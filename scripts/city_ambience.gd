extends Node
## RAVEN HOLLOW CITY v7 — ambience runner (Fable 5.1, 2026-09-22).
## Added last by TownCity.build. Two jobs, both duck-typed against the frozen
## DayNight (group "day_night", var time_of_day):
##  * lanterns in group "city_lanterns" show their unlit grey glass by day and
##    the lit yellow glass from dusk (meta "lit_tex" / "unlit_tex");
##  * flame lights in group "city_flicker" flicker by nudging the
##    "dn_base_energy" meta DayNight multiplies every frame (so the day/night
##    ramp still applies on top). Cheap: 12 updates a second, no tweens.

const LIT_FROM: float = 17.0
const LIT_UNTIL: float = 6.5
const TICK: float = 0.08

var _lit: bool = true
var _t: float = 0.0
var _acc: float = 0.0
var _lights: Array = []
var _lanterns: Array = []
var _glow: Array = []
var _windows: Array = []
var _flames: Array = []
var _brackets: Array = []
var _late_dark: bool = false


## Groups are collected once the world is in the tree; build() adds this node
## last, but a rescan on the first ticks covers any ordering surprise.
func _collect() -> void:
	_lights = get_tree().get_nodes_in_group("city_flicker")
	_lanterns = get_tree().get_nodes_in_group("city_lanterns")
	_glow = get_tree().get_nodes_in_group("city_glow")
	_windows = get_tree().get_nodes_in_group("city_windows")
	_flames = get_tree().get_nodes_in_group("city_flames")
	_brackets = get_tree().get_nodes_in_group("city_brackets")


func _ready() -> void:
	name = "CityAmbience"
	_collect()
	var i: int = 0
	for l: Node in _lights:
		var e_v: Variant = l.get_meta("dn_base_energy") if l.has_meta("dn_base_energy") else l.get("energy")
		l.set_meta("cf_energy", float(e_v))
		l.set_meta("cf_phase", float(i) * 1.618)
		i += 1
	_apply_lit(_hour_lit())


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	if _windows.is_empty() and _t < 6.0:
		_collect()
		_apply_lit(_hour_lit())
	var lit: bool = _hour_lit()
	if lit != _lit:
		_apply_lit(lit)
	# after 23:00 most windows go dark; the "late" third keeps burning
	var curfew: bool = _curfew()
	if curfew != _late_dark:
		_late_dark = curfew
		_apply_lit(_lit)
	for l: Node in _lights:
		if not is_instance_valid(l):
			continue
		var ph: float = float(l.get_meta("cf_phase"))
		var e: float = float(l.get_meta("cf_energy"))
		var f: float = 1.0 + 0.10 * sin(_t * 7.3 + ph) + 0.06 * sin(_t * 13.1 + ph * 1.7)
		l.set_meta("dn_base_energy", e * f)


func _hour_lit() -> bool:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null:
		return true
	var h_v: Variant = dn.get("time_of_day")
	if not (h_v is float):
		return true
	var h: float = float(h_v)
	return h >= LIT_FROM or h < LIT_UNTIL


func _curfew() -> bool:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null:
		return false
	var h_v: Variant = dn.get("time_of_day")
	if not (h_v is float):
		return false
	var h: float = float(h_v)
	return h >= 23.0 or h < 5.0


func _apply_lit(lit: bool) -> void:
	_lit = lit
	for s: Node in _lanterns:
		if not is_instance_valid(s):
			continue
		var key: String = "lit_tex" if lit else "unlit_tex"
		if s.has_meta(key):
			s.set("texture", s.get_meta(key))
	for gl: Node in _glow:
		if is_instance_valid(gl):
			gl.set("visible", lit)
	for fl: Node in _flames:
		if is_instance_valid(fl):
			fl.set("visible", lit)
	for br: Node in _brackets:
		if is_instance_valid(br):
			br.set("visible", not lit)
	for wn: Node in _windows:
		if not is_instance_valid(wn):
			continue
		var on: bool = lit and (not _late_dark or bool(wn.get_meta("late", false)))
		var a: float = float(wn.get_meta("lit_alpha", 0.5)) if on else 0.0
		var m: Color = wn.get("modulate")
		m.a = a
		wn.set("modulate", m)
