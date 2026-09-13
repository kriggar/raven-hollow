class_name TownCity
## RAVEN HOLLOW CITY — S1 skeleton (design/RAVEN_HOLLOW_CITY.md, BACKLOG #129).
##
## Built by TownBuilder AFTER the village pass on the grown 224x160 map:
##   paint_masks()  — cobbled streets/squares, canals, river, quays into the
##                    TerrainPainter canvases (called from _build_ground_painted)
##   build()        — outer wall ring + towers + the east gate, the keep compound,
##                    the cathedral, canal colliders + bridges, harbor piers/boats,
##                    square dressing (fountain, lamps, benches).
## Kit: LPC Castle Mega Pack dark set (assets/art/world/castle, CC-BY-SA, see
## tools/assets/extract_castle_kit.py) + the coast kit + freekit civic pieces.
## Everything is y-sorted Sprite2D with footprint colliders (Bible rule 11).

const CASTLE := "res://assets/art/world/castle/"
const FREEKIT := "res://assets/art/world/freekit/"
const COAST := "res://assets/art/world/coast/"
const TILE: float = 32.0
const MAP_W: float = 7168.0
const MAP_H: float = 5120.0
const INSET: float = 40.0
const WALL_H: float = 96.0          # wall_face height
const WALL_STEP: float = 64.0

# Key positions (world px) — keep in sync with design/RAVEN_HOLLOW_CITY.md
const OLD_GATE := Vector2(2240.0, 816.0)          # the village's brown gatehouse tunnel
const TRADE_SQ := Vector2(3300.0, 1000.0)
const CATH_SQ := Vector2(5400.0, 900.0)
const KEEP_DOOR := Vector2(3600.0, 900.0)         # keep compound gate (south wall of the compound)
const EAST_GATE_X: float = 6600.0                 # gate in the SOUTH wall → Emberfall Road
const CANAL_A_Y: float = 2150.0                   # east-west canal
const CANAL_B_X: float = 4350.0                   # north-south canal
const CANAL_HALF: float = 48.0
const RIVER_Y: float = 4660.0
const RIVER_HALF: float = 100.0
const QUAY_Y0: float = 4400.0                     # harbor quay band (y0..RIVER_Y-RIVER_HALF)

const WARM := Color(1.0, 0.78, 0.45)


# ============================================================ GROUND MASKS ===
static func paint_masks(base: TerrainPainter.Canvas, top: TerrainPainter.Canvas) -> void:
	var water: int = TerrainPainter.mat("Water")
	var stone: int = TerrainPainter.mat("Stone_Tan")
	var cobble: int = TerrainPainter.mat("Mudstone_Gray")
	var dirt: int = TerrainPainter.mat("Dirt_Roots")

	# --- canals + river (base layer; Water auto-bridges to Shallows)
	base.band([Vector2(2300, CANAL_A_Y), Vector2(MAP_W - 104.0, CANAL_A_Y)], CANAL_HALF, water, 0.0)
	base.band([Vector2(CANAL_B_X, 300), Vector2(CANAL_B_X, RIVER_Y)], CANAL_HALF, water, 0.0)
	base.band([Vector2(0, RIVER_Y), Vector2(MAP_W, RIVER_Y)], RIVER_HALF, water, 10.0)

	# --- stone quays along the canals and the harbor (overlay, keyed edges)
	for off: float in [-(CANAL_HALF + 40.0), CANAL_HALF + 40.0]:
		top.band([Vector2(2300, CANAL_A_Y + off), Vector2(MAP_W - 104.0, CANAL_A_Y + off)], 36.0, stone, 0.0)
		top.band([Vector2(CANAL_B_X + off, 300), Vector2(CANAL_B_X + off, RIVER_Y - RIVER_HALF - 20.0)], 36.0, stone, 0.0)
	top.rect_px(Rect2(2560, QUAY_Y0, 2080, RIVER_Y - RIVER_HALF - QUAY_Y0 + 16.0), stone)

	# --- cobbled streets (overlay)
	var main_w: float = 46.0
	top.band([OLD_GATE, Vector2(2700, 900), TRADE_SQ, Vector2(3900, 1000), Vector2(CANAL_B_X, 1000),
		Vector2(4800, 960), CATH_SQ, Vector2(6000, 1000), Vector2(6400, 1500), Vector2(6560, 2200),
		Vector2(6600, 3000), Vector2(6600, 4400), Vector2(EAST_GATE_X, MAP_H - INSET)], main_w, cobble, 6.0)
	top.band([TRADE_SQ, Vector2(3300, 1500), Vector2(3300, CANAL_A_Y), Vector2(3300, 3200), Vector2(3400, 4400), Vector2(3600, 4560)], main_w, cobble, 6.0)
	top.band([CATH_SQ, Vector2(5400, 1500), Vector2(5400, CANAL_A_Y), Vector2(5400, 3200), Vector2(5400, 4400)], 40.0, cobble, 6.0)
	for sy: float in [2600.0, 3200.0, 3800.0]:
		top.band([Vector2(2400, sy), Vector2(3300, sy), Vector2(4200, sy)], 36.0, cobble, 8.0)
	top.band([Vector2(3800, 2300), Vector2(3800, 4200)], 36.0, cobble, 8.0)
	top.band([Vector2(4500, 3200), Vector2(5400, 3200), Vector2(6600, 3200)], 36.0, cobble, 8.0)
	top.band([Vector2(2600, 4400), Vector2(3400, 4400), Vector2(4300, 4400), Vector2(4700, 4400), Vector2(6600, 4400)], 36.0, cobble, 6.0)
	top.band([KEEP_DOOR, Vector2(3600, 1000)], 40.0, cobble, 0.0)
	# squares
	top.ellipse(TRADE_SQ, 420.0, 280.0, cobble, 16.0)
	top.ellipse(CATH_SQ, 360.0, 240.0, cobble, 14.0)
	top.ellipse(Vector2(3800, 3200), 150.0, 110.0, cobble, 10.0)
	top.ellipse(Vector2(5900, 3200), 170.0, 120.0, cobble, 10.0)
	top.ellipse(Vector2(3600, 600), 300.0, 200.0, cobble, 10.0)   # keep courtyard

	# --- streets stop at the water's edge (bridges carry them across)
	var shallows: int = TerrainPainter.mat("Water_Shallows_Dirt")
	var hub: int = TerrainPainter.hub()
	for vy in range(base.h + 1):
		for vx in range(base.w + 1):
			var m: int = base.get_v(vx, vy)
			if m == water or m == shallows:
				top.set_v(vx, vy, hub)

	# --- field lanes (dirt, base)
	base.band([Vector2(1120, 1445), Vector2(1140, 2200), Vector2(1000, 3000), Vector2(1200, 3800), Vector2(1300, 4300)], 30.0, dirt, 10.0)
	base.band([Vector2(200, 2600), Vector2(1100, 2620), Vector2(2200, 2600)], 28.0, dirt, 10.0)
	base.band([Vector2(2200, 2600), Vector2(2400, 2600)], 28.0, dirt, 6.0)


# =============================================================== STRUCTURES ===
static func build(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	_outer_walls(props, lights)
	_keep(props, lights)
	_cathedral(props, lights)
	_canals(props)
	_bridges(props)
	_harbor(props, lights)
	_squares(props, lights)


# --- walls ------------------------------------------------------------------
## East-west curtain wall: front faces every 64 px, base line at `base_y`,
## with an optional gap (gate) [gap_x0, gap_x1]. Returns nothing; colliders added.
static func _wall_ew(props: Node2D, x0: float, x1: float, base_y: float, gap: Vector2 = Vector2(-1, -1)) -> void:
	var x: float = x0
	var i: int = 0
	while x + WALL_STEP <= x1 + 1.0:
		var cx: float = x + WALL_STEP * 0.5
		if gap.x >= 0.0 and cx > gap.x and cx < gap.y:
			x += WALL_STEP
			i += 1
			continue
		var tex: String = CASTLE + ("wall_face_b.png" if i % 5 == 3 else "wall_face_a.png")
		props.add_child(TownBuilder._sprite(tex, Vector2(cx, base_y), 0.0))
		x += WALL_STEP
		i += 1
	# footprint colliders (split at the gap)
	if gap.x >= 0.0:
		props.add_child(TownBuilder._rect_collider(Vector2((x0 + gap.x) * 0.5, base_y - 14.0), Vector2(gap.x - x0, 28.0), Vector2.ZERO))
		props.add_child(TownBuilder._rect_collider(Vector2((gap.y + x1) * 0.5, base_y - 14.0), Vector2(x1 - gap.y, 28.0), Vector2.ZERO))
	else:
		props.add_child(TownBuilder._rect_collider(Vector2((x0 + x1) * 0.5, base_y - 14.0), Vector2(x1 - x0, 28.0), Vector2.ZERO))


## North-south wall: a 64-wide brick band from y0 (top) to y1 (bottom), ending
## with a parapet face at the south end. `left_x` = west edge of the band.
static func _wall_ns(props: Node2D, left_x: float, y0: float, y1: float) -> void:
	var cx: float = left_x + WALL_STEP * 0.5
	var y: float = y0 + 64.0
	while y < y1 - 32.0:
		props.add_child(TownBuilder._sprite(CASTLE + "wall_band.png", Vector2(cx, y), 0.0))
		y += 64.0
	props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", Vector2(cx, y1), 0.0))
	props.add_child(TownBuilder._sprite(CASTLE + "wall_cren.png", Vector2(cx, y0 + 26.0), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(cx, (y0 + y1) * 0.5), Vector2(WALL_STEP, y1 - y0), Vector2.ZERO))


static func _tower_sq(props: Node2D, pos: Vector2) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + "tower_sq.png", pos, 0.0))
	props.add_child(TownBuilder._rect_collider(pos, Vector2(100.0, 30.0), Vector2(0, -15)))


static func _tower_round(props: Node2D, pos: Vector2, big: bool = false, cone: bool = false) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + ("tower_round_big.png" if big else "tower_round.png"), pos, 0.0))
	if cone:
		var c := TownBuilder._sprite(CASTLE + "roof_cone_dark.png", pos + Vector2(0, -122.0), 0.0)
		c.scale = Vector2(0.5, 0.5)
		props.add_child(c)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(112.0 if big else 56.0, 30.0), Vector2(0, -15)))


## An arched opening in a wall face at `pos` (bottom-center on the wall's base line).
static func _gate_arch(props: Node2D, lights: Node2D, pos: Vector2, lit: bool = true) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", pos, 0.0))
	var arch := TownBuilder._sprite(CASTLE + "gate_arch.png", pos + Vector2(0, 1.0), 0.0)
	props.add_child(arch)
	if lit:
		for dx: float in [-44.0, 44.0]:
			props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", pos + Vector2(dx, -40.0), 0.0))
			lights.add_child(TownBuilder._light(pos + Vector2(dx, -48.0), WARM, 0.6, 80.0))


static func _outer_walls(props: Node2D, lights: Node2D) -> void:
	var x0: float = INSET + 64.0             # walls run between the corner towers
	var x1: float = MAP_W - INSET - 64.0
	var top_base: float = INSET + WALL_H     # 136
	var bot_base: float = MAP_H - INSET      # 5080
	# north + south faces (south face carries the EAST GATE)
	_wall_ew(props, x0, x1, top_base)
	_wall_ew(props, x0, x1, bot_base, Vector2(EAST_GATE_X - 40.0, EAST_GATE_X + 40.0))
	# west + east bands
	_wall_ns(props, INSET, top_base, bot_base - 64.0)
	_wall_ns(props, MAP_W - INSET - WALL_STEP, top_base, bot_base - 64.0)
	# corner towers (round, coned)
	for c: Vector2 in [Vector2(INSET + 64.0, top_base + 8.0), Vector2(MAP_W - INSET - 64.0, top_base + 8.0),
			Vector2(INSET + 64.0, bot_base + 8.0), Vector2(MAP_W - INSET - 64.0, bot_base + 8.0)]:
		_tower_round(props, c, true, true)
	# interval towers on the long faces
	var tx: float = x0 + 448.0
	while tx < x1 - 200.0:
		if absf(tx - EAST_GATE_X) > 160.0:
			_tower_sq(props, Vector2(tx, bot_base + 8.0))
		_tower_sq(props, Vector2(tx, top_base + 8.0))
		tx += 448.0
	var ty: float = top_base + 384.0
	while ty < bot_base - 300.0:
		_tower_round(props, Vector2(INSET + 32.0, ty))
		_tower_round(props, Vector2(MAP_W - INSET - 32.0, ty))
		ty += 384.0
	# THE EAST GATE: arch in the south face, flanked by two square towers
	_gate_arch(props, lights, Vector2(EAST_GATE_X, bot_base))
	_tower_sq(props, Vector2(EAST_GATE_X - 96.0, bot_base + 10.0))
	_tower_sq(props, Vector2(EAST_GATE_X + 96.0, bot_base + 10.0))


# --- the Vigil Keep ---------------------------------------------------------
static func _keep(props: Node2D, lights: Node2D) -> void:
	var x0: float = 2800.0
	var x1: float = 4400.0
	var wall_base: float = KEEP_DOOR.y
	# compound walls: south face with the gate, east/west bands up to the north wall
	_wall_ew(props, x0, x1, wall_base, Vector2(KEEP_DOOR.x - 40.0, KEEP_DOOR.x + 40.0))
	_gate_arch(props, lights, Vector2(KEEP_DOOR.x, wall_base))
	_wall_ns(props, x0 - WALL_STEP, 136.0 + 32.0, wall_base - 64.0)
	_wall_ns(props, x1, 136.0 + 32.0, wall_base - 64.0)
	_tower_sq(props, Vector2(x0 - 32.0, wall_base + 8.0))
	_tower_sq(props, Vector2(x1 + 32.0, wall_base + 8.0))
	# the keep itself against the north wall: a 2-row stone block between two
	# double-height square towers, crenellated top, iron-bound door
	var kb := Vector2(3600.0, 520.0)
	_block(props, kb, 4, 2, "gate_doors.png")
	for dx: float in [-184.0, 184.0]:
		_tower_stack(props, kb + Vector2(dx, 8.0), 2)
	props.add_child(TownBuilder._rect_collider(kb, Vector2(260.0, 30.0), Vector2(0, -15)))
	for dx: float in [-70.0, 60.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", kb + Vector2(dx, -44.0), 0.0))
		lights.add_child(TownBuilder._light(kb + Vector2(dx, -52.0), WARM, 0.6, 85.0))
	# courtyard lamps
	for lp: Vector2 in [Vector2(3380, 760), Vector2(3820, 760)]:
		props.add_child(TownBuilder._lamp_post(lp))
		lights.add_child(TownBuilder._light(lp + Vector2(0, -62), WARM, 0.65, 80.0))


## A stone block `cols` faces wide and `rows` faces tall (64x96 each), bottom-center
## at `base`, crenellated top, optional door piece centred on the bottom row.
static func _block(props: Node2D, base: Vector2, cols: int, rows: int, door: String = "") -> void:
	var w: float = float(cols) * WALL_STEP
	for r in range(rows):
		var by: float = base.y - float(r) * (WALL_H - 4.0)
		for c in range(cols):
			var cx: float = base.x - w * 0.5 + WALL_STEP * (float(c) + 0.5)
			var tex: String = "wall_face_b.png" if (c + r) % 3 == 1 else "wall_face_a.png"
			var piece := TownBuilder._sprite(CASTLE + tex, Vector2(cx, by), 0.0)
			piece.z_index = 0
			# rows above the ground row must y-sort with the ground row (one building)
			piece.position.y = base.y - 0.01 * float(r)
			piece.offset.y -= float(r) * (WALL_H - 4.0)
			props.add_child(piece)
	for c in range(cols):
		var cx2: float = base.x - w * 0.5 + WALL_STEP * (float(c) + 0.5)
		var cap := TownBuilder._sprite(CASTLE + "wall_cren.png", Vector2(cx2, base.y), 0.0)
		cap.position.y = base.y - 0.02
		cap.offset.y -= float(rows) * (WALL_H - 4.0) - 10.0
		props.add_child(cap)
	if door != "":
		props.add_child(TownBuilder._sprite(CASTLE + door, base + Vector2(0, 1.0), 0.0))


## `n` square towers stacked (each 128 tall), bottom-center at `base`; optional cone.
static func _tower_stack(props: Node2D, base: Vector2, n: int, cone: bool = false) -> void:
	for i in range(n):
		var t := TownBuilder._sprite(CASTLE + "tower_sq.png", base, 0.0)
		t.position.y = base.y - 0.01 * float(i)
		t.offset.y -= float(i) * 118.0
		props.add_child(t)
	props.add_child(TownBuilder._rect_collider(base, Vector2(100.0, 30.0), Vector2(0, -15)))


# --- the cathedral ----------------------------------------------------------
static func _cathedral(props: Node2D, lights: Node2D) -> void:
	var cb := Vector2(CATH_SQ.x, 620.0)
	_block(props, cb, 4, 3, "gate_doors.png")
	for dx: float in [-160.0, 160.0]:
		# stone base row, then the gothic lancet tower, then a tall spire
		props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", cb + Vector2(dx, 6.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "gothic_tower.png", cb + Vector2(dx, -90.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "spire_tall.png", cb + Vector2(dx, -282.0), 0.0))
		props.add_child(TownBuilder._rect_collider(cb + Vector2(dx, 6.0), Vector2(60.0, 30.0), Vector2(0, -15)))
	props.add_child(TownBuilder._rect_collider(cb, Vector2(256.0, 30.0), Vector2(0, -15)))
	for dx: float in [-56.0, 56.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", cb + Vector2(dx, -44.0), 0.0))
		lights.add_child(TownBuilder._light(cb + Vector2(dx, -52.0), WARM, 0.6, 85.0))
	# statue of the Vigil in the square + lamps
	props.add_child(TownBuilder._sprite(FREEKIT + "saint_statue.png", CATH_SQ + Vector2(0, 20), 0.0))
	props.add_child(TownBuilder._rect_collider(CATH_SQ + Vector2(0, 20), Vector2(40.0, 16.0), Vector2(0, -8)))
	for lp: Vector2 in [CATH_SQ + Vector2(-260, -140), CATH_SQ + Vector2(260, -140), CATH_SQ + Vector2(-260, 160), CATH_SQ + Vector2(260, 160)]:
		props.add_child(TownBuilder._lamp_post(lp))
		lights.add_child(TownBuilder._light(lp + Vector2(0, -62), WARM, 0.65, 80.0))


# --- canals, bridges, harbor -------------------------------------------------
const BRIDGES_A := [3300.0, 5400.0, 6600.0]      # x of N-S bridges over canal A
const BRIDGES_B := [1000.0, 3200.0, 4400.0]      # y of E-W bridges over canal B

static func _canals(props: Node2D) -> void:
	# canal A (east-west) colliders between bridges
	var xs: Array = [2300.0]
	for bx: float in BRIDGES_A:
		xs.append(bx - 60.0)
		xs.append(bx + 60.0)
	xs.append(MAP_W - 104.0)
	var i: int = 0
	while i + 1 < xs.size():
		var a: float = xs[i]
		var b: float = xs[i + 1]
		if b - a > 8.0 and not (a > CANAL_B_X - 60.0 and a < CANAL_B_X + 60.0):
			props.add_child(TownBuilder._rect_collider(Vector2((a + b) * 0.5, CANAL_A_Y), Vector2(b - a, CANAL_HALF * 2.0 - 8.0), Vector2.ZERO))
		i += 2
	# canal B (north-south)
	var ys: Array = [300.0]
	for by: float in BRIDGES_B:
		ys.append(by - 60.0)
		ys.append(by + 60.0)
	ys.append(RIVER_Y - RIVER_HALF)
	i = 0
	while i + 1 < ys.size():
		var a2: float = ys[i]
		var b2: float = ys[i + 1]
		if b2 - a2 > 8.0:
			props.add_child(TownBuilder._rect_collider(Vector2(CANAL_B_X, (a2 + b2) * 0.5), Vector2(CANAL_HALF * 2.0 - 8.0, b2 - a2), Vector2.ZERO))
		i += 2
	# river
	props.add_child(TownBuilder._rect_collider(Vector2(MAP_W * 0.5, RIVER_Y), Vector2(MAP_W, RIVER_HALF * 2.0 - 10.0), Vector2.ZERO))


static func _bridges(props: Node2D) -> void:
	# N-S plank bridges over canal A (deck + wooden railings on both sides)
	for bx: float in BRIDGES_A:
		for dy: float in [CANAL_A_Y + 92.0, CANAL_A_Y - 2.0]:
			var deck := TownBuilder._sprite(CASTLE + "deck_round.png", Vector2(bx, dy), 0.0)
			deck.z_index = -1
			props.add_child(deck)
			for dx: float in [-46.0, 46.0]:
				props.add_child(TownBuilder._sprite(CASTLE + "railing_wood.png", Vector2(bx + dx, dy + 2.0), 0.0))
		for dx2: float in [-52.0, 52.0]:
			props.add_child(TownBuilder._rect_collider(Vector2(bx + dx2, CANAL_A_Y), Vector2(8.0, 190.0), Vector2.ZERO))
	# E-W plank bridges over canal B (deck + iron railings north and south)
	for by: float in BRIDGES_B:
		for dx3: float in [-48.0, 48.0]:
			var deck2 := TownBuilder._sprite(CASTLE + "deck_round.png", Vector2(CANAL_B_X + dx3, by + 48.0), 0.0)
			deck2.z_index = -1
			props.add_child(deck2)
		for dy: float in [-52.0, 44.0]:
			for dx4: float in [-46.0, 46.0]:
				props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(CANAL_B_X + dx4, by + dy + 18.0), 0.0))
			props.add_child(TownBuilder._rect_collider(Vector2(CANAL_B_X, by + dy + 4.0), Vector2(190.0, 8.0), Vector2.ZERO))


static func _harbor(props: Node2D, lights: Node2D) -> void:
	for px: float in [2900.0, 3500.0, 4100.0]:
		var pier := TownBuilder._sprite(FREEKIT + "pier_planks.png", Vector2(px, RIVER_Y + 20.0), 0.0)
		pier.z_index = -1
		props.add_child(pier)
	var sail := TownBuilder._sprite(COAST + "sailboat.png", Vector2(3230.0, RIVER_Y + 70.0), 0.0)
	props.add_child(sail)
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(2790.0, RIVER_Y + 40.0), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(3760.0, RIVER_Y + 80.0), 0.0))
	for lp: Vector2 in [Vector2(2700, 4520), Vector2(3300, 4520), Vector2(3900, 4520), Vector2(4500, 4520)]:
		props.add_child(TownBuilder._lamp_post(lp))
		lights.add_child(TownBuilder._light(lp + Vector2(0, -62), WARM, 0.65, 80.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "sea_chest.png", Vector2(3000, 4470), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(3560, 4480), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "anchor_large.png", Vector2(4150, 4470), 2.0))


# --- squares ----------------------------------------------------------------
static func _squares(props: Node2D, lights: Node2D) -> void:
	# Trade Square: fountain, eight lamps, four benches
	var f := TownBuilder._sprite(FREEKIT + "fountain.png", TRADE_SQ + Vector2(0, 30), 0.0)
	props.add_child(f)
	props.add_child(TownBuilder._rect_collider(TRADE_SQ + Vector2(0, 30), Vector2(90.0, 30.0), Vector2(0, -15)))
	for a in range(8):
		var ang: float = TAU * float(a) / 8.0
		var lp := TRADE_SQ + Vector2(cos(ang) * 330.0, sin(ang) * 220.0)
		props.add_child(TownBuilder._lamp_post(lp))
		props.add_child(TownBuilder._circle_collider(lp, 4.0, Vector2(0, -2)))
		lights.add_child(TownBuilder._light(lp + Vector2(0, -62), WARM, 0.65, 80.0))
	for bp: Vector2 in [TRADE_SQ + Vector2(-140, 120), TRADE_SQ + Vector2(140, 120), TRADE_SQ + Vector2(-140, -90), TRADE_SQ + Vector2(140, -90)]:
		props.add_child(TownBuilder._sprite("res://assets/art/props/cainos_prop_04.png", bp, 3.0))
		props.add_child(TownBuilder._rect_collider(bp, Vector2(34.0, 10.0), Vector2(0, -5)))
	# old town + east ward squares: a well and lamps
	for sq: Vector2 in [Vector2(3800, 3200), Vector2(5900, 3200)]:
		props.add_child(TownBuilder._sprite("res://assets/art/props/szadi_prop_11.png", sq + Vector2(0, 10), 4.0))
		props.add_child(TownBuilder._rect_collider(sq + Vector2(0, 10), Vector2(44.0, 22.0), Vector2(0, -11)))
		for lp2: Vector2 in [sq + Vector2(-120, -70), sq + Vector2(120, 80)]:
			props.add_child(TownBuilder._lamp_post(lp2))
			lights.add_child(TownBuilder._light(lp2 + Vector2(0, -62), WARM, 0.6, 75.0))
	# main-street lamps between the squares
	for lp3: Vector2 in [Vector2(2500, 850), Vector2(2900, 940), Vector2(3900, 960), Vector2(4700, 920), Vector2(5900, 960),
			Vector2(6400, 1440), Vector2(6560, 2500), Vector2(6560, 3600), Vector2(6560, 4700),
			Vector2(3260, 1600), Vector2(3260, 2700), Vector2(3260, 3600), Vector2(5360, 1600), Vector2(5360, 2700), Vector2(5360, 3700)]:
		props.add_child(TownBuilder._lamp_post(lp3))
		lights.add_child(TownBuilder._light(lp3 + Vector2(0, -62), WARM, 0.6, 75.0))
