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
        private ConfigurationManager configManager;
        private IconManager iconManager;
        
        // DNS配置
        private DnsSettings dnsSettings;
        
        // 状态信息
        private string lastUpdateTime = "未更新";
        private string currentIp = "未知";
        private string lastStatus = "初始化";

        public MainForm()
        {
            InitializeComponent();
            configManager = new ConfigurationManager();
            iconManager = new IconManager();
            LoadConfiguration();
            InitializeHttpClient();
            _ = InitializeTrayIconAsync(); // 异步初始化托盘图标
            InitializeTimer();
            
            // 隐藏主窗口
            this.WindowState = FormWindowState.Minimized;
            this.ShowInTaskbar = false;
            this.Visible = false;
        }

        private void LoadConfiguration()
        {
            // 使用新的配置管理器加载配置
            dnsSettings = configManager.LoadConfiguration();
        }

        private async Task InitializeTrayIconAsync()
        {
            // 创建托盘图标
            trayIcon = new NotifyIcon();
            trayIcon.Text = "DNS自动更新器";
            
            // 异步加载自定义图标
            try
            {
                trayIcon.Icon = await iconManager.GetTrayIconAsync();
            }
            catch
            {
                // 如果加载失败，使用系统默认图标
                trayIcon.Icon = iconManager.GetDefaultIcon();
            }
            
            // 创建右键菜单
            trayMenu = new ContextMenuStrip();
            
            // 添加菜单项
            var checkUpdateItem = new ToolStripMenuItem("立即检查更新");
            checkUpdateItem.Click += async (s, e) => await CheckAndUpdateDNS();
            trayMenu.Items.Add(checkUpdateItem);
            
            trayMenu.Items.Add(new ToolStripSeparator());
            
            var openWebItem = new ToolStripMenuItem("打开DNS管理");
            openWebItem.Click += async (s, e) => 
            {
                try
                {
                    var webUrl = "https://tx.qsgl.net:5075";
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = webUrl,
                        UseShellExecute = true
                    });
                    
                    // 保存最后访问的网页URL
                    await SaveLastWebPageAsync(webUrl);
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
            
            var diagnosticItem = new ToolStripMenuItem("网络诊断");
            diagnosticItem.Click += async (s, e) => await RunDiagnostics();
            trayMenu.Items.Add(diagnosticItem);
            
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
            if (dnsSettings.EnableUpdate && dnsSettings.UpdateInterval > 0)
            {
                updateTimer = new System.Windows.Forms.Timer();
                updateTimer.Interval = dnsSettings.UpdateInterval * 1000; // 转换为毫秒
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
                
                // 构建GET请求URL
                var urlBuilder = new UriBuilder(dnsSettings.ApiUrl);
                var query = new List<string>();
                
                if (!string.IsNullOrEmpty(dnsSettings.SubDomain))
                {
                    query.Add($"subdomain={Uri.EscapeDataString(dnsSettings.SubDomain)}");
                }
                
                if (!string.IsNullOrEmpty(dnsSettings.Domain))
                {
                    query.Add($"domain={Uri.EscapeDataString(dnsSettings.Domain)}");
                }
                
                query.Add("useProxy=false");
                query.Add($"enableDnsUpdate={dnsSettings.EnableUpdate.ToString().ToLower()}");
                
                urlBuilder.Query = string.Join("&", query);
                
                // 发送GET请求
                var response = await httpClient.GetAsync(urlBuilder.ToString());
                
                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    
                    try
                    {
                        var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
                        
                        // 解析IP地址
                        if (result.TryGetProperty("ip", out var ip))
                        {
                            currentIp = ip.GetString() ?? "未知";
                        }
                        else if (result.TryGetProperty("clientIp", out var clientIp))
                        {
                            currentIp = clientIp.GetString() ?? "未知";
                        }
                        
                        // 检查是否成功
                        if (result.TryGetProperty("success", out var success) && success.GetBoolean())
                        {
                            lastStatus = "✅ 更新成功";
                        }
                        else if (result.TryGetProperty("changed", out var changed))
                        {
                            // 有些API返回changed字段而不是success
                            lastStatus = changed.GetBoolean() ? "✅ IP已更新" : "✅ IP无变化";
                        }
                        else
                        {
                            var message = result.TryGetProperty("msg", out var msg) ? msg.GetString() : 
                                         result.TryGetProperty("message", out var message1) ? message1.GetString() : "未知错误";
                            lastStatus = $"⚠️ {message}";
                        }
                        
                        lastUpdateTime = DateTime.Now.ToString("HH:mm:ss");
                    }
                    catch (JsonException)
                    {
                        // 如果不是JSON格式，可能是纯文本响应
                        currentIp = responseContent.Contains(".") ? responseContent.Trim() : currentIp;
                        lastStatus = "✅ 响应已收到";
                        lastUpdateTime = DateTime.Now.ToString("HH:mm:ss");
                    }
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    lastStatus = $"❌ HTTP {(int)response.StatusCode}: {errorContent.Substring(0, Math.Min(50, errorContent.Length))}";
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
                         $"域名: {dnsSettings.SubDomain}.{dnsSettings.Domain}\n" +
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
            var userConfigPath = configManager.GetUserConfigPath();
            var statusMessage = $"DNS自动更新器状态信息\n\n" +
                              $"配置域名: {dnsSettings.SubDomain}.{dnsSettings.Domain}\n" +
                              $"API地址: {dnsSettings.ApiUrl}\n" +
                              $"更新间隔: {dnsSettings.UpdateInterval}秒\n" +
                              $"自动更新: {(dnsSettings.EnableUpdate ? "启用" : "禁用")}\n\n" +
                              $"当前IP: {currentIp}\n" +
                              $"最后更新: {lastUpdateTime}\n" +
                              $"运行状态: {lastStatus}\n\n" +
                              $"用户配置: {userConfigPath}";
            
            MessageBox.Show(statusMessage, "DNS更新器状态", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void ShowSettings()
        {
            try
            {
                var userConfigPath = configManager.GetUserConfigPath();
                var settingsForm = new SettingsForm(dnsSettings, configManager);
                
                if (settingsForm.ShowDialog() == DialogResult.OK)
                {
                    // 重新加载配置
                    LoadConfiguration();
                    
                    // 重启定时器以应用新的时间间隔
                    updateTimer?.Stop();
                    InitializeTimer();
                    
                    MessageBox.Show("配置已保存并应用！", "设置", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"打开设置窗口失败: {ex.Message}", "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private async Task SaveLastWebPageAsync(string webUrl)
        {
            try
            {
                var userSettings = configManager.LoadUserConfiguration() ?? new UserDnsSettings();
                userSettings.LastUsedWebPage = webUrl;
                configManager.SaveUserConfiguration(userSettings);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"保存最后访问网页失败: {ex.Message}");
            }
        }

        private async Task RunDiagnostics()
        {
            try
            {
                var result = await DiagnosticTool.RunDiagnostics(dnsSettings.ApiUrl);
                
                // 创建一个新窗口显示诊断结果
                var diagForm = new Form
                {
                    Text = "网络诊断报告",
                    Size = new Size(600, 500),
                    StartPosition = FormStartPosition.CenterScreen,
                    ShowIcon = false,
                    MaximizeBox = false,
                    MinimizeBox = false
                };

                var textBox = new TextBox
                {
                    Multiline = true,
                    ReadOnly = true,
                    ScrollBars = ScrollBars.Vertical,
                    Dock = DockStyle.Fill,
                    Text = result,
                    Font = new Font("Consolas", 9)
                };

                var panel = new Panel
                {
                    Dock = DockStyle.Bottom,
                    Height = 40
                };

                var copyButton = new Button
                {
                    Text = "复制到剪贴板",
                    Size = new Size(120, 30),
                    Location = new Point(10, 5)
                };
                copyButton.Click += (s, e) =>
                {
                    Clipboard.SetText(result);
                    MessageBox.Show("诊断结果已复制到剪贴板", "提示", MessageBoxButtons.OK, MessageBoxIcon.Information);
                };

                var closeButton = new Button
                {
                    Text = "关闭",
                    Size = new Size(80, 30),
                    Location = new Point(140, 5)
                };
                closeButton.Click += (s, e) => diagForm.Close();

                panel.Controls.Add(copyButton);
                panel.Controls.Add(closeButton);

                diagForm.Controls.Add(textBox);
                diagForm.Controls.Add(panel);

                diagForm.ShowDialog();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"运行诊断失败: {ex.Message}", "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
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
                iconManager?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}