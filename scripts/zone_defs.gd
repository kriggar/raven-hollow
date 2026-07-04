class_name ZoneDefs
## WORLD_PLAN.md data — the 40-zone / 2-continent Draconia world registry.
## Every zone is HAND-AUTHORED here: landmark anchors, road/river polylines,
## lore vignettes (bible-sourced), native creature tables, waystations, seams.
## ZoneBuilder (scripts/zone_builder.gd) turns each def into a live map;
## MapRegistry merges built zones into the playable map set.
##
## STATUS: zones flip built:true batch-by-batch (build order in WORLD_PLAN.md).
## Batch A (Border ring): vetka, iron_vein, copper_wells, stonepath.
## Stub entries carry canon name/biome/continent so the world map, travel
## graph and plan stay honest about what exists vs what is planned.

const MUSIC_WILD := "res://assets/audio/music/theme_plain.ogg"
const MUSIC_TOWN := "res://assets/audio/music/theme_lost_village.ogg"

## Zone music by REGION (canon mood per WORLD_PLAN). Files land via the audio
## acquisition; main.gd falls back to MUSIC_WILD until a theme exists on disk.
const REGION_MUSIC := {
	"border": "res://assets/audio/music/theme_border.ogg",
	"west": "res://assets/audio/music/theme_west.ogg",
	"north": "res://assets/audio/music/theme_north.ogg",
	"east": "res://assets/audio/music/theme_east.ogg",
	"south": "res://assets/audio/music/theme_south.ogg",
	"coast": "res://assets/audio/music/theme_port.ogg",
}

## Ambient bed by BIOME (zone defs may override with "ambience"). The howling
## wind of the tundra, swamp frogs of the bog, birdsong over farmland...
const BIOME_AMBIENCE := {
	"bog": "amb_swamp",
	"moor": "amb_dead_wind",
	"wilds": "amb_forest_birds",
	"farmland": "amb_forest_birds",
	"deadforest": "amb_dead_wind",
	"tundra": "amb_wind_howl",
	"volcanic": "amb_forge_rumble",
	"ridge": "amb_wind_howl",
	"port": "amb_harbor",
	"cave": "amb_cave",
}

## Waystation route graph (WoW flight-path rules: travel only along links,
## both endpoints discovered). The Grey Ferry (continent link) joins in
## batch G: riverfork_docks <-> grey_piers.
const ROUTES := {
	"bent_oar": ["vetka_square"],
	"vetka_square": ["bent_oar", "copper_cross"],
	"copper_cross": ["vetka_square", "stonepath_cross"],
	"stonepath_cross": ["copper_cross", "marches_post"],
	"marches_post": ["stonepath_cross", "lowlands_barge"],
	"lowlands_barge": ["marches_post", "angel_gate"],
	"angel_gate": ["lowlands_barge", "famine_post"],
	"famine_post": ["angel_gate", "riverfork_docks"],
	"riverfork_docks": ["famine_post"],
}


static func route_links(station_id: String) -> Array:
	return ROUTES.get(station_id, [])


static func built_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _ZONES:
		if bool((_ZONES[id] as Dictionary).get("built", false)):
			out.append(String(id))
	return out


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _ZONES:
		out.append(String(id))
	return out


static func zone(id: String) -> Dictionary:
	return (_ZONES.get(id, {}) as Dictionary).duplicate(true)


## MapRegistry-shaped defs for every BUILT zone (merged in map_registry.gd).
static func map_defs() -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in _ZONES:
		var z: Dictionary = _ZONES[id]
		if not bool(z.get("built", false)):
			continue
		out[String(id)] = {
			"id": String(id),
			"display_name": str(z.get("name", id)),
			"zone_id": String(id),
			"builder_script": "res://scripts/zone_builder.gd",
			"music": str(z.get("music",
					REGION_MUSIC.get(str(z.get("region", "")), MUSIC_WILD))),
			"ambience": str(z.get("ambience",
					BIOME_AMBIENCE.get(str(z.get("biome", "")), ""))),
			"dusk_tint": z.get("dusk_tint", Color(0.94, 0.82, 0.70)),
			"travel_points": z.get("travel_points", []),
		}
	return out


# ======================================================================
# THE ZONES — Continent 1: DRACONIA (Year 0)
# ======================================================================

const _ZONES := {
	# ---------------- Border Region (interior seams — starter ring) --------
	"iron_vein": {
		"built": true,
		"name": "The Iron Vein",
		"continent": 1, "region": "border", "biome": "bog",
		"tiles_w": 208, "tiles_h": 144,
		"dusk_tint": Color(0.88, 0.80, 0.72),
		"player_spawn": Vector2(180.0, 1850.0),
		"tree_density": 1.25,
		# The slow metallic river the color of old blood (canon).
		"river": [Vector2(0, 2200), Vector2(1400, 2400), Vector2(3000, 2300), Vector2(4600, 2600), Vector2(6656, 2500)],
		"river_width": 110.0,
		"river_color": Color(0.34, 0.24, 0.20, 0.94),
		"roads": [[Vector2(100, 1800), Vector2(1600, 1880), Vector2(3200, 1960), Vector2(5000, 2010), Vector2(6560, 2060)]],
		"landmarks": [
			{"type": "tavern", "pos": Vector2(3200, 1780)},          # The Bent Oar — hub on the north bank
			{"type": "camp", "pos": Vector2(1200, 3200)},
			{"type": "graves", "pos": Vector2(5200, 3400), "count": 8},
			{"type": "inscription_stone", "pos": Vector2(4400, 1200), "live": false},
			{"type": "dolmen", "pos": Vector2(1800, 900)},
			{"type": "copper_well", "pos": Vector2(2600, 2800)},
			{"type": "bones", "pos": Vector2(5400, 2850)},
			{"type": "pond", "pos": Vector2(1900, 2900)},
			{"type": "pond", "pos": Vector2(3900, 3100)},
			{"type": "pond", "pos": Vector2(900, 2100)},
			{"type": "stump", "pos": Vector2(2300, 1200)},
			{"type": "stump", "pos": Vector2(5000, 2400)},
			{"type": "trunk_hollow", "pos": Vector2(1500, 3700)},
		],
		"warm_patches": [Vector2(4400, 1260), Vector2(2650, 2860)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(5400, 1500)},       # in, none out
			{"kind": "standing_farmer", "pos": Vector2(2400, 2150)}, # "resting" since Tuesday
		],
		"waystations": [{"id": "bent_oar", "pos": Vector2(3050, 2000)}],
		"border_gaps": [Rect2(0, 1700, 220, 320), Rect2(6440, 1940, 220, 300)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(120.0, 1840.0), "radius": 34.0,
				"to_map": "wilderness", "to_point": "east_exit", "prompt": "[E] The Emberfall Road"},
			{"id": "east_gate", "pos": Vector2(6540.0, 2060.0), "radius": 34.0,
				"to_map": "vetka", "to_point": "west_entry", "prompt": "[E] Vetka — the Border Village"},
		],
		"creature_table": [
			{"type": "boar", "name": "Bog Boar", "count": 8, "pack": 2, "hp": 26, "damage": 5, "speed": 70, "patrol": 90,
				"area": Rect2(800, 2600, 2400, 1400)},
			{"type": "wolf", "name": "Mudwolf", "count": 6, "pack": 3, "hp": 30, "damage": 7, "speed": 88, "patrol": 120,
				"area": Rect2(4200, 800, 2000, 1000)},
			{"type": "skeleton", "name": "Thread-Touched Dead", "count": 5, "pack": 1, "hp": 34, "damage": 8, "speed": 52, "patrol": 60,
				"area": Rect2(4800, 3000, 1600, 1200)},
		],
	},

	"vetka": {
		"built": true,
		"name": "Vetka",
		"continent": 1, "region": "border", "biome": "moor",
		"tiles_w": 176, "tiles_h": 128,
		"dusk_tint": Color(0.92, 0.84, 0.74),
		"music": MUSIC_TOWN,
		"player_spawn": Vector2(200.0, 2010.0),
		"tree_density": 0.8,
		"roads": [
			[Vector2(100, 2000), Vector2(1500, 2020), Vector2(2800, 2050)],
			[Vector2(2800, 2050), Vector2(2830, 3000), Vector2(2800, 3980)],
			[Vector2(2400, 1800), Vector2(2800, 2050), Vector2(3300, 2300)],
		],
		"landmarks": [
			{"type": "cottage", "pos": Vector2(2200, 1700)},   # Old Marta's herb cottage
			{"type": "cottage", "pos": Vector2(3300, 1750)},   # Torn's holding
			{"type": "cottage", "pos": Vector2(2600, 2350)},   # Dorica's
			{"type": "barn", "pos": Vector2(3400, 2450)},      # Gren's barn
			{"type": "shed", "pos": Vector2(3000, 1500)},
			{"type": "well", "pos": Vector2(2850, 2080)},
			{"type": "copper_well", "pos": Vector2(2300, 2420)},  # the rot arriving in real time
		],
		"warm_patches": [Vector2(2320, 2470)],
		"vignettes": [
			{"kind": "standing_farmer", "pos": Vector2(4400, 1600)},  # faced toward the Chamber
			{"kind": "empty_stall", "pos": Vector2(2750, 1950)},      # flat grey bread, no eye contact
		],
		"waystations": [{"id": "vetka_square", "pos": Vector2(2950, 2120)}],
		"border_gaps": [Rect2(0, 1900, 220, 260), Rect2(2660, 3900, 300, 220)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(140.0, 2010.0), "radius": 34.0,
				"to_map": "iron_vein", "to_point": "east_gate", "prompt": "[E] The Iron Vein"},
			{"id": "south_gate", "pos": Vector2(2800.0, 3950.0), "radius": 34.0,
				"to_map": "copper_wells", "to_point": "north_entry", "prompt": "[E] The Copper Wells"},
		],
		"creature_table": [
			{"type": "boar", "name": "Boar", "count": 4, "pack": 2, "hp": 24, "damage": 5, "speed": 68, "patrol": 80,
				"area": Rect2(4300, 2900, 1100, 1000)},
		],
	},

	"copper_wells": {
		"built": true,
		"name": "The Copper Wells",
		"continent": 1, "region": "border", "biome": "moor",
		"tiles_w": 192, "tiles_h": 144,
		"dusk_tint": Color(0.90, 0.80, 0.70),
		"player_spawn": Vector2(2900.0, 220.0),
		"tree_density": 0.7,
		"roads": [[Vector2(2900, 120), Vector2(2950, 1400), Vector2(3000, 2200), Vector2(4500, 2280), Vector2(6060, 2300)]],
		"landmarks": [
			{"type": "copper_well", "pos": Vector2(2400, 1800)},
			{"type": "copper_well", "pos": Vector2(2700, 1980)},
			{"type": "copper_well", "pos": Vector2(2200, 2120)},
			{"type": "copper_well", "pos": Vector2(2600, 2300)},
			{"type": "well", "pos": Vector2(4200, 2600)},          # the one clean well
			{"type": "inscription_stone", "pos": Vector2(3400, 3200), "live": true},
			{"type": "stone_row", "pos": Vector2(1600, 3400), "count": 5},
			{"type": "dolmen", "pos": Vector2(5000, 1400)},
			{"type": "graves", "pos": Vector2(5200, 3600), "count": 6},
			{"type": "cottage", "pos": Vector2(4600, 1800)},       # empty farmstead, unlooted
			{"type": "cottage", "pos": Vector2(4950, 2080)},       # empty farmstead, unlooted
		],
		"warm_patches": [Vector2(2450, 1860), Vector2(2650, 2360), Vector2(3400, 3260)],
		"vignettes": [
			{"kind": "empty_stall", "pos": Vector2(1650, 3450)},
			{"kind": "cold_camp", "pos": Vector2(900, 900)},
		],
		"waystations": [{"id": "copper_cross", "pos": Vector2(3050, 2240)}],
		"border_gaps": [Rect2(2760, 0, 300, 220), Rect2(5940, 2180, 220, 280)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(2900.0, 150.0), "radius": 34.0,
				"to_map": "vetka", "to_point": "south_gate", "prompt": "[E] Vetka"},
			{"id": "east_gate", "pos": Vector2(6040.0, 2300.0), "radius": 34.0,
				"to_map": "stonepath", "to_point": "west_entry", "prompt": "[E] The Stonepath"},
		],
		"creature_table": [
			{"type": "skeleton_mage", "name": "Entranced Pilgrim", "count": 6, "pack": 1, "hp": 22, "damage": 6, "speed": 18, "patrol": 12,
				"area": Rect2(3000, 2900, 1200, 900)},
			{"type": "wolf", "name": "Moor Wolf", "count": 6, "pack": 3, "hp": 30, "damage": 7, "speed": 88, "patrol": 120,
				"area": Rect2(800, 1200, 1600, 1400)},
			{"type": "skeleton", "name": "Thread-Touched Dead", "count": 4, "pack": 2, "hp": 34, "damage": 8, "speed": 52, "patrol": 70,
				"area": Rect2(4800, 3200, 1200, 1100)},
		],
	},

	"stonepath": {
		"built": true,
		"name": "The Stonepath",
		"continent": 1, "region": "border", "biome": "wilds",
		"tiles_w": 208, "tiles_h": 160,
		"dusk_tint": Color(0.90, 0.84, 0.74),
		"player_spawn": Vector2(200.0, 2600.0),
		"tree_density": 1.0,
		"roads": [
			[Vector2(140, 2600), Vector2(1800, 2620), Vector2(3300, 2600), Vector2(5000, 2580), Vector2(6520, 2560)],
			[Vector2(3300, 300), Vector2(3320, 1500), Vector2(3300, 2600), Vector2(3280, 3900), Vector2(3300, 5000)],
		],
		"landmarks": [
			{"type": "inscription_stone", "pos": Vector2(3300, 2450), "live": true},
			{"type": "inscription_stone", "pos": Vector2(1400, 1200), "live": false},
			{"type": "inscription_stone", "pos": Vector2(5200, 3800), "live": false},
			{"type": "stone_row", "pos": Vector2(2900, 2350), "count": 6},
			{"type": "stone_row", "pos": Vector2(3700, 2800), "count": 6},
			{"type": "dolmen", "pos": Vector2(5600, 1000)},
			{"type": "dolmen", "pos": Vector2(800, 4300)},
			{"type": "graves", "pos": Vector2(1000, 2000), "count": 6},
			{"type": "bones", "pos": Vector2(3350, 2700)},
		],
		"warm_patches": [Vector2(3300, 2520), Vector2(3340, 2380)],
		"vignettes": [
			{"kind": "empty_stall", "pos": Vector2(3360, 2720)},
			{"kind": "boot_prints", "pos": Vector2(5150, 3850)},
		],
		"waystations": [{"id": "stonepath_cross", "pos": Vector2(3420, 2660)}],
		"border_gaps": [Rect2(0, 2480, 240, 280), Rect2(3160, 0, 300, 240)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(160.0, 2600.0), "radius": 34.0,
				"to_map": "copper_wells", "to_point": "east_gate", "prompt": "[E] The Copper Wells"},
			{"id": "north_gate", "pos": Vector2(3300.0, 340.0), "radius": 36.0,
				"to_map": "grey_marches", "to_point": "east_gate", "prompt": "[E] The Grey Marches — West Road"},
		],
		"creature_table": [
			{"type": "wolf", "name": "Wild Wolf", "count": 9, "pack": 3, "hp": 32, "damage": 7, "speed": 90, "patrol": 130,
				"area": Rect2(600, 800, 2400, 1600)},
			{"type": "skeleton_warrior", "name": "Grave Warband", "count": 6, "pack": 2, "hp": 42, "damage": 10, "speed": 58, "patrol": 90,
				"area": Rect2(4200, 3200, 1800, 1400)},
			{"type": "orc_rogue", "name": "Deserter", "count": 4, "pack": 2, "hp": 36, "damage": 9, "speed": 78, "patrol": 100,
				"area": Rect2(4800, 900, 1400, 1100)},
		],
	},

	# ---------------- planned (flip built:true per batch; canon names) ------
	"chamber_depths": {"built": false, "name": "The Chamber Depths", "continent": 1, "region": "border", "biome": "cave"},
	# ---------------- WEST — Angel Wings (Humans, Queen Fielderine) ---------
	"grey_marches": {
		"built": true,
		"name": "The Grey Marches",
		"continent": 1, "region": "west", "biome": "deadforest",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.84, 0.82, 0.80),
		"player_spawn": Vector2(6900.0, 2560.0),
		"tree_density": 1.6,
		"roads": [[Vector2(7040, 2560), Vector2(5200, 2500), Vector2(3400, 2560), Vector2(1500, 2620), Vector2(120, 2600)]],
		"landmarks": [
			{"type": "cottage", "pos": Vector2(4200, 1600)},       # abandoned forester's holding
			{"type": "graves", "pos": Vector2(2600, 3400), "count": 9},
			{"type": "inscription_stone", "pos": Vector2(3300, 1100), "live": false},
			{"type": "dolmen", "pos": Vector2(1200, 1400)},
			{"type": "camp", "pos": Vector2(5400, 3600)},          # cult fire
			{"type": "bones", "pos": Vector2(3350, 1160)},
		],
		"warm_patches": [Vector2(3320, 1150)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(1800, 2000)},
			{"kind": "standing_farmer", "pos": Vector2(4900, 2800)},
		],
		"waystations": [{"id": "marches_post", "pos": Vector2(5300, 2620)}],
		"border_gaps": [Rect2(6940, 2440, 220, 280), Rect2(0, 2480, 240, 280)],
		"travel_points": [
			{"id": "east_gate", "pos": Vector2(7000.0, 2560.0), "radius": 34.0,
				"to_map": "stonepath", "to_point": "north_gate", "prompt": "[E] The Stonepath"},
			{"id": "west_gate", "pos": Vector2(150.0, 2600.0), "radius": 34.0,
				"to_map": "western_lowlands", "to_point": "east_entry", "prompt": "[E] The Western Lowlands"},
		],
		"creature_table": [
			{"type": "wolf", "name": "Greywolf", "count": 10, "pack": 3, "hp": 34, "damage": 8, "speed": 92, "patrol": 130,
				"area": Rect2(1000, 800, 3200, 1600)},
			{"type": "orc_shaman", "name": "Cult Zealot", "count": 5, "pack": 2, "hp": 38, "damage": 9, "speed": 70, "patrol": 90,
				"area": Rect2(4600, 3200, 1800, 1200)},
			{"type": "skeleton_mage", "name": "The Hungering", "count": 4, "pack": 1, "hp": 24, "damage": 6, "speed": 24, "patrol": 16,
				"area": Rect2(2200, 2800, 1400, 1000)},
		],
	},

	"western_lowlands": {
		"built": true,
		"name": "The Western Lowlands",
		"continent": 1, "region": "west", "biome": "farmland",
		"tiles_w": 240, "tiles_h": 160,
		"dusk_tint": Color(0.98, 0.90, 0.78),
		"player_spawn": Vector2(7480.0, 2560.0),
		"tree_density": 0.5,
		"river": [Vector2(2000, 0), Vector2(2100, 1800), Vector2(2300, 3400), Vector2(2200, 5120)],
		"river_width": 90.0,
		"river_color": Color(0.30, 0.34, 0.38, 0.9),
		"roads": [[Vector2(7560, 2560), Vector2(5600, 2520), Vector2(3800, 2560), Vector2(2400, 2600), Vector2(140, 2620)]],
		"landmarks": [
			{"type": "hamlet", "pos": Vector2(5200, 2000), "count": 4},
			{"type": "hamlet", "pos": Vector2(3600, 3300), "count": 3},
			{"type": "barn", "pos": Vector2(4600, 2900)},
			{"type": "well", "pos": Vector2(5150, 2100)},
			{"type": "shed", "pos": Vector2(3500, 1500)},
			{"type": "graves", "pos": Vector2(6400, 3800), "count": 4},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "full_granary", "pos": Vector2(6200, 1700)},   # famine w/ a FULL granary (canon)
			{"kind": "standing_farmer", "pos": Vector2(4400, 2450)},
		],
		"waystations": [{"id": "lowlands_barge", "pos": Vector2(2350, 2650)}],
		"border_gaps": [Rect2(7420, 2400, 260, 300), Rect2(0, 2500, 260, 280)],
		"travel_points": [
			{"id": "east_entry", "pos": Vector2(7520.0, 2560.0), "radius": 34.0,
				"to_map": "grey_marches", "to_point": "west_gate", "prompt": "[E] The Grey Marches"},
			{"id": "west_gate", "pos": Vector2(170.0, 2620.0), "radius": 34.0,
				"to_map": "angel_wings", "to_point": "east_gate", "prompt": "[E] Angel Wings — the Human Capital"},
		],
		"creature_table": [
			{"type": "orc_rogue", "name": "Bandit", "count": 8, "pack": 3, "hp": 34, "damage": 8, "speed": 80, "patrol": 110,
				"area": Rect2(800, 800, 2400, 1400)},
			{"type": "boar", "name": "Field Boar", "count": 6, "pack": 2, "hp": 26, "damage": 5, "speed": 70, "patrol": 90,
				"area": Rect2(4800, 3600, 2200, 1200)},
			{"type": "skeleton_mage", "name": "The Hungering", "count": 5, "pack": 1, "hp": 24, "damage": 6, "speed": 24, "patrol": 16,
				"area": Rect2(5600, 1200, 1600, 1000)},
		],
	},

	"angel_wings": {
		"built": true,
		"name": "Angel Wings",
		"continent": 1, "region": "west", "biome": "farmland", "capital": true,
		"tiles_w": 320, "tiles_h": 256,
		"dusk_tint": Color(0.98, 0.90, 0.78),
		"music": MUSIC_TOWN,
		"player_spawn": Vector2(10020.0, 4100.0),
		"tree_density": 0.35,
		# The river-capital: the Vein delta runs through the city to the docks.
		"river": [Vector2(5200, 0), Vector2(5100, 2600), Vector2(4900, 5200), Vector2(5100, 8192)],
		"river_width": 130.0,
		"river_color": Color(0.30, 0.34, 0.38, 0.9),
		"roads": [
			[Vector2(10100, 4100), Vector2(8200, 4080), Vector2(6400, 4100), Vector2(5400, 4120)],
			[Vector2(5400, 4120), Vector2(4300, 4100), Vector2(2800, 4060), Vector2(1400, 4100)],
			[Vector2(4300, 4100), Vector2(4260, 2600), Vector2(4300, 1400)],
			[Vector2(4300, 4100), Vector2(4340, 5600), Vector2(4300, 6900)],
			[Vector2(6400, 4100), Vector2(6440, 2800), Vector2(6400, 1800)],
			[Vector2(6400, 4100), Vector2(6360, 5400), Vector2(6400, 6400)],
		],
		"landmarks": [
			# — Grain-market heart —
			{"type": "plaza", "pos": Vector2(5900, 4060), "count": 6},
			{"type": "fountain", "pos": Vector2(5900, 4090)},
			{"type": "stall", "pos": Vector2(5640, 3950)},
			{"type": "stall", "pos": Vector2(6160, 3950)},
			{"type": "stall", "pos": Vector2(5640, 4230)},
			{"type": "stall", "pos": Vector2(6160, 4230)},
			{"type": "shop", "pos": Vector2(6700, 3800)},
			{"type": "workshop", "pos": Vector2(5200, 3700)},
			# — The Lead Vault (NW): a room designed around NOT using power —
			{"type": "manor", "pos": Vector2(4300, 1200)},
			{"type": "statue", "pos": Vector2(4160, 1420)},
			{"type": "stone_row", "pos": Vector2(4080, 1500), "count": 4},
			# — Maren's Orphanage (E): warm, overcrowded, load-bearing —
			{"type": "manor", "pos": Vector2(8200, 3400)},
			{"type": "well", "pos": Vector2(8060, 3660)},
			# — River docks (S) —
			{"type": "workshop", "pos": Vector2(4700, 6600)},
			{"type": "shed", "pos": Vector2(5450, 6500)},
			{"type": "stall", "pos": Vector2(5100, 6700)},
			# — Thatch sprawl: authored district clusters —
			{"type": "hamlet", "pos": Vector2(7300, 2600), "count": 5},
			{"type": "hamlet", "pos": Vector2(7600, 5200), "count": 5},
			{"type": "hamlet", "pos": Vector2(3300, 3000), "count": 4},
			{"type": "hamlet", "pos": Vector2(3200, 5300), "count": 5},
			{"type": "hamlet", "pos": Vector2(6900, 6300), "count": 4},
			{"type": "hamlet", "pos": Vector2(8700, 4400), "count": 4},
			{"type": "hamlet", "pos": Vector2(2200, 2200), "count": 3},
			{"type": "barn", "pos": Vector2(2600, 6000)},
			{"type": "well", "pos": Vector2(7350, 2820)},
			{"type": "well", "pos": Vector2(3250, 5520)},
		],
		"warm_patches": [Vector2(8260, 3560)],   # the copper handprint... it is here
		"vignettes": [
			{"kind": "chalk_handprints", "pos": Vector2(8140, 3520)},  # orphanage wall (canon)
			{"kind": "empty_stall", "pos": Vector2(5900, 4380)},
			{"kind": "standing_farmer", "pos": Vector2(9200, 4300)},
		],
		"waystations": [{"id": "angel_gate", "pos": Vector2(9800, 4180)}],
		"border_gaps": [Rect2(9960, 3960, 280, 300), Rect2(1260, 3960, 280, 300)],
		"travel_points": [
			{"id": "east_gate", "pos": Vector2(10060.0, 4100.0), "radius": 36.0,
				"to_map": "western_lowlands", "to_point": "west_gate", "prompt": "[E] The Western Lowlands"},
			{"id": "west_gate", "pos": Vector2(1300.0, 4100.0), "radius": 36.0,
				"to_map": "famine_fields", "to_point": "east_entry", "prompt": "[E] The Famine Fields"},
		],
		"creature_table": [
			{"type": "orc_rogue", "name": "Alley Cutpurse", "count": 4, "pack": 2, "hp": 30, "damage": 7, "speed": 82, "patrol": 90,
				"area": Rect2(1800, 6000, 1600, 1400)},
		],
	},

	"famine_fields": {
		"built": true,
		"name": "The Famine Fields",
		"continent": 1, "region": "west", "biome": "farmland",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.94, 0.86, 0.74),
		"player_spawn": Vector2(7000.0, 2560.0),
		"tree_density": 0.45,
		"roads": [[Vector2(7080, 2560), Vector2(5200, 2600), Vector2(3400, 2560), Vector2(140, 2560)]],
		"landmarks": [
			{"type": "hamlet", "pos": Vector2(4800, 1800), "count": 3},   # the famine village
			{"type": "barn", "pos": Vector2(5200, 2100)},                 # the FULL granary
			{"type": "cottage", "pos": Vector2(2600, 3400)},              # burned farmstead
			{"type": "graves", "pos": Vector2(2900, 3700), "count": 7},
			{"type": "camp", "pos": Vector2(1600, 1600)},                 # cult fire
			{"type": "inscription_stone", "pos": Vector2(3800, 1200), "live": true},
		],
		"warm_patches": [Vector2(3820, 1260), Vector2(4850, 1900)],
		"vignettes": [
			{"kind": "full_granary", "pos": Vector2(5250, 2050)},
			{"kind": "cold_camp", "pos": Vector2(6100, 3400)},
			{"kind": "standing_farmer", "pos": Vector2(4500, 2200)},
		],
		"waystations": [{"id": "famine_post", "pos": Vector2(5300, 2660)}],
		"border_gaps": [Rect2(6980, 2420, 220, 300), Rect2(0, 2440, 240, 280)],
		"travel_points": [
			{"id": "east_entry", "pos": Vector2(7040.0, 2560.0), "radius": 34.0,
				"to_map": "angel_wings", "to_point": "west_gate", "prompt": "[E] Angel Wings"},
			{"id": "west_gate", "pos": Vector2(170.0, 2560.0), "radius": 34.0,
				"to_map": "riverfork", "to_point": "east_entry", "prompt": "[E] Riverfork"},
		],
		"creature_table": [
			{"type": "orc_shaman", "name": "Cult Zealot", "count": 6, "pack": 2, "hp": 38, "damage": 9, "speed": 70, "patrol": 90,
				"area": Rect2(1000, 1000, 2000, 1400)},
			{"type": "wolf", "name": "Starving Dog", "count": 6, "pack": 3, "hp": 20, "damage": 5, "speed": 96, "patrol": 130,
				"area": Rect2(4200, 3200, 2200, 1200)},
			{"type": "skeleton_mage", "name": "The Hungering", "count": 7, "pack": 1, "hp": 24, "damage": 6, "speed": 24, "patrol": 16,
				"area": Rect2(3600, 1600, 2200, 1400)},
		],
	},

	"riverfork": {
		"built": true,
		"name": "Riverfork",
		"continent": 1, "region": "west", "biome": "farmland",
		"tiles_w": 208, "tiles_h": 160,
		"dusk_tint": Color(0.92, 0.86, 0.76),
		"player_spawn": Vector2(6480.0, 2560.0),
		"tree_density": 0.6,
		# The Iron Vein delta: two arms meeting — the fork.
		"river": [Vector2(0, 1400), Vector2(2400, 2000), Vector2(4200, 2600), Vector2(6656, 2900)],
		"river_width": 120.0,
		"river_color": Color(0.32, 0.30, 0.30, 0.92),
		"roads": [[Vector2(6540, 2560), Vector2(4800, 2500), Vector2(3200, 2450), Vector2(2400, 2350)]],
		"landmarks": [
			{"type": "workshop", "pos": Vector2(2500, 2100)},   # toll post
			{"type": "shed", "pos": Vector2(3900, 2250)},
			{"type": "stall", "pos": Vector2(3000, 2300)},
			{"type": "camp", "pos": Vector2(1400, 3600)},       # bandit-lord fire
			{"type": "graves", "pos": Vector2(5400, 1200), "count": 5},
			{"type": "stump", "pos": Vector2(4600, 3400)},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "empty_stall", "pos": Vector2(3060, 2380)},
			{"kind": "boot_prints", "pos": Vector2(2550, 2200)},
		],
		"waystations": [{"id": "riverfork_docks", "pos": Vector2(2700, 2260)}],
		"border_gaps": [Rect2(6420, 2420, 236, 300)],
		"travel_points": [
			{"id": "east_entry", "pos": Vector2(6500.0, 2560.0), "radius": 34.0,
				"to_map": "famine_fields", "to_point": "west_gate", "prompt": "[E] The Famine Fields"},
		],
		"creature_table": [
			{"type": "orc_warrior", "name": "Bandit-Lord's Enforcer", "count": 5, "pack": 2, "hp": 52, "damage": 11, "speed": 72, "patrol": 100,
				"area": Rect2(900, 3000, 1800, 1400)},
			{"type": "orc_rogue", "name": "River Smuggler", "count": 6, "pack": 2, "hp": 32, "damage": 8, "speed": 84, "patrol": 110,
				"area": Rect2(4400, 1400, 1800, 1200)},
			{"type": "boar", "name": "Bog Boar", "count": 4, "pack": 2, "hp": 26, "damage": 5, "speed": 70, "patrol": 90,
				"area": Rect2(3200, 3400, 1800, 1000)},
		],
	},
	"black_night": {"built": false, "name": "Black Night", "continent": 1, "region": "north", "biome": "tundra", "capital": true,
		# Canon: NO fog here -- the air is unnaturally clear and still. Light
		# constant snow under the canopy of un-light; never rain, never fog.
		"weather": [[3, 6], [0, 3]]},  # [SNOW x6, CLEAR x3]
	"threadlands": {"built": false, "name": "The Threadlands", "continent": 1, "region": "north", "biome": "tundra"},
	"listening_steppe": {"built": false, "name": "The Listening Steppe", "continent": 1, "region": "north", "biome": "tundra"},
	"gravemark_tundra": {"built": false, "name": "Gravemark Tundra", "continent": 1, "region": "north", "biome": "tundra"},
	"bloodstone_pit": {"built": false, "name": "The Grave & Bloodstone Pit", "continent": 1, "region": "north", "biome": "cave"},
	"blestem": {"built": false, "name": "Blestem", "continent": 1, "region": "east", "biome": "ridge", "capital": true},
	"eastern_ridges": {"built": false, "name": "The Eastern Ridges", "continent": 1, "region": "east", "biome": "ridge"},
	"lichenreach": {"built": false, "name": "Lichenreach", "continent": 1, "region": "east", "biome": "cave"},
	"transcub_vale": {"built": false, "name": "The Transcub Vale", "continent": 1, "region": "east", "biome": "ridge"},
	"whisper_passes": {"built": false, "name": "The Whisper Passes", "continent": 1, "region": "east", "biome": "ridge"},
	"sangeroasa": {"built": false, "name": "Sangeroasa", "continent": 1, "region": "south", "biome": "volcanic", "capital": true},
	"the_gift": {"built": false, "name": "The Gift", "continent": 1, "region": "south", "biome": "volcanic"},
	"ashvents": {"built": false, "name": "The Ashvents", "continent": 1, "region": "south", "biome": "volcanic"},
	"basaltfang": {"built": false, "name": "Basaltfang Range", "continent": 1, "region": "south", "biome": "volcanic"},
	"bloodroad": {"built": false, "name": "The Bloodroad", "continent": 1, "region": "south", "biome": "volcanic"},
	# ---------------- Continent 2: The Collector's Coast --------------------
	"greyhollow": {"built": false, "name": "Greyhollow", "continent": 2, "region": "coast", "biome": "port", "capital": true},
	"drowned_quarter": {"built": false, "name": "The Drowned Quarter", "continent": 2, "region": "coast", "biome": "port"},
	"canal_maze": {"built": false, "name": "The Canal Maze", "continent": 2, "region": "coast", "biome": "port"},
	"grey_piers": {"built": false, "name": "The Grey Piers", "continent": 2, "region": "coast", "biome": "port"},
	"salt_fens": {"built": false, "name": "The Salt Fens", "continent": 2, "region": "coast", "biome": "bog"},
	"dead_timber": {"built": false, "name": "The Dead Timber", "continent": 2, "region": "coast", "biome": "deadforest"},
	"ledger_roads": {"built": false, "name": "The Ledger Roads", "continent": 2, "region": "coast", "biome": "deadforest"},
	"morven_reach": {"built": false, "name": "Morven Reach", "continent": 2, "region": "coast", "biome": "port"},
	"the_archive": {"built": false, "name": "The Archive", "continent": 2, "region": "coast", "biome": "tundra", "capital": true},
	"anchorfall": {"built": false, "name": "Anchorfall", "continent": 2, "region": "coast", "biome": "volcanic"},
	"finalized_fields": {"built": false, "name": "The Finalized Fields", "continent": 2, "region": "coast", "biome": "moor"},
	"coldharbor_deep": {"built": false, "name": "Coldharbor Deep", "continent": 2, "region": "coast", "biome": "cave"},
	"orange_fog": {"built": false, "name": "The Orange Fog", "continent": 2, "region": "coast", "biome": "deadforest"},
	"last_hearth": {"built": false, "name": "The Last Hearth", "continent": 2, "region": "coast", "biome": "moor"},
}
