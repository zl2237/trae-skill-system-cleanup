<#
.SYNOPSIS
  跨目录/跨盘迁移执行器（模块4 - 执行阶段）
.DESCRIPTION
  按用户确认过的 PlanFile 用 robocopy /MOVE 迁移（数据不丢，源删失败目标仍在）。
  执行前要求已关闭相关软件。同卷自动改为 Move-Item（瞬间完成）。
.PLANFILE 格式
  { "moves": [ { "source": "C:\\Users\\x\\BigData", "target": "D:\\Data\\BigData" } ] }
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File migrate-runner.ps1 -PlanFile migrate-plan.json -OutDir report
#>
param(
    [Parameter(Mandatory = $true)][string]$PlanFile,
    [string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')"
)
$ErrorActionPreference = 'Continue'
$plan = Get-Content $PlanFile -Raw -Encoding UTF8 | ConvertFrom-Json
$needAdmin = $false
foreach ($m in $plan.moves) {
    if ($m.source -like 'C:\Users\*' -and $m.source -notlike "$env:USERPROFILE*") { $needAdmin = $true }
    if ($m.source -like 'C:\ProgramData*' -or $m.source -like 'C:\Windows*') { $needAdmin = $true }
}
if ($needAdmin) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -PlanFile `"$PlanFile`" -OutDir `"$OutDir`""
        exit
    }
    Add-Type -Namespace K32 -Name Con -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);'
    $hh = [K32.Con]::GetStdHandle(-10); $mm = 0
    [void][K32.Con]::GetConsoleMode($hh, [ref]$mm)
    [void][K32.Con]::SetConsoleMode($hh, ($mm -band (-bnot 0x40)) -bor 0x80)
}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$logPath = "$OutDir\migrate-log-$(Get-Date -Format 'HHmmss').txt"
$log = New-Object System.Collections.Generic.List[string]
function Log($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c; $script:log.Add($m) }
Log "========== 迁移开始 $(Get-Date -Format 'HH:mm:ss') ==========" 'Cyan'

$i = 0; $total = $plan.moves.Count
foreach ($m in $plan.moves) {
    $i++
    if (-not (Test-Path -LiteralPath $m.source)) { Log "[$i/$total] 源不存在,跳过: $($m.source)" 'DarkGray'; continue }
    $srcRoot = [IO.Path]::GetPathRoot($m.source)
    $dstRoot = [IO.Path]::GetPathRoot($m.target)
    New-Item -ItemType Directory -Path (Split-Path $m.target -Parent) -Force | Out-Null
    if ($srcRoot -ieq $dstRoot) {
        # 同卷: 移动即可
        if (Test-Path -LiteralPath $m.target) { Log "[$i/$total] 目标已存在,跳过: $($m.target)" 'Yellow'; continue }
        Move-Item -LiteralPath $m.source -Destination $m.target -Force
        Log "[$i/$total] 已移动(同卷): $($m.source) -> $($m.target)" 'Green'
    } else {
        # 跨卷: robocopy /MOVE
        robocopy $m.source $m.target /E /MOVE /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
        $code = $LASTEXITCODE
        if ($code -le 7) {
            if (Test-Path -LiteralPath $m.source) { Log "[$i/$total] 完成(源有少量占用残留): $($m.target)" 'Yellow' }
            else { Log "[$i/$total] 已迁移: $($m.source) -> $($m.target)" 'Green' }
        } else {
            Log "[$i/$total] 异常 robocopy=$code : $($m.source)" 'Red'
        }
    }
}
Log ""
Log "迁移结束。提示: 引用旧路径的 PATH/环境变量/软件内设置需同步更新" 'Cyan'
$log | Out-String | Out-File $logPath -Encoding utf8
Write-Host "日志: $logPath"
