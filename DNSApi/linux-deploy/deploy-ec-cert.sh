#!/bin/bash
# EC证书部署脚本
set -e

cd /opt/envoy/certs

echo "=== 1. 获取 EC 证书 ==="
curl -fsS -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H 'Content-Type: application/json' \
  -d '{"domain": "qsgl.cn", "provider": "DNSPOD"}' > cert-response.json
echo "✓ API 调用成功"

echo ""
echo "=== 2. 查看 API 响应 ==="
echo "API 响应内容 (前500字符):"
head -c 500 cert-response.json
echo ""
echo ""

echo "=== 3. 提取证书和私钥 ==="
python3 << 'EOF'
import json
try:
    with open('cert-response.json') as f:
        content = f.read()
        print(f"文件大小: {len(content)} 字节")
        data = json.loads(content)
        print(f"JSON 键: {list(data.keys())}")
        
    # 尝试不同的键名
    cert_key = 'certificate' if 'certificate' in data else 'cert'
    key_key = 'privateKey' if 'privateKey' in data else 'key'
    
    if cert_key in data and key_key in data:
        with open('qsgl.cn.crt', 'w') as f:
            f.write(data[cert_key])
        with open('qsgl.cn.key', 'w') as f:
            f.write(data[key_key])
        print('✓ 证书已保存: qsgl.cn.crt')
        print('✓ 私钥已保存: qsgl.cn.key')
    else:
        print(f"❌ 未找到证书数据，可用的键: {list(data.keys())}")
        print(f"完整响应: {content[:1000]}")
        exit(1)
except Exception as e:
    print(f"❌ 错误: {e}")
    exit(1)
EOF

echo ""
echo "=== 4. 检查证书信息 ==="
openssl x509 -in qsgl.cn.crt -noout -subject
echo "私钥类型:"
head -1 qsgl.cn.key

echo ""
echo "=== 5. 验证 EC 私钥 ==="
if openssl ec -in qsgl.cn.key -noout -check 2>/dev/null; then
    echo "✓ EC 私钥格式正确"
else
    echo "❌ 私钥验证失败"
    exit 1
fi

echo ""
echo "=== 6. 设置权限 ==="
chmod 644 qsgl.cn.crt
chmod 600 qsgl.cn.key
echo "✓ 权限设置完成"

echo ""
echo "=== 7. 备份 RSA 证书 ==="
if [ -f qsgl.cn.key.rsa-backup ]; then
    echo "RSA 备份已存在"
else
    cp qsgl.cn.crt qsgl.cn.crt.rsa-backup 2>/dev/null && echo "✓ 已备份 RSA 证书"
    cp qsgl.cn.key qsgl.cn.key.rsa-backup 2>/dev/null && echo "✓ 已备份 RSA 私钥"
fi

echo ""
echo "=== 8. 重启 Envoy ==="
docker restart envoy-proxy
echo "等待 Envoy 启动 (5秒)..."
sleep 5

echo ""
echo "=== 9. 检查容器状态 ==="
if docker ps | grep -q envoy-proxy; then
    echo "✓ Envoy 容器运行中"
    docker ps | grep envoy-proxy
else
    echo "❌ Envoy 容器未运行，查看日志:"
    docker logs envoy-proxy --tail 30
    exit 1
fi

echo ""
echo "=== 10. 检查 Envoy 日志 (最近20行) ==="
docker logs envoy-proxy --tail 20

echo ""
echo "=== 11. 测试本地 8443 端口 ==="
sleep 2
echo "执行: curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn'"
RESPONSE=$(curl -skI https://localhost:8443/ -H 'Host: www.qsgl.cn' --connect-timeout 5 2>&1)

echo "$RESPONSE" | head -10

if echo "$RESPONSE" | grep -q '200 OK'; then
    echo ""
    echo "✅ 测试成功! EC 证书工作正常!"
    echo "🎉 Envoy v1.31 支持 EC (ECDSA) 证书"
else
    echo ""
    echo "❌ 测试失败，可能 Envoy 不支持 EC 证书"
    echo "完整响应:"
    echo "$RESPONSE"
    echo ""
    echo "尝试恢复 RSA 证书..."
    cp qsgl.cn.crt.rsa-backup qsgl.cn.crt
    cp qsgl.cn.key.rsa-backup qsgl.cn.key
    docker restart envoy-proxy
    sleep 3
    echo "RSA 证书已恢复"
fi

echo ""
echo "=== 证书详情 ==="
openssl x509 -in qsgl.cn.crt -noout -text | head -20
