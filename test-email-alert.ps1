# DNS API 邮件告警测试脚本
Write-Host "========== 邮件测试开始 ==========" -ForegroundColor Cyan

$EmailTo = "qsoft@139.com"
$EmailFrom = "dnsapi-monitor@tx.qsgl.net"
$SmtpServer = "smtp.139.com"
$SmtpPort = 25

Write-Host "收件人: $EmailTo" -ForegroundColor White
Write-Host "发件人: $EmailFrom" -ForegroundColor White
Write-Host "SMTP: $SmtpServer`:$SmtpPort" -ForegroundColor White
Write-Host ""
Write-Host "正在发送测试邮件..." -ForegroundColor Yellow

try {
    $subject = "DNS API 监控系统邮件测试 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    $body = @"
DNS API 监控系统邮件测试

如果您收到此邮件，说明邮件配置成功！

测试时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
收件人: $EmailTo
发件人: $EmailFrom
SMTP 服务器: $SmtpServer
SMTP 端口: $SmtpPort

下一步:
1. 确认收到此邮件
2. 检查是否在垃圾邮件箱
3. 运行部署命令:
   cd K:\DNS
   .\setup-monitoring-task.ps1 -IntervalMinutes 5
"@
    
    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $subject -Body $body -SmtpServer $SmtpServer -Port $SmtpPort -Encoding UTF8
    
    Write-Host "SUCCESS: 邮件发送成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "请检查收件箱: $EmailTo" -ForegroundColor Cyan
    Write-Host "可能在垃圾邮件箱中" -ForegroundColor Yellow
    
} catch {
    Write-Host "ERROR: 邮件发送失败" -ForegroundColor Red
    Write-Host "错误: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能原因:" -ForegroundColor Yellow
    Write-Host "1. 139邮箱需要SMTP认证（授权码）" -ForegroundColor White
    Write-Host "2. 防火墙阻止SMTP端口" -ForegroundColor White
    Write-Host "3. 需要使用SSL端口465或587" -ForegroundColor White
    Write-Host ""
    Write-Host "解决方案:" -ForegroundColor Cyan
    Write-Host "1. 访问 https://mail.139.com" -ForegroundColor White
    Write-Host "2. 设置 -> 客户端设置 -> 开启SMTP" -ForegroundColor White
    Write-Host "3. 获取SMTP授权码" -ForegroundColor White
    Write-Host "4. 修改监控脚本添加认证信息" -ForegroundColor White
    Write-Host ""
    Write-Host "详见: K:\DNS\EMAIL-ALERT-CONFIG.md" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========== 测试完成 ==========" -ForegroundColor Cyan
