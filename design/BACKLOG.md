# THE BACKLOG — canonical numbered task registry (NEVER LOSE THIS — owner mandate)
Anti-hallucination law: this is THE definitive task list. Triple-stored: this repo (committed),
GitHub (pushed), and the agent memory system points here. Every session resumes from this file.
Fresh session read order: design/MANDATES.md → THIS FILE → design/*.md as needed.
Legend: ✅ done · 🔧 in progress · 📐 designed (doc committed) · ⬜ queued · ⚠ owner input needed.

## THE REGISTRY (99 tasks)
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
24. ✅ Map masterpiece v1-v3.1 (parchment, routes, plates) — 🔧 iterate forever
25. ✅ 30+ design docs committed (see design/)
26. ✅ Anti-hallucination triple storage (this file + GitHub + memory)
### Design docs complete, implementation queued (27-45)
27. 📐→⬜ Quest system v2 + 1,000-quest campaign (QUEST_ARCHITECTURE/VILLAIN_ARC/ZONE_QUEST_MATRIX/EXEMPLARS)
28. 📐→⬜ Calendar events (12, WoW dates) implementation
29. 📐→⬜ NPC cast rollout (~243 across 40 zones)
30. 📐→⬜ Item progression + rarities + budgets (ITEM_PROGRESSION)
31. 📐→⬜ Loot tables + 16 named rares (LOOT_TABLES)
32. 📐→⬜ LOOT WINDOW implementation ("super nice" — LOOT_WINDOW spec)
33. 📐→⬜ Combat pacing full retune: archetypes, telegraphs/casts/charges AI, zone tables, XP-to-60 (COMBAT_PACING)
34. 📐→⬜ Character stats: 5 WoW primaries (CHARACTER_STATS)
35. 📐→⬜ Status effects + wolf→Infected chain (STATUS_EFFECTS)
36. 📐→⬜ 35 hidden debuffs, symptom-first (HIDDEN_DEBUFFS)
37. 📐→⬜ Runewords/sockets/12 runes — recolor to D2 DARK GOLD (RUNEWORDS + owner amendment)
38. 📐→⬜ Mounts system + 31 mounts + trainers (MOUNTS) + mount TROPHIES from elites (Witcher-style, class advantages)
39. 📐→⬜ Options suite (OPTIONS_SUITE) + settings UI
40. 📐→⬜ Smart NPCs: schedules/vendors/reactions (SMART_NPCS)
41. 📐→⬜ Talent trees (21 statted) + spellbook→~15/class + trainers (TALENTS_SPELLS)
42. 📐→⬜ Crafting: 7 Draconia professions — raise cap to 1000 per owner (CRAFTING amendment) + legendary recipes per profession AND class from bosses
43. 📐→⬜ Class starting experiences: 7 mentor pockets (STARTING_ZONES)
44. 📐→⬜ Legendary weapons ×7 + no-transmog visual gear (LEGENDARY_WEAPONS)
45. 📐→⬜ Proficiencies cloth/leather/mail/plate + WYSIWYG pipeline (PROFICIENCY_WYSIWYG)
### Design docs complete, systems queued (46-60)
46. 📐→⬜ PvP arena (Reckoning Floor) + Accord Roll ranks + titles (PVP_RANKS_TITLES) — EXPANDED per owner: thematic 1v1 arenas in EVERY zone
47. 📐→⬜ Map system: 3-tier zoom + fog-of-war + pins + minimap polish (MAP_SYSTEM)
48. 📐→⬜ QA automation stack: tests/qa.py 4 layers (QA_AUTOMATION)
49. 📐→⬜ Narrative voice rollout: Tolkien×dread registers to ALL text (NARRATIVE_VOICE)
50. 📐→⬜ THE GREAT BATTLE build ("The Second Cooperation" — GREAT_BATTLE)
51. 📐→⬜ Cinematics: 6 D2 films (ComfyUI stills + Chronicler VO) + in-world system (CINEMATICS)
52. 📐→⬜ Freedom & physics: no-walls audit + Zelda props (FREEDOM_PHYSICS)
53. 📐→⬜ Score production: C–E♭–D motif stems, MusicDirector adaptive layers (SCORE_BIBLE)
54. ✅ Audio QA COMPLETE: tools/audio_qa.py validator (192 files: decode/duration/peak/LUFS-windows/loop-seam) + tools/audio_fix_loops.py (seamless-loop rotation render); 9 beds repaired, all 173 VO pass — validator runs per audio batch forever
55. 📐→⬜ Achievements "Deed-Book": 9 categories, toasts, 60 exemplars (ACHIEVEMENTS)
56. 📐→⬜ VFX AAA plan — REWORK to owner's uniqueness law: no repeats, palette swaps ILLEGAL, unique per spell AND creature (VFX_AAA_PLAN amendment)
57. ⬜ Crafting ANIMATIONS from packs (stations + character craft-bob)
58. ⬜ Spell trainers NPCs in world + trainer UI
59. ⬜ Spellbook UI (browsable) + CONCRETE tooltip law enforcement
60. ⬜ Achievement/deed toast + panel implementation
### Zone production (61-66)
61. ✅ RAVEN HOLLOW REDO: all sitting-#1 town findings fixed (stalls, plaza fringe, orphan patches, grave clip, west road, SW clearing, gate lantern) — Council re-confirmation at next sitting
62. ✅ Batch C SHIPPED: North arm + Black Night capital (13 zones live) — rows of twelve, Thread filaments, snow tundra; Council sweep next sitting; catacombs-stone district detailing continues under Prime-Mandate loop
63. 🔧 Batches D-H → all 40 zones — **Batch D SHIPPED** (East arm: whisper_passes, eastern_ridges, BLESTEM capital — perpetual-dusk ambient lock, Black Spire, lamp-lit streets, Riddler's Quarter, Lower Market — lichenreach FIRST CAVE — underground ambient, biolume lichen — transcub_vale). 18 zones live. Engine adds: cave biome (dark ground/rock walls/no weather), rain-purge on hard transitions, DayNight underground+ambient_lock modes, tools/validate_travel.py (18 zones, all seams reciprocal). **Batch E SHIPPED** (South arm: bloodroad, basaltfang, SANGEROASA capital — THE FORGE THAT EATS: Debt Pit + forge district + killing floors + ambient-lock forge haze — the_gift red fields w/ childs_shoe vignettes, ashvents). 23 zones live. Engine adds: volcanic biome art (schwarnhild basalt + burnt trees + vents, credited), lava_vent/forge/pit/gift_field/brazier/cairn/signboard landmark types. **Batch F SHIPPED** (the two canon dungeon-caves: CHAMBER DEPTHS beneath Vetka — live transmission stones, thread web, the Courier's sealed satchel vignette — and THE GRAVE & BLOODSTONE PIT beneath Black Night — Lilith's tomb, converging threads, grave rings, raid-tier shells; cellar/grave stair entrances wired). 25 zones live. **BATCH G SHIPPED — ALL 40 ZONES LIVE (39 defs + town + wilderness).** Collector's Coast ×14 built (GREYHOLLOW drowned-ledger capital w/ Pit + clerk ring + ruled ivy blocks; THE ARCHIVE cold capital w/ ambient lock + colonnades; grey_piers ferry landing, canal_maze, drowned_quarter, morven_reach, salt_fens, dead_timber, ledger_roads 4-way hub, finalized_fields grave-grid, orange_fog (per-zone FOG color override), last_hearth SAFE hub, anchorfall, coldharbor_deep cave) + GREY FERRY (#75: riverfork.ferry_dock ↔ grey_piers.ferry_landing, era-crossing per council design). Engine: sea-edge bands, pier/boat/wreck/warehouse/crane/cargo/salt_pan/drowned_fence/ledger_tablet/lone_tree types, coast art (kimbul cobble/paved fills + minzinn sailboat/rowboat, credited). 39 zones ALL SEAMS RECIPROCAL. NEXT: WITCHBROOK POLISH LOOP (owner law: Witchbrook-level detail, polished BY FABLE) — sitting-3 confirmed fixes (road art, cold ambient bias, graves spacing, black_night buildout, threadlands webs) + coast Witchbrook pass + re-sweep
64. ✅ Sitting-#1 round-2 fixes complete (roads, ≡ artifact, keep-clear, stalls) — angel_wings quadrant findings folded into next sitting
65. ⬜ Terrain blending (GK up/down illusion): study-bots then implement
66. 🔧 Prime-Mandate polish loop — SITTING #2 DONE (11 inspectors, 220 shots, 161 findings: town A- PASS, angel_wings F, blestem D-): root causes fixed — sweep-camera smoothing lag (~300px off-center, corrupted overlap analysis), camp composite (bedroll row read as graves, floating flame → stone-ring pit + fanned warm bedrolls), ice-pond spacing + footprint keep-clear (bush-on-pond), road keep-clear inflation (tree-on-kerbstones), thread filaments now anchored to posts, stall poles lengthened; GOLDEN steppe palette (canon) + North-arm densification (steppe/threadlands/gravemark +30 landmarks). Sitting #3 CONVENED (wf_4e2ced37-fd9: 16 inspectors + adversarial verify over 429-shot re-sweep). CAPITAL IDENTITY PASSES SHIPPED — canon-corrected: Angel Wings is NOT a white city (lore: poor/crowded/ordinary, mud+woodsmoke+thatch = strategic disguise) → +15 packed cottages, CHIMNEY-SMOKE particles at chimney mouths, Lead Vault lead-grey tint, orphanage yard, full-granary + burned-farmstead(lead box, scratch marks) vignettes; Blestem → black-basalt ground palette (per-def palette override) + maze keeps/kerb rows/lamps; Black Night → outskirt statues/rows/lamps/graves/camp
### World systems (67-76)
67. ⬜ Drova-style visibility fog (2D line-of-sight)
68. ⬜ D2 behind-texture transparency (occluding sprites fade)
69. ⬜ Cow-level-style secret (lore-accurate)
70. ⬜ Resting activities (inn rest, hearth, downtime systems)
71. ⬜ Faction + race EMBLEMS (2D pixel) + REPUTATION system
72. ⬜ Auction house (mats) + banker in capitals
73. ⬜ Scarce-loot tuning pass
74. ⬜ Dungeons (10) + Raids (3, finale Bloodstone Pit)
75. ⬜ Grey Ferry voyage + Continent 2 travel
76. ⬜ 1,500-2,000 creatures w/ unique debuffs + death anims + perfect navmesh (staged; bestiary round 2 wolves→dragons)
### Quests & narrative expansion (77-81)
77. ⬜ +1,000 lore-of-the-land quests (2,000 total)
78. ⬜ Romance side quests (many, all-different, diverse, tasteful)
79. ⬜ Writers council + quest masters production system
80. ⬜ RDR2-grade detail & mysteries (small→epic 2-continent chains); ≥1,000-hour game audit
81. ⬜ Skyrim vibe layer on top of Witcher heavy-cheerful tone
### Characters & audio expansion (82-88)
82. ⬜ Druid CAT + BEAR forms w/ full pack-textured transform animations
83. ⬜ Rogue rework: stealth/dagger-poison/vanish/assassinate
84. ⬜ AAA character-creation screen (tons of customization)
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
95. ⬜ Local AI studio on the 5070 Ti (offline, Fable-capacity goal — honest research + narrow-role mitigation)
96. ⬜ Corporation-of-bots departments; godot-optimization horde; 2D-pixel-design + Blizzard-audio/cinematics study hordes; playtest agents start-to-finish; bots w/ perfect navmesh + class rotations; race-vs-bots world-firsts; everyone starts from 0 on New World
97. ⬜ Disk-space watcher (safe pruning) + BE-CHEAP operations law (standing)
98. ⬜ SEAMLESS WORLD (owner mandate): all 40 zones interconnected, NO loading screens — edge-streaming (pre-build adjacent zone off-screen as the player nears a seam, continuous walk-across, unload behind); the player never feels a map change. Engine: async zone pre-build + world-offset stitching + camera continuity, replacing the fade-to-black change_map at seams.

99. ⬜ COLLISION AUDIT (owner mandate): study EVERY prop class — does it need collision or not (decals/ivy/tufts walkable; wells/stones/logs solid; canopies pass-under) — footprint-accurate shapes (feet-line, not sprite rect), tied into the FREEDOM_PHYSICS engine (#52: pushable/rollable props get RigidBody2D, static get accurate StaticBody2D, dressing gets none); audit table per prop id + validator in tests/qa.py.

### Held for owner (⚠)
- ⚠ Adventurer-Sim design session (parties/40-man raids/chat/rolls/guilds/BGs)
- ⚠ Paid-pack approval (~$15 Pimen/Frostwindz full sets)
- ⚠ Quest QA playthrough; itch.io publish
