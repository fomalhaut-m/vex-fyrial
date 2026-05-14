@echo off
echo ========================================
echo fyrial - 启动代码生成监听模式
echo ========================================
echo.
echo 提示：保持此窗口打开，修改模型后会自动生成代码
echo 按 Ctrl+C 停止监听
echo.

cd /d "%~dp0app"

echo [1/2] 检查依赖...
flutter pub get

echo.
echo [2/2] 启动监听模式...
echo.

dart run build_runner watch --delete-conflicting-outputs

pause
