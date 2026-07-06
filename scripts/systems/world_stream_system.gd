extends Node
## WorldStreamSystem (autoload) — SEAMLESS WORLD edge-streaming (BLUEPRINT_98).
##
## Replaces the fade-to-black change_map at BORDER seams with continuous
## edge-streaming: as the player nears a seam travel point, the adjacent zone
## is pre-built OFF-SCREEN at a world offset so its border gap lines up with
## ours; the player walks across; ownership flips (one imperceptible frame);
## the zone behind unloads once fully crossed. Fast travel / ferry / cellar
## stairs KEEP the fade (they are jumps, and their points have no reciprocal
## edge gap so seam_offset() declines them).
##
## SAFETY / FALLBACK CONTRACT (non-negotiable):
##  * GATED. Nothing here runs unless `enabled` is true (set from the RH_SEAMLESS
##    env, or toggled explicitly). With it OFF the game behaves EXACTLY as today.
##  * GUARANTEED FALLBACK. If a seam cannot be streamed (no valid offset, target
##    not a built ZoneBuilder zone, a build fails), the streamer simply declines
##    the seam and main.gd's normal travel-point [E] -> change_map(fade) path
##    handles it. The game is never worse than today.
##  * The existing change_map / TravelSystem code is untouched by this file; the
##    only main.gd coupling is a set of small stream_* helper methods it calls.
##
## Driven by main._physics_process -> WorldStreamSystem.tick(main, player_pos).

# --- tuning ------------------------------------------------------------------
const PRELOAD_DISTANCE: float = 1200.0   # px from the seam point: start pre-build
const RETREAT_DISTANCE: float = 1700.0   # px: player walked away -> drop neighbor
const UNLOAD_HYSTERESIS: float = 800.0   # px past the seam: free the zone behind
const GAP_TOLERANCE: float = 28.0        # perpendicular slack on the gap span
const FLIP_MARGIN: float = 12.0          # px past the line before a flip (anti-thrash dead-band)
const FLIP_COOLDOWN_FRAMES: int = 18     # no second flip for this many frames after one (anti-thrash)

# --- state -------------------------------------------------------------------
var enabled: bool = false

var _neighbor_root: Node2D = null        # the OTHER zone (ahead pre-flip / behind post-flip)
var _neighbor_id: String = ""
var _neighbor_built: Dictionary = {}
var _neighbor_ready: bool = false        # async build finished?
var _building: bool = false
var _crossed: bool = false               # false: neighbor is ahead; true: neighbor is behind

# Seam geometry in WORLD coordinates (shifted on every flip so it stays valid).
var _axis: String = "x"                  # crossing axis
var _line: float = 0.0                   # boundary coordinate along the axis
var _toward: float = 1.0                 # sign from current zone toward neighbor
var _gap_lo: float = 0.0                 # perpendicular gap span (world)
var _gap_hi: float = 0.0
var _seam_point: String = ""             # the current-zone travel point id being streamed
var _seam_tp_pos: Vector2 = Vector2.ZERO

var _flipping: bool = false
var _flip_cooldown: int = 0              # frames remaining before another flip is allowed


func _ready() -> void:
	# Gate: OFF by default. RH_SEAMLESS turns streaming on for QA / opt-in.
	if not OS.get_environment("RH_SEAMLESS").is_empty():
		enabled = true
		print("[SEAMLESS] WorldStreamSystem ENABLED (RH_SEAMLESS)")


## Clear all streaming state and free any pre-built neighbor. Call on
## change_map / quit-to-menu so streaming never leaks a stale root.
func reset() -> void:
	if _neighbor_root != null and is_instance_valid(_neighbor_root):
		_neighbor_root.queue_free()
	_neighbor_root = null
	_neighbor_id = ""
	_neighbor_built = {}
	_neighbor_ready = false
	_building = false
	_crossed = false
	_seam_point = ""
	_flipping = false
	_flip_cooldown = 0


## Whether streaming currently OWNS a given travel point of `map_id` (so main.gd
## can suppress the manual [E] prompt for it). Returns false unless a valid seam
## offset exists AND streaming is engaged for that exact point — otherwise the
## normal fade path stays fully in charge (the guaranteed fallback).
func owns_seam(map_id: String, point_id: String) -> bool:
	if not enabled:
		return false
	if _neighbor_root != null and _seam_point == point_id and not _crossed:
		return true
	# Not engaged yet: only claim it if it is genuinely streamable.
	if _neighbor_root != null:
		return false
	var seam: Dictionary = ZoneDefs.seam_offset(map_id, point_id)
	return bool(seam.get("valid", false))


# =============================================================================
# TICK — called every physics frame from main (only when enabled)
# =============================================================================
func tick(main: Node, player_pos: Vector2) -> void:
	if not enabled or main == null or _flipping:
		return
	if not is_instance_valid(main) or main.get("current_map_id") == null:
		return
	if _flip_cooldown > 0:
		_flip_cooldown -= 1

	# Neighbor exists: watch for cross / retreat / unload.
	if _neighbor_root != null:
		if not is_instance_valid(_neighbor_root):
			reset()
			return
		if not _neighbor_ready:
			return  # still building; wait (a build is ~sub-second)
		_check_cross(main, player_pos)
		return

	# No neighbor: scan the current zone's seam points for an approach.
	_scan_for_seam(main, player_pos)


# --- approach scan -----------------------------------------------------------
func _scan_for_seam(main: Node, player_pos: Vector2) -> void:
	var cur: String = str(main.get("current_map_id"))
	var best_pid: String = ""
	var best_seam: Dictionary = {}
	var best_d: float = PRELOAD_DISTANCE
	for tp_v: Variant in MapRegistry.travel_points(cur):
		var tp: Dictionary = tp_v
		var pid: String = str(tp.get("id", ""))
		var seam: Dictionary = ZoneDefs.seam_offset(cur, pid)
		if not bool(seam.get("valid", false)):
			continue
		var d: float = player_pos.distance_to(tp.get("pos", Vector2.ZERO))
		if d < best_d:
			best_d = d
			best_pid = pid
			best_seam = seam
	if best_pid.is_empty():
		return
	_begin_preload(main, best_pid, best_seam)


# --- async pre-build ---------------------------------------------------------
func _begin_preload(main: Node, point_id: String, seam: Dictionary) -> void:
	_building = true
	_neighbor_ready = false
	_crossed = false
	_neighbor_id = str(seam.get("to_map", ""))
	_seam_point = point_id
	_seam_tp_pos = seam.get("tp_pos", Vector2.ZERO)
	# Seam geometry -> world coords (current zone sits at origin).
	_axis = str(seam.get("axis", "x"))
	_line = float(seam.get("boundary", 0.0))
	_toward = float(seam.get("dir_sign", 1.0))
	_gap_lo = float(seam.get("gap_min", 0.0))
	_gap_hi = float(seam.get("gap_max", 0.0))
	var offset: Vector2 = seam.get("offset", Vector2.ZERO)

	var root := Node2D.new()
	root.name = "StreamNeighbor_%s" % _neighbor_id
	root.y_sort_enabled = true
	root.position = offset
	var container: Node2D = main.call("stream_container")
	if container == null:
		_building = false
		reset()
		return
	container.add_child(root)
	_neighbor_root = root
	# Expand the camera to the union so it can pan past our edge and reveal the
	# neighbor across the seam (restored on flip / unload).
	main.call("stream_set_camera_union", offset, seam.get("world_b", Vector2.ZERO))
	# Fire-and-forget staged build (time-sliced coroutine, no hard hitch).
	_run_build(main, root, _neighbor_id, seam)


func _run_build(main: Node, root: Node2D, zone_id: String, seam: Dictionary) -> void:
	var def: Dictionary = ZoneDefs.zone(zone_id)
	var built: Dictionary = await ZoneBuilder.build_zone_staged(root, def)
	# The build may have been cancelled (root freed) while we awaited.
	if root == null or not is_instance_valid(root) or _neighbor_root != root:
		return
	_neighbor_built = built
	_neighbor_ready = true
	_building = false
	print("[SEAMLESS] pre-built neighbor '%s' at offset (%d, %d) for seam %s.%s" % [
		zone_id, int(root.position.x), int(root.position.y),
		str(main.get("current_map_id")), _seam_point])


# --- cross / retreat / unload ------------------------------------------------
func _check_cross(main: Node, player_pos: Vector2) -> void:
	var along: float = player_pos.x if _axis == "x" else player_pos.y
	var perp: float = player_pos.y if _axis == "x" else player_pos.x
	var d: float = (along - _line) * _toward           # >0 toward neighbor
	var in_gap: bool = perp >= (_gap_lo - GAP_TOLERANCE) and perp <= (_gap_hi + GAP_TOLERANCE)

	# Crossing the boundary line (by a margin, and not just after a flip) inside
	# the gap -> flip ownership. The margin + cooldown make a crossing exactly ONE
	# flip: after a flip the player sits at d~=0 (< margin), so it never re-fires.
	if d >= FLIP_MARGIN and in_gap and _flip_cooldown == 0:
		_flip(main)
		return

	if _crossed:
		# Neighbor is the zone behind: free it once the player is well past.
		if d <= -UNLOAD_HYSTERESIS:
			print("[SEAMLESS] unloaded zone behind '%s' (player %d px past seam)" % [_neighbor_id, int(-d)])
			main.call("stream_free_behind", _neighbor_root)
			reset()
	else:
		# Neighbor is ahead: drop it if the player wandered off.
		if player_pos.distance_to(_seam_tp_pos) > RETREAT_DISTANCE:
			main.call("stream_free_behind", _neighbor_root)
			reset()


func _flip(main: Node) -> void:
	if _flipping or _neighbor_root == null or not is_instance_valid(_neighbor_root):
		return
	_flipping = true
	# Capture the pre-flip current zone: it becomes the new (behind) neighbor.
	var prev_id: String = str(main.get("current_map_id"))
	var prev_built: Dictionary = main.call("stream_built")
	# Shift so the neighbor lands at origin and becomes the current zone.
	var shift: Vector2 = _neighbor_root.position
	var new_root: Node2D = _neighbor_root
	var new_id: String = _neighbor_id
	var new_built: Dictionary = _neighbor_built
	# main performs the atomic world-offset shift, reparents the player, fires
	# the change hooks (music/weather/minimap/daynight/enemies), and hands back
	# the OLD world root which becomes the new (behind) neighbor.
	var old_world: Node2D = main.call("stream_commit_flip", new_id, new_root, new_built, shift)

	# Re-express the seam in the shifted world frame; the neighbor is now behind.
	_line -= (shift.x if _axis == "x" else shift.y)
	_gap_lo -= (shift.y if _axis == "x" else shift.x)
	_gap_hi -= (shift.y if _axis == "x" else shift.x)
	_toward = -_toward
	_crossed = not _crossed
	# The old current zone is the new neighbor (now behind, at world pos -shift).
	_neighbor_root = old_world
	_neighbor_id = prev_id
	_neighbor_built = prev_built
	_neighbor_ready = old_world != null and is_instance_valid(old_world)
	_flip_cooldown = FLIP_COOLDOWN_FRAMES
	print("[SEAMLESS] FLIP -> now in '%s' (behind: '%s'); seamless, no fade" % [new_id, _neighbor_id])
	_flipping = false


# =============================================================================
# DEBUG / QA — force a pre-build for a static screenshot (RH_SEAMLESS capture)
# =============================================================================
## Pre-build the first streamable seam of the current map regardless of distance,
## so a windowed RH_SHOT can show both zones' terrain meeting at the seam. Returns
## the seam dict (or {} if none streamable). ASCII logs only.
func debug_prebuild_first_seam(main: Node) -> Dictionary:
	if main == null:
		return {}
	var cur: String = str(main.get("current_map_id"))
	for tp_v: Variant in MapRegistry.travel_points(cur):
		var tp: Dictionary = tp_v
		var pid: String = str(tp.get("id", ""))
		var seam: Dictionary = ZoneDefs.seam_offset(cur, pid)
		if not bool(seam.get("valid", false)):
			print("[SEAMLESS] seam %s.%s not streamable (interior/mismatched) -> would use fade" % [cur, pid])
			continue
		_begin_preload(main, pid, seam)
		# Wait for the async build to finish so the screenshot has terrain.
		var guard: int = 0
		while _building and guard < 600:
			await main.get_tree().process_frame
			guard += 1
		return seam
	print("[SEAMLESS] no streamable seam on '%s'" % cur)
	return {}
