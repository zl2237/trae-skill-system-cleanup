# Security Policy / 安全策略

本项目直接操作文件系统、注册表与环境变量，安全边界格外重要。

## Supported Versions / 支持版本

| Version | Supported |
| ------- | --------- |
| master  | ✅        |

## 报告漏洞 / Reporting a Vulnerability

**请不要通过公开 Issue 报告安全漏洞。**

请使用 GitHub 私密漏洞报告：
Repo 页面 → Security 标签 → Report a vulnerability，
或访问 https://github.com/zl2237/trae-skill-system-cleanup/security/advisories/new

会在 72 小时内响应。

## 本项目的安全承诺 / Security guarantees

- 所有清理/迁移操作遵循「扫描 → 报告 → 确认 → 执行」，绝不静默删除
- 注册表修改前自动导出 .reg 备份，可双击还原
- 数据外迁使用 `robocopy /MOVE`（先复制校验后删除），失败不删源
- 脚本不含任何网络上传行为，报告数据不离开本机
- 发现任何绕过确认直接执行、或向外部发送数据的代码，请立即按上述渠道报告
