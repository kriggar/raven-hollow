# THE BACKLOG — canonical numbered task registry (NEVER LOSE THIS — owner mandate)
Anti-hallucination law: this is THE definitive task list. Triple-stored: this repo (committed),
GitHub (pushed), and the agent memory system points here. Every session resumes from this file.
Fresh session read order: design/MANDATES.md → THIS FILE → design/*.md as needed.
Legend: ✅ done · 🔧 in progress · 📐 designed (doc committed) · ⬜ queued · ⚠ owner input needed.

## THE REGISTRY (98 tasks)
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
54. 🔧 Audio QA: file fixes SHIPPED (declip/gains/seam-crossfades ✅) — remaining: VO gain trim after final 5 lines, audio_qa.py validator build
55. 📐→⬜ Achievements "Deed-Book": 9 categories, toasts, 60 exemplars (ACHIEVEMENTS)
56. 📐→⬜ VFX AAA plan — REWORK to owner's uniqueness law: no repeats, palette swaps ILLEGAL, unique per spell AND creature (VFX_AAA_PLAN amendment)
57. ⬜ Crafting ANIMATIONS from packs (stations + character craft-bob)
58. ⬜ Spell trainers NPCs in world + trainer UI
59. ⬜ Spellbook UI (browsable) + CONCRETE tooltip law enforcement
60. ⬜ Achievement/deed toast + panel implementation
### Zone production (61-66)
61. 🔧 RAVEN HOLLOW REDO: stall-float ✅ + plaza fringe ✅ — remaining: orphan stone patch, branch-thru-grave, dying west road, SW dead space, lantern-fence clip
62. ⬜ Batch C: North arm + Black Night capital (snow + Szadi catacombs) at WoW-REAL-ZONE-SIZE, Stormwind-scale capital w/ castles
63. ⬜ Batches D-H: East, South, dungeons, Continent 2 port ring, remainder → all 40 zones
64. 🔧 Sitting-#1 round-2 fixes: roads-all-solid ✅, '≡' artifact ✅, breakup keep-clear ✅ — remaining: minor vetka floaters + angel_wings quadrant findings
65. ⬜ Terrain blending (GK up/down illusion): study-bots then implement
66. ⬜ Per-zone lighting/ambiance polish passes + densely-painted cohesion (Prime-Mandate loop forever)
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

### Held for owner (⚠)
- ⚠ Adventurer-Sim design session (parties/40-man raids/chat/rolls/guilds/BGs)
- ⚠ Paid-pack approval (~$15 Pimen/Frostwindz full sets)
- ⚠ Quest QA playthrough; itch.io publish
