# DNS API 服务部署脚本 (PowerShell)
# 用于部署到腾讯云服务器 tx.qsgl.net

param(
    [string]$Version = "cert-manager-v3",
    [string]$Registry = "43.138.35.183:5000",
    [string]$SshKey = "C:\Key\tx.qsgl.net_id_ed25519",
    [string]$Server = "43.138.35.183"
)

Write-Host "=== DNS API 服务部署 ===" -ForegroundColor Cyan
Write-Host "版本: $Version" -ForegroundColor Yellow
Write-Host "Registry: $Registry" -ForegroundColor Yellow
Write-Host "服务器: $Server" -ForegroundColor Yellow
Write-Host ""

# 1. 构建镜像（可选）
$build = Read-Host "是否需要构建新镜像? (y/N)"
if ($build -eq 'y' -or $build -eq 'Y') {
    Write-Host "正在构建镜像..." -ForegroundColor Green
    Set-Location "k:\DNS\DNSApi"
    
    # 发布应用
    Write-Host "1. 发布应用..." -ForegroundColor Yellow
    dotnet publish -c Release -o publish --self-contained false
    
    # 构建Docker镜像
    Write-Host "2. 构建Docker镜像..." -ForegroundColor Yellow
    docker build -t "${Registry}/dnsapi:${Version}" -f Dockerfile.simple .
    
    # 推送到Registry
    Write-Host "3. 推送到Registry..." -ForegroundColor Yellow
    docker push "${Registry}/dnsapi:${Version}"
    
    # 更新latest标签
    $updateLatest = Read-Host "是否更新latest标签? (y/N)"
    if ($updateLatest -eq 'y' -or $updateLatest -eq 'Y') {
        Write-Host "4. 更新latest标签..." -ForegroundColor Yellow
        docker tag "${Registry}/dnsapi:${Version}" "${Registry}/dnsapi:latest"
        docker push "${Registry}/dnsapi:latest"
    }
}

# 2. 部署到服务器
Write-Host ""
Write-Host "正在部署到服务器..." -ForegroundColor Green

$deployCommand = @"
docker pull ${Registry}/dnsapi:${Version} && \
docker stop dnsapi 2>/dev/null || true && \
docker rm dnsapi 2>/dev/null || true && \
docker run -d --name dnsapi \
  -p 5074:5074 \
  -p 5075:5075 \
  -v /opt/shared-certs:/opt/shared-certs:rw \
  -v /opt/acme-scripts:/opt/acme-scripts:ro \
  -v /root/.acme.sh:/root/.acme.sh:rw \
  ${Registry}/dnsapi:${Version}
"@

Write-Host "执行部署命令..." -ForegroundColor Yellow
ssh -i $SshKey root@$Server $deployCommand

# 3. 等待服务启动
Write-Host ""
Write-Host "等待服务启动..." -ForegroundColor Green
Start-Sleep -Seconds 5

# 4. 验证部署
Write-Host ""
Write-Host "验证部署状态..." -ForegroundColor Green

# 检查容器状态
Write-Host "1. 容器状态:" -ForegroundColor Yellow
ssh -i $SshKey root@$Server "docker ps --filter name=dnsapi --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# 检查端口连接
Write-Host ""
Write-Host "2. 端口连接测试:" -ForegroundColor Yellow
$http = Test-NetConnection -ComputerName $Server -Port 5074 -WarningAction SilentlyContinue
$https = Test-NetConnection -ComputerName $Server -Port 5075 -WarningAction SilentlyContinue

if ($http.TcpTestSucceeded) {
    Write-Host "   HTTP 5074: ✅ 正常" -ForegroundColor Green
} else {
    Write-Host "   HTTP 5074: ❌ 失败" -ForegroundColor Red
}

if ($https.TcpTestSucceeded) {
    Write-Host "   HTTPS 5075: ✅ 正常" -ForegroundColor Green
} else {
    Write-Host "   HTTPS 5075: ❌ 失败" -ForegroundColor Red
}

# 测试API
Write-Host ""
Write-Host "3. API测试:" -ForegroundColor Yellow

try {
    $httpResult = curl.exe -s http://${Server}:5074/api/cert-manager/status | ConvertFrom-Json
    if ($httpResult.success) {
        Write-Host "   HTTP API: ✅ 正常" -ForegroundColor Green
        Write-Host "   证书总数: $($httpResult.summary.totalCertificates)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   HTTP API: ❌ 失败" -ForegroundColor Red
}

try {
    $httpsResult = curl.exe -k -s https://${Server}:5075/api/cert-manager/status | ConvertFrom-Json
    if ($httpsResult.success) {
        Write-Host "   HTTPS API: ✅ 正常" -ForegroundColor Green
    }
} catch {
    Write-Host "   HTTPS API: ❌ 失败" -ForegroundColor Red
}

# 5. 显示日志
Write-Host ""
$showLogs = Read-Host "是否查看容器日志? (y/N)"
if ($showLogs -eq 'y' -or $showLogs -eq 'Y') {
    Write-Host ""
    Write-Host "=== 容器日志 (最后30行) ===" -ForegroundColor Cyan
    ssh -i $SshKey root@$Server "docker logs --tail 30 dnsapi"
}

Write-Host ""
Write-Host "=== 部署完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "服务访问地址:" -ForegroundColor Cyan
Write-Host "  HTTP:  http://tx.qsgl.net:5074/" -ForegroundColor Yellow
Write-Host "  HTTPS: https://tx.qsgl.net:5075/" -ForegroundColor Yellow
Write-Host "  API:   https://tx.qsgl.net:5075/api/cert-manager/status" -ForegroundColor Yellow
Write-Host ""
