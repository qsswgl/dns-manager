# GitHub SSH over HTTPS 推送脚本
# 使用密钥: C:\Users\Administrator\.ssh\id_rsa

Write-Host "🚀 开始推送项目到 GitHub (SSH over HTTPS)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 设置工作目录
Set-Location "K:\DNS"

# 1. 配置 SSH 使用 HTTPS 端口 443
Write-Host "`n📝 步骤 1: 配置 SSH over HTTPS (端口 443)" -ForegroundColor Yellow
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$sshConfigDir = Split-Path $sshConfigPath -Parent

# 确保 .ssh 目录存在
if (!(Test-Path $sshConfigDir)) {
    New-Item -ItemType Directory -Path $sshConfigDir -Force | Out-Null
}

# 检查是否已有 GitHub HTTPS 配置
$configContent = if (Test-Path $sshConfigPath) { Get-Content $sshConfigPath -Raw } else { "" }

if ($configContent -notmatch "Host github.com") {
    Write-Host "   添加 GitHub SSH over HTTPS 配置..." -ForegroundColor Cyan
    
    $githubConfig = @"

# GitHub SSH over HTTPS (端口 443)
Host github.com
    Hostname ssh.github.com
    Port 443
    User git
    IdentityFile C:\Users\Administrator\.ssh\id_rsa
    IdentitiesOnly yes
"@
    
    Add-Content -Path $sshConfigPath -Value $githubConfig
    Write-Host "   ✅ SSH 配置已添加到: $sshConfigPath" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  SSH 配置已存在，跳过" -ForegroundColor Gray
}

# 2. 测试 SSH 连接
Write-Host "`n🔍 步骤 2: 测试 GitHub SSH 连接" -ForegroundColor Yellow
Write-Host "   正在测试连接到 ssh.github.com:443 ..." -ForegroundColor Cyan

try {
    $testResult = ssh -T git@github.com 2>&1
    if ($testResult -match "successfully authenticated" -or $testResult -match "qsswgl") {
        Write-Host "   ✅ SSH 连接成功！" -ForegroundColor Green
        Write-Host "   认证信息: $testResult" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  SSH 连接测试: $testResult" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  SSH 测试出现异常，但可能仍然可以推送" -ForegroundColor Yellow
}

# 3. 确认远程仓库配置
Write-Host "`n🔗 步骤 3: 检查 Git 远程仓库配置" -ForegroundColor Yellow
$remoteUrl = git remote get-url origin 2>&1

if ($remoteUrl -match "github.com:qsswgl/dns-manager") {
    Write-Host "   ✅ 远程仓库: $remoteUrl" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  当前远程仓库: $remoteUrl" -ForegroundColor Yellow
    Write-Host "   正在设置为 SSH 地址..." -ForegroundColor Cyan
    git remote set-url origin git@github.com:qsswgl/dns-manager.git
    Write-Host "   ✅ 已更新为: git@github.com:qsswgl/dns-manager.git" -ForegroundColor Green
}

# 4. 显示当前状态
Write-Host "`n📊 步骤 4: Git 仓库状态" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
git status --short

# 5. 添加所有更改
Write-Host "`n➕ 步骤 5: 添加所有更改到暂存区" -ForegroundColor Yellow
Write-Host "   正在添加文件..." -ForegroundColor Cyan

git add -A
$stagedFiles = git diff --cached --name-only | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "   ✅ 已添加 $stagedFiles 个文件到暂存区" -ForegroundColor Green

# 6. 提交更改
Write-Host "`n💾 步骤 6: 提交更改" -ForegroundColor Yellow
$commitDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$commitMessage = @"
feat: Add certificate manager and auto-start features

- Certificate management service with auto-renewal and deployment
- DNSUpdaterTray auto-start on system boot
- Batch files for easy installation
- Support SSH, Docker Volume, Local Copy deployment
- Complete documentation and guides
- Fix HTTPS port 5075 access issue

Update: $commitDate
"@

git commit -m $commitMessage

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ 提交成功！" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  没有新的更改需要提交" -ForegroundColor Gray
}

# 7. 推送到 GitHub
Write-Host "`n🚀 步骤 7: 推送到 GitHub" -ForegroundColor Yellow
Write-Host "   正在推送到 origin/master..." -ForegroundColor Cyan
Write-Host "   使用 SSH over HTTPS (端口 443)" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan

# 设置 GIT_SSH_COMMAND 环境变量以确保使用正确的 SSH 配置
$env:GIT_SSH_COMMAND = "ssh -v -i C:\Users\Administrator\.ssh\id_rsa"

git push -u origin master --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "🎉 推送成功！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "📍 仓库地址:" -ForegroundColor Cyan
    Write-Host "   https://github.com/qsswgl/dns-manager" -ForegroundColor White
    Write-Host "" -ForegroundColor Cyan
    Write-Host "🔗 SSH 克隆地址:" -ForegroundColor Cyan
    Write-Host "   git@github.com:qsswgl/dns-manager.git" -ForegroundColor White
    Write-Host "" -ForegroundColor Cyan
    Write-Host "📊 推送统计:" -ForegroundColor Cyan
    Write-Host "   提交数: $(git rev-list --count origin/master..HEAD 2>$null)" -ForegroundColor White
    Write-Host "   SSH 方式: HTTPS 端口 443" -ForegroundColor White
} else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "❌ 推送失败！" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "1. SSH 密钥权限问题" -ForegroundColor White
    Write-Host "2. GitHub 访问权限问题" -ForegroundColor White
    Write-Host "3. 网络连接问题" -ForegroundColor White
    Write-Host "" -ForegroundColor Cyan
    Write-Host "故障排查步骤:" -ForegroundColor Yellow
    Write-Host "1. 验证 SSH 密钥:" -ForegroundColor White
    Write-Host "   ssh -T git@github.com" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Cyan
    Write-Host "2. 检查密钥权限:" -ForegroundColor White
    Write-Host "   icacls C:\Users\Administrator\.ssh\id_rsa" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Cyan
    Write-Host "3. 查看详细日志:" -ForegroundColor White
    Write-Host "   `$env:GIT_SSH_COMMAND = 'ssh -vvv'" -ForegroundColor Gray
    Write-Host "   git push origin master" -ForegroundColor Gray
    
    exit 1
}

Write-Host "" -ForegroundColor Cyan
Write-Host "✅ 所有操作完成！" -ForegroundColor Green
