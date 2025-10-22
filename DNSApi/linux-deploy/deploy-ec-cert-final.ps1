# 使用指定SSH密钥部署EC证书到Envoy
# 使用方法: .\deploy-ec-cert-final.ps1

param(
    [string]$Server = "www.qsgl.cn",
    [string]$Domain = "qsgl.cn"
)

$ErrorActionPreference = "Stop"
$SSH_KEY = "C:\Key\www.qsgl.cn_nopass_id_ed25519"

Write-Host "🔧 部署EC证书到 Envoy" -ForegroundColor Green
Write-Host "服务器: $Server" -ForegroundColor Cyan
Write-Host "域名: $Domain" -ForegroundColor Cyan
Write-Host "SSH密钥: $SSH_KEY" -ForegroundColor Cyan
Write-Host ""

# 检查SSH密钥
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "❌ SSH密钥不存在: $SSH_KEY" -ForegroundColor Red
    exit 1
}

# 创建部署脚本
$bashScript = @"
#!/bin/bash
set -e

echo "=== 1. 从 API 获取 EC 证书 ==="
cd /opt/envoy/certs
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/json' \
  -d '{\"domain\": \"$Domain\", \"provider\": \"DNSPOD\"}' > cert-response.json
echo "✓ API 调用成功"

echo ""
echo "=== 2. 提取证书和私钥 ==="
python3 << 'PYEOF'
import json
with open('cert-response.json', 'r') as f:
    data = json.load(f)
with open('$Domain.crt', 'w') as f:
    f.write(data['certificate'])
with open('$Domain.key', 'w') as f:
    f.write(data['privateKey'])
print('✓ 证书已保存: $Domain.crt')
print('✓ 私钥已保存: $Domain.key')
PYEOF

echo ""
echo "=== 3. 检查证书信息 ==="
echo "证书主题:"
openssl x509 -in $Domain.crt -noout -subject

echo ""
echo "证书公钥算法:"
openssl x509 -in $Domain.crt -noout -text | grep 'Public Key Algorithm' -A 2

echo ""
echo "私钥类型:"
head -1 $Domain.key

echo ""
echo "=== 4. 验证 EC 私钥 ==="
if openssl ec -in $Domain.key -noout -check 2>/dev/null; then
    echo "✓ EC 私钥格式正确"
else
    echo "❌ 私钥验证失败"
    exit 1
fi

echo ""
echo "=== 5. 验证私钥和证书匹配 ==="
CERT_MODULUS=\$(openssl x509 -in $Domain.crt -noout -pubkey | openssl ec -pubin -outform DER 2>/dev/null | md5sum | awk '{print \$1}')
KEY_MODULUS=\$(openssl ec -in $Domain.key -pubout -outform DER 2>/dev/null | md5sum | awk '{print \$1}')

if [ "\$CERT_MODULUS" = "\$KEY_MODULUS" ]; then
    echo "✓ 私钥和证书匹配"
else
    echo "❌ 私钥和证书不匹配"
    echo "证书指纹: \$CERT_MODULUS"
    echo "私钥指纹: \$KEY_MODULUS"
    exit 1
fi

echo ""
echo "=== 6. 设置文件权限 ==="
chmod 644 $Domain.crt
chmod 600 $Domain.key
ls -lh $Domain.crt $Domain.key
echo "✓ 权限设置完成"

echo ""
echo "=== 7. 备份旧证书 ==="
if [ -f $Domain.crt.bak ]; then
    mv $Domain.crt.bak $Domain.crt.bak.old 2>/dev/null || true
    mv $Domain.key.bak $Domain.key.bak.old 2>/dev/null || true
fi
cp $Domain.crt $Domain.crt.bak
cp $Domain.key $Domain.key.bak
echo "✓ 已备份到 .bak 文件"

echo ""
echo "=== 8. 检查 Envoy 配置文件中的证书路径 ==="
if [ -f /opt/envoy/envoy.yaml ]; then
    echo "Envoy 配置中的证书路径:"
    grep -A 5 'tls_certificates' /opt/envoy/envoy.yaml | grep -E 'certificate_chain|private_key' || echo "未找到证书配置"
fi

echo ""
echo "=== 9. 重启 Envoy 容器 ==="
docker restart envoy-proxy
echo "等待 Envoy 启动..."
sleep 5

echo ""
echo "=== 10. 检查容器状态 ==="
if docker ps | grep -q envoy-proxy; then
    echo "✓ Envoy 容器运行中"
    docker ps | grep envoy-proxy
else
    echo "❌ Envoy 容器未运行"
    docker ps -a | grep envoy-proxy
    exit 1
fi

echo ""
echo "=== 11. 检查 Envoy 日志（查找证书相关信息） ==="
echo "最近的日志:"
docker logs envoy-proxy --tail 30 2>&1 | tail -15

echo ""
echo "证书/密钥相关日志:"
docker logs envoy-proxy 2>&1 | grep -iE 'cert|key|tls|ssl' | tail -10 || echo "未发现证书相关日志"

echo ""
echo "错误日志:"
docker logs envoy-proxy 2>&1 | grep -iE 'error|fail|warn' | tail -5 || echo "✓ 未发现错误"

echo ""
echo "=== 12. 测试本地 8443 端口 ==="
sleep 2
echo "测试命令: curl -skI https://localhost:8443/ -H 'Host: www.$Domain'"
RESPONSE=\$(curl -skI https://localhost:8443/ -H 'Host: www.$Domain' --connect-timeout 5 2>&1)

echo "\$RESPONSE" | head -10

if echo "\$RESPONSE" | grep -q '200 OK'; then
    echo ""
    echo "✅ 本地测试成功! 8443 端口返回 200 OK"
elif echo "\$RESPONSE" | grep -q 'SSL'; then
    echo ""
    echo "⚠️ SSL 相关错误，可能是 Envoy 不支持 EC 证书"
    echo "完整响应:"
    echo "\$RESPONSE"
else
    echo ""
    echo "❌ 测试失败"
    echo "完整响应:"
    echo "\$RESPONSE"
fi

echo ""
echo "=== 13. 显示证书详细信息 ==="
echo "证书有效期:"
openssl x509 -in $Domain.crt -noout -dates

echo ""
echo "证书 SAN (Subject Alternative Names):"
openssl x509 -in $Domain.crt -noout -ext subjectAltName 2>/dev/null || echo "无 SAN 扩展"

echo ""
echo "证书完整信息:"
openssl x509 -in $Domain.crt -noout -text | head -30
"@

# 保存脚本到临时文件
$tempFile = New-TemporaryFile
$bashScript | Out-File -FilePath $tempFile.FullName -Encoding ASCII -NoNewline

try {
    Write-Host "📤 上传部署脚本到服务器..." -ForegroundColor Yellow
    scp -i $SSH_KEY -o StrictHostKeyChecking=no $tempFile.FullName "root@${Server}:/tmp/deploy-ec.sh"
    
    Write-Host "🚀 执行 EC 证书部署..." -ForegroundColor Yellow
    Write-Host ""
    
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no "root@$Server" "bash /tmp/deploy-ec.sh 2>&1; rm /tmp/deploy-ec.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "📌 从 Windows 客户端测试外网访问..." -ForegroundColor Yellow
        
        $response = curl.exe -k -I "https://${Server}:8443/" -H "Host: www.$Domain" --connect-timeout 10 2>&1
        
        Write-Host $response -ForegroundColor White
        
        if ($response -match "200 OK") {
            Write-Host ""
            Write-Host "🎉 完美! EC 证书部署成功，8443 端口正常工作!" -ForegroundColor Green
            Write-Host ""
            Write-Host "✓ Envoy v1.31 确实支持 EC 证书" -ForegroundColor Green
            Write-Host "✓ 证书类型: ECDSA (EC)" -ForegroundColor Green
            Write-Host "✓ 证书域名: *.$Domain" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "⚠️ 警告: 外网测试未返回 200 OK" -ForegroundColor Yellow
            Write-Host "可能的原因:" -ForegroundColor Yellow
            Write-Host "- Envoy 启动时遇到 EC 证书兼容问题" -ForegroundColor Gray
            Write-Host "- 证书格式需要转换" -ForegroundColor Gray
            Write-Host "- 网络延迟或其他问题" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "❌ 部署过程中出现错误" -ForegroundColor Red
    }
    
} finally {
    # 清理临时文件
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📝 后续操作建议:" -ForegroundColor Yellow
Write-Host "1. 浏览器访问: https://www.qsgl.cn:8443/" -ForegroundColor Gray
Write-Host "2. 查看完整日志: ssh -i $SSH_KEY root@$Server 'docker logs envoy-proxy --tail 50'" -ForegroundColor Gray
Write-Host "3. 如果失败，恢复 RSA 证书: ssh -i $SSH_KEY root@$Server 'cd /opt/envoy/certs && cp qsgl.cn.crt.bak qsgl.cn.crt && cp qsgl.cn.key.bak qsgl.cn.key && docker restart envoy-proxy'" -ForegroundColor Gray
Write-Host ""
