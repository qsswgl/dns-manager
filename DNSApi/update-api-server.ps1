# 自动更新 tx.qsgl.net API 服务器
# 使用腾讯云专用 SSH 密钥

$ErrorActionPreference = "Stop"

$SSH_KEY = "C:\Key\tx.qsgl.net_id_ed25519"
$SERVER = "43.138.35.183"
$REGISTRY = "43.138.35.183:5000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  tx.qsgl.net API 服务器自动更新" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 验证 SSH 密钥
Write-Host "[1/5] 验证 SSH 密钥..." -ForegroundColor Yellow
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "❌ SSH 密钥不存在: $SSH_KEY" -ForegroundColor Red
    exit 1
}
Write-Host "✅ SSH 密钥已找到" -ForegroundColor Green

# 2. 测试 SSH 连接
Write-Host "`n[2/5] 测试 SSH 连接..." -ForegroundColor Yellow
$testResult = ssh -i $SSH_KEY -o ConnectTimeout=10 root@$SERVER "echo 'SSH连接成功'" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ SSH 连接失败" -ForegroundColor Red
    Write-Host $testResult
    exit 1
}
Write-Host "✅ $testResult" -ForegroundColor Green

# 3. 构建 Docker 镜像
Write-Host "`n[3/5] 构建 Docker 镜像（包含 P-256 修复）..." -ForegroundColor Yellow
Push-Location K:\DNS\DNSApi

# 先编译项目
Write-Host "   编译项目..." -ForegroundColor Gray
dotnet publish -c Release -o publish | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 编译失败" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✅ 编译成功" -ForegroundColor Green

# 构建 Docker 镜像
Write-Host "   构建 Docker 镜像..." -ForegroundColor Gray
docker build -t dnsapi:latest -f Dockerfile . | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker 构建失败" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✅ Docker 镜像构建成功" -ForegroundColor Green

# 4. 推送到私有 Registry
Write-Host "`n[4/5] 推送镜像到私有 Registry..." -ForegroundColor Yellow
docker tag dnsapi:latest ${REGISTRY}/dnsapi:latest
docker tag dnsapi:latest ${REGISTRY}/dnsapi:p256

Write-Host "   推送 latest 标签..." -ForegroundColor Gray
docker push ${REGISTRY}/dnsapi:latest | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 推送 latest 失败" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "   推送 p256 标签..." -ForegroundColor Gray
docker push ${REGISTRY}/dnsapi:p256 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 推送 p256 失败" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✅ 镜像推送成功" -ForegroundColor Green

Pop-Location

# 5. 在服务器上更新容器
Write-Host "`n[5/5] 更新服务器上的 DNSApi 容器..." -ForegroundColor Yellow

$updateScript = @'
#!/bin/bash
set -e

echo "拉取最新镜像..."
docker pull 43.138.35.183:5000/dnsapi:latest

echo "停止旧容器..."
docker stop dnsapi 2>/dev/null || true
docker rm dnsapi 2>/dev/null || true

echo "启动新容器..."
docker run -d \
  --name dnsapi \
  --restart unless-stopped \
  -p 5074:5074 \
  -p 5075:5075 \
  -v /opt/dns-certs:/app/certificates \
  43.138.35.183:5000/dnsapi:latest

sleep 5

echo ""
echo "=== 容器状态 ==="
if docker ps | grep -q dnsapi; then
  echo "✅ DNSApi 容器运行中"
  docker logs dnsapi --tail 5
else
  echo "❌ DNSApi 容器未运行"
  docker logs dnsapi --tail 20
  exit 1
fi
'@

# 将脚本上传到服务器并执行
$tempFile = [System.IO.Path]::GetTempFileName()
$updateScript | Out-File -FilePath $tempFile -Encoding ASCII
scp -i $SSH_KEY $tempFile root@${SERVER}:/tmp/update-dnsapi.sh
ssh -i $SSH_KEY root@$SERVER "bash /tmp/update-dnsapi.sh"
Remove-Item $tempFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 容器更新失败" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ✅ API 服务器更新完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 6. 验证 API 返回 P-256 证书
Write-Host "验证 P-256 证书 API..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

$verifyScript = @'
curl -s -X POST 'https://tx.qsgl.net:5075/api/request-cert' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'domain=qsgl.cn&provider=DNSPOD' | \
  jq -r '.key' | \
  openssl ec -text -noout 2>&1 | \
  grep 'Private-Key'
'@

Write-Host "测试证书曲线类型..." -ForegroundColor Gray
$result = ssh -i $SSH_KEY root@$SERVER $verifyScript

if ($result -match "256 bit") {
    Write-Host "成功! API 现在返回 P-256 ECDSA 证书" -ForegroundColor Green
    Write-Host "   $result" -ForegroundColor Gray
} else {
    Write-Host "警告: $result" -ForegroundColor Yellow
    Write-Host "   可能需要等待容器完全启动" -ForegroundColor Yellow
}

Write-Host "`n所有操作完成!" -ForegroundColor Green
Write-Host "   - API 地址: https://tx.qsgl.net:5075" -ForegroundColor Gray
Write-Host "   - 证书 API: https://tx.qsgl.net:5075/api/request-cert" -ForegroundColor Gray
