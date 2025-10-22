# PowerShell 5.1 兼容的 8443 端口测试脚本
# 适用于 Windows PowerShell 5.1（不支持 -SkipCertificateCheck）

Write-Host "=== 阿里云 Envoy 8443 端口测试（PowerShell 5.1 兼容版）===" -ForegroundColor Cyan
Write-Host ""

# 临时禁用 SSL 证书验证（仅用于测试自签名证书）
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$testUrl = "https://www.qsgl.cn:8443/"
$testHost = "www.qsgl.net"

Write-Host "测试 URL: $testUrl" -ForegroundColor Yellow
Write-Host "Host 头: $testHost" -ForegroundColor Yellow
Write-Host ""

# 测试 1: 不带 Host 头（预期 404）
Write-Host "[测试 1] 不带 Host 头的请求..." -ForegroundColor Magenta
try {
    $response1 = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -ErrorAction Stop
    Write-Host "  状态码: $($response1.StatusCode)" -ForegroundColor Green
    Write-Host "  响应头:" -ForegroundColor Gray
    $response1.Headers.GetEnumerator() | ForEach-Object { 
        Write-Host "    $($_.Key): $($_.Value)" -ForegroundColor Gray 
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  状态码: $statusCode" -ForegroundColor Yellow
    if ($statusCode -eq 404) {
        Write-Host "  ✓ 符合预期（未匹配虚拟主机）" -ForegroundColor Green
    }
}
Write-Host ""

# 测试 2: 带正确 Host 头（预期 200）
Write-Host "[测试 2] 带 Host: $testHost 的请求..." -ForegroundColor Magenta
try {
    $headers = @{
        'Host' = $testHost
    }
    $response2 = Invoke-WebRequest -Uri $testUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "  ✓ 状态码: $($response2.StatusCode)" -ForegroundColor Green
    Write-Host "  ✓ 内容长度: $($response2.Content.Length) 字节" -ForegroundColor Green
    Write-Host "  响应头:" -ForegroundColor Gray
    $response2.Headers.GetEnumerator() | ForEach-Object { 
        if ($_.Key -match 'server|x-powered-by|x-envoy') {
            Write-Host "    $($_.Key): $($_.Value)" -ForegroundColor Cyan
        }
    }
    
    # 检查是否包含后端内容
    if ($response2.Content -match 'ASP.NET|qsgl') {
        Write-Host "  ✓ 后端代理成功（检测到 ASP.NET 内容）" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=== 测试通过！8443 端口代理正常工作 ===" -ForegroundColor Green
    
} catch {
    Write-Host "  ✗ 请求失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "=== 测试失败 ===" -ForegroundColor Red
    Write-Host "可能原因：" -ForegroundColor Yellow
    Write-Host "  1. 阿里云安全组未开放 8443 端口" -ForegroundColor Yellow
    Write-Host "  2. 本地网络/防火墙限制" -ForegroundColor Yellow
    Write-Host "  3. DNS 解析问题" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
