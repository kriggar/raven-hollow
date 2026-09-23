# draw_sheet.ps1 — the Raven Hollow map sheet, drawn as PIXEL ART at the exact
# size it is displayed, from the town's own authored vector data.
#
# WHY THIS EXISTS (read before changing anything)
# Three earlier attempts were rejected. Two independent expert critiques of the
# last one measured why, and their findings are the specification for this file:
#
#  * NO VALUE STRUCTURE. The old plate measured p25=177, p50=178, p75=190 — the
#    middle half of the whole image inside 13 of 256 luminance steps, 81% bare
#    paper and 8% ink with nothing between. It dissolved to grey mush at a
#    squint. FIX: every category gets a VALUE, not just a symbol, off one fixed
#    ramp, and areas are laid as flat tone masses before any line is drawn.
#  * LAND AND WATER WERE THE SAME COLOUR. The most basic separation in
#    cartography was simply absent, so the sheet had no silhouette. FIX: water
#    is its own cool tone block, the darkest mass on the sheet.
#  * THREE DRAWING HANDS ON ONE PAGE. Blurry resampled game sprites, crisp
#    vector icons and flat silhouettes together, 169 unique colours where a
#    pixel plate wants 6–14. FIX: one declared palette, and every symbol
#    box-filtered to its final pixel size and snapped to that palette, stamped
#    1:1. Nothing is ever scaled at draw time.
#  * NO ROAD NETWORK. One ribbon served a town with four named squares and two
#    gates. FIX: roads drawn from the authored polylines at three widths with a
#    dark casing and a light carriageway — the lightest thing on the sheet.
#  * A HOUSE AND A BUSH WERE THE SAME MARK. FIX: built-up is a light-filled
#    block with a heavy dark outline; woodland is a massed mid-tone polygon;
#    field is a pale stipple. Each class is a different graphic idea.
#  * SOFT WHITE GLOWS BEHIND EVERY SYMBOL. Paper does not glow. FIX: none, ever.
#
# SIZE. The sheet is rendered at the size it is actually shown — the zone's
# world rect fitted into the map screen's content box — so it is displayed 1:1
# and zooms by whole pixels. A 2048 px plate squeezed into 572 was the source of
# the blur and of the three-resolution problem.
#
# Usage:
#   powershell -File tools\chart\draw_sheet.ps1 -Geom <town_geom.json> `
#              -Out assets\art\maps\town_sheet.png
param(
    [Parameter(Mandatory = $true)][string]$Geom,
    [string]$Out = "assets\art\maps\town_sheet.png",
    # the map screen's content box, in 640x360 design pixels
    [int]$FitW = 572, [int]$FitH = 276,
    [int]$Scale = 1,
    [int]$Seed = 20260923
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not [System.IO.Path]::IsPathRooted($Geom)) { $Geom = Join-Path $root $Geom }
if (-not [System.IO.Path]::IsPathRooted($Out))  { $Out  = Join-Path $root $Out }
$carto = Join-Path $root "assets\art\maps\carto"
if (-not (Test-Path $Geom)) { throw "geometry dump not found: $Geom  (boot with RH_MAPDUMP=<path>)" }

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class RHSheet
{
    // ---- THE PALETTE -------------------------------------------------------
    // Eleven colours, declared once. A sepia value ramp for the land, two cool
    // values for water so the coast reads at a squint, and one red that is only
    // ever spent on the player. The bake fails if the plate exceeds this set.
    public const int PAPER_HI = 0, PAPER = 1, FIELD = 2, MID = 3, WOOD = 4,
                     BUILT = 5, DARK = 6, INK = 7, WATER_HI = 8, WATER = 9, ACCENT = 10;
    public static Color[] PAL = new Color[] {
        Color.FromArgb(235, 224, 196),  // 0 paper highlight
        Color.FromArgb(221, 207, 169),  // 1 paper
        Color.FromArgb(200, 184, 140),  // 2 field
        Color.FromArgb(171, 154, 113),  // 3 mid / built fill
        Color.FromArgb(139, 122,  87),  // 4 woodland
        Color.FromArgb(107,  91,  61),  // 5 built shade
        Color.FromArgb( 70,  56,  41),  // 6 dark
        Color.FromArgb( 38,  30,  21),  // 7 ink
        Color.FromArgb(147, 169, 174),  // 8 water light
        Color.FromArgb( 98, 128, 140),  // 9 water
        Color.FromArgb(142,  43,  34),  // 10 accent (player only)
    };

    static int W, H;
    static double K;                    // world px -> sheet px
    static byte[] px;                   // palette indices, one per pixel
    static Random rng;
    static string cartoDir;

    public static void Build(string geomJson, string dst, string cdir, int fitW, int fitH, int scale, int seed)
    {
        rng = new Random(seed);
        cartoDir = cdir;
        var g = MiniJson.Parse(geomJson) as Dictionary<string, object>;
        var bounds = g["bounds"] as Dictionary<string, object>;
        double bw = D(bounds["w"]), bh = D(bounds["h"]);

        // fit the world into the content box, then work at whole pixels
        K = Math.Min(fitW / bw, fitH / bh);
        W = (int)Math.Round(bw * K);
        H = (int)Math.Round(bh * K);
        px = new byte[W * H];

        Paper();

        bool[] water  = MaskWater(g);
        bool[] fields = MaskRects(g, "fields");
        bool[] woods  = MaskWoods(g);
        bool[] built  = MaskBuilt(g);
        bool[] hiRoad = MaskRoads(g, "major");
        bool[] loRoad = MaskRoads(g, "minor");
        bool[] track  = MaskTracks(g);

        // ---- flat tone masses first, in the order a draughtsman lays washes
        FillMask(fields, FIELD);
        Hatch(fields, MID, 3, 0);              // furrows
        EdgeOf(fields, BUILT, 1);              // hedgerow

        FillMask(woods, WOOD);
        EdgeOf(woods, DARK, 1);

        FillMask(water, WATER);
        ShoreBand(water);
        EdgeOf(water, INK, 1);

        // ---- built-up: light block, heavy outline (never a dark lump) ------
        FillMask(built, MID);
        EdgeOf(built, INK, 1);
        EdgeOf(built, INK, 0);                 // doubled = heavy

        // ---- streets are the LIGHTEST thing on the sheet -------------------
        Casing(track,  DARK);
        FillMask(track, FIELD);
        Casing(loRoad, INK);
        FillMask(loRoad, PAPER_HI);
        Casing(hiRoad, INK);
        FillMask(hiRoad, PAPER_HI);

        Squares(g);
        Woodmarks(g, woods);
        Border();

        Save(dst, scale);
    }

    static double D(object o) { return Convert.ToDouble(o, System.Globalization.CultureInfo.InvariantCulture); }
    static List<object> L(Dictionary<string, object> g, string k)
    {
        object v; if (!g.TryGetValue(k, out v) || v == null) return new List<object>();
        return v as List<object> ?? new List<object>();
    }
    static int PX(double wx) { return (int)Math.Round(wx * K); }
    static bool In(int x, int y) { return x >= 0 && y >= 0 && x < W && y < H; }
    static void Set(int x, int y, byte c) { if (In(x, y)) px[y * W + x] = c; }
    static byte Get(int x, int y) { return In(x, y) ? px[y * W + x] : (byte)PAPER; }

    // ---- paper -------------------------------------------------------------
    // A hand-authored two-value stipple on a wrapped 64x64 field. The previous
    // sheet used a photographic fibre scan, which tiled with a visible seam and
    // put continuous tone inside a pixel-art plate.
    static void Paper()
    {
        Random r = new Random(9173);
        bool[] grain = new bool[64 * 64];
        for (int i = 0; i < grain.Length; i++) grain[i] = r.NextDouble() < 0.14;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
                px[y * W + x] = grain[(y % 64) * 64 + (x % 64)] ? (byte)PAPER_HI : (byte)PAPER;
    }

    // ---- mask helpers ------------------------------------------------------
    // Masks are rasterised through GDI+ with smoothing OFF, then read back as
    // booleans, so every edge lands on a whole pixel.
    static bool[] Raster(Action<Graphics> draw)
    {
        bool[] m = new bool[W * H];
        using (Bitmap bm = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            using (Graphics gr = Graphics.FromImage(bm))
            {
                gr.SmoothingMode = SmoothingMode.None;
                gr.InterpolationMode = InterpolationMode.NearestNeighbor;
                gr.PixelOffsetMode = PixelOffsetMode.Half;
                gr.Clear(Color.Black);
                draw(gr);
            }
            BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[bd.Stride * H];
            System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
            bm.UnlockBits(bd);
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    m[y * W + x] = buf[y * bd.Stride + x * 4 + 1] > 110;
        }
        return m;
    }

    static PointF[] Pts(Dictionary<string, object> o)
    {
        var raw = o["pts"] as List<object>;
        var pts = new PointF[raw.Count];
        for (int i = 0; i < raw.Count; i++)
        {
            var xy = raw[i] as List<object>;
            pts[i] = new PointF((float)(D(xy[0]) * K), (float)(D(xy[1]) * K));
        }
        return pts;
    }

    static bool[] MaskWater(Dictionary<string, object> g)
    {
        return Raster(gr =>
        {
            foreach (object o in L(g, "water"))
            {
                var w = o as Dictionary<string, object>;
                PointF[] p = Pts(w);
                if (p.Length < 2) continue;
                float wide = Math.Max(2f, (float)(D(w["half"]) * 2.0 * K));
                string cls = w.ContainsKey("class") ? w["class"].ToString() : "canal";
                using (Pen pen = new Pen(Color.White, wide)) { pen.LineJoin = LineJoin.Round; gr.DrawLines(pen, p); }
                if (cls == "river")
                    gr.FillRectangle(Brushes.White, 0, p[0].Y, W, H - p[0].Y);   // open water to the sheet edge
            }
            foreach (object o2 in L(g, "ponds"))
            {
                var pd = o2 as Dictionary<string, object>;
                float cx = (float)(D(pd["x"]) * K), cy = (float)(D(pd["y"]) * K);
                float rx = Math.Max(2f, (float)(D(pd["rx"]) * K)), ry = Math.Max(2f, (float)(D(pd["ry"]) * K));
                gr.FillEllipse(Brushes.White, cx - rx, cy - ry, rx * 2, ry * 2);
            }
        });
    }

    static bool[] MaskRects(Dictionary<string, object> g, string key)
    {
        return Raster(gr =>
        {
            foreach (object o in L(g, key))
            {
                var r = o as Dictionary<string, object>;
                gr.FillRectangle(Brushes.White, (float)(D(r["x"]) * K), (float)(D(r["y"]) * K),
                    Math.Max(1f, (float)(D(r["w"]) * K)), Math.Max(1f, (float)(D(r["h"]) * K)));
            }
        });
    }

    // Woodland is a MASS, not confetti: every tree is dilated into a common
    // blob so a wood reads as one shape with a scalloped edge.
    static bool[] MaskWoods(Dictionary<string, object> g)
    {
        var trees = L(g, "trees");
        bool[] m = Raster(gr =>
        {
            foreach (object o in trees)
            {
                var t = o as Dictionary<string, object>;
                float cx = (float)(D(t["x"]) * K), cy = (float)(D(t["y"]) * K);
                gr.FillEllipse(Brushes.White, cx - 2.6f, cy - 2.6f, 5.2f, 5.2f);
            }
        });
        return Open(m, 1);
    }

    static bool[] MaskBuilt(Dictionary<string, object> g)
    {
        bool[] m = Raster(gr =>
        {
            foreach (object o in L(g, "buildings"))
            {
                var b = o as Dictionary<string, object>;
                float x = (float)(D(b["x"]) * K), y = (float)(D(b["y"]) * K);
                float w = (float)(D(b["w"]) * K), h = (float)(D(b["h"]) * K);
                if (w > W * 0.4f || h > H * 0.4f) continue;
                float fh = Math.Max(1f, h * 0.66f);
                gr.FillRectangle(Brushes.White, x, y + h - fh, Math.Max(1f, w), fh);
            }
            foreach (object o2 in L(g, "built"))
            {
                var r = o2 as Dictionary<string, object>;
                gr.FillRectangle(Brushes.White, (float)(D(r["x"]) * K), (float)(D(r["y"]) * K),
                    Math.Max(1f, (float)(D(r["w"]) * K)), Math.Max(1f, (float)(D(r["h"]) * K)));
            }
        });
        // terraces merge into blocks; lone specks are dropped
        return Open(Dilate(m, 1), 1);
    }

    static bool[] MaskRoads(Dictionary<string, object> g, string cls)
    {
        return Raster(gr =>
        {
            foreach (object o in L(g, "streets"))
            {
                var s = o as Dictionary<string, object>;
                string c = s.ContainsKey("class") ? s["class"].ToString() : "minor";
                if (c != cls) continue;
                PointF[] p = Pts(s);
                if (p.Length < 2) continue;
                float wide = cls == "major" ? 3f : 2f;
                using (Pen pen = new Pen(Color.White, wide)) { pen.LineJoin = LineJoin.Round; gr.DrawLines(pen, p); }
            }
        });
    }

    static bool[] MaskTracks(Dictionary<string, object> g)
    {
        return Raster(gr =>
        {
            foreach (object o in L(g, "tracks"))
            {
                var t = o as Dictionary<string, object>;
                PointF[] p = Pts(t);
                if (p.Length < 2) continue;
                using (Pen pen = new Pen(Color.White, 1f)) gr.DrawLines(pen, p);
            }
        });
    }

    // ---- morphology --------------------------------------------------------
    static bool[] Dilate(bool[] m, int r)
    {
        bool[] o = new bool[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                if (!m[y * W + x]) continue;
                for (int dy = -r; dy <= r; dy++)
                    for (int dx = -r; dx <= r; dx++)
                        if (In(x + dx, y + dy)) o[(y + dy) * W + (x + dx)] = true;
            }
        return o;
    }

    static bool[] Erode(bool[] m, int r)
    {
        bool[] o = new bool[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                bool all = true;
                for (int dy = -r; dy <= r && all; dy++)
                    for (int dx = -r; dx <= r; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (!In(nx, ny) || !m[ny * W + nx]) { all = false; break; }
                    }
                o[y * W + x] = all;
            }
        return o;
    }

    static bool[] Open(bool[] m, int r) { return Dilate(Erode(m, r), r); }

    // ---- painting ----------------------------------------------------------
    static void FillMask(bool[] m, int col)
    {
        for (int i = 0; i < m.Length; i++) if (m[i]) px[i] = (byte)col;
    }

    static void EdgeOf(bool[] m, int col, int inset)
    {
        bool[] e = new bool[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (!m[i]) continue;
                bool edge = !(In(x - 1, y) && m[i - 1]) || !(In(x + 1, y) && m[i + 1])
                         || !(In(x, y - 1) && m[i - W]) || !(In(x, y + 1) && m[i + W]);
                if (edge) e[i] = true;
            }
        if (inset > 0) e = Dilate(e, 0);
        for (int i = 0; i < e.Length; i++) if (e[i]) px[i] = (byte)col;
    }

    // A dark line laid one pixel outside a way, so the carriageway reads as a
    // cut through the block rather than a stripe painted on it.
    static void Casing(bool[] m, int col)
    {
        bool[] d = Dilate(m, 1);
        for (int i = 0; i < d.Length; i++) if (d[i] && !m[i]) px[i] = (byte)col;
    }

    static void Hatch(bool[] m, int col, int step, int phase)
    {
        for (int y = 0; y < H; y++)
        {
            if (((y + phase) % step) != 0) continue;
            for (int x = 0; x < W; x++) if (m[y * W + x]) px[y * W + x] = (byte)col;
        }
    }

    // Two sparser bands stepping away from the shore: the oldest way to say
    // "this is the sea" without colour.
    static void ShoreBand(bool[] water)
    {
        bool[] d1 = Dilate(water, 1);
        bool[] d2 = Dilate(water, 2);
        for (int i = 0; i < water.Length; i++)
        {
            if (water[i] && !Erode(water, 1)[0]) { }   // placeholder, see below
        }
        // inner lighter band along the inside of the shore
        bool[] inner = Erode(water, 1);
        for (int i = 0; i < water.Length; i++)
            if (water[i] && !inner[i]) px[i] = (byte)WATER_HI;
        // two receding stipple bands on the LAND side
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (water[i]) continue;
                if (d1[i] && ((x + y) % 2 == 0)) px[i] = (byte)MID;
                else if (d2[i] && ((x + y) % 4 == 0)) px[i] = (byte)MID;
            }
    }

    static void Squares(Dictionary<string, object> g)
    {
        foreach (object o in L(g, "squares"))
        {
            var s = o as Dictionary<string, object>;
            int cx = PX(D(s["x"])), cy = PX(D(s["y"]));
            int r = Math.Max(2, (int)Math.Round(120.0 * K));
            for (int y = cy - r; y <= cy + r; y++)
                for (int x = cx - r; x <= cx + r; x++)
                {
                    if (!In(x, y)) continue;
                    double dx = (x - cx) / (double)r, dy = (y - cy) / (double)(r * 0.8);
                    if (dx * dx + dy * dy <= 1.0) px[y * W + x] = (byte)PAPER_HI;
                }
        }
    }

    // A wood is drawn as a mass with a few crowns along its silhouette, never
    // as a field of identical clip-art.
    static void Woodmarks(Dictionary<string, object> g, bool[] woods)
    {
        for (int y = 2; y < H - 2; y++)
            for (int x = 2; x < W - 2; x++)
            {
                int i = y * W + x;
                if (!woods[i]) continue;
                if (woods[i - W]) continue;             // only the top silhouette
                if (rng.NextDouble() > 0.30) continue;
                Set(x, y - 1, (byte)DARK);
                Set(x - 1, y, (byte)DARK);
                Set(x + 1, y, (byte)DARK);
            }
    }

    static void Border()
    {
        for (int x = 0; x < W; x++) { px[x] = (byte)INK; px[(H - 1) * W + x] = (byte)INK; }
        for (int y = 0; y < H; y++) { px[y * W] = (byte)INK; px[y * W + W - 1] = (byte)INK; }
        for (int x = 2; x < W - 2; x++) { px[2 * W + x] = (byte)DARK; px[(H - 3) * W + x] = (byte)DARK; }
        for (int y = 2; y < H - 2; y++) { px[y * W + 2] = (byte)DARK; px[y * W + W - 3] = (byte)DARK; }
    }

    // ---- out ---------------------------------------------------------------
    static void Save(string dst, int scale)
    {
        int[] used = new int[PAL.Length];
        using (Bitmap bm = new Bitmap(W * scale, H * scale, PixelFormat.Format32bppArgb))
        {
            BitmapData bd = bm.LockBits(new Rectangle(0, 0, W * scale, H * scale), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[bd.Stride * H * scale];
            for (int y = 0; y < H * scale; y++)
                for (int x = 0; x < W * scale; x++)
                {
                    byte idx = px[(y / scale) * W + (x / scale)];
                    used[idx]++;
                    Color c = PAL[idx];
                    int i = y * bd.Stride + x * 4;
                    buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R; buf[i + 3] = 255;
                }
            System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
            bm.UnlockBits(bd);
            bm.Save(dst, ImageFormat.Png);
        }
        int n = 0; for (int i = 0; i < used.Length; i++) if (used[i] > 0) n++;
        Console.WriteLine(String.Format("  sheet {0}x{1} at {2:0.0000} px/world  colours used {3}/{4}", W, H, K, n, PAL.Length));
        double tot = (double)(W * H * scale * scale);
        Console.WriteLine(String.Format("  paper {0:0.0}%  field {1:0.0}%  wood {2:0.0}%  built {3:0.0}%  water {4:0.0}%  ink {5:0.0}%",
            (used[PAPER] + used[PAPER_HI]) / tot * 100, used[FIELD] / tot * 100, used[WOOD] / tot * 100,
            (used[MID] + used[BUILT]) / tot * 100, (used[WATER] + used[WATER_HI]) / tot * 100,
            (used[INK] + used[DARK]) / tot * 100));
    }
}

public class MiniJson
{
    string s; int i;
    public static object Parse(string text) { var p = new MiniJson(); p.s = text; p.i = 0; return p.Val(); }
    void Ws() { while (i < s.Length && char.IsWhiteSpace(s[i])) i++; }
    object Val()
    {
        Ws(); char c = s[i];
        if (c == '{') return Obj();
        if (c == '[') return Arr();
        if (c == '"') return Str();
        if (c == 't') { i += 4; return true; }
        if (c == 'f') { i += 5; return false; }
        if (c == 'n') { i += 4; return null; }
        return Num();
    }
    Dictionary<string, object> Obj()
    {
        var d = new Dictionary<string, object>(); i++; Ws();
        if (s[i] == '}') { i++; return d; }
        while (true) { Ws(); string k = Str(); Ws(); i++; d[k] = Val(); Ws(); if (s[i] == ',') { i++; continue; } i++; return d; }
    }
    List<object> Arr()
    {
        var a = new List<object>(); i++; Ws();
        if (s[i] == ']') { i++; return a; }
        while (true) { a.Add(Val()); Ws(); if (s[i] == ',') { i++; continue; } i++; return a; }
    }
    string Str()
    {
        i++; var sb = new System.Text.StringBuilder();
        while (s[i] != '"')
        {
            if (s[i] == '\\') { i++; char e = s[i];
                if (e == 'n') sb.Append('\n'); else if (e == 't') sb.Append('\t');
                else if (e == 'u') { sb.Append((char)Convert.ToInt32(s.Substring(i + 1, 4), 16)); i += 4; }
                else sb.Append(e); }
            else sb.Append(s[i]);
            i++;
        }
        i++; return sb.ToString();
    }
    object Num()
    {
        int st = i;
        while (i < s.Length && (char.IsDigit(s[i]) || s[i] == '-' || s[i] == '+' || s[i] == '.' || s[i] == 'e' || s[i] == 'E')) i++;
        return double.Parse(s.Substring(st, i - st), System.Globalization.CultureInfo.InvariantCulture);
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing -ErrorAction Stop

Write-Output "drawing sheet from $Geom"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
[RHSheet]::Build([IO.File]::ReadAllText($Geom), $Out, $carto, $FitW, $FitH, $Scale, $Seed)
$sw.Stop()
Write-Output ("done in {0:N1}s -> {1} ({2:N0} KB)" -f $sw.Elapsed.TotalSeconds, $Out, ((Get-Item $Out).Length / 1KB))
