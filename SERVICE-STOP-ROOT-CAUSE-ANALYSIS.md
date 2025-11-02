# DNS API 服务频繁停止问题根因分析

## 📋 问题描述

**现象**: https://tx.qsgl.net:5075 经常无法访问，服务停止运行

**发生时间**: 2025年10月24日发现，容器已停止 22 小时

**影响范围**: 
- HTTPS API 服务完全不可用
- DNS 动态更新功能中断
- 证书管理功能无法访问

---

## 🔍 根因分析

### 1. **直接原因：容器未配置自动重启策略**

**发现过程**：
```bash
# 检查容器状态
docker ps -a | grep dnsapi
# 输出: Exited (0) 22 hours ago

# 检查重启策略
docker inspect dnsapi --format='{{.HostConfig.RestartPolicy.Name}}'
# 输出: no
```

**问题说明**：
- Docker 容器的重启策略设置为 `no`
- 这意味着容器停止后**不会自动重启**
- 任何导致容器停止的事件（如系统重启、手动停止、应用崩溃等）都会导致服务长时间不可用

### 2. **容器停止的原因**

**日志分析**：
```
最后一条日志: info: Microsoft.Hosting.Lifetime[0]
      Application is shutting down...
```

**可能的停止原因**：
1. ✅ **正常关闭** - 日志显示是正常的应用关闭流程
2. 可能触发因素：
   - 系统维护或重启
   - 手动 `docker stop` 命令
   - 资源不足触发 OOM Killer
   - Docker 服务重启
   - 系统更新

### 3. **为什么之前没有问题？**

查看历史部署命令，发现问题：

**之前的部署命令（缺少重启策略）**：
```bash
docker run -d \
  --name dnsapi \
  -p 5074:5074 \
  -p 5075:5075 \
  -v /opt/shared-certs:/opt/shared-certs:ro \
  -v /etc/hosts:/etc/hosts:ro \
  43.138.35.183:5000/dnsapi:cert-manager-v3
```

**应该使用的命令（包含重启策略）**：
```bash
docker run -d \
  --name dnsapi \
  --restart=unless-stopped \  # ← 缺少这一行！
  -p 5074:5074 \
  -p 5075:5075 \
  -v /opt/shared-certs:/opt/shared-certs:ro \
  -v /etc/hosts:/etc/hosts:ro \
  43.138.35.183:5000/dnsapi:cert-manager-v3
```

---

## ✅ 解决方案

### 立即修复（已执行）

```bash
# 1. 启动容器
docker start dnsapi

# 2. 设置自动重启策略
docker update --restart=unless-stopped dnsapi

# 3. 验证
docker ps | grep dnsapi
docker inspect dnsapi --format='{{.HostConfig.RestartPolicy.Name}}'
```

**执行结果**：
- ✅ 容器已启动
- ✅ 重启策略已设置为 `unless-stopped`
- ✅ HTTPS 服务恢复正常

### Docker 重启策略说明

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| `no` | ❌ 不自动重启 | 仅测试环境 |
| `always` | 始终重启 | 需要永远运行的服务 |
| `unless-stopped` | 除非手动停止，否则总是重启 | **✅ 推荐用于生产环境** |
| `on-failure` | 仅在失败时重启 | 临时任务 |

**选择 `unless-stopped` 的原因**：
- 系统重启后自动启动
- 意外崩溃后自动恢复
- 允许手动停止维护（不会自动重启）
- 最适合生产环境的 Web 服务

---

## 🛡️ 预防措施

### 1. **部署检查清单**

创建标准部署流程，确保每次部署都包含：

```bash
# 部署检查清单
□ 指定 --restart=unless-stopped
□ 配置健康检查（可选）
□ 设置资源限制（可选）
□ 挂载必要的卷
□ 配置正确的端口映射
□ 验证容器启动成功
```

### 2. **添加健康检查（建议）**

修改 Dockerfile 或运行命令：

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5074/api/health || exit 1
```

或在运行时添加：
```bash
docker run -d \
  --name dnsapi \
  --restart=unless-stopped \
  --health-cmd='curl -f http://localhost:5074/api/health || exit 1' \
  --health-interval=30s \
  --health-timeout=3s \
  --health-retries=3 \
  ...
```

### 3. **监控和告警**

建议配置以下监控：

1. **服务可用性监控**
   - 每 5 分钟检查 https://tx.qsgl.net:5075/api/health
   - 失败时发送告警

2. **容器状态监控**
   ```bash
   # 定时任务检查容器状态
   */5 * * * * docker ps | grep dnsapi || /path/to/alert.sh
   ```

3. **资源使用监控**
   ```bash
   # 检查内存和 CPU 使用
   docker stats --no-stream dnsapi
   ```

### 4. **自动化诊断脚本**

已创建 `diagnose-and-fix-dnsapi.ps1` 脚本，可以：
- 自动检测服务状态
- 诊断常见问题
- 自动修复（使用 `-AutoFix` 参数）

**使用方法**：
```powershell
# 仅诊断
.\diagnose-and-fix-dnsapi.ps1

# 自动修复
.\diagnose-and-fix-dnsapi.ps1 -AutoFix
```

---

## 📊 系统状态检查

### 当前系统资源（正常）

```
内存:
  total: 3.6Gi
  used:  1.1Gi
  free:  458Mi
  available: 2.5Gi

磁盘:
  总容量: 69G
  已使用: 17G
  可用:   50G
  使用率: 26%
```

**结论**: 系统资源充足，不是停止的原因

### 容器配置

```yaml
容器名称: dnsapi
镜像: 43.138.35.183:5000/dnsapi:cert-manager-v3
端口映射:
  - 5074:5074 (HTTP)
  - 5075:5075 (HTTPS)
挂载卷:
  - /opt/shared-certs:/opt/shared-certs:ro
  - /etc/hosts:/etc/hosts:ro
重启策略: unless-stopped ✅
```

---

## 🔄 未来优化建议

### 1. **使用 Docker Compose**

创建 `docker-compose.yml`:

```yaml
version: '3.8'

services:
  dnsapi:
    image: 43.138.35.183:5000/dnsapi:cert-manager-v3
    container_name: dnsapi
    restart: unless-stopped
    ports:
      - "5074:5074"
      - "5075:5075"
    volumes:
      - /opt/shared-certs:/opt/shared-certs:ro
      - /etc/hosts:/etc/hosts:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5074/api/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**优点**：
- 配置统一管理
- 易于版本控制
- 简化部署流程

### 2. **日志管理**

当前日志可能无限增长，建议配置：

```bash
docker update \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  dnsapi
```

### 3. **资源限制（可选）**

防止资源耗尽：

```bash
docker update \
  --memory=2g \
  --memory-swap=2g \
  --cpus=2 \
  dnsapi
```

---

## 📝 总结

### 问题根源
- **根本原因**: Docker 容器未配置自动重启策略
- **触发因素**: 容器因某种原因停止（正常关闭）
- **影响时长**: 22 小时无人发现

### 已修复
- ✅ 容器已重启
- ✅ 设置 `--restart=unless-stopped` 策略
- ✅ 服务恢复正常

### 预防措施
- ✅ 创建自动诊断脚本
- ✅ 文档化标准部署流程
- 建议: 添加监控告警
- 建议: 使用 Docker Compose

### 经验教训
1. **所有生产容器必须配置重启策略**
2. 部署后验证重启策略是否正确
3. 需要监控和告警机制
4. 文档化运维流程很重要

---

## 🔗 相关文件

- 诊断脚本: `K:\DNS\diagnose-and-fix-dnsapi.ps1`
- SSH 密钥: `C:\Key\tx.qsgl.net_id_ed25519`
- 服务地址: https://tx.qsgl.net:5075
- 服务器IP: 43.138.35.183

## 📅 更新日志

- **2025-10-24**: 发现问题并修复，创建诊断脚本和此文档
