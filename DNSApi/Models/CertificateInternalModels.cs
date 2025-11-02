namespace DNSApi.Models;

/// <summary>
/// 内部证书请求模型 (用于服务层)
/// </summary>
public class CertificateRequest
{
    public string Domain { get; set; } = "";
    public string Provider { get; set; } = "DNSPOD";
    public string? CertType { get; set; }
    public string? ExportFormat { get; set; }
    public string? PfxPassword { get; set; }
    public string? ApiKeyId { get; set; }
    public string? ApiKeySecret { get; set; }
    public string? CfAccountId { get; set; }
    public bool? IsWildcard { get; set; }
}

/// <summary>
/// 内部证书响应模型 (用于服务层)
/// </summary>
public class CertificateResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = "";
    public string Domain { get; set; } = "";
    public string Subject { get; set; } = "";
    public string CertType { get; set; } = "";
    public bool IsWildcard { get; set; }
    public string ExportFormat { get; set; } = "";
    public string? PemCert { get; set; }
    public string? PemKey { get; set; }
    public string? PemChain { get; set; }
    public string? PfxData { get; set; }
    public CertificateFilePaths? FilePaths { get; set; }
    public DateTime? ExpiryDate { get; set; }
}
