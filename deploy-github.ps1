# GitHub CLI 自动化部署脚本
# 使用方法: .\deploy-github.ps1 "your_github_token_here"

param(
    [Parameter(Mandatory=$true)]
    [string]$GithubToken
)

# 添加GitHub CLI到PATH
$env:PATH += ";C:\Program Files\GitHub CLI"

Write-Host "🚀 开始GitHub自动化部署..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 设置GitHub Token
Write-Host "🔑 配置GitHub CLI认证..." -ForegroundColor Yellow
$env:GH_TOKEN = $GithubToken

# 验证认证
Write-Host "✅ 验证认证状态..." -ForegroundColor Yellow
try {
    gh auth status
    Write-Host "✅ GitHub CLI 认证成功!" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI 认证失败!" -ForegroundColor Red
    Write-Host "请检查Token是否正确，或访问: https://github.com/settings/tokens/new" -ForegroundColor Yellow
    exit 1
}

# 创建GitHub仓库
Write-Host "📦 创建GitHub仓库..." -ForegroundColor Yellow
try {
    $repoResult = gh repo create dns-manager --public --description "Dynamic DNS IP Manager with .NET 8.0 and Docker support" 2>&1
    Write-Host "✅ GitHub仓库创建成功!" -ForegroundColor Green
    Write-Host $repoResult -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ 仓库可能已存在或创建失败" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# 设置远程仓库
Write-Host "🔗 配置远程仓库..." -ForegroundColor Yellow
try {
    git remote remove origin 2>$null
    git remote add origin git@github.com:qsswgl/dns-manager.git
    Write-Host "✅ 远程仓库配置成功!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 远程仓库配置失败" -ForegroundColor Yellow
}

# 推送代码
Write-Host "🚀 推送代码到GitHub..." -ForegroundColor Yellow
try {
    git push -u origin master
    Write-Host "✅ 代码推送成功!" -ForegroundColor Green
} catch {
    Write-Host "❌ 代码推送失败!" -ForegroundColor Red
    Write-Host "请检查SSH配置或网络连接" -ForegroundColor Yellow
    exit 1
}

# 显示结果
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🎉 GitHub部署完成!" -ForegroundColor Green
Write-Host "📍 仓库地址: https://github.com/qsswgl/dns-manager" -ForegroundColor Cyan
Write-Host "🔗 克隆地址: git@github.com:qsswgl/dns-manager.git" -ForegroundColor Cyan
Write-Host "📚 在线查看: https://github.com/qsswgl/dns-manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan