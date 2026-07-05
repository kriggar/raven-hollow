class_name FXLib
extends Object
## Animated sprite-sheet effect library for Raven Hollow: Emberfall.
## Sheets live in res://assets/art/vfx/ (see CREDITS_VFX.txt); every frame
## geometry below was pixel-verified (alpha-occupancy + visual crop review).
## SpriteFrames are built lazily, once per id, and cached for the session.
##
## API:
##   play(id, parent, pos, opts) -> Node2D
##       One-shot effects auto-free on animation_finished; looping ids fade
##       out and free after opts "duration" (default 1.0 s).
##       opts: "rotation" (rad), "flip" (flip_v), "flip_h", "tint" (Color),
##             "scale" (float or Vector2), "speed" (anim speed mult),
##             "duration" (loop lifetime s), "z" (z_index),
##             "offset" (Vector2, pre-scale sprite offset — used to
##             bottom-anchor sheets whose art hangs from the frame bottom).
##   attach_loop(id, target, offset) -> Node2D
##       Looping aura parented to `target`; the CALLER frees it.
##   projectile_frames(id) -> SpriteFrames
##       Flight loop for projectile visuals (Combat.Projectile).
##
## Ability -> fx-id map (all flight loops face +X, rotate with dir.angle()):
##   fireball      projectile "firebolt_fly"; "firebolt_impact", "fire_explosion"
##   spark         projectile "spark_fly"; hit "spark_hit"
##   frost_nova    "frost_start" -> loop "frost_active" -> "frost_end"
##   soul_bolt     projectile "soul_fly"; hit "soul_hit"
##   raise_dead    loop "summon_circle" + "dark_rise" + "smoke_poof"
##   grave_grasp   "roots" (tint grave-purple)
##   consecration  "holy_pillar" on cast + loop "holy_loop" glyph
##   divine_shield loop "holy_loop" around the player
##   hammer_blow   "hit_spark" + "dust"
##   cleave/slash  "smear" (rotate to aim, tint class color)
##   whirlwind     "air_swirl" (rotating shred)
##   war_cry       "air_burst" (tint red-gold)
##   shadowstep    "smoke_puff"/"smoke_poof" (tint near-black)
##   fan_of_knives projectile "blade_spin" (spinning smear blade)
##   loosed_arrow  trail "wind_crescent"; hit "wind_hit"
##   arrow_storm   projectile "magic_arrow"; landing "spark_hit"
##   enemy hit     "hit_spark"; deaths "smoke_poof"

const _VFX_DIR := "res://assets/art/vfx/"

## id -> {sheet, fw, fh, from, to (inclusive, row-major), fps, loop}
const _DEFS: Dictionary = {
	# -- fire (Pimen Fire 01 / 02) --------------------------------------
	"firebolt_fly": {"sheet": _VFX_DIR + "foozle/fireball_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 4, "fps": 14.0, "loop": true},
	"firebolt_impact": {"sheet": _VFX_DIR + "foozle/fireball_64x64.png", "fw": 64, "fh": 64, "from": 5, "to": 9, "fps": 16.0, "loop": false},
	"fire_explosion": {"sheet": _VFX_DIR + "foozle/fireball_64x64.png", "fw": 64, "fh": 64, "from": 5, "to": 9, "fps": 16.0, "loop": false},
	# -- thunder (Pimen Thunder 01) -------------------------------------
	"spark_fly": {"sheet": _VFX_DIR + "pimen_thunder/projectile_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 4, "fps": 15.0, "loop": true},
	"spark_hit": {"sheet": _VFX_DIR + "pimen_thunder/hit_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 4, "fps": 15.0, "loop": false},
	# -- ice (Pimen Ice 01, 'Ice VFX 2' ground frost) --------------------
	"frost_start": {"sheet": _VFX_DIR + "pimen_ice/frost_start_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 7, "fps": 14.0, "loop": false},
	"frost_active": {"sheet": _VFX_DIR + "pimen_ice/frost_active_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 7, "fps": 10.0, "loop": true},
	"frost_end": {"sheet": _VFX_DIR + "pimen_ice/frost_end_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 16, "fps": 14.0, "loop": false},
	# -- dark (Pimen Dark VFX 1 / 2) ------------------------------------
	"soul_fly": {"sheet": _VFX_DIR + "pimen_dark/dark1_40x32.png", "fw": 40, "fh": 32, "from": 0, "to": 9, "fps": 14.0, "loop": true},
	"soul_hit": {"sheet": _VFX_DIR + "pimen_dark/dark1_40x32.png", "fw": 40, "fh": 32, "from": 10, "to": 15, "fps": 14.0, "loop": false},
	"dark_rise": {"sheet": _VFX_DIR + "pimen_dark/dark2_48x64.png", "fw": 48, "fh": 64, "from": 0, "to": 14, "fps": 14.0, "loop": false},
	# -- holy (Pimen Holy 01 / 02) --------------------------------------
	"holy_loop": {"sheet": _VFX_DIR + "pimen_holy/holy01_repeat_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 7, "fps": 12.0, "loop": true},
	"holy_pillar": {"sheet": _VFX_DIR + "pimen_holy/holy02_pillar_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 14, "fps": 16.0, "loop": false},
	# -- melee / generic hits (Pimen) ------------------------------------
	"hit_spark": {"sheet": _VFX_DIR + "pimen_hit/hit_spark_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 5, "fps": 18.0, "loop": false},
	"smear": {"sheet": _VFX_DIR + "pimen_smear/smear_h_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 4, "fps": 20.0, "loop": false},
	"blade_spin": {"sheet": _VFX_DIR + "pimen_smear/smear_h_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 4, "fps": 24.0, "loop": true},
	# -- smoke & dust (Pimen Smoke 01 / Smoke N Dust 03) -----------------
	"smoke_puff": {"sheet": _VFX_DIR + "pimen_smoke/puff_48x32.png", "fw": 48, "fh": 32, "from": 0, "to": 7, "fps": 14.0, "loop": false},
	"smoke_poof": {"sheet": _VFX_DIR + "pimen_smoke/poof_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 10, "fps": 14.0, "loop": false},
	"dust": {"sheet": _VFX_DIR + "pimen_smoke/dust_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 7, "fps": 12.0, "loop": false},
	# -- wind (Pimen Wind 01 / 02) ---------------------------------------
	"wind_crescent": {"sheet": _VFX_DIR + "foozle/wind_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 5, "fps": 18.0, "loop": true},
	"wind_hit": {"sheet": _VFX_DIR + "foozle/wind_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 9, "fps": 18.0, "loop": false},
	"air_burst": {"sheet": _VFX_DIR + "pimen_wind/air_burst_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 6, "fps": 14.0, "loop": false},
	"air_swirl": {"sheet": _VFX_DIR + "pimen_wind/air_swirl_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 8, "fps": 16.0, "loop": false},
	# -- wood roots (Pimen Wood 02) ---------------------------------------
	"roots": {"sheet": _VFX_DIR + "pimen_wood/roots_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 12, "fps": 14.0, "loop": false},
	# -- necromancer summon (Frostwindz VFX 1) ----------------------------
	"summon_circle": {"sheet": _VFX_DIR + "frostwindz_necro/summon_ellipse_128x128.png", "fw": 128, "fh": 128, "from": 0, "to": 8, "fps": 10.0, "loop": true},
	# -- magic arrows (XYEzawr, re-assembled strip) ------------------------
	"magic_arrow": {"sheet": _VFX_DIR + "xyezawr_arrows/magic_arrow_blue_59x28.png", "fw": 59, "fh": 28, "from": 0, "to": 14, "fps": 20.0, "loop": true},
	# -- Phase D spell-kit dedicated sheets (see CREDITS_VFX.txt) -----------
	# earth quake rock burst (earthshaker + bone_nova, re-tinted) — 6x2 grid
	"quake_rock": {"sheet": _VFX_DIR + "foozle/rocks_64x64.png", "fw": 64, "fh": 64, "from": 0, "to": 9, "fps": 16.0, "loop": false},
	# acid splash burst (venom_cloud) — Hit frames only
	"acid_hit": {"sheet": _VFX_DIR + "acid_spell/acid_hit_32x32.png", "fw": 32, "fh": 32, "from": 0, "to": 5, "fps": 14.0, "loop": false},
	# rotating protection ward LOOP (iron_bulwark) — 8x8 grid, 61 live frames
	"protection_ward": {"sheet": _VFX_DIR + "codemanu/protection_ward_100x100.png", "fw": 100, "fh": 100, "from": 0, "to": 60, "fps": 12.0, "loop": true},
	# spherical shield bubble LOOP (holy_dome)
	"ward_bubble": {"sheet": _VFX_DIR + "devwizard/ward_bubble_48x48.png", "fw": 48, "fh": 48, "from": 0, "to": 5, "fps": 10.0, "loop": true},
	# radiant holy pillar burst (dawnbreak_pillar)
	"dawnbreak_big": {"sheet": _VFX_DIR + "frostwindz_priest/dawnbreak_pillar_128x128.png", "fw": 128, "fh": 128, "from": 0, "to": 10, "fps": 14.0, "loop": false},
	# rotating bone/rune shell LOOP (bone_ward)
	"necro_shell": {"sheet": _VFX_DIR + "frostwindz_necro/necro_shell_128x128.png", "fw": 128, "fh": 128, "from": 0, "to": 8, "fps": 12.0, "loop": true},
	# soft golden heal bloom (holy_bloom gold + heal_bloom green)
	"heal_bloom_base": {"sheet": _VFX_DIR + "frostwindz_priest/heal_bloom_128x128.png", "fw": 128, "fh": 128, "from": 0, "to": 7, "fps": 14.0, "loop": false},
	# -- ROGUE SPELL KIT (BACKLOG #83/#56): ComfyUI-generated + authored motion, each UNIQUE,
	# gothic venom/violet/steel palette, gridcut-perfect 96x96 cells (tools/assets/rogue_vfx.py).
	# Sheets are PRE-COLOURED -> play() strips any incoming tint for rogue_* ids (see below).
	"rogue_backstab": {"sheet": _VFX_DIR + "rogue_kit/backstab.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 20.0, "loop": false},
	"rogue_poison_blade": {"sheet": _VFX_DIR + "rogue_kit/poison_blade.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 14.0, "loop": false},
	"rogue_fan_of_knives": {"sheet": _VFX_DIR + "rogue_kit/fan_of_knives.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 18.0, "loop": false},
	"rogue_vanish": {"sheet": _VFX_DIR + "rogue_kit/vanish.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 16.0, "loop": false},
	"rogue_shadowstep": {"sheet": _VFX_DIR + "rogue_kit/shadowstep.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 20.0, "loop": false},
	"rogue_deathmark": {"sheet": _VFX_DIR + "rogue_kit/deathmark.png", "fw": 96, "fh": 96, "from": 0, "to": 7, "fps": 16.0, "loop": false},
}

## Ability-id aliases: gameplay code (class_defs params.fx / fx_loop) plays
## ABILITY ids; each resolves to a base sheet id plus default opts that size
## and tint the sheet for that ability. Caller opts always win the merge.
const _ALIASES: Dictionary = {
	"cleave": {"id": "smear", "opts": {}},
	"quick_slash": {"id": "smear", "opts": {"scale": 0.85, "speed": 1.25}},
	# air_swirl's native art is leaf-green; desaturate toward warrior red-steel.
	"whirlwind": {"id": "air_swirl", "opts": {"scale": 2.4, "speed": 1.15, "tint": Color(0.95, 0.62, 0.48)}},
	"war_cry": {"id": "air_burst", "opts": {"scale": 1.9}},
	"shadowstep": {"id": "rogue_shadowstep", "opts": {"scale": 1.05}},   # violet dash smoke trail
	"grave_grasp": {"id": "roots", "opts": {"scale": 2.4}},
	# holy_pillar / dark_rise art hangs from the frame BOTTOM (PIL: pillar base
	# y≈46-47 of 48, wisp starts y≈56-64 of 64) — the "offset" bottom-anchors
	# them so the burst base / wisp root sits AT the cast ground point.
	"consecration": {"id": "holy_pillar", "opts": {"scale": 1.7, "offset": Vector2(0.0, -23.0)}},
	# holy_loop's native flame points +X: rotate -PI/2 so it licks upward
	# (matches vfx.gd sparkle_buff) instead of lying sideways.
	"consecration_loop": {"id": "holy_loop", "opts": {"scale": 2.6, "rotation": -PI / 2.0, "tint": Color(1.0, 0.88, 0.55, 0.85)}},
	"divine_shield": {"id": "holy_loop", "opts": {"scale": 1.25, "rotation": -PI / 2.0, "tint": Color(1.0, 0.9, 0.6, 0.85)}},
	"raise_dead": {"id": "dark_rise", "opts": {"scale": 1.15, "offset": Vector2(0.0, -30.0)}},
	"raise_dead_loop": {"id": "summon_circle", "opts": {"scale": 0.55}},
	"raven_dash": {"id": "smoke_puff", "opts": {"scale": 1.25, "tint": Color(0.30, 0.42, 0.44, 0.85)}},
	# Projectile-ability ids double as their IMPACT effect (Combat.Projectile).
	"spark": {"id": "spark_hit", "opts": {}},
	"fireball": {"id": "fire_explosion", "opts": {}},
	"soul_bolt": {"id": "soul_hit", "opts": {}},
	"loosed_arrow": {"id": "wind_hit", "opts": {"scale": 0.55}},
	"fan_of_knives": {"id": "rogue_fan_of_knives", "opts": {"scale": 1.15}},   # radial steel blade burst
	# Landing impact = thunder hit per the effect mapping (the magic_arrow
	# strip is the FLIGHT visual and would lie flat at the hit point).
	"arrow_storm": {"id": "spark_hit", "opts": {}},
	# --- Spell-kit aliases (per-ability fx, class-tinted; plan §2b/§2a) -------
	# Warrior
	"shield_charge": {"id": "dust", "opts": {"scale": 0.9, "tint": Color(0.66, 0.58, 0.48)}},
	"sunder": {"id": "hit_spark", "opts": {"tint": Color(0.92, 0.62, 0.50)}},
	"iron_bulwark": {"id": "protection_ward", "opts": {"scale": 0.85, "z": 1, "tint": Color(0.62, 0.66, 0.70, 0.9)}},  # cold iron rune ward (codemanu protection circle)
	"earthshaker": {"id": "quake_rock", "opts": {"scale": 1.6, "tint": Color(0.66, 0.50, 0.40)}},  # earth quake rock burst
	# Rogue -- dedicated ComfyUI rogue-kit sheets (pre-coloured; tint auto-stripped in play()).
	"backstab": {"id": "rogue_backstab", "opts": {"scale": 0.95}},          # crit slash arc + blood spark
	"shroud": {"id": "rogue_vanish", "opts": {"scale": 1.0}},               # violet smoke-puff vanish
	"venom_cloud": {"id": "rogue_poison_blade", "opts": {"scale": 1.0}},    # venom blade coat + drip
	"deathmark": {"id": "rogue_deathmark", "opts": {"scale": 1.05}},        # violet mark -> blood execute
	"death_blossom": {"id": "blade_spin", "opts": {"scale": 1.4, "speed": 1.2, "duration": 0.6, "tint": Color(0.72, 0.34, 0.34)}},
	# Mage
	"ice_lance": {"id": "frost_start", "opts": {"tint": Color(0.55, 0.72, 0.86)}},
	"flame_strike": {"id": "fire_explosion", "opts": {"tint": Color(0.86, 0.40, 0.20)}},
	"cinderfall": {"id": "fire_explosion", "opts": {"tint": Color(0.90, 0.46, 0.20)}},
	"blink": {"id": "smoke_puff", "opts": {"scale": 1.1, "tint": Color(0.64, 0.42, 0.82)}},
	"mana_shield": {"id": "frost_start", "opts": {"tint": Color(0.60, 0.55, 0.88)}},
	# Paladin (heal_bloom_base #4 not yet drawn — holy_bloom is its gold interim)
	"holy_smite": {"id": "hit_spark", "opts": {"tint": Color(0.92, 0.82, 0.50)}},
	"holy_bloom": {"id": "heal_bloom_base", "opts": {"scale": 0.62, "offset": Vector2(0.0, -12.0), "tint": Color(1.0, 0.90, 0.60)}},  # gold heal bloom (priest VFX1)
	"holy_dome": {"id": "ward_bubble", "opts": {"scale": 1.5, "z": 1, "tint": Color(0.95, 0.80, 0.45, 0.9)}},  # golden dome bubble (devwizard shield)
	"dawnbreak_pillar": {"id": "dawnbreak_big", "opts": {"scale": 1.15, "offset": Vector2(0.0, -48.0), "tint": Color(1.0, 0.94, 0.66)}},  # radiant holy pillar (priest VFX2)
	# Necromancer
	"drain_life": {"id": "soul_hit", "opts": {"tint": Color(0.58, 0.40, 0.66)}},
	"withering_curse": {"id": "dark_rise", "opts": {"scale": 1.15, "offset": Vector2(0.0, -30.0), "tint": Color(0.52, 0.66, 0.34)}},
	"bone_armor": {"id": "dark_rise", "opts": {"scale": 1.15, "offset": Vector2(0.0, -30.0), "tint": Color(0.62, 0.70, 0.52)}},
	"soul_harvest": {"id": "soul_hit", "opts": {"tint": Color(0.48, 0.74, 0.42)}},
	"bone_nova": {"id": "quake_rock", "opts": {"scale": 1.4, "tint": Color(0.82, 0.80, 0.72)}},  # bone-shard burst (rock sheet, bone tint)
	"bone_ward": {"id": "necro_shell", "opts": {"scale": 0.6, "tint": Color(0.62, 0.70, 0.52, 0.9)}},  # rotating bone/rune shell (necro VFX1)
	# Hunter (rookwarden)
	"piercing_shot": {"id": "wind_hit", "opts": {"tint": Color(0.72, 0.74, 0.64)}},
	"snare_trap": {"id": "roots", "opts": {"scale": 2.4, "tint": Color(0.42, 0.56, 0.32)}},
	"hunters_mark": {"id": "air_burst", "opts": {"scale": 1.6, "tint": Color(0.60, 0.68, 0.44)}},
	"rook_companion": {"id": "smoke_poof", "opts": {"scale": 0.5, "tint": Color(0.40, 0.42, 0.50)}},
	"rook_companion_loop": {"id": "summon_circle", "opts": {"scale": 0.5, "tint": Color(0.28, 0.44, 0.48, 0.85)}},
	"storm_of_feathers": {"id": "spark_hit", "opts": {"tint": Color(0.24, 0.34, 0.40)}},
	# Druid (heal_bloom shares heal_bloom_base #4 — green interim over holy_pillar)
	"maul": {"id": "smear", "opts": {"tint": Color(0.55, 0.62, 0.40)}},
	"gale": {"id": "air_burst", "opts": {"scale": 1.3, "tint": Color(0.62, 0.78, 0.60)}},
	"thornroot": {"id": "roots", "opts": {"scale": 2.4, "tint": Color(0.42, 0.52, 0.28)}},
	"stormbolt": {"id": "spark_hit", "opts": {"tint": Color(0.70, 0.80, 0.92)}},
	"heal_bloom": {"id": "heal_bloom_base", "opts": {"scale": 0.62, "offset": Vector2(0.0, -12.0), "tint": Color(0.50, 0.80, 0.45)}},  # green heal bloom (priest VFX1)
	"spirit_beast": {"id": "dark_rise", "opts": {"scale": 1.15, "offset": Vector2(0.0, -30.0), "tint": Color(0.55, 0.70, 0.50)}},
	"spirit_beast_loop": {"id": "summon_circle", "opts": {"scale": 0.55, "tint": Color(0.55, 0.70, 0.50, 0.85)}},
	"bear_form": {"id": "air_burst", "opts": {"scale": 1.6, "tint": Color(0.55, 0.42, 0.28)}},
	"tempest": {"id": "spark_hit", "opts": {"tint": Color(0.62, 0.72, 0.86)}},
}

## Multi-sheet ability composites handled by dedicated helpers in play().
const _COMPOSITES: Array[String] = ["hammer_blow", "frost_nova"]

const _FROST_START_LEN: float = 8.0 / 14.0    # frames 0-7 @ 14 fps
const _FROST_END_LEN: float = 17.0 / 14.0     # frames 0-16 @ 14 fps

static var _frames_cache: Dictionary = {}
static var _sheet_cache: Dictionary = {}


static func has_fx(id: String) -> bool:
	return _DEFS.has(id) or _ALIASES.has(id) or _COMPOSITES.has(id)


## Base sheet id + opts (alias defaults under the caller's) for any public id.
static func _resolve(id: String, opts: Dictionary) -> Array:
	if not _ALIASES.has(id):
		return [id, opts]
	var alias: Dictionary = _ALIASES[id]
	var merged: Dictionary = (alias["opts"] as Dictionary).duplicate()
	merged.merge(opts, true)
	return [str(alias["id"]), merged]


## One-shot (auto-frees) or timed loop (frees after opts "duration").
static func play(id: String, parent: Node2D, pos: Vector2, opts: Dictionary = {}) -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null
	match id:
		"hammer_blow":
			return _play_hammer_blow(parent, pos, opts)
		"frost_nova":
			return _play_frost_nova(parent, pos, opts)
	var resolved: Array = _resolve(id, opts)
	id = str(resolved[0])
	opts = resolved[1] as Dictionary
	# Rogue-kit sheets are already colour-authored (venom/violet/steel) — a caller fx_tint
	# would multiply and muddy them, so it is dropped for these pre-coloured ids.
	if id.begins_with("rogue_"):
		opts.erase("tint")
	var frames: SpriteFrames = _get_frames(id)
	if frames.get_frame_count(&"fx") == 0:
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.animation = &"fx"
	spr.position = pos
	_apply_opts(spr, opts)
	parent.add_child(spr)
	spr.play(&"fx")
	if frames.get_animation_loop(&"fx"):
		var life: float = maxf(0.1, float(opts.get("duration", 1.0)))
		var t := spr.create_tween()
		t.tween_interval(maxf(life - 0.15, 0.05))
		t.tween_property(spr, "modulate:a", 0.0, 0.15)
		t.tween_callback(spr.queue_free)
	else:
		spr.animation_finished.connect(spr.queue_free)
	return spr


## Looping aura parented to `target`. The caller owns and frees the node
## (or it dies with the target). Cheap: one AnimatedSprite2D, no tweens.
static func attach_loop(id: String, target: Node2D, offset: Vector2 = Vector2.ZERO) -> Node2D:
	if target == null or not is_instance_valid(target):
		return null
	var resolved: Array = _resolve(id, {})
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _get_frames(str(resolved[0]))
	spr.position = offset
	_apply_opts(spr, resolved[1] as Dictionary)
	target.add_child(spr)
	if spr.sprite_frames.get_frame_count(&"fx") > 0:
		spr.play(&"fx")
	return spr


## Flight-loop SpriteFrames for projectile visuals; native facing is +X.
## Takes BASE sheet ids only (e.g. "firebolt_fly", "spark_fly") — ability
## aliases deliberately do NOT resolve here, because they map ability ids to
## their IMPACT sheets (see _ALIASES), which are wrong for a flight loop.
static func projectile_frames(id: String) -> SpriteFrames:
	return _get_frames(id)


## Detached AnimatedSprite2D already playing `id` — for callers composing
## their own effect roots (e.g. VFX.projectile_visual).
static func make_sprite(id: String) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _get_frames(str(_resolve(id, {})[0]))
	spr.animation = &"fx"
	if spr.sprite_frames.get_frame_count(&"fx") > 0:
		spr.play(&"fx")
	return spr


# --- Ability composites (multiple sheets per cast) --------------------------


## Hammer Blow: Pimen hit spark + earth dust + a brief gold holy flash.
static func _play_hammer_blow(parent: Node2D, pos: Vector2, opts: Dictionary) -> Node2D:
	play("dust", parent, pos + Vector2(0.0, 2.0), {"scale": 0.7, "speed": 1.2})
	play("holy_loop", parent, pos + Vector2(0.0, -4.0), {
		"duration": 0.35,
		"scale": 1.2,
		"tint": Color(1.0, 0.87, 0.5, 0.85),
	})
	return play("hit_spark", parent, pos, {
		"rotation": float(opts.get("rotation", 0.0)),
		"scale": float(opts.get("scale", 0.9)),
		"tint": opts.get("tint", Color(1.0, 0.92, 0.72)),
	})


## Frost Nova: ground frost sequence start -> active loop -> ending, staged
## on a self-freeing holder so the three sheets read as one bloom.
static func _play_frost_nova(parent: Node2D, pos: Vector2, opts: Dictionary) -> Node2D:
	var sc: float = float(opts.get("scale", 3.2))
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = int(opts.get("z", -1))
	parent.add_child(holder)
	play("frost_start", holder, Vector2.ZERO, {"scale": sc})
	var t := holder.create_tween()
	t.tween_interval(_FROST_START_LEN)
	t.tween_callback(func() -> void:
		play("frost_active", holder, Vector2.ZERO, {"scale": sc, "duration": 1.0}))
	t.tween_interval(0.95)
	t.tween_callback(func() -> void:
		play("frost_end", holder, Vector2.ZERO, {"scale": sc}))
	t.tween_interval(_FROST_END_LEN + 0.1)
	t.tween_callback(holder.queue_free)
	return holder


static func _apply_opts(spr: AnimatedSprite2D, opts: Dictionary) -> void:
	spr.rotation = float(opts.get("rotation", 0.0))
	spr.flip_v = bool(opts.get("flip", false))
	spr.flip_h = bool(opts.get("flip_h", false))
	var tint: Variant = opts.get("tint")
	if tint is Color:
		spr.modulate = tint
	var off: Variant = opts.get("offset")
	if off is Vector2:
		spr.offset = off  # pre-scale, frame-local px (bottom-anchoring)
	var sc: Variant = opts.get("scale", 1.0)
	spr.scale = sc if sc is Vector2 else Vector2.ONE * float(sc)
	spr.speed_scale = maxf(0.05, float(opts.get("speed", 1.0)))
	spr.z_index = int(opts.get("z", 0))


static func _get_frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("fx")
	if not _DEFS.has(id):
		push_warning("FXLib: unknown fx id '%s'" % id)
		_frames_cache[id] = sf
		return sf
	var def: Dictionary = _DEFS[id]
	var tex: Texture2D = _sheet(str(def["sheet"]))
	if tex == null:
		_frames_cache[id] = sf
		return sf
	var fw: int = int(def["fw"])
	var fh: int = int(def["fh"])
	var cols: int = maxi(1, int(float(tex.get_width()) / float(maxi(1, fw))))
	sf.set_animation_speed("fx", float(def["fps"]))
	sf.set_animation_loop("fx", bool(def["loop"]))
	for i in range(int(def["from"]), int(def["to"]) + 1):
		var col: int = i % cols
		var row: int = int(float(i) / float(cols))
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(float(col * fw), float(row * fh), float(fw), float(fh))
		sf.add_frame("fx", at)
	_frames_cache[id] = sf
	return sf


static func _sheet(path: String) -> Texture2D:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("FXLib: missing sheet '%s'" % path)
	_sheet_cache[path] = tex
	return tex
