# THE ANIMATION PIPELINE — Raven Hollow (sorceress-derived finishing chain)

Sibling to `ASSET_CATALOG_PROMPT.md` / `ASSET_LIBRARY.md` / `ASSET_GAUNTLET.md`. This doc is the
**plan + parts bin** for animated assets (creatures, VFX, idle/props-in-motion). It is NOT a visual
paint pass — the world's look is Fable-personal (FABLE-ONLY VISUAL LAW). Everything here runs on the
owner's local stack ($0): ComfyUI + SDXL + Pixel-Art-XL (base pose / stills) and Wan2.2-TI2V-5B on
the RTX 5070 Ti (motion), finished by a PIL chain, gated by the vision Gauntlet, exported to Godot 4.

## The lane (how a raw clip becomes an in-engine animation)

```
SDXL+PixelArtXL base pose  ->  Wan2.2 TI2V img2vid clip  ->  extract N keyframes
   ->  anim_finish.py  (palette lock / downscale / hard-edge / anchor align / de-sparkle)
   ->  interpret.py razor cut  OR  gridcut.py uniform grid  (one sprite per cell, zero bleed)
   ->  gauntlet.py  (unanimous vision inspectors)         [FAIL -> retry route, part E]
   ->  godot_export.py  (packed sheet + JSON manifest + validated SpriteFrames .tres)
```

Tools: `tools/assets/anim_finish.py`, `generate.py` (video lane + retry routes), `interpret.py`
(adaptive chroma-key + finish call-through), `gridcut.py`, `gauntlet.py`, `godot_export.py`.

---

## The 9 adopted design rules (sorceress.games-derived, owner MAX-EFFORT law)

1. **Shared-palette temporal lock.** Build ONE median-cut palette (default 24 colours) from all
   frames (or a designated key frame) and quantize EVERY frame against it. Wan otherwise quantizes
   each frame to a slightly different palette, which reads as colour flicker. Dithering OFF by
   default (pixel art wants flat runs). — `anim_finish.build_shared_palette` / `snap_to_palette`.

2. **Silhouette-preserving downscale.** Crop all frames to a shared union bbox (keeps registration),
   defringe, then AREA-AVERAGE (BOX) downscale to the target cell by ONE global scale — never a
   bilinear-only shrink (which smears the silhouette). Palette re-snap follows the downscale.
   — `anim_finish.area_downscale_all`.

3. **Hard-edge matte (no half-tones).** After the downscale the alpha is binarised (0 or 255): every
   edge pixel is fully in or fully out. Zero anti-alias halo by construction. — `anim_finish.hard_edge`.

4. **Anchor alignment (anti-wobble).** Compute the opaque-pixel CENTROID (props/VFX) or the
   bottom-center FEET anchor (characters) of reference frame 0, then integer-pixel-shift every other
   frame so its anchor coincides. Kills the 1-3 px per-frame swim. Max drift corrected is logged.
   — `anim_finish.anchor_align` (`--anchor centroid|feet`).

5. **Temporal outlier smoothing.** A pixel that differs from BOTH temporal neighbours while those two
   AGREE is a single-frame sparkle and is replaced with the agreed value. Conservative: only fires on
   strict neighbour agreement; endpoints untouched; comparison ignores RGB behind the alpha matte.
   — `anim_finish.temporal_smooth`.

6. **Wan envelope discipline.** Wan2.2-TI2V-5B latent length must be **4k+1** (snapped + warned),
   **24 fps**, **720p** base; the **seed is always logged and settable** so a clip is reproducible /
   retry-routable. — `generate.snap_wan_length`, `WAN_FPS`, `WAN_DEFAULT_RES`, `wan_workflow`.

7. **Frame-budget presets.** Motion intent picks the extraction frame count + prompt hint:
   `idle`(4) / `walk4`(4) / `walk8`(8) / `attack`(6) / `vfx`(free). — `generate.PRESETS`, `--preset`.

8. **Adaptive chroma-key + despill.** Before background removal, detect a uniform green/magenta key
   from the border; key it SPATIALLY (border flood-fill can't punch holes in same-hued interior
   detail) and RGB-despill the survivors. If the sprite palette COLLIDES with the key hue, log it and
   advise rendering on the OTHER key (keying stays spatial so it never eats the collision). Existing
   de-halo / shadow-strip stay. — `interpret.detect_key_color` / `adaptive_chroma_key` / `cutout`.

9. **Retry routes (never fail the batch).** On a Gauntlet FAIL of an animation item: attempts 1-2
   re-roll the SEED (settings held); attempt 3 switches the SETTINGS route (steps 36 / cfg 6.0 /
   denoise 0.9). Up to 3 attempts, full route history logged; an item that exhausts its routes is
   DROPPED, the batch continues. — `generate.plan_routes` / `run_with_retry` (used per state-clip in
   `gen_creature`).

**Delivery contract (Godot 4).** A finished frame set becomes: (1) a packed uniform-cell sheet PNG,
(2) a JSON manifest `{name, cell_w, cell_h, cols, rows, fps, loop, anims:[{name, row|frames}]}`, and
(3) a Godot 4 `SpriteFrames` `.tres` (one `AtlasTexture` per frame region, correct `Rect2`s, per-anim
`speed`=fps + `loop`). The `.tres` is proven engine-valid: copied into a minimal throwaway Godot
project under `medieval_rpg`, the sheet `--headless --import`ed, then a SceneTree script loads the
resource and touches every frame texture — zero errors + `VALIDATE_OK` required. — `godot_export.py`.

---

## The DIRECTION rule (which lane makes which sprite)

- **Video (Wan) lane** produces **4-directional** sprites, **VFX**, and **idle / in-place** motion.
  Wan holds character consistency well over a short clip and 4 facings are cheap to mirror
  (right -> left) + regenerate (front/back). This is the default animated lane.
- **3D-to-2D lane** produces **8- and 16-directional** sprites (the Diablo-2 method: Hunyuan3D
  image->3D, Blender rig / animate / N-direction render, then Pixel-Art-XL refine — see agent memory
  `project_local_image_gen`). Wan cannot hold a rig consistent across 8-16 exact facings, so
  high-direction-count sprites go through geometry, not video.

Both lanes converge on the SAME finishing chain (rules 1-9) and the SAME Godot export contract, so a
sprite reads as one library no matter which lane made it.

---

## CLI quick reference

```
# Finish a clip (frames dir or gif) -> finished frames + sheet + filmstrip
python tools/assets/anim_finish.py <frames_dir|gif> --cell 64 --colors 24 --anchor feet \
    --out DIR --name NAME --filmstrip

# Export finished frames -> Godot 4 sheet + manifest + validated .tres
python tools/assets/godot_export.py --frames DIR/frames --name NAME --cell 64 --fps 24 --loop \
    --anim-name walk --out DIR

# Generate an animated creature through the video lane with a preset (retry-routed, gauntleted)
python tools/assets/generate.py --batch animated --preset walk8 --seed 700
```

Run everything with the ComfyUI venv python
(`C:/Users/vstef/ComfyUI/venv/Scripts/python.exe`); Godot validation additionally needs
`C:\Users\vstef\tools\godot\Godot_v4.6.3-stable_win64_console.exe` (override via `RH_GODOT`).
