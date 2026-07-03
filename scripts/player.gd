class_name Player
extends CharacterBody2D
## Player character for Raven Hollow: Emberfall.
## 8-way movement, szadi-sheet animation per chosen class (ClassDefs),
## nearest-NPC interaction, and 3-slot ability casting (attack/skill_1/skill_2)
## dispatched by ability kind: melee_arc / projectile / aoe_ring / dash /
## summon / buff / volley. Side frames of the szadi sheets face LEFT
## (verified by pixel inspection), so flip_h is enabled when facing right.
## Node position is the FEET line; sprite offset lifts the frame accordingly.
##
## Phase B: owns an Inventory (bag + equipment). Equipped stat totals are
## cached on equipment_changed: flat damage adds to ability damage, armor
## reduces incoming hits (min 1), hp/mana add to the maxima, speed_pct
## multiplies move speed, crit_pct rolls 1.5x crits (bigger gold number).
## A visible weapon Sprite2D (pixel-verified crops from pc_wood.png) rides
## the hand, follows facing (behind the body when facing up), sways at idle
## and brandishes on the cast lunge. Legendary gear adds effect hooks:
## emberfall / rooks_talon / gravekeepers_band / bulwark / bloody_dagger.
##
## Phase B.1 (combat readability): "target" holds the clicked enemy (WoW unit
## frames + nameplates read it), acquired on an attack press near the mouse,
## cleared by Esc / death / range. Holding "sprint" while moving speeds the
## run up (x1.55) and fast-forwards the walk anim — no sprite frame changes.
##
## Phase B.2 (sprite-sheet VFX): abilities carry FXLib ids in params
## ("fx" one-shot / "fx_loop" looping aura / "fx_tint" opts tint — see
## class_defs.gd header). Dispatch plays them at the mapped moments: melee
## smears rotated toward aim, dash vanish/appear puffs or a travel streak,
## AoE zone effects at the zone center (+ a persistent Consecration glyph),
## buff bursts and the Divine Shield wrap (freed when the buff ends), and
## the Raise Dead ritual (rising wisp + summon ellipse under the minion).
## Projectiles pass their flight-visual id through cfg "kind"/"fx" so
## Combat.Projectile -> VFX.projectile_visual builds FXLib flight frames.
## Procedural VFX stay only as garnish (feathers, rings, damage numbers).

const INTERACT_RANGE: float = 28.0
## 32x48 frame, centered=true puts frame center (y=24) at node pos. Pixel
## inspection: lowest opaque row (shadow bottom) is y=40 in every frame, i.e.
## 16 px below center; lift by 15 so the shadow ellipse straddles the node pos.
const FEET_OFFSET: Vector2 = Vector2(0, -15)
const INVULN_TIME: float = 0.5
const RESPAWN_DELAY: float = 2.5
const MELEE_CONE_DEG: float = 50.0  # half-angle of the 100-degree swing cone

const WEAPON_SHEET: String = "res://assets/art/weapons/pc_wood.png"
## Pixel-verified crops from pc_wood.png (contact-sheet inspected with PIL):
## wooden sword blade-up at (3,6 10x41), dagger (35,17 10x28), shepherd-crook
## staff (99,21 11x40), strung bow (52,48 10x32). "grip" = px above the crop
## bottom where the hand holds it — the sprite origin, so rotation pivots at
## the hand. "scale" shrinks the crop to read right against the ~30 px body.
const WEAPON_SHAPES: Dictionary = {
	"sword": {"region": Rect2(3.0, 6.0, 10.0, 41.0), "scale": 0.5, "grip": 5.0},
	"dagger": {"region": Rect2(35.0, 17.0, 10.0, 28.0), "scale": 0.55, "grip": 4.0},
	"staff": {"region": Rect2(99.0, 21.0, 11.0, 40.0), "scale": 0.62, "grip": 16.0},
	"bow": {"region": Rect2(52.0, 48.0, 10.0, 32.0), "scale": 0.6, "grip": 16.0},
}
const TARGET_ACQUIRE_RADIUS: float = 26.0  # attack press: enemy within this of the mouse
const TARGET_BREAK_DIST: float = 400.0     # target auto-clears past this distance
const SPRINT_SPEED_MULT: float = 1.55
const SPRINT_ANIM_SCALE: float = 1.7
const CAST_LOCK_TIME: float = 0.2          # cast lunge window: sprint pauses during it
const CRIT_MULT: float = 1.5
const CRIT_GOLD: Color = Color(1.0, 0.8, 0.3)
const EMBER_ORANGE: Color = Color(0.95, 0.52, 0.16)
const WISP_GREEN: Color = Color(0.45, 0.85, 0.45)
const BULWARK_GOLD: Color = Color(0.85, 0.68, 0.35)
const BULWARK_COOLDOWN: float = 2.0

var class_def: Dictionary = {}
var hp: float = 30.0
var max_hp: float = 30.0
var mana: float = 20.0
var max_mana: float = 20.0
var speed: float = 90.0
## Current hostile target (enemy Node2D or null). HUD unit frames and enemy
## nameplates poll this. Set by an "attack" press near an alive enemy; cleared
## by Esc (no UI open), the target dying, or exceeding TARGET_BREAK_DIST.
var target: Node2D = null

var _hp_regen: float = 0.0
var _mana_regen: float = 0.0
var _sprite: AnimatedSprite2D
var _facing: String = "down"
var _facing_vec: Vector2 = Vector2.DOWN
var _prompt_shown: bool = false
var _spawn_point: Vector2 = Vector2.ZERO
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _cd_max: Array[float] = [1.0, 1.0, 1.0]
var _invuln: float = 0.0
var _dead: bool = false
var _speed_mult: float = 1.0
var _damage_mult: float = 1.0
var _absorb: float = 0.0
var _buff_left: float = 0.0
var _buff_fx: Node2D = null  # FXLib looping aura (Divine Shield), freed with the buff
var _next_hit_bonus: float = 0.0
var _bonus_left: float = 0.0  # seconds until _next_hit_bonus expires unused
var _aim_dist: float = 60.0   # distance to the aim point (mouse), for placed AoEs
var _cast_anim_left: float = 0.0   # cast-lunge window: sprint pauses while > 0
var _ui_open_snapshot: bool = false  # "was a UI panel open?" from the last physics tick
var _feedback_tween: Tween
var _flash_tween: Tween

var inventory: Inventory = null
var _totals: Dictionary = {}          # cached Inventory.stat_totals()
var _base_max_hp: float = 30.0
var _base_max_mana: float = 20.0
var _base_speed: float = 90.0
var _base_mana_regen: float = 0.0
var _weapon: Sprite2D                 # child of _sprite: rides the cast lunge + red flash + death fade
var _chest_fx: CPUParticles2D         # legendary-chest gold glints (null when none)
var _weapon_tween: Tween
var _sway_t: float = 0.0
var _brandish_left: float = 0.0       # while > 0, the brandish tween owns weapon rotation
var _bulwark_cd: float = 0.0

static var _pixel_tex: Texture2D = null


static func create(spawn: Vector2, class_id: String) -> Player:
	var p := Player.new()
	p.name = "Player"
	p.position = spawn
	p._spawn_point = spawn
	p.collision_layer = 2
	p.collision_mask = 1
	p.y_sort_enabled = true
	# Top-down game: floating mode avoids grounded-mode floor/slope logic.
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	p.add_to_group("player")

	var def: Dictionary = ClassDefs.get_def(class_id)
	p.class_def = def
	p.max_hp = float(def.get("max_hp", 30.0))
	p.hp = p.max_hp
	p.max_mana = float(def.get("max_mana", 20.0))
	p.mana = p.max_mana
	p.speed = float(def.get("speed", 90.0))
	p._hp_regen = float(def.get("hp_regen", 0.0))
	p._mana_regen = float(def.get("mana_regen", 0.0))
	# Gear bonuses stack on top of these class baselines (_apply_equipment).
	p._base_max_hp = p.max_hp
	p._base_max_mana = p.max_mana
	p._base_speed = p.speed
	p._base_mana_regen = p._mana_regen

	var sheet: String = str(def.get("sheet", "res://assets/art/characters/npc_male1.png"))
	if not sheet.begins_with("res://"):
		sheet = "res://assets/art/characters/npc_%s.png" % sheet
	var variant: int = int(def.get("variant", 0))

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = SheetAnim.make_szadi_frames(sheet, variant)
	sprite.centered = true
	sprite.offset = FEET_OFFSET
	sprite.play("idle_down")
	p.add_child(sprite)
	p._sprite = sprite

	# Visible main-hand weapon. Child of the sprite so it rides the cast
	# lunge nudge, the red hit flash and the death fade for free.
	var weapon := Sprite2D.new()
	weapon.name = "Weapon"
	weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon.visible = false
	sprite.add_child(weapon)
	p._weapon = weapon

	var col := CollisionShape2D.new()
	col.name = "Feet"
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	col.position = Vector2.ZERO
	p.add_child(col)

	p.inventory = Inventory.new()
	p.inventory.equipment_changed.connect(p._on_equipment_changed)
	for item: Dictionary in Items.starting_bag():
		p.inventory.add_item(item)
	p._apply_equipment()

	return p


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_weapon_pose(delta)
	_validate_target()
	# Snapshot for _unhandled_input: bag/sheet close on the same un-consumed
	# Esc without marking it handled, so "is a panel open?" polled at event
	# time is ambiguous — gate the target-clear on the pre-event state.
	_ui_open_snapshot = _ui_panel_open()

	if _dead:
		velocity = Vector2.ZERO
		_sprite.speed_scale = 1.0
		return

	var ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	var dialogue_open: bool = ui != null and ui.get("is_open") == true

	if dialogue_open:
		velocity = Vector2.ZERO
		_sprite.speed_scale = 1.0
		_play_anim("idle")
		_set_prompt(ui, false)
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving: bool = input_dir.length_squared() > 0.0001
	# Sprint: held + moving + outside the brief cast-lunge window. Speeds the
	# run and fast-forwards the walk anim — no sprite frame changes.
	var sprinting: bool = moving and _cast_anim_left <= 0.0 \
			and Input.is_action_pressed("sprint")
	velocity = input_dir * speed * _speed_mult * (SPRINT_SPEED_MULT if sprinting else 1.0)
	move_and_slide()

	if moving:
		_update_facing(input_dir)
		_facing_vec = input_dir.normalized()
	_play_anim("walk" if moving else "idle")
	_sprite.speed_scale = SPRINT_ANIM_SCALE if sprinting else 1.0

	# "attack" is mouse-bound: a click that lifts/drops an item in the bag or
	# character sheet must not also swing the weapon. Control event-consumption
	# never reaches the polled Input singleton, so gate on the mouse being over
	# any Control (HUD/dialogue are MOUSE_FILTER_IGNORE and stay attackable-
	# through) or on a drag being in flight. Keyboard skills stay live.
	var mouse_on_ui: bool = Inventory.DragCtx.item != null \
			or get_viewport().gui_get_hovered_control() != null
	if Input.is_action_just_pressed("attack") and not mouse_on_ui:
		_acquire_target()
		_try_cast(0)
	elif Input.is_action_just_pressed("skill_1"):
		_try_cast(1)
	elif Input.is_action_just_pressed("skill_2"):
		_try_cast(2)

	var npc: Node2D = _nearest_npc()
	_set_prompt(ui, npc != null)
	if npc != null and Input.is_action_just_pressed("interact"):
		_set_prompt(ui, false)
		npc.call("interact", self)


func _tick_timers(delta: float) -> void:
	for i in range(3):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)
	if _buff_left > 0.0:
		_buff_left -= delta
		if _buff_left <= 0.0:
			_buff_left = 0.0
			_speed_mult = 1.0
			_damage_mult = 1.0
			_absorb = 0.0
			_clear_buff_fx()
	if _bonus_left > 0.0:
		_bonus_left -= delta
		if _bonus_left <= 0.0:
			_bonus_left = 0.0
			_next_hit_bonus = 0.0
	if _bulwark_cd > 0.0:
		_bulwark_cd = maxf(0.0, _bulwark_cd - delta)
	if _brandish_left > 0.0:
		_brandish_left = maxf(0.0, _brandish_left - delta)
	if _cast_anim_left > 0.0:
		_cast_anim_left = maxf(0.0, _cast_anim_left - delta)
	if not _dead:
		hp = minf(hp + _hp_regen * delta, max_hp)
		mana = minf(mana + _mana_regen * delta, max_mana)


# --- Targeting (HUD unit frames + enemy nameplates read player.target) -------


func _acquire_target() -> void:
	## Attack press: the closest alive "enemies" node within
	## TARGET_ACQUIRE_RADIUS px of the mouse WORLD position becomes the
	## target. A press over empty ground keeps the current target.
	var mouse: Vector2 = get_global_mouse_position()
	var best: Node2D = null
	var best_d: float = TARGET_ACQUIRE_RADIUS
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = e.global_position.distance_to(mouse)
		if d <= best_d:
			best_d = d
			best = e
	if best != null:
		target = best


func _validate_target() -> void:
	## Auto-clear: freed node, death, or beyond TARGET_BREAK_DIST.
	if target == null:
		return
	if not is_instance_valid(target) or target.get("is_dead") == true \
			or global_position.distance_to(target.global_position) > TARGET_BREAK_DIST:
		target = null


func _ui_panel_open() -> bool:
	for grp: String in ["bag_ui", "sheet_ui", "dialogue_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and n.get("is_open") == true:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Esc clears the target only when no UI panel was open before this event
	# (the open panels close themselves on the very same un-consumed Esc).
	if event.is_action_pressed("ui_cancel") and target != null and not _ui_open_snapshot:
		target = null


# --- Ability casting -------------------------------------------------------


func cooldown_frac(i: int) -> float:
	if i < 0 or i > 2 or _cd_max[i] <= 0.0:
		return 0.0
	return clampf(_cooldowns[i] / _cd_max[i], 0.0, 1.0)


func debug_cast(action_name: String, aim_dir: Vector2) -> void:
	## Force-cast for headless automation: ignores mana and cooldown gates.
	var idx: int = {"attack": 0, "skill_1": 1, "skill_2": 2}.get(action_name, -1)
	if idx < 0 or _dead:
		return
	var ability: Dictionary = _ability(idx)
	if ability.is_empty():
		return
	var aim: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else _facing_vec
	# No mouse in headless runs: aim placed AoEs at the nearest enemy instead.
	var foe: Node2D = Combat.find_nearest_enemy(global_position, 400.0)
	_aim_dist = global_position.distance_to(foe.global_position) if foe != null else 60.0
	_start_cooldown(idx, ability)
	_execute(ability, aim)


func _ability(i: int) -> Dictionary:
	var abilities: Array = class_def.get("abilities", [])
	if i < 0 or i >= abilities.size():
		return {}
	return abilities[i]


func _try_cast(i: int) -> void:
	var ability: Dictionary = _ability(i)
	if ability.is_empty() or _cooldowns[i] > 0.0:
		return
	var cost: float = float(ability.get("mana_cost", 0.0))
	if mana < cost:
		return
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var aim: Vector2 = to_mouse.normalized() if to_mouse.length_squared() > 0.25 else _facing_vec
	_aim_dist = to_mouse.length()
	mana -= cost
	_start_cooldown(i, ability)
	_execute(ability, aim)


func _start_cooldown(i: int, ability: Dictionary) -> void:
	_cd_max[i] = maxf(0.05, float(ability.get("cooldown", 1.0)))
	_cooldowns[i] = _cd_max[i]


func _execute(ability: Dictionary, aim: Vector2) -> void:
	_update_facing(aim)
	_facing_vec = aim
	_cast_anim_left = CAST_LOCK_TIME  # sprint pauses during the cast lunge
	var world: Node2D = get_parent() as Node2D
	if world == null:
		world = self
	var kind: String = str(ability.get("kind", ""))
	match kind:
		"melee_arc":
			_cast_feedback(aim * 8.0)
			_do_melee_arc(ability, aim, world)
		"projectile":
			_cast_feedback(-aim * 3.0)
			_do_projectile(ability, aim, world)
		"aoe_ring":
			_do_aoe_ring(ability, aim, world)
		"dash":
			_do_dash(ability, aim, world)
		"summon":
			_do_summon(ability, aim, world)
		"buff":
			_do_buff(ability, world)
		"volley":
			_cast_feedback(-aim * 3.0)
			_do_volley(ability, aim, world)


func _cast_feedback(sprite_nudge: Vector2) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_sprite.position = sprite_nudge
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12)
	_brandish_weapon()


func _brandish_weapon() -> void:
	## Quick over-the-shoulder swing on the cast lunge; while _brandish_left
	## runs, _update_weapon_pose leaves rotation to this tween.
	if _weapon == null or not _weapon.visible:
		return
	_brandish_left = 0.2
	if _weapon_tween != null and _weapon_tween.is_valid():
		_weapon_tween.kill()
	var rot_sign: float = -1.0 if _weapon.flip_h else 1.0
	_weapon.rotation = rot_sign * -0.5
	_weapon_tween = create_tween()
	_weapon_tween.tween_property(_weapon, "rotation", rot_sign * 1.5, 0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(_weapon, "rotation", rot_sign * 0.42, 0.1)


func _class_color() -> Color:
	return class_def.get("color", Color(0.85, 0.68, 0.35))


func _fx_opts(params: Dictionary, extra: Dictionary = {}) -> Dictionary:
	## FXLib.play opts from ability params: fx_tint rides opts.tint when the
	## mapping wants a re-tint; `extra` (rotation/scale/...) merges on top.
	var opts: Dictionary = {}
	if params.has("fx_tint"):
		opts["tint"] = params.get("fx_tint")
	opts.merge(extra, true)
	return opts


func _clear_buff_fx() -> void:
	## Frees the looping FXLib buff aura (Divine Shield wrap), if any.
	if _buff_fx != null and is_instance_valid(_buff_fx):
		_buff_fx.queue_free()
	_buff_fx = null


func _do_melee_arc(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	var rng: float = float(ability.get("range", 26.0))
	var half_arc: float = float(params.get("arc_degrees", MELEE_CONE_DEG * 2.0)) * 0.5
	var fx_id: String = str(params.get("fx", ""))
	if fx_id.is_empty():
		VFX.slash_arc(world, global_position + aim * 10.0, aim, _class_color(), rng)
	else:
		# Sheet-based swing: smear rotated toward aim (cleave / quick_slash,
		# tinted via fx_tint) or the hammer spark + dust + holy flash, played
		# at the middle of the swing reach.
		FXLib.play(fx_id, world, global_position + aim * (rng * 0.55),
				_fx_opts(params, {"rotation": aim.angle()}))
	var dmg: float = (float(ability.get("damage", 5.0)) + _stat_damage()) * _damage_mult
	if _next_hit_bonus > 0.0:
		dmg *= _next_hit_bonus
	var emberfall: bool = _slot_effect(["main_hand"], "emberfall")
	var hit_any: bool = false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or e.get("is_dead") == true:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > rng + 8.0:
			continue
		if absf(rad_to_deg(aim.angle_to(to))) > half_arc:
			continue
		_deal_player_damage(e, dmg)
		if emberfall:
			VFX.impact(world, e.global_position, EMBER_ORANGE, 0.8)
		hit_any = true
	if hit_any and _next_hit_bonus > 0.0:
		_next_hit_bonus = 0.0
		_bonus_left = 0.0


func _do_projectile(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	var cfg: Dictionary = {
		"pos": global_position + aim * 8.0,
		"dir": aim,
		"speed": float(params.get("speed", 220.0)),
		"range": float(ability.get("range", 140.0)),
		"faction": "player",
		"color": params.get("color", _class_color()),
		"kind": str(params.get("projectile", "orb")),
		"fx": str(params.get("fx", params.get("projectile", "orb"))),
		"aoe_radius": float(params.get("aoe_radius", 0.0)),
	}
	_arm_ranged(cfg, (float(ability.get("damage", 6.0)) + _stat_damage()) * _damage_mult)
	Combat.spawn_projectile(world, cfg)


func _do_aoe_ring(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	# ability "range" is the ring RADIUS; cast_range is the max placement dist.
	var radius: float = float(params.get("radius", ability.get("range", 40.0)))
	var tick_interval: float = float(params.get("tick_interval", 0.0))
	var zone_duration: float = float(params.get("duration", 0.0))
	var ticking: bool = tick_interval > 0.0 and zone_duration > 0.0
	var center: Vector2 = global_position
	if params.get("at_aim", false):
		var cast_range: float = float(params.get("cast_range", float(ability.get("range", 60.0))))
		center = global_position + aim * minf(_aim_dist, cast_range)
		VFX.ground_circle(world, center, radius, _class_color(),
				zone_duration if ticking else 0.45)
	VFX.ring(world, center, radius, _class_color(), 0.5)
	var fx_id: String = str(params.get("fx", ""))
	if not fx_id.is_empty():
		# Sheet-based zone effect at the center: frost bloom (frost_nova),
		# shred swirl (whirlwind), holy pillar burst (consecration) or
		# grasping roots (grave_grasp, tinted grave-purple via fx_tint).
		FXLib.play(fx_id, world, center, _fx_opts(params))
	var dmg: float = (float(ability.get("damage", 5.0)) + _stat_damage()) * _damage_mult
	_aoe_pulse(center, radius, dmg, params)
	if not ticking:
		return
	# Persistent sheet glyph (Consecration): looping FXLib aura on a ground
	# holder that fades away with the zone. Freeing the holder frees the loop.
	var loop_id: String = str(params.get("fx_loop", ""))
	if not loop_id.is_empty():
		var holder := Node2D.new()
		holder.position = center
		holder.z_index = -1
		world.add_child(holder)
		FXLib.attach_loop(loop_id, holder)
		var ht := holder.create_tween()
		ht.tween_interval(maxf(zone_duration - 0.25, 0.1))
		ht.tween_property(holder, "modulate:a", 0.0, 0.25)
		ht.tween_callback(holder.queue_free)
	# Ticking zone (Consecration): re-pulse every tick_interval for duration.
	var ticks: int = int(floor(zone_duration / tick_interval + 0.001))
	for k in range(1, ticks):
		var timer := get_tree().create_timer(tick_interval * float(k))
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(world) or not world.is_inside_tree():
				return
			_aoe_pulse(center, radius, dmg, params)
		)


func _aoe_pulse(center: Vector2, radius: float, dmg: float, params: Dictionary) -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or e.get("is_dead") == true:
			continue
		if e.global_position.distance_to(center) > radius + 6.0:
			continue
		_deal_player_damage(e, dmg)
		# Crowd control — the training scarecrow has no CC methods, so guard.
		if params.has("slow_mult") and e.has_method("apply_slow"):
			e.call("apply_slow", float(params.get("slow_mult", 0.5)),
					float(params.get("slow_duration", 2.0)))
		if params.has("root_duration") and e.has_method("apply_root"):
			e.call("apply_root", float(params.get("root_duration", 1.5)))


func _do_dash(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	# Contract: ability "range" IS the dash distance in px.
	var dist: float = float(ability.get("range", 75.0))
	var feathered: bool = bool(params.get("feathers", false))
	var fx_id: String = str(params.get("fx", ""))
	var start: Vector2 = global_position
	# Vanish marker at the launch point. Shadowstep swaps the procedural puff
	# for the FXLib smoke-and-dust puff (near-black via fx_tint); Raven Dash
	# keeps its procedural feathers (garnish stays) and adds a streak below.
	if feathered:
		VFX.feathers(world, global_position)
	elif not fx_id.is_empty():
		FXLib.play(fx_id, world, global_position, _fx_opts(params))
	else:
		VFX.smoke(world, global_position)
	# move_and_collide sweeps the full motion and stops at the first wall,
	# so the dash can never clip inside colliders.
	move_and_collide(aim * dist)
	if feathered:
		VFX.feathers(world, global_position)
		if not fx_id.is_empty():
			# Raven Dash: smoke streak swept along the travelled path.
			FXLib.play(fx_id, world, start.lerp(global_position, 0.5),
					_fx_opts(params, {"rotation": aim.angle()}))
	elif not fx_id.is_empty():
		FXLib.play(fx_id, world, global_position, _fx_opts(params))
	else:
		VFX.smoke(world, global_position)
	# Rook's Talon: the dash leaves a feather trail along the travelled path.
	if _slot_effect(["main_hand"], "talon"):
		for k in range(1, 4):
			VFX.feathers(world, start.lerp(global_position, float(k) / 4.0))
	if params.has("next_hit_mult") or str(ability.get("id", "")) == "shadowstep":
		_next_hit_bonus = float(params.get("next_hit_mult", 1.5))
		_bonus_left = float(params.get("bonus_duration", 3.0))


func _do_buff(ability: Dictionary, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	_buff_left = float(params.get("duration", 6.0))
	_speed_mult = float(params.get("speed_mult", 1.0))
	_damage_mult = float(params.get("damage_mult", 1.0))
	_absorb = float(params.get("absorb", 0.0))
	var fx_id: String = str(params.get("fx", ""))
	if not fx_id.is_empty():
		# War Cry: one-shot radial air burst around the caster (red-gold tint).
		FXLib.play(fx_id, world, global_position, _fx_opts(params))
	_clear_buff_fx()
	var loop_id: String = str(params.get("fx_loop", ""))
	if not loop_id.is_empty():
		# Divine Shield: looping holy wrap riding the body for the buff's
		# lifetime — freed by _tick_timers on expiry / when the absorb pops.
		_buff_fx = FXLib.attach_loop(loop_id, self, Vector2(0.0, -12.0))
	# Procedural orbit glints stay as garnish (duration readability).
	VFX.sparkle_buff(world, self, _class_color(), _buff_left)


func _do_volley(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	var count: int = int(params.get("count", 8))
	var dmg: float = (float(ability.get("damage", 4.0)) + _stat_damage()) * _damage_mult
	var kind: String = str(params.get("projectile", "knife"))
	var color: Color = params.get("color", _class_color())
	var pattern: String = str(params.get("pattern", ""))
	if pattern.is_empty():
		pattern = "rain" if str(ability.get("id", "")) == "arrow_storm" else "radial"
	if pattern == "radial":
		for k in range(count):
			var dir: Vector2 = aim.rotated(TAU * float(k) / float(count))
			var cfg: Dictionary = {
				"pos": global_position + dir * 8.0,
				"dir": dir,
				"speed": float(params.get("speed", 200.0)),
				"range": float(ability.get("range", 70.0)),
				"faction": "player",
				"color": color,
				"kind": kind,
				"fx": str(params.get("fx", kind)),
			}
			_arm_ranged(cfg, dmg)
			Combat.spawn_projectile(world, cfg)
		return
	# "rain": staggered mini-projectiles falling onto random points around aim,
	# spread across params.duration seconds (also the telegraph's lifetime).
	var center: Vector2 = global_position + aim * float(ability.get("range", 100.0))
	var radius: float = float(params.get("radius", 36.0))
	var spread_time: float = maxf(0.2, float(params.get("duration", 1.0)))
	VFX.ground_circle(world, center, radius, color, spread_time)
	for k in range(count):
		var timer := get_tree().create_timer(0.05 + spread_time * float(k) / float(count))
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(world) or not world.is_inside_tree():
				return
			var point: Vector2 = center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
			var cfg: Dictionary = {
				"pos": point + Vector2(0.0, -90.0),
				"dir": Vector2.DOWN,
				"speed": float(params.get("speed", 320.0)),
				"range": 90.0,
				"faction": "player",
				"color": color,
				"kind": kind,
				"fx": str(params.get("fx", kind)),
			}
			_arm_ranged(cfg, dmg)
			Combat.spawn_projectile(world, cfg)
		)


# --- Summon: friendly skeleton minion (built inline, not an Enemy) ---------


func _do_summon(ability: Dictionary, aim: Vector2, world: Node2D) -> void:
	var params: Dictionary = ability.get("params", {})
	var minion := Minion.new()
	minion.owner_player = self
	minion.damage = float(params.get("minion_damage", float(ability.get("damage", 5.0)))) + _stat_damage()
	minion.life_left = float(params.get("lifetime", 12.0))
	minion.hp = float(params.get("minion_hp", 35.0))
	minion.move_speed = float(params.get("minion_speed", 80.0))
	minion.position = global_position + aim * 20.0
	world.add_child(minion)
	var fx_id: String = str(params.get("fx", ""))
	if not fx_id.is_empty():
		# Raise Dead ritual: rising dark wisp over the grave-spot (one-shot).
		FXLib.play(fx_id, world, minion.position, _fx_opts(params))
	var loop_id: String = str(params.get("fx_loop", ""))
	if not loop_id.is_empty():
		# Looping summon ellipse under the minion for the ritual moment,
		# then a short fade — the loop node is ours to free.
		var ellipse: Node2D = FXLib.attach_loop(loop_id, minion)
		if ellipse != null:
			ellipse.z_index = -1
			var et := ellipse.create_tween()
			et.tween_interval(1.4)
			et.tween_property(ellipse, "modulate:a", 0.0, 0.3)
			et.tween_callback(ellipse.queue_free)
	# Smoke poof garnish on the spawn.
	VFX.smoke(world, minion.position)


class Minion extends CharacterBody2D:
	## Friendly summoned skeleton: follows its owner at ~60 px, melee-hits the
	## nearest enemy within 90 px every 0.8 s, despawns when its time is up.
	## Skeleton sheets face RIGHT (verified); idle 4x32x32 / run 6x64x64, feet
	## at the frame bottom — idle frames are margin-padded to 64x64 to match.
	var owner_player: Node2D
	var damage: float = 5.0
	var life_left: float = 12.0
	var hp: float = 35.0
	var move_speed: float = 80.0
	var _atk_cd: float = 0.0
	var _spr: AnimatedSprite2D

	func _init() -> void:
		name = "SkeletonMinion"
		collision_layer = 0
		collision_mask = 1
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		y_sort_enabled = true
		add_to_group("minions")
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = _build_frames()
		_spr.centered = true
		_spr.offset = Vector2(0, -31)  # 64px frames, feet at frame bottom
		_spr.modulate = Color(0.82, 0.92, 0.85)  # faint necrotic tint
		_spr.play("idle")
		add_child(_spr)
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5.0
		col.shape = circle
		add_child(col)

	func take_damage(amount: float, _source: Node) -> void:
		hp -= amount
		if hp <= 0.0:
			life_left = 0.0  # next physics tick despawns it with a smoke puff

	func _build_frames() -> SpriteFrames:
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		var run_tex: Texture2D = load("res://assets/art/enemies/skeleton_run.png")
		sf.add_animation("run")
		sf.set_animation_speed("run", 10.0)
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = run_tex
			at.region = Rect2(Vector2(float(i * 64), 0.0), Vector2(64.0, 64.0))
			sf.add_frame("run", at)
		var idle_tex: Texture2D = load("res://assets/art/enemies/skeleton_idle.png")
		sf.add_animation("idle")
		sf.set_animation_speed("idle", 5.0)
		for i in range(4):
			var at := AtlasTexture.new()
			at.atlas = idle_tex
			at.region = Rect2(Vector2(float(i * 32), 0.0), Vector2(32.0, 32.0))
			at.margin = Rect2(Vector2(16.0, 32.0), Vector2(32.0, 32.0))  # pad to 64x64, feet aligned
			sf.add_frame("idle", at)
		return sf

	func _physics_process(delta: float) -> void:
		life_left -= delta
		if life_left <= 0.0 or owner_player == null or not is_instance_valid(owner_player):
			var w := get_parent()
			if w != null:
				VFX.smoke(w, global_position)
			queue_free()
			return
		_atk_cd = maxf(0.0, _atk_cd - delta)
		var foe: Node2D = Combat.find_nearest_enemy(global_position, 90.0)
		if foe != null and _atk_cd <= 0.0:
			_atk_cd = 0.8
			Combat.deal_damage(foe, damage, owner_player)
			VFX.impact(get_parent(), foe.global_position, Color(0.72, 0.85, 0.7), 0.7)
			_spr.flip_h = foe.global_position.x < global_position.x
			# Minion kills count for the owner's on-kill gear effects too.
			if owner_player.has_method("_check_kill_effects"):
				owner_player.call("_check_kill_effects", foe)
		var to_owner: Vector2 = owner_player.global_position - global_position
		if foe != null and global_position.distance_to(foe.global_position) > 24.0:
			velocity = (foe.global_position - global_position).normalized() * move_speed
		elif foe == null and to_owner.length() > 60.0:
			velocity = to_owner.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		if velocity.length_squared() > 1.0:
			if _spr.animation != &"run":
				_spr.play("run")
			if absf(velocity.x) > 0.1:
				_spr.flip_h = velocity.x < 0.0
		elif _spr.animation != &"idle":
			_spr.play("idle")


# --- Damage / death ---------------------------------------------------------


func take_damage(amount: float, _source: Node) -> void:
	if _dead or _invuln > 0.0:
		return
	var amt: float = amount
	# Equipped armor soaks a flat amount, but a landed hit always stings for 1.
	var armor: float = float(_totals.get("armor", 0.0))
	if armor > 0.0:
		amt = maxf(1.0, amt - armor)
	# Bulwark of the Emberfall Road: gold pulse when struck, 2 s cooldown.
	if _bulwark_cd <= 0.0 and _slot_effect(["off_hand"], "bulwark"):
		_bulwark_cd = BULWARK_COOLDOWN
		VFX.ring(get_parent(), global_position, 16.0, BULWARK_GOLD, 0.45)
	if _absorb > 0.0:
		var soaked: float = minf(_absorb, amt)
		_absorb -= soaked
		amt -= soaked
		if _absorb <= 0.0:
			_clear_buff_fx()  # Divine Shield wrap pops when the absorb is spent
	_invuln = INVULN_TIME
	_flash_red()
	_shake_camera()
	if amt <= 0.0:
		return
	hp -= amt
	if hp <= 0.0:
		hp = 0.0
		_die()


func _flash_red() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(1.0, 0.4, 0.4)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func _shake_camera() -> void:
	var cam := get_node_or_null("PlayerCamera") as Camera2D
	if cam == null:
		return
	var tw := create_tween()
	for i in range(3):
		var jolt := Vector2(randf_range(-2.5, 2.5), randf_range(-2.0, 2.0))
		tw.tween_property(cam, "offset", jolt, 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	_clear_buff_fx()
	_play_anim("idle")
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var feet := get_node_or_null("Feet")
	if feet != null:
		feet.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.6)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	global_position = _spawn_point
	hp = max_hp
	mana = max_mana
	_dead = false
	_invuln = 1.0
	_next_hit_bonus = 0.0
	_bonus_left = 0.0
	_buff_left = 0.0
	_speed_mult = 1.0
	_damage_mult = 1.0
	_absorb = 0.0
	_clear_buff_fx()
	var feet := get_node_or_null("Feet")
	if feet != null:
		feet.set_deferred("disabled", false)
	_sprite.modulate = Color.WHITE
	var world := get_parent()
	if world != null:
		VFX.smoke(world, global_position)


# --- Equipment: stats, crits, legendary effect hooks ------------------------


func _on_equipment_changed() -> void:
	_apply_equipment()


func _apply_equipment() -> void:
	## Cache equipped stat totals and re-derive every gear-driven value:
	## hp/mana add to the class maxima, speed_pct multiplies move speed,
	## damage/armor/crit_pct are read from _totals at hit time.
	_totals = inventory.stat_totals() if inventory != null else {}
	max_hp = _base_max_hp + float(_totals.get("hp", 0.0))
	hp = minf(hp, max_hp)
	max_mana = _base_max_mana + float(_totals.get("mana", 0.0))
	mana = minf(mana, max_mana)
	speed = _base_speed * (1.0 + float(_totals.get("speed_pct", 0.0)) / 100.0)
	_mana_regen = _base_mana_regen + float(_totals.get("mana_regen", 0.0))
	_refresh_weapon()
	_refresh_chest_tint()


func _stat_damage() -> float:
	return float(_totals.get("damage", 0.0))


func _slot_effect(slots: Array, key: String) -> bool:
	## True when an item in any of the given equip slots carries the effect —
	## matched against both the effect id and the item id, scoped per slot so
	## e.g. the "emberfall" in the Bulwark's id can never false-positive the
	## main-hand fire-impact hook.
	if inventory == null:
		return false
	for s: Variant in slots:
		var it: Variant = inventory.equipped.get(str(s))
		if it is Dictionary:
			var tags: String = (str(it.get("effect", "")) + " " + str(it.get("id", ""))).to_lower()
			if key in tags:
				return true
	return false


func _deal_player_damage(foe: Node2D, dmg: float) -> void:
	## Ability-hit funnel: rolls crit_pct% for a 1.5x crit (bigger gold
	## number replaces the standard white one), then runs on-kill hooks.
	if foe == null or not is_instance_valid(foe):
		return
	var final: float = dmg
	var crit: bool = randf() * 100.0 < float(_totals.get("crit_pct", 0.0))
	if crit:
		final *= CRIT_MULT
	if crit and not foe.has_meta("own_damage_numbers") and foe.has_method("take_damage"):
		# Route damage directly so Combat's white number is skipped, then
		# show the bigger gold crit number ourselves.
		foe.call("take_damage", final, self)
		_crit_number(foe, final)
	else:
		Combat.deal_damage(foe, final, self)
	_check_kill_effects(foe)


func _arm_ranged(cfg: Dictionary, dmg: float) -> void:
	## Projectile hits resolve later inside Combat.Projectile (not our code),
	## so the crit is pre-rolled into the payload at cast time. "crit" +
	## "on_hit" ride the cfg (opt-in fields Combat.Projectile reads) so the
	## gold crit number and the on-kill legendary hooks fire for ranged
	## classes exactly like they do on the melee/AoE path.
	var crit: bool = randf() * 100.0 < float(_totals.get("crit_pct", 0.0))
	cfg["damage"] = dmg * (CRIT_MULT if crit else 1.0)
	cfg["crit"] = crit
	cfg["on_hit"] = _on_projectile_hit


func _on_projectile_hit(foe: Node2D, amount: float, crit_styled: bool) -> void:
	## Called by Combat.Projectile after its damage lands. crit_styled means
	## the projectile suppressed the standard white number for us to replace.
	if foe == null or not is_instance_valid(foe):
		return
	if crit_styled:
		_crit_number(foe, amount)
	_check_kill_effects(foe)


func _check_kill_effects(victim: Node2D) -> void:
	## Gravekeeper's Band: a kill releases a brief green soul wisp. Shared
	## on-kill funnel for melee/AoE, projectile/volley and minion damage.
	if victim == null or not is_instance_valid(victim):
		return
	if victim.get("is_dead") == true and _slot_effect(["ring1", "ring2"], "gravekeeper"):
		_soul_wisp(victim.global_position)


func _crit_number(foe: Node2D, amount: float) -> void:
	var world: Node = foe.get_parent()
	if world == null:
		return
	var label := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/alagard.ttf")
	ls.font_size = 14
	ls.font_color = CRIT_GOLD
	ls.outline_size = 4
	ls.outline_color = Color(0.12, 0.07, 0.03, 0.95)
	label.label_settings = ls
	label.text = "%d!" % int(round(amount))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(48.0, 16.0)
	label.pivot_offset = Vector2(24.0, 8.0)
	label.position = foe.global_position + Vector2(-24.0, -46.0)
	label.scale = Vector2.ONE * 0.6
	world.add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "scale", Vector2.ONE * 1.25, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 20.0, 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.4)
	t.chain().tween_callback(label.queue_free)


func _soul_wisp(pos: Vector2) -> void:
	## Gravekeeper's Band on-kill visual: a soft green mote drifting upward.
	var world: Node = get_parent()
	if world == null:
		return
	var root := Node2D.new()
	root.position = pos + Vector2(0.0, -10.0)
	world.add_child(root)
	var halo := Sprite2D.new()
	halo.texture = VFX.radial_tex(16)
	halo.modulate = Color(WISP_GREEN.r, WISP_GREEN.g, WISP_GREEN.b, 0.5)
	root.add_child(halo)
	var core := Sprite2D.new()
	core.texture = VFX.radial_tex(8, true)
	core.modulate = WISP_GREEN.lightened(0.35)
	core.scale = Vector2.ONE * 0.8
	root.add_child(core)
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(root, "position:y", root.position.y - 26.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "position:x", root.position.x + randf_range(-6.0, 6.0), 0.9)
	t.tween_property(root, "modulate:a", 0.0, 0.35).set_delay(0.55)
	t.chain().tween_callback(root.queue_free)


# --- Equipment: visible weapon + chest tint ---------------------------------


func _refresh_weapon() -> void:
	if _weapon == null:
		return
	for child: Node in _weapon.get_children():
		child.queue_free()  # old drips / glints
	var item: Variant = inventory.equipped.get("main_hand") if inventory != null else null
	if not (item is Dictionary):
		_weapon.visible = false
		return
	var cfg: Dictionary = WEAPON_SHAPES[_weapon_shape_for(item)]
	var reg: Rect2 = cfg["region"]
	var at := AtlasTexture.new()
	at.atlas = load(WEAPON_SHEET)
	at.region = reg
	_weapon.texture = at
	# Origin at the grip so rotation (sway / brandish) pivots at the hand.
	_weapon.centered = false
	_weapon.offset = Vector2(-reg.size.x * 0.5, -(reg.size.y - float(cfg["grip"])))
	_weapon.scale = Vector2.ONE * float(cfg["scale"])
	_weapon.visible = true
	if str(item.get("rarity", "")) == "legendary":
		_weapon.add_child(_make_gold_glints(Vector2(0.0, -18.0)))
	if _slot_effect(["main_hand"], "bloody"):
		_weapon.add_child(_make_blood_drip())
	_update_weapon_pose(0.0)


func _weapon_shape_for(item: Dictionary) -> String:
	var key: String = (str(item.get("id", "")) + " " + str(item.get("name", ""))).to_lower()
	if "bow" in key or "talon" in key:
		return "bow"
	if "staff" in key or "wand" in key or "rod" in key or "scepter" in key or "crook" in key:
		return "staff"
	if "dagger" in key or "knife" in key or "shiv" in key or "dirk" in key:
		return "dagger"
	return "sword"


func _update_weapon_pose(delta: float) -> void:
	## Per-frame hand placement: behind the body when facing up, in front
	## when facing down, hand-side when sideways; gentle idle sway unless a
	## brandish tween owns the rotation.
	if _weapon == null or not _weapon.visible:
		return
	_sway_t += delta
	var pos := Vector2(5.0, -10.0)
	var rot_sign: float = 1.0
	match _facing:
		"up":
			pos = Vector2(-5.0, -12.0)
			rot_sign = -1.0
		"down":
			pos = Vector2(5.0, -10.0)
			rot_sign = 1.0
		"side":
			# Side frames face LEFT; _sprite.flip_h true = facing right.
			if _sprite.flip_h:
				pos = Vector2(6.0, -11.0)
				rot_sign = 1.0
			else:
				pos = Vector2(-6.0, -11.0)
				rot_sign = -1.0
	_weapon.show_behind_parent = _facing == "up"
	_weapon.position = pos
	_weapon.flip_h = rot_sign < 0.0
	if _brandish_left <= 0.0:
		_weapon.rotation = rot_sign * (0.42 + sin(_sway_t * 2.4) * 0.06)


func _refresh_chest_tint() -> void:
	## Subtle sprite tint per equipped chest piece: leather = warm brown,
	## iron/mail = cool desaturate, legendary = faint gold + slow glints.
	## Rides self_modulate so the red hit-flash (modulate) still works.
	if _chest_fx != null and is_instance_valid(_chest_fx):
		_chest_fx.queue_free()
	_chest_fx = null
	var it: Variant = inventory.equipped.get("chest") if inventory != null else null
	var tint := Color.WHITE
	if it is Dictionary:
		var key: String = (str(it.get("id", "")) + " " + str(it.get("name", ""))).to_lower()
		if str(it.get("rarity", "")) == "legendary":
			tint = Color(1.0, 0.95, 0.8)
			_chest_fx = _make_gold_glints(Vector2(0.0, -16.0))
			_sprite.add_child(_chest_fx)
		elif "iron" in key or "steel" in key or "plate" in key or "chain" in key or "mail" in key:
			tint = Color(0.88, 0.92, 1.0)
		else:
			tint = Color(1.0, 0.93, 0.85)
	_sprite.self_modulate = tint


func _make_gold_glints(at_pos: Vector2) -> CPUParticles2D:
	## Low-rate legendary sparkle (VFX.sparkle_buff style, but looping and
	## far subtler): two soft gold motes drifting off the item.
	var p := CPUParticles2D.new()
	p.name = "LegendaryGlints"
	p.amount = 2
	p.lifetime = 0.7
	p.local_coords = false
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.8
	p.texture = VFX.radial_tex(8, true)
	p.color = Color(1.0, 0.85, 0.45, 0.8)
	p.position = at_pos
	return p


func _make_blood_drip() -> CPUParticles2D:
	## The Bloody Dagger: slow red drips falling from the blade.
	var p := CPUParticles2D.new()
	p.name = "BloodDrip"
	p.amount = 3
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector2(0.0, 1.0)
	p.spread = 10.0
	p.gravity = Vector2(0.0, 70.0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.texture = _pixel_square()
	p.color = Color(0.5, 0.06, 0.06, 0.85)
	p.position = Vector2(0.0, -14.0)
	return p


static func _pixel_square() -> Texture2D:
	if _pixel_tex == null:
		var img := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pixel_tex = ImageTexture.create_from_image(img)
	return _pixel_tex


# --- Movement / interaction helpers ----------------------------------------


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) >= absf(dir.y):
		_facing = "side"
		# Side frames face LEFT, so mirror when heading right.
		_sprite.flip_h = dir.x > 0.0
	else:
		_facing = "down" if dir.y > 0.0 else "up"


func _play_anim(prefix: String) -> void:
	var anim: String = prefix + "_" + _facing
	if _sprite.animation != StringName(anim) or not _sprite.is_playing():
		_sprite.play(anim)


func _nearest_npc() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INTERACT_RANGE
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Node2D
		if npc == null:
			continue
		var dist: float = global_position.distance_to(npc.global_position)
		if dist <= best_dist:
			best = npc
			best_dist = dist
	return best


func _set_prompt(ui: Node, visible_now: bool) -> void:
	if ui == null or visible_now == _prompt_shown:
		return
	_prompt_shown = visible_now
	ui.call("set_prompt_visible", visible_now)
