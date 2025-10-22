# 简化版EC证书部署脚本
# 假设SSH密钥已配置

param(
    [string]$Server = "www.qsgl.cn",
    [string]$Domain = "qsgl.cn"
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 部署EC证书到 Envoy" -ForegroundColor Green
Write-Host "服务器: $Server" -ForegroundColor Cyan
Write-Host "域名: $Domain" -ForegroundColor Cyan
Write-Host ""

# 创建部署脚本
$bashScript = @"
#!/bin/bash
set -e

echo "=== 1. 从 API 获取证书 ==="
cd /opt/envoy/certs
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/json' \
  -d '{\"domain\": \"$Domain\", \"provider\": \"DNSPOD\"}' > cert-response.json
echo "✓ API 调用成功"

echo -e "\n=== 2. 提取证书和私钥 ==="
python3 << 'EOF'
import json
with open('cert-response.json', 'r') as f:
    data = json.load(f)
with open('$Domain.crt', 'w') as f:
    f.write(data['certificate'])
with open('$Domain.key', 'w') as f:
    f.write(data['privateKey'])
print('✓ 证书和私钥已保存')
EOF

echo -e "\n=== 3. 检查证书格式 ==="
openssl x509 -in $Domain.crt -noout -subject
openssl x509 -in $Domain.crt -noout -text | grep 'Public Key Algorithm' -A 2
head -1 $Domain.key

echo -e "\n=== 4. 验证EC私钥 ==="
openssl ec -in $Domain.key -noout -check

echo -e "\n=== 5. 设置权限 ==="
chmod 644 $Domain.crt
chmod 600 $Domain.key
echo "✓ 权限设置完成"

echo -e "\n=== 6. 备份并应用 ==="
cp $Domain.crt $Domain.crt.bak 2>/dev/null || true
cp $Domain.key $Domain.key.bak 2>/dev/null || true

echo -e "\n=== 7. 重启 Envoy ==="
docker restart envoy-proxy
sleep 4

echo -e "\n=== 8. 检查容器状态 ==="
docker ps | grep envoy-proxy && echo "✓ Envoy运行中" || echo "❌ Envoy未运行"

echo -e "\n=== 9. 检查日志 ==="
docker logs envoy-proxy --tail 20 2>&1 | grep -E 'cert|key|tls|error' | tail -10 || echo "未发现错误"

echo -e "\n=== 10. 测试服务 ==="
sleep 2
curl -skI https://localhost:8443/ -H 'Host: www.$Domain' | head -5
"@

# 保存到临时文件
$tempFile = New-TemporaryFile
$bashScript | Out-File -FilePath $tempFile.FullName -Encoding ASCII

Write-Host "📤 上传部署脚本..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no $tempFile.FullName "root@${Server}:/tmp/deploy-ec.sh"

Write-Host "🚀 执行部署..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no "root@$Server" "bash /tmp/deploy-ec.sh 2>&1; rm /tmp/deploy-ec.sh"

Remove-Item $tempFile -Force

Write-Host "`n📌 测试外网访问..." -ForegroundColor Yellow
$response = curl.exe -k -I "https://${Server}:8443/" -H "Host: www.$Domain" 2>&1

Write-Host $response -ForegroundColor White

if ($response -match "200 OK") {
    Write-Host "`n✅ 成功! EC证书部署完成，8443端口正常工作!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ 警告: 未检测到200响应" -ForegroundColor Yellow
}
