using System.Text.Json;
using Microsoft.Extensions.Configuration;

namespace DNSUpdaterTray
{
    public class ConfigurationManager
    {
        private readonly string configFilePath;
        private readonly string userConfigFilePath;
        
        public ConfigurationManager()
        {
            configFilePath = Path.Combine(Application.StartupPath, "appsettings.json");
            userConfigFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DNSUpdaterTray", "user-config.json");
            
            // 确保用户配置目录存在
            Directory.CreateDirectory(Path.GetDirectoryName(userConfigFilePath)!);
        }

        public DnsSettings LoadConfiguration()
        {
            // 首先从appsettings.json加载默认配置
            var builder = new ConfigurationBuilder()
                .SetBasePath(Application.StartupPath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
            
            var configuration = builder.Build();
            
            var settings = new DnsSettings
            {
                ApiUrl = configuration["DnsSettings:ApiUrl"] ?? "https://tx.qsgl.net:5075/api/updatehosts",
                SubDomain = configuration["DnsSettings:SubDomain"] ?? "3950",
                Domain = configuration["DnsSettings:Domain"] ?? "qsgl.net",
                UpdateInterval = int.Parse(configuration["DnsSettings:UpdateInterval"] ?? "60"),
                EnableUpdate = bool.Parse(configuration["DnsSettings:EnableUpdate"] ?? "true")
            };

            // 然后尝试加载用户自定义配置
            var userSettings = LoadUserConfiguration();
            if (userSettings != null)
            {
                // 用户配置覆盖默认配置
                settings.SubDomain = userSettings.SubDomain ?? settings.SubDomain;
                settings.Domain = userSettings.Domain ?? settings.Domain;
                settings.UpdateInterval = userSettings.UpdateInterval ?? settings.UpdateInterval;
                settings.EnableUpdate = userSettings.EnableUpdate ?? settings.EnableUpdate;
                settings.ApiUrl = userSettings.ApiUrl ?? settings.ApiUrl;
            }

            return settings;
        }

        public UserDnsSettings? LoadUserConfiguration()
        {
            try
            {
                if (File.Exists(userConfigFilePath))
                {
                    var json = File.ReadAllText(userConfigFilePath);
                    return JsonSerializer.Deserialize<UserDnsSettings>(json);
                }
            }
            catch (Exception ex)
            {
                // 记录错误但不抛出异常，使用默认配置
                System.Diagnostics.Debug.WriteLine($"加载用户配置失败: {ex.Message}");
            }
            return null;
        }

        public void SaveUserConfiguration(UserDnsSettings settings)
        {
            try
            {
                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(settings, options);
                File.WriteAllText(userConfigFilePath, json);
            }
            catch (Exception ex)
            {
                throw new Exception($"保存用户配置失败: {ex.Message}");
            }
        }

        public string GetUserConfigPath() => userConfigFilePath;
    }

    public class DnsSettings
    {
        public string ApiUrl { get; set; } = "";
        public string SubDomain { get; set; } = "";
        public string Domain { get; set; } = "";
        public int UpdateInterval { get; set; }
        public bool EnableUpdate { get; set; }
    }

    public class UserDnsSettings
    {
        public string? ApiUrl { get; set; }
        public string? SubDomain { get; set; }
        public string? Domain { get; set; }
        public int? UpdateInterval { get; set; }
        public bool? EnableUpdate { get; set; }
        public DateTime LastSaved { get; set; } = DateTime.Now;
        public string? LastUsedWebPage { get; set; }
    }
}