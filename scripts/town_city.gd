class_name TownCity
## RAVEN HOLLOW CITY v3 — alignment pass (Fable 5.1, 2026-09-21, after the owner's
## 2/10: "houses misaligned, things clipping"). design/RAVEN_HOLLOW_CITY.md is the
## plan; this file is its geometry. Built by TownBuilder AFTER the village pass:
##   paint_masks(base, top) — ground materials into the TerrainPainter canvases
##   build(props, decals, lights) — walls + east gate, keep, cathedral, canal +
##                            basin + leat + bridges, harbor, squares, house rows,
##                            allotments, fields, commons, dressing.
##
## What v3 fixes (all verified on 3x probes, scratchpad/house_probe2.png):
##  * Szadi module assembly: the ground-floor crop is centred on the DOOR (per
##    colour: purple 142 / slate 128 / red 140) and cut to the plaster band's width
##    so ground, band and roof line up; chimneys sit ON the roof plane (gable: on
##    the slope 64 px under the ridge top; cross: on the wing 50 px down) instead
##    of floating beside the peak; slot widths are the real roof widths per colour.
##  * Rows: houses BUTT (0 px) in terraces, real alleys (56-72 px) every 5-8, no
##    per-house jitter, gentle street drift; row pitch 520 so back gardens are a
##    visible 90 px band and never sit under the next row's roofs.
##  * Trade Square moved south so the keep wall shows above the north row; keep
##    barracks are low enough to clear the north wall; the candle-house hedge is
##    north of the cottage; the fair's cart is off the paddock rail; markets use
##    one stall kit (the village's Szadi awning stalls) on a clean grid.
##  * Kit corrections from the sheet: cainos_prop_12 is a SARCOPHAGUS (not a
##    trough), haybale_1 is white bales, flag_3 is a tricolour, urn/urn2 are white
##    vases, lamp_0/lamp_6 are black iron, bench_4 is a piano — none used here.

const CASTLE := "res://assets/art/world/castle/"
const FREEKIT := "res://assets/art/world/freekit/"
const COAST := "res://assets/art/world/coast/"
const HOUSES := "res://assets/art/world/houses/"
const STREET := "res://assets/art/world/street/"
const PROPS := "res://assets/art/props/"
const TOWNKIT := "res://assets/art/world/town/"
const BUILDINGS := "res://assets/art/buildings/"
const PLANTS := "res://assets/art/vegetation/"
const TILE: float = 32.0
const MAP_W: float = 7168.0
const MAP_H: float = 5120.0
const INSET: float = 40.0
const WALL_H: float = 96.0
const WALL_STEP: float = 64.0
const WARM := Color(1.0, 0.78, 0.45)
const TUNNEL_DARK := Color(0.05, 0.045, 0.07, 0.9)

# --- the Szadi Houses Pack, measured (scratchpad/house_probe2.png) ---------------
# door centre in the timber_ground strip / strip width / plaster band width /
# gable roof width / cross roof width
const KIT := {
	"purple": {"door": 142.0, "strip": 276.0, "band": 153.0, "gable": 157.0, "cross": 242.0, "flat": 162.0},
	"slate": {"door": 128.0, "strip": 260.0, "band": 135.0, "gable": 153.0, "cross": 240.0, "flat": 160.0},
	"red": {"door": 140.0, "strip": 272.0, "band": 147.0, "gable": 164.0, "cross": 246.0, "flat": 166.0},
}
# roof_gable_*.png carries a stray full-width ridge bar in rows 0-7 and nothing in
# rows 8-29 (pixel scan 2026-09-21): the roof is cropped from row 30, so a gable
# house is 52 + 70 + 166 - 14 = 274 tall, a cottage 204, a cross 272.
const GABLE_ROOF_CUT: float = 30.0
const H_GABLE: float = 274.0
const H_CROSS: float = 272.0
const H_COTTAGE: float = 204.0
const H_SHOP: float = 160.0      # ground 52 + windows row 20 + flat roof 99, minus overlaps
const ROW_SETBACK: float = 46.0  # door sill above the street centreline
const PITCH: float = 520.0       # E-W street pitch: house 318 + street 100 + garden 100

# Key positions (world px) — keep in sync with design/RAVEN_HOLLOW_CITY.md
const OLD_GATE := Vector2(2240.0, 816.0)
const TRADE_SQ := Vector2(3300.0, 1180.0)
const CATH_SQ := Vector2(5400.0, 1020.0)
const KEEP_DOOR := Vector2(3600.0, 660.0)
const WARD_SQ := Vector2(5420.0, 2560.0)
const HARBOR_SQ := Vector2(3080.0, 4400.0)   # v8: on the quay lip, so the play frame contains the water
const WELL_SQ := Vector2(2380.0, 2560.0)
const TAVERN_SQ := Vector2(3080.0, 3690.0)
const EAST_GATE := Vector2(7000.0, 2600.0)
const BASIN := Vector2(3300.0, 1600.0)
const RIVER_Y: float = 4660.0
const RIVER_HALF: float = 100.0
const CANAL_HALF: float = 40.0
const QUAY_Y0: float = 4260.0

# --- streets (overlay cobble) ---------------------------------------------
const APPROACH := [Vector2(2262, 816), Vector2(2420, 842), Vector2(2560, 904), Vector2(2700, 992), Vector2(2830, 1090), Vector2(2960, 1150), Vector2(3060, 1180)]
const KEEP_ROAD := [Vector2(3600, 700), Vector2(3600, 960)]
const AVENUE_E := [Vector2(3700, 1180), Vector2(3900, 1130), Vector2(4120, 1080), Vector2(4330, 1040), Vector2(4560, 1000), Vector2(4800, 980), Vector2(5000, 990), Vector2(5120, 1000)]
const CATH_FORE := [Vector2(5400, 640), Vector2(5400, 900)]
const AVENUE_S := [Vector2(5400, 1180), Vector2(5400, 1400), Vector2(5400, 1600), Vector2(5380, 1800), Vector2(5340, 2080), Vector2(5400, 2360), Vector2(5420, 2620), Vector2(5380, 2900), Vector2(5440, 3200), Vector2(5400, 3520), Vector2(5440, 3840), Vector2(5400, 4120), Vector2(5420, 4250)]
const LINK := [Vector2(3700, 1430), Vector2(3960, 1470), Vector2(4300, 1470), Vector2(4300, 1520), Vector2(4300, 1600), Vector2(4240, 1800), Vector2(4100, 2050)]
const SPINE := [Vector2(2620, 1440), Vector2(2560, 1700), Vector2(2500, 2040), Vector2(2480, 2300), Vector2(2483, 2560), Vector2(2470, 2820), Vector2(2500, 3080), Vector2(2480, 3340), Vector2(2500, 3600), Vector2(2520, 3900), Vector2(2580, 4200), Vector2(2620, 4300)]
const QUAY_LANE := [Vector2(3040, 1480), Vector2(3050, 1760), Vector2(3040, 2050)]
# Old Town: four streets, gentle drift (<=10 px per 260) so terraces read level
const OT1 := [Vector2(2480, 2040), Vector2(2700, 2046), Vector2(3000, 2036), Vector2(3300, 2044), Vector2(3600, 2038), Vector2(3900, 2046), Vector2(4100, 2040)]
const OT2 := [Vector2(2380, 2560), Vector2(2680, 2554), Vector2(2980, 2564), Vector2(3280, 2556), Vector2(3580, 2566), Vector2(3900, 2560)]
const OT3 := [Vector2(2480, 3080), Vector2(2700, 3086), Vector2(3000, 3076), Vector2(3300, 3084), Vector2(3600, 3078), Vector2(3900, 3086), Vector2(4100, 3080)]
const OT4 := [Vector2(2480, 3600), Vector2(2720, 3594), Vector2(3020, 3604), Vector2(3320, 3596), Vector2(3620, 3606), Vector2(3900, 3598), Vector2(4100, 3600)]
const EAST_ROAD := [Vector2(3900, 2560), Vector2(4160, 2590), Vector2(4420, 2620), Vector2(4700, 2604), Vector2(4980, 2590), Vector2(5240, 2612), Vector2(5420, 2620), Vector2(5700, 2604), Vector2(6000, 2620), Vector2(6320, 2604), Vector2(6620, 2612), Vector2(6900, 2600), Vector2(7140, 2600)]
const EW1 := [Vector2(4340, 3120), Vector2(4640, 3126), Vector2(4940, 3116), Vector2(5240, 3124), Vector2(5540, 3118), Vector2(5840, 3126), Vector2(6140, 3116), Vector2(6440, 3124), Vector2(6600, 3120)]
const EW3 := [Vector2(4360, 4060), Vector2(4660, 4054), Vector2(4960, 4064), Vector2(5260, 4056), Vector2(5560, 4066), Vector2(5860, 4056), Vector2(6160, 4064), Vector2(6460, 4056), Vector2(6600, 4060)]
const EW2 := [Vector2(4360, 3640), Vector2(4660, 3634), Vector2(4960, 3644), Vector2(5260, 3636), Vector2(5560, 3646), Vector2(5860, 3636), Vector2(6160, 3644), Vector2(6460, 3636), Vector2(6600, 3640)]
const CANAL_LANE := [Vector2(4160, 2590), Vector2(4180, 2650), Vector2(4200, 2870), Vector2(4220, 3090), Vector2(4220, 3310), Vector2(4260, 3530), Vector2(4260, 3750), Vector2(4300, 4000), Vector2(4300, 4250)]
const SE_TRACK := [Vector2(6700, 2640), Vector2(6720, 2900), Vector2(6680, 3200), Vector2(6740, 3600), Vector2(6700, 3950), Vector2(6720, 4240)]
const GARDEN_LANE := [Vector2(4100, 2040), Vector2(4480, 1935), Vector2(4800, 1920), Vector2(5100, 1942), Vector2(5400, 1922), Vector2(5700, 1944), Vector2(6000, 1918), Vector2(6300, 1940), Vector2(6600, 1922), Vector2(6900, 1930)]
# v8: the Trade Square's north frontage (bank, auction house, shops) stood on
# lawn with its doorsteps and sill shadows on grass and no path to any door.
const BANK_ROW := [Vector2(2880, 1008), Vector2(3400, 1012), Vector2(3900, 1008), Vector2(4270, 1012)]
const ROWS_EW := [OT1, OT2, OT3, OT4, EAST_ROAD, EW1, EW2, EW3]
# --- water ------------------------------------------------------------------
const CANAL_N := [Vector2(4160, 4560), Vector2(4140, 4380), Vector2(4080, 4120), Vector2(4020, 3860), Vector2(3990, 3600), Vector2(3950, 3340), Vector2(3890, 3080), Vector2(3820, 2830), Vector2(3720, 2600), Vector2(3620, 2380), Vector2(3540, 2160), Vector2(3460, 1940), Vector2(3400, 1760), Vector2(3340, 1664)]
const CANAL_E := [Vector2(3500, 1600), Vector2(3760, 1600), Vector2(4020, 1570), Vector2(4300, 1520), Vector2(4560, 1500), Vector2(4820, 1520), Vector2(5080, 1580), Vector2(5340, 1600), Vector2(5600, 1580), Vector2(5860, 1540), Vector2(6120, 1560), Vector2(6400, 1620), Vector2(6680, 1700), Vector2(6960, 1760), Vector2(7140, 1780)]
# --- field lanes (base dirt) -----------------------------------------------
const F1 := [Vector2(1120, 1450), Vector2(1100, 1700), Vector2(1160, 2000), Vector2(1120, 2300), Vector2(1200, 2600), Vector2(1160, 2900), Vector2(1240, 3200), Vector2(1200, 3500), Vector2(1260, 3800), Vector2(1220, 4100), Vector2(1300, 4400)]
const F2 := [Vector2(300, 2300), Vector2(600, 2320), Vector2(900, 2280), Vector2(1160, 2300), Vector2(1500, 2280), Vector2(1800, 2320), Vector2(2100, 2300), Vector2(2400, 2260), Vector2(2560, 2060), Vector2(2620, 1800), Vector2(2620, 1440)]
const F3 := [Vector2(1160, 2900), Vector2(1500, 2920), Vector2(1800, 2880), Vector2(2100, 2900), Vector2(2400, 2870)]
const F5 := [Vector2(300, 3600), Vector2(600, 3580), Vector2(900, 3620), Vector2(1200, 3600)]
const TOWPATH := [Vector2(120, 4880), Vector2(600, 4870), Vector2(1100, 4890), Vector2(1600, 4876), Vector2(2100, 4892), Vector2(2600, 4880), Vector2(3100, 4894), Vector2(3600, 4882), Vector2(4100, 4896), Vector2(4600, 4884), Vector2(5100, 4898), Vector2(5600, 4884), Vector2(6100, 4896), Vector2(6600, 4886), Vector2(7050, 4890)]
const FARM_FIELDS := [Rect2(1280, 2330, 700, 190), Rect2(360, 2790, 520, 190), Rect2(1420, 2640, 640, 200), Rect2(340, 3120, 580, 180)]
const ALLOT := [Rect2(4560, 1690, 540, 150), Rect2(5520, 1690, 580, 150), Rect2(6200, 1770, 400, 110), Rect2(4600, 1990, 500, 150), Rect2(5540, 1990, 540, 150), Rect2(6240, 1990, 440, 150), Rect2(2262, 2720, 148, 110), Rect2(2262, 3260, 148, 110), Rect2(2262, 3810, 148, 110)]
# footprints of the detached buildings outside the packed districts
const BUILT_RECTS := [Rect2(1200, 4150, 240, 270), Rect2(1380, 1860, 440, 300), Rect2(540, 2400, 210, 280), Rect2(1020, 2880, 160, 200), Rect2(420, 1820, 260, 240), Rect2(6740, 3720, 200, 250), Rect2(6480, 4020, 170, 200), Rect2(4880, 4130, 440, 230), Rect2(6810, 1980, 180, 170), Rect2(6530, 640, 190, 280), Rect2(2380, 240, 340, 380), Rect2(2620, 1080, 280, 320), Rect2(330, 1640, 140, 130), Rect2(6140, 240, 200, 200), Rect2(5880, 1100, 660, 400), Rect2(1000, 2880, 200, 240), Rect2(380, 3540, 360, 220), Rect2(6840, 600, 140, 130), Rect2(900, 3760, 180, 220), Rect2(1820, 4700, 180, 220), Rect2(5420, 4700, 380, 300), Rect2(620, 3920, 280, 200), Rect2(5660, 300, 480, 310)]

static var _rng_seed: int = 20260921


# ============================================================ GROUND MASKS ===
static func paint_masks(base: TerrainPainter.Canvas, top: TerrainPainter.Canvas, top2: TerrainPainter.Canvas = null) -> void:
	var water: int = TerrainPainter.mat("Water")
	var cobble: int = TerrainPainter.mat("Mudstone_Gray")
	var dirt: int = TerrainPainter.mat("Dirt_Roots")
	var soil: int = TerrainPainter.mat("Soil")
	var shallows: int = TerrainPainter.mat("Water_Shallows_Dirt")

	# --- v7: packed earth under every terrace (house seams, alleys and gap
	#     yards were lawn). Painted FIRST so the water bands win at the canal.
	for sb: Array in ROWS_EW:
		var back: Array = []
		for bp: Vector2 in sb:
			back.append(bp + Vector2(0.0, -165.0))
		base.band(back, 125.0, dirt, 8.0)

	# --- water: the river, the winding canal, the basin under the square, the leat
	base.band([Vector2(0, RIVER_Y), Vector2(MAP_W, RIVER_Y)], RIVER_HALF, water, 10.0)
	base.band(CANAL_N, CANAL_HALF, water, 5.0)
	base.band(CANAL_E, 34.0, water, 5.0)
	base.ellipse(BASIN, 210.0, 64.0, water, 5.0)
	base.ellipse(Vector2(560, 3650), 150.0, 84.0, shallows, 8.0)      # the fields pond
	base.ellipse(Vector2(560, 3650), 100.0, 44.0, water, 4.0)
	base.band([Vector2(1250, 4560), Vector2(1300, 4470)], 14.0, shallows, 3.0)   # mill race
	base.band(TOWPATH, 26.0, dirt, 8.0)   # the towpath
	base.ellipse(Vector2(1900, 4960), 90.0, 40.0, dirt, 8.0)             # the ferryman's yard
	base.ellipse(Vector2(5600, 4940), 120.0, 46.0, dirt, 8.0)            # the eel-smokers

	# --- DIRT where feet go: street shoulders + doorsteps, yards, squares
	for s: Array in ROWS_EW:
		base.band(s, 64.0, dirt, 12.0)
	base.band(SPINE, 62.0, dirt, 8.0)
	base.band(QUAY_LANE, 58.0, dirt, 8.0)
	base.band(AVENUE_S, 62.0, dirt, 8.0)
	base.band(AVENUE_E, 66.0, dirt, 10.0)
	base.band(APPROACH, 66.0, dirt, 10.0)
	base.band(LINK, 40.0, dirt, 8.0)
	base.band(CANAL_LANE, 38.0, dirt, 8.0)
	base.band(SE_TRACK, 30.0, dirt, 10.0)
	base.band(GARDEN_LANE, 26.0, dirt, 8.0)
	base.band(BANK_ROW, 62.0, dirt, 10.0)
	base.ellipse(TRADE_SQ, 470.0, 320.0, dirt, 18.0)
	base.ellipse(CATH_SQ + Vector2(0, -40), 420.0, 330.0, dirt, 18.0)
	base.ellipse(WARD_SQ, 300.0, 170.0, dirt, 12.0)
	base.rect_px(Rect2(2800, 200, 1600, 460), dirt)                      # keep compound
	base.rect_px(Rect2(2600, 4140, 2100, 420), dirt)                     # harbor
	base.ellipse(Vector2(3250, 3830), 640.0, 90.0, dirt, 12.0)           # harbor yards
	base.ellipse(Vector2(2500, 440), 210.0, 170.0, dirt, 14.0)           # burned garrison
	base.ellipse(Vector2(2620, 1330), 280.0, 140.0, dirt, 16.0)          # horse fair
	base.ellipse(Vector2(5100, 4360), 520.0, 100.0, dirt, 14.0)          # fishers' strand
	base.ellipse(Vector2(6620, 900), 120.0, 70.0, dirt, 10.0)            # candle-house plot
	base.ellipse(Vector2(6840, 3900), 160.0, 100.0, dirt, 12.0)          # burned farmstead
	base.ellipse(Vector2(6840, 2800), 90.0, 50.0, dirt, 8.0)             # justice corner
	base.ellipse(Vector2(6580, 4220), 160.0, 70.0, dirt, 10.0)           # fisher shacks
	base.ellipse(WELL_SQ, 140.0, 90.0, dirt, 10.0)
	base.ellipse(TAVERN_SQ, 180.0, 100.0, dirt, 10.0)
	# --- the terraces' back gardens (planned here, placed in build)
	_plan_all()
	for sr: Rect2 in _garden_soil:
		base.rect_px(sr, soil)
	for e: Array in _garden_dirt:
		base.ellipse(e[0], float(e[1]), float(e[2]), dirt, 6.0)


	# --- the fields: lanes, tilled soil, yards, orchard ground, the paddock
	for f: Array in [F1, F2, F3, F5]:
		base.band(f, 30.0, dirt, 10.0)
	for fr: Rect2 in FARM_FIELDS:
		base.rect_px(fr, soil)
	for ar: Rect2 in ALLOT:
		base.rect_px(ar, soil)
	base.ellipse(Vector2(1560, 2210), 150.0, 70.0, dirt, 12.0)           # farm A yard
	base.ellipse(Vector2(660, 2690), 110.0, 52.0, dirt, 10.0)            # farm B yard
	base.ellipse(Vector2(1900, 3000), 170.0, 96.0, dirt, 12.0)           # paddock
	base.ellipse(Vector2(1100, 3060), 90.0, 50.0, dirt, 10.0)            # granary tower
	base.ellipse(Vector2(1320, 4420), 120.0, 56.0, dirt, 10.0)           # the mill
	base.ellipse(Vector2(520, 2010), 120.0, 80.0, dirt, 14.0)            # the Ashen Chapel mound

	# --- COBBLE (overlay): streets, squares, quays
	top.band(APPROACH, 44.0, cobble, 6.0)
	top.band(KEEP_ROAD, 40.0, cobble, 0.0)
	top.band(AVENUE_E, 42.0, cobble, 6.0)
	top.band(CATH_FORE, 60.0, cobble, 0.0)
	top.band(AVENUE_S, 40.0, cobble, 6.0)
	top.band(SPINE, 40.0, cobble, 6.0)
	top.band(QUAY_LANE, 36.0, cobble, 6.0)
	top.band(EAST_ROAD, 48.0, cobble, 6.0)
	for s3: Array in [OT1, OT2, OT3, OT4, EW1, EW2, EW3]:
		top.band(s3, 46.0, cobble, 6.0)
	top.band(LINK, 30.0, cobble, 6.0)
	var stone_tan: int = TerrainPainter.mat("Stone_Tan")
	var stone_white: int = TerrainPainter.mat("Stone_White")
	top.band(BANK_ROW, 34.0, cobble, 6.0)
	top.ellipse(TRADE_SQ, 400.0, 250.0, stone_white, 22.0)               # the square is flagged, not cobbled
	top.rect_px(Rect2(2900, 1440, 800, 90), stone_tan)                   # basin quay
	top.ellipse(CATH_SQ, 360.0, 250.0, stone_white, 16.0)                # pale stone before the cathedral
	top.ellipse(WARD_SQ, 200.0, 110.0, cobble, 12.0)
	top.ellipse(WELL_SQ, 110.0, 70.0, cobble, 10.0)
	top.ellipse(TAVERN_SQ, 150.0, 80.0, cobble, 10.0)
	top.ellipse(Vector2(3600, 470), 300.0, 150.0, cobble, 10.0)          # keep courtyard
	top.ellipse(Vector2(2500, 430), 120.0, 80.0, cobble, 8.0)            # old drill floor
	top.rect_px(Rect2(2600, QUAY_Y0, 2100, RIVER_Y - RIVER_HALF - QUAY_Y0 + 16.0), cobble)
	top.ellipse(HARBOR_SQ, 170.0, 90.0, cobble, 10.0)

	# --- v8 ACCENT PAVING (top2): warm brown setts where the city works - the
	#     harbour quay, the keep courtyard and a ring around the fountain.
	if top2 != null:
		var brown: int = TerrainPainter.mat("Mudstone_Brown")   # warm brown setts: the working places (quay, keep court, fountain ring)
		top2.rect_px(Rect2(2600, 4384, 2100, RIVER_Y - RIVER_HALF - 4384 + 16.0), brown)
		top2.ellipse(HARBOR_SQ, 180.0, 96.0, brown, 12.0)
		top2.ellipse(Vector2(3600, 470), 300.0, 150.0, brown, 12.0)
		top2.ellipse(TRADE_SQ + Vector2(0, 20), 150.0, 96.0, brown, 10.0)

	# --- streets stop at the water's edge (bridges carry them across)
	var hub: int = TerrainPainter.hub()
	for vy in range(base.h + 1):
		for vx in range(base.w + 1):
			var m: int = base.get_v(vx, vy)
			if m == water or m == shallows:
				top.set_v(vx, vy, hub)
				if top2 != null:
					top2.set_v(vx, vy, hub)


# =============================================================== STRUCTURES ===
static func build(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	_outer_walls(props, decals, lights)
	_keep(props, lights)
	_cathedral(props, lights)
	_water_colliders(props)
	_bridges(props)
	_harbor(props, lights)
	_squares(props, lights)
	_rows(props, lights)
	_fields(props, decals, lights)
	_allotments(props, lights)
	_commons(props, decals)
	_tonal(decals)
	_street_wear(decals)
	_water_skin(decals)
	_dress(props, decals, lights)
	_vignettes(props, decals, lights)
	_field_lines(props, lights)
	_south_bank(props, decals, lights)
	_contact_shadows(props, decals)
	_rooks(props)
	_sprite_debug(props)
	props.get_parent().add_child(load("res://scripts/city_ambience.gd").new())


## RH_SPRDBG="x,y,r": print every Sprite2D under `props` whose position is within r
## of (x,y) — texture, size, offset — to identify a mystery sprite on a screenshot.
static func _sprite_debug(props: Node2D) -> void:
	var env: String = OS.get_environment("RH_SPRDBG")
	if env.is_empty():
		return
	var parts: PackedStringArray = env.split(",")
	if parts.size() < 3:
		return
	var c := Vector2(parts[0].to_float(), parts[1].to_float())
	var r: float = parts[2].to_float()
	for n in props.get_children():
		var n2: Node2D = n as Node2D
		if n2 != null and n2.position.distance_to(c) <= r and not (n is Sprite2D):
			print("SPRDBG node %s pos=%s children=%d" % [n.get_class(), n2.position, n.get_child_count()])
		var s: Sprite2D = n as Sprite2D
		if s == null:
			continue
		if s.position.distance_to(c) <= r and s.texture != null:
			var tp: String = s.texture.resource_path
			if s.texture is AtlasTexture:
				tp = "atlas " + (s.texture as AtlasTexture).atlas.resource_path + " " + str((s.texture as AtlasTexture).region)
			print("SPRDBG %s size=%s pos=%s off=%s" % [tp, s.texture.get_size(), s.position, s.offset])
		for m in n.get_children():
			var s2: Sprite2D = m as Sprite2D
			if s2 != null and s2.texture != null and (n as Node2D).position.distance_to(c) <= r:
				print("SPRDBG child %s size=%s parent=%s local=%s" % [s2.texture.resource_path, s2.texture.get_size(), (n as Node2D).position, s2.position])


# ------------------------------------------------------------------ GEOMETRY ---
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = 0.0
	var l2: float = ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _dist_to_poly(p: Vector2, pts: Array) -> float:
	var best: float = INF
	for i in range(pts.size() - 1):
		best = minf(best, _seg_dist(p, pts[i], pts[i + 1]))
	return best


## y on an east-west polyline at x (points ordered by x).
static func _y_at(pts: Array, x: float) -> float:
	var first: Vector2 = pts[0]
	var last: Vector2 = pts[pts.size() - 1]
	if x <= first.x:
		return first.y
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 1.0))
	return last.y


## x on a north-south polyline at y (either point order).
static func _x_at(pts_in: Array, y: float) -> float:
	var pts: Array = pts_in.duplicate()
	if (pts[0] as Vector2).y > (pts[pts.size() - 1] as Vector2).y:
		pts.reverse()
	var first: Vector2 = pts[0]
	var last: Vector2 = pts[pts.size() - 1]
	if y <= first.y:
		return first.x
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 1.0))
	return last.x


static func _near_water(p: Vector2, margin: float = 70.0) -> bool:
	if absf(p.y - RIVER_Y) < RIVER_HALF + margin:
		return true
	if _dist_to_poly(p, CANAL_N) < CANAL_HALF + margin or _dist_to_poly(p, CANAL_E) < 34.0 + margin:
		return true
	var d := p - BASIN
	if (d.x * d.x) / (240.0 * 240.0) + (d.y * d.y) / (100.0 * 100.0) < 1.0:
		return true
	return false


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _rng_seed + salt
	return r


## Bridge centres, derived from where each street meets the canal (so the deck
## always sits on the street line): [centre, "ew" | "ns"].
static func _bridge_list() -> Array:
	var out: Array = []
	for row: Array in [OT1, OT2, OT3, OT4]:
		var y0: float = _y_at(row, 3700.0)
		var bx: float = _x_at(CANAL_N, y0)
		out.append([Vector2(bx, _y_at(row, bx)), "ew"])
	out.append([Vector2(_x_at(CANAL_N, 4300.0), 4300.0), "ew"])       # harbor square street
	out.append([Vector2(4300.0, 1520.0), "ns"])                       # LINK over the leat
	out.append([Vector2(5400.0, 1595.0), "ns"])                       # cathedral avenue over the leat
	return out


# ----------------------------------------------------------------- HOUSES ----
## FULL HOUSES (owner, 2026-09-21: "the houses are not ok — full houses in the
## same aesthetic"). The city now uses the Szadi Fantasy Lands set — the eight
## painterly full houses the approved village is built from — instead of the
## Szadi Houses Pack modules. Each has its yard baked in (stones, barrels, hay,
## ladders), so terraces keep a 10-26 px seam where that clutter shows.
## Kinds (aliases keep every old call site valid):
##   cottage = house_01 (160x247)   gable = house_05 (169x252)
##   cross   = house_02 (223x285)   shop  = house_06 (191x234, red awning)
##   work    = house_00 (211x241, hay awning: stables / workshops)
##   barn    = house_03 (186x298, big door: warehouses / barns)
##   shed    = house_07 (132x161, open shed)   inn = house_04 (390x277)
## chimney = smoke anchor relative to the bottom-centre (measured on the sheet).
const FULL := {
	"cottage": {"file": "house_01.png", "w": 160.0, "h": 247.0, "chimney": Vector2(26, -205)},
	"gable": {"file": "house_05.png", "w": 169.0, "h": 252.0, "chimney": Vector2(35, -215)},
	"cross": {"file": "house_02.png", "w": 223.0, "h": 285.0, "chimney": Vector2(-46, -265)},
	"shop": {"file": "house_06.png", "w": 191.0, "h": 234.0, "chimney": Vector2(18, -212)},
	"work": {"file": "house_00.png", "w": 211.0, "h": 241.0, "chimney": Vector2(60, -173)},
	"barn": {"file": "house_03.png", "w": 186.0, "h": 298.0, "chimney": Vector2(28, -226)},
	"shed": {"file": "house_07.png", "w": 132.0, "h": 161.0, "chimney": Vector2.ZERO},
	"inn": {"file": "house_04.png", "w": 390.0, "h": 277.0, "chimney": Vector2(-112, -200)},
	"town": {"file": "", "w": 132.0, "h": 278.0, "chimney": Vector2(-30, -229)},   # v7: composited from the parts sheet (_townhouse)
}


static func _house_w(kind: String, _colour: String = "") -> float:
	return float((FULL[kind] if FULL.has(kind) else FULL["cottage"])["w"])


## The wall's width under the roof (lamps, shadow band, garden posts hang off it).
static func _ground_w(kind: String, _colour: String = "") -> float:
	return 110.0 if kind == "town" else _house_w(kind) * 0.62


static func _house_h(kind: String) -> float:
	return float((FULL[kind] if FULL.has(kind) else FULL["cottage"])["h"])


## One full Fantasy Lands house, bottom-centre at `pos` (the wall line). `colour`
## only tints (slate cool / red warm / purple neutral); 40% are mirrored; ~45% smoke.
static func _house(props: Node2D, lights: Node2D, pos: Vector2, kind: String, colour: String, rng: RandomNumberGenerator, lit: bool = true) -> float:
	var k: Dictionary = FULL[kind] if FULL.has(kind) else FULL["cottage"]
	var w: float = float(k["w"])
	var gw: float = _ground_w(kind)
	var node := Node2D.new()
	node.position = pos
	var mirrored: bool = rng.randf() < 0.4
	if kind == "town":
		_townhouse(node, rng)
	else:
		var spr := Sprite2D.new()
		spr.texture = load(BUILDINGS + String(k["file"]))
		spr.centered = false
		spr.offset = Vector2(-w * 0.5, -float(k["h"]) + 8.0)
		node.add_child(spr)
	# v7: tints wide enough to read at 640x360 (slate cool / red warm / purple /
	# 15% weathered), then 0-3 attachments from the Szadi parts sheet
	var tint: float = rng.randf_range(0.88, 1.04)
	var base_tint := Color(1.0, 1.0, 1.0)
	match colour:
		"slate":
			base_tint = Color(0.80, 0.88, 1.0)
		"red":
			base_tint = Color(1.0, 0.84, 0.74)
		"purple":
			base_tint = Color(0.90, 0.82, 1.0)
	var troll: float = rng.randf()
	if troll < 0.15:
		base_tint = Color(0.78, 0.75, 0.72)     # weathered
	elif troll < 0.25:
		base_tint = Color(1.0, 0.99, 0.95)      # limewashed
	node.modulate = Color(base_tint.r * tint, base_tint.g * tint * rng.randf_range(0.98, 1.0), base_tint.b * tint * rng.randf_range(0.96, 1.0))
	var ch: Vector2 = k["chimney"]
	if kind != "town":
		ch = _attach_parts(node, kind, ch, rng)
	if ch != Vector2.ZERO and rng.randf() < 0.45:
		node.add_child(_smoke(ch, false))
	_windows(node, kind, w, float(k["h"]), rng)
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var wl: Sprite2D = null
	if kind == "shop" or kind == "cross" or rng.randf() < 0.3:
		wl = Sprite2D.new()
		wl.name = "wallamp"
		wl.texture = load(STREET + "wallamp_%d.png" % [7, 9, 10, 11, 12][rng.randi_range(0, 4)])
		wl.position = Vector2(-side * (gw * 0.5 - 6.0), -46.0)
		node.add_child(wl)
	# v8: a hanging sign over every trade door - a shop was indistinguishable
	# from a cottage at play zoom, and signs are how the references label them.
	if SIGNS.has(kind) and (kind != "town" or rng.randf() < 0.35):
		var sgl: Array = SIGNS[kind]
		var sg := TownBuilder._atlas_child(sgl[rng.randi_range(0, sgl.size() - 1)], Vector2(side * (gw * 0.5 - 4.0), -86.0))
		sg.name = "shopsign"
		node.add_child(sg)
	if mirrored:
		_mirror_children(node)
	if wl != null:
		lights.add_child(TownBuilder._light(pos + Vector2(wl.position.x, -48.0), Color(1.0, 0.72, 0.4), 0.3, 42.0))
	# cast shadow on the street (sun from the north-west): a soft band under the sill
	var decals_n: Node = props.get_parent().get_node_or_null("Decals")
	if decals_n != null:
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([Vector2(-gw * 0.5 + 4.0, -3.0), Vector2(gw * 0.5 + 10.0, -3.0), Vector2(gw * 0.5 + 18.0, 15.0), Vector2(-gw * 0.5 - 2.0, 15.0)])
		shadow.color = Color(0.05, 0.03, 0.02, 0.26)
		shadow.position = pos + Vector2(0.0, 8.0 - float(SKIRT.get(kind, 0)))
		decals_n.add_child(shadow)
		# v7: the east wall's shadow on the ground (sun from the north-west)
		var side_sh := Polygon2D.new()
		var hh: float = float(k["h"])
		side_sh.polygon = PackedVector2Array([Vector2(gw * 0.5 + 2.0, -hh * 0.5), Vector2(gw * 0.5 + 14.0, -hh * 0.5 + 12.0), Vector2(gw * 0.5 + 14.0, 8.0), Vector2(gw * 0.5 + 2.0, 8.0)])
		side_sh.color = Color(0.05, 0.03, 0.02, 0.18)
		side_sh.position = pos + Vector2(0.0, 8.0 - float(SKIRT.get(kind, 0)))
		decals_n.add_child(side_sh)
	props.add_child(node)
	_doorstep(props, pos, kind, w, mirrored, rng)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(w - 24.0, 44.0), Vector2(0, -22)))
	if lit:
		lights.add_child(TownBuilder._light(pos + Vector2(0, -26.0), WARM, 0.35, 60.0))
	return w


## Mirror a composed house about its centre line: every sprite flips and its
## x-offset/position mirrors, so the audit still sees true footprints.
static func _mirror_children(node: Node2D) -> void:
	for c in node.get_children():
		if c is Sprite2D:
			var s: Sprite2D = c
			s.flip_h = not s.flip_h
			if s.centered:
				s.position.x = -s.position.x
			else:
				var w: float = s.region_rect.size.x if s.region_enabled else float(s.texture.get_width())
				s.offset.x = -(s.offset.x + w)
		elif c is Node2D:
			(c as Node2D).position.x = -(c as Node2D).position.x


## ------------------------------------------------------------------ ROWS ----
## Terraces are PLANNED once per build (deterministic rng, salt 11) so that
## paint_masks can paint every house's back-garden soil/yard BEFORE the houses
## exist, then PLACED in build (dressing rng, salt 12). Houses BUTT along the
## north side of every east-west street, an alley every 5-8; leftover gaps
## >= 90 px become owned yards. Behind each house: a fenced back garden that
## fills the band up to the previous street's hedge (veg rows / work yard /
## flower plot), so no lawn survives between two terraces.
static var _plans: Array = []
static var _garden_soil: Array = []
static var _garden_dirt: Array = []


static func _row_specs() -> Array:
	var canal: Array = [CANAL_N, 104.0]
	var spine: Array = [SPINE, 46.0]
	var lane: Array = [CANAL_LANE, 44.0]
	var avenue: Array = [AVENUE_S, 46.0]
	var track: Array = [SE_TRACK, 44.0]
	var quay: Array = [QUAY_LANE, 46.0]
	var link: Array = [LINK, 46.0]
	var ot_kinds: Array = ["cottage", "gable", "cross", "cottage", "gable", "shop", "work", "cottage", "gable", "barn", "town", "town"]
	var ew_kinds: Array = ["cottage", "cottage", "gable", "shop", "work", "cottage", "gable", "shed", "town"]
	return [
		{"pts": OT1, "x0": 2570.0, "x1": 4100.0, "kinds": ot_kinds, "avoid": [canal, spine, link, quay], "keep_out": [],
			"gaps": [_x_at(SPINE, 2040.0), _x_at(CANAL_N, 2040.0), 4100.0, 3045.0], "north": 1690.0},
		{"pts": OT2, "x0": 2570.0, "x1": 3900.0, "kinds": ot_kinds, "avoid": [canal, spine], "keep_out": [],
			"gaps": [_x_at(SPINE, 2560.0), _x_at(CANAL_N, 2560.0)], "north": OT1},
		{"pts": OT3, "x0": 2570.0, "x1": 4100.0, "kinds": ot_kinds, "avoid": [canal, spine, lane], "keep_out": [],
			"gaps": [_x_at(SPINE, 3080.0), _x_at(CANAL_N, 3080.0), _x_at(CANAL_LANE, 3080.0)], "north": OT2},
		{"pts": OT4, "x0": 2570.0, "x1": 4100.0, "kinds": ot_kinds, "avoid": [canal, spine, lane], "keep_out": [Rect2(2860.0, 3480.0, 440.0, 200.0)],
			"gaps": [_x_at(SPINE, 3600.0), _x_at(CANAL_N, 3600.0), _x_at(CANAL_LANE, 3600.0), 2880.0, 2960.0, 3080.0, 3200.0, 3300.0], "north": OT3},
		{"pts": EAST_ROAD, "x0": 3960.0, "x1": 6860.0, "kinds": ["gable", "cross", "work", "cottage", "shop", "gable"], "avoid": [avenue, lane, track],
			"keep_out": [Rect2(5180.0, 2380.0, 480.0, 300.0), Rect2(6780.0, 2380.0, 400.0, 440.0)],
			"gaps": [_x_at(AVENUE_S, 2620.0), 4170.0, 6700.0, 5230.0, 5330.0, 5430.0, 5530.0, 5630.0, 4660.0, 4860.0, 6220.0, 6320.0], "north": 2190.0},
		{"pts": EW1, "x0": 4340.0, "x1": 6600.0, "kinds": ew_kinds, "avoid": [avenue, track, lane], "keep_out": [],
			"gaps": [_x_at(AVENUE_S, 3120.0), _x_at(AVENUE_S, 3120.0) + 150.0, 6700.0], "north": EAST_ROAD},   # 2nd gap: the crossroads shrine
		{"pts": EW2, "x0": 4360.0, "x1": 6600.0, "kinds": ew_kinds, "avoid": [avenue, track, lane], "keep_out": [],
			"gaps": [_x_at(AVENUE_S, 3640.0), 6700.0], "north": EW1},
		{"pts": EW3, "x0": 4360.0, "x1": 6440.0, "kinds": ["cottage", "cottage", "shop", "gable", "cottage", "shed"], "avoid": [avenue, track, lane], "keep_out": [],
			"gaps": [_x_at(AVENUE_S, 4060.0), 6700.0], "north": EW2},
		{"pts": AVENUE_E, "x0": 4480.0, "x1": 4870.0, "kinds": ["gable", "cross", "shop"], "avoid": [link], "keep_out": [],
			"gaps": [], "north": 720.0},
	]


## The north limit of a row's back gardens: the previous street's hedge line
## (+70 px so the plot starts just under the hedge sprite) or a fixed y.
static func _north_y(spec: Dictionary, x: float) -> float:
	var n: Variant = spec["north"]
	if n is Array:
		return _y_at(n, x) + 70.0
	return float(n)


static func _plan_all() -> void:
	_plans.clear()
	_garden_soil.clear()
	_garden_dirt.clear()
	var rng := _rng(11)
	for spec: Dictionary in _row_specs():
		_plans.append({"spec": spec, "items": _plan_row(spec, rng)})


static func _plan_row(spec: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pts: Array = spec["pts"]
	var x0: float = float(spec["x0"])
	var x1: float = float(spec["x1"])
	var kinds: Array = spec["kinds"]
	var avoid: Array = spec["avoid"]
	var keep_out: Array = spec["keep_out"]
	var colours: Array = ["slate", "slate", "purple", "purple", "red", "slate"]
	var items: Array = []
	var x: float = x0
	var run: int = 0
	var next_alley: int = rng.randi_range(5, 8)
	var gap_start: float = x0
	var last_kind: String = ""
	var last3: Array = []
	while x < x1 - 100.0:
		# v8: remember the last THREE kinds - two identical silhouettes two
		# slots apart was the commonest clone in the audit frames.
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		for _try in range(4):
			if not last3.has(kind):
				break
			kind = kinds[rng.randi_range(0, kinds.size() - 1)]
		if last3.has(kind):
			for alt: String in kinds:
				if not last3.has(alt):
					kind = alt
					break
		var colour: String = colours[rng.randi_range(0, colours.size() - 1)]
		var w: float = _house_w(kind, colour)
		if x + w > x1:
			kind = "cottage"
			w = _house_w(kind, colour)
			if x + w > x1:
				break
		var cx: float = x + w * 0.5
		var pos := Vector2(cx, _y_at(pts, cx) - ROW_SETBACK)
		var blocked: bool = _blocked(pos, w, avoid, keep_out)
		if blocked and kind != "cottage":
			kind = "cottage"
			w = _house_w(kind, colour)
			cx = x + w * 0.5
			pos = Vector2(cx, _y_at(pts, cx) - ROW_SETBACK)
			blocked = _blocked(pos, w, avoid, keep_out)
		if OS.get_environment("RH_ROWDBG") != "":
			print("ROWDBG x=%d kind=%s pos=%s blocked=%s" % [int(x), kind, pos, blocked])
		if blocked:
			x += 8.0
			continue
		if x - gap_start >= 90.0:
			items.append({"gap": true, "x0": gap_start, "x1": x - 8.0})
		var h: Dictionary = {"pos": pos, "kind": kind, "colour": colour, "w": w, "gw": _ground_w(kind, colour)}
		_plan_garden(spec, h, rng)
		items.append(h)
		last_kind = kind
		last3.append(kind)
		if last3.size() > 3:
			last3.remove_at(0)
		x += w + rng.randf_range(10.0, 26.0)
		gap_start = x
		run += 1
		if run >= next_alley:
			var alley_w: float = rng.randf_range(56.0, 72.0)
			items.append({"alley": true, "x": x + alley_w * 0.5})
			x += alley_w
			gap_start = x
			run = 0
			next_alley = rng.randi_range(5, 8)
	if x1 - gap_start >= 90.0:
		items.append({"gap": true, "x0": gap_start, "x1": x1})
	return items


static func _plan_garden(spec: Dictionary, h: Dictionary, rng: RandomNumberGenerator) -> void:
	var pos: Vector2 = h["pos"]
	var gw: float = float(h["gw"])
	var top: float = _north_y(spec, pos.x)
	var bottom: float = pos.y - _house_h(str(h["kind"])) - 6.0
	var depth: float = bottom - top
	if depth < 70.0:
		return
	if _near_water(Vector2(pos.x, top), 40.0) or _near_water(Vector2(pos.x, bottom), 40.0):
		return
	var mode: int = rng.randi_range(0, 4)   # 0/1/4 veg rows, 2 work yard, 3 flower plot
	h["garden"] = {"top": top, "bottom": bottom, "mode": mode}
	if mode == 2:
		var e: Array = [Vector2(pos.x, (top + bottom) * 0.5 + 4.0), gw * 0.36, (depth - 24.0) * 0.5]
		h["dirt"] = e
		_garden_dirt.append(e)
	elif mode != 3:
		var sw: float = minf(float(h["w"]) * 0.62, 150.0)
		var soil := Rect2(pos.x - sw * 0.5, top + 14.0, sw, minf(depth - 30.0, 120.0))
		h["soil"] = soil
		_garden_soil.append(soil)


static func _blocked(pos: Vector2, w: float, avoid: Array, keep_out: Array) -> bool:
	var corners: Array = [pos, pos + Vector2(w * 0.5, 0), pos - Vector2(w * 0.5, 0)]
	for c: Vector2 in corners:
		if _near_water(c, 60.0):
			return true
		for av: Array in avoid:
			if _dist_to_poly(c, av[0]) < float(av[1]):
				return true
		for r: Rect2 in keep_out:
			if r.has_point(c):
				return true
	return false


static func _rows(props: Node2D, lights: Node2D) -> void:
	var rng := _rng(12)
	if _plans.is_empty():
		_plan_all()
	for plan: Dictionary in _plans:
		var spec: Dictionary = plan["spec"]
		var items: Array = plan["items"]
		var pts: Array = spec["pts"]
		for i in range(items.size()):
			var it: Dictionary = items[i]
			if it.has("gap"):
				_gap_fill(props, pts, float(it["x0"]), float(it["x1"]), spec["avoid"], spec["keep_out"], rng)
				continue
			if it.has("alley"):
				# something at the alley mouth: a barrel, a crate, a cat's worth of clutter
				var ax: float = float(it["x"])
				var ay: float = _y_at(pts, ax)
				if rng.randf() < 0.65:
					var ap := Vector2(ax, ay - rng.randf_range(58.0, 96.0))
					props.add_child(TownBuilder._sprite(PROPS + ["szadi_prop_08.png", "szadi_prop_09.png", "szadi_prop_10.png", "szadi_prop_12.png"][rng.randi_range(0, 3)], ap, 3.0))
				# v7: washing strung across the alley at eave height (drawn in front
				# of both houses: its sort point is on the street side)
				if rng.randf() < 0.6:
					var tan: bool = rng.randf() < 0.6
					var ln := Sprite2D.new()
					ln.texture = load(STREET + ("banner_pair_tan.png" if tan else "banner_pair_white.png"))
					ln.centered = false
					ln.offset = Vector2(-21.0, -110.0 - rng.randf_range(0.0, 20.0))
					ln.scale = Vector2(1.6, 1.0)
					ln.position = Vector2(ax, ay - 40.0)
					ln.modulate = Color(0.86, 0.82, 0.74) if tan else Color(0.82, 0.80, 0.76)
					props.add_child(ln)
				continue
			_house(props, lights, it["pos"], str(it["kind"]), str(it["colour"]), rng)
			if it.has("garden"):
				var right_post: bool = i == items.size() - 1 or (items[i + 1] as Dictionary).has("gap")
				_garden(props, it, right_post, rng)
		_hedge_along(props, pts, float(spec["x0"]), float(spec["x1"]), 66.0, spec["gaps"], rng)
		_street_lamps(props, lights, pts, float(spec["x0"]), float(spec["x1"]), spec["gaps"], rng)


## A back garden: post lines between neighbours, then veg rows on the planned
## soil / a work yard on the planned dirt / a flower plot on the grass.
static func _garden(props: Node2D, h: Dictionary, right_post: bool, rng: RandomNumberGenerator) -> void:
	var g: Dictionary = h["garden"]
	var pos: Vector2 = h["pos"]
	var gw: float = float(h["gw"])
	var top: float = float(g["top"])
	var bottom: float = float(g["bottom"])
	var mode: int = int(g["mode"])
	var hw: float = float(h["w"]) * 0.5 - 8.0
	_post_line(props, pos.x - hw, top, bottom)
	if right_post:
		_post_line(props, pos.x + hw, top, bottom)
	match mode:
		2:
			var d: Array = h["dirt"]
			var c: Vector2 = d[0]
			props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", c + Vector2(-26, 12), 3.0))
			props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", c + Vector2(0, 20), 3.0))
			props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", c + Vector2(28, 8), 3.0))
			props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", c + Vector2(-38, -12), 3.0))
			if bottom - top >= 120.0 and rng.randf() < 0.6:
				props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(c.x + 34.0, bottom - 4.0), 4.0))
			elif rng.randf() < 0.5:
				props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_24.png", c + Vector2(34, -8), 3.0))
			if bottom - top >= 110.0 and rng.randf() < 0.4:
				var ytp := Vector2(c.x - gw * 0.3, top + 36.0)
				props.add_child(_tree(props, ytp, rng))
				props.add_child(TownBuilder._circle_collider(ytp, 6.0, Vector2(0, -3)))
		3:
			var beds: Array = ["flowerbed_1", "flowerbed_2", "flowerbed_3", "flowerbed_5", "flowerbed_7", "flowerbed_8", "flowerbed_9"]
			props.add_child(TownBuilder._sprite(STREET + beds[rng.randi_range(0, beds.size() - 1)] + ".png", Vector2(pos.x - 22.0, bottom - 10.0), 0.0))
			props.add_child(TownBuilder._sprite(STREET + beds[rng.randi_range(0, beds.size() - 1)] + ".png", Vector2(pos.x + 26.0, top + 44.0), 0.0))
			var gtp := Vector2(pos.x + 30.0, (top + bottom) * 0.5 + 14.0)
			props.add_child(_tree(props, gtp, rng))
			props.add_child(TownBuilder._circle_collider(gtp, 6.0, Vector2(0, -3)))
			if rng.randf() < 0.6:
				props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_04.png", Vector2(pos.x - 26.0, top + 40.0), 3.0))
		_:
			var soil: Rect2 = h["soil"]
			var crops: Array = ["crop_cabbage", "crop_lettuce", "crop_carrot", "crop_cucumber", "crop_pepper", "crop_tomato"]
			var crop_a: String = crops[rng.randi_range(0, crops.size() - 1)]
			var crop_b: String = crops[rng.randi_range(0, crops.size() - 1)]
			var just_planted: bool = rng.randf() < 0.25
			var pitch_x: float = rng.randf_range(30.0, 34.0)
			var pitch_y: float = rng.randf_range(30.0, 36.0)
			var nrows: int = int((soil.size.y - 26.0) / pitch_y) + 1
			var split: int = int(ceil(float(nrows) * 0.6))
			var ry: float = soil.position.y + 22.0
			var row: int = 0
			while ry < soil.end.y - 4.0:
				var use: String = crop_a if row < split else crop_b
				var rx: float = soil.position.x + 16.0
				while rx < soil.end.x - 12.0:
					var tex: String = ("sprout_" + use.trim_prefix("crop_")) if (just_planted or row == split) else use
					var cs := TownBuilder._sprite(TOWNKIT + tex + ".png", Vector2(rx + rng.randf_range(-3.0, 3.0), ry + rng.randf_range(-2.0, 2.0)), 1.0)
					cs.modulate = Color(0.92, 0.90, 0.84)
					cs.flip_h = rng.randf() < 0.5
					var cs_s: float = rng.randf_range(0.92, 1.08)
					cs.scale = Vector2(cs_s, cs_s)
					props.add_child(cs)
					rx += pitch_x
				ry += pitch_y
				row += 1
			var corner: Array = ["szadi_prop_08.png", "szadi_prop_24.png", "szadi_prop_26.png", "szadi_prop_10.png", "szadi_prop_22.png", "szadi_prop_31.png", "szadi_prop_12.png", "cainos_prop_27.png"]
			props.add_child(TownBuilder._sprite(PROPS + corner[rng.randi_range(0, corner.size() - 1)], Vector2(soil.position.x + 12.0 if rng.randf() < 0.5 else soil.end.x - 12.0, bottom - 2.0), 3.0))

## A north-south run of LPC fence posts (the full-height post tile) from y0 to y1.
static func _post_line(props: Node2D, x: float, y0: float, y1: float) -> void:
	var y: float = y0 + 30.0
	while y <= y1:
		var s := Sprite2D.new()
		s.texture = TownBuilder._region(TownBuilder.FENCES, TownBuilder.F_L)
		s.centered = false
		s.offset = Vector2(-16.0, -32.0)
		s.position = Vector2(x, y)
		props.add_child(s)
		y += 32.0
	props.add_child(TownBuilder._rect_collider(Vector2(x, (y0 + y1) * 0.5), Vector2(6.0, y1 - y0 - 8.0), Vector2.ZERO))


## A leftover gap in a terrace becomes an owned yard: a low hedge on the street
## line, a crate/sack cluster, sometimes a tree behind — never on the lane that
## caused the gap.
static func _gap_fill(props: Node2D, pts: Array, gx0: float, gx1: float, avoid: Array, keep_out: Array, rng: RandomNumberGenerator) -> void:
	var width: float = gx1 - gx0
	if width < 90.0:
		return
	var x: float = gx0 + 16.0
	while x < gx1 - 12.0:
		var p := Vector2(x, _y_at(pts, x) - 46.0)
		if _clear(p, avoid, keep_out, 20.0):
			var ft := Sprite2D.new()
			ft.texture = TownBuilder._region(TownBuilder.FENCES, TownBuilder.F_T)
			ft.centered = false
			ft.offset = Vector2(-16.0, -32.0)
			ft.position = p
			props.add_child(ft)
			props.add_child(TownBuilder._rect_collider(p, Vector2(32.0, 8.0), Vector2(0, -4)))
		x += 32.0
	var px: float = gx0 + rng.randf_range(30.0, maxf(30.0, width - 30.0))
	var pp := Vector2(px, _y_at(pts, px) - rng.randf_range(72.0, 100.0))
	if _clear(pp, avoid, keep_out, 30.0):
		var picks: Array = ["szadi_prop_29.png", "szadi_prop_32.png", "szadi_prop_14.png", "szadi_prop_12.png", "szadi_prop_10.png"]
		props.add_child(TownBuilder._sprite(PROPS + picks[rng.randi_range(0, picks.size() - 1)], pp, 3.0))
		if width >= 130.0 and rng.randf() < 0.7:
			var tp := Vector2(px + rng.randf_range(-24.0, 24.0), _y_at(pts, px) - rng.randf_range(150.0, 200.0))
			if _clear(tp, avoid, keep_out, 40.0):
				props.add_child(_tree(props, tp, rng))
				props.add_child(TownBuilder._circle_collider(tp, 6.0, Vector2(0, -3)))


static func _clear(p: Vector2, avoid: Array, keep_out: Array, extra: float) -> bool:
	if _near_water(p, 70.0):
		return false
	for av: Array in avoid:
		if _dist_to_poly(p, av[0]) < float(av[1]) + extra:
			return false
	for ko: Rect2 in keep_out:
		if ko.grow(40.0).has_point(p):
			return false
	return true


## The SOUTH side of a street = the back walls of the next row's gardens.
## v7: Old Town streets get a coped stone wall composited from the Cainos
## wall kit (the 79 px hedge slabs read as a green sausage); the ward keeps
## trimmed hedges, now overlapped (60 px step on 81 px slabs), flipped and
## tinted down to grass lightness. Gaps where lanes cross; end caps on every
## stone run; a tuft of weeds at every other foot (the carriageway is clean).
static func _hedge_along(props: Node2D, pts: Array, x0: float, x1: float, dy: float, gaps: Array, rng: RandomNumberGenerator) -> void:
	var stone: bool = [OT1, OT2, OT3, OT4].has(pts)
	var decals_n: Node = props.get_parent().get_node_or_null("Decals")
	var step: float = 64.0 if stone else 32.0
	var x: float = x0 + rng.randf_range(0.0, 30.0)
	var run: int = 0
	var last_p := Vector2.ZERO
	while x < x1:
		var p := Vector2(floorf(x), floorf(_y_at(pts, x) + dy))
		var skip: bool = _near_water(p, 40.0)
		for g: float in gaps:
			if absf(x - g) < 120.0:
				skip = true
		if skip:
			if stone and run > 0:
				_wall_cap(props, last_p + Vector2(48.0, 0.0), false)
			elif run > 0:
				_fence_post(props, last_p + Vector2(24.0, 0.0))
			run = 0
		else:
			if stone:
				if run == 0:
					_wall_cap(props, p + Vector2(-48.0, 0.0), true)
				var ws := Sprite2D.new()
				ws.texture = _low_wall_tex(64, 64)
				ws.centered = false
				ws.offset = Vector2(-32.0, -37.0)
				ws.modulate = WALL_TINT
				ws.position = p
				props.add_child(ws)
				props.add_child(TownBuilder._rect_collider(p, Vector2(64.0, 12.0), Vector2(0, -6)))
			else:
				# East Ward: the craft quarter's wooden rail (same kit as its yards)
				if run == 0:
					_fence_post(props, p + Vector2(-24.0, 0.0))
				var ft := Sprite2D.new()
				ft.texture = TownBuilder._region(TownBuilder.FENCES, TownBuilder.F_T)
				ft.centered = false
				ft.offset = Vector2(-16.0, -32.0)
				ft.position = p
				props.add_child(ft)
				props.add_child(TownBuilder._rect_collider(p, Vector2(32.0, 8.0), Vector2(0, -4)))
			run += 1
			last_p = p
			if decals_n != null and run % (2 if stone else 4) == 0:
				TownBuilder._decal(decals_n, PLANTS + "plant_%02d.png" % rng.randi_range(9, 14), p + Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(2.0, 6.0)))
		x += step
	if stone and run > 0:
		_wall_cap(props, last_p + Vector2(48.0, 0.0), false)
	elif run > 0:
		_fence_post(props, last_p + Vector2(24.0, 0.0))


static func _fence_post(props: Node2D, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = TownBuilder._region(TownBuilder.FENCES, TownBuilder.F_POST)
	s.centered = false
	s.offset = Vector2(-16.0, -32.0)
	s.position = pos
	props.add_child(s)


## Left/right end cap of a low stone run (32 px wide, same three courses).
static func _wall_cap(props: Node2D, pos: Vector2, left: bool) -> void:
	var s := Sprite2D.new()
	s.texture = _low_wall_tex(32 if left else 128, 32)
	s.centered = false
	s.offset = Vector2(-16.0, -37.0)
	s.modulate = WALL_TINT
	s.position = pos
	props.add_child(s)


## A 37 px coped low wall composited from three rows of the Cainos wall sheet
## (cap 18 + one brick course 9 + base course 10; probe: scratchpad
## probe_cainos_wall_composites.png row B). Cached per column window.
static var _wall_cache: Dictionary = {}


static func _low_wall_tex(x0: int, w: int) -> ImageTexture:
	var key: String = "%d,%d" % [x0, w]
	if _wall_cache.has(key):
		return _wall_cache[key]
	var sheet: Image = (load("res://assets/art/terrain/cainos_wall.png") as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var img := Image.create(w, 37, false, Image.FORMAT_RGBA8)
	img.blit_rect(sheet, Rect2i(x0, 192, w, 18), Vector2i(0, 0))
	img.blit_rect(sheet, Rect2i(x0, 210, w, 9), Vector2i(0, 18))
	img.blit_rect(sheet, Rect2i(x0, 246, w, 10), Vector2i(0, 27))
	var tex := ImageTexture.create_from_image(img)
	_wall_cache[key] = tex
	return tex

## Street lamps on the south shoulder every ~360 px (in front of the hedge line).
static func _street_lamps(props: Node2D, lights: Node2D, pts: Array, x0: float, x1: float, gaps: Array, rng: RandomNumberGenerator) -> void:
	var lamp_n: int = 0
	var x: float = x0 + rng.randf_range(80.0, 160.0)
	while x < x1 - 60.0:
		var skip: bool = false
		for g: float in gaps:
			if absf(x - g) < 120.0:
				skip = true
		var p := Vector2(x, _y_at(pts, x) + 26.0)
		if not skip and not _near_water(p, 30.0):
			props.add_child(_city_post(p))
			props.add_child(TownBuilder._circle_collider(p, 4.0, Vector2(0, -2)))
			lamp_n += 1
			if lamp_n % 2 == 1:
				_street_feature(props, lights, Vector2(x + 170.0, _y_at(pts, x + 170.0) + 40.0), lamp_n / 2, gaps)
			var sl := TownBuilder._light(p + Vector2(0, -62), Color(1.0, 0.74, 0.40), rng.randf_range(0.62, 0.84), 118.0)
			sl.add_to_group("city_flicker")
			lights.add_child(sl)
		x += 300.0 + rng.randf_range(-40.0, 120.0)


# --------------------------------------------------------------- SQUARES ----
static func _stall(props: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	## The village's Szadi thatch stall (one kit, one palette) with goods in front.
	var stall: Node2D = TownBuilder._market_stall(pos, TownBuilder.R_DRAPE_ORANGE)
	_stall_shade(props, stall, pos)
	props.add_child(stall)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(90.0, 22.0), Vector2(0, -14)))
	# v8: thirteen identical stalls on a 140 px grid read as a level-editor
	# default. The thatch flips and takes one of three tints, and the goods
	# come from ten sprites instead of four.
	var goods: Array = ["goods_0", "goods_1", "goods_2", "goods_3", "goods_7", "goods_8", "goods_10", "goods_11", "goods_12", "goods_13"]
	var gd := TownBuilder._sprite(STREET + goods[rng.randi_range(0, goods.size() - 1)] + ".png", pos + Vector2(rng.randf_range(-26.0, 26.0), 20.0), 0.0)
	gd.flip_h = rng.randf() < 0.5
	props.add_child(gd)
	if rng.randf() < 0.45:
		var gd2 := TownBuilder._sprite(STREET + goods[rng.randi_range(0, goods.size() - 1)] + ".png", pos + Vector2(rng.randf_range(-40.0, 40.0), 30.0), 0.0)
		gd2.flip_h = rng.randf() < 0.5
		props.add_child(gd2)


static func _lamp(props: Node2D, lights: Node2D, p: Vector2, energy: float = 0.62) -> void:
	props.add_child(_city_post(p))
	props.add_child(TownBuilder._circle_collider(p, 4.0, Vector2(0, -2)))
	var ll := TownBuilder._light(p + Vector2(0, -62), Color(1.0, 0.74, 0.40), energy * 1.25, 118.0)
	ll.add_to_group("city_flicker")
	lights.add_child(ll)


static func _bench(props: Node2D, p: Vector2) -> void:
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_04.png", p, 3.0))
	props.add_child(TownBuilder._rect_collider(p, Vector2(34.0, 10.0), Vector2(0, -5)))


static func _squares(props: Node2D, lights: Node2D) -> void:
	var rng := _rng(2)
	# --- TRADE SQUARE ring: the north terrace stands in front of the keep wall with
	#     its roofs 20 px UNDER the wall base (y 1000 - 318 = 682 > 660)
	_house(props, lights, Vector2(2966, 1000), "cottage", "purple", rng)
	_house(props, lights, Vector2(3140, 1000), "gable", "slate", rng)
	_house(props, lights, Vector2(3364, 1000), "cross", "slate", rng)      # THE BANK
	_house(props, lights, Vector2(3766, 1000), "cross", "purple", rng)     # THE AUCTION HOUSE
	_house(props, lights, Vector2(3982, 1000), "gable", "red", rng)
	_house(props, lights, Vector2(4156, 1000), "town", "slate", rng)   # v8: was a second gable beside its twin
	_house(props, lights, Vector2(2800, 1380), "inn", "red", rng)         # the Gate Tankard (horse fair)
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(3690, 1040), 0.0))
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(2960, 1250), 0.0))
	var f := TownBuilder._anim_sprite([TownBuilder.R_FOUNTAIN_0, TownBuilder.R_FOUNTAIN_1, TownBuilder.R_FOUNTAIN_2], 5.0, TRADE_SQ + Vector2(0, 20), 4.0)
	props.add_child(f)
	props.add_child(TownBuilder._rect_collider(TRADE_SQ + Vector2(0, 20), Vector2(56.0, 30.0), Vector2(0, -15)))
	# v8: the apron is painted in real Mudstone_Brown setts on the accent
	# overlay (paint_masks); cobble_brown_128 is a decorative emblem tile and
	# tiled as a fill it put furniture marks on the plaza. Only the soft kerb
	# shade stays here.
	var decals_sq: Node = props.get_parent().get_node_or_null("Decals")
	if decals_sq != null:
		var rim := Sprite2D.new()
		rim.texture = _radial_tex()
		rim.position = TRADE_SQ + Vector2(0, 26)
		rim.scale = Vector2(2.9, 1.9)
		rim.modulate = Color(0.05, 0.03, 0.02, 0.10)
		decals_sq.add_child(rim)
	for cyp: Vector2 in [TRADE_SQ + Vector2(-340, -130), TRADE_SQ + Vector2(340, -130), TRADE_SQ + Vector2(-360, 210), TRADE_SQ + Vector2(360, 210)]:
		props.add_child(TownBuilder._sprite(STREET + "planter_cypress.png", cyp, 0.0))
		props.add_child(TownBuilder._circle_collider(cyp, 8.0, Vector2(0, -4)))
	for tp2: Vector2 in [KEEP_DOOR + Vector2(-72, 8), KEEP_DOOR + Vector2(72, 8), Vector2(3524, 406), Vector2(3676, 406), Vector2(5336, 626), Vector2(5464, 626), Vector2(2440, 562), Vector2(2960, 4300), Vector2(6760, 2792)]:
		_torch_day_night(props, lights, tp2)
	var brazier := TownBuilder._anim_sprite(TownBuilder.FIRE_FRAMES, 8.0, Vector2(5100, 4446), 4.0)
	props.add_child(brazier)
	props.add_child(TownBuilder._circle_collider(Vector2(5100, 4446), 9.0, Vector2(0, -5)))
	lights.add_child(TownBuilder._light(Vector2(5100, 4430), Color(1.0, 0.62, 0.32), 0.8, 95.0))
	lights.add_child(TownBuilder._light(TRADE_SQ + Vector2(0, -10), Color(0.6, 0.85, 1.0), 0.4, 70.0))
	for lp: Vector2 in [TRADE_SQ + Vector2(-300, -120), TRADE_SQ + Vector2(300, -120), TRADE_SQ + Vector2(-300, 150), TRADE_SQ + Vector2(300, 150), Vector2(3232, 1030), Vector2(3496, 1030)]:
		_lamp(props, lights, lp, 0.65)
	_lamp(props, lights, Vector2(3880, 1044), 0.6)
	_lamp(props, lights, Vector2(4130, 1044), 0.6)
	_bench(props, Vector2(3150, 1120))
	_bench(props, Vector2(3450, 1120))
	for stp: Vector2 in [Vector2(2870, 1240), Vector2(3730, 1240), Vector2(2560, 820), Vector2(2700, 920), Vector2(2790, 1020),
			Vector2(2340, 2600), Vector2(2340, 3130), Vector2(2340, 3680), Vector2(2700, 3960), Vector2(3560, 3970),
			Vector2(5220, 1160), Vector2(5580, 1160)]:
		props.add_child(_swaying(PLANTS + "plant_%02d.png" % (int(stp.x) % 3), stp, 10.0))
		props.add_child(TownBuilder._circle_collider(stp, 7.0, Vector2(0, -4)))
	for pp: Vector2 in [TRADE_SQ + Vector2(-70, 60), TRADE_SQ + Vector2(70, 60), TRADE_SQ + Vector2(-70, -30), TRADE_SQ + Vector2(70, -30)]:
		props.add_child(TownBuilder._sprite(STREET + "planter_bigtree.png", pp, 0.0))
		props.add_child(TownBuilder._circle_collider(pp, 8.0, Vector2(0, -4)))
	props.add_child(TownBuilder._sprite(STREET + "board_0.png", Vector2(3560, 1060), 0.0))
	# --- the well square west of Fair Street, the ward square, the harbor square
	for sq: Vector2 in [WELL_SQ, WARD_SQ + Vector2(0, -60)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_11.png", sq + Vector2(0, 10), 4.0))
		props.add_child(TownBuilder._rect_collider(sq + Vector2(0, 10), Vector2(44.0, 22.0), Vector2(0, -11)))
	_lamp(props, lights, WELL_SQ + Vector2(-90, -60))
	_lamp(props, lights, WELL_SQ + Vector2(-90, 70))
	_bench(props, WELL_SQ + Vector2(60, -50))
	_lamp(props, lights, WARD_SQ + Vector2(-170, -40))
	_lamp(props, lights, WARD_SQ + Vector2(170, -40))
	_stall(props, WARD_SQ + Vector2(-110, 10), rng)
	_stall(props, WARD_SQ + Vector2(110, 10), rng)
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", WARD_SQ + Vector2(200, 40), 0.0))
	# --- the Drowned Rat: a red cross house IN the OT4 terrace, its square across the street
	var ty: float = _y_at(OT4, 3080.0) - ROW_SETBACK
	_house(props, lights, Vector2(3080, ty), "inn", "red", rng)
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", Vector2(2900, ty + 12), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", Vector2(3260, ty + 12), 3.0))
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(3296, ty - 6), 0.0))
	_bench(props, Vector2(3300, ty + 8))
	_lamp(props, lights, TAVERN_SQ + Vector2(-120, 60))
	_lamp(props, lights, TAVERN_SQ + Vector2(120, 60))
	_bench(props, TAVERN_SQ + Vector2(0, 40))
	# --- HARBOR square: the covered pump, lamps
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_11.png", HARBOR_SQ + Vector2(0, 20), 4.0))
	props.add_child(TownBuilder._rect_collider(HARBOR_SQ + Vector2(0, 20), Vector2(44.0, 22.0), Vector2(0, -11)))
	_lamp(props, lights, HARBOR_SQ + Vector2(-140, -40))
	_lamp(props, lights, HARBOR_SQ + Vector2(140, -40))


# ---------------------------------------------------------------- HARBOR -----
static func _cargo(props: Node2D, cp: Vector2) -> void:
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_14.png", cp, 4.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_09.png", cp + Vector2(36, 8), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", cp + Vector2(-30, 10), 3.0))
	props.add_child(TownBuilder._rect_collider(cp, Vector2(84.0, 18.0), Vector2(0, -9)))


static func _harbor(props: Node2D, lights: Node2D) -> void:
	var rng := _rng(3)
	for hx: float in [2720.0, 3440.0, 3700.0]:
		_house(props, lights, Vector2(hx, QUAY_Y0 - 70.0), "barn", "slate", rng, false)
	for px: float in [2900.0, 3500.0, 3900.0]:
		var pier := TownBuilder._sprite(FREEKIT + "pier_planks.png", Vector2(px, RIVER_Y + 20.0), 0.0)
		pier.z_index = -1
		props.add_child(pier)
	props.add_child(TownBuilder._sprite(COAST + "sailboat.png", Vector2(3230.0, RIVER_Y + 70.0), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(2790.0, RIVER_Y + 40.0), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(3760.0, RIVER_Y + 80.0), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(4420.0, RIVER_Y + 50.0), 0.0))
	for lp: Vector2 in [Vector2(2700, 4520), Vector2(3320, 4520), Vector2(3900, 4520), Vector2(4500, 4520)]:
		_lamp(props, lights, lp, 0.65)
	for cp: Vector2 in [Vector2(2840, 4290), Vector2(3560, 4300), Vector2(3800, 4290), Vector2(4360, 4300), Vector2(4500, 4200), Vector2(4560, 4290)]:
		_cargo(props, cp)
	props.add_child(TownBuilder._sprite(FREEKIT + "cargo_grate.png", Vector2(3980, 4470), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_29.png", Vector2(3000, 4470), 3.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(3560, 4480), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(4230, 4468), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "anchor_large.png", Vector2(4150, 4440), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "dock_railing.png", Vector2(2680, 4540), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "dock_railing.png", Vector2(4600, 4540), 0.0))
	# the quay edge: bollards between the piers, crate rows, two carts, nets on the rail
	for bx: float in [2760.0, 3040.0, 3200.0, 3340.0, 3660.0, 3760.0, 4040.0, 4260.0, 4400.0]:
		props.add_child(TownBuilder._sprite(HOUSES + "pole_slate.png", Vector2(bx, 4556.0), 0.0))
	for cr: Vector2 in [Vector2(3120, 4500), Vector2(3160, 4512), Vector2(3200, 4498), Vector2(4060, 4490), Vector2(4100, 4504)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_09.png", cr, 2.0))
	for br: Vector2 in [Vector2(2960, 4404), Vector2(2986, 4416), Vector2(3420, 4470), Vector2(3446, 4482), Vector2(4300, 4410)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", br, 3.0))
	for ct: Vector2 in [Vector2(2800, 4400), Vector2(4460, 4420)]:
		props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, ct, 5.0))
		props.add_child(TownBuilder._rect_collider(ct, Vector2(52, 18), Vector2(0, -10)))
	for sk: Vector2 in [Vector2(3300, 4300), Vector2(3340, 4312), Vector2(3880, 4440)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_24.png", sk, 3.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(3700, 4480), 4.0))
	for nf: Vector2 in [Vector2(4000, 4400), Vector2(4066, 4406), Vector2(4132, 4400)]:
		props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", nf, 4.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(4240, 4440), 0.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_18.png", Vector2(4270, 4452), 3.0))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, Vector2(3980, 4340), 5.0))
	props.add_child(TownBuilder._rect_collider(Vector2(3980, 4340), Vector2(52, 18), Vector2(0, -10)))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(4380, 4460), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(3540, 4340), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(2660, 4420), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(2690, 4436), 3.0))
	_stall(props, HARBOR_SQ + Vector2(-170, 70), rng)
	_stall(props, HARBOR_SQ + Vector2(170, 70), rng)
	# the fishers' strand east of the quay
	_house(props, lights, Vector2(4960, 4340), "shed", "slate", rng, false)
	_house(props, lights, Vector2(5240, 4350), "cottage", "red", rng, false)
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(5090, 4420), 0.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(5150, 4400), 4.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(4890, 4410), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(5350, 4416), 2.0))
	# --- HARBOR YARDS (the band between the last terrace and the warehouses):
	#     cargo, timber, a boat on trestles, nets drying, a lamp, a signpost
	for cp2: Vector2 in [Vector2(2760, 3850), Vector2(3120, 3840), Vector2(3480, 3850)]:
		_cargo(props, cp2)
	for tp: Vector2 in [Vector2(2900, 3880), Vector2(2940, 3872), Vector2(2960, 3892)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", tp, 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_25.png", Vector2(2990, 3886), 2.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(3320, 3880), 0.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_18.png", Vector2(3352, 3892), 3.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(3660, 3820), 4.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(3730, 3826), 4.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(3560, 3870), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "anchor_large.png", Vector2(2660, 3860), 2.0))
	_harbor_edge(props, lights)
	_lamp(props, lights, Vector2(3250, 3900))
	_lamp(props, lights, Vector2(2690, 3900))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", Vector2(3060, 3790), 2.0))


# --------------------------------------------------------------- FIELDS ------
static func _fields(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var rng := _rng(4)
	# --- farmstead A (north fields): house, barn, hay, cart
	props.add_child(TownBuilder._place_building("house_03.png", Vector2(1500, 2150)))
	props.add_child(TownBuilder._place_building("house_07.png", Vector2(1720, 2110)))
	lights.add_child(TownBuilder._light(Vector2(1500, 2120), WARM, 0.35, 55.0))
	props.add_child(TownBuilder._chimney_smoke(Vector2(1568, 1865)))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_14.png", Vector2(1600, 2190), 4.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", Vector2(1650, 2200), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", Vector2(1440, 2200), 3.0))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, Vector2(1790, 2200), 5.0))
	props.add_child(TownBuilder._rect_collider(Vector2(1790, 2200), Vector2(52, 18), Vector2(0, -10)))
	# --- farmstead B (west fields)
	props.add_child(TownBuilder._place_building("house_01.png", Vector2(640, 2660)))
	lights.add_child(TownBuilder._light(Vector2(640, 2630), WARM, 0.35, 55.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(730, 2680), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", Vector2(560, 2672), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", Vector2(700, 2710), 3.0))
	# --- the mill by the river
	props.add_child(TownBuilder._place_building("house_05.png", Vector2(1320, 4400)))
	lights.add_child(TownBuilder._light(Vector2(1320, 4370), WARM, 0.35, 55.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_24.png", Vector2(1400, 4420), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_26.png", Vector2(1250, 4426), 3.0))
	props.add_child(TownBuilder._sprite(STREET + "goods_1.png", Vector2(1330, 4470), 0.0))
	# --- the granary tower on the rise
	_tower_round(props, Vector2(1100, 3060), false, true, true)
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_24.png", Vector2(1170, 3080), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_26.png", Vector2(1040, 3086), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", Vector2(1150, 3100), 3.0))
	# --- crop rows on the four tilled fields (rails one tile outside the soil)
	var crops: Array = ["crop_corn", "crop_cabbage", "crop_lettuce", "crop_tomato", "crop_pepper", "crop_carrot"]
	for fr: Rect2 in FARM_FIELDS:
		# v8: the fields were the worst frame in the set - one crop sprite on a
		# perfect 34x36 lattice, no stages, no gaps. Same recipe as the terrace
		# gardens now: two crops, a seedling row, a fallow strip, harvested
		# holes and a half-pitch stagger so no column runs straight.
		var crop_a: String = crops[rng.randi_range(0, crops.size() - 1)]
		var crop_b: String = crops[rng.randi_range(0, crops.size() - 1)]
		var px_f: float = rng.randf_range(30.0, 36.0)
		var py_f: float = rng.randf_range(32.0, 38.0)
		var nrows_f: int = int((fr.size.y - 38.0) / py_f) + 1
		var split_f: int = int(ceil(float(nrows_f) * 0.6))
		var row_f: int = 0
		var ry: float = fr.position.y + 30.0
		while ry < fr.end.y - 8.0:
			if row_f % 4 != 3:
				var use_f: String = crop_a if row_f < split_f else crop_b
				var rx: float = fr.position.x + 22.0 + (px_f * 0.5 if row_f % 2 == 1 else 0.0)
				while rx < fr.end.x - 26.0:
					if rng.randf() >= 0.06:
						var tex_f: String = ("sprout_" + use_f.trim_prefix("crop_")) if row_f == split_f else use_f
						var cs := TownBuilder._sprite(TOWNKIT + tex_f + ".png", Vector2(rx + rng.randf_range(-3.0, 3.0), ry + rng.randf_range(-2.0, 2.0)), 1.0)
						cs.modulate = Color(0.92, 0.90, 0.84)
						cs.flip_h = rng.randf() < 0.5
						var cscale: float = rng.randf_range(0.92, 1.08)
						cs.scale = Vector2(cscale, cscale)
						props.add_child(cs)
					rx += px_f
			ry += py_f
			row_f += 1
		if fr.size.x > 500.0:
			var hx: float = fr.position.x + 30.0
			while hx < fr.end.x - 20.0:
				var corn := TownBuilder._sprite(TOWNKIT + "crop_corn.png", Vector2(hx + rng.randf_range(-2.0, 2.0), fr.position.y + 16.0), 1.0)
				corn.flip_h = rng.randf() < 0.5
				props.add_child(corn)
				hx += 24.0
		_fence_soil(props, fr)
	# --- the paddock: fenced dirt oval with hay, a gap on the lane side
	_fence_rect(props, Rect2i(54, 91, 11, 6), Vector2i(58, 59))
	for hb: Vector2 in [Vector2(1840, 2980), Vector2(1960, 3030), Vector2(1900, 2950), Vector2(1880, 3060)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", hb, 3.0))
	# --- orchards: jittered grids of leafy trees, picking gear under the last row
	for og: Array in [[Vector2(780, 1700), 4, 3], [Vector2(1660, 3900), 5, 3], [Vector2(6440, 300), 4, 3]]:
		var o: Vector2 = og[0]
		for ox in range(int(og[1])):
			for oy in range(int(og[2])):
				var op := o + Vector2(ox * 96.0 + rng.randf_range(-8, 8), oy * 88.0 + (16.0 if ox % 2 == 1 else 0.0) + rng.randf_range(-6, 6))
				props.add_child(_swaying(PLANTS + "plant_02.png", op, 10.0))
				props.add_child(TownBuilder._circle_collider(op, 5.0, Vector2(0, -3)))
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_16.png", o + Vector2(20, 236), 3.0))
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_24.png", o + Vector2(70, 246), 3.0))
	# --- the pond: reeds, rocks, a bucket
	for rp: Vector2 in [Vector2(470, 3590), Vector2(650, 3590), Vector2(424, 3660), Vector2(698, 3668), Vector2(560, 3740)]:
		var reed := TownBuilder._sprite(TOWNKIT + ("reed_a" if int(rp.x) % 2 == 0 else "reed_b") + ".png", rp, 4.0)
		reed.modulate = Color(0.84, 0.86, 0.78)
		props.add_child(reed)
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_38.png", Vector2(612, 3560), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", Vector2(704, 3600), 2.0))
	_pond_collider(props, Vector2(560, 3650), 124.0, 68.0)
	# --- the Ashen Chapel (PALADIN pocket): scorched stubs on a mound, the cross,
	#     one lit candelabrum (necrotic green is canon here), four graves, a snag
	for wp: Array in [[Vector2(470, 1960), false], [Vector2(534, 1960), true], [Vector2(598, 1964), false], [Vector2(470, 2050), true]]:
		var wf := TownBuilder._sprite(CASTLE + ("wall_face_b.png" if bool(wp[1]) else "wall_face_a.png"), wp[0], 0.0)
		wf.modulate = Color(0.42, 0.36, 0.34)
		props.add_child(wf)
		props.add_child(TownBuilder._rect_collider(wp[0], Vector2(60.0, 22.0), Vector2(0, -11)))
	props.add_child(TownBuilder._sprite(FREEKIT + "cross_large.png", Vector2(534, 1880), 0.0))
	_candelabrum(props, Vector2(580, 2040), 0.5)
	lights.add_child(TownBuilder._light(Vector2(580, 2000), Color(0.55, 0.9, 0.5), 0.45, 70.0))
	for gp: Vector2 in [Vector2(430, 2100), Vector2(480, 2110), Vector2(560, 2106), Vector2(610, 2100)]:
		props.add_child(TownBuilder._sprite(FREEKIT + "graves/grave_%02d.png" % rng.randi_range(1, 12), gp, 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "trees/tree_dead_snag.png", Vector2(400, 1760), 8.0))
	# --- the wildwood strip along the west wall (DRUID nod): two staggered columns
	var y: float = 1700.0
	while y < 4420.0:
		var dead: bool = false
		for col: Array in [[150.0, 185.0, 0.0], [225.0, 262.0, 37.0]]:
			if dead:
				break
			var tp := Vector2(rng.randf_range(float(col[0]), float(col[1])), y + float(col[2]) + rng.randf_range(-10.0, 10.0))
			if float(col[0]) == 150.0 and rng.randf() < 0.12:
				props.add_child(TownBuilder._sprite(FREEKIT + "trees/tree_dead_%s.png" % ["crook", "gnarl", "reach"][rng.randi_range(0, 2)], tp, 8.0))
				dead = true
			else:
				props.add_child(_tree(props, tp, rng))
			props.add_child(TownBuilder._circle_collider(tp, 7.0, Vector2(0, -4)))
		y += 74.0
	# --- copses and boulders on the commons between the fields
	for cp: Vector2 in [Vector2(1900, 1900), Vector2(1960, 1960), Vector2(2020, 1880),
			Vector2(400, 2560), Vector2(460, 2600), Vector2(1800, 3300), Vector2(1860, 3360), Vector2(1920, 3290), Vector2(900, 3400), Vector2(960, 3460),
			Vector2(1600, 4180), Vector2(1660, 4230), Vector2(2100, 3700), Vector2(2160, 3760),
			Vector2(2200, 4200), Vector2(2260, 4260), Vector2(1500, 1720), Vector2(1560, 1780)]:
		props.add_child(_swaying(PLANTS + "plant_%02d.png" % (int(cp.x + cp.y) % 3), cp, 10.0))
		props.add_child(TownBuilder._circle_collider(cp, 7.0, Vector2(0, -4)))
	for bp: Vector2 in [Vector2(840, 2450), Vector2(1700, 3520), Vector2(1200, 3950), Vector2(2180, 2500), Vector2(400, 3900), Vector2(1980, 3550)]:
		var rock := TownBuilder._sprite(PROPS + "cainos_prop_%02d.png" % [33, 38, 39, 42][rng.randi_range(0, 3)], bp, 2.0)
		rock.flip_h = rng.randf() < 0.5
		props.add_child(rock)
		if rng.randf() < 0.55:
			var rock2 := TownBuilder._sprite(PROPS + "cainos_prop_%02d.png" % [38, 39, 42][rng.randi_range(0, 2)], bp + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-10.0, 12.0)), 2.0)
			rock2.flip_h = rng.randf() < 0.5
			props.add_child(rock2)
	var t: float = 0.0
	while t < 1.0:
		var i: int = int(t * float(F1.size() - 1))
		var a: Vector2 = F1[mini(i, F1.size() - 2)]
		var b: Vector2 = F1[mini(i + 1, F1.size() - 1)]
		var p: Vector2 = a.lerp(b, t * float(F1.size() - 1) - float(i))
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var bp2 := p + Vector2(side * rng.randf_range(44.0, 70.0), rng.randf_range(-10.0, 10.0))
		if bp2.y > 1620.0 and bp2.y < 4300.0:
			props.add_child(TownBuilder._sprite(PLANTS + "plant_%02d.png" % rng.randi_range(3, 8), bp2, 3.0))
		t += 0.028
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_06.png", Vector2(1210, 2260), 3.0))
	props.add_child(TownBuilder._rect_collider(Vector2(1210, 2260), Vector2(22, 10), Vector2(0, -5)))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", Vector2(1180, 2940), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", Vector2(1150, 1560), 2.0))


static func _pond_collider(props: Node2D, center: Vector2, rx: float, ry: float) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	poly.points = pts
	cs.shape = poly
	body.add_child(cs)
	props.add_child(body)


## LPC 3x3 fence kit around a tile rect (inclusive), gap on the bottom rail at
## tiles gap.x..gap.y (-1,-1 for none). Thin colliders on the rails.
static func _fence_rect(props: Node2D, r: Rect2i, gap: Vector2i) -> void:
	var tx0: int = r.position.x
	var ty0: int = r.position.y
	var tx1: int = r.position.x + r.size.x - 1
	var ty1: int = r.position.y + r.size.y - 1
	for tx in range(tx0, tx1 + 1):
		var t_rect: Rect2 = TownBuilder.F_T
		if tx == tx0:
			t_rect = TownBuilder.F_TL
		elif tx == tx1:
			t_rect = TownBuilder.F_TR
		props.add_child(TownBuilder._fence_tile(t_rect, tx, ty0))
		if tx >= gap.x and tx <= gap.y:
			continue
		var b_rect: Rect2 = TownBuilder.F_B
		if tx == tx0:
			b_rect = TownBuilder.F_BL
		elif tx == tx1:
			b_rect = TownBuilder.F_BR
		props.add_child(TownBuilder._fence_tile(b_rect, tx, ty1))
	for ty in range(ty0 + 1, ty1):
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_L, tx0, ty))
		props.add_child(TownBuilder._fence_tile(TownBuilder.F_R, tx1, ty))
	var left: float = float(tx0 * TILE)
	var right: float = float((tx1 + 1) * TILE)
	var top: float = float(ty0 * TILE)
	var bottom: float = float((ty1 + 1) * TILE)
	var mid_x: float = (left + right) * 0.5
	var mid_y: float = (top + bottom) * 0.5
	props.add_child(TownBuilder._rect_collider(Vector2(mid_x, top + 24.0), Vector2(right - left, 10.0), Vector2.ZERO))
	props.add_child(TownBuilder._rect_collider(Vector2(left + 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))
	props.add_child(TownBuilder._rect_collider(Vector2(right - 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))
	if gap.x < 0:
		props.add_child(TownBuilder._rect_collider(Vector2(mid_x, bottom - 8.0), Vector2(right - left, 10.0), Vector2.ZERO))
	else:
		var gx0: float = float(gap.x * TILE)
		var gx1: float = float((gap.y + 1) * TILE)
		props.add_child(TownBuilder._rect_collider(Vector2((left + gx0) * 0.5, bottom - 8.0), Vector2(gx0 - left, 10.0), Vector2.ZERO))
		props.add_child(TownBuilder._rect_collider(Vector2((gx1 + right) * 0.5, bottom - 8.0), Vector2(right - gx1, 10.0), Vector2.ZERO))


## Fence a soil plot: rails one tile OUTSIDE the painted soil on every side.
static func _fence_soil(props: Node2D, fr: Rect2) -> void:
	var tx0: int = int(fr.position.x / TILE) - 1
	var ty0: int = int(fr.position.y / TILE) - 1
	var tx1: int = int(fr.end.x / TILE)
	var ty1: int = int(ceil(fr.end.y / TILE))
	_fence_rect(props, Rect2i(tx0, ty0, tx1 - tx0 + 1, ty1 - ty0 + 1), Vector2i(-1, -1))


static func _on_soil(p: Vector2) -> bool:
	for r: Rect2 in FARM_FIELDS:
		if r.grow(64.0).has_point(p):
			return true
	for r3: Rect2 in _garden_soil:
		if r3.grow(30.0).has_point(p):
			return true
	for r2: Rect2 in ALLOT:
		if r2.grow(40.0).has_point(p):
			return true
	return false


## THE MARKET GARDENS: allotment plots between the leat and the East Road, a lane
## between them, the gardeners' shed at the lane's end.
static func _allotments(props: Node2D, lights: Node2D) -> void:
	var rng := _rng(7)
	var crops: Array = ["crop_cabbage", "crop_lettuce", "crop_carrot", "crop_cucumber", "crop_pepper", "crop_tomato"]
	for fr: Rect2 in ALLOT:
		var crop_a: String = crops[rng.randi_range(0, crops.size() - 1)]
		var crop_b: String = crops[rng.randi_range(0, crops.size() - 1)]
		var big: bool = fr.size.x > 300.0
		var px: float = rng.randf_range(31.0, 35.0)
		var py: float = rng.randf_range(31.0, 36.0)
		var nrows: int = int((fr.size.y - 34.0) / py) + 1
		var split: int = int(ceil(float(nrows) * 0.6))
		var ry: float = fr.position.y + (44.0 if big else 28.0)
		var row: int = 0
		while ry < fr.end.y - 6.0:
			var rx: float = fr.position.x + 20.0
			var use: String = crop_a if row < split else crop_b
			while rx < fr.end.x - 26.0:
				if not (rx < fr.position.x + 40.0 and ry < fr.position.y + 40.0):
					var tex: String = ("sprout_" + use.trim_prefix("crop_")) if row == split else use
					var cs := TownBuilder._sprite(TOWNKIT + tex + ".png", Vector2(rx + rng.randf_range(-3.0, 3.0), ry + rng.randf_range(-2.0, 2.0)), 1.0)
					cs.modulate = Color(0.92, 0.90, 0.84)
					cs.flip_h = rng.randf() < 0.5
					props.add_child(cs)
				rx += px
			ry += py
			row += 1
		if big:
			var cx: float = fr.position.x + 30.0
			while cx < fr.end.x - 20.0:
				var corn := TownBuilder._sprite(TOWNKIT + "crop_corn.png", Vector2(cx + rng.randf_range(-2.0, 2.0), fr.position.y + 14.0), 1.0)
				corn.flip_h = rng.randf() < 0.5
				props.add_child(corn)
				cx += 24.0
		_fence_soil(props, fr)
		props.add_child(TownBuilder._sprite(PROPS + ["szadi_prop_24.png", "szadi_prop_26.png", "szadi_prop_08.png", "szadi_prop_10.png"][rng.randi_range(0, 3)], fr.position + Vector2(22.0, 30.0), 3.0))
	props.add_child(TownBuilder._place_building("house_07.png", Vector2(6900, 2130)))
	lights.add_child(TownBuilder._light(Vector2(6900, 2100), WARM, 0.3, 50.0))
	_bench(props, Vector2(6820, 2144))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(6978, 2140), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", Vector2(4470, 1980), 2.0))
	_lamp(props, lights, Vector2(5300, 1955), 0.5)
	_lamp(props, lights, Vector2(6150, 1958), 0.5)


## Ground breakup over the whole city outside the village: tufts and flower
## decals everywhere, bushes and stones on the open ground only.
static func _commons(props: Node2D, decals: Node2D) -> void:
	var rng := _rng(6)
	var placed: int = 0
	var tries: int = 0
	while placed < 3200 and tries < 14000:
		tries += 1
		var p := Vector2(rng.randf_range(140.0, MAP_W - 140.0), rng.randf_range(180.0, MAP_H - 120.0))
		if p.x < 2240.0 and p.y < 1600.0:
			continue
		if _near_water(p, 10.0) or _on_soil(p) or _on_street(p):
			continue
		TownBuilder._decal(decals, PLANTS + "plant_%02d.png" % rng.randi_range(9, 14), p)
		placed += 1
	var bushes: int = 0
	var bush_pts: Array = []
	tries = 0
	while bushes < 320 and tries < 6000:
		tries += 1
		var p2 := Vector2(rng.randf_range(160.0, MAP_W - 160.0), rng.randf_range(200.0, MAP_H - 140.0))
		if p2.x < 2240.0 and p2.y < 1600.0:
			continue
		if _near_water(p2, 24.0) or _in_built_up(p2) or _on_soil(p2) or _in_built_rect(p2) or _near_lane(p2):
			continue
		if p2.x < 330.0 and p2.y > 1650.0:
			continue
		var crowded: bool = false
		for q: Vector2 in bush_pts:
			if q.distance_to(p2) < 40.0:
				crowded = true
				break
		if crowded:
			continue
		bush_pts.append(p2)
		var croll: float = rng.randf()
		if croll < 0.25:
			props.add_child(_tree(props, p2, rng))
			props.add_child(TownBuilder._circle_collider(p2, 6.0, Vector2(0, -3)))
		elif croll < 0.8:
			props.add_child(_bush(p2, rng))
		else:
			props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_%02d.png" % rng.randi_range(34, 42), p2, 2.0))
		bushes += 1
	# v7: the cathedral quarter's meadows (skipped above as "built-up") get their
	# own scatter: small bushes, stones and a few trees between the close, the
	# hospice and the churchyard, never on the forecourt, the graves or the leat
	var cq: int = 0
	tries = 0
	while cq < 110 and tries < 3000:
		tries += 1
		var p3 := Vector2(rng.randf_range(4560.0, 7000.0), rng.randf_range(180.0, 1500.0))
		if _near_water(p3, 40.0) or _on_street(p3) or _on_soil(p3) or _in_built_rect(p3):
			continue
		if p3.distance_to(CATH_SQ) < 420.0 or _dist_to_poly(p3, CATH_FORE) < 90.0:
			continue
		if Rect2(5820.0, 180.0, 400.0, 420.0).has_point(p3):   # the churchyard's graves
			continue
		var crowded2: bool = false
		for q2: Vector2 in bush_pts:
			if q2.distance_to(p3) < 44.0:
				crowded2 = true
				break
		if crowded2:
			continue
		bush_pts.append(p3)
		var r3: float = rng.randf()
		if r3 < 0.12:
			props.add_child(_tree(props, p3, rng))
			props.add_child(TownBuilder._circle_collider(p3, 6.0, Vector2(0, -3)))
		elif r3 < 0.78:
			var bsh := TownBuilder._sprite(PLANTS + "plant_%02d.png" % rng.randi_range(3, 8), p3, 3.0)
			bsh.flip_h = rng.randf() < 0.5
			bsh.modulate = Color(rng.randf_range(0.84, 1.0), rng.randf_range(0.9, 1.0), rng.randf_range(0.76, 0.9))
			props.add_child(bsh)
		else:
			props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_%02d.png" % rng.randi_range(34, 42), p3, 2.0))
		cq += 1


static func _in_built_up(p: Vector2) -> bool:
	for s: Array in [OT1, OT2, OT3, OT4, EW1, EW2, EW3, EAST_ROAD, APPROACH, AVENUE_E, AVENUE_S, SPINE, LINK, CANAL_LANE, KEEP_ROAD, QUAY_LANE, GARDEN_LANE]:
		if _dist_to_poly(p, s) < 420.0:
			return true
	if p.y < 700.0 and p.x > 2740.0 and p.x < 4460.0:
		return true
	if p.distance_to(TRADE_SQ) < 700.0 or p.distance_to(CATH_SQ) < 640.0 or p.distance_to(WARD_SQ) < 320.0:
		return true
	if p.y > 3700.0 and p.x > 2560.0 and p.x < 4760.0:
		return true
	return false


static func _near_lane(p: Vector2) -> bool:
	for l: Array in [F1, F2, F3, F5]:
		if _dist_to_poly(p, l) < 60.0:
			return true
	return false


static func _in_built_rect(p: Vector2) -> bool:
	for r: Rect2 in BUILT_RECTS:
		if r.has_point(p):
			return true
	return false


# --------------------------------------------------------------- DRESSING ----
static func _hedge_run(props: Node2D, a: Vector2, b: Vector2) -> void:
	var horizontal: bool = absf(b.x - a.x) >= absf(b.y - a.y)
	var tex: String = STREET + ("hedge_h.png" if horizontal else "hedge_v.png")
	var step: float = 77.0 if horizontal else 62.0
	var n: int = int(a.distance_to(b) / step)
	for i in range(n + 1):
		var p: Vector2 = a.lerp(b, float(i) / maxf(float(n), 1.0))
		var hs := TownBuilder._sprite(tex, p, 0.0)
		hs.modulate = Color(0.80, 0.84, 0.68)
		props.add_child(hs)
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
	var rng := _rng(5)
	# --- TRADE SQUARE: two market rows on the south lobe, flags, crates at the edge
	# v8: 140 px pitch with a mirrored second row is a grid; jitter it and open
	# a gap where a stall would have stood.
	for sp: Vector2 in [Vector2(3046, 1284), Vector2(3196, 1296), Vector2(3366, 1286), Vector2(3494, 1300), Vector2(3118, 1388), Vector2(3288, 1374), Vector2(3436, 1390)]:
		if sp.x > 3480.0 and sp.y < 1320.0:
			props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_15.png", sp, 3.0))
			continue
		_stall(props, sp, rng)
	for fp: Vector2 in [Vector2(2920, 1120), Vector2(3680, 1120), Vector2(3030, 1400), Vector2(3680, 1380)]:
		props.add_child(TownBuilder._sprite(STREET + "flag_1.png", fp, 0.0))
		props.add_child(TownBuilder._circle_collider(fp, 4.0, Vector2(0, -2)))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_32.png", Vector2(3620, 1360), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_14.png", Vector2(3660, 1300), 3.0))
	pass  # (goods_1 crate removed: it stood on the square lamp)
	# quay along the basin: bollards, a moored rowboat, a rope coil
	for qx: float in [2960.0, 3120.0, 3300.0, 3480.0, 3640.0]:
		props.add_child(TownBuilder._sprite(HOUSES + "pole_slate.png", Vector2(qx, 1526.0), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(3180, 1580), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(3400, 1510), 2.0))
	# --- THE APPROACH: toll house, a signpost, crates
	_house(props, lights, Vector2(2400, 740), "cottage", "slate", rng)
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_22.png", Vector2(2520, 950), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_12.png", Vector2(2650, 1040), 3.0))
	# --- THE HORSE FAIR: paddock rails, hay inside, the farrier on the south edge,
	#     the tavern's cart, a big cart by the road
	_fence_rect(props, Rect2i(75, 38, 6, 7), Vector2i(-1, -1))
	for hb: Vector2 in [Vector2(2470, 1300), Vector2(2540, 1340), Vector2(2500, 1390), Vector2(2440, 1260)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", hb, 3.0))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, Vector2(2680, 1480), 5.0))
	props.add_child(TownBuilder._rect_collider(Vector2(2680, 1480), Vector2(52, 18), Vector2(0, -10)))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, Vector2(2900, 1520), 5.0))
	props.add_child(TownBuilder._rect_collider(Vector2(2900, 1520), Vector2(52, 18), Vector2(0, -10)))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", Vector2(2950, 1530), 3.0))
	var fire := TownBuilder._anim_sprite(TownBuilder.FIRE_FRAMES, 8.0, Vector2(2560, 1500), 4.0)
	props.add_child(fire)
	props.add_child(TownBuilder._circle_collider(Vector2(2560, 1500), 9.0, Vector2(0, -5)))
	lights.add_child(TownBuilder._light(Vector2(2560, 1484), Color(1.0, 0.62, 0.32), 0.8, 95.0))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_ANVIL, Vector2(2596, 1516), 4.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_19.png", Vector2(2520, 1520), 3.0))
	# --- THE BURNED GARRISON (WARRIOR pocket): scorched stubs, a tower stump,
	#     training posts, a rack, bricks, a bench — nothing tall in front of them
	for wp: Array in [[Vector2(2380, 330), 1], [Vector2(2444, 330), 0], [Vector2(2508, 334), 1], [Vector2(2380, 420), 0], [Vector2(2600, 360), 0], [Vector2(2664, 364), 1]]:
		var wf := TownBuilder._sprite(CASTLE + ("wall_face_b.png" if int(wp[1]) == 1 else "wall_face_a.png"), wp[0], 0.0)
		wf.modulate = Color(0.40, 0.35, 0.33)
		props.add_child(wf)
		props.add_child(TownBuilder._rect_collider(wp[0], Vector2(60.0, 22.0), Vector2(0, -11)))
	var tw := TownBuilder._sprite(CASTLE + "tower_narrow.png", Vector2(2310, 440), 0.0)
	tw.modulate = Color(0.45, 0.40, 0.38)
	props.add_child(tw)
	props.add_child(TownBuilder._rect_collider(Vector2(2310, 440), Vector2(56.0, 26.0), Vector2(0, -13)))
	for dp: Vector2 in [Vector2(2520, 500), Vector2(2600, 520)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_27.png", dp, 3.0))
		props.add_child(TownBuilder._circle_collider(dp, 6.0, Vector2(0, -4)))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_15.png", Vector2(2650, 570), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_19.png", Vector2(2690, 604), 3.0))
	_bench(props, Vector2(2560, 600))
	# --- KEEP courtyard: barracks (low enough to clear the north wall), well, drill
	#     posts, hay, flags at the gate, banners on the keep front
	_house(props, lights, Vector2(2960, 440), "work", "slate", rng)
	_house(props, lights, Vector2(3140, 400), "cottage", "slate", rng)
	_house(props, lights, Vector2(4160, 440), "work", "slate", rng)
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_11.png", Vector2(3420, 560), 4.0))
	props.add_child(TownBuilder._rect_collider(Vector2(3420, 560), Vector2(44.0, 22.0), Vector2(0, -11)))
	for dp2: Vector2 in [Vector2(3900, 560), Vector2(3960, 590)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_27.png", dp2, 3.0))
		props.add_child(TownBuilder._circle_collider(dp2, 6.0, Vector2(0, -4)))
	for hb2: Vector2 in [Vector2(4060, 560), Vector2(4100, 580)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", hb2, 3.0))
	props.add_child(_smoke(Vector2(3600, 528), true))
	props.add_child(_smoke(Vector2(2560, 1488), true))
	var kfire := TownBuilder._anim_sprite(TownBuilder.FIRE_FRAMES, 8.0, Vector2(3600, 540), 4.0)
	props.add_child(kfire)
	props.add_child(TownBuilder._circle_collider(Vector2(3600, 540), 9.0, Vector2(0, -5)))
	lights.add_child(TownBuilder._light(Vector2(3600, 524), Color(1.0, 0.62, 0.32), 0.85, 100.0))
	for ls: Vector2 in [Vector2(3556, 560), Vector2(3644, 560), Vector2(3600, 582)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_18.png", ls, 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_15.png", Vector2(3760, 610), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_15.png", Vector2(3800, 612), 3.0))
	props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, Vector2(4280, 600), 5.0))
	props.add_child(TownBuilder._rect_collider(Vector2(4280, 600), Vector2(52, 18), Vector2(0, -10)))
	for kb2: Vector2 in [Vector2(2870, 462), Vector2(3050, 458), Vector2(3070, 470), Vector2(4070, 466), Vector2(4250, 462)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", kb2, 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", Vector2(3456, 582), 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_09.png", Vector2(3290, 604), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_14.png", Vector2(3260, 590), 4.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_19.png", Vector2(3330, 616), 3.0))
	for fx: float in [-90.0, 90.0]:
		props.add_child(TownBuilder._sprite(STREET + "flag_1.png", KEEP_DOOR + Vector2(fx, 6.0), 0.0))
	for bx: float in [-120.0, 120.0]:
		var b := TownBuilder._sprite(STREET + "banner_pair_red.png", Vector2(3600.0 + bx, 400.0), 0.0)
		b.position.y = 400.0 + 0.6
		b.offset.y -= 150.0
		props.add_child(b)
	# --- CATHEDRAL: chapter house, almshouses, pots at the steps, hedges, beds,
	#     benches, lamps, climbing vines, the fenced churchyard with a dead oak
	_block(props, Vector2(4960, 640), 3, 2, "gate_small.png")
	props.add_child(TownBuilder._rect_collider(Vector2(4960, 640), Vector2(190.0, 30.0), Vector2(0, -15)))
	pass  # (almshouse folded into the avenue terrace)
	_house(props, lights, Vector2(4980, 1400), "gable", "purple", rng)
	_house(props, lights, Vector2(5820, 960), "gable", "slate", rng)
	_house(props, lights, Vector2(5820, 1400), "cottage", "slate", rng)
	_house(props, lights, Vector2(5990, 1400), "gable", "red", rng)
	_house(props, lights, Vector2(6300, 1400), "inn", "slate", rng)        # the Hospice of the Vigil
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(6520, 1400), 0.0))
	_bench(props, Vector2(6180, 1428))
	_bench(props, Vector2(6420, 1428))
	_hedge_run(props, Vector2(5900, 1470), Vector2(6500, 1470))
	for hb3: Vector2 in [Vector2(5940, 1440), Vector2(6540, 1440)]:
		props.add_child(TownBuilder._sprite(STREET + "flowerbed_5.png", hb3, 0.0))
	_lamp(props, lights, Vector2(6130, 1504))
	_lamp(props, lights, Vector2(6470, 1504))
	var cb := Vector2(CATH_SQ.x, 620.0)
	for ux: float in [-104.0, 104.0]:
		props.add_child(TownBuilder._sprite(STREET + "planter_roses.png", cb + Vector2(ux, 10.0), 0.0))
	_hedge_run(props, CATH_SQ + Vector2(-330, -90), CATH_SQ + Vector2(-330, 120))
	_hedge_run(props, CATH_SQ + Vector2(330, -90), CATH_SQ + Vector2(330, 120))
	for fb: Vector2 in [CATH_SQ + Vector2(-240, -200), CATH_SQ + Vector2(240, -200), CATH_SQ + Vector2(-240, 220), CATH_SQ + Vector2(240, 220)]:
		var beds: Array = ["flowerbed_1", "flowerbed_2", "flowerbed_5", "flowerbed_7", "flowerbed_9"]
		props.add_child(TownBuilder._sprite(STREET + beds[rng.randi_range(0, beds.size() - 1)] + ".png", fb, 0.0))
	for bp: Vector2 in [CATH_SQ + Vector2(-150, 70), CATH_SQ + Vector2(150, 70), CATH_SQ + Vector2(-150, -60), CATH_SQ + Vector2(150, -60), CATH_SQ + Vector2(-260, 10), CATH_SQ + Vector2(260, 10)]:
		_bench(props, bp)
	for py: float in [700.0, 780.0, 860.0]:
		for px2: float in [-96.0, 96.0]:
			props.add_child(TownBuilder._sprite(STREET + "planter_bigtree.png", Vector2(CATH_SQ.x + px2, py), 0.0))
			props.add_child(TownBuilder._circle_collider(Vector2(CATH_SQ.x + px2, py), 8.0, Vector2(0, -4)))
	props.add_child(TownBuilder._sprite(STREET + "board_0.png", Vector2(5100, 960), 0.0))
	for pp: Vector2 in [CATH_SQ + Vector2(-70, 110), CATH_SQ + Vector2(70, 110), CATH_SQ + Vector2(-200, 10), CATH_SQ + Vector2(200, 10)]:
		props.add_child(TownBuilder._sprite(STREET + "pot_shrub.png", pp, 0.0))
	for sk: Array in [[CATH_SQ + Vector2(-100, 40), 0], [CATH_SQ + Vector2(100, 46), 1], [CATH_SQ + Vector2(-20, 90), 2], [CATH_SQ + Vector2(30, 92), 0]]:
		props.add_child(TownBuilder._sprite(STREET + "stalk_%d.png" % int(sk[1]), sk[0], 0.0))
	_graves(props, decals, Vector2(5700, 380), 6, 3, rng)
	for fx2 in range(6):
		props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(5680.0 + fx2 * 88.0, 318.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(5680.0 + fx2 * 88.0, 590.0), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(5900, 318), Vector2(560, 10), Vector2.ZERO))
	props.add_child(TownBuilder._rect_collider(Vector2(5900, 590), Vector2(560, 10), Vector2.ZERO))
	props.add_child(TownBuilder._sprite(FREEKIT + "trees/tree_dead_oak.png", Vector2(6230, 400), 8.0))
	# --- THE CANDLE-HOUSE (MAGE pocket): sealed cottage in a hedged plot, the hedge
	#     NORTH of the cottage's roof line, one candle lit
	_house(props, lights, Vector2(6620, 900), "cottage", "purple", rng, false)
	lights.add_child(TownBuilder._light(Vector2(6640, 872), Color(1.0, 0.66, 0.30), 0.45, 48.0))
	props.add_child(TownBuilder._sprite(STREET + "ironfence_3.png", Vector2(6620, 924), 0.0))
	_hedge_run(props, Vector2(6480, 620), Vector2(6760, 620))
	_hedge_run(props, Vector2(6480, 630), Vector2(6480, 980))
	_hedge_run(props, Vector2(6760, 630), Vector2(6760, 980))
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(6540, 960), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "trees/tree_dead_gnarl.png", Vector2(6900, 700), 8.0))
	# --- the justice corner by the gate: gallows + stocks + a board
	props.add_child(TownBuilder._sprite(FREEKIT + "gallows.png", Vector2(6820, 2790), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(6820, 2790), Vector2(40.0, 14.0), Vector2(0, -7)))
	props.add_child(TownBuilder._sprite(FREEKIT + "stocks.png", Vector2(6900, 2810), 0.0))
	props.add_child(TownBuilder._sprite(STREET + "signboard_4.png", Vector2(6760, 2760), 0.0))
	# --- the burned farmstead (crime scene, SE commons)
	var bh := TownBuilder._place_building("house_06.png", Vector2(6840, 3960))
	bh.modulate = Color(0.36, 0.31, 0.29)
	props.add_child(bh)
	props.add_child(TownBuilder._sprite(FREEKIT + "cart_wheel.png", Vector2(6930, 3990), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "graves/grave_04.png", Vector2(6770, 3996), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "trees/tree_dead_reach.png", Vector2(6620, 3860), 8.0))
	# --- the fisher shacks on the SE track end
	_house(props, lights, Vector2(6560, 4200), "shed", "slate", rng, false)
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(6660, 4250), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(6500, 4250), 2.0))
	# --- lamps on the north-south streets (54 px off each centreline) + the approach
	var k: int = 0
	for ly: float in [1700.0, 2300.0, 2820.0, 3340.0, 3900.0]:
		_lamp(props, lights, Vector2(_x_at(SPINE, ly) + 60.0, ly))
	for ly2: float in [1800.0, 2080.0, 2900.0, 3400.0, 3900.0]:
		var ax: float = _x_at(AVENUE_S, ly2) + (60.0 if k % 2 == 0 else -60.0)
		_lamp(props, lights, Vector2(ax, ly2))
		k += 1
	for lp: Vector2 in [Vector2(2500, 880), Vector2(2760, 1040), Vector2(3560, 760), Vector2(3900, 1180), Vector2(4500, 1050), Vector2(4900, 1040),
			Vector2(3000, 1760), Vector2(4340, 1650), Vector2(4200, 1800), Vector2(6580, 2660), Vector2(6980, 2660)]:
		_lamp(props, lights, lp)
	for sg: Vector2 in [Vector2(2660, 1560), Vector2(3940, 2610), Vector2(5460, 2700), Vector2(3120, 4260), Vector2(4250, 1670), Vector2(3000, 1520)]:
		props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", sg, 2.0))
		props.add_child(TownBuilder._circle_collider(sg, 3.0, Vector2(0, -2)))
	var t: float = 0.05
	while t < 0.98:
		var i: int = int(t * float(CANAL_E.size() - 1))
		var a: Vector2 = CANAL_E[i]
		var b: Vector2 = CANAL_E[mini(i + 1, CANAL_E.size() - 1)]
		var p: Vector2 = a.lerp(b, t * float(CANAL_E.size() - 1) - float(i))
		var tp := p + Vector2(rng.randf_range(-20, 20), -82.0 - rng.randf_range(0.0, 30.0))
		if absf(tp.x - 4300.0) > 120.0 and absf(tp.x - 5400.0) > 120.0 and tp.x > 3720.0 and not (tp.x > 5860.0 and tp.x < 6500.0):
			props.add_child(_tree(props, tp, rng))
			props.add_child(TownBuilder._circle_collider(tp, 6.0, Vector2(0, -3)))
		t += 0.11


# --- walls ------------------------------------------------------------------
static func _wall_ew(props: Node2D, x0: float, x1: float, base_y: float, gap: Vector2 = Vector2(-1, -1)) -> void:
	var x: float = x0
	var i: int = 0
	while x + WALL_STEP <= x1 + 1.0:
		var cx: float = x + WALL_STEP * 0.5
		if gap.x >= 0.0 and cx > gap.x and cx < gap.y:
			x += WALL_STEP
			i += 1
			continue
		# v8: a fixed modulo put the same arch and the same crack on every 5th
		# bay, so the eye read a metronome. Seeded by position instead, with
		# flipped bays and a faint per-bay weathering.
		var wr := _rng(1000 + int(cx) + int(base_y))
		var tex: String = CASTLE + ("wall_face_b.png" if wr.randf() < 0.18 else "wall_face_a.png")
		var wsp := TownBuilder._sprite(tex, Vector2(cx, base_y), 0.0)
		wsp.flip_h = wr.randf() < 0.5
		var wv: float = wr.randf_range(0.93, 1.0)
		wsp.modulate = Color(wv, wv, wv)
		props.add_child(wsp)
		x += WALL_STEP
		i += 1
	if gap.x >= 0.0:
		props.add_child(TownBuilder._rect_collider(Vector2((x0 + gap.x) * 0.5, base_y - 14.0), Vector2(gap.x - x0, 28.0), Vector2.ZERO))
		props.add_child(TownBuilder._rect_collider(Vector2((gap.y + x1) * 0.5, base_y - 14.0), Vector2(x1 - gap.y, 28.0), Vector2.ZERO))
	else:
		props.add_child(TownBuilder._rect_collider(Vector2((x0 + x1) * 0.5, base_y - 14.0), Vector2(x1 - x0, 28.0), Vector2.ZERO))


static func _wall_ns(props: Node2D, left_x: float, y0: float, y1: float, gap: Vector2 = Vector2(-1, -1)) -> void:
	var cx: float = left_x + WALL_STEP * 0.5
	var y: float = y0 + 64.0
	while y < y1 - 32.0:
		if not (gap.x >= 0.0 and y > gap.x - 40.0 and y < gap.y + 40.0):
			props.add_child(TownBuilder._sprite(CASTLE + "wall_band.png", Vector2(cx, y), 0.0))
		y += 64.0
	props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", Vector2(cx, y1), 0.0))
	props.add_child(TownBuilder._sprite(CASTLE + "wall_cren.png", Vector2(cx, y0 + 26.0), 0.0))
	if gap.x >= 0.0:
		props.add_child(TownBuilder._rect_collider(Vector2(cx, (y0 + gap.x) * 0.5), Vector2(WALL_STEP, gap.x - y0), Vector2.ZERO))
		props.add_child(TownBuilder._rect_collider(Vector2(cx, (gap.y + y1) * 0.5), Vector2(WALL_STEP, y1 - gap.y), Vector2.ZERO))
	else:
		props.add_child(TownBuilder._rect_collider(Vector2(cx, (y0 + y1) * 0.5), Vector2(WALL_STEP, y1 - y0), Vector2.ZERO))


static func _tower_sq(props: Node2D, pos: Vector2) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + "tower_sq.png", pos, 0.0))
	props.add_child(TownBuilder._rect_collider(pos, Vector2(100.0, 30.0), Vector2(0, -15)))


static func _tower_round(props: Node2D, pos: Vector2, big: bool = false, cone: bool = false, tan: bool = false) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + ("tower_round_big.png" if big else "tower_round.png"), pos, 0.0))
	if cone:
		var c := Sprite2D.new()
		if tan:
			# v7: the granary â€” the dark cone at 0.5 read as a black obelisk
			c.texture = TownBuilder._region(CASTLE + "roof_cone_dark.png", Rect2(64, 0, 64, 217))   # the RED cone of the pair (roof_cone_tan.png is green)
			c.scale = Vector2(0.6, 0.6)
			c.offset = Vector2(-32.0, -217.0)
			c.modulate = Color(0.95, 0.88, 0.82)
		else:
			c.texture = TownBuilder._region(CASTLE + "roof_cone_dark.png", Rect2(0, 0, 64, 217))
			c.scale = Vector2(0.5, 0.5)
			c.offset = Vector2(-32.0, -217.0)
		c.centered = false
		c.position = pos + Vector2(0, -122.0)
		props.add_child(c)
	props.add_child(TownBuilder._rect_collider(pos, Vector2(112.0 if big else 56.0, 30.0), Vector2(0, -15)))


static func _gate_arch(props: Node2D, lights: Node2D, pos: Vector2, lit: bool = true) -> void:
	props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", pos, 0.0))
	props.add_child(TownBuilder._sprite(CASTLE + "gate_arch.png", pos + Vector2(0, 1.0), 0.0))
	if lit:
		for dx: float in [-44.0, 44.0]:
			props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", pos + Vector2(dx, -40.0), 0.0))
			lights.add_child(TownBuilder._light(pos + Vector2(dx, -48.0), WARM, 0.6, 80.0))


static func _east_gate(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var gx: float = MAP_W - INSET - WALL_STEP * 0.5
	_tower_sq(props, Vector2(gx, EAST_GATE.y - 54.0))
	_tower_sq(props, Vector2(gx, EAST_GATE.y + 182.0))
	var backing := Polygon2D.new()
	backing.polygon = PackedVector2Array([Vector2(gx - 34.0, EAST_GATE.y - 52.0), Vector2(gx + 34.0, EAST_GATE.y - 52.0),
		Vector2(gx + 34.0, EAST_GATE.y + 54.0), Vector2(gx - 34.0, EAST_GATE.y + 54.0)])
	backing.color = TUNNEL_DARK
	decals.add_child(backing)
	for dy: float in [-58.0, 62.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", Vector2(gx - 44.0, EAST_GATE.y + dy), 0.0))
		lights.add_child(TownBuilder._light(Vector2(gx - 44.0, EAST_GATE.y + dy - 10.0), WARM, 0.6, 80.0))
	lights.add_child(TownBuilder._light(Vector2(gx, EAST_GATE.y), Color(1.0, 0.74, 0.4), 0.3, 55.0))
	for fx: float in [-50.0, 50.0]:
		props.add_child(TownBuilder._sprite(STREET + "flag_1.png", Vector2(gx - 150.0, EAST_GATE.y + fx + 20.0), 0.0))


static func _outer_walls(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var x0: float = INSET + 64.0
	var x1: float = MAP_W - INSET - 64.0
	var top_base: float = INSET + WALL_H
	var bot_base: float = MAP_H - INSET
	_wall_ew(props, x0, x1, top_base)
	_wall_ew(props, x0, x1, bot_base)
	_wall_ns(props, INSET, top_base, bot_base - 64.0)
	_wall_ns(props, MAP_W - INSET - WALL_STEP, top_base, bot_base - 64.0, Vector2(EAST_GATE.y - 48.0, EAST_GATE.y + 48.0))
	for c: Vector2 in [Vector2(INSET + 64.0, top_base + 8.0), Vector2(MAP_W - INSET - 64.0, top_base + 8.0),
			Vector2(INSET + 64.0, bot_base + 8.0), Vector2(MAP_W - INSET - 64.0, bot_base + 8.0)]:
		_tower_round(props, c, false, true)
	var tx: float = x0 + 448.0
	while tx < x1 - 200.0:
		_tower_sq(props, Vector2(tx, bot_base + 8.0))
		_tower_sq(props, Vector2(tx, top_base + 8.0))
		tx += 448.0
	var ty: float = top_base + 384.0
	while ty < bot_base - 300.0:
		_tower_round(props, Vector2(INSET + 32.0, ty))
		if absf(ty - EAST_GATE.y) > 260.0:
			_tower_round(props, Vector2(MAP_W - INSET - 32.0, ty))
		ty += 384.0
	_east_gate(props, decals, lights)


# --- the Vigil Keep ---------------------------------------------------------
static func _keep(props: Node2D, lights: Node2D) -> void:
	var x0: float = 2800.0
	var x1: float = 4400.0
	var wall_base: float = KEEP_DOOR.y
	_wall_ew(props, x0, x1, wall_base, Vector2(KEEP_DOOR.x - 40.0, KEEP_DOOR.x + 40.0))
	_gate_arch(props, lights, Vector2(KEEP_DOOR.x, wall_base))
	_wall_ns(props, x0 - WALL_STEP, 136.0 + 32.0, wall_base - 64.0)
	_wall_ns(props, x1, 136.0 + 32.0, wall_base - 64.0)
	_tower_sq(props, Vector2(x0 - 32.0, wall_base + 8.0))
	_tower_sq(props, Vector2(x1 + 32.0, wall_base + 8.0))
	# v8: the map's primary landmark was a two-storey block LOWER than the
	# terrace roofs in front of it, and the stacked square towers repeated
	# their crenellation band mid-height. Three storeys with two round drums.
	var kb := Vector2(3600.0, 430.0)
	_block(props, kb, 4, 3, "gate_doors.png")
	for dx: float in [-164.0, 164.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "castle_tower_rd.png", kb + Vector2(dx, 10.0), 0.0))
		props.add_child(TownBuilder._rect_collider(kb + Vector2(dx, 10.0), Vector2(56.0, 30.0), Vector2(0, -15)))
	props.add_child(TownBuilder._rect_collider(kb, Vector2(260.0, 30.0), Vector2(0, -15)))
	for dx: float in [-70.0, 60.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", kb + Vector2(dx, -44.0), 0.0))
		lights.add_child(TownBuilder._light(kb + Vector2(dx, -52.0), WARM, 0.6, 85.0))
	_lamp(props, lights, Vector2(3380, 600), 0.65)
	_lamp(props, lights, Vector2(3820, 600), 0.65)


static func _block(props: Node2D, base: Vector2, cols: int, rows: int, door: String = "") -> void:
	var w: float = float(cols) * WALL_STEP
	for r in range(rows):
		var by: float = base.y - float(r) * (WALL_H - 4.0)
		for c in range(cols):
			var cx: float = base.x - w * 0.5 + WALL_STEP * (float(c) + 0.5)
			var tex: String = "wall_face_b.png" if (c + r) % 3 == 1 else "wall_face_a.png"
			var piece := TownBuilder._sprite(CASTLE + tex, Vector2(cx, by), 0.0)
			piece.z_index = 0
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


static func _tower_stack(props: Node2D, base: Vector2, n: int) -> void:
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
		props.add_child(TownBuilder._sprite(CASTLE + "wall_face_a.png", cb + Vector2(dx, 6.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "gothic_tower.png", cb + Vector2(dx, -90.0), 0.0))
		props.add_child(TownBuilder._sprite(CASTLE + "spire_tall.png", cb + Vector2(dx, -282.0), 0.0))
		props.add_child(TownBuilder._rect_collider(cb + Vector2(dx, 6.0), Vector2(60.0, 30.0), Vector2(0, -15)))
	props.add_child(TownBuilder._rect_collider(cb, Vector2(256.0, 30.0), Vector2(0, -15)))
	for dx: float in [-56.0, 56.0]:
		props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", cb + Vector2(dx, -44.0), 0.0))
		lights.add_child(TownBuilder._light(cb + Vector2(dx, -52.0), WARM, 0.6, 85.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "saint_statue.png", CATH_SQ + Vector2(0, 20), 0.0))
	props.add_child(TownBuilder._rect_collider(CATH_SQ + Vector2(0, 20), Vector2(40.0, 16.0), Vector2(0, -8)))
	for lp: Vector2 in [CATH_SQ + Vector2(-220, -120), CATH_SQ + Vector2(220, -120), CATH_SQ + Vector2(-220, 140), CATH_SQ + Vector2(220, 140)]:
		_lamp(props, lights, lp, 0.65)


# --- water colliders + bridges --------------------------------------------------
static func _water_colliders(props: Node2D) -> void:
	props.add_child(TownBuilder._rect_collider(Vector2(MAP_W * 0.5, RIVER_Y), Vector2(MAP_W, RIVER_HALF * 2.0 - 10.0), Vector2.ZERO))
	var bridges: Array = _bridge_list()
	for cw: Array in [[CANAL_N, CANAL_HALF], [CANAL_E, 34.0]]:
		var pts: Array = cw[0]
		var half: float = float(cw[1])
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n: int = maxi(1, int(a.distance_to(b) / 36.0))
			for k in range(n + 1):
				var c: Vector2 = a.lerp(b, float(k) / float(n))
				var open: bool = false
				for br: Array in bridges:
					if c.distance_to(br[0]) < 100.0:
						open = true
				if not open:
					props.add_child(TownBuilder._circle_collider(c, half + 4.0, Vector2.ZERO))
	_pond_collider(props, BASIN, 236.0, 90.0)


static func _bridges(props: Node2D) -> void:
	for br: Array in _bridge_list():
		var c: Vector2 = br[0]
		if String(br[1]) == "ew":
			for dx: float in [-48.0, 48.0]:
				var deck := TownBuilder._sprite(CASTLE + "deck_round.png", Vector2(c.x + dx, c.y + 48.0), 0.0)
				deck.z_index = -1
				props.add_child(deck)
			for dy: float in [-52.0, 44.0]:
				for dx2: float in [-46.0, 46.0]:
					props.add_child(TownBuilder._sprite(CASTLE + "fence_iron_a.png", Vector2(c.x + dx2, c.y + dy + 18.0), 0.0))
				props.add_child(TownBuilder._rect_collider(Vector2(c.x, c.y + dy + 4.0), Vector2(190.0, 8.0), Vector2.ZERO))
		else:
			for dy2: float in [c.y + 92.0, c.y - 2.0]:
				var deck2 := TownBuilder._sprite(CASTLE + "deck_round.png", Vector2(c.x, dy2), 0.0)
				deck2.z_index = -1
				props.add_child(deck2)
				for dx3: float in [-46.0, 46.0]:
					props.add_child(TownBuilder._sprite(CASTLE + "railing_wood.png", Vector2(c.x + dx3, dy2 + 2.0), 0.0))
			for dx4: float in [-52.0, 52.0]:
				props.add_child(TownBuilder._rect_collider(Vector2(c.x + dx4, c.y), Vector2(8.0, 190.0), Vector2.ZERO))


# --------------------------------------------------------------- CANOPY ------
## A leafy tree on the zone builder's shared GPU sway shader (phase from world
## position, roots planted). Collider is the caller's.
static func _swaying(path: String, pos: Vector2, skirt: float = 10.0) -> Sprite2D:
	var s := TownBuilder._sprite(path, pos, skirt)
	s.material = ZoneBuilder._tree_sway_material()
	s.set_meta("canopy", true)
	return s


## v8: a soft pool under every tree (the v7 canopy shadow only fired for trees
## scaled above 1.0, so the orchards, copses and square trees floated).
static func _canopy_shadow(decals: Node2D, pos: Vector2, sc: float) -> void:
	var sh := Sprite2D.new()
	sh.texture = _radial_tex()
	sh.position = pos + Vector2(14.0 * sc, 2.0)
	sh.scale = Vector2(0.62 * sc, 0.30 * sc)
	sh.modulate = Color(0.05, 0.04, 0.03, 0.22)
	decals.add_child(sh)


# --------------------------------------------------------------- TONAL -------
static var _radial: GradientTexture2D = null


static func _radial_tex() -> GradientTexture2D:
	if _radial != null:
		return _radial
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_radial = tex
	return tex


## Soft tonal patches over the whole city ground (Painting Bible: the ground
## must never read as one flat colour field at any zoom): large dark/mossy
## blobs at low alpha plus a finer scatter, on the decal layer above the
## tiles and under every prop. The village keeps its own dressing.
static func _tonal(decals: Node2D) -> void:
	var rng := _rng(21)
	var rtex: Texture2D = _radial_tex()
	for i in range(110):
		var mp := Vector2(rng.randf_range(160.0, MAP_W - 160.0), rng.randf_range(200.0, MAP_H - 160.0))
		if mp.x < 2240.0 and mp.y < 1600.0:
			continue
		if _near_water(mp, 50.0):
			continue
		var blob := Sprite2D.new()
		blob.texture = rtex
		blob.position = mp
		var bs: float = rng.randf_range(2.6, 8.0)
		blob.scale = Vector2(bs * rng.randf_range(1.0, 1.9), bs)
		if rng.randf() < 0.55:
			blob.modulate = Color(0.16, 0.13, 0.09, rng.randf_range(0.05, 0.10))
		else:
			blob.modulate = Color(0.42, 0.40, 0.18, rng.randf_range(0.04, 0.08))
		decals.add_child(blob)
	# v7: green mottling on the open lawns (the fields' commons, the churchyard
	# meadows, the south bank) so no lawn reads as one flat tile at any zoom
	for m in range(640):
		var mp2 := Vector2(rng.randf_range(160.0, MAP_W - 160.0), rng.randf_range(200.0, MAP_H - 160.0))
		if mp2.x < 2240.0 and mp2.y < 1600.0:
			continue
		if _near_water(mp2, 60.0) or _on_street(mp2) or _on_soil(mp2):
			continue
		var gb := Sprite2D.new()
		gb.texture = rtex
		gb.position = mp2
		var gs: float = rng.randf_range(1.5, 4.2)
		gb.scale = Vector2(gs * rng.randf_range(1.0, 1.8), gs)
		if rng.randf() < 0.6:
			gb.modulate = Color(0.20, 0.34, 0.14, rng.randf_range(0.14, 0.24))
		else:
			gb.modulate = Color(0.70, 0.78, 0.36, rng.randf_range(0.08, 0.16))
		decals.add_child(gb)
	for j in range(520):
		var sp2 := Vector2(rng.randf_range(140.0, MAP_W - 140.0), rng.randf_range(180.0, MAP_H - 140.0))
		if sp2.x < 2240.0 and sp2.y < 1600.0:
			continue
		if _near_water(sp2, 30.0):
			continue
		var b2 := Sprite2D.new()
		b2.texture = rtex
		b2.position = sp2
		var s2: float = rng.randf_range(0.7, 2.2)
		b2.scale = Vector2(s2 * rng.randf_range(1.0, 1.6), s2)
		var r2: float = rng.randf()
		if r2 < 0.6:
			b2.modulate = Color(0.12, 0.10, 0.07, rng.randf_range(0.10, 0.22))
		elif r2 < 0.85:
			b2.modulate = Color(0.40, 0.38, 0.16, rng.randf_range(0.08, 0.16))
		else:
			b2.modulate = Color(0.95, 0.90, 0.70, rng.randf_range(0.06, 0.10))
		decals.add_child(b2)


# --------------------------------------------------------------- HARBOUR -----
## v8: standing on the harbour square the player could not see water, a quay
## edge or anything taller than a stall. The square moved south onto the lip;
## this draws the lip itself (a wet dark line with a pale highlight), railings
## between the pier heads, a watch tower at the west end and the big anchor as
## the square's monument.
static func _harbor_edge(props: Node2D, lights: Node2D) -> void:
	var decals: Node = props.get_parent().get_node_or_null("Decals")
	var piers: Array = [2900.0, 3500.0, 3900.0]
	if decals != null:
		var segs: Array = [[2600.0, 2810.0], [2990.0, 3410.0], [3590.0, 3810.0], [3990.0, 4700.0]]
		for sg: Array in segs:
			var lip := Line2D.new()
			lip.points = PackedVector2Array([Vector2(float(sg[0]), 4558.0), Vector2(float(sg[1]), 4558.0)])
			lip.width = 6.0
			lip.default_color = Color(0.20, 0.17, 0.15, 0.80)
			decals.add_child(lip)
			var hi := Line2D.new()
			hi.points = PackedVector2Array([Vector2(float(sg[0]), 4552.0), Vector2(float(sg[1]), 4552.0)])
			hi.width = 2.0
			hi.default_color = Color(0.88, 0.85, 0.80, 0.55)
			decals.add_child(hi)
	var x: float = 2760.0
	while x < 4650.0:
		var clear: bool = true
		for px: float in piers:
			if absf(x - px) < 90.0:
				clear = false
		if clear and absf(x - HARBOR_SQ.x) > 120.0:
			props.add_child(TownBuilder._sprite(FREEKIT + "dock_railing.png", Vector2(x, 4552.0), 0.0))
		x += 96.0
	props.add_child(TownBuilder._sprite(FREEKIT + "castle_tower_rd.png", Vector2(2752.0, 4548.0), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(2752.0, 4548.0), Vector2(56.0, 30.0), Vector2(0, -15)))
	lights.add_child(TownBuilder._light(Vector2(2752.0, 4300.0), Color(1.0, 0.80, 0.50), 0.45, 120.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "anchor_large.png", HARBOR_SQ + Vector2(-70, -30), 0.0))
	props.add_child(TownBuilder._rect_collider(HARBOR_SQ + Vector2(-70, -30), Vector2(40.0, 14.0), Vector2(0, -7)))


# --------------------------------------------------------------- SIGNS -------
## Hanging trade signs on the LPC decorations sheet (32 px grid, probed:
## row y0 = blank / sword / jug / bread / bag, row y32 = book / tankard / INN /
## necklace / hammer+tongs). Hung at eave height opposite the wall lamp.
const SIGNS := {
	"shop": [Rect2(256, 0, 32, 32), Rect2(288, 0, 32, 32), Rect2(320, 0, 32, 32), Rect2(288, 32, 32, 32)],
	"work": [Rect2(224, 0, 32, 32), Rect2(320, 32, 32, 32)],
	"inn": [Rect2(224, 32, 32, 32), Rect2(256, 32, 32, 32)],
	"cross": [Rect2(320, 0, 32, 32), Rect2(192, 32, 32, 32)],
	"town": [Rect2(192, 32, 32, 32), Rect2(288, 32, 32, 32)],
}


## v8: a destination on every other lamp gap - a covered well, a wayside shrine
## or a notice board. Four terrace frames in the audit had nothing to walk to.
static func _street_feature(props: Node2D, lights: Node2D, p: Vector2, idx: int, gaps: Array) -> void:
	if _near_water(p, 60.0) or _on_square(p):
		return
	for g: float in gaps:
		if absf(p.x - g) < 130.0:
			return
	match idx % 3:
		0:
			var well := Sprite2D.new()
			well.texture = TownBuilder._region(FREEKIT + "well_covered.png", Rect2(32, 4, 64, 91))
			well.centered = false
			well.offset = Vector2(-32.0, -87.0)
			well.scale = Vector2(0.78, 0.78)
			well.position = p
			props.add_child(well)
			props.add_child(TownBuilder._rect_collider(p, Vector2(40.0, 14.0), Vector2(0, -7)))
		1:
			props.add_child(TownBuilder._sprite(FREEKIT + "statue_a.png", p, 0.0))
			props.add_child(TownBuilder._rect_collider(p, Vector2(22.0, 10.0), Vector2(0, -5)))
			_candelabrum(props, p + Vector2(26, 6), 0.5)
			lights.add_child(TownBuilder._light(p + Vector2(26, -34), Color(1.0, 0.68, 0.32), 0.35, 52.0))
			props.add_child(TownBuilder._sprite(STREET + "flowerbed_5.png", p + Vector2(-32, 8), 0.0))
		_:
			props.add_child(TownBuilder._sprite(STREET + "board_0.png", p, 0.0))
			props.add_child(TownBuilder._rect_collider(p, Vector2(36.0, 10.0), Vector2(0, -5)))
			_bench(props, p + Vector2(46, 4))


## v8: one bush, varied (flip, scale, four tints) - the commons scatter was one
## upright sprite at one size and one colour, thirteen to a frame.
static func _bush(p: Vector2, rng: RandomNumberGenerator) -> Sprite2D:
	var b := TownBuilder._sprite(PLANTS + "plant_%02d.png" % rng.randi_range(3, 8), p, 3.0)
	b.flip_h = rng.randf() < 0.5
	var bs: float = rng.randf_range(0.80, 1.15)
	b.scale = Vector2(bs, bs)
	if rng.randf() < 0.2:
		b.modulate = Color(1.0, 0.92, 0.70)
	else:
		b.modulate = Color(rng.randf_range(0.84, 1.0), rng.randf_range(0.90, 1.0), rng.randf_range(0.76, 0.90))
	return b


# --------------------------------------------------------------- WINDOWS -----
## Window rects measured on each house sprite at 3x (scratchpad
## v8_houses_probe.png). Sprite pixels, top-left origin. The pane is an
## additive quad the size of the glass with a soft spill under the sill, both
## dark until city_ambience.gd lights them at 17:00 - Stardew, Witchbrook and
## Graveyard Keeper all sell night with amber windows before anything else.
const SKIRT := {"cottage": 37, "gable": 28, "cross": 29, "shop": 10, "work": 0, "barn": 42, "shed": 15, "inn": 53, "town": 0}
const WINDOWS := {
	"cottage": [Rect2(33, 150, 18, 17), Rect2(96, 150, 18, 17), Rect2(60, 105, 28, 14)],
	"gable": [Rect2(62, 135, 17, 17), Rect2(94, 135, 17, 17)],
	"cross": [Rect2(70, 215, 18, 20), Rect2(102, 215, 18, 20)],
	"shop": [Rect2(71, 133, 17, 17), Rect2(102, 133, 17, 17), Rect2(40, 180, 18, 22), Rect2(100, 180, 18, 22)],
	"work": [],   # probe could not confirm a glass rect on house_00
	"barn": [],   # house_03's opening is a barn door, not a window
	"inn": [Rect2(39, 182, 18, 21), Rect2(103, 182, 18, 21), Rect2(327, 182, 18, 21), Rect2(72, 133, 15, 15), Rect2(263, 133, 15, 15)],
	"shed": [],
}
static var _white_tex: ImageTexture = null


static func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


## Lit panes for one house, in node-local coordinates (added before the mirror
## pass so a mirrored house keeps its windows). 65% of houses light up; inns
## always do; a third of them stay lit after 23:00.
static func _windows(node: Node2D, kind: String, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var rects: Array = WINDOWS.get(kind, [])
	if kind == "town":
		rects = [Rect2(-46, -35, 24, 27), Rect2(22, -35, 24, 27)]
	elif rects.is_empty():
		return
	if kind != "inn" and rng.randf() > 0.85:
		return
	var late: bool = rng.randf() < 0.3
	for r_v: Variant in rects:
		var r: Rect2 = r_v
		var local: Vector2 = r.position + r.size * 0.5
		if kind != "town":
			local = Vector2(r.position.x + r.size.x * 0.5 - w * 0.5, r.position.y + r.size.y * 0.5 - h + 8.0)
		var pane := Sprite2D.new()
		pane.texture = _white()
		pane.scale = r.size
		pane.position = local
		pane.modulate = Color(1.0, 0.72, 0.36, 0.0)
		var pm := CanvasItemMaterial.new()
		pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		pane.material = pm
		pane.set_meta("lit_alpha", rng.randf_range(0.45, 0.70))
		pane.set_meta("late", late)
		pane.add_to_group("city_windows")
		node.add_child(pane)
		var spill := Sprite2D.new()
		spill.texture = _radial_tex()
		spill.position = local + Vector2(0.0, r.size.y * 0.55)
		spill.scale = Vector2(r.size.x * 2.4 / 128.0, r.size.y * 1.8 / 128.0)
		spill.modulate = Color(1.0, 0.70, 0.35, 0.0)
		var sm := CanvasItemMaterial.new()
		sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spill.material = sm
		spill.set_meta("lit_alpha", 0.20)
		spill.set_meta("late", late)
		spill.add_to_group("city_windows")
		node.add_child(spill)


# --------------------------------------------------------------- SMOKE -------
static var _puff_tex: GradientTexture2D = null


static func _puff() -> GradientTexture2D:
	if _puff_tex != null:
		return _puff_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 24
	t.height = 24
	_puff_tex = t
	return t


## v8: a readable plume. TownBuilder._chimney_smoke stays untouched (the frozen
## village calls it): its 16 px puffs fade before they grow, so at play zoom a
## chimney gives a 1-2 px ghost and the open fires give nothing at all.
static func _smoke(pos: Vector2, fire: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _puff()
	p.amount = 12 if fire else 18
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.direction = Vector2(0.2, -1.0)
	p.spread = 17.0
	p.gravity = Vector2(4, -8)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 1.0 if fire else 1.2
	p.scale_amount_max = 2.0 if fire else 2.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	if fire:
		ramp.colors = PackedColorArray([Color(0.50, 0.48, 0.47, 0.55), Color(0.62, 0.61, 0.60, 0.34), Color(0.7, 0.7, 0.7, 0.0)])
	else:
		ramp.colors = PackedColorArray([Color(0.88, 0.86, 0.84, 0.44), Color(0.88, 0.88, 0.88, 0.26), Color(0.9, 0.9, 0.9, 0.0)])
	p.color_ramp = ramp

	p.z_index = 4
	return p


# --------------------------------------------------------------- STALLS ------
## v8: szadi_awning.png bakes a 40-54% black ground shade into rows 49-69
## (probe: rows 0-48 thatch at alpha 255, 49-68 the shade, 70-82 the two poles
## at x 8-11 and 86-89). The stall sorts behind its vendor, so that shade fell
## on the NPC and every merchant read as a black cut-out. The roof is cropped
## to the thatch, the poles are redrawn, and the shade goes on the ground.
static func _stall_shade(props: Node2D, stall: Node2D, pos: Vector2) -> void:
	stall.set_meta("shadow_w", 96.0)
	stall.set_meta("shadow_h", 26.0)
	var tr := _rng(int(pos.x) + int(pos.y) * 3)
	for ch in stall.get_children():
		var s: Sprite2D = ch as Sprite2D
		if s == null or s.texture == null:
			continue
		if not s.texture.resource_path.ends_with("szadi_awning.png"):
			continue
		s.flip_h = tr.randf() < 0.5
		var av: float = tr.randf()
		if av < 0.33:
			s.modulate = Color(0.90, 0.86, 0.78)
		elif av < 0.6:
			s.modulate = Color(0.80, 0.78, 0.70)
		var tex: Texture2D = s.texture
		s.texture = TownBuilder._region(tex.resource_path, Rect2(0, 0, 97, 49))
		for px: float in [8.0, 86.0]:
			var pole := Sprite2D.new()
			pole.texture = TownBuilder._region(tex.resource_path, Rect2(px, 49, 4, 34))
			pole.centered = false
			pole.offset = Vector2(s.offset.x + px, s.offset.y + 49.0)
			pole.position = s.position
			stall.add_child(pole)
		break
	var decals_n: Node = props.get_parent().get_node_or_null("Decals")
	if decals_n != null:
		var shade := Sprite2D.new()
		shade.texture = _radial_tex()
		shade.position = pos + Vector2(0, -26)
		shade.scale = Vector2(0.82, 0.24)
		shade.modulate = Color(0.05, 0.03, 0.02, 0.30)
		decals_n.add_child(shade)


# --------------------------------------------------------------- TORCHES -----
## v8: a wall torch that obeys the clock. The flame joins "city_flames" and an
## iron sconce (frame 0 of the strip with the flame rows cropped off) joins
## "city_brackets"; city_ambience swaps them at 17:00/06:30, so the keep no
## longer burns nine torches under a noon sky next to unlit lanterns.
static func _torch_day_night(props: Node2D, lights: Node2D, pos: Vector2) -> void:
	var before: int = props.get_child_count()
	TownBuilder._torch(props, lights, pos)
	for i in range(before, props.get_child_count()):
		var n: Node = props.get_child(i)
		if n is AnimatedSprite2D:
			n.add_to_group("city_flames")
	var bracket := Sprite2D.new()
	bracket.texture = TownBuilder._region("res://assets/art/world/civic/torch_anim_strip.png", Rect2(0, 14, 32, 18))
	bracket.centered = false
	bracket.offset = Vector2(-16, -14)
	bracket.position = pos
	bracket.add_to_group("city_brackets")
	props.add_child(bracket)


# --------------------------------------------------------------- PARTS -------
## Szadi Fantasy Lands building parts (probe: scratchpad/parts_composite_probe.png,
## every rect verified on the sheet and every slot verified on its house at 3x).
const PARTS_SHEET := BUILDINGS + "szadi_building_parts.png"
const PARTS := {
	"dormer": Rect2(610, 224, 28, 38), "cap": Rect2(640, 245, 32, 23),
	"chimney_a": Rect2(583, 156, 18, 29), "chimney_b": Rect2(615, 182, 18, 25), "chimney_wood": Rect2(448, 160, 26, 38),
	"door_a": Rect2(480, 22, 32, 42), "door_c": Rect2(478, 86, 34, 44),
	"window": Rect2(452, 242, 24, 27), "window_tiny": Rect2(392, 168, 14, 18), "hatch": Rect2(713, 267, 14, 14),
	"roof_tall": Rect2(238, 0, 132, 161), "wall_timber": Rect2(247, 161, 114, 63), "wall_brick": Rect2(247, 224, 114, 64),
	"planks": Rect2(123, 256, 42, 24), "cross_x": Rect2(642, 195, 28, 28),
}


## One part glued to a house node, bottom-centre at `local` (centered sprite so
## _mirror_children mirrors it correctly).
static func _part(node: Node2D, part: String, local: Vector2) -> Sprite2D:
	var r: Rect2 = PARTS[part]
	var s := Sprite2D.new()
	s.texture = TownBuilder._region(PARTS_SHEET, r)
	s.position = local + Vector2(0.0, -r.size.y * 0.5)
	node.add_child(s)
	return s


## 0-3 attachments per house so no two neighbours share a silhouette. Returns
## the smoke anchor (the barn only smokes when it gets its wooden chimney: the
## sheet's house_03 has none and the old anchor sat on a shutter window).
static func _attach_parts(node: Node2D, kind: String, ch: Vector2, rng: RandomNumberGenerator) -> Vector2:
	match kind:
		"cottage":
			var d: float = rng.randf()
			if d < 0.3:
				_part(node, "dormer", Vector2(-36, -111))
			elif d < 0.6:
				_part(node, "dormer", Vector2(38, -119))
			if rng.randf() < 0.25:
				_part(node, "cap", Vector2(0, -215))
			if rng.randf() < 0.3:
				_part(node, "chimney_b", Vector2(-40, -170))
				if rng.randf() < 0.5:
					ch = Vector2(-40, -197)
		"gable":
			var d2: float = rng.randf()
			if d2 < 0.35:
				_part(node, "dormer", Vector2(44, -116))
			elif d2 < 0.6:
				_part(node, "dormer", Vector2(-44, -94))
			if rng.randf() < 0.4:
				_part(node, "window_tiny", Vector2(0, -128))
		"cross":
			if rng.randf() < 0.4:
				_part(node, "dormer", Vector2(-60, -150))
		"shop":
			_part(node, "door_a" if rng.randf() < 0.5 else "door_c", Vector2(0, 2))   # house_06 has no door
		"work":
			if rng.randf() < 0.4:
				_part(node, "dormer", Vector2(72, -84))
		"barn":
			if rng.randf() < 0.55:
				_part(node, "chimney_wood", Vector2(-40, -224))
				ch = Vector2(-40, -262)
			else:
				ch = Vector2.ZERO
		"inn":
			if rng.randf() < 0.5:
				_part(node, "chimney_a", Vector2(-140, -196))
	return ch


## The 9th silhouette: a narrow half-timbered townhouse composited from the
## parts sheet (brick ground floor, timber upper floor, tall gable), 132x278.
static func _townhouse(node: Node2D, rng: RandomNumberGenerator) -> void:
	_part(node, "wall_brick", Vector2(0, 0))
	_part(node, "wall_timber", Vector2(0, -64))
	_part(node, "roof_tall", Vector2(0, -117))
	_part(node, "door_a" if rng.randf() < 0.5 else "door_c", Vector2(0, 0))
	_part(node, "window", Vector2(-34, -8))
	_part(node, "window", Vector2(34, -8))
	_part(node, "chimney_a", Vector2(-30, -200))
	if rng.randf() < 0.6:
		_part(node, "window_tiny", Vector2(0, -160))
	else:
		_part(node, "hatch", Vector2(0, -150))


## v7: doorstep clutter - 3-5 pieces that say who lives here, packed from the
## front's two corners toward the door (Bible: clusters owned by a door; pieces
## either overlap or stand >= 20 px apart, never kissing).
static func _doorstep(props: Node2D, pos: Vector2, kind: String, w: float, mirrored: bool, rng: RandomNumberGenerator) -> void:
	var door_x: float = 0.0
	var pieces: Array = []
	var pot_tint := Color(0.76, 0.72, 0.70)
	match kind:
		"cottage":
			pieces = [[STREET + "pot_3.png", 30.0, pot_tint], [STREET + "bench_1.png", 28.0, Color.WHITE], [STREET + "pot_1.png", 19.0, Color.WHITE], [PROPS + "cainos_prop_23.png", 23.0, Color.WHITE], [STREET + "pot_4.png", 30.0, pot_tint], [STREET + "pot_5.png", 23.0, pot_tint], [STREET + "pot_blue.png", 32.0, Color.WHITE], [PROPS + "cainos_prop_31.png", 23.0, Color.WHITE], [PROPS + "szadi_prop_31.png", 13.0, Color.WHITE], [STREET + "urn.png", 32.0, Color(0.82, 0.80, 0.76)]]
		"gable":
			pieces = [[PROPS + "szadi_prop_08.png", 20.0, Color.WHITE], [PROPS + "szadi_prop_24.png", 19.0, Color.WHITE], [PROPS + "szadi_prop_30.png", 26.0, Color.WHITE], [STREET + "pot_2.png", 18.0, Color.WHITE], [PROPS + "szadi_prop_12.png", 31.0, Color.WHITE], [PROPS + "szadi_prop_33.png", 31.0, Color.WHITE], [STREET + "barrel_1.png", 23.0, Color.WHITE], [STREET + "pot_6.png", 23.0, pot_tint], [PROPS + "cainos_prop_01.png", 37.0, Color.WHITE]]
		"shop":
			pieces = [[STREET + ["goods_2", "goods_3", "goods_7"][rng.randi_range(0, 2)] + ".png", 60.0, Color.WHITE], [STREET + "barrel_9.png", 33.0, Color.WHITE], [PROPS + "szadi_prop_09.png", 22.0, Color.WHITE], [STREET + "goods_11.png", 25.0, Color.WHITE], [STREET + "goods_12.png", 24.0, Color.WHITE], [STREET + "barrel_3.png", 32.0, Color.WHITE], [PROPS + "cainos_prop_18.png", 31.0, Color.WHITE], [STREET + "pot_red.png", 32.0, Color.WHITE]]
		"work":
			door_x = 40.0
			pieces = [[PROPS + "szadi_prop_10.png", 17.0, Color.WHITE], [PROPS + "szadi_prop_18.png", 31.0, Color.WHITE], [PROPS + "szadi_prop_19.png", 30.0, Color.WHITE], [PROPS + "szadi_prop_30.png", 26.0, Color.WHITE], [PROPS + "szadi_prop_22.png", 17.0, Color.WHITE], [PROPS + "szadi_prop_23.png", 26.0, Color.WHITE], [PROPS + "szadi_prop_25.png", 26.0, Color.WHITE], [PROPS + "szadi_prop_15.png", 53.0, Color.WHITE]]
		"barn":
			pieces = [[PROPS + "szadi_prop_21.png", 29.0, Color.WHITE], [STREET + "haybale_2.png", 44.0, Color.WHITE], [PROPS + "szadi_prop_14.png", 42.0, Color.WHITE], [STREET + "haybale_3.png", 44.0, Color.WHITE], [PROPS + "szadi_prop_13.png", 31.0, Color.WHITE], [PROPS + "szadi_prop_15.png", 53.0, Color.WHITE]]
		"cross":
			door_x = 50.0
			pieces = [[PROPS + "szadi_prop_32.png", 53.0, Color.WHITE], [STREET + "pot_shrub.png", 32.0, Color.WHITE], [STREET + "bench_2.png", 28.0, Color.WHITE]]
		"inn":
			door_x = -60.0
			pieces = [[STREET + "barrel_3.png", 32.0, Color.WHITE], [STREET + "goods_1.png", 60.0, Color.WHITE], [STREET + "bench_1.png", 28.0, Color.WHITE], [PROPS + "cainos_prop_18.png", 31.0, Color.WHITE], [STREET + "barrel_1.png", 23.0, Color.WHITE], [STREET + "bench_3.png", 36.0, Color.WHITE], [PROPS + "cainos_prop_27.png", 28.0, Color.WHITE], [STREET + "goods_13.png", 22.0, Color.WHITE]]
		"town":
			pieces = [[STREET + "pot_3.png", 30.0, pot_tint], [PROPS + "szadi_prop_08.png", 20.0, Color.WHITE], [STREET + "bench_1.png", 28.0, Color.WHITE]]
		_:
			return
	if mirrored:
		door_x = -door_x
	for i in range(pieces.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Array = pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = tmp
	var n: int = mini(pieces.size(), rng.randi_range(3, 5))
	var cursor_l: float = -w * 0.5 + 10.0
	var cursor_r: float = w * 0.5 - 10.0
	var use_left: bool = rng.randf() < 0.5
	var placed: int = 0
	for pc: Array in pieces:
		if placed >= n:
			break
		var pw: float = float(pc[1])
		var x: float = 0.0
		var ok: bool = false
		for _attempt in range(2):
			if use_left:
				if cursor_l + pw <= door_x - 26.0:
					x = cursor_l + pw * 0.5
					cursor_l += pw + (rng.randf_range(20.0, 30.0) if rng.randf() < 0.6 else -pw * 0.3)
					ok = true
			elif cursor_r - pw >= door_x + 26.0:
				x = cursor_r - pw * 0.5
				cursor_r -= pw + (rng.randf_range(20.0, 30.0) if rng.randf() < 0.6 else -pw * 0.3)
				ok = true
			if ok:
				break
			use_left = not use_left
		if not ok:
			break
		var wp: Vector2 = pos + Vector2(x + rng.randf_range(-3.0, 3.0), rng.randf_range(10.0, 15.0))
		if _near_folk(wp, 34.0):
			use_left = not use_left
			continue
		var sp := TownBuilder._sprite(String(pc[0]), wp, 3.0)
		sp.modulate = pc[2]
		sp.flip_h = rng.randf() < 0.5
		props.add_child(sp)
		use_left = not use_left
		placed += 1


# --------------------------------------------------------------- TREES -------
## v7: one tree, varied per instance (Bible: never two identical trees side by
## side): kind roll (leafy / dead / rust hero / birch), scale 0.85-1.2, 50%
## flip, four muted colour buckets, and a soft canopy shadow on the ground for
## the big ones. Returns the sprite; the caller adds it (and its collider).
static func _tree(props: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> Sprite2D:
	var roll: float = rng.randf()
	var s: Sprite2D
	var sc: float = rng.randf_range(0.85, 1.2)
	if roll < 0.08:
		s = _swaying(FREEKIT + "trees/tree_dead_%s.png" % ["crook", "gnarl", "reach", "snag"][rng.randi_range(0, 3)], pos, 8.0)
		s.modulate = Color(0.82, 0.78, 0.74)
		sc = rng.randf_range(0.75, 0.9)
	elif roll < 0.10:
		s = _swaying(FREEKIT + "trees/tree_dead_oak.png", pos, 8.0)
		s.modulate = Color(0.90, 0.82, 0.74)
		sc = 0.8
	elif roll < 0.13:
		s = _swaying("res://assets/art/world/deadforest/birch_dead.png", pos, 12.0)
		sc = 0.9
	else:
		s = _swaying(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2), pos, 10.0)
		var b: float = rng.randf()
		if b < 0.45:
			s.modulate = Color(rng.randf_range(0.80, 0.90), rng.randf_range(0.92, 1.0), rng.randf_range(0.72, 0.84))
		elif b < 0.75:
			s.modulate = Color(rng.randf_range(0.96, 1.0), rng.randf_range(0.96, 1.0), rng.randf_range(0.90, 1.0))
		elif b < 0.90:
			s.modulate = Color(1.0, rng.randf_range(0.80, 0.88), rng.randf_range(0.62, 0.72))
		else:
			s.modulate = Color(rng.randf_range(0.64, 0.72), rng.randf_range(0.68, 0.76), rng.randf_range(0.60, 0.68))
	s.scale = Vector2(sc, sc)
	s.flip_h = rng.randf() < 0.5
	var decals_n: Node = props.get_parent().get_node_or_null("Decals")
	if decals_n != null:
		_canopy_shadow(decals_n, pos, sc)
	return s


# --------------------------------------------------------------- LAMPS -------
static var _lantern_lit_tex: AtlasTexture = null
static var _lantern_unlit_tex: AtlasTexture = null


static func _lantern_tex(lit: bool) -> AtlasTexture:
	if lit:
		if _lantern_lit_tex == null:
			_lantern_lit_tex = TownBuilder._region(TownBuilder.DECOR, TownBuilder.R_LANTERN_LIT)
		return _lantern_lit_tex
	if _lantern_unlit_tex == null:
		_lantern_unlit_tex = TownBuilder._region(TownBuilder.DECOR, Rect2(396, 64, 24, 32))   # the grey-glass day twin (probe: scratchpad/lantern_probe.png)
	return _lantern_unlit_tex


## The city's LPC pole lantern: the glass is swapped lit/unlit by
## city_ambience.gd (group "city_lanterns"); the village keeps TownBuilder's.
static func _city_post(pos: Vector2, style: int = -1) -> Node2D:
	var post := Node2D.new()
	post.position = pos
	post.set_meta("shadow_w", 16.0)
	post.set_meta("shadow_h", 7.0)
	var pole := Sprite2D.new()
	pole.texture = TownBuilder._region(TownBuilder.DECOR, TownBuilder.R_POLE)
	pole.centered = false
	pole.offset = Vector2(-12.0, -77.0)
	post.add_child(pole)
	# v8: three heads instead of ninety copies of one. Style is seeded by
	# position so a street mixes but a given post is stable.
	var st: int = style
	if st < 0:
		st = (int(pos.x / 7.0) + int(pos.y / 11.0)) % 3
	pole.flip_h = (int(pos.x) % 2) == 0
	var lamp := Sprite2D.new()
	lamp.texture = _lantern_tex(true) if st != 1 else TownBuilder._region(TownBuilder.DECOR, Rect2(423, 32, 26, 32))
	lamp.position = Vector2(0, -62)
	if st == 1:
		lamp.set_meta("lit_tex", TownBuilder._region(TownBuilder.DECOR, Rect2(423, 32, 26, 32)))
		lamp.set_meta("unlit_tex", TownBuilder._region(TownBuilder.DECOR, Rect2(392, 32, 26, 32)))
	else:
		lamp.set_meta("lit_tex", _lantern_tex(true))
		lamp.set_meta("unlit_tex", _lantern_tex(false))
	lamp.add_to_group("city_lanterns")
	# v8: a soft additive bloom on the glass. A lit lantern with a hard yellow
	# block and no glow is the "sprite swapped, lighting forgotten" look.
	var halo := Sprite2D.new()
	halo.texture = _radial_tex()
	halo.position = Vector2(0, -62)
	halo.scale = Vector2(0.34, 0.34)
	halo.modulate = Color(1.0, 0.82, 0.45, 0.55)
	var hm := CanvasItemMaterial.new()
	hm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = hm
	halo.add_to_group("city_glow")
	post.add_child(halo)
	post.add_child(lamp)
	return post


# --------------------------------------------------------------- SHADOWS -----
## v7: a soft contact shadow under every free-standing prop placed by
## TownBuilder._sprite in the city (crates, barrels, trees, walls, stones),
## so nothing floats on the ground. Flat things (beds, crops, fence rails,
## bridge decks) are skipped; houses keep their own sill + side shadows.
static func _contact_shadows(props: Node2D, decals: Node2D) -> void:
	var rtex: Texture2D = _radial_tex()
	for c in props.get_children():
		# v8: composites are Node2Ds, so the v7 pass skipped every lamp post,
		# stall, well and tower. They carry a "shadow_w"/"shadow_h" meta now.
		var nd: Node2D = c as Node2D
		if nd != null and nd.has_meta("shadow_w"):
			var pw: float = float(nd.get_meta("shadow_w"))
			var ph: float = float(nd.get_meta("shadow_h"))
			if nd.position.x >= 2240.0 or nd.position.y >= 1600.0:
				var cs2 := Sprite2D.new()
				cs2.texture = rtex
				cs2.position = nd.position + Vector2(2.0, ph * 0.10)
				cs2.scale = Vector2(pw / 128.0 * 1.15, ph / 128.0 * 1.15)
				cs2.modulate = Color(0.05, 0.03, 0.02, 0.30)
				decals.add_child(cs2)
		var s: Sprite2D = c as Sprite2D
		if s == null or s.centered or s.texture == null:
			continue
		if s.position.x < 2240.0 and s.position.y < 1600.0:
			continue
		var w: float = s.region_rect.size.x if s.region_enabled else float(s.texture.get_width())
		var h: float = s.region_rect.size.y if s.region_enabled else float(s.texture.get_height())
		if w < 14.0 or h < 22.0:
			continue
		var path: String = s.texture.resource_path
		if s.texture is AtlasTexture and (s.texture as AtlasTexture).atlas != null:
			path = (s.texture as AtlasTexture).atlas.resource_path
		if path.contains("lpc_fences") or path.contains("flowerbed") or path.contains("crop_") or path.contains("sprout_") or path.contains("deck") or path.contains("bridge") or path.contains("cloth_line") or path.contains("banner") or path.contains("plant_09") or path.contains("plant_1"):
			continue
		var thin: bool = s.texture is ImageTexture or path.contains("hedge") or path.contains("wall_face") or path.contains("wall_cren") or path.contains("fence")
		var sh := Sprite2D.new()
		sh.texture = rtex
		var foot_y: float = s.position.y + (s.offset.y + h) * s.scale.y
		w *= absf(s.scale.x)
		var sw: float = w * (1.0 if thin else 0.95)
		var shh: float = 10.0 if thin else clampf(w * 0.34, 8.0, 30.0)
		sh.position = Vector2(s.position.x + 2.0, foot_y + shh * 0.10)
		sh.scale = Vector2(sw / 128.0 * 1.15, shh / 128.0 * 1.15)
		sh.modulate = Color(0.05, 0.03, 0.02, 0.22 if thin else 0.34)
		decals.add_child(sh)


# --------------------------------------------------------------- FOLK --------
static var _folk_pts: Array = []


## World positions of TownLife's placed folk (so clutter never lands on them).
static func _near_folk(p: Vector2, r: float) -> bool:
	if _folk_pts.is_empty():
		for row: Array in TownLife.FOLK:
			_folk_pts.append(Vector2(float(row[2]), float(row[3])))
	for f: Vector2 in _folk_pts:
		if f.distance_to(p) < r:
			return true
	return false


# --------------------------------------------------------------- WATER -------
const WATER_SHADER := "shader_type canvas_item;\nuniform float flow = 0.25;\nuniform float alpha = 0.32;\nvoid fragment() {\n\tvec3 a = texture(TEXTURE, UV + vec2(flow * TIME, 0.0)).rgb;\n\tvec3 b = texture(TEXTURE, UV * 1.7 - vec2(flow * 0.6 * TIME, 0.0) + vec2(0.31)).rgb;\n\tfloat h = smoothstep(0.50, 0.66, (a.r + a.g + a.b + b.r + b.g + b.b) / 6.0);\n\tCOLOR = vec4(0.78, 0.90, 0.94, h * alpha * COLOR.a);\n}\n"
const GLINT_SHADER := "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(COLOR.rgb, COLOR.a * (0.55 + 0.45 * sin(TIME * 1.3 + UV.x * 40.0)));\n}\n"
static var _water_shader: Shader = null
static var _glint_shader: Shader = null
static var _fleck: ImageTexture = null


static func _fleck_tex() -> ImageTexture:
	if _fleck == null:
		var img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_fleck = ImageTexture.create_from_image(img)
	return _fleck


## v7: the water gets a skin (the base tiles were a flat yellowed teal): a cool
## wash on the Decals layer pulls the ground tint back out, a shader-scrolled
## highlight FLOWS (the canal runs south to the river, the river runs east),
## a slow glint travels the ribbon, the north/west bank shades the water and
## flecks drift with the current. The basin gets the same skin as an ellipse.
## v9 WATER. The old skin was a stack of flat Line2Ds (a wash, a deep line, a
## texture-scrolled highlight, a glint and confetti flecks) over a single teal
## tile: no depth from bank to channel, no shoreline, no life. This draws the
## water as a real surface instead.
##
## One generated 64x64 tileable value-noise texture feeds one canvas shader.
## Across a Line2D, UV.y runs 0..1 bank-to-bank, which gives the depth ramp for
## free: pale shallows at the lip, a dark channel in the middle. Two noise
## layers scroll at different speeds and scales for flow; a thresholded
## highlight is the sparkle; a thin noise-broken band at the lip is foam; and
## the whole thing is quantised to a handful of levels so a shader still reads
## as pixel art at 640x360. The canal runs south to the river, the river runs
## east, and the flow direction follows.
static func _water_tex() -> ImageTexture:
	if _water_noise != null:
		return _water_noise
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	# tileable value noise: 4 octaves of a hashed lattice wrapped at n
	for y in range(n):
		for x in range(n):
			var v: float = 0.0
			var amp: float = 0.5
			var freq: int = 4
			for o in range(4):
				v += amp * _vnoise(float(x) / float(n) * float(freq), float(y) / float(n) * float(freq), freq)
				amp *= 0.5
				freq *= 2
			v = clampf(v + 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_water_noise = ImageTexture.create_from_image(img)
	return _water_noise


## Value noise on a lattice that wraps at `period` (so the tile seams match).
static func _vnoise(x: float, y: float, period: int) -> float:
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	xf = xf * xf * (3.0 - 2.0 * xf)
	yf = yf * yf * (3.0 - 2.0 * yf)
	var a: float = _hash2(xi % period, yi % period, period)
	var b: float = _hash2((xi + 1) % period, yi % period, period)
	var c: float = _hash2(xi % period, (yi + 1) % period, period)
	var d: float = _hash2((xi + 1) % period, (yi + 1) % period, period)
	return lerpf(lerpf(a, b, xf), lerpf(c, d, xf), yf)


static func _hash2(x: int, y: int, salt: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + salt * 1442695040888963407
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


const WATER_RIBBON_SHADER := "shader_type canvas_item;
uniform vec4 deep_col : source_color = vec4(0.05, 0.13, 0.22, 1.0);
uniform vec4 mid_col : source_color = vec4(0.10, 0.26, 0.35, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.21, 0.41, 0.44, 1.0);
uniform vec4 foam_col : source_color = vec4(0.74, 0.85, 0.86, 1.0);
uniform float flow = 0.055;
uniform float drift = 0.012;
uniform float tile = 2.0;
uniform float levels = 6.0;
uniform float foam_edge = 0.14;
void fragment() {
	vec2 uv = vec2(UV.x * tile, UV.y);
	float a = texture(TEXTURE, uv + vec2(TIME * flow, TIME * drift)).r;
	float b = texture(TEXTURE, uv * 1.9 - vec2(TIME * flow * 0.55, TIME * drift * 0.7) + vec2(0.37, 0.11)).r;
	float n = a * 0.62 + b * 0.38;
	float d = 1.0 - abs(UV.y * 2.0 - 1.0);
	float warp = texture(TEXTURE, uv * vec2(0.16, 0.5) + vec2(TIME * flow * 0.25, 0.0)).r;
	float depth = clamp(d + (n - 0.5) * 0.16 + (warp - 0.5) * 0.22, 0.0, 1.0);
	vec3 col = mix(shallow_col.rgb, mid_col.rgb, smoothstep(0.02, 0.46, depth));
	col = mix(col, deep_col.rgb, smoothstep(0.46, 0.95, depth));
	float sp = smoothstep(0.70, 0.78, n) * (0.25 + 0.75 * depth);
	col += vec3(0.62, 0.78, 0.82) * sp * 0.20;
	float lipd = clamp(d + (b - 0.5) * 0.10, 0.0, 1.0);
	float lip = smoothstep(0.0, foam_edge, lipd) * (1.0 - smoothstep(foam_edge, foam_edge * 2.1, lipd));
	col = mix(col, foam_col.rgb, lip * smoothstep(0.42, 0.70, b) * 0.65);
	float dith = texture(TEXTURE, uv * 7.0 + vec2(0.13, 0.71)).r;
	col = floor(col * levels + dith * 0.5 + 0.25) / levels;
	COLOR = vec4(col, COLOR.a);
}
"
const WATER_POOL_SHADER := "shader_type canvas_item;
uniform vec4 deep_col : source_color = vec4(0.05, 0.13, 0.22, 1.0);
uniform vec4 mid_col : source_color = vec4(0.10, 0.26, 0.35, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.21, 0.41, 0.44, 1.0);
uniform vec4 foam_col : source_color = vec4(0.74, 0.85, 0.86, 1.0);
uniform float levels = 6.0;
void fragment() {
	float a = texture(TEXTURE, UV * 2.0 + vec2(TIME * 0.016, TIME * 0.010)).r;
	float b = texture(TEXTURE, UV * 3.4 - vec2(TIME * 0.011, TIME * 0.007) + vec2(0.37, 0.11)).r;
	float n = a * 0.62 + b * 0.38;
	float r = length(UV - vec2(0.5)) * 2.0;
	float depth = clamp(1.0 - r + (n - 0.5) * 0.20, 0.0, 1.0);
	vec3 col = mix(shallow_col.rgb, mid_col.rgb, smoothstep(0.02, 0.46, depth));
	col = mix(col, deep_col.rgb, smoothstep(0.46, 0.95, depth));
	float sp = smoothstep(0.74, 0.82, n) * (0.30 + 0.70 * depth);
	col += vec3(0.62, 0.78, 0.82) * sp * 0.26;
	float lip = smoothstep(0.0, 0.14, 1.0 - r) * (1.0 - smoothstep(0.14, 0.26, 1.0 - r));
	col = mix(col, foam_col.rgb, lip * smoothstep(0.48, 0.74, b) * 0.60);
	float dith2 = texture(TEXTURE, UV * 9.0 + vec2(0.13, 0.71)).r;
	col = floor(col * levels + dith2 * 0.5 + 0.25) / levels;
	COLOR = vec4(col, COLOR.a);
}
"
static var _water_noise: ImageTexture = null
static var _ribbon_shader: Shader = null
static var _pool_shader: Shader = null


static func _ribbon_mat(flow: float) -> ShaderMaterial:
	if _ribbon_shader == null:
		_ribbon_shader = Shader.new()
		_ribbon_shader.code = WATER_RIBBON_SHADER
	var m := ShaderMaterial.new()
	m.shader = _ribbon_shader
	m.set_shader_parameter("flow", flow)
	return m


static func _water_skin(decals: Node2D) -> void:
	if _pool_shader == null:
		_pool_shader = Shader.new()
		_pool_shader.code = WATER_POOL_SHADER
	var tex: ImageTexture = _water_tex()
	var river: Array = [Vector2(0, RIVER_Y), Vector2(MAP_W, RIVER_Y)]
	# [points, ribbon width, flow (sign = direction), bank-shade offset, tile repeats]
	for rb: Array in [[CANAL_N, 92.0, -0.055, Vector2(-38.0, 0.0), 26.0], [CANAL_E, 80.0, 0.045, Vector2(0.0, -32.0), 30.0], [river, 212.0, 0.065, Vector2(0.0, -100.0), 40.0]]:
		var pts: Array = rb[0]
		var w: float = float(rb[1])
		var pv := PackedVector2Array()
		var sv := PackedVector2Array()
		for p: Vector2 in pts:
			pv.append(p)
			sv.append(p + (rb[3] as Vector2))
		# the bank's shadow on the water, under the surface
		var shade := Line2D.new()
		shade.points = sv
		shade.width = 11.0
		shade.default_color = Color(0.03, 0.06, 0.10, 0.34)
		shade.joint_mode = Line2D.LINE_JOINT_ROUND
		decals.add_child(shade)
		var body := Line2D.new()
		body.points = pv
		body.width = w
		body.texture = tex
		body.texture_mode = Line2D.LINE_TEXTURE_TILE
		body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		body.joint_mode = Line2D.LINE_JOINT_ROUND
		body.begin_cap_mode = Line2D.LINE_CAP_BOX
		body.end_cap_mode = Line2D.LINE_CAP_BOX
		var mat: ShaderMaterial = _ribbon_mat(float(rb[2]))
		mat.set_shader_parameter("tile", 3.0)
		body.material = mat
		decals.add_child(body)
	# the basin under the Trade Square and the fields pond
	for pool: Array in [[BASIN, 206.0, 60.0], [Vector2(560, 3650), 104.0, 46.0]]:
		var c: Vector2 = pool[0]
		var rx: float = float(pool[1])
		var ry: float = float(pool[2])
		var poly := Polygon2D.new()
		var pts2 := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in range(28):
			var ang: float = TAU * float(i) / 28.0
			var off := Vector2(cos(ang) * rx, sin(ang) * ry)
			pts2.append(c + off)
			uvs.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.5)
		poly.polygon = pts2
		poly.uv = uvs
		poly.texture = tex
		var pm := ShaderMaterial.new()
		pm.shader = _pool_shader
		poly.material = pm
		decals.add_child(poly)

# --------------------------------------------------------------- ROOKS -------
## v7: rooks over the Hollow â€” a straggling line of black birds crosses the
## city every half minute, flapping (two procedural 8x8 frames, no art).
static func _rooks(props: Node2D) -> void:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	var ink := Color(0.10, 0.09, 0.12)
	for px: Vector2i in [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 3), Vector2i(6, 2), Vector2i(3, 5), Vector2i(4, 5)]:
		img.set_pixelv(px, ink)
	for px2: Vector2i in [Vector2i(1, 5), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 5), Vector2i(3, 5), Vector2i(4, 5)]:
		img.set_pixelv(px2 + Vector2i(8, 0), ink)
	var tex := ImageTexture.create_from_image(img)
	for flock: Array in [[Vector2(1.0, -0.12), 5, Vector2(MAP_W * 0.5, 2600.0)], [Vector2(-1.0, 0.1), 3, Vector2(MAP_W * 0.55, 3200.0)]]:
		var fx := CPUParticles2D.new()
		fx.position = flock[2]
		fx.amount = int(flock[1])
		fx.lifetime = 28.0
		fx.preprocess = 28.0
		fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fx.emission_rect_extents = Vector2(2400.0, 900.0)
		fx.direction = flock[0]
		fx.spread = 8.0
		fx.gravity = Vector2.ZERO
		fx.initial_velocity_min = 55.0
		fx.initial_velocity_max = 75.0
		fx.anim_speed_min = 50.0
		fx.anim_speed_max = 70.0
		fx.texture = tex
		fx.color = Color(1, 1, 1, 0.85)
		fx.z_index = 60
		var m := CanvasItemMaterial.new()
		m.particles_animation = true
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = true
		fx.material = m
		props.add_child(fx)


# --------------------------------------------------------------- WASH --------
const WASH := Color(0.28, 0.27, 0.30, 0.30)   # v8: the city-earth layer now does the colour work
const WALL_TINT := Color(0.90, 0.88, 0.86)
static var _band_tex: GradientTexture2D = null
static var _flat_radial: GradientTexture2D = null


## v7: a soft neutral wash UNDER the cobble overlay and OVER the base tiles on
## every dirt area of the city (terrace bands, shoulders, lanes, squares,
## yards). Dirt_Roots under GROUND_TINT is a saturated orange that turned the
## packed-earth terraces into orange slabs; washed, it reads as trodden earth.
## Cobble/flags draw above it untouched. The village rectangle is never touched.
static func ground_wash() -> Node2D:
	var n := Node2D.new()
	n.name = "CityWash"
	n.y_sort_enabled = false
	for s: Array in ROWS_EW:
		n.add_child(_wash_band(_shifted(s, -120.0), 440.0))
	for s2: Array in [APPROACH, AVENUE_E, AVENUE_S, SPINE, QUAY_LANE, LINK, CANAL_LANE, KEEP_ROAD, CATH_FORE, BANK_ROW]:
		n.add_child(_wash_band(s2, 230.0))
	for s3: Array in [SE_TRACK, GARDEN_LANE, F1, F2, F3, F5, TOWPATH]:
		n.add_child(_wash_band(s3, 140.0))
	for e: Array in [[TRADE_SQ, 470.0, 320.0], [CATH_SQ + Vector2(0, -40), 420.0, 330.0], [WARD_SQ, 300.0, 170.0], [Vector2(3600, 430), 820.0, 250.0], [Vector2(3650, 4350), 1070.0, 230.0], [Vector2(3250, 3830), 640.0, 90.0], [Vector2(2500, 440), 210.0, 170.0], [Vector2(2620, 1330), 280.0, 140.0], [Vector2(5100, 4360), 520.0, 100.0], [Vector2(6620, 900), 120.0, 70.0], [Vector2(6840, 3900), 160.0, 100.0], [Vector2(6840, 2800), 90.0, 50.0], [Vector2(6580, 4220), 160.0, 70.0], [WELL_SQ, 140.0, 90.0], [TAVERN_SQ, 180.0, 100.0], [Vector2(1560, 2210), 150.0, 70.0], [Vector2(660, 2690), 110.0, 52.0], [Vector2(1900, 3000), 170.0, 96.0], [Vector2(1100, 3060), 90.0, 50.0], [Vector2(1320, 4420), 120.0, 56.0], [Vector2(520, 2010), 120.0, 80.0], [Vector2(1900, 4960), 90.0, 40.0], [Vector2(5600, 4940), 120.0, 46.0]]:
		var b := Sprite2D.new()
		b.texture = _flat_radial_tex()
		b.position = e[0]
		b.scale = Vector2(float(e[1]) * 1.1 / 64.0, float(e[2]) * 1.1 / 64.0)
		b.modulate = WASH
		n.add_child(b)
	return n


static func _shifted(pts: Array, dy: float) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p + Vector2(0.0, dy))
	return out


## A Line2D band with soft edges (the gradient runs across the width).
static func _wash_band(pts: Array, width: float) -> Line2D:
	var l := Line2D.new()
	var pv := PackedVector2Array()
	for p: Vector2 in pts:
		pv.append(p)
	l.points = pv
	l.width = width
	l.default_color = WASH
	l.texture = _band_texture()
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


static func _band_texture() -> GradientTexture2D:
	if _band_tex != null:
		return _band_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.14, 0.86, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 64
	_band_tex = tex
	return tex


## Radial with a flat core and a short soft rim (area washes).
static func _flat_radial_tex() -> GradientTexture2D:
	if _flat_radial != null:
		return _flat_radial
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_flat_radial = tex
	return tex


# --------------------------------------------------------------- WEAR --------
## v7: street wear as decals (the v4 hub-punched "worn patches" showed the
## orange base dirt in leafy-rimmed ovals that read as dung heaps at play
## zoom): a darker trodden middle every 90-140 px and two faint cart ruts,
## broken at the water (bridges) and on the flagged squares.
static func _street_wear(decals: Node2D) -> void:
	var rng := _rng(9)
	var rtex: Texture2D = _radial_tex()
	for s: Array in [OT1, OT2, OT3, OT4, EW1, EW2, EW3, EAST_ROAD, APPROACH, AVENUE_E, AVENUE_S, SPINE, QUAY_LANE, LINK, KEEP_ROAD, CANAL_LANE, BANK_ROW]:
		var horizontal: bool = absf((s[s.size() - 1] as Vector2).x - (s[0] as Vector2).x) >= absf((s[s.size() - 1] as Vector2).y - (s[0] as Vector2).y)
		var total: float = _poly_len(s)
		for side: float in [-14.0, 14.0]:
			var cur := PackedVector2Array()
			var d: float = 0.0
			while d <= total:
				var q: Vector2 = _along(s, d) + (Vector2(0.0, side) if horizontal else Vector2(side, 0.0)) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				var at_junction: bool = false
				for other: Array in [OT1, OT2, OT3, OT4, EW1, EW2, EW3, EAST_ROAD, AVENUE_S, SPINE, CANAL_LANE, APPROACH, AVENUE_E]:
					if other == s:
						continue
					if _dist_to_poly(q, other) < 54.0:
						at_junction = true
						break
				if _near_water(q, 26.0) or _on_square(q) or at_junction or int(d / 24.0) % 8 == 0:
					if cur.size() >= 2:
						decals.add_child(_rut(cur))
					cur = PackedVector2Array()
				else:
					cur.append(q)
				d += 24.0
			if cur.size() >= 2:
				decals.add_child(_rut(cur))
		var dd: float = rng.randf_range(40.0, 90.0)
		while dd < total - 30.0:
			var p: Vector2 = _along(s, dd) + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
			dd += rng.randf_range(90.0, 150.0)
			if _near_water(p, 40.0) or _on_square(p):
				continue
			var blob := Sprite2D.new()
			blob.texture = rtex
			blob.position = p
			var bs: float = rng.randf_range(0.40, 0.70)
			var bt: float = rng.randf_range(0.45, 0.6)
			blob.scale = Vector2(bs, bs * bt) if horizontal else Vector2(bs * bt, bs)
			blob.modulate = Color(0.16, 0.13, 0.10, rng.randf_range(0.12, 0.20))
			decals.add_child(blob)


static func _rut(pts: PackedVector2Array) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = 3.0
	l.default_color = Color(0.09, 0.07, 0.06, 0.15)
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


static func _poly_len(pts: Array) -> float:
	var total: float = 0.0
	for i in range(pts.size() - 1):
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	return total


## Point at arc length d along a polyline (clamped to its ends).
static func _along(pts: Array, d: float) -> Vector2:
	var left: float = d
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l: float = a.distance_to(b)
		if left <= l:
			return a.lerp(b, left / maxf(l, 0.001))
		left -= l
	return pts[pts.size() - 1]


## Inside one of the paved/flagged squares, the keep court or the harbour quay.
static func _on_square(p: Vector2) -> bool:
	for e: Array in [[TRADE_SQ, 420.0, 270.0], [CATH_SQ, 380.0, 270.0], [WARD_SQ, 220.0, 130.0], [WELL_SQ, 130.0, 90.0], [TAVERN_SQ, 170.0, 100.0], [Vector2(3600, 470), 320.0, 170.0], [HARBOR_SQ, 190.0, 110.0]]:
		var d: Vector2 = (p - (e[0] as Vector2)) / Vector2(float(e[1]), float(e[2]))
		if d.length_squared() < 1.0:
			return true
	if p.y > QUAY_Y0 - 10.0 and p.y < RIVER_Y - RIVER_HALF + 20.0 and p.x > 2590.0 and p.x < 4710.0:
		return true
	return false


## On the carriageway of any cobbled street (weeds stay off it).
static func _on_street(p: Vector2) -> bool:
	if _on_square(p):
		return true
	for s: Array in [OT1, OT2, OT3, OT4, EW1, EW2, EW3, EAST_ROAD, APPROACH, AVENUE_E, AVENUE_S, SPINE, LINK, CANAL_LANE, KEEP_ROAD, QUAY_LANE, CATH_FORE, BANK_ROW]:
		if _dist_to_poly(p, s) < 60.0:
			return true
	return false


## freekit's candelabrum is 64x91 (2.8 characters tall): always scaled down.
static func _candelabrum(props: Node2D, pos: Vector2, s: float) -> void:
	var c := TownBuilder._sprite(FREEKIT + "candelabrum_lit.png", pos, 0.0)
	c.scale = Vector2(s, s)
	props.add_child(c)


# --------------------------------------------------------------- STORY -------
## Small scenes that never explain themselves (Bible V). The drowned rat's
## grave on the canal bank, a cross on an Old Town door, the shrine at the
## ward crossroads, the copper well on the ward square.
static func _vignettes(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	# the first one pulled out of the canal: a marker on the bank, a lantern, the rope
	var bx: float = _x_at(CANAL_N, 3450.0) - 74.0
	props.add_child(TownBuilder._sprite(FREEKIT + "graves/grave_07.png", Vector2(bx, 3450), 2.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "lantern_lit.png", Vector2(bx - 20, 3474), 0.0))
	lights.add_child(TownBuilder._light(Vector2(bx - 20, 3462), Color(1.0, 0.72, 0.4), 0.35, 44.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(bx + 30, 3480), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", Vector2(bx + 8, 3496), 3.0))
	props.add_child(TownBuilder._sprite(STREET + "flowerbed_9.png", Vector2(bx - 4, 3428), 0.0))
	# a cross nailed to an Old Town door, candles at the sill
	var sy: float = _y_at(OT2, 3300.0) - ROW_SETBACK
	props.add_child(TownBuilder._sprite(FREEKIT + "cross_large.png", Vector2(3300, sy + 14), 0.0))
	_candelabrum(props, Vector2(3342, sy + 20), 0.5)
	lights.add_child(TownBuilder._light(Vector2(3342, sy - 28), Color(1.0, 0.68, 0.32), 0.35, 48.0))
	TownBuilder._decal(decals, PROPS + "szadi_prop_04.png", Vector2(3282, sy + 14))
	# the shrine at the ward crossroads (the avenue meets the first ward street)
	var shx: float = _x_at(AVENUE_S, 3120.0) + 78.0
	props.add_child(TownBuilder._sprite(FREEKIT + "statue_a.png", Vector2(shx, 3176), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(shx, 3176), Vector2(24.0, 10.0), Vector2(0, -5)))
	_candelabrum(props, Vector2(shx + 30, 3184), 0.5)
	lights.add_child(TownBuilder._light(Vector2(shx + 30, 3136), Color(1.0, 0.68, 0.32), 0.4, 55.0))
	props.add_child(TownBuilder._sprite(STREET + "flowerbed_5.png", Vector2(shx - 34, 3190), 0.0))
	props.add_child(TownBuilder._sprite(STREET + "pot_shrub.png", Vector2(shx + 58, 3192), 0.0))
	_bench(props, Vector2(shx + 6, 3214))
	# the copper well: the ward square's well has turned; a board says nothing
	for n in props.get_children():
		var s: Sprite2D = n as Sprite2D
		if s != null and s.position.distance_to(WARD_SQ + Vector2(0, -50)) < 4.0 and s.texture != null and s.texture.resource_path.ends_with("szadi_prop_11.png"):
			s.modulate = Color(0.88, 0.66, 0.52)
	props.add_child(TownBuilder._sprite(STREET + "board_0.png", WARD_SQ + Vector2(60, -40), 0.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", WARD_SQ + Vector2(-40, -36), 3.0))
	TownBuilder._decal(decals, PROPS + "szadi_prop_04.png", WARD_SQ + Vector2(-14, -20))


# --------------------------------------------------------------- FIELDS II ---
## A run of LPC fence rail along a polyline between x0 and x1, offset dy from
## the line (hedgerow walls of the field lanes), with gaps at `gaps`.
static func _fence_along(props: Node2D, pts: Array, x0: float, x1: float, dy: float, gaps: Array) -> void:
	var x: float = x0
	while x <= x1:
		var skip: bool = false
		for g: float in gaps:
			if absf(x - g) < 60.0:
				skip = true
		var p := Vector2(x, _y_at(pts, x) + dy)
		if not skip and not _near_water(p, 40.0):
			var ft := Sprite2D.new()
			ft.texture = TownBuilder._region(TownBuilder.FENCES, TownBuilder.F_T)
			ft.centered = false
			ft.offset = Vector2(-16.0, -32.0)
			ft.position = p
			props.add_child(ft)
		x += 32.0


## The fields, second pass: fenced lanes, haystacks in the meadows, a sheepfold,
## a wayside cross on the field lane, stone piles at the corners, more copses
## along the walls â€” so the west half is farmland, not lawn.
static func _field_lines(props: Node2D, lights: Node2D) -> void:
	var rng := _rng(24)
	# hedgerow rails along the E-W field lanes (north side), gaps at the crossings
	_fence_along(props, F2, 340.0, 2380.0, -44.0, [1160.0, 2200.0])
	_fence_along(props, F5, 340.0, 1160.0, -44.0, [1200.0])
	_fence_along(props, F2, 340.0, 1100.0, 44.0, [600.0])
	# haystacks: three meadows
	for hm: Array in [[Vector2(760, 2480), 5], [Vector2(1680, 3300), 6], [Vector2(1040, 4120), 4]]:
		var hc: Vector2 = hm[0]
		for i in range(int(hm[1])):
			var hp := hc + Vector2(rng.randf_range(-70.0, 70.0), rng.randf_range(-40.0, 40.0))
			props.add_child(TownBuilder._sprite(PROPS + ("szadi_prop_21.png" if rng.randf() < 0.6 else "szadi_prop_14.png"), hp, 3.0))
		props.add_child(TownBuilder._atlas_sprite(TownBuilder.R_CART, hc + Vector2(110, 30), 5.0))
		props.add_child(TownBuilder._rect_collider(hc + Vector2(110, 30), Vector2(52, 18), Vector2(0, -10)))
	# the sheepfold: a fenced square with a gap, hay and a bucket, a shepherd's hut
	_fence_rect(props, Rect2i(20, 124, 8, 6), Vector2i(23, 24))
	for sp2: Vector2 in [Vector2(700, 4070), Vector2(760, 4100), Vector2(820, 4060)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_21.png", sp2, 3.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", Vector2(700, 4120), 3.0))
	_house(props, lights, Vector2(980, 3960), "cottage", "slate", rng, false)
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_30.png", Vector2(1060, 3976), 3.0))
	# wayside cross on the field lane, a bench, a candle at dusk
	props.add_child(TownBuilder._sprite(FREEKIT + "cross_large.png", Vector2(1290, 3560), 0.0))
	props.add_child(TownBuilder._rect_collider(Vector2(1290, 3560), Vector2(20.0, 10.0), Vector2(0, -5)))
	_candelabrum(props, Vector2(1316, 3572), 0.5)
	lights.add_child(TownBuilder._light(Vector2(1316, 3530), Color(1.0, 0.68, 0.32), 0.35, 48.0))
	_bench(props, Vector2(1250, 3590))
	# stone piles cleared from the fields, at the corners
	for spp: Vector2 in [Vector2(1300, 2610), Vector2(2060, 2560), Vector2(1000, 2740), Vector2(940, 3060), Vector2(2130, 2760), Vector2(1000, 3110), Vector2(980, 3330)]:
		props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_33.png", spp, 2.0))
		props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_38.png", spp + Vector2(22, 8), 2.0))
	# copses: clusters of 3-5 swaying trees on the open commons
	for cc: Vector2 in [Vector2(1900, 1750), Vector2(2100, 2050), Vector2(500, 2500), Vector2(2100, 3560), Vector2(1400, 4150), Vector2(2000, 4250), Vector2(640, 4300), Vector2(1500, 3180)]:
		var n: int = rng.randi_range(3, 5)
		var placed: Array = []
		var tries: int = 0
		while placed.size() < n and tries < 20:
			tries += 1
			var tp := cc + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-60.0, 60.0))
			if _on_soil(tp) or _in_built_rect(tp) or _near_water(tp, 40.0) or _near_lane(tp):
				continue
			var crowded: bool = false
			for q: Vector2 in placed:
				if q.distance_to(tp) < 72.0:
					crowded = true
			if crowded:
				continue
			placed.append(tp)
			props.add_child(_tree(props, tp, rng))
			props.add_child(TownBuilder._circle_collider(tp, 6.0, Vector2(0, -3)))
		props.add_child(TownBuilder._sprite(PLANTS + "plant_%02d.png" % rng.randi_range(3, 8), cc + Vector2(0.0, 140.0), 3.0))


## The river's south bank: towpath, reeds and willows, boats pulled up, the
## ferryman's yard, the eel-smokers' fires â€” the strip under the south wall
## was a lawn.
static func _south_bank(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var rng := _rng(25)
	# reeds along the water's edge, both banks
	var x: float = 140.0
	while x < MAP_W - 140.0:
		if rng.randf() < 0.55:
			var rp := Vector2(x + rng.randf_range(-8.0, 8.0), RIVER_Y + RIVER_HALF + rng.randf_range(-6.0, 10.0))
			var reed := TownBuilder._sprite(TOWNKIT + ("reed_a" if rng.randf() < 0.5 else "reed_b") + ".png", rp, 4.0)
			reed.modulate = Color(0.84, 0.86, 0.78)
			props.add_child(reed)
		if rng.randf() < 0.3 and (x < 2560.0 or x > 4760.0):
			var rp2 := Vector2(x + rng.randf_range(-8.0, 8.0), RIVER_Y - RIVER_HALF - rng.randf_range(0.0, 8.0))
			var reed2 := TownBuilder._sprite(TOWNKIT + "reed_bank.png", rp2, 4.0)
			reed2.modulate = Color(0.84, 0.86, 0.78)
			props.add_child(reed2)
		x += 44.0
	# willows on the south bank, swaying
	var willows: Array = []
	for wx: float in [300.0, 620.0, 980.0, 1460.0, 2240.0, 2760.0, 3340.0, 3980.0, 4620.0, 5180.0, 6100.0, 6720.0]:
		var wp := Vector2(wx + rng.randf_range(-30.0, 30.0), RIVER_Y + RIVER_HALF + rng.randf_range(90.0, 130.0))
		willows.append(wp)
		props.add_child(_tree(props, wp, rng))
		props.add_child(TownBuilder._circle_collider(wp, 6.0, Vector2(0, -3)))
	# the ferryman's yard: a boat pulled up, a hut, rope, a lantern on a post
	_house(props, lights, Vector2(1900, 4900), "cottage", "slate", rng, false)
	props.add_child(TownBuilder._sprite(COAST + "rowboat_side.png", Vector2(2000, 4790), 0.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(1800, 4786), 0.0))
	props.add_child(TownBuilder._sprite(FREEKIT + "rope_coil.png", Vector2(1960, 4950), 2.0))
	props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_10.png", Vector2(1840, 4956), 3.0))
	_lamp(props, lights, Vector2(2040, 4930))
	props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_17.png", Vector2(1780, 4930), 2.0))
	# the eel-smokers: two fires, racks (cloth lines), barrels, a shack
	_house(props, lights, Vector2(5600, 4910), "cottage", "red", rng, false)
	for fp: Vector2 in [Vector2(5500, 4946), Vector2(5700, 4950)]:
		var fire := TownBuilder._anim_sprite(TownBuilder.FIRE_FRAMES, 8.0, fp, 4.0)
		props.add_child(fire)
		props.add_child(TownBuilder._circle_collider(fp, 9.0, Vector2(0, -5)))
		lights.add_child(TownBuilder._light(fp + Vector2(0, -16), Color(1.0, 0.62, 0.32), 0.7, 85.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(5460, 4930), 4.0))
	props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(5740, 4934), 4.0))
	for bp: Vector2 in [Vector2(5680, 4950), Vector2(5704, 4960)]:
		props.add_child(TownBuilder._sprite(PROPS + "szadi_prop_08.png", bp, 3.0))
	props.add_child(TownBuilder._sprite(COAST + "rowboat.png", Vector2(5440, 4790), 0.0))
	# a few boats and nets pulled up along the bank, hurdles, a stile
	for bx: float in [700.0, 3200.0, 4400.0, 6500.0]:
		props.add_child(TownBuilder._sprite(COAST + ("rowboat_side" if rng.randf() < 0.5 else "rowboat") + ".png", Vector2(bx, RIVER_Y + RIVER_HALF + 26.0), 0.0))
	for nx: float in [1100.0, 2600.0, 6200.0]:
		props.add_child(TownBuilder._sprite(TOWNKIT + "szadi_cloth_line.png", Vector2(nx, RIVER_Y + RIVER_HALF + 74.0), 4.0))
	# towpath lamps at the water gate and the ferry
	_lamp(props, lights, Vector2(3600, 4930))
	_lamp(props, lights, Vector2(4700, 4930))
	# the south bank tufts and stones
	for i in range(40):
		var sp2 := Vector2(rng.randf_range(140.0, MAP_W - 140.0), rng.randf_range(RIVER_Y + RIVER_HALF + 40.0, MAP_H - 120.0))
		if _in_built_rect(sp2):
			continue
		var by_willow: bool = false
		for wq: Vector2 in willows:
			if wq.distance_to(sp2) < 52.0:
				by_willow = true
		if by_willow:
			continue
		if rng.randf() < 0.7:
			props.add_child(TownBuilder._sprite(PLANTS + "plant_%02d.png" % rng.randi_range(3, 8), sp2, 3.0))
		else:
			props.add_child(TownBuilder._sprite(PROPS + "cainos_prop_%02d.png" % rng.randi_range(34, 42), sp2, 2.0))