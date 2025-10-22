# HTTPS 端口 5075 访问问题解决报告

## 📋 问题描述
无法通过 `https://tx.qsgl.net:5075/` 访问服务

## 🔍 问题排查过程

### 1. 端口映射问题
**发现**: 初始端口映射为 `5075->8443`  
**问题**: 容器内部监听的是 `https://[::]:5075`，不是 8443  
**原因**: 之前的部署命令错误配置了端口映射  

### 2. 镜像版本问题  
**发现**: 容器运行的是旧版本的 latest 镜像（ID: 971fa7d32471）  
**问题**: 该镜像不包含证书管理API功能  
**原因**: latest 标签没有更新到 cert-manager-v3 版本  

## ✅ 解决方案

### 步骤 1: 修正端口映射
```bash
# 从: -p 5075:8443  
# 改为: -p 5075:5075
docker run -d --name dnsapi -p 5074:5074 -p 5075:5075 ...
```

### 步骤 2: 使用正确的镜像版本
```bash
# 使用 cert-manager-v3 版本而不是旧的 latest
docker run ... 43.138.35.183:5000/dnsapi:cert-manager-v3
```

## 🎯 验证结果

### TCP 连接测试
```powershell
Test-NetConnection -ComputerName 43.138.35.183 -Port 5075
# 结果: TcpTestSucceeded = True ✅
```

### HTTPS API 测试
```bash
curl -k https://43.138.35.183:5075/api/cert-manager/status
# 返回: {"success":true,"summary":{...}} ✅
```

### 域名访问测试
```bash
curl -k https://tx.qsgl.net:5075/api/cert-manager/list
# 返回: {"success":true,"count":2,...} ✅
```

## 📊 当前配置

### 容器配置
- **镜像**: `43.138.35.183:5000/dnsapi:cert-manager-v3`
- **容器名**: `dnsapi`
- **端口映射**: 
  - `5074:5074` (HTTP)
  - `5075:5075` (HTTPS)

### 证书配置
- **证书路径**: `/opt/shared-certs/qsgl.net.crt`
- **密钥路径**: `/opt/shared-certs/qsgl.net.key`
- **证书类型**: ECDSA P-256
- **有效期**: 2025-10-20 至 2026-01-18

### 监听端点
- `http://[::]:8080` (遗留端口)
- `http://[::]:5074` ✅
- `https://[::]:5075` ✅

## 🔧 需要注意的问题

### 1. 8080 端口仍在监听
虽然设置了 `ASPNETCORE_URLS=http://+:5074`，但应用仍然监听 8080 端口。
**影响**: 可能造成端口冲突
**建议**: 修改 appsettings.json，移除 8080 端口配置

### 2. latest 标签未同步
本地的 latest 标签(971fa7d32471) 与 cert-manager-v3(7a8e7f22605f) 不一致。
**影响**: 可能部署到错误的版本
**建议**: 更新 latest 标签指向 cert-manager-v3

## 📝 后续建议

### 1. 更新 latest 标签
```bash
docker tag 43.138.35.183:5000/dnsapi:cert-manager-v3 43.138.35.183:5000/dnsapi:latest
docker push 43.138.35.183:5000/dnsapi:latest
```

### 2. 清理旧镜像
```bash
# 删除未使用的镜像
docker images 43.138.35.183:5000/dnsapi --format "{{.ID}} {{.Tag}}" | grep "<none>" | awk '{print $1}' | xargs docker rmi
```

### 3. 配置防火墙规则（如需要）
```bash
# 确保5075端口在云服务器安全组中开放
# 腾讯云控制台 -> 安全组 -> 添加入站规则
# 端口: 5075, 协议: TCP, 来源: 0.0.0.0/0
```

### 4. 配置 HTTPS 自动续签
证书管理服务已内置自动续签功能，每6小时检查一次。
可通过 API 查看状态：
```bash
curl -k https://tx.qsgl.net:5075/api/cert-manager/status
```

## ✅ 问题解决确认

- ✅ TCP 5075 端口连接正常
- ✅ HTTPS 握手成功
- ✅ 证书管理 API 正常响应
- ✅ 域名访问正常
- ✅ 浏览器可以访问

**问题已完全解决！**

---
**报告生成时间**: 2025-10-22  
**解决者**: GitHub Copilot  
**镜像版本**: cert-manager-v3  
**容器ID**: 8555e76ab907
