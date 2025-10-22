# DNS更新器卸载脚本
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

Write-Host "🗑️ DNS自动更新器卸载程序" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

try {
    # 1. 停止运行的程序
    Write-Host "⏹️ 停止DNS更新器进程..." -ForegroundColor Yellow
    $processes = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue
    if ($processes) {
        foreach ($process in $processes) {
            $process.Kill()
            Write-Host "  ✅ 已停止进程 PID: $($process.Id)" -ForegroundColor Green
        }
        Start-Sleep 2
    } else {
        Write-Host "  ℹ️ 没有找到运行中的DNS更新器进程" -ForegroundColor Gray
    }

    # 2. 删除开机启动设置
    Write-Host "🔑 删除开机自启动设置..." -ForegroundColor Yellow
    
    # 2.1 删除注册表启动项
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $appName = "DNSUpdaterTray"
    
    try {
        Remove-ItemProperty -Path $registryPath -Name $appName -ErrorAction Stop
        Write-Host "  ✅ 系统注册表启动项已删除" -ForegroundColor Green
    } catch {
        Write-Host "  ℹ️  系统注册表启动项不存在或已删除" -ForegroundColor Gray
    }
    
    # 2.2 删除用户启动文件夹快捷方式
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder "DNS自动更新器.lnk"
    
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "  ✅ 用户启动文件夹快捷方式已删除" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️  用户启动文件夹快捷方式不存在" -ForegroundColor Gray
    }
    
    # 2.3 删除防火墙规则
    try {
        $firewallRule = Get-NetFirewallRule -DisplayName "DNS自动更新器" -ErrorAction SilentlyContinue
        if ($firewallRule) {
            Remove-NetFirewallRule -DisplayName "DNS自动更新器" -ErrorAction Stop
            Write-Host "  ✅ 防火墙规则已删除" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  防火墙规则不存在" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ⚠️  防火墙规则删除失败（可忽略）" -ForegroundColor Yellow
    }

    # 3. 删除安装目录
    Write-Host "📁 删除安装目录: $InstallPath" -ForegroundColor Yellow
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
        Write-Host "  ✅ 安装目录已删除" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️ 安装目录不存在" -ForegroundColor Gray
    }



    # 4. 清理用户配置（可选）
    Write-Host "🧹 清理用户配置..." -ForegroundColor Yellow
    $userConfigPath = Join-Path $env:APPDATA "DNSUpdaterTray"
    
    if (Test-Path $userConfigPath) {
        $deleteConfig = Read-Host "是否删除用户配置文件？(包含DNS设置) [y/N]"
        if ($deleteConfig -eq 'y' -or $deleteConfig -eq 'Y') {
            Remove-Item $userConfigPath -Recurse -Force
            Write-Host "  ✅ 用户配置已删除" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  保留用户配置文件: $userConfigPath" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ℹ️  无用户配置文件" -ForegroundColor Gray
    }

    # 5. 卸载完成
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 卸载完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 已执行的操作:" -ForegroundColor Cyan
    Write-Host "  • 停止所有DNS更新器进程" -ForegroundColor Gray
    Write-Host "  • 删除系统注册表启动项" -ForegroundColor Gray
    Write-Host "  • 删除用户启动文件夹快捷方式" -ForegroundColor Gray
    Write-Host "  • 删除防火墙规则" -ForegroundColor Gray
    Write-Host "  • 删除程序安装目录" -ForegroundColor Gray
    Write-Host "  • 清理系统托盘图标" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 注意事项:" -ForegroundColor Yellow
    Write-Host "• 如果托盘图标仍然显示，请重启系统" -ForegroundColor Gray
    Write-Host "• 配置文件和日志已完全删除" -ForegroundColor Gray
    Write-Host "• 如需重新安装，请运行 install-startup.ps1" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan

} catch {
    Write-Host "❌ 卸载过程中发生错误: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "请手动删除以下内容:" -ForegroundColor Yellow
    Write-Host "1. 进程: 任务管理器中结束 DNSUpdaterTray.exe" -ForegroundColor Gray
    Write-Host "2. 文件: 删除目录 $InstallPath" -ForegroundColor Gray
    Write-Host "3. 注册表: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run 中的 DNSUpdaterTray 项" -ForegroundColor Gray
}

Write-Host "按任意键退出..." -ForegroundColor Gray
pause