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
var _zone_ambience: AudioStreamPlayer
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
			var cls: String = await _begin_new_game()
			if cls.is_empty():
				# Player backed out of the select screen -> back to the title.
				await _run_menu()
				return
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


## New Game entry (#84 -> #43): prefer the Diablo-2 SELECT SCREEN driven by
## NewGameSystem (it opens SelectScreenSystem and emits new_game_ready(class_id)).
## Returns the chosen class id, or "" if the player backed out (caller returns to
## the title). Falls back to the legacy ClassSelect exactly as before when the
## new autoloads are absent. This path is ONLY reached in an interactive run --
## RH_CLASS / RH_SMOKE / RH_SHOT boot straight into gameplay before any menu --
## so awaiting the pick here can never hang a headless boot.
func _begin_new_game() -> String:
	var ngs: Node = get_node_or_null("/root/NewGameSystem")
	if ngs != null and ngs.has_method("start_new_game") and ngs.has_signal("new_game_ready"):
		# Bind BEFORE starting: when no select screen is present NewGameSystem
		# emits new_game_ready synchronously INSIDE start_new_game(), so a plain
		# `await ngs.new_game_ready` afterwards could miss it and stall.
		var box: Array = [""]
		var got: Array = [false]
		var cb := func(cid: Variant) -> void:
			box[0] = str(cid)
			got[0] = true
		ngs.connect("new_game_ready", cb, CONNECT_ONE_SHOT)
		ngs.call("start_new_game")
		while not got[0]:
			await get_tree().process_frame
			if got[0]:
				break
			# Esc closed the select screen without a pick -> treat as cancel so we
			# never poll forever on a dismissed screen.
			var ss: Node = get_node_or_null("/root/SelectScreenSystem")
			if ss != null and ss.has_method("is_select_open") and not bool(ss.call("is_select_open")):
				if ngs.is_connected("new_game_ready", cb):
					ngs.disconnect("new_game_ready", cb)
				if ngs.has_method("cancel"):
					ngs.call("cancel")
				return ""
		var picked: String = str(box[0])
		if not picked.is_empty():
			return picked
		# Empty pick (unexpected) -> safe fallback so a class always spawns.
		return FALLBACK_CLASS
	# No new-game autoloads in this build: legacy class-select, unchanged.
	return await _prompt_class_select()


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

	# Intro cinematic (#51): play once over the freshly-built New-Game world.
	# Guarded + skipped entirely under any screenshot/smoke/class-skip automation
	# so captures and headless tests are unaffected.
	_maybe_play_intro()

	# Headless automation hooks (no-ops in a normal run).
	_run_env_hooks()

	# RH_SYS_TEST: prove the StatsSystem + StatusSystem math on boot (#34/#35).
	if not OS.get_environment("RH_SYS_TEST").is_empty():
		_run_sys_test(player)


## Intro cinematic hook (#51). Fire-and-forget: CinematicSystem commandeers the
## camera and blocks player input for the duration, then restores both. Fully
## guarded and degrade-safe -- absent system, missing 'intro', or any automation
## env leaves the New-Game boot behaving exactly as before.
func _maybe_play_intro() -> void:
	# Any screenshot / smoke / class-skip / select automation must NOT see the
	# cinematic -- it changes framing and can gate on input.
	for env: String in ["RH_CLASS", "RH_SHOT", "RH_SMOKE", "RH_SELECT"]:
		if not OS.get_environment(env).is_empty():
			return
	var cine: Node = get_node_or_null("/root/CinematicSystem")
	if cine == null or not cine.has_method("play") or not cine.has_method("has_cinematic"):
		return
	if not bool(cine.call("has_cinematic", "intro")):
		return
	# Play once per session: was_seen guards replays across quit-to-menu new games.
	if cine.has_method("was_seen") and bool(cine.call("was_seen", "intro")):
		return
	cine.call("play", "intro")


func _run_sys_test(player: Node) -> void:
	## Boot-time self-test for the two foundational systems (BACKLOG #34/#35):
	## prints class derivations, level scaling, a poison DoT, and the
	## wolf_bite -> Infected chain so the math is verifiable. ASCII only.
	if player == null:
		return
	print("[SYS_TEST] ===== Raven Hollow systems self-test =====")
	var cd: Dictionary = player.get("class_def")
	var cid: String = str(cd.get("id", "warrior"))
	var lv: int = int(player.get("level"))
	StatsSystem.register(player, cid, lv)
	var line: String = "[SYS_TEST] class=%s level=%d primaries:" % [cid, lv]
	for s: String in ["stamina", "strength", "agility", "intellect", "spirit"]:
		line += " %s=%.1f" % [s, StatsSystem.get_stat(player, s)]
	print(line)
	print("[SYS_TEST] derived L%d: max_health=%.1f max_mana=%.1f attack_power=%.1f spell_power=%.1f crit=%.2f%% armor=%.1f hp_regen=%.2f mana_regen=%.2f" % [
		lv,
		StatsSystem.get_derived(player, "max_health"), StatsSystem.get_derived(player, "max_mana"),
		StatsSystem.get_derived(player, "attack_power"), StatsSystem.get_derived(player, "spell_power"),
		StatsSystem.get_derived(player, "crit_chance"), StatsSystem.get_derived(player, "armor"),
		StatsSystem.get_derived(player, "hp_regen"), StatsSystem.get_derived(player, "mana_regen")])
	StatsSystem.apply_level(player, 60)
	print("[SYS_TEST] scaled to L60: max_health=%.1f max_mana=%.1f attack_power=%.1f flat_damage=%.1f" % [
		StatsSystem.get_derived(player, "max_health"), StatsSystem.get_derived(player, "max_mana"),
		StatsSystem.get_derived(player, "attack_power"), StatsSystem.get_derived(player, "flat_damage")])
	StatsSystem.apply_level(player, lv)
	var hp_start: float = float(player.get("hp"))
	StatusSystem.apply(player, "poison", null, 1)
	print("[SYS_TEST] poison applied: has=%s hp=%.1f speed_pct_mod=%.0f" % [
		str(StatusSystem.has(player, "poison")), float(player.get("hp")),
		StatsSystem.get_derived(player, "speed_pct")])
	for i in range(3):
		StatusSystem.tick(2.0)
		print("[SYS_TEST]   poison tick %d -> hp=%.1f" % [i + 1, float(player.get("hp"))])
	StatusSystem.remove(player, "poison")
	print("[SYS_TEST] poison cleared (hp fell %.1f over 3 ticks)" % [hp_start - float(player.get("hp"))])
	var maxhp_before: float = float(player.get("max_hp"))
	var derived_before: float = StatsSystem.get_derived(player, "max_health")
	for i in range(3):
		StatusSystem.apply(player, "wolf_bite", null, 1)
	print("[SYS_TEST] wolf_bite x3: has_wolf_bite=%s has_infected=%s infected_kind=%s" % [
		str(StatusSystem.has(player, "wolf_bite")), str(StatusSystem.has(player, "infected")),
		str(StatusSystem.get_def("infected").get("kind", "?"))])
	print("[SYS_TEST] Infected -1 Stamina: derived max_health %.1f -> %.1f ; player.max_hp %.1f -> %.1f" % [
		derived_before, StatsSystem.get_derived(player, "max_health"),
		maxhp_before, float(player.get("max_hp"))])
	StatusSystem.purge(player, "disease")
	print("[SYS_TEST] purge(disease): has_infected=%s max_hp restored to %.1f" % [
		str(StatusSystem.has(player, "infected")), float(player.get("max_hp"))])
	print("[SYS_TEST] ===== self-test complete =====")
	if OS.get_environment("RH_SHOT").is_empty():
		get_tree().create_timer(0.8).timeout.connect(func() -> void: get_tree().quit(0))


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
	# AAA polish: subtle 2D bloom (hdr_2d) — fires, inscription glow and
	# spell VFX bleed light softly; tuned low to respect the pixel art.
	if get_node_or_null("GlowEnv") == null:
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_strength = 0.9
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.08
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		var we := WorldEnvironment.new()
		we.name = "GlowEnv"
		we.environment = env
		add_child(we)
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
	add_child(SpellbookUI.new())
	add_child(CraftingUI.new())
	add_child(ProfessionCraftingUI.new())

	var ui := DialogueUI.new()
	add_child(ui)
	_dialogue = ui

	var pause := PauseMenu.new()
	add_child(pause)
	pause.quit_to_menu.connect(_on_quit_to_menu)
	# The central Menu hub (backtick `, or the pause menu's "Menu" row): the one
	# discoverable front door to every feature panel (auction/rep/mounts/pvp/etc.),
	# which otherwise hide behind undocumented single-letter hotkeys.
	add_child(GameMenu.new())
	pause.open_menu_requested.connect(_on_open_game_menu)

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
		# Biome lives in ZoneDefs, not the registry-merged def (same lookup
		# path the WeatherSystem uses).
		_day_night.set_underground(str(ZoneDefs.zone(map_id).get("biome", "")) == "cave")
		_day_night.set_ambient_lock(ZoneDefs.zone(map_id).get("ambient_lock"))
		_day_night.set_ambient_bias(ZoneDefs.zone(map_id).get("ambient_bias"))

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
			# ZoneBuilder zones (WORLD_PLAN.md): native creature ecology ships
			# in built.enemy_spawns; npc pockets in npc_spawns.
			_spawn_npc_cast(world, built.get("npc_spawns", {}))
			Combat.spawn_map_enemies(world, built)
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
	# A manual fade change_map supersedes any in-flight streaming: drop the
	# pre-built neighbor so it can never leak a stale root.
	WorldStreamSystem.reset()
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


## Waystation fast travel (TravelSystem): change map, then land at an exact
## authored position instead of a travel point.
func change_map_to_pos(map_id: String, pos: Vector2) -> void:
	if _changing_map or not MapRegistry.has_map(map_id):
		return
	await change_map(map_id, "")
	if _player != null and is_instance_valid(_player):
		_player.global_position = pos + Vector2(0.0, 28.0)


# =============================================================================
# SEAMLESS EDGE-STREAMING HOOKS (WorldStreamSystem / BLUEPRINT_98)
# Only reached when streaming is enabled; with it OFF the game runs exactly as
# before. These give the streamer the minimal main-side surface it needs.
# =============================================================================

## A sibling of World that holds pre-built neighbor roots (independently freeable,
## never confused with the current map).
func stream_container() -> Node2D:
	var c: Node = get_node_or_null("Streaming")
	if c is Node2D:
		return c
	var n := Node2D.new()
	n.name = "Streaming"
	n.y_sort_enabled = true
	add_child(n)
	return n


func stream_world() -> Node2D:
	return _world


func stream_built() -> Dictionary:
	return _built


## Expand the camera limits to the union of the current zone and a neighbor at
## `offset` (size `world_b`) so the camera can pan past our edge and reveal it.
func stream_set_camera_union(offset: Vector2, world_b: Vector2) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var a: Rect2 = _built.get("bounds", DEFAULT_BOUNDS)
	var b: Rect2 = Rect2(offset, world_b)
	_apply_camera_limits(_camera, a.merge(b))


## THE flip (BLUEPRINT_98 step 2): atomically shift the world by -shift so the
## neighbor lands at origin and becomes the current zone, reparent the player
## (carrying its camera) into it, fire the same change hooks change_map fires
## (minus the fade), and return the OLD world root (the streamer keeps it as the
## new behind-neighbor). One frame, imperceptible: roots + player + camera all
## move by the same -shift and the camera smoothing is reset.
func stream_commit_flip(new_id: String, new_root: Node2D, new_built: Dictionary, shift: Vector2) -> Node2D:
	if _player == null or not is_instance_valid(_player) or new_root == null or not is_instance_valid(new_root):
		return null
	var old_world: Node2D = _world
	var old_built: Dictionary = _built
	# Reparent the player into the new zone, keeping its on-screen position.
	var gpos: Vector2 = _player.global_position
	var pp: Node = _player.get_parent()
	if pp != null:
		pp.remove_child(_player)
	new_root.add_child(_player)
	_player.global_position = gpos
	# Atomic -shift: new_root -> origin (player rides it), old_world -> -shift.
	new_root.position -= shift
	if old_world != null and is_instance_valid(old_world):
		old_world.position -= shift
	# Camera continuity: reset smoothing so the (uniform) shift is invisible.
	if _camera != null and is_instance_valid(_camera):
		_camera.reset_smoothing()
	# Bookkeeping.
	_world = new_root
	_built = new_built
	current_map_id = new_id
	# DayNight CanvasModulate: the new zone gets its own; drop the old one so a
	# single modulate stays active (auto-discovery would otherwise fight).
	var new_cm := CanvasModulate.new()
	new_cm.name = "DuskModulate"
	new_root.add_child(new_cm)
	if _day_night != null:
		_day_night.attach_canvas_modulate(new_cm)
		_day_night.set_underground(str(ZoneDefs.zone(new_id).get("biome", "")) == "cave")
		_day_night.set_ambient_lock(ZoneDefs.zone(new_id).get("ambient_lock"))
		_day_night.set_ambient_bias(ZoneDefs.zone(new_id).get("ambient_bias"))
	if old_world != null and is_instance_valid(old_world):
		var ocm: Node = old_world.get_node_or_null("DuskModulate")
		if ocm != null:
			ocm.queue_free()
	# Live actors for the new zone spawn NOW (enemies are physics bodies -> on
	# commit, not during pre-build), plus npc pockets + light registry.
	_post_build_map(new_id, new_root, new_built)
	# Camera limits: union of new (origin) + old (behind at -shift) so there is
	# no clamp-pop while the player is still near the seam.
	if _camera != null and is_instance_valid(_camera):
		var nb: Rect2 = new_built.get("bounds", DEFAULT_BOUNDS)
		var camu: Rect2 = nb
		if old_world != null and is_instance_valid(old_world):
			camu = nb.merge(Rect2(old_world.position, (old_built.get("bounds", DEFAULT_BOUNDS) as Rect2).size))
		_apply_camera_limits(_camera, camu)
	# The same hooks change_map fires, without the fade.
	var def: Dictionary = MapRegistry.get_map(new_id)
	_start_music_for_def(def)
	get_tree().call_group("pause_menu", "apply_music_volume")
	if _weather != null:
		_weather.on_map_changed(new_id)
	_refresh_minimap(new_id, new_built, def)
	if _dialogue != null:
		_dialogue.show_banner(str(def.get("display_name", "")), "")
	if _quests != null and _day_night != null:
		_quests.set_night(_day_night.is_night)
	_push_tracker()
	return old_world


## Free a behind zone once the player has fully crossed; clamp the camera back
## to the current zone bounds.
func stream_free_behind(root: Node2D) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if _camera != null and is_instance_valid(_camera):
		_apply_camera_limits(_camera, _built.get("bounds", DEFAULT_BOUNDS))


## RH_SEAMLESS QA: pre-build the current map's first streamable seam, frame the
## player just short of the boundary so a wide shot shows both zones' terrain
## meeting with no black bar, and (RH_SEAMWALK) force-walk the player across to
## exercise the flip. ASCII logs only.
func _run_seamless_qa() -> void:
	var seam: Dictionary = await WorldStreamSystem.debug_prebuild_first_seam(self)
	if seam.is_empty() or _player == null or not is_instance_valid(_player):
		return
	var axis: String = str(seam.get("axis", "x"))
	var line: float = float(seam.get("boundary", 0.0))
	var dir: float = float(seam.get("dir_sign", 1.0))
	var gmid: float = (float(seam.get("gap_min", 0.0)) + float(seam.get("gap_max", 0.0))) * 0.5
	var back: float = line - dir * 120.0  # sit on OUR side of the seam
	_player.global_position = Vector2(back, gmid) if axis == "x" else Vector2(gmid, back)
	if _camera != null and is_instance_valid(_camera):
		await get_tree().process_frame
		_camera.reset_smoothing()
		await get_tree().process_frame
		_camera.reset_smoothing()
	print("[SEAMLESS] framed seam at boundary %d (axis %s); player on our side" % [int(line), axis])
	var walk_env: String = OS.get_environment("RH_SEAMWALK")
	if walk_env.is_empty():
		return
	var before_id: String = current_map_id
	var announced: bool = false
	for i in range(300):
		var stepv: Vector2 = Vector2(dir * 10.0, 0.0) if axis == "x" else Vector2(0.0, dir * 10.0)
		_player.global_position += stepv
		await get_tree().process_frame
		if not announced and current_map_id != before_id:
			announced = true
			print("[SEAMLESS] crossed seam by walking: '%s' -> '%s' (frame %d, no fade)" % [before_id, current_map_id, i])
	for _j in range(24):
		await get_tree().process_frame


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

	# Seamless edge-streaming (BLUEPRINT_98): pre-build the adjacent zone off-
	# screen as we near a border seam, flip ownership on cross, unload behind.
	# GATED -- no-op unless enabled; the [E] fade change_map below stays as the
	# guaranteed fallback for any seam streaming declines.
	if WorldStreamSystem.enabled:
		WorldStreamSystem.tick(self, ppos)

	# Crafting stations (town only ships them).
	var station: Dictionary = _nearest_station(ppos)
	if not station.is_empty():
		_show_world_prompt(str(station.get("prompt", "[E] Craft")))
		if Input.is_action_just_pressed("interact"):
			var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
			if cui != null and cui.get("is_open") != true:
				cui.call("open_station", str(station.get("id", "")))
		return

	# Waystation discovery (WORLD_PLAN travel system): walking near an authored
	# waystation lights it on the route graph; banner announces the discovery.
	var ws_found: String = TravelSystem.try_discover(ppos, current_map_id)
	if not ws_found.is_empty() and _dialogue != null:
		_dialogue.show_banner("Waystation Discovered", ws_found.capitalize())

	# Travel points.
	for tp: Dictionary in MapRegistry.travel_points(current_map_id):
		if ppos.distance_to(tp["pos"]) <= float(tp["radius"]):
			# Streamed border seams cross seamlessly (no prompt); the E-press
			# still fires change_map as the guaranteed fade fallback.
			if not (WorldStreamSystem.enabled and WorldStreamSystem.owns_seam(current_map_id, str(tp["id"]))):
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


## PauseMenu "Menu" row -> close the pause menu, open the central GameMenu hub.
func _on_open_game_menu() -> void:
	var gm: Node = get_tree().get_first_node_in_group("game_menu")
	if gm != null and gm.has_method("open"):
		gm.call("open")


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
	WorldStreamSystem.reset()
	_hide_world_prompt()
	_despawn_mira()
	for grp: String in ["hud", "minimap", "bag_ui", "sheet_ui", "crafting_ui", "dialogue_ui", "pause_menu"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null:
			n.queue_free()
	for named: String in ["WorldPromptLayer", "Vignette", "Music", "FadeLayer", "Streaming"]:
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
	# Region themes may not be on disk yet (audio acquisition lands them);
	# fall back to the base wilderness theme rather than silence.
	var path: String = str(def.get("music", MUSIC_PATH))
	if not ResourceLoader.exists(path):
		path = MUSIC_PATH
	_start_music_for_path(path)
	_start_zone_ambience(str(def.get("ambience", "")))


## Per-zone ambient bed (WORLD_PLAN zone audio): a looping biome soundscape —
## howling tundra wind, swamp frogs, farmland birdsong, harbor water — living
## UNDER the music and the weather layer. Missing files = silent (drop-in).
func _start_zone_ambience(amb_id: String) -> void:
	if _zone_ambience == null:
		_zone_ambience = AudioStreamPlayer.new()
		_zone_ambience.name = "ZoneAmbience"
		_zone_ambience.volume_db = -14.0
		_zone_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_zone_ambience)
	var stream: AudioStream = null
	if not amb_id.is_empty():
		var p: String = "res://assets/audio/ambience/%s.ogg" % amb_id
		if ResourceLoader.exists(p):
			stream = load(p) as AudioStream
	if stream == _zone_ambience.stream and _zone_ambience.playing:
		return
	if stream == null:
		_zone_ambience.stop()
		_zone_ambience.stream = null
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_zone_ambience.stream = stream
	_zone_ambience.play()
	# gentle fade-in so zone changes breathe
	_zone_ambience.volume_db = -34.0
	var tw := create_tween()
	tw.tween_property(_zone_ambience, "volume_db", -14.0, 2.5)


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
	# RH_SEAMLESS QA (BLUEPRINT_98): with streaming enabled, prove the neighbor
	# pre-builds at the seam offset (RH_SEAMWALK also force-walks the flip).
	# Purely additive; skipped entirely when streaming is OFF.
	if WorldStreamSystem.enabled:
		await _run_seamless_qa()
	# RH_RES=WxH: PRIME-MANDATE 4K cameras — resize the OS window so the
	# viewport texture (and thus RH_SHOT) captures at the requested size.
	var res_env: String = OS.get_environment("RH_RES")
	if not res_env.is_empty():
		var rp: PackedStringArray = res_env.split("x")
		if rp.size() == 2:
			get_window().size = Vector2i(int(rp[0]), int(rp[1]))
			await get_tree().process_frame
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
			# Snap AFTER a frame so the camera's follow target has moved —
			# a same-frame reset leaves the sweep shots ~300px off-center.
			await get_tree().process_frame
			_camera.reset_smoothing()
			await get_tree().process_frame
			_camera.reset_smoothing()
	var did_cast := false
	var fb_demo := false
	if not cast_action.is_empty():
		did_cast = true
		if cast_action == "fireball_anim":
			fb_demo = true  # dedicated projectile demo; runs after night/NOHUD framing below
		else:
			await _run_cast_sequence(cast_action)
	var fx_env: String = OS.get_environment("RH_FX")
	if not fx_env.is_empty():
		did_cast = true
		await _run_fx_showcase(fx_env)
	# RH_UI: force-open the bag + character sheet (before any RH_SHOT capture).
	if not ui_env.is_empty():
		for _i in range(30):
			await get_tree().process_frame
		_force_open_ui()
	# RH_SPELLBOOK=<talents|spells>: grant the player talent points, fill a couple
	# tiers, then open the spellbook/talent window (BACKLOG #59) for the shot.
	var sb_env: String = OS.get_environment("RH_SPELLBOOK")
	if not sb_env.is_empty():
		for _i in range(30):
			await get_tree().process_frame
		_open_spellbook(sb_env)
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
	# RH_CAST=fireball_anim: fireball SPRITE projectile flying east + impact burst. Runs HERE
	# (after RH_TIME night + RH_NOHUD) so the glow reads against the dark and the HUD is hidden.
	if fb_demo:
		await _run_fireball_demo()
	# RH_CRAFT=<station id>: open a crafting station panel (verify crafting UI).
	var craft_env: String = OS.get_environment("RH_CRAFT")
	if not craft_env.is_empty():
		var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
		if cui != null:
			cui.call("open_station", craft_env)
	# RH_PROFCRAFT=<profession id|1>: open the seven-profession crafting window
	# (BACKLOG #42) on the given profession tab for the verification screenshot.
	var profcraft_env: String = OS.get_environment("RH_PROFCRAFT")
	if not profcraft_env.is_empty():
		var pcui: Node = get_tree().get_first_node_in_group("profession_crafting_ui")
		if pcui != null and pcui.has_method("debug_present"):
			pcui.call("debug_present", profcraft_env)
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
		var tmap := {"clear": 0, "rain": 1, "storm": 2, "snow": 3, "fog": 4, "ash": 5}
		var wtype: int = int(tmap.get(parts[0].strip_edges().to_lower(), 0))
		var wint: float = float(parts[1]) if parts.size() > 1 else 1.0
		_weather.set_weather(wtype, wint, 0.0)
	# RH_MAPVIEW: open the world-map overlay (synthesize the "map" action).
	if not OS.get_environment("RH_MAPVIEW").is_empty():
		var mev := InputEventAction.new()
		mev.action = "map"
		mev.pressed = true
		Input.parse_input_event(mev)
	# RH_INVENTORY: instance the systems-layer paperdoll inventory, seed the
	# player's InventorySystem with loot + a full equipped kit, prove the
	# loot->stats link through StatsSystem, then open it (inventory/equip/
	# proficiency deliverable). Guarded: no player -> no-op.
	if not OS.get_environment("RH_INVENTORY").is_empty() and _player != null:
		var _inv_ui: Node = load("res://scenes/ui/inventory.tscn").instantiate()
		add_child(_inv_ui)
		if _inv_ui.has_method("demo_open"):
			_inv_ui.call("demo_open", _player)
		for _iv in range(12):
			await get_tree().process_frame
	if not shot_path.is_empty():
		if not OS.get_environment("RH_TALK").is_empty():
			for _i in range(20):
				await get_tree().process_frame
			var npc: Node = _nearest_npc()
			if npc != null and _player != null:
				npc.call("interact", _player)
		var shot_wait: int = CAST_SHOT_FRAMES if did_cast else SHOT_FRAMES
		var fxw_env: String = OS.get_environment("RH_FXWAIT")
		if not fxw_env.is_empty():
			shot_wait = int(fxw_env)
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


func _run_fx_showcase(id: String) -> void:
	## RH_FX hook: play ONE engine VFX at the scarecrow (clean single-effect beauty shot).
	for _i in range(CAST_WARMUP_FRAMES):
		await get_tree().process_frame
	if _player == null:
		return
	_player.global_position = CAST_STAND_POS
	if _camera != null:
		_camera.reset_smoothing()
	var world: Node2D = _player.get_parent() as Node2D
	if world == null:
		world = _player
	var sc: float = 1.0
	var se: String = OS.get_environment("RH_FXSCALE")
	if not se.is_empty():
		sc = se.to_float()
	FXLib.play(id, world, CAST_TARGET_POS + Vector2(0.0, -18.0), {"scale": sc, "rotation": deg_to_rad(-40.0)})


## RH_CAST=fireball_anim demo: a flat-trajectory fireball PROJECTILE (the fireball_anim sprite,
## kept alpha-blend so the WorldEnvironment glow cannot blow the pale pixels to white) flying EAST
## ~200 px over ~1.2 s with a warm PointLight2D escort, then the SpellVFX "fireball" GPUParticles2D
## detonation at the impact point, plus a ~0.5 s settle. Player sits frame-left; camera holds the
## flight midpoint. Self-contained so it composes over whatever zone/time the harness set.
func _run_fireball_demo() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.visible = true  # RH_NOHUD hid the "player" group; the caster must be seen
	var world: Node2D = _player.get_parent() as Node2D
	if world == null:
		world = _player
	# Hold the flight midpoint so caster + impact both stay framed (design spec).
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2(118.0, -18.0)
		await get_tree().process_frame
		_camera.reset_smoothing()
		await get_tree().process_frame
		_camera.reset_smoothing()
	var start: Vector2 = _player.global_position + Vector2(18.0, -20.0)
	var target: Vector2 = _player.global_position + Vector2(218.0, -20.0)
	var proj := Node2D.new()
	proj.position = start
	proj.z_index = 40
	world.add_child(proj)
	var spr: AnimatedSprite2D = FXLib.make_sprite("fireball_anim")
	spr.scale = Vector2(0.35, 0.35)  # 156 px art -> ~55 px projectile (~1.7 tiles)
	proj.add_child(spr)
	var light := PointLight2D.new()
	light.texture = _soft_light_texture()
	light.color = Color("ff8c3c")
	light.energy = 0.8
	light.texture_scale = 0.9
	proj.add_child(light)
	var tw := proj.create_tween()
	tw.tween_property(proj, "position", target, 1.2).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	FXLib.play("fireball", world, target, {"scale": 0.85})  # AAA GPUParticles2D detonation
	for _i in range(3):  # brief overlap: the crisp sprite hands off INTO the burst (no empty gap)
		await get_tree().process_frame
	proj.queue_free()
	for _i in range(33):  # ~0.5 s settle so the burst reads before the clip ends
		await get_tree().process_frame


## Soft radial light texture (white core -> transparent edge) for the projectile escort light.
func _soft_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


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


func _open_spellbook(mode: String) -> void:
	## RH_SPELLBOOK hook (#59): give the player some talent points, spend a few so
	## the tree shows filled nodes, then open the window on the requested tab.
	var ts: Node = get_node_or_null("/root/TalentSystem")
	if ts != null and _player != null:
		ts.call("notify_level_up", _player, 10)
		ts.call("grant_point", _player, 14)
		var cd_v: Variant = _player.get("class_def")
		var cid: String = str((cd_v as Dictionary).get("id", "warrior")) if cd_v is Dictionary else "warrior"
		var trees: Array = ts.call("trees_for", cid)
		if trees.size() > 0:
			for tt: Variant in (trees[0] as Dictionary).get("talents", []):
				var tid: String = str((tt as Dictionary).get("id", ""))
				# spend up to full ranks where the gates allow it
				for _r in range(5):
					if not bool(ts.call("learn", _player, tid)):
						break
	var sbui: Node = get_tree().get_first_node_in_group("spellbook_ui")
	if sbui == null:
		push_warning("main.gd: RH_SPELLBOOK — no spellbook_ui node.")
		return
	var tab: String = "spellbook" if mode.to_lower().begins_with("spell") else "talents"
	if sbui.has_method("debug_present"):
		sbui.call("debug_present", tab, 0, "")
	elif sbui.has_method("open"):
		sbui.call("open", tab)


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
