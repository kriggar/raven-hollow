extends Node2D
## Rogue-kit VFX showcase (BACKLOG #83/#56). Plays all six ComfyUI-generated rogue spell
## VFX through FXLib in a 3x2 grid on a dark gothic stage, then screenshots to RH_SHOT
## (default _screens/rogue_kit/godot/showcase.png) and quits. Proves the sheets load, cut
## clean and animate in-engine. Run WINDOWED:
##   RH_SHOT="_screens/rogue_kit/godot/showcase.png" GODOT res://scenes/rogue_kit_showcase.tscn

const CELLS := [
	{"fx": "backstab", "label": "Backstab"},
	{"fx": "venom_cloud", "label": "Poison Blade"},
	{"fx": "fan_of_knives", "label": "Fan of Knives"},
	{"fx": "shroud", "label": "Vanish"},
	{"fx": "shadowstep", "label": "Shadowstep"},
	{"fx": "deathmark", "label": "Deathmark"},
]
const COLS := 3
const VIEW := Vector2(640.0, 360.0)     # fixed project viewport (canvas_items stretch)
const CELLW := 200.0
const CELLH := 150.0
const OX := 20.0
const OY := 36.0

var _t := 0.0
var _shot := false


func _cell_center(i: int) -> Vector2:
	var col := i % COLS
	var row := i / COLS
	return Vector2(OX + col * CELLW + CELLW * 0.5, OY + row * CELLH + CELLH * 0.42)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.11)
	bg.size = VIEW
	bg.z_index = -100
	add_child(bg)
	var title := Label.new()
	title.text = "RAVEN HOLLOW — ROGUE SPELL KIT"
	title.position = Vector2(OX, 8.0)
	title.add_theme_color_override("font_color", Color(0.92, 0.85, 0.55))
	add_child(title)
	var sub := Label.new()
	sub.text = "venom · shadow · steel"
	sub.position = Vector2(VIEW.x - 150.0, 10.0)
	sub.add_theme_color_override("font_color", Color(0.55, 0.62, 0.42))
	add_child(sub)
	for i in CELLS.size():
		var lbl := Label.new()
		lbl.text = str(CELLS[i]["label"])
		lbl.position = _cell_center(i) + Vector2(-52.0, CELLH * 0.32)
		lbl.add_theme_color_override("font_color", Color(0.80, 0.76, 0.82))
		add_child(lbl)
	_burst()


func _burst() -> void:
	for i in CELLS.size():
		FXLib.play(str(CELLS[i]["fx"]), self, _cell_center(i), {"scale": 1.35, "duration": 1.2})


func _process(delta: float) -> void:
	_t += delta
	# re-trigger the one-shots so the grid keeps animating while we settle on a good frame
	if int(_t / 0.55) != int((_t - delta) / 0.55):
		_burst()
	if not _shot and _t > 0.86:      # ~mid-animation of a fresh burst
		_shot = true
		_capture()
		get_tree().quit(0)


func _capture() -> void:
	var path := OS.get_environment("RH_SHOT")
	if path.is_empty():
		path = "res://_screens/rogue_kit/godot/showcase.png"
	if not path.begins_with("res://") and not path.begins_with("/") and path.find(":") < 0:
		path = "res://" + path
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_warning("showcase capture failed %d -> %s" % [err, path])
	else:
		print("showcase -> ", path)
