#!/bin/bash
# 从更新后的API获取P-256证书并部署到Envoy

set -e

CERT_DIR="/opt/envoy/certs"
API_URL="http://43.138.35.183:5074/api/request-cert"

echo "=== 从API获取P-256 ECDSA证书并部署 ==="
date

cd "$CERT_DIR"

# 获取证书
echo "[1/4] 调用证书API..."
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "domain=qsgl.cn&provider=DNSPOD")

# 检查响应
if [ -z "$RESPONSE" ]; then
  echo "❌ API无响应"
  exit 1
fi

# 解析证书和私钥
echo "[2/4] 解析证书内容..."
CERT=$(echo "$RESPONSE" | jq -r '.cert')
KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$CERT" == "null" ] || [ "$KEY" == "null" ]; then
  echo "❌ API返回无效数据"
  echo "$RESPONSE" | jq '.'
  exit 1
fi

# 备份旧证书
echo "[3/4] 备份现有证书..."
if [ -f qsgl.cn.crt ]; then
  cp qsgl.cn.crt "qsgl.cn.crt.bak.$(date +%s)"
fi
if [ -f qsgl.cn.key ]; then
  cp qsgl.cn.key "qsgl.cn.key.bak.$(date +%s)"
fi

# 写入新证书
echo "$CERT" > qsgl.cn.crt
echo "$KEY" > qsgl.cn.key
chmod 644 qsgl.cn.crt qsgl.cn.key

# 验证
echo ""
echo "=== 证书验证 ==="
echo "私钥类型:"
openssl ec -in qsgl.cn.key -text -noout 2>&1 | grep "Private-Key"

echo ""
echo "证书信息:"
openssl x509 -in qsgl.cn.crt -noout -subject -dates

# 重启Envoy
echo ""
echo "[4/4] 重启Envoy..."
docker restart envoy-proxy

sleep 8

# 检查状态
echo ""
echo "=== 部署结果 ==="
if docker ps | grep -q envoy-proxy; then
  echo "✅ Envoy运行中"
  docker logs envoy-proxy --tail 5
  echo ""
  echo "✅ P-256 ECDSA证书部署成功!"
else
  echo "❌ Envoy未运行"
  docker logs envoy-proxy --tail 20
  exit 1
fi

echo ""
echo "证书文件:"
ls -lh qsgl.cn.{crt,key}
