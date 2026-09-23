# draw_plan.ps1 â€” draw a hand-coloured TOWN PLAN from the city's own vector
# geometry (the JSON written by RH_MAPDUMP / scripts/tools/map_dump.gd).
#
# WHY THIS REPLACES bake_chart.ps1
# bake_chart classified the PIXELS of a screenshot. However much cleaning you do,
# a roof recovered through a colour test is a ragged island and a street is
# whatever is left over, so the result is always blobs â€” which is exactly what
# the owner rejected. This draws the same town from the vectors it was actually
# built from: true street centrelines with true widths, true canal ribbons, and
# 1,388 true building footprints. Nothing is guessed.
#
# LAYER ORDER (the order a draughtsman would work in)
#   1  paper            parchment with fibre grain and aged edges
#   2  parish washes     field and allotment blocks, lightly hatched
#   3  woodland          tree symbols, one per cluster, never one per tree
#   4  water             canal ribbons: ink bank, body, then a lighter centre
#   5  street casing     every carriageway stroked in ink, widest first
#   6  street body       the carriageway itself, pale, inside its casing
#   7  tracks            thin dashed ways across the fields
#   8  squares           open paving, drawn as a lighter disc
#   9  buildings         solid blocks, heavier stroke on the south and east
#  10  walls + bridges
#  11  border            ruled double frame with corner diamonds
#
# PALETTE: a hand-coloured Georgian town plan, not a sepia photograph. Built mass
# is carmine, gardens and fields are green, water is blue-grey, paving is buff.
# That colour IS the information hierarchy â€” the previous monochrome version had
# none.
#
# Usage:
#   powershell -File tools\chart\draw_plan.ps1 -Geom <town_geom.json> `
#              -Out assets\art\maps\town_plan.png -Width 2048
param(
    [Parameter(Mandatory = $true)][string]$Geom,
    [string]$Out = "assets\art\maps\town_plan.png",
    [int]$Width = 2048,
    [int]$Seed = 20260923,
    [string]$Title = "RAVEN HOLLOW"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not [System.IO.Path]::IsPathRooted($Geom)) { $Geom = Join-Path $root $Geom }
if (-not [System.IO.Path]::IsPathRooted($Out))  { $Out  = Join-Path $root $Out }
$carto = Join-Path $root "assets\art\maps\carto"
$orn   = Join-Path $root "assets\art\maps\ornament"
if (-not (Test-Path $Geom)) { throw "geometry dump not found: $Geom  (run with RH_MAPDUMP=<path>)" }

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class RHPlan
{
    // ---- palette: a hand-coloured Georgian town plan -----------------------
    public static Color Paper     = Color.FromArgb(231, 217, 180);
    public static Color PaperDark = Color.FromArgb(206, 188, 146);
    public static Color Ink       = Color.FromArgb(43, 33, 23);
    public static Color InkSoft   = Color.FromArgb(96, 78, 56);
    public static Color Street    = Color.FromArgb(244, 233, 205);
    public static Color Built     = Color.FromArgb(166, 90, 60);
    public static Color BuiltDark = Color.FromArgb(121, 61, 40);
    public static Color Water     = Color.FromArgb(150, 183, 193);
    public static Color WaterDeep = Color.FromArgb(108, 145, 158);
    public static Color Field     = Color.FromArgb(198, 205, 165);
    public static Color Garden    = Color.FromArgb(177, 193, 145);
    public static Color Wood      = Color.FromArgb(104, 126, 82);
    public static Color Edge      = Color.FromArgb(132, 104, 62);

    static int W, H;
    static double K;                 // world px -> output px
    static Random rng;
    static string dir;
    static Dictionary<string, Bitmap> cache = new Dictionary<string, Bitmap>();

    public static void Build(string geomJson, string dst, string cartoDir, string ornamentDir, int width, int seed, string title)
    {
        rng = new Random(seed);
        dir = cartoDir;
        ornDir = ornamentDir;
        var g = MiniJson.Parse(geomJson) as Dictionary<string, object>;
        var bounds = g["bounds"] as Dictionary<string, object>;
        double bw = D(bounds["w"]), bh = D(bounds["h"]);
        W = width;
        K = W / bw;
        H = (int)Math.Round(bh * K);

        using (Bitmap bm = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            Paper2(bm);
            using (Graphics gr = Graphics.FromImage(bm))
            {
                gr.SmoothingMode = SmoothingMode.AntiAlias;
                gr.InterpolationMode = InterpolationMode.HighQualityBicubic;
                gr.PixelOffsetMode = PixelOffsetMode.HighQuality;

                Areas(gr, g, "fields");
                Woods(gr, g);
                Waterways(gr, g);
                Streets(gr, g);
                Tracks(gr, g);
                Squares(gr, g);
                Buildings(gr, g);
                Walls(gr, g);
                Linears(gr, g, "bridges", BuiltDark, 2.4);
                Margin(gr);
                Frame(gr);
                Furniture(gr, title);
            }
            Age(bm);
            bm.Save(dst, ImageFormat.Png);
        }
        foreach (var b in cache.Values) if (b != null) b.Dispose();
        Console.WriteLine(String.Format("  plan {0}x{1} at {2:0.000} px per world px", W, H, K));
    }

    static double D(object o) { return Convert.ToDouble(o, System.Globalization.CultureInfo.InvariantCulture); }
    static PointF P(double wx, double wy) { return new PointF((float)(wx * K), (float)(wy * K)); }
    static List<object> L(Dictionary<string, object> g, string k)
    {
        object v; if (!g.TryGetValue(k, out v) || v == null) return new List<object>();
        return v as List<object> ?? new List<object>();
    }

    // ---- 1. paper ----------------------------------------------------------
    static void Paper2(Bitmap bm)
    {
        BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        // fibre: two octaves of value noise, cheap and seamless enough at this size
        int gw = 256;
        double[] n1 = Noise(gw, 97), n2 = Noise(gw, 613);
        for (int y = 0; y < H; y++)
        {
            int row = y * bd.Stride;
            for (int x = 0; x < W; x++)
            {
                double f = (n1[(y % gw) * gw + (x % gw)] - 0.5) * 9.0
                         + (n2[((y * 3) % gw) * gw + ((x * 3) % gw)] - 0.5) * 5.0;
                int i = row + x * 4;
                buf[i]     = C8(Paper.B + f);
                buf[i + 1] = C8(Paper.G + f);
                buf[i + 2] = C8(Paper.R + f);
                buf[i + 3] = 255;
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bm.UnlockBits(bd);
    }

    static double[] Noise(int n, int seed)
    {
        Random r = new Random(seed);
        double[] a = new double[n * n];
        for (int i = 0; i < a.Length; i++) a[i] = r.NextDouble();
        return a;
    }

    static byte C8(double v) { return (byte)(v < 0 ? 0 : (v > 255 ? 255 : (int)Math.Round(v))); }

    // ---- 2. fields ---------------------------------------------------------
    static void Areas(Graphics gr, Dictionary<string, object> g, string key)
    {
        foreach (object o in L(g, key))
        {
            var r = o as Dictionary<string, object>;
            string cls = r.ContainsKey("class") ? r["class"].ToString() : "farm";
            RectangleF rc = new RectangleF(
                (float)(D(r["x"]) * K), (float)(D(r["y"]) * K),
                (float)(D(r["w"]) * K), (float)(D(r["h"]) * K));
            Color fill = cls == "allotment" ? Garden : Field;
            using (SolidBrush b = new SolidBrush(Color.FromArgb(185, fill))) gr.FillRectangle(b, rc);
            // furrows: ruled lines along the long axis, the standard tillage mark
            bool wide = rc.Width >= rc.Height;
            using (Pen p = new Pen(Color.FromArgb(58, Ink), 1f))
            {
                float step = 5f;
                if (wide) for (float y = rc.Top + step; y < rc.Bottom; y += step) gr.DrawLine(p, rc.Left + 1, y, rc.Right - 1, y);
                else for (float x = rc.Left + step; x < rc.Right; x += step) gr.DrawLine(p, x, rc.Top + 1, x, rc.Bottom - 1);
            }
            using (Pen p2 = new Pen(Color.FromArgb(150, Edge), 1.2f)) gr.DrawRectangle(p2, rc.X, rc.Y, rc.Width, rc.Height);
        }
    }

    // ---- 3. woodland: one symbol per CLUSTER, never one per tree -----------
    static void Woods(Graphics gr, Dictionary<string, object> g)
    {
        var trees = L(g, "trees");
        if (trees.Count == 0) return;
        // bucket into cells about 22 output px across; a wood is drawn as a few
        // marks standing for many trees, which is the whole point of a map
        int cell = 22;
        int cw = W / cell + 1, ch = H / cell + 1;
        int[] count = new int[cw * ch];
        float[] sx = new float[cw * ch], sy = new float[cw * ch];
        foreach (object o in trees)
        {
            var t = o as Dictionary<string, object>;
            PointF p = P(D(t["x"]), D(t["y"]));
            if (p.X < 0 || p.Y < 0 || p.X >= W || p.Y >= H) continue;
            int ix = (int)(p.X / cell), iy = (int)(p.Y / cell);
            int k = iy * cw + ix;
            count[k]++; sx[k] += p.X; sy[k] += p.Y;
        }
        string[] big = { "treePines", "treePineLarge", "treeTall" };
        string[] mid = { "treePine", "treeTall", "treePines" };
        string[] sml = { "treePinesSmall", "bush", "treePine" };
        for (int k = 0; k < count.Length; k++)
        {
            int c = count[k];
            if (c < 2) continue;
            float cx = sx[k] / c, cy = sy[k] / c;
            string sym; double sc;
            if (c >= 14) { sym = big[rng.Next(big.Length)]; sc = 0.46; }
            else if (c >= 6) { sym = mid[rng.Next(mid.Length)]; sc = 0.38; }
            else { sym = sml[rng.Next(sml.Length)]; sc = 0.30; }
            sc *= 0.9 + rng.NextDouble() * 0.25;
            Stamp(gr, sym, cx + (float)(rng.NextDouble() * 5 - 2.5), cy + (float)(rng.NextDouble() * 5 - 2.5), sc, Wood, 0.92);
        }
    }

    // ---- 4. water ----------------------------------------------------------
    static void Waterways(Graphics gr, Dictionary<string, object> g)
    {
        // The quay first: paved ground between the warehouse line and the water.
        object q;
        if (g.TryGetValue("quay", out q) && q != null)
        {
            var qd = q as Dictionary<string, object>;
            RectangleF rc = new RectangleF(
                (float)(D(qd["x0"]) * K), (float)(D(qd["y0"]) * K),
                (float)((D(qd["x1"]) - D(qd["x0"])) * K), (float)((D(qd["y1"]) - D(qd["y0"])) * K));
            using (SolidBrush b = new SolidBrush(Color.FromArgb(200, Street))) gr.FillRectangle(b, rc);
            using (Pen p = new Pen(Color.FromArgb(120, Ink), 1.2f)) gr.DrawRectangle(p, rc.X, rc.Y, rc.Width, rc.Height);
        }

        foreach (object o in L(g, "water"))
        {
            var w = o as Dictionary<string, object>;
            PointF[] pts = Pts(w);
            if (pts.Length < 2) continue;
            float half = (float)(D(w["half"]) * K);
            string cls = w.ContainsKey("class") ? w["class"].ToString() : "canal";
            Draw(gr, pts, half * 2f + 3f, Color.FromArgb(200, Ink));          // bank
            Draw(gr, pts, half * 2f, WaterDeep);                               // body
            Draw(gr, pts, half * 1.15f, Water);                                // lit centre
            if (cls == "river")
            {
                // Everything south of the river is open water to the sheet edge,
                // and a coast is drawn with lines held off the shore.
                float y = pts[0].Y;
                using (SolidBrush b = new SolidBrush(WaterDeep))
                    gr.FillRectangle(b, 0, y, W, H - y);
                using (SolidBrush b2 = new SolidBrush(Color.FromArgb(120, Water)))
                    gr.FillRectangle(b2, 0, y, W, (H - y) * 0.45f);
                for (int i = 1; i <= 4; i++)
                {
                    float off = y - half + i * (half * 0.55f) + half;
                    using (Pen p = new Pen(Color.FromArgb(Math.Max(18, 78 - i * 16), Ink), 1f))
                        gr.DrawLine(p, 0, off, W, off);
                }
            }
        }

        foreach (object o2 in L(g, "ponds"))
        {
            var pd = o2 as Dictionary<string, object>;
            float cx = (float)(D(pd["x"]) * K), cy = (float)(D(pd["y"]) * K);
            float rx = (float)(D(pd["rx"]) * K), ry = (float)(D(pd["ry"]) * K);
            using (SolidBrush b = new SolidBrush(WaterDeep)) gr.FillEllipse(b, cx - rx, cy - ry, rx * 2, ry * 2);
            using (Pen p = new Pen(Color.FromArgb(200, Ink), 1.6f)) gr.DrawEllipse(p, cx - rx, cy - ry, rx * 2, ry * 2);
        }
    }

    // ---- 5+6. streets: casing, then carriageway ---------------------------
    static void Streets(Graphics gr, Dictionary<string, object> g)
    {
        var all = L(g, "streets");
        // widest first so junctions merge cleanly instead of stacking edges
        var majors = new List<Dictionary<string, object>>();
        var minors = new List<Dictionary<string, object>>();
        foreach (object o in all)
        {
            var s = o as Dictionary<string, object>;
            string cls = s.ContainsKey("class") ? s["class"].ToString() : "minor";
            if (cls == "major") majors.Add(s); else minors.Add(s);
        }
        foreach (var s in majors) Draw(gr, Pts(s), (float)(D(s["half"]) * K) * 2f + 3.0f, Color.FromArgb(210, Ink));
        foreach (var s in minors) Draw(gr, Pts(s), (float)(D(s["half"]) * K) * 2f + 2.4f, Color.FromArgb(175, Ink));
        foreach (var s in majors) Draw(gr, Pts(s), (float)(D(s["half"]) * K) * 2f, Street);
        foreach (var s in minors) Draw(gr, Pts(s), (float)(D(s["half"]) * K) * 2f, Street);
    }

    static void Tracks(Graphics gr, Dictionary<string, object> g)
    {
        foreach (object o in L(g, "tracks"))
        {
            var t = o as Dictionary<string, object>;
            PointF[] pts = Pts(t);
            if (pts.Length < 2) continue;
            using (Pen p = new Pen(Color.FromArgb(150, Edge), 1.6f))
            {
                p.DashStyle = DashStyle.Custom;
                p.DashPattern = new float[] { 5f, 3.5f };
                p.LineJoin = LineJoin.Round;
                gr.DrawLines(p, pts);
            }
        }
    }

    static void Squares(Graphics gr, Dictionary<string, object> g)
    {
        foreach (object o in L(g, "squares"))
        {
            var s = o as Dictionary<string, object>;
            PointF c = P(D(s["x"]), D(s["y"]));
            float r = (float)(110.0 * K);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(170, Street)))
                gr.FillEllipse(b, c.X - r, c.Y - r * 0.8f, r * 2f, r * 1.6f);
            using (Pen p = new Pen(Color.FromArgb(90, Ink), 1.1f))
                gr.DrawEllipse(p, c.X - r, c.Y - r * 0.8f, r * 2f, r * 1.6f);
        }
    }

    // ---- 9. buildings ------------------------------------------------------
    // Flat colour is what made the first attempt look like a diagram. These are
    // washed, then the REAL engraved block-hatching cut out of Rocque's 1746
    // plan of London is laid inside them, clipped to the footprints. The
    // texture is downloaded art doing the work no procedural hatch can.
    static void Buildings(Graphics gr, Dictionary<string, object> g)
    {
        var list = L(g, "buildings");
        var rects = new List<RectangleF>();
        foreach (object o in list)
        {
            var b = o as Dictionary<string, object>;
            float x = (float)(D(b["x"]) * K), y = (float)(D(b["y"]) * K);
            float w = (float)(D(b["w"]) * K), h = (float)(D(b["h"]) * K);
            if (w < 1.2f || h < 1.2f) continue;
            if (w > W * 0.5f || h > H * 0.5f) continue;   // skip backdrops
            // a pixel-art sprite is mostly roof: the footprint a plan wants is
            // the lower two thirds of it
            float fh = h * 0.66f;
            rects.Add(new RectangleF(x, y + h - fh, w, fh));
        }

        using (SolidBrush fill = new SolidBrush(Built))
            foreach (RectangleF rc in rects) gr.FillRectangle(fill, rc);

        Bitmap tex = Orn("tex_built");
        if (tex != null)
        {
            using (GraphicsPath path = new GraphicsPath())
            {
                foreach (RectangleF rc in rects) path.AddRectangle(rc);
                Region old = gr.Clip;
                gr.SetClip(path, CombineMode.Replace);
                using (TextureBrush tb = new TextureBrush(tex, WrapMode.Tile))
                {
                    tb.ScaleTransform(0.34f, 0.34f);
                    gr.FillRectangle(tb, 0, 0, W, H);
                }
                gr.Clip = old;
            }
        }

        using (Pen edge = new Pen(Ink, 1.0f))
        using (Pen shade = new Pen(BuiltDark, 2.0f))
            foreach (RectangleF rc in rects)
            {
                gr.DrawRectangle(edge, rc.X, rc.Y, rc.Width, rc.Height);
                gr.DrawLine(shade, rc.Left + 1, rc.Bottom, rc.Right, rc.Bottom);
                gr.DrawLine(shade, rc.Right, rc.Top + 1, rc.Right, rc.Bottom);
            }
        Console.WriteLine("  buildings drawn: " + rects.Count);
    }

    // ---- downloaded ornament ----------------------------------------------
    static string ornDir;
    static Dictionary<string, Bitmap> ornCache = new Dictionary<string, Bitmap>();

    static Bitmap Orn(string name)
    {
        Bitmap bm;
        if (ornCache.TryGetValue(name, out bm)) return bm;
        string p = System.IO.Path.Combine(ornDir, name + ".png");
        bm = System.IO.File.Exists(p) ? new Bitmap(p) : null;
        ornCache[name] = bm;
        return bm;
    }

    // The sheet furniture, all of it real 18th-century engraving: Bowen's 1748
    // mariner's compass, and the rococo cartouche and engraved border from
    // Rocque's 1746 plan of London. Both are public domain.
    static void Furniture(Graphics gr, string title)
    {
        float m = (float)Math.Round(Math.Min(W, H) * 0.022);

        Bitmap strip = Orn("border_strip");
        if (strip != null)
        {
            float bh = (float)Math.Round(m * 0.82);
            float bw = strip.Width * (bh / strip.Height);
            for (float x = m; x < W - m; x += bw)
            {
                float wseg = Math.Min(bw, W - m - x);
                gr.DrawImage(strip, new RectangleF(x, m - bh, wseg, bh),
                    new RectangleF(0, 0, strip.Width * (wseg / bw), strip.Height), GraphicsUnit.Pixel);
                gr.DrawImage(strip, new RectangleF(x, H - m, wseg, bh),
                    new RectangleF(0, 0, strip.Width * (wseg / bw), strip.Height), GraphicsUnit.Pixel);
            }
            // the same strip turned on its side for the flanks
            GraphicsState st = gr.Save();
            gr.TranslateTransform(m, H - m);
            gr.RotateTransform(-90f);
            for (float x2 = 0; x2 < H - m * 2; x2 += bw)
            {
                float wseg = Math.Min(bw, H - m * 2 - x2);
                gr.DrawImage(strip, new RectangleF(x2, -bh, wseg, bh),
                    new RectangleF(0, 0, strip.Width * (wseg / bw), strip.Height), GraphicsUnit.Pixel);
            }
            gr.Restore(st);
            st = gr.Save();
            gr.TranslateTransform(W - m, m);
            gr.RotateTransform(90f);
            for (float x3 = 0; x3 < H - m * 2; x3 += bw)
            {
                float wseg = Math.Min(bw, H - m * 2 - x3);
                gr.DrawImage(strip, new RectangleF(x3, -bh, wseg, bh),
                    new RectangleF(0, 0, strip.Width * (wseg / bw), strip.Height), GraphicsUnit.Pixel);
            }
            gr.Restore(st);
        }

        Bitmap rose = Orn("compass_bowen");
        if (rose != null)
        {
            float rs = (float)(Math.Min(W, H) * 0.115);
            gr.DrawImage(rose, new RectangleF(W - m - rs - 14, m + 14, rs, rs * rose.Height / rose.Width));
        }

        Bitmap cart = Orn("cartouche_rococo");
        if (cart != null)
        {
            float cw = (float)(W * 0.165);
            float ch = cw * cart.Height / cart.Width;
            float cx = m + 20, cy = H - m - ch - 20;
            gr.DrawImage(cart, new RectangleF(cx, cy, cw, ch));
            if (title != null && title.Length > 0)
            {
                // The engraved shell came with Rocque's own scale bars and
                // abbreviation list inside it. Wash the belly back to paper
                // first, or our name prints on top of his legend.
                RectangleF belly = new RectangleF(cx + cw * 0.13f, cy + ch * 0.40f, cw * 0.74f, ch * 0.40f);
                using (SolidBrush wash = new SolidBrush(Color.FromArgb(226, 238, 226, 192)))
                    gr.FillEllipse(wash, belly);
                // letterspaced small caps: the cartographic convention for a
                // sheet title, and it stops the name fighting the rococo shell
                string spaced = "";
                foreach (char c in title.ToUpperInvariant()) spaced += c + " ";
                spaced = spaced.TrimEnd();
                using (Font f = new Font("Georgia", ch * 0.125f, FontStyle.Bold, GraphicsUnit.Pixel))
                using (SolidBrush b = new SolidBrush(Color.FromArgb(235, Ink)))
                {
                    StringFormat sf = new StringFormat();
                    sf.Alignment = StringAlignment.Center;
                    sf.LineAlignment = StringAlignment.Center;
                    gr.DrawString(spaced, f, b, belly, sf);
                }
                using (Pen hair = new Pen(Color.FromArgb(150, Ink), 1f))
                {
                    float ly = belly.Top + belly.Height * 0.74f;
                    gr.DrawLine(hair, belly.Left + belly.Width * 0.18f, ly, belly.Right - belly.Width * 0.18f, ly);
                }
            }
        }
    }


    // A town wall is one continuous line on a plan, never a row of grey boxes.
    // The dump gives each wall sprite's footprint; they are stroked as a single
    // heavy ink run along the middle of each.
    static void Walls(Graphics gr, Dictionary<string, object> g)
    {
        using (SolidBrush b = new SolidBrush(Color.FromArgb(215, Ink)))
        {
            foreach (object o in L(g, "walls"))
            {
                var wd = o as Dictionary<string, object>;
                float x = (float)(D(wd["x"]) * K), y = (float)(D(wd["y"]) * K);
                float w = (float)(D(wd["w"]) * K), h = (float)(D(wd["h"]) * K);
                if (w > W * 0.5f || h > H * 0.5f) continue;
                bool horiz = w >= h;
                float t = 2.2f;
                if (horiz) gr.FillRectangle(b, x, y + h * 0.62f - t * 0.5f, Math.Max(w, t), t);
                else gr.FillRectangle(b, x + w * 0.5f - t * 0.5f, y, t, Math.Max(h, t));
            }
        }
    }

    // A drawn sheet has a margin. Without one the props that sit on the world's
    // edge - boundary walls, the last row of quay clutter - print into the
    // frame and the plan looks like a screenshot that was cropped too tight.
    static void Margin(Graphics gr)
    {
        float m = (float)Math.Round(Math.Min(W, H) * 0.022);
        using (SolidBrush b = new SolidBrush(Paper))
        {
            gr.FillRectangle(b, 0, 0, W, m);
            gr.FillRectangle(b, 0, H - m, W, m);
            gr.FillRectangle(b, 0, 0, m, H);
            gr.FillRectangle(b, W - m, 0, m, H);
        }
        using (Pen p = new Pen(Color.FromArgb(70, Ink), 1f))
            gr.DrawRectangle(p, m, m, W - m * 2, H - m * 2);
    }

    static void Linears(Graphics gr, Dictionary<string, object> g, string key, Color col, double wpx)
    {
        foreach (object o in L(g, key))
        {
            var b = o as Dictionary<string, object>;
            float x = (float)(D(b["x"]) * K), y = (float)(D(b["y"]) * K);
            float w = (float)(D(b["w"]) * K), h = (float)(D(b["h"]) * K);
            using (SolidBrush br = new SolidBrush(col))
                gr.FillRectangle(br, x, y + h * 0.5f, Math.Max(w, (float)wpx), Math.Max(h * 0.4f, (float)wpx));
        }
    }

    static PointF[] Pts(Dictionary<string, object> o)
    {
        var raw = o["pts"] as List<object>;
        var pts = new PointF[raw.Count];
        for (int i = 0; i < raw.Count; i++)
        {
            var xy = raw[i] as List<object>;
            pts[i] = P(D(xy[0]), D(xy[1]));
        }
        return pts;
    }

    static void Draw(Graphics gr, PointF[] pts, float width, Color col)
    {
        if (pts.Length < 2) return;
        using (Pen p = new Pen(col, Math.Max(width, 0.8f)))
        {
            p.LineJoin = LineJoin.Round;
            p.StartCap = LineCap.Round;
            p.EndCap = LineCap.Round;
            gr.DrawLines(p, pts);
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

    static void Stamp(Graphics gr, string name, float cx, float cy, double scale, Color tint, double alpha)
    {
        Bitmap bm = Sym(name);
        if (bm == null) return;
        float w = (float)(bm.Width * scale), h = (float)(bm.Height * scale);
        using (ImageAttributes ia = new ImageAttributes())
        {
            ColorMatrix m = new ColorMatrix(new float[][] {
                new float[] {0f,0f,0f,0f,0f},
                new float[] {0f,0f,0f,0f,0f},
                new float[] {0f,0f,0f,0f,0f},
                new float[] {0f,0f,0f,(float)alpha,0f},
                new float[] {tint.R/255f, tint.G/255f, tint.B/255f, 0f, 1f} });
            ia.SetColorMatrix(m);
            gr.DrawImage(bm, new Rectangle((int)(cx - w / 2f), (int)(cy - h * 0.78f), (int)w, (int)h),
                0, 0, bm.Width, bm.Height, GraphicsUnit.Pixel, ia);
        }
    }

    // ---- frame + ageing ----------------------------------------------------
    static void Frame(Graphics gr)
    {
        using (Pen p1 = new Pen(Color.FromArgb(185, Ink), 3.5f))
        using (Pen p2 = new Pen(Color.FromArgb(110, Ink), 1.2f))
        {
            gr.DrawRectangle(p1, 9, 9, W - 19, H - 19);
            gr.DrawRectangle(p2, 18, 18, W - 37, H - 37);
        }
        using (SolidBrush b = new SolidBrush(Color.FromArgb(190, Ink)))
        {
            int[][] cs = { new int[]{18,18}, new int[]{W-19,18}, new int[]{18,H-19}, new int[]{W-19,H-19} };
            foreach (int[] c in cs)
                gr.FillPolygon(b, new PointF[] {
                    new PointF(c[0], c[1]-8), new PointF(c[0]+8, c[1]),
                    new PointF(c[0], c[1]+8), new PointF(c[0]-8, c[1]) });
        }
    }

    static void Age(Bitmap bm)
    {
        BitmapData bd = bm.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
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
                double t = Math.Max(0.0, (d - 0.55) / 0.45); t = t * t * 0.30;
                if (t <= 0.002) continue;
                int i = row + x * 4;
                buf[i]     = C8(buf[i]     + (94  - buf[i])     * t);
                buf[i + 1] = C8(buf[i + 1] + (118 - buf[i + 1]) * t);
                buf[i + 2] = C8(buf[i + 2] + (150 - buf[i + 2]) * t);
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bm.UnlockBits(bd);
    }
}

// Minimal JSON reader â€” enough for the dump's objects, arrays, numbers, strings.
public class MiniJson
{
    string s; int i;
    public static object Parse(string text) { var p = new MiniJson(); p.s = text; p.i = 0; return p.Val(); }
    void Ws() { while (i < s.Length && char.IsWhiteSpace(s[i])) i++; }
    object Val()
    {
        Ws();
        char c = s[i];
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
        while (true)
        {
            Ws(); string k = Str(); Ws(); i++; // colon
            d[k] = Val(); Ws();
            if (s[i] == ',') { i++; continue; }
            i++; return d;
        }
    }
    List<object> Arr()
    {
        var a = new List<object>(); i++; Ws();
        if (s[i] == ']') { i++; return a; }
        while (true)
        {
            a.Add(Val()); Ws();
            if (s[i] == ',') { i++; continue; }
            i++; return a;
        }
    }
    string Str()
    {
        i++; var sb = new System.Text.StringBuilder();
        while (s[i] != '"')
        {
            if (s[i] == '\\')
            {
                i++;
                char e = s[i];
                if (e == 'n') sb.Append('\n');
                else if (e == 't') sb.Append('\t');
                else if (e == 'u') { sb.Append((char)Convert.ToInt32(s.Substring(i + 1, 4), 16)); i += 4; }
                else sb.Append(e);
            }
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

Write-Output "drawing plan from $Geom"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
[RHPlan]::Build([IO.File]::ReadAllText($Geom), $Out, $carto, $orn, $Width, $Seed, $Title)
$sw.Stop()
Write-Output ("done in {0:N1}s -> {1} ({2:N0} KB)" -f $sw.Elapsed.TotalSeconds, $Out, ((Get-Item $Out).Length / 1KB))
