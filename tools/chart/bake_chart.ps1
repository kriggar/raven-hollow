# bake_chart.ps1 v2 — turn a zone screenshot into a HAND-DRAWN PARCHMENT CHART
# built from Kenney's CC0 Cartography Pack (assets/art/maps/carto).
#
# WHY v2: v1 drew everything per pixel — hatched roof blocks, ruled water,
# stroked tree marks. That reads as a filtered screenshot, because every mark
# still traced the photograph underneath. A real chart does two things a filter
# cannot: it GENERALISES (a wood becomes a handful of drawn trees, not a green
# blob) and it is drawn on REAL PAPER with a REAL PEN. So v2:
#   * lays tiled parchmentAncient.png under everything instead of a flat fill
#   * fills water with the pack's seamless ripple hatch + a double coastline
#   * draws buildings as SOLID PLAN FOOTPRINTS (the town-plan convention) with
#     a heavier south/east stroke, instead of mid-tone cross-hatch
#   * stamps drawn tree symbols (treePine / treePines / treeTall / bush) on an
#     even, jittered lattice wherever canopy is dense — legible at any zoom
#   * merges stone WALL pixels into the footprints when they touch a building
#     and demotes the rest to road, so cobble streets stop reading as masonry
#   * burns the edges (vignette) so the sheet looks aged rather than printed
#
# Named landmarks are NOT baked in: the map screen draws those itself so they
# can respect fog of war. -Places is available for zones that want fixed marks.
#
# Assets: assets/art/maps/carto/*.png — Kenney Cartography Pack, CC0 (see
# assets/art/maps/carto/CREDITS_CARTOGRAPHY.txt).
#
# Usage:
#   powershell -File tools\chart\bake_chart.ps1 -Src assets\art\maps\town.png `
#              -Out assets\art\maps\town_chart.png
param(
    [string]$Src = "assets\art\maps\town.png",
    [string]$Out = "assets\art\maps\town_chart.png",
    [string]$Places = "",
    [int]$Seed = 20260923
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not [System.IO.Path]::IsPathRooted($Src)) { $Src = Join-Path $root $Src }
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $root $Out }
if ($Places -ne "" -and -not [System.IO.Path]::IsPathRooted($Places)) { $Places = Join-Path $root $Places }
$carto = Join-Path $root "assets\art\maps\carto"
if (-not (Test-Path $Src))   { throw "source not found: $Src" }
if (-not (Test-Path $carto)) { throw "cartography symbols not found: $carto" }

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class RHCartographer
{
    public const byte GRASS = 0, WATER = 1, ROAD = 2, ROOF = 3, FIELD = 4, TREE = 5, STONE = 6;

    public static Color Parch = Color.FromArgb(211, 190, 144);
    public static Color Ink   = Color.FromArgb(52, 38, 24);

    public static double CANOPY_LUM = 78.0;   // below this a green pixel is canopy
    // Everything measured in pixels below is tuned on the 1536x1098 town plate
    // and then scaled to whatever plate is being charted, so a 1024 px zone
    // sheet gets marks of the same apparent size rather than a handful of
    // enormous ones.
    public static double TOWN_MIN = 1098.0, TOWN_AREA = 1536.0 * 1098.0;
    static double lenK = 1.0, areaK = 1.0;
    public static double WOOD_STEP  = 30.0;   // px between tree marks on the town plate
    public static double WOOD_GATE  = 0.22;   // canopy share needed for a mark
    public static double PAPER_A    = 0.55;   // how strongly the paper shows

    static int W, H;
    static byte[] cls;
    static Random rng;
    static string dir;
    static Dictionary<string, Bitmap> cache = new Dictionary<string, Bitmap>();

    public static void Build(string src, string dst, string cartoPath, string placesFile, int seed)
    {
        rng = new Random(seed);
        dir = cartoPath;
        using (Bitmap sb = new Bitmap(src))
        {
            W = sb.Width; H = sb.Height;
            cls = new byte[W * H];
            Classify(sb);
        }
        lenK = Math.Min(1.6, Math.Max(0.55, Math.Min(W, H) / TOWN_MIN));
        areaK = Math.Min(2.2, Math.Max(0.30, (W * (double)H) / TOWN_AREA));
        Clean(2);
        MergeWalls(Math.Max(3, (int)Math.Round(7 * lenK)));
        Clean(1);
        FillHoles(ROOF, A(260));  // windows, doors and chimneys stop punching holes
        OnlyBuildingsAreBuildings(A(110), 0.28);
        PathsOnly(A(420));
        Despeckle(WATER, A(120), GRASS);
        int nt = 0, nr = 0, nw = 0, ng = 0;
        for (int p = 0; p < W * H; p++)
        {
            if (cls[p] == TREE) nt++;
            else if (cls[p] == ROOF) nr++;
            else if (cls[p] == WATER) nw++;
            else if (cls[p] == GRASS) ng++;
        }
        double tot100 = W * H / 100.0;
        Console.WriteLine(String.Format(
            "  canopy texture split {0:0.0}   tree {1:0.0}%  built {2:0.0}%  water {3:0.0}%  open {4:0.0}%",
            CANOPY_LUM, nt / tot100, nr / tot100, nw / tot100, ng / tot100));

        using (Bitmap outBmp = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            Paper(outBmp);
            Tones(outBmp);
            InkEdges(outBmp);
            CoastBand(outBmp);
            using (Graphics g = Graphics.FromImage(outBmp))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                Woods(g);
                if (placesFile != null && placesFile.Length > 0) Places(g, placesFile);
                Frame(g);
            }
            Vignette(outBmp);
            outBmp.Save(dst, ImageFormat.Png);
        }
        foreach (Bitmap b in cache.Values) if (b != null) b.Dispose();
        cache.Clear();
    }

    // ---- classify ----------------------------------------------------------
    static void Classify(Bitmap sb)
    {
        BitmapData bd = sb.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        sb.UnlockBits(bd);

        double[] lum = new double[W * H];
        bool[] veg = new bool[W * H];
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            for (int x = 0; x < W; x++)
            {
                int i = row + x * 4;
                int b = buf[i], g = buf[i + 1], r = buf[i + 2];
                int p = y * W + x;
                byte k = ClassOf(r, g, b);
                cls[p] = k;
                lum[p] = 0.30 * r + 0.59 * g + 0.11 * b;
                veg[p] = (k == GRASS);
            }
        }

        // Canopy vs open ground. Brightness alone cannot do this: in the city
        // the lawn is the bright majority and the canopy the dark minority, in
        // the wildwood the canopy IS the plate and Otsu just splits its own
        // shading in half. What holds on both is TEXTURE - pixel-art foliage is
        // a mass of outlined leaf clusters and reads as high local variance,
        // while mown ground and clearings are nearly flat.
        double[] sd = LocalDeviation(lum, 2);
        int[] hist = new int[256];
        for (int p = 0; p < W * H; p++)
            if (veg[p]) hist[(int)Math.Min(255.0, sd[p] * 4.0)]++;
        double t = Otsu(hist, 2, 200) / 4.0;
        CANOPY_LUM = t;
        for (int p = 0; p < W * H; p++)
            if (veg[p] && sd[p] > t) cls[p] = TREE;
    }

    // Standard deviation of luminance in a (2r+1) box, via integral images so
    // the window size costs nothing.
    static double[] LocalDeviation(double[] lum, int r)
    {
        int sw = W + 1;
        double[] s1 = new double[sw * (H + 1)];
        double[] s2 = new double[sw * (H + 1)];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                double v = lum[y * W + x];
                int q = (y + 1) * sw + (x + 1);
                s1[q] = v + s1[q - 1] + s1[q - sw] - s1[q - sw - 1];
                s2[q] = v * v + s2[q - 1] + s2[q - sw] - s2[q - sw - 1];
            }
        double[] outv = new double[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int x0 = Math.Max(0, x - r), y0 = Math.Max(0, y - r);
                int x1 = Math.Min(W - 1, x + r), y1 = Math.Min(H - 1, y + r);
                int n = (x1 - x0 + 1) * (y1 - y0 + 1);
                int a = y0 * sw + x0, b = y0 * sw + (x1 + 1);
                int c = (y1 + 1) * sw + x0, d = (y1 + 1) * sw + (x1 + 1);
                double sum = s1[d] - s1[b] - s1[c] + s1[a];
                double sq = s2[d] - s2[b] - s2[c] + s2[a];
                double mean = sum / n;
                double var = sq / n - mean * mean;
                outv[y * W + x] = var > 0.0 ? Math.Sqrt(var) : 0.0;
            }
        return outv;
    }

    static double Otsu(int[] hist, int lo, int hi)
    {
        long total = 0, sum = 0;
        for (int i = lo; i <= hi; i++) { total += hist[i]; sum += (long)i * hist[i]; }
        if (total < 64) return 78.0;
        long wB = 0, sumB = 0;
        double best = -1.0; int bestT = lo;
        for (int t = lo; t <= hi; t++)
        {
            wB += hist[t]; if (wB == 0) continue;
            long wF = total - wB; if (wF == 0) break;
            sumB += (long)t * hist[t];
            double mB = sumB / (double)wB;
            double mF = (sum - sumB) / (double)wF;
            double between = (double)wB * wF * (mB - mF) * (mB - mF);
            if (between > best) { best = between; bestT = t; }
        }
        return bestT;
    }

    // A dead trunk, a bramble, a fallen log and a market awning are all the
    // same brown as a roof. A building is not told apart by colour but by
    // SHAPE: it is big enough to stand in and it fills its own bounding box,
    // because people build in rectangles. A vine is long, thin and snakes, so
    // it fills maybe a fifth of its box - that is what is tested here. What
    // fails goes back to the wood if the wood surrounds it, else to open ground.
    static void OnlyBuildingsAreBuildings(int minArea, double minFill)
    {
        bool[] seen = new bool[W * H];
        int[] stack = new int[W * H];
        int[] blob = new int[W * H];
        for (int s = 0; s < W * H; s++)
        {
            if (seen[s] || cls[s] != ROOF) continue;
            int sp = 0, n = 0, ring = 0, ringTree = 0;
            int sy0 = s / W, sx0 = s - sy0 * W;
            int minx = sx0, maxx = sx0, miny = sy0, maxy = sy0;
            stack[sp++] = s; seen[s] = true;
            while (sp > 0)
            {
                int cur = stack[--sp];
                blob[n++] = cur;
                int cy = cur / W, cx = cur - cy * W;
                if (cx < minx) minx = cx; if (cx > maxx) maxx = cx;
                if (cy < miny) miny = cy; if (cy > maxy) maxy = cy;
                int[] nb = new int[] { cx > 0 ? cur - 1 : -1, cx < W - 1 ? cur + 1 : -1,
                                       cy > 0 ? cur - W : -1, cy < H - 1 ? cur + W : -1 };
                foreach (int q in nb)
                {
                    if (q < 0) continue;
                    if (cls[q] == ROOF) { if (!seen[q]) { seen[q] = true; stack[sp++] = q; } }
                    else { ring++; if (cls[q] == TREE) ringTree++; }
                }
            }
            double box = (maxx - minx + 1.0) * (maxy - miny + 1.0);
            double fill = n / box;
            if (n >= minArea && fill >= minFill) continue;           // a building
            // Surrounded by canopy it was a trunk; anywhere else it was a prop
            // standing on paving, and paving is what should be left behind.
            byte to = (ring > 0 && ringTree / (double)ring > 0.30) ? TREE : ROAD;
            for (int i = 0; i < n; i++) cls[blob[i]] = to;
        }
    }

    // Flat scraps of bare earth in a wood are not paths. Left in, each one gets
    // a pale fill and an ink outline and the chart grows a field of little
    // clouds; a path worth drawing is long, so only large runs survive.
    static void PathsOnly(int minArea)
    {
        Despeckle(ROAD, minArea, GRASS);
    }

    static byte ClassOf(int r, int g, int b)
    {
        int mx = Math.Max(r, Math.Max(g, b));
        int mn = Math.Min(r, Math.Min(g, b));
        int sat = mx - mn;
        if (b > r + 12 && g > r + 4 && b > 45) return WATER;
        if (sat < 26 && mx > 95 && mx < 205) return STONE;
        if (r > g + 26 && r > b + 34 && r > 60 && r < 190 && g < 110) return ROOF;
        // Vegetation. Not "green dominant": the wildwood is olive, r and g are
        // equal there and a g > r test found 272 green pixels in a plate that
        // is three quarters forest. What every leaf actually shares is a blue
        // channel far below the other two, with red no higher than green -
        // which a tilled field (red clearly ahead) never satisfies. Canopy and
        // lawn are then split by the Otsu pass in Classify.
        if (b + 28 < Math.Min(r, g) && r <= g + 10 && g > 40) return GRASS;
        if (r > g + 14 && g > b + 10 && sat > 42) return FIELD;
        if (r >= g && g >= b && mx > 45) return ROAD;
        return GRASS;
    }

    static void Clean(int passes)
    {
        int[] count = new int[7];
        for (int p = 0; p < passes; p++)
        {
            byte[] next = (byte[])cls.Clone();
            for (int y = 1; y < H - 1; y++)
                for (int x = 1; x < W - 1; x++)
                {
                    Array.Clear(count, 0, 7);
                    for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                            count[cls[(y + dy) * W + (x + dx)]]++;
                    int best = 0, bi = 0;
                    for (int k = 0; k < 7; k++) if (count[k] > best) { best = count[k]; bi = k; }
                    if (best >= 6) next[y * W + x] = (byte)bi;
                }
            cls = next;
        }
    }

    // Grey pixels next to a roof are that building's walls, so they join the
    // footprint. Grey pixels out in the open are cobble, so they become road -
    // otherwise every paved street inks up as masonry.
    static void MergeWalls(int radius)
    {
        byte[] next = (byte[])cls.Clone();
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                if (cls[y * W + x] != STONE) continue;
                next[y * W + x] = Near(x, y, ROOF, radius) ? ROOF : ROAD;
            }
        cls = next;
    }

    // A plan draws a building as one filled block, but the screenshot under it
    // has windows, doorsteps and chimney shadows inside every roof. Filling
    // ENCLOSED gaps does that without a morphological close, which at any
    // radius wide enough to seal a doorway also welds neighbouring houses into
    // one amoeba and throws away every gable silhouette.
    static void FillHoles(byte k, int maxArea)
    {
        bool[] seen = new bool[W * H];
        int[] stack = new int[W * H];
        int[] blob = new int[W * H];
        for (int s = 0; s < W * H; s++)
        {
            if (seen[s] || cls[s] == k) continue;
            int sp = 0, n = 0;
            bool open = false;
            stack[sp++] = s; seen[s] = true;
            while (sp > 0)
            {
                int cur = stack[--sp];
                if (n < maxArea + 1) blob[n] = cur;
                n++;
                int cy = cur / W, cx = cur - cy * W;
                if (cx == 0 || cy == 0 || cx == W - 1 || cy == H - 1) open = true;
                if (cx > 0     && !seen[cur - 1] && cls[cur - 1] != k) { seen[cur - 1] = true; stack[sp++] = cur - 1; }
                if (cx < W - 1 && !seen[cur + 1] && cls[cur + 1] != k) { seen[cur + 1] = true; stack[sp++] = cur + 1; }
                if (cy > 0     && !seen[cur - W] && cls[cur - W] != k) { seen[cur - W] = true; stack[sp++] = cur - W; }
                if (cy < H - 1 && !seen[cur + W] && cls[cur + W] != k) { seen[cur + W] = true; stack[sp++] = cur + W; }
            }
            if (open || n > maxArea) continue;
            for (int i = 0; i < n; i++) cls[blob[i]] = k;
        }
    }

    // Props - barrels, crates, a cart - classify as roof brown. A surveyor
    // does not draw a barrel, so anything smaller than a shed is dropped.
    /// A pixel-area threshold from the town plate, rescaled to this one.
    static int A(int townArea) { return Math.Max(12, (int)Math.Round(townArea * areaK)); }

    static void Despeckle(byte k, int minArea) { Despeckle(k, minArea, ROAD); }

    static void Despeckle(byte k, int minArea, byte to)
    {
        bool[] seen = new bool[W * H];
        int[] stack = new int[W * H];
        int[] blob = new int[W * H];
        for (int s = 0; s < W * H; s++)
        {
            if (seen[s] || cls[s] != k) continue;
            int sp = 0, n = 0;
            stack[sp++] = s; seen[s] = true;
            while (sp > 0)
            {
                int cur = stack[--sp];
                blob[n++] = cur;
                int cy = cur / W, cx = cur - cy * W;
                if (cx > 0     && !seen[cur - 1] && cls[cur - 1] == k) { seen[cur - 1] = true; stack[sp++] = cur - 1; }
                if (cx < W - 1 && !seen[cur + 1] && cls[cur + 1] == k) { seen[cur + 1] = true; stack[sp++] = cur + 1; }
                if (cy > 0     && !seen[cur - W] && cls[cur - W] == k) { seen[cur - W] = true; stack[sp++] = cur - W; }
                if (cy < H - 1 && !seen[cur + W] && cls[cur + W] == k) { seen[cur + W] = true; stack[sp++] = cur + W; }
            }
            if (n >= minArea) continue;
            for (int i = 0; i < n; i++) cls[blob[i]] = to;
        }
    }

    static byte At(int x, int y)
    {
        if (x < 0) x = 0; if (y < 0) y = 0;
        if (x >= W) x = W - 1; if (y >= H) y = H - 1;
        return cls[y * W + x];
    }

    static bool Near(int x, int y, byte k, int r)
    {
        for (int dy = -r; dy <= r; dy += 2)
            for (int dx = -r; dx <= r; dx += 2)
                if (At(x + dx, y + dy) == k) return true;
        return false;
    }

    static bool EdgeOf(int x, int y, byte k)
    {
        if (At(x, y) != k) return false;
        return At(x - 1, y) != k || At(x + 1, y) != k || At(x, y - 1) != k || At(x, y + 1) != k;
    }

    // ---- paper -------------------------------------------------------------
    // Every parchment in the pack is a seamless tile whose lighting is a 4x4
    // grid of folded panels. Tiled it repeats that grid; stretched it still
    // shows it as bands across the plate. So we keep only the paper's HIGH
    // FREQUENCIES - the fibre, the speckle, the crinkle - and throw the panel
    // lighting away, then lay our own two folds where a real sheet this size
    // would have been folded once each way.
    static void Paper(Bitmap outBmp)
    {
        Bitmap pt = Sym("parchmentAncient");
        float[] grain = null;
        int pw = 0, ph = 0;
        if (pt != null)
        {
            pw = pt.Width; ph = pt.Height;
            float[] L = new float[pw * ph];
            BitmapData pd = pt.LockBits(new Rectangle(0, 0, pw, ph), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] pb = new byte[pd.Stride * ph];
            System.Runtime.InteropServices.Marshal.Copy(pd.Scan0, pb, 0, pb.Length);
            pt.UnlockBits(pd);
            for (int y = 0; y < ph; y++)
                for (int x = 0; x < pw; x++)
                {
                    int i = y * pd.Stride + x * 4;
                    L[y * pw + x] = 0.30f * pb[i + 2] + 0.59f * pb[i + 1] + 0.11f * pb[i];
                }
            float[] lo = BlurWrap(L, pw, ph, 14);
            grain = new float[pw * ph];
            for (int i = 0; i < grain.Length; i++) grain[i] = L[i] - lo[i];
        }

        BitmapData bd = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            double fy = Fold(y, H);
            for (int x = 0; x < W; x++)
            {
                double d = 0.0;
                if (grain != null) d = grain[(y % ph) * pw + (x % pw)] * PAPER_A;
                d += Fold(x, W) + fy;
                int i = row + x * 4;
                buf[i]     = Clamp8(Parch.B + d);
                buf[i + 1] = Clamp8(Parch.G + d);
                buf[i + 2] = Clamp8(Parch.R + d);
                buf[i + 3] = 255;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        outBmp.UnlockBits(bd);
    }

    // A crease at each third: a hair of shadow with a lit edge beside it.
    static double Fold(int v, int span)
    {
        double acc = 0.0;
        for (int k = 1; k <= 2; k++)
        {
            double c = span * k / 3.0;
            double t = (v - c) / 9.0;
            if (t < -3.0 || t > 3.0) continue;
            acc += -7.0 * Math.Exp(-t * t) + 5.0 * Math.Exp(-(t - 1.3) * (t - 1.3));
        }
        return acc;
    }

    static byte Clamp8(double v) { return (byte)(v < 0 ? 0 : (v > 255 ? 255 : (int)Math.Round(v))); }

    static float[] BlurWrap(float[] src, int w, int h, int r)
    {
        float[] tmp = new float[w * h];
        float[] dst = new float[w * h];
        float inv = 1.0f / (2 * r + 1);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                float s = 0f;
                for (int k = -r; k <= r; k++) s += src[y * w + ((x + k) % w + w) % w];
                tmp[y * w + x] = s * inv;
            }
        for (int x = 0; x < w; x++)
            for (int y = 0; y < h; y++)
            {
                float s = 0f;
                for (int k = -r; k <= r; k++) s += tmp[(((y + k) % h + h) % h) * w + x];
                dst[y * w + x] = s * inv;
            }
        return dst;
    }

    // ---- tones -------------------------------------------------------------
    static void Tones(Bitmap outBmp)
    {
        Bitmap wt = Sym("textureWater");
        BitmapData bd = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);

        // pre-read the water hatch so we are not calling GetPixel 1.7M times
        int ww = 0, wh = 0; byte[] wa = null;
        if (wt != null)
        {
            ww = wt.Width; wh = wt.Height; wa = new byte[ww * wh];
            for (int y = 0; y < wh; y++)
                for (int x = 0; x < ww; x++)
                    wa[y * ww + x] = wt.GetPixel(x, y).A;
        }

        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            for (int x = 0; x < W; x++)
            {
                byte k = cls[y * W + x];
                int i = row + x * 4;
                Color cur = Color.FromArgb(buf[i + 2], buf[i + 1], buf[i]);
                Color c = cur;
                if (k == WATER)
                {
                    c = Mix(cur, Ink, 0.11);
                    if (wa != null)
                    {
                        byte a = wa[(y % wh) * ww + (x % ww)];
                        if (a > 30) c = Mix(c, Ink, 0.34 * (a / 255.0));
                    }
                }
                else if (k == ROAD) c = Mix(cur, Color.FromArgb(255, 250, 236), 0.16);
                else if (k == ROOF) c = Mix(cur, Ink, 0.70);        // solid plan footprint
                else if (k == FIELD)
                {
                    c = Mix(cur, Ink, 0.06);
                    if (((y + x / 3) % 6) == 0) c = Mix(c, Ink, 0.20);   // furrows
                }
                buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R; buf[i + 3] = 255;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        outBmp.UnlockBits(bd);
    }

    static void InkEdges(Bitmap outBmp)
    {
        BitmapData bd = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            for (int x = 0; x < W; x++)
            {
                double w = 0.0;
                if (EdgeOf(x, y, WATER)) w = 1.0;
                else if (EdgeOf(x, y, ROOF))
                {
                    // heavier on the south and east = the drawn shadow of a plan
                    bool se = At(x, y + 1) != ROOF || At(x + 1, y) != ROOF;
                    w = se ? 1.0 : 0.55;
                }
                else if (EdgeOf(x, y, FIELD)) w = 0.30;
                // Deliberately no outline around paving. On a town plan a
                // street is the gap between buildings, never a drawn shape;
                // inking it turns the whole paved core into one ragged amoeba.
                if (w <= 0.0) continue;
                int i = row + x * 4;
                Color cur = Color.FromArgb(buf[i + 2], buf[i + 1], buf[i]);
                Color c = Mix(cur, Ink, w);
                buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        outBmp.UnlockBits(bd);
    }

    // second, lighter line held off the shore - the oldest way to say "coast"
    static void CoastBand(Bitmap outBmp)
    {
        BitmapData bd = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        for (int y = 3; y < H - 3; y++)
        {
            int row = y * bd.Stride;
            for (int x = 3; x < W - 3; x++)
            {
                if (At(x, y) == WATER) continue;
                if (!Near(x, y, WATER, 4) || Near(x, y, WATER, 2)) continue;
                int i = row + x * 4;
                Color cur = Color.FromArgb(buf[i + 2], buf[i + 1], buf[i]);
                Color c = Mix(cur, Ink, 0.30);
                buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        outBmp.UnlockBits(bd);
    }

    // ---- woods -------------------------------------------------------------
    // An even, jittered lattice rather than one mark per blob: that is how a
    // surveyed wood is drawn, and it stays legible however the mask is shaped.
    static void Woods(Graphics g)
    {
        int step = Math.Max(12, (int)Math.Round(WOOD_STEP * lenK));
        int half = step / 2;
        for (int y = step; y < H - step; y += step)
            for (int x = step; x < W - step; x += step)
            {
                int jx = x + rng.Next(-half, half + 1);
                int jy = y + rng.Next(-half, half + 1);
                if (At(jx, jy) != TREE) continue;
                int hits = 0, tot = 0;
                for (int dy = -half; dy <= half; dy += 3)
                    for (int dx = -half; dx <= half; dx += 3)
                    {
                        tot++;
                        if (At(jx + dx, jy + dy) == TREE) hits++;
                    }
                double dens = tot > 0 ? hits / (double)tot : 0.0;
                if (dens < WOOD_GATE) continue;
                // thin the lattice at the fringes so a wood fades out instead of
                // stopping at a straight edge of evenly spaced marks
                if (rng.NextDouble() > 0.35 + dens * 0.75) continue;
                string sym;
                double sc;
                if (dens > 0.74)      { sym = PickOf("treePines", "treePineLarge", "treeTall", "treePine"); sc = 0.62; }
                else if (dens > 0.48) { sym = PickOf("treePine", "treeTall", "treePines");                  sc = 0.50; }
                else                  { sym = PickOf("treePinesSmall", "treePine", "bush");                 sc = 0.38; }
                sc *= step / 30.0;
                sc *= 0.88 + rng.NextDouble() * 0.28;
                Stamp(g, sym, jx, jy, sc, 0.80 + rng.NextDouble() * 0.15);
            }
    }

    static string PickOf(params string[] names) { return names[rng.Next(names.Length)]; }

    // ---- fixed marks -------------------------------------------------------
    // "u,v,symbol,scale" with u/v in 0..1 of the plate. Optional; the map
    // screen normally draws named places itself so fog can hide them.
    static void Places(Graphics g, string file)
    {
        foreach (string line in System.IO.File.ReadAllLines(file))
        {
            string s = line.Trim();
            if (s.Length == 0 || s.StartsWith("#")) continue;
            string[] p = s.Split(',');
            if (p.Length < 4) continue;
            System.Globalization.CultureInfo iv = System.Globalization.CultureInfo.InvariantCulture;
            Stamp(g, p[2].Trim(),
                double.Parse(p[0], iv) * W, double.Parse(p[1], iv) * H,
                double.Parse(p[3], iv), 0.95);
        }
    }

    // ---- symbols -----------------------------------------------------------
    static Bitmap Sym(string name)
    {
        Bitmap bm;
        if (cache.TryGetValue(name, out bm)) return bm;
        string p = System.IO.Path.Combine(dir, name + ".png");
        bm = System.IO.File.Exists(p) ? new Bitmap(p) : null;
        cache[name] = bm;
        return bm;
    }

    static void Stamp(Graphics g, string name, double cx, double cy, double scale, double alpha)
    {
        Bitmap bm = Sym(name);
        if (bm == null) return;
        float w = (float)(bm.Width * scale), h = (float)(bm.Height * scale);
        RectangleF dst = new RectangleF((float)cx - w / 2f, (float)cy - h * 0.74f, w, h);
        using (ImageAttributes ia = new ImageAttributes())
        {
            // the pack draws in near-black; recolour every mark to map ink
            ColorMatrix m = new ColorMatrix(new float[][] {
                new float[] {0f, 0f, 0f, 0f, 0f},
                new float[] {0f, 0f, 0f, 0f, 0f},
                new float[] {0f, 0f, 0f, 0f, 0f},
                new float[] {0f, 0f, 0f, (float)alpha, 0f},
                new float[] {Ink.R / 255f, Ink.G / 255f, Ink.B / 255f, 0f, 1f} });
            ia.SetColorMatrix(m);
            g.DrawImage(bm, new Rectangle((int)dst.X, (int)dst.Y, (int)dst.Width, (int)dst.Height),
                0, 0, bm.Width, bm.Height, GraphicsUnit.Pixel, ia);
        }
    }

    // ---- frame + ageing ----------------------------------------------------
    static void Frame(Graphics g)
    {
        using (Pen p1 = new Pen(Color.FromArgb(160, Ink), 3f))
        using (Pen p2 = new Pen(Color.FromArgb(95, Ink), 1f))
        {
            g.DrawRectangle(p1, 7, 7, W - 15, H - 15);
            g.DrawRectangle(p2, 15, 15, W - 31, H - 31);
        }
        using (SolidBrush b = new SolidBrush(Color.FromArgb(170, Ink)))
        {
            int[][] cs = new int[][] { new int[] { 15, 15 }, new int[] { W - 16, 15 },
                                       new int[] { 15, H - 16 }, new int[] { W - 16, H - 16 } };
            foreach (int[] c in cs)
                g.FillPolygon(b, new PointF[] {
                    new PointF(c[0], c[1] - 7), new PointF(c[0] + 7, c[1]),
                    new PointF(c[0], c[1] + 7), new PointF(c[0] - 7, c[1]) });
        }
    }

    // Burn the edges so the sheet looks like paper that has been handled.
    static void Vignette(Bitmap outBmp)
    {
        BitmapData bd = outBmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        double hw = W * 0.5, hh = H * 0.5;
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            double ny = (y - hh) / hh;
            for (int x = 0; x < W; x++)
            {
                double nx = (x - hw) / hw;
                double d = Math.Sqrt(nx * nx + ny * ny) / 1.414;
                double t = Math.Max(0.0, (d - 0.52) / 0.48);
                t = t * t * 0.34;
                if (t <= 0.002) continue;
                int i = row + x * 4;
                Color cur = Color.FromArgb(buf[i + 2], buf[i + 1], buf[i]);
                Color c = Mix(cur, Color.FromArgb(120, 92, 56), t);
                buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        outBmp.UnlockBits(bd);
    }

    static Color Mix(Color a, Color b, double t)
    {
        if (t < 0) t = 0; if (t > 1) t = 1;
        return Color.FromArgb(
            (int)Math.Round(a.R + (b.R - a.R) * t),
            (int)Math.Round(a.G + (b.G - a.G) * t),
            (int)Math.Round(a.B + (b.B - a.B) * t));
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing -ErrorAction Stop

Write-Output "charting $Src -> $Out"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
[RHCartographer]::Build($Src, $Out, $carto, $Places, $Seed)
$sw.Stop()
Write-Output ("done in {0:N1}s ({1} bytes)" -f $sw.Elapsed.TotalSeconds, (Get-Item $Out).Length)
