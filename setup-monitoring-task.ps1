# 配置 Windows 任务计划程序，定期运行监控脚本
# 运行此脚本需要管理员权限

param(
    [string]$ScriptPath = "K:\DNS\monitor-dnsapi-service.ps1",
    [string]$TaskName = "DNS API 服务监控",
    [int]$IntervalMinutes = 5,
    [switch]$EnableAutoFix = $true,
    [switch]$EnableAlert = $true,
    [string]$AlertType = "file"  # file, email, webhook
)

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "❌ 此脚本需要管理员权限运行" -ForegroundColor Red
    Write-Host ""
    Write-Host "请以管理员身份运行 PowerShell，然后重新执行此脚本" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "配置 Windows 任务计划 - DNS API 监控" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 验证监控脚本存在
if (!(Test-Path $ScriptPath)) {
    Write-Host "❌ 监控脚本不存在: $ScriptPath" -ForegroundColor Red
    exit 1
}

# 删除已存在的任务（如果有）
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "发现已存在的任务，正在删除..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "  ✅ 已删除旧任务" -ForegroundColor Green
}

# 构建脚本参数
$scriptArgs = ""
if ($EnableAutoFix) {
    $scriptArgs += " -EnableAutoFix"
}
if ($EnableAlert) {
    $scriptArgs += " -EnableAlert"
}
if ($AlertType) {
    $scriptArgs += " -AlertType $AlertType"
}

# 创建任务操作
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"$scriptArgs"

# 创建触发器（每 N 分钟运行一次）
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# 创建任务设置
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# 创建任务主体（使用 SYSTEM 账户运行）
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 注册任务
Write-Host "正在创建任务计划..." -ForegroundColor Yellow
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "自动监控 DNS API 服务 (https://tx.qsgl.net:5075)，检测服务状态并在异常时自动修复" | Out-Null

Write-Host "  ✅ 任务计划创建成功" -ForegroundColor Green
Write-Host ""

# 验证任务
$task = Get-ScheduledTask -TaskName $TaskName
if ($task) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 任务计划配置完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "任务信息:" -ForegroundColor Yellow
    Write-Host "  任务名称: $TaskName" -ForegroundColor White
    Write-Host "  执行脚本: $ScriptPath" -ForegroundColor White
    Write-Host "  运行频率: 每 $IntervalMinutes 分钟" -ForegroundColor White
    Write-Host "  自动修复: $($EnableAutoFix ? '启用' : '禁用')" -ForegroundColor $(if($EnableAutoFix){'Green'}else{'Yellow'})
    Write-Host "  告警功能: $($EnableAlert ? '启用' : '禁用')" -ForegroundColor $(if($EnableAlert){'Green'}else{'Yellow'})
    Write-Host "  告警方式: $AlertType" -ForegroundColor White
    Write-Host "  任务状态: $($task.State)" -ForegroundColor White
    Write-Host ""
    Write-Host "日志位置:" -ForegroundColor Yellow
    Write-Host "  监控日志: K:\DNS\logs\monitor.log" -ForegroundColor White
    Write-Host "  告警日志: K:\DNS\logs\alerts.log" -ForegroundColor White
    Write-Host ""
    Write-Host "管理命令:" -ForegroundColor Yellow
    Write-Host "  # 立即运行一次" -ForegroundColor Cyan
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 查看任务状态" -ForegroundColor Cyan
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 禁用任务" -ForegroundColor Cyan
    Write-Host "  Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 启用任务" -ForegroundColor Cyan
    Write-Host "  Enable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 删除任务" -ForegroundColor Cyan
    Write-Host "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 查看监控日志" -ForegroundColor Cyan
    Write-Host "  Get-Content K:\DNS\logs\monitor.log -Tail 50" -ForegroundColor White
    Write-Host ""
    
    # 询问是否立即运行一次测试
    Write-Host "是否立即运行一次测试? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "正在运行测试..." -ForegroundColor Cyan
        Start-ScheduledTask -TaskName $TaskName
        
        Write-Host "  ✅ 任务已启动" -ForegroundColor Green
        Write-Host ""
        Write-Host "等待 5 秒..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        
        Write-Host ""
        Write-Host "最新日志:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Gray
        
        $logFile = "K:\DNS\logs\monitor.log"
        if (Test-Path $logFile) {
            Get-Content $logFile -Tail 30
        } else {
            Write-Host "  日志文件尚未创建" -ForegroundColor Yellow
        }
    }
    
} else {
    Write-Host "❌ 任务创建失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "配置完成！监控系统将在后台运行。" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
