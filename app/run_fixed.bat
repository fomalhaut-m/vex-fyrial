@echo off
echo ========================================
echo 修复日志配置 - 重新运行应用
echo ========================================
echo.

echo 已修复的问题:
echo   ✓ 启用 hierarchicalLoggingEnabled
echo   ✓ 添加 logging 包导入
echo.

echo 正在停止旧的应用实例...
adb shell am force-stop top.vex.fyrial
echo ✓ 应用已停止

echo.
echo 正在重新启动应用...
echo 提示: 观察控制台输出，应该不再出现 Logger 错误
echo.

flutter run

echo.
echo ========================================
echo 应用已退出
echo ========================================
pause
