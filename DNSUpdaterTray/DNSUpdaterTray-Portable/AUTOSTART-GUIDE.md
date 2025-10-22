# DNS自动更新器 - 开机自启动配置说明

## ✅ 已实现功能

DNS自动更新器现在支持**系统重启后自动启动**！

## 🎯 自动启动方式

本程序使用**双重保险**机制确保开机自启动：

### 方式 1：用户启动文件夹快捷方式
- **位置**: `C:\Users\{用户名}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`
- **优点**: 无需管理员权限，用户级别启动
- **适用**: 单用户系统或个人使用

### 方式 2：系统注册表启动项
- **位置**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
- **键名**: `DNSUpdaterTray`
- **优点**: 系统级启动，所有用户生效
- **适用**: 多用户系统或服务器环境

## 📦 安装方法

### 使用便携式安装包

1. **下载并解压** `DNSUpdaterTray-Portable.zip`

2. **右键以管理员身份运行** `install-startup.ps1`
   - Windows 11: 右键 → "以管理员身份运行"
   - Windows 10: 右键 → "以管理员身份运行 PowerShell"

3. **按提示完成安装**
   - 程序将安装到: `C:\Program Files\DNSUpdaterTray`
   - 自动配置开机启动
   - 自动启动托盘程序

4. **检查托盘图标**
   - 在任务栏右下角查找咖啡杯图标 ☕
   - 右键图标可查看菜单

## 🔧 首次配置

1. **右键托盘图标** → 选择"**设置**"

2. **配置DNS参数**:
   ```
   子域名: 例如 3950
   域名: 例如 qsgl.net
   更新间隔: 60 秒（推荐）
   API地址: https://tx.qsgl.net:5075
   ```

3. **点击"保存"** - 配置自动保存到用户目录

4. **验证运行**:
   - 右键图标 → "状态信息"
   - 查看最后更新时间和IP地址
   - 确认"更新成功"状态

## 🔍 验证开机自启动

### 方法一：检查启动文件夹
```powershell
# 打开资源管理器，输入以下路径：
shell:startup

# 应该能看到 "DNS自动更新器.lnk" 快捷方式
```

### 方法二：检查注册表
```powershell
# 以管理员身份运行PowerShell，执行：
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "DNSUpdaterTray"

# 应该显示程序路径
```

### 方法三：重启测试
```powershell
# 重启电脑
Restart-Computer

# 登录后检查任务栏托盘区域
# 应自动出现咖啡杯图标
```

### 方法四：检查进程
```powershell
# 检查程序是否运行
Get-Process DNSUpdaterTray

# 应显示进程信息
```

## 🛠️ 手动控制

### 停止程序
```powershell
# 方式1: 右键托盘图标 → 退出
# 方式2: 任务管理器中结束进程
Stop-Process -Name DNSUpdaterTray
```

### 手动启动
```powershell
# 运行程序
& "C:\Program Files\DNSUpdaterTray\DNSUpdaterTray.exe"
```

### 禁用开机启动（临时）
```powershell
# 以管理员身份运行PowerShell

# 删除注册表启动项
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "DNSUpdaterTray"

# 删除启动文件夹快捷方式
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DNS自动更新器.lnk"
```

### 重新启用开机启动
```powershell
# 以管理员身份运行安装目录中的 install-startup.ps1
& "C:\Program Files\DNSUpdaterTray\install-startup.ps1"
```

## 🗑️ 完全卸载

### 使用卸载脚本（推荐）
```powershell
# 以管理员身份运行
& "C:\Program Files\DNSUpdaterTray\uninstall-startup.ps1"
```

卸载脚本会自动清理：
- ✅ 停止运行的程序进程
- ✅ 删除系统注册表启动项
- ✅ 删除用户启动文件夹快捷方式
- ✅ 删除防火墙规则
- ✅ 删除程序安装目录
- ⚠️ 可选择是否保留用户配置

### 手动卸载
```powershell
# 1. 停止程序
Stop-Process -Name DNSUpdaterTray -Force

# 2. 删除注册表项
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "DNSUpdaterTray"

# 3. 删除快捷方式
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DNS自动更新器.lnk"

# 4. 删除程序目录
Remove-Item "C:\Program Files\DNSUpdaterTray" -Recurse -Force

# 5. 删除用户配置（可选）
Remove-Item "$env:APPDATA\DNSUpdaterTray" -Recurse -Force

# 6. 删除防火墙规则
Remove-NetFirewallRule -DisplayName "DNS自动更新器"
```

## ❓ 常见问题

### Q: 重启后程序没有自动启动？
**A**: 检查以下几点：
1. 确认使用管理员权限安装
2. 检查防病毒软件是否拦截
3. 查看事件查看器中的错误日志
4. 尝试手动运行程序测试

### Q: 如何确认程序正在运行？
**A**: 
- 查看任务栏托盘区域的咖啡杯图标
- 或在任务管理器中查找 `DNSUpdaterTray.exe` 进程

### Q: 程序启动后立即退出？
**A**: 可能原因：
- 配置文件错误
- 缺少必要的DLL文件
- 端口被占用
- 查看Windows事件日志获取详细错误

### Q: 可以安装多个实例吗？
**A**: 
- 不建议。程序会自动检测并防止重复运行
- 如需多实例，需要修改安装路径和配置

### Q: 支持哪些Windows版本？
**A**:
- Windows 10 (x64) ✅
- Windows 11 (x64) ✅
- Windows Server 2019/2022 ✅
- 需要 64 位系统

## 📊 性能影响

- **内存占用**: 约 20-30 MB
- **CPU使用**: 空闲时几乎为0，更新时瞬间<1%
- **网络流量**: 每次更新约 1-2 KB
- **开机延迟**: <1 秒
- **电池影响**: 可忽略不计

## 🔒 安全说明

- ✅ 程序使用HTTPS加密通信
- ✅ 不收集任何个人隐私信息
- ✅ 不连接除DNS API外的任何服务器
- ✅ 配置文件仅存储在本地
- ✅ 支持Windows Defender和防病毒软件

## 📞 技术支持

- **项目地址**: https://github.com/qsswgl/dns-manager
- **DNS管理面板**: https://tx.qsgl.net:5075
- **API文档**: https://tx.qsgl.net:5075/swagger

---

**💡 提示**: 首次安装后建议立即测试重启，确保自动启动功能正常工作！
