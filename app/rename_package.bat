@echo off
echo 正在重命名包目录结构...

cd /d C:\work\vex\vex-fyrial\app\android\app\src\main\kotlin

echo 创建新目录结构...
mkdir top\vex\fyrial 2>nul

echo 移动 MainActivity.kt...
if exist "com\vexfy\vexfy\MainActivity.kt" (
    move "com\vexfy\vexfy\MainActivity.kt" "top\vex\fyrial\MainActivity.kt"
    echo MainActivity.kt 已移动
) else (
    echo 警告: MainActivity.kt 不存在或已移动
)

echo 删除旧目录...
if exist "com" rmdir /s /q "com"

echo.
echo 完成！新的目录结构: top\vex\fyrial\MainActivity.kt
pause
