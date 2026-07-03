class_name NPCData
## Static cast list for Raven Hollow's villagers. `pos` and `wander_radius`
## are placeholders here — main.gd fills them from TownBuilder's npc_spawns,
## matching def.id to the spawn role name.
## Sheet/variant pairs are unique; player uses npc_male1 variant 0 (reserved).

const CHAR_DIR := "res://assets/art/characters/"


static func cast() -> Array:
	return [
		_def("innkeeper", "Innkeeper Marta", CHAR_DIR + "npc_female1.png", 0, "down", [
			"Welcome to the Ember Hearth, traveler. Sit yourself down before you fall down.",
			"We don't see many new faces since the old road washed out. Carts must swing wide past the graveyard now, and most don't bother.",
			"Harvest's been kind this year, thank the saints. Means the stew has actual meat in it.",
			"If you hear folk whisper about the fountain, pay it no mind. Or a little mind — coins have gone missing from it, is all.",
		]),
		_def("blacksmith", "Blacksmith Goran", CHAR_DIR + "npc_male2.png", 1, "down", [
			"Mind the sparks. I've singed nobler brows than yours.",
			"Ore comes up the old road — when the old road feels like being a road.",
			"Folk say a wish-coin in the fountain brings luck. I say a well-hammered nail brings more.",
			"Need something mended, come to me. Need gossip, the inn is that way.",
		]),
		_def("merchant", "Merchant Tibalt", CHAR_DIR + "npc_male3.png", 2, "down", [
			"Ah, a customer! Or at least someone shaped like one.",
			"Finest goods this side of the old road. Which, I'll grant, isn't saying much lately.",
			"Between us — someone's been fishing coins out of the fountain at night. Terrible luck, stealing a wish.",
			"Come back after the harvest fair. I'll have spices that will make your tongue write poetry.",
		]),
		_def("farmer", "Farmer Ansel", CHAR_DIR + "npc_male4.png", 0, "side", [
			"Good soil this year. Rain came when it was asked, and left when it wasn't.",
			"Harvest fair's coming. Whole village turns out — even old Vasile down from his graveyard hill.",
			"My grandfather planted the pear tree by the fountain. Fed half of Raven Hollow through one bad winter.",
			"Well. The wheat won't cut itself. Never has, no matter how nicely I ask.",
		]),
		_def("gravekeeper", "Gravekeeper Vasile", CHAR_DIR + "npc_male2.png", 3, "down", [
			"Hm. You're breathing. That puts you outside my line of work — for now.",
			"The graveyard is older than the village, you know. Raven Hollow grew around its dead, not the other way round.",
			"Everyone ends up on my hill eventually. The lucky ones arrive slowly.",
			"They toss coins in the fountain and wish to live forever. I collect a different kind of toll.",
			"Go on, enjoy the sun. It's wasted on me.",
		]),
		_def("maid", "Maid Elsbeth", "MAID", 0, "down", [
			"Oh! Don't mind me — run clean off my feet. Marta keeps this inn spotless and me exhausted.",
			"A pedlar swore he saw lights on the old road past midnight. Marsh-fire, probably. Probably.",
			"Everyone tosses a coin in the fountain before harvest. Mine's for a week of dry weather and a quiet taproom.",
			"If you stay the night, mind the third stair. It creaks like it's telling secrets.",
		]),
		_def("wanderer1", "Old Petra", CHAR_DIR + "npc_female2.png", 1, "side", [
			"Fine day for walking. My knees disagree, but they've disagreed since the old king.",
			"I remember when the fountain was new. The mason swore it would sing under a full moon. It never did. Well — once.",
			"The ravens roost above the graveyard come autumn. Village is named for them, you know.",
			"Walk with your eyes open, dear. Places like this remember things.",
		]),
		_def("wanderer2", "Young Emeric", CHAR_DIR + "npc_male1.png", 2, "down", [
			"One day I'm taking the old road as far as it goes. Past the graveyard, past everything.",
			"Da says the harvest needs me more than the wide world does. The wide world hasn't weighed in yet.",
			"I flicked a coin in the fountain and wished for an adventure. Then you walked in. Coincidence?",
			"You've been past the hills, yes? Is it true the cities have streets of stone all the way down?",
		]),
	]


static func _def(id: String, display_name: String, sheet: String, variant: int, facing: String, dialogue: Array[String]) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"sheet": sheet,
		"variant": variant,
		"pos": Vector2.ZERO,
		"wander_radius": 0.0,
		"dialogue": dialogue,
		"facing": facing,
	}
