<#
.SYNOPSIS
  扫描已卸载软件的残留目录（模块2 - 扫描阶段，只读不删）
.DESCRIPTION
  导出两份数据：①当前已安装软件清单 ②残留高发区一级目录大小清单。
  交叉比对由 AI 完成（区分"孤儿目录"与"在用软件数据目录"）。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File orphan-scan.ps1 -OutDir "$env:USERPROFILE\Desktop\cleanup-report"
#>
param(
    [string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')",
    [string[]]$ExtraDirs = @()    # 额外要扫描的目录（如 D:\ E:\ 根目录）
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# 1. 已安装软件清单
$roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
         'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
         'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$installed = @()
foreach ($r in $roots) {
    Get-ChildItem $r -EA SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -EA SilentlyContinue
        if ($p.DisplayName) {
            $installed += [PSCustomObject]@{ Name = $p.DisplayName; Location = $p.InstallLocation; Uninstall = $p.UninstallString }
        }
    }
}

# 2. 残留高发区
$sysSkip = 'Windows','Users','Program Files','Program Files (x86)','ProgramData','System Volume Information','$Recycle.Bin','Recovery','PerfLogs','OneDrive','OneDriveTemp','Documents and Settings'
$homeSkip = 'AppData','Desktop','Documents','Downloads','Pictures','Videos','Music','Favorites','Links','Searches','Saved Games','Contacts','3D Objects','OneDrive','NetHood','PrintHood','Recent','SendTo','Templates','「开始」菜单','My Documents','Local Settings'
$locs = @(
    @{ N = 'AppData\Local';  P = $env:LOCALAPPDATA; Skip = @() },
    @{ N = 'AppData\Roaming'; P = $env:APPDATA;      Skip = @() },
    @{ N = 'ProgramData';    P = 'C:\ProgramData';   Skip = @('Microsoft','USOShared','USOPrivate','chocolatey','Package Cache','regid.1991-06.com.microsoft','Windows Master Setup','License managers') },
    @{ N = 'ProgramFiles';   P = $env:ProgramFiles;  Skip = @() },
    @{ N = 'ProgramFilesX86'; P = ${env:ProgramFiles(x86)}; Skip = @() },
    @{ N = 'UserHome';       P = $env:USERPROFILE;   Skip = $homeSkip }
)
foreach ($e in $ExtraDirs) { $locs += @{ N = "Extra:$e"; P = $e; Skip = $sysSkip } }

function Get-DirStat($p) {
    $s = 0; $n = 0
    Get-ChildItem -LiteralPath $p -Recurse -Force -File -EA SilentlyContinue | ForEach-Object { $s += $_.Length; $n++ }
    [PSCustomObject]@{ GB = [math]::Round($s/1GB, 3); Files = $n }
}

$dirs = @()
foreach ($l in $locs) {
    if (-not $l.P -or -not (Test-Path $l.P)) { continue }
    foreach ($d in (Get-ChildItem -LiteralPath $l.P -Directory -Force -EA SilentlyContinue)) {
        if ($d.Name -like '.*trae*' -or $d.Name -in $l.Skip) { continue }
        if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }   # 跳过junction
        $st = Get-DirStat $d.FullName
        if ($st.GB -lt 0.001) { continue }
        $dirs += [PSCustomObject]@{
            Zone = $l.N; Name = $d.Name; Path = $d.FullName
            GB = $st.GB; Files = $st.Files; LastWrite = $d.LastWriteTime.ToString('yyyy-MM')
        }
    }
}

# 输出
[IO.File]::WriteAllText("$OutDir\installed.json", ($installed | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText("$OutDir\dirs.json", ($dirs | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
$rpt = New-Object System.Collections.Generic.List[string]
$rpt.Add("卸载残留扫描  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')   已安装软件 $($installed.Count) 个 / 高发区目录 $($dirs.Count) 个")
$rpt.Add("交叉比对需 AI 完成: dirs.json 中无法对应 installed.json 任何软件、且长期未更新的目录 = 疑似孤儿")
$rpt.Add("")
foreach ($g in ($dirs | Group-Object Zone)) {
    $rpt.Add("===== $($g.Name) =====")
    $g.Group | Sort-Object GB -Descending | Select-Object -First 40 | ForEach-Object {
        $rpt.Add(('{0,8} GB  {1}  {2}  ({2})' -f $_.GB, $_.LastWrite, $_.Name))
    }
}
$rpt | Out-String | Out-File "$OutDir\orphan-report.txt" -Encoding utf8
Write-Host "DONE -> $OutDir (installed $($installed.Count), dirs $($dirs.Count))"
