using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

class Program
{
    private const string HostsFilePath = @"C:\Windows\System32\drivers\etc\hosts";
    private const string PublicIpServiceUrl = "http://ip-api.com/json";

    static async Task Main(string[] args)
    {
        // 强制启用 TLS 1.2/1.3
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12 | SecurityProtocolType.Tls13;

        string hostname = Environment.MachineName;
        Console.WriteLine($"主机名: {hostname}");

        while (true)
        {
            try
            {
                // 1. 获取公网 IP
                string publicIp = await GetPublicIpAsync();
                Console.WriteLine($"{DateTime.Now:HH:mm:ss} 获取到公网 IP: {publicIp}");

                // 2. 更新 hosts 文件
                UpdateHostsFile(publicIp, hostname);

                Console.WriteLine($"{DateTime.Now:HH:mm:ss} hosts 文件已成功更新，{hostname} -> {publicIp}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"{DateTime.Now:HH:mm:ss} 发生错误: {ex}");
            }

            await Task.Delay(10000); // 等待10秒
        }
    }

    private static async Task<string> GetPublicIpAsync()
    {
        using var handler = new HttpClientHandler
        {
            UseProxy = false // 禁用系统代理
        };
        using HttpClient client = new HttpClient(handler);
        HttpResponseMessage response = await client.GetAsync(PublicIpServiceUrl);
        response.EnsureSuccessStatusCode();
        string jsonResponse = await response.Content.ReadAsStringAsync();

        using var jsonDoc = JsonDocument.Parse(jsonResponse);
        return jsonDoc.RootElement.GetProperty("query").GetString()!;
    }

    private static void UpdateHostsFile(string publicIp, string hostname)
    {
        string[] lines = File.ReadAllLines(HostsFilePath);
        StringBuilder newContent = new StringBuilder();
        bool entryFound = false;

        foreach (string line in lines)
        {
            if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith("#"))
            {
                newContent.AppendLine(line);
                continue;
            }

            string[] parts = line.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2 && parts[1].Equals(hostname, StringComparison.OrdinalIgnoreCase))
            {
                newContent.AppendLine($"{publicIp}\t{hostname}");
                entryFound = true;
            }
            else
            {
                newContent.AppendLine(line);
            }
        }

        if (!entryFound)
        {
            newContent.AppendLine($"{publicIp}\t{hostname}");
        }

        File.WriteAllText(HostsFilePath, newContent.ToString());
    }
}