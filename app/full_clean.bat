@echo off
echo ========================================
echo 完全清理并重启应用
echo ========================================
echo.

echo [1/5] 停止应用...
adb shell am force-stop top.vex.fyrial
echo ✓ 应用已停止

echo.
echo [2/5] 清除应用数据...
adb shell pm clear top.vex.fyrial
echo ✓ 应用数据已清除

echo.
echo [3/5] 清理 Flutter 构建...
flutter clean
if errorlevel 1 (
    echo ✗ Flutter clean 失败
    pause
    exit /b 1
)
echo ✓ Flutter clean 完成

echo.
echo [4/5] 重新生成代码...
dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ✗ build_runner 失败
    pause
    exit /b 1
)
echo ✓ 代码生成完成

echo.
echo [5/5] 获取依赖...
flutter pub get
if errorlevel 1 (
    echo ✗ flutter pub get 失败
    pause
    exit /b 1
)
echo ✓ 依赖获取完成

echo.
echo ========================================
echo ✓ 清理完成！现在可以重新运行应用
echo ========================================
echo.
echo 提示: 使用 flutter run -v 查看详细日志
echo.
pause
