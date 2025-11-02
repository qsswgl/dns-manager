# DNS API 增强版证书申请接口文档

## 📋 概述

新版证书申请 API (`/api/v2/request-cert`) 支持选择证书类型和导出格式，提供更灵活的证书管理功能。

---

## 🚀 API 端点

### POST /api/v2/request-cert

申请 SSL 证书（增强版）

**URL**: `https://tx.qsgl.net:5075/api/v2/request-cert`

---

## 📤 请求参数

### 请求头
```
Content-Type: application/json
```

### 请求体 (JSON)

```json
{
  "domain": "example.com",
  "provider": "DNSPOD",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "your-secure-password",
  "apiKeyId": "your-api-key-id",
  "apiKeySecret": "your-api-key-secret",
  "isWildcard": null
}
```

### 参数说明

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `domain` | string | ✅ | 域名 (如: example.com) |
| `provider` | string | ❌ | DNS服务商，默认 DNSPOD |
| `certType` | string | ❌ | 证书类型，默认 RSA2048 |
| `exportFormat` | string | ❌ | 导出格式，默认 PEM |
| `pfxPassword` | string | ⚠️ | PFX密码 (exportFormat为PFX或BOTH时必填) |
| `apiKeyId` | string | ⚠️ | API Key ID (某些服务商需要) |
| `apiKeySecret` | string | ⚠️ | API Key Secret |
| `cfAccountId` | string | ❌ | Cloudflare Account ID (仅CF需要) |
| `isWildcard` | boolean | ❌ | 是否申请泛域名 (自动检测) |

---

## 🔑 证书类型 (certType)

### RSA2048 (默认)
- **密钥长度**: 2048位
- **算法**: RSA
- **兼容性**: ✅ 最佳 (所有浏览器和服务器)
- **性能**: ⚠️ 较慢
- **安全性**: ✅ 高
- **推荐场景**: 需要最大兼容性的场景

**示例**:
```json
{
  "domain": "example.com",
  "certType": "RSA2048"
}
```

### ECDSA256
- **密钥长度**: 256位
- **算法**: ECDSA (Elliptic Curve)
- **兼容性**: ✅ 现代浏览器 (IE不支持)
- **性能**: ✅ 更快 (握手速度快30-40%)
- **安全性**: ✅ 更高 (相当于RSA 3072位)
- **证书大小**: ✅ 更小 (约为RSA的1/3)
- **推荐场景**: 现代应用，移动端，高性能需求

**示例**:
```json
{
  "domain": "example.com",
  "certType": "ECDSA256"
}
```

### 对比表格

| 特性 | RSA2048 | ECDSA256 |
|------|---------|----------|
| 密钥大小 | 2048 bit | 256 bit |
| 证书大小 | ~1.2 KB | ~0.4 KB |
| 握手性能 | 基准 | +30-40% |
| CPU 消耗 | 基准 | -50% |
| 兼容性 | 所有设备 | 现代设备 |
| 安全等级 | 112 bit | 128 bit |
| 推荐使用 | 传统系统 | 现代系统 |

---

## 📦 导出格式 (exportFormat)

### PEM (默认)
导出 `.crt` 和 `.key` 文件

**返回文件**:
- `domain.crt` - 证书文件
- `domain.key` - 私钥文件
- `domain.chain.crt` - 证书链 (可选)

**返回数据**:
```json
{
  "pemCert": "Base64编码的证书内容",
  "pemKey": "Base64编码的私钥内容",
  "pemChain": "Base64编码的证书链",
  "filePaths": {
    "pemCert": "/app/certificates/example.com/example.com.crt",
    "pemKey": "/app/certificates/example.com/example.com.key",
    "pemChain": "/app/certificates/example.com/example.com.chain.crt"
  }
}
```

**适用场景**:
- Nginx
- Apache
- Linux 服务器
- Docker 容器

**示例**:
```json
{
  "domain": "example.com",
  "exportFormat": "PEM"
}
```

### PFX
导出 `.pfx` 文件（包含证书和私钥）

**返回文件**:
- `domain.pfx` - PFX 证书文件

**返回数据**:
```json
{
  "pfxData": "Base64编码的PFX内容",
  "filePaths": {
    "pfx": "/app/certificates/example.com/example.com.pfx"
  }
}
```

**适用场景**:
- Windows IIS
- Windows 服务器
- .NET 应用
- Azure

**⚠️ 注意**: 使用此格式必须提供 `pfxPassword`

**示例**:
```json
{
  "domain": "example.com",
  "exportFormat": "PFX",
  "pfxPassword": "MySecurePassword123"
}
```

### BOTH
同时导出 PEM 和 PFX 格式

**返回文件**:
- `domain.crt`
- `domain.key`
- `domain.chain.crt`
- `domain.pfx`

**返回数据**:
```json
{
  "pemCert": "...",
  "pemKey": "...",
  "pemChain": "...",
  "pfxData": "...",
  "filePaths": {
    "pemCert": "/app/certificates/example.com/example.com.crt",
    "pemKey": "/app/certificates/example.com/example.com.key",
    "pemChain": "/app/certificates/example.com/example.com.chain.crt",
    "pfx": "/app/certificates/example.com/example.com.pfx"
  }
}
```

**适用场景**:
- 需要多平台部署
- 备份完整证书
- 灵活部署选择

**⚠️ 注意**: 使用此格式必须提供 `pfxPassword`

**示例**:
```json
{
  "domain": "example.com",
  "exportFormat": "BOTH",
  "pfxPassword": "MySecurePassword123"
}
```

---

## 🌐 DNS 服务商 (provider)

### DNSPod (默认)
```json
{
  "provider": "DNSPOD",
  "apiKeyId": "123456",
  "apiKeySecret": "your-token"
}
```

### Cloudflare
```json
{
  "provider": "CLOUDFLARE",
  "apiKeySecret": "your-api-token",
  "cfAccountId": "your-account-id"
}
```

### 阿里云
```json
{
  "provider": "ALIYUN",
  "apiKeyId": "your-access-key-id",
  "apiKeySecret": "your-access-key-secret"
}
```

---

## 📥 响应格式

### 成功响应 (200 OK)

```json
{
  "success": true,
  "message": "✅ 证书申请成功！ (RSA2048 / BOTH)",
  "domain": "example.com",
  "subject": "example.com",
  "certType": "RSA2048",
  "isWildcard": false,
  "exportFormat": "BOTH",
  "pemCert": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...",
  "pemKey": "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...",
  "pemChain": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...",
  "pfxData": "MIIJmQIBAzCCCVUGCSqGSIb3DQEHA...",
  "filePaths": {
    "pemCert": "/app/certificates/example.com/example.com.crt",
    "pemKey": "/app/certificates/example.com/example.com.key",
    "pemChain": "/app/certificates/example.com/example.com.chain.crt",
    "pfx": "/app/certificates/example.com/example.com.pfx"
  },
  "expiryDate": "2025-01-22T10:30:00Z",
  "timestamp": "2025-10-24T10:30:00Z"
}
```

### 失败响应 (400 Bad Request)

```json
{
  "success": false,
  "message": "域名不能为空",
  "domain": "",
  "subject": "",
  "certType": "",
  "isWildcard": false,
  "exportFormat": "",
  "timestamp": "2025-10-24T10:30:00Z"
}
```

---

## 📝 使用示例

### 示例 1: 申请 RSA 证书，导出 PEM 格式

```bash
curl -X POST https://tx.qsgl.net:5075/api/v2/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "example.com",
    "certType": "RSA2048",
    "exportFormat": "PEM",
    "provider": "DNSPOD"
  }'
```

### 示例 2: 申请 ECDSA 证书，导出 PFX 格式

```bash
curl -X POST https://tx.qsgl.net:5075/api/v2/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "api.example.com",
    "certType": "ECDSA256",
    "exportFormat": "PFX",
    "pfxPassword": "MySecurePassword123",
    "provider": "DNSPOD"
  }'
```

### 示例 3: 泛域名证书，导出双格式

```bash
curl -X POST https://tx.qsgl.net:5075/api/v2/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "example.com",
    "isWildcard": true,
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "MySecurePassword123",
    "provider": "DNSPOD",
    "apiKeyId": "123456",
    "apiKeySecret": "your-dnspod-token"
  }'
```

### 示例 4: PowerShell 调用

```powershell
$body = @{
    domain = "example.com"
    certType = "ECDSA256"
    exportFormat = "BOTH"
    pfxPassword = "MySecurePassword123"
    provider = "DNSPOD"
} | ConvertTo-Json

Invoke-RestMethod -Method Post `
    -Uri "https://tx.qsgl.net:5075/api/v2/request-cert" `
    -Body $body `
    -ContentType "application/json"
```

### 示例 5: JavaScript/Fetch

```javascript
const response = await fetch('https://tx.qsgl.net:5075/api/v2/request-cert', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    domain: 'example.com',
    certType: 'ECDSA256',
    exportFormat: 'PEM',
    provider: 'DNSPOD'
  })
});

const result = await response.json();
console.log(result);
```

---

## 🔍 常见问题

### Q1: RSA2048 和 ECDSA256 应该选择哪个？

**推荐**:
- **现代应用/移动应用**: ECDSA256（性能更好）
- **需要兼容IE的老系统**: RSA2048

### Q2: PEM 和 PFX 有什么区别？

- **PEM**: 文本格式，分离的证书和私钥文件，适合 Linux/Nginx
- **PFX**: 二进制格式，证书和私钥合并在一个文件中，适合 Windows/IIS

### Q3: 如何使用返回的 Base64 证书数据？

```bash
# 解码 PEM 证书
echo "LS0tLS1CRUdJTi..." | base64 -d > example.com.crt

# 解码 PFX 证书
echo "MIIJmQIBAzCC..." | base64 -d > example.com.pfx
```

### Q4: PFX 密码有什么要求？

建议:
- 长度 >= 8 位
- 包含大小写字母、数字和特殊字符
- 避免使用常见密码

### Q5: 泛域名证书如何申请？

系统会自动检测一级域名并申请泛域名证书:
```json
{
  "domain": "example.com"  // 自动申请 *.example.com
}
```

或手动指定:
```json
{
  "domain": "example.com",
  "isWildcard": true
}
```

---

## ⚠️ 注意事项

1. **PFX 密码**: 导出 PFX 格式时必须提供密码
2. **API 密钥**: 确保 DNS 服务商的 API 密钥有效
3. **域名验证**: 域名必须已经添加到 DNS 服务商
4. **证书文件**: 证书保存在 `/app/certificates/域名/` 目录
5. **过期时间**: Let's Encrypt 证书有效期 90 天

---

## 🔗 相关 API

- `GET /api/cert-manager/list` - 查看所有托管证书
- `POST /api/cert-manager/renew` - 续签证书
- `POST /api/cert-manager/deploy` - 部署证书
- `GET /api/cert-manager/status` - 证书状态汇总

---

**API 版本**: v2  
**最后更新**: 2025-10-24  
**维护者**: DNS 运维团队
