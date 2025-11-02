# DNS API 服务监控脚本
# 功能: 定期检查服务状态，失败时发送邮件告警并尝试自动修复
# 使用: 配合 Windows 任务计划程序，每 5 分钟运行一次

param(
    [string]$LogFile = "K:\DNS\logs\monitor.log",
    [switch]$EnableAutoFix = $true,
    [switch]$EnableAlert = $true,
    [string]$AlertType = "email",  # file, email
    [string]$EmailTo = "qsoft@139.com",
    [string]$EmailFrom = "qsoft@139.com",
    [string]$SmtpServer = "smtp.139.com",
    [int]$SmtpPort = 25,
    [string]$SmtpUser = "qsoft@139.com",
    [string]$SmtpPassword = "574a283d502db51ea200"
)

$SSH_KEY = "C:\Key\tx.qsgl.net_id_ed25519"
$SERVER = "43.138.35.183"
$SERVICE_URL = "https://tx.qsgl.net:5075"
$CONTAINER_NAME = "dnsapi"
$CHECK_TIMEOUT = 10
$SSH_KEY = "C:\Key\tx.qsgl.net_id_ed25519"
$SERVER = "43.138.35.183"
$SERVICE_URL = "https://tx.qsgl.net:5075"
$CONTAINER_NAME = "dnsapi"
$CHECK_TIMEOUT = 10

# 确保日志目录存在
$logDir = Split-Path $LogFile -Parent
if ($logDir -and !(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# 写日志函数
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor White }
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

# 发送邮件告警函数
function Send-EmailAlert {
    param(
        [string]$Subject,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # HTML 邮件正文
    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Microsoft YaHei', Arial, sans-serif; background-color: #f5f5f5; padding: 20px; }
        .container { background-color: white; border-radius: 8px; padding: 30px; max-width: 600px; margin: 0 auto; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background-color: #d32f2f; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .header h2 { margin: 0; }
        .info-box { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 15px 0; }
        .detail-box { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .label { font-weight: bold; color: #555; }
        .value { color: #333; margin-left: 10px; }
        .footer { margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>🚨 DNS API 服务告警</h2>
            <p style="margin: 5px 0 0 0;">$Subject</p>
        </div>
        
        <div class="info-box">
            <strong>⚠️ 检测到服务异常，请及时处理！</strong>
        </div>
        
        <div class="detail-box">
            <p><span class="label">告警时间:</span><span class="value">$timestamp</span></p>
            <p><span class="label">服务器:</span><span class="value">$SERVER (tx.qsgl.net)</span></p>
            <p><span class="label">服务地址:</span><span class="value">$SERVICE_URL</span></p>
            <p><span class="label">容器名称:</span><span class="value">$CONTAINER_NAME</span></p>
        </div>
        
        <h3>📋 异常详情</h3>
        <pre>$Message</pre>
        
        <div class="footer">
            <p>此邮件由 DNS API 监控系统自动发送</p>
            <p>监控脚本: K:\DNS\monitor-dnsapi-service.ps1</p>
        </div>
    </div>
</body>
</html>
"@
    
    try {
        Write-Log "准备发送邮件告警到: $EmailTo" "INFO"
        
        $emailParams = @{
            To = $EmailTo
            From = $EmailFrom
            Subject = "【DNS API 告警】$Subject"
            Body = $htmlBody
            BodyAsHtml = $true
            SmtpServer = $SmtpServer
            Port = $SmtpPort
            Encoding = [System.Text.Encoding]::UTF8
        }
        
        # 如果提供了SMTP认证信息
        if ($SmtpUser -and $SmtpPassword) {
            $securePassword = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($SmtpUser, $securePassword)
            $emailParams.Credential = $credential
            $emailParams.UseSsl = $true
        }
        
        Send-MailMessage @emailParams
        Write-Log "✓ 邮件告警已成功发送到: $EmailTo" "SUCCESS"
        return $true
    } catch {
        Write-Log "✗ 发送邮件失败: $_" "ERROR"
        Write-Log "请检查 SMTP 配置或网络连接" "WARN"
        
        # 邮件发送失败时，保存到本地文件
        $alertFile = Join-Path (Split-Path $LogFile -Parent) "alerts.log"
        $alertContent = @"

========================================
告警时间: $timestamp
========================================
$Subject

$Message

服务器: $SERVER
服务URL: $SERVICE_URL
容器: $CONTAINER_NAME
========================================

"@
        Add-Content -Path $alertFile -Value $alertContent
        Write-Log "告警已保存到本地文件: $alertFile" "INFO"
        return $false
    }
}




# 主监控逻辑
Write-Log "========== 开始监控检查 ==========" "INFO"

$hasError = $false
$errorDetails = @()
$needsFix = $false

# 1. PING 测试
Write-Log "检查网络连通性..." "INFO"
$pingTest = Test-Connection -ComputerName $SERVER -Count 1 -Quiet
if ($pingTest) {
    Write-Log "✓ 服务器 PING 测试通过" "SUCCESS"
} else {
    $hasError = $true
    $errorDetails += "✗ 服务器 $SERVER 无法 PING 通"
    Write-Log "✗ 服务器无法 PING 通" "ERROR"
}

# 2. 端口测试
Write-Log "检查端口 5075..." "INFO"
$portTest = Test-NetConnection -ComputerName $SERVER -Port 5075 -WarningAction SilentlyContinue
if ($portTest.TcpTestSucceeded) {
    Write-Log "✓ 端口 5075 可访问" "SUCCESS"
} else {
    $hasError = $true
    $needsFix = $true
    $errorDetails += "✗ 端口 5075 无法访问"
    Write-Log "✗ 端口 5075 无法访问" "ERROR"
}

# 3. HTTPS 健康检查
Write-Log "检查 HTTPS 服务..." "INFO"
try {
    $health = curl.exe -k -s --max-time $CHECK_TIMEOUT "$SERVICE_URL/api/health" | ConvertFrom-Json
    if ($health.status -eq "healthy") {
        Write-Log "✓ HTTPS 服务健康: $($health.status)" "SUCCESS"
    } else {
        $hasError = $true
        $errorDetails += "✗ 服务状态异常: $($health.status)"
        Write-Log "✗ 服务状态异常: $($health.status)" "ERROR"
    }
} catch {
    $hasError = $true
    $needsFix = $true
    $errorDetails += "✗ HTTPS 服务无响应或返回错误"
    Write-Log "✗ HTTPS 服务无响应" "ERROR"
}

# 4. Docker 容器状态
Write-Log "检查 Docker 容器..." "INFO"
try {
    $status = ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker ps --filter name=$CONTAINER_NAME --format '{{.Status}}'" 2>$null
    if ($status -match "Up") {
        Write-Log "✓ 容器运行中: $status" "SUCCESS"
        
        # 检查重启策略
        $restartPolicy = ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker inspect $CONTAINER_NAME --format '{{.HostConfig.RestartPolicy.Name}}'" 2>$null
        if ($restartPolicy -ne "unless-stopped") {
            Write-Log "⚠ 重启策略为 '$restartPolicy'，建议为 'unless-stopped'" "WARN"
            $errorDetails += "⚠ 重启策略不是 unless-stopped (当前: $restartPolicy)"
            $needsFix = $true
        } else {
            Write-Log "✓ 重启策略正确: $restartPolicy" "SUCCESS"
        }
    } else {
        $hasError = $true
        $needsFix = $true
        $errorDetails += "✗ 容器未运行: $status"
        Write-Log "✗ 容器未运行: $status" "ERROR"
    }
} catch {
    $hasError = $true
    $errorDetails += "✗ 无法检查容器状态: $_"
    Write-Log "✗ 容器检查异常: $_" "ERROR"
}

# 自动修复逻辑
if ($needsFix -and $EnableAutoFix) {
    Write-Log "========== 开始自动修复 ==========" "WARN"
    
    try {
        # 检查容器是否存在
        $containerExists = ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker ps -a --filter name=$CONTAINER_NAME --format '{{.Names}}'" 2>$null
        
        if ($containerExists -eq $CONTAINER_NAME) {
            # 启动容器
            Write-Log "尝试启动容器..." "INFO"
            $startResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker start $CONTAINER_NAME" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ 容器已启动" "SUCCESS"
                $errorDetails += "`n--- 自动修复操作 ---"
                $errorDetails += "✓ 容器已重新启动"
                
                # 设置重启策略
                Write-Log "设置重启策略为 unless-stopped..." "INFO"
                ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker update --restart=unless-stopped $CONTAINER_NAME" 2>&1 | Out-Null
                Write-Log "✓ 重启策略已更新" "SUCCESS"
                $errorDetails += "✓ 重启策略已设置为 unless-stopped"
                
                # 等待服务启动
                Start-Sleep -Seconds 5
                
                # 验证服务是否正常
                try {
                    $healthCheck = curl.exe -k -s --max-time 10 "$SERVICE_URL/api/health" | ConvertFrom-Json
                    if ($healthCheck.status -eq "healthy") {
                        Write-Log "✓ 服务修复成功并已恢复正常" "SUCCESS"
                        $errorDetails += "✓ 服务已恢复正常运行"
                        $hasError = $false  # 修复成功，清除错误标记
                    } else {
                        Write-Log "⚠ 服务已启动但状态异常: $($healthCheck.status)" "WARN"
                        $errorDetails += "⚠ 服务已启动但状态仍异常"
                    }
                } catch {
                    Write-Log "⚠ 服务已启动但健康检查仍失败" "WARN"
                    $errorDetails += "⚠ 服务已启动但健康检查仍失败"
                }
            } else {
                Write-Log "✗ 启动容器失败: $startResult" "ERROR"
                $errorDetails += "✗ 自动修复失败: $startResult"
            }
        } else {
            Write-Log "✗ 容器不存在，无法自动修复" "ERROR"
            $errorDetails += "✗ 容器不存在，需要人工处理"
        }
    } catch {
        Write-Log "✗ 自动修复过程出错: $_" "ERROR"
        $errorDetails += "✗ 自动修复异常: $_"
    }
    
    Write-Log "========== 自动修复完成 ==========" "WARN"
}

# 发送告警
if ($hasError -and $EnableAlert) {
    $errorMessage = $errorDetails -join "`n"
    
    if ($AlertType -eq "email") {
        Send-EmailAlert -Subject "服务异常检测" -Message $errorMessage
    } else {
        # 文件告警
        $alertFile = Join-Path (Split-Path $LogFile -Parent) "alerts.log"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $alertContent = @"

========================================
告警时间: $timestamp
========================================
$errorMessage

服务器: $SERVER
服务URL: $SERVICE_URL
容器: $CONTAINER_NAME
========================================

"@
        Add-Content -Path $alertFile -Value $alertContent
        Write-Log "告警已记录到: $alertFile" "INFO"
    }
} elseif (!$hasError) {
    Write-Log "✓ 所有检查通过，服务运行正常" "SUCCESS"
}

Write-Log "========== 监控检查结束 ==========`n" "INFO"

# 返回状态码
exit $(if ($hasError) { 1 } else { 0 })
