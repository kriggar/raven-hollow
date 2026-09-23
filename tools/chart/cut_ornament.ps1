# cut_ornament.ps1 — lift a piece of engraving off its paper and save it as
# ink-with-alpha PNG, ready to composite onto the game's own parchment.
#
# WHY
# The map is to be built from DOWNLOADED ART. The best free map art in existence
# is not a game asset pack at all: it is the public-domain output of the people
# who invented this craft — Rocque's 1746 plan of London, Nolli's 1748 Rome,
# Bowen's 1748 mariner's compass. Those sheets carry rococo cartouches, engraved
# borders, compass roses and scale bars drawn by hand in copperplate.
#
# They arrive as photographs of aged paper, so they cannot simply be pasted onto
# a different parchment: they bring their own rectangle of grey-brown with them.
# This strips that. Ink density becomes ALPHA and the colour becomes a chosen
# map ink, so the piece composites onto any ground and can be tinted to match.
#
# MODES
#   -Mode ink    (default) paper -> transparent, ink -> opaque, RGB forced to -Ink
#   -Mode tile   straight crop, no keying — for texture patches (hatch, stipple)
#
# Usage:
#   powershell -File tools\chart\cut_ornament.ps1 -Src <scan.jpg> `
#     -Out assets\art\maps\ornament\cartouche.png -X 0.145 -Y 0.835 -W 0.09 -H 0.15
#   (X/Y/W/H are fractions of the source when <= 1, else absolute pixels)
param(
    [Parameter(Mandatory = $true)][string]$Src,
    [Parameter(Mandatory = $true)][string]$Out,
    [double]$X = 0, [double]$Y = 0, [double]$W = 1, [double]$H = 1,
    [ValidateSet("ink", "tile")][string]$Mode = "ink",
    # luminance treated as blank paper (fully transparent) and as solid ink
    [int]$Paper = 216, [int]$Ink = 70,
    [string]$InkColor = "2B2117",
    [double]$Gamma = 0.85,
    [switch]$Trim,
    [switch]$Oval,
    [double]$Feather = 0.12,
    [int]$MaxWidth = 0
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not [System.IO.Path]::IsPathRooted($Src)) { $Src = Join-Path $root $Src }
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $root $Out }
if (-not (Test-Path $Src)) { throw "source not found: $Src" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null

$code = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class RHCut
{
    public static void Run(string src, string dst, double fx, double fy, double fw, double fh,
        string mode, int paper, int ink, int inkR, int inkG, int inkB, double gamma, bool trim, int maxWidth,
        bool oval, double feather)
    {
        using (Bitmap sb = new Bitmap(src))
        {
            int X = (int)(fx <= 1.0 ? fx * sb.Width : fx);
            int Y = (int)(fy <= 1.0 ? fy * sb.Height : fy);
            int W = (int)(fw <= 1.0 ? fw * sb.Width : fw);
            int H = (int)(fh <= 1.0 ? fh * sb.Height : fh);
            X = Math.Max(0, Math.Min(sb.Width - 1, X));
            Y = Math.Max(0, Math.Min(sb.Height - 1, Y));
            W = Math.Max(1, Math.Min(sb.Width - X, W));
            H = Math.Max(1, Math.Min(sb.Height - Y, H));

            using (Bitmap cut = sb.Clone(new Rectangle(X, Y, W, H), PixelFormat.Format32bppArgb))
            {
                Bitmap result = (mode == "tile") ? (Bitmap)cut.Clone()
                                                 : Key(cut, paper, ink, inkR, inkG, inkB, gamma);
                if (oval && mode != "tile") Oval(result, feather);
                if (trim && mode != "tile") { Bitmap t = Trim(result); result.Dispose(); result = t; }
                if (maxWidth > 0 && result.Width > maxWidth)
                {
                    int nh = (int)Math.Round(result.Height * (maxWidth / (double)result.Width));
                    Bitmap r2 = new Bitmap(maxWidth, nh, PixelFormat.Format32bppArgb);
                    using (Graphics g = Graphics.FromImage(r2))
                    {
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        g.Clear(Color.Transparent);
                        g.DrawImage(result, new Rectangle(0, 0, maxWidth, nh));
                    }
                    result.Dispose(); result = r2;
                }
                result.Save(dst, ImageFormat.Png);
                Console.WriteLine(String.Format("  cut {0}x{1} from ({2},{3}) {4}x{5} -> {6}x{7}",
                    W, H, X, Y, sb.Width, sb.Height, result.Width, result.Height));
                result.Dispose();
            }
        }
    }

    // Ink density becomes alpha. A scan's blank paper is never one value, so
    // everything at or above `paper` goes fully clear and everything at or below
    // `ink` goes fully solid, with a gamma on the ramp to keep fine hatching
    // from dissolving.
    static Bitmap Key(Bitmap src, int paper, int ink, int r, int g, int b, double gamma)
    {
        int W = src.Width, H = src.Height;
        Bitmap outBmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        BitmapData sd = src.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData od = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] si = new byte[sd.Stride * H];
        byte[] oi = new byte[od.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(sd.Scan0, si, 0, si.Length);
        double span = Math.Max(1.0, paper - ink);
        for (int y = 0; y < H; y++)
        {
            int sr = y * sd.Stride, orow = y * od.Stride;
            for (int x = 0; x < W; x++)
            {
                int i = sr + x * 4, o = orow + x * 4;
                double lum = 0.30 * si[i + 2] + 0.59 * si[i + 1] + 0.11 * si[i];
                double a = (paper - lum) / span;
                if (a < 0) a = 0; if (a > 1) a = 1;
                a = Math.Pow(a, gamma);
                oi[o] = (byte)b; oi[o + 1] = (byte)g; oi[o + 2] = (byte)r;
                oi[o + 3] = (byte)Math.Round(a * 255.0);
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(oi, 0, od.Scan0, oi.Length);
        src.UnlockBits(sd); outBmp.UnlockBits(od);
        return outBmp;
    }

    // A cartouche sits in the middle of a busy map, so a rectangular crop always
    // brings a fringe of somebody else's streets with it. Fading alpha away
    // outside an inscribed ellipse cuts the ornament free without a hand-drawn
    // mask, and the feathered edge reads as the engraving simply stopping.
    static void Oval(Bitmap bm, double feather)
    {
        int W = bm.Width, H = bm.Height;
        BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        double cx = W * 0.5, cy = H * 0.5;
        double f = Math.Max(0.01, feather);
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            double ny = (y - cy) / cy;
            for (int x = 0; x < W; x++)
            {
                double nx = (x - cx) / cx;
                double d = Math.Sqrt(nx * nx + ny * ny);
                double k = 1.0;
                if (d > 1.0 - f) k = Math.Max(0.0, (1.0 - d) / f);
                if (k >= 1.0) continue;
                int i = row + x * 4;
                buf[i + 3] = (byte)Math.Round(buf[i + 3] * k);
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bm.UnlockBits(bd);
    }

    // Drop fully-transparent margins so the piece can be placed by its own edges.
    static Bitmap Trim(Bitmap src)
    {
        int W = src.Width, H = src.Height;
        int x0 = W, y0 = H, x1 = -1, y1 = -1;
        BitmapData bd = src.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        src.UnlockBits(bd);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
                if (buf[y * bd.Stride + x * 4 + 3] > 14)
                {
                    if (x < x0) x0 = x; if (x > x1) x1 = x;
                    if (y < y0) y0 = y; if (y > y1) y1 = y;
                }
        if (x1 < 0) return (Bitmap)src.Clone();
        return src.Clone(new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1), PixelFormat.Format32bppArgb);
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing -ErrorAction Stop

$r = [Convert]::ToInt32($InkColor.Substring(0, 2), 16)
$g = [Convert]::ToInt32($InkColor.Substring(2, 2), 16)
$b = [Convert]::ToInt32($InkColor.Substring(4, 2), 16)
Write-Output "cutting $([IO.Path]::GetFileName($Src)) -> $([IO.Path]::GetFileName($Out))  [$Mode]"
[RHCut]::Run($Src, $Out, $X, $Y, $W, $H, $Mode, $Paper, $Ink, $r, $g, $b, $Gamma, [bool]$Trim, $MaxWidth, [bool]$Oval, $Feather)
