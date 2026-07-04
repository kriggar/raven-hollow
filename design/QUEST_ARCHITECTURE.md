# RAVEN HOLLOW — CAMPAIGN ARCHITECTURE (the spine)
**~1000 interconnected quests · 40 zones · level cap 60 · slow classic pacing · the Bloodstone as the Lich King**

Sources of truth: `c:/Users/vstef/Desktop/rpg/_lore_extract.txt` (Parts II–XI), `WORLD_PLAN.md` (40 zones,
travel graph), `scripts/quest_defs.gd` + `scripts/quests.gd` (shipped quest schema/engine v1),
`scripts/xp_system.gd` (shipped XP model), `scripts/npc_data.gd` (cast), `scripts/class_defs.gd`
(7 classes: warrior, rogue, mage, paladin, necromancer, rookwarden, druid).

Tone law (canon, Part I/XI): *dread is ambient, no quest offers a clean win, the best outcome usually
costs the least of someone else.* Tonal mix mandate: WoW-Classic — heavy next to creepy next to
cheerful, so each makes the others land.

---

## 0. THE VILLAIN'S GRAMMAR (read this before writing any quest)

The main villain is **the Bloodstone** — the buried world-machine under Black Night. It is not a
person. It never has a face, a model, or a health bar until the Pit. It ARRANGES events and speaks
only through media that already cost someone something. Canon rules (Part II/IV, "the
inscription-stone network"):

- **Curiosity is the vector.** Reading/copying/speaking an inscription seeds a new transmission
  point. Quests must repeatedly reward, then punish, the player's own investigative reflex.
- **Execution warms the world.** A live node = warm ground, coppered wells, dead yeast, dust in
  parallel lines, people "listening". These five symptoms are the villain's *presence animation*.
- **Comprehension kills.** Understanding an inscription is erasure. The Courier died of it —
  no wound, clean fingernails, satchel still sealed.
- **Detection grammar** (alchemical sight): blue = necromantic · violet = sub-terrestrial ·
  green = thermal (a stone waking) · **shifting orange = live signal** (the color of the villain).

### The five villain touch-forms (the "Lich King toolkit")
Every scripted villain contact in the game is one of exactly five forms, tagged in data
(`villain_beat.kind`) so cadence can be audited:

| kind | What it looks like | Canon anchor |
|---|---|---|
| `symptom` | Environmental wrongness only — warm lane, copper well, aligned dust. No words. | Vetka ES beats (Part XI §2) |
| `whisper` | One Underlanguage sentence through a borrowed mouth/medium — an entranced NPC, a wall, a forge-rhythm skip, lantern-dim. Never subtitled, never translated. | Mira's finale (`one_who_listens`, shipped) |
| `courier` | A message/object arrives whose *carrier paid for carrying it*: a dead courier with a sealed satchel, a humming child, a ledger line stamped/un-stamped/stamped. The player is now holding something the stone routed to them. | The Courier in the Chamber (Part IV/XI) |
| `arrangement` | A quest the player already completed is revealed to have been *scheduled*: the outcome served the stone either way. Dust-lines in the aftermath, a date that matches, a survivor who was always meant to survive. | "the stone doesn't need to possess you — it just needs your ambition to point the right way" (Valrom, Part V) |
| `false_victory` | An apparent clean win that the very next beat re-prices. The granary was full during the famine. Killing the shaman *landed the rooks*. The Accord summit succeeds — one command-path, no friction. | "Nothing here should ever offer the player a clean win" (Part XI) |
| `address` | Rarest. The stone speaks *to the player specifically*, referencing their logged choices (never their name — their deeds: "the one who buried the knife", "the one who walked her home"). Escalates per act. | Lich-King-cadence mandate; the Moment-ledger ("the choice is logged", Part XI §6) |

**The Courier pattern** (mandated): the villain's long-range messaging is always mediated and always
lossy — every message costs its carrier (life, memory, or innocence), arrives sealed or half-copied,
and the player must choose to read (power + seeding) or refuse (restraint as a mechanic). Q5's Mira
is the shipped prototype: she carried one sentence and lost the evening.

**Hard rules**
1. The stone never lies. It arranges, and it lets you conclude. (Scarier, and cheaper to write.)
2. No beat translates the Underlanguage. Ever. Players who "understand" NPCs die of it — on camera.
3. Every `address` references at least one logged player flag (see schema v2 `sets_flags`).
4. The stone treats the player like the Lich King treated the WotLK player: as *promising material*.
   Escalation across acts: unnoticed → noticed → tested → courted → confronted.

---

## 1. THREE-ACT STRUCTURE × LEVEL BRACKETS

### Act structure at a glance

| Act | Levels | Zones | Theme | Villain posture |
|---|---|---|---|---|
| **I — "The Ground Is Patient"** | 1–20 | Border ring (6) + West kingdom (5) | Domestic dread. Learn to read the land. First kingdom politics as small-stakes rehearsal. | Weather. You are *unnoticed*, then *noticed*. |
| **II — "Four Kings, One Grave"** | 20–45 | North (5) → East (5) → South (5) + capital intrigue everywhere | GoT cold war: leverage, betrayal, the Accord fraying. The stone plays the kings; the player learns they're a piece. | Chessmaster. You are *tested*, then *addressed*. |
| **III — "The Ledger's Debt"** | 45–60 | Continent 2 (14) + return to Black Night: the Grave & Bloodstone Pit | The drowned future. The Archive-as-disease shows what "winning wrong" looks like. Return, descend, transmit. | Intimate. You are *courted*, then *confronted*. |

### Zone level bands (leveling path; travel graph from WORLD_PLAN.md)

**Act I:** Raven Hollow 1–6 · Vetka 1–6 · The Iron Vein 5–10 · The Copper Wells 8–12 ·
The Chamber Depths (dungeon) 10–12 · The Stonepath 12–14 → Grey Marches 13–16 ·
Western Lowlands 14–17 · **Angel Wings 15–20** · Famine Fields 17–19 · Riverfork 18–21.

**Act II:** Listening Steppe 20–23 · Threadlands 22–25 · **Black Night 24–28** · Gravemark Tundra
26–30 → Whisper Passes 28–31 · Eastern Ridges 30–33 · **Blestem 32–36** · Lichenreach 33–36 ·
Transcub Vale 34–37 → Bloodroad 36–39 · Basaltfang Range 38–41 · **Sangeroasa 40–44** ·
The Gift 41–44 · Ashvents 43–45. (The Grave & Bloodstone Pit is *visible* from Gravemark at 26 —
and locked. Like the ICC skyline: the endgame on the horizon for 30 levels.)

**Act III:** Grey Piers 45–47 · **Greyhollow 46–50** · Drowned Quarter 47–49 · Canal Maze 48–50 ·
Salt Fens 49–51 · Dead Timber 50–52 · Ledger Roads 51–53 · Morven Reach 52–54 · Anchorfall 53–55 ·
The Archive 54–56 · Finalized Fields 55–57 · Coldharbor Deep (dungeon) 56–58 · The Orange Fog
57–59 · The Last Hearth (safe hub, 45–60) → return voyage → **The Grave & Bloodstone Pit 58–60**.

### ACT I (1–20) — Border ring + first kingdom

**Main chain: "The Long Vigil" (28 quests).** The shipped five demo quests are steps 1–5 verbatim
(`well_went_copper` → `fresh_hay_old_bones` → `blade_wont_dry` → `what_the_rooks_saw` →
`one_who_listens`). The chain then walks the hub ring — the Bent Oar quest board (Iron Vein),
Old Marta's Vetka, the Copper Wells puzzle-tutorial, down into the Chamber Depths (the Courier's
corpse; the transcribe-or-deface choice from Part XI Q2 — the game's thesis choice), out to the
Stonepath (the shortening inscription), then west: Grey Marches cult, the full granary of the
Famine Fields, Maren's orphanage safehouse, Fielderine's court and the Lead Box, closing at
Riverfork with the Act II breadcrumbs north.

**Bloodstone cadence — one scripted beat per ~4 levels, ascending the ladder
symptom → whisper → courier → arrangement → false_victory → address:**

| Lvl | Kind | Beat |
|---|---|---|
| 1–4 | `symptom` | Ambient only (copper wells, flat bread — already shipped). The villain is set-dressing. |
| ~5 | `whisper` | Mira at the treeline (shipped). One sentence, lanterns dim. |
| ~9 | `courier` | The Chamber Depths: the Courier's sealed satchel. Player carries it out; whoever they give it to *starts reading* — and must be stopped or lost. |
| ~12 | `arrangement` | Stonepath: the crossroads stone's marks are *fading* — and a date scratched by a dead hand matches the day the player first entered Vetka. The rooks-camp events of Q4 are re-referenced: either branch outcome, the warband moved exactly as something needed it to. |
| ~16 | `false_victory` | Famine Fields: the player breaks the cult starving a village — and finds the granary was full the whole time. Engineered famine; the cult was staffing, not cause. |
| 19–20 | `address` | Act finale, the Lead Vault (Angel Wings): the Queen's inert fragment hums **once** as the player passes — and the guarding clerk repeats, in the too-much-room voice, a choice the player made in Act I ("You buried it. / You kept it." per `blade_wont_dry` branch). Fielderine sees the player flinch *away* — and marks them as one of the few with the resisting instinct. |

**Tempo rule of thumb:** 1 scripted villain beat per bracket-quarter, ~1 ambient symptom vignette
per zone per session. Any more and dread becomes noise (WoW-Classic patience: Arthas doesn't
show up in Elwynn).

### ACT II (20–45) — Four kingdoms, cold war

**Main chain: "Four Kings, One Grave" (36 quests).** The player becomes a deniable instrument of
the Accord (recruited off the Act I finale by an Archive precursor contact — Sabira's network).
Kingdom arcs in leveling order N → E → S, with West intrigue threaded via return trips (hub-return
rule, §3). Arc capstones adapt the canon quest seeds: **North** — QS-6 "The Thread" (the waking
shell; Vasile vs Radovan, two-sided) and Gravemark's kerb-stones; **East** — QS-1 "Rows of
Twelve" (the ledger error; the paperwork is the murder weapon) and QS-4 "Useful, Not
Indispensable" (Anara hunted by Ilion); **South** — QS-2 "The Gift" (no ethical harvest) and the
disarm-Valrom's-dagger chain (which later gates Boss-3 phase 3); **West (threaded)** — QS-3
"The Lead Box" (the clerk-canary). Act climax 44–45: the Accord summit at the Stonepath —
a diplomatic *triumph*.

**Bloodstone cadence — each kingdom arc (~6–8 levels) contains exactly this fixed kit,
delivered through that kingdom's own medium:**

| Arc | `whisper` medium | `courier` beat | `arrangement` reveal | `false_victory` (arc end) |
|---|---|---|---|---|
| North 20–30 | A thread-shell in the still market turns its head as you pass — all of them do, one beat, rows of twelve | An abandoned pilgrim camp: three bedrolls, cold stew, footprints in, none out — and a letter addressed *to whoever reads this* | Lilith's "protection" framed: the Thread you've been repairing for the Council is also the cage's own maintenance | You sever/free/hide the waking shell (QS-6) — every option is revealed to feed Radovan's private reading |
| East 28–37 | The walls of the Riddler's Quarter say one sentence *in your own recorded voice* (Cazimir's listening-walls played back) | A dead informant's notebook: the copied inscription is surfacing on the facing blank page — it is *spreading itself* | The ledger error of QS-1 was seeded: Cazimir's flawless arithmetic contained exactly one mistake, placed where the player would find it | You save (or spend) the informant — either way Cazimir's bid for the stone advances one file |
| South 36–45 | All the hammers stop for a count of three (canon vignette) — and in the silence, one note | A debt-ledger nailed at the Pit rim: a name freshly marked "collected" is a man the player sold ore to yesterday | Valrom's dagger: the King's unification "ambition" is a compulsion — the antenna reveal (Part V leverage table) | Disarm the dagger / expose the Gift cycle — Sangeroasa's arsenal output *rises*; war logistics were never about the King |
| **Act finale 44–45** | — | — | — | **The Accord summit succeeds.** Four powers, one table, one signed pause — and on the ride home the player's alchemical sight reads the summit stone's foundation **shifting orange**. Unification of purpose = one command-path. The stone arranged its own oversight committee. |

**`address` cadence in Act II: every ~5 levels**, escalating specificity — L25 (Gravemark: a
thread-touched corpse sits up, speaks one sentence *about the player's Act I choice*, lies back
down) · L33 (Stonepath mid-act pivot: the shortening inscription now *answers* — it has been
getting shorter since someone transmitted; it recognizes what the player might be) · L38 (the
Bloodroad: a slag-walker column halts; the player's own name is illegible on a work-ledger, entry
"pending") · L44 (summit, above). This is the Wrathgate rhythm: the villain co-authors the act's
biggest political event.

### ACT III (45–60) — Continent 2 + endgame

**Main chain: "The Ledger's Debt" (26 quests).** The Grey Ferry voyage from Riverfork is the
era-crossing (canon frame: Greyhollow is "the drowned future the map grows into"). The stone's
cruelest arrangement is the act itself: *it shows the player the future it already won.* Marrow
Pell's un-closeable file (QS-7), the Blind Seer screaming "already collected — why is it still
walking?" (QS-8), Marta's stick enshrined in the Archive (it must hurt), the Morven line — the
locked door — deciding whether to open. Act pivot at 55: the player learns the counter
(**a living touch receives; a dead touch transmits**) from the Seer/Constantine-recurrence, at the
cost of accelerating his erasure (QS-5's shape). Then the return voyage — the Archive ↔ Black
Night thread-gate, "the same place, a thousand years apart" — and the descent: Gravemark →
the Grave & Bloodstone Pit, 58–60.

**Bloodstone cadence — every ~2 levels; the stone now talks TO you:**

| Lvl | Kind | Beat |
|---|---|---|
| 45–46 | `courier` | A cracked debt-tablet washes up at the Grey Piers, *still warm* — hairline-cracked, not quite closed. It is shaped like the player's file. |
| 47–49 | `whisper` | Greyhollow fog reads shifting orange around the player wherever they stand. The finalized pause as they pass — rows, heads turning, one beat. |
| 50 | `false_victory` | Cracking a Debt-Pit node un-finalizes a district — doors reopen, faces flicker back — and widens the signal: the Orange Fog creeps one zone closer. Mercy is a transfer, not a cancellation (QS-7's law). |
| 51–54 | `arrangement` | The Archive tour: the player finds *their own Act I–II outcomes* filed and closed — Mira's file, the dagger's file, the informant's file. Every choice they made has an entry. One entry is stamped, un-stamped, stamped again. |
| 55 | `address` (the offer) | The Deadheart-signal wastes: the stone makes its one direct offer, Lich-King-style — not power, *completion*: "You have carried so much. Set it down. Be kept." Refusable only; refusing is the quest. |
| 56–57 | `courier` | The Seer's testimony (QS-5/QS-8 fusion): the "transmit, not receive" key, handed over by a man dissolving as he offers it. |
| 58–60 | **confrontation** | The descent. Gravemark kerb-stones light blue → violet → green → orange as you pass (the detection grammar as level design). The Pit is a **comprehension gauntlet, not a combat gauntlet** (canon, Part XI §4): standing too long and understanding too much erases. Lilith encounter per Boss 4 (rage-gauge, the emotional fight). Final input: the player pushes one small, specific, imperfect logged Moment into the stone — chosen from *their own campaign flags* (Mira walked home, the buried dagger, the informant's name). The overwrite is small and temporary. That's the point. The Pause holds. |

**Endgame plateau (post-60 / at-60 content):** dailies at the Last Hearth + Bent Oar (both hearths,
both eras), the two endgame dungeons (Coldharbor Deep, the Pit re-entry wings), event quests.
The stone keeps whispering at 60 — the Pause is held, not won.

---

## 2. QUEST TYPE SYSTEM — counts to ~1000

| Type | `qtype` | Count | Definition & rules |
|---|---|---|---|
| **Main chain** | `main` | **90** | The spine: Act I 28 · Act II 36 · Act III 26. Strict `chain`/`chain_step` order, always cross-zone, carries every scripted `villain_beat`. Gold journal color. |
| **Zone stories** | `zone` | **480** | Per-zone arcs (3–5 mini-chains per zone) telling that zone's one argument. Budget: 5 capitals × 20 = 100 · 3 dungeons × 8 = 24 · 31 wilderness zones × 11 = 341 · Last Hearth 15. Zone-story completion = that zone's "achievement" + unlocks its dailies. |
| **Side quests** | `side` | **190** | One-offs and 2-steps off the beaten path; carry most of the *cheerful* budget. No prereqs beyond discovery. |
| **Faction reputation** | `faction` | **70** | 8 tracks (see §2b) × ~9. Gated by rep tier; the GoT machinery — most `leverage-trade` and `two-sided` templates live here. Cross-zone by construction. |
| **Class quests** | `class` | **70** | 7 classes × 10, at L10/20/30/40/50 milestones (2 per milestone). Necromancer's are Thread-flavored (Black Night), rookwarden's rook-flavored (Petra's line), druid's Gift/soil-flavored, paladin's Transcub-flavored — class fantasy braided into faction lore. |
| **Dailies** | `daily` | **60** | Unique defs in pools: Bent Oar board (12), each capital board (5×6=30), Last Hearth (10), Stonepath wardens (8). Unlock on zone-story completion. Short, systemic, tone-light. |
| **Event quests** | `event` | **40** | Calendar windows: the Long Dark (winter, Iele), Forge-Rest (the day the hammers stop), Accord Day (political theater), the Drowned Tide (C2). 4 events × ~10. |
| **TOTAL** | | **1000** | |

### 2a. Interconnection rules (the "interconnected" in the mandate)

1. **Breadcrumb rule.** Every zone-story finale emits 1–2 `follow_up` breadcrumb quests pointing
   along travel-graph edges (WORLD_PLAN spine) to the next band-appropriate zone. No dead-end zones.
2. **Two-hop locality.** No quest step sends the player more than 2 zones from where the chain
   continues. Long hauls are chains, not single objectives.
3. **Cross-zone chains.** Each act arm carries ≥3 chains spanning ≥3 zones (e.g. the Lead Box
   escort spine West; the Rows-of-Twelve ledger chain East; the Gift corpse-brokerage chain South).
4. **Reputation threads.** Kingdom-arm quests grant that kingdom's rep; ~20% *also* move a rival's
   (spy work cuts both ways). Capital inner-district chains gate on rep tier 3+.
5. **Hub-return rule.** Every 3–4 levels a main/zone quest routes through a hub (Bent Oar,
   Stonepath, a capital gate) — the Crossroads pattern. Villain `address` beats live at hubs,
   where the most players will be standing.
6. **Choice persistence.** Every `choice` objective sets a flag; every flag is referenced ≥1 more
   time later (aftermath dialogue, an Act III Archive file, or an `address`). Worlds are mutable;
   backtracking is grief (Part XI dungeon rule 4).
7. **Dailies unlock by intimacy.** A zone's dailies open only after its story — the zone "knows"
   you first.
8. **No orphans.** Every side quest's giver is on a main/zone path or reached by a breadcrumb.

### 2b. Reputation tracks (8)

Border Hearths (Bent Oar/Vetka/Raven Hollow) · Angel Wings (Fielderine) · Council of Six
(Black Night) · Blestem (Cazimir's ledger — rep here is literally *your file thickness*) ·
Sangeroasa (Valrom's forges) · The Accord/Archive (Act II+) · The Morven (Act III) ·
The Last Hearth (Act III). Six tiers, canon-flavored labels per faction (Blestem:
Unfiled → Noted → Priced → Leveraged → Load-Bearing → Architecture). Kingdom tracks are
partially zero-sum by design (rule 4): you cannot be Architecture in Blestem and beloved of the
forges. GoT mandate honored: leverage, not friendship.

---

## 3. CHAIN TEMPLATES (8 reusable shapes)

Each template lists beats → engine objective kinds (v1: `talk/kill/reach/choice/use_item`;
v2 adds `collect/scan/vigil/deliver`, §5). Target distribution across the 1000: T1 18% · T2 8% ·
T3 12% · T4 10% · T5 22% · T6 6% · T7 10% · T8 8% · bespoke 6%.

**T1 — INVESTIGATION ("Read the Land").** Symptom → scan (alchemical sight color) → witness
interview → site reveal → containment *choice* (deface/starve vs transcribe/exploit — restraint is
a mechanic). Beats: `talk → scan → talk → reach → choice`. Shipped prototype: `well_went_copper`.
The transcribe option always pays better *now* and seeds a persistent world-state cost.

**T2 — ESCORT-GONE-WRONG.** The escort is never in the danger you were told about. Find →
lead (escort flag) → interruption (the escortee stops; listens; speaks; or is *recognized*) →
finale that completes unresolved. Beats: `reach(night) → reach(escort) → finale_beat`. Shipped
prototype: `one_who_listens`. Rule: never let an escort die to trash mobs; the "gone wrong" is
always story, not fail-state.

**T3 — LEVERAGE-TRADE (the GoT shape).** Acquire leverage (a ledger, a name, a confession) →
*three* buyers exist (the subject, their rival, the Archive) → sell/return/burn choice with rep
consequences in two directions and a flag. Beats: `collect/steal → talk×2 (bids) → choice → deliver`.
Canon anchor: Blestem's lower market — information priced, escrowed, enforced. The leverage always
resurfaces once (rule 6): the man you sold shows up sold-on.

**T4 — TWO-SIDED FACTION.** Two givers, mutually exclusive (`excludes`), same event, incompatible
verbs (study it vs snuff it; save her vs file her). Both sides are right about the other's blind
spot. Beats: mirrored `talk → kill/collect/deliver → turn_in`, rep +A/−B. Canon anchor: QS-6
Vasile vs Radovan. Rule: the excluded giver's aftermath dialogue acknowledges what you chose —
politely, in Blestem; not politely, in Sangeroasa.

**T5 — COLLECTION-WITH-A-TWIST.** Kill/collect N → the turn-in re-reads the evidence and
recontextualizes (`note` + follow_up). The twist is discovered *in the loot*: too many tracks,
even-spaced; hides with no wounds; grain sacks stamped with last year's seal. Beats:
`kill/collect → talk (twist) → follow_up breadcrumb`. Shipped prototype: `fresh_hay_old_bones`
(boars → deliberate wolf-ring). This is the workhorse — it makes even filler advance dread.

**T6 — SILENT VIGIL.** Nothing attacks. Stand a watch (`vigil` objective: hold position, duration,
often night_only) over a grave, a stone, a standing person — and *observe* the one thing that
happens (a head turns; dust re-aligns; a note is left). Reward: knowledge + a flag, low XP, high
tone. Canon anchor: the Iele vigil culture; "the first monster is a symptom". Cap: ≤2 per zone —
scarcity keeps them holy.

**T7 — THE COURIER RUN.** Carry a sealed thing A→B without reading it. The temptation is
mechanical: examining it is *offered* at every rest point (`use_item` prompt), reading yields real
power/lore and seeds a transmission point + flag; delivering sealed pays rep and sets the
opposite flag. Sometimes the recipient reads it and the player watches the cost. Beats:
`accept_items → deliver (multi-hop reach) → choice-by-temptation`. Canon anchor: the Courier;
QS-3's lead-box logistics ("a courier/escort spine", Part X).

**T8 — FALSE VICTORY.** A complete, satisfying, well-paid win — then the epilogue quest
(auto-offered `follow_up`, a level later) re-prices it: the aftermath contains the stone's
fingerprints. Beats: any template played straight → epilogue `reach + scan(orange)`. Rule: the
re-pricing never invalidates the reward, only the meaning — the player keeps the gold and loses
the sleep. Used at every arc capstone (see cadence tables).

---

## 4. TONAL DISTRIBUTION RULE

Per-quest `tone` tag (audited per zone at authoring time). Percentages are of that zone-type's
quest count; ±5% tolerance.

| Zone type | heavy | creepy | cheerful | intrigue | Canon justification |
|---|---|---|---|---|---|
| Border ring (starter) | 25% | 35% | 25% | 15% | "A small, warm, ordinary town the world-machine is quietly digesting" — dread must arrive *through* domestic warmth (Part XI §2), so cheer is load-bearing here. |
| West / Angel Wings | 30% | 15% | 35% | 20% | The Humans are "messy uncountable warmth"; their grit is "decent people slowly priced into indecency" — highest cheer on the map, and famine-heavy where it counts. |
| North / Black Night | 30% | 45% | 5% | 20% | Vigil culture, the still market, thread-shells: "Black Night stills you." The 5% cheer is deliberate and precious (one gallows-humor gravedigger per zone). |
| East / Blestem | 20% | 25% | 10% | **45%** | "Information asymmetry as civic planning"; the paperwork is the murder weapon — the intrigue capital by canon. |
| South / Sangeroasa | **45%** | 15% | 15% | 25% | Structural cruelty "cheerful about it"; the Debt Pit, the Gift, consent-rotted-in. The 15% cheer is forge-camaraderie — honest, brutal, warm. |
| Continent 2 | 35% | 30% | 10% | 25% | Grimdark-noir dark heart, "what winning wrong looks like"; the Last Hearth carries most of C2's cheer budget on purpose (it's the point of the zone). |
| Dungeons | 45% | 45% | 0% | 10% | "A dungeon is an argument the world is making" — no jokes below ground. |

**Global result:** ≈29% heavy · 28% creepy · 19% cheerful · 24% intrigue — the WoW-Classic blend
(plague quarter next to gnome humor) with the dial shifted one notch darker, per the Velen tone
mandate. **Placement rule:** never two `heavy` main-chain quests back-to-back without a
cheerful/intrigue valve between them (the Classic pacing trick); `creepy` may chain freely (dread
compounds, grief doesn't).

---

## 5. XP CURVE TO 60 — extending `xp_system.gd`

### Design targets
- **Slow, WoW-Classic pacing**: ~140–170 hours 1→60; quests supply ~45–55% of leveling XP
  (vanilla-accurate), kills-en-route + dailies + grind the rest.
- **Keep shipped saves valid**: levels 2–10 keep the existing ×1.6 geometric costs *exactly*
  (100, 160, 256, 410, 655, 1049, 1678, 2684, 4295 — cumulative 11,287).
- The ×1.6 geometric CANNOT extend to 60 (1.6^58 ≈ 10^11 XP). Switch to **linear per-level growth**
  from 11 up — which is what Classic's curve effectively was.

### Exact numbers

```
xp_for_level(L):
    L in 2..10:  roundi(100 * 1.6^(L-2))          # unchanged, save-compatible
    L in 11..60: 4295 + 1815 * (L - 10)           # linear ramp
```

| L | cost | cumulative | | L | cost | cumulative |
|---|---|---|---|---|---|---|
| 10 | 4,295 | 11,287 | | 40 | 58,745 | 987,887 |
| 15 | 13,370 | 61,187 | | 45 | 67,820 | 1,304,562 |
| 20 | 22,445 | 151,262 | | 50 | 76,895 | 1,666,612 |
| 25 | 31,520 | 286,712 | | 55 | 85,970 | 2,074,037 |
| 30 | 40,595 | 467,237 | | 60 | 95,045 | **2,540,162** |
| 35 | 49,670 | 692,837 | | | | |

**Total 1→60: ~2.54M XP.**

### Kill XP (replaces the flat `KILL_XP` dict)

```
xp_for_kill(enemy) = roundi((10.0 + 4.5 * enemy_level) * family_mult * diff_mult)

family_mult:  fodder 0.75 (boar, wolf, fauna-with-teeth)
              standard 1.0 (skeleton, entranced, bandit, thread-shell, the finalized)
              tough 1.3   (orc, strigoi, varcolac, slag-walker, Morven blade)
              elite 2.0 · rare 3.0 · boss 10.0

diff_mult (classic gray-out): d = player_level - enemy_level
              d >= 8  -> 0.0                          # gray, no XP
              d >  3  -> 1.0 - 0.15 * (d - 3)         # fades over 4 levels
              d <  0  -> 1.0 + 0.05 * min(-d, 5)      # up to +25% for red mobs
```

Continuity check vs shipped values: skeleton L1 → 15 (was 12) · boar L1 → 11 (was 14) ·
wolf L2 → 14 (was 10) · orc L4 → 36 (was 18, orcs re-leveled to 4) — same order of magnitude,
now scaling to 60 (standard L58 mob ≈ 271 XP).

### Quest XP (derived, not hand-tuned — schema v2 lets `rewards.xp = 0` mean "derive")

```
quest_xp = quest_level * tier_mult      (min 40)
    daily 25 · side 30 · event 35 · zone 40 · class 45 · main 55 · chain-finale 80
```
Shipped demo quests keep their hand-authored values (grandfathered; they're in-range for L1–3).

### Pacing table (the "slow grind" audit)

Assumes quest-XP share ~60% early → ~50% late; the rest is kills earned *while questing* + grind.

| Bracket | cost/level (avg) | avg quest XP | quests/level | kills/level (standard) | feel |
|---|---|---|---|---|---|
| 1–10 | ~1,250 | 40·L ≈ 100–400 | 2–4 | 15–25 | brisk tutorial ramp |
| 11–20 | ~15,700 | ~600 | 8–12 | 60–90 | the Classic wall arrives |
| 21–30 | ~31,600 | ~1,000 | 12–16 | 90–120 | steady grind, arcs carry it |
| 31–45 | ~54,300 | ~1,500 | 15–19 | 110–150 | cold-war slog (intentional) |
| 46–60 | ~85,500 | ~2,100 | 18–22 | 140–180 | endgame march; dailies matter |

Whole-game math: ~1,000 quests exist; a single character naturally completes ~650–750 (you
out-level zones — Classic-authentic), worth ≈ 0.9–1.1M XP ≈ 45% of 2.54M. ✔ targets met.

### `xp_system.gd` change list
1. `MAX_LEVEL = 60`; add `LINEAR_START = 11`, `LINEAR_SLOPE = 1815`; make `xp_for_level` piecewise
   (keep the geometric branch verbatim for 2..10).
2. Replace `KILL_XP` with `FAMILY_MULT` + the formula above; `xp_for_kill(enemy_type, enemy_level,
   player_level)` (enemy.gd already knows `type_name`; add an `enemy_level` field to spawn configs).
3. Add `quest_xp(level, qtype)` implementing the tier table; `Quests` calls it when
   `def.rewards.xp == 0`.
4. Keep `HP_MANA_BONUS_PCT = 0.06` and `DAMAGE_PER_LEVEL = 1.0` (at 60: ×31 hp — matched by
   enemy-level scaling; itemization budget handles the rest).
5. `reapply_level_bonuses` and the graceful-degradation contract stay as-is.

---

## 6. QUEST DATA SCHEMA v2 (exact GDScript shape)

Backwards compatible: **every v1 key keeps its exact meaning**; v2 keys are additive with safe
defaults, so the five shipped quests run unmodified. JSON-safe throughout (Quests save contract).

```gdscript
## ------------------------------------------------------------------
## QUEST DEF SHAPE v2  (★ = required; unmarked = optional w/ default)
## ------------------------------------------------------------------
{
    # ---- v1 core (unchanged semantics) --------------------------------
    "id": "iron_vein_bent_oar_03",       # ★ stable save id: <zone>_<chain>_<step>
    "title": "The Board at the Bent Oar",# ★
    "giver": "bent_oar_keeper",          # ★ "" = auto-trigger only
    "prereq": [],                        #   AND-prereqs (quest ids), as today
    "summary": "…",                      # ★ journal blurb
    "offer_pages": ["…"],                # ★
    "active_pages": ["…"],
    "accept_items": [],
    "objectives": [ … ],                 # ★ see OBJECTIVE SHAPE v2
    "turn_in_npc": "",
    "turn_in_pages": [],
    "rewards": {                         # ★
        "xp": 0,                         #   0 = DERIVE from level+qtype (§5); >0 = hand-tuned
        "gold": 35,
        "items": [],
        "rep": {"border_hearths": 150, "blestem": -25},   # NEW inside rewards
    },
    "note": "…",                         # ★ journal line once completed
    "aftermath": {},                     #   npc dialogue overrides, as today
    "auto_trigger": {},                  #   as today
    "finale_pages": [], "finale_speaker": "", "finale_beat": "",

    # ---- v2 identity & placement --------------------------------------
    "qtype": "zone",       # ★ "main"|"zone"|"side"|"daily"|"event"|"class"|"faction"
    "zone": "iron_vein",   # ★ zone id (WORLD_PLAN registry) — journal grouping, map pins
    "level": 7,            # ★ quest level: XP derivation + journal color (green/yellow/red)
    "min_level": 0,        #   hard offer gate (0 = none)
    "tone": "creepy",      # ★ "heavy"|"creepy"|"cheerful"|"intrigue" — §4 audit key

    # ---- v2 chains & interconnection ----------------------------------
    "chain": "bent_oar_board",  #   chain id ("" = standalone)
    "chain_step": 3,            #   1-based order within chain (journal shows "3 of 5")
    "prereq_any": [],           #   OR-prereqs — any one completed unlocks (two-sided joins)
    "excludes": [],             #   accepting/completing this LOCKS these ids forever (T4)
    "follow_up": ["iron_vein_bent_oar_04"],  # auto-flip to available on completion;
                                #   if that def's giver == "" it force-starts (breadcrumb)
    "breadcrumb_to": "",        #   zone id — journal renders a travel pointer

    # ---- v2 world state ------------------------------------------------
    "requires_flags": {},       #   {flag: bool} — ALL must match to be offered
    "sets_flags": {},           #   {flag: bool} — applied on completion (choice branches
                                #   may override via their own sets_flags, like rewards)

    # ---- v2 gating: reputation / class / recurrence --------------------
    "rep_requirement": {},      #   {"faction": "blestem", "tier": 3} — min tier to offer
    "class_lock": [],           #   e.g. ["necromancer"] — qtype "class" quests
    "daily": {},                #   {"pool": "bent_oar_board", "reset_hour": 6}
                                #   completion stamps day-index; re-offerable next day
    "event": {},                #   {"event_id": "long_dark"} — offerable only while
                                #   EventCalendar.active(event_id)

    # ---- v2 villain cadence --------------------------------------------
    "villain_beat": {},         #   {"kind": "whisper"|"courier"|"arrangement"|
                                #    "false_victory"|"address"|"symptom",
                                #    "beat_id": "act2_north_whisper"}
                                #   Logged to VillainLedger on completion; lets tooling
                                #   audit the §1 cadence tables per bracket.
}

## ------------------------------------------------------------------
## OBJECTIVE SHAPE v2 — v1 kinds unchanged (talk/kill/reach/choice/use_item)
## kill gains:  + {enemy_level:int}          # for xp_for_kill (default: zone band)
## choice gains:+ options may carry "sets_flags" (mirrors rewards override rule)
## NEW kinds:
##   collect: {id, kind:"collect", text, item:String, count:int,
##             from_enemies:Array[String], drop_pct:float}   # loot-N (T5 workhorse)
##   scan:    {id, kind:"scan", text, map, pos:Vector2, radius:float,
##             color:String}      # alchemical-sight read; color: blue|violet|green|orange
##   vigil:   {id, kind:"vigil", text, map, pos, radius, duration_s:float,
##             night_only:bool}   # hold position; leaving pauses, not resets (T6)
##   deliver: {id, kind:"deliver", text, item:String, npc:String,
##             tempt_pages:Array[String]}  # courier run; each rest-hub offers the
##             read-it prompt (choice-by-temptation, T7); reading sets flag
##             "<quest_id>_read" and seeds a transmission point (world state)
## ------------------------------------------------------------------
```

### Engine deltas required (quests.gd + new autoloads)
1. **Registry split** — 1000 defs cannot live in one file. `QuestDefs.all()` becomes an aggregator:
   `scripts/quests/defs/act1_border.gd`, `defs/zone_<id>.gd` (one per zone), `defs/class_<id>.gd`,
   `defs/dailies.gd`, `defs/events.gd` — each exposing `static func quests() -> Array`. Registry
   asserts unique ids and validates required v2 keys at load (dev builds).
2. **Availability check** (`Quests`) extends the v1 prereq test with: `prereq_any`, `excludes`
   (locked set persisted), `min_level`, `requires_flags`, `rep_requirement`, `class_lock`,
   `daily` day-stamp, `event` window.
3. **New objective kinds**: `collect` hooks the loot pipeline (`report_loot(item_id)`), `scan`
   hooks the alchemy-sight tool (`report_scan(target, color)`), `vigil` ticks off
   `report_position` dwell time, `deliver` composes reach+use_item with temptation prompts.
4. **Reputation autoload** (`Reputation.gd`): 8 tracks (§2b), 6 tiers at 0/3000/9000/21000/45000
   /90000; `add(faction, delta)`, `tier(faction)`; JSON-safe save block. Quests applies
   `rewards.rep` on completion.
5. **VillainLedger autoload**: append-only log of `{beat_id, kind, level_at, act}` + the campaign
   flag set. Feeds `address` beats their references ("the one who buried the knife") and gives
   design a cadence audit (`beats_in_bracket(kind, l0, l1)`).
6. **EventCalendar autoload**: event windows off in-game calendar; dailies day-index in the save.
7. **Journal/tracker**: `MAX_TRACKED` 2 → 5; journal tabs by `qtype`, grouping by `zone`,
   chain progress "step N of M" from `chain`/`chain_step`.
8. **Save**: `_states` gains `"locked_by_exclude": []`, `"daily_stamps": {}`; flags move to
   VillainLedger's block. All JSON-safe, all additive.

---

## 7. ACCEPTANCE CHECKLIST (per authored quest)
- [ ] Has all ★ v2 keys; id follows `<zone>_<chain>_<step>`.
- [ ] `tone` set and inside its zone-type budget (§4); no heavy-heavy adjacency on main chain.
- [ ] Fits a template (§3) or is flagged bespoke (≤6% of zone budget).
- [ ] Obeys 2-hop locality; if zone-finale, emits breadcrumb `follow_up`.
- [ ] Any `choice` sets a flag AND that flag has a registered later reference (rule 6).
- [ ] If `villain_beat`: kind/frequency matches the act cadence table (§1) — check VillainLedger audit.
- [ ] No clean win: the reward is real, and something in `note`/aftermath re-prices it.
- [ ] Lore nouns verified against `_lore_extract.txt` (names, colors, factions, grammar of the dead).
