class_name Enemy
extends CharacterBody2D
## World enemy (Pixel Crawler mobs) for Raven Hollow: Emberfall.
## Sheets verified by pixel inspection (see ASSET_MANIFEST.md):
##  - idle: 4 frames of 32x32, run: 6 frames of 64x64, death: varies per type
##    (DEATH_LAYOUTS below — skeleton/orc_warrior death sheets contain fully
##    transparent flicker frames; kept, the artist baked them in on purpose).
##  - Every animation has its feet on the LAST pixel row of the frame, so the
##    per-anim sprite offset is -frame_height/2 (node position = feet line).
##  - All sheets face RIGHT; flip_h is enabled when moving/facing left.
## AI: patrol (lazy seeded wander around home) -> chase when the living player
## is within AGGRO_RANGE -> 0.4 s telegraphed melee windup -> strike, 1.2 s
## cooldown. Leashes home (heal to full) past LEASH_RANGE.
##
## Phase B.1: the old bare HP bar is now a WoW-style Nameplate (name label +
## HP bar) that polls its parent's hp and the player's "target" on its own —
## see the Nameplate inner class (also reused by Combat.Scarecrow, bar-less).

const SHEET_DIR := "res://assets/art/enemies/"
## Wilderness animal sheets (LPC / Pixel-Crawler animals). Frame rects below
## are PIL-verified against these (scratchpad/wild_geometry.json + manual crops);
## never guess an animal rect. Imported into res:// (each PNG has a .import).
const FAUNA_DIR := "res://_downloads/wilderness/animals/"
const AGGRO_RANGE: float = 120.0
const DEAGGRO_RANGE: float = 220.0
const ATTACK_RANGE: float = 22.0
const HIT_RANGE: float = 30.0
const WINDUP_TIME: float = 0.4
const ATTACK_COOLDOWN: float = 1.2
const LEASH_RANGE: float = 280.0
const AGGRO_HOLD_TIME: float = 6.0  # keep chasing this long after being hit
const PATROL_SPEED_MULT: float = 0.45
const KNOCKBACK_PX: float = 6.0
const PLATE_POS := Vector2(0.0, -40.0)
const WINDUP_TINT := Color(1.3, 0.85, 0.72)
const SLASH_COLOR := Color(0.78, 0.36, 0.22)

## Death sheet geometry per type, verified with PIL: [frame_count, frame_w, frame_h].
const DEATH_LAYOUTS: Dictionary = {
	"orc": [6, 64, 64],
	"orc_rogue": [6, 64, 64],
	"orc_shaman": [7, 64, 64],
	"orc_warrior": [9, 64, 80],
	"skeleton": [12, 64, 64],
	"skeleton_mage": [6, 64, 64],
	"skeleton_rogue": [6, 64, 64],
	"skeleton_warrior": [8, 48, 48],
}

var is_dead: bool = false
var hp: float = 40.0
var max_hp: float = 40.0
var damage: float = 8.0
var speed: float = 60.0
var patrol_radius: float = 60.0
var home: Vector2 = Vector2.ZERO
var type_name: String = "skeleton"
var display_name: String = "Skeleton"

var _state: String = "patrol"
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _col: CollisionShape2D
var _plate: Nameplate
var _anim_offsets: Dictionary = {}
## Wilderness fauna sheets face RIGHT after the picks below (wolf/bear/boar
## right-facing rows chosen), so this stays false and the shared flip logic is
## unchanged; kept as a hook in case a future sheet only ships a left row.
var _art_faces_left: bool = false
var _patrol_target: Vector2 = Vector2.ZERO
var _idle_wait: float = 0.0
var _leg_time: float = 0.0
var _attack_cd: float = 0.0
var _windup_left: float = 0.0
var _windup_dir: Vector2 = Vector2.RIGHT
var _flash_tween: Tween
var _lean_tween: Tween
var _slow_mult: float = 1.0   # crowd control: speed multiplier while slowed
var _slow_left: float = 0.0
var _root_left: float = 0.0   # crowd control: frozen in place while > 0
var _aggro_left: float = 0.0  # hold aggro window after taking a hit


static func create(cfg: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.type_name = str(cfg.get("type", "skeleton"))
	# String.capitalize() turns "skeleton_rogue" into "Skeleton Rogue".
	e.display_name = str(cfg.get("display_name", e.type_name.capitalize()))
	e.name = "Enemy_" + e.type_name
	e.position = cfg.get("pos", Vector2.ZERO)
	e.home = e.position
	e.patrol_radius = float(cfg.get("patrol_radius", 60.0))
	e.max_hp = float(cfg.get("hp", 40.0))
	e.hp = e.max_hp
	e.damage = float(cfg.get("damage", 8.0))
	e.speed = float(cfg.get("speed", 60.0))
	# Convention: physics layer NUMBERS — walls=1, player=2, npcs=3, enemies=4.
	e.collision_layer = 1 << 3
	e.collision_mask = 1
	e.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	e.y_sort_enabled = true
	e.add_to_group("enemies")
	# Deterministic-ish wander: RNG seeded from the spawn position.
	e._rng.seed = hash(e.position)
	e._patrol_target = e.position
	e._idle_wait = e._rng.randf_range(0.3, 1.5)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	if bool(cfg.get("fauna", false)):
		# Wilderness animal (wolf/boar/bear): LPC/PixelCrawler animal sheets
		# with their own geometry, not the Pixel-Crawler mob idle/run/death
		# triple. Feet sit on the bottom row of each frame -> offset -h/2.
		var fauna: Dictionary = _build_fauna_frames(e.type_name)
		sprite.sprite_frames = fauna["frames"]
		e._anim_offsets = fauna["offsets"]
		e._art_faces_left = bool(fauna["faces_left"])
	else:
		var layout: Array = DEATH_LAYOUTS.get(e.type_name, [6, 64, 64])
		# Feet sit on the bottom row of every frame (verified), so lifting the
		# centered frame by half its height puts the feet exactly at node pos.
		e._anim_offsets = {
			"idle": Vector2(0.0, -16.0),
			"run": Vector2(0.0, -32.0),
			"death": Vector2(0.0, -float(layout[2]) * 0.5),
		}
		sprite.sprite_frames = _build_frames(e.type_name, layout)
	sprite.offset = e._anim_offsets["idle"]
	sprite.play("idle")
	sprite.animation_finished.connect(e._on_anim_finished)
	e.add_child(sprite)
	e._sprite = sprite

	var col := CollisionShape2D.new()
	col.name = "Feet"
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	e.add_child(col)
	e._col = col

	var plate := Nameplate.new(e.display_name, true)
	plate.position = PLATE_POS
	plate.visible = false
	e.add_child(plate)
	e._plate = plate

	return e


static func _build_frames(t: String, death_layout: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_strip(sf, SHEET_DIR + t + "_idle.png", "idle", 4, 32, 32, 5.0, true)
	_add_strip(sf, SHEET_DIR + t + "_run.png", "run", 6, 64, 64, 10.0, true)
	_add_strip(sf, SHEET_DIR + t + "_death.png", "death",
			int(death_layout[0]), int(death_layout[1]), int(death_layout[2]), 10.0, false)
	return sf


static func _add_strip(sf: SpriteFrames, path: String, anim: String, count: int, fw: int, fh: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(path)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(float(i * fw), 0.0), Vector2(float(fw), float(fh)))
		sf.add_frame(anim, at)


## Builds idle/run/death SpriteFrames for a wilderness combatant animal from
## the LPC / Wild-Boar / Pixel-Crawler wolf sheets. Every rect here was
## PIL-verified (see wild_geometry.json + scratchpad crops); all picked rows
## face RIGHT so the shared flip logic (faces_left=false) is unchanged. Feet on
## the frame bottom -> offset -h/2. Returns {frames, offsets, faces_left}.
static func _build_fauna_frames(t: String) -> Dictionary:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var off := {}
	match t:
		"boar":
			# Wild-Boar modular pack; row3 (y=192) is the RIGHT-facing side view
			# across Walk/Stand/Die (verified). 64x64 frames.
			var b := FAUNA_DIR + "boar/Wild Boar/Boar/"
			var walk: Texture2D = load(b + "Boar Walk.png")
			var stand: Texture2D = load(b + "Boar Stand.png")
			var die: Texture2D = load(b + "Boar Die.png")
			_fauna_anim(sf, stand, "idle", [Rect2(192, 0, 64, 64)], 3.0, true)
			_fauna_anim(sf, walk, "run", [
				Rect2(0, 192, 64, 64), Rect2(64, 192, 64, 64),
				Rect2(128, 192, 64, 64), Rect2(192, 192, 64, 64)], 9.0, true)
			_fauna_anim(sf, die, "death", [
				Rect2(0, 192, 64, 64), Rect2(64, 192, 64, 64),
				Rect2(128, 192, 64, 64), Rect2(192, 192, 64, 64)], 8.0, false)
			off = {"idle": Vector2(0.0, -32.0), "run": Vector2(0.0, -32.0), "death": Vector2(0.0, -32.0)}
		"bear":
			# LPC-2022 grizzly, 5x12 of 64x64: row1(y64) stand, row2(y128)
			# side walk (RIGHT-facing), row10(y640) collapse = death. tRNS
			# transparency imports correctly in Godot (magenta only in dumb viewers).
			var g: Texture2D = load(FAUNA_DIR + "lpc2022/lpc animals 2022 v1.1/individual creature spritesheets/bear, grizzly.png")
			_fauna_anim(sf, g, "idle", [Rect2(0, 64, 64, 64)], 3.0, true)
			_fauna_anim(sf, g, "run", [
				Rect2(0, 128, 64, 64), Rect2(64, 128, 64, 64),
				Rect2(128, 128, 64, 64), Rect2(192, 128, 64, 64)], 6.0, true)
			_fauna_anim(sf, g, "death", [
				Rect2(0, 640, 64, 64), Rect2(64, 640, 64, 64),
				Rect2(128, 640, 64, 64), Rect2(192, 640, 64, 64)], 6.0, false)
			off = {"idle": Vector2(0.0, -32.0), "run": Vector2(0.0, -32.0), "death": Vector2(0.0, -32.0)}
		_:
			# "wolf" (and any unknown fauna): wolfsheet1, 10x6 of 64x64. Cols 5-9
			# are the RIGHT-facing side views. row2(y128) c5-8 = trot; row0/row3
			# c5-6 sink into the c320,y192 flat pose = death.
			var w: Texture2D = load(FAUNA_DIR + "wolfsheet1.png")
			_fauna_anim(sf, w, "idle", [Rect2(320, 128, 64, 64)], 4.0, true)
			_fauna_anim(sf, w, "run", [
				Rect2(320, 128, 64, 64), Rect2(384, 128, 64, 64),
				Rect2(448, 128, 64, 64), Rect2(512, 128, 64, 64)], 11.0, true)
			_fauna_anim(sf, w, "death", [
				Rect2(384, 0, 64, 64), Rect2(448, 0, 64, 64),
				Rect2(512, 0, 64, 64), Rect2(320, 192, 64, 64)], 8.0, false)
			off = {"idle": Vector2(0.0, -32.0), "run": Vector2(0.0, -32.0), "death": Vector2(0.0, -32.0)}
	return {"frames": sf, "offsets": off, "faces_left": false}


static func _fauna_anim(sf: SpriteFrames, tex: Texture2D, anim: String, rects: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for r: Rect2 in rects:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = r
		sf.add_frame(anim, at)


# --- AI ----------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_slow_left = maxf(0.0, _slow_left - delta)
	_aggro_left = maxf(0.0, _aggro_left - delta)
	var player: Node2D = _alive_player()
	if _root_left > 0.0:
		# Rooted: frozen in place (state machine paused, resumes after).
		_root_left = maxf(0.0, _root_left - delta)
		velocity = Vector2.ZERO
		if player != null:
			_face_point(player.global_position)
		if _state != "windup":
			_play("idle")
		return
	match _state:
		"patrol":
			_tick_patrol(delta, player)
		"chase":
			_tick_chase(player)
		"windup":
			_tick_windup(delta, player)
		"return":
			_tick_return()


func _tick_patrol(delta: float, player: Node2D) -> void:
	if player != null and global_position.distance_to(player.global_position) < _aggro_range():
		_state = "chase"
		return
	if _idle_wait > 0.0:
		_idle_wait -= delta
		velocity = Vector2.ZERO
		_play("idle")
		if _idle_wait <= 0.0:
			_pick_patrol_target()
		return
	_leg_time -= delta
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() < 4.0 or _leg_time <= 0.0:
		_idle_wait = _rng.randf_range(1.0, 3.0)
		velocity = Vector2.ZERO
		_play("idle")
		return
	velocity = to_target.normalized() * _speed_now() * PATROL_SPEED_MULT
	move_and_slide()
	if get_slide_collision_count() > 0:
		# Bumped a wall/prop: give up on this leg after a short pause.
		_idle_wait = _rng.randf_range(0.5, 1.5)
	_face_move()
	_play("run")


## Aggro detection radius. Wolves hunt in the dark: their aggro doubles at
## night (SPEC §6). Reads the "day_night" group's is_night (frozen DayNight);
## non-wolves and daytime keep the base radius, and the group lookup only runs
## for wolves so skeletons/orcs pay nothing.
func _aggro_range() -> float:
	if type_name == "wolf":
		var dn := get_tree().get_first_node_in_group("day_night")
		if dn != null and dn.get("is_night") == true:
			return AGGRO_RANGE * 2.0
	return AGGRO_RANGE


func _pick_patrol_target() -> void:
	var ang: float = _rng.randf_range(0.0, TAU)
	var r: float = sqrt(_rng.randf()) * patrol_radius
	_patrol_target = home + Vector2.from_angle(ang) * r
	_leg_time = 4.0


func _tick_chase(player: Node2D) -> void:
	if player == null or global_position.distance_to(home) > LEASH_RANGE:
		_state = "return"
		velocity = Vector2.ZERO
		return
	var to_p: Vector2 = player.global_position - global_position
	var dist: float = to_p.length()
	# A recent hit holds aggro (up to the leash) so ranged chip damage from
	# beyond DEAGGRO_RANGE provokes a chase instead of an instant reset.
	if dist > DEAGGRO_RANGE and _aggro_left <= 0.0:
		_state = "return"
		velocity = Vector2.ZERO
		return
	if dist <= ATTACK_RANGE:
		velocity = Vector2.ZERO
		_face_point(player.global_position)
		if _attack_cd <= 0.0:
			_start_windup(to_p.normalized() if to_p.length_squared() > 0.01 else _windup_dir)
		else:
			_play("idle")
		return
	velocity = to_p.normalized() * _speed_now()
	move_and_slide()
	_face_move()
	_play("run")


func _start_windup(dir: Vector2) -> void:
	_state = "windup"
	_windup_left = WINDUP_TIME
	_windup_dir = dir
	velocity = Vector2.ZERO
	_play("idle")
	# Attack tell: warm tint + a slow lean into the strike.
	_sprite.modulate = WINDUP_TINT
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_sprite.position = Vector2.ZERO
	_lean_tween = create_tween()
	_lean_tween.tween_property(_sprite, "position", dir * 4.0, WINDUP_TIME)


func _tick_windup(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	if player != null:
		_face_point(player.global_position)
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	_end_windup_tell()
	_attack_cd = ATTACK_COOLDOWN
	_state = "chase"
	if player == null:
		return
	var to_p: Vector2 = player.global_position - global_position
	if to_p.length() <= HIT_RANGE:
		var dir: Vector2 = to_p.normalized() if to_p.length_squared() > 0.01 else _windup_dir
		var parent := get_parent()
		if parent != null:
			VFX.slash_arc(parent, global_position + dir * 10.0, dir, SLASH_COLOR, 16.0)
		Combat.deal_damage(player, damage, self)


func _end_windup_tell() -> void:
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.1)
	_sprite.modulate = Color.WHITE


func _tick_return() -> void:
	var to_home: Vector2 = home - global_position
	if to_home.length() < 6.0:
		if _aggro_left <= 0.0:
			hp = max_hp  # only heal once the fight has actually broken off
		_state = "patrol"
		_idle_wait = _rng.randf_range(0.5, 1.5)
		velocity = Vector2.ZERO
		_play("idle")
		return
	velocity = to_home.normalized() * _speed_now()
	move_and_slide()
	_face_move()
	_play("run")


# --- Crowd control -------------------------------------------------------------


func _speed_now() -> float:
	return speed * (_slow_mult if _slow_left > 0.0 else 1.0)


func apply_slow(mult: float, duration: float) -> void:
	if is_dead:
		return
	_slow_mult = clampf(mult, 0.05, 1.0)
	_slow_left = maxf(_slow_left, duration)


func apply_root(duration: float) -> void:
	if is_dead:
		return
	_root_left = maxf(_root_left, duration)
	velocity = Vector2.ZERO


# --- Damage / death ----------------------------------------------------------


func take_damage(amount: float, source: Node) -> void:
	if is_dead:
		return
	hp -= amount
	_aggro_left = AGGRO_HOLD_TIME
	_flash_red()
	var src := source as Node2D
	if src != null and is_instance_valid(src):
		var away: Vector2 = global_position - src.global_position
		if away.length_squared() > 0.01:
			move_and_collide(away.normalized() * KNOCKBACK_PX)
	if hp <= 0.0:
		hp = 0.0
		_die()
		return
	if _state == "patrol" or _state == "return":
		_state = "chase"


func _flash_red() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(1.0, 0.3, 0.3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	if _plate != null:
		_plate.visible = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_sprite.modulate = Color.WHITE
	_sprite.position = Vector2.ZERO
	set_deferred("collision_layer", 0)
	_col.set_deferred("disabled", true)
	_grant_kill_rewards()
	_play("death")


## Phase C kill payoff, fired exactly once from _die() (take_damage gates on
## is_dead so this can't double-fire). Grants kill XP (XPSystem resolves family
## prefixes: skeleton_*/orc_* and wolf/boar/bear; scarecrow never reaches here),
## rolls the material drop table into the killer's bag, and reports the kill to
## the Quests node for kill objectives. All look-ups are null-safe so a mob dying
## with no player/inventory/quests present is harmless.
func _grant_kill_rewards() -> void:
	var killer := get_tree().get_first_node_in_group("player")
	if killer != null:
		XPSystem.grant_xp(killer, XPSystem.xp_for_kill(type_name))
		var inv_v: Variant = killer.get("inventory")
		if inv_v is Inventory:
			var got: Array[Dictionary] = Crafting.drop_for_kill(inv_v, type_name)
			if not got.is_empty():
				var cui := get_tree().get_first_node_in_group("crafting_ui")
				if cui != null:
					for it: Dictionary in got:
						cui.call("show_toast", "+ %s" % str(it.get("name", "")),
								Color(0.85, 0.68, 0.35))
	var q := get_tree().get_first_node_in_group("quests")
	if q != null:
		q.call("report_kill", type_name)


func _on_anim_finished() -> void:
	# Only the (non-looping) death animation ever finishes.
	if not is_dead:
		return
	# The corpse dissipates in a smoke poof (Pimen sheet via VFX.smoke),
	# per the effect mapping — same treatment as minion despawn.
	var parent := get_parent()
	if parent != null:
		VFX.smoke(parent, global_position)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


# --- Helpers -----------------------------------------------------------------


func _play(anim: String) -> void:
	if _sprite.animation != StringName(anim) or not _sprite.is_playing():
		_sprite.offset = _anim_offsets.get(anim, Vector2.ZERO)
		_sprite.play(anim)


func _face_move() -> void:
	# Sheets face RIGHT (verified) -> mirror when heading left. _art_faces_left
	# inverts it for any sheet whose picked row faces left (currently none —
	# XOR with false is a no-op, so existing mobs are unchanged).
	if absf(velocity.x) > 0.5:
		_sprite.flip_h = (velocity.x < 0.0) != _art_faces_left


func _face_point(p: Vector2) -> void:
	if absf(p.x - global_position.x) > 0.5:
		_sprite.flip_h = (p.x < global_position.x) != _art_faces_left


func _alive_player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return null
	var hp_v: Variant = p.get("hp")
	if hp_v is float and float(hp_v) <= 0.0:
		return null
	return p


class Nameplate extends Node2D:
	## WoW-style nameplate: centered name label (Alagard 8, hostile red, dark
	## outline) over a 26x3 px HP bar. Fully self-managing — each physics tick
	## it polls the parent's hp / max_hp / is_dead and the player's "target".
	## Shown when the owner is hurt, is the player's target, or the player is
	## within SHOW_RANGE px. While targeted: brighter name, bar 1 px taller,
	## subtle gold corner ticks. with_bar=false (the training scarecrow)
	## renders the name only. Also used by Combat.Scarecrow.
	const SHOW_RANGE: float = 90.0
	const NAME_RED := Color(0.85, 0.25, 0.2)
	const NAME_RED_BRIGHT := Color(1.0, 0.45, 0.38)
	const OUTLINE_DARK := Color(0.1, 0.06, 0.04, 0.95)
	const BAR_BG := Color(0.07, 0.05, 0.04, 0.92)
	const BAR_FILL := Color(0.72, 0.16, 0.14)
	const TICK_GOLD := Color(0.85, 0.68, 0.35, 0.9)
	const BAR_W: float = 26.0

	var frac: float = 1.0
	var targeted: bool = false
	var show_hp_bar: bool = true
	var _label: Label
	var _settings: LabelSettings  # per-plate instance, safe to recolor

	func _init(display_name: String, with_bar: bool) -> void:
		name = "Nameplate"
		show_hp_bar = with_bar
		z_index = 2  # readable above nearby world sprites despite y-sort
		_settings = LabelSettings.new()
		_settings.font = load("res://assets/fonts/alagard.ttf")
		_settings.font_size = 8
		_settings.font_color = NAME_RED
		_settings.outline_size = 3
		_settings.outline_color = OUTLINE_DARK
		_label = Label.new()
		_label.name = "Name"
		_label.label_settings = _settings
		_label.text = display_name
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Clicks must fall through to the world for mouse targeting.
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.size = Vector2(96.0, 10.0)
		_label.position = Vector2(-48.0, -12.0)
		add_child(_label)

	func _physics_process(_delta: float) -> void:
		var holder := get_parent() as Node2D
		if holder == null:
			return
		if holder.get("is_dead") == true:
			visible = false
			return
		var hp_v: Variant = holder.get("hp")
		var max_v: Variant = holder.get("max_hp")
		var hp_now: float = float(hp_v) if hp_v is float else 1.0
		var hp_max: float = maxf(float(max_v) if max_v is float else 1.0, 0.01)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var has_player: bool = player != null and is_instance_valid(player)
		var is_target: bool = has_player and player.get("target") == holder
		var near: bool = has_player and \
				player.global_position.distance_to(holder.global_position) <= SHOW_RANGE
		var hurt: bool = show_hp_bar and hp_now < hp_max - 0.01
		visible = hurt or is_target or near
		if not visible:
			return
		if is_target != targeted:
			targeted = is_target
			_settings.font_color = NAME_RED_BRIGHT if targeted else NAME_RED
			queue_redraw()
		if show_hp_bar:
			var f: float = clampf(hp_now / hp_max, 0.0, 1.0)
			if not is_equal_approx(f, frac):
				frac = f
				queue_redraw()

	func _draw() -> void:
		if not show_hp_bar:
			return
		var h: float = 4.0 if targeted else 3.0
		var bx0: float = -BAR_W * 0.5
		var bx1: float = BAR_W * 0.5
		draw_rect(Rect2(bx0, 0.0, BAR_W, h), BAR_BG)
		var w: float = (BAR_W - 2.0) * clampf(frac, 0.0, 1.0)
		if w > 0.0:
			draw_rect(Rect2(bx0 + 1.0, 1.0, w, h - 2.0), BAR_FILL)
		if not targeted:
			return
		# Subtle gold L-shaped ticks framing the targeted bar's corners.
		draw_rect(Rect2(bx0 - 2.0, -2.0, 3.0, 1.0), TICK_GOLD)
		draw_rect(Rect2(bx0 - 2.0, -2.0, 1.0, 3.0), TICK_GOLD)
		draw_rect(Rect2(bx1 - 1.0, -2.0, 3.0, 1.0), TICK_GOLD)
		draw_rect(Rect2(bx1 + 1.0, -2.0, 1.0, 3.0), TICK_GOLD)
		draw_rect(Rect2(bx0 - 2.0, h + 1.0, 3.0, 1.0), TICK_GOLD)
		draw_rect(Rect2(bx0 - 2.0, h - 1.0, 1.0, 3.0), TICK_GOLD)
		draw_rect(Rect2(bx1 - 1.0, h + 1.0, 3.0, 1.0), TICK_GOLD)
		draw_rect(Rect2(bx1 + 1.0, h - 1.0, 1.0, 3.0), TICK_GOLD)
