#!/usr/bin/env python3
# Compose 6 distinct Raven Hollow class sprites from LPC layers + a muted pass.
import json, os, glob
from PIL import Image

ROOT = r"C:\Users\vstef\lpc_assets"
SD = os.path.join(ROOT, "sheet_definitions")
SS = os.path.join(ROOT, "spritesheets")
OUT = r"C:\Users\vstef\Desktop\rpg\medieval_rpg\assets\art\chars\lpc"
BODY = "male"
ANIMS = ["walk", "run", "slash", "thrust", "spellcast", "shoot", "hurt"]  # idle = walk[0] in-game

def resolve_png(prefix, anim, color):
    """Handle both flat (prefix/anim.png) and color-variant (prefix/anim/<color>.png) layouts."""
    flat = os.path.join(SS, prefix.replace("/", os.sep), anim + ".png")
    if os.path.exists(flat):
        return flat
    d = os.path.join(SS, prefix.replace("/", os.sep), anim)
    if os.path.isdir(d):
        for v in (color, "brown", "dark_gray", "gray", "light_gray", "black", "steel"):
            p = os.path.join(d, v + ".png")
            if os.path.exists(p):
                return p
        g = glob.glob(os.path.join(d, "*.png"))
        return g[0] if g else None
    return None

_defcache = {}
def find_def(keyword):
    if keyword in _defcache: return _defcache[keyword]
    hits = [p for p in glob.glob(os.path.join(SD, "**", "*.json"), recursive=True)
            if os.path.basename(p)[:-5].endswith(keyword) and "meta" not in p.lower()]
    if not hits:
        hits = [p for p in glob.glob(os.path.join(SD, "**", "*.json"), recursive=True)
                if keyword in os.path.basename(p).lower() and "meta" not in p.lower()]
    _defcache[keyword] = hits[0] if hits else None
    return _defcache[keyword]

def layers_of(defpath):
    """-> list of (zPos, male_prefix) for a def."""
    d = json.load(open(defpath, encoding="utf-8"))
    out = []
    for k, v in d.items():
        if k.startswith("layer_") and isinstance(v, dict):
            # prefer the male body variant; fall back through common body types,
            # then any available string prefix (e.g. female-only robes).
            pref = ""
            for bt in (BODY, "thin", "muscular", "teen", "female", "male"):
                if v.get(bt):
                    pref = v[bt]; break
            if not pref:
                for kk, vv in v.items():
                    if kk != "zPos" and isinstance(vv, str) and vv:
                        pref = vv; break
            if pref:
                out.append((int(v.get("zPos", 50)), pref.strip("/")))
    return out

# class -> ordered list of def keywords (body/head first)
CLASSES = {
    "warrior":     ["body", "heads_human_male", "hair_plain", "legs_armour", "feet_plate_toe", "torso_armour_plate", "weapon_sword_longsword"],
    "rogue":       ["body", "heads_human_male", "hat_hood_cloth", "legs_leggings", "feet_boots_basic", "torso_armour_leather", "weapon_sword_dagger"],
    "mage":        ["body", "heads_human_male", "hair_long", "legs_leggings", "feet_shoes_basic", "torso_clothes_robe", "weapon_magic_wand"],
    "paladin":     ["body", "heads_human_male", "hair_plain", "legs_armour", "feet_plate_toe", "torso_armour_plate", "weapon_blunt_mace"],
    "necromancer": ["body", "heads_human_male", "hat_hood_cloth", "legs_leggings", "feet_shoes_basic", "torso_clothes_robe", "weapon_magic_gnarled"],
    "hunter":      ["body", "heads_human_male", "hair_plain", "legs_leggings", "feet_boots_basic", "torso_armour_leather", "weapon_ranged_bow_normal", "quiver"],
}
# preferred clothing color per class (applies to color-variant layers like robes)
COLOR = {"warrior": "steel", "rogue": "dark_brown", "mage": "blue",
         "paladin": "light_gray", "necromancer": "black", "hunter": "forest_green"}

MUTE = (0.90, 0.86, 0.76)   # warm-olive multiply
def muted(im):
    # desaturate ~22% toward luma, then warm-olive multiply
    px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0: continue
            lum = int(0.299*r + 0.587*g + 0.114*b)
            r = int((r*0.78 + lum*0.22) * MUTE[0])
            g = int((g*0.78 + lum*0.22) * MUTE[1])
            b = int((b*0.78 + lum*0.22) * MUTE[2])
            px[x, y] = (min(r,255), min(g,255), min(b,255), a)
    return im

def compose(cls, keywords):
    made = {}
    color = COLOR.get(cls, "brown")
    for anim in ANIMS:
        stack = []  # (zPos, path)
        for kw in keywords:
            dp = find_def(kw)
            if not dp: continue
            for z, pref in layers_of(dp):
                p = resolve_png(pref, anim, color)
                if p:
                    stack.append((z, p))
        if not stack: continue
        stack.sort(key=lambda t: t[0])
        base = None
        for z, p in stack:
            im = Image.open(p).convert("RGBA")
            if base is None: base = Image.new("RGBA", im.size, (0,0,0,0))
            if im.size != base.size:
                nb = Image.new("RGBA", (max(base.size[0],im.size[0]), max(base.size[1],im.size[1])), (0,0,0,0))
                nb.alpha_composite(base); base = nb
                nb2 = Image.new("RGBA", base.size, (0,0,0,0)); nb2.alpha_composite(im); im = nb2
            base = Image.alpha_composite(base, im)
        base = muted(base)
        d = os.path.join(OUT, cls); os.makedirs(d, exist_ok=True)
        base.save(os.path.join(d, anim + ".png"))
        made[anim] = base
    return made

tiles = []
for cls, kws in CLASSES.items():
    m = compose(cls, kws)
    print(cls, "->", sorted(m.keys()))
    # grab the DOWN-facing standing frame from idle (or walk)
    src = m.get("walk")
    if src:
        # rows: up,left,down,right; take down row frame 0 (64x64) as standing pose
        fr = src.crop((0, 128, 64, 192))
        tiles.append((cls, fr))

# montage of all 6 (down-facing), 3x zoom
if tiles:
    cw = 64*3
    mont = Image.new("RGBA", (cw*len(tiles), 64*3 + 20), (30, 28, 24, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(mont)
    for i, (cls, fr) in enumerate(tiles):
        mont.alpha_composite(fr.resize((cw, cw), Image.NEAREST), (i*cw, 0))
        dr.text((i*cw+4, 64*3+4), cls[:9], fill=(220,210,190,255))
    mp = r"C:\Users\vstef\Desktop\rpg\medieval_rpg\_screens\lpc_classes_montage.png"
    mont.save(mp); print("montage:", mp)
print("DONE")
