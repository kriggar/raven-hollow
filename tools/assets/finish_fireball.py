# Assemble a clean animated fireball sprite sheet from raw Wan frames.
# frames -> anim_finish (palette lock/hard-edge/anchor/smooth) -> sheet + .tres -> gauntlet -> GIF.
import glob, os, shutil, subprocess, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "assets"))
OUT = os.path.join(ROOT, "_screens", "fireball_final")
RAW = os.path.join(OUT, "raw")
os.makedirs(RAW, exist_ok=True)

PREFIX = sys.argv[1] if len(sys.argv) > 1 else "rh_fb_clean"
CELL = int(sys.argv[2]) if len(sys.argv) > 2 else 64
COLORS = int(sys.argv[3]) if len(sys.argv) > 3 else 24

comfy_out = r"C:\Users\vstef\ComfyUI\output"
frames = sorted(glob.glob(os.path.join(comfy_out, PREFIX + "_*.png")))
if not frames:
    print("NO FRAMES for", PREFIX); sys.exit(1)
# skip first 2 (settle-in) and copy to clean raw dir, re-indexed
for i, f in enumerate(frames[2:]):
    shutil.copy(f, os.path.join(RAW, f"f_{i:03d}.png"))
n = len(frames) - 2
print(f"raw frames: {n}")

# 1) finishing chain
subprocess.run([sys.executable, os.path.join(ROOT, "tools", "assets", "anim_finish.py"),
                RAW, "--cell", str(CELL), "--colors", str(COLORS), "--anchor", "centroid",
                "--out", os.path.join(OUT, "finished"), "--name", "fireball", "--filmstrip"],
               check=True)

# 2) Godot export (sheet + json + validated .tres)
fin_frames = os.path.join(OUT, "finished", "frames")
if not os.path.isdir(fin_frames):
    # anim_finish may write frames flat in finished/
    fin_frames = os.path.join(OUT, "finished")
subprocess.run([sys.executable, os.path.join(ROOT, "tools", "assets", "godot_export.py"),
                "--frames", fin_frames, "--name", "fireball", "--out", os.path.join(OUT, "godot"),
                "--fps", "24", "--loop", "--anim-name", "spin"], check=False)

# 3) build a clean looping GIF preview (transparent, 3x nearest upscale)
fin = sorted(glob.glob(os.path.join(fin_frames, "*.png")))
ims = [Image.open(p).convert("RGBA") for p in fin]
if ims:
    scale = max(1, 240 // max(ims[0].size))
    ups = [im.resize((im.width*scale, im.height*scale), Image.NEAREST) for im in ims]
    # ping-pong for seamless flicker loop
    seq = ups + ups[-2:0:-1]
    # flatten onto dark tile for the GIF (GIF alpha is 1-bit; keep bg dark)
    flat = []
    for im in seq:
        bg = Image.new("RGBA", im.size, (14, 12, 16, 255))
        bg.alpha_composite(im)
        flat.append(bg.convert("P", palette=Image.ADAPTIVE, colors=64))
    gif = os.path.join(OUT, "fireball_final.gif")
    flat[0].save(gif, save_all=True, append_images=flat[1:], duration=80, loop=0, disposal=2)
    print("GIF:", gif, len(seq), "frames")

    # transparent packed sheet preview (single row, upscaled) for the owner
    sw = ups[0].width; sh = ups[0].height
    sheet = Image.new("RGBA", (sw*len(ups), sh), (0, 0, 0, 0))
    for i, im in enumerate(ups):
        sheet.paste(im, (i*sw, 0), im)
    sheet.save(os.path.join(OUT, "fireball_sheet_preview.png"))
    # dark-bg contact strip so the owner can eyeball frames
    strip = Image.new("RGB", (sw*len(ups), sh), (18, 16, 20))
    for i, im in enumerate(ups):
        strip.paste(im.convert("RGB"), (i*sw, 0), im)
    strip.save(os.path.join(OUT, "fireball_strip.png"))
    print("SHEET frames:", len(ups), "cell", sw, "x", sh)

print("DONE ->", OUT)
