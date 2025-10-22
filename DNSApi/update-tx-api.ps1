# Auto-update tx.qsgl.net API Server with P-256 ECDSA fix
# Using Tencent Cloud SSH key

param(
    [string]$SSHKey = "C:\Key\tx.qsgl.net_id_ed25519",
    [string]$Server = "43.138.35.183",
    [string]$Registry = "43.138.35.183:5000"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "  tx.qsgl.net API Server Update"
Write-Host "========================================"
Write-Host ""

# Step 1: Verify SSH Key
Write-Host "[1/5] Verifying SSH key..." -ForegroundColor Yellow
if (-not (Test-Path $SSHKey)) {
    Write-Host "ERROR: SSH key not found: $SSHKey" -ForegroundColor Red
    exit 1
}
Write-Host "OK: SSH key found" -ForegroundColor Green

# Step 2: Test SSH Connection
Write-Host "`n[2/5] Testing SSH connection..." -ForegroundColor Yellow
try {
    $testCmd = "echo 'SSH OK'"
    $result = ssh -i $SSHKey -o ConnectTimeout=10 root@$Server $testCmd 2>&1
    if ($LASTEXITCODE -ne 0) { throw "SSH failed" }
    Write-Host "OK: $result" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot connect to $Server" -ForegroundColor Red
    exit 1
}

# Step 3: Build Docker Image
Write-Host "`n[3/5] Building Docker image with P-256 fix..." -ForegroundColor Yellow
Push-Location K:\DNS\DNSApi

Write-Host "   Compiling project..."
dotnet publish -c Release -o publish > $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "   Building Docker image..."
docker build -t dnsapi:latest -f Dockerfile . > $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "OK: Docker image built" -ForegroundColor Green

# Step 4: Push to Private Registry
Write-Host "`n[4/5] Pushing to private registry..." -ForegroundColor Yellow
docker tag dnsapi:latest ${Registry}/dnsapi:latest
docker tag dnsapi:latest ${Registry}/dnsapi:p256

Write-Host "   Pushing latest tag..."
docker push ${Registry}/dnsapi:latest > $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Push failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "   Pushing p256 tag..."
docker push ${Registry}/dnsapi:p256 > $null
Write-Host "OK: Images pushed" -ForegroundColor Green

Pop-Location

# Step 5: Update Container on Server
Write-Host "`n[5/5] Updating container on server..." -ForegroundColor Yellow

$updateScript = @'
#!/bin/bash
set -e
echo "Pulling latest image..."
docker pull 43.138.35.183:5000/dnsapi:latest
echo "Stopping old container..."
docker stop dnsapi 2>/dev/null || true
docker rm dnsapi 2>/dev/null || true
echo "Starting new container..."
docker run -d --name dnsapi --restart unless-stopped -p 5074:5074 -p 5075:5075 -v /opt/dns-certs:/app/certificates 43.138.35.183:5000/dnsapi:latest
sleep 5
echo ""
echo "=== Container Status ==="
if docker ps | grep -q dnsapi; then
  echo "OK: DNSApi container running"
  docker logs dnsapi --tail 5
else
  echo "ERROR: Container not running"
  docker logs dnsapi --tail 20
  exit 1
fi
'@

$tempFile = New-TemporaryFile
$updateScript -replace "`r`n", "`n" | Out-File -FilePath $tempFile.FullName -Encoding ASCII -NoNewline
scp -i $SSHKey $tempFile.FullName root@${Server}:/tmp/update-dnsapi.sh
ssh -i $SSHKey root@$Server "dos2unix /tmp/update-dnsapi.sh 2>/dev/null || sed -i 's/\r$//' /tmp/update-dnsapi.sh ; bash /tmp/update-dnsapi.sh"
Remove-Item $tempFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Container update failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================"
Write-Host "  Update Complete!"
Write-Host "========================================"
Write-Host ""

# Step 6: Verify P-256 Certificate
Write-Host "Verifying P-256 certificate API..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

$verifyCmd = "curl -s -X POST 'https://tx.qsgl.net:5075/api/request-cert' -H 'Content-Type: application/x-www-form-urlencoded' -d 'domain=qsgl.cn&provider=DNSPOD' | jq -r '.key' | openssl ec -text -noout 2>&1 | grep 'Private-Key'"

$result = ssh -i $SSHKey root@$Server $verifyCmd

if ($result -match "256 bit") {
    Write-Host "SUCCESS: API now returns P-256 ECDSA certificates!" -ForegroundColor Green
    Write-Host "   $result" -ForegroundColor Gray
} else {
    Write-Host "WARNING: $result" -ForegroundColor Yellow
    Write-Host "   Container may still be starting..." -ForegroundColor Yellow
}

Write-Host "`nAll operations complete!" -ForegroundColor Green
Write-Host "   - API URL: https://tx.qsgl.net:5075" -ForegroundColor Gray
Write-Host "   - Cert API: https://tx.qsgl.net:5075/api/request-cert" -ForegroundColor Gray
