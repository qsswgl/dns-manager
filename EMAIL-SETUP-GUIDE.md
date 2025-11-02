# DNS API 邮件告警部署说明

## 📋 测试结果

测试邮件发送到 **qsoft@139.com** 时收到错误：
```
不允许使用邮箱名称。 服务器响应为: SMTP only, outside user is not allowed on this machine
```

**结论**: 139 邮箱的 SMTP 服务器**要求身份认证**，不能匿名发送。

---

## ✅ 解决方案

### 方案 1: 使用 139 邮箱 SMTP 认证（推荐）

#### 步骤 1: 获取 SMTP 授权码

1. 访问 139 邮箱: https://mail.139.com
2. 使用 **qsoft@139.com** 账号登录
3. 点击右上角 **设置** → **客户端设置**
4. 找到 **POP3/SMTP/IMAP** 设置区域
5. **开启 SMTP 服务**
6. 点击 **获取授权码**（或"开通客户端"）
7. 按提示完成验证（可能需要短信验证）
8. **记录生成的授权码**（这不是您的登录密码！）

#### 步骤 2: 配置监控脚本

编辑 `K:\DNS\monitor-dnsapi-service.ps1`，修改参数部分：

```powershell
param(
    [string]$LogFile = "K:\DNS\logs\monitor.log",
    [switch]$EnableAutoFix = $true,
    [switch]$EnableAlert = $true,
    [string]$AlertType = "email",
    [string]$EmailTo = "qsoft@139.com",
    [string]$EmailFrom = "qsoft@139.com",                # 改为您的139邮箱
    [string]$SmtpServer = "smtp.139.com",
    [int]$SmtpPort = 465,                                # 改为465 (SSL)
    [string]$SmtpUser = "qsoft@139.com",                 # 添加: 您的139邮箱
    [string]$SmtpPassword = "您的SMTP授权码"              # 添加: 授权码（不是登录密码！）
)
```

**重要提示**:
- `$EmailFrom` 必须改为您自己的 139 邮箱（qsoft@139.com）
- `$SmtpUser` 填写您的 139 邮箱
- `$SmtpPassword` 填写刚才获取的**SMTP授权码**（不是登录密码）
- `$SmtpPort` 改为 **465**（SSL加密端口）

#### 步骤 3: 测试邮件发送

创建测试脚本 `K:\DNS\test-email-139.ps1`:

```powershell
$EmailTo = "qsoft@139.com"
$EmailFrom = "qsoft@139.com"
$SmtpServer = "smtp.139.com"
$SmtpPort = 465
$SmtpUser = "qsoft@139.com"
$SmtpPassword = "您的SMTP授权码"  # 填写您获取的授权码

try {
    $securePassword = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($SmtpUser, $securePassword)
    
    $params = @{
        To = $EmailTo
        From = $EmailFrom
        Subject = "DNS API 监控测试 - $(Get-Date -Format 'HH:mm:ss')"
        Body = "测试成功！时间: $(Get-Date)"
        SmtpServer = $SmtpServer
        Port = $SmtpPort
        Credential = $credential
        UseSsl = $true
    }
    
    Send-MailMessage @params
    Write-Host "✓ 邮件发送成功！" -ForegroundColor Green
} catch {
    Write-Host "✗ 失败: $_" -ForegroundColor Red
}
```

运行测试:
```powershell
powershell -ExecutionPolicy Bypass -File K:\DNS\test-email-139.ps1
```

#### 步骤 4: 部署到任务计划

确认测试邮件发送成功后，运行：

```powershell
cd K:\DNS
.\setup-monitoring-task.ps1 -IntervalMinutes 5
```

---

### 方案 2: 使用腾讯企业邮箱（备选方案）

如果您有腾讯企业邮箱，配置更简单：

```powershell
param(
    [string]$EmailTo = "qsoft@139.com",                  # 收件人保持不变
    [string]$EmailFrom = "your-email@yourdomain.com",    # 改为您的企业邮箱
    [string]$SmtpServer = "smtp.exmail.qq.com",
    [int]$SmtpPort = 465,
    [string]$SmtpUser = "your-email@yourdomain.com",
    [string]$SmtpPassword = "您的企业邮箱密码"
)
```

---

### 方案 3: 使用 QQ 邮箱（最简单）

如果您有 QQ 邮箱，推荐使用（配置最简单）：

#### 获取 QQ 邮箱授权码:

1. 访问: https://mail.qq.com
2. 设置 → 账户 → POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务
3. 开启 **SMTP 服务**
4. 生成授权码

#### 配置:

```powershell
param(
    [string]$EmailTo = "qsoft@139.com",
    [string]$EmailFrom = "您的QQ号@qq.com",              # 如 123456@qq.com
    [string]$SmtpServer = "smtp.qq.com",
    [int]$SmtpPort = 465,
    [string]$SmtpUser = "您的QQ号@qq.com",
    [string]$SmtpPassword = "QQ邮箱授权码"               # 16位授权码
)
```

---

## 🚀 快速部署命令汇总

### 完整部署流程

```powershell
# 1. 获取 SMTP 授权码（手动操作）
#    - 访问邮箱设置
#    - 开启 SMTP 服务
#    - 获取授权码

# 2. 修改监控脚本配置
#    编辑 K:\DNS\monitor-dnsapi-service.ps1
#    填写 SMTP 认证信息

# 3. 测试邮件发送
powershell -ExecutionPolicy Bypass -File K:\DNS\test-email-139.ps1

# 4. 确认收到测试邮件后，部署监控
cd K:\DNS
.\setup-monitoring-task.ps1 -IntervalMinutes 5

# 5. 验证任务计划
Get-ScheduledTask -TaskName "DNS API 服务监控"
Start-ScheduledTask -TaskName "DNS API 服务监控"

# 6. 查看日志
Get-Content K:\DNS\logs\monitor.log -Tail 50 -Wait
```

---

## 📧 当前配置状态

| 配置项 | 当前值 | 状态 | 操作 |
|--------|--------|------|------|
| 收件人 | qsoft@139.com | ✅ 已配置 | 无需修改 |
| 发件人 | dnsapi-monitor@tx.qsgl.net | ❌ 需修改 | 改为您的邮箱 |
| SMTP服务器 | smtp.139.com | ✅ 正确 | 无需修改 |
| SMTP端口 | 25 | ⚠️ 需修改 | 改为 465 (SSL) |
| SMTP用户 | (空) | ❌ 需添加 | 添加您的邮箱 |
| SMTP密码 | (空) | ❌ 需添加 | 添加授权码 |
| SSL加密 | 未启用 | ⚠️ 需启用 | 使用465端口 |

---

## 🔍 常见问题

### Q: 授权码是什么？和登录密码有什么区别？

A: 授权码是专门用于第三方客户端登录的密码，不是您的邮箱登录密码。为了安全，邮件服务商要求第三方应用使用授权码而不是真实密码。

### Q: 为什么要用 465 端口而不是 25？

A: 
- 端口 25：不加密，很多 ISP 封禁此端口，需要认证
- 端口 465：SSL 加密，安全性高，推荐使用
- 端口 587：TLS 加密，也可以使用

### Q: 发件人可以是任意邮箱吗？

A: 不可以。发件人（$EmailFrom）必须是您自己的邮箱（用于SMTP认证的那个），否则邮件服务器会拒绝发送。

### Q: 如果 139 邮箱配置太复杂怎么办？

A: 建议改用 QQ 邮箱，配置更简单，稳定性更好。只需要在 QQ 邮箱设置中开启 SMTP 服务，获取授权码即可。

---

## 📝 下一步操作

请按照以下顺序操作：

1. ☐ 访问 139 邮箱获取 SMTP 授权码
2. ☐ 修改 `K:\DNS\monitor-dnsapi-service.ps1` 配置
3. ☐ 创建并运行 `K:\DNS\test-email-139.ps1` 测试
4. ☐ 确认收到测试邮件
5. ☐ 运行 `.\setup-monitoring-task.ps1` 部署
6. ☐ 验证任务计划运行正常

---

## 📞 需要帮助？

如果您在配置过程中遇到问题，请提供：
- 使用的邮箱类型（139/QQ/企业邮箱）
- 错误信息截图
- 日志文件内容

我会帮您解决！

---

**收件人邮箱**: qsoft@139.com  
**配置文件**: K:\DNS\monitor-dnsapi-service.ps1  
**测试脚本**: K:\DNS\test-email-139.ps1  
**部署脚本**: K:\DNS\setup-monitoring-task.ps1
