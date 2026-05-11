# ⚠️ 已废弃（Deprecated）

> **此文档已废弃。** Vexfy PRD v3 已删除所有在线音乐功能，产品定位改为纯本地播放器。本文档仅作历史参考，不再维护。

---

# Vexfy API 接口设计文档

> 本文档定义在线音乐模块的 API 接口规范，采用 RESTful 风格描述。
> 后端服务尚未接入，当前端点为**模拟/占位实现**，实际对接时只需替换 `OnlineProvider` 的 base URL 和数据解析逻辑。

---

## 1. 接口概览

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/recommend` | 推荐歌单 |
| GET | `/rank` | 排行榜 |
| GET | `/square` | 歌单广场 |
| GET | `/search` | 搜索 |
| GET | `/song/url` | 获取歌曲播放地址 |

---

## 2. 通用说明

### 2.1 基础信息

- **Base URL**：`https://api.example-music.com/v1`（占位）
- **数据格式**：JSON
- **字符编码**：UTF-8
- **请求编码**：URL query string，使用 `UTF-8` URL encode

### 2.2 通用响应结构

```json
{
  "code": 200,
  "message": "success",
  "data": { ... }
}
```

错误响应：

```json
{
  "code": 400,
  "message": "Invalid parameter",
  "data": null
}
```

### 2.3 分页参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `page` | `int` | `1` | 页码 |
| `pageSize` | `int` | `20` | 每页条数，最大 `50` |

---

## 3. 接口详情

---

### 3.1 GET /recommend — 推荐歌单

获取系统推荐的歌单列表。

**请求参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `page` | `int` | 否 | 页码，默认 `1` |
| `pageSize` | `int` | 否 | 每页条数，默认 `10` |

**请求示例**：
```
GET /recommend?page=1&pageSize=10
```

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "id": "pl_001",
        "name": "华语经典",
        "coverUrl": "https://cdn.example.com/covers/pl001.jpg",
        "songCount": 50,
        "playCount": 1234567,
        "tags": ["华语", "经典", "流行"],
        "description": "那些年我们一起听过的歌",
        "creatorName": "官方",
        "createTime": "2024-01-01T00:00:00Z"
      }
    ],
    "page": 1,
    "pageSize": 10,
    "total": 100,
    "hasMore": true
  }
}
```

**响应字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | `List<Playlist>` | 歌单列表 |
| `page` | `int` | 当前页 |
| `pageSize` | `int` | 每页条数 |
| `total` | `int` | 总数 |
| `hasMore` | `bool` | 是否有更多 |

---

### 3.2 GET /rank — 排行榜

获取音乐排行榜列表。

**请求参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `rankType` | `string` | 否 | 排行榜类型，默认 `total`（可选：`total`、`new`、`hot`） |

**请求示例**：
```
GET /rank?rankType=total
```

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "rankings": [
      {
        "id": "rank_total",
        "name": "综合榜",
        "coverUrl": "https://cdn.example.com/rank/total.jpg",
        "updateTime": "2024-05-10T12:00:00Z",
        "items": [
          {
            "rank": 1,
            "song": {
              "id": "song_001",
              "title": "晴天",
              "artist": "周杰伦",
              "album": "叶惠美",
              "duration": 268000,
              "coverUrl": "https://cdn.example.com/song001.jpg",
              "onlineUrl": "https://cdn.example.com/song001.mp3"
            },
            "lastRank": 2,
            "trend": "up"
          },
          {
            "rank": 2,
            "song": {
              "id": "song_002",
              "title": "稻香",
              "artist": "周杰伦",
              "album": "魔杰座",
              "duration": 222000,
              "coverUrl": "https://cdn.example.com/song002.jpg",
              "onlineUrl": "https://cdn.example.com/song002.mp3"
            },
            "lastRank": null,
            "trend": "new"
          }
        ]
      }
    ]
  }
}
```

**响应字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `rankings` | `List<Ranking>` | 排行榜列表 |
| `rankings[].items` | `List<RankItem>` | 榜单条目列表 |
| `rankItems[].rank` | `int` | 当前排名 |
| `rankItems[].lastRank` | `int?` | 上期排名，null 表示新上榜 |
| `rankItems[].trend` | `string` | 趋势：`up`、`down`、`new`、`same` |

---

### 3.3 GET /square — 歌单广场

获取可浏览的歌单广场，支持分页加载。

**请求参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `page` | `int` | 否 | 页码，默认 `1` |
| `pageSize` | `int` | 否 | 每页条数，默认 `20` |
| `tag` | `string` | 否 | 标签筛选，如 `华语`、`欧美`、`摇滚` |

**请求示例**：
```
GET /square?page=1&pageSize=20&tag=华语
```

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "id": "pl_sq_001",
        "name": "深夜emo专用",
        "coverUrl": "https://cdn.example.com/covers/plsq001.jpg",
        "songCount": 30,
        "playCount": 555555,
        "tags": ["华语", "伤感", "深夜"],
        "description": "一个人听的歌",
        "creatorName": "音乐小熊",
        "createTime": "2024-03-15T08:00:00Z"
      }
    ],
    "page": 1,
    "pageSize": 20,
    "total": 500,
    "hasMore": true
  }
}
```

---

### 3.4 GET /search — 搜索

搜索歌曲、歌手、歌单。

**请求参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `keyword` | `string` | **是** | 搜索关键词 |
| `type` | `string` | 否 | 搜索类型，默认 `all`（可选：`all`、`song`、`playlist`、`artist`） |
| `page` | `int` | 否 | 页码，默认 `1` |
| `pageSize` | `int` | 否 | 每页条数，默认 `20` |

**请求示例**：
```
GET /search?keyword=周杰伦&type=song&page=1&pageSize=20
```

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "keyword": "周杰伦",
    "songs": {
      "items": [
        {
          "id": "song_001",
          "title": "晴天",
          "artist": "周杰伦",
          "album": "叶惠美",
          "duration": 268000,
          "coverUrl": "https://cdn.example.com/song001.jpg",
          "onlineUrl": "https://cdn.example.com/song001.mp3"
        }
      ],
      "total": 200,
      "page": 1,
      "pageSize": 20,
      "hasMore": true
    },
    "playlists": {
      "items": [
        {
          "id": "pl_002",
          "name": "周杰伦精选",
          "coverUrl": "https://cdn.example.com/covers/pl002.jpg",
          "songCount": 50,
          "creatorName": "杰迷小王",
          "createTime": "2024-02-01T00:00:00Z"
        }
      ],
      "total": 15,
      "page": 1,
      "pageSize": 20,
      "hasMore": false
    },
    "artists": {
      "items": [
        {
          "id": "artist_001",
          "name": "周杰伦",
          "avatarUrl": "https://cdn.example.com/artist001.jpg",
          "songCount": 300
        }
      ],
      "total": 1,
      "page": 1,
      "pageSize": 20,
      "hasMore": false
    }
  }
}
```

---

### 3.5 GET /song/url — 获取歌曲播放地址

获取指定歌曲的在线播放 URL。

**请求参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `id` | `string` | **是** | 歌曲ID |

**请求示例**：
```
GET /song/url?id=song_001
```

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "song_001",
    "url": "https://cdn.example.com/songs/song001.mp3",
    "duration": 268000,
    "size": 4283210,
    "format": "mp3",
    "bitrate": "320kbps",
    "expiresAt": "2024-05-10T18:00:00Z"
  }
}
```

**响应字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `string` | 歌曲ID |
| `url` | `string` | 播放地址（可能有时效性） |
| `duration` | `int` | 时长，毫秒 |
| `size` | `int` | 文件大小，字节 |
| `format` | `string` | 音频格式，如 `mp3`、`flac` |
| `bitrate` | `string` | 比特率，如 `128kbps`、`320kbps`、`flac` |
| `expiresAt` | `string` | URL 过期时间（ISO 8601），需在此之前缓存 |

---

## 4. 错误码规范

| code | 说明 |
|------|------|
| `200` | 成功 |
| `400` | 请求参数错误 |
| `401` | 未授权（需登录） |
| `403` | 无权限 |
| `404` | 资源不存在 |
| `429` | 请求过于频繁（需退避） |
| `500` | 服务器内部错误 |

---

## 5. 在线模块 Provider 示例结构

```dart
class OnlineProvider {
  static const String baseUrl = 'https://api.example-music.com/v1';

  // 推荐歌单
  Future<List<PlaylistModel>> getRecommendPlaylists({int page = 1, int pageSize = 10});

  // 排行榜
  Future<List<RankingModel>> getRankings({String rankType = 'total'});

  // 歌单广场
  Future<List<PlaylistModel>> getPlaylistSquare({int page = 1, int pageSize = 20, String? tag});

  // 搜索
  Future<SearchResultModel> search(String keyword, {String type = 'all', int page = 1, int pageSize = 20});

  // 获取播放地址
  Future<String> getSongUrl(String songId);
}
```
