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
	"steppe": "amb_wind_howl",
	"port": "amb_harbor",
	"cave": "amb_cave",
}

## Waystation route graph (WoW flight-path rules: travel only along links,
## both endpoints discovered). The Grey Ferry (continent link) joins in
## batch G: riverfork_docks <-> grey_piers.
const ROUTES := {
	"bent_oar": ["vetka_square"],
	"vetka_square": ["bent_oar", "copper_cross"],
	"copper_cross": ["vetka_square", "stonepath_cross", "bloodroad_post"],
	"bloodroad_post": ["copper_cross", "basalt_post"],
	"basalt_post": ["bloodroad_post", "sangeroasa_gate"],
	"sangeroasa_gate": ["basalt_post", "gift_post", "ashvent_post"],
	"gift_post": ["sangeroasa_gate"],
	"ashvent_post": ["sangeroasa_gate"],
	"stonepath_cross": ["copper_cross", "marches_post", "steppe_post", "whisper_post"],
	"whisper_post": ["stonepath_cross", "ridge_post"],
	"ridge_post": ["whisper_post", "blestem_gate"],
	"blestem_gate": ["ridge_post", "vale_post"],
	"vale_post": ["blestem_gate"],
	"steppe_post": ["stonepath_cross", "thread_post"],
	"thread_post": ["steppe_post", "black_gate"],
	"black_gate": ["thread_post", "gravemark_post"],
	"gravemark_post": ["black_gate"],
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
	var out: Dictionary = (_ZONES.get(id, {}) as Dictionary).duplicate(true)
	if not out.is_empty():
		out["id"] = id
	return out


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
			{"type": "ore_rocks", "pos": Vector2(4800, 1600), "count": 6},   # bog-iron diggings
			{"type": "ore_rocks", "pos": Vector2(1400, 2500), "count": 5},
			{"type": "ore_rocks", "pos": Vector2(5900, 3400), "count": 5},
			{"type": "rocks", "pos": Vector2(3600, 800), "count": 4},
			{"type": "rocks", "pos": Vector2(700, 1400), "count": 4},
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
			{"type": "camp", "pos": Vector2(800, 3400)},          # charcoal-burner's camp, cold
			{"type": "stump", "pos": Vector2(1500, 3700)},
			{"type": "dolmen", "pos": Vector2(4900, 800)},
			{"type": "stump", "pos": Vector2(700, 700)},
			{"type": "bones", "pos": Vector2(1500, 600)},
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
		"roads": [[Vector2(2900, 120), Vector2(2950, 1400), Vector2(3000, 2200), Vector2(4500, 2280), Vector2(6060, 2300)],
			[Vector2(3000, 2200), Vector2(2950, 3400), Vector2(3000, 4480)]],
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
		"border_gaps": [Rect2(2760, 0, 300, 220), Rect2(5940, 2180, 220, 280), Rect2(2850, 4388, 300, 220)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(2900.0, 150.0), "radius": 34.0,
				"to_map": "vetka", "to_point": "south_gate", "prompt": "[E] Vetka"},
			{"id": "south_gate", "pos": Vector2(3000.0, 4460.0), "radius": 36.0,
				"to_map": "bloodroad", "to_point": "north_entry", "prompt": "[E] The Bloodroad — South"},
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
			{"type": "stone_row", "pos": Vector2(3500, 600), "count": 4},
			{"type": "bones", "pos": Vector2(4400, 800)},
			{"type": "camp", "pos": Vector2(2600, 4500)},
			{"type": "bones", "pos": Vector2(3400, 4200)},
		],
		"warm_patches": [Vector2(3300, 2520), Vector2(3340, 2380)],
		"vignettes": [
			{"kind": "empty_stall", "pos": Vector2(3360, 2720)},
			{"kind": "boot_prints", "pos": Vector2(5150, 3850)},
		],
		"waystations": [{"id": "stonepath_cross", "pos": Vector2(3420, 2660)}],
		"border_gaps": [Rect2(0, 2480, 240, 280), Rect2(3160, 0, 300, 240), Rect2(4860, 0, 300, 240), Rect2(6420, 2420, 236, 300)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(160.0, 2600.0), "radius": 34.0,
				"to_map": "copper_wells", "to_point": "east_gate", "prompt": "[E] The Copper Wells"},
			{"id": "north_gate", "pos": Vector2(3300.0, 340.0), "radius": 36.0,
				"to_map": "grey_marches", "to_point": "east_gate", "prompt": "[E] The Grey Marches — West Road"},
			{"id": "north_road", "pos": Vector2(5000.0, 340.0), "radius": 36.0,
				"to_map": "listening_steppe", "to_point": "south_entry", "prompt": "[E] The Listening Steppe — North Road"},
			{"id": "east_gate", "pos": Vector2(6520.0, 2560.0), "radius": 36.0,
				"to_map": "whisper_passes", "to_point": "west_entry", "prompt": "[E] The Whisper Passes — East Road"},
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
			{"type": "dolmen", "pos": Vector2(6200, 600)},
			{"type": "graves", "pos": Vector2(5600, 900), "count": 5},
			{"type": "bones", "pos": Vector2(900, 4300)},
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
			{"type": "cottage", "pos": Vector2(800, 4200)},
			{"type": "camp", "pos": Vector2(1600, 4600)},
			{"type": "shed", "pos": Vector2(6800, 1000)},
			{"type": "stump", "pos": Vector2(700, 700)},
			{"type": "graves", "pos": Vector2(1500, 1000), "count": 3},
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
			# lead-grey, lightless, counter-cultural (canon)
			{"type": "manor", "pos": Vector2(4300, 1200), "tint": Color(0.60, 0.64, 0.70)},
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
			# — sitting #3 identity pass: POOR, CROWDED, ORDINARY (canon):
			#   packed lanes, woodsmoke over every roofline —
			{"type": "cottage", "pos": Vector2(6900, 4400)},
			{"type": "cottage", "pos": Vector2(7150, 4620)},
			{"type": "cottage", "pos": Vector2(6850, 4850)},
			{"type": "cottage", "pos": Vector2(7500, 4700)},
			{"type": "cottage", "pos": Vector2(6650, 4600)},
			{"type": "chimney_smoke", "pos": Vector2(6900, 4400)},
			{"type": "chimney_smoke", "pos": Vector2(7150, 4620)},
			{"type": "chimney_smoke", "pos": Vector2(7500, 4700)},
			{"type": "cottage", "pos": Vector2(3400, 3700)},
			{"type": "cottage", "pos": Vector2(3600, 4150)},
			{"type": "cottage", "pos": Vector2(2900, 4200)},
			{"type": "chimney_smoke", "pos": Vector2(3400, 3700)},
			{"type": "chimney_smoke", "pos": Vector2(3600, 4150)},
			{"type": "cottage", "pos": Vector2(4600, 2300)},
			{"type": "cottage", "pos": Vector2(4050, 2600)},
			{"type": "cottage", "pos": Vector2(4550, 3000)},
			{"type": "chimney_smoke", "pos": Vector2(4600, 2300)},
			# Maren's Orphanage yard (warm, overcrowded, load-bearing)
			{"type": "cottage", "pos": Vector2(8500, 3700)},
			{"type": "stall", "pos": Vector2(8350, 3850)},
			{"type": "statue", "pos": Vector2(8000, 3500)},
			{"type": "chimney_smoke", "pos": Vector2(8200, 3400)},
			{"type": "chimney_smoke", "pos": Vector2(8500, 3700)},
			{"type": "stall", "pos": Vector2(5750, 4550)},
			{"type": "lamp", "pos": Vector2(7000, 4140)},
			{"type": "lamp", "pos": Vector2(4800, 4060)},
			{"type": "lamp", "pos": Vector2(3600, 4140)},
			{"type": "lamp", "pos": Vector2(8300, 4060)},
			{"type": "graves", "pos": Vector2(2200, 5400), "count": 7},
		],
		"warm_patches": [Vector2(8260, 3560)],   # the copper handprint... it is here
		"vignettes": [
			{"kind": "chalk_handprints", "pos": Vector2(8140, 3520)},  # orphanage wall (canon)
			{"kind": "full_granary", "pos": Vector2(3050, 4550)},   # bread everywhere, hunger anyway
			{"kind": "full_granary", "pos": Vector2(7250, 2950)},
			{"kind": "burned_farmstead", "pos": Vector2(2400, 2600)},
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
			{"type": "graves", "pos": Vector2(800, 4300), "count": 5},
			{"type": "camp", "pos": Vector2(1500, 4600)},
			{"type": "stone_row", "pos": Vector2(6300, 800), "count": 3},
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
			{"type": "dolmen", "pos": Vector2(700, 600)},
			{"type": "stump", "pos": Vector2(1500, 900)},
			{"type": "bones", "pos": Vector2(5800, 4300)},
			{"type": "stone_row", "pos": Vector2(3500, 700), "count": 3},
			{"type": "dolmen", "pos": Vector2(4600, 500)},
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
	# ---------------- NORTH — Black Night (Iele / undead, Lilith) ----------
	"listening_steppe": {
		"built": true,
		"name": "The Listening Steppe",
		"continent": 1, "region": "north", "biome": "steppe",
		"tiles_w": 240, "tiles_h": 176,
		"dusk_tint": Color(0.74, 0.80, 0.94),
		"player_spawn": Vector2(3840.0, 5400.0),
		"tree_density": 0.5,
		"roads": [[Vector2(3840, 5560), Vector2(3800, 4200), Vector2(3760, 2800), Vector2(3800, 1400), Vector2(3840, 140)]],
		"landmarks": [
			{"type": "inscription_stone", "pos": Vector2(3400, 3600), "live": true},
			{"type": "stone_row", "pos": Vector2(2600, 2400), "count": 5},
			{"type": "dolmen", "pos": Vector2(5200, 4200)},
			{"type": "camp", "pos": Vector2(2200, 4600)},
			{"type": "graves", "pos": Vector2(5600, 1800), "count": 6},
			{"type": "cabin", "pos": Vector2(2900, 1500)},
			{"type": "bones", "pos": Vector2(4600, 3200)},
			{"type": "rocks", "pos": Vector2(1400, 3200), "count": 5},
			{"type": "rocks", "pos": Vector2(6200, 3600), "count": 4},
			# — sitting #2 densification: the steppe LISTENS —
			{"type": "camp", "pos": Vector2(5400, 2600)},            # listener post
			{"type": "camp", "pos": Vector2(1800, 1800)},            # listener post
			{"type": "inscription_stone", "pos": Vector2(2400, 3400), "live": false},
			{"type": "inscription_stone", "pos": Vector2(6000, 4600), "live": true},
			{"type": "dolmen", "pos": Vector2(1400, 4600)},
			{"type": "dolmen", "pos": Vector2(6400, 1400)},
			{"type": "hamlet", "pos": Vector2(4800, 4800), "count": 3},   # herder huts
			{"type": "stall", "pos": Vector2(4000, 4400)},           # wool stall
			{"type": "stone_row", "pos": Vector2(5000, 3600), "count": 4},
			{"type": "stone_row", "pos": Vector2(2000, 2900), "count": 3},
			{"type": "stump", "pos": Vector2(3200, 4700)},
			{"type": "bones", "pos": Vector2(1600, 2400)},
		],
		"warm_patches": [Vector2(3420, 3660), Vector2(6020, 4660)],
		"vignettes": [
			{"kind": "standing_farmer", "pos": Vector2(3900, 3000)},
			{"kind": "standing_farmer", "pos": Vector2(3600, 2200)},
			{"kind": "cold_camp", "pos": Vector2(5000, 5000)},
		],
		"waystations": [{"id": "steppe_post", "pos": Vector2(3960, 5300)}],
		"border_gaps": [Rect2(3700, 5460, 300, 240), Rect2(3700, 0, 300, 240)],
		"travel_points": [
			{"id": "south_entry", "pos": Vector2(3840.0, 5480.0), "radius": 36.0,
				"to_map": "stonepath", "to_point": "north_road", "prompt": "[E] The Stonepath"},
			{"id": "north_gate", "pos": Vector2(3840.0, 180.0), "radius": 36.0,
				"to_map": "threadlands", "to_point": "south_entry", "prompt": "[E] The Threadlands"},
		],
		"creature_table": [
			{"type": "skeleton_mage", "name": "Entranced Pilgrim", "count": 9, "pack": 1, "hp": 24, "damage": 6, "speed": 16, "patrol": 10,
				"area": Rect2(2600, 1800, 2600, 2400)},
			{"type": "wolf", "name": "Snow Wolf", "count": 8, "pack": 3, "hp": 34, "damage": 8, "speed": 92, "patrol": 130,
				"area": Rect2(1000, 1400, 2000, 2600)},
			{"type": "skeleton", "name": "Thread-Touched Dead", "count": 6, "pack": 2, "hp": 36, "damage": 9, "speed": 54, "patrol": 70,
				"area": Rect2(4800, 2600, 1800, 2200)},
		],
	},

	"threadlands": {
		"built": true,
		"name": "The Threadlands",
		"continent": 1, "region": "north", "biome": "tundra",
		"tiles_w": 240, "tiles_h": 176,
		"dusk_tint": Color(0.70, 0.76, 0.94),
		"player_spawn": Vector2(3840.0, 5400.0),
		"tree_density": 0.35,
		"roads": [[Vector2(3840, 5560), Vector2(3880, 4000), Vector2(3840, 2400), Vector2(3800, 140)]],
		"landmarks": [
			{"type": "thread_lines", "pos": Vector2(3200, 3400), "count": 7},
			{"type": "thread_lines", "pos": Vector2(4800, 2200), "count": 6},
			{"type": "thread_lines", "pos": Vector2(2200, 1800), "count": 5},
			{"type": "inscription_stone", "pos": Vector2(4400, 4200), "live": false},
			{"type": "stone_row", "pos": Vector2(2800, 4600), "count": 4},
			{"type": "graves", "pos": Vector2(5400, 3800), "count": 8},
			{"type": "dolmen", "pos": Vector2(1600, 2600)},
			{"type": "cabin", "pos": Vector2(5800, 1400)},
			{"type": "bones", "pos": Vector2(3000, 2600)},
			# — sitting #2 densification: the Threads are EVERYWHERE here —
			{"type": "thread_lines", "pos": Vector2(5600, 4600), "count": 6},
			{"type": "thread_lines", "pos": Vector2(1800, 4200), "count": 5},
			{"type": "thread_lines", "pos": Vector2(6200, 3000), "count": 5},
			{"type": "thread_lines", "pos": Vector2(3600, 1200), "count": 6},
			{"type": "dark_keep", "pos": Vector2(2400, 3400)},
			{"type": "dark_keep", "pos": Vector2(5200, 5000)},
			{"type": "camp", "pos": Vector2(4400, 3400)},
			{"type": "camp", "pos": Vector2(1400, 1400)},
			{"type": "hamlet", "pos": Vector2(6000, 1800), "count": 3},
			{"type": "stone_row", "pos": Vector2(4600, 5200), "count": 4},
			{"type": "graves", "pos": Vector2(2000, 5200), "count": 6},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(4400, 5000)},   # 3 bedrolls, prints in, none out
			{"kind": "standing_farmer", "pos": Vector2(3500, 1600)},
		],
		"waystations": [{"id": "thread_post", "pos": Vector2(3960, 5300)}],
		"border_gaps": [Rect2(3700, 5460, 300, 240), Rect2(3660, 0, 300, 240)],
		"travel_points": [
			{"id": "south_entry", "pos": Vector2(3840.0, 5480.0), "radius": 36.0,
				"to_map": "listening_steppe", "to_point": "north_gate", "prompt": "[E] The Listening Steppe"},
			{"id": "north_gate", "pos": Vector2(3800.0, 180.0), "radius": 36.0,
				"to_map": "black_night", "to_point": "south_gate", "prompt": "[E] Black Night — the City over the Grave"},
		],
		"creature_table": [
			{"type": "skeleton", "name": "Thread-Shell", "count": 10, "pack": 2, "hp": 38, "damage": 9, "speed": 50, "patrol": 60,
				"area": Rect2(2400, 2000, 3000, 2600)},
			{"type": "skeleton_mage", "name": "Entranced Pilgrim", "count": 6, "pack": 1, "hp": 24, "damage": 6, "speed": 14, "patrol": 8,
				"area": Rect2(3200, 3600, 1600, 1400)},
			{"type": "wolf", "name": "Snow Wolf", "count": 6, "pack": 3, "hp": 34, "damage": 8, "speed": 92, "patrol": 130,
				"area": Rect2(1000, 1200, 1800, 2000)},
		],
	},

	"black_night": {
		"built": true,
		"name": "Black Night",
		"continent": 1, "region": "north", "biome": "tundra", "capital": true,
		"tiles_w": 320, "tiles_h": 256,
		"dusk_tint": Color(0.58, 0.62, 0.86),
		"music": MUSIC_TOWN,
		"player_spawn": Vector2(5120.0, 8000.0),
		"tree_density": 0.15,
		# Canon: NO fog ever — the air unnaturally clear; light constant snow.
		"weather": [[3, 6], [0, 3]],
		"roads": [
			[Vector2(5120, 8100), Vector2(5100, 6400), Vector2(5120, 4800), Vector2(5140, 3400)],
			[Vector2(5120, 4800), Vector2(3600, 4760), Vector2(2400, 4800)],
			[Vector2(5120, 4800), Vector2(6600, 4840), Vector2(7800, 4800)],
			[Vector2(5140, 3400), Vector2(4200, 3360), Vector2(3400, 3400)],
			[Vector2(5140, 3400), Vector2(6000, 3440), Vector2(6800, 3400)],
		],
		"landmarks": [
			# — The city over the grave: dark keeps around the still market —
			{"type": "dark_keep", "pos": Vector2(5120, 2600)},          # Council of Six halls
			{"type": "stone_row", "pos": Vector2(4780, 4880), "count": 6},  # the still market's kerbstones
			{"type": "statue", "pos": Vector2(5000, 4720)},
			{"type": "statue", "pos": Vector2(5240, 4720)},
			{"type": "thread_lines", "pos": Vector2(5120, 4700), "count": 8},
			# — sitting #3: outskirt quadrants filled —
			{"type": "statue", "pos": Vector2(2400, 6400)},
			{"type": "statue", "pos": Vector2(8200, 2000)},
			{"type": "stone_row", "pos": Vector2(2000, 2400), "count": 5},
			{"type": "stone_row", "pos": Vector2(8000, 6200), "count": 5},
			{"type": "lamp", "pos": Vector2(3400, 4200)},
			{"type": "lamp", "pos": Vector2(6800, 4100)},
			{"type": "lamp", "pos": Vector2(5200, 2600)},
			{"type": "lamp", "pos": Vector2(5100, 5800)},
			{"type": "graves", "pos": Vector2(8600, 4800), "count": 8},
			{"type": "camp", "pos": Vector2(1600, 6800)},
			{"type": "thread_lines", "pos": Vector2(3600, 4600), "count": 6},
			{"type": "thread_lines", "pos": Vector2(6600, 4700), "count": 6},
			{"type": "thread_lines", "pos": Vector2(5100, 3200), "count": 7},
			{"type": "dark_keep", "pos": Vector2(2800, 4400)},
			{"type": "dark_keep", "pos": Vector2(7400, 4400)},
			{"type": "graves", "pos": Vector2(4200, 6000), "count": 10},
			{"type": "graves", "pos": Vector2(6000, 6100), "count": 10},
			{"type": "inscription_stone", "pos": Vector2(5120, 5600), "live": true},
			{"type": "stone_row", "pos": Vector2(4400, 2200), "count": 6},
			{"type": "stone_row", "pos": Vector2(5800, 2250), "count": 6},
			{"type": "dolmen", "pos": Vector2(3000, 2000)},
			{"type": "dolmen", "pos": Vector2(7200, 2100)},
			{"type": "bones", "pos": Vector2(4800, 5200)},
			{"type": "rocks", "pos": Vector2(2200, 6400), "count": 5},
			{"type": "rocks", "pos": Vector2(7900, 6300), "count": 5},
		],
		"warm_patches": [Vector2(5120, 5660)],
		"vignettes": [
			{"kind": "rows_of_twelve", "pos": Vector2(4900, 4600)},   # the still market (canon)
			{"kind": "cold_camp", "pos": Vector2(3400, 6800)},        # the living family's camp
			{"kind": "standing_farmer", "pos": Vector2(6400, 5600)},
		],
		"waystations": [{"id": "black_gate", "pos": Vector2(5240, 7800)}],
		"border_gaps": [Rect2(4960, 8000, 320, 192)],
		"travel_points": [
			{"id": "south_gate", "pos": Vector2(5120.0, 8080.0), "radius": 38.0,
				"to_map": "threadlands", "to_point": "north_gate", "prompt": "[E] The Threadlands"},
			{"id": "east_gate", "pos": Vector2(9980.0, 4800.0), "radius": 38.0,
				"to_map": "gravemark_tundra", "to_point": "west_entry", "prompt": "[E] Gravemark Tundra"},
		],
		"creature_table": [
			{"type": "skeleton_mage", "name": "Iele Shell", "count": 14, "pack": 1, "hp": 26, "damage": 6, "speed": 12, "patrol": 8,
				"area": Rect2(3600, 3800, 3000, 1800)},
			{"type": "skeleton_warrior", "name": "Thread Warden", "count": 6, "pack": 2, "hp": 48, "damage": 11, "speed": 56, "patrol": 80,
				"area": Rect2(4400, 2000, 1600, 1200)},
		],
	},

	"gravemark_tundra": {
		"built": true,
		"name": "Gravemark Tundra",
		"continent": 1, "region": "north", "biome": "tundra",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.72, 0.78, 0.94),
		"player_spawn": Vector2(220.0, 2560.0),
		"tree_density": 0.4,
		"roads": [[Vector2(140, 2560), Vector2(1800, 2600), Vector2(3600, 2560), Vector2(5400, 2600)]],
		"landmarks": [
			{"type": "graves", "pos": Vector2(2400, 1600), "count": 12},
			{"type": "graves", "pos": Vector2(3800, 3400), "count": 12},
			{"type": "graves", "pos": Vector2(5200, 1800), "count": 10},
			{"type": "inscription_stone", "pos": Vector2(3000, 2200), "live": false},
			{"type": "inscription_stone", "pos": Vector2(4600, 4000), "live": true},
			{"type": "stone_row", "pos": Vector2(1600, 3600), "count": 6},
			{"type": "dolmen", "pos": Vector2(5800, 3000)},
			{"type": "bones", "pos": Vector2(2600, 2800)},
			{"type": "bones", "pos": Vector2(4200, 1400)},
			{"type": "cabin", "pos": Vector2(1200, 1400)},
			# — sitting #2 densification —
			{"type": "graves", "pos": Vector2(1600, 4400), "count": 8},
			{"type": "graves", "pos": Vector2(6200, 2600), "count": 6},
			{"type": "stone_row", "pos": Vector2(3200, 4200), "count": 5},
			{"type": "stone_row", "pos": Vector2(5000, 1200), "count": 4},
			{"type": "dolmen", "pos": Vector2(2200, 2200)},
			{"type": "camp", "pos": Vector2(6400, 4200)},
			{"type": "statue", "pos": Vector2(3900, 3900)},
		],
		"warm_patches": [Vector2(4620, 4060)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(5600, 4400)},
			{"kind": "boot_prints", "pos": Vector2(3050, 2260)},
		],
		"waystations": [{"id": "gravemark_post", "pos": Vector2(340, 2660)}],
		"border_gaps": [Rect2(0, 2440, 260, 280)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(170.0, 2560.0), "radius": 36.0,
				"to_map": "black_night", "to_point": "east_gate", "prompt": "[E] Black Night"},
		],
		"creature_table": [
			{"type": "skeleton", "name": "Great-War Dead", "count": 12, "pack": 3, "hp": 40, "damage": 10, "speed": 52, "patrol": 70,
				"area": Rect2(2000, 1200, 3400, 2600)},
			{"type": "skeleton_warrior", "name": "Barrow Warden", "count": 5, "pack": 1, "hp": 52, "damage": 12, "speed": 58, "patrol": 90,
				"area": Rect2(3400, 3000, 2000, 1600)},
			{"type": "wolf", "name": "Bone-Hound", "count": 6, "pack": 3, "hp": 34, "damage": 8, "speed": 94, "patrol": 130,
				"area": Rect2(800, 3400, 2000, 1400)},
		],
	},
	"bloodstone_pit": {"built": false, "name": "The Grave & Bloodstone Pit", "continent": 1, "region": "north", "biome": "cave"},
	# ---------------- EAST — Blestem (Strigoi, Cazimir) --------------------
	"whisper_passes": {
		"built": true,
		"name": "The Whisper Passes",
		"continent": 1, "region": "east", "biome": "ridge",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.72, 0.72, 0.84),
		"player_spawn": Vector2(220.0, 2560.0),
		"tree_density": 0.9,
		"roads": [[Vector2(140, 2560), Vector2(1800, 2500), Vector2(3600, 2600), Vector2(5400, 2520), Vector2(7020, 2560)]],
		"landmarks": [
			{"type": "rocks", "pos": Vector2(2400, 1800), "count": 6},
			{"type": "rocks", "pos": Vector2(4600, 3400), "count": 6},
			{"type": "camp", "pos": Vector2(3200, 1400)},              # listener watch-post
			{"type": "camp", "pos": Vector2(5400, 3800)},              # listener watch-post
			{"type": "inscription_stone", "pos": Vector2(4000, 2000), "live": false},
			{"type": "dolmen", "pos": Vector2(1400, 3600)},
			{"type": "stone_row", "pos": Vector2(6000, 1600), "count": 4},
			{"type": "bones", "pos": Vector2(2800, 3000)},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "boot_prints", "pos": Vector2(3250, 1450)},       # twelve, facing the wall
			{"kind": "cold_camp", "pos": Vector2(1800, 1200)},
		],
		"waystations": [{"id": "whisper_post", "pos": Vector2(340, 2660)}],
		"border_gaps": [Rect2(0, 2440, 260, 280), Rect2(6900, 2420, 268, 280)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(170.0, 2560.0), "radius": 36.0,
				"to_map": "stonepath", "to_point": "east_gate", "prompt": "[E] The Stonepath"},
			{"id": "east_gate", "pos": Vector2(6980.0, 2560.0), "radius": 36.0,
				"to_map": "eastern_ridges", "to_point": "west_entry", "prompt": "[E] The Eastern Ridges"},
		],
		"creature_table": [
			{"type": "skeleton_rogue", "name": "Listener", "count": 8, "pack": 1, "hp": 30, "damage": 8, "speed": 74, "patrol": 90,
				"area": Rect2(2400, 1000, 2800, 1600)},
			{"type": "wolf", "name": "Ridge Wolf", "count": 8, "pack": 3, "hp": 34, "damage": 8, "speed": 92, "patrol": 130,
				"area": Rect2(1000, 3000, 2600, 1600)},
			{"type": "orc_rogue", "name": "Strigoi Blade", "count": 5, "pack": 2, "hp": 38, "damage": 10, "speed": 84, "patrol": 100,
				"area": Rect2(4800, 3000, 1800, 1400)},
		],
	},

	"eastern_ridges": {
		"built": true,
		"name": "The Eastern Ridges",
		"continent": 1, "region": "east", "biome": "ridge",
		"tiles_w": 240, "tiles_h": 176,
		"dusk_tint": Color(0.68, 0.68, 0.82),
		"player_spawn": Vector2(220.0, 2820.0),
		"tree_density": 1.1,
		"roads": [[Vector2(140, 2820), Vector2(2000, 2760), Vector2(3840, 2820), Vector2(5600, 2760), Vector2(7540, 2820)]],
		"landmarks": [
			{"type": "rocks", "pos": Vector2(2000, 1600), "count": 8},
			{"type": "rocks", "pos": Vector2(5200, 4200), "count": 8},
			{"type": "rocks", "pos": Vector2(3600, 1200), "count": 6},
			{"type": "dolmen", "pos": Vector2(4400, 3600)},
			{"type": "inscription_stone", "pos": Vector2(2800, 3800), "live": true},
			{"type": "camp", "pos": Vector2(6200, 1800)},
			{"type": "graves", "pos": Vector2(1400, 4200), "count": 5},
			{"type": "cabin", "pos": Vector2(5800, 2200)},
			{"type": "bones", "pos": Vector2(3400, 2400)},
		],
		"warm_patches": [Vector2(2820, 3860)],
		"vignettes": [
			{"kind": "standing_farmer", "pos": Vector2(3000, 2300)},
			{"kind": "cold_camp", "pos": Vector2(6600, 4400)},
		],
		"waystations": [{"id": "ridge_post", "pos": Vector2(340, 2920)}],
		"border_gaps": [Rect2(0, 2700, 260, 280), Rect2(7420, 2700, 260, 280)],
		"travel_points": [
			{"id": "west_entry", "pos": Vector2(170.0, 2820.0), "radius": 36.0,
				"to_map": "whisper_passes", "to_point": "east_gate", "prompt": "[E] The Whisper Passes"},
			{"id": "east_gate", "pos": Vector2(7500.0, 2820.0), "radius": 36.0,
				"to_map": "blestem", "to_point": "west_gate", "prompt": "[E] Blestem — the Listening City"},
		],
		"creature_table": [
			{"type": "orc_rogue", "name": "Strigoi Patrol", "count": 8, "pack": 2, "hp": 38, "damage": 10, "speed": 84, "patrol": 110,
				"area": Rect2(3000, 1400, 3000, 1800)},
			{"type": "wolf", "name": "Mountain Wolf", "count": 9, "pack": 3, "hp": 36, "damage": 9, "speed": 94, "patrol": 140,
				"area": Rect2(1200, 3400, 2800, 1600)},
			{"type": "skeleton_rogue", "name": "Listener", "count": 6, "pack": 1, "hp": 30, "damage": 8, "speed": 74, "patrol": 80,
				"area": Rect2(5200, 3200, 2000, 1600)},
		],
	},

	"blestem": {
		"built": true,
		"name": "Blestem",
		"continent": 1, "region": "east", "biome": "ridge", "capital": true,
		"palette": "blestem",   # black basalt + old iron (canon: a city that
		                        # does not want to be walked)
		"tiles_w": 320, "tiles_h": 256,
		"dusk_tint": Color(0.52, 0.50, 0.72),
		"ambient_lock": Color(0.60, 0.55, 0.72),   # perpetual dusk — canon
		"music": MUSIC_TOWN,
		"player_spawn": Vector2(240.0, 4100.0),
		"tree_density": 0.2,
		# Perpetual dusk-light; fog pools thickest here (biome default table).
		"roads": [
			[Vector2(160, 4100), Vector2(1800, 4060), Vector2(3400, 4100), Vector2(5100, 4080)],
			[Vector2(5100, 4080), Vector2(5140, 2800), Vector2(5100, 1800)],
			[Vector2(5100, 4080), Vector2(5060, 5400), Vector2(5100, 6400)],
			[Vector2(5100, 2800), Vector2(3800, 2760), Vector2(2800, 2800)],
			[Vector2(5100, 2800), Vector2(6400, 2840), Vector2(7400, 2800)],
			[Vector2(5060, 5400), Vector2(3900, 5440), Vector2(3000, 5400)],
			[Vector2(5060, 5400), Vector2(6300, 5360), Vector2(7200, 5400)],
		],
		"landmarks": [
			# — The Black Spire at the heart —
			{"type": "spire", "pos": Vector2(5480, 3400)},
			{"type": "thread_lines", "pos": Vector2(5480, 3500), "count": 4},
			# — The Riddler's Quarter (disorientation maze of dark keeps) —
			{"type": "dark_keep", "pos": Vector2(2800, 2500)},
			{"type": "dark_keep", "pos": Vector2(3600, 2200)},
			{"type": "dark_keep", "pos": Vector2(2400, 3100)},
			# — The Lower Market (information as currency) —
			{"type": "stall", "pos": Vector2(6300, 5200)},
			{"type": "stall", "pos": Vector2(6700, 5350)},
			{"type": "stall", "pos": Vector2(6560, 5680)},
			{"type": "shop", "pos": Vector2(7000, 5100)},
			# — Churches of Transcub (ivy-eaten, half-abandoned) —
			{"type": "manor", "pos": Vector2(3400, 5800)},
			{"type": "graves", "pos": Vector2(3100, 6100), "count": 6},
			# — the lamp-oil city: lamps line every street —
			{"type": "lamp", "pos": Vector2(4400, 4020)},
			{"type": "lamp", "pos": Vector2(5800, 4140)},
			{"type": "lamp", "pos": Vector2(5160, 3000)},
			{"type": "lamp", "pos": Vector2(5040, 5000)},
			{"type": "lamp", "pos": Vector2(3400, 4160)},
			{"type": "lamp", "pos": Vector2(2200, 4040)},
			{"type": "lamp", "pos": Vector2(6800, 2860)},
			{"type": "lamp", "pos": Vector2(3400, 2860)},
			{"type": "dark_keep", "pos": Vector2(7000, 2200)},
			{"type": "dark_keep", "pos": Vector2(2200, 5600)},
			# — maze thickening: old iron and dead ends —
			{"type": "dark_keep", "pos": Vector2(6300, 1700)},
			{"type": "dark_keep", "pos": Vector2(7600, 3300)},
			{"type": "dark_keep", "pos": Vector2(3000, 6100)},
			{"type": "dark_keep", "pos": Vector2(1700, 3600)},
			{"type": "stone_row", "pos": Vector2(4400, 3100), "count": 5},
			{"type": "stone_row", "pos": Vector2(5900, 4600), "count": 4},
			{"type": "stone_row", "pos": Vector2(3700, 5000), "count": 4},
			{"type": "lamp", "pos": Vector2(5480, 3700)},
			{"type": "lamp", "pos": Vector2(4500, 2820)},
			{"type": "lamp", "pos": Vector2(6100, 5420)},
			{"type": "camp", "pos": Vector2(8200, 6000)},
			{"type": "rocks", "pos": Vector2(8600, 4400), "count": 6},
			{"type": "rocks", "pos": Vector2(1200, 2000), "count": 5},
			{"type": "inscription_stone", "pos": Vector2(5100, 2000), "live": false},
			# — capital density: lamp-lit residential streets —
			{"type": "cottage", "pos": Vector2(3900, 3300)},
			{"type": "cottage", "pos": Vector2(4400, 2400)},
			{"type": "cottage", "pos": Vector2(6000, 3400)},
			{"type": "cottage", "pos": Vector2(6500, 3700)},
			{"type": "cottage", "pos": Vector2(3000, 4700)},
			{"type": "cottage", "pos": Vector2(2400, 4500)},
			{"type": "cottage", "pos": Vector2(5800, 6000)},
			{"type": "tavern", "pos": Vector2(5700, 4500)},
			{"type": "workshop", "pos": Vector2(7300, 5100)},
			{"type": "dark_keep", "pos": Vector2(3300, 1800)},
			{"type": "dark_keep", "pos": Vector2(2000, 2400)},
			{"type": "statue", "pos": Vector2(4700, 4300)},
			{"type": "stone_row", "pos": Vector2(2600, 4300), "count": 4},
			{"type": "well", "pos": Vector2(4300, 4700)},
			{"type": "lamp", "pos": Vector2(4200, 5460)},
			{"type": "lamp", "pos": Vector2(5900, 5460)},
		],
		"warm_patches": [Vector2(5480, 3520)],   # the Spire's base... it is warm
		"vignettes": [
			{"kind": "boot_prints", "pos": Vector2(2650, 2900)},   # twelve, facing the wall
			{"kind": "empty_stall", "pos": Vector2(6500, 5400)},   # coin-box full, stall abandoned
			{"kind": "standing_farmer", "pos": Vector2(4200, 4800)},
		],
		"waystations": [{"id": "blestem_gate", "pos": Vector2(360, 4200)}],
		"border_gaps": [Rect2(0, 3960, 280, 300)],
		"travel_points": [
			{"id": "west_gate", "pos": Vector2(200.0, 4100.0), "radius": 38.0,
				"to_map": "eastern_ridges", "to_point": "east_gate", "prompt": "[E] The Eastern Ridges"},
			{"id": "cave_mouth", "pos": Vector2(5100.0, 1840.0), "radius": 38.0,
				"to_map": "lichenreach", "to_point": "south_entry", "prompt": "[E] Lichenreach — the Glowing Caves"},
			{"id": "vale_gate", "pos": Vector2(5100.0, 6360.0), "radius": 38.0,
				"to_map": "transcub_vale", "to_point": "north_entry", "prompt": "[E] The Transcub Vale"},
		],
		"creature_table": [
			{"type": "skeleton_rogue", "name": "Listener", "count": 10, "pack": 1, "hp": 32, "damage": 8, "speed": 74, "patrol": 90,
				"area": Rect2(2200, 2000, 3200, 2000)},
			{"type": "orc_rogue", "name": "Strigoi Enforcer", "count": 8, "pack": 2, "hp": 42, "damage": 11, "speed": 86, "patrol": 100,
				"area": Rect2(5600, 4600, 2400, 1600)},
		],
	},

	"lichenreach": {
		"built": true,
		"name": "Lichenreach",
		"continent": 1, "region": "east", "biome": "cave",
		"tiles_w": 128, "tiles_h": 128,
		"dusk_tint": Color(0.50, 0.55, 0.62),
		"player_spawn": Vector2(2048.0, 3900.0),
		"tree_density": 0.0,
		"roads": [[Vector2(2048, 3980), Vector2(2000, 2800), Vector2(2100, 1600), Vector2(2048, 600)]],
		"landmarks": [
			{"type": "lichen_glow", "pos": Vector2(1400, 2800), "count": 6},
			{"type": "lichen_glow", "pos": Vector2(2700, 2000), "count": 6},
			{"type": "lichen_glow", "pos": Vector2(1800, 1200), "count": 5},
			{"type": "lichen_glow", "pos": Vector2(3000, 3200), "count": 5},
			{"type": "rocks", "pos": Vector2(1000, 1800), "count": 6},
			{"type": "rocks", "pos": Vector2(3200, 1400), "count": 5},
			{"type": "bones", "pos": Vector2(2400, 2600)},
			{"type": "inscription_stone", "pos": Vector2(2048, 800), "live": true},
			{"type": "stump", "pos": Vector2(1500, 3400)},
		],
		"warm_patches": [Vector2(2068, 860)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(2600, 3600)},
			{"kind": "boot_prints", "pos": Vector2(2100, 1000)},
		],
		"waystations": [],
		"border_gaps": [Rect2(1900, 3900, 300, 196)],
		"travel_points": [
			{"id": "south_entry", "pos": Vector2(2048.0, 3960.0), "radius": 36.0,
				"to_map": "blestem", "to_point": "cave_mouth", "prompt": "[E] Blestem"},
		],
		"creature_table": [
			{"type": "skeleton_mage", "name": "The Walled", "count": 7, "pack": 1, "hp": 34, "damage": 9, "speed": 30, "patrol": 20,
				"area": Rect2(1200, 1200, 1800, 1600)},
			{"type": "skeleton", "name": "Cave Shell", "count": 7, "pack": 2, "hp": 38, "damage": 9, "speed": 56, "patrol": 70,
				"area": Rect2(2200, 2400, 1400, 1200)},
		],
	},

	"transcub_vale": {
		"built": true,
		"name": "The Transcub Vale",
		"continent": 1, "region": "east", "biome": "ridge",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.70, 0.72, 0.80),
		"player_spawn": Vector2(3580.0, 220.0),
		"tree_density": 1.0,
		"roads": [[Vector2(3580, 140), Vector2(3540, 1600), Vector2(3580, 2800), Vector2(3540, 4200)]],
		"landmarks": [
			{"type": "manor", "pos": Vector2(2800, 2000)},        # ivy-eaten temple
			{"type": "manor", "pos": Vector2(4400, 3000)},        # ivy-eaten temple
			{"type": "graves", "pos": Vector2(2500, 2400), "count": 8},
			{"type": "statue", "pos": Vector2(2950, 2250)},
			{"type": "statue", "pos": Vector2(4550, 3250)},
			{"type": "inscription_stone", "pos": Vector2(3600, 3600), "live": false},
			{"type": "dolmen", "pos": Vector2(1600, 1400)},
			{"type": "stone_row", "pos": Vector2(5400, 1800), "count": 5},
			{"type": "rocks", "pos": Vector2(6000, 3600), "count": 5},
			{"type": "bones", "pos": Vector2(3300, 2900)},
		],
		"warm_patches": [Vector2(2860, 2100)],   # "the stone beneath the altar is warm"
		"vignettes": [
			{"kind": "standing_farmer", "pos": Vector2(3800, 2400)},
			{"kind": "cold_camp", "pos": Vector2(5200, 4200)},
		],
		"waystations": [{"id": "vale_post", "pos": Vector2(3700, 340)}],
		"border_gaps": [Rect2(3440, 0, 300, 240)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(3580.0, 180.0), "radius": 36.0,
				"to_map": "blestem", "to_point": "vale_gate", "prompt": "[E] Blestem"},
		],
		"creature_table": [
			{"type": "skeleton", "name": "Temple Ghoul", "count": 9, "pack": 2, "hp": 40, "damage": 10, "speed": 58, "patrol": 80,
				"area": Rect2(2200, 1600, 2800, 1800)},
			{"type": "orc_shaman", "name": "Penitent Cultist", "count": 6, "pack": 2, "hp": 38, "damage": 9, "speed": 70, "patrol": 90,
				"area": Rect2(4200, 2600, 2200, 1600)},
		],
	},
	# ---------------- SOUTH — Sangeroasa (Varcolaci, Valrom) ---------------
	"bloodroad": {
		"built": true,
		"name": "The Bloodroad",
		"continent": 1, "region": "south", "biome": "volcanic",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.80, 0.62, 0.55),
		"player_spawn": Vector2(3580.0, 220.0),
		"tree_density": 0.8,
		"roads": [[Vector2(3580, 140), Vector2(3540, 1400), Vector2(3600, 2800), Vector2(3560, 4200), Vector2(3580, 4980)]],
		"landmarks": [
			{"type": "lava_vent", "pos": Vector2(2200, 1800)},
			{"type": "lava_vent", "pos": Vector2(4800, 3200)},
			{"type": "camp", "pos": Vector2(4200, 1600)},           # drover camp
			{"type": "bones", "pos": Vector2(3000, 2400)},
			{"type": "bones", "pos": Vector2(4100, 3800)},
			{"type": "signboard", "pos": Vector2(3700, 1000)},
			{"type": "signboard", "pos": Vector2(3450, 3400)},
			{"type": "rocks", "pos": Vector2(1600, 3000), "count": 6},
			{"type": "rocks", "pos": Vector2(5600, 2000), "count": 6},
			{"type": "graves", "pos": Vector2(2600, 4200), "count": 5},
			{"type": "inscription_stone", "pos": Vector2(4400, 2600), "live": false},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(2000, 1200)},
			{"kind": "boot_prints", "pos": Vector2(3650, 2900)},
		],
		"waystations": [{"id": "bloodroad_post", "pos": Vector2(3700, 340)}],
		"border_gaps": [Rect2(3440, 0, 300, 240), Rect2(3440, 4880, 300, 240)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(3580.0, 180.0), "radius": 36.0,
				"to_map": "copper_wells", "to_point": "south_gate", "prompt": "[E] The Copper Wells"},
			{"id": "south_gate", "pos": Vector2(3580.0, 4940.0), "radius": 36.0,
				"to_map": "basaltfang", "to_point": "north_entry", "prompt": "[E] Basaltfang Range"},
		],
		"creature_table": [
			{"type": "wolf", "name": "Varcolac Runner", "count": 9, "pack": 3, "hp": 38, "damage": 10, "speed": 96, "patrol": 140,
				"area": Rect2(1400, 1400, 2600, 1800)},
			{"type": "orc_rogue", "name": "Road Toll-Taker", "count": 6, "pack": 2, "hp": 40, "damage": 11, "speed": 84, "patrol": 100,
				"area": Rect2(4200, 2800, 2200, 1600)},
			{"type": "boar", "name": "Cinder Boar", "count": 6, "pack": 2, "hp": 42, "damage": 10, "speed": 80, "patrol": 90,
				"area": Rect2(1800, 3400, 2000, 1200)},
		],
	},

	"basaltfang": {
		"built": true,
		"name": "Basaltfang Range",
		"continent": 1, "region": "south", "biome": "volcanic",
		"tiles_w": 240, "tiles_h": 176,
		"dusk_tint": Color(0.76, 0.58, 0.52),
		"player_spawn": Vector2(3840.0, 220.0),
		"tree_density": 1.0,
		"roads": [[Vector2(3840, 140), Vector2(3800, 1600), Vector2(3860, 3200), Vector2(3800, 4800), Vector2(3840, 5492)]],
		"landmarks": [
			{"type": "lava_vent", "pos": Vector2(2400, 1600)},
			{"type": "lava_vent", "pos": Vector2(5400, 2400)},
			{"type": "lava_vent", "pos": Vector2(2000, 3800)},
			{"type": "lava_vent", "pos": Vector2(5800, 4400)},
			{"type": "ore_rocks", "pos": Vector2(2800, 2800), "count": 6},   # blackglass diggings
			{"type": "ore_rocks", "pos": Vector2(5000, 3600), "count": 5},
			{"type": "cairn", "pos": Vector2(4400, 1400)},
			{"type": "cabin", "pos": Vector2(5200, 1800)},           # prospector hut
			{"type": "camp", "pos": Vector2(2400, 4600)},
			{"type": "bones", "pos": Vector2(3400, 3400)},
			{"type": "dolmen", "pos": Vector2(6200, 3000)},
			{"type": "inscription_stone", "pos": Vector2(3200, 4800), "live": true},
		],
		"warm_patches": [Vector2(3220, 4860)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(5600, 5000)},
			{"kind": "standing_farmer", "pos": Vector2(4000, 2400)},
		],
		"waystations": [{"id": "basalt_post", "pos": Vector2(3960, 340)}],
		"border_gaps": [Rect2(3700, 0, 300, 240), Rect2(3700, 5392, 300, 240)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(3840.0, 180.0), "radius": 36.0,
				"to_map": "bloodroad", "to_point": "south_gate", "prompt": "[E] The Bloodroad"},
			{"id": "south_gate", "pos": Vector2(3840.0, 5452.0), "radius": 36.0,
				"to_map": "sangeroasa", "to_point": "north_gate", "prompt": "[E] Sangeroasa — the Forge That Eats"},
		],
		"creature_table": [
			{"type": "orc_warrior", "name": "Basalt Claim-Guard", "count": 8, "pack": 2, "hp": 46, "damage": 12, "speed": 78, "patrol": 90,
				"area": Rect2(2400, 2400, 3000, 1800)},
			{"type": "wolf", "name": "Varcolac Runner", "count": 8, "pack": 3, "hp": 38, "damage": 10, "speed": 96, "patrol": 140,
				"area": Rect2(1400, 3600, 2400, 1600)},
			{"type": "skeleton_warrior", "name": "War-Dead Shell", "count": 6, "pack": 2, "hp": 44, "damage": 11, "speed": 60, "patrol": 70,
				"area": Rect2(5000, 4000, 2000, 1400)},
		],
	},

	"sangeroasa": {
		"built": true,
		"name": "Sangeroasa",
		"continent": 1, "region": "south", "biome": "volcanic", "capital": true,
		"tiles_w": 320, "tiles_h": 256,
		"dusk_tint": Color(0.72, 0.50, 0.44),
		"ambient_lock": Color(0.80, 0.62, 0.55),   # forge-light haze, never true day
		"music": MUSIC_TOWN,
		"player_spawn": Vector2(5100.0, 240.0),
		"tree_density": 0.2,
		"roads": [
			[Vector2(5100, 160), Vector2(5140, 1400), Vector2(5100, 2400), Vector2(4780, 3000), Vector2(5100, 3620), Vector2(5140, 4000)],
			[Vector2(5140, 4000), Vector2(3800, 4040), Vector2(2600, 4000)],
			[Vector2(5140, 4000), Vector2(6400, 3960), Vector2(7600, 4000)],
			[Vector2(5140, 4000), Vector2(5100, 5400), Vector2(5140, 6600)],
			[Vector2(2600, 4000), Vector2(2560, 5200)],
			[Vector2(6400, 3960), Vector2(6440, 2800)],
		],
		"landmarks": [
			# — the Debt Pit at the heart (lore 04/08) —
			{"type": "pit", "pos": Vector2(5120, 3000)},
			{"type": "inscription_stone", "pos": Vector2(5120, 2600), "live": true},
			# — the forge district: hammers never stop —
			{"type": "forge", "pos": Vector2(6440, 2400)},
			{"type": "forge", "pos": Vector2(6800, 2700)},
			{"type": "forge", "pos": Vector2(6200, 3100)},
			{"type": "workshop", "pos": Vector2(7200, 3700)},
			{"type": "brazier", "pos": Vector2(6440, 2900)},
			{"type": "brazier", "pos": Vector2(6600, 3400)},
			# — the killing floors (lore: livestock + war industry) —
			{"type": "bones", "pos": Vector2(2600, 3400)},
			{"type": "bones", "pos": Vector2(2300, 3700)},
			{"type": "stall", "pos": Vector2(2800, 4400)},
			{"type": "stall", "pos": Vector2(2500, 4650)},
			{"type": "brazier", "pos": Vector2(2650, 4200)},
			# — residential terraces —
			{"type": "cottage", "pos": Vector2(4200, 4600)},
			{"type": "cottage", "pos": Vector2(4500, 5000)},
			{"type": "cottage", "pos": Vector2(5800, 4700)},
			{"type": "cottage", "pos": Vector2(6100, 5100)},
			{"type": "cottage", "pos": Vector2(3800, 5300)},
			{"type": "tavern", "pos": Vector2(5700, 5600)},          # the Hammer's Rest
			{"type": "manor", "pos": Vector2(3400, 2400)},           # Valrom's hall
			{"type": "statue", "pos": Vector2(3650, 2650)},
			{"type": "well", "pos": Vector2(4800, 4400)},
			{"type": "lava_vent", "pos": Vector2(8200, 2000)},
			{"type": "lava_vent", "pos": Vector2(1800, 6000)},
			{"type": "lava_vent", "pos": Vector2(8400, 5600)},
			{"type": "rocks", "pos": Vector2(8800, 4000), "count": 6},
			{"type": "graves", "pos": Vector2(3000, 6200), "count": 8},
		],
		"warm_patches": [Vector2(5120, 2660)],
		"vignettes": [
			{"kind": "boot_prints", "pos": Vector2(5000, 3250)},     # facing the Pit
			{"kind": "standing_farmer", "pos": Vector2(4400, 4200)},
			{"kind": "empty_stall", "pos": Vector2(2650, 4520)},
		],
		"waystations": [{"id": "sangeroasa_gate", "pos": Vector2(5260, 400)}],
		"border_gaps": [Rect2(4960, 0, 300, 240), Rect2(2420, 6560, 300, 240), Rect2(7460, 6560, 300, 240)],
		"travel_points": [
			{"id": "north_gate", "pos": Vector2(5100.0, 200.0), "radius": 38.0,
				"to_map": "basaltfang", "to_point": "south_gate", "prompt": "[E] Basaltfang Range"},
			{"id": "gift_gate", "pos": Vector2(2560.0, 6620.0), "radius": 38.0,
				"to_map": "the_gift", "to_point": "north_entry", "prompt": "[E] The Gift — the Red Fields"},
			{"id": "vents_gate", "pos": Vector2(7600.0, 6620.0), "radius": 38.0,
				"to_map": "ashvents", "to_point": "north_entry", "prompt": "[E] The Ashvents"},
		],
		"creature_table": [
			{"type": "orc_warrior", "name": "Forgehand", "count": 10, "pack": 2, "hp": 48, "damage": 12, "speed": 78, "patrol": 90,
				"area": Rect2(6000, 2000, 2600, 1800)},
			{"type": "wolf", "name": "Varcolac Pit-Guard", "count": 8, "pack": 2, "hp": 42, "damage": 11, "speed": 94, "patrol": 110,
				"area": Rect2(4200, 2400, 2000, 1400)},
			{"type": "skeleton_mage", "name": "Debt Clerk", "count": 6, "pack": 1, "hp": 34, "damage": 9, "speed": 24, "patrol": 16,
				"area": Rect2(4600, 2800, 1200, 800)},
		],
	},

	"the_gift": {
		"built": true,
		"name": "The Gift",
		"continent": 1, "region": "south", "biome": "volcanic",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.86, 0.66, 0.58),
		"player_spawn": Vector2(3580.0, 220.0),
		"tree_density": 0.4,
		"roads": [[Vector2(3580, 140), Vector2(3540, 1600), Vector2(3600, 3000), Vector2(3560, 4400)]],
		"landmarks": [
			# — the red fields: soil grown from the war dead (lore 03/08) —
			{"type": "gift_field", "pos": Vector2(2200, 1600), "w": 8, "h": 4},
			{"type": "gift_field", "pos": Vector2(4400, 2200), "w": 7, "h": 4},
			{"type": "gift_field", "pos": Vector2(2000, 3200), "w": 8, "h": 3},
			{"type": "gift_field", "pos": Vector2(4600, 3800), "w": 6, "h": 4},
			{"type": "cottage", "pos": Vector2(3000, 2400)},         # tenant farm
			{"type": "cottage", "pos": Vector2(4200, 1400)},
			{"type": "well", "pos": Vector2(3200, 2700)},
			{"type": "stall", "pos": Vector2(3800, 3300)},           # grain stall
			{"type": "graves", "pos": Vector2(5400, 1800), "count": 6},
			{"type": "statue", "pos": Vector2(5600, 3200)},          # harvest saint
			{"type": "inscription_stone", "pos": Vector2(2600, 4200), "live": false},
			{"type": "bones", "pos": Vector2(5200, 4400)},
		],
		"warm_patches": [],
		"vignettes": [
			{"kind": "childs_shoe", "pos": Vector2(2450, 1720)},
			{"kind": "childs_shoe", "pos": Vector2(4750, 3920)},
			{"kind": "full_granary", "pos": Vector2(3100, 2500)},
			{"kind": "standing_farmer", "pos": Vector2(2350, 1800)},
		],
		"waystations": [{"id": "gift_post", "pos": Vector2(3700, 340)}],
		"border_gaps": [Rect2(3440, 0, 300, 240)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(3580.0, 180.0), "radius": 36.0,
				"to_map": "sangeroasa", "to_point": "gift_gate", "prompt": "[E] Sangeroasa"},
		],
		"creature_table": [
			{"type": "boar", "name": "Red-Field Boar", "count": 9, "pack": 3, "hp": 40, "damage": 10, "speed": 82, "patrol": 100,
				"area": Rect2(1600, 2000, 2600, 1800)},
			{"type": "skeleton", "name": "Harvest Shell", "count": 7, "pack": 2, "hp": 40, "damage": 10, "speed": 56, "patrol": 70,
				"area": Rect2(4200, 2800, 2200, 1600)},
		],
	},

	"ashvents": {
		"built": true,
		"name": "The Ashvents",
		"continent": 1, "region": "south", "biome": "volcanic",
		"tiles_w": 224, "tiles_h": 160,
		"dusk_tint": Color(0.72, 0.56, 0.50),
		"player_spawn": Vector2(3580.0, 220.0),
		"tree_density": 0.9,
		"roads": [[Vector2(3580, 140), Vector2(3540, 1400), Vector2(3600, 2600), Vector2(3560, 3800)]],
		"landmarks": [
			{"type": "lava_vent", "pos": Vector2(2200, 1400)},
			{"type": "lava_vent", "pos": Vector2(4800, 1800)},
			{"type": "lava_vent", "pos": Vector2(1800, 2800)},
			{"type": "lava_vent", "pos": Vector2(5400, 3200)},
			{"type": "lava_vent", "pos": Vector2(3000, 3600)},
			{"type": "lava_vent", "pos": Vector2(4400, 4200)},
			{"type": "lava_vent", "pos": Vector2(2600, 2100)},
			{"type": "cairn", "pos": Vector2(3800, 2000)},
			{"type": "cairn", "pos": Vector2(3300, 2900)},
			{"type": "bones", "pos": Vector2(4600, 2600)},
			{"type": "bones", "pos": Vector2(2400, 4000)},
			{"type": "camp", "pos": Vector2(5600, 4400)},            # vent-tender camp
			{"type": "inscription_stone", "pos": Vector2(4000, 3400), "live": true},
			{"type": "rocks", "pos": Vector2(1400, 1800), "count": 6},
			{"type": "rocks", "pos": Vector2(6000, 2400), "count": 6},
		],
		"warm_patches": [Vector2(4020, 3460)],
		"vignettes": [
			{"kind": "cold_camp", "pos": Vector2(1600, 3600)},
			{"kind": "chalk_handprints", "pos": Vector2(3900, 3350)},
		],
		"waystations": [{"id": "ashvent_post", "pos": Vector2(3700, 340)}],
		"border_gaps": [Rect2(3440, 0, 300, 240)],
		"travel_points": [
			{"id": "north_entry", "pos": Vector2(3580.0, 180.0), "radius": 36.0,
				"to_map": "sangeroasa", "to_point": "vents_gate", "prompt": "[E] Sangeroasa"},
		],
		"creature_table": [
			{"type": "orc_shaman", "name": "Vent-Tender", "count": 7, "pack": 2, "hp": 40, "damage": 10, "speed": 70, "patrol": 90,
				"area": Rect2(2000, 1600, 2600, 1800)},
			{"type": "wolf", "name": "Ash Prowler", "count": 8, "pack": 3, "hp": 38, "damage": 10, "speed": 94, "patrol": 130,
				"area": Rect2(4200, 2600, 2200, 1600)},
			{"type": "skeleton_warrior", "name": "War-Dead Shell", "count": 5, "pack": 1, "hp": 44, "damage": 11, "speed": 60, "patrol": 60,
				"area": Rect2(1400, 3400, 1800, 1200)},
		],
	},
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
