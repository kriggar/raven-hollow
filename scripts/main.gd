extends Node2D
## Bootstrap for "Raven Hollow" (Phase C demo).
## Boots to the title/main menu first (MainMenu): "New Game" runs class-select
## then builds the town; "Continue" loads a save and rebuilds the saved map.
## Headless automation hooks (RH_CLASS / RH_SMOKE / RH_SHOT / RH_SELECT /
## RH_MENU / RH_WIDE / RH_ZOOM / RH_FOCUS / RH_TALK / RH_CAST / RH_UI /
## RH_EQUIP / RH_NOBANNER) SKIP the menu and boot straight into gameplay, New
## Game style, exactly as they did before Phase C.
##
## Owns the Phase C central wiring: change_map(map_id, entry_point_id) (fade /
## free / rebuild / place / camera / music / minimap / day-night / autosave),
## the travel-point + crafting-station world-prompt loop (_physics_process),
## the persistent DayNight + Quests system nodes (via the two save-adapter
## subclasses below), quest/xp/loot signal wiring, and the Mira escort beat.

const DUSK_TINT := Color(1.0, 0.87, 0.72)  # kept for reference; DayNight owns the tint now
const MUSIC_PATH := "res://assets/audio/music/theme_lost_village.ogg"
const MUSIC_VOLUME_DB := -14.0
const CAMERA_SMOOTH_SPEED := 6.0
const VIGNETTE_LAYER := 5  # below DialogueUI (layer 10) so UI never gets darkened
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.35)
const WIDE_ZOOM := 0.45
const SMOKE_FRAMES := 60
const SHOT_FRAMES := 40
const FALLBACK_CLASS := "warrior"
const SELECT_BACKDROP_LAYER := 15  # below ClassSelect (layer 20)
const CAST_WARMUP_FRAMES := 25
const CAST_GAP_FRAMES := 12
const CAST_SHOT_FRAMES := 6  # short delay so the shot catches the 3rd cast mid-flight
const CAST_STAND_POS := Vector2(1622.0, 950.0)  # 28 px from scarecrow: inside melee reach (range+8)
const CAST_TARGET_POS := Vector2(1650.0, 950.0)  # scarecrow

const DEFAULT_BOUNDS := Rect2(0.0, 0.0, 2240.0, 1600.0)
const FADE_LAYER := 25         # over the world, below the menus (30)
const FADE_TIME := 0.4
const WORLD_PROMPT_LAYER := 10
const GOLD := Color(0.85, 0.68, 0.35)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FONT_ALAGARD := "res://assets/fonts/alagard.ttf"

## Save-surface bridges (contract §2): both frozen files expose a save API that
## SaveSystem does NOT probe for. Subclassing adds the alias methods WITHOUT
## editing the frozen files. Both inherit _ready() (group self-join), _process,
## signals and every field of their base.
class QuestsNode extends Quests:
	func serialize() -> Dictionary:
		return to_save_dict()
	func deserialize(d: Dictionary) -> void:
		from_save_dict(d)


class DayNightNode extends DayNight:
	func get_time_hours() -> float:
		return time_of_day
	func set_time_hours(h: float) -> void:
		set_time(h)


## Readable by SaveSystem (get_tree().current_scene.get("current_map_id")) and
## by player.gd's quest-position ping. Set at the top of change_map + on boot.
var current_map_id: String = "town"

var _camera: Camera2D
var _player: Player
var _world: Node2D
var _built: Dictionary = {}
var _quests: QuestsNode
var _day_night: DayNightNode
var _weather: WeatherController
var _dialogue: DialogueUI
var _music: AudioStreamPlayer
var _world_prompt: Label

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

var _mira: NPC
var _q5_done: bool = false
var _changing_map: bool = false
var _pending_world_choice: bool = false


func _ready() -> void:
	# 0. Automation: an explicit/forced class choice skips ALL menus and boots
	#    straight into a New-Game town, exactly as before Phase C.
	var chosen: String = _resolve_class_choice()
	if not chosen.is_empty():
		_bootstrap_world(chosen)
		return
	# RH_SELECT scheduled a class-select screenshot — go straight to the select
	# screen (never the main menu) so the harness captures the right UI.
	if not OS.get_environment("RH_SELECT").is_empty():
		var cls_sel: String = await _prompt_class_select()
		_bootstrap_world(cls_sel)
		return
	# RH_MENU: visual QA of the title screen (optionally screenshot + quit).
	if not OS.get_environment("RH_MENU").is_empty() and not OS.get_environment("RH_SHOT").is_empty():
		_schedule_menu_screenshot(OS.get_environment("RH_SHOT"))
	# 1. Normal boot: the title / main menu.
	await _run_menu()


# =============================================================================
# BOOT: main menu -> new game / continue / quit
# =============================================================================

func _run_menu() -> void:
	var action: String = await _prompt_main_menu()
	match action:
		"new_game":
			var cls: String = await _prompt_class_select()
			SaveSystem.delete_save()
			_bootstrap_world(cls)
		"continue":
			var data: Dictionary = SaveSystem.load_game()
			if data.is_empty():
				var cls: String = await _prompt_class_select()
				_bootstrap_world(cls)
			else:
				_bootstrap_world_from_save(data)
		_:
			pass  # "quit": MainMenu quits the tree itself after its fade.


func _prompt_main_menu() -> String:
	var m := MainMenu.new()
	add_child(m)
	var a: String = await m.menu_choice
	return a


func _schedule_menu_screenshot(path: String) -> void:
	var capture := func() -> void:
		for _i in range(50):
			await get_tree().process_frame
		_save_screenshot(path)
		get_tree().quit(0)
	capture.call()


func _resolve_class_choice() -> String:
	## Returns a class id when the menus must be skipped, else "".
	# RH_SELECT: show the select screen even under automation, screenshot it,
	# and quit — used to visually verify the class-select UI.
	if not OS.get_environment("RH_SELECT").is_empty():
		_screenshot_select_screen()
		return ""
	var env_id: String = OS.get_environment("RH_CLASS")
	if not env_id.is_empty():
		if ClassDefs.all_ids().has(env_id):
			return env_id
		push_warning("main.gd: RH_CLASS '%s' is not a valid class id — using '%s'." % [env_id, FALLBACK_CLASS])
		return FALLBACK_CLASS
	# Headless automation without an explicit class must never hang on a menu.
	if not OS.get_environment("RH_SMOKE").is_empty() or not OS.get_environment("RH_SHOT").is_empty():
		# RH_MENU asks to keep the menu even under RH_SHOT (title-screen QA).
		if OS.get_environment("RH_MENU").is_empty():
			return FALLBACK_CLASS
	return ""


func _screenshot_select_screen() -> void:
	var shot_path: String = OS.get_environment("RH_SHOT")
	if shot_path.is_empty():
		return
	var capture := func() -> void:
		for _i in range(50):
			await get_tree().process_frame
		_save_screenshot(shot_path)
		get_tree().quit(0)
	capture.call()


func _prompt_class_select() -> String:
	var backdrop := CanvasLayer.new()
	backdrop.name = "SelectBackdrop"
	backdrop.layer = SELECT_BACKDROP_LAYER
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(black)
	add_child(backdrop)
	var select := ClassSelect.new()
	add_child(select)
	var chosen: String = await select.class_chosen
	backdrop.queue_free()
	return chosen


# =============================================================================
# WORLD BOOTSTRAP (New Game)
# =============================================================================

func _bootstrap_world(class_id: String) -> void:
	set_physics_process(true)
	current_map_id = "town"
	Crafting.reset()  # fresh known-recipe set on a New Game

	# Persistent systems FIRST (children of Main, NOT World) so the world build
	# can attach the day/night CanvasModulate and so signal wiring finds them.
	_spawn_systems()

	# World + town content.
	var info: Dictionary = _build_map("town")
	var def: Dictionary = info["def"]
	var built: Dictionary = info["built"]
	_built = built

	# Player at the builder spawn.
	var player: Player = Player.create(built.get("player_spawn", Vector2.ZERO), class_id)
	_world.add_child(player)
	_player = player

	# Gate + NPC cast + enemies + light registry.
	_post_build_map("town", _world, built)

	# Camera rides the player.
	_camera = _make_camera(built.get("bounds", DEFAULT_BOUNDS))
	player.add_child(_camera)

	# UI stack.
	_spawn_ui()

	# Music + vignette.
	_start_music_for_def(def)
	add_child(_make_vignette())

	# Arrival banner (subtitle = the chosen class title).
	if OS.get_environment("RH_NOBANNER").is_empty() and _dialogue != null:
		var subtitle: String = str(player.class_def.get("title", "The Emberfall Road"))
		_dialogue.show_banner("Raven Hollow", subtitle)

	# Quest / xp / loot signal wiring; minimap + tracker.
	_wire_quest_signals()
	_refresh_minimap("town", built, def)
	if _weather != null:
		_weather.on_map_changed("town")
	_push_tracker()
	if _quests != null and _day_night != null:
		_quests.set_night(_day_night.is_night)

	# Camera can only become current once inside the tree.
	await get_tree().process_frame
	_camera.make_current()

	# Headless automation hooks (no-ops in a normal run).
	_run_env_hooks()


func _bootstrap_world_from_save(data: Dictionary) -> void:
	set_physics_process(true)
	var p: Dictionary = data.get("player", {})
	var class_id: String = str(p.get("class", FALLBACK_CLASS))
	var map_id: String = str(data.get("map", "town"))
	if not MapRegistry.has_map(map_id):
		map_id = "town"
	current_map_id = map_id

	_spawn_systems()

	var info: Dictionary = _build_map(map_id)
	var def: Dictionary = info["def"]
	var built: Dictionary = info["built"]
	_built = built

	# Player created at the map spawn, then the saved state is pushed onto it
	# AFTER it is in-tree with its seeded starting inventory.
	var player: Player = Player.create(built.get("player_spawn", Vector2.ZERO), class_id)
	_world.add_child(player)
	_player = player

	_post_build_map(map_id, _world, built)

	_camera = _make_camera(built.get("bounds", DEFAULT_BOUNDS))
	player.add_child(_camera)

	_spawn_ui()
	_start_music_for_def(def)
	add_child(_make_vignette())
	_wire_quest_signals()

	# Restore player, then systems (quests / recipes / clock via the adapters).
	SaveSystem.apply_player_state(data, player)
	SaveSystem.apply_systems_state(data)

	_refresh_minimap(map_id, built, def)
	_push_tracker()
	if _quests != null and _day_night != null:
		_quests.set_night(_day_night.is_night)

	await get_tree().process_frame
	_camera.make_current()


# =============================================================================
# SYSTEM + UI BOOTSTRAP
# =============================================================================

func _spawn_systems() -> void:
	var q := QuestsNode.new()
	q.name = "Quests"
	add_child(q)
	_quests = q

	var dn := DayNightNode.new()  # _init() names it "DayNight"
	add_child(dn)
	_day_night = dn
	dn.night_changed.connect(_on_night_changed)

	var wx := WeatherController.new()  # _init() names it "Weather"
	add_child(wx)
	_weather = wx


func _spawn_ui() -> void:
	# Layer bands (set by the scripts themselves): HUD 8, Minimap 8, Bag/Sheet 9,
	# CraftingUI 9, Dialogue 10, PauseMenu 30.
	add_child(HUD.new())
	add_child(Minimap.new())
	add_child(BagUI.new())
	add_child(CharacterSheetUI.new())
	add_child(CraftingUI.new())

	var ui := DialogueUI.new()
	add_child(ui)
	_dialogue = ui

	var pause := PauseMenu.new()
	add_child(pause)
	pause.quit_to_menu.connect(_on_quit_to_menu)

	_build_world_prompt()


func _build_world_prompt() -> void:
	var cl := CanvasLayer.new()
	cl.name = "WorldPromptLayer"
	cl.layer = WORLD_PROMPT_LAYER
	var lbl := Label.new()
	lbl.name = "WorldPrompt"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: FontFile = load(FONT_ALAGARD)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", GOLD)
	lbl.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Bottom-center, lifted above DialogueUI's own "[E] Talk" prompt.
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.offset_top = -96.0
	lbl.offset_bottom = -78.0
	lbl.visible = false
	cl.add_child(lbl)
	add_child(cl)
	_world_prompt = lbl


func _show_world_prompt(text: String) -> void:
	if _world_prompt == null:
		return
	_world_prompt.text = text
	_world_prompt.visible = true


func _hide_world_prompt() -> void:
	if _world_prompt != null:
		_world_prompt.visible = false


# =============================================================================
# MAP BUILD / CHANGE
# =============================================================================

## Builds the world root for `map_id`, attaches a fresh DuskModulate to the
## DayNight controller, and returns {def, built, world}. Does NOT place the
## player or run per-map post-build (callers do, so the New-Game / Continue /
## change_map paths can order player creation differently).
func _build_map(map_id: String) -> Dictionary:
	var def: Dictionary = MapRegistry.get_map(map_id)
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	var built: Dictionary = {}
	var builder_v: Variant = def.get("builder")
	if builder_v is Callable and (builder_v as Callable).is_valid():
		var out: Variant = (builder_v as Callable).call(world)
		if out is Dictionary:
			built = out
	else:
		push_error("main.gd: no builder for map '%s'." % map_id)
	add_child(world)
	_world = world

	# DayNight owns the world tint from now on (§8): build the CanvasModulate but
	# do NOT hard-set its color — DayNight's 17:00 start == the old DUSK_TINT.
	var dusk := CanvasModulate.new()
	dusk.name = "DuskModulate"
	world.add_child(dusk)
	if _day_night != null:
		_day_night.attach_canvas_modulate(dusk)

	return {"def": def, "built": built, "world": world}


func _post_build_map(map_id: String, world: Node2D, built: Dictionary) -> void:
	match map_id:
		"town":
			GateBuilder.add_gate(world)
			_spawn_npc_cast(world, built.get("npc_spawns", {}))
			Combat.spawn_world_enemies(world)
		"wilderness":
			_spawn_npc_cast(world, built.get("npc_spawns", {}))
			Combat.spawn_map_enemies(world, built)
			if _quests != null:
				_quests.override_pos("q4_camp", built.get("camp_pos", Vector2.ZERO))
				_quests.override_pos("q5_treeline", built.get("listener_pos", Vector2.ZERO))
				_quests.override_pos("q5_gate", built.get("gate_pos", Vector2.ZERO))
		_:
			_spawn_npc_cast(world, built.get("npc_spawns", {}))
	# Register EVERY ambience light (town lanterns, gate lights, wilderness
	# fires) with DayNight in one robust tree walk (§8).
	_group_world_lights(world)


func _spawn_npc_cast(world: Node2D, spawns: Dictionary) -> void:
	for def: Dictionary in NPCData.cast():
		var role: String = def.id
		if spawns.has(role):
			var spawn: Dictionary = spawns[role]
			def.pos = spawn.pos
			def.wander_radius = spawn.wander_radius
			world.add_child(NPC.create(def))
		# Roles without a spawn (e.g. dynamic Mira) are SILENTLY skipped.


func _group_world_lights(root: Node) -> void:
	for l: Node in root.find_children("*", "PointLight2D", true, false):
		if not l.is_in_group("world_lights"):
			l.add_to_group("world_lights")


## Contract §3.4 — the central map transition.
func change_map(map_id: String, entry_point_id: String) -> void:
	if _changing_map or not MapRegistry.has_map(map_id):
		return
	_changing_map = true
	_hide_world_prompt()

	# 1. Fade to black.
	await _fade_to_black(FADE_TIME)

	# 2. Reparent the player OUT of the old world (it carries its camera,
	#    hp/xp/level/inventory), then free the old world + its CanvasModulate +
	#    that map's enemies/props (all children of World).
	var old_world: Node2D = _world
	if _player != null and is_instance_valid(_player):
		var pp: Node = _player.get_parent()
		if pp != null:
			pp.remove_child(_player)
	_despawn_mira()
	if old_world != null and is_instance_valid(old_world):
		old_world.queue_free()
	_world = null

	# 3. Current map id (before build — SaveSystem/quests read it).
	current_map_id = map_id

	# 4. Build the new world.
	var info: Dictionary = _build_map(map_id)
	var def: Dictionary = info["def"]
	var built: Dictionary = info["built"]
	_built = built

	# 5. Place the reused player at the entry travel point (fallback spawn),
	#    nudged toward map center to clear the return-trigger radius.
	_world.add_child(_player)
	var bounds: Rect2 = built.get("bounds", DEFAULT_BOUNDS)
	var place: Vector2 = built.get("player_spawn", Vector2.ZERO)
	var tp: Dictionary = MapRegistry.get_travel_point(map_id, entry_point_id)
	if not tp.is_empty():
		place = tp["pos"]
	var center: Vector2 = bounds.position + bounds.size * 0.5
	var toward: Vector2 = center - place
	if toward.length() > 1.0:
		place += toward.normalized() * 24.0
	if _player != null:
		_player.global_position = place

	# Camera survives on the player; just re-limit it (recreate if it was lost).
	if _camera == null or not is_instance_valid(_camera):
		_camera = _make_camera(bounds)
		if _player != null:
			_player.add_child(_camera)
	else:
		_apply_camera_limits(_camera, bounds)

	# 6. Per-map post build (npc/enemies/overrides/light registry).
	_post_build_map(map_id, _world, built)

	# 7. DayNight CanvasModulate already re-attached in _build_map; time carries.
	if _weather != null:
		_weather.on_map_changed(map_id)
	# 8. Music swap (survives the pause-menu volume).
	_start_music_for_def(def)
	get_tree().call_group("pause_menu", "apply_music_volume")

	# 9. Minimap. 10. Location banner.
	_refresh_minimap(map_id, built, def)
	if _dialogue != null:
		_dialogue.show_banner(str(def.get("display_name", "")), "")

	# 11. Fade in, then autosave. 12. Repaint tracker.
	await get_tree().process_frame
	_camera.make_current()
	await _fade_from_black(FADE_TIME)
	SaveSystem.save_game()
	_push_tracker()
	_changing_map = false


func _refresh_minimap(map_id: String, built: Dictionary, def: Dictionary = {}) -> void:
	var mm: Node = get_tree().get_first_node_in_group("minimap")
	if mm == null:
		return
	if def.is_empty():
		def = MapRegistry.get_map(map_id)
	mm.call("set_map", map_id, built.get("bounds", DEFAULT_BOUNDS),
		def.get("travel_points", []), str(def.get("display_name", "")))


# =============================================================================
# TRAVEL / STATION / MIRA — main.gd's _physics_process
# =============================================================================

func _physics_process(_delta: float) -> void:
	if _changing_map or _player == null or not is_instance_valid(_player):
		return

	_update_mira()

	# The world prompt only shows when no panel is open and the E press is NOT
	# claimed by a nearby NPC (player.gd owns that within 28 px).
	if _any_panel_open() or _nearest_npc_within(28.0) != null:
		_hide_world_prompt()
		return

	var ppos: Vector2 = _player.global_position

	# Crafting stations (town only ships them).
	var station: Dictionary = _nearest_station(ppos)
	if not station.is_empty():
		_show_world_prompt(str(station.get("prompt", "[E] Craft")))
		if Input.is_action_just_pressed("interact"):
			var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
			if cui != null and cui.get("is_open") != true:
				cui.call("open_station", str(station.get("id", "")))
		return

	# Travel points.
	for tp: Dictionary in MapRegistry.travel_points(current_map_id):
		if ppos.distance_to(tp["pos"]) <= float(tp["radius"]):
			_show_world_prompt(str(tp.get("prompt", "[E] Travel")))
			if Input.is_action_just_pressed("interact"):
				change_map(str(tp["to_map"]), str(tp["to_point"]))
			return

	_hide_world_prompt()


func _any_panel_open() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "pause_menu"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and n.get("is_open") == true:
			return true
	var mm: Node = get_tree().get_first_node_in_group("minimap")
	if mm != null and mm.has_method("is_world_map_open") and mm.call("is_world_map_open") == true:
		return true
	return false


func _nearest_npc_within(r: float) -> Node:
	var n: Node = _nearest_npc()
	if n != null and n is Node2D and (n as Node2D).global_position.distance_to(_player.global_position) <= r:
		return n
	return null


func _nearest_station(ppos: Vector2) -> Dictionary:
	var stations_v: Variant = _built.get("stations", [])
	if not (stations_v is Array):
		return {}
	var best: Dictionary = {}
	var best_d: float = INF
	for s: Dictionary in stations_v:
		var d: float = ppos.distance_to(s["pos"])
		if d <= float(s.get("radius", 30.0)) and d < best_d:
			best_d = d
			best = s
	return best


# --- Mira escort lifecycle (§11) --------------------------------------------

func _update_mira() -> void:
	if _quests == null or _day_night == null or _player == null or _world == null:
		return
	# Present only in the wilderness at night, until quest 5 completes.
	var want: bool = current_map_id == "wilderness" and _day_night.is_night and not _q5_done
	if not want:
		_despawn_mira()
		return
	if _mira == null or not is_instance_valid(_mira):
		var mdef: Dictionary = NPCData.by_id("mira")
		if mdef.is_empty():
			return
		mdef = mdef.duplicate(true)
		mdef["pos"] = _built.get("listener_pos", Vector2.ZERO)
		mdef["wander_radius"] = 10.0
		_mira = NPC.create(mdef)
		_world.add_child(_mira)

	# Escort-lite: re-home Mira just behind the player so her own locomotion
	# walks her along (uses NPC's built-in move + walk anim). The escort flag is
	# held true while she is active so the q5_gate reach can always fire (the
	# deadline-safe fallback — see contract §11).
	_quests.set_flag("escort_mira", true)
	var to_mira: Vector2 = _mira.global_position - _player.global_position
	var home: Vector2 = _player.global_position
	if to_mira.length() > 1.0:
		home = _player.global_position + to_mira.normalized() * 22.0
	_mira.set("_home", home)


func _despawn_mira() -> void:
	if _mira != null and is_instance_valid(_mira):
		_mira.queue_free()
	_mira = null


# =============================================================================
# QUEST / XP / LOOT SIGNAL WIRING (§5, §6, §7)
# =============================================================================

func _wire_quest_signals() -> void:
	if _quests == null:
		return
	_quests.quest_started.connect(func(_q: String) -> void: _push_tracker())
	_quests.quest_updated.connect(func(_q: String) -> void: _push_tracker())
	_quests.quest_completed.connect(func(_q: String) -> void: _push_tracker())
	_quests.quest_started.connect(func(q: String) -> void:
		if _dialogue != null:
			_dialogue.show_banner("New Quest", _quest_title(q)))
	_quests.rewards_granted.connect(_on_rewards_granted)
	_quests.item_granted.connect(_on_item_granted)
	_quests.objective_note.connect(func(text: String) -> void:
		if _dialogue != null:
			_dialogue.show_banner("", text))
	_quests.cinematic_beat.connect(func(beat: String) -> void:
		if beat == "listener_whisper":
			_dim_world_one_beat())
	_quests.quest_completed.connect(_on_quest_completed)
	_quests.quest_updated.connect(_on_quest_updated_choice)


func _on_night_changed(is_night_now: bool) -> void:
	if _quests != null:
		_quests.set_night(is_night_now)


## XP + gold rewards on quest turn-in (items arrive via item_granted only).
func _on_rewards_granted(_qid: String, r: Dictionary) -> void:
	if _player != null:
		XPSystem.grant_xp(_player, int(r.get("xp", 0)))
		var g_v: Variant = _player.get("gold")
		var g: int = int(g_v) if (g_v is int or g_v is float) else 0
		_player.set("gold", g + int(r.get("gold", 0)))
	SaveSystem.save_game()  # AUTOSAVE on turn-in


func _on_item_granted(id: String) -> void:
	if _player == null:
		return
	var it: Dictionary = Items.get_item(id)
	if it.is_empty():
		it = Crafting.get_item(id)
	var inv_v: Variant = _player.get("inventory")
	if not it.is_empty() and inv_v is Inventory:
		(inv_v as Inventory).add_item(it)
		var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
		if cui != null and cui.has_method("show_toast"):
			cui.call("show_toast", "+ %s" % str(it.get("name", "item")), GOLD)
	# Quest 3 branch B consumed nothing via burial — remove the weeping dagger
	# now that the legendary lands (branch A already used it via report_use_item).
	if id == "bloody_dagger" and inv_v is Inventory:
		_remove_bag_item(inv_v as Inventory, "weeping_dagger")


func _remove_bag_item(inv: Inventory, item_id: String) -> void:
	for i: int in inv.bag.size():
		var entry: Variant = inv.bag[i]
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
			inv.bag[i] = null
			inv.bag_changed.emit()
			return


func _on_quest_completed(qid: String) -> void:
	if qid == "one_who_listens":
		_q5_done = true
		_despawn_mira()
	var d: Dictionary = QuestDefs.all().get(qid, {})
	if d.has("finale_pages") and _dialogue != null:
		_dialogue.show_dialogue(str(d.get("finale_speaker", "")), d["finale_pages"])


## Quest 4's camp-overlook choice has no NPC (npc == "") — main.gd surfaces it
## as a world choice prompt (§5 / quests.gd INTEGRATION).
func _on_quest_updated_choice(_qid: String) -> void:
	if _quests == null or _dialogue == null or _pending_world_choice:
		return
	var pc: Dictionary = _quests.pending_choice()
	if pc.is_empty() or str(pc.get("npc", "")) != "":
		return
	if not _dialogue.has_method("show_choice"):
		return
	_pending_world_choice = true
	var quest_id: String = str(pc.get("quest_id", ""))
	var handler := func(opt: String) -> void:
		_pending_world_choice = false
		var follow: Array = _quests.report_choice(quest_id, opt)
		if not follow.is_empty() and _dialogue != null:
			_dialogue.show_dialogue("", follow)
	if _dialogue.has_signal("choice_made"):
		_dialogue.connect("choice_made", handler, CONNECT_ONE_SHOT)
	_dialogue.call("show_choice", "", str(pc.get("prompt", "")), str(pc.get("a", "")), str(pc.get("b", "")))


func _quest_title(qid: String) -> String:
	var d: Dictionary = QuestDefs.all().get(qid, {})
	return str(d.get("title", qid))


func _push_tracker() -> void:
	if _quests == null:
		return
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("update_tracker"):
		hud.call("update_tracker", _quests.tracker_lines())


## Dim the whole world one beat (quest 5 finale) — a black wash on the vignette
## layer (5), which sits below the HUD/dialogue so the UI is never darkened.
func _dim_world_one_beat() -> void:
	var v: Node = get_node_or_null("Vignette")
	if v == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_child(dim)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.55, 0.6)
	tw.tween_property(dim, "color:a", 0.0, 0.6)
	tw.tween_callback(dim.queue_free)


# =============================================================================
# QUIT TO MENU (PauseMenu.quit_to_menu)
# =============================================================================

func _on_quit_to_menu() -> void:
	set_physics_process(false)
	_hide_world_prompt()
	_despawn_mira()
	for grp: String in ["hud", "minimap", "bag_ui", "sheet_ui", "crafting_ui", "dialogue_ui", "pause_menu"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null:
			n.queue_free()
	for named: String in ["WorldPromptLayer", "Vignette", "Music", "FadeLayer"]:
		var node: Node = get_node_or_null(named)
		if node != null:
			node.queue_free()
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	if _quests != null and is_instance_valid(_quests):
		_quests.queue_free()
	if _day_night != null and is_instance_valid(_day_night):
		_day_night.queue_free()
	if _weather != null and is_instance_valid(_weather):
		_weather.queue_free()
	_world = null
	_quests = null
	_day_night = null
	_weather = null
	_player = null
	_camera = null
	_dialogue = null
	_music = null
	_world_prompt = null
	_built = {}
	_q5_done = false
	_pending_world_choice = false
	current_map_id = "town"
	await _run_menu()


# =============================================================================
# CAMERA / MUSIC / VIGNETTE / FADE
# =============================================================================

func _make_camera(bounds: Rect2) -> Camera2D:
	var cam := Camera2D.new()
	cam.name = "PlayerCamera"
	_apply_camera_limits(cam, bounds)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	return cam


func _apply_camera_limits(cam: Camera2D, bounds: Rect2) -> void:
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)


func _ensure_music() -> AudioStreamPlayer:
	if _music != null and is_instance_valid(_music):
		return _music
	var existing: Node = get_node_or_null("Music")
	if existing is AudioStreamPlayer:
		_music = existing
		return _music
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.volume_db = MUSIC_VOLUME_DB
	# Keep playing while PauseMenu pauses the tree; join "music" so its volume
	# slider can find the player (contract §13 / PauseMenu §4).
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music.add_to_group("music")
	add_child(music)
	_music = music
	return music


func _start_music_for_def(def: Dictionary) -> void:
	_start_music_for_path(str(def.get("music", MUSIC_PATH)))


func _start_music_for_path(path: String) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("main.gd: could not load music at %s" % path)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var music := _ensure_music()
	music.stream = stream
	music.play()


func _fade_to_black(t: float) -> void:
	if _fade_layer == null or not is_instance_valid(_fade_layer):
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "FadeLayer"
		_fade_layer.layer = FADE_LAYER
		_fade_rect = ColorRect.new()
		_fade_rect.name = "FadeRect"
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_layer.add_child(_fade_rect)
		add_child(_fade_layer)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, t)
	await tw.finished


func _fade_from_black(t: float) -> void:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		return
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, t)
	await tw.finished
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade_rect = null


func _make_vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = VIGNETTE_LAYER
	var rect := TextureRect.new()
	rect.name = "VignetteRect"
	rect.texture = _make_vignette_texture()
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	return layer


func _make_vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), VIGNETTE_EDGE])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 512
	tex.height = 288
	return tex


# =============================================================================
# HEADLESS AUTOMATION HOOKS (unchanged behavior)
# =============================================================================

func _run_env_hooks() -> void:
	# RH_MAP: force change_map to the given map id right after boot so the harness
	# can smoke/screenshot the wilderness (normally only reached via the gate).
	# Runs before the camera/zoom/focus hooks so RH_ZOOM/RH_FOCUS frame the
	# destination map, and before the RH_SHOT/RH_SMOKE frame loop.
	var map_env: String = OS.get_environment("RH_MAP")
	if not map_env.is_empty() and map_env != current_map_id and MapRegistry.has_map(map_env):
		await change_map(map_env, "")
	var shot_path: String = OS.get_environment("RH_SHOT")
	var smoke: String = OS.get_environment("RH_SMOKE")
	var cast_action: String = OS.get_environment("RH_CAST")
	var ui_env: String = OS.get_environment("RH_UI")
	if shot_path.is_empty() and smoke.is_empty() and cast_action.is_empty() and ui_env.is_empty():
		return
	if _camera != null and not OS.get_environment("RH_WIDE").is_empty():
		_camera.zoom = Vector2(WIDE_ZOOM, WIDE_ZOOM)
		_camera.reset_smoothing()
	var zoom_env: String = OS.get_environment("RH_ZOOM")
	if _camera != null and not zoom_env.is_empty():
		var z: float = zoom_env.to_float()
		if z > 0.01:
			_camera.zoom = Vector2(z, z)
			_camera.limit_left = -10000000
			_camera.limit_top = -10000000
			_camera.limit_right = 10000000
			_camera.limit_bottom = 10000000
			var focus: String = OS.get_environment("RH_FOCUS")
			if not focus.is_empty():
				var parts: PackedStringArray = focus.split(",")
				if parts.size() == 2 and _player != null:
					_player.global_position = Vector2(parts[0].to_float(), parts[1].to_float())
			_camera.reset_smoothing()
	var did_cast := false
	if not cast_action.is_empty():
		did_cast = true
		await _run_cast_sequence(cast_action)
	# RH_UI: force-open the bag + character sheet (before any RH_SHOT capture).
	if not ui_env.is_empty():
		for _i in range(30):
			await get_tree().process_frame
		_force_open_ui()
	# RH_EQUIP: comma list of bag indices to auto-equip (QA: visible weapon,
	# rarity borders on the paper-doll, live stat strip).
	var equip_env: String = OS.get_environment("RH_EQUIP")
	if not equip_env.is_empty() and _player != null:
		var inv_v: Variant = _player.get("inventory")
		if inv_v is Inventory:
			for part: String in equip_env.split(",", false):
				(inv_v as Inventory).equip_from_bag(int(part.strip_edges()))
	# RH_GRANT=<id,id,...>: drop items into the bag (QA: verify icons/tooltips
	# for crafting materials, consumables, recipe scrolls, quest items).
	var grant_env: String = OS.get_environment("RH_GRANT")
	if not grant_env.is_empty() and _player != null:
		var ginv: Variant = _player.get("inventory")
		if ginv is Inventory:
			for gid: String in grant_env.split(",", false):
				var g: String = gid.strip_edges()
				if Crafting.has_item(g):
					Crafting.grant(ginv as Inventory, g, 1)
				else:
					var git: Dictionary = Items.get_item(g)
					if not git.is_empty():
						(ginv as Inventory).add_item(git)
	# RH_NOHUD: hide all UI + the player + vignette for a clean world capture
	# (used to bake the minimap map textures).
	if not OS.get_environment("RH_NOHUD").is_empty():
		for grp: String in ["hud", "minimap", "bag_ui", "sheet_ui", "crafting_ui", "dialogue_ui", "player"]:
			for n: Node in get_tree().get_nodes_in_group(grp):
				if n is CanvasItem:
					(n as CanvasItem).visible = false
				elif n is CanvasLayer:
					(n as CanvasLayer).visible = false
		var vg: Node = get_node_or_null("Vignette")
		if vg is CanvasLayer:
			(vg as CanvasLayer).visible = false
		if _world_prompt != null:
			_world_prompt.visible = false
	# RH_TIME=<hours 0..24>: snap the day/night clock (verify night ambience).
	var time_env: String = OS.get_environment("RH_TIME")
	if not time_env.is_empty() and _day_night != null:
		_day_night.set_time(time_env.to_float())
	# RH_CRAFT=<station id>: open a crafting station panel (verify crafting UI).
	var craft_env: String = OS.get_environment("RH_CRAFT")
	if not craft_env.is_empty():
		var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
		if cui != null:
			cui.call("open_station", craft_env)
	# RH_PROMPT: force the "[E] Talk" interact prompt visible (QA layout check).
	if not OS.get_environment("RH_PROMPT").is_empty():
		var du: Node = get_tree().get_first_node_in_group("dialogue_ui")
		if du != null and du.has_method("set_prompt_visible"):
			du.call("set_prompt_visible", true)
	# RH_SAY=<voice_id>|<text>: directly speak a line via the Voice autoload (QA).
	var say_env: String = OS.get_environment("RH_SAY")
	if not say_env.is_empty():
		var vo: Node = get_node_or_null("/root/Voice")
		if vo != null:
			var sp: PackedStringArray = say_env.split("|", true)
			vo.call("speak", sp[0] if sp.size() > 0 else "marta",
				sp[1] if sp.size() > 1 else "Testing the voice of Raven Hollow.")
	# RH_WEATHER=<type[,intensity]>: force weather (clear/rain/storm/snow/fog) for QA.
	var wx_env: String = OS.get_environment("RH_WEATHER")
	if not wx_env.is_empty() and _weather != null:
		var parts: PackedStringArray = wx_env.split(",", false)
		var tmap := {"clear": 0, "rain": 1, "storm": 2, "snow": 3, "fog": 4}
		var wtype: int = int(tmap.get(parts[0].strip_edges().to_lower(), 0))
		var wint: float = float(parts[1]) if parts.size() > 1 else 1.0
		_weather.set_weather(wtype, wint, 0.0)
	# RH_MAPVIEW: open the world-map overlay (synthesize the "map" action).
	if not OS.get_environment("RH_MAPVIEW").is_empty():
		var mev := InputEventAction.new()
		mev.action = "map"
		mev.pressed = true
		Input.parse_input_event(mev)
	if not shot_path.is_empty():
		if not OS.get_environment("RH_TALK").is_empty():
			for _i in range(20):
				await get_tree().process_frame
			var npc: Node = _nearest_npc()
			if npc != null and _player != null:
				npc.call("interact", _player)
		var shot_wait: int = CAST_SHOT_FRAMES if did_cast else SHOT_FRAMES
		for _i in range(shot_wait):
			await get_tree().process_frame
		_save_screenshot(shot_path)
		get_tree().quit(0)
		return
	if smoke.is_empty():
		return  # RH_CAST alone: keep the game running after the casts.
	for _i in range(SMOKE_FRAMES):
		await get_tree().process_frame
	get_tree().quit(0)


func _run_cast_sequence(action: String) -> void:
	## RH_CAST hook: teleport near the scarecrow and cast the given action
	## three times, spaced CAST_GAP_FRAMES apart.
	for _i in range(CAST_WARMUP_FRAMES):
		await get_tree().process_frame
	if _player == null:
		return
	_player.global_position = CAST_STAND_POS
	if _camera != null:
		_camera.reset_smoothing()
	# Headless runs have no mouse press to acquire a target with, so mimic the
	# attack-press acquisition: target the nearest enemy (the scarecrow). This
	# lets screenshots verify the HUD target frame + targeted nameplate state.
	_player.target = Combat.find_nearest_enemy(_player.global_position, 200.0)
	var aim: Vector2 = (CAST_TARGET_POS - _player.global_position).normalized()
	for c in range(3):
		if c > 0:
			for _j in range(CAST_GAP_FRAMES):
				await get_tree().process_frame
		_player.debug_cast(action, aim)


func _force_open_ui() -> void:
	## RH_UI hook: open both overlay panels via their groups, tolerant of
	## whichever open-method name the UI scripts expose.
	for group: String in ["bag_ui", "sheet_ui"]:
		var node: Node = get_tree().get_first_node_in_group(group)
		if node == null:
			push_warning("main.gd: RH_UI — no node in group '%s'." % group)
			continue
		for method: String in ["open", "force_open", "show_ui", "toggle"]:
			if node.has_method(method):
				node.call(method)
				break


func _nearest_npc() -> Node:
	if _player == null:
		return null
	var best: Node = null
	var best_d: float = INF
	for npc: Node in get_tree().get_nodes_in_group("npcs"):
		if npc is Node2D:
			var d: float = (npc as Node2D).global_position.distance_to(_player.global_position)
			if d < best_d:
				best_d = d
				best = npc
	return best


func _save_screenshot(path: String) -> void:
	var vp := get_viewport()
	if vp == null:
		push_warning("main.gd: RH_SHOT — no viewport available.")
		return
	var tex := vp.get_texture()
	if tex == null:
		push_warning("main.gd: RH_SHOT — viewport has no texture.")
		return
	var img: Image = tex.get_image()
	if img == null:
		push_warning("main.gd: RH_SHOT — could not read viewport image.")
		return
	var err: int = img.save_png(path)
	if err != OK:
		push_warning("main.gd: RH_SHOT — save_png failed (%d) for %s" % [err, path])
