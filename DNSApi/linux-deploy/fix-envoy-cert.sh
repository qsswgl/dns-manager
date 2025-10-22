#!/bin/bash
# 快速修复：更新 Envoy 配置使用 qsgl.cn 证书

set -e

DOMAIN="qsgl.cn"

echo "更新 Envoy 配置，使用域名: $DOMAIN"

# 备份原配置
cp /opt/envoy/envoy.yaml /opt/envoy/envoy.yaml.backup

# 替换证书路径（只替换证书文件名，不替换域名）
sed -i "s|qsgl\.net\.crt|$DOMAIN.crt|g" /opt/envoy/envoy.yaml
sed -i "s|qsgl\.net\.key|$DOMAIN.key|g" /opt/envoy/envoy.yaml

# 替换域名配置（在 domains 数组中）
sed -i "s|\"qsgl\.net\"|\"$DOMAIN\"|g" /opt/envoy/envoy.yaml
sed -i "s|\"\*\.qsgl\.net\"|\"\*\.$DOMAIN\"|g" /opt/envoy/envoy.yaml

echo "配置已更新，证书路径:"
grep "filename:" /opt/envoy/envoy.yaml | head -n 6

# 应用到容器
echo "应用配置到容器..."
docker cp /opt/envoy/envoy.yaml envoy-proxy:/etc/envoy/envoy.yaml

# 重启容器
echo "重启 Envoy..."
docker restart envoy-proxy

sleep 2

# 测试
echo ""
echo "测试 8443 端口..."
curl -skI https://localhost:8443/ -H "Host: www.$DOMAIN" | head -n 10

echo ""
echo "完成！"
