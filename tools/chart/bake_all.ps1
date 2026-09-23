# bake_all.ps1 — chart every zone plate in assets/art/maps.
#
# Skips anything already ending in _chart, and skips plates whose chart is
# newer than the plate unless -Force is given.
param([switch]$Force, [string]$Only = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$maps = Join-Path $root "assets\art\maps"
$bake = Join-Path $PSScriptRoot "bake_chart.ps1"

$plates = Get-ChildItem $maps -Filter *.png | Where-Object { $_.BaseName -notlike "*_chart" }
if ($Only -ne "") { $plates = $plates | Where-Object { $_.BaseName -eq $Only } }

$done = 0; $skipped = 0; $failed = @()
foreach ($p in $plates) {
    $out = Join-Path $maps ($p.BaseName + "_chart.png")
    if ((-not $Force) -and (Test-Path $out) -and ((Get-Item $out).LastWriteTime -gt $p.LastWriteTime)) {
        $skipped++; continue
    }
    # a stable per-zone seed so a rebake reproduces the same sheet
    $seed = 0
    foreach ($ch in $p.BaseName.ToCharArray()) { $seed = ($seed * 131 + [int]$ch) % 2147483647 }
    try {
        $r = & powershell -NoProfile -ExecutionPolicy Bypass -File $bake -Src $p.FullName -Out $out -Seed $seed 2>&1
        $line = ($r | Where-Object { $_ -match "canopy texture split" })
        Write-Output ("{0,-22} {1}" -f $p.BaseName, ($line -replace "^\s+", ""))
        $done++
    } catch {
        $failed += $p.BaseName
        Write-Output ("{0,-22} FAILED: {1}" -f $p.BaseName, $_.Exception.Message)
    }
}
Write-Output ""
Write-Output "charted $done, skipped $skipped, failed $($failed.Count)"
if ($failed.Count -gt 0) { Write-Output ("failed: " + ($failed -join ", ")) }
