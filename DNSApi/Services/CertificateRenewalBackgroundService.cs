namespace DNSApi.Services;

/// <summary>
/// 证书自动续签后台服务
/// </summary>
public class CertificateRenewalBackgroundService : BackgroundService
{
    private readonly ILogger<CertificateRenewalBackgroundService> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly TimeSpan _checkInterval = TimeSpan.FromHours(6); // 每6小时检查一次
    
    public CertificateRenewalBackgroundService(
        ILogger<CertificateRenewalBackgroundService> logger,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _serviceProvider = serviceProvider;
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("🚀 证书自动续签服务已启动");
        
        // 启动后延迟1分钟再开始检查
        await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndRenewCertificatesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError($"❌ 证书检查异常: {ex.Message}");
            }
            
            // 等待下次检查
            await Task.Delay(_checkInterval, stoppingToken);
        }
        
        _logger.LogInformation("🛑 证书自动续签服务已停止");
    }
    
    private async Task CheckAndRenewCertificatesAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var certManager = scope.ServiceProvider.GetRequiredService<CertificateManagerService>();
        
        _logger.LogInformation("🔍 开始检查证书状态...");
        
        var certificates = certManager.GetAllCertificates();
        var checkedCount = 0;
        var renewedCount = 0;
        var deployedCount = 0;
        
        foreach (var cert in certificates)
        {
            if (!cert.AutoRenew)
            {
                _logger.LogInformation($"⏭️ 跳过未启用自动续签的证书: {cert.Domain}");
                continue;
            }
            
            // 检查证书状态
            var checkResult = await certManager.CheckCertificateAsync(cert);
            if (!checkResult)
            {
                _logger.LogWarning($"⚠️ 无法检查证书状态: {cert.Domain}");
                continue;
            }
            
            checkedCount++;
            
            // 判断是否需要续签
            if (cert.NeedsRenewal)
            {
                _logger.LogInformation($"🔄 证书需要续签: {cert.Domain} (剩余 {cert.DaysUntilExpiry} 天)");
                
                // 续签证书
                var (success, certPem, keyPem) = await certManager.RenewCertificateAsync(cert);
                if (success)
                {
                    renewedCount++;
                    
                    // 部署到所有启用的目标
                    foreach (var deployment in cert.Deployments.Where(d => d.Enabled))
                    {
                        var deployed = await certManager.DeployCertificateAsync(cert, deployment, certPem, keyPem);
                        if (deployed)
                        {
                            deployedCount++;
                            _logger.LogInformation($"✅ 已部署到: {deployment.Name}");
                        }
                        else
                        {
                            _logger.LogError($"❌ 部署失败: {deployment.Name}");
                        }
                    }
                }
                else
                {
                    _logger.LogError($"❌ 续签失败: {cert.Domain}");
                }
            }
            else
            {
                _logger.LogInformation($"✅ 证书有效: {cert.Domain} (剩余 {cert.DaysUntilExpiry} 天)");
            }
        }
        
        _logger.LogInformation($"📊 检查完成: 检查 {checkedCount} 个, 续签 {renewedCount} 个, 部署 {deployedCount} 次");
    }
}
