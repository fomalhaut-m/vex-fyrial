@echo off
echo ========================================
echo 获取音频元数据读取依赖
echo ========================================
echo.

echo 正在获取依赖包...
flutter pub get

if errorlevel 1 (
    echo.
    echo ✗ 依赖获取失败
    pause
    exit /b 1
)

echo.
echo ✓ 依赖获取成功
echo.
echo 已添加的包:
echo   - audio_metadata_reader: ^1.0.2
echo.
echo 功能:
echo   ✓ 读取 MP3/FLAC/WAV 等格式的 ID3 标签
echo   ✓ 获取歌曲时长
echo   ✓ 获取歌手、专辑信息
echo   ✓ 提取专辑封面图片
echo.
pause
