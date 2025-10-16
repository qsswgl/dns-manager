# DNS API Linux 部署指令

## 📋 部署步骤

### 1. 上传文件到 Linux 服务器
```bash
# 使用 scp 上传整个目录
scp -r linux-deploy/* user@server:/opt/dnsapi/

# 或使用 rsync
rsync -avz linux-deploy/ user@server:/opt/dnsapi/
```

### 2. 设置权限
```bash
sudo chmod +x /opt/dnsapi/DNSApi
sudo chmod +x /opt/dnsapi/start.sh
sudo chown -R www-data:www-data /opt/dnsapi
```

### 3. 创建必要目录
```bash
sudo mkdir -p /opt/dnsapi/certs
sudo mkdir -p /opt/dnsapi/logs
sudo chown -R www-data:www-data /opt/dnsapi
```

### 4. 安装为系统服务（推荐）
```bash
# 复制服务文件
sudo cp /opt/dnsapi/dnsapi.service /etc/systemd/system/

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用自启动
sudo systemctl enable dnsapi

# 启动服务
sudo systemctl start dnsapi
```

### 5. 直接运行（测试模式）
```bash
cd /opt/dnsapi
./start.sh
```

### 6. 查看服务状态
```bash
# 查看服务状态
sudo systemctl status dnsapi

# 查看实时日志
sudo journalctl -u dnsapi -f

# 查看近期日志
sudo journalctl -u dnsapi --since "1 hour ago"
```

### 7. 防火墙配置
```bash
# Ubuntu/Debian
sudo ufw allow 5074/tcp
sudo ufw allow 5075/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5074/tcp
sudo firewall-cmd --permanent --add-port=5075/tcp
sudo firewall-cmd --reload
```

### 8. 测试访问
```bash
# 测试HTTP
curl http://localhost:5074/api/wan-ip

# 测试HTTPS（如果配置了证书）
curl -k https://localhost:5075/api/wan-ip

# 在浏览器中访问
# http://server-ip:5074
```

### 9. 服务管理命令
```bash
# 启动服务
sudo systemctl start dnsapi

# 停止服务  
sudo systemctl stop dnsapi

# 重启服务
sudo systemctl restart dnsapi

# 禁用自启动
sudo systemctl disable dnsapi

# 查看配置
sudo systemctl show dnsapi
```

### 10. 故障排除
```bash
# 检查端口占用
sudo netstat -tlnp | grep 507

# 检查进程
ps aux | grep DNSApi

# 检查文件权限
ls -la /opt/dnsapi/

# 检查SELinux（如适用）
sestatus
sudo setsebool -P httpd_can_network_connect 1
```

## 🔧 配置文件

- **appsettings.json**: 应用程序配置
- **appsettings.Production.json**: 生产环境配置  

## 📂 目录结构
```
/opt/dnsapi/
├── DNSApi              # 主程序
├── start.sh           # 启动脚本
├── dnsapi.service     # 系统服务文件
├── appsettings.json   # 配置文件
├── wwwroot/           # 静态文件
├── certs/             # SSL证书目录
└── logs/              # 日志目录
```

## 🌐 访问地址

- **主页**: http://server-ip:5074
- **API文档**: http://server-ip:5074/swagger  
- **WAN IP**: http://server-ip:5074/api/wan-ip

## ⚠️ 注意事项

1. **依赖**: 应用程序是自包含的，不需要安装.NET运行时
2. **权限**: 需要root权限修改/etc/hosts文件
3. **证书**: HTTPS需要有效的SSL证书
4. **防火墙**: 确保端口5074和5075开放
5. **DNS**: 确保服务器可以访问外部DNS服务