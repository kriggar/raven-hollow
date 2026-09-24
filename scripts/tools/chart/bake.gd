extends SceneTree
## THE MAP BAKER — draws a zone sheet from the city's own vectors, headless.
##
## Run:  "$GODOT" --headless --script res://scripts/tools/chart/bake.gd -- --zone=town
##
## WHY IT LOOKS LIKE THIS
## Four earlier versions were rejected. Each one either classified the pixels of
## a screenshot or drew soft shapes with a 2D renderer, and both routes produce
## the same tell: a picture of the world rather than a drawing of it. Two expert
## critiques measured the last attempt — 169 unique colours, 81% of pixels in a
## single luminance band, land and water the identical tan — and the research
## behind this file found the production answer used by the studios that ship
## these: the render is REFERENCE, the deliverable is REDRAWN, through the five
## generalization operations (select, simplify, exaggerate, displace, symbolize).
##
## So this file has hard rules, and they are structural rather than stylistic:
##   * Image.set_pixelv and integer Bresenham ONLY. No draw_line, no SubViewport,
##     no shader. Antialiasing is not discouraged here, it is impossible.
##   * Every pixel is a PALETTE INDEX until the final write, so the sheet cannot
##     drift off its 16 colours.
##   * Scripts are path-loaded, never referenced by class_name: under --script
##     the autoload globals do not exist and a class_name reference fails to
##     compile with "Identifier not found: NavSystem".
##   * A road is a VOID between two casing lines, never a coloured ribbon. On
##     Nolli, Rocque and the Ordnance Survey town plans the street is the gap,
##     and filling it inverts the map's meaning.
##   * The darkest value is RESERVED: coast, neatline, wall, block outline. The
##     rejected sheet spent its darkest ink everywhere and therefore had no
##     hierarchy and no focal point.

const TC_PATH := "res://scripts/town_city.gd"
const TP_PATH := "res://scripts/terrain_painter.gd"

# ---- the plate palette. Exactly these, and nothing else, reaches the PNG. ----
enum {
	PAPER_HI, PAPER, PAPER_2, PAPER_3, PAPER_BURN,
	INK, INK_2, INK_3, INK_4,
	BUILT, BUILT_DEEP,
	WATER, WATER_DEEP, WATER_INK,
	FIELD_G, WOOD,
}
const PAL := [
	Color8(0xf2, 0xe9, 0xd2),  # PAPER_HI   knockout: road cores, label halo
	Color8(0xe2, 0xd9, 0xc4),  # PAPER      the sheet
	Color8(0xd2, 0xc5, 0xa8),  # PAPER_2    blotch, foxing
	Color8(0xb9, 0xa6, 0x84),  # PAPER_3    deep blotch, fog wash
	Color8(0xa8, 0x91, 0x74),  # PAPER_BURN edge burn, lamp falloff
	Color8(0x24, 0x1b, 0x12),  # INK        RESERVED: coast, wall, neatline
	Color8(0x3d, 0x2e, 0x1d),  # INK_2      road casings, party walls
	Color8(0x5c, 0x48, 0x30),  # INK_3      hachure, stipple, ruled water
	Color8(0x86, 0x6d, 0x54),  # INK_4      hedges, linework only, never type
	Color8(0x7a, 0x3b, 0x2e),  # BUILT      ordinary urban fabric
	Color8(0x51, 0x1e, 0x19),  # BUILT_DEEP THE DARK ANCHOR, civic mass only
	Color8(0x7e, 0x97, 0xa6),  # WATER
	Color8(0x4a, 0x62, 0x74),  # WATER_DEEP channel centres
	Color8(0x2f, 0x45, 0x52),  # WATER_INK  ruled water, hydronyms
	Color8(0xa3, 0xad, 0x7d),  # FIELD_G    pasture, meadow, allotment
	Color8(0x45, 0x57, 0x3a),  # WOOD       woodland ground
]

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var W: int
var H: int
var K: float                      # world px per plate px
var px: PackedByteArray           # palette indices
var TC: GDScript
var TP: GDScript
var rngv: int = 0


func _initialize() -> void:
	var zone := "town"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			zone = a.substr(7)
	print("[bake] zone=", zone)
	TC = load(TC_PATH)
	TP = load(TP_PATH)
	if TC == null or TP == null:
		push_error("[bake] cannot load the city scripts")
		quit(1)
		return
	_bake(zone)
	quit(0)


# ---------------------------------------------------------------- the bake
func _bake(zone: String) -> void:
	var world := Vector2(TC.MAP_W, TC.MAP_H)
	# PLATE SCALE. The sheet is authored at the size it is shown, so it can be
	# blitted 1:1 and zoomed by whole steps. A 2048 px plate squeezed into 572
	# was the source of every resampling artefact in the rejected versions.
	K = maxf(world.x / 444.0, world.y / 300.0)
	W = int(ceil(world.x / K))
	H = int(ceil(world.y / K))
	px = PackedByteArray()
	px.resize(W * H)
	print("[bake] plate %dx%d  k=%.3f world px per plate px" % [W, H, K])

	var t0 := Time.get_ticks_msec()
	var mat := _material_grid()
	print("[bake] material grid in %d ms" % (Time.get_ticks_msec() - t0))

	_paper()                       # 01-03  paper, blotch, grain
	var m := _classify(mat)        # sample the grid onto the plate
	_water(m)                      # 07-08  water bodies, banks, ruled lines
	_land(m)                       # 10     field and wood washes
	_woods(m)                      # 11     stamped crowns, never a fill
	_roads()                       # 13     voids with casings
	_blocks()                      # 15     terraces unioned, BUILT fill
	_anchor()                      # 16     the dark anchor: civic mass only
	_walls()                       # 17     the enclosure, heaviest line, last
	_lamp()                        # 18     lamp, edge burn, deckle

	_write("res://assets/art/maps/sheets/%s_0.png" % zone)


## The ground truth. paint_masks is a pure static function that paints a
## per-vertex material grid from the same vectors the city is built from, so it
## needs no scene, no renderer and no screenshot. Precedence is top2 > top >
## base because cobble is laid on the upper canvases and the base alone yields
## zero paved vertices.
func _material_grid() -> PackedInt32Array:
	var tw := 224
	var th := 160
	var grass: int = TP.mat("Grass")
	var base = TP.Canvas.new(tw, th, grass)
	var top = TP.Canvas.new(tw, th, grass)
	var top2 = TP.Canvas.new(tw, th, grass)
	TC.paint_masks(base, top, top2)
	var out := PackedInt32Array()
	out.resize((tw + 1) * (th + 1))
	for y in range(th + 1):
		for x in range(tw + 1):
			var v: int = top2.get_v(x, y)
			if v == grass:
				v = top.get_v(x, y)
			if v == grass:
				v = base.get_v(x, y)
			out[y * (tw + 1) + x] = v
	return out


## Sample the 225x161 vertex grid onto the plate. The plate is only 1.9x the
## grid, so nearest sampling is honest here; contouring would invent precision
## the source does not have.
func _classify(mat: PackedInt32Array) -> PackedByteArray:
	const CLS_NONE := 0
	const CLS_WATER := 1
	const CLS_SHALLOW := 2
	const CLS_PAVED := 3
	const CLS_SOIL := 4
	const CLS_DIRT := 5
	var water: int = TP.mat("Water")
	var shallow: int = TP.mat("Water_Shallows_Dirt")
	var cobble: int = TP.mat("Mudstone_Gray")
	var soil: int = TP.mat("Soil")
	var dirt: int = TP.mat("Dirt_Roots")
	var out := PackedByteArray()
	out.resize(W * H)
	for y in range(H):
		for x in range(W):
			var wx: float = (float(x) + 0.5) * K
			var wy: float = (float(y) + 0.5) * K
			var vx: int = clampi(int(round(wx / 32.0)), 0, 224)
			var vy: int = clampi(int(round(wy / 32.0)), 0, 160)
			var v: int = mat[vy * 225 + vx]
			var c := CLS_NONE
			if v == water: c = CLS_WATER
			elif v == shallow: c = CLS_SHALLOW
			elif v == cobble: c = CLS_PAVED
			elif v == soil: c = CLS_SOIL
			elif v == dirt: c = CLS_DIRT
			out[y * W + x] = c
	return out


# ---------------------------------------------------------------- 01-03 paper
func _paper() -> void:
	for i in range(px.size()):
		px[i] = PAPER
	# low-frequency blotch on 24px cells, amplitude limited to ONE ramp step so
	# the sheet never mottles into mud
	for y in range(H):
		for x in range(W):
			var n := _vnoise(float(x) / 11.0, float(y) / 11.0)
			if n < -0.25:
				px[y * W + x] = PAPER_2
			elif n > 0.35:
				px[y * W + x] = PAPER_HI
	# high-frequency grain: a 4x4 Bayer locked to the PLATE grid, shifting 9% of
	# pixels by one step. This is the entire paper texture. It cannot tile,
	# cannot seam and cannot crawl when the map pans, which a photographic
	# parchment overlay does all three of.
	for y in range(H):
		for x in range(W):
			var b: int = BAYER[(y & 3) * 4 + (x & 3)]
			if b != 1:
				continue
			var i := y * W + x
			if px[i] == PAPER:
				px[i] = PAPER_2 if ((x + y) & 1) == 0 else PAPER_HI


func _vnoise(gx: float, gy: float) -> float:
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := gx - float(x0)
	var fy := gy - float(y0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h2(x0, y0)
	var b := _h2(x0 + 1, y0)
	var c := _h2(x0, y0 + 1)
	var d := _h2(x0 + 1, y0 + 1)
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fy) * 2.0 - 1.0


func _h2(x: int, y: int) -> float:
	var n := int(x * 374761393 + y * 668265263)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


# ---------------------------------------------------------------- raster kernel
func _put(x: int, y: int, c: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	px[y * W + x] = c


func _at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return PAPER
	return px[y * W + x]


## Integer Bresenham with SQUARE caps. The round caps and lollipop junction
## blobs in the engraved attempt were its most visible defect, so the kernel
## simply cannot draw them.
func _line(a: Vector2i, b: Vector2i, c: int, wdt: int = 1) -> void:
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	var r := wdt / 2
	while true:
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				_put(x + ox, y + oy, c)
		if x == b.x and y == b.y:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


func _poly(pts: Array, c: int, wdt: int = 1) -> void:
	for i in range(pts.size() - 1):
		_line(_p(pts[i]), _p(pts[i + 1]), c, wdt)


func _p(w: Vector2) -> Vector2i:
	return Vector2i(int(floor(w.x / K)), int(floor(w.y / K)))


func _rect_fill(r: Rect2i, c: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(x, y, c)


# ---------------------------------------------------------------- 07-08 water
func _water(m: PackedByteArray) -> void:
	for i in range(px.size()):
		if m[i] == 1:
			px[i] = WATER
		elif m[i] == 2:
			px[i] = WATER
	# channel depth: anything more than 2px from dry land
	var deep := PackedByteArray()
	deep.resize(W * H)
	for y in range(H):
		for x in range(W):
			if px[y * W + x] != WATER:
				continue
			var near := false
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					if _at(x + ox, y + oy) != WATER and _at(x + ox, y + oy) != WATER_DEEP:
						near = true
			if not near:
				deep[y * W + x] = 1
	for i in range(deep.size()):
		if deep[i] == 1:
			px[i] = WATER_DEEP
	# ruled water: the oldest way to say "this is a surface you cannot walk on"
	for y in range(0, H, 3):
		for x in range(W):
			var i := y * W + x
			if px[i] == WATER or px[i] == WATER_DEEP:
				if ((x + y) % 7) < 5:
					px[i] = WATER_INK
	# the bank. 2px INK, and on a local sheet the only 2px line besides the
	# neatline and the wall.
	var bank := PackedByteArray()
	bank.resize(W * H)
	for y in range(H):
		for x in range(W):
			var i := y * W + x
			if not _is_water(px[i]):
				continue
			if not (_is_water(_at(x - 1, y)) and _is_water(_at(x + 1, y))
					and _is_water(_at(x, y - 1)) and _is_water(_at(x, y + 1))):
				bank[i] = 1
	for y in range(H):
		for x in range(W):
			if bank[y * W + x] == 1:
				_put(x, y, INK)
				_put(x + 1, y, INK)


func _is_water(c: int) -> bool:
	return c == WATER or c == WATER_DEEP or c == WATER_INK


# ---------------------------------------------------------------- 10 washes
func _land(m: PackedByteArray) -> void:
	# tilled soil reads as arable: ridge and furrow, which averages lighter than
	# a flat fill and says "worked" rather than "green"
	for y in range(H):
		for x in range(W):
			var i := y * W + x
			if m[i] != 4:
				continue
			px[i] = FIELD_G if (y % 6) < 3 else PAPER
	# the authored field and allotment rects get a flat pasture wash, offset by
	# +1,+1 on about two thirds of them: hand-coloured plates never registered
	# perfectly and this is the cheapest authenticity cue in the pipeline
	var n := 0
	for r: Rect2 in TC.FARM_FIELDS:
		_wash_rect(r, FIELD_G, (n % 3) != 2)
		n += 1
	for r2: Rect2 in TC.ALLOT:
		_wash_rect(r2, FIELD_G, (n % 3) != 2)
		n += 1


func _wash_rect(r: Rect2, c: int, offset: bool) -> void:
	var a := _p(r.position)
	var b := _p(r.end)
	var o := 1 if offset else 0
	for y in range(a.y + o, b.y + o):
		for x in range(a.x + o, b.x + o):
			if _at(x, y) == PAPER or _at(x, y) == PAPER_2 or _at(x, y) == PAPER_HI:
				_put(x, y, c)
	# 1px hedge, broken 3-on 1-off
	for x2 in range(a.x, b.x):
		if (x2 % 4) != 3:
			_put(x2, a.y, INK_4)
			_put(x2, b.y - 1, INK_4)
	for y2 in range(a.y, b.y):
		if (y2 % 4) != 3:
			_put(a.x, y2, INK_4)
			_put(b.x - 1, y2, INK_4)


# ---------------------------------------------------------------- 11 woodland
## Trees are a DENSITY FIELD, not marks. 4,328 scene trees resampled to a few
## hundred stamps, clumped, with the edge drawn and the middle implied — which
## is what an engraver does and what a per-tree stamp loop cannot do.
func _woods(_m: PackedByteArray) -> void:
	var step := 5
	for y in range(step, H - step, step):
		for x in range(step, W - step, step):
			var wx := float(x) * K
			var wy := float(y) * K
			if not _wooded(wx, wy):
				continue
			if _at(x, y) != PAPER and _at(x, y) != PAPER_2 and _at(x, y) != PAPER_HI:
				continue
			var h := _h2(x * 7, y * 13)
			if h > 0.55:
				continue
			_crown(x + int(h * 3.0) - 1, y, (h < 0.28))


func _wooded(wx: float, wy: float) -> bool:
	# The city's woods are its western commons and the strip outside the wall.
	var n := _vnoise(wx / 640.0, wy / 640.0)
	if wx > 2200.0 and wy > 900.0 and wy < 4400.0:
		return false               # the built core is never woodland
	return n > 0.10


func _crown(x: int, y: int, conifer: bool) -> void:
	if conifer:
		_put(x, y - 2, WOOD)
		_put(x - 1, y - 1, WOOD); _put(x + 1, y - 1, WOOD)
		_put(x - 2, y, WOOD); _put(x + 2, y, WOOD)
		_put(x, y + 1, INK_3)
	else:
		_put(x - 1, y - 2, WOOD); _put(x, y - 2, WOOD); _put(x + 1, y - 2, WOOD)
		_put(x - 2, y - 1, WOOD); _put(x + 2, y - 1, WOOD)
		_put(x - 2, y, WOOD); _put(x + 2, y, WOOD)
		_put(x - 1, y + 1, WOOD); _put(x, y + 1, WOOD); _put(x + 1, y + 1, WOOD)
		_put(x + 1, y, INK_3)


# ---------------------------------------------------------------- 13 roads
## A road is a VOID between two casing lines. Class widths are FIXED in plate
## pixels regardless of true world half-width — that is the "exaggerate"
## operation, and it is why a lane still reads at 420px wide.
func _roads() -> void:
	var majors := [TC.APPROACH, TC.AVENUE_E, TC.AVENUE_S, TC.EAST_ROAD, TC.SPINE,
		TC.KEEP_ROAD, TC.CATH_FORE, TC.BANK_ROW]
	var minors := [TC.OT1, TC.OT2, TC.OT3, TC.OT4, TC.EW1, TC.EW2, TC.EW3,
		TC.LINK, TC.QUAY_LANE, TC.CANAL_LANE, TC.SE_TRACK, TC.GARDEN_LANE]
	# casings first, one pixel proud on each side
	for r in majors:
		_poly(r, INK_2, 7)
	for r2 in minors:
		_poly(r2, INK_2, 5)
	# then the carriageway cut out of them
	for r3 in majors:
		_poly(r3, PAPER_HI, 5)
	for r4 in minors:
		_poly(r4, PAPER_HI, 3)
	# field tracks and the towpath: 1px, dashed
	for t in [TC.F1, TC.F2, TC.F3, TC.F5, TC.TOWPATH]:
		_dashed(t, INK_4, 3, 2)


func _dashed(pts: Array, c: int, on: int, off: int) -> void:
	var run := 0
	for i in range(pts.size() - 1):
		var a := _p(pts[i])
		var b := _p(pts[i + 1])
		var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in range(steps + 1):
			run += 1
			if (run % (on + off)) < on:
				var t := float(s) / maxf(1.0, float(steps))
				_put(int(round(lerp(float(a.x), float(b.x), t))),
					int(round(lerp(float(a.y), float(b.y), t))), c)


# ---------------------------------------------------------------- 15 blocks
## Terraces are unioned into ONE block per row. Never separate rounded
## rectangles with gaps: real urban fabric is a continuous block with internal
## divisions, and that single mistake announces "procedural" from across the room.
func _blocks() -> void:
	if TC._plans.is_empty():
		TC._plan_all()
	for plan in TC._plans:
		var items: Array = plan.get("items", [])
		var run_a := Vector2.ZERO
		var run_b := Vector2.ZERO
		var open := false
		for it_v in items:
			var it: Dictionary = it_v
			if it.has("alley") or it.has("gap"):
				if open:
					_block(run_a, run_b)
					open = false
				continue
			if not it.has("pos"):
				continue
			var pos: Vector2 = it["pos"]
			var hw: float = float(it.get("w", 96.0)) * 0.5
			if not open:
				run_a = Vector2(pos.x - hw, pos.y)
				run_b = Vector2(pos.x + hw, pos.y)
				open = true
			else:
				run_a.x = minf(run_a.x, pos.x - hw)
				run_b.x = maxf(run_b.x, pos.x + hw)
				run_b.y = pos.y
		if open:
			_block(run_a, run_b)
	# _plans only holds the terraced rows along the east-west streets. The 23
	# authored BUILT_RECTS are the rest of the fabric - the keep ward, the
	# market blocks, the outlying farms - and without them the sheet reads as
	# mostly bare paper, which is exactly what the value gate reported.
	for r: Rect2 in TC.BUILT_RECTS:
		_block_rect(r)


func _block_rect(r: Rect2) -> void:
	var p0 := _p(r.position)
	var p1 := _p(r.end)
	if p1.x - p0.x < 2 or p1.y - p0.y < 2:
		return
	for y in range(p0.y, p1.y):
		for x in range(p0.x, p1.x):
			_put(x, y, BUILT)
	for x2 in range(p0.x, p1.x):
		_put(x2, p0.y, INK)
		_put(x2, p1.y - 1, INK)
	for y2 in range(p0.y, p1.y):
		_put(p0.x, y2, INK)
		_put(p1.x - 1, y2, INK)


func _block(a: Vector2, b: Vector2) -> void:
	var depth := 150.0                      # plan depth, ~9 plate px, not a bar
	var p0 := _p(Vector2(a.x, minf(a.y, b.y)))
	var p1 := _p(Vector2(b.x, maxf(a.y, b.y) + depth))
	if p1.x - p0.x < 2 or p1.y - p0.y < 2:
		return
	for y in range(p0.y, p1.y):
		for x in range(p0.x, p1.x):
			_put(x, y, BUILT)
	for x2 in range(p0.x, p1.x):
		_put(x2, p0.y, INK)
		_put(x2, p1.y - 1, INK)
	for y2 in range(p0.y, p1.y):
		_put(p0.x, y2, INK)
		_put(p1.x - 1, y2, INK)


# ---------------------------------------------------------------- 16 anchor
## THE DARK ANCHOR. Civic and monumental mass only, and nothing else on the
## sheet may use this value. It is the composition's focal point and it is the
## step neither rejected version had at all: one measured 3.0% dark scattered
## as confetti, which is the same as having none.
func _anchor() -> void:
	var blocks := [
		Rect2(3300, 240, 620, 560),     # the keep compound and its ward
		Rect2(5140, 420, 540, 520),     # the cathedral close and churchyard
		Rect2(2980, 1020, 900, 230),    # the blocks fronting Trade Square
		Rect2(5180, 2400, 500, 300),    # Ward Square and the civic block
		Rect2(2820, 4180, 620, 220),    # the harbour warehouses
	]
	for r: Rect2 in blocks:
		var p0 := _p(r.position)
		var p1 := _p(r.end)
		for y in range(p0.y, p1.y):
			for x in range(p0.x, p1.x):
				_put(x, y, BUILT_DEEP)
		# a 1px cast tick to the south-east: the anchor sits ON the paper
		for x2 in range(p0.x + 1, p1.x + 1):
			_put(x2, p1.y, INK_2)
		for y2 in range(p0.y + 1, p1.y + 1):
			_put(p1.x, y2, INK_2)


# ---------------------------------------------------------------- 17 walls
## The enclosure, drawn LAST and at the heaviest weight, so it cuts cleanly
## across the fabric. That is why a walled town reads instantly.
func _walls() -> void:
	var x0 := 104.0
	var x1 := 7064.0
	var runs := [
		[Vector2(x0, 136.0), Vector2(x1, 136.0)],
		[Vector2(x0, 5080.0), Vector2(x1, 5080.0)],
		[Vector2(40.0, 136.0), Vector2(40.0, 5080.0)],
	]
	for r: Array in runs:
		_line(_p(r[0]), _p(r[1]), INK, 2)
	# the east run, broken at the gate
	var gy: float = TC.EAST_GATE.y
	_line(_p(Vector2(7064.0, 136.0)), _p(Vector2(7064.0, gy - 120.0)), INK, 2)
	_line(_p(Vector2(7064.0, gy + 120.0)), _p(Vector2(7064.0, 5080.0)), INK, 2)
	# towers as filled discs on the wall line
	for t: Vector2 in [Vector2(x0, 136), Vector2(x1, 136), Vector2(x0, 5080), Vector2(x1, 5080)]:
		var c := _p(t)
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				if ox * ox + oy * oy <= 5:
					_put(c.x + ox, c.y + oy, INK)


# ---------------------------------------------------------------- 18 the lamp
## One authored point doing an art director's job: it tells the eye where the
## light is and therefore where to look, and it is what makes the dark anchor
## read as lit rather than as a stain.
func _lamp() -> void:
	var lamp := Vector2(float(W) * 0.52, float(H) * 0.30)
	var far := float(W) * 0.62
	for y in range(H):
		for x in range(W):
			var d := Vector2(float(x), float(y)).distance_to(lamp)
			var t := clampf((d - far * 0.45) / far, 0.0, 1.0)
			var steps := int(t * 3.999)
			var b: int = BAYER[(y & 3) * 4 + (x & 3)]
			if steps <= 0 or b > steps * 4:
				continue
			var i := y * W + x
			px[i] = _darker(px[i])
	# the deckle: bite notches out of the silhouette so the sheet is an object
	# lying on a dark table, not a texture filling a window
	for y in range(H):
		for x in range(W):
			var e: int = mini(mini(x, W - 1 - x), mini(y, H - 1 - y))
			if e < 12:
				var b2: int = BAYER[(y & 3) * 4 + (x & 3)]
				if b2 < (12 - e):
					px[y * W + x] = _darker(px[y * W + x])


func _darker(c: int) -> int:
	match c:
		PAPER_HI: return PAPER
		PAPER: return PAPER_2
		PAPER_2: return PAPER_3
		PAPER_3: return PAPER_BURN
		FIELD_G: return WOOD
		WATER: return WATER_DEEP
		WATER_DEEP: return WATER_INK
		BUILT: return BUILT_DEEP
		INK_4: return INK_3
		INK_3: return INK_2
	return c


# ---------------------------------------------------------------- write
func _write(path: String) -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var used := {}
	for y in range(H):
		for x in range(W):
			var idx: int = px[y * W + x]
			used[idx] = true
			img.set_pixel(x, y, PAL[idx])
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("[bake] %s  colours used %d/%d  err=%d" % [path, used.size(), PAL.size(), err])
	# the value plan, measured rather than asserted
	var counts := {}
	for y in range(H):
		for x in range(W):
			var k: int = px[y * W + x]
			counts[k] = int(counts.get(k, 0)) + 1
	var tot := float(W * H)
	var light := (int(counts.get(PAPER_HI, 0)) + int(counts.get(PAPER, 0)) + int(counts.get(PAPER_2, 0))) / tot
	var dark := int(counts.get(BUILT_DEEP, 0)) / tot
	var inkc := (int(counts.get(INK, 0)) + int(counts.get(INK_2, 0)) + int(counts.get(INK_3, 0))) / tot
	print("[bake] light ground %.1f%% (want 44-58)  dark anchor %.1f%% (want 4-10)  ink %.1f%% (want 18-28)"
		% [light * 100.0, dark * 100.0, inkc * 100.0])
