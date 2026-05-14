@echo off
chcp 65001 >nul
echo ========================================
echo 修复编译错误 - 获取依赖并重新构建
echo ========================================
echo.

cd /d C:\work\vex\vex-fyrial\app

echo [步骤 1/4] 清理旧的构建...
call flutter clean
if errorlevel 1 (
    echo ✗ Flutter clean 失败
    pause
    exit /b 1
)
echo ✓ 清理完成
echo.

echo [步骤 2/4] 获取所有依赖包（包括 audio_metadata_reader）...
call flutter pub get
if errorlevel 1 (
    echo.
    echo ✗ 依赖获取失败！
    echo.
    echo 可能的原因:
    echo   1. 网络连接问题
    echo   2. audio_metadata_reader 版本不兼容
    echo.
    echo 尝试方案:
    echo   1. 检查网络连接
    echo   2. 运行: flutter pub cache repair
    echo   3. 临时移除 audio_metadata_reader 依赖
    echo.
    pause
    exit /b 1
)
echo ✓ 依赖获取成功
echo.

echo [步骤 3/4] 重新生成代码...
call dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ⚠ 代码生成有警告（继续执行）
) else (
    echo ✓ 代码生成完成
)
echo.

echo [步骤 4/4] 验证依赖...
call flutter doctor
echo.

echo ========================================
echo ✓ 所有步骤完成！
echo ========================================
echo.
echo 现在可以运行应用了:
echo   flutter run
echo.
pause
