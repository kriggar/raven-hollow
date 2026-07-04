# RAVEN HOLLOW — RUNEWORDS & SOCKETS (the Artifact Class Above Legendary)
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic spirit, D2 runeword mechanics.

**Grounded in (read before implementing):**
- `scripts/items.gd` — item dict shape `{id, name, slot, rarity, icon, stats, flavor,
  stackable, effect}`; `RARITY_COLORS`; the `effect`-id hook pattern handled in `player.gd`
  (`_slot_effect`, `_check_kill_effects` — the exact plumbing runeword effects reuse).
- `design/ITEM_PROGRESSION.md` — 6-tier ladder, BP budget formula
  `BP = (2.4 + 0.62*ilvl) * SLOT_W * RARITY_M`, stat costs, extension-key layering
  (`ilvl/req_level/set_id/value` — this doc adds `sockets/runes` the same way).
- `design/LOOT_TABLES.md` — `LootTables.roll_for()` pipeline, `GEAR_POOLS`, boss
  `guaranteed` slots, `bind` rules. Socket rolls bolt onto step 4 of its roll procedure.
- `design/LOOT_WINDOW.md` — panel kit (palette, row recipe, confirm-dialog precedent for
  BoP). The need/greed roll panel below is built from the same parts.
- `design/COMBAT_PACING.md` — class verb set (basic·burst·dash·root·defensive·AoE),
  interrupt rules §5.2, rank system (`normal/elite/rare`) — runeword effects compose with
  these, never replace them.
- `scripts/class_defs.gd` — 7 class kits (the dash/interrupt/AoE abilities named in §5).
- `WORLD_PLAN.md` — the 3 raids: **The Killing Floors** (Valrom), **The Black Spire**
  (Cazimir), **The Grave & the Bloodstone Pit** (Lilith / the Thirsty Stone). Runes drop
  nowhere else. Adventurer Sim (bot raids) is deferred; the roll flow is designed now.
- `../_lore_extract.txt` — Underlanguage canon: a self-replicating command-virus; curiosity
  is the vector; **transcription spreads it**; comprehension erases; the six escalating
  symptoms (warm ground → coppered wells → dead yeast → aligned dust → listening → deletion);
  detection grammar green=waking, violet=sub-terrestrial, **shifting-orange=live signal**.

**OWNER MANDATE served:** RUNEWORD is the artifact class ABOVE legendary. Runes are carved
Underlanguage syllables the player must not read — using them is playing with fire. Socket
specific runes in a specific ORDER into a socketed base and the item transforms into a named
artifact. Runes drop only from raid bosses at 0.5–2%, everyone rolls WoW-style, with a
bad-luck floor.

---

## 1. THE RARITY LADDER, CONFIRMED (+1 tier)

| Tier | Color | Source law |
|---|---|---|
| poor | grey `(0.62, 0.62, 0.62)` | junk rolls — the coin engine |
| common | muted white `(0.92, 0.91, 0.87)` | vendor/world filler |
| uncommon | green `(0.35, 0.75, 0.35)` | quests, crafts, world drops |
| rare | blue `(0.3, 0.5, 0.9)` | rare-elites, dungeon bosses, capstones |
| epic | purple `(0.62, 0.35, 0.85)` | act bosses, world epics, lore sets |
| legendary | orange `(1.0, 0.55, 0.1)` | quest-line narrative capstones ONLY |
| **RUNEWORD** | **shifting orange** (animated, §1.1) | **assembled, never dropped** — the only tier the player *makes* |

Legendaries are the world remembering you. **Runewords are you doing the thing the entire
setting warns you not to do.** A legendary is given; a runeword is transcribed — and in
Draconia, transcription is how the command-virus spreads. That is why the tier sits above
legendary and why its color is the lore bible's *live signal*.

### 1.1 The runeword color — "shifting orange"

Canon detection grammar: shifting orange = the Underlanguage writing itself into the medium
(the Deadheart's color). A completed runeword item **is a live transmission point the player
carries**. Render law:

```gdscript
# items.gd — RARITY_COLORS gains:
"runeword": Color(1.0, 0.42, 0.05),   # base hue; UI layers animate it (below)

# Anywhere a runeword name/rim renders (bag slot rim, tooltip name, loot row,
# nameplate-style flourishes): sine-shift the color each frame — the ONLY
# animated rarity in the game, so it reads as alive from across a menu:
#   t = Time.get_ticks_msec() / 1000.0
#   c = RARITY_COLORS["runeword"].lerp(Color(1.0, 0.62, 0.0), 0.5 + 0.5 * sin(t * 2.6))
```

Static fallback (screenshots, disabled-animation setting): the base hue. Tooltip tier line
reads **"Runeword"** where legendaries read "Legendary".

---

## 2. SOCKETS

### 2.1 Which slots can roll sockets

Only **main_hand**, **chest**, and **head** (owner mandate: weapons/chest/helm). Off-hand,
legs, boots, rings, trinkets never socket — keeps the shipped legendaries (Bulwark,
Gravekeeper's Band) and the ring/trinket budget lanes clean, and concentrates the base-hunt
on three farmable slots.

| Slot | Max sockets | Note |
|---|---|---|
| main_hand | 3 | the flagship runeword canvas |
| chest | 3 | tank/caster words |
| head | 2 | 2-syllable words only |

### 2.2 What can roll sockets (and what never does)

| Source | Sockets? |
|---|---|
| World-drop gear (LOOT_TABLES `gear_pool` picks) | **yes** — the socket roll below |
| Dungeon-boss bonus world-roll (`gear_chance: 0.25` jackpot roll) | **yes**, same odds |
| Boss `guaranteed` slots (curated BoP) | never — curated stat pieces stay curated |
| Quest rewards | never |
| Craft outputs | never rolled — but see the Rune-Chisel, §2.5 |
| Legendaries / set pieces | never — `effect`/`set_id` items are already spoken for |

Rarities that can roll sockets: **common, uncommon, rare, epic**. (Epic sockets exist for
rune stat-stuffing, §3.4 — but runewords refuse epic bases, §4.2. That tension is deliberate.)

### 2.3 Socket odds (rolled once, at drop time, after the rarity/pool pick)

Step 4½ of the LOOT_TABLES roll procedure: if the rolled gear item's slot is
`main_hand/chest/head`, roll sockets:

```
P(has sockets) by rarity:   common 4% · uncommon 7% · rare 12% · epic 15%
```

Socket **count** weights, by the item's ilvl (head caps at 2 — excess rerolls as 2):

| ilvl band | 1 socket | 2 sockets | 3 sockets |
|---|---|---|---|
| 1–19 | 100% | — | — |
| 20–39 | 80% | 20% | — |
| 40–54 | 55% | 38% | 7% |
| 55–60 | 40% | 42% | **18%** |

Feel math: a bracket-8 farming hour (~120 kills, ~11% gear chance) yields ~13 gear drops,
~1.2 socketed, a 3-socket i55+ base roughly **1 per 8–10 hours of world farming** — the base
hunt is a real but background project while raiding for the runes themselves. A 3-socket
*rare* base of the right slot is itself a tradeable event (BoE per LOOT_TABLES §7).

### 2.4 Data shape (items.gd extension keys — the crafting.gd layering pattern)

Two new optional keys, ignored by all core code, read only by tooltip/bag/socketing logic:

```gdscript
"sockets": 2,              # int 0-3; 0/absent = unsocketed (never shows pips)
"runes": ["veth", ""],     # Array[String], size == sockets, ORDER IS THE WORD.
                           # "" = empty socket. Index 0 renders leftmost.
```

Both keys serialize for free (items are dicts; `save_system.gd` untouched, same as
`ilvl/set_id`). `Inventory` ignores unknown keys — non-breaking by construction.

### 2.5 The Rune-Chisel (base-hunt anti-frustration floor)

One drop-gated b8 recipe (the `crafting.gd` recipe-scroll pattern):
**Recipe: Underlanguage Chisel** — drops from Coldharbor Deep's end boss (8%). Craft cost:
3× `blackglass_shard`, 2× `anchor_lead`, 1× `kerbstone_chip`, 40 gold. Using the chisel on an
eligible unsocketed item (main_hand/chest/head, rarity ≤ epic, ilvl ≥ 40) adds **1 socket,
once per item** (`"chiseled": true` guard key). It cannot raise an item past its slot cap and
cannot add a *second* socket — the chisel floors the drought ("I have the runes and no base"),
it does not replace the hunt for natural 2–3 socket bases.

Flavor: *"A mason's chisel, re-ground. The edge is ordinary. What you cut with it is not."*

---

## 3. RUNES — carved syllables of the command-virus

### 3.1 What a rune is (canon)

A rune is a palm-sized stone chip carved with **one Underlanguage syllable** — a fragment of
the command-virus, knapped whole off a transmission surface by something that died holding
it. Each rune names one thing the virus does to the world. The player is warned, repeatedly,
in-fiction, **not to read them**. Socketing one is *transcription* — the act the lore bible
names as the exact mechanism by which the virus spreads. The player is playing with fire and
the game never pretends otherwise.

Canon safety valve (why assembling words doesn't comprehension-kill the player): the player
never *reads* the syllables — they fit shapes, the way Anara "reads around the meaning."
Partial exposure entrances; it does not erase. The whispers in §5 are what almost-understanding
sounds like. (Design note, narrative hook, zero mechanics now: each completed runeword
increments a hidden world-state counter — *the two notes drift a little closer*. The endgame
scripts may read it.)

Tooltip law for every rune: the flavor's **last line is always a warning**, and the syllable
is never translated anywhere in the UI. Optional polish (one line of code): once the player
has owned 6+ distinct runes, every rune tooltip appends a final line: *"You are starting to
see how they fit. Stop."*

### 3.2 Rune tiers & the detection-color grammar

Three tiers, glowing per the canon detection grammar (icon rim + bag glint color):

| Tier | Glow | Count | Drops from |
|---|---|---|---|
| **Lesser** | green (*the waking*) | 6 | any raid boss |
| **Greater** | violet (*sub-terrestrial*) | 4 | any raid boss (rarer) |
| **Apex** | shifting orange (*live signal*) | 2 | the 3 raid finales ONLY |

The six lesser runes are the six escalating symptoms of an executing site — the player has
been reading these signs on the land since Vetka; now they hold them:

### 3.3 The 12 runes (full spec)

Socket bonus = flat stats granted while socketed (order-independent; the word is
order-dependent). BP costs per ITEM_PROGRESSION §2.3. All runes: `slot: "none"`,
`stackable: false`, `rarity: "rare"` for roll/color purposes is WRONG — runes carry
`rarity: "runeword"`-adjacent rendering via their own `type: "rune"` + tier glow; tooltip
tier line reads "Rune — do not read".

| Rune | Syllable of… | Tier | Socket bonus (BP) | Flavor (last line is law) |
|---|---|---|---|---|
| **VETH** | the ground warming | Lesser | +30 hp (6) | *"Snow refuses to lie on it. It is warm the way a held breath is warm. Do not read it."* |
| **SUL** | the wells coppering | Lesser | +25 mana (5) | *"Your waterskin tastes of coins for a day after you carry it. Do not read it."* |
| **NUL** | the yeast dying | Lesser | +5% crit (5) | *"Small, domestic, catastrophic. Bread will not rise in the same bag. Do not read it."* |
| **ISK** | the dust aligning | Lesser | +4% speed +5 hp (5) | *"Motes hang around it in faint parallel lines, pointing somewhere. Do not follow them. Do not read it."* |
| **OM** | the stone stilling | Lesser | +5 armor (5) | *"It is heavier every time you decide to throw it away. Do not read it."* |
| **KAR** | the flesh correcting | Lesser | +5 damage (5) | *"The edge of the carving is sharper than the stone it is cut into. Do not read it."* |
| **THAR** | the listening | Greater | +2 mana_regen (8) | *"You catch yourself tilting toward your own bag. Stop finishing the sentence. Do not read it."* |
| **MOR** | the grave holding | Greater | +45 hp (9) | *"The dead handle it best. You are not dead. Do not read it."* |
| **DRA** | the thirst | Greater | +8 damage +5 hp (9) | *"A gnawing lack no meal fixes. The stone was named for this syllable. Do not read it."* |
| **ZEV** | the thread animating | Greater | +30 mana +3% crit (9) | *"Blue filament in the grooves. It is still faintly warm. Do not read it."* |
| **AZH** | the erasing | Apex | +7 damage +7% crit (14) | *"Not a wound. A correction. He just finished the thought, and then there was less of him. DO NOT READ IT."* |
| **UR** | the first entry (restore) | Apex | +10 armor +30 hp (16) | *"Every stone in its place, every silence, and no one in it. The record prefers it that way. DO NOT READ IT."* |

Exemplar dicts (items.gd shape + extension keys — all 12 follow this template):

```gdscript
"rune_veth": {
	"id": "rune_veth", "name": "Rune VETH", "slot": "none",
	"rarity": "rare", "icon": "pixel:rune_veth",
	"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
	"flavor": "Snow refuses to lie on it. It is warm the way a held breath is warm. Do not read it.",
	"stackable": false, "effect": "",
	"ilvl": 60, "req_level": 55, "set_id": "", "value": 0,
	# rune extension keys (layering pattern):
	"type": "rune", "rune_tier": "lesser", "rune_glow": "green",
	"socket_bonus": {"hp": 30.0},
	"bind": "pickup",     # ALL runes are BoP — the roll (§7) is the trading moment
},
"rune_azh": {
	"id": "rune_azh", "name": "Rune AZH", "slot": "none",
	"rarity": "epic", "icon": "pixel:rune_azh",
	"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
	"flavor": "Not a wound. A correction. He just finished the thought, and then there was less of him. DO NOT READ IT.",
	"stackable": false, "effect": "",
	"ilvl": 60, "req_level": 60, "set_id": "", "value": 0,
	"type": "rune", "rune_tier": "apex", "rune_glow": "signal_orange",
	"socket_bonus": {"damage": 7.0, "crit_pct": 7.0},
	"bind": "pickup",
},
```

(`rarity` on rune dicts drives roll-window text color only — lesser=rare-blue,
greater=epic-purple, apex=legendary-orange — so a rune row in the loot window screams
appropriately even before the tier glow renders. `value: 0`: **vendors will not touch
them.** Nobody in Draconia buys a carved syllable.)

### 3.4 Socketing rules

1. **Permanent.** A socketed rune never comes out. *"What is written is written — prying a
   syllable loose means reading it."* The confirm dialog (§8) says so in plain words.
2. **No duplicate syllables in one item.** *"A syllable repeated is a stutter; the mark
   refuses."* (Also caps epic stat-stuffing: best possible epic 3-socket = AZH+UR+DRA =
   +39 BP on a 67-BP epic MH ≈ 106 BP of raw stats — real, but stat-only, vs a runeword's
   ~90 BP **plus** a build-defining effect. The greedy path exists; the patient path wins.)
3. **Order is chosen at socketing.** Dragging a rune onto the item fills the **leftmost empty
   socket**. Order cannot be rearranged afterward (permanence rule) — placing runes IS
   spelling. Getting the sequence wrong on a hunting-months base is the game's most
   delicious mistake; the confirm dialog always previews the resulting sequence (§8.3).
4. Rune socket bonuses apply while socketed (Inventory.stat_totals extension, §9), and are
   **consumed** — replaced entirely — if the word completes and the item transforms.

---

## 4. RUNEWORDS — the transformation

### 4.1 The D2 law, Draconia grammar

Fill **all** sockets of an eligible base with a specific rune **sequence** → the item
transforms, permanently, into a named artifact. The name of the artifact IS the sequence —
the syllables, hyphenated, now reading as one word. The game never translates it. The
tooltip's flavor line is the **whisper**: what the player character almost understands,
standing at the edge of comprehension.

### 4.2 Base requirements (all words)

| Requirement | Rule | Canon |
|---|---|---|
| Slot | must match the word's slot | — |
| Socket count | must equal the word's length **exactly** (2-word in a 3-socket base: never completes — D2 law) | a word with a spare socket is an unfinished sentence |
| Base rarity | **common, uncommon, or rare only** — epics refuse the word | *"The Word overwrites. It will not share a page written in a loud hand — it wants quiet metal."* |
| Base ilvl | ≥ the word's `min_base_ilvl` (55, apex words 58) | the budget gate |
| Sequence | exact order, left to right | spelling |

On completion the base contributes **nothing** to the result — the artifact is a fully
hand-authored dict (the legendary precedent). The base's identity is kept only as a
provenance line in the tooltip: *"Written on: Bog-Iron Cleaver."* Players will farm
*specific* quiet bases anyway, for the story of it.

### 4.3 Artifact law

- `rarity: "runeword"`, `ilvl: 61` (one above cap — the only i61 items in the game; the
  tooltip number itself says *above legendary*), `req_level: 60`.
- Stat budget: RUNEWORD joins `RARITY_M` at **2.4** (legendary 2.0). At i60: MH ≈ 95 BP,
  chest ≈ 86, head ≈ 71. Statlines below spend to ~90–95% of that — the effect is the tier.
- Every artifact carries a **mandatory `effect` id** (player.gd hook, legendary precedent).
- `bind: "pickup"` implicitly (it transformed in your bag), `value: 0` — no vendor will
  hold it. It cannot be disenchanted, sold, or destroyed casually (destroy = the bag's
  destroy flow + a triple confirm; it is, canonically, a live signal — you don't just drop it).
- Transform moment (§8.4) is the game's biggest single VFX payoff outside raid finales.

---

## 5. THE TEN RUNEWORDS

Summary (full statted dicts in §5.1). TTK/class-verb references are COMBAT_PACING's;
ability names are `class_defs.gd`'s.

| # | Word (sequence) | Base | Artifact effect (id) | Builds it defines |
|---|---|---|---|---|
| 1 | **VETH-OM** | chest, 2s, i55+ | `patient_ground` — stand still 1s → +3 armor/s stacking (max +15); any movement sheds it. A warm-ground decal grows under you. | Paladin Consecration turret, Warrior Earthshaker, bear-form Druid — the fortress fantasy |
| 2 | **KAR-DRA** | main_hand, 2s, i55+ | `thirsting_edge` — ability hits heal you for 12% of damage dealt; 24% while below 35% hp. | melee sustain: Warrior, Rogue, Maul Druid — the "never eats" build |
| 3 | **SUL-THAR** | head, 2s, i55+ | `listening_well` — interrupting an enemy cast restores 15% max mana and makes your next ability free. | Mage, Necromancer — pays you for playing COMBAT_PACING §5.2 correctly |
| 4 | **ISK-NUL** | main_hand, 2s, i55+ | `quiet_dust` — after your dash ability (Shadowstep/Blink/Shield Charge/Raven Dash), your next ability within 3s always crits and pulls **no social aggro** for 3s. | Rogue and Hunter openers; surgical pack-pulling |
| 5 | **MOR-ZEV** | head, 2s, i55+ | `threaded_grave` — your killing blows have 20% chance to raise the corpse as a thread-shell ally for 12s (normal rank only, one at a time; counts as a minion). | Necromancer army; any class gets a taste of the North's horror working *for* them |
| 6 | **DRA-SUL** | chest, 2s, i55+ | `coppered_well` — dropping below 30% mana grants 20 mana/s for 5s (60s cd). | Mage/Necro burn phases; Paladin Lay-on-Hands insurance |
| 7 | **THAR-ISK-KAR** | main_hand, 3s, i55+ | `aligned_edge` — each crit aligns the dust: +3% crit, stacking to +15%; taking any hit scatters it to 0. | glass cannon: Rogue, Hunter, crit Mage — dodge-perfect play made visible |
| 8 | **OM-UR** | chest, 2s (apex), i58+ | `restored_entry` — the first killing blow against you each 120s instead sets you to 30% hp and entombs you in stone for 2s (invulnerable, unable to act). | every tank; the raid-wipe insurance every class whispers about |
| 9 | **VETH-MOR-DRA** | main_hand, 3s, i55+ | `harvest_below` — enemies that die within 40px of a corpse erupt for 30% of their max hp as AoE damage. | AoE farm: Whirlwind Warrior, Bone Nova Necro, Flame Strike Mage — chain-detonation grinding |
| 10 | **AZH-UR** | main_hand, 2s (apex), i58+ | `the_correction` — your abilities **delete** normal-rank enemies below 15% hp (no damage number, no wound; full XP/loot). Vs elite/rare/boss: +15% damage below 15% instead. | the chase item of the whole game, all 7 classes |

Design notes:
- Words 1–7 & 9 use lesser/greater runes only — buildable in one raid tier. Words 8 & 10 each
  need an apex rune (finales only) — the two "server-first" words.
- Every effect composes with a **class verb**, not a class: `quiet_dust` reads "your dash
  ability" and works for all seven kits because COMBAT_PACING gave every kit the verb.
- `the_correction`'s delete is the comprehension-death made mechanical: the body intact,
  the entry overwritten. It must *feel* wrong — no hit-stop, no number, a half-beat of
  silence, the corpse simply completes.

### 5.1 Artifact dicts (exact items.gd shape; budgets verified vs BP at RARITY_M 2.4)

```gdscript
# ==================================================================
# RUNEWORD ARTIFACTS — ilvl 61, req 60, rarity "runeword", value 0.
# "runeword" extension keys: word (sequence), whisper = flavor.
# ==================================================================
"rw_veth_om": {
	"id": "rw_veth_om", "name": "VETH-OM", "slot": "chest",
	"rarity": "runeword", "icon": "pixel:rw_veth_om",
	"stats": {"damage": 0.0, "armor": 30.0, "hp": 240.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 1.0},
	"flavor": "…the ground under you is patient. it has been waiting for someone to stand still…",
	"stackable": false, "effect": "patient_ground",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["veth", "om"], "bind": "pickup",
	# BP 82/86: armor 30 + 240hp(48) + regen1(4).
},
"rw_kar_dra": {
	"id": "rw_kar_dra", "name": "KAR-DRA", "slot": "main_hand",
	"rarity": "runeword", "icon": "pixel:rw_kar_dra",
	"stats": {"damage": 58.0, "armor": 0.0, "hp": 90.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 10.0},
	"flavor": "…it drinks what it corrects. you feel steadier with every stroke, and you decide not to ask why…",
	"stackable": false, "effect": "thirsting_edge",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["kar", "dra"], "bind": "pickup",
	# BP 86/95: dmg 58 + 90hp(18) + crit10. Under-spent — the leech carries it.
},
"rw_sul_thar": {
	"id": "rw_sul_thar", "name": "SUL-THAR", "slot": "head",
	"rarity": "runeword", "icon": "pixel:rw_sul_thar",
	"stats": {"damage": 0.0, "armor": 10.0, "hp": 25.0, "mana": 220.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 3.0},
	"flavor": "…the well listens back now. when you cut a voice off mid-sentence, it pays you for the silence…",
	"stackable": false, "effect": "listening_well",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["sul", "thar"], "bind": "pickup",
	# BP 71/71: armor 10 + 25hp(5) + 220mana(44) + regen3(12).
},
"rw_isk_nul": {
	"id": "rw_isk_nul", "name": "ISK-NUL", "slot": "main_hand",
	"rarity": "runeword", "icon": "pixel:rw_isk_nul",
	"stats": {"damage": 48.0, "armor": 0.0, "hp": 70.0, "mana": 0.0, "speed_pct": 8.0, "crit_pct": 15.0},
	"flavor": "…the dust holds its lines while you move through it. nothing marks your passing. nothing rises…",
	"stackable": false, "effect": "quiet_dust",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["isk", "nul"], "bind": "pickup",
	# BP 85/95: dmg 48 + 70hp(14) + spd8 + crit15.
},
"rw_mor_zev": {
	"id": "rw_mor_zev", "name": "MOR-ZEV", "slot": "head",
	"rarity": "runeword", "icon": "pixel:rw_mor_zev",
	"stats": {"damage": 0.0, "armor": 12.0, "hp": 130.0, "mana": 130.0, "speed_pct": 0.0, "crit_pct": 6.0},
	"flavor": "…the thread wants hands. the grave keeps offering. for twelve seconds at a time, they agree…",
	"stackable": false, "effect": "threaded_grave",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["mor", "zev"], "bind": "pickup",
	# BP 70/71: armor 12 + 130hp(26) + 130mana(26) + crit6.
},
"rw_dra_sul": {
	"id": "rw_dra_sul", "name": "DRA-SUL", "slot": "chest",
	"rarity": "runeword", "icon": "pixel:rw_dra_sul",
	"stats": {"damage": 0.0, "armor": 14.0, "hp": 110.0, "mana": 180.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 3.0},
	"flavor": "…the well refills when you have thirsted enough. do not ask from where. the water tastes of coins…",
	"stackable": false, "effect": "coppered_well",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["dra", "sul"], "bind": "pickup",
	# BP 84/86: armor 14 + 110hp(22) + 180mana(36) + regen3(12).
},
"rw_thar_isk_kar": {
	"id": "rw_thar_isk_kar", "name": "THAR-ISK-KAR", "slot": "main_hand",
	"rarity": "runeword", "icon": "pixel:rw_thar_isk_kar",
	"stats": {"damage": 55.0, "armor": 0.0, "hp": 40.0, "mana": 0.0, "speed_pct": 7.0, "crit_pct": 18.0},
	"flavor": "…listen. align. correct. the dust points at what you are about to hit, if nothing touches you first…",
	"stackable": false, "effect": "aligned_edge",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["thar", "isk", "kar"], "bind": "pickup",
	# BP 88/95: dmg 55 + 40hp(8) + spd7 + crit18.
},
"rw_om_ur": {
	"id": "rw_om_ur", "name": "OM-UR", "slot": "chest",
	"rarity": "runeword", "icon": "pixel:rw_om_ur",
	"stats": {"damage": 0.0, "armor": 36.0, "hp": 245.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
	"flavor": "…the record declines the edit. for two heartbeats you are every stone in its place, and nothing can be added…",
	"stackable": false, "effect": "restored_entry",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["om", "ur"], "bind": "pickup",
	# BP 85/86: armor 36 + 245hp(49). Apex word (UR): min_base_ilvl 58.
},
"rw_veth_mor_dra": {
	"id": "rw_veth_mor_dra", "name": "VETH-MOR-DRA", "slot": "main_hand",
	"rarity": "runeword", "icon": "pixel:rw_veth_mor_dra",
	"stats": {"damage": 50.0, "armor": 0.0, "hp": 130.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 8.0},
	"flavor": "…the ground is warm because it is fed. it is fed because you are generous. the furrows do not ask why…",
	"stackable": false, "effect": "harvest_below",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["veth", "mor", "dra"], "bind": "pickup",
	# BP 84/95: dmg 50 + 130hp(26) + crit8.
},
"rw_azh_ur": {
	"id": "rw_azh_ur", "name": "AZH-UR", "slot": "main_hand",
	"rarity": "runeword", "icon": "pixel:rw_azh_ur",
	"stats": {"damage": 62.0, "armor": 0.0, "hp": 80.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 13.0},
	"flavor": "…erase. restore. the same operation. what you finish leaves no wound, because it was never, in the record, there…",
	"stackable": false, "effect": "the_correction",
	"ilvl": 61, "req_level": 60, "set_id": "", "value": 0,
	"word": ["azh", "ur"], "bind": "pickup",
	# BP 91/95: dmg 62 + 80hp(16) + crit13. Double-apex: min_base_ilvl 58.
},
```

### 5.2 The RUNEWORDS registry (items.gd const, keyed by joined sequence)

```gdscript
const RUNEWORDS := {
	# key = "_".join(sequence). Checked by Items.runeword_for(item) whenever a
	# socket fills: item.sockets == sequence.size() AND item.runes == sequence
	# AND item.slot == slot AND RARITY order(item.rarity) <= rare
	# AND item.ilvl >= min_base_ilvl  ->  transform to artifact_id.
	"veth_om":      {"artifact": "rw_veth_om",      "slot": "chest",     "min_base_ilvl": 55},
	"kar_dra":      {"artifact": "rw_kar_dra",      "slot": "main_hand", "min_base_ilvl": 55},
	"sul_thar":     {"artifact": "rw_sul_thar",     "slot": "head",      "min_base_ilvl": 55},
	"isk_nul":      {"artifact": "rw_isk_nul",      "slot": "main_hand", "min_base_ilvl": 55},
	"mor_zev":      {"artifact": "rw_mor_zev",      "slot": "head",      "min_base_ilvl": 55},
	"dra_sul":      {"artifact": "rw_dra_sul",      "slot": "chest",     "min_base_ilvl": 55},
	"thar_isk_kar": {"artifact": "rw_thar_isk_kar", "slot": "main_hand", "min_base_ilvl": 55},
	"om_ur":        {"artifact": "rw_om_ur",        "slot": "chest",     "min_base_ilvl": 58},
	"veth_mor_dra": {"artifact": "rw_veth_mor_dra", "slot": "main_hand", "min_base_ilvl": 55},
	"azh_ur":       {"artifact": "rw_azh_ur",       "slot": "main_hand", "min_base_ilvl": 58},
}
```

Discovery design (WoW-Classic spirit): **sequences are not listed in-game.** They are found
as **lore fragments** — a rubbing in the Riddler's Quarter, a margin note in the Archive, a
dying listener's last arrangement of pebbles. Each fragment item ("Sequence Fragment:
VETH‑OM", the `charcoal_rubbing` precedent) teaches one word to the character's journal when
used. Fragments drop from raid trash at ~3% and dungeon end-bosses at ~5% — you learn the
words long before you can afford to spell them. The community will trade sequences out of
game anyway; that IS the D2 magic.

---

## 6. ACQUISITION — runes drop only from the biggest bosses

### 6.1 Sources & exact rates (owner mandate: 0.5–2%)

Eligible kills: **raid bosses only** — the boss encounters of The Killing Floors, The Black
Spire, and The Grave & the Bloodstone Pit (WORLD_PLAN raid roster; assume ~4+4+5 bosses
incl. the 3 finales). Dungeon bosses, rare-elites, world bosses: **never**. One rune roll
per boss kill, resolved before the loot window opens (the rune appears as a row in the boss
loot window, §7).

| Source | P(rune) per kill | Tier split when it hits |
|---|---|---|
| Raid boss (non-finale, any raid) | **1.5%** | lesser 80% / greater 20% / apex 0% |
| Finale: **Valrom the Forged King** (Killing Floors) | **2.0%** | lesser 45% / greater 40% / **apex 15%** |
| Finale: **Cazimir in the Walls** (Black Spire) | **2.0%** | lesser 45% / greater 40% / **apex 15%** |
| Finale: **the Thirsty Stone** (Bloodstone Pit) | **2.0%** | lesser 30% / greater 40% / **apex 30%** |

Within a tier the rune id is a uniform pick, **except**: AZH bias — Valrom/Cazimir apex hits
are 50/50 AZH/UR; the Thirsty Stone's apex hits are 40% AZH / 60% UR (*restore* belongs to
the stone). Effective apex rate: 0.30–0.60% per finale kill — squarely at the owner's floor.

Lockout: raids are weekly-lockout post-Adventurer-Sim (classic law). ~13 eligible kills per
full-clear week → expected ~0.21 runes/week from raw rolls.

### 6.2 Bad-luck protection (the anti-frustration floor)

Per character, one pity counter, persisted by `save_system.gd`:

```gdscript
# SaveSystem: rune_pity: int = 0
```

- Every eligible boss kill **without** a rune drop (for this character): `rune_pity += 1`,
  and the character's effective rune chance gains **+0.10% per pity point** (additive:
  a 1.5% boss at pity 20 rolls at 3.5%).
- **Hard floor: the 50th consecutive dry kill drops a guaranteed rune** (tier split of the
  boss that triggered it).
- Any rune drop (rolled, pity-triggered, or first-clear) resets `rune_pity` to 0.

Math honesty: raw 1.5–2% ≈ 1 rune per ~60 kills. With the ramp, expected first drop lands
near kill ~28, worst case exactly 50 (≈4 lockout weeks of full clears). Combined long-run
yield ≈ **1 rune every 2.5–3.5 weeks of raiding**. A 2-rune word is a season's project; an
apex word is the guild story of the year. That is the artifact class above legendary,
priced honestly.

### 6.3 First-clear guarantee (bootstrap)

The **first full clear of each raid** (once per character, per raid) awards one guaranteed
**lesser** rune via the finale's loot window — 3 bootstrap runes per character lifetime.
Progress feels started the day raiding starts; the grind is for the word, not the concept.

### 6.4 Distribution law

Runes are **BoP** (`bind: "pickup"`) and roll-distributed (§7). No trading, no auction —
the roll IS the economy. (Forward-armor: if trading ships later, runes stay BoP; bases and
sequence fragments are the tradeable halves of the system.)

---

## 7. WHEN A RUNE DROPS, EVERYONE ROLLS (need/greed spec)

Designed now, bots later (Adventurer Sim is a deferred owner session — WORLD_PLAN). The flow
below runs entirely on data the sim will already own (party roster, member "inventories").
Solo kills (no group): no roll — the rune is a normal click-to-take loot row.

### 7.1 Trigger & rules (WoW-classic law, adapted)

1. Boss dies in a group context → loot rolls resolve normally, THEN each rune row (and, one
   flag away, any BoP row the sim wants contested later) opens a **RollSession** for every
   living group member, including the player.
2. Choices: **Need** / **Greed** / **Pass**, 30-second deadline; no response = Pass.
3. **Need eligibility**: you may Need a rune only if you do not already own a copy of that
   rune id (bag + bank + socketed count == 0). Otherwise the Need button is disabled with
   the tooltip *"You already hold this syllable."* (Everyone can always Greed — a second
   VETH is a stat-stuffing rune, and the rule keeps first-timers competitive.)
4. Resolution: any Need beats every Greed. Highest d100 among the winning intent takes it.
   **Ties re-roll among the tied** (visible re-roll lines — the drama is the point).
5. All Pass → the row reverts to free-for-all click-to-take in the corpse window.
6. Winner's rune is granted directly (bots: to their sim bags); losers see the result lines.
   Bag full → rune is mailed... no mail system: rune stays reserved in the corpse for the
   winner only (LOOT_WINDOW despawn timer pauses on reserved rows).

```gdscript
# scripts/roll_session.gd (new, static-friendly; UI-agnostic so the sim can run it headless)
# RollSession := {
#   "item": Dictionary,            # the rune dict
#   "corpse": NodePath,            # source lootable
#   "members": Array[String],      # roster ids ("player", bot ids)
#   "eligible_need": Dictionary,   # member id -> bool (rule 3, computed at open)
#   "choices": Dictionary,         # member id -> "need"|"greed"|"pass"
#   "rolls": Dictionary,           # member id -> int (d100, rolled at resolve)
#   "deadline": float,             # unix time, open + 30.0
# }
```

### 7.2 Roll UI (built from the LOOT_WINDOW / bag kit — colors verbatim)

A **RollBar** per active session, stacked top-center (below the zone-banner lane), 232×46 px
in the 640×360 space — glanceable mid-combat, never modal:

```
RollBar (Panel: BOX_BG fill, panel_brown 9-patch rim, FRAME_TINT)
 |- RuneIcon 24x24, rim = tier glow color (green/violet/shifting-orange, §3.2)
 |- Name label: "Rune AZH" — Alagard 10, rune rarity color, OUTLINE_DARK
 |- TimerBar: 2 px GOLD bar draining right-to-left over 30 s (the §5.2 cast-bar recipe)
 |- Buttons (the bag-button recipe, gold-glow hover; keys 1/2/3):
 |    [ Need ]   d20 icon  — disabled + grey when ineligible (rule 3)
 |    [ Greed ]  coin icon
 |    [ Pass ]   X icon
```

After choosing, the player's buttons collapse to their choice ("Need…") while others decide.
Resolution posts to the toast channel (`crafting_ui.show_toast`, the loot-window channel),
one line per roller, then the verdict:

```
Vasile-bot rolls Need — 87        (member name in class color, roll in PARCHMENT)
You roll Need — 91
Mirela-bot passes.
YOU WIN: Rune AZH                 (verdict line in the tier glow color; losers see
                                   "Vasile-bot wins: Rune AZH")
```

Edge cases: winner disconnects/despawns (sim death) → next-highest takes it; session
outlives the corpse (despawn deferred while a session is open — LOOT_WINDOW §8 precedent);
player in dialogue → RollBar stays (it has a deadline), input keys 1/2/3 still route.

---

## 8. SOCKETING UI (on the bag kit)

All construction from `bag_ui.gd`'s shipped parts (slot recipe, DRAG_LAYER, confirm-dialog
pattern, gold-glow buttons). No new panel class — sockets are a bag-and-tooltip feature.

### 8.1 Reading sockets

- **Bag/paper-doll slots**: socketed items draw 2×2 px diamond pips centered along the slot's
  bottom edge (up to 3): empty = `SLOT_BORDER` outline; filled = the rune's tier glow color,
  filled. One glance = "socketed, 2/3 full, one violet."
- **Loot window rows** (LOOT_WINDOW §2.5): same pips right-aligned in the row — a 3-pip
  rare base in a corpse reads as the event it is.
- **Tooltip** (`item_tooltip.gd`): after the stat block, one line per socket, in order:

```
◆ VETH — +30 Health          (tier glow color)
◆ OM — +5 Armor
◇ Empty socket               (SLOT_BORDER grey)
```

  Runeword artifacts replace socket lines with the word line: `"Written on: Bog-Iron
  Cleaver"` (PARCHMENT) and render the name + rim in animated shifting orange (§1.1).

### 8.2 Socketing action

Drag a rune from a bag slot and drop it **onto** a socketed item (bag or equipped
paper-doll slot — the bag's existing drag/drop surface). While dragging a rune, every valid
target slot's border lights `SLOT_BORDER_HOVER`; invalid targets stay inert (no error spam —
the lighting is the teaching). Right-clicking a rune with exactly one valid target in the
bag offers the same flow (bag right-click precedent: `weeping_dagger`).

### 8.3 The confirm (always — permanence demands it)

Reuses the loot window's BoP confirm dialog shell:

```
Set VETH into Bog-Iron Cleaver?
Socket 2 of 3 — the sequence will read: ISK · VETH · ◇
The mark cannot be unmade.
                [ Set ]   [ Leave it ]
```

The **sequence preview line is mandatory** — spelling mistakes must be the player's, never
the UI's. If the placement would complete a known-to-this-character word (journal, §5.2
discovery), the dialog upgrades to the second warning:

```
The final syllable. The word will resolve: ISK-NUL.
This cannot be undone. It cannot be unsaid.
                [ Speak it ]   [ Not yet ]
```

If it completes a word the character has NOT discovered: same upgrade, but the word is
shown as `ISK-???` — completion still works (D2 law: the recipe fires regardless), the
player just didn't know they were about to. Those accidents become stories.

### 8.4 The transform moment

On completion: bag input locks 1.2s → the item slot flashes through the six symptom colors
(green → violet) into shifting orange → `VFX` burst (the legendary-chest gold-glint recipe
recolored to the signal orange) → icon swaps to the artifact → whisper toasts in the tier
color → a single low bell. Screenshot bait, deliberately. (One narrative beat, free to
implement: the first time any word resolves, every NPC bark in the current zone goes quiet
for one bark cycle. The world noticed.)

---

## 9. DATA SCHEMA & ENGINE TOUCH POINTS (implementation pass)

### 9.1 `items.gd`
1. `RARITY_COLORS += {"runeword": Color(1.0, 0.42, 0.05)}` (animated at render sites, §1.1).
2. New consts: `RUNES` (12 dicts, §3.3 template), `RUNEWORDS` (§5.2), the 10 `rw_*`
   artifact dicts (§5.1), the sequence-fragment items.
3. New helpers (pure, static — house style):

```gdscript
static func rune_ids() -> Array[String]                 # RUNES keys
static func runeword_for(item: Dictionary) -> String    # "" or the RUNEWORDS key matched
static func try_socket(item: Dictionary, rune_id: String) -> Dictionary:
	## Returns the updated item: rune placed in the leftmost "" of item.runes.
	## If that completes a RUNEWORDS entry (slot, exact sequence, rarity <= rare,
	## ilvl >= min_base_ilvl): returns the ARTIFACT dict instead, with
	## "written_on": item.name stamped for the tooltip provenance line.
	## Rejects: duplicate syllable in item.runes, wrong/absent sockets.
```

### 9.2 `inventory.gd`
`stat_totals()` extension (~6 lines, exactly the ITEM_PROGRESSION set-bonus pattern): for
each equipped item, for each non-empty entry in `runes`, add `RUNES[id].socket_bonus` into
the totals (bonus dicts use `STAT_KEYS`, so the existing sum loop is reused).

### 9.3 `loot_tables.gd` (LOOT_TABLES doc)
- Socket roll = step 4½ of `roll_for()` (§2.3 odds), writing `sockets`/`runes` onto the
  rolled gear dict. Applies to `gear_pool` picks only (never `guaranteed` slots).
- Raid-boss tables gain a `rune_roll` key: `{chance, tiers: {lesser, greater, apex}}` (§6.1)
  + the pity hook (`SaveSystem.rune_pity`, §6.2) + first-clear flags (§6.3).

### 9.4 `bag_ui.gd` / `item_tooltip.gd`
Socket pips (§8.1), rune drag targets + confirm dialogs (§8.2–8.3), transform sequence
(§8.4), tooltip socket lines + runeword animated name + provenance line, "Runeword" tier
label.

### 9.5 `loot_ui.gd` + new `roll_session.gd` + new `roll_bar_ui.gd`
Rune rows route through RollSession in group context (§7); RollBar stack (§7.2); reserved
rows + deferred despawn. Sim-headless by design: bots call the same
`RollSession.choose(member_id, choice)`.

### 9.6 `player.gd` — 10 new effect ids via the `_slot_effect` pattern
| effect id | wiring point (existing plumbing) |
|---|---|
| `patient_ground` | `_physics_process` stillness timer; armor stack via the `_bulwark_cd` state pattern; warm-ground decal = `VFX.ground_circle` recolor |
| `thirsting_edge` | the ability damage-dealing path (where crits roll) → self-heal |
| `listening_well` | needs COMBAT_PACING §5.2's cast-cancel to callback the interrupter (add one signal on Enemy cast-cancel) — then mana refund + free-cast flag |
| `quiet_dust` | dash-ability call sites set a 3s flag; crit override + social-aggro suppression check in Enemy `_call_pack()` |
| `threaded_grave` | `_check_kill_effects` (the `gravekeeper` precedent); shell = Raise Dead's minion spawn, 12s despawn |
| `coppered_well` | mana watcher in `_process`; cooldown via the `_bulwark_cd` pattern |
| `aligned_edge` | crit event increments stack; `take_damage` resets |
| `restored_entry` | lethal-damage intercept in `take_damage` (cheat-death; 120s cd) |
| `harvest_below` | on kill, scan group `"lootable_corpses"` within 40px (free reuse of the corpse system) → eruption AoE |
| `the_correction` | pre-hit check in ability hit resolution: target `rank == "normal"` and hp ≤15% → route to `_die()` directly, suppress damage number |

### 9.7 `save_system.gd`
`rune_pity: int`, per-raid first-clear flags, journal-known sequences. Items (sockets,
runes, artifacts) ride the existing dict serialization untouched.

### 9.8 `icons_pixel.gd`
Cells needed: 12 runes (one angular-mark glyph family, tier-tinted), 10 `rw_*` artifact
icons, sequence fragment, Underlanguage Chisel, RollBar d20/coin/X mini-icons. PIL-verify
per repo law (icon id == item id).

---

## 10. TUNING & QA CHECKLIST

1. **Budget audit**: all 10 artifacts within −10%/0% of BP at RARITY_M 2.4 (§5.1 comments);
   best stat-stuffed epic (AZH+UR+DRA ≈ 106 BP raw) stays below runeword + effect value.
2. **Drop audit**: simulate 10k raid weeks — median first rune ≤ 4 lockouts, guaranteed ≤ 50
   dry kills, apex expected ≈ 1 per 12–18 finale kills with pity.
3. **Roll audit**: 40-member session resolves < 1 frame; ties re-roll visibly; all-pass
   reverts the row; disconnect mid-roll falls through to next-highest.
4. **Spelling audit**: wrong-order runes in a right base must NOT complete (ISK-NUL vs
   NUL-ISK); 2-word sequence in a 3-socket base must NOT complete; epic base must refuse.
5. **RH_\* screenshot pass**: socket pips at 1× integer scale (2 px, no bleed), shifting
   orange animates in bag + tooltip + loot row, transform sequence full-plays, RollBar
   legible mid-combat over the Copper Wells night palette.
6. `tests/smoke_test.py` green — everything here is additive data + additive UI.
