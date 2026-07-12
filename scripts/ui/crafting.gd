class_name ProfessionCraftingUI
extends CanvasLayer
## ProfessionCraftingUI - the seven-profession crafting window for Raven Hollow
## (BACKLOG #42, design/CRAFTING.md). One gold-bezel panel matching the HUD kit
## (panel_brown 9-patch rim, Alagard, the shared palette), driven entirely by the
## CraftingSystem autoload. Built in code, loot_window / spellbook convention.
##
## Layout: a row of profession tabs across the top; a skill bar (skill / 1000 +
## rank) for the selected profession; LEFT the profession's recipe list (icon +
## name coloured by recipe ink, unknown recipes as "???"); RIGHT the selected
## recipe's detail - output icon in a rarity ring, category + ink label, flavor,
## stat lines, material have/need rows (green when met, ember when short), any
## craft condition, and the Craft button (gold when craftable). When a
## profession is not learned the detail pane offers a Learn button.
##
## Layer 9, group "profession_crafting_ui". Opens on the K key (raw keycode, no
## new input action) or via open()/open_profession(); Esc closes. QA:
## RH_PROFCRAFT=<prof id|1> opens it after boot via debug_present() (see main.gd).

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.60, 0.55, 0.47)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const BOX_BORDER := Color(0.58, 0.44, 0.22)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const SLOT_BG := Color(0.06, 0.05, 0.04, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SLOT_BORDER_HOVER := Color(0.62, 0.48, 0.26)
const SCRIM := Color(0.0, 0.0, 0.0, 0.45)
const EMBER := Color(0.82, 0.34, 0.26)
const LOCKED := Color(0.42, 0.36, 0.30)

## Recipe ink colours (design/CRAFTING.md 2.2 / 11): wet orange, settled yellow,
## fading green, dry grey - WoW hues through the ornate-UI kit.
const INK := {
	"wet": Color(1.0, 0.50, 0.0),
	"settled": Color(1.0, 1.0, 0.0),
	"fading": Color(0.25, 0.75, 0.25),
	"dry": Color(0.62, 0.62, 0.62),
}
const RARITY_COLOR := {
	"common": Color(0.72, 0.72, 0.72),
	"uncommon": Color(0.35, 0.80, 0.35),
	"rare": Color(0.35, 0.55, 0.95),
	"epic": Color(0.66, 0.40, 0.90),
	"legendary": Color(1.0, 0.55, 0.10),
}
const STAT_LABELS := {
	"damage": "%+d Damage", "armor": "%+d Armor", "hp": "%+d Health",
	"mana": "%+d Mana", "speed_pct": "%+d%% Speed", "crit_pct": "%+d%% Crit",
}

const PANEL_W: float = 540.0
const PANEL_H: float = 322.0
const PAD: float = 10.0
const TAB_Y: float = 30.0
const TAB_H: float = 16.0
const BAR_Y: float = 52.0
const CONTENT_Y: float = 74.0
const LIST_X: float = 10.0
const LIST_W: float = 206.0
const DETAIL_X: float = 228.0
const ROW_H: float = 24.0
const ICONS_PIXEL_PATH := "res://scripts/icons_pixel.gd"

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")
static var _pixel_script: GDScript = null

var is_open: bool = false
var _prof: String = ""
var _selected: String = ""

var _root: Control
var _panel: Control
var _title: Label
var _bar_fill: ColorRect
var _bar_label: Label
var _prof_tabs: Dictionary = {}          # prof_id -> {panel, label}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _rows: Dictionary = {}               # recipe_id -> {panel, sb, icon, label}
var _detail: Control
var _detail_icon: TextureRect
var _detail_rim_sb: StyleBoxFlat
var _detail_name: Label
var _detail_sub: Label
var _detail_flavor: Label
var _detail_lines: VBoxContainer
var _craft_btn: Panel
var _learn_btn: Panel
var _toast: Label
var _toast_tween: Tween
var _open_tween: Tween


func _ready() -> void:
	layer = 9
	add_to_group("profession_crafting_ui")
	_build_shell()
	_build_tabs()
	_build_content()
	_build_toast()
	_connect_system()
	_root.visible = false


# --- public API -------------------------------------------------------------

func open() -> void:
	if _dialogue_open():
		return
	is_open = true
	_root.visible = true
	if _prof == "":
		var profs: Array = CS_professions()
		if not profs.is_empty():
			_prof = str((profs[0] as Dictionary).get("id", ""))
	_rebuild()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.pivot_offset = Vector2(PANEL_W, PANEL_H) * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	_panel.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


func open_profession(prof_id: String) -> void:
	if prof_id != "" and prof_id != "1":
		_prof = prof_id
	open()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.tween_property(_panel, "modulate:a", 0.0, 0.10)
	_open_tween.tween_callback(func() -> void:
		if not is_open:
			_root.visible = false)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## QA/screenshot: learn a couple of professions on the live player, hand it
## skill + materials for the given profession, teach its legendary, and open on
## that tab with the first recipe selected so a headless capture reads clean.
func debug_present(prof_id: String = "bog_iron") -> void:
	var p: String = prof_id
	if p == "" or p == "1":
		p = "bog_iron"
	var actor: Object = _actor()
	if actor != null:
		for extra: String in [p, "blackglass", "folk_warding"]:
			CraftingSystem.learn_profession(actor, extra)
		CraftingSystem.debug_set_skill(actor, p, 150)
		for r: Variant in CraftingSystem.recipes_for(actor, p):
			var rd: Dictionary = r
			if bool(rd.get("legendary", false)):
				CraftingSystem.learn_recipe(actor, str(rd.get("id", "")))
			for mid: String in (rd.get("materials", {}) as Dictionary):
				CraftingSystem.give_material(actor, mid, int((rd["materials"] as Dictionary)[mid]))
	_prof = p
	open()
	var profs: Array = CraftingSystem.recipes_for(actor, p)
	if not profs.is_empty():
		_select(str((profs[0] as Dictionary).get("id", "")))
	# QA only: the spawn arrival banner (DialogueUI, layer 10) sits over this
	# panel's title when force-opened at boot; hide it so the capture reads clean.
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dlg != null:
		var banner: Node = dlg.get_node_or_null("LocationBanner")
		if banner is CanvasItem:
			(banner as CanvasItem).visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_K:
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- system glue ------------------------------------------------------------

func _connect_system() -> void:
	if not _has_cs():
		return
	if CraftingSystem.has_signal("crafted") and not CraftingSystem.crafted.is_connected(_on_crafted):
		CraftingSystem.crafted.connect(_on_crafted)
	if CraftingSystem.has_signal("skill_up") and not CraftingSystem.skill_up.is_connected(_on_skill_up):
		CraftingSystem.skill_up.connect(_on_skill_up)


func _on_crafted(_actor: Object, _rid: String, item: Dictionary) -> void:
	if is_open:
		show_toast("Crafted: %s" % str(item.get("name", "?")))
		_refresh_detail()
		_refresh_rows()


func _on_skill_up(_actor: Object, prof: String, new_skill: int) -> void:
	if is_open and prof == _prof:
		_refresh_bar()


func _has_cs() -> bool:
	return get_node_or_null("/root/CraftingSystem") != null


func CS() -> Node:
	return get_node_or_null("/root/CraftingSystem")


func CS_professions() -> Array:
	return CraftingSystem.professions() if _has_cs() else []


# --- shell ------------------------------------------------------------------

func _build_shell() -> void:
	_root = Control.new()
	_root.name = "CraftingRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	_root.add_child(scrim)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = ((Vector2(640, 360) - Vector2(PANEL_W, PANEL_H)) * 0.5).floor()
	_root.add_child(_panel)

	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(PANEL_W - 6.0, PANEL_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.border_color = BOX_BORDER
	fill_sb.set_border_width_all(2)
	fill.add_theme_stylebox_override("panel", fill_sb)
	_panel.add_child(fill)

	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = _panel_tex
	frame.draw_center = false
	frame.patch_margin_left = 10
	frame.patch_margin_right = 10
	frame.patch_margin_top = 10
	frame.patch_margin_bottom = 10
	frame.modulate = FRAME_TINT
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(frame)

	_title = _mk_label(_panel, 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = "Professions"
	_title.position = Vector2(0.0, 7.0)
	_title.size = Vector2(PANEL_W, 18.0)

	var hint := _mk_label(_panel, 8, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.text = "[K/Esc] Close"
	hint.position = Vector2(PANEL_W - 96.0, 9.0)
	hint.size = Vector2(86.0, 12.0)


func _build_tabs() -> void:
	var profs: Array = CS_professions()
	var n: int = maxi(1, profs.size())
	var usable: float = PANEL_W - PAD * 2.0
	var tw: float = (usable - float(n - 1) * 2.0) / float(n)
	for i: int in profs.size():
		var pd: Dictionary = profs[i]
		var pid: String = str(pd.get("id", ""))
		var tab := Panel.new()
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.position = Vector2(PAD + float(i) * (tw + 2.0), TAB_Y)
		tab.size = Vector2(tw, TAB_H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = SLOT_BG
		sb.border_color = SLOT_BORDER
		sb.set_border_width_all(2)
		tab.add_theme_stylebox_override("panel", sb)
		var lbl := _mk_label(tab, 8, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.name = "Label"
		lbl.text = _short_name(str(pd.get("name", pid)))
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		tab.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
					and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_prof = pid
				_rebuild())
		_panel.add_child(tab)
		_prof_tabs[pid] = {"panel": tab, "label": lbl, "sb": sb}


func _build_content() -> void:
	# skill bar
	var bar_bg := Panel.new()
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.position = Vector2(PAD, BAR_Y)
	bar_bg.size = Vector2(PANEL_W - PAD * 2.0, 16.0)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.04, 0.03, 0.025, 0.95)
	bsb.border_color = SLOT_BORDER
	bsb.set_border_width_all(2)
	bar_bg.add_theme_stylebox_override("panel", bsb)
	_panel.add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.color = Color(0.62, 0.30, 0.16, 0.85)
	_bar_fill.position = Vector2(PAD + 2.0, BAR_Y + 2.0)
	_bar_fill.size = Vector2(0.0, 12.0)
	_panel.add_child(_bar_fill)

	_bar_label = _mk_label(_panel, 9, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	_bar_label.position = Vector2(PAD, BAR_Y + 2.0)
	_bar_label.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# recipe list
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(LIST_X, CONTENT_Y)
	_scroll.size = Vector2(LIST_W, PANEL_H - CONTENT_Y - 12.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_W - 14.0, 0.0)
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	# divider
	var div := ColorRect.new()
	div.color = Color(BOX_BORDER.r, BOX_BORDER.g, BOX_BORDER.b, 0.75)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.position = Vector2(LIST_X + LIST_W + 5.0, CONTENT_Y)
	div.size = Vector2(1.0, PANEL_H - CONTENT_Y - 12.0)
	_panel.add_child(div)

	_build_detail()


func _build_detail() -> void:
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.position = Vector2(DETAIL_X, CONTENT_Y)
	_detail.size = Vector2(PANEL_W - DETAIL_X - PAD, PANEL_H - CONTENT_Y - 12.0)
	_panel.add_child(_detail)

	var slot := Panel.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(0.0, 0.0)
	slot.size = Vector2(34.0, 34.0)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = SLOT_BG
	ssb.border_color = SLOT_BORDER
	ssb.set_border_width_all(2)
	slot.add_theme_stylebox_override("panel", ssb)
	_detail.add_child(slot)

	var rim := Panel.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.position = Vector2(2.0, 2.0)
	rim.size = Vector2(30.0, 30.0)
	_detail_rim_sb = StyleBoxFlat.new()
	_detail_rim_sb.draw_center = false
	_detail_rim_sb.set_border_width_all(2)
	rim.add_theme_stylebox_override("panel", _detail_rim_sb)
	slot.add_child(rim)

	_detail_icon = TextureRect.new()
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.position = Vector2(5.0, 5.0)
	_detail_icon.size = Vector2(24.0, 24.0)
	slot.add_child(_detail_icon)

	_detail_name = _mk_label(_detail, 12, GOLD)
	_detail_name.position = Vector2(42.0, 1.0)
	_detail_name.size = Vector2(_detail.size.x - 42.0, 16.0)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD

	_detail_sub = _mk_label(_detail, 8, DIM)
	_detail_sub.position = Vector2(42.0, 18.0)
	_detail_sub.size = Vector2(_detail.size.x - 42.0, 12.0)

	_detail_flavor = _mk_label(_detail, 8, DIM)
	_detail_flavor.position = Vector2(0.0, 40.0)
	_detail_flavor.size = Vector2(_detail.size.x, 30.0)
	_detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD

	_detail_lines = VBoxContainer.new()
	_detail_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_lines.add_theme_constant_override("separation", 1)
	_detail_lines.position = Vector2(0.0, 72.0)
	_detail_lines.size = Vector2(_detail.size.x, 130.0)
	_detail.add_child(_detail_lines)

	_craft_btn = _mk_button("Craft", func() -> void: _do_craft())
	_craft_btn.position = Vector2(_detail.size.x - 96.0, _detail.size.y - 22.0)
	_craft_btn.size = Vector2(96.0, 20.0)
	_detail.add_child(_craft_btn)

	_learn_btn = _mk_button("Learn Profession", func() -> void: _do_learn())
	_learn_btn.position = Vector2(0.0, _detail.size.y - 22.0)
	_learn_btn.size = Vector2(150.0, 20.0)
	_learn_btn.visible = false
	_detail.add_child(_learn_btn)


# --- rebuild / refresh ------------------------------------------------------

func _rebuild() -> void:
	_refresh_tabs()
	_refresh_bar()
	_rebuild_rows()
	_refresh_detail()


func _refresh_tabs() -> void:
	for pid: Variant in _prof_tabs:
		var entry: Dictionary = _prof_tabs[pid]
		var sb: StyleBoxFlat = entry["sb"]
		var lbl: Label = entry["label"]
		var on: bool = str(pid) == _prof
		var learned: bool = _has_cs() and CraftingSystem.has_profession(_actor(), str(pid))
		sb.border_color = GOLD if on else SLOT_BORDER
		sb.bg_color = SLOT_BG.lerp(GOLD, 0.16) if on else SLOT_BG
		lbl.add_theme_color_override("font_color", GOLD if on else (PARCHMENT if learned else DIM))


func _refresh_bar() -> void:
	var pd: Dictionary = CraftingSystem.profession(_prof) if _has_cs() else {}
	_title.text = str(pd.get("name", "Professions"))
	var actor: Object = _actor()
	var learned: bool = _has_cs() and CraftingSystem.has_profession(actor, _prof)
	var cap: int = CraftingSystem.max_skill() if _has_cs() else 1000
	var skill: int = CraftingSystem.get_skill(actor, _prof) if _has_cs() else 0
	var full_w: float = PANEL_W - PAD * 2.0 - 4.0
	if learned:
		_bar_fill.size = Vector2(full_w * (float(skill) / float(cap)), 12.0)
		_bar_label.text = "%s     %d / %d" % [CraftingSystem.rank_name(skill), skill, cap]
	else:
		_bar_fill.size = Vector2(0.0, 12.0)
		_bar_label.text = "Not learned - visit %s or press Learn" % str(pd.get("trainer", "a trainer"))


func _rebuild_rows() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	_rows.clear()
	if not _has_cs():
		return
	var actor: Object = _actor()
	var recs: Array = CraftingSystem.recipes_for(actor, _prof)
	var want_select: String = _selected
	_selected = ""
	for r: Variant in recs:
		_build_row(r)
	if want_select != "" and _rows.has(want_select):
		_select(want_select)
	elif not recs.is_empty():
		_select(str((recs[0] as Dictionary).get("id", "")))


func _build_row(recipe: Dictionary) -> void:
	var rid: String = str(recipe.get("id", ""))
	var actor: Object = _actor()
	var known: bool = CraftingSystem.is_known(actor, rid)
	var legendary: bool = bool(recipe.get("legendary", false))

	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = GOLD.darkened(0.2) if legendary else SLOT_BORDER
	sb.set_border_width_all(2)
	row.add_theme_stylebox_override("panel", sb)
	_list.add_child(row)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(3.0, 3.0)
	icon.size = Vector2(ROW_H - 6.0, ROW_H - 6.0)
	icon.texture = _icon_for(_dict(recipe.get("output", {})))
	icon.modulate = Color.WHITE if known else Color(0.12, 0.10, 0.08)
	row.add_child(icon)

	var lbl := _mk_label(row, 9, PARCHMENT)
	lbl.position = Vector2(ROW_H, 0.0)
	lbl.size = Vector2(LIST_W - ROW_H - 20.0, ROW_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	if known:
		lbl.text = ("* " if legendary else "") + str(recipe.get("name", rid))
		lbl.add_theme_color_override("font_color", _row_color(recipe, actor))
	else:
		lbl.text = "???"
		lbl.add_theme_color_override("font_color", LOCKED)

	row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select(rid))
	row.mouse_entered.connect(func() -> void:
		if rid != _selected:
			sb.border_color = SLOT_BORDER_HOVER)
	row.mouse_exited.connect(func() -> void:
		if rid != _selected:
			sb.border_color = GOLD.darkened(0.2) if legendary else SLOT_BORDER)
	_rows[rid] = {"panel": row, "sb": sb, "icon": icon, "label": lbl, "legendary": legendary}


func _row_color(recipe: Dictionary, actor: Object) -> Color:
	if CraftingSystem.get_skill(actor, str(recipe.get("profession", ""))) < int(recipe.get("skill_req", 1)):
		return LOCKED
	return INK.get(CraftingSystem.ink_of(actor, str(recipe.get("id", ""))), PARCHMENT)


func _refresh_rows() -> void:
	var actor: Object = _actor()
	for rid: Variant in _rows:
		var entry: Dictionary = _rows[rid]
		var known: bool = CraftingSystem.is_known(actor, str(rid))
		var recipe: Dictionary = CraftingSystem.recipe(str(rid))
		var lbl: Label = entry["label"]
		(entry["icon"] as TextureRect).modulate = Color.WHITE if known else Color(0.12, 0.10, 0.08)
		if known:
			lbl.text = ("* " if bool(entry["legendary"]) else "") + str(recipe.get("name", rid))
			lbl.add_theme_color_override("font_color", _row_color(recipe, actor))
		else:
			lbl.text = "???"
			lbl.add_theme_color_override("font_color", LOCKED)


func _select(rid: String) -> void:
	_selected = rid
	for k: Variant in _rows:
		var entry: Dictionary = _rows[k]
		var sb: StyleBoxFlat = entry["sb"]
		var legendary: bool = bool(entry["legendary"])
		if str(k) == rid:
			sb.border_color = GOLD
			sb.bg_color = SLOT_BG.lerp(GOLD, 0.12)
		else:
			sb.border_color = GOLD.darkened(0.2) if legendary else SLOT_BORDER
			sb.bg_color = SLOT_BG
	_refresh_detail()


func _refresh_detail() -> void:
	for c: Node in _detail_lines.get_children():
		_detail_lines.remove_child(c)
		c.queue_free()
	var actor: Object = _actor()
	var learned: bool = _has_cs() and CraftingSystem.has_profession(actor, _prof)
	_learn_btn.visible = _has_cs() and not learned

	if _selected == "" or not _has_cs():
		_detail_name.text = ""
		_detail_sub.text = ""
		_detail_flavor.text = "" if learned else _prof_flavor()
		_detail_icon.texture = null
		_detail_rim_sb.border_color = SLOT_BORDER
		_set_craft_enabled(false)
		return

	var recipe: Dictionary = CraftingSystem.recipe(_selected)
	var output: Dictionary = _dict(recipe.get("output", {}))
	var known: bool = CraftingSystem.is_known(actor, _selected)
	var rarity: String = str(output.get("rarity", "common"))
	_detail_icon.texture = _icon_for(output)
	_detail_icon.modulate = Color.WHITE if known else Color(0.12, 0.10, 0.08)
	_detail_rim_sb.border_color = _rarity_color(rarity) if known else SLOT_BORDER

	if not known:
		_detail_name.text = "??? Unknown Recipe"
		_detail_name.add_theme_color_override("font_color", LOCKED)
		_detail_sub.text = "%s - learned from: %s" % [_cat(recipe), _unlock_text(recipe)]
		_detail_flavor.text = "Recipes turn up where people stopped needing them."
		_set_craft_enabled(false)
		return

	_detail_name.text = str(recipe.get("name", _selected))
	_detail_name.add_theme_color_override("font_color", _rarity_color(rarity))
	var ink: String = CraftingSystem.ink_of(actor, _selected)
	_detail_sub.text = "%s   -   skill %d   -   %s ink" % [
		_cat(recipe), int(recipe.get("skill_req", 1)), ink]
	_detail_flavor.text = str(output.get("flavor", ""))

	for line: Dictionary in _stat_lines(output):
		_add_line(str(line["text"]), line["color"] as Color)
	var cond: String = _condition_text(recipe)
	if cond != "":
		_add_line("Best crafted: " + cond, INK["settled"])
	_add_line("Materials:", GOLD)
	var mats: Dictionary = _dict(recipe.get("materials", {}))
	for mid: String in mats:
		var need: int = int(mats[mid])
		var have: int = CraftingSystem.material_count(actor, mid)
		var md: Dictionary = CraftingSystem.material(mid)
		_add_material(str(md.get("name", mid)), "pixel:" + str(md.get("icon", "iron_scrap")),
			"%d/%d" % [have, need], PARCHMENT if have >= need else EMBER)

	_set_craft_enabled(CraftingSystem.can_craft(actor, _selected))


# --- actions ----------------------------------------------------------------

func _do_craft() -> void:
	if not _has_cs() or _selected == "":
		return
	var actor: Object = _actor()
	if not CraftingSystem.can_craft(actor, _selected):
		show_toast("Cannot craft that yet.", EMBER)
		return
	var item: Dictionary = CraftingSystem.craft(actor, _selected)
	if item.is_empty():
		show_toast("Your bag is full.", EMBER)


func _do_learn() -> void:
	if not _has_cs():
		return
	var actor: Object = _actor()
	if actor == null:
		show_toast("No character.", EMBER)
		return
	if CraftingSystem.learn_profession(actor, _prof):
		show_toast("Learned: %s" % str(CraftingSystem.profession(_prof).get("name", _prof)))
		_rebuild()
	else:
		show_toast("You already know two crafts.", EMBER)


func _set_craft_enabled(on: bool) -> void:
	var show_btn: bool = _has_cs() and _selected != "" and CraftingSystem.is_known(_actor(), _selected)
	_craft_btn.visible = show_btn
	_craft_btn.set_meta("enabled", on)
	var sb: StyleBoxFlat = _craft_btn.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = GOLD if on else SLOT_BORDER
		sb.bg_color = SLOT_BG.lerp(GOLD, 0.10) if on else SLOT_BG
	var lbl: Label = _craft_btn.get_node_or_null("Label")
	if lbl != null:
		lbl.add_theme_color_override("font_color", GOLD if on else DIM)


# --- detail helpers ---------------------------------------------------------

func _stat_lines(output: Dictionary) -> Array:
	var out: Array = []
	var fx: Dictionary = _dict(output.get("use_effect", {}))
	var kind: String = str(fx.get("kind", ""))
	if kind != "":
		var t: String = "Use: " + kind.replace("_", " ")
		if fx.has("amount"):
			t += " (%d)" % int(fx.get("amount", 0))
		if fx.has("color"):
			t += " - %s sight" % str(fx.get("color", ""))
		out.append({"text": t, "color": PARCHMENT})
	var stats: Dictionary = _dict(output.get("stats", {}))
	for key: String in STAT_LABELS:
		var v: float = float(stats.get(key, 0.0))
		if v != 0.0:
			out.append({"text": (STAT_LABELS[key] as String) % int(v), "color": PARCHMENT})
	return out


func _add_line(text: String, color: Color) -> void:
	var l := _mk_label(_detail_lines, 9, color)
	l.text = text
	l.custom_minimum_size = Vector2(0.0, 12.0)


func _add_material(mat_name: String, icon_id: String, counts: String, color: Color) -> void:
	var line := Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(_detail.size.x, 14.0)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _pixel_icon(icon_id.trim_prefix("pixel:"))
	icon.position = Vector2(6.0, 1.0)
	icon.size = Vector2(12.0, 12.0)
	line.add_child(icon)
	var name_lbl := _mk_label(line, 9, color)
	name_lbl.position = Vector2(22.0, 0.0)
	name_lbl.size = Vector2(_detail.size.x - 70.0, 13.0)
	name_lbl.clip_text = true
	name_lbl.text = mat_name
	var cnt := _mk_label(line, 9, color, HORIZONTAL_ALIGNMENT_RIGHT)
	cnt.position = Vector2(_detail.size.x - 46.0, 0.0)
	cnt.size = Vector2(42.0, 13.0)
	cnt.text = counts
	_detail_lines.add_child(line)


func _prof_flavor() -> String:
	var pd: Dictionary = CraftingSystem.profession(_prof) if _has_cs() else {}
	return str(pd.get("flavor", ""))


func _cat(recipe: Dictionary) -> String:
	return str(recipe.get("category", "item")).capitalize()


func _unlock_text(recipe: Dictionary) -> String:
	var u: String = str(recipe.get("unlock", "trainer"))
	if u == "boss":
		return "boss drop - %s" % str(recipe.get("boss", "a boss"))
	var src: String = str(recipe.get("source", ""))
	return "%s%s" % [u, ("  (%s)" % src) if src != "" else ""]


func _condition_text(recipe: Dictionary) -> String:
	var c: Dictionary = _dict(recipe.get("condition", {}))
	if c.is_empty():
		return ""
	var kind: String = str(c.get("kind", ""))
	if kind.begins_with("festival:"):
		return "during " + kind.trim_prefix("festival:").replace("_", " ")
	if kind == "at_station":
		return "at " + str(c.get("station", "a special station")).replace("_", " ")
	return kind.replace("_", " ")


# --- toast ------------------------------------------------------------------

func show_toast(text: String, color: Color = GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.visible = true
	_toast.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _build_toast() -> void:
	_toast = _mk_label(_root, 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -132.0
	_toast.offset_bottom = -116.0
	_toast.visible = false


# --- resolution / widgets ---------------------------------------------------

func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _actor() -> Object:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p if (p != null and is_instance_valid(p)) else null


func _dialogue_open() -> bool:
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	return dlg != null and dlg.get("is_open") == true


func _rarity_color(rarity: String) -> Color:
	return RARITY_COLOR.get(rarity, PARCHMENT)


func _short_name(full: String) -> String:
	var head: String = full.split(" ")[0].split("-")[0]
	return head.substr(0, 9)


func _icon_for(d: Dictionary) -> Texture2D:
	var icon: String = str(d.get("icon", ""))
	if icon.begins_with("pixel:"):
		return _pixel_icon(icon.trim_prefix("pixel:"))
	return null


static func _pixel_icon(icon_id: String) -> Texture2D:
	if _pixel_script == null:
		if not ResourceLoader.exists(ICONS_PIXEL_PATH, "Script"):
			return null
		_pixel_script = load(ICONS_PIXEL_PATH) as GDScript
	if _pixel_script == null or not bool(_pixel_script.call("has_icon", icon_id)):
		return null
	var tex_v: Variant = _pixel_script.call("get_tex", icon_id)
	return tex_v if tex_v is Texture2D else null


func _mk_label(parent: Control, fsize: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 1)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(l)
	return l


func _mk_button(text: String, cb: Callable) -> Panel:
	var btn := Panel.new()
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	btn.add_theme_stylebox_override("panel", sb)
	var lbl := _mk_label(btn, 10, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.name = "Label"
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			btn.accept_event()
			cb.call())
	btn.mouse_entered.connect(func() -> void:
		if not bool(btn.get_meta("enabled", true)):
			return
		sb.border_color = SLOT_BORDER_HOVER)
	return btn
