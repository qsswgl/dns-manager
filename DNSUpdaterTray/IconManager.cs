using System.Drawing;
using System.Net.Http;

namespace DNSUpdaterTray
{
    public class IconManager
    {
        private readonly HttpClient httpClient;
        private Icon? cachedIcon;
        private readonly string iconCachePath;

        public IconManager()
        {
            httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(10);
            iconCachePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DNSUpdaterTray", "coffee-icon.ico");
            
            // 确保缓存目录存在
            Directory.CreateDirectory(Path.GetDirectoryName(iconCachePath)!);
        }

        public async Task<Icon> GetTrayIconAsync()
        {
            // 如果已有缓存图标，直接返回
            if (cachedIcon != null)
                return cachedIcon;

            // 尝试从本地缓存加载
            if (File.Exists(iconCachePath))
            {
                try
                {
                    cachedIcon = new Icon(iconCachePath);
                    return cachedIcon;
                }
                catch
                {
                    // 缓存文件损坏，删除并重新下载
                    File.Delete(iconCachePath);
                }
            }

            // 下载并缓存图标
            try
            {
                await DownloadAndCacheIconAsync();
                if (File.Exists(iconCachePath))
                {
                    cachedIcon = new Icon(iconCachePath);
                    return cachedIcon;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"下载图标失败: {ex.Message}");
            }

            // 如果下载失败，使用系统默认图标
            return SystemIcons.Application;
        }

        private async Task DownloadAndCacheIconAsync()
        {
            const string imageUrl = "https://www.qsgl.net/%E5%92%96%E5%95%A1%E6%9D%AF.jpg";
            
            try
            {
                // 下载图片
                var imageBytes = await httpClient.GetByteArrayAsync(imageUrl);
                
                // 转换为Icon格式并保存
                using var ms = new MemoryStream(imageBytes);
                using var bitmap = new Bitmap(ms);
                
                // 调整为32x32像素（标准托盘图标大小）
                using var resizedBitmap = new Bitmap(bitmap, 32, 32);
                
                // 转换为Icon并保存
                var icon = Icon.FromHandle(resizedBitmap.GetHicon());
                using var fs = new FileStream(iconCachePath, FileMode.Create);
                
                // 由于Icon.Save方法在某些情况下可能不可用，我们使用另一种方法
                // 创建一个临时Icon文件
                await SaveIconToFileAsync(resizedBitmap, iconCachePath);
            }
            catch (Exception ex)
            {
                throw new Exception($"处理图标时出错: {ex.Message}");
            }
        }

        private async Task SaveIconToFileAsync(Bitmap bitmap, string path)
        {
            try
            {
                // 创建ICO格式的数据
                using var ms = new MemoryStream();
                
                // ICO文件头
                ms.Write(new byte[] { 0, 0, 1, 0, 1, 0 }, 0, 6);
                
                // 图标目录条目
                ms.WriteByte(32); // 宽度
                ms.WriteByte(32); // 高度
                ms.WriteByte(0);  // 颜色数
                ms.WriteByte(0);  // 保留
                ms.Write(BitConverter.GetBytes((short)1), 0, 2); // 颜色平面
                ms.Write(BitConverter.GetBytes((short)32), 0, 2); // 位深度
                
                // 准备PNG数据
                using var pngStream = new MemoryStream();
                bitmap.Save(pngStream, System.Drawing.Imaging.ImageFormat.Png);
                var pngData = pngStream.ToArray();
                
                // 写入数据大小和偏移
                ms.Write(BitConverter.GetBytes(pngData.Length), 0, 4);
                ms.Write(BitConverter.GetBytes(22), 0, 4); // 偏移到图像数据
                
                // 写入PNG数据
                ms.Write(pngData, 0, pngData.Length);
                
                // 保存到文件
                await File.WriteAllBytesAsync(path, ms.ToArray());
            }
            catch (Exception ex)
            {
                // 如果ICO转换失败，尝试直接保存为PNG然后转换
                var tempPngPath = path.Replace(".ico", ".png");
                bitmap.Save(tempPngPath, System.Drawing.Imaging.ImageFormat.Png);
                
                // 简单的备用方案：使用系统API转换
                try
                {
                    using var icon = Icon.FromHandle(bitmap.GetHicon());
                    using var fs = new FileStream(path, FileMode.Create);
                    // 注意：这里可能需要使用P/Invoke或其他方法来正确保存Icon
                    // 暂时使用PNG文件，在加载时处理
                    File.Move(tempPngPath, path.Replace(".ico", ".png"));
                }
                finally
                {
                    if (File.Exists(tempPngPath))
                        File.Delete(tempPngPath);
                }
            }
        }

        public Icon GetDefaultIcon()
        {
            return SystemIcons.Application;
        }

        public void Dispose()
        {
            cachedIcon?.Dispose();
            httpClient?.Dispose();
        }
    }
}