"""MICROBAR ICONS — 15 unique panel icons (owner icon law 2026-07-12).

One 24px-readable painterly icon per game panel, generated in the anchor
palette, keyed + trimmed to assets/art/ui/micro/<name>.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate as G
import interpret as I

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "ui", "micro"))

COMMON = ("single game icon, pixel art, centered, near-black gothic palette with aged gold and "
          "bone highlights, crisp dark outline, painterly detail, no text")
NEG = ("blurry, 3d, photo, text, letters, watermark, bright neon, multiple objects, grid, "
       "frame, border, ui panel")

ICONS = {
    "character": "steel knight helmet icon",
    "spellbook": "open arcane tome icon with glowing rune",
    "talents": "branching talent tree icon, gnarled tree with gold nodes",
    "quests": "quill and scroll icon with wax seal",
    "map": "folded parchment map icon with red route",
    "achievements": "laurel wreath medal icon",
    "reputation": "twin heraldic banners icon",
    "mounts": "horse head icon in profile",
    "titles": "ornate name ribbon icon with crown",
    "pvp": "crossed swords icon",
    "calendar": "moon phase calendar stone icon",
    "crafting": "anvil and hammer icon",
    "codex": "legendary sword in codex book icon",
    "options": "iron gear cog icon",
    "menu": "raven head icon",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (name, subject) in enumerate(ICONS.items()):
        pos = f"{subject}, {COMMON}, isolated on a plain uniform solid flat chroma green screen background"
        imgs = G.run_workflow(G.sdxl_workflow(pos, NEG, 90210 + i * 7))
        if not imgs:
            print(name, "FAILED")
            continue
        full = G._fetch_image(imgs[0])
        objs = I.process_render(full, target_px=48, n_colors=32, split=False)
        if not objs:
            print(name, "KEY-FAIL")
            continue
        obj = max(objs, key=lambda im: im.width * im.height)
        obj.save(os.path.join(OUT, name + ".png"))
        print(name, obj.size)


if __name__ == "__main__":
    main()
