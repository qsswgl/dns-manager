#!/bin/bash
# EC证书自动部署脚本 - 最终版本
# 已解决权限问题：私钥必须设置为 644 才能被容器读取

set -e

CERT_DIR="/opt/envoy/certs"
API_URL="https://tx.qsgl.net:5075/api/request-cert"
DOMAIN="qsgl.cn"

echo "=== EC证书部署开始 ==="
date

# 1. 调用证书API获取EC证书
echo "[1/5] 从API获取EC证书..."
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=$DOMAIN&provider=DNSPOD")

# 检查API响应
if [ -z "$RESPONSE" ]; then
  echo "错误: API无响应"
  exit 1
fi

# 2. 解析JSON并保存证书
echo "[2/5] 解析证书内容..."
CERT=$(echo "$RESPONSE" | jq -r '.cert')
KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$CERT" == "null" ] || [ "$KEY" == "null" ]; then
  echo "错误: API返回无效证书数据"
  echo "$RESPONSE"
  exit 1
fi

# 3. 备份旧证书
echo "[3/5] 备份现有证书..."
if [ -f "$CERT_DIR/qsgl.cn.crt" ]; then
  cp "$CERT_DIR/qsgl.cn.crt" "$CERT_DIR/qsgl.cn.crt.bak.$(date +%s)"
fi
if [ -f "$CERT_DIR/qsgl.cn.key" ]; then
  cp "$CERT_DIR/qsgl.cn.key" "$CERT_DIR/qsgl.cn.key.bak.$(date +%s)"
fi

# 4. 写入新证书 (关键: 设置正确的权限)
echo "[4/5] 部署EC证书..."
echo "$CERT" > "$CERT_DIR/qsgl.cn.crt"
echo "$KEY" > "$CERT_DIR/qsgl.cn.key"

# **重点**: 设置权限为 644，允许容器读取
chmod 644 "$CERT_DIR/qsgl.cn.crt"
chmod 644 "$CERT_DIR/qsgl.cn.key"

# 验证证书格式
echo "证书验证:"
openssl ec -in "$CERT_DIR/qsgl.cn.key" -check -noout 2>&1 | head -1
openssl x509 -in "$CERT_DIR/qsgl.cn.crt" -noout -subject -dates

# 5. 重启Envoy容器
echo "[5/5] 重启Envoy容器..."
docker restart envoy-proxy

# 等待容器启动
sleep 8

# 检查容器状态
echo ""
echo "=== 部署结果 ==="
if docker ps | grep -q envoy-proxy; then
  echo "✅ Envoy容器运行中"
  docker logs envoy-proxy --tail 3
  echo ""
  echo "✅ EC证书部署成功!"
  echo "证书文件:"
  ls -l "$CERT_DIR/qsgl.cn."{crt,key}
else
  echo "❌ Envoy容器未运行"
  docker logs envoy-proxy --tail 20
  exit 1
fi

echo ""
echo "=== 测试HTTPS连接 ==="
timeout 5 openssl s_client -connect localhost:443 -servername qsgl.cn </dev/null 2>&1 | grep -E "(Protocol|Cipher|subject|issuer)" || echo "连接超时，可能需要防火墙规则"

echo ""
echo "部署完成时间: $(date)"
