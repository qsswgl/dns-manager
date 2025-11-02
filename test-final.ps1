# 邮件发送测试
Write-Host "========== 测试邮件发送 ==========" -ForegroundColor Cyan
Write-Host ""

$EmailTo = "qsoft@139.com"
$EmailFrom = "qsoft@139.com"
$SmtpServer = "smtp.139.com"
$SmtpPort = 465
$SmtpUser = "qsoft@139.com"
$SmtpPassword = "574a283d502db51ea200"

Write-Host "配置信息:" -ForegroundColor Yellow
Write-Host "  收件人: $EmailTo"
Write-Host "  发件人: $EmailFrom"
Write-Host "  SMTP: $SmtpServer`:$SmtpPort"
Write-Host "  认证: 已启用"
Write-Host ""
Write-Host "正在发送测试邮件..." -ForegroundColor White

try {
    $securePassword = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($SmtpUser, $securePassword)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $subject = "[测试] DNS API 监控系统 - $timestamp"
    
    $htmlBody = @"
<!DOCTYPE html>
<html>
<head><meta charset=UTF-8>
<style>
body{font-family:Microsoft YaHei,Arial;background:#f5f5f5;padding:20px}
.container{background:white;border-radius:8px;padding:30px;max-width:600px;margin:0 auto;box-shadow:0 2px 4px rgba(0,0,0,0.1)}
.header{background:#4CAF50;color:white;padding:20px;border-radius:5px;margin-bottom:20px}
.info{background:#e8f5e9;border-left:4px solid #4CAF50;padding:15px;margin:15px 0}
.detail{background:#f8f9fa;padding:15px;border-radius:5px;margin:15px 0}
</style>
</head>
<body>
<div class=container>
<div class=header>
<h2>DNS API 监控系统测试</h2>
<p>邮件告警功能测试成功</p>
</div>
<div class=info>
<strong>如果您收到此邮件，说明邮件告警配置成功！</strong>
</div>
<div class=detail>
<p><strong>测试时间:</strong> $timestamp</p>
<p><strong>收件人:</strong> $EmailTo</p>
<p><strong>监控脚本:</strong> K:\DNS\monitor-dnsapi-service.ps1</p>
</div>
<h3>下一步操作</h3>
<ol>
<li>确认已收到此测试邮件</li>
<li>运行部署命令: .\setup-monitoring-task.ps1 -IntervalMinutes 5</li>
<li>系统将每5分钟自动检查服务状态</li>
<li>如有异常会立即发送邮件告警</li>
</ol>
</div>
</body>
</html>
"@
    
    $emailParams = @{
        To = $EmailTo
        From = $EmailFrom
        Subject = $subject
        Body = $htmlBody
        BodyAsHtml = $true
        SmtpServer = $SmtpServer
        Port = $SmtpPort
        Credential = $credential
        UseSsl = $true
        Encoding = [System.Text.Encoding]::UTF8
    }
    
    Send-MailMessage @emailParams
    
    Write-Host ""
    Write-Host "SUCCESS: 测试邮件发送成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "请检查收件箱: $EmailTo" -ForegroundColor Cyan
    Write-Host "（如果没收到，请检查垃圾邮件箱）" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "部署命令:" -ForegroundColor Green
    Write-Host "  cd K:\DNS" -ForegroundColor White
    Write-Host "  .\setup-monitoring-task.ps1 -IntervalMinutes 5" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "ERROR: 邮件发送失败" -ForegroundColor Red
    Write-Host "错误: $_" -ForegroundColor Red
    Write-Host ""
}

Write-Host "========== 测试完成 ==========" -ForegroundColor Cyan
