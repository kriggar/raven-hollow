class_name TownAudit
## QA: prop clipping / placement audit for a built map (RH_PROPAUDIT=1).
##
## Walks every Sprite2D / AnimatedSprite2D under the world's y-sorted prop
## nodes, derives a FOOTPRINT (the bottom band of the sprite where it "stands")
## and reports:
##   STACK   two solid props whose footprints overlap (one stands in another)
##   ON_LANE a prop whose footprint sits on a painted lane/plaza cell
##   IN_BLDG a prop whose footprint sits inside a building's wall footprint
##   NPC_IN  an NPC/villager spawn standing inside a prop footprint
## Output is plain text on stdout (grep "AUDIT"). Read-only; never mutates.

const FOOT_H: float = 10.0        # px band above the sprite base that counts as "feet"
const DECAL_ALPHA: float = 0.75   # sprites this transparent are ground decals, ignored
const MIN_OVERLAP: float = 36.0   # px² of footprint overlap before STACK fires


static func run(world: Node, path_cells: Dictionary = {}) -> Dictionary:
	var props: Array = []
	_collect(world, props)
	var report: Dictionary = {"STACK": [], "ON_LANE": [], "IN_BLDG": [], "NPC_IN": [], "count": props.size()}
	var feet: Array = []       # [rect, name, is_building, node]
	for e: Variant in props:
		feet.append(e)
	# STACK
	for i in range(feet.size()):
		var a: Array = feet[i]
		if a[2]:
			continue   # buildings are handled by IN_BLDG
		for j in range(i + 1, feet.size()):
			var b: Array = feet[j]
			if b[2]:
				continue
			var inter: Rect2 = (a[0] as Rect2).intersection(b[0])
			if inter.size.x * inter.size.y >= MIN_OVERLAP:
				if _is_masonry(a[1]) and _is_masonry(b[1]):
					continue   # wall pieces / towers / blocks overlap by construction
				report["STACK"].append("%s @%s  x  %s @%s" % [a[1], _fmt(a[0]), b[1], _fmt(b[0])])
	# IN_BLDG + ON_LANE
	for e: Variant in feet:
		var r: Rect2 = e[0]
		if e[2]:
			continue
		for b: Variant in feet:
			if not b[2] or _is_masonry(e[1]):
				continue   # facade pieces (chimneys, wall lamps, ivy, signs) belong to their building
			var br: Rect2 = b[0]
			var inter2: Rect2 = br.intersection(r)
			if inter2.size.x * inter2.size.y >= MIN_OVERLAP:
				report["IN_BLDG"].append("%s @%s inside %s" % [e[1], _fmt(r), b[1]])
		if not path_cells.is_empty():
			var c := Vector2i(int((r.position.x + r.size.x * 0.5) / 32.0), int((r.end.y - 2.0) / 32.0))
			if path_cells.has(c) and not _lane_ok(e[1]):
				report["ON_LANE"].append("%s @%s on lane cell %s" % [e[1], _fmt(r), c])
	# NPC_IN
	for n: Variant in _find_npcs(world):
		var p: Vector2 = (n as Node2D).global_position
		for e: Variant in feet:
			if (e[0] as Rect2).has_point(p):
				report["NPC_IN"].append("%s @(%d,%d) inside %s" % [n.name, int(p.x), int(p.y), e[1]])
	print("AUDIT props=%d STACK=%d ON_LANE=%d IN_BLDG=%d NPC_IN=%d" % [props.size(), report["STACK"].size(), report["ON_LANE"].size(), report["IN_BLDG"].size(), report["NPC_IN"].size()])
	# ON_LANE is informational (yards are painted dirt by design); print the rest.
	for k: String in ["STACK", "IN_BLDG", "NPC_IN"]:
		for line: Variant in report[k]:
			print("AUDIT %s: %s" % [k, line])
	return report


static func _is_masonry(label: String) -> bool:
	for k in ["wall_face", "wall_band", "wall_cren", "tower_", "gate_arch", "gate_doors", "gothic_tower", "spire", "roof_cone", "deck_", "railing_wood", "fence_iron", "lantern_lit", "chimney_", "banner_pair", "signicon", "awning_", "roof_", "wallamp", "ivy", "windows_row", "szadi_building_parts"]:
		if label.find(k) != -1:
			return true
	return false


## Signs, lanterns, carts and NPC anchors legitimately stand on lanes.
static func _lane_ok(name: String) -> bool:
	for ok in ["sign", "lamp", "lantern", "cart", "wagon", "post", "bench", "well", "fountain", "stall", "counter", "cobble", "campfire", "fire", "anvil", "crate", "sack", "barrel", "pot"]:
		if name.to_lower().find(ok) != -1:
			return true
	return false


static func _collect(node: Node, out: Array) -> void:
	if node.name == "Decals":
		return   # ground decals never clip
	for c: Node in node.get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			var s: Node2D = c
			var tex_size := Vector2.ZERO
			if c is Sprite2D and (c as Sprite2D).texture != null:
				var sp: Sprite2D = c
				tex_size = sp.texture.get_size()
				if sp.region_enabled:
					tex_size = sp.region_rect.size
			elif c is AnimatedSprite2D:
				var asp: AnimatedSprite2D = c
				if asp.sprite_frames != null and asp.sprite_frames.has_animation(asp.animation):
					var t: Texture2D = asp.sprite_frames.get_frame_texture(asp.animation, 0)
					if t != null:
						tex_size = t.get_size()
			if tex_size != Vector2.ZERO and s.modulate.a >= DECAL_ALPHA and s.z_index >= 0:
				var scale: Vector2 = s.global_scale
				var w: float = tex_size.x * absf(scale.x)
				var h: float = tex_size.y * absf(scale.y)
				var off := Vector2.ZERO
				if c is Sprite2D:
					var sp2: Sprite2D = c
					off = sp2.offset * scale
					if not sp2.centered:
						off += Vector2(w * 0.5, h * 0.5)
				var center: Vector2 = s.global_position + off
				var base_y: float = center.y + h * 0.5
				var is_bldg: bool = w >= 120.0 and h >= 120.0
				var foot_w: float = w * (0.9 if is_bldg else 0.6)
				var foot_h: float = h * 0.35 if is_bldg else FOOT_H
				var rect := Rect2(center.x - foot_w * 0.5, base_y - foot_h, foot_w, foot_h)
				if is_bldg:
					# _place_building draws 8px of ground skirt below the wall line;
					# props standing on that skirt are in front of the wall, not inside it.
					rect = Rect2(center.x - foot_w * 0.5, base_y - 8.0 - foot_h, foot_w, foot_h)
				var label: String = c.name
				if c is Sprite2D and (c as Sprite2D).texture != null:
					var tx: Texture2D = (c as Sprite2D).texture
					if tx is AtlasTexture:
						var at: AtlasTexture = tx
						label += "(atlas %s %dx%d)" % [at.atlas.resource_path.get_file() if at.atlas != null else "?", int(at.region.position.x), int(at.region.position.y)]
					else:
						label += "(" + tx.resource_path.get_file() + ")"
				out.append([rect, label, is_bldg, c])
		_collect(c, out)


static func _find_npcs(world: Node) -> Array:
	var out: Array = []
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CharacterBody2D and n.name.to_lower().find("player") == -1:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


static func _fmt(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
