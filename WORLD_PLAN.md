# DRACONIA WORLD PLAN — 40 Zones · 2 Continents
Canon source: `../Draconia_Lore_Bible.pdf` (Part IV — World & Regions, 03-regions.md).
Mandates: **WoW-Classic zone count (40)** · **2 continents** · **every zone hand-crafted & alive** ·
**built from downloaded pack assets (Szadi/Cainos-style, 32px, Graveyard-Keeper palette)** ·
**zone-native creatures** · **massive faction capitals** · **lore-accurate**.

## Canon ground rules (apply to EVERY zone)
- **Warm is wrong.** Warm-ground patches (subtle shader/decal) mark Underlanguage activity; nearby wells copper, dust lies in parallel lines. Players read the land.
- **Bodies as signage.** Each faction's dead are arranged in their own grammar (Strigoi: rows of twelve; Varcolaci: worked-to-death in pits; Iele: standing still; humans: buried, missed).
- **No safe region.** Each capital is a predator with a different appetite.
- **Inscription-stone network** threads every wild zone: standing stones that seed the command-virus. Interactable — examining is the vector (curiosity kills). Detection grammar: blue=necromantic, violet=sub-terrestrial, green=thermal(waking), shifting-orange=live signal.
- **Hand-crafted = authored layout data per zone**: landmark anchor list, road/river paths, and ≥3 lore vignettes (environmental set-pieces from the bible) placed by hand in each zone def. No uniform noise-soup.
- **Alive =** zone-native creature spawn tables (day/night variants), ambient fauna, NPC pockets with barks, weather per biome.

## Cardinal layout (canon): Blestem=EAST (Strigoi), Sangeroasa=SOUTH (Varcolaci), Black Night=NORTH (Iele/undead), Angel Wings=WEST (Humans), Border/Vetka=interior seams, Greyhollow=Collector-era (Continent 2).

## Zone size targets
- Wilderness zone: **256×192 tiles** (8192×6144 px) minimum.
- Capital city: **320×256 tiles** (10240×8192 px), district-structured (MASSIVE).
- Dungeon zone: 128×128 interior.
Engine: culled TileMapLayers + proximity spawns (perf pattern already proven in-repo).

---

# CONTINENT 1 — DRACONIA (Year 0) — 26 zones

## Interior Seams — Border Region (starter, 6)
1. **Raven Hollow** *(exists — becomes a Border-Region village zone; keep)*. Biome: fogged village. Creatures: boars, wolves, skeletons (graveyard).
2. **Vetka** — starter village: mud, thatch, herb-woman's cottage (Old Marta), doomed neighbors (Torn, Dorica, Gren). Landmarks: Marta's cottage, the Bent Oar approach. Vignettes: farmer "resting" since Tuesday facing the Chamber; flat grey bread at the inn; aligned dust. Creatures: none hostile at first — **the first monster is a symptom** — then freshly entranced villagers, boars.
3. **The Iron Vein** — bog-valley along the slow metallic blood-colored river. Landmarks: the Bent Oar tavern (hub, quest board), river fords, drowned holdings. Creatures: bog-boars, mudwolves, thread-touched dead (drifting from north), the Digging Creature (apex, rare night spawn).
4. **The Copper Wells** — poisoned-well moors; environmental puzzle-tutorial (read the land). Landmarks: well clusters (copper/clean), inscription stone crossroads (worn boundary-stone, aligned grass, 3 empty unlooted farmsteads). Creatures: entranced pilgrims, ravens, digging-creature tunnels.
5. **The Chamber Depths** *(dungeon)* — buried Underlanguage transmission site beneath Vetka. The Courier's corpse (satchel sealed, no wounds, clean fingernails). Command-script walls, warming stone. Creatures: none at first (dread), then walls "listening", late thread-shells.
6. **The Stonepath** — inscription-stone crossroads wilds linking all four kingdoms. Landmarks: the shortening inscription (dead man's handprint, marks fading), stone rows. Creatures: listeners, entranced, wolf packs.

## WEST — Angel Wings (Humans, Queen Fielderine) (5)
7. **Angel Wings** *(CAPITAL — MASSIVE)* — poor, crowded, ordinary river-capital. Districts: the Lead Vault (a room designed around NOT using power), Maren's Orphanage (safe-house; chalk handprints wall — one faintly copper-stained), river docks, grain markets, thatch sprawl. Creatures (outskirts): bandits, hungering cultists.
8. **The Western Lowlands** — river-country farmland, thinnest fog, mud/woodsmoke/thatch. Vignette: famine-village with a FULL granary. Creatures: bandit-lords' gangs, the hungering (neighbors walking east), river fauna.
9. **The Grey Marches** — dying-forest frontier shading into Border. Grey needle-forests. Creatures: greywolves, desperate cults, hungering caravans.
10. **The Famine Fields** — stone-engineered hunger belt. Vignette: lead box in a burned farmstead, scratch-marks inside. Creatures: cult ambushers, starving dogs, crows.
11. **Riverfork** — Iron Vein delta, bridges + toll posts. Creatures: bandit chiefs, river-drakes (bestiary-consistent bog fauna), smuggler NPCs.

## NORTH — Black Night (Iele / undead, Lilith) (5)
12. **Black Night** *(CAPITAL — MASSIVE)* — blue-black stone, NO fog, unnaturally clear air, bitter cold. Districts: the still market (Iele standing in rows of twelve), Council of Six halls (Vasile/Radovan), Thread-lit streets (blue filaments), the Black Night canopy of un-light. Creatures: thread-driven Iele shells (harmless until directed), the entranced.
13. **The Threadlands** — tundra threaded with visible blue Thread filaments; pilgrim roads north. Vignette: abandoned family camp — 3 bedrolls, cold uneaten stew, footprints in, none out. Creatures: thread-shells, entranced pilgrims, snow-wolves.
14. **The Listening Steppe** — wind-scoured steppe where the drawn stand "listening". Creatures: entranced clusters, ravens, the Digging Creature.
15. **Gravemark Tundra** — Great-War mass graves; kerb-stones carved with Underlanguage. Creatures: thread-touched dead, bone-hounds, skeleton warbands.
16. **The Grave & Bloodstone Pit** *(dungeon, endgame)* — Lilith's tomb over the Thirsty Stone. "47 years… they gave me a pit." Creatures: Iele guards, the stone's arrangements; boss: the Pit itself (orange signal).

## EAST — Blestem (Strigoi / vampires, Cazimir) (5)
17. **Blestem** *(CAPITAL — MASSIVE)* — black maze-city in a ridge-cleft, perpetual dusk, lamp-oil + pale bioluminescence. Districts: the Black Spire (windowless, violet-black; orange bleed at base), the Riddler's Quarter (disorientation-engine dungeon district), the Lower Market (information as hard currency), Churches of Transcub (ivy-eaten). Vignette: 12 boot-prints facing a dead-end wall. Creatures: Strigoi enforcers, listeners, the walled.
18. **The Eastern Ridges** — Carpathian spine, fog at shoulder height on passes. Creatures: strigoi patrols, cliff-bats, mountain wolves.
19. **Lichenreach** *(cave zone)* — wet-stone caverns of luminous lichen (Strigoi export). Creatures: bat swarms, cave-strigoi, the walled (in the dark).
20. **The Transcub Vale** — valley of the old god's ivy-eaten temples; confession vignette ("I only wanted to know what it said" — warm altar). Creatures: temple ghouls, penitent cultists.
21. **The Whisper Passes** — high trails with listener watch-posts; sound carries strangely. Creatures: listeners, strigoi assassins, rock-vipers.

## SOUTH — Sangeroasa (Varcolaci / werewolves, Valrom) (5)
22. **Sangeroasa** *(CAPITAL — MASSIVE)* — volcanic forge-city, hundreds of hammers, red haze. Districts: the Debt Pit (labor-and-death organ; ledger nailed at rim, dead marked "collected"), the Killing Floors & Blood Channels, forge rows, Valrom's keep. Vignette: all hammers stop for a count of three. Creatures: varcolaci pit-bosses, forge-thralls.
23. **The Gift** — impossibly red fertile bands grown from Great-War dead. Vignette: child's shoe in a furrow beside a good harvest. Creatures: varcolaci field-wardens, blood-fattened boars, carrion birds.
24. **The Ashvents** — active vent fields, warm rivers (heat hides the signal here — canon problem zone). Creatures: slag-walkers (dead workers still working), ash-hounds.
25. **Basaltfang Range** — black basalt ridges; varcolaci hunting packs under the haze. Creatures: varcolaci hunters, obsidian wolves, cliff shamans.
26. **The Bloodroad** — arsenal supply road north; war-caravans, toll-forts. Creatures: varcolaci convoys, deserters, war-dogs.

---

# CONTINENT 2 — THE COLLECTOR'S COAST (Collector era, ~1000 yrs on) — 14 zones
Canon frame: Greyhollow is "a fifth tense — the drowned future the map grows into." Continent 2 IS that future: the Archive's cure curdled into the Debt System. Travel between continents = era-crossing voyage (the drowned ledger route).

27. **Greyhollow** *(CAPITAL — MASSIVE)* — brackish canal-port; gaslight that doesn't reach the ground. Districts: the Pit (cold clerical finality over black water), Greyhollow Records (Marrow Pell, the dead broker), Morven surveillance quarter, pier sprawl. Vignettes: cracked debt-tablet washed up warm; ledger line stamped/un-stamped/stamped; chalk handprint with a Morven mark around it. Creatures: the finalized, Morven agents, canal-things.
28. **The Drowned Quarter** — flooded district, roof-top paths. Creatures: the finalized (submerged, surfacing), debt-wraiths.
29. **The Canal Maze** — circulatory/disposal waterways. Creatures: canal-things, smuggler gangs, collector-constructs.
30. **The Grey Piers** — rotting harbor of grey never-quite-alive wood. Creatures: dock gangs, salt-ghouls, moor-eels.
31. **The Salt Fens** — brackish fog marshes ringing the port. Creatures: fen-lurkers, marsh finalized, salt-crows.
32. **The Dead Timber** — the old dying forests, here fully dead; logging ruins. Creatures: grey-wood stalkers, sap-less ents (bestiary-consistent), feral dogs.
33. **The Ledger Roads** — toll roads with debt-checkpoints. Creatures: collection-agents, road bandits, the recently-finalized.
34. **Morven Reach** — intelligence district / safehouses (Sabira's lineage). Creatures: Morven blades, informant-shells.
35. **The Archive** *(city zone)* — Black Night calcified into a cold debt-bureaucracy library-city; Marta's stick enshrined. Creatures: archivist-shells, filing-constructs, the Blind Seer (Constantine's recurrence — quest NPC: "already collected — why is it still walking?").
36. **Anchorfall** — debt-tablet foundries (anchors worth more than the lives they encode). Creatures: foundry thralls, tablet-golems.
37. **The Finalized Fields** — plains where collected are filed; grave-rows to the horizon. Creatures: the finalized (rows), grave-wardens.
38. **Coldharbor Deep** *(dungeon)* — black-water under-docks; accounts settled into the water. Creatures: drowned finalized, the Pit's instruments.
39. **The Orange Fog** — Deadheart-signal wastes; fog reads shifting orange. Creatures: signal-warped horrors, comprehension-dead.
40. **The Last Hearth** — the one warm refuge; Maren's orphanage echo (chalk handprints, protected/catalogued). Safe-hub zone. Creatures: none hostile — the point.

---

## Native creature families → sprite needs (downloaded packs, style-matched)
| Family | Zones | Pack need |
|---|---|---|
| Wolves/canines (grey, snow, obsidian, war-dog) | 3,9,13,18,25,26 | HAVE (Update_Canines re-tints) |
| Skeletons/undead/thread-shells | 1,15,16,12-16,27-40 | HAVE (Admurin skeletons, skeleton sheets) + need shambler/ghoul pack |
| Boars/fauna (bog, blood-fattened) | 1,2,3,23 | HAVE (wilderness) + re-tints |
| Bats/cave | 18,19 | HAVE (Enemy_Galore bat) |
| Strigoi (vampire humanoids), listeners | 17-21 | NEED: vampire/cultist humanoid pack |
| Varcolaci (werewolves), pit-bosses | 22-26 | NEED: werewolf pack |
| Entranced/villager-shells, cultists, bandits | 2,4,8,9,10,13,14 | Szadi NPC sheets re-purposed (standing still IS the horror) + bandit pack |
| Slag-walkers, forge-thralls | 22,24 | Re-tint skeleton/orc + ember VFX |
| The Digging Creature (herald boss) | 3,4,14 | NEED: clawed burrower boss sprite |
| The finalized, debt-wraiths, canal-things | 27-40 | Re-tint shells + NEED ghost/wraith pack |
| Ambient fauna (ravens, crows, dogs, eels) | all | HAVE birds + NEED small-fauna pack |

## Biome tileset needs (downloaded packs, 32px, muted GK palette)
| Biome | Zones | Need |
|---|---|---|
| Bog/swamp/dying birch | 2,3,4,31 | swamp/marsh tileset + dead trees |
| Farmland/river/thatch | 7,8,10,11 | HAVE (farm, avalon water, Szadi houses) + crop fields |
| Snow/tundra blue-black stone | 12-16 | snow tileset + dark stone city kit |
| Ridge/cliff/cave + biolume | 17-21 | HAVE cliff_tileset + need cave/catacomb kit (Szadi Rogue Fantasy Catacombs = style-perfect) + glow decals |
| Volcanic basalt/lava/forge | 22-26 | lava/volcanic tileset + forge props |
| Port/canal/docks/grey water | 27-34,38 | docks/pier tileset + boats + canal water |
| Dead forest grey | 9,32 | dead tree set (re-tint + pack) |
| Library/bureau interior | 35,36 | interior tileset (catacombs/dungeon kit doubles) |

## Travel graph (spine)
Raven Hollow ↔ Iron Vein ↔ Vetka (↕ Chamber Depths) ↔ Copper Wells ↔ Stonepath — the hub ring.
Stonepath → W: Grey Marches → Lowlands → Angel Wings → Famine Fields → Riverfork.
Stonepath → N: Listening Steppe → Threadlands → Black Night → Gravemark → the Pit.
Stonepath → E: Whisper Passes → Eastern Ridges → Blestem → Lichenreach → Transcub Vale.
Stonepath → S: Bloodroad → Basaltfang → Sangeroasa → the Gift → Ashvents.
Riverfork ⇢ (voyage, era-crossing) ⇢ The Grey Piers → Greyhollow hub ring → all Continent-2 zones.

## Travel system (WoW-style, interconnecting both continents)
- **Waystations** (flight-path equivalent, lore-safe): coach posts & river barges — 1-2 per zone at canon-sensible spots (the Bent Oar landing, kingdom toll-forts, capital gates). Each must be **discovered on foot** first (walk into it, like tapping a flight master).
- **Fast travel** only along **connected discovered routes** (WoW rules): pay a small coin cost per hop; routed through the travel graph below (no teleporting across undiscovered space). Travel plays a short fade-through-fog transit with zone-name banners.
- **The Grey Ferry** (continent link): a boat at **Riverfork Docks (C1)** ↔ **The Grey Piers (C2)** — the era-crossing "drowned ledger route" voyage. Boardable vessel with a dock scene on each side; crossing plays a fog-voyage interlude. (Second late-game link: the Archive ↔ Black Night "thread-gate" — same place, a thousand years apart.)
- **World map UI**: M opens a two-continent parchment map; zones fill in as discovered; waystation nodes shown lit/unlit; click a lit node to travel (if connected). Minimap already exists per-zone.
- Engine: `TravelSystem` autoload — node registry {id, zone, pos, links[], cost}; discovered set persisted in SaveSystem; MapRegistry travel_points remain the walk-across-border seams between adjacent zones.

## Build order (batches)
A. Engine + Border ring (zones 2,3,4,6 + Raven Hollow integration) — hub playable.
B. West arm + Angel Wings capital.  C. North arm + Black Night.  D. East arm + Blestem.
E. South arm + Sangeroasa.  F. Dungeons (5,16).  G. Continent 2 port ring + Greyhollow.  H. Continent 2 remainder.
Each batch: hand-authored layout data → build → screenshot QA (creatures + vignettes visible) → commit.
