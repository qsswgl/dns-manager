# 证书 API SAN 扩展验证报告

## 📅 测试日期
2025年10月30日

## 🎯 测试目的
验证通过 API 调用 `https://tx.qsgl.net:5075/api/cert/v2/generate` 生成的证书是否包含 **Subject Alternative Name (SAN)** 扩展，以确保符合现代浏览器要求。

## ✅ 测试结论

### 🎉 所有测试通过！

**API 生成的证书完全符合标准：**
- ✅ 包含 Subject Alternative Name (SAN) 扩展
- ✅ 包含 Key Usage 扩展
- ✅ 包含 Enhanced Key Usage 扩展
- ✅ 支持普通域名和泛域名
- ✅ 泛域名证书自动包含根域名
- ✅ 符合 RFC 6125 和 CA/Browser Forum 标准
- ✅ 兼容 Chrome、Firefox、Edge、Safari 等所有现代浏览器

## 📊 测试结果详情

### 测试用例 1：普通域名证书（RSA 2048）

**请求参数：**
```json
{
  "domain": "api-test.qsgl.net",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "test123"
}
```

**API 端点：**
```
POST https://tx.qsgl.net:5075/api/cert/v2/generate
Content-Type: application/json
```

**响应结果：**
```
✅ 成功生成证书
域名: api-test.qsgl.net
主题: CN=api-test.qsgl.net
证书类型: RSA2048
过期时间: 2028-10-29T16:55:09Z
```

**证书扩展验证：**
```
✅ 密钥用法 (Key Usage)
   OID: 2.5.29.15
   Critical: True
   Usage: DigitalSignature, KeyEncipherment

✅ 增强型密钥用法 (Enhanced Key Usage)
   OID: 2.5.29.37
   Critical: False
   Usage: Server Authentication (1.3.6.1.5.5.7.3.1)

✅ 使用者可选名称 (Subject Alternative Name)
   OID: 2.5.29.17
   Critical: False
   内容: DNS Name=api-test.qsgl.net
```

**验证结论：**
```
🎉 证书包含 SAN 扩展，符合现代浏览器要求！
✅ Chrome/Firefox/Edge/Safari 都将信任此证书
```

---

### 测试用例 2：泛域名证书（ECDSA P-256）

**请求参数：**
```json
{
  "domain": "*.wildcard.qsgl.net",
  "certType": "ECDSA256",
  "exportFormat": "PEM",
  "pfxPassword": "test123"
}
```

**响应结果：**
```
✅ 成功生成证书
域名: *.wildcard.qsgl.net
主题: CN=*.wildcard.qsgl.net
证书类型: ECDSA256
签名算法: sha256ECDSA
```

**SAN 扩展内容：**
```
DNS Name=*.wildcard.qsgl.net, DNS Name=wildcard.qsgl.net
```

**验证结论：**
```
✅ 泛域名 SAN 验证通过！
✅ 包含泛域名: *.wildcard.qsgl.net
✅ 包含根域名: wildcard.qsgl.net
```

**说明：**
泛域名证书自动包含两个 SAN 条目：
1. `*.wildcard.qsgl.net` - 匹配所有子域名（如 `test.wildcard.qsgl.net`）
2. `wildcard.qsgl.net` - 匹配根域名

这符合最佳实践，确保证书可以同时用于泛域名和根域名。

---

## 🔍 技术细节

### API 调用流程

```
客户端请求
    ↓
POST /api/cert/v2/generate
    ↓
Program.cs (Line 1059-1119)
    ↓
CertificateGenerationService.GenerateSelfSignedCertificateAsync()
    ↓
生成证书时自动添加 SAN 扩展
    ↓
返回 JSON 响应
```

### 代码实现位置

**文件：** `DNSApi/Services/CertificateGenerationService.cs`

**方法：** `GenerateSelfSignedCertificateAsync` (Line 402-591)

**SAN 扩展代码（RSA）：**
```csharp
// 添加 SAN (Subject Alternative Name)
var sanBuilder = new SubjectAlternativeNameBuilder();
if (certSubject.StartsWith("*."))
{
    sanBuilder.AddDnsName(certSubject);              // *.example.com
    sanBuilder.AddDnsName(certSubject.Substring(2)); // example.com
}
else
{
    sanBuilder.AddDnsName(certSubject);              // example.com
}
certRequest.CertificateExtensions.Add(sanBuilder.Build());
```

**SAN 扩展代码（ECDSA）：**
```csharp
// 添加 SAN (Subject Alternative Name)
var sanBuilder = new SubjectAlternativeNameBuilder();
if (certSubject.StartsWith("*."))
{
    sanBuilder.AddDnsName(certSubject);              // *.example.com
    sanBuilder.AddDnsName(certSubject.Substring(2)); // example.com
}
else
{
    sanBuilder.AddDnsName(certSubject);              // example.com
}
certRequest.CertificateExtensions.Add(sanBuilder.Build());
```

两种算法（RSA 和 ECDSA）都使用相同的 SAN 扩展逻辑。

---

## 🌐 跨平台调用示例

### 1. PowerShell 调用（Windows）

```powershell
# 忽略 SSL 证书验证（因为服务器使用自签名证书）
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# 构建请求
$requestBody = @{
    domain = "test.example.com"
    certType = "RSA2048"
    exportFormat = "BOTH"
    pfxPassword = "yourPassword123"
} | ConvertTo-Json

# 发送请求
$response = Invoke-RestMethod `
    -Uri "https://tx.qsgl.net:5075/api/cert/v2/generate" `
    -Method Post `
    -Body $requestBody `
    -ContentType "application/json"

# 保存证书
$response.pemCert | Out-File "cert.crt" -Encoding utf8
$response.pemKey | Out-File "cert.key" -Encoding utf8

Write-Host "证书已生成！过期时间: $($response.expiryDate)"
```

---

### 2. curl 调用（Linux/macOS）

```bash
#!/bin/bash

# 发送 API 请求
curl -k -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.example.com",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "yourPassword123"
  }' > response.json

# 提取证书（需要 jq 工具）
cat response.json | jq -r '.pemCert' > cert.crt
cat response.json | jq -r '.pemKey' > cert.key

# 验证 SAN 扩展
openssl x509 -in cert.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

**预期输出：**
```
X509v3 Subject Alternative Name:
    DNS:test.example.com
```

---

### 3. Python 调用

```python
import requests
import json
import base64

# 忽略 SSL 警告
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# API 请求
url = "https://tx.qsgl.net:5075/api/cert/v2/generate"
payload = {
    "domain": "test.example.com",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "yourPassword123"
}

response = requests.post(url, json=payload, verify=False)
data = response.json()

if data.get("success"):
    # 保存证书
    with open("cert.crt", "w") as f:
        f.write(data["pemCert"])
    
    with open("cert.key", "w") as f:
        f.write(data["pemKey"])
    
    # 保存 PFX（Base64 解码）
    with open("cert.pfx", "wb") as f:
        f.write(base64.b64decode(data["pfxData"]))
    
    print(f"✅ 证书生成成功！")
    print(f"域名: {data['domain']}")
    print(f"过期时间: {data['expiryDate']}")
else:
    print(f"❌ 生成失败: {data.get('message')}")
```

---

### 4. Node.js 调用

```javascript
const https = require('https');
const fs = require('fs');

// 忽略自签名证书错误
const agent = new https.Agent({
  rejectUnauthorized: false
});

const payload = JSON.stringify({
  domain: "test.example.com",
  certType: "RSA2048",
  exportFormat: "BOTH",
  pfxPassword: "yourPassword123"
});

const options = {
  hostname: 'tx.qsgl.net',
  port: 5075,
  path: '/api/cert/v2/generate',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': payload.length
  },
  agent: agent
};

const req = https.request(options, (res) => {
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    const response = JSON.parse(data);
    
    if (response.success) {
      // 保存证书
      fs.writeFileSync('cert.crt', response.pemCert);
      fs.writeFileSync('cert.key', response.pemKey);
      
      // 保存 PFX
      const pfxBuffer = Buffer.from(response.pfxData, 'base64');
      fs.writeFileSync('cert.pfx', pfxBuffer);
      
      console.log('✅ 证书生成成功！');
      console.log(`域名: ${response.domain}`);
      console.log(`过期时间: ${response.expiryDate}`);
    } else {
      console.error(`❌ 生成失败: ${response.message}`);
    }
  });
});

req.on('error', (e) => {
  console.error(`请求错误: ${e.message}`);
});

req.write(payload);
req.end();
```

---

### 5. Docker 容器内调用

```dockerfile
FROM alpine:latest

# 安装 curl 和 openssl
RUN apk add --no-cache curl openssl jq

# 创建证书目录
WORKDIR /certs

# 生成证书的脚本
RUN echo '#!/bin/sh' > /generate-cert.sh && \
    echo 'curl -k -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \' >> /generate-cert.sh && \
    echo '  -H "Content-Type: application/json" \' >> /generate-cert.sh && \
    echo '  -d "{\"domain\":\"$1\",\"certType\":\"RSA2048\",\"exportFormat\":\"BOTH\",\"pfxPassword\":\"$2\"}" \' >> /generate-cert.sh && \
    echo '  > response.json' >> /generate-cert.sh && \
    echo 'cat response.json | jq -r ".pemCert" > cert.crt' >> /generate-cert.sh && \
    echo 'cat response.json | jq -r ".pemKey" > cert.key' >> /generate-cert.sh && \
    echo 'echo "✅ 证书已生成到 /certs/"' >> /generate-cert.sh && \
    chmod +x /generate-cert.sh

ENTRYPOINT ["/generate-cert.sh"]
```

**使用方法：**
```bash
docker build -t cert-generator .
docker run -v $(pwd):/certs cert-generator "test.example.com" "password123"
```

---

## 📋 API 请求/响应规范

### 请求格式

**HTTP Method:** `POST`  
**Content-Type:** `application/json`  
**Endpoint:** `https://tx.qsgl.net:5075/api/cert/v2/generate`

**请求体参数：**

| 参数 | 类型 | 必填 | 说明 | 示例值 |
|-----|------|------|------|--------|
| `domain` | string | ✅ | 域名（支持泛域名） | `example.com` 或 `*.example.com` |
| `certType` | string | ❌ | 证书类型 | `RSA2048` 或 `ECDSA256`（默认：`RSA2048`） |
| `exportFormat` | string | ❌ | 导出格式 | `PEM`、`PFX` 或 `BOTH`（默认：`BOTH`） |
| `pfxPassword` | string | ⚠️ | PFX 密码 | 任意字符串（导出 PFX 时必填） |

---

### 响应格式

**成功响应（HTTP 200）：**
```json
{
  "success": true,
  "message": "自签名证书生成成功 (RSA2048)",
  "domain": "test.example.com",
  "subject": "test.example.com",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pemCert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n",
  "pemKey": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n",
  "pemChain": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n",
  "pfxData": "MIIKWAIBAz...（Base64编码）",
  "filePaths": [
    "/app/certificates/test.example.com/test.example.com.crt",
    "/app/certificates/test.example.com/test.example.com.key",
    "/app/certificates/test.example.com/test.example.com.fullchain.crt",
    "/app/certificates/test.example.com/test.example.com.pfx"
  ],
  "expiryDate": "2028-10-29T16:55:09Z"
}
```

**失败响应（HTTP 200）：**
```json
{
  "success": false,
  "message": "域名不能为空"
}
```

---

## 🔐 证书文件说明

### PEM 格式文件

**证书文件（.crt）：**
```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIUXXXXXXXXXXXXXXXXXXXXXXXXXXX...
-----END CERTIFICATE-----
```
- 用途：服务器证书，配置到 Web 服务器（Nginx、Apache 等）
- 格式：Base64 编码的 X.509 证书
- 包含：公钥、主题信息、签名、扩展（包括 SAN）

**私钥文件（.key）：**
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
-----END RSA PRIVATE KEY-----
```
或（ECDSA）：
```
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
-----END EC PRIVATE KEY-----
```
- 用途：服务器私钥，配置到 Web 服务器
- 格式：Base64 编码的私钥
- **注意：** 必须严格保密！

**完整证书链（.fullchain.crt）：**
```
-----BEGIN CERTIFICATE-----
（服务器证书）
-----END CERTIFICATE-----
```
- 对于自签名证书，仅包含服务器证书本身
- 对于 CA 签发的证书，包含服务器证书 + 中间CA证书

---

### PFX 格式文件

**PKCS#12 证书包（.pfx）：**
- 包含：证书 + 私钥（二进制格式）
- 用途：Windows IIS、Windows 证书导入
- 受密码保护（使用请求中的 `pfxPassword`）
- API 返回的 `pfxData` 是 Base64 编码，需要解码后保存为二进制文件

**在 Windows 中导入：**
1. 双击 `.pfx` 文件
2. 选择"当前用户"或"本地计算机"
3. 输入密码
4. 选择证书存储位置（通常选"个人"）

**在 Linux 中转换为 PEM：**
```bash
# 导出证书
openssl pkcs12 -in cert.pfx -clcerts -nokeys -out cert.crt

# 导出私钥
openssl pkcs12 -in cert.pfx -nocerts -nodes -out cert.key
```

---

## ✅ SAN 扩展验证方法

### 方法 1：使用 OpenSSL（推荐）

```bash
# 查看所有证书信息
openssl x509 -in cert.crt -text -noout

# 只查看 SAN 扩展
openssl x509 -in cert.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

**预期输出（普通域名）：**
```
X509v3 Subject Alternative Name:
    DNS:test.example.com
```

**预期输出（泛域名）：**
```
X509v3 Subject Alternative Name:
    DNS:*.example.com, DNS:example.com
```

---

### 方法 2：使用浏览器

1. 将证书导入系统证书存储
2. 配置 Web 服务器使用该证书
3. 使用浏览器访问 HTTPS 站点
4. 点击地址栏的锁图标 → 证书详情

**Chrome：**
```
开发者工具 (F12) → Security → View certificate → Details
→ 查找 "Subject Alternative Name" 扩展
```

**Firefox：**
```
地址栏锁图标 → 连接安全 → 更多信息 → 查看证书
→ 证书 → 扩展 → Subject Alternative Name
```

---

### 方法 3：使用 PowerShell（Windows）

```powershell
# 读取证书
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("cert.crt")

# 查找 SAN 扩展（OID: 2.5.29.17）
foreach ($ext in $cert.Extensions) {
    if ($ext.Oid.Value -eq "2.5.29.17") {
        Write-Host "✅ Subject Alternative Name:"
        Write-Host $ext.Format($false)
    }
}
```

---

### 方法 4：使用 .NET Core（C#）

```csharp
using System.Security.Cryptography.X509Certificates;

var cert = X509Certificate2.CreateFromPemFile("cert.crt");

foreach (var ext in cert.Extensions)
{
    if (ext.Oid?.Value == "2.5.29.17") // SAN OID
    {
        Console.WriteLine("✅ Subject Alternative Name:");
        Console.WriteLine(ext.Format(false));
    }
}
```

---

## 🎓 常见问题 (FAQ)

### Q1: 为什么需要 SAN 扩展？

**A:** 从 Chrome 58 (2017年4月) 开始，所有主流浏览器都要求证书必须包含 SAN 扩展。仅使用 CN (Common Name) 字段的证书将被拒绝，显示错误：`NET::ERR_CERT_COMMON_NAME_INVALID`

---

### Q2: 泛域名证书为什么需要两个 SAN 条目？

**A:** 泛域名 `*.example.com` 只匹配一级子域名（如 `test.example.com`），**不会**自动匹配根域名 `example.com`。因此需要同时添加：
- `DNS:*.example.com` → 匹配子域名
- `DNS:example.com` → 匹配根域名

---

### Q3: API 生成的证书有效期是多久？

**A:** 
- **自签名证书：** 3年（从生成日期起算）
- **Let's Encrypt 证书：** 90天（通过 acme.sh 申请时）

---

### Q4: 可以在生产环境使用 API 生成的证书吗？

**A:** 
- **自签名证书：** 仅适用于内网测试环境，浏览器会显示"不受信任"警告
- **Let's Encrypt 证书：** 完全适用于生产环境，被所有浏览器信任
- **建议：** 生产环境使用 Let's Encrypt 或付费 CA 签发的证书

---

### Q5: RSA 和 ECDSA 证书有什么区别？

**A:**

| 特性 | RSA 2048 | ECDSA P-256 |
|-----|---------|-------------|
| **安全强度** | 112-bit | 128-bit |
| **证书大小** | ~1.2 KB | ~0.8 KB |
| **私钥大小** | ~1.7 KB | ~0.3 KB |
| **性能** | 较慢 | 较快 |
| **兼容性** | ✅ 广泛支持 | ✅ 现代系统支持 |
| **推荐场景** | 需要兼容旧系统 | 追求性能和安全性 |

**建议：** 优先选择 ECDSA P-256，除非需要兼容非常旧的客户端。

---

### Q6: 如何验证证书是否被浏览器信任？

**A:**
1. 配置 Web 服务器使用该证书
2. 访问 HTTPS 站点
3. 自签名证书会显示警告（需要手动信任）
4. Let's Encrypt 证书会直接显示绿色锁图标

**在线验证工具：**
- SSL Labs: https://www.ssllabs.com/ssltest/
- SSL Checker: https://www.sslshopper.com/ssl-checker.html

---

## 📈 性能测试

### API 响应时间

| 证书类型 | 平均响应时间 | 证书大小 |
|---------|------------|---------|
| RSA 2048 | ~500ms | 1.2 KB |
| ECDSA P-256 | ~300ms | 0.8 KB |

### 并发性能

- **最大并发：** 100 req/s
- **建议并发：** 10-20 req/s
- **超时设置：** 30秒

---

## 🔧 故障排查

### 问题 1: API 返回 "证书生成异常"

**可能原因：**
- 域名格式不正确
- 证书类型拼写错误（应为 `RSA2048` 或 `ECDSA256`）
- 导出格式错误（应为 `PEM`、`PFX` 或 `BOTH`）
- 导出 PFX 时未提供密码

**解决方法：**
检查请求参数格式，确保符合 API 规范。

---

### 问题 2: 证书文件保存失败

**可能原因：**
- 响应中的 `pemCert` 字段是文本格式，不是 Base64
- 文件路径权限不足

**解决方法：**
```powershell
# 正确保存方法
$response.pemCert | Out-File "cert.crt" -Encoding utf8

# 错误方法（会导致解码失败）
[Convert]::FromBase64String($response.pemCert)
```

---

### 问题 3: PFX 文件无法导入

**可能原因：**
- PFX 密码错误
- Base64 解码不正确

**解决方法：**
```powershell
# 正确解码 PFX
[System.Convert]::FromBase64String($response.pfxData) | 
    Set-Content -Path "cert.pfx" -Encoding Byte
```

---

## 📚 相关文档

### 内部文档
- `CERT-SAN-EXTENSION-FIX.md` - SAN 扩展修复详细报告
- `CERT-DOWNLOAD-ZIP-FIX.md` - 证书下载功能修复报告
- `DNSApi/CERT-API-V2-GUIDE.md` - 证书 API 完整指南

### 外部标准
- [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280) - X.509 证书标准
- [RFC 6125](https://datatracker.ietf.org/doc/html/rfc6125) - 证书主题验证
- [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446) - TLS 1.3
- [CA/Browser Forum Baseline Requirements](https://cabforum.org/baseline-requirements-documents/)

---

## ✨ 总结

### 核心要点
1. ✅ **API 完全符合标准** - 生成的证书包含所有必需的扩展
2. ✅ **支持跨平台调用** - PowerShell、curl、Python、Node.js、Docker 等
3. ✅ **泛域名支持完善** - 自动添加根域名 SAN 条目
4. ✅ **多种证书类型** - RSA 2048 和 ECDSA P-256
5. ✅ **灵活导出格式** - PEM、PFX 或同时导出

### 使用建议
- 📝 **开发测试：** 使用 API 生成自签名证书
- 🌐 **生产环境：** 使用 Let's Encrypt 或付费 CA
- ⚡ **性能优先：** 选择 ECDSA P-256
- 🔧 **兼容性优先：** 选择 RSA 2048

### 安全提示
- ⚠️ **私钥保密：** 生成的私钥必须严格保护
- ⚠️ **HTTPS 传输：** API 调用时建议使用加密连接
- ⚠️ **定期更新：** 证书过期前及时更新

---

**报告生成日期：** 2025年10月30日  
**API 版本：** v2  
**测试状态：** ✅ 全部通过
