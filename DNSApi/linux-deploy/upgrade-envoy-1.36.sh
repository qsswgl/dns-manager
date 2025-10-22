#!/bin/bash
# Envoy Proxy 升级到 1.36 版本
# 支持 EC (ECDSA) 证书

set -e

echo "=========================================="
echo "Envoy Proxy 升级到 1.36"
echo "=========================================="

# 配置
ENVOY_VERSION="v1.36.0"
# 尝试多个镜像源
ENVOY_IMAGE="envoyproxy/envoy:${ENVOY_VERSION}"
ENVOY_IMAGE_ALT="envoyproxy/envoy:distroless-${ENVOY_VERSION}"
CONTAINER_NAME="envoy-proxy"
CONFIG_DIR="/opt/envoy"
CERT_DIR="/opt/envoy/certs"
CONFIG_FILE="/opt/envoy/envoy.yaml"

echo ""
echo "=== 1. 停止并备份当前 Envoy 容器 ==="
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "停止当前容器..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    
    echo "重命名为备份容器..."
    docker rename $CONTAINER_NAME ${CONTAINER_NAME}-v1.31-backup 2>/dev/null || true
    
    echo "✓ 旧容器已备份为: ${CONTAINER_NAME}-v1.31-backup"
else
    echo "未找到运行中的容器"
fi

echo ""
echo "=== 2. 拉取 Envoy 1.36 镜像 ==="
echo "尝试镜像: $ENVOY_IMAGE"
if docker pull $ENVOY_IMAGE 2>/dev/null; then
    echo "✓ 成功拉取: $ENVOY_IMAGE"
else
    echo "主镜像拉取失败，尝试备用镜像..."
    echo "尝试: $ENVOY_IMAGE_ALT"
    if docker pull $ENVOY_IMAGE_ALT 2>/dev/null; then
        ENVOY_IMAGE=$ENVOY_IMAGE_ALT
        echo "✓ 成功拉取备用镜像"
    else
        echo "❌ 所有镜像源均失败"
        echo "尝试使用阿里云镜像加速..."
        # 配置 Docker 镜像加速
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
EOF
        systemctl restart docker
        sleep 3
        docker pull $ENVOY_IMAGE || exit 1
    fi
fi

echo ""
echo "=== 3. 检查配置文件 ==="
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi
echo "✓ 配置文件: $CONFIG_FILE"

echo ""
echo "=== 4. 检查证书目录 ==="
if [ ! -d "$CERT_DIR" ]; then
    echo "创建证书目录..."
    mkdir -p "$CERT_DIR"
fi
ls -lh "$CERT_DIR"

echo ""
echo "=== 5. 启动 Envoy 1.36 容器 ==="
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p 80:80 \
    -p 443:443 \
    -p 8443:443 \
    -p 99:99 \
    -p 5002:5002 \
    -p 9901:9901 \
    -v $CONFIG_FILE:/etc/envoy/envoy.yaml:ro \
    -v $CERT_DIR:/etc/envoy/certs:ro \
    $ENVOY_IMAGE

echo ""
echo "=== 6. 等待容器启动 ==="
sleep 5

echo ""
echo "=== 7. 检查容器状态 ==="
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✓ Envoy 1.36 容器运行中"
    docker ps | grep $CONTAINER_NAME
else
    echo "❌ 容器启动失败"
    docker logs $CONTAINER_NAME --tail 30
    exit 1
fi

echo ""
echo "=== 8. 查看 Envoy 版本 ==="
docker exec $CONTAINER_NAME envoy --version

echo ""
echo "=== 9. 检查日志 ==="
docker logs $CONTAINER_NAME --tail 20

echo ""
echo "=== 10. 测试本地连接 ==="
sleep 2
echo "测试 8443 端口..."
RESULT=$(curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' --connect-timeout 5 2>&1)
echo "$RESULT" | head -5

if echo "$RESULT" | grep -q '200 OK'; then
    echo ""
    echo "✅ Envoy 1.36 升级成功!"
    echo "✅ 服务正常运行"
else
    echo ""
    echo "⚠️ 服务测试未通过，请检查日志"
fi

echo ""
echo "=========================================="
echo "升级完成!"
echo "=========================================="
echo ""
echo "📝 后续操作:"
echo "1. 部署 EC 证书: bash /tmp/ec.sh"
echo "2. 测试外网访问: curl -kI https://www.qsgl.cn:8443/"
echo "3. 如需回滚: docker stop $CONTAINER_NAME && docker start ${CONTAINER_NAME}-v1.31-backup"
echo "4. 清理旧容器: docker rm ${CONTAINER_NAME}-v1.31-backup"
