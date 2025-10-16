#!/bin/bash

echo "🚀 开始构建 DNSApi Docker 镜像"

# 清理之前的发布文件
echo "📁 清理旧的发布文件..."
rm -rf publish/

# 发布应用程序
echo "📦 发布 .NET 9 应用程序..."
dotnet publish DNSApi.csproj -c Docker -o publish

# 构建Docker镜像
echo "🐳 构建 Docker 镜像..."
docker build -t dnsapi:latest .

# 标记镜像为私有仓库格式
echo "🏷️ 标记镜像用于私有仓库..."
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:latest
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:v1.0

# 推送到私有Docker Registry
echo "📤 推送镜像到私有仓库..."
docker push 43.138.35.183:5000/dnsapi:latest
docker push 43.138.35.183:5000/dnsapi:v1.0

# 显示构建结果
echo "✅ 构建并推送完成！"
echo ""
echo "🎯 从私有仓库运行容器："
echo "docker run -d -p 5074:5074 -p 5075:5075 --name dnsapi 43.138.35.183:5000/dnsapi:latest"
echo ""
echo "🌐 在其他服务器上拉取镜像："
echo "docker pull 43.138.35.183:5000/dnsapi:latest"
echo ""
echo "🔍 查看日志："
echo "docker logs -f dnsapi"
echo ""
echo "🛑 停止容器："
echo "docker stop dnsapi && docker rm dnsapi"