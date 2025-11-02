# 服务器端监控部署脚本
# 用途: 将监控脚本和配置部署到服务器

param(
    [string]$ServerHost = "43.138.35.183",
    [string]$SshKey = "C:\Key\tx.qsgl.net_id_ed25519",
    [switch]$DeployDockerCompose = $false
)

$SSH_CMD = "ssh -i $SshKey root@$ServerHost"
$SCP_CMD = "scp -i $SshKey"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "部署服务器端监控系统" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 创建监控目录
Write-Host "步骤 1: 创建监控目录" -ForegroundColor Yellow
Invoke-Expression "$SSH_CMD 'mkdir -p /opt/monitor /var/log'" | Out-Null
Write-Host "  ✅ 目录创建完成" -ForegroundColor Green
Write-Host ""

# 2. 上传监控脚本
Write-Host "步骤 2: 上传监控脚本" -ForegroundColor Yellow
$localScript = "K:\DNS\server-monitor\check-dnsapi.sh"
if (Test-Path $localScript) {
    & $SCP_CMD $localScript "root@${ServerHost}:/opt/monitor/check-dnsapi.sh"
    Invoke-Expression "$SSH_CMD 'chmod +x /opt/monitor/check-dnsapi.sh'"
    Write-Host "  ✅ 监控脚本已上传" -ForegroundColor Green
} else {
    Write-Host "  ❌ 监控脚本不存在: $localScript" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 3. 配置 cron 定时任务
Write-Host "步骤 3: 配置 cron 定时任务（每 5 分钟执行一次）" -ForegroundColor Yellow
$cronJob = "*/5 * * * * /opt/monitor/check-dnsapi.sh >> /var/log/dnsapi-monitor.log 2>&1"

$cronScript = @"
#!/bin/bash
# 检查 cron 任务是否已存在
if ! crontab -l 2>/dev/null | grep -q 'check-dnsapi.sh'; then
    # 添加新的 cron 任务
    (crontab -l 2>/dev/null; echo "$cronJob") | crontab -
    echo "cron 任务已添加"
else
    echo "cron 任务已存在"
fi

# 显示当前 cron 任务
echo ""
echo "当前 cron 任务:"
crontab -l | grep check-dnsapi
"@

$cronScript | Out-File -FilePath "$env:TEMP\setup-cron.sh" -Encoding ASCII -Force
& $SCP_CMD "$env:TEMP\setup-cron.sh" "root@${ServerHost}:/tmp/setup-cron.sh"
Invoke-Expression "$SSH_CMD 'bash /tmp/setup-cron.sh'"
Write-Host "  ✅ Cron 任务配置完成" -ForegroundColor Green
Write-Host ""

# 4. 部署 Docker Compose（可选）
if ($DeployDockerCompose) {
    Write-Host "步骤 4: 部署 Docker Compose 配置" -ForegroundColor Yellow
    
    $composeFile = "K:\DNS\server-monitor\docker-compose.yml"
    if (Test-Path $composeFile) {
        # 创建部署目录
        Invoke-Expression "$SSH_CMD 'mkdir -p /opt/dnsapi'" | Out-Null
        
        # 上传 docker-compose.yml
        & $SCP_CMD $composeFile "root@${ServerHost}:/opt/dnsapi/docker-compose.yml"
        
        Write-Host "  ✅ Docker Compose 配置已上传到 /opt/dnsapi/" -ForegroundColor Green
        Write-Host ""
        Write-Host "  📝 使用 Docker Compose 重新部署:" -ForegroundColor Cyan
        Write-Host "     ssh -i $SshKey root@$ServerHost" -ForegroundColor White
        Write-Host "     cd /opt/dnsapi" -ForegroundColor White
        Write-Host "     docker-compose down" -ForegroundColor White
        Write-Host "     docker-compose up -d" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "  ⚠️  Docker Compose 文件不存在: $composeFile" -ForegroundColor Yellow
    }
} else {
    Write-Host "步骤 4: 为现有容器添加健康检查" -ForegroundColor Yellow
    Write-Host "  注意: 无法直接为运行中的容器添加健康检查" -ForegroundColor Yellow
    Write-Host "  建议: 使用 Docker Compose 重新部署" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  如需部署，请运行:" -ForegroundColor Cyan
    Write-Host "     .\deploy-server-monitor.ps1 -DeployDockerCompose" -ForegroundColor White
    Write-Host ""
}

# 5. 测试监控脚本
Write-Host "步骤 5: 测试监控脚本" -ForegroundColor Yellow
Write-Host "  正在执行测试..." -ForegroundColor Cyan
Invoke-Expression "$SSH_CMD '/opt/monitor/check-dnsapi.sh'"
Write-Host ""

# 6. 查看日志
Write-Host "步骤 6: 查看最新日志" -ForegroundColor Yellow
Write-Host "  监控日志:" -ForegroundColor Cyan
Invoke-Expression "$SSH_CMD 'tail -10 /var/log/dnsapi-monitor.log 2>/dev/null || echo ""日志文件尚未创建""'"
Write-Host ""

# 7. 显示部署摘要
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 服务器端监控部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "部署信息:" -ForegroundColor Yellow
Write-Host "  服务器: $ServerHost" -ForegroundColor White
Write-Host "  监控脚本: /opt/monitor/check-dnsapi.sh" -ForegroundColor White
Write-Host "  监控日志: /var/log/dnsapi-monitor.log" -ForegroundColor White
Write-Host "  告警日志: /var/log/dnsapi-alerts.log" -ForegroundColor White
Write-Host "  执行频率: 每 5 分钟" -ForegroundColor White
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Yellow
Write-Host "  # 查看监控日志" -ForegroundColor Cyan
Write-Host "  ssh -i $SshKey root@$ServerHost 'tail -f /var/log/dnsapi-monitor.log'" -ForegroundColor White
Write-Host ""
Write-Host "  # 查看告警日志" -ForegroundColor Cyan
Write-Host "  ssh -i $SshKey root@$ServerHost 'cat /var/log/dnsapi-alerts.log'" -ForegroundColor White
Write-Host ""
Write-Host "  # 手动执行监控" -ForegroundColor Cyan
Write-Host "  ssh -i $SshKey root@$ServerHost '/opt/monitor/check-dnsapi.sh'" -ForegroundColor White
Write-Host ""
Write-Host "  # 查看 cron 任务" -ForegroundColor Cyan
Write-Host "  ssh -i $SshKey root@$ServerHost 'crontab -l'" -ForegroundColor White
Write-Host ""

if ($DeployDockerCompose) {
    Write-Host "Docker Compose 配置:" -ForegroundColor Yellow
    Write-Host "  配置文件: /opt/dnsapi/docker-compose.yml" -ForegroundColor White
    Write-Host "  健康检查: 每 30 秒" -ForegroundColor White
    Write-Host "  失败重试: 3 次" -ForegroundColor White
    Write-Host ""
}
