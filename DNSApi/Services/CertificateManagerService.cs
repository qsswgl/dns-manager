using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace DNSApi.Services;

/// <summary>
/// 证书配置模型
/// </summary>
public class ManagedCertificate
{
    [JsonPropertyName("domain")]
    public string Domain { get; set; } = "";
    
    [JsonPropertyName("isWildcard")]
    public bool IsWildcard { get; set; }
    
    [JsonPropertyName("provider")]
    public string Provider { get; set; } = "DNSPOD";
    
    [JsonPropertyName("autoRenew")]
    public bool AutoRenew { get; set; } = true;
    
    [JsonPropertyName("renewDaysBefore")]
    public int RenewDaysBefore { get; set; } = 30;
    
    [JsonPropertyName("deployments")]
    public List<CertDeployment> Deployments { get; set; } = new();
    
    [JsonPropertyName("notifications")]
    public NotificationConfig Notifications { get; set; } = new();
    
    // 运行时状态（不保存到配置）
    [JsonIgnore]
    public DateTime? LastChecked { get; set; }
    
    [JsonIgnore]
    public DateTime? LastRenewed { get; set; }
    
    [JsonIgnore]
    public DateTime? ExpiryDate { get; set; }
    
    [JsonIgnore]
    public int DaysUntilExpiry => ExpiryDate.HasValue 
        ? (int)(ExpiryDate.Value - DateTime.UtcNow).TotalDays 
        : -1;
    
    [JsonIgnore]
    public bool NeedsRenewal => DaysUntilExpiry > 0 && DaysUntilExpiry <= RenewDaysBefore;
}

/// <summary>
/// 证书部署配置
/// </summary>
public class CertDeployment
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";
    
    [JsonPropertyName("type")]
    public string Type { get; set; } = "ssh"; // ssh, docker-volume, local-copy, http-api
    
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; } = true;
    
    // SSH 部署
    [JsonPropertyName("host")]
    public string? Host { get; set; }
    
    [JsonPropertyName("username")]
    public string? Username { get; set; }
    
    [JsonPropertyName("sshKeyPath")]
    public string? SshKeyPath { get; set; }
    
    [JsonPropertyName("remoteCertPath")]
    public string? RemoteCertPath { get; set; }
    
    [JsonPropertyName("remoteKeyPath")]
    public string? RemoteKeyPath { get; set; }
    
    // Docker Volume 部署
    [JsonPropertyName("containerName")]
    public string? ContainerName { get; set; }
    
    [JsonPropertyName("volumePath")]
    public string? VolumePath { get; set; }
    
    // 本地复制
    [JsonPropertyName("localCertPath")]
    public string? LocalCertPath { get; set; }
    
    [JsonPropertyName("localKeyPath")]
    public string? LocalKeyPath { get; set; }
    
    // 通用
    [JsonPropertyName("certFileName")]
    public string? CertFileName { get; set; }
    
    [JsonPropertyName("keyFileName")]
    public string? KeyFileName { get; set; }
    
    [JsonPropertyName("postDeployCommand")]
    public string? PostDeployCommand { get; set; }
    
    // 运行时状态
    [JsonIgnore]
    public DateTime? LastDeployed { get; set; }
    
    [JsonIgnore]
    public string? LastError { get; set; }
}

/// <summary>
/// 通知配置
/// </summary>
public class NotificationConfig
{
    [JsonPropertyName("email")]
    public List<string> Email { get; set; } = new();
    
    [JsonPropertyName("webhook")]
    public string? Webhook { get; set; }
}

/// <summary>
/// 证书配置文件
/// </summary>
public class CertificatesConfig
{
    [JsonPropertyName("managedCertificates")]
    public List<ManagedCertificate> ManagedCertificates { get; set; } = new();
    
    [JsonPropertyName("globalSettings")]
    public GlobalSettings GlobalSettings { get; set; } = new();
}

/// <summary>
/// 全局设置
/// </summary>
public class GlobalSettings
{
    [JsonPropertyName("checkInterval")]
    public string CheckInterval { get; set; } = "0 2 * * *"; // Cron 表达式
    
    [JsonPropertyName("defaultProvider")]
    public string DefaultProvider { get; set; } = "DNSPOD";
    
    [JsonPropertyName("defaultRenewDaysBefore")]
    public int DefaultRenewDaysBefore { get; set; } = 30;
    
    [JsonPropertyName("logRetentionDays")]
    public int LogRetentionDays { get; set; } = 90;
    
    [JsonPropertyName("enableNotifications")]
    public bool EnableNotifications { get; set; } = true;
}

/// <summary>
/// 证书管理服务
/// </summary>
public class CertificateManagerService
{
    private readonly ILogger<CertificateManagerService> _logger;
    private readonly IConfiguration _configuration;
    private readonly string _configPath;
    private CertificatesConfig _config;
    
    public CertificateManagerService(
        ILogger<CertificateManagerService> logger,
        IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
        _configPath = Path.Combine(AppContext.BaseDirectory, "certificates.json");
        _config = LoadConfig();
    }
    
    /// <summary>
    /// 加载配置
    /// </summary>
    private CertificatesConfig LoadConfig()
    {
        try
        {
            if (File.Exists(_configPath))
            {
                var json = File.ReadAllText(_configPath);
                var config = JsonSerializer.Deserialize<CertificatesConfig>(json);
                _logger.LogInformation($"✅ 已加载证书配置：{config?.ManagedCertificates.Count ?? 0} 个域名");
                return config ?? new CertificatesConfig();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"❌ 加载证书配置失败: {ex.Message}");
        }
        
        return new CertificatesConfig();
    }
    
    /// <summary>
    /// 获取所有托管证书
    /// </summary>
    public List<ManagedCertificate> GetAllCertificates()
    {
        return _config.ManagedCertificates;
    }
    
    /// <summary>
    /// 检查单个证书状态
    /// </summary>
    public async Task<bool> CheckCertificateAsync(ManagedCertificate cert)
    {
        try
        {
            _logger.LogInformation($"🔍 检查证书: {cert.Domain}");
            
            // 调用现有的 acme.sh 脚本获取证书信息
            var scriptPath = "/opt/acme-scripts/request-letsencrypt-cert.sh";
            if (!File.Exists(scriptPath))
            {
                _logger.LogWarning($"⚠️ 脚本不存在: {scriptPath}");
                return false;
            }
            
            var apiKeyId = _configuration["DNSPod:ApiKeyId"];
            var apiKeySecret = _configuration["DNSPod:ApiKeySecret"];
            
            var processInfo = new ProcessStartInfo
            {
                FileName = "/bin/bash",
                Arguments = $"{scriptPath} {cert.Domain} {cert.Provider} {apiKeyId} {apiKeySecret}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            
            using var process = Process.Start(processInfo);
            if (process != null)
            {
                var output = await process.StandardOutput.ReadToEndAsync();
                await process.WaitForExitAsync();
                
                if (process.ExitCode == 0 && !string.IsNullOrEmpty(output))
                {
                    var jsonDoc = JsonDocument.Parse(output);
                    var root = jsonDoc.RootElement;
                    
                    if (root.TryGetProperty("success", out var successProp) && successProp.GetBoolean())
                    {
                        var daysLeft = root.TryGetProperty("daysLeft", out var daysProp) 
                            ? daysProp.GetInt32() 
                            : 0;
                        
                        cert.ExpiryDate = DateTime.UtcNow.AddDays(daysLeft);
                        cert.LastChecked = DateTime.UtcNow;
                        
                        _logger.LogInformation($"📋 证书 {cert.Domain} 剩余 {daysLeft} 天");
                        return true;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"❌ 检查证书失败 {cert.Domain}: {ex.Message}");
        }
        
        return false;
    }
    
    /// <summary>
    /// 续签证书
    /// </summary>
    public async Task<(bool success, string certPem, string keyPem)> RenewCertificateAsync(ManagedCertificate cert)
    {
        try
        {
            _logger.LogInformation($"🔄 续签证书: {cert.Domain}");
            
            var scriptPath = "/opt/acme-scripts/request-letsencrypt-cert.sh";
            var apiKeyId = _configuration["DNSPod:ApiKeyId"];
            var apiKeySecret = _configuration["DNSPod:ApiKeySecret"];
            
            var processInfo = new ProcessStartInfo
            {
                FileName = "/bin/bash",
                Arguments = $"{scriptPath} {cert.Domain} {cert.Provider} {apiKeyId} {apiKeySecret}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            
            using var process = Process.Start(processInfo);
            if (process != null)
            {
                var output = await process.StandardOutput.ReadToEndAsync();
                await process.WaitForExitAsync();
                
                if (process.ExitCode == 0 && !string.IsNullOrEmpty(output))
                {
                    var jsonDoc = JsonDocument.Parse(output);
                    var root = jsonDoc.RootElement;
                    
                    if (root.TryGetProperty("success", out var successProp) && successProp.GetBoolean())
                    {
                        var certPem = root.GetProperty("cert").GetString() ?? "";
                        var keyPem = root.GetProperty("key").GetString() ?? "";
                        
                        cert.LastRenewed = DateTime.UtcNow;
                        
                        _logger.LogInformation($"✅ 证书续签成功: {cert.Domain}");
                        return (true, certPem, keyPem);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"❌ 续签证书失败 {cert.Domain}: {ex.Message}");
        }
        
        return (false, "", "");
    }
    
    /// <summary>
    /// 部署证书到目标服务
    /// </summary>
    public async Task<bool> DeployCertificateAsync(
        ManagedCertificate cert, 
        CertDeployment deployment, 
        string certPem, 
        string keyPem)
    {
        if (!deployment.Enabled)
        {
            _logger.LogInformation($"⏭️ 跳过已禁用的部署: {deployment.Name}");
            return true;
        }
        
        try
        {
            _logger.LogInformation($"📤 部署证书到: {deployment.Name} ({deployment.Type})");
            
            bool success = deployment.Type.ToLower() switch
            {
                "ssh" => await DeployViaSshAsync(deployment, certPem, keyPem),
                "docker-volume" => await DeployViaDockerVolumeAsync(deployment, certPem, keyPem),
                "local-copy" => await DeployViaLocalCopyAsync(deployment, certPem, keyPem),
                _ => throw new NotSupportedException($"不支持的部署类型: {deployment.Type}")
            };
            
            if (success)
            {
                deployment.LastDeployed = DateTime.UtcNow;
                deployment.LastError = null;
                
                // 执行部署后命令
                if (!string.IsNullOrEmpty(deployment.PostDeployCommand))
                {
                    await ExecutePostDeployCommandAsync(deployment);
                }
            }
            
            return success;
        }
        catch (Exception ex)
        {
            deployment.LastError = ex.Message;
            _logger.LogError($"❌ 部署失败 {deployment.Name}: {ex.Message}");
            return false;
        }
    }
    
    /// <summary>
    /// 通过 SSH 部署
    /// </summary>
    private async Task<bool> DeployViaSshAsync(CertDeployment deployment, string certPem, string keyPem)
    {
        try
        {
            // 创建临时文件
            var tempCertFile = Path.GetTempFileName();
            var tempKeyFile = Path.GetTempFileName();
            
            await File.WriteAllTextAsync(tempCertFile, certPem);
            await File.WriteAllTextAsync(tempKeyFile, keyPem);
            
            // 使用 SCP 复制文件
            var scpCertCmd = $"scp -i {deployment.SshKeyPath} {tempCertFile} {deployment.Username}@{deployment.Host}:{deployment.RemoteCertPath}";
            var scpKeyCmd = $"scp -i {deployment.SshKeyPath} {tempKeyFile} {deployment.Username}@{deployment.Host}:{deployment.RemoteKeyPath}";
            
            var certResult = await ExecuteCommandAsync(scpCertCmd);
            var keyResult = await ExecuteCommandAsync(scpKeyCmd);
            
            // 清理临时文件
            File.Delete(tempCertFile);
            File.Delete(tempKeyFile);
            
            return certResult && keyResult;
        }
        catch (Exception ex)
        {
            _logger.LogError($"SSH 部署失败: {ex.Message}");
            return false;
        }
    }
    
    /// <summary>
    /// 通过 Docker Volume 部署
    /// </summary>
    private async Task<bool> DeployViaDockerVolumeAsync(CertDeployment deployment, string certPem, string keyPem)
    {
        try
        {
            var certPath = Path.Combine(deployment.VolumePath!, deployment.CertFileName!);
            var keyPath = Path.Combine(deployment.VolumePath!, deployment.KeyFileName!);
            
            await File.WriteAllTextAsync(certPath, certPem);
            await File.WriteAllTextAsync(keyPath, keyPem);
            
            // 设置权限
            await ExecuteCommandAsync($"chmod 644 {certPath}");
            await ExecuteCommandAsync($"chmod 644 {keyPath}");
            
            _logger.LogInformation($"✅ 证书已写入: {certPath}");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError($"Docker Volume 部署失败: {ex.Message}");
            return false;
        }
    }
    
    /// <summary>
    /// 本地复制部署
    /// </summary>
    private async Task<bool> DeployViaLocalCopyAsync(CertDeployment deployment, string certPem, string keyPem)
    {
        try
        {
            await File.WriteAllTextAsync(deployment.LocalCertPath!, certPem);
            await File.WriteAllTextAsync(deployment.LocalKeyPath!, keyPem);
            
            _logger.LogInformation($"✅ 证书已复制到本地");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError($"本地复制失败: {ex.Message}");
            return false;
        }
    }
    
    /// <summary>
    /// 执行部署后命令
    /// </summary>
    private async Task<bool> ExecutePostDeployCommandAsync(CertDeployment deployment)
    {
        try
        {
            _logger.LogInformation($"🔧 执行部署后命令: {deployment.PostDeployCommand}");
            return await ExecuteCommandAsync(deployment.PostDeployCommand!);
        }
        catch (Exception ex)
        {
            _logger.LogError($"执行部署后命令失败: {ex.Message}");
            return false;
        }
    }
    
    /// <summary>
    /// 执行系统命令
    /// </summary>
    private async Task<bool> ExecuteCommandAsync(string command)
    {
        try
        {
            var processInfo = new ProcessStartInfo
            {
                FileName = "/bin/bash",
                Arguments = $"-c \"{command.Replace("\"", "\\\"")}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            
            using var process = Process.Start(processInfo);
            if (process != null)
            {
                await process.WaitForExitAsync();
                return process.ExitCode == 0;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"执行命令失败: {ex.Message}");
        }
        
        return false;
    }
}
