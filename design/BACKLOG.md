# THE BACKLOG — durable owner-directive ledger (anti-hallucination law)
Owner mandate: every todo lives HERE, committed, so any session resumes instantly with zero loss.
Read order for a fresh session: MANDATES.md → this file → todo state below → design/*.md.
Status: ✅ done · 🔧 in progress · 📐 designed (doc exists) · ⬜ queued · ⚠ needs owner input.

## ⚑ SUPREME RULES (owner's words, latest session)
1. **VERIFIED FREE ASSETS ONLY — "the absolute most mandatory rule of them all."** Everything built from fully-scouted, verified-free asset packs (license recorded). The Asset Gauntlet enforces.
2. **ANTI-HALLUCINATION LAW**: all state written durably (this file + MANDATES + memory); definitive resume point always exists.
3. **BE CHEAP**: minimal credit spend while keeping quality exceptional — reuse agent caches, batch designs, prefer local compute (5070 Ti) and scripts over agents when equal.
4. **SPELL VFX UNIQUENESS LAW** (supersedes VFX_AAA_PLAN's palette-sharing): spell VFX CANNOT repeat; palette swaps for spells are ILLEGAL; every spell and every creature's effects independent and unique. (Feasibility note: with free-assets-only this is the single biggest asset demand in the project — resolve via per-spell composite recipes: unique sheet combos + motion + timing per spell, not shared tints.)
5. **CONCRETE TOOLTIPS LAW**: spell/spellbook text states exactly what it does with numbers ("empowers you" is banned); the text must match the actual effect. Applies to every tooltip.

## Sitting #1 verdict (Prime Mandate — 9/14 inspectors reported before session limit)
BLOCKED zones with the fix list (fix → re-sweep → Council):
- ⬜ **Ground tiling seams zone-wide** (mud repeat grid nakedly visible) → variant tiles/rotation/decal breakup
- ⬜ **Road system conflict** (translucent tile path vs dark smear trail within 100px; mis-snapped segments; trees standing IN roads) → one road art, routed around props
- ⬜ **Creature pack stacking** (wolves/boars collapse into one blob — separation radius broken zone-wide) → separation steering in enemy wander/chase
- ⬜ **Weather rain covers only bottom screen band at some world offsets** (weather surface not spanning viewport) → WeatherController surface fix
- ⬜ **Zone identity gaps** (iron_vein shows zero "iron": no ore, carts, scree, mine mouths) → zone-fantasy prop passes per zone
- ⬜ **Asset monotony** (1 tree + 1 bush) → scatter variety per biome (packs already owned)
- ⬜ **Vetka + Angel Wings quadrants uninspected** (agent limit) → resume sitting #1 from cache
- ⬜ **REDO RAVEN HOLLOW** (owner: "not good enough — make it perfect")

## New owner directives (the 4am batch) — all captured
### World & feel
- ⬜ Skyrim vibe layered onto the tone mix
- ⬜ WoW-scale zone SIZE feel ("Stormwind scale" capitals, castles); painted, dense, cohesive levels
- ⬜ Terrain blending like Graveyard Keeper (ground reads as rising/falling) — deploy study bots, then implement height-illusion blending
- ⬜ Drova-style visibility fog (2D line-of-sight fog trick)
- ⬜ Diablo-2-style transparency when the player walks behind tall textures
- ⬜ Per-zone lighting/ambiance focus pass (continues AAA lighting work)
- ⬜ Cow-level-style secret zone, lore-accurate to Draconia
- ⬜ Resting activities (player downtime systems: inn rest, fishing?, hearth)
### NPCs & world life
- ⬜ Town barks in speech bubbles ("Fresh bread!" near the bakery) via TTS
- ⬜ Organic NPC chatter: roaming, greetings, friendships forming (WoW-server community feel among bots)
- ⬜ NPC jobs/routes; rest at the inn; sit/sleep/work animations from free packs — flawless
- ⬜ TONS of vendors; profession-appropriate intriguing quests, some class-specific with powerful rewards
### Classes & combat
- ⬜ Druid CAT FORM + BEAR FORM with full transformation animations, fully textured from packs, perfect fit (lore-named forms)
- ⬜ Rogue kit rework: stealth, dagger poisons, vanish, assassinate-target-and-escape fantasy
- ⬜ Character sprite must pair perfectly with EVERY equippable item (full animation test matrix — sprite×item QA)
- ⬜ The shipped sword sprite "looks pygame-drawn" — replace with real pack pixel art; REAL hand animation when sheathing to the back
- ⬜ 1,500-2,000 creatures w/ distinct debuffs + death animations each + PERFECT navigation (navmesh emphasis)
- ⬜ Spellbook UI (visible, browsable) + concrete tooltips law
### Quests & story
- ⬜ +1,000 MORE lore-of-the-land quests (2,000 total: sheep-herding small → artifact epics)
- ⬜ Romance side-quests: many, all different, fully diverse (treated as side quests; tasteful per no-sexuality law)
- ⬜ RDR2-grade world detail & reactivity; mysteries — "small quests" that unfold into 2-continent 4-hour epics with epic loot
- ⬜ Loot SCARCE; professional AUCTION HOUSE for mats + BANKER in capitals
- ⬜ Writers council working with quest masters on every quest/bark/gossip
- ⬜ Game length: ≥1,000 hours to beat; players race BOTS to world-firsts (first to kill the big boss, first to 1,000 quests)
### Items & economy
- ⬜ Every item: own icon asset + perfect equipped animation; designed for FUN
- ⬜ Artifact/runeword color = Diablo dark gold (update RUNEWORDS' shifting-orange → D2 dark gold #C7B377-ish; keep orange for live-stone lore FX only)
- ⬜ Mount trophies (Witcher-style, bloody) from world elites — random drops, per-class advantages
- ⬜ Max crafting skill 1000 (updates CRAFTING's 300); legendary recipes per profession AND class-specific from bosses
### Factions
- ⬜ 2D-pixel faction EMBLEMS + race emblems; full REPUTATION system per faction
### PvP
- ⬜ 1v1 arenas in EVERY zone, each thematically native (updates PVP_RANKS_TITLES' single venue → a network; Reckoning Floor stays the flagship)
### Audio & voice (the 10k Sound Council)
- ⬜ Zone music with Diablo 2 / Warcraft 3 / WoW feel (Elwynn Forest nostalgia bar) — research-bots on why Blizzard leads audio design + cinematics; apply
- ⬜ ALL sound produced on the local TTS/audio server; menu sounds + full UI SFX, AAA grade
- ⬜ Distinct voice per character, sprite-appropriate (old name = old voice), Mark Hamill/Kevin-Conroy bar; Diablo 2 style — narrator = "that Marius storyteller voice" (maps to our Chronicler; re-cast Maya1 desc toward warm weary Marius timbre)
- ⬜ 10,000-agent Sound Council reviews every sound before it ships (ledger like the Million Council)
### Engineering & tooling (owner software orders)
- ⬜ OWNER CONTROL INTERFACE: ground-up app (language of my choice) — simple-but-deep AAA-studio software controlling every aspect of the game
- ⬜ ADMIN PANEL: super-easy manual QA of every feature (in-game debug/admin UI — cheapest correct start; fold into control interface)
- ⬜ C++/native ENGINE layer automating level design + AAA-studio pipelines for 2D pixel art
- ⬜ PROMPT-TO-GAME ENGINE ("Microsoft level"): "make me a 2D RPG about autumn" → asks style questions → builds from our engine (mandatory; huge — staged after the game itself)
- ⬜ LOCAL AI STUDIO: the whole bot corporation running OFFLINE on the 5070 Ti at Fable-like capacity (research: local LLM orchestration — Qwen/Llama on 16GB VRAM + the pipelines we've built; honest gap noted: local models ≠ Fable capability; we mitigate via narrow fine-tuned roles + our validators)
- ⬜ Corporation structure: departments of bots (design/audio/QA/writers/godot-optimization), Rockstar-grade prolific QA teams
- ⬜ Godot hacker horde: engine-limit optimization + automation everywhere
- ⬜ Disk-space watcher: prune unneeded files automatically (with safety rules)
- ⬜ Study-bots: all of 2D pixel game design; terrain blending; UI design courses → style-appropriate UI overhaul (massive)
- ⬜ Bots: perfect navmesh + class-appropriate spell rotations; everyone starts from 0 on "New World"
- ⬜ Agents playtest the game start-to-finish (first drop → final boss)
### Character creation
- ⬜ AAA character-creation screen + UI: tons of customization

## In-flight (resume-from-cache, cheap)
- 🔧 Sitting #1 remainder: vetka + angel_wings q1-q4 inspectors (resumeFromRunId wf_4fc3249f-577)
- 🔧 TALENTS_SPELLS doc (resumeFromRunId wf_36e70e40-f6d)
- 🔧 SCORE_BIBLE / AUDIO_QA / ACHIEVEMENTS (resumeFromRunId wf_34a6119b-647)
- 🔧 Voice v2 bake (detached supervisor, self-healing)
- ✅ CRAFTING / STARTING_ZONES / LEGENDARY_WEAPONS / QA_AUTOMATION / NARRATIVE_VOICE / GREAT_BATTLE / CINEMATICS / FREEDOM_PHYSICS / MAP_SYSTEM / PVP_RANKS_TITLES / PROFICIENCY_WYSIWYG / VFX_AAA_PLAN — committed

## Standing build order (post-fix)
Sitting-#1 fixes → re-sweep → Raven Hollow redo → map v3 + zoom tiers → Batch C (North) under full Prime-Mandate loop → implementation wave 1 (combat retune/INVULN, loot window, stats, status effects, starting quests) → onward per WORLD_PLAN batches.
