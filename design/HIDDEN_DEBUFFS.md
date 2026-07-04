# HIDDEN DEBUFFS — The World Writes On You
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic spirit.
Grounded in: `_lore_extract.txt` (Parts II, IV, IX — symptom order, bestiary engines,
detection colors), `WORLD_PLAN.md` (creature families, zone spine, canon ground rules),
`design/COMBAT_PACING.md` (archetypes, aggro tables §5.8, regen §9.2),
`design/ITEM_PROGRESSION.md` (gold economy §7, sets §5.3, Gravekeeper's Lantern),
`design/LOOT_TABLES.md` (loot-window pipeline), `scripts/player.gd` (stats, gold,
`apply_regen_buff` hook), `scripts/enemy.gd` (aggro/leash, windup audio),
`scripts/day_night.gd` (`time_of_day` hours, `is_night`), `scripts/crafting.gd`
(hunters_stew consume path), `scripts/minimap.gd`, `scripts/weather.gd`,
`scripts/zone_defs.gd` (creature tables), `scripts/class_defs.gd`.

> **Composition note:** `design/STATUS_EFFECTS.md` was not yet on disk at time of
> writing (parallel workflow). This doc composes against its stated baseline — the
> **wolf-bite "Infected" stacking model**: debuffs are registry dicts with stacks,
> per-stack scalars, duration, and a HUD debuff bar. Hidden effects join **the same
> registry** with `hidden: true` and are simply not rendered until `revealed`.
> If STATUS_EFFECTS ships different key names, this doc's shapes rename 1:1.

Owner mandate served: **"tons of hidden debuffs that SURPRISE the player,
creature-specific, lore-appropriate."**

Canon law this entire system is built on (lore bible, Part II §1):
**curiosity is the vector, warmth is the symptom.** The Underlanguage's own
escalation — ground warms → wells copper → yeast dies → dust aligns → people
"listen" → comprehension — is the design grammar for every effect below: the
world never announces the debuff; it *reports the infection* through mundane
wrongness, and the player is Kriggar — a detective-by-noticing in a world that
punishes noticing.

---

## 1. THE CONTRACT — hidden, not unfair

A hidden debuff is a **story told backwards**: symptom first, cause later.
For that to be delight instead of frustration, these laws are absolute:

1. **No hidden HP damage.** While hidden, an effect never deals direct damage
   and never modifies a stat by more than ~10%. The scary effects are
   *systemic* — gold, prices, audio, minimap, food, aggro — things a player
   FEELS before they can name.
2. **Symptom-first, always ≥2 tells.** Every effect stages through at least two
   escalating symptoms on **distinct channels** (audio / VFX / UI / NPC bark /
   economy) before its worst stage. Symptoms never stack on the same channel —
   the §9 arbiter guarantees two simultaneous hidden effects stay legible.
3. **Everything reveals eventually.** Every entry has a hard reveal condition.
   Nothing is hidden forever; hidden is an *incubation*, not a state.
4. **Max 3 hidden effects incubating at once.** A 4th application is refused
   (oldest-first priority). Prevents symptom soup.
5. **The death recap confesses.** If a hidden effect contributed to a death,
   the death screen lists it, revealed, with its source. Dying is a legitimate
   way to learn the world (WoW-Classic spirit: the graveyard run is a lesson).
6. **Cures are learnable, repeatable, and priced like consumables** (§7 vendor
   math: 1–25 g, scaling with act). Prevention items exist and are cheap.
7. **Half the catalogue cuts both ways.** Canon: reading the world is the core
   verb. Many hidden effects are the world *writing on you* — and a written-on
   player can read things clean players can't. Tool-edges are marked ⚒.
8. **Reveal is diegetic.** The universal reveal instrument is **Hessik's
   Washes** (§4) — the same four detection colors Kriggar learns from
   *Hessik's Practical Foundations*. Alchemy reads the signal; now it reads you.

---

## 2. ENGINE — `game/hidden_effects.gd` (autoload `HiddenFX`)

One registry, one tick, one save dict. Composes with the STATUS_EFFECTS
registry (hidden entries are status effects with `hidden: true`) and with
CHARACTER_STATS via the same modifier keys `player.gd` already consumes
(`damage`, `armor`, `hp`, `mana`, `speed_pct`, `crit_pct`, `mana_regen`).

```gdscript
## HIDDEN_DEBUFFS.md §2 — effect definition shape (registry const CATALOG)
"moon_fever": {
    "id": "moon_fever", "name": "Moon-Fever", "family": "varcolaci",
    "signature": true, "hidden": true,
    "engine": "cruelty",              # lore engine: underlanguage|cruelty|thread|veil|bureau
    "wash": "green",                  # which Hessik wash reveals it (blue|violet|green|orange)
    "trigger": {"kind": "hit_taken", "attack_tag": "varcolac_bite", "night_only": true},
    "incubation_h": -1.0,             # game-hours to stage 1; -1 = event-driven (next nightfall)
    "stages": [                        # each: symptoms[] (channel ids §3) + mods (stat dict)
        {"symptoms": ["vfx_red_vignette_night"], "mods": {"damage_mult": 1.15, "speed_pct": 10.0}},
        {"symptoms": ["audio_heartbeat"],        "mods": {"damage_mult": 1.15, "speed_pct": 10.0}},
        {"symptoms": [],                          "mods": {"damage_mult": 0.80, "speed_pct": -15.0,
                                                           "regen_mult": 0.5}},  # the crash
    ],
    "reveal": {"kind": "stage_reached", "stage": 3},   # crash IS the reveal
    "cure": ["alch_wolfsbane_draught", "shrine_old_hunt", "wait_out"],
    "max_stacks": 1,
}
```

Pipeline:

- `HiddenFX.apply(id, source_ref)` — called from `enemy.gd` attack payloads
  (one new optional key `"applies_hidden": "id"` beside `"damage"`), from
  interactables (wells, inscriptions, mounds — `zone_builder` props), and from
  consume paths (`crafting.gd` eat hook). Silently inserts into the shared
  status registry with `hidden: true`. **No toast. No sound. Nothing.**
- `HiddenFX.tick(delta)` — advances incubation using `DayNight.time_of_day`
  for game-hour clocks and wall-clock for real-minute clocks (only H-31 uses
  real minutes). Stage transitions fire their symptom channels (§3).
- `HiddenFX.reveal(id)` — flips `hidden = false`; the STATUS_EFFECTS debuff
  bar picks it up on its next refresh (zero new UI needed); plays the one
  shared reveal sting: a single low bell + the tooltip opens once, unbidden.
  The tooltip is where the lore pays off — it names the source retroactively
  ("The well at the crossroads. You knew the taste was wrong.").
- `HiddenFX.cure(id, method)` — removes; some cures leave a 1-line permanent
  flavor on the character sheet (never a stat).
- Save: the registry dict rides `save_system.gd` as-is (dicts serialize).

**Stat plumbing:** `mods` dicts are summed into `Inventory.stat_totals()`
consumers the same way gear is — one added read in `player.gd::_apply_equipment`
path (`+ HiddenFX.stat_mods()`). Multiplier keys (`damage_mult`, `regen_mult`,
`vendor_mult`, `aggro_mult_family`) are read at their point of use (§3 table).

---

## 3. SYMPTOM CHANNELS — where the wrongness shows

Every symptom is one of these channel ids. Each lists its shipped integration
point, so the implementation pass is a checklist, not a search.

| Channel id | What the player experiences | Hooks into |
|---|---|---|
| `walk_interrupt_north` | character STOPS walking 0.5 s, faces north | `player.gd` movement state (skip input, force facing, timer) |
| `idle_pose_tilt` / `idle_glance_down` | idle anim tilts head / glances down | `sheet_anim.gd` idle branch |
| `audio_layer_*` | new faint loop (scraping, rumble, hum, heartbeat) | new `AudioStreamPlayer` bus "Symptom" |
| `audio_duck_high` | high frequencies roll off; wind layer gone | `AudioServer` low-pass on Master |
| `audio_mute_windup` | enemy windup audio cues silent (visuals stay) | `enemy.gd` windup SFX gate |
| `minimap_dim` | minimap darkens from the edges, per stage | `minimap.gd` modulate |
| `minimap_drift` | POI pips drift 1–2 px toward nearest inscription | `minimap.gd` pip draw ⚒ (drift points AT hidden content) |
| `map_rotate` | world map opens rotated, rights itself in 2 s | travel map UI |
| `banner_glitch` | zone-name banner one letter wrong, then corrects | `travel_system.gd` banner |
| `vendor_mult` | prices quietly ×1.10–1.15 at tagged vendors | vendor UI price calc |
| `food_block` | food/drink buffs apply zero ("the yeast dies in you") | `crafting.gd::_consume` → checks `HiddenFX.food_blocked()` |
| `gold_drain` | gold −1/min, faint stamp sound per tick | `player.gd` gold + HUD readout |
| `aggro_mult_family` | one creature family detects you farther | `enemy.gd` aggro check ×`HiddenFX.aggro_mult(archetype/family)` (composes COMBAT_PACING §5.8) |
| `loot_hook` | loot windows gain/lose a line | LOOT_TABLES roll post-pass |
| `xp_mult` | quest XP −10% | `xp_system.gd` quest grant |
| `npc_bark` | tagged NPCs comment ("you smell of the Vein") | `npc_data.gd` bark pool, condition = has effect |
| `vfx_attach` | steam footprints, flies, ember hands, black drips | `vfx.gd` / `fx_library.gd` loops |
| `dialogue_ghost` | an extra "…" option appears in dialogue | `dialogue_ui.gd` option inject |
| `regen_mult` / `regen_delay` | out-of-combat regen weaker / later | COMBAT_PACING §9.2 regen tick |
| `cast_stutter` | 10% of casts +0.3 s | `player.gd` cast start |
| `weather_local` | mist clings to you; rain misses you by a step | `weather.gd` per-player modifier |

---

## 4. THE REVEAL ECONOMY — Hessik's Washes

Canon (Part VI): Kriggar's alchemy detects the world's infection by color —
**blue = necromantic · violet = sub-terrestrial · green = thermal/waking ·
shifting orange = live signal.** The same grammar, turned inward:

| Item | Craft/vendor | Reveals (on self) | Act availability |
|---|---|---|---|
| **Hessik's Blue Wash** | herbalist 3 g / craftable (grave-moss + clean water) | all hidden effects of the **thread/undead** engine | I+ |
| **Hessik's Violet Wash** | 3 g (cave-lichen + bone-char) | **sub-terrestrial** engine (burrowers, tunnels) | I+ |
| **Hessik's Green Wash** | 5 g (vent-sulfur + tallow) | **waking/thermal** engine (varcolaci, fevers, warm ground) | II+ |
| **Hessik's Orange Wash** | 12 g, rare recipe drop | **live signal** engine (Listening, Orange Note, kerb-effects) | III+ |

Using a wash reveals matching hidden effects **without curing them** — the
tooltip names source and cure. This is the honest player economy: a cautious
player spends 3–12 g after a bad-feeling fight and buys knowledge. Old Marta
(Vetka) applies any wash for free but comments on your curiosity, disapprovingly.
Priests reveal (not cure) one random hidden effect per chapel visit, free —
"confession" reskinned.

Other diegetic revealers, used by specific entries: buying **your own file**
(Blestem Lower Market / Morven fence — information as hard currency, canon),
inn **mirrors** and **baths**, campfire rests, the **death recap**.

---

## 5. CURE VOCABULARY (lore-apt, reused across the catalogue)

| Cure class | Examples | Canon anchor |
|---|---|---|
| **Hessik's alchemy** | wolfsbane draught, incuriosity draught, expectorant, eye-wash, verdigris scrub | Part VI — alchemy is chemistry with grief in it |
| **Shrine** | Transcub confession altars (the old god who punished cruelty to the self — fits every self-inflicted curiosity effect), chapel candles, shrine of the old hunt | Part IV Blestem; churches ivy-eaten but warm |
| **Priest** | Angel Wings chapels: gut-blessing, ear-closing, washing, transfusion | Part IV — the human west resists |
| **Folk / physical** | river fords, rain, inn baths, campfires, beeswax, salt-and-fire, wax earplugs, boot swap, sleep | Pillar I — the horror is domestic; so are the remedies |
| **Undo the source** | efface the inscription, cap the well, kill the marker, burn your file, crack your tablet | Bestiary law: killing the monster rarely fixes the wrong — fixing the WRONG fixes you |
| **The thesis** | give freely to a beggar/orphanage; speak a specific true memory; refuse to wait | Part II §4 — specificity + stubbornness; small warm kindnesses |

Rule: every entry offers **at least two cure routes** at different price points
(one coin, one deed), and severe entries offer three.

---

## 6. THE CATALOGUE — 35 hidden effects, 8 creature families, 8 SIGNATURES ★

Entry format: **Source · Trigger (hidden) · Incubation · Symptom staging ·
Reveal · Cure · Mechanics.** All stat numbers are percentages or flat scalars
so they ride the 1–60 curves untouched (COMBAT_PACING §3).

---

### FAMILY 1 — THE LAND THAT READS
*(inscription stones, coppered wells, warm ground, aligned dust, the entranced —
Underlanguage engine · orange/green wash · zones 1–6, 13–14, 39)*

#### H-01 · The Listening ★ SIGNATURE
- **Source:** live inscription stones (shifting-orange under detection) —
  Stonepath, Copper Wells crossroads, Chamber Depths walls; also the "…"
  option in H-18.
- **Trigger:** using *Examine* on a live inscription = +1 silent stack. Standing
  within 60 px of one for 30 s = +1. **Curiosity is the vector** — the stones
  are interactable and the examine text is genuinely interesting. That is the trap.
- **Incubation:** 2 game-hours to first symptom.
- **Symptoms:** ①(1 stack) idle anim occasionally tilts the head; the ambient
  music gains a faint three-note motif. ②(2 stacks) NPC dialogue lines
  occasionally render with the final word replaced by "…". ③(3 stacks) roughly
  every 90 s of travel, your character **stops walking for half a second,
  facing north** — toward Black Night, toward the grave. Input resumes as if
  nothing happened.
- **Reveal:** after the third involuntary stop, "Listening III" appears on the
  debuff bar. Orange Wash reveals at any stack. Old Marta reveals it on sight.
- **Cure:** Old Marta's **incuriosity draught** (raven-feather ash + clean well
  water, 5 g or free with her quest); **efface the specific stone you read**
  (Digging-Creature grammar — the cure is undoing the transcription); Transcub
  confession shrine ("I only wanted to know what it said").
- **Mechanics:** −5% crit per stack (attention drifts); at 3 stacks, 10% of
  casts +0.3 s (`cast_stutter`). Stacks cap at 3 in the open world. **Stack 4–5
  exist only inside Chamber Depths / the Orange Fog** and convert to the
  *visible* "Almost Understanding" (severe, from STATUS_EFFECTS' escalation
  tier) — comprehension-death stays a dungeon mechanic, never an ambush.

#### H-02 · Copperbelly — "the yeast dies in you"
- **Source:** coppered wells (every well is drinkable; clean wells give a small
  heal; coppered wells give the SAME heal and a flavor line: *"It tastes
  faintly of coins."* Nothing else. Copper Wells zone, Famine Fields, any
  warm-ground hamlet).
- **Trigger:** drinking from a coppered well. 100%.
- **Incubation:** **3 game-hours.** Nothing happens. The player forgets.
- **Symptoms:** ① the next food/drink item grants NO buff — toast reads
  *"The stew sits in you like river-water."* ② second failure: *"The yeast
  dies in you."* ③ campfire/inn rest bonuses halve.
- **Reveal:** the second failed food buff puts "Copperbelly" on the bar.
- **Cure:** **Hearth Bread** (craftable: clean-water dough + salt, baked at any
  inn hearth — salt-and-fire, the old preservations); an Angel Wings priest
  "blesses the gut" (2 g); or it passes naturally in 24 game-hours ("let it
  work through, and drink from moving water").
- **Mechanics:** `food_block` — all consumable buffs apply zero (hunters_stew's
  `apply_regen_buff` path checks `HiddenFX.food_blocked()`); out-of-combat
  regen −25%. Brutal before an elite; trivial if noticed. Teaches the §7
  environmental-read tutorial (Copper Wells zone IS the lesson).

#### H-03 · Warm-Soled ⚒
- **Source:** warm-ground patches (the canon decal — "warm is wrong").
- **Trigger:** 60 s cumulative standing on warm ground.
- **Incubation:** none — builds silently.
- **Symptoms:** ① footstep VFX steam faintly; in snow zones, snow doesn't
  settle on you. ② NPC bark: *"You're standing where the grass leans."*
- **Reveal:** the first time an Underlanguage-engine mob (entranced,
  thread-shell, Digging Creature) turns toward you from beyond its normal
  aggro ring — nameplate flashes — the bar shows "Warm-Soled."
- **Cure:** wade a clean cold ford (Iron Vein upper stretches); stand in Black
  Night's unnaturally clear air 2 min (the irony is canon — no fog, no signal
  bleed at street level); or simply **swap boots** (the soles carry it —
  unequip/equip different boots clears; the discarded pair gains the flavor
  line *"warm, still"*).
- **Mechanics:** `aggro_mult_family(underlanguage) = 1.3` — the ground reports
  you (composes §5.8). ⚒ Tool-edge: warm-soled players FEEL warm patches
  through the controller — a soft rumble/screen pulse on entry — becoming a
  living detector. The land reads you; you read it back.

#### H-04 · Dust-Reader ⚒ (the trap that is also a compass)
- **Source:** aligned-dust interiors — the three unlooted farmsteads (Copper
  Wells), sealed granaries, Chamber Depths antechambers.
- **Trigger:** looting any container in a room where the dust lies in parallel
  lines (the loot is real and good — that's the bait).
- **Incubation:** 1 game-hour.
- **Symptoms:** ① dust motes drift after the player (VFX). ② scroll/paper
  items in the bag gain an appended tooltip line: *"the corner points
  north-east."* ③ `minimap_drift`: POI pips drift 1–2 px toward the nearest
  live transmission point.
- **Reveal:** examining any inscription while Dust-Read — the tooltip opens
  with *"You realize you already knew where it was."*
- **Cure:** shake out your bags at any waystation (free interact); a hard rain
  while outdoors; Orange Wash then any cure above.
- **Mechanics:** the drift is REAL — following it locates hidden inscriptions
  and buried caches (⚒ the world's best treasure-sense, and every minute of
  using it you are carrying the signal's mail). While Dust-Read, +1 Listening
  stack chance (5%) per inscription you approach. Curiosity compounds.

#### H-05 · The Almost-Word
- **Source:** entranced pilgrims / Listeners (Copper Wells, Listening Steppe,
  Black Night streets) humming their melody fragment.
- **Trigger:** remaining in earshot (~160 px) of an un-aggroed Listener for
  20 s without engaging. (Watching the horror = catching it.)
- **Incubation:** until your next zone transition or inn sleep.
- **Symptoms:** ① on zone load, the zone-name banner renders one letter wrong
  for 2 s, then corrects (`banner_glitch` — "RAVEN HOLLOW" → "RAVEN HOLLOWN").
  ② a single hummed note surfaces in quiet music.
- **Reveal:** the third wrong banner.
- **Cure:** hear a **complete song** — the Bent Oar's musician, any tavern
  performance ("three honest notes push the borrowed one out"); or Transcub
  shrine.
- **Mechanics:** −10% mana_regen (a corner of the mind is busy listening).

---

### FAMILY 2 — WOLVES & CANINES
*(grey/snow/obsidian wolves, mudwolves, starving dogs, war-dogs — cruelty/ecology
engine · green wash · zones 1, 3, 4, 6, 9, 13, 18, 25, 26)*

#### H-06 · Pack-Scent ★ SIGNATURE
- **Source:** wolf packs; specifically surviving a fight where any wolf landed
  3+ hits on you, or being hit by an alpha's charge.
- **Trigger:** as above — blood and fear soak in. Silent.
- **Incubation:** next nightfall (`DayNight.is_night`).
- **Symptoms:** ① distant howls become more frequent (audio layer — the world
  is talking about you). ② wolves you pass visibly bend their patrol paths
  toward your position before aggroing. ③ packs social-aggro from far beyond
  normal range and beeline.
- **Reveal:** the first time a pack social-aggros from beyond 200 px, the bar
  shows "Pack-Scented" with the tooltip *"They marked you three fights ago.
  They have been discussing it since."*
- **Cure:** **boar tallow** rubbed on at a campfire (craftable from boar fat —
  masks the mark; hunters know this); swim any river ford; or **kill the alpha
  that marked you** — its death toast reveals-and-clears (the pack's memory
  dies with it).
- **Mechanics:** canine-family aggro radius ×1.5 and social-aggro call radius
  +40 px against you (composes §5.4/§5.8); the night ×2 multiplier stacks on
  top — night travel through wolf country while Pack-Scented is a running
  fight, exactly the WoW-Classic "should I take the road" decision.

#### H-07 · Limping Prey
- **Source:** any canine hit landed on you while you were below 30% HP.
- **Trigger:** as above. Wolves remember weakness.
- **Incubation:** immediate, silent.
- **Symptoms:** ① swarm canines (starving dogs) prioritize YOU over pets and
  summons, always. ② their pack damage bonus counts one extra packmate against
  you (§5.4). ③ village dogs growl as you pass (`npc_bark` via ambient fauna).
- **Reveal:** the village-dog growl bark names it: *"Even the dogs can smell
  the limp on you."*
- **Cure:** reach 100% HP and stay out of combat 30 s (the limp heals); or a
  priest's blessing (1 g).
- **Mechanics:** teaches the §2 downtime contract — travel bloodied through
  canine country and the world punishes it; eat, breathe, then move.

#### H-08 · Greywolf Tick
- **Source:** looting/skinning greywolf corpses in the Grey Marches (the dying
  forest — things leave it looking for warm hosts).
- **Trigger:** 15% per greywolf loot.
- **Incubation:** 6 game-hours.
- **Symptoms:** ① occasional single scratch sound + a tiny screen shiver while
  idle. ② −5% speed in forest biomes (*"something rides you"*).
- **Reveal:** any campfire rest auto-reveals it — *"You find it behind your
  ear, fat and patient."* (Campfires are the humble reveal instrument for the
  humble effect.)
- **Cure:** the same campfire burns it off (interact, free); Hessik's verdigris
  scrub (2 g).
- **Mechanics:** −5% speed_pct in forest zones. If ignored 24 game-hours it
  matures into the **visible** "Grey Fever" (−10% max hp, herbalist cure 5 g) —
  the STATUS_EFFECTS escalation pattern: hidden things left alone become
  visible worse things.

---

### FAMILY 3 — BOARS & BLOOD-FED FAUNA
*(bog boars, blood-fattened boars of the Gift, field boars, river fauna —
ecology/cruelty engine · green wash · zones 1–3, 8, 11, 23)*

#### H-09 · Gift-Gorged ★ SIGNATURE (the meal that loves you back)
- **Source:** meat looted from **blood-fattened boars** in the Gift — it cooks
  into stew with visibly better numbers (+50% regen on the tooltip). The best
  food in the game. Grown from Great-War dead. That is the bait, and it is canon:
  *"abundance and atrocity sharing a furrow."*
- **Trigger:** eating any Gift-meat dish.
- **Incubation:** 2 game-hours.
- **Symptoms:** ① all food buff durations −50% (the hunger comes back sooner —
  it isn't hunger for food). ② standing in the Gift's red furrows heals 1 hp/s
  — **the wrongness announces itself as comfort, which is worse.** ③ Varcolaci
  field-wardens nod at you like kin; their bark: *"The soil knows its own."*
- **Reveal:** the first Gift-soil heal tick shows "Gift-Gorged" on the bar.
- **Cure:** fast 12 game-hours (eat nothing — the borrowed appetite starves
  first); Transcub shrine (the old god punished cruelty to the self, and this
  is self-fed); or **give bread to a beggar** — a small warm kindness unhooks
  the stone's hunger (thesis cure, free, and the beggar NPCs exist in every
  capital).
- **Mechanics:** `food_block`-lite (durations ×0.5 everywhere), +1 hp/s on Gift
  soil only. Net: a leveling player in Act V eats twice as often or feeds the
  habit. Quietly horrible.

#### H-10 · Bog-Sour
- **Source:** bog water — boar charges that knock you into bog tiles (§5.3
  knockback), or swimming bog water > 10 s (Iron Vein, Copper Wells moors,
  Salt Fens).
- **Trigger:** as above.
- **Incubation:** none.
- **Symptoms:** ① squelching footstep audio persists on dry land. ② flies
  gather when you stand still (VFX). ③ vendors take a visible step back.
- **Reveal:** any vendor interaction barks *"You smell of the Vein, friend"*
  and the bar shows it.
- **Cure:** rain; a clean ford; or 1 g at any inn — *"Hot water. No questions."*
- **Mechanics:** `vendor_mult` ×1.10 (the smell tax), −3% speed until cured.
  The cheapest, most common hidden effect — deliberately: it teaches the
  *pattern* (odd symptom → vendor bark → cheap cure) safely in the starter bog,
  so every later hidden debuff has a learned grammar.

#### H-11 · Tusk-Splinter
- **Source:** surviving a boar charge hit (the 1.5× §5.3 impact).
- **Trigger:** 25% on charge hit taken.
- **Incubation:** immediate, silent.
- **Symptoms:** ① 10% of your dash/charge abilities travel 20% short with a
  wince grunt. ② after 6 game-hours: dash cooldown +1 s.
- **Reveal:** the third shortened dash — *"Something grinds in your hip when
  you move fast."*
- **Cure:** any healer NPC pulls it (5 g, with a satisfying *tink* into a
  bowl); any full-heal-class ability (Lay on Hands tier) pops it free; or it
  works itself out in 24 game-hours (toast: *"It surfaces in the night. You
  keep it."* — grants a `boar_tusk_splinter` junk item worth 3 g. The world
  pays its debts).
- **Mechanics:** dash reliability tax — hits the §6 curriculum where boars ARE
  the dash-teachers. Getting hit by the lesson makes the lesson harder. Dodge.

---

### FAMILY 4 — THE UNDEAD, THREAD-SHELLS & GRAVE-MISTS
*(skeletons, thread-touched dead, Iele shells, graveyard mists — thread/necromantic
engine · blue wash · zones 1, 12–16, graveyards everywhere)*

#### H-12 · Grave-Dim ★ SIGNATURE
- **Source:** graveyard mists at night — the low mist patches in Raven Hollow's
  graveyard, Gravemark Tundra, any barrow field.
- **Trigger:** 30 s inside mist at night = 1 stack; each further 30 s = +1
  (cap 4). Silent — mist is everywhere and pretty.
- **Incubation:** none. It leaves WITH you.
- **Symptoms:** ① minimap dims 5% from the edges inward per stack
  (`minimap_dim`) — at stack 1 nobody notices; at 3 it's undeniable.
  ② discovered-POI pips only render when near. ③ at stack 4, in the Raven
  Hollow graveyard the minimap shows a faint **13th grave-row that is not
  there** (pure dread; interacting with the real ground where it "is" finds
  nothing — mostly).
- **Reveal:** stack 2's dim is designed to be caught; the bar shows "Grave-Dim"
  the first time the player opens the map while dimmed. Equipping any lit
  lantern (incl. torch off-hands) also reveals it instantly.
- **Cure:** spend a dawn outdoors (be outside 05:00–07:00 `DayNight` — dawn
  scours the eyes); light a shrine candle at any chapel (1 g); **the
  Gravekeeper's Lantern** (ITEM_PROGRESSION Act-I set trinket) grants
  immunity — *"It gutters when you pass the new rows"* now pays off
  mechanically: Vasile's lantern already knew.
- **Mechanics:** minimap brightness/vision radius reduced per stack; the map
  becomes untrustworthy exactly where the dead are thickest. Navigation dread
  in the WoW-Classic corpse-run register.

#### H-13 · Thread-Crossed
- **Source:** the visible blue Thread filaments (Threadlands, Black Night
  streets). They have no collision. Walking through one feels like nothing.
- **Trigger:** crossing a filament. 100%. Silent.
- **Incubation:** 1 game-hour.
- **Symptoms:** ① your pets/summons occasionally stop for 1 s and face north.
  ② your ability animations play one frame late (0.1 s input→anim lag,
  cosmetic only — combat timing unaffected; it just *feels* wrong). ③ at
  night, enemies you kill stand back up after 3 s — take one step — and fall
  again. No gameplay effect. Maximum horror.
- **Reveal:** the first re-standing corpse. Bar: "Thread-Crossed" — *"Something
  up north filed a copy of you."*
- **Cure:** cross running water (severs the filament — folk-canon); a priest
  cuts it (blue under detection — the Blue Wash shows it snaking off you,
  3 g for wash + free chapel cut); or petition a Council clerk in Black Night
  to **re-file you as living** (free, one humiliating dialogue: *"Name.
  Heartbeat. …You're certain?"*).
- **Mechanics:** pet/summon uptime −10% (the pauses). **Necromancer exception:**
  summons last +10% longer instead — the Thread likes them. Dual-edged by
  class, which the class fantasy earns.

#### H-14 · Twelfth-Counted ⚒
- **Source:** the rows of twelve — standing still among the still Iele of Black
  Night's market for >10 s, or lingering in a strigoi execution-row vignette
  (the 12 boot-prints).
- **Trigger:** as above. You were counted.
- **Incubation:** none.
- **Symptoms:** ① when you stand still >8 s anywhere, your character
  straightens to a subtle attention posture. ② NPC bark: *"Didn't see you
  there."* ③ enemies path AROUND you while you stand still.
- **Reveal:** the first enemy that walks past you at rest — bar shows
  "Twelfth-Counted": *"You read as one of the still. Try not to think about
  what the count is for."*
- **Cure:** be counted correctly — any capital census clerk records you (1 g);
  or physically break a row (kick apart a boot-print vignette — minor karma
  bark from strigoi NPCs).
- **Mechanics:** ⚒ standing still 8+ s = Underlanguage/undead-family mobs
  treat you as neutral until you move (a poor man's stealth — and the Vigil of
  the Twelve set's lore, *"mistaken for one of the still,"* now has a system
  rhyme: wearing 2+ set pieces halves the 8 s). Cost: vendor/quest NPCs also
  fail to notice you — you must jiggle to open shops. Players WILL keep this
  one on purpose. Let them.

#### H-15 · Kerb-Read (cursed-carry)
- **Source:** carrying the **Gravemark Kerbstone** epic trinket
  (ITEM_PROGRESSION: *"Do not read it aloud. Do not read it."*) or any looted
  Underlanguage-carved kerb item.
- **Trigger:** 100% while in bag or equipped. Hidden.
- **Incubation:** 1 game-hour of carry.
- **Symptoms:** ① item tooltips in your bag occasionally reorder their stat
  lines (order is emerging). ② flavor texts gain a final line: *"…and it is
  owed."* ③ loot-window gold rows trend toward multiples of 12.
- **Reveal:** Orange Wash; or any Anara-lineage translator NPC recoils
  mid-dialogue and names it.
- **Cure:** stop carrying it — bank it in a **lead-lined box** (buyable
  container, 15 g, Angel Wings only — the Lead Vault's discipline retailed);
  or accept it: it is the item, and the item is worth it.
- **Mechanics:** −8% gold from all loot (the stone's tithe). The epic's stats
  already price this in implicitly — this doc makes the whisper real. First
  deliberate "carry cost" item; sets precedent for Act VI cursed relics.

#### H-16 · Mist-Wept
- **Source:** fighting undead in rain/mist weather — their dust mixes with the
  wet and gets into everything.
- **Trigger:** 5+ undead kills during active rain/mist (`weather.gd` state).
- **Incubation:** none.
- **Symptoms:** ① your damage numbers on undead kills render slightly grey.
  ② undead loot windows always contain one extra bone junk item (they
  recognize kin — a few extra copper per kill, small bait). ③ priest NPCs
  frown as you approach.
- **Reveal:** the first priest heal: *"Child, you're wearing more of the dead
  than a gravedigger."*
- **Cure:** chapel washing (free); or 10 minutes of daytime in the Western
  Lowlands (thinnest fog on the map — canon; the sun still works there).
- **Mechanics:** healing received from priests/shrines −15% while Mist-Wept.
  The extra junk income vs. weaker chapel support is a real (tiny) choice.

---

### FAMILY 5 — STRIGOI & LISTENERS (BLESTEM)
*(strigoi enforcers, listeners, the walled, cave-strigoi — cruelty/intelligence
engine · violet wash · zones 17–21)*

#### H-17 · Marked ★ SIGNATURE
- **Source:** a **strigoi listener's touch** — their signature attack is a slow
  open-palm reach that does almost no damage. Players read it as a whiffed
  grab. It was never an attack. It was a *filing*.
- **Trigger:** the touch landing. 100%. Utterly silent.
- **Incubation:** none — the information starts moving immediately.
- **Symptoms:** ① Blestem-affiliated vendors **overcharge you 15%** — no bark,
  no tell, the prices are simply higher (sharp players comparing notes across
  vendors is the discovery fantasy). ② strigoi patrols "happen" to path toward
  your position. ③ Blestem gate guards greet you **by name** before you have
  given it. ④ assassin ambush events unlock on the Whisper Passes.
- **Reveal:** a Lower Market informant offers, unprompted: *"Five gold and
  I'll sell you what they know about you."* Paying reveals the debuff and its
  full dossier — **information as the hard currency**, canon made mechanical.
  Violet Wash also reveals.
- **Cure:** **buy your file and burn it** (Lower Market transaction, 25 g —
  information is priced like the hard currency it is); **kill the listener
  that marked you** (a tracker NPC can name it for a favor; it remembers you —
  it is the only listener that turns to face you across a zone); or leave the
  East entirely for 48 game-hours (marks go stale; Cazimir does not pay for
  cold files).
- **Mechanics:** `vendor_mult` ×1.15 at strigoi-faction vendors;
  strigoi-family mobs +20% aggro radius and receive a pathing hint toward
  your position every 30 s. The whole city is quietly tilted against you and
  the game never says so. Peak Blestem.

#### H-18 · Overheard
- **Source:** the walls that listen. Completing dialogues inside Blestem
  interiors.
- **Trigger:** 3 indoor dialogues within Blestem.
- **Incubation:** none.
- **Symptoms:** ① a fourth dialogue option appears occasionally, rendering
  only as **"…"** (the wall, waiting). ② faint whispering under UI click
  sounds.
- **Reveal:** *choosing* the "…" option (curiosity!) reveals Overheard — and
  applies +1 Listening stack (H-01). The families compose; the trap has a
  trapdoor.
- **Cure:** conduct your Blestem business outdoors (3 consecutive outdoor
  dialogues auto-clears); or pay the Riddler's Quarter to "re-route your echo"
  (10 g).
- **Mechanics:** quest-reward negotiation options inside Blestem lock to the
  lowest tier — they already know your bottom line.

#### H-19 · Lichen-Lit ⚒
- **Source:** carrying luminous lichen (Blestem's export — craft reagent) or
  traversing Lichenreach without a torch. The lichen cultures you.
- **Trigger:** 2 game-hours of carry / cave time.
- **Incubation:** included above.
- **Symptoms:** ① in darkness you faintly glow — 5% luminance, imperceptible
  until deep dark. ② cave mobs (bats, cave-strigoi) aggro at +40% radius in
  the dark. ③ the walled whisper as you pass their sections of wall.
- **Reveal:** entering deep-dark, a bat swarm turns toward you *as one* —
  bar shows "Lichen-Lit."
- **Cure:** ash scrub at a campfire (free); 2 minutes of real daylight kills
  the culture.
- **Mechanics:** cave stealth gone; ⚒ but you can read cave interactables and
  loot without torchlight (a hand that glows needs no lamp), freeing the
  off-hand slot in Lichenreach. Miners' folk-wisdom made into a build choice.

#### H-20 · The Riddle Set
- **Source:** the Riddler's Quarter — answering any riddle NPC **wrong**.
- **Trigger:** one wrong answer. The Quarter keeps score.
- **Incubation:** none.
- **Symptoms:** ① doors in the Riddler's Quarter occasionally open one room
  off (short teleport, disorienting, never soft-locks). ② your world map of
  Blestem opens rotated 90°, righting itself after 2 s (`map_rotate`).
- **Reveal:** the map rotation is unmistakable — bar shows "The Riddle Set:
  the Quarter is still asking."
- **Cure:** answer any riddle correctly (the Quarter is satisfied); or run
  Cazimir's clerks a favor-errand to be "resolved."
- **Mechanics:** minimap disabled inside the Riddler's Quarter dungeon while
  set (the level IS the antagonist — WORLD_PLAN's dungeon thesis, sharpened).

#### H-21 · Blood-Tithed
- **Source:** strigoi enforcer melee — each hit takes a little more than the
  damage number says. The numbers look normal. The ledger is elsewhere.
- **Trigger:** cumulative: 5 / 10 / 15 enforcer hits taken (lifetime counter,
  any period — they are patient).
- **Incubation:** thresholds above.
- **Symptoms:** ①(5) max hp −3% — invisible among gear swaps. ②(10) −6%, and
  your reflection in water tiles renders paler (palette-swap shader).
  ③(15) −10%, and your footsteps stop making sound.
- **Reveal:** the character sheet renders max HP in a dull red once tithed
  (sharp-eye tell); any inn **mirror** interactable reveals it fully — *"You
  are less than you were. Someone is more."*
- **Cure:** rare-cooked meat + a full night's inn sleep (folk transfusion,
  ~3 g total); a priest's transfusion rite (10 g); or take it back — **kill 12
  strigoi** (rows of twelve; the tithe returns with interest: +2% max hp for
  1 game-day on completion).
- **Mechanics:** max-hp percentage theft, capped at −10%. Composes with
  CHARACTER_STATS' hp pools multiplicatively (applied after gear).

---

### FAMILY 6 — VARCOLACI & THE FORGE (SANGEROASA)
*(varcolaci hunters/pit-bosses, ash-hounds, slag-walkers, forge-thralls —
cruelty engine · green wash · zones 22–26)*

#### H-22 · Moon-Fever ★ SIGNATURE
- **Source:** a **varcolac bite landing at night** (attack tag checked against
  `DayNight.is_night`).
- **Trigger:** as above. The bite heals like any wound. Nothing shows.
- **Incubation:** until the **next nightfall.**
- **Symptoms — the surge (this is a hidden BUFF first):** ① at nightfall:
  +15% damage, +10% speed, a faint red vignette at screen edges, heartbeat
  audio under the music. It feels *wonderful*. **The wrongness announces
  itself as comfort, which is worse.** The surge runs two nights. No icon.
  No toast. Just you, stronger, in the dark, and a small voice asking why.
- **The crash:** dawn after the second night — −20% damage, −15% speed, hp
  regen halved, for one full game-day.
- **Reveal:** the crash IS the reveal: "Moon-Crash" appears with the full
  tooltip — *"Two nights ago, under the moon, something lent you its blood.
  It has come to collect the interest."* (Green Wash reveals the fever early,
  during the surge — the informed player's edge.)
- **Cure:** **wolfsbane draught** from Sangeroasa herbalists (5 g — they stock
  it for their own; a varcolac city knows fever management better than anyone);
  a shrine of the old hunt (Basaltfang ridge-shrines); or ride it out — the
  crash clears naturally at the next dusk. Getting re-bitten during the surge
  **stacks the crash, not the surge.** The moon lends once.
- **Mechanics:** net power over the full cycle is negative (2 nights ×
  moderate surge < 1 day × heavy crash + halved regen), so exploiting it
  requires actually noticing and timing content into the surge windows —
  which is the fantasy: the player who plans around their own affliction is
  living in Sangeroasa properly. Anara — "the Moon-Whisperer" — has a
  questline hook here (she can teach a controlled third night, Act V).

#### H-23 · Forge-Deaf
- **Source:** the hundreds of hammers. >5 min inside Sangeroasa's forge
  districts.
- **Trigger:** dwell time. Silent — hearing loss always is.
- **Incubation:** none.
- **Symptoms:** ① high frequencies roll off; the wind layer disappears
  (`audio_duck_high`). ② you stop hearing **enemy windup audio cues** —
  visual telegraphs unaffected (fairness: §5.1 tells are audio+visual;
  Forge-Deaf removes exactly one channel). ③ when all the hammers stop for a
  count of three — canon vignette — you hear the silence as a deafening
  pressure + screen shake. Everyone else just looks uneasy.
- **Reveal:** the count-of-three event; or any tavern musician: *"Friend,
  you're nodding on the off-beat."*
- **Cure:** clears naturally after 24 game-hours away from the forges;
  **beeswax plugs** (1 g, Sangeroasa vendors) worn BEFORE entering prevent it
  entirely — the prevention economy in one copper-cheap item.
- **Mechanics:** `audio_mute_windup`. Fighting §5.1 heavy swings and §5.2
  casters on visual tells alone is a real skill check — Sangeroasa's zones
  quietly train pure-visual play.

#### H-24 · Slag-Bound ⚒
- **Source:** looting slag-walker corpses (dead workers, still working) —
  3+ loots.
- **Trigger:** as above. Something in the slag recognizes a fellow laborer.
- **Incubation:** none.
- **Symptoms:** ① your hands glow faintly ember at night (VFX on hand slots).
  ② 5% of weapon swings trail ember particles. ③ the **Debt Pit ledger**
  (interactable vignette) gains a new line: your name. Labor-days owed:
  *blank*.
- **Reveal:** reading the ledger and finding your name. (Players WILL read
  the ledger. Curiosity is the vector.)
- **Cure:** pay the "administrative correction" at the ledger (20 g — the Pit
  has a clerk; of course it has a clerk); or 48 game-hours in a cold northern
  zone lets the hands cool.
- **Mechanics:** ⚒ +1 ore quality when mining Sangeroasa nodes (the slag
  teaches your hands); pit-boss-family mobs treat you as an escaped worker —
  +25% aggro and an on-aggro bark: *"Back to the Pit."* Miner builds will
  keep it and fight for it. Correct.

#### H-25 · Ash-Lunged
- **Source:** the Ashvents during ashfall weather, unmasked.
- **Trigger:** 60 s cumulative in ashfall without a mask item.
- **Incubation:** builds over exposure.
- **Symptoms:** ① dash/sprint abilities produce a small cough grunt.
  ② out-of-combat regen delay 5 s → 8 s (composing §9.2 — the breather takes
  longer to start). ③ your breath becomes visible even in warm zones —
  wrongness inverted; in Draconia, being cold inside is the tell.
- **Reveal:** any herbalist: *"Breathe for me. …How long were you in the
  vents?"* Or stage-3's visible breath.
- **Cure:** honey-milk at any inn (2 g); Hessik's expectorant (3 g); 24
  game-hours in the clean western air.
- **Mechanics:** `regen_delay +3 s`. Small, constant, exactly the kind of tax
  you only notice when someone asks how long you've been tired.

#### H-26 · Debt-Scented
- **Source:** killing a Bloodroad convoy **paymaster** and taking its coin.
  The coin is marked. All of it.
- **Trigger:** marked gold entering your purse. Hidden while any remains.
- **Incubation:** none.
- **Symptoms:** ① war-dog packs track you across zone lines (hunting-party
  spawns on Bloodroad roads). ② convoy ambush events while traveling.
  ③ vendors weigh your coins twice.
- **Reveal:** the first hunting-party leader: *"He carries the pay-chest
  shine."*
- **Cure:** **spend it** — marked gold launders as it circulates; the first
  ~30 g spent clears the scent (the economy as cure); drop it (gold-drop
  interact — walking away from money in Sangeroasa is a statement); or a
  Morven-style fence cleans the lot for 20%.
- **Mechanics:** Bloodroad/Basaltfang random encounter rate ×2 while carrying
  marked gold. Loot the arsenal road, pay the arsenal road.

---

### FAMILY 7 — THE DIGGING CREATURE & THE UNDER-THINGS
*(the Digging Creature, tunnel networks, bats, cave collapse — sub-terrestrial
engine · violet wash · zones 3, 4, 5, 14, 18, 19)*

#### H-27 · Under-Hearing ★ SIGNATURE
- **Source:** surviving a **Digging Creature scratch** (its non-lethal swipe —
  the throat-pull it saves for marks, the scratch it gives witnesses), or
  falling into a collapse-tunnel in the Copper Wells.
- **Trigger:** as above.
- **Incubation:** 1 game-hour.
- **Symptoms — the muffled layer grows:** ① faint underground scraping when
  you stand still. ② surface audio (birds, wind, music) ducks −20% while a
  low rumble layer fades in — **the muffled audio layer grows.** ③ you can
  *hear the under* — the rumble intensifies over buried tunnels and
  inscription chambers (⚒ human sonar; buried content becomes findable by
  ear). ④ sometimes you hear your own footsteps arrive a half-second after
  you stop.
- **Reveal:** stage ②'s duck is unmistakable — "Under-Hearing" appears.
  Violet Wash reveals instantly (sub-terrestrial = violet, canon detection
  grammar).
- **Cure:** a priest "closes the ear" (free at chapels); wax in both ears
  (1 g — removes the tool-edge too); or **let it mature**: 24 game-hours at
  stage ④ and it fades on its own, leaving a permanent character-sheet
  flavor line — *"an ear for the deep"* — and nothing else. Some scars are
  souvenirs.
- **Mechanics:** audio remix per stage; −5% crit while at stage ②+ (the
  distraction); the ⚒ sonar at stage ③ is the game's only detector for
  unmarked tunnel content. The Digging Creature is canon's dread-teacher —
  its survivors become dowsers. *You read it, so now it reads you back —
  and you can hear it reading.*

#### H-28 · Grave-Dirt Nails
- **Source:** digging at Digging-Creature mounds bare-handed (the "Dig"
  interact without a spade tool).
- **Trigger:** 2+ bare digs.
- **Incubation:** none.
- **Symptoms:** ① chest/container opening animations +0.5 s (dirt in the
  nails). ② high-station NPCs refuse handshake dialogue branches (a courtier
  bark in Angel Wings). ③ +5% basic-attack damage vs. burrower/earthen
  enemies — your hands learned something down there.
- **Reveal:** the courtier's refusal names it.
- **Cure:** inn bath (1 g). Note: Vasile (gravekeeper lineage NPCs) and any
  Necromancer-class vendor *approve* — small reputation barks. Dirt is a
  dialect.
- **Mechanics:** as listed. Tiny, characterful, nearly free.

#### H-29 · Bat-Kissed ⚒
- **Source:** bat swarms (Lichenreach, Eastern Ridges) — 10+ cumulative swarm
  hits.
- **Trigger:** as above.
- **Incubation:** next cave entry.
- **Symptoms:** ① in caves, your darkness vignette shrinks — you see
  **better** underground (feels like a blessing; the bait again). ② in full
  daylight, a slight white-out squint at noon and −5% crit outdoors by day.
- **Reveal:** the noon squint — *"The sun has opinions about what you've
  been letting bite you."*
- **Cure:** herbalist eye-wash (2 g) removes both halves; or keep it — it is
  an honest trade.
- **Mechanics:** cave vision radius +20% / daylight outdoor crit −5%. A
  permanent-until-cured spelunker's tradeoff. Fairness cap respected: both
  sides are mild.

#### H-30 · Tunnel-Turned
- **Source:** >10 min underground without surfacing (Chamber Depths,
  Lichenreach, Coldharbor).
- **Trigger:** dwell. The under has its own norths.
- **Incubation:** on surfacing.
- **Symptoms:** ① the world map opens facing the wrong cardinal, righting
  itself in 2 s. ② your idle animation glances downward. ③ fast-travel
  confirmations flash the *adjacent* node's name for half a second before
  correcting.
- **Reveal:** the map rotation.
- **Cure:** any waystation coachman "sets you right" (free dialogue — coachmen
  have seen it a hundred times); or sleep at an inn.
- **Mechanics:** −2% speed for 1 game-hour after surfacing ("the legs
  disbelieve the sky"); pure texture otherwise. The cheapest dread in the doc
  and the one streamers will clip.

---

### FAMILY 8 — THE FINALIZED & THE COLLECTOR'S COAST
*(the finalized, debt-wraiths, canal-things, Morven agents, collection-agents —
bureau engine · orange wash · zones 27–40)*

#### H-31 · Collected ★ SIGNATURE — the Finalized's Chill
- **Source:** a **finalized's chill touch** — their slow, cold grab. Low
  damage. High everything else.
- **Trigger:** the touch landing. Silent. A stamp sound plays so quietly it
  reads as UI noise.
- **Incubation:** none. The account opens immediately.
- **Symptoms:** ① your **gold counts down 1 per real minute** — each tick a
  faint stamp. The HUD gold readout is the symptom surface: most players
  catch it within minutes, some catch it at the vendor, all of them feel the
  specific horror of *checking their wallet twice*. ② the character-sheet
  gold readout occasionally renders the word **"collected"** for a single
  frame. ③ after 30 g lost, a **debt-tablet bearing your name** appears in
  your bag — quest item, undroppable, flavor: *"Account open. Standard
  terms."*
- **Reveal:** opening the bag and seeing the tablet flips the bar icon on:
  "Collected." (If somehow unnoticed, the tablet "matures" at 0 g — the
  drain never goes negative; instead collection-agents ambush, which is its
  own reveal.)
- **Cure — three lore-apt outs:**
  1. **Crack your tablet** (the Kriggar grammar): carry it to the Anchorfall
     foundry and pay to have it mis-stamped — fee = exactly what you've lost
     so far + 10 g. The system will always sell you an error at cost-plus.
  2. **Prove a discrepancy:** kill the specific finalized that touched you
     (it holds your line item; a Records clerk — Marrow Pell — will sell you
     its location, 5 g, because of course the dead broker sells the dead).
  3. **The thesis cure:** give 5 g freely to the Last Hearth orphanage or any
     beggar — *a debt freely given cannot be collected.* Cheapest, easiest,
     and the game never tells you it works. Word of mouth carries it. That
     is the point.
- **Mechanics:** `gold_drain 1/min` (real time — dread should not pause when
  you idle in a menu; cap: stops at 0, never negative); composes with the §7
  gold economy where ~25–40 g/hr is a bracket-30 farming rate — the drain is
  60 g/hr: strictly *worse than farming*, must be dealt with, never
  bankrupting. Act VI's thesis in one debuff: existence, invoiced.

#### H-32 · Filed
- **Source:** **reading** any looted debt-tablet (the Examine action — the
  text is fascinating; curiosity, vector, etc.).
- **Trigger:** one read.
- **Incubation:** none.
- **Symptoms:** ① quest-log entries gain small ledger-stamp icons; completed
  quests re-sort to the top under a header that reads "closed." ② NPCs whose
  quests you completed greet you with one line of flat clerk cadence before
  returning to themselves: *"Account acknowledged. — sorry, I don't know why
  I said that."*
- **Reveal:** an Archive clerk compliments your filing, unprompted.
- **Cure:** destroy any one quest item (tear a page — sacrilege that unfiles
  you; pick the item carefully); or the Blind Seer **unreads** you (free, once
  per act — he takes one look: *"Already collected. Why is it still
  walking?"* — and whatever he sees, he refuses it on your behalf).
- **Mechanics:** quest XP −10% (closed accounts pay out less — composes with
  `xp_system.gd` quest grants). The Act VI leveling tax with a story attached.

#### H-33 · Canal-Wet ⚒
- **Source:** swimming Greyhollow's canals, or a canal-thing's pull.
- **Trigger:** as above.
- **Incubation:** none.
- **Symptoms:** ① black water keeps dripping from you long after you dry —
  and the beads **crawl toward the docks** (canon: *"black water beads off
  them and crawls back toward the docks"* — the Coldharbor Greaves knew).
  ② gaslights dim as you pass beneath them. ③ the finalized **surface to
  watch you pass.** They do not attack. That is worse.
- **Reveal:** stage ②'s lamp-dimming.
- **Cure:** sit at the Last Hearth's actual hearth for 60 s (the one warm
  refuge earns its name mechanically); or a salt-scrub at the Grey Piers
  (1 g).
- **Mechanics:** ⚒ at stage ③, finalized-family mobs don't aggro you — the
  water has already claimed you, and they respect a prior lien (traversal
  tool through the Drowned Quarter); but healing received −10% (something of
  you is owed downstream). Players will deliberately swim the canals to farm
  the pacifism. The canals will remember that.

#### H-34 · Morven-Noticed
- **Source:** Morven surveillance — committing any crime-flag act in Morven
  Reach, or speaking with 3+ informants.
- **Trigger:** as above. Somebody wrote it down.
- **Incubation:** none.
- **Symptoms:** ① **chalk marks appear on walls near where you slept** — a
  handprint with a Morven catalogue mark around it (the canon vignette,
  personalized). ② your fast-travel arrivals are *expected*: a figure watches
  you disembark, then leaves. ③ Greyhollow vendors restock precisely the
  categories you bought last — and price your favorite +10%.
- **Reveal:** buying your own file from a Morven fence (10 g — the H-17 rhyme
  a thousand years matured; Sabira's inheritance, "poor bastards" and all).
- **Cure:** become boring — 24 game-hours with no crimes and no informant
  contact; or the file-burn favor-quest.
- **Mechanics:** 10% Morven-blade ambush after each fast-travel;
  `vendor_mult` +10% on your most-purchased item category (computed from
  purchase history — surveillance capitalism, the medieval build).

#### H-35 · The Orange Note (severe · the accelerant)
- **Source:** the Orange Fog (zone 39) — lingering >60 s unprotected in the
  Deadheart-signal wastes.
- **Trigger:** dwell. The fog is the signal, self-writing.
- **Incubation:** 6 game-hours.
- **Symptoms:** ① exactly **one note** of the three-note melody hums under all
  music, in every zone, forever, until cured. Players who have heard the
  motif in H-01/H-05 will recognize the escalation: those were borrowed
  fragments; this one is *addressed to you*. ② every OTHER hidden effect you
  carry advances one stage. ③ your Listening stacks (H-01) accrue at double
  rate.
- **Reveal:** Orange Wash ONLY — or a seer-lineage NPC screams on seeing you
  (the Constantine reflex).
- **Cure — the hardest in the doc, deliberately:** ① the Blind Seer's
  questline (a dead man's handshake — only the read-only can take the note
  out of you); or ② **transmit, don't receive**: at the Archive, write one
  specific, true, unimportant memory of your own onto a blank tablet — a
  chipped cup, an aching knee, a name — and the note has nothing smooth left
  to hold onto (mini-quest; the game asks the player to type/choose the
  memory; specificity as a game verb).
- **Mechanics:** meta-debuff — all hidden-effect stage timers run ×2 while
  carried. The endgame zone's ambient threat is that it makes every other
  whisper in this document louder. Cap: it cannot push H-01 past its
  open-world stack cap; comprehension-death remains dungeon-only (Law 1).

---

## 7. WIRING TABLE — who applies what (zone_defs / enemy cfg)

New optional enemy-cfg key (§2): `"applies_hidden": "<id>"` on the relevant
attack. Environmental triggers ride interactables in zone layout data.

| Applier | Effect(s) | Zone(s) / table rows |
|---|---|---|
| Live inscription stones (interactable) | H-01, (H-04 rooms nearby) | Stonepath, Copper Wells, Chamber Depths, all wild zones (WORLD_PLAN network) |
| Coppered wells (interactable) | H-02 | Copper Wells, Famine Fields, warm-ground hamlets |
| Warm-ground patches (area) | H-03 | every zone's Underlanguage vignettes |
| Aligned-dust containers | H-04 | Copper Wells farmsteads, sealed interiors |
| Entranced Pilgrim / Villager (`skeleton_mage` caster rows) | H-05 proximity | Vetka, Copper Wells, Listening Steppe |
| Wolf packs / alphas (`wolf` stalker rows) | H-06, H-07 | Iron Vein, Copper Wells, Stonepath, Marches, Threadlands, Basaltfang |
| Greywolf corpses (loot) | H-08 | Grey Marches |
| Gift boar meat (consume) | H-09 | The Gift |
| Bog water (area) / boar charge | H-10, H-11 | Iron Vein, Copper Wells, Salt Fens; all `charger` rows |
| Graveyard mists (area, night) | H-12 | Raven Hollow graveyard, Gravemark |
| Thread filaments (area) | H-13 | Threadlands, Black Night |
| Rows-of-twelve vignettes | H-14 | Black Night still market, Blestem alleys |
| Gravemark Kerbstone (item carry) | H-15 | Gravemark world epic |
| Undead kills in rain (`weather.gd`) | H-16 | any undead row + rain |
| Strigoi listener touch attack | H-17 | Blestem, Whisper Passes (`caster`/`duelist` listener rows) |
| Blestem indoor dialogue | H-18 | Blestem interiors |
| Lichen carry / dark caves | H-19 | Lichenreach |
| Riddle NPCs (wrong answer) | H-20 | Riddler's Quarter |
| Strigoi enforcer melee (`orc_warrior` guarded rows) | H-21 | Blestem, Eastern Ridges |
| Varcolac bite at night | H-22 | all varcolaci rows, zones 22–26 |
| Forge district dwell | H-23 | Sangeroasa |
| Slag-walker loot | H-24 | Ashvents, Sangeroasa |
| Ashfall weather dwell | H-25 | Ashvents |
| Convoy paymaster loot | H-26 | Bloodroad |
| Digging Creature scratch / collapse-tunnels | H-27 | Iron Vein (rare), Copper Wells, Listening Steppe |
| Mound digs (bare-handed) | H-28 | digging-creature tunnel zones |
| Bat swarms | H-29 | Lichenreach, Eastern Ridges |
| Underground dwell | H-30 | all dungeon/cave zones |
| Finalized chill touch | H-31 | Drowned Quarter, Finalized Fields, Coldharbor |
| Debt-tablet read | H-32 | all Continent-2 loot |
| Canal swim / canal-thing pull | H-33 | Greyhollow, Canal Maze |
| Morven Reach crime / informants | H-34 | Morven Reach, Greyhollow |
| Orange Fog dwell | H-35 | The Orange Fog |

**Coverage audit:** 35 effects · 8 families · 8 SIGNATURES, one per family:
H-01 The Listening (the Land That Reads), H-06 Pack-Scent (Canines), H-09
Gift-Gorged (Boars & Blood-Fed Fauna — the meal-that-loves-you-back is that
family's most canon-dense expression: the Gift, abundance-and-atrocity in one
furrow), H-12 Grave-Dim (Undead & Mists), H-17 Marked (Strigoi), H-22
Moon-Fever (Varcolaci), H-27 Under-Hearing (Burrowers), H-31 Collected (the
Finalized). ⚒ tool-edged: 8 of 35. Acts: I–II carry 13 entries, III–IV carry
11, V–VI carry 11 — every act's zones ship with hidden weather.

---

## 8. TUNING & ANTI-FRUSTRATION

- **Budget:** at-level, the worst single hidden effect costs less than one
  gear-slot downgrade (~10% of one stat, or a systemic tax with a ≤25 g exit).
  Two simultaneous hidden effects cost less than fighting one mob-level up.
- **The 40-second rule, inverted:** WORLD_PLAN mandates an engagement every
  40 s of travel; hidden-effect *symptoms* count as engagements. A carried
  symptom (howls, drips, hums) is ambient content the zone doesn't have to
  spawn.
- **New-player ramp:** Acts I–II hidden effects are cheap, loud, and
  fast-revealing (H-10 Bog-Sour is the tutorial; H-02 teaches the food
  economy; H-01 is the canon centerpiece with the gentlest mechanical touch).
  The expensive dread (H-31, H-35) is endgame, where players have the gold
  and the grammar.
- **Never gate progress:** no hidden effect blocks quest turn-in, travel, or
  equip. They tax, tilt, whisper, and lie — they never wall.
- **Streamer test:** every SIGNATURE has one clip-able moment (the north-stop,
  the beeline pack, the 13th grave-row, the guard who knows your name, the
  surge-crash dawn, the footsteps that arrive late, the wallet that ticks).
  Surprise is the mandate; the clip is the proof.

---

## 9. IMPLEMENTATION CHECKLIST

1. `game/hidden_effects.gd` autoload: CATALOG const (35 entries, §2 shape),
   `apply/tick/reveal/cure/stat_mods/aggro_mult/food_blocked`, save dict.
2. STATUS_EFFECTS registry: accept `hidden` + `revealed` flags; debuff bar
   skips `hidden and not revealed`; shared reveal sting + auto-tooltip.
3. `enemy.gd`: `"applies_hidden"` cfg key on attack payloads (listener touch,
   varcolac bite w/ `DayNight.is_night` check, finalized chill, digging
   scratch, enforcer hit counter); aggro check reads
   `HiddenFX.aggro_mult(family)`.
4. `player.gd`: stat-mods read in the equipment path; `walk_interrupt_north`
   movement intercept; gold-drain tick; cast_stutter.
5. `crafting.gd`: consume path checks `food_blocked()` / duration mult; new
   recipes (Hearth Bread, boar tallow, washes ×4, wolfsbane, honey-milk,
   beeswax, eye-wash) — all follow the recipe-scroll drop pattern.
6. `minimap.gd`: `minimap_dim`, `minimap_drift` hooks. Travel map:
   `map_rotate`, `banner_glitch`.
7. Vendor UI: `vendor_mult` per-faction/per-category. `xp_system.gd`:
   quest-XP mult.
8. Audio: "Symptom" bus + low-pass; windup-SFX gate in `enemy.gd`.
9. Interactables batch: wells (drink), inscriptions (examine), mounds (dig),
   ledger, census clerks, mirrors, baths, hearth-sit, file-fences, tablet
   mis-stamping — each a small `npc_data.gd`/prop dialogue.
10. Death recap: append revealed-on-death hidden effects.
11. QA gates: symptom-channel collision test (no two active effects share a
    channel — §9 arbiter); Act I playthrough must organically catch H-10 and
    H-02; Green Wash must reveal H-22 during surge; H-31 drain must stop at 0.

---

*The land reads you. The teeth are just the bill — these are the interest.*
