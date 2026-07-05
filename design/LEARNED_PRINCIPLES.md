# LEARNED PRINCIPLES — distilled observations (review-gated into the bibles)

Per THE ACADEMY LAW (MANDATES): STUDY references, distill into this file, review-gate the
keepers into the Painting Bible / pipeline. Assets are NEVER copied — only technique is learned.

---

## Asset generation flow (studied 2026-07-05 — owner refs: @1dudedevteam / sorceress.games)

**What they are.** `@1dudedevteam` (channel "DevDude") markets **Sorceress** (sorceress.games) —
a proprietary, closed-source AI game-asset SaaS. Core product "Auto-Sprite v2". Pricing: $49
one-time / 100 free trial credits. **License: proprietary, no open-source components.** Under the
ZERO-PURCHASE LAW it is NOT bought and there is nothing free to install (it is hosted SaaS).

**Their pipeline (Auto-Sprite v2), extracted:**
1. **Generate** a base character with any AI image model (they offer Flux/GPT-Image/NanoBanana…).
2. **Animate** it with an AI *video* model (Wan / Kling / Seedance …) — motion as a video clip.
3. **Convert** clip → spritesheet: extract every frame at a target fps → **AI background removal
   (no green-screen needed)** → **edge cleanup** → **tight crop** → **padding normalization** →
   **grid alignment** → spritesheet PNG + **JSON frame manifest**.
4. **Consistency anchor**: a single *Reference Image* locks silhouette + palette across all
   generations. Their "True Pixel" step = chroma-key + edge cleanup + palette optimize + downscale.

**Honest verdict — already ours, free.** This is the *same* method this project reverse-engineered
months ago (see agent memory `project_local_image_gen`: FLUX/SDXL base → **Wan2.2 TI2V img2vid** →
**pixelsnap** = chroma/rembg key + tight crop + shared master-palette quantize + grid + manifest).
Our `tools/assets/generate.py` **animated lane already implements this exact flow** locally on the
5070 Ti. Nothing to buy; nothing superior to adopt wholesale. Confirmation, not revelation.

**Adopted refinements (the genuinely useful bits):**
- **Reference-image / shared-palette anchor** → keep ONE base per creature and a single 32-colour
  master palette across the whole cycle so colour never drifts. (Already in `pixelsnap_frames`.)
- **AI bg-removal without green screen** → `rembg` fallback in `interpret.cutout` so real/edge
  cases key even when the flat-chroma prompt is ignored. (Added this session.)
- **Padding normalization + grid alignment + JSON manifest** → each animated state now writes a
  `<state>_sheet.png` + a geometry manifest (frames, frame_size, feet-line) via
  `interpret.geometry_manifest`. (In pipeline.)

**Where our need differs from theirs.** Sorceress is *character*-centric (one hero → walk/attack).
Our biggest gap is **inanimate density** (props/buildings/tiles to fix sparse zones + replace the
ColorRect composites). That is a *single-image* problem, not video. For it we use the stronger
lane we built: SDXL + Pixel-Art-XL → **connected-component split (one sprite per cell)** →
**defringe** (fill transparent RGB with mean object colour so downscale can't bleed a halo) →
quantize + gothic cohesion nudge → **binary alpha** (zero semi-transparent = zero halo by
construction) → despeckle → tight trim. Sorceress has no equivalent; this is our own.

---

## The SPOTLESS cutting bar (owner, 2026-07-05 — hard gate before library.json)

A generated sprite enters `library.json` ONLY if ALL pass (machine) + a human/vision montage eyeball:
1. **Transparent background** — alpha is strictly binary {0,255}; zero semi-transparent px (no halo).
2. **One sprite per cell** — multi-object renders are split by alpha-connected-components; a small
   `merge_gap` dilation keeps genuinely-attached parts together (boat+resting-oar = 1) while
   separated objects split (3 boats = 3 sprites). Lacy single objects (nets/reeds/fences) are
   flagged `single` and kept whole (their low connected-component fraction is legitimate).
3. **Alpha-trimmed** — tight bounds + 1px margin; the border ring is provably empty.
4. **Quantized, not mushy** — ≤ ~48 visible colours; no JPEG/anti-alias soup.
5. **Palette-compatible** — ≥45% of colours sit within tolerance of the gothic master palette.
6. Rejections are logged with the failing check name. No sprite passes on vibes; the montage IS the gate.
