class_name QuestDefs
## Static quest database for the Phase C demo — the five Draconia quests of
## SPEC_PHASE_C_DEMO.md §5, Long Vigil era. Pure data, no scene code (mirrors
## class_defs.gd / npc_data.gd). Consumed by Quests (quests.gd).
##
## Tone law (Lore Bible): dread is ambient, no quest offers a clean win, and
## the Underlanguage symptom ladder is canon — ground warms, wells go copper,
## yeast dies, dust aligns, people "listen".
##
## ------------------------------------------------------------------
## QUEST DEF SHAPE (every quest carries at least the starred keys)
## ------------------------------------------------------------------
##   *id            String — stable save id
##   *title         String — Alagard gold in tracker/journal
##   *giver         String — npc id ("" = auto-trigger only)
##    prereq        Array[String] — quest ids that must be completed before
##                   the giver offers this quest (auto_trigger ignores prereq)
##   *summary       String — journal blurb while active
##   *offer_pages   Array[String] — giver dialogue; accepting = closing it
##    active_pages  Array[String] — giver reminder while quest in progress
##    accept_items  Array[String] — item ids granted on accept (quest items)
##   *objectives    Array[Dictionary] — see OBJECTIVE SHAPE
##    turn_in_npc   String — npc who takes the turn-in ("" = auto-complete
##                   the moment the final objective is done)
##    turn_in_pages Array[String] — spoken at turn-in
##   *rewards       {xp:int, gold:int, items:Array[String]}
##   *note          String — journal line once completed
##    aftermath     {npc_id: Array[String]} — replaces that NPC's default
##                   dialogue after this quest completes (flavor echo)
##    auto_trigger  {map:String, pos:Vector2, radius:float, night_only:bool}
##                   — walking into this zone force-accepts the quest
##    finale_pages  Array[String] + finale_speaker String — scripted beat
##                   shown by integration right when the quest auto-completes
##    finale_beat   String — Quests emits cinematic_beat(finale_beat) first
##                   (quest 5: "listener_whisper" = all lights dim one beat)
##
## ------------------------------------------------------------------
## OBJECTIVE SHAPE (kinds per spec §4: talk / kill / reach / choice / use_item)
## ------------------------------------------------------------------
##   common: {id:String (unique, for override_pos), kind:String,
##            text:String (tracker line)}
##   talk:     + {npc:String, pages:Array[String]}  — pages spoken by that npc
##   kill:     + {enemy:String, count:int}          — matches Enemy.type_name
##   reach:    + {map:String, pos:Vector2, radius:float,
##                night_only:bool (optional), escort:String (optional npc id
##                that must be following — see INTEGRATION),
##                grant_item:String (optional, granted on arrival),
##                arrive_note:String (optional toast/log line)}
##   choice:   + {prompt:String, npc:String ("" = world prompt),
##                retry_pages:Array[String] (npc re-offer if player walked
##                away without choosing),
##                a:{label, pages, objectives, rewards, turn_in_npc,
##                   turn_in_pages, note, aftermath}, b:{same}}
##              — the chosen option's `objectives` replace everything after
##                the choice; option keys override the quest-level ones.
##   use_item: + {item:String, map:String, pos:Vector2, radius:float}
##
## ------------------------------------------------------------------
## INTEGRATION (owned by the integration pass — NOT this file):
## ------------------------------------------------------------------
## 1. NPC ids referenced here that DO NOT exist yet in NPCData.cast():
##      "gatewarden" — Gatewarden Iosif (gate workflow adds him at the east
##                     gate; quest 4 branch B talks to him)
##      "mira"       — Mira, the miller's daughter (quest 5): spawned at the
##                     q5_treeline spot at NIGHT while quest 5 is not
##                     completed; once quest 5 is active she follows the
##                     player when within 40 px (escort-lite); the escort
##                     controller must call
##                     Quests.set_flag("escort_mira", true/false) as the
##                     follow state changes. Despawn/walk her home after the
##                     finale.
## 2. Positions marked PLACEHOLDER below must be re-bound to builder truth
##    at map-build time via Quests.override_pos(objective_id, pos):
##      q4_camp (orc camp overlook, wilderness SE), q5_treeline (far-east
##      treeline LISTENER spot), q5_gate (wilderness-side gate/waystone).
##    Town positions (q1_well fountain 1120,790 · q1_cemetery graveyard
##    center 460,410 · q3_stone / q3_bury hooded witness-statue 448,340) are
##    read from town_builder.gd constants and should stay valid.
## 3. Enemy type names used by kill objectives: "skeleton", "boar",
##    "orc_shaman" — the wilderness builder MUST give the orc camp's shaman
##    enemy `type = "orc_shaman"` in its config dict.
## 4. items.gd must gain the defs below (quest rewards + quest items). All
##    follow the exact Items._DB dict shape; icons need IconsPixel entries.
##    Copy-paste ready:
##      "coppervein_ring": {"id": "coppervein_ring", "name": "Coppervein Ring",
##        "slot": "ring", "rarity": "uncommon", "icon": "pixel:coppervein_ring",
##        "stats": {"damage": 0.0, "armor": 0.0, "hp": 10.0, "mana": 8.0,
##        "speed_pct": 0.0, "crit_pct": 0.0},
##        "flavor": "Buried with a woman who died old and unafraid.",
##        "stackable": false, "effect": ""},
##      "travelers_boots": {"id": "travelers_boots", "name": "Traveler's Boots",
##        "slot": "boots", "rarity": "uncommon", "icon": "pixel:travelers_boots",
##        "stats": {"damage": 0.0, "armor": 1.0, "hp": 5.0, "mana": 0.0,
##        "speed_pct": 6.0, "crit_pct": 0.0},
##        "flavor": "They walked out the east gate once already.",
##        "stackable": false, "effect": ""},
##      "gorans_targe": {"id": "gorans_targe", "name": "Goran's Targe",
##        "slot": "off_hand", "rarity": "rare", "icon": "pixel:gorans_targe",
##        "stats": {"damage": 0.0, "armor": 4.0, "hp": 12.0, "mana": 0.0,
##        "speed_pct": 0.0, "crit_pct": 0.0},
##        "flavor": "Same winter, same steel lot. The only quiet piece.",
##        "stackable": false, "effect": ""},
##      "weeping_dagger": {"id": "weeping_dagger", "name": "The Wrapped Dagger",
##        "slot": "none", "rarity": "rare", "icon": "pixel:weeping_dagger",
##        "stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0,
##        "speed_pct": 0.0, "crit_pct": 0.0},
##        "flavor": "Kept wrapped. The cloth is damp at one corner.",
##        "stackable": false, "effect": ""},
##      "charcoal_rubbing": {"id": "charcoal_rubbing", "name": "Charcoal Rubbing",
##        "slot": "none", "rarity": "common", "icon": "pixel:charcoal_rubbing",
##        "stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0,
##        "speed_pct": 0.0, "crit_pct": 0.0},
##        "flavor": "Angular runes. Keep it face-down.",
##        "stackable": false, "effect": ""},
##    Quest 3 branch B rewards the EXISTING legendary "bloody_dagger" (the
##    canon echo); integration must also REMOVE "weeping_dagger" from the bag
##    on that branch (branch A consumes it via Quests.report_use_item).
##    Quest 2 rewards include 2× "boar_hide" — defined by the crafting
##    workflow; Quests grants items by id, so if the crafting slice ships
##    later the grant is skipped with a warning (safe).
## 5. Quest 5's whisper beat: Quests emits cinematic_beat("listener_whisper")
##    at completion; integration dims the screen ~0.6 s (vignette layer 5)
##    and shows finale_pages via dialogue_ui (speaker finale_speaker).

const NPC_LABELS := {
	"innkeeper": "Innkeeper Marta",
	"blacksmith": "Blacksmith Goran",
	"merchant": "Merchant Tibalt",
	"farmer": "Farmer Ansel",
	"gravekeeper": "Gravekeeper Vasile",
	"wanderer1": "Old Petra",
	"gatewarden": "Gatewarden Iosif",
	"mira": "Mira",
}

# Town anchor points (from town_builder.gd verified constants).
const POS_PLAZA_WELL := Vector2(1120.0, 790.0)      # plaza fountain-well
const POS_CEMETERY := Vector2(460.0, 410.0)         # grave rows center
const POS_WITNESS_STONE := Vector2(448.0, 340.0)    # hooded statue
# Wilderness PLACEHOLDERS (~70x55 tiles @32 px) — override_pos at build time.
const POS_ORC_CAMP := Vector2(1850.0, 1350.0)       # SE camp overlook
const POS_TREELINE := Vector2(2130.0, 880.0)        # far-east LISTENER spot
const POS_WILD_GATE := Vector2(150.0, 880.0)        # wilderness-side waystone


## id -> quest def, in demo order.
static func all() -> Dictionary:
	var out: Dictionary = {}
	for q: Dictionary in _quests():
		out[str(q["id"])] = q
	return out


static func npc_label(npc_id: String) -> String:
	return str(NPC_LABELS.get(npc_id, npc_id.capitalize()))


static func _quests() -> Array:
	return [
		_q1_well_went_copper(),
		_q2_fresh_hay_old_bones(),
		_q3_blade_wont_dry(),
		_q4_what_the_rooks_saw(),
		_q5_one_who_listens(),
	]


# ----------------------------------------------------------------------
# 1. THE WELL WENT COPPER — main hook. Giver: Innkeeper Marta.
# Canon symptom #2; ends on Vasile's "bookmark, not an ending".
# ----------------------------------------------------------------------
static func _q1_well_went_copper() -> Dictionary:
	return {
		"id": "well_went_copper",
		"title": "The Well Went Copper",
		"giver": "innkeeper",
		"prereq": [],
		"summary": "The Ember Hearth's water tastes of copper — and it is not just Marta's well.",
		"offer_pages": [
			"Hold a moment, traveler. Before you order anything — taste the water. Go on. Taste it and tell me I'm imagining things.",
			"Copper. Like a coin held under the tongue. The barrel's scrubbed, the bucket's new, and it's not only my well — it's every drop drawn in Raven Hollow since Thursday.",
			"My grandmother had a saying: when the well goes copper, count your candles. She said a lot of things. She never laughed when she said that one.",
			"Go and look at the plaza well for me, would you? I'd go myself, but someone has to stop the stew from... burning. From burning. Go on, and come tell me it's nothing.",
		],
		"active_pages": [
			"Still copper. Worse, if anything — the tea's gone the color of old blood, and the bread barely rises anymore. Whatever Vasile tells you to do, do it soon.",
		],
		"accept_items": [],
		"objectives": [
			{
				"id": "q1_well",
				"kind": "reach",
				"text": "Inspect the plaza well",
				"map": "town",
				"pos": POS_PLAZA_WELL,
				"radius": 48.0,
				"grant_item": "charcoal_rubbing",
				"arrive_note": "Angular runes have been scratched into the wellstone — and someone took a charcoal rubbing of them, then dropped it. You pocket the page without looking at it too long.",
			},
			{
				"id": "q1_vasile",
				"kind": "talk",
				"text": "Bring the rubbing to Gravekeeper Vasile",
				"npc": "gravekeeper",
				"pages": [
					"What's this, then? Paper. Charcoal. And — ah. No. Turn it face-down. NOW.",
					"You don't READ what the ground writes. That's how it gets in — through the eyes first, then through the wanting-to-understand. Give it here.",
					"There. Ash tells no one anything. ... On the wellstone, you say. Then my yard is next. The old dead grow restless when the ground starts talking underneath them.",
					"Come to the cemetery after dark. If nothing walks, I'll apologize for wasting your evening. Mark this: I have never once apologized.",
				],
			},
			{
				"id": "q1_cemetery",
				"kind": "reach",
				"text": "Check the old cemetery at night",
				"map": "town",
				"pos": POS_CEMETERY,
				"radius": 90.0,
				"night_only": true,
				"arrive_note": "The graveyard has gone quiet — the wrong kind of quiet, like a held breath. Then the first soil moves.",
			},
			{
				"id": "q1_skeletons",
				"kind": "kill",
				"text": "Put down the risen dead",
				"enemy": "skeleton",
				"count": 4,
			},
		],
		"turn_in_npc": "gravekeeper",
		"turn_in_pages": [
			"Four of them, up and walking. In MY yard. And they didn't dig out angry, traveler — they dug out LISTENING. Mark the difference. Angry passes.",
			"Take this. Copper — yes, I'm aware of the joke. It was buried with a woman who died old and unafraid, which is the rarest blessing this ground gives. Some of it may rub off.",
			"And whatever the priests told you about the Pause: it's a bookmark, not an ending. Something put its thumb in the page. One day it means to keep reading.",
		],
		"rewards": {"xp": 100, "gold": 25, "items": ["coppervein_ring"]},
		"note": "The wells still taste of copper. Vasile burned the runes unread and says the Pause is a bookmark, not an ending.",
		"aftermath": {},
	}


# ----------------------------------------------------------------------
# 2. FRESH HAY, OLD BONES — giver: Farmer Ansel. Forces the first gate
# trip; turn-in seeds the wolf dread and gates quest 4.
# ----------------------------------------------------------------------
static func _q2_fresh_hay_old_bones() -> Dictionary:
	return {
		"id": "fresh_hay_old_bones",
		"title": "Fresh Hay, Old Bones",
		"giver": "farmer",
		"prereq": [],
		"summary": "Something out of the east woods tears up Ansel's north field by night. He wagers boars.",
		"offer_pages": [
			"You there — you look like you can swing something heavier than a hoe. My north field's torn to ruin. Third night running, and always worst before dawn.",
			"Snout-work, deep and greedy. Boars, I'd wager — big ones, come down out of the wilderness past the east gate. The ground there's been... generous, lately. Things grow fat on it.",
			"Take the Emberfall Road out the gate and cull three of them, and I'll make it worth your while. And traveler — walk it in daylight if you've any sense left. The woods past the wall aren't the woods they were.",
		],
		"active_pages": [
			"Three boars, out the east gate. The field won't mend itself, and whatever's rooting it up isn't getting politer while we stand here.",
		],
		"accept_items": [],
		"objectives": [
			{
				"id": "q2_boars",
				"kind": "kill",
				"text": "Cull boars in the wilderness",
				"enemy": "boar",
				"count": 3,
			},
		],
		"turn_in_npc": "farmer",
		"turn_in_pages": [
			"Three, you say? Good. Honest work — the field might live to see harvest after all. Here, and the hides are yours too; I want nothing that slept out there.",
			"Only... I walked the fence line this morning, and boar-sign wasn't all I found. Tracks. Dog-shaped, but too big. And too MANY — circling the field, even-spaced, like something was reading the place.",
			"Boots for your trouble. My brother's. He walked out the east gate two winters back and the road never handed him back. They should fit. Wear them somewhere safer than he did.",
		],
		"rewards": {"xp": 60, "gold": 15, "items": ["travelers_boots", "boar_hide", "boar_hide"]},
		"note": "The boars are culled — but wolf tracks ring Ansel's field, too many and too deliberate.",
		"aftermath": {},
	}


# ----------------------------------------------------------------------
# 3. THE BLADE THAT WON'T DRY — giver: Blacksmith Goran. Moral-gray canon
# Bloody Dagger echo. CHOICE at Vasile: bury it, or keep it. No clean win.
# ----------------------------------------------------------------------
static func _q3_blade_wont_dry() -> Dictionary:
	return {
		"id": "blade_wont_dry",
		"title": "The Blade That Won't Dry",
		"giver": "blacksmith",
		"prereq": [],
		"summary": "Goran's unclaimed dagger beads fresh blood overnight. He wants it carried to Vasile — wrapped.",
		"offer_pages": [
			"You. Close the door. ...I need a thing carried, and carried by someone who doesn't gossip and doesn't ask the water why it's red.",
			"Winter before last, a man ordered a dagger. Paid in full, up front — old coin, cold hands, wouldn't warm them at my forge. Never came back for it. Fine. A smith keeps unclaimed work. That's custom.",
			"Except it won't stay CLEAN. I wipe it down at close of day, and by morning there's blood beaded along the edge. Not rust — I know rust like I know my own hands. Blood. And nothing in this shop bleeds. I've made certain.",
			"Take it up the hill to Vasile. Wrapped — you keep it wrapped. He deals in things that don't stay where they're put. Whatever he tells you to do with it, do it. Just don't bring it back through my door.",
		],
		"active_pages": [
			"Is it done? Then why are you here and it isn't with Vasile? Keep it WRAPPED. And keep walking.",
		],
		"accept_items": ["weeping_dagger"],
		"objectives": [
			{
				"id": "q3_vasile",
				"kind": "talk",
				"text": "Take the wrapped dagger to Vasile",
				"npc": "gravekeeper",
				"pages": [
					"Goran sent you? Then it's a debt, or a body, or — ah. Unwrap it. Slowly. On the stone, not in your hand.",
					"Yes. I know this order of work. Not Goran's hammer — the ASKING. Someone asked the steel for something, and paid for the asking in the oldest currency there is.",
					"Everything that stays sharp is waiting for something. The only question is whether you let it wait in the ground — or on your belt.",
					"Bury it in the old yard, under my witness-stone, before it learns the weight of your hand. Or keep it, and be its answer when the waiting ends. I'll dig either grave. One of them is just slower.",
				],
			},
			{
				"id": "q3_choice",
				"kind": "choice",
				"text": "Decide the dagger's fate",
				"npc": "gravekeeper",
				"prompt": "The dagger hums faintly through the wrapping. Vasile waits, spade already in hand.",
				"retry_pages": [
					"Still weighing it? The dagger doesn't mind. Waiting is the one thing it does honestly.",
				],
				"a": {
					"label": "Bury it in the old cemetery",
					"pages": [
						"The witness-stone, then — the hooded one past the third row, the one that faces AWAY from the graves. It faces away for a reason. Things buried under its regard stay modest.",
						"Dig shallow, lay it flat, and say nothing over it. Words are how the ground learns names.",
					],
					"objectives": [
						{
							"id": "q3_stone",
							"kind": "reach",
							"text": "Go to the witness-stone in the old cemetery",
							"map": "town",
							"pos": POS_WITNESS_STONE,
							"radius": 45.0,
							"arrive_note": "The hooded statue faces away from the graves. The soil at its feet is loose, as if it has always expected deliveries.",
						},
						{
							"id": "q3_bury",
							"kind": "use_item",
							"text": "Bury the wrapped dagger beneath the stone",
							"item": "weeping_dagger",
							"map": "town",
							"pos": POS_WITNESS_STONE,
							"radius": 45.0,
						},
					],
					"turn_in_npc": "blacksmith",
					"turn_in_pages": [
						"In the ground? Under stone, with the old man watching? ...Ha. HA! You'd not think a man could sleep on news of a burial, but I'll sleep tonight — first honest night in two winters.",
						"Take the targe. Same winter, same steel lot — and the only piece from that batch that never once troubled me. Maybe it was the shield the dagger was waiting for. Better it hangs on you than in here, wondering.",
					],
					"rewards": {"xp": 90, "gold": 20, "items": ["gorans_targe"]},
					"note": "The dagger sleeps under Vasile's witness-stone. Goran sleeps too — for the first time in two winters.",
					"aftermath": {},
				},
				"b": {
					"label": "Keep the dagger",
					"pages": [
						"So. It goes with you. ...Unwrap it, then. No point in modesty between the two of you now.",
						"Look — the blood is drying into the steel like it's coming home. It has never once done that on my stone. It likes your hand. I'd tell you what that usually means, but you've chosen not to be told things today.",
						"Everything that stays sharp is waiting for something. Try to die before you find out what.",
					],
					"objectives": [],
					"turn_in_npc": "",
					"turn_in_pages": [],
					"rewards": {"xp": 90, "gold": 0, "items": ["bloody_dagger"]},
					"note": "You kept the dagger. It is always freshly bloody. Goran will not meet your eyes again.",
					"aftermath": {
						"blacksmith": [
							"...",
							"Forge is busy. I've nothing for you.",
							"(He does not look up from the anvil. He does not look at your belt, either — very carefully.)",
						],
					},
				},
			},
		],
		"turn_in_npc": "blacksmith",
		"turn_in_pages": [],
		"rewards": {"xp": 90, "gold": 0, "items": []},
		"note": "",
		"aftermath": {},
	}


# ----------------------------------------------------------------------
# 4. WHAT THE ROOKS SAW — giver: Old Petra. Scout the orc camp, then
# CHOICE: strike the shaman, or slip away and warn the town. Either way,
# the camp — or the rooks — remain.
# ----------------------------------------------------------------------
static func _q4_what_the_rooks_saw() -> Dictionary:
	return {
		"id": "what_the_rooks_saw",
		"title": "What the Rooks Saw",
		"giver": "wanderer1",
		"prereq": ["fresh_hay_old_bones"],
		"summary": "The rooks circle the east woods and will not land. Petra wants eyes on the old road.",
		"offer_pages": [
			"Sit a moment, dear. My knees are holding a parliament and your legs look young enough to vote. ...There. Now look east, over the treeline. Tell me what you see.",
			"Rooks. Circling since dawn, and NOT LANDING. A rook will land on a gallows, dear. A rook will land on anything. The only thing a rook won't roost over is a thing that watches back.",
			"Something is camped on the old road through the east woods, and the birds have been saying so for three days to anyone who'd listen. Nobody listens to birds anymore. Go and be my eyes — from a distance, mind. Come back with the SHAPE of it, not a piece of it.",
		],
		"active_pages": [
			"The rooks are still up, dear. Higher today, if anything. Whatever it is, it's grown sure of itself. East woods — the old road. And keep your shadow behind you.",
		],
		"accept_items": [],
		"objectives": [
			{
				"id": "q4_camp",
				"kind": "reach",
				"text": "Scout the camp on the old road",
				"map": "wilderness",
				"pos": POS_ORC_CAMP,
				"radius": 100.0,
				"arrive_note": "Orcs — the start of a warband. Six at least, banners raised, and a shaman feeding something green into the fire that makes the smoke bend the wrong way.",
			},
			{
				"id": "q4_choice",
				"kind": "choice",
				"text": "Strike now, or slip away and warn the town",
				"npc": "",
				"prompt": "The shaman's chant carries through the trees. The camp hasn't seen you — yet.",
				"retry_pages": [],
				"a": {
					"label": "Strike now — kill the shaman",
					"pages": [
						"(You check your edge and move toward the firelight. Above the canopy, the rooks go silent all at once — the way a room does when it wants to watch.)",
					],
					"objectives": [
						{
							"id": "q4_shaman",
							"kind": "kill",
							"text": "Kill the orc shaman",
							"enemy": "orc_shaman",
							"count": 1,
						},
					],
					"turn_in_npc": "wanderer1",
					"turn_in_pages": [
						"You smell of green smoke and bold decisions, dear. The rooks landed an hour ago — first time in four days. So the loud part of the problem is dead, then.",
						"Here. This came from my mother, who swore it fell out of a rook's nest the year the old king died. It sees what they see. I'm too old to want to know, and you are exactly young enough.",
						"The camp is still there, mind. Thinner — but there. You've cut the tongue out of the wolf, dear. The wolf is still deciding what that means.",
					],
					"rewards": {"xp": 120, "gold": 10, "items": ["ravens_eye"]},
					"note": "The shaman is dead and the rooks have landed. The camp remains — thinner, and deciding.",
					"aftermath": {},
				},
				"b": {
					"label": "Slip away and warn the town",
					"pages": [
						"(You count the fires twice, mark the banners, and back away the way hunters teach — slow, and without opinions.)",
					],
					"objectives": [
						{
							"id": "q4_warn",
							"kind": "talk",
							"text": "Warn Gatewarden Iosif at the east gate",
							"npc": "gatewarden",
							"pages": [
								"Report it plain, traveler. Numbers, banners, fires — in that order. ...Six or more, banners UP, and a shaman working the flame. On the old road itself.",
								"Then it's not raiders passing through. Banners up means an argument someone intends to finish. I'll double the watch tonight and send word up the Vigil roads by first light.",
								"You did the sensible thing. Put that on my stone someday, if you like: HE DID THE SENSIBLE THING. Nobody sings about us, but the walls stay standing.",
							],
						},
					],
					"turn_in_npc": "wanderer1",
					"turn_in_pages": [
						"Guards doubled on the wall, word gone up the road, and you back with all your fingers. Sensible, dear. Truly. ...The rooks are still circling, mind.",
						"Sensible buys time. It has never yet bought quiet. Take this for the walking — and keep an ear on the treeline. The birds do.",
					],
					"rewards": {"xp": 120, "gold": 60, "items": []},
					"note": "The town is warned and the watch doubled. The rooks still circle.",
					"aftermath": {},
				},
			},
		],
		"turn_in_npc": "wanderer1",
		"turn_in_pages": [],
		"rewards": {"xp": 120, "gold": 0, "items": []},
		"note": "",
		"aftermath": {},
	}


# ----------------------------------------------------------------------
# 5. THE ONE WHO LISTENS — demo finale and Kickstarter cliffhanger.
# From Marta after quest 1, OR auto-triggers at the far-east treeline at
# night. Escort-lite; completes unresolved: "The ground is patient."
# ----------------------------------------------------------------------
static func _q5_one_who_listens() -> Dictionary:
	return {
		"id": "one_who_listens",
		"title": "The One Who Listens",
		"giver": "innkeeper",
		"prereq": ["well_went_copper"],
		"summary": "Mira, the miller's daughter, walked to the far treeline at dusk and stands there — listening.",
		"offer_pages": [
			"Traveler — thank the saints, a face with its wits still behind it. It's Mira. The miller's girl. She took the east road at dusk carrying nothing, wearing no cloak, and walking like she'd been CALLED for.",
			"Her father's leg is broken and every other soul in this room has suddenly remembered somewhere else to be. First the water goes copper, then the bread stops rising, and now this. My grandmother had a saying for this one too, and I will not repeat it under my own roof.",
			"The far treeline, past the old road's end — that's where the miller's boy last saw her. Bring her home. And if she's standing still when you find her... don't shout. You must never startle a person who is listening.",
		],
		"active_pages": [
			"She's still out there, and the light's going. Whatever she's hearing, traveler, don't let her finish hearing it. Bring her home.",
		],
		"accept_items": [],
		"auto_trigger": {
			"map": "wilderness",
			"pos": POS_TREELINE,
			"radius": 90.0,
			"night_only": true,
		},
		"objectives": [
			{
				"id": "q5_treeline",
				"kind": "reach",
				"text": "Find Mira at the far-east treeline (at night)",
				"map": "wilderness",
				"pos": POS_TREELINE,
				"radius": 80.0,
				"night_only": true,
				"arrive_note": "Mira stands at the treeline, head tilted, eyes open. She is not looking at anything. She is listening.",
			},
			{
				"id": "q5_gate",
				"kind": "reach",
				"text": "Lead Mira home to the gate (stay close — she follows)",
				"map": "wilderness",
				"pos": POS_WILD_GATE,
				"radius": 70.0,
				"escort": "mira",
			},
		],
		"turn_in_npc": "",
		"turn_in_pages": [],
		"finale_beat": "listener_whisper",
		"finale_speaker": "Mira",
		"finale_pages": [
			"(At the gate arch, Mira stops mid-step. Her head tilts the other way — slowly, like a page being turned back.)",
			"\"Vhal-oru sedh. Kaam-tem vhal... sub-vatra, numen-ieh.\" One sentence — level, patient, in a voice with far too much room in it. The words arrive through your teeth, not your ears.",
			"(Every lantern on the wall dims at once, for the length of one held breath.)",
			"...oh. The gate? I was — fetching flour, I think. Why is it dark already? Did you walk me home? That was kind of you. It's... it's very kind, how quiet everything is.",
		],
		"rewards": {"xp": 150, "gold": 0, "items": []},
		"note": "Mira remembers nothing. The ground is patient.",
		"aftermath": {
			"innkeeper": [
				"Mira's home safe — doesn't remember a step of it, her father says. She's been humming, though. A little tune nobody taught her.",
				"You did right, traveler. You did right. ...So why does my own taproom feel like it's counting us?",
			],
		},
	}
