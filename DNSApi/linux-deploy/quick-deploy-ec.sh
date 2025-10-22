#!/bin/bash
# EC证书快速部署脚本
cd /opt/envoy/certs

echo "=== 获取 EC 证书 ==="
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'domain=qsgl.cn' \
  --data-urlencode 'provider=DNSPOD' | \
python3 -c "import sys,json; d=json.load(sys.stdin); open('qsgl.cn.crt','w').write(d['cert']); open('qsgl.cn.key','w').write(d['key']); print('✓ 证书已保存'); print('证书类型: EC (ECDSA)')"

echo ""
echo "=== 检查证书类型 ==="
openssl x509 -in qsgl.cn.crt -noout -subject
echo "私钥类型:"
head -1 qsgl.cn.key

echo ""
echo "=== 验证 EC 私钥 ==="
if openssl ec -in qsgl.cn.key -noout -check 2>/dev/null; then
    echo "✓ EC 私钥格式正确"
else
    echo "❌ 私钥验证失败"
    exit 1
fi

echo ""
echo "=== 备份 RSA 证书 ==="
cp qsgl.cn.crt qsgl.cn.crt.rsa 2>/dev/null || true
cp qsgl.cn.key qsgl.cn.key.rsa 2>/dev/null || true
echo "✓ RSA证书已备份为 .rsa"

echo ""
echo "=== 设置权限 ==="
chmod 644 qsgl.cn.crt
chmod 600 qsgl.cn.key
ls -lh qsgl.cn.{crt,key}

echo ""
echo "=== 重启 Envoy ==="
docker restart envoy-proxy
sleep 6

echo ""
echo "=== 检查容器 ==="
if docker ps | grep -q envoy-proxy; then
    echo "✓ Envoy 运行中"
else
    echo "❌ Envoy 未运行"
    docker logs envoy-proxy --tail 20
    exit 1
fi

echo ""
echo "=== Envoy 日志 ==="
docker logs envoy-proxy --tail 15

echo ""
echo "=== 测试 8443 端口 ==="
sleep 2
RESULT=$(curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' 2>&1)
echo "$RESULT" | head -5

if echo "$RESULT" | grep -q '200 OK'; then
    echo ""
    echo "🎉 成功! EC 证书正常工作!"
    echo "✅ Envoy v1.31 支持 ECDSA 证书"
else
    echo ""
    echo "❌ 测试失败，恢复 RSA 证书..."
    cp qsgl.cn.crt.rsa qsgl.cn.crt
    cp qsgl.cn.key.rsa qsgl.cn.key
    docker restart envoy-proxy
    echo "RSA 证书已恢复"
fi
