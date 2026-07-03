class_name VFX
extends Object
## Procedural, self-freeing pixel VFX helpers for Raven Hollow: Emberfall.
## Purely visual — no gameplay state. Every effect cleans itself up via
## tweens / particle-finished signals, and every entry point is null-safe
## against a freed parent. Style: chunky pixels, muted earthy colors.

static var _tex_cache: Dictionary = {}
static var _font: FontFile = null


# ---------------------------------------------------------------------------
# Shared procedural textures
# ---------------------------------------------------------------------------

static func _square_tex(size: int) -> Texture2D:
	var key := "sq_%d" % size
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _triangle_tex(size: int) -> Texture2D:
	var key := "tri_%d" % size
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	for y in range(size):
		for x in range(size):
			if x <= y:
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## Soft radial falloff texture (white core -> transparent edge).
static func radial_tex(size: int = 32, hard: bool = false) -> Texture2D:
	var key := "rad_%d_%s" % [size, str(hard)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var grad := Gradient.new()
	if hard:
		grad.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
		grad.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	else:
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	_tex_cache[key] = tex
	return tex


static func _alagard() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/alagard.ttf")
	return _font


static func _alive(node: Node) -> bool:
	return node != null and is_instance_valid(node)


## Free `node` after `delay` seconds using a tween bound to the node itself.
static func _free_after(node: Node, delay: float) -> void:
	var t := node.create_tween()
	t.tween_interval(delay)
	t.tween_callback(node.queue_free)


# ---------------------------------------------------------------------------
# slash_arc — crescent sweep for melee hits
# ---------------------------------------------------------------------------

static func slash_arc(parent: Node, pos: Vector2, dir: Vector2, color: Color, radius: float) -> void:
	if not _alive(parent):
		return
	var root := Node2D.new()
	root.position = pos
	root.rotation = dir.angle()
	parent.add_child(root)

	var half := deg_to_rad(35.0)
	var fan := Node2D.new()
	root.add_child(fan)

	# Filled crescent fan (inner radius carves the crescent).
	var pts := PackedVector2Array()
	var inner := radius * 0.45
	var steps := 8
	for i in range(steps + 1):
		var a := -half + (2.0 * half) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	for i in range(steps + 1):
		var a2 := half - (2.0 * half) * float(i) / float(steps)
		pts.append(Vector2(cos(a2), sin(a2)) * inner)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(color.r, color.g, color.b, 0.4)
	fan.add_child(poly)

	# Brighter core line along the outer edge.
	var line := Line2D.new()
	var lpts := PackedVector2Array()
	for i in range(steps + 1):
		var a3 := -half + (2.0 * half) * float(i) / float(steps)
		lpts.append(Vector2(cos(a3), sin(a3)) * (radius * 0.92))
	line.points = lpts
	line.width = 2.0
	line.default_color = color.lightened(0.45)
	fan.add_child(line)

	# A few sparks flung outward along the swing.
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 5
	sparks.lifetime = 0.28
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(1, 0)
	sparks.spread = 32.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = radius * 2.2
	sparks.initial_velocity_max = radius * 3.4
	sparks.scale_amount_min = 0.8
	sparks.scale_amount_max = 1.4
	sparks.texture = _square_tex(2)
	sparks.color = color.lightened(0.3)
	sparks.position = Vector2(radius * 0.6, 0)
	root.add_child(sparks)

	# Sweep: rotate the fan through the arc while fading.
	fan.rotation = -0.55
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(fan, "rotation", 0.55, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(fan, "modulate:a", 0.0, 0.16).set_delay(0.04)
	_free_after(root, 0.5)


# ---------------------------------------------------------------------------
# impact — radial chunky burst + quick flash
# ---------------------------------------------------------------------------

static func impact(parent: Node, pos: Vector2, color: Color, size: float = 1.0) -> void:
	if not _alive(parent):
		return
	var root := Node2D.new()
	root.position = pos
	parent.add_child(root)

	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12
	burst.lifetime = 0.32
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 36.0 * size
	burst.initial_velocity_max = 70.0 * size
	burst.damping_min = 60.0
	burst.damping_max = 110.0
	burst.scale_amount_min = 0.7 * size
	burst.scale_amount_max = 1.5 * size
	burst.texture = _square_tex(3)
	burst.color = color
	root.add_child(burst)

	var flash := Sprite2D.new()
	flash.texture = radial_tex(32)
	flash.modulate = color.lightened(0.35)
	flash.scale = Vector2.ONE * 0.6 * size
	root.add_child(flash)
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "scale", Vector2.ONE * 1.2 * size, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, 0.15)
	_free_after(root, 0.6)


# ---------------------------------------------------------------------------
# ring — expanding circle outline
# ---------------------------------------------------------------------------

static func ring(parent: Node, pos: Vector2, radius: float, color: Color, duration: float = 0.5) -> void:
	if not _alive(parent):
		return
	var root := Node2D.new()
	root.position = pos
	parent.add_child(root)

	var line := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	line.points = pts
	line.closed = true
	line.width = 2.5
	line.default_color = color
	root.add_child(line)

	root.scale = Vector2.ONE * 0.12
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(root, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(line, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(root.queue_free)


# ---------------------------------------------------------------------------
# ground_circle — glowing ground decal with slow rotating rune ticks
# ---------------------------------------------------------------------------

static func ground_circle(parent: Node, pos: Vector2, radius: float, color: Color, duration: float) -> void:
	if not _alive(parent):
		return
	var root := Node2D.new()
	root.position = pos
	root.z_index = -1
	parent.add_child(root)

	# Filled soft disc.
	var fill := Sprite2D.new()
	fill.texture = radial_tex(64)
	fill.modulate = Color(color.r, color.g, color.b, 0.3)
	fill.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	root.add_child(fill)

	# Rim outline.
	var rim := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	rim.points = pts
	rim.closed = true
	rim.width = 1.5
	rim.default_color = Color(color.r, color.g, color.b, 0.75)
	root.add_child(rim)

	# Slow rotating rune-ish dashes just inside the rim.
	var runes := Node2D.new()
	root.add_child(runes)
	for i in range(8):
		var a2 := TAU * float(i) / 8.0
		var tick := Line2D.new()
		var rdir := Vector2(cos(a2), sin(a2))
		tick.points = PackedVector2Array([rdir * (radius * 0.72), rdir * (radius * 0.88)])
		tick.width = 2.0
		tick.default_color = color.lightened(0.25)
		runes.add_child(tick)

	# Soft matching light.
	var light := PointLight2D.new()
	light.texture = radial_tex(64)
	light.color = color
	light.energy = 0.5
	light.texture_scale = radius / 16.0
	root.add_child(light)

	# Slow rotation + gentle pulse for the lifetime. Pulse must ride
	# modulate (self_modulate doesn't propagate to children and the root
	# draws nothing itself), and gets killed before the fade-out so the
	# two tweens never fight over the same property.
	var spin := root.create_tween()
	spin.tween_property(runes, "rotation", TAU, maxf(duration, 0.1) * 2.0)
	var pulse := root.create_tween()
	pulse.set_loops()
	pulse.tween_property(root, "modulate:a", 0.7, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(root, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

	var t := root.create_tween()
	t.tween_interval(maxf(duration - 0.4, 0.0))
	t.tween_callback(pulse.kill)
	t.tween_property(root, "modulate:a", 0.0, 0.4)
	t.tween_callback(root.queue_free)


# ---------------------------------------------------------------------------
# smoke — soft dark-grey puffs drifting up
# ---------------------------------------------------------------------------

static func smoke(parent: Node, pos: Vector2) -> void:
	if not _alive(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.5
	p.explosiveness = 0.85
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.gravity = Vector2(0, -26)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	p.texture = _square_tex(3)
	p.color = Color(0.28, 0.27, 0.26, 0.6)
	parent.add_child(p)
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------------------
# feathers — dark fluttering triangles (rook / bird themed)
# ---------------------------------------------------------------------------

static func feathers(parent: Node, pos: Vector2) -> void:
	if not _alive(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 55)
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 52.0
	p.damping_min = 24.0
	p.damping_max = 48.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -260.0
	p.angular_velocity_max = 260.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.texture = _triangle_tex(5)
	p.color = Color(0.09, 0.16, 0.17, 0.95)
	parent.add_child(p)
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------------------
# sparkle_buff — orbiting glints + soft glow attached to a target
# ---------------------------------------------------------------------------

static func sparkle_buff(_parent: Node, target: Node2D, color: Color, duration: float) -> void:
	if not _alive(target):
		return
	var fx := Node2D.new()
	fx.position = Vector2(0, -12)
	target.add_child(fx)

	# Soft glow behind the sprite, pulsing.
	var glow := Sprite2D.new()
	glow.texture = radial_tex(32)
	glow.modulate = Color(color.r, color.g, color.b, 0.22)
	glow.scale = Vector2.ONE * 1.4
	fx.add_child(glow)
	var gp := fx.create_tween()
	gp.set_loops()
	gp.tween_property(glow, "modulate:a", 0.34, 0.4).set_trans(Tween.TRANS_SINE)
	gp.tween_property(glow, "modulate:a", 0.16, 0.4).set_trans(Tween.TRANS_SINE)

	# 4 glints orbiting the sprite.
	var pivot := Node2D.new()
	fx.add_child(pivot)
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var glint := Sprite2D.new()
		glint.texture = radial_tex(8, true)
		glint.modulate = color.lightened(0.4)
		glint.position = Vector2(cos(a), sin(a)) * 11.0
		pivot.add_child(glint)
	var orbit := fx.create_tween()
	var spins := maxf(duration, 0.3) / 0.9
	orbit.tween_property(pivot, "rotation", TAU * spins, maxf(duration, 0.3))

	var t := fx.create_tween()
	t.tween_interval(maxf(duration - 0.3, 0.0))
	t.tween_property(fx, "modulate:a", 0.0, 0.3)
	t.tween_callback(fx.queue_free)


# ---------------------------------------------------------------------------
# projectile_visual — glowing head + trail, returned for the caller to place
# ---------------------------------------------------------------------------

static func projectile_visual(kind: String, color: Color) -> Node2D:
	var root := Node2D.new()

	var trail := CPUParticles2D.new()
	trail.amount = 10
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 4.0
	trail.spread = 180.0
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.1
	trail.texture = _square_tex(2)
	trail.color = Color(color.r, color.g, color.b, 0.7)
	trail.color_ramp = _fade_ramp(color)
	root.add_child(trail)

	if kind == "arrow":
		trail.amount = 6
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		var shaft := Polygon2D.new()
		shaft.polygon = PackedVector2Array([
			Vector2(-4.5, -1.0), Vector2(2.5, -1.0), Vector2(4.5, 0.0),
			Vector2(2.5, 1.0), Vector2(-4.5, 1.0)])
		shaft.color = Color(0.62, 0.5, 0.34)
		root.add_child(shaft)
		var head := Polygon2D.new()
		head.polygon = PackedVector2Array([
			Vector2(1.5, -1.5), Vector2(4.5, 0.0), Vector2(1.5, 1.5)])
		head.color = color.lightened(0.3)
		root.add_child(head)
	elif kind == "knife":
		var sliver := Polygon2D.new()
		sliver.polygon = PackedVector2Array([
			Vector2(-2.5, -1.0), Vector2(1.0, -1.0), Vector2(2.5, 0.0),
			Vector2(1.0, 1.0), Vector2(-2.5, 1.0)])
		sliver.color = color.lightened(0.35)
		root.add_child(sliver)
		var glimmer := Sprite2D.new()
		glimmer.texture = radial_tex(8, true)
		glimmer.modulate = Color(color.r, color.g, color.b, 0.5)
		root.add_child(glimmer)
	elif kind == "fireball":
		# Big burning head: wide halo, hot core, rising ember trail.
		trail.amount = 16
		trail.lifetime = 0.5
		trail.gravity = Vector2(0, -24)
		trail.initial_velocity_max = 10.0
		trail.scale_amount_min = 0.9
		trail.scale_amount_max = 1.8
		trail.color = Color(color.r, color.g, color.b, 0.85)
		var fb_halo := Sprite2D.new()
		fb_halo.texture = radial_tex(24)
		fb_halo.modulate = Color(color.r, color.g, color.b, 0.75)
		fb_halo.scale = Vector2.ONE * 1.2
		root.add_child(fb_halo)
		var fb_core := Sprite2D.new()
		fb_core.texture = radial_tex(12, true)
		fb_core.modulate = color.lightened(0.5)
		fb_core.scale = Vector2.ONE * 1.1
		root.add_child(fb_core)
	elif kind == "spark":
		# Small hard glint with a short jittery crackle trail.
		trail.amount = 12
		trail.lifetime = 0.2
		trail.initial_velocity_max = 18.0
		trail.spread = 180.0
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		trail.color = color.lightened(0.25)
		var haze := Sprite2D.new()
		haze.texture = radial_tex(12)
		haze.modulate = Color(color.r, color.g, color.b, 0.4)
		root.add_child(haze)
		var glint := Sprite2D.new()
		glint.texture = radial_tex(8, true)
		glint.modulate = color.lightened(0.6)
		glint.scale = Vector2.ONE * 0.8
		root.add_child(glint)
	else:
		# Orb: colored halo + bright core.
		var halo := Sprite2D.new()
		halo.texture = radial_tex(16)
		halo.modulate = Color(color.r, color.g, color.b, 0.65)
		halo.scale = Vector2.ONE * 0.85
		root.add_child(halo)
		var core := Sprite2D.new()
		core.texture = radial_tex(8, true)
		core.modulate = color.lightened(0.55)
		root.add_child(core)
	return root


static func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.75),
		Color(color.r, color.g, color.b, 0.0)])
	return g


# ---------------------------------------------------------------------------
# damage_number — floating Alagard number
# ---------------------------------------------------------------------------

static func damage_number(parent: Node, pos: Vector2, amount: int, color: Color) -> void:
	if not _alive(parent):
		return
	var label := Label.new()
	var ls := LabelSettings.new()
	ls.font = _alagard()
	ls.font_size = 10
	ls.font_color = color
	ls.outline_size = 3
	ls.outline_color = Color(0.07, 0.05, 0.04, 0.9)
	label.label_settings = ls
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 12)
	var drift := randf_range(-5.0, 5.0)
	label.position = pos + Vector2(-20.0 + drift, -18.0)
	parent.add_child(label)

	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 14.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:x", label.position.x + drift * 0.6, 0.7)
	t.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.35)
	t.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------------------
# shake — small decaying camera shake (optional helper)
# ---------------------------------------------------------------------------

static func shake(camera: Camera2D, strength: float) -> void:
	if not _alive(camera):
		return
	var t := camera.create_tween()
	var s := strength
	for i in range(5):
		var off := Vector2(randf_range(-s, s), randf_range(-s, s))
		t.tween_property(camera, "offset", off, 0.03)
		s *= 0.6
	t.tween_property(camera, "offset", Vector2.ZERO, 0.05)
