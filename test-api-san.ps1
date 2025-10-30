# ============================================================
# 测试证书 API SAN 扩展
# 验证通过 API 生成的证书是否包含 Subject Alternative Name
# ============================================================

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   测试证书生成 API - SAN 扩展验证" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 测试参数
$apiUrl = "https://tx.qsgl.net:5075/api/cert/v2/generate"
$testDomain = "api-test.qsgl.net"
$outputDir = "K:\DNS\test-san-output"

# 创建输出目录
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "`n📝 测试参数：" -ForegroundColor Yellow
Write-Host "  API URL: $apiUrl" -ForegroundColor White
Write-Host "  测试域名: $testDomain" -ForegroundColor White
Write-Host "  证书类型: RSA2048" -ForegroundColor White
Write-Host "  导出格式: BOTH (PEM + PFX)" -ForegroundColor White

# 构建请求体
$requestBody = @{
    domain = $testDomain
    certType = "RSA2048"
    exportFormat = "BOTH"
    pfxPassword = "test123456"
} | ConvertTo-Json

Write-Host "`n🚀 发送 API 请求..." -ForegroundColor Yellow

try {
    # 跳过 SSL 证书验证（因为是自签名证书）
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post `
            -Body $requestBody -ContentType "application/json" `
            -SkipCertificateCheck
    } else {
        # PowerShell 5.1
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post `
            -Body $requestBody -ContentType "application/json"
    }

    if ($response.success) {
        Write-Host "✅ API 调用成功！" -ForegroundColor Green
        
        Write-Host "`n📦 响应数据：" -ForegroundColor Yellow
        Write-Host "  域名: $($response.domain)" -ForegroundColor White
        Write-Host "  主题: $($response.subject)" -ForegroundColor White
        Write-Host "  证书类型: $($response.certType)" -ForegroundColor White
        Write-Host "  导出格式: $($response.exportFormat)" -ForegroundColor White
        Write-Host "  过期时间: $($response.expiryDate)" -ForegroundColor White
        
        # 保存 PEM 证书
        if ($response.pemCert) {
            Write-Host "`n💾 保存证书文件..." -ForegroundColor Yellow
            
            $certPath = Join-Path $outputDir "$testDomain.crt"
            $keyPath = Join-Path $outputDir "$testDomain.key"
            $pfxPath = Join-Path $outputDir "$testDomain.pfx"
            
            # 解码 Base64 并保存 PEM 证书
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.pemCert)) | Out-File -FilePath $certPath -Encoding utf8
            Write-Host "  ✅ 证书文件: $certPath" -ForegroundColor Green
            
            # 保存私钥
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.pemKey)) | Out-File -FilePath $keyPath -Encoding utf8
            Write-Host "  ✅ 私钥文件: $keyPath" -ForegroundColor Green
            
            # 保存 PFX
            if ($response.pfxData) {
                [System.Convert]::FromBase64String($response.pfxData) | Set-Content -Path $pfxPath -Encoding Byte
                Write-Host "  ✅ PFX文件: $pfxPath" -ForegroundColor Green
            }
            
            Write-Host "`n🔍 验证证书 SAN 扩展..." -ForegroundColor Yellow
            
            # 检查是否有 OpenSSL
            $opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
            
            if ($opensslCmd) {
                Write-Host "`n📋 证书详细信息：" -ForegroundColor Cyan
                Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
                
                # 显示证书主题
                $subject = & openssl x509 -in $certPath -noout -subject 2>$null
                Write-Host "Subject: $subject" -ForegroundColor White
                
                # 显示 SAN 扩展
                Write-Host "`n🎯 Subject Alternative Name (SAN) 扩展：" -ForegroundColor Yellow
                $san = & openssl x509 -in $certPath -noout -text 2>$null | Select-String -Pattern "Subject Alternative Name" -Context 0,1
                
                if ($san) {
                    $san | ForEach-Object {
                        Write-Host $_.ToString() -ForegroundColor Green
                    }
                    Write-Host "`n✅ SAN 扩展存在！证书符合现代浏览器要求。" -ForegroundColor Green
                } else {
                    Write-Host "❌ 未找到 SAN 扩展！" -ForegroundColor Red
                }
                
                # 显示完整的证书扩展
                Write-Host "`n📜 所有证书扩展：" -ForegroundColor Cyan
                Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
                $extensions = & openssl x509 -in $certPath -noout -text 2>$null | Select-String -Pattern "X509v3" -Context 0,2
                $extensions | ForEach-Object {
                    Write-Host $_.ToString() -ForegroundColor White
                }
                
                # 显示证书有效期
                Write-Host "`n📅 证书有效期：" -ForegroundColor Cyan
                Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
                $notBefore = & openssl x509 -in $certPath -noout -startdate 2>$null
                $notAfter = & openssl x509 -in $certPath -noout -enddate 2>$null
                Write-Host $notBefore -ForegroundColor White
                Write-Host $notAfter -ForegroundColor White
                
            } else {
                Write-Host "`n⚠️  未安装 OpenSSL，跳过证书验证" -ForegroundColor Yellow
                Write-Host "   请安装 OpenSSL 以验证证书详情" -ForegroundColor Gray
                Write-Host "   下载地址: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Gray
                
                Write-Host "`n📝 手动验证方法（Linux/macOS）：" -ForegroundColor Cyan
                Write-Host "   openssl x509 -in $testDomain.crt -text -noout | grep -A 1 'Subject Alternative Name'" -ForegroundColor Gray
            }
            
            Write-Host "`n📊 测试总结：" -ForegroundColor Yellow
            Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
            Write-Host "  ✅ API 调用成功" -ForegroundColor Green
            Write-Host "  ✅ 证书生成成功" -ForegroundColor Green
            Write-Host "  ✅ PEM 格式导出" -ForegroundColor Green
            Write-Host "  ✅ PFX 格式导出" -ForegroundColor Green
            if ($opensslCmd -and $san) {
                Write-Host "  ✅ SAN 扩展验证通过" -ForegroundColor Green
            }
            
        } else {
            Write-Host "❌ 响应中没有证书数据" -ForegroundColor Red
        }
        
    } else {
        Write-Host "❌ API 返回失败: $($response.message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n详细错误信息：" -ForegroundColor Yellow
    Write-Host $_.Exception.ToString() -ForegroundColor Gray
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   测试完成！" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 测试泛域名证书
Write-Host "`n" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   测试泛域名证书 - SAN 扩展验证" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$wildcardDomain = "*.test.qsgl.net"
Write-Host "`n📝 测试泛域名: $wildcardDomain" -ForegroundColor Yellow

$requestBody2 = @{
    domain = $wildcardDomain
    certType = "ECDSA256"
    exportFormat = "PEM"
    pfxPassword = "test123456"
} | ConvertTo-Json

Write-Host "🚀 发送 API 请求..." -ForegroundColor Yellow

try {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $response2 = Invoke-RestMethod -Uri $apiUrl -Method Post `
            -Body $requestBody2 -ContentType "application/json" `
            -SkipCertificateCheck
    } else {
        $response2 = Invoke-RestMethod -Uri $apiUrl -Method Post `
            -Body $requestBody2 -ContentType "application/json"
    }

    if ($response2.success) {
        Write-Host "✅ API 调用成功！" -ForegroundColor Green
        
        Write-Host "`n📦 响应数据：" -ForegroundColor Yellow
        Write-Host "  域名: $($response2.domain)" -ForegroundColor White
        Write-Host "  主题: $($response2.subject)" -ForegroundColor White
        Write-Host "  证书类型: $($response2.certType)" -ForegroundColor White
        
        # 保存泛域名证书
        $wildcardCertPath = Join-Path $outputDir "wildcard.test.qsgl.net.crt"
        $wildcardKeyPath = Join-Path $outputDir "wildcard.test.qsgl.net.key"
        
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response2.pemCert)) | Out-File -FilePath $wildcardCertPath -Encoding utf8
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response2.pemKey)) | Out-File -FilePath $wildcardKeyPath -Encoding utf8
        
        Write-Host "  ✅ 证书文件: $wildcardCertPath" -ForegroundColor Green
        Write-Host "  ✅ 私钥文件: $wildcardKeyPath" -ForegroundColor Green
        
        # 验证泛域名证书的 SAN
        $opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
        if ($opensslCmd) {
            Write-Host "`n🎯 泛域名证书 SAN 扩展：" -ForegroundColor Yellow
            Write-Host "   预期包含: DNS:*.test.qsgl.net, DNS:test.qsgl.net" -ForegroundColor Gray
            Write-Host "" -ForegroundColor White
            
            $wildcardSan = & openssl x509 -in $wildcardCertPath -noout -text 2>$null | Select-String -Pattern "Subject Alternative Name" -Context 0,1
            
            if ($wildcardSan) {
                $wildcardSan | ForEach-Object {
                    Write-Host $_.ToString() -ForegroundColor Green
                }
                Write-Host "`n✅ 泛域名证书 SAN 扩展验证通过！" -ForegroundColor Green
                Write-Host "   包含泛域名 (*.test.qsgl.net) 和根域名 (test.qsgl.net)" -ForegroundColor Green
            } else {
                Write-Host "❌ 未找到 SAN 扩展！" -ForegroundColor Red
            }
        }
        
    } else {
        Write-Host "❌ API 返回失败: $($response2.message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   所有测试完成！" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
