<#
.SYNOPSIS
  磁盘文件分布盘点（模块4 - 盘点阶段，只读）
.DESCRIPTION
  各固定盘容量、一级目录大小、用户目录与 AppData 明细，为磁盘规划提供数据。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File disk-inventory.ps1 -OutDir "$env:USERPROFILE\Desktop\cleanup-report"
#>
param([string]$OutDir = "$env:USERPROFILE\Desktop\cleanup-report-$(Get-Date -Format 'yyyyMMdd')",
      [string]$HomeDir = $env:USERPROFILE)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Get-DirStat($p) {
    $s = 0; $n = 0
    Get-ChildItem -LiteralPath $p -Recurse -Force -File -EA SilentlyContinue | ForEach-Object { $s += $_.Length; $n++ }
    [PSCustomObject]@{ GB = [math]::Round($s/1GB, 2); Files = $n }
}

$vols = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object DeviceID
$result = @()
foreach ($v in $vols) {
    $root = $v.DeviceID + '\'
    $dirs = @()
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -Force -EA SilentlyContinue)) {
        if ($d.Name -in 'Windows','Users','System Volume Information','$Recycle.Bin','Recovery','Documents and Settings') { continue }
        $st = Get-DirStat $d.FullName
        $dirs += [PSCustomObject]@{ Name = $d.Name; GB = $st.GB; LastWrite = $d.LastWriteTime.ToString('yyyy-MM') }
    }
    $rootFiles = Get-ChildItem -LiteralPath $root -File -Force -EA SilentlyContinue
    $rootGB = [math]::Round((($rootFiles | Measure-Object Length -Sum).Sum)/1GB, 2)
    $result += [PSCustomObject]@{
        Drive = $v.DeviceID
        TotalGB = [math]::Round($v.Size/1GB, 0)
        FreeGB = [math]::Round($v.FreeSpace/1GB, 1)
        Dirs = ($dirs | Sort-Object GB -Descending)
        RootFilesGB = $rootGB
    }
}

# 用户目录二级 + AppData 二级（膨胀源头）
$homeDirs = @(); $appdataDirs = @()
foreach ($d in (Get-ChildItem -LiteralPath $HomeDir -Directory -Force -EA SilentlyContinue)) {
    $st = Get-DirStat $d.FullName
    if ($st.GB -gt 0.05) { $homeDirs += [PSCustomObject]@{ Name = $d.Name; GB = $st.GB } }
}
foreach ($sub in 'Local','Roaming') {
    foreach ($d in (Get-ChildItem -LiteralPath "$HomeDir\AppData\$sub" -Directory -Force -EA SilentlyContinue)) {
        $st = Get-DirStat $d.FullName
        if ($st.GB -gt 0.3) { $appdataDirs += [PSCustomObject]@{ Zone = $sub; Name = $d.Name; GB = $st.GB; LastWrite = $d.LastWriteTime.ToString('yyyy-MM') } }
    }
}

[IO.File]::WriteAllText("$OutDir\disk-inventory.json", (ConvertTo-Json -InputObject @{ Volumes = $result; HomeDirs = ($homeDirs | Sort-Object GB -Descending); AppDataDirs = ($appdataDirs | Sort-Object GB -Descending) } -Depth 5), [Text.UTF8Encoding]::new($false))

$rpt = New-Object System.Collections.Generic.List[string]
$rpt.Add("磁盘分布盘点  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
foreach ($r in $result) {
    $used = [math]::Round($r.TotalGB - $r.FreeGB, 1)
    $rpt.Add("")
    $rpt.Add("===== $($r.Drive)  总 $([math]::Round($r.TotalGB,0))GB / 已用 ${used}GB / 剩余 $($r.FreeGB)GB =====")
    $r.Dirs | ForEach-Object { $rpt.Add(('{0,10} GB  {1}  {2}' -f $_.GB, $_.LastWrite, $_.Name)) }
    if ($r.RootFilesGB -gt 0.01) { $rpt.Add(('{0,10} GB  (根目录散文件)' -f $r.RootFilesGB)) }
}
$rpt.Add("")
$rpt.Add("===== 用户目录二级(>0.05GB) =====")
$homeDirs | Sort-Object GB -Descending | ForEach-Object { $rpt.Add(('{0,10} GB  {1}' -f $_.GB, $_.Name)) }
$rpt.Add("")
$rpt.Add("===== AppData 大户(>0.3GB) =====")
$appdataDirs | Sort-Object GB -Descending | ForEach-Object { $rpt.Add(('{0,10} GB  {1}\{2}  {3}' -f $_.GB, $_.Zone, $_.Name, $_.LastWrite)) }
$rpt | Out-String | Out-File "$OutDir\disk-inventory.txt" -Encoding utf8
Write-Host "DONE -> $OutDir\disk-inventory.txt"
