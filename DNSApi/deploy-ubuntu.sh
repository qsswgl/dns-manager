#!/bin/bash

echo "🚀 DNS API 服务部署脚本"
echo "========================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "请以root用户运行此脚本: sudo $0" 
   exit 1
fi

echo ""
echo "📋 步骤1: 停止并重新配置Registry"
echo "--------------------------------"

# 停止现有registry
echo "停止现有registry容器..."
docker stop $(docker ps | grep registry | awk '{print $1}') 2>/dev/null || true
docker rm $(docker ps -a | grep registry | awk '{print $1}') 2>/dev/null || true

echo ""
echo "📋 步骤2: 配置Docker信任外部仓库"
echo "-------------------------------"

# 配置Docker daemon
echo "配置Docker daemon.json..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["43.138.35.183:5000"]
}
EOF

echo "重启Docker服务..."
systemctl restart docker

echo "等待Docker服务启动..."
sleep 15

echo ""
echo "📋 步骤3: 重新启动Registry（支持外部访问）"
echo "----------------------------------------"

# 重新启动registry
echo "启动Registry容器..."
docker run -d \
  --name registry \
  --restart=always \
  -p 0.0.0.0:5000:5000 \
  -v registry-data:/var/lib/registry \
  registry:latest

echo "等待Registry启动..."
sleep 5

echo ""
echo "📋 步骤4: 拉取DNS API镜像"
echo "------------------------"

# 拉取DNS API镜像
echo "从外部仓库拉取DNS API镜像..."
docker pull 43.138.35.183:5000/dnsapi:latest

echo ""
echo "📋 步骤5: 准备部署环境"
echo "--------------------"

# 创建必要的目录
echo "创建证书目录..."
mkdir -p /opt/dnsapi/certs
chmod 755 /opt/dnsapi/certs

echo ""
echo "📋 步骤6: 部署DNS API服务"
echo "-----------------------"

# 停止现有的dnsapi容器（如果存在）
echo "停止现有DNS API容器..."
docker stop dnsapi 2>/dev/null || true
docker rm dnsapi 2>/dev/null || true

# 运行DNS API容器
echo "启动DNS API容器..."
docker run -d \
  --name dnsapi \
  --restart=unless-stopped \
  -p 5074:5074 \
  -p 5075:5075 \
  -v /etc/hosts:/etc/hosts:ro \
  -v /opt/dnsapi/certs:/app/certs \
  -e ASPNETCORE_ENVIRONMENT=Production \
  43.138.35.183:5000/dnsapi:latest

echo ""
echo "📋 步骤7: 配置防火墙"
echo "------------------"

# 配置防火墙
echo "配置防火墙规则..."
ufw allow 5000/tcp  # Registry
ufw allow 5074/tcp  # DNS API HTTP
ufw allow 5075/tcp  # DNS API HTTPS

echo ""
echo "📋 步骤8: 验证部署"
echo "----------------"

echo "等待服务启动..."
sleep 10

echo ""
echo "容器状态:"
docker ps

echo ""
echo "测试DNS API服务:"
echo "HTTP端点测试:"
curl -s http://localhost:5074/api/wan-ip || echo "HTTP测试失败"

echo ""
echo "Registry测试:"
curl -s http://localhost:5000/v2/_catalog || echo "Registry测试失败"

echo ""
echo "🎉 部署完成！"
echo "============"
echo ""
echo "访问地址:"
echo "  DNS API 主页: http://$(hostname -I | awk '{print $1}'):5074"
echo "  DNS API 文档: http://$(hostname -I | awk '{print $1}'):5074/swagger"
echo "  Registry API: http://$(hostname -I | awk '{print $1}'):5000/v2/_catalog"
echo ""
echo "管理命令:"
echo "  查看日志: docker logs -f dnsapi"
echo "  重启服务: docker restart dnsapi"
echo "  停止服务: docker stop dnsapi"
echo ""
echo "故障排除:"
echo "  如果访问失败，请检查防火墙和网络配置"
echo "  确保端口5074、5075、5000在云服务器安全组中开放"