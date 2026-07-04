# LOOT WINDOW — WoW-Style Corpse Looting UX
Raven Hollow (Draconia canon) · 640x360 design space · implementable spec, grounded in the shipped code.

> OWNER MANDATE: when a creature dies the player **sees** the loot list — rarity-colored
> names, click to take — not silent auto-pickup. Item progression in WoW's spirit:
> the loot window is where rarity tiers become *visible* and acquisition feels earned.

---

## 0. Current state (what this replaces)

| Today | Where |
|---|---|
| Kill → drops silently teleport into the bag | `enemy.gd:476-491` `_grant_kill_rewards()` calls `Crafting.drop_for_kill(inv, type_name)` (`crafting.gd:700`) which rolls **and grants** in one step, then fires a `show_toast("+ Wolf Pelt")` on the crafting UI |
| Corpse plays `death` anim → smoke poof → 0.4 s alpha fade → `queue_free()` | `enemy.gd:494-505` `_on_anim_finished()` |
| No gold drops at all (player has a purse: `player.gd:178` `var gold: int = 0`, already saved) | — |
| Full bag on drop = item silently lost ("acceptable demo behavior") | `crafting.gd:697-707` |

The pieces we keep: `Crafting.roll_drops()` (`crafting.gd:684`, **pure roll, no inventory**
— exactly what a loot container needs), `Crafting.grant()` (`crafting.gd:495`, stack-merging
bag insert), `Crafting.get_item()` (resolves every item id in the game), rarity colors
(`ItemTooltip.rarity_color`, `item_tooltip.gd:175`), and the whole gold-bezel panel kit.

---

## 1. Player experience (the WoW loop)

1. **Kill payoff.** Enemy dies, death anim plays fully. XP grant and quest `report_kill`
   fire exactly as today (`enemy.gd:_die()`). The loot roll happens at death but nothing
   enters the bag.
2. **Corpse sparkle.** If the roll produced items or gold, the corpse **stays** (last
   death frame) and emits slow gold glints — the same `_make_gold_glints` recipe the
   legendary chest uses in `player.gd` (~line 1362), `CRIT_GOLD Color(1.0, 0.8, 0.3)`.
   If the best drop is **rare or better**, the glint color is that rarity's color
   instead — a readable "ooh" moment from across the screen. Empty roll → today's
   smoke + fade, unchanged.
3. **Approach.** Within `LOOT_RANGE` (30 px, same scale as the 28 px NPC interact claim
   in `main.gd:563`) the bottom-center world prompt (main.gd `_world_prompt`,
   `main.gd:338-374`) reads `E  Loot Graveyard Skeleton`. NPCs outrank corpses,
   corpses outrank crafting stations (see §6.2).
4. **Open.** `[E]` (the existing `interact` action, physical `E` — project.godot) or
   **right-click** the corpse opens a compact loot panel anchored beside the corpse.
   Combat is not locked; the panel is glanceable, not modal.
5. **Take.** Gold line auto-reads at top; click any row to take that item into the bag
   (rarity rim flashes, row disappears, remaining rows slide up). **Take All** button —
   or **press E a second time** — loots everything and closes. Esc closes without taking.
6. **Cleanup.** Emptied corpse smokes and fades (existing `_on_anim_finished` tail).
   Unlooted corpses persist 90 s, blinking for the last 10, then despawn with loot lost —
   WoW-style "go back for your loot" pressure without a permanent litter problem.

---

## 2. Visual spec — panel

All values in the 640x360 design space (`window/stretch/scale_mode="integer"`). Every
color below is an **existing constant** — copy them verbatim so the panel is pixel-kin
to the bag, HUD and tooltip.

### 2.1 Shared palette (sources: hud.gd:31-48, bag_ui.gd:41-47, item_tooltip.gd:11-31)

| Constant | Value | Use here |
|---|---|---|
| `GOLD` | `Color(0.85, 0.68, 0.35)` | title, gold amount, Take All text, keybind caption |
| `PARCHMENT` | `Color(0.87, 0.82, 0.72)` | stack counts, hints |
| `HOSTILE_RED` | `Color(0.85, 0.25, 0.2)` | "Bag is full" flash |
| `BOX_BG` | `Color(0.09, 0.07, 0.06, 0.96)` | panel dark fill |
| `BOX_BORDER` | `Color(0.45, 0.33, 0.18)` | 1 px inner borders |
| `OUTLINE_DARK` | `Color(0.08, 0.05, 0.03)` | all label outlines (size 2) |
| `FRAME_TINT` | `Color(0.55, 0.45, 0.38)` | 9-patch rim modulate |
| `SLOT_BG` | `Color(0.055, 0.045, 0.035, 0.95)` | row background |
| `SLOT_BORDER` | `Color(0.30, 0.22, 0.12)` | row border, normal |
| `SLOT_BORDER_HOVER` | `Color(0.62, 0.48, 0.26)` | row border, hover / pad-highlight |
| rarity colors | `ItemTooltip.rarity_color(rarity)` | item name text + icon rim: common `(0.62,0.62,0.62)` · uncommon `(0.35,0.75,0.35)` · rare `(0.3,0.5,0.9)` · epic `(0.62,0.35,0.85)` · legendary `(1.0,0.55,0.1)` |

Font: `res://assets/fonts/alagard.ttf` everywhere (preload, same as every UI file).

### 2.2 Panel construction (the bag_ui.gd recipe, verbatim)

Exactly the `bag_ui.gd:_build_panel()` layering:
1. Root `Control` (`MOUSE_FILTER_STOP`), sized `PANEL_W x panel_h`.
2. `Panel` "Fill" inset `(3, 3)`, size `(PANEL_W-6, panel_h-6)`, `StyleBoxFlat`
   bg `BOX_BG`, no border, no corner radius.
3. `NinePatchRect` "Frame": `res://assets/art/ui/panel_brown.png`, `draw_center = false`,
   all `patch_margin` = 10, `modulate = FRAME_TINT`, full-rect anchors.
4. Open/close animation: the bag's tween — scale from `0.88` + alpha from `0.0`,
   `0.16 s TRANS_BACK / EASE_OUT` scale, `0.12 s` alpha (`bag_ui.gd:186-193`).
   `pivot_offset` = panel center-left (it grows out of the corpse side).

### 2.3 Geometry constants

```gdscript
const PANEL_W: float = 128.0      # fits "Skeleton Warrior" + 5-row lists
const HEADER_H: float = 18.0      # title strip
const ROW_H: float = 22.0
const ROW_GAP: float = 2.0
const ROW_PAD_X: float = 7.0      # rows inset from panel edge (clear of the rim)
const ICON: float = 18.0          # item icon square inside a row
const TAKE_ALL_H: float = 16.0
const BOT_PAD: float = 8.0
const MAX_ROWS: int = 6           # gold line + 5 items; current tables max at 3+gold
# panel_h = HEADER_H + n_rows*(ROW_H+ROW_GAP) + TAKE_ALL_H + BOT_PAD  (dynamic)
```

With today's biggest drop (bear: recipe + 2 pelts + gold = 4 rows) the panel is
128 x 122 px — under a third of the 360 px height. No scrolling needed; if a future
table exceeds `MAX_ROWS`, overflow rows appear as the list drains (WoW pages; we drain).

### 2.4 Header

- `Label`, Alagard **10**, `GOLD`, outline `OUTLINE_DARK` size 2, centered,
  `clip_text + OVERRUN_TRIM_ELLIPSIS` (the hud.gd `_t_name` treatment).
- Text = the corpse's `display_name` ("Graveyard Skeleton"). Corpse name in gold —
  the panel is treasure now, not a threat; hostile red stays on living nameplates.
- Position `(0, 5)`, size `(PANEL_W, 12)`.

### 2.5 Item row (one per drop)

Node recipe mirrors a bag slot (`bag_ui.gd:_build_slot`) stretched into a row:

```
Row (Panel, MOUSE_FILTER_STOP, ROW_PAD_X..PANEL_W-ROW_PAD_X wide, ROW_H tall)
 |- StyleBoxFlat: bg SLOT_BG, border 1 px SLOT_BORDER (hover: SLOT_BORDER_HOVER)
 |- RarityRim (Panel, IGNORE) at (2,2) size (ICON, ICON): draw_center=false,
 |     1 px border = ItemTooltip.rarity_color(item.rarity)
 |- Icon (TextureRect, IGNORE) at (3,3) size (ICON-2, ICON-2):
 |     STRETCH_SCALE + EXPAND_IGNORE_SIZE + TEXTURE_FILTER_NEAREST
 |     texture resolved EXACTLY like bag_ui._icon_for(): "pixel:<id>" ->
 |     IconsPixel.get_tex, fallback Crafting.icon_texture (crafting.gd:733)
 |- Name (Label, IGNORE) at (ICON+7, 0) size (PANEL_W-ROW_PAD_X*2-ICON-9, ROW_H):
 |     Alagard 9, font_color = ItemTooltip.rarity_color(item.rarity),
 |     outline OUTLINE_DARK size 2, VALIGN center (y lift -1 for Alagard ascent),
 |     clip_text + TRIM_ELLIPSIS
 |- Count (Label, IGNORE): bottom-right of the icon cell, Alagard 8, GOLD,
       "x2" style — shown only when Crafting.stack_count(item) > 1
```

- Hover: swap the row stylebox to the `sb_hover` duplicate (the bag's exact idiom)
  **and** show the shared `ItemTooltip.show_item(item, mouse_pos)` on a layer-15
  CanvasLayer (the bag's `DRAG_LAYER` pattern, `bag_ui.gd:61,113-119`) so the player
  can inspect stats *before* taking — WoW parity, and it sells item progression.
- Take feedback on click: row flashes `modulate = Color(1.4, 1.3, 1.0)` → white over
  0.12 s, then the row frees and rows below tween up 0.08 s.

### 2.6 Gold line (always the first row when `loot_gold > 0`)

Same row shell; icon = `pixel:` coin id (promote a Shikashi coin cell into
`IconsPixel.REGISTRY`, or a `FALLBACK_ICON_CELLS` entry — the pipeline already
supports both, `crafting.gd:352-369`). Name label: `"%d Gold" % loot_gold`,
Alagard 9, color `GOLD`. Clicking it (or Take All) does
`player.gold += loot_gold; corpse.loot_gold = 0` and toasts `+12 Gold` in `GOLD`
via the existing `crafting_ui.show_toast` (the same channel today's drop toast uses,
`enemy.gd:485-488`).

### 2.7 Take All button

- `Panel` row at the bottom, `PANEL_W - ROW_PAD_X*2` wide, `TAKE_ALL_H` tall,
  `SLOT_BG` / `SLOT_BORDER` (hover: `SLOT_BORDER_HOVER` + the bag button's gold glow:
  `shadow_color Color(0.85, 0.68, 0.35, 0.30)`, `shadow_size 4`, zero offset —
  `bag_ui.gd:624-628`).
- Centered label: `"Take All"` Alagard 9 `GOLD`; right-aligned mini-caption `"E"`
  Alagard 8 `GOLD` (the bag button's keybind-caption idiom, `bag_ui.gd:644-656`)
  telling the player the fast path.
- Press feedback: the bag button's 0.9 → 1.0 `TRANS_BACK` punch (`bag_ui.gd:672-677`).

### 2.8 Placement near the corpse

The panel is a child of the LootUI CanvasLayer (screen space) but *anchored to the
corpse* each frame while open:

```gdscript
var p: Vector2 = corpse.get_global_transform_with_canvas().origin  # feet, canvas px
position.x = p.x + 14.0                     # right of the corpse
position.y = p.y - panel_h * 0.5 - 10.0     # vertically centered on the body
# flip to the left side when it would leave the view (ItemTooltip._place logic):
if position.x + PANEL_W > view.x - 4.0: position.x = p.x - PANEL_W - 14.0
position = position.clamp(Vector2(4, 4), view - size - Vector2(4, 4)).floor()
```

Re-evaluated per frame (camera can move); `.floor()` keeps it pixel-crisp.
Never overlaps the ability bar: the 360-4 clamp naturally floats it above, and the
corpse anchor keeps it out of the top-left unit frames in practice.

---

## 3. Corpse presentation (world side)

- **Group**: dead enemies with loot join `"lootable_corpses"` (and stay out of
  `"enemies"` logic via the existing `is_dead` guards; collision is already zeroed in
  `_die()`, `enemy.gd:464-465`).
- **Sparkle**: new `VFX.loot_glint(corpse, color)` → a `CPUParticles2D` at the sprite
  torso (`y -14`): 6 particles, lifetime 1.2 s, tiny 2 px `VFX._square_tex` quads,
  gravity `-8`, gold (or best-rarity color) fading out — the legendary-chest glints
  recipe relocated into vfx.gd so enemy.gd can call it too.
- **Nameplate**: stays hidden (`_die()` already does `_plate.visible = false`).
- **Despawn**: `_loot_despawn: float = 90.0` ticked in the existing `is_dead`
  early-return branch of `_physics_process` (`enemy.gd:243-244`). Last 10 s: blink
  `_sprite.modulate.a` between 0.45 and 1.0 at 2 Hz. At 0 (and not currently open in
  the loot window — expiry is deferred while open): run the standard corpse exit
  (`VFX.smoke` + 0.4 s alpha fade + `queue_free`, `enemy.gd:498-505`).

---

## 4. Node tree (new file: `scripts/loot_ui.gd`)

```
LootUI (CanvasLayer, layer 9, group "loot_ui")        # peer of BagUI; both can be
 |                                                    # open at once (bag-full triage)
 |- LootPanel (Control, MOUSE_FILTER_STOP, hidden)
 |   |- Fill (Panel)                 # §2.2 step 2
 |   |- Frame (NinePatchRect)        # §2.2 step 3
 |   |- Title (Label)                # §2.4
 |   |- Rows (Control)               # y = HEADER_H; children rebuilt per open/take
 |   |   |- Row0..RowN (Panel)       # §2.5 / §2.6 — gold line first
 |   |- TakeAll (Panel + Label)      # §2.7
 |- LootTipLayer (CanvasLayer, layer 15)              # bag DRAG_LAYER convention
     |- ItemTooltip                  # shared class, own instance (its documented model)
```

Public surface (duck-typed, matching the house style):
```gdscript
var is_open: bool = false
func open_corpse(corpse: Node2D) -> void   # closes any previous corpse first
func close() -> void
```

Per-frame `_process` upkeep (the BagUI pattern): corpse validity
(`is_instance_valid`), distance leash (close when player-to-corpse > 44 px — a little
beyond LOOT_RANGE so a knockback doesn't slam it shut), dialogue guard
(`_dialogue_open()`, close + inert while a conversation runs, `bag_ui.gd:747-749`),
and re-anchoring per §2.8.

---

## 5. Interaction & input spec

### 5.1 Keyboard / mouse (shipping)

| Input | Closed | Open |
|---|---|---|
| `E` (`interact`) | opens nearest lootable corpse in `LOOT_RANGE` (NPC outranks it — see §6.2) | **Take All + close** (the fast-loot rhythm; teaches itself via the "E" caption on the button) |
| RMB on corpse (within 14 px of world mouse pos AND corpse within `LOOT_RANGE`) | opens it | on another corpse: switches |
| LMB row | — | take that item |
| LMB Take All | — | take everything, close |
| `Esc` (`ui_cancel`) | — | close, take nothing (NOT marked handled — matches the bag's Esc convention, `bag_ui.gd:138-141`) |
| Walk away > 44 px | — | closes |

RMB-to-loot is checked in `player.gd` `_unhandled_input` *before* it would be eaten as
a world click; LMB stays attack — WoW muscle memory (right-click corpse) preserved.

### 5.2 Controller / keyboard-nav note

The input map today is keyboard+mouse only (no joypad events in project.godot). When
pads land, the loot panel is already nav-ready because rows are discrete Panels:

- `interact` (pad X/Square) opens; a **highlight index** replaces mouse hover — the
  highlighted row gets `sb_hover` + the tooltip, `move_up`/`move_down` (dpad) cycles
  (index clamped, gold line first), pad A takes the highlighted row, pad Y = Take All,
  pad B = close. Highlight state and hover state share one code path (`_set_hot(idx)`)
  so mouse and pad never fight.
- Same `_set_hot` machinery gives keyboard-only users arrows + Enter for free.

---

## 6. Wiring points (exact death-path changes)

### 6.1 `enemy.gd` — split the roll from the grant

New fields:
```gdscript
var loot: Array[Dictionary] = []   # rolled item dicts, drained by LootUI
var loot_gold: int = 0
var _loot_despawn: float = 0.0
```

`_grant_kill_rewards()` (`enemy.gd:476`) keeps the XP grant and `report_kill`
**unchanged**, and replaces the `Crafting.drop_for_kill` block with:
```gdscript
for id: String in Crafting.roll_drops(type_name):    # pure roll — crafting.gd:684
    loot.append(Crafting.get_item(id))
loot_gold = _roll_gold()                              # §7 table
if not loot.is_empty() or loot_gold > 0:
    add_to_group("lootable_corpses")
    _loot_despawn = 90.0
```
(The `show_toast("+ item")` on kill is deleted — the loot window IS the announcement.
`crafting.gd:drop_for_kill` becomes LootUI's take-helper or is retired; its stack-aware
insert lives on as `Crafting.grant`, `crafting.gd:495`, which LootUI calls per row:
`grant(inv, id, count)` for stackables, `inv.add_item(dict)` for gear.)

`_on_anim_finished()` (`enemy.gd:494`): if in `"lootable_corpses"` → do **not** smoke/
free; instead freeze on the last death frame and start `VFX.loot_glint(self, color)`.
The smoke + fade + `queue_free` block moves into a `_despawn_corpse()` func called by
(a) LootUI when the last row is taken, (b) the despawn timer.

### 6.2 `player.gd` — the E-priority chain (`player.gd:402-411`)

```gdscript
var npc: Node2D = _nearest_npc()
var corpse: Node2D = null if npc != null else _nearest_lootable()   # NEW
_set_prompt(ui, npc != null)
if Input.is_action_just_pressed("interact"):
    if npc != null: ...                        # unchanged
    elif corpse != null and not _ui_panel_open():
        loot_ui.open_corpse(corpse)            # via group "loot_ui"
    elif not _ui_panel_open():
        _try_open_station()                    # unchanged
```
`_nearest_lootable()` clones `_nearest_npc()` (`player.gd:1661-1672`) over group
`"lootable_corpses"` with `LOOT_RANGE = 30.0`. Add `"loot_ui"` to `_ui_panel_open()`'s
group checks so an open loot panel is a "panel open" for the station fallthrough,
and route the second E press to LootUI's take-all (LootUI itself watches `interact`
in `_unhandled_input` while `is_open`, marking it handled — so player.gd never sees it).

### 6.3 `main.gd` — world prompt (`main.gd:560-564` region)

The station-prompt loop gains one clause: when no NPC claims E (28 px) and a lootable
corpse is within `LOOT_RANGE`, `_show_world_prompt("E  Loot %s" % corpse.display_name)`.
Corpse outranks station in the prompt exactly as in the E-chain.

### 6.4 `vfx.gd` — `loot_glint(parent_corpse, color)` per §3 (new static func beside
`sparkle_buff`, `vfx.gd:323`).

### 6.5 Untouched
`combat.gd` (death routing is enemy-side), `inventory.gd`, `items.gd`,
`xp_system.gd`, `save_system.gd` (corpse loot is transient by design; `player.gold`
is already in the save per `player.gd:172-178`).

---

## 7. Gold drop table (new data, WoW-Classic pacing)

Slow economy: coins are meaningful. Per-family ranges, rolled once at death
(`_roll_gold()` in enemy.gd, seeded RNG fine):

| Family (via `Crafting._drop_family`) | Gold | Note |
|---|---|---|
| wolf / boar (beasts) | 60% chance of 1-2 | beasts carry little — their value is pelts |
| skeleton | 1-3 | graveyard coppers |
| orc | 2-4 | raiders carry purses |
| bear ("Old Mother", mini-boss) | 8-12 | boss purse; pairs with her guaranteed recipe |
| unknown family (scarecrow, fauna) | 0 | never lootable |

Post-demo, tie ranges to `WORLD_PLAN.md` zone level brackets (creature level x ~0.5g)
so the curve scales with the 40-zone rollout without touching this UI.

---

## 8. Edge cases

| Case | Behavior |
|---|---|
| **Bag full** on take | `inv.add_item`/`Crafting.grant` returns false → item **stays in the corpse**, row border flashes `HOSTILE_RED` (0.25 s), toast "Bag is full" in `HOSTILE_RED` via `crafting_ui.show_toast`. Player can open the bag (I) — both panels are layer 9 and coexist — make room, take again. No more silent overflow loss. |
| **Take All with partial room** | takes gold first, then rows top-down until a fail; failing row flashes, panel stays open with the remainder. |
| **Multiple corpses** (AoE kills) | each Enemy owns its `loot`; `_nearest_lootable()` picks the closest; `open_corpse` on a new corpse closes the old panel first. After emptying one, the prompt immediately shows the next in range — E, E, E rhythm. (Optional polish, non-blocking: auto-open next corpse within range after Take All.) |
| **Despawn timer expires while panel open** | expiry deferred while `LootUI` is open on that corpse; blink still plays as warning. |
| **Corpse freed / map change** | per-frame `is_instance_valid` check closes the panel; `change_map` fade (`main.gd:453-460`) frees the world → same guard catches it. Corpse loot intentionally not serialized. |
| **Dialogue opens** | panel closes; E stays inert under dialogue (the BagUI `_dialogue_open()` guard). |
| **Player dies mid-loot** | distance/validity poll: dead player keeps position, so explicitly close when `player.hp <= 0`. |
| **Legendary/epic in the list** | nothing special needed — rarity name color + rim + the rarity-colored corpse glint already telegraph it. The tooltip's gold "Legendary" tag line renders on hover as everywhere else. |
| **Stackable drops** | duplicate rolls of one id merge into a single row with an `x2` count before display; taking uses `Crafting.grant(inv, id, count)` which merges into existing bag stacks. |

---

## 9. QA checklist (RH_* screenshot harness)

1. Kill a graveyard skeleton (town spawns, `combat.gd:25-31`) → corpse glints, prompt
   shows, E opens: bone/ember-dust rows in common grey + gold line. Screenshot at
   1x integer scale: rims are 1 px, no half-pixel bleed (`.floor()` on placement).
2. Fill the bag (20 slots) → take → red flash + toast, item persists in the corpse.
3. Kill Old Mother → recipe scroll row + `Wolf Pelt x2` merged row + 8-12 gold; glint
   runs uncommon-green or better if the table gains rarer entries.
4. Walk 50 px away with the panel open → closes. Esc → closes, corpse keeps glinting.
5. Wait 90 s → blink at 80 s, smoke despawn at 90; loot gone.
6. Open dialogue with the panel open → panel closes, E advances dialogue only.
7. `tests/smoke_test.py` still passes (no scene-tree assumptions broken: LootUI is an
   additive CanvasLayer registered like BagUI in the session bootstrap).
