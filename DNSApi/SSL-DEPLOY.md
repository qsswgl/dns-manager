# DNS API HTTPS 部署指南

## 概述
本版本使用 qsgl.net 泛域名证书，支持 HTTPS 访问 `tx.qsgl.net:5075`

## 已配置的功能
- ✅ HTTP 端口: 5074
- ✅ HTTPS 端口: 5075 (使用 qsgl.net.pfx 证书)
- ✅ 支持 HTTP/1.1, HTTP/2, HTTP/3
- ✅ 跨域 (CORS) 支持
- ✅ 证书已集成到 Docker 镜像

## 镜像信息
- 镜像名称: `43.138.35.183:5000/dnsapi:ssl`
- 构建状态: ✅ 已推送到私有仓库
- 证书路径: `/app/certificates/qsgl.net.pfx` (容器内)

## 部署命令

### 1. 单容器运行
```bash
docker run -d \
  --name dnsapi-ssl \
  -p 5074:5074 \
  -p 5075:5075 \
  --restart unless-stopped \
  43.138.35.183:5000/dnsapi:ssl
```

### 2. Docker Compose 运行
```bash
# 使用 docker-compose-ssl.yml
docker-compose -f docker-compose-ssl.yml up -d
```

## 访问方式

### HTTP 访问
- 本地: http://localhost:5074
- 局域网: http://[服务器IP]:5074

### HTTPS 访问
- 域名: https://tx.qsgl.net:5075
- 本地测试: https://localhost:5075 (证书警告正常)

## 主要 API 端点
- GET `/api/wan-ip` - 获取公网 IP
- POST `/api/updatehosts` - 更新 DNS 记录
- POST `/api/request-cert` - 申请证书
- GET `/swagger` - API 文档

## 证书配置
- 证书文件: `qsgl.net.pfx` (已集成)
- 域名支持: `*.qsgl.net`
- 绑定域名: `tx.qsgl.net:5075`
- 密码: 无密码保护

## 故障排查

### 查看容器日志
```bash
docker logs dnsapi-ssl
```

### 检查端口占用
```bash
netstat -tulpn | grep 507
```

### 验证证书
```bash
openssl s_client -connect tx.qsgl.net:5075 -servername tx.qsgl.net
```

## Ubuntu 部署注意事项
如果遇到容器退出代码 139:
1. 检查 .NET 运行时兼容性
2. 确认私有仓库配置
3. 验证网络连通性

```bash
# 添加私有仓库支持
sudo nano /etc/docker/daemon.json
{
  "insecure-registries": ["43.138.35.183:5000"]
}
sudo systemctl restart docker
```