# draw_wow.ps1 — the Raven Hollow zone map, painted in the World of Warcraft
# manner from the town's own authored vector data and real photographic terrain.
#
# WHY THIS AND NOT THE EARLIER ATTEMPTS
# Three versions were rejected. The first classified screenshot pixels and got
# blobs. The second drew flat vector shapes and got a diagram. The third pasted
# 18th-century engraving on top and got a beautiful antique that still had no
# terrain in it. The owner then named the target directly: WoW zone maps.
#
# WHAT A WOW ZONE MAP ACTUALLY IS, and what that dictates here:
#   * It is PAINTED, not drawn. There is no outline language at all — no ink
#     line round a forest, no hatch, no engraved block. Everything is a soft
#     textured mass. So: no strokes anywhere in this file except roads.
#   * It reads because of RELIEF. Forest and high ground carry a drop shadow
#     down-right and catch light up-left, which is what makes a flat overhead
#     texture look like terrain instead of wallpaper.
#   * Its VALUE STRUCTURE is real: water darkest and cool, woodland dark warm,
#     open ground mid, roads and settlement the lightest. The rejected sheet
#     had 81% of its pixels in one luminance band, which is why it vanished at
#     a squint.
#   * Roads are TAN RIBBONS, the brightest line on the map, and they are the
#     thing the eye follows.
#   * The sheet does not end at a border: it FADES into aged parchment at the
#     edges, so the painted area feels like a window onto a bigger world.
#   * Colour is warm and desaturated. Photographic grass straight off a texture
#     site is far too green and too saturated; it is pulled towards the game's
#     sepia before anything else happens.
#
# Painted art wants smooth filtering, so this renders at a working resolution
# above the display size and is shown with linear filtering — the opposite of
# the pixel-art rule, and correct for this target.
#
# TEXTURES (all CC0, Poly Haven) and PAPER (public domain) live in
# _downloads/mapart/terrain. See assets/art/maps/CREDITS_TERRAIN.txt.
#
# Usage:
#   powershell -File tools\chart\draw_wow.ps1 -Geom <town_geom.json> `
#              -Out assets\art\maps\town_wow.png -Width 1536
param(
    [Parameter(Mandatory = $true)][string]$Geom,
    [string]$Out = "assets\art\maps\town_wow.png",
    [int]$Width = 1536,
    [int]$Seed = 20260923,
    # Diablo II's lesson, quoted in the research: prototype the whole map as
    # 1px ink lines on paper first. If the wireframe is confusing, parchment
    # will not save it; if it is good, every pass afterwards is pure profit.
    [switch]$Wire
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not [System.IO.Path]::IsPathRooted($Geom)) { $Geom = Join-Path $root $Geom }
if (-not [System.IO.Path]::IsPathRooted($Out))  { $Out  = Join-Path $root $Out }
$terrain = Join-Path $root "_downloads\mapart\terrain"
if (-not (Test-Path $Geom))    { throw "geometry dump not found: $Geom  (boot with RH_MAPDUMP=<path>)" }
if (-not (Test-Path $terrain)) { throw "terrain textures not found: $terrain" }

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class RHWow
{
    static int W, H;
    static double K;
    static Random rng;
    static string texDir;

    // working buffers, linear float RGB
    static float[] R, G, B;

    public static void Build(string geomJson, string dst, string tdir, int width, int seed, bool wire)
    {
        rng = new Random(seed);
        texDir = tdir;
        var g = MiniJson.Parse(geomJson) as Dictionary<string, object>;
        var bounds = g["bounds"] as Dictionary<string, object>;
        double bw = D(bounds["w"]), bh = D(bounds["h"]);
        W = width; K = W / bw; H = (int)Math.Round(bh * K);
        R = new float[W * H]; G = new float[W * H]; B = new float[W * H];

        // ---- masks -------------------------------------------------------
        // CARTOGRAPHIC GENERALIZATION. The research headline: "every expensive
        // fantasy map is a DRAWN DOCUMENT rebuilt from world data through
        // select, simplify, exaggerate, displace, symbolize". The wireframe
        // proved the cost of skipping it — drawing all 1,242 buildings and
        // 4,328 trees individually gave a page of confetti with no structure.
        // So: blur each raw mask hard and threshold it, which merges terraces
        // into QUARTERS and scattered trees into WOODS, and drops anything too
        // small to matter at this scale.
        float[] water  = Blur(Mask(gr => DrawWater(gr, g)), 2);
        // Woodland is where trees are DENSE, not wherever a tree stands. The
        // city has 4,328 scattered trees; dilating each one welded the whole
        // plate into a single forest. Blurring the stamps gives a density
        // field, and only what clears the threshold is drawn as wood.
        float[] woods  = Blur(Threshold(Blur(Mask(gr => DrawTrees(gr, g)), 18), 0.30f), 7);
        float[] fields = Blur(Mask(gr => DrawRects(gr, g, "fields")), 3);
        float[] built  = Blur(Threshold(Blur(MaskB(gr => DrawBuilt(gr, g)), 13), 0.26f), 5);
        float[] roadHi = Blur(Mask(gr => DrawRoads(gr, g, "major")), 1);
        float[] roadLo = Blur(Mask(gr => DrawRoads(gr, g, "minor")), 1);

        if (wire)
        {
            // ---- D2 FIDELITY: paper, flat water, and 1px ink. Nothing else.
            // House style, from Blizzard''s stated rule that everything must
            // look drawn by the same hand: coastline 2px, all other line 1px,
            // light from the upper left, under ten colours.
            for (int i = 0; i < R.Length; i++) { R[i] = 0.898f; G[i] = 0.855f; B[i] = 0.741f; }
            Paint(Threshold(water, 0.5f), 0.792f, 0.831f, 0.831f);
            Ink(Outline(Threshold(water, 0.5f)), 2);
            Ink(Outline(Threshold(fields, 0.5f)), 1);
            Ink(Outline(Threshold(woods, 0.5f)), 1);
            Ink(Outline(Threshold(built, 0.5f)), 1);
            Ink(Outline(Threshold(roadLo, 0.35f)), 1);
            Ink(Outline(Threshold(roadHi, 0.35f)), 1);
            Save(dst);
            return;
        }

        // ---- 1. the ground, painted from real overhead grass --------------
        Tile("aerial_grass_rock", 5.0, 0.62f, 1.02f, 0.96f, 0.80f);

        // ---- 2. open field and tilled ground ------------------------------
        Blend(fields, "aerial_mud_1", 6.0, 0.55f, 1.06f, 0.99f, 0.86f);

        // ---- 3. woodland: shadow first, then canopy, then a lit top edge --
        // The shadow is the whole trick. A canopy texture with no shadow under
        // it is a green rug; offset it down-right and the wood stands up.
        Shadow(woods, 4, 4, 0.42f);
        Blend(woods, "forest_ground_04", 3.4, 0.50f, 0.86f, 0.94f, 0.72f);
        RimLight(woods, 0.30f);

        // ---- 4. water: cool, dark, with a lit shelf at the shore ----------
        Shadow(water, 2, 2, 0.30f);
        Paint(water, 0.255f, 0.353f, 0.392f);      // deep
        Shelf(water, 0.392f, 0.510f, 0.529f);      // shallows
        Sparkle(water);

        // ---- 5. roads: the brightest line, and what the eye follows -------
        Paint(Mul(roadLo, 0.85f), 0.454f, 0.380f, 0.267f);
        Paint(Mul(roadLo, 0.62f), 0.741f, 0.647f, 0.467f);
        Paint(Mul(roadHi, 0.90f), 0.427f, 0.353f, 0.243f);
        Paint(Mul(roadHi, 0.72f), 0.812f, 0.718f, 0.522f);

        // ---- 6. the town: warm roofs, with their own shadow ---------------
        Shadow(built, 3, 3, 0.45f);
        Blend(built, "aerial_rocks_01", 4.0, 0.30f, 0.92f, 0.88f, 0.84f);
        Paint(Mul(built, 0.55f), 0.376f, 0.290f, 0.243f);
        RimLight(built, 0.26f);

        // ---- 7. the sheet fades into old paper at its edges ---------------
        Parchment();
        Vignette();

        Save(dst);
    }

    // ---------------------------------------------------------------- utils
    static double D(object o) { return Convert.ToDouble(o, System.Globalization.CultureInfo.InvariantCulture); }
    static List<object> L(Dictionary<string, object> g, string k)
    {
        object v; if (!g.TryGetValue(k, out v) || v == null) return new List<object>();
        return v as List<object> ?? new List<object>();
    }
    static PointF[] Pts(Dictionary<string, object> o)
    {
        var raw = o["pts"] as List<object>;
        var p = new PointF[raw.Count];
        for (int i = 0; i < raw.Count; i++)
        {
            var xy = raw[i] as List<object>;
            p[i] = new PointF((float)(D(xy[0]) * K), (float)(D(xy[1]) * K));
        }
        return p;
    }

    // ---------------------------------------------------------------- masks
    static float[] Mask(Action<Graphics> draw)
    {
        float[] m = new float[W * H];
        using (Bitmap bm = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            using (Graphics gr = Graphics.FromImage(bm))
            {
                gr.SmoothingMode = SmoothingMode.AntiAlias;
                gr.Clear(Color.Black);
                draw(gr);
            }
            BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[bd.Stride * H];
            System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
            bm.UnlockBits(bd);
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    m[y * W + x] = buf[y * bd.Stride + x * 4 + 1] / 255f;
        }
        return m;
    }
    static float[] MaskB(Action<Graphics> draw) { return Mask(draw); }

    static void DrawWater(Graphics gr, Dictionary<string, object> g)
    {
        foreach (object o in L(g, "water"))
        {
            var w = o as Dictionary<string, object>;
            PointF[] p = Pts(w);
            if (p.Length < 2) continue;
            float wide = Math.Max(3f, (float)(D(w["half"]) * 2.0 * K));
            using (Pen pen = new Pen(Color.White, wide)) { pen.LineJoin = LineJoin.Round; pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round; gr.DrawLines(pen, p); }
            string cls = w.ContainsKey("class") ? w["class"].ToString() : "canal";
            if (cls == "river") gr.FillRectangle(Brushes.White, 0, p[0].Y, W, H - p[0].Y);
        }
        foreach (object o2 in L(g, "ponds"))
        {
            var pd = o2 as Dictionary<string, object>;
            float cx = (float)(D(pd["x"]) * K), cy = (float)(D(pd["y"]) * K);
            float rx = Math.Max(3f, (float)(D(pd["rx"]) * K)), ry = Math.Max(3f, (float)(D(pd["ry"]) * K));
            gr.FillEllipse(Brushes.White, cx - rx, cy - ry, rx * 2, ry * 2);
        }
    }

    static void DrawTrees(Graphics gr, Dictionary<string, object> g)
    {
        foreach (object o in L(g, "trees"))
        {
            var t = o as Dictionary<string, object>;
            float cx = (float)(D(t["x"]) * K), cy = (float)(D(t["y"]) * K);
            float r = 5.0f;
            gr.FillEllipse(Brushes.White, cx - r, cy - r, r * 2, r * 2);
        }
    }

    static void DrawRects(Graphics gr, Dictionary<string, object> g, string key)
    {
        foreach (object o in L(g, key))
        {
            var r = o as Dictionary<string, object>;
            gr.FillRectangle(Brushes.White, (float)(D(r["x"]) * K), (float)(D(r["y"]) * K),
                Math.Max(2f, (float)(D(r["w"]) * K)), Math.Max(2f, (float)(D(r["h"]) * K)));
        }
    }

    static void DrawBuilt(Graphics gr, Dictionary<string, object> g)
    {
        foreach (object o in L(g, "buildings"))
        {
            var b = o as Dictionary<string, object>;
            float x = (float)(D(b["x"]) * K), y = (float)(D(b["y"]) * K);
            float w = (float)(D(b["w"]) * K), h = (float)(D(b["h"]) * K);
            if (w > W * 0.4f || h > H * 0.4f) continue;
            float fh = Math.Max(2f, h * 0.7f);
            gr.FillRectangle(Brushes.White, x, y + h - fh, Math.Max(2f, w), fh);
        }
        foreach (object o2 in L(g, "built"))
        {
            var r = o2 as Dictionary<string, object>;
            gr.FillRectangle(Brushes.White, (float)(D(r["x"]) * K), (float)(D(r["y"]) * K),
                Math.Max(2f, (float)(D(r["w"]) * K)), Math.Max(2f, (float)(D(r["h"]) * K)));
        }
    }

    static void DrawRoads(Graphics gr, Dictionary<string, object> g, string cls)
    {
        foreach (object o in L(g, "streets"))
        {
            var s = o as Dictionary<string, object>;
            string c = s.ContainsKey("class") ? s["class"].ToString() : "minor";
            if (c != cls) continue;
            PointF[] p = Pts(s);
            if (p.Length < 2) continue;
            float wide = cls == "major" ? Math.Max(5f, (float)(110.0 * K)) : Math.Max(3f, (float)(80.0 * K));
            using (Pen pen = new Pen(Color.White, wide)) { pen.LineJoin = LineJoin.Round; pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round; gr.DrawLines(pen, p); }
        }
    }

    // ------------------------------------------------------------ morphology
    static float[] Blur(float[] m, int r)
    {
        if (r < 1) return m;
        float[] t = new float[W * H], o = new float[W * H];
        int n = r * 2 + 1;
        for (int y = 0; y < H; y++)
        {
            float sum = 0;
            for (int x = -r; x <= r; x++) sum += m[y * W + Clamp(x, 0, W - 1)];
            for (int x = 0; x < W; x++)
            {
                t[y * W + x] = sum / n;
                sum -= m[y * W + Clamp(x - r, 0, W - 1)];
                sum += m[y * W + Clamp(x + r + 1, 0, W - 1)];
            }
        }
        for (int x = 0; x < W; x++)
        {
            float sum = 0;
            for (int y = -r; y <= r; y++) sum += t[Clamp(y, 0, H - 1) * W + x];
            for (int y = 0; y < H; y++)
            {
                o[y * W + x] = sum / n;
                sum -= t[Clamp(y - r, 0, H - 1) * W + x];
                sum += t[Clamp(y + r + 1, 0, H - 1) * W + x];
            }
        }
        return o;
    }

    static int Clamp(int v, int a, int b) { return v < a ? a : (v > b ? b : v); }

    // grow then shrink, so scattered stamps become one mass
    static float[] Open(float[] m, int r)
    {
        float[] b = Blur(m, r);
        float[] o = new float[m.Length];
        for (int i = 0; i < m.Length; i++) o[i] = b[i] > 0.14f ? 1f : 0f;
        return o;
    }

    // The 1px boundary of a hard mask.
    static float[] Outline(float[] m)
    {
        float[] o = new float[m.Length];
        for (int y = 1; y < H - 1; y++)
            for (int x = 1; x < W - 1; x++)
            {
                int i = y * W + x;
                if (m[i] < 0.5f) continue;
                if (m[i - 1] < 0.5f || m[i + 1] < 0.5f || m[i - W] < 0.5f || m[i + W] < 0.5f) o[i] = 1f;
            }
        return o;
    }

    static void Ink(float[] line, int weight)
    {
        float[] l = weight > 1 ? Threshold(Blur(line, weight - 1), 0.02f) : line;
        for (int i = 0; i < l.Length; i++)
            if (l[i] > 0.5f) { R[i] = 0.149f; G[i] = 0.118f; B[i] = 0.082f; }
    }

    static float[] Threshold(float[] m, float t)
    {
        float[] o = new float[m.Length];
        for (int i = 0; i < m.Length; i++) o[i] = m[i] >= t ? 1f : 0f;
        return o;
    }

    static float[] Mul(float[] m, float k)
    {
        float[] o = new float[m.Length];
        for (int i = 0; i < m.Length; i++) o[i] = m[i] * k;
        return o;
    }

    // ---------------------------------------------------------------- paint
    static Bitmap Tex(string name)
    {
        string p = System.IO.Path.Combine(texDir, name + ".jpg");
        return System.IO.File.Exists(p) ? new Bitmap(p) : null;
    }

    // Sample a photographic texture across the whole plate, pulling it towards
    // the game's warm sepia. Straight off the texture site it is far too green.
    static void Tile(string name, double tiles, float desat, float rg, float gg, float bg)
    {
        using (Bitmap t = Tex(name))
        {
            if (t == null) { for (int i = 0; i < R.Length; i++) { R[i] = 0.62f; G[i] = 0.58f; B[i] = 0.44f; } return; }
            int tw = t.Width, th = t.Height;
            int stride;
            byte[] tb = Bytes(t, out stride);
            double sx = tiles / W * tw, sy = tiles / W * tw;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int u = (int)(x * sx) % tw, v = (int)(y * sy) % th;
                    if (u < 0) u += tw; if (v < 0) v += th;
                    int i = v * stride + u * 3;
                    float r = tb[i + 2] / 255f, gg2 = tb[i + 1] / 255f, b = tb[i] / 255f;
                    float l = 0.30f * r + 0.59f * gg2 + 0.11f * b;
                    r = l + (r - l) * desat; gg2 = l + (gg2 - l) * desat; b = l + (b - l) * desat;
                    int o = y * W + x;
                    R[o] = Sat(r * rg); G[o] = Sat(gg2 * gg); B[o] = Sat(b * bg);
                }
        }
    }

    static void Blend(float[] m, string name, double tiles, float desat, float rg, float gg, float bg)
    {
        using (Bitmap t = Tex(name))
        {
            if (t == null) return;
            int tw = t.Width, th = t.Height;
            int stride;
            byte[] tb = Bytes(t, out stride);
            double sx = tiles / W * tw;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int o = y * W + x;
                    float a = m[o]; if (a <= 0.004f) continue;
                    int u = (int)(x * sx) % tw, v = (int)(y * sx) % th;
                    if (u < 0) u += tw; if (v < 0) v += th;
                    int i = v * stride + u * 3;
                    float r = tb[i + 2] / 255f, g2 = tb[i + 1] / 255f, b = tb[i] / 255f;
                    float l = 0.30f * r + 0.59f * g2 + 0.11f * b;
                    r = Sat((l + (r - l) * desat) * rg);
                    g2 = Sat((l + (g2 - l) * desat) * gg);
                    b = Sat((l + (b - l) * desat) * bg);
                    R[o] += (r - R[o]) * a; G[o] += (g2 - G[o]) * a; B[o] += (b - B[o]) * a;
                }
        }
    }

    static void Paint(float[] m, float r, float g, float b)
    {
        for (int i = 0; i < m.Length; i++)
        {
            float a = m[i]; if (a <= 0.004f) continue;
            R[i] += (r - R[i]) * a; G[i] += (g - G[i]) * a; B[i] += (b - B[i]) * a;
        }
    }

    // Offset, blurred darkening under a mass. This is what makes a flat
    // overhead texture read as standing terrain.
    static void Shadow(float[] m, int dx, int dy, float strength)
    {
        float[] s = Blur(m, 3);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int src = Clamp(y - dy, 0, H - 1) * W + Clamp(x - dx, 0, W - 1);
                int o = y * W + x;
                float a = s[src] * strength * (1f - m[o]);
                if (a <= 0.004f) continue;
                R[o] *= (1f - a * 0.72f); G[o] *= (1f - a * 0.72f); B[o] *= (1f - a * 0.60f);
            }
    }

    // Light from the upper left catching the top edge of a mass.
    static void RimLight(float[] m, float strength)
    {
        for (int y = 1; y < H; y++)
            for (int x = 1; x < W; x++)
            {
                int o = y * W + x;
                if (m[o] < 0.35f) continue;
                float grad = m[o] - m[(y - 2 < 0 ? 0 : y - 2) * W + (x - 2 < 0 ? 0 : x - 2)];
                if (grad <= 0.05f) continue;
                float a = Math.Min(1f, grad) * strength;
                R[o] = Sat(R[o] + a * 0.30f); G[o] = Sat(G[o] + a * 0.28f); B[o] = Sat(B[o] + a * 0.20f);
            }
    }

    // A lighter shelf just inside the shoreline: the single clearest signal
    // that a body of water has a bank.
    static void Shelf(float[] m, float r, float g, float b)
    {
        float[] inner = Blur(m, 4);
        for (int i = 0; i < m.Length; i++)
        {
            if (m[i] < 0.35f) continue;
            float a = Sat((1f - inner[i]) * 2.0f) * 0.85f;
            if (a <= 0.01f) continue;
            R[i] += (r - R[i]) * a; G[i] += (g - G[i]) * a; B[i] += (b - B[i]) * a;
        }
    }

    static void Sparkle(float[] m)
    {
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * W + x;
                if (m[o] < 0.6f) continue;
                if (((x * 7 + y * 13) % 97) > 2) continue;
                float a = 0.16f;
                R[o] = Sat(R[o] + a); G[o] = Sat(G[o] + a); B[o] = Sat(B[o] + a);
            }
    }

    // The painted area does not stop at a line; it dries out into old paper.
    static void Parchment()
    {
        using (Bitmap t = Tex("old_paper6"))
        {
            double hw = W * 0.5, hh = H * 0.5;
            byte[] tb = null; int stride = 0, tw = 0, th = 0;
            if (t != null) { int st2; tb = Bytes(t, out st2); stride = st2; tw = t.Width; th = t.Height; }
            for (int y = 0; y < H; y++)
            {
                double ny = (y - hh) / hh;
                for (int x = 0; x < W; x++)
                {
                    double nx = (x - hw) / hw;
                    double d = Math.Max(Math.Abs(nx), Math.Abs(ny));
                    double a = (d - 0.86) / 0.14;
                    if (a <= 0) continue;
                    a = Math.Min(1.0, a); a = a * a;
                    int o = y * W + x;
                    float pr = 0.82f, pg = 0.75f, pb = 0.59f;
                    if (tb != null)
                    {
                        int u = (int)(x * 0.9) % tw, v = (int)(y * 0.9) % th;
                        int i = v * stride + u * 3;
                        pr = tb[i + 2] / 255f; pg = tb[i + 1] / 255f; pb = tb[i] / 255f;
                    }
                    R[o] += (pr - R[o]) * (float)a;
                    G[o] += (pg - G[o]) * (float)a;
                    B[o] += (pb - B[o]) * (float)a;
                }
            }
        }
    }

    static void Vignette()
    {
        double hw = W * 0.5, hh = H * 0.5;
        for (int y = 0; y < H; y++)
        {
            double ny = (y - hh) / hh;
            for (int x = 0; x < W; x++)
            {
                double nx = (x - hw) / hw;
                double d = Math.Sqrt(nx * nx + ny * ny) / 1.414;
                double a = Math.Max(0.0, (d - 0.45) / 0.55); a = a * a * 0.34;
                if (a <= 0.002) continue;
                int o = y * W + x;
                R[o] *= (float)(1.0 - a * 0.55); G[o] *= (float)(1.0 - a * 0.52); B[o] *= (float)(1.0 - a * 0.44);
            }
        }
    }

    static byte[] Bytes(Bitmap t, out int stride)
    {
        BitmapData bd = t.LockBits(new Rectangle(0, 0, t.Width, t.Height), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        stride = bd.Stride;
        byte[] buf = new byte[bd.Stride * t.Height];
        System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        t.UnlockBits(bd);
        return buf;
    }

    static float Sat(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }

    static void Save(string dst)
    {
        using (Bitmap bm = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[bd.Stride * H];
            double lsum = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int o = y * W + x, i = y * bd.Stride + x * 4;
                    buf[i]     = (byte)Math.Round(Sat(B[o]) * 255);
                    buf[i + 1] = (byte)Math.Round(Sat(G[o]) * 255);
                    buf[i + 2] = (byte)Math.Round(Sat(R[o]) * 255);
                    buf[i + 3] = 255;
                    lsum += 0.30 * R[o] + 0.59 * G[o] + 0.11 * B[o];
                }
            System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
            bm.UnlockBits(bd);
            bm.Save(dst, ImageFormat.Png);
            Console.WriteLine(String.Format("  wow map {0}x{1}  mean luminance {2:0.000}", W, H, lsum / (W * (double)H)));
        }
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

Write-Output "painting WoW-style map from $Geom"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
[RHWow]::Build([IO.File]::ReadAllText($Geom), $Out, $terrain, $Width, $Seed, [bool]$Wire)
$sw.Stop()
Write-Output ("done in {0:N1}s -> {1} ({2:N0} KB)" -f $sw.Elapsed.TotalSeconds, $Out, ((Get-Item $Out).Length / 1KB))
