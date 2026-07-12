"""UI KIT GENERATION — handcrafted interface assets (owner order 2026-07-12).

Map frame, parchment, minimap ring, panels, character-screen backdrop/dais/
sconces — generated on the owner's GPU with Fable-authored prompts in the
STYLE_ANCHOR palette, keyed + trimmed, saved to assets/art/ui/kit/ for the
screen reconstructions. Full-bleed pieces (parchment, backdrop) skip keying.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate as G
import interpret as I

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "ui", "kit"))

COMMON = ("pixel art, video game UI asset, near-black gothic dark-fantasy palette, "
          "deep umber brown, aged bone, wrought black iron, aged gold filigree accents, "
          "crisp pixel detail, ornate medieval")
NEG_UI = ("blurry, 3d render, photo, text, letters, numbers, watermark, bright neon, "
          "sci-fi, modern, minimal flat design, rounded plastic")

SPECS = [
    # keyed pieces (green-screened, cut + trimmed, kept LARGE)
    {"id": "map_frame", "keyed": True, "px": 640,
     "pos": f"thick ornate rectangular picture frame border, empty green center, {COMMON}, "
            "corner raven emblems, iron scrollwork edges, complete closed frame"},
    {"id": "mini_ring", "keyed": True, "px": 320,
     "pos": f"round ornate compass ring, empty green center hole, {COMMON}, "
            "wrought iron circle with gold inlay marks, small raven crest at top, complete closed ring"},
    {"id": "panel_frame", "keyed": True, "px": 512,
     "pos": f"rectangular gothic panel frame, empty green center, {COMMON}, "
            "dark wood beams with iron corner brackets, complete closed frame"},
    {"id": "title_banner", "keyed": True, "px": 512,
     "pos": f"hanging horizontal banner ribbon scroll, {COMMON}, dark leather scroll with "
            "gold trim ends, blank empty center for text, single banner"},
    {"id": "stone_dais", "keyed": True, "px": 360,
     "pos": f"round stone dais platform pedestal, slight top-down view, {COMMON}, "
            "cracked pale stone, melted candle wax at edges, single object"},
    {"id": "wall_sconce", "keyed": True, "px": 200,
     "pos": f"wall torch sconce, {COMMON}, wrought iron bracket with burning flame, single object"},
    {"id": "corner_flourish", "keyed": True, "px": 220,
     "pos": f"decorative corner flourish ornament, {COMMON}, iron and gold scrollwork curl, single object"},
    # full-bleed pieces (no keying — textures / backdrops)
    {"id": "parchment_tile", "keyed": False,
     "pos": "aged parchment paper texture, blank, fibers and subtle stains, warm cream tan, "
            "flat even lighting, seamless texture, no text, pixel art"},
    {"id": "select_backdrop", "keyed": False,
     "pos": "dark gothic cathedral hall interior, candlelit stone arches, deep shadow, "
            "distant stained glass glow, moody atmospheric backdrop, pixel art scene, "
            "near-black palette with candle amber and necrotic green accents"},
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, spec in enumerate(SPECS):
        seed = 77000 + i * 13
        if spec["keyed"]:
            pos = spec["pos"] + ", isolated on a plain uniform solid flat chroma green screen background"
            imgs = G.run_workflow(G.sdxl_workflow(pos, NEG_UI, seed))
            if not imgs:
                print(spec["id"], "FAILED (no image)")
                continue
            full = G._fetch_image(imgs[0])
            objs = I.process_render(full, target_px=spec["px"], n_colors=48, split=False)
            if not objs:
                print(spec["id"], "FAILED (keying)")
                continue
            obj = max(objs, key=lambda im: im.width * im.height)
            obj.save(os.path.join(OUT, spec["id"] + ".png"))
            print(spec["id"], obj.size)
        else:
            imgs = G.run_workflow(G.sdxl_workflow(spec["pos"], NEG_UI, seed))
            if not imgs:
                print(spec["id"], "FAILED (no image)")
                continue
            full = G._fetch_image(imgs[0]).convert("RGBA")
            full.save(os.path.join(OUT, spec["id"] + ".png"))
            print(spec["id"], full.size)


if __name__ == "__main__":
    main()
