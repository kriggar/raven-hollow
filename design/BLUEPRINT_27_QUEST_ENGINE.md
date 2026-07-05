# BLUEPRINT #27 — QUEST ENGINE v2 + the 1,000-quest campaign
Fable architecture, Opus executes. Design canon: QUEST_ARCHITECTURE.md,
VILLAIN_ARC.md, ZONE_QUEST_MATRIX.md, QUEST_EXEMPLARS.md (all committed).

## Split of labor
- ENGINE (this blueprint): Opus builds once.
- DATA (1,000 quests): local studio quest_writer emits JSON (proven ~90%
  quality); Fable-successor/owner reviews register + the ~16 VILLAIN_ARC
  touch-point quests get hand-polish. Studio batch → data/quests/*.json.

## Data format (data/quests/<zone_id>/<quest_id>.json)
{ "id", "title", "zone", "giver_npc",              // giver matches NPC_CAST id
  "level": int, "type": "side|main|daily|event",
  "prereq": ["quest_id", ...], "act": 1|2|3,        // main-arc gating
  "steps": [ {"kind": "kill",    "target": "<enemy name>", "count": 6}
           | {"kind": "collect", "item": "<item_id>", "count": 4,
              "drop_from": "<enemy name>", "chance": 0.4}
           | {"kind": "examine", "map": "<zone>", "pos": [x,y], "radius": 48,
              "label": "the unaligned grave"}       // spawns a shimmer marker
           | {"kind": "talk",    "npc": "<npc_id>"}
           | {"kind": "escort",  "npc": "<npc_id>", "to": [x,y]}  // v2, reuse Mira beat
           ],
  "dialogue": {"offer", "progress", "complete"},    // giver lines
  "rewards": {"xp", "gold", "item": null|"item_id", "reputation": {...}} }
Validator (tools/quest_lint.py — Opus writes): schema + giver exists in
NPC_CAST + enemy names exist in that zone's creature_table + examine pos
inside zone bounds + level within zone band (ZONE_QUEST_MATRIX) + prereq
acyclic. Run in CI/pre-commit like validate_travel.py.

## Engine (scripts/quests_v2.gd — new autoload; do NOT rewrite frozen Quests)
The existing Quests node (frozen file, subclassed in main.gd) keeps the
Phase-C tutorial chain. quests_v2 runs ALONGSIDE for data quests:
- registry: lazy-load zone's quest files on zone entry (streamer hook).
- state: {quest_id: {step_idx, counts: {}, done, turned_in}} — serialize/
  deserialize via the established 3-line save-group pattern ("quests_v2").
- signals in: Combat kill events (enemy display name), inventory add events,
  player position (examine radius, 0.5s poll), dialogue完成 events.
- signals out: quest_offered/progress/completed → HUD tracker + toast +
  banner reuse; VO barks via voice_client when giver speaks.
- NPC integration: npc.gd already supports dialogue trees — add quest hooks:
  giver shows "!" sprite overlay (atlas: use minimap-pin art) when a quest
  in registry has giver==npc and prereqs met; "?" when turn-in ready.
  POTHOLE: NPC ids — NPC_CAST rollout (#29) must land ids on NPC nodes
  first; until then quests bind to placeholder ids: block quest visibility
  when giver npc not present in world (no crash).
- examine markers: shimmer = reuse warm-ground glow at 0.5 scale, examine
  key = existing [E] world-prompt loop in main.gd (_physics_process) — add
  quests_v2.get_nearby_examine(player_pos) to the prompt candidates.
- daily reset: DayNight day counter (add day_index to save); event quests
  gate on CALENDAR_EVENTS dates.

## Tracker UI (scripts/quest_tracker.gd, CanvasLayer)
Right-side list, max 5 tracked: title + current step counts, gold/parchment
style per UI kit (ornate_ui). Click-to-untrack. Map pins (#47 hook): expose
quests_v2.get_pins(zone) -> [{pos, kind}].

## The 16 villain touch-points (VILLAIN_ARC)
Implemented as normal data quests flagged "act" + "touch_point": N. Fable's
successor hand-writes dialogue for these; engine needs ONE extra step kind:
  {"kind": "cinematic", "id": "act1_scene2"} → calls Cinematics system
  (#51 blueprint) or, until it exists, a letterboxed slow-pan on a target
  (already have GlowEnv + camera tween utilities in main).

## Build order for Opus
1. quest_lint.py + 3 hand-made test quests in town (kill rats/talk/examine).
2. quests_v2 autoload: load/state/save + kill/collect/examine/talk kinds.
3. Giver !/? overlays + offer/turn-in dialogue splice into npc.gd.
4. Tracker UI + toasts. 5. daily/event gating. 6. escort + cinematic kinds.
7. Studio batch: 25 quests/zone × 40 zones via bark-style batch file; lint;
   Fable-successor review pass; commit in zone folders.
Acceptance: tutorial chain untouched; save round-trips mid-quest; 3 test
quests completable end-to-end on video (RH_WALK script); lint green on all
data; no quest references a missing npc/enemy/pos.

## Effort
Opus: 2 sessions engine + UI. Studio: ~2 GPU-days for 1,000 drafts.
Review: the bottleneck — batch in 50s, spot-check 20%, hand-polish act quests.
