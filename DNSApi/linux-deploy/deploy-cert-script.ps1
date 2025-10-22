# 部署自动证书续期脚本到阿里云服务器
# 使用方法: .\deploy-cert-script.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== 部署证书续期脚本到阿里云服务器 ===" -ForegroundColor Cyan
Write-Host ""

$sshKey = "C:\KEY\www.qsgl.cn_id_ed25519"
$server = "root@www.qsgl.cn"
$localScriptPath = "K:\DNS\DNSApi\linux-deploy\renew-cert-auto.sh"
$localConfigPath = "K:\DNS\DNSApi\linux-deploy\envoy-domain.conf"
$remoteScriptPath = "/usr/local/bin/renew-qsgl-cert.sh"
$remoteConfigPath = "/etc/envoy-domain.conf"

# 检查文件是否存在
if (-not (Test-Path $localScriptPath)) {
    Write-Host "错误: 找不到脚本文件 $localScriptPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $localConfigPath)) {
    Write-Host "错误: 找不到配置文件 $localConfigPath" -ForegroundColor Red
    exit 1
}

Write-Host "1. 上传续期脚本..." -ForegroundColor Yellow
scp -i $sshKey $localScriptPath "${server}:${remoteScriptPath}"
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ 脚本上传成功" -ForegroundColor Green
} else {
    Write-Host "   ✗ 脚本上传失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. 上传域名配置文件..." -ForegroundColor Yellow
scp -i $sshKey $localConfigPath "${server}:${remoteConfigPath}"
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ 配置上传成功" -ForegroundColor Green
} else {
    Write-Host "   ✗ 配置上传失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "3. 设置脚本权限..." -ForegroundColor Yellow
ssh -i $sshKey $server "chmod +x $remoteScriptPath; chmod 644 $remoteConfigPath"
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ 权限设置成功" -ForegroundColor Green
} else {
    Write-Host "   ✗ 权限设置失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "4. 验证部署..." -ForegroundColor Yellow
ssh -i $sshKey $server "ls -l $remoteScriptPath $remoteConfigPath; echo ''; echo '当前配置的域名:'; cat $remoteConfigPath"

Write-Host ""
Write-Host "=== 部署完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "使用说明:" -ForegroundColor Cyan
Write-Host "  1. 自动续期: ssh root@www.qsgl.cn '$remoteScriptPath'" -ForegroundColor Gray
Write-Host "  2. 修改域名: ssh root@www.qsgl.cn 'echo qsgl.net > $remoteConfigPath'" -ForegroundColor Gray
Write-Host "  3. 查看日志: ssh root@www.qsgl.cn 'tail -f /var/log/cert-renewal.log'" -ForegroundColor Gray
Write-Host ""
Write-Host "提示: 域名配置保存在 $remoteConfigPath" -ForegroundColor Yellow
Write-Host "修改后重新运行续期脚本即可生成新域名的证书" -ForegroundColor Yellow
