# RAVEN HOLLOW — ARMOR PROFICIENCIES + THE WYSIWYG ITEM LAW
Design doc for two owner mandates from MANDATES.md (Combat/Classes section):
- *"Armor PROFICIENCIES: cloth/leather/mail/plate per class (WoW rules)"*
- *"NO TRANSMOG — what you wear is what you see; every item looks EXACTLY like
  its icon (WYSIWYG law)"*

**Grounded in (read before writing):**
- `scripts/inventory.gd` — 9 equip slots, `slot_accepts()` is a PURE static
  shape contract (no level/class knowledge); `ITEM_PROGRESSION.md` §9.3 already
  rules that gates live at call-sites, not in `slot_accepts`. This doc follows
  that precedent exactly.
- `scripts/items.gd` — item dict shape `{id, name, slot, rarity, icon, stats,
  flavor, stackable, effect}`; icon law `icon id == item id`; 5 shipped
  legendaries; `_STARTING_BAG_IDS` is one kit shared by all 7 classes (a
  proficiency problem — §6).
- `design/ITEM_PROGRESSION.md` — extension-key layering pattern
  (`ilvl/req_level/set_id/value`, core code ignores unknown keys); the 40
  exemplars; the 6 lore sets with target classes; class–stat affinities.
- `scripts/class_defs.gd` — the 7 classes: warrior, rogue, mage, paladin,
  necromancer, rookwarden (Hunter), druid.
- `scripts/player.gd` — the on-character render system that WYSIWYG builds on:
  visible main-hand weapon Sprite2D (`WEAPON_SHAPES`: 4 crops from
  `pc_wood.png` — sword/dagger/staff/bow), off-hand shield (`SHIELD_SHAPE`,
  one crop), per-frame hand/shoulder anchors, SHEATHED/DRAWN carry states,
  legendary-chest gold-glint particles (`_chest_fx`). Weapon shape is chosen by
  `_weapon_shape_for()` **keyword-sniffing the item name** (player.gd:1400) —
  the main thing this law replaces.
- `scripts/sheet_anim.gd` — the Szadi rig: 32x48 frames, 3 facing rows
  (side/down/up), 4 idle + 4 walk frames per facing.
- `scripts/palette_swap.gdshader` — shipped palette-swap shader; the engine of
  the armor visual-tier plan (§10).
- `scripts/icons_pixel.gd` — Shikashi 32px icon registry;
  `_SPELL_DIR = "res://assets/art/icons_spell/"` painterly-icon slot (Phase D).
- `design/LOOT_WINDOW.md` — icon resolution path the loot window shares.
- `design/LEGENDARY_WEAPONS.md` — **does not exist yet** (checked). §12 lists
  the obligations this law imposes on it when it is written.
- Memory: local ComfyUI + SDXL + Pixel Art XL pipeline is the established
  sprite/icon generator on this machine.

---

# PART I — ARMOR & WEAPON PROFICIENCIES

## 1. Armor classes and who wears what (owner-fixed)

Four armor classes, WoW's exact ladder: **cloth < leather < mail < plate**.
WoW rule kept verbatim: *you may always wear any tier below your maximum* —
a warrior in a cloth kerchief is legal (and visible, per Part II).

| Class | From level 1 | Trains at 40 | Terminal |
|---|---|---|---|
| **Warrior** | cloth, leather, **mail** | **plate** | plate |
| **Paladin** | cloth, leather, **mail** | **plate** | plate |
| **Rogue** | cloth, **leather** | — | leather |
| **Druid** | cloth, **leather** | — | leather |
| **Rookwarden** | cloth, **leather** | **mail** | mail |
| **Mage** | **cloth** | — | cloth |
| **Necromancer** | **cloth** | — | cloth |

### 1.1 The level-40 gate — decision: KEEP IT, and it lands in the forge-city

Classic WoW gates warriors/paladins at mail-until-40 → plate, and hunters at
leather-until-40 → mail. **We keep the level-40 gate**, for three reasons that
are specific to our pacing, not cargo cult:

1. **Act V begins at 40 and Act V is Sangeroasa — the forge city.** The
   material lexicon (ITEM_PROGRESSION §5.1) already places
   *basaltfang/emberforged* plate in Act V, and the first plate set in the game
   is already The Forgefather's Toll (ilvl 46–47, warrior/paladin). The gate
   isn't an arbitrary number: **plate does not exist north of the forge**. You
   train plate where plate is made.
2. Our grind is classic-slow (~2.54M XP to 60); level 40 is a genuine
   mid-campaign milestone, worth a gear-silhouette power beat (and a visible
   one — Part II makes the plate moment readable on the sprite).
3. It future-proofs the loot tables: Acts I–IV never need plate art or plate
   drops at all (§7 annotation table confirms zero pre-40 plate items exist).

**The training moment (one short quest each, not a gold sink):**
- **Plate — "The First Fitting"** (warrior/paladin, level 40, Sangeroasa
  forge-quarter armorer). Bring three basaltfang ingots off the Ashvents
  slag-lines; the armorer measures you against a rack of dead men's fittings
  until one is yours. Dark twist per tone law: the fitting that matches you is
  already stamped with a ledger number.
- **Mail — "Rings for the Rook-Road"** (rookwarden, level 40, trainable at the
  Blestem/Act-IV border warden-post — rookwardens ride the eastern passes, and
  Act IV ends at 40). Recover a dead warden's riveted hauberk from the Whisper
  Passes; the trainer re-rivets it to you, ring by ring, naming the previous
  owner at every tenth ring.

Until trained, plate/mail items behave exactly like an unmet `req_level`:
lootable, bankable, tradeable, tooltip line rendered red (§5.3), equip refused.

### 1.2 armor_class does NOT buy stats

In our system `armor` is a budgeted stat (ITEM_PROGRESSION §2.3), unlike WoW
where armor value scales with armor class. **`armor_class` is purely a
gating + visual key — zero budget interaction.** A cloth robe and a plate
chest of the same ilvl/rarity have the same BP; they simply *spend* it
differently (affinity tables §4 of ITEM_PROGRESSION already slant plate
classes toward armor/hp lines). No double-dipping, no formula change.

## 2. Weapon proficiencies per class

Weapon classes: **sword, axe, mace, dagger, staff, bow** (main-hand) and
**shield, tome, fetish, quiver** (off-hand held types — formalizing
ITEM_PROGRESSION §3.1's "off_hand covers shields, tomes, fetishes and quivers
via flavor"). Plus one special class, **relic** (§2.2).

| Class | Main-hand | Off-hand |
|---|---|---|
| **Warrior** | sword, axe, mace, dagger | **shield** |
| **Paladin** | sword, mace | **shield** |
| **Rogue** | dagger, sword | (second-blade off-hands: 🔒 deferred — no dual-wield in the current combat model) |
| **Druid** | staff, mace, dagger | fetish |
| **Rookwarden** | bow, sword, dagger | quiver |
| **Mage** | staff, dagger | tome |
| **Necromancer** | staff, dagger | fetish |

Design notes:
- No dagger for paladins (classic law, and it keeps The Bloody Dagger out of
  the two holy/plate hands — flavor-correct).
- Shields are **warrior/paladin only**. Both shipped shield legendaries
  (Bulwark) and both shield set pieces (Twelfth Watcher's Ward, Forgefather's
  Pavise) already target exactly those classes — the DB was implicitly
  obeying this rule already.
- No weapon-skill grind (WoW's 1–300 weapon skill): proficiencies are binary
  and fixed at creation (+ the two level-40 armor trainings). The owner
  mandated proficiencies, not skill-ups; skill-ups fight our TTK pacing law.
- Every class keeps ≥2 weapon classes so loot windows stay interesting.

### 2.1 Sanity check — the 5 shipped demo legendaries under the law

| Legendary | weapon_class | Who can equip |
|---|---|---|
| Emberfall (greatsword) | sword | warrior, paladin, rogue, rookwarden |
| Rook's Talon | bow | rookwarden |
| The Bloody Dagger | dagger | warrior, rogue, druid, mage, necromancer, rookwarden |
| Bulwark of the Emberfall Road | shield | warrior, paladin |
| Gravekeeper's Band | (ring — ungated) | all |

Every class can equip at least two of the five (paladin: Emberfall + Bulwark +
Band; mage: Bloody Dagger + Band; druid: Bloody Dagger + Band; …). The law
gates **equip, not acquisition** — classic behavior: you can loot, carry and
bank gear you cannot wear. Demo quests need **no reward changes**. When the
per-class legendary questlines ship (MANDATES 🔄), each class gets its own
weapon anyway (§12).

### 2.2 The `relic` exception (exactly one item)

**The Ledger of Final Account** (campaign-end legendary, main_hand) gets
`weapon_class: "relic"`: **all classes proficient**. Rationale: it is the
one-per-campaign capstone every class must be able to raise at the Pit; and a
brass-bound ledger on a chain is nobody's sword, staff or bow. `relic` is
reserved for campaign artifacts — the owner signs off on every future use.

## 3. Data extension — `armor_class` / `weapon_class` keys

Two new extension keys, following the exact `crafting.gd`/ITEM_PROGRESSION
layering pattern (core code ignores unknown keys; only the proficiency gate,
tooltips and the render layer read them). Appended after `value`:

```gdscript
# armor pieces (slot head/chest/legs/boots):
"armor_class": "mail",     # "cloth"|"leather"|"mail"|"plate"

# weapons & off-hands (slot main_hand/off_hand):
"weapon_class": "sword",   # "sword"|"axe"|"mace"|"dagger"|"staff"|"bow"
                           # |"shield"|"tome"|"fetish"|"quiver"|"relic"

# rings/trinkets/junk (slot ring/trinket/none): NEITHER key (ungated slots).
```

Authoring rule: **exactly one of the two keys per equippable item**, matching
its slot family. A missing key on an armor/weapon slot is an audit error
(§11 checklist), never a silent pass — the WYSIWYG render layer needs the key
too, so it can't be optional.

## 4. `scripts/proficiency.gd` — the one place the rules live

New static class, mirroring the `class_defs.gd`/`items.gd` pattern (pure data
+ tiny helpers, no scene code). The ENTIRE ruleset in one file:

```gdscript
class_name Proficiency
## Armor & weapon proficiency law (design/PROFICIENCY_WYSIWYG.md).

const PLATE_TRAIN_LEVEL: int = 40   # warrior/paladin: mail -> plate
const MAIL_TRAIN_LEVEL: int = 40    # rookwarden:      leather -> mail

## class_id -> armor classes wearable from level 1.
const ARMOR_BASE := {
    "warrior":     ["cloth", "leather", "mail"],
    "paladin":     ["cloth", "leather", "mail"],
    "rogue":       ["cloth", "leather"],
    "druid":       ["cloth", "leather"],
    "rookwarden":  ["cloth", "leather"],
    "mage":        ["cloth"],
    "necromancer": ["cloth"],
}
## class_id -> {armor_class: min level} trained upgrades.
const ARMOR_TRAINED := {
    "warrior":    {"plate": PLATE_TRAIN_LEVEL},
    "paladin":    {"plate": PLATE_TRAIN_LEVEL},
    "rookwarden": {"mail": MAIL_TRAIN_LEVEL},
}
## class_id -> equippable weapon classes ("relic" is implicitly universal).
const WEAPONS := {
    "warrior":     ["sword", "axe", "mace", "dagger", "shield"],
    "paladin":     ["sword", "mace", "shield"],
    "rogue":       ["dagger", "sword"],
    "druid":       ["staff", "mace", "dagger", "fetish"],
    "rookwarden":  ["bow", "sword", "dagger", "quiver"],
    "mage":        ["staff", "dagger", "tome"],
    "necromancer": ["staff", "dagger", "fetish"],
}

## The single verdict API. Returns {ok: bool, reason: String} — reason is the
## player-facing denial line ("Plate: trained at level 40", "Rookwardens
## cannot wield shields"), "" when ok. Checks, in order:
## req_level -> armor_class -> weapon_class. Items with neither key pass
## (rings/trinkets); slot "none" fails upstream in slot_accepts already.
static func can_equip(class_id: String, level: int, item: Dictionary) -> Dictionary
```

`can_equip` also implements the trained-at-40 tier as a *level* check (no save
flag needed for the base rule); the training **quests** gate flavor and the
trainer beat, but a warrior hitting 40 who skips the quest merely sees the
tooltip flip white when the quest completes — quest completion sets a save
flag `trained_plate`/`trained_mail` that `can_equip` requires **in addition
to** the level (so the forge moment cannot be skipped; save_system carries the
flag like any quest flag).

## 5. Equip-gating integration (inventory.gd read — where the checks go)

`inventory.gd` stays **exactly as pure as it is**. `slot_accepts()` keeps its
current contract (shape-only: ring→ring1/ring2, name==type, "none" fails —
inventory.gd:161). Rationale is already written into ITEM_PROGRESSION §9.3
for `req_level`, and it holds doubly here: `Inventory` has no class or level
field, and giving it one would smear player identity into a pure container.

### 5.1 Call-sites that must gate (the complete list)

Every path into `equip_from_bag()` / equipment mutation:

| Call-site | Interaction | Gate behavior |
|---|---|---|
| `bag_ui.gd` — double-click/right-click equip | the main path | `Proficiency.can_equip()` first; on deny: red rim-flash on the bag cell + HUD toast with `reason` |
| `bag_ui.gd` / `character_sheet_ui.gd` — DragCtx drop onto a paper-doll slot | drag & drop | deny → the drag ghost snaps back (DragCtx.clear(), no mutation), same toast |
| quest/vendor "equip now?" conveniences (future) | scripted equips | must route through the same check — rule: **no code path calls `equip_from_bag` without a `can_equip` verdict** (audit greps for this, §11) |

`unequip_*` paths never gate (you can always take something off — including
after a design change strands you in gear you no longer could equip; worn
items are grandfathered until removed, WoW behavior).

### 5.2 Denial feedback (dark-fantasy, not error-beep)

Toast lines are in-world, per class palette:
- armor: *"You have never been fitted for plate."* / *"Mail is not yours to
  carry — yet."* (pre-40 trainable) / *"Cloth hands. Cloth back."* (never)
- weapon: *"Your order does not raise shields."* / *"You were not taught the
  bow."*

### 5.3 Tooltip lines (`item_tooltip.gd`)

Insert one line under the slot line, WoW-style:
- Armor: `Mail` — white when wearable now, **gold** when trainable later
  ("Mail — trained at 40"), **red** when never wearable by this class.
- Weapon: `Sword` / `Shield` / `Relic (all orders)` — same three colors.
- Loot window (LOOT_WINDOW.md) needs no change — it renders names/icons only;
  the tooltip carries the proficiency verdict on hover.

## 6. Retro-annotation — every shipped + exemplar wearable

Rules used (then the full table): quilted/robe/kerchief/shawl/cowl/wraps =
cloth · hood/jerkin/pelts/soles/treads/striders = leather ·
halfhelm/greaves/hauberk-words = mail · cuirass/facemask/apron/pavise-plate
words = plate. Set pieces respect their target classes' terminal armor.

### 6.1 items.gd (shipped)

| Item | Key | Note |
|---|---|---|
| leather_hood | leather | |
| patched_jerkin | leather | |
| iron_cuirass | **mail** | rare, warrior/paladin line; "plate" would be pre-40 contraband |
| padded_breeches | cloth | |
| gravediggers_boots | leather | |
| travelers_boots | leather | |
| rusted_shortsword | sword | |
| pinewood_buckler | shield | ⚠ starting-bag problem, §6.3 |
| gorans_targe | shield | quest reward — warrior/paladin only now (acceptable: it's Goran's) |
| emberfall / rooks_talon / bloody_dagger / bulwark | sword / bow / dagger / shield | §2.1 |
| tarnished_band, gravekeepers_band, ravens_eye, coppervein_ring | — | ungated slots |
| weeping_dagger, charcoal_rubbing | — | slot "none" |

### 6.2 ITEM_PROGRESSION exemplars (all wearables + weapons)

| Item (act) | Key | Note |
|---|---|---|
| waterlogged_boots (I) | leather | |
| wardens_quilted_cap (I) | cloth | |
| gravekeepers_coat (I) | **cloth** | set targets Necromancer — necro is cloth-only, so Vasile's coat is waxed heavy cloth, not leather. Icon must agree (§11). |
| gravekeepers_mudboots (I) | **cloth** | same set constraint |
| bogiron_cleaver (I) | axe | |
| famine_field_sickle (II) | sword | sickle = one-hand blade family |
| lowland_poachers_hood (II) | leather | |
| riverfork_toll_blade (II) | sword | |
| marens_kerchief / patched_shawl (II) | cloth | paladin+druid set: both wear cloth (downtier rule) |
| snowwolf_leggings (III) | leather | |
| still_market_soles (III) | leather | |
| twelfth_watchers_halfhelm / greaves (III) | **mail** | warrior/paladin at 28 — pre-40, mail correct ✓ |
| twelfth_watchers_ward (III) | shield | |
| vasiles_spade (III) | **mace** | hafted blunt family — a spade swings like a maul; druid/warrior/paladin |
| whisper_pass_treads (IV) | leather | |
| transcub_penitents_robe (IV) | cloth | |
| blackglass_stiletto (IV) | dagger | |
| riddlers_blackglass_mask / softstep_boots (IV) | leather | rogue/rookwarden at 38 ✓ (rookwarden keeps leather rights post-40) |
| slagwalkers_band, riddlers_obsidian_loop, whisper_listeners_ear, gravemark_kerbstone, gravekeepers_lantern (rings/trinkets) | — | ungated |
| ashvent_striders (V) | **mail** | 44, crafted — the rookwarden's first post-training mail boots; warrior/paladin too |
| giftfield_reapers_hook (V) | axe | hooked blade, axe family |
| forgefathers_facemask / apron / pavise (V) | **plate** / plate / shield | 46–47, post-40 ✓ — the first plate in the game, forged where plate is born |
| debt_pit_ledgerblade (V) | sword | |
| coldharbor_greaves (VI) | **plate** | 54 tank piece |
| accordkeepers_grey_cowl / treads (VI) | cloth | mage/necro set ✓ |
| accordkeepers_seal | — | ring |
| ledger_of_final_account (VI) | **relic** | §2.2 |

Audit result: **zero contradictions** — no pre-40 plate exists, every set is
wearable by its target classes, all five shields sit on warrior/paladin
targets. The DB was already implicitly obeying WoW rules; this doc just makes
them enforceable.

### 6.3 The starter-bag fix (required, small)

`_STARTING_BAG_IDS` is one kit for all classes; under the law a mage/necro
could equip only `padded_breeches` + `tarnished_band` from it, and nobody but
warrior/paladin the buckler. Fix (also serves the 🔄 "class starting
experiences" mandate): `Items.starting_bag()` grows a `class_id` parameter and
picks one of **two kits**:

- **Leather kit** (warrior, paladin, rogue, druid, rookwarden — existing
  items, zero new art): rusted_shortsword*, leather_hood, patched_jerkin,
  padded_breeches, gravediggers_boots, tarnished_band + pinewood_buckler for
  warrior/paladin only. (*rookwarden gets a new common `cracked_selfbow` [bow],
  druid a `mossbound_cudgel` [mace] — 2 new commons so nobody starts unable to
  hold their own weapon class.)
- **Cloth kit** (mage, necromancer — 4 new common items, i1 budget):
  `mothbitten_cowl` (head), `hemp_robe` (chest), padded_breeches (reused),
  `ashen_footwraps` (boots), `graveyard_switch` (staff), tarnished_band.

Six new commons total, each needing the full WYSIWYG chain of §11.

---

# PART II — THE WYSIWYG ITEM LAW

## 7. The law, stated

Owner mandate: **no transmog; every item looks EXACTLY like its icon and
renders on the character.** Codified as six enforceable rules:

- **W1 — The icon is canon.** An item's icon is its single canonical look:
  silhouette, materials, palette, glow. Everything else derives FROM the icon,
  never the reverse. (Pipeline: §9.)
- **W2 — The world sprite is the icon's silhouette.** The on-character
  weapon/shield sprite is a downscale-derivation of the same silhouette and
  key palette. A player who inspects your Emberfall must recognize the icon.
- **W3 — Armor renders on the rig.** What occupies head/chest/legs/boots is
  visible on the Szadi rig, at minimum as its armor class silhouette in the
  item's icon palette (visual-tier plan: §10).
- **W4 — No transmog, ever.** No appearance slots, no skins, no "hide helm"
  toggle (the owner may later grant "hide helm" as the single mercy exception
  — flagged as an open question, §13; until ruled, no).
- **W5 — Words match pixels.** Name, flavor, tooltip, icon and sprite agree on
  material and state. A "rusted" name may not sit over gleaming art; a cloth
  `armor_class` may not sit under a riveted-mail icon (the Gravekeeper's Coat
  in §6.2 is the live test case: its icon must read as waxed cloth, not hide).
- **W6 — Rig-readability carve-out (the honest clause).** WYSIWYG applies to
  slots that can read at 32x48: weapons, shields/off-hands, chest, head, legs,
  boots. Rings and trinkets are sub-pixel at rig scale; they render as
  **effects, not geometry** — the shipped legendary-chest gold-glint particle
  (`player.gd _chest_fx`) is the precedent: legendary/epic rings+trinkets may
  emit a subtle themed particle; lower rarities render nothing. This is
  written down so nobody "fixes" it into a lie later.

## 8. Current-state audit (what violates the law today)

| # | Finding | Where | Verdict |
|---|---|---|---|
| 1 | Weapon world sprite chosen by **name keyword-sniffing** (`"talon" in key → bow`), 4 generic wooden crops shared by ALL items: Emberfall (legendary glowing greatsword icon) renders as the same wood sword as Rusted Shortsword | `player.gd:1400 _weapon_shape_for`, `WEAPON_SHAPES`, `pc_wood.png` | **violates W1/W2** — the fragile sniffing is exactly what `weapon_class` replaces |
| 2 | ONE shield crop for every off-hand: Bulwark's quartered-heater icon vs generic wood buckler on the arm; tomes/fetishes/quivers render as a shield or nothing | `player.gd SHIELD_SHAPE` | violates W2 |
| 3 | Armor not rendered at all — class sheet is fixed; a naked-slot paladin and a Forgefather-plated one are pixel-identical (chest legendaries get glints only) | `player.gd` rig setup, `sheet_anim.gd` | violates W3 (the big build item — §10) |
| 4 | Item icons are Shikashi 32px pixel cells "picked to match", not authored canon; several items share near-identical cells; painterly item icons don't exist yet (`icons_spell/` is abilities-only, and empty) | `icons_pixel.gd REGISTRY` | W1 not yet establishable — §9 defines the authoring order going forward |
| 5 | No enforcement: nothing stops an item shipping with icon/name/sprite disagreement | — | §11 checklist + audit script |

## 9. The icon → sprite pipeline rule (W1/W2 machinery)

Authoring order for every new item, **icon first, always**:

1. **Canonical painterly icon** — 64x64, authored via the local ComfyUI SDXL +
   Pixel Art XL pipeline (the repo's established generator), on the
   Graveyard-Keeper muted palette, dark-fantasy painterly-pixel hybrid
   matching the premium ability icons. Saved
   `res://assets/art/icons_item/<item_id>.png` (new dir, sibling of
   `_SPELL_DIR`); `IconsPixel.get_tex` gains the same painterly-first,
   Shikashi-fallback resolution it already plans for abilities. The icon fixes
   THE five facts of the item: silhouette · 3–5 key colors · material read ·
   wear state · glow (legendary only).
2. **Palette extraction (automated)** — a build-step script pulls the icon's
   top-5 opaque colors into `assets/art/palettes/<item_id>.json`. This file
   feeds both the weapon-crop recolor and the armor palette-swap (§10). The
   icon literally *is* the color source — W1 enforced by tooling, not
   discipline.
3. **Weapon world sprite** — replace name-sniffing with data:
   - `WEAPON_SHAPES` keys become the ten `weapon_class` values (sword, axe,
     mace, dagger, staff, bow, shield, tome, fetish, quiver) — 6 new base
     crops needed beyond the current 4 (axe, mace, tome, fetish, quiver + a
     2nd shield), each a template pose crop on a new
     `assets/art/weapons/` sheet, grip/scale/sheath_shift measured like the
     B.2.1 pass.
   - New registry `WEAPON_SPRITES: {item_id -> {region, grip, scale, ...}}`
     consulted FIRST; fallback = the item's `weapon_class` base crop
     **palette-swapped through the item's extracted palette**
     (palette_swap.gdshader on the weapon Sprite2D — cheap, per-item color
     fidelity for free).
   - Uniqueness ladder: poor/common = base crop + palette swap ·
     uncommon/rare = base crop + palette swap + 1–2 px detail edit where the
     silhouette differs (sickle hook, stiletto taper) · **epic/legendary =
     mandatory unique crop, PIL-verified at 8x against the icon silhouette**
     (Emberfall's drips/glints child-FX system in `_refresh_weapon` already
     supports per-item garnish).
4. **On-character armor** — §10.
5. **Verification** — §11 checklist run; PIL side-by-side strip (icon | world
   crop | rig render, 8x) eyeballed before the item merges — same
   "viewed by eye at 8x" law items.gd already applies to icons.

Retro-fit order for the existing DB: the 5 legendaries first (worst offenders,
most-seen items), then the 6 lore sets, then rare+, then the long tail —
commons are legal under the fallback rule immediately.

## 10. Armor visual tiers on the Szadi rig (W3 build plan)

The rig: 32x48, facings side/down/up, 4 idle + 4 walk frames = **24 frames per
overlay sheet** (side mirrors for right). Plan = **layered paper-doll
overlays + per-item palette swap**, which buys per-item color fidelity with
bounded art:

- **Layer stack (draw order):** body sheet → legs overlay → boots overlay →
  chest overlay → head overlay → hair tuft (down/side only, suppressed by
  closed helms) → weapon/shield sprites (existing anchor system unchanged).
  Implementation: sibling `Sprite2D`s on the player's AnimatedSprite2D driven
  by the same frame index — the anchor-frame machinery (`_anchor_frame_index`)
  already tracks exactly this.
- **Silhouette inventory (the bounded art bill):** per armor class, **2
  silhouettes per visible slot** — *worn* (acts I–III) and *fine*
  (acts IV–VI): cloth (robe-skirted vs fitted robe), leather (jerkin vs
  hardened harness), mail (ring shirt vs riveted hauberk+coif), plate (fine
  only — plate doesn't exist pre-40; 1 silhouette). That is
  (4 classes × 2 − 1 plate-worn) × 4 slots = **28 overlay sheets × 24 frames**
  — a real but finite commission, buildable with the local pixel-gen pipeline
  + hand cleanup, shipped in stages (below).
- **Per-item color:** every overlay renders through `palette_swap.gdshader`
  fed by the item's §9.2 extracted palette. Two different leather hoods share
  a silhouette but never a palette unless their icons do — which is the truth
  the law demands.
- **Uniques:** the 6 lore sets, epics and legendaries get dedicated overlay
  sheets for their signature piece (the Riddler's eyeless mask, the
  Forgefather's apron) — one slot each, not all four; their remaining pieces
  use class silhouettes + palette. Legendary chest/head additionally keep the
  particle garnish channel (`_chest_fx` precedent).
- **Item key:** derivation is automatic (`armor_class` + act bracket from
  `ilvl` + palette file); an optional `visual: "<sheet_id>"` extension key
  overrides for uniques — same layering pattern as every other key.
- **Staged rollout (each stage ships whole):**
  S1 weapons+shields per-item (§9.3 — kills audit findings 1–2) →
  S2 chest overlays (the biggest silhouette read) →
  S3 head → S4 legs+boots → S5 set/epic/legendary uniques.
  Until a slot's stage ships, that slot renders nothing (status quo) — the law
  tolerates *absence* during construction, never *wrongness* (no placeholder
  that contradicts the icon).
- **Perf note:** +4 Sprite2D per actor is nothing for the player; if smart-NPC
  "players" (🔒 bots pillar) later wear gear, overlays batch under the same
  texture atlases — flag for the GPU-render integration, not a blocker.

## 11. The consistency checklist (LAW — every future item, no exceptions)

Ship-gate for any new item PR; one box unchecked = not merged:

1. ☐ **Icon** exists at `icons_item/<item_id>.png`, `icon id == item id`,
   authored BEFORE sprites; reads correctly at loot-window scale (18px) and
   tooltip scale.
2. ☐ **Keys**: exactly one of `armor_class`/`weapon_class` on equippable
   armor/weapon slots (§3); `Proficiency` tables cover the value; target
   classes of its source content CAN equip it (the §6.2 Gravekeeper's-Coat
   test).
3. ☐ **Palette** file extracted from the icon; committed.
4. ☐ **World sprite**: weapon/off-hand — `weapon_class` base crop or unique
   crop registered; epic/legendary REQUIRE unique crop, PIL-verified at 8x
   against the icon silhouette. Armor — overlay derivation resolves (class
   silhouette exists for its bracket), uniques have their sheet.
5. ☐ **Tooltip** shows the proficiency line with correct color logic; name /
   flavor / material words match the icon's material read (W5).
6. ☐ **On-character check**: equip on the tallest-contrast class rig, PIL
   strip icon|crop|rig at 8x, eyeballed.
7. ☐ **Loot window** renders the same icon (automatic via `_icon_for` path —
   verify only if the item adds a new resolution branch).
8. ☐ **Audit script green**: `tests/wysiwyg_audit.py` (new; runs with
   smoke_test) statically checks: every `_DB` equippable has its
   class key + icon file + palette file; every `weapon_class` value exists in
   `WEAPON_SHAPES`/`WEAPON_SPRITES`; every epic+ weapon has a unique crop
   entry; no code path calls `equip_from_bag` without a `can_equip` verdict
   (grep); tooltip material-word blacklist vs `armor_class` ("mail" word on a
   cloth item, etc.).

## 12. Obligations on LEGENDARY_WEAPONS.md (when it is written)

The per-class legendary questline doc (MANDATES 🔄) inherits, non-negotiably:
one legendary per class ⇒ its `weapon_class` MUST be in that class's §2 list
(warrior sword/axe/mace, paladin mace/sword, rogue dagger, druid staff/mace,
rookwarden bow, mage staff, necromancer staff) · unique painterly icon + unique
world crop + garnish FX (checklist §11 items 1–6 at legendary tier) · icon
authored at concept stage, before quest art, because W1 makes it the canon the
boss-fight visuals must echo.

## 13. Open questions for the owner

1. **"Hide helm"** — classic WoW allowed it; strict WYSIWYG forbids it. Ruling
   requested (recommendation: forbid; the eyeless Riddler mask is a *choice*).
2. **Trainer quests mandatory** (save-flag + level) vs level-only for
   plate/mail at 40 — this doc assumes mandatory (§4); confirm.
3. **`relic` class** reserved for the Ledger alone — confirm no second use
   without sign-off.

## 14. Integration checklist (implementation pass, in order)

1. `scripts/proficiency.gd` — new static class (§4).
2. `items.gd` — annotate per §6.1; `starting_bag(class_id)` + 6 new commons
   (§6.3); exemplar batch lands with `armor_class`/`weapon_class` from §6.2.
3. `bag_ui.gd` / `character_sheet_ui.gd` — gate the three call-site families
   (§5.1) + denial toasts (§5.2).
4. `item_tooltip.gd` — proficiency line, three-color logic (§5.3).
5. `player.gd` — replace `_weapon_shape_for` name-sniffing with
   `weapon_class` → `WEAPON_SPRITES`/`WEAPON_SHAPES` lookup (§9.3); wire
   palette_swap onto weapon/shield sprites.
6. Quests — "The First Fitting" + "Rings for the Rook-Road" (§1.1) with save
   flags; `save_system.gd` carries flags + new item keys ride along (dicts
   serialize as-is, ITEM_PROGRESSION §9.7 precedent).
7. Art stages S1→S5 (§10) + `tests/wysiwyg_audit.py` (§11.8), added to the
   smoke-test lane.
