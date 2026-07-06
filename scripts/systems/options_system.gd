extends Node
## OptionsSystem (autoload) — Raven Hollow's settings store + applier.
##
## Owns user://settings.cfg (ConfigFile), the audio-bus layout, and the
## apply-on-change hooks that turn a stored value into a real effect (window
## mode / resolution / vsync / pixel scaling via DisplayServer+Window, bus
## volumes via AudioServer, camera smoothing on the live PlayerCamera, and
## InputMap keybind overrides). Spawns the gold-bezel settings panel
## (scenes/ui/options_menu.tscn) so F10 (or a menu) can edit everything.
##
## Design note on coexistence: pause_menu.gd already writes
## [audio] music_volume and applies it as a node-dB offset. To avoid fighting
## it (double attenuation across reboots) OptionsSystem stores its own audio
## under DISTINCT keys ([audio] master/music/sfx/ambience) and drives dedicated
## AudioServer buses. Each control leaves the other at unity by default, so the
## two never compound. Nothing in pause_menu.gd / main.gd is touched.
##
## Public API (the spec surface):
##   get_setting(section, key) -> Variant          # alias: get_v
##   set_setting(section, key, value) -> void       # alias: set_v   (applies + persists)
##   apply_all() -> void                            # re-run every hook (world rebuilds)
##   open() / close() / toggle()                    # the settings panel
## Signal:
##   setting_changed(section, key, value)

signal setting_changed(section, key, value)

const CFG_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/ui/options_menu.tscn"
const SAVE_DEBOUNCE_S := 0.4

## section -> key -> default. The single source of truth; the UI iterates it.
const DEFAULTS := {
	"video": {
		"window_mode": "windowed",     # windowed | borderless | fullscreen
		"resolution": "1920x1080",     # windowed size (W x H)
		"vsync": "on",                 # on | adaptive | off
		"pixel_scale": "integer",      # integer | fractional
	},
	"audio": {
		"master": 1.0,
		"music": 1.0,
		"sfx": 1.0,
		"ambience": 1.0,
	},
	"gameplay": {
		"difficulty": "normal",        # story | normal | hard
		"tooltips": "full",            # full | compact
		"camera_smoothing": "standard",# off | low | standard | high  (standard == shipped 6.0)
	},
	"controls": {},                    # physical-keycode overrides only; empty = project.godot
}

## The audio buses OptionsSystem guarantees exist (all routed to Master).
const AUDIO_BUSES := ["Music", "Ambience", "SFX"]
## slider key -> bus name it drives ("Master" is bus 0, always present).
const BUS_FOR_KEY := {"master": "Master", "music": "Music", "sfx": "SFX", "ambience": "Ambience"}

const CAMERA_SMOOTH := {"off": -1.0, "low": 4.0, "standard": 6.0, "high": 10.0}

## Rebindable actions (everything in project.godot except the fixed ui_* spine).
const REBINDABLE := [
	"move_up", "move_down", "move_left", "move_right",
	"interact", "attack", "sprint", "sheathe",
	"skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "skill_7",
	"inventory", "character_sheet", "spellbook", "map",
]
## Pretty labels for the controls list.
const ACTION_LABELS := {
	"move_up": "Move Up", "move_down": "Move Down", "move_left": "Move Left",
	"move_right": "Move Right", "interact": "Interact", "attack": "Attack",
	"sprint": "Sprint", "sheathe": "Sheathe Weapon",
	"skill_1": "Skill 1", "skill_2": "Skill 2", "skill_3": "Skill 3",
	"skill_4": "Skill 4", "skill_5": "Skill 5", "skill_6": "Skill 6",
	"skill_7": "Skill 7", "inventory": "Inventory", "character_sheet": "Character",
	"spellbook": "Spellbook", "map": "World Map",
}

var _cfg := ConfigFile.new()
var _values: Dictionary = {}      # deep copy of DEFAULTS overlaid with cfg
var _menu: Node = null
var _save_pending: bool = false
var _save_accum: float = 0.0
var _reroute_accum: float = 0.0
var _reroute_tries: int = 0
var _default_events: Dictionary = {}   # action -> Array[InputEvent] captured before overrides


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_events()
	_load()
	_ensure_audio_buses()
	_apply_input_overrides()
	apply_all()
	call_deferred("_spawn_menu")
	# QA: prove the AudioServer honours a change without polluting saved state.
	if not OS.get_environment("RH_OPT_TEST").is_empty():
		call_deferred("_qa_audio_selftest")


func _process(delta: float) -> void:
	# Debounced disk write so sliders don't hammer the file.
	if _save_pending:
		_save_accum += delta
		if _save_accum >= SAVE_DEBOUNCE_S:
			_write_cfg()
	# Music / ZoneAmbience are created lazily by main.gd after we boot; retry the
	# bus routing a few times until they exist, then idle (cheap, self-limiting).
	if _reroute_tries < 40:
		_reroute_accum += delta
		if _reroute_accum >= 0.5:
			_reroute_accum = 0.0
			_reroute_tries += 1
			_reroute_audio()


# ---------------------------------------------------------------- public API

func get_setting(section: String, key: String) -> Variant:
	var sec: Dictionary = _values.get(section, {})
	if sec.has(key):
		return sec[key]
	return _default(section, key)

func set_setting(section: String, key: String, value: Variant) -> void:
	if not DEFAULTS.has(section):
		return
	if get_setting(section, key) == value and section != "controls":
		return
	if not _values.has(section):
		_values[section] = {}
	_values[section][key] = value
	_apply_one(section, key, value)
	setting_changed.emit(section, key, value)
	_queue_save()

# Spec-named aliases.
func get_v(section: String, key: String) -> Variant:
	return get_setting(section, key)

func set_v(section: String, key: String, value: Variant) -> void:
	set_setting(section, key, value)

func apply_all() -> void:
	for section: String in DEFAULTS.keys():
		if section == "controls":
			continue
		for key: String in DEFAULTS[section].keys():
			_apply_one(section, key, get_setting(section, key))
	_reroute_audio()

func reset_section(section: String) -> void:
	if not DEFAULTS.has(section):
		return
	if section == "controls":
		reset_all_keybinds()
		return
	for key: String in DEFAULTS[section].keys():
		set_setting(section, key, DEFAULTS[section][key])


# ---------------------------------------------------------------- the panel

func open() -> void:
	if _menu != null and _menu.has_method("open_menu"):
		_menu.call("open_menu")

func close() -> void:
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")

func toggle() -> void:
	if _menu != null and _menu.has_method("toggle_menu"):
		_menu.call("toggle_menu")

func is_menu_open() -> bool:
	return _menu != null and bool(_menu.get("is_open"))

func _spawn_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		return
	if not ResourceLoader.exists(MENU_SCENE):
		push_warning("OptionsSystem: %s missing." % MENU_SCENE)
		return
	var scn: PackedScene = load(MENU_SCENE) as PackedScene
	if scn == null:
		return
	_menu = scn.instantiate()
	add_child(_menu)


# ---------------------------------------------------------------- persistence

func _load() -> void:
	_values = {}
	for section: String in DEFAULTS.keys():
		_values[section] = (DEFAULTS[section] as Dictionary).duplicate(true)
	if _cfg.load(CFG_PATH) != OK:
		return
	for section: String in DEFAULTS.keys():
		if section == "controls":
			continue
		for key: String in DEFAULTS[section].keys():
			var def: Variant = DEFAULTS[section][key]
			var v: Variant = _cfg.get_value(section, key, def)
			_values[section][key] = _coerce(v, def)


func _queue_save() -> void:
	_save_pending = true
	_save_accum = 0.0

func _write_cfg() -> void:
	_save_pending = false
	_save_accum = 0.0
	_cfg.load(CFG_PATH)  # keep keys other systems own (pause_menu's music_volume)
	for section: String in DEFAULTS.keys():
		if section == "controls":
			continue
		for key: String in DEFAULTS[section].keys():
			_cfg.set_value(section, key, get_setting(section, key))
	# Keybind overrides: only actions that differ from the project defaults.
	for action: String in REBINDABLE:
		var code: int = _override_code(action)
		if code != 0:
			_cfg.set_value("controls", action, code)
		elif _cfg.has_section_key("controls", action):
			_cfg.erase_section_key("controls", action)
	if _cfg.save(CFG_PATH) != OK:
		push_warning("OptionsSystem: could not write %s" % CFG_PATH)

func _coerce(v: Variant, like: Variant) -> Variant:
	# ConfigFile round-trips types, but be defensive about int/float drift.
	if like is float:
		return float(v)
	if like is int:
		return int(v)
	if like is String:
		return str(v)
	if like is bool:
		return bool(v)
	return v

func _default(section: String, key: String) -> Variant:
	var sec: Dictionary = DEFAULTS.get(section, {})
	return sec.get(key, null)


# ---------------------------------------------------------------- apply dispatch

func _apply_one(section: String, key: String, value: Variant) -> void:
	match section:
		"video":
			match key:
				"window_mode": _apply_window_mode(str(value))
				"resolution": _apply_resolution(str(value))
				"vsync": _apply_vsync(str(value))
				"pixel_scale": _apply_pixel_scale(str(value))
		"audio":
			if BUS_FOR_KEY.has(key):
				_apply_bus_volume(str(BUS_FOR_KEY[key]), float(value))
		"gameplay":
			if key == "camera_smoothing":
				_apply_camera_smoothing(str(value))
		"controls":
			pass  # handled through rebind_action()


# ---- video ----------------------------------------------------------------

func _apply_window_mode(mode: String) -> void:
	var win: Window = get_window()
	if win == null:
		return
	match mode:
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_resolution(str(get_setting("video", "resolution")))
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _apply_resolution(res: String) -> void:
	if str(get_setting("video", "window_mode")) != "windowed":
		return
	var wh: PackedStringArray = res.split("x")
	if wh.size() != 2:
		return
	var sz := Vector2i(int(wh[0]), int(wh[1]))
	if sz.x < 320 or sz.y < 180:
		return
	var win: Window = get_window()
	if win == null:
		return
	if win.size == sz:
		return
	win.size = sz
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	win.position = usable.position + (usable.size - sz) / 2

func _apply_vsync(mode: String) -> void:
	match mode:
		"off": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"adaptive": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func _apply_pixel_scale(mode: String) -> void:
	var win: Window = get_window()
	if win == null:
		return
	win.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_INTEGER if mode == "integer"
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL)


# ---- audio ----------------------------------------------------------------

func _ensure_audio_buses() -> void:
	for bus_name: String in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.005)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.005)))

## Route the game's audio nodes onto our buses without editing their owners.
## Idempotent; called on apply_all + a few times after boot until nodes exist.
func _reroute_audio() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group("music"):
		if n is AudioStreamPlayer and (n as AudioStreamPlayer).bus != "Music":
			(n as AudioStreamPlayer).bus = "Music"
	var root: Node = tree.root
	if root != null:
		var amb: Node = root.find_child("ZoneAmbience", true, false)
		if amb is AudioStreamPlayer:
			(amb as AudioStreamPlayer).bus = "Ambience"
		var menu_music: Node = root.find_child("MenuMusic", true, false)
		if menu_music is AudioStreamPlayer:
			(menu_music as AudioStreamPlayer).bus = "Music"
	for n: Node in tree.get_nodes_in_group("sfx"):
		if n is AudioStreamPlayer:
			(n as AudioStreamPlayer).bus = "SFX"
		elif n is AudioStreamPlayer2D:
			(n as AudioStreamPlayer2D).bus = "SFX"


# ---- gameplay -------------------------------------------------------------

func _apply_camera_smoothing(mode: String) -> void:
	var cam: Node = get_tree().root.find_child("PlayerCamera", true, false)
	if cam == null or not (cam is Camera2D):
		return
	var v: float = float(CAMERA_SMOOTH.get(mode, 6.0))
	var c := cam as Camera2D
	c.position_smoothing_enabled = v > 0.0
	if v > 0.0:
		c.position_smoothing_speed = v


# ---------------------------------------------------------------- keybinds

func _capture_default_events() -> void:
	for action: String in REBINDABLE:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()

func _apply_input_overrides() -> void:
	if not _cfg.has_section("controls"):
		return
	for action: String in _cfg.get_section_keys("controls"):
		if not InputMap.has_action(action):
			continue
		var code: int = int(_cfg.get_value("controls", action, 0))
		if code != 0:
			_bind_physical(action, code)

## Public — rebind an action to a single physical key, preserving any non-key
## (mouse) event the action already had. Returns true on success.
func rebind_action(action: String, physical_keycode: int) -> bool:
	if not InputMap.has_action(action) or physical_keycode == 0:
		return false
	_bind_physical(action, physical_keycode)
	setting_changed.emit("controls", action, physical_keycode)
	_queue_save()
	return true

func reset_keybind(action: String) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for ev: InputEvent in _default_events.get(action, []):
		InputMap.action_add_event(action, ev)
	setting_changed.emit("controls", action, 0)
	_queue_save()

func reset_all_keybinds() -> void:
	for action: String in REBINDABLE:
		reset_keybind(action)

func _bind_physical(action: String, physical_keycode: int) -> void:
	# keep existing mouse/joypad events, replace the keyboard primary.
	var keep: Array[InputEvent] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if not (ev is InputEventKey):
			keep.append(ev)
	InputMap.action_erase_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)
	for ev: InputEvent in keep:
		InputMap.action_add_event(action, ev)

## Physical keycode currently bound to an action's primary key, or 0.
func action_primary_code(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0

## The override code iff the action differs from its captured default (else 0).
func _override_code(action: String) -> int:
	var cur: Array = InputMap.action_get_events(action)
	var base: Array = _default_events.get(action, [])
	if _events_equal(cur, base):
		return 0
	return action_primary_code(action)

func _events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var ea: InputEvent = a[i]
		var eb: InputEvent = b[i]
		if ea is InputEventKey and eb is InputEventKey:
			if (ea as InputEventKey).physical_keycode != (eb as InputEventKey).physical_keycode \
					or (ea as InputEventKey).keycode != (eb as InputEventKey).keycode:
				return false
		elif not ea.is_match(eb):
			return false
	return true

## Human-readable glyph for an action's binding (layout-aware for keys).
func action_display(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code: int = k.physical_keycode
			if code != 0:
				return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
			return OS.get_keycode_string(k.keycode)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "Mouse L"
				MOUSE_BUTTON_RIGHT: return "Mouse R"
				MOUSE_BUTTON_MIDDLE: return "Mouse M"
				_: return "Mouse"
	return "-"


# ---------------------------------------------------------------- QA

func _qa_audio_selftest() -> void:
	# Prove AudioServer reflects a change, then restore — no disk write.
	var idx: int = AudioServer.get_bus_index("Master")
	var before: float = AudioServer.get_bus_volume_db(idx)
	_apply_bus_volume("Master", 0.4)
	var after: float = AudioServer.get_bus_volume_db(idx)
	var midx: int = AudioServer.get_bus_index("Music")
	_apply_bus_volume("Music", 0.25)
	var mdb: float = AudioServer.get_bus_volume_db(midx) if midx != -1 else -999.0
	print("AUDIO_PROOF master 1.0->0.4 db %.2f -> %.2f (expect ~-7.96) | Music 0.25 db %.2f (expect ~-12.04) | buses=%d" \
			% [before, after, mdb, AudioServer.bus_count])
	# restore defaults so state is clean
	_apply_bus_volume("Master", float(get_setting("audio", "master")))
	_apply_bus_volume("Music", float(get_setting("audio", "music")))
