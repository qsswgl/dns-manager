@echo off
echo 🚀 DNS API 镜像推送到私有仓库

REM 检查Docker是否运行
echo 🔍 检查Docker状态...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker 未运行，请先启动 Docker Desktop
    pause
    exit /b 1
)

REM 测试与私有仓库的连接
echo 🌐 测试与私有仓库连接...
docker pull alpine:latest >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ 网络连接问题
    pause
    exit /b 1
)

REM 配置私有仓库为不安全仓库（如需要）
echo 🔧 配置私有仓库访问...
echo 注意：如果遇到HTTPS错误，需要在Docker Desktop设置中添加不安全仓库：
echo 43.138.35.183:5000

REM 构建镜像
echo 📦 发布应用程序...
dotnet publish DNSApi.csproj -c Docker -o publish

REM 构建Docker镜像
echo 🐳 构建 Docker 镜像...
docker build -t dnsapi:latest .

REM 标记镜像
echo 🏷️ 标记镜像...
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:latest
docker tag dnsapi:latest 43.138.35.183:5000/dnsapi:v1.0

REM 推送镜像
echo 📤 推送镜像到 43.138.35.183:5000...
docker push 43.138.35.183:5000/dnsapi:latest
if %ERRORLEVEL% neq 0 (
    echo ❌ 推送 latest 标签失败
    pause
    exit /b 1
)

docker push 43.138.35.183:5000/dnsapi:v1.0
if %ERRORLEVEL% neq 0 (
    echo ❌ 推送 v1.0 标签失败
    pause
    exit /b 1
)

REM 显示成功信息
echo ✅ 镜像推送成功！
echo.
echo 📋 镜像信息：
echo   - 43.138.35.183:5000/dnsapi:latest
echo   - 43.138.35.183:5000/dnsapi:v1.0
echo.
echo 🎯 在目标服务器上运行：
echo   docker pull 43.138.35.183:5000/dnsapi:latest
echo   docker run -d -p 5074:5074 -p 5075:5075 --name dnsapi 43.138.35.183:5000/dnsapi:latest
echo.
echo 🔧 或使用docker-compose：
echo   docker-compose up -d

pause