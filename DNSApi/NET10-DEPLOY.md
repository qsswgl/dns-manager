# DNS API .NET 10 部署总结

## 🎯 已完成的工作

### ✅ Docker 镜像构建
- **镜像名称**: `43.138.35.183:5000/dnsapi:net10-ssl`
- **.NET 版本**: 10.0 预览版
- **证书支持**: PEM 格式 (qsgl.net.crt + qsgl.net.key)
- **推送状态**: ✅ 已成功推送到私有仓库

### ✅ 证书配置
- **证书文件**: `/app/certificates/qsgl.net.crt`
- **私钥文件**: `/app/certificates/qsgl.net.key`
- **域名支持**: `*.qsgl.net` (泛域名证书)
- **目标绑定**: `tx.qsgl.net:5075`

### ✅ 端口配置
- **HTTP**: 5074
- **HTTPS**: 5075 (使用 qsgl.net 证书)
- **协议支持**: HTTP/1.1, HTTP/2, HTTP/3

## 🚀 部署命令

### Ubuntu 服务器部署
```bash
# 1. 配置 Docker 私有仓库
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["43.138.35.183:5000"]
}
EOF

# 2. 重启 Docker 服务
sudo systemctl restart docker

# 3. 拉取镜像
docker pull 43.138.35.183:5000/dnsapi:net10-ssl

# 4. 运行容器
docker run -d \
  --name dnsapi-ssl \
  -p 5074:5074 \
  -p 5075:5075 \
  --restart unless-stopped \
  43.138.35.183:5000/dnsapi:net10-ssl

# 5. 检查容器状态
docker ps
docker logs dnsapi-ssl
```

### 本地 Windows 测试
```powershell
# 拉取并运行
docker pull 43.138.35.183:5000/dnsapi:net10-ssl
docker run -d --name dnsapi-test -p 5074:5074 -p 5075:5075 43.138.35.183:5000/dnsapi:net10-ssl

# 测试访问
curl http://localhost:5074/api/wan-ip
curl -k https://localhost:5075/api/wan-ip
```

## 🔧 访问方式

### 生产环境 (使用域名)
- **HTTPS**: https://tx.qsgl.net:5075
- **API 文档**: https://tx.qsgl.net:5075/swagger
- **前端页面**: https://tx.qsgl.net:5075

### 本地测试 (IP 访问)
- **HTTP**: http://localhost:5074
- **HTTPS**: https://localhost:5075 (自签名证书警告)

## 📋 技术规格

### Docker 镜像信息
- **基础镜像**: mcr.microsoft.com/dotnet/aspnet:10.0-preview
- **镜像大小**: ~462MB
- **架构**: linux/amd64
- **证书位置**: /app/certificates/

### API 端点
- `GET /api/wan-ip` - 获取公网 IP
- `POST /api/updatehosts` - 更新 hosts 和 DNS
- `POST /api/request-cert` - 申请 SSL 证书
- `GET /swagger` - API 文档

### 环境变量
- `ASPNETCORE_ENVIRONMENT=Production`
- `ASPNETCORE_URLS=http://+:5074;https://+:5075`

## ⚠️ 故障排查

### 容器退出问题
如果容器启动后立即退出，检查：
```bash
# 查看详细日志
docker logs dnsapi-ssl

# 常见问题：
# 1. 证书文件不存在或权限问题
# 2. 端口被占用
# 3. .NET 运行时不兼容
```

### 证书问题
```bash
# 验证证书文件
docker exec dnsapi-ssl ls -la /app/certificates/

# 检查证书有效期
openssl x509 -in certificates/qsgl.net.crt -noout -dates
```

### 网络连接
```bash
# 检查端口监听
netstat -tulpn | grep 507

# 测试 HTTPS 连接
openssl s_client -connect tx.qsgl.net:5075 -servername tx.qsgl.net
```

## 🎉 成功指标

容器正常运行时，应该看到：
- ✅ 容器状态为 "Up"
- ✅ 日志显示 "使用 PEM 证书文件"
- ✅ HTTP 5074 和 HTTPS 5075 端口可访问
- ✅ Swagger UI 可以正常打开

## 📝 下一步

如果遇到运行问题，可以：
1. 检查 Ubuntu 系统的 .NET 运行时兼容性
2. 尝试使用 .NET 8 版本的镜像 (`43.138.35.183:5000/dnsapi:ssl`)
3. 验证证书文件的有效性和格式
4. 确认防火墙和端口配置