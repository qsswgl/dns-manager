# DNS自动更新器 - 便携式安装包创建脚本

Write-Host "🚀 正在创建DNS更新器便携式安装包..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 创建便携式安装包目录
$packageDir = "DNSUpdaterTray-Portable"
$currentDir = Get-Location

if (Test-Path $packageDir) {
    Remove-Item $packageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

Write-Host "📁 创建安装包目录: $packageDir" -ForegroundColor Yellow

# 复制必要文件
Write-Host "📋 复制程序文件..." -ForegroundColor Yellow

# 1. 自包含可执行文件
Copy-Item "bin\Release\net8.0-windows\win-x64\publish\DNSUpdaterTray.exe" $packageDir -Force
Copy-Item "bin\Release\net8.0-windows\win-x64\publish\appsettings.json" $packageDir -Force
Write-Host "  ✅ 主程序文件" -ForegroundColor Green

# 2. 安装和卸载脚本（PowerShell + 批处理）
Copy-Item "install-startup-selfcontained.ps1" "$packageDir\install-startup.ps1" -Force
Copy-Item "uninstall-startup.ps1" $packageDir -Force
Copy-Item "verify-autostart.ps1" $packageDir -Force
Copy-Item "install-startup.bat" $packageDir -Force
Copy-Item "uninstall-startup.bat" $packageDir -Force
Copy-Item "verify-autostart.bat" $packageDir -Force
Copy-Item "install-simple.bat" $packageDir -Force
Write-Host "  ✅ 安装/卸载脚本（PowerShell + 批处理）" -ForegroundColor Green

# 3. 文档文件
Copy-Item "README.md" $packageDir -Force
Write-Host "  ✅ 使用说明文档" -ForegroundColor Green

# 4. 创建便携式启动脚本
$portableScript = '@echo off
title DNS自动更新器 - 便携模式
echo.
echo ===============================
echo    DNS自动更新器 - 便携模式
echo ===============================
echo.

REM 检查是否已在运行
tasklist /FI "IMAGENAME eq DNSUpdaterTray.exe" 2>NUL | find /I "DNSUpdaterTray.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    echo [信息] DNS更新器已在运行中
    echo [提示] 请查看系统托盘区域的咖啡杯图标
    pause
    exit /b
)

echo [启动] 正在启动DNS自动更新器...
start "" "%~dp0DNSUpdaterTray.exe"

REM 等待程序启动
timeout /t 2 /nobreak >NUL

REM 检查启动是否成功  
tasklist /FI "IMAGENAME eq DNSUpdaterTray.exe" 2>NUL | find /I "DNSUpdaterTray.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    echo [成功] DNS更新器已成功启动！
    echo [提示] 请查看系统托盘区域的咖啡杯图标
    echo [操作] 右键点击图标可查看菜单选项
) else (
    echo [错误] 程序启动失败，请检查错误信息
    pause
    exit /b 1
)

echo.
echo 程序将在后台运行，窗口将在5秒后自动关闭...
timeout /t 5'

$portableScript | Out-File "$packageDir\启动DNS更新器.bat" -Encoding Default
Write-Host "  ✅ 便携式启动脚本" -ForegroundColor Green

# 5. 创建快速安装脚本
$quickInstallScript = @"
# DNS更新器 - 快速安装脚本
# 此脚本将自动安装DNS更新器到系统并设置开机自启动

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "❌ 需要管理员权限来安装到系统目录和设置开机启动！" -ForegroundColor Red
    Write-Host "请右键点击此文件，选择'以管理员身份运行'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "🚀 DNS自动更新器 - 快速安装" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 执行安装
. ".\install-startup.ps1"
"@

$quickInstallScript | Out-File "$packageDir\快速安装.ps1" -Encoding UTF8
Write-Host "  ✅ 快速安装脚本" -ForegroundColor Green

# 6. 创建安装包说明文件
$packageReadme = @"
# DNS自动更新器 - 便携式安装包

## 📦 安装包内容

此安装包包含以下文件：

### 🔧 核心文件
- **DNSUpdaterTray.exe** - 主程序（自包含，无需安装.NET运行时）
- **appsettings.json** - 默认配置文件

### 🚀 安装脚本
- **快速安装.ps1** - 一键安装到系统并设置开机启动（需要管理员权限）
- **install-startup.ps1** - 详细安装脚本
- **uninstall-startup.ps1** - 卸载脚本

### 📖 文档
- **README.md** - 详细使用说明
- **安装包说明.md** - 本文件

### ⚡ 便携启动
- **启动DNS更新器.bat** - 便携式启动脚本（无需安装）

## 🎯 安装方式

### 方式一：系统安装（推荐）
1. 右键点击 **快速安装.ps1**
2. 选择"以管理员身份运行"
3. 等待安装完成
4. 检查系统托盘的咖啡杯图标 ☕

### 方式二：便携运行
1. 双击 **启动DNS更新器.bat**
2. 程序将以便携模式运行
3. 不会安装到系统，不会设置开机启动

## ⚙️ 系统要求

- **操作系统**: Windows 10/11 (x64)
- **架构**: 64位系统
- **权限**: 系统安装需要管理员权限，便携运行无需特殊权限
- **网络**: 需要访问DNS API服务器

## 🔧 首次使用

1. 程序启动后会显示咖啡杯托盘图标
2. 右键点击图标 → "设置" 配置DNS参数：
   - 子域名（如: 3950）
   - 域名（如: qsgl.net）
   - 更新间隔（建议60秒）
   - API地址
3. 配置会自动保存，下次启动自动加载

## 📁 配置文件位置

- **程序配置**: 安装目录下的 appsettings.json
- **用户配置**: %AppData%\DNSUpdaterTray\user-config.json
- **图标缓存**: %AppData%\DNSUpdaterTray\coffee-icon.ico

## ❓ 故障排除

1. **程序无法启动**
   - 检查是否为64位Windows系统
   - 尝试以管理员身份运行

2. **托盘图标未显示**  
   - 检查Windows通知区域设置
   - 重启程序或重启系统

3. **DNS更新失败**
   - 检查网络连接
   - 验证API地址是否正确
   - 查看"状态信息"中的错误详情

## 📞 技术支持

- **项目地址**: https://github.com/qsswgl/dns-manager
- **DNS管理**: https://tx.qsgl.net:5075
- **API文档**: https://tx.qsgl.net:5075/swagger

---

💡 建议使用"系统安装"方式以获得最佳体验！
"@

$packageReadme | Out-File "$packageDir\安装包说明.md" -Encoding UTF8
Write-Host "  ✅ 安装包说明文档" -ForegroundColor Green

# 显示安装包信息
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 便携式安装包创建完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📍 安装包位置: $currentDir\$packageDir" -ForegroundColor Cyan
Write-Host "📦 安装包大小: $('{0:N2}' -f ((Get-ChildItem $packageDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB)) MB" -ForegroundColor Cyan
Write-Host ""

# 显示文件列表
Write-Host "📋 安装包内容:" -ForegroundColor Yellow
Get-ChildItem $packageDir | Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host "🎯 使用方法:" -ForegroundColor Yellow
Write-Host "1. 将整个 '$packageDir' 文件夹复制到目标主机" -ForegroundColor Gray
Write-Host "2. 在目标主机上运行 '快速安装.ps1'（管理员权限）" -ForegroundColor Gray
Write-Host "3. 或运行 '启动DNS更新器.bat'（便携模式）" -ForegroundColor Gray
Write-Host ""
Write-Host "✨ 自包含程序，目标主机无需安装.NET运行时！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan