class_name Items
## Static item database for Raven Hollow: Emberfall — Phase B.
## Pure data + tiny helpers, no scene code (mirrors class_defs.gd).
##
## Item dict shape (exact — every item carries every key):
##   {id, name, slot, rarity, icon, stats, flavor, stackable, effect}
##   slot:   "head"|"chest"|"legs"|"boots"|"main_hand"|"off_hand"|"ring"|
##           "trinket"|"none"  (rings use the shared type "ring"; the
##           Inventory maps them onto ring1/ring2)
##   rarity: "common"|"uncommon"|"rare"|"epic"|"legendary"
##   icon:   "pixel:<icon_id>" — resolved through IconsPixel (Shikashi
##           32x32 pixel sheets); every cell viewed by eye at 8x.
##   stats:  {damage, armor, hp, mana, speed_pct, crit_pct} — floats, all
##           six keys always present (0.0 when unused). gravekeepers_band
##           additionally carries "mana_regen" per the user-approved spec.
##   effect: "" or a legendary effect id handled in player.gd:
##           emberfall | rooks_talon | gravekeepers_band | bulwark |
##           bloody_dagger
##
## Icon choices (Shikashi pack — literal gear art this time, PIL-viewed):
## enchanted glowing greatsword, white monster talon, gem ring, quartered
## heater shield, blood-dripping blade for the legendaries; dark hood,
## leather cuirass, iron breastplate, trousers, worn boots, gladius,
## wooden buckler, plain band and a glossy black orb for the rest.
## Each item's icon id equals its item id (see IconsPixel.REGISTRY).

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.35, 0.75, 0.35),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.62, 0.35, 0.85),
	"legendary": Color(1.0, 0.55, 0.1),
}

const _DB := {
	# ------------------------------------------------------------------
	# LEGENDARIES (spec-exact stats, flavors and effect hooks)
	# ------------------------------------------------------------------
	"emberfall": {
		"id": "emberfall",
		"name": "Emberfall",
		"slot": "main_hand",
		"rarity": "legendary",
		"icon": "pixel:emberfall",
		"stats": {"damage": 12.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 5.0},
		"flavor": "The blade that lit the hollow's last lantern.",
		"stackable": false,
		"effect": "emberfall",
	},
	"rooks_talon": {
		"id": "rooks_talon",
		"name": "Rook's Talon",
		"slot": "main_hand",
		"rarity": "legendary",
		"icon": "pixel:rooks_talon",
		"stats": {"damage": 9.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 10.0, "crit_pct": 0.0},
		"flavor": "A feather fell; a kingdom followed.",
		"stackable": false,
		"effect": "rooks_talon",
	},
	"gravekeepers_band": {
		"id": "gravekeepers_band",
		"name": "Gravekeeper's Band",
		"slot": "ring",
		"rarity": "legendary",
		"icon": "pixel:gravekeepers_band",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 20.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 2.0},
		"flavor": "Vasile never buries what he cannot keep.",
		"stackable": false,
		"effect": "gravekeepers_band",
	},
	"bulwark": {
		"id": "bulwark",
		"name": "Bulwark of the Emberfall Road",
		"slot": "off_hand",
		"rarity": "legendary",
		"icon": "pixel:bulwark",
		"stats": {"damage": 0.0, "armor": 8.0, "hp": 25.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "It remembers every blow it was ever dealt.",
		"stackable": false,
		"effect": "bulwark",
	},
	"bloody_dagger": {
		"id": "bloody_dagger",
		"name": "The Bloody Dagger",
		"slot": "main_hand",
		"rarity": "legendary",
		"icon": "pixel:bloody_dagger",
		"stats": {"damage": 7.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 8.0},
		"flavor": "It is always freshly bloody. No one remembers cutting anything.",
		"stackable": false,
		"effect": "bloody_dagger",
	},
	# ------------------------------------------------------------------
	# LOWER RARITIES — one per slot type so drag/drop, rarity borders and
	# every paper-doll slot are QA-able from the starting bag.
	# ------------------------------------------------------------------
	"leather_hood": {
		"id": "leather_hood",
		"name": "Leather Hood",
		"slot": "head",
		"rarity": "common",
		"icon": "pixel:leather_hood",
		"stats": {"damage": 0.0, "armor": 1.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Smells of rain and old rope.",
		"stackable": false,
		"effect": "",
	},
	"patched_jerkin": {
		"id": "patched_jerkin",
		"name": "Patched Jerkin",
		"slot": "chest",
		"rarity": "common",
		"icon": "pixel:patched_jerkin",
		"stats": {"damage": 0.0, "armor": 2.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "More patch than jerkin, if we are honest.",
		"stackable": false,
		"effect": "",
	},
	"iron_cuirass": {
		"id": "iron_cuirass",
		"name": "Iron Cuirass",
		"slot": "chest",
		"rarity": "rare",
		"icon": "pixel:iron_cuirass",
		"stats": {"damage": 0.0, "armor": 4.0, "hp": 15.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Forged by the west gate, back when the smithy still rang.",
		"stackable": false,
		"effect": "",
	},
	"padded_breeches": {
		"id": "padded_breeches",
		"name": "Padded Breeches",
		"slot": "legs",
		"rarity": "common",
		"icon": "pixel:padded_breeches",
		"stats": {"damage": 0.0, "armor": 1.0, "hp": 5.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Quilted by someone's grandmother. Not yours.",
		"stackable": false,
		"effect": "",
	},
	"gravediggers_boots": {
		"id": "gravediggers_boots",
		"name": "Gravedigger's Boots",
		"slot": "boots",
		"rarity": "uncommon",
		"icon": "pixel:gravediggers_boots",
		"stats": {"damage": 0.0, "armor": 1.0, "hp": 0.0, "mana": 0.0, "speed_pct": 5.0, "crit_pct": 0.0},
		"flavor": "The mud of a hundred mornings never quite comes off.",
		"stackable": false,
		"effect": "",
	},
	"rusted_shortsword": {
		"id": "rusted_shortsword",
		"name": "Rusted Shortsword",
		"slot": "main_hand",
		"rarity": "common",
		"icon": "pixel:rusted_shortsword",
		"stats": {"damage": 3.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "The rust stops at the edge. Someone kept that much sharp.",
		"stackable": false,
		"effect": "",
	},
	"pinewood_buckler": {
		"id": "pinewood_buckler",
		"name": "Pinewood Buckler",
		"slot": "off_hand",
		"rarity": "uncommon",
		"icon": "pixel:pinewood_buckler",
		"stats": {"damage": 0.0, "armor": 2.0, "hp": 10.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Pine holds exactly one good blow. Choose which.",
		"stackable": false,
		"effect": "",
	},
	"tarnished_band": {
		"id": "tarnished_band",
		"name": "Tarnished Copper Band",
		"slot": "ring",
		"rarity": "common",
		"icon": "pixel:tarnished_band",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 5.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Green where it kisses the skin.",
		"stackable": false,
		"effect": "",
	},
	"ravens_eye": {
		"id": "ravens_eye",
		"name": "Raven's Eye",
		"slot": "trinket",
		"rarity": "epic",
		"icon": "pixel:ravens_eye",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 5.0, "crit_pct": 5.0},
		"flavor": "The hollow watches back.",
		"stackable": false,
		"effect": "",
	},
}

## Order the seed items land in the bag: legendaries first (the QA stars),
## then the slot-coverage spread.
const _STARTING_BAG_IDS: Array[String] = [
	"emberfall",
	"rooks_talon",
	"gravekeepers_band",
	"bulwark",
	"bloody_dagger",
	"leather_hood",
	"patched_jerkin",
	"iron_cuirass",
	"padded_breeches",
	"gravediggers_boots",
	"rusted_shortsword",
	"pinewood_buckler",
	"tarnished_band",
	"ravens_eye",
]


## Deep copy of the item with the given id, or {} (with a warning) if unknown.
static func get_item(id: String) -> Dictionary:
	if not _DB.has(id):
		push_warning("Items.get_item: unknown item id '%s'" % id)
		return {}
	var src: Dictionary = _DB[id]
	return src.duplicate(true)


## The seed items placed in the player's bag at game start
## (5 legendaries + a spread covering every equipment slot type).
static func starting_bag() -> Array[Dictionary]:
	var bag: Array[Dictionary] = []
	for id in _STARTING_BAG_IDS:
		var item := get_item(id)
		if not item.is_empty():
			bag.append(item)
	return bag


## UI color for a rarity string (falls back to common grey).
static func rarity_color(rarity: String) -> Color:
	if RARITY_COLORS.has(rarity):
		return RARITY_COLORS[rarity]
	return RARITY_COLORS["common"]
