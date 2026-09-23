# THE BACKLOG — canonical numbered task registry (NEVER LOSE THIS — owner mandate)
Anti-hallucination law: this is THE definitive task list. Triple-stored: this repo (committed),
GitHub (pushed), and the agent memory system points here. Every session resumes from this file.
Fresh session read order: design/MANDATES.md → THIS FILE → design/*.md as needed.
Legend: ✅ done · 🔧 in progress · 📐 designed (doc committed) · ⬜ queued · ⚠ owner input needed.

## THE REGISTRY (122 tasks)
### Shipped foundation (1-20)
1. ✅ TTS voice system + 173 baked NPC lines (v1)
2. ✅ Weather system (rain/snow/storm/fog + zone-native tables + ASH + drift)
3. ✅ Class sprite decision (Szadi originals kept per owner revert)
4. ✅ [E] prompt fix + spell tooltips (custom in-scene)
5. ✅ WoW-style spell kits ×7 classes + Druid class + distinct palettes (54 abilities)
6. ✅ Premium painterly ability icons (54)
7. ✅ Foozle/pack VFX upgrades + beast summons (spirit-wolf, raven)
8. ✅ AAA 2D lighting: HDR-2D glow + shadow-casting lights + occluders
9. ✅ GPU tree-sway + pond/bubble animation layer
10. ✅ World engine: ZoneBuilder + ZoneDefs + TravelSystem (waystations/fast travel)
11. ✅ WORLD_PLAN: 40 zones / 2 continents from the lore bible
12. ✅ Batch A: Border ring (iron_vein, vetka, copper_wells, stonepath)
13. ✅ Batch B: West arm + Angel Wings capital (9 zones live total)
14. ✅ Dead Swamp + craftpix pack terrain integration (bog/deadforest)
15. ✅ Zone audio v1: 6 region themes + 8 ambience beds + weather SFX (credited)
16. ✅ 40-Second Rule validator + all live zones densified to pass
17. ✅ 4K one-shot level cameras (RH_RES) + 142-shot sweep grid
18. ✅ Prime-Mandate sitting #1 (14/14 inspectors) + 7-defect fix pass + re-sweep
19. ✅ Combat unblock: INVULN 0.5→0.18 + out-of-combat recovery
20. ✅ Voice v2 COMPLETE: 173/173 expressive lines verified + committed
### Governance systems (21-26)
21. ✅ MANDATES.md master rule ledger + this BACKLOG registry
22. ✅ Million Design Council (1M bots, Ocarina Bar, tools/design_council)
23. ✅ Asset Gauntlet (1000-bot military corps, tools/asset_gauntlet) — ⬜ round 1 on 22 packs
24. ✅ Map masterpiece v1-v3.2 (parchment, routes, plates, all 23 C1 zones labeled) — 🔧 NEXT: draw Continent 2 per the canonical Batch-G topology grid (archive N, anchorfall S, drowned west bay)
25. ✅ 30+ design docs committed (see design/)
26. ✅ Anti-hallucination triple storage (this file + GitHub + memory)
### Design docs complete, implementation queued (27-45)
27. ✅ Quest engine (data objectives + tracking + rewards, 12 quests) — BUILT (BLUEPRINT_27) e8e27a9
28. ✅ Calendar + 12 seasonal events (tied to day/night clock) — BUILT 8f909ae
29. ✅ NPC cast rollout (384 NPCs across all 39 built zones, unique ids/personality/lines) - BUILT
30. ✅ Item progression (gear-score/level, via InventorySystem) — BUILT 2026-07-06
31. ✅ Loot tables + 16 named rares — BUILT (LootSystem, rarity budgets) f1c905f
32. ✅ LOOT WINDOW (D2-style, rarity+tooltips) — BUILT
33. ✅ Combat retune (archetypes/telegraphs/casts/charges/XP-to-60) — BUILT (BLUEPRINT_33, TTK PASS) 3f120e5
34. ✅ Character stats (5 primaries + derived + per-class scaling) — BUILT (StatsSystem) efd0a23
35. ✅ Status effects + wolf→Infected chain — BUILT (StatusSystem)
36. ✅ Hidden debuffs/curses (silent stat mods, discovery/reveal/cleanse, StatusSystem mirror) — BUILT 023d4b0
37. ✅ Runewords/sockets/12 runes (D2 dark-gold) + StatsSystem bonuses — BUILT aa05b60
38. ✅ Mounts: 31 mounts, summon/speed, elite trophies, trainers — BUILT (MountSystem) 12439d6
39. ✅ Options suite + persisted settings (video/audio/gameplay/controls) — BUILT (OptionsSystem) 1c22b5d
40. ✅ Smart NPCs: schedules, vendors + shop UI, reactions — BUILT (SmartNPCSystem) 7ab946d
41. ✅ Talent trees (21, 252 talents, prereqs) + StatsSystem hooks — BUILT (TalentSystem) 6055cc2
42. ✅ Crafting: 7 professions, 35 recipes, skill-to-1000, legendaries — BUILT (CraftingSystem) 7edd7ed
43. ✅ Starting-zone new-player flow (per-class onboarding checklist + starter reward) — BUILT 023d4b0
44. ✅ 7 legendary weapons + unique signature effects + acquisition + WYSIWYG — BUILT 5b29780
45. ✅ Proficiencies cloth/leather/mail/plate + equip gating — BUILT (InventorySystem) ea97bbd
### Design docs complete, systems queued (46-60)
46. ✅ PvP arena (Reckoning Floor) + 14-rank Accord Roll + 55 titles — BUILT 54f492e
47. ✅ Map system: 3-tier zoom + fog-of-war + pins + minimap — BUILT (MapSystem) d0aa4a3
48. ✅ QA stack (F1 debug console 10 cmds + 14-system smoke harness, 14/14 pass) - BUILT
49. ✅ Narrative voice (17 lore entries, zone/faction barks, narrator beats, chronicle journal) - BUILT
50. ✅ The Great Battle scripted set-piece (waves, objectives survive/defend/push, boss finale, morale) — BUILT b61829b
51. ✅ Cinematics/cutscene player (letterbox, camera pan/zoom, subtitles, fade, 4 cinematics) — BUILT b61829b
52. ✅ Freedom & physics props (13 props, 6 kinds: push/break/throw/lift/climb/switch + no-walls audit) - BUILT
53. ✅ Dynamic music director (7 states, per-zone beds, 4 stingers, crossfade, guarded-silent) - BUILT
54. ✅ Audio QA COMPLETE: tools/audio_qa.py validator (192 files: decode/duration/peak/LUFS-windows/loop-seam) + tools/audio_fix_loops.py (seamless-loop rotation render); 9 beds repaired, all 173 VO pass — validator runs per audio batch forever
55. ✅ Achievements deed-book (9 cat, 69 deeds, toasts+panel, persist) — BUILT 9bc7cdd
56. 🔧 VFX AAA plan — REWORK to owner's uniqueness law: no repeats, palette swaps ILLEGAL, unique per spell AND creature (VFX_AAA_PLAN amendment). OWNER RULING 2026-07-05: NO PURCHASES EVER — the ~$15 Pimen/Frostwindz proposal is DEAD; VFX pool depth comes from free packs (#101 scout) + ComfyUI generation on the owner's GPU (SDXL + Pixel Art XL, already proven for icons)
    - ✅ PROVEN: ComfyUI-generated, per-spell-UNIQUE VFX with a perfect-cutting pipeline
      (tools/assets/gridcut.py + rogue_vfx.py) — first full kit = rogue (6 sheets, #83). Each
      VFX is its own generated element + distinct motion model (NOT a recolour) → uniqueness law
      satisfied. Reusable for the other 6 classes' kits + creature VFX.
57. ⬜ Crafting ANIMATIONS from packs (stations + character craft-bob)
58. ✅ Spell/ability trainers (14 trainers, learn by level+gold, self-instanced panel) — BUILT 023d4b0
59. ✅ Spellbook UI (browsable + concrete tooltips) — BUILT fb79aa4
60. ✅ Achievement toast + panel — BUILT
### Zone production (61-66)
61. ✅ RAVEN HOLLOW REDO: all sitting-#1 town findings fixed (stalls, plaza fringe, orphan patches, grave clip, west road, SW clearing, gate lantern) — Council re-confirmation at next sitting
62. ✅ Batch C SHIPPED: North arm + Black Night capital (13 zones live) — rows of twelve, Thread filaments, snow tundra; Council sweep next sitting; catacombs-stone district detailing continues under Prime-Mandate loop
63. ✅ ALL 40 ZONES LIVE — Batches D-H → all 40 zones — **Batch D SHIPPED** (East arm: whisper_passes, eastern_ridges, BLESTEM capital — perpetual-dusk ambient lock, Black Spire, lamp-lit streets, Riddler's Quarter, Lower Market — lichenreach FIRST CAVE — underground ambient, biolume lichen — transcub_vale). 18 zones live. Engine adds: cave biome (dark ground/rock walls/no weather), rain-purge on hard transitions, DayNight underground+ambient_lock modes, tools/validate_travel.py (18 zones, all seams reciprocal). **Batch E SHIPPED** (South arm: bloodroad, basaltfang, SANGEROASA capital — THE FORGE THAT EATS: Debt Pit + forge district + killing floors + ambient-lock forge haze — the_gift red fields w/ childs_shoe vignettes, ashvents). 23 zones live. Engine adds: volcanic biome art (schwarnhild basalt + burnt trees + vents, credited), lava_vent/forge/pit/gift_field/brazier/cairn/signboard landmark types. **Batch F SHIPPED** (the two canon dungeon-caves: CHAMBER DEPTHS beneath Vetka — live transmission stones, thread web, the Courier's sealed satchel vignette — and THE GRAVE & BLOODSTONE PIT beneath Black Night — Lilith's tomb, converging threads, grave rings, raid-tier shells; cellar/grave stair entrances wired). 25 zones live. **BATCH G SHIPPED — ALL 40 ZONES LIVE (39 defs + town + wilderness).** Collector's Coast ×14 built (GREYHOLLOW drowned-ledger capital w/ Pit + clerk ring + ruled ivy blocks; THE ARCHIVE cold capital w/ ambient lock + colonnades; grey_piers ferry landing, canal_maze, drowned_quarter, morven_reach, salt_fens, dead_timber, ledger_roads 4-way hub, finalized_fields grave-grid, orange_fog (per-zone FOG color override), last_hearth SAFE hub, anchorfall, coldharbor_deep cave) + GREY FERRY (#75: riverfork.ferry_dock ↔ grey_piers.ferry_landing, era-crossing per council design). Engine: sea-edge bands, pier/boat/wreck/warehouse/crane/cargo/salt_pan/drowned_fence/ledger_tablet/lone_tree types, coast art (kimbul cobble/paved fills + minzinn sailboat/rowboat, credited). 39 zones ALL SEAMS RECIPROCAL. NEXT: WITCHBROOK POLISH LOOP (owner law: Witchbrook-level detail, polished BY FABLE) — sitting-3 confirmed fixes (road art, cold ambient bias, graves spacing, black_night buildout, threadlands webs) + coast Witchbrook pass + re-sweep
64. ✅ Sitting-#1 round-2 fixes complete (roads, ≡ artifact, keep-clear, stalls) — angel_wings quadrant findings folded into next sitting
65. ✅ Terrain edge-blend shader (renderfx_terrain_blend, opt-in only) - BUILT
66. 🔧 Prime-Mandate polish loop — SITTING #2 DONE (11 inspectors, 220 shots, 161 findings: town A- PASS, angel_wings F, blestem D-): root causes fixed — sweep-camera smoothing lag (~300px off-center, corrupted overlap analysis), camp composite (bedroll row read as graves, floating flame → stone-ring pit + fanned warm bedrolls), ice-pond spacing + footprint keep-clear (bush-on-pond), road keep-clear inflation (tree-on-kerbstones), thread filaments now anchored to posts, stall poles lengthened; GOLDEN steppe palette (canon) + North-arm densification (steppe/threadlands/gravemark +30 landmarks). Sitting #3 CONVENED (wf_4e2ced37-fd9: 16 inspectors + adversarial verify over 429-shot re-sweep). CAPITAL IDENTITY PASSES SHIPPED — canon-corrected: Angel Wings is NOT a white city (lore: poor/crowded/ordinary, mud+woodsmoke+thatch = strategic disguise) → +15 packed cottages, CHIMNEY-SMOKE particles at chimney mouths, Lead Vault lead-grey tint, orphanage yard, full-granary + burned-farmstead(lead box, scratch marks) vignettes; Blestem → black-basalt ground palette (per-def palette override) + maze keeps/kerb rows/lamps; Black Night → outskirt statues/rows/lamps/graves/camp. SITTING #3 ADJUDICATED (16 inspectors + adversarial verify, 429 shots; 51 verifiers died at session limit → completion is #106): town A- PASS again; confirmed systemics FIXED (ce29297): cold-zone ambient_bias (snow no longer flips beige between snowfalls), graves 48x58 spacing, threadlands +4 webs, BLACK NIGHT gate-to-gate roads + crossroads quarter. Remaining confirmed per-zone items + ROAD ART UPGRADE → #100
### World systems (67-76)
67. ✅ Drova-style visibility fog overlay (gated OFF default, RH_FOG) - BUILT
68. ✅ D2 occluder transparency (player-behind fade+restore, gated OFF) - BUILT
69. ✅ Cow-level-style secret (3 lore-accurate ritual secrets + reward portal) - BUILT
70. ✅ Resting (inn/hearth, well-rested XP buff via StatusSystem) — BUILT 9da4dc6
71. ✅ Factions + reputation (6 factions, 8 WoW tiers, emblems, rep gates) — BUILT 61ea165
72. ✅ Auction house + bank (listings, gold+item storage) — BUILT 7debfc4
73. ✅ Scarce-loot tuning pass (documented/reversible, loot_tables still valid) - BUILT
74. ✅ Dungeons & raids (10 dungeons + 3 raids, boss phase machines, enrage, telegraphs, weekly lockouts) — BUILT 418fdee
75. ✅ Grey Ferry travel link + fast-travel routes (fare/unlock gates, guarded map-change) - BUILT
76. ✅ Bestiary FRAMEWORK (63 signature creatures, 11 biomes, 7 families, unique debuffs, spawn tables, codex UI; 1500-sprite art pass later) - BUILT
### Quests & narrative expansion (77-81)
77. ✅ +1,007 lore-of-the-land quests SHIPPED — 1,090 total across 41 zones (real ids, validated, engine-registered). Toward 2,000.
78. ✅ Romance side quests SHIPPED — 71 quests / ~24 multi-stage arcs, 8 distinct dynamics (slow-burn/grief/rivalry/letters/quiet/duty/healing/joy), tasteful (no sexuality), real NPC targets.
79. ✅ Writers-council PRODUCTION SYSTEM SHIPPED — tools/studio/quest_pipeline.py (pools/validate/merge): model writes prose, code guarantees real ids. Authored the 1,000-quest wave.
80. ✅ RDR2-grade mysteries SHIPPED — the Bloodstone Underlanguage investigation chain (dust-lines->warm-slab->coppered-wells->the "resting"->the Pit, cross-zone) + 3 regional mystery chains, real culprits/twists.
81. ✅ Skyrim-vibe discovery quests SHIPPED — 40 standalone wanderer-find discoveries across zones (hermit shrines, abandoned camps w/ journals, graves to tend, moved border-stones), the "one more hill" feeling.
### Characters & audio expansion (82-88)
82. ✅ Druid CAT + BEAR + caster forms (reversible stat-profile swap + ability bar) - BUILT
83. ✅ Rogue rework (stealth/dagger-poison/vanish/assassinate 2.5x opener) - BUILT
    - ✅ ROGUE SPELL-KIT VFX (6 unique sheets, ComfyUI SDXL+PixelArtXL + authored motion,
      gothic venom/violet/steel): backstab, poison_blade, fan_of_knives, vanish, shadowstep,
      deathmark. Perfect-cut 96x96 grids (tools/assets/gridcut.py — every frame in its own
      centred cell, zero bleed, binary alpha; grid-overlay montages under
      _screens/rogue_kit/sheets/). Wired into FXLib (rogue_* ids) + verified in Godot
      (_screens/rogue_kit/godot/: showcase grid + 4 RH_CAST-on-scarecrow shots). Generator:
      tools/assets/rogue_vfx.py.
    - CHARACTER: kept the consistent szadi rogue (npc_male4 v3) — SDXL cannot hold cross-frame
      character identity (probe: _screens/rogue_kit/sheets/_char_probe.png); ComfyUI rogue art
      delivered as REFERENCE only (rogue_reference.png). Honest fallback per mission guidance.
    - ⬜ REMAINING: talent-tree/ability-system rework, stealth mechanic, assassinate execute logic.
84. ✅ D2-style class SELECT SCREEN (7 pedestals, animated hero, ability/lore panel, BLUEPRINT_84) - BUILT
85. ✅ Distinct voice per NPC DATA SHIPPED — data/voice_map.json assigns all 384 NPCs a role-appropriate voice archetype + per-npc pitch jitter; VoiceRegistry loads it (audio bake = separate local-TTS). Chronicler recast
86. ✅ Menu/UI sound manager (12 cues + aliases, 6-voice pool, guarded-silent, ui_sfx auto-wire) - BUILT
87. ✅ Sound Council audio-coverage registry (audits all cues, reports present vs MISSING - 17/58 present, gap list) - BUILT
88. ✅ NPC life layer (bark bubbles, chatter, friendships/rivalries, job routes, inn-rest; freed-safe poll) - BUILT
### Items & sprites (89-91)
89. ⬜ Replace "pygame-looking" sword sprites w/ real pack art; REAL hand animation on sheathing
90. ⬜ Sprite×item full animation test matrix (every item on every character)
91. ⬜ Scout assets fitting our characters EXACTLY with tons of animations (gauntlet-gated)
### Engineering mega-projects (92-97)
92. ✅ Owner Control Interface + Admin Panel (F2, 4 tabs WORLD/PLAYER/SYSTEMS/CONTENT, guarded do_action) - BUILT
93. ⬜ C++/native engine layer: level-design + studio-pipeline automation
94. ⬜ PROMPT-TO-GAME engine ("make me a 2D RPG about autumn" → builds on our engine)
95. 🔧 LOCAL STUDIO v1 SHIPPED (tools/studio/): Ollama+Qwen2.5-Coder-14B worker w/ 5 roles (quest/bark/def/item/qa-triage), style-bible priming + validators + retry; finetune/ QLoRA recipe on the project corpus (honest scope: specialist, not Fable-clone; no Claude-output training per ToS). ART (ComfyUI) + VOICE (Maya1) already local = full free studio. Remaining: owner installs Ollama, first batch run, adopt-if-better eval
96. ⬜ Corporation-of-bots departments; godot-optimization horde; 2D-pixel-design + Blizzard-audio/cinematics study hordes; playtest agents start-to-finish; bots w/ perfect navmesh + class rotations; race-vs-bots world-firsts; everyone starts from 0 on New World
97. ✅ Disk-space watcher (tools/ops/disk_watch.py: drive report + safe-category prune, dry-run default) - BUILT
98. ✅ SEAMLESS WORLD edge-streaming (full crossing, gated+change_map fallback) — BUILT (BLUEPRINT_98) 22cf6a1

99. ✅ COLLISION AUDIT: footprint colliders per prop class + pushable props — BUILT (BLUEPRINT_99, 60 types mapped) e58f0cf

### Session additions 2026-07-05 (100-108) — reconciliation sweep
100. 🔧 WITCHBROOK POLISH LOOP — **PAINTING PASS 1 SHIPPED: all 38 zone defs received Fable-authored lore sites (1 murder/crime scene + curiosity sites each; Last Hearth murder-free BY DESIGN; town/wilderness already dressed)** — murder_scene composite (stain/remains/drag-marks/dropped item); examples: grave-digger in his own grave (gravemark), forgehand's boot-prints ending at the Pit edge (sangeroasa), the salt-farmer white-on-white (salt_fens), the hungering who almost made it east (orange_fog), a body shelved and tagged (the_archive). **ROAD-ART UPGRADE SHIPPED** (perpendicular 2-wide stamping — vertical roads were 1-tile-wide, the sitting-3 'debug geometry' root cause; flush 2x2 diagonals + elbow pads; grass/pebble edge blending). REMAINING in loop: (owner law, FABLE-ONLY VISUAL: every zone hand-painted by Fable personally — lore landmarks, CURIOSITY SITES (>=2/zone), MURDER/CRIME SCENES (>=1/zone), all vignettes and visual passes; drivers/studio excluded from visuals): per-zone detail passes to Witchbrook density. Top items: ROAD ART UPGRADE (real path texture + corner/jog smoothing + grass edge-blending — sitting-3's #1 systemic defect), baked-snow ground evaluation (vs ambient-bias), coast detail pass (14 new zones), sitting-3 per-zone remainders (blestem ×5, lichenreach ×3 incl. cave-bright road, transcub ×4 incl. cross-shot prop stability, eastern_ridges ×4, black_night pale-green floating light at ~(6786,4486)), THEN full re-sweep + sitting #4
101. 🔧 GRAND ASSET SCOUT (owner: "incredibly vast variety of medieval assets to paint the levels"): 10 categories (castle/church/village/harbor/terrain-blends/creatures/NPCs/interiors/monuments/FX), VERIFIED-FREE license evidence + style gate; workflow script saved (wf_a889d7f0-2c4, 0 ran — re-run AFTER credit reset); downloads → Asset Gauntlet → zone painting. **2026-07-05 (Opus, #114):** `tools/assets/scout.py` built — live license-fetch + evidence + verdict + manifest (`_downloads/_assetlib/scout_manifest.json`). HONEST FINDING: free-scouting adds little beyond the ~20 owned packs (CC0/CC-BY anchors reconfirmed: Kenney Tiny Town CC0, OGA LPC Village Decorations CC-BY-SA; fresh candidates NEEDS_MANUAL). **Generation (#114) is the real library** — scout demoted to secondary per owner.
102. ✅ Grey Ferry Voyage Interlude (fog-crossing cinematic, CinematicSystem or self-contained overlay) - BUILT
103. ⬜ CAPITAL-UNIQUE ARCHITECTURE KITS: all 6 capitals currently reuse the same 8 rustic house sprites — each needs a distinct civic kit (Greyhollow drowned-ledger stone, Archive filing halls, Black Night catacomb facades, Blestem black-iron, Sangeroasa forge-works, Angel Wings stays rustic per canon) — from #101 scout or ComfyUI gen; Witchbrook-bar dependency
104. ⬜ CREATURE PACK INTEGRATION + THE WEREWOLF GAP: turn downloaded packs (lucifer cultist/possessed, craftpix vampires, admurin) into REAL Enemy types replacing reskins ("Strigoi Enforcer"=orc, "Varcolac"=wolf); Varcolaci need TRUE werewolf sprites (2026-07-11 SCOUT FOUND: LPC Wolfman, ACCEPT verdict, in _downloads/scout_2026_07 — wire it; previous note: no free top-down pack found → ComfyUI 3D→2D pipeline); feeds #76
105. 🔧 LOCAL STUDIO OPERATIONS (credit law): v1 shipped (#95) — OWNER: install Ollama + pull qwen2.5-coder:14b; then first free batches (50 Coast quests, 200 barks, sparse-zone densification drafts, item tables) → Fable review/integration gates; QLoRA eval adopt-if-better
106. ⬜ SITTING #3 COMPLETION: resume the 51 dead verifiers from cache (wf_4e2ced37-fd9) AFTER reset; adjudicate the unverified findings for steppe/gravemark/whisper/bloodroad/basaltfang/ashvents/gift/sangeroasa/angel_wings
107. ✅ Coast content wave: all 14 Collector's-Coast zones covered by the NPC cast roster - BUILT
108b. ✅ DRIVER PROTOCOL (CLAUDE.md in repo root): any Claude session opened here — Opus 4.8 included — auto-loads the full driving manual (read order, driver loop, local-studio commands, verification hooks, mapped potholes, quality gates, escalation limits). The driver conducts; the pipelines + validators hold the Fable bar.
108. ✅ TASK DIVISION & LANES (design/TASK_DIVISION.md, owner directive): Fable = engine/canon/balance/QA (~24 tasks); spec-complete implementation lane (~35) runs LOCAL STUDIO first (free), billed Opus 4.8 only post-reset for tasks failing the local QA gate; every handoff has doc + acceptance criteria + Fable review gate

109. 🔧 THE PAINTER PROGRAM (owner priority: the studio's strongest target = flawless level painting): design/LEVEL_PAINTING_BIBLE.md (Fable's doctrine: the read/composition/ground/light/story/sourcing/verification) + level_painter role primed with it + HARD WALLS (density floor 16-24, footprint spacing, cluster cohesion, biome-legality — no forges in bogs, repetition law — one-of-everything = prop salad, ≥2 curiosity + 1 murder vignettes) + inspection mode (rejected drafts still render, labeled) + tools/studio/render_draft.py (draft JSON → temporary studio_canvas zone → real-engine boot → screenshots). EXAM IN PROGRESS: "create Raven Hollow from scratch" on qwen3:30b-a3b (/no_think after thinking-mode timeout) with qwen3:14b backup → owner reviews the pictures. Verdicts so far: 14B quests ~90% of bar; 14B painting REJECTED by walls (prop salad, biome illegals) — painting stays Fable's hand (visual law) with machine drafts under art direction
110. 🔧 THE PAINTER PROGRAM v2 (BLUEPRINT_110_PAINTER_PROGRAM.md): FABLE PATTERN LIBRARY (machine composes Fable's own extracted cluster geometry — quality floor = Fable by construction) + staged painter (model=semantics, code=geometry) + fine-tune + vision probe + exam protocol. OPUS 4.8 EXECUTING (owner-authorized, Max plan). Old fine-tune scope folded in — THE SPECIALIST FINE-TUNE (QLoRA on the 5070 Ti): teach a local model THIS project's conventions from Fable's own shipped work — dataset builder DONE (119 instruction pairs harvested: 40 zone layouts, doc sections, VO lines; grows as the game grows), Unsloth 4-bit recipe committed (r=16, ~1-3h for 7B), GGUF→Ollama export, adopt-if-better eval vs studio validators first-try pass-rate. HONESTY LINE (standing): no local model equals Fable's general intelligence; no training on Claude transcripts (ToS); the goal is a professional SPECIALIST on our narrow roles

111. ⬜ FULL ANIMATION STATES LAW (owner, 2026-07-05): EVERY sprite uses EVERY animation its sheet offers — player (all classes), bosses, enemies, fauna: idle, walk/run, ATTACK, HURT, DEATH, cast where applicable. Audit matrix per entity (extends #90); combat fauna already have idle/run/death; enemies must gain attack/hurt states from their Pixel-Crawler rows; ambient critters gain death anims when they enter combat scope (#76); entities whose sheets LACK states get completed via free scout (#101) or ComfyUI sheet-gen. Acceptance: automated animation-matrix capture shows every state playing for every entity. FIXED TODAY under this law: fauna scale-to-world (boar 0.60, wolf 0.72, bear 0.85, fox 0.55, deer 0.62) + palette harmonization (owner wilderness QA: 'seems like a different game' — LPC 64px art in a 32px world)

112. 🔧 PER-SPRITE ANIMATION VERIFICATION + THE SCOUT NETWORK + INTERPRETER HORDE (owner mandate, 2026-07-05): **2026-07-05 (Opus, #114): INTERPRETER HORDE BUILT** — `tools/assets/interpret.py`: machine geometry manifest (grid/rows/facing/feet-line/bounds) + montage + the SPOTLESS cleanliness gate (binary-alpha/no-halo, no-uncut-bg, one-sprite-per-cell via connected-component split, alpha-trim, quantize, gothic-palette-compat) — nothing enters `library.json` without passing + a montage eyeball. Applied to all generated assets. Original mandate continues: NO generic/shared animations — every sprite's every animation is its own, and EVERY FRAME of EVERY sheet is pixel-verified before use: facing direction, feet line, frame bounds, per-frame offsets (the wild_geometry.json PIL-verification pattern becomes MANDATORY for all sheets). Massive asset SCOUTING NETWORK (#101 expansion: continuous hunts per need category) feeding an ASSET INTERPRETER HORDE (local studio + Opus jobs): each incoming sheet gets a machine-generated geometry manifest (grid, rows, facings, anchors) + montage that a reviewer eyeballs before integration. FIRST CATCH under this law: rabbit frames faced LEFT while annotated RIGHT → ran left with right-facing animation (owner report; pixel-proven, fixed). Fox/deer verified correct. Bird rows queued for verification.

113. 🔧 THE OPUS VISION-LOOP PAINTER (BLUEPRINT_113, owner: a modality that paints at the Fable bar): TWO TIERS. Tier 1 = Opus 4.8 IS the painter in a draft->render->SEE(own screenshots)->critique->revise loop (Fable's own method; Opus has the taste + vision a 14B lacks) — Fable-level, costs Opus tokens/Max plan, for CAPITALS + hero towns. Tier 2 = local pattern-library+fine-tune+flywheel (#110), free/asymptotic, for filler. Routing rule -> TASK_DIVISION. Opus builder ordered to build opus_paint_loop.py + demo on bog+RavenHollow. THE painting answer.

114. 🔧 THE 150K ASSET LIBRARY (owner mandate — MANDATORY total 150,000 spotless assets, adapted to OUR gothic-medieval world, NOT school/beach). Category quotas (scaled to 150k; animation frames + variant combos carry bulk): character sprites (player+NPC) ~8k, clothing/hair/accessories ~25k, furniture/decor ~15k, environment tiles (town/forest/cave/coast/dungeon/capital/farmland) ~20k, plants/crops/items/magic objects ~15k, UI/spell/inventory icons ~5k, ANIMATION FRAMES (each frame=1 asset, via video-gen) ~62k. Architecture: PERSISTENT GENERATION QUEUE/daemon (category quotas, spotless-gate per asset — bg-transparent + one-per-cell + despeckle + dedupe, progress manifest toward 150k), runs 24/7 on the 5070 Ti. HONEST SCALE: ~6-10 weeks continuous GPU. Gate: EXTENSIVE generator stress-test FIRST (throughput assets/hr, reject-rate, dedup, quality-at-volume) before committing the marathon. ComfyUI still-gen (props/tiles) + video-gen (animations, sorceress.games flow). Opus builds+runs; Fable verifies samples. VOCABULARY: design/ASSET_CATALOG_PROMPT.md = the lore/palette/zone-tuned prompt that generates the 150k asset-name catalog (JSONL: category/subcategory/zone_fit/name/descriptor) feeding queue.py — run in resumable per-category batches on ChatGPT or the local model.
    - **DELIVERED v1 (Opus 4.8, 2026-07-05):** full pipeline built + proven, $0 on the 5070 Ti. `tools/assets/`: **generate.py** (SDXL+Pixel-Art-XL still lane + Wan 2.2 TI2V img2vid animated lane), **interpret.py** (#112 SPOTLESS cleaner/verifier: robust cutout, connected-component ONE-SPRITE-PER-CELL split, defringe, quantize+gothic-cohesion, binary-alpha no-halo, bg-reject guard, montage, library index), **asset_specs.py**, **scout.py** (secondary — free-scouting yields little; generation is the win), **queue.py** (PERSISTENT daemon: 20 gothic category quotas summing to EXACTLY 150,000, batch-gen VRAM fill, perceptual-hash dedup, **auto-prune raws**, **D:\raven hollow\assetlib** storage, 20 GB disk guard) + **run_queue_supervisor.bat**. Video-gen model = **Wan 2.2 TI2V-5B** (installed, fits 16 GB, proven-consistent — sorceress.games flow replicated free; LEARNED_PRINCIPLES.md). Sample library = **182 verified spotless sprites** (prop/building/harbor/monument/nature + 2 animated creatures walk×8, 8/8 clean) covering all 5 ColorRect composites. Catalog: `design/ASSET_LIBRARY.md` (real counts + stress numbers + wiring plan). Marathon queue is READY to run for weeks toward 150k. ASSETS ORIGINAL (generated CC0/owner-owned) — never copied. Zone wiring = Fable (visual law).

115. 🔧 THE VISION GAUNTLET + GENERATION COUNCIL (owner mandate): (a) council of independent AI vision inspectors (different lenses: pixel-grid, palette, style, perspective) gates EVERY asset — must agree UNANIMOUSLY; non-pixel-art = DIRECT REJECT (mandatory), off-style/ambience = reject (mandatory); rejections logged w/ reason. (b) GENERATION COUNCIL decides per asset: picture-gen vs video-gen + WHICH model, from a real scorecard. (c) ALL MODELS TESTED — same subject through every free 16GB-feasible model (SDXL±LoRA, SD1.5, Wan2.2 still+video, AnimateDiff, LTX, CogVideoX-2B, Flux-schnell, all ComfyUI checkpoints) → labeled MODEL-MATRIX montage for the owner. Opus building (max effort). MAX-EFFORT LAW extended: ALL local AI (Ollama/ComfyUI/vision/studio/flywheel) always runs highest-quality settings — no turbo shortcuts on final assets, never skip a gate.
    - **DELIVERED v1 (Opus 4.8, 2026-07-05):** (a) `tools/assets/gauntlet.py` — unanimous multi-lens gate wired as the FINAL gate in generate.py + queue.py: heuristic lenses (pixel_art flat-run, gothic palette, muted ambience) always on (6ms/asset) + local VLM `llava:7b` lenses (vlm_style, vlm_perspective) at ~1.3s/asset (toggle RH_GAUNTLET_VLM). Real rejections logged (mushy cattail_reeds killed, flat-run 0.38). (b) `tools/assets/council.py` — routing: props/buildings→SDXL+PixelArtXL still lane, creatures/vfx→Wan2.2 video lane, model from the live scorecard. (c) `tools/assets/model_matrix.py` → `_MODEL_MATRIX.png` — same gothic-market-stall subject through EVERY installed model: SDXL+PixelArtXL (winner, crispest+fast), SDXL-base, FLUX+2DHD, FLUX+topdown (best green-screen keying), Wan2.2 video (torch x5, animates) — ALL gauntlet-pass; scorecard = model_matrix_scores.json. HONEST SKIPS (not installed / need multi-GB fetch + node install + restart): SD1.5, AnimateDiff, LTX-Video, CogVideoX-2B, Flux-schnell; hunyuan3d = image→3D not 2D. Those 3 video installs are the documented lowest-priority follow-on (owner: after the cut/Gauntlet checkpoint).

### ⏰ FABLE SUNSET PLAN (Fable 5 disabled JULY 7 — 2 days; owner directive: milk Fable maximally)
What ONLY Fable should do before the 7th, in strict priority order:
S1. 🔧 **ARCHITECTURE BLUEPRINTS** — SHIPPED: BLUEPRINT_98_SEAMLESS_WORLD.md, BLUEPRINT_27_QUEST_ENGINE.md, BLUEPRINT_33_COMBAT_RETUNE.md, BLUEPRINT_99_COLLISION_PHYSICS.md (each: architecture, exact integration points, data schemas, potholes, Opus build order, acceptance tests). **S1 COMPLETE** — all nine blueprints shipped: +BLUEPRINT_74_DUNGEONS_RAIDS.md (10 dungeons + 3 raids w/ bosses; Bloodstone Pit finale w/ transmit-vs-receive mid-fight) +BLUEPRINT_SUNSET_FINAL.md (#67 Drova fog v1 radial/v2 LOS, #68 D2 transparency w/ tall-tag + hysteresis, #50 Great Battle director + staging notes, #51 cinematics in-world player + 6 slide-films via ComfyUI+Maya1, #53 MusicDirector 4-stem adaptive layers + motif law + audio_qa motif check). Every mega-project is now Opus-executable — (cheapest, highest leverage — Fable designs, Opus builds after the 7th):
    full build-ready blueprints for #98 SEAMLESS WORLD, #99+#52 COLLISION/PHYSICS, #33 COMBAT RETUNE,
    #27 QUEST ENGINE, #67 DROVA FOG + #68 D2 TRANSPARENCY shaders, #74 dungeon/raid layouts + boss
    designs, #50 GREAT BATTLE staging, #51 cinematics shot-lists, #53 MusicDirector spec — each with
    file-level integration points, data schemas, acceptance tests, and pothole warnings.
S2. **FINAL FABLE PAINT PASSES** (the visual law becomes impossible after the 7th): coast detail pass +
    capital one-image compositions + sitting #4 verdicts — as budget allows after S1.
S3. **SUCCESSION**: after July 7 the driver protocol (CLAUDE.md) stands with Opus 4.8 as chief driver;
    the Fable-Only Visual Law transfers to "Bible + walls + fine-tuned painter drafts + owner's eye";
    the Painting Bible, gotcha ledger, and these blueprints ARE Fable's hand, encoded.
If the owner buys the +$100: ~40% Fable (S1+S2 complete), ~60% Opus implementation wave run NOW so
Fable can still review it before shutoff. Without the purchase: S1 only, inside the remaining quota.

### Session additions 2026-07-06 (116-122) — the honest asset-generation reckoning
**THE CORE FINDING (owner + Opus, hard-won): local free AI has a clean capability split. STOP fighting it; route to it.**
- ✅ **Static world art = free AI's sweet spot.** Buildings, terrain, props, ruins, foliage, walls, monuments — SDXL+Pixel-Art-XL txt2img makes them moody, consistent, game-ready, endlessly, $0. Proof: 8 dark-fantasy buildings → `_screens/village_showcase.png` (tower-house, thatched cottage, gothic chapel, forge asset-sheet, huts, watchtower, kiln — all clean). This IS the 150k-library path (#114).
- ✅ **Characters = the owner's OWN reference + img2img.** Recipe (PROVEN on the rogue): SDXL base + Pixel-Art-XL LoRA, load the reference image as init, img2img @ **denoise 0.5** (32 steps, cfg 7, dpmpp_2m karras). Reproduces the character faithfully (`rh_rogue_gen_00004` ≈ `rogue_reference.png`). **BLIND generation fails; reference-guided succeeds** — this reverses the #83 "SDXL can't hold identity" note: it can, WHEN started from a reference. (Updates #83.)
- 🔧 **Animation / hero VFX = the wall, DELIBERATELY PARKED.** Local AI i2v (Wan) = soft mush; particle-bake = spiky/urchin (owner-rejected); AnimateDiff not yet proven. Honest verdict re-confirmed 4 ways. INTERIM: free CC0 packs (Foozle etc.) + Godot GPUParticles2D for VFX; solve the animation question later, separately, with a clear head — NOT under budget pressure. (Reframes #111/#84/#113.)
- 💰 **BUDGET LAW HARDENED (owner overspent ~$300–400 on credits, real hardship): ZERO further purchases. Retro Diffusion (Astropulse) is PAID — banned.** What we used (`pixel-art-xl` LoRA) IS Astropulse's *free* model, the free ancestor of Retro Diffusion; RD is the paid upgrade (~last-10% polish only). Free local on the 5070 Ti makes the whole world for $0 — this is sufficient. Protect the owner's food money; never suggest a purchase.

116. 🔧 **THE STATIC LIBRARY MARATHON (the #114 engine, now correctly scoped to STATIC).** `tools/assets/queue.py` (150k quotas across 20 gothic categories: buildings 12k / nature 12k / harbor 9k / fences_walls 6k / ruins / graveyard / monuments / …) generates → razor-cuts → gauntlet-gates → perceptual-dedups → stores spotless PNGs to `D:/raven_assets/<cat>/`, deletes raws, 20GB disk-guard. VERIFIED running via `--burst`. OWNER launches `--target 150000` (run_queue_supervisor.bat) for the weeks-long marathon when ready. This is the real, free, massive library.
117. ⬜ **CHARACTER img2img PIPELINE:** script the proven recipe as `tools/assets/img2img_from_ref.py <reference.png>` → clean transparent sprite; run across ALL class references (rogue done; warrior/mage/hunter/paladin/druid/necromancer refs in `assets/art/characters_v2/`). Free, faithful.
118. ✅ **FIREBALL RESOLVED:** `assets/fx/fireball/` = Foozle CC0 packed game-ready (validated `.tres`, drop-in) + `assets/fx/fireball_seed4/` = owner-approved diffusion still (#00004) pixel-perfected + procedural-flicker-animated (gate PASS 89.8). Lesson: `anim_finish` degrades already-clean art (centers projectile motion) — pack clean sprites RAW.
119. ✅ **VFX GATE (extends #115):** `tools/assets/gauntlet.py run_vfx_gauntlet()` + `vfx_bar.json` (calibrated off Foozle CC0 control) + `test_vfx_gate.py` (PASS Foozle / REJECT AI-mush). Emissive exemption (fire is vivid — the muted-gothic ambience ceiling was inverting-wrong for VFX) + temporal/mush lenses (partial-alpha, off-ramp ΔE2000, drift, palette-Jaccard) + reference control. Committed.
120. ✅ **VFX GENERATION STANDARD:** `design/VFX_PIPELINE.md` (Opus research fleet + adversarial verify): measurable bar, method routing, SOP, quality gate, flywheel, bake-off. Honest conclusion baked in: procedural/free-pack/hand-pixel beat AI for hero VFX; AI for bulk/generic only.
121. ⬜ **MODEL VERDICTS (extends #115c):** Pixel Art Sprite Diffusion (Onodofthenorth SD1.5, sprite-sheet-trained) DOWNLOADED + TESTED on rogue → **WORSE than SDXL+PixelArtXL** (tiny generic sprites txt2img; muddy img2img). AnimateDiff v3 (mm+adapter+sparsectrl) + Wan2.2-I2V-A14B-GGUF (Q4, both experts) downloaded to D: — for the parked animation problem. Fleet on D:\ComfyUI-models (extra_model_paths.yaml).
122. 🔧 **C: DRIVE RELIEF (owner: C: at 94%):** models routed to D:\ComfyUI-models already; STILL TODO — migrate `_downloads` + stray AI models off C:, symlink, free the drive.

### Session additions 2026-07-11 (123) — the Fable AAA world pass
123. 🔧 **FABLE AAA WORLD PASS (owner sitting 2026-07-11, Fable 5 driving):**
   - ✅ STYLE ANCHOR LAW: game style = Necromancer sheet (lab/input_necromancer_ref.png); design/STYLE_ANCHOR.md (sampled palette + rules); MANDATES entry; generate.py STYLE prompt retuned to anchor palette. Library target **30,000 assets total**.
   - ✅ ENGINE PAINT PASS (zone_builder): macro tonal ground patches (cool on cold, earth/moss on warm) + micro decals 2x (110k px²/decal) + road biome tint & wheel-wear stains + packed-sheet super-grid breaker (off-lattice block stamps) + generic `deco` landmark type (any style-gated PNG hand-placeable).
   - ✅ FABLE HAND PASS 2: 1,220 hand-authored deco placements across all 39 zones + iron_vein pilot (story clusters: tavern yards, work sites, fisher hamlets, shrine stops, watch points, curiosity rings, grave patches, harbor rows, chapel grounds; biome-legal pools; scratchpad/fable_pass2.py generator = Fable specs + code geometry). Seams re-validated PASS. Full 41-map 4K re-sweep shot + eyeballed (iron_vein, vetka, black_night, gravemark, angel_wings).
   - ✅ **#29 TRULY COMPLETE — zone NPC spawner:** the 384-NPC cast was announced but never instanced in world zones. Now: `_cast_anchors()` (doorsteps/camps/wells/waystations/deco buildings) + `main._spawn_zone_cast()` — every zone physically populated, NPCs anchored to life, verified on-screen (vetka doorstep NPCs w/ markers).
   - ✅ LOST ASSETS RESTORED: `_downloads/wilderness` fauna + gate sheets re-downloaded from originals (wolf/boar/bear/fox/deer/bunny/bird/castle2), PIL-verified vs hardcoded rects, gate crops pixel-proven identical; assets/art/wilderness/CREDITS_WILD.txt written (CC-BY/SA obligations).
   - ✅ QA harness: RH_NOBANNER now gates the narrator parchment toast; tools/aaa_oneshots.sh = per-zone fit-zoom 4K one-shot sweep.
   - ✅ ACADEMY: 7-topic design-study fleet distilled → design/LEARNED_PRINCIPLES_DRAFT_2026-07-11.md (review-gate pending before Bible merge).
   - 🔧 30k GENERATION QUEUE running (run_queue_30k.bat detached, ComfyUI up). 
   - 🔧 GRAND SCOUT round 2 DOWNLOADED (45 agents): Mage City Arcanos CC0, Castle Tiles CC-BY, Hyptosis batches, Szadi Rogue Fantasy Catacombs + Houses Pack + FL Houses Demo (free licenses verified, evidence quoted), LPC grave markers, church/cemetery/crypt sets + more → `_downloads/scout_2026_07/` w/ ATTRIBUTION files. Style-assess stage died at session limit — resume wf_6b752a35-f17 after reset; then Gauntlet + extraction + capital kit wiring (#103).
   - ⬜ NEXT: swarm re-inspection of post-pass shots (resume wf_6ce1fc13-5b2 after reset); capital district buildouts from scout kits; per-zone one-image compositions; cave glow passes; road-art v2 from scout terrain; LEARNED_PRINCIPLES review-gate.
   - SCRIPT ERROR noted during windowed boots: "Trying to assign invalid previously freed instance" ×2 (pre-existing?, non-fatal, zone still renders + screenshots) — triage queued.

### Session additions 2026-07-11 PM (124) — pipeline order
124. 🔧 **GENERATE-FIRST LAW (owner):** the 30k library completes BEFORE the deep paint push.
   Queue at 4,534 (~280/hr on the 5070 Ti) — honest ETA to 30k: ~4 days continuous GPU.
   Supervisor: tools/assets/run_queue_30k.bat (detached, restarts on crash; ComfyUI must be up).
   While it grinds: shopping fleet (wf_5a6b63c0-8aa) surveys all 41 zones -> design/PAINT_PROGRAM_SHOPPING.md
   (per-category demand + lore-flavored generation descriptors + story-site list). Paint phase executes it
   on the full library: TONS of assets per level, hand-placed (visual law), Witchbrook density, anchor palette.
   Interim waves 3-4 (55 assets, 107 placements) stay; no further deep painting until library done.

### Session additions 2026-07-12 (125) — the free-assets reckoning
125. 🔧 **FREE-ASSETS-ONLY ERA (owner):** generated world/UI art REJECTED + retired; generation queue dead.
   Executed: 1,306 world decos + all UI swapped to human-made free art (Szadi/Cainos/LPC freekit/church kit/coast);
   town reverted to v1 art; Shikashi microbar; thematic class spell icons (owner-permitted generation, concrete
   subjects + per-class palettes, 54 shipped). MASS LIBRARY: 153,319 verified-free files downloaded
   (design/MASS_DOWNLOAD_2026_07.md; Kenney CC0, LPC bundles incl. Universal LPC spritesheet, DungeonCrawl CC0,
   itch free, game-icons.net) -> _downloads/mass_2026_07/. NEXT: extraction waves from the mass library
   (Fantasy UI Borders for panels, LPC buildings/terrain, DungeonCrawl creature/props), interim placeholder
   replacements (towers, harbor smalls), zone-by-zone Witchbrook densification with FREE art only.

126. EXTRACTION WAVES 2 (2026-07-12, Fable, commits through 774a35e) — DONE:
   castle kit v2 (clean composites: gothic cathedral tower per capital, cone-roof round tower,
   recolored square tower, gatehouse; 13 watchtower sites promoted off house_06); LPC dead-tree
   variety (deadforest/bog tree sets); giant stitched stump (stump=clearcut scatter, trunk_hollow);
   19-marker LPC grave pool replaces two-stone loop; PHYSICS PROP ART WIRED (placeholder Polygon2D
   quads killed in all 39 zone spawn rings); cargo/hook_crate/ledger_tablet ColorRects -> Szadi/Cainos
   sprites; 31 mount icons + 6 faction emblems (game-icons CC-BY, credited; stable + reputation UI
   render them; RH_PANEL=reputation hook). Werewolf in-world proof shot landed (bloodroad).
   NEXT: game-icons item-family icons, LPC Terrains v7 autotile road v3, harbor smalls, per-zone
   Witchbrook densification (the standing core mission).

127. SITTING #6 + SYSTEMIC FIX WAVE (2026-07-12 evening, commits -> 6325507) — IN PROGRESS:
   Archive design/SITTING_6_FREE_WORLD.md (29 CRIT / 84 MAJ / 47 MIN confirmed, adversarial verify;
   2 verify batches lost to session limits: iron_vein/last_hearth/ledger_roads + famine/finalized/gravemark).
   FIXED: border-forest ring (spr.position never set — whole ring stacked at origin = the 'corner tree'
   in 10+ zones; ring restored in all 39), boot_prints ghost-fence -> real heel+toe tracks, lamp_post
   baked grass bar -> lit-lantern street lamp, RIVER SKIN v2 (water-textured Line2D + brightened tint)
   + STONE BRIDGES at every road x river crossing + river keep-clear (no bushes on banks), rowboat
   4-sheet split + water keyed, transcub road re-path + gift-field grown, gravemark road extended,
   wilderness gate wall cut buried, sea v2 verified at grey_piers + drowned estuary.
   REMAINING from sitting-6: lichenreach dot-grid + white framed-box sprite + oob boulder; orange_fog
   cyan thread_lines read as debug; morven river/band junction; riverfork orphan rect decals + sailboat
   fringe (hand pass); wilderness slab-grid path network overhaul; per-zone dead-zone densification
   (bloodroad S half, eastern_ridges NW, whisper_passes, salt_fens E/S, canal_maze, listening_steppe...);
   zone-identity passes DONE: orange_fog/salt_fens/drowned_quarter weather tables, eastern_ridges rock spines.
   DEAD-ZONE DENSIFICATION DONE (2026-07-12 late): wilderness street-grid -> winding forest trails;
   eastern_ridges NW (+13); bloodroad south (+12); whisper_passes spread (+13); salt_fens E/S (+10);
   canal_maze (+10). morven keep wings differentiated + river/roads re-pathed. thread_lines glow.
   CONFIRMATION SITTING #7 (16 re-swept fixed zones): 11 CLEAN / 4 MINOR / 1 broken. Fixed the 3 real
   ones: transcub gift_field grown 4x2->12x7+band+dressing; eastern_ridges new ridge_wall landmark
   (scaled boulder spines, 4 diagonals); orange_fog permanent fog via new def "ambient" flag +
   _build_ambient (static tint + drifting haze, survives clear weather roll) — extended to salt_fens
   + the_gift. sailboat water fringe hue-keyed. canal crossings confirmed already bridged.
   #127 effectively DONE. Remaining = optional prefab-variety deepening + a periodic fresh sitting.
   Gallery artifact (all 41 zones + UI): https://claude.ai/code/artifact/b3120f8a-ef3a-427f-af38-f3d91ccb8682

### Session additions 2026-09-12 (128) — Steam-readiness audit + the painted-ground pilot
128. 🔧 **PAINTED GROUND — Raven Hollow pilot (Fable, 2026-09-12).** Steam audit verdict (207 fresh
   shots over all 41 zones + 14 inspector agents): the world's ceiling is the ground pipeline, not the
   props — every zone is ONE block-tiled sheet (wallpaper repeat at play zoom) + polyline slab roads
   (read as debug strips) + RNG scatter; capitals read as confetti hamlets on a flat plane; only the
   hand-built town/wilderness approached store-shot quality. Same audit: 1,432 "Resource file not
   found" errors on a clean clone (wolf/boar sheets live in gitignored _downloads/wilderness), 40s rule
   FAILS in ashvents/ledger_roads/listening_steppe/the_gift/transcub_vale, no Steam preset/Steamworks/
   controller/localization/credits screen. Audit shots: _screens/audit (Desktop copy), contact sheets
   _screens/audit_sheets.
   SHIPPED: `scripts/terrain_painter.gd` — corner-matched (dual-grid) autotiler over LPC Terrains v7
   (`data/lpc_terrain_v7.json` from `tools/terrain/lpc_terrain_index.py`; 496 corner-coded tiles, 18
   transition pairs; grass-keyed overlay sheet so cobble/soil edges sit on dirt). Authors paint MATERIALS
   on a vertex canvas (bands/ellipses/rects with value-noise rims); sanitize pass bridges Water->Shallows
   and drops unsupported neighbours. TOWN REPAINTED with it (`_build_ground_painted`): grass hub tinted to
   the anchor palette, worn dirt lanes with drift (no rulers), trampled yards at every door/stall/forge,
   cobble plaza + inn forecourt + forge floor on the overlay, soil garden + farm field, a pond with
   shallows (+ bank collider), legacy slab road to the gate disabled (main.gd add_gate paint_road=false).
   All prop/grave/tree placements byte-identical (legacy ground builder still burns the same RNG draws).
   Verified: smoke boots zero script errors; shots `_screens/town_v2/` (before/after: before_after_plaza.png).
   **POLISH PASS SHIPPED (same day):** ONE cohesive kit — Szadi props on Szadi houses, Cainos stone,
   LPC fences/graves/lanterns, LPC farming crops + reeds (tools/assets/extract_town_kit.py -> assets/art/
   world/town/). Szadi thatch awnings replace the LPC candy-stripe stalls; cottage yards (barrels, benches,
   woodpiles, ivy, a washing line); fenced farm field with 33 crop sprites + fenced kitchen garden; orchard
   thinned to 2x2 with ladder/baskets; pond bank reeds/rocks/bucket; woodcutter's yard behind the inn;
   fenced hay paddock NE; roadside saint by the gate road; old well ring north of the graveyard (curiosity
   site); copses + boulders on the two empty lawns; wood-gatherer clutter clustered; chimney smoke (inn x2,
   smithy); door lights on every house; border ring dead-sapling rate 18% -> 6%. QA: new `scripts/
   town_audit.gd` + `RH_PROPAUDIT=1` hook (footprint STACK / IN_BLDG / NPC_IN report) — final run: 0 real
   stacks (only the gate lantern on its post + the inn's own sign/lanterns), 0 NPCs in props. 20-screen
   play-zoom sweep eyeballed (`_screens/town_sweep/sheet_*.png`).
   SITTING (4 inspectors + adversarial verify over the 20-screen sweep, 20 confirmed findings, 19 fixed):
   graveyard lane now enters the fence gap; wolf statue off the open grave; graveyard fence stops at the
   merchant house instead of running under its roof; inn barrels/bench/firewood owned by the walls; crate
   out of the forge fire; ladder leans into an orchard tree; field cut to two rows so its south rail clears
   the border canopies; barn stores off the fence line + wider door gap for the doorstep NPC; reeds with
   feet in the shallows, toned; Szadi 3/4 well replaces the top-down disc at the terminus; saint bedded on
   cobble; doubled lamp removed; NE meadow gets a travellers' camp (fire + log seats) and the paddock a
   trough + hay cart; smoke moved onto the smithy chimney cap, round puffs. NOT fixed (deferred): gate
   wall's repeated battlement caps (GateBuilder wall tiles need a body tile) — #128b.
   NEXT (in order): (a) owner eye on the town at play zoom; (b) port the painter into zone_builder as the
   per-zone ground pass (biome material sets: bog Mud/Grass_Dark/Water_Green, tundra Snow/Ice, volcanic
   Rock_Black/Lava, coast Sand/Shallows/Water) replacing block-tiled sheets + slab roads — the single
   highest-leverage fix for all 39 zones; (c) town dressing pass (fences/hedges/reeds at the pond, lamp
   variety, NE quadrant anchor); (d) wilderness ground repaint; (e) Steam engineering blockers (ship the
   fauna sheets inside assets/, Steam export preset, credits screen, controller map).

### Session additions 2026-09-13 (129) — RAVEN HOLLOW CITY
129. 🔧 **RAVEN HOLLOW CITY (owner, 2026-09-13): the starting town of every class grows into a
   Stormwind-scale walled city on the same map.** Design: design/RAVEN_HOLLOW_CITY.md (map 224x160,
   nine districts, canals + bridges, river + harbor, keep in the north wall, east gate to the
   Emberfall Road moved to (6968,2600); the polished village stays byte-identical as district 1).
   Owner references: isometric AI concepts (mood only) + a 16px market-town kit (structure only —
   wrong density for our 32px anchor). Stages S1 skeleton → S2 districts → S3 life/polish → S4
   systems. Asset scout for the city kit: _downloads/scout_2026_09 (verified-free, license-quoted)
   + the LPC bundles already in _downloads/mass_2026_07 (Victorian buildings, roofs, windows/doors,
   castle mega pack, farm animals, cats/dogs, birds, trees). Style gate = Fable's eye on montages.
   **S1 SKELETON SHIPPED (2026-09-13):** map 224x160 (village byte-identical as district 1, its
   forest ring retired — the wall is the edge); `scripts/town_city.gd` (TownCity): outer wall ring
   (LPC castle mega pack dark crops via tools/assets/extract_castle_kit.py → assets/art/world/castle),
   corner round towers with cone roofs, interval towers, the EAST GATE in the south wall (travel point
   MapRegistry.TOWN_EAST_GATE → (6600,5050)), the Vigil Keep compound (courtyard, gate, 2-row keep
   block between double-height towers), the cathedral (3-row nave, gothic towers on stone bases, tall
   spires) on its square with the Vigil statue, canal A (E-W) + canal B (N-S) with Stone_Tan quays,
   solid plank bridges (2 decks, railings) at every crossing, the river along the south with the
   harbor quay, three piers and boats, Trade Square (fountain, 8 lamps, benches), old-town + east-ward
   squares with wells, cobbled main street/avenues/old-town grid, field lanes. Streets never float over
   water (overlay cleared where the base is water). Audit: 0 real stacks (masonry overlaps excluded).
   Shots: _screens/city/s1_map_4k.png + keep/cathedral/bridges/gate/harbor close-ups.
   LOCAL SCOUT RESULT (4 agents): LPC Victorian Buildings + Victorian Town Decorations + Roofs v2 +
   Windows/Doors + Castle Mega Pack + Farm Animals/Cats-Dogs/Birds/Trees all ACCEPT (32px, CC-BY-SA,
   montages in _screens/scout_city/) — the rowhouse, market, hedge/planter/banner/lamp and animal kits
   for S2 are already on disk. Web scout died at the session limit (resets 19:20) — optional.
   **S2 DISTRICTS SHIPPED (2026-09-13):** rowhouse generator from the Szadi Houses Pack modules
   (tools/assets/extract_szadi_houses.py → assets/art/world/houses: gable/cross/flat roofs, two-storey
   plaster band, plank ground floor with door, chimneys, poles; three colourways) — TownCity._house /
   _house_row: gable (3 storeys), cross (wide), cottage; chimney smoke on ~45%, door light, planter or
   pot by the door, hanging shop signs, banner pairs. Rows: Old Town (3 streets x 3 blocks), canal-side
   (4 blocks), Trade Square flanks (bank + auction house), Cathedral avenue, East Ward (2 streets), 4
   harbor warehouses. Street furniture from LPC Victorian Town Decorations (tools/assets/
   extract_victorian_kit.py → assets/art/world/street: hedges h/v/block/corner, planters, urns, pots,
   banner pairs, flat awnings, stall tables, flower beds, ornate lamps, clock post, sign icons, flags,
   barrels, signboard): market rows (6 stalls with awnings + goods), flags + planters + clock on the Trade
   Square, hedge under the keep wall, keep flags + banners, cathedral urns/hedges/flower beds + fenced
   churchyard with LPC graves and a dead oak, back-garden hedges + flower beds behind every Old Town row,
   harbor cargo, the Fields (2 farmsteads, mill house, 3 tilled fields with crop rows, fenced paddock with
   hay + trough, 6x3 orchard), East Ward craft yards (carpenter logs, potter jars, tanner cloth lines).
   Audit: 1,850 props, 0 real stacks (roof-mounted pieces excluded). Shots: _screens/city/s2_map_4k.png.
   Kit lesson: my first Szadi wall crops were one row off — always render the extracted module at 3x
   BEFORE composing (labels in montages must sit ABOVE the image they describe).
   NEXT = S3 LIFE + FILL: NPC cast anchors at every city doorstep (NPCCastSystem) + guards at the gates
   and keep, LPC farm animals (cow/sheep/pig/chicken sheets in _downloads/mass_2026_07/oga_lpc_bundles/
   lpc_farm_animals) in the paddock/fields as ambient fauna, cats/dogs in Old Town, birds; fill the empty
   bands (NW between village and Trade Square, SE quadrant, west fields), a second market on the East
   Ward square, harbor crane + nets, keep guards/barracks, curiosity sites + one crime scene per
   district (Bible V), then a full play-zoom sweep + sitting; S4 systems (bank/auction/trainers inside
   their buildings, waystation, minimap texture, map labels).
   **v2 RE-PLAN + DENSIFY SHIPPED (2026-09-21, Fable 5.1, owner choice "re-plan and densify" over
   "paint the grid"):** the 09-13 right-angle grid + ruler canals read as houses on a golf course at play
   zoom (audit shots `_screens/audit/city_*.png`). `scripts/town_city.gd` REWRITTEN (1,383 lines; 09-13
   version backed up in the session scratchpad): every street/canal/row is a drifting polyline; rows
   shoulder-to-shoulder (2-14 px gaps, an alley every 5-8) with fronts NORTH of each E-W street and
   hedge + back-garden bits (trees/beds/woodpiles/washing) south; gap-filler yards where lanes/bridges
   break a row; dirt shoulders only where feet go (village read); tufts/bushes/stones on every common.
   Districts: Approach + Old Gate, Burned Garrison (WARRIOR pocket), Horse Fair + Gate Tankard, Vigil
   Keep + barracks row, Trade Square (bank/auction/shops ring, market of Szadi + LPC stalls, basin quay),
   Cathedral Square (chapter house, almshouses, churchyard, candelabra/urns/benches), Candle-House (MAGE
   pocket), Old Town (5 curved streets, Fair Street spine, well square, the Drowned Rat tavern square),
   winding canal -> basin + leat with 8 bridges, East Road + 3 East Ward streets + craft yards + ward
   square market, market-garden allotments under the leat + gardeners' shed, Harbor (4 warehouses, quay
   square, fish market, piers, fishers' strand), the Fields (2 farmsteads, 4 fenced fields, 3 orchards,
   paddock, pond, granary tower, the mill, hedgerow lane, Ashen Chapel ruin = PALADIN pocket, wildwood
   strip = DRUID nod), SE commons (burned farmstead crime scene, fisher shacks, justice corner).
   **EAST GATE moved to the EAST wall**: MapRegistry.TOWN_EAST_GATE = (7000,2600); prompt verified in
   `v6_gate_prompt.png`; wilderness smoke still boots (its 30 not-found errors are the #128 fauna sheets).
   Minimap `assets/art/maps/town.png` regenerated from the 4K one-shot (scratchpad minimap_from_full.ps1)
   + re-imported; HUD shot `v7_hud_minimap.png`. QA: 9 boot cycles, every one eyeballed (v2..v9 shots in
   `_screens/audit/`), zero script errors, ~7-12 s boots; RH_PROPAUDIT final: 3,574 props, STACK=3
   (graveyard lantern-on-post, cathedral door-on-wall = accepted composites, 1 chimney/tree), IN_BLDG=5
   (3 = the inn's own sign/lanterns, 2 = wildwood bush-under-snag). Kit lessons: LPC street `bench_4`
   is a PIANO, `lamp_5` a black iron lamp, `barrel_5` a barrel row, `signboard_0` a tall board; the
   `roof_cone_dark` sheet holds two cones (crop 64 px); `_x_at` must handle CANAL_N stored south->north;
   row clearance vs lanes >46 px silently blocks most houses (RH_ROWDBG=1 prints placed/blocked).
   NOT done (R3/R4): NPC cast anchors at city doorsteps + guards, farm animals/cats/dogs/birds (sheets
   not on this machine), night lamp pass on the new streets is automatic (world_lights) but unreviewed
   per district, per-district curiosity sites beyond the pockets, bank/auction/trainers moved into their
   buildings, waystation, 40-second validator (prints only for ZoneBuilder zones; the town has none).
   The scattered-house rows still use only the 3 Szadi colourways x 3 kinds: a 4th module set (Szadi
   Houses Pack has more) is the next density lever.
   **v3 ALIGNMENT + BACK-GARDEN PASS (2026-09-21, same day, after the owner's 2/10 "houses misaligned,
   things clipping"):** root causes found on 3x probes (scratchpad house_probe2.png + a pixel scan of
   every module): (1) `roof_gable_*.png` carries a stray full-width ridge bar in rows 0-7 and nothing in
   rows 8-29 — the "plank floating above every roof"; roofs are now region-cropped from row 30
   (H_GABLE 274 / cottage 204 / cross 272). (2) The ground-floor crop was not centred on the door and
   not cut to the plaster band's width — modules now stack flush per colourway (KIT table: door 142/128/
   140, strip 276/260/272, band 153/135/147, roof widths per colour). (3) Chimneys hung beside the peak —
   now on the roof plane (gable slope 64 px under the ridge, cross wing 50 px). (4) Row geometry: houses
   BUTT (0 px) in terraces, an alley every 5-8, no per-house jitter, drift <=10 px/260; blocked
   stretches scan in 8 px steps and fall back to the cottage kind, so lanes end tight against terraces.
   (5) Every terrace house gets a FENCED BACK GARDEN planned before the ground is painted (soil rows of
   cabbage/carrot/tomato/pepper, a work yard on dirt with woodpiles + a washing line, or a flower plot
   with a bench), LPC post lines between neighbours — no lawn survives between two terraces. (6) A 4th
   house kind "shop" (timber ground + windows row + flat roof, 160 tall) from the unused Szadi modules.
   (7) Trade Square moved south so the keep wall shows above its north terrace; a terrace on the avenue
   to the cathedral; a 3rd East Ward terrace (EW3) fills the band above the fishers' strand (strand
   moved to the bank; the 4th warehouse that swallowed EW3's west end removed); market = one kit (the
   village's Szadi awning stalls); fountain planters + notice board; Fair Street lamps east side only
   (west side = allotments); allotments between the village hedgerow and Fair Street; wildwood dead
   trees only in the outer column; kit corrections (cainos_prop_12 is a sarcophagus, haybale_1 white
   bales, flag_3 a tricolour, urn/urn2 white vases, lamp_0/6 black iron, bench_4 a piano — all retired).
   QA: 16 boot cycles, all eyeballed (v10..v16 in `_screens/audit/`), zero script errors, ~7-13 s boots;
   final RH_PROPAUDIT: 4,369 props, STACK=2 (graveyard lantern-on-post, cathedral door-on-wall =
   composites), IN_BLDG=4 (3 = the inn's own sign/lanterns, 1 = a wildwood tree under a dead tree).
   Minimap regenerated + re-imported. NEW HOOK: `RH_SPRDBG="x,y,r"` prints every prop sprite within r
   of (x,y) — texture/size/offset — to identify a mystery sprite on a screenshot.
   STILL OPEN (visual): the lone almshouses east of the cathedral, the NE orchard corner and the SE
   commons are sparse; the gap yards where a lane breaks a terrace are one hedge block + one prop
   cluster; NPC life / animals / class-pocket dressing as before.
   **v4 LIFE + VARIETY PASS (2026-09-21, after the owner's 3/10 "not bad, drastically improvable"):**
   NEW `scripts/town_life.gd` (TownLife, called from TownBuilder after TownCity): 76 city folk with
   their own two-line voices, placed where they make sense — 4 market vendors behind the Trade
   Square stalls, banker/auctioneer at their doors, a crier, keep + gate + garrison guards, a
   quartermaster, tollman, farrier, horse-trader, Old Town wanderers on every street, two women at
   the well, the Drowned Rat's landlord + drinkers, the ward's potter/tanner/elder, watchman at the
   stocks, Father Ambrozie at the cathedral door, sexton + widow in the churchyard, pilgrims at the
   statue, 4 gardeners in the allotments, harbourmaster/fishwife/3 dock hands/2 fishers, farmers,
   miller, shepherd, the kneeling pilgrim at the Ashen Chapel, the widow across from the candle-house,
   the ragman, Sister Agatha + an old soldier at the new Hospice. Ids carry role keywords so
   NPCLifeSystem infers barks/routes; looks are seeded per id (6 sheets x 4 variants x 12 muted
   colourways, guards in 3 dark ones). FACADES: 40% of terrace houses mirrored (per-sprite flips —
   a negative node scale broke TownAudit's footprints), per-house tint, wall lamps (lit, 42 px) on
   shops + a third of houses, awnings over shop doors, ivy on a quarter of walls, clutter at alley
   mouths. GROUND: civic squares in pale Stone_White flags, keep yard cobble, worn holes in every
   street's cobble that show the dirt beneath (Mudstone_Brown "worn" patches read as mud blobs —
   retired). MOTION: animated LPC fountain on the square, 9 torches (keep gate + front, cathedral,
   garrison, harbour, gallows), fire pits in the keep yard and on the strand. FILLS: keep courtyard
   (fire pit + log seats, spear racks, cart, barrels at the barracks, buckets), cathedral square 80%
   paved with planter-lined forecourt, benches, board; the Hospice of the Vigil (cross house, hedge,
   benches, lamps) east of the cathedral; harbour east quay (bollards, crate rows, nets, boat on
   trestles, coils); harbour square gets the village well (the freekit covered well has a grass cap).
   Kit: freekit cart_big renders a lime-green tarp — retired for the LPC cart. TownAudit: wallamp/
   ivy/windows_row are facade pieces; facade pieces are never IN_BLDG of their own house.
   QA: 21 boot cycles today, every one eyeballed (v18..v21 in `_screens/audit/`), zero script
   errors; final RH_PROPAUDIT 4,622 props, STACK=11 (7 = vendors under their own stall awnings,
   2 composites, 2 fixed after), IN_BLDG=4 (inn sign/lanterns, one wildwood tree), NPC_IN=0.
   Minimap regenerated from a forced-clear 4K one-shot + re-imported.
   NEXT (visual): animals (sheets not on this machine), NPC schedules for the city cast
   (NPCLifeSystem routes are role-generic), interiors, the SE commons and NE orchard corner, a
   second market kit, snow/rain puddles on the flags.
   **v5 GROUND + CANOPY + FARMLAND PASS (2026-09-21, "improve it drastically again"):** GROUND:
   `_tonal()` — 170 large + 520 small soft radial blobs (dark earth / moss / pale) at 6-22% alpha on
   the decal layer over the whole city, so the grass never reads as one flat field at any zoom (the
   zone builder's Witchbrook macro-patch idea, ported). CANOPY: every leafy tree the city places
   now runs on the zone builder's shared GPU sway shader (`_swaying()` → ZoneBuilder._tree_sway_
   material); trees in every flower-plot garden, 40% of work yards, a quarter of the commons
   scatter, on the squares, the approach and the quays, copses of 3-5 on the commons, willows on
   the river bank. HOUSES: three chimney variants, a cast-shadow band under every terrace sill.
   VIGNETTES (Bible V, never explained): the drowned rat's grave on the canal bank with a lantern
   and the rope; a cross nailed to an Old Town door with green candles; the shrine at the ward
   crossroads; the ward well turned copper with a board that says nothing. FARMLAND: LPC fence
   rails along the field lanes (hedgerows), three haystack meadows with carts, a sheepfold + the
   shepherd's hut, a wayside cross, stone piles at the field corners, eight copses; the west
   allotments; the fenced gap yards in terraces (a rail run instead of the floating hedge block).
   SOUTH BANK: a towpath the whole width, reeds on both banks, 12 willows, the ferryman's yard
   (hut, two boats, lamp, sign), the eel-smokers (shack, two fires, drying racks), boats and nets
   pulled up, towpath lamps at the water gate and the ferry. FOLK: +14 (ferryman, eel-smoker,
   shepherd's boy, two haymakers, the pilgrim at the cross, eight more street wanderers with lines
   that point at the vignettes) — 90 city folk. Kit: `_commons`/copses keep 60 px off the field
   lanes and 40 px off soil; copse trees 72 px apart. QA GOTCHA: `RH_SHOT` containing "bank" or
   "auction" makes AuctionSystem open that panel (auction_system.gd:64/422) — never name a
   screenshot that way. 27 boot cycles today, all eyeballed (v23..v27 in `_screens/audit/`), zero
   script errors; final audit ~5,150 props, STACK = composites + vendors under their own awnings +
   hay heaps in the stacks, IN_BLDG 5 (the inn's own sign/lanterns, two trees under dead trees),
   NPC_IN 0. Minimap rebaked from v25_full + re-imported.
   NEXT: animals; schedules; the NE quarter beyond the hospice; a stone-wall kit for the lanes
   instead of the LPC rail; puddles; interiors.
   **v6 FULL HOUSES (2026-09-21, owner: "the houses are not ok — find full houses in the same
   aesthetic"):** the Szadi Houses Pack MODULE assembly (roof + plaster band + timber ground, three
   colourways) is RETIRED for the city. Every city house is now one of the eight Szadi Fantasy
   Lands full houses the approved village is built from (assets/art/buildings/house_00-07 — the
   only full-house art in this aesthetic on this machine; the civic/szfl_* copies are the same
   set): cottage = house_01, gable = house_05, cross = house_02 (red awning), shop = house_06,
   work = house_00 (hay awning: stables/workshops), barn = house_03 (big door: warehouses), shed =
   house_07, inn = house_04 (the Drowned Rat, the Gate Tankard, the Hospice). Their yards are
   baked in (stones, sacks, barrels, ladders), so terraces keep a 10-26 px seam; no two adjacent
   houses share a kind; 40% mirrored; per-house tint in three cool/warm/neutral families; smoke
   at each sprite's measured chimney; a wall lamp on shops/cross houses + 30%; cast shadow band.
   Garden post lines now hang off the real house width. 61 houses placed. Result: the city reads
   as the same town as the village (same brown roofs, brick, timber) at every zoom. Old module
   code kept in scratchpad backup town_city_v5_modules_last.gd. Audit final: STACK = composites +
   two commons trees, IN_BLDG = the inn's own sign/lanterns + two trees under dead trees, NPC_IN 0.
   Emergent: the Drowned Rat's landlord has "innkeeper" in his id, so the rest system offers
   [T] Rest there too (label still says "The Ember Hearth" — RestSystem uses one inn name).
   LIMIT: eight sprites is a small catalogue; a terrace of 6+ shows repeats even with mirroring.
   A ninth-plus house needs new verified-free art in this exact style (Szadi Fantasy Lands FULL
   pack, or a scout) — the owner's decision.
   **v7 THE 4/10 PASS (2026-09-22, owner: "does this look like a triple-A pixel game? improve the
   level, this is a 4/10, let's be honest"):** answered honestly (no), then a 7-agent critique
   workflow (ground / light / repetition lenses + probes of cainos_wall.png, szadi_building_parts
   .png, lpc_decorations/fences) produced a 5-pass plan; implemented v31..v37 with a boot +
   eyeballed screenshots after each. PASS 1 GROUND: the root cause of the "yellow desert" was
   GROUND_TINT multiplying the cobble overlay (mustard streets, sand square) — the city's overlay
   cells now live on `GroundOverlayCity` with CITY_STONE_TINT (0.90,0.86,0.80) while the village
   overlay keeps GROUND_TINT (byte-identical; `layer.self_modulate` so children tint themselves);
   `TownCity.ground_wash()` (Line2D bands + flat radials, alpha 0.52 neutral) sits UNDER the overlay
   over every dirt area so Dirt_Roots stops reading orange; the v4 hub-punched worn patches (read
   as dung heaps) are replaced by `_street_wear` decals + two rut Line2Ds per street; packed-earth
   band under every terrace (house seams/alleys were lawn); cobble 46 / shoulder 64; Mudstone_Gray
   sprig tiles 793/858 swapped 90% for the clean fills 856/857/1354; Old Town (OT1-4) hedges →
   a 37 px coped stone wall composited at runtime from three rows of cainos_wall.png (cap 192-210,
   course 210-219, base 246-256; `_low_wall_tex`, end caps); ward streets → LPC rail + posts; tufts
   never on the carriageway (`_on_street`), instead at wall feet; candelabra scaled 0.5 (were 2.8
   characters tall); granary cone = the RED cone of roof_cone_dark (roof_cone_tan.png is green);
   planter_bigtree replaces the two-tile planter_tree. PASS 2 GROUNDING: `_contact_shadows` post-
   pass (a radial under every non-flat free-standing sprite outside the village), deeper sill
   shadow + an east-wall shadow strip per house, tonal big blobs halved, `scripts/city_ambience.gd`
   (new): city lantern glass swaps lit/unlit (lpc_decorations 420,64 / 396,64) at 17:00/06:30 and
   flame lights in group "city_flicker" flicker through dn_base_energy (DayNight untouched).
   PASS 3 VARIETY: `_tree()` helper on all 8 leafy call sites (8% dead, 2% rust oak, 3% birch,
   scale 0.85-1.2, 50% flip, four muted tint buckets, canopy shadow for the big ones); house tints
   widened (slate/red/purple readable at 640x360 + 15% weathered); `_attach_parts` from the Szadi
   parts sheet (rects verified at 3x: dormer 610,224,28,38 / cap 640,245,32,23 / chimney_a
   583,156,18,29 / chimney_b 615,182,18,25 / chimney_wood 448,160,26,38 / doors 480,22,32,42 +
   478,86,34,44 / window 452,242,24,27 / tiny 392,168,14,18 / hatch 713,267,14,14 / roof_tall
   238,0,132,161 / wall_timber 247,161,114,63 / wall_brick 247,224,114,64) — cottage/gable/work/
   cross dormers, ridge caps, second chimneys, the shop's MISSING DOOR, a wooden chimney on the
   barn (its old smoke anchor sat on a shutter window; now smokes only with the chimney); a NINTH
   kind "town" = 132x278 half-timbered townhouse composited from the sheet (`_townhouse`) in the
   OT/EW kind lists; `_doorstep` = 3-5 pieces per kind packed from the corners toward the door,
   never kissing, never on a placed TownLife folk (`_near_folk`); banner_pair washing strung across
   60% of alleys; gardens/allotments = two crops + a sprout row (25% just-planted), jitter/flip/
   scale, rotating corner prop, crop_corn back row on the big plots; commons 3,200 tufts + 320
   bushes; the cathedral quarter's meadows get their own scatter (were skipped as built-up).
   PASS 4/5: green mottling (640 radials) on the open lawns; Trade Square cobble apron
   (cobble_brown_128 polygon) + rim + 4 cypress planters; `_water_skin`: cool wash, a Line2D with a
   scrolling-noise shader whose highlight FLOWS (canal south to the river, river east), a glint
   line, bank shade, CPUParticles flecks every 700 px, the basin as a shader ellipse; `_rooks`: two
   CPUParticles flocks of procedural 2-frame black birds crossing at z 60. TownAudit: parts-sheet
   pieces count as facade. QA: 7 patch cycles (v31..v37, scratchpad v31_pass1_patch.ps1 ..
   v37_patch.ps1, boot runner v31_boot.ps1), ~30 windowed shots eyeballed (`_screens/audit/v3*`),
   zero script errors; final RH_PROPAUDIT 5,403 props, STACK 30 (composites, commons canopies),
   IN_BLDG 44 (canopies over garden posts/beds + the inn's own sign/lanterns — accepted), NPC_IN 0.
   Minimap rebaked from v37_full + re-imported. Village 0..2240 x 0..1600 untouched (every v7
   pass skips the rect; overlay split keeps its cells on the tinted layer). Backups: scratchpad
   backup_2026-09-22/. NOT ACHIEVABLE WITHOUT NEW ART: >9 building silhouettes, >3 leafy canopies,
   fauna/animals, N-S stone walls (no vertical face on the Cainos sheet), a scarecrow, wet cobble.
   GOTCHAS: PowerShell variables are case-insensitive (`$r` clobbered `$R`); regex replacements
   that end at "\n" swallow the following line's tab — check for "))\tword" joins after a patch;
   Godot --check-only reports autoload identifiers as missing (harmless).

   **v8 THE FIVE-LENS PASS (2026-09-23, owner: "go"):** a 5-critic workflow (ground / light /
   repetition / composition / AAA-benchmark) read a fresh 20-shot v38 set plus the generator and
   rated the level 4, 4, 4, 4.5 and 5 out of 10. Its adversarial verify stage and plan agent died
   on the account's usage credits, so the driver refuted the findings itself (every asset
   Test-Path'd, every rect probed at 3x: scratchpad v8_probe_a.ps1 / v8_probe_b.ps1 →
   v8_houses_probe.png, v8_kit_probe.png) and implemented the survivors in four passes.
   PASS A GROUND (v40-v46): (1) every cobble/flag edge in the city wore a periodic GRASS LIP on
   packed earth — the keyed sheet keeps the blades of each Grass↔stone transition tile. New
   `TerrainPainter.make_tileset(keyed, deblade)` builds a one-off ImageTexture with the seven
   blade colours keyed out of the pair tiles of "10,30"/"10,31"/"10,32"/"10,33" plus solos
   793/858/796/861 — restricted BY TILE ID because (0,67,55) is also Grass_Dark's fill; the
   village overlay keeps the untouched sheet. (2) the pale flags move to `GroundOverlaySquares`
   at SQUARE_TINT (0.72,0.71,0.68): the plazas measured 40% lighter than the streets and read as
   sand (211,194,143 → 170,161,122). (3) `_city_earth()` redraws every SOLO Dirt_Roots cell of
   the city on its own layer with a channel-gain shader, killing the orange terrace backs
   (133,100,40 → 86,76,43); transition cells stay on the base so no grass half is retinted.
   (4) a second accent overlay (`top2` canvas → GroundOverlayCity2) paints Mudstone_Brown setts
   on the quay, the keep courtyard and a ring round the fountain — three paved materials instead
   of one grey — and RETIRES the cobble_brown_128 apron polygon (it is an emblem floor tile and
   tiling it put furniture marks on the plaza). (5) wear alpha 0.30-0.45 → 0.12-0.20, ruts 4→3 px
   and broken at junctions and dashed (they ran as tram lines through every crossing).
   PASS B LIGHT (v47-v48): lantern bloom (additive halo, group "city_glow") + pools raised to
   radius 118 / energy 0.62-0.84; LIT WINDOWS — a per-kind WINDOWS table of rects measured on the
   house sprites, an additive pane plus a soft spill per window, 85% of houses (inns always), a
   third staying lit after 23:00, all switched by city_ambience at 17:00/06:30; wall torches and
   the two braziers now obey the clock (flame in "city_flames", an iron sconce cropped from
   torch_anim_strip Rect2(0,14,32,18) in "city_brackets") — the keep used to burn nine torches
   under a noon sky beside unlit lanterns; `TownCity._smoke()` replaces the 1-2 px ghost plume
   (TownBuilder._chimney_smoke is untouched — the frozen village calls it) and the keep fire and
   forge now smoke; stall vendors stop being black cut-outs (szadi_awning rows 49-69 are a baked
   40-54% ground shade that fell on the NPC — the roof is cropped to the thatch, the two poles at
   x 8-11/86-89 are redrawn and the shade goes on the Decals layer); contact shadows peek past
   the foot, composites opt in via a "shadow_w" meta, every tree gets a canopy pool; house sill
   and side shadows anchor to the brick line via a per-kind SKIRT table.
   PASS C VARIETY (v49): the farm fields (the worst frame in the set — 85 copies of one crop on a
   34x36 lattice) get the garden recipe: two crops, a seedling row, a fallow strip every fourth
   row, 6% harvested holes, a half-pitch quincunx and a corn headland; bushes/rock piles/reeds
   flip, scale and tint; curtain walls seed their accent by position and flip bays instead of
   `i % 5 == 3`; three lamp heads (glass, LPC cage Rect2(423,32,26,32)/(392,32,26,32), pole flip)
   at a 300±80 pitch; `_plan_row` remembers the last THREE kinds (distance-2 clones were the
   commonest repeat) and the Trade Square's twin gables become gable + townhouse; house tints now
   change HUE plus a 10% limewash; HANGING SHOP SIGNS over every trade door (LPC sign grid rows
   y0/y32, probed) and a street feature — covered well / wayside shrine / notice board — on every
   other lamp gap, which is the 40-second rule the terrace frames failed; stalls flip, take one of
   three awning tints and draw goods from ten sprites, and the 140 px market grid is jittered with
   one stall replaced by crates.
   PASS D COMPOSITION (v50-v51): the Vigil Keep finally towers (3-row block + two freekit
   castle_tower_rd drums instead of a 2-row block lower than the houses in front of it); the
   harbour reads as a harbour (HARBOR_SQ moved to the quay lip at y 4400, a dark waterline with a
   pale highlight broken at the pier heads, dock railings every 96 px, a watch tower at the west
   end, the big anchor as the square's monument); doorstep/yard/garden-corner vocabulary widened
   from ~6 props to 20+; the water gets a channel (a darker mid-stream, a wet lip under the quay,
   flecks down from alpha 0.5 to 0.28); and BANK_ROW paves the Trade Square's north frontage so
   the bank, auction house and shops stand on a street instead of lawn.
   QA: 12 patch/boot cycles (scratchpad v40_passA.ps1, v47_passB.ps1, v49_passC.ps1,
   v50_passD.ps1 + tuning), ~40 windowed shots eyeballed (`_screens/audit/v4*`, `v5*`), zero
   script errors; final RH_PROPAUDIT 5,514 props, STACK 36, IN_BLDG 45 (canopies over garden
   posts and the inn's own sign — accepted), NPC_IN 0; wilderness still boots with zero script
   errors. Village 0..2240 x 0..1600 untouched (every new layer skips the rect; a sampled diff of
   the village frame shows only animated pixels). Minimap rebaked from v52_full + re-imported.
   Backups: scratchpad backup_2026-09-23/.
   GOTCHAS FOUND: an earlier note in this entry claimed 2D shader writes come back GAMMA-SQUARED.
   RETRACTED 2026-09-23 by a calibration boot (RH_SHADERCAL, three quads at the Trade Square): a
   shader writing 0.50,0.35,0.20 measured 129,88,46 against a plain modulate at 128,87,45 and the
   sRGB expectation of 128,89,51 - shader writes are faithful. The dark accent paving that
   prompted the wrong conclusion was a MIS-SAMPLED pixel (the probe point sat on earth, not on
   the quay). Lesson kept: measure the pixel you think you are measuring. `TerrainPainter._solo` values are JSON floats — `Array.has(int)` silently misses, so
   build coord sets from the solo table directly. CPUParticles2D.color_ramp takes a Gradient, not
   a GradientTexture1D. Stone_Tan really is orange even off GROUND_TINT. In PowerShell here-strings
   the `'@` terminator must be at column 0 — four of them mid-line killed two patch runs.
   NOT DONE (top of the next list): the diagonal roads (approach, avenue, link) are still 32 px
   STAIRCASES — the fix is a textured Line2D ribbon per road, the single most visible
   "procedural tilemap" tell and it is on the first screen after the village gate; dusk still has
   noon-length shadows and rigid cloth; the ward square has no facade on its north side; garden
   plot geometry is still one rectangle per house; the 10th silhouette (a hip-roofed hall from the
   parts sheet) is unbuilt.

   **v9 WATER / MINIMAP / SCHEDULES / COLLISION (2026-09-23, owner: "i want better water assets
   witchbrook style, we need to fully revamp the mini map its horrible, research pixel games with
   minimaps, dots on the maps is absolutely unacceptable, also give npc schedules, also make sure
   they dont colide with anything"):** a 4-agent research workflow (minimap references, pixel
   water rendering, NPC schedules, NPC navigation) returned four implementable specs, each with a
   code audit; everything below follows them.
   WATER. Nothing water-like exists on disk beyond a 32x32 LPC noise tile, so the water is a
   RENDERED SURFACE now, not new art: a procedurally generated 64x64 tileable value-noise texture
   plus one canvas shader per ribbon. Across a Line2D, UV.y runs bank-to-bank, which gives the
   depth ramp for free (pale shallows at the lip, dark channel mid-stream); two noise layers
   scroll at different speeds for flow, a low-frequency warp undulates the band edges, a
   thresholded highlight is the sparkle, a noise-broken band at the lip is foam, and the colour is
   quantised to 6 levels with a texture-space dither so it still reads as pixel art. The canal
   flows south to the river, the river east. The basin and the fields pond use a radial variant.
   GOTCHA: the first attempt used LINE_TEXTURE_STRETCH, which smears one texture over the whole
   7168 px river and produced flat horizontal bands - it must be LINE_TEXTURE_TILE with
   texture_repeat ENABLED. Second gotcha: a FRAGCOORD-based dither shimmers, because the game
   renders at window resolution with a 3x camera, so the dither must come from the texture.
   MINIMAP. Rewritten (scripts/minimap.gd). The old one squeezed the whole 7168x5120 city into a
   70x70 thumbnail and drew 2x2 coloured dots, so a house was 1.5 px. Now: an 84 px round window
   that SCROLLS with the player at 13 world px per minimap px (about three screens wide); places
   drawn as ICON GLYPHS with a dark seat - keep, church cross, market awning, tankard, anchor,
   well, gate arch, mill, granary, anvil, grave, horse, candle, boat, burned ruin - never dots;
   off-window places clamped to the rim as arrows, capped at the THREE nearest so the rim does not
   become a fence (Moonlighter/CrossCode convention); enemies as red chevrons; the district name
   fading in under the clock as you cross into a quarter. M opens a parchment world map with the
   same icons labelled, district names, travel diamonds, quest pins, the player arrow, a legend
   strip and +/- zoom about the player. QA hook RH_MAPOPEN=1 boots with the world map up.
   assets/art/maps/town.png rebaked at 1536x1098 (was 768x549) so the scrolling window stays crisp.
   SCHEDULES. New autoload `CityScheduleSystem` (scripts/systems/city_schedule_system.gd) + data
   file data/city_schedules.json. The audit found the city had NO schedules at all: SmartNPCSystem's
   data/npc_schedules.json is keyed to the TEN VILLAGE ids, so all 90 city folk were skipped, and
   NPCLifeSystem's "routes" and "rest" only nudge an NPC's home by up to 60 px - its "everyone goes
   to the inn at night" moved each folk 63 px north-west of wherever they stood. Three systems
   wrote the same private `_home` every second and fought. The new director claims ONLY ids
   beginning "city_" (the village keeps its shipped behaviour byte-identical), marks them
   `rh_sched_owned`, and the other writers stand down for exactly those (a guard in
   `_tick_schedules`, and guards inside `advance_route`/`send_to_rest` so barks keep working, plus
   an early return in npc.gd `_apply_night`). Shape follows Ultima VII / Kingdom Come / Stardew /
   Gothic / The Sims: 4-7 stops a day, each a PLACE plus an ACTIVITY, with the wander radius a
   property of the STOP rather than of the NPC - which is what finally lets the ~30 folk with
   wander radius 0 travel, and what makes a stall vendor stand still (r 0) and a guard pace (r 70).
   Blocks are a RING so no hour is uncovered; departures are staggered by a per-id hash (40
   minutes) so nobody teleports at 9am; districts are inferred from spawn position so there is
   nothing to author per id; "home" resolves to the nearest terrace doorstep on the published
   ROWS_EW polylines. Paths are computed ONCE per leg and cached (new `NavSystem.path_to` and
   `closest_point`) - npc.gd's per-frame `next_point` would have been ~6000 A* queries a second
   with a city of commuters. Both-ends-off-screen legs complete instantly (level-of-detail).
   Unreachable legs warn once, blacklist that block for the session and revert the folk to its
   shipped wander at its own spawn - never a teleport, never a rubber-band.
   COLLISION. The audit's key finding: NPCs are already on collision_layer 1<<2 / mask 1, so they
   collide with walls and props but pass cleanly through the player and each other - the whole
   class of "NPC shoves the player" and "crowd jams in a doorway" bugs is absent and must STAY
   absent, so the mask was deliberately NOT widened. What was added: every schedule destination is
   snapped onto the baked navmesh with `closest_point` (obstacles are inflated by AGENT_RADIUS at
   bake, so a snapped point is walkable), a per-folk anti-stacking offset, and a stuck detector
   (no 6 px of progress for 6 s aborts the leg).
   QA: new headless whole-day test, RH_SCHED_TEST=1, drives the clock through 48 half-hours and
   reports never-settled folk, blacklisted blocks and anyone standing inside a solid body. Result
   in the shipping configuration: tracked=90, never-settled=0, blacklisted-blocks=0,
   unreachable-warnings=0, INSIDE-COLLIDER=0, script errors=0. (Running it with RH_SCHED_SNAP set
   huge, which forbids the off-screen shortcut and forces every leg to be walked inside a 5-second
   compressed day, produces 33 aborts - that is the compressed clock, not a world problem.)
   NOT DONE: the wilderness map texture still does not exist, so that map falls back to the olive
   plate; there is no fog-of-war/discovery yet; NPC schedule stops have no interior destinations
   because the city has no interiors.

   **v10 THE MAP SCREEN (2026-09-23, owner: "do the same for the map, heavy research"; then, on
   seeing it: "this is a 1/10 map, drasticly and massivly improve it, have a look at tons of
   games"):** a 5-agent research workflow (discovery/fog, fast travel, player pins, map UX,
   cartographic treatment) returned five specs with code audits.
   FIRST FINDING, from the research and confirmed independently: THERE WERE TWO MAP SCREENS. The
   v9 parchment overlay added to scripts/minimap.gd is unreachable by key, because
   scripts/ui/map_screen.gd (the 3-tier World/Region/Local atlas spawned by the MapSystem
   autoload) consumes the "map" action in `_input()`, which always runs before the minimap's
   `_unhandled_input()`. The screen the owner actually sees on M is map_screen.gd, so ALL work
   went there; the minimap overlay is now dead weight to be removed.
   THE REAL PROBLEM was that the local tier drew a downscaled SCREENSHOT of the world on a
   parchment panel, with generic landmark DOTS. A screenshot reads as a photograph; every
   reference map (Hollow Knight's inked sheets, Elden Ring's washed watercolour, Tunic's folded
   booklet) reads as an ARTEFACT. The research also found the answer was already in the repo:
   assets/art/ui/world_map.png is a hand-drawn parchment chart whose palette is parchment
   211,190,144 / ink 52,38,24 / band 185,163,121 / seal 122,34,26 - the town chart simply had to
   join that family.
   THE CHART BAKER (new, tools/chart/bake_chart.ps1): an offline PowerShell driver around an
   inline C# image core. It classifies every pixel of a zone screenshot into water / road /
   building / field / tree / wall / grass by colour, cleans the masks with a majority filter,
   then RENDERS a chart: parchment ground, toned water with ruled ripple lines, blank road
   ribbons, cross-hatched built-up blocks (the pre-1737 convention) with a heavier ink stroke on
   their south and east edges as drawn shadow, hatched field blocks with furrow dashes, ink
   boundaries per class, a second offset coast band, and stamped three-stroke conifer glyphs
   where canopy is dense. Runs in half a second over 1.6M pixels. Baked
   assets/art/maps/town_chart.png and wilderness_chart.png; map_screen prefers <zone>_chart.png
   over the raw plate and switches every label, icon and glyph to sepia ink when it does.
   GOTCHA worth remembering: PowerShell is CASE-INSENSITIVE, so the C# constant `BUILD` shadowed
   the static method `Build` and `[RHChart]::Build(...)` failed with "does not contain a method
   named 'Build'" even though reflection listed it. Renamed the constant to HOUSE.
   ALSO LANDED ON THE MAP SCREEN: the 21 named places now draw as ICON GLYPHS with labels
   (reusing Minimap._draw_icon so there is ONE icon vocabulary), quarter names in larger type,
   greedy label de-collision (nudge down twice, then drop) because the village corner was
   unreadable, a legend rail that doubles as a FILTER list (1 places / 2 travel / 3 quarters /
   4 pins), a compass rose and a "500 paces" scale bar drawn in engine, and a breadcrumb that
   reports "surveyed N%".
   DISCOVERY: MapSystem gained a per-cell chart memory - 64 world px per cell (the city is
   112x80 = 8960 cells), a 560 px reveal radius sampled at 8.3 Hz, landmarks inked when you come
   within 180 px (which also surveys 768 px around them), and a veil texture of one texel per
   cell drawn stretched with LINEAR filtering so the frontier feathers for free. Persisted in
   MapSystem.save_state as base64 per zone plus the known-place list. Following the research's
   headline conclusion, the veil is NOT black: unsurveyed ground washes to blank parchment (the
   Zelda/Minecraft position - never hide the shape of a place), and what discovery really gates
   is the names, icons and gates.
   FAST TRAVEL: Tab cycles the gates you have actually discovered, Enter travels, and the map
   closes and calls main.change_map deferred. Undiscovered gates draw as a faint chevron with no
   label - the stag-station rule.
   ALSO: assets/art/maps/wilderness.png finally exists (the zone had none, so its map fell back
   to an olive plate), baked from a 0.2-zoom 4K one-shot.
   NOT DONE: player-placed pins (the spec is in hand at scratchpad/wm_pins.txt; the legend
   already reserves the [4] Pins filter), the UX spec's integer zoom steps and keyboard panning,
   and removing the now-dead world-map overlay from minimap.gd.

#### v11 - THE MAP DRAWN, NOT SCREENSHOTTED (2026-09-23, owner: "i want downloaded assets and
   all its a 2/10 lets be honest")
   ASSETS: downloaded Kenney's Cartography Pack (CC0, opengameart.org/content/cartography-pack,
   4,199,252 bytes) into _downloads/cartography and installed 53 symbols +
   CREDITS_CARTOGRAPHY.txt at assets/art/maps/carto/. Zero cost, no AI art, licence recorded.
   _downloads/cartography carries a .gdignore so the raw pack is not imported twice.
   THE BAKER REWRITTEN (tools/chart/bake_chart.ps1): v1 drew the chart per pixel - hatched
   roofs, ruled water, stroked tree marks - which is a FILTER, and a filtered screenshot still
   reads as a screenshot. v2 generalises and stamps:
     * paper is the pack's parchment HIGH-PASSED (every parchment in the pack is a seamless tile
       whose lighting is a 4x4 grid of folded panels; tiled it repeats, stretched it bands, so
       only the fibre survives) with two folds laid at the thirds
     * water is the pack's seamless ripple hatch inside the mask, with a coastline and a second
       line held off the shore
     * buildings are SOLID PLAN FOOTPRINTS with a heavier south/east stroke, after a hole fill
       that seals windows and doorways without a morphological close (any close wide enough to
       seal a doorway also welds neighbouring houses into one amoeba)
     * a blob is a building only if it is big enough to stand in AND fills its bounding box:
       people build in rectangles, a bramble fills a fifth of its box. What fails goes back to
       the wood if the wood rings it, else to paving
     * woods are drawn symbols on an even jittered lattice, thinned at the fringe
     * NO outline around paving - on a town plan a street is the gap between buildings
   TWO CLASSIFIER FIXES worth keeping: (1) vegetation is NOT "green dominant" - the wildwood is
   olive, r == g there, and a g > r test found 272 green pixels in a plate that is three quarters
   forest; what every leaf shares is a blue channel far below the other two with red no higher
   than green. (2) canopy vs open ground cannot be split by brightness: in the city the lawn is
   the bright majority and the canopy the dark minority, in the wildwood the canopy IS the plate
   and Otsu just halves its own shading. Local TEXTURE splits both - pixel-art foliage is
   outlined leaf clusters and reads as high variance, mown ground is flat. Measured: town
   tree 18.0% / built 10.6% / water 4.9% / open 41.5%; wilderness tree 58.3% / built 2.9%.
   PINS (tools/chart/make_pins.ps1 -> assets/art/maps/carto/pin/): the pack draws in near-black
   and draw_texture_rect's modulate MULTIPLIES, so tinting that art with map ink lands at about
   3% grey. Pins are re-rendered pure white with the original alpha, AT the size they are shown
   at, because project.godot draws canvas textures with NEAREST and any rescale in engine tears
   the strokes. The map screen now draws every named place as a cartography symbol - castle for
   the Vigil Keep, churchLarge for the Cathedral, waterWheel for the Mill, dock for the Harbour,
   graveyard, gate, well, tent, stable, skull - and the compass rose is the pack's compass.
   MAP SCREEN FIXES, all found by looking at captures:
     * the marks layer was clipped to the PANEL, so a name near the south edge printed across
       the legend; it is clipped to the map now
     * names are placed in a SECOND pass after every mark and piece of furniture has claimed its
       paper - with one pass a name only avoided the names already written and then printed
       straight across the next symbol along
     * a name that cannot fit below its mark goes above it, and never off the sheet
     * the legend sits on the panel's near-black ground, so it is keyed to the frame's gold, not
       to the parchment's ink (it was ink-on-black and invisible)
     * world + region tiers: the shipped Draconia plate already letters itself and carries its
       own rose and scale, so the engine was printing every kingdom twice and facing north in
       two corners. On those tiers the engine draws marks only, and the lozenge is OPEN so the
       plate's lettering reads through it
     * _sheet is LINEAR_WITH_MIPMAPS and the plates import with mipmaps: 1536 px shown across
       572 aliased every ink line into shimmer while panning
   HARNESS FIX: RH_MAPSCREEN opened the map on the boot frame, before RH_MAP's change_map landed,
   so every "wilderness" capture was silently a picture of Raven Hollow. It waits 30 frames now.
   VERIFIED by reading captures: town local, wilderness local, region and world tiers; 0 script
   errors on every boot.
   NOT DONE / FOUND: the other 39 plates in assets/art/maps are tools/map_painter.py output for
   zones that MapRegistry does not list (only town and wilderness are loadable), and the painter
   draws only what zone_defs declares - roads, river, landmarks - so they are a tan ribbon, a
   blue line and three glyphs on blank paper. Charting them produced blank sheets (0% of
   everything) and the 40 bad bakes were deleted; only town_chart.png and wilderness_chart.png
   ship. Also still open from v10: player-placed pins, integer zoom steps, keyboard panning, and
   the dead world-map overlay in minimap.gd.

### Held for owner
- [WARN] **ZONE MAP PLATES ARE NEARLY BLANK (2026-09-23, v11):** 39 of the 41 plates in
  `assets/art/maps` come from `tools/map_painter.py`, which paints only what `zone_defs.gd`
  declares (roads, river, landmarks, ways). Zones with two road polylines and three landmarks
  therefore render as a tan ribbon, a blue line and three 10 px glyphs on blank parchment. Two
  routes to fix, both owner calls: (a) declare more geometry per zone in `zone_defs.gd`, or
  (b) give the painter a richer look built on the new CC0 cartography symbols. The painter's
  own header says "Fable authors the look; this code is the brush (visual law)", so the driver
  did not touch it. Note also that this machine has NO Python, so `map_painter.py` cannot be run
  here at all; the two shipped charts were baked from in-game screenshots instead.
- [WARN] **ONLY town AND wilderness ARE LOADABLE (2026-09-23, v11):** `scripts/map_registry.gd`
  lists exactly two maps, while `zone_defs.gd` carries 39 built zone defs and `MapSystem.ANCHORS`
  has anchors for all of them. The world map therefore marks 39 places you cannot walk to. Not a
  bug to fix blind - it is a content-scope question for the owner.
- [WARN] **DUNGEON NAMES MISSING AT WORLD SCALE (2026-09-23, v11):** now that the engine no
  longer re-letters the world and region tiers, anything the Draconia plate does not name goes
  unnamed there - e.g. The Chamber Depths. Either add those names to the plate (art) or give
  MapSystem a per-zone "named on plate" flag so the engine can letter only the gaps. (⚠)
- ⚠ **CITY v8 (2026-09-23):** the five-lens critique workflow's verify + plan agents failed with
  "out of usage credits"; the driver did that work itself. Re-running any billed multi-agent
  review needs the owner's credit call (BACKLOG #105/#108).
- ⚠ **NPC OUTFIT PALETTE (2026-09-23, repetition lens):** six of seven folk in a frame wear the
  same near-black coat. The sheet-native half (spread the six sheets x four variants so no two
  folk within 320 px match) is free; widening TownLife.OUTFITS with lighter colourways is a
  character-art palette change and falls under the palette-swap ban — owner's call.
- ⚠ **CITY v7 LIGHT & MOTION (Fable-only visual, 2026-09-22):** cloud shadows would go in
  `weather.gd` as a screen-space layer that also crosses the approved village — owner call;
  same for cooling `DayNight.COL_NIGHT` (frozen) and a navy `VIGNETTE_EDGE` in main.gd.
- ⚠ Adventurer-Sim design session (parties/40-man raids/chat/rolls/guilds/BGs)
- ⚠ Quest QA playthrough; itch.io publish
- ⚠ **CANONICAL INVENTORY DECISION (architecture, TASK_DIVISION):** two bags exist —
  `scripts/inventory.gd` (`Inventory`, on the player, size 20, what BagUI/shop/save
  render) and `scripts/systems/inventory_system.gd` (`InventorySystem` autoload,
  size 30, paperdoll UI). The combat/loot pass (2026-07-07, Opus) BRIDGED enemy loot
  into the player's visible `Inventory` (kills now give usable loot — proven via
  RH_LOOT_TEST) but did NOT delete either bag. Owner should pick ONE canonical bag
  and retire/migrate the other (BagUI vs the systems paperdoll; legendary equip-procs
  and runeword sockets want the unified bag to fully fire). Driver bridged, did not
  decide — deleting an owner system is out of lane.
- ⚠ **CANONICAL QUEST ENGINE DECISION (architecture, TASK_DIVISION):** two quest
  engines run in parallel — the Phase-C `Quests` node (`scripts/quests.gd`, 5 quests,
  key E/G) and the data-driven `QuestSystem` autoload (`data/quests.json`, ~13 quests,
  keys L/J/G, its own "!"/"?" markers). Same NPCs are givers in BOTH, so a player sees
  two markers + two keybinds on one NPC. Owner should choose which ships (or merge the
  13 data quests into the Phase-C engine). Driver flagged, did not delete either.
