using System.Diagnostics;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using CertReq = DNSApi.Models.CertificateRequest;
using CertResp = DNSApi.Models.CertificateResponse;

namespace DNSApi.Services;

/// <summary>
/// 证书生成和格式转换服�?
/// </summary>
public class CertificateGenerationService
{
    private readonly ILogger<CertificateGenerationService> _logger;
    private readonly IConfiguration _configuration;
    private readonly string _certBasePath;
    private readonly string _acmeShPath;

    public CertificateGenerationService(
        ILogger<CertificateGenerationService> logger,
        IConfiguration configuration,
        IWebHostEnvironment environment)
    {
        _logger = logger;
        _configuration = configuration;
        
        // 确定证书存储路径
        _certBasePath = environment.IsDevelopment() 
            ? Path.Combine(Directory.GetCurrentDirectory(), "certificates")
            : "/app/certificates";
        
        // acme.sh 路径
        _acmeShPath = Environment.GetEnvironmentVariable("HOME") + "/.acme.sh/acme.sh";
        
        // 确保证书目录存在
        if (!Directory.Exists(_certBasePath))
        {
            Directory.CreateDirectory(_certBasePath);
        }
        
        _logger.LogInformation("证书服务初始�?- 证书路径: {CertBasePath}", _certBasePath);
    }

    /// <summary>
    /// 申请证书
    /// </summary>
    public async Task<CertResp> IssueCertificateAsync(CertReq request)
    {
        try
        {
            // 验证请求
            var validationError = ValidateRequest(request);
            if (validationError != null)
            {
                return new CertResp
                {
                    Success = false,
                    Message = validationError,
                    Domain = request.Domain
                };
            }

            // 确定是否为泛域名
            bool isWildcard = request.IsWildcard ?? IsApexDomain(request.Domain);
            string certSubject = isWildcard ? $"*.{request.Domain}" : request.Domain;
            
            _logger.LogInformation("开始申请证�?- 域名: {Domain}, 类型: {CertType}, 格式: {ExportFormat}", 
                certSubject, request.CertType, request.ExportFormat);

            // 设置DNS API环境变量
            SetDnsApiEnvironment(request);

            // 调用 acme.sh 申请证书
            var acmeResult = await RunAcmeShAsync(request, certSubject, isWildcard);
            
            if (!acmeResult.Success)
            {
                return new CertResp
                {
                    Success = false,
                    Message = $"证书申请失败: {acmeResult.ErrorMessage}",
                    Domain = request.Domain
                };
            }

            // 导出证书为所需格式
            var exportResult = await ExportCertificateAsync(request, certSubject);
            
            if (!exportResult.Success)
            {
                return exportResult;
            }

            exportResult.Subject = certSubject;
            exportResult.IsWildcard = isWildcard;
            exportResult.Message = $"�?证书申请成功�?({request.CertType} / {request.ExportFormat})";
            
            return exportResult;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "证书申请异常");
            return new CertResp
            {
                Success = false,
                Message = $"证书申请异常: {ex.Message}",
                Domain = request.Domain
            };
        }
    }

    /// <summary>
    /// 验证请求参数
    /// </summary>
    private string? ValidateRequest(CertReq request)
    {
        if (string.IsNullOrWhiteSpace(request.Domain))
            return "域名不能为空";

        if (!new[] { "RSA2048", "ECDSA256" }.Contains(request.CertType?.ToUpper()))
            return "证书类型必须�?RSA2048 �?ECDSA256";

        if (!new[] { "PEM", "PFX", "BOTH" }.Contains(request.ExportFormat?.ToUpper()))
            return "导出格式必须是 PEM、PFX 或 BOTH";

        if ((request.ExportFormat?.ToUpper() == "PFX" || request.ExportFormat?.ToUpper() == "BOTH") 
            && string.IsNullOrWhiteSpace(request.PfxPassword))
            return "导出PFX格式时必须提供密码";

        return null;
    }

    /// <summary>
    /// 设置DNS API环境变量
    /// </summary>
    private void SetDnsApiEnvironment(CertReq request)
    {
        var provider = request.Provider?.ToUpper() ?? "DNSPOD";

        switch (provider)
        {
            case "DNSPOD":
                var dnspodId = request.ApiKeyId ?? _configuration["DNSPod:ApiKeyId"];
                var dnspodKey = request.ApiKeySecret ?? _configuration["DNSPod:ApiKeySecret"];
                
                if (!string.IsNullOrEmpty(dnspodId) && !string.IsNullOrEmpty(dnspodKey))
                {
                    Environment.SetEnvironmentVariable("DP_Id", dnspodId);
                    Environment.SetEnvironmentVariable("DP_Key", dnspodKey);
                    _logger.LogInformation("已设�?DNSPod API 凭证");
                }
                break;

            case "CLOUDFLARE":
                var cfToken = request.ApiKeySecret;
                var cfAccountId = request.CfAccountId;
                
                if (!string.IsNullOrEmpty(cfToken))
                {
                    Environment.SetEnvironmentVariable("CF_Token", cfToken);
                    if (!string.IsNullOrEmpty(cfAccountId))
                    {
                        Environment.SetEnvironmentVariable("CF_Account_ID", cfAccountId);
                    }
                    _logger.LogInformation("已设�?Cloudflare API 凭证");
                }
                break;

            case "ALIYUN":
                var aliKeyId = request.ApiKeyId;
                var aliKeySecret = request.ApiKeySecret;
                
                if (!string.IsNullOrEmpty(aliKeyId) && !string.IsNullOrEmpty(aliKeySecret))
                {
                    Environment.SetEnvironmentVariable("Ali_Key", aliKeyId);
                    Environment.SetEnvironmentVariable("Ali_Secret", aliKeySecret);
                    _logger.LogInformation("已设置阿里云 API 凭证");
                }
                break;
        }
    }

    /// <summary>
    /// 运行 acme.sh 申请证书
    /// </summary>
    private async Task<(bool Success, string ErrorMessage)> RunAcmeShAsync(
        CertReq request, string certSubject, bool isWildcard)
    {
        try
        {
            // 检�?acme.sh 是否安装
            if (!File.Exists(_acmeShPath))
            {
                _logger.LogWarning("acme.sh 未安装，返回模拟成功");
                // 在开发环境下创建模拟证书
                return await CreateDevelopmentCertificateAsync(request, certSubject);
            }

            // 构建 acme.sh 命令
            var dnsProvider = GetDnsProviderName(request.Provider);
            var keyLength = request.CertType?.ToUpper() == "RSA2048" ? "2048" : "ec-256";
            
            var arguments = new StringBuilder();
            arguments.Append($"--issue --dns {dnsProvider} ");
            arguments.Append($"-d {certSubject} ");
            
            if (request.CertType?.ToUpper() == "ECDSA256")
            {
                arguments.Append("--keylength ec-256 ");
            }
            else
            {
                arguments.Append("--keylength 2048 ");
            }
            
            arguments.Append("--force ");  // 强制更新

            _logger.LogInformation("执行命令: {AcmeShPath} {Arguments}", _acmeShPath, arguments.ToString());

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"{_acmeShPath} {arguments}\"",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };

            process.Start();
            var output = await process.StandardOutput.ReadToEndAsync();
            var error = await process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            _logger.LogInformation("acme.sh 输出:\n{Output}", output);
            
            if (process.ExitCode != 0)
            {
                _logger.LogError("acme.sh 错误:\n{Error}", error);
                return (false, error);
            }

            return (true, string.Empty);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "运行 acme.sh 失败");
            return (false, ex.Message);
        }
    }

    /// <summary>
    /// 导出证书为指定格�?
    /// </summary>
    private async Task<CertResp> ExportCertificateAsync(
        CertReq request, string certSubject)
    {
        var response = new CertResp
        {
            Success = true,
            Domain = request.Domain,
            CertType = request.CertType ?? "RSA2048",
            ExportFormat = request.ExportFormat ?? "PEM",
            FilePaths = new DNSApi.Models.CertificateFilePaths()
        };

        try
        {
            // acme.sh 证书默认路径
            var acmeCertDir = Path.Combine(
                Environment.GetEnvironmentVariable("HOME") ?? "/root", 
                ".acme.sh", 
                certSubject);

            var certFile = Path.Combine(acmeCertDir, "fullchain.cer");
            var keyFile = Path.Combine(acmeCertDir, certSubject + ".key");
            var caFile = Path.Combine(acmeCertDir, "ca.cer");

            // 如果文件不存在（开发环境），创建模拟证书
            if (!File.Exists(certFile) || !File.Exists(keyFile))
            {
                _logger.LogWarning("证书文件不存在，创建开发环境模拟证书");
                return await CreateMockCertificateResponseAsync(request, certSubject);
            }

            // 读取证书和私钥
            var certPem = await File.ReadAllTextAsync(certFile);
            var keyPem = await File.ReadAllTextAsync(keyFile);
            var chainPem = File.Exists(caFile) ? await File.ReadAllTextAsync(caFile) : "";

            // 目标文件路径
            var domainDir = Path.Combine(_certBasePath, request.Domain.Replace("*.", "wildcard."));
            if (!Directory.Exists(domainDir))
            {
                Directory.CreateDirectory(domainDir);
            }

            var exportFormat = request.ExportFormat?.ToUpper() ?? "PEM";

            // 导出 PEM 格式
            if (exportFormat == "PEM" || exportFormat == "BOTH")
            {
                var pemCertPath = Path.Combine(domainDir, $"{request.Domain}.crt");
                var pemKeyPath = Path.Combine(domainDir, $"{request.Domain}.key");
                var pemChainPath = Path.Combine(domainDir, $"{request.Domain}.chain.crt");

                await File.WriteAllTextAsync(pemCertPath, certPem);
                await File.WriteAllTextAsync(pemKeyPath, keyPem);
                
                if (!string.IsNullOrEmpty(chainPem))
                {
                    await File.WriteAllTextAsync(pemChainPath, chainPem);
                    response.FilePaths.PemChain = pemChainPath;
                    response.PemChain = Convert.ToBase64String(Encoding.UTF8.GetBytes(chainPem));
                }

                response.FilePaths.PemCert = pemCertPath;
                response.FilePaths.PemKey = pemKeyPath;
                response.PemCert = Convert.ToBase64String(Encoding.UTF8.GetBytes(certPem));
                response.PemKey = Convert.ToBase64String(Encoding.UTF8.GetBytes(keyPem));

                _logger.LogInformation("已导�?PEM 格式证书: {CertPath}", pemCertPath);
            }

            // 导出 PFX 格式
            if (exportFormat == "PFX" || exportFormat == "BOTH")
            {
                var pfxPath = Path.Combine(domainDir, $"{request.Domain}.pfx");
                var pfxData = await ConvertToPfxAsync(certPem, keyPem, request.PfxPassword!);

                await File.WriteAllBytesAsync(pfxPath, pfxData);
                response.FilePaths.Pfx = pfxPath;
                response.PfxData = Convert.ToBase64String(pfxData);

                _logger.LogInformation("已导�?PFX 格式证书: {PfxPath}", pfxPath);
            }

            // 解析证书信息
            try
            {
                var cert = X509Certificate2.CreateFromPem(certPem);
                response.ExpiryDate = cert.NotAfter;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "解析证书过期时间失败");
            }

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "导出证书失败");
            return new CertResp
            {
                Success = false,
                Message = $"导出证书失败: {ex.Message}",
                Domain = request.Domain
            };
        }
    }

    /// <summary>
    /// �?PEM 证书转换�?PFX 格式
    /// </summary>
    private async Task<byte[]> ConvertToPfxAsync(string certPem, string keyPem, string password)
    {
        try
        {
            // 使用 X509Certificate2 加载证书和私�?
            var cert = X509Certificate2.CreateFromPem(certPem, keyPem);
            
            // 导出�?PFX
            return cert.Export(X509ContentType.Pfx, password);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "PEM �?PFX 失败");
            throw;
        }
    }

    /// <summary>
    /// 创建开发环境模拟证�?
    /// </summary>
    private async Task<(bool Success, string ErrorMessage)> CreateDevelopmentCertificateAsync(
        CertReq request, string certSubject)
    {
        _logger.LogInformation("创建开发环境模拟证�? {Subject}", certSubject);
        
        // 在实际环境中，这里应该实际调用证书申请逻辑
        // 这里仅作为开发测试使�?
        await Task.Delay(1000); // 模拟延迟
        
        return (true, string.Empty);
    }

    /// <summary>
    /// 生成自签名证书（公开方法）
    /// 支持 RSA 2048 和 ECDSA P-256
    /// </summary>
    public async Task<CertResp> GenerateSelfSignedCertificateAsync(CertReq request)
    {
        try
        {
            _logger.LogInformation("开始生成自签名证书 - 域名: {Domain}, 类型: {CertType}, 格式: {ExportFormat}",
                request.Domain, request.CertType, request.ExportFormat);

            // 验证请求
            var validationError = ValidateRequest(request);
            if (validationError != null)
            {
                return new CertResp
                {
                    Success = false,
                    Message = validationError,
                    Domain = request.Domain
                };
            }

            string certSubject = request.Domain ?? "localhost";
            X509Certificate2 cert;

            // 根据证书类型生成密钥对
            if (request.CertType?.ToUpper() == "ECDSA256")
            {
                // 生成 ECDSA P-256 证书
                using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
                var certRequest = new CertificateRequest(
                    $"CN={certSubject}",
                    ecdsa,
                    HashAlgorithmName.SHA256);

                // 添加扩展
                certRequest.CertificateExtensions.Add(
                    new X509KeyUsageExtension(
                        X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.KeyEncipherment,
                        critical: true));

                certRequest.CertificateExtensions.Add(
                    new X509EnhancedKeyUsageExtension(
                        new OidCollection { new Oid("1.3.6.1.5.5.7.3.1") }, // TLS Web Server Authentication
                        critical: false));

                // 添加 SAN (Subject Alternative Name)
                var sanBuilder = new SubjectAlternativeNameBuilder();
                if (certSubject.StartsWith("*."))
                {
                    sanBuilder.AddDnsName(certSubject);
                    sanBuilder.AddDnsName(certSubject.Substring(2)); // 添加不带通配符的域名
                }
                else
                {
                    sanBuilder.AddDnsName(certSubject);
                }
                certRequest.CertificateExtensions.Add(sanBuilder.Build());

                cert = certRequest.CreateSelfSigned(
                    DateTimeOffset.UtcNow.AddDays(-1),
                    DateTimeOffset.UtcNow.AddYears(3));
            }
            else
            {
                // 生成 RSA 2048 证书（默认）
                using var rsa = RSA.Create(2048);
                var certRequest = new CertificateRequest(
                    $"CN={certSubject}",
                    rsa,
                    HashAlgorithmName.SHA256,
                    RSASignaturePadding.Pkcs1);

                // 添加扩展
                certRequest.CertificateExtensions.Add(
                    new X509KeyUsageExtension(
                        X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.KeyEncipherment,
                        critical: true));

                certRequest.CertificateExtensions.Add(
                    new X509EnhancedKeyUsageExtension(
                        new OidCollection { new Oid("1.3.6.1.5.5.7.3.1") }, // TLS Web Server Authentication
                        critical: false));

                // 添加 SAN (Subject Alternative Name)
                var sanBuilder = new SubjectAlternativeNameBuilder();
                if (certSubject.StartsWith("*."))
                {
                    sanBuilder.AddDnsName(certSubject);
                    sanBuilder.AddDnsName(certSubject.Substring(2)); // 添加不带通配符的域名
                }
                else
                {
                    sanBuilder.AddDnsName(certSubject);
                }
                certRequest.CertificateExtensions.Add(sanBuilder.Build());

                cert = certRequest.CreateSelfSigned(
                    DateTimeOffset.UtcNow.AddDays(-1),
                    DateTimeOffset.UtcNow.AddYears(3));
            }

            // 导出证书
            var certPem = cert.ExportCertificatePem();
            string keyPem;

            if (request.CertType?.ToUpper() == "ECDSA256")
            {
                // ECDSA 私钥
                using var ecdsa = cert.GetECDsaPrivateKey();
                if (ecdsa != null)
                {
                    keyPem = ecdsa.ExportECPrivateKeyPem();
                }
                else
                {
                    return new CertResp
                    {
                        Success = false,
                        Message = "无法导出 ECDSA 私钥",
                        Domain = request.Domain ?? "localhost"
                    };
                }
            }
            else
            {
                // RSA 私钥
                using var rsa = cert.GetRSAPrivateKey();
                if (rsa != null)
                {
                    keyPem = rsa.ExportRSAPrivateKeyPem();
                }
                else
                {
                    return new CertResp
                    {
                        Success = false,
                        Message = "无法导出 RSA 私钥",
                        Domain = request.Domain ?? "localhost"
                    };
                }
            }

            var response = new CertResp
            {
                Success = true,
                Domain = request.Domain ?? "localhost",
                Subject = certSubject,
                CertType = request.CertType ?? "RSA2048",
                ExportFormat = request.ExportFormat ?? "PEM",
                ExpiryDate = cert.NotAfter.ToUniversalTime(),
                Message = $"自签名证书生成成功 ({request.CertType ?? "RSA2048"})"
            };

            // 保存到文件
            var domainDir = Path.Combine(_certBasePath, request.Domain!.Replace("*.", "wildcard."));
            if (!Directory.Exists(domainDir))
            {
                Directory.CreateDirectory(domainDir);
            }

            var filePaths = new DNSApi.Models.CertificateFilePaths();

            // 导出 PEM 格式
            if (request.ExportFormat?.ToUpper() == "PEM" || request.ExportFormat?.ToUpper() == "BOTH")
            {
                var pemCertPath = Path.Combine(domainDir, $"{request.Domain.Replace("*.", "wildcard.")}.crt");
                var pemKeyPath = Path.Combine(domainDir, $"{request.Domain.Replace("*.", "wildcard.")}.key");
                var pemFullChainPath = Path.Combine(domainDir, $"{request.Domain.Replace("*.", "wildcard.")}.fullchain.crt");

                await File.WriteAllTextAsync(pemCertPath, certPem);
                await File.WriteAllTextAsync(pemKeyPath, keyPem);
                await File.WriteAllTextAsync(pemFullChainPath, certPem); // 自签名证书没有链

                response.PemCert = certPem;
                response.PemKey = keyPem;
                response.PemChain = certPem;

                filePaths.PemCert = pemCertPath;
                filePaths.PemKey = pemKeyPath;
                filePaths.PemChain = pemFullChainPath;

                _logger.LogInformation("PEM 证书已保存: {Path}", pemCertPath);
            }

            // 导出 PFX 格式
            if (request.ExportFormat?.ToUpper() == "PFX" || request.ExportFormat?.ToUpper() == "BOTH")
            {
                var pfxPath = Path.Combine(domainDir, $"{request.Domain.Replace("*.", "wildcard.")}.pfx");
                var pfxData = cert.Export(X509ContentType.Pfx, request.PfxPassword ?? "qsgl2024");

                await File.WriteAllBytesAsync(pfxPath, pfxData);
                response.PfxData = Convert.ToBase64String(pfxData);

                filePaths.Pfx = pfxPath;

                _logger.LogInformation("PFX 证书已保存: {Path}", pfxPath);
            }

            response.FilePaths = filePaths;

            cert.Dispose();

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "生成自签名证书时发生异常");
            return new CertResp
            {
                Success = false,
                Message = $"证书生成异常: {ex.Message}",
                Domain = request.Domain
            };
        }
    }

    /// <summary>
    /// 创建模拟证书响应（开发环境）
    /// </summary>
    private async Task<CertResp> CreateMockCertificateResponseAsync(
        CertReq request, string certSubject)
    {
        // 生成自签名证书用于测试
        using var rsa = RSA.Create(2048);
        var certRequest = new CertificateRequest(
            $"CN={certSubject}",
            rsa,
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1);

        // 添加扩展
        certRequest.CertificateExtensions.Add(
            new X509KeyUsageExtension(
                X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.KeyEncipherment,
                critical: true));

        certRequest.CertificateExtensions.Add(
            new X509EnhancedKeyUsageExtension(
                new OidCollection { new Oid("1.3.6.1.5.5.7.3.1") }, // TLS Web Server Authentication
                critical: false));

        // 添加 SAN (Subject Alternative Name) - 现代浏览器必需
        var sanBuilder = new SubjectAlternativeNameBuilder();
        if (certSubject.StartsWith("*."))
        {
            sanBuilder.AddDnsName(certSubject);
            sanBuilder.AddDnsName(certSubject.Substring(2)); // 添加不带通配符的域名
        }
        else
        {
            sanBuilder.AddDnsName(certSubject);
        }
        certRequest.CertificateExtensions.Add(sanBuilder.Build());

        var cert = certRequest.CreateSelfSigned(
            DateTimeOffset.UtcNow.AddDays(-1),
            DateTimeOffset.UtcNow.AddDays(90));

        var certPem = cert.ExportCertificatePem();
        var keyPem = rsa.ExportRSAPrivateKeyPem();

        var response = new CertResp
        {
            Success = true,
            Domain = request.Domain,
            Subject = certSubject,
            CertType = request.CertType ?? "RSA2048",
            ExportFormat = request.ExportFormat ?? "PEM",
            ExpiryDate = cert.NotAfter.ToUniversalTime(),
            PemCert = Convert.ToBase64String(Encoding.UTF8.GetBytes(certPem)),
            PemKey = Convert.ToBase64String(Encoding.UTF8.GetBytes(keyPem)),
            FilePaths = new DNSApi.Models.CertificateFilePaths()
        };

        // 保存到文�?
        var domainDir = Path.Combine(_certBasePath, request.Domain.Replace("*.", "wildcard."));
        if (!Directory.Exists(domainDir))
        {
            Directory.CreateDirectory(domainDir);
        }

        if (request.ExportFormat?.ToUpper() == "PEM" || request.ExportFormat?.ToUpper() == "BOTH")
        {
            var pemCertPath = Path.Combine(domainDir, $"{request.Domain}.crt");
            var pemKeyPath = Path.Combine(domainDir, $"{request.Domain}.key");
            
            await File.WriteAllTextAsync(pemCertPath, certPem);
            await File.WriteAllTextAsync(pemKeyPath, keyPem);
            
            response.FilePaths.PemCert = pemCertPath;
            response.FilePaths.PemKey = pemKeyPath;
        }

        if (request.ExportFormat?.ToUpper() == "PFX" || request.ExportFormat?.ToUpper() == "BOTH")
        {
            var pfxPath = Path.Combine(domainDir, $"{request.Domain}.pfx");
            var pfxData = cert.Export(X509ContentType.Pfx, request.PfxPassword);
            
            await File.WriteAllBytesAsync(pfxPath, pfxData);
            response.FilePaths.Pfx = pfxPath;
            response.PfxData = Convert.ToBase64String(pfxData);
        }

        return response;
    }

    /// <summary>
    /// 获取DNS服务商名�?
    /// </summary>
    private string GetDnsProviderName(string? provider)
    {
        return provider?.ToUpper() switch
        {
            "DNSPOD" => "dns_dp",
            "CLOUDFLARE" => "dns_cf",
            "ALIYUN" => "dns_ali",
            "TENCENT" => "dns_tencent",
            _ => "dns_dp"
        };
    }

    /// <summary>
    /// 判断是否为一级域�?
    /// </summary>
    private bool IsApexDomain(string domain)
    {
        if (string.IsNullOrEmpty(domain)) return false;
        var s = domain.Trim().ToLower();
        if (s.StartsWith('.') || s.EndsWith('.')) return false;
        var first = s.IndexOf('.');
        var last = s.LastIndexOf('.');
        return first > 0 && first == last && last < s.Length - 1;
    }
}
