class_name FBBakeCore
extends Node2D
## Procedural molten-core fireball drawer for the VFX particle-bake route.
## Everything is driven by `phase` in [0,1): frame 0 and frame 1.0 are identical by
## construction (all motion via sin/cos of TAU*phase and frac(phase+k)), so a 12-frame
## capture across one cycle is a SEAMLESS forward loop. Built the way Foozle builds fire:
## an irregular WAVY red flame aura (licking, upward crown) + a distinct dark-orange band
## + a bright concentric gold/white-hot CORE on top, all in a fixed 12-colour fire ramp so
## the palettize shader is near-identity and pixels stay crisp. Cell 64x64.

var phase: float = 0.0

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


# wavy flame radius at a given angle: base + flicker + an upward crown (fire rises).
func _flame_r(ang: float, base: float, amp: float, up: float) -> float:
	var a := TAU * phase
	var f := sin(ang * 3.0 + a) * 0.5 + sin(ang * 5.0 - a * 1.7) * 0.32 + sin(ang * 2.0 + a * 0.7) * 0.22
	var up_bias := maxf(0.0, -sin(ang))          # 1 at top (-Y), 0 at bottom
	return base + amp * f + up * up_bias * up_bias


func _flame_poly(base: float, amp: float, up: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var seg := 64
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		var r := _flame_r(ang, base, amp, up)
		pts.append(C + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var a := TAU * phase

	# 1) FLAME AURA — layered wavy blobs: maroon rim (silhouette) -> red licking flame
	#    -> dark-orange body. The upward crown makes it read as a fireball, not a sun.
	_flame_poly(20.2, 3.8, 9.0, P8)    # maroon rim (1px dark silhouette behind)
	_flame_poly(19.2, 3.8, 8.6, P6)    # RED licking flame layer (Foozle's outer fire)
	_flame_poly(15.6, 2.9, 4.6, P5)    # dark-orange body (red pokes past it = licks)

	# 2) CORE — bright concentric gold rings, hard-stepped, hot-white centre (clean, no holes).
	draw_circle(C, 13.6, P4)   # orange
	draw_circle(C, 11.2, P3)   # amber
	draw_circle(C,  8.6, P2)   # gold

	# 3) HOT CENTRE — orbits slightly off-centre => churning molten read, not a static bullseye.
	var hot := Vector2(cos(a), sin(a)) * 2.3
	draw_circle(C + hot * 0.30, 5.6, P1)   # pale gold
	draw_circle(C + hot * 0.70, 2.9, P0)   # white-hot pip

	# 5) HOT FLAME TIPS — a few bright gold flares licking up past the red crown.
	for k in 5:
		var tang := -PI * 0.5 + (float(k) - 2.0) * 0.42          # clustered toward the top
		var flick := 0.5 + 0.5 * sin(a + float(k) * 1.7)
		var tip := C + Vector2(cos(tang), sin(tang)) * (17.0 + 7.0 * flick)
		draw_circle(tip, lerpf(2.2, 1.0, flick), P3 if k % 2 == 0 else P2)

	# 6) EMBERS — 2 crisp spark pixels riding the crown, kept close so they don't orphan.
	var embers := 2
	for e in embers:
		var u := fmod(phase + float(e) / float(embers), 1.0)
		if u > 0.8:
			continue
		var ea := -PI * 0.5 + (float(e) - 0.5) * 1.1
		var p := C + Vector2(cos(ea), sin(ea)) * (16.0 + u * 5.0)
		p.y -= u * 4.0
		var col := P2 if u < 0.5 else P4
		draw_rect(Rect2(roundf(p.x - 1.0), roundf(p.y - 1.0), 2.0, 2.0), col)
