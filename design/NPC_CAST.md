# RAVEN HOLLOW — ZONE NPC CAST (all 40 zones)
Canon sources: `_lore_extract.txt` Parts IV (regions), V (factions), VII (principal cast), VIII (supporting cast), IX (bestiary), XI (game hooks). Zone list: `WORLD_PLAN.md`. Engine binding: `scripts/npc_data.gd` (cast defs), `scripts/quest_defs.gd` (`giver` / `turn_in_npc` reference NPC ids).

Design law carried from the bible: **every NPC is somebody's small mercy or small rot.** Each named entry below either carries a "warm imperfect thing" (the ammunition the Bloodstone wants erased) or embodies a faction's appetite. Flavor NPCs are never neutral set-dressing — their barks are symptom-ladder telemetry (warm ground, copper wells, dead yeast, aligned dust, listening).

---

## 0. Legends & engine conventions

### Role tags
| Tag | Meaning |
|---|---|
| **QG** | Quest-giver (referenced by `quest_defs.giver`; usually also turn-in) |
| **TI** | Turn-in / quest-target only (talked to inside quests, gives none) |
| **V** | Vendor (goods, repairs, travel, food) |
| **T** | Trainer (class/profession/detection skills) |
| **F** | Flavor / ambient barks (aftermath-dialogue targets) |
| **S** | Story set-piece (principal cast, cinematic beats, `finale_speaker`) |

Tags combine (QG+V etc.). Every zone hub needs ≥1 QG and ≥1 V; capitals need trainers.

### NPC id convention
Zone-prefixed snake_case ids so `quest_defs.giver` strings stay unambiguous across 40 zones: `vk_marta`, `aw_fielderine`, `bn_radovan`, `gh_pell`. Existing Raven Hollow ids (`innkeeper`, `blacksmith`, …) are grandfathered. Per-zone cast files should mirror `NPCData.cast()` (`npc_data_<zone>.gd` or one registry keyed by zone) and keep the UNIQUE-VILLAGER CONTRACT: named cast pass no `palette`; generics get colorways.

### Sprite families (from our packs)
| Code | Family | Source |
|---|---|---|
| **B:m1–m4 / f1–f2** | Base villager sheets + palette colorways | `assets/art/characters/npc_*.png` |
| **MAID** | Tavern maid sheet | `assets/art/characters/tavern_maid` |
| **SZ:vill / SZ:elder / SZ:merch / SZ:guard / SZ:noble / SZ:priest** | Szadi NPC characters pack, role sheets | `_downloads/szadi_npc_characters.zip` |
| **CC** | Bespoke hand-authored sheet via char-creator kits (principals only — fixed signature looks) | `_downloads/char_creator/rahmat_customization_32`, `mana_seed` |
| **SK** | Skeleton/undead re-tints (Iele shells, thread-shells, the finalized) | Admurin skeletons + WORLD_PLAN re-tints |
| **NV** | Strigoi/vampire + cultist humanoids — **PACK NEEDED** (WORLD_PLAN gap) | vampire/cultist pack |
| **NW** | Varcolaci/werewolf humanoids — **PACK NEEDED** (WORLD_PLAN gap) | werewolf pack |
| **NG** | Wraith/ghost (debt-wraiths, canal-things as NPCs) — **PACK NEEDED** | ghost pack |
| **CHILD** | Small-frame child sheet — **PACK NEEDED** (orphans, Tav, Mihu; scale-down of B sheets acceptable stopgap) | — |

Rule of thumb: principals = CC bespoke; hub humans = SZ role sheets; wilderness bit-parts = B sheets + palette; monstrous-faction civilians = NV/NW/SK with clothing overlays. Iele "shells" deliberately reuse **B/SZ villager sheets standing unnaturally still** — per WORLD_PLAN, "standing still IS the horror" — reserve SK for the visibly dead.

### Voice archetypes (TTS cast — feeds the `_vo_v2` pipeline)
A closed set of 16 reusable archetypes; every NPC maps to one (+ optional FX chain).

| Code | Archetype | Direction |
|---|---|---|
| **V-ELDER-F** | Worn rural woman | Warm gravel, unimpressed, zero drama (Old Marta baseline) |
| **V-ELDER-M** | Old man | Slow, dry, pauses like shoveling |
| **V-MATRON** | Working-age woman, brisk | Innkeepers, quartermasters; warmth under efficiency |
| **V-GRUFF-M** | Blunt tradesman | Short sentences, no thanks given (Borek baseline) |
| **V-SLY-M / V-SLY-F** | Fence, smuggler, broker | Amused, transactional, never surprised |
| **V-NOBLE-F** | Measured court voice | Quiet authority; says little, means all of it (Fielderine) |
| **V-NOBLE-M** | Orator | Performed vigor, loves own sound (Vasile) |
| **V-SOLDIER** | Clipped ranks voice (m/f variants) | Report cadence; tired professionalism |
| **V-YOUTH-M / V-YOUTH-F** | Young adult | Bright or sullen; the only fast talkers in the game |
| **V-CHILD** | Child | Sparse use; devastating by placement |
| **V-WHISPER** | The entranced / listeners | Flat calm + faint 3-note hum bed; slight time-stretch FX |
| **V-DEAD** | Iele shells, the finalized | Airless monotone, no breath sounds, close-mic dry |
| **V-BEAST** | Varcolaci | Low growl-filtered chest voice; consonants chewed |
| **V-CLERK** | Archive/Collector-era bureaucracy | Cold clerical finality; stamps as punctuation |
| **V-SEER** | Constantine / Blind Seer | Fractured relay cadence, doubled take faintly under main |
| **V-STONE** | THE BLOODSTONE (inscription stones, the Pit) | Not a voice — a chorus of every other archetype at once, orange-signal beats; whispers the player's own quest log back at them |

**V-STONE is the main villain's voice** and appears in *every* wild zone via inscription stones (WORLD_PLAN inscription network). It is cast once and reused game-wide — the WotLK-style tease: it congratulates, tempts, and grades the player from zone 2 to the Pit.

---

## 1. Canon principal placement map (Parts VII–VIII → zones)
| Figure | Home zone | Notes |
|---|---|---|
| Old Marta | 2 Vetka | Tutorial mentor; her stick recurs in 35 The Archive |
| Borek | 2 Vetka | First employer, Q0 "Honest Work" (bible XI) |
| Torn / Dorica / Gren | 2 Vetka | Symptom-ladder trio; Torn degrades across the arc |
| The Courier | 5 Chamber Depths | Corpse set-piece; sealed satchel = quest hook |
| Constantine | 6 Stonepath (roams N) | Relay; hands over "transmit, not receive"; recurs as 35's Blind Seer |
| Queen Fielderine | 7 Angel Wings | Lead Vault; the box that stays closed |
| Maren | 7 Angel Wings | Orphanage; "save the small thing" chain |
| Quartermaster Helva / Lead-Box Warden / Old Fisherman Cott | 7 / 7 / 11 | Cott by the river he taught her on |
| Scout-Widow Pall | 9 Grey Marches | Fog-line early-warning |
| Council of Six (Vasile, Radovan, Moasa, Petran, Dumitra, Sorin) | 12 Black Night | GoT small-council theater over horror |
| Threadwarden Ilka / Grave-Sweeper / Vosk | 12 Black Night | |
| Lilith | 16 The Pit (presence over all N zones) | Nightly patrol = ambient N-zone events |
| Cazimir | 17 Blestem | Speaks from walls — an NPC with no sprite in most scenes |
| Sabira | 17 Blestem | Player's intrigue handler; Morven origin |
| Nistor / Vera Cold-Hands / the Lift-Boy | 17 Blestem | |
| Brother Ansel | 20 Transcub Vale | |
| Valrom / Ilion / Anara | 22 Sangeroasa | Anara hidden inside the war-machine |
| Olga / Drego / Tav | 22 Sangeroasa | Ruja in 23 The Gift |
| Marrow Pell | 27 Greyhollow | Collector-era hub broker |
| The Archivist (retired Morven) | 35 The Archive | Marta's-stick drawer scene |
| The Blind Seer (Constantine's recurrence) | 35 The Archive | "Already collected — why is it still walking?!" |
| Hessik | Nowhere (dead centuries) | Exists as the book; alchemy trainers game-wide teach "from Hessik's margins" |
| Kael / Fen | No zone | Ambient-guilt names only; surface in fragments, never cast |

### ⚠ Name collisions with existing `npc_data.gd` (fix before Batch A ships)
| Existing RH NPC | Collides with canon | Recommendation |
|---|---|---|
| Innkeeper **Marta** (Ember Hearth) | **Old Marta**, Vetka (canon, load-bearing) | Rename display to **Innkeeper Magda** (id `innkeeper` unchanged; saves safe) |
| Farmer **Ansel** | **Brother Ansel**, Transcub (canon) | Rename display to **Farmer Anton** |
| Gravekeeper **Vasile** | **Councilor Vasile**, Black Night (canon) | Rename display to **Gravekeeper Voicu** — OR keep as deliberate irony (a gravekeeper sharing the Loudest Thread's name) and lampshade it in one bark. Prefer rename; two quest-givers named Vasile will confuse `giver` debugging |

---

## 2. ZONE ROSTERS — CONTINENT 1 (26 zones)

### Interior Seams — Border Region

#### Zone 1 · Raven Hollow (starter village — 11)
Existing cast retained (renames per §1). Faction: none/Border.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `innkeeper` | Innkeeper Magda | QG,V | Feeds you before she trusts you | B:f1v0 | V-MATRON |
| `blacksmith` | Blacksmith Goran | QG,V,T(weapons) | Prefers nails to wishes | B:m2v1 | V-GRUFF-M |
| `merchant` | Merchant Tibalt | V | Optimism as a sales tactic | B:m3v2 | V-SLY-M |
| `farmer` | Farmer Anton | F,QG | Talks to wheat more than people | B:m4v0 | V-ELDER-M |
| `gravekeeper` | Gravekeeper Voicu | QG | Patient; considers you a future client | B:m2v3 | V-ELDER-M |
| `maid` | Maid Elsbeth | F | Run off her feet, hears everything | MAID | V-YOUTH-F |
| `wanderer1` | Old Petra | QG,F | Remembers the fountain singing — once | B:f2v1 | V-ELDER-F |
| `wanderer2` | Young Emeric | QG | Wants the road more than the road wants him | B:m1v2 | V-YOUTH-M |
| `gatewarden` | Gatewarden Iosif | QG | Counts wolves that pace like surveyors | B:m4v1 | V-SOLDIER |
| `mira` | Mira | S | The first listener the player meets | B:f1v2 | V-WHISPER |
| `rh_codrin` *(new)* | Veteran Codrin | T(combat) | One war too many; teaches so he can stop | SZ:guard | V-SOLDIER |

#### Zone 2 · Vetka (starter village — 8)
The bible's ground zero. First monster is a symptom. Faction: none.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `vk_marta` | Old Marta | S,QG,T(herbalism) | Rural competence; worried you're tracking mud | CC | V-ELDER-F |
| `vk_borek` | Borek | QG | Won't say thank you; leaves the bowl out | CC | V-GRUFF-M |
| `vk_torn` | Torn | QG→TI | Finds the marks "interesting"; hums 3 notes | B:m3v0 | V-YOUTH-M→V-WHISPER |
| `vk_dorica` | Dorica | QG | Blames her hands for what the world does to yeast | B:f2v0 | V-MATRON |
| `vk_gren` | Gren | QG,F | Fear wearing common sense; digs graves just in case | B:m2v0 | V-GRUFF-M |
| `vk_stanciu` | Reeve Stanciu | F,V | Files complaints against the fog itself | SZ:vill | V-ELDER-M |
| `vk_ionel` | Ionel | F | Child; asks the questions adults won't | CHILD | V-CHILD |
| `vk_ferryhand` | Ferry-hand Nicu | V(travel) | Waystation node; poles the marsh punt to the Bent Oar | SZ:vill | V-YOUTH-M |

#### Zone 3 · The Iron Vein (bog hub — 6)
The Bent Oar tavern = Border quest board. Faction: none.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `iv_rodica` | Rodica the Oar-Wife | QG,V | Runs the Bent Oar; bans knives, not grudges | SZ:merch | V-MATRON |
| `iv_luca` | Ferryman Luca | V(travel) | Charges double after dark, and is right to | SZ:vill | V-ELDER-M |
| `iv_vadim` | Trapper Vadim | QG | Sells hides; won't trap the north bank anymore | B:m4v2 | V-GRUFF-M |
| `iv_zorka` | Zorka the Stillwife | T(alchemy),V | Teaches from a stolen copy of Hessik's *Practical Foundations*; her margins argue with his | SZ:elder | V-ELDER-F |
| `iv_petre` | Drowned-Holding Petre | QG | Farms a flooded field because his family is under it | B:m1v1 | V-ELDER-M |
| `iv_bogdana` | Barge-widow Bogdana | F | Watches the red river; counts what floats | B:f2v2 | V-ELDER-F |

#### Zone 4 · The Copper Wells (poisoned moors — 5)
Environmental-puzzle tutorial: read the land. Faction: none.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `cw_petru` | Dowser Petru | QG | Tastes well-water for a living; is losing the taste | SZ:elder | V-ELDER-M |
| `cw_iulia` | Pilgrim Iulia | TI,F | Half-entranced; still remembers her sister's name — barely | B:f1v3 | V-WHISPER |
| `cw_costel` | Costel of the Empty Farm | QG | Lone unlooted-farmstead survivor; packs, never leaves | B:m3v3 | V-GRUFF-M |
| `cw_tinker` | Tinker Maree | V | Sells lead sheeting and doesn't say why it sells | SZ:merch | V-SLY-F |
| `cw_stone` | *Inscription Stone (crossroads)* | S | THE VILLAIN'S FIRST DIRECT ADDRESS — knows the player's name | (prop) | V-STONE |

#### Zone 5 · The Chamber Depths (dungeon — 3)
Dread by absence: almost no one, and one of them is dead.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `cd_courier` | The Courier | TI,S | Corpse set-piece; sealed satchel, clean fingernails — someone still waits on his letter | SK(dressed) | (none) |
| `cd_aurel` | Scholar Aurel | QG | Camped at the entrance, "just cataloguing"; the vector is curiosity and he is all vector | SZ:priest | V-YOUTH-M |
| `cd_mihu` | Lantern-boy Mihu | F,V(supplies) | Sells torches at the door; will not cross the threshold, ever | CHILD | V-CHILD |

#### Zone 6 · The Stonepath (crossroads wilds — 5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `sp_constantine` | Constantine | S,QG | Red-flicker eyes; relays a signal he hates; first met arguing with a standing stone | CC | V-SEER |
| `sp_coachman` | Coachman Grigor | V(travel) | Four-kingdom waystation; neutral because nobody pays him enough to have a side | SZ:vill | V-ELDER-M |
| `sp_vlaicu` | Mapmaker Vlaicu | V,QG | Sells maps with one road always drawn wrong — on purpose, he says | SZ:merch | V-SLY-M |
| `sp_scriber` | The Stone-Scriber | TI,S | Heretic copying inscriptions "to warn people"; the game's first look at a doomed transcriber | NV(cultist) | V-WHISPER |
| `sp_handprint` | *The Shortening Inscription* | S | Dead man's handprint; marks fading — V-STONE reads the countdown aloud if examined twice | (prop) | V-STONE |

### WEST — Angel Wings (Humans, Queen Fielderine)

#### Zone 7 · Angel Wings (CAPITAL — 18)
Poor, crowded, ordinary — the capital that feeds people. Faction: Human/Accord.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `aw_fielderine` | Queen Fielderine | S,QG | Says no to the box every night; that is her whole reign | CC | V-NOBLE-F |
| `aw_maren` | Maren | S,QG | Flint in a blanket; serves every fish but trout | CC | V-MATRON |
| `aw_helva` | Quartermaster Helva | QG,V | Counts grain like Cazimir counts secrets; private ledger of fed children | SZ:guard | V-SOLDIER |
| `aw_leadwarden` | The Lead-Box Warden | F | Never opened it; certain it opens itself (use sparingly — queen's-level secret) | SZ:guard | V-SOLDIER |
| `aw_neagu` | Mistress Neagu | QG(intrigue) | Fielderine's quiet intelligencer; trades in what Blestem thinks it knows | SZ:noble | V-NOBLE-F |
| `aw_dockmaster` | Dockmaster Iordan | QG,V(travel) | River-gate waystation; hates barges, loves rivers | SZ:vill | V-GRUFF-M |
| `aw_brana` | Grain-Factor Brana | V | Sells flour by honest weight — radical, in a famine | SZ:merch | V-MATRON |
| `aw_cook` | Orphanage Cook Tudora | F,QG | Feeds forty on rations for twelve; won't explain the math | SZ:elder | V-ELDER-F |
| `aw_captain` | Guard-Captain Osric | QG,T(warrior) | Drills militia he prays never deploy | SZ:guard | V-SOLDIER |
| `aw_gable` | Gable the Rat-Catcher | QG | Cheerful (WoW-tonal): rates the castle's rats by personality | B:m3v4 | V-YOUTH-M |
| `aw_preacher` | Bread-Preacher Simion | F | Preaches that hunger is a message; is closer to right than he knows | SZ:priest | V-ELDER-M |
| `aw_seamstress` | Seamstress Vera | V,F | Sews chalk-white burial shrouds and christening gowns from one bolt | B:f2v4 | V-ELDER-F |
| `aw_fence` | Thatch-Row Ferka | V,QG | Fence in the sprawl; Neagu's unwitting sensor | SZ:merch | V-SLY-F |
| `aw_herald` | Herald Ludovic | F | Announces good news only; the silences are the news | SZ:noble | V-NOBLE-M |
| `aw_healer` | Sister Casilda | T(healer),V | Infirmary nun; triages by who can still be saved and hates herself for it | SZ:priest | V-MATRON |
| `aw_bargewright` | Bargewright Emeric Snr | F,V | Young Emeric's uncle — the road the boy dreams of starts at his slip | B:m4v3 | V-GRUFF-M |
| `aw_orphan_1` | Chalk-Hand Pia | F | Orphan; her handprint on Maren's wall is the copper-stained one | CHILD | V-CHILD |
| `aw_lera` | Archivist-Postulant Lera | QG | Cataloguing kindnesses "so someone remembers"; proto-Archive, played warm | SZ:vill | V-YOUTH-F |

#### Zone 8 · The Western Lowlands (5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `wl_elder` | Elder Marga (Full-Granary Village) | QG | Presides over famine beside a full granary no one will open — the vignette walks | SZ:elder | V-ELDER-F |
| `wl_deserter` | Bandit-Deserter Radu | QG | Left the bandit-lords when they started taking food *to* the east | B:m2v4 | V-GRUFF-M |
| `wl_miller` | Miller Iustina | QG,V | Her wheel turns; her bread won't rise; she's begun to hate the river | B:f1v4 | V-MATRON |
| `wl_clerk` | Granary-Clerk Pavel | TI,F | The man with the key and the orders; small rot in a wool coat | SZ:merch | V-CLERK |
| `wl_drover` | Drover Anghel | V(travel),F | Waystation; walks cattle west and won't say what he saw walking east | SZ:vill | V-ELDER-M |

#### Zone 9 · The Grey Marches (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `gm_pall` | Scout-Widow Pall | S,QG | Smells a coppering well a mile off; wishes she couldn't | CC | V-SOLDIER |
| `gm_burner` | Charcoal-Burner Tase | V,F | Sells fire in a forest that's forgetting how to burn | B:m1v3 | V-GRUFF-M |
| `gm_novice` | Cult-Novice Anica | QG,TI | Fled the hungering cults; still flinches at supper bells | B:f1v5 | V-YOUTH-F |
| `gm_forester` | Forester Dinu | QG | Marks dying trees; ran out of marks | SZ:vill | V-ELDER-M |

#### Zone 10 · The Famine Fields (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `ff_ileana` | Baker Ileana | QG | Bakes flat grey loaves and apologizes to each one | B:f2v3 | V-MATRON |
| `ff_surveyor` | Surveyor Corvin | QG,TI | Maps the hunger belt with unsettling satisfaction; someone pays him. Who? | SZ:merch | V-CLERK |
| `ff_saltman` | Salt-Pedlar Ghiță | V | Cheerfully sells the one thing the Yeastless fear; business is *booming* | SZ:merch | V-SLY-M |
| `ff_witness` | Mad Costache | F | Survived the burned farmstead; describes the scratch-marks *inside* the lead box | B:m3v5 | V-WHISPER |

#### Zone 11 · Riverfork (6)
Continent link — the Grey Ferry sails from here.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `rf_tollcaptain` | Toll-Captain Ancuța | QG,V | Taxes three kingdoms' smugglers with perfect even-handedness | SZ:guard | V-SOLDIER |
| `rf_smuggler` | Wren the Smuggler-Queen | QG,V | Moves anything except inscriptions; found out the hard way | SZ:merch | V-SLY-F |
| `rf_ferrymaster` | Grey-Ferry Master Toma | V(travel),S | Sails the drowned ledger route; logs each crossing twice, in two different years | SZ:elder | V-ELDER-M |
| `rf_cott` | Old Fisherman Cott | S,QG,F | Taught the trout-thief to fish, twice — the second time on purpose | CC | V-ELDER-M |
| `rf_drakeman` | Drake-Hunter Bela | QG | Hunts river-drakes; keeps every hook that's ever failed him | B:m2v5 | V-GRUFF-M |
| `rf_hermit` | Bridge-Hermit Uță | F | Lives under the second bridge; tolls in riddles nobody has to answer | B:m4v4 | V-ELDER-M |

### NORTH — Black Night (Iele / undead, Lilith)

#### Zone 12 · Black Night (CAPITAL — 16)
No fog, unnatural clarity, bitter cold. Faction: Iele.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `bn_vasile` | Councilor Vasile, "the Loudest Thread" | S,QG | Clears a throat that hasn't held breath in 300 years; the misdirect | CC | V-NOBLE-M |
| `bn_radovan` | Councilor Radovan, "the Quiet Thread" | S,QG | When he finally speaks, the room has already lost; kingmaker price-later intel | CC | V-DEAD (measured) |
| `bn_moasa` | Councilor Moasa, "the Ledger" | QG | Files each new shell with a private word nobody asked for — the Archive's buried mercy, in embryo | SZ:noble | V-CLERK |
| `bn_petran` | Councilor Petran, "the Empty Chair" | F | Agrees with whoever spoke last; a warning that walks | SZ:noble | V-DEAD |
| `bn_dumitra` | Councilor Dumitra, "the Old Grievance" | QG | Still fighting the Great War in committee | SZ:noble | V-NOBLE-F |
| `bn_sorin` | Councilor Sorin, "the Doubter" | QG,S | Leaves early "to check the cellars"; the player's inside man — or first casualty | SZ:noble | V-ELDER-M |
| `bn_ilka` | Threadwarden Ilka | QG | Names the shells under her breath; regulations forbid it | CC | V-MATRON |
| `bn_sweeper` | The Grave-Sweeper | S,QG,F | Leaves cedar shavings on the stone; his grandmother did too | SZ:elder | V-ELDER-M |
| `bn_vosk` | Vosk, the Doubting Sexton | QG | Digs the graves shallow "so they don't have so far to come up" | SZ:vill | V-GRUFF-M |
| `bn_stillmarket` | Still-Market Overseer Ecra | V | Sells to the living with the patience of someone who can wait you out — literally | SK(robed) | V-DEAD |
| `bn_cedarseller` | Cedar-Monger Fira | V,F | Sells shavings to mourners; doesn't know she's selling folk-memory of the throne | B:f2v5 | V-ELDER-F |
| `bn_embassy` | Embassy-Clerk Laurian | QG(intrigue) | Living Accord attaché; writes home less and less | SZ:merch | V-CLERK |
| `bn_threadtender` | Thread-Tender Neluș | T(detection) | Teaches blue-sight; "you learn to see the leash so you never mistake it for the dog" | SZ:priest | V-ELDER-M |
| `bn_processor` | Pilgrim-Processor Odeta | F,TI | Registers arrivals from the Threadlands; her queue never shortens and never complains | SZ:vill | V-CLERK |
| `bn_polisher` | Shell-Polisher Bibi | F | Creepy-cheerful: grooms the standing dead "because everyone deserves market-day best" | B:f1v6 | V-YOUTH-F |
| `bn_lastwarm` | Keeper of the Last Warm Inn | V,QG | Runs the one heated taproom for living visitors; stokes the fire like an argument | SZ:merch | V-MATRON |

#### Zone 13 · The Threadlands (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `tl_shepherd` | Pilgrim-Shepherd Iov | QG | Walks the pilgrim road turning people back; fails, daily | SZ:elder | V-ELDER-M |
| `tl_child` | Sanda of the Cold Camp | QG,TI | Sole survivor of the three-bedroll vignette; footprints in, none out — hers never left | CHILD | V-CHILD |
| `tl_surveyor` | Thread-Surveyor Vlad | F | Charts filament drift; the charts keep pointing at the same buried spot | SZ:merch | V-CLERK |
| `tl_hunter` | Snow-Hunter Ozana | V | Sells furs and one rule: never camp where the snow won't settle | B:f2v6 | V-SOLDIER |

#### Zone 14 · The Listening Steppe (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `ls_windreader` | Wind-Reader Baba Irina | QG | Reads weather in grass; the grass has started reading back | SZ:elder | V-ELDER-F |
| `ls_warden` | Cluster-Warden Matei | QG | Tends the standing entranced like an orchard he can't harvest | SZ:guard | V-SOLDIER |
| `ls_drover` | Steppe-Drover Costin | V(travel) | Waystation; his horses refuse certain ground and he's stopped arguing | SZ:vill | V-GRUFF-M |
| `ls_digcultist` | The Kneeling Man | F,TI | Waits at a tunnel-mouth for the Digging Creature "to confirm receipt" | NV(cultist) | V-WHISPER |

#### Zone 15 · Gravemark Tundra (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `gt_registrar` | War-Graves Registrar Sofron | QG | Six hundred years of names; refuses to abbreviate a single one | SZ:elder | V-CLERK (warm variant) |
| `gt_trapper` | Bone-Hound Trapper Ruxa | QG,V | Traps what digs its way up; sells the collars she finds already on them | B:f1v7 | V-GRUFF-M |
| `gt_scholar` | Kerb-Stone Scholar Damian | QG,TI | Transcribing the Underlanguage kerbs "safely, in fragments"; there is no safely | SZ:priest | V-YOUTH-M |
| `gt_sentinel` | The Standing Soldier | F | A threaded Great-War shell still at his post; salutes rank he can no longer see | SK | V-DEAD |

#### Zone 16 · The Grave & Bloodstone Pit (endgame dungeon — 4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `pit_lilith` | Lilith | S | "47 years… they gave me a pit." Warden, mother, jailer; the final door | CC | V-NOBLE-F (dual register) |
| `pit_revenant` | The Cedar Revenant | S(boss) | The throne's memory of her; laid to rest by witness, not force | bespoke boss | V-DEAD + wood-creak FX |
| `pit_sweeper` | The Grave-Sweeper (descended) | TI | The only one who goes near daily; carries cedar shavings all the way down | SZ:elder | V-ELDER-M |
| `pit_stone` | THE BLOODSTONE | S(final boss) | The arranging machine; every inscription-stone whisper in the game was this | (environment) | V-STONE |

### EAST — Blestem (Strigoi, Cazimir)

#### Zone 17 · Blestem (CAPITAL — 16)
Maze-city, perpetual dusk, information as currency. Faction: Strigoi.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `bl_cazimir` | Cazimir | S,QG | Speaks from the walls — no sprite in most scenes; inventories, never speculates | CC (rare embodied) | V-NOBLE-M (stone-reverb FX) |
| `bl_sabira` | Sabira | S,QG | Managed blankness; the "poor bastards" tell — the player's intrigue handler | CC | V-SOLDIER (f, flattened) |
| `bl_nistor` | Nistor, the Sightline Sweeper | QG | Abolishes blind spots for a living; sells them on the side; keeps one corner for himself | SZ:vill | V-ELDER-M |
| `bl_vera` | Vera Cold-Hands | V,QG | Lower-Market fence; pays extra for kindnesses — warm stories are the rare coin here | SZ:merch | V-SLY-F |
| `bl_liftboy` | The Lift-Boy | F,QG | Runs the Riddler's Quarter lift; memorized its true pattern; will never tell | CHILD | V-CHILD |
| `bl_handler` | Quarter-Handler Iepure | T(rogue) | Trains "professional noticing"; graduation is walking his maze unremarked | NV | V-SLY-M |
| `bl_lampman` | Lamp-Oil Vintilă | V | Sells light by the hour in a city designed for watching | SZ:merch | V-SLY-M |
| `bl_notary` | Information-Notary Zaraza | V,QG | Certifies rumors; a lie with her seal costs triple, and is worth it | SZ:noble | V-NOBLE-F |
| `bl_enforcer` | Enforcer-Captain Dragoș | QG | Strigoi muscle who finds the whole intrigue economy vulgar; nostalgia for honest fangs | NV | V-SOLDIER |
| `bl_tithe` | Blood-Tithe Clerk Sorel | F | Collects the tithe with a wine-steward's manner | NV | V-CLERK |
| `bl_widow` | Widow Iridenta | QG,TI | Her husband is one of the 12 boot-prints facing the dead-end wall | B:f2v7 | V-ELDER-F |
| `bl_lichenfactor` | Lichen-Factor Miron | V,QG | Exports glow; imports rumors; both spoil in transit | SZ:merch | V-SLY-M |
| `bl_recruiter` | Listener-Watch Recruiter Ela | QG(sinister) | Recruits watchers for the passes; retention is… clerically described | NV | V-CLERK |
| `bl_ivy` | Ivy-Warden Coman | F | Trims the Transcub churches' ivy inside city walls; the ivy grows back in words | SZ:vill | V-ELDER-M |
| `bl_chirurgeon` | Chirurgeon Alba | T(healer),V | Patches up duel losers; strictly cash, strictly no questions about tooth-marks | SZ:priest | V-MATRON |
| `bl_beggar` | The Grateful Beggar | F | Blestem's tonal counter-beat: genuinely happy; nobody can find out *why*, and it drives the spies mad | B:m1v4 | V-ELDER-M |

#### Zone 18 · The Eastern Ridges (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `er_passwarden` | Pass-Warden Strigoi Vlascu | QG | Counts travelers up; counts fewer down; files the difference | NV | V-SOLDIER |
| `er_goatherd` | Goat-Herd Mitran | F,V | His goats won't graze the pass shoulders where the fog sits | B:m4v5 | V-ELDER-M |
| `er_courier` | Ridge-Courier Ilinca | QG | Runs letters over the spine; never reads them — learned from a story about a satchel | B:f1v8 | V-YOUTH-F |
| `er_watcher` | Fog-Line Watcher Petcu | V(travel) | Waystation; logs the fog's height like a tide | SZ:guard | V-SOLDIER |

#### Zone 19 · Lichenreach (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `lr_overseer` | Lichen-Overseer Sanda Veche | QG,V | Farms glow in the dark; pays wages in light | NV | V-MATRON |
| `lr_miner` | Blind Miner Toader | F,QG | Lost his sight years ago; the only worker the deep galleries never bother | SZ:vill | V-ELDER-M |
| `lr_hermit` | The Cave-Strigoi | QG | Ancient, feral-polite; withdrew from Blestem when the walls started listening *to him* | NV | V-DEAD (wet) |
| `lr_factor` | Export-Factor Bran | V | Crates cold light for four capitals; keeps the cracked jars for himself | SZ:merch | V-SLY-M |

#### Zone 20 · The Transcub Vale (5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `tv_ansel` | Brother Ansel | S,QG | Ivy-priest; hears confessions from the walls and answers; sometimes they answer back | CC | V-ELDER-M |
| `tv_penitent` | Penitent-Leader Casian | QG,TI | Leads cultists scourging themselves for reading; "I only wanted to know what it said" | NV(cultist) | V-WHISPER |
| `tv_ivycutter` | Ivy-Cutter Floarea | F,V | Prunes the old god's temples; sells the cuttings as charms she doesn't believe in | B:f2v8 | V-MATRON |
| `tv_altarwitness` | The Kneeler | F | Found at the warm altar, mid-confession, three days now | B:m3v6 | V-WHISPER |
| `tv_ghoulward` | Ossuary-Warden Tache | QG | Keeps temple ghouls penned with bell and habit; the bells are wearing thin | SZ:priest | V-ELDER-M |

#### Zone 21 · The Whisper Passes (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `wp_sergeant` | Listener-Post Sergeant Neca | QG(sinister),TI | Runs the watch-posts; his reports home have begun rhyming | NV | V-SOLDIER→V-WHISPER |
| `wp_guide` | Deaf Guide Mutu | QG | Immune to what the passes say; the only safe escort — talks with his hands, laughs like a landslide | SZ:vill | (sign — text-only, drum FX) |
| `wp_scholar` | Echo-Scholar Livia | QG,TI | Studying why sound carries wrong; her notes have started carrying wrong | SZ:priest | V-YOUTH-F |
| `wp_smuggler` | Pass-Smuggler Codru | V | Moves goods by night whistling arrhythmically — on Mutu's advice | B:m2v6 | V-SLY-M |

### SOUTH — Sangeroasa (Varcolaci, Valrom)

#### Zone 22 · Sangeroasa (CAPITAL — 17)
Forge-city; hundreds of hammers; the Debt Pit. Faction: Varcolaci.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `sg_valrom` | King Valrom, the Forged King | S,QG | One banner, one anvil; does not hear the dagger agree | CC | V-BEAST (regal) |
| `sg_ilion` | Ilion | S,QG | Near-silent executioner-general; cannot stand a loose end — the player becomes one | CC | V-SOLDIER (sparse) |
| `sg_anara` | Anara, the Moon-Whisperer | S,QG | Last fluent reader; useful, never indispensable; hides her hands | CC | V-ELDER-F (young, hushed) |
| `sg_olga` | Hammer-Widow Olga | QG | Swings a dead man's hammer so the debt lands on her, not her sons | CC | V-MATRON |
| `sg_drego` | Pit-Caller Drego | QG,F | Reads the daily dead over the forge-roar; nobody hears; he's never once been wrong | CC | V-ELDER-M |
| `sg_tav` | Soot-Boy Tav | QG | Courier kid; collects "clean" things in a tin — rebellion, in Sangeroasa | CHILD | V-CHILD |
| `sg_forgemaster` | Forge-Master Hrodun | T(smith),V | Teaches the hammer as language; grades your work by ear from three rows away | NW | V-BEAST |
| `sg_pitclerk` | Debt-Ledger Clerk Fiscu | F,TI | Nails the ledger at the Pit rim; stamps "collected" with civic pride | SZ:merch | V-CLERK |
| `sg_foreman` | Killing-Floor Foreman Bruh | QG(grim) | Keeps the floors running; has opinions about which screams mean trouble | NW | V-BEAST |
| `sg_armorer` | Armorer Neaga | V | Sells plate quenched in the channels; won't say what tempers it. Everyone knows | NW | V-GRUFF-M |
| `sg_dredger` | Channel-Dredger Ispas | QG | Clears the blood-channels; whistles to whatever's in them, out of politeness | SZ:vill | V-ELDER-M |
| `sg_huntmistress` | Hunt-Mistress Rada | QG,T(hunter) | Runs the griffin and great-elk hunts; noticed the prey coming home changed, told no one yet | NW | V-SOLDIER |
| `sg_warquarter` | War-Quartermaster Docea | V | Provisions the Bloodroad; counts axes out, coffins back | NW | V-CLERK |
| `sg_penwarden` | Turned-Pen Warden Mihnea | F | Guards the bad-turn pens; brings them water they can't drink; does it anyway | NW | V-GRUFF-M |
| `sg_chamberlain` | Keep-Chamberlain Vulpea | QG(intrigue) | Runs Valrom's keep; has begun keeping a second, honest diary about the king's orders | SZ:noble | V-NOBLE-F |
| `sg_ashpriest` | Ash-Priest Bogdan | F | Blesses the forges; his liturgy has three new verses nobody taught him | SZ:priest | V-WHISPER |
| `sg_stonemouth` | *The Keep Inscription* | S | V-STONE speaking through the dagger's whisper — audible only after zone 6 | (prop) | V-STONE |

#### Zone 23 · The Gift (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `gf_ruja` | Ruja, the Gift-Farmer | S,QG | Feeds her children from soil grown of the dead; talks to the crop — it might hear | CC | V-MATRON |
| `gf_warden` | Field-Warden Colț | F | Varcolac overseer; measures rows by stride and won't step on certain furrows | NW | V-BEAST |
| `gf_tally` | Harvest-Tally Iancu | QG | The yield ledger balances only if he counts the child's shoe; he doesn't. It doesn't | SZ:merch | V-CLERK |
| `gf_crowkeeper` | Crow-Keeper Baba Suru | F,V | Feeds the carrion birds so they'll owe her; sells feathers as "witnesses" | SZ:elder | V-ELDER-F |

#### Zone 24 · The Ashvents (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `av_engineer` | Vent-Tapper Enache | QG | Taps thermal power; his gauges read a heartbeat under the heat (canon: heat hides the signal) | SZ:vill | V-GRUFF-M |
| `av_widow` | Slag-Widow Ioana | QG,TI | Her husband still works vent nine. He was buried in it in spring | B:f1v9 | V-MATRON |
| `av_bathkeeper` | Warm-River Bathkeeper Zamfira | V,F | Cheerful spa amid horror (tonal counter-beat); "the water's *lovely*, dear" | SZ:merch | V-ELDER-F |
| `av_scholar` | Quiet Scholar Emil | F,TI | Chose the one place detection fails to do his reading; that should worry everyone | SZ:priest | V-YOUTH-M |

#### Zone 25 · Basaltfang Range (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `bf_packleader` | Pack-Leader Urlat | QG | Runs the ridge hunts; grades outsiders in prey/not-prey; the player can change categories | NW | V-BEAST |
| `bf_shaman` | Cliff-Shaman Vraja | QG,T(shaman) | Reads the vents' smoke; the smoke has started spelling | NW | V-ELDER-F (growl) |
| `bf_knapper` | Obsidian-Knapper Cremene | V | Knaps black glass blades; keeps the flawed cores "because they tried" | NW | V-GRUFF-M |
| `bf_youngwolf` | Lupei the Half-Turned | QG,TI | Young varcolac whose turns stall; terrified of the Pit's solution for his kind | NW | V-YOUTH-M |

#### Zone 26 · The Bloodroad (5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `br_convoy` | Convoy-Master Hargan | QG,V(travel) | Moves the arsenal north; waystation; hates the road's new habit of being watched | NW | V-BEAST |
| `br_tollcaptain` | Toll-Fort Captain Sila | QG,V | Runs fort three; taxes deserters in information | NW | V-SOLDIER |
| `br_deserter` | Deserter-Leader Ovid | QG,TI | Leads runaways off the war-machine; buries their armbands with full rites | B:m2v7 | V-GRUFF-M |
| `br_dogbreeder` | War-Dog Breeder Cața | V,F | Breeds them loyal; lately whelps face north in their sleep | B:f2v9 | V-MATRON |
| `br_milestone` | *The Bloodroad Milestone* | S | Mile-marker inscription; V-STONE keeps a running tally of what the player has "cost it" | (prop) | V-STONE |

---

## 3. ZONE ROSTERS — CONTINENT 2 (Collector era, 14 zones)

#### Zone 27 · Greyhollow (CAPITAL — 15)
Brackish canal-port; debt as death. Faction: Archive/Morven.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `gh_pell` | Marrow Pell | S,QG,V | Dead broker who keeps trading; taps his own debt-tablet when nervous | CC | V-SLY-M (airless) |
| `gh_morven` | Morven-Handler Sever | QG(intrigue) | Sabira's millennial echo; recruits the player as a listening asset | CC | V-SOLDIER (flattened) |
| `gh_finalclerk` | Clerk-of-Final-Entry Lex | S,F | Stamps the Pit's ledger; the stamped/un-stamped/stamped line is his — he doesn't remember doing it | SZ:merch | V-CLERK |
| `gh_canalboss` | Canal-Boss Murena | QG,V | Runs the waterway gangs; tolls in favors, compounding | SZ:merch | V-SLY-F |
| `gh_gaslighter` | Gaslighter Pip | F | Lights lamps whose light never reaches the ground; keeps doing it; someone has to | CHILD | V-YOUTH-M |
| `gh_advocate` | Debt-Advocate Salcia | QG | The one lawyer who argues the dead's side; win rate: two, in thirty years. Both matter | SZ:noble | V-NOBLE-F |
| `gh_pawnbroker` | Tablet-Pawnbroker Gruia | V | Lends against debt-tablets; never lends against warm ones | SZ:merch | V-SLY-M |
| `gh_counter` | The Counter-Teacher | T(counter) | Teaches specificity-and-stubbornness — the anti-finalizing discipline; homework: notice one true thing daily | SZ:elder | V-ELDER-F |
| `gh_piermistress` | Pier-Mistress Hulda | V(travel) | Grey Ferry's far terminus; logs arrivals from a year that shouldn't connect | SZ:guard | V-SOLDIER |
| `gh_widow` | Finalized-Widow Mare | QG,TI | Her husband was collected in error; the correction queue is 40 years long | B:f2v10 | V-MATRON |
| `gh_runner` | Chalk-Hand Runner Nit | QG | Orphan courier; marks safe doors with chalk handprints — Maren's motif, feral and alive | CHILD | V-CHILD |
| `gh_recordsclerk` | Records-Clerk Ostie | F,TI | Greyhollow Records under Pell; files by smell now, mostly | SZ:vill | V-CLERK |
| `gh_eelhouse` | Eel-House Keeper Buna | V,F | Serves hot eel to the living and warm memories to the rest | SZ:elder | V-ELDER-F |
| `gh_watcher` | The Morven on the Corner | F | Never the same corner; always the same watcher | CC(hooded) | (silent) |
| `gh_tablet` | *The Washed-Up Tablet* | S | Cracked debt-tablet, warm to the touch — V-STONE's Collector-era opening address | (prop) | V-STONE |

#### Zone 28 · The Drowned Quarter (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `dq_ferryman` | Roof-Ferryman Cârmaci | V(travel) | Poles between chimneys; navigates by which windows still have curtains | SZ:vill | V-ELDER-M |
| `dq_resident` | Aunt Vetusta | QG | Won't leave her flooded parlor; the water rose politely and she returns the courtesy | SZ:elder | V-ELDER-F |
| `dq_diver` | Salvage-Diver Corb | QG | Dives for pre-flood valuables; refuses jobs where the finalized are "still at home" | B:m3v7 | V-GRUFF-M |
| `dq_floater` | The Standing Tenant | F | A finalized shape at a second-floor window, curtains parted; files no complaints | NG | V-DEAD |

#### Zone 29 · The Canal Maze (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `cm_pilot` | Maze-Pilot Anghelina | QG,V | Knows the disposal routes; charges by what you're disposing | SZ:merch | V-SLY-F |
| `cm_tender` | Construct-Tender Rugin | F,QG | Oils the collector-constructs; named them all; regulations forbid it (Ilka's echo) | SZ:vill | V-GRUFF-M |
| `cm_sluice` | Sluice-Keeper Doru | QG | Opens the gates on schedule; has started finding the schedule already turned | B:m4v6 | V-ELDER-M |
| `cm_lostclerk` | The Lost Clerk | F,TI | Been delivering one interoffice memo since before the flood; won't surrender it (the Courier's rhyme) | NG | V-CLERK |

#### Zone 30 · The Grey Piers (5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `gp_dockmaster` | Dockmaster Velch | V(travel),QG | C2 ferry terminus; stamps era-crossing manifests without reading the dates. Safer | SZ:guard | V-GRUFF-M |
| `gp_gangboss` | Pier-Boss Şarpe | QG | Runs the dock gangs; pays in tablet-credit, which is the whole problem | SZ:merch | V-SLY-M |
| `gp_ghoulward` | Salt-Ghoul Warden Lipa | F,QG | Keeps the under-pier things fed on schedule so they keep to it | B:f1v10 | V-MATRON |
| `gp_fishwife` | Fishwife Zoica | V,F | Sells the day's catch; some days the catch is best not asked about | SZ:vill | V-ELDER-F |
| `gp_customs` | Customs-Officer Fag | QG,TI | Inspects for contraband inscriptions; wears lead-lined gloves, sweats anyway | SZ:merch | V-CLERK |

#### Zone 31 · The Salt Fens (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `sf_guide` | Fen-Guide Mâl | QG | Reads the brack like scripture; his safe paths shorten yearly | SZ:vill | V-GRUFF-M |
| `sf_brinewitch` | Brine-Witch Sarea | QG,V,T(alchemy) | Collector-era hedge-alchemy; brews from Hessik's lineage, five editions corrupted | SZ:elder | V-ELDER-F |
| `sf_hunter` | Lurker-Hunter Ostaş | F | Hunts fen-lurkers; keeps count by notches; ran out of spear | B:m2v8 | V-SOLDIER |
| `sf_keeper` | Fog-Lamp Keeper Alba | F,QG | Tends the fen light; logs which nights it "goes orange for a bit" | B:f2v11 | V-MATRON |

#### Zone 32 · The Dead Timber (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `dt_logger` | Last-Logger Trunchi | QG | Fells grey wood that never quite dies; apologizes to each stump | B:m4v7 | V-GRUFF-M |
| `dt_ranger` | Grey-Wood Ranger Suru | QG | Patrols for stalkers; navigates by the one tree that still has sap. Guards it fiercely | SZ:guard | V-SOLDIER |
| `dt_cook` | Camp-Cook Plută | V,F | Feeds the ruin-camps; her stew is the zone's only warm thing (Borek's echo, 1000 years on) | SZ:elder | V-ELDER-F |
| `dt_dogboy` | The Feral-Dog Boy | F,TI | Runs with the dog packs; trades bones for buttons; may be the camp's best early-warning | CHILD | V-CHILD |

#### Zone 33 · The Ledger Roads (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `lr2_inspector` | Checkpoint-Inspector Ştampilă | QG(sinister),TI | Audits travelers' debt-standing; finds everyone provisionally overdue | SZ:merch | V-CLERK |
| `lr2_warden` | Road-Warden Hâtru | QG | Keeps bandits off the tolls and tolls off the destitute; the second is the illegal part | SZ:guard | V-SOLDIER |
| `lr2_evader` | Toll-Evader Vulpe | F,QG | Knows every un-inspected mile; owes everyone, files nothing, sleeps fine | B:m3v8 | V-SLY-M |
| `lr2_assessor` | Traveling Assessor Cifra | V | Sells valuations; will appraise anything except a life, which is the job she quit | SZ:noble | V-NOBLE-F |

#### Zone 34 · Morven Reach (5)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `mr_spymistress` | Spymistress Vrabie | QG(intrigue) | Heads the Reach; Sabira's chair, a thousand years worn; still says "poor bastards" — nobody remembers why | CC | V-SOLDIER (f) |
| `mr_safehouse` | Safehouse-Keeper Tocilă | V,QG | Runs the boltholes; rents silence by the night | SZ:vill | V-SLY-M |
| `mr_informant` | The Informant-Shell | F,TI | A finalized asset still reporting on schedule to a handler forty years dead | NG | V-DEAD |
| `mr_doubleagent` | Clerk Fidel | QG,TI | Reports to the Archive and the Reach; keeps a third report he shows no one | SZ:merch | V-CLERK |
| `mr_trainer` | Blank-Face Bătrâna | T(rogue) | Teaches managed blankness; her final exam is grieving without your face knowing | SZ:elder | V-ELDER-F |

#### Zone 35 · The Archive (city zone — 8)
Black Night calcified into a debt-bureaucracy library-city.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `ar_archivist` | The Archivist (retired Morven) | S,QG | Keeper of catalogues nobody reads; weeps at Marta's stick without knowing why | CC | V-CLERK (breaking) |
| `ar_seer` | The Blind Seer | S,QG | Constantine's recurrence; Eyeless Sight; screams the thousand-year alarm at the player's Deadheart-touched gear | CC | V-SEER |
| `ar_stacksclerk` | Contested-Stacks Clerk Firidă | QG | Files the records the Archive lost arguments with; hums to the Definitions to keep them calm | SZ:merch | V-CLERK |
| `ar_overseer` | Construct-Overseer Şurub | F,QG | Directs the filing-constructs; suspects one has started filing *him* | SZ:vill | V-GRUFF-M |
| `ar_vendor` | Catalogue-Vendor Pergament | V | Sells indexes to indexes; the useful one is always out of print | SZ:merch | V-SLY-M |
| `ar_restorer` | Memory-Restorer Cald | T(counter),QG | Restores what the filing removed — one specific warm fact at a time; the Archive tolerates her as "lossy" | SZ:elder | V-ELDER-F |
| `ar_runner` | Stack-Runner Iute | F | Sprints the shelf-canyons; claims the deep stacks rearrange overnight. They do | CHILD | V-YOUTH-M |
| `ar_moasa_echo` | *Moasa's Ledger (shrine)* | F,S | The councilor's private-word ledger, enshrined mis-captioned beside Marta's stick — two mercies, both filed wrong | (prop) | (text) |

#### Zone 36 · Anchorfall (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `af_foundrymaster` | Foundry-Master Nituire | QG,V | Casts debt-anchors worth more than the lives they encode; knows it; casts anyway | SZ:guard | V-GRUFF-M |
| `af_engraver` | Engraver Blândețe | QG,S | Mis-writes one glyph per tablet, deliberately — un-finalizable lives; the zone's small kindness, industrial-grade | SZ:vill | V-MATRON |
| `af_overseer` | Thrall-Overseer Jug | F,TI | Runs the foundry lines; reads the safety litany daily to workers past hearing it | SZ:merch | V-CLERK |
| `af_fence` | Anchor-Fence Cârlig | V | Deals in blank tablets; a blank is a life nobody's defined yet — priceless, terrifying | SZ:merch | V-SLY-F |

#### Zone 37 · The Finalized Fields (4)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `fz_captain` | Grave-Warden Captain Strajă | QG | Patrols the filed rows; his roll-call is Drego's echo — every name, every night, no one listening | SZ:guard | V-SOLDIER |
| `fz_counter` | Row-Counter Tăcere | F | Counts graves to the horizon; the count is never the same twice, and she's stopped reporting that | B:f1v11 | V-CLERK |
| `fz_mourner` | The Un-Filed Mourner | QG,TI | Grieves at a row's end for someone the ledger says never existed; her grief is the discrepancy | B:f2v12 | V-ELDER-F |
| `fz_wreathseller` | Wreath-Vendor Voios | V,F | Grim-cheerful (tonal counter-beat): "everyone's a customer eventually, dear" | SZ:merch | V-ELDER-M |

#### Zone 38 · Coldharbor Deep (dungeon — 3)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `ch_survivor` | Diver Rămas | QG | Sole survivor of the last settlement dive; briefs at the entrance; won't say the harbormaster's name in the dark | B:m2v9 | V-GRUFF-M |
| `ch_harbormaster` | The Drowned Harbormaster | S(boss) | Still settles accounts into the black water; yours is open | NG(boss) | V-CLERK (submerged FX) |
| `ch_instrument` | The Pit's Instrument | F,S | A finalized auditor that walks the under-docks stamping hull-timbers | NG | V-DEAD |

#### Zone 39 · The Orange Fog (3)
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `of_maskseller` | Mask-Seller Ultim | V | Edge-of-zone vendor; sells filters that don't work against comprehension, and says so | SZ:merch | V-SLY-M (muffled) |
| `of_scholar` | Signal-Scholar Ardere | QG,TI | The last person studying the Deadheart wastes on-site; her notes are down to single syllables | SZ:priest | V-WHISPER |
| `of_herald` | The Comprehension-Dead | S | A figure that finished understanding; stands where the fog is thickest, facing the player, patient | NG | V-STONE (single-voice — the closest the villain comes to speaking *as itself* before the Pit) |

#### Zone 40 · The Last Hearth (safe hub — 6)
No hostiles — the point. Maren's echo, catalogued but alive.
| Id | Name | Role | Personality | Sprite | Voice |
|---|---|---|---|---|---|
| `lh_mother` | Hearth-Mother Blajină | QG | Runs the refuge; Maren's millennial inheritor; still won't serve one kind of fish, tradition now, reason lost | CC | V-MATRON |
| `lh_wallkeeper` | Chalk-Wall Keeper Semn | F,QG | Curates the handprint wall — protected *and* catalogued; fights the cataloguers on commas | SZ:elder | V-ELDER-M |
| `lh_soupvendor` | Soup-Vendor Cald-Cald | V | Free bowl for first-timers; Borek's stew, formalized into an institution that somehow stayed warm | SZ:vill | V-GRUFF-M |
| `lh_storyteller` | Storyteller Poveste | F,S | Retells the player's own completed quests, slightly wrong, warmly — the game's epilogue engine | SZ:elder | V-ELDER-F |
| `lh_gentledead` | Old Dascăl | QG,TI | A finalized man the Hearth shelters; remembers one warm thing and guards it like a coal — proof the filed can hold a spark | NG(soft) | V-DEAD (warm — the hardest VO direction in the game) |
| `lh_child` | Scumpa | F | Hearth child; asks departing players to bring back "something that isn't grey" | CHILD | V-CHILD |

---

## 4. Totals & coverage audit
| Region | Zones | NPCs | QG-capable | Vendors | Trainers |
|---|---|---|---|---|---|
| Border (1–6) | 6 | 38 | 22 | 10 | 3 |
| West (7–11) | 5 | 37 | 21 | 12 | 3 |
| North (12–16) | 5 | 32 | 19 | 6 | 1 |
| East (17–21) | 5 | 33 | 20 | 10 | 2 |
| South (22–26) | 5 | 34 | 21 | 8 | 3 |
| Continent 2 (27–40) | 14 | 69 | 39 | 20 | 4 |
| **Total** | **40** | **~243** | **~142** | **~66** | **16** |

~142 quest-capable NPCs × 6–8 quests each comfortably carries the ~1000-quest mandate; capitals hit the 12–20 band, wilderness 3–6, hubs between. Every zone has ≥1 QG; every hub has a vendor; every capital has ≥2 trainers when adjacent-zone trainers are counted (North deliberately trainer-poor — the North doesn't teach, it takes; players train for northern content in Border/West).

## 5. Implementation notes
1. **Registry:** add `npc_data_<zone>.gd` files (or one `NPCRegistry` keyed by zone id) mirroring `NPCData.cast()`'s def shape (`id, display_name, sheet, variant, pos, wander_radius, dialogue, facing`), with two additive keys the current loader can ignore: `role_tags: Array[String]` and `voice: String` (feeds the `_vo_v2` TTS pipeline and future vendor/trainer UI gating).
2. **Ids are load-bearing:** `quest_defs.giver` / `turn_in_npc` / `aftermath` keys all reference these ids — freeze them before quest authoring starts; display names can churn, ids cannot.
3. **Renames first:** apply the three Raven Hollow display renames (§1) before Batch A ships, while saves are cheap.
4. **V-STONE is one cast member:** every inscription-stone prop with dialogue routes through a single `bloodstone` pseudo-NPC id so the villain's WotLK-style through-line (tease → test → tally → confrontation) is authored and paced in one place across all 40 zones.
5. **Aftermath dialogue is the cheapest storytelling we own:** every QG above should get at least one `aftermath` swap per major quest — Torn's hum getting longer, Dorica's bread getting flatter, Drego adding a name the player caused.
6. **Sprite pack gaps** (blockers for East/South/C2 casts): vampire-cultist humanoids (NV), werewolf humanoids (NW), wraith/ghost (NG), child frames (CHILD) — matches the WORLD_PLAN creature-pack gap table; the local ComfyUI sprite pipeline can fill NV/NW clothing variants if pack shopping fails.
