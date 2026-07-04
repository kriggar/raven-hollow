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
const _SPELL_DIR := "res://assets/art/icons_spell/"  # painterly ability icons (Phase D)

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
	# --- Spell-kit abilities (Phase D: WoW-style 7-8 ability kits) -------
	# Warrior (blood-steel)
	"shield_charge": Vector2i(13, 3),   # boots — rush/charge
	"sunder": Vector2i(11, 3),          # red spiked impact — armor break
	"iron_bulwark": Vector2i(1, 11),    # striped ward-shield (not gold)
	"earthshaker": Vector2i(4, 10),     # heavy maul — ground slam
	# Rogue (shadow/venom/crimson)
	"backstab": Vector2i(0, 3),         # bloody dual blades
	"noxious_vial": Vector2i(6, 19),    # green vial — thrown venom
	"shroud": Vector2i(2, 0),           # closed eye — vanish
	"death_blossom": Vector2i(2, 3),    # crossed sword+dagger flurry
	# Mage (violet-arcane / amber-fire / frost-blue)
	"ice_lance": Vector2i(13, 12),      # blue ice shards
	"flame_strike": Vector2i(2, 4),     # flames — fire AoE
	"arcane_blink": Vector2i(14, 3),    # violet arcane orb (Blink icon)
	"mana_shield": Vector2i(4, 18),     # purple orb — arcane ward
	"meteor": Vector2i(10, 3),          # comet — Cinderfall ult
	# Paladin (gold/white-holy)
	"holy_smite": Vector2i(8, 0),       # gold bolt — smite
	"judgment": Vector2i(12, 3),        # gold divine crescents
	"lay_on_hands": Vector2i(5, 3),     # figure + green cross — heal
	"sacred_bulwark": Vector2i(7, 21),  # sunrise dome — holy ward
	"dawnbreak": Vector2i(8, 21),       # radiant sunburst — ult
	# Necromancer (necrotic-green / grave-purple / bone)
	"drain_life": Vector2i(0, 1),       # red heart — life drain
	"withering_curse": Vector2i(1, 0),  # green sickly face — curse
	"bone_nova": Vector2i(9, 17),       # bone/tusk — shard burst
	"bone_armor": Vector2i(5, 7),       # scale vest — bone plating
	"soul_harvest": Vector2i(9, 0),     # flaming skull — souls reaped
	# Hunter (rookwarden — teal/forest/bone)
	"piercing_shot": Vector2i(9, 11),   # single dart/arrow
	"snare_trap": Vector2i(13, 10),     # spiked band — bear trap
	"hunters_mark": Vector2i(5, 0),     # sparkles — marked target
	"rook_companion": Vector2i(10, 19), # dark beast head — companion
	"storm_of_feathers": Vector2i(12, 3),# gold crescents — feather storm
	# Druid (leaf/moss / bear-brown / storm-blue)
	"maul": Vector2i(14, 5),            # fist/claw — bear maul
	"gale": Vector2i(12, 3),            # wind crescents
	"thornroot": Vector2i(2, 12),       # gnarled roots (shares grave_grasp)
	"stormbolt": Vector2i(8, 0),        # lightning bolt
	"rejuvenation": Vector2i(13, 11),   # green herb sprig — nature heal
	"spirit_beast": Vector2i(10, 19),   # dark beast head — summon
	"bear_form": Vector2i(4, 1),        # flexed arm — rage/form buff
	"tempest": Vector2i(10, 0),         # rain drops — storm ult
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
	# --- Phase C: crafting materials / consumables / recipe scrolls -------
	"wolf_pelt": Vector2i(8, 17),       # X-stretched animal hide
	"boar_hide": Vector2i(8, 17),       # animal hide (shares the pelt art)
	"bone": Vector2i(9, 17),            # white bone / tusk
	"ember_dust": Vector2i(4, 20),      # smouldering red-ash powder pile
	"iron_scrap": Vector2i(3, 17),      # metal ingot / scrap
	"healing_draught": Vector2i(4, 9),  # red potion with a green cross
	"hunters_stew": Vector2i(0, 15),    # roast drumstick (hearty meal)
	"recipe_hunters_stew": Vector2i(1, 21),     # green-ribbon recipe scroll
	"recipe_wolf_fang_dagger": Vector2i(2, 21), # red-ribbon recipe scroll
	# --- Phase C: quest items (quest_defs.gd rewards / carried items) -----
	"coppervein_ring": Vector2i(5, 8),  # gem ring (quest 1 reward)
	"travelers_boots": Vector2i(3, 8),  # grey boots (quest 2 reward)
	"gorans_targe": Vector2i(1, 6),     # heater shield (quest 3 reward)
	"weeping_dagger": Vector2i(8, 5),   # dark wrapped dagger (quest 3 carried)
	"charcoal_rubbing": Vector2i(7, 17),# inscribed parchment (quest 1)
	# --- Generic UI ------------------------------------------------------
	"backpack": Vector2i(0, 10),        # knapsack (bag button / bag UI)
	"pouch": Vector2i(9, 8),            # leather belt pouch
}

static var _sheet: Texture2D = null
static var _cache: Dictionary = {}


## AtlasTexture for a registry id. Accepts "cleave" or "pixel:cleave".
## Unknown ids warn once and return null (callers show their placeholder).
static func get_tex(icon_id: String) -> Texture2D:
	var id: String = icon_id.trim_prefix("pixel:")
	if _cache.has(id):
		return _cache[id]
	# Premium painterly ability icon wins over the Shikashi cell when present.
	var spell_path: String = _SPELL_DIR + id + ".png"
	if ResourceLoader.exists(spell_path):
		_cache[id] = load(spell_path) as Texture2D
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
