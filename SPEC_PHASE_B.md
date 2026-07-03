# Phase B Spec — Items, Backpack, Character Sheet (USER-APPROVED)

The user approved this spec verbatim. Deviations need strong justification.

## Style mandate (MANDATORY)
All new UI must match the established Raven Hollow look — the same visual language as `dialogue_ui.gd` and `hud.gd`:
- Dark aged-wood panels: bg `Color(0.09,0.07,0.06,0.96)`, 2px border `Color(0.45,0.33,0.18)`, corner radius 0 (pixel look).
- Alagard font (`res://assets/fonts/alagard.ttf`); gold `Color(0.85,0.68,0.35)` for headers/names, parchment `Color(0.87,0.82,0.72)` for body.
- Kenney 9-patches from `assets/art/ui/` may be used, modulated darker to blend.
- NO flat default-grey Godot controls anywhere.

## Item system
- Item = Dictionary: `{id, name, slot, rarity, icon, stats: {damage, armor, hp, mana, speed_pct, crit_pct}, flavor, stackable, effect}`.
- Slots: `head, chest, legs, boots, main_hand, off_hand, ring1, ring2, trinket` (rings share item slot type "ring").
- Rarities + colors: common grey `(0.62,0.62,0.62)`, uncommon green `(0.35,0.75,0.35)`, rare blue `(0.3,0.5,0.9)`, epic purple `(0.62,0.35,0.85)`, **legendary orange `(1.0,0.55,0.1)`**.
- Icons from `assets/art/icons/` (painterly pack — weapons/armor themes exist: check `_icon_list.txt`).
- Stats apply to the player on equip (damage multiplies ability damage; armor reduces incoming; speed_pct movement).

## Backpack (WoW-style) — key **I** (action `inventory`)
- Bottom-right anchored bag panel: 4×5 grid of 24px slots with dark inset frames; rarity-colored 1px border around occupied slots' icons.
- Hover tooltip: item name in rarity color (Alagard 12), slot + stats lines (parchment), flavor text in italic grey-gold, gold "Legendary" tag line for legendaries.
- Drag & drop: pick up with LMB, drop on paper-doll slot to equip (or right-click to auto-equip); swapped item returns to bag.

## Character sheet paper-doll (WoW-style) — key **C** (action `character_sheet`)
USER'S EXACT WORDS: "C key opens the paper-doll panel — your character's animated sprite center, equipment slots around it WoW-style: Head, Chest, Legs, Boots, Main Hand, Off Hand, Ring ×2, Trinket".
- Center: the player's AnimatedSprite2D preview (idle_down, scale 3) on a dark inset stage with a soft warm glow behind.
- Slots arranged around the character: left column top-to-bottom Head, Chest, Legs, Boots; right column Main Hand, Off Hand, Ring 1, Ring 2, Trinket. 26px slots, engraved slot-name labels (Alagard 8).
- Stats panel strip at the bottom: Damage / Armor / HP / Mana / Speed / Crit totals (icon + number), updating live on equip.
- Drag & drop between bag and slots both ways; invalid slot flashes red border.
- Both panels can be open simultaneously (bag right, sheet left); Esc or key again closes.

## Visible equipment on character (in world AND on the paper-doll preview)
- **Main hand weapon**: a small weapon Sprite2D held by the character — cut from `assets/art/weapons/pc_wood.png` / `pc_bone.png` (pixel-verify the grid; pick sword/staff/bow/dagger shapes) or drawn procedurally (~10-14px). Follows facing: hidden behind body when facing up, in front when down, flipped on side. Subtle idle sway; brandished during casts (reuse the cast lunge).
- **Armor (chest)**: palette tint — the AnimatedSprite2D gets a slight modulate shift per equipped chest rarity/material (e.g. leather = warm brown tint, iron = cool desaturate, legendary = faint gold shimmer via sparkle_buff-style glints). Keep subtle, must not break the muted palette.
- Legendaries additionally get a tiny particle wisp on the weapon (VFX.sparkle_buff style, low intensity).

## Seed items (in the bag at game start — user will QA these)
Per class-agnostic set + at least these LEGENDARIES (orange, with flavor + special effect):
1. **"Emberfall"** — main_hand sword: +12 damage, +5% crit; effect: melee hits spawn a small fire impact (VFX.impact orange). Flavor: "The blade that lit the hollow's last lantern."
2. **"Rook's Talon"** — main_hand bow/dagger: +9 damage, +10% speed; effect: dash abilities leave a feather trail. Flavor: "A feather fell; a kingdom followed."
3. **"Gravekeeper's Band"** — ring: +20 mana, +2 mana regen; effect: kills spawn a brief green soul wisp. Flavor: "Vasile never buries what he cannot keep."
4. **"Bulwark of the Emberfall Road"** — off_hand shield: +8 armor, +25 HP; effect: taking damage pulses a gold ring (2s cooldown). Flavor: "It remembers every blow it was ever dealt."
Plus a handful of common/uncommon/rare items (leather hood, iron chest, traveler boots, plain rings) so drag/drop and rarity borders can be compared.

## Contracts (for the build workflow)
- `Items` (scripts/items.gd): static item DB `get_item(id)`, `starting_bag()` (the seeds), rarity color helpers.
- `Inventory` (scripts/inventory.gd): player-owned data: bag: Array (20 slots, null or item id/dict), equipped: Dictionary slot->item; signals `bag_changed`, `equipment_changed`; equip/unequip/swap logic + stat totals.
- `BagUI` + `CharacterSheetUI` (scripts/bag_ui.gd, scripts/character_sheet_ui.gd): CanvasLayer layer 9 (below dialogue 10, above HUD 8); group lookups, drag state shared via a small `DragContext` (autoload NOT needed — static var acceptable).
- `player.gd` refit: owns an `Inventory`; applies stat totals; weapon sprite + armor tint updates on `equipment_changed`; ability damage uses damage stat.
