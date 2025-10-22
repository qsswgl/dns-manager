#!/bin/bash

# 证书申请脚本
DOMAIN="qsgl.net"
CERT_DIR="/opt/envoy/certs"
API_URL="http://tx.qsgl.net:5074/api/request-cert"
LOG_FILE="/var/log/cert-renewal.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "开始申请证书: $DOMAIN"

# 调用 API 申请证书
RESPONSE=$(curl -s -X POST $API_URL \
    -H 'Content-Type: application/json' \
    -d '{"domain":"'$DOMAIN'","provider":"DNSPOD"}')

# 检查响应
if [ -z "$RESPONSE" ]; then
    log "错误: API 无响应"
    exit 1
fi

# 提取 success 字段
SUCCESS=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('success', False))")

if [ "$SUCCESS" != "True" ]; then
    log "错误: 证书申请失败"
    log "响应: $RESPONSE"
    exit 1
fi

# 提取证书和私钥内容
CERT_CONTENT=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('cert', ''))")
KEY_CONTENT=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('key', ''))")

if [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; then
    log "错误: 无法提取证书或私钥内容"
    exit 1
fi

# 保存证书和私钥
echo "$CERT_CONTENT" > $CERT_DIR/$DOMAIN.crt
echo "$KEY_CONTENT" > $CERT_DIR/$DOMAIN.key

# 设置权限
chmod 644 $CERT_DIR/$DOMAIN.crt
chmod 600 $CERT_DIR/$DOMAIN.key

log "证书已保存: $CERT_DIR/$DOMAIN.crt"
log "私钥已保存: $CERT_DIR/$DOMAIN.key"

# 重启 Envoy 容器
log "重启 Envoy 容器..."
docker restart envoy-proxy

log "证书更新完成!"
