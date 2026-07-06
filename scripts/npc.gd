class_name NPC
extends CharacterBody2D
## Wandering / stationary villager. Built entirely in code via NPC.create(def).
## def keys: id, display_name, sheet ("res://..." or "MAID"), variant:int,
## pos:Vector2, wander_radius:float (0 = stationary), dialogue:Array[String], facing:String,
## palette:Dictionary (OPTIONAL — see below; absent/empty = untouched original look).
## Group "npcs". Collision: circle r=6 at feet, layer 3, mask 1 (walls only).
## Phase B.1: a gold name tag (Alagard 8, dark outline) floats above the head
## while the player is within NAME_RANGE px.
##
## UNIQUE-VILLAGER PALETTES (Phase B.3): def["palette"] recolors a szadi
## villager at runtime through a per-instance ShaderMaterial
## (palette_swap.gdshader) — sprite files are never modified. Keys (each
## optional): "outfit_a": Color, "outfit_b": Color, "hair": Color
## (draw from OUTFIT_COLORS / HAIR_COLORS below), "skin": int (index into
## SKIN_TONES; 0 = the sheets' native skin, left untouched). Every source
## ramp STEP of the variant (RAMPS, PIL-verified per sheet+variant from the
## szadi frames) maps to the target colour scaled by the step's relative
## value, so shading survives the swap. Named cast (npc_data.gd) passes no
## palette and keeps its signature look. Player and enemies never use NPC,
## so they are unaffected.

const WALK_SPEED: float = 40.0
const ARRIVE_DIST: float = 3.0
const IDLE_MIN: float = 2.0
const IDLE_MAX: float = 5.0
const RESUME_DELAY: float = 1.0
## Szadi 32x48 frames: lowest opaque row (shadow bottom) is y=40 in every frame
## (pixel-verified), 16 px below the centered frame center (y=24); shift up 15
## so the shadow ellipse straddles the node pos. Matches Player.FEET_OFFSET.
const SZADI_OFFSET := Vector2(0.0, -15.0)
## Maid 64x64 frames: lowest opaque pixel row is y=47 (verified with PIL), so
## feet line ~y=48 -> 16 px below frame center -> shift up 16.
const MAID_OFFSET := Vector2(0.0, -16.0)
const NAME_RANGE: float = 70.0
const NAME_GOLD := Color(0.85, 0.68, 0.35)
const NAME_OUTLINE := Color(0.1, 0.06, 0.04, 0.95)
## Escort-lite (SPEC §5 quest 5) + night behavior (SPEC §6) tunables.
const FOLLOW_LEASH: float = 40.0        # she follows only while within this
const FOLLOW_STOP_DIST: float = 18.0    # stop this close so she doesn't shove
const NIGHT_WANDER_FACTOR: float = 0.25 # tighter wander radius after dusk

const PALETTE_SHADER := preload("res://scripts/palette_swap.gdshader")

## Curated MUTED colorway pools (GK palette law). Values are the target for
## a ramp's LIGHTEST step; darker steps are derived by value-ratio scaling.
## town_builder draws from these when assigning unique villager combos.
const OUTFIT_COLORS := {
	"olive": Color(136.0 / 255.0, 138.0 / 255.0, 88.0 / 255.0),
	"oxblood": Color(156.0 / 255.0, 74.0 / 255.0, 64.0 / 255.0),
	"umber": Color(160.0 / 255.0, 118.0 / 255.0, 74.0 / 255.0),
	"slate": Color(120.0 / 255.0, 134.0 / 255.0, 148.0 / 255.0),
	"moss": Color(108.0 / 255.0, 132.0 / 255.0, 88.0 / 255.0),
	"charcoal": Color(92.0 / 255.0, 92.0 / 255.0, 96.0 / 255.0),
	"dun": Color(182.0 / 255.0, 160.0 / 255.0, 120.0 / 255.0),
	"faded_teal": Color(104.0 / 255.0, 150.0 / 255.0, 144.0 / 255.0),
	"wine": Color(146.0 / 255.0, 80.0 / 255.0, 104.0 / 255.0),
	"ash": Color(168.0 / 255.0, 163.0 / 255.0, 150.0 / 255.0),
}
const HAIR_COLORS := {
	"black": Color(70.0 / 255.0, 66.0 / 255.0, 60.0 / 255.0),
	"dark_brown": Color(110.0 / 255.0, 80.0 / 255.0, 56.0 / 255.0),
	"chestnut": Color(166.0 / 255.0, 116.0 / 255.0, 72.0 / 255.0),
	"ash_grey": Color(176.0 / 255.0, 174.0 / 255.0, 168.0 / 255.0),
	"white": Color(232.0 / 255.0, 226.0 / 255.0, 215.0 / 255.0),
	"dark_auburn": Color(158.0 / 255.0, 84.0 / 255.0, 58.0 / 255.0),
}
## Index 0 = the szadi sheets' native skin (no remap). 1-3 progressively deeper.
const SKIN_TONES := [
	Color(249.0 / 255.0, 193.0 / 255.0, 157.0 / 255.0),
	Color(228.0 / 255.0, 172.0 / 255.0, 128.0 / 255.0),
	Color(204.0 / 255.0, 146.0 / 255.0, 102.0 / 255.0),
	Color(158.0 / 255.0, 108.0 / 255.0, 74.0 / 255.0),
]
## Skin ramps anchor to the pack-wide lightest skin texel (249,193,157) so a
## variant whose visible skin is only hands still darkens consistently.
const SKIN_REF_V := 249.0 / 255.0

## PIL-verified exact 8-bit ramps per szadi "sheet:variant" (light -> dark).
## outfit_a = upper garment cluster, outfit_b = lower garment cluster,
## hair includes beards; skin includes face, arm and beard/neck shadow tones.
## Deliberately EXCLUDED so they keep their hand-authored colours: the 20,25,29
## outline, eye whites, baked soft shadows, and props (male3 v0/v1 hats,
## female1 v2 / female2 v2 flower crowns and leaves, hairpins, glasses).
const RAMPS := {
	"npc_male1:0": {
		"outfit_a": [0x3E9B57, 0x2C7256, 0x5C2D1D, 0x404A4A, 0x1F4234, 0x41261C, 0x282B2B],
		"outfit_b": [0xA3DDDD, 0x6AB4B4, 0x3C6767, 0x593A31, 0x2B4B4B, 0x2B3E3E, 0x3D2423, 0x311E1D, 0x192828],
		"hair": [0x374040, 0x252828, 0x171919],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98553E],
	},
	"npc_male1:1": {
		"outfit_a": [0x7AD785, 0x3E939B, 0x2C5772, 0x404A4A, 0x1F3942, 0x41261C, 0x282B2B, 0x2B2623],
		"outfit_b": [0xA3DDDD, 0x6AB4B4, 0x3C6767, 0x593A31, 0x2B4B4B, 0x2B3E3E, 0x3D2423, 0x311E1D, 0x192828],
		"hair": [0x594C33, 0x312A1C, 0x201E19],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781],
	},
	"npc_male1:2": {
		"outfit_a": [0xBA8D70, 0xA67147, 0x804C31, 0x582E21, 0x58362D, 0x545454, 0x2C3030, 0x1C2222],
		"outfit_b": [0x593A31, 0x3D2423, 0x382B2A, 0x311E1D, 0x2D201F],
		"hair": [0x724D44, 0x42302B, 0x28201F],
		"skin": [0xF9C19D, 0xF6D5BE, 0xDFA47D, 0xC58060],
	},
	"npc_male1:3": {
		"outfit_a": [0xBA8D70, 0xB5B5B5, 0x5E686E, 0x5C4B1F, 0x58362D, 0x42494F, 0x3C3D3E, 0x262F35, 0x272829, 0x1C2222],
		"outfit_b": [0x35480F, 0x252F11, 0x232C11, 0x1C240C, 0x1A220C],
		"hair": [0x46413F, 0x2A2424, 0x1C1716],
		"skin": [0xF9C19D, 0xF6D5BE, 0xDFA47D, 0xC58060, 0xB4923A],
	},
	"npc_male2:0": {
		"outfit_a": [0x86503E, 0x5C2D1D, 0x3D2423],
		"outfit_b": [0x5BA85B, 0x5B805B, 0x243B24, 0x192A19, 0x142114],
		"hair": [0x404A4A, 0x282B2B, 0x171919],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x98553E, 0x743815],
	},
	"npc_male2:1": {
		"outfit_a": [0xBBF5F5, 0x7AB166, 0x4D954D, 0x447234, 0x2E4720, 0x171919],
		"outfit_b": [0x7890B5, 0x5B6980, 0x403C55, 0x302C42, 0x33323A, 0x26242D],
		"hair": [0x88655D, 0x654139, 0x3E1F18],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_male2:2": {
		"outfit_a": [0xAF7F98, 0x3E939B, 0x755867, 0x483846, 0x2B2623],
		"outfit_b": [0x7890B5, 0x5B6980, 0x2C5772, 0x403C55, 0x1F3942, 0x302C42, 0x33323A, 0x26242D],
		"hair": [0xA06D46, 0x7A502F, 0x472F1D],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_male2:3": {
		"outfit_a": [0x7EBFC0, 0x3B8A8B, 0x897A65, 0x5D3A26, 0x454545, 0x332D29, 0x2B2623],
		"outfit_b": [0x925F8B, 0x6A4B5D, 0x553A4A, 0x3D2734, 0x372830, 0x2B1D25],
		"hair": [0x524D4B, 0x362F2F, 0x251D1C],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E],
	},
	"npc_male3:0": {
		"outfit_a": [0xB96228, 0xA4885F, 0x7D6453, 0x765F3C, 0x525358, 0x52423D, 0x493226, 0x38383C, 0x362B24, 0x23242C],
		"outfit_b": [0x64593D, 0x564A2C, 0x35251D, 0x30201C, 0x281916],
		"hair": [0x352622, 0x2B2C35],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x743815],
	},
	"npc_male3:1": {
		"outfit_a": [0xB96228, 0x9D9D9D, 0x666A82, 0x6E6E6E, 0x5D5151, 0x44485A, 0x474747, 0x423535, 0x302525, 0x23242C],
		"outfit_b": [0x64593D, 0x564A2C, 0x30201C, 0x281916, 0x282828],
		"hair": [0x343642, 0x352622],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x743815],
	},
	"npc_male3:2": {
		"outfit_a": [0xFBFFD3, 0xBEC293, 0xB96228, 0xB56142, 0xB3B3B3, 0x7D4632, 0x6A6A6A, 0x585B37, 0x43352D, 0x424242],
		"outfit_b": [0xAD614F, 0x7F4233, 0x38201A, 0x30201C, 0x281916],
		"hair": [0x98552E, 0x7A7E52, 0x6A6144, 0x373520],
		"skin": [0xFFE3D1, 0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x743815],
	},
	"npc_male3:3": {
		"outfit_a": [0xD3E4FF, 0xC3CCDC, 0xB2B6C5, 0xB96228, 0x7AB166, 0xA1867C, 0x4D954D, 0x644F48, 0x2E4720, 0x43352D],
		"outfit_b": [0xAD614F, 0x7F4233, 0x38201A, 0x30201C, 0x281916],
		"hair": [0x8B909C, 0x98552E, 0x60646E, 0x373A4A],
		"skin": [0xFFE3D1, 0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x743815],
	},
	"npc_male4:0": {
		"outfit_a": [0xBBF5F5, 0xD6DCE5, 0xB5B7BB, 0x5CA9AA, 0x7D7D7D, 0x347260, 0x204247],
		"outfit_b": [0x7890B5, 0x403C55, 0x302C42, 0x33323A, 0x26242D],
		"hair": [0x88655D, 0x654139, 0x46231B],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_male4:1": {
		"outfit_a": [0x75AC76, 0x8F605A, 0x568557, 0x446744, 0x674339, 0x472B24],
		"outfit_b": [0x455D45, 0x403C55, 0x243824, 0x243124, 0x182518],
		"hair": [0x6E7579, 0x3B3F42, 0x293035],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x743815],
	},
	"npc_male4:2": {
		"outfit_a": [0xBA8297, 0x5A788C, 0x8B5766, 0x56373D],
		"outfit_b": [0x7890B5, 0x403C55, 0x302C42, 0x33323A, 0x26242D],
		"hair": [0x7BC19D, 0x3E7759, 0x16443F],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_male4:3": {
		"outfit_a": [0xA0A59C, 0x7C7E7B, 0x757E6E, 0x4E5549, 0x4F524C, 0x393E35],
		"outfit_b": [0x7890B5, 0x403C55, 0x302C42, 0x33323A, 0x26242D],
		"hair": [0x705661, 0x4C3A41, 0x3B2D33],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_female1:0": {
		"outfit_a": [0x73A6CD, 0x4A78A1, 0x1E858E, 0x305678, 0x263F55],
		"outfit_b": [0x8B77CB, 0x6C57AF, 0x483B73, 0x352A59],
		"hair": [0x6DD173, 0x4CAC51, 0x1F8925, 0x1A5E40, 0x224535],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_female1:1": {
		"outfit_a": [0xD6869A, 0x4AB2B7, 0xAC586D, 0x7C404F, 0x632837],
		"outfit_b": [0xD4D4D4, 0x999999, 0x6D6D6D, 0x383838],
		"hair": [0x3B8D91, 0x2E5F62, 0x223D3E, 0x183132],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_female1:2": {
		"outfit_a": [0xCB77AE, 0xAE5790],
		"outfit_b": [0x7A4154, 0x4D323B],
		"hair": [0x5E3915, 0x432B13],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0x98552E, 0x743815],
	},
	"npc_female1:3": {
		"outfit_a": [0xA3A777, 0x757954, 0x60646E],
		"outfit_b": [0x575B34, 0x343624],
		"hair": [0xD3E4FF, 0xCDCDCD, 0x8B909C, 0x373A4A, 0x3B3B3B],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0xB89781, 0xA37538, 0x743815],
	},
	"npc_female2:0": {
		"outfit_a": [0xD6E1E9, 0xD99BB6, 0xA9B4BD, 0x6B7E8C, 0x8B4237, 0x2F373D],
		"outfit_b": [0xB25949, 0x8A4337, 0x592C28, 0x41221F],
		"hair": [0xA76C86, 0x814660, 0x573942, 0x412830],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x98552E, 0x743815],
	},
	"npc_female2:1": {
		"outfit_a": [0x2EA93D, 0x277630],
		"outfit_b": [0x315928, 0x23371E],
		"hair": [0xD36753, 0xB25949, 0x8A4337, 0x592C28, 0x41221F],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x98552E, 0x743815],
	},
	"npc_female2:2": {
		"outfit_a": [0xCC9BB0, 0x9C6F7E, 0x6E515B, 0x2F373D],
		"outfit_b": [0x428D87, 0x3F6A66, 0x31514E, 0x1D3230],
		"hair": [0xDD8E4E, 0xB1692F, 0x8D512C, 0x5E301D, 0x412113],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x98552E, 0x743815],
	},
	"npc_female2:3": {
		"outfit_a": [0xA67673, 0x769D67, 0x72423F, 0x31422A],
		"outfit_b": [0x543533, 0x422725],
		"hair": [0xD3E4FF, 0x8B909C, 0x60646E, 0x373A4A],
		"skin": [0xF9C19D, 0xEDCBB4, 0xDFA47D, 0xC58060, 0x98552E, 0x743815],
	},
}

var display_name: String = "Villager"
var dialogue: Array = []
var _name_label: Label

## Phase C quest/escort/day-night hooks. `_id` is the def id (== node name)
## the Quests node keys markers and interactions on. The two _hooked flags gate
## a one-time lazy connect to the Quests / DayNight singletons, which are added
## to the tree AFTER the NPC cast on first boot (so _ready() is too early).
var _id: String = "npc"
const BARK_RANGE := 78.0
var _bark_cd: float = 3.0   # per-npc ambient-bark cooldown
var _bark_salt: int = 0
var _marker_label: Label
var _base_wander_radius: float = 0.0
var _follow_target: Node2D = null
var _quests_hooked: bool = false
var _daynight_hooked: bool = false

var _sprite: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()
var _home: Vector2 = Vector2.ZERO
var _wander_radius: float = 0.0
var _facing: String = "down"
var _flip: bool = false
var _talking: bool = false
var _walking: bool = false
var _target: Vector2 = Vector2.ZERO
var _idle_time_left: float = 0.0
var _walk_time_left: float = 0.0


static func create(def: Dictionary) -> NPC:
	var npc := NPC.new()
	var id: String = String(def.get("id", "npc"))
	npc.name = id
	npc._id = id
	npc.display_name = String(def.get("display_name", "Villager"))
	npc.dialogue = def.get("dialogue", [])
	npc._home = def.get("pos", Vector2.ZERO)
	npc._wander_radius = float(def.get("wander_radius", 0.0))
	npc.position = npc._home
	npc._rng.seed = hash(id)
	npc._apply_facing_name(String(def.get("facing", "down")))

	var sheet: String = String(def.get("sheet", ""))
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.centered = true
	if sheet == "MAID":
		spr.sprite_frames = SheetAnim.make_maid_frames()
		spr.offset = MAID_OFFSET
	else:
		spr.sprite_frames = SheetAnim.make_szadi_frames(sheet, int(def.get("variant", 0)))
		spr.offset = SZADI_OFFSET
		var palette: Dictionary = def.get("palette", {})
		if not palette.is_empty():
			var mat: ShaderMaterial = _palette_material(sheet, int(def.get("variant", 0)), palette)
			if mat != null:
				spr.material = mat
	npc.add_child(spr)
	npc._sprite = spr

	var col := CollisionShape2D.new()
	col.name = "Feet"
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	npc.add_child(col)

	# Floating gold name tag, shown only while the player is close (see
	# _update_name_tag). Sits just above the ~30 px body's head line.
	var tag := Label.new()
	tag.name = "NameTag"
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/alagard.ttf")
	ls.font_size = 8
	ls.font_color = NAME_GOLD
	ls.outline_size = 3
	ls.outline_color = NAME_OUTLINE
	tag.label_settings = ls
	tag.text = npc.display_name
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks pass through
	tag.size = Vector2(96.0, 10.0)
	tag.position = Vector2(-48.0, -50.0)
	tag.z_index = 2  # readable above nearby world sprites despite y-sort
	tag.visible = false
	npc.add_child(tag)
	npc._name_label = tag

	# Quest marker: a gold Alagard glyph floating above the name tag — "!" when
	# this NPC has a quest to offer, "?" when a quest is ready to turn in or he
	# is a wanted talk target, "" otherwise. Unlike the name tag it stays
	# visible at any range (refreshed on quest signals / lazy hookup).
	var marker := Label.new()
	marker.name = "QuestMarker"
	var ms := LabelSettings.new()
	ms.font = load("res://assets/fonts/alagard.ttf")
	ms.font_size = 16
	ms.font_color = NAME_GOLD
	ms.outline_size = 4
	ms.outline_color = NAME_OUTLINE
	marker.label_settings = ms
	marker.text = ""
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = Vector2(96.0, 16.0)
	marker.position = Vector2(-48.0, -64.0)
	marker.z_index = 3
	marker.visible = false
	npc.add_child(marker)
	npc._marker_label = marker

	npc.collision_layer = 1 << 2
	npc.collision_mask = 1
	npc.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	npc.y_sort_enabled = true
	return npc


## Build the per-instance palette-swap material for a szadi sheet+variant.
## Returns null (leave the original look) when the variant has no verified
## ramps or the palette requests nothing — e.g. skin tone 0 only.
static func _palette_material(sheet: String, variant: int, palette: Dictionary) -> ShaderMaterial:
	var key: String = sheet.get_file().get_basename() + ":" + str(variant)
	if not RAMPS.has(key):
		return null
	var ramp: Dictionary = RAMPS[key]
	var src: Array[Color] = []
	var dst: Array[Color] = []
	for cat: String in ["outfit_a", "outfit_b", "hair"]:
		if palette.get(cat) is Color:
			var steps: Array = ramp[cat]
			var ref_v: float = _lightest_v(steps)
			for h: int in steps:
				var c: Color = _c8(h)
				src.append(c)
				dst.append(_shade(palette[cat], c.v / ref_v))
	if palette.has("skin"):
		var tone: int = clampi(int(palette.get("skin", 0)), 0, SKIN_TONES.size() - 1)
		if tone > 0:
			for h: int in ramp["skin"]:
				var c: Color = _c8(h)
				src.append(c)
				dst.append(_shade(SKIN_TONES[tone], c.v / SKIN_REF_V))
	if src.is_empty():
		return null
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	mat.set_shader_parameter("color_count", src.size())
	mat.set_shader_parameter("src_colors", PackedColorArray(src))
	mat.set_shader_parameter("dst_colors", PackedColorArray(dst))
	return mat


## Target colour for one ramp step: keep the base hue/saturation, scale its
## value by the step's brightness relative to the ramp's lightest step.
static func _shade(base: Color, ratio: float) -> Color:
	return Color.from_hsv(base.h, base.s, clampf(base.v * ratio, 0.0, 1.0), 1.0)


static func _lightest_v(steps: Array) -> float:
	var v: float = 0.0
	for h: int in steps:
		v = maxf(v, _c8(h).v)
	return maxf(v, 0.001)


## Exact 8-bit hex (0xRRGGBB) -> Color, matching texel values bit-perfectly.
static func _c8(rgb: int) -> Color:
	return Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)


func _ready() -> void:
	add_to_group("npcs")
	_base_wander_radius = _wander_radius
	_update_anim(false)
	if _wander_radius > 0.0:
		# Stagger first departures so villagers do not move in lockstep.
		_idle_time_left = _rng.randf_range(0.5, IDLE_MAX)
	_register_life()


## NPC life layer (BACKLOG #88): register this villager with NPCLifeSystem so it
## gets ambient bark bubbles / chatter / job routes / inn-rest. The system polls
## ONLY registered NPCs, so this hook is what turns the town-life layer on for
## real world actors. Fully guarded and degrade-safe: if the autoload is absent
## the NPC behaves exactly as before. Role is left blank so NPCLifeSystem infers
## it from the id (it lowercases + matches its own KNOWN_ROLES); zone is the live
## map id when the scene exposes one (blank otherwise). Visuals/placement are
## never touched here -- registration only.
func _register_life() -> void:
	var life: Node = get_node_or_null("/root/NPCLifeSystem")
	if life == null or not life.has_method("register_npc"):
		return
	var zone: String = ""
	var scene: Node = get_tree().current_scene
	if scene != null:
		var z: Variant = scene.get("current_map_id")
		if z is String:
			zone = str(z)
	life.call("register_npc", self, "", zone)


func _physics_process(delta: float) -> void:
	# Lazily connect to the Quests / DayNight singletons the first time they
	# exist (they are added after the NPC cast on boot). Stops polling once both
	# are wired.
	if not (_quests_hooked and _daynight_hooked):
		_hook_systems()
	# Name tag first: it must track the player even for stationary or
	# mid-dialogue villagers, whose branches below return early.
	_update_name_tag()
	_tick_bark(delta)
	if _talking:
		velocity = Vector2.ZERO
		return
	# Escort-lite (quest 5) overrides idle wander while a follow target is set.
	if _follow_target != null:
		if is_instance_valid(_follow_target):
			_tick_follow()
			return
		_follow_target = null
	if _wander_radius <= 0.0:
		return
	if _walking:
		_walk_time_left -= delta
		var to_target: Vector2 = _target - global_position
		if to_target.length() <= ARRIVE_DIST or _walk_time_left <= 0.0:
			_stop_walking()
			return
		var dir: Vector2 = to_target.normalized()
		velocity = dir * WALK_SPEED
		_set_move_facing(dir)
		_update_anim(true)
		move_and_slide()
	else:
		_idle_time_left -= delta
		if _idle_time_left <= 0.0:
			_pick_new_target()


## WoW-style ambient bark: a short spatial one-liner when the player lingers
## nearby, on a long per-npc cooldown so town chatter stays occasional. Baked
## clips (assets/vo/<speaker>/<hash>.ogg) play offline; live otherwise.
func _tick_bark(delta: float) -> void:
	_bark_cd -= delta
	if _bark_cd > 0.0 or _talking:
		return
	var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if pl != null and is_instance_valid(pl) and global_position.distance_to(pl.global_position) <= BARK_RANGE:
		var vo: Node = get_node_or_null("/root/Voice")
		var vr: Node = get_node_or_null("/root/VoiceRegistry")
		if vo != null and vr != null:
			vo.call("bark", self, _id, str(vr.call("bark_line", _id, _bark_salt)))
			_bark_salt += 1
		_bark_cd = _rng.randf_range(24.0, 44.0)
	else:
		_bark_cd = 1.0


## Called by the player. Stop, face the caller, run dialogue, resume after 1 s.
## Quest-aware: state-based quest pages (offer / talk / turn-in / choice /
## aftermath) served by the Quests node take priority over the flavor rotation.
func interact(by: Node2D) -> void:
	_talking = true
	_walking = false
	velocity = Vector2.ZERO
	var d: Vector2 = by.global_position - global_position
	if absf(d.x) > absf(d.y):
		_facing = "side"
		_flip = d.x > 0.0
	else:
		_facing = "down" if d.y > 0.0 else "up"
		_flip = false
	_update_anim(false)

	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		_on_dialogue_finished()
		return

	# Quest content first (per quests.gd INTEGRATION). npc_interact() returns {}
	# to fall through; else {quest_id, kind, pages, choice}. npc_interact_done()
	# (in _finish_quest_dialogue) is the ONLY talk-advance path here — do NOT
	# also call report_talk, that would double-advance the objective.
	var q := get_tree().get_first_node_in_group("quests")
	if q != null:
		var r: Dictionary = q.call("npc_interact", _id)
		if not r.is_empty():
			_begin_quest_dialogue(ui, q, r)
			return

	if dialogue.is_empty():
		_on_dialogue_finished()
		return
	ui.show_dialogue(display_name, dialogue, _id)
	if not ui.is_connected("dialogue_finished", _on_dialogue_finished):
		ui.connect("dialogue_finished", _on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished() -> void:
	# Stay put for a moment, then the wander AI takes over again.
	_talking = false
	_walking = false
	_idle_time_left = RESUME_DELAY


# ----------------------------------------------------------------------
# Quest dialogue flow (offer / talk / turn-in / world-anchored choice)
# ----------------------------------------------------------------------

## Show a quest dialogue result, then advance/turn-in on close and, if the
## result carries a choice, present the two-option prompt.
func _begin_quest_dialogue(ui: Node, q: Node, r: Dictionary) -> void:
	var pages: Array = r.get("pages", [])
	if pages.is_empty():
		# Some states (e.g. an empty reminder) carry no pages — skip straight to
		# the resolution so the villager never freezes mid-"conversation".
		_finish_quest_dialogue(q, r)
		return
	ui.call("show_dialogue", display_name, pages, _id)
	ui.connect("dialogue_finished", func() -> void: _finish_quest_dialogue(q, r), CONNECT_ONE_SHOT)


func _finish_quest_dialogue(q: Node, r: Dictionary) -> void:
	if is_instance_valid(q):
		q.call("npc_interact_done", r)
	var ch: Dictionary = r.get("choice", {})
	if not ch.is_empty():
		var ui := get_tree().get_first_node_in_group("dialogue_ui")
		if ui != null and is_instance_valid(q) \
				and ui.has_method("show_choice") and ui.has_signal("choice_made"):
			ui.connect("choice_made", func(opt: String) -> void: _on_quest_choice(q, r, opt), CONNECT_ONE_SHOT)
			ui.call("show_choice", display_name, str(ch.get("prompt", "")),
					_choice_label(ch.get("a")), _choice_label(ch.get("b")))
			return
	_refresh_marker()
	_on_dialogue_finished()


func _on_quest_choice(q: Node, r: Dictionary, opt: String) -> void:
	var follow: Array = []
	if is_instance_valid(q):
		follow = q.call("report_choice", str(r.get("quest_id", "")), opt)
	_refresh_marker()
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	if not follow.is_empty() and ui != null:
		ui.call("show_dialogue", display_name, follow, _id)
		ui.connect("dialogue_finished", _on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		_on_dialogue_finished()


## The choice preview from quests.gd carries option labels as plain strings
## ({"a": String}); tolerate a {"label": String} sub-dict too so the prompt
## never renders blank regardless of which shape the systems ship.
static func _choice_label(v: Variant) -> String:
	if v is Dictionary:
		return str((v as Dictionary).get("label", ""))
	return str(v)


# ----------------------------------------------------------------------
# Quest marker + day/night hookup (Quests / DayNight singletons)
# ----------------------------------------------------------------------

func _hook_systems() -> void:
	if not _quests_hooked:
		var q := get_tree().get_first_node_in_group("quests")
		if q != null:
			if q.has_signal("quest_started"):
				q.connect("quest_started", _on_quest_signal)
			if q.has_signal("quest_updated"):
				q.connect("quest_updated", _on_quest_signal)
			if q.has_signal("quest_completed"):
				q.connect("quest_completed", _on_quest_signal)
			_quests_hooked = true
			_refresh_marker()
	if not _daynight_hooked:
		var dn := get_tree().get_first_node_in_group("day_night")
		if dn != null:
			if dn.has_signal("night_changed"):
				dn.connect("night_changed", _on_night_changed)
			_daynight_hooked = true
			if dn.get("is_night") == true:
				_apply_night(true)


func _on_quest_signal(_quest_id: String) -> void:
	_refresh_marker()


func _refresh_marker() -> void:
	if _marker_label == null:
		return
	var q := get_tree().get_first_node_in_group("quests")
	if q == null:
		_marker_label.visible = false
		return
	var m: String = str(q.call("marker_for_npc", _id))
	if _marker_label.text != m:
		_marker_label.text = m
	_marker_label.visible = m != ""


func _on_night_changed(is_night_now: bool) -> void:
	_apply_night(is_night_now)


## Night behavior (SPEC §6): after dusk villagers pull toward home and wander a
## tighter radius; restored by day. No-op for stationary NPCs and while escorting.
func _apply_night(is_night_now: bool) -> void:
	if _base_wander_radius <= 0.0 or is_following():
		return
	if is_night_now:
		_wander_radius = _base_wander_radius * NIGHT_WANDER_FACTOR
		if not _talking:
			_target = _home
			_walk_time_left = (_home - global_position).length() / WALK_SPEED * 2.0 + 1.0
			_walking = true
	else:
		_wander_radius = _base_wander_radius


# ----------------------------------------------------------------------
# Escort-lite (SPEC §5 quest 5) — opt-in follow controller
# ----------------------------------------------------------------------

## Enable follow: the NPC walks toward `t` while within FOLLOW_LEASH and keeps
## the Quests "escort_<id>" flag in sync with whether it is keeping up. Dormant
## for every NPC until main.gd's Mira lifecycle calls this (single owner of the
## when/why; this node owns only the movement + flag while active).
func set_follow_target(t: Node2D) -> void:
	_follow_target = t


func stop_following() -> void:
	_follow_target = null
	_walking = false
	velocity = Vector2.ZERO
	var q := get_tree().get_first_node_in_group("quests")
	if q != null:
		q.call("set_flag", "escort_" + _id, false)
	_update_anim(false)


func is_following() -> bool:
	return _follow_target != null and is_instance_valid(_follow_target)


func _tick_follow() -> void:
	var tgt: Vector2 = _follow_target.global_position
	var dist: float = global_position.distance_to(tgt)
	var keeping_up: bool = dist <= FOLLOW_LEASH
	var q := get_tree().get_first_node_in_group("quests")
	if q != null:
		q.call("set_flag", "escort_" + _id, keeping_up)
	if keeping_up and dist > FOLLOW_STOP_DIST:
		var dir: Vector2 = (tgt - global_position).normalized()
		velocity = dir * WALK_SPEED
		_set_move_facing(dir)
		_update_anim(true)
		move_and_slide()
	else:
		# Within arm's reach, or the player outran the leash: stall in place.
		velocity = Vector2.ZERO
		_update_anim(false)


func _pick_new_target() -> void:
	var ang: float = _rng.randf_range(0.0, TAU)
	var dist: float = _rng.randf_range(_wander_radius * 0.3, _wander_radius)
	_target = _home + Vector2(cos(ang), sin(ang)) * dist
	var travel: float = (_target - global_position).length()
	# Safety cap: if blocked by walls, give up instead of walking in place.
	_walk_time_left = travel / WALK_SPEED * 2.0 + 1.0
	_walking = true


func _update_name_tag() -> void:
	if _name_label == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var show_name: bool = player != null and is_instance_valid(player) \
			and player.global_position.distance_to(global_position) <= NAME_RANGE
	if _name_label.visible != show_name:
		_name_label.visible = show_name


func _stop_walking() -> void:
	_walking = false
	velocity = Vector2.ZERO
	_idle_time_left = _rng.randf_range(IDLE_MIN, IDLE_MAX)
	_update_anim(false)


func _set_move_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing = "side"
		_flip = dir.x > 0.0
	else:
		_facing = "down" if dir.y > 0.0 else "up"
		_flip = false


func _apply_facing_name(f: String) -> void:
	match f:
		"left", "side":
			_facing = "side"
			_flip = false
		"right":
			_facing = "side"
			_flip = true
		"up":
			_facing = "up"
			_flip = false
		_:
			_facing = "down"
			_flip = false


func _update_anim(moving: bool) -> void:
	var anim: String = ("walk_" if moving else "idle_") + _facing
	if _sprite.animation != StringName(anim) or not _sprite.is_playing():
		_sprite.play(anim)
	# Sheets face LEFT on side frames (verified); flip when facing right.
	_sprite.flip_h = _flip and _facing == "side"
