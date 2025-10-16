# 解决 Ubuntu 容器重启问题的方案

## 问题分析
Ubuntu 服务器上的容器出现 **退出代码 139** (段错误)，主要原因：
1. .NET 10 预览版在生产环境不稳定
2. 运行时依赖版本不匹配
3. 证书加载问题

## 🎯 推荐解决方案

### 方案一：使用稳定版镜像（推荐）
我已经构建了 .NET 8 稳定版镜像，推荐使用：

```bash
# Ubuntu 服务器上执行：

# 1. 停止现有容器
docker stop dnsapi-ssl dnsapi
docker rm dnsapi-ssl dnsapi

# 2. 拉取稳定版镜像
docker pull 43.138.35.183:5000/dnsapi:stable

# 3. 运行稳定版容器
docker run -d \
  --name dnsapi-stable \
  -p 5074:5074 \
  -p 5075:5075 \
  --restart unless-stopped \
  43.138.35.183:5000/dnsapi:stable

# 4. 检查状态
docker ps
docker logs dnsapi-stable
```

### 方案二：系统级修复
如果仍有问题，执行以下修复：

```bash
# 更新系统包
sudo apt update && sudo apt upgrade -y

# 安装 .NET 8 运行时
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install -y dotnet-runtime-8.0

# 清理 Docker 资源
docker system prune -f

# 重启 Docker 服务
sudo systemctl restart docker
```

## 🔧 可用镜像版本对比

| 镜像标签 | .NET 版本 | 稳定性 | 状态 | 推荐度 |
|---------|----------|--------|------|--------|
| `43.138.35.183:5000/dnsapi:stable` | .NET 8.0 | ✅ 稳定 | ✅ 可用 | ⭐⭐⭐⭐⭐ |
| `43.138.35.183:5000/dnsapi:ssl` | .NET 8.0 | ✅ 稳定 | ✅ 可用 | ⭐⭐⭐⭐ |
| `43.138.35.183:5000/dnsapi:net10-ssl` | .NET 10 预览 | ⚠️ 不稳定 | ❌ 有问题 | ⭐⭐ |
| `43.138.35.183:5000/dnsapi:latest` | .NET 8.0 | ✅ 稳定 | ✅ 可用 | ⭐⭐⭐ |

## 🎯 访问测试

容器成功运行后，测试访问：

```bash
# HTTP 测试
curl http://localhost:5074/api/wan-ip

# HTTPS 测试（忽略证书警告）
curl -k https://localhost:5075/api/wan-ip

# 浏览器访问
# HTTP: http://[服务器IP]:5074
# HTTPS: https://tx.qsgl.net:5075
```

## 📋 预期输出

**成功运行的日志应该包含：**
```
DNS API Starting...
Loading certificate: /app/certificates/qsgl.net.crt
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://[::]:5074
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://[::]:5075
```

**成功的容器状态：**
```bash
$ docker ps
CONTAINER ID   IMAGE                              COMMAND        CREATED          STATUS          PORTS                    NAMES
abc123def456   43.138.35.183:5000/dnsapi:stable   "./DNSApi"     2 minutes ago    Up 2 minutes    0.0.0.0:5074-5075->...   dnsapi-stable
```

## 🚨 故障排查

如果仍然遇到问题：

1. **查看详细日志：**
   ```bash
   docker logs dnsapi-stable --details --timestamps
   ```

2. **检查系统资源：**
   ```bash
   free -h  # 内存使用
   df -h    # 磁盘使用
   ```

3. **测试网络连通性：**
   ```bash
   # 测试私有仓库连接
   docker pull alpine:latest
   
   # 测试端口占用
   netstat -tulpn | grep 507
   ```

4. **回退到最基础版本：**
   ```bash
   docker run -d --name dnsapi-basic -p 5074:5074 43.138.35.183:5000/dnsapi:latest
   ```

## ✅ 推荐执行顺序

**立即执行（建议）：**
```bash
# Step 1: 清理现有容器
docker stop $(docker ps -q --filter "name=dnsapi") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=dnsapi") 2>/dev/null || true

# Step 2: 运行稳定版
docker pull 43.138.35.183:5000/dnsapi:stable
docker run -d --name dnsapi-stable -p 5074:5074 -p 5075:5075 --restart unless-stopped 43.138.35.183:5000/dnsapi:stable

# Step 3: 验证
sleep 10
docker ps | grep dnsapi-stable
docker logs dnsapi-stable | tail -10
```

这个稳定版镜像已经在我的测试环境中验证过，应该能解决重启问题。