class_name HUD
extends CanvasLayer
## Graveyard-Keeper-flavored gameplay HUD for Raven Hollow: Emberfall.
## Built entirely in code. Layer 8 (between the vignette at 5 and dialogue at
## 10), group "hud". Reads the "player" group node every frame, null-safe:
## everything stays hidden until a player with a class_def exists.
##
## Layout (640x360 design space):
##  - Top-left WoW-style unit frames (Phase B.1):
##    * Player frame: 32x32 pixel-face portrait (AtlasTexture head crop of the
##      class' own szadi sheet, idle_down frame 0, PIL-verified rect), class
##      name in gold Alagard, red HP bar + blue mana bar with numeric overlays.
##      Dark StyleBoxFlat fill framed by the Kenney panel_brown 9-patch
##      (draw_center off, modulated darker) for the aged-wood rim.
##    * Target frame (right of the player frame, only while player.target is a
##      live enemy): enemy head-crop portrait (per-type rects PIL-verified —
##      heads are not all centered in the 32x32 idle frame), hostile-red name,
##      red HP bar with numbers. The training scarecrow shows its plate with a
##      full bar and no numbers (its 999999 hp is noise, not information).
##  - Bottom-center ability bar: 3 slots of 30x30 with painterly icons,
##    keybind captions, bottom-anchored cooldown sweep + seconds label,
##    grey-blue tint when mana is insufficient.
##  - Under the player frame: a slim amber XP bar + "Lv N" readout, polled
##    from XPSystem.xp_progress (Phase C).
##  - Top-right, UNDER the minimap (y>=100, right edge): the quest tracker — a
##    parchment panel showing up to 2 tracked quests (name in gold, objective
##    inked below), driven by update_tracker(lines) from the Quests system;
##    [] hides it. The day/night clock is owned/drawn by the Minimap (frozen),
##    NOT here (contract §13/§14).

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const HOSTILE_RED := Color(0.85, 0.25, 0.2)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const BOX_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const HP_FILL := Color(0.62, 0.16, 0.12)
const MANA_FILL := Color(0.2, 0.32, 0.55)
const BAR_BG := Color(0.05, 0.04, 0.03)
const SLOT_BG := Color(0.07, 0.055, 0.045, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const COOLDOWN_SHADE := Color(0.04, 0.03, 0.02, 0.62)
const MANA_LOW_TINT := Color(0.4, 0.42, 0.52)
## Phase C: amber XP fill, parchment tracker sheet + its dark inked objective.
const XP_FILL := Color(0.80, 0.62, 0.22)
const PARCH_BG := Color(0.72, 0.65, 0.5)
const INK := Color(0.22, 0.15, 0.09)

## Unit-frame geometry: 118x42 frame, 34x34 portrait box (32px face at 2x from
## a 16x16 crop — crisp integer pixel scale), 66px bars right of the portrait.
const UF_W: float = 118.0
const UF_H: float = 42.0
const UF_MARGIN: float = 8.0
const UF_GAP: float = 6.0
const UF_BAR_X: float = 44.0
const UF_BAR_W: float = 66.0
const PORTRAIT_POS := Vector2(6.0, 5.0)
const FACE_SIZE: float = 16.0

const SLOT: float = 30.0
const SLOT_GAP: float = 6.0
const KEYBINDS: Array[String] = ["LMB", "Q", "R", "F", "1", "2", "3", "4"]
const CHAR_DIR := "res://assets/art/characters/"
const ENEMY_DIR := "res://assets/art/enemies/"

## Quest tracker (top-right, under the minimap frame+clock which run to y~96).
## Right-edge aligned like the minimap; grows downward for up to 2 quests.
const TRACKER_W: float = 176.0
const TRACKER_TOP: float = 100.0
const TRACKER_PAD: float = 6.0
const TRACKER_TITLE_H: float = 13.0
const TRACKER_LINE_H: float = 12.0
const TRACKER_ENTRY_GAP: float = 5.0

## 16x16 head-crop origin inside idle frame 0 (32x32), per enemy type. All
## rects verified with PIL at 8x — heads are NOT uniformly centered (the
## orc_shaman's hooded head sits low-right, skeleton_mage's high-center).
const HEAD_CROPS: Dictionary = {
	"orc": Vector2(6.0, 3.0),
	"orc_rogue": Vector2(6.0, 3.0),
	"orc_shaman": Vector2(10.0, 8.0),
	"orc_warrior": Vector2(5.0, 1.0),
	"skeleton": Vector2(6.0, 3.0),
	"skeleton_mage": Vector2(8.0, 1.0),
	"skeleton_rogue": Vector2(5.0, 1.0),
	"skeleton_warrior": Vector2(5.0, 3.0),
}
const HEAD_CROP_DEFAULT := Vector2(8.0, 4.0)
## Training scarecrow portrait: its sprite region in lpc_decorations.png is
## (320,130,32,62); hat brim + straw face reads at this crop (PIL-verified —
## y=132 was almost all hat crown, y=137 centers the head).
const SCARECROW_SHEET := "res://assets/art/decor/lpc_decorations.png"
const SCARECROW_FACE := Rect2(328.0, 137.0, 16.0, 16.0)

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _root: Control
var _player_frame: Control
var _portrait: TextureRect
var _class_label: Label
var _hp_fill: ColorRect
var _mana_fill: ColorRect
var _hp_text: Label
var _mana_text: Label
var _target_frame: Control
var _t_portrait: TextureRect
var _t_name: Label
var _t_hp_fill: ColorRect
var _t_hp_text: Label
var _target_iid: int = 0
var _ability_bar: Control
## One Dictionary per slot: {panel, icon, cd_rect, cd_label, key_label}.
var _slots: Array[Dictionary] = []
var _ability_tip: Panel
var _ability_tip_label: Label
var _built_class_id: String = ""
var _xp_fill: ColorRect
var _xp_label: Label
var _tracker: Control
## One Dictionary per tracked-quest slot: {title Label, line Label}.
var _tracker_entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 8
	add_to_group("hud")

	_root = Control.new()
	_root.name = "HudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	_build_player_frame()
	_build_target_frame()
	_build_ability_bar()
	_build_ability_tip()
	_build_xp_bar()
	_build_tracker()


func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		_root.visible = false
		return
	var class_def_v: Variant = player.get("class_def")
	if not (class_def_v is Dictionary):
		_root.visible = false
		return
	var class_def: Dictionary = class_def_v
	if class_def.is_empty():
		_root.visible = false
		return
	_root.visible = true

	var class_id: String = str(class_def.get("id", ""))
	if class_id != _built_class_id:
		_built_class_id = class_id
		_apply_class(class_def)

	_update_bars(player)
	_update_target_frame(player)
	_update_ability_slots(player, class_def)
	if not OS.get_environment("RH_TIP").is_empty():
		_show_ability_tip(int(OS.get_environment("RH_TIP")))
	_update_xp(player)


# --- per-frame updates -------------------------------------------------------

func _update_bars(player: Node) -> void:
	var hp: float = _as_float(player.get("hp"))
	var max_hp: float = maxf(_as_float(player.get("max_hp")), 1.0)
	var mana: float = _as_float(player.get("mana"))
	var max_mana: float = maxf(_as_float(player.get("max_mana")), 1.0)

	var inner_w: float = UF_BAR_W - 2.0
	_hp_fill.size.x = roundf(inner_w * clampf(hp / max_hp, 0.0, 1.0))
	_mana_fill.size.x = roundf(inner_w * clampf(mana / max_mana, 0.0, 1.0))
	_hp_text.text = "%d/%d" % [int(roundf(hp)), int(roundf(max_hp))]
	_mana_text.text = "%d/%d" % [int(roundf(mana)), int(roundf(max_mana))]


func _update_target_frame(player: Node) -> void:
	var target_v: Variant = player.get("target")
	var target: Node2D = target_v as Node2D
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true:
		_target_frame.visible = false
		_target_iid = 0
		return
	_target_frame.visible = true
	if target.get_instance_id() != _target_iid:
		_target_iid = target.get_instance_id()
		_t_name.text = _target_display_name(target)
		_t_portrait.texture = _target_portrait_tex(target)
	var hp: float = _as_float(target.get("hp"))
	var max_hp: float = maxf(_as_float(target.get("max_hp")), 1.0)
	_t_hp_fill.size.x = roundf((UF_BAR_W - 2.0) * clampf(hp / max_hp, 0.0, 1.0))
	if _is_training_dummy(target):
		_t_hp_text.text = ""
	else:
		_t_hp_text.text = "%d/%d" % [int(roundf(hp)), int(roundf(max_hp))]


func _update_ability_slots(player: Node, class_def: Dictionary) -> void:
	var abilities: Array = []
	var abilities_v: Variant = class_def.get("abilities")
	if abilities_v is Array:
		abilities = abilities_v
	_ability_bar.visible = not abilities.is_empty()

	var mana: float = _as_float(player.get("mana"))
	var can_query_cd: bool = player.has_method("cooldown_frac")

	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var panel: Panel = slot["panel"]
		var key_label: Label = slot["key_label"]
		if i >= abilities.size():
			panel.visible = false
			key_label.visible = false
			continue
		panel.visible = true
		key_label.visible = true

		var ability: Dictionary = {}
		var ability_v: Variant = abilities[i]
		if ability_v is Dictionary:
			ability = ability_v
		panel.tooltip_text = _ability_tooltip(ability, KEYBINDS[i] if i < KEYBINDS.size() else "")

		# Cooldown sweep: dark rect rising from the slot bottom.
		var frac: float = 0.0
		if can_query_cd:
			frac = clampf(_as_float(player.call("cooldown_frac", i)), 0.0, 1.0)
		var cd_rect: ColorRect = slot["cd_rect"]
		var cd_label: Label = slot["cd_label"]
		if frac > 0.0:
			var h: float = roundf(frac * SLOT)
			cd_rect.visible = h >= 1.0
			cd_rect.position = Vector2(0.0, SLOT - h)
			cd_rect.size = Vector2(SLOT, h)
		else:
			cd_rect.visible = false
		var remaining: float = frac * _as_float(ability.get("cooldown"))
		cd_label.visible = remaining > 0.3
		if cd_label.visible:
			cd_label.text = "%d" % int(ceilf(remaining)) if remaining >= 9.95 else "%.1f" % remaining

		# Mana-insufficient tint.
		var icon: TextureRect = slot["icon"]
		var cost: float = _as_float(ability.get("mana_cost"))
		icon.modulate = MANA_LOW_TINT if mana < cost else Color.WHITE


## Polls XPSystem.xp_progress(player) -> {level, xp, needed, frac} and drives
## the slim XP bar + "Lv N" under the player frame. At the cap frac is 1.0.
func _update_xp(player: Node) -> void:
	var prog: Dictionary = XPSystem.xp_progress(player)
	var lvl: int = int(prog.get("level", 1))
	var frac: float = clampf(_as_float(prog.get("frac")), 0.0, 1.0)
	_xp_fill.size.x = roundf((UF_W - 2.0) * frac)
	if lvl >= XPSystem.MAX_LEVEL:
		_xp_label.text = "Lv %d  Max" % lvl
	else:
		_xp_label.text = "Lv %d" % lvl


## Quest tracker (Quests contract): lines = quests.tracker_lines(), up to 2
## dicts {title: String, line: String}. Quest name in gold, current objective
## inked on the parchment beneath it. An empty array hides the whole panel.
func update_tracker(lines: Array) -> void:
	var count: int = mini(lines.size(), _tracker_entries.size())
	if count <= 0:
		_tracker.visible = false
		return
	var y: float = TRACKER_PAD
	for i in range(_tracker_entries.size()):
		var entry: Dictionary = _tracker_entries[i]
		var title: Label = entry["title"]
		var line: Label = entry["line"]
		if i >= count:
			title.visible = false
			line.visible = false
			continue
		var data: Dictionary = {}
		var data_v: Variant = lines[i]
		if data_v is Dictionary:
			data = data_v
		title.text = str(data.get("title", ""))
		line.text = str(data.get("line", ""))
		title.visible = true
		line.visible = true
		title.position = Vector2(TRACKER_PAD, y)
		y += TRACKER_TITLE_H
		line.position = Vector2(TRACKER_PAD, y)
		y += TRACKER_LINE_H + TRACKER_ENTRY_GAP
	# Resize the panel to the used entries: drop the trailing gap, add bottom pad.
	_tracker.offset_bottom = TRACKER_TOP + (y - TRACKER_ENTRY_GAP + TRACKER_PAD)
	_tracker.visible = true


func _apply_class(class_def: Dictionary) -> void:
	_class_label.text = str(class_def.get("name", "Adventurer"))
	_portrait.texture = _player_portrait_tex(class_def)
	var abilities: Array = []
	var abilities_v: Variant = class_def.get("abilities")
	if abilities_v is Array:
		abilities = abilities_v
	for i in range(_slots.size()):
		var icon: TextureRect = _slots[i]["icon"]
		icon.texture = null
		if i < abilities.size() and abilities[i] is Dictionary:
			icon.texture = _load_icon((abilities[i] as Dictionary).get("icon"))


# --- construction ------------------------------------------------------------

func _build_player_frame() -> void:
	_player_frame = _build_unit_frame("PlayerFrame", UF_MARGIN)
	_portrait = _make_portrait(_player_frame)

	_class_label = Label.new()
	_class_label.name = "ClassName"
	_style_label(_class_label, 10, GOLD)
	_class_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_class_label.add_theme_constant_override("outline_size", 2)
	_class_label.position = Vector2(UF_BAR_X, 4.0)
	_class_label.size = Vector2(UF_W - UF_BAR_X - 4.0, 12.0)
	_class_label.clip_text = true
	_class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_player_frame.add_child(_class_label)

	var hp_parts: Array = _build_bar(_player_frame,
			Vector2(UF_BAR_X, 17.0), Vector2(UF_BAR_W, 9.0), HP_FILL, 8)
	_hp_fill = hp_parts[0]
	_hp_text = hp_parts[1]
	var mana_parts: Array = _build_bar(_player_frame,
			Vector2(UF_BAR_X, 28.0), Vector2(UF_BAR_W, 9.0), MANA_FILL, 8)
	_mana_fill = mana_parts[0]
	_mana_text = mana_parts[1]


func _build_target_frame() -> void:
	_target_frame = _build_unit_frame("TargetFrame", UF_MARGIN + UF_W + UF_GAP)
	_target_frame.visible = false
	_t_portrait = _make_portrait(_target_frame)

	_t_name = Label.new()
	_t_name.name = "TargetName"
	_style_label(_t_name, 10, HOSTILE_RED)
	_t_name.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_t_name.add_theme_constant_override("outline_size", 2)
	_t_name.position = Vector2(UF_BAR_X, 5.0)
	_t_name.size = Vector2(UF_W - UF_BAR_X - 4.0, 12.0)
	_t_name.clip_text = true
	_t_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_target_frame.add_child(_t_name)

	var hp_parts: Array = _build_bar(_target_frame,
			Vector2(UF_BAR_X, 20.0), Vector2(UF_BAR_W, 12.0), HP_FILL, 8)
	_t_hp_fill = hp_parts[0]
	_t_hp_text = hp_parts[1]


## One 118x42 top-anchored unit frame shell: dark inset fill + aged-wood
## 9-patch rim (same dressing as the dialogue panels). Content goes on top.
func _build_unit_frame(frame_name: String, x: float) -> Control:
	var frame := Control.new()
	frame.name = frame_name
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 0.0
	frame.anchor_right = 0.0
	frame.anchor_top = 0.0
	frame.anchor_bottom = 0.0
	frame.offset_left = x
	frame.offset_right = x + UF_W
	frame.offset_top = UF_MARGIN
	frame.offset_bottom = UF_MARGIN + UF_H
	_root.add_child(frame)

	# Dark fill, inset so the wooden 9-patch rim overlaps its edges.
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(UF_W - 6.0, UF_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.set_border_width_all(0)
	fill_sb.set_corner_radius_all(0)
	fill.add_theme_stylebox_override("panel", fill_sb)
	frame.add_child(fill)

	# Kenney aged-wood rim, tinted darker to sit in the dusk palette.
	var rim := NinePatchRect.new()
	rim.name = "Rim"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture = _panel_tex
	rim.draw_center = false
	rim.patch_margin_left = 10
	rim.patch_margin_right = 10
	rim.patch_margin_top = 10
	rim.patch_margin_bottom = 10
	rim.modulate = FRAME_TINT
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(rim)
	return frame


## 34x34 dark-wood portrait box holding a 32x32 face (16x16 crop at 2x,
## nearest-filtered for crisp pixels). Returns the TextureRect to fill.
func _make_portrait(parent: Control) -> TextureRect:
	var box := Panel.new()
	box.name = "PortraitBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = PORTRAIT_POS
	box.size = Vector2(34.0, 34.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	box.add_theme_stylebox_override("panel", sb)
	parent.add_child(box)

	var face := TextureRect.new()
	face.name = "Portrait"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.position = Vector2(1.0, 1.0)
	face.size = Vector2(32.0, 32.0)
	box.add_child(face)
	return face


## Builds one resource bar (1px border, fill, numeric overlay).
## Returns [fill ColorRect, text Label].
func _build_bar(parent: Control, pos: Vector2, bar_size: Vector2,
		fill_color: Color, font_size: int) -> Array:
	var back := Panel.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = pos
	back.size = bar_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	back.add_theme_stylebox_override("panel", sb)
	parent.add_child(back)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_color
	fill.position = Vector2(1.0, 1.0)
	fill.size = bar_size - Vector2(2.0, 2.0)
	back.add_child(fill)

	var text := Label.new()
	_style_label(text, font_size, PARCHMENT)
	text.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	text.add_theme_constant_override("outline_size", 1)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Alagard's ascent is tall relative to its glyphs, so a centered line box
	# paints the digits ~4 px below the bar's visual middle — lift to compensate.
	text.position = Vector2(0.0, -4.0)
	text.size = bar_size
	back.add_child(text)

	return [fill, text]


## Spell tooltip text (hover). The ability data has no free-text description, so
## compose one from the ability's kind + combat stats.
const KIND_DESC := {
	"melee_arc": "Melee arc — strikes enemies in front of you",
	"projectile": "Projectile — fired toward the cursor",
	"aoe_ring": "Area burst — damages around you",
	"dash": "Dash — a quick burst of movement",
	"summon": "Summon — raises an ally to fight for you",
	"buff": "Empowers you for a short time",
	"volley": "Volley — a spread of shots",
}


func _ability_tooltip(ability: Dictionary, key: String) -> String:
	if ability.is_empty():
		return ""
	var nm: String = str(ability.get("name", "?"))
	var lines: PackedStringArray = PackedStringArray()
	lines.append(("[%s]  %s" % [key, nm]) if key != "" else nm)
	var kd: String = str(KIND_DESC.get(str(ability.get("kind", "")), ""))
	if not kd.is_empty():
		lines.append(kd)
	var stats: PackedStringArray = PackedStringArray()
	var dmg: float = _as_float(ability.get("damage"))
	var rng: float = _as_float(ability.get("range"))
	if dmg > 0.0:
		stats.append("%d dmg" % int(roundf(dmg)))
	if rng > 0.0:
		stats.append("%d range" % int(roundf(rng)))
	if stats.size() > 0:
		lines.append("  ".join(stats))
	var cd: float = _as_float(ability.get("cooldown"))
	var mana: float = _as_float(ability.get("mana_cost"))
	var meta: PackedStringArray = PackedStringArray()
	meta.append(("%.1fs cooldown" % cd) if cd > 0.0 else "No cooldown")
	if mana > 0.0:
		meta.append("%d mana" % int(roundf(mana)))
	lines.append("  ".join(meta))
	return "\n".join(lines)


func _build_ability_bar() -> void:
	var n_slots: int = KEYBINDS.size()
	var total_w: float = SLOT * float(n_slots) + SLOT_GAP * float(n_slots - 1)
	var caption_h: float = 10.0
	_ability_bar = Control.new()
	_ability_bar.name = "AbilityBar"
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_bar.anchor_left = 0.5
	_ability_bar.anchor_right = 0.5
	_ability_bar.anchor_top = 1.0
	_ability_bar.anchor_bottom = 1.0
	_ability_bar.offset_left = -total_w * 0.5
	_ability_bar.offset_right = total_w * 0.5
	_ability_bar.offset_top = -8.0 - caption_h - 2.0 - SLOT
	_ability_bar.offset_bottom = -8.0
	_root.add_child(_ability_bar)

	for i in range(n_slots):
		var x: float = float(i) * (SLOT + SLOT_GAP)

		var panel := Panel.new()
		panel.name = "Slot%d" % i
		# PASS (not IGNORE) so hovering shows the spell tooltip, while LMB clicks
		# still pass through to the game for aiming/attacking.
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.position = Vector2(x, 0.0)
		panel.size = Vector2(SLOT, SLOT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = SLOT_BG
		sb.border_color = SLOT_BORDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(0)
		panel.add_theme_stylebox_override("panel", sb)
		_ability_bar.add_child(panel)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(2.0, 2.0)
		icon.size = Vector2(SLOT - 4.0, SLOT - 4.0)
		panel.add_child(icon)

		var cd_rect := ColorRect.new()
		cd_rect.name = "CooldownShade"
		cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_rect.color = COOLDOWN_SHADE
		cd_rect.visible = false
		panel.add_child(cd_rect)

		var cd_label := Label.new()
		cd_label.name = "CooldownSeconds"
		_style_label(cd_label, 9, GOLD)
		cd_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		cd_label.add_theme_constant_override("outline_size", 2)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.position = Vector2.ZERO
		cd_label.size = Vector2(SLOT, SLOT)
		cd_label.visible = false
		panel.add_child(cd_label)

		var key_label := Label.new()
		key_label.name = "Key%d" % i
		_style_label(key_label, 8, PARCHMENT)
		key_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		key_label.add_theme_constant_override("outline_size", 2)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.text = KEYBINDS[i]
		key_label.position = Vector2(x, SLOT + 2.0)
		key_label.size = Vector2(SLOT, caption_h)
		_ability_bar.add_child(key_label)

		_slots.append({
			"panel": panel,
			"icon": icon,
			"cd_rect": cd_rect,
			"cd_label": cd_label,
			"key_label": key_label,
		})
		panel.mouse_entered.connect(_on_slot_entered.bind(i))
		panel.mouse_exited.connect(_on_slot_exited)


## Slim amber XP bar spanning the player-frame width, just below it, with a
## left-aligned "Lv N" caption. Fill width + text are driven by _update_xp.
func _build_ability_tip() -> void:
	## Custom in-scene spell tooltip (the default CanvasLayer subwindow tooltip
	## does not render reliably over the HUD layer). Driven by slot hover signals.
	_ability_tip = Panel.new()
	_ability_tip.name = "AbilityTip"
	_ability_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_tip.visible = false
	_ability_tip.z_index = 200
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	_ability_tip.add_theme_stylebox_override("panel", sb)
	_root.add_child(_ability_tip)
	_ability_tip_label = Label.new()
	_ability_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_ability_tip_label, 9, PARCHMENT)
	_ability_tip_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_ability_tip_label.add_theme_constant_override("outline_size", 2)
	_ability_tip_label.position = Vector2(6.0, 5.0)
	_ability_tip.add_child(_ability_tip_label)


func _show_ability_tip(i: int) -> void:
	if _ability_tip == null or i < 0 or i >= _slots.size():
		return
	var panel: Panel = _slots[i]["panel"]
	if not panel.visible or panel.tooltip_text == "":
		_ability_tip.visible = false
		return
	_ability_tip_label.text = panel.tooltip_text
	var sz: Vector2 = _ability_tip_label.get_minimum_size() + Vector2(12.0, 10.0)
	_ability_tip.size = sz
	var r: Rect2 = panel.get_global_rect()
	var x: float = r.position.x + r.size.x * 0.5 - sz.x * 0.5
	var y: float = r.position.y - sz.y - 6.0
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	x = clampf(x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	_ability_tip.global_position = Vector2(roundf(x), roundf(y))
	_ability_tip.visible = true


func _on_slot_entered(i: int) -> void:
	_show_ability_tip(i)


func _on_slot_exited() -> void:
	if _ability_tip != null:
		_ability_tip.visible = false


func _build_xp_bar() -> void:
	var y: float = UF_MARGIN + UF_H + 2.0

	var back := Panel.new()
	back.name = "XPBar"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = Vector2(UF_MARGIN, y)
	back.size = Vector2(UF_W, 9.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	back.add_theme_stylebox_override("panel", sb)
	_root.add_child(back)

	_xp_fill = ColorRect.new()
	_xp_fill.name = "XPFill"
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_fill.color = XP_FILL
	_xp_fill.position = Vector2(1.0, 1.0)
	_xp_fill.size = Vector2(0.0, 7.0)
	back.add_child(_xp_fill)

	_xp_label = Label.new()
	_xp_label.name = "XPLevel"
	_style_label(_xp_label, 8, PARCHMENT)
	_xp_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_xp_label.add_theme_constant_override("outline_size", 2)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Same -4 lift the resource bars use for Alagard's tall ascent.
	_xp_label.position = Vector2(3.0, -4.0)
	_xp_label.size = Vector2(UF_W - 6.0, 9.0)
	back.add_child(_xp_label)


## Quest tracker: a parchment sheet under the minimap (right edge, y>=100)
## with an aged-wood 9-patch rim, pre-building 2 hidden entry slots (gold
## quest title + inked objective line). Populated/resized by update_tracker.
func _build_tracker() -> void:
	_tracker = Control.new()
	_tracker.name = "QuestTracker"
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.anchor_top = 0.0
	_tracker.anchor_bottom = 0.0
	_tracker.offset_left = -(UF_MARGIN + TRACKER_W)
	_tracker.offset_right = -UF_MARGIN
	_tracker.offset_top = TRACKER_TOP
	_tracker.offset_bottom = TRACKER_TOP + 37.0
	_tracker.visible = false
	_root.add_child(_tracker)

	# Parchment sheet inset under the wooden rim.
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 3.0
	fill.offset_top = 3.0
	fill.offset_right = -3.0
	fill.offset_bottom = -3.0
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = PARCH_BG
	fsb.border_color = BOX_BORDER
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(0)
	fill.add_theme_stylebox_override("panel", fsb)
	_tracker.add_child(fill)

	var rim := NinePatchRect.new()
	rim.name = "Rim"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture = _panel_tex
	rim.draw_center = false
	rim.patch_margin_left = 10
	rim.patch_margin_right = 10
	rim.patch_margin_top = 10
	rim.patch_margin_bottom = 10
	rim.modulate = FRAME_TINT
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tracker.add_child(rim)

	var text_w: float = TRACKER_W - TRACKER_PAD * 2.0
	for i in range(2):
		var title := Label.new()
		title.name = "Title%d" % i
		_style_label(title, 10, GOLD)
		title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		title.add_theme_constant_override("outline_size", 2)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size = Vector2(text_w, TRACKER_TITLE_H)
		title.visible = false
		_tracker.add_child(title)

		var line := Label.new()
		line.name = "Line%d" % i
		_style_label(line, 9, INK)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.size = Vector2(text_w, TRACKER_LINE_H)
		line.visible = false
		_tracker.add_child(line)

		_tracker_entries.append({"title": title, "line": line})


# --- portraits ---------------------------------------------------------------

## Player face: head crop of the class' szadi sheet, idle_down frame 0
## (col 0, row = variant*3 + 1). PIL-verified: the 16x16 rect at (8, row*48+3)
## frames hair-to-chin on the szadi 32x48 body blocks.
func _player_portrait_tex(class_def: Dictionary) -> Texture2D:
	var sheet: String = str(class_def.get("sheet", ""))
	if not sheet.is_empty() and not sheet.begins_with("res://"):
		sheet = CHAR_DIR + "npc_%s.png" % sheet
	var variant: int = int(_as_float(class_def.get("variant")))
	var row: int = variant * 3 + 1
	var region := Rect2(8.0, float(row * 48 + 3), FACE_SIZE, FACE_SIZE)
	return _face_crop(sheet, region)


## Enemy face: per-type head crop of idle frame 0; the scarecrow (no
## type_name property) gets its LPC hat/head crop instead.
func _target_portrait_tex(target: Node2D) -> Texture2D:
	var type_v: Variant = target.get("type_name")
	if type_v is String and not str(type_v).is_empty():
		var t: String = str(type_v)
		var origin: Vector2 = HEAD_CROPS.get(t, HEAD_CROP_DEFAULT)
		return _face_crop(ENEMY_DIR + t + "_idle.png",
				Rect2(origin, Vector2(FACE_SIZE, FACE_SIZE)))
	return _face_crop(SCARECROW_SHEET, SCARECROW_FACE)


static func _face_crop(path: String, region: Rect2) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var at := AtlasTexture.new()
	at.atlas = load(path)
	at.region = region
	return at


## Nameplate/frame display name: explicit display_name when the spawner set
## one, else the prettified enemy type, else the prettified node name.
static func _target_display_name(target: Node2D) -> String:
	var dn_v: Variant = target.get("display_name")
	if dn_v is String and not str(dn_v).is_empty():
		return str(dn_v)
	var type_v: Variant = target.get("type_name")
	if type_v is String and not str(type_v).is_empty():
		return str(type_v).capitalize()
	return str(target.name).capitalize()


## The training scarecrow marks itself with this meta (it renders its own
## damage numbers); its 999999 hp pool would read as noise in the frame.
static func _is_training_dummy(target: Node2D) -> bool:
	return target.has_meta("own_damage_numbers")


# --- helpers -----------------------------------------------------------------

func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


## Accepts "pixel:<id>" ids (Shikashi sheets via IconsPixel) or full
## "res://..." paths. Returns null if the resource does not exist so a bad
## id never crashes the HUD. (The painterly bare-name fallback is gone —
## Phase B.2 moved every ability/item icon to the pixel registry.)
static func _load_icon(icon_v: Variant) -> Texture2D:
	var s: String = str(icon_v) if icon_v != null else ""
	if s.is_empty():
		return null
	if s.begins_with("pixel:"):
		return IconsPixel.get_tex(s)
	if s.begins_with("res://") and ResourceLoader.exists(s, "Texture2D"):
		return load(s)
	return null


static func _as_float(v: Variant) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
	return 0.0
