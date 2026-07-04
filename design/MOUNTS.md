# RAVEN HOLLOW — MOUNT SYSTEM ("tons of mounts")
Design doc for the mount pillar: riding mechanics, the render approach for a mounted
32px Szadi rider, the stable/collection UI, save wiring, and **THE COLLECTION** —
30 lore-grounded mounts across every acquisition source, plus an honest asset plan.

**Grounded in (read before implementing):**
- `scripts/player.gd` — CharacterBody2D, `speed: 90.0` base, `velocity = input * speed *
  _speed_mult * sprint(1.55)`; 32×48 szadi frames via `SheetAnim.make_szadi_frames()`,
  `FEET_OFFSET = (0,-15)` (node pos = feet line), side frames face LEFT + `flip_h`;
  per-frame `ANCHORS` (PIL-measured hand/shoulder/off), weapon SHEATHED/DRAWN carry
  states (Z toggles, attacks auto-draw) — the mount layer composes with all of this.
- `scripts/sheet_anim.gd` — `SZADI_FRAME = 32×48`, `SZADI_DIR_ROW = {side:0, down:1, up:2}`;
  the mount sheet contract below reuses this row order.
- `scripts/items.gd` + `design/ITEM_PROGRESSION.md` — item dict shape + the extension-key
  layering pattern (`ilvl/req_level/set_id/value`); mounts are taught from `slot:"none"`
  items with an `effect: "mount:<id>"` hook. §7 vendor math (25–40g/hr at bracket 30)
  prices the gold sink. ITEM_PROGRESSION §6 explicitly reserves gold for "mounts-later" —
  this doc is that sink.
- `design/LOOT_TABLES.md` — mount drops ride the existing schema: `special: [{id, chance}]`
  rows on rare-spawn/boss tables; no new loot machinery.
- `design/COMBAT_PACING.md` — mob speeds 44–98 px/s; stalkers ~150. Mounted speed must
  outrun everything (that is the point of a mount) — tiers below clear the fastest stalker.
- `scripts/save_system.gd` — group-based `serialize()/deserialize()` contract (quests/
  crafting precedent §4/§5); MountSystem joins group `"mounts"` and rides the same rails.
- `WORLD_PLAN.md` + `_downloads/_design/CALENDAR_EVENTS.md` + `_lore_extract.txt` —
  zones, festivals, and canon fauna (the Sangeroasa Hunts: griffins, great elk,
  mountain-giants; obsidian wolves; war-dogs; bone-hounds; the Grey Ferry).
- `project.godot` — input map has no `mount` action yet; added below.

OWNER MANDATE: **tons of mounts** — a collection game in the WoW-Classic spirit
(40/60 speed gates, mounts as status, rare drops as legends), Draconia-canon sourced.

---

## 1. RIDING — THE CORE RULES

### 1.1 Speed tiers (classic 40/60 gates)

Riding is trained at **stablemasters** (new NPC archetype, §5). Two ranks:

| Rank | Level req | Cost | Mount speed | Effective px/s |
|---|---|---|---|---|
| — (unmounted) | — | — | — | 90 walk / 139 sprint |
| **Apprentice Riding** | 40 | **80 g** | **+60%** (tier-I mounts) | **144** |
| **Journeyman Riding** | 60 | **400 g** | **+100%** (tier-II mounts) | **180** |

- Tier-II mounts require Journeyman; a tier-II mount ridden with only Apprentice
  runs at tier-I speed (own the prestige early, earn the speed later — kinder than
  classic's hard gate, still preserves the 60 moment).
- At classic-tuned gold income (§7 of ITEM_PROGRESSION: ~25–40 g/hr at bracket 30),
  Apprentice + first horse (**100 g all-in**) is a saved-for milestone around 40, and
  Journeyman (**400 g + mount**) is the level-60 project. These are THE gold sinks.
- Speed math: mounted velocity = `_base_speed * MOUNT_MULT` (1.6 / 2.0). Gear
  `speed_pct`, sprint, and ability `_speed_mult` buffs do **not** stack on top —
  mounted speed is flat and readable (fastest enemy is a 150 px/s stalker; a tier-I
  mount escapes everything at 144 vs its non-sprint 90... barely — deliberate:
  tier-I outruns leashes, tier-II trivializes open-world travel).
- The 40-Second Rule survives: at 180 px/s the ~1,750 px engagement-anchor spacing
  reads every ~10–20 s. Mounted travel makes zones feel alive, not empty.

### 1.2 Mount / dismount

- **Hotkey `H`** (new input action `mount`, keyboard H — free in the current map;
  B/C/K/M/Z/Tab taken). Also a click target: the active-mount button on the HUD
  (small round icon by the player frame) and the Stable page (§5).
- **Mounting is a 1.5 s stationary channel** (progress bar over the player, the
  existing cast-bar visual): moving, taking damage, or casting cancels it.
- **Dismounting is instant**: press H again, or open a dialogue/vendor, or enter
  a no-mount area (dungeon interiors, building interiors, boss arenas).
- **Combat rules (classic spirit, action-RPG kindness):**
  - Cannot BEGIN mounting in combat — "in combat" = dealt/received damage within
    the last 5 s or a live `target` aggroed on you.
  - While mounted, abilities are locked… but an `attack` press **auto-dismounts
    and swings in the same input** (mirrors the weapon auto-draw precedent —
    no dead inputs, ever).
  - Taking a hit while mounted does NOT auto-dismount (classic law), but each hit
    rolls a **25% "spooked"**: instant dismount + 50% move speed for 3 s (the daze).
    Riding through a camp is a gamble, exactly as it was in 2005.
- **Weapon**: mounting force-sheathes (reuses `_toggle_sheathe`'s tween); the slung
  weapon stays visible on the rider's back — the carry system needs zero changes.
- **Zone restrictions**: `no_mount` flag on interior/dungeon zone defs; the Canal
  Skiff (§4.6) inverts this with a `zones_allowed` whitelist.
- **Death** dismounts. Mount "HP" does not exist — the mount is a movement state,
  not a pet (Rook Companion stays the only combat pet).

### 1.3 Mounts as items → collection

A mount enters the game as an **item** (exact `items.gd` shape — loot window,
rarity color, flavor text all free):

```gdscript
"reins_lowland_dun": {
    "id": "reins_lowland_dun", "name": "Reins: Lowland Dun", "slot": "none",
    "rarity": "common", "icon": "pixel:reins_lowland_dun",
    "stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
    "flavor": "Farm stock out of the Western Lowlands. Honest, mud-colored, alive.",
    "stackable": false, "effect": "mount:lowland_dun",
    "ilvl": 40, "req_level": 40, "set_id": "", "value": 5,  # buy 20g (value*4)
},
```

Right-click in the bag → the item is consumed, the mount id joins the **collection**
(`MountSystem.known`), a toast fires ("Lowland Dun added to your stable."). Already
known → the item refuses consumption ("You already keep this one."). Mount drops in
the loot window therefore read as rarity-colored `Reins:` / `Whistle:` / `Bone-Bridle:`
rows — a purple mount row in a raid loot window is the screenshot the system exists for.

---

## 2. RENDER APPROACH — THE MOUNTED SZADI RIDER

The rider stays the class's szadi sheet. The mount is an **under/over sprite pair**
on the existing Player node — no new scene, no rig change, composes with the weapon
anchor system.

### 2.1 Node structure

```
Player (CharacterBody2D, node pos = FEET line — unchanged)
├── MountBack   (AnimatedSprite2D, NEW)   z: drawn BEFORE _sprite (behind rider)
├── Sprite      (_sprite, existing rider)  offset lifted by saddle_offset while mounted
│   ├── Weapon  (existing — force-sheathed while mounted)
│   └── Shield  (existing — hidden while mounted)
└── MountFront  (Sprite2D, NEW, optional)  z: drawn AFTER _sprite (near-side saddle/neck
                                           pixels occluding the rider's legs)
```

- `MountBack.offset` puts the mount's feet on the node pos (its own FEET_OFFSET,
  measured per sheet like the szadi `-15`). The mount owns the ground shadow
  (bigger ellipse, baked into the sheet or the existing procedural shadow scaled ×1.6).
- `_sprite.offset` shifts from `FEET_OFFSET` to `FEET_OFFSET + saddle_offset`
  (per-mount, typically `(0,-14)` — the rider sits at the mount's back line).
- **The two-layer trick** solves side-view occlusion at 32px: `MountBack` holds the
  full animal; `MountFront` holds ONLY the near-side pixels (saddle skirt, near
  shoulder, mane line — a ~10×14 px crop per frame) so the rider's legs read as
  *behind* them. Down-facing: rider fully above (front overlay empty). Up-facing:
  rider partially hidden by the head/neck via the overlay. This is exactly the
  weapon-behind-body trick already shipped, applied to a bigger sprite.
- Rider animation while mounted: **`idle_<dir>` frame 0, frozen** + a per-mount-frame
  **bob table** (±1 px Y, same pattern as `ANCHORS` — 6 ints per facing, measured
  once per mount skeleton, shared across re-tints). No new rider frames needed —
  the szadi idle pose with legs occluded by the saddle line reads as seated at 32px.
  (Verified approach: the LPC riding convention does the same — a seated-legs
  overlay is a v2 polish option, not a launch need.)
- Facing: mount sheets follow the szadi convention — **side row faces LEFT**,
  `flip_h` both mount sprites when facing right. `SZADI_DIR_ROW` order reused.

### 2.2 Mount sheet contract (`assets/art/mounts/`)

```
<mount_id>.png        — REQUIRED. Grid: 48×48 frames (64×48 for large: elk, rook,
                        pit-brute), 3 rows in SZADI_DIR_ROW order (side/down/up),
                        10 cols: 0–3 idle (6 fps), 4–9 run (12 fps). → 480×144 px.
<mount_id>_front.png  — OPTIONAL. Same grid; near-side overlay pixels only.
                        Missing file = no overlay (fine for down-heavy mounts).
```

`SheetAnim.make_mount_frames(path)` — a sibling of `make_szadi_frames()` cutting
this grid into `idle_side/down/up` + `run_side/down/up`. Re-tints (the wolf family)
are palette swaps through the existing `palette_swap.gdshader` — one skeleton,
many mounts, honest about art cost.

**Registry** (pure data, `class_defs.gd` pattern):

```gdscript
# scripts/mount_defs.gd
class_name MountDefs
const MOUNTS := {
    "lowland_dun": {
        "id": "lowland_dun", "name": "Lowland Dun", "tier": 1,
        "sheet": "res://assets/art/mounts/horse_base.png", "tint": "dun",
        "front": true, "frame": Vector2i(48, 48),
        "feet_offset": Vector2(0, -12), "saddle_offset": Vector2(0, -14),
        "bob": {"side": [0,-1,0,0,-1,0], "down": [0,-1,0,0,-1,0], "up": [0,-1,0,0,-1,0]},
        "source": "vendor", "zone": "western_lowlands",
        "lore": "Farm stock out of the Western Lowlands. Honest, mud-colored, alive.",
    },
    # ... §4 collection ...
}
```

### 2.3 Player integration (surgical)

- `player.gd` gains: `var mount_id: String = ""` (active), `var _mounted: bool`,
  `_mount_cast_left: float`, the two mount sprite refs, and a `MOUNT_MULT` const.
- `_physics_process`: when `_mounted`, `velocity = input * _base_speed * mult`
  (bypasses `speed`, `_speed_mult`, sprint); `_play_anim` drives the mount sprites
  instead of walk/idle on the rider; collision `Feet` circle stays r=6 (a bigger
  radius strands players in doorways — the mount is visual, the hitbox is the rider).
- `take_damage()`: one added line — the 25% spooked roll while `_mounted`.
- Camera/culling/weather: nothing changes — same node, same position semantics.

---

## 3. SPEED TIERS IN THE WORLD (what the player feels)

| State | px/s | Crossing a 256×192-tile zone (8192 px) |
|---|---|---|
| Walk | 90 | ~91 s |
| Sprint (held) | 139 | ~59 s |
| Tier-I mount (L40) | 144 | ~57 s, sustained, hands-free |
| Tier-II mount (L60) | 180 | ~46 s |
| Waystation hop | — | instant (coin cost, discovered routes only) |

Mounts do not compete with waystations — waystations skip known space, mounts make
unknown space traversable. Classic got this exactly right; we keep the division.

---

## 4. THE COLLECTION — 30 MOUNTS

Rarity = the reins-item rarity (loot-window color). Tier = speed rank (§1.1).
Sources: **V**endor · **R**ep (faction standing — planned system; until it ships,
gated on the faction's capstone quest-chain flag via `Quests`) · **D**rop ·
**Q**uest · **E**vent · **T**ame (rare-spawn interaction, §4.5).

### 4.1 Kingdom horses — the honest tier (Angel Wings / human West)

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 1 | **Lowland Dun** | V | I | common | Angel Wings stablemaster, 20 g | "Farm stock out of the Western Lowlands. Honest, mud-colored, alive." |
| 2 | **Vetka Mudplodder** | Q | I | uncommon | "The Long Way Home" — return to Vetka at 40+; Old Marta keeps your first horse | "She remembers you when you were slower. She is polite about it." |
| 3 | **Riverfork Courser** | V | I | uncommon | Riverfork toll-post stablemaster, 35 g | "Bred to outrun the toll. The toll was never coin." |
| 4 | **Queen's Grey** | R | II | rare | Angel Wings standing: complete the Act II chain; then 90 g | "Fielderine's stables give grey horses to people the crown owes. Ask what you're owed for." |
| 5 | **Famine-Cart Draft** | D | I | uncommon | Famine Fields cult ambusher tables, `special` 0.4% | "It pulled a cart of grain past starving villages. It did not choose the route." |

### 4.2 The South — Varcolaci wolves, hounds & the war-road (Sangeroasa)

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 6 | **Bloodroad Warhorse** | V | I | uncommon | Bloodroad toll-fort stablemaster, 45 g | "Convoy stock. Flinches at nothing except a count of three." |
| 7 | **Convoy-Breaker** | R | II | rare | Sangeroasa standing (Act V chain) + 120 g | "Barded in basaltfang plate. The ledger line for the barding reads 'collected'." |
| 8 | **Obsidian Dire-Wolf** | R | II | rare | Basaltfang hunt-chain capstone ("run with the packs") + 120 g | "The packs of Basaltfang judge a rider by one measure: whether the wolf agrees to be ridden." |
| 9 | **Ash-Hound** | D | I | uncommon | Ashvents slag-walker/ash-hound tables, `special` 0.3% | "It walks the warm ground without reading it. Envy that." |
| 10 | **Forge-Hound** | Q | II | rare | Sangeroasa forge-rows questline (feed it at every hammer-rest) | "Raised under the hammers. When they all stop, it stops. Count with it." |
| 11 | **Valrom's Pit-Brute** | D | II | **epic** | **The Killing Floors raid** — Valrom the Forged King, `special` 2% | "It fought in the Debt Pit and was never once entered in the ledger. Valrom respected that too much to file it." |

### 4.3 The East — Strigoi night-stock (Blestem)

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 12 | **The Unhitched** | R | II | rare | Blestem standing (Act IV chain) + 120 g | "A night-coach horse that outlived its coach, its driver, and its route. It still stops at every door on it." |
| 13 | **Riddler's Walker** | D | II | **epic** | Riddler's Quarter dungeon end boss, `special` 3% | "However you approach it, you are approaching it from behind. Mount quickly." |
| 14 | **Lichen-Pale Colt** | D | I | rare | Lichenreach cave-strigoi lord (rare-elite), `special` 5% | "Foaled in the dark, lit from inside. It has never needed a lantern. Neither will you." |

### 4.4 The North — bone, thread & the pale rows (Black Night / Gravemark)

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 15 | **Gravemark Bone-Steed** | D | I | rare | Gravemark skeleton-warband rare-elite, `special` 5% (bone-bridle item) | "Raised from the kerb-rows. Some assembly was required. Not all of it is horse." |
| 16 | **Pale Mare of the Twelfth Row** | R | II | rare | Black Night standing (Act III chain) + 120 g | "Thread-driven. When you dismount she stands utterly still, facing the Pit, until you need her." |
| 17 | **Thread-Silver Stallion** | D | II | **epic** | **The Grave & Bloodstone Pit raid**, Council of Six wing, `special` 2% | "Blue filament runs where the veins were. It is not cold to the touch. That is the unsettling part." |
| 18 | **Snow-Wolf of the Threadlands** | T | I | rare | Threadlands rare-spawn tame (approach slow, unmounted, meat in bag) | "The pack left it behind for standing still too long. It listens less than the others. Barely." |

### 4.5 Wild tames — the Sangeroasa Hunts made personal

Canon megafauna (lore bible: "griffins riding the thermals, great elk the size of
cottages, mountain-giants"). Tames are **rare-spawn interactions**, not combat: find
the spawn (shared rare-spawn plumbing), approach unmounted with the bait item, channel
6 s. Fail states (spooked, wrong bait) put the spawn back on its timer. Pure classic
rare-camp gameplay.

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 19 | **Great Elk of the Hunts** | T | II | **epic** | Basaltfang rare spawn (~6 h timer), bait: Gift-fed grain | "Elk the size of cottages move through the fog like grey ships. This one consented to a passenger. Once." |
| 20 | **Fogship Doe** | T | I | rare | Grey Marches rare spawn, bait: last green browse | "She walks the dying forest like it is still green. For the length of the ride, you almost believe her." |
| 21 | **Blood-Fattened Boar** | T | I | uncommon | The Gift rare spawn, bait: anything — it is not picky | "The harvest is red and good and so is he. Do not ask the furrows what he eats." |
| 22 | **Bog-Ox of the Iron Vein** | T | I | uncommon | Iron Vein rare spawn, bait: river-reed bundle | "It has stood in the metallic river its whole life and holds no opinion about the color." |

### 4.6 The Collector's Coast — Continent 2 (level 60 stock)

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| 23 | **Canal Skiff** | Q | II* | rare | Greyhollow questline "Poling the Ledger Route" | "A flat-bottomed skiff and a black pole. In Greyhollow this IS a horse." *Whitelist mount: usable only in canal/flooded zones (27–31, 38); on land it packs onto your back (dismount).* |
| 24 | **Ledger-Brass Courser** | D | II | rare | Ledger Roads collection-agent tables, `special` 0.5% | "Its shoes are stamped with serial numbers. It has been repossessed four times. It always comes back." |
| 25 | **The Collected Horse** | D | II | **epic** | Finalized Fields grave-warden rare-elite, `special` 3% | "Marked collected. Filed. Closed. It is still walking. Someone in the Archive is very upset about this." |
| 26 | **Morven Grey** | R | II | rare | Morven Reach standing (safehouse chain) + 150 g | "Trained to stand in gaslight without casting a shadow. Do not ask the trainers how." |

### 4.7 Festival mounts — one per calendar beat (CALENDAR_EVENTS.md)

Event mounts are **token purchases** from the festival vendor (the token loop each
festival already defines) — earnable in one festival window played dailies-style.
They scale with your riding rank (tier I/II automatically) — festival prestige
should never rot.

| # | Mount | Festival | Rarity | Lore line |
|---|---|---|---|---|
| 27 | **The Kept-Name Lantern Mare** | The Kept Names (Jan–Feb) | rare | "A lantern hangs at her throat with a name in it. Not hers. She carries it anyway. That is the whole festival." |
| 28 | **Proofing-Cellar Ram** | The Proofing (Sep–Oct, Bent Oar) | rare | "It has carried worse than you out of that cellar, in worse condition, faster." |
| 29 | **The Thinning Mare** | The Thinning (Oct 18–31) | **epic**, event-boss drop 5% | "During the Thinning she is entirely visible. The rest of the year, check the stable anyway." |
| 30 | **Winter Vigil Elk** | The Long Vigil Feast (Dec–Jan) | rare | "Antlers hung with kept-flame lamps. It walks at feast-pace. Nothing you do will hurry it. (Tier speed unaffected — it merely disapproves.)" |

### 4.8 Class prestige — the Rookwarden's due

| # | Mount | Src | Tier | Rarity | Acquisition | Lore line |
|---|---|---|---|---|---|---|
| — | **The Gallows Rook** | Q | II | **legendary** | Rookwarden-only, level 60 class questline ("One Warden a Generation") | "The rooks choose one warden a generation. At sixty, the wardens learn what the rooks ride. It is rooks. It was always going to be rooks." — a giant rook; it *hop-glides* (ground mount, classic law: no flight; the run anim is a low wing-assisted lope). |

Count: **30 + 1 class-exclusive**. Rarity spread: 1 common, 7 uncommon, 15 rare,
6 epic, 1 legendary — greens are the on-ramp, blues are the collection body, purples
are stories, the orange is a class identity. Every source type in the game feeds it:
5 vendor, 6 rep, 9 drop (2 raid), 4 quest, 4 event, 5 tame.

---

## 5. STABLEMASTERS & THE STABLE PAGE (collection UI)

### 5.1 Stablemasters (NPCs)

One per capital + the Bent Oar (hub). They: train riding ranks (§1.1), sell their
kingdom's vendor mounts, and open the Stable page. Reuse the vendor/dialogue plumbing;
the stable prompt is one extra dialogue option ("See the stalls.").

### 5.2 The Stable page

New tab in the character-sheet cluster (hotkey **Shift+H**, and a tab button beside
Character/Spellbook — the ornate-UI kit already paginates):

- **Grid of stalls**: one cell per KNOWN mount (portrait crop = idle_down frame 0),
  rarity-colored border (reuses `Items.rarity_color()`), name + tier pips (▮ / ▮▮).
- **Unknown mounts show as silhouettes** with their source line ("Reins: sold in
  Riverfork", "Drop: the Killing Floors") — the collection is a visible checklist;
  silhouettes are the want-engine. Event/tame hints stay vague ("Something in the
  Threadlands consents, rarely.").
- Click a stall → detail pane: full lore line, source, **Set Active** button.
  Active mount gets the saddle icon; H summons the active mount.
- Counter header: "Stable: 11 / 31". That number is the whole meta-game.
- Filter row: All · Horses · Wolves · Wild · Ceremonial (festival) · Peculiar (skiff, rook, bone).

### 5.3 Save

`MountSystem` (autoload or group-node) joins group `"mounts"` per the SaveSystem
§4/§5 serialize contract — zero changes to `save_system.gd`:

```gdscript
func serialize() -> Dictionary:
    return {"known": known.duplicate(), "active": active_id, "riding_rank": riding_rank}
func deserialize(d: Dictionary) -> void:
    known = ...  # defensive: drop unknown ids with a warning (db-patch safe)
```

Reins items in bags serialize as normal items (already handled). Unknown mount ids
on load degrade with a warning, matching the load-is-defensive house rule.

---

## 6. ACQUISITION PACING (the classic feel, in numbers)

| Source | Expected time to acquire | Tuning hook |
|---|---|---|
| Vendor horse | the moment you have the gold | price (§1.1) |
| Rep mount | the act's capstone chain (~the act) + gold | quest flag |
| Rare-elite `special` 3–5% | ~20–35 kills on a camped spawn — an evening or three | `special.chance` |
| Trash-table `special` 0.3–0.5% | ~200–300 kills — a farm project with a jackpot moment | `special.chance` |
| Raid `special` 2–3% | months of weekly clears — the server-story mounts | `special.chance` |
| Tame | rare-spawn camping + one 6 s channel — patience, not power | spawn timer |
| Festival | one festival window of token dailies | token price |

Loot-window presentation: a mount row is always the TOP row of its window (above
even rarity sorting) with a small saddle glyph — the one time sorting bends, because
the mount drop IS the event.

---

## 7. ASSET PLAN — honest audit (what exists on disk today)

### 7.1 HAVE (verified in `_downloads/`)

| Asset | Location / spec | Covers |
|---|---|---|
| **Update_Canines wolves** | `_downloads/monster_packs_research/Update_Canines/extracted/Canines/` — **4 tints shipped** (Black/Gray/Brown/White), Idle 192×32 (6×32×32), Run 192×64, Attack/Hit/Death + FX | The entire wolf/hound family: Obsidian Dire-Wolf (black), Ash-Hound (gray), Forge-Hound (brown + ember tint), Snow-Wolf (white), Pit-Brute (black, scaled). **Caveat, honestly:** side-view only, and 32×32 is *enemy* scale — a ridden dire-wolf needs a **48×32 "dire" body** or the 32×48 rider dwarfs it. Plan: ComfyUI img2img upsize pass using the Canine sheets as structure reference (§7.3), keeping the pack's silhouette language. Down/up rows likewise generated (side row = pack art re-tinted). |
| **LPC Animals 2022** | `_downloads/lpc_animals_probe/lpc2022/` — deer bucks/does (256×384, 64×64 LPC 4-dir layout!), bears, foxes + farm set (cow/pig/sheep/chicken walk cycles) | **Elk mounts** (Great Elk, Fogship Doe, Winter Vigil Elk = buck/doe re-scales + antler dressing), **Bog-Ox** (cow re-tint), **Proofing Ram** (sheep + horn edit), **Blood-Fattened Boar** (wild_boar.zip in same folder). LPC layout ≠ szadi contract — needs a one-time re-cut into the §2.2 grid + a Graveyard-Keeper palette pass (`PALETTE_RECOLOR_GUIDE.md` ships in-repo). **License note:** LPC is CC-BY-SA/GPL — additions go in `CREDITS-LPC.md` (already established practice). |
| Existing wolf enemy sheets | `assets/art/enemies/wolf_idle/run.png` (32×32) | Scale/style yardstick only. |

### 7.2 ACQUIRE (nothing rideable-horse-shaped exists on disk — confirmed)

The downloads hold **zero horse art** (probe verified: LPC subset has deer/bears/
farm animals; no horse sheet anywhere in `_downloads/`). The horse base is the
single biggest asset gap and it underpins 14 of 31 mounts. Candidates, in order:

1. **LPC Horses (bluecarrot16, OpenGameArt)** — free, CC-BY-SA, 4-direction
   walk/gallop, multiple coat colors, and a matching *rider overlay* convention.
   Best structural fit; needs the same LPC→szadi re-cut + GK-palette pass as the elk.
2. **itch.io top-down horse packs** (search: "horse 32x32 top down", "pixel horse
   spritesheet") — evaluate against the Szadi/Cainos 32px look before buying;
   the pack must have 3-or-4-direction locomotion, not platformer side-scroll.
   (Sunnyside World by Danieldiggle is a known pack containing a rideable horse —
   style is brighter than GK palette; verify with a re-tint test before committing.)
3. **Fallback**: full ComfyUI generation of the horse base (§7.3) — viable but a
   horse gallop cycle is the hardest thing on this list to generate cleanly;
   prefer editing real animation frames.

One **horse base skeleton** (48×48, §2.2 grid) + the palette-swap shader yields the
whole horse family: Dun/Courser/Warhorse/Grey/Draft/coach-black/pale-mare are tints;
Bone-Steed, Thread-Silver, Thinning Mare, Collected Horse are **derived skins**
(§7.3) on the same frames — one skeleton, 14 mounts. That is the "tons of mounts"
budget trick, and it is exactly how classic did it.

### 7.3 GENERATE (ComfyUI — SDXL + Pixel Art XL LoRA, pipeline proven in-repo)

For sprites the packs cannot supply. Method per the established sprite pipeline:
generate large, img2img with the base sheet as structure reference, downscale to
grid, hand-cleanup frames in Aseprite. Per-mount:

| Sprite | Base reference | Notes |
|---|---|---|
| Dire-wolf 48×32 body (side) + down/up rows | Canine sheets | Keeps pack silhouette; 3 tints ride the shader |
| Bone-Steed skin | horse base frames | strip to bone palette; thread of exposed kerb-stone glyphs |
| Thread-Silver / Pale Mare glow | horse base | emissive blue filament pass (second texture, additive) |
| Thinning Mare spectral | horse base | alpha-ghost + desaturate — mostly shader, minor art |
| **The Gallows Rook** | none (new) | 64×48; hop-glide cycle, 6 frames; the one truly bespoke sheet |
| **Canal Skiff** | none (new) | 64×32; rider STANDS (no saddle offset — pole anchor reuses the weapon `staff` crop!); water-only simplifies to side+down |
| Front overlays (`_front.png`) | each base | small crops, fast; horse + wolf + elk = 3 overlays cover 26 mounts |

### 7.4 Icon plan

Every reins item needs an `IconsPixel.REGISTRY` cell (icon id == item id law).
Shikashi sheets have saddle/rope/animal-adjacent cells — PIL-verify per the
crafting.gd integration precedent; generate the misses (rook, skiff) with the
icon-scale ComfyUI flow.

---

## 8. INTEGRATION CHECKLIST (implementation pass, in order)

1. `project.godot` — add `mount` (H) input action.
2. `scripts/mount_defs.gd` — registry (§2.2) with the 31 entries; data only.
3. `scripts/sheet_anim.gd` — `make_mount_frames()` (§2.2 grid cutter).
4. `scripts/mount_system.gd` — autoload: `known/active_id/riding_rank`,
   `teach(id)`, `set_active(id)`, group `"mounts"` serialize contract (§5.3).
5. `scripts/player.gd` — mount sprites + mounted movement branch + 1.5 s channel +
   spooked roll + auto-dismount-attack (§1.2, §2.3). Biggest single diff; ~150 lines.
6. `scripts/items.gd` — reins items (one per §4 mount); `effect "mount:*"` routed
   to `MountSystem.teach` from the bag-use path.
7. Loot tables — `special` rows per §4 tables; festival vendors per CALENDAR_EVENTS
   token loops; tame interactables on the rare-spawn plumbing (§4.5).
8. Stable UI — `scripts/stable_ui.gd` on the ornate-UI kit (§5.2); stablemaster
   NPCs in the 4 capitals + Bent Oar.
9. QA — `RH_FACE`-style headless screenshots of all 3 facings × mounted/unmounted ×
   3 body skeletons (horse/wolf/elk); verify saddle offsets and front-overlay
   occlusion per facing before authoring the remaining tints.

**Demo-scope note:** riding gates at 40 and the demo cap is 10 (`XPSystem.MAX_LEVEL`) —
so the demo ships steps 1–5 dark, plus ONE dev-flag mount (Lowland Dun) for
screenshot/trailer use. The collection content lands with the leveling arms; nothing
here blocks on it.
