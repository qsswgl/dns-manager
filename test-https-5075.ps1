# HTTPS 端口 5075 测试脚本
# 用于验证 HTTPS 服务是否正常工作

param(
    [string]$Server = "tx.qsgl.net",
    [string]$Port = "5075"
)

Write-Host "=== HTTPS 服务测试 ===" -ForegroundColor Cyan
Write-Host "服务器: $Server" -ForegroundColor Yellow
Write-Host "端口: $Port" -ForegroundColor Yellow
Write-Host ""

# 1. TCP连接测试
Write-Host "1. TCP连接测试..." -ForegroundColor Green
$tcpTest = Test-NetConnection -ComputerName $Server -Port $Port -WarningAction SilentlyContinue

if ($tcpTest.TcpTestSucceeded) {
    Write-Host "   ✅ TCP连接成功" -ForegroundColor Green
    Write-Host "   远程IP: $($tcpTest.RemoteAddress)" -ForegroundColor Cyan
    Write-Host "   RTT: $($tcpTest.PingReplyDetails.RoundtripTime) ms" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ TCP连接失败" -ForegroundColor Red
    Write-Host "   请检查:" -ForegroundColor Yellow
    Write-Host "   - 容器是否运行" -ForegroundColor Yellow
    Write-Host "   - 端口映射是否正确 (应为 5075:5075)" -ForegroundColor Yellow
    Write-Host "   - 防火墙规则是否开放端口 5075" -ForegroundColor Yellow
    exit 1
}

# 2. HTTPS证书测试
Write-Host ""
Write-Host "2. HTTPS证书测试..." -ForegroundColor Green

$certInfo = curl.exe -k -v "https://${Server}:${Port}/" 2>&1 | Select-String -Pattern "subject|issuer|expire|TLS"
if ($certInfo) {
    Write-Host "   ✅ HTTPS握手成功" -ForegroundColor Green
    foreach ($line in $certInfo) {
        Write-Host "   $line" -ForegroundColor Cyan
    }
} else {
    Write-Host "   ⚠️  无法获取证书信息" -ForegroundColor Yellow
}

# 3. 根路径测试
Write-Host ""
Write-Host "3. 根路径访问测试..." -ForegroundColor Green

$rootTest = curl.exe -k -i "https://${Server}:${Port}/" 2>$null | Select-String -Pattern "HTTP"
if ($rootTest) {
    Write-Host "   ✅ 根路径响应: $rootTest" -ForegroundColor Green
} else {
    Write-Host "   ❌ 根路径无响应" -ForegroundColor Red
}

# 4. API端点测试
Write-Host ""
Write-Host "4. API端点测试..." -ForegroundColor Green

# 测试证书管理状态API
try {
    $statusJson = curl.exe -k -s "https://${Server}:${Port}/api/cert-manager/status"
    $status = $statusJson | ConvertFrom-Json
    
    if ($status.success) {
        Write-Host "   ✅ /api/cert-manager/status 正常" -ForegroundColor Green
        Write-Host "   证书总数: $($status.summary.totalCertificates)" -ForegroundColor Cyan
        Write-Host "   自动续签: $($status.summary.autoRenewEnabled)" -ForegroundColor Cyan
        Write-Host "   需要续签: $($status.summary.needsRenewal)" -ForegroundColor Cyan
        Write-Host "   已过期: $($status.summary.expired)" -ForegroundColor Cyan
        Write-Host "   健康: $($status.summary.healthy)" -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️  API返回失败状态" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ API测试失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 测试证书列表API
Write-Host ""
try {
    $listJson = curl.exe -k -s "https://${Server}:${Port}/api/cert-manager/list"
    $list = $listJson | ConvertFrom-Json
    
    if ($list.success) {
        Write-Host "   ✅ /api/cert-manager/list 正常" -ForegroundColor Green
        Write-Host "   证书数量: $($list.count)" -ForegroundColor Cyan
        
        foreach ($cert in $list.certificates) {
            Write-Host ""
            Write-Host "   域名: $($cert.domain)" -ForegroundColor Yellow
            Write-Host "   泛域名: $($cert.isWildcard)" -ForegroundColor Cyan
            Write-Host "   自动续签: $($cert.autoRenew)" -ForegroundColor Cyan
            Write-Host "   剩余天数: $($cert.daysUntilExpiry)" -ForegroundColor Cyan
            Write-Host "   部署目标数: $($cert.deployments.Count)" -ForegroundColor Cyan
        }
    }
} catch {
    Write-Host "   ❌ 列表API测试失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. 性能测试
Write-Host ""
Write-Host "5. 性能测试..." -ForegroundColor Green

$times = @()
for ($i = 1; $i -le 5; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    curl.exe -k -s "https://${Server}:${Port}/api/cert-manager/status" | Out-Null
    $sw.Stop()
    $times += $sw.ElapsedMilliseconds
}

$avgTime = ($times | Measure-Object -Average).Average
$minTime = ($times | Measure-Object -Minimum).Minimum
$maxTime = ($times | Measure-Object -Maximum).Maximum

Write-Host "   响应时间统计 (5次请求):" -ForegroundColor Cyan
Write-Host "   最小: ${minTime}ms" -ForegroundColor Cyan
Write-Host "   最大: ${maxTime}ms" -ForegroundColor Cyan
Write-Host "   平均: ${avgTime}ms" -ForegroundColor Cyan

if ($avgTime -lt 100) {
    Write-Host "   ✅ 响应速度优秀" -ForegroundColor Green
} elseif ($avgTime -lt 500) {
    Write-Host "   ✅ 响应速度良好" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  响应速度较慢" -ForegroundColor Yellow
}

# 总结
Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "访问地址:" -ForegroundColor Cyan
Write-Host "  主页: https://$Server`:$Port/" -ForegroundColor Yellow
Write-Host "  API状态: https://$Server`:$Port/api/cert-manager/status" -ForegroundColor Yellow
Write-Host "  API列表: https://$Server`:$Port/api/cert-manager/list" -ForegroundColor Yellow
Write-Host ""
