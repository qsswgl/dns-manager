# 配置SSH密钥并部署EC证书到Envoy
# 使用方法: .\setup-ssh-and-ec-cert.ps1

$ErrorActionPreference = "Continue"

$SERVER = "www.qsgl.cn"
$SERVER_IP = "123.57.93.200"
$USERNAME = "root"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa"
$SSH_PUB_KEY = "$env:USERPROFILE\.ssh\id_rsa.pub"

Write-Host "🔧 SSH密钥配置和EC证书部署工具" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 步骤1: 检查SSH密钥
Write-Host "`n📌 步骤1: 检查SSH密钥" -ForegroundColor Yellow
if (-not (Test-Path $SSH_PUB_KEY)) {
    Write-Host "❌ SSH公钥不存在: $SSH_PUB_KEY" -ForegroundColor Red
    Write-Host "请先生成SSH密钥: ssh-keygen -t rsa -b 4096" -ForegroundColor Yellow
    exit 1
}
$pubKey = Get-Content $SSH_PUB_KEY -Raw
Write-Host "✓ 找到SSH公钥" -ForegroundColor Green

# 步骤2: 配置SSH密钥到服务器 (需要密码)
Write-Host "`n📌 步骤2: 配置SSH密钥到服务器 (需要输入一次密码)" -ForegroundColor Yellow
Write-Host "正在添加公钥到服务器..." -ForegroundColor Cyan

$setupKeyScript = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$pubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo '✓ SSH密钥已添加'
"@

# 使用密码登录添加公钥
$setupKeyScript | ssh -o StrictHostKeyChecking=no $USERNAME@$SERVER "bash -s"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ SSH密钥配置失败" -ForegroundColor Red
    Write-Host "请手动执行: ssh-copy-id $USERNAME@$SERVER" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ SSH密钥配置成功" -ForegroundColor Green

# 步骤3: 测试免密登录
Write-Host "`n📌 步骤3: 测试SSH免密登录" -ForegroundColor Yellow
$testResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o PasswordAuthentication=no $USERNAME@$SERVER "echo '✓ 免密登录成功'"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 免密登录测试失败" -ForegroundColor Red
    exit 1
}
Write-Host $testResult -ForegroundColor Green

# 步骤4: 部署EC证书
Write-Host "`n📌 步骤4: 从API获取并部署EC证书" -ForegroundColor Yellow

$deployCertScript = @'
echo "=== 1. 从 API 获取证书 ==="
cd /opt/envoy/certs
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H "Content-Type: application/json" \
  -d '{"domain": "qsgl.cn", "provider": "DNSPOD"}' > cert-response.json

if [ ! -s cert-response.json ]; then
    echo "❌ API 调用失败"
    exit 1
fi
echo "✓ API 调用成功"

echo -e "\n=== 2. 提取证书和私钥 ==="
python3 << 'PYTHON_EOF'
import json
try:
    with open('cert-response.json', 'r') as f:
        data = json.load(f)
    with open('qsgl.cn.crt', 'w') as f:
        f.write(data['certificate'])
    with open('qsgl.cn.key', 'w') as f:
        f.write(data['privateKey'])
    print('✓ 证书和私钥已保存')
except Exception as e:
    print(f'❌ 提取失败: {e}')
    exit(1)
PYTHON_EOF

echo -e "\n=== 3. 检查证书格式 ==="
echo "证书主题:"
openssl x509 -in qsgl.cn.crt -noout -subject

echo -e "\n证书公钥算法:"
openssl x509 -in qsgl.cn.crt -noout -text | grep "Public Key Algorithm" -A 2

echo -e "\n私钥类型:"
head -1 qsgl.cn.key

echo -e "\n=== 4. 验证EC私钥 ==="
openssl ec -in qsgl.cn.key -noout -check 2>&1

echo -e "\n=== 5. 验证私钥和证书匹配 ==="
CERT_PUBKEY=$(openssl x509 -in qsgl.cn.crt -noout -pubkey | openssl ec -pubin -outform DER 2>/dev/null | md5sum)
KEY_PUBKEY=$(openssl ec -in qsgl.cn.key -pubout -outform DER 2>/dev/null | md5sum)

if [ "$CERT_PUBKEY" = "$KEY_PUBKEY" ]; then
    echo "✓ 私钥和证书匹配"
else
    echo "❌ 私钥和证书不匹配"
    exit 1
fi

echo -e "\n=== 6. 设置权限 ==="
chmod 644 qsgl.cn.crt
chmod 600 qsgl.cn.key
echo "✓ 权限设置完成"

echo -e "\n=== 7. 备份当前证书 ==="
if [ -f qsgl.cn.crt.bak ]; then
    rm -f qsgl.cn.crt.bak.old qsgl.cn.key.bak.old
    mv qsgl.cn.crt.bak qsgl.cn.crt.bak.old
    mv qsgl.cn.key.bak qsgl.cn.key.bak.old
fi
cp qsgl.cn.crt qsgl.cn.crt.bak
cp qsgl.cn.key qsgl.cn.key.bak
echo "✓ 已备份到 .bak 文件"

echo -e "\n=== 8. 重启 Envoy ==="
docker restart envoy-proxy
sleep 4

echo -e "\n=== 9. 检查 Envoy 状态 ==="
if docker ps | grep -q envoy-proxy; then
    echo "✓ Envoy 容器运行中"
else
    echo "❌ Envoy 容器未运行"
    docker logs envoy-proxy --tail 30
    exit 1
fi

echo -e "\n=== 10. 检查 Envoy 日志中的证书加载信息 ==="
docker logs envoy-proxy --tail 30 2>&1 | grep -i "cert\|key\|tls" | tail -10

echo -e "\n=== 11. 测试 8443 端口 ==="
sleep 2
RESPONSE=$(curl -skI https://localhost:8443/ -H "Host: www.qsgl.cn" --connect-timeout 5 2>&1)
echo "$RESPONSE" | head -10

if echo "$RESPONSE" | grep -q "200 OK"; then
    echo -e "\n✅ 8443 端口测试成功!"
else
    echo -e "\n❌ 8443 端口测试失败"
    echo "完整响应:"
    echo "$RESPONSE"
fi

echo -e "\n=== 12. 显示证书信息 ==="
echo "证书有效期:"
openssl x509 -in qsgl.cn.crt -noout -dates

echo -e "\n证书SAN (Subject Alternative Names):"
openssl x509 -in qsgl.cn.crt -noout -ext subjectAltName
'@

Write-Host "正在执行证书部署..." -ForegroundColor Cyan

# 将脚本保存到临时文件
$tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
$deployCertScript | Out-File -FilePath $tempScript -Encoding ASCII -NoNewline

# 上传并执行脚本
scp -i $SSH_KEY -o StrictHostKeyChecking=no $tempScript ${USERNAME}@${SERVER}:/tmp/deploy-ec-cert.sh
ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o PasswordAuthentication=no $USERNAME@$SERVER "bash /tmp/deploy-ec-cert.sh; rm /tmp/deploy-ec-cert.sh"

# 清理临时文件
Remove-Item $tempScript -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ EC证书部署完成!" -ForegroundColor Green
    
    # 步骤5: 从Windows客户端测试
    Write-Host "`n📌 步骤5: 从Windows客户端测试外网访问" -ForegroundColor Yellow
    $testResponse = curl.exe -k -I https://${SERVER}:8443/ -H "Host: www.qsgl.cn" --connect-timeout 10
    
    Write-Host $testResponse -ForegroundColor White
    
    if ($testResponse -match "200 OK") {
        Write-Host "`n🎉 成功! 8443端口使用EC证书正常工作!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  外网测试未返回200 OK，请检查" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n❌ EC证书部署失败" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📝 后续操作:" -ForegroundColor Yellow
Write-Host "1. 检查浏览器访问: https://www.qsgl.cn:8443/" -ForegroundColor Gray
Write-Host "2. 查看证书信息: ssh $USERNAME@$SERVER 'openssl x509 -in /opt/envoy/certs/qsgl.cn.crt -noout -text'" -ForegroundColor Gray
Write-Host "3. 如果失败，恢复备份: ssh $USERNAME@$SERVER 'cd /opt/envoy/certs && cp qsgl.cn.crt.bak qsgl.cn.crt && cp qsgl.cn.key.bak qsgl.cn.key && docker restart envoy-proxy'" -ForegroundColor Gray
