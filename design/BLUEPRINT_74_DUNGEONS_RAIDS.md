# BLUEPRINT #74 — 10 DUNGEONS + 3 RAIDS (layouts + bosses, Fable design)
Opus executes; cave/dungeon zone tech is proven (lichenreach/chamber/pit).
Each dungeon = a zone def (cave biome unless noted) + creature table +
1 boss (new Enemy config w/ archetype + telegraph set from BLUEPRINT_33).

## The ten dungeons (level, zone-hook, gimmick, boss)
1. RAT CELLARS (L5, town tavern trapdoor): tutorial dungeon; SWARM packs;
   boss "The Tavern King" (boar BRUISER reskin w/ crown decal, comedy note).
2. THE FLOODED VEIN (L12, iron_vein mine shaft): water channels split paths
   (plank walks); LURKER ambushes; boss "Foreman Radu, Unpaid" (skeleton_
   warrior BRUISER, drops the first blue weapon).
3. CHAMBER TRANSMISSION FLOOR (L18, chamber_depths lower stair): the live
   stones PULSE on a 6s cycle — standing in stone light during pulse =
   debuff stack; boss "The Second Courier" (CASTER, interrupt tutorialized).
4. WOLF WARRENS (L24, whisper_passes den mouth): SWARM den; darkness (dim
   ambient, torch pickup mechanic v2); boss "Mother of the Pass" (wolf pack
   alpha + adds every 25%).
5. BLESTEM UNDERMAZE (L30, blestem dead-end alley): the maze DUNGEON —
   corridors of dark_keep walls, boot_prints as the trail mechanic; boss
   "The Listener Prime" (LURKER; stealth-opener on the PLAYER, reversed).
6. THE DROWNED CRYPT (L36, transcub_vale altar stair): water rising/falling
   room cycle (two zone variants swapped on timer v2 / static v1); boss
   "The Penitent" (CASTER + BRUISER phase swap at 50%).
7. FORGE BELLY (L42, sangeroasa forge district): lava_vent gauntlet lanes
   (vents pulse damage on the ember-light cycle — readable telegraph); boss
   "The Unpaid Debt" (pit-summoned BRUISER, arena ring around a mini-pit).
8. THE SALT CELLARS (L48, salt_fens salt-pan sinkhole): brine pools slow;
   boss "The Preserved" (skeleton_mage CASTER w/ SWARM preserved adds).
9. LEDGER STACKS (L54, the_archive west wing): filing-hall corridors of
   stone_rows; ledger_tablets buff enemies that stand adjacent (destroyable
   objective v2); boss "Chief Archivist Sabin" (CASTER, files a random
   player buff = steals it, returns it on death — v2 mechanic, v1 drain).
10. COLDHARBOR BLACK DOCK (L58, coldharbor_deep lower gate): pre-raid
    dungeon; boss "The Harbormaster" (BRUISER w/ crane-drop telegraph
    zones — reuse crane sprite + wedge decals).

## The three raids
R1. THE GREAT BATTLE STAGING (L60, famine_fields event zone): 10-man-scale
    wave defense w/ NPC allies (GREAT_BATTLE doc = the set-piece; raid =
    replayable version). 3 bosses: siege captain / twin shamans / warlord.
R2. THE ARCHIVE FINALIZATION FLOOR (L60, the_archive vault): 4 bosses incl.
    "The Collector's Ledger" (object boss: destroy tablets while adds file
    the raid — wipe = 'finalized' flavor). Unlock: attunement quest chain.
R3. THE BLOODSTONE PIT (L60 finale, bloodstone_pit inner ring): 5 bosses
    descending rings; final: LILITH'S VESSEL — 3 phases: (P1) thread-walker
    adds converge on pit; (P2) the VILLAIN_ARC transmit-vs-receive choice
    mechanic MID-FIGHT (two interactable stones alter the fight per
    VILLAIN_ARC.md finale); (P3) burn phase under rows-of-twelve gaze
    (the twelve animate at 10% — the session's best dread image, paid off).

## Tech notes for Opus
- Dungeon zones: normal zone defs, "dungeon": true → no waystation, no
  weather, single entrance travel_point, denser creature tables, one
  "boss_spawn" key consumed by Combat.spawn like enemy_spawns.
- Boss = enemy.gd config + "boss": true (bigger nameplate, HUD bar hook,
  loot table roll from LOOT_TABLES named-rare pool, music sting).
- Respawn/lockout v1: dungeon resets on zone rebuild (natural); raid
  lockout = save flag per week (DayNight day_index / 7).
- Build order: 1 (tutorial) → 2 → boss framework → 3-10 → R1 → R2 → R3.
  Acceptance per dungeon: full clear video via RH_WALK bot + boss telegraph
  visible in stills + loot drops verified.
