# QUEST EXEMPLARS — Raven Hollow / Draconia
**24 complete quests. This document is the quality bar for the ~1000-quest world.**
Every quest that ships must be writable in this template, in this voice, at this level of canon rigor.

Canon source: `../../../_lore_extract.txt` (Draconia Unified Lore Bible). Zone source: `WORLD_PLAN.md`.
Engine source of truth: `scripts/quest_defs.gd` (def shape), `scripts/quests.gd` (runtime API), `scripts/xp_system.gd`, `scripts/npc_data.gd`.

---

## 0. THE RULES THESE 24 QUESTS OBEY (and all 1000 must)

1. **No clean wins.** The best outcome costs the least of someone else (Lore XI). Every `note:` field must carry a residue.
2. **Dread is ambient, in symptom order.** Ground warms → wells copper → yeast dies → dust aligns → people "listen" → comprehension-death (Lore II §1). Never skip rungs. Never jump-scare.
3. **The villain arranges; it never forces.** Every Bloodstone touch-point must read as coincidence, weather, or the player's own good idea (Lore II §2: "the Bloodstone never forces. It arranges"). The stone teases the player across all 60 levels the way the inscription network threads all 40 zones — through *curiosity rewarded, then billed*.
4. **Curiosity is the vector.** Reading/copying/speaking the marks is always a real choice, always tempting, always costed. Reward players narratively for refusing to translate (Lore II design note).
5. **Bodies are signage.** Strigoi: rows of twelve. Varcolaci: worked-to-death, the pit. Iele: standing still. Humans: buried, missed (WORLD_PLAN ground rules).
6. **GoT means leverage, never romance-plot or sexual content.** Intrigue = information as currency, debts, burned assets, reasonable people with ledgers (Lore I Pillar II).
7. **Tone mix per zone (WoW-Classic law):** ~50% dread-neutral bread-and-butter, 15% heavy, 15% creepy, 10% cheerful, 10% intrigue. Cheerful quests are load-bearing: the small warm thing must exist so its loss means something (Lore I §6).
8. **Every quest cites canon.** A quest with no `canon:` line does not ship. Design extrapolation is allowed but must be flagged, exactly as the lore bible flags its own.

### Schema mapping (existing engine, `quest_defs.gd`)
Objective kinds that EXIST today: **`talk` / `kill` / `reach` / `choice` / `use_item`** — plus per-objective extras
(`night_only`, `escort`, `grant_item`, `arrive_note`) and quest-level `accept_items`, `auto_trigger`,
`aftermath`, `finale_beat`/`finale_pages`, `prereq`, `turn_in_npc`.
- "Collect 8 tusks" shapes are modeled today as **`kill` with count** (drop implied) or **`reach` + `grant_item`**. A true `collect` kind is a flagged engine extension (see §7).
- Positions in this doc use `ANCHOR(name)` — builder-truth placeholders rebound via `Quests.override_pos()` exactly like `q4_camp` in the demo.
- Dailies/events need the small engine extensions in §7; their *shapes* below use only existing kinds.

### XP calibration
`xp_system.gd` today: cap 10, quest XP 50–150, ×1.6/level curve. **The ×1.6 curve cannot reach 60** (L60 would cost ~10^14 xp); post-demo the curve must flatten (flagged in §7). Exemplar values below use the working band table — slow, WoW-Classic pacing (~6–9 quests per level mid-game):

| Shape | XP | Gold |
|---|---|---|
| Standard side/main step | `level × 60` | `level × 4` |
| Chain capstone / elite | `level × 90` | `level × 6` |
| Daily (repeatable) | `level × 25` | `level × 3` |
| Event | `level × 40` | token currency |
| Class quest | `level × 80` | 0 (reward is the ability/item) |

Reward items follow the `items.gd` `_DB` dict shape; new ids are listed per quest and must be added by the integration pass (same contract as `quest_defs.gd` §4 header).

---
---

# PART A — MAIN CHAIN (6 of the ~60-quest spine)

The spine is the Bloodstone arc: the buried world-machine arranges the player's whole career — every "coincidence" that promotes them, every door that opens — and whispers through inscription stones from level 1 to the descent under Black Night. Structure: **Border ring (1–12) → the four arms (12–50) → Gravemark (50–58) → the Grave & Bloodstone Pit (60)**. The six below are the rungs that calibrate all the others.

---

## MSQ-01 · The Road That Washed Out
| | |
|---|---|
| **id** | `msq_road_washed_out` |
| **zone** | Raven Hollow → The Iron Vein (zones 1→3) |
| **level** | 6 |
| **giver** | `gravekeeper` (Gravekeeper Vasile) |
| **prereq** | `well_went_copper`, `one_who_listens` (Phase C demo) |
| **next** | `msq_courier_satchel` |
| **tone** | dread-neutral (main) |
| **canon** | Lore IV Border Region (the Bent Oar = "the last warm hearth before it gets bad"); WORLD_PLAN zone 3; demo aftermath ("a bookmark, not an ending") |

**summary:** Vasile has burned three more rubbings this month. He wants a letter carried down the old road to the Bent Oar — and he wants the player to *look at the river* on the way.

**offer_pages** (Vasile):
1. "Still breathing. Good. I have a task that wants exactly that qualification, and a pair of boots that have already been past the gate and come back — rarer than you'd think."
2. "Three more rubbings this month. Three. Someone in this district is copying wellstones like recipes, and I burn them faster than fools can scratch them. That is not a war I win with a spade."
3. "There's a woman at the Bent Oar, down the Iron Vein — keeps the taproom, keeps the quest-board, keeps her mouth shut in four languages. Carry her this letter. Sealed. It stays sealed. You of all people know what reading does around here."
4. "And traveler — when the road bends along the river, LOOK at the water. Don't touch it. Don't taste it. Just look, and remember the color, and tell her the color when you arrive. She'll know what I'm asking."

**active_pages:** "The letter. The river. The color. In that order, and none of them read aloud."

**objectives:**
- `{id:"m1_river", kind:"reach", text:"Look at the Iron Vein where the road meets the river", map:"iron_vein", pos:ANCHOR(iron_vein_ford), radius:60, arrive_note:"The river runs slow and metallic — the color of old blood. It has run that color for years, they say. What's new: along the near bank, the dust between the stones lies in fine parallel lines, pointing upstream."}`
- `{id:"m1_letter", kind:"talk", npc:"oar_keeper", text:"Deliver Vasile's sealed letter to the keeper of the Bent Oar", pages:[
  "From Vasile? Then it's bad, and he's pretending it's correspondence. Sit. You look like the road argued with you.",
  "(She reads it with her back to the room — a habit, you realize, of someone who reads a lot of things other people shouldn't see her reading.)",
  "He says the graves are quiet again but the WELLS aren't, and he asks — ha — he asks whether my beer's still fermenting. That old crow. That's not small talk. That's a diagnostic.",
  "Now. The river. Tell me the color, and tell me about the dust, because there's always dust." ]}`
- `{id:"m1_report", kind:"choice", npc:"oar_keeper", text:"Tell her what you saw", prompt:"She waits, cloth in hand, wiping a mug that is already dry.", retry_pages:["Take your time. The river won't change color for being described slowly. ...Probably."],
  a:{label:"Tell her everything — including the aligned dust", pages:[
    "Parallel lines. Upstream. So it's not the water carrying it — something up the valley is EXECUTING, and the river's just the messenger.",
    "You did right to say it plain. Most people soften it, and softened news gets people killed a week later instead of saved a day sooner. I'll pass it up the Vigil roads.",
    "Room's yours tonight, no charge. Tomorrow there's a name I want you to hear: the Courier. Everyone on this river owes him a debt, and nobody's ever paid it, on account of him being dead of nothing at all." ], rewards:{xp:400, gold:30, items:["oar_room_token"]}, note:"The keeper sent word up the Vigil roads: something up the valley is executing. She spoke a name — the Courier — like a debt."},
  b:{label:"Mention only the color; keep the dust to yourself", pages:[
    "Copper-dark. Same as our wells, then. ...That all? You're sure? Hm. Your face does a thing when you say 'sure.'",
    "Fine. I'll report a red river and they'll file it under 'rivers, red, historical.' If there was more, traveler, it'll surface. It always surfaces. Usually somewhere worse.",
    "Room's yours tonight anyway. Vasile vouched for you, and I've learned to lend against his word." ], rewards:{xp:400, gold:30, items:["oar_room_token"]}, note:"You kept the aligned dust to yourself. The report went up the road lighter than the truth. It always surfaces. Usually somewhere worse."}}`

**turn_in_npc:** `oar_keeper` (folded into the choice branches, demo Q3-style)
**rewards:** xp 400 · gold 30 · `oar_room_token` (new item: inn privileges at the Bent Oar; flavor: "Good for one bed, one bowl, and no questions.")
**aftermath:** `gravekeeper`: ["So she got the letter, and you got the look at the river. Keep both. The Pause is a bookmark, traveler — and lately I hear pages turning."]

*Exemplar note: the option-B consequence is a WORLD FLAG (`m1_withheld`) referenced by MSQ-02's turn-in — chain-memory is the spine's signature. NPC `oar_keeper` (design extrapolation: "Rada, keeper of the Bent Oar" — the bible leaves the keeper unnamed) joins the cast list.*

---

## MSQ-02 · The Letter He Never Delivered
| | |
|---|---|
| **id** | `msq_courier_satchel` |
| **zone** | The Chamber Depths (zone 5, dungeon) via Vetka (zone 2) |
| **level** | 12 |
| **giver** | `oar_keeper` (Rada of the Bent Oar) |
| **prereq** | `msq_road_washed_out` |
| **next** | `msq_three_notes` |
| **tone** | creepy → heavy (main; the comprehension-death lesson) |
| **canon** | Lore VIII "The Courier — who died of understanding"; Lore IV Vetka Chamber ("satchel intact... he stopped to read the wall"); Lore XI Q2 "The Chamber" |

**summary:** Beneath Vetka lies the chamber where a Courier died of understanding, his satchel still sealed. Someone, somewhere, is still waiting on an answer a wall ate. Rada wants the letter finished.

**offer_pages** (Rada):
1. "Sit. This one needs sitting. ...Years back, a Courier came down this road — company man, fast, honest, the kind the road doesn't hand back. He was carrying a letter to a woman in Vetka. He never arrived. They found him under the town."
2. "Under it. There's a chamber down there — old, carved, and I will say the next part once and quietly: the carving KILLED him. No wound. Clean fingernails. He stopped to read a wall, and the wall finished him mid-thought. The letter was still sealed in his satchel. Nobody's had the spine to go back for it."
3. "The woman he was riding for is called Dorica. Still in Vetka. Still baking bread that won't rise and blaming her own hands for it. Somebody owes her that letter, traveler, and the somebody keeps being nobody."
4. "Go down. Take the satchel. DO NOT read the walls — not a mark, not a curl of it, I don't care how much it looks like it's about to make sense. ESPECIALLY then. Bring the letter up sealed, and give a dead man his last mile."

**active_pages:** "Sealed, traveler. The seal is the whole point. Down, satchel, up, Dorica. Nothing in that list says 'read.'"

**objectives:**
- `{id:"m2_descend", kind:"reach", text:"Descend into the Chamber beneath Vetka", map:"chamber_depths", pos:ANCHOR(chamber_antechamber), radius:70, arrive_note:"The stair goes down warm. Your breath stops fogging halfway. Below, the carving starts — not decoration, not writing: instruction. The angles pull the eye like a hook pulls a lip."}`
- `{id:"m2_satchel", kind:"reach", text:"Recover the Courier's satchel", map:"chamber_depths", pos:ANCHOR(courier_corpse), radius:40, grant_item:"courier_satchel", arrive_note:"He is exactly where the years left him — intact, unmarked, an expression of comprehension. The satchel buckles are still done up. The wall above him is dense with marks, and one line of it — you catch yourself squinting. You STOP. You take the satchel and look at your boots all the way out."}`
- `{id:"m2_temptation", kind:"choice", npc:"", text:"The satchel is in your hands. The wax seal is old and lifting at one corner.", prompt:"Halfway up the stair, in the last of the warm dark, the letter is very light and very easy to open. Nobody would know.", retry_pages:[],
  a:{label:"Keep the seal — carry it to Dorica unread", pages:[
    "(You press the lifting corner of wax flat with your thumb, the way you'd close a coffin lid gently, and climb toward the grey daylight without stopping.)" ],
    objectives:[ {id:"m2_dorica", kind:"talk", npc:"dorica", text:"Deliver the letter to Dorica in Vetka", pages:[
      "For me? Nobody sends... (she sees the company mark on the satchel and sits down where there is no chair, and the floor holds her, and you look away because it's that kind of moment.)",
      "This is my sister's hand. Ten years. Ten YEARS I thought she never wrote, that I'd said something, that the last thing between us was a slammed door and a cart leaving early.",
      "She wrote. It just... didn't arrive. Oh — oh, the poor man. He was carrying THIS when — (she stops. In this town, people have learned not to finish certain sentences.)",
      "Thank you. I mean it the old way, where it costs something to say. Take the bread. It's flat, it's grey, it's the worst bread in Draconia — and today it's a feast, because today I know she loved me the whole time." ]}],
    turn_in_npc:"dorica", turn_in_pages:[], rewards:{xp:720, gold:0, items:["doricas_flat_loaf"]},
    note:"Dorica has her sister's letter, ten years late. You never learned what the wall said. That is the only version of this story where you get to keep being you.",
    aftermath:{"dorica":["She wrote every season, you know. Every season for three years, and then stopped hoping. I'm writing back tonight. The ink still works, even here.","(The bread on her sill is still flat. She has stopped apologizing for it.)"]}},
  b:{label:"Read the letter — you've earned that much", pages:[
    "(The wax gives like it wanted to. The letter is ordinary — a sister's gossip, a recipe, a plea to write back. And along the bottom margin, in a different, older ink, someone has practiced copying four angular marks. The Courier didn't stop to read the wall. He stopped because the letter and the wall MATCHED.)",
    "(You know four marks now. You will catch yourself drawing them in spilled flour, in frost, in the margin of anything. You fold the letter and your hands are very steady, which is somehow worse.)" ],
    objectives:[ {id:"m2_dorica_b", kind:"talk", npc:"dorica", text:"Deliver the opened letter to Dorica", pages:[
      "For me? But the seal's — ...ah. The road, I suppose. Seals don't keep, out there. (She wants to believe it. She decides to believe it. You let her.)",
      "This is my sister's hand. Ten years. (She reads. She laughs once, wet.) A recipe. She sent me a RECIPE, the absolute — oh, I miss her. Thank you, traveler. Truly.",
      "(She doesn't notice the four practiced marks in the margin. You did. You do. You keep doing it.)" ]}],
    turn_in_npc:"dorica", turn_in_pages:[], rewards:{xp:720, gold:0, items:["doricas_flat_loaf"]},
    note:"Dorica has her letter. You have four marks you didn't have this morning, and a new habit of drawing in flour. [world flag: player_marked_1]",
    aftermath:{"dorica":["I'm writing back tonight. ...Traveler? You were tracing something on my table just now. What was it? It looked almost like—no. Never mind. Bread won't bake itself."]}}}`

**rewards:** xp 720 · gold 0 · `doricas_flat_loaf` (new item, consumable: heals 20% hp; flavor: "Flat, grey, the worst bread in Draconia. A feast.")
**turn-in variant:** if `m1_withheld` flag set (MSQ-01 option B), Rada's next ambient line: "The dust you didn't mention? It reached Vetka's mill this week. Surfaced somewhere worse. It always does."

*Exemplar note: this is the CURIOSITY TAX shape — the b-branch gives no mechanical bonus, only lore and a persistent `player_marked` counter the villain arc reads later (MSQ-03, MSQ-06). The engine needs no changes: both branches are plain choice options.*

---

## MSQ-03 · The Stone That Knows Your Name  ⟵ **VILLAIN TOUCH-POINT**
| | |
|---|---|
| **id** | `msq_three_notes` |
| **zone** | The Stonepath (zone 6 — the shortening inscription) |
| **level** | 20 |
| **giver** | `""` — auto_trigger `{map:"stonepath", pos:ANCHOR(shortening_stone), radius:90, night_only:false}` |
| **prereq** | `msq_courier_satchel` (auto_trigger ignores prereq per engine; integration gates the trigger on the flag) |
| **next** | `msq_spire_bleeds` |
| **tone** | creepy / mythic (the Lich-King-style tease, delivered the Draconia way) |
| **canon** | Lore IV inscription network ("a dead man's handprint... the only inscription that is getting shorter"); Lore II the melody/countdown; Lore II §2 "it arranges" |

**summary:** The one inscription in Draconia that is getting SHORTER stands at the Stonepath crossroads. An entranced pilgrim waits beside it. When the player approaches, the pilgrim speaks — level, patient, in a voice with too much room in it — and it knows things about the player it has no way to know.

**objectives:**
- `{id:"m3_stone", kind:"reach", text:"Approach the crossroads stone", map:"stonepath", pos:ANCHOR(shortening_stone), radius:60, arrive_note:"The stone wears a dead man's handprint, and around the fingers the marks are FADING — the only inscription on the continent that is getting shorter. Beside it stands a pilgrim, head tilted, eyes open, waiting. He has been waiting, you understand suddenly, for you specifically."}`
- `{id:"m3_listen", kind:"talk", npc:"stonepath_pilgrim", text:"The pilgrim is speaking. To you.", pages:[
  "\"You looked at a river and reported a color.\" (The pilgrim's mouth moves a half-second after the words arrive. His voice is his own. The SPACING isn't.) \"You carried a letter down a warm stair. You held a seal under your thumb and pressed it — flat.\"",
  "\"Small. Temporary. Wrong little things. We have an entry for you now. It is short. Entries grow.\"",
  "\"You will go east, or west, or south — it does not matter which, that is the part they never believe — and doors will open for you, and you will call it luck, and skill, and your own good idea. And every road you choose will run downhill. Toward us. They all drain to the same pit, traveler. Water knows this. Water doesn't take it personally.\"",
  "\"When you are tired enough — and you will be; we have seen to the weather — come north. The ground is warm there. It is the only place in Draconia that will feel like rest.\"",
  "(The lights of the far waystation dim, all at once, for the length of one held breath. Then the pilgrim blinks, sways, and says in a small ordinary voice:) \"...forgive me — was I talking? I do that, on the road. My feet go on and my mouth wanders. Which way is it to the wells, friend? I'm told the water there has a taste.\"" ]}`
- `{id:"m3_choice", kind:"choice", npc:"", text:"The pilgrim shuffles off. The stone's marks are one line shorter than when you arrived.", prompt:"The handprint on the stone is at exactly your height. It would fit your hand. It would be so easy to check.", retry_pages:[],
  a:{label:"Walk away without touching the stone", pages:[
    "(You put your hand in your coat instead, and you walk, and the crossroads lets you go the way a patient thing lets go of anything: certain it will see you again.)" ],
    objectives:[], turn_in_npc:"", turn_in_pages:[], rewards:{xp:1800, gold:0, items:[]},
    note:"It knows about the river, the seal, the stair. It has an entry for you, and entries grow. You did not give it your hand. [world flag: refused_the_stone_1]", aftermath:{}},
  b:{label:"Press your hand to the dead man's print", pages:[
    "(Warm. Not like fever — like an argument someone else already won. Under your palm the fading marks stir, and for one instant you understand ONE of them — a small one, a preposition, a nothing-word — and it costs you exactly one memory you won't identify for weeks: some small warm thing, gone, and no receipt.)",
    "(The stone's marks are fading faster now. Somewhere under the world, three notes drift one hair closer together. You did the right thing, probably. That is exactly what it wanted you to feel.)" ],
    objectives:[], turn_in_npc:"", turn_in_pages:[], rewards:{xp:1800, gold:0, items:[]},
    note:"You fed the shortening stone your hand and it took a small memory as postage. The marks fade faster now. Whether that is victory is a question for later, and later is patient. [world flags: player_marked_1, notes_converged_1]", aftermath:{}}}`

**finale_beat:** `stone_whisper` — integration dims all light sources 0.6 s at the pilgrim's page 4 (reuses the demo's `listener_whisper` vignette machinery).
**rewards:** xp 1800 · gold 0 · none (the villain pays in dread)

*Exemplar note: THE villain-cadence template. Rules for all ~15 spine touch-points: (1) the stone speaks only through intermediaries — pilgrims, wells, dreams at inns, a chalk line a child draws; (2) it recaps the player's own recent quest history (the arranger reading its arrangement) — integration exposes a `recent_notes()` API for this; (3) it always offers REST, never power; (4) the lights dim once; (5) the vessel remembers nothing and is kind. Frequency: one touch-point per ~4 levels, escalating in intimacy, never in volume.*

---

## MSQ-04 · The Spire Bleeds Orange
| | |
|---|---|
| **id** | `msq_spire_bleeds` |
| **zone** | Blestem (zone 17, capital) |
| **level** | 34 |
| **giver** | `sabira` (the Riddler's Quarter) |
| **prereq** | `msq_three_notes` + East-arm access chain |
| **next** | `msq_dig_that_woke` |
| **tone** | intrigue / dread (main; GoT engine bolted to the villain arc) |
| **canon** | Lore IV Blestem (Black Spire "bleeds a faint shifting orange at its base"); Lore V Accord Point 4; Lore V leverage table (Cazimir = "the perfect vector"); Lore VII Sabira ("poor bastards") |

**summary:** Sabira has a reading she cannot report: the Black Spire — Cazimir's own tower — reads shifting orange at the base. Reporting it to the Accord's Archive is treason to Blestem. Not reporting it is treason to the world. She needs hands that aren't hers.

**offer_pages** (Sabira):
1. "Don't sit. Sitting means staying, and this conversation isn't happening. ...You're the one the wells talk about. Good. I need someone the walls DON'T already own."
2. "There's a color, in my trade. The worst one. Orange, and shifting — the signal writing itself into the medium. I've seen it four times in twenty years. Wells. A grave-kerb. A scholar's notebook, after. You put miles between yourself and it, and you report it, and joint hands deal with it. Accord Point Four. That's the law all four thrones signed."
3. "Three nights ago I ran a wash at the base of the Black Spire. Routine. Calibration, even. (Her face does nothing at all. It is the loudest nothing you have ever watched.) The Spire bleeds orange, traveler. At the base. My master's own tower is sitting closer to the Underlanguage than my master admits — or knows. I genuinely cannot tell you which is worse."
4. "If I report it, Blestem burns me by morning — I've filed enough people to know the paperwork. If I don't, I've watched the worst color in the world write itself under the one man who thinks he can OWN it. So: someone with no file carries a vial to the Archive's woman at the Transcub church. Reagent, wash-notes, my seal broken off. Or — you take it to Cazimir himself, and we learn whether the spymaster knew. Choose better than I've managed to."

**active_pages:** "The vial is still in your coat, which means the decision is still in your hands. Both are heavier than they look. Walk faster."

**accept_items:** `["sealed_spire_vial"]` (new quest item; flavor: "The wash inside shifts orange when you don't look at it directly.")

**objectives:**
- `{id:"m4_choice", kind:"choice", npc:"sabira", text:"Where does the reading go?", prompt:"Blestem's lamps hiss. Somewhere above, a windowless tower watches with no eyes.", retry_pages:["Still carrying it? Every hour it's on you, you're the most interesting person in Blestem. That is not a compliment. Move."],
  a:{label:"Deliver the reading to the Archive's listener (Accord Point 4)", pages:["(The Transcub church has no roof and one congregant. The ivy has eaten the god but left the pews.)"],
    objectives:[
      {id:"m4_church", kind:"use_item", item:"sealed_spire_vial", text:"Leave the vial at the Transcub confession-rail", map:"blestem", pos:ANCHOR(transcub_rail), radius:40},
      {id:"m4_witness", kind:"talk", npc:"archive_listener", text:"Speak the passphrase to the woman lighting candles", pages:[
        "\"Cold hands make honest ledgers.\" ...So. Someone in this city still remembers what we all signed. Give me the shape of it — no, not the DETAILS, saints, never the details. The color, the place, the depth of the read. That's all the Archive needs and MORE than it's safe to carry.",
        "The Spire. (She lights the next candle with a hand that does not shake, which tells you exactly how long she has been doing this work.) Then joint hands will come — northern hands, western hands, hands with treaty-weight — and Blestem will have to open its cellar to the Accord, and the man in the walls will have to smile through it.",
        "Whoever ran this reading bought the world a fighting chance and themselves a very bad year. Tell them a stranger said: poor bastards, the lot of us — and thank you." ]}],
    turn_in_npc:"sabira", turn_in_pages:[
      "It's done? Then in eight days there will be northern auditors in the Lower Market and my master will be very calm about it, which is his loudest scream. He'll hunt the source of the report for a decade. He will not find her. I've been hiding people from him for twenty years — this once, it's me.",
      "...Poor bastards. All of us. Here — from the Quarter's own kit. If you're going to be interesting, be HARD to follow." ],
    rewards:{xp:3060, gold:0, items:["quarterstep_boots"]},
    note:"The Accord knows the Spire bleeds orange. Northern auditors are coming to Blestem, and Cazimir is very calm. Sabira is hiding one more person from him now: herself. [world flag: accord_holds_1]", aftermath:{}},
  b:{label:"Take the reading to Cazimir — learn what the spymaster knows", pages:["(You are not taken to Cazimir. You are taken to a corridor, and the corridor rearranges until it is a room, and the room has a voice in its walls.)"],
    objectives:[
      {id:"m4_cazimir", kind:"talk", npc:"cazimir_wall", text:"Present the vial to the voice in the stone", pages:[
        "\"An unsolicited reading of my own foundation. Do you know how few people could take that wash and live to misdeliver it? I have a list. It is short. Your name is being added as we speak — under 'useful.'\"",
        "\"Yes. The Spire sits close to the deep script. I BUILT it there. One does not surveil a thing from a comfortable distance, and I have watched that buried ledger longer and closer than any Accord clerk sneezing over treaty-paper. The orange at my foundation is a fact I manage. It is not a fact I report. Do you see the distinction? It is the distinction between an owner and a witness.\"",
        "\"You expected — what, exactly? A man possessed? A tower humming hymns? I collect architecture, walker-of-wells. The stone under my city is the finest architecture in the world. And everything that exists can be owned. I have six hundred years of evidence.\"",
        "\"The vial stays. The visit never happened. And because you brought the problem HOME instead of to the treaty-criers — a consideration. Spend it wisely; I price second favors differently.\"" ]}],
    turn_in_npc:"sabira", turn_in_pages:[
      "You took it INTO the walls. (Her blankness holds. Her hands, for one half-second, do not.) Then he knew. He built ON it. He thinks it's a vault and he's the keyholder, and it thinks — it doesn't think. It ARRANGES. And my master has spent six centuries arranging himself into position to be arranged.",
      "I filed my first report at fourteen, traveler. This is the first one I'm not going to write. ...Take the coin. His coin. It spends the same, and that's the whole tragedy of this city." ],
    rewards:{xp:3060, gold:400, items:[]},
    note:"Cazimir knew. He built the Spire ON the deep script to 'watch' it — the collector who mistakes himself for the buyer. The Accord was not told. Sabira filed no report. [world flags: cazimir_leverage_1, accord_cracked_1]", aftermath:{"sabira":["(She is watching the Spire from the shadowed side of the Quarter.) Six centuries of evidence, he says. The stone has more. The stone has all of it. ...Poor bastards."]}}}`

**rewards:** xp 3060 · branch-dependent · `quarterstep_boots` (new item, boots: +8% speed, flavor: "Riddler's Quarter issue. They remember routes you never took.")

*Exemplar note: the INTRIGUE-MAIN shape — a leverage triangle (Sabira/Cazimir/Accord) where both options are defensible, both are betrayals, and the world-flags (`accord_holds`/`accord_cracked`) steer which version of the level-50s war-council quests the player sees. GoT engine, zero romance, all ledger.*

---

## MSQ-05 · The Dig That Woke Something
| | |
|---|---|
| **id** | `msq_dig_that_woke` |
| **zone** | The Gift → Basaltfang Range (zones 23, 25) |
| **level** | 46 |
| **giver** | `anara` (hidden camp above the Gift) |
| **prereq** | `msq_spire_bleeds` + South-arm chain |
| **next** | `msq_the_bookmark` (via the Gravemark 50s block) |
| **tone** | heavy / mythic (main; the Accord's stress-test) |
| **canon** | Lore V Flashpoint 1 verbatim ("The Dig That Woke Something"); Lore VII Ilion, Anara, Valrom's dagger; Lore IX the Digging Creature ("efface the mark — killing the herald does nothing") |

**summary:** Ilion's compulsion to resolve loose ends has driven a Varcolaci excavation into the old Gift-soil. They pulled up an inscribed fragment — and something with four claws that pulls throats. Anara, hiding in the killer of her people's own war-machine, is the only one who can say what the fragment is. She will read it for the player. Once. Around the meaning.

**offer_pages** (Anara):
1. "Stop there. If you found this camp, one of three things is true: you are Ilion, you are working for Ilion, or you are so far outside every faction's ledger that no one thought to stop you. Sit where I can see your hands. Convince me it's the third."
2. "The dig, then. Yes. I feel it from here, the way you'd feel a splinter in someone else's hand — a talent I did not ask for and cannot return. Valrom's tracker-general pulled a fragment out of the war-dead soil. Carved. LIVE. And the ground answered him — four claws, an open throat a night, always upward, always once. It is not hunting. It is punctuating."
3. "Kill it if you like. It will come back; it is bound to the mark, not to its body. The Accord's law says the fragment goes to the Archive, jointly, hands from every throne. Valrom — the dagger that wears Valrom — has refused. So the treaty that has held since the Pause is now being tested by a hole in the ground, which is precisely how these things go. Nothing ends at a summit. It ends at a dig site, with tired people, at night."
4. "I will read the fragment for you — around the meaning, the way you carry a blade by the flat. One reading. Then you will decide what happens to it, and I will already have left this camp, because whichever way you decide, someone will come asking who read it."

**active_pages:** "The creature signs the ground every night the mark stays live. Efface, surrender, or bury — but decide. Punctuation doesn't pause."

**objectives:**
- `{id:"m5_herald", kind:"kill", text:"Drive off the four-clawed herald at the dig site (it will return)", enemy:"digging_creature", count:1}`
- `{id:"m5_fragment", kind:"reach", text:"Recover the inscribed fragment from the dig", map:"the_gift", pos:ANCHOR(gift_dig_site), radius:60, grant_item:"gift_fragment", arrive_note:"The fragment is warm, of course. Around the dig, the red soil has begun to lie in furrows nobody plowed — parallel, patient, pointing north. A child's shoe sits in one of them, beside a very good harvest."}`
- `{id:"m5_reading", kind:"talk", npc:"anara", text:"Bring Anara the fragment for one reading", pages:[
  "Put it on the stone. Not in my hands — the STONE. (She reads the way surgeons cut: fast, shallow, never twice in the same place.) It is an address. Do you understand? Not a spell, not a curse. A RETURN address. The war-dead soil has been writing letters north for six hundred years, and this is the corner of the envelope.",
  "Your Accord clerks would file it. Cazimir would frame it. Valrom's dagger wants it CARRIED — south to north at an army's pace, with a king's hand around it. All three deliver it. Everything delivers it. That is what it is FOR.",
  "There is a fourth option, and it costs the most and does the least, which is how you know it's the honest one: efface it. Grind the address off the world. The creature loses its anchor; the letter loses its envelope; Ilion loses his loose end — and a man who cannot abide a loose end is a man the stone can bait forever, so you will also be saving HIM, not that he will file it that way.",
  "Decide. I was never here. My people had a word for people like me — the last safe copy. I intend to remain uncollected." ]}`
- `{id:"m5_choice", kind:"choice", npc:"", text:"The fragment's fate", prompt:"The fragment hums against the stone — two notes, close together, closer than they should be.", retry_pages:[],
  a:{label:"Efface the mark — grind the address off the world", pages:[
    "(It takes half the night and both your arms. The marks do not resist. They simply take a very long time to stop being legible — like a thing choosing to make you mean it. Somewhere before dawn, the ground under your knees goes cold for the first time since you crossed into the Gift.)" ],
    objectives:[{id:"m5_efface", kind:"use_item", item:"gift_fragment", text:"Efface the fragment at the dig site", map:"the_gift", pos:ANCHOR(gift_dig_site), radius:60}],
    turn_in_npc:"", turn_in_pages:[], rewards:{xp:4140, gold:0, items:["anaras_flat_knife"]},
    note:"The address is off the world. The herald has no anchor; the dig is a hole again; Ilion's loose end is ash. Every faction lost. That was the win. [world flag: fragment_effaced]",
    aftermath:{"anara":["(A note, weighted with a flat knife, where her camp was.) 'You did the costly nothing. My people would have liked you. Keep the knife — it has never once been interesting, which is the highest praise I know.'"]},
    finale_beat:"stone_whisper", finale_speaker:"the dig wind", finale_pages:["(As the last mark goes, the wind across the Gift stutters — one held breath — and far north, something patient turns a page back, unhurried. You have not been forgiven. You have been NOTED.)"]},
  b:{label:"Surrender the fragment to the Accord's joint hands (Point 4)", pages:[
    "(The handover happens at a toll-fort on the Bloodroad: a northern shell, a western clerk, a Blestem witness, and a Varcolaci pit-boss who spits. Four hands on one warm stone. The treaty, working — creaking, but working.)" ],
    objectives:[{id:"m5_handover", kind:"reach", text:"Deliver the fragment to the joint Accord party at the Bloodroad toll-fort", map:"bloodroad", pos:ANCHOR(bloodroad_tollfort), radius:70}],
    turn_in_npc:"", turn_in_pages:[], rewards:{xp:4140, gold:300, items:[]},
    note:"The fragment travels north under four seals to the Archive — carried, catalogued, KEPT. The Accord held. The address was delivered by treaty, in triplicate. Anara's voice, from memory: 'Everything delivers it.' [world flag: fragment_archived]",
    aftermath:{"anara":["(Her camp is bare. Scratched on the stone where she read: 'They will keep it SAFE. Safe is a room. Rooms have addresses too.')"]}}}`

**rewards:** xp 4140 · `anaras_flat_knife` (branch A; new item, dagger: modest stats, flavor: "It has never once been interesting. The highest praise she knows.")

*Exemplar note: the HEAVY-MAIN shape — the canon flashpoint dramatized so the "correct" Accord-lawful option is quietly the stone's courier service, and the costly manual labor option is the real win. Killing the boss is deliberately NOT the solution (bestiary law: efface the mark). The choice's world-flags select the Gravemark 50s content.*

---

## MSQ-06 · The Bookmark  ⟵ **LEVEL-60 FINALE**
| | |
|---|---|
| **id** | `msq_the_bookmark` |
| **zone** | Black Night → The Grave & Bloodstone Pit (zones 12, 16 — endgame dungeon) |
| **level** | 60 (5-player or tuned-solo capstone; exemplar shows the solo-spine version) |
| **giver** | auto_trigger at the Pit gate + `vasile_council` summons |
| **prereq** | full spine (`msq_*` chain), `refused_the_stone` OR `player_marked` history (both are honored — see choice) |
| **next** | — (post-finale epilogue hooks) |
| **tone** | mythic / heavy (the whole game lands here) |
| **canon** | Lore II the Counter ("living touch receives; dead touch transmits"); Lore V Accord Point 2 (the Collector alone interfaces); Lore IV Black Night ("47 years... they gave me a pit"); Lore XI Boss 4/5 grammar; WORLD_PLAN zone 16 |

**summary:** Every road ran downhill, exactly as the pilgrim said. The arrangements are complete: the wells of four kingdoms went copper in the same week, the notes are two where they were three, and the Council of Six has — against six hundred years of precedent — opened the Pit gate. The stone has arranged its living touch: the player. The descent is real. So is the refusal.

**offer_pages** (Vasile of the Council — the loudest thread, frightened quiet for the first time):
1. "You. Yes — the one the stones talk about. Do you know what it costs a dead man to say 'I was wrong'? Nothing. That is the horror of my condition: I can afford every truth. So: we were wrong. The containment is not a wall. It never was. It is a LID, and the thing under it has finished arranging."
2. "Every well from Blestem to the western river went copper inside seven days. The dust in four capitals lies in the same direction — north. The melody is at two notes. And the Pit gate, which the Council has held shut through war, drift, and doctrine — the gate is OPEN, traveler, and no shell of ours opened it, and it is open at exactly your height."
3. "It wants a living hand. It has spent your whole life digging the channel that leads your particular water here — every door that opened for you, every 'luck.' You may feel owned, hearing that. Good. Feel it, and carry it DOWN, because the one thing it cannot arrange is what you do with the knowing."
4. "The Queen is below. The Collector is below — the Accord's dead hand, the only one that can touch what you must not. Go down. Refuse everything that feels like rest. And traveler — the last door is not fought through. It is WALKED through, the way you walked past every stone that wanted reading. You have been in training for that walk since the first copper well. Perhaps that, too, was arranged. Go anyway."

**objectives:**
- `{id:"m6_descent", kind:"reach", text:"Descend the Grave stair beneath Black Night", map:"bloodstone_pit", pos:ANCHOR(grave_landing), radius:80, arrive_note:"The stair passes Lilith's tomb-stone, worn nearly smooth: '47 years. I gave them 47 just years, and a cedar throne. They gave me a pit.' The cedar smell is still, impossibly, there. Below, the air is the inside of a held breath."}`
- `{id:"m6_guards", kind:"kill", text:"Cut through the Pit's arrangements — the guards the stone has borrowed", enemy:"pit_shell", count:12, }` *(twelve — the arrangement's own grammar; body-signage law)*
- `{id:"m6_lilith", kind:"talk", npc:"lilith", text:"Face the Buried Queen at the threshold", pages:[
  "(She is at the threshold of the last chamber, and she is not guarding it from you. She is guarding YOU from it, and she has been doing it, you realize, for the entire descent — every shell that missed, every stone that crumbled a half-second early.) \"So. You are what it ordered. Six hundred years of patrol and I never once caught it SHOPPING.\"",
  "\"Listen to me, warm thing, because I will say this once and my saying costs more than you know. Beyond this door is a record of a world with no one in it, and it is the most restful thing you will ever stand near. It will not attack you. It will offer to STOP — the ache, the grief, the whole exhausting business of being specific. And it will be telling the truth. That is why everyone touches it.\"",
  "\"I touched it out of a grave they dug me for the crime of feeding them. I have hated them six hundred years for it, and my hate is the hinge the world hangs on — and lately, some nights, I am too tired to hate, and on those nights the door behind the door goes THIN. So the errand is simple: whatever you came to spend down here — spend it fast. My anger has outlived my reasons, and a lock that has forgotten why it locks is just a shape.\"",
  "\"The dead man is inside, at the stone. He is the only hand. You are the only reason. Do not confuse the two, and do not — DO NOT — shake his hand out of politeness. Go.\"" ]}`
- `{id:"m6_stone", kind:"reach", text:"Walk the last chamber to the Thirsty Stone (do not linger — the floor listens)", map:"bloodstone_pit", pos:ANCHOR(bloodstone_dais), radius:50, night_only:false, arrive_note:"It is smaller than the dread of it — a crystal the size of a curled sleeping child, withholding light. Two notes hum in the stone underfoot, very close together now. And it is RESTFUL here. That is the attack. Beside the dais stands a grey-blue dead man in a worn coat, waiting, an ember-orange stone at his sternum. 'You're late,' the Collector says. 'Everyone is. It counts on that.'"}`
- `{id:"m6_offering", kind:"choice", npc:"collector", text:"The transmission — choose what to feed the record", prompt:"The Collector holds out one grey hand. 'A dead touch can transmit — push the present INTO it. But the present has to be SPECIFIC. Small. Warm. Yours. Give me one thing the record cannot hold, and mean it. And know the price: what we feed it, you LOSE. That's the whole mechanism. Loss is the price. The price is what makes it real.'", retry_pages:["The Collector waits. Dead men are good at it. The stone waits better. Choose."],
  a:{label:"Give him Mira's little tune — the song nobody taught her", pages:[
    "(You hum it — badly, which matters; the record has no entry for 'badly.' Four notes a miller's daughter hummed after the treeline, the tune that made a taproom feel counted. The Collector closes his fist around the sound like a firefly.)",
    "\"Good. Wrong, small, unrepeatable. It'll hate this.\" (He lays his dead hand on the Thirsty Stone, and TRANSMITS.)",
    "(No light. No thunder. Just — mass. The two notes underfoot shudder APART, a hair, a handspan, a held world. Somewhere above, in a town you started in, an innkeeper forgets a tune she's been humming for months and frowns at her own hands. You will never hear it again. Neither will the record. It is yours-that-was, wedged into the door forever.)",
    "\"Bookmark's holding,\" the Collector says, in the voice of a man reading a receipt. \"Notes are three again. That buys — a generation? Two? Nobody stops the ending, friend. We just keep the room warm a little longer, and we make sure somebody's name is in it when the cold comes. Yours is, now. That's the job. That was always the whole job.\"" ],
    objectives:[], turn_in_npc:"", turn_in_pages:[], rewards:{xp:5400, gold:0, items:["bookmark_signet"]},
    note:"The notes are three again. Mira's tune is gone from the world and lodged in the door. The Pause holds — a bookmark, not an ending, and now one page thicker. [world flag: finale_tune]", aftermath:{"innkeeper":["Strange — I've had a tune in my head since the spring, and this morning it's just... gone. Left a warm dent where it sat, like a cat got up. ...Ah well. Soup won't stir itself."]}},
  b:{label:"Give him a name — the one you carried the whole way", pages:[
    "(You say the name. It is not written in this document because it is not the same name for any two players: integration binds it to the campaign's tracked loss — the NPC this run failed, buried, or could not reach in time. The engine has been keeping the list since level one. The stone was not the only thing arranging.)",
    "\"...Yes,\" the Collector says quietly, and for one second the noir cracks and something older looks out. \"A name. I carry two of those myself. They're the heaviest small things there are.\" (He lays his dead hand on the stone, and TRANSMITS.)",
    "(The two notes shudder apart. The name goes INTO the record — specific, mortal, wrong, unresolvable — and the perfect empty world now has one grave in it that will not file. You feel the name leave you: not the memory, but the WEIGHT of it, the ache you'd been calling yours. Lighter is not the same as better. You will notice that for years.)",
    "\"Bookmark's holding. Go up, warm thing. Tell them it's quiet. Don't tell them what quiet costs — they'll learn. Everyone learns. That's the other thing the stone never understood about us: we learn, and we do it ANYWAY.\"" ],
    objectives:[], turn_in_npc:"", turn_in_pages:[], rewards:{xp:5400, gold:0, items:["bookmark_signet"]},
    note:"The notes are three again. The name you carried is wedged into the record — one grave the perfect world cannot file. You are lighter. Lighter is not the same as better. [world flag: finale_name]", aftermath:{}}}`

**finale_beat:** `pause_reset` — integration: every light source in every loaded zone brightens one step for a held beat (the inverse of every dimming the villain ever performed), then the two/three-note ambient motif resolves back to a chord. This is the game's single moment of un-dread. Spend it.
**rewards:** xp 5400 · `bookmark_signet` (new item, ring, legendary: +15 hp, +15 mana, effect "listening resistance"; flavor: "Proof that somebody chose the small, temporary, wrong little thing. Every time.")
**epilogue hooks:** Lilith at the tomb-stone (her contempt re-fueled — by GRATITUDE, which she will deny for another six hundred years); Vasile apologizing (he has never once apologized); the four capitals' epilogue barks keyed to `accord_holds`/`accord_cracked`, `fragment_effaced`/`fragment_archived`.

*Exemplar note: the finale honors the hard canon asymmetry — the PLAYER (living) never touches the stone; the Collector (dead, Accord Point 2) is the hand, the player is the SPECIFICITY. The choice consumes a real tracked thing (a tune the innkeeper hums post-demo / the campaign's logged loss), making "loss is the price of love" mechanical, not rhetorical. WotLK-cadence fulfilled: the villain that teased for 60 levels is met, and it is not fought — it is REFUSED, at cost.*

---
---

# PART B — SIDE QUESTS (8: 2 heavy · 2 creepy · 2 cheerful · 2 intrigue)

---

## SIDE-01 · The Granary Is Full  — **HEAVY**
| | |
|---|---|
| **id** | `side_granary_full` |
| **zone** | The Famine Fields (zone 10) |
| **level** | 26 |
| **giver** | `helva_agent` (Quartermaster Helva's field-agent, Costel) |
| **prereq** | West-arm access; **next:** `side_grain_for_words` (soft link) |
| **tone** | heavy |
| **canon** | Lore IV Angel Wings vignette 1 verbatim ("a famine-village where the granary is full... nothing is physically wrong"); Lore IX the Yeastless; Lore II §2 engineered desperation |

**summary:** Brassbeck village is starving. The Crown sent grain. The granary is FULL — audited, dry, unspoiled — and the village is starving anyway, walking past the fat granary to gnaw bark, because the hunger the stone farms is not for food.

**offer_pages** (Costel):
1. "You want the report I can't write? Here it is: Brassbeck is starving to death around a full granary. FULL. I counted it myself, twice, by lamplight, because the first count felt like madness. Good grain. Dry. Theirs. Free."
2. "And they walk past it. Every day, out to the bark and the bitter roots, with the key to the granary hanging on the reeve's belt in plain sight. Ask them why and they get — polite. 'Not today.' 'It wants keeping.' 'It'd be a waste on the likes of us.' A whole village, talking itself out of its own bread in the same gentle voice."
3. "Helva's ledgers have no column for this. Hunger with a full store isn't shortage — it's ARRANGEMENT. Someone or something has convinced three hundred people they are not worth feeding. Go down there. Find me the seam. And eat something in front of them, saints help you — see what they do."

**active_pages:** "Found the seam yet? Every day the granary stays shut, two more of them lie down 'for a rest.' You've seen the resting kind before, I'd wager."

**objectives:**
- `{id:"s1_walk", kind:"reach", text:"Walk Brassbeck's lanes at meal-hour", map:"famine_fields", pos:ANCHOR(brassbeck_square), radius:80, arrive_note:"Meal-hour. No smoke from any chimney. A woman peels bark with careful, apologetic hands. Through the granary's slats: grain to the rafters. On the well-lip beside it, fresh-cut and neat as a signature: angular marks."}`
- `{id:"s1_well", kind:"reach", text:"Inspect the village well", map:"famine_fields", pos:ANCHOR(brassbeck_well), radius:40, grant_item:"brassbeck_rubbing_facedown", arrive_note:"The water is copper-bright. The marks on the lip are FRESH — days old. Someone cut them recently, from inside the village. Below the marks, someone else has been scratching them out with a spoon, over and over, and losing."}`
- `{id:"s1_reeve", kind:"talk", npc:"brassbeck_reeve", text:"Confront the reeve who holds the granary key", pages:[
  "The key? Of course I have the key. I keep it very safe. (He touches it the way you'd touch a wound.) We'll open the store when things are TRULY bad. This — this isn't truly bad yet. We can hold out. Holding out is what we're good at.",
  "My daughter said the cleverest thing last month. She said, 'Papa, the grain is the village. If we eat the village, what's left?' Seven years old. Where do they LEARN such— (his eyes go, briefly, to the well.) ...such wisdom.",
  "I sleep by the granary now. Not to guard the grain from thieves. To guard it from — appetites. Weak moments. Mine, mostly. That's twice now I've woken with the key in the lock and no memory of walking there. Good thing I catch myself. Good thing. A waste, on the likes of us." ]}`
- `{id:"s1_choice", kind:"choice", npc:"brassbeck_reeve", text:"The seam is the marks. The lock is the man.", prompt:"Cut new, from inside — someone here is transcribing. The reeve stands between his people and their own bread, sincerely, protectively, starving.", retry_pages:["'We can hold out,' the reeve says again, gently, to no one. The spoon-scratches on the well have not won."],
  a:{label:"Efface the well-marks, then break the granary open yourself", pages:[
    "(The marks fight like the Gift fragment fought — by taking time. When they go, the reeve blinks, sways... and starts to weep, holding the key out at arm's length like a snake he's been wearing.)",
    "\"Open it. OPEN it — saints, the children, we had it the WHOLE — open it, don't let me talk, my mouth's been someone's spoon for a month—\"" ],
    objectives:[{id:"s1_open", kind:"use_item", item:"granary_key", text:"Open the granary at meal-hour", map:"famine_fields", pos:ANCHOR(brassbeck_granary), radius:40}],
    turn_in_npc:"helva_agent", turn_in_pages:[
      "They're EATING? They're eating. (Costel sits down on nothing, misses, doesn't care.) Write that in Helva's ledger: one column, 'eating, again, like people.'",
      "You'll want to hear the rest, though, because there's always a rest. The one cutting the marks — it was the schoolmistress. Sweetest woman in the parish. She'd found an old kerb-stone in the stream and thought the marks were PRETTY, and copying them calmed her nerves, she said. Calmed. Her. Nerves. She's being walked west to Maren's people now, and she keeps asking what she did, and nobody on that road knows how to answer her.",
      "That's the enemy, friend. Not a wolf. A tired woman who found something pretty. Helva says: paid in full, and get some sleep. Neither of us will." ],
    rewards:{xp:1560, gold:100, items:["helvas_ration_book"]},
    note:"Brassbeck is eating. The transcriber was the schoolmistress, who thought the marks were pretty. She keeps asking what she did. Nobody knows how to answer her.", aftermath:{}},
  b:{label:"Report the seam to Helva and wait for Crown hands (by the book)", pages:[
    "(You ride the two days. The Crown moves in four more — fast, for a crown; four days, for a village. Effacers come with treaty-seals and do it properly, prayers and all.)" ],
    objectives:[{id:"s1_report", kind:"talk", npc:"helva_agent", text:"Carry the rubbing (face-down) and your account to Costel", pages:[
      "Face-down. Good — you HAVE seen this before. Right. Two days to Helva, four for warrants and effacers... six days. (He does the other arithmetic, the one in lives, and his face closes like a ledger.)",
      "By the book, then. The book exists because freelancers make martyrs and martyrs make cults. I know it. I believe it. I'll believe it all six days.",
      "...Eleven, it turned out. Eleven more of the resting kind before the store opened. The book will call that a success, and the book will be RIGHT, and I've started hating books. Here's your pay. Helva added a line to the ledger in her own hand: 'six days = eleven souls. Find a faster book.'" ]}],
    turn_in_npc:"", turn_in_pages:[], rewards:{xp:1560, gold:160, items:[]},
    note:"By the book: six days, eleven souls. The granary is open and Brassbeck eats. Helva's ledger now carries a line in her own hand: 'Find a faster book.'", aftermath:{}}}`

**rewards:** xp 1560 · `helvas_ration_book` (branch A; new item, trinket: +5% healing received; flavor: "Every child fed at Maren's, in a quartermaster's hand. 'The only war I'm winning.'")

*Exemplar note: the HEAVY shape — the horror is that nothing is physically wrong; both branches feed people and both cost; the "villain" is a kind woman with a spoon of her own. No monster was slain. Kill-objectives are optional in heavy quests.*

---

## SIDE-02 · The Line That Reads "Collected"  — **HEAVY**
| | |
|---|---|
| **id** | `side_olgas_ledger` |
| **zone** | Sangeroasa (zone 22, capital — Debt Pit rim) |
| **level** | 46 |
| **giver** | `hammer_widow_olga` |
| **prereq** | South-arm access |
| **tone** | heavy |
| **canon** | Lore VIII Hammer-Widow Olga verbatim; Lore IV Sangeroasa vignette 3 (the rim-ledger, "collected... a thousand years early"); Lore V Debt Pit ("debt is a sentence you serve with your body") |

**summary:** Olga's husband died in the Pit. His debt didn't. She has kept his forge-quota swinging for six years so the sentence passes to her back and not her sons'. Now a pit-boss has "re-audited" the ledger: the boys are listed as collateral after all.

**offer_pages** (Olga, without stopping the hammer):
1. "Talk between strikes. I lose the rhythm, I lose the quota; I lose the quota, the Pit gets curious about my household. So. Talk. (STRIKE.) You're the outlander who doesn't flinch at the channels. Good. I need a person exactly that unimpressed."
2. "My man went down the Pit six winters back. His debt didn't go with him — debts here are the only immortal thing. (STRIKE.) I took his hammer and his quota so the ledger would eat MY years and not my boys'. That was the arrangement. Everyone at this rim knows the arrangement. (STRIKE.)"
3. "Yesterday a pit-boss — Hrold, gilt tooth, smells of clerk — 're-audited.' Says the old line was misfiled. Says collateral 'follows the blood, not the hammer.' Says my boys' names go on the rim-board at next accounting unless the balance clears. (She strikes, and this one is not for the quota.) The balance is four hundred labor-days. I have swung six YEARS. The number went up, traveler. Numbers here only ever learn the one direction."
4. "I can't leave the anvil to fight a ledger — the anvil IS the fight. So somebody goes to the rim-board for me and reads the original line with their own eyes. Gilt-tooth is lying, or the board is wrong, or the board is right and the world is worse than even I price it. Find out which. I'll be here. (STRIKE.) I'm always here."

**active_pages:** "(STRIKE.) The board's at the south rim, past the channel-grates. Read the LINE, not the totals — totals are where they keep the lies. (STRIKE.)"

**objectives:**
- `{id:"s2_board", kind:"reach", text:"Read the ledger nailed at the Debt Pit's rim", map:"sangeroasa", pos:ANCHOR(pit_rim_board), radius:50, arrive_note:"Names and labor-days owed, in rain-proof clerk-hand. The dead have a final column, one word each: 'collected.' You find his line. The original debt is PAID — struck through, six years of Olga's strikes, initialed. Below it, in newer ink: 'REVISED — collateral follows blood. See addendum.' The addendum hook is empty. There is no addendum. There never was."}`
- `{id:"s2_hrold", kind:"talk", npc:"pit_boss_hrold", text:"Put the empty addendum hook to Pit-Boss Hrold", pages:[
  "The widow's runner! Or — no, too well-armed. The widow's INVESTMENT. (The gilt tooth catches the forge-light.) You read the board. Everyone can read the board; that's what makes it fair.",
  "The addendum? In processing. Documents mature at their own pace here — like debts. Like widows. (He watches you the way an auditor watches a discrepancy.) Here is the shape of things, outlander: the line is whatever the CURRENT ink says. Old ink is nostalgia. Her boys are strong. The Pit's quotas are short. The arithmetic writes itself.",
  "But I'm a reasonable instrument. Four hundred labor-days, OR its weight in coin, OR — (and here his voice does the thing clerk-voices do when they reach the true price) — the widow's forge. Deed and hammer. She swings for the Pit directly, the boys go free and un-listed, and everybody's ink agrees. Reasonable. Everything down here is reasonable. That's the pit of it." ]}`
- `{id:"s2_choice", kind:"choice", npc:"", text:"Three prices, one lie, no clean line", prompt:"Paid in old ink. Owed in new. The forge, the coin, or the fight.", retry_pages:["(From the rim you can hear her hammer, keeping time. It has not missed once. It will not, until it does.)"],
  a:{label:"Pay the four hundred labor-days in coin (2400 gold) and keep the receipt PUBLIC", pages:[
    "(You pay at the rim-board itself, at shift-change, before two hundred witnesses, and you make the clerk strike the line and initial it while the crowd watches. In Sangeroasa, witness is the only notary that can't be re-audited.)",
    "(Hrold's tooth stops catching the light. A debt paid loudly is leverage BURNED — his, this time.)" ],
    objectives:[], turn_in_npc:"hammer_widow_olga", turn_in_pages:[
      "(For the first time since you met her, the hammer stops. The silence where her rhythm was is the loudest thing on the rim.) Paid. PUBLIC. You absolute — do you know what you've spent? Coin like that buys a forge. Two forges.",
      "(She picks the hammer back up, because the quota is still the quota, but the strikes come easier — a woman keeping time now, not keeping a door shut.) My boys will learn a trade above ground. Both of them. That's your interest, outlander, the only coin I mint: two lives that won't owe the Pit a single day. Collect it in twenty years. (STRIKE.) Now get off my rim before I say something soft." ],
    rewards:{xp:4140, gold:-2400, items:["olgas_first_hammer"]},
    note:"Paid, publicly, unrevisably. Olga still swings — the quota is still the quota — but her boys' names will never reach the rim-board. Hrold's arithmetic found no purchase. This cost you a fortune. It was the cheapest thing on the board.", aftermath:{}},
  b:{label:"Take the empty addendum-hook to the Killing-Floor magistrate — fight the ink with ink", pages:[
    "(Sangeroasa has law. It is not kind law, but it is PROUD law — and a forged revision with no addendum is sloppy work, and the Pit despises sloppy work more than it despises mercy.)" ],
    objectives:[{id:"s2_magistrate", kind:"talk", npc:"floor_magistrate", text:"Present the fraud to the Killing-Floor magistrate", pages:[
      "A revision citing an addendum that does not exist. (The magistrate's jaw ticks — the closest thing to rage this office permits itself.) Understand what offends me, outlander. Not the widow. Not the boys. The INK. Our whole city stands on the ink being merciless and TRUE. A clerk who forges the ledger has stolen the only thing we actually worship.",
      "Hrold will answer at the floor. His line will read what all lines here eventually read. (One word. You both know it.) The widow's line reverts to the old ink: paid, struck, initialed. The boys are un-listed. Justice, of the Sangeroasa kind — which is to say: the machine ate the man who misused the machine, and calls itself satisfied.",
      "Do not look relieved. That is the lesson to carry out of my office: the ledger protected her today because the ledger was CORRECT, not because it was good. Pray you are never standing where those two part ways." ]}],
    turn_in_npc:"hammer_widow_olga", turn_in_pages:[
      "Hrold's name went on his own board this morning. (STRIKE.) I'd say something about justice, but I've lived at this rim too long — that wasn't justice, that was the Pit tidying its own arithmetic. My boys just happened to be standing in the tidy part. (STRIKE.)",
      "Still. Un-listed is un-listed. Take the old hammer — his, from before the Pit. It's paid its debts, which is more than most steel here can say. And outlander — the magistrate's lesson? Learn it better than he thinks you did. The ink saved us TODAY. (STRIKE.) The ink is also why there's a Pit." ],
    rewards:{xp:4140, gold:200, items:["olgas_first_hammer"]},
    note:"The ink ate the clerk who forged it. Olga's boys are un-listed; Hrold's line reads 'collected.' The ledger was correct today. Correct and good part ways somewhere below the rim, and everyone here knows the depth by heart.", aftermath:{}}}`

**rewards:** xp 4140 · `olgas_first_hammer` (new item, 1h mace: solid stats; flavor: "It's paid its debts. More than most steel here can say.")

*Exemplar note: the second HEAVY shape — industrial-clerical cruelty (Pillar: "horror wears a clerk's face"). Branch A shows a GOLD-SINK choice (negative gold reward — engine already supports arbitrary ints); branch B resolves through the system's own cold pride. Neither branch frees Olga: the quota is still the quota.*

---

## SIDE-03 · Three Bedrolls  — **CREEPY**
| | |
|---|---|
| **id** | `side_three_bedrolls` |
| **zone** | The Threadlands (zone 13) |
| **level** | 38 |
| **giver** | `waystation_keeper_north` (coach-post keeper, Pilgrim Road) |
| **tone** | creepy |
| **canon** | Lore IV Black Night vignette 2 verbatim ("three bedrolls, cold stew, footprints in, none out"); WORLD_PLAN zone 13 vignette; Lore IX Listeners |

**summary:** A family of three bought passage north and camped a night short of the waystation. Their camp is still there. Their footprints go in. No footprints come out. The stew has not been eaten, and nothing out there is hungry anymore.

**offer_pages** (the keeper):
1. "Three fares, paid in advance: a wheelwright, his wife, their girl — nine, maybe ten, kept asking if the northern lights hum. They camped the last night out, like everyone does, at the sheltered bend. Sensible folk. Warm gear. A night's walk from my door."
2. "That was six days ago. Coach went past the bend on schedule. Camp's there. Fire's long cold. Bedrolls laid out neat — THREE, mind. And the driver, who has driven this road twenty years and seen every way the north eats people, came in white as the plain and wouldn't say more than: 'the footprints go in.'"
3. "I'm not asking you to find them alive. I've kept this post too long to insult either of us. I'm asking you to go and READ it — properly, the way you people read things — and bring me something I can write to the wheelwright's brother. A page with an ENDING on it. Even a bad ending. The worst thing I can send that man is a blank."

**active_pages:** "The sheltered bend, half a night north. Go in daylight — not that daylight has been meaning much up there lately."

**objectives:**
- `{id:"s3_camp", kind:"reach", text:"Examine the family's camp at the sheltered bend", map:"threadlands", pos:ANCHOR(bend_camp), radius:60, arrive_note:"Three bedrolls, squared. Stew in the pot, skinned with frost, three bowls set out — UNEATEN. Three sets of footprints walk in from the road. The snow around the camp is six days undisturbed. No prints lead out. Nothing here is hungry anymore."}`
- `{id:"s3_filament", kind:"reach", text:"Follow the blue filament rising from the camp (alchemical sight)", map:"threadlands", pos:ANCHOR(bend_thread_knoll), radius:50, night_only:true, arrive_note:"By night you can see it plain: a thread-filament, hair-fine and blue, rises from the CENTER of the camp — from the girl's bedroll — and runs north, taut, over the snow, toward the pilgrim road. It is the only thing in the landscape under tension. Threads don't grow here on their own. Something reeled."}`
- `{id:"s3_pilgrims", kind:"reach", text:"Overtake the pilgrim column on the northern road", map:"threadlands", pos:ANCHOR(pilgrim_column), radius:80, arrive_note:"A column of the drawn, walking north in the even-spaced way. Third from the rear: a wheelwright. His wife. Between them, a girl, nine, maybe ten. Their boots match the prints at the bend. They are six days from their stew and they are not tired, not cold, not ANYTHING. The girl's head is tilted, as if the northern lights hum. Perhaps, for her, they do."}`
- `{id:"s3_try", kind:"talk", npc:"wheelwright_drawn", text:"Try to turn the wheelwright", pages:[
  "(You step into his path. He stops — the whole column stops, evenly, at once, which is worse. His eyes find you the way a door finds a draft.) \"We're nearly there,\" he says, pleasantly. \"It's kind of you to worry. But we're expected.\"",
  "\"The girl was tired, you see, so we left the — we left the—\" (a hitch; a flicker; a man looking for a word like a hand patting empty pockets) \"—we left it all laid out. For when we come BACK. We're coming back. That's the — yes. That's the arrangement.\"",
  "(The girl looks up at you. She is the only one who still flinches at her own name — fresh, Sabira's notes would say. She says, very quietly, in a voice that is entirely her own and entirely terrified:) \"Mister — I can't feel my feet. I've been walking for DAYS and I can't feel my feet. But mama says—\" (and her head tilts back, gently, like a page being turned, and she smiles at the humming sky.)",
  "(The column resumes. Evenly. You can walk beside them as long as you like. That is somehow the worst part: nothing here will stop you. Nothing here needs to.)" ]}`
- `{id:"s3_choice", kind:"choice", npc:"", text:"The girl still flinches at her name", prompt:"Fresh ones can be pulled out — with panic, with force, with the whole column turning its heads at once. Late ones cannot. The parents are late. The girl might not be.", retry_pages:[],
  a:{label:"Take the girl — pull her from the column by force", pages:[
    "(She fights you like Sabira's notes said she would: with the total panic of someone being dragged from the only thing that ever made sense. Her parents watch with mild, pleasant faces. They do not reach for her. They WAVE. The column walks on, two boots short, and does not miss a step.)",
    "(A mile south she stops fighting. Two miles south she starts to shake. Three miles south she asks — in a small voice, feeling returning to her feet like frost coming out of timber — 'Are mama and papa coming back for the stew?' You are carrying her by then. You do not answer. Your arms will remember the weight longer than your mind wants to.)" ],
    objectives:[{id:"s3_return", kind:"reach", text:"Carry the girl to the waystation", map:"threadlands", pos:ANCHOR(waystation_north), radius:60}],
    turn_in_npc:"waystation_keeper_north", turn_in_pages:[
      "(The keeper takes one look and has blankets moving before the door shuts.) One. One out of three. ...No, don't say it like a failure — I've kept this post eleven years and one-out-of-three is the best news this road has sent me in four winters.",
      "I'll write the brother tonight. An ending AND a beginning — the girl goes to him, or to Maren's people if he won't. And I'll write the other thing too, the thing we don't say near the stove: that whatever's reeling the road north has started taking them mid-JOURNEY now. Paying fares. Laying out bedrolls. Keeping up appearances. It's learned to look like travel, friend. Sleep with a lamp lit." ],
    rewards:{xp:3420, gold:150, items:[]},
    note:"One out of three. The girl's feet thawed; her nights are bad; she is alive to have them. Her parents walk north, evenly, expected. The thread has learned to look like travel. [world flag: girl_saved]", aftermath:{}},
  b:{label:"Let them walk — mark the column for the Council's threadwardens instead", pages:[
    "(You do the cold arithmetic: a fighting child, thirty miles of open plain, a column that might turn as one. You mark the thread-line with warden-dye instead, the long-practice way, and you watch the girl's tilted head hum away north until the snow takes the whole even-spaced procession.)",
    "(The threadwardens are good. Ilka's people re-seat slipping wills every season. Maybe they reach her while she still flinches at her name. Maybe. The word does a lot of carrying, on this road.)" ],
    objectives:[{id:"s3_mark", kind:"use_item", item:"warden_dye", text:"Mark the thread-line for the wardens", map:"threadlands", pos:ANCHOR(pilgrim_column), radius:80}],
    turn_in_npc:"waystation_keeper_north", turn_in_pages:[
      "Marked for the wardens. By the book — the northern book, which is older than mine and colder. (He writes. He is a long time writing.) I'll tell the brother the truth: expected north, marked for retrieval, a chance. A CHANCE is not a blank. I've sent worse pages.",
      "...Eleven years at this post. You know what I've learned? The road keeps a ledger too, and 'maybe' is its favorite ink. Warm up before you go. The stove's the one thing here the north hasn't audited yet." ],
    rewards:{xp:3420, gold:150, items:[]},
    note:"Marked for the threadwardens: expected north, a chance, maybe. The road keeps a ledger too, and 'maybe' is its favorite ink. [world flag: girl_marked]", aftermath:{}}}`

**rewards:** xp 3420 · gold 150
**aftermath (both):** the bend-camp remains as a permanent world fixture — three bedrolls, squared, forever (bodies-as-signage law: Iele grammar is *standing still*; this camp is its domestic conjugation).

*Exemplar note: the CREEPY shape — no combat objective at all; the monster is a column that will politely let you walk beside it. The `night_only` filament beat teaches detection-color literacy mid-quest. `warden_dye` is granted by `accept_items` in branch integration.*

---

## SIDE-04 · I Only Wanted to Know What It Said  — **CREEPY**
| | |
|---|---|
| **id** | `side_warm_altar` |
| **zone** | The Transcub Vale (zone 20) |
| **level** | 36 |
| **giver** | `brother_ansel_ivy` (Brother Ansel, ivy-priest of Transcub) |
| **tone** | creepy |
| **canon** | Lore IV Blestem env-story 2 verbatim (the confession, the warm altar); Lore VIII Brother Ansel ("hears confessions from the walls... sometimes the walls answer back"); Lore V Transcub theology (the god who punished cruelty-to-the-self) |

**summary:** In an ivy-eaten temple, a confession is scratched into the altar: "I only wanted to know what it said." The stone beneath the altar is warm. Brother Ansel has been answering the confession every evening — and lately, something has been answering back.

**offer_pages** (Brother Ansel):
1. "Welcome, welcome — mind the ivy, it has opinions. You are my first breathing congregant since the spring, unless we count the walls, and lately... well. We'll come to the walls."
2. "Transcub was the god who punished cruelty to the self — the lie you tell YOURSELF, the harm you do your own soul. Out of fashion, you'll say, and the roofless nave agrees. But confessions still arrive. Look — here, on the altar itself. Scratched. A shaking hand: 'I only wanted to know what it said.' Is that not the whole parish of this age in nine words?"
3. "I answer it, of course. Every evening. Absolution is a habit, like breathing — I've kept one long after losing the excuse for the other. Only — the altar stone has gone WARM under my hand this past month. And three nights ago, when I finished the rite and said, as I always say, 'you are forgiven, go and want less'... the wall behind the altar said something BACK. Softly. In no language I know. In a spacing I have started hearing in my sleep."
4. "I am half-mad, wholly gentle, and entirely aware of both — so I need honest eyes. Sit the evening rite with me. Hear what I hear, or don't. If God has finally answered after six hundred years, I should like a witness. And if it is the OTHER thing that answers in warm stone... I should like a witness very much more."

**active_pages:** "Evening, at the altar. Bring nothing that reads and nothing that copies. Whatever answers, we will not be taking notes."

**objectives:**
- `{id:"s4_rite", kind:"reach", text:"Attend the evening rite at the warm altar (night)", map:"transcub_vale", pos:ANCHOR(transcub_altar), radius:40, night_only:true, arrive_note:"Ansel keeps a clean rite for a dead god: candle, open palms, the nine scratched words read aloud with terrible tenderness. 'You are forgiven,' he says. 'Go and want less.' And the wall behind the altar — softly, patiently, in a spacing that arrives through your teeth — answers."}`
- `{id:"s4_listen", kind:"talk", npc:"brother_ansel_ivy", text:"Tell Ansel what you heard", pages:[
  "You heard it. (He does not look triumphant. He looks like a man whose fever just got a second opinion.) Level. Patient. It has answered every night since the altar warmed, always after the absolution — as if the forgiveness itself were the... the door-knock.",
  "I have been a fool in a very old way, friend. Consider: who scratched the confession? A shaking hand, someone who READ something and came here crawling with the knowing of it. They confessed INTO the altar — carved their guilt into the stone. And what do we know about carving, in this age? What do we know about what carved marks DO?",
  "The confession is a TRANSCRIPTION. Nine words of it are only words — but the poor soul's hand was shaking with what they'd read, and grief writes deeper than ink. Something of what they knew went into the stone with the scratching. And every evening for a month, I have stood at that altar and RESPONDED to it. Call and answer. Call and answer. I have been running a rite of absolution as a two-party TRANSMISSION, and the other party is very old and very interested.",
  "So my witness: one last question, and I fear its answer more than I have feared anything since the roof came down. Is the altar the confession's grave... or its PULPIT? Read the stone with your colors, and tell a gentle old fool which church he's been keeping." ]}`
- `{id:"s4_wash", kind:"reach", text:"Run an alchemical wash on the altar stone", map:"transcub_vale", pos:ANCHOR(transcub_altar), radius:30, arrive_note:"The wash blooms across the altar: green at the edges — warming, waking. And in the scratched letters themselves, thin as a hair in each groove: ORANGE. Shifting. The confession is writing itself deeper. The altar is not a grave. It has a congregation of one faithful old man, and it is teaching him the responses."}`
- `{id:"s4_choice", kind:"choice", npc:"brother_ansel_ivy", text:"The altar is a pulpit", prompt:"Ansel hears the verdict with his hands folded, like a man receiving a diagnosis he'd already palpated himself.", retry_pages:["'Take your time,' Ansel says softly. 'It will. It has six hundred years of practice at evensong.'"],
  a:{label:"Efface the confession — and the altar face with it", pages:[
    "(He helps. That is the part you will remember: the priest of the dead god taking up the chisel with you, weeping without drama, apologizing — to the altar, to the shaking hand, to the god who punished cruelty-to-the-self — 'and what greater cruelty to yourself,' he murmurs, 'than to keep a door open because the knocking sounds like company.')",
    "(When the last letter goes, the stone cools under your palms like a fever breaking. The nave is quiet. For the first time since you arrived, it is only ONE kind of quiet.)" ],
    objectives:[], turn_in_npc:"brother_ansel_ivy", turn_in_pages:[
      "Done. Done, and the evening rite is dead, and I am a priest of two dead things now instead of one. (He laughs — small, real.) Forgive an old man his grief for a haunting. It ANSWERED, friend. Nothing has answered in so long.",
      "But that was the trap, wasn't it. That is always the trap, in this age — not power, not gold: company. Something that listens. Something that answers back. Whoever scratched those nine words wanted only to KNOW — and I, who buried a god for wanting less, spent a month wanting an answer so badly I nearly became one.",
      "Take the candle-stub. Transcub's last honest relic: it lights, it warms, it goes out. Everything good is temporary, friend. That's what makes it good." ],
    rewards:{xp:3240, gold:0, items:["transcub_candle_stub"]},
    note:"The altar is blank and cool. The evening rite is over forever. Ansel keeps the church anyway — 'someone should be here to want less.' The trap was never power. It was company.", aftermath:{"brother_ansel_ivy":["The walls are just walls this week. I find I miss the haunting and distrust the missing — which is, I suppose, the correct theology at last. Mind the ivy on your way out. It has opinions."]}},
  b:{label:"Leave the altar — but end the rite: starve it of answers", pages:[
    "(No chisel. Ansel simply... stops. The hardest rite of his life is the one he doesn't perform: standing in his own nave at evensong, palms open, saying NOTHING. The wall waits. The spacing arrives, patient, inviting, a call with a groove worn where the answer goes. He holds his silence like a full cup on a rolling deck.)",
    "(Night after night, the exchange starves. The warmth retreats down the letters like a tide going out of nine small channels. It is slower than the chisel. It is crueler than the chisel. It is, Ansel insists, the only version that is THEOLOGY.)" ],
    objectives:[], turn_in_npc:"brother_ansel_ivy", turn_in_pages:[
      "Cold this morning. All nine words. (He shows you his palms, like a man proving he hasn't been scratching.) It called for eleven nights. On the twelfth it... did not. I won't pretend that was victory — things that patient don't lose, they re-schedule. But it learned that THIS door answers with silence, and doors like that get moved down the list.",
      "You wonder why I didn't let you chisel it. Friend: the confession was real. Some poor shaking soul carried their worst knowing to my altar because there was nowhere else on the continent that would take it. Effacing it un-happens THEM, a little. This way the words stay — human, grieving, nine words long — and only the thing that was wearing them has been shown the road.",
      "Take the candle-stub. And take the lesson, it's the only tithe I charge: when something ancient wants a conversation, the holiest word in any language is the one you don't say back." ],
    rewards:{xp:3240, gold:0, items:["transcub_candle_stub"]},
    note:"Eleven nights of silence starved the altar cold. The confession remains — nine human words, grieving, no longer worn by anything. Things that patient don't lose; they re-schedule.", aftermath:{}}}`

**rewards:** xp 3240 · `transcub_candle_stub` (new item, trinket: brief "listening resistance" when lit, 3 charges; flavor: "It lights, it warms, it goes out. That's what makes it good.")

*Exemplar note: the second CREEPY shape — a haunting whose mechanism is CANON MACHINERY (transcription + vocalization = two-party transmission), not a ghost. Branch B demonstrates the "refuse to engage" win the lore bible explicitly asks designers to reward.*

---

## SIDE-05 · Emeric's Grand Expedition  — **CHEERFUL**
| | |
|---|---|
| **id** | `side_emeric_expedition` |
| **zone** | Raven Hollow → The Iron Vein border (zones 1→3) |
| **level** | 7 |
| **giver** | `wanderer2` (Young Emeric — existing cast) |
| **tone** | cheerful (with the canonical dark wink, not a dark turn) |
| **canon** | `npc_data.gd` Emeric ("One day I'm taking the old road as far as it goes"); Lore I §6 ("kindness is small, real"); tone law: cheerful quests protect the contrast |

**summary:** Emeric is FINALLY doing it. The old road, as far as it goes. He has a bundle, a walking stick, one (1) apple, and a route plan drawn on the back of a flour bill. He would like a professional adventurer to accompany him for the dangerous first leg: the four hundred paces to the river fork.

**offer_pages** (Emeric):
1. "It's happening. Today. Don't try to talk me out of it — Da tried, Marta tried, the MAID tried, and I looked every one of them in the eye and said: the wide world has weighed in, and it says COME. ...All right, technically what happened is you walked in from the wide world and didn't die, which I'm counting as it weighing in."
2. "I've provisioned thoroughly. (He shows you: a bundle, a stick, one apple, and a map drawn on a flour bill with the mill's stamp still on it.) Route's planned to the last detail: the old road, then — (he rotates the flour bill) — then MORE of the old road, then the wide world. It's mostly wide world after the fork, navigationally speaking."
3. "Here's my proposition, adventurer to adventurer: walk the first leg with me. Just to the river fork. Not because I'm scared — because it's PROTOCOL. Expeditions have a send-off contingent. I read that. Well — I heard it. Well — I decided it just now, but it sounded true. Four hundred paces. What do you say?"

**active_pages:** "Protocol, remember! Send-off contingent walks AHEAD at the scary bits and BEHIND at the boring bits. I'll signal which is which."

**objectives:**
- `{id:"s5_gate", kind:"reach", text:"Meet Emeric at the east gate", map:"town", pos:ANCHOR(east_gate_arch), radius:40, arrive_note:"Emeric is saying goodbye to the gate itself, patting the arch like a horse. Gatewarden Iosif watches with the face of a man composing a report titled 'Local Boy, Probably Fine.'"}`
- `{id:"s5_walk", kind:"reach", text:"Escort the expedition to the river fork (stay close — he narrates)", map:"iron_vein", pos:ANCHOR(river_fork_marker), radius:50, escort:"wanderer2", arrive_note:"Four hundred paces of continuous narration later ('note the TERRAIN — very road-like'), the fork. Emeric stops. The old road runs on ahead — muddy, foggy, gloriously indifferent. He goes very quiet for the first time all day."}`
- `{id:"s5_moment", kind:"talk", npc:"wanderer2", text:"Hear him out at the fork", pages:[
  "That's it, then. The fork. Past that marker it's — nobody from home fixes your boots past that marker. (He looks down the road for a long, honest moment. The fog looks back, the way fog does.)",
  "...You know what I realized on the walk? Around pace two hundred? The harvest is in three weeks. Da's knee is bad this year. And if I leave TODAY, the expedition arrives everywhere IMPORTANT in, let me reckon it — winter. Nobody discovers the wide world in WINTER. That's just bad expedition science.",
  "So here's the revised plan, and I want it noted this is a POSTPONEMENT, not a retreat: I walk back, I get the harvest in, I fix the boot situation, and come spring — the fork won't know what hit it. (He plants his walking stick at the marker, ceremonially.) There. Now the road knows I'm coming. That's binding, that is. That's PROTOCOL.",
  "Walk back with me? I'll do the narration quieter. ...I won't, actually. But I'll mean to." ]}`
- `{id:"s5_return", kind:"reach", text:"Walk the expedition home (he narrates quieter — he doesn't)", map:"town", pos:ANCHOR(east_gate_arch), radius:50, escort:"wanderer2"}`

**turn_in_npc:** `wanderer2`
**turn_in_pages:**
1. "Home by supper — EXACTLY as planned, phase one complete. (He is glowing. The gate has never been patted so warmly.) Send-off contingent, your service is concluded and it was exemplary. Barely screamed at the heron at all."
2. "Here — expedition wages. It's the apple. I know, I know: 'Emeric, that's your whole provisions.' A good expedition travels light, and a GREAT one shares rations with its contingent. I heard that. Well — I decided it just now. It sounded true, didn't it? Everything sounds true at a fork."
3. "Spring, adventurer. The stick is planted. The road's been NOTIFIED. ...Do you think it hums out there, the wide world? The girl from the mill says everything hums lately if you listen right. Anyway! Spring!"

**rewards:** xp 420 · gold 0 · `emerics_apple` (new item, consumable: heals 15% hp; flavor: "The whole provisions of the Grand Expedition, phase one. It sounded true at the fork.")
**aftermath:** `wanderer2`: ["Spring. SPRING. The stick's planted at the fork, so it's binding.", "Da says the wide world will keep. I told him: that's exactly what worries me — everything out there keeping so QUIET. ...Anyway. Harvest first."]

*Exemplar note: the CHEERFUL shape — warm, funny, complete in itself; the dark world appears only as one held-breath line ('everything hums lately') the player is trusted to catch. The stick planted at the fork becomes a world fixture and a phase-2 hook. Zero combat; escort-lite reuses the demo's Mira controller contract.*

---

## SIDE-06 · The Bent Oar's Honest Stew  — **CHEERFUL**
| | |
|---|---|
| **id** | `side_honest_stew` |
| **zone** | The Iron Vein (zone 3) |
| **level** | 9 |
| **giver** | `oar_keeper` (Rada) |
| **tone** | cheerful |
| **canon** | Lore VIII Borek's stew ("not food; a chair pulled out at a table"); Lore IV the Bent Oar ("the last warm hearth before it gets bad"); Lore II symptom-order (yeast lives HERE — the point) |

**summary:** Once a season, the Bent Oar cooks the Founder's Stew — the recipe a hard man once set in front of a dead man who couldn't eat it, because a bowl on a table is a chair pulled out. Rada's larder is short three honest ingredients, and the season is tonight.

**offer_pages** (Rada):
1. "Good timing, or terrible — you decide when you hear the job. Tonight's the Founder's Stew. Once a season, every soul on this river gets a bowl, on the house, no questions. It's older than my tenancy, older than the tavern's NAME, some say. The rule is: everything in the pot honest — grown, caught, or traded fair, nothing scavenged off anybody's misfortune."
2. "The story? A man named Borek — hamlet up-river, long gone — once set a bowl of stew in front of a guest who couldn't eat it. Everyone knew he couldn't. Borek did it anyway, every night the guest stayed. Because a bowl on the table isn't food, traveler — it's a chair pulled out. So once a season we pull out every chair on this river, and the fog can have the rest of the year."
3. "Larder's short three: river-fish from the ford — CAUGHT, not bought off some poacher's misery; bog-onions from the north bank, mind the mud, it flatters no one; and marrow-bones from Ansel's farm over Raven Hollow way — traded FAIR, he'll want a hand with something, he always does. Back by dusk and the first bowl's yours. Well — second. First bowl goes to the empty chair. That's the rule too."

**active_pages:** "Fish, onions, bones — caught, dug, traded. Dusk, traveler. A stew waits for no one, and tonight it's EVERYONE's stew."

**objectives:**
- `{id:"s6_fish", kind:"reach", text:"Catch river-fish at the ford", map:"iron_vein", pos:ANCHOR(iron_vein_ford), radius:50, grant_item:"honest_riverfish", arrive_note:"Twenty patient minutes and three fat river-fish. The Iron Vein runs its old-blood color even here — and the fish are fine, always have been. The river's rude, not wicked. There's a lesson in that somebody cleverer can have."}`
- `{id:"s6_onions", kind:"reach", text:"Dig bog-onions on the north bank", map:"iron_vein", pos:ANCHOR(north_bank_bog), radius:60, grant_item:"bog_onions", arrive_note:"The mud accepts your boots, your dignity, and very nearly a sock. In return: a full bag of bog-onions, sharp enough to make your eyes water through the sack. Honest goods drive a hard bargain."}`
- `{id:"s6_bones", kind:"talk", npc:"farmer", text:"Trade Farmer Ansel for marrow-bones (he'll want a hand)", pages:[
  "Marrow-bones for Rada's stew-night? Aye, gladly — that stew fed my grandfather a winter he doesn't talk about, which means it mattered. But trade's trade: my west fence is down two rails and the boar-sign is back. Shift those rails with me and the bones are yours with the Hollow's compliments.",
  "(Twenty minutes of honest lifting. Ansel talks the whole time — weather, the fair, his brother's boots, and once, quietly: 'good, this. Plain work. The fields feel... listened-at, lately, and plain work drowns it out.' Then, brighter:) There! A fence again. Bones are in the cold-shed — take the good ones, the stew deserves it." ]}`

**turn_in_npc:** `oar_keeper`
**turn_in_pages:**
1. "Fish, onions, bones — and mud to your ears, which is how I know the onions are genuine. Into the pot, all of it. Now sit. SIT. You've earned watching the good part."
2. "(The taproom fills as the light dies: bargees, farmhands, the ferry family, two wary strangers who get waved in anyway. The first bowl goes to the empty chair by the hearth. Nobody comments. Everybody sees it.)"
3. "(Rada raises neither glass nor voice — just says, to the room, the way you'd say 'mind the step':) Everything good is temporary. That's what makes it good. Eat up. (And the room does, loudly, warmly, all talking over each other — the single loudest sound of aliveness you have heard in this fog-drowned country, and it goes on for hours.)"

**rewards:** xp 540 · gold 0 · `bowl_of_founders_stew` (new item, consumable: +10% max hp for 1 hour; flavor: "The first bowl goes to the empty chair. This is the second.") + `oar_regular_token` (trinket: vendor discount at the Bent Oar)
**aftermath:** `oar_keeper`: ["Still tasting it? Good. That's the trick of stew-night: the fog gets the whole year, but it doesn't get THAT.", "The empty chair's bowl was gone by morning. It always is. I've stopped asking. Some questions the answer would only spoil."]

*Exemplar note: the second CHEERFUL shape — a gathering-triangle (reach+grant_item ×2, talk ×1) with zero combat, whose emotional payload is the canon epigraph delivered as tavern-talk. Ansel's one quiet line ('listened-at') is the permitted single held breath. This is the template for ~30 hearth-quests across both continents (Last Hearth, Maren's, waystations).*

---

## SIDE-07 · What Vera Pays For  — **GoT INTRIGUE**
| | |
|---|---|
| **id** | `side_vera_pays` |
| **zone** | Blestem — the Lower Market (zone 17) |
| **level** | 33 |
| **giver** | `vera_cold_hands` |
| **tone** | intrigue |
| **canon** | Lore VIII Vera Cold-Hands verbatim ("prices rumor by how many people it can kill; pays extra for kindnesses"); Lore V Strigoi ("information asymmetry as civic planning"); Lore I Pillar II (information = hardest currency) |

**summary:** Vera Cold-Hands fences overheard things. Someone is selling her a rumor that prices out at four deaths — and one of the four is the only person in Blestem who ever sold her a kindness. She wants the rumor'S SOURCE found before the rumor finishes maturing. Not to save anyone, she insists. To correct a market inefficiency.

**offer_pages** (Vera):
1. "Stand there. Buy something or be something worth watching — those are the stall rules. ...Ah. You're the outlander who walks like the walls aren't listening. They are, but the confidence is refreshing. I have work for exactly that walk."
2. "My trade: overheard things. I price a rumor by how many people it can kill — a two-death rumor buys bread for a week; a four-death rumor buys this stall. Three days ago a seller I don't know offered me a four-death piece: WHO fed the Gatereeve's ledger to the Morrow-street collectors last spring. I declined — too rich, wrong stall. He'll find a buyer by week's end. This market always finds a buyer."
3. "Why do I care? (Her cold hands sort dried herbs that are not the merchandise.) Item: one of the four deaths in that rumor is old Paven, the lamp-trimmer. Years back, Paven sold me a kindness — a warm story, true one, about a Strigoi clerk who un-filed a child from a culling list. I paid triple. Kindnesses are RARE stock; a dead supplier is a market inefficiency. So: find the seller before the rumor matures. This is inventory protection. It is NOT sentiment. Repeat that last part back to me before you go."
4. "The seller wears a river-man's coat too clean for the river, and he asks his prices in Ridgeway weights — an easterner faking low. Start at the wharf-gate stalls. And traveler — in this market, the walls take a commission on everything spoken. Haggle accordingly."

**active_pages:** "Week's end, outlander. Rumors mature faster than debts here — it's the one industry Blestem never lets slump."

**objectives:**
- `{id:"s7_wharf", kind:"reach", text:"Work the wharf-gate stalls for the too-clean river coat", map:"blestem", pos:ANCHOR(wharf_gate_stalls), radius:70, arrive_note:"Third stall down: a river-man's coat with no river on it, asking in Ridgeway weights. He's careful. He's also SELLING — sampling the rumor in slivers to price the whole. Two buyers are already circling like the polite carrion of this city."}`
- `{id:"s7_seller", kind:"talk", npc:"clean_coat_seller", text:"Approach the seller as a buyer", pages:[
  "A new face with old coin — my favorite denomination. You've heard what I'm holding? Slivers only, until the price firms: the Gatereeve's ledger walked to Morrow-street last spring, and I can name the FEET it walked on. Four names. Good names. Load-bearing names.",
  "Price? For the set — call it passage west and a purse that doesn't insult me. I'm done with this city; its walls have started repeating things I said in my SLEEP, and a man in my line knows exactly what that means and exactly how long he has.",
  "(Up close, the tell: his hands. Burn-scarred in the specific way of lamp-work. He isn't SELLING the lamp-trimmer's death — he's a lamp-man himself. Apprentice, maybe. Someone who learned four names doing the quiet rounds and is now cashing out the only inheritance Blestem ever pays its poor: what they overheard.)",
  "Well, buyer? The slivers are free. The names cost. And week's end, someone less pleasant than you pays the asking." ]}`
- `{id:"s7_choice", kind:"choice", npc:"", text:"Kill the rumor, buy the rumor, or turn the seller", prompt:"A lamp-man cashing out four deaths to buy his own escape. One of the four taught him the rounds.", retry_pages:["He's still at the stall. The circling buyers have stopped circling and started WAITING, which in Blestem is the louder verb."],
  a:{label:"Buy the whole rumor for Vera — every sliver, exclusive, and the seller's silence as a term", pages:[
    "(You pay his passage west and the non-insulting purse — Vera's coin, advanced against 'inventory.' The terms are Blestem-formal: all four names, exclusivity, and his oath — witnessed by the walls, which is the only notary here — that the rumor dies with the sale.)",
    "(He signs, sells, and is on a barge by dusk, west, alive, gone. The two circling buyers un-wait, expressions never changing. In the Lower Market, a done deal is weather: everyone simply adjusts.)" ],
    objectives:[], turn_in_npc:"vera_cold_hands", turn_in_pages:[
      "Exclusive, witnessed, and the seller shipped out breathing. Adequate work. (She locks the four names — unread, you notice — in the box below the herbs. The FALSE bottom below the false bottom.) A four-death rumor, retired at cost. My ledger calls that a loss. My ledger is not consulted on everything.",
      "The lamp-trimmer keeps trimming, none the wiser, and my kindness-supply keeps its supplier. Inventory protection, outlander. Say it with me. ...Good. Here's your fee — and a sliver of advice, free, because you held the stall rules: the walls heard the whole transaction. They always do. What keeps YOU safe is that Blestem's walls answer to a man who respects a completed contract more than he respects blood. Pray that remains the fashion." ],
    rewards:{xp:2970, gold:120, items:["lower_market_marker"]},
    note:"The rumor is bought, boxed, unread, dead. The seller is west and breathing; Paven trims lamps, unaware he was four names' worth of dead. Vera's ledger calls it a loss. Her ledger is not consulted on everything. [world flag: vera_favor]", aftermath:{}},
  b:{label:"Out-leverage him: reveal you know his lamp-scars — turn him into Vera's ASSET in place", pages:[
    "(You lay it out quietly: the burn-scars, the rounds, the apprenticeship — enough identification to be a death sentence at any of six stalls in earshot. Then the offer: don't sell. don't run. STAY. Feed the wharf-gate's overhearings to Vera's stall on retainer, and Blestem's most connected fence will make sure the walls' owner never learns which lamp-man knew what.)",
    "(He is grey by the end. Then he does the Blestem arithmetic — asset beats corpse, always, everywhere — and nods. In this city, that nod is a contract with more teeth than parchment.)" ],
    objectives:[], turn_in_npc:"vera_cold_hands", turn_in_pages:[
      "You turned him. IN PLACE. (For a full second, Vera's cold hands go still — her version of applause.) A lamp-line into the wharf-gate ward... do you know what that FEEDS? Every ledger that walks after dark walks past a lamp. I priced you as muscle, outlander. I under-priced.",
      "The four names stay un-sold because their seller now profits more from silence — the only silence this city considers structurally sound. Pavens keeps his lamps AND his apprentice, who will now never, ever tell him any of this, which is its own small mercy or its own small cruelty. Here we call that Tuesday.",
      "Your fee — plus the marker. And do note what you did today, because it's the whole city in one stall: nobody died, nobody's saved, everyone's LEVERAGED, and the market calls it peace. Welcome to Blestem, outlander. You speak it natively now. That should worry you at your leisure." ],
    rewards:{xp:2970, gold:200, items:["lower_market_marker"]},
    note:"The seller sells nothing, forever, on retainer. Pavens keeps his lamps and an apprentice with a second employer. Nobody died; nobody's saved; everyone's leveraged. The market calls it peace. [world flags: vera_favor, wharf_lamp_line]", aftermath:{}}}`

**rewards:** xp 2970 · `lower_market_marker` (new item, trinket: Blestem vendor access tier; flavor: "Good for one answered question at any stall. The walls take their commission regardless.")

*Exemplar note: the INTRIGUE shape — no combat, three parties, and the resolution axis is leverage vs. leverage (kill-the-rumor as a PURCHASE; mercy as market logic). Vera's 'inventory protection, not sentiment' is the Strigoi register for warmth — intrigue quests must always hide their one warm thing inside a ledger.*

---

## SIDE-08 · Grain for Words  — **GoT INTRIGUE**
| | |
|---|---|
| **id** | `side_grain_for_words` |
| **zone** | The Western Lowlands (zone 8) |
| **level** | 24 |
| **giver** | `quartermaster_helva` (Angel Wings) |
| **prereq** | soft-linked from `side_granary_full` |
| **tone** | intrigue |
| **canon** | Lore V Angel Wings grit verbatim ("villages that sell information to Blestem to eat through winter"); Lore V Flashpoint 2 (the Lead Box leak "probably through a starving western village"); Lore VII Fielderine |

**summary:** Helva's grain-ledgers have found a village that doesn't add up: Merrowdown eats through every winter without drawing Crown relief. The arithmetic says they're selling something. In the west, a village with nothing left sells the only crop that grows in a bad year: what it overhears. And Merrowdown sits on the coach road where Crown couriers stop.

**offer_pages** (Helva):
1. "Close the door. This is a grain conversation, and grain conversations are the most dangerous kind I have. Sit. Look at this column. Merrowdown: four hard winters, zero relief-draws, granary levies paid IN FULL and early. Now look at their acreage. Now look at me telling you that acreage doesn't feed that village past midwinter in a GOOD year."
2. "So they're selling. Not grain — they haven't any. Not daughters or sons to the forges — I count heads, it's my whole grim talent, and Merrowdown's heads are all present and fed. Which leaves the west's one reliable cash crop in a starving year: WORDS. And Merrowdown sits astride the coach road, traveler. Crown couriers water their horses there. Clerks talk in taprooms there. And somewhere east of us, a man in a maze pays generously for exactly that watering-stop chatter."
3. "The Queen knows what I'm about to tell you: we cannot simply hang a hungry village for talking. First, because she won't — feeding people is her whole doctrine, and a doctrine you drop when it's expensive was never a doctrine. Second, because a plugged leak teaches the buyer nothing, but a MANAGED leak... (she taps the ledger, once). Go to Merrowdown. Find me the seller, the route, and the buyer's rate. And touch NOTHING until you've reported. In this trade, the finding is the cheap part. The deciding is what keeps queens up nights."

**active_pages:** "Seller, route, rate. And keep your coin in your coat — the moment you buy anything in Merrowdown, you're in somebody's ledger too."

**objectives:**
- `{id:"s8_village", kind:"reach", text:"Take a room in Merrowdown as a passing traveler", map:"western_lowlands", pos:ANCHOR(merrowdown_inn), radius:60, arrive_note:"Merrowdown in famine-season: thin fields, patched roofs — and fed children, sound boots, a taproom with real candles. The innkeeper's wife asks where you've traveled from with a warmth that is one question too specific. Everyone here listens WELL. It's the town's whole posture."}`
- `{id:"s8_watch", kind:"reach", text:"Watch the coach-road watering stop at courier-hour (night)", map:"western_lowlands", pos:ANCHOR(merrowdown_trough), radius:50, night_only:true, arrive_note:"A Crown courier waters his horse and gossips at the trough — harmless, tired, loud. Behind the tack-shed, the innkeeper's wife writes nothing down. She doesn't need to. You watch her LISTEN, and it is a craftsman's listening. Later, a boy runs the eastern hedgerow with something learned by heart."}`
- `{id:"s8_seller", kind:"talk", npc:"merrowdown_hostess", text:"Put it to the innkeeper's wife, quietly", pages:[
  "(You catch her alone at the cold-larder. She reads your face the way she reads couriers — fast, deep — and something in her shoulders sets, like a woman putting down a heavy basket she's carried four winters.) So. You're either Blestem checking its asset or the Crown checking its arithmetic. Sit. Either way you'll want the true version.",
  "Four winters back the yield failed — the QUIET way, the way nobody paints: not locusts, not fire, just less, and less, and children with that patient look they get. We drew no relief because the relief boards post the drawing villages' names, and named villages get their levies 'reassessed.' You starve faster on the Crown's mercy than off it — write THAT in a ledger someday.",
  "Then a pedlar with too-good boots offered coin for 'road news.' Nothing wicked, he said. Who waters. Who talks. What the talkers say. And saints forgive me, it was the truth: nothing wicked — wicked would've been easier to refuse. Just TALK, traded east, and my children ate that winter, and the next, and I learned my trade, and now the whole village eats off my listening and pretends not to know why the candles are real.",
  "So there's your seller, Crown-man-or-whoever. One tired woman with good ears. The rate is forty silver a season. The route is a boy and a hedgerow. And the price — the real one — is that I haven't slept an honest night in four years, because some spring a courier will water his horse and mention a LEAD BOX, and I will have to decide whether my children eat off THAT too. Now: what happens to Merrowdown?" ]}`
- `{id:"s8_choice", kind:"choice", npc:"", text:"Report to Helva — but recommend what?", prompt:"Seller, route, rate. The finding was the cheap part.", retry_pages:["Helva's seal weighs your pocket. Whatever you recommend, a queen reads it by candle tonight."],
  a:{label:"Recommend the managed leak: turn Merrowdown into Fielderine's instrument", pages:[
    "(Helva reads your report twice, then a third time, then does the rarest thing in her repertoire: she smiles, and it is Cazimir's smile worn on a decent woman, which is an education in itself.)" ],
    objectives:[{id:"s8_helva_a", kind:"talk", npc:"quartermaster_helva", text:"Deliver the recommendation", pages:[
      "A working line into the Riddler's Quarter that BLESTEM built, paid for, and trusts. Do you know what this is worth if we don't plug it — if we FEED it? Every season, the hostess sells true chaff and one grain of our choosing. The east pays her to carry OUR words in HER voice. The Queen will hate it. The Queen will approve it. Those two facts describe her whole reign.",
      "Merrowdown's levies get quietly halved — 'clerical revision' — so the village eats without the trade, and the trade continues anyway, managed, because a leak that stops is a leak the buyer investigates. The hostess keeps her forty silver and gains a Crown pension she'll never see the shape of. And she sleeps — well, better. Nobody in this trade sleeps WELL.",
      "You've a talent for the ugly arithmetic, traveler. That's not flattery. Flattery is pleasant." ]}],
    turn_in_npc:"", turn_in_pages:[], rewards:{xp:2160, gold:150, items:["helvas_cipher_button"]},
    note:"Merrowdown eats twice now: off halved levies, and off Blestem's coin — carrying Fielderine's chosen grain east in a tired woman's true voice. The Queen hated it and approved it. Those two facts describe her whole reign. [world flag: merrowdown_turned]", aftermath:{}},
  b:{label:"Recommend mercy without the leash: halve the levies, end the trade, tell Blestem nothing", pages:[
    "(Helva reads your report twice. The second time, her finger stops on the line about the relief boards posting names, and stays there a long while.)" ],
    objectives:[{id:"s8_helva_b", kind:"talk", npc:"quartermaster_helva", text:"Deliver the recommendation", pages:[
      "End the trade, feed the village, run no double game. (She sits back.) You know what my trade says? WASTE. A built line into Blestem, burned for sentiment. And you know what the relief-board line in your report says? That my own system taught a good village that honesty starves. The Crown made this seller, traveler. Before any pedlar did.",
      "So: levies halved, quietly. The boards reformed — no more posted names; I'll bleed for that one in council but I'll win. And the trade just... goes dry. The hostess tells her buyer the couriers changed routes. Blestem shrugs — the west was cheap chatter anyway. And one woman sleeps, and her children eat off honest arithmetic for the first time in four winters.",
      "The Queen will call this the expensive choice. Then she'll fund it. That's the doctrine, and today — (Helva signs it) — the doctrine held. Take your fee. This one I pay gladly, which happens about twice a decade." ]}],
    turn_in_npc:"", turn_in_pages:[], rewards:{xp:2160, gold:150, items:["helvas_cipher_button"]},
    note:"Levies halved; relief boards reformed; the trade gone dry with a shrug from the east. One woman sleeps. The expensive choice — funded, because a doctrine you drop when it's costly was never a doctrine. [world flag: merrowdown_freed]", aftermath:{}}}`

**rewards:** xp 2160 · `helvas_cipher_button` (new item, trinket; flavor: "A plain coat button. The pattern of its thread is a Crown cipher. You will never be told which coat to watch for.")

*Exemplar note: the second INTRIGUE shape — western register (mercy vs. tradecraft instead of leverage vs. leverage). The `merrowdown_turned` flag feeds the Lead Box leak flashpoint content at 28–32 (Lore V Flashpoint 2). Note both branches indict the SYSTEM (relief boards) — GoT law: every faction gets a legitimate grievance.*

---
---

# PART C — DAILIES (4 repeatable shapes)

Dailies are the grind's heartbeat (slow WoW-Classic pacing). Rules: (1) each daily is a *ritual*, not an errand — it must dramatize the zone's ongoing wrong; (2) flavor text rotates from a small pool so repetition reads as vigil, not copy-paste; (3) XP = `level × 25`; (4) engine needs a `repeatable: "daily"` def key (§7).

---

## DAILY-01 · Walk the Wells  — *reach-patrol shape*
`id: daily_walk_the_wells` · **zone** The Copper Wells (4) · **level** 9 · **giver** `wellwatcher_petru` · **tone** dread-neutral
**canon:** WORLD_PLAN zone 4 ("environmental puzzle-tutorial — read the land"); Lore II symptom order.

**offer (first time):** "Petru. Wellwatcher — self-appointed; the appointment committee died of not watching wells. The moor has nine wells and three moods: clean, coppering, and gone. Every dawn someone has to taste the difference — LOOK at the difference, saints, never taste — and chalk the lids: white for clean, red for turning. Skip a day, and a family waters at a well that was white yesterday. There are no days off from geology that hates you. Walk three for me?"
**repeat offer (rotating pool):** "Three wells, traveler. The moor moved overnight — it does that now." / "Chalk's by the door. The red stick's shorter every week. I try not to read that as an omen. I fail." / "Well six was singing yesterday. Wells don't sing. Three today — six FIRST."
**objectives:** `reach` ×3 (rotating anchor pool of nine well positions; each with `arrive_note` variants: "Clean. Cold. Honest water. You chalk it white and enjoy the rarest feeling on this moor: nothing." / "The bucket comes up faintly pink, and the moss on the shaft is dying in a neat ring. Red chalk. Somebody's tomorrow just got harder." / "Warm stones. Aligned dust on the lid. You chalk it red twice and do not linger.").
**turn-in (rotating):** "Two white, one red? That's a GOOD day now. Saints, listen to what I just called a good day." / "All three holding. I'll take it. The moor gives you nothing twice."
**rewards:** xp 225 · gold 27 · `wellwatchers_chalk` stub (5 charges of well-reading = minor detection buff)
*Shape note: pure reach-rotation; the daily teaches land-literacy and quietly tracks zone corruption — integration may shift the anchor pool's notes as world flags accumulate.*

## DAILY-02 · Salt the Thresholds  — *use_item shape*
`id: daily_salt_thresholds` · **zone** Vetka (2) · **level** 5 · **giver** `old_marta_vetka` · **tone** dread-neutral, warm
**canon:** Lore VIII Old Marta ("kept people alive by keeping them incurious"); Lore IX Yeastless ("fire and salt — the old preservations").

**offer (first time):** "You've the look of someone who can carry salt without asking it philosophical questions — hired. Three doors on this lane get a salt-line every dusk: Torn's, because he finds things interesting lately; Dorica's, because her bread's gone flat and flat bread means the house is LISTENING even if she isn't; and the empty one, because empty houses are only empty if you keep them that way. Does salt work, you'll ask? The wrong question, dear. The RIGHT question is: has anything crossed a line I've laid in forty years? Also no. We don't audit what's working."
**accept_items:** `["martas_salt_pouch"]` (3 uses)
**objectives:** `use_item` ×3 (`martas_salt_pouch` at ANCHOR(torn_door), ANCHOR(dorica_door), ANCHOR(empty_house_door), radius 25 each).
**turn-in (rotating):** "Three lines, laid at dusk, by hands that didn't ask questions. That's the whole craft, dear. The incurious live longest out here." / "Torn watched you do his step, didn't he. Watched, and hummed. ...Lay his line double tomorrow."
**rewards:** xp 125 · gold 15
*Shape note: use_item rotation; the flavor pool escalates with Vetka's zone-state (Torn's entrancement arc). Old Marta is THE canon herb-woman — her dailies are how players know her before her stick outlives her.*

## DAILY-03 · The Warband Won't Stay Down  — *kill shape*
`id: daily_cull_warband` · **zone** Gravemark Tundra (15) · **level** 56 · **giver** `threadwarden_ilka` · **tone** dread-neutral, heavy-adjacent
**canon:** WORLD_PLAN zone 15 (Great-War mass graves, skeleton warbands); Lore VIII Threadwarden Ilka ("she names the shells. Regulations forbid it."); Lore VI thread canon (severed = inert).

**offer (first time):** "Warden Ilka. I tend this section of the containment — re-seat slipping wills, soothe the restless rows. But the old muster-graves out past the kerb-stones have been... surfacing. Warbands, still in formation, still carrying the Great War in their spine-memory. Off-thread — nobody's driving them, understand; they're just old orders with no one left to countermand. Put them down along the kerb-line. Cleanly. And — a personal asking, not a warden's: they were soldiers once. Don't whoop."
**repeat offer (rotating):** "The east rows surfaced again overnight. Same formation. They always muster facing SOUTH — toward the war. Six hundred years and they still think the enemy's south." / "Twelve up by the kerb-stones. I named the lead one Costel — regulations forbid it, and regulations can weep. Put Costel back down gently."
**objectives:** `{kind:"kill", enemy:"skeleton_warband", count:12}` (twelve — the grammar again) + `{kind:"reach", text:"Report the kerb-line clear", ...}`.
**turn-in (rotating):** "Down, and along the kerb where the stones can watch them. Thank you for not whooping. You'd be surprised. You'd be sickened, actually." / "Costel too? ...Good. Good. Tomorrow there'll be twelve more and I'll name them too. It's not futility, traveler. It's ATTENDANCE."
**rewards:** xp 1400 · gold 168
*Shape note: the endgame kill-daily; count 12 enforces the body-grammar motif even in grind content. Ilka's rotating names make repetition a mourning ritual — the daily IS the theme.*

## DAILY-04 · Turn One Back  — *talk/escort shape*
`id: daily_turn_them_back` · **zone** The Listening Steppe (14) · **level** 41 · **giver** `scout_widow_pall` (seconded north) · **tone** dread-neutral
**canon:** WORLD_PLAN zone 14 (the drawn stand "listening"); Lore IX Listeners ("get them out before they understand"); Lore VIII Scout-Widow Pall.

**offer (first time):** "Pall. I read the fog-line for the Crown, and the Crown lent me north because the steppe's got a HARVEST coming up — the walking kind. Pilgrims cross here, heads full of that hum, feet full of somebody else's errand. The fresh ones — the ones who still flinch at their own name — can be turned back. One a day, most days, if you catch them early and you're gentle and you're LUCKY. That's the job: walk the wind-line, find the freshest, say their name until it lands, and walk them to the shelter-cairn. One a day. It's not nothing. Out here, one is the biggest number there is."
**objectives:** `{kind:"reach", text:"Find the freshest walker on the wind-line", ...arrive_note:"A woman, mid-step, head tilted. When you say 'hello' she flinches — FLINCHES. Fresh. There's still a tenant."}` → `{kind:"talk", npc:"steppe_walker", pages:[rotating pool — e.g. "'—the barley,' she says, waking mid-sentence. 'I was... I left the barley wet. How long was I—' (Don't answer that. Pall's first rule: never answer that.)"]}` → `{kind:"reach", text:"Walk her to the shelter-cairn (stay close)", escort:"steppe_walker", ...}`.
**turn-in (rotating):** "One back. Write nothing, celebrate nothing, sleep BADLY — and be here tomorrow. That's the whole liturgy." / "She asked you how long, didn't she. They always ask. The kind lie is 'not long.' The kind lie is the only equipment this post issues."
**rewards:** xp 1025 · gold 123
*Shape note: talk+escort daily reusing the Mira escort-lite controller. The rotating rescued-walker pool (names, half-sentences they wake into) is authored content — 20 variants minimum, so the grind stays human.*

---
---

# PART D — EVENT QUESTS (3)

Events are scheduled world-states (engine extension §7): a zone-wide or world-wide condition with its own quest(s), barks, and ambient overrides. Rule: one villain-owned event, one warm event, one faction event — the tone law applied to the calendar itself.

---

## EVENT-01 · The Night of Held Breath  — *world event, villain-owned*
`id: event_held_breath` · **zone** ALL (world event, one night per season) · **level** scales (exemplar tuning: 30) · **giver** auto_trigger at any lit settlement at event-dusk · **tone** creepy/mythic
**canon:** Lore II the melody ("you can hear it... in the pitch of the wells"); demo finale beat (all lights dim one breath); Lore X (the stone "seduces with relief").

**summary:** One night a season, every lantern in Draconia dims at the same instant, for the length of one held breath — the notes drifting a hair closer. The night that follows is the year's worst: wells sing, listeners walk, the drawn stand up mid-supper. Every settlement holds the Vigil: lamps doubled, names called, doors watched till dawn.

**offer_pages** (any settlement's warden — exemplar: Gatewarden Iosif):
1. "You felt it at dusk — everyone feels it. Every lamp in the world, down and up again, like the night swallowing once. The old folk call what follows the Night of Held Breath, and they board their shutters, and the old folk are RIGHT."
2. "Tonight the quiet things are loud. Wells sing. The listening kind stand up mid-supper and walk — ALL of them, everywhere, the same night, which tells you something about who's conducting. So we hold the Vigil: double lamps, count heads hourly, and walk the walls calling names till dawn. A called name is an anchor, my grandmother said. Tonight we anchor everything we can't afford to lose."
3. "Take the east rounds. Lamps lit, names called, walkers turned back or walked home. And traveler — whatever you hear singing out past the wall in your OWN voice tonight: it isn't. Hold your breath and walk on. That's the whole doctrine. Dawn pays for everything."

**objectives (event-night, repeatable per event):**
- `{kind:"use_item", item:"vigil_taper", count-shape: relight 4 lamp-anchors, night_only:true}`
- `{kind:"talk", npc:"vigil_walker_*", text:"Call a wanderer by name and turn them home"}` ×2 (rotating pool)
- `{kind:"kill", enemy:"night_listener", count:6, text:"Put down what the singing raised at the wall"}`
- `{kind:"reach", text:"Stand the dawn watch at the gate", night_only:true, arrive_note:"Dawn comes up grey and ordinary and MAGNIFICENT. The lamps gutter out one by one, unneeded. Somewhere below the world, three notes hold — two and a stubborn third — for one more season."}`

**turn-in** (Iosif): "Dawn, and the count is EVEN — every head that sat to supper wakes to breakfast. You'll hear no songs about a night where nothing was lost, traveler. Write your own. Nobody sings about us, but the walls stay standing." · **rewards:** xp 1200 (scaled) · `vigil_lantern_charm` (trinket: +listening resistance, event-upgradeable each season) · **finale_beat:** `pause_breath` (all lights BRIGHTEN one step at dawn — the finale's grace-note, foreshadowed seasonally).
*Shape note: the villain's calendar presence — the same held-breath dimming the player saw at Mira's gate, scaled to the world. Event content scales by zone bracket; the count-is-even turn-in line is fixed canon-voice across all settlements.*

## EVENT-02 · The Harvest Fair at Raven Hollow  — *annual, warm*
`id: event_harvest_fair` · **zone** Raven Hollow (1) · **level** any (scaled rewards) · **giver** `innkeeper` (Marta) · **tone** cheerful
**canon:** `npc_data.gd` (fair, pear tree, wish-coins, fountain — four separate NPCs seed it); Lore I §6 (kindness small, real, doomed — but not TODAY).

**summary:** The fair the villagers have been talking about since the demo: the whole village out, Vasile down from his hill, wish-coins in the fountain, Ansel's pears, a pie contest Marta has won eleven years running and intends to win a twelfth.

**offer_pages** (Marta): 1. "Fair day! No dread today, traveler — I've BANNED it, and the ban holds till sundown, I've been assured by everyone who fears my ladle. You're conscripted: three errands, all of them beneath your station, all of them the most important work you'll do this season." 2. "One: pears from Ansel's grandfather-tree — the fountain tree feeds the fair, that's the LAW. Two: fish Emeric out of whatever he's climbed. Three: a wish-coin in the fountain — your OWN wish, mind, none of your grim professional ones. Off you go. The pie waits for no one, and neither do I."
**objectives:** `{kind:"talk", npc:"farmer"}` (pears + one Ansel story about the bad winter the tree fed half the Hollow) → `{kind:"reach", ANCHOR(fair_mishap)}` (rotating comic anchor: Emeric up the pear tree / the pig loose among the pies / Vasile judging the vegetable contest with terrifying literalism: "This marrow is the healthiest thing I have examined in forty years. It disturbs me. First prize.") → `{kind:"use_item", item:"wish_coin", ANCHOR(fountain), radius:30}` (arrive_note: "You flick the coin. It catches the light going down. You don't tell anyone the wish. That's the rule, and today — today it feels less like superstition and more like the one piece of encryption the whole fogged world still trusts.")
**turn-in** (Marta): "Pears delivered, boy retrieved, wish sunk — and MY PIE TOOK TWELFTH-YEAR GOLD, not that the outcome was ever in doubt, Tibalt's crust was a CRIME. Here — winner's slice, first cut. Eat it in the sun, traveler. The fog gets the whole year. It doesn't get today." · **rewards:** xp scaled ×40/level · `martas_prize_slice` (consumable: +10% all stats 1 hr) · `fair_ribbon` (cosmetic trinket, year-stamped — collectible across annual fairs).
*Shape note: the warm event — zero combat, three comic set-pieces from a rotating pool so each year differs, one collectible that quietly measures how many years the player has kept this world alive. Vasile's fair barks are the tonal hinge: the gravekeeper in sunlight, enjoying himself, terribly.*

## EVENT-03 · The Count of Three  — *Sangeroasa zone event*
`id: event_hammers_stop` · **zone** Sangeroasa (22) · **level** 45 · **giver** auto_trigger (the event IS the trigger) · **tone** creepy/heavy
**canon:** Lore IV Sangeroasa vignette 2 verbatim ("The hammers stop. All of them, at once, for a count of three. Then resume. No one will meet your eye about it."); WORLD_PLAN zone 22 vignette.

**summary:** At an unscheduled moment, every hammer in the forge-city stops — one, two, three — then resumes. During those three counts, and the shaken hour after, things are possible that are never otherwise possible in Sangeroasa: pit-thralls look UP, a ledger goes unwatched, a door into the Debt Pit's counting-house stands open. The player has one hour in a city pretending nothing happened.

**objectives (event-hour):** `{kind:"reach", ANCHOR(counting_house_door), arrive_note:"Open. In six centuries of forge-law this door has never stood open. Inside, the day-ledgers sit unattended — because every clerk in the city is standing very still, not meeting anyone's eye, waiting for the hammers to make the world make sense again."}` → `{kind:"choice"}`: **a)** copy the pit-quota page for Olga's rim-committee (evidence that quotas rose the week of every 'stoppage' — the Pit feeds on the fear of its own silence) — intrigue-thread reward, `world flag: rim_evidence`; **b)** carry water down to the pit-thralls while the bosses stand frozen (talk ×3, rotating thrall pool — "the thrall drinks, looks UP — the first up-look of his adult life — and says: 'it stopped. I heard it stop. If it can stop for three... it can stop.'") — `world flag: pit_hope_1..n`, a slow-burn counter feeding the endgame's south-arm epilogue.
**turn-in:** none — auto-complete at hour's end: "(The hammers resume mid-thought, all at once, and the city exhales into its haze and agrees, unanimously, silently, that nothing happened. Your boots know otherwise. So does one thrall who looked up. The count is coming again — everyone in Sangeroasa knows it and no one says it: someday the count of three will be a count of four, and the city holds its breath about what resumes THEN.)" · **rewards:** xp 1800 · event-token currency.
*Shape note: the faction event — a timed world-state window (engine §7) where the quest content only exists DURING the anomaly. The unexplained stoppage is never explained (canon: no one will meet your eye); the design honors it by never explaining either.*

---
---

# PART E — CLASS QUESTS (3 exemplars of the 7-class set)

Class quests fire at level 20 (spec-defining) — one exemplar each for a martial, a ranged/utility, and the lore-dangerous class. Rule: a class quest teaches WHO YOUR POWER BELONGS TO in Draconia's hard-magic terms (Lore VI: no spellcasters; the necromancer class is *borrowed thread* — see guard note).

---

## CLASS-01 (Warrior) · Steel Remembers
`id: class_warrior_steel` · **zone** Raven Hollow → The Bloodroad (26) · **level** 20 · **giver** `blacksmith` (Goran) · **tone** dread-neutral/heavy edge
**canon:** demo `gorans_targe` ("same winter, same steel lot — the only quiet piece"); Lore X GORESCREAM (Fidor, the neurotoxin edge, "forge for consequence"); Lore VI (no free power).

**summary:** Goran will forge the player's spec-weapon — but the only steel worthy of it comes from the lot that produced the weeping dagger and the quiet targe: a Bloodroad convoy carries the last three ingots of it north. Goran wants an ingot won FAIR — bought, bartered, or taken from the convoy's fighting champion in an honest circle — and then the player must choose the temper.

**offer (Goran, abridged to the load-bearing pages):** 1. "You swing like the steel owes you money. It doesn't. Time you learned what it DOES owe you, and the only way to learn that is to be there when your weapon is born." 2. "Winter-before-last's lot — the dagger you know about, the targe you carry. Same pour. One piece wept, one kept quiet, and I've spent two years wondering what decides. The answer's in the TEMPER, and the last three ingots of that lot roll north on a Varcolaci convoy this week. Win one fair — coin, trade, or their champion's circle, I don't care which, but FAIR. Steel remembers how it was got. That's not smith's poetry. I wish it were."
**objectives:** `reach` (Bloodroad convoy camp) → `choice` — **a)** fight the convoy champion in the circle (`kill`, enemy:"varcolaci_champion", count:1 — honor-duel framing, the champion yields at the end: "GOOD. The north sends so few who understand the circle. Take the ingot — it goes to a hand that earned it in front of witnesses, which in Sangeroasa arithmetic makes it FREE.") / **b)** trade Goran's proxy-work (a season of repair-debt Goran authorized: "his mark buys more on this road than the King's — the King's mark commands, Goran's mark PAYS"). → `talk` (Goran, the forging — the quest's heart): "Now the temper. Fidor of Tilamar quenches in blood and volcanic salt — the edge that unmakes the will to stand. I can DO that temper. I know it like I know a bad debt. Or we quench it plain — water, oil, patience — and it comes out a shade slower, a hair heavier, and QUIET for the rest of its working life. The weeping lot and the quiet lot, traveler. Same steel. The pour doesn't decide. The QUENCH decides. So decide." → `choice`: **a) plain quench** → weapon `quiet_steel_[spec]` (solid, honest stats; flavor: "Same steel. The quench decides.") / **b) ask for the Fidor temper** → Goran refuses — and the refusal is the content: "No. And now you know the last thing about smithing I can teach: the customer is the final quench. You ASKED, and the asking is in you, not the steel — so I'll give you the quiet blade and you'll carry the asking around and see how it weathers. Come back in ten years and tell me which of us the edge belongs to." (same weapon, plus hidden flag `asked_for_the_edge` — read by south-arm dagger content).
**rewards:** xp 1600 · `quiet_steel_weapon` (spec-appropriate: 1h/2h per build) · **aftermath** (Goran): ["Quiet so far? Good. Quiet is a lifetime achievement, in steel and in men. Mind the sparks."]
*Shape note: martial class template — the class fantasy (your weapon) welded to the canon item-law (desire is the attack vector). The b-refusal is the exemplar's key move: class quests may deny the player and make the denial the reward.*

## CLASS-02 (Rookwarden) · What the Rooks Keep
`id: class_rookwarden_rooks` · **zone** Raven Hollow → The Stonepath (6) · **level** 20 · **giver** `wanderer1` (Old Petra) · **tone** dread-neutral/creepy edge
**canon:** demo `ravens_eye` + Petra's rook-lore ("the only thing a rook won't roost over is a thing that watches back"); WORLD_PLAN zone 1 (village named for the ravens); class_defs `rook_companion`.

**summary:** The rookwarden's companion is not a pet — it is a PACT with the parliament above the graveyard, and Petra (who has been the Hollow's unofficial rook-speaker for sixty years) is retiring the office. The trial: carry a nestling from the graveyard parliament along the Stonepath, past three inscription stones, and learn the one thing a warden must never do — send the bird where the bird won't go.
**offer (Petra):** 1. "Sit, dear. My mother kept the rooks, and hers, back past the old king — someone in this village always has, since it was named. The birds keep US, is the truth of it: they won't roost over what watches back, and a village that learns to read its own rooks has a sentry that never sleeps and never lies. My knees have voted: the office is yours, if the parliament agrees. They're particular. They liked how you handled the shaman business." *(reads `ravens_eye`/q4 flags)* 2. "The trial's simple and it isn't: walk a nestling down the Stonepath — past the standing stones, PAST them, mind — to the old rookery oak and home again. Watch what she watches. Refuse what she refuses. The whole craft is in the refusing, dear. Any fool can send a bird. A warden learns where not to."
**objectives:** `reach` (graveyard parliament, dawn; grant_item `hollow_nestling`; arrive_note: "The parliament regards you from the yew tops — forty small black judiciaries. One nestling, bold and unimpressed, steps onto your arm like an audit.") → `reach` ×3 along the Stonepath, each anchor NEAR an inscription stone, each arrive_note the same lesson deepening: "You lift your arm to send her over the standing stone — scouting, the natural thing, the USEFUL thing. She grips. She will not go. She looks at you with one eye, then the other, the way Petra looks at fools. Over the stone the air is empty of everything — no rooks, no crows, not a wing. You mark the stone's position from the GROUND, the long way, the warden's way." → `talk` (Petra, at the rookery oak): "Three stones, three refusals, and you marked them all afoot? Then you've learned it, and I'll say it plain just once so you can forget it slowly like I did: the bird is not your TOOL, dear. The bird is your BETTER JUDGMENT, wearing feathers. Every warden who ever sent one where it wouldn't go got back a bird that goes anywhere — and a bird that goes anywhere is just a crow, and a warden with a crow is just a lonely person with bread. Keep her refusals. They'll keep you."
**rewards:** xp 1600 · `rook_companion` ability unlock (class kit) + `petras_weathered_glove` (trinket: companion sight-share detection pulse, long cooldown; flavor: "Sixty years of refusals, worn smooth.") · **aftermath** (Petra): ["She rides your shoulder like she invented you. Good. The parliament's voted, then. ...The office comes with one duty, dear: when the rooks all rise at once and won't land — you TELL someone. You tell everyone. Even when they laugh. ESPECIALLY then."]
*Shape note: utility-class template — the class mechanic (companion) is taught as canon detection-doctrine (rooks = diegetic orange-warning). The refusal mechanic seeds every future rookwarden objective: integration gives rook-scouting a hard no-go over live stones, and that limitation IS the class's lore armor.*

## CLASS-03 (Necromancer) · A Borrowed Thread  — *the lore-dangerous class*
`id: class_necro_borrowed` · **zone** The Stonepath → Gravemark approaches (6→15 edge) · **level** 20 · **giver** `threadwarden_ilka` (on southern circuit) · **tone** heavy/creepy
**canon:** Lore VI HARD RULE 2 ("exactly one necromancer... no player necromancy") — **honored via the sanctioned frame:** the player class is a *thread-tender*, working borrowed slack in Lilith's own network under warden license; all animation is still HER thread (design extrapolation, flagged, consistent with Ilka's canon role "re-seats slipping wills"). Lore VIII Ilka ("she names the shells").

**summary:** The class's power is a license, not a gift: Ilka inducts the player as a circuit-tender — hands that may take up SLACK thread where the network sags, drive a shell for the network's OWN maintenance, and must return every borrowed filament at circuit's end. The trial is a raising, a working, and — the part that decides whether the license holds — a laying-down.
**offer (Ilka):** 1. "So you're the one the thread bends toward. Don't preen — it bends toward certain hands the way rivers bend toward low ground, and low ground should hear that as the warning it is. The Council calls what I do 'maintenance.' The Queen's word for it is older: TENDING. And tending needs hands, and the circuit is long, and I am — the shells and I have an understanding about my age that I'll thank you not to disturb." 2. "Understand what you will NEVER be, and we'll get along: there is one necromancer in this world. One. What you'll hold is her slack — borrowed filament off the containment web, licensed, logged, and RETURNED. The power isn't yours. The RESPONSIBILITY is. That's the trade, it's non-negotiable, and it's the only version of this craft that doesn't end with you as a lesson in somebody's file." 3. "The trial is one circuit: raise a slipped shell at the old muster-grave, work it — there's a kerb-stone collapsed on the containment line that needs shifting, four living backs' worth, or one tireless one — and then lay it down again. Properly. The raising any low ground can do. The LAYING-DOWN is the license."
**objectives:** `reach` (muster-grave; arrive_note: "The slipped shell lies where the thread dropped it — a Great-War soldier, six hundred years past his war. The slack filament drifts above him, blue under any light, waiting for low ground.") → `use_item` (`borrowed_filament`, at the grave — the raising: "The thread seats. The shell rises. And you feel it, exactly as Ilka said you would: the borrowed will running through your hands like cold water through a glove — power that fits perfectly and belongs to someone else, which is the most dangerous fit there is.") → `reach` (collapsed kerb-stone, escort:"tended_shell" — the working) → `choice` — the laying-down: **a) Lay it down with a name** — "(Ilka's way — the forbidden, correct way. You give the shell a name as the thread pays out: not its own, which is six centuries lost, but A name, spoken once. The shell settles into the grave like a man getting into bed after a long watch. The filament returns to the web without a snag.)" → rewards class kit + `wardens_license` trinket; Ilka: "You NAMED it. Regulations forbid — (she stops. Her mouth does something old.) — the license is yours. Tend well. And when the day comes that the borrowed will fits TOO well — and it comes for every tender, it came for me — you lay YOURSELF down for a season. That's in the license too, in the small script. Read the small script." / **b) Lay it down silent, by the regulation** — same mechanical result; Ilka: "Clean. Regulation. LICENSED. ...And cold, tender. The craft will let you be cold — the craft PREFERS it, that's how the Council likes its circuits. But hear an old warden's actuarial note: the silent tenders last ten years. The naming ones last forty. The web can tell the difference, even if the regulations can't. Something in the thread prefers to be held by hands that grieve." (hidden flag `silent_tender` — read by Black Night arc).
**rewards:** xp 1600 · class kit unlock (`raise_dead` reframed in all class tooltips as *Borrowed Thread* — integration task) · `wardens_license` (trinket; flavor: "Filament: borrowed. Responsibility: yours. See small script.")
*Shape note: THE lore-guard exemplar — how a mechanically-standard class survives hard canon: rename the fantasy (tender, not necromancer), source the power (Lilith's slack, licensed), and make the class quest teach the leash. Every necromancer-class quest thereafter must include a returning/laying-down beat. This is the pattern for reconciling any future class/system against Lore VI's hard rules.*

---
---

# §7 · ENGINE EXTENSIONS FLAGGED (for the systems pass — NOT assumed by the exemplars above)

All 24 exemplars run on the EXISTING kinds (`talk/kill/reach/choice/use_item` + existing extras). The following are needed for full mass-production and are **flagged, not used silently**:
1. **`repeatable: "daily"` def key** + rotating text pools (`offer_pool`, `arrive_note_pool`) — Part C.
2. **Event scheduler**: world-state windows with auto_trigger quests + ambient overrides (`event_id`, calendar) — Part D.
3. **`collect` objective kind** (item-drop counting) — until then, model as `kill`-with-implied-drop or `reach`+`grant_item`.
4. **World flags API**: `Quests.set_flag()` exists (bool); mass production needs flags readable in `prereq` and dialogue-page selection (e.g., `m1_withheld`, `accord_holds`, counter flags like `pit_hope_n`).
5. **`recent_notes()` / campaign-loss tracker**: the villain touch-points (MSQ-03) and finale option B recap the player's own history — expose the completed-quest `note:` log and a tracked-loss list.
6. **XP curve past 10**: replace ×1.6 beyond L10 (see §0 table) — `xp_system.gd` `MAX_LEVEL`, `xp_for_level` — and extend `KILL_XP` families per WORLD_PLAN creature table.
7. **Negative-gold rewards** (SIDE-02 branch A) — verify `rewards.gold` accepts and clamps sensibly.
8. **New NPCs introduced by these exemplars** (add to `npc_data.gd` cast or zone casts): `oar_keeper` (Rada), `dorica`, `stonepath_pilgrim`, `sabira`, `cazimir_wall`, `archive_listener`, `anara`, `lilith`, `collector`, `vasile_council`, `helva_agent` (Costel), `brassbeck_reeve`, `hammer_widow_olga`, `pit_boss_hrold`, `floor_magistrate`, `waystation_keeper_north`, `wheelwright_drawn`, `brother_ansel_ivy`, `vera_cold_hands`, `clean_coat_seller`, `quartermaster_helva`, `merrowdown_hostess`, `wellwatcher_petru`, `old_marta_vetka`, `threadwarden_ilka`, `scout_widow_pall`, plus rotating pools (vigil walkers, steppe walkers, pit thralls).
9. **New items introduced** (items.gd defs needed): `oar_room_token`, `doricas_flat_loaf`, `sealed_spire_vial`, `quarterstep_boots`, `gift_fragment`, `anaras_flat_knife`, `bookmark_signet`, `helvas_ration_book`, `olgas_first_hammer`, `warden_dye`, `transcub_candle_stub`, `emerics_apple`, `bowl_of_founders_stew`, `oar_regular_token`, `lower_market_marker`, `helvas_cipher_button`, `wellwatchers_chalk`, `martas_salt_pouch`, `vigil_taper`, `vigil_lantern_charm`, `wish_coin`, `martas_prize_slice`, `fair_ribbon`, `quiet_steel_weapon` (per-spec), `petras_weathered_glove`, `borrowed_filament`, `wardens_license`, `granary_key`, `courier_satchel`, `brassbeck_rubbing_facedown`, `hollow_nestling`, `emeric planted stick` (world fixture, not inventory).

# §8 · THE MASS-PRODUCTION CHECKLIST (pin this)

Before any of the remaining ~976 quests ships, it must pass:
- [ ] **Canon line** cites bible part/page or WORLD_PLAN zone — or flags `(design extrapolation)`.
- [ ] **Tone tag** assigned; zone tone-mix quota respected (§0.7).
- [ ] **No clean win**: the `note:` carries residue; at least one cost is real.
- [ ] **Symptom order** never violated; detection colors used correctly (blue/violet/green/orange).
- [ ] **The stone arranges** — any villain beat works through intermediaries and offers REST.
- [ ] **Bodies as signage** — faction dead in faction grammar (12s / pits / standing / buried-missed).
- [ ] **Objectives use existing kinds** or flag §7 extensions explicitly.
- [ ] **Voice check**: "would the Collector say it this dry?" — no purple, no hero-swell; gravedigger-funny allowed.
- [ ] **XP/gold from the §0 band table**; rewards items get `items.gd`-shape defs.
- [ ] **Chain links** (`prereq`/`next`/world-flags) named, and flags are READ somewhere — a flag nothing reads is a lie to the player.
- [ ] **The small warm thing** — every quest can answer the motif audit: *where is the small warm imperfect thing the stone wants gone?* If there's no answer, the quest is set-dressing. Give it one; then it's ammunition.
