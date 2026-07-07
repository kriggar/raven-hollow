class_name SpellVFX
extends Object
## SpellVFX — the GPUParticles2D "AAA engine VFX" seam for Raven Hollow's spell
## kit (design/VFX_PIPELINE.md: projectile core = procedural in-shader palettized
## fire/energy on GPUParticles2D, the strongest $0 path under the ZERO-PURCHASE
## LAW). FXLib.play() consults SpellVFX.has_fx(id) FIRST and, for any id this
## class owns, hands the effect to SpellVFX.play() instead of the sprite-sheet
## path (fx_library.gd:235).
##
## STATUS: this is the integration point, deliberately EMPTY of registered ids
## right now — has_fx() returns false for every id, so FXLib falls through to its
## existing sprite-sheet + composite path for ALL current effects (identical
## behaviour to before this class existed; it only unbreaks compilation, since
## fx_library.gd referenced SpellVFX but the file was absent). As individual
## spells are rebuilt on the GPUParticles2D lane, register their id in _FX and
## add a builder — FXLib will then route them here with no change at the call
## site. Purely visual; no gameplay state; every effect must self-free.

## id -> builder Callable(parent: Node2D, pos: Vector2, opts: Dictionary) -> Node2D.
## Empty until the first spell is migrated to the engine-VFX lane.
const _FX: Dictionary = {}


## True only for ids this class owns. While _FX is empty this is always false,
## so FXLib keeps using its sprite-sheet path for every effect.
static func has_fx(id: String) -> bool:
	return _FX.has(id)


## Play the engine VFX for `id` at `pos` under `parent`. Returns the spawned
## node (self-freeing) or null. Never reached for an id has_fx() rejects, so the
## empty-registry case cannot run — but stays null-safe regardless.
static func play(id: String, parent: Node2D, pos: Vector2, opts: Dictionary = {}) -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var builder_v: Variant = _FX.get(id)
	if builder_v is Callable and (builder_v as Callable).is_valid():
		var out: Variant = (builder_v as Callable).call(parent, pos, opts)
		return out as Node2D
	return null
