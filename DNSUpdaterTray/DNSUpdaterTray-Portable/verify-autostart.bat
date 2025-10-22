@echo off
:: DNS自动更新器 - 开机自启动验证批处理
:: 检查开机自启动配置是否正确

title DNS自动更新器 - 开机自启动验证

:: 设置控制台代码页为UTF-8
chcp 65001 >nul

echo.
echo ========================================
echo   DNS自动更新器 - 开机自启动验证
echo ========================================
echo.

:: 检查PowerShell是否可用
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 未找到PowerShell，无法执行验证
    echo [提示] 请确保系统已安装PowerShell
    pause
    exit /b 1
)

:: 检查验证脚本是否存在
if not exist "%~dp0verify-autostart.ps1" (
    echo [错误] 未找到验证脚本 verify-autostart.ps1
    echo [提示] 请确保此批处理文件与 verify-autostart.ps1 在同一目录
    pause
    exit /b 1
)

echo [执行] 正在检查开机自启动配置...
echo.
echo ========================================
echo.

:: 执行PowerShell验证脚本
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0verify-autostart.ps1"

:: 获取PowerShell脚本的退出码
set VERIFY_RESULT=%errorLevel%

echo.
echo 按任意键退出...
pause >nul

exit /b %VERIFY_RESULT%
