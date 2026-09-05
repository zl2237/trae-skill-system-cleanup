# trae-skill-system-cleanup

一个 [TRAE](https://trae.cn) Skill：Windows 系统深度清理与磁盘整理。加载后对 AI 说"清理 C 盘 / 整理环境变量 / 找卸载残留 / 磁盘规划"，AI 会按本 skill 的流程先扫描、出报告，**经你确认后**才执行清理。

## 四大模块（可全做，也可任选几项）

| 模块 | 功能 | 安全机制 |
|---|---|---|
| 1 环境变量 | 扫描并清理失效环境变量、PATH 死条目 | 删前自动 reg export 备份，可双击还原 |
| 2 卸载残留 | 找出已卸载软件遗留的孤儿目录（AppData/ProgramData 等） | AI 交叉比对已安装清单，A/B 分档逐项确认 |
| 3 垃圾清理 | 临时文件/日志/缓存/回收站/浏览器缓存等 | 白名单制，分安全等级逐项确认 |
| 4 磁盘规划 | 磁盘功能划分、文件跨盘迁移、输出使用规范文档 | 方案先行、确认后 robocopy /MOVE（数据不丢） |

## 安装

### 全局安装（推荐，所有项目可用）

```powershell
git clone https://github.com/<你的用户名>/trae-skill-system-cleanup.git "$env:USERPROFILE\.trae-cn\skills\system-cleanup"
```

### 项目级安装（仅当前项目）

```powershell
git clone https://github.com/<你的用户名>/trae-skill-system-cleanup.git .trae\skills\system-cleanup
```

也可以直接下载 ZIP 解压到上述目录（目录名保持 `system-cleanup`）。

## 使用

安装后**重启 TRAE / 新开会话**，直接对 AI 说：

- 「帮我清理一下 C 盘垃圾」
- 「我环境变量好多，帮我看看哪些失效了」
- 「找找有没有已卸载软件的残留文件」
- 「C 盘快满了，帮我做磁盘规划」

AI 会先问你做哪几项（或全做），然后扫描 → 报告 → 你确认 → 执行。所有报告/备份/日志集中存放在 `桌面\cleanup-report-<日期>\`。

## 目录结构

```
system-cleanup/
├── SKILL.md                  # AI 编排指令（skill 入口）
└── scripts/
    ├── env-scan.ps1          # 模块1 扫描：失效环境变量
    ├── orphan-scan.ps1       # 模块2 扫描：已装软件清单 + 高发区目录
    ├── junk-scan.ps1         # 模块3 扫描：垃圾文件白名单
    ├── disk-inventory.ps1    # 模块4 盘点：磁盘分布
    ├── clean-executor.ps1    # 统一执行器（删变量/删PATH条目/删目录/清空目录）
    └── migrate-runner.ps1    # 迁移执行器（同卷移动/跨卷 robocopy /MOVE）
```

## 系统要求

- Windows 10/11，PowerShell 5.1+（系统自带，无需额外安装）
- 涉及系统级操作时脚本会自动申请管理员权限（UAC 弹窗）

## 安全说明

- 扫描脚本**只读不删**；所有删除动作必须由你确认 PlanFile 后才执行
- 注册表修改前自动备份 `.reg`，双击即可还原
- 永不触碰 `hiberfil.sys`、`pagefile.sys`、`Windows.old` 等系统文件（仅报告）
- 文件被占用时跳过并在日志标注，不强杀进程

## License

MIT
