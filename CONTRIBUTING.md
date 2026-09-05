# 贡献指南 / Contributing

这是一个 TRAE Skill 仓库：`SKILL.md` 定义 AI 执行流程，`scripts/` 是各模块的 PowerShell 实现。

## 如何贡献

欢迎贡献以下内容：

- **新增扫描位置**：垃圾文件白名单、卸载残留目录、可外迁数据类型（给出路径依据与风险说明）
- **新模块想法**：如浏览器缓存分析、WSL 磁盘占用等
- **兼容性修复**：不同 Windows 版本 / PowerShell 版本下的路径或行为差异
- **文档**：真实清理案例、效果截图、边界情况说明

## 流程

1. Fork 或建分支开发
2. 提交 PR 并填写模板自查清单（核心红线：**任何删除都必须经用户确认**）
3. 描述清楚测试环境（Windows / PowerShell 版本）与实测输出

## 提交规范

Conventional Commits，示例：

```
feat(junk-scan): 新增 Edge 更新缓存白名单位置
fix(env-scan): 兼容 PATH 中带引号的条目
docs: README 补充真实清理案例
```

## 报告问题

- 脚本 Bug / 功能建议：[Issues](https://github.com/zl2237/trae-skill-system-cleanup/issues)
- 安全问题：[SECURITY.md](SECURITY.md)（私密渠道，勿开公开 Issue）
- 使用交流：[Discussions](https://github.com/zl2237/trae-skill-system-cleanup/discussions)
