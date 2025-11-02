# ================================================================
# 快速导入 qsgl.net 证书到 Windows 受信任根证书库
# ================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   🔐 导入 qsgl.net 证书到系统受信任根证书" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ 此脚本需要管理员权限运行！" -ForegroundColor Red
    Write-Host ""
    Write-Host "请右键点击此脚本，选择 '以管理员身份运行'" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "按回车键退出"
    exit 1
}

# 定义路径
$certFile = "qsgl.net.fullchain.crt"
$server = "tx.qsgl.net"
$remotePath = "/opt/dnsapi-app/certificates/qsgl.net.fullchain.crt"

Write-Host "📋 操作步骤：" -ForegroundColor Yellow
Write-Host "  1. 从服务器下载证书文件" -ForegroundColor White
Write-Host "  2. 导入到系统受信任根证书库" -ForegroundColor White
Write-Host "  3. 验证证书安装" -ForegroundColor White
Write-Host ""

# 检查是否已有证书文件
if (Test-Path $certFile) {
    Write-Host "✅ 找到本地证书文件: $certFile" -ForegroundColor Green
    $downloadNew = Read-Host "是否重新下载最新证书？(y/N)"
    if ($downloadNew -ne "y" -and $downloadNew -ne "Y") {
        Write-Host "使用现有证书文件" -ForegroundColor Gray
        $skipDownload = $true
    }
}

# 下载证书
if (-not $skipDownload) {
    Write-Host ""
    Write-Host "📥 步骤 1: 从服务器下载证书..." -ForegroundColor Cyan
    Write-Host "  服务器: $server" -ForegroundColor Gray
    Write-Host "  路径: $remotePath" -ForegroundColor Gray
    Write-Host ""
    
    try {
        # 使用 scp 下载证书
        $scpCommand = "scp root@${server}:${remotePath} $certFile"
        Write-Host "  执行: $scpCommand" -ForegroundColor Gray
        & scp "root@${server}:${remotePath}" $certFile
        
        if ($LASTEXITCODE -ne 0) {
            throw "SCP 命令失败"
        }
        
        Write-Host "  ✅ 证书下载成功" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ 下载失败: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "请确保：" -ForegroundColor Yellow
        Write-Host "  1. 已安装 OpenSSH 客户端或 Git Bash" -ForegroundColor Gray
        Write-Host "  2. 可以通过 SSH 访问服务器" -ForegroundColor Gray
        Write-Host "  3. 证书文件存在于服务器上" -ForegroundColor Gray
        Write-Host ""
        
        # 提供手动下载指引
        Write-Host "或者手动下载证书：" -ForegroundColor Yellow
        Write-Host "  1. SSH 登录服务器: ssh root@$server" -ForegroundColor White
        Write-Host "  2. 查看证书: cat $remotePath" -ForegroundColor White
        Write-Host "  3. 复制内容到本地文件: $certFile" -ForegroundColor White
        Write-Host "  4. 重新运行此脚本" -ForegroundColor White
        Write-Host ""
        Read-Host "按回车键退出"
        exit 1
    }
}

Write-Host ""

# 验证证书文件
if (-not (Test-Path $certFile)) {
    Write-Host "❌ 证书文件不存在: $certFile" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

Write-Host "📄 证书文件信息：" -ForegroundColor Cyan
$fileInfo = Get-Item $certFile
Write-Host "  路径: $($fileInfo.FullName)" -ForegroundColor Gray
Write-Host "  大小: $($fileInfo.Length) 字节" -ForegroundColor Gray
Write-Host "  修改时间: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
Write-Host ""

# 导入证书
Write-Host "🔧 步骤 2: 导入证书到系统..." -ForegroundColor Cyan

try {
    # 先检查是否已存在
    $existingCert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*qsgl.net*"}
    
    if ($existingCert) {
        Write-Host "  ⚠️  发现已存在的 qsgl.net 证书：" -ForegroundColor Yellow
        foreach ($cert in $existingCert) {
            Write-Host "    主题: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "    指纹: $($cert.Thumbprint)" -ForegroundColor Gray
            Write-Host "    有效期: $($cert.NotBefore) - $($cert.NotAfter)" -ForegroundColor Gray
        }
        Write-Host ""
        
        $replace = Read-Host "是否删除旧证书并导入新证书？(y/N)"
        if ($replace -eq "y" -or $replace -eq "Y") {
            foreach ($cert in $existingCert) {
                Remove-Item -Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
                Write-Host "  🗑️  已删除旧证书: $($cert.Thumbprint)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  取消操作" -ForegroundColor Yellow
            Read-Host "按回车键退出"
            exit 0
        }
    }
    
    # 导入新证书
    Write-Host "  正在导入证书..." -ForegroundColor Gray
    $newCert = Import-Certificate -FilePath $certFile -CertStoreLocation Cert:\LocalMachine\Root
    Write-Host "  ✅ 证书导入成功！" -ForegroundColor Green
    Write-Host ""
    
    # 显示证书详情
    Write-Host "📋 已安装证书详情：" -ForegroundColor Cyan
    Write-Host "  主题: $($newCert.Subject)" -ForegroundColor Gray
    Write-Host "  颁发者: $($newCert.Issuer)" -ForegroundColor Gray
    Write-Host "  指纹: $($newCert.Thumbprint)" -ForegroundColor Gray
    Write-Host "  有效期开始: $($newCert.NotBefore)" -ForegroundColor Gray
    Write-Host "  有效期结束: $($newCert.NotAfter)" -ForegroundColor Gray
    Write-Host "  序列号: $($newCert.SerialNumber)" -ForegroundColor Gray
    
    # 显示 SAN
    $san = $newCert.Extensions | Where-Object {$_.Oid.FriendlyName -eq "Subject Alternative Name"}
    if ($san) {
        Write-Host "  DNS 名称: $($san.Format($false))" -ForegroundColor Gray
    }
    Write-Host ""
}
catch {
    Write-Host "  ❌ 导入失败: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "按回车键退出"
    exit 1
}

# 验证安装
Write-Host "✅ 步骤 3: 验证证书安装..." -ForegroundColor Cyan

$installedCert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Thumbprint -eq $newCert.Thumbprint}
if ($installedCert) {
    Write-Host "  ✅ 证书已成功安装到受信任根证书库" -ForegroundColor Green
    Write-Host "  存储位置: Cert:\LocalMachine\Root\$($installedCert.Thumbprint)" -ForegroundColor Gray
}
else {
    Write-Host "  ❌ 证书验证失败" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   ✅ 证书导入完成！" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📝 后续操作：" -ForegroundColor Yellow
Write-Host "  1. 完全关闭所有浏览器（Chrome、Edge 等）" -ForegroundColor White
Write-Host "  2. 重新打开浏览器" -ForegroundColor White
Write-Host "  3. 访问: https://tx.qsgl.net:5075/swagger" -ForegroundColor Cyan
Write-Host "  4. 现在应该不再显示证书警告" -ForegroundColor White
Write-Host ""

Write-Host "💡 提示：" -ForegroundColor Yellow
Write-Host "  - 如果仍有警告，清除浏览器缓存/Cookie" -ForegroundColor Gray
Write-Host "  - 检查日期时间是否正确" -ForegroundColor Gray
Write-Host "  - 证书有效期: $($newCert.NotBefore.ToString('yyyy-MM-dd')) 至 $($newCert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
Write-Host ""

# 询问是否打开浏览器测试
$openBrowser = Read-Host "是否在 Chrome 中打开 Swagger 测试？(y/N)"
if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Start-Process "chrome.exe" "https://tx.qsgl.net:5075/swagger"
    Write-Host "已打开 Chrome 浏览器" -ForegroundColor Green
}

Write-Host ""
Write-Host "脚本执行完成！" -ForegroundColor Green
Read-Host "按回车键退出"
