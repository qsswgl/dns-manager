# DNS更新器安装脚本
# 需要管理员权限运行

param(
    [string]$InstallPath = "C:\Program Files\DNSUpdaterTray"
)

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "❌ 此脚本需要管理员权限运行！" -ForegroundColor Red
    Write-Host "请右键点击PowerShell并选择'以管理员身份运行'，然后重新执行此脚本。" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "🚀 DNS自动更新器安装程序" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

try {
    # 1. 创建安装目录
    Write-Host "📁 创建安装目录: $InstallPath" -ForegroundColor Yellow
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    # 2. 复制程序文件
    Write-Host "📋 复制程序文件..." -ForegroundColor Yellow
    $sourceFiles = @(
        "bin\Release\net8.0-windows\DNSUpdaterTray.exe",
        "bin\Release\net8.0-windows\DNSUpdaterTray.dll",
        "bin\Release\net8.0-windows\DNSUpdaterTray.runtimeconfig.json",
        "bin\Release\net8.0-windows\appsettings.json"
    )
    
    # 先构建项目
    Write-Host "🔨 构建项目..." -ForegroundColor Yellow
    dotnet build -c Release
    
    if ($LASTEXITCODE -ne 0) {
        throw "项目构建失败"
    }
    
    # 复制文件
    foreach ($file in $sourceFiles) {
        if (Test-Path $file) {
            Copy-Item $file $InstallPath -Force
            Write-Host "  ✅ 复制: $(Split-Path $file -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ 文件不存在: $file" -ForegroundColor Yellow
        }
    }
    
    # 复制所有依赖DLL
    $dllFiles = Get-ChildItem "bin\Release\net8.0-windows\*.dll"
    foreach ($dll in $dllFiles) {
        Copy-Item $dll.FullName $InstallPath -Force
    }

    # 3. 创建开机启动注册表项
    Write-Host "🔑 设置开机自启动..." -ForegroundColor Yellow
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $appName = "DNSUpdaterTray"
    $exePath = Join-Path $InstallPath "DNSUpdaterTray.exe"
    
    Set-ItemProperty -Path $registryPath -Name $appName -Value $exePath -Force
    Write-Host "  ✅ 注册表项已创建" -ForegroundColor Green

    # 4. 启动程序
    Write-Host "🚀 启动DNS更新器..." -ForegroundColor Yellow
    Start-Process $exePath -WindowStyle Hidden
    
    # 等待一下让程序启动
    Start-Sleep 2
    
    # 检查是否启动成功
    $process = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "  ✅ 程序已成功启动" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ 程序可能未正常启动，请检查任务栏托盘区域" -ForegroundColor Yellow
    }

    # 5. 安装完成信息
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 安装完成！" -ForegroundColor Green
    Write-Host ""
    Write-Host "📍 安装位置: $InstallPath" -ForegroundColor Cyan
    Write-Host "🔄 开机自启: 已启用" -ForegroundColor Cyan
    Write-Host "🎯 托盘图标: 请查看任务栏右下角" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 使用说明:" -ForegroundColor Yellow
    Write-Host "• 右键托盘图标查看菜单选项" -ForegroundColor Gray
    Write-Host "• 双击托盘图标立即检查更新" -ForegroundColor Gray
    Write-Host "• 程序将每60秒自动检查DNS更新" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔧 配置文件: $InstallPath\appsettings.json" -ForegroundColor Yellow
    Write-Host "🗑️ 卸载程序: 运行 uninstall-startup.ps1" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

} catch {
    Write-Host "❌ 安装失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "请检查错误信息并重试。" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "按任意键退出..." -ForegroundColor Gray
pause