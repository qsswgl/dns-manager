#!/bin/bash
# Envoy 1.36 升级脚本（无交互版）

set -e

echo "=========================================="
echo "Envoy Proxy 升级到 1.36"
echo "=========================================="

# 配置
ENVOY_IMAGE="envoyproxy/envoy:v1.36.0"
CONTAINER_NAME="envoy-proxy"
CONFIG_FILE="/opt/envoy/envoy.yaml"
CERT_DIR="/opt/envoy/certs"

echo ""
echo "=== 1. 检查 Docker 服务 ==="
if ! systemctl is-active --quiet docker; then
    echo "Docker 未运行，启动中..."
    systemctl start docker
    sleep 2
fi
echo "✓ Docker 服务运行中"

echo ""
echo "=== 2. 清理旧容器 ==="
if docker ps -a | grep -q "^.*${CONTAINER_NAME}\s"; then
    echo "停止并删除旧容器..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi
echo "✓ 旧容器已清理"

echo ""
echo "=== 3. 拉取 Envoy 1.36 镜像 ==="
echo "镜像: $ENVOY_IMAGE"
# 设置拉取超时
export DOCKER_CLIENT_TIMEOUT=120
export COMPOSE_HTTP_TIMEOUT=120

if docker pull $ENVOY_IMAGE; then
    echo "✓ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败，尝试使用代理或镜像加速"
    exit 1
fi

echo ""
echo "=== 4. 验证镜像 ==="
docker images | grep envoy | head -3

echo ""
echo "=== 5. 检查配置文件 ==="
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi
echo "✓ 配置文件: $CONFIG_FILE"
ls -lh $CONFIG_FILE

echo ""
echo "=== 6. 检查证书目录 ==="
if [ ! -d "$CERT_DIR" ]; then
    mkdir -p "$CERT_DIR"
fi
echo "证书目录内容:"
ls -lh $CERT_DIR/ | head -10

echo ""
echo "=== 7. 启动 Envoy 1.36 容器 ==="
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

echo "✓ 容器已启动: $CONTAINER_NAME"

echo ""
echo "=== 8. 等待容器启动 ==="
sleep 5

echo ""
echo "=== 9. 检查容器状态 ==="
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✓ Envoy 容器运行中"
    docker ps | grep $CONTAINER_NAME
else
    echo "❌ 容器启动失败"
    docker ps -a | grep $CONTAINER_NAME
    echo ""
    echo "查看日志:"
    docker logs $CONTAINER_NAME --tail 30
    exit 1
fi

echo ""
echo "=== 10. 查看 Envoy 版本 ==="
docker exec $CONTAINER_NAME envoy --version 2>/dev/null || echo "无法获取版本信息"

echo ""
echo "=== 11. 检查启动日志 ==="
docker logs $CONTAINER_NAME --tail 20

echo ""
echo "=== 12. 测试服务 ==="
sleep 3
echo "测试本地 8443 端口..."
RESULT=$(curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' --connect-timeout 5 2>&1 | head -5)
echo "$RESULT"

if echo "$RESULT" | grep -q '200 OK'; then
    echo ""
    echo "✅ Envoy 1.36 升级成功!"
    echo "✅ 8443 端口正常响应"
elif echo "$RESULT" | grep -qi 'ssl\|certificate'; then
    echo ""
    echo "⚠️ SSL 相关问题，可能需要部署证书"
else
    echo ""
    echo "⚠️ 服务测试未通过"
fi

echo ""
echo "=========================================="
echo "升级完成!"
echo "=========================================="
echo ""
echo "📝 后续操作:"
echo "1. 测试外网: curl -kI https://www.qsgl.cn:8443/"
echo "2. 部署 EC 证书: bash /tmp/deploy-ec.sh"
echo "3. 查看日志: docker logs envoy-proxy -f"
echo "4. 进入容器: docker exec -it envoy-proxy sh"
