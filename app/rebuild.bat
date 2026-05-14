@echo off
echo ========================================
echo 清理并重新构建 Fyrial 项目
echo ========================================
echo.

echo [1/4] 清理 Flutter 构建...
flutter clean
if errorlevel 1 (
    echo Flutter clean 失败
    pause
    exit /b 1
)
echo.

echo [2/4] 清理 Gradle 缓存...
cd android
call gradlew clean
if errorlevel 1 (
    echo Gradle clean 失败
    pause
    exit /b 1
)
cd ..
echo.

echo [3/4] 获取依赖...
flutter pub get
if errorlevel 1 (
    echo Flutter pub get 失败
    pause
    exit /b 1
)
echo.

echo [4/4] 启动 build_runner watch...
start cmd /k "dart run build_runner watch --delete-conflicting-outputs"

echo.
echo ========================================
echo 等待 5 秒后启动 Flutter 应用...
echo ========================================
timeout /t 5 /nobreak >nul

echo.
echo 启动 Flutter 应用...
flutter run

pause
