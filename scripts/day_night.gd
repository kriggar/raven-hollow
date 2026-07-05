class_name DayNight
extends Node
## Day/night cycle for Raven Hollow (Phase C, SPEC_PHASE_C_DEMO.md §6).
## 10-minute full 24h cycle, starting at 17:00 (dusk). Drives a CanvasModulate
## through the spec's ambient keyframes (smooth wrap-around lerp) and ramps
## every light in the "world_lights" group up at night / down by day.
## Adds itself to group "day_night" so gameplay code can duck-type against it
## (wolf night-aggro, the Listener quest trigger, the minimap clock).
##
## Boot continuity: at the 17:00 start the ambient color is exactly the old
## permanent DUSK_TINT (1.0, 0.87, 0.72) and the light scale is exactly 1.0,
## so the first frame looks identical to the pre-Phase-C game.
##
## ============================ INTEGRATION (main.gd — integrator implements)
## 1. In _bootstrap_world(), after the world + DuskModulate exist:
##        var day_night := DayNight.new()
##        add_child(day_night)                      # child of Main, NOT World
##        day_night.attach_canvas_modulate(dusk)    # the existing CanvasModulate
##    main.gd must STOP hard-setting dusk.color = DUSK_TINT (DayNight owns the
##    color from now on). If attach is skipped, DayNight auto-discovers the
##    first CanvasModulate under the current scene (re-scanned when the world
##    is freed), so plain add_child() also works.
## 2. change_map(): the old World (and its CanvasModulate) is freed; after the
##    new map builds, call attach_canvas_modulate(new_cm) — or rely on the
##    auto-rediscovery. DayNight itself must NOT be freed with the world:
##    time_of_day persists across maps.
## 3. Builders (town_builder.gd / wilderness_builder.gd): every ambience
##    PointLight2D (lanterns, fires, forge glow) joins the registry with
##        light.add_to_group("world_lights")
##    Base energy is captured from the light's authored value on first sight
##    (stored in meta "dn_base_energy"). Lights that animate their own energy
##    (flicker tweens) should set_meta("dn_ignore", true) to opt out.
## 4. enemy.gd (night wolf aggro ×2, spec §3):
##        var dn: Node = get_tree().get_first_node_in_group("day_night")
##        var night: bool = dn != null and dn.get("is_night") == true
## 5. npc.gd: connect night_changed(bool) to shift wander targets home at
##    night (spec §6): get_first_node_in_group("day_night").night_changed.
## 6. save_system.gd: persist get_save_data() and restore apply_save_data()
##    (key "time_of_day", float hours 0..24).
## ===========================================================================

signal night_changed(is_night_now: bool)

const CYCLE_SECONDS: float = 600.0  # one full 24h day every 10 real minutes
const START_HOUR: float = 17.0
const HOURS_PER_SECOND: float = 24.0 / CYCLE_SECONDS

const COL_DAY := Color(1.0, 0.97, 0.9)
const COL_DUSK := Color(1.0, 0.87, 0.72)   # == the old permanent DUSK_TINT
const COL_NIGHT := Color(0.62, 0.66, 0.85)
const COL_DAWN_GOLD := Color(1.0, 0.84, 0.6)

## Ambient keyframes: hour -> CanvasModulate color, wrap-around lerped.
## 17:00 is pinned to COL_DUSK so a new game boots looking unchanged.
const AMBIENT_HOURS: PackedFloat32Array = [4.5, 6.5, 9.0, 15.5, 17.0, 20.0]
const AMBIENT_COLORS: PackedColorArray = [
	COL_NIGHT, COL_DAWN_GOLD, COL_DAY, COL_DAY, COL_DUSK, COL_NIGHT,
]

## Light-energy scale keyframes (multiplier on each light's authored energy).
## 17:00 is pinned to 1.0: the town's hand-tuned lantern look is the baseline.
const LIGHT_HOURS: PackedFloat32Array = [4.5, 6.5, 9.0, 15.5, 17.0, 20.0]
const LIGHT_SCALES: PackedFloat32Array = [1.3, 0.7, 0.35, 0.35, 1.0, 1.3]

## is_night window (wolf aggro ×2, Listener trigger, NPCs head home).
const NIGHT_START_HOUR: float = 19.5
const NIGHT_END_HOUR: float = 5.5

const META_BASE_ENERGY := "dn_base_energy"
const META_IGNORE := "dn_ignore"
const RESCAN_INTERVAL_FRAMES: int = 30

var time_of_day: float = START_HOUR  # hours, 0..24 wrap
var is_night: bool = false

var _canvas_modulate: CanvasModulate = null
var _rescan_cooldown: int = 0


func _init() -> void:
	name = "DayNight"


func _ready() -> void:
	add_to_group("day_night")
	is_night = _compute_is_night(time_of_day)
	_apply(0.0)


func _process(delta: float) -> void:
	_apply(delta)


## Point DayNight at the world's CanvasModulate explicitly (preferred over the
## auto-discovery fallback). Call again after every change_map rebuild.
func attach_canvas_modulate(cm: CanvasModulate) -> void:
	_canvas_modulate = cm
	_rescan_cooldown = 0


## Underground zones (biome "cave") ignore the sky: constant dim ambient and
## torch/glow lights at full burn, whatever the surface clock says.
const UNDERGROUND_AMBIENT := Color(0.40, 0.42, 0.50)
var underground: bool = false


func set_underground(on: bool) -> void:
	underground = on
	_apply(0.0)


## Zones can pin their ambient (Blestem's perpetual dusk). null = follow the sky.
var _ambient_lock: Variant = null


func set_ambient_lock(c: Variant) -> void:
	_ambient_lock = c if c is Color else null
	_apply(0.0)


## Current ambient color for the given (or current) hour — exposed so menus /
## the minimap can tint against the live palette.
func ambient_color() -> Color:
	return _ambient_at(time_of_day)


## "17:20"-style clock text (minimap HUD clock, spec §6).
func clock_text() -> String:
	return format_clock(time_of_day)


static func format_clock(hours: float) -> String:
	var h: float = fposmod(hours, 24.0)
	var hh: int = int(floorf(h))
	# Round (not floor) minutes so float drift never shows 20.9h as "20:53".
	var mm: int = mini(59, int(roundf((h - float(hh)) * 60.0)))
	return "%02d:%02d" % [hh, mm]


## Jump the clock (quest scripting / debug). Emits night_changed on a flip.
func set_time(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	_apply(0.0)


# --- save/load (consumed by save_system.gd in the integration pass) ----------

func get_save_data() -> Dictionary:
	return {"time_of_day": time_of_day}


func apply_save_data(data: Dictionary) -> void:
	var t: Variant = data.get("time_of_day")
	if t is float or t is int:
		set_time(float(t))


# --- internals ----------------------------------------------------------------

func _apply(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta * HOURS_PER_SECOND, 24.0)

	var cm: CanvasModulate = _resolve_canvas_modulate()
	if cm != null:
		if underground:
			cm.color = UNDERGROUND_AMBIENT
		elif _ambient_lock is Color:
			cm.color = _ambient_lock
		else:
			cm.color = _ambient_at(time_of_day)

	if underground:
		_update_lights(1.0)
	elif _ambient_lock is Color:
		# Perpetual-dusk streets keep their lamps burning.
		_update_lights(maxf(0.8, _light_scale_at(time_of_day)))
	else:
		_update_lights(_light_scale_at(time_of_day))

	var night_now: bool = _compute_is_night(time_of_day)
	if night_now != is_night:
		is_night = night_now
		night_changed.emit(night_now)


func _compute_is_night(hours: float) -> bool:
	return hours >= NIGHT_START_HOUR or hours < NIGHT_END_HOUR


func _resolve_canvas_modulate() -> CanvasModulate:
	if _canvas_modulate != null and is_instance_valid(_canvas_modulate):
		return _canvas_modulate
	_canvas_modulate = null
	# Throttled auto-discovery: find the world's CanvasModulate (e.g. the
	# DuskModulate main.gd builds) without requiring any wiring call.
	if _rescan_cooldown > 0:
		_rescan_cooldown -= 1
		return null
	_rescan_cooldown = RESCAN_INTERVAL_FRAMES
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var found: Array[Node] = scene.find_children("*", "CanvasModulate", true, false)
	if not found.is_empty():
		_canvas_modulate = found[0] as CanvasModulate
	return _canvas_modulate


func _update_lights(scale: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("world_lights"):
		if not is_instance_valid(node) or node.has_meta(META_IGNORE):
			continue
		var energy_v: Variant = node.get("energy")
		if not (energy_v is float):
			continue  # not a Light2D-like node
		if not node.has_meta(META_BASE_ENERGY):
			node.set_meta(META_BASE_ENERGY, energy_v)
		var base: float = float(node.get_meta(META_BASE_ENERGY))
		node.set("energy", base * scale)


func _ambient_at(hour: float) -> Color:
	var seg: Vector3 = _segment(AMBIENT_HOURS, hour)
	return AMBIENT_COLORS[int(seg.x)].lerp(AMBIENT_COLORS[int(seg.y)], seg.z)


func _light_scale_at(hour: float) -> float:
	var seg: Vector3 = _segment(LIGHT_HOURS, hour)
	return lerpf(LIGHT_SCALES[int(seg.x)], LIGHT_SCALES[int(seg.y)], seg.z)


## Wrap-around keyframe lookup over a sorted hour list.
## Returns Vector3(prev_index, next_index, t in 0..1).
static func _segment(hours: PackedFloat32Array, hour: float) -> Vector3:
	var n: int = hours.size()
	var h: float = fposmod(hour, 24.0)
	# Before the first key or after the last: the wrap segment last -> first.
	if h < hours[0] or h >= hours[n - 1]:
		var span: float = hours[0] + 24.0 - hours[n - 1]
		var into: float = h - hours[n - 1] if h >= hours[n - 1] else h + 24.0 - hours[n - 1]
		return Vector3(float(n - 1), 0.0, clampf(into / span, 0.0, 1.0))
	for i in range(n - 1):
		if h >= hours[i] and h < hours[i + 1]:
			var t: float = (h - hours[i]) / (hours[i + 1] - hours[i])
			return Vector3(float(i), float(i + 1), t)
	return Vector3(float(n - 1), float(n - 1), 0.0)  # unreachable
