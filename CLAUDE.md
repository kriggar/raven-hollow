# RAVEN HOLLOW — DRIVER PROTOCOL (auto-loads for every Claude session here)

You are the DRIVER of a working game studio, not its brain. The intelligence
lives in the pipelines, validators, and committed design bibles. Follow the
protocol and the output stays at the established bar no matter which model
drives. Deviate from it and quality collapses. The owner is at strict credit
limits: production happens on LOCAL tools ($0); you spend tokens on judgment,
integration, and verification only.

## Read order (every session, before any work)
1. `design/MANDATES.md` — the owner's laws (Witchbrook bar, verified-free
   assets, palette-swap ban, anti-hallucination triple store, BE CHEAP).
2. `design/BACKLOG.md` — THE 108-task registry. It is canon. Update it after
   every completed step; announce completions as "TASK #N DONE".
3. `design/TASK_DIVISION.md` — what the driver may implement solo vs what is
   Fable/owner-only (engine architecture, canon retcons, mandate changes:
   NOT yours to decide — flag and stop).
4. Canon: `../_lore_extract.txt` (grep it before inventing anything).

## The driver loop
pick task from BACKLOG → produce with LOCAL tools → run the validators →
integrate by the established patterns → verify with screenshots → commit +
push (authorized) → update BACKLOG + memory → report with evidence.

## The local studio (all $0 — use these INSTEAD of writing content yourself)
- TEXT: `python tools/studio/studio.py <role> "<task>"` — roles: quest_writer,
  bark_writer, def_author, item_smith, qa_triage. Needs Ollama serving
  qwen2.5-coder:14b. Output is validator-checked JSON; you review + integrate.
- ART: ComfyUI + SDXL + Pixel Art XL LoRA (already installed, MCP `comfyui`).
- VOICE: Maya1 TTS at `C:\Users\vstef\tts` — bake via `maya1_bake_v2.py`
  pattern; filenames = fnv1a(speaker|ORIGINAL text); ALWAYS chunked OGG writes.
- QA: `python tools/validate_travel.py` (seams; run after ANY zone_defs edit),
  `C:/Users/vstef/tts/venv/Scripts/python.exe tools/audio_qa.py` (all audio),
  40-second-rule warnings print during any zone boot, sweep scripts
  `tools/sweep_north.sh` (grid screenshots for inspection).

## Verification (the Prime Mandate — non-negotiable)
- Godot exe: `C:\Users\vstef\tools\godot\Godot_v4.6.3-stable_win64_console.exe`
- Boot a zone + screenshot:
  `RH_CLASS=warrior RH_MAP=<id> RH_TIME=12 RH_ZOOM=0.5 RH_NOHUD=1
   RH_FOCUS="x,y" RH_SHOT="_screens/<name>.png" timeout 200 "$GODOT"
   res://scenes/main.tscn` — then READ the image yourself. Never claim a
  visual result you have not looked at.
- Other hooks: RH_WEATHER, RH_RES=WxH (4K), RH_CAST, RH_UI, RH_SMOKE.
- After adding/overwriting ANY png: run `"$GODOT" --headless --import` or the
  game will not see it (and re-run it if you rewrite the file — cache goes
  stale). Headless CANNOT screenshot; screenshots need windowed runs.

## Integration patterns (copy these, don't invent)
- Zones are data: `scripts/zone_defs.gd` (hand-authored defs) built by
  `scripts/zone_builder.gd` (generic). Mirror an existing capital def
  (blestem/sangeroasa/greyhollow) for density conventions. New landmark
  types go in the builder's match; keep composites lean (sprites + lights
  + ColorRects + tweens).
- Edit scripts via SMALL PYTHON PATCH FILES with
  `assert s.count(old) == 1` anchors (the Edit tool races Godot re-imports).
  Write the patch to the scratchpad, run it, never edit blind.
- Batch generation: JSON specs → generator script → injected defs (see the
  Batch-G pattern in git history, commit 9ca8046).

## Potholes already mapped (hitting these again is negligence)
- libsndfile crashes SILENTLY (exit 127) on OGG writes > 10 s — stream via
  sf.SoundFile in 1 s chunks. Vorbis encode overshoots peaks ~0.5 dB — cap
  at 0.90 before encode.
- bash: `local a=1 b=$a` leaves b EMPTY (expansion precedes assignment) —
  separate lines. Long background bash dies — detach via PowerShell
  Start-Process + supervisor .bat.
- cp1252 console cannot print unicode arrows — write utf-8 files, don't print.
- `plant_00-02.png` are FULL TREES, not tufts (scale 0.2-0.35 for saplings).
- `MapRegistry.get_map()` DROPS non-whitelisted def keys (biome, etc.) — read
  `ZoneDefs.zone(id)` directly for zone metadata.
- Camera needs `await process_frame` + `reset_smoothing()` (twice) after
  RH_FOCUS teleports, already fixed in main.gd — don't regress it.
- `_screens/` is gitignored (QA captures stay local). `_downloads/world_packs`
  has .gdignore but parts of `_downloads` are load-bearing — never ignore it
  wholesale.
- Ground sheets: block-tiled `tx%cols, ty%rows` — accent tiles in the sheet
  become WALLPAPER STRIPES; sheets must be uniform fills, accents go in as
  scattered decals.
- Multiple parallel edits to the same file = lost work; sequence them.

## Quality gates before ANY commit
1. zone edits → `validate_travel.py` PASS + boot with zero errors + zero
   40-second warnings + you LOOKED at a screenshot.
2. audio edits → audio_qa.py 0 FAIL.
3. content (quests/barks/items) → came through studio.py validators, then
   YOU read it for canon fit (grep the lore extract for names you're unsure
   of).
4. Commit messages: what + why + canon refs; end with the Co-Authored-By
   trailer; push to origin main (authorized standing).
5. Update `design/BACKLOG.md` statuses + the agent-memory pointer if state
   changed materially.

## What the driver must NOT do
- No engine rewrites, no canon changes, no new mandates, no paid downloads,
  no deleting owner files, no billed sub-agents while the credit law stands
  (check BACKLOG #105/#108). When blocked on any of these: write the
  question into BACKLOG under "Held for owner" and move to the next task.
