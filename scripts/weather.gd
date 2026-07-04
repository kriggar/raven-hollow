class_name WeatherController
extends Node
## Weather system for Raven Hollow — FREE / fully procedural (no art assets).
## A DayNight twin: a persistent Main-child node (group "weather") that owns a
## screen-space CanvasLayer(6) overlay. Rain/snow are GPUParticles2D with
## procedurally-generated streak/dot textures; fog is a scrolling FastNoiseLite
## shader; lightning is a tweened white flash; darkening MULTIPLIES over the
## framebuffer AFTER DayNight has tinted it, so storm-dark composites over the
## day/night cycle WITHOUT touching the frozen day_night.gd.
##
## ================= INTEGRATION (main.gd) =================
##  _spawn_systems():      _weather = WeatherController.new(); add_child(_weather)
##  change_map() (step 7): if _weather: _weather.on_map_changed(map_id)
##  _bootstrap_world():    _weather.on_map_changed("town")     # New Game
##  _bootstrap_from_save:  SaveSystem restores it (do NOT re-roll)
##  _on_quit_to_menu():    free + null _weather
##  _run_env_hooks():      RH_WEATHER=<type[,intensity]> for QA screenshots
## SAVE (save_system.gd): group "weather", serialize()/deserialize() (3-line
##  pattern, same as quests/recipes).
## Audio: streams load from res://assets/audio/weather/<name>.ogg if present;
##  absent = silent (system still works). CC0 beds drop in later.

signal weather_changed(type: int)

enum Type { CLEAR, RAIN, STORM, SNOW, FOG }

const LAYER := 6                       # above vignette(5), below HUD(8)
const VIEW := Vector2(640.0, 360.0)    # base viewport (integer-scaled)

# MUL darken target colours at full intensity (White = no darken).
const DARK := {
	Type.CLEAR: Color.WHITE,
	Type.RAIN:  Color(0.80, 0.82, 0.87),
	Type.STORM: Color(0.52, 0.57, 0.70),
	Type.SNOW:  Color(0.86, 0.89, 0.96),
	Type.FOG:   Color(0.80, 0.83, 0.88),
}

const AUDIO_DIR := "res://assets/audio/weather/"
const AMBIENCE := {
	Type.RAIN:  "rain_loop", Type.STORM: "rain_loop",
	Type.SNOW:  "wind_loop", Type.FOG:  "wind_loop",
}

# Per-map weighted weather tables (fallback if map_registry has none).
const MAP_TABLES := {
	"town": [[Type.CLEAR, 6], [Type.RAIN, 2], [Type.FOG, 1]],
	"wilderness": [[Type.CLEAR, 4], [Type.RAIN, 2], [Type.FOG, 2], [Type.STORM, 1], [Type.SNOW, 1]],
}

var _type: int = Type.CLEAR
var _intensity: float = 0.0        # live master dial 0..1
var _target_intensity: float = 0.0
var _blend_speed: float = 0.5      # intensity units / sec during a transition
var _wind: float = 0.0             # -1..1, drives rain slant + drift
var _t: float = 0.0                # fog scroll clock
var _lightning_cd: float = 0.0
var _rng := RandomNumberGenerator.new()

var _layer: CanvasLayer
var _darken: ColorRect
var _fog: TextureRect
var _fog_mat: ShaderMaterial
var _precip: GPUParticles2D
var _flash: ColorRect
var _ambience: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _rain_tex: Texture2D
var _snow_tex: Texture2D


func _init() -> void:
	name = "Weather"


func _ready() -> void:
	add_to_group("weather")
	_rng.randomize()
	_ensure_audio_bus()
	_build_overlay()
	_apply(0.0)


# ============================================================ PUBLIC API ====

## Transition to a weather state. blend_time 0 = instant (used on load).
func set_weather(type: int, target_intensity: float = 1.0, blend_time: float = 3.0) -> void:
	target_intensity = clampf(target_intensity, 0.0, 1.0)
	if type == Type.CLEAR:
		target_intensity = 0.0
	var family_change: bool = _precip_family(type) != _precip_family(_type)
	_type = type
	_target_intensity = target_intensity
	_blend_speed = (1.0 / maxf(0.05, blend_time)) if blend_time > 0.0 else 1000.0
	if blend_time <= 0.0:
		_intensity = target_intensity
	# On a family change, hard-swap the precip material at once (old fades via
	# intensity if it was mid-blend; simplest robust behaviour for the demo).
	if family_change or blend_time <= 0.0:
		_configure_precip(type)
		_configure_fog(type)
	_configure_ambience(type)
	weather_changed.emit(type)


func on_map_changed(map_id: String) -> void:
	set_weather(_roll_for_map(map_id), _rng.randf_range(0.55, 1.0), 0.0)


func current_type() -> int:
	return _type


# --------------------------------------------------------------- save/load ---

func serialize() -> Dictionary:
	return {"type": _type, "intensity": _target_intensity, "wind": _wind}


func deserialize(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	_wind = float(data.get("wind", 0.0))
	set_weather(int(data.get("type", Type.CLEAR)), float(data.get("intensity", 0.0)), 0.0)


# ================================================================ PROCESS ====

func _process(delta: float) -> void:
	_t += delta
	# ease intensity toward target
	if _intensity != _target_intensity:
		_intensity = move_toward(_intensity, _target_intensity, _blend_speed * delta)
	_apply(delta)


func _apply(delta: float) -> void:
	# 1. Darken (MUL): White -> target by intensity.
	if _darken != null:
		var d: Color = DARK.get(_type, Color.WHITE) as Color
		_darken.color = Color.WHITE.lerp(d, _intensity)
	# 2. Precip amount rides intensity.
	if _precip != null:
		var storm_boost: float = 1.35 if _type == Type.STORM else 1.0
		_precip.amount_ratio = clampf(_intensity * storm_boost, 0.0, 1.0)
		_precip.emitting = _intensity > 0.02 and _precip_family(_type) != Type.CLEAR
	# 3. Fog alpha.
	if _fog_mat != null:
		var fog_on: float = _intensity if _type == Type.FOG else (_intensity * 0.15 if _type == Type.STORM else 0.0)
		_fog_mat.set_shader_parameter("base_alpha", fog_on * 0.5)
		_fog_mat.set_shader_parameter("t", _t)
		_fog.visible = fog_on > 0.001
	# 4. Ambience volume.
	if _ambience != null and _ambience.stream != null:
		_ambience.volume_db = lerpf(-40.0, -8.0, _intensity)
	# 5. Storm lightning.
	if _type == Type.STORM and _intensity > 0.35:
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_strike()
			_lightning_cd = _rng.randf_range(4.0, 12.0)


func _strike() -> void:
	if _flash == null:
		return
	var tw := create_tween()
	_flash.color.a = 0.0
	tw.tween_property(_flash, "color:a", 0.85, 0.05)
	tw.tween_property(_flash, "color:a", 0.1, 0.08)
	tw.tween_property(_flash, "color:a", 0.6, 0.05)
	tw.tween_property(_flash, "color:a", 0.0, 0.22)
	# Thunder follows the flash by a randomized delay (distance feel).
	if _thunder != null and _thunder.stream != null:
		var delay: float = _rng.randf_range(0.3, 2.4)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(_thunder):
				_thunder.play())


# ================================================================ BUILD ====

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "WeatherLayer"
	_layer.layer = LAYER
	add_child(_layer)

	# (a) Darken — MUL blend rect, first child so precip/fog stay bright.
	_darken = ColorRect.new()
	_darken.name = "Darken"
	_darken.color = Color.WHITE
	_darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_darken.material = mul
	_layer.add_child(_darken)

	# (b) Fog — scrolling FastNoiseLite shader over a full-rect TextureRect.
	_fog = TextureRect.new()
	_fog.name = "Fog"
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.texture = _make_noise_texture()
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = _make_fog_shader()
	_fog_mat.set_shader_parameter("base_alpha", 0.0)
	_fog.material = _fog_mat
	_fog.visible = false
	_layer.add_child(_fog)

	# (c) Precip — GPUParticles2D in screen space.
	_rain_tex = _make_rain_texture()
	_snow_tex = _make_snow_texture()
	_precip = GPUParticles2D.new()
	_precip.name = "Precip"
	_precip.amount = 700
	_precip.local_coords = false
	_precip.preprocess = 2.0
	_precip.position = Vector2.ZERO
	_precip.emitting = false
	_layer.add_child(_precip)
	_configure_precip(Type.RAIN)  # default material; emitting stays false

	# (d) Flash — lightning.
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1.0, 1.0, 0.96, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)

	# (e) Audio.
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = "Weather"
	_ambience.volume_db = -40.0
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambience)
	_thunder = AudioStreamPlayer.new()
	_thunder.name = "Thunder"
	_thunder.bus = "Weather"
	add_child(_thunder)


func _configure_precip(type: int) -> void:
	if _precip == null:
		return
	var fam: int = _precip_family(type)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(340.0, 4.0, 1.0)
	if fam == Type.SNOW:
		_precip.texture = _snow_tex
		_precip.lifetime = 6.0
		_precip.position = Vector2(320.0, 180.0)
		# Slow snow: emit across the WHOLE view so flakes fill the screen
		# instantly (no top-cluster while they fall) and recycle in place.
		mat.emission_box_extents = Vector3(340.0, 200.0, 1.0)
		mat.direction = Vector3(0.0, 1.0, 0.0)
		mat.spread = 12.0
		mat.gravity = Vector3(0.0, 8.0, 0.0)
		mat.initial_velocity_min = 24.0
		mat.initial_velocity_max = 60.0
		mat.turbulence_enabled = true
		mat.turbulence_noise_strength = 0.35
		mat.turbulence_noise_scale = 1.4
		mat.scale_min = 0.8
		mat.scale_max = 1.6
	else:  # RAIN / STORM
		_precip.texture = _rain_tex
		_precip.lifetime = 1.2
		_precip.position = Vector2(320.0, -12.0)
		mat.direction = Vector3(_wind * 0.35, 1.0, 0.0)
		mat.spread = 3.0
		mat.gravity = Vector3(0.0, 300.0, 0.0)
		mat.initial_velocity_min = 420.0
		mat.initial_velocity_max = 560.0
		mat.scale_min = 0.8
		mat.scale_max = 1.2
	_precip.process_material = mat
	# Pre-simulate a full lifetime so a fresh state already fills the screen
	# (matters for slow snow, and for screenshots taken right after set_weather).
	_precip.preprocess = _precip.lifetime


func _configure_fog(_type_in: int) -> void:
	pass  # fog visual is intensity-driven in _apply; hook kept for symmetry


func _configure_ambience(type: int) -> void:
	if _ambience == null:
		return
	var name_key: String = String(AMBIENCE.get(type, ""))
	var stream: AudioStream = _load_audio(name_key) if name_key != "" else null
	if stream != _ambience.stream:
		_ambience.stream = stream
		if stream != null:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			_ambience.play()
		else:
			_ambience.stop()
	if _thunder != null and _thunder.stream == null:
		_thunder.stream = _load_audio("thunder")


# ============================================================ HELPERS ====

func _precip_family(type: int) -> int:
	match type:
		Type.RAIN, Type.STORM: return Type.RAIN
		Type.SNOW: return Type.SNOW
		_: return Type.CLEAR


func _roll_for_map(map_id: String) -> int:
	var table: Array = MAP_TABLES.get(map_id, [[Type.CLEAR, 1]])
	var total: int = 0
	for row: Array in table:
		total += int(row[1])
	var pick: int = _rng.randi_range(1, maxi(1, total))
	for row: Array in table:
		pick -= int(row[1])
		if pick <= 0:
			return int(row[0])
	return Type.CLEAR


func _load_audio(base_name: String) -> AudioStream:
	if base_name == "":
		return null
	for ext: String in [".ogg", ".wav"]:
		var p: String = AUDIO_DIR + base_name + ext
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


func _ensure_audio_bus() -> void:
	if AudioServer.get_bus_index("Weather") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Weather")
		AudioServer.set_bus_send(idx, "Master")


func _make_rain_texture() -> Texture2D:
	var w := 2
	var h := 14
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var a: float = 0.10 + 0.55 * (1.0 - absf(float(y) / float(h) - 0.5) * 2.0)
		for x in range(w):
			img.set_pixel(x, y, Color(0.78, 0.83, 0.92, a))
	return ImageTexture.create_from_image(img)


func _make_snow_texture() -> Texture2D:
	var s := 6
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5 - 0.5, s * 0.5 - 0.5)
	for y in range(s):
		for x in range(s):
			var d: float = Vector2(x, y).distance_to(c) / (s * 0.5)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, sqrt(a)))
	return ImageTexture.create_from_image(img)


func _make_noise_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = noise
	return nt


func _make_fog_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform float base_alpha = 0.0;
uniform vec3 fog_col : source_color = vec3(0.62, 0.64, 0.68);
void fragment() {
	vec2 uv1 = UV * vec2(2.0, 1.5) + vec2(t * 0.010, t * 0.004);
	vec2 uv2 = UV * vec2(1.3, 1.0) - vec2(t * 0.006, t * 0.002);
	float n = texture(noise_tex, uv1).r * 0.6 + texture(noise_tex, uv2).r * 0.4;
	COLOR = vec4(fog_col, clamp(n, 0.0, 1.0) * base_alpha);
}
"""
	return sh
