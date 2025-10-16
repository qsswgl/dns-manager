# 使用.NET 8运行时镜像
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# 设置工作目录
WORKDIR /app

# 创建必要的目录
RUN mkdir -p /app/certs/active /app/certs/logs /app/certificates

# 暴露端口
EXPOSE 5074 5075

# 复制发布的应用
COPY publish/ .

# 复制证书文件
COPY certificates/qsgl.net.pfx /app/certificates/

# 设置环境变量
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:5074;https://+:5075

# 设置权限
RUN chmod +x ./DNSApi && chmod 644 /app/certificates/qsgl.net.pfx

# 启动应用
ENTRYPOINT ["./DNSApi"]