# Asset Manifest — Raven Hollow: Emberfall

Ground truth for every art asset in `res://assets/`. All geometry below is **verified by pixel inspection** — do not guess different layouts.
Contact sheets with numbered sprites (viewable images): `_downloads/cs_houses.png`, `_downloads/cs_plants.png`, `_downloads/cs_cainos_props.png`, `_downloads/cs_szadi_props.png`.

Style target: **Graveyard Keeper** — muted earthy palette, warm golden-hour lighting, detailed medieval village. Grid: **32 px**. Viewport: **640×360**, integer-scaled.

## Characters — `res://assets/art/characters/`

### Szadi NPC sheets (npc_male1..4.png, npc_female1..2.png) — 256×576 each
- Frame block: **32×48**. Sheet = 8 cols × 12 rows.
- 12 rows = **4 outfit variants × 3 directions**, direction order per variant: **row 0 = side (faces LEFT), row 1 = down, row 2 = up**. So `row = variant*3 + {side:0, down:1, up:2}`.
- Columns **0–3 = idle** frames, **4–7 = walk** frames.
- Right-facing = flip_h on the side animation.
- Character body ~30 px tall inside the 32×48 block, small baked ground shadow at feet. Feet sit ~2-4 px above block bottom.
- 6 sheets × 4 variants = **24 distinct villagers**. Realistic proportions, muted earthy clothing.
- Use `SheetAnim.make_szadi_frames(sheet_path, variant)` (res://scripts/sheet_anim.gd) — returns SpriteFrames with anims `idle_side/idle_down/idle_up/walk_side/walk_down/walk_up`.

### Tavern maid (tavern_maid/) — Pixel Crawler Citizen_F
- `idle_down/side/up.png` = 256×64 (4 frames of 64×64); `walk_down/side/up.png` = 384×64 (6 frames of 64×64).
- Body ~30 px tall centered in the 64×64 frame. Verify side-facing direction by viewing the PNG before flipping.
- Use `SheetAnim.make_maid_frames()`.

## Buildings — `res://assets/art/buildings/`  (Szadi Fantasy Lands — THE style anchor)
Individual pre-cut buildings, transparent background, feet-line at bottom edge minus a few px of ground foliage:
- `house_00.png` 211×241 — workshop/smithy: open hay-roofed porch with barrels & tools.
- `house_01.png` 160×247 — small cottage, blue door.
- `house_02.png` 223×285 — two-story townhouse w/ ladder, red banner, shop awning + crates → merchant shop.
- `house_03.png` 186×298 — barn, big X-braced door, hay.
- `house_04.png` 390×277 — **large manor / INN**, multi-gable, courtyard entrance.
- `house_05.png` 169×252 — cottage with sacks.
- `house_06.png` 191×234 — house with awning + red banner → shop variant.
- `house_07.png` 132×161 — open storage shed with barrels & crates.
- `szadi_building_parts.png` 832×288 — modular walls/roofs/doors/windows/tents for extra structures (optional).
Doors are at plausible positions along each building's bottom edge — pick door world positions when placing.

## Terrain — `res://assets/art/terrain/`  (Cainos, 32 px grid, olive-muted — matches Szadi palette)
- `cainos_grass.png` 256×256 = 8×8 tiles of 32 px. Top rows: plain olive grass + subtle flower/sparkle variants. Bottom-left quadrant: grass with embedded grey stone slabs (pathway variants, several damaged/cracked). Row/col map (0-indexed, by 32px tile): rows 0–3 mostly pure grass variants (some with tiny flowers at cols 4–7 of rows 0–1); rows 4–7 contain stone-slab-on-grass path tiles (full slabs at cols 0–2, partial/cracked at cols 4–7).
- `cainos_stone_ground.png` 256×256 — grey stone plaza tiles: large slab (cols 0–2, rows 0–2), border pieces, dotted decorative slabs (right side), plus-shaped connectors (bottom-right).
- `cainos_wall.png` 512×512 — stone wall tileset (for low walls / cemetery wall).

## Vegetation — `res://assets/art/vegetation/`  (Cainos, olive, baked soft shadows)
- `plant_00.png` 113×139, `plant_01.png` 95×136, `plant_02.png` 83×120 — big trees WITH baked ground shadow (trunk base ≈ 60% height; sort origin should be near bottom-center minus shadow ~10 px).
- `plant_03..08.png` (23–50 px) — bushes.
- `plant_09..14.png` (12–17 px) — grass tufts.

## Props
`res://assets/art/props/` — all with transparent bg:
- Szadi (matches buildings perfectly): `szadi_prop_00` 81×74 ivy ground patch (decal), `szadi_prop_01` 153×128 **stone plaza patch with ivy border** (ground decal), `szadi_prop_02..05` foliage bits, `_06/_07/_19/_20` red-brick piles, `_08/_22` barrels, `_09` crate, `_11` **stone well with post & bucket** 52×48, `_12/_13` hay piles, `_14/_29` big hay mounds 42×49, `_15/_32` crate/barrel/sack stacks, `_16` ladder 16×64, `_17/_23/_25` logs, `_18` sacks, `_21` brick pallet 29×24, `_24/_26/_31/_33` grain sacks, `_27/_28` wooden poles, `_30` log pile.
- Cainos (grey stone, use sparingly): `cainos_prop_01/_08/_09` chests, `_02` crate, `_04` stone bench, `_06` seated angel-ish statue 39×72, `_07` round door, `_17/_22/_28/_39` wood signposts, `_18` barrel, `_20/_21` stone steles (gravestone-like), `_23/_27/_31` clay pots, `_24` small shrine/altar, `_30` **large round well/fountain base** 97×72, `_32` stone circle ruin 58×49, `_33.._42` rocks.

## Set dressing atlas — `res://assets/art/decor/` (LPC, 32 px grid)
- `lpc_decorations.png` 512×2048 — use AtlasTexture regions. Content map (approx y-bands, VERIFY by viewing the image before cutting exact regions):
  - y 0–340: gravestones, tombs, crosses, stone statues (children/wolf), dirt grave mounds — the GRAVEYARD kit.
  - y 0–60 x 160–352: hanging shop signs incl. "INN".
  - y 0–260 x 380–512: lanterns (several frames — some are animation pairs) and candles/torch flames (animation frames).
  - y 290–345 x 300–460: gnarled spooky trees + clock.
  - y 350–420: wooden shrine hut, palisade walls.
  - y 416–500: stone WELL (x 0–64) and covered well (x 440–512), buckets, garden rows.
  - y 500–600: **fountain with animated water** (3 frame variants at x 0–190, 64×96 each) — plaza centerpiece; carts, tools.
  - y 610–780: hay bales/stacks (x 0–190), wood piles, market goods, forge anvils, hammers.
  - y 790–935: **market stall awnings** (striped: grey/white, green/white, orange/white) + wooden stall counters ~96×144 per stall.
  - y 940–1300: tables, benches, cabinets, crates, big tents, banners (white/blue/red/green hanging cloth), colorful bunting.
  - y 1300–1460: carts/wagons (~96×80), gallows, stocks, cartwheels.
  - y 1460–1540: **campfires with flame animation frames** (~32×48 each, 4-5 frames), tipi tents, cauldron.
  - y 1540–1900: large canvas tents (grey/tan, ~160×160), stone bridge piece.
- `lpc_fences.png` 512×1024 — wooden fence Wang set (posts, rails, corners; several styles incl. stone-base). Top-left 32px tiles connect: use for pens/graveyard fence.

## Fonts — `res://assets/fonts/`
- `alagard.ttf` — medieval display font (headers, NPC names, location banner). Body text: same font at small size or Godot default.

## Audio — `res://assets/audio/music/`
- `theme_lost_village.ogg`, `theme_plain.ogg` (Ninja Adventure, CC0) — calm village ambience loops. Play at ~-12 dB.

## Enemies — `res://assets/art/enemies/` (Pixel Crawler, side-view, flip_h for facing)
8 mob types: `orc, orc_rogue, orc_shaman, orc_warrior, skeleton, skeleton_mage, skeleton_rogue, skeleton_warrior`, each with `<name>_idle.png`, `<name>_run.png`, `<name>_death.png`.
- Idle: 128×32 = **4 frames of 32×32**.
- Run: 384×64 = **6 frames of 64×64** (body centered, feet ~16 px below frame center like the maid).
- Death: **VARIES per sheet** (e.g. skeleton 768×64 = 12×64×64; orc_warrior 576×80 = 9 frames of 64×80; skeleton_warrior 384×48 = 8×48×48). Frame width is 64 when height ≥ 64, else = height. VERIFY each sheet with PIL before hardcoding: frame_count = width / frame_width, and confirm by cropping.
- Sheets face ONE side; verify which with a crop, flip_h for the other. No up/down rows — acceptable for enemies.

## Weapons — `res://assets/art/weapons/` — pc_wood.png 192×112, pc_bone.png 224×144: grids of small weapon sprites (bows, staffs, clubs, bones — inspect + crop what you need).

## UI — `res://assets/art/ui/` (Kenney UI RPG expansion, CC0, 180 files)
Nine-patch panels and widgets, notably: `panel_brown.png`, `panelInset_beige.png`, `panelInset_beigeLight.png`, `buttonLong_brown.png`, `buttonSquare_brown.png`, `barsHorizontal_*.png` etc. Browse the folder; use NinePatchRect or StyleBoxTexture. Combine with dark StyleBoxFlat (existing dialogue style) — the game UI look = dark aged wood + parchment + gold Alagard text, Kenney 9-patches tinted darker via modulate where needed.

## Ability/Item icons — `res://assets/art/icons/` (J.W. Bjerk "Painterly Spell Icons" 1-4, CC-BY 3.0 — attribution required)
**DEPRECATED (Phase B.2):** no runtime code or data references this pack anymore — every ability/item/UI icon now resolves through the Shikashi pixel registry (`assets/art/icons_pixel/` + `scripts/icons_pixel.gd`). Safe to delete the folder (and drop the CC-BY attribution) once the team confirms nothing else is planned to use it.
439 painterly 64×64 icons. Naming: `<theme>-<color>-<power>.png` e.g. `fireball-red-1.png`, `heal-royal-2.png`, `protect-sky-3.png`, `beam-acid-1.png`. Full list: `assets/art/icons/_icon_list.txt`. Themes include: fireball, fire-arrows, flame, burning, heal, regen, protect, holy, light, wind, air-burst, ice, snow, water, acid, poison, death, skull, raise-dead, curse, evil-eye, horror, beam, bolt, lightning, arrow(s), needles, stone, rock, leaf, vines, wild, haste, teleport, enchant, magic, rune, wisp, eye, fog, moon, star, sun. Pick colors that match each class's palette.

## Licenses (assets/licenses/, full text) — summary
- Szadi Art packs (buildings, props, NPCs): free personal+commercial, no redistribution of raw assets. No credit required (we credit anyway).
- Cainos Top Down Basic: free+commercial, modify OK, no redistribution.
- Pixel Crawler (Anokolisa): free+commercial, no credit required.
- LPC decorations/fences: **CC-BY-SA 3.0 / GPL 3.0 — attribution REQUIRED** (see lpc_decorations_credits.txt).
- Alagard font (Hewett Tsoi): freeware, commercial OK.
- Ninja Adventure audio: CC0.
