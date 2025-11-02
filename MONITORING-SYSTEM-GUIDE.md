# DNS API 监控系统配置指南

## 📋 系统概述

这是一个完整的 DNS API 服务监控解决方案，包含：
- **Windows 客户端监控**: 定期检查服务可用性
- **服务器端自检**: 本地健康检查和自动修复
- **Docker 健康检查**: 容器级别的健康监控
- **多种告警方式**: 文件日志、邮件、Webhook

---

## 🏗️ 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    监控系统架构                               │
└─────────────────────────────────────────────────────────────┘

Windows 客户端                 服务器端
┌──────────────┐             ┌──────────────────────────┐
│              │             │                          │
│ monitor-     │   SSH       │  check-dnsapi.sh        │
│ dnsapi-      ├────────────→│  (Cron 每 5 分钟)       │
│ service.ps1  │             │                          │
│              │             │  ┌──────────────────┐   │
│ (任务计划    │             │  │  Docker          │   │
│  每 5 分钟)  │             │  │  Healthcheck     │   │
│              │             │  │  (每 30 秒)      │   │
└──────────────┘             │  └──────────────────┘   │
                             │                          │
      ↓                      └──────────────────────────┘
                                       ↓
┌──────────────┐                      ↓
│  告警系统    │←────────────────────┘
│              │
│ • 文件日志   │
│ • 邮件       │
│ • Webhook    │
└──────────────┘
```

---

## 📦 组件说明

### 1. Windows 监控脚本 (`monitor-dnsapi-service.ps1`)

**功能**:
- ✅ 检查网络连通性（Ping 测试）
- ✅ 检查端口 5075 可用性
- ✅ 测试 HTTPS API 健康端点
- ✅ SSH 登录检查容器状态
- ✅ 自动修复（可选）
- ✅ 多种告警方式

**运行方式**: Windows 任务计划程序

**位置**: `K:\DNS\monitor-dnsapi-service.ps1`

### 2. 服务器端监控脚本 (`check-dnsapi.sh`)

**功能**:
- ✅ 本地容器状态检查
- ✅ 服务健康检查
- ✅ 重启策略验证
- ✅ 系统资源监控
- ✅ 自动修复功能
- ✅ 日志轮转

**运行方式**: Cron 定时任务

**位置**: `/opt/monitor/check-dnsapi.sh`（服务器端）

### 3. Docker Compose 配置 (`docker-compose.yml`)

**功能**:
- ✅ 容器健康检查（每 30 秒）
- ✅ 自动重启策略
- ✅ 资源限制
- ✅ 日志管理

**位置**: `K:\DNS\server-monitor\docker-compose.yml`

---

## 🚀 快速部署

### 步骤 1: 部署服务器端监控

```powershell
# 在 Windows 上运行
cd K:\DNS
.\deploy-server-monitor.ps1

# 如果需要部署 Docker Compose（推荐）
.\deploy-server-monitor.ps1 -DeployDockerCompose
```

**这将完成**:
- ✅ 上传监控脚本到服务器 `/opt/monitor/`
- ✅ 配置 Cron 任务（每 5 分钟执行）
- ✅ 可选：部署 Docker Compose 配置

### 步骤 2: 配置 Windows 任务计划

```powershell
# 以管理员身份运行 PowerShell
cd K:\DNS
.\setup-monitoring-task.ps1

# 自定义参数
.\setup-monitoring-task.ps1 `
    -IntervalMinutes 5 `
    -EnableAutoFix `
    -EnableAlert `
    -AlertType "file"
```

**这将完成**:
- ✅ 创建 Windows 任务计划
- ✅ 配置每 5 分钟运行一次
- ✅ 启用自动修复功能
- ✅ 配置告警方式

### 步骤 3: 验证部署

```powershell
# 立即运行一次测试
Start-ScheduledTask -TaskName "DNS API 服务监控"

# 查看日志
Get-Content K:\DNS\logs\monitor.log -Tail 50

# 查看告警日志
Get-Content K:\DNS\logs\alerts.log -Tail 20
```

---

## ⚙️ 配置详解

### Windows 监控脚本配置

#### 基本参数

```powershell
# 日志文件路径
-LogFile "K:\DNS\logs\monitor.log"

# 启用/禁用自动修复
-EnableAutoFix $true/$false

# 启用/禁用告警
-EnableAlert $true/$false

# 告警类型
-AlertType "file"    # 文件日志
-AlertType "email"   # 邮件告警
-AlertType "webhook" # Webhook 告警
```

#### 邮件告警配置

```powershell
.\monitor-dnsapi-service.ps1 `
    -AlertType "email" `
    -EmailTo "admin@example.com" `
    -EmailFrom "monitor@example.com" `
    -SmtpServer "smtp.example.com" `
    -SmtpPort 587
```

#### Webhook 告警配置

```powershell
.\monitor-dnsapi-service.ps1 `
    -AlertType "webhook" `
    -WebhookUrl "https://your-webhook-url.com/alert"
```

**Webhook 数据格式**:
```json
{
  "timestamp": "2025-10-24 10:30:00",
  "level": "ERROR",
  "subject": "服务异常",
  "message": "详细错误信息",
  "server": "43.138.35.183",
  "service_url": "https://tx.qsgl.net:5075",
  "container": "dnsapi"
}
```

### 服务器端监控配置

#### 修改检查频率

```bash
# SSH 登录服务器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183

# 编辑 crontab
crontab -e

# 修改时间间隔
# 每 3 分钟: */3 * * * * /opt/monitor/check-dnsapi.sh
# 每 10 分钟: */10 * * * * /opt/monitor/check-dnsapi.sh
```

#### 脚本配置项

编辑 `/opt/monitor/check-dnsapi.sh`:

```bash
# 容器名称
CONTAINER_NAME="dnsapi"

# 服务 URL
SERVICE_URL="http://localhost:5074/api/health"

# 日志文件
LOG_FILE="/var/log/dnsapi-monitor.log"
ALERT_FILE="/var/log/dnsapi-alerts.log"

# 最大日志大小（字节）
MAX_LOG_SIZE=10485760  # 10MB
```

### Docker 健康检查配置

编辑 `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5074/api/health"]
  interval: 30s        # 检查间隔
  timeout: 5s          # 超时时间
  retries: 3           # 失败重试次数
  start_period: 15s    # 启动宽限期
```

**参数说明**:
- `interval`: 多久检查一次
- `timeout`: 单次检查超时时间
- `retries`: 失败几次后标记为 unhealthy
- `start_period`: 容器启动后多久才开始检查

---

## 📊 监控指标

### 检查项目

| 检查项 | 说明 | Windows | 服务器 | Docker |
|--------|------|---------|--------|--------|
| 网络连通性 | Ping 测试 | ✅ | ✅ | ❌ |
| 端口可用性 | 端口 5075 | ✅ | ❌ | ❌ |
| HTTPS 服务 | API 健康检查 | ✅ | ✅ | ✅ |
| 容器状态 | Docker ps | ✅ | ✅ | ✅ |
| 重启策略 | RestartPolicy | ✅ | ✅ | ❌ |
| 系统资源 | 内存/磁盘 | ❌ | ✅ | ❌ |

### 健康状态判断

| 状态 | 条件 | 操作 |
|------|------|------|
| ✅ Healthy | 所有检查通过 | 无操作 |
| ⚠️ Warning | 部分检查失败但服务可用 | 记录日志 |
| ❌ Error | 服务不可用 | 自动修复 + 告警 |

---

## 🔧 故障处理流程

### 自动修复流程

```
发现异常
    ↓
检查容器状态
    ↓
容器已停止? ──Yes──→ 启动容器
    ↓ No                  ↓
检查重启策略            验证启动
    ↓                    ↓
策略为 no? ──Yes──→ 设置 unless-stopped
    ↓ No                  ↓
检查服务健康 ←─────────┘
    ↓
健康? ──Yes──→ 修复成功
    ↓ No
发送告警（需要人工介入）
```

### 告警级别

| 级别 | 条件 | 操作 |
|------|------|------|
| INFO | 正常运行 | 仅记录日志 |
| WARN | 资源使用率高 | 记录日志 |
| ERROR | 服务不可用 | 自动修复 + 告警 |
| CRITICAL | 修复失败 | 告警（需要人工处理）|

---

## 📝 日志管理

### Windows 日志

**监控日志**: `K:\DNS\logs\monitor.log`
```
[2025-10-24 10:30:00] [INFO] ========== 开始监控检查 ==========
[2025-10-24 10:30:01] [INFO] 检查网络连通性...
[2025-10-24 10:30:01] [INFO] 服务器 PING 测试通过
[2025-10-24 10:30:02] [SUCCESS] HTTPS 服务健康检查通过: healthy
[2025-10-24 10:30:02] [SUCCESS] 所有检查通过，服务运行正常
```

**告警日志**: `K:\DNS\logs\alerts.log`
```
========================================
告警时间: 2025-10-24 10:30:00
========================================
时间: 2025-10-24 10:30:00
级别: ERROR
主题: 服务异常

详细信息:
端口 5075 无法访问
容器已停止: Exited (0) 2 hours ago
自动修复: 容器已重新启动
========================================
```

### 服务器日志

**监控日志**: `/var/log/dnsapi-monitor.log`

**告警日志**: `/var/log/dnsapi-alerts.log`

### 查看日志命令

```powershell
# Windows
Get-Content K:\DNS\logs\monitor.log -Tail 50 -Wait  # 实时查看
Get-Content K:\DNS\logs\alerts.log  # 查看所有告警

# 服务器
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "tail -f /var/log/dnsapi-monitor.log"
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "cat /var/log/dnsapi-alerts.log"
```

---

## 🎯 使用场景

### 场景 1: 日常监控

**配置**: 默认配置即可
- 检查频率: 每 5 分钟
- 自动修复: 启用
- 告警方式: 文件日志

**适用**: 
- 单人维护
- 日常检查日志即可

### 场景 2: 团队协作

**配置**: 启用邮件告警
```powershell
.\setup-monitoring-task.ps1 `
    -IntervalMinutes 5 `
    -AlertType "email" `
    -EmailTo "team@example.com"
```

**适用**:
- 团队维护
- 需要及时通知

### 场景 3: 企业环境

**配置**: Webhook 集成到企业通知系统
```powershell
.\setup-monitoring-task.ps1 `
    -AlertType "webhook" `
    -WebhookUrl "https://your-system.com/api/alerts"
```

**适用**:
- 企业微信/钉钉集成
- 统一告警平台

---

## 🔍 故障排查

### 问题 1: 监控脚本未运行

**检查**:
```powershell
# 查看任务状态
Get-ScheduledTask -TaskName "DNS API 服务监控"

# 查看任务历史
Get-ScheduledTask -TaskName "DNS API 服务监控" | Get-ScheduledTaskInfo
```

**解决**:
```powershell
# 启用任务
Enable-ScheduledTask -TaskName "DNS API 服务监控"

# 手动运行测试
Start-ScheduledTask -TaskName "DNS API 服务监控"
```

### 问题 2: 无法连接服务器

**检查**:
```powershell
# 测试 SSH 连接
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "echo 'OK'"

# 检查密钥权限
icacls C:\Key\tx.qsgl.net_id_ed25519
```

### 问题 3: 告警未发送

**检查日志**:
```powershell
Get-Content K:\DNS\logs\monitor.log | Select-String "告警"
```

**验证邮件配置**:
```powershell
# 测试 SMTP 连接
Test-NetConnection -ComputerName smtp.example.com -Port 587
```

### 问题 4: Docker 健康检查失败

**查看容器健康状态**:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
docker inspect dnsapi --format='{{.State.Health.Status}}'
```

**查看健康检查日志**:
```bash
docker inspect dnsapi --format='{{json .State.Health}}' | jq
```

---

## 📚 参考命令

### Windows 管理命令

```powershell
# 查看所有任务
Get-ScheduledTask | Where-Object {$_.TaskName -like "*DNS*"}

# 立即运行
Start-ScheduledTask -TaskName "DNS API 服务监控"

# 停止任务
Stop-ScheduledTask -TaskName "DNS API 服务监控"

# 删除任务
Unregister-ScheduledTask -TaskName "DNS API 服务监控" -Confirm:$false

# 查看日志
Get-Content K:\DNS\logs\monitor.log -Tail 100
Get-Content K:\DNS\logs\alerts.log
```

### 服务器管理命令

```bash
# 查看 Cron 任务
crontab -l

# 手动执行监控
/opt/monitor/check-dnsapi.sh

# 查看日志
tail -f /var/log/dnsapi-monitor.log
cat /var/log/dnsapi-alerts.log

# 查看容器健康状态
docker ps
docker inspect dnsapi --format='{{.State.Health.Status}}'
```

### Docker Compose 命令

```bash
# 进入部署目录
cd /opt/dnsapi

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 启动服务
docker-compose up -d
```

---

## 💡 最佳实践

1. **监控频率**
   - 生产环境: 每 3-5 分钟
   - 测试环境: 每 10-15 分钟

2. **日志保留**
   - 监控日志: 保留 7 天
   - 告警日志: 长期保留

3. **告警策略**
   - 使用多种告警方式（文件 + 邮件/Webhook）
   - 避免告警疲劳（合并相同告警）

4. **自动修复**
   - 启用基本修复（启动容器、设置重启策略）
   - 复杂问题人工介入

5. **定期检查**
   - 每周查看告警日志
   - 每月检查监控配置

---

## 📞 技术支持

- 监控脚本: `K:\DNS\monitor-dnsapi-service.ps1`
- 部署脚本: `K:\DNS\deploy-server-monitor.ps1`
- 任务配置: `K:\DNS\setup-monitoring-task.ps1`
- Docker 配置: `K:\DNS\server-monitor\docker-compose.yml`

---

**文档版本**: 1.0  
**最后更新**: 2025-10-24  
**维护者**: DNS 运维团队
