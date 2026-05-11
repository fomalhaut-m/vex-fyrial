# OSS 双向同步方案设计

## 1. 同步策略

### 1.1 同步模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| 全量同步 | 扫描本地所有文件，与 OSS 对比差异后同步 | 首次初始化、修复一致性 |
| 增量同步 | 仅同步新增、修改、删除的文件 | 日常维护，减少流量 |

**推荐策略**：日常使用增量同步，定期（如每周）执行一次全量校验。

### 1.2 冲突处理

冲突场景：本地文件和 OSS 文件同时被修改。

| 冲突类型 | 处理策略 |
|----------|----------|
| 本地修改、OSS 未变 | 上传本地版本到 OSS |
| OSS 修改、本地未变 | 下载 OSS 版本到本地 |
| 双方同时修改 | 以最后修改时间为准，保留较新的；旧版本移入 `.archive/` 目录备份 |
| 删除冲突 | 对方已删除则同步删除，本地文件移入回收站而非直接删除 |

### 1.3 同步触发

| 触发方式 | 描述 |
|----------|------|
| 手动同步 | 用户主动点击"同步"按钮 |
| App 启动时 | 启动时检查增量，高并发场景加锁防重复 |
| 定时自动同步 | 可配置间隔（15min / 30min / 1h / 6h），后台 Job 执行 |
| 文件变更监听 | 使用 `watchman`（iOS/macOS）或 `inotify`（Android/Linux）监听本地文件变化，实时触发上传 |
| Wi-Fi 白名单 | 仅在 Wi-Fi 下自动同步，节省流量 |

---

## 2. 数据结构设计

### 2.1 本地文件元数据缓存表

使用 SQLite 表 `local_file_metadata` 缓存文件元数据：

```sql
CREATE TABLE local_file_metadata (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  local_path      TEXT NOT NULL UNIQUE,        -- 本地绝对路径
  file_name       TEXT NOT NULL,               -- 文件名
  file_size       INTEGER NOT NULL,            -- 文件大小（字节）
  local_mtime     INTEGER NOT NULL,            -- 本地修改时间（Unix timestamp ms）
  oss_path        TEXT,                        -- OSS 对象路径，如 "music/song.mp3"
  oss_etag        TEXT,                        -- OSS ETag
  oss_size        INTEGER,                     -- OSS 文件大小
  oss_mtime       INTEGER,                     -- OSS 修改时间
  sync_status     TEXT NOT NULL DEFAULT 'pending',  -- pending/upload/download/synced/conflicted/error
  last_sync_at    INTEGER,                     -- 最后同步时间
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

CREATE INDEX idx_sync_status ON local_file_metadata(sync_status);
CREATE INDEX idx_local_path ON local_file_metadata(local_path);
CREATE INDEX idx_oss_path ON local_file_metadata(oss_path);
```

### 2.2 同步队列设计

使用 SQLite 表 `sync_queue` 管理同步任务：

```sql
CREATE TABLE sync_queue (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id     INTEGER NOT NULL,                -- 关联 local_file_metadata.id
  action      TEXT NOT NULL,                   -- upload / download / delete
  priority    INTEGER NOT NULL DEFAULT 0,      -- 优先级，数字越大越优先
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  error_msg   TEXT,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending / processing / completed / failed
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE INDEX idx_queue_status ON sync_queue(status);
CREATE INDEX idx_queue_priority ON sync_queue(priority DESC, created_at ASC);
```

**状态机：**
- `pending` → `processing` → `completed`
- `processing` → `failed` → 满足重试条件则回到 `pending`，否则保持 `failed`

---

## 3. OSS SDK 选择

### 3.1 Flutter SDK

| SDK | 地址 | 说明 |
|-----|------|------|
| `aliyun_oss_flutter_sdk` | https://pub.dev/packages/aliyun_oss_flutter_sdk | 阿里云官方 Flutter SDK，支持上传/下载/列举/签名 URL 生成 |
| `aliyun-oss-ftp-sdk-flutter` | https://github.com/aliyun/aliyun-oss-ftp-sdk-flutter | 面向 FTP 协议，不适用于对象存储场景 |

**推荐**：`aliyun_oss_flutter_sdk`（官方维护，支持完整 OSS API）

### 3.2 Android/iOS 原生 SDK（Platform Channel）

对于性能敏感的音视频流处理，建议通过 Platform Channel 调用原生 SDK：

| 平台 | SDK | 说明 |
|------|-----|------|
| Android | aliyun-openservices-android-sdk | 阿里云 OSS Android SDK |
| iOS | AliyunOSSiOS | 阿里云 OSS iOS SDK |

**Flutter 接口层设计（MethodChannel）：**

```dart
// channel name: com.fluttermusic/oss
abstract class OssPlatformChannel {
  Future<void> init(String bucket, String endpoint, String accessKey, String secretKey);
  Future<String> upload(String localPath, String ossPath, {Function(double)? onProgress});
  Future<void> download(String ossPath, String localPath, {Function(double)? onProgress});
  Future<void> delete(String ossPath);
  Future<List<OssObject>> listObjects(String prefix);
}
```

---

## 4. 实现流程

### 4.1 本地新增文件 → 上传到 OSS

```
[文件新增检测]
    ↓
[扫描元数据，计算 MD5/SHA1]
    ↓
[查询本地库，是否已有记录]
    ↓ (无记录)
[插入 local_file_metadata，状态=pending]
    ↓
[插入 sync_queue，action=upload]
    ↓
[SyncWorker 消费队列]
    ↓
[调用 OSS SDK 上传]
    ↓
[成功 → 更新 oss_path / oss_etag / sync_status=synced]
    ↓ (失败)
[重试队列，记录 error_msg]
```

### 4.2 OSS 新增文件 → 下载到本地

```
[定时轮询 OSS 对象列表 或 接收 OSS 事件通知]
    ↓
[对比本地 local_file_metadata]
    ↓ (OSS 有，本地无 或 OSS mtime 更新)
[插入 sync_queue，action=download]
    ↓
[SyncWorker 消费队列]
    ↓
[下载文件到本地对应目录]
    ↓
[更新 local_mtime / sync_status=synced]
```

> **注**：若使用 OSS 事件通知（跨区延迟较高），建议结合定期轮询作为兜底。

### 4.3 删除文件联动

```
[用户删除本地文件 或 检测到 OSS 删除事件]
    ↓
[查找对应记录]
    ↓
[删除本地文件 → 软删除到回收站（保留30天）]
    ↓
[更新 sync_status=deleted，保留元数据用于追同步记录]
    ↓
[若对方（OSS/本地）仍有副本 → 记录冲突待确认]
```

---

## 5. 配置项

### 5.1 OSS 连接参数

| 参数 | 来源 | 说明 |
|------|------|------|
| `bucket` | 用户配置 | OSS Bucket 名称 |
| `endpoint` | 用户配置 | OSS Endpoint，如 `oss-cn-hangzhou.aliyuncs.com` |
| `accessKeyId` | 用户配置 | RAM 子账号 AK |
| `accessKeySecret` | 用户配置 | RAM 子账号 SK |

> **安全建议**：AK/SK 禁止明文存储。推荐以下方案：
> 
> **方案一：flutter_secure_storage（推荐）**
> - Android：使用 EncryptedSharedPreferences（底层 Android KeyChain）
> - iOS：使用 iOS Keychain
> - 加密存储敏感凭证，换机需重新输入
>
> **方案二：STS Token 动态凭证**
> - 通过自己的后端服务申请临时访问凭证（过期时间可设）
> - AK/SK 始终留存在服务端，前端只存储短期 Token
> - 适合对安全性要求更高的场景
>
> **方案三：原生 KeyChain / KeyStore（Platform Channel）**
> - Android：通过 KeyStore 管理密钥，支持 biometric 认证解锁
> - iOS：原生 Keychain，安全性最高

### 5.2 同步目录配置

用户可配置多个同步目录（如 `/storage/music`、`/storage/podcast`），每个目录对应独立的 OSS 前缀：

```json
{
  "sync_dirs": [
    { "local_path": "/storage/music", "oss_prefix": "music/", "enabled": true },
    { "local_path": "/storage/podcast", "oss_prefix": "podcast/", "enabled": false }
  ]
}
```

### 5.3 同步频率配置

```json
{
  "auto_sync": true,
  "sync_interval_minutes": 30,
  "wifi_only": true,
  "full_sync_weekly": true,
  "full_sync_day": "sunday"
}
```

---

## 6. 异常处理与监控

- **网络错误**：自动重试，指数退避（1s → 2s → 4s → 8s，最大 3 次）
- **OSS 限流（403/503）**：识别错误码，暂停队列并延时重排
- **存储空间不足**：上传前检查本地磁盘空间 < 100MB 时告警并暂停
- **同步日志**：每次同步操作记录操作类型、文件、结果、耗时，供问题排查