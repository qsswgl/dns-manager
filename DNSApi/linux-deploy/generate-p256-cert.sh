#!/bin/bash
# 在服务器上生成 P-256 ECDSA 证书（符合 Envoy 要求）

set -e

CERT_DIR="/opt/envoy/certs"
DOMAIN="*.qsgl.cn"

echo "=== 生成 P-256 ECDSA 证书 ==="
date

cd "$CERT_DIR"

# 备份旧证书
if [ -f qsgl.cn.crt ]; then
    cp qsgl.cn.crt "qsgl.cn.crt.bak.$(date +%s)"
fi
if [ -f qsgl.cn.key ]; then
    cp qsgl.cn.key "qsgl.cn.key.bak.$(date +%s)"
fi

# 生成 P-256 (prime256v1) EC 私钥
echo "[1/3] 生成 P-256 ECDSA 私钥..."
openssl ecparam -name prime256v1 -genkey -noout -out qsgl.cn.key

# 生成证书签名请求
echo "[2/3] 生成 CSR..."
openssl req -new -key qsgl.cn.key -out qsgl.cn.csr \
  -subj "/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:qsgl.cn"

# 生成自签名证书（90天有效期）
echo "[3/3] 生成自签名证书..."
openssl x509 -req -in qsgl.cn.csr \
  -signkey qsgl.cn.key \
  -out qsgl.cn.crt \
  -days 90 \
  -copy_extensions copy

# 设置正确的权限（644 允许容器读取）
chmod 644 qsgl.cn.crt
chmod 644 qsgl.cn.key

# 验证证书
echo ""
echo "=== 证书验证 ==="
echo "私钥曲线:"
openssl ec -in qsgl.cn.key -text -noout 2>&1 | grep 'Private-Key'

echo ""
echo "证书信息:"
openssl x509 -in qsgl.cn.crt -noout -subject -dates

echo ""
echo "✅ P-256 ECDSA 证书生成完成"
ls -lh qsgl.cn.{crt,key}

# 重启 Envoy
echo ""
echo "重启 Envoy 容器..."
docker restart envoy-proxy

sleep 8

# 检查结果
if docker ps | grep -q envoy-proxy; then
  echo "✅ Envoy 启动成功!"
  docker logs envoy-proxy --tail 5
else
  echo "❌ Envoy 启动失败"
  docker logs envoy-proxy --tail 20
  exit 1
fi
