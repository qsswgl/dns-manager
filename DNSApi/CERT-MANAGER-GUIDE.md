# 企微证书管理服务使用指南

## 概述

证书管理服务提供了统一的证书申请、续签、部署和监控功能，支持自动化管理多个域名的 Let's Encrypt 证书。

## 功能特性

### 1. 统一证书管理
- 📋 集中管理多个域名证书
- 🔄 自动续签（到期前30天）
- 📤 自动部署到多个微服务
- 📊 实时状态监控

### 2. 多种部署方式
- **SSH/SCP**: 通过 SSH 部署到远程服务器
- **Docker Volume**: 直接写入 Docker 挂载卷
- **Local Copy**: 复制到本地指定路径

### 3. 自动化运维
- 🤖 后台服务每6小时自动检查
- 🔔 证书状态变化通知
- 📝 完整的操作日志

## 配置文件

### certificates.json

```json
{
  "managedCertificates": [
    {
      "domain": "qsgl.net",
      "isWildcard": true,
      "provider": "DNSPOD",
      "autoRenew": true,
      "renewDaysBefore": 30,
      "deployments": [
        {
          "name": "Envoy Proxy (www.qsgl.cn)",
          "type": "ssh",
          "host": "123.57.93.200",
          "username": "root",
          "sshKeyPath": "/root/.ssh/id_rsa_qsgl_nopass",
          "remoteCertPath": "/etc/envoy/certs/qsgl.net.crt",
          "remoteKeyPath": "/etc/envoy/certs/qsgl.net.key",
          "postDeployCommand": "docker restart envoy",
          "enabled": true
        }
      ]
    }
  ],
  "globalSettings": {
    "checkInterval": "0 2 * * *",
    "defaultRenewDaysBefore": 30
  }
}
```

### 配置项说明

#### ManagedCertificate
- `domain`: 域名（必填）
- `isWildcard`: 是否为泛域名证书
- `provider`: DNS 提供商（DNSPOD/CLOUDFLARE）
- `autoRenew`: 是否自动续签
- `renewDaysBefore`: 提前多少天续签
- `deployments`: 部署目标列表

#### CertDeployment
- `name`: 部署名称
- `type`: 部署类型（ssh/docker-volume/local-copy）
- `enabled`: 是否启用
- `postDeployCommand`: 部署后执行的命令

**SSH 部署特有配置**:
- `host`: 远程主机地址
- `username`: SSH 用户名
- `sshKeyPath`: SSH 私钥路径
- `remoteCertPath`: 远程证书路径
- `remoteKeyPath`: 远程私钥路径

**Docker Volume 部署**:
- `volumePath`: Docker 卷挂载路径
- `certFileName`: 证书文件名
- `keyFileName`: 私钥文件名

**Local Copy 部署**:
- `localCertPath`: 本地证书路径
- `localKeyPath`: 本地私钥路径

## API 接口

### 1. 获取证书列表
```bash
GET /api/cert-manager/list
```

**响应示例**:
```json
{
  "success": true,
  "count": 2,
  "certificates": [
    {
      "domain": "qsgl.net",
      "isWildcard": true,
      "daysUntilExpiry": 89,
      "needsRenewal": false,
      "deployments": [...]
    }
  ]
}
```

### 2. 检查证书状态
```bash
POST /api/cert-manager/check?domain=qsgl.net
```

**响应示例**:
```json
{
  "success": true,
  "domain": "qsgl.net",
  "expiryDate": "2026-01-18T05:38:50Z",
  "daysUntilExpiry": 89,
  "needsRenewal": false
}
```

### 3. 手动续签证书
```bash
POST /api/cert-manager/renew?domain=qsgl.net&deploy=true
```

**参数**:
- `domain`: 域名（必填）
- `deploy`: 是否自动部署（默认 true）

**响应示例**:
```json
{
  "success": true,
  "domain": "qsgl.net",
  "renewed": "2025-10-20T08:00:00Z",
  "deployed": true,
  "deployResults": [
    {
      "name": "Envoy Proxy",
      "success": true,
      "error": null
    }
  ]
}
```

### 4. 部署证书
```bash
POST /api/cert-manager/deploy?domain=qsgl.net&deploymentName=Envoy%20Proxy
```

**参数**:
- `domain`: 域名（必填）
- `deploymentName`: 部署名称（可选，不填则部署到所有启用的目标）

### 5. 获取整体状态
```bash
GET /api/cert-manager/status
```

**响应示例**:
```json
{
  "success": true,
  "summary": {
    "totalCertificates": 2,
    "autoRenewEnabled": 2,
    "needsRenewal": 0,
    "expired": 0,
    "healthy": 2,
    "certificates": [
      {
        "domain": "qsgl.net",
        "daysUntilExpiry": 89,
        "status": "healthy"
      }
    ]
  }
}
```

## 使用场景

### 场景1: 添加新域名

1. **编辑配置文件**:
```json
{
  "domain": "newdomain.com",
  "isWildcard": false,
  "provider": "DNSPOD",
  "autoRenew": true,
  "deployments": [...]
}
```

2. **重启服务**:
```bash
docker restart dnsapi
```

3. **首次申请证书**:
```bash
curl -X POST "http://localhost:5074/api/cert-manager/renew?domain=newdomain.com"
```

### 场景2: 监控证书状态

**获取所有证书状态**:
```bash
curl http://localhost:5074/api/cert-manager/status
```

**检查单个证书**:
```bash
curl -X POST "http://localhost:5074/api/cert-manager/check?domain=qsgl.net"
```

### 场景3: 手动续签和部署

**续签并部署到所有目标**:
```bash
curl -X POST "http://localhost:5074/api/cert-manager/renew?domain=qsgl.net&deploy=true"
```

**只续签不部署**:
```bash
curl -X POST "http://localhost:5074/api/cert-manager/renew?domain=qsgl.net&deploy=false"
```

**单独部署到指定目标**:
```bash
curl -X POST "http://localhost:5074/api/cert-manager/deploy?domain=qsgl.net&deploymentName=Envoy%20Proxy"
```

### 场景4: 添加新的部署目标

假设需要将 `qsgl.net` 的证书同时部署到 Nginx 服务器：

```json
{
  "domain": "qsgl.net",
  "deployments": [
    {
      "name": "Nginx Server",
      "type": "ssh",
      "host": "192.168.1.100",
      "username": "root",
      "sshKeyPath": "/root/.ssh/id_rsa",
      "remoteCertPath": "/etc/nginx/ssl/qsgl.net.crt",
      "remoteKeyPath": "/etc/nginx/ssl/qsgl.net.key",
      "postDeployCommand": "nginx -s reload",
      "enabled": true
    }
  ]
}
```

## 自动化运维

### 后台服务

证书管理服务包含一个后台任务，会：
- 每6小时检查一次所有证书
- 自动续签即将过期的证书（30天内）
- 自动部署到所有启用的目标
- 记录详细日志

### 查看日志

```bash
docker logs -f dnsapi | grep "证书"
```

### 日志示例

```
🚀 证书自动续签服务已启动
🔍 开始检查证书状态...
✅ 证书有效: qsgl.net (剩余 89 天)
✅ 证书有效: tx.qsgl.net (剩余 85 天)
📊 检查完成: 检查 2 个, 续签 0 个, 部署 0 次
```

## 部署到生产环境

### 1. 复制配置文件
```bash
docker cp certificates.json dnsapi:/app/certificates.json
```

### 2. 重启容器
```bash
docker restart dnsapi
```

### 3. 验证服务
```bash
curl http://localhost:5074/api/cert-manager/status
```

### 4. 测试续签
```bash
curl -X POST "http://localhost:5074/api/cert-manager/check?domain=qsgl.net"
```

## 故障排查

### 问题1: 证书续签失败

**检查日志**:
```bash
docker logs dnsapi | grep "续签失败"
```

**常见原因**:
- DNS API 凭证不正确
- acme.sh 脚本不存在
- 网络连接问题

### 问题2: 部署失败

**检查 SSH 连接**:
```bash
ssh -i /root/.ssh/id_rsa_qsgl_nopass root@123.57.93.200
```

**检查文件权限**:
```bash
ls -l /etc/envoy/certs/
```

### 问题3: 后台服务未运行

**检查容器日志**:
```bash
docker logs dnsapi | grep "证书自动续签服务"
```

**重启容器**:
```bash
docker restart dnsapi
```

## 监控和告警

### 定期检查证书状态
建议设置 cron 任务：

```bash
# 每天早上8点检查证书状态
0 8 * * * curl http://localhost:5074/api/cert-manager/status | jq '.summary.needsRenewal'
```

### Webhook 通知
在 `certificates.json` 中配置 webhook：

```json
{
  "notifications": {
    "webhook": "https://your-webhook-url.com/notify"
  }
}
```

## 最佳实践

1. **定期备份配置**: 保存 `certificates.json` 的副本
2. **测试环境验证**: 先在测试环境验证配置
3. **监控日志**: 定期检查服务日志
4. **提前续签**: 建议设置 `renewDaysBefore: 30`
5. **多重部署**: 为关键服务配置多个部署目标
6. **SSH密钥管理**: 使用无密码密钥，妥善保管

## 技术支持

- 查看 Swagger 文档: http://localhost:5074/swagger
- 查看健康状态: http://localhost:5074/api/health
- GitHub Issues: https://github.com/qsswgl/dns-manager/issues
