# RAVEN HOLLOW — CRAFTING (The Professions of Draconia)
WoW-Classic **structure** — trainers, 1–300 skill, recipe colors, two-primary law, vendor
recipes you check every visit — carrying **crafts that exist nowhere else**, because they are
derived from Draconia's canon economies, not from Azeroth's.

**Grounded in (read before extending):**
- `scripts/crafting.gd` — shipped Phase C slice: static data+logic class, stations `forge`/`hearth`,
  `RECIPES` (6), recipe scrolls learned by right-click, `_known` set serialized via
  `serialize()/deserialize()`, the **extension-key layering pattern** (core ignores unknown keys).
  Everything below is additive to that file's contracts — the 6 demo recipes keep working unedited.
- `scripts/crafting_ui.gd` — station panel opened via `open_station(id)`; recipe list order =
  `RECIPES` insertion order; the panel this doc extends with a skill bar + ink colors.
- `design/ITEM_PROGRESSION.md` (law) — budget formula BP(ilvl, slot, rarity); craft share of
  upgrades per bracket (15–25%); "craft outputs are uncommon by default, rare with drop-gated
  reagents"; vendor math `value`/4x buy.
- `design/LOOT_TABLES.md` (companion) — §6 zone materials are **this doc's material spine**
  (ids consumed verbatim); "one stack (10) per focused hour" gathering pace; catalyst gold sinks.
- `design/ZONE_QUEST_MATRIX.md` (law) — arm order W→E→S→N→C2, hub/capital placement,
  bracket bands. ⚠ Where LOOT_TABLES §3 bracket numbering disagrees with ZQM arm order
  (it files North at b4/18–28), **ZQM wins**: thread/cold-iron materials are level 42+ materials.
- `design/NPC_CAST.md` — trainer (T) / vendor (V) tags, zone-prefixed id convention; this doc
  feeds it new entries and retags (§7).
- `design/CALENDAR_EVENTS.md` — festival-exclusive recipes (§3, §9).
- `design/STATUS_EFFECTS.md` — consumable outputs reference its effect ids where they exist.
- `_lore_extract.txt` Part VI — the Underlanguage transcription rules that shape §3's safety law.

---

## 0. DESIGN LAWS

1. **WoW's skeleton, Draconia's flesh.** Professions, trainers, skill 1–300, orange→grey
   recipe difficulty, limited-stock vendor recipes, world-drop recipes, specializations.
   None of the professions are alchemy/blacksmithing/tailoring reskins — each one is a canon
   economy turned into a craft (§1).
2. **No profession ever transcribes the Underlanguage.** Recipes are human knowledge in
   human hands — a dead aunt's stitch, a knapper's angle, a broker's cipher. The game's ONE
   craft-adjacent trap (§3.5) exists precisely to teach the difference. Crafting is the
   player's warm counter-culture: everything the Stone wants erased, made and remade nightly.
3. **Recipes are learned from the world.** Trainers teach a thin spine (~30%). The rest is
   found: carved household fragments, NPC masters who teach by making you watch, festival
   exclusives, vendor limited stock, drop scrolls (the shipped `recipe_wolf_fang_dagger`
   pattern). Your recipe book is a travel diary.
4. **Some things only craft when the world cooperates.** The craft-under-condition mechanic
   (§4): at night, in rain, on warm ground, near the dead, in true dark, during a festival,
   at one specific place in the world. Conditions mark signature recipes, never the grind spine.
5. **Compose, don't fork.** Outputs obey ITEM_PROGRESSION budget math; material costs obey
   LOOT_TABLES drop/gather pacing; crafted-gear share per bracket obeys ITEM_PROGRESSION §6;
   coin obeys the LOOT_TABLES gold economy (recipes and catalysts are its designed sinks).
6. **Dread stays ambient.** Every profession has one recipe that is quietly wrong and one
   that is quietly kind. Flavor text is mandatory on materials, recipes, and outputs.

---

## 1. THE PROFESSION ROSTER

**Seven primaries** (a character learns at most **two**) and **three secondaries** (anyone
can learn all three). No separate gathering professions — **each primary carries its own
field-gather verb** (§6.2), unlocked at learn; that is a deliberate break from WoW that
keeps the roster tight and makes every crafter a self-feeder plus a market for drop mats.

| Id | Profession | Kind | Home arm | Canon economy it's built from | Makes |
|---|---|---|---|---|---|
| `bog_iron` | **Bog-Iron Smelting** | primary | Border → South | The Iron Vein's river-fed metal; Goran's "honest work"; Sangeroasa's forge rows | weapons, armor, tools — the mundane anchor craft |
| `blackglass` | **Blackglass Working** | primary | South (roots in Border flint) | Basaltfang obsidian knapping (Cremene); Strigoi glass; Riddler optics | edged weapons, mirrors, lenses — glass that sees and cuts |
| `thread_binding` | **Thread-Binding** | primary | North | The Iele Thread network; Ilka's filament-tending; necromantic filament-work | charms, keepsake trinkets, **stat re-weaves** (our enchanting-shaped hole, filled differently) |
| `ledger_craft` | **Ledger-Scribing** | primary | East → C2 | Blestem's information-as-currency; Cazimir's leverage web; matures into the Collector-era **Debt-Brokering** specialization | consumable intel: maps, dossiers, ciphers, forged papers, writs |
| `folk_warding` | **Folk-Warding** | primary | Border/West | Old Marta's herb-porch; Maren's chalk handprints; cedar shavings on the tomb; salt lines | incurious charms — protection that works BECAUSE it refuses to mean anything |
| `lichen_culture` | **Lichen-Culturing** | primary | East | Lichenreach's light-harvest export (Sanda Veche pays wages in light) | lamps, glow dyes (palette_swap hook), dark-zone gear, cultured cures |
| `hessik_method` | **Hessik-Method Brewing** | primary | game-wide (Border-rooted) | Hessik's *Practical Foundations*; detection colors blue/violet/green/orange; Zorka's argued margins | reading draughts (feeds `scan` objectives), counter-agents, salt-brines |
| `hearthcraft` | **Hearthcraft** | secondary | everywhere | Borek's stew; the Bent Oar pot; Camp-Cook Plută 1,000 years later | food buffs — the cooking analogue, and the game's warmest system |
| `riverline` | **Riverline** | secondary | everywhere | Old Fisherman Cott (taught the trout-thief twice); Fishwife Zoica's don't-ask catch | fishing — red rivers, still markets, canal maze |
| `vigil_dressing` | **Vigil-Dressing** | secondary | everywhere | Sister Casilda's triage; ashen poultices; shroud-linen from one bolt | bandages, poultices, splints — first-aid analogue |

### Profession one-liners (tone anchors for all future recipe authoring)

- **Bog-Iron Smelting** — "River-smelted. Ugly work, honest metal." The only craft the
  Stone cannot subvert, because it never meant anything but nails. Skill ceiling lives in
  Sangeroasa, where the forge that eats teaches best.
- **Blackglass Working** — starts as Border flint-knapping; becomes Strigoi glass at Master
  rank. Blackglass "takes an edge once — it has never needed a second." High-rank optics
  (fog-mirrors, riddler's lenses) blur the line between crafting and detection.
- **Thread-Binding** — the regulated craft. Filament is Iele state property; every legal
  gram comes with paperwork (§7 Black Night vendor), every illegal gram comes with a story.
  Its capstone verb is the **re-weave**: unpick a worn item's suffix statline and bind
  another (ITEM_PROGRESSION §5.2 suffix table) — consumes filament, never creates budget.
- **Ledger-Scribing** — information turned into consumables. A scribed dossier is a buff
  against a named enemy family; a cipher is immunity to being listened to; a forged toll
  receipt is a coach fare you don't pay. At 200 skill it forks: **Rumormonger**
  (Blestem line — better intel consumables) or **Debt-Broker** (C2 line, unlocks only after
  the Grey Ferry crossing — tablet-work, writs, the un-filing of things).
- **Folk-Warding** — the anti-comprehension craft. A chalk handprint means nothing; a salt
  line means nothing; cedar shavings mean nothing. *"It means nothing. That is the whole
  defense."* Mechanically: wards against fear/entrancement/undead aggro; the profession the
  endgame quietly needs (the finale's Moment tokens are folk-warded objects).
- **Lichen-Culturing** — grow light instead of burning it. Beds must be cultured in true
  dark; the brightest strains grow on things best not asked about. Learnt from a **book**,
  not a trainer, at Hand rank (Hessik's primer, sold by a circuit alchemist) — canon: the
  primer is the one honest textbook in Draconia.
- **Hessik-Method Brewing** — not potion-spam: **reading the land**. Its draughts grant the
  scan-sight colors the quest schema already uses (`scan` objective kind, QUEST_ARCHITECTURE
  §6); its counter-agents cure the symptom ladder (STATUS_EFFECTS). The profession's fantasy
  is being the one person in the party who knows which well is clean.

### Class–profession affinities (guidance, never a lock)

Warrior/Paladin → bog_iron; Rogue → ledger_craft + blackglass; Mage → hessik_method +
lichen_culture; Necromancer → thread_binding; Hunter (Rookwarden) → blackglass + riverline;
Druid → folk_warding + hessik_method. Quest-taught masters (§3.3) slant per arm, so the
affinity emerges from where each class hunts, matching ITEM_PROGRESSION §4's philosophy.

---

## 2. SKILL & PROGRESSION (1–300)

### 2.1 Ranks — Draconia names, WoW gates

| Rank | Skill | Where you rank up | The rank-up rite |
|---|---|---|---|
| **Hand** | 1–75 | any Hand trainer (Border/West hubs) | pay a small fee; "show me your hands" |
| **Sworn** | 75–150 | arm-capital trainers | craft one item **in front of** the trainer |
| **Master** | 150–225 | the craft's home capital | a master-task quest (each profession's §9 exemplar chain) |
| **Keeper** | 225–300 | one NPC in the world, each craft | earned, not bought — a Keeper teaches you because of who you've been |

"Keeper" is deliberate — Gravekeeper, Threadwarden, Keeper of the Last Warm Inn. At Keeper
rank a profession stops being a trade and becomes a vigil.

### 2.2 Recipe colors — kept, but ours

WoW's orange/yellow/green/grey survives intact in the math; the UI names them by **ink**,
because a Draconian recipe book is a living document:

| Ink (UI label) | WoW color | Difficulty band (vs `difficulty` D) | Skill-up chance |
|---|---|---|---|
| **wet ink** | orange | skill < D + 20 | 100% |
| **settled** | yellow | D + 20 … D + 39 | 60% |
| **fading** | green | D + 40 … D + 59 | 20% |
| **dry** | grey | ≥ D + 60 | 0% |

Twists that make the climb ours:
- **First craft always skills up** (+1 guaranteed, even fading) — every new recipe is worth
  making once, which keeps found-recipe hunting (§3) mechanically honest.
- **Condition bonus**: crafting a recipe with its §4 condition met adds **+15 percentage
  points** to the skill-up roll (a settled recipe in the rain = 75%). Unconditioned recipes
  crafted at their *flavor-home* station (e.g. bog-iron at the Sangeroasa forge rows) get
  +5pp. The world rewards going out into it.
- **No recipe ever greys for gold**: dry-ink crafts still produce full-value output; only
  skill gain stops (pure WoW rule, stated for clarity).

### 2.3 Pacing (skill ≈ 5 × character level)

| Char level | Expected skill | Material region feeding the climb (ZQM arm order) |
|---|---|---|
| 10 | ~50 | Border b1–b2: wolf_pelt, boar_hide, bone, ember_dust, iron_scrap, bog_iron_lump, marsh_lichen, raven_feather, copper_scale, vein_flint |
| 20 | ~100 | West b3: linen_scrap, grain_sack_seal, river_pearl, cult_wax (+ vendor: chalk_nub, clean_salt) |
| 30 | ~150 | East b5: luminous_lichen, blackvein_ore, bat_membrane, riddle_ink |
| 40 | ~200 | South b6: blackglass_shard, gift_grain, slag_iron, ashvent_salt |
| 50 | ~250 | North (level 42+): thread_filament, cold_iron_shard, kerbstone_chip, snowwolf_undercoat, cedar_shavings |
| 60 | 300 | C2 b7–b8: debt_tablet_fragment, grey_timber, salt_rot_plank, ledger_ink, anchor_lead |

Cost audit rule (from LOOT_TABLES §6): a zone's signature material drops ~1 stack (10) per
focused hour → **an at-bracket settled-ink recipe costs 4–8 signature units**, so crafting an
at-bracket uncommon ≈ one evening of that zone. Wet-ink leveling recipes cost 2–4 commons.
Grinding skill past your bracket is possible (buy materials, fish the vendor rotation) but
priced like Classic: painful, prestigious, optional.

### 2.4 Learning limits & unlearning

- **2 primaries max**; all 3 secondaries free. Learning a third primary requires abandoning
  one — skill is **lost**, recipes are **kept greyed in the book** ("your hands forget;
  the book remembers") — re-learning starts at 1 but known recipes re-activate as ranks pass.
- Secondaries have no rank gates past Sworn — trainers everywhere, 1–300 in one bar.

---

## 3. RECIPE ACQUISITION — the five channels

Authoring quota per profession (target ~40 recipes each at ship; 30 exemplars ship in §9):

| Channel | Share | Pattern |
|---|---|---|
| **1. Trainer spine** | ~30% | Rank trainers sell the boring reliable climb — tools, fillers, the wet-ink ladder. Never signature items. |
| **2. World fragments** | ~30% | Carved/stitched/scratched HUMAN records found in the world: a stitch-sampler in a drowned holding, a knapping diagram scratched on slate, a recipe in a dead cook's hand. Spawn as lootable props + rare container loot. Right-click to learn (extends the shipped `RECIPE_SCROLLS` right-click flow). |
| **3. NPC masters** | ~20% | Quest-taught: the master makes you watch, fetch, or fail first. Borek teaches stew by cooking it and saying nothing. These carry the profession's signature and condition recipes. |
| **4. Festival exclusives** | ~10% | CALENDAR_EVENTS tie-ins (§3.4). Available only while the festival runs; craftable year-round once learned — EXCEPT festival-condition recipes (§4). |
| **5. Vendor rotation + drops** | ~10% | One **limited-stock rotating recipe slot** per capital crafting vendor (§7), restocked on the Grey Fair cycle (first week of each month); plus drop scrolls per LOOT_TABLES `special` rows (the shipped pattern). |

### 3.4 Festival ↔ profession map (feeds CALENDAR_EVENTS implementation)

| Festival | Exclusive recipe(s) | Profession |
|---|---|---|
| The Kept Names (Jan–Feb) | `kept_name_token` (§9 #13) | thread_binding |
| Sowing Day (spring) | seed-blessing ward | folk_warding |
| Ward's Week (May) | `chalk_handprint_ward` **condition window** (§9 #21) | folk_warding |
| The Emberfall Vigil (midsummer) | ember-quench weapon finish (+fire flavor proc) | bog_iron |
| The Proofing (autumn) | `proofing_black_loaf` (§9 #29); Hessik yeast-reading brew | hearthcraft / hessik_method |
| The Gift-Tide | gift_grain feast dishes | hearthcraft |
| The Thinning (Oct) | veil-salt ward line | folk_warding |
| The Grey Fair (monthly) | rotates ONE past-festival recipe + restocks vendor slots | all |

### 3.5 The trap (canon-mandatory, exactly one)

`fragment_that_wants_reading` — an item that looks exactly like a §3-channel-2 recipe
fragment and is not one. Right-clicking it opens the standard learn prompt with one wrong
detail (the "recipe" has no materials list). Confirming teaches **nothing**, consumes the
fragment, sets `stone_saw_recipe_trap`, and the nearest inscription stone thanks you for
your beautiful handwriting. Declining converts it to a turn-in (Zorka pays 5g and says
"good instincts; most people's cost more"). One spawn per arm, never repeated per character.
This is the tutorialized boundary of law §0.2: real recipes name materials, tools, and hands;
the Underlanguage only ever names *you*.

---

## 4. CRAFT-UNDER-CONDITION

Some recipes carry a `condition` dict; the craft button stays visible but disabled with the
condition line lit in the panel ("Craft only in rain") — visible desire is the point.

| `condition.kind` | Meaning | Engine hook |
|---|---|---|
| `night` | after dusk | `day_night.gd` phase |
| `rain` / `snow` | active precipitation | `weather.gd` current weather |
| `warm_ground` | station/prop tagged warm (symptom sites, Ashvents, vent stations) | station def `tags` (§5) |
| `near_the_dead` | within 12 tiles of a grave prop, corpse, or shell NPC | zone prop tags + enemy corpse check |
| `true_dark` | cave zone + no light source active | zone def `is_cave` + player light state |
| `cold` | northern zones / tagged cold stations | zone def region tag |
| `festival:<id>` | calendar event active | CALENDAR_EVENTS registry |
| `at_station:<unique_id>` | one specific world station (§5.2) | station id match |
| `in_capital` | any capital zone ("scribing needs an audience to trade against") | zone def flag |

Design rules:
1. **~1 in 5 recipes conditioned**, never on the wet-ink leveling spine — conditions gate
   signature and capstone recipes only (no grind-blockers).
2. Every conditioned recipe is settled-ink-or-better at its skill point AND carries the
   +15pp condition skill-up bonus — the trip always pays twice.
3. One gold sink release valve: capital vendors sell **`bottled_hour`** (expensive, b6+):
   consumes to satisfy exactly one `night` OR `rain` condition for one craft. Never works
   for `at_station`, `festival`, or `true_dark` — some things you cannot buy.

---

## 5. STATIONS

### 5.1 Common stations (extend the shipped `forge` / `hearth`)

Station defs live where they do today (`town_builder.gd` / zone builders return
`"stations": [{id, pos, radius}]`); add optional `tags: Array[String]` (e.g.
`["warm_ground"]`) which `Crafting.condition_met` consults.

| Station id | Professions served | Where placed |
|---|---|---|
| `forge` *(shipped)* | bog_iron | every hub with a smith; capitals |
| `hearth` *(shipped)* | hearthcraft, folk_warding (wax/cedar work) | inns, camps, orphanage |
| `knapping_bench` | blackglass | Border camps (flint), Basaltfang, Sangeroasa |
| `binding_post` | thread_binding | Black Night precincts, Gravemark lodge; always `near_the_dead` by placement |
| `scribe_desk` | ledger_craft | capitals, Bent Oar board, Morven Reach |
| `still` | hessik_method | Zorka's barge, Copper Wells camp, Ashvents stilt-station, Salt Fens |
| `culture_trough` | lichen_culture | Lichenreach galleries (true_dark by placement), capital cellars |
| `tablet_press` | ledger_craft (Debt-Broker spec only) | C2 only: Greyhollow, Anchorfall |
| — (no station) | riverline (water edge), vigil_dressing (anywhere) | secondaries stay station-free |

### 5.2 Unique world stations (destination crafting — each is a pilgrimage)

| Unique id | Place | What only crafts here |
|---|---|---|
| `blood_channel_quench` | Sangeroasa killing-floor channels | §9 #4 `emberfold_edge` and all Edgesmith capstones |
| `cold_hollow_still` | the Ashvents' one cold hollow | §9 #27 `orange_reading_still` (the stone kept it cold so you'd find it; brewing here is spitting in its eye) |
| `last_hearth_wall` | Last Hearth chalk-handprint wall | §9 #21 `chalk_handprint_ward` (alt to Ward's Week) |
| `martas_porch` | Old Marta's cottage porch, Vetka | Folk-Warding Keeper rite + one recipe; "the village has no board — Marta IS the board" |
| `deep_bed_gallery` | Lichenreach brightest bed (grows in the outline of a man) | `coldlight_crown` (§9 #24); harvesting here has a quest cost |

---

## 6. MATERIALS

### 6.1 Sources (all LOOT_TABLES-first)

- **Kill drops** — LOOT_TABLES family tables (`materials` rows) are unchanged and remain the
  main faucet; every §9 cost below is payable from shipped/planned table ids.
- **Field-gather nodes** (§6.2) — the second faucet, profession-gated.
- **Vendors** — processed/civilized mats only (§7): clean_salt, chalk_nub, oak_gall_ink,
  cedar_shavings, culture broth, quench-oil, plus b6+ **catalysts** (LOOT_TABLES §5 sink).
- **Fishing** — riverline yields cooking fish + occasional dredge (river_pearl,
  waterlogged junk, one soggy fragment channel).

### 6.2 Field-gather verbs (one per primary; sparse nodes, rare-spawn-style respawn timers)

| Profession | Verb | Node | Yields |
|---|---|---|---|
| bog_iron | **pan the shallows** | river shallows glint | bog_iron_lump, iron_scrap, rare river_pearl |
| blackglass | **knap the seam** | flint/vent-core seam | vein_flint *(NEW id)*, blackglass_shard (b6 zones) |
| thread_binding | **wind a loose end** | frayed filament wisp (North only) | thread_filament — LEGAL only at tagged wisps; winding from the drawn is an illicit quest verb, not a node |
| ledger_craft | **copy the board** | notice boards, toll ledgers, milestones (never inscription stones — the UI refuses) | riddle_ink components, grain_sack_seal, toll receipts |
| folk_warding | **gather the hedge** | herb/cedar clusters | marsh_lichen, raven_feather, cedar_shavings, cult_wax |
| lichen_culture | **scrape the bed** | glow-bed patch | marsh_lichen (Border strain), luminous_lichen (East) |
| hessik_method | **draw a sample** | wells, vents, dead-yeast pantries | copper_scale, ashvent_salt, well readings (quest channel) |

**New material ids introduced by this doc** (Crafting.MATERIALS shape, flavor mandatory):
`vein_flint` ("River flint. It remembers being an edge."), `cedar_shavings` ("His grandmother
did it too."), `chalk_nub` ("Worn to a thumbnail. Forty walls ago."), `clean_salt` ("The one
thing the Yeastless fear."), `oak_gall_ink` ("Honest ink. It only says what you wrote."),
`bottled_hour` (§4 valve), `redfin_gudgeon` / `pale_eel` / `greywater_catch` (riverline).
Everything else in §9 already exists in crafting.gd or LOOT_TABLES §6.

---

## 7. TRAINERS & CRAFTING VENDORS (feeds NPC_CAST)

### 7.1 Trainer matrix (existing NPC_CAST ids; retags noted; ★ = new NPC)

| Profession | Hand (1–75) | Sworn (75–150) | Master (150–225) | Keeper (225–300) |
|---|---|---|---|---|
| bog_iron | `blacksmith` Goran (RH — retag T(weapons)→T(bog_iron)) | Goran | `sg_forgemaster` Hrodun ("grades your work by ear from three rows away") | Hrodun; spec rite: Edgesmith (Hrodun) / Wardsmith (`sg_armorer` Neaga) |
| blackglass | `cw_tinker` Maree ("flint and lead before glass, dear") | `bf_knapper` Cremene | Cremene | Cremene — Keeper rite: he shows you his flawed cores, "because they tried" |
| thread_binding | `bn_threadtender` Neluș (retag T(detection)→T(thread_binding); detection folds into hessik_method) | Neluș | `bn_ilka` Threadwarden Ilka | Ilka — Keeper rite is illicit and she names it under her breath |
| ledger_craft | `aw_lera` Archivist-Postulant Lera (warm variant — "so someone remembers") | `bl_notary` Zaraza | Zaraza; spec fork at 200: Rumormonger (`bl_handler` Iepure) / Debt-Broker (`gh_pell` Marrow Pell, C2 gate) | Pell (Debt-Broker) / Zaraza (Rumormonger) |
| folk_warding | `vk_marta` Old Marta (retag T(herbalism)→T(folk_warding)) | Marta (at `martas_porch`) | `tv_ivycutter` Floarea ("charms she doesn't believe in" — she teaches better than believers) | `lh_wallkeeper` Semn, Last Hearth |
| lichen_culture | **book-taught**: *Practical Foundations, ch. 9* — sold by the Copper Wells circuit alchemist ★`cw_circuit` | `lr_overseer` Sanda Veche | Sanda Veche | `lr_miner` Blind Miner Toader — the deep beds never bother him; Keeper rite in true dark |
| hessik_method | `iv_zorka` Zorka the Stillwife | Zorka | ★`av_hessikist` Hessik-Method Alchemist Irod (the ZQM Ashvents giver, now named) | `sf_brinewitch` Sarea (C2 — "five editions corrupted"; she teaches from the first) |
| hearthcraft | `innkeeper` Magda (RH) / `iv_rodica` | any inn V-MATRON | `dt_cook` Plută | `lh_soupvendor` Cald-Cald |
| riverline | `rf_cott` Old Fisherman Cott | Cott | `gp_fishwife` Zoica | Cott ("the second time on purpose" — his Keeper rite is teaching someone else) |
| vigil_dressing | `aw_healer` Sister Casilda | Casilda | `bl_chirurgeon` Alba | ★`gt_layer` Layer-Out Vetra, Gravemark (dresses the dead; teaches dressing the living as the easier case) |

### 7.2 Crafting vendors — one per capital + the two safe hubs

Each stocks: (a) profession materials of its region, (b) tools/reagents (clean_salt,
chalk_nub, oak_gall_ink, cedar_shavings, culture broth, quench-oil), (c) **one rotating
limited-stock recipe** (restock: Grey Fair week; quantity 1 — first come, WoW-classic), and
(d) its **catalyst** gold sink (b6+ only). Buy prices per ITEM_PROGRESSION §7 (value × 4).

| Hub | Vendor (id) | Personality / stock slant | Catalyst |
|---|---|---|---|
| Bent Oar (Border) | `iv_zorka` + `iv_vadim` (existing) | reagents, hides; Zorka's rotation slot sells argued-margin Hessik recipes | — |
| Angel Wings | ★`aw_chandler` **Chandleress Uca** — wax, chalk, salt, lead sheeting; "sells candles by burn-hour, honest to the minute" | folk_warding / vigil_dressing | `ward_wax` |
| Blestem | `bl_vera` Vera Cold-Hands (existing) — riddle_ink, paper, ciphers; her rotation slot pays partly in kindness (a warm story knocks 20% off) | ledger_craft / lichen_culture | `gall_fixative` |
| Black Night | ★`bn_requisition` **Filament-Requisition Clerk Onu** — sells thread_filament ALLOWANCE with paperwork ("three per month; sign here; do not tell me what for") + `bn_cedarseller` Fira (cedar_shavings) | thread_binding / folk_warding | `sanctioned_spool` |
| Sangeroasa | `sg_armorer` Neaga + `bf_knapper` Cremene (existing) — slag, quench-oil, vent cores | bog_iron / blackglass | `channel_quench_oil` |
| Greyhollow | `gh_pawnbroker` Gruia (existing) — tablet fragments, ledger_ink, blank forms ("never lends against warm ones") | ledger_craft (Debt-Broker) | `press_lead` |
| Last Hearth | `lh_soupvendor` Cald-Cald (existing) — hearthcraft staples; the rotation slot here is always a WARM recipe, free, one per character | hearthcraft / folk_warding | — |

NPC_CAST feed summary — **4 new NPCs**: `aw_chandler` (Uca, V, SZ:merch, V-MATRON),
`bn_requisition` (Onu, V, SZ:noble, V-CLERK), `av_hessikist` (Irod, T+V, SZ:priest,
V-YOUTH-M), `gt_layer` (Vetra, T, SZ:elder, V-ELDER-F), plus ★`cw_circuit` (the already-flagged
ZQM circuit alchemist, now carrying the lichen primer). **3 retags**: Goran, Neluș, Marta
(table above). All other rows reuse existing cast — the roster was built for this.

---

## 8. DATA SCHEMAS (exact GDScript — additive to `crafting.gd`)

All additions follow the shipped extension-key law: old callers ignore new keys; the 6 demo
recipes gain annotations, zero behavior changes until the UI reads them.

```gdscript
# ---------------------------------------------------------------- professions
const MAX_PRIMARIES: int = 2

const PROFESSIONS := {
	"bog_iron": {
		"id": "bog_iron", "name": "Bog-Iron Smelting", "kind": "primary",
		"stations": ["forge"],
		"field_gather": "pan_shallows",
		"ranks": {1: "Hand", 75: "Sworn", 150: "Master", 225: "Keeper"},
		"trainers": {"Hand": "blacksmith", "Sworn": "blacksmith",
			"Master": "sg_forgemaster", "Keeper": "sg_forgemaster"},
		"spec": {"at": 200, "options": ["edgesmith", "wardsmith"]},
		"flavor": "Honest metal asks no questions.",
	},
	# ... thread_binding, ledger_craft (spec: rumormonger/debt_broker, the
	# latter gated by flag "act6_crossed"), folk_warding, blackglass,
	# lichen_culture (Hand rank book-taught: learned from item
	# "practical_foundations_ch9", not a trainer), hessik_method,
	# hearthcraft/riverline/vigil_dressing {kind:"secondary", spec:null}.
}

# ------------------------------------------------------------ player state
static var _prof_skill: Dictionary = {}    # prof_id -> int (absent = unlearned)
static var _prof_spec: Dictionary = {}     # prof_id -> spec id ("" until chosen)

static func skill_of(prof: String) -> int: ...
static func learn_profession(prof: String) -> bool:   # enforces MAX_PRIMARIES
static func abandon_profession(prof: String) -> void: # skill lost, book kept (greyed)

# serialize()/deserialize() gain: {"known": [...], "skill": _prof_skill,
#   "spec": _prof_spec}  — reset() clears all three (New Game).

# ------------------------------------------------------------ recipe def v2
# EXISTING keys unchanged: id, name, station, output, cost, start_known, scroll.
# NEW keys (all optional; absent = demo-legacy defaults shown):
#   "profession": String   # default: "bog_iron" if station=="forge",
#                          #          "hearthcraft" if station=="hearth"
#   "skill_req":  int      # default 1 — book shows recipe greyed until met
#   "difficulty": int      # default = skill_req — wet-ink point (§2.2 bands)
#   "count":      int      # default 1 — output stack size
#   "condition":  Dictionary  # default {} — see condition_met() kinds (§4)
#   "spec_req":   String   # default "" — e.g. "debt_broker"
#   "source":     Dictionary  # authoring metadata, never read at runtime:
#                          # {kind:"trainer"|"fragment"|"master"|"festival"
#                          #  |"vendor"|"drop", where:String}

# ---------------------------------------------------------- condition check
static func condition_met(recipe: Dictionary, station: Dictionary,
		zone: Dictionary) -> bool:
	var c: Dictionary = recipe.get("condition", {})
	if c.is_empty():
		return true
	match str(c.get("kind", "")):
		"night":       return DayNight.is_night()
		"rain", "snow": return Weather.current == c["kind"]
		"warm_ground": return "warm_ground" in station.get("tags", [])
		"near_the_dead": return _dead_within(12.0)   # grave props / corpses / shells
		"true_dark":   return zone.get("is_cave", false) and not _player_has_light()
		"cold":        return zone.get("region", "") in ["north", "c2"] \
			or "cold" in station.get("tags", [])
		"at_station":  return str(station.get("id", "")) == str(c.get("station", ""))
		"in_capital":  return zone.get("is_capital", false)
		_:
			var fest: String = str(c.get("kind", "")).trim_prefix("festival:")
			return CalendarEvents.is_active(fest)
	# bottled_hour (§4): use_consumable path pre-arms a one-craft override
	# for kinds "night"/"rain" only — stored as a one-shot static flag.

# ------------------------------------------------------------- craft & skill
# can_craft() gains three checks: profession learned, skill_of >= skill_req,
# spec_req empty-or-matched. condition_met() is checked by craft() (NOT by
# can_craft — the UI wants "craftable but not here/now" as a distinct state).
# craft() success then rolls the skill-up:

static func _roll_skill_up(recipe: Dictionary, condition_was_met: bool,
		first_craft: bool) -> void:
	var prof: String = _prof_of(recipe)
	var d: int = int(recipe.get("difficulty", recipe.get("skill_req", 1)))
	var s: int = skill_of(prof)
	var pct: float
	if s < d + 20:    pct = 1.00     # wet ink
	elif s < d + 40:  pct = 0.60     # settled
	elif s < d + 60:  pct = 0.20     # fading
	else:             pct = 0.00     # dry
	if first_craft:
		pct = 1.0
	elif condition_was_met and pct > 0.0:
		pct = minf(1.0, pct + 0.15)
	if pct > 0.0 and randf() < pct:
		_prof_skill[prof] = mini(300, s + 1)
		# rank cap: skill stalls at 75/150/225 until the rank rite is done
```

**Demo retrofit** (annotations only, zero behavior change): iron_sword/boarhide_jerkin/
bone_ring/wolf_fang_dagger → `profession:"bog_iron"`, skill_req 1/5/1/25; healing_draught →
`hessik_method` skill_req 1; hunters_stew → `hearthcraft` skill_req 1. `start_known` recipes
seed with the profession auto-learned at skill 1 the first time the player opens that
station in the demo (grandfather clause — post-demo characters learn from Goran/Magda).

---

## 9. THE 31 EXEMPLAR RECIPES (ship-ready, schema v2)

Output stat lines are audited against ITEM_PROGRESSION §2 (BP within ±1); consumable effects
reference STATUS_EFFECTS ids where they exist. Icons follow repo law `icon id == item id`
(Shikashi cells, PIL-verified, per the crafting.gd promotion pattern). Costs use LOOT_TABLES
§6 ids + crafting.gd staples + §6.2 new ids only.

```gdscript
	# ===================== BOG-IRON SMELTING (5) =====================
	"bogiron_pot_hook": {
		"id": "bogiron_pot_hook", "name": "Bog-Iron Pot Hook", "station": "forge",
		"profession": "bog_iron", "skill_req": 1, "difficulty": 10,
		"output": "bogiron_pot_hook", "cost": {"bog_iron_lump": 2},
		"source": {"kind": "trainer", "where": "blacksmith"},
		# output: slot none, common, value 2 — vendor fodder + hearth-station
		# upgrade token (an inn with your hook cooks your food 10% cheaper).
		# flavor: "Every kitchen on the river hangs its pot on one of these."
	},
	"riverset_blade": {
		"id": "riverset_blade", "name": "Riverset Blade", "station": "forge",
		"profession": "bog_iron", "skill_req": 40, "difficulty": 40,
		"output": "riverset_blade", "cost": {"bog_iron_lump": 4, "bone": 2},
		"source": {"kind": "fragment", "where": "Drowned Holding smithy slate (Iron Vein)"},
		# output: main_hand uncommon i9 — dmg 8, hp 5 (BP 9.6✓)
		# flavor: "Quenched in the river it came from. It keeps the color."
	},
	"wardsmiths_riverplate": {
		"id": "wardsmiths_riverplate", "name": "Wardsmith's Riverplate", "station": "forge",
		"profession": "bog_iron", "skill_req": 105, "difficulty": 110,
		"output": "wardsmiths_riverplate",
		"cost": {"bog_iron_lump": 6, "iron_scrap": 4, "linen_scrap": 4},
		"source": {"kind": "trainer", "where": "blacksmith (Sworn rank reward)"},
		# output: chest uncommon i14 — armor 5, hp 20 (BP 12.3, spend 9 + suffix
		# room; of-the-Vigil line). flavor: "Goran's pattern, one size too honest."
	},
	"emberfold_edge": {
		"id": "emberfold_edge", "name": "Emberfold Edge", "station": "forge",
		"profession": "bog_iron", "skill_req": 180, "difficulty": 185,
		"spec_req": "edgesmith",
		"condition": {"kind": "at_station", "station": "blood_channel_quench"},
		"output": "emberfold_edge",
		"cost": {"slag_iron": 6, "ember_dust": 8, "blackglass_shard": 1,
			"channel_quench_oil": 1},
		"source": {"kind": "master", "where": "sg_forgemaster — 'The Hammer as Language'"},
		# output: main_hand rare i36 — dmg 29, crit 4 (BP 35.8✓). The channels
		# temper it. Everyone knows with what.
		# flavor: "Folded nine times. The ninth fold is the one you don't ask about."
	},
	"keepers_vigil_plate": {
		"id": "keepers_vigil_plate", "name": "Keeper's Vigil Plate", "station": "forge",
		"profession": "bog_iron", "skill_req": 255, "difficulty": 262,
		"spec_req": "wardsmith", "condition": {"kind": "cold"},
		"output": "keepers_vigil_plate",
		"cost": {"cold_iron_shard": 8, "anchor_lead": 2, "thread_filament": 2},
		"source": {"kind": "vendor", "where": "bn_requisition rotation (Grey Fair restock)"},
		# output: chest rare i52 — armor 14, hp 70 (BP 47.6✓). Cold-forged: the
		# metal never rings. flavor: "Armor for standing very still, very long."
	},

	# ===================== BLACKGLASS WORKING (4) =====================
	"veinflint_striker": {
		"id": "veinflint_striker", "name": "Vein-Flint Striker", "station": "knapping_bench",
		"profession": "blackglass", "skill_req": 5, "difficulty": 12,
		"output": "veinflint_striker", "cost": {"vein_flint": 2, "bone": 1},
		"source": {"kind": "trainer", "where": "cw_tinker"},
		# output: trinket common i4 — hp 6 (BP 3.1✓) + utility: lights campfires
		# instantly. flavor: "Flint and iron agree about exactly one thing."
	},
	"blackglass_razor": {
		"id": "blackglass_razor", "name": "Blackglass Razor", "station": "knapping_bench",
		"profession": "blackglass", "skill_req": 160, "difficulty": 165,
		"output": "blackglass_razor",
		"cost": {"blackglass_shard": 4, "wolf_pelt": 2, "slag_iron": 1},
		"source": {"kind": "master", "where": "bf_knapper — bring him a flawed core intact"},
		# output: main_hand rare i34 — dmg 25, speed 3 (BP 34.4✓); Rogue line.
		# flavor: "It took an edge once. It has never needed a second."
	},
	"fogmirror": {
		"id": "fogmirror", "name": "Fogmirror", "station": "knapping_bench",
		"profession": "blackglass", "skill_req": 200, "difficulty": 205,
		"condition": {"kind": "true_dark"},
		"output": "fogmirror",
		"cost": {"blackglass_shard": 6, "luminous_lichen": 3, "anchor_lead": 1},
		"source": {"kind": "fragment", "where": "Lichenreach deep-gallery surveyor kit"},
		# output: trinket rare i40 — hp 30, crit 4 (BP 24.3, spend 10 + on-use:
		# points toward the zone's live rare spawn, 30 min cd).
		# flavor: "It shows the fog what the fog is hiding. They argue. You listen."
	},
	"riddlers_lens": {
		"id": "riddlers_lens", "name": "Riddler's Lens", "station": "knapping_bench",
		"profession": "blackglass", "skill_req": 240, "difficulty": 248,
		"condition": {"kind": "night"},
		"output": "riddlers_lens",
		"cost": {"blackglass_shard": 8, "riddle_ink": 2, "river_pearl": 1},
		"source": {"kind": "festival", "where": "Grey Fair rotation, one month a year"},
		# output: off_hand epic i50 — mana 60, crit 5, mana_regen 1 (BP 39.9✓);
		# Mage/Necro line. flavor: "Ground so fine it corrects for the truth."
	},

	# ===================== THREAD-BINDING (4) =====================
	"soothing_knot": {
		"id": "soothing_knot", "name": "Soothing Knot", "station": "binding_post",
		"profession": "thread_binding", "skill_req": 1, "difficulty": 10, "count": 3,
		"output": "soothing_knot", "cost": {"thread_filament": 1, "linen_scrap": 1},
		"source": {"kind": "trainer", "where": "bn_threadtender"},
		# output: consumable — clears fear/entrance stacks (STATUS_EFFECTS
		# "listening" ladder), 10 s calm aura on shells.
		# flavor: "Ilka ties one for every shell she names. Regulations forbid both."
	},
	"bound_keepsake": {
		"id": "bound_keepsake", "name": "Bound Keepsake", "station": "binding_post",
		"profession": "thread_binding", "skill_req": 130, "difficulty": 135,
		"condition": {"kind": "near_the_dead"},
		"output": "bound_keepsake",
		"cost": {"thread_filament": 2, "raven_feather": 2, "bone": 1},
		"source": {"kind": "fragment", "where": "Gravemark kerb-row lodge (Vosk's shelf)"},
		# output: trinket uncommon i26 — hp 25, mana 20 (BP 11.1✓).
		# flavor: "Something of theirs, something of yours, and a knot that won't say which."
	},
	"filament_reweave": {
		"id": "filament_reweave", "name": "Filament Re-Weave", "station": "binding_post",
		"profession": "thread_binding", "skill_req": 190, "difficulty": 195,
		"condition": {"kind": "near_the_dead"},
		"output": "filament_reweave",
		"cost": {"thread_filament": 4, "cold_iron_shard": 1, "sanctioned_spool": 1},
		"source": {"kind": "master", "where": "bn_ilka — after 'The Flicker of Will'"},
		# output: consumable APPLIED TO GEAR — unpicks an uncommon/rare item's
		# suffix statline and re-binds another §5.2 suffix (player picks; budget
		# unchanged — re-spends, never adds). The enchanting-shaped hole, filled
		# our way: you don't add power, you re-tell what the item is for.
		# flavor: "Everything worn is woven. Everything woven can be told again."
	},
	"kept_name_token": {
		"id": "kept_name_token", "name": "Kept-Name Token", "station": "binding_post",
		"profession": "thread_binding", "skill_req": 90, "difficulty": 95,
		"condition": {"kind": "festival:kept_names"},
		"output": "kept_name_token",
		"cost": {"thread_filament": 1, "cedar_shavings": 1, "linen_scrap": 1},
		"source": {"kind": "festival", "where": "The Kept Names (Jan 23 – Feb 10)"},
		# output: trinket uncommon i18 — hp 20 (BP 7.9, spend 4 + effect: when
		# you drop below 20% hp, a kept name is spoken; 6 s +2 hp/s; 3 min cd).
		# flavor: "You get to choose whose. Choose out loud."
	},

	# ===================== LEDGER-SCRIBING (4) =====================
	"marked_map_border": {
		"id": "marked_map_border", "name": "Marked Map: the Border", "station": "scribe_desk",
		"profession": "ledger_craft", "skill_req": 20, "difficulty": 25, "count": 2,
		"output": "marked_map_border", "cost": {"linen_scrap": 2, "oak_gall_ink": 1},
		"source": {"kind": "trainer", "where": "aw_lera"},
		# output: consumable — reveals the current Border zone's gather nodes +
		# waystations on the minimap for 10 min.
		# flavor: "Vlaicu draws one road wrong on purpose. This one is all yours."
	},
	"assumed_audience_cipher": {
		"id": "assumed_audience_cipher", "name": "Assumed-Audience Cipher",
		"station": "scribe_desk",
		"profession": "ledger_craft", "skill_req": 150, "difficulty": 155, "count": 2,
		"output": "assumed_audience_cipher",
		"cost": {"riddle_ink": 2, "bat_membrane": 1},
		"source": {"kind": "vendor", "where": "bl_vera rotation"},
		# output: consumable — 10 min immunity to 'listened' tagging (Whisper
		# Passes / Blestem mechanic; STATUS_EFFECTS); your leverage flags stop
		# accruing while active. flavor: "Write as if they're reading. They are."
	},
	"dossier_of_habits": {
		"id": "dossier_of_habits", "name": "Dossier of Habits", "station": "scribe_desk",
		"profession": "ledger_craft", "skill_req": 175, "difficulty": 180,
		"spec_req": "rumormonger", "condition": {"kind": "in_capital"},
		"output": "dossier_of_habits",
		"cost": {"riddle_ink": 3, "grain_sack_seal": 1},
		"source": {"kind": "master", "where": "Cazimir web chain — he shows you the format"},
		# output: consumable — pick an enemy FAMILY (LOOT_TABLES families):
		# +10% crit vs it for 30 min. "You know when he drops his guard."
		# flavor: "I do not collect assumptions. — the epigraph is printed on every copy."
	},
	"writ_of_unfiling": {
		"id": "writ_of_unfiling", "name": "Writ of Un-Filing", "station": "tablet_press",
		"profession": "ledger_craft", "skill_req": 260, "difficulty": 270,
		"spec_req": "debt_broker",
		"output": "writ_of_unfiling",
		"cost": {"debt_tablet_fragment": 6, "ledger_ink": 2, "anchor_lead": 1,
			"press_lead": 1},
		"source": {"kind": "master", "where": "gh_pell — 'A Discrepancy of One's Own'"},
		# output: consumable — clears the bind on ONE bind-on-pickup item
		# (LOOT_TABLES §7), once. Engraver Blândețe's trick, licensed: one glyph
		# mis-written, one life un-finalizable, one item un-filed.
		# flavor: "Stamped, un-stamped. There is no third impression on this one."
	},

	# ===================== FOLK-WARDING (4) =====================
	"salt_line_pouch": {
		"id": "salt_line_pouch", "name": "Salt-Line Pouch", "station": "hearth",
		"profession": "folk_warding", "skill_req": 1, "difficulty": 10, "count": 3,
		"output": "salt_line_pouch", "cost": {"clean_salt": 2, "linen_scrap": 1},
		"source": {"kind": "trainer", "where": "vk_marta"},
		# output: consumable — pours a 6 s ground line: undead/shell families
		# hesitate at it (3 s soft taunt-drop). It shouldn't work. It works.
		# flavor: "Salt keeps nothing out. It reminds them there's a door."
	},
	"incurious_charm": {
		"id": "incurious_charm", "name": "Incurious Charm", "station": "hearth",
		"profession": "folk_warding", "skill_req": 75, "difficulty": 80,
		"output": "incurious_charm",
		"cost": {"cedar_shavings": 2, "raven_feather": 1, "chalk_nub": 1},
		"source": {"kind": "master", "where": "vk_marta Sworn rite, at martas_porch"},
		# output: trinket uncommon i16 — hp 15 (BP 7.2, spend 3 + effect: halves
		# 'listening' buildup near inscriptions — STATUS_EFFECTS entrancement).
		# flavor: "It means nothing. That is the whole defense."
	},
	"hearth_hex_sign": {
		"id": "hearth_hex_sign", "name": "Hearth Hex-Sign", "station": "hearth",
		"profession": "folk_warding", "skill_req": 140, "difficulty": 145,
		"condition": {"kind": "rain"},
		"output": "hearth_hex_sign",
		"cost": {"cedar_shavings": 3, "cult_wax": 2, "chalk_nub": 1},
		"source": {"kind": "fragment", "where": "Grey Marches cult deserter's kit"},
		# output: consumable — placed at a campfire/hearth: 30 min zone-tick
		# +1 hp/s rest aura for the player (stacks with food).
		# flavor: "Paint it slow, in rain, so the wet can teach it patience."
	},
	"chalk_handprint_ward": {
		"id": "chalk_handprint_ward", "name": "Chalk Handprint Ward", "station": "hearth",
		"profession": "folk_warding", "skill_req": 220, "difficulty": 230,
		"condition": {"kind": "at_station", "station": "last_hearth_wall"},
		# ALT window: festival:wards_week at any hearth — implement as either/or
		# in condition_met (authoring note; the only dual-condition recipe).
		"output": "chalk_handprint_ward",
		"cost": {"chalk_nub": 3, "cedar_shavings": 2, "gift_grain": 1},
		"source": {"kind": "master", "where": "lh_wallkeeper Semn — Keeper rite"},
		# output: trinket rare i50 — hp 55 (BP 27.9, spend 11 + effect: the
		# first killing blow each 5 min leaves you at 1 hp instead. Once.
		# Someone's hand on the wall says you were here.)
		# flavor: "One of these prints is warm. Today it's yours."
	},

	# ===================== LICHEN-CULTURING (3) =====================
	"marshlight_jar": {
		"id": "marshlight_jar", "name": "Marshlight Jar", "station": "culture_trough",
		"profession": "lichen_culture", "skill_req": 25, "difficulty": 30, "count": 2,
		"output": "marshlight_jar", "cost": {"marsh_lichen": 3},
		"source": {"kind": "trainer", "where": "book: Practical Foundations ch.9 (cw_circuit)"},
		# output: consumable — hands-free light source, 10 min (no off_hand cost;
		# does NOT break true_dark conditions — cultured light is dark's kin).
		# flavor: "Reads by it fine. The dark doesn't seem to mind. That's new."
	},
	"bedgrown_dye_of_the_deep": {
		"id": "bedgrown_dye_of_the_deep", "name": "Bed-Grown Dye of the Deep",
		"station": "culture_trough",
		"profession": "lichen_culture", "skill_req": 170, "difficulty": 175,
		"condition": {"kind": "true_dark"},
		"output": "bedgrown_dye_of_the_deep", "cost": {"luminous_lichen": 5},
		"source": {"kind": "vendor", "where": "lr_overseer rotation"},
		# output: consumable — cosmetic gear dye (palette_swap.gdshader hook):
		# a faint teal glow-edge on one equipped item. Pure flex; sells forever.
		# flavor: "Grown, not mixed. The color is alive and knows it's worn."
	},
	"coldlight_crown": {
		"id": "coldlight_crown", "name": "Coldlight Crown", "station": "culture_trough",
		"profession": "lichen_culture", "skill_req": 210, "difficulty": 215,
		"condition": {"kind": "at_station", "station": "deep_bed_gallery"},
		"output": "coldlight_crown",
		"cost": {"luminous_lichen": 8, "blackvein_ore": 2},
		"source": {"kind": "fragment", "where": "lr_miner Toader — he describes it; you write it"},
		# output: head rare i42 — mana 55, hp 20, mana_regen 1 (BP 30.5✓);
		# Mage/Necro. Grown on the bed shaped like a man. He doesn't need it.
		# flavor: "It sheds light with no heat and asks a small rent of memory."
	},

	# ===================== HESSIK-METHOD BREWING (3) =====================
	"reading_draught_blue": {
		"id": "reading_draught_blue", "name": "Reading Draught (Blue)", "station": "still",
		"profession": "hessik_method", "skill_req": 15, "difficulty": 20, "count": 2,
		"output": "reading_draught_blue", "cost": {"marsh_lichen": 2, "copper_scale": 1},
		"source": {"kind": "trainer", "where": "iv_zorka"},
		# output: consumable — 5 min blue-sight: thread filaments + dormant
		# inscriptions glint on screen (satisfies scan objectives color "blue").
		# Violet/green variants at skill 60/110; orange is §27's pilgrimage.
		# flavor: "Hessik's margin: 'if it reads blue, you may finish your tea.'"
	},
	"counteragent_of_quiet": {
		"id": "counteragent_of_quiet", "name": "Counteragent of Quiet", "station": "still",
		"profession": "hessik_method", "skill_req": 120, "difficulty": 125,
		"condition": {"kind": "warm_ground"},
		"output": "counteragent_of_quiet",
		"cost": {"cult_wax": 1, "clean_salt": 1, "river_pearl": 1},
		"source": {"kind": "master", "where": "gm_pall — 'Read the Land' capstone"},
		# output: consumable — purges all entrancement stacks + 5 min immunity
		# (the Copper Wells / pilgrim mechanic). Must be brewed where the
		# symptom lives: the cure keeps a grudge.
		# flavor: "Bitter as the argument it settles."
	},
	"orange_reading_still": {
		"id": "orange_reading_still", "name": "Orange Reading (Still-Run)", "station": "still",
		"profession": "hessik_method", "skill_req": 250, "difficulty": 255,
		"condition": {"kind": "at_station", "station": "cold_hollow_still"},
		"output": "orange_reading_still",
		"cost": {"ashvent_salt": 3, "luminous_lichen": 2, "thread_filament": 1},
		"source": {"kind": "master", "where": "av_hessikist Irod — Act IV close"},
		# output: consumable — 5 min ORANGE-sight: live-signal sources read on
		# screen. Required by an Act VI main (the Archive thread-gate survey);
		# endgame raid-prep consumable thereafter.
		# flavor: "Brewed in the one cold place it left you. Drink it angry."
	},

	# ===================== SECONDARIES (4) =====================
	"boreks_stew_proper": {
		"id": "boreks_stew_proper", "name": "Borek's Stew (Proper)", "station": "hearth",
		"profession": "hearthcraft", "skill_req": 35, "difficulty": 40, "count": 2,
		"output": "boreks_stew_proper",
		"cost": {"fatty_haunch": 2, "marsh_lichen": 1, "clean_salt": 1},
		"source": {"kind": "master", "where": "vk_borek — he cooks; you watch; he says nothing"},
		# output: consumable food — well-fed: +3 hp/s out of combat 15 min AND
		# flags the Moment (`moment_boreks_stew`) the first time you eat it hot.
		# Yes: a cooking recipe is finale ammunition. That's the whole game.
		# flavor: "He leaves the bowl out. That's the recipe."
	},
	"proofing_black_loaf": {
		"id": "proofing_black_loaf", "name": "Proofing Black Loaf", "station": "hearth",
		"profession": "hearthcraft", "skill_req": 150, "difficulty": 155,
		"condition": {"kind": "festival:the_proofing"},
		"output": "proofing_black_loaf",
		"cost": {"gift_grain": 2, "clean_salt": 1},
		"source": {"kind": "festival", "where": "The Proofing (Sep 20 – Oct 6)"},
		# output: consumable food — 30 min +30 max hp, +10 max mana. The one
		# week a year the yeast rises everywhere, everyone bakes like it's a vigil.
		# flavor: "It rose. Don't ask it twice."
	},
	"smoked_redfin": {
		"id": "smoked_redfin", "name": "Smoked Redfin", "station": "hearth",
		"profession": "hearthcraft", "skill_req": 60, "difficulty": 65, "count": 3,
		"output": "smoked_redfin", "cost": {"redfin_gudgeon": 2},
		"source": {"kind": "trainer", "where": "rf_cott (riverline cross-sell — fish to cook)"},
		# output: consumable food — 15 min +1 mana_regen while seated.
		# flavor: "Cott says the river owes him. The river pays in these."
	},
	"ashen_poultice": {
		"id": "ashen_poultice", "name": "Ashen Poultice", "station": "",  # station-free
		"profession": "vigil_dressing", "skill_req": 100, "difficulty": 105, "count": 3,
		"output": "ashen_poultice",
		"cost": {"linen_scrap": 3, "ember_dust": 1, "marsh_lichen": 1},
		"source": {"kind": "drop", "where": "recipe_ashen_poultice — LOOT_TABLES cultist special"},
		# output: consumable — channel 4 s: restore 35% max hp over 8 s (breaks
		# on damage — the WoW bandage discipline, ash-grey).
		# flavor: "The cult got one thing right. Ansel checked."
	},
```

*(31 recipes. Trap item `fragment_that_wants_reading` (§3.5) ships alongside but is not a
recipe. Coverage: 7 primaries + 3 secondaries all represented; 9 conditioned (29% of the
signature set, 0% of wet-ink spine); channels — trainer 8, fragment 4, master 9, festival 4,
vendor 4, drop 1, book 1; skill spread 1→270 with no 50-point gap.)*

---

## 10. ECONOMY & PACING AUDIT

- **Craft share of upgrades** (ITEM_PROGRESSION §6): the §9 gear outputs land at brackets
  1–10 (riverset), 10–20 (riverplate), 26 (keepsake), 34–42 (razor, fogmirror, crown,
  emberfold), 50+ (vigil plate, lens, handprint ward) — one honest crafted option per slot
  band, uncommon default, rare only with drop-gated reagents or conditions. ✓
- **Gold sinks**: rank fees (Hand 1g / Sworn 10g / Master 50g), vendor recipes (rotation
  slot priced at ~1 session's grind per ITEM_PROGRESSION §7: 20g at b3 → 120g at b7),
  catalysts (b6+, consumed per craft), `bottled_hour` (steep, 40g+). Combined target: an
  active crafter banks ~60% of raw grind income — coin stays real. ✓
- **Skill-time**: ~340 crafts to 300 at average 65% skill-up; materials for that path ≈
  30–35 focused gathering hours across the leveling journey — Classic-honest: a profession
  finishes with the character, not before. Conditions and festivals compress it for
  planners; the +15pp bonus means a condition-chaser saves ~4 hours. ✓
- **Two-primary pressure**: re-weave (thread_binding) + writ (ledger_craft) are the only
  services other players/alts cannot self-supply without the profession — the social/mule
  economy anchors, mirroring WoW enchanting/tailoring pull without cloning either. ✓

---

## 11. INTEGRATION CHECKLIST (for the implementation pass)

1. **`crafting.gd`** — add `PROFESSIONS`, `_prof_skill`/`_prof_spec` + serialize v2,
   recipe-v2 defaults, `condition_met()`, `_roll_skill_up()`; annotate the 6 demo recipes
   (§8 retrofit). Existing API (`can_craft`, `craft`, `grant`, scroll learning) unchanged.
2. **`crafting_ui.gd`** — skill bar per station's profession; ink-color recipe names
   (wet #ff8000 / settled #ffff00 / fading #40bf40 / dry #9d9d9d — WoW hues through the
   ornate-UI kit); condition line under the cost list, lit green when met; spec badge.
3. **Stations** — extend builder `stations` arrays with the §5.1 ids + `tags`; place the
   five §5.2 unique stations in their zone builders; wire `open_station` for new ids.
4. **`day_night.gd` / `weather.gd` / CALENDAR_EVENTS registry** — expose the read-only
   queries `condition_met` needs (`is_night()`, `current`, `is_active(id)`).
5. **NPC_CAST** — add `aw_chandler`, `bn_requisition`, `av_hessikist`, `gt_layer`,
   `cw_circuit`; apply the three trainer retags (§7.1); add T/V role_tags accordingly.
6. **LOOT_TABLES** — add §6.2 new material ids to zone tables/vendors; add fragment props
   to zone loot (channel 2); keep `special` recipe-scroll rows pointing at v2 recipe ids.
7. **`save_system.gd`** — persists `Crafting.serialize()` already; v2 payload rides along.
8. **Icons** — Shikashi cells for all §9 ids via the shipped `FALLBACK_ICON_CELLS`
   promotion pattern; PIL-verify per repo law.
9. **Quests** — master-taught recipes (§3 channel 3) each need a small quest def
   (QUEST_ARCHITECTURE schema v2; `rewards.recipes: [id]` as a rewards extension key);
   rank rites at 75/150/225 are one-objective quests at the trainer.
10. **Demo smoke** — `tests/smoke_test.py` addition: open forge, verify demo recipes craft
    with profession auto-learn grandfather clause; verify serialize round-trip with skill.
