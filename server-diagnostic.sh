#!/bin/bash
# SSH服务器诊断脚本 - 检查DNS API服务状态

echo "=== DNS API 服务器诊断报告 ==="
echo "时间: $(date)"
echo "服务器: tx.qsgl.net (43.138.35.183)"
echo "========================================="

# 1. 检查系统信息
echo "🖥️  系统信息:"
echo "   主机名: $(hostname)"
echo "   系统: $(uname -a)"
echo "   当前用户: $(whoami)"
echo "   当前目录: $(pwd)"
echo ""

# 2. 检查Docker服务状态
echo "🐳 Docker服务状态:"
if command -v docker &> /dev/null; then
    echo "   Docker版本: $(docker --version)"
    echo "   Docker状态: $(systemctl is-active docker 2>/dev/null || echo 'Unknown')"
    echo ""
    
    # 检查DNS API容器
    echo "📦 DNS API 容器状态:"
    docker ps -a --filter "name=dnsapi" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # 检查容器日志（最近20行）
    echo "📋 容器日志 (最近20行):"
    if docker ps -q --filter "name=dnsapi" | grep -q .; then
        docker logs --tail 20 dnsapi 2>/dev/null || echo "   无法获取容器日志"
    else
        echo "   DNS API容器未运行"
    fi
    echo ""
else
    echo "   Docker未安装或不在PATH中"
    echo ""
fi

# 3. 检查网络端口
echo "🌐 端口监听状态:"
echo "   HTTP端口 (5074):"
if netstat -tlnp 2>/dev/null | grep -q ":5074"; then
    netstat -tlnp 2>/dev/null | grep ":5074"
else
    echo "     ❌ 端口5074未监听"
fi

echo "   HTTPS端口 (5075):"
if netstat -tlnp 2>/dev/null | grep -q ":5075"; then
    netstat -tlnp 2>/dev/null | grep ":5075"
else
    echo "     ❌ 端口5075未监听"
fi
echo ""

# 4. 检查防火墙状态
echo "🔥 防火墙状态:"
if command -v ufw &> /dev/null; then
    echo "   UFW状态: $(ufw status 2>/dev/null | head -1)"
    echo "   开放端口:"
    ufw status 2>/dev/null | grep -E "5074|5075" || echo "     未找到5074/5075端口规则"
elif command -v firewall-cmd &> /dev/null; then
    echo "   Firewalld状态: $(firewall-cmd --state 2>/dev/null || echo 'inactive')"
    echo "   开放端口:"
    firewall-cmd --list-ports 2>/dev/null | tr ' ' '\n' | grep -E "5074|5075" || echo "     未找到5074/5075端口规则"
else
    echo "   防火墙工具未找到或未配置"
fi
echo ""

# 5. 测试本地连接
echo "🔍 本地连接测试:"
echo "   HTTP (5074):"
if curl -s -m 5 -o /dev/null -w "HTTP: %{http_code} - %{time_total}s\n" http://localhost:5074/api/wan-ip 2>/dev/null; then
    echo "     ✅ HTTP服务正常"
else
    echo "     ❌ HTTP服务无响应"
fi

echo "   HTTPS (5075):"
if curl -k -s -m 5 -o /dev/null -w "HTTPS: %{http_code} - %{time_total}s\n" https://localhost:5075/api/wan-ip 2>/dev/null; then
    echo "     ✅ HTTPS服务正常"
else
    echo "     ❌ HTTPS服务无响应"
fi
echo ""

# 6. 检查SSL证书
echo "🔒 SSL证书检查:"
if [ -d "/app/certificates" ]; then
    echo "   证书目录: /app/certificates"
    ls -la /app/certificates/ 2>/dev/null || echo "     无法访问证书目录"
elif [ -d "./certificates" ]; then
    echo "   证书目录: ./certificates"
    ls -la ./certificates/ 2>/dev/null || echo "     无法访问证书目录"
else
    echo "   ❌ 未找到证书目录"
fi
echo ""

# 7. 检查域名解析
echo "🌍 域名解析检查:"
echo "   tx.qsgl.net 解析:"
if command -v nslookup &> /dev/null; then
    nslookup tx.qsgl.net 2>/dev/null | grep -A2 "Name:" || echo "     域名解析失败"
elif command -v dig &> /dev/null; then
    dig +short tx.qsgl.net 2>/dev/null || echo "     域名解析失败"
else
    echo "     DNS工具未找到"
fi
echo ""

# 8. 系统资源检查
echo "💾 系统资源:"
echo "   内存使用:"
free -h 2>/dev/null | head -2 || echo "     无法获取内存信息"
echo "   磁盘使用:"
df -h . 2>/dev/null | tail -1 || echo "     无法获取磁盘信息"
echo ""

echo "========================================="
echo "🏁 诊断完成! $(date)"
echo "========================================="