#!/bin/bash
set -euo pipefail

# 自动检测当前服务器的域名（从主机名或公网 IP 反查）
# 方法1: 从主机名获取（如果设置了 FQDN）
DETECTED_DOMAIN=$(hostname -f 2>/dev/null | grep -oP '^[^.]+\.[^.]+$' || echo "")

# 方法2: 如果主机名没有域名，从公网 IP 反查 DNS
if [ -z "$DETECTED_DOMAIN" ]; then
  PUBLIC_IP=$(curl -s --max-time 3 https://api.ip.sb/ip || curl -s --max-time 3 http://ifconfig.me || echo "")
  if [ -n "$PUBLIC_IP" ]; then
    DETECTED_DOMAIN=$(dig -x "$PUBLIC_IP" +short | head -n 1 | sed 's/\.$//' | grep -oP '[^.]+\.[^.]+$' || echo "")
  fi
fi

# 方法3: 手动指定域名（如果自动检测失败）
# 可以通过环境变量 PROXY_DOMAIN 覆盖自动检测
DOMAIN="${PROXY_DOMAIN:-${DETECTED_DOMAIN:-qsgl.cn}}"

API_URL="https://tx.qsgl.net:5075/api/request-cert"
CERT_DIR="/opt/envoy/certs"
LOG_FILE="/var/log/cert-renewal.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "开始申请证书: $DOMAIN (检测到的代理域名，将生成 *.$DOMAIN 泛域名证书)"
log "API: $API_URL"

HTTP_BODY=$(curl -fsS -X POST "$API_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "domain=$DOMAIN" \
  --data-urlencode "provider=DNSPod") || { log "错误: curl 调用 API 失败"; exit 1; }
log "API 响应长度: $(printf '%s' "$HTTP_BODY" | wc -c) 字节"

if printf '%s' "$HTTP_BODY" | tr -d '\r\n\t ' | grep -qi '"success":true'; then
  SUCCESS="1"
else
  SUCCESS="0"
fi

CERT_CONTENT=$(BODY="$HTTP_BODY" python3 - <<'PY'
import os, json
s = os.environ.get('BODY','')
try:
  d = json.loads(s)
  print(d.get('cert',''))
except Exception:
  pass
PY
)
KEY_CONTENT=$(BODY="$HTTP_BODY" python3 - <<'PY'
import os, json
s = os.environ.get('BODY','')
try:
  d = json.loads(s)
  print(d.get('key',''))
except Exception:
  pass
PY
)

if [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; then
  # 若 Python 解析失败，使用 grep/awk 简单提取（不严格）
  CERT_CONTENT=$(printf '%s' "$HTTP_BODY" | tr -d '\r' | sed -n 's/.*"cert":"\(.*\)","key".*/\1/p' | sed 's/\\n/\n/g')
  KEY_CONTENT=$(printf '%s' "$HTTP_BODY" | tr -d '\r' | sed -n 's/.*"key":"\(.*\)".*/\1/p' | sed 's/\\n/\n/g')
fi

# 判定是否继续：优先 success==1；否则如果提取到了 cert 和 key 也继续
if [ "$SUCCESS" != "1" ] && { [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; }; then
  log "错误: API 返回失败: $HTTP_BODY"
  exit 1
fi

mkdir -p "$CERT_DIR"
printf '%s\n' "$CERT_CONTENT" > "$CERT_DIR/$DOMAIN.crt"
printf '%s\n' "$KEY_CONTENT" > "$CERT_DIR/$DOMAIN.key"
## 规范换行并转换私钥为 PKCS#8（BEGIN PRIVATE KEY）
# 移除 CRLF
sed -i 's/\r$//' "$CERT_DIR/$DOMAIN.crt" || true
sed -i 's/\r$//' "$CERT_DIR/$DOMAIN.key" || true
# 将任何格式私钥（RSA/EC）统一转为不加密的 PKCS#8
if openssl pkey -in "$CERT_DIR/$DOMAIN.key" -out "$CERT_DIR/$DOMAIN.key.tmp" -nocrypt >/dev/null 2>&1; then
  mv "$CERT_DIR/$DOMAIN.key.tmp" "$CERT_DIR/$DOMAIN.key"
fi
chmod 644 "$CERT_DIR/$DOMAIN.crt"
chmod 600 "$CERT_DIR/$DOMAIN.key"
log "证书已保存: $CERT_DIR/$DOMAIN.crt"
log "私钥已保存: $CERT_DIR/$DOMAIN.key (PKCS#8)"

if docker ps --format '{{.Names}}' | grep -q '^envoy-proxy$'; then
  log "重启 Envoy 容器..."
  if ! docker restart envoy-proxy >/dev/null 2>&1; then
    log "警告: Envoy 重启命令返回非零，继续检查日志"
  fi
  sleep 1
  # 快速检查最近日志中是否存在证书加载错误
  if docker logs --tail 50 envoy-proxy 2>&1 | grep -Eqi 'Failed to load (incomplete private key|certificate chain|only P-256 ECDSA)'; then
    log "检测到 Envoy 证书加载失败，启用应急回退（生成本地 RSA 自签证书）"
    cat >/tmp/qsgl-openssl-rsa.cnf <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = *.$DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF
    openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 2048
    openssl req -new -x509 -key "$CERT_DIR/$DOMAIN.key" -sha256 -days 90 -out "$CERT_DIR/$DOMAIN.crt" -config /tmp/qsgl-openssl-rsa.cnf
    chmod 644 "$CERT_DIR/$DOMAIN.crt" && chmod 600 "$CERT_DIR/$DOMAIN.key"
    log "已生成 RSA 2048 自签证书（回退）"
    docker restart envoy-proxy >/dev/null || true
  else
    log "Envoy 已重启"
  fi
else
  log "警告: 未发现 envoy-proxy 容器，请手动确认容器名称/运行状态"
fi

log "证书更新完成!"
