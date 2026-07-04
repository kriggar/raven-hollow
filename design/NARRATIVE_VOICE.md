# NARRATIVE VOICE — Tolkien Wonder × Draconia Dread
**The style guide for every word the game shows the player. Owner mandate (MANDATES.md · Narrative & Cinematics): *"STORYTELLING VOICE: Tolkien / LotR register — wonder and awe — braided with Draconia dread (style guide + all quest text follows it)."***

Sources of truth: `c:/Users/vstef/Desktop/rpg/_lore_extract.txt` (the bible's own prose — Parts I, IV, XI),
`design/QUEST_ARCHITECTURE.md` (tone law + tonal budgets), `design/QUEST_EXEMPLARS.md` (the 24-quest
quality bar), `scripts/quest_defs.gd` / `scripts/items.gd` / `scripts/zone_defs.gd` (shipped text surfaces),
`WORLD_PLAN.md` (the 9 live zones + canon ground rules).

---

## 0. THE BRAID — one mechanism, two lights

The bible's prose law says: *"The noir register rules the prose. Dry, tired, unillusioned… Never purple.
Never a hero's swell."* The owner's mandate says: *Tolkien — wonder and awe.* These are not in conflict,
and the whole guide hangs on understanding why:

> **Tolkien's wonder and Draconia's dread are the same fact in two lights: the world is vast, old,
> and it remembers. Pointed at the land, that fact is wonder. Pointed at you, it is dread.**

Tolkien never produced awe with adjectives. He produced it with **deep time** ("no man now living
remembers"), **named things with histories** (Weathertop was Amon Sûl, and it burned), **geographic
reverence** (roads and rivers as elders, not scenery), and **understatement** (the most terrible things
said most plainly). Every one of those techniques is *restraint* — which is exactly what the bible's
grimdark law demands. We do not add purple to Draconia. We add **memory at scale**: the player should
constantly feel that every ruin, river and road existed long before them, will outlast them, and has
already seen this happen — *"the old wildwood that remembers Raven Hollow older than its walls."*

The braid rule in one sentence: **the wonder belongs to the world; the dread belongs to the last
clause; the warmth belongs to the people.**

The two epigraphs that calibrate everything — hold them side by side and write between them:

- Tolkien's light: *"Still round the corner there may wait / a new road or a secret gate."*
- Draconia's answer (canon): *"Everything good is temporary. That's what makes it good."*

---

## 1. THE THREE REGISTERS (plus the one that isn't ours)

Every string in the game speaks in exactly one of three registers. Tag it, audit it, never blend
mid-sentence without intent.

### R1 — HIGH-MYTHIC (the World's voice)
The chronicler telling of Middle-earth: measured, reverent, old. This is where the Tolkien mandate
lives. The world's narration treats the land as an elder relative — capable of patience, memory,
and grudges — and treats deep time as the primary source of awe.

**Applies to:** zone-intro banners · first-footfall journal entries · `arrive_note` fields · quest
`summary` and completed-`note` journal text (the journal is a chronicle, not a to-do list) ·
lore books and inscriptions · act-chapter cinematic narration · flavor text of storied/named items ·
`finale_pages` stage directions.

**Sounds like:** *"Men named the river for its ore. It has run the color of old blood longer than
the name."*

**Its law:** wonder must be earned by specificity (a name, a number, a history) and must turn — the
final clause re-prices the awe with cost or warning. Mythic never gushes. Mythic *counts*.

### R2 — HEARTH-PLAIN (the People's voice)
The bible's shipped register, unchanged: warm, concrete, tired, occasionally funny the way
gravediggers are funny. Villagers, farmers, innkeepers, keepers of small lights. In cities this
register dries out into **ledger-noir** (Blestem clerks, the Collector, Sabira) — same family, less
warmth, more paperwork. The dialogue test from the bible still governs: *"would the Collector say
it this dry?"*

**Applies to:** ALL NPC spoken dialogue (`offer_pages`, `active_pages`, `turn_in_pages`,
`aftermath`) · barks · vendor lines · daily-quest text.

**Sounds like:** *"My grandmother had a saying: when the well goes copper, count your candles.
She never laughed when she said that one."* (shipped, `well_went_copper` — already perfect; do not
mythologize lines like this.)

**Its law:** people never speak in the mythic register — except in the rare, deliberate moment when
a plain speaker *reaches* for it and half-fails ("The Pause is a bookmark, traveler — and lately I
hear pages turning"). That reach, from a plain mouth, is the most powerful tool in the game.
Budget: at most one reach per quest chain.

### R3 — THE STONE (the villain's voice — quarantined)
Flat, patient, second person, clerical. Deeds instead of names ("the one who buried the knife").
Latinate and logistical where everything else is earthbound: *entry, arranged, collected, pending,
rest.* **The stone is never mythic and never warm.** It gets no wonder, no metaphor, no rhythm.
This quarantine is load-bearing: the mythic register makes the world feel alive; the stone's
register must feel like the absence of everything the other two registers are.

**Applies to:** `villain_beat` text of all six kinds · second-person Pit inscriptions ·
the `address` beats · Underlanguage-adjacent media (which are never translated — hard rule).

**Sounds like:** *"Small. Temporary. Wrong little things. We have an entry for you now. It is
short. Entries grow."* (shipped, QUEST_EXEMPLARS MSQ-03.)

### Register assignment table (audit key — every string gets one tag)

| Text surface | Register | Notes |
|---|---|---|
| Zone banner + first-footfall entry | R1 | §4 formats |
| `arrive_note`, `summary`, completed `note` | R1 | the journal is the chronicler |
| Objective tracker `text` | R1-lite | ≤10 words; one mythic detail max |
| NPC dialogue, barks, aftermath | R2 | warmth in villages, noir in cities |
| Item `flavor` | R1 for storied items · R2 for humble gear | both budgets in §3 |
| Lore books, inscriptions, waystones | R1 (body) + R2 (marginalia) | §6 formats |
| Tooltips (mechanical text) | plain UI voice — no register | numbers stay sacredly clear |
| Villain beats, Pit inscriptions | R3 | quarantined |
| Cinematic narration (D2-style) | R1, weary variant | the narrator has *seen* it |

---

## 2. VOICE PRINCIPLES (the ten laws)

1. **Deep time is the engine of wonder.** Every zone, landmark and named item should imply an age
   greater than the player's business with it. Measure time concretely: *six hundred years, two
   winters, since before the walls, no keeper now serving remembers.* Vague "ancient" is banned;
   counted time is holy (the bible counts everything: rows of twelve, 47 years, three notes).

2. **Geographic reverence.** Roads climb, rivers remember, hills watch, fords keep their own
   counsel. The land is the game's true elder cast. Tolkien walked his reader down every road;
   we do the same — a journey is narrated as lineage ("the old road that was a king's road once").
   Never call the land "terrain," never describe it as an obstacle course.

3. **Named things with histories.** A name plus an epithet plus one clause of history: *the Bent
   Oar, the last warm hearth before it gets bad — and it has been the last for longer than any
   keeper can say.* Naming is how wonder and dread both accrue. If a thing matters, name it; if
   it is named, it has a past; if it has a past, one clause of that past shows.

4. **The dread turn.** In R1, the final clause re-prices the wonder. Awe opens the sentence;
   cost closes it. *"The stair goes down warm."* This is the braid mechanically: never wonder
   without a bill, never a bill without wonder having been real first.

5. **Understatement is the loudest volume.** The most terrible facts are delivered most plainly
   (Tolkien: "and they cast him down"; the bible: "no wound, clean fingernails, satchel still
   sealed"). No exclamation points in R1. No adjectival stacking. If a sentence feels big, cut
   its biggest word.

6. **Warmth is load-bearing and stays plain.** The cheerful budget (QUEST_ARCHITECTURE §4) is
   delivered in R2 only. The small warm thing — a stew, a stick, a tune nobody taught her — must
   stay small and concrete so its loss means something. Mythologizing warmth kills it.

7. **The stone is quarantined** (§1 R3). One register may never borrow from another downward:
   villagers may reach up toward myth (rarely, at cost); the mythic voice never reaches down into
   the stone's clerical flatness except when quoting it — and quoting it is always an event.

8. **Curiosity is written as temptation.** The prose itself performs the villain's grammar: when
   R1 describes an inscription, the sentence should *pull* ("the angles pull the eye like a hook
   pulls a lip" — shipped) and then model restraint ("you look at your boots all the way out").
   The narration teaches the player the survival reflex the quests will bill.

9. **No clean sentences about clean wins.** The tone law (canon, Part XI) applies at sentence
   level: journal `note` fields carry residue; victories are recorded with their price attached;
   the chronicler is honest the way Vasile is honest.

10. **Second person is rationed.** `arrive_note`s may use "you" (the chronicler at your shoulder).
    The stone uses "you" as a weapon. NPC dialogue uses "you" naturally. Zone banners and lore
    books never do — they are older than the reader and address no one.

---

## 3. SENTENCE RHYTHM & VOCABULARY RULES (archaic-lite)

### Rhythm
- **The Long-Then-Short rule.** R1's signature cadence: one rolling sentence (often with "and"
  chains — polysyndeton is the Tolkien heartbeat), closed by a blunt sentence of six words or
  fewer. *"Men have drawn water over these carvings for lifetimes and never once seen them. They
  are seen now."*
- **Inversion sparingly.** One inversion per zone's worth of text, maximum ("Old is that wood" —
  earned once, ruined twice). Standard word order otherwise.
- **"For" and "and" as conjunctions** are welcome in R1; semicolons are welcome; em-dashes carry
  the dread turn. Avoid parenthetical asides in R1 (those belong to R2's tired humor).
- **Rhetorical questions: never in R1.** The chronicler states. Questions belong to people (R2)
  and, chillingly seldom, to the stone (R3).

### Vocabulary — the earthbound palette
- Core lexicon is **Anglo-Saxon and concrete**: stone, hearth, furrow, kerb, ford, thatch, rook,
  spade, loaf, lantern. Latinate abstraction (*situation, utilize, location, experience, process,
  significant*) is banned from R1 and R2 — it is reserved, deliberately, for R3 (*entry, record,
  arranged, finalized, collected, pending*). The player's ear learns the villain by vocabulary
  temperature alone.
- **Romanian-inflected proper nouns** (Vetka, Blestem, Sângeroasă, Varcolaci, Iele, strigoi) are
  the world's spice — never invent new ones without the lore bible's phonology (consonant-heavy,
  -ka/-em/-oasa endings).
- **Allowed archaic-lite:** *of old · long ago · ere long is banned but "before the walls" fine ·
  no man now living · it is said · in the years when · thrice · fortnight · league (as distance,
  sparingly) · "the last of the …" constructions.*
- **BANNED archaisms** (the no-thee/thou law): *thee, thou, thy, thine, ye, 'tis, 'twas, o'er,
  e'en, oft, doth, hath, shalt, forsooth, verily, prithee, anon, hark, lo, behold, alas, whence,
  thither, wherefore, betwixt.* Also banned everywhere: *epic, awesome, mysterious, ancient
  (unqualified), eldritch, cyclopean, foreboding, ominous (show the omen instead), very, really.*
- **Banned constructions:** "little did they know" · "for now…" · any wink at the camera ·
  lore dumped as exposition ("As you know, six hundred years ago…") — depth is implied, never
  lectured (bible Pillar III: *depth over exposition*).

### Per-surface word budgets (validator-enforceable)
| Surface | Budget | Hard cap |
|---|---|---|
| Zone banner line | ≤ 14 words | 18 |
| First-footfall journal entry | 2–4 sentences | 70 words |
| Objective tracker `text` | ≤ 10 words | 14 |
| `arrive_note` | ≤ 60 words | 80 |
| Quest `summary` | ≤ 35 words | 50 |
| Completed `note` | ≤ 45 words | 60 |
| Item `flavor` | ≤ 16 words | 20 |
| Lore-book page | ≤ 120 words | 150 |
| Inscription / gravestone | ≤ 25 words | 30 |
| Travel prompt | "[E] " + ≤ 8 words | 10 |

---

## 4. ZONE-INTRO BANNERS — all 9 live zones (+ the 2 legacy maps)

**Format (integration spec).** Zone defs gain two keys; main.gd's location banner renders line 1
in Alagard gold (existing `display_name` behavior) and line 2 beneath it in smaller italic, shown
only on FIRST entry per save (repeat entries show name only — wonder must not become wallpaper).
The `first_footfall` paragraph is written into the journal's zone tab on first entry.

```gdscript
"banner": "…",          # ≤14 words, R1, shown under the zone name on first entry
"first_footfall": "…",  # 2–4 sentences, R1, journal entry on first entry
```

Banner grammar: **a fact about the land's memory, then the turn.** Never instructions, never "you".

### The nine built zones (`zone_defs.gd` built:true)

**THE IRON VEIN**
> *Men named the river for its ore. It has run the color of old blood longer than the name.*

First-footfall: "A bog-valley under leaning birches, where the slow river carries its rust down to
a sea no one here has seen. On the north bank stands the Bent Oar, the last warm hearth before it
gets bad — and it has been the last for longer than any keeper can say. The dust between the
bank-stones lies in fine parallel lines. It points upstream."

**VETKA**
> *Mud, thatch, and small warm doors. The oldest houses no longer face the fields.*

First-footfall: "Vetka has stood in the border fog since before the kingdoms took their names, and
it endures the way moss endures — by being too low for the wind to bother. The bread here comes
out flat and grey, and the baking-women have stopped apologizing for it. Beneath the town, it is
said, there is a chamber. Nobody says it twice."

**THE COPPER WELLS**
> *The moor gives water in many wells. All but one have learned a new taste.*

First-footfall: "Herdsmen sank these wells in a kinder age and cut their names in the wellstones,
and the moss took the names as it takes everything, without hurry. Now the farmsteads stand open
and unlooted — which is worse than burned — and the pilgrims on the old paths have stopped walking
anywhere in particular. One well still runs clean. Drink at that one, and count the others."

**THE STONEPATH**
> *All the roads of the four kingdoms cross here, among stones older than all four.*

First-footfall: "Whoever raised the standing stones raised them before roads existed to cross, and
the roads, when they came, bent to meet the stones and not the other way. Every carving here has
been growing since — every carving but one. At the crossroads leans a stone under a dead man's
handprint whose marks are fading, line by patient line. It is the only inscription in Draconia
that is getting shorter, and no one who studies it stays curious for long."

**THE GREY MARCHES**
> *No axe felled this forest. It goes grey from within, needle by needle.*

First-footfall: "This was the deep wood once, the green rampart of the west, and old men in the
Lowlands still call it the Greenmarch out of a habit their grandfathers should not have handed
down. The needles do not fall. They fade where they hang, as if the trees were being asked, one by
one, to stop agreeing to live. Somewhere among them a cult keeps a fire lit. The fire is not
what warms the ground."

**THE WESTERN LOWLANDS**
> *River-country, warm and uncounted — the fog itself thins here for the harvest.*

First-footfall: "The kindest land in Draconia: black river-mud, straight furrows, woodsmoke going
up from more chimneys than any clerk has ever managed to tax. The west has fed three kingdoms
through six hundred years of vigil, and it has done it the way rivers do everything — without
being thanked. Lately, some of the neighbors walk east and do not come back for supper. Their
families set a place anyway."

**ANGEL WINGS**
> *The poorest throne in Draconia — and the only one that never wanted the stone.*

First-footfall: "A capital of thatch and grain and too many people, sprawled where the Vein slows
and remembers it is a working river. There is no marble here and no spire; the queens of the west
built granaries instead, and one room in the northwest that no one speaks of loudly — a room
designed, stone by stone, around not using a power it keeps. On an orphanage wall by the east
district, children have pressed their hands in chalk. One print is faintly copper. It is here."

**THE FAMINE FIELDS**
> *Good soil, straight furrows, empty tables. The land did not do this.*

First-footfall: "These fields were the pride of the west within living memory — soil so willing,
the saying went, you could plant a walking-stick and harvest a chair. The furrows are still
straight. The soil is still willing. The hunger came anyway, and it moved through the villages
with a strange neatness, house by house in order, like a man reading down a list. The grave-rows
by the burned farmstead are counted and kept. Somebody counts them."

**RIVERFORK**
> *Two arms of the Vein meet here and go on together, toward a sea no map shows.*

First-footfall: "The delta country: bridges, toll-posts, and the smell of tar and wet rope — the
last working edge of the west before the water takes over. Everything that leaves the kingdoms
comes through Riverfork sooner or later, paying at the narrow places, the way it has since the
first plank bridge went across. Dockmen speak of grey piers far downriver where the light arrives
tired. They speak of them quietly, and they are never hiring for that run."

### The two legacy maps (map_registry.gd)

**RAVEN HOLLOW** *(town)*
> *The wildwood remembers a hollow here older than any wall men raised over it.*

First-footfall: "The rooks came before the founders and will outstay them, and the town has had
the good manners never to ask what they are waiting for. A small, warm, ordinary place: one inn,
one forge, one gravekeeper who has never once apologized. The wells went copper on a Thursday."

**THE EMBERFALL ROAD** *(wilderness)*
> *It carried lanterns east once, in the years when a lantern was enough.*

First-footfall: "The old road runs east out of the hollow under trees that have watched it since
it was a footpath, and it keeps its ruts the way an old man keeps his scars — proudly, and without
explaining. Travelers used to walk it singing. The woods remember the songs. Lately they lean in,
as if listening for the next verse, and the rooks will not land past the treeline."

---

## 5. TWELVE BEFORE/AFTER REWRITES (repo text, elevated)

Rules demonstrated: deep time (#1 law), the dread turn, Long-Then-Short, named things, budgets.
**Dialogue is mostly left alone on purpose** — the shipped R2 lines (Marta's grandmother, Vasile's
"I have never once apologized", the boots that "walked out the east gate once already") already
carry the voice; elevation targets the NARRATION surfaces (journal, arrive_notes, flavors, prompts).

**1 · Travel prompt** — `zone_defs.gd` iron_vein `east_gate`
- BEFORE: `[E] Vetka — the Border Village`
- AFTER: `[E] Vetka — the last warm doors before the moor`
- *Why:* the epithet does the work of a paragraph; "warm" is canon-loaded (warm is wrong — but
  hearth-warm is the thing being defended). Format law: `[E] <Name> — <earned epithet>`.

**2 · Travel prompt** — `zone_defs.gd` iron_vein `west_entry`
- BEFORE: `[E] The Emberfall Road`
- AFTER: `[E] The Emberfall Road — it carried lanterns once`
- *Why:* deep time in five words; the past tense is the dread.

**3 · Quest summary** — `quest_defs.gd` `well_went_copper`
- BEFORE: "The Ember Hearth's water tastes of copper — and it is not just Marta's well."
- AFTER: "Copper has come into the water of Raven Hollow — every well at once, as if the ground
  beneath had made up its mind. Marta's grandmother had a saying about wells like these."
- *Why:* the land gets agency ("made up its mind"); the chronicler cites the human memory-chain
  instead of explaining the omen.

**4 · Arrive note** — `quest_defs.gd` objective `q1_well`
- BEFORE: "Angular runes have been scratched into the wellstone — and someone took a charcoal
  rubbing of them, then dropped it. You pocket the page without looking at it too long."
- AFTER: "The wellstone was old when the town was young; men have drawn water over these carvings
  for lifetimes and never once seen them. They are seen now. Fresh-cut angular marks through the
  moss — and a charcoal rubbing of them, dropped in the mud, face-up. You pocket it face-down."
- *Why:* deep time before dread; Long-Then-Short ("They are seen now."); the face-up/face-down
  turn makes restraint physical (law 8).

**5 · Completed note** — `quest_defs.gd` `well_went_copper`
- BEFORE: "The wells still taste of copper. Vasile burned the runes unread and says the Pause is a
  bookmark, not an ending."
- AFTER: "The wells of the hollow run copper still, as they never did in all the long years of the
  Vigil. Vasile burned the runes unread — ash tells no one anything — and named the Pause for what
  it is: a bookmark, with something's thumb still in the page."
- *Why:* the chronicle measures against six centuries ("all the long years of the Vigil"); the
  residue rule — the note ends on the thumb, not the ash.

**6 · Objective tracker** — `quest_defs.gd` objective `q2_boars`
- BEFORE: "Cull boars in the wilderness"
- AFTER: "Cull the boars the generous ground has fattened"
- *Why:* even a tracker line can carry one mythic detail (canon: "the ground there's been…
  generous, lately") inside a 10-word budget. Trackers get exactly one such detail, never two.

**7 · Completed note** — `quest_defs.gd` `fresh_hay_old_bones`
- BEFORE: "The boars are culled — but wolf tracks ring Ansel's field, too many and too deliberate."
- AFTER: "The boars are culled and the field may yet see harvest. But tracks ring it now —
  dog-shaped, too large, too many, spaced even as fence-posts — as if something had walked the
  bounds of Ansel's land the way a buyer walks a purchase."
- *Why:* the closing simile is dread-through-commerce (the villain's clerical grammar bleeding
  into the world's voice — the one sanctioned direction of register bleed, and only as simile).

**8 · Arrive note** — `quest_defs.gd` objective `q4_camp`
- BEFORE: "Orcs — the start of a warband. Six at least, banners raised, and a shaman feeding
  something green into the fire that makes the smoke bend the wrong way."
- AFTER: "Orcs on the old road — a king's road once, that carried grain-carts under escort in the
  years when an escort was a courtesy. Six at least, banners up, a shaman feeding something green
  to the fire. The smoke leans against the wind, toward the town."
- *Why:* the road's lineage makes the trespass matter; "toward the town" sharpens the omen from
  strange to *aimed*.

**9 · Quest summary** — `quest_defs.gd` `one_who_listens`
- BEFORE: "Mira, the miller's daughter, walked to the far treeline at dusk and stands there —
  listening."
- AFTER: "At dusk Mira, the miller's daughter, walked past the road's end to the old wildwood —
  the wood that remembers Raven Hollow older than its walls — and stands at its treeline now,
  head tilted, listening."
- *Why:* the owner's own exemplar line, in place: the wood's deep memory turns a missing girl
  into a girl standing at the edge of something that predates her whole world.

**10 · Item flavor** — `items.gd` `emberfall` (legendary)
- BEFORE: "The blade that lit the hollow's last lantern."
- AFTER: "Forged for no one; named in one night. The hollow's last lantern failed — this did not."
- *Why:* legendaries get the full R1 treatment: an origin, a naming, a Long-Then-Short turn,
  sixteen words.

**11 · Item flavor** — `items.gd` `iron_cuirass` (rare)
- BEFORE: "Forged by the west gate, back when the smithy still rang."
- AFTER: "West-gate steel, from the years the smithy rang from dark to dark. It rings no longer."
- *Why:* counted time ("dark to dark") plus the blunt closer. Rare+ gear earns a history clause.

**12 · Item flavor** — `items.gd` `leather_hood` (common)
- BEFORE: "Smells of rain and old rope."
- AFTER: "Rain, old rope, and beneath them woodsmoke — the smell of every road that ever led home."
- *Why:* common gear stays humble (R2-adjacent) but may carry one note of the world's warmth;
  "led home" is the cheerful budget doing quiet work.

**Left standing, deliberately:** `travelers_boots` ("They walked out the east gate once already."),
`rusted_shortsword` ("The rust stops at the edge. Someone kept that much sharp."), Q5's note
("Mira remembers nothing. The ground is patient."). These are already the voice. The braid's first
discipline is knowing when the noir line IS the wonder — touch nothing that already hums.

---

## 6. LORE-BOOK & INSCRIPTION FORMATS

### 6a. Waystones & boundary stones (human, R1)
Carved imperative + counted measure + weathering stage direction (the stage direction is the
narration around the quote, not carved text).

> **THE VEIN FORD — TWO LEAGUES. WALK IT BY DAY.**
> *(The last three words were cut later, by a different chisel, deeper.)*

Rules: carved text in small caps; ≤12 carved words; the "different hand / cut deeper / added
later" convention is the format's dread mechanism — stones accrete warnings the way the world
accretes memory.

### 6b. Grave kerbs & headstones (R1, body-signage law honored)
Name · counted years · one specific thing they did · optional turn. Never epithets of praise —
the specific detail IS the praise (thesis: specificity beats perfection).

> **MAGDA VETKAN · 61 WINTERS · SHE FED SIX WINTERS OF STRANGERS AND ASKED ONE QUESTION.**

Faction grammar (WORLD_PLAN ground rules): human graves are *individual and missed* (as above);
Gravemark kerb-stones are *counted rows* whose inscriptions read as ledger lines — and late-game,
some kerbs answer the alchemical sight in colors. A kerb that has gone R3 reads like this, and
only like this:

> **ROW ELEVEN. TWELVE KEPT. ONE PENDING.**

### 6c. The stone's inscriptions (R3 — second person, the villain's mandate)
Per VILLAIN_ARC: second-person inscriptions escalate across acts. Format rules:
- Underlanguage is NEVER rendered. What the player reads is the stone's arrangement in plain
  speech — found chalked, scratched, or spoken through a medium that paid for it.
- Second person, deeds not names, present tense, no metaphor, ≤25 words, always ends on an offer
  of rest or a statement of bookkeeping. Never a threat — threats are hope.

> YOU LOOKED AT A RIVER AND REPORTED A COLOR.
> THE ENTRY IS SHORT. ENTRIES GROW.

> YOU ARE TIRED. THE GROUND HERE IS WARM. IT IS THE ONLY PLACE THAT WILL FEEL LIKE REST.

### 6d. Found lore books (R1 body + R2 marginalia)
The two-hands format — the book braids the registers physically:

```
[TITLE — "Of the …" / "A True Accounting of …" / "The Roads of …" naming conventions]
(condition line, italic: hand, age, damage — "Water-stained; the last signature is a child's.")

Body: 1–3 pages, ≤120 words each, R1 chronicle voice. Deep time, named things,
counted numbers. The body may know less than the player does — old books being
wrong in period-plausible ways is depth.

Marginalia: a second hand, R2 — tired, human, recent. The marginalia argue with
the body, date it, or grieve over it. One margin note per page, maximum.
```

Example page (findable in the Grey Marches):

> **Of the Greenmarch, and Its Keeping** *(the ink is good; the optimism has not kept as well)*
>
> The wood of the western march is the oldest living thing in Draconia, older than the four
> thrones and the roads between them, and it has been cut and has grown back nine times in the
> memory of the west. The forester's law is short: take the grey trees, leave the green, and the
> march will outlast your grandchildren's grandchildren.
>
> *— margin, later hand:* there are no green ones left past the second ridge. we stopped logging
> tuesday. nobody ordered it. you just don't swing an axe in a room where something is dying.

### 6e. Journal chronicle voice (`summary` / `note` fields)
The journal is written by the chronicler, not the player: R1, past tense for what happened,
present tense for what remains ("The wells run copper still"). `note` fields end on residue
(tone law). The journal never says "objective," "complete," or any UI word.

---

## 7. THE MASS-PRODUCTION STYLE PROMPT (paste verbatim into every quest-gen pipeline)

This block is the contract that keeps ~1000 quests on-voice. It is self-contained by design —
a generator given ONLY this block plus a quest brief must produce compliant text.

```text
You are the narrative voice of RAVEN HOLLOW (Draconia canon): Tolkien's wonder braided
with grimdark dread. The world is vast, old, and it remembers — pointed at the land
that fact is WONDER; pointed at the player it is DREAD. Warmth belongs to people.

REGISTERS — every string is exactly one:
• R1 WORLD (banners, journal summaries/notes, arrive_notes, books, inscriptions,
  storied item flavor): measured chronicle voice. Wonder through DEEP TIME (counted:
  "six hundred years", "two winters", "no keeper now serving remembers"), GEOGRAPHIC
  REVERENCE (roads climb, rivers remember, land has lineage and agency), and NAMED
  THINGS (name + epithet + one clause of history). Final clause re-prices the wonder
  with cost or warning (the dread turn). Signature cadence: one long rolling sentence
  (and-chains welcome), then a blunt sentence of ≤6 words. Understatement only; the
  most terrible fact said most plainly. No questions. No exclamation marks. "You"
  allowed only in arrive_notes.
• R2 PEOPLE (all NPC dialogue, barks): plain, warm, concrete, tired; gallows humor;
  ledger-dry in cities (test: "would the Collector say it this dry?"). People never
  speak myth — except ≤1 half-failed reach for it per chain. Kind things are small
  and specific (a stew, a stick, a tune). Cheerful lines are load-bearing: write
  them straight, never ironic.
• R3 STONE (villain beats, second-person inscriptions ONLY): flat, patient, clerical,
  second person, deeds not names ("the one who buried the knife"), Latinate ledger
  words (entry, arranged, collected, pending, rest), no metaphor, no warmth, never
  translated Underlanguage, always offers rest or states bookkeeping, never threatens.

VOCABULARY: earthbound Anglo-Saxon core (stone, hearth, furrow, ford, rook, loaf,
lantern). Latinate abstraction is FORBIDDEN in R1/R2 and reserved for R3.
BANNED everywhere: thee, thou, thy, thine, ye, 'tis, 'twas, o'er, e'en, oft, doth,
hath, shalt, forsooth, verily, prithee, anon, hark, lo, behold, alas, whence,
thither, wherefore, betwixt, epic, awesome, eldritch, cyclopean, foreboding,
ominous, mysterious, ancient (unqualified), very, really, "little did they know".
No lore-lecturing ("As you know…"). Depth is implied, never explained.

TONE LAWS (canon): dread is ambient and arrives in symptom order (ground warms →
wells copper → yeast dies → dust aligns → people "listen"); no quest text offers a
clean win — every completed-quest note ends on residue; curiosity is written as
temptation and restraint is modeled ("you pocket it face-down"); bodies are signage;
numbers are sacred (rows of twelve, 47 years, three notes) — count things.

BUDGETS (hard): banner ≤14 words · tracker text ≤10 · arrive_note ≤60 · summary ≤35 ·
note ≤45 · item flavor ≤16 · inscription ≤25 · book page ≤120.

FEW-SHOT CALIBRATION:
R1 banner: "Men named the river for its ore. It has run the color of old blood
longer than the name."
R1 note: "Vasile burned the runes unread — ash tells no one anything — and named
the Pause for what it is: a bookmark, with something's thumb still in the page."
R2 dialogue: "My grandmother had a saying: when the well goes copper, count your
candles. She never laughed when she said that one."
R3 beat: "Small. Temporary. Wrong little things. We have an entry for you now.
It is short. Entries grow."

SELF-CHECK before emitting (reject and rewrite on any failure):
1. Correct register per surface? No downward register bleed (myth never talks like
   the stone except in one-line similes; stone never warm)?
2. Every R1 passage: one concrete deep-time or named-history detail? Dread turn in
   the final clause? Long-Then-Short cadence present?
3. Zero banned words (regex the list)? Zero budget overruns (count words)?
4. Completed note carries residue? No clean win phrased as clean?
5. Would Tolkien recognize the reverence AND would the Collector tolerate the
   dryness? If either answer is no, cut the biggest word and try again.
```

### Validator spec (Engineering Law: auto-QA-able)
Ship `tests/voice_lint.py` alongside quest batches:
- **Banned-lexicon regex** over every string field (case-insensitive, word-boundary): the §3 list.
- **Budget counter** per field type (table in §3; field→surface mapping from schema v2).
- **R3 leak detector:** ledger words (*entry|arranged|collected|pending|finalized*) appearing in
  `offer_pages`/`turn_in_pages` of quests without a `villain_beat` → warn (allowed only as simile;
  human review).
- **Exclamation/question scan** in R1 fields (`summary`, `note`, `arrive_note`, `banner`) → fail.
- **Residue heuristic:** completed `note` fields ending in an unqualified positive ("saved",
  "safe", "victory", "peace") with no contrastive conjunction → warn for review.
- Reports per zone, feeding the standard improvement loop (validator → backfill → re-verify).

---

## 8. ACCEPTANCE CHECKLIST (per authored string — append to QUEST_ARCHITECTURE §7)

- [ ] Register tagged (R1/R2/R3) and correct for its surface (§1 table).
- [ ] R1: contains ≥1 counted-time or named-history detail; ends on a dread turn; no questions,
      no exclamations; Long-Then-Short cadence somewhere in the passage.
- [ ] R2: concrete and speakable aloud; passes the Collector-dryness test; any mythic reach is
      the chain's single budgeted one.
- [ ] R3: second person, deeds not names, ≤25 words, offers rest / states bookkeeping, zero
      metaphor, zero warmth, zero translated Underlanguage.
- [ ] Zero banned lexicon; within word budget (§3 table).
- [ ] Completed `note` carries residue; nothing clean is phrased clean.
- [ ] Names verified against `_lore_extract.txt`; new names follow bible phonology.
- [ ] `voice_lint.py` passes on the batch.

*The braid, restated once, for the door of the room where quests are written:*
> **Let the land be older than the story, the people warmer than the land, and the stone colder
> than both. Count the years. Say the terrible thing plainly. End on the price.**
