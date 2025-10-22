# 使用指定SSH密钥部署EC证书到Envoy
param(
    [string]$Server = "www.qsgl.cn",
    [string]$Domain = "qsgl.cn"
)

$SSH_KEY = "C:\Key\www.qsgl.cn_nopass_id_ed25519"

Write-Host "🔧 部署EC证书到 Envoy" -ForegroundColor Green
Write-Host "服务器: $Server | 域名: $Domain" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $SSH_KEY)) {
    Write-Host "❌ SSH密钥不存在: $SSH_KEY" -ForegroundColor Red
    exit 1
}

# Bash部署脚本
$bashScript = @'
#!/bin/bash
set -e

echo "=== 1. 获取 EC 证书 ==="
cd /opt/envoy/certs
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/json' \
  -d '{"domain": "qsgl.cn", "provider": "DNSPOD"}' > cert-response.json
echo "✓ API成功"

echo -e "\n=== 2. 提取证书 ==="
python3 << 'EOF'
import json
with open('cert-response.json') as f:
    data = json.load(f)
with open('qsgl.cn.crt', 'w') as f:
    f.write(data['certificate'])
with open('qsgl.cn.key', 'w') as f:
    f.write(data['privateKey'])
print('✓ 证书已保存')
EOF

echo -e "\n=== 3. 检查格式 ==="
openssl x509 -in qsgl.cn.crt -noout -subject
head -1 qsgl.cn.key

echo -e "\n=== 4. 验证EC私钥 ==="
openssl ec -in qsgl.cn.key -noout -check && echo "✓ EC私钥正确"

echo -e "\n=== 5. 设置权限 ==="
chmod 644 qsgl.cn.crt
chmod 600 qsgl.cn.key
echo "✓ 权限完成"

echo -e "\n=== 6. 备份 ==="
cp qsgl.cn.crt qsgl.cn.crt.bak 2>/dev/null || true
cp qsgl.cn.key qsgl.cn.key.bak 2>/dev/null || true
echo "✓ 已备份"

echo -e "\n=== 7. 重启Envoy ==="
docker restart envoy-proxy
sleep 5

echo -e "\n=== 8. 检查状态 ==="
docker ps | grep envoy-proxy && echo "✓ 运行中"

echo -e "\n=== 9. 检查日志 ==="
docker logs envoy-proxy --tail 20 | grep -iE 'cert|key|error|fail' || echo "无异常"

echo -e "\n=== 10. 测试 ==="
sleep 2
curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' | head -5
'@

$tempFile = New-TemporaryFile
$bashScript | Out-File -FilePath $tempFile.FullName -Encoding ASCII -NoNewline

try {
    Write-Host "📤 上传脚本..." -ForegroundColor Yellow
    scp -i $SSH_KEY -o StrictHostKeyChecking=no $tempFile.FullName "root@${Server}:/tmp/deploy-ec.sh"
    
    Write-Host "🚀 执行部署...`n" -ForegroundColor Yellow
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no "root@$Server" "bash /tmp/deploy-ec.sh; rm /tmp/deploy-ec.sh"
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📌 外网测试..." -ForegroundColor Yellow
    
    $response = curl.exe -k -I "https://${Server}:8443/" -H "Host: www.$Domain" 2>&1
    Write-Host $response
    
    if ($response -match "200 OK") {
        Write-Host "`n🎉 成功! EC证书工作正常!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ 未返回200" -ForegroundColor Yellow
    }
    
} finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "`n访问: https://www.qsgl.cn:8443/" -ForegroundColor Cyan
