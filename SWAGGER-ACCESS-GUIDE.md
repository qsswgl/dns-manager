# Swagger API 访问指南

## 🎯 快速访问（推荐）

### HTTP 版本 - 无证书问题
```
http://tx.qsgl.net:5074/swagger
```

**优点：**
- ✅ 无需任何证书设置
- ✅ 所有浏览器通用
- ✅ 适合内网环境
- ✅ 所有功能完全可用

---

## 🔐 HTTPS 访问方法

### 方法 1: Chrome 强制继续（推荐）

1. **访问地址**
   ```
   https://tx.qsgl.net:5075/swagger
   ```

2. **看到警告页面**
   - 显示 "您的连接不是私密连接"
   - 错误代码：NET::ERR_CERT_AUTHORITY_INVALID

3. **跳过警告**
   - 点击 **"高级"** 按钮
   - 点击 **"继续前往 tx.qsgl.net (不安全)"**

4. **刷新页面**
   - 如果页面空白，按 `F5` 刷新

### 方法 2: Chrome 隐藏继续按钮（高级）

**如果没有"高级"或"继续"按钮：**

#### 方案 A: 输入隐藏代码
在警告页面直接输入（不会显示字符，直接打字）：
```
thisisunsafe
```
页面会自动继续访问。

#### 方案 B: 启用开发者选项
1. 在 Chrome 地址栏输入：
   ```
   chrome://flags/#allow-insecure-localhost
   ```

2. 将选项设置为 **"Enabled"**

3. 点击 **"Relaunch"** 重启浏览器

4. 重新访问 Swagger 地址

### 方法 3: Microsoft Edge

1. 访问 HTTPS 地址

2. 看到警告，点击 **"高级"**

3. 点击 **"继续前往网页(不推荐)"**

4. 页面加载后按 `F5` 刷新

---

## 🔧 永久解决方案

### 选项 A: 导入自签名证书到系统

**Windows 系统：**

1. 从服务器下载证书：
   ```powershell
   scp root@tx.qsgl.net:/opt/dnsapi-app/certificates/qsgl.net.crt .
   ```

2. 双击证书文件

3. 点击 **"安装证书"**

4. 选择 **"本地计算机"**（需要管理员权限）

5. 选择 **"将所有证书放入下列存储"**

6. 点击 **"浏览"**，选择 **"受信任的根证书颁发机构"**

7. 完成导入

8. 重启所有浏览器

**通过 PowerShell 导入（管理员）：**
```powershell
# 下载证书
scp root@tx.qsgl.net:/opt/dnsapi-app/certificates/qsgl.net.fullchain.crt qsgl.net.crt

# 导入到受信任根证书
Import-Certificate -FilePath "qsgl.net.crt" -CertStoreLocation Cert:\LocalMachine\Root

# 查看已安装证书
Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*qsgl.net*"}
```

### 选项 B: 申请 Let's Encrypt 正式证书（推荐生产环境）

**要求：**
- 域名有公网可访问的 DNS 记录
- 服务器开放 80 端口（HTTP-01 验证）
- 配置 ACME 自动续期脚本

**部署步骤：**
```bash
# 安装 acme.sh
ssh root@tx.qsgl.net
curl https://get.acme.sh | sh

# 申请证书
~/.acme.sh/acme.sh --issue -d tx.qsgl.net --webroot /var/www/html

# 安装证书到应用目录
~/.acme.sh/acme.sh --install-cert -d tx.qsgl.net \
  --cert-file /opt/dnsapi-app/certificates/qsgl.net.crt \
  --key-file /opt/dnsapi-app/certificates/qsgl.net.key \
  --fullchain-file /opt/dnsapi-app/certificates/qsgl.net.fullchain.crt

# 重启 Docker 容器
docker restart dnsapi
```

---

## ❓ 常见问题

### Q1: Chrome 显示 "无法访问此网站"
**A:** 检查是否使用了正确的路径：
- ✅ 正确：`https://tx.qsgl.net:5075/swagger`
- ❌ 错误：`https://tx.qsgl.net:5075/swagger/index.html`

### Q2: Firefox 能访问，Chrome 不行
**A:** Firefox 允许手动添加例外，Chrome 需要按上述方法强制继续或导入证书。

### Q3: 导入证书后仍然显示不安全
**A:** 
1. 检查证书是否导入到 **"受信任的根证书颁发机构"**（不是"个人"或其他）
2. 重启浏览器（必须完全退出再打开）
3. 清除浏览器缓存和 Cookie

### Q4: 其他电脑也无法访问
**A:** 每台电脑需要分别：
- 方法 1：使用 HTTP 版本（无需设置）
- 方法 2：分别导入证书
- 方法 3：服务器部署 Let's Encrypt 正式证书（所有电脑自动信任）

---

## 📊 各方案对比

| 方案 | 配置难度 | 安全性 | 适用场景 |
|------|---------|--------|---------|
| HTTP 访问 | ⭐ 极简 | ⚠️ 明文传输 | 内网开发/测试 |
| 强制继续 | ⭐⭐ 简单 | ⚠️ 浏览器警告 | 临时访问 |
| 导入自签名证书 | ⭐⭐⭐ 中等 | ✅ 加密传输 | 内网生产环境 |
| Let's Encrypt | ⭐⭐⭐⭐ 复杂 | ✅✅ 公信证书 | 公网生产环境 |

---

## 🚀 推荐方案

- **开发/测试环境**: 使用 HTTP 版本（最简单）
- **内网生产环境**: 导入自签名证书到所有客户端
- **公网生产环境**: 部署 Let's Encrypt 正式证书

---

## 📞 需要帮助？

如果需要帮助部署 Let's Encrypt 证书或配置自动续期，请告知！
