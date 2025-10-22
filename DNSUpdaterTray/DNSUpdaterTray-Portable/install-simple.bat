@echo off
:: DNS自动更新器 - 纯批处理安装脚本
:: 不依赖PowerShell，使用Windows内置命令实现
:: 适用于禁用PowerShell或安全受限的环境

title DNS自动更新器 - 快速安装

:: 设置控制台代码页为UTF-8
chcp 65001 >nul

setlocal enabledelayedexpansion

echo.
echo ========================================
echo    DNS自动更新器 - 快速安装程序
echo    (纯批处理版本)
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [警告] 需要管理员权限！
    echo.
    echo [方法1] 右键此文件 - 选择"以管理员身份运行"
    echo [方法2] 在管理员命令提示符中运行此文件
    echo.
    echo 按任意键尝试自动请求管理员权限...
    pause >nul
    
    :: 创建临时VBS脚本来请求管理员权限
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~f0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /b
)

echo [√] 已获取管理员权限
echo.

:: 设置安装路径
set "INSTALL_DIR=C:\Program Files\DNSUpdaterTray"
set "PROGRAM_NAME=DNSUpdaterTray.exe"
set "SOURCE_DIR=%~dp0"

:: 1. 检查源文件
echo [步骤 1/6] 检查程序文件...
if not exist "%SOURCE_DIR%%PROGRAM_NAME%" (
    echo [×] 错误: 未找到 %PROGRAM_NAME%
    echo [!] 请确保此批处理文件与程序文件在同一目录
    goto :error
)
echo [√] 程序文件检查通过
echo.

:: 2. 停止已运行的实例
echo [步骤 2/6] 检查并停止运行中的实例...
tasklist /FI "IMAGENAME eq %PROGRAM_NAME%" 2>NUL | find /I "%PROGRAM_NAME%" >NUL
if %errorLevel% equ 0 (
    echo [!] 发现运行中的程序，正在停止...
    taskkill /F /IM "%PROGRAM_NAME%" >NUL 2>&1
    timeout /t 2 /nobreak >NUL
    echo [√] 已停止旧实例
) else (
    echo [√] 无运行中的实例
)
echo.

:: 3. 创建/清理安装目录
echo [步骤 3/6] 准备安装目录...
if exist "%INSTALL_DIR%" (
    echo [!] 检测到已存在的安装，正在清理...
    rd /s /q "%INSTALL_DIR%" 2>NUL
)
mkdir "%INSTALL_DIR%" 2>NUL
if %errorLevel% neq 0 (
    echo [×] 错误: 无法创建安装目录
    goto :error
)
echo [√] 安装目录已就绪: %INSTALL_DIR%
echo.

:: 4. 复制程序文件
echo [步骤 4/6] 复制程序文件...
xcopy "%SOURCE_DIR%*.*" "%INSTALL_DIR%\" /E /I /Y /Q >NUL 2>&1
if %errorLevel% neq 0 (
    echo [×] 错误: 文件复制失败
    goto :error
)

:: 检查主程序是否复制成功
if not exist "%INSTALL_DIR%\%PROGRAM_NAME%" (
    echo [×] 错误: 主程序复制失败
    goto :error
)
echo [√] 程序文件复制完成
echo.

:: 5. 配置开机自启动
echo [步骤 5/6] 配置开机自启动...

:: 5.1 注册表方式
echo [  ] 设置注册表启动项...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DNSUpdaterTray" /t REG_SZ /d "\"%INSTALL_DIR%\%PROGRAM_NAME%\"" /f >NUL 2>&1
if %errorLevel% equ 0 (
    echo [√] 注册表启动项已设置
) else (
    echo [!] 注册表启动项设置失败（可忽略）
)

:: 5.2 启动文件夹快捷方式（使用VBS创建）
echo [  ] 创建启动文件夹快捷方式...
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\DNS自动更新器.lnk"

:: 创建VBS脚本来生成快捷方式
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%temp%\CreateShortcut.vbs"
echo sLinkFile = "%SHORTCUT_PATH%" >> "%temp%\CreateShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%temp%\CreateShortcut.vbs"
echo oLink.TargetPath = "%INSTALL_DIR%\%PROGRAM_NAME%" >> "%temp%\CreateShortcut.vbs"
echo oLink.WorkingDirectory = "%INSTALL_DIR%" >> "%temp%\CreateShortcut.vbs"
echo oLink.Description = "DNS自动更新器 - 自动更新动态DNS记录" >> "%temp%\CreateShortcut.vbs"
echo oLink.WindowStyle = 7 >> "%temp%\CreateShortcut.vbs"
echo oLink.Save >> "%temp%\CreateShortcut.vbs"

cscript //nologo "%temp%\CreateShortcut.vbs" >NUL 2>&1
del "%temp%\CreateShortcut.vbs" >NUL 2>&1

if exist "%SHORTCUT_PATH%" (
    echo [√] 启动文件夹快捷方式已创建
) else (
    echo [!] 启动文件夹快捷方式创建失败（可忽略）
)

echo [√] 开机自启动配置完成
echo.

:: 6. 启动程序
echo [步骤 6/6] 启动程序...
start "" "%INSTALL_DIR%\%PROGRAM_NAME%"
timeout /t 2 /nobreak >NUL

tasklist /FI "IMAGENAME eq %PROGRAM_NAME%" 2>NUL | find /I "%PROGRAM_NAME%" >NUL
if %errorLevel% equ 0 (
    echo [√] 程序已成功启动
) else (
    echo [!] 程序可能未正常启动，请手动检查
)
echo.

:: 安装完成
echo ========================================
echo [√] 安装完成！
echo ========================================
echo.
echo [信息] 安装位置: %INSTALL_DIR%
echo [信息] 开机自启: 已启用（双重机制）
echo [信息] 托盘图标: 请查看任务栏右下角 ☕
echo.
echo [使用说明]
echo  • 右键托盘图标 - 查看菜单
echo  • 双击托盘图标 - 立即更新DNS
echo  • 右键 - 设置 - 配置DNS参数
echo  • 右键 - 状态信息 - 查看运行状态
echo.
echo [下一步]
echo  1. 右键托盘图标配置DNS参数
echo  2. 重启电脑测试开机自启动
echo.
echo 按任意键退出...
pause >nul
exit /b 0

:error
echo.
echo ========================================
echo [×] 安装失败！
echo ========================================
echo.
echo [建议]
echo  1. 检查是否以管理员身份运行
echo  2. 检查程序文件是否完整
echo  3. 关闭防病毒软件后重试
echo  4. 查看上方错误信息
echo.
echo 按任意键退出...
pause >nul
exit /b 1
