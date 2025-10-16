#!/bin/bash

echo "🚀 DNS API 镜像推送到私有仓库"

# 检查Docker是否运行
echo "🔍 检查Docker状态..."
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker 服务"
    exit 1
fi

# 测试与私有仓库的连接
echo "🌐 测试与私有仓库连接..."
if ! docker pull alpine:latest >/dev/null 2>&1; then
    echo "❌ 网络连接问题"
    exit 1
fi

# 配置私有仓库为不安全仓库（如需要）
echo "🔧 配置私有仓库访问..."
echo "注意：如果遇到HTTPS错误，需要配置 /etc/docker/daemon.json："
echo '{"insecure-registries":["43.138.35.183:5000"]}'

# 构建镜像
echo "📦 发布应用程序..."
dotnet publish DNSApi.csproj -c Docker -o publish

# 构建Docker镜像
echo "🐳 构建 Docker 镜像..."
docker build -t dnsapi:latest .

# 标记镜像
echo "🏷️ 标记镜像..."
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:latest
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:v1.0

# 推送镜像
echo "📤 推送镜像到 43.138.35.183:5000..."
if ! docker push 43.138.35.183:5000/dnsapi:latest; then
    echo "❌ 推送 latest 标签失败"
    exit 1
fi

if ! docker push 43.138.35.183:5000/dnsapi:v1.0; then
    echo "❌ 推送 v1.0 标签失败"
    exit 1
fi

# 显示成功信息
echo "✅ 镜像推送成功！"
echo ""
echo "📋 镜像信息："
echo "  - 43.138.35.183:5000/dnsapi:latest"
echo "  - 43.138.35.183:5000/dnsapi:v1.0"
echo ""
echo "🎯 在目标服务器上运行："
echo "  docker pull 43.138.35.183:5000/dnsapi:latest"
echo "  docker run -d -p 5074:5074 -p 5075:5075 --name dnsapi 43.138.35.183:5000/dnsapi:latest"
echo ""
echo "🔧 或使用docker-compose："
echo "  docker-compose up -d"