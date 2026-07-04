# VFX_AAA_PLAN — AAA Spell-VFX + Crafting-Animation Acquisition Plan
Raven Hollow: Emberfall · Godot 4.6 · cap 60 · Draconia canon

**Mandates served (MANDATES.md):**
- *"each class's spells = AAA-studio quality — cohesive class palette, proper animations/VFX, from DOWNLOADED packs"* (Combat/Classes)
- *"FULL crafting animations from downloaded packs"* (Crafting & Economy)
- Constraints honored: 60 FPS cap (no per-rank texture explosion), WYSIWYG law (a spell's VFX **is** its identity at every rank), Tone Law (muted, never neon — `class_defs.gd` already encodes this in every ability `color`).

Status of upstream docs: `TALENTS_SPELLS.md` and `CRAFTING.md` are **not yet written**. This plan derives spell-family counts from the mandate (~30 spells/class, WoW trainer+rank model) and the 7×8 shipped ability kits in `scripts/class_defs.gd`; profession assumptions come from the mandate ("WoW structure, Draconia professions") and lore anchors (forge-city Sângeroasă, the Thread/weaving, alchemy pillar, the Ledger). Where those docs land later, only §3/§6 tables need renaming — the acquisition list and architecture hold.

---

## 1. Where we are today

`scripts/fx_library.gd` (FXLib) is a healthy foundation:
- **33 base sheet defs** (`_DEFS`), pixel-verified geometry, lazy-built + session-cached `SpriteFrames`.
- **~50 ability aliases** (`_ALIASES`) mapping ability ids → base sheet + default opts (scale/tint/offset/z), caller opts win.
- **2 hand-coded composites** (`hammer_blow`, `frost_nova`) — the pattern §7 generalizes.
- Sources in `assets/art/vfx/` (18 author dirs, CREDITS_VFX.txt): Pimen ×11 sets, Frostwindz free necro/priest, Foozle, CodeManu, DevWizard, XYEzawr, acid/earth spell packs.

**Downloaded but not yet mined:** `_downloads/vfx_packs/` holds **47 pack dirs**; only ~18 sheet families are registered. Unmined highlights: `frostwindz_frost_knight_free`, `frostwindz_impacts_free`, `frostwindz_slashes`, `magical-animation-effects`, `magical-water-effect`, `water-spell-effect-02`, `thunder-spell-effect-02`, `earth-spell-effect-2`, `halloween-special-effects`, `cutting-and-healing`, `pixel-battle-effects`, `retro_impact_effect_pack_all`, `bdragon_effect_bullet_16`, `fire_pixel_bullet_16x16`, `free_effect_and_bullet_16x16`, `free_effect_bullet_impact_explosion_32x32`, both `free_smoke_fx_pixel` packs, `fga_magic_effects`, `pixel_holy_spell_effect_32x32_pack_3`, `foozle_pixel_magic`, `foozle_rpg_vfx_lite`.

**Gap in one sentence:** the demo kits (8 abilities × 7 classes) are covered by re-tinting ~20 sheets; the mandate needs ~30 spells × 7 classes with class-cohesive palettes, rank-growing intensity, cast-loops, channels/beams, and screen-owning ultimates — that requires (a) mining the other ~29 owned packs, (b) buying the full paid versions of the exact authors we already ship (Pimen, Frostwindz), and (c) a data-driven rank/layer system in FXLib.

---

## 2. The math: 30 spells ≠ 30 unique effects

WoW-classic model (mandated): ~30 *spells* per class, most learned in **ranks** from trainers. Rank N of Fireball is the same effect, hotter. So per class:

| Bucket | Spells | Unique VFX families |
|---|---|---|
| Basic attack + rotational damage | ~8 | 4–5 (smears/projectiles, rank-shared) |
| Ground AOE / DoT zones | ~5 | 3 |
| Buffs / auras / shields | ~6 | 3–4 loops |
| Heals (pal/druid) or curses (necro) etc. | ~4 | 2–3 |
| Mobility + utility (marks, taunts, traps) | ~4 | 2–3 |
| Summons / forms | ~2 | 1–2 |
| Ultimate (30s+ CD showpieces) | ~1–2 | 1–2 **hero** effects |
| **Total** | **~30** | **~14–16 families** |

7 classes × ~15 families ≈ **~105 VFX families**. Of these, ~60% can be shared base sheets re-tinted per class (the FXLib alias pattern, already proven), leaving **~40 class-unique "hero" sheets** — exactly what the paid Pimen/Frostwindz sets provide. Every family needs up to 4 **rank tiers** (§7) delivered by node-level opts + added layers, never new textures.

---

## 3. Per-class VFX kits

Palette rule: 3 locked swatches per class — **Base** (the `class_defs.gd` class color, muted), **Mid** (dominant ability accent), **Hot** (the near-white core reserved for crits, max-rank, ultimates). Every sheet entering a class kit is conformed to these swatches via the gradient-map shader (§7.4) — `modulate` alone cannot re-hue multi-hue sheets and is why `whirlwind`'s leaf-green swirl needed apology comments.

### Warrior — "Red Steel & Earth"
- Palette: Base `(0.68,0.30,0.26)` rust-red · Mid steel-grey `(0.62,0.60,0.58)` · Hot ember-orange `(0.90,0.58,0.30)`.
- Families: melee smears (3 weights: quick/heavy/executioner), shield/charge dust wake, shout ring (air_burst family), banner/stance auras ×2, ground slams (quake_rock owned), bleed-proc splash, taunt mark, ultimate **Avalanche of the Drill-Yard** (multi-slam quake + dust column + screen shake).
- Owned coverage: strong (smears, hit_spark, dust, quake_rock, air_burst, protection_ward). Buy: heavier slash set (Frostwindz Slashes full / Pimen slashes bundle) for the 3-weight smear ladder.

### Rogue — "Ash, Poison, Blood"
- Palette: Base ash-grey `(0.62,0.62,0.66)` · Mid poison green `(0.46,0.60,0.30)` · Hot arterial red `(0.72,0.16,0.16)`.
- Families: dagger smears (fast ×2), stealth smoke in/out, poison vial splash + lingering cloud loop, bleed stacks (3-stage drip decal), fan/blossom blade spins, trap/garrote, shadow-clone feint, ultimate **Red Ledger** (screen-edge vignette + multi-backstab flurry smears).
- Owned: smears, smoke ×4 packs, acid_hit, blade_spin. Gap: **lingering poison cloud loop** (acid pack has burst only), bleed drip decals → `halloween-special-effects` (blood splash — mine it), else Pimen "Cutting" full.

### Mage — "Violet Flame, True Fire, Frost" (3 schools = 3 sub-palettes, violet is the class signature)
- Palette: Base violet `(0.62,0.42,0.78)` · Mid flame `(0.92,0.55,0.25)` / frost `(0.55,0.72,0.86)` · Hot white-violet.
- Families: spark bolt, fireball (fly+impact+scorch), ice lance (fly+shatter), frost nova (owned composite), flame strike pillar, blizzard-style rain, blink, mana/ice barriers, arcane channel beam, cast-loop hand glyph, ultimate **Cinderfall** upgraded (meteor + ember rain + burning ground loop).
- Owned: best-covered class (Pimen fire/ice/thunder, foozle fireball). Gaps: **cast-loop glyphs**, **channel beam**, **burning-ground loop**, big meteor. → Pimen Fire full set (02/03 have the large explosion + burning ground), XYEzawr fire columns (free), `magical-animation-effects` (mine first).

### Paladin — "Dawn Gold"
- Palette: Base gold `(0.85,0.68,0.35)` · Mid warm ivory `(0.96,0.90,0.62)` · Hot white-gold `(1.0,0.94,0.66)`.
- Families: hammer composite (owned), holy bolt, judgment brand (falling sigil), consecration ground loop (owned), heal blooms ×2 sizes, shields (holy_loop wrap + ward_bubble dome — owned), aura ring loops ×3 (devotion-style), resurrection pillar, ultimate **Dawnbreak** upgraded (owned 128px pillar + added god-rays layer).
- Owned: excellent — Frostwindz priest free + Pimen holy + bdragon holy pack 3 + devwizard bubble. Buy: **Frostwindz Priest FULL** (the free set's big sheets are exactly the style; full set adds the cast circles, beams, multi-stage blooms).

### Necromancer — "Grave-Green, Bone, Violet Rot"
- Palette: Base grave-green `(0.45,0.72,0.35)` · Mid bone `(0.82,0.80,0.72)` · Hot sickly white-green.
- Families: soul bolt (owned), drain-life **beam/tether**, curse sigils (2 DoT decals), bone nova (owned re-tint), bone armor shell (owned), summon circle + rise (owned), corpse-burst, soul-harvest rain, pet death-poof, ultimate **The Unclosed Entry** (ledger-rune circle + mass rise + soul vortex — Bloodstone tie-in).
- Owned: Frostwindz necro free + Pimen dark. Gaps: **beam/tether** (nothing owned does a sustained beam), **curse sigil decals**, soul vortex. → **Frostwindz Necromancer FULL** (P0 — it is literally this class's kit, same author as our shipped sheets), XYEzawr soul/ghost packs (free).

### Hunter (Rookwarden) — "Slate-Teal & Feather"
- Palette: Base slate-teal `(0.24,0.48,0.50)` · Mid moss `(0.58,0.64,0.42)` · Hot pale sky `(0.72,0.74,0.64)`.
- Families: arrow trails (thin, 3 speeds), piercing wind-hit, trap snap (roots owned re-tint + added metal glint), mark sigil over target, feather burst (dash owned), rook summon circle (owned), volley rain, aspect auras ×2, ultimate **Storm of Feathers** upgraded (radial volley + feather cyclone loop + shadow-of-wings ground decal).
- Owned: wind packs, roots, magic_arrow strip. Gaps: **feather-specific sheets** (currently tinted smoke — weakest kit in the game), trap metal snap, mark sigil. → XYEzawr arrow packs (more variants, free), `pixel-battle-effects`/`retro_impact` mining; feather burst may need the one **custom-assembled strip** (from owned crow/raven creature sheets' frames — pack-derived, mandate-compliant).

### Druid — "Wildwood Green & Storm"
- Palette: Base wildwood `(0.36,0.55,0.30)` · Mid storm blue-grey `(0.70,0.80,0.92)` · Hot sun-through-leaves gold-green.
- Families: maul smears (bear-weight), gale orb (fly+burst), thornroot (owned), stormbolt strike (needs a real **sky-strike bolt**), rejuvenation bloom loop (owned base), wrath-style solar bolt, forms shift burst (bear/travel), spirit beast summon (owned), swarm cloud, ultimate **Tempest** upgraded (multi-bolt storm + rain sheet + wind shear loops).
- Owned: wood/wind/priest-bloom. Gaps: **vertical lightning strike** (thunder packs owned are projectile/hit only — mine `thunder-spell-effect-02` first, it has the strike), leaf/petal particles, swarm. → Pimen Thunder full, `magical-water-effect` for rain (owned, unmined).

---

## 4. Gap analysis — owned 47 VFX packs vs the mandate

**Covered by owned packs (mine, don't buy):**
| Need | Owned source |
|---|---|
| All projectile/impact bases, elemental | Pimen ×11, foozle, bdragon bullet packs ×4, retro_impact (ALL variants) |
| Smears/slashes, 2 authors | pimen_slashes_thrusts, frostwindz_slashes, battle-vfx-slashes |
| Smoke/dust/poof | 4 packs (pimen ×2, bdragon free_smoke ×2) |
| Shields/wards/domes | codemanu protection ward, devwizard bubble, frostwindz necro shell |
| Holy kit ~80% | pimen_holy, frostwindz_priest_free, pixel_holy_pack_3 |
| Frost melee (DK-flavor warrior talents?) | frostwindz_frost_knight_free |
| Water/rain | magical-water-effect, water-spell-effect-02 (both unmined) |
| Earth/rock | earth-spell-effect-01 + -2, foozle rocks |
| Generic magic bursts, buffs sparkles | fga_magic_effects, magical-animation-effects, cutting-and-healing (heal slashes!) |
| Blood/gore procs | halloween-special-effects |

**True gaps (cannot be mined from the 47):**
1. **Cast-time loops** — hand-glyph / gathering-energy anims for every caster. Nothing owned loops at the *caster* during a cast bar. → Frostwindz full sets include cast circles; XYEzawr has charge-ups.
2. **Beams/tethers/channels** — drain life, arcane channel. No owned sheet is a beam. → Frostwindz Necromancer full; search "pixel beam vfx".
3. **Screen-owning ultimates** — 128px+ multi-stage showpieces beyond the 2 Frostwindz free ones. → paid Pimen large sets + Frostwindz fulls + §7 layering (composite 3 owned sheets = 1 ultimate).
4. **Vertical lightning strikes** — verify `thunder-spell-effect-02` first; if it's projectile-only, buy Pimen Thunder full.
5. **Feather/nature-specific** (hunter, druid): petals, leaves, feather bursts. Thinnest area of the entire itch pixel-VFX ecosystem — plan the custom-strip fallback (§3 Hunter).
6. **DoT ground decals** (poison pools, curse sigils, burning ground) as *loops*, not bursts.
7. **Crafting station anims beyond the forge** — §5.

---

## 5. Crafting animations (mandate: FULL animations, from downloaded packs)

Professions (working set until CRAFTING.md lands — Draconia-native per lore): **Emberforging** (smith — Sângeroasă forge canon), **Threadweaving** (tailor — the Thread), **Grave-tending/Bonecarving** (jewel-slot analog), **Alchemy** (lore pillar III), **Ledger-scribing** (inscription — debt-ledger canon), **Tanning**, **Hearth-cooking**, + gathering (herbing/mining/skinning).

### 5.1 The three-layer craft animation model
AAA feel without new character art:
1. **Station layer** (pack sprites): the station itself animates continuously while crafting.
2. **Character layer** (Szadi rig): `sheet_anim.gd` proves the rig has **only idle/walk ×3 dirs** — there are no craft-pose rows to unlock, and no downloadable pack will match Szadi's 32×48 silhouette. Solution: a procedural **craft bob** (tween: 0.4s lean-in loop, ±2px, matches hammer/stir cadence) + the character *holds* facing the station. This is code, not art — mandate-compliant because all visible *art* is pack-sourced.
3. **FX layer** (FXLib, pack sheets): per-profession overlay synced to the craft-progress bar in `crafting_ui.gd`.

### 5.2 Per-profession spec
| Profession | Station anim (source) | FX overlay (FXLib, owned) | Gap to buy/find |
|---|---|---|---|
| Emberforging | **Animated Anvil (3 sheets) + Furnace w/ glowing cores** — `pixel_crawler_free` (owned, unmined for this) | `hit_spark` gold-tinted on each "clang" + `dust` + ember `spark_hit` micro | none — fully covered |
| Threadweaving | Loom/spinning wheel — **not owned** | thread shimmer: `magic_arrow` strip re-tinted, tiny scale, arc path | **P1 buy/find**: animated loom or spinning wheel (LPC spinning wheel CC-BY on OGA; itch "cozy crafting stations") |
| Alchemy | Cauldron bubble — check `ninja_adventure` (owned, has animated objects) + `dead_swamp` bubbles (owned, shipped) | `smoke_puff` colored per potion rarity + `acid_hit` micro-splash | soft gap: dedicated alembic/cauldron set |
| Ledger-scribing | Writing desk + candle — `rf_catacombs` candles (owned) | quill-scratch: 2-frame glint (`spark_hit` frames 0-1, ivory tint) + ink `smoke_puff` micro; rune-flash on completion (`summon_circle` 1 rev, violet — Bloodstone dread) | animated quill sprite (tiny; custom strip from icon frames acceptable) |
| Bonecarving | workbench (`pixel_crawler_free`) | bone chips: `quake_rock` bone-tint at 0.3 scale | none |
| Tanning | rack prop (static ok) + `dust` beats | `smear` leather-tint slow | rack prop exists in farm/village packs (owned) |
| Hearth-cooking | Furnace/campfire (owned, multiple animated fires shipped) | steam `smoke_puff` white + `heal_bloom_base` micro on "delicious" proc | none |
| Gathering | node sparkle: `fga_magic_effects` sparkles | pick/sickle `smear` + `dust` | none |

**Completion moment (all professions):** rarity-colored `heal_bloom_base` bloom over the product + item icon lofts to bag (WYSIWYG: the icon IS the item). Epic+ crafts add `holy_pillar` thin column in profession color — "the anvil remembers."

---

## 6. Acquisition shopping list (free-first, then paid)

Style gate (same law as world packs): 32px-grid readable, muted-capable palette or recolorable, sheet-strip format, license allows edit + commercial + no-redistribution compliance. Every purchase goes to `_downloads/vfx_packs/<author>_<pack>/` + CREDITS_VFX.txt entry.

### P0 — mine what we own (cost: 0, days not dollars)
1. The ~29 unmined owned packs (§1 list). Expected yield: water/rain, 2nd thunder (strike?), earth-2, big impacts (retro_impact ALL), heal-slashes, blood, holy pack 3, frost-knight melee, battle-effects misc. This alone likely closes gaps 4, 6-partial, and doubles the smear ladder.

### P0 — paid, the two anchor authors (est. $10–30 total; they ARE our shipped style)
2. **Pimen full catalogue / bundle** — itch.io/pimen. Search: `pimen spell effects bundle`. Priority sets: Fire 02+03 (burning ground, big explosion), Thunder full (strike), Dark 02, Holy 03, Water, Earth, Cutting+Healing full, Slashes bundle. Rationale: 11 of our 18 shipped families are Pimen — palette cohesion is free.
3. **Frostwindz FULL versions** — itch.io/frostwindz. Search: `frostwindz vfx full`. Priority: **Necromancer FULL** (beams, cast circles, soul vortex — the necro class kit), **Priest FULL** (paladin), **Frost Knight FULL** (mage frost + warrior talents), + any Fire/Rogue sets in catalogue. Our 128px hero sheets (dawnbreak, necro shell, summon) are their free teasers; the fulls are the mandated "AAA cohesive set" for 2–3 whole classes.

### P1 — free fillers (cost: 0)
4. **untiedgames — "Will's Magic Pixel Particle Effects"** (search: `untiedgames magic pixel particle`) — 100+ loopable particle effects, ideal for cast-loops + buff auras (gap 1).
5. **XYEzawr — Free Pixel Effects Packs #1–#20+** (search: `xyezawr free pixel effects`) — fire columns, lightning, ghosts/souls, charge-ups, more arrows (hunter). We already ship #12; same-author cohesion.
6. **BDragon1727 remaining free packs** (search: `bdragon1727 effects`) — ball animations, shining effects; we ship 4 of his packs already.
7. **CodeManu paid "Pixel Effects Pack" full** if the owned `codemanu_pixel_effects` is the free tier (verify) — the protection ward we ship is his; ~$5.

### P2 — crafting stations
8. Animated **loom / spinning wheel**: search `pixel art loom animated`, `spinning wheel sprite sheet`, LPC spinning wheel (OpenGameArt, CC-BY). 
9. **Alchemy station**: search `animated cauldron pixel art`, `alchemy workshop tileset` — Admurin interior packs (style-proven author, our skeletons/rat) are the paid fallback: search `admurin interior`.
10. **Scriptorium**: search `pixel art writing desk animated`, `quill sprite` — tiny need; custom strip from owned icon sheets acceptable if dry.

### P3 — only if P0–P1 leave holes
11. Beam/tether generic: search `pixel beam vfx sprite sheet top down`.
12. Feather/nature: search `pixel feather burst vfx`, `leaf particle sprite sheet` — expect to fall back to the custom raven-frame strip (§3 Hunter).

**Verification protocol per pack (unchanged from world packs):** license text saved, PIL frame-geometry check, style-montage vs `_style_montage.png`, then FXLib registration.

---

## 7. FXLib architecture: rank-scaling + data-driven layers

Design goals: same spell grows with rank (mandate: trainer ranks), **zero** new textures per rank (60-FPS law: `_frames_cache` stays one entry per base id), everything data.

### 7.1 Rank tiers
Ranks (1–12ish over 60 levels) collapse to **4 visual tiers**: T1 ranks 1–3 · T2 4–6 · T3 7–9 · T4 10+ (and T4 = ultimate/crit presentation). Casters pass `{"rank": r}` in opts; nothing else changes at call sites.

```gdscript
# fx_library.gd additions
const _TIER_OF_RANK := [1,1,1, 2,2,2, 3,3,3, 4,4,4]  # clamp tail → 4

# Alias entries gain two optional keys:
"fireball": {
  "id": "fire_explosion",
  "opts": {"tint": Color(0.92,0.55,0.25)},
  "tiers": {                       # node-level deltas, multiplied onto opts
    2: {"scale": 1.15, "speed": 1.05},
    3: {"scale": 1.35, "speed": 1.10, "hot": 0.35},
    4: {"scale": 1.60, "speed": 1.15, "hot": 0.7},
  },
  "layers": {                      # extra pack sheets stacked at tier >= N
    3: [{"id": "ground_scorch_loop", "opts": {"duration": 2.0, "z": -1}}],
    4: [{"id": "ember_rain", "opts": {"scale": 1.2}}],
  },
},
```

### 7.2 Resolution changes
- `_resolve(id, opts)` reads `opts.rank` → tier → merges the tier dict (multiplicative for `scale`/`speed`, `hot` handled by §7.4 shader) under caller opts.
- `play()` after spawning the main sprite, iterates `layers` for all tiers ≤ current and `play()`s each — this **replaces** `_COMPOSITES`: `hammer_blow`/`frost_nova` become data (`layers` + a new optional `"stagger": sec` key per layer for the frost start→active→end chain). One code path, no bespoke functions per spell.
- `attach_loop()` and `projectile_frames()` callers (Combat.Projectile) pass rank too — projectiles grow via node scale + `hot`, flight sheets never re-baked.

### 7.3 Cast-loops (new family slot)
New optional alias key `"cast": {"id": ..., "opts": ...}` — player.gd plays it at cast-start parented to the caster, frees on cast-end/interrupt. Sourced from untiedgames/Frostwindz-full circles (§6). Every spell with a cast bar gets one; instant spells skip it.

### 7.4 Class-palette cohesion shader (the "AAA cohesive palette" enforcer)
`modulate` multiplies and cannot conform a multi-hue pack sheet to a class palette. Add one shared `CanvasItem` shader, `fx_palette.gdshader`: **gradient map** — luminance of the source frame indexes a 3-stop gradient (class Base→Mid→Hot from §3), uniform `hot_boost` adds HDR-2D glow energy (ties into the shipped AAA-2D-lighting mandate: T3/T4 effects push emission > 1.0 so the glow bloom picks them up).
- Alias opt `"palette": "necromancer"` (or explicit 3 colors) applies the shader with a per-class preloaded gradient texture (7 tiny 1×16px gradients, generated once).
- Tier `hot` value drives `hot_boost` — **rank growth reads as heat, not just size**, which is the actual AAA read.
- Fallback stays `tint` for sheets that are already monochrome.

### 7.5 Budget guards
- Shader material shared per class (7 materials total, `_material_cache`).
- `layers` capped at 3 concurrent per cast; volley counts scale by tier via params not sprites-per-frame > 40 rule.
- All tier data lives in `_ALIASES` — `_DEFS`/sheet cache untouched, so memory footprint is identical to today.

### 7.6 Crafting hook
`FXLib.craft_overlay(profession: String, station: Node2D, progress: float)` — thin helper that schedules the §5.2 FX beats (clang every 0.8s, shimmer sweep, etc.) as `play()` calls; `crafting_ui.gd` drives it from the progress tween it already owns.

---

## 8. Execution order
1. **Mine** the 29 unmined owned packs → register ~30 new `_DEFS` (closes gaps 4/6-partial, smear ladder, water/earth). 
2. **Ship FXLib 7.1–7.2** (tiers + layers, migrate 2 composites) — the demo's 56 abilities instantly gain rank presentation for free.
3. **Buy P0 paid** (Pimen bundle, Frostwindz fulls) → build the 3 caster hero-kits (mage/paladin/necromancer) end-to-end as the quality bar.
4. **Palette shader 7.4** + conform all 7 kits; screenshot montage per class for the owner's cohesion sign-off.
5. **Crafting layer** (§5) — forge first (fully owned), then buy loom/alchemy stations.
6. Hunter/druid nature gaps last (P3 + custom strips) once TALENTS_SPELLS.md fixes their final spell lists.
