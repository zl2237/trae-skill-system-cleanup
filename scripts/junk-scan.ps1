<#
.SYNOPSIS
  扫描全盘可删除的垃圾文件（模块3 - 扫描阶段，只读不删）
.DESCRIPTION
  白名单制：只统计公认的可清理位置，不越界。每项带安全等级。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File junk-scan.ps1 -OutDir "$env:USERPROFILE\Desktop\cleanup-report"
#>
param([string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')",
      [string]$Home = $env:USERPROFILE)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$targets = @(
    @{ Name='Windows临时文件';   Path='C:\Windows\Temp';                          Level='safe' },
    @{ Name='用户临时文件';      Path="$Home\AppData\Local\Temp";                 Level='safe' },
    @{ Name='Windows更新缓存';   Path='C:\Windows\SoftwareDistribution\Download'; Level='safe' },
    @{ Name='传递优化缓存';      Path='C:\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'; Level='safe' },
    @{ Name='系统错误报告WER';   Path='C:\ProgramData\Microsoft\Windows\WER';      Level='safe' },
    @{ Name='系统小型转储';      Path='C:\Windows\Minidump';                      Level='safe' },
    @{ Name='内存转储MEMORY';    Path='C:\Windows\MEMORY.DMP';                    Level='safe' },
    @{ Name='用户崩溃转储';      Path="$Home\AppData\Local\CrashDumps";           Level='safe' },
    @{ Name='DirectX着色器缓存'; Path="$Home\AppData\Local\D3DSCache";            Level='safe' },
    @{ Name='缩略图图标缓存';    Path="$Home\AppData\Local\Microsoft\Windows\Explorer"; Level='safe-thumb' },
    @{ Name='Prefetch预读取';    Path='C:\Windows\Prefetch';                      Level='caution' },
    @{ Name='CBS系统日志';       Path='C:\Windows\Logs\CBS';                      Level='caution' },
    @{ Name='回收站';            Path='C:\$Recycle.Bin';                          Level='recycle' },
    @{ Name='Edge缓存';          Path="$Home\AppData\Local\Microsoft\Edge\User Data\*\Cache";           Level='safe' },
    @{ Name='Edge代码缓存';      Path="$Home\AppData\Local\Microsoft\Edge\User Data\*\Code Cache";      Level='safe' },
    @{ Name='Chrome缓存';        Path="$Home\AppData\Local\Google\Chrome\User Data\*\Cache";           Level='safe' },
    @{ Name='Chrome代码缓存';    Path="$Home\AppData\Local\Google\Chrome\User Data\*\Code Cache";      Level='safe' }
)

$thumbExts = '.db','.tmp'   # 缩略图目录只清这两类，避免误伤

$rows = @()
foreach ($t in $targets) {
    $paths = @(Resolve-Path -Path $t.Path -EA SilentlyContinue)
    $size = 0; $count = 0
    foreach ($rp in $paths) {
        if ($t.Level -eq 'safe-thumb') {
            Get-ChildItem -LiteralPath $rp.Path -Force -File -EA SilentlyContinue | Where-Object { $_.Extension -in $thumbExts } | ForEach-Object { $size += $_.Length; $count++ }
        } else {
            Get-ChildItem -LiteralPath $rp.Path -Recurse -Force -File -EA SilentlyContinue | ForEach-Object { $size += $_.Length; $count++ }
        }
    }
    $rows += [PSCustomObject]@{
        Name = $t.Name; Path = $t.Path; Level = $t.Level
        GB = [math]::Round($size/1GB, 3); Files = $count
    }
}

[IO.File]::WriteAllText("$OutDir\junk-scan.json", ($rows | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
$levelCn = @{ safe='可安全删除'; 'safe-thumb'='可安全删除(仅缓存文件)'; caution='谨慎删除'; recycle='清空前确认无要恢复的文件' }
$rpt = New-Object System.Collections.Generic.List[string]
$rpt.Add("垃圾文件扫描报告  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$rpt.Add("")
$rpt.Add(('{0,-18} {1,10} {2,8}  {3}' -f '项目','大小GB','文件数','建议'))
foreach ($r in ($rows | Sort-Object GB -Descending)) {
    $rpt.Add(('{0,-20} {1,10} {2,8}  {3}  {4}' -f $r.Name, $r.GB, $r.Files, $levelCn[$r.Level], $r.Path))
}
$rpt.Add("")
$rpt.Add(("合计(不含caution项): {0} GB" -f [math]::Round((($rows | Where-Object { $_.Level -notmatch 'caution' }) | Measure-Object GB -Sum).Sum, 2)))
$rpt.Add("注意: hiberfil.sys/pagefile.sys/Windows.old 不在扫描范围, 如需处理请单独说明")
$rpt | Out-String | Out-File "$OutDir\junk-report.txt" -Encoding utf8
Write-Host "DONE -> $OutDir\junk-report.txt"
