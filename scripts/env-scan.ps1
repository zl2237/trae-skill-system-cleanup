<#
.SYNOPSIS
  扫描失效环境变量（模块1 - 扫描阶段，只读不删）
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File env-scan.ps1 -OutDir "$env:USERPROFILE\Desktop\cleanup-report"
.OUTPUT
  env-scan.json（机器可读，含建议动作）、env-report.txt（人类可读）
#>
param([string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')")
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$opt = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
$scopes = @(
    @{ Name = 'Machine'; Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment') },
    @{ Name = 'User';    Key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment') }
)

function Test-EntryPath([string]$entry) {
    # PATH 条目：展开环境变量后验证存在
    if ([string]::IsNullOrWhiteSpace($entry)) { return 'empty' }
    $expanded = [Environment]::ExpandEnvironmentVariables($entry)
    if ($expanded -match '^[A-Za-z]:\\') {
        if (Test-Path -LiteralPath $expanded) { return 'ok' } else { return 'missing' }
    }
    return 'unknown'   # 相对路径或特殊形式，不判定
}

$issues = @()
foreach ($s in $scopes) {
    if (-not $s.Key) { continue }
    foreach ($vn in $s.Key.GetValueNames()) {
        $raw = $s.Key.GetValue($vn, '', $opt)
        if ($vn -ieq 'PATH') {
            $idx = 0
            foreach ($e in ($raw -split ';')) {
                $st = Test-EntryPath $e
                if ($st -eq 'empty') {
                    $issues += [PSCustomObject]@{ Scope=$s.Name; Kind='pathEmpty'; Var='Path'; Entry=$e; Suggest='removePathEntry' }
                } elseif ($st -eq 'missing') {
                    $issues += [PSCustomObject]@{ Scope=$s.Name; Kind='pathMissing'; Var='Path'; Entry=$e; Suggest='removePathEntry' }
                }
                $idx++
            }
        } else {
            if ([string]::IsNullOrWhiteSpace([string]$raw)) {
                $issues += [PSCustomObject]@{ Scope=$s.Name; Kind='emptyVar'; Var=$vn; Entry=''; Suggest='removeEnv' }
            } else {
                $expanded = [Environment]::ExpandEnvironmentVariables([string]$raw)
                foreach ($m in [regex]::Matches($expanded, '[A-Za-z]:\\[^\s;"|,]+')) {
                    # 含空格路径校正: 取该位置到下一个';'的宽候选再验证, 避免 "C:\Program Files\X" 被截成 "C:\Program"
                    $rest = $expanded.Substring($m.Index)
                    $wide = (($rest -split ';')[0]).TrimEnd()
                    if (-not (Test-Path -LiteralPath $wide)) {
                        $issues += [PSCustomObject]@{ Scope=$s.Name; Kind='invalidRef'; Var=$vn; Entry=$wide; Suggest='confirm' }
                        break   # 每变量只记第一条失效引用
                    }
                }
            }
        }
    }
}

$issues | ConvertTo-Json -Depth 4 | Out-File "$OutDir\env-scan.json" -Encoding utf8
$rpt = New-Object System.Collections.Generic.List[string]
$rpt.Add("环境变量扫描报告  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$rpt.Add("PATH死条目/空条目/空变量/失效引用 共 $($issues.Count) 项")
$rpt.Add("")
if ($issues.Count -eq 0) { $rpt.Add("未发现失效环境变量") }
else {
    $rpt.Add(('{0,-8} {1,-12} {2,-20} {3}' -f '范围','类型','变量','条目/引用'))
    foreach ($i in $issues) {
        $kindCn = @{ pathEmpty='PATH空条目'; pathMissing='PATH死条目'; emptyVar='空变量'; invalidRef='值引用的路径不存在' }[$i.Kind]
        $rpt.Add(("{0,-8} {1,-14} {2,-22} {3}" -f $i.Scope, $kindCn, $i.Var, $i.Entry))
    }
    $rpt.Add("")
    $rpt.Add("说明: pathEmpty/pathMissing/emptyVar 可安全清理; invalidRef 需人工判断(可能是参数而非路径)")
}
$rpt | Out-String | Out-File "$OutDir\env-report.txt" -Encoding utf8
Write-Host "DONE -> $OutDir\env-report.txt ($($issues.Count) issues)"
