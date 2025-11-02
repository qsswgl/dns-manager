# 证书 API V2 快速参考

## 🚀 API 端点
```
POST https://tx.qsgl.net:5075/api/v2/request-cert
```

## 📋 证书类型选择

### RSA2048 (传统，兼容性最好)
```json
{
  "domain": "example.com",
  "certType": "RSA2048"
}
```
✅ 所有浏览器支持  
⚠️ 性能较慢

### ECDSA256 (现代，性能更好)
```json
{
  "domain": "example.com",
  "certType": "ECDSA256"
}
```
✅ 握手速度快 30-40%  
✅ CPU 消耗减少 50%  
✅ 证书大小 1/3  
⚠️ IE 不支持

## 📦 导出格式选择

### PEM (Linux/Nginx)
```json
{
  "domain": "example.com",
  "exportFormat": "PEM"
}
```
导出: `.crt` + `.key` + `.chain.crt`

### PFX (Windows/IIS)
```json
{
  "domain": "example.com",
  "exportFormat": "PFX",
  "pfxPassword": "YourPassword"
}
```
导出: `.pfx` (含私钥)

### BOTH (双格式)
```json
{
  "domain": "example.com",
  "exportFormat": "BOTH",
  "pfxPassword": "YourPassword"
}
```
导出: PEM + PFX 全部文件

## 🌐 DNS 服务商

### DNSPod
```json
{
  "provider": "DNSPOD",
  "apiKeyId": "123456",
  "apiKeySecret": "token"
}
```

### Cloudflare
```json
{
  "provider": "CLOUDFLARE",
  "apiKeySecret": "api-token",
  "cfAccountId": "account-id"
}
```

### 阿里云
```json
{
  "provider": "ALIYUN",
  "apiKeyId": "key-id",
  "apiKeySecret": "key-secret"
}
```

## 📝 完整示例

### 最常用配置
```json
{
  "domain": "example.com",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "MyPassword123",
  "provider": "DNSPOD"
}
```

### 高性能配置
```json
{
  "domain": "api.example.com",
  "certType": "ECDSA256",
  "exportFormat": "PEM",
  "provider": "DNSPOD"
}
```

### 泛域名证书
```json
{
  "domain": "example.com",
  "isWildcard": true,
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "MyPassword123",
  "provider": "DNSPOD"
}
```

## 🧪 测试命令

### curl
```bash
curl -X POST https://tx.qsgl.net:5075/api/v2/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.com",
    "certType": "RSA2048",
    "exportFormat": "PEM"
  }'
```

### PowerShell
```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://tx.qsgl.net:5075/api/v2/request-cert" `
  -Body (@{
    domain = "test.com"
    certType = "RSA2048"
    exportFormat = "PEM"
  } | ConvertTo-Json) `
  -ContentType "application/json"
```

## 📂 文件路径

证书保存在:
```
/app/certificates/{domain}/
  ├── {domain}.crt      (PEM证书)
  ├── {domain}.key      (PEM私钥)
  ├── {domain}.chain.crt (证书链)
  └── {domain}.pfx      (PFX证书)
```

## 📚 文档

- 详细文档: `K:\DNS\DNSApi\CERT-API-V2-GUIDE.md`
- 测试脚本: `K:\DNS\DNSApi\test-cert-api-v2.ps1`
- Swagger UI: `https://tx.qsgl.net:5075/swagger`
