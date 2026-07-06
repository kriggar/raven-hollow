# VFX_PIPELINE.md — Pixel-VFX Generation Standard & Plan (Raven Hollow)

**Status: 📐 DRAFT — owner-approved before build.** Author: driver (Opus 4.8) from verified adversarial research. Nothing here is committed to `design/` or built until owner sign-off. Sections flagged **[FABLE/OWNER]** need visual sign-off per FABLE-ONLY VISUAL LAW; **[DRIVER]** are buildable by the studio without a visual call.

**Honest one-line verdict (the plan in a sentence):** *No local generator makes crisp pixel VFX push-button; crispness is enforced by our post chain, not the model. Hand-pixel + free CC0 pro-packs + in-engine particles still beat every AI method for HERO spell bursts today — so the standard is: procedural in-shader core + hand-pixeled burst keyframes for hero, AI+heavy-post for bulk/generic VFX, with a reference-calibrated gate as the acceptance law and a flywheel to close the gap over time at $0.*

Two mandate overrides on the research, stated up front:
- **ZERO-PURCHASE LAW governs.** The research's "$9.97 Pixel FX Designer / $22 SpriteMancer is basically free" is **void here** — nothing is bought, ever. The literal-bar tool is replaced by **free equivalents**: Godot `GPUParticles2D` + a palette-quantize shader (procedural), the **msfrantz free `.aseprite` sources**, **Foozle CC0**, **CodeManu free 22-effect pack**, and free editors (Krita/GIMP/LibreSprite) for the hand-pixel burst frames.
- **SPELL-VFX UNIQUENESS LAW governs.** Palette-swapped spell VFX are illegal; every spell/creature VFX must be unique. Therefore **AI-bulk and the flywheel are routed to NON-spell generic VFX only** (dust, sparks, embers, generic impacts). Every hero SPELL gets unique authored source.

---

## 1. THE BAR (measurable)

Every VFX cell/animation is judged against these numbers. **Calibrate the exact band values off the reference pack itself (Foozle CC0 + msfrantz `.aseprite` + CodeManu free) BEFORE trusting any absolute — the SPEC numbers below are the honest starting guesses, not gospel.** Ranges tagged **[SPEC]** are calibration targets; ranges tagged **[LAW]** are structural guarantees our post chain already enforces.

| Axis | Bar | Basis |
|---|---|---|
| **Canvas / cell** | 32×32 small projectile/impact · **64×64 standard spell** · 96–128 hero AoE | matches msfrantz 64×64 + our `--cell 64` default |
| **Palette size** | **≤24 colours per VFX total**, organised as ≤2 named ramps: a **hot emissive ramp (5–8 steps)** + a **smoke/ash ramp (4–6 steps)**. Hard ceiling 110 (gauntlet reject line). [SPEC≤24 / LAW≤110] | msfrantz ramp discipline; `finish_fireball` COLORS=24; `lens_pixel_art` n_colours≤110 |
| **Ramp integrity (off-ramp ratio)** | ≤3% of opaque pixels have nearest-palette **ΔE2000 > 10** (i.e. essentially every pixel sits ON a ramp step). [SPEC] | ΔE2000 nearest-color, standard metric |
| **Outline** | Emissive cores may be outline-less; any solid body carries a **1px hard outline**. **Zero anti-alias halo.** [LAW] | `hard_edge()` binarises α to {0,255} by construction |
| **Partial-alpha ratio** | `frac(0<α<255)` **≈ 0** (target < 0.5%). This is the single best AI-mush discriminator. [LAW] | hard-edge pass; verified as the cheapest, most rigorous mush test |
| **Silhouette contrast** | Reads at 100% zoom on the gothic dark bg: **exactly one dominant connected component** per phase; **orphan speckle count = 0** (no stray <4px islands); hot-core value clearly above background. [SPEC] | connected-components silhouette |
| **Frames per phase** | **Anticipation 3–4 · Travel/loop 4–6 · Impact/burst 6–8 · Dissipate 3–4.** Total **10–12 frames** (fits AnimateDiff's 16-frame coherence window). [SPEC, from msfrantz] | msfrantz: Creation14/Antecip3/ShotLoop4/Explode7/Idle4; AnimateDiff issue #321 (>16f blurry) |
| **Timing** | Author/decimate to **~11–14 fps** source cadence (AI output MUST be frame-decimated to kill "uncanny smooth"); `.tres` playback 12–24 fps. [LAW for AI paths] | Birdman creator: Wan too smooth, drop to ~11–14fps |
| **Temporal stability** | Sub-pixel drift **≤1px** frame-to-frame; **no inter-frame palette flicker** (single shared palette); **no single-frame sparkle**; frame-to-frame **palette Jaccard ≥0.85**. [LAW + SPEC] | `anchor_align` max_drift; shared-palette lock; `temporal_smooth`; phase cross-correlation |
| **Emissive colourfulness (VFX exemption)** | Emissive VFX must be **vivid**: Hasler–Süsstrunk colourfulness **≥45** in the hot core (the gothic desaturation ceiling is INVERTED for fire/energy) AND retain a **desaturated smoke/ash periphery**. [SPEC, polarity-flipped] | Hasler–Süsstrunk (verified real metric; anchors 0/15/33/45/59/82/109); fire *should* be vivid — the one-sided ceiling was a bug |

**The reference ceiling (the literal bar object):** the **msfrantz free 64×64 fireball** with editable `.aseprite` sources (Creation/Anticipation/ShotLoop/Explode/Idle) IS the bar. It is hand-authored, free, and already passes. Any generated VFX that does not read as well as msfrantz at 100% zoom does not ship.

---

## 2. THE ROUTING (which method for which VFX)

Ranked by **proven quality-per-effort on OUR rig** (RTX-class 16GB VRAM, ComfyUI, Godot). Honest verdicts from the verification carry through.

### 2a. HERO spell VFX — unique per SPELL-VFX law. **[FABLE/OWNER sign-off]**
> **The honest ruling: AI cannot hit the Foozle/msfrantz bar for the impact-burst yet. Do NOT route hero bursts to AI.** The *look* (hard outline, ~10-colour ramp) is achievable in post, but the **topology-birth frames — the burst ring being born, the disocclusion** — still require hand-pixeled keyframes. No verified crisp AI burst example exists in any source checked (the styly Wan pixel adapter card shows **zero example outputs**).

**Route (best → fallback):**
1. **Projectile core = procedural in-shader palettized fire/energy** (Godot `GPUParticles2D` + a palette-quantize fragment shader). Crisp **by construction** — the palette is quantized in-shader, so frames come out hard-edged and near-palette before post touches them; nothing for area-downscale to smear. Strongest $0 path, genuinely different from the AI paths. **HITS-BAR for crispness.**
2. **Burst = 3–4 hand-pixeled keyframes** in a free editor, seeded from the msfrantz `.aseprite` Explode frames or Foozle CC0 as reference (never copied). ~1–2 hrs. **The only route to a truly crisp burst.**
3. Squash/stretch on the core authored via a **mask curve**, not optical flow.

Paid VFX tools are **banned** (ZERO-PURCHASE). AI is allowed only as a *candidate generator that must beat the gate AND the msfrantz control* — currently it does not, so it stays a probe.

### 2b. Generic / BULK VFX — non-unique, high volume (dust, hit sparks, embers, footfall, generic slashes). **[DRIVER + Fable spot-sign-off]**
This is where **AI + heavy post earns its keep** — volume matters and the uniqueness law does not bind.
- **Route:** frame-by-frame **SDXL + PixelArtSpriteDiffusion checkpoint + PixelAttack LoRA** (crisp guaranteed — each frame quantized independently), OR **AnimateDiff v3 pixel loop** for coherent travel loops → **`anim_finish`** → gate. **CLOSE-WITH-POST → passes at bulk quality.**

### 2c. Projectiles — rigid translate + squash/stretch. **[DRIVER]**
- **Primary:** procedural in-shader (as 2a.1).
- **Alt:** **RIFE-anime keyframe interpolation** (4× → downscale → requantize) across **RIGID motion only**. **CLOSE-WITH-POST.** Hard rule below.

### 2d. Impacts / bursts — topology birth. **[FABLE/OWNER for hero; DRIVER for bulk from free packs]**
- **Hero:** hand-pixel (2a.2).
- **Bulk:** adapt **CodeManu free 22-pack / Foozle CC0** impacts through `anim_finish`.
- **HARD LAW — never run RIFE/optical-flow across a projectile→burst boundary.** Optical flow physically cannot invent the burst ring; it guarantees ghost/smear. This is a law, not a tuning problem.

### Method verdict table (carry-through from verification)

| Method | Crispness | Motion | Verdict for us | Use |
|---|---|---|---|---|
| Procedural in-shader fire | ✅ HITS-BAR | rigid + mask squash | **best $0**, proven-by-construction | hero core, projectiles |
| Hand-pixel keyframes | ✅ HITS-BAR | authored | only true crisp burst | hero burst |
| Free CC0 packs (Foozle/CodeManu/msfrantz) | ✅ HITS-BAR | authored | the reference ceiling; free & legal | reference + bulk base |
| Frame-by-frame SDXL+PixelArtXL+post | ✅ HITS-BAR | ❌ none (you supply) | crisp, but must author motion | bulk still frames / per-frame |
| AnimateDiff v3 pixel loop | ⚠ post-only | ✅ loopy travel | CLOSE-WITH-POST | bulk travel loops |
| RIFE / FILM (rigid) | ⚠ post-only | ✅ rigid | CLOSE-WITH-POST | projectile in-betweens |
| RIFE across burst boundary | — | ❌ | **DOESN'T-HIT (law)** | never |
| SparseCtrl keyframe→impact | ❌ softens | ⚠ flashes/drifts | DOESN'T-HIT (issue #476, no fix) | probe only |
| styly Wan2.2 pixel-animate | ❓ **unproven** | smooth (decimate) | **download-and-probe, NOT load-bearing** | bake-off probe |
| ToonCrafter / ToonComposer | ❌ softens | ✅ | anime-line-art, not pixel; VRAM-risky | probe later |

---

## 3. THE GENERATION SOP (one VFX, at bar, repeatable)

Produces one VFX from concept → Godot `.tres`. Uses the real tools in `tools/assets/`.

**Step 0 — Concept & phase plan [DRIVER].** Write the phase budget (anticipation/travel/impact/dissipate frame counts from §1), target cell, and the two ramps (emissive + smoke). One line per VFX in the VFX registry.

**Step 1 — Choose route [DRIVER, per §2].** Hero → procedural core + hand-pixel burst. Bulk → AI. Projectile → procedural or RIFE-rigid.

**Step 2 — Produce source frames.**
- *Procedural:* author the Godot particle/shader, capture frames to a raw dir.
- *AI:* `python tools/assets/generate.py …` (SDXL+PixelArtSpriteDiffusion / AnimateDiff v3) → raw frames in `C:\Users\vstef\ComfyUI\output` with a known prefix.
- *Hand:* paint the 3–4 burst keyframes into the raw dir. **[FABLE/OWNER]**

**Step 3 — Frame-decimate (AI paths only) [LAW].** Drop to ~11–14 fps source; discard the first 1–2 settle frames (the `finish_fireball` pattern already skips `frames[2:]`). Skip for authored/procedural frames.

**Step 4 — Finish (the post chain that enforces the look) [DRIVER].**
```
python tools/assets/anim_finish.py <raw_dir> --cell 64 --colors 24 \
       --anchor centroid --out <OUT>/finished --name <vfx> --filmstrip
```
Applies, in order: **shared-palette temporal lock** (kills flicker) → **silhouette-preserving BOX downscale** (never bilinear) → **hard-edge α binarise** (zero halo, drives partial-alpha≈0) → **anchor-align** (drift ≤1px) → **temporal sparkle removal**. Emits a before/after filmstrip for eyeball review.

**Step 5 — Quality gate (§4) [DRIVER].** Run the VFX Gauntlet on `finished/`. Reject-and-loop on any fail with the killing lens logged. Score must beat the msfrantz reference control.

**Step 6 — Godot export [DRIVER].**
```
python tools/assets/godot_export.py --frames <OUT>/finished/frames \
       --name <vfx> --out <OUT>/godot --fps 12 --loop --anim-name cast
```
Produces the packed sheet + JSON + validated `SpriteFrames .tres`.

**Step 7 — Visual sign-off [FABLE/OWNER].** Fable integrates the `.tres` into the spell/scene and gives the final visual call. Driver never integrates visuals (FABLE-ONLY VISUAL LAW) — it only stages the gated candidate + filmstrip.

The `finish_fireball.py` orchestrator already chains Steps 3→4→6 + preview GIF/strip; generalise it to `finish_vfx.py <prefix> <cell> <colors>` as the one-command runner.

---

## 4. THE QUALITY GATE (automated grader — extends the Vision Gauntlet)

Add a **VFX mode** to `tools/assets/gauntlet.py` (`run_gauntlet(im, mode="vfx", subject=…)`). It reuses the existing council but swaps the ambience lens and adds temporal lenses. **Every band is calibrated off the Foozle/msfrantz pack FIRST** (see First Build Step 1); numbers below are SPEC starting points.

**Reused lenses (per-frame):**
- `lens_pixel_art` — flat-run ratio ≥0.42 (calibrate up toward Foozle, likely ~0.55 for VFX), n_colours ≤110. Already the lens that caught the mush/off-palette rejects.
- `lens_style_anchor` — candidate palette vs owner reference sheets (≥0.5 near reference). Point it at the VFX reference pack.

**Swapped lens — VFX emissive exemption (the key fix):**
- **Replace `lens_ambience`'s desaturation ceiling.** The gothic `mean_sat ≤118` ceiling would *wrongly reject vivid fire*. VFX rule instead: **require a vivid hot core** (Hasler–Süsstrunk colourfulness ≥45 in the brightest connected region) **AND a desaturated smoke/ash periphery** (outer band mean-sat within gothic range). Polarity-flipped, two-sided — sound per verification.

**New temporal / mush lenses (across the frame set):**
- **partial-alpha ratio** `frac(0<α<255)` < 0.5% — the cheapest, most rigorous AI-mush discriminator. [LAW-backed by hard-edge]
- **off-ramp ratio** — ≤3% pixels with ΔE2000>10 to nearest palette step.
- **sub-pixel drift** — phase cross-correlation ≤1px between consecutive frames.
- **palette Jaccard** — shared-palette overlap ≥0.85 frame-to-frame (temporal colour stability).
- **connected-components silhouette** — exactly one dominant blob per frame, orphan-speckle count 0.
- **sparkle count** — post-`temporal_smooth` residual single-frame outliers = 0.

**Scoring:** unanimous heuristic pass = gate pass (any explicit False blocks; an abstain never blocks — the honest-degrade design stays). Composite 0–100 with `pass ≥80` is a **[SPEC]** convenience score; the **binary heuristic unanimity is the real gate**. VLM lenses stay **advisory** until calibrated, then `lens_vlm_identity(subject="a fireball impact burst")` becomes gating — the softest signal, never the sole gate.

**Reference control:** the gate ALSO scores the msfrantz reference every run; a candidate must **score ≥ the msfrantz control** to promote. This neutralises absolute-threshold drift.

---

## 5. THE FLYWHEEL (verified viable — with an honest boundary)

**Viable? Yes, for BULK VFX only — bounded, not magic.** SD1.5/SDXL style-LoRA on 16GB is trivially real (huge headroom, ~15–45 min/round — not a time-sink). It climbs bulk/generic-VFX quality over time at $0. It does **not** promise to reach hero-burst crisp — that stays hand-authored.

**Loop:**
1. Train a style-LoRA on **shipped-and-gate-accepted** VFX frames (**Route A: generate the whole spritesheet in one image, then slice** — a legitimately better crispness path than per-frame).
2. Generate → `anim_finish` → **VFX Gauntlet** → accept only gate-passers ≥ msfrantz control.
3. **Never-regress ratchet** (per ACADEMY LAW): a round's model only replaces the incumbent if aggregate gate score does not drop.
4. Retrain on the accumulated accepted set. Repeat nightly.

**Honest guardrails (the research's own caveat — do NOT overclaim collapse-immunity):**
- The cited self-correcting-loops paper used an **idealised physics corrector on human-motion data, NOT a VLM aesthetic judge on pixel art.** The leap "our VLM Gauntlet is that verifier" is **plausible but unproven.** So:
- **Keep a permanent CC0/real anchor** (Foozle + msfrantz) in every training set — never train on 100% synthetic.
- **Accumulate, don't replace** the dataset.
- **Track palette/shape diversity as a collapse tripwire** — halt-and-review if diversity falls.
- Gate on **heuristics**; keep VLM **advisory**. Treat "the verifier makes it provably fine" as encouraging, not settled.
- **Never route hero SPELL VFX through the flywheel** (SPELL-VFX UNIQUENESS + it can't reach the burst bar).

---

## 6. FIRST BUILD STEPS (ordered)

1. **Calibrate the bar off the reference pack.** **[DRIVER]** — download + **license-verify via the Asset Gauntlet** the Foozle CC0, CodeManu free 22-pack, and msfrantz free `.aseprite` fireball (confirm each permits commercial use/redistribution — **flag any non-CC0 license to owner**). Run all reference frames through the §4 metrics to **set every SPEC band** (flat-run, off-ramp, colourfulness floor, drift, Jaccard). *Do this before trusting any absolute number.*
2. **Build the VFX gate.** **[DRIVER]** — add `mode="vfx"` to `gauntlet.py`: emissive exemption + the temporal lenses + msfrantz reference control. Unit-test that it PASSES msfrantz and REJECTS a known Wan-mush clip.
3. **THE BAKE-OFF — same fireball, three methods, scored by the gate.** **[DRIVER]** Produce ONE fireball via each route, run identical `anim_finish` + gate, and record scores + filmstrips:
   - **(A) AnimateDiff-v3 pixel loop** (travel-loop path)
   - **(B) SparseCtrl keyframe → impact** (projectile→burst path — expected to fail the burst per issue #476; confirm empirically)
   - **(C) Godot particles-bake procedural** (in-shader core)
   - **Control:** the **msfrantz free fireball** as the reference ceiling.
   The **empirical winner sets the routing** — do not pre-decide. (Prediction from verification: C beats A beats B, and none beats the msfrantz control on the burst.)
4. **Probe the styly Wan2.2 pixel-animate adapter.** **[DRIVER]** — load the rank256 LoRA on the A14B GGUF (Q4/Q5 + sequential expert load + lightx2v 4-step; A14B fp16 ≈28GB will NOT fit 16GB — GGUF only). Pass frames through the gate. **Promote only if it beats the bake-off winner AND the msfrantz control.** Its own model card shows no crisp frame — treat "1–3 min/clip" as speculation. Probe, not plan.
5. **Hand-pixel the flagship spell's 3–4 burst keyframes.** **[FABLE/OWNER]** — the only route to a true crisp hero burst; owner visual authoring + sign-off.
6. **Stand up the flywheel** on accepted BULK VFX with ratchet + permanent CC0 anchor + diversity tripwire. **[DRIVER build; each model promotion = Fable sign-off]**.

**Sign-off split:** Steps 1–4 and 6-infrastructure are **[DRIVER]** buildable now. Step 5 and every *visual acceptance/integration* (which VFX ships, hero burst authoring) are **[FABLE/OWNER]** per FABLE-ONLY VISUAL LAW.

---

### Files referenced (all absolute)
- Gate: `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\gauntlet.py` (owner law #115 Vision Gauntlet — extend with VFX mode)
- Post chain: `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\anim_finish.py`
- Generator: `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\generate.py`
- Godot export: `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\godot_export.py`
- Orchestrator to generalise → `finish_vfx.py`: `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\finish_fireball.py`
- Model fleet (confirms models landing): `C:\Users\vstef\Desktop\rpg\medieval_rpg\tools\assets\download_fleet.py` — Wan2.2-I2V-A14B GGUF Q4_K_M, LTXV-2b-0.9.8-distilled, AnimateDiff v3 (mm+adapter+sparsectrl_rgb), PixelArtSpriteDiffusion, PixelAttack LoRA, styly Wan2-2-pixel-animate rank256. **(RIFE VFI node/model to be added for §2c rigid interpolation.)**
- Mandate ledger: `C:\Users\vstef\Desktop\rpg\medieval_rpg\design\MANDATES.md`

**This draft is ready to be placed at `design/VFX_PIPELINE.md` pending owner sign-off. Not written to disk (owner-governed `design/`, approval-gated).**