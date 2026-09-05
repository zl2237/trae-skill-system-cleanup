---
name: "system-cleanup"
description: "Windows 系统深度清理与磁盘整理工具集：失效环境变量扫描清理、已卸载软件残留清除、全盘垃圾文件(临时/日志/缓存)清理、磁盘功能规划与文件迁移。当用户提到 C盘满了/C盘瘦身/清理垃圾/环境变量太多/卸载残留/磁盘整理/分区规划 时调用。"
---

# Windows 系统清理与磁盘整理

对 Windows 系统执行四大模块的体检与清理。**所有清理动作必须经过"扫描 → 报告 → 用户确认 → 执行"四步，严禁未确认直接删除。**

## 第 0 步：确定范围（必做）

用户可能只做部分模块。必须先用 AskUserQuestion 询问（或从用户消息明确得知），选项：

1. **全部四项**
2. **模块1 环境变量**：扫描并清理失效环境变量与 PATH 死条目
3. **模块2 卸载残留**：找出已卸载软件遗留的孤儿目录
4. **模块3 垃圾清理**：全盘扫描临时文件/日志/缓存等可删文件
5. **模块4 磁盘规划**：磁盘功能划分、文件迁移、输出使用规范

## 通用安全规则（每个模块都适用）

- 扫描脚本只读不删；清理脚本必须接收 PlanFile（用户确认后的清单）才执行
- 涉及注册表写入/删除前，先 `reg export` 备份到输出目录
- 输出目录默认 `$env:USERPROFILE\Desktop\cleanup-report-<日期>\`，所有报告、备份、日志集中存放
- 脚本用 `powershell -NoProfile -ExecutionPolicy Bypass -File <path>` 运行；需要管理员权限的（HKLM、系统目录）脚本会自动 UAC 提权重启自身
- 遇到文件被占用删不掉：跳过并在日志标注，建议重启后再跑，不要强杀进程
- 永不触碰：`hiberfil.sys`、`pagefile.sys`、`Windows.old`（仅报告）、系统运行中的关键目录

## 模块 1：失效环境变量

```
扫描: scripts/env-scan.ps1 -OutDir <输出目录>
清理: scripts/clean-executor.ps1 -PlanFile <输出目录>\env-plan.json
```

1. 运行扫描，得到三类结果：PATH 死条目（路径不存在）、失效变量（值引用不存在的路径，如 *_HOME、*_PATH 类）、空值变量
2. 向用户展示报告表格，标注每项的来源（用户/系统）与影响
3. 用户确认后：把要删的项写入 env-plan.json（格式见脚本头部注释），执行清理（自动先备份 .reg）
4. 提醒：已打开的终端/IDE 需重开才生效

## 模块 2：已卸载软件残留

```
扫描: scripts/orphan-scan.ps1 -OutDir <输出目录>
清理: scripts/clean-executor.ps1 -PlanFile <输出目录>\orphan-plan.json
```

1. 扫描脚本会导出：当前已安装软件清单 + 残留高发区（LocalAppData/Roaming/ProgramData/ProgramFiles×2/用户根目录/各盘根目录）的一级目录大小
2. **由 AI 交叉比对**：孤儿目录 = 高发区里存在、但无法对应任何已安装软件的目录。注意区分：
   - 仍在用软件的数据目录（如 JetBrains、Code、npm）→ 保留
   - 系统目录（Microsoft、Packages、Common Files）→ 保留
   - 判断依据参考目录最后修改时间、大小、名称与已装软件的关联
3. 报告分两档展示：**A 档（基本确定可删）** 与 **B 档（拿不准，逐项问用户）**
4. 用户确认后写 orphan-plan.json 执行删除；卸载注册表还指向旧位置的软件提醒用户在"设置→应用"里正式卸载

## 模块 3：垃圾文件清理

```
扫描: scripts/junk-scan.ps1 -OutDir <输出目录>
清理: scripts/clean-executor.ps1 -PlanFile <输出目录>\junk-plan.json
```

1. 扫描白名单：Windows/用户 Temp、更新缓存、回收站、缩略图缓存、DirectX 着色器、WER 错误报告、崩溃转储、Prefetch、CBS 日志、浏览器 Cache（Edge/Chrome）
2. 报告中标注安全等级：可安全删除 / 清空前确认（回收站）/ 谨慎（Prefetch、CBS）
3. 用户逐项或批量确认后写 junk-plan.json 执行；结束时报告释放空间
4. 建议用户后续开启 Windows"存储感知"

## 模块 4：磁盘规划与迁移

```
盘点: scripts/disk-inventory.ps1 -OutDir <输出目录>
迁移: scripts/migrate-runner.ps1 -PlanFile <输出目录>\migrate-plan.json
```

这是交互最重的模块，**方案必须由 AI 出、用户确认后才能动文件**：

1. 运行盘点：各盘容量 + 一级目录大小 + 用户目录/AppData 明细
2. AI 基于盘点结果拟《磁盘分工方案》：
   - C = 系统盘（只留系统和必须装 C 的软件）
   - 其余盘按用户现有习惯命名（如 开发盘/生活盘），不强制盘符
   - 给出"新软件装哪"决策表、目录树、待迁移清单（源→目标，含预估大小）
3. 用 AskUserQuestion 让用户确认：迁移范围（保守=只动数据 / 激进=含工具目录）、哪些保留
4. 执行迁移：**先要求用户关闭相关软件**（聊天、网盘、虚拟机等）；migrate-plan.json 为 {source, target} 数组；robocopy /MOVE 保持数据不丢
5. 迁移后必须同步修正引用，否则工具失联：
   - PATH 中旧路径替换为新路径
   - 环境变量（*_HOME、缓存目录类）指向新位置
   - Maven settings.xml、.npmrc 等配置文件中的路径
   - 修改注册表后广播 WM_SETTINGCHANGE（脚本已内置）
6. 输出《磁盘分工与使用规范.md》到桌面，包含：分工表、新软件决策表、目录登记、防膨胀守则（存储路径设置清单）

## PlanFile 格式（三个清理脚本通用）

```json
{
  "actions": [
    { "type": "removeEnv", "scope": "User", "name": "OLD_VAR" },
    { "type": "removePathEntry", "scope": "Machine", "entry": "D:\\gone\\bin" },
    { "type": "removeDir", "path": "C:\\Users\\x\\AppData\\Local\\DeadSoft" },
    { "type": "cleanDir", "path": "C:\\Windows\\Temp", "keepEmpty": true }
  ]
}
```

## 收尾

每个模块完成后：汇总释放空间/删除项数 → 写日志到输出目录 → 桌面只留最终规范文档（模块4）或简要结果，中间报告归档到输出目录，不堆积在桌面。
