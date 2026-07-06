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
29. 📐→⬜ NPC cast rollout (~243 across 40 zones)
30. ✅ Item progression (gear-score/level, via InventorySystem) — BUILT 2026-07-06
31. ✅ Loot tables + 16 named rares — BUILT (LootSystem, rarity budgets) f1c905f
32. ✅ LOOT WINDOW (D2-style, rarity+tooltips) — BUILT
33. ✅ Combat retune (archetypes/telegraphs/casts/charges/XP-to-60) — BUILT (BLUEPRINT_33, TTK PASS) 3f120e5
34. ✅ Character stats (5 primaries + derived + per-class scaling) — BUILT (StatsSystem) efd0a23
35. ✅ Status effects + wolf→Infected chain — BUILT (StatusSystem)
36. 🔧 Hidden debuffs — (folded into StatusSystem; symptom debuffs) — PARTIAL
37. ✅ Runewords/sockets/12 runes (D2 dark-gold) + StatsSystem bonuses — BUILT aa05b60
38. ✅ Mounts: 31 mounts, summon/speed, elite trophies, trainers — BUILT (MountSystem) 12439d6
39. ✅ Options suite + persisted settings (video/audio/gameplay/controls) — BUILT (OptionsSystem) 1c22b5d
40. ✅ Smart NPCs: schedules, vendors + shop UI, reactions — BUILT (SmartNPCSystem) 7ab946d
41. ✅ Talent trees (21, 252 talents, prereqs) + StatsSystem hooks — BUILT (TalentSystem) 6055cc2
42. ✅ Crafting: 7 professions, 35 recipes, skill-to-1000, legendaries — BUILT (CraftingSystem) 7edd7ed
43. 📐→⬜ Class starting experiences: 7 mentor pockets (STARTING_ZONES)
44. ✅ 7 legendary weapons + unique signature effects + acquisition + WYSIWYG — BUILT 5b29780
45. ✅ Proficiencies cloth/leather/mail/plate + equip gating — BUILT (InventorySystem) ea97bbd
### Design docs complete, systems queued (46-60)
46. ✅ PvP arena (Reckoning Floor) + 14-rank Accord Roll + 55 titles — BUILT 54f492e
47. ✅ Map system: 3-tier zoom + fog-of-war + pins + minimap — BUILT (MapSystem) d0aa4a3
48. 📐→⬜ QA automation stack: tests/qa.py 4 layers (QA_AUTOMATION)
49. 📐→⬜ Narrative voice rollout: Tolkien×dread registers to ALL text (NARRATIVE_VOICE)
50. 📐→⬜ THE GREAT BATTLE build ("The Second Cooperation" — GREAT_BATTLE)
51. 📐→⬜ Cinematics: 6 D2 films (ComfyUI stills + Chronicler VO) + in-world system (CINEMATICS)
52. 📐→⬜ Freedom & physics: no-walls audit + Zelda props (FREEDOM_PHYSICS)
53. 📐→⬜ Score production: C–E♭–D motif stems, MusicDirector adaptive layers (SCORE_BIBLE)
54. ✅ Audio QA COMPLETE: tools/audio_qa.py validator (192 files: decode/duration/peak/LUFS-windows/loop-seam) + tools/audio_fix_loops.py (seamless-loop rotation render); 9 beds repaired, all 173 VO pass — validator runs per audio batch forever
55. ✅ Achievements deed-book (9 cat, 69 deeds, toasts+panel, persist) — BUILT 9bc7cdd
56. 🔧 VFX AAA plan — REWORK to owner's uniqueness law: no repeats, palette swaps ILLEGAL, unique per spell AND creature (VFX_AAA_PLAN amendment). OWNER RULING 2026-07-05: NO PURCHASES EVER — the ~$15 Pimen/Frostwindz proposal is DEAD; VFX pool depth comes from free packs (#101 scout) + ComfyUI generation on the owner's GPU (SDXL + Pixel Art XL, already proven for icons)
    - ✅ PROVEN: ComfyUI-generated, per-spell-UNIQUE VFX with a perfect-cutting pipeline
      (tools/assets/gridcut.py + rogue_vfx.py) — first full kit = rogue (6 sheets, #83). Each
      VFX is its own generated element + distinct motion model (NOT a recolour) → uniqueness law
      satisfied. Reusable for the other 6 classes' kits + creature VFX.
57. ⬜ Crafting ANIMATIONS from packs (stations + character craft-bob)
58. ⬜ Spell trainers NPCs in world + trainer UI
59. ✅ Spellbook UI (browsable + concrete tooltips) — BUILT fb79aa4
60. ✅ Achievement toast + panel — BUILT
### Zone production (61-66)
61. ✅ RAVEN HOLLOW REDO: all sitting-#1 town findings fixed (stalls, plaza fringe, orphan patches, grave clip, west road, SW clearing, gate lantern) — Council re-confirmation at next sitting
62. ✅ Batch C SHIPPED: North arm + Black Night capital (13 zones live) — rows of twelve, Thread filaments, snow tundra; Council sweep next sitting; catacombs-stone district detailing continues under Prime-Mandate loop
63. ✅ ALL 40 ZONES LIVE — Batches D-H → all 40 zones — **Batch D SHIPPED** (East arm: whisper_passes, eastern_ridges, BLESTEM capital — perpetual-dusk ambient lock, Black Spire, lamp-lit streets, Riddler's Quarter, Lower Market — lichenreach FIRST CAVE — underground ambient, biolume lichen — transcub_vale). 18 zones live. Engine adds: cave biome (dark ground/rock walls/no weather), rain-purge on hard transitions, DayNight underground+ambient_lock modes, tools/validate_travel.py (18 zones, all seams reciprocal). **Batch E SHIPPED** (South arm: bloodroad, basaltfang, SANGEROASA capital — THE FORGE THAT EATS: Debt Pit + forge district + killing floors + ambient-lock forge haze — the_gift red fields w/ childs_shoe vignettes, ashvents). 23 zones live. Engine adds: volcanic biome art (schwarnhild basalt + burnt trees + vents, credited), lava_vent/forge/pit/gift_field/brazier/cairn/signboard landmark types. **Batch F SHIPPED** (the two canon dungeon-caves: CHAMBER DEPTHS beneath Vetka — live transmission stones, thread web, the Courier's sealed satchel vignette — and THE GRAVE & BLOODSTONE PIT beneath Black Night — Lilith's tomb, converging threads, grave rings, raid-tier shells; cellar/grave stair entrances wired). 25 zones live. **BATCH G SHIPPED — ALL 40 ZONES LIVE (39 defs + town + wilderness).** Collector's Coast ×14 built (GREYHOLLOW drowned-ledger capital w/ Pit + clerk ring + ruled ivy blocks; THE ARCHIVE cold capital w/ ambient lock + colonnades; grey_piers ferry landing, canal_maze, drowned_quarter, morven_reach, salt_fens, dead_timber, ledger_roads 4-way hub, finalized_fields grave-grid, orange_fog (per-zone FOG color override), last_hearth SAFE hub, anchorfall, coldharbor_deep cave) + GREY FERRY (#75: riverfork.ferry_dock ↔ grey_piers.ferry_landing, era-crossing per council design). Engine: sea-edge bands, pier/boat/wreck/warehouse/crane/cargo/salt_pan/drowned_fence/ledger_tablet/lone_tree types, coast art (kimbul cobble/paved fills + minzinn sailboat/rowboat, credited). 39 zones ALL SEAMS RECIPROCAL. NEXT: WITCHBROOK POLISH LOOP (owner law: Witchbrook-level detail, polished BY FABLE) — sitting-3 confirmed fixes (road art, cold ambient bias, graves spacing, black_night buildout, threadlands webs) + coast Witchbrook pass + re-sweep
64. ✅ Sitting-#1 round-2 fixes complete (roads, ≡ artifact, keep-clear, stalls) — angel_wings quadrant findings folded into next sitting
65. ⬜ Terrain blending (GK up/down illusion): study-bots then implement
66. 🔧 Prime-Mandate polish loop — SITTING #2 DONE (11 inspectors, 220 shots, 161 findings: town A- PASS, angel_wings F, blestem D-): root causes fixed — sweep-camera smoothing lag (~300px off-center, corrupted overlap analysis), camp composite (bedroll row read as graves, floating flame → stone-ring pit + fanned warm bedrolls), ice-pond spacing + footprint keep-clear (bush-on-pond), road keep-clear inflation (tree-on-kerbstones), thread filaments now anchored to posts, stall poles lengthened; GOLDEN steppe palette (canon) + North-arm densification (steppe/threadlands/gravemark +30 landmarks). Sitting #3 CONVENED (wf_4e2ced37-fd9: 16 inspectors + adversarial verify over 429-shot re-sweep). CAPITAL IDENTITY PASSES SHIPPED — canon-corrected: Angel Wings is NOT a white city (lore: poor/crowded/ordinary, mud+woodsmoke+thatch = strategic disguise) → +15 packed cottages, CHIMNEY-SMOKE particles at chimney mouths, Lead Vault lead-grey tint, orphanage yard, full-granary + burned-farmstead(lead box, scratch marks) vignettes; Blestem → black-basalt ground palette (per-def palette override) + maze keeps/kerb rows/lamps; Black Night → outskirt statues/rows/lamps/graves/camp. SITTING #3 ADJUDICATED (16 inspectors + adversarial verify, 429 shots; 51 verifiers died at session limit → completion is #106): town A- PASS again; confirmed systemics FIXED (ce29297): cold-zone ambient_bias (snow no longer flips beige between snowfalls), graves 48x58 spacing, threadlands +4 webs, BLACK NIGHT gate-to-gate roads + crossroads quarter. Remaining confirmed per-zone items + ROAD ART UPGRADE → #100
### World systems (67-76)
67. ⬜ Drova-style visibility fog (2D line-of-sight)
68. ⬜ D2 behind-texture transparency (occluding sprites fade)
69. ⬜ Cow-level-style secret (lore-accurate)
70. ✅ Resting (inn/hearth, well-rested XP buff via StatusSystem) — BUILT 9da4dc6
71. ✅ Factions + reputation (6 factions, 8 WoW tiers, emblems, rep gates) — BUILT 61ea165
72. ✅ Auction house + bank (listings, gold+item storage) — BUILT 7debfc4
73. ⬜ Scarce-loot tuning pass
74. ⬜ Dungeons (10) + Raids (3, finale Bloodstone Pit)
75. 🔧 Grey Ferry: travel link + fast-travel ROUTES ✅ (riverfork.ferry_dock ↔ grey_piers.ferry_landing) — the VOYAGE INTERLUDE presentation is #102
76. ⬜ 1,500-2,000 creatures w/ unique debuffs + death anims + perfect navmesh (staged; bestiary round 2 wolves→dragons)
### Quests & narrative expansion (77-81)
77. ⬜ +1,000 lore-of-the-land quests (2,000 total)
78. ⬜ Romance side quests (many, all-different, diverse, tasteful)
79. ⬜ Writers council + quest masters production system
80. ⬜ RDR2-grade detail & mysteries (small→epic 2-continent chains); ≥1,000-hour game audit
81. ⬜ Skyrim vibe layer on top of Witcher heavy-cheerful tone
### Characters & audio expansion (82-88)
82. ⬜ Druid CAT + BEAR forms w/ full pack-textured transform animations
83. 🔧 Rogue rework: stealth/dagger-poison/vanish/assassinate
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
84. 🔧 D2-STYLE SELECT SCREEN (BLUEPRINT_84): animated hero on pedestal + class blurb/abilities/stat-bias + RACE layer (racial passive shown, lore blurb) — showcases what class AND race does. Data-driven (data/classes,races). Blocked on animated class sheets from video-gen pipeline. Opus builds.
85. ⬜ Distinct voice per NPC (sprite-appropriate; Hamill/Conroy bar); D2-style + Marius-timbre Chronicler recast
86. ⬜ Menu/UI sounds via TTS-server pipeline, AAA grade
87. ⬜ 10k Sound Council system (reviews every sound)
88. ⬜ NPC bark bubbles ("Fresh bread!") + organic chatter/friendships; jobs/routes/inn-rest w/ sit anims from free packs
### Items & sprites (89-91)
89. ⬜ Replace "pygame-looking" sword sprites w/ real pack art; REAL hand animation on sheathing
90. ⬜ Sprite×item full animation test matrix (every item on every character)
91. ⬜ Scout assets fitting our characters EXACTLY with tons of animations (gauntlet-gated)
### Engineering mega-projects (92-97)
92. ⬜ Owner CONTROL INTERFACE (ground-up AAA-studio app) + easy ADMIN PANEL for manual QA
93. ⬜ C++/native engine layer: level-design + studio-pipeline automation
94. ⬜ PROMPT-TO-GAME engine ("make me a 2D RPG about autumn" → builds on our engine)
95. 🔧 LOCAL STUDIO v1 SHIPPED (tools/studio/): Ollama+Qwen2.5-Coder-14B worker w/ 5 roles (quest/bark/def/item/qa-triage), style-bible priming + validators + retry; finetune/ QLoRA recipe on the project corpus (honest scope: specialist, not Fable-clone; no Claude-output training per ToS). ART (ComfyUI) + VOICE (Maya1) already local = full free studio. Remaining: owner installs Ollama, first batch run, adopt-if-better eval
96. ⬜ Corporation-of-bots departments; godot-optimization horde; 2D-pixel-design + Blizzard-audio/cinematics study hordes; playtest agents start-to-finish; bots w/ perfect navmesh + class rotations; race-vs-bots world-firsts; everyone starts from 0 on New World
97. ⬜ Disk-space watcher (safe pruning) + BE-CHEAP operations law (standing)
98. ✅ SEAMLESS WORLD edge-streaming (full crossing, gated+change_map fallback) — BUILT (BLUEPRINT_98) 22cf6a1

99. ✅ COLLISION AUDIT: footprint colliders per prop class + pushable props — BUILT (BLUEPRINT_99, 60 types mapped) e58f0cf

### Session additions 2026-07-05 (100-108) — reconciliation sweep
100. 🔧 WITCHBROOK POLISH LOOP — **PAINTING PASS 1 SHIPPED: all 38 zone defs received Fable-authored lore sites (1 murder/crime scene + curiosity sites each; Last Hearth murder-free BY DESIGN; town/wilderness already dressed)** — murder_scene composite (stain/remains/drag-marks/dropped item); examples: grave-digger in his own grave (gravemark), forgehand's boot-prints ending at the Pit edge (sangeroasa), the salt-farmer white-on-white (salt_fens), the hungering who almost made it east (orange_fog), a body shelved and tagged (the_archive). **ROAD-ART UPGRADE SHIPPED** (perpendicular 2-wide stamping — vertical roads were 1-tile-wide, the sitting-3 'debug geometry' root cause; flush 2x2 diagonals + elbow pads; grass/pebble edge blending). REMAINING in loop: (owner law, FABLE-ONLY VISUAL: every zone hand-painted by Fable personally — lore landmarks, CURIOSITY SITES (>=2/zone), MURDER/CRIME SCENES (>=1/zone), all vignettes and visual passes; drivers/studio excluded from visuals): per-zone detail passes to Witchbrook density. Top items: ROAD ART UPGRADE (real path texture + corner/jog smoothing + grass edge-blending — sitting-3's #1 systemic defect), baked-snow ground evaluation (vs ambient-bias), coast detail pass (14 new zones), sitting-3 per-zone remainders (blestem ×5, lichenreach ×3 incl. cave-bright road, transcub ×4 incl. cross-shot prop stability, eastern_ridges ×4, black_night pale-green floating light at ~(6786,4486)), THEN full re-sweep + sitting #4
101. 🔧 GRAND ASSET SCOUT (owner: "incredibly vast variety of medieval assets to paint the levels"): 10 categories (castle/church/village/harbor/terrain-blends/creatures/NPCs/interiors/monuments/FX), VERIFIED-FREE license evidence + style gate; workflow script saved (wf_a889d7f0-2c4, 0 ran — re-run AFTER credit reset); downloads → Asset Gauntlet → zone painting. **2026-07-05 (Opus, #114):** `tools/assets/scout.py` built — live license-fetch + evidence + verdict + manifest (`_downloads/_assetlib/scout_manifest.json`). HONEST FINDING: free-scouting adds little beyond the ~20 owned packs (CC0/CC-BY anchors reconfirmed: Kenney Tiny Town CC0, OGA LPC Village Decorations CC-BY-SA; fresh candidates NEEDS_MANUAL). **Generation (#114) is the real library** — scout demoted to secondary per owner.
102. ⬜ GREY FERRY VOYAGE INTERLUDE (council design committed): fog-crossing scene, era-crossfade banners ("The Iron Vein Delta — Year 0" → "The Collector's Coast — Year 1000"), ferryman + CARRIED FORWARD chit, shifting-orange fog master-tell mid-passage
103. ⬜ CAPITAL-UNIQUE ARCHITECTURE KITS: all 6 capitals currently reuse the same 8 rustic house sprites — each needs a distinct civic kit (Greyhollow drowned-ledger stone, Archive filing halls, Black Night catacomb facades, Blestem black-iron, Sangeroasa forge-works, Angel Wings stays rustic per canon) — from #101 scout or ComfyUI gen; Witchbrook-bar dependency
104. ⬜ CREATURE PACK INTEGRATION + THE WEREWOLF GAP: turn downloaded packs (lucifer cultist/possessed, craftpix vampires, admurin) into REAL Enemy types replacing reskins ("Strigoi Enforcer"=orc, "Varcolac"=wolf); Varcolaci need TRUE werewolf sprites (no free top-down pack found → ComfyUI 3D→2D pipeline); feeds #76
105. 🔧 LOCAL STUDIO OPERATIONS (credit law): v1 shipped (#95) — OWNER: install Ollama + pull qwen2.5-coder:14b; then first free batches (50 Coast quests, 200 barks, sparse-zone densification drafts, item tables) → Fable review/integration gates; QLoRA eval adopt-if-better
106. ⬜ SITTING #3 COMPLETION: resume the 51 dead verifiers from cache (wf_4e2ced37-fd9) AFTER reset; adjudicate the unverified findings for steppe/gravemark/whisper/bloodroad/basaltfang/ashvents/gift/sangeroasa/angel_wings
107. ⬜ COAST CONTENT WAVE: the 14 Collector's-Coast zones need NPC cast (extends #29), quest lines (#27/#77), per-zone arenas (#46), lighting/ambience polish, sweep + 4K one-shots (Prime-Mandate cameras) — currently creature tables only
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

### Held for owner (⚠)
- ⚠ Adventurer-Sim design session (parties/40-man raids/chat/rolls/guilds/BGs)
- ⚠ Quest QA playthrough; itch.io publish
