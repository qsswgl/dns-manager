# DNS Dynamic IP Manager

A .NET 8.0 web application for dynamic DNS management with automatic IP detection and DNS record updates.

## 🚀 Features

- **Dynamic IP Detection**: Automatically detects client's real WAN IP address
- **DNS Record Updates**: Integrates with DNSPod API for automatic DNS record updates
- **SSL Certificate Management**: Built-in Let's Encrypt certificate management
- **Web Interface**: User-friendly HTML5 interface for configuration
- **Docker Support**: Containerized deployment with HTTPS support
- **Multi-Provider Support**: DNSPod, Aliyun DNS, Cloudflare

## 🏗️ Architecture

- **Backend**: ASP.NET Core 8.0 Minimal API
- **Frontend**: HTML5 + JavaScript
- **Container**: Docker with multi-stage builds
- **Database**: Configuration-based (appsettings.json)
- **Security**: HTTPS/TLS with PFX certificate support

## 📦 Deployment

### Docker Deployment

```bash
# Build the Docker image
docker build -t dnsapi:net8 -f DNSApi/Dockerfile.net8 .

# Run the container
docker run -d --name dnsapi-tx \
  -p 5074:8080 \
  -p 5075:8443 \
  dnsapi:net8
```

### Configuration

Update `DNSApi/appsettings.json`:

```json
{
  "DNSPod": {
    "ApiKeyId": "your_dnspod_key_id",
    "ApiKeySecret": "your_dnspod_secret"
  },
  "Certificate": {
    "PfxPath": "/app/certificates/domain.pfx",
    "Password": "certificate_password"
  }
}
```

## 🌐 API Endpoints

- `GET /` - Main web interface
- `GET /api/health` - Health check with network tests
- `GET /api/wan-ip` - Get client and server IP addresses
- `GET /api/updatehosts` - Update DNS records
- `POST /api/request-cert` - Request SSL certificates
- `GET /swagger` - API documentation

## 🔧 Development

### Prerequisites

- .NET 8.0 SDK
- Docker (optional)
- Visual Studio Code or Visual Studio

### Local Development

```bash
cd DNSApi
dotnet restore
dotnet run
```

Access the application at:
- HTTP: http://localhost:8080
- HTTPS: https://localhost:8443 (requires certificate)

## 📋 DNS Providers Configuration

### DNSPod (Tencent Cloud)
- Obtain API Key ID and Secret from DNSPod console
- Configure in appsettings.json or environment variables

### Aliyun DNS
- Get Access Key from Aliyun console
- Recommend using RAM sub-account for security

### Cloudflare
- Create API Token with Zone:Zone:Read and Zone:DNS:Edit permissions
- Or use Global API Key with email

## 🛡️ Security

- SSH key authentication for deployment
- HTTPS/TLS encryption
- API key management via configuration
- Certificate auto-renewal support

## 📚 Documentation

Visit `/swagger` endpoint for detailed API documentation.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🏷️ Version

Current version: 1.0.0 (NET8)