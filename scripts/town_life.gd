class_name TownLife
## RAVEN HOLLOW CITY — the life pass (Fable 5.1, 2026-09-21). City folk with
## their own lines, spawned at the places that explain them: vendors behind
## their stalls, guards at both gates and the keep, a priest at the cathedral
## door, dock hands on the quay, gardeners in the allotments, farmers on their
## yards, drinkers outside the Drowned Rat. Ids carry a role keyword so
## NPCLifeSystem infers barks/routes (guard, merchant, priest, fisher, farmer,
## innkeeper, blacksmith, gravekeeper, maid, baker, gatewarden, wanderer).
## Looks: the six Szadi sheets x 4 variants x a muted colourway, seeded per id
## so no two neighbours match. Called by TownBuilder.build after TownCity.build.

const CHAR_DIR := "res://assets/art/characters/"
const SHEETS := ["npc_male1", "npc_male2", "npc_male3", "npc_male4", "npc_female1", "npc_female2"]
const OUTFITS := [
	{"a": Color("6b6b3a"), "b": Color("4a4a28")}, {"a": Color("6e3030"), "b": Color("4c2020")},
	{"a": Color("6b4a2f"), "b": Color("4a3320")}, {"a": Color("4e5a66"), "b": Color("37414a")},
	{"a": Color("55663f"), "b": Color("3b472c")}, {"a": Color("3f3f43"), "b": Color("2b2b2e")},
	{"a": Color("8a7a58"), "b": Color("625640")}, {"a": Color("46655f"), "b": Color("304742")},
	{"a": Color("5d3547"), "b": Color("402432")}, {"a": Color("7a7a72"), "b": Color("565650")},
	{"a": Color("7d6a3a"), "b": Color("5a4b28")}, {"a": Color("3c4a5c"), "b": Color("2a3442")},
]
const GUARD_OUTFITS := [
	{"a": Color("3f3f43"), "b": Color("2b2b2e")}, {"a": Color("4e5a66"), "b": Color("37414a")},
	{"a": Color("5a2a2a"), "b": Color("3c1c1c")},
]
const HAIRS := [Color("1d1a17"), Color("3d2c1e"), Color("5a3a24"), Color("8a8578"), Color("d8d3c8"), Color("58291f")]

# [id, display name, x, y, wander radius, facing, sheet index or -1 (seeded), variant or -1, [lines]]
const FOLK := [
	# --- Trade Square: the market, the bank, the auction house, the crier
	["city_merchant_1", "Ilinca Vulpescu", 3060, 1254, 0, "down", 4, 1, ["Salt from the fens. Honest salt, weighed honest.", "Ask me about the well and I'll charge you double for the silence."]],
	["city_merchant_2", "Tudor Crainic", 3340, 1254, 0, "down", 1, 2, ["Cabbages. Grown north of the leat, where the ground still sleeps."]],
	["city_merchant_3", "Maricica", 3130, 1344, 0, "down", 5, 0, ["Tomatoes from my own back plot. Red as anything you'll see this side of the Pit."]],
	["city_merchant_4", "Old Bogdan", 3410, 1344, 0, "down", 2, 3, ["I sold nails to the garrison once. Now I sell them to widows.", "Same nails. Smaller coffins."]],
	["city_banker", "Clerk Anghel", 3364, 1012, 6, "down", 0, 2, ["The bank keeps what you give it. That is more than the ground does."]],
	["city_auctioneer", "Auctioneer Stanca", 3766, 1012, 6, "down", 4, 3, ["Lots close at dusk. The Vigil's bell decides when, not I."]],
	["city_crier", "Crier Fane", 3520, 1090, 30, "down", 3, 0, ["Hear ye. The east gate bars at the second bell.", "Wolves do not read notices. Nor, it seems, do you."]],
	["city_wanderer_1", "Petru", 3200, 1150, 140, "down", -1, -1, ["Busy square for a town that's dying. That's how you can tell it's dying."]],
	["city_wanderer_2", "Anca", 3400, 1120, 140, "down", -1, -1, ["The fountain water's still clear. I check. Everyone checks."]],
	["city_wanderer_3", "Grigore", 3260, 1240, 120, "left", -1, -1, ["Bread's dearer than nails now. Ask Bogdan which one keeps you alive."]],
	["city_wanderer_4", "Ruxandra", 3560, 1200, 120, "down", -1, -1, ["I came in from Vetka. Don't ask me why. Everyone from Vetka has the same why."]],
	["city_wanderer_5", "Matei", 3000, 1120, 120, "right", -1, -1, ["The keep watches the square. The square watches the keep. Nobody watches the ground."]],
	# --- the Vigil Keep: gate guards, courtyard, the drill posts
	["city_guard_1", "Keep Guard", 3548, 708, 0, "down", 3, 1, ["The keep is the Vigil. You don't walk in. You're sent for."]],
	["city_guard_2", "Keep Guard", 3652, 708, 0, "down", 3, 1, ["Move along. The captain's not seeing anyone with mud on their boots."]],
	["city_guard_3", "Guard Vlaicu", 3320, 520, 40, "down", 3, 1, ["Courtyard's ours. Everything past the wall is the Accord's problem."]],
	["city_guard_4", "Guard Ilie", 3820, 565, 50, "left", 3, 1, ["Forty-seven years of Vigil and the wall's never been climbed. Nothing needs to climb it."]],
	["city_guard_5", "Sergeant Dragoslav", 3930, 615, 30, "left", 3, 1, ["Posts don't hit back.", "Neither did the last thing we buried. It just kept turning its head."]],
	["city_guard_10", "Guard Petrache", 3500, 470, 50, "down", 3, 1, ["Fire's for the night watch. Day watch gets the sun and likes it less."]],
	["city_guard_11", "Quartermaster Grigorescu", 3140, 430, 8, "down", 2, 3, ["Spears, boots, salt. Sign for them. Everything in this keep is signed for.", "Except the dead. Nobody signs for the dead."]],
	["city_wanderer_30", "Pilgrim Ana", 5370, 1064, 0, "up", 5, 3, ["I lit a candle for my brother. It burned blue. Father Ambrozie says that means nothing.", "He says it very quickly."]],
	["city_wanderer_31", "Pilgrim Sorin", 5432, 1066, 0, "up", 0, 1, ["Walked from the Steppe. My knees gave out here. Good a place as any to kneel."]],
	["city_wanderer_32", "Sister Agatha", 6230, 1436, 30, "down", 4, 2, ["The Hospice takes anyone the road breaks. Lately the road breaks them from the inside."]],
	["city_wanderer_33", "Old Soldier Dinu", 6462, 1440, 0, "down", 2, 1, ["Forty years on the wall. Now I sit under it. The wall doesn't mind either way."]],
	["city_wanderer_34", "Costin", 3300, 2044, 180, "left", -1, -1, ["There's a cross on my neighbour's door since Thursday. Nobody nailed it. Nobody's taken it down."]],
	["city_wanderer_35", "Domnica", 2760, 2564, 180, "right", -1, -1, ["Two wells in this town run sweet. I could tell you which. I won't."]],
	["city_wanderer_36", "Radu the Younger", 3460, 3084, 180, "left", -1, -1, ["Ward's got a shrine now. Old Town's got the Rat. Pick your church."]],
	["city_wanderer_37", "Maria", 3300, 3604, 180, "right", -1, -1, ["The canal gave one back this spring. We buried it on the bank. The bank kept it."]],
	["city_wanderer_38", "Tiberiu", 4860, 3124, 200, "right", -1, -1, ["Ward well's gone copper. The board says nothing. The board's right."]],
	["city_wanderer_39", "Ancuta", 5800, 3124, 200, "left", -1, -1, ["Three streets and a shrine. It's not much. It's ours."]],
	["city_wanderer_40", "Stoian", 5000, 3644, 200, "right", -1, -1, ["I carry water from Old Town now. Half a mile for a bucket that doesn't taste of pennies."]],
	["city_wanderer_41", "Zamfira", 5600, 4064, 200, "left", -1, -1, ["Last street before the river. Nothing comes up from the river. That's what I tell the children."]],
	["city_fisher_6", "Ferryman Onut", 1900, 4940, 30, "down", 2, 3, ["Ferry's tied up. Has been since the Grey one stopped calling.", "I'll row you across for coin. I won't row you back."]],
	["city_fisher_7", "Eel-smoker Vera", 5600, 4950, 40, "down", 5, 2, ["Eels from the east bend. Smoked slow. They keep.", "Everything from that bend keeps. That's the trouble with it."]],
	["city_farmer_c1", "Shepherd's boy Nae", 760, 4030, 40, "down", 0, 3, ["Fold's empty. I keep it swept anyway. Father says something will need it."]],
	["city_farmer_c2", "Haymaker Ilinca", 1600, 3390, 50, "down", 4, 0, ["Hay's in early. Ground's warm, grass grows, we cut. Nobody says why it's warm."]],
	["city_farmer_c3", "Haymaker Bogdan", 760, 2500, 70, "down", 1, 1, ["Two carts a day to the fair. Horses eat. That's the one honest trade left."]],
	["city_wanderer_42", "Pilgrim at the cross", 1268, 3596, 0, "up", 3, 2, ["I stop here every day on the way to the mill. Some days I don't get to the mill."]],
	# --- the burned garrison (the warrior's yard)
	["city_guard_6", "Veteran Costache", 2520, 565, 20, "down", 3, 1, ["This drill-yard held when the garrison burned. Held. Everything else in it didn't.", "You want to learn the sword, you learn it here, on ground that remembers."]],
	# --- the approach and the horse fair
	["city_gatewarden_2", "Tollman Pavel", 2420, 792, 10, "down", 3, 1, ["The old gate takes no toll now. The new one takes it in other coin."]],
	["city_blacksmith_2", "Farrier Costel", 2600, 1528, 10, "left", 1, 0, ["Shoes for horses, nails for the rest. Iron doesn't care what it's driven into."]],
	["city_merchant_5", "Horse-trader Radu", 2700, 1400, 70, "down", 2, 1, ["Sound of wind and limb, every one.", "Don't ask what they hear at night. I don't."]],
	["city_wanderer_6", "Stable-lad Ionut", 2560, 1300, 60, "down", 0, 3, ["Hay's in. Hay's always in. It's the water I watch."]],
	# --- Old Town: the streets, the well square, the Drowned Rat
	["city_wanderer_7", "Neculai", 3100, 2044, 160, "right", -1, -1, ["Four streets, one canal, and every door I know. That's Old Town."]],
	["city_wanderer_8", "Floarea", 3700, 2044, 160, "left", -1, -1, ["My grandmother's house. Her grandmother's. The cellar's older than the wall."]],
	["city_wanderer_9", "Zaharia", 2900, 2564, 160, "right", -1, -1, ["Kerb-stones are new this year. Somebody's counting them."]],
	["city_wanderer_10", "Lenuta", 3500, 2564, 160, "left", -1, -1, ["The washing dries slower than it did. Don't tell me it's the weather."]],
	["city_wanderer_11", "Toma", 3000, 3084, 160, "right", -1, -1, ["Canal's low. Canal's always low now."]],
	["city_wanderer_12", "Smaranda", 3600, 3084, 160, "left", -1, -1, ["I keep the front step swept. It's the one thing that stays swept."]],
	["city_wanderer_13", "Iancu", 2800, 3604, 160, "right", -1, -1, ["Harbour men drink at the Rat. Old Town drinks at home, with the shutters closed."]],
	["city_wanderer_14", "Veronica", 3400, 3604, 160, "left", -1, -1, ["The lamps come on at dusk. Somebody lights them. I've never seen who."]],
	["city_maid_1", "Sanda", 2470, 2562, 40, "right", 4, 2, ["This well's still sweet. I check it every morning.", "Every morning it's a smaller mercy."]],
	["city_maid_2", "Dorica", 2532, 2584, 40, "left", 5, 1, ["Bring your bucket or don't. The rope's the town's, the water's God's, and neither's mine."]],
	["city_innkeeper_2", "Vintila", 3080, 3664, 16, "down", 2, 0, ["The Drowned Rat. Named for the first one we pulled out of the canal.", "Not the last."]],
	["city_wanderer_15", "Dumitru", 2990, 3740, 40, "down", -1, -1, ["Ale's dark, the room's warm, and the door's thick. Three reasons."]],
	["city_wanderer_16", "Ghita", 3170, 3740, 40, "down", -1, -1, ["I don't go home till the second bell. Home listens."]],
	["city_wanderer_17", "Marin", 2480, 2300, 200, "down", -1, -1, ["Fair Street runs gate to harbour. Everything that comes into this town walks past my door."]],
	["city_wanderer_18", "Ileana", 2480, 3340, 200, "up", -1, -1, ["Allotments on the left, houses on the right, and the river at the end. That's the whole map."]],
	# --- the East Road, the ward square, the justice corner, the east gate
	["city_wanderer_19", "Carter Vasile", 4300, 2604, 220, "right", -1, -1, ["Road's cobbled to the gate now. Cart still rattles. Cart always rattles."]],
	["city_wanderer_20", "Aurelia", 4900, 2604, 220, "left", -1, -1, ["Six plots of cabbage between here and the leat. Six. I counted before I could read."]],
	["city_wanderer_21", "Simion", 5800, 2604, 220, "right", -1, -1, ["East Ward's the new part. New as in forty years. The ground doesn't count that as new."]],
	["city_wanderer_22", "Catinca", 6400, 2604, 220, "left", -1, -1, ["Past the gate is the Emberfall Road. Past that, I've never asked."]],
	["city_merchant_6", "Potter Gavril", 5310, 2534, 0, "down", 2, 2, ["Jars, pots, and a jug that won't crack. Clay's from the river. River's fine. The clay's fine."]],
	["city_merchant_7", "Tanner Ana", 5530, 2534, 0, "down", 5, 3, ["Hides cured out back. If it smells, that's the trade. If it whispers, that's something else."]],
	["city_wanderer_23", "Ward Elder Oprea", 5420, 2560, 120, "down", -1, -1, ["The ward keeps its own square and its own well. The keep can keep the rest."]],
	["city_guard_7", "Watchman Nicu", 6880, 2860, 30, "down", 3, 1, ["Stocks are empty today. Give it till the fair."]],
	["city_guard_8", "Gate Guard", 6890, 2540, 0, "down", 3, 1, ["Emberfall Road. Say your name to the wardens on the far side, and say it once."]],
	["city_guard_9", "Gate Guard", 6890, 2664, 0, "up", 3, 1, ["Gate bars at the second bell. Be inside it or be interesting."]],
	# --- the cathedral square and the churchyard
	["city_priest", "Father Ambrozie", 5400, 672, 10, "down", 0, 0, ["We keep the Vigil with candles. The ground keeps it with patience.", "Light one. It costs you nothing. It costs the dark a little."]],
	["city_gravekeeper_2", "Sexton Mihai", 5820, 522, 40, "down", 2, 3, ["Six new rows this winter.", "I have stopped counting the old ones. Some of them count themselves."]],
	["city_wanderer_24", "Widow Corbeanu", 5778, 476, 0, "up", 5, 2, ["He's under the third stone. I come to make sure he still is."]],
	["city_wanderer_25", "Bishop's Clerk", 5300, 1000, 140, "down", -1, -1, ["The Bishop is at prayer. The Bishop is always at prayer. It's the safest room in the town."]],
	["city_wanderer_26", "Pilgrim Onisim", 5520, 1040, 140, "down", -1, -1, ["Walked from Stonepath. Every wayside stone on the road was warm. I didn't stop to ask why."]],
	# --- the market gardens and the gardeners' shed
	["city_farmer_a1", "Gardener Nastasia", 4830, 1856, 40, "down", 4, 0, ["Cabbages don't listen.", "That's why I grow cabbages."]],
	["city_farmer_a2", "Gardener Petrache", 5810, 1856, 40, "down", 1, 3, ["Good soil under the leat. Wet, black, and quiet. The quiet's the part I pay for."]],
	["city_farmer_a3", "Gardener Ruxa", 4850, 1928, 40, "down", 5, 0, ["Carrots came up straight this year. First time in three. I don't know what that means either."]],
	["city_farmer_a4", "Old Nichifor", 6880, 2172, 20, "down", 2, 1, ["Shed's mine. Tools are the ward's. Hands are getting to be nobody's."]],
	# --- the harbour, the strand, the fishers
	["city_fisher_1", "Dock-hand Radomir", 2900, 4330, 90, "down", 1, 1, ["Cargo in, cargo out. Nothing on the manifest says where it slept."]],
	["city_fisher_2", "Dock-hand Bucur", 3600, 4330, 90, "down", 3, 2, ["Three piers, two boats, one river. Arithmetic of a town that used to be bigger."]],
	["city_fisher_3", "Dock-hand Sorin", 4300, 4330, 90, "down", 0, 3, ["Grey Ferry doesn't stop here anymore. Nothing that crosses water stops here anymore."]],
	["city_merchant_8", "Harbourmaster Zamfir", 3170, 4330, 30, "down", 2, 2, ["Every hull's logged. Every hull. Even the ones that come in empty and leave emptier."]],
	["city_merchant_9", "Fishwife Marga", 3250, 4354, 0, "down", 4, 3, ["Fresh. Well. Fresh from the river, and the river's what it is."]],
	["city_fisher_4", "Fisher Ciprian", 5080, 4432, 40, "down", 1, 2, ["River's slow. Slow water carries things.", "You learn not to look too long."]],
	["city_fisher_5", "Fisher Lupu", 6580, 4272, 40, "down", 0, 1, ["I fish the east bend alone. Company talks. The bend doesn't like talk."]],
	# --- the fields, the mill, the paddock, the chapel mound
	["city_farmer_b1", "Goodman Iorgu", 1560, 2170, 40, "down", 2, 0, ["Two fields and a barn, inside the wall. Outside it, I had four."]],
	["city_farmer_b2", "Goodwife Stanca", 660, 2702, 50, "down", 5, 3, ["Corn's short. Ground's warm. I've heard the words the Vetka folk use for it. I won't."]],
	["city_baker", "Miller Luca", 1390, 4436, 24, "down", 1, 3, ["Flour's grey this year. Bread's grey. Yeast doesn't take.", "Don't tell the town. The town's eating it."]],
	["city_farmer_b3", "Shepherd Anghelina", 1900, 3062, 60, "down", 4, 1, ["Sheep went to the Coast market. Paddock's for hay and memory now."]],
	["city_wanderer_27", "Kneeling Pilgrim", 572, 2092, 6, "up", 0, 2, ["Sworn here. Not to anything you'd call a church anymore.", "The candles burn green. Nobody lights them green."]],
	# --- the candle-house (the mage's pocket) and the SE commons
	["city_wanderer_28", "Widow Ciresica", 6560, 1004, 20, "right", 5, 1, ["The council sealed that door. The candle in the window lights itself.", "Walk on. I do, every day, and I've lived across from it thirty years."]],
	["city_wanderer_29", "Ragman Tase", 6740, 3300, 120, "down", -1, -1, ["Burned farm's down the track. Nobody claims the cart. Nobody claims the grave."]],
]


static func populate(world: Node2D) -> void:
	for row_v: Variant in FOLK:
		var row: Array = row_v
		var id: String = String(row[0])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("rh_city_" + id)
		var sheet_idx: int = int(row[6])
		var variant: int = int(row[7])
		if sheet_idx < 0:
			sheet_idx = rng.randi_range(0, SHEETS.size() - 1)
		if variant < 0:
			variant = rng.randi_range(0, 3)
		var is_guard: bool = id.find("guard") != -1 or id.find("gatewarden") != -1
		var pool: Array = GUARD_OUTFITS if is_guard else OUTFITS
		var colourway: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var def := {
			"id": id,
			"display_name": String(row[1]),
			"sheet": CHAR_DIR + SHEETS[sheet_idx] + ".png",
			"variant": variant,
			"pos": Vector2(float(row[2]), float(row[3])),
			"wander_radius": float(row[4]),
			"dialogue": row[8],
			"facing": String(row[5]),
			"palette": {
				"outfit_a": colourway["a"],
				"outfit_b": colourway["b"],
				"hair": HAIRS[rng.randi_range(0, HAIRS.size() - 1)],
				"skin": rng.randi_range(0, 3),
			},
		}
		world.add_child(NPC.create(def))
	if OS.get_environment("RH_SMOKE") != "":
		print("[TownLife] %d city folk placed" % FOLK.size())
