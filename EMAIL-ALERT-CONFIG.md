# DNS API 邮件告警配置指南

## 📧 配置概述

已配置邮件告警推送到: **qsoft@139.com**

---

## 🔧 当前配置

### 基本信息

| 配置项 | 值 |
|--------|-----|
| 收件人 | qsoft@139.com |
| 发件人 | dnsapi-monitor@tx.qsgl.net |
| SMTP 服务器 | smtp.139.com |
| SMTP 端口 | 25 (不加密) / 465 (SSL) / 587 (TLS) |
| 认证方式 | 可选（139邮箱可能需要） |

---

## 🚀 快速部署

### 方案 1: 使用默认配置（不需要SMTP认证）

如果 139 邮箱允许无认证发送（较少见），可直接部署：

```powershell
# 部署到 Windows 任务计划
cd K:\DNS
.\setup-monitoring-task.ps1 -IntervalMinutes 5
```

### 方案 2: 使用 SMTP 认证（推荐）

如果需要 SMTP 认证（多数情况需要），使用以下配置：

```powershell
# 1. 首先，您需要在 139 邮箱获取 SMTP 授权码
#    登录 mail.139.com -> 设置 -> 客户端设置 -> 获取授权码

# 2. 修改脚本默认参数
# 编辑 K:\DNS\monitor-dnsapi-service.ps1
# 将以下行修改：
# [string]$SmtpUser = "qsoft@139.com"  # 您的139邮箱账号
# [string]$SmtpPassword = "您的授权码"   # 不是登录密码，是SMTP授权码
# [int]$SmtpPort = 465                  # 使用 SSL 端口

# 3. 部署
.\setup-monitoring-task.ps1 -IntervalMinutes 5
```

### 方案 3: 使用腾讯企业邮箱（替代方案）

如果 139 邮箱配置困难，可考虑使用企业邮箱：

```powershell
# 修改脚本参数为：
# [string]$EmailTo = "qsoft@139.com"
# [string]$EmailFrom = "your-email@yourdomain.com"
# [string]$SmtpServer = "smtp.exmail.qq.com"
# [int]$SmtpPort = 465
# [string]$SmtpUser = "your-email@yourdomain.com"
# [string]$SmtpPassword = "您的邮箱密码或授权码"
```

---

## 📝 139 邮箱 SMTP 设置指南

### 步骤 1: 登录 139 邮箱

访问: https://mail.139.com

### 步骤 2: 开启 SMTP 服务

1. 点击右上角 **设置**
2. 选择 **客户端设置**
3. 找到 **POP3/SMTP/IMAP** 设置
4. 开启 **SMTP 服务**
5. 获取 **授权码**（不是登录密码）

### 步骤 3: 记录配置信息

```
SMTP 服务器: smtp.139.com
SMTP 端口: 
  - 25  (不加密，可能被某些ISP封禁)
  - 465 (SSL 加密，推荐)
  - 587 (TLS 加密，推荐)
用户名: qsoft@139.com
密码: [您获取的SMTP授权码]
```

---

## 🔨 修改脚本配置

### 编辑监控脚本

打开文件: `K:\DNS\monitor-dnsapi-service.ps1`

找到参数部分（第 5-15 行左右），修改为：

```powershell
param(
    [string]$LogFile = "K:\DNS\logs\monitor.log",
    [switch]$EnableAutoFix = $true,
    [switch]$EnableAlert = $true,
    [string]$AlertType = "email",
    [string]$EmailTo = "qsoft@139.com",
    [string]$EmailFrom = "dnsapi-monitor@tx.qsgl.net",
    [string]$SmtpServer = "smtp.139.com",
    [int]$SmtpPort = 465,                        # ← 改为 465 (SSL)
    [string]$SmtpUser = "qsoft@139.com",         # ← 添加您的邮箱
    [string]$SmtpPassword = "您的SMTP授权码"      # ← 添加授权码
)
```

**重要提示**：
- `$SmtpPassword` 不是您的邮箱登录密码
- 必须使用 139 邮箱提供的 **SMTP 授权码**
- 建议使用端口 465 或 587 确保安全传输

---

## 🧪 测试邮件发送

### 方法 1: 手动触发测试（模拟故障）

```powershell
# 临时停止容器来模拟故障
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker stop dnsapi"

# 立即运行监控脚本（会检测到故障并发送邮件）
powershell -ExecutionPolicy Bypass -File K:\DNS\monitor-dnsapi-service.ps1

# 等待收到邮件后，恢复容器（如果启用自动修复，会自动恢复）
# 如果未自动恢复，手动启动：
ssh -i C:\Key\tx.qsgl.net_id_ed25519 root@43.138.35.183 "docker start dnsapi"
```

### 方法 2: 测试脚本（直接发送测试邮件）

创建测试脚本 `K:\DNS\test-email.ps1`：

```powershell
# 测试邮件发送
$emailParams = @{
    To = "qsoft@139.com"
    From = "dnsapi-monitor@tx.qsgl.net"
    Subject = "【测试】DNS API 监控系统邮件测试"
    Body = "这是一封测试邮件，如果您收到此邮件，说明邮件配置成功！`n`n发送时间: $(Get-Date)"
    SmtpServer = "smtp.139.com"
    Port = 465
    Encoding = [System.Text.Encoding]::UTF8
}

# 如果需要认证，取消下面三行的注释并填写信息
# $securePassword = ConvertTo-SecureString "您的SMTP授权码" -AsPlainText -Force
# $credential = New-Object System.Management.Automation.PSCredential("qsoft@139.com", $securePassword)
# $emailParams.Credential = $credential
# $emailParams.UseSsl = $true

try {
    Send-MailMessage @emailParams
    Write-Host "✓ 测试邮件发送成功！请检查收件箱 qsoft@139.com" -ForegroundColor Green
} catch {
    Write-Host "✗ 测试邮件发送失败: $_" -ForegroundColor Red
    Write-Host "`n可能的原因：" -ForegroundColor Yellow
    Write-Host "1. SMTP 服务器地址或端口错误" -ForegroundColor Yellow
    Write-Host "2. 需要 SMTP 认证但未提供" -ForegroundColor Yellow
    Write-Host "3. 授权码错误" -ForegroundColor Yellow
    Write-Host "4. 网络防火墙阻止 SMTP 端口" -ForegroundColor Yellow
}
```

运行测试：
```powershell
powershell -ExecutionPolicy Bypass -File K:\DNS\test-email.ps1
```

---

## 📬 邮件告警内容

### 邮件主题格式
```
【DNS API 告警】服务异常检测
```

### 邮件正文（HTML格式）

邮件采用美观的 HTML 格式，包含：

1. **告警头部**（红色背景）
   - 告警主题
   - 服务名称

2. **基本信息**
   - 告警时间
   - 服务器地址
   - 服务 URL
   - 容器名称

3. **异常详情**
   - 具体错误信息
   - 自动修复操作记录（如有）

4. **邮件底部**
   - 监控系统标识
   - 脚本路径

### 示例告警内容

```
🚨 DNS API 服务告警
服务异常检测

⚠️ 检测到服务异常，请及时处理！

告警时间: 2025-10-24 11:30:00
服务器: 43.138.35.183 (tx.qsgl.net)
服务地址: https://tx.qsgl.net:5075
容器名称: dnsapi

📋 异常详情
✗ 端口 5075 无法访问
✗ HTTPS 服务无响应
✗ 容器未运行: Exited (0) 10 minutes ago

--- 自动修复操作 ---
✓ 容器已重新启动
✓ 重启策略已设置为 unless-stopped
✓ 服务已恢复正常运行
```

---

## 🔍 故障排查

### 问题 1: 未收到邮件

**检查项**：

1. **查看日志**：
   ```powershell
   Get-Content K:\DNS\logs\monitor.log -Tail 50
   ```

2. **检查垃圾邮件箱**：
   - 139 邮箱可能将告警邮件标记为垃圾邮件
   - 将发件人添加到白名单

3. **验证 SMTP 配置**：
   ```powershell
   # 测试 SMTP 端口连通性
   Test-NetConnection -ComputerName smtp.139.com -Port 465
   Test-NetConnection -ComputerName smtp.139.com -Port 587
   ```

4. **检查服务是否正常**：
   - 如果服务一直正常，不会发送邮件
   - 只有检测到异常时才发送

### 问题 2: 邮件发送失败

**常见错误及解决方案**：

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| Authentication failed | 认证失败 | 检查用户名密码（使用授权码，不是登录密码） |
| Relay access denied | 未授权转发 | 开启 139 邮箱的 SMTP 服务 |
| Connection timeout | 连接超时 | 检查防火墙，尝试其他端口 (25/465/587) |
| SSL handshake failed | SSL 错误 | 确保使用了 `-UseSsl $true` 参数 |

### 问题 3: 邮件发送太频繁

**优化方案**：

1. **增加检查间隔**：
   ```powershell
   # 从每 5 分钟改为每 10 分钟
   .\setup-monitoring-task.ps1 -IntervalMinutes 10
   ```

2. **添加告警抑制逻辑**：
   - 同一问题在 1 小时内只发送一次
   - 修改脚本添加告警去重逻辑

---

## ⚙️ 高级配置

### 配置多个收件人

修改脚本参数：
```powershell
[string]$EmailTo = "qsoft@139.com,admin@example.com,ops@example.com"
```

### 使用不同的告警级别

可以根据严重程度配置不同的邮件主题：

```powershell
# 在 Send-EmailAlert 函数中修改
if ($errorDetails -match "容器未运行") {
    $Subject = "【紧急】$Subject"
} elseif ($errorDetails -match "重启策略") {
    $Subject = "【警告】$Subject"
}
```

### 添加邮件附件（日志文件）

```powershell
$emailParams.Attachments = "K:\DNS\logs\monitor.log"
```

---

## 📊 监控报告

### 每日健康报告（可选）

可以配置每天发送一次健康报告，即使没有错误：

1. 创建新的任务计划，每天早上 9 点运行
2. 修改脚本发送汇总邮件：
   - 过去 24 小时的检查次数
   - 成功率统计
   - 异常记录（如有）

---

## 🔗 相关文档

- [监控系统配置指南](MONITORING-SYSTEM-GUIDE.md)
- [快速修复指南](QUICK-FIX-GUIDE.md)
- [根本原因分析](SERVICE-STOP-ROOT-CAUSE-ANALYSIS.md)

---

## 📞 技术支持

- **收件邮箱**: qsoft@139.com
- **监控脚本**: K:\DNS\monitor-dnsapi-service.ps1
- **配置脚本**: K:\DNS\setup-monitoring-task.ps1
- **服务器**: 43.138.35.183 (tx.qsgl.net)
- **服务地址**: https://tx.qsgl.net:5075

---

**文档版本**: 1.0  
**最后更新**: 2025-10-24  
**收件人**: qsoft@139.com
