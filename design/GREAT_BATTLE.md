# THE GREAT BATTLE — "THE SECOND COOPERATION"
**Raven Hollow / Draconia canon · the endgame army set-piece · level 58 · between TP-15 and TP-16**

> *The Cooperation. Vampires (Strigoi), Werewolves (Varcolaci), the Undead (Iele), and Humans set aside the cold war and move together against the surfacing threat. Their unity is real, brief, and never repeated.* — Lore III, The Great War (~976–978)
>
> It is repeated once. This is that night. The last time the four banners marched together, it ended *"with me in a pit and the world on fire"* (~982). Everyone on this field knows the story. That is why nobody says the old name out loud — the soldiers just call it **the Second Cooperation**, with the grim tone reserved for a thing that killed everyone who tried it first.

**Owner mandate:** a massive army set-piece where the player fights beside the faction their story followed — aim: one of the greatest battles in game history (MANDATES §Narrative & Cinematics).

Canon sources: `_lore_extract.txt` (Great War ~971–993 · Thread founding ~985–988, ~2081–2083 · faction militaries ~1579–1584, ~1640–1645, ~1697–1701, ~1752–1757 · Valrom/Gorescream ~1630–1675, ~2650–2663, ~3690–3713 · the hungering ~1372–1378 · Veil/rage ~1003–1009 · melody convergence ~675–688). Design deps: `VILLAIN_ARC.md` (TP-14/15/16, flag appendix), `QUEST_ARCHITECTURE.md` (villain grammar §0, rep tracks §2b, schema v2 §6), `WORLD_PLAN.md` (Z12/Z15/Z16, perf pattern note), `NPC_CAST.md` (roster ids). Engine: `scripts/quests.gd`, `enemy.gd`, `zone_builder.gd`, `combat.gd`.

---

## 1. WHAT THE BATTLE IS (design law first)

### 1.1 Where it sits
Level 58. The player has just followed the walked-ahead NPC through the thread-gate (TP-15) — from the Archive era back into Black Night, Year 0. They emerge onto **Gravemark Tundra at night — and the tundra is full of armies.** The Great Battle is the bridge between TP-15 (the lure) and TP-16 (the Pit): its final beat is the player stepping through the Grave's outer door into Stage 1 of the final raid. The battle is *how the player gets to the door*, staged as the biggest thing the game ever puts on screen.

### 1.2 Why four armies are here (the stone's grammar holds)
**The stone arranges; it never acts** (VILLAIN_ARC law 1). There is no dark army with a general. What the armies march against is **the Convergence**: after the Quieting (TP-10) seeded the trade roads and the melody fell to very nearly one tone, *everyone the stone has been farming for sixty levels starts walking to the Pit at once* — the hungering columns from the West (down the very roads the player opened at TP-06), entranced pilgrims from the Steppe, listeners abandoning their posts, and — worst — the Gravemark mass graves beginning to slip Lilith's Thread while her attention is spent at the Veil (~2081–2083: the Thread's job is to *hold down what the Great War raised and did not re-bury*). A living touch completes the broadcast (~751–757). Tonight there are ten thousand candidate hands converging on the stone, and the four powers have — for the second time in history — agreed to keep every one of them off it.

Each faction marches for its own reason, and every reason is individually explicable. That is the tell:

| Faction | Stated reason | Real reason (GoT layer) |
|---|---|---|
| **Angel Wings** (Fielderine) | Accord point 5: the countdown is everyone's | Fielderine marches to keep *every* hand off the stone — including her allies'. She is the only commander on the field who is here to make sure nobody wins (~1773–1777). |
| **Sangeroasa** (Valrom) | Cut the columns, end the threat "with one blow" | The dagger. Valrom's unification-compulsion reads tonight as destiny: deliver the strongest army on the continent to the stone's front door (~1660–1663). He thinks he's the hammer. He's the antenna. |
| **Blestem** (Cazimir) | Accord observers; intelligence support | Cazimir does not march; he *attends*. Sabira and a column of blades are positioned to acquire the stone in the chaos — the ultimate asset, collected while everyone else is busy (~1598–1601). |
| **Black Night** (Council / Lilith) | Home ground; hold the walls, hold the Thread | The Council is split live on the field: Vasile wants procedure and containment; Radovan wants a *controlled transmission* on his terms (per `radovan_pact`). Lilith is below, holding two doors at once. |

**The hindsight test (VILLAIN_ARC law 6):** every one of those four motives was planted between levels 12 and 55 — the famine, the dagger, the rubbings, the failing Thread. Four true reasons, one date, one destination. The epilogue shows (never says) what that means: see §8.

### 1.3 The one rule that keeps the battle canon
**No enemy on this field is a minion.** The Convergence does not charge, does not siege, has no war-cry. It *walks*. The hungering never attack unless physically blocked — and the armies are a wall, so they are blocked, and it is horrible. The thread-slipped dead fight because fighting is the last order the Great War ever gave them. The horror of the Great Battle is that the enemy is a crowd of victims moving like weather, and the heroism on the field is real anyway. Monsters are consequences (Part IX); tonight the consequence is six hundred years long and walking north.

### 1.4 No clean win
The field can be held, the breach can be made, every named NPC can survive — and the battle is still not a victory, because the door opens *from the inside* (§5, Phase 4) and the player still has to go down. The armies believe they are the wall. They are the escort. Nothing in the battle text ever states this; the aligned dust in the epilogue states it silently (§8).

---

## 2. WHICH BANNER THE PLAYER MARCHES UNDER

Computed once, at the moment the player exits the thread-gate; persisted as `battle_line` (never recomputed — the battle remembers your story, not your last-minute grinding).

```
battle_line = argmax over {angel_wings, council_of_six, blestem, sangeroasa} of rep tier
tie-breakers, in order:
  1. radovan_pact accepted            -> council_of_six
  2. dagger_disarmed (TP-09 chain)    -> sangeroasa
  3. fed_cazimir_rubbings >= 6        -> blestem
  4. leadbox_choice == saved_clerk    -> angel_wings
  5. absolute fallback                -> angel_wings  (the Humans take anyone; that is their whole thing)
```

**The Bent Oar banner (all variants).** Regardless of `battle_line`, a small levy of Border Hearths militia finds the player at the muster — faces from levels 1–12, carrying a tavern sign on a spear for a standard. Gren, the Bent Oar keeper's boys, a couple of Vetka farmers with boar-spears. They did not march for a kingdom; they marched because the player did. They embed with whatever line the player joins. This is the battle's warm center and the finale's cruelest lever: the `moments` list walks beside you all night.

**Named-NPC roster (assembled from save flags).** The battle pulls the player's story into the line. Priority-ordered per variant (§6), drawn from: `saved_mira`-family flags, TP-07 clerk, TP-08 refusals, TP-09 Anara chain, TP-11 Ilka's named shells, plus faction principals. Every rostered NPC gets: a muster greeting referencing the shared quest, a battlefield position, one `protect` window, wounded/alive epilogue barks.

---

## 3. THE BATTLEFIELD (map + instance plan)

**Instance, not the world zone.** `gravemark_field` — a dedicated battle map (Z15 tileset + Black Night approach kit), so Gravemark Tundra proper stays intact for open-world play. Precedent: Godot map registry already supports parallel map defs (`map_registry.gd`); the battle is entered via the thread-gate exit and left only by the Grave door (or by walking back through the gate pre-Phase 2, which pauses the chain — no soft-locks).

**Layout — three lanes and a spine** (total ~384×256 tiles; built from hand-authored anchors per WORLD_PLAN hand-crafted law):

```
            BLACK NIGHT WALLS (north edge, blue-black, no fog)
                 [THE GRAVE'S OUTER DOOR — Phase 4/5]
   ================== THE RIM (Phase 3) ==================
   LANE W          |        LANE C (spine)      |   LANE E
   kerb-stone      |   the old Great-War        |  frozen river
   rows, mass      |   muster-field (canon      |  + pilgrim road
   graves          |   fragment, ~991–993)      |  (the columns come up this)
   [Hold W]        |   [Hold C: the Cairn]      |  [Hold E]
   ================ FIRST CONTACT LINE (Phase 1 end) =======
                 THE MUSTER (south edge, four camps + thread-gate)
```

- **Lane assignment by variant:** Angel Wings = Lane W (shield-wall over the graves) · Sangeroasa = Lane C (the wedge, straight up the spine) · Council = Lane E (the shell legion meeting the columns) · Blestem = roaming/Lane E flank (small, fast, never a line). The player fights their faction's lane; the other lanes run on LaneSim (§7) and are *visible* fighting in the distance — always. The battle must never look like it waits for the player.
- **Landmarks (40-second rule applies even here):** the Great-War cairn (Hold C) · a war-axe rusted into red soil (canon fragment ~992) · the shortening inscription's twin, marks long gone · a burned waystation · Maren's stretcher-tents (W rear) · Drego's call-post (C rear) · the observers' black coach (E rear, Blestem) · kerb-stones that light blue → violet → green → orange as the night goes on (detection grammar as level design, QUEST_ARCH act III).

---

## 4. PHASES (the buildable spine)

Runtime target: 75–90 minutes, uninterrupted but checkpointed at every phase boundary (save-safe: `battle_phase` int flag; reload resumes at phase start with LaneSim state restored).

### PHASE 0 — THE MUSTER (staging hub, ~15 min, no combat)
The player exits the thread-gate into torchlight and ten thousand people. Four camps, four banners, one night sky. Quests GB-01/02 (§5). Beats:
- **The banner ceremony.** The player's faction commander formally gives them the line-standard position their rep earned. Full-screen `cinematic_beat` (in-engine camera rail, letterbox — MANDATES in-game cinematics).
- **Walk the camps.** All four camps are open pre-battle; rival principals get one scene each (Fielderine checking wagon-loads of *bandages, not arrows*; Valrom on a crate, Gorescream across his knees, *laughing* with his packs; Sabira "counting tents, wrong direction"; the shell legion standing in rows of twelve — allied, this time, and no less wrong).
- **The Stranger** walks the lines once, is seen by the player and by no one else, and is gone (§3 VILLAIN_ARC thread — TP-appearance between TP-14 and TP-16; he does not speak).
- **Roster assembly.** Named NPCs greet the player; the Bent Oar levy arrives late, embarrassed, beloved.

### PHASE 1 — THE MARCH (playable column, ~12 min, light combat)
The army moves north as one column with the player in it — speed-matched escort tech (inverted TP-15 pattern: the player walks *inside* a moving formation). March cadence audio: boots, Drego's voice reading names over the wind (South variant: the forge-drums). En route, hand-placed vignettes every ~40 s:
- rows of twelve dead pilgrims beside the road, arranged where they dropped;
- a hungering family walking *through* the column, unarmed, eyes north — the soldiers part around them, nobody gives the order to stop them, and the player watches them go (they will be at the Pit door in Phase 4);
- the walked-ahead NPC (`pit_reason` flag) glimpsed crossing a ridge, half a mile ahead, alone, unhurried — **Beat B5** first firing;
- kerb-stones going green as the column passes (waking).
- **BEAT B1 — THE SKY GOES UNNATURALLY CLEAR.** At the ridge crest, the fog — present in every outdoor frame since level 1 — rolls back like a curtain being drawn. Stars. The whole column stops without an order. Black Night visible on the horizon, blue-black and sharp, and above it *nothing at all*. Canon: Z12's no-fog clarity (WORLD_PLAN), promoted to an army-wide dread beat; TP-16's "clarity as the final wrongness" seeded here, at scale. One line, from whichever named NPC is closest: *"I've never seen the sky. I thought it would feel like more."*
- **First contact** at the line: a skirmish sized to teach the battle's systems — 20-ish thread-slipped dead, one dragged-back demonstration (a Bent Oar boy goes down and is *carried*, alive, rearward: the fail-forward loop shown before it's needed).

### PHASE 2 — THE FIELD (the main engagement, ~30 min)
- **BEAT B2a — VALROM'S HORN.** One note, brass, impossibly loud — a horn built by forges that make Gorescream (the Varcolaci do not forge for beauty, ~3695). Every lane advances on it. The battle begins on that sound in all four variants; only the South variant stands close enough to see him blow it.
- **Structure:** three simultaneous pressure fronts (LaneSim) + the player's lane runs **three hold-point cycles** and **three roaming objectives**, interleaved so the player is always choosing what to save. Hold-point loop: reach → fortify (30 s, `use_item` barricade/brazier interactions) → survive waves (scaled by LaneSim pressure) → lane pushes forward. Roaming objectives (any order, missable-with-consequence, never fail-stop): reinforce a buckling neighbor squad · escort Maren's stretcher-team through a gap · re-light the signal braziers (cleanses Battle Wound stacks, §6.4).
- **Champions (all variants, one per hold cycle):**
  1. **The Sergeant of the Rows** — a Great-War revenant in officer's kit, thread-slipped, tough/elite. Gimmick: it *arranges* — downed fighters near it are dragged into a neat row of twelve, and anything completing a row stands back up. Kill priority teaches the corpse-grammar as mechanics.
  2. **The Gaunt Choir** — a wedge of hungering led by a prophet whose voice has too much room in it (`whisper` form — one Underlanguage sentence, never translated, lanterns dim in a 40-tile radius). The Choir doesn't attack; it *walks through the line*, and everything entranced follows it. Break the entrancement by downing the prophet — who is, visibly, a starved farmer from the Famine Fields. No good feeling is available. That's correct.
  3. **The Brood-Mother** — the Digging Creature's last brood (Boss-1 kin, Part IX ~3169–3184), an elite burrower opening a transmission trench across the lane; risen crawl out of it until she's dead and the trench is collapsed (`use_item` charges). Her death rattle is three notes, very nearly one.
- **BEAT B3 — THE COUNT OF THREE.** Mid-phase, unannounced: every hostile on the field halts for exactly three heartbeats — the Sangeroasa hammer vignette (Z22) at continental scale — then resumes as if nothing happened. No explanation, ever. Allies' barks afterward do the work: *"Did the— did everything just—"* *"Eyes front."*
- **Protect windows:** each named NPC on the roster gets one scripted danger window in this phase (§6 per variant). Fail = wounded and carried off (never dead; §6.4).

### PHASE 3 — THE RIM (the alliance frays, ~12 min)
The lanes converge on Black Night's outskirts; the Convergence thickens (comprehension-dead husks now; kerb-stones orange). And with the door in sight, the Second Cooperation does exactly what the first one did — it starts to come apart:
- **BEAT B2b — THE SECOND HORN.** Valrom sounds the advance on the Grave itself — and the echo that comes back off the tundra is *wrong*: a half-note flat, one beat late, as if answered. The South variant sees Ilion turn to stare at the King. All variants hear it.
- **The flashpoint duel (variant-specific, §6):** each faction discovers a rival's real play at the rim and the player fights a named champion over it — Ilion's vanguard rushing the door (fought by W/N/E variants), Sabira's blades slipping the cordon (fought by W/N/S), Radovan's wardens sealing the door *against* the player (per `radovan_pact`), or Accord wardens under Fielderine's order barring *everyone* (fought by S/E if the player's faction pushes). Duels are 1v1 arena pockets inside the crowd (crowd parts, ring of shields — Godot: local nav region + crowd agents pushed to ring radius). **No duel is to the death** — every rival champion is dragged back by their own side at ~15% HP. The cold war must survive the night; killing a principal here would detonate the epilogue and the raid politics.
- **Choice beat (schema `choice`, sets `rim_choice`):** expose the rival's play to your commander (rep +own, −rival, the rim cordon strengthens) or let it ride (a debt the epilogue collects). No clean option; both are re-priced in the epilogue crawl.

### PHASE 4 — THE BREACH (the Grave's outer door, ~10 min)
The final push to the door across Lilith's own graveyard. The Convergence is densest here — and so is the wrongness: the hungering family from Phase 1 arrives at the cordon; the walked-ahead NPC is *at the door*, hand on it, waiting (B5 final firing — combat parts around them; nothing touches them; nothing ever touched them).
- **The door problem:** the Grave's outer door has no mechanism on this side (it is a tomb; it was built to be closed). The armies begin to force it — rams, forge-charges, Council rites — and nothing marks it.
- **BEAT B4 — THE THREAD IGNITES.** Every blue filament in the sky — the lattice the player has seen over the North since level 20 — flares white-blue at once, horizon to horizon. Every shell on the field freezes mid-swing for one beat. The mass graves stop opening. Then the shells still hers form a **corridor** from the cordon to the door, shoulder to shoulder, facing outward — and the door stands open. Not breached: **open**. Lilith has spent the leash to clear her own tomb's threshold, and the Veil pays for it (the sky's clarity now reads faintly *wrong-colored*, and stays that way through the raid). Her voice arrives once, through every shell at once, level and very tired: ***"Go down. I cannot hold both doors."***
- **BEAT B2c — THE THIRD HORN NEVER COMES.** Valrom raises the horn for the kill-order at the open door — and stops, mid-breath. South variant sees why (the dagger-hand, or its absence, per `dagger_disarmed`); other variants only see the strongest army on the continent *not advance*, and Ilion's hand on the King's arm. The silence where the third note should be is the battle's last held breath.

### PHASE 5 — THE DESCENT HANDOFF (~4 min, no combat)
The faction line forms up at the threshold and **holds the door open behind the player** — that is the battle's whole strategic product. Farewell pass down the line: every surviving rostered NPC gets one line (wounded ones are propped up to say theirs; the Bent Oar levy gives the player something small and stupid and warm — logged to `moments` as `moment_banner`). The player (+ raid group, adventurer-sim placeholder hooks per WORLD_PLAN deferral) walks the shell corridor and down. The battlefield audio — horns, hammers, ten thousand voices — muffles with each stair, layer by layer (audio buses ducked on depth triggers), until by the Still Market (TP-16 Stage 1) the loudest sound is the player's own footsteps. **The Great Battle ends where the raid's unnatural quiet begins; the contrast is the handoff.**

Surface state persists into the raid as texture: hold-points won/lost change Stage-1 barks and which wounded NPCs are visible sheltering in the Still Market's doorways; `rim_choice` decides who is standing at the Pit rim in Stage 4 alongside the `radovan_pact` logic (VILLAIN_ARC TP-16).

---

## 5. QUEST CHAIN (schema v2 defs — buildable list)

Chain `great_battle`, qtype `main`, zone `gravemark_field`, level 58, tone `heavy` (the mandated exception to heavy-heavy adjacency: the Pit band is uninterrupted by design, VILLAIN_ARC §4). All defs carry `requires_flags: {battle_line: X}` variants where marked ⓥ.

| id | step | Title | Objectives (v2 kinds) | Notes |
|---|---|---|---|---|
| `gb_muster_01` | 1 | **The Second Cooperation** | talk (commander ⓥ) → reach (walk the four camps, 4 sub-reaches) → talk (banner ceremony ⓥ) | Phase 0. Sets roster from flags; `cinematic_beat("battle_banner")`. |
| `gb_muster_02` | 2 | **Faces From Home** | talk ×N (rostered NPCs; N from save flags, min 3) | Optional-feeling but auto-offered; every talk logs a `protect` target. |
| `gb_march_03` | 3 | **The Long Column North** | reach (march, escort-inverted) → vigil (the ridge, B1, 20 s) → kill (first contact, 12 thread-slipped) | Phase 1. `cinematic_beat("sky_clear")`. |
| `gb_field_04` | 4 | **Hold the Line** ⓥ | reach (Hold 1) → use_item (fortify ×3) → kill (wave, LaneSim-scaled) → kill (Sergeant of the Rows, elite) | Phase 2, cycle 1. Protect window #1 fires mid-wave. |
| `gb_field_05` | 5 | **The Ones Who Walk** ⓥ | reach (Hold 2) → choice (block the hungering column with shields / part the line and let them pass — sets `let_them_pass`) → kill (Gaunt Choir prophet) | The battle's moral center. Neither option is praised. `villain_beat: {kind: "arrangement"}`. |
| `gb_field_06` | 6 | **The Trench** ⓥ | reach (Hold 3) → kill (Brood-Mother, elite) → use_item (collapse trench ×3) → vigil (B3 count-of-three, 3 s, auto) | Phase 2 close. |
| `gb_rim_07` | 7 | **Four Banners, One Door** ⓥ | reach (the rim) → kill (flashpoint duel ⓥ, non-lethal scripted end) → choice (`rim_choice`) | Phase 3. Rep ±two factions (QUEST_ARCH rule 4). |
| `gb_breach_08` | 8 | **The Door Was Never Locked** | reach (the door approach) → kill (cordon defense wave) → vigil (B4 Thread ignition, 15 s) | Phase 4. `cinematic_beat("thread_ignite")`, then `whisper_pit` family. |
| `gb_descent_09` | 9 | **Hold It Open Behind Me** | talk (farewell line pass) → reach (the corridor, the stairs) | Phase 5. Grants `moment_banner`; turn-in IS the raid entrance; `follow_up` → TP-16 Stage 1 quest. |

Side defs (auto-offered during Phase 2, `qtype: side`, missable): `gb_side_stretchers` (escort Maren's team ⓥW / Drego's call-post ⓥS / Ilka's litany ⓥN / Sabira's extraction ⓥE), `gb_side_braziers` (re-light ×4), `gb_side_reinforce` (save the buckling squad). Completing side defs feeds LaneSim ally strength and the Battle Honors grade (§6.5).

---

## 6. FACTION-VARIANT DESIGN (the same night, four wars)

The variant changes: lane, formation fantasy, support mechanics, rostered NPCs, protect windows, the flashpoint duel, and every bark. It does NOT change: phases, beats B1–B6, champions, the door, the handoff. One battle, four memories of it — built for four playthroughs.

### 6.1 ANGEL WINGS — "The Wall of the Poor" (Lane W)
The weakest army on the field and the one doing the most work (~1752–1757: *Angel Wings does not win battles. It outlasts them*). Formation fantasy: the **shield-wall** — the player fights inside a line of farmers with pikes that re-forms every time it breaks, arrow volleys called overhead (screen-wide VFX, no gameplay damage to allies), and the densest stretcher-web on the field (fail-forward is *fastest* here; the Humans are best at carrying each other — that is the theme, made mechanical).
- **Roster:** Fielderine (command knoll — she marched; the lead box did not), Maren (stretcher-master), Scout-Widow Pall (fog-line calls — except there is no fog tonight, and it is unmanning her), the TP-07 clerk if saved (carrying the banner, eating at last), Granary-village survivors if TP-06 flags warm.
- **Protect windows:** Maren's team caught in the open (cycle 1) · Pall overrun at the listening post (cycle 2) · the clerk's banner-stand (cycle 3).
- **Flashpoint duel:** **Ilion**, when the South vanguard rushes the open door. Fielderine's order is barred spears against the strongest army on the continent, and she gives it without raising her voice. Non-lethal end: Ilion disengages the moment Valrom's third horn doesn't come.
- **Signature beat:** at B4, the shield-wall — which has been retreating in good order all night — takes one step *forward* unordered, whole-line. Fielderine, quietly: *"Now they understand it. That's the whole army I ever needed."*

### 6.2 SANGEROASA — "The Wedge" (Lane C)
The strongest raw army (~1641) played as forge-tempo aggression: the player fights at the tip of wedge charges called on drum-signals, forge-thrall siege beasts (re-tinted slag-walker elites) crash lanes open, and Gorescream — audible three lanes away — clears zones the player exploits. Highest kill-count variant, and the one where the moral texture bites hardest (you are the best in the world at killing people who are only walking).
- **Roster:** Valrom (spine command — near, enormous, wrong), Ilion (silent, filing the night as it happens), Anara (field-reader, hooded — hiding her hands; she reads kerb-stones for the column and hates every second), Pit-Caller Drego (reads the dead over the battle-roar; his call-post is the rally point), Soot-Boy Tav (water-runner; his protect window is the variant's heart).
- **Protect windows:** Anara marked by listeners (they *turn toward her* — the last fluent reader, cycle 1) · Drego's post overrun (cycle 2) · Tav caught between wedges (cycle 3).
- **Flashpoint duel:** an **Accord warden-captain** at the rim when Valrom orders the door taken — the player literally fights the cordon their other playthrough defended. If `dagger_disarmed`: Valrom hesitates at B2c on his own, and Ilion's line is *"He stopped himself. Write that down."* If not: Ilion physically stays the King's arm, and the player sees the dagger-hand shaking.
- **Signature beat:** B3's count-of-three lands here as the Sangeroasa vignette come home — every Varcolac on the field knows the hammers-stop and every one of them goes grey under the fur.

### 6.3 COUNCIL OF SIX / IELE — "The Still Legion" (Lane E)
The dead defending the world, on ground made of their own mass graves. Formation fantasy: the **shell legion** — rows of twelve advancing in perfect silence (allied, and still the creepiest thing on the field), and **Threadwardens who re-leash**: the variant's unique verb is *conversion* — warden rites (channel objectives the player defends) that wrestle thread-slipped dead back onto Lilith's leash mid-fight, turning enemy units allied in place. The North doesn't kill the Convergence; it *recovers* it.
- **Roster:** Vasile (loud, procedural, secretly terrified and rising to it — his best night), Radovan (present per `radovan_pact`: pact accepted = at the player's shoulder clearing their way; refused = *racing* them, his wardens a rival unit on the same lane), Threadwarden Ilka (naming every shell under her breath, against regulations, all night), the freed Iele shell if QS-6 freed (fighting beside the player with a will of its own — the only volunteer among the dead).
- **Protect windows:** Ilka's re-leashing rite (cycle 1) · Vasile pinned when procedure meets a trench (cycle 2) · the freed shell targeted by the Sergeant of the Rows — it wants it *back in a row* (cycle 3).
- **Flashpoint duel:** per `radovan_pact` — refused: **Radovan's warden-champion** sealing the door against the player; accepted: **Sabira's blade-lieutenant** caught slipping the cordon Radovan is holding open. 
- **Signature beat:** B4 from inside — every shell in the legion freezes *including the ones beside the player*, and when they move again, Ilka is the one who says it: *"That wasn't a stumble. She spent them. She spent all of them at once."*

### 6.4 BLESTEM — "The Observers" (roaming, Lane E flank)
Small standing army, enormous reach (~1580): the player runs with Sabira's blades — a thirty-strong elite that is officially not fighting. Formation fantasy: **the battle as a heist** — smoke-screen redeploys, ambush pockets, sabotage objectives (collapse the Brood-Mother's trench *before* she's a boss if scouted early — the only variant that can pre-empt a champion), and intelligence pings: the Black Coach's spotters mark champion spawns and protect windows 20 s early on the player's HUD. Lowest body-count, highest information.
- **Roster:** Sabira (handler, on the field in person — which everyone who knows her knows is itself intelligence), Mistress Neagu's courier (the West's watcher watching the watchers), the TP-08 debt made flesh — if `fed_cazimir_rubbings` ≥ 6, a Lower-Market listener *serving in the column*, still and wrong, "on loan"; if the player refused the rubbings, Cazimir's favor-debt is called tonight: one order the player may refuse (choice, rep-priced).
- **Protect windows:** Sabira's forward post (cycle 1) · the courier's run (cycle 2) · the listener-on-loan targeted by the Gaunt Choir — it *wants its own back* (cycle 3).
- **Flashpoint duel:** an **Ilion vanguard-tracker** who has been filing *Sabira* all night. Winning it, the player finds his file: it is about *them*.
- **Signature beat:** at B2b's wrong echo, every Blestem blade looks at Sabira. Sabira looks at the sky. *"File that under: things we do not sell."*

### 6.5 Fail-forward (the mandated no-game-over spec — all variants)
- **Player at 0 HP in Phases 1–4:** no death screen. Screen desaturates 40% (reuse `dead_walk` shader family at partial strength), two faction stretcher-bearers spawn-run to the player (guaranteed path — they are non-targetable), a 4-second carried camera plays, and the player stands back up at the current rally brazier with full HP and one stack of **Battle Wound** (−10% damage dealt, −10% move, 90 s, max 3, cleansed instantly at a lit brazier — making `gb_side_braziers` self-motivating). LaneSim ally-strength ticks −1 per drag (the line missed you). No XP loss, no reload, no repair bill beyond normal.
- **Named NPC at 0 HP:** never dies. Enters *downed-shielded* (10 s): the player (or any ally squad in range) can complete a `protect` interact to get them carried off **wounded** (out for the night, epilogue bark changes, Battle Honors −1) instead of **mauled** (same, −2, and their Phase 5 farewell is delivered from a stretcher). Death is not on the table by design: this battle's stakes are the *world's*, and the player's personal stakes were already taken hostage at TP-15 — killing roster NPCs here would spend grief the finale needs (VILLAIN_ARC: cheerful deposits are the finale's ammunition).
- **Hold-point lost:** the lane's front regresses (LaneSim), the *next* objective moves south, ambient allied barks darken, Battle Honors −1. The battle never restarts an objective; it re-stages forward. Phase transitions fire regardless — because the door was always going to open (§1.4). Losing everything all night yields the same door and a battlefield that looks like the cost of it.
- **Battle Honors (grade, not gate):** tally of holds kept, protects clean, sides done, drags avoided → epilogue texture, faction rep bonus, the war-title (feeds the ranks/titles mandate: *"…of the Four Banners"* variants), and the faction war-mount hook (MOUNTS raid-mount family). Grade is never shown as a number during the battle; it is shown as the state of the line.

---

## 7. THE PERF PLAN (hundreds of combatants at 60 FPS, honestly)

Ground truth: our combat units are `CharacterBody2D` with per-frame `_physics_process` (enemy.gd) — that scales to dozens, not hundreds. The battle therefore runs **three concentric simulation rings** around the player plus a **lane abstraction** for everything off-screen. The proven repo patterns (culled TileMapLayers + proximity spawns, WORLD_PLAN engine note; frozen-snapshot reuse) extend as follows.

### 7.1 The rings

| Ring | Radius | What lives there | Budget | Cost model |
|---|---|---|---|---|
| **R0 — Combat** | ≤ ~600 px (sight radius) | Real units: `enemy.gd` instances + allied `battle_ally.gd` (new; enemy.gd subclass, friendly mask). Full combat.gd hooks, loot-less. | **≤ 28 total** (≈14 allies + 14 hostiles), hard cap enforced by spawner | physics + AI, as today |
| **R1 — Puppets** | 600–1600 px | Lightweight fighters: `Node2D` + `AnimatedSprite2D`, **no physics, no collision** — position lerped along squad paths, animation state (fight/walk/fall) driven by squad, HP is a squad scalar not per-unit. Staggered think: each puppet ticks at 5 Hz, batched 1/12 per frame. | **≤ 90** | ~1/10 of an R0 unit |
| **R2 — Crowd** | > 1600 px / to horizon | **MultiMeshInstance2D** crowd layers (one allied, one hostile, one corpse), instance positions updated in chunks (1/8 of instances per frame), `INSTANCE_CUSTOM` data = frame index + palette row into a shared atlas (palette_swap.gdshader already in repo covers faction tinting). No nodes per unit. | **≤ 1,400 instances** across 3 MultiMeshes | one draw call per layer |

**Promotion/demotion at ring crossings:** squads (not individuals) are the unit of transfer. A squad crossing into R1 materializes N puppets sampled from its strength scalar; crossing into R0 range converts up to the R0 cap's headroom into real units (nearest-first), the remainder stays puppet. Demotion folds real units back into the squad scalar (their HP averaged in). The player never sees a pop: conversion happens ≥ 500 px out, and sprites are identical across rings (same sheets).

### 7.2 LaneSim (the off-screen war)
Autoload `BattleDirector` owns three `LaneSim` structs: `{front_px, ally_strength, enemy_pressure, event_queue}` ticking at **1 Hz** (not per-frame). Player outcomes apply modifiers (hold kept: +strength; champion down: −pressure; side quests: ±). Visible spawning *samples* lane state — the crowd near the player is always consistent with the scoreboard. Because LaneSim is pure data at 1 Hz:
- the entire battle runs **headless** (Engineering Law: `tests/battle_sim_test.gd` runs all phases at 100× speed and asserts phase transitions, no-softlock, and grade bounds);
- distant-lane visuals are driven by LaneSim directly into R2 crowd chunk targets (the other two lanes are always visibly fighting, for free);
- reload/checkpoint restore is a struct copy.

### 7.3 Hard budgets (assert in dev builds, `BattleDirector.frame_audit()`)
- Physics bodies active: **≤ 40** (28 combat + player + escorts + margin). Everything else collisionless.
- Projectiles + spell VFX nodes: **≤ 40** live; volleys/army-scale effects are shader/particle fakes on a full-screen layer, not per-arrow nodes.
- Corpses: real/puppet deaths spawn into the **corpse MultiMesh** (cap 400, oldest fade). Beat B6 (rows of twelve) is a corpse-MultiMesh position ease — the arranging is literally a lerp, cost ≈ 0.
- Audio: 3 crossfading crowd-intensity beds (driven by local pressure) + **≤ 8** positional one-shots + beat stingers. Horn/Thread/count-of-three beats duck everything (existing bus layout).
- Weather/sky beats (B1, B4) are WorldEnvironment/canvas-modulate tweens + one shader (thread lattice = a parallax `Line2D` batch flaring via material param) — no entity cost.
- Deterministic: every phase seeds RNG from `save_id + phase` (screenshot QA reproducibility; RH_* harness per memory).
- Target: **60 FPS mid-Phase-2 on the dev machine with frame_audit green**; the audit script + a windowed screenshot QA pass (crowd visible in all three rings, beats fire) ship with the feature — MANDATES Engineering Law.

### 7.4 New engine primitives (delta list)
1. `battle_director.gd` (autoload, instanced-scene-scoped): phases, LaneSim ×3, ring manager, spawn budgets, frame audit, checkpoint save block (JSON-safe).
2. `battle_ally.gd`: enemy.gd subclass — friendly collision mask, squad membership, drag-and-carry behaviors (stretcher pair is 2 allies in a `carry` state).
3. `crowd_layer.gd`: the 3 MultiMesh layers + chunked update + atlas anim + B6 arrange-ease.
4. `squad.gd` (Resource): strength scalar, path, formation offsets, ring state — the promotion currency.
5. Player `dragged` state: partial-desaturate shader + input lock + carried path (shares plumbing with TP-16's `dead_walk`; build once, parameterize).
6. Quest objective reuse: everything in §5 maps to existing v1/v2 kinds (talk/kill/reach/choice/use_item/vigil) — **no new objective kinds needed.** `protect` windows are `vigil`-with-a-target sugar handled by BattleDirector emitting objective progress.

---

## 8. EPILOGUE & THE HINDSIGHT CODA (no clean win, sealed)

Played after the raid (whatever the TP-16 ending), as the surface epilogue's first movement:
- Dawn over Gravemark Field. The armies burying their own — each in their own grammar (canon: bodies as signage). The Battle Honors grade is *visible*, not printed: how many stretcher-tents, how long the rows.
- Rostered NPC barks per survived/wounded state; `rim_choice` and `let_them_pass` collect their debts here (the family the player let pass is found at the cordon line, sitting down, facing the door, resting — alive or otherwise per the ending).
- **The coda (one camera rail, no dialogue, `villain_beat: {kind: "arrangement"}`):** low sun, long shadows — and in the light, visible only at this angle, the dust across the *entire battlefield* lies in fine parallel lines. All of them point at the Pit. Four armies, ten thousand boots, one night of chaos — and the ground underneath was aligned the whole time. Hold on it three seconds. Cut. Never mentioned again, anywhere, by anyone.

The Second Cooperation ends the way the first one did: with a pit, and a fire, and the survivors deciding what to call it. The difference — the only difference, and the one the whole game argues for — is what got carried out this time, and who did the carrying.

---

## 9. ACCEPTANCE CHECKLIST (build gates)
- [ ] Villain grammar audit: zero enemies "commanded"; all Convergence units are consequences with canon lineage; B-beats use only `symptom/whisper/arrangement` forms.
- [ ] All four `battle_line` variants playable start-to-door; variant-blind content (phases, champions, B1–B6) verified identical.
- [ ] Roster assembly covers the empty case (a player who saved no one still gets the Bent Oar levy + faction principals; the battle never feels unpopulated by punishment).
- [ ] Fail-forward: forced-loss playthrough (lose every hold, every protect, get dragged 10×) reaches the door with degraded texture and zero blocks.
- [ ] `frame_audit` green at 60 FPS mid-Phase-2; headless `battle_sim_test.gd` passes; screenshot QA set (muster, B1 crest, Phase-2 tri-ring crowd, B4 ignition, corridor) captured per variant.
- [ ] Lore nouns verified against `_lore_extract.txt`; no Underlanguage translated; the sky-clarity, horn, and Thread beats match canon citations herein.
- [ ] Handoff: Phase 5 flows into TP-16 Stage 1 with audio duck-down and surface-state flags (`battle_phase`, `battle_honors`, `rim_choice`, `let_them_pass`, `moment_banner`) persisted and read.
