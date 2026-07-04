class_name MapRegistry
## Phase C §1 — central registry of playable maps (demo ships "town" + "wilderness",
## but the registry is future-proof: add a def below and the map exists).
## Each def: {id, display_name, builder (Callable -> the same Dictionary
## TownBuilder.build returns: {player_spawn, npc_spawns, bounds}), music,
## dusk_tint, travel_points: [{id, pos, radius, to_map, to_point, prompt}]}.
##
## INTEGRATION (wired by the integration pass, NOT by this file):
##  * main.gd gains change_map(map_id: String, entry_point_id: String):
##      - fade to black 0.4 s, free the current World children,
##      - var def := MapRegistry.get_map(map_id)
##      - var built: Dictionary = def["builder"].call(world_node)
##      - place player at MapRegistry.get_travel_point(map_id, entry_point_id)["pos"]
##        (fall back to built["player_spawn"] when the point id is unknown);
##        nudging the spawn ~24 px toward map center avoids standing inside the
##        return-trigger radius on arrival (harmless either way — prompt just shows),
##      - camera limits from built["bounds"], NPC/enemy spawns per map, fade in,
##      - swap music stream to def["music"], feed def["dusk_tint"] to the
##        day/night CanvasModulate, show def["display_name"] as location banner.
##  * main.gd travel loop (physics tick): for tp in
##    MapRegistry.travel_points(current_map): if player.global_position
##    .distance_to(tp["pos"]) <= tp["radius"] show tp["prompt"]; on the interact
##    action call change_map(tp["to_map"], tp["to_point"]).
##  * Town side: after TownBuilder.build(parent) the integrator calls
##    GateBuilder.add_gate(parent) (scripts/gate_builder.gd) — it returns the
##    exact position of travel point "east_gate" below (keep the constants in
##    sync — see TOWN_EAST_GATE).
##  * wilderness_builder.gd (parallel workflow) must expose
##    static func build(parent: Node2D) -> Dictionary with the TownBuilder
##    contract, and its west road should terminate at WILD_WEST_ENTRY so the
##    return waystone/gate lines up with travel point "west_entry".
##  * save_system.gd stores the current map id; boot-from-save calls
##    change_map(saved_id, "") and places the player at the saved position.

## Travel-point anchors (single source of truth for cross-map positions).
## TOWN_EAST_GATE = GateBuilder.GATE_POS + GateBuilder.TRAVEL_OFFSET — kept as a
## literal here so each script validates standalone; keep the two in sync.
const TOWN_EAST_GATE := Vector2(2192.0, 816.0)
const WILD_WEST_ENTRY := Vector2(80.0, 880.0)

const MUSIC_TOWN := "res://assets/audio/music/theme_lost_village.ogg"
const MUSIC_WILD := "res://assets/audio/music/theme_plain.ogg"

## Dusk tints per map (fed to the day/night CanvasModulate at dusk; §6).
const DUSK_TOWN := Color(1.0, 0.87, 0.72)
const DUSK_WILD := Color(0.94, 0.82, 0.70)


static func get_map(map_id: String) -> Dictionary:
	## Full def for one map, with "builder" resolved to a live Callable.
	## Returns {} (and pushes an error) for unknown ids.
	var defs := _defs()
	if not defs.has(map_id):
		push_error("MapRegistry: unknown map id '%s'" % map_id)
		return {}
	var def: Dictionary = (defs[map_id] as Dictionary).duplicate(true)
	def["builder"] = _builder_callable(String(def["builder_script"]))
	return def


static func has_map(map_id: String) -> bool:
	return _defs().has(map_id)


static func map_ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _defs().keys():
		out.append(String(key))
	return out


static func travel_points(map_id: String) -> Array:
	## The travel-point dicts of one map ([] for unknown ids).
	var defs := _defs()
	if not defs.has(map_id):
		return []
	return (defs[map_id] as Dictionary)["travel_points"] as Array


static func get_travel_point(map_id: String, point_id: String) -> Dictionary:
	## One travel point ({id, pos, radius, to_map, to_point, prompt});
	## {} when either id is unknown.
	for tp: Variant in travel_points(map_id):
		if (tp as Dictionary)["id"] == point_id:
			return (tp as Dictionary).duplicate(true)
	return {}


# ------------------------------------------------------------------ DEFS ----

static func _defs() -> Dictionary:
	return {
		"town": {
			"id": "town",
			"display_name": "Raven Hollow",
			"builder_script": "res://scripts/town_builder.gd",
			"music": MUSIC_TOWN,
			"dusk_tint": DUSK_TOWN,
			"travel_points": [
				{
					"id": "east_gate",
					"pos": TOWN_EAST_GATE,
					"radius": 28.0,
					"to_map": "wilderness",
					"to_point": "west_entry",
					"prompt": "[E] The Emberfall Road — Wilderness",
				},
			],
		},
		"wilderness": {
			"id": "wilderness",
			"display_name": "The Emberfall Road",
			"builder_script": "res://scripts/wilderness_builder.gd",
			"music": MUSIC_WILD,
			"dusk_tint": DUSK_WILD,
			"travel_points": [
				{
					"id": "west_entry",
					"pos": WILD_WEST_ENTRY,
					"radius": 28.0,
					"to_map": "town",
					"to_point": "east_gate",
					"prompt": "[E] Return to Raven Hollow",
				},
			],
		},
	}


static func _builder_callable(script_path: String) -> Callable:
	## Builders resolve lazily by path so this file parses even while a peer
	## builder script is still being written by a parallel workflow.
	if not ResourceLoader.exists(script_path):
		push_warning("MapRegistry: builder script missing: %s" % script_path)
		return Callable()
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		push_error("MapRegistry: failed to load builder script: %s" % script_path)
		return Callable()
	return Callable(script, "build")
