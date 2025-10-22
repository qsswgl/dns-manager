#!/bin/bash
# 使用 acme.sh 申请 Let's Encrypt P-256 ECDSA 证书

DOMAIN="$1"
DNS_PROVIDER="$2"  # dns_dp (DNSPod) 或 dns_cf (Cloudflare)

# 检查参数
if [ -z "$DOMAIN" ] || [ -z "$DNS_PROVIDER" ]; then
    echo "用法: $0 <domain> <dns_provider>"
    echo "示例: $0 example.com dns_dp"
    exit 1
fi

# 安装 acme.sh (如果未安装)
if [ ! -f ~/.acme.sh/acme.sh ]; then
    curl https://get.acme.sh | sh -s email=admin@$DOMAIN
fi

# 设置 DNSPod API 凭证 (从环境变量读取)
export DP_Id="$DNSPOD_API_KEY_ID"
export DP_Key="$DNSPOD_API_KEY_SECRET"

# 申请 P-256 ECDSA 证书
~/.acme.sh/acme.sh --issue \
    --dns $DNS_PROVIDER \
    -d "$DOMAIN" \
    -d "*.$DOMAIN" \
    --keylength ec-256 \
    --server letsencrypt

# 检查结果
if [ $? -eq 0 ]; then
    echo "✅ 证书申请成功!"
    
    # 输出证书路径
    CERT_DIR=~/.acme.sh/${DOMAIN}_ecc
    echo "证书目录: $CERT_DIR"
    echo "完整链: $CERT_DIR/fullchain.cer"
    echo "私钥: $CERT_DIR/${DOMAIN}.key"
    echo "CA证书: $CERT_DIR/ca.cer"
    
    # 验证证书
    openssl x509 -in "$CERT_DIR/fullchain.cer" -noout -issuer -subject -dates
else
    echo "❌ 证书申请失败"
    exit 1
fi
