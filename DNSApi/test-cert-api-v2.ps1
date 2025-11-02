# DNS API V2 证书申请测试脚本

Write-Host "========== DNS API V2 证书申请测试 ==========" -ForegroundColor Cyan
Write-Host ""

$ApiUrl = "https://tx.qsgl.net:5075/api/v2/request-cert"

# 测试场景
$testCases = @(
    @{
        Name = "测试 1: RSA2048 + PEM 格式"
        Body = @{
            domain = "test.qsgl.net"
            certType = "RSA2048"
            exportFormat = "PEM"
            provider = "DNSPOD"
        }
    },
    @{
        Name = "测试 2: ECDSA256 + PFX 格式"
        Body = @{
            domain = "api.qsgl.net"
            certType = "ECDSA256"
            exportFormat = "PFX"
            pfxPassword = "Test@123456"
            provider = "DNSPOD"
        }
    },
    @{
        Name = "测试 3: RSA2048 + 双格式导出"
        Body = @{
            domain = "qsgl.net"
            certType = "RSA2048"
            exportFormat = "BOTH"
            pfxPassword = "Test@123456"
            provider = "DNSPOD"
            isWildcard = $true
        }
    },
    @{
        Name = "测试 4: ECDSA256 + 双格式导出"
        Body = @{
            domain = "qsgl.net"
            certType = "ECDSA256"
            exportFormat = "BOTH"
            pfxPassword = "Test@123456"
            provider = "DNSPOD"
        }
    }
)

foreach ($test in $testCases) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host $test.Name -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "请求参数:" -ForegroundColor Cyan
    Write-Host ($test.Body | ConvertTo-Json -Depth 3) -ForegroundColor White
    Write-Host ""
    
    try {
        $jsonBody = $test.Body | ConvertTo-Json -Depth 3
        
        Write-Host "发送请求..." -ForegroundColor White
        $response = Invoke-RestMethod -Method Post `
            -Uri $ApiUrl `
            -Body $jsonBody `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-Host "✓ 请求成功" -ForegroundColor Green
        Write-Host ""
        Write-Host "响应结果:" -ForegroundColor Cyan
        Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor White
        Write-Host ""
        
        if ($response.success) {
            Write-Host "✓ 证书申请成功" -ForegroundColor Green
            Write-Host "  域名: $($response.domain)" -ForegroundColor White
            Write-Host "  主题: $($response.subject)" -ForegroundColor White
            Write-Host "  类型: $($response.certType)" -ForegroundColor White
            Write-Host "  格式: $($response.exportFormat)" -ForegroundColor White
            
            if ($response.filePaths) {
                Write-Host "  文件路径:" -ForegroundColor White
                if ($response.filePaths.pemCert) {
                    Write-Host "    PEM证书: $($response.filePaths.pemCert)" -ForegroundColor Gray
                }
                if ($response.filePaths.pemKey) {
                    Write-Host "    PEM私钥: $($response.filePaths.pemKey)" -ForegroundColor Gray
                }
                if ($response.filePaths.pfx) {
                    Write-Host "    PFX文件: $($response.filePaths.pfx)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "✗ 证书申请失败" -ForegroundColor Red
            Write-Host "  错误: $($response.message)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "✗ 请求失败" -ForegroundColor Red
        Write-Host "  错误: $_" -ForegroundColor Red
        Write-Host "  详情: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "按任意键继续下一个测试..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

Write-Host "========== 测试完成 ==========" -ForegroundColor Cyan
Write-Host ""

# 显示 API 文档链接
Write-Host "📚 详细文档:" -ForegroundColor Cyan
Write-Host "  K:\DNS\DNSApi\CERT-API-V2-GUIDE.md" -ForegroundColor White
Write-Host ""

# 显示 Swagger UI 链接
Write-Host "🔗 在线 API 文档:" -ForegroundColor Cyan
Write-Host "  http://tx.qsgl.net:5074/swagger" -ForegroundColor White
Write-Host "  https://tx.qsgl.net:5075/swagger" -ForegroundColor White
Write-Host ""
