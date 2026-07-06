class_name Combat
## Static combat helpers for Raven Hollow: Emberfall.
##  - deal_damage: routes into a target's take_damage + floating damage number.
##  - spawn_projectile: faction-aware Area2D projectile (group-based hit test
##    within 10 px, frees on wall contact via body_entered on mask 1).
##  - spawn_world_enemies: deterministic TOWN skeleton placements plus the
##    training scarecrow (LPC decorations atlas, region verified by pixel
##    inspection: Rect2(320, 130, 32, 62), pole base on the crop bottom).
##  - spawn_map_enemies(parent, built): Phase C wilderness spawn. The wilderness
##    builder OWNS positions/config (built["enemy_spawns"]/["ambient_spawns"]);
##    this OWNS instantiation — killable animals become Enemy.create (fauna flag
##    -> LPC animal sprites, handled in enemy.gd), ambient critters become
##    Combat.Fauna (group "ambient_fauna", flee-only, never in "enemies").
##  - find_nearest_enemy: nearest living member of group "enemies".

const DMG_ON_ENEMY := Color(0.95, 0.92, 0.85)   # bone-white, player-dealt
const DMG_ON_PLAYER := Color(0.9, 0.28, 0.22)   # red, player was hit
const SCARECROW_POS := Vector2(1650.0, 950.0)

## Deterministic TOWN spawns. Skeletons haunt the graveyard OUTSKIRTS (west and
## north of the fence, off the lane). The Phase A orc camp used to sit SE of the
## farm here; Phase C relocates it to the wilderness (SPEC §3e / contract §10),
## so wilderness_builder now owns those 6 orcs + the orc_shaman via its
## build()["enemy_spawns"], instantiated by spawn_map_enemies() below.
const ENEMY_SPAWNS: Array[Dictionary] = [
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(140.0, 300.0),
		"level": 1, "archetype": "brute", "hp": 180.0, "damage": 11.0, "speed": 56.0, "patrol_radius": 55.0},
	{"type": "skeleton_rogue", "display_name": "Skeleton Rogue", "pos": Vector2(125.0, 435.0),
		"level": 1, "archetype": "duelist", "hp": 162.0, "damage": 9.0, "speed": 74.0, "patrol_radius": 65.0},
	{"type": "skeleton_warrior", "display_name": "Skeleton Warrior", "pos": Vector2(185.0, 495.0),
		"level": 2, "archetype": "guarded", "hp": 270.0, "damage": 14.0, "speed": 52.0, "patrol_radius": 45.0},
	{"type": "skeleton_mage", "display_name": "Skeleton Mage", "pos": Vector2(330.0, 165.0),
		"level": 2, "archetype": "caster", "hp": 145.0, "damage": 15.0, "speed": 48.0, "patrol_radius": 60.0},
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(520.0, 155.0),
		"level": 1, "archetype": "brute", "hp": 180.0, "damage": 11.0, "speed": 58.0, "patrol_radius": 80.0},
]


static func deal_damage(target: Node, amount: float, source: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.call("take_damage", amount, source)
	if target.has_meta("own_damage_numbers"):
		return  # target spawns its own number (training scarecrow)
	var t2d := target as Node2D
	if t2d == null:
		return
	var parent := t2d.get_parent()
	if parent == null:
		return
	var color: Color = DMG_ON_PLAYER if target.is_in_group("player") else DMG_ON_ENEMY
	VFX.damage_number(parent, t2d.global_position + Vector2(0.0, -26.0), int(round(amount)), color)


static func spawn_projectile(world: Node2D, cfg: Dictionary) -> void:
	if world == null:
		return
	world.add_child(Projectile.new(cfg))


static func spawn_world_enemies(world: Node2D) -> void:
	if world == null:
		return
	for cfg: Dictionary in ENEMY_SPAWNS:
		world.add_child(Enemy.create(cfg))
	world.add_child(Scarecrow.new(SCARECROW_POS))


## Phase C per-map spawn (wilderness). The map builder returns the placements;
## we instantiate them. `built["enemy_spawns"]` are killable combatants
## (wolf/boar/bear carry "fauna": true -> animal sprites; orcs reuse the mob
## sheets), each a full Enemy so targeting/nameplate/XP/drops/report_kill work
## unchanged. `built["ambient_spawns"]` are deer/fox/rabbit/bird — Combat.Fauna,
## which flee but never fight and live in group "ambient_fauna" (never
## "enemies"), so kill/aggro/AoE logic ignores them.
static func spawn_map_enemies(parent: Node2D, built: Dictionary) -> void:
	if parent == null:
		return
	for cfg_v: Variant in built.get("enemy_spawns", []):
		if cfg_v is Dictionary:
			parent.add_child(Enemy.create(cfg_v))
	for cfg_v: Variant in built.get("ambient_spawns", []):
		if cfg_v is Dictionary:
			parent.add_child(Fauna.new(cfg_v))


static func find_nearest_enemy(from: Vector2, max_dist: float) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Node2D = null
	var best_d: float = max_dist
	for node: Node in tree.get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = e.global_position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = e
	return best


class Projectile extends Area2D:
	## Faction-aware projectile. Node position rides the FEET line (y-sort
	## participant in the world); the visual is lifted to torso height. Hits
	## are group-based (nearest opposing target within HIT_RADIUS); walls
	## (physics layer 1) free it via body_entered.
	const HIT_RADIUS: float = 10.0

	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 200.0
	var range_left: float = 140.0
	var damage: float = 5.0
	var faction: String = "player"
	var color: Color = Color(0.85, 0.68, 0.35)
	var aoe_radius: float = 0.0  # > 0: splash damage around the impact point
	## Opt-in cfg fields (player.gd _arm_ranged): "crit" marks a pre-rolled
	## crit payload; "on_hit" is a Callable(target, damage, crit_styled)
	## invoked after each damage application so the owner can render the gold
	## crit number and run on-kill effects. Both default to inert.
	var crit: bool = false
	var on_hit: Callable = Callable()
	## Ability fx id (cfg "fx"): played through FXLib on impact (e.g. the
	## fireball explosion, spark crackle, soul-bolt burst, arrow wind hit).
	var fx_impact: String = ""

	func _init(cfg: Dictionary) -> void:
		name = "Projectile"
		position = cfg.get("pos", Vector2.ZERO)
		dir = cfg.get("dir", Vector2.RIGHT)
		if dir.length_squared() < 0.0001:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		speed = maxf(20.0, float(cfg.get("speed", 200.0)))
		range_left = maxf(8.0, float(cfg.get("range", 140.0)))
		damage = float(cfg.get("damage", 5.0))
		faction = str(cfg.get("faction", "player"))
		color = cfg.get("color", Color(0.85, 0.68, 0.35))
		aoe_radius = float(cfg.get("aoe_radius", 0.0))
		crit = bool(cfg.get("crit", false))
		fx_impact = str(cfg.get("fx", ""))
		var on_hit_v: Variant = cfg.get("on_hit")
		if on_hit_v is Callable:
			on_hit = on_hit_v
		z_index = 1  # above ground decals, still y-sorted among sprites
		collision_layer = 0
		collision_mask = 1
		monitoring = true
		var col := CollisionShape2D.new()
		col.name = "Hit"
		var circle := CircleShape2D.new()
		circle.radius = 3.0
		col.shape = circle
		add_child(col)
		var visual: Node2D = VFX.projectile_visual(str(cfg.get("kind", "bolt")), color)
		if visual != null:
			visual.position = Vector2(0.0, -12.0)
			visual.rotation = dir.angle()  # arrow/knife visuals point +X
			add_child(visual)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		var step: float = speed * delta
		position += dir * step
		range_left -= step
		if range_left <= 0.0:
			queue_free()
			return
		var target: Node2D = _nearest_target()
		if target != null:
			_hit(target)

	func _nearest_target() -> Node2D:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		var group_name: String = "enemies" if faction == "player" else "player"
		var best: Node2D = null
		var best_d: float = HIT_RADIUS
		for node: Node in tree.get_nodes_in_group(group_name):
			var t := node as Node2D
			if t == null or not is_instance_valid(t):
				continue
			if faction == "player":
				if t.get("is_dead") == true:
					continue
			else:
				var hp_v: Variant = t.get("hp")
				if hp_v is float and float(hp_v) <= 0.0:
					continue
			var d: float = t.global_position.distance_to(global_position)
			if d <= best_d:
				best_d = d
				best = t
		return best

	func _hit(target: Node2D) -> void:
		if aoe_radius > 0.0:
			_splash()
		else:
			_deal(target)
		var parent := get_parent()
		if parent != null:
			# Same visual height as _play_impact_fx (and the flight visual at
			# y-12) so the spark garnish and the sheet impact read as ONE hit.
			VFX.impact(parent, global_position + Vector2(0.0, -10.0), color)
			_play_impact_fx(parent)
		set_physics_process(false)
		queue_free()

	func _play_impact_fx(parent: Node) -> void:
		## Sheet-based impact keyed by the ability fx id (FXLib alias maps
		## e.g. "fireball" -> fire_explosion). Sized up when there is splash.
		var world := parent as Node2D
		if world == null or fx_impact.is_empty() or not FXLib.has_fx(fx_impact):
			return
		var opts: Dictionary = {"rotation": randf_range(0.0, TAU)}
		if aoe_radius > 0.0:
			opts["scale"] = maxf(1.0, aoe_radius * 2.0 / 64.0)
			opts["rotation"] = 0.0
		FXLib.play(fx_impact, world, global_position + Vector2(0.0, -10.0), opts)

	func _deal(target: Node2D) -> void:
		## Applies the payload to one target. A pre-rolled crit with a live
		## on_hit owner suppresses the standard white number (mirrors the
		## melee path in player._deal_player_damage) so the owner can draw
		## the bigger gold one; targets that spawn their own numbers keep
		## the normal route. on_hit always fires afterwards (kill hooks).
		var styled: bool = crit and on_hit.is_valid() \
				and not target.has_meta("own_damage_numbers") \
				and target.has_method("take_damage")
		if styled:
			target.call("take_damage", damage, self)
		else:
			Combat.deal_damage(target, damage, self)
		if on_hit.is_valid():
			on_hit.call(target, damage, styled)

	func _splash() -> void:
		## Impact splash (Fireball): full damage to every living opposing-group
		## member within aoe_radius of the impact point.
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		var parent := get_parent()
		if parent != null:
			VFX.ring(parent, global_position, aoe_radius, color, 0.3)
		var group_name: String = "enemies" if faction == "player" else "player"
		for node: Node in tree.get_nodes_in_group(group_name):
			var t := node as Node2D
			if t == null or not is_instance_valid(t) or t.get("is_dead") == true:
				continue
			if t.global_position.distance_to(global_position) <= aoe_radius:
				_deal(t)

	func _on_body_entered(body: Node) -> void:
		if is_queued_for_deletion():
			return
		# The solid scarecrow sits on layer 1 too — treat it as a real hit.
		if faction == "player" and body != null and body is Node2D \
				and body.is_in_group("enemies") and body.get("is_dead") != true:
			_hit(body as Node2D)
			return
		var parent := get_parent()
		if parent != null:
			VFX.impact(parent, global_position, color, 0.7)
		queue_free()


class Scarecrow extends StaticBody2D:
	## Training dummy in group "enemies": shows damage numbers + wobbles, never
	## dies. Sprite: LPC decorations scarecrow, region verified by pixel
	## inspection (red hat + green coat on a pole, pole base at crop bottom).
	## Carries a bar-less Enemy.Nameplate (name only — infinite HP would make a
	## bar meaningless); the plate manages its own visibility and target glow.
	const REGION := Rect2(320.0, 130.0, 32.0, 62.0)

	var is_dead: bool = false
	var hp: float = 999999.0
	var max_hp: float = 999999.0
	var display_name: String = "Training Scarecrow"

	var _spr: Sprite2D
	var _wobble: Tween

	func _init(pos: Vector2) -> void:
		name = "TrainingScarecrow"
		position = pos
		collision_layer = 1 | (1 << 3)  # solid to walkers (layer 1) AND enemy layer (layer number 4)
		collision_mask = 0
		y_sort_enabled = true
		add_to_group("enemies")
		# Combat.deal_damage skips its number for us — we spawn our own, so
		# direct take_damage callers still get feedback without doubles.
		set_meta("own_damage_numbers", true)
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/art/decor/lpc_decorations.png")
		at.region = REGION
		_spr = Sprite2D.new()
		_spr.name = "Sprite"
		_spr.texture = at
		_spr.centered = true
		_spr.offset = Vector2(0.0, -31.0)  # pole base (crop bottom) = node pos
		add_child(_spr)
		var col := CollisionShape2D.new()
		col.name = "Base"
		var circle := CircleShape2D.new()
		circle.radius = 4.0
		col.shape = circle
		add_child(col)
		# Bar-less nameplate above the 62 px sprite (crop top sits at y=-62).
		var plate := Enemy.Nameplate.new(display_name, false)
		plate.position = Vector2(0.0, -70.0)
		plate.visible = false
		add_child(plate)

	func take_damage(amount: float, _source: Node) -> void:
		var parent := get_parent()
		if parent != null:
			VFX.damage_number(parent, global_position + Vector2(0.0, -44.0),
					int(round(amount)), Combat.DMG_ON_ENEMY)
		if _wobble != null and _wobble.is_valid():
			_wobble.kill()
		_spr.rotation = 0.0
		# Rotation pivot is the node origin (pole base), so it sways in place.
		_wobble = create_tween()
		_wobble.tween_property(_spr, "rotation", 0.14, 0.05)
		_wobble.tween_property(_spr, "rotation", -0.1, 0.09)
		_wobble.tween_property(_spr, "rotation", 0.05, 0.08)
		_wobble.tween_property(_spr, "rotation", 0.0, 0.08)


class Fauna extends Node2D:
	## Ambient wilderness critter (deer / fox / rabbit / bird) — SPEC §3, contract
	## §9. Lives in group "ambient_fauna" and NEVER in "enemies": no hp, no
	## take_damage, no nameplate, no target, so combat/targeting/AoE ignore it
	## entirely. It idly wanders around its spawn (home) and, when the player
	## comes within flee_radius (~60px), walks/flies directly away for a beat —
	## selling the forest as alive. Lightweight Node2D (no physics body); it moves
	## its own position and clips through props, which is fine for decoration.
	## Sprite rects are PIL-verified (wild_geometry.json + scratchpad crops); all
	## picked rows face RIGHT (flip_h mirrors for leftward motion). Birds hop on a
	## perched row and switch to the top-down fly row while fleeing.
	const FAUNA_DIR := "res://_downloads/wilderness/animals/"
	const WANDER_SPEED: float = 24.0
	const FLEE_SPEED: float = 96.0
	const FLEE_HOLD: float = 1.1

	var type_name: String = "deer"
	var flee_radius: float = 60.0
	var home: Vector2 = Vector2.ZERO

	var _sprite: AnimatedSprite2D
	var _rng := RandomNumberGenerator.new()
	var _art_faces_left: bool = false
	var _is_bird: bool = false
	var _off: Vector2 = Vector2(0.0, -32.0)
	var _wander_radius: float = 56.0
	var _target: Vector2 = Vector2.ZERO
	var _idle_wait: float = 0.0
	var _flee_left: float = 0.0

	func _init(cfg: Dictionary) -> void:
		type_name = str(cfg.get("type", "deer"))
		position = cfg.get("pos", Vector2.ZERO)
		home = position
		flee_radius = float(cfg.get("flee_radius", 60.0))
		name = "Fauna_" + type_name
		y_sort_enabled = true
		# Deterministic-ish wander seeded from the spawn (mirrors Enemy).
		_rng.seed = hash(position)
		_target = position
		_idle_wait = _rng.randf_range(0.4, 2.2)
		_build_sprite()

	func _build_sprite() -> void:
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		match type_name:
			"fox":
				# fox, woods.png 256x256 4x4; row1 (y64) = RIGHT-facing side walk.
				var t: Texture2D = load(FAUNA_DIR + "lpc2022/lpc animals 2022 v1.1/individual creature spritesheets/fox, woods.png")
				_add(sf, t, "idle", [Rect2(0, 64, 64, 64)], 3.0, true)
				_add(sf, t, "move", [Rect2(0, 64, 64, 64), Rect2(64, 64, 64, 64),
						Rect2(128, 64, 64, 64), Rect2(192, 64, 64, 64)], 9.0, true)
				_off = Vector2(0.0, -32.0)
			"rabbit":
				# bunnysheet5.png is hand-packed (no clean grid); these three
				# bottom-row side hops (facing RIGHT) are tight, PIL-verified rects.
				var t: Texture2D = load(FAUNA_DIR + "bunnysheet5.png")
				_add(sf, t, "idle", [Rect2(25, 283, 28, 34)], 2.0, true)
				_add(sf, t, "move", [Rect2(25, 283, 28, 34), Rect2(59, 283, 29, 34),
						Rect2(94, 283, 36, 34)], 8.0, true)
				_off = Vector2(0.0, -17.0)
				# PIXEL-VERIFIED 2026-07-05 (owner bug report: rabbits ran left
				# facing right): these frames face LEFT, not right as the old
				# annotation claimed. facing_check.png is the evidence.
				_art_faces_left = true
			"bird":
				# bird_1_brown.png 96x256 3x8 @32; row7 (y224) = ground/perched
				# side (RIGHT), row2 (y64) = top-down wings-spread fly.
				var t: Texture2D = load(FAUNA_DIR + "bird_1_brown.png")
				_add(sf, t, "idle", [Rect2(0, 224, 32, 32), Rect2(32, 224, 32, 32),
						Rect2(64, 224, 32, 32)], 4.0, true)
				_add(sf, t, "fly", [Rect2(0, 64, 32, 32), Rect2(32, 64, 32, 32),
						Rect2(64, 64, 32, 32)], 12.0, true)
				_is_bird = true
				_off = Vector2(0.0, -16.0)
			_:
				# "deer": deer, light doe.png 256x384 4x(64x96); row2 (y192) =
				# RIGHT-facing side walk. Tall frames (antler clearance).
				var t: Texture2D = load(FAUNA_DIR + "lpc2022/lpc animals 2022 v1.1/individual creature spritesheets/deer, light doe.png")
				_add(sf, t, "idle", [Rect2(0, 192, 64, 96)], 3.0, true)
				_add(sf, t, "move", [Rect2(0, 192, 64, 96), Rect2(64, 192, 64, 96),
						Rect2(128, 192, 64, 96), Rect2(192, 192, 64, 96)], 8.0, true)
				_off = Vector2(0.0, -48.0)
		var spr := AnimatedSprite2D.new()
		spr.name = "Sprite"
		spr.sprite_frames = sf
		# Owner QA (2026-07-05): size + palette harmonization (see enemy.gd).
		var fscale: float = {"fox": 0.55, "deer": 0.62, "rabbit": 0.90,
				"bird": 1.0}.get(type_name, 0.65)
		spr.scale = Vector2.ONE * fscale
		if type_name != "bird":
			spr.modulate = Color(0.90, 0.87, 0.83)
		spr.centered = true
		spr.offset = _off
		spr.play("idle")
		add_child(spr)
		_sprite = spr

	func _add(sf: SpriteFrames, tex: Texture2D, anim: String, rects: Array, fps: float, loop: bool) -> void:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, loop)
		for r: Rect2 in rects:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = r
			sf.add_frame(anim, at)

	func _physics_process(delta: float) -> void:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and is_instance_valid(player) \
				and global_position.distance_to(player.global_position) <= flee_radius:
			_flee_left = FLEE_HOLD
		_flee_left = maxf(0.0, _flee_left - delta)
		var fleeing: bool = _flee_left > 0.0
		if fleeing and player != null and is_instance_valid(player):
			var away: Vector2 = global_position - player.global_position
			if away.length_squared() < 0.01:
				away = Vector2.from_angle(_rng.randf_range(0.0, TAU))
			_step(global_position + away.normalized() * 40.0, FLEE_SPEED, delta)
			_play_move(true, true)
			return
		# Idle / lazy wander around home.
		if _idle_wait > 0.0:
			_idle_wait -= delta
			_play_move(false, false)
			if _idle_wait <= 0.0:
				_pick_wander()
			return
		if global_position.distance_to(_target) < 3.0:
			_idle_wait = _rng.randf_range(1.2, 3.6)
			_play_move(false, false)
			return
		_step(_target, WANDER_SPEED, delta)
		_play_move(true, false)

	func _step(dest: Vector2, spd: float, delta: float) -> void:
		var to: Vector2 = dest - global_position
		if to.length_squared() < 0.0001:
			return
		var step: Vector2 = to.normalized() * spd * delta
		global_position += step
		if absf(step.x) > 0.01:
			_sprite.flip_h = (step.x < 0.0) != _art_faces_left

	func _pick_wander() -> void:
		var ang: float = _rng.randf_range(0.0, TAU)
		var r: float = sqrt(_rng.randf()) * _wander_radius
		_target = home + Vector2.from_angle(ang) * r

	func _play_move(moving: bool, fleeing: bool) -> void:
		var anim: String
		if _is_bird:
			anim = "fly" if fleeing else "idle"
		else:
			anim = "move" if moving else "idle"
		if not _sprite.sprite_frames.has_animation(anim):
			return
		if _sprite.animation != StringName(anim) or not _sprite.is_playing():
			_sprite.offset = _off
			_sprite.play(anim)
