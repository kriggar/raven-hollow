class_name FBBakeCore
extends Node2D
## Procedural fireball drawer for the VFX particle-bake route (v2 — flame character).
## Built the Foozle way: a small HOT irregular head (white-hot crescent on the leading
## edge + large gold fill + thin orange/red rim, hot centre OFFSET toward the lead so it
## is NOT a concentric bullseye) wrapped in distinct POINTED flame TONGUES that wave and
## flicker. mode 0 = radial spin loop (tongues radiate, upward-biased). mode 1 = directional
## projectile (tongues trail BEHIND the travel direction, comet head leading).
## All motion uses INTEGER harmonics of TAU*phase (+ constant per-tongue offsets), so a
## 12-frame capture is a SEAMLESS loop. Drawn in the fixed 12-colour fire ramp = crisp.

var phase: float = 0.0
var mode: int = 0     # 0 = spin (radial), 1 = dir (directional/comet)

# ---- the 12-colour fire+ash ramp (must match vfx_palettize.gdshader) ----
const P0 := Color(255.0/255, 250.0/255, 235.0/255)   # white-hot
const P1 := Color(255.0/255, 238.0/255, 170.0/255)   # pale gold
const P2 := Color(255.0/255, 214.0/255,  96.0/255)   # gold
const P3 := Color(255.0/255, 176.0/255,  48.0/255)   # amber
const P4 := Color(250.0/255, 130.0/255,  28.0/255)   # orange
const P5 := Color(224.0/255,  86.0/255,  18.0/255)   # dark orange
const P6 := Color(188.0/255,  50.0/255,  16.0/255)   # red
const P7 := Color(140.0/255,  30.0/255,  18.0/255)   # dark red
const P8 := Color( 92.0/255,  22.0/255,  20.0/255)   # maroon
const P9 := Color( 52.0/255,  14.0/255,  18.0/255)   # deep ember
const P10 := Color(40.0/255,  30.0/255,  34.0/255)   # dark edge
const P11 := Color(22.0/255,  18.0/255,  24.0/255)   # near-black smoke

const C := Vector2(32, 32)   # cell centre


func set_phase(p: float) -> void:
	phase = p
	queue_redraw()


func _hash(k: int) -> float:
	var s := sin(float(k) * 127.1 + 11.7) * 43758.5453
	return s - floor(s)


# a curved, pointed flame tongue (fat base -> sharp tip) as one filled polygon.
func _tongue(theta: float, base_dist: float, length: float, base_w: float, lean: float, col: Color) -> void:
	if length <= 0.5:
		return
	var K := 7
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for s in K + 1:
		var u := float(s) / float(K)
		var ang := theta + lean * u * u                 # curve grows toward the tip
		var d := base_dist + length * u
		var c := C + Vector2(cos(ang), sin(ang)) * d
		var rad := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-rad.y, rad.x)
		var w := base_w * pow(1.0 - u, 0.85)            # taper to a sharp point
		left.append(c + perp * w)
		right.append(c - perp * w)
	var poly := PackedVector2Array()
	for p in left:
		poly.append(p)
	for i in range(right.size() - 1, -1, -1):
		poly.append(right[i])
	draw_colored_polygon(poly, col)


# a hot flame lick: thin dark rim, RED tips, orange body, amber/gold hot root (Foozle gradient).
func _flame_lick(theta: float, base_dist: float, length: float, base_w: float, lean: float) -> void:
	_tongue(theta, base_dist, length, base_w, lean, P7)                  # thin dark-red rim
	_tongue(theta, base_dist, length * 0.98, base_w * 0.88, lean, P6)   # red (tips + body)
	_tongue(theta, base_dist, length * 0.72, base_w * 0.72, lean, P4)   # orange mid
	_tongue(theta, base_dist, length * 0.46, base_w * 0.56, lean, P3)   # amber base
	_tongue(theta, base_dist, length * 0.26, base_w * 0.44, lean, P2)   # gold hot root


# an irregular (non-circular) molten blob, so bands never read as concentric rings.
func _blob(center: Vector2, radius: float, col: Color, wob: float, ph: float) -> void:
	var pts := PackedVector2Array()
	var seg := 22
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		var r := radius * (1.0 + wob * sin(ang * 3.0 + ph) + wob * 0.6 * sin(ang * 5.0 - ph))
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, col)


# the hot HEAD: red rim -> thin amber -> LARGE gold fill -> pale gold -> white-hot
# crescent on the LEADING edge. Hot centre offset toward `lead` => not a bullseye.
func _head(lead: Vector2, a: float) -> void:
	_blob(C, 11.8, P7, 0.09, a + 0.4)                   # dark-red rim (silhouette)
	_blob(C + lead * 0.6, 10.8, P5, 0.09, a)            # dark-orange rim
	_blob(C + lead * 1.3, 9.6, P4, 0.08, a + 1.1)       # orange band
	_blob(C + lead * 2.1, 8.2, P3, 0.08, a + 1.7)       # amber band
	_blob(C + lead * 2.9, 6.6, P2, 0.07, a + 3.1)       # large gold fill (Foozle head)
	_blob(C + lead * 3.6, 3.9, P1, 0.06, a + 4.6)       # pale gold
	var wob := lead * 5.2 + Vector2(cos(a), sin(a)) * 0.7
	draw_circle(C + wob, 2.6, P0)                        # white-hot crescent at lead edge


func _draw() -> void:
	var a := TAU * phase
	if mode == 1:
		_draw_dir(a)
	else:
		_draw_spin(a)


func _draw_spin(a: float) -> void:
	# radial flame tongues, upward-biased, varying length + curl => dancing flame, not a sun
	var n := 6
	for k in n:
		var rnd := _hash(k)
		var base := TAU * (float(k) + 0.5) / float(n) + (rnd - 0.5) * 0.45
		var flick := 0.5 + 0.5 * sin(a + float(k) * 2.1 + rnd * TAU)
		var flick2 := 0.5 + 0.5 * sin(2.0 * a + rnd * TAU * 1.3)
		var up := maxf(0.0, -sin(base))
		var length := 9.0 + 5.5 * flick + 3.0 * flick2 * rnd + up * up * 6.5   # capped, chunkier
		var lean := 0.5 * sin(a + rnd * TAU)
		var bw := 5.2 + 1.8 * rnd                                              # fat, cohesive licks
		_flame_lick(base, 7.0, length, bw, lean)
	_head(Vector2(0, -1), a)


func _draw_dir(a: float) -> void:
	# directional comet: hot head leads +X, pointed flame tongues trail behind (-X).
	var n := 5
	for k in n:
		var rnd := _hash(k + 20)
		var frac := (float(k) + 0.5) / float(n) - 0.5          # -0.5..0.5 across the tail fan
		var base := PI + frac * 3.0                            # around -X, +/-1.5 rad
		var flick := 0.5 + 0.5 * sin(a + float(k) * 1.9 + rnd * TAU)
		var flick2 := 0.5 + 0.5 * sin(2.0 * a + rnd * TAU)
		var backness := maxf(0.0, 1.0 - absf(frac) * 1.35)     # longest straight back
		var length := 8.0 + 12.0 * backness + 5.0 * flick + 3.0 * flick2 * rnd
		var lean := 0.5 * sin(a + rnd * TAU)
		var bw := 4.6 + 2.6 * maxf(backness, 0.3)              # fat, cohesive toward straight-back
		_flame_lick(base, 7.0, length, bw, lean)
	# short front fringe licks so the leading head is flaming, not a bald semicircle
	for j in 3:
		var fa := (float(j) - 1.0) * 0.72                      # around +X
		var fl := 0.5 + 0.5 * sin(a + float(j) * 2.0)
		var flen := 4.5 + 3.0 * fl
		_flame_lick(fa, 9.5, flen, 3.6, 0.2 * sin(a + float(j)))
	_head(Vector2(1, 0), a)
