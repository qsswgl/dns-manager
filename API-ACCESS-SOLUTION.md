# API 访问问题解决方案

## 📅 日期
2025年10月30日

## 🐛 问题描述

**问题：** 无法访问 `https://tx.qsgl.net:5075/api/request-cert`

**错误现象：** 在浏览器地址栏直接访问该 URL 时无法访问

## 🔍 问题分析

### 根本原因
`/api/request-cert` 是一个 **POST** 端点，不支持 GET 请求。

**API 定义：**
```csharp
app.MapPost("/api/request-cert", async (...) => { ... })
```

这意味着：
- ✅ 可以通过 POST 请求访问（使用工具如 curl、Postman、fetch）
- ❌ 不能在浏览器地址栏直接访问（浏览器默认使用 GET 请求）

### 验证测试

使用 PowerShell 测试成功：
```powershell
$body = @{
    domain = "test.qsgl.net"
    provider = "DNSPOD"
    certType = "RSA2048"
    exportFormat = "PEM"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://tx.qsgl.net:5075/api/request-cert" `
    -Method Post -Body $body -ContentType "application/json"
```

**响应结果：**
```json
{
  "success": true,
  "message": "✅ 证书申请成功！(RSA2048 / PEM)",
  "domain": "test.qsgl.net",
  "subject": "test.qsgl.net",
  "certType": "RSA2048",
  "isWildcard": false,
  "exportFormat": "PEM",
  "timestamp": "2025-10-30T04:19:31Z"
}
```

✅ **结论：API 端点工作正常！**

---

## ✅ 解决方案

### 方案 1：使用浏览器测试页面（最简单）✨

**访问：** https://tx.qsgl.net:5075/test-request-cert.html

这是一个专门创建的测试页面，特点：
- ✅ 在浏览器中直接使用
- ✅ 图形化界面，无需命令行
- ✅ 自动发送 POST 请求
- ✅ 实时显示响应结果
- ✅ 美观的 UI 设计

**使用步骤：**
1. 打开测试页面
2. 填写表单参数：
   - 域名（必填）
   - DNS 服务商（DNSPod/Cloudflare/阿里云）
   - 证书类型（RSA2048/ECDSA256）
   - 导出格式（PEM/PFX/BOTH）
   - API 密钥（可选，留空使用服务器配置）
3. 点击"发送请求"按钮
4. 查看响应结果

---

### 方案 2：使用 Swagger UI（推荐开发测试）

**访问：** https://tx.qsgl.net:5075/swagger

Swagger UI 是自动生成的 API 文档和测试工具。

**使用步骤：**
1. 打开 Swagger 页面
2. 找到 `Certificate Management` 分组
3. 展开 `POST /api/request-cert` 端点
4. 点击 "Try it out" 按钮
5. 填写请求参数
6. 点击 "Execute" 执行请求
7. 查看响应结果

**优势：**
- ✅ 自动生成的 API 文档
- ✅ 交互式测试界面
- ✅ 查看请求/响应格式
- ✅ 查看所有可用端点

---

### 方案 3：使用 curl 命令（Linux/macOS）

```bash
curl -k -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.qsgl.net",
    "provider": "DNSPOD",
    "certType": "RSA2048",
    "exportFormat": "PEM"
  }' | jq .
```

**参数说明：**
- `-k`: 忽略 SSL 证书验证（因为是自签名证书）
- `-X POST`: 使用 POST 方法
- `-H`: 设置请求头
- `-d`: 请求体（JSON 格式）
- `| jq .`: 美化 JSON 输出（需要安装 jq）

---

### 方案 4：使用 PowerShell（Windows）

```powershell
# 忽略 SSL 证书验证
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# 构建请求
$requestBody = @{
    domain = "test.qsgl.net"
    provider = "DNSPOD"
    certType = "RSA2048"
    exportFormat = "PEM"
    apiKeyId = "your_key_id"        # 可选
    apiKeySecret = "your_key_secret" # 可选
} | ConvertTo-Json

# 发送请求
$response = Invoke-RestMethod `
    -Uri "https://tx.qsgl.net:5075/api/request-cert" `
    -Method Post `
    -Body $requestBody `
    -ContentType "application/json"

# 显示结果
$response | ConvertTo-Json -Depth 5
```

---

### 方案 5：使用 Python

```python
import requests
import json

# 忽略 SSL 警告
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

url = "https://tx.qsgl.net:5075/api/request-cert"
payload = {
    "domain": "test.qsgl.net",
    "provider": "DNSPOD",
    "certType": "RSA2048",
    "exportFormat": "PEM"
}

response = requests.post(url, json=payload, verify=False)
result = response.json()

print(json.dumps(result, indent=2, ensure_ascii=False))
```

---

### 方案 6：使用 Postman

1. **打开 Postman**
2. **新建请求：**
   - Method: `POST`
   - URL: `https://tx.qsgl.net:5075/api/request-cert`
3. **设置 Headers：**
   - `Content-Type`: `application/json`
4. **设置 Body（raw JSON）：**
   ```json
   {
     "domain": "test.qsgl.net",
     "provider": "DNSPOD",
     "certType": "RSA2048",
     "exportFormat": "PEM"
   }
   ```
5. **关闭 SSL 验证：**
   - Settings → SSL certificate verification → OFF
6. **点击 Send 发送请求**

---

## 📝 API 参数说明

### 请求参数

| 参数 | 类型 | 必填 | 说明 | 示例值 |
|-----|------|------|------|--------|
| `domain` | string | ✅ | 域名 | `example.com` |
| `provider` | string | ✅ | DNS 服务商 | `DNSPOD`, `CLOUDFLARE`, `ALIYUN` |
| `certType` | string | ❌ | 证书类型 | `RSA2048`, `ECDSA256`（默认：`RSA2048`） |
| `exportFormat` | string | ❌ | 导出格式 | `PEM`, `PFX`, `BOTH`（默认：`PEM`） |
| `apiKeyId` | string | ❌ | API Key ID | 留空使用服务器配置 |
| `apiKeySecret` | string | ❌ | API Key Secret | 留空使用服务器配置 |
| `isWildcard` | boolean | ❌ | 是否申请泛域名证书 | `true` / `false` |
| `pfxPassword` | string | ❌ | PFX 密码（导出 PFX 时需要） | 任意字符串 |

---

### 响应格式

**成功响应：**
```json
{
  "success": true,
  "message": "✅ 证书申请成功！(RSA2048 / PEM)",
  "domain": "test.qsgl.net",
  "subject": "test.qsgl.net",
  "certType": "RSA2048",
  "isWildcard": false,
  "exportFormat": "PEM",
  "pemCert": null,
  "pemKey": null,
  "pemChain": null,
  "pfxData": null,
  "certFilePaths": null,
  "expiryDate": null,
  "timestamp": "2025-10-30T04:19:31Z"
}
```

**失败响应：**
```json
{
  "success": false,
  "message": "证书申请失败: 错误原因",
  "domain": "test.qsgl.net",
  "timestamp": "2025-10-30T04:19:31Z"
}
```

---

## ⚠️ 重要说明

### 当前状态
**注意：** `/api/request-cert` 端点目前返回的是**模拟响应**，证书相关字段为 `null`。

代码中的 TODO 标记：
```csharp
// TODO: 这里调用实际的 CertificateGenerationService
// 目前先返回成功响应以保证编译通过
await Task.Delay(100); // 模拟处理时间
```

### 生产环境建议

**如果需要生成真实证书，请使用：**

✅ **推荐使用：** `/api/cert/v2/generate` 端点

这个端点已经完整实现，包含：
- ✅ 真实的证书生成
- ✅ 支持 RSA 和 ECDSA
- ✅ 完整的 SAN 扩展
- ✅ PEM 和 PFX 格式导出
- ✅ Base64 编码的证书数据
- ✅ 文件路径列表

**使用示例：**
```bash
curl -k -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.qsgl.net",
    "certType": "RSA2048",
    "exportFormat": "BOTH",
    "pfxPassword": "yourPassword"
  }'
```

---

## 🔧 故障排查

### 问题 1: 请求超时

**可能原因：**
- 网络问题
- 服务器未响应
- 防火墙阻止

**解决方法：**
```bash
# 测试服务器是否可达
curl -k https://tx.qsgl.net:5075/api/health

# 检查端口是否开放
telnet tx.qsgl.net 5075
```

---

### 问题 2: SSL 证书错误

**错误信息：**
```
SSL certificate problem: self signed certificate
```

**解决方法：**
- curl: 添加 `-k` 参数
- PowerShell: 设置 `ServerCertificateValidationCallback`
- Python: 设置 `verify=False`
- Postman: 关闭 SSL 验证

---

### 问题 3: 403 Forbidden

**可能原因：**
- CORS 问题
- 请求头错误

**解决方法：**
确保设置正确的 Content-Type：
```
Content-Type: application/json
```

---

### 问题 4: 400 Bad Request

**可能原因：**
- JSON 格式错误
- 必填参数缺失

**解决方法：**
检查请求体格式：
```json
{
  "domain": "example.com",
  "provider": "DNSPOD",
  "certType": "RSA2048",
  "exportFormat": "PEM"
}
```

---

## 📚 相关文档

### 内部文档
- `CERT-API-SAN-TEST-REPORT.md` - 证书 API SAN 扩展测试报告
- `CERT-SAN-EXTENSION-FIX.md` - SAN 扩展修复详细说明
- `DNSApi/CERT-API-V2-GUIDE.md` - 证书 API V2 完整指南

### 可用端点
- `GET /api/health` - 健康检查
- `POST /api/request-cert` - 证书申请（模拟响应）
- `POST /api/cert/v2/generate` - 证书生成（真实证书，推荐）
- `GET /api/cert/download-zip` - 下载证书 ZIP 包
- `GET /swagger` - Swagger API 文档

---

## ✨ 快速开始

### 最简单的测试方法

1. **打开浏览器**
2. **访问测试页面：** https://tx.qsgl.net:5075/test-request-cert.html
3. **填写表单并提交**
4. **查看结果**

就这么简单！🎉

---

## 📊 总结

### 问题原因
- ❌ 试图用 GET 方法访问 POST 端点
- ✅ API 本身工作正常

### 解决方案
1. ✅ **最简单：** 使用测试页面 `test-request-cert.html`
2. ✅ **最专业：** 使用 Swagger UI
3. ✅ **命令行：** 使用 curl / PowerShell / Python

### 推荐方案
- **浏览器测试：** `test-request-cert.html`
- **生产使用：** `/api/cert/v2/generate`
- **API 文档：** Swagger UI

---

**文档创建日期：** 2025年10月30日  
**问题状态：** ✅ 已解决  
**可用性：** ✅ API 正常工作
