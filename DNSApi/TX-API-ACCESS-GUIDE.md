# tx.qsgl.net API 访问说明

## 当前状态 (2025-10-20)

### ✅ 已完成的工作

1. **API 代码修复** - 生成 P-256 ECDSA 证书（Envoy 兼容）
   - 修改: `Program.cs` 第 602 行
   - 从 P-521 改为 P-256: `ECDsa.Create(ECCurve.NamedCurves.nistP256)`

2. **Docker 镜像更新**
   - 镜像: `43.138.35.183:5000/dnsapi:latest`
   - 标签: `43.138.35.183:5000/dnsapi:p256-fix`
   - 构建时间: 2025-10-20 13:00

3. **服务器部署完成**
   - 服务器: tx.qsgl.net (43.138.35.183)
   - 容器状态: 运行中
   - HTTP 端口: 5074 ✅
   - HTTPS 端口: 5075 ⚠️ (暂不可用)

---

## API 访问方式

### 推荐方式：HTTP (端口 5074) ✅

**基础地址**: `http://tx.qsgl.net:5074`

#### 健康检查
```bash
curl http://tx.qsgl.net:5074/api/health
```

响应:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-20T06:17:17Z"
}
```

#### 请求 P-256 证书
```bash
curl -X POST http://tx.qsgl.net:5074/api/request-cert \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=example.com&provider=DNSPOD"
```

响应:
```json
{
  "cert": "-----BEGIN CERTIFICATE-----\n...",
  "key": "-----BEGIN EC PRIVATE KEY-----\n..."
}
```

#### 验证证书曲线
```bash
curl -s -X POST http://tx.qsgl.net:5074/api/request-cert \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=example.com&provider=DNSPOD" | \
  jq -r '.key' | \
  openssl ec -text -noout 2>&1 | grep 'Private-Key'
```

输出: `Private-Key: (256 bit)` ✅

---

## HTTPS 访问 (端口 5075) ⚠️

### 当前状态
- **端口状态**: 5075 端口已开放
- **服务状态**: 容器内 HTTPS 未正确配置
- **问题原因**: 证书路径和加载逻辑复杂

### 临时解决方案

**选项 1: 使用 HTTP (推荐)**
- 所有客户端改用 `http://tx.qsgl.net:5074`
- 如需加密，在客户端和服务器之间使用 VPN 或 SSH 隧道

**选项 2: 通过 Cloudflare**
如果域名使用 Cloudflare DNS:
1. 开启 Cloudflare "Flexible" SSL 模式
2. 外部访问: `https://tx.qsgl.net` (端口 443)
3. Cloudflare 转发到: `http://43.138.35.183:5074`

**选项 3: 使用反向代理**
在本地或其他服务器部署 Nginx/Envoy:
```nginx
server {
    listen 443 ssl;
    server_name tx.qsgl.net;
    
    ssl_certificate /path/to/cert.crt;
    ssl_certificate_key /path/to/key.key;
    
    location / {
        proxy_pass http://tx.qsgl.net:5074;
    }
}
```

---

## 完整部署脚本示例

### www.qsgl.cn 服务器 (Envoy)

使用更新后的 API 从 HTTP 端点获取 P-256 证书:

```bash
#!/bin/bash
# 从 HTTP API 获取 P-256 证书并部署到 Envoy

CERT_DIR="/opt/envoy/certs"
API_URL="http://43.138.35.183:5074/api/request-cert"

cd "$CERT_DIR"

# 获取证书
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=qsgl.cn&provider=DNSPOD")

# 解析并保存
echo "$RESPONSE" | jq -r '.cert' > qsgl.cn.crt
echo "$RESPONSE" | jq -r '.key' > qsgl.cn.key
chmod 644 qsgl.cn.crt qsgl.cn.key

# 验证 P-256
openssl ec -in qsgl.cn.key -text -noout 2>&1 | grep 'Private-Key'
# 输出: Private-Key: (256 bit)

# 重启 Envoy
docker restart envoy-proxy
```

---

## API 端点清单

| 端点 | 方法 | 说明 | 状态 |
|------|------|------|------|
| `/api/health` | GET | 健康检查 | ✅ |
| `/api/request-cert` | POST | 申请 P-256 证书 | ✅ |
| `/api/network-test` | GET | 网络测试 | ✅ |
| `/api/updatehosts` | POST | 更新 DNS 记录 | ✅ |
| `/swagger` | GET | API 文档 | ✅ |

---

## 技术细节

### 证书规格
- **算法**: ECDSA
- **曲线**: P-256 (prime256v1, secp256r1)
- **密钥长度**: 256 bit
- **有效期**: 90 天
- **格式**: PEM

### 兼容性
- ✅ Envoy Proxy (v1.31+)
- ✅ Nginx
- ✅ Caddy
- ✅ Traefik
- ✅ 所有现代浏览器

### 文件大小参考
- 证书 (cert): ~490 bytes
- 私钥 (key): ~225 bytes

---

## 故障排查

### 问题: 无法连接 5074 端口
```bash
# 检查容器状态
docker ps | grep dnsapi

# 查看日志
docker logs dnsapi --tail 50

# 测试本地连接
curl http://localhost:5074/api/health
```

### 问题: 证书生成失败
```bash
# 检查 DNSPod 配置
docker exec dnsapi cat /app/appsettings.json | jq '.DNSPod'

# 手动测试 API
curl -X POST http://localhost:5074/api/request-cert \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=test.example.com&provider=DNSPOD"
```

### 问题: 生成的是 P-521 而不是 P-256
```bash
# 验证容器镜像版本
docker inspect dnsapi | jq '.[0].Config.Image'
# 应该是: 43.138.35.183:5000/dnsapi:latest (最新版本)

# 如果不是，重新拉取
docker pull 43.138.35.183:5000/dnsapi:latest
docker stop dnsapi && docker rm dnsapi
docker run -d --name dnsapi -p 5074:5074 43.138.35.183:5000/dnsapi:latest
```

---

## 联系信息

- **服务器**: tx.qsgl.net (43.138.35.183)
- **HTTP API**: http://tx.qsgl.net:5074
- **SSH访问**: `ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183`
- **容器名称**: `dnsapi`
- **镜像仓库**: 43.138.35.183:5000

---

## 更新日志

### 2025-10-20
- ✅ 修复 API 生成 P-256 证书
- ✅ 更新 Docker 镜像到最新版
- ✅ 验证 HTTP (5074) 端口正常工作
- ✅ 确认生成的证书为 P-256 (256 bit)
- ⚠️ HTTPS (5075) 暂时通过 HTTP 替代

### 下一步计划
- [ ] 修复容器内 HTTPS 证书加载
- [ ] 部署 Nginx 反向代理提供 HTTPS
- [ ] 配置自动证书续期
