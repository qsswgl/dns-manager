# 在 Windows 上生成 RSA 证书并上传到服务器

$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_qsgl_nopass"
$SERVER = "root@www.qsgl.cn"

Write-Host "🔑 在本地生成 RSA 证书..." -ForegroundColor Yellow

# 生成私钥
openssl genrsa -out "$env:TEMP\qsgl.cn.key" 2048

# 生成证书
openssl req -new -x509 -key "$env:TEMP\qsgl.cn.key" -days 90 -out "$env:TEMP\qsgl.cn.crt" `
  -subj "/CN=*.qsgl.cn" `
  -addext "subjectAltName=DNS:qsgl.cn,DNS:*.qsgl.cn"

Write-Host "✓ 证书已生成" -ForegroundColor Green

# 检查文件
Get-Content "$env:TEMP\qsgl.cn.key" | Select-Object -First 1
Get-Content "$env:TEMP\qsgl.cn.key" | Select-Object -Last 1

Write-Host "`n📤 上传到服务器..." -ForegroundColor Yellow
scp -i $SSH_KEY "$env:TEMP\qsgl.cn.key" "${SERVER}:/opt/envoy/certs/qsgl.cn.key"
scp -i $SSH_KEY "$env:TEMP\qsgl.cn.crt" "${SERVER}:/opt/envoy/certs/qsgl.cn.crt"

Write-Host "✓ 上传完成" -ForegroundColor Green

Write-Host "`n🔄 设置权限并重启 Envoy..." -ForegroundColor Yellow
ssh -i $SSH_KEY $SERVER @"
chmod 644 /opt/envoy/certs/qsgl.cn.crt
chmod 600 /opt/envoy/certs/qsgl.cn.key
docker restart envoy-proxy
sleep 8
docker ps | grep envoy
docker logs envoy-proxy --tail 5
"@

Write-Host ""
Write-Host "📌 测试外网访问..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
curl.exe -k -I https://www.qsgl.cn:8443/ -H "Host: www.qsgl.cn"

# 清理临时文件
Remove-Item "$env:TEMP\qsgl.cn.key" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\qsgl.cn.crt" -Force -ErrorAction SilentlyContinue
