@echo off
chcp 65001 >nul
echo ========================================
echo 清理 Flutter 缓存并重新构建
echo ========================================
echo.

cd /d C:\work\vex\vex-fyrial\app

echo [步骤 1/3] 停止所有正在运行的应用...
adb shell am force-stop top.vex.fyrial 2>nul
echo ✓ 已停止应用
echo.

echo [步骤 2/3] 清理 Flutter 构建缓存...
call flutter clean
if errorlevel 1 (
    echo ✗ Flutter clean 失败
    pause
    exit /b 1
)
echo ✓ 清理完成
echo.

echo [步骤 3/3] 重新获取依赖包...
call flutter pub get
if errorlevel 1 (
    echo ✗ 依赖获取失败
    pause
    exit /b 1
)
echo ✓ 依赖获取成功
echo.

echo ========================================
echo ✓ 清理完成！
echo ========================================
echo.
echo 现在可以重新启动应用了:
echo   flutter run
echo.
echo 注意: 如果是热重载状态，建议完全重启应用
echo.
pause
