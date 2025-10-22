# 使用指定 SSH 密钥部署 EC 证书
$KEY = "C:\Key\www.qsgl.cn_nopass_id_ed25519"
$SERVER = "www.qsgl.cn"

Write-Host "🔧 使用 SSH 密钥部署 EC 证书" -ForegroundColor Green
Write-Host "密钥: $KEY" -ForegroundColor Cyan
Write-Host ""

# 上传脚本
Write-Host "📤 上传部署脚本..." -ForegroundColor Yellow
scp -i $KEY -o StrictHostKeyChecking=no "k:\DNS\DNSApi\linux-deploy\quick-deploy-ec.sh" "root@${SERVER}:/tmp/quick-ec.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 上传失败" -ForegroundColor Red
    exit 1
}

Write-Host "✓ 上传成功" -ForegroundColor Green
Write-Host ""

# 执行脚本
Write-Host "🚀 执行 EC 证书部署..." -ForegroundColor Yellow
Write-Host ""
ssh -i $KEY -o StrictHostKeyChecking=no "root@$SERVER" "bash /tmp/quick-ec.sh 2>&1; rm /tmp/quick-ec.sh"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📌 从 Windows 测试外网访问..." -ForegroundColor Yellow
Write-Host ""

$response = curl.exe -k -I "https://${SERVER}:8443/" -H "Host: www.qsgl.cn" --connect-timeout 10 2>&1
Write-Host $response

if ($response -match "200 OK") {
    Write-Host ""
    Write-Host "🎉 成功! EC 证书正常工作!" -ForegroundColor Green
    Write-Host "✅ Envoy v1.31 确实支持 ECDSA (EC) 证书" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ 外网测试异常，请检查服务器日志" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "浏览器访问: https://www.qsgl.cn:8443/" -ForegroundColor Cyan
