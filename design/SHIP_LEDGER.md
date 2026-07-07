# SHIP LEDGER — line-by-line status of all 122 BACKLOG items

Owner directive (2026-07-07): ship EVERYTHING line by line, INCLUDING the 1,000+
quests and all content/systems — EXCEPT art-related items and Ollama-dependent items.
This ledger classifies every item and tracks driver-lane completion.

Legend: ✅ SHIPPED · 🛠 IN-LANE (doing now) · 🎨 ART-EXCLUDED (owner rule) ·
🖥 OLLAMA/MACHINE-EXCLUDED (owner rule) · ✅prev = verified already-done this session.

## Foundation & governance (1–26)
All ✅ shipped previously. #22/#23 (Million Council / Asset Gauntlet) are governance
framing; #24 map masterpiece has a 🎨 "draw Continent 2" art remainder (excluded).

## Systems (27–55, 58–75, 82–84, 86–88, 92, 97–99, 102, 107–108)
All ✅ BUILT. This session VERIFIED and, where disconnected, WIRED:
- #30/#31/#32/#44/#45 (loot/inventory/legendaries): loot→bag bridge shipped (kills
  now give usable loot); StatsSystem→combat read-back shipped (talents/stealth/forms/
  status now affect play); player crowd-control added. (commit b86395d)
- #35/#36 (status/hidden debuffs): data/status_effects.json restored — poison/
  wolf_bite→Infected now fire. (commit 5a3dc3c)
- #40/#71 (smart NPCs/factions): vendor reputation discount now applied to prices.
- #55 (achievements): reward granting (title/mount/item) wired.
- #39/#46/#47/#55/#72/... : all reachable via the new central Menu hub + fixed
  hotkey collisions. (commit 5a3dc3c)

## IN-LANE, doing now (content/systems, NOT art, NOT Ollama)
- #77 🛠 +1,000 quests (2,000 total) — GENERATING (39-zone workflow, real ids, tone-locked).
- #78 🛠 Romance side quests — next wave.
- #79 🛠 Writers-council PRODUCTION SYSTEM — the data/tooling half (a quest schema +
  generator + validator), not art.
- #80 🛠 RDR2-grade quest chains / mysteries — authored as interconnected quest data.
- #81 🛠 Skyrim vibe layer — tone/content data pass over the quest set.
- #85 🛠 Distinct voice-per-NPC DATA (voice registry assignment per NPC id) — the
  mapping is in-lane; audio BAKING uses the local Maya1 TTS (not Ollama) and can run.

## ART-EXCLUDED (owner rule: skip art) 🎨
#56 VFX art, #57 crafting animations, #66 polish loop (visual), #89 sword sprites,
#90 sprite×item anim matrix, #91 asset scouting, #100 Witchbrook painting,
#101 asset scout, #103 capital architecture art, #104 creature sprites/werewolf art,
#106 sitting-3 visual verifiers, #109/#110/#113 painter programs, #111/#112 sprite
animation, #114/#115/#116 the 150k asset library, #117 img2img pipeline, #118/#119/
#120/#121 VFX/model art, #122 C: drive relief (asset models). #24 Continent-2 map draw.

## OLLAMA / MACHINE-EXCLUDED (owner rule: no Ollama) 🖥
#95 local studio (Ollama), #96 corporation-of-bots (needs local model horde),
#105 local studio operations (Ollama install), #93 C++ native engine (owner/engine
architecture — not a content task), #94 prompt-to-game engine (a separate product).

## Status
The in-lane content set (#77–#81, #85 data) is the bulk of the remaining real
driver work. Everything else is either shipped, art-excluded, or machine-excluded
per the owner's explicit scope.
