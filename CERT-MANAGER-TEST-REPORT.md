# 企业证书管理服务 - 测试报告

##  部署成功

**服务版本**: cert-manager-v3 (已标记为 latest)
**部署时间**: 2025-10-20 18:22:02
**服务地址**: http://43.138.35.183:5074

##  功能测试结果

### 1. API端点测试
-  GET /api/cert-manager/status - 系统状态
-  GET /api/cert-manager/list - 证书列表
-  POST /api/cert-manager/check - 证书检查
-  POST /api/cert-manager/renew - 证书续签
-  POST /api/cert-manager/deploy - 证书部署

### 2. 当前证书状态
- **总计**: 2 个证书
- **健康**: 2 个
- **过期**: 0 个
- **需续签**: 0 个

### 3. 管理的域名
1. **qsgl.net** (泛域名)
   - 有效期剩余: 88 天
   - 状态:  healthy
   - 部署目标: Envoy Proxy, API Server

2. **tx.qsgl.net**
   - 有效期剩余: 88 天
   - 状态:  healthy
   - 部署目标: TX Server HTTPS
   - 最后续签: 2025-10-20 10:20:53 UTC
   - 部署状态:  成功

### 4. 自动化功能
-  后台服务已启动
-  每6小时自动检查证书
-  自动续签（提前30天）
-  自动部署到配置的目标
-  部署后自动执行命令（如 nginx reload）

### 5. 部署方式测试
-  local-copy: 本地文件复制
-  docker-volume: Docker卷挂载
-  ssh: SSH/SCP远程部署

##  测试数据

### 手动续签测试
`json
{
  "success": true,
  "domain": "tx.qsgl.net",
  "renewed": "2025-10-20T10:20:53Z",
  "deployed": true,
  "deployResults": [
    {
      "name": "TX Server HTTPS",
      "success": true,
      "error": null
    }
  ]
}
`

### 系统状态查询
`json
{
  "totalCertificates": 2,
  "autoRenewEnabled": 2,
  "needsRenewal": 0,
  "expired": 0,
  "healthy": 2
}
`

##  配置信息
- 配置文件: /app/certificates.json
- 证书目录: /opt/shared-certs
- acme.sh脚本: /opt/acme-scripts
- acme.sh配置: /root/.acme.sh

##  下一步建议
1. 监控后台服务的自动续签日志
2. 配置监控告警（证书即将过期）
3. 定期查看部署状态
4. 根据需要添加更多域名到 certificates.json

##  API使用示例

### 查看所有证书
`ash
curl http://43.138.35.183:5074/api/cert-manager/list
`

### 检查特定证书
`ash
curl -X POST 'http://43.138.35.183:5074/api/cert-manager/check?domain=qsgl.net'
`

### 手动续签证书
`ash
curl -X POST 'http://43.138.35.183:5074/api/cert-manager/renew?domain=qsgl.net&deploy=true'
`

### 查看系统状态
`ash
curl http://43.138.35.183:5074/api/cert-manager/status
`

---
**报告生成时间**: 2025-10-20 18:22:02
