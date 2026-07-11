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

## BACKLOG #76 Bestiary: map this mob's type/name to a data/bestiary.json creature
## id so a landed hit can route that creature's UNIQUE signature debuff through
## StatusSystem and record it in the codex. Exact species (wolf/boar) win; every
## other type falls back to its family prefix (skeleton_* / orc_*). Anything with
## no reasonable match (e.g. bear) resolves to "" and is skipped silently. Best-
## effort only: undead skeletons -> a signature undead, orc raiders -> a cultist.
const BESTIARY_MAP: Dictionary = {
	"wolf": "stonepath_wolf",   # exact species; its signature IS wolf_bite
	"boar": "thicket_boar",     # exact species; charger beast
	"skeleton": "bark_revenant",  # family fallback: undead
	"orc": "ember_cultist",       # family fallback: cultist (humanoid raiders)
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
# --- BLUEPRINT_33 archetype layer (additive: empty archetype -> legacy AI) ---
var level: int = 1
var archetype: String = ""
var rank: String = "normal"
var _arch: Dictionary = {}          # MobScaling.archetype(archetype), {} if none
var _swing_count: int = 0           # heavy swing lands every Nth melee swing
var _heavy_pending: bool = false    # the current windup is the heavy one
var _cast_total: float = 0.0        # caster channel length
var _cast_left: float = 0.0
var _cast_cd: float = 0.0
var _stagger_left: float = 0.0      # interrupted-cast / stun recovery (no action)
var _charge_state: String = ""      # "", "tell", "dash", "recover"
var _charge_left: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_dest: Vector2 = Vector2.ZERO
var _charge_cd: float = 0.0
var _vuln_left: float = 0.0         # charge-whiff window: takes bonus damage
var _enraged: bool = false
var _pack_called: bool = false      # social aggro fires once per engagement
var _tele_node: Node2D = null       # ground wedge / charge-line telegraph decal
var _demo: bool = false             # RH_ENEMY_DEMO QA hook
var _demo_phase: float = 0.0


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
	# BLUEPRINT_33: archetype/level/rank feed the additive AI layer + kill XP.
	# A blank/unknown archetype leaves _arch empty -> legacy behavior (no regress).
	e.level = int(cfg.get("level", 1))
	e.archetype = str(cfg.get("archetype", ""))
	e.rank = str(cfg.get("rank", "normal"))
	if e.archetype != "" and MobScaling.has_archetype(e.archetype):
		e._arch = MobScaling.archetype(e.archetype)
	e._demo = not OS.get_environment("RH_ENEMY_DEMO").is_empty()
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
		# Owner QA (2026-07-05): LPC animal sheets are 64px art in a ~32px
		# world and read a size class too big + a shade too bright. Scale
		# to species size and mute toward the house palette.
		var fscale: float = {"boar": 0.60, "bear": 0.85, "wolf": 0.72}.get(e.type_name, 0.70)
		sprite.scale = Vector2.ONE * fscale
		sprite.modulate = Color(0.90, 0.87, 0.83)
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
		"werewolf":
			# LPC Wolfman (#104 — TRUE Varcolac sprites; sourcing law: animated
			# characters come from verified-free packs). Standard LPC 64x64 rows
			# up/left/down/right; row3 (y=192) is RIGHT-facing. Walk 9 cols
			# (col0 = stance), Slash 6 cols, Hurt single row 6 cols = collapse.
			var ww: Texture2D = load("res://assets/art/creatures/wolfman/black_walk.png")
			var wh: Texture2D = load("res://assets/art/creatures/wolfman/black_hurt.png")
			_fauna_anim(sf, ww, "idle", [Rect2(0, 192, 64, 64)], 3.0, true)
			_fauna_anim(sf, ww, "run", [
				Rect2(64, 192, 64, 64), Rect2(128, 192, 64, 64),
				Rect2(192, 192, 64, 64), Rect2(256, 192, 64, 64),
				Rect2(320, 192, 64, 64), Rect2(384, 192, 64, 64),
				Rect2(448, 192, 64, 64), Rect2(512, 192, 64, 64)], 10.0, true)
			_fauna_anim(sf, wh, "death", [
				Rect2(0, 0, 64, 64), Rect2(64, 0, 64, 64), Rect2(128, 0, 64, 64),
				Rect2(192, 0, 64, 64), Rect2(256, 0, 64, 64), Rect2(320, 0, 64, 64)], 8.0, false)
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
	_cast_cd = maxf(0.0, _cast_cd - delta)
	_charge_cd = maxf(0.0, _charge_cd - delta)
	_vuln_left = maxf(0.0, _vuln_left - delta)
	if _demo:
		_tick_demo(delta)
		return
	var player: Node2D = _alive_player()
	# Interrupted-cast / charge-whiff recovery: frozen, taking no action.
	if _stagger_left > 0.0:
		_stagger_left = maxf(0.0, _stagger_left - delta)
		velocity = Vector2.ZERO
		if player != null:
			_face_point(player.global_position)
		_play("idle")
		return
	if _root_left > 0.0:
		# Rooted: frozen in place (state machine paused, resumes after). A root
		# also interrupts an in-progress cast or charge (CC teaching, s5.2/s5.3).
		_root_left = maxf(0.0, _root_left - delta)
		_cancel_cast(true)
		_cancel_charge()
		velocity = Vector2.ZERO
		if player != null:
			_face_point(player.global_position)
		if _state != "windup":
			_play("idle")
		return
	# A charge in progress overrides the normal state machine.
	if _charge_state != "":
		_tick_charge(delta, player)
		return
	match _state:
		"patrol":
			_tick_patrol(delta, player)
		"chase":
			_tick_chase(delta, player)
		"windup":
			_tick_windup(delta, player)
		"cast":
			_tick_cast(delta, player)
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
	var base: float = AGGRO_RANGE
	if _has_archetype():
		base = float(_arch.get("aggro_px", AGGRO_RANGE))
	# Wolves hunt in the dark: aggro doubles at night (SPEC s6 / stalker
	# night_aggro behavior). The group lookup only runs for night-hunters.
	if type_name == "wolf" or _behavior("night_aggro"):
		var dn := get_tree().get_first_node_in_group("day_night")
		if dn != null and dn.get("is_night") == true:
			return base * 2.0
	return base


func _leash_range() -> float:
	return float(_arch.get("leash_px", LEASH_RANGE)) if _has_archetype() else LEASH_RANGE


func _has_archetype() -> bool:
	return not _arch.is_empty()


func _behavior(b: String) -> bool:
	return (_arch.get("behaviors", []) as Array).has(b)


func _tf(key: String, dflt: float) -> float:
	return float(MobScaling.tele().get(key, dflt))


func _cf(key: String, dflt: float) -> float:
	return float(MobScaling.cast_cfg().get(key, dflt))


func _pf(key: String, dflt: float) -> float:
	return float(MobScaling.pack_cfg().get(key, dflt))


func _pick_patrol_target() -> void:
	var ang: float = _rng.randf_range(0.0, TAU)
	var r: float = sqrt(_rng.randf()) * patrol_radius
	_patrol_target = home + Vector2.from_angle(ang) * r
	_leg_time = 4.0


func _tick_chase(delta: float, player: Node2D) -> void:
	if player == null or global_position.distance_to(home) > _leash_range():
		_state = "return"
		velocity = Vector2.ZERO
		_pack_called = false
		return
	# Hard leash safety (s4.AI): dragged far past the soft leash -> snap home +
	# full heal so mobs cannot be kited into town.
	if global_position.distance_to(home) > MobScaling.hard_reset_px():
		global_position = home
		hp = max_hp
		_reset_combat_state()
		_state = "patrol"
		velocity = Vector2.ZERO
		return
	var to_p: Vector2 = player.global_position - global_position
	var dist: float = to_p.length()
	# A recent hit holds aggro (up to the leash) so ranged chip damage from
	# beyond DEAGGRO_RANGE provokes a chase instead of an instant reset.
	if dist > DEAGGRO_RANGE and _aggro_left <= 0.0:
		_state = "return"
		velocity = Vector2.ZERO
		_pack_called = false
		return
	# Social aggro: first chase frame pulls nearby packmates in (careful pulls).
	if not _pack_called and _behavior("social_aggro"):
		_call_pack()
		_pack_called = true
	# Caster: kite to a preferred band and open fire (does not melee-chase).
	if _behavior("cast"):
		_tick_caster(delta, player, to_p, dist)
		return
	# Charger: telegraphed locked line charge from mid-range, off cooldown.
	if _behavior("charge") and _charge_cd <= 0.0 \
			and dist >= _tf("charge_trigger_min", 90.0) and dist <= _tf("charge_trigger_max", 170.0):
		_start_charge(player)
		return
	if dist <= ATTACK_RANGE:
		velocity = Vector2.ZERO
		_face_point(player.global_position)
		if _attack_cd <= 0.0:
			_start_windup(to_p.normalized() if to_p.length_squared() > 0.01 else _windup_dir)
		else:
			_play("idle")
		return
	# Flanking packs surround the player instead of conga-lining.
	var aim: Vector2 = _flank_offset(player.global_position) if _behavior("flank") else player.global_position
	# Route AROUND obstacles via the runtime navmesh (BACKLOG #96). NavSystem
	# returns the next waypoint toward `aim`; if nav is off/unready it returns
	# `aim` unchanged, so this degrades to the original direct steering.
	var waypoint: Vector2 = aim
	if NavSystem != null and NavSystem.has_method("next_point"):
		waypoint = NavSystem.next_point(global_position, aim)
	var step_dir: Vector2 = waypoint - global_position
	var mv: Vector2 = step_dir.normalized() if step_dir.length_squared() > 1.0 else to_p.normalized()
	velocity = mv * _speed_now()
	move_and_slide()
	_face_move()
	_play("run")


func _start_windup(dir: Vector2) -> void:
	_state = "windup"
	_windup_dir = dir
	velocity = Vector2.ZERO
	_play("idle")
	# Heavy swing every Nth swing for archetypes that telegraph big hits: longer,
	# more legible windup + a ground wedge showing the hit arc (step out of it --
	# the strike-time HIT_RANGE re-check whiffs it). Fast duelists swing quicker.
	_swing_count += 1
	var heavy_every: int = int(_tf("heavy_every", 3.0))
	_heavy_pending = _behavior("heavy_swing") and heavy_every > 0 and (_swing_count % heavy_every == 0)
	if _behavior("fast_swing"):
		_windup_left = _tf("fast_windup", 0.3)
	elif _heavy_pending:
		_windup_left = _tf("heavy_windup", 0.8)
	else:
		_windup_left = WINDUP_TIME
	# Attack tell: warm tint (hotter on a heavy) + a slow lean into the strike.
	_sprite.modulate = Color(1.6, 0.6, 0.5) if _heavy_pending else WINDUP_TINT
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_sprite.position = Vector2.ZERO
	var lean: float = 7.0 if _heavy_pending else 4.0
	_lean_tween = create_tween()
	_lean_tween.tween_property(_sprite, "position", dir * lean, _windup_left)
	if _heavy_pending:
		_spawn_wedge(dir, HIT_RANGE + 14.0)
		var parent := get_parent()
		if parent != null:
			VFX.slash_arc(parent, global_position + dir * (HIT_RANGE * 0.6), dir, SLASH_COLOR, 20.0)


func _tick_windup(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	if player != null:
		_face_point(player.global_position)
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	_end_windup_tell()
	_attack_cd = _tf("fast_cooldown", 0.9) if _behavior("fast_swing") else ATTACK_COOLDOWN
	_state = "chase"
	if player != null:
		var to_p: Vector2 = player.global_position - global_position
		if to_p.length() <= HIT_RANGE:
			var dir: Vector2 = to_p.normalized() if to_p.length_squared() > 0.01 else _windup_dir
			var parent := get_parent()
			if parent != null:
				VFX.slash_arc(parent, global_position + dir * 10.0, dir, SLASH_COLOR, 16.0)
			Combat.deal_damage(player, _strike_damage(), self)
			# StatusSystem (design/STATUS_EFFECTS.md, #35): a wolf's landed bite
			# stacks wolf_bite; 3 stacks trip its threshold into Infected. Guarded
			# and additive -- other enemy types are unaffected.
			if type_name == "wolf":
				StatusSystem.apply(player, "wolf_bite", self)
			# BestiarySystem (#76): on a landed melee hit, apply this creature id's
			# UNIQUE on-hit signature debuff (via StatusSystem) and record it in
			# the codex. Fully guarded + additive; unmapped types do nothing.
			_apply_bestiary_signature(player)
	_heavy_pending = false


func _end_windup_tell() -> void:
	_clear_wedge()
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.1)
	_sprite.modulate = _enrage_tint() if _enraged else Color.WHITE


func _tick_return() -> void:
	var to_home: Vector2 = home - global_position
	if to_home.length() < 6.0:
		if _aggro_left <= 0.0:
			hp = max_hp  # only heal once the fight has actually broken off
			_reset_combat_state()
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
	var s: float = speed
	if _enraged:
		s *= 1.0 + float(MobScaling.enrage_cfg().get("speed_bonus", 0.35))
	return s * (_slow_mult if _slow_left > 0.0 else 1.0)


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
	var amt: float = amount
	# A charger caught mid-recovery after a whiffed charge takes bonus damage --
	# dodging the charge is rewarded, not merely survived (s5.3).
	if _vuln_left > 0.0:
		amt *= _tf("charge_vuln_mult", 1.25)
	# Any solid hit interrupts an in-progress cast -> stagger. The teaching hook:
	# melee / dash / root a caster to stop its bolt (kill the healer first).
	if _state == "cast" and amount > 0.0:
		_cancel_cast(true)
	hp -= amt
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
	# Enrage: below the hp threshold, charger/brute-family enemies speed up, hit
	# harder, and pulse red until death (finish it or kite the last sliver, s5.6).
	if not _enraged and _behavior("enrage") \
			and hp <= max_hp * float(MobScaling.enrage_cfg().get("hp_frac", 0.30)):
		_enrage()
	if _state == "patrol" or _state == "return":
		_state = "chase"


func _flash_red() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(1.0, 0.3, 0.3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", _enrage_tint() if _enraged else Color.WHITE, 0.1)


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
	_clear_wedge()
	if _plate != null:
		_plate.clear_cast()
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
		# BLUEPRINT_33 s8: kill XP scales with the mob's level + rank and greys
		# out vs an over-levelled player (replaces the flat family table).
		var plvl_v: Variant = killer.get("level")
		var plvl: int = int(plvl_v) if (plvl_v is int or plvl_v is float) else 1
		XPSystem.grant_xp(killer, XPSystem.xp_for_kill_scaled(level, rank, plvl))
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
	# Additive loot roll: LootSystem maps this enemy type to a loot table and
	# emits loot_generated (the D2-style loot window listens). Guarded and
	# non-destructive -- the crafting drop above is unchanged; an unmapped type
	# rolls nothing and shows nothing.
	if LootSystem != null and LootSystem.has_method("roll_for_enemy"):
		LootSystem.roll_for_enemy(type_name)


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


# --- BLUEPRINT_33 archetype behaviors ---------------------------------------


func _strike_damage() -> float:
	## Melee/cast damage for one landed hit: heavy-swing multiplier (this swing
	## only), enrage bonus, and pack bonus fold in on top of the base `damage`.
	var d: float = damage
	if _heavy_pending:
		d *= _tf("heavy_mult", 1.6)
	if _enraged:
		d *= 1.0 + float(MobScaling.enrage_cfg().get("dmg_bonus", 0.40))
	if _behavior("pack_bonus"):
		d *= _pack_damage_mult()
	return d


# --- BACKLOG #76 Bestiary: on-hit signature debuff + codex discovery ---------


func _bestiary_id() -> String:
	## Resolve this enemy to a data/bestiary.json creature id. Exact species
	## (wolf/boar) first, else the mob family prefix (skeleton_* -> "skeleton",
	## orc_* -> "orc"). Returns "" for anything unmatched (e.g. bear) so the
	## caller skips silently. Pure lookup -- no side effects.
	if BESTIARY_MAP.has(type_name):
		return str(BESTIARY_MAP[type_name])
	var fam: String = type_name.split("_")[0] if type_name != "" else ""
	return str(BESTIARY_MAP.get(fam, ""))


func _apply_bestiary_signature(target: Node) -> void:
	## Guarded + additive bridge to /root/BestiarySystem. On a landed hit it marks
	## this creature discovered (codex) and routes its UNIQUE signature debuff
	## through StatusSystem. Absent system, unmapped type, or missing methods all
	## degrade to a no-op -- base enemy damage/AI is never changed.
	if target == null or not is_instance_valid(target):
		return
	var bid: String = _bestiary_id()
	if bid == "":
		return
	var bs: Node = get_node_or_null("/root/BestiarySystem")
	if bs == null:
		return
	if bs.has_method("discover"):
		bs.call("discover", bid)
	if bs.has_method("apply_signature"):
		bs.call("apply_signature", bid, target)


# --- caster (kite + interruptible cast bar) ---------------------------------


func _tick_caster(delta: float, player: Node2D, to_p: Vector2, dist: float) -> void:
	var pref: float = _cf("range_pref", 240.0)
	var flee: float = _cf("range_flee", 70.0)
	if dist < flee:
		# Too close: back away (kite) at reduced speed to reopen the gap.
		velocity = -to_p.normalized() * _speed_now() * _cf("kite_speed_mult", 0.8)
		move_and_slide()
		_face_point(player.global_position)
		_play("run")
		return
	if dist <= pref and _cast_cd <= 0.0:
		_start_cast(player)
		return
	if dist > pref:
		# Close the gap to preferred range, then cast.
		velocity = to_p.normalized() * _speed_now() * _cf("kite_speed_mult", 0.8)
		move_and_slide()
		_face_move()
		_play("run")
		return
	velocity = Vector2.ZERO
	_face_point(player.global_position)
	_play("idle")


func _start_cast(player: Node2D) -> void:
	_state = "cast"
	_cast_total = _cf("channel", 1.6)
	_cast_left = _cast_total
	velocity = Vector2.ZERO
	_face_point(player.global_position)
	_play("idle")
	_sprite.modulate = Color(0.8, 0.85, 1.4)  # cool cast-channel glow tell
	if _plate != null:
		_plate.set_cast(0.0)


func _tick_cast(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	if player != null:
		_face_point(player.global_position)
	_cast_left -= delta
	if _plate != null and _cast_total > 0.0:
		_plate.set_cast(clampf(1.0 - _cast_left / _cast_total, 0.0, 1.0))
	if _cast_left > 0.0:
		return
	# Channel complete: launch the bolt, enter cooldown.
	_sprite.modulate = _enrage_tint() if _enraged else Color.WHITE
	if _plate != null:
		_plate.clear_cast()
	_cast_cd = _cf("cooldown", 2.2)
	_state = "chase"
	if player != null:
		_fire_bolt(player)


func _fire_bolt(player: Node2D) -> void:
	var world := get_parent() as Node2D
	if world == null:
		return
	var aim: Vector2 = player.global_position - global_position
	if aim.length_squared() < 0.01:
		aim = _windup_dir
	# Per-creature bolt look (mandate #56): pale soul-bolt for the skeletal
	# casters, a sickly green for the orc-shaman cults.
	var col: Color = Color(0.55, 0.9, 0.5) if type_name.begins_with("orc") else Color(0.75, 0.85, 1.0)
	Combat.spawn_projectile(world, {
		"pos": global_position,
		"dir": aim.normalized(),
		"speed": _cf("projectile_speed", 180.0),
		"range": _cf("projectile_range", 560.0),
		"damage": _strike_damage(),
		"faction": "enemy",
		"kind": "bolt",
		"color": col,
	})


func _cancel_cast(stagger: bool) -> void:
	if _state != "cast" and _cast_left <= 0.0:
		return
	_cast_left = 0.0
	if _plate != null:
		_plate.interrupt_cast()
	_sprite.modulate = _enrage_tint() if _enraged else Color.WHITE
	if _state == "cast":
		_state = "chase"
	if stagger:
		_stagger_left = _cf("stagger", 1.5)
		_cast_cd = _cf("recovery", 2.5)


# --- charger (telegraphed locked line charge) -------------------------------


func _start_charge(player: Node2D) -> void:
	_charge_state = "tell"
	_charge_left = _tf("charge_windup", 0.7)
	_charge_dir = (player.global_position - global_position).normalized()
	if _charge_dir.length_squared() < 0.01:
		_charge_dir = _windup_dir
	_charge_dest = player.global_position  # locked: no homing -- a sidestep beats it
	velocity = Vector2.ZERO
	_face_point(player.global_position)
	_play("idle")
	_sprite.modulate = Color(1.6, 0.6, 0.5)
	_spawn_charge_line(_charge_dir, global_position.distance_to(_charge_dest))


func _tick_charge(delta: float, player: Node2D) -> void:
	match _charge_state:
		"tell":
			velocity = Vector2.ZERO
			if player != null:
				_face_point(player.global_position)
			_charge_left -= delta
			if _charge_left <= 0.0:
				_clear_wedge()
				_charge_state = "dash"
				_charge_left = _tf("charge_dash_time", 0.42)
		"dash":
			velocity = _charge_dir * speed * _tf("charge_speed_mult", 3.2)
			move_and_slide()
			_face_move()
			_play("run")
			if player != null and global_position.distance_to(player.global_position) <= HIT_RANGE:
				var d: float = damage * _tf("charge_dmg_mult", 1.5)
				if _enraged:
					d *= 1.0 + float(MobScaling.enrage_cfg().get("dmg_bonus", 0.40))
				Combat.deal_damage(player, d, self)
				# BestiarySystem (#76): a landed charge counts as an on-hit too.
				_apply_bestiary_signature(player)
				if player.has_method("apply_slow"):
					player.call("apply_slow", _tf("charge_slow_mult", 0.5), _tf("charge_slow_dur", 1.0))
				_end_charge(false)
				return
			_charge_left -= delta
			if _charge_left <= 0.0 or get_slide_collision_count() > 0:
				_end_charge(true)
		"recover":
			velocity = Vector2.ZERO
			if player != null:
				_face_point(player.global_position)
			_play("idle")
			_charge_left -= delta
			if _charge_left <= 0.0:
				_charge_state = ""
				_state = "chase"


func _end_charge(missed: bool) -> void:
	_clear_wedge()
	_charge_state = "recover"
	_charge_left = _tf("charge_miss_recovery", 1.2) if missed else 0.4
	_charge_cd = _tf("charge_cooldown", 6.0)
	if missed:
		_vuln_left = _charge_left  # +damage window while recovering from a whiff
	_sprite.modulate = _enrage_tint() if _enraged else Color.WHITE


func _cancel_charge() -> void:
	if _charge_state == "":
		return
	_clear_wedge()
	_charge_state = ""
	_charge_left = 0.0
	_state = "chase"
	_sprite.modulate = _enrage_tint() if _enraged else Color.WHITE


# --- pack tactics (social aggro / flanking / pack bonus) --------------------


func _call_pack() -> void:
	var social: float = _pf("social_px", 140.0)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or not is_instance_valid(e) or e.is_dead:
			continue
		if e.type_name != type_name:
			continue
		if e.global_position.distance_to(global_position) <= social:
			e._aggro_left = maxf(e._aggro_left, AGGRO_HOLD_TIME)
			if e._state == "patrol" or e._state == "return":
				e._state = "chase"


func _flank_offset(player_pos: Vector2) -> Vector2:
	# Stand at an angle around the player (side by instance id) so packmates
	# surround instead of stacking on one approach line.
	var from_player: Vector2 = global_position - player_pos
	var ang: float = from_player.angle()
	var side: float = 1.0 if (get_instance_id() % 2 == 0) else -1.0
	ang += deg_to_rad(_pf("flank_deg", 55.0)) * side
	return player_pos + Vector2.from_angle(ang) * (ATTACK_RANGE + 6.0)


func _pack_damage_mult() -> float:
	var per: float = _pf("bonus_per_ally", 0.10)
	var cap: float = _pf("bonus_cap", 0.30)
	var radius: float = _pf("bonus_px", 120.0)
	var allies: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == self or not is_instance_valid(e) or e.is_dead:
			continue
		if e.type_name != type_name:
			continue
		if e._state == "patrol" or e._state == "return":
			continue
		if e.global_position.distance_to(global_position) <= radius:
			allies += 1
	return 1.0 + minf(cap, per * float(allies))


# --- enrage / telegraph decals / state reset --------------------------------


func _enrage() -> void:
	_enraged = true
	_sprite.modulate = _enrage_tint()


func _enrage_tint() -> Color:
	return Color(1.55, 0.5, 0.42)


func _reset_combat_state() -> void:
	_enraged = false
	_pack_called = false
	_swing_count = 0
	_heavy_pending = false
	_cast_cd = 0.0
	_cast_left = 0.0
	_charge_cd = 0.0
	_charge_state = ""
	_charge_left = 0.0
	_vuln_left = 0.0
	_stagger_left = 0.0
	_clear_wedge()
	if _plate != null:
		_plate.clear_cast()
	_sprite.modulate = Color.WHITE


func _spawn_wedge(dir: Vector2, radius: float) -> void:
	## 90-degree ground wedge showing where a heavy swing will land (dodge = walk
	## out). Child of self at the feet, drawn under the sprite (z -3).
	_clear_wedge()
	var poly := Polygon2D.new()
	poly.name = "Telegraph"
	poly.z_index = -3
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var base: float = dir.angle()
	var steps: int = 8
	for i in range(steps + 1):
		var a: float = base + lerpf(-PI * 0.25, PI * 0.25, float(i) / float(steps))
		pts.append(Vector2.from_angle(a) * radius)
	poly.polygon = pts
	poly.color = Color(0.95, 0.25, 0.2, 0.30)
	add_child(poly)
	_tele_node = poly
	var tw := create_tween()
	tw.tween_property(poly, "color:a", 0.5, 0.25)


func _spawn_charge_line(dir: Vector2, dist: float) -> void:
	## Locked charge lane the boar will dash down (pulsing red quad on the ground).
	_clear_wedge()
	var line := Polygon2D.new()
	line.name = "ChargeTell"
	line.z_index = -3
	var w: float = 9.0
	var perp: Vector2 = Vector2(-dir.y, dir.x) * w
	var far: Vector2 = dir * clampf(dist, 40.0, 260.0)
	line.polygon = PackedVector2Array([-perp, perp, far + perp, far - perp])
	line.color = Color(1.0, 0.35, 0.2, 0.30)
	add_child(line)
	_tele_node = line
	var tw := create_tween()
	tw.tween_property(line, "color:a", 0.5, 0.2)


func _clear_wedge() -> void:
	if _tele_node != null and is_instance_valid(_tele_node):
		_tele_node.queue_free()
	_tele_node = null


# --- RH_ENEMY_DEMO: QA-only telegraph/cast/charge showcase in place ----------


func _tick_demo(delta: float) -> void:
	## RH_ENEMY_DEMO forces this archetype to cycle its telegraph/cast/charge tell
	## in place (facing +X) so a windowed screenshot reliably catches the feel
	## without the player pathing into every pack. QA-only, harmless (0 dmg).
	velocity = Vector2.ZERO
	var dir := Vector2.RIGHT
	_demo_phase += delta
	if _behavior("cast"):
		if _state != "cast_demo" and _cast_cd <= 0.0:
			_cast_total = _cf("channel", 1.6)
			_cast_left = _cast_total
			_state = "cast_demo"
			_sprite.modulate = Color(0.8, 0.85, 1.4)
		if _state == "cast_demo":
			_cast_left -= delta
			if _plate != null and _cast_total > 0.0:
				_plate.set_cast(clampf(1.0 - _cast_left / _cast_total, 0.0, 1.0))
			if _cast_left <= 0.0:
				_state = "patrol"
				_cast_cd = 0.0  # demo: recast immediately so the bar is always visible
				if _plate != null:
					_plate.clear_cast()
				var world := get_parent() as Node2D
				if world != null:
					var col: Color = Color(0.55, 0.9, 0.5) if type_name.begins_with("orc") else Color(0.75, 0.85, 1.0)
					Combat.spawn_projectile(world, {"pos": global_position, "dir": dir,
						"speed": _cf("projectile_speed", 180.0), "range": 220.0,
						"damage": 0.0, "faction": "enemy", "kind": "bolt", "color": col})
		_play("idle")
		return
	if _behavior("charge"):
		if _tele_node == null:
			_spawn_charge_line(dir, 120.0)
			_sprite.modulate = Color(1.6, 0.6, 0.5)
		_play("idle")
		return
	if _behavior("heavy_swing"):
		if _tele_node == null:
			_spawn_wedge(dir, HIT_RANGE + 14.0)
			_sprite.modulate = Color(1.6, 0.6, 0.5)
		_play("idle")
		return
	_play("idle")


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
	const CAST_GOLD := Color(0.95, 0.8, 0.3)

	var frac: float = 1.0
	var targeted: bool = false
	var show_hp_bar: bool = true
	var cast_frac: float = -1.0       # >= 0 while the owner is casting; -1 hidden
	var _cast_flash: float = 0.0      # white interrupt flash timer
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
		if _cast_flash > 0.0:
			_cast_flash = maxf(0.0, _cast_flash - _delta)
		var casting: bool = cast_frac >= 0.0 or _cast_flash > 0.0
		visible = hurt or is_target or near or casting
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

	func set_cast(f: float) -> void:
		cast_frac = clampf(f, 0.0, 1.0)
		queue_redraw()

	func clear_cast() -> void:
		if cast_frac < 0.0 and _cast_flash <= 0.0:
			return
		cast_frac = -1.0
		queue_redraw()

	func interrupt_cast() -> void:
		cast_frac = -1.0
		_cast_flash = 0.45
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
		# Cast bar: gold 2 px bar under the HP bar; flashes white on interrupt.
		if cast_frac >= 0.0 or _cast_flash > 0.0:
			var cy: float = h + 2.0
			draw_rect(Rect2(bx0, cy, BAR_W, 2.0), BAR_BG)
			if _cast_flash > 0.0:
				draw_rect(Rect2(bx0, cy, BAR_W, 2.0), Color(1.0, 1.0, 1.0, 0.9))
			elif cast_frac >= 0.0:
				var cw: float = BAR_W * clampf(cast_frac, 0.0, 1.0)
				if cw > 0.0:
					draw_rect(Rect2(bx0, cy, cw, 2.0), CAST_GOLD)
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
