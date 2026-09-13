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
const KEEP_DOOR := Vector2(3600.0, 660.0)         # keep compound gate (south wall of the compound)
const HOUSES := "res://assets/art/world/houses/"   # Szadi Houses Pack modules (extract_szadi_houses.py)
const STREET := "res://assets/art/world/street/"    # LPC Victorian town decorations (extract_victorian_kit.py)
const PROPS := "res://assets/art/props/"
const TOWNKIT := "res://assets/art/world/town/"
const BUILDINGS := "res://assets/art/buildings/"
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
	top.band([KEEP_DOOR, Vector2(3600, 760)], 40.0, cobble, 0.0)
	# squares
	top.ellipse(TRADE_SQ, 420.0, 280.0, cobble, 16.0)
	top.ellipse(CATH_SQ, 360.0, 240.0, cobble, 14.0)
	top.ellipse(Vector2(3800, 3200), 150.0, 110.0, cobble, 10.0)
	top.ellipse(Vector2(5900, 3200), 170.0, 120.0, cobble, 10.0)
	top.ellipse(Vector2(3600, 470), 300.0, 150.0, cobble, 10.0)   # keep courtyard

	# --- streets stop at the water's edge (bridges carry them across)
	var shallows: int = TerrainPainter.mat("Water_Shallows_Dirt")
	var hub: int = TerrainPainter.hub()
	for vy in range(base.h + 1):
		for vx in range(base.w + 1):
			var m: int = base.get_v(vx, vy)
			if m == water or m == shallows:
				top.set_v(vx, vy, hub)

	# --- the Fields: tilled soil, farm yards, orchard ground
	var soil: int = TerrainPainter.mat("Soil")
	base.rect_px(Rect2(320, 2720, 640, 224), soil)
	base.rect_px(Rect2(1280, 2720, 704, 192), soil)
	base.rect_px(Rect2(320, 3520, 512, 192), soil)
	base.ellipse(Vector2(1120, 3120), 120.0, 60.0, dirt, 10.0)     # farmstead A yard
	base.ellipse(Vector2(700, 3280), 100.0, 50.0, dirt, 10.0)      # farmstead B yard
	base.ellipse(Vector2(1500, 4420), 110.0, 50.0, dirt, 10.0)     # the mill
	base.ellipse(Vector2(1660, 3500), 140.0, 90.0, dirt, 12.0)     # paddock

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
	_districts(props, decals, lights)
	_dress(props, decals, lights)


# --- rowhouses ----------------------------------------------------------------
## One Szadi-module townhouse, bottom-center at `pos` (the door sill). kind:
##   "gable"   narrow (157 wide) — plaster upper band + tall gable roof
##   "cross"   wide (242 wide)  — shutter window row + cross-gabled roof
##   "cottage" narrow one-story — timber ground + gable roof
## colour: purple | slate | red. Returns the footprint width.
static func _house(props: Node2D, lights: Node2D, pos: Vector2, kind: String, colour: String, rng: RandomNumberGenerator, lit: bool = true) -> float:
	var node := Node2D.new()
	node.position = pos
	var w: float = 242.0 if kind == "cross" else 157.0
	var ground := Sprite2D.new()
	ground.texture = load(HOUSES + "timber_ground_" + colour + ".png")
	ground.region_enabled = true
	var gw: float = minf(w - 4.0, float(ground.texture.get_width()))
	var gx: float = 24.0 if kind == "cross" else float(rng.randi_range(96, 128))
	ground.region_rect = Rect2(gx, 0, gw, ground.texture.get_height())
	ground.centered = false
	ground.offset = Vector2(-gw * 0.5, -ground.texture.get_height())
	node.add_child(ground)
	var top_y: float = -float(ground.texture.get_height()) + 6.0
	if kind == "gable":
		# two-storey plaster band tucked under the roof's gable beam
		var band := Sprite2D.new()
		band.texture = load(HOUSES + "plaster_upper_" + colour + ".png")
		band.centered = false
		band.offset = Vector2(-band.texture.get_width() * 0.5, top_y - band.texture.get_height())
		node.add_child(band)
		top_y += -float(band.texture.get_height()) + 8.0
	else:
		top_y += 8.0
	var roof := Sprite2D.new()
	roof.texture = load(HOUSES + ("roof_cross_" if kind == "cross" else "roof_gable_") + colour + ".png")
	roof.centered = false
	roof.offset = Vector2(-roof.texture.get_width() * 0.5, top_y - roof.texture.get_height())
	node.add_child(roof)
	# chimney on the ridge, smoke on some houses
	var ch := Sprite2D.new()
	ch.texture = load(HOUSES + "chimney_b_" + colour + ".png")
	ch.centered = false
	var chx: float = (-w * 0.28) if rng.randf() < 0.5 else (w * 0.22)
	ch.offset = Vector2(chx, top_y - roof.texture.get_height() + 30.0)
	node.add_child(ch)
	if rng.randf() < 0.45:
		node.add_child(TownBuilder._chimney_smoke(Vector2(chx + 6.0, top_y - roof.texture.get_height() + 30.0)))
	# dressing owned by the house: a planter or pot by the door, sometimes a
	# hanging shop sign or a banner pair (Bible rule 4: every prop has an owner)
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var dress_roll: float = rng.randf()
	if dress_roll < 0.55:
		var pl: Array = ["planter_roses", "planter_sunflower", "pot_shrub", "urn", "planter_cypress", "planter_tree"]
		var pn: String = pl[rng.randi_range(0, pl.size() - 1)]
		var planter := TownBuilder._sprite(STREET + pn + ".png", pos + Vector2(side * (w * 0.5 - 18.0), 2.0), 0.0)
		props.add_child(planter)
	if kind == "gable" and rng.randf() < 0.3:
		var icons: Array = ["signicon_0", "signicon_1", "signicon_2", "signicon_3", "signicon_5", "signicon_6", "signicon_8", "signicon_9", "signicon_10", "signicon_12"]
		var sign := TownBuilder._sprite(STREET + icons[rng.randi_range(0, icons.size() - 1)] + ".png", pos + Vector2(-side * (w * 0.5 - 22.0), -70.0), 0.0)
		sign.position.y = pos.y - 0.05
		sign.offset.y -= 0.0
		node.add_child(_reparent_free(sign, pos, Vector2(-side * (w * 0.5 - 22.0), -70.0)))
	if rng.randf() < 0.18:
		var bn: Array = ["banner_pair_blue", "banner_pair_red", "banner_pair_green", "banner_pair_white", "banner_pair_tan"]
		var banner := Sprite2D.new()
		banner.texture = load(STREET + bn[rng.randi_range(0, bn.size() - 1)] + ".png")
		banner.centered = false
		banner.offset = Vector2(side * (w * 0.5 - 52.0) - 21.0, top_y - 24.0)
		node.add_child(banner)
	if OS.get_environment("RH_HOUSETOP") != "":
		node.z_index = 50
	if OS.get_environment("RH_HOUSEDBG") != "":
		for c in node.get_children():
			if c is Sprite2D:
				var sp: Sprite2D = c
				print("HOUSEDBG %s %s tex=%s region=%s off=%s pos=%s" % [kind, colour, sp.texture.get_size(), sp.region_rect if sp.region_enabled else Rect2(), sp.offset, sp.position])
	props.add_child(node)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(w - 16.0, 40.0), Vector2(0, -20)))
	if lit:
		lights.add_child(TownBuilder._light(pos + Vector2(0, -26.0), WARM, 0.35, 60.0))
	return w


## A row of houses fronting a street: walk from x0 to x1 at `base_y`, random kinds and
## colours, alleys between. Cobble doorsteps come from the street band itself.
static func _house_row(props: Node2D, lights: Node2D, x0: float, x1: float, base_y: float, rng: RandomNumberGenerator, kinds: Array = ["gable", "cross", "gable", "cottage"]) -> void:
	var x: float = x0
	var colours: Array = ["purple", "slate", "red"]
	while x < x1:
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var w: float = 242.0 if kind == "cross" else 157.0
		if x + w > x1:
			break
		var colour: String = colours[rng.randi_range(0, colours.size() - 1)]
		var jitter: float = rng.randf_range(-6.0, 6.0)
		_house(props, lights, Vector2(x + w * 0.5, base_y + jitter), kind, colour, rng)
		x += w + rng.randf_range(20.0, 56.0)


static func _districts(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260913
	# Old Town: houses on the north side of each east-west street, fronting the street
	for sy: float in [2600.0, 3200.0, 3800.0]:
		_house_row(props, lights, 2420.0, 3220.0, sy - 56.0, rng)
		_house_row(props, lights, 3380.0, 3740.0, sy - 56.0, rng)
		_house_row(props, lights, 3860.0, 4230.0, sy - 56.0, rng)
	# canal-side row: north quay of canal A, facing the water
	_house_row(props, lights, 2420.0, 3220.0, CANAL_A_Y - CANAL_HALF - 96.0, rng, ["gable", "gable", "cross"])
	_house_row(props, lights, 3380.0, 4230.0, CANAL_A_Y - CANAL_HALF - 96.0, rng, ["gable", "cross"])
	_house_row(props, lights, 4470.0, 5320.0, CANAL_A_Y - CANAL_HALF - 96.0, rng, ["gable", "gable", "cross"])
	_house_row(props, lights, 5480.0, 6440.0, CANAL_A_Y - CANAL_HALF - 96.0, rng, ["gable", "cross", "cottage"])
	# Trade Square flanks: bank (west) and auction house (east) on the main street
	_house(props, lights, Vector2(2760.0, 950.0), "cross", "slate", rng)
	_house(props, lights, Vector2(3880.0, 950.0), "cross", "purple", rng)
	_house_row(props, lights, 2400.0, 2620.0, 950.0, rng, ["gable"])
	_house_row(props, lights, 4020.0, 4230.0, 950.0, rng, ["gable"])
	# Cathedral Square east side + the avenue
	_house_row(props, lights, 4470.0, 5000.0, 850.0, rng, ["gable", "cross"])
	_house_row(props, lights, 5800.0, 6300.0, 850.0, rng, ["gable", "cross"])
	# East Ward: crafts row on the north side of the y=3200 street, and the east square
	_house_row(props, lights, 4470.0, 5320.0, 3144.0, rng)
	_house_row(props, lights, 5480.0, 5720.0, 3144.0, rng, ["cottage", "gable"])
	_house_row(props, lights, 6100.0, 6440.0, 3144.0, rng, ["gable", "cross"])
	_house_row(props, lights, 4470.0, 6440.0, 3744.0, rng, ["cottage", "gable", "cross"])
	# Harbor: warehouses (wide, dark) north of the quay
	for hx: float in [2760.0, 3080.0, 3880.0, 4560.0]:
		_house(props, lights, Vector2(hx, QUAY_Y0 - 30.0), "cross", "slate", rng, false)


## Re-home a sprite made by TownBuilder._sprite (bottom-center at world pos) under a
## house node so it y-sorts with the house: keep its screen position, local coords.
static func _reparent_free(spr: Sprite2D, house_pos: Vector2, local: Vector2) -> Sprite2D:
	spr.position = local
	return spr


static func _stall(props: Node2D, pos: Vector2, awning: String, rng: RandomNumberGenerator) -> void:
	var table := TownBuilder._sprite(STREET + "stall_3.png", pos, 0.0)
	props.add_child(table)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(86.0, 16.0), Vector2(0, -8)))
	for dx: float in [-44.0, 44.0]:
		props.add_child(TownBuilder._sprite(HOUSES + "pole_slate.png", pos + Vector2(dx, -30.0), 0.0))
	var aw := TownBuilder._sprite(STREET + awning + ".png", pos + Vector2(0, -78.0), 0.0)
	aw.position.y = pos.y + 0.5   # draws over the poles, sorts with the stall
	aw.offset.y -= 78.0
	props.add_child(aw)
	var goods: Array = ["barrel_9", "barrel_3", "flowerbed_5", "pot_blue", "pot_red"]
	var gn: String = goods[rng.randi_range(0, goods.size() - 1)]
	props.add_child(TownBuilder._sprite(STREET + gn + ".png", pos + Vector2(rng.randf_range(-70.0, 70.0), 22.0), 0.0))


static func _hedge_run(props: Node2D, a: Vector2, b: Vector2) -> void:
	var horizontal: bool = absf(b.x - a.x) >= absf(b.y - a.y)
	var tex: String = STREET + ("hedge_h.png" if horizontal else "hedge_v.png")
	var step: float = 80.0 if horizontal else 64.0
	var n: int = int(a.distance_to(b) / step)
	for i in range(n + 1):
		var p: Vector2 = a.lerp(b, float(i) / maxf(float(n), 1.0))
		props.add_child(TownBuilder._sprite(tex, p, 0.0))
	var mid: Vector2 = (a + b) * 0.5
	props.add_child(TownBuilder._rect_collider(mid, Vector2(absf(b.x - a.x) + 40.0, 14.0) if horizontal else Vector2(14.0, absf(b.y - a.y) + 40.0), Vector2(0, -7)))


static func _graves(props: Node2D, decals: Node2D, origin: Vector2, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	for r in range(rows):
		for c in range(cols):
			var gp: Vector2 = origin + Vector2(c * 52.0 + rng.randf_range(-6, 6), r * 64.0)
			var rect: Rect2 = TownBuilder.GRAVE_TYPES[rng.randi_range(0, TownBuilder.GRAVE_TYPES.size() - 1)]
			props.add_child(TownBuilder._atlas_sprite(rect, gp, 2.0))
			props.add_child(TownBuilder._circle_collider(gp, 6.0, Vector2(0, -4)))
			if rng.randf() < 0.5:
				TownBuilder._decal_rect(decals, TownBuilder.R_MOUND, gp + Vector2(0, 28.0))


static func _dress(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	# --- Trade Square: market rows, flags, planters round the fountain, hedge under the keep wall
	for sp: Vector2 in [Vector2(3110, 1110), Vector2(3230, 1110), Vector2(3370, 1110), Vector2(3490, 1110), Vector2(3160, 1215), Vector2(3440, 1215)]:
		var aw: Array = ["awning_2", "awning_5", "awning_8"]
		_stall(props, sp, aw[rng.randi_range(0, 2)], rng)
	for fp: Vector2 in [TRADE_SQ + Vector2(-380, -200), TRADE_SQ + Vector2(380, -200), TRADE_SQ + Vector2(-380, 240), TRADE_SQ + Vector2(380, 240)]:
		props.add_child(TownBuilder._sprite(STREET + "flag_3.png", fp, 0.0))
		props.add_child(TownBuilder._circle_collider(fp, 4.0, Vector2(0, -2)))
	for pp: Vector2 in [TRADE_SQ + Vector2(-70, 60), TRADE_SQ + Vector2(70, 60), TRADE_SQ + Vector2(-70, -10), TRADE_SQ + Vector2(70, -10)]:
		props.add_child(TownBuilder._sprite(STREET + "planter_tree.png", pp, 0.0))
		props.add_child(TownBuilder._circle_collider(pp, 8.0, Vector2(0, -4)))
	_hedge_run(props, Vector2(2900, 700), Vector2(3480, 700))
	_hedge_run(props, Vector2(3720, 700), Vector2(4300, 700))
	for lp: Vector2 in [TRADE_SQ + Vector2(-200, -40), TRADE_SQ + Vector2(200, -40)]:
		props.add_child(TownBuilder._sprite(STREET + "lamp_0.png", lp, 0.0))
		lights.add_child(TownBuilder._light(lp + Vector2(0, -60), WARM, 0.7, 90.0))
	props.add_child(TownBuilder._sprite(STREET + "lamp_6.png", TRADE_SQ + Vector2(0, -230), 0.0))   # clock post
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", TRADE_SQ + Vector2(-260, 150), 0.0))
	# --- Keep: flags flanking the gate, banners on the keep front
	for fx: float in [-90.0, 90.0]:
		props.add_child(TownBuilder._sprite(STREET + "flag_3.png", KEEP_DOOR + Vector2(fx, 6.0), 0.0))
	for bx: float in [-120.0, 120.0]:
		var b := TownBuilder._sprite(STREET + "banner_pair_red.png", Vector2(3600.0 + bx, 400.0), 0.0)
		b.position.y = 400.0 + 0.6
		b.offset.y -= 150.0
		props.add_child(b)
	# --- Cathedral: urns at the steps, hedge-lined square, churchyard east of the nave
	var cb := Vector2(CATH_SQ.x, 620.0)
	for ux: float in [-104.0, 104.0]:
		props.add_child(TownBuilder._sprite(STREET + "urn.png", cb + Vector2(ux, 10.0), 0.0))
	_hedge_run(props, CATH_SQ + Vector2(-360, -60), CATH_SQ + Vector2(-360, 200))
	_hedge_run(props, CATH_SQ + Vector2(360, -60), CATH_SQ + Vector2(360, 200))
	for fb: Vector2 in [CATH_SQ + Vector2(-300, -230), CATH_SQ + Vector2(300, -230), CATH_SQ + Vector2(-300, 260), CATH_SQ + Vector2(300, 260)]:
		var beds: Array = ["flowerbed_1", "flowerbed_2", "flowerbed_5", "flowerbed_7", "flowerbed_9"]
		props.add_child(TownBuilder._sprite(STREET + beds[rng.randi_range(0, beds.size() - 1)] + ".png", fb, 0.0))
	_graves(props, decals, Vector2(5700, 380), 6, 3, rng)
	for fx2 in range(6):
		props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(5680.0 + fx2 * 88.0, 318.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(5680.0 + fx2 * 88.0, 590.0), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(5900, 318), Vector2(560, 10), Vector2.ZERO))
	props.add_child(TownBuilder._rect_collider(Vector2(5900, 590), Vector2(560, 10), Vector2.ZERO))
	props.add_child(TownBuilder._sprite("res://assets/art/world/freekit/trees/tree_dead_oak.png", Vector2(6230, 400), 8.0))
	# --- Old Town: back-garden hedges + flower beds behind each house row, notice board on the square
	for sy: float in [2600.0, 3200.0, 3800.0]:
		_hedge_run(props, Vector2(2440, sy - 420), Vector2(3200, sy - 420))
		_hedge_run(props, Vector2(3400, sy - 420), Vector2(4220, sy - 420))
		for k in range(6):
			var beds2: Array = ["flowerbed_1", "flowerbed_3", "flowerbed_5", "flowerbed_8"]
			props.add_child(TownBuilder._sprite(STREET + beds2[rng.randi_range(0, 3)] + ".png", Vector2(2500.0 + k * 300.0 + rng.randf_range(-40, 40), sy - 470.0 + rng.randf_range(-16, 16)), 0.0))
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(3700, 3260), 0.0))
	props.add_child(TownBuilder._sprite(STREET + "lamp_6.png", Vector2(5900, 3090), 0.0))
	# --- Harbor: cargo on the quay
	for cp: Vector2 in [Vector2(2840, 4470), Vector2(3300, 4480), Vector2(3700, 4470), Vector2(4560, 4480)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_14.png", cp, 4.0))
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_09.png", cp + Vector2(36, 8), 2.0))
		props.add_child(TownBuilder._sprite(STREET + "barrel_3.png", cp + Vector2(-38, 10), 0.0))
		props.add_child(TownBuilder._rect_collider(cp, Vector2(90.0, 18.0), Vector2(0, -9)))
	props.add_child(TownBuilder._sprite("res://assets/art/world/freekit/cargo_grate.png", Vector2(3980, 4475), 2.0))
	# --- the Fields: two farmsteads, crop rows, a paddock, an orchard, the mill
	props.add_child(TownBuilder._place_building("house_03.png", Vector2(1120, 3050)))
	props.add_child(TownBuilder._place_building("house_07.png", Vector2(1330, 3010)))
	props.add_child(TownBuilder._place_building("house_01.png", Vector2(700, 3220)))
	props.add_child(TownBuilder._place_building("house_05.png", Vector2(1500, 4330)))
	for hp: Vector2 in [Vector2(1120, 3020), Vector2(700, 3190), Vector2(1500, 4300)]:
		lights.add_child(TownBuilder._light(hp, WARM, 0.35, 55.0))
	props.add_child(TownBuilder._chimney_smoke(Vector2(1188, 2765)))
	var crops: Array = ["crop_corn", "crop_cabbage", "crop_lettuce", "crop_tomato", "crop_pepper", "crop_carrot"]
	for fr: Rect2 in [Rect2(320, 2720, 640, 224), Rect2(1280, 2720, 704, 192), Rect2(320, 3520, 512, 192)]:
		var crop: String = crops[rng.randi_range(0, crops.size() - 1)]
		var ry: float = fr.position.y + 28.0
		while ry < fr.end.y - 8.0:
			var rx: float = fr.position.x + 20.0
			while rx < fr.end.x - 12.0:
				var cs := TownBuilder._sprite(TOWNKIT + crop + ".png", Vector2(rx, ry), 1.0)
				cs.modulate = Color(0.92, 0.90, 0.84)
				props.add_child(cs)
				rx += 34.0
			ry += 34.0
	# paddock fence (LPC tiles) around the dirt oval + hay
	var ptx0: int = 47
	var ptx1: int = 56
	var pty0: int = 106
	var pty1: int = 112
	for tx in range(ptx0, ptx1 + 1):
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_TL if tx == ptx0 else (TownBuilder.F_TR if tx == ptx1 else TownBuilder.F_T), tx, pty0))
		if tx >= 51 and tx <= 52:
			continue
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_BL if tx == ptx0 else (TownBuilder.F_BR if tx == ptx1 else TownBuilder.F_B), tx, pty1))
	for ty in range(pty0 + 1, pty1):
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_L, ptx0, ty))
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_R, ptx1, ty))
	for hb: Vector2 in [Vector2(1580, 3470), Vector2(1700, 3520), Vector2(1760, 3450)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", hb, 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_12.png", Vector2(1640, 3560), 3.0))
	for ox in range(6):
		for oy in range(3):
			var op := Vector2(360.0 + ox * 96.0, 3960.0 + oy * 88.0 + (16.0 if ox % 2 == 1 else 0.0))
			props.add_child(TownBuilder._sprite("res://assets/art/vegetation/plant_02.png", op, 10.0))
			props.add_child(TownBuilder._circle_collider(op, 5.0, Vector2(0, -3)))
	# --- East Ward crafts: carpenter, potter, tanner yards on the y=3200 row
	for cx2: float in [4560.0, 4760.0]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(cx2, 3300), 3.0))
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_18.png", Vector2(cx2 + 48, 3310), 3.0))
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_25.png", Vector2(cx2 + 20, 3340), 2.0))
	for jx: float in [5560.0, 5600.0, 5640.0]:
		props.add_child(TownBuilder._sprite(PROPS + ("cainos_prop_23.png" if int(jx) % 80 == 0 else "cainos_prop_27.png"), Vector2(jx, 3296), 3.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(6200, 3320), 4.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(6290, 3326), 4.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", Vector2(6360, 3310), 3.0))


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
	var kb := Vector2(3600.0, 400.0)
	_block(props, kb, 4, 2, "gate_doors.png")
	for dx: float in [-184.0, 184.0]:
		_tower_stack(props, kb + Vector2(dx, 8.0), 2)
	props.add_child(TownBuilder._rect_collider(kb, Vector2(260.0, 30.0), Vector2(0, -15)))
	for dx: float in [-70.0, 60.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", kb + Vector2(dx, -44.0), 0.0))
		lights.add_child(TownBuilder._light(kb + Vector2(dx, -52.0), WARM, 0.6, 85.0))
	# courtyard lamps
	for lp: Vector2 in [Vector2(3380, 600), Vector2(3820, 600)]:
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
	for bp: Vector2 in [TRADE_SQ + Vector2(-150, -90), TRADE_SQ + Vector2(150, -90)]:
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
