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

# 设置环境变量（不覆盖 URLS，监听由应用内 Kestrel 配置完成）
ENV ASPNETCORE_ENVIRONMENT=Production

# 设置权限（证书可选存在，若存在则设为 644）
RUN if [ -f /app/certificates/qsgl.net.pfx ]; then chmod 644 /app/certificates/qsgl.net.pfx; fi

# 启动应用（使用框架依赖 DLL 运行）
ENTRYPOINT ["dotnet", "DNSApi.dll"]