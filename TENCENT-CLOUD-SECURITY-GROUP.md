# 腾讯云安全组配置指南

## 当前状态
- ✅ 5074 端口（HTTP）已开放
- ✅ 5075 端口（HTTPS）已开放
- ✅ 端口连通性测试通过

## 如何检查安全组配置

### 方法一：通过腾讯云控制台
1. 登录腾讯云控制台：https://console.cloud.tencent.com/
2. 进入 **云服务器 CVM** 控制台
3. 找到服务器实例（IP: 43.138.35.183）
4. 点击实例ID，进入详情页
5. 切换到 **安全组** 标签页
6. 查看入站规则，确认是否有以下规则：
   - TCP:5074 (来源: 0.0.0.0/0 或特定IP)
   - TCP:5075 (来源: 0.0.0.0/0 或特定IP)

### 方法二：使用命令行测试
```powershell
# 测试端口连通性
Test-NetConnection -ComputerName tx.qsgl.net -Port 5074
Test-NetConnection -ComputerName tx.qsgl.net -Port 5075

# 或使用 curl
curl http://tx.qsgl.net:5074/api/health
curl -k https://tx.qsgl.net:5075/api/health
```

## 如何添加安全组规则

### 通过腾讯云控制台添加
1. 进入安全组管理页面
2. 点击 **修改规则** 或 **添加规则**
3. 添加入站规则：
   - **类型**: 自定义
   - **协议端口**: TCP:5074 和 TCP:5075
   - **来源**: 0.0.0.0/0（所有IP）或指定IP段
   - **策略**: 允许
   - **备注**: DNSApi HTTP/HTTPS

### 使用腾讯云 CLI 添加（可选）
```bash
# 安装腾讯云 CLI
pip install tencentcloud-sdk-python

# 添加安全组规则（需要配置密钥）
tccli vpc CreateSecurityGroupPolicies \
  --SecurityGroupId sg-xxxxx \
  --SecurityGroupPolicySet.Ingress.0.Protocol TCP \
  --SecurityGroupPolicySet.Ingress.0.Port 5074-5075 \
  --SecurityGroupPolicySet.Ingress.0.CidrBlock 0.0.0.0/0 \
  --SecurityGroupPolicySet.Ingress.0.Action ACCEPT
```

## 常见端口配置

| 端口 | 协议 | 用途 | 状态 |
|------|------|------|------|
| 5074 | HTTP | DNSApi HTTP 接口 | ✅ 已开放 |
| 5075 | HTTPS | DNSApi HTTPS 接口 | ✅ 已开放 |
| 8080 | HTTP | 容器内部 HTTP | 仅内部 |
| 8443 | HTTPS | 容器内部 HTTPS | 仅内部 |
| 22 | SSH | 远程管理 | ✅ 已开放 |
| 5000 | HTTP | Docker Registry | 需要时开放 |

## 安全建议

### 生产环境
- ✅ 只开放必要的端口
- ✅ 使用 HTTPS 替代 HTTP
- ✅ 限制来源 IP（如果可能）
- ⚠️ 定期检查安全组规则
- ⚠️ 启用云防火墙日志

### 开发/测试环境
- 可以临时开放 0.0.0.0/0
- 测试完成后及时关闭不需要的端口
- 使用临时访问凭证

## 验证端口开放

### 内部验证（在服务器上）
```bash
# 检查端口监听
netstat -tlnp | grep -E '5074|5075'

# 内部访问测试
curl http://localhost:5074/api/health
curl -k https://localhost:5075/api/health
```

### 外部验证（从本地）
```powershell
# Windows PowerShell
Test-NetConnection -ComputerName tx.qsgl.net -Port 5075 -InformationLevel Detailed

# 或访问浏览器
# https://tx.qsgl.net:5075/
# http://tx.qsgl.net:5074/swagger/index.html
```

## 故障排查

### 端口无法访问
1. **检查服务是否运行**
   ```bash
   docker ps | grep dnsapi
   docker logs 8555e76ab907
   ```

2. **检查端口监听**
   ```bash
   netstat -tlnp | grep 5075
   ss -tlnp | grep 5075
   ```

3. **检查防火墙规则**
   ```bash
   iptables -L -n | grep 5075
   ufw status  # 如果使用 ufw
   ```

4. **检查腾讯云安全组**
   - 登录控制台查看规则
   - 确认规则优先级
   - 检查是否被其他规则拒绝

5. **测试网络连通性**
   ```bash
   # 在服务器上
   curl -v http://localhost:5075
   
   # 在本地
   telnet tx.qsgl.net 5075
   ```

## 相关文档
- 腾讯云安全组文档: https://cloud.tencent.com/document/product/213/12452
- DNSApi 部署文档: K:\DNS\DNSApi\README.md
- 监控系统配置: K:\DNS\MONITORING-SYSTEM-GUIDE.md

## 更新记录
- 2025-10-29: 验证 5074/5075 端口已开放并正常工作
- 2025-10-29: 完成 Swagger 文档增强部署
