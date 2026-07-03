extends Node2D
## Bootstrap for "Raven Hollow: Emberfall".
## Shows the class-select screen first (over black), then builds the town via
## TownBuilder, spawns the Player (chosen class), NPC cast and enemies, and
## wires camera / dialogue UI / HUD / bag + character-sheet UIs / dusk tint /
## music / vignette. Honors headless automation hooks (RH_CLASS / RH_SMOKE /
## RH_SHOT / RH_WIDE / RH_ZOOM / RH_FOCUS / RH_TALK / RH_CAST / RH_UI).

const DUSK_TINT := Color(1.0, 0.87, 0.72)
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

var _camera: Camera2D
var _player: Player


func _ready() -> void:
	# 0. Class choice: env hook (RH_CLASS / headless automation) or the
	#    class-select screen shown over a black backdrop, world not yet built.
	var chosen: String = _resolve_class_choice()
	if chosen.is_empty():
		chosen = await _prompt_class_select()
	_bootstrap_world(chosen)


func _resolve_class_choice() -> String:
	## Returns a class id when the select screen must be skipped, else "".
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
	# Headless automation without an explicit class must never hang on the
	# select screen.
	if not OS.get_environment("RH_SMOKE").is_empty() or not OS.get_environment("RH_SHOT").is_empty():
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


func _bootstrap_world(class_id: String) -> void:
	# 1-2. World root (y-sorted) populated by the town builder.
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	var info: Dictionary = TownBuilder.build(world)
	add_child(world)

	# 3. Player at the builder-provided spawn, as the chosen class.
	var player: Player = Player.create(info.player_spawn, class_id)
	world.add_child(player)
	_player = player

	# 4. NPC cast, placed from the builder's role spawn table.
	var spawns: Dictionary = info.npc_spawns
	for def: Dictionary in NPCData.cast():
		var role: String = def.id
		if spawns.has(role):
			var spawn: Dictionary = spawns[role]
			def.pos = spawn.pos
			def.wander_radius = spawn.wander_radius
			world.add_child(NPC.create(def))
		else:
			push_warning("main.gd: no town spawn for NPC role '%s' — skipped." % role)

	# 4b. Enemies out past the town edges.
	Combat.spawn_world_enemies(world)

	# 5. Dialogue UI + arrival banner (subtitle = the chosen class title).
	var ui := DialogueUI.new()
	add_child(ui)
	if OS.get_environment("RH_NOBANNER").is_empty():
		var subtitle: String = str(player.class_def.get("title", "The Emberfall Road"))
		ui.show_banner("Raven Hollow", subtitle)

	# 5b. HUD (layer 8) sits between the vignette (5) and the dialogue UI (10).
	add_child(HUD.new())

	# 5c. Backpack + character sheet (layer 9: above the HUD, below dialogue).
	add_child(BagUI.new())
	add_child(CharacterSheetUI.new())

	# 6. Camera rides the player, clamped to town bounds.
	_camera = _make_camera(info.bounds)
	player.add_child(_camera)

	# 7. Warm golden-dusk tint over the whole world.
	var dusk := CanvasModulate.new()
	dusk.name = "DuskModulate"
	dusk.color = DUSK_TINT
	world.add_child(dusk)

	# 8. Village ambience loop.
	_start_music()

	# 9. Vignette overlay: above the world, below the dialogue UI (layer 10).
	add_child(_make_vignette())

	# 6b. Camera can only become current once inside the tree.
	await get_tree().process_frame
	_camera.make_current()

	# 10. Headless automation hooks (no-ops in a normal run).
	_run_env_hooks()


func _make_camera(bounds: Rect2) -> Camera2D:
	var cam := Camera2D.new()
	cam.name = "PlayerCamera"
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	return cam


func _start_music() -> void:
	var stream: AudioStream = load(MUSIC_PATH)
	if stream == null:
		push_warning("main.gd: could not load music at %s" % MUSIC_PATH)
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.stream = stream
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.play()


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


func _run_env_hooks() -> void:
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
