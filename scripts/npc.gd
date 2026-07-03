class_name NPC
extends CharacterBody2D
## Wandering / stationary villager. Built entirely in code via NPC.create(def).
## def keys: id, display_name, sheet ("res://..." or "MAID"), variant:int,
## pos:Vector2, wander_radius:float (0 = stationary), dialogue:Array[String], facing:String.
## Group "npcs". Collision: circle r=6 at feet, layer 3, mask 1 (walls only).
## Phase B.1: a gold name tag (Alagard 8, dark outline) floats above the head
## while the player is within NAME_RANGE px.

const WALK_SPEED: float = 40.0
const ARRIVE_DIST: float = 3.0
const IDLE_MIN: float = 2.0
const IDLE_MAX: float = 5.0
const RESUME_DELAY: float = 1.0
## Szadi 32x48 frames: lowest opaque row (shadow bottom) is y=40 in every frame
## (pixel-verified), 16 px below the centered frame center (y=24); shift up 15
## so the shadow ellipse straddles the node pos. Matches Player.FEET_OFFSET.
const SZADI_OFFSET := Vector2(0.0, -15.0)
## Maid 64x64 frames: lowest opaque pixel row is y=47 (verified with PIL), so
## feet line ~y=48 -> 16 px below frame center -> shift up 16.
const MAID_OFFSET := Vector2(0.0, -16.0)
const NAME_RANGE: float = 70.0
const NAME_GOLD := Color(0.85, 0.68, 0.35)
const NAME_OUTLINE := Color(0.1, 0.06, 0.04, 0.95)

var display_name: String = "Villager"
var dialogue: Array = []
var _name_label: Label

var _sprite: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()
var _home: Vector2 = Vector2.ZERO
var _wander_radius: float = 0.0
var _facing: String = "down"
var _flip: bool = false
var _talking: bool = false
var _walking: bool = false
var _target: Vector2 = Vector2.ZERO
var _idle_time_left: float = 0.0
var _walk_time_left: float = 0.0


static func create(def: Dictionary) -> NPC:
	var npc := NPC.new()
	var id: String = String(def.get("id", "npc"))
	npc.name = id
	npc.display_name = String(def.get("display_name", "Villager"))
	npc.dialogue = def.get("dialogue", [])
	npc._home = def.get("pos", Vector2.ZERO)
	npc._wander_radius = float(def.get("wander_radius", 0.0))
	npc.position = npc._home
	npc._rng.seed = hash(id)
	npc._apply_facing_name(String(def.get("facing", "down")))

	var sheet: String = String(def.get("sheet", ""))
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.centered = true
	if sheet == "MAID":
		spr.sprite_frames = SheetAnim.make_maid_frames()
		spr.offset = MAID_OFFSET
	else:
		spr.sprite_frames = SheetAnim.make_szadi_frames(sheet, int(def.get("variant", 0)))
		spr.offset = SZADI_OFFSET
	npc.add_child(spr)
	npc._sprite = spr

	var col := CollisionShape2D.new()
	col.name = "Feet"
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	npc.add_child(col)

	# Floating gold name tag, shown only while the player is close (see
	# _update_name_tag). Sits just above the ~30 px body's head line.
	var tag := Label.new()
	tag.name = "NameTag"
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/alagard.ttf")
	ls.font_size = 8
	ls.font_color = NAME_GOLD
	ls.outline_size = 3
	ls.outline_color = NAME_OUTLINE
	tag.label_settings = ls
	tag.text = npc.display_name
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks pass through
	tag.size = Vector2(96.0, 10.0)
	tag.position = Vector2(-48.0, -50.0)
	tag.z_index = 2  # readable above nearby world sprites despite y-sort
	tag.visible = false
	npc.add_child(tag)
	npc._name_label = tag

	npc.collision_layer = 1 << 2
	npc.collision_mask = 1
	npc.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	npc.y_sort_enabled = true
	return npc


func _ready() -> void:
	add_to_group("npcs")
	_update_anim(false)
	if _wander_radius > 0.0:
		# Stagger first departures so villagers do not move in lockstep.
		_idle_time_left = _rng.randf_range(0.5, IDLE_MAX)


func _physics_process(delta: float) -> void:
	# Name tag first: it must track the player even for stationary or
	# mid-dialogue villagers, whose branches below return early.
	_update_name_tag()
	if _talking:
		velocity = Vector2.ZERO
		return
	if _wander_radius <= 0.0:
		return
	if _walking:
		_walk_time_left -= delta
		var to_target: Vector2 = _target - global_position
		if to_target.length() <= ARRIVE_DIST or _walk_time_left <= 0.0:
			_stop_walking()
			return
		var dir: Vector2 = to_target.normalized()
		velocity = dir * WALK_SPEED
		_set_move_facing(dir)
		_update_anim(true)
		move_and_slide()
	else:
		_idle_time_left -= delta
		if _idle_time_left <= 0.0:
			_pick_new_target()


## Called by the player. Stop, face the caller, run dialogue, resume after 1 s.
func interact(by: Node2D) -> void:
	_talking = true
	_walking = false
	velocity = Vector2.ZERO
	var d: Vector2 = by.global_position - global_position
	if absf(d.x) > absf(d.y):
		_facing = "side"
		_flip = d.x > 0.0
	else:
		_facing = "down" if d.y > 0.0 else "up"
		_flip = false
	_update_anim(false)

	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		_on_dialogue_finished()
		return
	ui.show_dialogue(display_name, dialogue)
	if not ui.is_connected("dialogue_finished", _on_dialogue_finished):
		ui.connect("dialogue_finished", _on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished() -> void:
	# Stay put for a moment, then the wander AI takes over again.
	_talking = false
	_walking = false
	_idle_time_left = RESUME_DELAY


func _pick_new_target() -> void:
	var ang: float = _rng.randf_range(0.0, TAU)
	var dist: float = _rng.randf_range(_wander_radius * 0.3, _wander_radius)
	_target = _home + Vector2(cos(ang), sin(ang)) * dist
	var travel: float = (_target - global_position).length()
	# Safety cap: if blocked by walls, give up instead of walking in place.
	_walk_time_left = travel / WALK_SPEED * 2.0 + 1.0
	_walking = true


func _update_name_tag() -> void:
	if _name_label == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var show_name: bool = player != null and is_instance_valid(player) \
			and player.global_position.distance_to(global_position) <= NAME_RANGE
	if _name_label.visible != show_name:
		_name_label.visible = show_name


func _stop_walking() -> void:
	_walking = false
	velocity = Vector2.ZERO
	_idle_time_left = _rng.randf_range(IDLE_MIN, IDLE_MAX)
	_update_anim(false)


func _set_move_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing = "side"
		_flip = dir.x > 0.0
	else:
		_facing = "down" if dir.y > 0.0 else "up"
		_flip = false


func _apply_facing_name(f: String) -> void:
	match f:
		"left", "side":
			_facing = "side"
			_flip = false
		"right":
			_facing = "side"
			_flip = true
		"up":
			_facing = "up"
			_flip = false
		_:
			_facing = "down"
			_flip = false


func _update_anim(moving: bool) -> void:
	var anim: String = ("walk_" if moving else "idle_") + _facing
	if _sprite.animation != StringName(anim) or not _sprite.is_playing():
		_sprite.play(anim)
	# Sheets face LEFT on side frames (verified); flip when facing right.
	_sprite.flip_h = _flip and _facing == "side"
