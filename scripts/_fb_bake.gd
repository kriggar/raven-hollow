extends Node2D
## VFX PARTICLE-BAKE HARNESS (procedural fireball -> alpha PNG frames).
## Renders the procedural molten-core fireball (FBBakeCore) into a transparent 64x64
## SubViewport, pipes it through the vfx_palettize shader in a second transparent
## SubViewport (posterize to the 12-colour fire ramp + hard-alpha binarise), and
## captures FRAMES evenly-spaced phase steps to alpha PNGs -> crisp-by-construction.
## Run WINDOWED (headless cannot screenshot / render viewports reliably):
##   "$GODOT" res://scenes/_fb_bake.tscn
## Optional: RH_FB_GPU=1 adds a live GPUParticles2D ember layer (default off = the
## fully deterministic, guaranteed-seamless procedural bake).

const CELL := 64
const FRAMES := 12
const VIEW := 576          # windowed preview size (9x upscale of 64)

# RH_FB_MODE=dir -> directional/comet variant into raw_dir/; else radial spin into raw/
var _mode := 0
var _out_dir := "res://_screens/fb_particle/raw"

var _render_vp: SubViewport
var _palette_vp: SubViewport
var _core: FBBakeCore
var _use_gpu := false


func _ready() -> void:
	_use_gpu = OS.get_environment("RH_FB_GPU") == "1"
	if OS.get_environment("RH_FB_MODE") == "dir":
		_mode = 1
		_out_dir = "res://_screens/fb_particle/raw_dir"
	RenderingServer.set_default_clear_color(Color(0.05, 0.045, 0.06))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var win := get_window()
	win.size = Vector2i(VIEW, VIEW)

	# --- render viewport: the raw procedural fireball on a transparent bg ---
	_render_vp = SubViewport.new()
	_render_vp.size = Vector2i(CELL, CELL)
	_render_vp.transparent_bg = true
	_render_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_render_vp.disable_3d = true
	_render_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_render_vp)

	_core = FBBakeCore.new()
	_core.mode = _mode
	_render_vp.add_child(_core)

	if _use_gpu:
		_add_gpu_flame(_core)

	# --- palette viewport: posterize + hard-alpha the render, still transparent ---
	_palette_vp = SubViewport.new()
	_palette_vp.size = Vector2i(CELL, CELL)
	_palette_vp.transparent_bg = true
	_palette_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_palette_vp.disable_3d = true
	_palette_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_palette_vp)

	var pmat := ShaderMaterial.new()
	pmat.shader = load("res://scripts/vfx_palettize.gdshader")
	var pspr := Sprite2D.new()
	pspr.centered = false
	pspr.texture = _render_vp.get_texture()
	pspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pspr.material = pmat
	_palette_vp.add_child(pspr)

	# --- live windowed preview so an inspection screenshot shows the result ---
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.055, 0.07)
	bg.size = Vector2(VIEW, VIEW)
	add_child(bg)
	var view_spr := Sprite2D.new()
	view_spr.texture = _palette_vp.get_texture()
	view_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view_spr.centered = false
	view_spr.scale = Vector2(9, 9)
	add_child(view_spr)

	await _capture_loop()
	get_tree().quit()


func _capture_loop() -> void:
	# warm the viewports (and GPU particles, if any) before the first grab
	for _i in 6:
		await RenderingServer.frame_post_draw
	if _use_gpu:
		await get_tree().create_timer(0.8).timeout   # let particle stream reach steady state

	for i in FRAMES:
		_core.set_phase(float(i) / float(FRAMES))
		if _use_gpu:
			await get_tree().create_timer(1.0 / float(FRAMES)).timeout
		# let the phase change propagate render_vp -> palette_vp before grabbing
		for _j in 3:
			await RenderingServer.frame_post_draw
		var img := _palette_vp.get_texture().get_image()
		var path := "%s/frame_%02d.png" % [_out_dir, i]
		img.save_png(path)
		print("[fb_bake] saved ", path, " ", img.get_size())

	print("[fb_bake] DONE ", FRAMES, " frames -> ", _out_dir)


func _add_gpu_flame(parent: Node2D) -> void:
	# subtle continuous alpha flame licks; captured across one lifetime so the
	# aggregate is periodic (loop-safe). Alpha-blend (NOT additive) keeps the
	# transparent-viewport capture clean.
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var c := 2.5
	for y in 6:
		for x in 6:
			var dd := Vector2(x - c, y - c).length() / 3.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - dd, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)

	var p := GPUParticles2D.new()
	p.position = Vector2(32, 32)
	p.amount = 36
	p.lifetime = 1.0
	p.preprocess = 1.0
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.texture = tex
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 10.0
	m.spread = 180.0
	m.gravity = Vector3(0, -40, 0)
	m.initial_velocity_min = 8.0
	m.initial_velocity_max = 26.0
	m.scale_min = 0.6
	m.scale_max = 1.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([FBBakeCore.P2, FBBakeCore.P5, Color(FBBakeCore.P7.r, FBBakeCore.P7.g, FBBakeCore.P7.b, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	parent.add_child(p)
	p.emitting = true
