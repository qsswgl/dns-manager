using System.Diagnostics;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;

namespace DNSUpdaterTray
{
    public partial class MainForm : Form
    {
        private NotifyIcon trayIcon;
        private ContextMenuStrip trayMenu;
        private System.Windows.Forms.Timer updateTimer;
        private HttpClient httpClient;
        private IConfiguration configuration;
        
        // DNS配置
        private string apiUrl;
        private string subDomain;
        private string domain;
        private int updateInterval;
        private bool enableUpdate;
        
        // 状态信息
        private string lastUpdateTime = "未更新";
        private string currentIp = "未知";
        private string lastStatus = "初始化";

        public MainForm()
        {
            InitializeComponent();
            LoadConfiguration();
            InitializeTrayIcon();
            InitializeHttpClient();
            InitializeTimer();
            
            // 隐藏主窗口
            this.WindowState = FormWindowState.Minimized;
            this.ShowInTaskbar = false;
            this.Visible = false;
        }

        private void LoadConfiguration()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(Application.StartupPath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
            
            configuration = builder.Build();
            
            // 读取DNS配置
            apiUrl = configuration["DnsSettings:ApiUrl"] ?? "https://tx.qsgl.net:5075/api/updatehosts";
            subDomain = configuration["DnsSettings:SubDomain"] ?? "3950";
            domain = configuration["DnsSettings:Domain"] ?? "qsgl.net";
            updateInterval = int.Parse(configuration["DnsSettings:UpdateInterval"] ?? "60") * 1000; // 转换为毫秒
            enableUpdate = bool.Parse(configuration["DnsSettings:EnableUpdate"] ?? "true");
        }

        private void InitializeTrayIcon()
        {
            // 创建托盘图标
            trayIcon = new NotifyIcon();
            trayIcon.Text = "DNS自动更新器";
            trayIcon.Icon = SystemIcons.Application; // 使用系统默认图标
            
            // 创建右键菜单
            trayMenu = new ContextMenuStrip();
            
            // 添加菜单项
            var checkUpdateItem = new ToolStripMenuItem("立即检查更新");
            checkUpdateItem.Click += async (s, e) => await CheckAndUpdateDNS();
            trayMenu.Items.Add(checkUpdateItem);
            
            trayMenu.Items.Add(new ToolStripSeparator());
            
            var openWebItem = new ToolStripMenuItem("打开DNS管理");
            openWebItem.Click += (s, e) => 
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "https://tx.qsgl.net:5075",
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"无法打开网页: {ex.Message}", "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            };
            trayMenu.Items.Add(openWebItem);
            
            trayMenu.Items.Add(new ToolStripSeparator());
            
            var statusItem = new ToolStripMenuItem("状态信息");
            statusItem.Click += (s, e) => ShowStatus();
            trayMenu.Items.Add(statusItem);
            
            var settingsItem = new ToolStripMenuItem("设置");
            settingsItem.Click += (s, e) => ShowSettings();
            trayMenu.Items.Add(settingsItem);
            
            trayMenu.Items.Add(new ToolStripSeparator());
            
            var exitItem = new ToolStripMenuItem("退出");
            exitItem.Click += (s, e) => 
            {
                trayIcon.Visible = false;
                Application.Exit();
            };
            trayMenu.Items.Add(exitItem);
            
            // 绑定右键菜单
            trayIcon.ContextMenuStrip = trayMenu;
            
            // 双击事件
            trayIcon.DoubleClick += async (s, e) => await CheckAndUpdateDNS();
            
            // 显示托盘图标
            trayIcon.Visible = true;
        }

        private void InitializeHttpClient()
        {
            httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(30);
        }

        private void InitializeTimer()
        {
            if (enableUpdate && updateInterval > 0)
            {
                updateTimer = new System.Windows.Forms.Timer();
                updateTimer.Interval = updateInterval;
                updateTimer.Tick += async (s, e) => await CheckAndUpdateDNS();
                updateTimer.Start();
                
                // 启动后立即检查一次
                Task.Run(async () => await CheckAndUpdateDNS());
            }
        }

        private async Task CheckAndUpdateDNS()
        {
            try
            {
                lastStatus = "检查中...";
                UpdateTrayTooltip();
                
                // 准备请求数据
                var requestData = new
                {
                    subDomain = subDomain,
                    domain = domain,
                    refreshTime = 60,
                    enableDnsPod = enableUpdate
                };
                
                var json = JsonSerializer.Serialize(requestData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                // 发送POST请求
                var response = await httpClient.PostAsync(apiUrl, content);
                
                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
                    
                    // 解析响应
                    if (result.TryGetProperty("success", out var success) && success.GetBoolean())
                    {
                        if (result.TryGetProperty("clientIp", out var clientIp))
                        {
                            currentIp = clientIp.GetString() ?? "未知";
                        }
                        
                        lastStatus = "✅ 更新成功";
                        lastUpdateTime = DateTime.Now.ToString("HH:mm:ss");
                    }
                    else
                    {
                        var message = result.TryGetProperty("message", out var msg) ? msg.GetString() : "未知错误";
                        lastStatus = $"❌ 更新失败: {message}";
                    }
                }
                else
                {
                    lastStatus = $"❌ HTTP错误: {response.StatusCode}";
                }
            }
            catch (Exception ex)
            {
                lastStatus = $"❌ 异常: {ex.Message}";
            }
            
            UpdateTrayTooltip();
        }

        private void UpdateTrayTooltip()
        {
            var tooltip = $"DNS自动更新器\n" +
                         $"域名: {subDomain}.{domain}\n" +
                         $"当前IP: {currentIp}\n" +
                         $"最后更新: {lastUpdateTime}\n" +
                         $"状态: {lastStatus}";
            
            if (trayIcon != null)
            {
                // Windows托盘提示最大长度为63个字符，需要截断
                trayIcon.Text = tooltip.Length > 63 ? tooltip.Substring(0, 60) + "..." : tooltip;
            }
        }

        private void ShowStatus()
        {
            var statusMessage = $"DNS自动更新器状态信息\n\n" +
                              $"配置域名: {subDomain}.{domain}\n" +
                              $"API地址: {apiUrl}\n" +
                              $"更新间隔: {updateInterval / 1000}秒\n" +
                              $"自动更新: {(enableUpdate ? "启用" : "禁用")}\n\n" +
                              $"当前IP: {currentIp}\n" +
                              $"最后更新: {lastUpdateTime}\n" +
                              $"运行状态: {lastStatus}";
            
            MessageBox.Show(statusMessage, "DNS更新器状态", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void ShowSettings()
        {
            var settingsMessage = $"配置文件位置:\n{Path.Combine(Application.StartupPath, "appsettings.json")}\n\n" +
                                 $"当前配置:\n" +
                                 $"• 子域名: {subDomain}\n" +
                                 $"• 域名: {domain}\n" +
                                 $"• 更新间隔: {updateInterval / 1000}秒\n" +
                                 $"• 自动更新: {(enableUpdate ? "启用" : "禁用")}\n\n" +
                                 $"修改配置后需要重启程序生效。";
            
            MessageBox.Show(settingsMessage, "设置", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        protected override void SetVisibleCore(bool value)
        {
            // 防止窗口显示
            base.SetVisibleCore(false);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                updateTimer?.Stop();
                updateTimer?.Dispose();
                httpClient?.Dispose();
                trayIcon?.Dispose();
                trayMenu?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}