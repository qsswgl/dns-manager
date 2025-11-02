# DNS API 服务快速修复指南

## 🚨 快速诊断命令

```powershell
# 1. 测试服务是否可访问
Test-NetConnection -ComputerName 43.138.35.183 -Port 5075

# 2. 使用诊断脚本（推荐）
.\diagnose-and-fix-dnsapi.ps1           # 仅诊断
.\diagnose-and-fix-dnsapi.ps1 -AutoFix  # 自动修复

# 3. 手动检查容器状态
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker ps -a | grep dnsapi"
```

## ⚡ 快速修复命令

### 问题1: 容器已停止

```bash
# 启动容器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker start dnsapi"

# 验证
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker ps | grep dnsapi"
```

### 问题2: 未配置自动重启

```bash
# 设置自动重启策略
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker update --restart=unless-stopped dnsapi"

# 验证
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker inspect dnsapi --format='{{.HostConfig.RestartPolicy.Name}}'"
```

### 问题3: 容器运行但服务无响应

```bash
# 重启容器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker restart dnsapi"

# 查看实时日志
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs -f dnsapi"
```

## 🔍 常用诊断命令

### 查看容器日志
```bash
# 最后 50 行
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs --tail 50 dnsapi"

# 实时跟踪
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs -f --tail 100 dnsapi"

# 查看特定时间段
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker logs --since 1h dnsapi"
```

### 查看容器详细信息
```bash
# 完整配置
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker inspect dnsapi"

# 仅查看状态
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker inspect dnsapi --format='{{.State.Status}}'"

# 查看重启次数
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker inspect dnsapi --format='{{.RestartCount}}'"
```

### 检查系统资源
```bash
# 内存使用
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "free -h"

# 磁盘空间
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "df -h"

# 容器资源使用
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker stats --no-stream dnsapi"
```

## 🧪 测试命令

### 测试 HTTP 端点
```powershell
# PowerShell
curl.exe http://43.138.35.183:5074/api/health

# 或
Invoke-RestMethod -Uri "http://43.138.35.183:5074/api/health"
```

### 测试 HTTPS 端点
```powershell
# 使用 curl（忽略证书验证）
curl.exe -k https://tx.qsgl.net:5075/api/health

# 测试证书管理 API
curl.exe -k https://tx.qsgl.net:5075/api/cert-manager/status

# 测试 DNS 更新 API
curl.exe -k "https://tx.qsgl.net:5075/api/updatehosts?domain=qsgl.net&sub_domain=test"
```

## 🔄 重新部署（慎用）

### 完全重新部署
```bash
# 登录服务器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183

# 停止并删除旧容器
docker stop dnsapi
docker rm dnsapi

# 拉取最新镜像
docker pull 43.138.35.183:5000/dnsapi:cert-manager-v3

# 重新运行（包含所有正确配置）
docker run -d \
  --name dnsapi \
  --restart=unless-stopped \
  -p 5074:5074 \
  -p 5075:5075 \
  -v /opt/shared-certs:/opt/shared-certs:ro \
  -v /etc/hosts:/etc/hosts:ro \
  43.138.35.183:5000/dnsapi:cert-manager-v3

# 验证
docker ps | grep dnsapi
docker logs -f dnsapi
```

## 📋 维护操作

### 更新容器镜像
```bash
# 1. 拉取新镜像
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker pull 43.138.35.183:5000/dnsapi:cert-manager-v3"

# 2. 重新创建容器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker stop dnsapi && docker rm dnsapi"

# 3. 运行新容器（使用上面的 docker run 命令）
```

### 查看证书状态
```bash
# 检查证书文件
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "ls -lh /opt/shared-certs/"

# 查看证书详情
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "openssl x509 -in /opt/shared-certs/qsgl.net.crt -noout -dates -subject"
```

## 🔒 SSH 密钥信息

```
密钥路径: C:\Key\tx.qsgl.net_id_ed25519
服务器IP: 43.138.35.183
域名: tx.qsgl.net
用户: root
```

### SSH 连接
```powershell
# Windows PowerShell
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183

# 一次性执行命令
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "命令"
```

## 🌐 服务端点

| 类型 | URL | 说明 |
|------|-----|------|
| HTTP | http://tx.qsgl.net:5074 | HTTP 主页 |
| HTTPS | https://tx.qsgl.net:5075 | HTTPS 主页 |
| API 健康检查 | https://tx.qsgl.net:5075/api/health | 服务健康状态 |
| Swagger 文档 | https://tx.qsgl.net:5075/swagger | API 文档 |
| DNS 更新 | https://tx.qsgl.net:5075/api/updatehosts | DNS 更新接口 |
| 证书管理 | https://tx.qsgl.net:5075/api/cert-manager/status | 证书状态 |

## 📞 故障排查流程

1. **确认问题**
   - 测试端口连通性
   - 尝试访问服务端点

2. **诊断**
   - 运行诊断脚本: `.\diagnose-and-fix-dnsapi.ps1`
   - 或手动检查容器状态

3. **修复**
   - 自动修复: `.\diagnose-and-fix-dnsapi.ps1 -AutoFix`
   - 或根据诊断结果执行相应命令

4. **验证**
   - 检查容器状态
   - 测试服务端点
   - 查看日志确认无错误

5. **预防**
   - 确认重启策略已设置
   - 考虑添加监控告警

## 💡 最佳实践

1. ✅ 始终使用 `--restart=unless-stopped`
2. ✅ 定期查看容器日志
3. ✅ 监控服务可用性
4. ✅ 保持镜像更新
5. ✅ 备份重要配置和数据
6. ✅ 文档化所有操作

## 🆘 紧急联系

如果上述方法都无法解决问题：

1. 查看完整分析文档: `SERVICE-STOP-ROOT-CAUSE-ANALYSIS.md`
2. 检查系统日志: `ssh -i ... "journalctl -xe"`
3. 检查 Docker 服务: `ssh -i ... "systemctl status docker"`
4. 考虑重启 Docker 服务: `ssh -i ... "systemctl restart docker"`

---

**最后更新**: 2025-10-24
**文档版本**: 1.0
