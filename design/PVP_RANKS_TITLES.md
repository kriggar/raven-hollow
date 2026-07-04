# RAVEN HOLLOW — THE ARENA, PVP MILITARY RANKS & TITLES
### 1v1 duels on the Reckoning Floor · the Accord Roll (14 ranks) · the Titles ledger
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic spirit, lore-adapted.

**Grounded in (read before implementing):**
- `scripts/class_defs.gd` — the seven class kits (`{id, name, abilities[], max_hp, …}`);
  ability shapes (`melee_arc/projectile/aoe_ring/dash/summon/buff/volley`) — the duel-bot
  casts **these exact abilities**, nothing bespoke.
- `scripts/enemy.gd` — the reusable AI bones: state machine (`patrol/chase/attack`),
  windup→strike telegraph with `HIT_RANGE` re-check, `apply_slow/apply_root`, leash,
  `Nameplate` inner class (line 540), `palette_swap.gdshader` for varied bot looks.
- `scripts/save_system.gd` — the systems-block contract: any node in a named group with
  `serialize() -> Dictionary` / `deserialize(d)` (JSON-safe, String keys) is snapshotted
  via `_system_snapshot(group, script_path)` — quests/crafting/weather precedent.
  New consts needed: `PVP_SCRIPT`, `TITLES_SCRIPT` (mirrors `QUESTS_SCRIPT`).
- `scripts/combat.gd` — faction-aware `Projectile` (targets `"player"` group when
  `faction != "player"`); the duel-bot joins faction `"duelist"` and both sides re-use it.
- `scripts/travel_system.gd` + `map_registry.gd` — the arena is a small registered map
  reached by waystation (same plumbing as every zone).
- `design/COMBAT_PACING.md` — `PlayerRefDPS(60) ≈ 358`, `PlayerRefEHP(60) ≈ 2 830`
  (mirror-match burn time ≈ 8 s before defensives — drives round/timer math §3).
- `design/CHARACTER_STATS.md` — primaries; bots derive stats identically (level → primaries
  → derived), so a duel-bot is *budget-honest*, never stat-cheated.
- `design/ITEM_PROGRESSION.md` — BP budget formula for rank-gear itemization; gold economy
  (~25–40 g/hr at bracket 30) that the wager sink must respect.
- `design/STATUS_EFFECTS.md` — effect registry & threshold proc-chains; the flood/heat
  hazards and the title-trigger hooks ride this framework.
- `design/MOUNTS.md` — speed tiers (I +60% / II +100%), item-shaped mounts, GROUND ONLY.
- `design/CALENDAR_EVENTS.md` — the Draconian year; season turns and event titles.
- `WORLD_PLAN.md` — Sangeroasa districts incl. **the Killing Floors & Blood Channels**;
  the three raids (The Killing Floors / The Black Spire / The Grave & the Bloodstone Pit).
- `_lore_extract.txt` — the Accord, the Long Vigil, the Pause, Varcolaci blood-culture,
  the count-of-three hammer stop, "collected", the Untithed logic (Valrom's Pit-Brute).

**Owner mandates served (MANDATES.md):**
- 🗓 *Duels; ARENA (1v1 ONLY)* — §2–§6. One venue, strictly 1v1, best-of-3.
- 🗓 *World military PvP RANKS like WoW (lore-adapted ladder) + TITLES system* — §7–§10.
- 🔒 *Bots = full smart "players"* is **deferred by owner** — §6 ships a duel-bot on the
  existing enemy-AI bones + class kits FIRST; §6.5 is the seam where Sim bots slot in 1:1.
- *NO TRANSMOG / WYSIWYG* — rank cloaks are **distinct real items** (§8.3), never overlays.
- *GROUND MOUNTS ONLY* — rank-11 mount and the seasonal mount are tier-II ground stock.
- *TONE LAW (heavy-cheerful)* — the Floor is warm: crowds, wagers, a rude announcer —
  built on top of an abattoir that still smells of what it was.

---

## 1. Audit — what exists, what this re-uses, what is new

| Fact | Source | Consequence for this design |
|---|---|---|
| Enemy AI is a compact, proven state machine with telegraphs, CC hooks, nameplates | `enemy.gd` | Duel-bot v1 = a re-skinned controller on these bones driving **player class kits** — small, shippable now |
| Player abilities are pure data (`ClassDefs.abilities`), executed by `player.gd` handlers per `kind` | `class_defs.gd` | The bot needs a thin `AbilityCaster` that replays the same data shapes; no ability is re-authored |
| `Combat.Projectile` is already faction-aware | `combat.gd` | Bot volleys/projectiles work day one by setting `faction = "duelist"` |
| Save system snapshots any group-registered system | `save_system.gd` | `pvp_ladder` and `titles` are two new system nodes; **no SAVE_VERSION bump** (blocks are additive, `_normalize` defaults them) |
| No player-vs-player damage path exists (players only take damage from enemies/projectiles) | `player.gd take_damage` | The duel-bot is a *hostile actor*, not a player instance — it deals damage through the existing enemy/projectile paths. PvP rules (§3.4 DR, dampening) live in the match manager, not in `player.gd` |
| Nameplate renders name + optional HP bar | `enemy.gd:540` | Extend with an optional second line (title, smaller, muted) — used by duel-bots and, later, Sim adventurers |
| Character sheet is a fixed 200×264 panel | `character_sheet_ui.gd` | Title picker = one row in the header (§10.4), no layout surgery |
| MAX_LEVEL is 10 (demo) | `xp_system.gd` | All formulas below are written for cap 60 per mandate; ranked play gates at 60, wager duels at 10+ (§4.3) |

**New scripts this doc specifies:** `arena_builder.gd`, `arena_match.gd`, `duel_bot.gd`,
`adventurer_roster.gd`, `pvp_ladder.gd`, `title_defs.gd`, `titles.gd`. All static-data +
small-node style, matching the repo's conventions.

---

## 2. THE VENUE — The Reckoning Floor (Sangeroasa, the Killing Floors district)

### 2.1 The lore-perfect choice, and why not Blestem

The candidates were a Blestem wager-ring and Sangeroasa's Killing Floors. **Blestem is
disqualified by its own canon**: Strigoi violence "is never hot; it is filed" — open,
witnessed, bet-upon bloodshed is culturally impossible in the Listening City. Sangeroasa
is the opposite pole by canon: the Varcolaci despise Blestem precisely as "cowards who
won't bleed in the open." A public dueling pit belongs to the forge-city the way a ledger
belongs to the East.

**The Reckoning Floor** is a decommissioned killing floor in the Killing Floors & Blood
Channels district — one slaughter-gallery drained, sanded, and re-consecrated to a purpose
the city considers *more* honest, not less. The engineered drainage is still live: the
channels under the grating still carry blood away, and the house still uses it. Nothing in
Sangeroasa is wasted.

**The Accord frame (why all four banners fight here).** The Accord is "four powers
managing the stone, not each other" — and four powers full of soldiers with six centuries
of grudges need a pressure valve that isn't war. **Accord Point 9** (this doc's canon
extension, same register as the lore's "Accord Point 4"): *grievances between the banners
may be settled on a drained floor, first blood thrice, filed and done.* The Floor is thus
the one place on the continent where a Vigil lamplighter, a Strigoi clerk, a Varcolaci
forge-guard and a thread-driven Iele shell stand in the same queue — which is exactly what
a joint military ladder (§7) needs to exist.

### 2.2 The place (level design brief)

A sunken oval pit, ~22×14 tiles of red-sanded basalt, ringed by:
- **The grating ring** — iron grates over live blood-channels at the pit's outer edge
  (the sudden-death flood hazard, §3.3). Faint warm updraft; the sand near the grates
  is darker. Nobody rakes it.
- **The gallery** — two tiers of standing crowd (NPC clutter + roster adventurers
  lounging between their own matches, §6.5). Torch and forge-glow lighting — the
  HDR-2D "honest ray tracing" showcase after dark.
- **The Blood Ledger** — a nailed-up board by the gate (the queue/wager UI, §4): names,
  stakes, odds, and a final column that, for retired duelists, reads *settled*. (Never
  "collected" — the Floor is superstitious about the Pit's word.)
- **The gate** — a peace-bonding checkpoint. Weapons stay worn (WYSIWYG — you *are* your
  gear) but bags lock and buffs strip on the threshold (§3.2).
- **Hazard dressing** — a central **heat-vent seam** (hairline orange glow under the
  sand; §3.3 dampening flavor) and the hammer-audio of the forge district all around.

**Access:** waystation "Sangeroasa — the Reckoning Floor" (existing discover→fast-travel
plumbing). It sits at the Killing Floors district edge — the **raid** (The Killing Floors,
WORLD_PLAN) is the deeper, still-working half of the district; the arena is its retired
antechamber. Two content pieces, one address, no collision.

### 2.3 The cast (5 NPCs, `npc_data.gd` additions)

| NPC | Role | Voice |
|---|---|---|
| **Floor-Master Vasa** | Varcolaci, retired pit-boss, one ear. Runs the Floor; the challenge/queue dialogue. | "The Floor doesn't care what banner you bleed under. That's the kindest thing in this city." |
| **The Tithe-Clerk** | Strigoi, Accord oversight. Files wagers, pays out, keeps the Blood Ledger. | "Your stake is filed. Your odds are filed. Your confidence is noted, and filed." |
| **Accord Registrar Neagu** | Human (Angel Wings commission). Administers the Accord Roll — rank-ups, standing, rank titles (§7). | "Fourteen rungs. The top one keeps a lamp you cannot see. Start walking." |
| **Vigil Quartermaster Osana** | Iele shell, thread-driven, unfailingly polite. Rank-gear vendor (§8). | "This cloak has a rank in it. Wear the rank. The cloak comes along." |
| **The Bone-Surgeon** | Grey, elderly, kind hands. Post-match heal-to-full and cheerful gallows humor — the TONE-LAW warmth. | "Nothing the Floor takes tonight that soup won't put back." |

---

## 3. DUEL RULES — best-of-3 on the count of three

### 3.1 Format

- **Strictly 1v1** (owner law). No pets exceeding the kit (necromancer `summon` abilities
  are part of the kit and legal — the summon is the class).
- **Best-of-3 rounds.** First to 2 round-wins takes the match.
- **Round end:** a duelist reaching 0 HP is *dropped to 1 HP and staggered* — the
  Floor-Caller calls the round; nobody dies on a filed duel (Accord Point 9). No durability
  loss, no death penalty, no corpse run.
- **Between rounds:** 10 s reset — both duelists teleport to gates, HP/mana restored to
  full, **all cooldowns reset**, round-applied effects purged. Every round is a clean read
  of kit vs kit.
- **Round timer: 90 s**, then sudden death (§3.3).

### 3.2 The gate rules (WYSIWYG in combat form)

On crossing the threshold both sides are normalized — *"you enter as you are"*:
- All temporary buffs stripped (`status.purge_all_kind("buff")` except persistent food —
  Well Fed is honest preparation, canon to classic).
- **Bags locked** (no consumables mid-match; `bag_ui` gets an `arena_locked` flag).
- **Mounts locked** (the Floor is 22 tiles; also: dignity).
- Gear is untouched — what you wear is what you fight in and what your opponent *sees*,
  which is the WYSIWYG law doing PvP work: you can read an opponent's build off their
  sprite before the count finishes.

### 3.3 The count of three, and the Floor's impatience

**Round start — the count of three.** Canon vignette, weaponized: when a round begins,
*the hammers of Sangeroasa stop — all of them, at once, for a count of three* — and the
duel starts on the third silence. Mechanically: 3 s freeze with audio drop (duck the forge
loop, three sub-bass "absences"), then control unlocks. It is the best starting gun in any
game because the whole city is the gun.

**Sudden death at 90 s — the channels rise.** The Tithe-Clerk pulls a lever; the grating
ring floods: the outer 3 tiles of the pit become a hazard field (STATUS_EFFECTS ground-tick,
`aoe_ring` render via `VFX.ground_circle`, dark red): **4% max-HP per second** while
standing in it, escalating +1%/s every 10 s. The safe area is the inner oval; at 120 s the
flood takes another ring. Forces engagement; no round exceeds ~150 s.

**Anti-stall dampening — the heat rises.** From 45 s into a round, both duelists take
**+3% damage-taken per 5 s** (stacking, `stat_mods {"damage_taken_pct": +3}` hidden
effect, id `floors_heat`). Flavor: the heat-vent seam under the sand. Kills healer
stalemates (druid/paladin mirrors) without touching class balance.

**Draws:** double-KO → round replays (max once, then higher-HP%-at-stop rule); timer with
both alive → higher HP% wins the round; exact tie → replay.

### 3.4 PvP-only combat modifiers (live only inside `arena_match.gd`)

These apply to both duelists for the match duration — the match manager applies/removes
them; `player.gd` and class kits are untouched:

| Rule | Value | Why |
|---|---|---|
| CC diminishing returns | same-school slow/root: 2nd application within 15 s at 50% duration, 3rd at 25%, 4th immune (15 s window) | rogue/mage chain-CC would be TTK-dominant at 8 s mirror burn |
| Burst ceiling | crit damage vs duelists ×1.5 (not ×2) | keeps the 8 s RefDPS mirror from being a coin-flip opener |
| Summon cap | 1 concurrent minion per duelist | necromancer kit legal, zerg illegal in a 1v1 law |
| Absorb/defensive scaling | unchanged | defensives are the *decision layer* COMBAT_PACING trains; leave them loud |
| Out-of-round regen | n/a (full reset §3.1) | rounds are clean experiments |

---

## 4. QUEUE & CHALLENGE FLOW

### 4.1 Two entry points, one escrow

1. **The Blood Ledger (queue).** Interact with the board → pick stake tier (§5) → the
   Tithe-Clerk escrows your stake → matchmaking draws an opponent from the roster within
   ±150 rating (widening +50 every 10 s of "queue", instant in practice — bots are always
   available; the queue theater is a 5–20 s wait with the opponent *walking in through the
   gate*, announced by the Floor-Caller. The wait sells the fiction that they came from
   somewhere).
2. **Direct challenge.** Roster adventurers lounge in the gallery (3–6 present, rotating
   by rating band). Talk to one → challenge via dialogue (`npc.gd` dialogue tree) → stake
   select → same escrow. Beating a *named* lounger is how grudges and repeat rivals form —
   the roster remembers (§6.5 persona memory).

### 4.2 Match flow (state machine for `arena_match.gd`)

```
IDLE → CHALLENGED {opp_id, stake} → ESCROW (gold moves to ledger)
     → GATE (strip buffs, lock bags/mount, teleport to gates)
     → COUNT (3 s hammer-stop)  → ROUND (90 s + flood)  → ROUND_END (call, reset 10 s)
     → [best-of-3 loop] → RESOLVE (payout §5, rating §7.2, RP §7.3, titles check §10)
     → REMATCH? (same stake re-offer, one click) → IDLE
```

Disconnect/quit mid-match = forfeit (stake lost to the ledger; rated as a loss). Saving is
blocked during ROUND (same guard as combat).

### 4.3 Brackets & gating

| Bracket | Who | Rated? | Purpose |
|---|---|---|---|
| **Wager duels** (levels 10–59, per-decade bands 10-19 … 50-59) | any class ≥10 | **unrated** | practice + gold-wager fun while leveling; bots drawn at-band with ITEM_PROGRESSION-normal gear |
| **The Roll** (level 60) | max level | **rated** (Elo §7.2) | the seasonal ladder, the Accord Roll, everything in §7–§8 |

Level 10 floor = after the class-teaching starter experience (mandate: starting zones
teach the class; the Floor assumes you graduated).

---

## 5. WAGERS — the Blood Ledger

Wagering is the Floor's soul and the design's **gold sink** (with Riding, THE sinks).

| Stake tier | Cost | Gate | Payout on win |
|---|---|---|---|
| Sand | 2 g | rank 1 (enlisted) | 3.6 g |
| Iron | 10 g | rank 2 | 18 g |
| Blood | 50 g | rank 4 | 90 g |
| Ledger | 200 g | rank 7 | 360 g |

- The ledger matches your stake; **the Floor's tithe is 10% of the pot** — win pays
  `stake × 1.8`. At a fair 50% winrate the expected value is **−10% per match**: the arena
  *consumes* gold at scale, exactly what the classic-tuned economy (25–40 g/hr at bracket
  30, ITEM_PROGRESSION) needs. Skill (beating your band) is the only way to run positive,
  and rating catch-up (§6.4) erodes that within a session — honest, self-limiting.
- **Free tier always exists** (0 g, "for the sand") — rating/RP unaffected by stake;
  wagering is flavor + sink, never pay-to-rank.
- **Daily ledger cap:** winnings beyond 500 g/day pay out at ×1.0 (stake back, no profit) —
  "the Clerk's pen runs dry." Anti-farm without blocking play.
- All wagers, results, odds are *written on the board* — the Blood Ledger UI doubles as
  match history (last 20 rows persisted, §9 schema).

---

## 6. THE DUEL-BOT — ships first, Sim slots in later

The Adventurer-Sim pillar (full smart "players") is **owner-deferred**. The arena must not
wait for it. Phase 1 is a *duel-bot*: the existing enemy-AI bones driving real class kits.

### 6.1 What a duel-bot is (`scripts/duel_bot.gd`)

A `CharacterBody2D` in faction/group `"duelist"`:
- **Body & look:** `ClassDefs` sheet/variant for its class + `palette_swap.gdshader`
  palette from its roster entry — every bot is a *visually distinct adventurer*, not a
  monster. `Enemy.Nameplate` with the new title line (§10.4): `"Dragoslav\nBlade-Captain"`.
- **Stats:** derived exactly like a player — level → CHARACTER_STATS primaries → derived
  HP/mana/damage, plus an ITEM_PROGRESSION *normal-gear* budget for its bracket. A bot is
  never stat-cheated; difficulty comes from **skill knobs** (§6.3) only. (This is the
  anti-frustration law: losing to a bot must always read as "it played better".)
- **Abilities:** its class's `ClassDefs.abilities` verbatim, executed by a thin
  `AbilityCaster` helper that replays the same `kind` handlers the player uses
  (`melee_arc` sweep, `Combat.Projectile` spawn, `aoe_ring` placement, dash, buff, summon,
  volley). No bespoke bot abilities, ever — the bot IS the class kit.

### 6.2 The brain (reuses `enemy.gd` patterns, three layers)

1. **Movement policy** (per class archetype — the `FAMILY_MULT` idea, inverted for kits):

   | Archetype | Classes | Policy |
   |---|---|---|
   | bruiser | warrior, paladin | close and stay glued; save gap-closer for opponent's disengage |
   | skirmisher | rogue | stick + peel: disengage at <35% HP, re-open with dash |
   | ranged-physical | rookwarden | hold 140–200 px band, strafe-kite, volley at range keeps |
   | caster | mage, necromancer | hold band, cast; drop `aoe_ring` on predicted path; panic-dash on melee touch |
   | hybrid | druid | mode-switch: caster band until forced, bruiser inside 60 px |

2. **Rotation table** — per class, a priority list over the kit (opener → spender →
   filler → defensive-at-threshold), data-defined in `duel_bot.gd` so tuning is a table
   edit. Defensive/heal abilities fire at HP thresholds (e.g. 40%) with reaction delay.
3. **Reaction model** — the human-izer. The bot *perceives* events (windup started,
   projectile spawned, ring telegraph placed) and responds after `reaction_s`; dodges
   (perpendicular step / dash) succeed at `dodge_pct`; interrupts (where a kit has one)
   at `interrupt_pct`. All three scale with rating (§6.3). Sub-0.4 s player telegraphs
   being un-dodgeable is already COMBAT_PACING doctrine — the same physics apply to bots.

### 6.3 Skill knobs (rating → behavior; the whole difficulty system)

| Rating band | reaction_s | dodge_pct | interrupt_pct | rotation efficiency | kite quality |
|---|---|---|---|---|---|
| <1100 (Sand) | 0.9 | 20% | 10% | skips spenders, mashes filler | drifts, corners itself |
| 1100–1400 (Iron) | 0.6 | 40% | 30% | correct order, wastes some mana | holds band loosely |
| 1400–1700 (Blood) | 0.45 | 60% | 55% | clean rotation, saves burst for openings | strafe-kites, uses flood ring against you |
| 1700–2000 (Ledger) | 0.35 | 75% | 70% | punishes your cooldown gaps | herds you toward hazards |
| 2000+ (Warden band) | 0.30 | 85% | 85% | near-optimal, baits defensives | pixel-band control |

`0.30 s` reaction floor and `85%` ceilings are deliberate — the bot stays beatable-by-read
at every band; it never becomes an aimbot.

### 6.4 Rating & fairness plumbing

Bots carry real ratings (§6.5) and the match uses the same Elo math as the player (§7.2) —
the ladder is *one* population. Matchmaking ±150 keeps expected winrate 40–60%.

### 6.5 The roster — the seam where the Sim slots in (`scripts/adventurer_roster.gd`)

```gdscript
## The ONLY interface the arena knows. Phase 1: procedural persistent roster.
## Phase Sim: the Adventurer Sim implements this same contract with live agents.
static func opponents_for(rating: float, band: int, n: int) -> Array   # entries below
static func report_result(bot_id: String, won: bool, vs_rating: float) -> void
static func weekly_tick() -> void   # off-screen ladder drift (bots duel each other, cheap Elo sim)
## Entry shape (exact):
##   {"id": "adv_017", "name": "Dragoslav", "class_id": "warrior",
##    "kingdom": "sangeroasa",          # look + taunt flavor, faction-appropriate
##    "rating": 1520.0, "rank": 7,       # rank derived from its own simulated RP
##    "look": {"sheet": "male1", "variant": 0, "palette": 3},
##    "titles": ["rank_07"], "active_title": "rank_07",
##    "persona": {"aggression": 0.7, "caution": 0.3,
##                "lines": {"win": [...], "loss": [...], "rematch": [...]}},
##    "memory": {"vs_player_w": 2, "vs_player_l": 1}}   # grudges: repeat rivals taunt accordingly
```

- Phase 1 generates **~200 named adventurers** (Draconian name tables per kingdom, all
  seven classes, ratings ~N(1350, 250)) at first arena visit, persisted in the save.
  `weekly_tick()` drifts their ratings so the ladder *lives* between your sessions.
- The full Sim later replaces the generator with its live agents — **same entry shape,
  same two report calls**. `arena_match.gd` and `duel_bot.gd` never change. That is the
  entire migration.
- Roster bots hold ladder positions, earn simulated RP, and appear on the seasonal
  standings board (§7.4) — your percentile is computed against *them*, so seasonal rewards
  work in single-player exactly like a server.

---

## 7. THE ACCORD ROLL — 14 military ranks, lore-adapted

### 7.1 The ladder (the four kingdoms' joint commission)

WoW's 14 PvP ranks, re-founded in canon: after the Pause, the Accord raised a joint order
— **the Vigil** — to walk the roads, keep the lamps, check the wells, and *not read the
stones*. Its Roll is the one military ladder all four banners recognize (Accord Point 9's
administrative twin), maintained by Registrar Neagu at the Floor. You do not fight *for*
a kingdom on the Roll; you fight to be trusted with more of the watch.

| # | Rank (WoW analog) | The duty, in one line |
|---|---|---|
| 1 | **Lamplighter** (Private) | Keeps one lamp lit on one road. |
| 2 | **Well-Warden** (Corporal) | Checks the wells for copper. Tastes them personally. |
| 3 | **Fog-Sergeant** (Sergeant) | Leads a file of lamps through the interior seams. |
| 4 | **Stone-Sergeant** (Master Sergeant) | Patrols the standing stones. Has never read one. That is the qualification. |
| 5 | **Vigil-Blade** (Sergeant Major) | First rank permitted to draw on Accord business. |
| 6 | **Blade-Lieutenant** (Knight) | Commands a crossing where two banners' patrols pretend not to see each other. |
| 7 | **Blade-Captain** (Knight-Lieutenant) | Holds a border fort's roll and its tempers. |
| 8 | **Veil-Champion** (Knight-Captain) | Duels for the Vigil's honor when a banner's grievance is filed. |
| 9 | **Lieutenant of the Accord** (Knight-Champion) | Carries sealed words between capitals. Does not read those either. |
| 10 | **Commander of the Accord** (Lieutenant Commander) | Commands all lamps of one kingdom's roads. |
| 11 | **Marshal of the Four Roads** (Commander) | The four capital roads answer to one rider. |
| 12 | **Field Marshal of the Veil** (Marshal) | Holds the fog-line itself in the Long Vigil's name. |
| 13 | **High Marshal of the Long Vigil** (Field Marshal) | Second lamp of the continent. Signs the Roll. |
| 14 | **Warden of the Pause** (Grand Marshal) | Keeps the lamp no one may see out. There is one per season, and the rank is a weight. |

Each rank grants its **title** (§10, `pos: "prefix"` — "Fog-Sergeant Kriggar") and its
rewards row (§8).

### 7.2 Arena rating (the skill axis)

Elo, one pool (player + roster): start **1200**; `K = 32` for your first 20 rated matches,
then `16`; `expected = 1 / (1 + 10^((opp − you)/400))`; `rating += K·(score − expected)`.
Floor 800. **Season-high** is tracked separately — top-rank gates (§7.3) read season-high,
so one bad night never demotes access mid-season.

### 7.3 Rank Points (the contribution axis) — arena now, battlegrounds later

Ranks are earned by **RP**, an effort currency, so the ladder rewards showing up and
serving, not only peak rating (the WoW-classic soul, minus its life-destroying decay):

- **Per rated win:** `RP = 15 × (1 + clamp((opp_rating − your_rating)/400, −0.5, +0.5))`
  (7.5–22.5). Losses: 0 RP (never negative).
- **First win of the day:** +30 RP. **Weekly quota** (10 rated matches, win or lose):
  +150 RP. Active-casual ≈ 500–700 RP/week.
- **Battlegrounds (later):** `PvpLadder.grant_rp(amount, source)` is the public API the
  Bloodroad supply war will call per objective (escort delivered, lamp relit, cart
  burned). The ledger doesn't care where service happened — the API ships now, the BG
  fills it later.
- **Decay (gentle, top-heavy):** ranks 11+ lose 300 RP per *fully idle* week (0 rated
  matches). Ranks 1–10 never decay. Earned ranks 1–10 are permanent commissions.

| Rank | RP required (cumulative) | Rating gate (season-high) |
|---|---|---|
| 1 | 0 — enlistment quest (§7.5) | — |
| 2 | 150 | — |
| 3 | 400 | — |
| 4 | 800 | — |
| 5 | 1 400 | — |
| 6 | 2 200 | — |
| 7 | 3 200 | — |
| 8 | 4 500 | 1 500 |
| 9 | 6 200 | 1 600 |
| 10 | 8 400 | 1 700 |
| 11 | 11 000 | 1 800 |
| 12 | 14 000 | 1 950 |
| 13 | 17 500 | 2 100 |
| 14 | 21 500 | 2 250 **and** finish a season top-0.5% (§7.4) |

At 500–700 RP/week, rank 10 ≈ 3–4 months, rank 13 ≈ 7–9 months, rank 14 is a
season-defining feat — classic pacing without classic's 18-hour days.

### 7.4 Seasons

- **Four per year**, turning on the Draconian calendar (CALENDAR_EVENTS): **Season of
  Thaw** (ends at Sowing Day), **Season of Embers** (ends as the Emberfall Vigil closes),
  **Season of the Proofing** (ends at the Thinning), **Season of the Long Dark** (ends at
  the Turning of the Count, Dec 31).
- At season end: rating soft-resets toward 1200 (`new = 1200 + (old − 1200)/2`),
  season-high clears, RP and ranks persist (minus decay rules).
- **Seasonal standings** (you vs the ~200-adventurer roster, §6.5):

| Finish | Reward |
|---|---|
| top 0.5% | title **"the Untithed"** (suffix; §10) + mount **Crimson Floor-Hound** (tier-II ground, epic — *"Whelped under the grating. The Floor never took a drop from it. Professional respect."*) + eligibility for rank 14 |
| top 3% | title **"of the Red Sand"** + Wardenweave-trim cloak variant (§8.3) |
| top 10% | title **"Pit-Proven"** |
| top 35% | 100 g ledger bonus + gallery cheer on entry for a season (flavor flag) |

### 7.5 Enlistment (rank 1 quest, teaches everything)

"**One Lamp**": Registrar Neagu swears you in → light one waystation lamp on the Bloodroad
→ return → one free-stake instructional duel vs "Instructor Brañka" (fixed 1000-rating
bot, class-mirrored) with the Floor-Caller narrating the rules (count of three, rounds,
flood). Completes → rank 1, title *Lamplighter*, the Roll UI unlocks. Ten minutes, zero
reading required, every §3 rule demonstrated once.

---

## 8. RANK REWARDS (WYSIWYG-lawful)

### 8.1 Principles

- **No tabards exist** (and no transmog ever): rank identity lives on the **Vigil cloak
  line** — each trim tier is a **distinct real item** with its own icon, sprite, and
  stats. The trim is *in the item*, not painted over it. Inspect-at-a-glance still works:
  a lamp-gold hem IS a Commander, because only Commanders can buy the item.
- Rank gear is **bought with gold, gated by rank** (classic law): a second sink, and the
  reason wager gold circulates.
- Itemization uses the ITEM_PROGRESSION BP budget at the listed ilvl — rank gear is
  *sidegrade-competitive* with dungeon blues/raid epics (PvP-flavored stat mixes: stamina
  and armor lean), never strictly better. Raids keep their crown; RUNEWORDS keep theirs.
- Sprites/icons come from downloaded packs + the proven ComfyUI pixel pipeline (asset plan
  mirrors MOUNTS §7).

### 8.2 The rewards ladder

| Rank | Unlock |
|---|---|
| 1 | title; Sand stakes; the Roll UI |
| 2 | Iron stakes; Osana's consumables page (world-PvE potions; still bag-locked in duels) |
| 3 | **Vigil Cloak, Brass Trim** (back, i24 rare) |
| 4 | Blood stakes |
| 5 | Vigilant's bracers + boots (i30 rare pieces) |
| 6 | **Vigil Cloak, Forge-Red Trim** (i38 rare); Vigilant's legs + chest |
| 7 | Ledger stakes; full **Vigilant's Battledress** access (6-piece rare set, i40–44, per-armor-class variants: cloth/leather/mail/plate — proficiency law) |
| 8 | Vigilant's weapons (i44 rare, one per class archetype) |
| 9 | **Vigil Cloak, Veil-Grey Trim** (i50 epic) |
| 10 | **Commander's Accord** set access begins (epic, i52–56, kingdom-trim variant chosen at purchase — faction-appropriate look, human/strigoi/varcolaci/iele stylings) |
| 11 | **THE MOUNT** — free choice of one of four kingdom war-mounts (tier-II ground, epic): *Accord Grey* (Angel Wings horse), *Bloodroad Siege-Wolf* (Sangeroasa), *Night-Coach Black* (Blestem), *Pale Row-Steed* (Black Night). Race/faction-appropriate mandate, served. |
| 12 | **Vigil Cloak, Lamp-Gold Trim** (i58 epic); Commander's Accord completion |
| 13 | **High Marshal's weapons** (i60 epic, best PvP weapons in the game) |
| 14 | **Wardenweave** (i60 unique cloak — near-black, one hairline hem thread of *shifting orange*; the Registrar swears it is only dye. The Registrar does not meet your eye.) + **the Warden's Lamp** — a faint warm lamp-glow aura (HDR-2D light, honest 2D form; the only rank with a light source) + title **Warden of the Pause** |

### 8.3 Cloak asset note

Five cloak sprites (brass/forge-red/veil-grey/lamp-gold/wardenweave) + the top-3% seasonal
trim variant = 6 back-slot sprites + icons. Trim colors deliberately avoid the detection
grammar's blue/violet/green (those *mean* things in this world); the Wardenweave's orange
hairline is the one intentional, whispered exception.

---

## 9. DATA SCHEMA & SAVE (`pvp_ladder.gd`)

```gdscript
## scripts/pvp_ladder.gd — node, add_to_group("pvp_ladder"). Static-free state owner.
## save_system.gd: const PVP_SCRIPT := "res://scripts/pvp_ladder.gd"  (QUESTS_SCRIPT pattern)
signal rank_changed(new_rank: int)
signal match_resolved(won: bool, rating_delta: float)

func serialize() -> Dictionary:
    return {
      "season": 3, "rating": 1487.0, "season_high": 1512.0,
      "rp": 3350.0, "rank": 7,
      "wins": 84, "losses": 61, "season_wins": 22, "season_losses": 15,
      "weekly": {"week_id": "2026-W27", "rated_matches": 6, "first_win_day": "2026-07-04"},
      "wager": {"day": "2026-07-04", "profit_today": 120},
      "history": [ {"opp": "adv_017", "opp_name": "Dragoslav", "won": true,
                    "stake": 10, "rounds": [1,0,1], "rating_after": 1487.0} ],  # last 20
      "roster": AdventurerRoster.serialize(),   # ~200 entries, the living ladder
    }
```

- JSON-safe throughout (String keys, no Vector2) per the save contract.
- `_normalize` defaults the whole block when absent — old saves load clean, **no
  SAVE_VERSION bump**.
- `weekly_tick()` runs on load when `week_id` changed: applies quota bonus/decay and the
  roster drift — the ladder moved while you were gone.

---

## 10. TITLES — the second name you earned

### 10.1 Rules

- **One active title**, prefix OR suffix by its definition. Prefix: `"Fog-Sergeant Kriggar"`.
  Suffix: `"Kriggar, the Untithed"`.
- Titles are **permanent once earned** (even seasonal ones — the *season* is in the title's
  tooltip; wearing an old Untithed is a veteran's flex). Exception: **Warden of the Pause**
  may only be *worn* by the current season's holder — there is one lamp (rank persists,
  the title re-locks if you don't re-qualify; its tooltip explains the weight).
- Earned via signals, checked in one place: `titles.gd` listens to quest completion, raid
  clears, status-effect expiries (§10.3), pvp_ladder rank/season events, calendar events.

### 10.2 The title ledger (initial registry — extend forever)

**PvP — rank titles (14):** the Accord Roll names, §7.1, ids `rank_01…rank_14`, all prefix.

**PvP — arena feats:**

| id | Title | pos | Earned |
|---|---|---|---|
| `the_untithed` | the Untithed | suffix | season finish top 0.5% (§7.4) |
| `of_the_red_sand` | of the Red Sand | suffix | season top 3% |
| `pit_proven` | Pit-Proven | suffix | season top 10% |
| `bloodletter` | Bloodletter | suffix | 100 rated wins |
| `ledger_long` | Ledger-Long | suffix | 1 000 duels fought (win or lose — the Clerk respects attendance) |
| `flawless` | the Flawless | suffix | win a match 2-0 without dropping below 90% HP in either round |

**PvE — legendary weapons** (per-class suffix on completing the class legendary questline;
names finalize with the LEGENDARY_WEAPONS design pass — reserve the ids now):
`legend_warrior…legend_druid`, e.g. warrior *"Forgebreaker"*, necromancer *"Threadwright"*
(placeholder flavor, 7 rows).

**PvE — raid feats:**

| id | Title | pos | Earned |
|---|---|---|---|
| `pit_breaker` | Pit-Breaker | suffix | clear The Killing Floors (Valrom down) |
| `spirewalker` | Spirewalker | suffix | clear The Black Spire (Cazimir found) |
| `the_bookmark` | the Bookmark | suffix | finish The Grave & the Bloodstone Pit — you held the Pause, the way Kriggar holds it: a bookmark the stone tolerates |
| `of_the_long_vigil` | of the Long Vigil | suffix | all three raids cleared on one character |
| `first_lamp` | First Lamp | prefix | *first* clear of each raid within its content-season window (per character; the "server-first" analog in a one-hearth world) |

**Event titles** (CALENDAR_EVENTS, one per major beat — earned by finishing the event's
capstone quest that year):

| id | Title | Event |
|---|---|---|
| `keeper_of_kept_names` | Keeper of Kept Names | The Kept Names |
| `the_ward` | the Ward | Ward's Week |
| `emberkept` | Emberkept | The Emberfall Vigil |
| `the_proofed` | the Proofed | The Proofing |
| `of_the_gift` | of the Gift | The Gift-Tide (wear it knowing what the Gift is made of) |
| `thin_walker` | Thin-Walker | The Thinning |
| `stranger_fed` | Stranger-Fed | The Table of Strangers |
| `count_keeper` | Count-Keeper | present at the Turning of the Count bell |

**Hidden-debuff survivor titles** (the owner's hidden-debuff mandate, celebrated —
`titles.gd` listens to `StatusEffects` expiry/threshold signals):

| id | Title | pos | Earned |
|---|---|---|---|
| `still_walking` | Still Walking | suffix | survive a Hungering pull (4+ stacks of `hungering_touch`) at ≤5% HP — *"already collected — why is it still walking?"* |
| `copper_blooded` | Copper-Blooded | suffix | let `copper_sickness` expire naturally 3 times (never bought the cure) |
| `the_untreated` | the Untreated | suffix | let `infected` run its full 300 s five times |
| `mange_proof` | Mange-Proof | suffix | kill a dog-swarm pull while at 5 stacks of `mange` |
| *(hook)* | — | — | every future hidden debuff may declare `survivor_title` in its def — the registry grows with the bestiary |

**Exploration / conduct:**

| id | Title | pos | Earned |
|---|---|---|---|
| `of_the_four_roads` | of the Four Roads | suffix | discover all four capital waystations |
| `the_incurious` | the Incurious | suffix | finish Act I without reading a single inscription stone. Old Marta's own discipline. The rarest kind of wisdom. |

### 10.3 Schema (`title_defs.gd` + `titles.gd`)

```gdscript
## scripts/title_defs.gd — static registry, ClassDefs style.
## Def shape (exact):
##   {id, name, pos,                # "prefix" | "suffix"
##    cat,                          # "pvp_rank"|"pvp_feat"|"raid"|"legendary"|"event"|"survivor"|"conduct"
##    desc,                         # tooltip: how it was earned, one lore line
##    hidden}                       # true = not shown in the sheet until earned (survivor/conduct surprises)
const TITLES := { "rank_01": {...}, ... }

## scripts/titles.gd — node, add_to_group("titles").
## save_system.gd: const TITLES_SCRIPT := "res://scripts/titles.gd"
signal title_earned(id: String)
func grant(id: String) -> void            # idempotent; fires signal + toast "Title earned: …"
func set_active(id: String) -> void       # "" = none
func display_name(base: String) -> String # applies active prefix/suffix
func serialize() -> Dictionary:  return {"known": ["rank_01", "still_walking"], "active": "rank_01"}
```

### 10.4 Display

- **Nameplate:** `Enemy.Nameplate` gains an optional second line — smaller, muted-gold,
  under the name. Player frame (hud.gd top-left) shows `Titles.display_name(player_name)`.
  Duel-bots and (later) Sim adventurers use the same line — the gallery reads like a
  server.
- **Character sheet:** one new row in the header — the active title under the character
  name, click → a compact list popup (known titles, category-grouped, tooltip = `desc`),
  "None" always first. No layout surgery on the 200×264 panel; the popup is its own
  panel, ornate-UI kit styling.
- **Blood Ledger & standings board:** names render with active titles. Seeing
  *"Blade-Captain Dragoslav"* above you on the board is the whole motivation loop in four
  words.

---

## 11. INTEGRATION CHECKLIST (implementation pass, in order)

1. **`title_defs.gd` + `titles.gd`** + save block + toast — smallest ship, immediately
   grants event/raid/survivor titles as those systems land. Nameplate second line +
   character-sheet row.
2. **`arena_builder.gd`** — the Reckoning Floor map (waystation, pit, gallery, 5 NPCs,
   Blood Ledger board prop) registered in `map_registry.gd`.
3. **`adventurer_roster.gd`** — generator + persistence + `weekly_tick`.
4. **`duel_bot.gd`** — body (ClassDefs sheet + palette swap), AbilityCaster, movement
   policies, rotation tables, reaction model, skill knobs.
5. **`arena_match.gd`** — state machine §4.2, gate rules, count of three, flood +
   `floors_heat` (two STATUS_EFFECTS defs), round/match resolution, escrow/payout.
6. **`pvp_ladder.gd`** — Elo, RP, ranks, seasons, decay, save block; Registrar +
   Quartermaster dialogue; enlistment quest "One Lamp".
7. **Rank gear + cloaks** — 6 cloak sprites/icons, two sets × armor-class variants,
   4 rank-11 mounts + Crimson Floor-Hound (MOUNTS pipeline), vendor tables.
8. **Season plumbing** — calendar hooks (4 turn dates), soft-reset, standings board UI,
   seasonal reward grants.
9. **Later, free:** Bloodroad battlegrounds call `grant_rp()`; the Adventurer Sim
   re-implements `adventurer_roster.gd`'s contract — nothing else changes.

## 12. Mandate compliance (self-audit)

| Mandate | Where honored |
|---|---|
| ARENA (1v1 ONLY) | §3.1 — strictly 1v1, one venue, Bo3; no team queues exist anywhere in the doc |
| Sim pillar deferred; simple bots first | §6 ships on enemy.gd bones + class kits; §6.5 is the 1:1 Sim seam |
| WoW-style ranks, lore-adapted, arena + BG earned | §7 — 14-rank Accord Roll; RP from arena now, `grant_rp` API for BGs later |
| Rank rewards: gear / mount / tabard-equivalent | §8 — rank-gated sets, rank-11 kingdom mounts, cloak-trim line |
| NO TRANSMOG / WYSIWYG | §8.1 — every trim tier is a distinct real item; no overlays, no cosmetics layer |
| GROUND MOUNTS ONLY | §8.2 r11 + §7.4 — all tier-II ground stock |
| Titles: PvP + PvE feats + events + hidden-debuff survivors, nameplate + sheet, schema + save | §10 complete |
| Level cap 60 / classic pacing | §4.3 brackets; §7.3 month-scale rank grind |
| TONE LAW (heavy-cheerful) | §2 — a warm, loud, wagering crowd on a floor that remembers being an abattoir; the Bone-Surgeon's soup |
| Every fight teaches the class | §6.1 — bots ARE the class kits; losing is a legible lesson |
