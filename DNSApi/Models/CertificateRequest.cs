using System.Text.Json.Serialization;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel;

namespace DNSApi.Models;

/// <summary>
/// 证书申请请求模型
/// </summary>
/// <example>
/// {
///   "domain": "example.com",
///   "provider": "DNSPOD",
///   "certType": "RSA2048",
///   "exportFormat": "BOTH",
///   "pfxPassword": "YourPassword123",
///   "apiKeyId": "your_api_key_id",
///   "apiKeySecret": "your_api_key_secret"
/// }
/// </example>
public class CertRequestModel
{
    /// <summary>
    /// 域名（支持单域名或泛域名，如 example.com 或 *.example.com）
    /// </summary>
    /// <example>example.com</example>
    [JsonPropertyName("domain")]
    [Required(ErrorMessage = "域名不能为空")]
    public string Domain { get; set; } = "";
    
    /// <summary>
    /// DNS服务商 (DNSPOD, CLOUDFLARE, ALIYUN等)
    /// </summary>
    /// <example>DNSPOD</example>
    [JsonPropertyName("provider")]
    [DefaultValue("DNSPOD")]
    public string Provider { get; set; } = "DNSPOD";
    
    /// <summary>
    /// 证书类型: RSA2048（兼容性好）, ECDSA256（性能好，证书小）
    /// </summary>
    /// <example>RSA2048</example>
    [JsonPropertyName("certType")]
    [DefaultValue("RSA2048")]
    public string CertType { get; set; } = "RSA2048";
    
    /// <summary>
    /// 导出格式: PEM（Linux/Nginx）, PFX（Windows/IIS）, BOTH（同时导出）
    /// </summary>
    /// <example>BOTH</example>
    [JsonPropertyName("exportFormat")]
    [DefaultValue("PEM")]
    public string ExportFormat { get; set; } = "PEM";
    
    /// <summary>
    /// PFX密码 (exportFormat为PFX或BOTH时必填)
    /// </summary>
    /// <example>YourPassword123</example>
    [JsonPropertyName("pfxPassword")]
    public string? PfxPassword { get; set; }
    
    /// <summary>
    /// API Key ID (某些服务商需要，如腾讯云DNSPod)
    /// </summary>
    /// <example>123456</example>
    [JsonPropertyName("apiKeyId")]
    public string? ApiKeyId { get; set; }
    
    /// <summary>
    /// API Key Secret（服务商密钥）
    /// </summary>
    /// <example>your_secret_key_here</example>
    [JsonPropertyName("apiKeySecret")]
    public string? ApiKeySecret { get; set; }
    
    /// <summary>
    /// Cloudflare Account ID (仅Cloudflare需要)
    /// </summary>
    /// <example>abcdef1234567890</example>
    [JsonPropertyName("cfAccountId")]
    public string? CfAccountId { get; set; }
    
    /// <summary>
    /// 是否申请泛域名证书 (自动检测，也可手动指定)
    /// </summary>
    /// <example>false</example>
    [JsonPropertyName("isWildcard")]
    public bool? IsWildcard { get; set; }
}

/// <summary>
/// 证书生成响应模型
/// </summary>
/// <example>
/// {
///   "success": true,
///   "message": "证书生成成功",
///   "domain": "example.com",
///   "subject": "CN=example.com",
///   "certType": "RSA2048",
///   "isWildcard": false,
///   "exportFormat": "BOTH",
///   "pemCert": "LS0tLS1CRUdJTi...(Base64编码)",
///   "pemKey": "LS0tLS1CRUdJTi...(Base64编码)",
///   "pfxData": "MIIJ...(Base64编码)",
///   "expiryDate": "2028-01-31T14:47:12Z",
///   "timestamp": "2025-10-29T08:00:00Z"
/// }
/// </example>
public class CertResponseModel
{
    /// <summary>
    /// 是否成功
    /// </summary>
    /// <example>true</example>
    [JsonPropertyName("success")]
    public bool Success { get; set; }
    
    /// <summary>
    /// 消息
    /// </summary>
    /// <example>证书生成成功</example>
    [JsonPropertyName("message")]
    public string Message { get; set; } = "";
    
    /// <summary>
    /// 域名
    /// </summary>
    /// <example>example.com</example>
    [JsonPropertyName("domain")]
    public string Domain { get; set; } = "";
    
    /// <summary>
    /// 证书主题 (CN)
    /// </summary>
    /// <example>CN=example.com</example>
    [JsonPropertyName("subject")]
    public string Subject { get; set; } = "";
    
    /// <summary>
    /// 证书类型
    /// </summary>
    /// <example>RSA2048</example>
    [JsonPropertyName("certType")]
    public string CertType { get; set; } = "";
    
    /// <summary>
    /// 是否为泛域名
    /// </summary>
    /// <example>false</example>
    [JsonPropertyName("isWildcard")]
    public bool IsWildcard { get; set; }
    
    /// <summary>
    /// 导出格式
    /// </summary>
    /// <example>BOTH</example>
    [JsonPropertyName("exportFormat")]
    public string ExportFormat { get; set; } = "";
    
    /// <summary>
    /// PEM证书内容 (Base64编码)
    /// </summary>
    /// <example>LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...</example>
    [JsonPropertyName("pemCert")]
    public string? PemCert { get; set; }
    
    /// <summary>
    /// PEM私钥内容 (Base64编码)
    /// </summary>
    /// <example>LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...</example>
    [JsonPropertyName("pemKey")]
    public string? PemKey { get; set; }
    
    /// <summary>
    /// PEM证书链内容 (Base64编码)
    /// </summary>
    /// <example>LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...</example>
    [JsonPropertyName("pemChain")]
    public string? PemChain { get; set; }
    
    /// <summary>
    /// PFX证书内容 (Base64编码)
    /// </summary>
    /// <example>MIIJQQIBAzCCCP...</example>
    [JsonPropertyName("pfxData")]
    public string? PfxData { get; set; }
    
    /// <summary>
    /// 证书文件路径
    /// </summary>
    [JsonPropertyName("certFilePaths")]
    public CertificateFilePaths? FilePaths { get; set; }
    
    /// <summary>
    /// 过期时间
    /// </summary>
    /// <example>2028-01-31T14:47:12Z</example>
    [JsonPropertyName("expiryDate")]
    public DateTime? ExpiryDate { get; set; }
    
    /// <summary>
    /// 时间戳
    /// </summary>
    /// <example>2025-10-29T08:00:00Z</example>
    [JsonPropertyName("timestamp")]
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// 证书文件路径
/// </summary>
public class CertificateFilePaths
{
    [JsonPropertyName("pemCert")]
    public string? PemCert { get; set; }
    
    [JsonPropertyName("pemKey")]
    public string? PemKey { get; set; }
    
    [JsonPropertyName("pemChain")]
    public string? PemChain { get; set; }
    
    [JsonPropertyName("pfx")]
    public string? Pfx { get; set; }
}
