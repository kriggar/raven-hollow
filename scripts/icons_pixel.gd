class_name IconsPixel
## Shikashi pixel-icon registry for Raven Hollow: Emberfall (Phase B.2).
## Serves 32x32 AtlasTextures from the Shikashi's Fantasy Icon Pack v2 sheet
## (res://assets/art/icons_pixel/shikashi_v2.png, 512x867, 32 px grid,
## 16 columns). The sheet is NOT densely packed: every manifest category
## starts on a NEW row (alpha-occupancy verified). v2 rows 0-18 duplicate v1
## (4 touched-up cells), so the registry uses v2 EXCLUSIVELY.
##
## Row -> category: 0 status, 1 body, 2 buffs, 3 special moves, 4 non-combat,
## 5-6 weapons, 7-8 armour, 9 potions, 10-13 general, 14-15 food, 16 fishing,
## 17 resources, 18 orbs, 19-21 v2-only icons.
##
## Every cell below was picked by EYE (4x labelled strips) to match the WoW
## class-color identity: warrior steel/red physical, rogue grey smoke and
## daggers, mage violet/flame/ice, paladin gold, necromancer green/black,
## hunter teal/feather/arrows. Item icons are the literal gear art named in
## items.gd. get_tex accepts both "cleave" and "pixel:cleave".

const SHEET_PATH := "res://assets/art/icons_pixel/shikashi_v2.png"
const CELL: int = 32

## icon_id -> Vector2i(col, row) on the 16-column grid.
const REGISTRY: Dictionary = {
	# --- Abilities (icon_id == ability id) ------------------------------
	"cleave": Vector2i(10, 5),          # war axe — steel/red physical
	"whirlwind": Vector2i(9, 5),        # crossed dual swords
	"war_cry": Vector2i(8, 11),         # hunting/war horn
	"quick_slash": Vector2i(6, 5),      # slim grey dagger
	"shadowstep": Vector2i(8, 4),       # steal — hooded thief mid-dash
	"fan_of_knives": Vector2i(8, 5),    # sai — fanned prongs
	"spark": Vector2i(8, 0),            # forked lightning bolts
	"fireball": Vector2i(9, 3),         # ring of fire
	"frost_nova": Vector2i(11, 21),     # snowflake
	"hammer_blow": Vector2i(4, 4),      # smith's hammer over the anvil
	"consecration": Vector2i(15, 3),    # sunrays — gold light from above
	"divine_shield": Vector2i(1, 6),    # gold-orange heater shield
	"soul_bolt": Vector2i(2, 18),       # green orb — necromancer green
	"raise_dead": Vector2i(0, 0),       # skull and bones
	"grave_grasp": Vector2i(2, 12),     # gnarled root tips
	"loosed_arrow": Vector2i(3, 6),     # bow & nocked arrow
	"raven_dash": Vector2i(10, 17),     # feathers
	"arrow_storm": Vector2i(4, 3),      # raining arrows
	# --- Items (icon_id == item id, art named in items.gd) --------------
	"emberfall": Vector2i(2, 5),        # enchanted glowing greatsword
	"rooks_talon": Vector2i(9, 17),     # white monster talon
	"gravekeepers_band": Vector2i(5, 8),# gem ring
	"bulwark": Vector2i(2, 6),          # quartered heater shield
	"bloody_dagger": Vector2i(0, 3),    # blood-dripping blade
	"leather_hood": Vector2i(2, 7),     # dark leather helm/hood
	"patched_jerkin": Vector2i(6, 7),   # ribbed leather cuirass
	"iron_cuirass": Vector2i(4, 7),     # iron breastplate
	"padded_breeches": Vector2i(10, 7), # trousers
	"gravediggers_boots": Vector2i(2, 8),# worn leather boots
	"rusted_shortsword": Vector2i(4, 5),# gladius
	"pinewood_buckler": Vector2i(0, 6), # round wooden buckler
	"tarnished_band": Vector2i(4, 8),   # plain gold band
	"ravens_eye": Vector2i(5, 18),      # glossy black orb
	# --- Generic UI ------------------------------------------------------
	"backpack": Vector2i(0, 10),        # knapsack (bag button / bag UI)
	"pouch": Vector2i(9, 8),            # leather belt pouch
}

static var _sheet: Texture2D = null
static var _cache: Dictionary = {}


## AtlasTexture for a registry id. Accepts "cleave" or "pixel:cleave".
## Unknown ids warn once and return null (callers show their placeholder).
static func get_tex(icon_id: String) -> AtlasTexture:
	var id: String = icon_id.trim_prefix("pixel:")
	if _cache.has(id):
		return _cache[id]
	if not REGISTRY.has(id):
		push_warning("IconsPixel: unknown icon id '%s'" % id)
		_cache[id] = null
		return null
	if _sheet == null:
		_sheet = load(SHEET_PATH) as Texture2D
	if _sheet == null:
		push_warning("IconsPixel: missing sheet '%s'" % SHEET_PATH)
		return null
	var cell: Vector2i = REGISTRY[id]
	var tex := AtlasTexture.new()
	tex.atlas = _sheet
	tex.region = Rect2(float(cell.x * CELL), float(cell.y * CELL), float(CELL), float(CELL))
	_cache[id] = tex
	return tex


static func has_icon(icon_id: String) -> bool:
	return REGISTRY.has(icon_id.trim_prefix("pixel:"))
