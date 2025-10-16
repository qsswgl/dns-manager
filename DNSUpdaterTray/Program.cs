using System.Runtime.InteropServices;

namespace DNSUpdaterTray;

static class Program
{
    [DllImport("kernel32.dll")]
    static extern bool AttachConsole(int dwProcessId);
    
    [DllImport("kernel32.dll")]
    static extern bool AllocConsole();
    
    [DllImport("kernel32.dll")]
    static extern bool FreeConsole();
    
    /// <summary>
    ///  The main entry point for the application.
    /// </summary>
    [STAThread]
    static void Main()
    {
        // 检查是否已有实例在运行
        bool createdNew;
        using (var mutex = new Mutex(true, "DNSUpdaterTray_SingleInstance", out createdNew))
        {
            if (!createdNew)
            {
                MessageBox.Show("DNS更新器已在运行！", "提示", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            
            // 配置应用程序
            ApplicationConfiguration.Initialize();
            
            // 启用视觉样式
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            // 运行主窗体
            Application.Run(new MainForm());
        }
    }
}