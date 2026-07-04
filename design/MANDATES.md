# OWNER MANDATES — master ledger (single source of truth)
Every rule the owner has issued. Nothing ships that violates one. Status: ✅ live · 📐 designed · 🔄 in design · 🗓 planned · 🔒 deferred by owner.

## ⚑ THE PRIME MANDATE (obey at EVERY decision)
**Every level is agent-swarm QA'd for cohesion and beauty. No clipping. No floating assets. Nothing bad. ABSOLUTELY NOTHING.** Tons of inspection agents sweep every zone screen-by-screen; findings get fixed and re-swept until clean. Think like the first AAA 2D-pixel studio in history aiming to out-grade Ocarina of Time. This rule outranks all others and applies to every decision, every commit, every zone.

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
