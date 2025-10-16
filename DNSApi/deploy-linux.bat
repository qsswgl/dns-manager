@echo off
echo 🚀 创建 Linux 部署包

REM 清理发布目录
if exist linux-deploy rmdir /s /q linux-deploy

REM 发布自包含应用程序
echo 📦 发布 .NET 9 Linux 应用程序...
dotnet publish DNSApi.csproj -c Docker -o linux-deploy

REM 创建启动脚本
echo 📝 创建启动脚本...
echo #!/bin/bash > linux-deploy\start.sh
echo echo "启动 DNS API 服务..." >> linux-deploy\start.sh
echo export ASPNETCORE_URLS="http://0.0.0.0:5074;https://0.0.0.0:5075" >> linux-deploy\start.sh
echo chmod +x ./DNSApi >> linux-deploy\start.sh
echo ./DNSApi >> linux-deploy\start.sh

REM 创建系统服务文件
echo 📝 创建系统服务文件...
(
echo [Unit]
echo Description=DNS API Service
echo After=network.target
echo.
echo [Service]
echo Type=simple
echo User=www-data
echo WorkingDirectory=/opt/dnsapi
echo ExecStart=/opt/dnsapi/DNSApi
echo Environment=ASPNETCORE_URLS=http://0.0.0.0:5074;https://0.0.0.0:5075
echo Restart=always
echo.
echo [Install]
echo WantedBy=multi-user.target
) > linux-deploy\dnsapi.service

REM 创建部署指令
echo 📝 创建部署指令...
(
echo # DNS API Linux 部署指令
echo.
echo ## 1. 上传文件到 Linux 服务器
echo # scp -r linux-deploy/* user@server:/opt/dnsapi/
echo.
echo ## 2. 设置权限
echo # sudo chmod +x /opt/dnsapi/DNSApi
echo # sudo chmod +x /opt/dnsapi/start.sh
echo.
echo ## 3. 安装为系统服务（可选）
echo # sudo cp /opt/dnsapi/dnsapi.service /etc/systemd/system/
echo # sudo systemctl enable dnsapi
echo # sudo systemctl start dnsapi
echo.
echo ## 4. 直接运行（测试）
echo # cd /opt/dnsapi
echo # ./start.sh
echo.
echo ## 5. 查看服务状态
echo # sudo systemctl status dnsapi
echo # sudo journalctl -u dnsapi -f
echo.
echo ## 6. 防火墙配置
echo # sudo ufw allow 5074/tcp
echo # sudo ufw allow 5075/tcp
) > linux-deploy\DEPLOY.md

echo ✅ Linux 部署包创建完成！
echo 📁 位置: linux-deploy\
echo 📖 查看部署说明: linux-deploy\DEPLOY.md
pause