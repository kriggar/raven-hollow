# OWNER MANDATES — master ledger (single source of truth)

**THE ASSET SOURCING LAW (2026-07-11, owner):** levels are CONSTRUCTED from
the owner's GENERATED asset library (ComfyUI, 30k target) for all statics;
ANIMATED assets — mainly CHARACTERS, also creatures/VFX — come from
verified-free net packs (the local-AI animation wall stands, #116). Generation
is the default for everything that does not move; animation is downloaded,
license-verified, geometry-PIL-verified.

**THE STYLE ANCHOR LAW (2026-07-11, owner — MANDATORY):** the game's art style
AND level-of-detail bar = the Necromancer "Master of the Dead" reference sheet
(`../lab/input_necromancer_ref.png`; palette + rules codified in
design/STYLE_ANCHOR.md). Every asset (generated locally + downloaded) and every
zone grade is judged against that sheet; its IN GAME PREVIEW panel is the level
density/mood bar. Library target: **30,000 total assets** (owner, 2026-07-11),
sourced from local generation + verified-free downloads, all style-gated to the
anchor. Levels stay HAND-CRAFTED by Fable (visual law) at Witchbrook density —
this sheet's palette.

**THE ACADEMY LAW (2026-07-05, owner — THE MOST MANDATORY RULE): the local AI
must reach and hold the Fable 5 standard.** It trains continuously: fine-tunes
on the project's shipped work, STUDIES references (tutorial transcripts, design
talks, screenshot libraries of the target games — Graveyard Keeper, Witchbrook,
Stardew, Eastward), INSPECTS them with the vision model against a fixed rubric,
distills observations into LEARNED_PRINCIPLES.md (review-gated into the Painting
Bible), and self-plays nightly via the flywheel with a never-regress ratchet.
Design principles are learned; ASSETS ARE NEVER COPIED from references. OWNER EXPANSION (same day): this law covers ALL DOMAINS — every studio role (painting, quests, barks, items, QA triage) trains under the same teacher-validators + academy + ratchet, toward finishing ALL registry todos at the Fable bar.

**ZERO-PURCHASE LAW (2026-07-05, owner):** NOTHING is ever bought. All assets verified-free; anything a paid pack would provide is instead scouted free (#101) or generated locally on the owner's GPU (ComfyUI). No held purchase questions may be raised again.

**FABLE-ONLY VISUAL LAW (2026-07-05, owner):** ALL level painting is done by
FABLE 5 PERSONALLY — zone composition, landmark placement, terrain dressing,
lore landmarks, CURIOSITY SITES, MURDER/CRIME SCENES, every vignette, every
visual pass. Drivers (Opus 4.8) and the local studio NEVER place or alter
anything visual: they may draft (studio def_author output = suggestion only)
but only Fable integrates visuals. Per-zone vignette quota under #100:
>=2 curiosity sites + >=1 murder/crime scene per zone, lore-derived.

**WITCHBROOK BAR (2026-07-05, owner):** capital cities, terrain and ALL visual assets at Witchbrook-level detail and density. Level polish is done BY FABLE personally (task division law). Every operation must be super cost-effective AND remain triple-A standard.

Every rule the owner has issued. Nothing ships that violates one. Status: ✅ live · 📐 designed · 🔄 in design · 🗓 planned · 🔒 deferred by owner.

## ⚑ THE PRIME MANDATE (obey at EVERY decision)
**THE MILLION COUNCIL**: a corps of ≥1,000,000 design bots (hierarchical divisions→brigades→squads, ledger at tools/design_council/) must reach consensus that every level meets THE OCARINA BAR — judged better than Ocarina of Time on cohesion, readability, wonder-per-screen, zero defects, soundscape and pacing. Consensus rolls up by unanimous delegation; any squad's NO blocks the level. MANDATORY.
**4K CAMERAS**: every level must be capturable in ONE 4K shot (RH_RES hook, live) + the full sweep grid.
**THE ASSET GAUNTLET**: every pack passes a 1,000-bot military review chain (unanimity, top-rank sign-off, promotion by validated decisions, General rotates every 3 rounds) — design/ASSET_GAUNTLET.md.

**Every level is agent-swarm QA'd for cohesion and beauty. No clipping. No floating assets. Nothing bad. ABSOLUTELY NOTHING.** Tons of inspection agents sweep every zone screen-by-screen; findings get fixed and re-swept until clean. Think like the first AAA 2D-pixel studio in history aiming to out-grade Ocarina of Time. This rule outranks all others and applies to every decision, every commit, every zone.

## ⚑ SUPREME RULES (latest owner session — see design/BACKLOG.md for the full 4am batch)
- **VERIFIED FREE ASSETS ONLY** — the absolute most mandatory rule of all; the Asset Gauntlet enforces
- **ANTI-HALLUCINATION LAW** — every directive/todo written durably (BACKLOG.md); a definitive resume point always exists
- **BE CHEAP** — minimal credit spend, exceptional output; caches, local compute, scripts before agents
- **SPELL-VFX UNIQUENESS** — spell VFX cannot repeat; palette swaps for spells ILLEGAL; unique per spell & creature
- **CONCRETE TOOLTIPS** — text states exactly what it does with numbers; "empowers you" banned; text must match effect
- Artifact/runeword display color = Diablo 2 dark gold. Max crafting skill 1000. Narrator = Diablo-2 Marius timbre. 1v1 arenas in every zone. 2,000 quests total. ≥1,000-hour game. 10k Sound Council over all audio.

## World & Zones
- ✅ 40 zones (WoW-Classic count), 2 continents, lore-bible accurate (WORLD_PLAN)
- ✅ Zones built from DOWNLOADED asset packs (22 style-gated packs; Dead Swamp/craftpix live)
- ✅ Every zone HAND-CRAFTED, detail-by-detail, level-appropriate hand-placed assets
- ✅ The 40-Second Rule (Witcher 3): validator + all live zones pass
- ✅ Zone-native creatures; 📐 zone-appropriate NPCs (~243 cast)
- ✅ Massive faction capitals; vendors + interesting cities (📐 SMART_NPCS)
- ✅ Zone-native weather (constant snow/tundra, rain/bog, ASH/volcanic…) + drift
- ✅ Zone themes + zone soundscapes (howling wind, swamp, birdsong…)
- ✅ Animation for EVERYTHING (GPU tree sway, ponds, bubbles live; every pack wires its anim sheets)
- 🗓 Dungeons (10, lore-grounded) + Raids (3, finale = the Bloodstone Pit)

## Story & Quests
- 📐 ~1000 interconnected quests: main/zone/side/dailies/events; GoT intrigue (no sexuality); WoW-calendar events on real dates, lore-adapted, each with a dark twist
- 📐 Villain = the Bloodstone (Lich-King tester): 16 touch-points, false victory, second-person inscriptions, Pit finale (transmit-vs-receive)
- 📐 TONE LAW: heavy-cheerful like THE WITCHER 3 — warmth that earns its dread; tonal budgets per zone type (QUEST_ARCHITECTURE) 
- 📐 Level cap 60, slow classic grind (~2.54M XP); every quest gives story progression
- 🔄 Class starting experiences that TEACH the class (WoW-style), zone-appropriate

## Combat, Classes & Progression
- 📐 Every mob a real fight that teaches the class (TTK 8-15s normal; COMBAT_PACING)
- 📐 Character stats: 5 WoW primaries (CHARACTER_STATS)
- 📐 Buff/debuff system incl. stacking procs (wolf-bite ×3 → Infected) (STATUS_EFFECTS)
- 📐 TONS of HIDDEN debuffs (35, 8 signatures, fairness laws — HIDDEN_DEBUFFS) — creature-specific, lore-apt, symptom-first surprises
- 🔄 Talent trees (3/class, 31-pt classic) + SAME NUMBER OF SPELLS AS WOW (~30/class) via SPELL TRAINERS
- MANDATE: each class's spells = AAA-studio quality — cohesive class palette, proper animations/VFX, from DOWNLOADED packs
- 🔄 Legendary weapon questline per class (mighty bosses; feat of strength)
- NO TRANSMOG — what you wear is what you see; every item looks EXACTLY like its icon (WYSIWYG law)
- Armor PROFICIENCIES: cloth/leather/mail/plate per class (WoW rules)
- 📐 Items: WoW progression, rarities common→blue→epic→legendary, loot WINDOW (rarity rolls)
- 📐 RUNEWORDS = artifact class (12 Underlanguage runes = the six symptoms; 10 artifacts; pity ramp — RUNEWORDS) above legendary; sockets; runes from biggest bosses at 0.5-2%, raid-rolled need/greed

## Crafting & Economy
- 🔄 WoW STRUCTURE, totally DIFFERENT crafts (Draconia professions); classic-ish progression, not a clone; crafting VENDORS
- MANDATE: FULL crafting animations from downloaded packs
- 📐 Loot tables per family×bracket; zone materials; 16 named rares live-zone set

## Mounts & Travel
- 📐 TONS of mounts — RACE/FACTION-appropriate: 31 designed incl. festival + raid mounts (MOUNTS)
- Riding skill; GROUND MOUNTS ONLY (classic law)
- ✅ WoW travel: waystations (discover→fast-travel), Grey Ferry continent link

## PvP & Social (Adventurer Sim pillar)
- 🔒 Bots = full smart "players" (parties → 40-man raids, chat, rolls) — dedicated design session with owner
- 🗓 Duels; ARENA (1v1 ONLY); open PvP; battlegrounds (Bloodroad supply war); guilds
- 🗓 World military PvP RANKS like WoW (lore-adapted ladder) + TITLES system

## UI & Presentation
- ✅ AAA 2D lighting: HDR-2D glow + shadow-casting lights ("ray tracing", honest 2D form)
- 📐 AAA Steam-polish OPTIONS suite (video/audio/gameplay/accessibility/rebinding)
- 🔄 THE MAP MASTERPIECE (mandatory, iterate forever): gothic Romanian parchment; v2 done.
  + WoW map behavior: player position ALWAYS known; ZOOM zone ↔ continent ↔ world; minimap same polish
- ✅ Spell tooltips; premium painterly ability icons; loot-window spec

## Engineering Law
- 🔄 EVERYTHING auto-QA-testable AND auto-improvable — every system ships with automated tests (headless asserts, windowed screenshot QA, build-time validators like the 40s rule) and an improvement loop (validator reports -> backfill -> re-verify). MANDATORY.

## Narrative & Cinematics
- 🔄 STORYTELLING VOICE: Tolkien / LotR register — wonder and awe — braided with Draconia dread (style guide + all quest text follows it)
- 🔄 THE GREAT BATTLE: a massive army set-piece where the player fights beside the faction their story followed — aim: one of the greatest battles in game history
- 🔄 FULL CINEMATICS: 6 act-chapter cinematics, DIABLO 2 STYLE (painted stills, slow pans, weary narrator) — pipeline: ComfyUI painted stills from the lore bible's own art prompts + Ken Burns + Maya1 narrator
- 🔄 TONS of in-game world cinematics (in-engine: camera rails, letterbox, scripted scenes)

## Freedom & Physics
- 🔄 GTA-grade player freedom (go anywhere, no artificial gates, emergent systems)
- 🔄 Real physics, Zelda-style: pushable/rollable/burnable world props, physical interactions that combine

## Audio & Voice
- ✅ Zone themes + biome ambience + weather SFX (17 files, credited)
- 🔄 Voice v2: Maya1 expressive acting, all 173 lines (bake self-healing in background)
- 🔄 HANS-ZIMMER-LEVEL score & ambiance: adaptive layered music (exploration/tension/combat stems), per-kingdom motifs, the WHOLE score built on the canon three-note Bloodstone melody (notes converge across acts as the broadcast nears — the soundtrack IS the villain)
- 🔄 ROCKSTAR-GRADE audio QA: automated LUFS loudness, loop-seam, clipping & spectral validators on every audio asset (feeds QA_AUTOMATION law)

## Achievements
- 🔄 MMORPG/WoW-style achievement system: categories (quests/exploration/dungeons/PvP/professions/feats), points, meta-achievements, title+mount rewards, toast UI, account ledger

## MANDATE (owner, 2026-07-07): EXACT HERO-SHEET STANDARD — LOCAL, FREE, NO TIME LIMIT
The local pixel-art model MUST become able to produce the EXACT quality of the reference
hero sheets (the Necromancer "Master of the Dead" 8-direction idle/walk/attack/cast/hurt/death
sheet + minions; the 7-class board; matching animated sprites). This is the STANDARD for all
Raven Hollow character/creature art. Static AND animated. Free/local only (owner at zero budget).
Time is NOT a constraint — do it right, not fast.

HONEST ENGINEERING NOTE (recorded so no future session repeats the lie):
A model can only learn quality that EXISTS in its training data. To output hero-tier sheets it
must be fine-tuned on hero-tier frames. The factory generating its own "decent" output can NEVER
reach hero tier by looping — it averages what it sees. The ONLY free path to the target is to
COLLECT a large corpus of REAL human-made hero pixel sprite sheets (CC0/CC-BY where license
permits), cut to frames, caption, and fine-tune on THAT. Blockers, tracked honestly:
  1. LICENSE: most hero pixel art is NOT free-to-train-on. Must verify per source (CC0 safe;
     CC-BY needs attribution; ripped game art / paid packs = NO). This gates dataset size.
  2. VOLUME: need thousands of clean hero frames of consistent style. Free CC0 hero art is scarce.
  3. ANIMATION+RIG: 8-dir consistency = ControlNet pose + Wan motion; still below hand-rig at hero tier.
Status: v1 style-LoRA training stood up (171 frames). Hero-tier is GATED ON DATASET, not on effort.
