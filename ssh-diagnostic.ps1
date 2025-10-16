# SSH服务器诊断PowerShell脚本
# 用于连接tx.qsgl.net服务器并诊断DNS API服务问题

param(
    [string]$ServerIP = "43.138.35.183",
    [string]$Username = "root",
    [string]$KeyPath = "C:\Users\Administrator\.ssh\id_rsa"
)

Write-Host "🔍 DNS API 服务器诊断工具" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 检查SSH密钥
if (-not (Test-Path $KeyPath)) {
    Write-Host "❌ SSH密钥文件不存在: $KeyPath" -ForegroundColor Red
    exit 1
}

Write-Host "🔑 使用SSH密钥: $KeyPath" -ForegroundColor Yellow
Write-Host "🖥️  连接服务器: $Username@$ServerIP (tx.qsgl.net)" -ForegroundColor Yellow
Write-Host ""

# 创建SSH命令
$sshCommand = @"
echo '=== DNS API 服务器快速诊断 ==='
echo '时间: '`$(date)
echo '服务器: tx.qsgl.net (43.138.35.183)'
echo '========================================='

# 检查Docker容器状态
echo '🐳 Docker容器状态:'
docker ps -a --filter 'name=dnsapi' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo '   Docker未运行或容器不存在'
echo ''

# 检查端口监听
echo '🌐 端口监听状态:'
echo '   HTTP端口 (5074):'
netstat -tlnp 2>/dev/null | grep ':5074' || echo '     ❌ 端口5074未监听'
echo '   HTTPS端口 (5075):'
netstat -tlnp 2>/dev/null | grep ':5075' || echo '     ❌ 端口5075未监听'
echo ''

# 检查防火墙
echo '🔥 防火墙状态:'
if command -v ufw >/dev/null 2>&1; then
    echo '   UFW状态:'
    ufw status 2>/dev/null | head -3
    echo '   端口规则:'
    ufw status 2>/dev/null | grep -E '5074|5075' || echo '     未找到5074/5075端口规则'
else
    echo '   UFW未安装'
fi
echo ''

# 测试本地服务
echo '🔍 本地服务测试:'
echo '   HTTP测试:'
curl -s -m 3 http://localhost:5074/api/wan-ip 2>/dev/null && echo '     ✅ HTTP服务正常' || echo '     ❌ HTTP服务异常'
echo '   HTTPS测试:'
curl -k -s -m 3 https://localhost:5075/api/wan-ip 2>/dev/null && echo '     ✅ HTTPS服务正常' || echo '     ❌ HTTPS服务异常'
echo ''

# 检查容器日志
echo '📋 容器日志 (最近10行):'
if docker ps -q --filter 'name=dnsapi' | grep -q .; then
    docker logs --tail 10 dnsapi 2>/dev/null || echo '   无法获取日志'
else
    echo '   容器未运行'
fi

echo '========================================='
"@

try {
    Write-Host "🚀 开始SSH连接和诊断..." -ForegroundColor Green
    
    # 执行SSH命令
    $result = ssh -i $KeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=10 $Username@$ServerIP $sshCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host $result -ForegroundColor White
        Write-Host ""
        Write-Host "✅ 诊断完成!" -ForegroundColor Green
        
        # 提供修复建议
        Write-Host "🔧 常见问题修复建议:" -ForegroundColor Yellow
        Write-Host "1. 如果容器未运行，执行:" -ForegroundColor Cyan
        Write-Host "   docker start dnsapi" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. 如果端口未监听，检查容器端口映射:" -ForegroundColor Cyan
        Write-Host "   docker run -d -p 5074:8080 -p 5075:8443 --name dnsapi [image]" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. 如果防火墙阻止，开放端口:" -ForegroundColor Cyan
        Write-Host "   sudo ufw allow 5074" -ForegroundColor Gray
        Write-Host "   sudo ufw allow 5075" -ForegroundColor Gray
        Write-Host ""
        Write-Host "4. 重新部署容器:" -ForegroundColor Cyan
        Write-Host "   docker-compose down && docker-compose up -d" -ForegroundColor Gray
    } else {
        Write-Host "❌ SSH连接失败!" -ForegroundColor Red
        Write-Host "请检查:" -ForegroundColor Yellow
        Write-Host "- 服务器地址是否正确" -ForegroundColor Gray
        Write-Host "- SSH密钥路径和权限" -ForegroundColor Gray
        Write-Host "- 网络连接状态" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ 执行过程中发生错误: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "📞 手动SSH连接命令:" -ForegroundColor Cyan
Write-Host "ssh -i $KeyPath $Username@$ServerIP" -ForegroundColor Gray