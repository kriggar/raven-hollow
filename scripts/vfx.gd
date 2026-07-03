class_name VFX
extends Object
## Self-freeing pixel VFX helpers for Raven Hollow: Emberfall.
## Purely visual — no gameplay state. Every effect cleans itself up via
## tweens / signals, and every entry point is null-safe against a freed
## parent. Since the B.2 pass the heavy lifting is REAL animated
## sprite-sheet effects from FXLib (Pimen/Frostwindz/XYEzawr packs in
## res://assets/art/vfx/); the procedural bits that remain are garnish
## (sparks, rings, telegraphs, damage numbers, feathers, camera shake).

static var _tex_cache: Dictionary = {}
static var _font: FontFile = null
static var _slash_flip: bool = false


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
# slash_arc — Pimen smear sweep for melee hits (sparks kept as garnish)
# ---------------------------------------------------------------------------

static func slash_arc(parent: Node, pos: Vector2, dir: Vector2, color: Color, radius: float) -> void:
	if not _alive(parent):
		return
	var world := parent as Node2D
	if world == null:
		return
	# Real slash smear, rotated toward the aim and tinted with the class
	# color. Alternating flip_v sells a left-right combo rhythm.
	_slash_flip = not _slash_flip
	FXLib.play("smear", world, pos, {
		"rotation": dir.angle(),
		"flip": _slash_flip,
		"tint": color.lightened(0.15),
		"scale": maxf(0.6, radius / 21.0),
	})

	# A few sparks flung outward along the swing (procedural garnish).
	var sparks := CPUParticles2D.new()
	sparks.position = pos + dir * radius * 0.6
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 5
	sparks.lifetime = 0.28
	sparks.explosiveness = 1.0
	sparks.direction = dir
	sparks.spread = 32.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = radius * 2.2
	sparks.initial_velocity_max = radius * 3.4
	sparks.scale_amount_min = 0.8
	sparks.scale_amount_max = 1.4
	sparks.texture = _square_tex(2)
	sparks.color = color.lightened(0.3)
	world.add_child(sparks)
	sparks.finished.connect(sparks.queue_free)


# ---------------------------------------------------------------------------
# impact — Pimen hit spark + a few chunky debris particles as garnish
# ---------------------------------------------------------------------------

static func impact(parent: Node, pos: Vector2, color: Color, size: float = 1.0) -> void:
	if not _alive(parent):
		return
	var world := parent as Node2D
	if world == null:
		return
	# Real hit-spark burst (white core takes the tint, edges stay hot).
	FXLib.play("hit_spark", world, pos, {
		"rotation": randf_range(0.0, TAU),
		"tint": color.lightened(0.2),
		"scale": 0.75 * size,
	})

	# Chunky debris garnish.
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 6
	burst.lifetime = 0.3
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 36.0 * size
	burst.initial_velocity_max = 70.0 * size
	burst.damping_min = 60.0
	burst.damping_max = 110.0
	burst.scale_amount_min = 0.7 * size
	burst.scale_amount_max = 1.4 * size
	burst.texture = _square_tex(3)
	burst.color = color
	world.add_child(burst)
	burst.finished.connect(burst.queue_free)


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
# smoke — Pimen smoke poof (dash/vanish/summon puffs, death dissipates)
# ---------------------------------------------------------------------------

static func smoke(parent: Node, pos: Vector2) -> void:
	if not _alive(parent):
		return
	var world := parent as Node2D
	if world == null:
		return
	# The poof sheet is light grey, so a dark multiply-tint keeps the old
	# sooty look; slight random spin/flip hides repeats.
	FXLib.play("smoke_poof", world, pos + Vector2(0.0, -10.0), {
		"tint": Color(0.5, 0.48, 0.46, 0.9),
		"scale": randf_range(0.5, 0.62),
		"flip_h": randf() < 0.5,
		"speed": 1.2,
	})


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
# sparkle_buff — Pimen holy flames orbiting the target + soft glow
# ---------------------------------------------------------------------------

static func sparkle_buff(_parent: Node, target: Node2D, color: Color, duration: float) -> void:
	if not _alive(target):
		return
	var fx := Node2D.new()
	fx.position = Vector2(0, -12)
	target.add_child(fx)

	# Soft glow behind the sprite, pulsing (procedural garnish).
	var glow := Sprite2D.new()
	glow.texture = radial_tex(32)
	glow.modulate = Color(color.r, color.g, color.b, 0.22)
	glow.scale = Vector2.ONE * 1.4
	fx.add_child(glow)
	var gp := fx.create_tween()
	gp.set_loops()
	gp.tween_property(glow, "modulate:a", 0.34, 0.4).set_trans(Tween.TRANS_SINE)
	gp.tween_property(glow, "modulate:a", 0.16, 0.4).set_trans(Tween.TRANS_SINE)

	# Two real holy-flame loops wrapped around the sprite, rotated to lick
	# upward and tinted with the buff color (gold sheet -> class hue).
	var pivot := Node2D.new()
	fx.add_child(pivot)
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var flame: AnimatedSprite2D = FXLib.attach_loop(
				"holy_loop", pivot, Vector2(11.0 * side, 0.0)) as AnimatedSprite2D
		if flame != null:
			flame.rotation = -PI / 2.0
			flame.modulate = Color(color.r, color.g, color.b, 0.9).lightened(0.15)
			flame.scale = Vector2(0.8, 0.7)
			flame.flip_h = i == 1
	var orbit := fx.create_tween()
	var spins := maxf(duration, 0.3) / 1.2
	orbit.tween_property(pivot, "rotation", TAU * spins, maxf(duration, 0.3))

	var t := fx.create_tween()
	t.tween_interval(maxf(duration - 0.3, 0.0))
	t.tween_property(fx, "modulate:a", 0.0, 0.3)
	t.tween_callback(fx.queue_free)


# ---------------------------------------------------------------------------
# projectile_visual — real animated flight sprites (FXLib), trail as garnish.
# Returned node faces +X; Combat.Projectile rotates it to the flight dir.
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
		# Real arrow shaft kept (reads best at this size); a faint Pimen
		# wind crescent chases it as the fletching draft.
		trail.amount = 6
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		var draft := FXLib.make_sprite("wind_crescent")
		draft.position = Vector2(-7.0, 0.0)
		draft.modulate = Color(color.r, color.g, color.b, 0.45)
		draft.scale = Vector2.ONE * 0.55
		root.add_child(draft)
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
	elif kind == "knife" or kind == "fan_of_knives":
		# Spinning silver blade: the Pimen smear frames looped fast read
		# as a whirling knife (Fan of Knives).
		trail.amount = 6
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		var blade := FXLib.make_sprite("blade_spin")
		blade.modulate = color.lightened(0.25)
		blade.scale = Vector2.ONE * 0.55
		root.add_child(blade)
	elif kind == "arrow_storm":
		# Falling storm bolt: the XYEzawr magic arrow, tinted to the class
		# teal (rotated to the flight dir by Combat.Projectile).
		trail.amount = 6
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		var bolt := FXLib.make_sprite("magic_arrow")
		bolt.modulate = Color(color.r, color.g, color.b, 0.95).lightened(0.2)
		bolt.scale = Vector2.ONE * 0.55
		root.add_child(bolt)
	elif kind == "fireball":
		# Pimen firebolt flight loop + rising ember trail.
		trail.amount = 12
		trail.lifetime = 0.5
		trail.gravity = Vector2(0, -24)
		trail.initial_velocity_max = 10.0
		trail.scale_amount_min = 0.9
		trail.scale_amount_max = 1.6
		trail.color = Color(color.r, color.g, color.b, 0.85)
		root.add_child(FXLib.make_sprite("firebolt_fly"))
	elif kind == "spark":
		# Pimen thunder bolt loop, kept native gold (it IS the lightning),
		# with a short jittery crackle trail in the class color.
		trail.amount = 10
		trail.lifetime = 0.2
		trail.initial_velocity_max = 18.0
		trail.spread = 180.0
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.8
		trail.color = color.lightened(0.25)
		root.add_child(FXLib.make_sprite("spark_fly"))
	elif kind == "orb" or kind == "soul_bolt":
		# Soul bolt: Pimen dark comet, kept native grave-purple.
		trail.amount = 8
		trail.color = Color(color.r, color.g, color.b, 0.6)
		root.add_child(FXLib.make_sprite("soul_fly"))
	else:
		# Unknown kinds keep the procedural orb (safe fallback).
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
