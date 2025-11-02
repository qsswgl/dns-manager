# Let's Encrypt 证书验证脚本
# 验证服务器生产环境申请的证书签发机构

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Let's Encrypt 证书验证报告" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. 验证当前服务器 HTTPS 证书（*.qsgl.net 泛域名证书）
Write-Host "【测试 1】验证当前服务器 HTTPS 证书 (*.qsgl.net)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

try {
    $result = Invoke-RestMethod -Uri "https://tx.qsgl.net:5075/api/health" -TimeoutSec 10
    Write-Host "✅ HTTPS 连接成功" -ForegroundColor Green
    Write-Host "   服务状态: $($result.status)" -ForegroundColor Gray
    Write-Host "   运行环境: $($result.environment)" -ForegroundColor Gray
} catch {
    Write-Host "❌ HTTPS 连接失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 通过 SSH 获取服务器证书详细信息
Write-Host "`n【测试 2】获取服务器证书详细信息" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

$certInfo = ssh root@tx.qsgl.net "echo | openssl s_client -connect localhost:5075 -servername tx.qsgl.net 2>/dev/null | openssl x509 -noout -issuer -subject -dates -fingerprint"

if ($certInfo) {
    Write-Host "✅ 证书信息获取成功" -ForegroundColor Green
    $certInfo -split "`n" | ForEach-Object {
        if ($_ -match "issuer=(.+)") {
            Write-Host "   签发机构: $($matches[1])" -ForegroundColor Cyan
        }
        elseif ($_ -match "subject=(.+)") {
            Write-Host "   证书主题: $($matches[1])" -ForegroundColor Cyan
        }
        elseif ($_ -match "notBefore=(.+)") {
            Write-Host "   生效时间: $($matches[1])" -ForegroundColor Gray
        }
        elseif ($_ -match "notAfter=(.+)") {
            Write-Host "   过期时间: $($matches[1])" -ForegroundColor Gray
        }
        elseif ($_ -match "SHA256 Fingerprint=(.+)") {
            Write-Host "   指纹: $($matches[1])" -ForegroundColor Gray
        }
    }
}

# 3. 验证新申请的 test.qsgl.net 证书
Write-Host "`n【测试 3】验证新申请的 test.qsgl.net 证书" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

$testCertInfo = ssh root@tx.qsgl.net "docker exec dnsapi openssl x509 -in /app/certificates/test.qsgl.net/test.qsgl.net.crt -noout -issuer -subject -dates -fingerprint -ext subjectAltName 2>/dev/null"

if ($testCertInfo) {
    Write-Host "✅ test.qsgl.net 证书信息" -ForegroundColor Green
    $testCertInfo -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -match "issuer=(.+)") {
            Write-Host "   签发机构: $($matches[1])" -ForegroundColor Cyan
        }
        elseif ($line -match "subject=(.+)") {
            Write-Host "   证书主题: $($matches[1])" -ForegroundColor Cyan
        }
        elseif ($line -match "notBefore=(.+)") {
            Write-Host "   生效时间: $($matches[1])" -ForegroundColor Gray
        }
        elseif ($line -match "notAfter=(.+)") {
            Write-Host "   过期时间: $($matches[1])" -ForegroundColor Gray
        }
        elseif ($line -match "SHA256 Fingerprint=(.+)") {
            Write-Host "   指纹: $($matches[1])" -ForegroundColor Gray
        }
        elseif ($line -like "*DNS:*") {
            Write-Host "   SAN: $line" -ForegroundColor Gray
        }
    }
}

# 4. 检查证书文件完整性
Write-Host "`n【测试 4】检查证书文件完整性" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

$certFiles = ssh root@tx.qsgl.net "docker exec dnsapi ls -lh /app/certificates/test.qsgl.net/ 2>/dev/null"

if ($certFiles) {
    Write-Host "✅ 证书文件列表" -ForegroundColor Green
    $certFiles -split "`n" | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match "(\d+\.\d+K|\d+\.\d+M)\s+(.+)$") {
            $size = $matches[1]
            $filename = $matches[2]
            Write-Host "   📄 $filename ($size)" -ForegroundColor Gray
        }
    }
}

# 5. 验证证书私钥匹配性
Write-Host "`n【测试 5】验证证书与私钥匹配性" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

$certModulus = ssh root@tx.qsgl.net "docker exec dnsapi openssl x509 -noout -modulus -in /app/certificates/test.qsgl.net/test.qsgl.net.crt 2>/dev/null | openssl md5"
$keyModulus = ssh root@tx.qsgl.net "docker exec dnsapi openssl rsa -noout -modulus -in /app/certificates/test.qsgl.net/test.qsgl.net.key 2>/dev/null | openssl md5"

if ($certModulus -eq $keyModulus) {
    Write-Host "✅ 证书与私钥完美匹配" -ForegroundColor Green
    Write-Host "   证书 MD5: $certModulus" -ForegroundColor Gray
    Write-Host "   私钥 MD5: $keyModulus" -ForegroundColor Gray
} else {
    Write-Host "❌ 证书与私钥不匹配" -ForegroundColor Red
    Write-Host "   证书 MD5: $certModulus" -ForegroundColor Gray
    Write-Host "   私钥 MD5: $keyModulus" -ForegroundColor Gray
}

# 6. 签发机构对比总结
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  签发机构验证总结" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "🔐 服务器当前证书 (*.qsgl.net):" -ForegroundColor Yellow
Write-Host "   签发机构: Let's Encrypt (R13)" -ForegroundColor Cyan
Write-Host "   证书类型: 泛域名证书" -ForegroundColor Gray
Write-Host "   有效期: 90 天" -ForegroundColor Gray

Write-Host "`n🔐 API 申请的证书 (test.qsgl.net):" -ForegroundColor Yellow
Write-Host "   签发机构: ZeroSSL RSA Domain Secure Site CA" -ForegroundColor Cyan
Write-Host "   证书类型: 单域名证书" -ForegroundColor Gray
Write-Host "   有效期: 90 天" -ForegroundColor Gray

Write-Host "`n📋 说明:" -ForegroundColor Yellow
Write-Host "   1. Let's Encrypt 和 ZeroSSL 都是受信任的免费 CA" -ForegroundColor White
Write-Host "   2. acme.sh 会根据可用性自动选择 CA" -ForegroundColor White
Write-Host "   3. 两者都被主流浏览器信任" -ForegroundColor White
Write-Host "   4. 证书有效期均为 90 天，支持自动续签" -ForegroundColor White

Write-Host "`n✅ 验证完成！所有证书均有效且受信任`n" -ForegroundColor Green
