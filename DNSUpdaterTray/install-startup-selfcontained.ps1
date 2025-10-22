# DNS更新器 - 自包含版本安装脚本
# 用于从便携式包安装并设置开机自启动
# 需要管理员权限运行

param(
    [string]$InstallPath = "C:\Program Files\DNSUpdaterTray"
)

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "❌ 此脚本需要管理员权限运行！" -ForegroundColor Red
    Write-Host "请右键点击PowerShell并选择'以管理员身份运行'，然后重新执行此脚本。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "或者右键点击此脚本文件，选择'以管理员身份运行'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "🚀 DNS自动更新器 - 系统安装程序" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # 0. 停止已运行的实例
    Write-Host "🔍 检查运行中的实例..." -ForegroundColor Yellow
    $runningProcess = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue
    if ($runningProcess) {
        Write-Host "⚠️  发现运行中的DNS更新器，正在停止..." -ForegroundColor Yellow
        $runningProcess | Stop-Process -Force
        Start-Sleep -Seconds 2
        Write-Host "  ✅ 已停止旧实例" -ForegroundColor Green
    } else {
        Write-Host "  ✅ 无运行中的实例" -ForegroundColor Green
    }

    # 1. 创建安装目录
    Write-Host ""
    Write-Host "📁 准备安装目录..." -ForegroundColor Yellow
    Write-Host "   目标路径: $InstallPath" -ForegroundColor Cyan
    
    if (Test-Path $InstallPath) {
        Write-Host "   检测到已存在的安装，正在清理..." -ForegroundColor Yellow
        Remove-Item $InstallPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "  ✅ 安装目录已就绪" -ForegroundColor Green

    # 2. 复制自包含程序文件（从当前目录或指定源目录）
    Write-Host ""
    Write-Host "📋 复制程序文件..." -ForegroundColor Yellow
    
    # 检测源目录（支持多个可能的位置）
    $possibleSources = @(
        ".",  # 当前目录（便携式包解压后的位置）
        "..\publish-selfcontained",  # 从项目目录运行
        "publish-selfcontained"  # 从项目根目录运行
    )
    
    $sourceDir = $null
    foreach ($src in $possibleSources) {
        $testPath = Join-Path $src "DNSUpdaterTray.exe"
        if (Test-Path $testPath) {
            $sourceDir = $src
            break
        }
    }
    
    if (-not $sourceDir) {
        throw "未找到DNS更新器程序文件！请确保在正确的目录运行此脚本。"
    }
    
    Write-Host "   源目录: $sourceDir" -ForegroundColor Cyan
    
    # 复制所有文件
    $sourceFiles = Get-ChildItem $sourceDir -Recurse
    $copiedCount = 0
    foreach ($file in $sourceFiles) {
        if (-not $file.PSIsContainer) {
            $relativePath = $file.FullName.Substring((Resolve-Path $sourceDir).Path.Length + 1)
            $targetPath = Join-Path $InstallPath $relativePath
            $targetDir = Split-Path $targetPath -Parent
            
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            
            Copy-Item $file.FullName $targetPath -Force
            $copiedCount++
        }
    }
    
    Write-Host "  ✅ 已复制 $copiedCount 个文件" -ForegroundColor Green

    # 3. 设置开机自启动（用户级）
    Write-Host ""
    Write-Host "🔑 配置开机自启动..." -ForegroundColor Yellow
    
    # 方式1: 当前用户启动文件夹（推荐，无需管理员权限）
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder "DNS自动更新器.lnk"
    $exePath = Join-Path $InstallPath "DNSUpdaterTray.exe"
    
    # 创建快捷方式
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath
    $shortcut.WorkingDirectory = $InstallPath
    $shortcut.Description = "DNS自动更新器 - 自动更新动态DNS记录"
    $shortcut.WindowStyle = 7  # 最小化启动
    $shortcut.Save()
    
    Write-Host "  ✅ 用户启动文件夹快捷方式已创建" -ForegroundColor Green
    Write-Host "     路径: $shortcutPath" -ForegroundColor Cyan
    
    # 方式2: 注册表启动项（系统级，所有用户）
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        $appName = "DNSUpdaterTray"
        
        # 检查注册表项是否存在
        $existingValue = Get-ItemProperty -Path $registryPath -Name $appName -ErrorAction SilentlyContinue
        if ($existingValue) {
            Write-Host "  ⚠️  检测到已存在的注册表启动项，正在更新..." -ForegroundColor Yellow
        }
        
        Set-ItemProperty -Path $registryPath -Name $appName -Value "`"$exePath`"" -Force
        Write-Host "  ✅ 系统注册表启动项已设置" -ForegroundColor Green
        Write-Host "     注册表: $registryPath\$appName" -ForegroundColor Cyan
    } catch {
        Write-Host "  ⚠️  注册表启动项设置失败: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "     程序仍将通过用户启动文件夹自动启动" -ForegroundColor Gray
    }

    # 4. 配置防火墙规则（可选）
    Write-Host ""
    $configFirewall = Read-Host "是否配置Windows防火墙规则？(建议配置) [Y/n]"
    if ($configFirewall -ne 'n' -and $configFirewall -ne 'N') {
        Write-Host "🔥 配置防火墙规则..." -ForegroundColor Yellow
        try {
            # 删除旧规则（如果存在）
            $existingRule = Get-NetFirewallRule -DisplayName "DNS自动更新器" -ErrorAction SilentlyContinue
            if ($existingRule) {
                Remove-NetFirewallRule -DisplayName "DNS自动更新器" -ErrorAction SilentlyContinue
                Write-Host "  ℹ️  已删除旧的防火墙规则" -ForegroundColor Cyan
            }
            
            # 创建新规则
            New-NetFirewallRule -DisplayName "DNS自动更新器" `
                                -Description "允许DNS更新器访问网络进行DNS记录更新" `
                                -Direction Outbound `
                                -Program $exePath `
                                -Action Allow `
                                -Profile Any `
                                -Enabled True | Out-Null
            
            Write-Host "  ✅ 防火墙规则已配置" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  防火墙配置失败: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "     程序仍可正常使用，但可能被防火墙提示" -ForegroundColor Gray
        }
    }

    # 5. 启动程序
    Write-Host ""
    Write-Host "🚀 启动DNS更新器..." -ForegroundColor Yellow
    
    # 使用Start-Process而不是直接运行，避免阻塞
    Start-Process -FilePath $exePath -WorkingDirectory $InstallPath -WindowStyle Hidden
    
    # 等待程序启动
    Write-Host "   等待程序启动..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    
    # 检查是否启动成功
    $process = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "  ✅ 程序已成功启动（PID: $($process.Id)）" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  程序可能未正常启动，请检查任务栏托盘区域" -ForegroundColor Yellow
        Write-Host "     您也可以手动运行: $exePath" -ForegroundColor Gray
    }

    # 6. 安装完成信息
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 安装完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📍 安装信息:" -ForegroundColor Yellow
    Write-Host "   安装位置: $InstallPath" -ForegroundColor Cyan
    Write-Host "   程序大小: $('{0:N2}' -f ((Get-ChildItem $InstallPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔄 开机自启动: ✅ 已启用" -ForegroundColor Green
    Write-Host "   方式1: 用户启动文件夹快捷方式" -ForegroundColor Cyan
    Write-Host "   方式2: 系统注册表启动项（HKLM）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎯 托盘图标: 请查看任务栏右下角的咖啡杯图标 ☕" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 使用说明:" -ForegroundColor Yellow
    Write-Host "   • 右键托盘图标 → 查看菜单选项" -ForegroundColor Gray
    Write-Host "   • 双击托盘图标 → 立即检查更新" -ForegroundColor Gray
    Write-Host "   • 右键 → 设置 → 配置DNS参数" -ForegroundColor Gray
    Write-Host "   • 右键 → 状态信息 → 查看运行状态" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📁 配置文件位置:" -ForegroundColor Yellow
    Write-Host "   程序配置: $InstallPath\appsettings.json" -ForegroundColor Cyan
    Write-Host "   用户配置: %AppData%\DNSUpdaterTray\user-config.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🗑️  如需卸载:" -ForegroundColor Yellow
    Write-Host "   方式1: 运行 $InstallPath\uninstall-startup.ps1" -ForegroundColor Cyan
    Write-Host "   方式2: 手动删除安装目录和启动项" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✨ 程序已设置为开机自启动，重启后自动运行！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan

    # 7. 验证开机启动配置
    Write-Host ""
    Write-Host "🔍 验证开机启动配置..." -ForegroundColor Yellow
    
    # 检查启动文件夹快捷方式
    if (Test-Path $shortcutPath) {
        Write-Host "  ✅ 启动文件夹快捷方式: 正常" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  启动文件夹快捷方式: 未找到" -ForegroundColor Yellow
    }
    
    # 检查注册表项
    $regValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "DNSUpdaterTray" -ErrorAction SilentlyContinue
    if ($regValue) {
        Write-Host "  ✅ 注册表启动项: 正常" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  注册表启动项: 未找到（仍可通过快捷方式启动）" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "✅ 所有配置已完成！程序将在系统重启后自动启动。" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ 安装失败！" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "错误详情: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "  • 缺少必要的程序文件" -ForegroundColor Gray
    Write-Host "  • 安装路径无权限" -ForegroundColor Gray
    Write-Host "  • 系统资源不足" -ForegroundColor Gray
    Write-Host ""
    Write-Host "请检查错误信息并重试。" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor Gray
pause
