# Let's Encrypt 集成方案

## 方案对比

| 方案 | 证书类型 | 浏览器信任 | 实现难度 | 推荐度 |
|------|---------|-----------|---------|--------|
| **当前 (自签名)** | Self-Signed | ❌ | ⭐ 简单 | 测试环境 |
| **acme.sh 脚本** | Let's Encrypt | ✅ | ⭐⭐ 中等 | ⭐⭐⭐⭐⭐ |
| **Certes 库** | Let's Encrypt | ✅ | ⭐⭐⭐ 复杂 | ⭐⭐⭐ |
| **外部服务** | 第三方 CA | ✅ | ⭐⭐⭐⭐ 很复杂 | ⭐⭐ |

---

## 方案 1: 集成 acme.sh (推荐)

### 优点
- ✅ Let's Encrypt 免费可信证书
- ✅ 支持 DNS-01 验证（适合内网服务器）
- ✅ 自动续期
- ✅ 支持泛域名证书
- ✅ 支持 P-256 ECDSA

### 实现步骤

#### 1. 在服务器上安装 acme.sh

```bash
ssh -i "C:\Key\tx.qsgl.net_id_ed25519" root@43.138.35.183

# 安装 acme.sh
curl https://get.acme.sh | sh -s email=admin@qsgl.net

# 重新加载环境变量
source ~/.bashrc
```

#### 2. 配置 DNSPod API 密钥

```bash
# 设置环境变量
export DP_Id="您的DNSPod_API_ID"
export DP_Key="您的DNSPod_API_Key"

# 或者永久保存到 ~/.bashrc
echo 'export DP_Id="您的DNSPod_API_ID"' >> ~/.bashrc
echo 'export DP_Key="您的DNSPod_API_Key"' >> ~/.bashrc
```

#### 3. 申请证书

```bash
# 申请 P-256 ECDSA 泛域名证书
~/.acme.sh/acme.sh --issue \
  --dns dns_dp \
  -d qsgl.net \
  -d "*.qsgl.net" \
  --keylength ec-256 \
  --server letsencrypt

# 查看证书
~/.acme.sh/acme.sh --list
```

#### 4. 部署证书

```bash
# 安装证书到指定目录
~/.acme.sh/acme.sh --install-cert -d qsgl.net \
  --ecc \
  --cert-file /opt/nginx-certs/qsgl.net.crt \
  --key-file /opt/nginx-certs/qsgl.net.key \
  --fullchain-file /opt/nginx-certs/qsgl.net.fullchain.crt \
  --reloadcmd "docker restart nginx-dnsapi-proxy"
```

#### 5. 修改 API 代码调用 acme.sh

在 `Program.cs` 的 `/api/request-cert` 端点中：

```csharp
// 替换自签名证书生成逻辑
var result = await CallAcmeShScript(domain, provider, apiKeyId, apiKeySecret);

if (result.Success)
{
    var certPem = File.ReadAllText(result.CertPath);
    var keyPem = File.ReadAllText(result.KeyPath);
    
    return Results.Ok(new { 
        success = true, 
        cert = certPem, 
        key = keyPem,
        issuer = "Let's Encrypt",
        type = "trusted"
    });
}
```

---

## 方案 2: 使用 Certes 库 (.NET ACME 客户端)

### 1. 安装 NuGet 包

```bash
cd K:\DNS\DNSApi
dotnet add package Certes
```

### 2. 修改代码使用 Certes

```csharp
using Certes;
using Certes.Acme;
using Certes.Acme.Resource;

// 创建 ACME 客户端
var acme = new AcmeContext(WellKnownServers.LetsEncryptV2);

// 创建账户
var account = await acme.NewAccount("admin@example.com", true);

// 申请证书
var order = await acme.NewOrder(new[] { "example.com", "*.example.com" });

// DNS-01 验证
var authz = (await order.Authorizations()).First();
var dnsChallenge = await authz.Dns();
var dnsTxt = acme.AccountKey.DnsTxt(dnsChallenge.Token);

// 添加 TXT 记录到 DNSPod
// ... (调用 DNSPod API)

// 验证
await dnsChallenge.Validate();

// 生成私钥和 CSR
var privateKey = KeyFactory.NewKey(KeyAlgorithm.ES256); // P-256
var cert = await order.Generate(new CsrInfo
{
    CommonName = "example.com",
}, privateKey);

// 下载证书
var certPem = cert.ToPem();
var keyPem = privateKey.ToPem();
```

---

## 方案 3: 当前自签名证书的使用场景

### 适用场景
1. **内网测试环境** ✅
2. **API 服务器间通信** (可以配置信任)
3. **开发调试** ✅
4. **临时演示** ✅

### 客户端如何使用自签名证书

#### Linux/macOS (curl)
```bash
# 忽略证书验证
curl -k https://tx.qsgl.net:5075/api/health

# 或指定 CA 证书
curl --cacert ca.crt https://tx.qsgl.net:5075/api/health
```

#### PowerShell
```powershell
# 忽略证书验证
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Invoke-RestMethod -Uri https://tx.qsgl.net:5075/api/health
```

#### Python
```python
import requests

# 忽略警告
requests.get('https://tx.qsgl.net:5075/api/health', verify=False)
```

#### Node.js
```javascript
const https = require('https');
const axios = require('axios');

// 忽略证书验证
const agent = new https.Agent({ rejectUnauthorized: false });
axios.get('https://tx.qsgl.net:5075/api/health', { httpsAgent: agent });
```

---

## 推荐方案

### 生产环境：方案 1 (acme.sh) ⭐⭐⭐⭐⭐
- 成熟稳定
- 自动续期
- 浏览器完全信任
- 实现相对简单

### 测试环境：当前自签名 ✅
- 已经可用
- 无需额外配置
- 适合内网和开发环境

---

## 立即行动方案

如果您需要让 `https://tx.qsgl.net:5075` 被浏览器信任，我建议：

### 快速方案 (30分钟)
1. 在服务器上安装 acme.sh
2. 配置 DNSPod API
3. 申请 Let's Encrypt 证书
4. 手动部署到 Nginx/Envoy

### 完整集成方案 (2-3小时)
1. 修改 API 代码集成 acme.sh 脚本调用
2. 自动化证书申请和续期
3. 更新 Docker 镜像
4. 部署到生产环境

---

## 需要我帮您实现吗？

请告诉我：
1. ✅ **使用 acme.sh 手动申请证书** (快速)
2. ✅ **修改 API 代码集成 Let's Encrypt** (完整)
3. ❌ **继续使用自签名证书** (当前状态)

我可以立即帮您实现选择的方案！
