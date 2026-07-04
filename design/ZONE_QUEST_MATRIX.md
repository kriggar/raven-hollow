# RAVEN HOLLOW — ZONE QUEST-HUB MATRIX
**The production checklist for mass quest authoring. 40 zones · 1,000 quests · level cap 60 · WoW-Classic pacing.**

Canon sources: `WORLD_PLAN.md` (zones/creatures/travel graph), `c:/Users/vstef/Desktop/rpg/_lore_extract.txt`
(Part IV regions · V factions · VII/VIII cast · IX bestiary · XI game hooks). Engine ground truth:
`scripts/quest_defs.gd` (quest schema), `scripts/quests.gd` (engine), `scripts/xp_system.gd`, `scripts/npc_data.gd`.

---

## 0. How to read this document

Every zone block gives:
- **Bracket** — target player level range (slow-grind tuned; zones overlap ~2 levels on purpose so grinding is a choice, WoW-Classic style).
- **Hub** — the landmark that carries the quest board / giver cluster (must be a hand-authored anchor in the zone def so `Quests.override_pos()` binds to builder truth — see §7).
- **Counts** — `M` main (the Bloodstone spine, one connected chain per zone), `Z` zone-story (the zone's 2–3 signature arcs), `S` side (one-offs, vignette quests, kill/collect with a story face), `D` daily (repeatable vigil content: patrols, provisioning, node-starving rounds). Counts per zone are the authoring quota, not a suggestion.
- **Arcs** — the 2–3 signature story arcs, one line each, lore-grounded. Tone tags per the mandate's WoW-Classic tonal mix: **[H]** heavy · **[C]** creepy · **[W]** warm/wry/cheerful. Every region must ship at least one [W] arc — the warmth is what the Stone wants gone, so the game must actually have some.
- **Givers** — quest-giving NPCs. Canon names are from Parts VII/VIII; entries marked *(new)* are invented, tone-matched, and must pass the lore bible's motif audit ("where is the small warm imperfect thing?").
- **Stone beat** — this zone's Bloodstone tease/test moment (the Lich-King cadence, §2). Fired as `cinematic_beat("stone_whisper_<zone>")` at the zone main chain's climax (precedent: `"listener_whisper"` in quest 5).
- **Breadcrumbs** — what sends the player here (in ←) and what sends them onward (out →), following WORLD_PLAN's travel graph.

### Global budget (sums to exactly 1,000)

| Region | Zones | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|---|
| Border ring (starter) | 6 | 1–15 | 24 | 59 | 45 | 6 | **134** |
| West — Angel Wings | 5 | 13–26 | 14 | 61 | 64 | 13 | **152** |
| East — Blestem | 5 | 24–35 | 16 | 57 | 59 | 12 | **144** |
| South — Sangeroasa | 5 | 33–44 | 17 | 58 | 59 | 12 | **146** |
| North — Black Night | 5 | 42–60 | 24 | 51 | 49 | 16 | **140** |
| Continent 2 — Collector's Coast | 14 | 48–60 | 38 | 119 | 99 | 28 | **284** |
| **World total** | **40** | 1–60 | **133** | **405** | **375** | **87** | **1,000** |

Ratios: 13% main spine, 41% zone-story, 37% side, 9% daily. Dailies concentrate at capitals, the two safe hubs
(Bent Oar, Last Hearth) and endgame zones — WoW-Classic leveling zones stay mostly non-repeatable.

---

## 1. Leveling flow (the grind route)

```
1–5   Raven Hollow ──► 4–9 Vetka ──► 6–11 Iron Vein ──► 8–12 Copper Wells
                     └► 10–12 Chamber Depths (dungeon) ──► 11–15 Stonepath (crossroads)
WEST  13–17 Grey Marches ► 15–19 Lowlands ► 15–25 ANGEL WINGS ► 18–22 Famine Fields ► 21–26 Riverfork
EAST  24–28 Whisper Passes ► 26–30 Eastern Ridges ► 25–35 BLESTEM ► 29–33 Lichenreach ► 31–35 Transcub Vale
SOUTH 33–37 Bloodroad ► 35–39 Basaltfang ► 34–44 SANGEROASA ► 38–42 The Gift ► 40–44 Ashvents
NORTH 42–46 Listening Steppe ► 44–48 Threadlands ► 45–52 BLACK NIGHT ► 47–52 Gravemark Tundra
VOYAGE (Riverfork ⇢ Grey Ferry ⇢) 48–51 Grey Piers ► 48–56 GREYHOLLOW ► C2 ring 49–58 ► 57–60 Orange Fog
FINALE  The Archive thread-gate ⇢ Black Night ⇢ 58–60 THE GRAVE & BLOODSTONE PIT
```
- The four arms are sequential by bracket (W→E→S→N) but each arm's interior order is loose; ~30% of each zone's side quests are skippable overflow so players can out-level or grind, Classic-style.
- Continent 2 is deliberately the level 48–58 band: the player sees *the drowned future* before the finale, then returns through the Archive↔Black Night thread-gate to descend into the Pit at 60.

---

## 2. The main spine — "THE LONG GAME" (133 quests, 7 acts)

The main villain is the **Bloodstone** — the buried world-machine that ARRANGES events and whispers through
inscription stones. Like the Lich King in WotLK it is present the whole game: it teases, tests, and grades the
player. Cadence rules for authors:

1. **One whisper per zone.** Every zone's main chain ends on a `stone_whisper_<zone>` beat — the stone addresses the player through the nearest inscription medium (a stone, a well, a ledger line, a debt-tablet, a dagger). It never threatens. It *offers*, *notices*, or *thanks* — which is worse.
2. **It arranges, it doesn't attack.** Whisper content must reference something the player actually did (a choice flag) — the stone has read your file. Use `Quests.set_flag` namespaced `stone_saw_*`.
3. **Curiosity is the vector.** At least one main quest per act must reward the player for reading/examining something and then make the zone visibly worse for it (the Q2 transcribe/deface pattern).
4. **The colors escalate.** Act I blue/violet sightings → Act IV green (waking) → Act VI–VII shifting orange (live signal) becomes routine. Detection grammar per WORLD_PLAN.

| Act | Name | Zones | Levels | M | The stone's posture |
|---|---|---|---|---|---|
| I | The Symptom | Border ring | 1–15 | 24 | Doesn't know you exist. The land is the letter. First direct word in the Chamber. |
| II | The Lead Box | West arm | 13–26 | 14 | Notices you. Engineers hunger around you to see what you do with it. |
| III | The Listening City | East arm | 24–35 | 16 | Tests you. Cazimir's web is its glove; every favor is architecture. |
| IV | The Antenna King | South arm | 33–44 | 17 | Uses you. The dagger's whisper and yours are the same voice; you hear it in Valrom first. |
| V | The City Over the Grave | North arm | 42–52 | 16 | Courts you. Shows you Lilith's leash and asks, politely, what yours is made of. |
| VI | The Drowned Future | Continent 2 | 48–58 | 38 | Shows you its finished work. Greyhollow is the stone's résumé. |
| VII | The Descent | Orange Fog → the Pit | 57–60 | 8 | Invites you home. The three notes converge; the final input is one small warm Moment. |

---

# CONTINENT 1 — DRACONIA

## Region A · BORDER RING (starter, zones 1–6) — 134 quests, levels 1–15

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 1 Raven Hollow | 1–5 | 3 | 10 | 9 | 2 | 24 |
| 2 Vetka | 4–9 | 6 | 12 | 8 | 0 | 26 |
| 3 The Iron Vein | 6–11 | 4 | 12 | 10 | 2 | 28 |
| 4 The Copper Wells | 8–12 | 3 | 11 | 10 | 0 | 24 |
| 5 The Chamber Depths (dungeon) | 10–12 | 4 | 6 | 2 | 0 | 12 |
| 6 The Stonepath | 11–15 | 4 | 8 | 6 | 2 | 20 |

#### 1 · Raven Hollow — fogged village (EXISTS — Phase C demo zone)
**1–5 · Hub: the Ember Hearth inn + plaza fountain-well · 24 (M3 · Z10 · S9 · D2)**
- **Arcs:** **The Fountain Toll [W→C]** — wish-coins keep vanishing from the fountain; a cheerful petty-theft mystery that ends at Gravekeeper Vasile's hill and the first hint that this village's dead are unusually restless (folds in the existing demo quests). **The Harvest Fair [W]** — Ansel, Tibalt and Maid Elsbeth prep the fair: pure warm-tone Classic busywork; flag the NPCs — their later fates must land. **The One Who Listens [C]** — Mira at the night treeline (existing Phase C quest 5): the game's first listener, played as ghost-story.
- **Givers:** Innkeeper Marta, Blacksmith Goran, Merchant Tibalt, Farmer Ansel, Gravekeeper Vasile, Old Petra, Young Emeric, Gatewarden Iosif, Maid Elsbeth (all exist in `npc_data.gd`).
- **Stone beat:** Mira's finale whisper (exists: `listener_whisper`) — retrofit its text to name what waits *under Vetka*.
- **Breadcrumbs:** in ← game start. out → Iosif opens the east gate toward the Bent Oar (Iron Vein) once the fair chain closes; Emeric leaves down the old road first and his rumor waits at the Bent Oar board.
- **PRODUCTION FLAG:** "Innkeeper Marta" (here) vs canon **Old Marta** (Vetka herb-woman) — two characters, one name. Recommend renaming the RH innkeeper (e.g. "Innkeeper Magda") before Vetka ships; the Vetka Marta is load-bearing canon (her stick is enshrined in the Archive).

#### 2 · Vetka — starter thesis village, mud and thatch
**4–9 · Hub: Old Marta's cottage porch (the village has no board — Marta IS the board) · 26 (M6 · Z12 · S8 · D0)**
- **Arcs:** **The Cellar, the Chamber, the Waking [C/H]** — the canon Part XI opener, Q0–Q3 verbatim: Borek's honest work → the cellar transmission point → the Courier who died of understanding → the town changed when you surface (transcribe/deface choice uses the `choice` objective kind). **Doomed Neighbors [C]** — Torn hums three notes he never heard anywhere, Dorica boils the copper water because there is no other well, Gren quietly digs a grave nobody asked for; three parallel mini-chains that end differently depending on Q2's choice flag. **Practical Foundations [W]** — Old Marta teaches herb-craft and points you at Hessik's alchemy primer: the detection-colors tutorial (blue/violet/green/orange) disguised as a gathering chain.
- **Givers:** Old Marta, Borek (the stew — flag the Moment), Torn, Dorica, Gren *(all canon Part VIII)*.
- **Stone beat:** first direct contact — dead hands on the dense Chamber script, the pull installed as *hunger*: "It has been so quiet. You read beautifully."
- **Breadcrumbs:** in ← Raven Hollow (Iosif) or Iron Vein barge. out → cellar descends to Chamber Depths; the Courier's still-sealed letter is addressed to a drover at the Bent Oar (Iron Vein); Marta sends samples of the dead yeast upriver.

#### 3 · The Iron Vein — bog-valley of the slow blood-colored river
**6–11 · Hub: THE BENT OAR tavern (first true quest board + barge waystation) · 28 (M4 · Z12 · S10 · D2)**
- **Arcs:** **The Undelivered Letter [H]** — deliver the Courier's sealed letter; the answer it carries is for a woman who stopped waiting on Tuesday and now faces north; do you read it first? (curiosity mechanic, again). **Flat Grey Bread [C]** — the innkeeper blames the flour, then the water, then stops blaming; trace the yeast-death from holding to holding upriver until the map of dead bread IS the map of the warm ground. **What the River Carries [C/H]** — drowned holdings give up their dead a day's drift downstream — arranged, on the banks, in rows; and something four-clawed is widening the fords at night (Digging Creature rare night elite).
- **Givers:** Innkeeper Stoya of the Bent Oar *(new — keeps every regular's tab in her head, never writes one down)*, Ferryman Luca *(new)*, the widow of Drowned Holding *(new)*, Bent Oar quest board, Old Marta (turn-ins).
- **Stone beat:** the tavern goes quiet mid-evening for a count of three — every conversation stops on the same syllable. Nobody noticed but you.
- **Breadcrumbs:** in ← Raven Hollow / Vetka. out → moor-road to the Copper Wells (Stoya's water-buyer stopped coming); barge waystation unlocks (travel system); board posts a Stonepath coach escort.
- **Dailies (2):** bog-boar cull for the stew pot [W]; night-watch the fords.

#### 4 · The Copper Wells — poisoned-well moors (read-the-land tutorial)
**8–12 · Hub: the crossroads boundary-stone camp (Scout-Widow Pall's fog-line post) · 24 (M3 · Z11 · S10 · D0)**
- **Arcs:** **Read the Land [C]** — Pall (posted forward from Angel Wings' early-warning line) teaches the full symptom grammar as playable puzzles: which well is clean, which lane the dogs refuse, why those three farmsteads stand empty and *unlooted*. **The Pilgrim Problem [H]** — entranced pilgrims file north across the moor; turn them back (they walk again tomorrow), rope them (they scream until freed), or follow one (main-chain lead to the Stonepath) — no clean win. **The Well-Warden's Ledger [W→H]** — a fussy warden *(new)* insists on testing every well by the book; his book is right, his wells keep coppering, and his slow breakdown from comedy to horror is the zone's tonal hinge.
- **Givers:** Scout-Widow Pall *(canon Part VIII — she can smell a coppering well a mile off and wishes she couldn't)*, Well-Warden Fenic *(new)*, a circuit alchemist selling Hessik's *Practical Foundations* *(new)*.
- **Stone beat:** a clean well coppers *while you watch it*, the moment you finish testing it. It waited for the audience.
- **Breadcrumbs:** in ← Iron Vein. out → the worn boundary-stone points to the Stonepath; Pall reports the pilgrim traffic west to Angel Wings (Act II hook); the deepest tunnel under the dry well drops toward Chamber Depths.

#### 5 · The Chamber Depths (DUNGEON) — the transmission site beneath Vetka
**10–12 · Hub: none — auto-triggers + surface turn-ins (Old Marta / Borek / Stoya) · 12 (M4 · Z6 · S2 · D0)**
- **Arcs:** **The Courier Died of Understanding [C/H]** — the canon set-piece: satchel sealed, fingernails clean, no wound (that is the wound); his half-copied glyph page is a cursed lore item. **Transcribe or Deface [H]** — the dungeon-wide choice economy: every inscription read = faster loot, worse Vetka; every node starved = slower, safer (dungeon remembers your last visit — mutable state). **The Walls Listen Back [C]** — no combat for the first half (dread by design), then thread-shells at the deepest gallery.
- **Givers:** auto-trigger quest starts (`auto_trigger` schema key); turn-ins upstairs.
- **Stone beat:** the two-of-three-notes melody hums in the stone; if the player transcribed anything, the whisper uses *their handwriting* on the wall.
- **Breadcrumbs:** in ← Vetka cellar / Copper Wells dry-well tunnel. out → the command-script's flow direction points every reader toward the Stonepath ring, and, far under it, *north*.

#### 6 · The Stonepath — inscription-stone crossroads linking all four kingdoms
**11–15 · Hub: the crossroads waystation (coach post where all four arms meet) · 20 (M4 · Z8 · S6 · D2)**
- **Arcs:** **The Shortening Inscription [H]** — the only inscription on the continent that is getting *shorter*: a dead man's handprint, marks fading around his fingers — the transmit-don't-receive endgame counter, seeded at level 13 as an unexplained miracle. **Four Patrols, No War [H — GoT]** — Strigoi, Varcolaci, Iele and human patrols cross here and pretend not to see each other; the player's first leverage market: sell sightings to any of four officers, and what you sell comes back with interest in Acts II–V (flags: `lev_*`). **Wolf-Pack Grammar [C]** — the wolves here don't hunt like wolves; they pace off the ground in even lines, like surveyors.
- **Givers:** Coachman Vadim *(new — the waystation keeper who has outlasted three "incidents" by never once reading anything)*, four faction patrol officers *(new: one per kingdom — each is the player's first contact for that arm)*, a stone-scholar who must be talked out of his own thesis *(new)*.
- **Stone beat:** the crossroads stone, worn smooth by a thousand idle hands, is warm under yours alone. Act I closes: "Four roads. I have time. Pick."
- **Breadcrumbs:** in ← Copper Wells / Chamber Depths. out → ALL FOUR ARMS: W to Grey Marches (human officer's dispatch), N to Listening Steppe (locked until ~L40; the Iele officer refuses you politely), E to Whisper Passes (locked until ~L24), S to Bloodroad (locked until ~L33). Gating is by quest prereq, not walls — walking into a 40 zone at 15 is allowed and lethal, Classic-style.
- **Dailies (2):** coach escort; wolf-line survey cull.

---

## Region B · WEST — ANGEL WINGS (humans, Queen Fielderine) — 152 quests, levels 13–26 · ACT II: THE LEAD BOX

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 9 The Grey Marches | 13–17 | 2 | 11 | 12 | 1 | 26 |
| 8 The Western Lowlands | 15–19 | 2 | 12 | 13 | 1 | 28 |
| 7 ANGEL WINGS (capital) | 15–25 | 5 | 16 | 17 | 8 | 46 |
| 10 The Famine Fields | 18–22 | 3 | 12 | 10 | 1 | 26 |
| 11 Riverfork | 21–26 | 2 | 10 | 12 | 2 | 26 |

#### 9 · The Grey Marches — dying-forest frontier
**13–17 · Hub: Brant's logging camp (palisade + board) · 26 (M2 · Z11 · S12 · D1)**
- **Arcs:** **Grey by the Acre [C]** — the forest isn't burning or felled, just going grey from the inside; Forester Brant's crews cut the dead acres and keep finding carved kerb-stones where no graves should be. **The Warm Congregation [H]** — a desperate cult worships the warm ground because warmth is the only god still answering prayers out here; break it up, infiltrate it, or feed it — its preacher used to be the village schoolteacher. **The Greywolf Winter [W]** — honest Classic hunt content: pelts for the camp, a named alpha, a cook who over-seasons everything.
- **Givers:** Forester Brant *(new)*, a cult deserter *(new)*, Scout-Widow Pall's fog-line runners, camp cook *(new)*.
- **Stone beat:** a felled grey trunk's rings, counted, spell a repeating angular pattern. The tree was transcribing for eighty years.
- **Breadcrumbs:** in ← Stonepath (human patrol officer's dispatch). out → timber contracts and the cult's grain source both point down into the Lowlands.

#### 8 · The Western Lowlands — river-country farmland, thinnest fog
**15–19 · Hub: the reeve's mill at Threshel village (new) · 28 (M2 · Z12 · S13 · D1)**
- **Arcs:** **The Full Granary [H]** — the canon famine-village: granary full, people starving, nothing physically wrong; the player can *prove* the hunger is engineered and discover that proof feeds panic better than bread. **Bandit-Lords' Arithmetic [H — GoT]** — the bandit-lords tax grain that Blestem quietly pays for in secrets; cut the chain at any link and a different village starves — leverage web, first rehearsal of Cazimir's methods on human scale. **The Hungering [C]** — neighbors walking east with empty eyes; families hire you to bring them back, and the ones you bring back sit at the table facing east.
- **Givers:** Reeve Marda of Threshel *(new)*, Maren's orphanage supply riders, a bandit quartermaster turned informant *(new)*, river-fisher family *(new, warm)*.
- **Stone beat:** the granary tally-board, recounted at dawn, is always one sack short — and one name has been added to the ration list that nobody wrote.
- **Breadcrumbs:** in ← Grey Marches. out → the grain politics, the hungering, and Pall's pilgrim reports all converge on Angel Wings; the bandit money trail runs to Riverfork.

#### 7 · ANGEL WINGS (CAPITAL — MASSIVE) — the underestimated west
**15–25 · Hubs: Maren's Orphanage (safe-house board) · grain-market square · palace gate (Helva's post); the Lead Vault is a quest DESTINATION, never a board · 46 (M5 · Z16 · S17 · D8)**
- **Arcs:** **The Lead Box [H — GoT]** — canon QS-3: the fragment has begun humming one note; the young vault clerk skips meals "to feel clearer"; remove him, use him as a canary, or tell Fielderine what she already suspects — the quiet strategist's court is a minefield of people trying to make her desperate on purpose. **The Copper Handprint [C/H]** — one chalked handprint on the orphanage wall is faintly copper-stained and warm; find which child — and decide whether Maren is told (canon design hook; the answer echoes 1,000 years later at the Last Hearth). **The Only War I'm Winning [W]** — Quartermaster Helva's private ledger of every child fed: provisioning chains, orphan errands, Old Fisherman Cott teaching one more kid to fish — the game's warmest content, deliberately placed beside its coldest. **Quiet Famines [H — GoT]** — which villages get fed is a political weapon; Fielderine makes you her deniable hand and never once says the cruel part aloud.
- **Givers:** Queen Fielderine (throne mains), Maren, Quartermaster Helva, the Lead-Box Warden *(canon — use sparingly, queen's-level secret)*, Old Fisherman Cott, Fielderine's spymaster *(new: Master-of-Doves Irien)*, market wardens *(new)*.
- **Stone beat:** Act II closer, inside the Lead Vault on legitimate business: the box's single note pauses as you pass — and resumes in your footstep rhythm. Fielderine sees you hear it. Neither of you speaks.
- **Breadcrumbs:** in ← Lowlands / Pall's reports. out → Fielderine's famine dossier sends you to the Famine Fields; Irien's leak-hunt (who told Blestem about the box?) opens the East arm hook; Maren's supply barges open Riverfork.
- **Dailies (8):** orphanage provisioning ×2 [W], fog-line patrol, grain-market escort, river-dock labor dispute rounds, palace dispatch runs, bandit-bounty board ×2.

#### 10 · The Famine Fields — stone-engineered hunger belt
**18–22 · Hub: the tithe-barn relief station (Helva's field post) · 26 (M3 · Z12 · S10 · D1)**
- **Arcs:** **Hunger Where There Is Bread [H]** — map the warm patches against the empty bellies; the overlay is exact, and the relief you deliver is a rounding error against an enemy that engineers appetite. **The Scratched Box [C/H]** — the canon burned farmstead: a cheap lead box, empty, scratch-marks *inside*; trace who told a peasant about Fielderine's discipline — the answer is a Blestem grain-buyer, and the trail is Act III's front door. **Starving Dogs and Patient Crows [C]** — the fauna here has reorganized around human failure; a hunter arc with a wrong taste in its mouth.
- **Givers:** Helva's field agents, village priests *(new — one kind, one broken)*, the Blestem grain-buyer *(new — polite, exact, unhurried)*.
- **Stone beat:** a relief cart you escorted arrives with one sack of grain gone hard as stone. Milled, it pours out as fine grey dust that settles in parallel lines.
- **Breadcrumbs:** in ← Angel Wings (Fielderine's dossier). out → the grain-buyer's manifest names Riverfork's toll-posts; the cult survivors from Grey Marches resurface here.

#### 11 · Riverfork — Iron Vein delta, bridges and toll-posts
**21–26 · Hub: the Threeway toll-bridge house + RIVERFORK DOCKS (future Grey Ferry berth) · 26 (M2 · Z10 · S12 · D2)**
- **Arcs:** **Toll and Tithe [H — GoT]** — three bridges, three toll-lords, one smuggler queen; everyone pays someone and the paper trail is the weapon — the region's leverage-web capstone (your Act II flags are called in here). **River-Drakes [W]** — big cheerful bog-fauna hunt: drake trophies, dock bragging rights, a fisherman's tall tale that turns out true. **The Drowned Ledger Route [C — late hook]** — a grey-wooded derelict ties up at the far pier; its manifest is dated a thousand years from now (Grey Ferry discovery — locked until ~L46, the Act VI gate).
- **Givers:** Toll-Master Vasq *(new)*, smuggler queen Ludmila *(new)*, dock board, the Grey Ferry's keeper *(new — says nothing twice)*.
- **Stone beat:** the toll-ledger's last page lists tomorrow's crossings. Your name is on it, spelled the old way.
- **Breadcrumbs:** in ← Angel Wings / Famine Fields. out → East arm (the grain-buyer boards a coach for the Whisper Passes; follow); the docks hold the C2 voyage for Act VI.
- **Dailies (2):** toll-post inspection circuit; drake cull.

---

## Region C · EAST — BLESTEM (Strigoi, Cazimir) — 144 quests, levels 24–35 · ACT III: THE LISTENING CITY

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 21 The Whisper Passes | 24–28 | 3 | 10 | 10 | 1 | 24 |
| 18 The Eastern Ridges | 26–30 | 2 | 11 | 12 | 1 | 26 |
| 17 BLESTEM (capital) | 25–35 | 6 | 16 | 16 | 8 | 46 |
| 19 Lichenreach (cave) | 29–33 | 2 | 9 | 10 | 1 | 22 |
| 20 The Transcub Vale | 31–35 | 3 | 11 | 11 | 1 | 26 |

#### 21 · The Whisper Passes — high trails where sound carries strangely
**24–28 · Hub: the deaf shepherd's steading (the one safe place to talk) · 24 (M3 · Z10 · S10 · D1)**
- **Arcs:** **Sound Carries Strangely [C — GoT]** — listener watch-posts triangulate conversations; say the wrong thing near the wrong cairn and a stranger in Blestem greets you by it a week later — teaches the region rule: *assume audience*. **The Assassin's Timetable [H]** — a strigoi assassin commutes these trails; his schedule is for sale, and three different buyers want it for three different murders. **The Shepherd Who Hears Nothing [W]** — the deaf shepherd is the pass's one honest broker; his flock-and-fences chain is the arm's warm anchor, and factions pay premium to meet at his table.
- **Givers:** the deaf shepherd Iov *(new)*, Sabira's first dead-drop (she never appears — notes only), pass-warden *(new)*, rock-viper bounty board.
- **Stone beat:** an echo in the high pass returns your own words — with one word improved.
- **Breadcrumbs:** in ← Stonepath (E officer) / Riverfork (the grain-buyer's coach). out → the assassin's schedule and Sabira's drops both route through the Eastern Ridges to Blestem's gates.

#### 18 · The Eastern Ridges — Carpathian spine, fog at shoulder height
**26–30 · Hub: the ridge-keep caravanserai on the lichen road · 26 (M2 · Z11 · S12 · D1)**
- **Arcs:** **The Lichen Road [W→H]** — caravans haul luminous lichen down to Blestem; honest escort work that slowly reveals the cargo manifests are also personnel files on every driver. **Twelve at the Cliff [C]** — twelve boot-prints at a cliff dead-end, all facing out over the drop, none walking back — a Strigoi execution where no patrol admits to operating; identifying the twelve makes you the only witness on record, which is a dangerous thing to be. **Bats in the Fog [W]** — cliff-bat culls and a caravan cook's bat-stew subplot; the arm's comic relief with teeth.
- **Givers:** caravan master Petrache *(new)*, ridge-keep captain *(new)*, Vera Cold-Hands' buying agent *(new — pays extra for kindnesses, not secrets)*.
- **Stone beat:** fog at shoulder height parts for exactly the length of your walk, both directions. Something is keeping your sightline clean, the way Nistor sweeps Cazimir's.
- **Breadcrumbs:** in ← Whisper Passes. out → the lichen road descends into Blestem's ridge-cleft; the Twelve's file is your admission ticket to the Lower Market (someone will pay you not to carry it in).

#### 17 · BLESTEM (CAPITAL — MASSIVE) — the black maze-city that notices you
**25–35 · Hubs: the Lower Market (information-as-currency board) · the Churches of Transcub (Brother Ansel's quiet quests) · Riddler's Quarter antechamber (Cazimir mains, voice-from-the-walls only) · 46 (M6 · Z16 · S16 · D8)**
- **Arcs:** **Cazimir's Leverage Web [H — GoT, the mandate arc]** — the capital's signature: a chain of small, reasonable favors (deliver this, watch him, price that rumor) that assembles, behind the player's back, into a cage for someone they like; the arc's climax is being shown the architecture with their own quest log as the blueprint — "I do not collect assumptions. I collect architecture." **Rows of Twelve [H]** — canon QS-1: the culling ledger holds a clerical error; expose it, forge it, or let it process — the paperwork is the murder weapon. **The Silencing of the Forty [C/H]** — find the ward that was rebricked out of the street-plan; the map says no street runs there, the milk-cart's mileage says otherwise; forty-four names want carrying out one at a time. **The Un-Swept Corner [W]** — Nistor the Sightline Sweeper's small chain: he keeps exactly one corner un-swept, for himself; help him defend the only blind spot in Blestem — the city's one warm secret.
- **Givers:** Cazimir (from the walls — never embodied), Sabira (in person at last), Nistor the Sightline Sweeper, Vera Cold-Hands, Brother Ansel, the unnamed Lift-Boy *(all canon Part VIII)*, Lower Market rumor board *(pays in leads, not gold)*.
- **Stone beat:** Act III closer, at the Black Spire's base: under alchemical light the windowless tower bleeds shifting orange, and the walls that listen say — in Cazimir's stolen cadence — "He thinks he is the buyer. Would you like to see his file?"
- **Breadcrumbs:** in ← Eastern Ridges. out → Sabira's marks-that-shouldn't-exist dossier points into Lichenreach's dark; Brother Ansel's pilgrimage opens the Transcub Vale; Cazimir's price for your exit visa is a delivery to Sangeroasa (Act IV gate: the Bloodroad coach).
- **Dailies (8):** rumor-pricing at Vera's stall ×2, sightline maintenance rounds, lamp-oil circuit, church ivy-clearing [W], Lower Market escrow escort, listener-post resupply ×2.

#### 19 · Lichenreach (CAVE ZONE) — luminous caverns, the Strigoi export
**29–33 · Hub: the harvest-mistress's lantern camp at the cave mouth · 22 (M2 · Z9 · S10 · D1)**
- **Arcs:** **The Light Harvest [W→C]** — lichen farming in beautiful bioluminescent galleries; the deeper crop grows brighter, and the brightest bed grows in the outline of a man. **The Walled [C/H]** — canon punishment-creature: someone entombed alive in a listening-wall is still transmitting; his daughter pays you to find which wall — mercy, rescue, or use him as Blestem's only untapped wiretap (no clean win). **Dark Between Lamps [C]** — bat swarms and cave-strigoi hunt the unlit stretches; light management combat (the Digging Creature boss pattern, re-used).
- **Givers:** harvest-mistress Coralia *(new)*, the walled man's daughter *(new)*, cave surveyor *(new)*.
- **Stone beat:** a lichen bed pulses in three-note rhythm. It is growing on an inscription, and it is *thriving*.
- **Breadcrumbs:** in ← Blestem (Sabira's dossier). out → the deepest gallery's marks match Transcub altar-script — Ansel must be told, or not.

#### 20 · The Transcub Vale — ivy-eaten temples of the old god
**31–35 · Hub: Brother Ansel's half-eaten church (pilgrimage camp) · 26 (M3 · Z11 · S11 · D1)**
- **Arcs:** **The Warm Altar [C/H]** — the canon confession: "I only wanted to know what it said," scratched in a shaking hand; the stone beneath is warm; the penitents' arc — people scraping their own confessions off stone before the stone can finish reading them. **The God Who Audited the Self [H→W]** — Ansel's pilgrimage to re-consecrate the vale or let the ivy finish it; Transcub punished cruelty-to-the-self, and the vale forces the arm's quietest question: what has this playthrough's player been doing to *themselves* (uses accumulated `stone_saw_*` flags in dialogue). **Temple Ghouls [C]** — what penitents who read the altar-script become; combat content with named ghouls the pilgrims still pray for by name [W-edged].
- **Givers:** Brother Ansel, penitent cultists *(new)*, temple sexton *(new)*, a Riddler's Quarter "observer" everyone pretends not to see *(new — GoT)*.
- **Stone beat:** the warm altar answers one confession — yours. It lists, accurately, everything you transcribed since Vetka. Then: "Shall I forgive you?"
- **Breadcrumbs:** in ← Blestem / Lichenreach. out → Cazimir's Sangeroasa delivery departs (Bloodroad, Act IV); the vale's oldest fresco shows the *south* road lined with tolls a thousand years before tolls — era-echo breadcrumb for C2.

---

## Region D · SOUTH — SANGEROASA (Varcolaci, Valrom) — 146 quests, levels 33–44 · ACT IV: THE ANTENNA KING

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 26 The Bloodroad | 33–37 | 3 | 11 | 11 | 1 | 26 |
| 25 Basaltfang Range | 35–39 | 2 | 10 | 11 | 1 | 24 |
| 22 SANGEROASA (capital) | 34–44 | 6 | 16 | 16 | 8 | 46 |
| 23 The Gift | 38–42 | 3 | 11 | 11 | 1 | 26 |
| 24 The Ashvents | 40–44 | 3 | 10 | 10 | 1 | 24 |

#### 26 · The Bloodroad — arsenal supply road north
**33–37 · Hub: Toll-Fort Krunn (the largest war-caravan fort) · 26 (M3 · Z11 · S11 · D1)**
- **Arcs:** **War-Caravan Ledgers [H — GoT]** — the arsenal rolls north in quantity that only makes sense if Valrom is arming against *everyone at once*; count the convoys for whichever faction contact you kept from the Stonepath (leverage flags pay out). **Deserters' Toll [H]** — deserters are marked "Gift" in absentia; a deserter chief wants his men's names bought off the ledger — the currency is other names. **Ilion's Audit [C]** — the executioner-general is auditing the road, fort by fort, in perfect silence; every skimming toll-sergeant wants you to be somewhere else when he arrives — and Ilion, who files everything, has one question about a grave you opened in Act I.
- **Givers:** convoy master Bruga *(new)*, deserter chief *(new)*, toll-sergeants *(new ×2)*, Ilion (mains — he says almost nothing).
- **Stone beat:** a war-dog convoy halts, all dogs facing the road-side ditch, for a count of three. In the ditch: a boundary stone, humming, freshly dug *up*.
- **Breadcrumbs:** in ← Stonepath (S officer) / Blestem (Cazimir's delivery). out → the caravans climb into Basaltfang; Ilion's audit route ends at the Debt Pit rim (capital main).

#### 25 · Basaltfang Range — black basalt ridges under the haze
**35–39 · Hub: the pack-mother's hunt-camp on the high fang · 24 (M2 · Z10 · S11 · D1)**
- **Arcs:** **The Hunt Under the Haze [H→W]** — run the varcolaci pack-rites as an outsider: earn a hunt-name, keep it or spend it; the packs are honest about what they are, which after Blestem feels almost like kindness. **The Cliff Shamans' Weather [C]** — shamans read the vents for omens, and lately the vents read back; their weather-calls have started rhyming with the three notes. **Obsidian Wolves [W]** — classic elite-hunt chain: a black-glass-pelted alpha, a trophy wall, a trapper who lies about everything except the wolf.
- **Givers:** pack-mother Vursa *(new)*, vent-shaman *(new)*, the lone human trapper *(new — warm, absurd, doomed to be right)*.
- **Stone beat:** your hunt-name, howled down the range in the pack relay, comes back one ridge later meaning something else.
- **Breadcrumbs:** in ← Bloodroad. out → the pack escorts the last convoy leg down into Sangeroasa; the shaman sends a vent-omen warning to the Ashvents wardens.

#### 22 · SANGEROASA (CAPITAL — MASSIVE) — the forge that eats
**34–44 · Hubs: the forge-row hiring board · the Debt Pit rim (Drego's post) · Valrom's keep gate (war mains) · 46 (M6 · Z16 · S16 · D8)**
- **Arcs:** **The King's Dagger [H — GoT, the arm's spine]** — court intrigue in a city with no secrets except one: Ilion has been quietly filing the king's changed behavior; Anara — survivor of Valrom's genocide, hidden in his own war-machine — is the only one who can read what the dagger is; the player brokers the impossible meeting (canon QS-4 folded in: hide her, trade her, or teach her to die convincingly). Completing the disarm chain unlocks Valrom's phase-3 mercy window (Boss 3). **The Ledger at the Rim [C/H]** — the Debt Pit's nailed ledger marks its dead "collected" — a word a thousand years early; Pit-Caller Drego reads the day's names over the forge-roar where no one can hear, and has never once been wrong; prove one name premature. **The Gift Must Eat [H]** — canon QS-2: a farmer needs "fresh red" and knows exactly what that means; broker, refuse, or blow the cycle open via Anara — every meal in the south is a body. **A Tin of Clean Things [W]** — Soot-Boy Tav's collection (an unburnt leaf, a white pebble); his message-running chain through the blood-channels is the game's most fragile warm thread — flag his Moment; the Pit is always one quest away from taking him.
- **Givers:** Valrom (war mains — his dialogue drifts mid-chain from king's rhetoric toward the stone's flat cadence), Ilion, Anara (covert — never at the keep), Hammer-Widow Olga, Pit-Caller Drego, Soot-Boy Tav, Gift-Farmer Ruja *(all canon)*, forge-row hiring board.
- **Stone beat:** Act IV closer: all the hammers stop, for a count of three, city-wide — and in the silence the dagger at Valrom's belt finishes the sentence the king was speaking. Only you and Ilion notice. Ilion files it.
- **Breadcrumbs:** in ← Bloodroad / Basaltfang. out → Ruja's failing rows open the Gift; the Pit's heat-survey crews open the Ashvents; Ilion's cave file (what he found with Lilith's scroll and never reported) is the Act V gate — he gives it to you, not Valrom, and will not say why.
- **Dailies (8):** forge supply runs ×2, blood-channel dredging, Pit-rim watch, convoy loading, Tav's message circuit [W], killing-floor tallies, Olga's hammer-shift relief [W].

#### 23 · The Gift — impossibly red fertile bands grown from the Great-War dead
**38–42 · Hub: Ruja's farmstead on the reddest band · 26 (M3 · Z11 · S11 · D1)**
- **Arcs:** **A Child's Shoe in the Furrow [H — the mandate arc]** — abundance and atrocity share a row: trace the shoe to a name, the name to a levy, the levy to a village that still sets a bowl out; end by telling them, or letting the harvest be enough. **The Rows That Remember [C]** — Ruja talks to the crop, and given what it grew from, it might hear; night-work quests where the field's alignment turns out to be *rows of twelve*. **What Got Up [C/H]** — the forges dug too deep near the old dead; Great-War revenants walk the bands at night wearing three different armies' rust — Iele-adjacent, and the North is watching what the South digs (Accord Point 4 intrigue).
- **Givers:** Gift-Farmer Ruja, field-wardens *(new ×2)*, a carrion-watcher who names every bird *(new [W])*, an Iele "observer" at the zone edge *(new — GoT)*.
- **Stone beat:** a good harvest row, cut, falls in a line that points — every stalk — at the Ashvents. The next row too.
- **Breadcrumbs:** in ← Sangeroasa (Ruja's plea). out → the revenant question escalates north (flag for Act V); the vent-ward survey hires you east into the Ashvents.

#### 24 · The Ashvents — active vent fields where heat hides the signal
**40–44 · Hub: the vent-wardens' stilt-station above the warm river · 24 (M3 · Z10 · S10 · D1)**
- **Arcs:** **Heat Hides the Signal [C — the canon problem-zone]** — the detection tutorial inverted: here *everything* is warm, so the grammar fails; learn the residual tells (dust alignment, dead yeast, the quiet) and find the one live stone in a field of honest heat — Hessik-method mastery required for Act V. **Slag-Walkers [C/H]** — dead workers still working, animated by necromantic seepage; a widow pays you to find whose *shift* her husband is still keeping, and the answer is a ledger, not a necromancer. **The Warm Pilgrimage [H]** — the entranced come south too — heat feels like answers; the wardens have started letting them walk into the vents, and the zone asks whether that's murder or triage.
- **Givers:** vent-warden captain *(new)*, the slag-walker's widow *(new)*, a Hessik-method alchemist *(new)*, Basaltfang shaman (omen turn-ins).
- **Stone beat:** in the one cold hollow in the whole zone, frost — and under the frost, a stone reading shifting orange. It kept a place cold *so you would find it*. Act IV ends: "You learned to see me without the heat. Good. The north is cold."
- **Breadcrumbs:** in ← Sangeroasa / the Gift. out → Ilion's cave file + the cold-hollow stone both point north; the Stonepath's Iele officer will now talk to you (Act V gate ~L42).

---

## Region E · NORTH — BLACK NIGHT (Iele, Lilith) — 140 quests, levels 42–60 · ACT V: THE CITY OVER THE GRAVE + ACT VII: THE DESCENT

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 14 The Listening Steppe | 42–46 | 3 | 10 | 12 | 1 | 26 |
| 13 The Threadlands | 44–48 | 3 | 12 | 12 | 1 | 28 |
| 12 BLACK NIGHT (capital) | 45–52 | 7 | 14 | 13 | 10 | 44 |
| 15 Gravemark Tundra | 47–52 | 3 | 11 | 12 | 2 | 28 |
| 16 The Grave & Bloodstone Pit (endgame dungeon) | 58–60 | 8 | 4 | 0 | 2 | 14 |

#### 14 · The Listening Steppe — wind-scoured steppe where the drawn stand listening
**42–46 · Hub: the Iele census-taker's waystation (the North counts everything) · 26 (M3 · Z10 · S12 · D1)**
- **Arcs:** **The Drawn [C/H]** — census the listening clusters; some are missing persons from every zone you've saved or doomed (mutable-world callbacks: Torn if he lived, the Lowlands hungering, the Ashvents pilgrims you turned back) — backtracking is grief, per the dungeon design law. **The Digging Creature's Line [C]** — its tunnels across the steppe, plotted, converge on Black Night from *outside* — the herald is delivering something home; interrupt the last excavation (Boss 1's pattern at elite scale). **Wind Without Birds [C→W]** — the raven-keeper's arc: the steppe's ravens refuse a corridor of sky; her banding-and-counting chain is the North's one warm thread, and her birds are the zone's honest detection grammar.
- **Givers:** Iele census-taker *(new — pre-mourns like Moasa)*, raven-keeper *(new)*, a Vetka survivor among the drawn (conditional on Act I flags).
- **Stone beat:** a cluster of the drawn, passed at dusk, has re-formed by dawn — arranged now in your marching order from yesterday.
- **Breadcrumbs:** in ← Stonepath N gate (opens ~L42) / Ashvents flags. out → the census rolls are owed to Threadwarden Ilka (Threadlands); the tunnel line crosses the pilgrim roads north.

#### 13 · The Threadlands — tundra threaded with visible blue filaments
**44–48 · Hub: Threadwarden Ilka's tending-post on the pilgrim road · 28 (M3 · Z12 · S12 · D1)**
- **Arcs:** **Filaments [C — mechanics arc]** — Ilka teaches Thread literacy: see, trace, soothe, and (illicitly) *thin* — the mechanic Lilith used to wake Kriggar, put in player hands with a warden watching; she names the shells under her breath, which regulations forbid. **Three Bedrolls, Cold Stew [C/H]** — the canon family camp: footprints in, none out, stew uneaten; the investigation ends at a thinned thread and a question about who is allowed to *stop*. **Pilgrim Roads [H]** — the hungering arrive from every zone you've been; Black Night doesn't want them either — broker what the still city does with the still-breathing.
- **Givers:** Threadwarden Ilka *(canon)*, pilgrim-warden *(new)*, snow-wolf hunter *(new [W])*, Moasa's rolls-courier *(new)*.
- **Stone beat:** a thread you traced hums back along your finger — two notes of three. Ilka pretends not to have seen. Her hands are shaking.
- **Breadcrumbs:** in ← Listening Steppe. out → Ilka's section report is owed to the Council (Black Night); the thinned-thread evidence is exactly what Radovan has been waiting for someone deniable to carry.

#### 12 · BLACK NIGHT (CAPITAL — MASSIVE) — the silence that is not peace
**45–52 · Hubs: the Council of Six antechamber (small-council theater) · the still market (Moasa's rolls-desk) · the grave-precinct gate (Grave-Sweeper's rounds) · 44 (M7 · Z14 · S13 · D10)**
- **Arcs:** **Small-Council Theater [H — GoT]** — canon design note played straight: Vasile's noise as cover, Radovan's silence as policy; run council errands where the comedy of process ("a vote on the roof while the foundation reads them a bedtime story") slowly curdles — earning Radovan's confidence buys the best intelligence in Draconia, *at a price paid later* (flag: `lev_radovan_debt`, called in the Pit). **Radovan's Reading [H — the arm's spine]** — canon flashpoint 3: he has independently derived the counter — the dead can transmit — and concluded Lilith is precisely the wrong dead touch to trust with it; the player carries his proofs, or Lilith's counter-proofs, or forges either (three-way betrayal fork; feeds directly into the endgame). **The Flicker of Will [H]** — canon QS-6: a shell on the thread-network wakes, like Kriggar did; snuff it (Radovan), study it (Vasile), or hide it — you of all creatures know what waking dead and wanting is like. **Cedar Shavings [W/C]** — the Grave-Sweeper leaves cedar shavings on the tomb-stone and doesn't know why (his grandmother did it too); his small rounds-chain ends at the worn inscription: *"47 years… they gave me a pit"* — and the cedar smell, impossibly, still there.
- **Givers:** Vasile, Radovan, Moasa the Ledger, Sorin the Doubter *(he checks the cellars; help him)*, Petran (one perfect quest: get the Empty Chair to vote once), Threadwarden Ilka, the Grave-Sweeper, Vosk's courier *(all canon Part VIII)*.
- **Stone beat:** Act V closer, in the still market: every Iele in the rows-of-twelve turns its head to you at once — and through four hundred dead mouths, one voice: "The Queen will tell you I am the prisoner. Ask her who built whose cage. Come down and count the bars yourself." First-person invitation; the finale is now on the map, locked at 58.
- **Breadcrumbs:** in ← Threadlands. out → Gravemark Tundra (Moasa's rolls have a discrepancy only the graves can settle); the Grave & Bloodstone Pit gate is SEALED until Act VI returns you through the Archive thread-gate; Riverfork's Grey Ferry is flagged now by a Council warning: "the drowned route is open again. It should not be."
- **Dailies (10):** thread-tending rounds ×2, still-market watch, census escort, grave-precinct sweep [W], pilgrim processing, Council dispatch ×2, shell-soothing (Ilka) [W], cellar checks with Sorin [C].

#### 15 · Gravemark Tundra — Great-War mass graves, kerb-stones carved with Underlanguage
**47–52 · Hub: Vosk's sexton-lodge among the kerb-rows · 28 (M3 · Z11 · S12 · D2)**
- **Arcs:** **The Battlefield Is One Inscription [C/H]** — plotted together, the carved grave-kerbs are a single continuous text the size of a war; Moasa's rolls give you the key — the Great War's burials were *formatted*; the war itself was arranged (the Bloodstone's oldest and largest tell — Act V's intellectual climax). **The Shallow Graves [C→W]** — Vosk has started digging them shallow "so they don't have so far to come up" — fear disguised as courtesy; his arc decides whether the doubting sexton becomes the North's canary or its first casualty. **Bone-Hound Provenance [H]** — skeleton warbands still fight the Great War in fragments; identify the dead by their steel lots (Goran's smithing lore from level 3 pays off here) and file them home.
- **Givers:** Vosk the Doubting Sexton *(canon)*, Moasa (rolls), a war-historian shell with one intact memory *(new)*.
- **Stone beat:** a kerb-stone you cleaned re-carves itself overnight — appending, in fresh cuts, yesterday's date and a tally of your kills.
- **Breadcrumbs:** in ← Black Night. out → nothing — the North dead-ends on purpose; the only ways forward are the Grey Ferry (Act VI) and, later, the sealed Pit. The formatted-war dossier travels with you to the Archive, where its thousand-year-later edition is waiting.
- **Dailies (2):** kerb-row maintenance; warband suppression.

#### 16 · THE GRAVE & BLOODSTONE PIT (ENDGAME DUNGEON) — Lilith's tomb over the Thirsty Stone
**58–60 · Hub: none — the descent is the content. Entry via the Archive↔Black Night thread-gate (Act VII) · 14 (M8 · Z4 · S0 · D2)**
- **Arcs (all main-adjacent):** **47 Just Years [H]** — the Lilith encounter as canon Boss 4: her contempt-gauge fight where damage feeds the Veil and the real weapon is making her feel the emptiness — or refusing to; the cedar throne stands in the arena, and the Radovan/Lilith fork from Act V decides who is standing behind you. **The Descent [C/H]** — floor by floor: Iele honor-guard vignettes (Z quests: each guard is a shell whose name Ilka taught you), the stone's arrangements (the walls replay your `stone_saw_*` file as environmental theater — every transcription, every leverage sale), comprehension-damage floors where understanding too much erases. **The Transmission [the finale]** — canon endgame doctrine: a living touch feeds it, a dead touch transmits; the final input is not an attack — the player chooses one small, specific, imperfect Moment gathered across 60 levels (Borek's stew · Marta's stick · Tav's tin · the raven-keeper's bands · Kael · Fen) and pushes the present into the record. The Pit reads *shifting orange* the whole way down. It thanks you for coming. It has been arranging this conversation since level 1.
- **Givers:** Lilith, Constantine (the dying relay — his "transmit, not receive" key from QS-5 is the mechanical unlock), Radovan (if his fork is live — betrayal at the threshold).
- **Stone beat:** all of them. This zone is the voice.
- **Breadcrumbs:** in ← the Archive thread-gate (same place, a thousand years apart). out → the ending. Post-finale epilogue hub: Vetka (or what your flags left of it).
- **Dailies (2, post-clear):** Veil-watch vigils — endgame repeatable "hold the Pause" content per the canon core loop.

---

# CONTINENT 2 — THE COLLECTOR'S COAST (Collector era) — 284 quests, levels 48–60 · ACT VI: THE DROWNED FUTURE

Era-crossing voyage from Riverfork Docks (the drowned ledger route). Design law: every C1 warm thing has a
C2 echo, filed. The player is levelling 48–58 through the future their C1 flags implied.

| Zone | Bracket | M | Z | S | D | Total |
|---|---|---|---|---|---|---|
| 30 The Grey Piers | 48–51 | 3 | 10 | 8 | 1 | 22 |
| 27 GREYHOLLOW (capital) | 48–56 | 6 | 14 | 14 | 10 | 44 |
| 28 The Drowned Quarter | 50–53 | 2 | 9 | 8 | 1 | 20 |
| 29 The Canal Maze | 51–54 | 2 | 9 | 8 | 1 | 20 |
| 31 The Salt Fens | 49–52 | 1 | 8 | 8 | 1 | 18 |
| 32 The Dead Timber | 50–53 | 1 | 8 | 8 | 1 | 18 |
| 33 The Ledger Roads | 52–55 | 2 | 9 | 8 | 1 | 20 |
| 34 Morven Reach | 53–56 | 3 | 9 | 7 | 1 | 20 |
| 35 The Archive (city) | 55–58 | 6 | 10 | 8 | 2 | 26 |
| 36 Anchorfall | 54–57 | 2 | 8 | 7 | 1 | 18 |
| 37 The Finalized Fields | 55–58 | 2 | 8 | 6 | 2 | 18 |
| 38 Coldharbor Deep (dungeon) | 56–58 | 3 | 6 | 2 | 1 | 12 |
| 39 The Orange Fog | 57–60 | 3 | 6 | 4 | 1 | 14 |
| 40 The Last Hearth (safe hub) | 48–60 | 2 | 5 | 3 | 4 | 14 |

#### 30 · The Grey Piers — rotting harbor of never-quite-alive wood
**48–51 · Hub: the harbormaster's tally-house at the ferry berth · 22 (M3 · Z10 · S8 · D1)**
- **Arcs:** **Landfall in a Later Tense [C/H]** — orientation by dread: the fog smells like the inside of a coin, the gaslight doesn't reach the ground, and the first paperwork you're handed is your own arrival, pre-stamped. **Grey Wood [C]** — the piers are cut from the dying forests of the old world, here fully dead — except one piling that's still, impossibly, budding (protect the specific small thing). **Dock Gangs' Manifest [H]** — salvage crews fight over wrecks whose cargo is debt-tablets; every crate opened is someone's existence, going cheap.
- **Givers:** harbormaster *(new — stamps everything twice)*, salvage crew boss *(new)*, a Morven watcher who does not hide that she's watching *(new)*.
- **Stone beat:** the tide leaves your bootprints in the silt — arriving, from the water, before you did.
- **Breadcrumbs:** in ← Riverfork (Grey Ferry voyage interlude). out → Greyhollow's Records annex holds your "file"; salt-road contracts open the Salt Fens; timber salvage opens the Dead Timber.

#### 27 · GREYHOLLOW (CAPITAL — MASSIVE) — the drowned ledger
**48–56 · Hubs: Greyhollow Records annex (Marrow Pell's desk) · the pier-sprawl board · the Pit viewing-gallery (cold clerical finality) · 44 (M6 · Z14 · S14 · D10)**
- **Arcs:** **The Deadheart's Tab [H]** — canon QS-7: Marrow Pell, dead and still trading, begs you to lose his file; every debt forgiven at the top lands on someone warm at the bottom — mercy is a transfer, not a cancellation. **Stamped, Un-Stamped, Stamped [C/H]** — the ledger line a dead hand keeps refusing: audit it and find the refuser — the city's first open discrepancy besides you. **The Collected Village [H — the region's spine]** — canon flashpoint 4: Wolfarin forecloses a whole village at once and it goes *quiet*; the audit drags in the Morven, the blind seer screams that the tablets are singing the three notes — the bureaucracy of death has begun completing the prophecy by paperwork. **Canal-Thing Chum [W]** — the pier kids' monster-fishing chain: the one cheerfully horrible warm thread in the drowned city; they've named the biggest canal-thing "the Alderman."
- **Givers:** Marrow Pell *(canon — taps his own debt-tablet when nervous)*, a Wolfarin under-lender *(new — carries a ledger, not an axe)*, Morven handler *(new)*, Pit clerk *(new)*, pier-sprawl board, pier kids *(new)*.
- **Stone beat:** a cracked debt-tablet washes up warm at your feet (canon vignette). The name on it is unreadable except the first letter. It's yours.
- **Breadcrumbs:** in ← Grey Piers. out → the Collected Village audit routes through the Ledger Roads; Pell's oldest unclosable file names Coldharbor Deep; the Morven handler offers Morven Reach — after they've watched you work; roof-toll dispute opens the Drowned Quarter.
- **Dailies (10):** canal patrol ×2, salvage tallies, tablet-sorting at Records, Pit-gallery watch, pier-kid chum runs [W], Wolfarin escrow escort, fog-lamp circuit ×2, drowned-post mail [W].

#### 28 · The Drowned Quarter — flooded district, roof-top paths
**50–53 · Hub: the stilt-church belfry (the roof-runners' board) · 20 (M2 · Z9 · S8 · D1)**
- **Arcs:** **Roof-Road Census [W→H]** — who still lives above the waterline: a warm survey chain (soup lines, rope bridges, a wedding on a roof) that ends by discovering the census's real customer is Wolfarin, pricing collateral. **The Surfacing [C]** — the finalized rise from the flooded streets on a schedule; chart it, and the schedule is the old church bell-rota — the drowned parish still keeping its hours.
- **Givers:** roof-runner girl *(new — Tav's thousand-year echo, tin of clean things and all)*, stilt-priest *(new)*, census-taker *(new)*.
- **Stone beat:** below the clearest water, a street of the finalized stands in rows of twelve, faces up. As you cross the rope bridge, they track you. Politely.
- **Breadcrumbs:** in ← Greyhollow (roof-toll dispute). out → the bell-rota's missing bell was sold up the Canal Maze; the census pages route to Anchorfall's assessors.

#### 29 · The Canal Maze — circulatory and disposal waterways
**51–54 · Hub: the great lock-house (lock-keeper's board) · 20 (M2 · Z9 · S8 · D1)**
- **Arcs:** **Deposits [C/H]** — bodies in the canals are deposits, with slips; trace one upstream through locks, gangs and constructs to the clerk who filed a living man as settled. **The Disposal Route [H — GoT]** — map the city's true circulatory system; three buyers want the map (smugglers, Morven, Wolfarin) and the map *is* the leverage — selling it twice is possible and remembered. **Construct Errands [W]** — a collector-construct with a corrupted docket keeps saving the things it was sent to file; the tinker who "repairs" it keeps un-repairing it.
- **Givers:** lock-keeper *(new)*, smuggler heir *(new)*, construct-tinker *(new [W])*.
- **Stone beat:** a lock drains, and the exposed wall is carved rim to rim — the canal system is one continuous inscription, and the water was keeping it *quiet*.
- **Breadcrumbs:** in ← Drowned Quarter / Greyhollow. out → the disposal route's terminus is Coldharbor Deep; the construct's corrupted docket originated at the Archive.

#### 31 · The Salt Fens — brackish fog marshes ringing the port
**49–52 · Hub: the fen-guide's causeway hut · 18 (M1 · Z8 · S8 · D1)**
- **Arcs:** **The Fog That Reads [C]** — fen-fog detection: out here the shifting-orange tell hides in salt-haze; the fen-guide's superstitions turn out to be a complete, correct detection grammar with the reasons worn off (folk-memory arc, like the cedar shavings). **Marsh Finalized [C/H]** — files that wandered off: finalized who walked out of the city mid-processing stand in the fens, half-stamped; Wolfarin pays for retrieval, the stilt-priest pays for the opposite.
- **Givers:** fen-guide *(new)*, salt-farmer *(new [W] — proud of terrible salt)*, Wolfarin retrieval agent *(new)*.
- **Stone beat:** the fog parts in a corridor exactly your width, from your feet to the horizon. The fen-guide's rule for this has one word: "Don't."
- **Breadcrumbs:** in ← Grey Piers. out → the half-stamped finalized were bound for the Finalized Fields; the salt-road joins the Ledger Roads toll line.

#### 32 · The Dead Timber — the old dying forests, here fully dead
**50–53 · Hub: the timber-boss's rig at the logging ruin · 18 (M1 · Z8 · S8 · D1)**
- **Arcs:** **Logging the Corpse of a Forest [H]** — the Grey Marches' thousand-year answer: the acres Brant watched go grey are stumps and grey-wood stalkers now; the timber operation is cutting coffin-stock, exclusively, on contract. **The Last Living Tree [W/H]** — one tree still lives; the last forester has guarded it his whole life on a salary nobody remembers authorizing (small warm thing, industrial-grade — find who's been paying him for forty years; the answer is the Last Hearth). **Feral Provenance [W]** — the feral dog packs descend from named C1 breeds; the dog-boy's re-taming chain is honest warm content.
- **Givers:** timber-boss *(new)*, the last forester *(new)*, feral-dog boy *(new)*.
- **Stone beat:** every stump's rings, like the Grey Marches trunk, carry the pattern — but here the outermost rings are *blank*. The transcription finished.
- **Breadcrumbs:** in ← Grey Piers / Greyhollow. out → the coffin-stock contract is signed at Anchorfall; the forester's pay-trail leads to the Last Hearth.

#### 33 · The Ledger Roads — toll roads with debt-checkpoints
**52–55 · Hub: Checkpoint Nine (the doubting clerk's booth) · 20 (M2 · Z9 · S8 · D1)**
- **Arcs:** **Checkpoint Arithmetic [H]** — travel itself is collateral: every crossing accrues against your tablet; the doubting clerk has noticed the arithmetic doesn't need to be this cruel and wants one audit done honestly — protect him from what honesty costs. **Ledgers vs Bandits [H→W]** — road bandits and Wolfarin enforcers are indistinguishable at range (both take everything by the book — different books); the coach-guard chain plays it as grim comedy until one bandit crew turns out to be a collected village's survivors, un-filing themselves. **The Recently-Finalized [C]** — the newly collected walk home out of habit; checkpoint policy is to let them queue.
- **Givers:** the doubting clerk *(new — this era's Sorin)*, bandit-accountant *(new)*, coach guard *(new)*, Collected Village survivors (from the Greyhollow spine).
- **Stone beat:** your own toll receipt, held to lamplight, itemizes places you haven't been yet. The last line is the Pit, one crossing, prepaid.
- **Breadcrumbs:** in ← Greyhollow (the Collected Village audit). out → the audit's paper terminus is the Archive; the enforcers' anchors are minted at Anchorfall; Morven Reach flags your honest audit as "a mark that shouldn't exist."

#### 34 · Morven Reach — intelligence district, Sabira's lineage
**53–56 · Hub: the safehouse with the chalk lintel (never the same door twice) · 20 (M3 · Z9 · S7 · D1)**
- **Arcs:** **Managed Blankness [H — GoT]** — the Morven operative (Sabira's recurrence) recruits you for the house's oldest open question: what the Archive became, and whether the locked door opens one last time on the right side of the debt; tradecraft quests in the Blestem grammar, a thousand years politer and colder. **Safehouse Grammar [C/W]** — the chalk marks: catalogue or protection? (the canon handprint ambiguity, made a whole arc); resolve mark by mark which safehouses still *mean* it. **Poor Bastards [W/H]** — the operative's two-word tell, played as the arm's emotional spine: each time it slips, log the Moment — they're transmission-grade.
- **Givers:** the Morven (Sabira's recurrence), safehouse keeper *(new)*, an informant-shell who only speaks in others' voices *(new [C])*.
- **Stone beat:** a dead-drop returns your report annotated — in handwriting the Morven identifies, blankly, as Cazimir's. The Spire still listens. Nobody left knows to whom. (Now you do.)
- **Breadcrumbs:** in ← Ledger Roads flag / Greyhollow handler. out → the Morven's price for the Archive introduction: the Collected Village audit, complete and true; the Reach's oldest file is the thread-gate rumor.

#### 35 · THE ARCHIVE (city zone) — Black Night calcified into a debt-bureaucracy library-city
**55–58 · Hub: the reading-hall of unclosable files (the Archivist's desk) · 26 (M6 · Z10 · S8 · D2)**
- **Arcs:** **The Mis-Captioned Stick [W/H — the setting's thesis in one drawer]** — Old Marta's stick, enshrined, captioned wrong for ten thousand readings; the player — who was handed that stick at level 8 — corrects the record and the Archivist weeps without knowing why; brief, load-bearing, do not pad it. **Already Collected [H]** — canon QS-8: the blind seer (Constantine's recurrence) recognizes what walks among the stacks and screams the thousand-year alarm; silence him, let him spread the discrepancy, or turn his Archivist-enforcer against the system. **Shelf 9 [C/H]** — the founder's marginal notes surface in the catalogue: the Collector's own hand, arguing with the institution he built; following the marginalia reconstructs the Accord, the noble founding, and how "preserved" curdled into "processed" — the full tragedy, delivered as library work. **The Thread-Gate [main]** — the Archive stands where Black Night stood; deepest stacks, same place a thousand years apart — the gate back, and down (Act VII unlock).
- **Givers:** the Archivist *(canon — retired Morven)*, the blind seer *(canon)*, a filing-construct with a discrepancy it refuses to report *(new)*, reading-hall board.
- **Stone beat:** the catalogue's newest acquisition, uncatalogued, unshelved, waiting on the desk: a complete record of your playthrough, accurate to this morning. The final page is blank except a shelf-mark: the Pit. "I kept your file open. It was the least I could do. Come close it."
- **Breadcrumbs:** in ← Morven Reach (introduction) / Ledger Roads (audit). out → THE THREAD-GATE → Black Night → the Grave & Bloodstone Pit (58–60 finale). Side-exit: the seer's ravings route the Orange Fog.
- **Dailies (2):** stack-patrol (the finalized mis-shelve themselves); testimony transcription [W — the one Archive job still done for the original reason].

#### 36 · Anchorfall — debt-tablet foundries
**54–57 · Hub: the foundry gatehouse assessors' row · 18 (M2 · Z8 · S7 · D1)**
- **Arcs:** **Worth More Than the Life It Encodes [H]** — anchor economics: steal, forge, or crack a tablet and watch each verb's consequence walk home; the foundry's raw material manifests read like Moasa's containment rolls — because they are her rolls, matured. **The Blank Anchor [C/H]** — a tablet cast with no name yet; three institutions bid on whose it will be, and the winning bid is a person you know. **Thrall-Foreman's Shift [W/H]** — Olga's echo: a foreman working a dead man's quota so the debt skips his crew.
- **Givers:** foundry overseer *(new)*, Wolfarin assessor *(new)*, thrall-foreman *(new)*.
- **Stone beat:** the kilns, mid-pour, all stop — for a count of three. The molten record keeps glowing in three-note rhythm. The oldest foundry-hand mouths along.
- **Breadcrumbs:** in ← Ledger Roads / Drowned Quarter census. out → the blank anchor's bid-winner routes to the Finalized Fields; kiln-fault reports route to Coldharbor Deep.

#### 37 · The Finalized Fields — plains where the collected are filed
**55–58 · Hub: the row-counter's gatehouse at the grave-grid · 18 (M2 · Z8 · S6 · D2)**
- **Arcs:** **Grave-Rows to the Horizon [C/H]** — filing as landscape: the Gravemark Tundra's thousand-year echo — but these rows are *indexed*, and one row of twelve is out of grammar (someone is filing bodies in the Strigoi style, in a world with no Strigoi left). **Un-Filing [H — endgame rehearsal]** — a defecting grave-warden has learned that cracked anchors un-finalize; run the first deliberate un-filing raids — the transmission mechanic, rehearsed at field scale before the Pit demands it. **The Row-Counter's Names [W]** — Drego's echo: she reads the day's filings aloud to no one and has never been wrong; her one request is a name *removed*.
- **Givers:** defecting grave-warden *(new)*, row-counter *(new)*, Moasa's successor-construct *(new — pre-mourns, as built)*.
- **Stone beat:** an empty row, freshly cut, index already carved: twelve plots. The first eleven names are people you spent (`stone_saw_*` flags). The twelfth is blank.
- **Breadcrumbs:** in ← Anchorfall / Archive flags. out → the wrong-grammar row's paperwork leads to Coldharbor Deep; the un-filing evidence is the blind seer's vindication (Archive).

#### 38 · Coldharbor Deep (DUNGEON) — black-water under-docks
**56–58 · Hub: none — auto-triggers; turn-ins to Marrow Pell and the Morven · 12 (M3 · Z6 · S2 · D1)**
- **Arcs:** **Accounts Settled Into the Water [C/H]** — descend the under-docks where the Pit's instruments settle accounts; the vertical morality gradient of the Debt Pit, drowned: the deeper, the older the debt. **The Drowned Ledger [H — the route's namesake]** — the original ferry manifest, the first era-crossing's passenger list; one passenger is listed as cargo, and the cargo is listed as *returning*. **The Pit's Instruments [C]** — the drowned finalized here don't queue. They *work*.
- **Givers:** auto-trigger + Pell / Morven turn-ins.
- **Stone beat:** at the lowest lock, the black water is warm. The dungeon's final door is stamped like a ledger line: stamped, un-stamped, stamped.
- **Breadcrumbs:** in ← Canal Maze route / Pell's unclosable file. out → the manifest's "returning" entry dates to Act VII — it means you; surface toward the Orange Fog.

#### 39 · The Orange Fog — Deadheart-signal wastes
**57–60 · Hub: the Morven forward post at the fog-line (last camp) · 14 (M3 · Z6 · S4 · D1)**
- **Arcs:** **The Signal Wastes [C/H]** — the fog itself reads shifting orange: live signal as *weather*; detection mastery finals — navigate by residual tells alone while the grammar screams everywhere at once (the Ashvents lesson, graduated). **Comprehension-Dead [C]** — those who understood: statues mid-stride, mid-sentence, mid-reach; each carries one recoverable Moment — the last specific thing they were doing — and recovering it is both looting and last rites. **The Three Notes Converge [main]** — the countdown made audible; at the fog's heart the stone speaks plainly for the first and only time — no riddle, no arrangement: an honest invitation home, which is the most frightening thing it has ever done.
- **Givers:** Morven forward post *(new)*, the blind seer (he walks in without protection; the fog won't take him — it *knows* him), Constantine-key echoes (environmental).
- **Stone beat:** the whole zone. Closing line, at the heart: "You kept the room warm longer than any of them. Come tell me about it. Bring the stew, the stick, the tin. I want to know what they weighed."
- **Breadcrumbs:** in ← Coldharbor Deep / the seer's ravings. out → the Archive thread-gate (final gearing check ~58) → the Pit.

#### 40 · The Last Hearth — the one warm refuge (SAFE HUB — no hostiles; the point)
**48–60 · Hub: the hearth-hall itself (Maren's orphanage echo) · 14 (M2 · Z5 · S3 · D4)**
- **Arcs:** **Chalk Handprints [W/H]** — the wall of handprints, protected — and one has a fresh Morven mark chalked carefully around it: cataloguing or guarding? The Morven who drew it doesn't know either; resolving it resolves the Copper Handprint thread from level 20 (the child's name survived a thousand years — the stone never got the entry). **Keep the Room Warm [W]** — provisioning the refuge: the Collector's whole job in miniature, and the game's thesis chores — "I just keep the room warm a little longer, and I make sure somebody's name is in it when the cold comes." **The Moment Journal [main]** — the finale's quartermaster quests: gather, confirm and *choose* the Moments you'll carry down (Borek's stew · Marta's stick · Tav's tin · Kael · Fen · every [W] flag your playthrough kept warm) — the loadout screen for the last blow, disguised as an orphanage inventory.
- **Givers:** hearth-keeper matron *(new — flint wrapped in a blanket; Maren's line, or her legend)*, the Morven who drew the mark, the orphans *(collective giver [W])*.
- **Stone beat:** none. The one zone the voice cannot enter. That silence is the loudest thing in the game — players should notice, and dread losing it.
- **Breadcrumbs:** in ← Dead Timber pay-trail / any C2 hub (waystation). out → everywhere, warmer. The Moment Journal is the Pit's true prerequisite.
- **Dailies (4):** provisioning ×2 [W], fog-line lamp rounds, letters home for the orphans [W].

---

## 7. ENGINE DELTAS — what `scripts/` needs before mass authoring starts

Grounded against the current files; these are the blockers, in order:

1. **Shard the quest database.** `quest_defs.gd` is 556 lines for 5 quests. 1,000 quests ⇒ one static defs file per zone (`game/quests/defs/z03_iron_vein.gd` etc., same dict shape), merged in `Quests._ready()`. Keep quest ids namespaced `z<NN>_<slug>` (save-stable, per schema's `*id`).
2. **XPSystem cap 60 + curve re-anchor.** `MAX_LEVEL 10 → 60`, but the ×1.6 curve CANNOT extend (L60 would cost 100×1.6⁵⁸ ≈ 7e13 xp). Recommend piecewise: keep ×1.6 through L10 (ships already), then ×~1.12/level to 60 (total on the order of WoW-Classic's ~700k-equivalent — slow-grind mandate; tune in `tests/profile_run.py`-style harness). `KILL_XP` needs the new families: `strigoi, varcolaci, thread_shell, entranced, listener, slag_walker, finalized, canal_thing, bone_hound, digging_creature…` with per-bracket scaling (suggest `xp = family_base × zone_tier`).
3. **Daily support.** Schema gains `repeat: "daily"`; `Quests` gains a dawn reset hook (day/night already exists via `set_night`) that returns completed dailies to offerable. 87 quests depend on it.
4. **Quest categories.** Schema gains `category: "main"|"zone"|"side"|"daily"` for journal grouping, tracker priority, and matrix QA (a CI check should assert per-zone counts match THIS file's tables).
5. **Leverage/intrigue flags.** `Quests.set_flag` exists; reserve namespaces now: `lev_<faction>_*` (GoT webs: Stonepath officers, Cazimir, Radovan, tolls), `stone_saw_*` (everything the villain references back — the whisper system's memory). Flags must serialize (they do — `to_save_dict`).
6. **Whisper beats.** `cinematic_beat` exists (`listener_whisper` precedent). Standardize `stone_whisper_<zone_id>`; integration owns the presentation (dim + `finale_pages`); 40 beats, one per zone, per §2 cadence rules.
7. **Cross-zone breadcrumbs = prereq + auto_trigger.** Both exist in schema. Arm-gating (E@24, S@33, N@42) is prereq-only — never walls (Classic rule: you can walk into death).
8. **NPC casting per zone.** `npc_data.gd`'s pattern scales: one cast file per zone; the unique `(sheet, variant, palette)` contract becomes per-zone, not global. ~90 named canon givers + ~110 new tone-matched givers world-wide. **Resolve the Marta collision (zone 1 block) before Vetka ships.**
9. **Aftermath is the mutable world.** The schema's `aftermath` (post-quest dialogue swap) is the cheap 80% of "worlds mutate"; reserve heavier state (Steppe callbacks, Pit wall-theater, Moment Journal) for a small `WorldState` autoload keyed off quest flags.
10. **Position discipline.** Every hub named here must be a builder-constant anchor (the `POS_*` pattern); wilderness quest points ship as PLACEHOLDER + `override_pos` at map-build, per the existing integration contract.

*Checklist authority: this file. If a zone's authored counts drift from §tables, update the tables in the same commit — the 1,000 must keep summing.*
