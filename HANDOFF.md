# HANDOFF — Raven Hollow (for any AI session or human continuing this project)

Last updated: 2026-07-03 (by Claude Fable 5, before the July 5 model sunset). Read this FIRST, then
ASSET_MANIFEST.md (verified sprite geometry — never guess sheet layouts), SPEC_PHASE_B.md,
SPEC_PHASE_C_DEMO.md, CREDITS.md.

## What this is
A Graveyard-Keeper-styled medieval pixel RPG in Godot 4.6.3, set in the user's own dark-fantasy universe
**Draconia** (lore PDFs at `..\Draconia_Lore_Bible.pdf` + `..\Draconia_HOME_BRIEF.pdf` — 115-page canon;
Raven Hollow is a human border village in the Long Vigil era). The user (GitHub: kriggar,
vstefan19@gmail.com) is preparing a **Kickstarter demo for July 7, 2026** on itch.io.

- Private code repo: https://github.com/kriggar/raven-hollow (never make public — asset licenses forbid
  redistributing raw packs; compiled game is fine).
- Public site: https://kriggar.github.io/raven-hollow-site/ (repo raven-hollow-site; source mirror in docs/).
- Godot exe: `C:\Users\EIT\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe`

## State at handoff (see git log for exact truth)
SHIPPED & verified: Phase A (6 classes w/ ability kits LMB/Q/R, mouse-aimed; enemies: graveyard skeletons,
orc camp, training scarecrow; HUD; class select; bustling town, 19 NPCs, dialogue), Phase B (items,
WoW backpack I, paper-doll sheet C, drag&drop, rarities, 5 seeded legendaries incl. Draconia's Bloody
Dagger, visible weapon + armor tints), B.1 (WoW unit frames w/ live sprite-crop portraits, click-to-target,
target frame, creature nameplates, Shift-sprint).
IN FLIGHT at write time: B.2 (animated spell VFX from downloaded packs via new fx_library.gd; pixel icon
overhaul via icons_pixel.gd + Shikashi sheets; WoW corner bag button). Then B.3 (town composition polish —
props must look OWNED: barrels→doorways, hay→barn, logs→smithy; user's explicit demand).
NEXT: Phase C demo build per SPEC_PHASE_C_DEMO.md (gate, wilderness, 5 lore quests, XP cap 10, day/night,
minimap+M map, save/load, main menu). Then July 5-6: balance, user QA, Windows export
(export templates needed!), press kit. July 7: itch.io.

## Architecture (everything built in code; only scenes/main.tscn exists as a scene)
scripts/: main.gd (bootstrap: class select → TownBuilder.build → Player/NPCs/enemies → UIs → camera/dusk/
music/vignette + RH_* automation hooks) · town_builder.gd (static build(parent)→{player_spawn, npc_spawns,
bounds}; seeded RNG; pixel-verified atlas rect consts) · player.gd (CharacterBody2D; MOTION_MODE_FLOATING;
class kits; casting; inventory/gear; targeting; sprint) · enemy.gd, npc.gd, combat.gd (projectiles, spawns),
class_defs.gd (pure data), vfx.gd (+ fx_library.gd post-B.2), sheet_anim.gd (SpriteFrames factory — pins
verified sheet geometry), hud.gd, dialogue_ui.gd, class_select.gd, npc_data.gd, items.gd, inventory.gd,
bag_ui.gd, character_sheet_ui.gd, item_tooltip.gd, icons_pixel.gd (post-B.2).
CanvasLayer order: vignette 5 < HUD 8 < bag/sheet 9 < dialogue 10 < select backdrop 15 < class select 20.
Collision layers: walls 1, player 2, npcs 3, enemies 4. Szadi chars: side faces LEFT; feet offset (0,-15).
Enemy sheets face RIGHT. 640×360 viewport, integer scale, nearest.

## The build method that works (keep using it)
Multi-agent workflows: parallel builders with STRICT file ownership + a pinned interface contract in every
prompt → integration agent (headless smoke loop + windowed screenshot verification, must READ the pngs) →
1-2 adversarial reviewers (read-only) → fixer. Builders must PIL-verify sprite geometry before hardcoding
rects. Session limits kill runs — resume with Workflow({scriptPath, resumeFromRunId}); errored agents
re-run, completed ones cache. Never let two concurrent workflows edit the same files. Never let agents
touch project.godot (coordinator edits it inline).

## Test/screenshot harness (main.gd env hooks; run WINDOWED for pixels, headless renders nothing)
RH_SMOKE=1 (60-frame boot test, headless OK) · RH_CLASS=<id> (skip class select; ids: warrior rogue mage
paladin necromancer rookwarden — display name "Hunter") · RH_SHOT=path (save png ~40 frames, quit) ·
RH_ZOOM=0.22 + RH_FOCUS="x,y" (framing; RH_FOCUS teleports player) · RH_WIDE · RH_NOBANNER=1 ·
RH_TALK=1 (auto-dialogue) · RH_CAST=attack|skill_1|skill_2 (teleport near scarecrow (1650,950), cast 3×) ·
RH_UI=1 (+RH_EQUIP="0,3") opens bag+sheet. Screenshots → _screens/.

## Assets (all licenses verified; full geometry in ASSET_MANIFEST.md)
In-game: Szadi Fantasy Lands buildings + 3-dir NPCs (style anchors), Cainos terrain/trees, LPC decorations
(CC-BY-SA — attribution mandatory, see CREDITS), Pixel Crawler enemies, painterly icons (being replaced by
Shikashi pixel icons in B.2), Alagard font, Ninja Adventure CC0 music.
Staged for Phase C+ in _downloads/ (gitignored, LOCAL ONLY — re-download via research notes if lost):
wilderness/ (LPC wolf/boar/bears/deer/farm animals, Admurin monsters+Gollux boss, Szadi RPG Worlds Caves
9/10 + Rogue Fantasy Catacombs 8/10 for the dungeon, Hyptosis tiles, castle gate sheet, CraftPix undead +
cursed-land biomes) · vfx_packs/ (46 packs: Pimen fire/dark/holy/ice/thunder/wind/earth/smoke/smears/hits,
Frostwindz class kits, BDragon1727, Foozle, XYEzawr — mapping table in the B.2 workflow script) ·
char_creator/ (Mana Seed demos; the $19.49 Farmer Sprite System = the approved Witchbrook-style character
creation path, purchase pending user).

## User's design law (violations get called out fast)
Style gate is MANDATORY: muted earthy palette, realistic proportions, NO chibi, NO flat-minimal; Szadi
Fantasy Lands is the anchor. When the user names a game (WoW/D2/GK/Witchbrook), they mean it literally.
Props must look OWNED, not scattered. NEVER hand-edit or derive new sprite frames (user forbade it);
runtime tints/palette swaps OK. One focused improvement pass at a time, each verified with screenshots.
Progression: SUPER SLOW, cap 60 (demo cap 10). PvP later — keep combat faction-tagged source→target.
Runewords = D2 rules with the Underlanguage (Ash/Ember/Raven/Grave/Thorn/Mist/Oath/Hollow). Spell system
target: LoL-size bar + WoW spellbook (P) + trainers for gold. Many biome maps later (map registry built for
it in Phase C). Races decision pending: A = Draconia peoples (Human/Strigoi/Varcolac/Iele w/ tints+racials
+NPC reactions — recommended) vs B = human bloodlines.

## Memory
Fuller history in `C:\Users\EIT\.claude\projects\c--Users-EIT-Desktop-rpg\memory\` (MEMORY.md index →
project_medieval_rpg_gk.md, project_draconia_lore.md, feedback_style.md). Machine-local; this file is the
portable version — keep BOTH updated on major changes.
