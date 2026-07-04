# RAVEN HOLLOW — AUTO-QA + AUTO-IMPROVE LAW
**Owner mandate (MANDATES.md § Engineering Law): EVERYTHING auto-QA-testable AND auto-improvable — every
system ships with automated tests (headless asserts, windowed screenshot QA, build-time validators like
the 40s rule) and an improvement loop (validator reports → backfill → re-verify). MANDATORY.**

This doc is the design of that law as infrastructure: what exists today, the four-layer QA stack,
the exact file layout, the runner skeleton, the new debug hooks the engine must grow, and a rollout
order that retrofits every shipped system before any new system lands.

Sources of truth read for this design: `scripts/main.gd` (RH_* hooks), `scripts/zone_builder.gd`
(`_validate_forty_second_rule`), `scripts/player.gd` (`debug_cast`), `scripts/save_system.gd`,
`scripts/quest_defs.gd` + `quests.gd`, `scripts/zone_defs.gd`, `WORLD_PLAN.md` (40-Second Rule §),
`design/ITEM_PROGRESSION.md` (budget math), `design/LOOT_TABLES.md`, `design/COMBAT_PACING.md`
(TTK 8–15s law), `design/QUEST_ARCHITECTURE.md` (villain-beat cadence, XP spine), HANDOFF.md.

---

## 0. AUDIT — WHAT EXISTS TODAY (and what it is missing)

### 0.1 The RH_* headless/windowed harness (main.gd, shipped, strong)
Environment-variable hooks that skip the menu and boot straight into instrumented gameplay:

| Hook | Does | QA layer it serves |
|---|---|---|
| `RH_SMOKE=1` | boot, tick ~60 frames, `quit(0)` | functional (headless OK) |
| `RH_CLASS=<id>` | skip class select as warrior/rogue/mage/paladin/necromancer/rookwarden/druid | all |
| `RH_MAP=<id>` | force `change_map` to any MapRegistry zone right after boot | all |
| `RH_SHOT=<path>` | save a viewport PNG after a settle window, quit | visual (WINDOWED only) |
| `RH_CAST=<action>` | teleport near scarecrow, acquire target, `player.debug_cast()` ×3 | functional + visual |
| `RH_UI=1` / `RH_EQUIP=i,j` / `RH_GRANT=id,id` | open bag+sheet / auto-equip bag slots / inject items | functional + visual |
| `RH_ZOOM` `RH_FOCUS` `RH_WIDE` `RH_NOHUD` `RH_NOBANNER` | framing + clean-world capture | visual |
| `RH_TIME=<0..24>` `RH_WEATHER=<type[,int]>` (incl. `ash`) | pin clock / force weather | visual determinism |
| `RH_TALK` `RH_PROMPT` `RH_SAY` `RH_CRAFT` `RH_MAPVIEW` `RH_TIP` `RH_MENU` `RH_SELECT` | dialogue, interact prompt, VO, crafting panel, world map, tooltips, title, class select | visual |

Missing: no machine-readable *result channel* (screenshots and `push_warning` text are the only
outputs); no quest driver; no per-spell sweep (RH_CAST does one action); no stat asserts; no
pass/fail exit-code discipline (everything quits 0 unless it crashes).

### 0.2 The 40-second validator (zone_builder.gd, shipped — the pattern to generalize)
`_validate_forty_second_rule(def, w, h)`: grid-samples every built non-capital zone at 400 px steps,
computes distance to the nearest engagement anchor (landmarks + vignettes + waystations +
creature-territory centers), and `push_warning`s the worst dead spot when it exceeds
`MAX_DEAD_PX = 1750`. All 9 live zones pass — but the last mile was done **by hand**: read the
warning, invent micro-POIs, edit zone_defs.gd, rebuild, re-read. That manual loop is exactly what
§4 turns into a pipeline. Two structural gaps: output is a human-readable warning (not JSON — no
script can consume it), and a warning never fails a build (no exit code, no CI red).

### 0.3 What does NOT exist here
- **No `tests/` directory in this repo.** (The `tests/smoke_test.py` / `profile_run.py` named in the
  memory index belong to the *pygame* project, not Raven Hollow. This doc creates this repo's own.)
- No baseline screenshots, no perceptual diff, no report format, no single runner command.
- Python tooling precedent exists (`tools/map_gen.py`, `bake_vo.py`, `compose_classes.py`) — the QA
  stack follows the same "Python drives, Godot executes" shape.

### 0.4 Hard environmental constraints (learned the expensive way — design around them)
1. **Headless Godot cannot screenshot** (dummy rendering driver, no viewport texture) and **hangs on
   GPUParticles**. → Layer 2 (functional) is headless; Layer 3 (visual) is windowed, serial,
   one instance at a time.
2. Godot exe on this machine: `C:\Users\vstef\tools\godot\Godot_v4.6.3-stable_win64_console.exe`
   (HANDOFF's path is stale) — the runner takes it from `tests/qa_config.json`, never hardcodes.
3. Long background bash jobs die; console is cp1252 — all reports are UTF-8 **files**, runner prints
   ASCII-only summaries.
4. Godot exits 0 on `push_warning`/`push_error` — pass/fail must ride an explicit protocol (§0.5).

### 0.5 The QA output protocol (the one new convention everything speaks)
Every instrumented run emits **QA lines on stdout** plus a JSON file, so results survive even when
file writes fail and Python can stream-parse:

```
QA_JSON|{"check":"zone_40s","zone":"iron_vein","status":"pass","worst_px":1416}
QA_JSON|{"check":"cast","class":"mage","action":"skill_2","status":"fail","reason":"no vfx node spawned"}
QA_DONE|pass          # or QA_DONE|fail — last line before quit; quit code mirrors it (0/1)
```
Runner rule: a run with no `QA_DONE` line within its timeout is a **hang → red**. Any
`SCRIPT ERROR:` line on stderr is a **red** regardless of QA_DONE (functional layer only; visual
layer records it as a warning so one bad bark doesn't block a screenshot matrix).

---

## 1. LAYER 1 — BUILD-TIME VALIDATORS (data is guilty until proven innocent)

**Principle:** almost every mandate is a *data invariant* — validate the data, not the pixels.
**Architecture:** one headless Godot pass dumps all game data to JSON; Python validators audit the
dump against the design-doc math. This keeps heavy math in Python (fast, testable, no engine
restarts) and keeps GDScript's job trivial (serialize honestly).

### 1.1 The gamedata dump (new: `tests/godot/dump_gamedata.gd`, a `SceneTree` script)
```
godot --headless --script res://tests/godot/dump_gamedata.gd   # → build/qa/gamedata.json
```
Serializes, verbatim: `ZoneDefs.ZONES` (+ROUTES, REGION_MUSIC, BIOME_AMBIENCE), `QuestDefs` quest
list, `Items` db, `ClassDefs` (classes, abilities, palettes, keys), `NpcData` (cast, dialogue,
schedules when SMART_NPCS lands), `Crafting` recipes, `TravelSystem` node registry, XP curve table,
loot tables (when they land as data), plus a `res_paths` array of every `res://` string constant
found in the dumped data (for the missing-file scan). Vector2/Rect2 → `[x,y]` / `[x,y,w,h]`.

### 1.2 The validator battery (`tests/validators/*.py` — one file per system)
Each validator: `def validate(gamedata: dict, repo: Path) -> list[Finding]` where
`Finding = {check, severity: "fail"|"warn", subject, detail, fix_hint, payload}` — `payload` is the
machine-readable half that backfill scripts (§4) consume.

| Validator | Invariants enforced (mandate it guards) |
|---|---|
| `v_zone_density.py` | **The 40s rule, ported from zone_builder:** same grid sampling (400 px step, 1750 px max, capitals exempt) but over the *dump*, emitting per-zone `{worst_px, dead_spots:[{pos, dist, nearest_anchor}]}` — ALL dead spots over threshold, not just the worst, because the backfiller needs the full set. zone_builder's in-engine check stays as a belt-and-suspenders warning. |
| `v_zone_defs.py` | Every `built:true` zone: ≥3 vignettes, ≥1 landmark, ≥1 waystation, non-empty creature_table with day/night rows, creature areas inside zone bounds, seams bidirectional (A→B implies B→A with matching entry points), biome ∈ BIOME_AMBIENCE keys, region ∈ REGION_MUSIC keys, wilderness ≥256×192 tiles / capitals ≥320×256 (WORLD_PLAN size law). Stub zones: canon name+biome+continent present (honesty rule). |
| `v_travel_graph.py` | ROUTES symmetric; every waystation id in ROUTES exists in a zone def and vice versa; graph connected per continent; Grey Ferry link present once batch G flips; fast-travel cost defined ≥0. |
| `v_quest_graph.py` | **Reachability & orphan detection:** build the prereq DAG — no cycles; every quest reachable from a starter (no prereq, or auto_trigger); giver/turn_in_npc ids exist in NpcData; objective `enemy` matches a real Enemy type_name; `map` ids exist in MapRegistry/ZoneDefs; reward/accept item ids exist in Items or Crafting dbs; aftermath npc ids exist; every `choice` has ≥2 branches. **XP budget:** Σ(quest XP by bracket) + kill-XP model vs the ~2.54M slow-classic curve per QUEST_ARCHITECTURE — each level bracket within ±15% of its share (warn), main-story-only path must still reach act gates (fail). **Villain cadence:** `villain_beat.kind` ∈ the 6 canonical forms; per-act cadence counts vs VILLAIN_ARC's 16 touch-points (warn drift). |
| `v_loot_budget.py` | **Loot audit vs ITEM_PROGRESSION math:** for every item with `ilvl`: stat total ≤ slot budget × rarity multiplier (the doc's formula — fail on over-budget, warn ≥5% under); `req_level` consistent with ilvl band; rarity ∈ the 6 tiers; legendaries never appear in random loot tables (narrative-capstone law); per-table drop-rate sums ≤ 100%; each table's expected value per kill within the bracket's coin/greens envelope; the 16 named rares' tables point at real item ids; per-family×bracket table exists for every creature family a built zone spawns. |
| `v_spells.py` | **Spell-palette collision checks:** per-class palette colors pairwise distinct across classes (ΔE / RGB distance ≥ threshold — the "cohesive class palette" mandate means a mage bolt must never read as necromancer green); ability count per class vs the ~30-spell WoW-parity target (warn until trainers land, fail after); every ability's icon + VFX resource paths exist; no two abilities in one class share a default keybind; trainer spell level-gates monotonic. |
| `v_npc_schedule.py` | (arms when SMART_NPCS ships) Schedule sanity: every waypoint inside its zone's bounds and on walkable tiles; time windows cover 24h with no gaps/overlaps per NPC; two NPCs never claim the same bed/stool slot in the same window; dialogue speaker ids exist; barks reference live zone ids. Until then: dialogue-graph lint only (giver pages non-empty, aftermath targets exist). |
| `v_save_roundtrip.py` | Drives the headless engine (this one shells out): new-game state + a mutated state (items granted, quest mid-chain, clock moved, zone travelled) → `SaveSystem.save_game()` → `load_game()` → normalized-dict deep-compare, and a **schema check** of the on-disk JSON vs the documented shape (SAVE_VERSION bump = update the schema or fail). Also loads a corpus of `tests/fixtures/saves/*.json` (one frozen per SAVE_VERSION ever shipped) — old saves must load with warnings, never crash (the defensive-load contract). |
| `v_assets.py` | Every `res://` path in the dump exists on disk; every atlas `Rect2` const in builders within its sheet's true PIL-measured bounds (the "never guess sheet geometry" law, mechanized); CREDITS.md contains an entry for every pack directory referenced (CC-BY-SA attribution law); no file references into gitignored `_downloads/world_packs/` from shipped zones without the pack being marked local-only-OK. |
| `v_text_tone.py` | (cheap heuristics, warn-only) Quest text: no unresolved `{placeholder}`; Underlanguage lines never accompanied by a translation (canon: never subtitled); banned-word list (modern idiom) per the Tolkien-register style guide once it ships. |

### 1.3 Escalation discipline
- `fail` findings → runner exits non-zero → red. `warn` → yellow, listed, never blocks.
- A brand-new validator always lands in **warn-only quarantine** for one full green run over the live
  build, then flips to enforcing — retrofits must never turn the tree red on arrival (that's how
  validators get deleted instead of fixed).
- zone_builder's in-engine 40s check gets one edit: also emit `QA_JSON|` lines when `RH_QA=1`, so
  the build-time and dump-time checks can be cross-verified.

---

## 2. LAYER 2 — HEADLESS FUNCTIONAL SUITE (the game plays itself)

Windowless, parallel-safe (no GPU contention — but keep ≤2 concurrent: audio device contention is
real), every run speaks the QA protocol (§0.5). This layer needs **new engine hooks** — specced in
§2.6 — all following the existing RH_* env-var idiom in main.gd.

### 2.1 Boot matrix — every zone boots clean
For each `built:true` zone × 2 classes (one melee, one caster — cheap coverage of both kit paths):
```
RH_QA=1 RH_CLASS=warrior RH_MAP=iron_vein RH_SMOKE=1 godot --headless
```
Pass = 60 frames tick, `QA_DONE|pass`, zero `SCRIPT ERROR`, zero `ZoneBuilder[40s]` fails,
boot-to-playable under a per-zone time budget (perf canary, generous: 15 s). The smoke hook grows
frame-time sampling under RH_QA: emits `{avg_ms, worst_ms}` — a zone whose worst frame exceeds 33 ms
headless is a yellow (headless ≠ real perf, but regressions still show).

### 2.2 Cast matrix — every spell of every class actually fires
New hook `RH_CASTALL=1` (extends the shipped RH_CAST scarecrow pattern): teleport to the scarecrow,
then for **each ability in the class kit** (from ClassDefs, not a hardcoded list — new spells are
covered the day they're added): `debug_cast`, wait the ability's cast+travel window, assert via
QAReport: (a) no script errors, (b) cooldown actually started, (c) mana/resource was spent per the
def, (d) an effect was observed — scarecrow HP delta for damage spells, buff applied for buffs,
Minion node in tree for summons, VFX node count rose for everything (the AAA-spell mandate's
cheapest honest proxy). Runs 7× (once per class). Also asserts the STATUS_EFFECTS stacking law:
wolf-bite ×3 → Infected, via a scripted triple-proc.

### 2.3 Quest driver — every chain accept → objectives → turn-in
New hook `RH_QUEST=<id>|all` + a `Quests.debug_*` API (§2.6). For each quest in dependency order:
- **accept**: satisfy prereqs via `debug_force_complete` of ancestors (fast path), then drive the
  real giver: teleport to giver, call `interact`, walk the offer pages — assert quest active.
- **objectives**, each by kind, through *real mechanics* wherever cheap:
  `talk` → teleport + interact, walk pages; `kill` → `Combat.debug_spawn(enemy, near_player)` +
  `Enemy.debug_kill()` × count (exercises the real kill-credit path); `reach` → teleport into the
  radius (night_only: RH_TIME first); `choice` → run the quest **once per branch** (matrix expands);
  `use_item` → grant + use.
- **turn-in**: teleport to turn_in_npc, interact — assert: rewards granted exactly (xp/gold/item
  deltas match the def), journal note written, aftermath dialogue actually swapped on the target NPC,
  auto_trigger/finale beats fired where defined.
- Chains run **within one process** where possible (state accumulates like a player's would);
  the full campaign eventually becomes a single long-haul run — the closest thing to a bot
  playthrough before the Adventurer Sim exists.

### 2.4 Item / stat asserts — the WYSIWYG + budget laws at runtime
New hook `RH_GEARCHECK=1`: for every equippable item in the Items db: grant → equip →
assert `Inventory.stat_totals()` equals the item's stat dict summed with prior gear; assert
`player` derived stats moved by exactly the documented rule (`_apply_equipment` contract: hp/mana
add to maxima, speed_pct multiplies, damage adds to abilities, crit rolls 1.5×); for visible-gear
slots assert the paper-doll/world sprite layer actually changed (node/texture swap observed — the
NO-TRANSMOG/WYSIWYG law's functional half; its *visual* half lives in Layer 3); unequip → assert
perfect restore. Proficiency law (cloth/leather/mail/plate): assert each class can equip exactly
its legal armor classes and is refused the rest.

### 2.5 Combat pacing probe — the TTK law
New hook `RH_TTK=<family>|all`: spawn each creature family at its bracket level vs a
bracket-median-geared player (fixture gear sets per bracket, generated from ITEM_PROGRESSION math),
auto-attack + rotation via debug_cast until death, sample 10 fights: median TTK must land in the
COMBAT_PACING 8–15 s window (normal mobs), and player must have been *threatened* (took ≥N% max HP —
this is the assert that would have caught the global INVULN_TIME blocker COMBAT_PACING found by
reading). Warn-only until the pacing retune ships, then enforcing.

### 2.6 New engine hooks to build (the full spec)
All env-var gated, all no-ops in normal play, all live in main.gd + a new autoload:

| New hook / API | Spec |
|---|---|
| `scripts/qa_report.gd` (autoload `QAReport`) | The protocol speaker. `QAReport.check(name, subject, ok, detail:="", payload:={})` → buffers + prints `QA_JSON\|...`; `QAReport.finish()` → writes `user://qa_report.json`, prints `QA_DONE\|<verdict>`, `get_tree().quit(0 or 1)`. Registers a `push_error` interceptor (via `--log-file` parsing runner-side, since Godot lacks an error signal — the runner treats stderr as part of the record). Only instantiated when `RH_QA=1`. |
| `RH_QA=1` | Master switch: instantiates QAReport, makes zone_builder's 40s check emit QA_JSON, makes smoke emit frame timings. |
| `RH_CASTALL=1` | §2.2. Iterates `ClassDefs` kit of `RH_CLASS`. |
| `RH_QUEST=<id>\|all[,branch=N]` | §2.3 driver. |
| `RH_GEARCHECK=1` | §2.4 sweep. |
| `RH_TTK=<family>\|all` | §2.5 probe. |
| `RH_SEED=<int>` | Seeds *every* RNG the boot path touches (builders already take seeds; weather drift, loot rolls, ambient spawns get plumbed). Determinism backbone for Layer 3. |
| `RH_DETERMINISTIC=1` | RH_SEED=1 + pin day/night (unless RH_TIME set), freeze AnimatedSprite2D global frame at 0 after settle, disable weather drift + ambient fauna wandering, mute autosave. Screenshots become byte-comparable-ish; perceptual diff does the rest. |
| `Quests.debug_accept(id)` / `debug_advance(id, obj_id)` / `debug_force_complete(id)` / `debug_choose(id, obj_id, branch)` | Quest driver primitives; force_complete also grants rewards through the *real* reward path (never a parallel one — parallel paths rot). |
| `Combat.debug_spawn(type, pos)` / `Enemy.debug_kill(attacker)` | Kill-credit-preserving spawn/kill (die via the normal `_grant_kill_rewards` path). |
| `Player.debug_equip(item_id)` / `debug_use(item_id)` | Gear/consumable sweep primitives (bag-index-free — RH_EQUIP's index form stays for visual runs). |

---

## 3. LAYER 3 — WINDOWED VISUAL QA (perceptual regression vs blessed baselines)

The pixels ARE the product (style gate, WYSIWYG, AAA spells, map masterpiece) — so pixels get
regression-tested like code. **Windowed, serial, foreground** (headless renders nothing — hard
constraint §0.4). 640×360 native shots keep baselines tiny (~300 KB) — plain git, no LFS needed.

### 3.1 The screenshot matrix (`tests/qa_config.json → "matrix"`, data not code)
Each row = an id + the env dict for one run. Seed rows (grows with every feature):

| Matrix family | Rows | Env recipe |
|---|---|---|
| `zone/<id>/wide` | every built zone | `RH_MAP RH_NOHUD=1 RH_WIDE RH_ZOOM=0.22 RH_DETERMINISTIC=1 RH_SHOT` |
| `zone/<id>/play` | every built zone | gameplay framing + HUD, fixed RH_FOCUS per zone (a hand-picked postcard spot in the zone def: `qa_focus`) |
| `zone/<id>/night` | every built zone | + `RH_TIME=23` (lights/glow regression) |
| `weather/<type>` | 6 types on canon zones (ash→volcanic, snow→tundra, no-fog Black Night) | `RH_WEATHER` |
| `class/<id>/cast_<n>` | 7 classes × signature casts | `RH_CAST` per ability (AAA-spell mandate's eyes) |
| `ui/<panel>` | bag, sheet(+RH_EQUIP), tooltip, crafting, world map, minimap, menu, class select, options | shipped UI hooks |
| `quest/<beat>` | finale beats / cinematics as they land | RH_QUEST + RH_SHOT combo |

### 3.2 Perceptual diff (`tests/lib/perceptual.py`, Pillow-only — no new deps)
Per pair (new, blessed): (1) optional **mask** (`tests/masks/<row>.png` black = ignore: clock digit,
minimap, FPS corner); (2) grid the frame 16×9 tiles; per-tile RMS in linear RGB; (3) row score =
worst tile; plus a global 64-bit dHash distance. Thresholds in config (`tile_rms: 9.0`,
`hash_bits: 10` to start — tuned during rollout). Verdicts: `pass` / `changed` (over threshold) /
`new` (no baseline) / `error` (run died). `changed` is **yellow, never red** — pixels change for good
reasons; the gate is that a human (or the session agent, by *reading the pngs* — the workflow law)
must bless or fix. `error` is red.

### 3.3 Bless workflow + report
```
py tests/qa.py visual                 # run matrix → build/qa/shots/, diff vs tests/baselines/
py tests/qa.py bless zone/vetka/wide  # copy shot → baseline (or `bless --all-changed` after review)
```
Report: `build/qa/visual_report.html` — self-contained gallery, one row per matrix id:
baseline / new / amplified-diff triptych, worst-tile highlighted, verdict badge. This is the
artifact the "integration agent must READ the pngs" law points at — one page instead of a folder.

---

## 4. LAYER 4 — THE IMPROVE LOOP (validator reports drive backfill scripts)

The 40s-rule backfill was done by hand once; that manual session is the template, mechanized:
**every validator's `payload` is designed to be a backfiller's input.**

### 4.1 The loop protocol (what `qa.py improve` runs)
```
validate → findings.json → [for each finding class with a registered backfiller]
  → backfill (writes real data edits) → re-validate (must now pass) → re-screenshot affected rows
  → perceptual diff → append to improve_log.json → STOP; leave the git diff for review
```
Hard rules: a backfiller **never commits** — it leaves a working-tree diff + regenerated shots; it
must make its own finding pass on re-validate or it reverts itself (no thrashing); one backfiller
per finding class (registered in `tools/qa/backfill_registry.py`); findings with no backfiller are
written to `build/qa/TODO_QA.md` grouped by owner-decision vs mechanical (the session picks up the
mechanical ones; the owner sees the decisions).

### 4.2 Pilot backfiller: `tools/qa/backfill_40s.py` (the hand-job, pipelined)
Input: `v_zone_density` payload — full dead-spot list per zone with positions and gap sizes.
For each dead spot: choose a micro-POI archetype from a **per-biome table** (bog → bone-spill,
leaning stone, drowned cart; tundra → cairn, frozen camp; volcanic → slag heap, cooled vent;
moor → boundary stone, empty farmstead — all WORLD_PLAN § canon set: shrines, stone rows, bone
spills, abandoned camps, rare-spawn lairs), jitter position off the exact grid point, and append it
to the zone def. **Write target:** micro-POIs go into a separate generated block
(`# --- QA BACKFILL (generated by backfill_40s.py — edits welcome, regeneration appends only) ---`)
inside each zone's `landmarks` list via a Python patch-script (the repo's proven edit pattern —
never Edit-tool during Godot re-import). Hand-authored data stays visually untouched above the
marker; the hand-crafted law is preserved because archetypes are hand-designed per biome and every
diff is reviewed with fresh screenshots before commit.

### 4.3 Backfillers that follow the same pattern
| Finding class | Backfiller behavior |
|---|---|
| loot budget over/under | rewrite the item's stat dict to the exact budget split preserving its stat *identity* (ratios), emit before/after table |
| missing loot table (family×bracket) | generate a skeleton table from the bracket's envelope math, flagged `"generated": true` for hand-flavoring |
| quest orphan (unreachable) | insert into TODO_QA as owner-decision if narrative; auto-fix only pure data typos (fuzzy-match giver/npc/item ids, ≥0.9 similarity, listed in the diff) |
| missing ambience/music file | wire the biome/region fallback explicitly + TODO entry for the acquisition list |
| asset path dead | fuzzy-match against the asset tree; auto-fix ≥0.95 confidence, else TODO |
| spell palette collision | propose the minimal hue rotation that clears the ΔE threshold, as a diff to the class palette const (owner-review — palettes are identity) |

### 4.4 The law applied to future systems (this is the auto-improvable half of the mandate)
Every new design doc must ship with: (a) its validator (§1 table row), (b) its functional matrix
entries (§2), (c) its visual matrix rows (§3), (d) *either* a backfiller *or* an explicit
`TODO_QA`-only declaration for its finding classes. **A workflow that lands a system without its QA
quartet is incomplete by definition** — the integration agent's checklist ends with `qa.py all`
green/yellow, never red.

---

## 5. THE RUNNER — ONE COMMAND (`py tests/qa.py all`)

### 5.1 File layout
```
tests/
  qa.py                       # entry point — the ONE command
  qa_config.json              # godot exe path, timeouts, thresholds, the visual matrix
  lib/
    godot.py                  # launch/kill/timeout Godot with env dicts; QA_JSON stream parser
    findings.py               # Finding type, severity math, json io
    perceptual.py             # tile-RMS + dHash diff, mask support (Pillow)
    report.py                 # console summary + visual_report.html + summary.json
  godot/
    dump_gamedata.gd          # SceneTree script → build/qa/gamedata.json
  validators/
    v_zone_density.py  v_zone_defs.py  v_travel_graph.py  v_quest_graph.py
    v_loot_budget.py   v_spells.py     v_npc_schedule.py  v_save_roundtrip.py
    v_assets.py        v_text_tone.py
  fixtures/
    saves/v1.json ...         # one frozen save per SAVE_VERSION ever shipped
    gear_brackets.json        # generated median gear sets for the TTK probe
  baselines/                  # blessed pngs, committed (640×360, small)
  masks/                      # ignore-region masks
scripts/
  qa_report.gd                # the QAReport autoload (engine side, RH_QA-gated)
tools/qa/
  backfill_registry.py  backfill_40s.py  backfill_loot.py ...
build/qa/                     # gitignored: gamedata.json, findings.json, shots/, reports
```

### 5.2 Runner skeleton (`tests/qa.py`)
```python
#!/usr/bin/env python3
"""Raven Hollow QA — the one command.
  py tests/qa.py all|validate|functional|visual|improve|quick|report
  py tests/qa.py bless <matrix_id>|--all-changed
"""
import json, subprocess, sys, time
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
CFG  = json.loads((ROOT / "tests/qa_config.json").read_text("utf-8"))
OUT  = ROOT / "build/qa"

def run_godot(env_extra: dict, headless: bool, timeout_s: int) -> "RunResult":
    """lib/godot.py: spawn CFG['godot_exe'] --path ROOT (+ --headless), merged env,
    stream stdout for QA_JSON|/QA_DONE| lines, capture stderr SCRIPT ERRORs,
    kill on timeout (hang == red). Returns parsed checks + verdict + timings."""

def stage_validate() -> list:
    run_godot({"RH_QA": "1"}, headless=True, timeout_s=120,
              extra_args=["--script", "res://tests/godot/dump_gamedata.gd"])
    gamedata = json.loads((OUT / "gamedata.json").read_text("utf-8"))
    findings = []
    for v in discover(ROOT / "tests/validators"):        # v_*.py, sorted
        findings += v.validate(gamedata, ROOT)           # each returns [Finding]
    (OUT / "findings.json").write_text(json.dumps(findings, indent=1), "utf-8")
    return findings

def stage_functional() -> list:
    jobs = boot_matrix(CFG) + cast_matrix(CFG) + quest_matrix(CFG) + \
           [{"RH_QA":"1","RH_GEARCHECK":"1"}, {"RH_QA":"1","RH_TTK":"all"}]
    return [run_godot(j, headless=True, timeout_s=CFG["functional_timeout_s"])
            for j in jobs]                               # ≤2 workers, pool

def stage_visual() -> list:
    results = []
    for row in CFG["matrix"]:                            # SERIAL — windowed law
        env = dict(row["env"], RH_QA="1", RH_DETERMINISTIC="1",
                   RH_SHOT=str(OUT / "shots" / (row["id"].replace("/", "_") + ".png")))
        r = run_godot(env, headless=False, timeout_s=CFG["visual_timeout_s"])
        r.verdict = perceptual.compare(row["id"], shot, ROOT / "tests/baselines", CFG)
        results.append(r)
    return results

def stage_improve(findings) -> None:
    from tools.qa.backfill_registry import REGISTRY
    for cls, group in group_by_check(findings):
        if fixer := REGISTRY.get(cls):
            fixer.apply(group, ROOT)                     # edits working tree
            assert not [f for f in stage_validate() if f["check"] == cls and
                        f["severity"] == "fail"], f"backfiller {cls} did not converge"
        else:
            todo_append(cls, group)                      # build/qa/TODO_QA.md

def main() -> int:
    stage = sys.argv[1] if len(sys.argv) > 1 else "all"
    red = report.summarize(                              # ASCII table + summary.json + html
        validate=stage_validate() if stage in ("all", "validate", "quick", "improve") else None,
        functional=stage_functional() if stage in ("all", "functional") else None,
        visual=stage_visual() if stage in ("all", "visual") else None)
    if stage == "improve": stage_improve(...)
    return 1 if red else 0

if __name__ == "__main__": sys.exit(main())
```

### 5.3 Config seed (`tests/qa_config.json`)
```json
{ "godot_exe": "C:/Users/vstef/tools/godot/Godot_v4.6.3-stable_win64_console.exe",
  "functional_timeout_s": 90, "visual_timeout_s": 60, "workers": 2,
  "thresholds": {"tile_rms": 9.0, "hash_bits": 10, "boot_budget_s": 15},
  "quick_zones": ["town", "vetka", "iron_vein"],
  "matrix": [ {"id": "zone/vetka/wide", "env": {"RH_MAP": "vetka", "RH_NOHUD": "1",
               "RH_WIDE": "1", "RH_ZOOM": "0.22"}} ] }
```

### 5.4 Summary contract (what green means)
```
RAVEN HOLLOW QA ---------------------------------------------
 validate    41 checks   38 pass   2 warn   1 FAIL
 functional  9 zones + 7 casts + 5 quests + gear + ttk : PASS
 visual      64 rows     59 pass   4 changed(review)   1 NEW
 verdict: RED (v_loot_budget: rooks_talon 6% over epic budget @ilvl22)
 reports: build/qa/summary.json  visual_report.html  TODO_QA.md
```
`all` red = do not commit. `changed` visuals = review the html, bless or fix. Session cadence:
`qa.py quick` (validators + 3-zone boot, <2 min) before every commit; `qa.py all` before every
push; `qa.py improve` as its own reviewed commit.

---

## 6. ROLLOUT ORDER (retrofit shipped systems FIRST — each phase lands green)

**Phase 0 — Scaffolding (one session).** `tests/` tree, `qa_config.json`, `lib/godot.py` launcher
+ QA_JSON parser, `dump_gamedata.gd`, `scripts/qa_report.gd` + `RH_QA` wiring in main.gd,
`qa.py` with `validate` stage only. Exit: `qa.py validate` runs one trivial validator
(v_assets path-scan) green.

**Phase 1 — Retrofit validators over everything already shipped (1–2 sessions).**
Port the 40s rule to `v_zone_density` (verify it agrees with zone_builder on all 9 live zones);
`v_zone_defs` + `v_travel_graph` over the live world; `v_quest_graph` over the 5 shipped quests;
`v_loot_budget` over the shipped items + 5 legendaries (ITEM_PROGRESSION already retro-validated
this math by hand — mechanize that exact audit); `v_spells` over 7 classes; `v_save_roundtrip` +
freeze the v1 save fixture; `v_assets` full (PIL rect audit mechanizes the ASSET_MANIFEST law).
Exit: `qa.py validate` green on HEAD — every warn triaged, quarantine flips done.

**Phase 2 — Headless functional retrofit (1–2 sessions).** QAReport asserts into the smoke path;
boot matrix (9 zones × 2 classes); `RH_CASTALL` + cast matrix (7 classes, every shipped ability);
`Quests.debug_*` API + `RH_QUEST` driver over the 5 demo quests (incl. the choice branches);
`RH_GEARCHECK`. `RH_TTK` lands warn-only (the INVULN_TIME fix flips it enforcing).
Exit: `qa.py functional` green; a deliberately injected bug (break a quest reward) turns it red.

**Phase 3 — Visual QA + first bless (1 session).** `RH_SEED`/`RH_DETERMINISTIC` plumbing;
perceptual.py + masks; seed matrix (~60 rows: 9 zones × wide/play/night, 6 weather, 7 class casts,
9 UI panels); run twice back-to-back — flaky rows get masks or determinism fixes until repeat-stable;
then bless all as the founding baselines; visual_report.html.
Exit: `qa.py visual` green twice in a row from cold.

**Phase 4 — The improve pilot (1 session).** `backfill_registry` + `backfill_40s.py`; prove the
loop end-to-end: temporarily raise MAX_DEAD_PX to 1200 so live zones "fail" → backfill generates
biome-true micro-POIs → re-validate green → shots regenerate → review diff → drop threshold back.
Add `backfill_loot.py`. Exit: one full `qa.py improve` cycle producing a reviewable, committable diff.

**Phase 5 — The law goes live (ongoing).** MANDATES.md Engineering Law flips 🔄→✅. Every workflow
prompt template gains the QA-quartet requirement (§4.4); integration agents end on `qa.py all`;
new systems (SMART_NPCS schedules → `v_npc_schedule`, loot window → drop-rate contract tests,
talents/trainers → v_spells enforcement, dungeons → boot matrix rows) arrive with their tests in
the same commit. The suite is the second player the Adventurer Sim will one day make literal.

---

## 7. WHAT THIS BUYS (why every layer earns its runtime)

| Mandate | Enforced by |
|---|---|
| 40-second rule, forever | v_zone_density + backfill_40s (no more hand loops) |
| hand-crafted zones stay intact | validators read, backfillers append below a marker, humans commit |
| ~1000-quest graph never ships an orphan or a dead giver | v_quest_graph + RH_QUEST driver |
| slow-classic 2.54M XP economy stays solvent | XP budget audit per bracket |
| loot math = ITEM_PROGRESSION law, always | v_loot_budget + gearcheck runtime asserts |
| AAA spells: every cast fires, reads distinctly, looks right | RH_CASTALL + palette collision + cast shots |
| WYSIWYG / proficiency laws | RH_GEARCHECK sprite-swap + equip-refusal asserts |
| every mob a real fight (TTK 8–15s) | RH_TTK probe |
| saves never eat a character | v_save_roundtrip + frozen fixture corpus |
| the style gate survives 40 zones of iteration | blessed baselines + perceptual diff |
