# trae-skill-system-cleanup

一个 [TRAE](https://trae.cn) Skill：Windows 系统深度清理与磁盘整理。加载后对 AI 说"清理 C 盘 / 整理环境变量 / 找卸载残留 / 磁盘规划"，AI 会按本 skill 的流程先扫描、出报告，**经你确认后**才执行清理。

## 真实效果：一次完整的清理（2026-09-05）

一台使用多年的开发机，一个下午跑完全部四个模块，C 盘剩余空间 **36.84 GB → 99.49 GB，净释放约 62.6 GB**：

| 阶段 | 做了什么 | 结果 |
|---|---|---|
| 环境变量 | 删除 18 个失效系统变量、2 个失效用户变量、7 条 PATH 死条目（删前自动备份 .reg，可双击还原） | PATH 干净，排查环境问题不再被死路径干扰 |
| 垃圾清理 | 扫描 18 项白名单位置（临时文件/崩溃转储/回收站/缓存），逐项确认后清理 | **释放 5.83 GB** |
| 数据外迁 | QQ 接收文件、虚拟机、Gradle/Maven/pip/npm/Playwright 缓存、Android SDK、Rust 工具链等 14 项迁出 C 盘，并同步改写 8 个环境变量 + Maven/npm 配置，工具不断链 | **释放 39.92 GB** |
| 卸载残留 | 与 287 个已安装软件交叉比对，A/B 分档确认后删除 57 个孤儿目录（钉钉/Epic/Steam/360 等卸载遗留） | **释放 9.76 GB** |
| 收尾 | 输出《磁盘分工与软件安装规范》，明确每个盘放什么、新软件装哪 | 防止 C 盘再次膨胀 |

> 全程遵循「扫描 → 报告 → 确认 → 执行」：每一项删除/迁移都经用户确认，注册表先备份，迁移用 robocopy /MOVE 数据不丢。


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
git clone https://github.com/zl2237/trae-skill-system-cleanup.git "$env:USERPROFILE\.trae-cn\skills\system-cleanup"
```

### 项目级安装（仅当前项目）

```powershell
git clone https://github.com/zl2237/trae-skill-system-cleanup.git .trae\skills\system-cleanup
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

---

如果这个 skill 帮你清出了空间，欢迎点一个 ⭐ Star，让更多被 C 盘爆满折磨的人看到它。
