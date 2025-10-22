# 使用 SSH 密钥部署 EC 证书
$SSH_KEY = "C:\Key\www.qsgl.cn_nopass_id_ed25519"
$SERVER = "www.qsgl.cn"

Write-Host "🔧 部署 EC 证书到 Envoy" -ForegroundColor Green
Write-Host ""

# 创建部署脚本
$script = @'
#!/bin/bash
set -e
cd /opt/envoy/certs

echo "=== 1. 获取 EC 证书 ==="
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/json' \
  -d '{"domain": "qsgl.cn", "provider": "DNSPOD"}' > cert-response.json
echo "✓ API 调用成功"

echo ""
echo "=== 2. 查看 API 响应 ==="
head -c 300 cert-response.json
echo ""

echo ""
echo "=== 3. 提取证书 ==="
python3 -c "
import json
with open('cert-response.json') as f:
    data = json.load(f)
print('JSON 键:', list(data.keys()))
with open('qsgl.cn.crt', 'w') as f:
    f.write(data['certificate'])
with open('qsgl.cn.key', 'w') as f:
    f.write(data['privateKey'])
print('✓ 证书和私钥已保存')
"

echo ""
echo "=== 4. 检查证书 ==="
openssl x509 -in qsgl.cn.crt -noout -subject
head -1 qsgl.cn.key

echo ""
echo "=== 5. 验证 EC 私钥 ==="
openssl ec -in qsgl.cn.key -noout -check && echo "✓ EC 私钥正确"

echo ""
echo "=== 6. 备份 RSA 证书 ==="
cp qsgl.cn.crt qsgl.cn.crt.rsa-backup 2>/dev/null || true
cp qsgl.cn.key qsgl.cn.key.rsa-backup 2>/dev/null || true
echo "✓ 已备份"

echo ""
echo "=== 7. 设置权限 ==="
chmod 644 qsgl.cn.crt
chmod 600 qsgl.cn.key
echo "✓ 权限设置完成"

echo ""
echo "=== 8. 重启 Envoy ==="
docker restart envoy-proxy
sleep 5

echo ""
echo "=== 9. 检查状态 ==="
docker ps | grep envoy-proxy

echo ""
echo "=== 10. 检查日志 ==="
docker logs envoy-proxy --tail 20

echo ""
echo "=== 11. 测试 ==="
sleep 2
curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' | head -5
'@

# 保存脚本
$tempFile = [System.IO.Path]::GetTempFileName()
$script | Out-File -FilePath $tempFile -Encoding ASCII -NoNewline

try {
    Write-Host "📤 上传脚本..." -ForegroundColor Yellow
    # 使用密码方式上传（因为 scp 也需要 passphrase）
    scp $tempFile root@${SERVER}:/tmp/deploy-ec.sh
    
    Write-Host "🚀 执行部署...`n" -ForegroundColor Yellow
    # 使用密码方式执行
    ssh root@$SERVER "bash /tmp/deploy-ec.sh; rm /tmp/deploy-ec.sh"
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📌 外网测试..." -ForegroundColor Yellow
    $response = curl.exe -k -I "https://${SERVER}:8443/" -H "Host: www.qsgl.cn" 2>&1
    Write-Host $response
    
    if ($response -match "200 OK") {
        Write-Host "`n🎉 成功! EC 证书正常工作!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ 测试异常" -ForegroundColor Yellow
    }
} finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
