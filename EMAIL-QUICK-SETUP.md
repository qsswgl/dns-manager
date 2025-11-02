# 邮件告警快速配置卡片

## 收件人
✅ **qsoft@139.com**

---

## 🔑 获取 139 邮箱 SMTP 授权码

1. 访问: https://mail.139.com
2. 登录 qsoft@139.com
3. 右上角 **设置** → **客户端设置**
4. 开启 **SMTP 服务**
5. 点击 **获取授权码** 或 **开通客户端**
6. 完成短信验证
7. **记录授权码**（16位字符串）

---

## ⚙️ 修改配置文件

编辑: `K:\DNS\monitor-dnsapi-service.ps1`

找到第 5-15 行左右的参数部分，修改为：

```powershell
param(
    [string]$LogFile = "K:\DNS\logs\monitor.log",
    [switch]$EnableAutoFix = $true,
    [switch]$EnableAlert = $true,
    [string]$AlertType = "email",
    [string]$EmailTo = "qsoft@139.com",
    [string]$EmailFrom = "qsoft@139.com",           # ← 改这里
    [string]$SmtpServer = "smtp.139.com",
    [int]$SmtpPort = 465,                           # ← 改这里: 25 → 465
    [string]$SmtpUser = "qsoft@139.com",            # ← 添加这行
    [string]$SmtpPassword = "您刚才获取的授权码"     # ← 添加这行
)
```

---

## 🧪 测试邮件

创建测试文件: `K:\DNS\test-email-quick.ps1`

```powershell
$SmtpPassword = "您的授权码"  # 填写这里

$secPass = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
$cred = New-Object PSCredential("qsoft@139.com", $secPass)

Send-MailMessage `
    -To "qsoft@139.com" `
    -From "qsoft@139.com" `
    -Subject "测试 $(Get-Date -Format 'HH:mm')" `
    -Body "成功!" `
    -SmtpServer "smtp.139.com" `
    -Port 465 `
    -Credential $cred `
    -UseSsl

Write-Host "OK" -ForegroundColor Green
```

运行测试:
```powershell
powershell -ExecutionPolicy Bypass -File K:\DNS\test-email-quick.ps1
```

---

## 🚀 部署

测试成功后：

```powershell
cd K:\DNS
.\setup-monitoring-task.ps1 -IntervalMinutes 5
```

---

## ✅ 验证

```powershell
# 查看任务
Get-ScheduledTask -TaskName "DNS API 服务监控"

# 手动运行
Start-ScheduledTask -TaskName "DNS API 服务监控"

# 查看日志
Get-Content K:\DNS\logs\monitor.log -Tail 20
```

---

## 📞 如有问题

查看详细文档: `K:\DNS\EMAIL-SETUP-GUIDE.md`
