# 阿里云 Envoy 8443 端口 HTTPS 代理配置完成

## ✅ 配置概览

**代理地址**: https://www.qsgl.cn:8443/  
**后端服务器**: https://61.163.200.245  
**绑定域名**: www.qsgl.net  
**证书**: CN=*.qsgl.net (自签名 RSA 2048)  
**容器**: envoy-proxy (端口映射 8443->443)

---

## 📋 当前状态

### ✅ 已完成配置

1. **Envoy 配置** (`/opt/envoy/envoy.yaml`)
   - 监听端口 443（映射到主机 8443）
   - 下游 TLS 使用 `/etc/envoy/certs/qsgl.net.{crt,key}`
   - 上游代理到 `61.163.200.245:443`，SNI=www.qsgl.net
   - 虚拟主机域名: `qsgl.net`, `*.qsgl.net`, `qsgl.net:443`, `*.qsgl.net:443`

2. **证书自动续期脚本** (`/usr/local/bin/renew-qsgl-cert.sh`)
   - API 地址: https://tx.qsgl.net:5075/api/request-cert
   - 自动清理 CRLF、转换私钥为 PKCS#8
   - 失败时自动回退生成本地 RSA 自签证书
   - 日志: `/var/log/cert-renewal.log`

3. **容器配置**
   ```bash
   容器名称: envoy-proxy
   端口映射: 
     - 0.0.0.0:8443 -> 443/tcp (HTTPS)
     - 0.0.0.0:99 -> 99/tcp
     - 0.0.0.0:9902 -> 9901/tcp (Admin)
   卷挂载:
     - /opt/envoy/certs -> /etc/envoy/certs
     - /opt/envoy/envoy.yaml -> /etc/envoy/envoy.yaml
   ```

4. **网络配置**
   - 阿里云安全组已开放 8443 端口（TCP）
   - 防火墙：无需额外配置（使用 Docker 自动管理）

---

## 🧪 验证测试

### 1. 服务器本地测试

```bash
# SSH 登录服务器
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn

# 测试本地 8443 端口
curl -skI https://127.0.0.1:8443/ -H 'Host: www.qsgl.net'

# 测试外网 IP
curl -skI https://123.57.93.200:8443/ -H 'Host: www.qsgl.net'

# 验证证书
echo | openssl s_client -connect 127.0.0.1:8443 -servername www.qsgl.net 2>&1 | grep subject
```

**预期结果**:
```
HTTP/1.1 200 OK
server: envoy
content-type: text/html
subject=CN = *.qsgl.net
```

### 2. 外网测试（Windows PowerShell）

```powershell
# 测试 TCP 连接
Test-NetConnection -ComputerName www.qsgl.cn -Port 8443

# PowerShell 7+ (支持 SkipCertificateCheck)
Invoke-WebRequest -Uri "https://www.qsgl.cn:8443/" `
  -Headers @{"Host"="www.qsgl.net"} `
  -SkipCertificateCheck

# PowerShell 5.1 (忽略证书验证)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Invoke-WebRequest -Uri "https://www.qsgl.cn:8443/" -Headers @{"Host"="www.qsgl.net"}
```

### 3. 浏览器测试

直接访问以下链接（会提示证书警告，点击"继续访问"）:

- https://www.qsgl.cn:8443/
- https://123.57.93.200:8443/

---

## 🔧 常见问题

### Q1: 浏览器显示"不安全"或证书错误
**A**: 这是正常的，因为使用的是自签名证书。点击"高级" -> "继续访问"即可。

**解决方案**（可选）：
- 使用 Let's Encrypt 申请受信任证书
- 将 DNSApi 的 `/api/request-cert` 集成 ACME 协议
- 或使用 acme.sh 在服务器上直接申请

### Q2: 无法从外网访问
**A**: 按以下步骤排查：

1. **检查阿里云安全组**
   ```
   登录阿里云控制台 -> ECS实例 -> 安全组
   确认入站规则包含：
   - 端口: 8443
   - 协议: TCP
   - 源地址: 0.0.0.0/0
   ```

2. **检查本地网络**
   ```powershell
   Test-NetConnection -ComputerName www.qsgl.cn -Port 8443
   ```
   如果 `TcpTestSucceeded: False`，说明本地网络限制了 8443 端口。

3. **检查容器状态**
   ```bash
   docker ps | grep envoy-proxy
   docker logs --tail 50 envoy-proxy
   ```

### Q3: 需要使用 HTTP（非 HTTPS）
**A**: 当前 Envoy 配置仅支持 HTTPS。如需支持 HTTP，需要修改 `envoy.yaml` 添加 HTTP 监听器。

### Q4: 证书过期或需要更新
**A**: 运行续期脚本：
```bash
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn
/usr/local/bin/renew-qsgl-cert.sh
```

查看日志：
```bash
tail -f /var/log/cert-renewal.log
```

---

## 📝 维护指南

### 手动重启 Envoy
```bash
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn "docker restart envoy-proxy"
```

### 查看 Envoy 日志
```bash
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn "docker logs --tail 100 -f envoy-proxy"
```

### 查看证书信息
```bash
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn "openssl x509 -in /opt/envoy/certs/qsgl.net.crt -noout -text"
```

### 更新 Envoy 配置
```bash
# 1. 修改本地 envoy-aliyun.yaml
# 2. 上传到服务器
scp -i "C:\KEY\www.qsgl.cn_id_ed25519" envoy-aliyun.yaml root@www.qsgl.cn:/opt/envoy/envoy.yaml

# 3. 应用到容器
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn "docker cp /opt/envoy/envoy.yaml envoy-proxy:/etc/envoy/envoy.yaml; docker restart envoy-proxy"
```

### 设置证书自动续期（Cron）
```bash
ssh -i "C:\KEY\www.qsgl.cn_id_ed25519" root@www.qsgl.cn

# 编辑 crontab
crontab -e

# 添加以下行（每天凌晨 2 点执行）
0 2 * * * /usr/local/bin/renew-qsgl-cert.sh >> /var/log/cert-renewal.log 2>&1
```

---

## 🎯 性能优化建议

### 1. 启用 HTTP/2
Envoy 已默认支持 HTTP/2（ALPN 协商），无需额外配置。

### 2. 调整超时时间
如果后端响应慢，可在 `envoy.yaml` 中调整：
```yaml
clusters:
- name: qsgl_backend
  connect_timeout: 30s  # 可根据需要调整
```

### 3. 启用访问日志
在 `envoy.yaml` 中添加：
```yaml
http_filters:
- name: envoy.filters.http.router
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
access_log:
- name: envoy.access_loggers.file
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
    path: /var/log/envoy/access.log
```

---

## 🔐 安全建议

1. **使用受信任证书**
   - 建议申请 Let's Encrypt 免费证书
   - 浏览器不会显示警告

2. **限制访问来源**
   - 如果只需特定 IP 访问，修改阿里云安全组规则
   - 将 `0.0.0.0/0` 改为具体 IP 段

3. **启用 HSTS**
   - 在后端服务器或 Envoy 响应头添加 `Strict-Transport-Security`

4. **定期更新**
   - 定期更新 Envoy 镜像到最新版本
   - 关注安全公告

---

## 📊 监控指标

### Envoy Admin 接口
访问: http://www.qsgl.cn:9902/

**常用端点**:
- `/stats` - 统计信息
- `/clusters` - 集群状态
- `/listeners` - 监听器状态
- `/config_dump` - 完整配置

**示例**:
```bash
# 查看 443 监听器统计
curl -s http://www.qsgl.cn:9902/stats | grep listener.0.0.0.0_443

# 查看后端连接状态
curl -s http://www.qsgl.cn:9902/clusters | grep qsgl_backend
```

---

## ✅ 测试清单

- [x] TCP 端口 8443 可从外网访问
- [x] HTTPS 握手成功（证书 CN=*.qsgl.net）
- [x] HTTP 状态码 200 OK
- [x] 服务器响应头包含 `server: envoy`
- [x] 后端代理到 61.163.200.245（ASP.NET）
- [x] 域名 www.qsgl.net 绑定正常
- [x] 证书自动续期脚本可执行
- [x] Envoy 容器稳定运行

---

## 📞 技术支持

如遇问题，请提供以下信息：

1. **错误截图或错误信息**
2. **测试命令及输出**
   ```bash
   Test-NetConnection -ComputerName www.qsgl.cn -Port 8443
   ```
3. **服务器日志**
   ```bash
   docker logs --tail 100 envoy-proxy
   tail -50 /var/log/cert-renewal.log
   ```

---

**最后更新**: 2025-10-19  
**维护人员**: GitHub Copilot  
**相关文档**: 
- `envoy-aliyun.yaml` - Envoy 配置文件
- `renew-qsgl-cert.form.sh` - 证书续期脚本
- `UBUNTU-FIX-FINAL.md` - 历史问题记录
