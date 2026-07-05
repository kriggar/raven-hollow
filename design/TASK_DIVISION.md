# TASK DIVISION — Fable 5 vs Opus 4.8 (owner directive, 2026-07-05)

Principle: **Fable takes everything that requires architecture, canon judgment,
systemic balance, or root-cause debugging. Opus 4.8 takes every task whose
design doc is already complete enough that a strong implementer can ship it
by following the spec.** Every OPUS task ships with a handoff contract:
1. the design doc (already committed in design/),
2. acceptance criteria (validator / test / screenshot checklist),
3. a FABLE review gate before merge (sitting QA or code review).

Mechanism: OPUS tasks are run as `opus`-model subagents orchestrated from the
Fable session (Agent tool, model override), or in dedicated Opus sessions the
owner opens. Either way the contract + gate applies.

## FABLE 5 — the complicated jobs (~24)

| # | Task | Why Fable |
|---|------|-----------|
| 63 | **FINISH ALL 40 ZONES** (in progress — 25 live) | canon-sensitive hand-crafting, builder engine |
| 75 | Grey Ferry voyage | zone/travel engine integration |
| 98 | SEAMLESS WORLD (no loading screens) | async edge-streaming architecture |
| 99 | Collision audit + | footprint physics engine design (#52) |
| 52 | Freedom & physics engine | engine |
| 33 | Combat pacing retune | systemic balance + telegraph AI |
| 27 | Quest ENGINE v2 + campaign acts/arcs | state architecture + GoT intrigue canon |
| 50 | THE GREAT BATTLE | large-scale scripted set-piece engine |
| 51 | Cinematics engine + direction | D2-style film pipeline + canon direction |
| 53 | Adaptive score MusicDirector | layered-stem engine + motif direction |
| 56 | VFX uniqueness law rework | per-spell design + shaders, palette-swap ban |
| 65 | Terrain blending (GK up/down illusion) | rendering illusion engineering |
| 67 | Drova visibility fog | 2D line-of-sight shader |
| 68 | D2 behind-texture transparency | occlusion shader |
| 47 | Map 3-tier zoom + fog-of-war | world-state integration |
| 66 | Prime-Mandate sittings (forever) | judgment-heavy visual QA |
| 74 | Dungeon/raid LAYOUTS + boss design | encounter design |
| 76 | Creature pipeline + perfect navmesh | pipeline + pathfinding engineering |
| 80 | RDR2-grade detail & 1000h audit | judgment |
| 92 | Owner control interface | ground-up app architecture |
| 93 | C++ level-design engine | native engine |
| 94 | Prompt-to-game engine | architecture |
| 95 | Local AI studio (5070 Ti) | ML systems |
| 96 | Bot corporation architecture | org/system design |

## OPUS 4.8 — spec-complete implementation (~35)

| # | Task | Handoff doc | Acceptance gate |
|---|------|-------------|-----------------|
| 28 | Calendar events | CALENDAR_EVENTS.md | events fire on set dates in-game |
| 29 | NPC cast rollout (~243) | NPC_CAST.md | all zones populated, no overlap w/ landmarks |
| 30 | Item progression data | ITEM_PROGRESSION.md | budget formula validates per ilvl |
| 31 | Loot tables + named rares | LOOT_TABLES.md | drop simulation matches spec % |
| 32 | Loot window UI | LOOT_WINDOW.md | screenshot vs spec mockup |
| 34 | 5 primary stats migration | CHARACTER_STATS.md | L1 byte-identical check passes |
| 35 | Status effects | STATUS_EFFECTS.md | wolf-bite×3→Infected chain test |
| 36 | 35 hidden debuffs | HIDDEN_DEBUFFS.md | symptom-first, no UI leak test |
| 37 | Runewords + sockets | RUNEWORDS.md | D2 DARK GOLD color law |
| 38 | Mounts (31) + trophies | MOUNTS.md | ground-only law; trainer flow |
| 39 | Options suite | OPTIONS_SUITE.md | every option round-trips save |
| 41 | Talent trees + trainer data | TALENTS_SPELLS.md | 21 trees, ~15 spells/class wired |
| 42 | Crafting professions (cap 1000) | CRAFTING.md | 7 professions craft-loop test |
| 43 | Class starting pockets ×7 | STARTING_ZONES.md | follows zone-def pattern; Fable sitting |
| 44 | Legendary weapons ×7 | LEGENDARY_WEAPONS.md | quest chains complete |
| 45 | Proficiency + WYSIWYG wiring | PROFICIENCY_WYSIWYG.md | every equip visually swaps |
| 46 | Arenas ×40 placement | Fable ships template first | 1v1 flow works per zone |
| 48 | tests/qa.py 4-layer stack | QA_AUTOMATION.md | validators run green on HEAD |
| 49 | Narrative voice rollout | NARRATIVE_VOICE.md | register lint on all text |
| 55 | Achievements Deed-Book | ACHIEVEMENTS.md | 9 categories + toasts |
| 57 | Crafting animations | pack anims exist | stations animate |
| 58 | Spell trainer NPCs + UI | TALENTS_SPELLS.md | learn flow + gold sink |
| 59 | Spellbook UI + tooltip law | owner tooltip mandate | concrete numbers in every tooltip |
| 60 | Achievement/deed toasts | ACHIEVEMENTS.md | toast QA screenshots |
| 69 | Cow-level secret | Fable canon brief first | hidden trigger works |
| 70 | Resting activities | inn/hearth spec | rested bonus loop |
| 71 | Emblems + reputation | faction list canon | rep bars + vendor gates |
| 72 | Auction house + banker | capitals exist | mats-only AH; bank tabs |
| 73 | Scarce-loot tuning | Fable economy targets | drop-rate telemetry |
| 77 | +1,000 lore quests | QUEST_EXEMPLARS.md | writers-council pattern; Fable arc gate |
| 78 | Romance side quests | tone: tasteful/diverse | Fable tone gate |
| 81 | Skyrim vibe layer | vibe brief | Fable spot-check |
| 82 | Druid cat+bear forms | pack anims scouted | transform anim QA |
| 83 | Rogue stealth/poison/vanish | kit spec | balance sim vs TTK law |
| 84 | Character creation screen | AAA brief | screenshot review |
| 85 | Voice batch production | Maya1 pipeline (proven) | Fable casting gate; audio_qa.py |
| 86 | Menu/UI sounds | TTS pipeline | audio_qa.py green |
| 87 | 10k Sound Council runs | AUDIO_QA.md | council reports to Fable |
| 88 | NPC barks + organic chatter | SMART_NPCS.md | bark bubbles in-world |
| 89 | Real sword sprites + sheathing | Fable-approved packs | hand-anim frames verified |
| 90 | Sprite×item test matrix | RH_* hooks exist | automated capture grid |
| 97 | Disk-space watcher | BE-CHEAP law | safe-prune dry-run log |

## SPLIT (Fable architects → Opus mass-produces)
- **27** quests: Fable = engine + 3-act campaign spine; Opus = 1,000 quest data entries from the matrix
- **40** smart NPCs: Fable = schedule engine; Opus = 243 schedules
- **45/76/91**: Fable = pipelines + gauntlet gates; Opus = batch integration
- **74**: Fable = layouts/bosses; Opus = trash population + loot hookup
- **79/96**: Fable = council/corporation architecture; Opus = staffing + throughput

## CREDIT AMENDMENT (2026-07-05 eve, owner: 93% weekly usage, resets in 6 DAYS)
The OPUS lane is executed by the LOCAL STUDIO first (tools/studio/ — free,
5070 Ti) for all content-production tasks (quests, barks, defs, items, docs).
Billed Opus 4.8 agents run ONLY: (a) after the credit reset, (b) for tasks the
local studio repeatedly fails at the QA gate (UI code, engine-adjacent work).
Fable spends tokens on REVIEW + INTEGRATION + ENGINE only.

## Standing law
Zones (#63) outrank everything until 40/40. Then the implementation wave
(#27-#45) runs OPUS-parallel under Fable review while Fable builds #98/#99/#52.
