# Let's Encrypt 证书申请 API 测试脚本
# 测试时间: 2025-11-02

Write-Host "`n" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "       Let's Encrypt 证书申请 API 测试                          " -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

# 测试配置
$apiUrl = "https://tx.qsgl.net:5075/api/request-cert"
$domain = "*.qsgl.net"
$provider = "DNSPOD"
$certType = "RSA2048"
$exportFormat = "BOTH"
$pfxPassword = "qsgl2024"

Write-Host "📋 测试配置:" -ForegroundColor Yellow
Write-Host "  API 地址:    $apiUrl" -ForegroundColor Gray
Write-Host "  域名:        $domain" -ForegroundColor Gray
Write-Host "  DNS 提供商:  $provider" -ForegroundColor Gray
Write-Host "  证书类型:    $certType" -ForegroundColor Gray
Write-Host "  导出格式:    $exportFormat" -ForegroundColor Gray
Write-Host "`n"

# 构建请求体
$body = @{
    domain = $domain
    provider = $provider
    certType = $certType
    exportFormat = $exportFormat
    pfxPassword = $pfxPassword
} | ConvertTo-Json

Write-Host "📤 发送请求..." -ForegroundColor Cyan
Write-Host "请求体:" -ForegroundColor Gray
Write-Host $body -ForegroundColor White
Write-Host "`n"

try {
    $startTime = Get-Date
    
    # 发送请求
    $response = Invoke-RestMethod `
        -Uri $apiUrl `
        -Method Post `
        -ContentType "application/json" `
        -Body $body `
        -SkipCertificateCheck
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "✅ 请求成功!" -ForegroundColor Green
    Write-Host "⏱️  耗时: $([Math]::Round($duration, 2)) 秒`n" -ForegroundColor Cyan
    
    # 显示响应
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                        响应数据                                " -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($response.success) {
        Write-Host "`n✅ 证书申请成功!" -ForegroundColor Green
        Write-Host "`n基本信息:" -ForegroundColor Yellow
        Write-Host "  消息:        $($response.message)" -ForegroundColor White
        Write-Host "  域名:        $($response.domain)" -ForegroundColor White
        Write-Host "  主题:        $($response.subject)" -ForegroundColor White
        Write-Host "  证书类型:    $($response.certType)" -ForegroundColor White
        Write-Host "  泛域名:      $($response.isWildcard)" -ForegroundColor White
        Write-Host "  导出格式:    $($response.exportFormat)" -ForegroundColor White
        
        if ($response.expiryDate) {
            $expiryDate = [DateTime]::Parse($response.expiryDate)
            $daysUntilExpiry = ($expiryDate - (Get-Date)).Days
            Write-Host "  过期时间:    $($expiryDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
            Write-Host "  剩余天数:    $daysUntilExpiry 天" -ForegroundColor $(if ($daysUntilExpiry -gt 30) { "Green" } else { "Yellow" })
        }
        
        Write-Host "`n证书内容 (Base64):" -ForegroundColor Yellow
        if ($response.pemCert) {
            $certLength = $response.pemCert.Length
            Write-Host "  PEM 证书:    ✅ ($certLength 字符)" -ForegroundColor Green
        } else {
            Write-Host "  PEM 证书:    ❌ 无" -ForegroundColor Red
        }
        
        if ($response.pemKey) {
            $keyLength = $response.pemKey.Length
            Write-Host "  PEM 私钥:    ✅ ($keyLength 字符)" -ForegroundColor Green
        } else {
            Write-Host "  PEM 私钥:    ❌ 无" -ForegroundColor Red
        }
        
        if ($response.pemChain) {
            $chainLength = $response.pemChain.Length
            Write-Host "  PEM 证书链:  ✅ ($chainLength 字符)" -ForegroundColor Green
        } else {
            Write-Host "  PEM 证书链:  ⚠️  无" -ForegroundColor Yellow
        }
        
        if ($response.pfxData) {
            $pfxLength = $response.pfxData.Length
            Write-Host "  PFX 证书:    ✅ ($pfxLength 字符)" -ForegroundColor Green
        } else {
            Write-Host "  PFX 证书:    ❌ 无" -ForegroundColor Red
        }
        
        if ($response.filePaths) {
            Write-Host "`n文件路径:" -ForegroundColor Yellow
            if ($response.filePaths.pemCert) {
                Write-Host "  PEM 证书:    $($response.filePaths.pemCert)" -ForegroundColor White
            }
            if ($response.filePaths.pemKey) {
                Write-Host "  PEM 私钥:    $($response.filePaths.pemKey)" -ForegroundColor White
            }
            if ($response.filePaths.pemChain) {
                Write-Host "  PEM 证书链:  $($response.filePaths.pemChain)" -ForegroundColor White
            }
            if ($response.filePaths.pfx) {
                Write-Host "  PFX 证书:    $($response.filePaths.pfx)" -ForegroundColor White
            }
        }
        
        Write-Host "`n时间戳:" -ForegroundColor Yellow
        Write-Host "  $($response.timestamp)" -ForegroundColor White
        
        Write-Host "`n" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "                      验证步骤                                  " -ForegroundColor Yellow
        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        
        Write-Host "`n步骤 1: 检查服务器文件" -ForegroundColor Cyan
        $domainDir = $domain.Replace("*.", "wildcard.")
        Write-Host "  ssh root@tx.qsgl.net 'ls -lh /app/certificates/$domainDir/'" -ForegroundColor Gray
        
        Write-Host "`n步骤 2: 下载 ZIP 压缩包" -ForegroundColor Cyan
        Write-Host "  scp root@tx.qsgl.net:/app/certificates/$domainDir/$domainDir-certificates.zip ./" -ForegroundColor Gray
        
        Write-Host "`n步骤 3: 验证证书" -ForegroundColor Cyan
        Write-Host "  openssl x509 -in certificate.crt -text -noout" -ForegroundColor Gray
        
        Write-Host "`n步骤 4: 使用 /api/cert/download-zip 下载" -ForegroundColor Cyan
        Write-Host "  curl -k 'https://tx.qsgl.net:5075/api/cert/download-zip?domain=$domain' -o certificates.zip" -ForegroundColor Gray
        
    } else {
        Write-Host "`n❌ 证书申请失败!" -ForegroundColor Red
        Write-Host "  消息: $($response.message)" -ForegroundColor Yellow
        Write-Host "  域名: $($response.domain)" -ForegroundColor Yellow
    }
    
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                      完整 JSON 响应                            " -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ($response | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    Write-Host "`n"
    
} catch {
    Write-Host "❌ 请求失败!" -ForegroundColor Red
    Write-Host "错误: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "`n错误详情:" -ForegroundColor Gray
    Write-Host $_.Exception -ForegroundColor Gray
}

Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                      测试完成                                  " -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
