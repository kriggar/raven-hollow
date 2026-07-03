class_name Combat
## Static combat helpers for Raven Hollow: Emberfall.
##  - deal_damage: routes into a target's take_damage + floating damage number.
##  - spawn_projectile: faction-aware Area2D projectile (group-based hit test
##    within 10 px, frees on wall contact via body_entered on mask 1).
##  - spawn_world_enemies: deterministic skeleton/orc placements outside town
##    plus the training scarecrow (LPC decorations atlas, region verified by
##    pixel inspection: Rect2(320, 130, 32, 62), pole base on the crop bottom).
##  - find_nearest_enemy: nearest living member of group "enemies".

const DMG_ON_ENEMY := Color(0.95, 0.92, 0.85)   # bone-white, player-dealt
const DMG_ON_PLAYER := Color(0.9, 0.28, 0.22)   # red, player was hit
const SCARECROW_POS := Vector2(1650.0, 950.0)

## Deterministic world spawns. Skeletons haunt the graveyard OUTSKIRTS (west
## and north of the fence, off the lane); orcs camp SE beyond the farm.
const ENEMY_SPAWNS: Array[Dictionary] = [
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(140.0, 300.0), "hp": 32.0, "damage": 6.0, "speed": 62.0, "patrol_radius": 55.0},
	{"type": "skeleton_rogue", "display_name": "Skeleton Rogue", "pos": Vector2(125.0, 435.0), "hp": 30.0, "damage": 7.0, "speed": 70.0, "patrol_radius": 65.0},
	{"type": "skeleton_warrior", "display_name": "Skeleton Warrior", "pos": Vector2(185.0, 495.0), "hp": 48.0, "damage": 9.0, "speed": 55.0, "patrol_radius": 45.0},
	{"type": "skeleton_mage", "display_name": "Skeleton Mage", "pos": Vector2(330.0, 165.0), "hp": 34.0, "damage": 8.0, "speed": 58.0, "patrol_radius": 60.0},
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(520.0, 155.0), "hp": 32.0, "damage": 6.0, "speed": 64.0, "patrol_radius": 80.0},
	{"type": "orc", "display_name": "Orc Grunt", "pos": Vector2(1845.0, 1350.0), "hp": 40.0, "damage": 7.0, "speed": 60.0, "patrol_radius": 60.0},
	{"type": "orc_warrior", "display_name": "Orc Warrior", "pos": Vector2(1955.0, 1325.0), "hp": 55.0, "damage": 10.0, "speed": 55.0, "patrol_radius": 40.0},
	{"type": "orc_rogue", "display_name": "Orc Rogue", "pos": Vector2(2040.0, 1430.0), "hp": 35.0, "damage": 8.0, "speed": 70.0, "patrol_radius": 75.0},
	{"type": "orc_shaman", "display_name": "Orc Shaman", "pos": Vector2(1900.0, 1460.0), "hp": 38.0, "damage": 9.0, "speed": 56.0, "patrol_radius": 50.0},
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
			VFX.impact(parent, global_position, color)
		set_physics_process(false)
		queue_free()

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
