# DNS API 服务诊断和自动修复脚本
# 用于检查和修复 tx.qsgl.net:5075 服务异常

param(
    [switch]$AutoFix = $false
)

$SSH_KEY = "C:\Key\tx.qsgl.net_id_ed25519"
$SERVER = "43.138.35.183"
$SERVICE_URL = "https://tx.qsgl.net:5075"
$CONTAINER_NAME = "dnsapi"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔍 DNS API 服务诊断工具" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 测试网络连通性
Write-Host "步骤 1: 测试网络连通性" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$pingTest = Test-Connection -ComputerName $SERVER -Count 2 -Quiet
if ($pingTest) {
    Write-Host "✅ 服务器 PING 测试通过" -ForegroundColor Green
} else {
    Write-Host "❌ 服务器 PING 测试失败" -ForegroundColor Red
    exit 1
}

$port5075 = Test-NetConnection -ComputerName $SERVER -Port 5075 -WarningAction SilentlyContinue
$port5074 = Test-NetConnection -ComputerName $SERVER -Port 5074 -WarningAction SilentlyContinue

Write-Host "  - 端口 5074 (HTTP):  $($port5074.TcpTestSucceeded ? '✅ 开放' : '❌ 关闭')" -ForegroundColor $(if($port5074.TcpTestSucceeded){'Green'}else{'Red'})
Write-Host "  - 端口 5075 (HTTPS): $($port5075.TcpTestSucceeded ? '✅ 开放' : '❌ 关闭')" -ForegroundColor $(if($port5075.TcpTestSucceeded){'Green'}else{'Red'})
Write-Host ""

# 2. 检查 Docker 容器状态
Write-Host "步骤 2: 检查 Docker 容器状态" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$containerStatus = ssh -i $SSH_KEY -o StrictHostKeyChecking=no root@$SERVER "docker ps -a --filter name=$CONTAINER_NAME --format '{{.Status}}'"

Write-Host "  容器状态: $containerStatus" -ForegroundColor Cyan

$isRunning = $containerStatus -match "Up"
if ($isRunning) {
    Write-Host "  ✅ 容器正在运行" -ForegroundColor Green
} else {
    Write-Host "  ❌ 容器已停止" -ForegroundColor Red
}
Write-Host ""

# 3. 检查重启策略
Write-Host "步骤 3: 检查容器重启策略" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$restartPolicy = ssh -i $SSH_KEY root@$SERVER "docker inspect $CONTAINER_NAME --format='{{.HostConfig.RestartPolicy.Name}}'"
Write-Host "  当前策略: $restartPolicy" -ForegroundColor Cyan

if ($restartPolicy -eq "no") {
    Write-Host "  ⚠️  警告: 未配置自动重启策略！" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ 已配置自动重启策略" -ForegroundColor Green
}
Write-Host ""

# 4. 检查系统资源
Write-Host "步骤 4: 检查系统资源" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$memInfo = ssh -i $SSH_KEY root@$SERVER "free -h | grep Mem"
$diskInfo = ssh -i $SSH_KEY root@$SERVER "df -h / | tail -1"

Write-Host "  内存: $memInfo" -ForegroundColor Cyan
Write-Host "  磁盘: $diskInfo" -ForegroundColor Cyan
Write-Host ""

# 5. 检查容器日志（最后异常）
Write-Host "步骤 5: 检查容器日志（最近 20 行）" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$logs = ssh -i $SSH_KEY root@$SERVER "docker logs --tail 20 $CONTAINER_NAME 2>&1"
Write-Host $logs -ForegroundColor Gray
Write-Host ""

# 6. 测试服务端点
Write-Host "步骤 6: 测试服务端点" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

if ($port5075.TcpTestSucceeded) {
    try {
        $response = curl.exe -k -s --max-time 10 "$SERVICE_URL/api/health"
        $healthData = $response | ConvertFrom-Json
        
        Write-Host "  ✅ HTTPS 服务正常" -ForegroundColor Green
        Write-Host "  状态: $($healthData.status)" -ForegroundColor Cyan
        Write-Host "  版本: $($healthData.version)" -ForegroundColor Cyan
        Write-Host "  运行时: $($healthData.runtime)" -ForegroundColor Cyan
    } catch {
        Write-Host "  ❌ HTTPS 服务异常: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ 端口 5075 不可访问" -ForegroundColor Red
}
Write-Host ""

# 自动修复逻辑
if (!$isRunning -or $restartPolicy -eq "no") {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "⚠️  发现问题需要修复" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    if (!$isRunning) {
        Write-Host "  • 容器已停止，需要启动" -ForegroundColor Yellow
    }
    
    if ($restartPolicy -eq "no") {
        Write-Host "  • 未配置自动重启策略" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    if ($AutoFix) {
        Write-Host "🔧 开始自动修复..." -ForegroundColor Cyan
        Write-Host ""
        
        if (!$isRunning) {
            Write-Host "  正在启动容器..." -ForegroundColor Cyan
            ssh -i $SSH_KEY root@$SERVER "docker start $CONTAINER_NAME" | Out-Null
            Write-Host "  ✅ 容器已启动" -ForegroundColor Green
        }
        
        if ($restartPolicy -eq "no") {
            Write-Host "  正在设置自动重启策略..." -ForegroundColor Cyan
            ssh -i $SSH_KEY root@$SERVER "docker update --restart=unless-stopped $CONTAINER_NAME" | Out-Null
            Write-Host "  ✅ 已设置为 unless-stopped" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "  等待服务启动..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        
        # 验证修复结果
        Write-Host ""
        Write-Host "验证修复结果..." -ForegroundColor Yellow
        
        $newStatus = ssh -i $SSH_KEY root@$SERVER "docker ps --filter name=$CONTAINER_NAME --format '{{.Status}}'"
        if ($newStatus -match "Up") {
            Write-Host "  ✅ 容器运行正常" -ForegroundColor Green
        } else {
            Write-Host "  ❌ 容器仍未运行" -ForegroundColor Red
        }
        
        $newPolicy = ssh -i $SSH_KEY root@$SERVER "docker inspect $CONTAINER_NAME --format='{{.HostConfig.RestartPolicy.Name}}'"
        Write-Host "  ✅ 重启策略: $newPolicy" -ForegroundColor Green
        
        # 测试服务
        Start-Sleep -Seconds 3
        try {
            $testResponse = curl.exe -k -s --max-time 10 "$SERVICE_URL/api/health"
            if ($testResponse) {
                Write-Host "  ✅ HTTPS 服务可访问" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ⚠️  服务可能仍在启动中" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "✅ 修复完成！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
    } else {
        Write-Host "💡 运行以下命令自动修复:" -ForegroundColor Cyan
        Write-Host "   .\diagnose-and-fix-dnsapi.ps1 -AutoFix" -ForegroundColor White
        Write-Host ""
        Write-Host "或手动执行修复命令:" -ForegroundColor Cyan
        if (!$isRunning) {
            Write-Host "   ssh -i $SSH_KEY root@$SERVER `"docker start $CONTAINER_NAME`"" -ForegroundColor White
        }
        if ($restartPolicy -eq "no") {
            Write-Host "   ssh -i $SSH_KEY root@$SERVER `"docker update --restart=unless-stopped $CONTAINER_NAME`"" -ForegroundColor White
        }
    }
} else {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ 所有检查通过，服务运行正常" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "📋 服务信息:" -ForegroundColor Cyan
Write-Host "  HTTP:  http://tx.qsgl.net:5074" -ForegroundColor White
Write-Host "  HTTPS: https://tx.qsgl.net:5075" -ForegroundColor White
Write-Host "  SSH:   ssh -i $SSH_KEY root@$SERVER" -ForegroundColor White
Write-Host ""
