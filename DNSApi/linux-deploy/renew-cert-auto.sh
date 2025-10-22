#!/bin/bash
# 自动证书续期脚本（智能检测域名版本）
# 用法: 
#   1. 自动检测: ./renew-cert-auto.sh
#   2. 手动指定: PROXY_DOMAIN=qsgl.cn ./renew-cert-auto.sh
#   3. 命令行参数: ./renew-cert-auto.sh qsgl.cn

set -euo pipefail

# ============= 配置部分 =============

# 证书 API 地址
API_URL="https://tx.qsgl.net:5075/api/request-cert"

# DNS 服务商（固定为 DNSPod，也可以通过环境变量覆盖）
PROVIDER="${DNS_PROVIDER:-DNSPod}"

# 证书目录
CERT_DIR="/opt/envoy/certs"

# 日志文件
LOG_FILE="/var/log/cert-renewal.log"

# 容器名称
CONTAINER_NAME="envoy-proxy"

# ============= 函数定义 =============

log() { 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 自动检测服务器域名
detect_domain() {
    local detected=""
    
    # 方法1: 从主机名获取（如果设置了 FQDN）
    detected=$(hostname -f 2>/dev/null | grep -oP '[^.]+\.[^.]+$' || echo "")
    if [ -n "$detected" ]; then
        echo "$detected"
        return 0
    fi
    
    # 方法2: 从 /etc/hostname 或配置文件读取
    if [ -f "/etc/envoy-domain.conf" ]; then
        detected=$(cat /etc/envoy-domain.conf | tr -d '[:space:]')
        if [ -n "$detected" ]; then
            echo "$detected"
            return 0
        fi
    fi
    
    # 方法3: 从公网 IP 反查 DNS
    local public_ip=$(curl -s --max-time 3 https://api.ip.sb/ip 2>/dev/null || \
                     curl -s --max-time 3 http://ifconfig.me 2>/dev/null || echo "")
    
    if [ -n "$public_ip" ]; then
        detected=$(dig -x "$public_ip" +short 2>/dev/null | head -n 1 | sed 's/\.$//' | grep -oP '[^.]+\.[^.]+$' || echo "")
        if [ -n "$detected" ]; then
            echo "$detected"
            return 0
        fi
    fi
    
    # 默认值
    echo "qsgl.cn"
}

# 提取 JSON 字段
extract_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null || echo ""
}

# 生成本地 RSA 自签证书（回退方案）
generate_fallback_cert() {
    local domain="$1"
    log "生成本地 RSA 2048 自签证书（回退方案）..."
    
    cat >/tmp/cert-openssl-rsa.cnf <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = *.$domain

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
EOF
    
    openssl genrsa -out "$CERT_DIR/$domain.key" 2048 2>/dev/null
    openssl req -new -x509 -key "$CERT_DIR/$domain.key" -sha256 -days 90 \
        -out "$CERT_DIR/$domain.crt" -config /tmp/cert-openssl-rsa.cnf 2>/dev/null
    
    chmod 644 "$CERT_DIR/$domain.crt"
    chmod 600 "$CERT_DIR/$domain.key"
    
    log "✓ 已生成自签证书: CN=*.$domain (有效期90天)"
}

# ============= 主流程 =============

# 确定域名（优先级：命令行参数 > 环境变量 > 自动检测）
if [ $# -gt 0 ]; then
    DOMAIN="$1"
    log "使用命令行参数指定的域名: $DOMAIN"
elif [ -n "${PROXY_DOMAIN:-}" ]; then
    DOMAIN="$PROXY_DOMAIN"
    log "使用环境变量指定的域名: $DOMAIN"
else
    DOMAIN=$(detect_domain)
    log "自动检测到的域名: $DOMAIN"
fi

log "=========================================="
log "开始申请证书"
log "域名: $DOMAIN (将生成 *.$DOMAIN 泛域名证书)"
log "服务商: $PROVIDER"
log "API: $API_URL"
log "=========================================="

# 调用证书 API
log "正在调用证书 API..."
HTTP_BODY=$(curl -fsS -X POST "$API_URL" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "domain=$DOMAIN" \
    --data-urlencode "provider=$PROVIDER" \
    --connect-timeout 10 \
    --max-time 60) || {
    log "错误: API 调用失败"
    log "尝试生成本地自签证书..."
    generate_fallback_cert "$DOMAIN"
    exit 1
}

log "API 响应长度: $(printf '%s' "$HTTP_BODY" | wc -c) 字节"

# 检查 API 是否返回成功
if printf '%s' "$HTTP_BODY" | tr -d '\r\n\t ' | grep -qi '"success":true'; then
    log "✓ API 返回成功状态"
    SUCCESS=1
else
    log "⚠ API 未返回明确的成功状态"
    SUCCESS=0
fi

# 提取证书和私钥
CERT_CONTENT=$(BODY="$HTTP_BODY" python3 - <<'PY'
import os, json
s = os.environ.get('BODY','')
try:
    d = json.loads(s)
    print(d.get('cert',''))
except Exception as e:
    pass
PY
)

KEY_CONTENT=$(BODY="$HTTP_BODY" python3 - <<'PY'
import os, json
s = os.environ.get('BODY','')
try:
    d = json.loads(s)
    print(d.get('key',''))
except Exception as e:
    pass
PY
)

# 如果 Python 解析失败，尝试简单的正则提取
if [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; then
    log "Python 解析失败，尝试正则提取..."
    CERT_CONTENT=$(printf '%s' "$HTTP_BODY" | tr -d '\r' | sed -n 's/.*"cert":"\(.*\)","key".*/\1/p' | sed 's/\\n/\n/g')
    KEY_CONTENT=$(printf '%s' "$HTTP_BODY" | tr -d '\r' | sed -n 's/.*"key":"\(.*\)".*/\1/p' | sed 's/\\n/\n/g')
fi

# 验证提取结果
if [ -z "$CERT_CONTENT" ] || [ -z "$KEY_CONTENT" ]; then
    log "错误: 无法从 API 响应中提取证书或私钥"
    log "API 响应: $HTTP_BODY"
    log "尝试生成本地自签证书..."
    generate_fallback_cert "$DOMAIN"
    exit 1
fi

# 保存证书和私钥
mkdir -p "$CERT_DIR"
printf '%s\n' "$CERT_CONTENT" > "$CERT_DIR/$DOMAIN.crt"
printf '%s\n' "$KEY_CONTENT" > "$CERT_DIR/$DOMAIN.key"

# 规范化换行符（移除 CRLF）
sed -i 's/\r$//' "$CERT_DIR/$DOMAIN.crt" 2>/dev/null || true
sed -i 's/\r$//' "$CERT_DIR/$DOMAIN.key" 2>/dev/null || true

# 转换私钥为 PKCS#8 格式（兼容性更好）
if openssl pkey -in "$CERT_DIR/$DOMAIN.key" -out "$CERT_DIR/$DOMAIN.key.tmp" -nocrypt >/dev/null 2>&1; then
    mv "$CERT_DIR/$DOMAIN.key.tmp" "$CERT_DIR/$DOMAIN.key"
    log "✓ 私钥已转换为 PKCS#8 格式"
else
    log "⚠ 私钥格式转换失败，保持原格式"
fi

# 设置权限
chmod 644 "$CERT_DIR/$DOMAIN.crt"
chmod 600 "$CERT_DIR/$DOMAIN.key"

log "✓ 证书已保存: $CERT_DIR/$DOMAIN.crt"
log "✓ 私钥已保存: $CERT_DIR/$DOMAIN.key"

# 验证证书
CERT_INFO=$(openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -noout -subject -dates 2>/dev/null || echo "")
if [ -n "$CERT_INFO" ]; then
    log "证书信息:"
    echo "$CERT_INFO" | while read -r line; do log "  $line"; done
fi

# 重启 Envoy 容器
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "正在重启 Envoy 容器..."
    
    if ! docker restart "$CONTAINER_NAME" >/dev/null 2>&1; then
        log "⚠ Envoy 重启命令返回非零"
    fi
    
    sleep 2
    
    # 检查证书加载是否成功
    if docker logs --tail 50 "$CONTAINER_NAME" 2>&1 | grep -Eqi 'Failed to load (incomplete private key|certificate chain|only P-256 ECDSA)'; then
        log "❌ 检测到 Envoy 证书加载失败"
        log "启用应急回退方案..."
        generate_fallback_cert "$DOMAIN"
        docker restart "$CONTAINER_NAME" >/dev/null 2>&1 || true
        sleep 2
    fi
    
    # 最终状态检查
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log "✓ Envoy 容器运行正常"
    else
        log "❌ Envoy 容器未运行，请检查配置"
    fi
else
    log "⚠ 未发现容器 $CONTAINER_NAME"
fi

log "=========================================="
log "证书更新完成！"
log "域名: $DOMAIN"
log "证书: $CERT_DIR/$DOMAIN.crt"
log "私钥: $CERT_DIR/$DOMAIN.key"
log "=========================================="

exit 0
