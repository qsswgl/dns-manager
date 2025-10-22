using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace DNSUpdaterTray
{
    public class DiagnosticTool
    {
        private static readonly HttpClient httpClient = new HttpClient();
        
        public static async Task<string> RunDiagnostics(string apiUrl)
        {
            var results = new StringBuilder();
            results.AppendLine("=== DNS更新器诊断报告 ===");
            results.AppendLine($"时间: {DateTime.Now}");
            results.AppendLine($"API地址: {apiUrl}");
            results.AppendLine();

            // 1. 网络连接测试
            results.AppendLine("1. 网络连接测试:");
            try
            {
                var uri = new Uri(apiUrl);
                var baseUrl = $"{uri.Scheme}://{uri.Host}:{uri.Port}";
                
                var response = await httpClient.GetAsync(baseUrl);
                results.AppendLine($"   ✓ 服务器连接成功 - 状态码: {response.StatusCode}");
            }
            catch (Exception ex)
            {
                results.AppendLine($"   ✗ 服务器连接失败: {ex.Message}");
            }

            // 2. API端点测试
            results.AppendLine("\n2. API端点测试:");
            try
            {
                // 测试不带参数的API调用
                var testUrl = $"{apiUrl}?domain=test.com&useProxy=false&enableDnsUpdate=false";
                var response = await httpClient.GetAsync(testUrl);
                var content = await response.Content.ReadAsStringAsync();
                
                results.AppendLine($"   状态码: {response.StatusCode}");
                results.AppendLine($"   响应长度: {content.Length} 字符");
                
                if (response.IsSuccessStatusCode)
                {
                    results.AppendLine("   ✓ API端点正常");
                }
                else
                {
                    results.AppendLine("   ✗ API端点异常");
                    results.AppendLine($"   响应内容: {content.Substring(0, Math.Min(200, content.Length))}");
                }
            }
            catch (Exception ex)
            {
                results.AppendLine($"   ✗ API测试失败: {ex.Message}");
            }

            // 3. DNS解析测试
            results.AppendLine("\n3. DNS解析测试:");
            try
            {
                var uri = new Uri(apiUrl);
                var hostEntry = await System.Net.Dns.GetHostEntryAsync(uri.Host);
                results.AppendLine($"   ✓ DNS解析成功:");
                foreach (var address in hostEntry.AddressList)
                {
                    results.AppendLine($"     - {address}");
                }
            }
            catch (Exception ex)
            {
                results.AppendLine($"   ✗ DNS解析失败: {ex.Message}");
            }

            // 4. SSL证书测试
            results.AppendLine("\n4. SSL证书测试:");
            try
            {
                var uri = new Uri(apiUrl);
                if (uri.Scheme == "https")
                {
                    using var client = new HttpClient();
                    var response = await client.GetAsync($"https://{uri.Host}:{uri.Port}");
                    results.AppendLine("   ✓ SSL证书验证通过");
                }
                else
                {
                    results.AppendLine("   - 非HTTPS连接，跳过SSL测试");
                }
            }
            catch (Exception ex)
            {
                results.AppendLine($"   ✗ SSL证书验证失败: {ex.Message}");
            }

            // 5. 配置文件检查
            results.AppendLine("\n5. 配置文件检查:");
            var configManager = new ConfigurationManager();
            try
            {
                var settings = configManager.LoadConfiguration();
                results.AppendLine("   ✓ 配置文件加载成功:");
                results.AppendLine($"     - API地址: {settings.ApiUrl}");
                results.AppendLine($"     - 子域名: {settings.SubDomain}");
                results.AppendLine($"     - 域名: {settings.Domain}");
                results.AppendLine($"     - 更新间隔: {settings.UpdateInterval}秒");
                results.AppendLine($"     - 启用更新: {settings.EnableUpdate}");
            }
            catch (Exception ex)
            {
                results.AppendLine($"   ✗ 配置文件加载失败: {ex.Message}");
            }

            results.AppendLine("\n=== 诊断完成 ===");
            return results.ToString();
        }
    }
}