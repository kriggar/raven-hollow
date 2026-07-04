class_name CraftingUI
extends CanvasLayer
## Graveyard-Keeper-styled crafting station panel for Raven Hollow: Emberfall
## — Phase C demo (SPEC_PHASE_C_DEMO.md §6b). Built entirely in code on the
## shared dark-aged-wood look (dark fill + Kenney panel_brown rim + gold
## Alagard title), layer 9 (with bag/sheet, above HUD 8, below dialogue 10),
## group "crafting_ui".
##
## Layout: centered station panel. LEFT — the station's recipe list (pixel
## icon + name; unlearned recipes render as "???" with a blacked-out icon).
## RIGHT — selected recipe details: output icon in a rarity ring, name in
## rarity color, flavor line in parchment, stat/use lines, material costs as
## "have/need" rows (parchment when met, ember red when short), and the Craft
## button (gold when craftable, greyed otherwise).
##
## Opens ONLY via open_station("forge"|"hearth") — walking up to a station
## and pressing E is the integrator's loop (below). E ("interact") or Esc
## closes; like DialogueUI, is_open stays true for CLOSE_GUARD_TICKS physics
## ticks after closing so the player's POLLED interact can never instantly
## re-open the station (or talk to an NPC through the closing panel).
## Dialogue-gated: refuses to open during a conversation and auto-closes if
## one starts. Refreshes live on the player Inventory's bag_changed.
##
## show_toast(text, color) is public: crafting uses it for "Crafted: …" /
## "Your bag is full.", and the bag right-click integration reuses it for
## "Recipe learned: …" toasts.
##
## ============================= INTEGRATION =============================
## Hooks EXPECTED from the integration pass (this file compiles and works
## standalone given scripts/crafting.gd from the same workspace):
##
## 1. main.gd (bootstrap) — instance once next to BagUI:
##        var crafting_ui := CraftingUI.new()
##        add_child(crafting_ui)   # any parent; it is a CanvasLayer
##
## 2. town_builder.gd — station interactables. Extend the build() return
##    dict with:
##        "stations": [
##            {"id": "forge",  "pos": <Goran's anvil pos + (0, 16)>,
##             "radius": 30.0, "prompt": "[E] Craft — Goran's Forge"},
##            {"id": "hearth", "pos": <inn hearth/fireplace pos>,
##             "radius": 30.0, "prompt": "[E] Craft — The Inn Hearth"},
##        ]
##    (Wilderness map ships NO stations per spec §6b.) The forge should sit
##    at the smithy's existing anvil prop; the hearth inside/behind the inn
##    doorway so the prompt reads from the courtyard.
##
## 3. main.gd or player.gd (station loop, mirrors the nearest-NPC pattern):
##    each physics tick find the nearest station within its radius; when one
##    is near AND no dialogue is open AND crafting_ui.is_open == false, show
##    its prompt (reuse DialogueUI's gold [E] prompt label or a twin of it);
##    on Input.is_action_just_pressed("interact") call:
##        crafting_ui.open_station(station["id"])
##    ALWAYS test crafting_ui.is_open before opening — it stays true through
##    the close guard, which is what stops the closing E press from
##    re-opening the panel on the very next tick.
##
## 4. bag_ui.gd (right-click consumables/scrolls — see crafting.gd's block
##    for the exact snippet): on success it can toast through this node:
##        var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
##        if cui != null and cui.has_method("show_toast"):
##            cui.call("show_toast", "Recipe learned: %s" % name)
## =======================================================================

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const PARCHMENT_DIM := Color(0.55, 0.51, 0.44)
const EMBER_RED := Color(0.82, 0.34, 0.26)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SLOT_BORDER_HOVER := Color(0.62, 0.48, 0.26)
const UNKNOWN_SILHOUETTE := Color(0.10, 0.08, 0.06)

const PANEL_W: float = 312.0
const PANEL_H: float = 208.0
const TITLE_H: float = 30.0
const LIST_X: float = 12.0
const LIST_W: float = 122.0
const ROW_H: float = 26.0
const ROW_GAP: float = 3.0
const DETAIL_X: float = 146.0
const DETAIL_W: float = 154.0   # PANEL_W - DETAIL_X - 12 right pad
const BTN_W: float = 76.0
const BTN_H: float = 20.0

## Same trick as DialogueUI: the E press that closes the panel is still in
## its just-pressed window on the NEXT physics tick for anything polling the
## Input singleton; holding is_open for two ticks lets that window pass.
const CLOSE_GUARD_TICKS: int = 2

## Station id -> panel copy. Unknown ids degrade to a capitalized id.
const STATIONS := {
	"forge": {
		"title": "Goran's Forge",
		"subtitle": "Bring your own iron. The anvil keeps no secrets.",
	},
	"hearth": {
		"title": "The Inn Hearth",
		"subtitle": "Marta's pot has fed worse hours than this one.",
	},
}

var is_open: bool = false
var station_id: String = ""

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _panel: Control
var _title: Label
var _subtitle: Label
var _list_root: Control
## One Dictionary per visible recipe row:
## {panel, sb_normal, sb_hover, sb_selected, icon, label, recipe_id, known}.
var _rows: Array[Dictionary] = []
var _selected: int = -1

var _detail_root: Control
var _detail_icon: TextureRect
var _detail_rim: Panel
var _detail_rim_sb: StyleBoxFlat
var _detail_name: Label
var _detail_flavor: Label
var _detail_lines: VBoxContainer
var _craft_btn: Panel
var _craft_label: Label
var _craft_sb_off: StyleBoxFlat
var _craft_sb_on: StyleBoxFlat
var _craft_sb_hover: StyleBoxFlat
var _craft_hover: bool = false

var _toast: Label
var _toast_tween: Tween
var _open_tween: Tween
var _flash_tween: Tween
var _close_ticks: int = 0
var _inv: Variant = null  # the player's Inventory (RefCounted), duck-typed


func _ready() -> void:
	layer = 9
	add_to_group("crafting_ui")
	_build_panel()
	_build_toast()
	set_physics_process(false)


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	_sync_inventory()
	if _dialogue_open():
		close()  # conversations read over everything on layer 10


## Close-guard countdown (see CLOSE_GUARD_TICKS).
func _physics_process(_delta: float) -> void:
	if _close_ticks <= 0:
		set_physics_process(false)
		return
	_close_ticks -= 1
	if _close_ticks == 0:
		set_physics_process(false)
		if not _panel.visible:
			is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not _panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --- open / close --------------------------------------------------------------

## Opens the panel for a station ("forge" / "hearth"). No-ops while a
## dialogue runs, while already open (incl. the close guard), or before a
## player exists.
func open_station(id: String) -> void:
	if is_open or _dialogue_open():
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	station_id = id
	_close_ticks = 0
	is_open = true
	_sync_inventory()
	var info: Dictionary = STATIONS.get(id, {})
	_title.text = str(info.get("title", id.capitalize()))
	_subtitle.text = str(info.get("subtitle", ""))
	_rebuild_rows()
	_panel.visible = true  # before _select: _refresh no-ops on a hidden panel
	_select(0 if not _rows.is_empty() else -1)
	_panel.pivot_offset = _panel.size * 0.5
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not is_open or not _panel.visible:
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.visible = false
	_panel.scale = Vector2.ONE
	_panel.modulate = Color.WHITE
	# is_open stays true across the closing press's just-pressed window.
	_close_ticks = CLOSE_GUARD_TICKS
	set_physics_process(true)


# --- inventory hookup ----------------------------------------------------------

func _sync_inventory() -> void:
	var inv: Variant = null
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var inv_v: Variant = player.get("inventory")
		if inv_v is Object and is_instance_valid(inv_v):
			inv = inv_v
	if inv == _inv:
		return
	_disconnect_inv()
	_inv = inv
	if _inv != null:
		_inv.bag_changed.connect(_refresh)
	_refresh()


func _disconnect_inv() -> void:
	if _inv == null or not is_instance_valid(_inv):
		return
	if _inv.bag_changed.is_connected(_refresh):
		_inv.bag_changed.disconnect(_refresh)


# --- recipe list ---------------------------------------------------------------

func _rebuild_rows() -> void:
	for row: Dictionary in _rows:
		(row["panel"] as Panel).queue_free()
	_rows.clear()
	_selected = -1
	var recipes: Array[Dictionary] = Crafting.recipes_for_station(station_id)
	for i: int in recipes.size():
		_build_row(i, recipes[i])


func _build_row(idx: int, recipe: Dictionary) -> void:
	var recipe_id: String = str(recipe.get("id", ""))
	var known: bool = Crafting.is_known(recipe_id)

	var panel := Panel.new()
	panel.name = "RecipeRow%d" % idx
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = Vector2(0.0, float(idx) * (ROW_H + ROW_GAP))
	panel.size = Vector2(LIST_W, ROW_H)
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = SLOT_BG
	sb_normal.border_color = SLOT_BORDER
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(0)
	var sb_hover: StyleBoxFlat = sb_normal.duplicate() as StyleBoxFlat
	sb_hover.border_color = SLOT_BORDER_HOVER
	var sb_selected: StyleBoxFlat = sb_normal.duplicate() as StyleBoxFlat
	sb_selected.border_color = GOLD
	sb_selected.bg_color = Color(0.11, 0.085, 0.06, 0.96)
	panel.add_theme_stylebox_override("panel", sb_normal)
	_list_root.add_child(panel)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var output: Dictionary = Crafting.get_item(str(recipe.get("output", recipe_id)))
	icon.texture = Crafting.icon_texture(str(output.get("icon", "")))
	icon.position = Vector2(4.0, 4.0)
	icon.size = Vector2(ROW_H - 8.0, ROW_H - 8.0)
	# Unlearned recipes show only a blacked-out silhouette (GK-style tease).
	icon.modulate = Color.WHITE if known else UNKNOWN_SILHOUETTE
	panel.add_child(icon)

	var label := Label.new()
	label.name = "Name"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override(
		"font_color", PARCHMENT if known else PARCHMENT_DIM)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 2)
	label.text = str(recipe.get("name", recipe_id)) if known else "???"
	label.position = Vector2(ROW_H - 1.0, 0.0)
	label.size = Vector2(LIST_W - ROW_H - 2.0, ROW_H)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	panel.add_child(label)

	panel.gui_input.connect(_on_row_gui_input.bind(idx))
	panel.mouse_entered.connect(_on_row_entered.bind(idx))
	panel.mouse_exited.connect(_on_row_exited.bind(idx))

	_rows.append({
		"panel": panel,
		"sb_normal": sb_normal,
		"sb_hover": sb_hover,
		"sb_selected": sb_selected,
		"icon": icon,
		"label": label,
		"recipe_id": recipe_id,
		"known": known,
	})


func _on_row_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		(_rows[idx]["panel"] as Panel).accept_event()
		_select(idx)


func _on_row_entered(idx: int) -> void:
	if idx != _selected:
		var row: Dictionary = _rows[idx]
		(row["panel"] as Panel).add_theme_stylebox_override("panel", row["sb_hover"])


func _on_row_exited(idx: int) -> void:
	if idx != _selected and idx < _rows.size():
		var row: Dictionary = _rows[idx]
		(row["panel"] as Panel).add_theme_stylebox_override("panel", row["sb_normal"])


func _select(idx: int) -> void:
	_selected = idx
	for i: int in _rows.size():
		var row: Dictionary = _rows[i]
		var sb: StyleBoxFlat = row["sb_selected"] if i == idx else row["sb_normal"]
		(row["panel"] as Panel).add_theme_stylebox_override("panel", sb)
	_refresh()


# --- details pane ---------------------------------------------------------------

## Repaints the details pane + row known-state for the current selection.
## Connected to the inventory's bag_changed so have/need counts stay live.
func _refresh() -> void:
	if not _panel.visible:
		return
	# A scroll learned while the panel is open upgrades its "???" row live.
	for row: Dictionary in _rows:
		if not bool(row["known"]) and Crafting.is_known(str(row["recipe_id"])):
			row["known"] = true
			(row["icon"] as TextureRect).modulate = Color.WHITE
			var lbl: Label = row["label"]
			lbl.text = Crafting.recipe_name(str(row["recipe_id"]))
			lbl.add_theme_color_override("font_color", PARCHMENT)
	for child: Node in _detail_lines.get_children():
		_detail_lines.remove_child(child)  # instant relayout; deletion deferred
		child.queue_free()
	if _selected < 0 or _selected >= _rows.size():
		_detail_root.visible = false
		return
	_detail_root.visible = true
	var row: Dictionary = _rows[_selected]
	var recipe_id: String = str(row["recipe_id"])
	var known: bool = bool(row["known"])
	var recipe: Dictionary = Crafting.RECIPES.get(recipe_id, {})
	var output: Dictionary = Crafting.get_item(str(recipe.get("output", recipe_id)))

	_detail_icon.texture = Crafting.icon_texture(str(output.get("icon", "")))
	_detail_icon.modulate = Color.WHITE if known else UNKNOWN_SILHOUETTE
	var rarity: String = str(output.get("rarity", "common"))
	_detail_rim_sb.border_color = Items.rarity_color(rarity) if known else SLOT_BORDER
	_detail_name.text = str(output.get("name", recipe_id)) if known else "???"
	_detail_name.add_theme_color_override(
		"font_color", Items.rarity_color(rarity) if known else PARCHMENT_DIM)

	if not known:
		_detail_flavor.text = "Not yet learned. Recipes turn up where people stopped needing them."
		_set_craft_enabled(false)
		return
	_detail_flavor.text = str(output.get("flavor", ""))

	for line: Dictionary in _stat_lines(output):
		_add_detail_line(str(line["text"]), line["color"] as Color, 9)
	_add_detail_line("Materials:", GOLD, 9)
	var cost: Dictionary = recipe.get("cost", {})
	for mat_id: String in cost:
		var need: int = int(cost[mat_id])
		var have: int = Crafting.count_in(_inv as Inventory, mat_id) if _inv is Inventory else 0
		var mat: Dictionary = Crafting.get_item(mat_id)
		var color: Color = PARCHMENT if have >= need else EMBER_RED
		_add_material_line(str(mat.get("name", mat_id)), str(mat.get("icon", "")),
			"%d/%d" % [have, need], color)

	_set_craft_enabled(
		_inv is Inventory and Crafting.can_craft(recipe_id, _inv as Inventory))


## Stat/use lines for an output item: crafted gear lists its nonzero stats;
## consumables describe their use_effect instead.
func _stat_lines(output: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fx: Dictionary = output.get("use_effect", {})
	match str(fx.get("kind", "")):
		"heal":
			out.append({"text": "Use: restores %d health." % int(fx.get("amount", 0.0)),
				"color": PARCHMENT})
			return out
		"regen_hp":
			out.append({"text": "Use: +%d health/sec for %ds." %
				[int(fx.get("amount", 0.0)), int(fx.get("duration", 0.0))],
				"color": PARCHMENT})
			return out
	const LABELS := {
		"damage": "%+d Damage", "armor": "%+d Armor", "hp": "%+d Health",
		"mana": "%+d Mana", "speed_pct": "%+d%% Speed",
		"crit_pct": "%+d%% Crit", "mana_regen": "%+d Mana Regen",
	}
	var stats: Dictionary = output.get("stats", {})
	for key: String in LABELS:
		var v: float = float(stats.get(key, 0.0))
		if v != 0.0:
			out.append({"text": (LABELS[key] as String) % int(v), "color": PARCHMENT})
	return out


func _add_detail_line(text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 2)
	label.text = text
	_detail_lines.add_child(label)


## One "have/need" cost row: tiny material icon + name left, count right.
func _add_material_line(mat_name: String, icon_id: String, counts: String, color: Color) -> void:
	var line := Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(DETAIL_W, 13.0)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = Crafting.icon_texture(icon_id)
	icon.position = Vector2(4.0, 1.0)
	icon.size = Vector2(11.0, 11.0)
	line.add_child(icon)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", _font)
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.text = mat_name
	name_label.position = Vector2(19.0, 0.0)
	name_label.size = Vector2(DETAIL_W - 60.0, 13.0)
	name_label.clip_text = true
	line.add_child(name_label)

	var count_label := Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_override("font", _font)
	count_label.add_theme_font_size_override("font_size", 9)
	count_label.add_theme_color_override("font_color", color)
	count_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	count_label.add_theme_constant_override("outline_size", 2)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.text = counts
	count_label.position = Vector2(DETAIL_W - 42.0, 0.0)
	count_label.size = Vector2(38.0, 13.0)
	line.add_child(count_label)

	_detail_lines.add_child(line)


# --- craft button ----------------------------------------------------------------

func _set_craft_enabled(enabled: bool) -> void:
	_craft_btn.set_meta("enabled", enabled)
	_apply_craft_style()


func _apply_craft_style() -> void:
	var enabled: bool = bool(_craft_btn.get_meta("enabled", false))
	var sb: StyleBoxFlat = _craft_sb_off
	if enabled:
		sb = _craft_sb_hover if _craft_hover else _craft_sb_on
	_craft_btn.add_theme_stylebox_override("panel", sb)
	_craft_label.add_theme_color_override(
		"font_color", GOLD if enabled else PARCHMENT_DIM)


func _on_craft_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_craft_btn.accept_event()
	if not bool(_craft_btn.get_meta("enabled", false)):
		return
	if _selected < 0 or not (_inv is Inventory):
		return
	var recipe_id: String = str(_rows[_selected]["recipe_id"])
	var crafted: Dictionary = Crafting.craft(recipe_id, _inv as Inventory)
	if crafted.is_empty():
		# can_craft held materials+knowledge, so the only honest failure left
		# is a bag with no room for the output.
		show_toast("Your bag is full.", EMBER_RED)
		return
	show_toast("Crafted: %s" % str(crafted.get("name", recipe_id)))
	_flash_detail_icon()
	# _refresh already ran via bag_changed; the press punch sells the strike.
	_craft_btn.scale = Vector2(0.92, 0.92)
	var t: Tween = create_tween()
	t.tween_property(_craft_btn, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_detail_icon() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_detail_icon.modulate = Color(1.6, 1.45, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_detail_icon, "modulate", Color.WHITE, 0.35)


# --- toast -----------------------------------------------------------------------

## Bottom-center announcement ("Crafted: …", "Recipe learned: …"). Public —
## the bag right-click integration reuses it (see the INTEGRATION block).
func show_toast(text: String, color: Color = GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.visible = true
	_toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- construction ----------------------------------------------------------------

func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "StationPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = -PANEL_H * 0.5
	_panel.offset_bottom = PANEL_H * 0.5
	add_child(_panel)

	# Dark fill inset under the aged-wood rim (shared HUD/bag recipe).
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(PANEL_W - 6.0, PANEL_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.set_border_width_all(0)
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

	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_title.add_theme_constant_override("outline_size", 2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0.0, 7.0)
	_title.size = Vector2(PANEL_W, 14.0)
	_panel.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_override("font", _font)
	_subtitle.add_theme_font_size_override("font_size", 8)
	_subtitle.add_theme_color_override("font_color", PARCHMENT_DIM)
	_subtitle.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_subtitle.add_theme_constant_override("outline_size", 2)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0.0, 20.0)
	_subtitle.size = Vector2(PANEL_W, 10.0)
	_panel.add_child(_subtitle)

	_list_root = Control.new()
	_list_root.name = "RecipeList"
	_list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_root.position = Vector2(LIST_X, TITLE_H + 6.0)
	_list_root.size = Vector2(LIST_W, PANEL_H - TITLE_H - 18.0)
	_panel.add_child(_list_root)

	# Thin divider between list and details.
	var divider := Panel.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(LIST_X + LIST_W + 5.0, TITLE_H + 6.0)
	divider.size = Vector2(1.0, PANEL_H - TITLE_H - 24.0)
	var div_sb := StyleBoxFlat.new()
	div_sb.bg_color = SLOT_BORDER
	divider.add_theme_stylebox_override("panel", div_sb)
	_panel.add_child(divider)

	_build_details()

	var hint := Label.new()
	hint.name = "CloseHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", PARCHMENT_DIM)
	hint.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	hint.add_theme_constant_override("outline_size", 2)
	hint.text = "[E] Close"
	hint.position = Vector2(LIST_X, PANEL_H - 16.0)
	hint.size = Vector2(60.0, 10.0)
	_panel.add_child(hint)


func _build_details() -> void:
	_detail_root = Control.new()
	_detail_root.name = "Details"
	_detail_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_root.position = Vector2(DETAIL_X, TITLE_H + 6.0)
	_detail_root.size = Vector2(DETAIL_W, PANEL_H - TITLE_H - 18.0)
	_panel.add_child(_detail_root)

	# Output icon in a rarity ring.
	var slot := Panel.new()
	slot.name = "OutputSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(0.0, 0.0)
	slot.size = Vector2(28.0, 28.0)
	var slot_sb := StyleBoxFlat.new()
	slot_sb.bg_color = SLOT_BG
	slot_sb.border_color = SLOT_BORDER
	slot_sb.set_border_width_all(1)
	slot_sb.set_corner_radius_all(0)
	slot.add_theme_stylebox_override("panel", slot_sb)
	_detail_root.add_child(slot)

	_detail_rim = Panel.new()
	_detail_rim.name = "RarityRim"
	_detail_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_rim.position = Vector2(2.0, 2.0)
	_detail_rim.size = Vector2(24.0, 24.0)
	_detail_rim_sb = StyleBoxFlat.new()
	_detail_rim_sb.draw_center = false
	_detail_rim_sb.set_border_width_all(1)
	_detail_rim_sb.set_corner_radius_all(0)
	_detail_rim.add_theme_stylebox_override("panel", _detail_rim_sb)
	slot.add_child(_detail_rim)

	_detail_icon = TextureRect.new()
	_detail_icon.name = "OutputIcon"
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.position = Vector2(4.0, 4.0)
	_detail_icon.size = Vector2(20.0, 20.0)
	slot.add_child(_detail_icon)

	_detail_name = Label.new()
	_detail_name.name = "OutputName"
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_name.add_theme_font_override("font", _font)
	_detail_name.add_theme_font_size_override("font_size", 10)
	_detail_name.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_detail_name.add_theme_constant_override("outline_size", 2)
	_detail_name.position = Vector2(33.0, 0.0)
	_detail_name.size = Vector2(DETAIL_W - 33.0, 28.0)
	_detail_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_root.add_child(_detail_name)

	_detail_flavor = Label.new()
	_detail_flavor.name = "Flavor"
	_detail_flavor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_flavor.add_theme_font_override("font", _font)
	_detail_flavor.add_theme_font_size_override("font_size", 8)
	_detail_flavor.add_theme_color_override("font_color", PARCHMENT_DIM)
	_detail_flavor.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_detail_flavor.add_theme_constant_override("outline_size", 2)
	_detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_flavor.position = Vector2(0.0, 31.0)
	_detail_flavor.size = Vector2(DETAIL_W, 28.0)
	_detail_root.add_child(_detail_flavor)

	_detail_lines = VBoxContainer.new()
	_detail_lines.name = "Lines"
	_detail_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_lines.add_theme_constant_override("separation", 1)
	_detail_lines.position = Vector2(0.0, 62.0)
	_detail_lines.size = Vector2(DETAIL_W, 76.0)
	_detail_root.add_child(_detail_lines)

	_craft_btn = Panel.new()
	_craft_btn.name = "CraftButton"
	_craft_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_btn.position = Vector2(DETAIL_W - BTN_W, _detail_root.size.y - BTN_H - 2.0)
	_craft_btn.size = Vector2(BTN_W, BTN_H)
	_craft_btn.pivot_offset = Vector2(BTN_W, BTN_H) * 0.5
	_craft_sb_off = StyleBoxFlat.new()
	_craft_sb_off.bg_color = SLOT_BG
	_craft_sb_off.border_color = SLOT_BORDER
	_craft_sb_off.set_border_width_all(1)
	_craft_sb_off.set_corner_radius_all(0)
	_craft_sb_on = _craft_sb_off.duplicate() as StyleBoxFlat
	_craft_sb_on.border_color = GOLD
	_craft_sb_hover = _craft_sb_on.duplicate() as StyleBoxFlat
	_craft_sb_hover.bg_color = Color(0.13, 0.10, 0.06, 0.96)
	_craft_sb_hover.shadow_color = Color(0.85, 0.68, 0.35, 0.25)
	_craft_sb_hover.shadow_size = 3
	_craft_sb_hover.shadow_offset = Vector2.ZERO
	_craft_btn.add_theme_stylebox_override("panel", _craft_sb_off)
	_craft_btn.set_meta("enabled", false)
	_detail_root.add_child(_craft_btn)
	# The details root ignores mouse, but STOP on the button re-arms it.
	_craft_btn.gui_input.connect(_on_craft_gui_input)
	_craft_btn.mouse_entered.connect(func() -> void:
		_craft_hover = true
		_apply_craft_style())
	_craft_btn.mouse_exited.connect(func() -> void:
		_craft_hover = false
		_apply_craft_style())

	_craft_label = Label.new()
	_craft_label.name = "CraftLabel"
	_craft_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_label.add_theme_font_override("font", _font)
	_craft_label.add_theme_font_size_override("font_size", 10)
	_craft_label.add_theme_color_override("font_color", PARCHMENT_DIM)
	_craft_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_craft_label.add_theme_constant_override("outline_size", 2)
	_craft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_craft_label.text = "Craft"
	_craft_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft_btn.add_child(_craft_label)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.name = "CraftToast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_override("font", _font)
	_toast.add_theme_font_size_override("font_size", 11)
	_toast.add_theme_color_override("font_color", GOLD)
	_toast.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -120.0
	_toast.offset_bottom = -106.0
	_toast.visible = false
	add_child(_toast)


# --- helpers ---------------------------------------------------------------------

func _dialogue_open() -> bool:
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	return dlg != null and dlg.get("is_open") == true
