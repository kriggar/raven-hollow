# RAVEN HOLLOW — THE DEED-BOOK (MMORPG ACHIEVEMENT SYSTEM)
### WoW-style achievements, Draconia-voiced: categories · points · metas · titles/mounts/real-item rewards · hidden deeds · account ledger · gold-bezel toasts
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic spirit, lore-adapted.

**Grounded in (read before implementing):**
- `design/MANDATES.md` — *"MMORPG/WoW-style achievement system: categories (quests/exploration/
  dungeons/PvP/professions/feats), points, meta-achievements, title+mount rewards, toast UI,
  account ledger"* (🔄 → this doc). Also: NO TRANSMOG / WYSIWYG · GROUND MOUNTS ONLY ·
  CONCRETE TOOLTIPS · Engineering Law (auto-QA + improvement loop) · TONE LAW.
- `design/PVP_RANKS_TITLES.md` — the **titles registry** (`title_defs.gd` / `titles.gd`,
  §10): rank titles, raid titles, event titles, survivor titles, `the_incurious`.
  Achievements GRANT and LISTEN to that registry; they never duplicate it.
- `design/MOUNTS.md` — `MountDefs.MOUNTS`, `MountSystem.teach(id)`, the reins-item shape,
  tier rules, the palette-swap asset economy. Achievement mounts are new registry rows.
- `design/HIDDEN_DEBUFFS.md` — the 35-effect catalogue, survivor feats, the fairness
  contract (§1) that this doc's hidden achievements inherit wholesale.
- `design/VILLAIN_ARC.md` — the 16 touch-points, the hindsight test, TP-10 false victory,
  the thesis cures; source of every villain-arc secret deed below.
- `design/NARRATIVE_VOICE.md` — R1/R2/R3 registers, banned lexicon, word budgets. Every
  achievement `name` and `lore` line in this doc is register-tagged and lint-clean.
- `design/CRAFTING.md` — the 10 Draconia professions, rank names (Hand/Sworn/Master/Keeper),
  condition crafting, `_roll_skill_up`. **Note:** thresholds below reference RANK NAMES,
  not raw skill numbers, so they survive the owner's max-crafting-skill-1000 re-scale.
- `design/CALENDAR_EVENTS.md` — the 8 festival capstones and their titles.
- `scripts/save_system.gd` — the systems-block contract: group node + `serialize()/
  deserialize(d)` (JSON-safe, String keys) snapshotted via `_system_snapshot(group,
  script_path)` — quests/crafting/weather precedent. One new const: `ACHIEVEMENTS_SCRIPT`.
- `scripts/quests.gd` — `quest_completed(quest_id)`, `rewards_granted`, `cinematic_beat`.
- `scripts/travel_system.gd` — `station_discovered(station_id)`; zone discovery rides the
  first-entry banner flag (NARRATIVE_VOICE §4) in `main.gd`.
- `scripts/enemy.gd` — `_die()` grants kill XP and already resolves creature family; one
  added line reports the kill. `scripts/hud.gd` — `GOLD := Color(0.85, 0.68, 0.35)`,
  Alagard gold labels, the aged-wood 9-patch rim: the toast is built from this kit.
- `scripts/character_sheet_ui.gd` — the fixed 200×264 panel; the Deed-Book opens as its
  own popup panel, PVP_RANKS_TITLES §10.4 title-picker precedent.
- `WORLD_PLAN.md` — 40 zones, 10 dungeons, 3 raids, 16 named rares, the Grey Ferry.

**Owner mandates served:** the MANDATES.md achievements row, in full (§12 self-audit).

---

## 1. AUDIT — what exists, what this re-uses, what is new

| Fact | Source | Consequence for this design |
|---|---|---|
| Titles system fully specified (registry + grant + display + save) | PVP_RANKS_TITLES §10 | Achievements grant title rewards through `Titles.grant(id)` and treat `title_earned` as a criteria event — zero duplicated logic |
| Mounts are registry rows taught via `MountSystem.teach(id)` | MOUNTS §1.3/§2.2 | Achievement mounts = 2 new `MountDefs` rows (both horse-base tints — honest asset cost), taught directly on earn, no reins item needed |
| Save system snapshots any group-registered system | save_system.gd | Per-slot progress = group `"achievements"` node; **no SAVE_VERSION bump** (additive block) |
| No account-wide storage exists (saves are per slot) | save_system.gd | NEW: `user://deedbook.json` — the account ledger, written on earn, independent of slots (§8). Achievements survive slot deletion, exactly like WoW's account pane |
| Quest/travel/crafting/pvp systems all emit signals | scripts + design docs | The engine is a **signal-fed event bus** (§9): systems call one `Achievements.event()` line or are auto-wired to their existing signals |
| Hidden-debuff survivor titles already defined with a growth hook | PVP §10.2, HIDDEN_DEBUFFS | Every `survivor_title` def auto-generates a hidden 10-pt achievement (§6.3) — the registry grows with the bestiary for free |
| The HUD has a proven gold-bezel visual language | hud.gd | The toast banner and the Deed-Book panel are restyles of shipped chrome, not new art systems (§7) |
| NO TRANSMOG / WYSIWYG | MANDATES | No cosmetic overlay layer exists or ever will: item rewards are **distinct real items** with own sprite/icon/stats (PVP §8.1 precedent). "Tabard-equivalent" identity lives in real back/trinket items |

**New scripts this doc specifies:** `achievement_defs.gd`, `achievements.gd`,
`deedbook_ui.gd`, plus one-line hooks in `main.gd`, `enemy.gd`, `crafting.gd`,
`player.gd`. Static-data + small-node style, matching repo conventions.

---

## 2. DESIGN LAWS

1. **Account-wide earn, per-character progress** (WoW model). Counters accrue on the
   character; the moment a deed completes it is written to the account ledger forever.
   Character-conduct deeds (deathless runs, the Incurious) track and void per character
   but still earn account-wide.
2. **Points are 5 / 10 / 25 / 50 — nothing else.** 5 = you showed up, 10 = you did the
   thing, 25 = you kept at it, 50 = the world will remember. **Feats of Strength = 0
   points** (WoW law: feats are stories, not currency).
3. **Concrete criteria text** (CONCRETE TOOLTIPS mandate): the `desc` field states
   exactly what to do, with numbers — *"Complete 500 quests."* Never "prove your worth."
   The `lore` line underneath carries the register (R1 for the world's deeds, R2 for the
   hearth's); `desc` is plain UI voice, numbers sacredly clear.
4. **Hidden deeds inherit the HIDDEN_DEBUFFS contract:** no hidden deed punishes; every
   hidden deed is earnable by playing the world's own grammar (surviving, noticing,
   giving freely); the Deed-Book always shows HOW MANY unwritten rows a category holds,
   so completionists know the hunt exists without being told the quarry (§6).
5. **Rewards are WYSIWYG-lawful.** Titles via the titles registry. Mounts via MountDefs
   (GROUND ONLY, tier-scaling like festival mounts). Items are distinct real items —
   never overlays, never a "cosmetics tab." What an achievement puts on your character
   is a thing your character is actually wearing.
6. **Never double-author a feat.** Where titles.gd already owns a trigger (raid titles,
   survivor titles, event titles), the achievement's criteria is simply
   `{"kind":"flag","event":"title_earned","filter":{"id":"…"}}` — one source of truth.
7. **No retroactive loss.** Earned is earned. Seasonal exclusivity lives in Feats of
   Strength, same as the titles system's Warden rule.
8. **Auto-QA (Engineering Law):** `tests/achievements_lint.py` ships with the registry
   (§11) — id uniqueness, points ∈ {0,5,10,25,50}, reward ids resolve against
   `title_defs`/`MountDefs`/`Items`, banned-lexicon regex over `name`+`lore`, every
   hidden entry has a reachable criteria event, every meta's child ids exist.

---

## 3. CATEGORIES & POINTS

Nine categories (WoW's spine, Draconia's names in the UI):

| id | UI name | Panel epigraph (R1, ≤14 words) |
|---|---|---|
| `general` | **General** | *Small things, counted. The counting is the point.* |
| `quests` | **Quests** | *Every errand done is a door that knows you now.* |
| `exploration` | **Exploration** | *The map was older than you. You walked it anyway.* |
| `dungeons_raids` | **Dungeons & Raids** | *The deep places keep their own count. So do we.* |
| `professions` | **Professions** | *Honest work, tallied. The hands remember all of it.* |
| `pvp` | **The Reckoning Floor** | *First blood thrice, filed and done. Here is the file.* |
| `reputation` | **Reputation** | *Four banners, and what each one owes you.* |
| `world_events` | **World Events** | *The year turns. Some of it turned because you were there.* |
| `feats` | **Feats of Strength** | *No points. Points are for things that can be done twice.* |

Points audit of the shipped registry (§10): **1,180 points** across 57 pointed deeds +
3 feats at 0, plus 8 category metas (25 each = 200) and the grand meta (50) = **1,430 total**.
The number is displayed, compared against nothing, and quietly becomes the most
contested stat in the game. That is the WoW inheritance working as intended.

---

## 4. REWARDS — three channels, all WYSIWYG-lawful

### 4.1 Titles (channel 1 — via the PVP_RANKS_TITLES registry)

Achievements reuse existing title ids wherever one exists (`the_incurious`,
`still_walking`, `copper_blooded`, `pit_breaker`, `spirewalker`, `the_bookmark`,
`of_the_long_vigil`, `of_the_four_roads`, `bloodletter`, `ledger_long`, `flawless`,
event titles, `first_lamp`, `the_untithed`). **Six new rows for `title_defs.gd`**
(same def shape, `cat: "deed"`):

| id | Title | pos | Granted by |
|---|---|---|---|
| `well_stabled` | the Well-Stabled | suffix | A-05 (15 mounts) |
| `the_chronicler` | the Chronicler | suffix | A-13 (every zone's quests) |
| `far_walked` | the Far-Walked | suffix | A-20 (all 40 zones) |
| `twice_sworn` | the Twice-Sworn | suffix | A-37 (both primaries at Keeper) |
| `accord_kept` | the Accord-Kept | suffix | A-51 (all four kingdom standings) |
| `long_counted` | the Long-Counted | suffix | M-10 grand meta |

### 4.2 Mounts (channel 2 — via MountDefs; GROUND ONLY)

Two new `MountDefs.MOUNTS` rows, both **horse-base tints** (MOUNTS §7.2 skeleton —
zero new animation cost), tier-scaling with riding rank like festival mounts:

| id | Mount | Rarity | Granted by | Lore line (≤16 words) |
|---|---|---|---|---|
| `almanac_grey` | **The Almanac Grey** | epic | M-09 → A-57 *The Kept Year* | "She knows every feast day. She has opinions about your attendance at all of them." |
| `lamplit_bay` | **The Lamplit Bay** | epic | M-10 grand meta | "A small kept flame hangs at the saddle. Nobody lit it. Nobody has to." |

On earn, `MountSystem.teach(id)` fires directly — no reins item, but the stable page
shows the deed as the source line ("Deed: The Kept Year").

### 4.3 Real items (channel 3 — the tabard-equivalent, without tabards)

No tabards, no transmog, no overlay layer. Category-identity rewards are **distinct
real items** with their own sprite, icon and honest (small) stats, ITEM_PROGRESSION
budget rules, delivered straight to the bag (bag full → held by any innkeeper,
"kept behind the bar" dialogue — no mail system needed):

| Item | Slot | Granted by | The read-at-a-glance |
|---|---|---|---|
| **Chronicler's Satchel-Cloak** | back, i56 epic | M-02 (Quests meta) | ink-stained hem; only quest-finishers wear it |
| **The Far-Walker's Boots** | feet, i56 epic | M-03 (Exploration meta) | visibly resoled thrice; the WYSIWYG flex |
| **Keeper's Work-Apron** | chest, i56 epic (per armor class) | M-05 (Professions meta) | burn-scars and thread-loops per profession palette |
| **A Small Kept Lamp** | trinket, i58 epic | M-10 grand meta | faint warm glow at night (HDR-2D light, honest 2D form — the civilian cousin of the Warden's Lamp) |

Trim colors avoid the detection grammar's blue/violet/green/orange (PVP §8.3 law).

---

## 5. META-ACHIEVEMENTS — the chain

Each category (except Feats) has a completion meta; the eight metas chain into the
grand meta. Metas are `{"kind":"meta","needs":[…ids]}` — they complete the instant
their last child does, and their toasts queue politely behind it (§7.1).

| id | Meta (25 pts each) | Needs | Reward |
|---|---|---|---|
| M-01 | **The Small Things, Counted** | every `general` deed (hidden rows excluded — law §6.2) | — |
| M-02 | **The Chronicle, Bound** | every `quests` deed | Chronicler's Satchel-Cloak |
| M-03 | **No Road Refused** | every `exploration` deed | The Far-Walker's Boots |
| M-04 | **The Deep Places, Settled** | every `dungeons_raids` deed | — |
| M-05 | **A Keeper's Hands** | every `professions` deed | Keeper's Work-Apron |
| M-06 | **The Floor Remembers You** | every `pvp` deed | — |
| M-07 | **Four Banners Answered** | every `reputation` deed | — |
| M-08 | **The Year, Attended** | every `world_events` deed | — |
| M-09 | *(alias)* | M-08's capstone child A-57 carries the mount | The Almanac Grey |
| M-10 | **THE LONG COUNT** (50 pts) | M-01…M-08 | title **the Long-Counted** + mount **The Lamplit Bay** + trinket **A Small Kept Lamp** |

M-10's earn line in the ledger renders in Diablo-2 dark gold (the artifact color law) —
the only Deed-Book row that does.

**Hidden rows never gate metas** (§6.2): a player can bind every meta without ever
finding an unwritten row. Hidden deeds are gifts, not homework.

---

## 6. HIDDEN ACHIEVEMENTS — the unwritten rows

### 6.1 The contract

Hidden deeds are the achievement system speaking the world's own grammar: **symptom
first, name later.** They render in the Deed-Book as an unbleached parchment row —
*"— a deed unwritten —"* — one row per hidden deed, so the count is public and the
content is not (HIDDEN_DEBUFFS fairness law, mirrored). On earn, the row fills in with
full text and the toast fires like any other; the tooltip names what you did
retroactively, the same backwards-story beat as a debuff reveal.

### 6.2 Rules

- Hidden deeds never gate metas and never exceed 25 points.
- Every hidden deed is earnable through play the world already teaches: surviving a
  signature debuff, refusing a temptation, a small warm kindness, noticing an
  arrangement. Never pixel-hunting, never wiki-bait mechanics.
- The death recap, washes, and NPC barks that reveal hidden DEBUFFS also serve as the
  hint economy for hidden DEEDS — the two systems share a discovery grammar on purpose.

### 6.3 The survivor hook (auto-growth)

Every hidden-debuff def that declares `survivor_title` (PVP §10.2 hook) auto-generates
a hidden 10-pt `general` achievement at registry build time: id `surv_<debuff_id>`,
criteria = that title's `title_earned` event, reward = nothing further (the title IS
the reward; the points are the bookkeeping). The catalogue grows with the bestiary and
this registry never needs editing. §10 lists the two hand-authored signature cases
(Still Walking, Copper-Blooded) as exemplars of the generated shape.

### 6.4 Villain-arc secrets (hand-authored)

Tied to VILLAIN_ARC's machinery — the hindsight test, the thesis cures, the false
victory. Shipped in §10: **The Incurious** (A-16, the owner's named exemplar: read
nothing for the whole of Act I), **A Debt Freely Given** (A-17, the H-31 thesis cure
the game never advertises), **The Thirteenth Row** (A-25, Grave-Dim stack 4's false
grave-row, visited). Reserved ids for the design passes that own their content:
`secret_hindsight` (revisit the planted evidence of 8 touch-points after the finale —
the arrangement, seen), `secret_quieting` (a deed inside TP-10's false victory,
finalized with the world-event build).

---

## 7. TOAST & THE DEED-BOOK (UI)

### 7.1 The gold-bezel toast

Built from the shipped HUD kit (`hud.gd` GOLD, Alagard, aged-wood 9-patch):

- **Banner:** top-center, 264×52 px panel; aged-wood 9-patch rim with `GOLD` border
  (the quest-tracker's chrome, widened); slides down 0.25 s, holds 4 s, fades.
- **The bezel:** a 44×44 round gold-bezel medallion overhanging the panel's left edge
  (ornate-UI kit ring), holding the **points numeral** in Alagard gold — "25". Feats
  show a lamp glyph instead of a number.
- **Line 1:** `Deed done.` — small, muted parchment. **Line 2:** the achievement name,
  Alagard gold, 11 px. **Line 3:** category · points (`Exploration · 25 points`),
  8 px muted. Hidden deeds prepend a candle glyph 🕯 rendered as the kit's flame icon.
- **Reward suffix:** if the deed granted a title/mount/item, a second toast queues:
  the existing `titles.gd` / stable / loot toast — never merged, never dropped.
- **Sound:** one shared sting — a struck lamp-glass chime, warm, two notes (distinct
  from the hidden-debuff reveal's single low bell; the ear must never confuse "the
  world wrote on you" with "you wrote on the world"). Meta deeds add a third note.
- **Queue:** toasts serialize with 0.8 s gaps; a meta always queues after its last
  child. Saving/combat never blocks a toast; cinematics defer the queue.

### 7.2 The Deed-Book panel (`deedbook_ui.gd`)

Opens from a new button row on the character sheet header (beside the title picker —
PVP §10.4 precedent; no surgery on the 200×264 sheet, the Deed-Book is its own popup
panel on the ornate-UI kit, ~320×240, hotkey **Y**):

- **Header:** "THE DEED-BOOK" in Alagard gold · right-aligned **"Points kept: 385"**.
- **Left rail:** the nine categories with per-category completion pips (`7/10`) and
  the category epigraph (§3) as tooltip.
- **Rows:** name (gold when earned, parchment-grey when not) · `desc` (plain UI voice)
  · progress bar (kit HP-bar restyle, gold fill) with `123/500` overlay · points chip.
  Earned rows show the date and the character who did it ("Kriggar, 14 Thaw").
  Unearned hidden rows render as §6.1's unwritten parchment.
- **Feats section:** bottom of the rail, separated by a carved rule; no points chips;
  the epigraph does the explaining.
- **Grand meta row:** pinned last under General, Diablo-2 dark gold on earn (§5).

---

## 8. THE ACCOUNT LEDGER

Per-slot progress rides the save (group contract, §9.3). **Earned deeds do not.**

- **File:** `user://deedbook.json` — written atomically on every earn (temp + rename),
  read once at autoload `_ready()`. Never touched by slot save/load/delete.
- **Shape (JSON-safe, String keys):**

```json
{
  "v": 1,
  "points": 385,
  "earned": {
    "expl_four_capitals": {"date": "2026-07-04", "char": "Kriggar", "class": "warrior"},
    "gen_still_walking":  {"date": "2026-06-28", "char": "Kriggar", "class": "warrior"}
  }
}
```

- **Cross-character:** a second character sees every earned row (grey-gold, credited
  to its earner) and re-earns nothing; its own counters still tick so per-character
  conduct deeds (Incurious, deathless) work per run.
- **Rewards on a fresh character:** titles are account-known (titles.gd `known`
  merges the ledger's granted set on load); mounts re-teach on first stable visit;
  item rewards are once-per-account (the ledger records `reward_claimed`).
- Corrupt/missing ledger degrades to empty with a warning — the defensive-load house
  rule; progress re-earns, nothing crashes.

---

## 9. ENGINE — exact GDScript

### 9.1 `scripts/achievement_defs.gd` (static registry, ClassDefs style)

```gdscript
class_name AchievementDefs
## THE DEED-BOOK registry — design/ACHIEVEMENTS.md §10. Pure data, no scene code.
## Lint: tests/achievements_lint.py (ids, points, reward refs, lexicon, budgets).

const CATEGORIES: Array[String] = [
	"general", "quests", "exploration", "dungeons_raids", "professions",
	"pvp", "reputation", "world_events", "feats",
]

## Def shape (exact — every key present, "" / {} when unused):
##   id: String                      # registry key, snake_case, category-prefixed
##   name: String                    # ≤6 words; R1 (world deeds) or R2 (hearth deeds)
##   cat: String                     # CATEGORIES member
##   points: int                     # 0 (feats only) | 5 | 10 | 25 | 50
##   hidden: bool                    # true = unwritten row until earned (§6)
##   desc: String                    # plain UI voice, CONCRETE: exact numbers
##   lore: String                    # ≤20 words, register-tagged flavor
##   criteria: Dictionary            # one of:
##     {"kind":"counter", "event":String, "count":int, "filter":Dictionary}
##     {"kind":"flag",    "event":String, "filter":Dictionary}
##     {"kind":"set",     "event":String, "key":String, "needs":Array}  # distinct values
##     {"kind":"meta",    "needs":Array}                                # achievement ids
##   void_on: Dictionary             # {} or {"event":String, "filter":Dictionary,
##                                   #  "scope":"act"|"character"} — conduct deeds (§6.4):
##                                   # the matching event voids progress for the scope
##   reward: Dictionary              # {} or any of {"title":id, "mount":id, "item":id}
const DEFS: Dictionary = {
	"expl_all_zones": {
		"id": "expl_all_zones", "name": "All the Fog Allows",
		"cat": "exploration", "points": 50, "hidden": false,
		"desc": "Discover all 40 zones of Draconia.",
		"lore": "The map was drawn by men who turned back. You did not.",
		"criteria": {"kind": "counter", "event": "zone_discovered", "count": 40,
				"filter": {"distinct": "zone"}},
		"void_on": {}, "reward": {"title": "far_walked"},
	},
	"quests_incurious": {
		"id": "quests_incurious", "name": "The Incurious",
		"cat": "quests", "points": 25, "hidden": true,
		"desc": "Complete Act I without examining a single inscription stone.",
		"lore": "Old Marta's own discipline. The rarest kind of wisdom.",
		"criteria": {"kind": "flag", "event": "quest_completed",
				"filter": {"quest_id": "act1_finale"}},
		"void_on": {"event": "inscription_read", "filter": {}, "scope": "act"},
		"reward": {"title": "the_incurious"},
	},
	# … §10 registry (60 rows) + §5 metas + §6.3 generated survivor rows …
}

## §6.3 — build-time expansion: every StatusEffects/HiddenFX def declaring
## "survivor_title" contributes a hidden 10-pt general row keyed surv_<debuff_id>,
## criteria {"kind":"flag","event":"title_earned","filter":{"id": <survivor_title>}}.
static func all_defs() -> Dictionary:  # DEFS + generated rows, cached
	...
```

### 9.2 `scripts/achievements.gd` (autoload `Achievements`, group `"achievements"`)

```gdscript
extends Node
## THE DEED-BOOK engine — signal-fed, save-group-registered, account-ledgered.
## Autoload "Achievements"; _ready(): add_to_group("achievements"); _wire(); _load_ledger().

signal achievement_earned(id: String)                     # -> toast, panel refresh
signal progress_updated(id: String, value: int, target: int)

const LEDGER_PATH := "user://deedbook.json"

var _earned: Dictionary = {}        # id -> {date, char, class}   (account, §8)
var _points: int = 0                # account points
var _progress: Dictionary = {}      # id -> int | {set: {...}}    (per slot)
var _voided: Dictionary = {}        # id -> true                  (per scope, §6.4)

## ---- THE ONE PUBLIC API systems call (or are auto-wired to) ----
func event(name: String, payload: Dictionary = {}) -> void:
	for def: Dictionary in AchievementDefs.all_defs().values():
		if _earned.has(def["id"]) or _voided.has(def["id"]):
			continue
		_check_void(def, name, payload)      # conduct deeds first
		_advance(def, name, payload)         # counter/flag/set matching + filters
	_check_metas()                           # meta kind resolves off _earned

func grant(id: String) -> void:              # idempotent; the only earn path
	if _earned.has(id) or not AchievementDefs.all_defs().has(id):
		return
	var def: Dictionary = AchievementDefs.all_defs()[id]
	_earned[id] = {"date": _today(), "char": _player_name(), "class": _player_class()}
	_points += int(def["points"])
	_write_ledger()                          # atomic temp+rename, §8
	_route_reward(def["reward"])             # Titles.grant / MountSystem.teach /
	                                         # bag insert (innkeeper hold on full bag)
	achievement_earned.emit(id)              # HUD toast queue picks this up
	event("achievement_earned", {"id": id})  # metas may chain off it

## ---- wiring (deferred, defensive: every hookup checks the node exists) ----
func _wire() -> void:
	Quests.quest_completed.connect(func(qid: String) -> void:
			event("quest_completed", {"quest_id": qid}))
	TravelSystem.station_discovered.connect(func(sid: String) -> void:
			event("station_discovered", {"station_id": sid,
					"zone": TravelSystem.station_zone(sid)}))
	# Titles / PvpLadder / StatusEffects / MountSystem connect identically when present.

## ---- save contract (SaveSystem group pattern — per-slot block only) ----
func serialize() -> Dictionary:
	return {"progress": _progress.duplicate(true), "voided": _voided.keys()}
func deserialize(d: Dictionary) -> void:
	_progress = d.get("progress", {}) if d.get("progress") is Dictionary else {}
	_voided = {}
	for id: Variant in d.get("voided", []):
		_voided[str(id)] = true
```

`save_system.gd` additions (mirrors the quests precedent, no version bump):
`const ACHIEVEMENTS_SCRIPT := "res://scripts/achievements.gd"` · one
`_system_snapshot("achievements", ACHIEVEMENTS_SCRIPT)` row in `collect_state()` ·
one `_apply_system_state(...)` row in `apply_systems_state()`.

### 9.3 The event vocabulary (tracking hooks — implementation checklist)

| Event | Fired from (exact seam) | Payload keys | Feeds |
|---|---|---|---|
| `quest_completed` | `Quests.quest_completed` (auto-wired) | `quest_id` | counts, act flags, zone sets, event capstones |
| `daily_completed` | quests turn-in path, `repeatable=="daily"` | `quest_id` | A-11 |
| `zone_discovered` | `main.gd` first-entry banner flag (NARRATIVE_VOICE §4 — the same gate that writes the first-footfall journal) | `zone` | A-18/19/20 |
| `station_discovered` | `TravelSystem` (auto-wired) | `station_id`, `zone` | A-21/22 |
| `kill` | `enemy.gd::_die()` — one added line; family already resolved for kill XP | `type`, `family`, `rare_id`, `zone` | per-family counters, A-24 |
| `level_up` | `xp_system.gd` level grant | `level` | A-01/02 |
| `gold_changed` | `player.gd` gold setter | `gold` | A-03 |
| `equipment_changed` | `Inventory.equipment_changed` → rarity scan | `slots_rare_plus` | A-04 |
| `mount_taught` | `MountSystem.teach` | `mount_id`, `known_count` | A-05 |
| `skill_up` | `crafting.gd::_roll_skill_up` success | `prof`, `skill`, `rank` | A-34–37 |
| `crafted` | `crafting.gd::craft()` success | `recipe`, `prof`, `condition_met` | A-38/40 |
| `fish_caught` | riverline gather verb | `zone` | A-39 |
| `duel_resolved` | `PvpLadder.match_resolved` | `won`, `rated`, `rating` | A-42–45 |
| `rank_changed` | `PvpLadder.rank_changed` | `rank` | A-41/46 |
| `title_earned` | `Titles.title_earned` | `id` | survivor rows, raid/event mirrors |
| `standing_earned` | faction capstone chain flags (Quests, until rep ships) | `kingdom` | A-47–51 |
| `dungeon_cleared` / `raid_cleared` | instance end-boss death hook | `id`, `deaths`, `minutes` | A-26–33 |
| `inscription_read` | Examine on inscription interactables | `zone` | voids A-16 |
| `player_died` | `player.gd` death path | — | voids A-60 |
| `effect_survived` / `effect_cured` | `HiddenFX` expiry/cure | `id`, `method` | A-17, survivor rows |
| `secret` | bespoke world seams (13th row interact, TP evidence) | `id` | A-25, reserved secrets |

Anti-frustration note (BE CHEAP, also perf): `event()` iterates a pre-bucketed
`event -> [def ids]` index built once at load — kill spam costs a dictionary hit,
not a 70-row scan.

---

## 10. THE REGISTRY — 60 exemplar deeds

Format: **id suffix · Name · pts · criteria (desc, concrete) · lore line (register).**
🕯 = hidden. Reward column only where one exists. Names are lint-clean against the
NARRATIVE_VOICE banned lexicon; R1 names for the world's feats, R2 for the hearth's.

### GENERAL (7)

| # | Deed | pts | Do (desc) | Lore (register) | Reward |
|---|---|---|---|---|---|
| A-01 | **A Name on the Roll** | 10 | Reach level 10. | R2: "The road has learned your step. It keeps what it learns." | — |
| A-02 | **The Last Rung** | 25 | Reach level 60. | R1: "Sixty rungs, and the ladder ends at the lip of the Pit. It always did." | — |
| A-03 | **The Purse Survives** | 10 | Hold 1,000 gold at once. | R2: "Somewhere in Blestem, a clerk has noticed. Spend it warm." | — |
| A-04 | **Dressed Against the Weather** | 10 | Equip rare or better items in all 9 slots. | R2: "Blue head to boot. Your mother would want a portrait." | — |
| A-05 | **The Stable Fills** | 25 | Add 15 mounts to your stable. | R2: "Fifteen stalls, fifteen names, one carrot budget past saving." | title: the Well-Stabled |
| A-06 | 🕯 **Still Walking** | 25 | Survive a Hungering pull of 4+ stacks at 5% health or less. | R1: "Already collected, by every law the ledger knows. Why is it still walking." | title: Still Walking |
| A-07 | 🕯 **Copper-Blooded** | 10 | Let Copperbelly run its full course 3 times, uncured. | R2: "You never bought the cure. The wells respect that. Nothing else does." | title: Copper-Blooded |

*(§6.3's survivor hook generates the siblings — the Untreated, Mange-Proof, and every
future `survivor_title` — in this category, hidden, 10 pts each.)*

### QUESTS (10)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-08 | **Errands for the Hollow** | 10 | Complete 50 quests. | R2: "Fifty doors knocked. They open faster now." | — |
| A-09 | **Five Hundred Doors** | 25 | Complete 500 quests. | R1: "Five hundred errands, and the fog gave ground for none of them. You did them anyway." | — |
| A-10 | **The Chronicle Thickens** | 50 | Complete 1,500 quests. | R1: "No keeper now serving has done more. The journal is heavier than a sword." | — |
| A-11 | **Bread for the Day** | 10 | Complete 25 daily quests. | R2: "Same road, same errand, same thanks. That's not nothing. That's a living." | — |
| A-12 | **The Vein, Every Errand** | 10 | Complete every quest in the Iron Vein. | R1: "The bog-valley has no work left for you. It watches you leave with something like regret." | — |
| A-13 | **The Chronicle Entire** | 50 | Earn every zone's every-errand deed (all 40 zones). | R1: "Every door in Draconia, knocked. The chronicler runs out of ink before praise." | title: the Chronicler |
| A-14 | **"YOU ARE WEATHER"** | 10 | Complete Act I. | *(the stone's own epigraph — quoting it is an event; Acts II–V follow this pattern, 10 pts each, named at quest-batch time)* | — |
| A-15 | **"THE ENTRY CLOSES"** | 50 | Complete the main story. | R1: "The Pause holds. The bookmark keeps its page. The page, being a page, waits." | — |
| A-16 | 🕯 **The Incurious** | 25 | Complete Act I without examining a single inscription stone. | R2: "Old Marta's own discipline. The rarest kind of wisdom." | title: the Incurious |
| A-17 | 🕯 **A Debt Freely Given** | 25 | While Collected, cure it by giving gold freely to a beggar or the Last Hearth orphanage. | R2: "The game never told you it works. Neither does anyone in Anchorfall. Word of mouth carries it." | — |

### EXPLORATION (8)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-18 | **First Footfalls** | 5 | Discover 5 zones. | R2: "The border fog let you through five times. It was not being kind." | — |
| A-19 | **Half the Map From Memory** | 10 | Discover 20 zones. | R1: "Twenty lands, and the map's blank half still outweighs the drawn." | — |
| A-20 | **All the Fog Allows** | 50 | Discover all 40 zones. | R1: "The map was drawn by men who turned back. You did not." | title: the Far-Walked |
| A-21 | **Of the Four Roads** | 10 | Discover all four capital waystations. | R1: "Four capitals, four lamps, one rider they all now know by name." | title: of the Four Roads |
| A-22 | **Every Lamp on the Map** | 25 | Discover every waystation in the world. | R1: "Every lamp lit once by your passing. The coachmen have stopped asking where." | — |
| A-23 | **The Grey Crossing** | 10 | Ride the Grey Ferry to the second continent. | R1: "The light arrives tired at the far piers. So will you." | — |
| A-24 | **Sixteen Named Things** | 25 | Kill all 16 named rares. | R1: "Each had a name, a haunt, and a habit. You ended all three, sixteen times." | — |
| A-25 | 🕯 **The Thirteenth Row** | 10 | At Grave-Dim's deepest stage, stand where the grave-row that is not there would be. | R1: "You counted twelve rows going in. So does everyone, going in." | — |

### DUNGEONS & RAIDS (8)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-26 | **The Chamber Below Vetka** | 10 | Clear the Chamber Depths. | R1: "The walls down there were listening before the town had a name. They heard you leave." | — |
| A-27 | **Ten Deep Places, Settled** | 25 | Clear all 10 dungeons. | R1: "Every deep place has a floor. You have stood on all of them and come back up." | — |
| A-28 | **Pit-Breaker** | 25 | Clear The Killing Floors. | R1: "Valrom the Forged King is down, and the hammers of Sangeroasa missed one beat for him." | title: Pit-Breaker |
| A-29 | **Spirewalker** | 25 | Clear The Black Spire. | R1: "The windowless tower, climbed. Cazimir was in the walls. He is not now." | title: Spirewalker |
| A-30 | **The Bookmark** | 50 | Clear The Grave & the Bloodstone Pit. | R1: "You held the Pause the way Kriggar held it: a bookmark the stone tolerates." | title: the Bookmark |
| A-31 | **Of the Long Vigil** | 50 | Clear all three raids on one character. | R1: "Six hundred years of watch, and the last three watches were yours." | title: of the Long Vigil |
| A-32 | **No One Fed the Floor** | 25 | Clear The Killing Floors with zero deaths in the raid. | R2: "The drains under the grating ran dry all night. The house was furious." | — |
| A-33 | **The Quarter, Answered Quickly** | 10 | Clear the Riddler's Quarter in 45 minutes or less. | R2: "The doors tried their trick. You were already through them." | — |

### PROFESSIONS (7)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-34 | **A Trade in Hand** | 5 | Reach Sworn rank in any profession. | R2: "Hands stop being borrowed the day the work starts arguing back." | — |
| A-35 | **Sworn to the Work** | 10 | Reach Master rank in any profession. | R2: "The master made you watch, fetch, and fail first. It took." | — |
| A-36 | **Keeper of a Craft** | 25 | Reach Keeper rank in any profession. | R1: "Past this rank a trade stops being a trade and becomes a vigil. Yours now." | — |
| A-37 | **Two Trades, One Pair of Hands** | 50 | Reach Keeper rank in both primary professions. | R1: "Two vigils, one pair of hands. The hands have opinions about this arrangement of yours." | title: the Twice-Sworn |
| A-38 | **Borek's Pot** | 5 | Learn 20 Hearthcraft recipes. | R2: "He taught you stew by cooking it and saying nothing. Twenty dishes later, you heard him." | — |
| A-39 | **One Hundred Off the Line** | 5 | Catch 100 fish. | R2: "The rivers run red and the fish don't ask either. A hundred kept quiet with you." | — |
| A-40 | **Wet Ink, Right Weather** | 10 | Craft 25 recipes with their condition met. | R2: "Settled iron in the rain, bread at a true hearth. The trip always pays twice." | — |

### THE RECKONING FLOOR — PvP (6)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-41 | **One Lamp** | 5 | Enlist on the Accord Roll (rank 1). | R2: "Fourteen rungs. The top one keeps a lamp you cannot see. Start walking." | — |
| A-42 | **First Blood, Filed** | 5 | Win your first rated duel. | R2: "Your stake is filed. Your win is filed. Your grin is noted, and filed." | — |
| A-43 | **Bloodletter** | 25 | Win 100 rated duels. | R1: "A hundred rounds called on the red sand, and every one of them called for you." | title: Bloodletter |
| A-44 | **Ledger-Long** | 50 | Fight 1,000 duels, won or lost. | R2: "The Clerk respects attendance above talent. The Clerk has a column just for you." | title: Ledger-Long |
| A-45 | **The Flawless** | 25 | Win a match 2–0 without dropping below 90% health in either round. | R1: "The Floor takes its tithe from every match. From this one it took nothing at all." | title: the Flawless |
| A-46 | **Warden of the Pause** | 50 | Reach rank 14 on the Accord Roll. | R1: "One per season. The rank is a weight, and the lamp no one may see stays lit." | title: rank 14 (via the Roll) |

### REPUTATION (5)

*(standing = each kingdom's capstone chain flag until the faction system ships — the
MOUNTS.md gating precedent; criteria re-point to rep thresholds 1:1 when it does)*

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-47 | **The Queen's Grey, Given** | 10 | Earn Angel Wings' full standing. | R2: "Fielderine's stables give grey horses to people the crown owes. Ask what you're owed for." | — |
| A-48 | **Blooded on the Bloodroad** | 10 | Earn Sangeroasa's full standing. | R2: "The forge-city despises cowards who won't bleed in the open. You bled correctly." | — |
| A-49 | **A Name in the Lower Market** | 10 | Earn Blestem's full standing. | R2: "In the Listening City your good name is an asset. Someone is already pricing it." | — |
| A-50 | **Filed as Living** | 10 | Earn Black Night's full standing. | R2: "Name. Heartbeat. …You're certain? — stamped, at last, without the pause." | — |
| A-51 | **Four Banners, One Walker** | 25 | Earn all four kingdoms' full standing. | R1: "Four powers that manage the stone, not each other — and all four manage to trust you." | title: the Accord-Kept |

### WORLD EVENTS (6)

| # | Deed | pts | Do | Lore | Reward |
|---|---|---|---|---|---|
| A-52 | **Keeper of Kept Names** | 10 | Complete The Kept Names capstone. | R2: "A lantern with a name in it. Not yours. You carried it anyway. That is the whole festival." | title: Keeper of Kept Names |
| A-53 | **Emberkept** | 10 | Complete the Emberfall Vigil capstone. | R2: "The fire kept through the dark weeks, and you kept the fire." | title: Emberkept |
| A-54 | **The Proofed** | 10 | Complete The Proofing capstone. | R2: "The cellar tried you the way it tries the bread. You rose." | title: the Proofed |
| A-55 | **Thin-Walker** | 10 | Complete The Thinning capstone. | R1: "For thirteen nights the veil wore thin, and you walked its worn places and came home." | title: Thin-Walker |
| A-56 | **Count-Keeper** | 10 | Be present at the Turning of the Count bell. | R2: "One bell, once a year, and everyone quiet enough to hear the count continue." | title: Count-Keeper |
| A-57 | **The Kept Year** | 50 | Complete all 8 calendar-event capstones within one Draconian year. | R1: "Thaw to Long Dark, feast to vigil, no turn of the year unattended. The almanac is satisfied." | mount: **The Almanac Grey** |

### FEATS OF STRENGTH (3 · 0 points)

| # | Feat | Do | Lore |
|---|---|---|---|
| A-58 | **First Lamp** | Be first to clear a raid within its content-season window. | R1: "Someone had to carry the lamp in before there were footprints. It was you." *(mirrors the `first_lamp` title grant)* |
| A-59 | **The Untithed** | Finish an arena season in the top 0.5% of the Roll. | R1: "A season on the red sand and the Floor never took a drop. Professional respect." *(mirrors the seasonal title + Crimson Floor-Hound)* |
| A-60 | **The Long Way, Unburied** | Reach level 60 without dying. | R1: "Sixty levels of Draconia, and the ground never once got its turn. It is patient. It noticed." *(void_on: `player_died`, scope: character)* |

*(Reserved FoS rows, finalized by their owning design passes: the seven per-class
legendary-weapon completions — `legend_<class>`, MANDATES' "feat of strength" —
and `fos_warden_season`: hold rank 14 through a full season.)*

---

## 11. INTEGRATION CHECKLIST (implementation pass, in order)

1. **`achievement_defs.gd`** — registry §9.1 with the 60 rows + 10 metas; data only.
   Ship `tests/achievements_lint.py` in the same commit (Engineering Law; checks per §2.8)
   and wire it into the standard validator → backfill → re-verify loop.
2. **`achievements.gd`** — autoload + group; event bus, criteria kinds, void logic,
   account ledger read/write, reward routing (`Titles.grant` / `MountSystem.teach` /
   bag insert with innkeeper hold). SaveSystem: `ACHIEVEMENTS_SCRIPT` const + two rows.
3. **Hooks, cheapest first** — auto-wires (Quests, TravelSystem, Titles, PvpLadder,
   MountSystem, HiddenFX) then the one-line seams: `enemy.gd::_die` kill event,
   `main.gd` first-entry zone event, `crafting.gd` skill-up/craft events, `player.gd`
   gold/level/death events, inscription-examine void event.
4. **Toast** — the gold-bezel banner §7.1 on the HUD kit; queue; the lamp-glass sting
   (two notes; Sound Council review with the next audio batch).
5. **`deedbook_ui.gd`** — the panel §7.2 + character-sheet header button + hotkey Y.
6. **Title/mount/item rows** — 6 title_defs additions (§4.1), 2 MountDefs tints (§4.2),
   4 reward items (§4.3, ITEM_PROGRESSION budgets; sprites via the established
   pack-first + ComfyUI pipeline).
7. **Registry growth** — zone every-errand rows auto-derive from ZONE_QUEST_MATRIX at
   build time (like §6.3's survivor hook); act rows land with each act's quest batch;
   reserved secret/FoS ids fill in from their owning docs.
8. **QA** — headless asserts: fire each event synthetically, assert earn/void/points;
   screenshot QA of toast + panel in both capitals' lighting; ledger corruption test
   (truncate `deedbook.json`, assert clean degrade).

## 12. Mandate compliance (self-audit)

| Mandate | Where honored |
|---|---|
| WoW-style achievements: categories/points/metas/title+mount rewards/toast/account ledger | §3 categories · §2.2 points · §5 metas · §4 rewards · §7 toast · §8 ledger — the MANDATES row, complete |
| NO TRANSMOG / WYSIWYG | §4.3 — rewards are distinct real items; no cosmetic layer exists anywhere in the doc |
| GROUND MOUNTS ONLY | §4.2 — both reward mounts are horse-base ground stock, tier-scaling |
| CONCRETE TOOLTIPS | §2.3 — every `desc` states exact numbers; registers live only in `lore` |
| TONE LAW / NARRATIVE_VOICE | §10 — R1/R2 tagged lines, banned-lexicon-clean, the stone quoted only at act rows (quoting is an event) |
| Hidden debuffs celebrated, survivor feats | §6.3 auto-hook + A-06/A-07; villain-arc secrets §6.4 incl. the owner's named exemplar **The Incurious** (A-16) |
| Engineering Law (auto-QA + improvement loop) | §2.8 lint · §11.1/§11.8 tests · derived-row generation keeps the registry self-healing |
| BE CHEAP | 2 mounts = tints on the existing horse skeleton; toast/panel = restyled shipped chrome; event bus pre-bucketed (§9.3 note) |
| Save contract (group-serialize, no version bump) | §9.2 — quests/crafting/pvp precedent followed exactly; account ledger deliberately outside the slot save (§8) |
| Level cap 60 / classic pacing | A-02/A-10/A-44/A-57 thresholds sit on the 1,000-hour curve; nothing here trivializes the grind, everything memorializes it |
