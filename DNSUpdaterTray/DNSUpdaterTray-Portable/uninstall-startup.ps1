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

    # 2. 删除开机启动注册表项
    Write-Host "🔑 删除开机自启动设置..." -ForegroundColor Yellow
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $appName = "DNSUpdaterTray"
    
    try {
        Remove-ItemProperty -Path $registryPath -Name $appName -ErrorAction Stop
        Write-Host "  ✅ 注册表项已删除" -ForegroundColor Green
    } catch {
        Write-Host "  ℹ️ 注册表项不存在或已删除" -ForegroundColor Gray
    }

    # 3. 删除安装目录
    Write-Host "📁 删除安装目录: $InstallPath" -ForegroundColor Yellow
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
        Write-Host "  ✅ 安装目录已删除" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️ 安装目录不存在" -ForegroundColor Gray
    }

    # 4. 清理任务栏托盘
    Write-Host "🧹 清理系统托盘..." -ForegroundColor Yellow
    Write-Host "  ℹ️ 请手动检查任务栏右下角，确认托盘图标已消失" -ForegroundColor Gray

    # 5. 卸载完成
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 卸载完成！" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 已执行的操作:" -ForegroundColor Cyan
    Write-Host "• 停止所有DNS更新器进程" -ForegroundColor Gray
    Write-Host "• 删除开机自启动设置" -ForegroundColor Gray
    Write-Host "• 删除程序安装目录" -ForegroundColor Gray
    Write-Host "• 清理系统托盘图标" -ForegroundColor Gray
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