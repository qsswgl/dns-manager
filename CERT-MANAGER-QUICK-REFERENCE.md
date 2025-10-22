# 证书管理服务 - 快速参考

## 🚀 服务信息
- **服务地址**: http://43.138.35.183:5074
- **Docker镜像**: 43.138.35.183:5000/dnsapi:latest (cert-manager-v3)
- **配置文件**: k:\DNS\DNSApi\certificates.json

## 📋 API端点速查

### 1. 查看系统状态
```bash
GET /api/cert-manager/status
```
返回所有证书的健康状态摘要

### 2. 列出所有证书
```bash
GET /api/cert-manager/list
```
返回详细的证书列表，包括部署配置

### 3. 检查特定证书
```bash
POST /api/cert-manager/check?domain={domain}
```
检查并更新证书的有效期信息

### 4. 续签证书
```bash
POST /api/cert-manager/renew?domain={domain}&deploy={true|false}
```
- `domain`: 域名（必需）
- `deploy`: 是否自动部署（可选，默认true）

### 5. 部署证书
```bash
POST /api/cert-manager/deploy?domain={domain}&deploymentName={name}
```
- `domain`: 域名（必需）
- `deploymentName`: 部署目标名称（可选，不指定则部署到所有启用的目标）

## 🔄 自动化功能
- ⏰ 每6小时自动检查所有证书
- 📅 提前30天自动续签（可在配置中调整）
- 📤 续签后自动部署到配置的目标
- 🔧 支持部署后命令执行

## 🛠️ 常用操作

### 重启服务
```bash
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker restart dnsapi"
```

### 查看日志
```bash
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs -f dnsapi"
```

### 查看后台服务日志
```bash
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs dnsapi 2>&1 | grep -E '证书|续签|部署'"
```

### 手动触发证书检查（在服务器上）
```bash
docker exec dnsapi curl -s http://localhost:5074/api/cert-manager/status
```

## 📝 添加新证书

1. 编辑配置文件 `k:\DNS\DNSApi\certificates.json`
2. 添加新的证书配置到 `managedCertificates` 数组
3. 重新发布并部署：
```powershell
cd k:\DNS\DNSApi
dotnet publish -c Release -o publish --self-contained false
docker build -t 43.138.35.183:5000/dnsapi:latest -f Dockerfile.simple .
docker push 43.138.35.183:5000/dnsapi:latest

ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker pull 43.138.35.183:5000/dnsapi:latest && docker stop dnsapi && docker rm dnsapi && docker run -d --name dnsapi -p 5074:5074 -p 5075:8443 -v /opt/shared-certs:/opt/shared-certs:rw -v /opt/acme-scripts:/opt/acme-scripts:ro -v /root/.acme.sh:/root/.acme.sh:rw 43.138.35.183:5000/dnsapi:latest"
```

## 📊 监控建议

### 检查证书状态
```bash
curl -s http://43.138.35.183:5074/api/cert-manager/status | jq '.summary'
```

### 查看即将过期的证书
```bash
curl -s http://43.138.35.183:5074/api/cert-manager/list | jq '.certificates[] | select(.daysUntilExpiry < 30)'
```

### 查看部署失败的记录
```bash
curl -s http://43.138.35.183:5074/api/cert-manager/list | jq '.certificates[].deployments[] | select(.lastError != null)'
```

## 🔐 支持的部署类型

### 1. SSH/SCP 部署
适用于远程服务器，使用SSH密钥认证
```json
{
  "Type": "ssh",
  "SshHost": "example.com",
  "SshUser": "root",
  "SshKeyPath": "/path/to/key",
  "TargetCertPath": "/etc/ssl/cert.pem",
  "TargetKeyPath": "/etc/ssl/key.pem",
  "PostDeployCommand": "systemctl reload service"
}
```

### 2. Docker Volume 部署
适用于共享卷的容器
```json
{
  "Type": "docker-volume",
  "TargetCertPath": "/opt/shared-certs/cert.pem",
  "TargetKeyPath": "/opt/shared-certs/key.pem",
  "PostDeployCommand": "docker exec container_name reload"
}
```

### 3. Local Copy 部署
适用于本地文件系统
```json
{
  "Type": "local-copy",
  "TargetCertPath": "/path/to/cert.pem",
  "TargetKeyPath": "/path/to/key.pem",
  "PostDeployCommand": "systemctl reload nginx"
}
```

## 🆘 故障排查

### API返回404
检查路由是否在 `app.Run()` 之前注册

### 部署失败
1. 检查SSH密钥权限
2. 验证目标路径权限
3. 查看详细错误日志：`docker logs dnsapi`

### 证书续签失败
1. 检查acme.sh脚本是否存在
2. 验证DNS API凭据配置
3. 查看续签日志中的错误信息

---
**最后更新**: 2025-10-20
**版本**: cert-manager-v3
