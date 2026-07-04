# RAVEN HOLLOW — CLASS STARTING EXPERIENCES (L1–5)
**Seven class-mentor intro chains rooted in Raven Hollow · every kit taught ability-by-ability · one shared "come of age" convergence into the Border ring at ~L5.**

Law composed with: `design/QUEST_ARCHITECTURE.md` (70 class quests, schema v2, tone law, villain
cadence), `design/ZONE_QUEST_MATRIX.md` (zone quotas, breadcrumbs, leveling flow),
`design/COMBAT_PACING.md` (TTK contract, archetype curriculum, shipped XP curve §8, RH spawn
table §10.1), `design/ITEM_PROGRESSION.md` (budget points, rarity roles), `design/NPC_CAST.md`
(RH roster + rename mandates). Engine ground truth: `scripts/class_defs.gd` (the seven kits —
ability ids/kinds/params are quoted verbatim below), `scripts/quest_defs.gd` (shipped demo
quests + objective kinds v1), `scripts/main.gd` (`change_map`, spawn flow), `scripts/player.gd`
(full kit granted at L1 today), `scripts/zone_defs.gd` (built zones), lore bible
`c:/Users/vstef/Desktop/rpg/_lore_extract.txt`.

---

## 0. THE DECISION: Border start + class-mentor pockets (not seven separate zones)

The prompt's instinct — warrior→Sangeroasa pit-yards, paladin→Angel Wings chapel,
necromancer→Black Night, rogue→Blestem alleys — is the right *fantasy* but the wrong *level
band*. Sangeroasa is a 34–44 zone; Black Night is 45–52; Blestem is 25–35 (ZONE_QUEST_MATRIX
brackets). Dropping a level-1 pocket inside a level-40 kingdom breaks the travel graph, the
tone escalation (Act I is *domestic* dread — "Arthas doesn't show up in Elwynn"), and the
40-zone build plan. Seven full 1–5 zones would also cost ~7 zone builds + 7 spawn tables +
7 hub NPC rosters before the second real zone ships.

**The decisive argument is already shipped in `class_defs.gd`: all seven class lore blurbs
root the class in Raven Hollow itself.**

| Class | Shipped lore anchor (verbatim source) | Native RH pocket |
|---|---|---|
| Warrior | "when the Emberfall razed the old garrison, only the drill-yard's stubbornness survived in him" | **the burned-garrison drill-yard** |
| Rogue | "raised in the fog-alleys behind the tavern" | **the fog-alleys behind the Ember Hearth** |
| Mage | "copied forbidden ember-script by candlelight until the candle answered back" | **the candle-house** (council-sealed cottage) |
| Paladin | "sworn at the ashen chapel on the hill" | **the Ashen Chapel** on the cemetery hill |
| Necromancer | "years tending Raven Hollow's graveyard" | **the old graveyard** (exists — demo map) |
| Rookwarden | "the rooks… chose him at the gallows-tree" | **the gallows-tree** (east wilderness) |
| Druid | "the old wildwood that remembers Raven Hollow older than its walls" | **the wildwood eaves** (north wilderness) |

So the design is:

1. **Everyone still starts in Raven Hollow** (respects the shipped `main.gd` new-game flow,
   `class_select.gd`, saves, and the demo quests verbatim).
2. Each class gets a **mentor + pocket**: a hand-authored landmark anchor inside the existing
   `town`/`wilderness` maps (Phase 1 — zero new maps), optionally promoted to a small interior
   micro-map later via the proven `change_map` path (Phase 2).
3. Each class runs a **6-quest intro chain (L1–5)** that teaches the kit ability-by-ability
   against the COMBAT_PACING archetype curriculum (brute → caster → guarded → pack → elite).
4. Every chain ends on the same **"come of age" beat**: the mentor walks you to Gatewarden
   Iosif at the east gate, and the Border ring opens — converging exactly on
   ZONE_QUEST_MATRIX's shipped breadcrumb ("Iosif opens the east gate toward the Bent Oar").
5. The prompt's far-kingdom fantasies are honored **later, where they belong**: as the class
   **journey quests** at L15/25/35–40/50 (§6) — which is where QUEST_ARCHITECTURE already
   braids class fantasy into faction lore (necromancer=Thread/Black Night, rookwarden=Petra's
   line, druid=Gift/soil, paladin=Transcub).

### Budget accounting (composes with the 70-class-quest law)

QUEST_ARCHITECTURE §2 allots **70 `class` quests (7 × 10)** and sketches them as "2 per
milestone at L10/20/30/40/50." **Amendment (count-preserving):** re-cut each class's 10 as
**6 intro quests (L1–5) + 4 journey quests (~L15 / ~L25 / ~L35–40 / ~L50)**. Total stays 70;
the faction-braiding mandate moves wholly onto the journey quests; the intro chain becomes the
teaching layer WoW-Classic never had and always needed. These 42 intro quests are `qtype:
"class"` budget — they do **not** count against Raven Hollow's 24-quest zone quota (journal
groups them under `zone: "raven_hollow"`, class tab).

---

## 1. THE SHARED FRAME — minute-by-minute new game

```
0:00  class_select → spawn at builder spawn (plaza, per main.gd)
0:10  Innkeeper Magda's default dialogue gains ONE class-conditional line
      ("The yard behind Goran's still drills at dawn — Codrin asked after
      anyone wearing a soldier's boots." — 7 variants, one per class)
      + minimap pin on the class mentor. Nothing forced; WoW-style breadcrumb.
1:00  Mentor offers rh_<class>_1 (class_lock gates it; other mentors give
      one flavor bark to wrong-class players — the town has texture, not walls)
L1–2  Class quests 1–3 interleave with shipped demo quests 1–2
      (well_went_copper, fresh_hay_old_bones — untouched, verbatim)
L3–4  Class quests 4–5 interleave with demo 3–4 + first Vetka/Iron Vein pulls
L5    Class quest 6 — COME OF AGE: staged elite, class ultimate, mentor beat,
      class item. Mentor walks you to Gatewarden Iosif. East gate opens.
      Demo quest 5 (one_who_listens) lands here too — Mira's whisper stays
      the game's FIRST villain word, per the Act I cadence table.
~L5   Everyone converges: east gate → Emberfall Road → the Bent Oar board
      (Iron Vein 2–4) → Vetka. The seven roads become one road.
```

**Pacing audit** (COMBAT_PACING §8 shipped curve — L2:164 · L3:224 · L4:294 · L5:372;
cumulative 1→5 = 1,054 XP): demo quests grant 520 (grandfathered values), the class chain
grants **400** (below), kills-en-route ~150–250 (skeletons 18 XP, boars 22–26). A player who
does both chains hits L5 right at the gate with a handful of RH zone-quests left over —
Classic-correct overflow (ZONE_QUEST_MATRIX rule: ~30% skippable).

**Class-chain XP schedule (all 7 chains identical):** Q1 40 · Q2 50 · Q3 60 · Q4 70 ·
Q5 80 · Q6 100 = **400 XP** (~38% of 1→5 — inside the "quests ≈ half" contract).
`rewards.xp` hand-set (these are L1–3 defs; the derive-formula floor of 40 would overshoot Q1).

**Reward schedule (ITEM_PROGRESSION):** Q1 consumables (2× minor potion) · Q3 one **common
i2** class tool (white is correct at L2) · Q6 one **uncommon i5** class-identity piece +
the class's "come of age" cosmetic flourish (title line in the character sheet). Rares stay
quest-scarce per the Goran's Targe precedent.

**Tone audit:** each chain is tagged per-quest below; summed across 42 quests the mix is
10H/12C/14W/6I ≈ 24H/29C/33W/14I — inside the Border-ring budget (25/35/25/15 ±5) with the
warm side deliberately heavy: these are the character's *home* quests, and the warmth is what
the Stone wants gone.

**Villain cadence:** Act I L1–4 allows `symptom` beats ONLY (QUEST_ARCHITECTURE §1). Each
chain carries exactly **one** class-flavored symptom vignette (marked ⚠ below), always
environmental, never a word. Mira's `whisper` at ~L5 remains the first voice.

---

## 2. TEACHING GRAMMAR (how a quest "teaches an ability")

Rules for every teaching quest, derived from COMBAT_PACING's curriculum:

1. **The situation forces the ability.** Not "use Whirlwind 3 times" in a vacuum — three
   boars funnel into a culvert so single-target swings *feel* wrong. The objective verifies
   what the situation already made desirable.
2. **One new verb per fight.** Paired abilities (marked `+`) are taught in the same quest only
   when they form a natural combo (shadowstep→backstab, frost_nova→blink, thornroot→stormbolt).
3. **Archetype ladder.** The chain's opponents ascend COMBAT_PACING §10.1's shipped RH
   roster: training pell (no combat) → `skeleton` brute L1 → `skeleton_mage` caster L2 →
   `skeleton_warrior` guarded L2 → pack pull (boars/wolves via east gate) → **staged L4
   elite** at the Q6 capstone (rank mult ×5 hp — an 8–9 s TTK contract fight that *needs*
   the ultimate).
4. **Mentor voice does the tooltip's job.** Every mechanical fact (cooldown feel, aim mode,
   the `next_hit_mult` window) is spoken in-character, once, before the fight.
5. **No fail states.** Missing the ability usage just leaves the objective open (v1 engine
   behavior); the situation re-arms.

### New objective kind (schema v2 addition — additive, JSON-safe)

```gdscript
## use_ability: {id, kind:"use_ability", text,
##   ability:String,            # ability id from ClassDefs (e.g. "whirlwind")
##   count:int,                 # default 1
##   context:{                  # ALL optional; empty = any cast counts
##     enemy_type:String,       # a hit landed on Enemy.type_name
##     min_targets:int,         # melee_arc/aoe_ring/volley hit >= N enemies
##     at_night:bool,           # DayNight.is_night
##     within:{map,pos,radius}, # cast located in a zone anchor
##     while_active:String}}    # another ability's buff/loop currently up
```
Wiring: `player.gd`'s cast path emits `Quests.report_ability(ability_id, ctx)` (ctx built from
the resolved hit list — the melee_arc/aoe/volley resolution code already knows its targets).
One report call site; Quests matches like `report_kill` does.

### Ability unlock gating (the WoW-trainer feel, soft)

Today `player.gd` grants the full kit at L1. Change (flag-gated, save-compatible):

- New characters start with **abilities[0] + abilities[1]** unlocked
  (`player.unlocked_abilities: Array[String]`; key absent in a save ⇒ all unlocked — old
  saves untouched, graceful-degradation contract preserved).
- Each class quest's `rewards` gains `"unlock_abilities": ["whirlwind"]` — unlocked at
  turn-in with a gold hotbar flash + mentor line.
- **Hard fallback so no build soft-locks:** any still-locked ability auto-unlocks at
  `level >= 2 + its_kit_index` (i.e., skipping the chain entirely costs you nothing but the
  teaching and the rewards). Hotbar renders locked slots dark with a padlock over the
  `pixel:` icon.

---

## 3. THE SEVEN MENTORS (NPC_CAST composition)

Existing cast reused where the lore already appointed them; three additions to the Zone-1
roster (11 → 14), all passing the "small warm imperfect thing" audit. Renames per NPC_CAST §1
assumed (Magda / Anton / Voicu).

| Class | Mentor | Status | Pocket anchor | Voice |
|---|---|---|---|---|
| Warrior | **Veteran Codrin** | exists (`rh_codrin`, T(combat)) | drill-yard behind the smithy, against the burned garrison palisade | V-SOLDIER |
| Rogue | **Ilinca the Lamplighter** *(new, `rh_ilinca`)* — lights every lamp in town except the fog-alley's; keeps that one dark on purpose | new | fog-alley behind the Ember Hearth | V-SLY-F |
| Mage | **Candle-Keeper Ruxandra** *(new, `rh_ruxandra`)* — tends the candle-house the council sealed and never quite locked; her own candle answered back forty years ago and she blew it out | new | the candle-house, a shuttered cottage off the plaza | V-ELDER-F |
| Paladin | **Prior Costin** *(new, `rh_costin`)* — last keeper of the Ashen Chapel; polishes a lantern he has never once needed to relight, and checks anyway | new | the Ashen Chapel on the cemetery hill | V-ELDER-M |
| Necromancer | **Gravekeeper Voicu** | exists (`gravekeeper` — "considers you a future client") | the old graveyard (existing demo combat map) | V-ELDER-M |
| Rookwarden | **Old Petra** | exists (`wanderer1` — already reads rooks in shipped Q4) | the gallows-tree, east wilderness treeline | V-ELDER-F |
| Druid | **Baba Iva** *(new, `rh_iva`)* — wildwood hermit; the town swears she predates the walls, and the walls do not argue | new | the wildwood eaves, north wilderness edge | V-ELDER-F |

Mentors are spawned for **all** classes (world texture); `class_lock` on the quest defs means
only your own mentor has work for you. Wrong-class players get one bark each ("Wrong hands
for this yard, friend. Goran's forge is warmer.").

**Anchor integration (the shipped pitfall):** all six new anchors (drill-yard, fog-alley,
candle-house, chapel, gallows-tree, wildwood eaves) are PLACEHOLDER positions until bound to
builder truth via `Quests.override_pos()` at map-build time — the exact pattern
`quest_defs.gd`'s INTEGRATION notes already mandate for q4_camp/q5_treeline. The graveyard
and plaza anchors reuse `town_builder.gd` verified constants.

---

## 4. THE SEVEN INTRO CHAINS

Quest ids follow `<zone>_<chain>_<step>`: `rh_warrior_1` … `rh_warrior_6`. All are
`qtype:"class"`, `zone:"raven_hollow"`, `class_lock:[<class>]`, `chain:"<class>_coming_of_age"`.
Kit indices below quote `class_defs.gd` verbatim. Q6 in every chain is the **come of age**:
staged elite → ultimate → mentor oath beat → class item → `follow_up` breadcrumb to Iosif.

---

### 4.1 WARRIOR — "The Yard That Wouldn't Burn" (mentor: Veteran Codrin)
*Kit: cleave · shield_charge · sunder · whirlwind · war_cry · iron_bulwark · earthshaker.*
*Start unlocked: cleave + shield_charge.*

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **First Stance** | `cleave` (arc 110°) | Three training pells stood in a tight arc — Codrin: "One swing, three answers. The arc is the lesson." | `use_ability` cleave ×5 `min_targets:2` (pells count as dummy targets) | W |
| 2 | 2 | **Close the Distance** | `shield_charge` (dash 100px, next-hit ×1.8) | A skeleton_mage has climbed the graveyard knoll; Codrin: "A caster you walk toward is a caster that wins. ARRIVE." Charge it mid-cast, land the empowered hit. | `use_ability` shield_charge `enemy_type:skeleton_mage` → `kill` skeleton_mage ×1 | C |
| 3 | 2 | **Break the Guard** | `sunder` (70° heavy) | The skeleton_warrior (guarded archetype — gray-number tank) at the yard wall. Cleave bounces off; Codrin: "Some doors want a narrower key, swung harder." | `use_ability` sunder `enemy_type:skeleton_warrior` ×2 → `kill` ×1 · reward: **common i2 "Drill-Yard Waistguard"** | W |
| 4 | 3 | **Too Many Hands** | `whirlwind` (self-ring 40px) | Boar cull past the east gate — but Codrin's contract sends you to the culvert where they funnel three at a time. | `use_ability` whirlwind `min_targets:3` → `kill` boar ×4 | W |
| 5 | 4 | **The Two Shouts** | `war_cry` + `iron_bulwark` | Hold the drill-yard gate at dusk against two skeleton waves (scripted spawn). "One shout for the blood, one for the bone. Learn which comes first — it says who you are." | `use_ability` war_cry ×1 + iron_bulwark ×1, both during the hold → `kill` skeleton ×5 | H |
| 6 | 5 | **Earthshaker** ⚑ | `earthshaker` (72px slow-ring ult) | COME OF AGE: the Palisade Wight (staged L4 **elite** skeleton_warrior, ×5 hp) claws out of the burned garrison's foundation. Codrin stands aside: "The yard trained you. Now the yard asks." | `reach` palisade → `use_ability` earthshaker `min_targets:1` → `kill` elite → `talk` Codrin | H |

⚠ **Symptom (in Q6 aftermath):** under the wight's grave, the drill-yard's cracked flagstones
hold dust in perfectly parallel lines — the ground was drilling too. Codrin sweeps it flat
without a word and hands you your reward on top of the broom.
**Come-of-age reward:** uncommon i5 **"Codrin's Second Shield"** (OH: armor 2 + hp 10) — "He
carried two the whole war. He only ever needed the one he gave away." Title line: *Shield of
the Hollow*. `follow_up` → Iosif at the east gate.

---

### 4.2 ROGUE — "The Unlit Lamp" (mentor: Ilinca the Lamplighter)
*Kit: quick_slash · backstab · shadowstep · noxious_vial · fan_of_knives · shroud ·
death_blossom. Start unlocked: quick_slash + backstab.*

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **Quick Hands** | `quick_slash` (0.35s spam) | Four sandbags hung from the alley lines at swaying heights. "Fast beats hard. Hard is for people who got seen." | `use_ability` quick_slash ×8 `within:alley` | W |
| 2 | 2 | **Step, Then Knife** | `shadowstep` + `backstab` (step grants next-hit ×2.0; backstab 60° arc) | The skeleton_rogue duelist (it strafes — face-tanking it is slow). Ilinca: "Step through its shadow, and put the point where it was just looking away from." | `use_ability` shadowstep → `use_ability` backstab `while_active:shadowstep` (bonus window) → `kill` skeleton_rogue ×1 | C |
| 3 | 2 | **Bad Medicine** | `noxious_vial` (thrown ground DoT + slow, at_aim 120px) | The boar wallow past the gate: vial the wallow *before* they wake, cull them slowed. First aim-mode ground-target of the chain. | `use_ability` noxious_vial `within:wallow` → `kill` boar ×3 · reward: **common i2 "Alley Knife"** | W |
| 4 | 3 | **Eight Points of Argument** | `fan_of_knives` (radial 8-volley) | Night skeletons converge on the graveyard path in a knot of four. "When they're all around you, dear — good. That's the one shape you can hit ALL of." | `use_ability` fan_of_knives `min_targets:3` `at_night` → `kill` skeleton ×4 | C |
| 5 | 4 | **Carry It Sealed** | `shroud` (4s speed/absorb veil) | A sealed packet across town at night, graveyard route, shroud up for the crossing. The packet's examine-prompt is OFFERED at the well (T7 temptation, seeded at level 4 — reading sets `rh_rogue_packet_read`; Ilinca knows either way, and says only "So."). | `deliver` packet (tempt at plaza well) + `use_ability` shroud `within:graveyard` | I |
| 6 | 5 | **Death Blossom** ⚑ | `death_blossom` (ticking self-ring ult) | COME OF AGE: three cutpurse "guests" (staged L4 duelist trio, one **elite**) wait in the fog-alley to take the lamp route from Ilinca. They surround you. That is their mistake. | `reach` alley `at_night` → `use_ability` death_blossom `min_targets:2` → `kill` ×3 → `talk` Ilinca | H |

⚠ **Symptom (Q6 arrival):** the alley fog is standing in rows — even-spaced, patient, like
queued men. Death Blossom scatters it. It reforms behind you, one row closer.
**Come-of-age reward:** uncommon i5 **"Lamplighter's Gloves"** (hands: damage 1 + speed 3%) —
"For work best done between two lamps, both out." Title: *Knife in the Fog*. `follow_up` → Iosif.

---

### 4.3 MAGE — "The Candle That Answered" (mentor: Candle-Keeper Ruxandra)
*Kit: spark · ice_lance · fireball · flame_strike · frost_nova · blink · mana_shield ·
cinderfall. Start unlocked: spark + ice_lance.*

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **Small Fires** | `spark` (fast bolt) | Relight the four dead lanterns on the candle-house lane from across the street. "Magic that can't light a lamp has no business stopping a heart." | `use_ability` spark ×4 `within:lane_lanterns` | W |
| 2 | 2 | **Two Answers** | `ice_lance` + `fireball` (fast single vs slow splash) | A charging boar (fast, one body — the lance's 320-speed answer) and a lazy skeleton pair (slow, two bodies — the fireball's 30px splash answer). "The question decides the spell. Never the mood." | `use_ability` ice_lance `enemy_type:boar` → `use_ability` fireball `min_targets:2` | W |
| 3 | 2 | **Ground, Not Target** | `flame_strike` (at_aim ring, 130px cast range) | Three dust-ring nests on the cemetery hill must be burned *where they lie* — first ground-target cast. Reward: **common i2 "Wax-Sealed Focus"**. | `use_ability` flame_strike `within:nests` ×3 | C |
| 4 | 3 | **The Panic Lesson** | `frost_nova` + `blink` (root ring + escape dash) | Ruxandra has you ring the boar-run bell. Three chargers converge: nova the rush, blink out of the ring, finish at range. "Every mage dies once. Practice the not-dying part first." | in one fight: `use_ability` frost_nova `min_targets:2` → `use_ability` blink → `kill` boar ×3 | W |
| 5 | 4 | **What the Shield Is For** | `mana_shield` (55 absorb) | Duel the graveyard skeleton_mage — caster vs caster, its 15-dmg bolts against your 80 hp. Shield up before its second volley or eat dirt. | `use_ability` mana_shield → `kill` skeleton_mage ×1 | C |
| 6 | 5 | **Cinderfall** ⚑ | `cinderfall` (12-meteor rain ult) | COME OF AGE: the old beacon cage on the walls, unlit since the Emberfall. Ruxandra unseals the candle-house long enough to hand you the ember-script *she* copied — "Read nothing. BURN beautifully." Staged L4 elite skeleton_mage + adds swarm the beacon stairs; cinderfall the landing; light the beacon with the last meteor. | `reach` beacon → `use_ability` cinderfall `min_targets:2` → `kill` elite → `talk` Ruxandra | H |

⚠ **Symptom (Q5 night, unremarked):** Ruxandra's one lit candle burns violet for a breath —
and leans east, windless, all night. She watches it. She does not relight it white.
**Come-of-age reward:** uncommon i5 **"Ruxandra's Snuffer"** (off-hand: mana 12 + mana regen
tick) — "The bravest thing she owns is the thing that puts fire OUT." Title: *Keeper of the
Violet Flame*. `follow_up` → Iosif.

---

### 4.4 PALADIN — "The Lantern on the Hill" (mentor: Prior Costin)
*Kit: hammer_blow · holy_smite · judgment · consecration · lay_on_hands · divine_shield ·
sacred_bulwark · dawnbreak. Start unlocked: hammer_blow + holy_smite.*

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **The Weight of It** | `hammer_blow` (100° arc) | The chapel's fallen roof-beams, blessed once, must be broken for the pyre — hammer-work with witnesses (three pell-posts arc'd on the chapel steps). | `use_ability` hammer_blow ×6 `min_targets:2` | W |
| 2 | 2 | **Light That Reaches** | `holy_smite` (220px bolt) | Skeletons shamble up the chapel path at dusk; Costin forbids you the steps: "The hill is consecrated by BEING defended at range. Meet nothing at the door." Smite three before any reaches the gate line. | `use_ability` holy_smite `enemy_type:skeleton` ×3 → `kill` ×3 | C |
| 3 | 3 | **Hold the Ground** | `judgment` + `consecration` (aimed root ring + ticking holy ground) | The path fork below the chapel: consecrate the fork (ground denial), judge the guarded skeleton_warrior in place when it detours. First aim-mode; first zone-control think. Reward: **common i2 "Votive Hammer-Wrap"**. | `use_ability` consecration `within:fork` → `use_ability` judgment `enemy_type:skeleton_warrior` → `kill` ×1 | C |
| 4 | 3 | **Mend What You Spent** | `lay_on_hands` (50 heal) | The Long Vigil: a night watch over the chapel yard (T6 `vigil`, ≤2/zone budget: this is RH's second and last). Cold-script frost saps hp through the small hours (scripted DoT); Lay on Hands is the lesson AND the prayer. | `vigil` chapel yard, night, 60s → `use_ability` lay_on_hands during vigil | H |
| 5 | 4 | **The Two Vows** | `divine_shield` + `sacred_bulwark` | Carry the chapel's reliquary chest through the graveyard's bone-yard row while skeletons wake (scripted ambush, no drop-fail): shield for the first wave, bulwark for the crossing. "One vow keeps you standing. The other keeps you WALKING." | `deliver` reliquary + `use_ability` divine_shield ×1 + sacred_bulwark ×1 en route | H |
| 6 | 5 | **Dawnbreak** ⚑ | `dawnbreak` (55-dmg pillar ult, aimed root) | COME OF AGE: the crypt door under the chapel has been knocking, politely, from inside. Costin opens it at first light. A grave-cold **elite** brute leads four out. Dawnbreak the doorway — the pillar as a drawn line: *not one step onto the hill*. | `reach` crypt at dawn → `use_ability` dawnbreak `min_targets:2` → `kill` elite → `talk` Costin | H |

⚠ **Symptom (Q4's vigil, the one thing that happens):** the chapel bell, struck once for
matins, rings its note — and underneath it, a second note nobody cast the bell to hold. Costin's
hand stays on the rope a long time.
**Come-of-age reward:** uncommon i5 **"The Prior's Spare Lantern"** (off-hand: armor 1 + hp 8 +
mana 6) — "He keeps two. He has always kept two. Now you know why." Title: *Lantern of the
Ashen Chapel*. `follow_up` → Iosif.

---

### 4.5 NECROMANCER — "Tucked Back In" (mentor: Gravekeeper Voicu)
*Kit: soul_bolt · drain_life · withering_curse · bone_nova · grave_grasp · bone_armor ·
raise_dead · soul_harvest. Start unlocked: soul_bolt + drain_life.*

Voicu's law, spoken in Q1 and enforced by the whole chain: **"Borrow. Never keep. And always
tuck them back in."** (class lore verbatim). This is the game teaching, at level 1, the exact
restraint mechanic the Bloodstone will spend 60 levels testing.

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **A Future Client** | `soul_bolt` (fast bolt) | Voicu, who has been expecting you ("I keep a ledger of aptitudes"): put down three restless ones from the fence line — the dead deserve to not be chased. | `use_ability` soul_bolt ×6 → `kill` skeleton ×3 | C |
| 2 | 2 | **Take Only What's Owed** | `drain_life` (bolt + 35% lifesteal) | Voicu sends you in "tired" — a scripted draught drops you to half hp before the guarded skeleton_warrior fight. Drain is how you leave the yard standing. "It flows one way in the end. Practice the direction." | `use_ability` drain_life `enemy_type:skeleton_warrior` ×2 → `kill` ×1 | C |
| 3 | 2 | **Soil and Circle** | `withering_curse` + `bone_nova` (aimed DoT ring + self slow-ring) | Diggers (boars) root up the paupers' row nightly: curse the torn soil where they feed, nova the ones that break for you. Ground-cast + self-peel in one lesson. Reward: **common i2 "Sexton's Trowel"**. | `use_ability` withering_curse `within:paupers_row` → `use_ability` bone_nova `min_targets:2` → `kill` boar ×3 | W |
| 4 | 3 | **None Walk Out** | `grave_grasp` (aimed 1.5s root) | One of the risen doesn't fight — it *leaves*, walking east at a listener's pace (scripted fleeing mob). Grasp it before the gate line. Voicu, quietly: "That one wasn't restless. That one was CALLED. Note the difference in your ledger." | `use_ability` grave_grasp on the walker before `reach`-line → `kill` ×1 | H |
| 5 | 4 | **Polite Company** | `bone_armor` + `raise_dead` (absorb buff + skeleton minion) | Raise Old Man Sava — with his family's leave, Voicu obtained it, it took a YEAR — to stand one last watch against the warband trickle. Armor up, let Sava hold the line, bolt over his shoulder. Then the quest's true objective: **tuck him back in** (`use_item` shroud-cloth at his grave). | `use_ability` bone_armor + raise_dead → `kill` skeleton ×4 → `use_item` shroud at grave | H |
| 6 | 5 | **Soul Harvest** ⚑ | `soul_harvest` (14-bolt rain ult) | COME OF AGE: the whole east row wakes at once — five up and an **elite** grave-cold brute among them, all of them *listening*, none of them angry (shipped Q1's dread, escalated). Harvest the row; put every one of them back. Voicu signs your page in his ledger of aptitudes: "Warden. Same as mine." | `reach` east row at night → `use_ability` soul_harvest `min_targets:3` → `kill` elite + ×4 → `talk` Voicu | H |

⚠ **Symptom (Q6 aftermath):** one re-filled grave stays warm to the hand till morning. Voicu
plants rue on it and moves his ledger to a locked drawer.
**Come-of-age reward:** uncommon i5 **"Voicu's Ledger-Page"** (trinket: mana 10 + hp 6) —
"Your aptitudes, in his hand. He gives every warden their page. He keeps the book." Title:
*Warden of the Old Graves*. `follow_up` → Iosif.

---

### 4.6 ROOKWARDEN — "Chosen at the Gallows-Tree" (mentor: Old Petra)
*Kit: loosed_arrow · piercing_shot · snare_trap · raven_dash · hunters_mark ·
rook_companion · arrow_storm · storm_of_feathers. Start unlocked: loosed_arrow + piercing_shot.*

Composes with shipped Q4 (`what_the_rooks_saw`, Petra's quest): the chain is scheduled so
its Q5 lands after Q4's camp scout — the rooks that watched the warband now watch *you*.

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **Where the Rooks Point** | `loosed_arrow` (260px, fast) | Petra's rooks land on five fence-posts in sequence; hit each mark within its perch-window. "I don't teach aim, dear. I teach LISTENING with your eyes." | `use_ability` loosed_arrow ×5 `within:marks` | W |
| 2 | 2 | **Through, Not At** | `piercing_shot` (420-speed, 300px, splash) | The boar-run at full gallop: take the lead charger *through* the run's mouth at maximum range — the shot that arrives before the argument does. | `use_ability` piercing_shot `enemy_type:boar` ×2 → `kill` ×2 | W |
| 3 | 3 | **The Ground Fights Too** | `snare_trap` + `raven_dash` (aimed root+slow ring / feather dash) | Mudwolves lope the treeline in threes (stalkers — faster than you: COMBAT_PACING's kiting lesson). Trap the run, dash the gap, shoot the held. Reward: **common i2 "Waxed Bowstring"**. | `use_ability` snare_trap `within:wolf_run` → raven_dash ×1 → `kill` wolf ×3 | C |
| 4 | 3 | **The Marked Boar** | `hunters_mark` (+35% damage window) | Old Bristle, a named tough boar rooting the gallows-hill barrows. Mark before the pull; the window is the kill. "Pick your bird before you loose the flock." | `use_ability` hunters_mark → `kill` old_bristle ×1 | W |
| 5 | 4 | **One of Theirs** | `rook_companion` (raven minion) | After the camp scout (prereq: `what_the_rooks_saw`), a rook follows you home and will not leave. Petra: "That's not a pet, dear. That's a POSTING." Send it against the treeline skeletons; fight beside it. | `use_ability` rook_companion → `kill` skeleton ×4 with companion active | C |
| 6 | 5 | **The Parliament** ⚑ | `arrow_storm` + `storm_of_feathers` (rain volley + radial ult) | COME OF AGE: at the gallows-tree at dusk the whole parliament descends — and goes silent at once ("the way a room does when it wants to watch," per shipped Q4A). What they watched for arrives: an **elite** thread-touched brute with a wolf pair, drawn to the tree the rooks would never roost over. Storm the pack; feather-burst the ring. The parliament lands on the gallows-arm — first time in living memory. You are chosen. | `reach` gallows-tree at dusk → `use_ability` arrow_storm `min_targets:2` → storm_of_feathers `min_targets:2` → `kill` elite + ×2 → `talk` Petra | H |

⚠ **Symptom (standing, all chain):** the rooks will not land on the gallows-tree — shipped
Q4's grammar, made the chain's spine. The Q6 landing is the payoff: the tree is clean *because
of you*. (What the rooks watched — the thing under the tree the elite was digging toward —
Petra does not say. Her mother's rule: never tell the bird what it saw.)
**Come-of-age reward:** uncommon i5 **"Gallows-Feather Band"** (head: speed 3% + crit 1%) —
"One feather from every warden's first parliament. Petra's is in there somewhere." Title:
*Rookwarden of the Hollow*. `follow_up` → Iosif. (Synergy: if `ravens_eye` was Q4A's reward,
Petra name-checks it: "Two of their gifts on one belt. They mean to KEEP you, dear.")

---

### 4.7 DRUID — "The Forest Names Its Price" (mentor: Baba Iva)
*Kit: maul · gale · thornroot · stormbolt · rejuvenation · spirit_beast · bear_form ·
tempest. Start unlocked: maul + gale.*

| # | L | Quest | Teaches | The designed situation | Objectives | Tone |
|---|---|---|---|---|---|---|
| 1 | 1 | **Paw Before Palm** | `maul` (115° arc) | The blight-brambles choking the wildwood gate must be torn out by the armful — maul's wide arc as pruning. Iva watches from a stump: "The wood doesn't want your manners. It wants your WEIGHT." | `use_ability` maul ×6 `within:bramble_gate` | W |
| 2 | 2 | **The Wind's Errand** | `gale` (gust orb, 26px splash) | Carrion birds mob the deer carcass rows two at a time; the gust takes pairs. But note WHY the deer died in rows — Iva won't say yet. | `use_ability` gale `min_targets:2` ×2 → `kill` ×3 | C |
| 3 | 3 | **Root and Sky** | `thornroot` + `stormbolt` (aimed 1.6s root + aimed 200px strike) | The combo lesson: a mudwolf stalker circles faster than you walk. Root it at range, and while it is HELD, bring the sky down on the spot. First cast-range-200 aim. Reward: **common i2 "Rootbound Charm"**. | `use_ability` thornroot → stormbolt on the rooted target (within root window) → `kill` wolf ×2 | W |
| 4 | 3 | **What the Walk Costs** | `rejuvenation` (HoT) | The Bramble Walk: the wildwood's inner path scores you as you pass (scripted thorn DoT corridor — the forest's toll). Rejuvenation is how druids pay it walking. | `reach` heartwood via corridor + `use_ability` rejuvenation during the walk | C |
| 5 | 4 | **The Two Shapes** | `spirit_beast` + `bear_form` (wolf minion + self buff-form) | Iva's test of company and self: call the spirit wolf, take the bear's weight, and hold the heartwood clearing against the boar sounder that's been gorging on the warm soil. "One shape beside you, one shape INSTEAD of you. The wood accepts both. The town will accept neither — remember that kindly." | `use_ability` spirit_beast + bear_form → `kill` boar ×4 both active | W |
| 6 | 5 | **Tempest** ⚑ | `tempest` (12-strike storm-rain ult) | COME OF AGE: the wood names its price (class lore verbatim: "the forest, as it always does, will name its price"). The grove ring's oldest oak splits — out comes an **elite** blight-fattened brute with wolf attendants, wearing the warm soil like a coat. Tempest the ring. Then the price: Iva asks for your Q3 charm back — the wood keeps a token of every warden it arms. You leave lighter. That's the point. | `reach` grove ring → `use_ability` tempest `min_targets:2` → `kill` elite + ×2 → `use_item` return the charm → `talk` Iva | H |

⚠ **Symptom (Q2/Q6 frame):** the grove ring's trees stand even-spaced — TOO even, like
surveyors' pins (the Stonepath wolf-grammar, arriving early and quiet). Iva has known for
years. "Old walls remember being planted. So does whatever measured them."
**Come-of-age reward:** uncommon i5 **"Heartwood Sprig"** (trinket: hp 8 + hp-regen tick) —
"It is still green. It will still be green in winter. Do not ask it how." Title: *Warden of
the Wildwood*. `follow_up` → Iosif.

---

## 5. THE CONVERGENCE — "Out the East Gate" (shared epilogue beat, all classes)

Not a seventh quest — a shared scripted turn-in staging. Every Q6 `follow_up` force-starts
**`rh_class_gate`** (giver "", auto-offered, `qtype:"class"`, 1 objective):

- `talk` **Gatewarden Iosif**, whose page is class-aware via a one-line insert ("Codrin
  vouched for you. He doesn't." / "Petra's birds have been bragging." / "Voicu says you're a
  warden now. He said it like a WARNING." — 7 variants).
- Iosif's closer is identical for all seven — the WoW-Classic "leaving Northshire" beat:
  *"The Hollow's small, and you've outgrown the small troubles. Emberfall Road, east. The
  Bent Oar keeps a board of the big ones. …Walk it in daylight. And come back sometimes —
  walls remember who they held."*
- Completion sets `flag: came_of_age_<class>` (referenced later per interconnection rule 6:
  the L15 journey quest opens on it, and one Act III Archive file quotes it back — the stone
  logged your graduation).
- Rewards: 0 XP, 0 gold — this is a door, not a job. The east-gate world pin lights the
  Bent Oar waystation breadcrumb (ZONE_QUEST_MATRIX Zone-1 "out" edge, verbatim).

Mira's finale (`one_who_listens`) remains untouched and un-gated — if the player finishes it
before the class chain, the whisper lands mid-training (fine: dread is ambient); the intended
order simply emerges from level gating.

---

## 6. THE JOURNEY QUESTS (the other 4 per class — where the far-kingdom fantasy lives)

One quest at each milestone; level chosen inside the destination zone's band
(ZONE_QUEST_MATRIX brackets). These honor QUEST_ARCHITECTURE's braiding mandate verbatim
(necromancer=Thread, rookwarden=rook/Petra's line, druid=Gift/soil, paladin=Transcub) AND the
prompt's zone instincts, now at legal levels. Full authoring belongs to each region batch;
one-line hooks are contracted here so the mentors can foreshadow them.

| Class | ~L15 (West band) | ~L25 (East band) | ~L35–40 (South band) | ~L50 (North band) |
|---|---|---|---|---|
| **Warrior** | Angel Wings: drill Fielderine's under-fed levies — Codrin's old regiment's colors hang there | Ridge-keep caravanserai: hold a pass breach solo (bulwark exam) | **Sangeroasa pit-yards (L40):** fight the killing-floor circuit; refuse (or don't) the Debt Pit's standing purse | Gravemark: a skeleton warband still drilling Codrin's cadence — put his old company to rest |
| **Rogue** | Riverfork: Ludmila's smuggler queen owes Ilinca a lamp-debt | **Blestem fog-alleys (L25):** the Lower Market prices your Q5 packet choice — sealed or read, it KNOWS | Sangeroasa: lift Ilion's audit page without becoming an entry in it | Black Night: steal nothing — walk the still market unheard (stealth exam) |
| **Mage** | Angel Wings: the council's confiscated ember-script cache — Ruxandra's handwriting is in it | Blestem: the listening-walls replay YOUR voice; unlearn being overheard | Ashvents: cast where heat blinds the grammar (Hessik-method exam) | Threadlands: violet fire vs blue filament — Ilka forbids exactly one spell |
| **Paladin** | **Angel Wings chapel (L15):** the Ashen Chapel's mother-see; Costin's unsent letters to it | **Transcub Vale (L33):** the god who audited the self — re-consecrate with Ansel, or let the ivy finish | Sangeroasa: consecrate the Debt Pit rim (it does not take) | Gravemark: last rites at scale — the formatted graves reject the rite's grammar |
| **Necromancer** | Famine Fields: the hungry dead stay down if fed first — Voicu's method, scaled | Lichenreach: the Walled transmit — mercy is a necromantic act here | The Gift: what got up wears three armies' rust; file them home | **Black Night approach (L50):** Thread-work under Ilka — Voicu's ledger has a page HE never showed you |
| **Rookwarden** | **Border rookery (L15, Grey Marches):** Petra's line kept a rookery on the fog-line — restaff it | Whisper Passes: rooks vs listening-posts — whose network is older? | Basaltfang: the pack hunts with dogs; you hunt with weather | Listening Steppe: the corridor of sky the ravens refuse — Petra's mother charted it |
| **Druid** | Grey Marches: grey-by-the-acre — the wildwood's sister forest is dying inside-out | Transcub: ivy is also a forest deciding — arbitrate | **The Gift (L40):** soil grown from the dead — the wildwood's warm-ground question at scale | Threadlands: spirit beast vs thread-shell — the wood's answer to the Thread |

---

## 7. ENGINE DELTA LIST (all additive, ordered by dependency)

1. **`use_ability` objective kind** (§2) — `quests.gd` matcher + one `Quests.report_ability()`
   call site in `player.gd`'s cast/hit resolution. The `context` sub-checks reuse existing
   facts (DayNight.is_night, hit lists, positions).
2. **Ability unlock gating** (§2) — `player.unlocked_abilities`, `rewards.unlock_abilities`,
   level fallback, hotbar padlock rendering. Absent-key = all unlocked (old saves safe).
3. **`class_lock` availability check** — already specified in QUEST_ARCHITECTURE schema v2
   engine-delta #2; this document is its first consumer. Ship together.
4. **Mentor NPCs** — 3 additions to `npc_data.gd` (`rh_ilinca`, `rh_ruxandra`, `rh_costin`,
   `rh_iva` = 4 new; Codrin already rostered in NPC_CAST) + class-conditional bark line +
   Magda's 7-variant pointer line. Sprite picks must avoid the player-class sheet/variant
   combos listed at the top of `class_defs.gd`.
5. **Anchors** — `town_builder.gd`: drill-yard, fog-alley, candle-house + beacon, chapel +
   crypt door; `wilderness` builder: gallows-tree, wildwood eaves + grove ring, boar
   culvert/wallow/run. ALL quest positions PLACEHOLDER → `Quests.override_pos()` at build
   (shipped pitfall; see quest_defs.gd INTEGRATION notes).
6. **Staged elites** — 7 one-off spawn configs (L4, `rank:"elite"` per COMBAT_PACING §4
   formulas: ≈ 5× hp of the L4 normal ≈ 1,100 hp, damage ×1.35), spawned by quest-state
   trigger like Q4's orc camp. Named: Palisade Wight, the Three Guests, the Beacon-Keeper,
   the Crypt Brute, the East-Row Elder, the Digger-Drawn, the Blight-Fattened.
7. **New enemy fact** — `raven` minion family for rook_companion already referenced by
   `class_defs.gd`; confirm `enemy.gd` sheet family exists before Q5 rookwarden ships
   (integration flag — same class of gap as Q4's `orc_shaman` note).
8. **Items** — 7 common i2 tools + 7 uncommon i5 identity pieces (stats above, budget per
   ITEM_PROGRESSION formulas) + `pixel:` icons; 2 quest props (rogue packet, druid charm).
9. **Phase 2 (optional, later):** promote candle-house/chapel/cellar pockets to 64×48
   interior micro-maps via `change_map` — pure polish; no quest def changes needed (anchors
   just move indoors via override_pos).

---

## 8. ACCEPTANCE CHECKLIST (per intro quest — extends QUEST_ARCHITECTURE §7)

- [ ] All schema v2 ★ keys; id `rh_<class>_<step>`; `qtype:"class"`, `class_lock` set.
- [ ] The taught ability is REQUIRED by the situation, not just counted (§2 rule 1);
      one new verb per fight (rule 2); opponent archetype ascends the §2 ladder.
- [ ] Mentor dialogue states the ability's mechanical identity once, in voice.
- [ ] XP matches the 40/50/60/70/80/100 schedule; rewards match the i2/i5 schedule.
- [ ] Chain carries exactly ONE `symptom` villain beat, environmental, wordless, ⚠-marked.
- [ ] Q6 ends: elite + ultimate + mentor beat + item + title + `follow_up` → `rh_class_gate`.
- [ ] No clean win at the capstone: the reward is real and the aftermath re-prices something
      (warm grave, reformed fog, second bell-note, returned charm…).
- [ ] Tone tags inside the Border budget after summing with the zone's 24 quests.
- [ ] All positions bound via `override_pos`; no literal coordinates trusted from this doc.

---

## 9. OPEN QUESTIONS / PRODUCTION FLAGS

1. **QUEST_ARCHITECTURE §2 amendment** must be written back into that doc's class-quest row
   ("6 intro L1–5 + 4 journey" replacing "2 per milestone L10–50") once this doc is accepted —
   single-line edit, count unchanged.
2. **NPC renames** (Magda/Anton/Voicu per NPC_CAST §1) are assumed throughout; if the rename
   ships after this content, the mentor dialogue must use the OLD display names at authoring
   time and be swept in the rename pass.
3. **`vigil` objective kind** (paladin Q4) is schema v2 — if the paladin chain ships before
   the v2 engine pass, substitute a night `reach` + `use_ability` pair (degrades cleanly).
4. **Elite TTK sanity** — 1,100 hp vs an L4-5 player (~30–40 DPS with cooldowns) ≈ 25–30 s:
   long for the bracket. If playtests drag, drop elites to rank ×3.5 hp (~770). The ultimate
   should visibly delete ~15–20% of the bar — that's the fantasy being sold.
5. **Rookwarden Q5 prereq** on `what_the_rooks_saw` creates the one cross-chain dependency;
   if players out-level Q4, Petra offers a fallback scout objective (same camp, thinner).
