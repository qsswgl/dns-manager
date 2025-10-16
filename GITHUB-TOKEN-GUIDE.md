# GitHub Token 获取指南

## 1. 创建Personal Access Token

访问GitHub Token设置页面：
https://github.com/settings/tokens/new

## 2. 配置Token权限

请确保选择以下权限范围（scopes）：

### 必需权限：
- ✅ `repo` - 完整的仓库访问权限
- ✅ `workflow` - 更新GitHub Actions工作流
- ✅ `write:packages` - 上传包到GitHub包注册表

### 可选权限：
- ✅ `delete_repo` - 删除仓库（如果需要管理仓库）
- ✅ `admin:org` - 组织管理（如果在组织中工作）

## 3. Token格式说明

正确的GitHub Personal Access Token格式：
- 经典Token: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (40字符)
- Fine-grained Token: `github_pat_xxxxxxxxxxxxxxxx` (更长)

## 4. 使用方法

### 方法1: 使用自动化脚本
```powershell
.\deploy-github.ps1 "your_actual_token_here"
```

### 方法2: 手动设置环境变量
```powershell
$env:GH_TOKEN = "your_actual_token_here"
gh auth status
```

## 5. 安全提示

⚠️ **重要提醒**：
- 不要将Token提交到代码仓库
- Token具有完整的GitHub访问权限，请妥善保管
- 建议设置Token过期时间
- 定期更换Token

## 6. 故障排查

如果遇到认证问题：

1. 检查Token是否正确复制（没有多余空格）
2. 确认Token权限包含 `repo` 范围
3. 验证Token是否已过期
4. 尝试重新生成新Token

## 7. SSH方式备用方案

如果Token方式有问题，也可以使用SSH认证：
```powershell
gh auth login --git-protocol ssh --web
```

然后在浏览器中完成认证过程。