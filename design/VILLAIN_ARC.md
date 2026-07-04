# VILLAIN ARC — THE BLOODSTONE AS LICH KING
**Raven Hollow / Draconia canon · mainline villain-presence design, level 1 → 60**

> *"The Bloodstone never forces. It arranges. Every character who touches it does so believing it was their choice, usually their only choice, often their most selfless choice."* — Lore Bible, Part II (`_lore_extract.txt` ~664–668)

The stone **never appears on screen**. It has no model, no boss bar, no monologue. It is present the way the Lich King is present in WotLK — a pressure that keeps finding you — except it never even condescends to a throne-room cameo. Its body is the land (warm ground, coppered wells), its voice is the inscription-stone network, its hands are everyone the player trusts, and its masterstroke is that **every reward the player earns on the mainline was the stone's plan all along**. The player should finish the game able to look back at level 3 and realize they were being read the whole time.

Canon sources used throughout: `c:/Users/vstef/Desktop/rpg/_lore_extract.txt` (Part II cosmology, Part III history, Part IV regions, Part V factions/flashpoints, Part VII/VIII cast, Part IX bestiary, Part X artifacts, Part XI game hooks) and `WORLD_PLAN.md` (zone numbers cited as **Z#**). Engine references: `scripts/quest_defs.gd` (quest schema), `scripts/quests.gd` (flags/signals/beats), `scripts/npc_data.gd`, `scripts/xp_system.gd` (cap 60 post-demo).

---

## 1. The Design Law (pin this)

1. **The stone arranges; it never acts.** No Bloodstone minion may ever attack "on its orders." Monsters are consequences (Part IX: "monsters as consequence"); manipulations are logistics. If a touch-point can be read as a villain *doing* something, rewrite it as a villain *having already arranged* it. (Lore II: "It engineers conditions until touching it feels like salvation," ~654–662.)
2. **The machine has no malice. It has a specification. That's worse.** (Lore I, Pillar III, ~449–450.) The voice is never cruel, never gloating — it is *level, patient, with far too much room in it* (Mira's finale, `quest_defs.gd` q5).
3. **Curiosity is the vector.** Every whisper is bait; every transcription spreads it (Lore II §1, ~571–591). The game rewards players narratively for *refusing to translate*. The whisper-language (`"Vhal-oru sedh. Kaam-tem vhal... sub-vatra, numen-ieh."`) is **never translated anywhere in the game**, including the finale.
4. **Escalation of address.** The stone's attention ladder is the arc's spine — this is the Lich-King "he sees you" feeling done in Bloodstone grammar:
   - **Tier 0 (lv 1–9): You are weather.** Symptoms only. The stone doesn't know you from a boar.
   - **Tier 1 (lv 10–24): You are a useful hand.** Quests whose rewards serve the network; you're being *used*, not watched.
   - **Tier 2 (lv 25–40): You are a *deed*.** Inscriptions address "THE ONE WHO ___" — quoting the player's own logged choices. It knows what you did; it doesn't have your name.
   - **Tier 3 (lv 40–55): You are an *entry*.** Your name appears — first in ledgers, then in stone. The Archive era shows you what "being known" matures into.
   - **Tier 4 (lv 58–60): You are the *only option*.** The full arrangement closes around you personally, exactly as it closed around Lilith six hundred years ago (Lore III, The Burial, ~960–968).
5. **Cadence rule (WoW-Classic tonal mix).** The stone touches the mainline roughly **once per 3–4 levels — never more**. Everything between is honest grind: boar culls, deliveries, cheerful harvest-fair quests, creepy one-offs, faction intrigue. The dread works because the game is mostly *not* dread — WotLK's Lich King appears at zone climaxes only. Cheerful quests are not filler; they are what the stone is trying to erase.
6. **Every touch-point must pass the hindsight test:** on a second playthrough, a player must be able to see the arrangement. No retcons, no "gotcha" without planted evidence (aligned dust, a warm patch, a too-convenient reward).

### The Whisper Register (writer's style guide)
- The stone never uses "I." It uses **the passive voice and the second person**: *"It was always going to be carried. You carried it well."*
- It never lies. It **arranges true statements** so the wrong conclusion feels self-evident (canon: engineered famine "looks like bad years," ~658–659).
- It never threatens. It **offers relief**: rest, warmth, an end to the errand. Its cruelest sentence is *"You may stop now."*
- Escalating physical delivery: hummed notes → aligned dust that spells nothing (yet) → script that rearranges under alchemical light → script that is simply *addressed*.
- Engine: whispers are `cinematic_beat` events (`quests.gd` already emits `listener_whisper`; extend the family: `whisper_2`, `whisper_name`, `whisper_pit`). Direct-address pages use a `{player_name}` token substituted by `dialogue_ui` from the save profile.

### Tracking spine (engine)
The arc runs on primitives that **already exist**:
- `Quests.set_flag()` / `get_flag` — cross-quest memory (e.g. `kept_dagger`, `transcribed_chamber`, `moment_stew`, `saved_mira`).
- Quest `note` strings — the journal is diegetically *the record the stone reads back* (see TP-13).
- `aftermath` dialogue swaps — the world remembering.
- `choice` objectives — every arrangement pivots on one.
- `auto_trigger` + `night_only` — ambushes of atmosphere, not combat.
- New (small): a persisted `moments: Array[String]` list (Moment Journal-lite, Lore XI §6) — quest completions push tokens; the finale consumes one.

---

## 2. THE SIXTEEN TOUCH-POINTS

Level bands assume the WORLD_PLAN spine: Border ring 1–12 → West 12–18 → East 18–24 → South 24–30 → mid-event 30–34 → North 34–40 → Grey Ferry / Continent 2 40–58 → thread-gate → the Pit 58–60. Slow x1.6 XP curve (`xp_system.gd`) keeps each band a real residency, WoW-Classic style.

---

### ACT I — SYMPTOMS (lv 1–12) · *"You are weather."*

#### TP-01 · lv 1–3 · Raven Hollow (Z1) — "The Well Went Copper" *(shipped — canon anchor)*
**What happens:** The existing Phase C chain (`quest_defs.gd` q1): Marta's water tastes of coin, runes on the wellstone, Vasile burns the rubbing *unread*, the graveyard dead dig out **listening, not angry**. Vasile closes on the arc's thesis line: *"The Pause is a bookmark, not an ending. Something put its thumb in the page. One day it means to keep reading."*
**Teaches / foreshadows:** The symptom ladder (ground warms → wells copper → yeast dies → dust aligns → listening → comprehension-death, Lore II ~597–615); that reading is the danger; plants the word **Pause** 57 levels before the player learns they'll be the one holding it. The `coppervein_ring` ("died old and unafraid") is the first Moment-shaped object.
**Canon:** Lore II §1 symptoms (~597–615); Rules of the World #8 (~874–875); WORLD_PLAN "Warm is wrong" ground rule.

#### TP-02 · lv 4–5 · Raven Hollow wilderness (Z1) — "The One Who Listens" *(shipped)*
**What happens:** Mira at the treeline; the escort home; at the gate the whisper arrives **through your teeth, not your ears**, every lantern dims one held breath (`finale_beat: listener_whisper`). She remembers nothing — and hums *"a little tune nobody taught her."*
**Teaches / foreshadows:** The voice exists and is patient. Crucially the player was **not addressed — merely in the room**. Second playthrough hindsight: the sentence Mira relays is the same sentence carved over the Pit door (TP-16). Marta's aftermath line — *"why does my own taproom feel like it's counting us?"* — is literally correct: the census has begun.
**Canon:** entrancement/"listening" (Lore II ~608–610); three-note hum (Torn's detail, Part VIII ~2963–2964); `quest_defs.gd` q5 finale_pages.

#### TP-03 · lv 6–8 · Vetka (Z2) — "Flat Grey Bread" (new)
**What happens:** Cheerful on its face: Old Marta the herb-woman (the Vetka one, Part VIII) asks the player to save the harvest supper — fetch flour from the miller, good water from the far well, a coal from the Bent Oar hearth. Every ingredient is perfect. **The bread still will not rise.** Dorica apologizes to her family for it. Next door, Torn keeps mentioning "the pretty carvings by the well," and a farmer has been "resting" in his field, facing the Chamber, **since Tuesday** — dust in fine parallel lines around his boots. The quest completes with the supper eaten flat and grey, and everyone pretending. There is no fail state and no win state.
**Teaches / foreshadows:** *The famine is engineered and cannot be out-errand-ed.* The neighbor who listens (Torn) shows the vector is fascination, not force. First quest whose objectives all succeed while the outcome fails — the arrangement grammar in miniature.
**Canon:** Dorica's dead yeast / Torn's arriving notes (Part VIII ~2953–2975); "resting since Tuesday" vignette (Part IV ~1421–1423, WORLD_PLAN Z2); the stone farms desperation (Lore III, The Long Want, ~952–955).
**Engine:** plain talk/reach objectives + `aftermath` swaps on Torn/Dorica; no `choice` — the *absence* of agency is the point, once.

#### TP-04 · lv 8–10 · The Chamber Depths (Z5, dungeon) — "The Courier's Letter"
**What happens:** The buried transmission site beneath Vetka. No enemies at first — the dungeon is dread and warming stone (WORLD_PLAN Z5). The Courier lies unmarked, satchel buckled, seal intact, fingernails clean — *he stopped to read the wall* (Part VIII ~2996–2999). Set-piece **choice** (Lore XI Q2): **transcribe** the dense script (fast lore, +XP, a `charcoal_page` item — but seeds a transmission point: Vetka's symptoms visibly worsen, Torn goes fence-still) or **deface it** (slower, alchemy-gated, starves the node; Vetka's second well stays clean). The game never says which was right. On the way out, at the spot where the player rested, there is one **new line of script that was not there before** — under alchemical light it reads as *freshly cut*. It is not translated. It never is.
**Teaches / foreshadows:** Curiosity kills; transcription spreads (Rules #1–2, ~854–858); **mutable world** — the town remembers the choice for fifty levels (flag `transcribed_chamber`). The fresh line is the first hint of Tier-2 attention: something noticed where you slept.
**Canon:** Vetka chamber / comprehension-death (Lore III ~1030–1034; VIII, the Courier); transcribe-vs-defile choice (Lore XI, Q2, ~3976–3980); detection grammar (WORLD_PLAN ground rules).

#### TP-05 · lv 10–12 · Copper Wells → Stonepath (Z4, Z6) — "The Shortening Inscription" + FIRST STRANGER SCENE
**What happens:** Environmental-puzzle zone (read the land: which wells copper, where the grass aligns). At the Stonepath crossroads stands the canon **shortening inscription** — a standing stone with a dead man's handprint, whose marks are *fading, line by line* (WORLD_PLAN Z6). A Listener stands before it, and as the player approaches, speaks — level, patient — **the player's own deed**: *"You burned the page,"* or *"You copied the wall,"* or *"You buried the knife under the hooded stone"* (branching on `transcribed_chamber` / q3 `kept_dagger` flags). Then resumes listening.
That evening at the Bent Oar (Z3): a **grey traveler** pays for stew he does not eat, tells the player exactly one useful true thing — *"Don't read the stones. Not because they'll hurt you. Because they're just legible enough that you'll want to."* — and is gone by morning. The innkeeper has no memory of renting him a room. **He is never named. (See §3, the Stranger thread.)**
**Teaches / foreshadows:** *It watches deeds.* Tier-2 attention arrives early as a single sting, then withdraws for 15 levels (Lich-King pacing: the touch, then the silence). The shortening inscription plants the countdown: marks converging/vanishing = the melody's notes converging (Lore II ~673–681). The stranger plants the Kriggar/Collector ambiguity and the stew-motif (Borek's bowl, Part VIII ~2932–2935).
**Canon:** inscription-stone network as "the true power" of the Border (Part IV ~1395–1399); WORLD_PLAN Z6; the Listeners (Part IX ~3189–3197).
**Engine:** `auto_trigger` zone quest; Listener uses `npc_interact` pages keyed off flags; stranger is a one-night `night_only` NPC spawn with `aftermath`-style vanishing.

---

### ACT II — ARRANGEMENTS (lv 12–40) · *"You are a useful hand," then "You are a deed."*
One manipulation per kingdom arm. Each is Game-of-Thrones intrigue on the surface — leverage, clerical murder, council knives — and a Bloodstone arrangement underneath. **Rule: in every kingdom, the player's *success* advances the network.** The faction plots are the noise; the stone is the signal (Lore IV ~1206–1208).

#### TP-06 · lv 12–16 · The Famine Fields / Western Lowlands (Z10, Z8) — "The Full Granary"
**What happens:** A starving village begs the player to break the bandit-lord blockade choking the grain road. Classic WoW arc: camps, a named bandit chief, a rousing finish. The road opens; carts roll; the quartermaster weeps with relief; genuinely warm turn-in. Then the coda: walking out, the player passes the village granary. **It is full. It was always full.** The villagers aren't eating because eating doesn't help — the hunger is *in* them (the gnawing lack no meal fixes, Lore II ~656–657). And down the road the player just cleared, a thin line of villagers is already walking east. A scout-widow (Pall, Part VIII) names them: **the hungering**.
**Teaches / foreshadows:** The stone engineers hunger *where there is bread*, so touching it "feels like the only option" (Part IV ~1376–1378 — the mandate's core citation). And the reward was the plan: **the player opened the pilgrim road east.** The blockade was the last thing slowing the hungering down.
**Canon:** famine-village/full-granary vignette (Part IV ~1376–1378; WORLD_PLAN Z8); the hungering — "the scariest enemy in the West is your neighbor, walking east" (Part IV ~1372–1374).
**Engine:** standard kill/reach chain; coda is a `finale_pages` beat + world-state swap (hungering NPC walkers spawn on the cleared road henceforth).

#### TP-07 · lv 16–18 · Angel Wings (Z7) — "The Lead Box" (GoT intrigue #1: leverage)
**What happens:** Lore XI QS-3, staged as court intrigue. Fielderine's spymaster quietly hires the player to verify the queen's lead-boxed Bloodstone fragment is inert. It isn't: it hums **a single note**, and the young clerk guarding it has been skipping meals *"to feel clearer."* Three-way `choice`: remove the clerk (saves him; the court learns the fragment is live), leave him as a canary (exploit a person as an instrument), or counsel destruction (Fielderine refuses — it is her only leverage in the cold war). Whichever way: **word leaks** — the player's report *is* the leak, laundered through Blestem's listening walls — and by the next act, all three predator-factions know the weakest crown holds a fragment (Flashpoint 2, Part V ~2012–2017).
**Teaches / foreshadows:** GoT mechanics: information is a weapon that fires the moment it exists. Fielderine is the resistance-thesis made flesh — the one ruler who feels the "only option" and answers *no* every night (~2809–2812) — the player meets the counter-example **before** the stone starts working on them personally. The single note foreshadows convergence.
**Canon:** QS-3 (Lore XI ~4016–4023); Fielderine profile (Part VII ~2768–2812); Flashpoint "The Lead Box" (Part V ~2012–2017).

#### TP-08 · lv 18–24 · Blestem / Whisper Passes (Z17, Z21) — "Rows of Twelve" + "The Rubbing Trade" (GoT intrigue #2: the clerical murder)
**What happens:** Two-stage residency in the maze-city.
*(a)* **QS-1 verbatim:** a Strigoi clerk-executioner's ledger of twelve names holds one clerical error — an informant who already paid. Expose / forge / do nothing. *The paperwork is the murder weapon* (Lore XI ~4000–4008). Cazimir: *"I do not collect assumptions. I collect architecture."*
*(b)* **The arrangement:** Cazimir, impressed, contracts the player for the Lower Market's richest bounty — **charcoal rubbings of the wild inscription stones** along the Whisper Passes, "for the archive of leverage. Face-down, of course. I am not a fool." Pay is superb (this is the level band's best gold — temptation must be real). Every rubbing delivered seeds Blestem: listeners multiply in the Lower Market; by turn-in, twelve boot-prints face a dead-end wall (the Z17 vignette). Refusing or forging blanks earns safety — and a debt Cazimir *will* collect (a favor-flag that resurfaces at TP-11).
**Teaches / foreshadows:** *Transcription is transmission* — the QS/Q2 lesson now industrialized: a whole faction's intelligence apparatus doing the stone's copying for it. Cazimir covets the stone as the ultimate asset and cannot see that **"the Bloodstone does not get acquired. It acquires"** (Part V ~1598–1601). The player watches the smartest man in the East be a delivery mechanism — and is invited to be one too, for coin.
**Canon:** QS-1 (~4000–4008); Cazimir's hidden agenda (~1597–1601, Part VII ~2557–2596); spread-by-transcription (Rules #2 ~856–858); Z17 vignette (WORLD_PLAN).
**Engine:** stage (b) is a repeatable-feeling collection quest with a hidden counter; each turn-in fires an `aftermath` swap on a Lower-Market NPC (one more voice goes still). The player can *see* the cost accrue if they look. Flag: `fed_cazimir_rubbings` (int).

#### TP-09 · lv 24–30 · Sangeroasa / The Gift / Ashvents (Z22–24) — "Fresh Red" + "Warm Was Always Wrong"
**What happens:** The forge-city residency. **QS-2:** the Gift-farmer needs "fresh red" — corpses — for failing soil; broker with the Debt Pit, refuse (famine — *you just helped the stone*), or expose the cycle through Anara (politically explosive) (Lore XI ~4009–4015). Alongside: the player finally gets a **warm, comfortable zone** — the Ashvents, where vent-heat means no frost, warm rivers, easy camping. Veterans of Acts I will be *physically uncomfortable* camping there, and they are right to be: **the heat hides the signal** (WORLD_PLAN Z24, canon problem zone). Mainline climax: the player is hired to disarm the whisper out of **Valrom's bloody dagger** — the compulsion blade that feels like clarity (Part X ~3715–3740) — the quest that later unlocks Boss-3 phase 3 mercy. Succeed or fail, the player has now *held* a signal-object and felt what the stone's voice feels like **from the inside: like finally knowing what to do.**
**Teaches / foreshadows:** Compulsion is indistinguishable from conviction — the exact mechanism the Pit will aim at the player at TP-15/16. There is no ethical harvest; every meal in the South is a body. Also seeds Valrom-as-case-study: the stone doesn't break a strong will, it *aims* one (Part VII ~2678–2679).
**Canon:** QS-2 (~4009–4015); the dagger (Part X ~3715–3740); Ashvents heat-masking (WORLD_PLAN Z24); slag-walkers — the dead still working (Z24).

#### TP-10 · lv 30–34 · Stonepath / all four arms (Z6 world event) — **"THE QUIETING" — the false victory (mandated beat)**
**What happens:** The arc's midpoint and its cruelest arrangement. The Digging Creature — the four-clawed herald that widens transmission points (Part IX ~3169–3184) — is finally cornered and killed at the Stonepath crossroads (proper boss, Lore XI Boss-1 mechanics). In the afterglow, all four factions — in a deliberate, hopeful echo of Great-War cooperation (Lore III ~976–978) — jointly sanction a purge: the player leads teams to **topple and shatter the wild inscription stones** along every road they've opened since level 1. It works. For one in-game week: wells run clean, bread rises in Vetka, the dust lies random, Torn asks what he's been doing all year. **This is the game's single most cheerful stretch** — a festival quest, thank-you letters, Marta's supper finally rising. Then the alchemists re-scan: the network didn't die. **It went quiet because it finished.** Shattered stones read *shifting orange at every break-face* — each shard a seed — and the shards traveled out as rubble, ballast, and hearthstones **along the trade roads the player spent thirty levels clearing**. The victory tour was the distribution route. The final beat: at the shortening inscription, the last marks fade entirely — and the Bent Oar's two-note hum drops to **very nearly one**.
**Teaches / foreshadows:** The mandated *false victory that spreads the network*. Hindsight test passes: TP-05 warned the marks were *shortening* (converging), TP-08 taught shards-as-seeds, TP-06 taught the player their opened roads get used. The world darkens measurably post-Quieting (spawn tables shift: more listeners, thread-touched dead range further south) — the WotLK "the war is going badly" turn. And the cooperation-echo curdles: each faction now blames the others for proposing it. Was the purge proposed by a council-clerk — **or the stone speaking through one?** (Open Mystery, Lore ~363, ~1156–1158 — never answered.)
**Canon:** Digging Creature (Part IX ~3169–3184; Lore XI Boss-1 ~4106–4120); executing/destroying script accelerates convergence (Rules #7 ~870–873); "The old songs had three notes. Ours have two." (~683–684); Great-War unity as the ghost the present can't recover (~991–993).
**Engine:** world-event quest chain + a timed world-state (`quieting_week`) with swapped ambient barks and clean-water visuals, then the reversal via `cinematic_beat("whisper_2")` and permanent spawn-table escalation.

#### TP-11 · lv 34–40 · Black Night / Threadlands / Gravemark (Z12–15) — "Radovan's Reading" (GoT intrigue #3: the betrayal) + FIRST SECOND-PERSON STONE
**What happens:** The northern residency is pure small-council theater over Warcraft horror (Part VIII design note ~2904–2906). Vasile — loud, warm-nostalgic, harmless — recruits the player for containment errands he doesn't understand; the *actual* recruitment is **Radovan**, who speaks last and least. Across the arc (including **QS-6**, the Iele shell flickering into will — *you, of all people, know what it's like to wake up wanting*), Radovan reveals he has independently derived the counter — **"the dead can transmit"** — and his conclusion: Lilith, six hundred years of rage, is *precisely the wrong dead hand to trust with it*. He offers the player the North's best intelligence, at a price paid later (Part VIII ~2882–2884), to help him control the transmission himself — and, if necessary, see the Buried Queen stays buried (Flashpoint 3, Part V ~2018–2023). Accepting or refusing sets `radovan_pact` — it decides who is standing at the Pit rim in TP-16.
Then, in **Gravemark Tundra**, the tier break: a Great-War kerb-stone's carvings, under blue light, rearrange into legible second person:
> **TO THE ONE WHO BURIED THE KNIFE.** *(or: WHO KEPT IT / WHO COPIED THE WALL / WHO OPENED THE ROADS — flag-dependent)*
> **YOU HAVE BEEN CARRYING WELL. YOU MAY STOP NOW.**
No name. It doesn't have the name yet. The screen holds; nothing attacks; the wind continues.
**Teaches / foreshadows:** Tier-2 in full: **it addresses you by your deeds** — assembled from the player's own quest history (the flags are literally read). The GoT machinery peaks: the player now holds leverage (Radovan's secret) that both Lilith's faction and Cazimir's ledger-debt (TP-8) want — three creditors, one player. Radovan's parallel key also protects the endgame twist: the transmit/receive truth is *in play politically* long before Constantine's recurrence hands it over morally (canon reconciliation note ~202–208).
**Canon:** QS-6 (~4040–4046); Radovan profile (~2877–2886); Flashpoint 3 (~2018–2023); Threadlands abandoned-camp vignette (WORLD_PLAN Z13 — footprints in, none out); "listening" as thread-adjacent (Part VI ~2090–2099).

---

### ACT III — THE ENTRY (lv 40–58) · *"You are an entry."*
The Grey Ferry from Riverfork (Z11) to the Grey Piers (Z30) is the era-crossing voyage (WORLD_PLAN travel graph): the player sails into **the drowned future** — what the whole map becomes if the Pause fails. Act III is the villain arc's proof-of-consequence: the stone barely whispers here, because *here it barely needs to*. The Archive matured into the debt-system **is** the Underlanguage wearing a clerk's face (Lore II §5 ~791–849).

#### TP-12 · lv 40–45 · Grey Piers / Greyhollow (Z27, Z30) — "The Warm Tablet" — **THE NAME, IN WRITING**
**What happens:** First hour on Continent 2: a cracked debt-tablet washes up at the player's feet, **warm to the touch** (the Z27 canon vignette). Marrow Pell — the dead broker who taps his own tablet to check he's still legally allowed to exist (Part VIII ~3012–3014) — reads it for a fee, goes very still, and slides it back: it is an **account header**. The name on it is **{player_name}**. Opened — not settled, not collected. *Opened.* Dated in an era the player should never have lived to see. Pell: *"Congratulations. You've been noticed by the only thing in this city with a longer memory than me."* His own QS-7 dilemma follows (lose his file → his debt lands on a warm family; mercy is a transfer, not a cancellation, ~4047–4052).
**Teaches / foreshadows:** Tier-3: **the first direct address by name — and it arrives as paperwork**, which is scarier than any voice. The debt-system vocabulary clicks into place: "collected/closed" = comprehension-death with a receipt (Lore II ~818–821). The player is now, formally, an unclosed entry — exactly what the stone wants to *correct*.
**Canon:** warm-tablet vignette (WORLD_PLAN Z27); debt-tablets as matured Bloodstone-records (~813–817, Part X ~3640–3658); Marrow Pell (Part VIII ~3001–3014).

#### TP-13 · lv 45–50 · The Archive (Z35) — "The Mis-Captioned Stick" + "Already Collected" — **THE KEY**
**What happens:** The library-city that Black Night calcified into. Three chambers:
*(a)* In a locked drawer: **Old Marta's walking stick**, enshrined, lit, labeled — *and the caption is wrong* (Part VIII ~3026–3030; Part X ~3774+). If the player carries any Vetka warmth-flags (saved Torn, ate the flat bread, the `coppervein_ring`), they can correct the caption; the Archivist — a retired Morven — weeps without knowing why. Log `moment_stick`.
*(b)* **QS-8:** the Blind Seer — Constantine's recurrence, Eyeless Sight — turns toward the player mid-street and screams: **"Already open — why is your file already OPEN?!"** — the thousand-year alarm going off on the *player* this time (adapted from ~4054–4061; the Deadheart-scream canon at ~2643–2644). Protect him, silence him, or spend him: the QS-8 triangle.
*(c)* If the Seer survives in any form, he hands over the arc's hinge, the six most important words in the saga: **"Transmit, don't receive."** A living touch RECEIVES — feeds the prophecy, authorizes the broadcast. A dead touch can TRANSMIT — push the imperfect present into the record and overwrite the perfect past (Lore II §4 ~751–766; Rules #11–12). The player also sees the **thread-gate**: the Archive stands where Black Night stood; same place, a thousand years apart (WORLD_PLAN travel system).
**Teaches / foreshadows:** The full counter-mechanic, delivered ~10 levels before it's needed so it can rot in the player's pocket (they now know the stone can only be beaten by a *dead* hand — and they are alive). The stick scene rehearses the finale's real mechanic: **a small warm specific thing, correctly remembered, is ammunition** (~3113–3118, the motif audit).
**Canon:** as cited inline; Archive-as-calcified-cure (Lore III ~1110–1132).

#### TP-14 · lv 50–55 · Orange Fog / Finalized Fields / Coldharbor Deep (Z37–39) — "The Stone Reads Your Journal" — **FULL DIRECT ADDRESS**
**What happens:** The signal wastes. Here the fog itself reads shifting orange, and across three dungeons the inscriptions speak to **{player_name} directly — by quoting the player's own quest journal back at them**, verbatim. The engine gag is load-bearing: the `note` strings of completed quests are the save-file's memory, and the stone *is* a record — so the walls display the player's actual notes:
> **{PLAYER_NAME}. "YOU KEPT THE DAGGER. IT IS ALWAYS FRESHLY BLOODY."**
> **YOU HAVE BEEN KEEPING A RECORD. SO HAVE WE. YOURS IS SMALLER.**
> **BRING IT.**
Each dungeon ends not with a boss but with an offer written in stone: rest, an end to the walking, the road north. In the Finalized Fields, the grave-rows include one **open, empty, freshly cut plot** with a blank headstone sized for the player. Nothing attacks. (Bodies as signage — WORLD_PLAN ground rule — aimed at one person.)
**The Stranger's last visit:** in Coldharbor Deep the grey traveler from TP-05 is there ahead of the player, unaged after fifty levels, an **orange stone glowing at his sternum**. He says: *"It'll offer you the pit like it's your idea. It did the same to a queen once, and to me it didn't even have to — I was already dead. Whatever you do down there — don't do it alive."* He does not explain. He is gone when the player looks back. (§3 resolves what the game will and won't confirm.)
**Teaches / foreshadows:** Tier-3 complete: named, quoted, expected. The empty grave is the arrangement showing its hand — the stone has begun building the player's "only option." The Stranger's warning restates the key as *survival advice*, so the finale's suicide-mechanic lands as tragic logic, not puzzle-trivia.
**Canon:** Orange Fog / Deadheart-signal wastes and comprehension-dead (WORLD_PLAN Z39); the Deadheart as index-worn-as-organ (~826–833); "the most dangerous thing on the map is a document that makes perfect sense" (~509–510).
**Engine:** dialogue pages assembled at runtime from `Quests.to_save_dict()` notes + `{player_name}` token; `cinematic_beat("whisper_name")`.

#### TP-15 · lv 55–58 · The Last Hearth (Z40) → the thread-gate — "The Only Option"
**What happens:** The one warm refuge — Maren's orphanage echo, chalk handprints protected and catalogued, no hostiles, *the point* (WORLD_PLAN Z40). The player is given one long, deliberately gentle questing stretch: help with the harvest-fair of the end of the world. Then the stone plays its last card, and it is not an attack: **someone the player saved** — priority order by flags: Mira (if `saved_mira`), the corrected Archivist, the freed Iele shell, the Seer — goes quiet at supper, stands, and **walks north through the thread-gate**, toward the Pit, exactly as the hungering walked east at TP-06. Every NPC begs the player to go after them. Going after them means descending to the stone. The player will do it, and it will feel like their own idea — *usually their only choice, often their most selfless choice* (Lore II ~664–668).
**Teaches / foreshadows:** The final arrangement, aimed at the player, built from **the player's own kept kindnesses** — the stone weaponizes the Moment Journal. This is Lilith's burial re-staged with the player in the pit-ward role: desperation engineered, the door opened, the choice pre-selected. Passing the thread-gate steps the player from the Archive into Black Night — same ground, a thousand years apart — and the two eras of the game close into one place.
**Canon:** the burial arrangement (Lore III ~960–968); Z40/Last Hearth; thread-gate (WORLD_PLAN travel system); "the stone's central lever — engineered desperation" (Part VII ~2423–2424).
**Engine:** `auto_trigger` finale; the walker is an escort *inverted* (the player follows, `night_only`, the NPC never stops); `set_flag("pit_reason", npc_id)`.

---

### ACT IV — THE PIT (lv 58–60) · *"You are the only option."*

#### TP-16 · lv 58–60 · Black Night → The Grave & Bloodstone Pit (Z12, Z16) — **"TRANSMIT, DON'T RECEIVE" — the multi-stage finale**
The endgame dungeon descends through four stages. No stage may offer a clean win (Lore XI preamble ~3893–3896).

**Stage 1 — The Still Market (Z12).** Descent through Black Night: unnaturally clear air, no fog for the first time in the whole game — clarity as the final wrongness. Iele shells stand in rows of twelve; thread-lit streets; the walked-ahead NPC always one street further. Combat is sparse and wrong: shells are harmless until directed, and something *is* directing (the Pit's arrangements, WORLD_PLAN Z16). Council theater collapses in real time — Vasile pleading procedure, Radovan (per `radovan_pact`) either clearing the player's way or racing them down.

**Stage 2 — The Grave (Lilith).** The tomb floor is her grave; the cedar throne sits in the cold (Part X ~3742–3771). Boss-4 canon structure: her contempt-gauge *fills when attacked* — fighting her feeds the Veil; the real verbs are dialogue and evidence. The player who brings warmth-flags can move her from rage toward grief at the throne — and must then face the canon trap: **her peace thins the Veil; her fury is the world's lock** (~707–739). Her line at the rim, canon-verbatim: *"47 years… they gave me a pit."* Resolve as CHOICE, not kill: sustain her rage (she bars the Entity's door and *cannot* help below) or grant her the emptiness (she rests; the rear-plane membrane visibly thins for the rest of the run — and stays thinned in the epilogue). Either way she tells the player the one thing they need: *"It will feel like your idea. It felt like mine."*

**Stage 3 — The Descent (comprehension gauntlet).** No enemies. The Pit engineers feeling: famine-memory, the taste of copper, the player's dead NPCs' voices used as bait — every voice offering rest (Lore XI, Bloodstone Pit set-piece ~4097–4101). The three-note melody is audible and it is **very nearly one tone**. Standing still too long, or lingering on legible script, fills a *Listening* meter — comprehension damage; the player survives by moving, by *not resolving the meaning* (Rules #3). Over the last door, the sentence from level 5, unchanged, untranslated: *"Vhal-oru sedh. Kaam-tem vhal… sub-vatra, numen-ieh."* Players who reach here having refused translation all game are rewarded with exactly nothing — which is the reward (Lore II design note ~589–591).

**Stage 4 — The Touch (the climactic CHOICE, transmit vs receive).** The Thirsty Stone, over Lilith's grave-floor. The walked-ahead NPC stands before it, hand rising. The final input is a choice wheel with the game's whole design inside it:

- **RECEIVE — touch it alive.** Pull the NPC back and take their place with a beating heart. The prophecy triggers; the living touch authorizes the broadcast (~753–757). The Still Age epilogue plays: cold blue light, aligned dust, a silence that reads as threat (~942–944). This is a real, selectable ending — the villain's win state, chosen the way the stone always wins: *by a hand that believed it was saving someone.*
- **REFUSE — walk away.** Carry the NPC out (they do not wake). The notes keep converging; Radovan's or Cazimir's hands move in the epilogue crawl. The Pause frays. An ending that is honestly a deferral — the world's, and the sequel's.
- **TRANSMIT — die first.** The counter, earned at TP-13, warned at TP-14: *the mechanism needs a heartbeat to stop* — so give it none. The player must **deliberately die in the Pit** (the environment obliges; the arrangements have been trying to kill the player softly for three levels) — and then, as the player-corpse, in the game's last playable minute, **walk to the stone and push one kept Moment into it**: Marta's stick correctly captioned, the taste of a stew a dead man couldn't eat, Mira's tuneless hum, the coppervein ring of a woman who died old and unafraid — one entry from the `moments` list, *spent forever* (what you feed, you lose — ~4222–4225). The specific, imperfect, warm, wrong little detail overwrites one line of the perfect record. The notes hold apart. **The Pause is renewed — not won.** Players who kept no Moments warm — who spent every person as an asset — *cannot select this option*, and the Stranger's dead hand does it instead, at a cost shown and not explained.

**Closing beat:** back at the surface, Gravekeeper Vasile's level-2 line returns as the last line of the game: *"A bookmark, not an ending. Something put its thumb in the page."* This time the player knows whose thumb.

**Teaches:** the thesis, played: *human memory is broken and warm; the stone's is complete and cold; the broken warm thing is better* (~458–461, ~785–789). The villain is never fought, never seen, never destroyed — it is *held*, at the price of one loved specific thing, which is the only price the game ever charges that matters.
**Canon:** transmit/receive exactness (Lore II §4 ~751–766; Rules #11–12); dead-only interface as a designed verb (~468–472, Lore XI dungeon rule 5 ~4081–4084); Pit set-piece (~4097–4101); Lilith boss grammar (~4157–4178); Boss-5 "submit one small imperfect memory as the overwrite" (~4188–4204); "The Pause is a bookmark" (`quest_defs.gd` q1 turn-in).
**Engine:** stage 4 needs one new primitive — a `dead_walk` player state (input-locked to walk + interact, greyscale shader, no HUD) triggered on death inside the Pit arena with `pit_final` flag set; the Moment select reuses the bag UI over the `moments` list; endings dispatch on a 3-way `choice` + flags.

---

## 3. THE STRANGER — the Kriggar / Collector ambiguity (running thread)

**Appearances:** TP-05 (Bent Oar, buys stew he doesn't eat) · TP-10 (glimpsed at the Quieting festival, not celebrating, watching the roads) · TP-12 (Pell calls him "the other discrepancy" and refuses to elaborate) · TP-14 (Coldharbor warning, orange stone at his sternum) · TP-16 stage 4 (the fallback dead hand).

**The rule: the game never says his name.** The evidence is all real and all canon-consistent — grey-blue pallor, doesn't eat, unaged across fifty levels and an era-crossing, the Deadheart glow, "solutions, not weapons" phrasing, the stew callback (Borek's bowl, Part VIII ~2932–2935) — and it is never confirmed, because the canon keeps a colder question open underneath the obvious one: **the Deadheart is a piece of the stone's index worn as an organ (~826–833). When the Stranger helps you, is that Kriggar helping — or the stone's filing-system steering its one sanctioned interface exactly where the arrangement needs a dead hand to be?** The Open-Mysteries file asks the same shape of question about the Accord's bureaucrats (~363, ~1156–1158): *was it a man, or the stone speaking through one?*

Both readings must survive the whole game:
- **Kriggar the jailer-ally:** the sole sanctioned interface (Accord canon ~1068–1070), quietly shepherding the one mortal stubborn enough to matter, refusing to spend them the way he was spent.
- **The stone's finger:** every Stranger intervention *also* moved the player one step down the road to the Pit. His TP-14 warning is what makes the player able to complete the touch at all. If the stone needed a new pause — a fresher dead hand, a renewed lease — the Stranger delivered one.

Dialogue discipline: he speaks only in the noir register (dry, tired, gravedigger-funny, ~511–512); he never answers a direct question about himself; NPCs who might know him (Pell, the Seer, Lilith) react to him and refuse to name him. Lilith, stage 2, gets the one line that feeds both readings: *"I know that stone he wears. I cannot tell anymore which of them is carrying the other."*

---

## 4. Cadence & Tone Map (WoW-Classic mix, at a glance)

| Band | Zones | Touch-points | Between them (the other ~85% of quests) |
|---|---|---|---|
| 1–12 | Z1–Z6 | TP-01…05 | boars, deliveries, harvest fair, fountain coins — warm village life *worth erasing* |
| 12–18 | Z7–Z11 | TP-06, 07 | bandit arcs, river trade, orphanage (Maren) cheer, smuggler comedy |
| 18–24 | Z17–Z21 | TP-08 | heists, lichen trade, Transcub ghost-stories (creepy), lift-boy vignettes |
| 24–30 | Z22–Z26 | TP-09 | forge deliveries, pit-caller Drego, Soot-Boy Tav's tin (small kindnesses) |
| 30–34 | world | **TP-10** | the festival — the game's brightest week, on purpose |
| 34–40 | Z12–Z16 | TP-11 | council farce (Vasile), Ilka's named shells, tundra survival grind |
| 40–58 | Z27–Z40 | TP-12…15 | canal noir cases, ledger comedy-of-horrors, Last Hearth warmth |
| 58–60 | Z12+Z16 | **TP-16** | none — the Pit is uninterrupted |

Sixteen touch-points ÷ 60 levels ≈ one per 3.75 levels: the villain is a *tide*, not a roommate. Heavy / creepy / cheerful quests alternate between touch-points; every cheerful quest is a deposit the finale can withdraw (`moments` list).

## 5. Flag & Systems Appendix (engine mapping)

| Flag / system | Set at | Read at |
|---|---|---|
| `transcribed_chamber` | TP-04 choice | TP-05 Listener, TP-11 stone, Vetka world-state |
| `kept_dagger` (q3 shipped) | Phase C q3 | TP-05, TP-11, TP-14 journal-quote pool |
| `fed_cazimir_rubbings` (int) | TP-08 | Blestem world-state, TP-11 leverage scene |
| `leadbox_choice` | TP-07 | Act II faction pressure barks, epilogue |
| `radovan_pact` | TP-11 | TP-16 stage 1 staging |
| `saved_mira` (q5 shipped) + per-NPC saves | Acts I–III | TP-15 walker priority |
| `moments: Array` (`moment_stew`, `moment_stick`, `moment_ring`, `moment_hum`, …) | warmth beats game-wide | **TP-16 stage 4 — gate + ammunition** |
| `cinematic_beat` family: `listener_whisper` (shipped), `whisper_2`, `whisper_name`, `whisper_pit` | TP-02/10/14/16 | screen-dim + page delivery |
| `{player_name}` token; journal-note quote pool from `Quests.to_save_dict()` | — | TP-12/14/16 direct address |
| `dead_walk` player state (new) | TP-16 stage 4 | the transmit ending |

**Non-negotiables checklist** (from canon, for every future quest touching this arc): the stone never forces, only arranges · no translation ever shown · warm is wrong · curiosity is punished and the punishment is foreshadowed · no clean wins, including the last one · the dead are read-only · living touch receives, dead touch transmits · the Pause is a bookmark.
