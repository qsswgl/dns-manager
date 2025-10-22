#!/bin/bash
set -euo pipefail

# 使用 HTTPS API 从 tx.qsgl.net:5075 获取 qsgl.net 泛域名证书（PEM 格式）
DOMAIN="qsgl.net"
API_URL="https://tx.qsgl.net:5075/api/request-cert"
CERT_DIR="/opt/envoy/certs"
LOG_FILE="/var/log/cert-renewal.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始申请证书: $DOMAIN (API: $API_URL)"

# 调用 API
HTTP_BODY=$(curl -fsS -X POST "$API_URL" \
  -H 'Content-Type: application/json' \
  -d '{"domain":"'$DOMAIN'","provider":"DNSPod"}') || {
  log "错误: curl 调用 API 失败"
  exit 1
}

# 解析 JSON
SUCCESS=$(printf '%s' "$HTTP_BODY" | python3 - <<'PY'
import sys,json
try:
  d=json.load(sys.stdin)
  print(d.get('success', False))
except Exception as e:
  print('False')
PY
)

if [ "$SUCCESS" != "True" ]; then
  log "错误: API 返回失败: $HTTP_BODY"
  exit 1
fi

CERT_CONTENT=$(printf '%s' "$HTTP_BODY" | python3 - <<'PY'
import sys,json
print(json.load(sys.stdin).get('cert',''))
PY
)
KEY_CONTENT=$(printf '%s' "$HTTP_BODY" | python3 - <<'PY'
import sys,json
print(json.load(sys.stdin).get('key',''))
PY
)

if [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; then
  log "错误: 响应中缺少 cert 或 key 字段"
  exit 1
fi

# 写入证书
mkdir -p "$CERT_DIR"
CERT_PATH="$CERT_DIR/$DOMAIN.crt"
KEY_PATH="$CERT_DIR/$DOMAIN.key"
printf '%s\n' "$CERT_CONTENT" > "$CERT_PATH"
printf '%s\n' "$KEY_CONTENT" > "$KEY_PATH"
chmod 644 "$CERT_PATH"
chmod 600 "$KEY_PATH"
log "证书已保存: $CERT_PATH"
log "私钥已保存: $KEY_PATH"

# 重启 envoy 容器
if docker ps --format '{{.Names}}' | grep -q '^envoy-proxy$'; then
  log "重启 Envoy 容器..."
  docker restart envoy-proxy >/dev/null
  log "Envoy 已重启"
else
  log "警告: 未发现 envoy-proxy 容器，请手动确认容器名称/运行状态"
fi

log "证书更新完成!"
