class_name SheetAnim
## Factory for SpriteFrames built from the packs' verified sheet geometries.
## See ASSET_MANIFEST.md. Animations produced: idle_side / idle_down / idle_up
## and walk_side / walk_down / walk_up. Side animations face LEFT.

const SZADI_FRAME := Vector2i(32, 48)
const SZADI_DIR_ROW := {"side": 0, "down": 1, "up": 2}
const MAID_DIR := ["down", "side", "up"]


static func make_szadi_frames(sheet_path: String, variant: int) -> SpriteFrames:
	var tex: Texture2D = load(sheet_path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir_name: String in SZADI_DIR_ROW:
		var row: int = variant * 3 + SZADI_DIR_ROW[dir_name]
		_add_atlas_anim(sf, tex, "idle_" + dir_name, row, 0, 4, 5.0)
		_add_atlas_anim(sf, tex, "walk_" + dir_name, row, 4, 4, 8.0)
	return sf


static func make_maid_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var base := "res://assets/art/characters/tavern_maid/"
	for d: String in MAID_DIR:
		_add_strip_anim(sf, base + "idle_" + d + ".png", "idle_" + d, 4, 5.0)
		_add_strip_anim(sf, base + "walk_" + d + ".png", "walk_" + d, 6, 8.0)
	return sf


## LPC 4-directional 64x64 class sheets (assets/art/chars/lpc/<class>/walk.png).
## Rows: up=0, left=1, down=2, right=3. To match the game's 3-dir + flip_h
## convention (side faces LEFT), "side" uses the LEFT row and player.gd flips
## for right. idle_* = walk frame 0 (standing pose). Weapon is baked into the
## sheet, so no separate weapon overlay for LPC classes.
const LPC_FRAME := 64
const LPC_ROW := {"up": 0, "side": 1, "down": 2}


static func make_lpc_frames(class_dir: String) -> SpriteFrames:
	var tex: Texture2D = load(class_dir + "walk.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	if tex == null:
		return sf
	var cols: int = int(tex.get_width() / LPC_FRAME)
	for dir_name: String in LPC_ROW:
		var row: int = LPC_ROW[dir_name]
		_add_lpc_anim(sf, tex, "idle_" + dir_name, row, 0, 1, 4.0)
		_add_lpc_anim(sf, tex, "walk_" + dir_name, row, 0, cols, 10.0)
	return sf


static func _add_lpc_anim(sf: SpriteFrames, tex: Texture2D, anim: String, row: int, col0: int, count: int, fps: float) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, true)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(
			Vector2(float((col0 + i) * LPC_FRAME), float(row * LPC_FRAME)),
			Vector2(float(LPC_FRAME), float(LPC_FRAME)))
		sf.add_frame(anim, at)


static func _add_atlas_anim(sf: SpriteFrames, tex: Texture2D, anim: String, row: int, col0: int, count: int, fps: float) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, true)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(
			Vector2(float((col0 + i) * SZADI_FRAME.x), float(row * SZADI_FRAME.y)),
			Vector2(SZADI_FRAME))
		sf.add_frame(anim, at)


static func _add_strip_anim(sf: SpriteFrames, path: String, anim: String, count: int, fps: float) -> void:
	var tex: Texture2D = load(path)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, true)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(float(i * 64), 0.0), Vector2(64.0, 64.0))
		sf.add_frame(anim, at)
