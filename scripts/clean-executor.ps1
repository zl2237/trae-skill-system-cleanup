<#
.SYNOPSIS
  统一清理执行器（模块1/2/3 - 执行阶段）
.DESCRIPTION
  读取用户确认过的 PlanFile(JSON)，执行四类动作并写日志。自动 UAC 提权、注册表先备份、改完广播。
.PLANFILE 格式
  { "actions": [
      { "type": "removeEnv",       "scope": "User",    "name": "OLD_VAR" },
      { "type": "removePathEntry", "scope": "Machine", "entry": "D:\\gone\\bin" },
      { "type": "removeDir",       "path": "C:\\Users\\x\\AppData\\Local\\DeadSoft" },
      { "type": "cleanDir",        "path": "C:\\Windows\\Temp", "keepEmpty": true }
  ] }
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File clean-executor.ps1 -PlanFile plan.json -OutDir report
#>
param(
    [Parameter(Mandatory = $true)][string]$PlanFile,
    [string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')"
)
$ErrorActionPreference = 'Continue'

$plan = Get-Content $PlanFile -Raw -Encoding UTF8 | ConvertFrom-Json
$needAdmin = $false
foreach ($a in $plan.actions) {
    if ($a.scope -eq 'Machine') { $needAdmin = $true }
    if ($a.path -and ($a.path -like "$env:ProgramFiles*" -or $a.path -like "${env:ProgramFiles(x86)}*" -or $a.path -like 'C:\ProgramData*' -or $a.path -like 'C:\Windows*')) { $needAdmin = $true }
}
if ($needAdmin) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -PlanFile `"$PlanFile`" -OutDir `"$OutDir`""
        exit
    }
    # 提权窗口防误点暂停
    Add-Type -Namespace K32 -Name Con -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);'
    $hh = [K32.Con]::GetStdHandle(-10); $mm = 0
    [void][K32.Con]::GetConsoleMode($hh, [ref]$mm)
    [void][K32.Con]::SetConsoleMode($hh, ($mm -band (-bnot 0x40)) -bor 0x80)
}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$logPath = "$OutDir\clean-log-$(Get-Date -Format 'HHmmss').txt"
$log = New-Object System.Collections.Generic.List[string]
function Log($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c; $script:log.Add($m) }

# 涉及环境变量的动作：先 reg export 备份
$hasEnvAction = ($plan.actions | Where-Object { $_.type -in 'removeEnv','removePathEntry' }).Count -gt 0
if ($hasEnvAction) {
    $bakUser = "$OutDir\backup-env-User.reg"
    $bakMachine = "$OutDir\backup-env-Machine.reg"
    reg.exe export 'HKCU\Environment' $bakUser /y | Out-Null
    reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' $bakMachine /y | Out-Null
    Log "[备份] $bakUser / $bakMachine (双击.reg可还原,Machine需管理员)" 'Green'
}

$opt = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
$done = 0; $fail = 0
foreach ($a in $plan.actions) {
    switch ($a.type) {
        'removeEnv' {
            $root = if ($a.scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
            $sub = if ($a.scope -eq 'Machine') { 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' } else { 'Environment' }
            $k = $root.OpenSubKey($sub, $true)
            if ($k) { $k.DeleteValue($a.name, $false); $k.Close(); Log "[env 删变量][$($a.scope)] $($a.name)" 'Green'; $done++ }
            else { Log "[env 失败] 打不开注册表 $($a.scope)" 'Red'; $fail++ }
        }
        'removePathEntry' {
            $root = if ($a.scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
            $sub = if ($a.scope -eq 'Machine') { 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' } else { 'Environment' }
            $k = $root.OpenSubKey($sub, $true)
            if ($k) {
                $raw = $k.GetValue('Path', '', $opt)
                $kept = @()
                foreach ($e in ($raw -split ';')) {
                    if ([string]::IsNullOrWhiteSpace($e)) { continue }
                    if ($e.Trim() -ieq $a.entry.Trim()) { continue }
                    $kept += $e
                }
                $k.SetValue('Path', ($kept -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
                $k.Close(); Log "[env 删PATH条目][$($a.scope)] $($a.entry)" 'Green'; $done++
            } else { Log "[env 失败] $($a.entry)" 'Red'; $fail++ }
        }
        'removeDir' {
            if (Test-Path -LiteralPath $a.path) {
                Remove-Item -LiteralPath $a.path -Recurse -Force -EA SilentlyContinue
                if (Test-Path -LiteralPath $a.path) { Log "[目录 部分占用未删尽] $($a.path)" 'Yellow'; $fail++ }
                else { Log "[目录 已删] $($a.path)" 'Green'; $done++ }
            } else { Log "[目录 不存在] $($a.path)" 'DarkGray' }
        }
        'cleanDir' {
            if (Test-Path -LiteralPath $a.path) {
                $freed = 0
                Get-ChildItem -LiteralPath $a.path -Recurse -Force -EA SilentlyContinue |
                    Where-Object { $_.PSIsContainer -eq $false } |
                    ForEach-Object { $freed += $_.Length; Remove-Item -LiteralPath $_.FullName -Force -EA SilentlyContinue }
                Log ("[清空] {0}  释放约 {1} MB" -f $a.path, [math]::Round($freed/1MB,1)) 'Green'; $done++
            } else { Log "[清空] 不存在 $($a.path)" 'DarkGray' }
        }
        default { Log "[跳过] 未知类型 $($a.type)" 'Yellow' }
    }
}

# 广播环境变量变更
if ($hasEnvAction) {
    Add-Type -Namespace Win32 -Name NM -MemberDefinition '[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
    [UIntPtr]$rr = [UIntPtr]::Zero
    [void][Win32.NM]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$rr)
}

$cFree = [math]::Round((Get-PSDrive C).Free/1GB, 2)
Log ""
Log ("完成: 成功 {0} / 失败或部分 {1}   C盘剩余 {2} GB" -f $done, $fail, $cFree) 'Cyan'
$log | Out-String | Out-File $logPath -Encoding utf8
Write-Host "日志: $logPath"
