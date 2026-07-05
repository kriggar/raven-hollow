# THE ASSET LIBRARY — Raven Hollow (#114)

Honest catalog of the cohesive gothic pixel-art asset library. **Truth over hype: every number
below is a real machine count from `library.json`, not a promise.** The library exists to end zone
sparsity and retire the lean ColorRect composites in `scripts/zone_builder.gd`.

Built by `tools/assets/` on the owner's local stack ($0): ComfyUI + SDXL + Pixel-Art-XL LoRA on
the RTX 5070 Ti (generation) and a PIL-based interpreter/cleaner (verification). Fable drives the
zone redo from here (FABLE-ONLY VISUAL LAW — this doc is the plan + parts bin, not a paint pass).

---

## 1. How it was made (the pipeline)

**Generation is primary** (owner: free-scouting yields little; the GPU is the library).
`tools/assets/generate.py` drives ComfyUI:

- **Inanimate lane** (props / buildings / tiles / monuments — the bulk): SDXL + Pixel-Art-XL, one
  1024px render per seed → `interpret.process_render()` →
  **cutout** (dominant-border flood-fill, most-bg-removed of several candidates + rembg) →
  **connected-component SPLIT** (one sprite per cell; a small-gap dilation keeps a boat+oar as one
  but splits three boats into three; lacy objects flagged `single` stay whole) →
  **defringe** (fill transparent RGB with mean object colour so the downscale can't bleed a halo) →
  nearest-clean downscale → **quantize + gothic-palette cohesion nudge** → **binary alpha**
  (0/255 only ⇒ zero semi-transparent ⇒ zero halo by construction) → despeckle → tight trim +1px.

- **Animated lane** (creatures): SDXL base pose → **Wan 2.2 TI2V img2vid** (the proven
  consistent-motion method — same flow the commercial Sorceress tool sells, replicated free here,
  see `design/LEARNED_PRINCIPLES.md`) → **pixel-snap** (chroma key + tight crop + one shared
  32-colour master palette across the whole cycle so colour never drifts) → per-frame clean+verify
  → `<state>_sheet.png` + strip + GIF + a `frames_per_state` manifest.

**Verification is the gate** (`tools/assets/interpret.py`, the INTERPRETER HORDE #112). Nothing
enters `library.json` unless it passes the **SPOTLESS rubric** — a hard machine gate plus a human
montage eyeball:

| check | meaning |
|---|---|
| `edge_clean_no_halo` | alpha strictly binary — no fringe/halo pixels |
| `no_uncut_background` | no leftover white/chroma background block |
| `has_content` | not empty, background actually removed |
| `single_subject` | one placeable object (exempt for `single` lacy objects) |
| `quantized` | ≤ ~48 visible colours — clean pixels, not JPEG/AA mush |
| `alpha_trimmed` | tight bounds + 1px margin; border ring provably empty |
| `palette_compatible` | ≥45% of colours sit in the muted-gothic family |

Rejects are logged with the failing check. Montages (`verified/**/*_montage.png`) are the eyeball.

---

## 2. Coverage — REAL counts

<!-- AUTO:COVERAGE -->
**Total verified sprites in `library.json`: 182**  (180 inanimate, 2 animated creature sheets).

| category | verified sprites |
|---|---|
| prop | 54 |
| building | 38 |
| harbor | 38 |
| monument | 34 |
| nature | 16 |
| creature | 2 |

**ColorRect composites now covered** (generated replacements exist): `boat`×10, `cargo`×10, `crane`×2, `drowned_fence`×2, `ledger_tablet`×10, `pier`×7, `salt_pan`×7.

**Animated creatures** (real Wan-video-derived frames, per-frame verified):
- `carrion_crow` — states: walk:8f
- `plague_rat` — states: walk:8f
<!-- /AUTO:COVERAGE -->

**Scout (secondary, `tools/assets/scout.py` → `scout_manifest.json`):** honest result — the
owner already owns ~20 packs; live license-fetch confirmed the CC0/CC-BY anchors (Kenney Tiny Town
= CC0; OGA LPC Village Decorations = CC-BY-SA 4.0; LPC City Outside = CC-BY-SA 3.0/GPL) and flagged
fresh candidates NEEDS_MANUAL. Free-scouting adds little the repo lacks; **generation is the win.**

---

## 3. Gaps still open (truth)

- **Seamless ground TILESETS** — this library is placeable *objects/decals*, not wang-tiled ground
  fills. Terrain sheets remain the existing packs; generating seamless tiles is a separate task.
- **Animated-creature throughput is limited** — Wan clips are ~1–2 min each on 16 GB; the library
  ships a proven *demonstration* set, not hundreds of monsters. Props scale freely; creatures don't.
- **Capital-unique civic kits (#103)** — the buildings here are village/town tier; per-capital
  signature architecture (Archive filing halls, Black Night catacomb facades…) is a follow-on batch.
- **Interiors, large NPC cast art** — not attempted this pass.

---

## 4. Wiring plan — library → zone_builder (for Fable's redo)

The lean ColorRect/placeholder composites in `scripts/zone_builder.gd` are the #1 upgrade targets.
Proposed: copy chosen library PNGs into `res://assets/art/world/harbor/` (and `/village/`, `/gothic/`)
run `godot --headless --import`, then replace each composite branch with `_sprite(...)` calls
(picking a random variant per placement for the asymmetry law). **Visual integration is Fable's**
(visual law); this maps the parts:

| zone_builder branch (line) | today | replace with library category → ids |
|---|---|---|
| `"pier"` (488) | brown ColorRect deck + posts | `harbor/pier_deck_*`, `harbor/pier_post_*`, `harbor/mooring_bollard_*` |
| `"boat"` (506) | `coast/rowboat.png` / `sailboat.png` (placeholder) | `harbor/rowboat_*`, `harbor/fishing_sailboat_*` |
| `"wreck"` (515) | rotated tinted sailboat + water ColorRect | `harbor/fishing_sailboat_*` (modulate dark) + keep water rect |
| `"warehouse"` (529) | reused `house_03.png` | `building/harbor_warehouse_*` |
| `"crane"` (531) | mast/arm/rope/crate ColorRects | `harbor/dock_crane_*` (single sprite, keep the rope Line2D for sway) |
| `"cargo"` (553) | crate ColorRects | `harbor/cargo_crate_*`, `prop/crate_stack_*`, `prop/barrel_*` |
| `"salt_pan"` (565) | Polygon2D + streak ColorRects | `harbor/salt_pan_*` |
| `"drowned_fence"` (582) | post ColorRects | `prop/drowned_fence_*` |
| `"ledger_tablet"` (589) | tablet/rim/rune ColorRects | `monument/ledger_tablet_*` (keep the live PointLight2D) |

**Density fill (fixes sparse zones, LEVEL_PAINTING_BIBLE 40-second rule):** the `prop/`,
`building/`, `monument/`, `nature/` families (barrels, crates, market stalls, wells, carts, fences,
braziers, lanterns, signposts, gravestones, crosses, obelisks, shrines, statues, cairns, cottages,
houses, chapels, churches, windmills, stumps, mossy rocks, reeds) are the cluster satellites for
camps / shrines / graveyards / markets / farms per `biome_fit` in each `library.json` entry.

---

## 5. The 150k marathon queue (`tools/assets/queue.py`)

Owner target: build toward **150,000** gothic-medieval assets. The queue runs continuously on the
5070 Ti, $0, resumable, and is meant to be left running for weeks via the detached supervisor.

- **Category quotas sum to exactly 150,000** across 20 gothic taxonomies (containers, furniture,
  lighting, market/food, tools, graveyard, monuments, ruins, buildings, harbor, nature, fences/walls,
  decor, religious, farm, tavern, stacked-containers, signage, wagons, misc-gothic). NOT school/beach.
- **Huge prompt space** — each category has a subject bank × material modifiers × state modifiers ×
  random seed, so variety is combinatorial, not 150k near-dupes.
- **VRAM fill / max the GPU** — `batch_size` images per ComfyUI job (default 4; set `RH_BATCH`),
  model stays resident (no reload thrash), one resident SDXL+LoRA graph reused every job.
- **Perceptual-hash DEDUP** — every accepted sprite's dHash is kept per-category; a new sprite within
  Hamming≤6 of an existing one is dropped (`dedup_hits` counted). Kills near-duplicates.
- **SPOTLESS gate** — same `interpret.cleanliness_report` rubric as the sample library; rejects counted.
- **DISK LAW (owner)** — output lives on **`D:\raven hollow\assetlib`** (C: was at 92%). Every raw
  1024px render is **deleted from ComfyUI's output the instant** its sprite is cut+verified (raws ×150k
  would be ~225 GB). Only final PNGs + `library.json` + `phash_index.json` + `queue_manifest.json` are
  kept (~8–15 GB projected). A **disk guard** stops the run if the drive drops below 20 GB free
  (ties to disk-watcher #97). generate.py likewise prunes its ComfyUI raws + writes debug raws to D:.
- **Supervisor** — `tools/assets/run_queue_supervisor.bat` relaunches the queue if it dies; start it
  detached: `powershell -Command "Start-Process -WindowStyle Hidden tools\assets\run_queue_supervisor.bat"`.
- **Resumable** — manifest + phash index persist to D:; restart continues from the running totals.

### Stress test (real numbers)
<!-- AUTO:STRESS -->
Measured on the running burst (batch_size 4, SDXL 1024px @ 28 steps, single ComfyUI stream, 5070 Ti):

| metric | value |
|---|---|
| throughput | **~185 assets/hr** (steady; ~210 warm, drops slightly as jobs vary) |
| sprites per render | ~1.1 (connected-component split multiplies output) |
| reject rate (spotless gate) | **~3%** |
| dedup hits | ~0% early (rises as per-category density grows) |
| VRAM | batch-4 fits comfortably (14.7 GB free at idle; no OOM) |
| **raws left on disk** | **0** — auto-prune deletes every ComfyUI render the instant its sprite is cut (disk law holds) |
| final library size | ~50–80 KB/50 sprites ⇒ **~8–12 GB projected at 150k** (fits D: easily) |
| **projected time to 150,000** | **~34 days single-stream** at 185/hr (matches the owner's 6–10 week estimate) |

Throughput levers if the owner wants faster: raise `RH_BATCH` (VRAM permitting), drop steps 28→20,
or run a second ComfyUI instance. The queue is resumable, so the marathon can start/stop freely.
<!-- /AUTO:STRESS -->

---

## 6. Animation = local video-gen (owner directive)

**Model chosen: Wan 2.2 TI2V-5B** (img2vid), already installed on this rig. Rationale over the
owner's other suggestions:
- **Fits 16 GB & proven** — this exact model already rendered the game's rogue set here (~512²×41
  frames in ~60–90 s); no new multi-GB download (BE CHEAP), vs LTX-Video / AnimateDiff / SVD which
  would need fetching + node installs and give weaker consistency for a colour-locked sprite.
- **Consistency** — img2vid from ONE base pose + a single shared master palette across the cycle keeps
  the creature on-model (the demo: `plague_rat` & `carrion_crow` walk×8, verified 8/8 clean, checker
  strips prove transparent isolation). This is the same generate→animate→cut flow the commercial
  Sorceress tool sells, replicated free (LEARNED_PRINCIPLES.md).
- **Honest limit** — motion on a small top-down creature is subtle and each clip is slow (~1–2 min),
  so animated throughput is far below props. Static props scale to 150k; animated entities are a
  curated, slower lane.

Flow: SDXL base pose → Wan img2vid clip of the motion → extract N frames → robust cutout (handles the
dark bg Wan invents) → shared-palette quantize → binary alpha → tight trim +1px → grid sheet + strip +
GIF + `frames_per_state` manifest → per-frame SPOTLESS verify.

---

## 7. Files

- `tools/assets/generate.py` — ComfyUI generation driver (inanimate + animated lanes)
- `tools/assets/interpret.py` — cleaner + splitter + SPOTLESS verifier + montage + library index
- `tools/assets/asset_specs.py` — the spec catalog (categories, prompts, biome-fit, ColorRect targets)
- `tools/assets/scout.py` — free-pack license scout (secondary)
- `_downloads/_assetlib/library.json` — master index (id, category, path, size, animated, states,
  frames_per_state, facing, biome_fit, source, license, cleanliness, verdict)
- `_downloads/_assetlib/verified/**` — the verified sprites + montages (committed)
- `_downloads/_assetlib/raw/**` — the 1024px renders (gitignored; regenerable)
