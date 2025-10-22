@echo off
:: DNS自动更新器 - 系统安装批处理文件
:: 此批处理会自动请求管理员权限并执行安装

title DNS自动更新器 - 系统安装

:: 设置控制台代码页为UTF-8
chcp 65001 >nul

echo.
echo ========================================
echo    DNS自动更新器 - 系统安装程序
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [警告] 需要管理员权限来安装程序并设置开机启动！
    echo.
    echo [操作] 正在请求管理员权限...
    echo.
    
    :: 使用PowerShell请求提升权限并重新运行批处理
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [信息] 已获取管理员权限
echo.

:: 检查PowerShell是否可用
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 未找到PowerShell，无法继续安装
    echo [提示] 请确保系统已安装PowerShell
    pause
    exit /b 1
)

:: 检查安装脚本是否存在
if not exist "%~dp0install-startup.ps1" (
    echo [错误] 未找到安装脚本 install-startup.ps1
    echo [提示] 请确保此批处理文件与 install-startup.ps1 在同一目录
    pause
    exit /b 1
)

echo [执行] 正在运行安装脚本...
echo.
echo ========================================
echo.

:: 执行PowerShell安装脚本
:: -ExecutionPolicy Bypass: 绕过执行策略限制
:: -NoProfile: 不加载用户配置文件，加快启动
:: -File: 指定要执行的脚本文件
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install-startup.ps1"

:: 获取PowerShell脚本的退出码
set INSTALL_RESULT=%errorLevel%

echo.
echo ========================================

if %INSTALL_RESULT% equ 0 (
    echo.
    echo [成功] 安装完成！
    echo.
    echo [提示] 请查看任务栏右下角的咖啡杯图标
    echo [提示] 右键图标可进行设置和查看状态
    echo.
    echo [下一步] 建议重启电脑测试开机自启动功能
    echo.
) else (
    echo.
    echo [失败] 安装过程中发生错误 (错误码: %INSTALL_RESULT%)
    echo.
    echo [建议]
    echo  1. 检查是否有其他安全软件拦截
    echo  2. 尝试关闭防病毒软件后重试
    echo  3. 查看错误信息并手动解决问题
    echo.
)

echo 按任意键退出...
pause >nul
