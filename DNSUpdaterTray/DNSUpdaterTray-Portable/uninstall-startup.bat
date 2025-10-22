@echo off
:: DNS自动更新器 - 卸载批处理文件
:: 此批处理会自动请求管理员权限并执行卸载

title DNS自动更新器 - 卸载程序

:: 设置控制台代码页为UTF-8
chcp 65001 >nul

echo.
echo ========================================
echo    DNS自动更新器 - 卸载程序
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [警告] 需要管理员权限来卸载程序！
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
    echo [错误] 未找到PowerShell，无法继续卸载
    echo [提示] 请确保系统已安装PowerShell
    pause
    exit /b 1
)

:: 检查卸载脚本位置
set "UNINSTALL_SCRIPT=%~dp0uninstall-startup.ps1"
if not exist "%UNINSTALL_SCRIPT%" (
    :: 尝试从安装目录查找
    set "UNINSTALL_SCRIPT=C:\Program Files\DNSUpdaterTray\uninstall-startup.ps1"
    
    if not exist "%UNINSTALL_SCRIPT%" (
        echo [错误] 未找到卸载脚本 uninstall-startup.ps1
        echo.
        echo [尝试的位置]
        echo  1. %~dp0uninstall-startup.ps1
        echo  2. C:\Program Files\DNSUpdaterTray\uninstall-startup.ps1
        echo.
        pause
        exit /b 1
    )
)

echo [确认] 即将卸载 DNS自动更新器
echo.
echo [操作内容]
echo  - 停止运行的程序
echo  - 删除开机自启动设置
echo  - 删除程序文件
echo  - 删除防火墙规则
echo.

set /p CONFIRM="确定要继续吗？(Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo [取消] 用户取消了卸载操作
    echo.
    pause
    exit /b 0
)

echo.
echo [执行] 正在运行卸载脚本...
echo.
echo ========================================
echo.

:: 执行PowerShell卸载脚本
powershell -ExecutionPolicy Bypass -NoProfile -File "%UNINSTALL_SCRIPT%"

:: 获取PowerShell脚本的退出码
set UNINSTALL_RESULT=%errorLevel%

echo.
echo ========================================

if %UNINSTALL_RESULT% equ 0 (
    echo.
    echo [成功] 卸载完成！
    echo.
    echo [已清理]
    echo  - DNS更新器进程
    echo  - 开机自启动设置
    echo  - 程序安装目录
    echo  - 防火墙规则
    echo.
    echo [提示] 如果托盘图标仍显示，请重启系统
    echo.
) else (
    echo.
    echo [失败] 卸载过程中发生错误 (错误码: %UNINSTALL_RESULT%)
    echo.
    echo [建议]
    echo  1. 尝试手动删除程序目录
    echo  2. 使用任务管理器结束进程
    echo  3. 查看错误信息并手动解决问题
    echo.
)

echo 按任意键退出...
pause >nul
