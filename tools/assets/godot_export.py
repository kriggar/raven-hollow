#!/usr/bin/env python3
"""
GODOT EXPORT  (sorceress-derived, owner MAX-EFFORT law, 2026-07-06).

Take a FINISHED frame set (from anim_finish.py) — a directory of per-frame PNGs or an existing packed
sheet — and emit the three things Godot 4 needs to play the animation, plus a self-check:

  1. PACKED SHEET PNG        — uniform cell_w x cell_h grid, cols x rows, each frame centred in its cell.
  2. JSON MANIFEST           — {name, cell_w, cell_h, cols, rows, fps, loop, anims:[{name, row|frames}]}.
  3. GODOT 4 SpriteFrames .tres — one AtlasTexture sub-resource per frame region (correct Rect2s),
     assembled into a SpriteFrames resource with the right per-anim fps (speed) + loop flags.
  4. VALIDATION              — the .tres is copied into a MINIMAL throwaway Godot project under
     medieval_rpg, the sheet is `--headless --import`ed, then a SceneTree script LOADS the .tres and
     touches every frame texture. Zero errors + VALIDATE_OK = the resource is engine-valid.

Why a minimal throwaway project (not the full game project): importing / booting Raven Hollow takes
~37 s and runs autoloads; a 3-file temp project imports the sheet in ~4 s and cannot hang on the game.

CLI:
  python tools/assets/godot_export.py --frames DIR --name fireball --cell 64 --fps 24 --loop \
      --anim-name cast --out DIR [--no-validate]
  python tools/assets/godot_export.py --sheet SHEET.png --cols 8 --rows 1 --cell 64 --name walk --out DIR

Run with the ComfyUI venv python (PIL); validation additionally needs the Godot console exe:
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/godot_export.py --help
"""
from __future__ import annotations
import os, sys, json, glob, re, shutil, subprocess, argparse, time
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT_EXE = os.environ.get("RH_GODOT",
                           r"C:\Users\vstef\tools\godot\Godot_v4.6.3-stable_win64_console.exe")


# ========================================================================================
# SHEET PACKING
# ========================================================================================
def _natkey(p):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", p)]


_SKIP_SUFFIX = ("_sheet.png", "_filmstrip.png", "_montage.png", "_strip.png")


def load_frame_dir(frames_dir):
    files = [f for f in sorted(glob.glob(os.path.join(frames_dir, "*.png")), key=_natkey)
             if not f.endswith(".import") and not f.lower().endswith(_SKIP_SUFFIX)]
    if not files:
        raise ValueError(f"no PNG frames in {frames_dir}")
    return [Image.open(f).convert("RGBA") for f in files]


def pack_sheet(frames, cols=None):
    """Pack uniform-cell frames row-major into a grid. cell = max frame dims; each frame centred.
    Returns (sheet, cell_w, cell_h, cols, rows)."""
    cell_w = max(f.width for f in frames)
    cell_h = max(f.height for f in frames)
    n = len(frames)
    cols = cols or n
    rows = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        sheet.alpha_composite(f, (cx + (cell_w - f.width) // 2, cy + (cell_h - f.height) // 2))
    return sheet, cell_w, cell_h, cols, rows


# ========================================================================================
# ANIM RESOLUTION
# ========================================================================================
def resolve_anims(anims, cols, rows, total):
    """Expand each anim spec into an explicit ordered frame-index list.
    An anim may declare {"row": r} (a whole grid row) or {"frames": [i,...]} (explicit indices)."""
    out = []
    for a in anims:
        name = a["name"]
        if "frames" in a:
            idxs = [i for i in a["frames"] if 0 <= i < total]
        elif "row" in a:
            r = a["row"]
            idxs = [r * cols + c for c in range(cols) if r * cols + c < total]
        else:                                   # default: all frames in order
            idxs = list(range(total))
        out.append({"name": name, "frames": idxs,
                    "fps": a.get("fps"), "loop": a.get("loop")})
    return out


# ========================================================================================
# .tres GENERATION  (Godot 4.x SpriteFrames, format=3)
# ========================================================================================
def build_spriteframes_tres(sheet_res_path, cell_w, cell_h, cols, anims, fps=24.0, loop=True):
    """Return the text of a Godot 4 SpriteFrames .tres. One AtlasTexture sub-resource per UNIQUE
    frame region; animations reference them with per-frame duration 1.0 and per-anim speed + loop."""
    # unique regions across all anims -> stable atlas ids
    region_of = {}
    order = []
    for a in anims:
        for idx in a["frames"]:
            if idx not in region_of:
                col, row = idx % cols, idx // cols
                region_of[idx] = (col * cell_w, row * cell_h, cell_w, cell_h)
                order.append(idx)
    atlas_id = {idx: f"Atlas_{k}" for k, idx in enumerate(order)}
    load_steps = 1 + len(order) + 1             # ext_resource + sub_resources + [resource]

    L = []
    L.append(f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]')
    L.append("")
    L.append(f'[ext_resource type="Texture2D" path="{sheet_res_path}" id="1_sheet"]')
    L.append("")
    for idx in order:
        x, y, w, h = region_of[idx]
        L.append(f'[sub_resource type="AtlasTexture" id="{atlas_id[idx]}"]')
        L.append('atlas = ExtResource("1_sheet")')
        L.append(f'region = Rect2({x}, {y}, {w}, {h})')
        L.append("")
    L.append("[resource]")
    anim_entries = []
    for a in anims:
        frames_txt = ", ".join(
            '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % atlas_id[idx]
            for idx in a["frames"])
        a_loop = loop if a.get("loop") is None else a["loop"]
        a_fps = fps if a.get("fps") is None else a["fps"]
        anim_entries.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (frames_txt, "true" if a_loop else "false", a["name"], _num(a_fps)))
    L.append("animations = [" + ", ".join(anim_entries) + "]")
    L.append("")
    return "\n".join(L)


def _num(v):
    """Godot float literal (keep a decimal point)."""
    f = float(v)
    return str(int(f)) + ".0" if f == int(f) else repr(f)


# ========================================================================================
# VALIDATION  (minimal throwaway Godot project: import + SceneTree load-check)
# ========================================================================================
_VALIDATE_GD = '''extends SceneTree
func _init():
	var path := "res://anim.tres"
	var res = ResourceLoader.load(path, "SpriteFrames")
	if res == null:
		printerr("VALIDATE_FAIL: load returned null")
		quit(1); return
	if not (res is SpriteFrames):
		printerr("VALIDATE_FAIL: not a SpriteFrames (", res.get_class(), ")")
		quit(1); return
	var sf := res as SpriteFrames
	var names := sf.get_animation_names()
	var total := 0
	for n in names:
		var fc := sf.get_frame_count(n)
		total += fc
		for i in range(fc):
			var tex = sf.get_frame_texture(n, i)
			if tex == null:
				printerr("VALIDATE_FAIL: null frame texture ", n, " #", i)
				quit(1); return
	print("VALIDATE_OK anims=", names, " total_frames=", total)
	quit(0)
'''


def validate_tres(tres_text, sheet_img, godot_exe=None, keep=False):
    """Copy the sheet + a res://-rooted .tres into a MINIMAL throwaway Godot project under
    medieval_rpg, `--import`, then run a SceneTree script that loads the .tres and touches every
    frame texture. Returns (ok, log). ok=True requires VALIDATE_OK and no ERROR/SCRIPT lines."""
    godot_exe = godot_exe or GODOT_EXE
    if not os.path.exists(godot_exe):
        return False, f"godot exe not found: {godot_exe}"
    tp = os.path.join(PROJECT_ROOT, "_screens", "_tres_validate_%d" % int(time.time() * 1000))
    os.makedirs(tp, exist_ok=True)
    try:
        with open(os.path.join(tp, "project.godot"), "w", encoding="utf-8") as f:
            f.write('config_version=5\n\n[application]\nconfig/name="tresval"\n'
                    'config/features=PackedStringArray("4.6")\n')
        sheet_img.save(os.path.join(tp, "sheet.png"))
        # the temp .tres always references the local imported sheet
        local_tres = re.sub(r'path="[^"]*"', 'path="res://sheet.png"', tres_text, count=1)
        with open(os.path.join(tp, "anim.tres"), "w", encoding="utf-8") as f:
            f.write(local_tres)
        with open(os.path.join(tp, "validate.gd"), "w", encoding="utf-8") as f:
            f.write(_VALIDATE_GD)
        imp = subprocess.run([godot_exe, "--headless", "--path", tp, "--import"],
                             capture_output=True, text=True, timeout=120)
        run = subprocess.run([godot_exe, "--headless", "--path", tp, "-s", "res://validate.gd"],
                             capture_output=True, text=True, timeout=120)
        out = (imp.stdout + imp.stderr + "\n" + run.stdout + run.stderr)
        ok = ("VALIDATE_OK" in out) and ("VALIDATE_FAIL" not in out) and \
             ("SCRIPT ERROR" not in out) and ("Parse Error" not in out)
        vline = next((ln for ln in out.splitlines() if "VALIDATE_OK" in ln or "VALIDATE_FAIL" in ln), "")
        return ok, vline or out[-400:]
    finally:
        if not keep:
            shutil.rmtree(tp, ignore_errors=True)


# ========================================================================================
# ORCHESTRATION
# ========================================================================================
def _res_path(abs_path):
    """res:// path if the file lives under the project root, else a bare filename (validation copies
    it locally regardless)."""
    ap = os.path.abspath(abs_path)
    if ap.lower().startswith(PROJECT_ROOT.lower()):
        rel = os.path.relpath(ap, PROJECT_ROOT).replace("\\", "/")
        return "res://" + rel
    return "res://" + os.path.basename(ap)


def export(frames=None, sheet=None, name="anim", out_dir=".", cols=None, rows=1,
           cell_w=None, cell_h=None, fps=24.0, loop=True, anims=None, validate=True):
    """Emit sheet + manifest + .tres for one finished animation. Returns a report dict."""
    os.makedirs(out_dir, exist_ok=True)
    if frames is not None:
        if isinstance(frames, str):
            frames = load_frame_dir(frames)
        sheet_img, cell_w, cell_h, cols, rows = pack_sheet(frames, cols=cols)
        total = len(frames)
    else:                                       # pre-packed sheet
        sheet_img = sheet if isinstance(sheet, Image.Image) else Image.open(sheet).convert("RGBA")
        assert cell_w and cell_h and cols, "sheet mode needs --cell (and --cols/--rows)"
        rows = rows or max(1, sheet_img.height // cell_h)
        total = min(cols * rows, (sheet_img.width // cell_w) * (sheet_img.height // cell_h))

    if not anims:
        anims = [{"name": name if rows == 1 else "default", "frames": list(range(total))}]
    resolved = resolve_anims(anims, cols, rows, total)

    sheet_path = os.path.join(out_dir, f"{name}_sheet.png")
    sheet_img.save(sheet_path)
    sheet_res = _res_path(sheet_path)

    manifest = {
        "name": name, "cell_w": cell_w, "cell_h": cell_h, "cols": cols, "rows": rows,
        "fps": fps, "loop": loop, "sheet": os.path.basename(sheet_path),
        "anims": [{"name": a["name"],
                   **({"row": src.get("row")} if "row" in src else {"frames": a["frames"]}),
                   "frame_count": len(a["frames"])}
                  for a, src in zip(resolved, anims)],
    }
    with open(os.path.join(out_dir, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    tres_text = build_spriteframes_tres(sheet_res, cell_w, cell_h, cols, resolved, fps=fps, loop=loop)
    tres_path = os.path.join(out_dir, f"{name}.tres")
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write(tres_text)

    rep = {"name": name, "sheet": sheet_path, "manifest": os.path.join(out_dir, f"{name}.json"),
           "tres": tres_path, "sheet_res": sheet_res, "cell": [cell_w, cell_h],
           "grid": [cols, rows], "frames": total,
           "anims": [{"name": a["name"], "frames": len(a["frames"])} for a in resolved]}
    if validate:
        ok, line = validate_tres(tres_text, sheet_img)
        rep["validate_ok"] = ok
        rep["validate"] = line
    return rep


def _cli():
    ap = argparse.ArgumentParser(description="Export finished frames -> Godot 4 sheet + manifest + "
                                             "SpriteFrames .tres (validated headless)")
    ap.add_argument("--frames", help="dir of finished per-frame PNGs")
    ap.add_argument("--sheet", help="pre-packed sheet PNG (needs --cell --cols --rows)")
    ap.add_argument("--name", default="anim")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--rows", type=int, default=1)
    ap.add_argument("--cell", type=int, default=0, help="cell (square) for --sheet mode")
    ap.add_argument("--fps", type=float, default=24.0)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--anim-name", default=None)
    ap.add_argument("--anims-json", default=None, help='JSON: [{"name":"walk","row":0},...]')
    ap.add_argument("--no-validate", action="store_true")
    args = ap.parse_args()

    anims = json.loads(args.anims_json) if args.anims_json else None
    if not anims and args.anim_name:
        anims = [{"name": args.anim_name}]
    rep = export(frames=args.frames, sheet=args.sheet,
                 name=args.name, out_dir=args.out,
                 cols=(args.cols or None), rows=args.rows,
                 cell_w=(args.cell or None), cell_h=(args.cell or None),
                 fps=args.fps, loop=args.loop, anims=anims, validate=not args.no_validate)
    print(json.dumps(rep, indent=2))


if __name__ == "__main__":
    _cli()
