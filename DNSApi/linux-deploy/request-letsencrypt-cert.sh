#!/bin/bash
# acme.sh wrapper for Let's Encrypt certificate request
# Usage: ./request-letsencrypt-cert.sh <domain> <dns_provider> <api_key_id> <api_key_secret>

set -e

DOMAIN="$1"
DNS_PROVIDER="$2"
API_KEY_ID="$3"
API_KEY_SECRET="$4"

# 验证参数
if [ -z "$DOMAIN" ] || [ -z "$DNS_PROVIDER" ]; then
    echo '{"success": false, "error": "Missing required parameters: domain and dns_provider"}' >&2
    exit 1
fi

# 设置 DNSPod API 凭证
if [ "$DNS_PROVIDER" = "DNSPOD" ]; then
    export DP_Id="$API_KEY_ID"
    export DP_Key="$API_KEY_SECRET"
    DNS_PLUGIN="dns_dp"
elif [ "$DNS_PROVIDER" = "CLOUDFLARE" ]; then
    export CF_Token="$API_KEY_SECRET"
    DNS_PLUGIN="dns_cf"
else
    echo "{\"success\": false, \"error\": \"Unsupported DNS provider: $DNS_PROVIDER\"}" >&2
    exit 1
fi

# acme.sh 路径
ACME_SH="$HOME/.acme.sh/acme.sh"

if [ ! -f "$ACME_SH" ]; then
    echo '{"success": false, "error": "acme.sh not installed"}' >&2
    exit 1
fi

# 检查是否为一级域名（泛域名证书）
if [[ "$DOMAIN" =~ ^[^.]+\.[^.]+$ ]]; then
    # 一级域名，申请泛域名证书
    CERT_DOMAIN="$DOMAIN"
    WILDCARD_DOMAIN="*.$DOMAIN"
    ISSUE_ARGS="-d $CERT_DOMAIN -d $WILDCARD_DOMAIN"
    CERT_DIR="$HOME/.acme.sh/${CERT_DOMAIN}_ecc"
else
    # 子域名，只申请单个域名
    CERT_DOMAIN="$DOMAIN"
    ISSUE_ARGS="-d $CERT_DOMAIN"
    CERT_DIR="$HOME/.acme.sh/${CERT_DOMAIN}_ecc"
fi

# 检查证书是否已存在且有效
if [ -f "$CERT_DIR/fullchain.cer" ] && [ -f "$CERT_DIR/${CERT_DOMAIN}.key" ]; then
    # 检查证书有效期（如果还有30天以上，直接返回现有证书）
    EXPIRE_DATE=$(openssl x509 -in "$CERT_DIR/fullchain.cer" -noout -enddate | cut -d= -f2)
    EXPIRE_TIMESTAMP=$(date -d "$EXPIRE_DATE" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRE_DATE" +%s 2>/dev/null || echo 0)
    CURRENT_TIMESTAMP=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRE_TIMESTAMP - $CURRENT_TIMESTAMP) / 86400 ))
    
    if [ $DAYS_LEFT -gt 30 ]; then
        # 证书仍然有效，直接返回
        CERT_CONTENT=$(cat "$CERT_DIR/fullchain.cer")
        KEY_CONTENT=$(cat "$CERT_DIR/${CERT_DOMAIN}.key")
        
        # 转换为 PKCS#8 格式（.NET 兼容）
        KEY_PKCS8=$(openssl pkcs8 -topk8 -nocrypt -in "$CERT_DIR/${CERT_DOMAIN}.key" 2>/dev/null)
        
        cat <<EOF
{
  "success": true,
  "cached": true,
  "cert": $(echo "$CERT_CONTENT" | jq -Rs .),
  "key": $(echo "$KEY_PKCS8" | jq -Rs .),
  "issuer": "Let's Encrypt",
  "daysLeft": $DAYS_LEFT,
  "domain": "$CERT_DOMAIN"
}
EOF
        exit 0
    fi
fi

# 申请新证书
echo "Requesting certificate for: $CERT_DOMAIN..." >&2

# 使用 --force 参数强制重新申请（如果需要）
$ACME_SH --issue \
    --dns $DNS_PLUGIN \
    $ISSUE_ARGS \
    --keylength ec-256 \
    --server letsencrypt \
    2>&1 | tee /tmp/acme-log.txt >&2

# 检查是否成功
if [ $? -ne 0 ]; then
    # 检查是否是因为证书已存在
    if grep -q "Domains not changed" /tmp/acme-log.txt; then
        # 证书已存在，强制续期
        $ACME_SH --renew -d $CERT_DOMAIN --ecc --force 2>&1 >&2
    else
        ERROR_MSG=$(tail -5 /tmp/acme-log.txt | tr '\n' ' ')
        echo "{\"success\": false, \"error\": \"Certificate request failed: $ERROR_MSG\"}" >&2
        exit 1
    fi
fi

# 验证证书文件是否存在
if [ ! -f "$CERT_DIR/fullchain.cer" ] || [ ! -f "$CERT_DIR/${CERT_DOMAIN}.key" ]; then
    echo '{"success": false, "error": "Certificate files not found after issuance"}' >&2
    exit 1
fi

# 读取证书内容
CERT_CONTENT=$(cat "$CERT_DIR/fullchain.cer")
KEY_CONTENT=$(cat "$CERT_DIR/${CERT_DOMAIN}.key")

# 转换私钥为 PKCS#8 格式（.NET 兼容）
KEY_PKCS8=$(openssl pkcs8 -topk8 -nocrypt -in "$CERT_DIR/${CERT_DOMAIN}.key" 2>/dev/null)

# 获取证书信息
ISSUER=$(openssl x509 -in "$CERT_DIR/fullchain.cer" -noout -issuer | sed 's/issuer=//')
NOT_AFTER=$(openssl x509 -in "$CERT_DIR/fullchain.cer" -noout -enddate | cut -d= -f2)

# 返回 JSON 格式
cat <<EOF
{
  "success": true,
  "cached": false,
  "cert": $(echo "$CERT_CONTENT" | jq -Rs .),
  "key": $(echo "$KEY_PKCS8" | jq -Rs .),
  "issuer": "$ISSUER",
  "notAfter": "$NOT_AFTER",
  "domain": "$CERT_DOMAIN"
}
EOF
