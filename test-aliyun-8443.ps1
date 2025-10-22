# Aliyun Envoy 8443 Port Test Script

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Aliyun Envoy 8443 Port Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$server = "www.qsgl.cn"
$ip = "123.57.93.200"
$port = 8443
$hostHeader = "www.qsgl.net"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Proxy: https://${server}:${port}/"
Write-Host "  Server IP: $ip"
Write-Host "  Host Header: $hostHeader"
Write-Host "  Backend: https://61.163.200.245"
Write-Host ""

# Test 1: TCP Connection
Write-Host "Test 1: TCP Port Connectivity..." -ForegroundColor Yellow
$tcpTest = Test-NetConnection -ComputerName $server -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
if ($tcpTest) {
    Write-Host "  OK - TCP port $port accessible" -ForegroundColor Green
} else {
    Write-Host "  FAIL - TCP port $port not accessible" -ForegroundColor Red
    Write-Host "     Possible cause: Firewall or network issue" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: HTTPS Access
Write-Host "Test 2: HTTPS Access..." -ForegroundColor Yellow
if ($PSVersionTable.PSVersion.Major -ge 7) {
    try {
        $response = Invoke-WebRequest -Uri "https://${server}:${port}/" `
            -Headers @{"Host"=$hostHeader} `
            -SkipCertificateCheck `
            -Method Head `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        Write-Host "  OK - HTTPS access successful" -ForegroundColor Green
        Write-Host "     Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
        Write-Host "     Server: $($response.Headers.Server)" -ForegroundColor Green
        Write-Host "     Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor Green
        Write-Host "     Content-Length: $($response.Headers.'Content-Length') bytes" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL - HTTPS access failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  SKIP - PowerShell 7+ required for HTTPS test" -ForegroundColor Yellow
    Write-Host "     Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "     Manual test command:" -ForegroundColor Yellow
    Write-Host "     curl -k https://${server}:${port}/ -H 'Host: $hostHeader'" -ForegroundColor Cyan
}
Write-Host ""

# Test 3: Remote Server Test
Write-Host "Test 3: Server-side Validation..." -ForegroundColor Yellow
$sshKey = "C:\KEY\www.qsgl.cn_id_ed25519"
if (Test-Path $sshKey) {
    try {
        $remoteTest = ssh -i $sshKey root@$server "curl -skI https://127.0.0.1:${port}/ -H 'Host: $hostHeader' 2>&1 | grep -E '(HTTP|server)' | head -n 2"
        if ($LASTEXITCODE -eq 0 -and $remoteTest) {
            Write-Host "  OK - Server-side test passed" -ForegroundColor Green
            Write-Host "     $remoteTest" -ForegroundColor Green
        } else {
            Write-Host "  WARN - Server-side test abnormal" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  WARN - Cannot connect via SSH" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARN - SSH key not found: $sshKey" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Container Status
Write-Host "Test 4: Envoy Container Status..." -ForegroundColor Yellow
if (Test-Path $sshKey) {
    try {
        $containerStatus = ssh -i $sshKey root@$server "docker ps --filter name=envoy-proxy --format '{{.Status}}' 2>&1"
        if ($LASTEXITCODE -eq 0 -and $containerStatus -like "*Up*") {
            Write-Host "  OK - Envoy container running" -ForegroundColor Green
            Write-Host "     Status: $containerStatus" -ForegroundColor Green
        } else {
            Write-Host "  FAIL - Envoy container not running or abnormal" -ForegroundColor Red
            Write-Host "     Status: $containerStatus" -ForegroundColor Red
        }
    } catch {
        Write-Host "  WARN - Cannot check container status" -ForegroundColor Yellow
    }
} else {
    Write-Host "  SKIP - SSH connection required" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If all tests passed, access via:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Browser (ignore certificate warning):" -ForegroundColor Yellow
Write-Host "   https://${server}:${port}/" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. PowerShell command:" -ForegroundColor Yellow
Write-Host "   Invoke-WebRequest -Uri 'https://${server}:${port}/' -Headers @{'Host'='$hostHeader'} -SkipCertificateCheck" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. curl command:" -ForegroundColor Yellow
Write-Host "   curl -k https://${server}:${port}/ -H 'Host: $hostHeader'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Notes:" -ForegroundColor Yellow
Write-Host "  - Self-signed certificate (browser warning is normal)" -ForegroundColor Gray
Write-Host "  - HTTPS only (HTTP not supported)" -ForegroundColor Gray
Write-Host "  - Port $port must be allowed in firewall" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentation: DNSApi\linux-deploy\ALIYUN-8443-SETUP.md" -ForegroundColor Cyan
Write-Host ""
