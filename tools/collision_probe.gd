extends SceneTree
## BLUEPRINT_99 runtime collision probe (headless). Proves a player-shaped
## CharacterBody2D (collision_mask = 1, like scripts/player.gd) is BLOCKED by a
## ZoneBuilder footprint StaticBody2D (a "well", circle r16 on layer 1) and is
## FREE over open ground (a decal class = no collider). ASCII prints only.
##
## Run:  Godot_console.exe --headless --script res://tools/collision_probe.gd

var _n := 0
var _p: CharacterBody2D = null
var _blocked := false
var _free := false


func _init() -> void:
	physics_frame.connect(_on_phys)


func _on_phys() -> void:
	_n += 1
	match _n:
		1:
			var world := Node2D.new()
			get_root().add_child(world)
			# A solid "well" footprint (static_footprint kind) built IDENTICALLY
			# to ZoneBuilder._foot's static-circle branch: StaticBody2D on the
			# world layer (1), CircleShape r16. (Inlined so the probe does not
			# drag in ZoneBuilder's autoload deps under --script.)
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var bcs := CollisionShape2D.new()
			var bc := CircleShape2D.new()
			bc.radius = 16.0
			bcs.shape = bc
			body.add_child(bcs)
			body.position = Vector2.ZERO
			world.add_child(body)
			_p = CharacterBody2D.new()
			_p.collision_layer = 2          # player layer (player.gd:236)
			_p.collision_mask = 1           # collides with world layer 1 (player.gd:237)
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = 8.0
			cs.shape = c
			_p.add_child(cs)
			_p.position = Vector2(-40.0, 0.0)   # just left of the well
			world.add_child(_p)
		3:
			# walk RIGHT into the well -> must be stopped
			var col := _p.move_and_collide(Vector2(48.0, 0.0))
			_blocked = col != null
			_p.position = Vector2(400.0, 400.0)  # open ground (a decal = no body)
		5:
			var col2 := _p.move_and_collide(Vector2(48.0, 0.0))
			_free = col2 == null
			print("PROBE well_blocks_player=%s  open_ground_free=%s"
					% [str(_blocked), str(_free)])
			print("PROBE RESULT: %s" % ("PASS" if (_blocked and _free) else "FAIL"))
			quit()
