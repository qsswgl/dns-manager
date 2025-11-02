# 证书申请 API 验证报告

## 📅 验证日期
2025年11月2日

## 🎯 验证目标

验证通过 API 申请的证书类型：
- **测试 API:** `POST https://tx.qsgl.net:5075/api/request-cert`
- **下载 API:** `GET https://tx.qsgl.net:5075/api/cert/download-zip?domain=*.qsgl.net`
- **测试参数:**
```json
{
  "domain": "*.qsgl.net",
  "provider": "DNSPOD",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "qsgl2024"
}
```

---

## ❌ 验证结论：当前 API 未生成任何证书

### 🔍 实际测试结果

#### 1. API 响应分析

**请求:**
```bash
POST https://tx.qsgl.net:5075/api/request-cert
Content-Type: application/json

{
  "domain": "*.qsgl.net",
  "provider": "DNSPOD",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "qsgl2024"
}
```

**响应:**
```json
{
  "success": true,
  "message": "✅ 证书申请成功！(RSA2048 / BOTH)",
  "domain": "*.qsgl.net",
  "subject": "*.qsgl.net",
  "certType": "RSA2048",
  "isWildcard": false,
  "exportFormat": "BOTH",
  "pemCert": null,          ⚠️ 证书为 null
  "pemKey": null,           ⚠️ 私钥为 null
  "pemChain": null,         ⚠️ 证书链为 null
  "pfxData": null,          ⚠️ PFX 数据为 null
  "certFilePaths": null,    ⚠️ 文件路径为 null
  "expiryDate": null,       ⚠️ 过期时间为 null
  "timestamp": "2025-11-01T16:19:47Z"
}
```

**关键发现:**
- ✅ API 调用成功
- ✅ 返回 success: true
- ❌ **所有证书相关字段都是 null**
- ❌ **没有生成任何证书文件**

---

#### 2. 下载 ZIP 测试

**请求:**
```bash
GET https://tx.qsgl.net:5075/api/cert/download-zip?domain=*.qsgl.net
```

**结果:**
```
❌ 下载失败
错误: 基础连接已经关闭: 发送时发生错误
```

**原因:** 服务器上没有 `*.qsgl.net` 的证书文件

---

#### 3. 服务器文件系统检查

**证书目录:**
```bash
/app/certificates/
```

**现有文件:**
```bash
total 8.0K
-rw-r--r-- 1 root root 4.3K Oct 29 16:23 qsgl.net.pfx
```

**查找 wildcard 证书:**
```bash
find /app/certificates -type d -name '*wildcard*' -o -name '*.qsgl.net'
```

**结果:** 未找到任何 `*.qsgl.net` 或 `wildcard.qsgl.net` 相关文件

---

## 📋 代码分析

### 问题根源

**文件:** `DNSApi/Program.cs` (第 614-616 行)

```csharp
// TODO: 这里调用实际的 CertificateGenerationService
// 目前先返回成功响应以保证编译通过
await Task.Delay(100); // 模拟处理时间
```

**分析:**
1. ❌ API 端点**没有实现实际的证书生成逻辑**
2. ❌ 代码中有 `TODO` 标记，表示这是**未完成的功能**
3. ❌ 仅返回模拟成功响应，不生成任何证书
4. ❌ 无法通过此 API 申请 Let's Encrypt 证书

---

## ✅ 正确的证书生成 API

### 推荐使用：`/api/cert/v2/generate`

这个 API 已经**完整实现**，可以生成真实的自签名证书。

#### API 端点
```
POST https://tx.qsgl.net:5075/api/cert/v2/generate
```

#### 请求示例
```json
{
  "domain": "*.qsgl.net",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pfxPassword": "qsgl2024"
}
```

#### 响应示例
```json
{
  "success": true,
  "message": "自签名证书生成成功 (RSA2048)",
  "domain": "*.qsgl.net",
  "subject": "*.qsgl.net",
  "certType": "RSA2048",
  "exportFormat": "BOTH",
  "pemCert": "-----BEGIN CERTIFICATE-----\n...",    ✅ 完整证书
  "pemKey": "-----BEGIN RSA PRIVATE KEY-----\n...", ✅ 完整私钥
  "pemChain": "-----BEGIN CERTIFICATE-----\n...",   ✅ 证书链
  "pfxData": "MIIKWAIBAz...",                        ✅ PFX 数据
  "filePaths": [
    "/app/certificates/wildcard.qsgl.net/wildcard.qsgl.net.crt",
    "/app/certificates/wildcard.qsgl.net/wildcard.qsgl.net.key",
    "/app/certificates/wildcard.qsgl.net/wildcard.qsgl.net.fullchain.crt",
    "/app/certificates/wildcard.qsgl.net/wildcard.qsgl.net.pfx"
  ],
  "expiryDate": "2028-11-01T16:30:00Z"
}
```

---

## 🔐 证书类型对比

### `/api/request-cert` (未实现)

| 项目 | 状态 |
|-----|------|
| **证书类型** | ❌ 无（未实现） |
| **证书来源** | ❌ 理论上应该是 Let's Encrypt，但代码未实现 |
| **证书生成** | ❌ 不生成任何证书 |
| **返回数据** | ❌ 所有证书字段为 null |
| **文件保存** | ❌ 不保存任何文件 |
| **可用性** | ❌ 仅返回模拟响应 |
| **浏览器信任** | ❌ 无证书 |

**说明:** 虽然 Swagger 文档中描述为"使用 Let's Encrypt 自动申请 SSL 证书"，但实际代码中有 `TODO` 标记，功能未实现。

---

### `/api/cert/v2/generate` (已实现)

| 项目 | 状态 |
|-----|------|
| **证书类型** | ✅ 自签名证书 (Self-Signed) |
| **证书来源** | ✅ 本地生成（使用 .NET X509Certificate2） |
| **证书生成** | ✅ 完整实现 |
| **返回数据** | ✅ 包含完整的证书、私钥、PFX 数据 |
| **文件保存** | ✅ 保存到 `/app/certificates/{domain}/` |
| **SAN 扩展** | ✅ 包含完整的 SAN 扩展 |
| **有效期** | ✅ 3 年 |
| **浏览器信任** | ⚠️ 需要手动导入信任（自签名证书） |

**说明:** 这是完全实现的自签名证书生成 API，包含完整的 X.509v3 扩展（Key Usage、Enhanced Key Usage、SAN）。

---

## 📊 功能对比总结

### API 对比表

| 功能 | `/api/request-cert` | `/api/cert/v2/generate` |
|-----|---------------------|------------------------|
| **实现状态** | ❌ 未实现（TODO） | ✅ 已完整实现 |
| **证书类型** | 理论上 Let's Encrypt | 自签名证书 |
| **实际生成** | ❌ 不生成 | ✅ 生成 |
| **证书数据** | ❌ null | ✅ 完整数据 |
| **文件保存** | ❌ 无 | ✅ 保存到服务器 |
| **SAN 扩展** | ❌ 无 | ✅ 完整支持 |
| **浏览器信任** | ❌ 无证书 | ⚠️ 需手动信任 |
| **有效期** | ❌ 无 | ✅ 3 年 |
| **生产可用** | ❌ 不可用 | ⚠️ 仅内网测试 |

---

## 🎯 问题答案

### 问题：通过 `/api/request-cert` 申请的证书是自签名还是 Let's Encrypt？

**答案：** **两者都不是！该 API 当前不生成任何证书。**

**详细说明：**

1. **API 文档描述：**
   - Swagger 文档中写着"使用 Let's Encrypt 自动申请 SSL 证书"
   - 这是**计划中的功能**，但尚未实现

2. **实际实现状态：**
   - 代码中有 `TODO: 这里调用实际的 CertificateGenerationService`
   - 仅返回模拟成功响应
   - 不调用任何证书生成服务
   - 不保存任何文件
   - 返回的所有证书字段都是 `null`

3. **验证结果：**
   - ✅ API 调用成功（返回 200 OK）
   - ✅ 返回 `success: true`
   - ❌ 但没有任何实际的证书生成
   - ❌ 无法通过 `/api/cert/download-zip` 下载

---

## 💡 推荐方案

### 方案 1：使用自签名证书 API（立即可用）

如果只是内网测试或开发环境，使用 `/api/cert/v2/generate`：

```bash
curl -k -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.qsgl.net",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "qsgl2024"
  }'
```

**优点：**
- ✅ 立即可用
- ✅ 包含完整 SAN 扩展
- ✅ 支持泛域名
- ✅ 可下载 ZIP 包

**缺点：**
- ⚠️ 浏览器会显示"不受信任"警告
- ⚠️ 仅适合内网或测试环境

---

### 方案 2：等待 Let's Encrypt 集成（推荐生产环境）

如果需要浏览器自动信任的证书，需要：

1. **等待开发完成：**
   - `/api/request-cert` 端点需要集成 `CertificateGenerationService`
   - 调用 acme.sh 申请 Let's Encrypt 证书
   - 实现 DNS 验证流程

2. **手动使用 acme.sh：**
   ```bash
   # 在服务器上手动申请
   ssh root@tx.qsgl.net
   
   # 设置 DNSPod API 密钥
   export DP_Id="your_dnspod_id"
   export DP_Key="your_dnspod_key"
   
   # 申请泛域名证书
   ~/.acme.sh/acme.sh --issue --dns dns_dp -d "*.qsgl.net" -d "qsgl.net" \
     --keylength 2048
   ```

---

### 方案 3：直接调用证书生成服务

如果要实现 Let's Encrypt 集成，需要修改 `/api/request-cert` 端点代码：

**当前代码（第 614-616 行）：**
```csharp
// TODO: 这里调用实际的 CertificateGenerationService
// 目前先返回成功响应以保证编译通过
await Task.Delay(100); // 模拟处理时间
```

**应该改为：**
```csharp
// 注入 CertificateGenerationService
var certService = context.RequestServices.GetRequiredService<CertificateGenerationService>();

// 构建内部请求对象
var certRequest = new CertificateRequest
{
    Domain = request.Domain,
    CertType = certType,
    ExportFormat = exportFormat,
    PfxPassword = request.PfxPassword,
    Provider = request.Provider,
    ApiKeyId = request.ApiKeyId,
    ApiKeySecret = request.ApiKeySecret,
    IsWildcard = isWildcard
};

// 调用证书申请服务（通过 acme.sh）
var result = await certService.IssueCertificateAsync(certRequest);
```

---

## 📝 测试命令汇总

### 测试当前 API（返回模拟响应）

**PowerShell:**
```powershell
$body = @{
    domain = "*.qsgl.net"
    provider = "DNSPOD"
    certType = "RSA2048"
    exportFormat = "BOTH"
    pfxPassword = "qsgl2024"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://tx.qsgl.net:5075/api/request-cert" `
    -Method Post -Body $body -ContentType "application/json" `
    -SkipCertificateCheck
```

**curl:**
```bash
curl -k -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.qsgl.net",
    "provider": "DNSPOD",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "qsgl2024"
  }'
```

**预期结果：** 返回 success: true，但所有证书字段为 null

---

### 测试实际证书生成 API（推荐）

**PowerShell:**
```powershell
$body = @{
    domain = "*.qsgl.net"
    certType = "RSA2048"
    exportFormat = "BOTH"
    pfxPassword = "qsgl2024"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "https://tx.qsgl.net:5075/api/cert/v2/generate" `
    -Method Post -Body $body -ContentType "application/json" `
    -SkipCertificateCheck

# 保存证书
$response.pemCert | Out-File "wildcard.qsgl.net.crt" -Encoding utf8
$response.pemKey | Out-File "wildcard.qsgl.net.key" -Encoding utf8

# 保存 PFX
[Convert]::FromBase64String($response.pfxData) | 
    Set-Content "wildcard.qsgl.net.pfx" -Encoding Byte
```

**curl:**
```bash
curl -k -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.qsgl.net",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "qsgl2024"
  }' | jq -r '.pemCert' > wildcard.qsgl.net.crt
```

**预期结果：** 返回完整的证书数据，包含 PEM 和 PFX 格式

---

### 下载证书 ZIP 包

**前提：** 必须先使用 `/api/cert/v2/generate` 生成证书

**PowerShell:**
```powershell
Invoke-WebRequest -Uri "https://tx.qsgl.net:5075/api/cert/download-zip?domain=*.qsgl.net" `
    -OutFile "wildcard.qsgl.net-certificates.zip" `
    -SkipCertificateCheck
```

**curl:**
```bash
curl -k -O "https://tx.qsgl.net:5075/api/cert/download-zip?domain=*.qsgl.net"
```

---

## 🔍 证书验证方法

### 验证自签名证书

**使用 OpenSSL:**
```bash
# 查看证书详情
openssl x509 -in wildcard.qsgl.net.crt -text -noout

# 查看颁发者（自签名证书 Issuer = Subject）
openssl x509 -in wildcard.qsgl.net.crt -noout -issuer -subject
```

**预期输出（自签名）:**
```
issuer=CN = *.qsgl.net
subject=CN = *.qsgl.net
```

**如果是 Let's Encrypt:**
```
issuer=C = US, O = Let's Encrypt, CN = R3
subject=CN = *.qsgl.net
```

---

### 验证 SAN 扩展

```bash
openssl x509 -in wildcard.qsgl.net.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

**预期输出（泛域名）:**
```
X509v3 Subject Alternative Name:
    DNS:*.qsgl.net, DNS:qsgl.net
```

---

## ✅ 最终结论

### 当前状态

| API 端点 | 实现状态 | 证书类型 | 可用性 |
|---------|---------|---------|--------|
| `/api/request-cert` | ❌ 未实现 | 无（理论上应该是 Let's Encrypt） | ❌ 不可用 |
| `/api/cert/v2/generate` | ✅ 已实现 | 自签名证书 | ✅ 可用 |

### 推荐方案

1. **开发/测试环境：**
   - ✅ 使用 `/api/cert/v2/generate`
   - ✅ 生成自签名证书
   - ✅ 包含完整 SAN 扩展

2. **生产环境：**
   - ⚠️ 等待 `/api/request-cert` 实现完成
   - 或手动使用 acme.sh 申请 Let's Encrypt 证书
   - 或使用付费 CA 证书

---

## 📄 相关文档

- `CERT-API-SAN-TEST-REPORT.md` - API SAN 验证测试报告
- `CERT-SAN-EXTENSION-FIX.md` - SAN 扩展修复详细说明
- `API-ACCESS-SOLUTION.md` - API 访问问题解决方案

---

**报告生成日期：** 2025年11月2日  
**验证状态：** ✅ 已完成  
**核心发现：** `/api/request-cert` 当前未生成任何证书，仅返回模拟响应
