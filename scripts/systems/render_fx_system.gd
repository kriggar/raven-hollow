extends Node
## RenderFXSystem -- autoload (/root/RenderFXSystem). Build #65+#67+#68
## "Render FX: terrain edge-blend + atmospheric fog + D2 behind-texture transparency".
##
## Three optional rendering layers, ALL GATED OFF BY DEFAULT. This system never
## alters shipped visuals unless a feature is explicitly turned on (env opt-in or
## the API below); with everything off, _ready does effectively nothing visible
## and _process is stopped. Mirrors the seamless-world system's "dark until asked"
## contract so the Fable-only visual law is never broken by accident.
##
##   FOG (#67, Drova-style): a self-instanced fog CanvasLayer holding a full-rect
##     ColorRect driven by assets/shaders/renderfx_fog.gdshader -- a drifting
##     fbm-noise veil + soft radial vignette. Its density is ramped by time-of-day
##     if a "day_night" node exists (guarded), denser at night.
##   D2-TRANSPARENCY (#68): each frame WHEN enabled, occluders in group "occluders"
##     (or registered via register_occluder) whose sprite rect overlaps the
##     player's body rect have their modulate.a lerped DOWN (never hiding the
##     player) and lerped back UP once clear. No player -> no-op. Safe headless.
##   TERRAIN-BLEND (#65): make_blend_material()/apply_blend_to() hand a tile the
##     renderfx_terrain_blend material (soft edge alpha via a blend_edge uniform).
##     OPT-IN ONLY -- never auto-applied to any existing tile.
##
## Additive + null-safe: no other system's file is edited. Every world/player/
## shader access is guarded (get_node_or_null / ResourceLoader.exists /
## is_instance_valid). ASCII-only prints.
##
## Public API:
##   set_fog(on) / set_transparency(on) / set_blend(on) / set_all(on)
##   is_fog_on() / is_transparency_on() / is_blend_on() / is_enabled()
##   register_occluder(node) / unregister_occluder(node)
##   make_blend_material(blend_edge := 0.15) -> ShaderMaterial
##   apply_blend_to(tile, blend_edge := 0.15) -> bool   (no-op unless blend on)
##   fog_layer() -> CanvasLayer
## Signals: renderfx_toggled(feature, on)

signal renderfx_toggled(feature, on)

const FOG_SHADER := "res://assets/shaders/renderfx_fog.gdshader"
const BLEND_SHADER := "res://assets/shaders/renderfx_terrain_blend.gdshader"
const OCCLUDER_GROUP := "occluders"

const FOG_CANVAS_LAYER := 40      # above the world, below the HUD panels
const FADE_FLOOR := 0.35          # how transparent an occluding prop gets
const FADE_SPEED := 6.0           # alpha units per second

# Time-of-day fog density targets.
const FOG_DAY_DENSITY := 0.22
const FOG_NIGHT_DENSITY := 0.55
const FOG_DEFAULT_DENSITY := 0.38

var _fog_on: bool = false
var _trans_on: bool = false
var _blend_on: bool = false

var _fog_layer: CanvasLayer = null
var _fog_rect: ColorRect = null
var _fog_density: float = FOG_DEFAULT_DENSITY

# instance_id -> {node, orig} for occluders we have faded (so they restore).
var _touched: Dictionary = {}
# Registered occluders (validity-checked), in addition to the group.
var _registered: Array = []

# Inline fallbacks so the material still works if the .gdshader import lags.
const _FOG_FALLBACK := """shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.03, 0.04, 0.06, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
void fragment() {
	float r = distance(UV, vec2(0.5));
	float vig = smoothstep(0.25, 0.78, r) * vignette;
	float a = clamp(density * 0.7 + vig * 0.5, 0.0, 1.0);
	COLOR = vec4(fog_color.rgb, a * fog_color.a);
}"""

const _BLEND_FALLBACK := """shader_type canvas_item;
uniform float blend_edge : hint_range(0.0, 0.5) = 0.15;
uniform float blend_amount : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 d = min(UV, vec2(1.0) - UV);
	float e = smoothstep(0.0, max(blend_edge, 0.0001), min(d.x, d.y));
	float a = mix(1.0, e, clamp(blend_amount, 0.0, 1.0));
	COLOR = tex * COLOR;
	COLOR.a *= a;
}"""


func _ready() -> void:
	set_process(false)
	# Env opt-in (deferred so the root viewport is settled before we build a layer).
	if OS.get_environment("RH_FOG") == "1" \
			or OS.get_environment("RH_D2TRANS") == "1" \
			or OS.get_environment("RH_BLEND") == "1":
		call_deferred("_apply_env_flags")
	if not OS.get_environment("RH_RENDERFX_TEST").is_empty():
		call_deferred("_run_selftest")


func _apply_env_flags() -> void:
	if OS.get_environment("RH_FOG") == "1":
		set_fog(true)
	if OS.get_environment("RH_D2TRANS") == "1":
		set_transparency(true)
	if OS.get_environment("RH_BLEND") == "1":
		set_blend(true)


# --- Feature toggles --------------------------------------------------------

func set_fog(on: bool) -> void:
	on = bool(on)
	_fog_on = on
	if on:
		_build_fog_layer()
		if _fog_layer != null and is_instance_valid(_fog_layer):
			_fog_layer.visible = true
	else:
		_teardown_fog_layer()
	_sync_process()
	renderfx_toggled.emit("fog", on)


func set_transparency(on: bool) -> void:
	on = bool(on)
	_trans_on = on
	if not on:
		_restore_all_occluders()
	_sync_process()
	renderfx_toggled.emit("transparency", on)


func set_blend(on: bool) -> void:
	on = bool(on)
	_blend_on = on
	renderfx_toggled.emit("blend", on)


func set_all(on: bool) -> void:
	set_fog(on)
	set_transparency(on)
	set_blend(on)


func is_fog_on() -> bool:
	return _fog_on


func is_transparency_on() -> bool:
	return _trans_on


func is_blend_on() -> bool:
	return _blend_on


func is_enabled() -> bool:
	return _fog_on or _trans_on or _blend_on


func fog_layer() -> CanvasLayer:
	return _fog_layer if is_instance_valid(_fog_layer) else null


func _sync_process() -> void:
	set_process(_fog_on or _trans_on)


# --- Per-frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _fog_on:
		_update_fog(delta)
	if _trans_on:
		_update_transparency(delta)


# --- FOG (#67) ---------------------------------------------------------------

func _build_fog_layer() -> void:
	if _fog_layer != null and is_instance_valid(_fog_layer):
		return
	var cl := CanvasLayer.new()
	cl.name = "RenderFXFog"
	cl.layer = FOG_CANVAS_LAYER
	var rect := ColorRect.new()
	rect.name = "FogRect"
	rect.color = Color(1.0, 1.0, 1.0, 1.0)   # shader owns the real color/alpha
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _make_fog_material()
	cl.add_child(rect)
	add_child(cl)
	_fog_layer = cl
	_fog_rect = rect
	_resize_fog_rect()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_resize_fog_rect):
		vp.size_changed.connect(_resize_fog_rect)


func _teardown_fog_layer() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_resize_fog_rect):
		vp.size_changed.disconnect(_resize_fog_rect)
	if _fog_layer != null and is_instance_valid(_fog_layer):
		_fog_layer.queue_free()
	_fog_layer = null
	_fog_rect = null


func _resize_fog_rect() -> void:
	if _fog_rect == null or not is_instance_valid(_fog_rect):
		return
	var sz := Vector2(1152.0, 648.0)
	var vp := get_viewport()
	if vp != null:
		var v: Vector2 = vp.get_visible_rect().size
		if v.x > 0.0 and v.y > 0.0:
			sz = v
	_fog_rect.position = Vector2.ZERO
	_fog_rect.size = sz


func _make_fog_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _load_shader(FOG_SHADER, _FOG_FALLBACK)
	mat.set_shader_parameter("density", _fog_density)
	return mat


func _update_fog(delta: float) -> void:
	var target: float = FOG_DEFAULT_DENSITY
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and is_instance_valid(dn):
		target = FOG_NIGHT_DENSITY if bool(dn.get("is_night")) else FOG_DAY_DENSITY
	_fog_density = lerpf(_fog_density, target, clampf(delta * 2.0, 0.0, 1.0))
	if _fog_rect != null and is_instance_valid(_fog_rect) and _fog_rect.material is ShaderMaterial:
		(_fog_rect.material as ShaderMaterial).set_shader_parameter("density", _fog_density)


# --- D2 TRANSPARENCY (#68) ---------------------------------------------------

func register_occluder(node: Object) -> void:
	if node is CanvasItem and not _registered.has(node):
		_registered.append(node)


func unregister_occluder(node: Object) -> void:
	_registered.erase(node)


func _update_transparency(delta: float) -> void:
	var pl: Node = _player()
	var pr: Variant = _player_rect(pl)
	var overlapping: Dictionary = {}
	if pr != null:
		for occ: Object in _iter_occluders():
			if not is_instance_valid(occ) or not (occ is CanvasItem):
				continue
			var orect: Variant = _occluder_rect(occ)
			if orect == null:
				continue
			if (pr as Rect2).intersects(orect as Rect2):
				overlapping[occ.get_instance_id()] = true
				_fade_down(occ as CanvasItem, delta)
	# Restore any occluder we previously faded that is no longer overlapping.
	for iid: int in _touched.keys().duplicate():
		if overlapping.has(iid):
			continue
		var rec: Dictionary = _touched[iid]
		var node: Object = rec.get("node")
		if not is_instance_valid(node):
			_touched.erase(iid)
			continue
		_fade_up(node as CanvasItem, rec, delta)


func _fade_down(node: CanvasItem, delta: float) -> void:
	var iid: int = node.get_instance_id()
	if not _touched.has(iid):
		_touched[iid] = {"node": node, "orig": node.modulate.a}
	var m: Color = node.modulate
	m.a = move_toward(m.a, FADE_FLOOR, FADE_SPEED * delta)
	node.modulate = m


func _fade_up(node: CanvasItem, rec: Dictionary, delta: float) -> void:
	var orig: float = float(rec.get("orig", 1.0))
	var m: Color = node.modulate
	m.a = move_toward(m.a, orig, FADE_SPEED * delta)
	node.modulate = m
	if is_equal_approx(m.a, orig):
		m.a = orig
		node.modulate = m
		_touched.erase(node.get_instance_id())


func _restore_all_occluders() -> void:
	for iid: int in _touched.keys():
		var rec: Dictionary = _touched[iid]
		var node: Object = rec.get("node")
		if is_instance_valid(node) and node is CanvasItem:
			var m: Color = (node as CanvasItem).modulate
			m.a = float(rec.get("orig", 1.0))
			(node as CanvasItem).modulate = m
	_touched.clear()


func _iter_occluders() -> Array:
	var out: Array = []
	var t: SceneTree = get_tree()
	if t != null:
		for n: Node in t.get_nodes_in_group(OCCLUDER_GROUP):
			out.append(n)
	for n: Object in _registered:
		if is_instance_valid(n) and not out.has(n):
			out.append(n)
	return out


func _player_rect(pl: Node) -> Variant:
	if pl == null or not (pl is Node2D):
		return null
	var p: Vector2 = (pl as Node2D).global_position
	var w: float = 40.0
	var h: float = 96.0
	# Body rect: rises from the feet (at p) upward.
	return Rect2(p + Vector2(-w * 0.5, -h + 8.0), Vector2(w, h))


func _occluder_rect(occ: Object) -> Variant:
	if not (occ is Node2D):
		return null
	var n2d := occ as Node2D
	var pos: Vector2 = n2d.global_position
	var sz: Vector2 = Vector2(48.0, 96.0)
	if occ is Sprite2D and (occ as Sprite2D).texture != null:
		var tex: Texture2D = (occ as Sprite2D).texture
		sz = Vector2(float(tex.get_width()), float(tex.get_height())) * n2d.global_scale.abs()
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = Vector2(48.0, 96.0)
	# Rect rises from the base (feet) upward, centered horizontally.
	return Rect2(pos - Vector2(sz.x * 0.5, sz.y), sz)


# --- TERRAIN BLEND (#65) -----------------------------------------------------

func make_blend_material(blend_edge: float = 0.15) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _load_shader(BLEND_SHADER, _BLEND_FALLBACK)
	mat.set_shader_parameter("blend_edge", clampf(blend_edge, 0.0, 0.5))
	return mat


## Hand a tile the blend material. OPT-IN ONLY: a no-op (returns false) unless
## blend is enabled -- shipped tiles are never altered without explicit opt-in.
func apply_blend_to(tile: Object, blend_edge: float = 0.15) -> bool:
	if not _blend_on:
		return false
	if tile == null or not (tile is CanvasItem):
		return false
	(tile as CanvasItem).material = make_blend_material(blend_edge)
	return true


# --- Shared helpers ----------------------------------------------------------

func _load_shader(path: String, fallback: String) -> Shader:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Shader and not (res as Shader).code.is_empty():
			return res as Shader
	var sh := Shader.new()
	sh.code = fallback
	return sh


func _player() -> Node:
	var t: SceneTree = get_tree()
	return t.get_first_node_in_group("player") if t != null else null


# --- Self-test (RH_RENDERFX_TEST=1) -----------------------------------------

func _run_selftest() -> void:
	# Let the tree settle so get_viewport()/root exist.
	await get_tree().process_frame
	var results: Array = []
	var ok: bool = true

	# Enable all three features programmatically.
	set_fog(true)
	set_transparency(true)
	set_blend(true)

	# 1) Fog layer instanced + visible.
	var fog_ok: bool = _fog_layer != null and is_instance_valid(_fog_layer) \
			and _fog_layer.visible and _fog_rect != null and _fog_rect.visible
	ok = ok and fog_ok
	results.append("fog_layer=%s" % str(fog_ok))

	# Fake the minimal nodes: a player + an overlapping occluder sprite.
	var pl := Node2D.new()
	pl.global_position = Vector2(500.0, 500.0)
	pl.add_to_group("player")
	add_child(pl)
	var img: Image = Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	var occ_tex: ImageTexture = ImageTexture.create_from_image(img)
	var occ := Sprite2D.new()
	occ.texture = occ_tex
	occ.global_position = Vector2(500.0, 500.0)
	occ.add_to_group(OCCLUDER_GROUP)
	add_child(occ)

	# 2) Overlapping occluder fades DOWN.
	for _i in range(30):
		_update_transparency(0.1)
	var faded: float = occ.modulate.a
	var fade_ok: bool = faded < 0.9
	ok = ok and fade_ok
	results.append("occluder_faded_a=%.2f(%s)" % [faded, str(fade_ok)])

	# 3) Move it clear -> restores UP.
	occ.global_position = Vector2(4000.0, 4000.0)
	for _j in range(40):
		_update_transparency(0.1)
	var restored: float = occ.modulate.a
	var restore_ok: bool = restored > 0.95
	ok = ok and restore_ok
	results.append("occluder_restored_a=%.2f(%s)" % [restored, str(restore_ok)])

	# 4) Blend shader resource loads/compiles + material builds.
	var bres: Resource = load(BLEND_SHADER) if ResourceLoader.exists(BLEND_SHADER) else null
	var res_ok: bool = bres is Shader and not (bres as Shader).code.is_empty()
	var bmat: ShaderMaterial = make_blend_material(0.2)
	var mat_ok: bool = bmat != null and bmat.shader != null and not bmat.shader.code.is_empty()
	ok = ok and res_ok and mat_ok
	results.append("blend_shader=%s" % str(res_ok and mat_ok))

	# 5) apply_blend_to works only while blend is enabled.
	var tile := Sprite2D.new()
	tile.texture = occ_tex
	add_child(tile)
	var applied: bool = apply_blend_to(tile, 0.2)
	ok = ok and applied
	results.append("blend_applied=%s" % str(applied))

	# Clean up faked nodes.
	occ.queue_free()
	pl.queue_free()
	tile.queue_free()

	# 6) Disable all -> no residual fog layer, no faded state.
	set_all(false)
	var no_layer: bool = _fog_layer == null or not is_instance_valid(_fog_layer)
	var clean: bool = _touched.is_empty()
	ok = ok and no_layer and clean
	results.append("no_residual=%s" % str(no_layer and clean))

	print("RENDERFX SELFTEST %s %s" % ["PASS" if ok else "FAIL", " ".join(results)])
