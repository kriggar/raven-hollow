class_name SpellbookUI
extends CanvasLayer
## SpellbookUI — the browsable spellbook + talent-tree window for Raven Hollow
## (BACKLOG #59, design/TALENTS_SPELLS.md). Two tabs on one gold-bezel panel that
## matches the HUD kit (panel_brown 9-patch rim, Alagard, the shared palette):
##
##   SPELLBOOK — every learnable entry grouped Class Kit / Trained Spells /
##     Talent Capstones, each row carrying CONCRETE numbers (Dmg / CD / Mana /
##     Rng) and a rank readout (Fireball I-V via TalentSystem.rank_value); hover
##     pops a full tooltip with the whole rank table.
##   TALENTS   — the class's three lore trees, one at a time (sub-tabs), drawn as
##     a 3-column x 7-tier grid with rank pips, tier-gate labels, prerequisite
##     lines, spent / available point counters and click-to-learn (guarded by
##     TalentSystem.can_learn). A Respec button refunds the whole build.
##
## Built entirely in code (loot_window / character_sheet convention). Layer 9,
## group "spellbook_ui". Opens on the "spellbook" action (P); Esc closes. QA:
## RH_SPELLBOOK opens it after boot (see main.gd) for the screenshot harness.

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
const LEARNABLE := Color(0.80, 0.66, 0.32)
const MAXED := Color(0.90, 0.78, 0.42)
const LOCKED := Color(0.22, 0.18, 0.14)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)
const EMBER := Color(0.80, 0.30, 0.24)
const STEEL := Color(0.55, 0.62, 0.72)

## kind -> node accent (placeholder tint when a talent has no pixel icon).
const KIND_COLOR := {
	"passive": Color(0.55, 0.62, 0.72),
	"proc": Color(0.85, 0.68, 0.35),
	"ability_mod": Color(0.70, 0.62, 0.45),
	"ability": Color(0.80, 0.30, 0.24),
}
const KIND_LABEL := {
	"passive": "Passive", "proc": "Proc", "ability_mod": "Modifier", "ability": "Capstone",
}

const PANEL_W: float = 524.0
const PANEL_H: float = 322.0
const PAD: float = 10.0
const HEADER_H: float = 40.0
const ICONS_PIXEL_PATH := "res://scripts/icons_pixel.gd"

# talent grid geometry
const GRID_X: float = 40.0
const GRID_Y: float = 78.0
const COL_PITCH: float = 56.0
const ROW_PITCH: float = 32.0
const NODE: float = 30.0
const DETAIL_X: float = 214.0

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

static var _pixel_script: GDScript = null

var is_open: bool = false
var _tab: String = "talents"           # "spellbook" | "talents"
var _tree_idx: int = 0
var _class_id: String = "warrior"

var _root: Control
var _panel: Control
var _title: Label
var _points_lbl: Label
var _tab_btn_spells: Panel
var _tab_btn_talents: Panel
var _tab_spells: Control
var _tab_talents: Control
var _tree_tabs: Array = []             # 3 Panels
var _grid_host: Control
var _detail: Panel
var _detail_title: Label
var _detail_body: Label
var _respec_btn: Panel
var _spell_scroll: ScrollContainer
var _spell_list: VBoxContainer
var _open_tween: Tween
var _nodes: Dictionary = {}            # talent_id -> {panel, sb, name_lbl}


func _ready() -> void:
	layer = 9
	add_to_group("spellbook_ui")
	_build_shell()
	_build_tabs_bar()
	_build_talents_tab()
	_build_spellbook_tab()
	_connect_talent_system()
	_root.visible = false


func _connect_talent_system() -> void:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts == null:
		return
	if ts.has_signal("points_changed") and not ts.is_connected("points_changed", _on_talents_changed):
		ts.connect("points_changed", _on_talents_changed)
	if ts.has_signal("talent_learned") and not ts.is_connected("talent_learned", _on_talent_learned):
		ts.connect("talent_learned", _on_talent_learned)


func _on_talents_changed(_actor: Object) -> void:
	if is_open:
		_refresh()


func _on_talent_learned(_actor: Object, _id: String, _r: int) -> void:
	if is_open:
		_refresh()


# --- public API -------------------------------------------------------------


func open(tab: String = "talents") -> void:
	_class_id = _resolve_class()
	_tab = tab if (tab == "spellbook" or tab == "talents") else "talents"
	is_open = true
	_root.visible = true
	_refresh()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.pivot_offset = Vector2(PANEL_W, PANEL_H) * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	_panel.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


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
		open(_tab)


## QA/screenshot: open a tab, pick a tree, and pin a talent's tooltip so a
## headless capture shows a readable node + concrete detail text.
func debug_present(tab: String = "talents", tree_idx: int = 0, talent_id: String = "") -> void:
	open(tab)
	_tree_idx = clampi(tree_idx, 0, 2)
	_apply_tab()
	if _tab == "talents":
		_build_grid()
		var tid: String = talent_id
		if tid == "":
			var trees: Array = _trees()
			if _tree_idx < trees.size():
				var talents: Array = (trees[_tree_idx] as Dictionary).get("talents", [])
				if talents.size() > 0:
					tid = str((talents[0] as Dictionary).get("id", ""))
		if tid != "":
			_show_detail(tid)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open():
		return
	if event.is_action_pressed("spellbook"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _dialogue_open() -> bool:
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	return dlg != null and dlg.get("is_open") == true


# --- shell ------------------------------------------------------------------


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "SpellbookRoot"
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
	fill_sb.set_corner_radius_all(0)
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
	_title.text = "Spellbook"
	_title.position = Vector2(0.0, 7.0)
	_title.size = Vector2(PANEL_W, 18.0)

	_points_lbl = _mk_label(_panel, 9, PARCHMENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_points_lbl.position = Vector2(PANEL_W - 210.0, 24.0)
	_points_lbl.size = Vector2(200.0, 12.0)

	var div := ColorRect.new()
	div.color = Color(BOX_BORDER.r, BOX_BORDER.g, BOX_BORDER.b, 0.8)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.position = Vector2(PAD, HEADER_H)
	div.size = Vector2(PANEL_W - PAD * 2.0, 1.0)
	_panel.add_child(div)


func _build_tabs_bar() -> void:
	_tab_btn_spells = _mk_tab("Spellbook", Vector2(PAD, 22.0), func() -> void: _set_tab("spellbook"))
	_tab_btn_talents = _mk_tab("Talents", Vector2(PAD + 84.0, 22.0), func() -> void: _set_tab("talents"))
	_panel.add_child(_tab_btn_spells)
	_panel.add_child(_tab_btn_talents)


func _set_tab(t: String) -> void:
	_tab = t
	_apply_tab()
	_refresh()


func _apply_tab() -> void:
	_tab_spells.visible = _tab == "spellbook"
	_tab_talents.visible = _tab == "talents"
	_hilite_tab(_tab_btn_spells, _tab == "spellbook")
	_hilite_tab(_tab_btn_talents, _tab == "talents")


# --- talents tab ------------------------------------------------------------


func _build_talents_tab() -> void:
	_tab_talents = Control.new()
	_tab_talents.name = "TalentsTab"
	_tab_talents.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_talents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_tab_talents)

	# three tree sub-tabs
	for i in range(3):
		var tab := _mk_tab("Tree", Vector2(PAD + float(i) * 118.0, 46.0), Callable())
		tab.gui_input.connect(_on_tree_tab_input.bind(i))
		tab.custom_minimum_size = Vector2(114.0, 16.0)
		tab.size = Vector2(114.0, 16.0)
		_tab_talents.add_child(tab)
		_tree_tabs.append(tab)

	_grid_host = Control.new()
	_grid_host.name = "GridHost"
	_grid_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_host.position = Vector2.ZERO
	_tab_talents.add_child(_grid_host)

	# detail / tooltip panel on the right
	_detail = Panel.new()
	_detail.name = "Detail"
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.position = Vector2(DETAIL_X, GRID_Y - 2.0)
	_detail.size = Vector2(PANEL_W - DETAIL_X - PAD, 214.0)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.05, 0.04, 0.03, 0.95)
	dsb.border_color = SLOT_BORDER
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(0)
	_detail.add_theme_stylebox_override("panel", dsb)
	_tab_talents.add_child(_detail)

	_detail_title = _mk_label(_detail, 12, GOLD)
	_detail_title.position = Vector2(8.0, 6.0)
	_detail_title.size = Vector2(_detail.size.x - 16.0, 15.0)
	_detail_title.text = "Select a talent"

	_detail_body = _mk_label(_detail, 9, PARCHMENT)
	_detail_body.position = Vector2(8.0, 24.0)
	_detail_body.size = Vector2(_detail.size.x - 16.0, _detail.size.y - 32.0)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_body.clip_text = false
	_detail_body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	_respec_btn = _mk_button("Respec Tree", func() -> void: _do_respec())
	_respec_btn.position = Vector2(DETAIL_X, GRID_Y + 218.0)
	_respec_btn.size = Vector2(120.0, 18.0)
	_tab_talents.add_child(_respec_btn)


func _on_tree_tab_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_tree_idx = idx
		_build_grid()
		_refresh_headers()


func _trees() -> Array:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts == null:
		return []
	return ts.call("trees_for", _class_id)


func _build_grid() -> void:
	for c: Node in _grid_host.get_children():
		c.queue_free()
	_nodes.clear()
	var trees: Array = _trees()
	if _tree_idx >= trees.size():
		return
	var tree: Dictionary = trees[_tree_idx]
	var talents: Array = tree.get("talents", [])

	# tier gate labels down the left
	var ts: Node = get_node_or_null("/root/TalentSystem")
	for tier in range(1, 8):
		var need: int = ts.call("tier_requirement", tier) if ts != null else (tier - 1) * 5
		var gate := _mk_label(_grid_host, 8, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		gate.position = Vector2(GRID_X - 30.0, GRID_Y + float(tier - 1) * ROW_PITCH + 8.0)
		gate.size = Vector2(24.0, 12.0)
		gate.text = str(need)

	# prerequisite connector lines (drawn under the nodes)
	for t: Variant in talents:
		var tal: Dictionary = t
		var req: String = str(tal.get("requires", ""))
		if req == "":
			continue
		var req_tal: Dictionary = ts.call("get_talent", req) if ts != null else {}
		if req_tal.is_empty():
			continue
		var a: Vector2 = _node_center(int(req_tal.get("tier", 1)), int(req_tal.get("col", 1)))
		var b: Vector2 = _node_center(int(tal.get("tier", 1)), int(tal.get("col", 1)))
		var line := Line2D.new()
		line.points = PackedVector2Array([a, b])
		line.width = 2.0
		line.default_color = Color(SLOT_BORDER_HOVER.r, SLOT_BORDER_HOVER.g, SLOT_BORDER_HOVER.b, 0.55)
		line.z_index = -1
		_grid_host.add_child(line)

	# talent nodes
	for t: Variant in talents:
		_build_node(t)
	_update_nodes()


func _node_center(tier: int, col: int) -> Vector2:
	return Vector2(GRID_X + float(col) * COL_PITCH + NODE * 0.5,
		GRID_Y + float(tier - 1) * ROW_PITCH + NODE * 0.5)


func _build_node(tal: Dictionary) -> void:
	var tid: String = str(tal.get("id", ""))
	var tier: int = int(tal.get("tier", 1))
	var col: int = int(tal.get("col", 1))
	var pos: Vector2 = Vector2(GRID_X + float(col) * COL_PITCH, GRID_Y + float(tier - 1) * ROW_PITCH)

	var node := Panel.new()
	node.name = "T_" + tid
	node.position = pos
	node.size = Vector2(NODE, NODE)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	node.add_theme_stylebox_override("panel", sb)
	node.gui_input.connect(_on_node_input.bind(tid))
	node.mouse_entered.connect(func() -> void: _show_detail(tid))
	_grid_host.add_child(node)

	# icon or kind-tinted placeholder
	var kind: String = str(tal.get("kind", "passive"))
	var accent: Color = KIND_COLOR.get(kind, STEEL)
	var tex: Texture2D = _icon_for(tal)
	if tex != null:
		var ic := TextureRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = tex
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(3.0, 3.0)
		ic.size = Vector2(NODE - 6.0, NODE - 6.0)
		node.add_child(ic)
	else:
		var ph := ColorRect.new()
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.color = accent.darkened(0.35)
		ph.position = Vector2(5.0, 5.0)
		ph.size = Vector2(NODE - 10.0, NODE - 10.0)
		node.add_child(ph)
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.color = accent
		dot.position = Vector2(NODE * 0.5 - 3.0, NODE * 0.5 - 3.0)
		dot.size = Vector2(6.0, 6.0)
		node.add_child(dot)

	# rank pip label under the node ("r/max")
	var rank_lbl := _mk_label(_grid_host, 8, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.position = Vector2(pos.x - 8.0, pos.y + NODE - 1.0)
	rank_lbl.size = Vector2(NODE + 16.0, 11.0)
	rank_lbl.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	rank_lbl.add_theme_constant_override("outline_size", 2)

	_nodes[tid] = {"panel": node, "sb": sb, "rank": rank_lbl}


func _update_nodes() -> void:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	var actor: Object = _actor()
	for tid: Variant in _nodes:
		var tal: Dictionary = ts.call("get_talent", str(tid)) if ts != null else {}
		var maxr: int = int(tal.get("max_ranks", 1))
		var ranks: int = ts.call("get_ranks", actor, str(tid)) if (ts != null and actor != null) else 0
		var learnable: bool = actor != null and ts != null and ts.call("can_learn", actor, str(tid))
		var entry: Dictionary = _nodes[tid]
		var sb: StyleBoxFlat = entry["sb"]
		var rank_lbl: Label = entry["rank"]
		rank_lbl.text = "%d/%d" % [ranks, maxr]
		if ranks >= maxr and maxr > 0:
			sb.border_color = MAXED
			sb.bg_color = SLOT_BG.lerp(MAXED, 0.22)
			rank_lbl.add_theme_color_override("font_color", MAXED)
		elif ranks > 0:
			sb.border_color = LEARNABLE
			sb.bg_color = SLOT_BG.lerp(LEARNABLE, 0.12)
			rank_lbl.add_theme_color_override("font_color", PARCHMENT)
		elif learnable:
			sb.border_color = LEARNABLE
			sb.bg_color = SLOT_BG
			rank_lbl.add_theme_color_override("font_color", DIM)
		else:
			sb.border_color = SLOT_BORDER
			sb.bg_color = SLOT_BG
			rank_lbl.add_theme_color_override("font_color", DIM)


func _on_node_input(event: InputEvent, tid: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var ts: Node = get_node_or_null("/root/TalentSystem")
		var actor: Object = _actor()
		if ts != null and actor != null and ts.call("learn", actor, tid):
			_flash_node(tid)
		else:
			_reject_node(tid)
		_show_detail(tid)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_show_detail(tid)


func _flash_node(tid: String) -> void:
	if not _nodes.has(tid):
		return
	var panel: Panel = _nodes[tid]["panel"]
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.18, 1.18), 0.06)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.10)


func _reject_node(tid: String) -> void:
	if not _nodes.has(tid):
		return
	var sb: StyleBoxFlat = _nodes[tid]["sb"]
	var orig: Color = sb.border_color
	sb.border_color = EMBER
	var tw := create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(func() -> void: sb.border_color = orig)


func _do_respec() -> void:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	var actor: Object = _actor()
	if ts != null and actor != null:
		ts.call("reset", actor)
		_refresh()


func _show_detail(tid: String) -> void:
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts == null:
		return
	var tal: Dictionary = ts.call("get_talent", tid)
	if tal.is_empty():
		return
	var actor: Object = _actor()
	var ranks: int = ts.call("get_ranks", actor, tid) if actor != null else 0
	var maxr: int = int(tal.get("max_ranks", 1))
	var tier: int = int(tal.get("tier", 1))
	var kind: String = str(tal.get("kind", "passive"))
	_detail_title.text = str(tal.get("name", "?"))
	var lines: Array[String] = []
	lines.append("%s  -  Tier %d  -  Rank %d/%d" % [KIND_LABEL.get(kind, kind), tier, ranks, maxr])
	lines.append(str(tal.get("desc", "")))
	var per: Dictionary = tal.get("per_rank", {})
	if kind == "passive" and ranks > 0:
		var cur: Array[String] = []
		for stat: Variant in per:
			if str(stat) == "when":
				continue
			var v: Variant = per[stat]
			if v is int or v is float:
				cur.append("%s %s" % [_pretty_stat(str(stat)), _signed(float(v) * float(ranks))])
		if cur.size() > 0:
			lines.append("Now: " + ", ".join(cur))
	if kind == "ability" and tal.has("ability"):
		lines.append(_ability_stats_line(tal["ability"]))
	var need: int = ts.call("tier_requirement", tier)
	lines.append("Requires %d points in this tree." % need)
	var req: String = str(tal.get("requires", ""))
	if req != "":
		var rt: Dictionary = ts.call("get_talent", req)
		lines.append("Requires: %s (maxed)." % str(rt.get("name", req)))
	if actor != null and ranks < maxr:
		lines.append("" )
		lines.append("Learnable: %s" % ("YES" if ts.call("can_learn", actor, tid) else "no - gate/points/prereq"))
	_detail_body.text = "\n".join(lines)


# --- spellbook tab ----------------------------------------------------------


func _build_spellbook_tab() -> void:
	_tab_spells = Control.new()
	_tab_spells.name = "SpellsTab"
	_tab_spells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_spells.position = Vector2(PAD, 46.0)
	_tab_spells.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 46.0 - PAD)
	_panel.add_child(_tab_spells)

	_spell_scroll = ScrollContainer.new()
	_spell_scroll.name = "Scroll"
	_spell_scroll.position = Vector2.ZERO
	_spell_scroll.size = _tab_spells.size
	_spell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_spells.add_child(_spell_scroll)

	_spell_list = VBoxContainer.new()
	_spell_list.name = "List"
	_spell_list.custom_minimum_size = Vector2(_tab_spells.size.x - 14.0, 0.0)
	_spell_list.add_theme_constant_override("separation", 3)
	_spell_scroll.add_child(_spell_list)


func _build_spell_rows() -> void:
	for c: Node in _spell_list.get_children():
		c.queue_free()
	var ts: Node = get_node_or_null("/root/TalentSystem")

	# 1. class kit (from ClassDefs, live + authoritative)
	_spell_section("Class Kit")
	var kit: Array = _kit_abilities()
	for i in range(kit.size()):
		var ab: Dictionary = kit[i]
		var learn_lv: int = _kit_learn_level(i)
		_spell_row(ab, learn_lv, [], "kit")

	# 2. trained utility spells (from talents.json spellbook)
	if ts != null:
		var util: Array = ts.call("spellbook_for", _class_id)
		if util.size() > 0:
			_spell_section("Trained Spells")
			for u: Variant in util:
				var sp: Dictionary = u
				_spell_row(sp, int(sp.get("req_level", 1)), sp.get("rank_levels", []), str(sp.get("trainer_verb", "")))

	# 3. talent capstones
	if ts != null:
		var caps: Array = ts.call("capstones_for", _class_id)
		if caps.size() > 0:
			_spell_section("Talent Capstones")
			for c2: Variant in caps:
				_spell_row(c2, 30, [], "capstone")


func _spell_section(title: String) -> void:
	var head := _mk_label(_spell_list, 11, GOLD)
	head.custom_minimum_size = Vector2(0.0, 15.0)
	head.text = "- %s -" % title


func _spell_row(sp: Dictionary, learn_lv: int, rank_levels: Array, tag: String) -> void:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, 30.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	row.add_theme_stylebox_override("panel", sb)
	_spell_list.add_child(row)

	var icon_box := Panel.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.position = Vector2(4.0, 3.0)
	icon_box.size = Vector2(24.0, 24.0)
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.03, 0.025, 0.02, 0.9)
	rim.border_color = SLOT_BORDER
	rim.set_border_width_all(2)
	icon_box.add_theme_stylebox_override("panel", rim)
	row.add_child(icon_box)
	var tex: Texture2D = _icon_for(sp)
	if tex != null:
		var ic := TextureRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = tex
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(2.0, 2.0)
		ic.size = Vector2(20.0, 20.0)
		icon_box.add_child(ic)

	var name_lbl := _mk_label(row, 10, PARCHMENT)
	name_lbl.position = Vector2(34.0, 3.0)
	name_lbl.size = Vector2(230.0, 13.0)
	var ranks_n: int = maxi(1, rank_levels.size())
	var rname: String = str(sp.get("name", "?"))
	if ranks_n > 1:
		rname += "  (I-%s)" % _roman(ranks_n)
	name_lbl.text = rname

	var stats_lbl := _mk_label(row, 8, GOLD)
	stats_lbl.position = Vector2(34.0, 16.0)
	stats_lbl.size = Vector2(row.custom_minimum_size.x - 40.0 if row.custom_minimum_size.x > 40.0 else 300.0, 11.0)
	stats_lbl.text = _spell_stats_line(sp)

	var meta_lbl := _mk_label(row, 8, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	meta_lbl.position = Vector2(_tab_spells.size.x - 96.0, 3.0)
	meta_lbl.size = Vector2(78.0, 12.0)
	var meta: String = "Lv %d" % learn_lv
	if tag != "" and tag != "kit" and tag != "capstone":
		meta = tag.capitalize()
	meta_lbl.text = meta

	row.mouse_entered.connect(func() -> void: _hover_spell_row(sb, true))
	row.mouse_exited.connect(func() -> void: _hover_spell_row(sb, false))
	row.set_meta("sp", sp)
	row.set_meta("rl", rank_levels)
	row.set_meta("ll", learn_lv)
	row.gui_input.connect(_on_spell_row_input.bind(row))


func _hover_spell_row(sb: StyleBoxFlat, on: bool) -> void:
	sb.border_color = SLOT_BORDER_HOVER if on else SLOT_BORDER


func _on_spell_row_input(event: InputEvent, row: Panel) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# reuse the talent detail panel is talents-only; show spell detail inline
		# via the tooltip-style print into the title bar area is overkill — keep the
		# concrete rank table in a transient label at the cursor.
		_show_spell_popup(row.get_meta("sp"), row.get_meta("rl"), int(row.get_meta("ll")),
			row.get_global_rect().position)


func _show_spell_popup(sp: Dictionary, rank_levels: Array, learn_lv: int, at: Vector2) -> void:
	var existing: Node = _root.get_node_or_null("SpellPopup")
	if existing != null:
		existing.queue_free()
	var pop := Panel.new()
	pop.name = "SpellPopup"
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	pop.add_theme_stylebox_override("panel", sb)
	var lbl := _mk_label(pop, 9, PARCHMENT)
	lbl.position = Vector2(6.0, 5.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: Array[String] = []
	lines.append(str(sp.get("name", "?")))
	lines.append(_spell_stats_line(sp))
	var dmg: float = float(sp.get("damage", 0.0))
	if dmg > 0.0 and rank_levels.size() > 1:
		var parts: Array[String] = []
		var ts: Node = get_node_or_null("/root/TalentSystem")
		for i in range(rank_levels.size()):
			var rv: float = ts.call("rank_value", dmg, learn_lv, int(rank_levels[i])) if ts != null else dmg
			parts.append("%s=%d@L%d" % [_roman(i + 1), int(rv), int(rank_levels[i])])
		lines.append("Ranks: " + "  ".join(parts))
	var p: Dictionary = sp.get("params", {})
	var extras: Array[String] = _param_highlights(p)
	if extras.size() > 0:
		lines.append(", ".join(extras))
	lbl.text = "\n".join(lines)
	var w: float = 260.0
	lbl.size = Vector2(w - 12.0, 60.0)
	pop.size = Vector2(w, 66.0)
	var vp: Vector2 = Vector2(640, 360)
	pop.position = Vector2(clampf(at.x, 6.0, vp.x - w - 6.0), clampf(at.y - 70.0, 6.0, vp.y - 72.0))
	_root.add_child(pop)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(pop):
			pop.queue_free())


# --- refresh / headers ------------------------------------------------------


func _refresh() -> void:
	_class_id = _resolve_class()
	_apply_tab()
	_refresh_headers()
	if _tab == "talents":
		_build_grid()
	else:
		_build_spell_rows()


func _refresh_headers() -> void:
	var cname: String = _class_id.capitalize()
	if _tab == "talents":
		_title.text = "%s Talents" % cname
	else:
		_title.text = "%s Spellbook" % cname
	var ts: Node = get_node_or_null("/root/TalentSystem")
	var actor: Object = _actor()
	if ts != null and actor != null:
		var avail: int = ts.call("get_points", actor)
		var spent: int = ts.call("get_spent", actor)
		_points_lbl.text = "Talent Points:  %d available  /  %d spent" % [avail, spent]
	else:
		_points_lbl.text = "Talent Points:  (no character)"
	# tree sub-tab labels + hilite
	var trees: Array = _trees()
	for i in range(_tree_tabs.size()):
		var tab: Panel = _tree_tabs[i]
		var lbl: Label = tab.get_node_or_null("Label")
		if i < trees.size():
			var tr: Dictionary = trees[i]
			var inpts: int = ts.call("points_in_tree", actor, str(tr.get("id", ""))) if (ts != null and actor != null) else 0
			if lbl != null:
				lbl.text = "%s (%d)" % [str(tr.get("name", "?")), inpts]
			tab.visible = true
		else:
			tab.visible = false
		_hilite_tab(tab, i == _tree_idx)


# --- resolution helpers -----------------------------------------------------


func _actor() -> Object:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p if (p != null and is_instance_valid(p)) else null


func _resolve_class() -> String:
	var p: Node = _actor()
	if p != null:
		var cd_v: Variant = p.get("class_def")
		if cd_v is Dictionary:
			var cid: String = str((cd_v as Dictionary).get("id", ""))
			if cid != "":
				return cid
	var env: String = OS.get_environment("RH_CLASS")
	if env != "":
		return env
	return _class_id


func _kit_abilities() -> Array:
	if ResourceLoader.exists("res://scripts/class_defs.gd"):
		var cd: Variant = ClassDefs.get_def(_class_id)
		if cd is Dictionary:
			return (cd as Dictionary).get("abilities", [])
	return []


func _kit_learn_level(slot: int) -> int:
	# design 4.2 kit re-gate: 1 / 4 / 8 / 12 / 16 / 20 / 24 / 30
	var gates: Array[int] = [1, 4, 8, 12, 16, 20, 24, 30]
	return gates[slot] if slot < gates.size() else 30


# --- formatting -------------------------------------------------------------


func _spell_stats_line(sp: Dictionary) -> String:
	var parts: Array[String] = []
	var dmg: float = float(sp.get("damage", 0.0))
	var kind: String = str(sp.get("kind", ""))
	if dmg > 0.0:
		parts.append("Dmg %d" % int(round(dmg)))
	var cd: float = float(sp.get("cooldown", 0.0))
	if cd > 0.0:
		parts.append("CD %s s" % _fmt(cd))
	var mana: float = float(sp.get("mana_cost", 0.0))
	if mana > 0.0:
		parts.append("Mana %d" % int(round(mana)))
	var rng: float = float(sp.get("range", 0.0))
	if rng > 0.0:
		parts.append("Rng %d" % int(round(rng)))
	if parts.is_empty():
		parts.append(kind.capitalize().replace("_", " "))
	return "   ".join(parts)


func _ability_stats_line(ab: Dictionary) -> String:
	return "Capstone:  " + _spell_stats_line(ab)


func _param_highlights(p: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var order := [
		["slow_mult", "slow x%s"], ["slow_duration", "slow %ss"],
		["root_duration", "root %ss"], ["silence_duration", "silence %ss"],
		["interrupt", "interrupt"], ["duration", "%ss"], ["heal", "heal %s"],
		["heal_per_sec", "heal %s/s"], ["absorb", "absorb %s"],
		["bleed_per_sec", "bleed %s/s"], ["execute_mult", "execute x%s"],
		["lifesteal", "lifesteal %s"],
	]
	for r: Array in order:
		var k: String = r[0]
		if not p.has(k):
			continue
		var v: Variant = p[k]
		if k == "interrupt":
			if bool(v):
				out.append("interrupt")
			continue
		if v is bool:
			continue
		out.append((r[1] as String) % _fmt(float(v)))
		if out.size() >= 4:
			break
	return out


func _pretty_stat(stat: String) -> String:
	var names := {
		"armor": "Armor", "stamina": "Stamina", "mana": "Mana", "mana_regen": "Mana Regen",
		"hp_regen": "HP Regen", "crit_pct": "Crit%", "speed_pct": "Speed%",
		"damage_dealt_pct": "Dmg Dealt%", "damage_taken_pct": "Dmg Taken%",
		"max_hp_pct": "Max HP%", "max_mana_pct": "Max Mana%", "crit_mult": "Crit Mult",
	}
	return str(names.get(stat, stat.capitalize().replace("_", " ")))


func _roman(n: int) -> String:
	var r: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII"]
	return r[clampi(n, 0, 7)]


func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return "%.1f" % v


func _signed(v: float) -> String:
	var s: String = _fmt(absf(v))
	return ("+" + s) if v >= 0.0 else ("-" + s)


# --- widget factories -------------------------------------------------------


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


func _mk_tab(text: String, pos: Vector2, cb: Callable) -> Panel:
	var btn := Panel.new()
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.position = pos
	btn.size = Vector2(78.0, 16.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("panel", sb)
	var lbl := _mk_label(btn, 9, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.name = "Label"
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if cb.is_valid():
		btn.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
					and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				cb.call())
	return btn


func _hilite_tab(tab: Panel, on: bool) -> void:
	var sb: StyleBoxFlat = tab.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	sb.border_color = GOLD if on else SLOT_BORDER
	sb.bg_color = SLOT_BG.lerp(GOLD, 0.14) if on else SLOT_BG
	var lbl: Label = tab.get_node_or_null("Label")
	if lbl != null:
		lbl.add_theme_color_override("font_color", GOLD if on else PARCHMENT)


func _mk_button(text: String, cb: Callable) -> Panel:
	var btn := _mk_tab(text, Vector2.ZERO, cb)
	var sb: StyleBoxFlat = btn.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = SLOT_BG.lerp(EMBER, 0.10)
		sb.border_color = SLOT_BORDER_HOVER
	btn.mouse_entered.connect(func() -> void: _hilite_tab(btn, true))
	btn.mouse_exited.connect(func() -> void: _hilite_tab(btn, false))
	return btn


func _icon_for(d: Dictionary) -> Texture2D:
	var icon: String = str(d.get("icon", ""))
	if icon.begins_with("pixel:"):
		var id: String = icon.trim_prefix("pixel:")
		return _pixel_icon(id)
	return null


static func _pixel_icon(icon_id: String) -> Texture2D:
	if _pixel_script == null:
		if not ResourceLoader.exists(ICONS_PIXEL_PATH, "Script"):
			return null
		_pixel_script = load(ICONS_PIXEL_PATH) as GDScript
	if _pixel_script == null:
		return null
	if not bool(_pixel_script.call("has_icon", icon_id)):
		return null
	var tex_v: Variant = _pixel_script.call("get_tex", icon_id)
	return tex_v if tex_v is Texture2D else null
