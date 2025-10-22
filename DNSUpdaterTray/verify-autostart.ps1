# DNS更新器 - 开机自启动验证脚本

Write-Host "=== DNS自动更新器 - 开机自启动验证 ===" -ForegroundColor Cyan
Write-Host ""

$hasErrors = $false

# 1. 检查程序文件
Write-Host "1. 检查程序安装..." -ForegroundColor Yellow
$installPath = "C:\Program Files\DNSUpdaterTray"
$exePath = Join-Path $installPath "DNSUpdaterTray.exe"

if (Test-Path $exePath) {
    $fileInfo = Get-Item $exePath
    Write-Host "   ✅ 程序已安装" -ForegroundColor Green
    Write-Host "      路径: $exePath" -ForegroundColor Cyan
    Write-Host "      大小: $('{0:N2}' -f ($fileInfo.Length / 1MB)) MB" -ForegroundColor Cyan
    Write-Host "      修改时间: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ 程序未安装" -ForegroundColor Red
    Write-Host "      请先运行 install-startup.ps1 安装程序" -ForegroundColor Yellow
    $hasErrors = $true
}

# 2. 检查进程状态
Write-Host ""
Write-Host "2. 检查运行状态..." -ForegroundColor Yellow
$process = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue

if ($process) {
    Write-Host "   ✅ 程序正在运行" -ForegroundColor Green
    Write-Host "      进程ID: $($process.Id)" -ForegroundColor Cyan
    Write-Host "      内存占用: $('{0:N2}' -f ($process.WorkingSet64 / 1MB)) MB" -ForegroundColor Cyan
    Write-Host "      运行时间: $([math]::Round(($process.TotalProcessorTime.TotalSeconds), 2)) 秒 CPU时间" -ForegroundColor Cyan
} else {
    Write-Host "   ⚠️  程序未运行" -ForegroundColor Yellow
    Write-Host "      尝试手动启动程序以测试..." -ForegroundColor Cyan
    
    if (Test-Path $exePath) {
        try {
            Start-Process -FilePath $exePath -WindowStyle Hidden
            Start-Sleep -Seconds 2
            $process = Get-Process "DNSUpdaterTray" -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "   ✅ 程序启动成功" -ForegroundColor Green
            } else {
                Write-Host "   ❌ 程序启动失败" -ForegroundColor Red
                $hasErrors = $true
            }
        } catch {
            Write-Host "   ❌ 启动失败: $($_.Exception.Message)" -ForegroundColor Red
            $hasErrors = $true
        }
    }
}

# 3. 检查启动文件夹快捷方式
Write-Host ""
Write-Host "3. 检查用户启动文件夹..." -ForegroundColor Yellow
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder "DNS自动更新器.lnk"

if (Test-Path $shortcutPath) {
    Write-Host "   ✅ 启动快捷方式已配置" -ForegroundColor Green
    Write-Host "      路径: $shortcutPath" -ForegroundColor Cyan
    
    # 验证快捷方式目标
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        Write-Host "      目标: $($shortcut.TargetPath)" -ForegroundColor Cyan
        
        if ($shortcut.TargetPath -eq $exePath) {
            Write-Host "      ✅ 目标路径正确" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  目标路径不匹配" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "      ⚠️  无法验证快捷方式: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ 启动快捷方式未配置" -ForegroundColor Red
    Write-Host "      应该位于: $shortcutPath" -ForegroundColor Yellow
    $hasErrors = $true
}

# 4. 检查注册表启动项
Write-Host ""
Write-Host "4. 检查系统注册表启动项..." -ForegroundColor Yellow
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$appName = "DNSUpdaterTray"

try {
    $regValue = Get-ItemProperty -Path $registryPath -Name $appName -ErrorAction Stop
    Write-Host "   ✅ 注册表启动项已配置" -ForegroundColor Green
    Write-Host "      注册表路径: $registryPath" -ForegroundColor Cyan
    Write-Host "      键名: $appName" -ForegroundColor Cyan
    Write-Host "      值: $($regValue.$appName)" -ForegroundColor Cyan
    
    # 验证路径
    $regExePath = $regValue.$appName -replace '"', ''
    if ($regExePath -eq $exePath) {
        Write-Host "      ✅ 路径正确" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  路径不匹配" -ForegroundColor Yellow
        Write-Host "         预期: $exePath" -ForegroundColor Gray
        Write-Host "         实际: $regExePath" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠️  注册表启动项未配置" -ForegroundColor Yellow
    Write-Host "      这不影响自启动（通过快捷方式仍可启动）" -ForegroundColor Gray
}

# 5. 检查防火墙规则
Write-Host ""
Write-Host "5. 检查防火墙规则..." -ForegroundColor Yellow

try {
    $firewallRule = Get-NetFirewallRule -DisplayName "DNS自动更新器" -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Write-Host "   ✅ 防火墙规则已配置" -ForegroundColor Green
        Write-Host "      规则名称: DNS自动更新器" -ForegroundColor Cyan
        Write-Host "      状态: $($firewallRule.Enabled)" -ForegroundColor Cyan
        Write-Host "      方向: $($firewallRule.Direction)" -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️  防火墙规则未配置" -ForegroundColor Yellow
        Write-Host "      这可能导致首次运行时出现防火墙提示" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠️  无法检查防火墙规则" -ForegroundColor Yellow
}

# 6. 检查配置文件
Write-Host ""
Write-Host "6. 检查配置文件..." -ForegroundColor Yellow

# 检查程序配置
$appSettingsPath = Join-Path $installPath "appsettings.json"
if (Test-Path $appSettingsPath) {
    Write-Host "   ✅ 程序配置文件存在" -ForegroundColor Green
    Write-Host "      路径: $appSettingsPath" -ForegroundColor Cyan
} else {
    Write-Host "   ⚠️  程序配置文件缺失" -ForegroundColor Yellow
}

# 检查用户配置
$userConfigPath = Join-Path $env:APPDATA "DNSUpdaterTray\user-config.json"
if (Test-Path $userConfigPath) {
    Write-Host "   ✅ 用户配置文件存在" -ForegroundColor Green
    Write-Host "      路径: $userConfigPath" -ForegroundColor Cyan
    
    try {
        $config = Get-Content $userConfigPath | ConvertFrom-Json
        Write-Host "      子域名: $($config.SubDomain)" -ForegroundColor Cyan
        Write-Host "      域名: $($config.Domain)" -ForegroundColor Cyan
        Write-Host "      更新间隔: $($config.UpdateInterval) 秒" -ForegroundColor Cyan
    } catch {
        Write-Host "      ⚠️  配置文件格式错误" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ℹ️  用户配置文件不存在" -ForegroundColor Gray
    Write-Host "      首次运行后会自动创建" -ForegroundColor Gray
}

# 7. 总结
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if (-not $hasErrors) {
    Write-Host "✅ 验证通过！开机自启动已正确配置" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步操作：" -ForegroundColor Yellow
    Write-Host "  1. 重启电脑测试自动启动" -ForegroundColor Gray
    Write-Host "  2. 登录后查看任务栏托盘图标" -ForegroundColor Gray
    Write-Host "  3. 右键图标配置DNS参数" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 提示: 使用以下命令重启测试" -ForegroundColor Cyan
    Write-Host "   Restart-Computer" -ForegroundColor Gray
} else {
    Write-Host "⚠️  发现问题，请检查上述错误" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "建议操作：" -ForegroundColor Yellow
    Write-Host "  1. 以管理员身份重新运行 install-startup.ps1" -ForegroundColor Gray
    Write-Host "  2. 检查防病毒软件是否拦截" -ForegroundColor Gray
    Write-Host "  3. 查看Windows事件日志获取详细错误" -ForegroundColor Gray
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
