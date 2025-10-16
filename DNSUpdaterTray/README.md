# DNS自动更新器 - Windows系统托盘应用程序

## 🎯 功能说明

这是一个Windows系统托盘应用程序，用于自动更新动态DNS解析。它会定期检查您的公网IP地址变化，并自动调用DNS API来更新域名解析记录。

## ✨ 主要特性

- **🖥️ 系统托盘运行**: 最小化到系统托盘，不占用任务栏空间
- **☕ 自定义图标**: 使用咖啡杯图标，自动从网络下载并缓存
- **🔄 自动更新**: 可配置间隔自动检查IP变化并更新DNS记录
- **🚀 开机自启**: 支持Windows开机自动启动
- **⚙️ 图形化配置**: 友好的设置界面，支持实时配置修改
- **💾 配置持久化**: 自动保存用户配置到本地，下次启动自动加载
- **🎛️ 右键菜单**: 丰富的托盘右键菜单操作
- **📊 状态显示**: 实时显示更新状态和IP信息
- **🔧 动态更新**: 配置修改后立即生效，无需重启程序

## 🛠️ 安装步骤

### 1. 快速安装（推荐）

以**管理员身份**运行PowerShell，然后执行：

```powershell
cd K:\DNS\DNSUpdaterTray
.\install-startup.ps1
```

安装脚本将自动：
- 构建并复制程序文件到 `C:\Program Files\DNSUpdaterTray\`
- 设置开机自动启动
- 立即启动托盘程序

### 2. 手动安装

```powershell
# 构建项目
dotnet build -c Release

# 手动运行
.\bin\Release\net8.0-windows\DNSUpdaterTray.exe
```

## ⚙️ 配置选项

编辑 `appsettings.json` 文件来自定义设置：

```json
{
  "DnsSettings": {
    "ApiUrl": "https://tx.qsgl.net:5075/api/updatehosts",
    "SubDomain": "3950",           // 子域名
    "Domain": "qsgl.net",          // 主域名
    "UpdateInterval": 60,          // 检查间隔（秒）
    "EnableUpdate": true           // 是否启用自动更新
  }
}
```

### 配置参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `ApiUrl` | DNS更新API地址 | `https://tx.qsgl.net:5075/api/updatehosts` |
| `SubDomain` | 子域名 | `3950` |
| `Domain` | 主域名 | `qsgl.net` |
| `UpdateInterval` | 检查间隔（秒） | `60` |
| `EnableUpdate` | 启用自动更新 | `true` |

## 🎮 使用方法

### 系统托盘操作

1. **托盘图标**: 程序运行后会在Windows任务栏右下角显示咖啡杯图标 ☕
2. **右键菜单**:
   - **立即检查更新**: 手动触发DNS更新检查
   - **打开DNS管理**: 在浏览器中打开DNS管理网页
   - **状态信息**: 查看当前运行状态和配置
   - **设置**: 打开图形化设置窗口，可修改所有配置参数
   - **退出**: 关闭托盘程序

3. **双击图标**: 立即执行DNS更新检查

### 🆕 设置界面

点击右键菜单中的"设置"可打开配置窗口，包含以下选项：
- **子域名**: 设置要更新的子域名（如: 3950）
- **域名**: 设置主域名（如: qsgl.net）  
- **更新间隔**: 设置自动检查间隔，范围10-3600秒
- **启用更新**: 开启/关闭自动DNS更新功能
- **API地址**: 设置DNS更新接口地址

配置修改后立即生效，并自动保存到用户配置文件中。

### 状态信息显示

托盘提示包含以下信息：
- 当前配置的域名 (`子域名.主域名`)
- 最新检测到的公网IP地址
- 最后更新时间
- 运行状态（成功/失败/检查中）

## 📁 文件结构

```
# 程序安装目录
C:\Program Files\DNSUpdaterTray\
├── DNSUpdaterTray.exe          # 主程序
├── appsettings.json            # 默认配置文件
├── *.dll                       # 依赖库文件
└── *.runtimeconfig.json        # 运行时配置

# 用户配置目录
%AppData%\DNSUpdaterTray\
├── user-config.json            # 用户自定义配置（自动生成）
└── coffee-icon.ico             # 缓存的托盘图标文件
```

## 🔧 故障排除

### 常见问题

1. **托盘图标不显示**
   - 检查进程管理器中是否有 `DNSUpdaterTray.exe`
   - 重启应用程序或重启系统

2. **DNS更新失败**
   - 检查网络连接是否正常
   - 验证API地址是否可访问：`https://tx.qsgl.net:5075`
   - 查看状态信息中的错误详情

3. **开机不自启动**
   - 确认以管理员权限运行了安装脚本
   - 检查注册表：`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`

4. **配置不生效**
   - 推荐使用"设置"窗口修改配置，会立即生效
   - 直接修改配置文件需要重启程序
   - 用户配置存储在 `%AppData%\DNSUpdaterTray\user-config.json`

### 日志查看

程序运行状态可通过以下方式查看：
1. 右键托盘图标 → "状态信息"
2. 托盘提示信息（鼠标悬停）

## 🗑️ 卸载程序

以**管理员身份**运行：

```powershell
cd K:\DNS\DNSUpdaterTray
.\uninstall-startup.ps1
```

卸载脚本将：
- 停止正在运行的程序
- 删除开机启动设置
- 删除所有程序文件

## 🔄 更新程序

1. 停止当前运行的程序
2. 下载新版本源码
3. 重新运行安装脚本

## 📞 技术支持

- **项目地址**: https://github.com/qsswgl/dns-manager
- **DNS管理**: https://tx.qsgl.net:5075
- **API文档**: https://tx.qsgl.net:5075/swagger

## 📝 版本信息

- **当前版本**: v1.0.0
- **创建日期**: 2025年10月16日
- **运行环境**: Windows + .NET 8.0
- **开发语言**: C# WinForms

---

🎉 **享受自动化的DNS管理体验！** 🎉