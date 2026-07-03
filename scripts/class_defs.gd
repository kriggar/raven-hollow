class_name ClassDefs
## Static class definitions for the six playable classes of
## Raven Hollow: Emberfall. Pure data + tiny helpers — no scene code.
##
## Class def shape (exact):
##   {id, name, title, lore, sheet, variant, max_hp, max_mana, speed,
##    hp_regen, mana_regen, color, abilities}
## Ability shape (exact, abilities[0] = basic attack, mana_cost 0):
##   {id, name, icon, cooldown, mana_cost, range, damage, kind, params}
## `kind` is one of: melee_arc, projectile, aoe_ring, dash, summon, buff, volley.
##
## params conventions per kind (every params carries "color": the ability's
## VFX accent Color — muted, never neon):
##   melee_arc:  arc_degrees.
##   projectile: speed, projectile (visual kind string for
##               VFX.projectile_visual: "spark"|"fireball"|"orb"|"arrow"|
##               "knife"), optional aoe_radius (impact splash), thin (bool).
##   aoe_ring:   `range` = ring radius. at_aim (false = centered on self),
##               optional cast_range (max placement distance when at_aim),
##               tick_interval + duration (ticking consecrated ground —
##               render with VFX.ground_circle), slow_mult + slow_duration,
##               root_duration.
##   dash:       `range` = dash distance in px. smoke / feathers (bool VFX
##               flags), optional next_hit_mult + bonus_duration.
##   summon:     minion_type (enemy.gd sheet family, e.g. "skeleton"),
##               lifetime, minion_hp, minion_damage, minion_speed.
##   buff:       duration, optional speed_mult, damage_mult, absorb.
##   volley:     count, pattern ("radial" = burst around caster,
##               "rain" = arrows over aim area), speed, projectile (visual
##               kind), optional radius + duration (rain area / spread time).
##
## Sheet/variant picks verified by PIL crop of each sheet's down-facing idle
## frame (row = variant*3 + 1, col 0). All six are distinct and avoid the NPC
## cast combos (female1 v0, male2 v1, male3 v2, male4 v0, male2 v3,
## female2 v1, male1 v2):
##   warrior     male1 v0   — bearded, green quilted jerkin, sturdy.
##   rogue       male4 v3   — lean youth, all-dark shirt and trousers.
##   mage        female2 v3 — grey-haired wisewoman in long mauve robe.
##   paladin     male1 v1   — bearded, steel-blue padded gambeson.
##   necromancer male3 v1   — grim spectacled elder in long grey coat.
##   rookwarden  male2 v0   — huntsman in a weathered brown leather coat.

const _DEFS := {
	"warrior": {
		"id": "warrior",
		"name": "Warrior",
		"title": "Shield of the Hollow",
		"lore": "When the Emberfall razed the old garrison, only the drill-yard's stubbornness survived in him. Now he stands where the palisade burned, daring the dark to try Raven Hollow twice.",
		"sheet": "res://assets/art/characters/npc_male1.png",
		"variant": 0,
		"max_hp": 140.0,
		"max_mana": 40.0,
		"speed": 82.0,
		"hp_regen": 1.5,
		"mana_regen": 4.0,
		"color": Color(0.68, 0.30, 0.26),
		"abilities": [
			{
				"id": "cleave",
				"name": "Cleave",
				"icon": "res://assets/art/icons/slice-orange-1.png",
				"cooldown": 0.5,
				"mana_cost": 0.0,
				"range": 26.0,
				"damage": 12.0,
				"kind": "melee_arc",
				"params": {"arc_degrees": 110.0, "color": Color(0.84, 0.78, 0.70)},
			},
			{
				"id": "whirlwind",
				"name": "Whirlwind",
				"icon": "res://assets/art/icons/wind-red-1.png",
				"cooldown": 6.0,
				"mana_cost": 20.0,
				"range": 40.0,
				"damage": 18.0,
				"kind": "aoe_ring",
				"params": {"at_aim": false, "color": Color(0.75, 0.38, 0.30)},
			},
			{
				"id": "war_cry",
				"name": "War Cry",
				"icon": "res://assets/art/icons/haste-fire-1.png",
				"cooldown": 12.0,
				"mana_cost": 15.0,
				"range": 0.0,
				"damage": 0.0,
				"kind": "buff",
				"params": {
					"duration": 5.0,
					"speed_mult": 1.4,
					"damage_mult": 1.3,
					"color": Color(0.88, 0.55, 0.28),
				},
			},
		],
	},
	"rogue": {
		"id": "rogue",
		"name": "Rogue",
		"title": "Knife in the Fog",
		"lore": "Raised in the fog-alleys behind the tavern, he learned young that a quiet knife settles what loud men cannot. The Hollow's shadows owe him favors, and he collects them nightly.",
		"sheet": "res://assets/art/characters/npc_male4.png",
		"variant": 3,
		"max_hp": 90.0,
		"max_mana": 50.0,
		"speed": 105.0,
		"hp_regen": 1.0,
		"mana_regen": 5.0,
		"color": Color(0.62, 0.62, 0.66),
		"abilities": [
			{
				"id": "quick_slash",
				"name": "Quick Slash",
				"icon": "res://assets/art/icons/slice-spirit-1.png",
				"cooldown": 0.35,
				"mana_cost": 0.0,
				"range": 22.0,
				"damage": 8.0,
				"kind": "melee_arc",
				"params": {"arc_degrees": 90.0, "color": Color(0.80, 0.80, 0.84)},
			},
			{
				"id": "shadowstep",
				"name": "Shadowstep",
				"icon": "res://assets/art/icons/fog-air-1.png",
				"cooldown": 5.0,
				"mana_cost": 10.0,
				"range": 70.0,
				"damage": 0.0,
				"kind": "dash",
				"params": {
					"smoke": true,
					"next_hit_mult": 2.0,
					"bonus_duration": 3.0,
					"color": Color(0.45, 0.44, 0.50),
				},
			},
			{
				"id": "fan_of_knives",
				"name": "Fan of Knives",
				"icon": "res://assets/art/icons/needles-blue-1.png",
				"cooldown": 7.0,
				"mana_cost": 20.0,
				"range": 110.0,
				"damage": 7.0,
				"kind": "volley",
				"params": {
					"count": 8,
					"pattern": "radial",
					"speed": 240.0,
					"projectile": "knife",
					"color": Color(0.75, 0.78, 0.82),
				},
			},
		],
	},
	"mage": {
		"id": "mage",
		"name": "Mage",
		"title": "Keeper of the Violet Flame",
		"lore": "She copied forbidden ember-script by candlelight until the candle answered back. The town council distrusts her violet fire, yet they knock on her door whenever the dark grows teeth.",
		"sheet": "res://assets/art/characters/npc_female2.png",
		"variant": 3,
		"max_hp": 80.0,
		"max_mana": 120.0,
		"speed": 90.0,
		"hp_regen": 0.6,
		"mana_regen": 8.0,
		"color": Color(0.62, 0.42, 0.78),
		"abilities": [
			{
				"id": "spark",
				"name": "Spark",
				"icon": "res://assets/art/icons/lightning-magenta-1.png",
				"cooldown": 0.5,
				"mana_cost": 0.0,
				"range": 220.0,
				"damage": 9.0,
				"kind": "projectile",
				"params": {
					"speed": 260.0,
					"projectile": "spark",
					"color": Color(0.68, 0.45, 0.85),
				},
			},
			{
				"id": "fireball",
				"name": "Fireball",
				"icon": "res://assets/art/icons/fireball-red-1.png",
				"cooldown": 5.0,
				"mana_cost": 25.0,
				"range": 240.0,
				"damage": 22.0,
				"kind": "projectile",
				"params": {
					"speed": 200.0,
					"projectile": "fireball",
					"aoe_radius": 30.0,
					"color": Color(0.92, 0.55, 0.25),
				},
			},
			{
				"id": "frost_nova",
				"name": "Frost Nova",
				"icon": "res://assets/art/icons/ice-blue-1.png",
				"cooldown": 8.0,
				"mana_cost": 30.0,
				"range": 55.0,
				"damage": 10.0,
				"kind": "aoe_ring",
				"params": {
					"at_aim": false,
					"slow_mult": 0.5,
					"slow_duration": 3.0,
					"color": Color(0.58, 0.76, 0.88),
				},
			},
		],
	},
	"paladin": {
		"id": "paladin",
		"name": "Paladin",
		"title": "Lantern of the Ashen Chapel",
		"lore": "Sworn at the ashen chapel on the hill, he carries the last consecrated hammer left in the Hollow. His faith is quiet, dented, and yet to break.",
		"sheet": "res://assets/art/characters/npc_male1.png",
		"variant": 1,
		"max_hp": 120.0,
		"max_mana": 70.0,
		"speed": 86.0,
		"hp_regen": 1.2,
		"mana_regen": 5.0,
		"color": Color(0.85, 0.68, 0.35),
		"abilities": [
			{
				"id": "hammer_blow",
				"name": "Hammer Blow",
				"icon": "res://assets/art/icons/explosion-orange-1.png",
				"cooldown": 0.6,
				"mana_cost": 0.0,
				"range": 26.0,
				"damage": 11.0,
				"kind": "melee_arc",
				"params": {"arc_degrees": 100.0, "color": Color(0.85, 0.68, 0.35)},
			},
			{
				"id": "consecration",
				"name": "Consecration",
				"icon": "res://assets/art/icons/runes-orange-1.png",
				"cooldown": 9.0,
				"mana_cost": 30.0,
				"range": 45.0,
				"damage": 6.0,
				"kind": "aoe_ring",
				"params": {
					"at_aim": true,
					"cast_range": 110.0,
					"tick_interval": 0.5,
					"duration": 4.0,
					"color": Color(0.90, 0.75, 0.42),
				},
			},
			{
				"id": "divine_shield",
				"name": "Divine Shield",
				"icon": "res://assets/art/icons/protect-orange-2.png",
				"cooldown": 14.0,
				"mana_cost": 25.0,
				"range": 0.0,
				"damage": 0.0,
				"kind": "buff",
				"params": {
					"duration": 6.0,
					"absorb": 40.0,
					"color": Color(0.92, 0.80, 0.45),
				},
			},
		],
	},
	"necromancer": {
		"id": "necromancer",
		"name": "Necromancer",
		"title": "Warden of the Old Graves",
		"lore": "Years tending Raven Hollow's graveyard taught him that the dead make loyal neighbors. He raises them politely, works them briefly, and always tucks them back in.",
		"sheet": "res://assets/art/characters/npc_male3.png",
		"variant": 1,
		"max_hp": 85.0,
		"max_mana": 110.0,
		"speed": 90.0,
		"hp_regen": 0.7,
		"mana_regen": 7.0,
		"color": Color(0.45, 0.72, 0.35),
		"abilities": [
			{
				"id": "soul_bolt",
				"name": "Soul Bolt",
				"icon": "res://assets/art/icons/fireball-acid-1.png",
				"cooldown": 0.55,
				"mana_cost": 0.0,
				"range": 220.0,
				"damage": 10.0,
				"kind": "projectile",
				"params": {
					"speed": 220.0,
					"projectile": "orb",
					"color": Color(0.55, 0.80, 0.38),
				},
			},
			{
				"id": "raise_dead",
				"name": "Raise Dead",
				"icon": "res://assets/art/icons/horror-acid-1.png",
				"cooldown": 12.0,
				"mana_cost": 35.0,
				"range": 80.0,
				"damage": 0.0,
				"kind": "summon",
				"params": {
					"minion_type": "skeleton",
					"lifetime": 20.0,
					"minion_hp": 35.0,
					"minion_damage": 6.0,
					"minion_speed": 75.0,
					"color": Color(0.50, 0.72, 0.40),
				},
			},
			{
				"id": "grave_grasp",
				"name": "Grave Grasp",
				"icon": "res://assets/art/icons/wind-grasp-eerie-1.png",
				"cooldown": 8.0,
				"mana_cost": 25.0,
				"range": 40.0,
				"damage": 12.0,
				"kind": "aoe_ring",
				"params": {
					"at_aim": true,
					"cast_range": 120.0,
					"root_duration": 1.5,
					"color": Color(0.58, 0.38, 0.66),
				},
			},
		],
	},
	"rookwarden": {
		"id": "rookwarden",
		"name": "Hunter",
		"title": "Rookwarden of the Hollow",
		"lore": "The rooks of the Hollow choose one warden a generation, and they chose him at the gallows-tree. His arrows fly where the ravens point, and the ravens are never wrong.",
		"sheet": "res://assets/art/characters/npc_male2.png",
		"variant": 0,
		"max_hp": 95.0,
		"max_mana": 80.0,
		"speed": 98.0,
		"hp_regen": 0.9,
		"mana_regen": 6.0,
		"color": Color(0.24, 0.48, 0.50),
		"abilities": [
			{
				"id": "loosed_arrow",
				"name": "Loosed Arrow",
				"icon": "res://assets/art/icons/fire-arrows-sky-1.png",
				"cooldown": 0.45,
				"mana_cost": 0.0,
				"range": 260.0,
				"damage": 10.0,
				"kind": "projectile",
				"params": {
					"speed": 320.0,
					"projectile": "arrow",
					"thin": true,
					"color": Color(0.76, 0.72, 0.60),
				},
			},
			{
				"id": "raven_dash",
				"name": "Raven Dash",
				"icon": "res://assets/art/icons/haste-sky-1.png",
				"cooldown": 5.0,
				"mana_cost": 10.0,
				"range": 80.0,
				"damage": 0.0,
				"kind": "dash",
				"params": {"feathers": true, "color": Color(0.30, 0.54, 0.56)},
			},
			{
				"id": "arrow_storm",
				"name": "Arrow Storm",
				"icon": "res://assets/art/icons/fire-arrows-sky-3.png",
				"cooldown": 9.0,
				"mana_cost": 30.0,
				"range": 140.0,
				"damage": 8.0,
				"kind": "volley",
				"params": {
					"count": 10,
					"pattern": "rain",
					"radius": 45.0,
					"duration": 1.2,
					"speed": 300.0,
					"projectile": "arrow",
					"color": Color(0.34, 0.54, 0.58),
				},
			},
		],
	},
}


static func all_ids() -> Array[String]:
	var ids: Array[String] = [
		"warrior", "rogue", "mage", "paladin", "necromancer", "rookwarden",
	]
	return ids


## Returns a deep copy so callers may annotate it with runtime state without
## touching the read-only constants. Unknown ids warn and fall back to warrior.
static func get_def(id: String) -> Dictionary:
	if not _DEFS.has(id):
		push_warning("ClassDefs.get_def: unknown class id '%s', using warrior" % id)
		return (_DEFS["warrior"] as Dictionary).duplicate(true)
	return (_DEFS[id] as Dictionary).duplicate(true)


## Convenience: loads the icon Texture2D for an ability dictionary.
static func icon_texture(ability: Dictionary) -> Texture2D:
	var path: String = str(ability.get("icon", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
