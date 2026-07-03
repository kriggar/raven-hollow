# Phase C (Demo Scope) — Wilderness, Quests, Systems — SPEC

For the July 7 Kickstarter demo. Post-demo Phase C items (character creation, races, Druid) are NOT here.
Lore source: the Draconia canon (see memory / user's Lore Bible). Era: the Long Vigil. Tone law: dread is ambient;
no quest offers a clean win; the Underlanguage symptom ladder is canon (ground warms → wells copper → yeast dies →
dust aligns → people "listen").

## 1. Map system (future-proof, demo ships 2 maps)
- `scripts/map_registry.gd` (class_name MapRegistry): static defs `{id, display_name, builder (Callable returning the same dict TownBuilder.build returns), music, dusk_tint, travel_points: [{id, pos, radius, to_map, to_point, prompt}]}`.
- `main.gd` refit: `change_map(map_id, entry_point_id)` — fades out (0.4s black), frees World, builds new map, places player at entry, fades in. Camera limits from new bounds. Enemies/NPCs per map builder.
- Maps: `town` (TownBuilder, existing) and `wilderness` (new WildernessBuilder).

## 2. The town gate
- East edge of town (end of the smithy road, ~x 2200): stone gatehouse composited from `_downloads/wilderness/gate/castle2.png` (two arched gatehouses with portcullis pixel-verified in that sheet) + wall segments flanking into the border forest. Warm lantern each side.
- Travel point at the arch: prompt "[E] The Emberfall Road — Wilderness". Guard NPC ("Gatewarden Iosif") beside it with dialogue warning about wolves and the night.
- Matching return gate/waystone on the wilderness side.

## 3. The Wilderness map (WildernessBuilder, ~70x55 tiles)
- Terrain: same Cainos grass base but wilder mix (more tufts, fewer flowers); winding dirt road west→east; small clearings.
- Density: heavy border + interior forest (Cainos trees + LPC trees + Hyptosis gnarled/dead trees mixed; thickets as collision walls shaping 3-4 natural "rooms").
- Set pieces: (a) hunter's abandoned camp (LPC tents/campfire, lootable later), (b) standing stones / dolmen (Hyptosis) with faint carved runes — LORE SPOT, (c) boar wallow clearing, (d) wolf den at NE (dead trees, bones from CraftPix undead pack sprinkled), (e) orc camp SE (moved OUT of town map: relocate the Phase A orc camp here, bigger: 6 orcs + banners/tents), (f) the LISTENER spot at the far east treeline (see quest 5).
- Fauna/enemies (LPC animal sheets at `_downloads/wilderness/animals/` — geometry in research notes; enemy.gd config style):
  - Wolves ×5 (wolfsheet, 4-dir walk/run/bite/die — full 4-dir enemy!), hp 26, dmg 7, fast.
  - Boars ×4 (wild_boar: walk/stand/attack/die 4-dir), hp 40, dmg 9, charge-ish (higher speed when aggroed).
  - Bear ×1 (lpc2022 grizzly, walk/attack/die): mini-boss of the wolf den, hp 120, dmg 16, slow. Nameplate "Old Mother" (she guards the den).
  - Deer ×4 + fox ×2 + rabbits ×3: AMBIENT (flee from player within 60px, never fight — sells the forest as alive).
  - Birds: 2-3 ground birds that fly off when approached (LPC birds fly anim).
- Day/night matters here: at night wolves' aggro radius doubles (see §6).

## 4. Quest system
- `scripts/quest_defs.gd` (data) + `scripts/quests.gd` (class_name Quests, state machine on the player or a group singleton) + tracker UI in hud.gd (top-right under minimap: quest name gold + current objective parchment, max 2 tracked).
- Objective kinds: `talk(npc_id)`, `kill(enemy_type, n)`, `reach(map,pos,r)`, `choice(a,b)`, `use_item(id)`. Quest states persist via save.
- NPC integration: npc.gd gains optional quest hooks — "!" gold marker above quest givers (Alagard "!"), "?" when ready to turn in; dialogue extended per quest state (quest_defs supplies extra dialogue pages per state).
- Rewards: XP + gold placeholder + item into bag.

## 5. The five demo quests (from Draconia canon, Long Vigil era)
1. **"The Well Went Copper"** (main hook; giver: Innkeeper Marta): the inn's water tastes of copper (canon symptom #2). Objectives: inspect the plaza well (reach) → find a charcoal rubbing of ANGULAR RUNES someone scratched on the wellstone (auto-item) → bring it to Vasile the gravekeeper (talk) — he burns it without reading it: "You don't READ what the ground writes. That's how it gets in." → check the old cemetery at night (reach) → put down 4 graveyard skeletons (kill). Reward: XP + uncommon ring + Vasile's warning that the Pause "is a bookmark, not an ending". Sets the demo's tone.
2. **"Fresh Hay, Old Bones"** (giver: Farmer Ansel): something tears up the north field by night — cull 3 boars in the wilderness (kill; forces first gate trip). Turn-in: Ansel finds wolf tracks TOO — hook to quest 4. Reward: XP + Traveler's Boots (uncommon).
3. **"The Blade That Won't Dry"** (giver: Blacksmith Goran; moral-gray, canon Bloody Dagger echo): Goran forged a dagger for a customer who never came back; it will not stay clean — blood beads on it overnight. Take it to Vasile (talk) → CHOICE: bury it in the old cemetery (reach + use_item; reward: XP + Goran's gratitude + rare shield) OR keep it (you keep a legendary dagger; Goran won't meet your eyes again; Vasile: "Everything that stays sharp is waiting for something."). No clean win.
4. **"What the Rooks Saw"** (giver: Old Petra): the rooks circle the east woods and will not land — something camps on the old road. Scout the orc camp (reach) → CHOICE: strike now (kill orc shaman; reward: XP + epic trinket, camp thins) or slip away and warn the town (talk Gatewarden; reward: XP + gold, guards posted — cheaper but safer). 
5. **"The One Who Listens"** (endgame of demo; auto-trigger near the far-east treeline OR from Marta after quest 1): a villager — Mira, the miller's daughter — stands frozen at the treeline, head tilted, eyes open, LISTENING (canon affliction). Objective: lead her home (escort-lite: she follows if you stay within 40px; wolves may aggro once). At the gate she whispers ONE sentence in a language that isn't hers — the screen dims a beat — then she remembers nothing. Quest "completes" unresolved: journal entry reads "The ground is patient." **This is the demo's final beat and the Kickstarter cliffhanger.**

## 6. Systems (demo scope)
- **XP/levels**: cap 10 for demo. Slow curve: L2=100, then ×1.6/level (~L10 total ≈ 7.5k). Kills: skeleton 12, orc 18, wolf 10, boar 14, bear 60; quests 50-150. Level-up: +6% hp/mana, +1 damage, full heal, gold VFX burst + "Level N" banner. (Cap 60 + trainers = post-demo.)
- **Day/night**: 10-min full cycle starting 17:00 dusk. CanvasModulate lerps through: day (1.0,0.97,0.9) → dusk (1.0,0.87,0.72) → night (0.62,0.66,0.85, darker) → dawn gold. Lanterns/fires: light energy ramps up at night (lights registry in builders). Night: wolf aggro ×2, town NPCs head to inn/homes (wander targets shift), Listener quest spot only triggers at night. Clock in HUD (small Alagard "17:20" under minimap).
- **Minimap** (top-right, ~64px square, dark-wood frame): prerendered map texture per map (RH full-map capture piped through at build time — generate once per map via SubViewport OR ship the existing fullmap PNGs downscaled at `assets/art/maps/<id>.png`), player gold arrow, NPC yellow dots, enemy red dots, travel point markers. **World map (M)**: parchment-framed full map with district labels (Alagard), player marker, quest pins.
- **Save/load**: `scripts/save_system.gd` — JSON at `user://save1.json`: map id, player pos/class/hp/mana/xp/level/gold, inventory bag+equipped (item ids), quest states, time-of-day. Autosave on map change + quest turn-in; manual save in pause menu. Load = boot to saved map. (Enemies respawn on load — acceptable demo behavior.)
- **Main menu + pause**: title screen (town fullmap art dimmed behind, "Raven Hollow" Alagard 40 gold, New Game / Continue (if save exists) / Quit; version string "Kickstarter Demo"). Esc in-game: pause panel (Resume / Save / Settings-lite: music volume slider / Quit to Menu). Class select shows after New Game.
- **Audio**: keep town theme; wilderness uses theme_plain.ogg; night layers wind? (only if trivial). SFX pass is post-demo except: UI click, level-up chime (synthesize or skip).

## 7. Build order (workflows)
1. B.2 (spells/icons) → 2. B.3 (town polish) → 3. C-demo workflow: builders = map-system+gate, wilderness, quests+dialogue-hooks, systems (xp/day-night), minimap+worldmap, save+menus; then integrate (headless + screenshot verify: gate prompt, wilderness fauna, quest tracker, night town, minimap, menu) → review ×2 → fix.
Keep ALL interface contracts from prior phases. Never touch project.godot except NEW input action "map" (M) + "pause" (Esc = ui_cancel exists) — add via coordinator before launch.
