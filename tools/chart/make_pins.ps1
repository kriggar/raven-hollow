# make_pins.ps1 — render the Kenney cartography symbols into MAP PINS for the
# map screen: assets/art/maps/carto/pin/*.png
#
# Two things have to happen offline rather than in the engine.
#
# 1. COLOUR. The pack draws in near-black (42,42,42). draw_texture_rect's
#    modulate MULTIPLIES, so tinting that art with map ink would land at about
#    3% grey - a black smudge, not brown ink. Pins are written pure white with
#    the original alpha, so modulate then produces exactly the colour asked for.
#
# 2. SIZE. A 64 px drawing displayed at 20 px has to lose two thirds of its
#    pixels. The project draws canvas textures with NEAREST (project.godot
#    default_texture_filter=0), which would simply drop those rows and break
#    every stroke. Resampling here with a high-quality filter keeps the strokes
#    and their antialiasing, and the engine then blits 1:1.
#
# Usage:  powershell -File tools\chart\make_pins.ps1
param([int]$Size = 20, [int]$CompassSize = 34)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$src  = Join-Path $root "assets\art\maps\carto"
$dst  = Join-Path $src  "pin"
if (-not (Test-Path $src)) { throw "symbols not found: $src" }
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }

# only the symbols the map screen actually pins, plus the rose
$wanted = @("houseChimney", "house", "houseTall", "houses", "graveyard", "gate",
            "stable", "runis", "tent", "castleTall", "church", "towerLow",
            "well", "ship", "dock", "waterWheel", "skull", "compass",
            "mill", "watchtower", "bridge", "lighthouse", "mine", "campfire")

$made = 0
foreach ($n in $wanted) {
    $p = Join-Path $src "$n.png"
    if (-not (Test-Path $p)) { Write-Output "  missing $n"; continue }
    $b = [System.Drawing.Bitmap]::FromFile($p)
    $h = if ($n -eq "compass") { $CompassSize } else { $Size }
    $w = [int][math]::Round($b.Width * $h / $b.Height)
    $o = New-Object System.Drawing.Bitmap -ArgumentList @([int]$w, [int]$h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($o)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $rect = New-Object System.Drawing.Rectangle -ArgumentList @([int]0, [int]0, [int]$w, [int]$h)
    $g.DrawImage($b, $rect)
    $g.Dispose()
    # white body, alpha carried over, and a gentle alpha lift so thin strokes
    # survive the reduction instead of fading to a suggestion
    for ($y = 0; $y -lt $o.Height; $y++) {
        for ($x = 0; $x -lt $o.Width; $x++) {
            $c = $o.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $a = [int][math]::Min(255, [math]::Round([math]::Pow($c.A / 255.0, 0.72) * 255.0))
            $o.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255))
        }
    }
    $o.Save((Join-Path $dst "$n.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $o.Dispose(); $b.Dispose()
    $made++
}
Write-Output "wrote $made pins to $dst"
