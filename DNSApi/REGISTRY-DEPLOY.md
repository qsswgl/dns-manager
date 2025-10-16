# DNS API 私有仓库部署指南

## 🏗️ 私有仓库配置

### 服务器信息
- **Registry地址**: `43.138.35.183:5000`
- **镜像名称**: `43.138.35.183:5000/dnsapi:latest`
- **版本标签**: `43.138.35.183:5000/dnsapi:v1.0`

---

## 📤 构建并推送镜像

### Windows (开发机器)
```bash
# 运行推送脚本
cd k:\DNS\DNSApi
.\push-to-registry.bat
```

### Linux (开发机器)
```bash
# 运行推送脚本
cd /path/to/DNSApi
chmod +x push-to-registry.sh
./push-to-registry.sh
```

---

## 🎯 目标服务器部署

### 1. 配置Docker Registry访问

如果Registry使用HTTP（非HTTPS），需要配置不安全仓库：

**Linux服务器**:
```bash
# 创建或编辑daemon.json
sudo nano /etc/docker/daemon.json

# 添加以下内容：
{
  "insecure-registries": ["43.138.35.183:5000"]
}

# 重启Docker服务
sudo systemctl restart docker
```

**Windows服务器**:
- 打开 Docker Desktop
- 进入 Settings -> Docker Engine
- 添加配置：
```json
{
  "insecure-registries": ["43.138.35.183:5000"]
}
```

### 2. 拉取并运行镜像

**方式1: 直接运行**
```bash
# 拉取镜像
docker pull 43.138.35.183:5000/dnsapi:latest

# 运行容器
docker run -d \
  --name dnsapi \
  -p 5074:5074 \
  -p 5075:5075 \
  -v ./certs:/app/certs \
  -v /etc/hosts:/etc/hosts:ro \
  43.138.35.183:5000/dnsapi:latest
```

**方式2: 使用docker-compose**
```yaml
# docker-compose.yml
version: '3.8'

services:
  dnsapi:
    image: 43.138.35.183:5000/dnsapi:latest
    container_name: dnsapi
    ports:
      - "5074:5074"
      - "5075:5075"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:5074;https://+:5075
    volumes:
      - ./certs:/app/certs
      - /etc/hosts:/etc/hosts:ro
    restart: unless-stopped
```

```bash
# 启动服务
docker-compose up -d
```

### 3. 验证部署

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs dnsapi

# 测试API
curl http://localhost:5074/api/wan-ip

# 访问Web界面
# http://server-ip:5074
```

---

## 🔧 故障排除

### Registry连接问题
```bash
# 测试Registry连接
telnet 43.138.35.183 5000

# 检查防火墙
sudo ufw status
sudo ufw allow from your-ip to any port 5000

# 检查Docker配置
docker info | grep -i registry
```

### 镜像拉取失败
```bash
# 查看详细错误
docker pull 43.138.35.183:5000/dnsapi:latest --debug

# 检查镜像是否存在
curl http://43.138.35.183:5000/v2/_catalog
curl http://43.138.35.183:5000/v2/dnsapi/tags/list
```

### 容器启动问题
```bash
# 查看详细日志
docker logs --details dnsapi

# 检查端口占用
netstat -tlnp | grep 507

# 检查文件权限
ls -la /etc/hosts
```

---

## 📊 监控和管理

### 容器管理
```bash
# 查看状态
docker stats dnsapi

# 更新镜像
docker pull 43.138.35.183:5000/dnsapi:latest
docker-compose up -d

# 备份配置
docker cp dnsapi:/app/appsettings.json ./backup/
```

### 日志管理
```bash
# 实时日志
docker logs -f dnsapi

# 限制日志大小
docker run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 ...
```

---

## 🌐 访问地址

部署完成后，可通过以下地址访问：

- **主页**: http://server-ip:5074
- **API文档**: http://server-ip:5074/swagger
- **健康检查**: http://server-ip:5074/api/wan-ip
- **HTTPS**: https://server-ip:5075 (需配置证书)