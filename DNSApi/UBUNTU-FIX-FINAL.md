# 🚨 Ubuntu 容器崩溃 (Exit Code 139) 终极解决方案

## 问题分析
经过多次测试，发现问题根源：
- **退出代码 139** = 段错误 (Segmentation Fault)
- 即使是最简化的 .NET 8 应用也会崩溃
- 问题出现在 **Ubuntu 系统与 .NET 运行时的兼容性**

## 🎯 推荐解决方案

### 方案 1：使用自包含部署（推荐）
创建完全独立的可执行文件，不依赖系统 .NET 运行时：

```bash
# 在 Ubuntu 服务器执行：

# 1. 停止所有现有容器
docker stop $(docker ps -q --filter "name=dnsapi") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=dnsapi") 2>/dev/null || true

# 2. 使用最新的自包含镜像（即将构建）
docker pull 43.138.35.183:5000/dnsapi:selfcontained
docker run -d --name dnsapi-final -p 5074:5074 --restart unless-stopped 43.138.35.183:5000/dnsapi:selfcontained

# 3. 验证运行
docker ps | grep dnsapi-final
curl http://localhost:5074/api/health
```

### 方案 2：系统级修复
如果问题持续，需要修复 Ubuntu 系统环境：

```bash
# 更新系统和修复潜在问题
sudo apt update && sudo apt upgrade -y

# 安装缺失的系统库
sudo apt install -y \
    libc6-dev \
    libgcc-s1 \
    libssl3 \
    zlib1g-dev \
    libicu-dev

# 修复 glibc 兼容性问题
sudo apt install --reinstall libc6

# 清理并重启 Docker
docker system prune -af
sudo systemctl restart docker

# 检查系统兼容性
ldd --version
uname -a
```

### 方案 3：使用 Alpine 基础镜像
Alpine Linux 通常更兼容，内存占用更小：

```bash
# 拉取 Alpine 版本（如果可用）
docker pull 43.138.35.183:5000/dnsapi:alpine
docker run -d --name dnsapi-alpine -p 5074:5074 --restart unless-stopped 43.138.35.183:5000/dnsapi:alpine
```

## 🔧 我正在为你构建的解决方案

我即将创建以下镜像版本：

1. **自包含版本** (`selfcontained`) - 包含所有运行时依赖
2. **Alpine 版本** (`alpine`) - 基于 Alpine Linux
3. **调试版本** (`debug`) - 包含调试工具和详细日志

## 📋 临时替代方案

在等待新镜像期间，你可以：

### 使用 Node.js 替代版本
```bash
# 创建简单的 Node.js 替代品
cat > app.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => res.send('DNS API Alternative'));
app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.get('/api/wan-ip', (req, res) => res.json({ ip: '127.0.0.1', method: 'nodejs' }));

app.listen(5074, '0.0.0.0', () => console.log('Server running on port 5074'));
EOF

# 使用 Node.js 容器运行
docker run -d --name dnsapi-nodejs -p 5074:5074 -v $(pwd)/app.js:/app.js node:18-alpine node /app.js
```

### 使用 Python 替代版本
```bash
cat > app.py << 'EOF'
from flask import Flask, jsonify
import datetime

app = Flask(__name__)

@app.route('/')
def home():
    return 'DNS API Alternative (Python)'

@app.route('/api/health')
def health():
    return jsonify({'status': 'ok', 'time': datetime.datetime.now().isoformat()})

@app.route('/api/wan-ip')
def wan_ip():
    return jsonify({'ip': '127.0.0.1', 'method': 'python'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5074)
EOF

docker run -d --name dnsapi-python -p 5074:5074 -v $(pwd)/app.py:/app.py python:3.9-slim sh -c "pip install flask && python /app.py"
```

## 🔍 调试信息收集

请提供以下信息以便进一步诊断：

```bash
# 系统信息
uname -a
lsb_release -a
docker --version

# 运行时信息
docker logs dnsapi-stable 2>&1 | head -20

# 系统资源
free -h
df -h

# 内核日志（可能显示段错误详细信息）
sudo dmesg | tail -20
```

## ⏰ 接下来的步骤

1. **立即执行**：尝试方案 2 的系统修复
2. **10分钟内**：我将构建自包含版本镜像
3. **备选方案**：使用 Node.js 或 Python 临时替代

这个问题很可能是 Ubuntu 系统环境问题，而不是代码问题。自包含部署应该能够解决这个问题。