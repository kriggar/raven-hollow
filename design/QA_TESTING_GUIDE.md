# Raven Hollow — QA Testing Guide

How to reach and test every built system in-game. Keys verified against project.godot
[input]. Panel keys F1/F2/B are self-bound by their systems (not in the input map, so
never swallowed).

## Movement & combat
| Key | Action |
|-----|--------|
| W A S D | Move |
| Mouse / attack | Attack |
| Q R F 1 2 3 4 | Skills 1-7 (class abilities) |
| Z | Sheathe/draw weapon |
| Tab | Sprint |
| E | Interact / talk to NPC |
| Space | Advance dialogue |

Rogue kit lives on the skill keys: Shroud (stealth) = **2**, Backstab (assassinate) = **Q**,
Shadowstep (vanish) = **R**, Noxious Vial (poison) = **F**. Druid Bear Form = **3**.

## Panels (press the key anywhere in-game)
| Key | Opens |
|-----|-------|
| **I** | Inventory / paperdoll |
| **C** | Character sheet (stats) |
| **P** | Spellbook / talents |
| **M** | Map (3-tier zoom, fog-of-war, pins) |
| **B** | Bestiary codex (63 creatures, signatures, lore) |
| **F1** | QA console (text commands) |
| **F2** | ADMIN / QA HUB (the master test console) |

## The F2 master QA hub — test everything from here
Four tabs:
- **WORLD** — teleport to any of 40 zones, set time (0-23h), set weather.
- **PLAYER** — set level / gold / HP, grant any item, learn any ability.
- **SYSTEMS** — toggle seamless-world, fog (RenderFX), godmode; list autoloads; Run Smoke (pings every system).
- **CONTENT** — spawn any creature, enter any dungeon, fire any cinematic, start the Great Battle, give a quest.

## F1 QA console commands
`help · give <item> · gold <n> · tp <zone> · heal · godmode · spawn <enemy> · smoke · sysinfo · clear`

## NPC-gated systems (walk up, press E)
| Talk to | Tests |
|---------|-------|
| Trainer | Learn class abilities (level + gold cost) |
| Auctioneer | Auction house (list/buy) |
| Banker | Bank (gold + item storage) |
| Stablemaster | Mounts (31, summon/speed) |
| Vendor / shopkeeper | Buy/sell shop |
| Quest giver | Accept/track/turn-in quests |

## Systems that fire during normal play (no key — just play)
- **Class select** — New Game → "CHOOSE YOUR CHAMPION" (D2 screen) → pick → spawn → intro cinematic.
- **Music director** — swells to combat/boss when enemies are near; zone beds on travel.
- **Narrative** — lore toasts on first zone entry; NPC barks; chronicle journal.
- **NPC life** — town NPCs bark, chatter, walk job routes, rest at the inn at night.
- **Bestiary** — when a creature hits you, its unique signature debuff lands + it enters your codex (B).
- **Loot** — kill enemies → rarity-colored drops → loot window.
- **Factions/rep, Calendar/festivals, Achievements, Titles** — accrue as you play.
- **Dungeons/raids** — enter a dungeon entrance (or F2 → CONTENT → enter dungeon).
- **Grey Ferry** — a ferry dock → travel + voyage cutscene.
- **Secrets** — combine ritual items at the right shrine.
- **Physics props** — push/break pots & crates near zone spawns.
- **Great Battle** — enter gravemark_field (or F2 → CONTENT → start battle).
- **Seamless world** — OFF by default; F2 → SYSTEMS to enable edge-streaming.

## Headless screenshot hooks (for automated QA)
`RH_CLASS=<class> RH_MAP=<zone> RH_SHOT=<path>` boots straight to a zone.
Panel screenshots: `RH_ADMIN=1`, `RH_BESTIARY=1`, `RH_SELECT=1`, `RH_AUCTION=1`, `RH_BANK=1`.
Cast a skill: `RH_CAST=skill_N`. Fog demo: `RH_FOG=1`.
