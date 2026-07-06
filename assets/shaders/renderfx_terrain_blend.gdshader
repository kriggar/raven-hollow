shader_type canvas_item;

// RenderFXSystem terrain edge-blend (BACKLOG #65, "GK up/down illusion").
// A canvas_item shader that soft-blends a tile against its neighbours by fading
// the tile's alpha toward its borders. `blend_edge` sets the softness band
// width; `blend_amount` scales the effect; an optional `neighbor_mask`
// (red channel) selects WHICH borders blend (white = blend, black = keep hard).
//
// This is OPT-IN ONLY: RenderFXSystem hands this material to a tile through
// apply_blend_to()/make_blend_material(); it is NEVER auto-applied to shipped
// tiles (Fable-only visual law). With blend_amount 0 it is a pure passthrough.

uniform float blend_edge : hint_range(0.0, 0.5) = 0.15;
uniform float blend_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D neighbor_mask : hint_default_white;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Distance to the nearest tile border (0 at edge, 0.5 at centre).
	vec2 d = min(UV, vec2(1.0) - UV);
	float e = smoothstep(0.0, max(blend_edge, 0.0001), min(d.x, d.y));
	float mask = texture(neighbor_mask, UV).r;
	float a = mix(1.0, e, clamp(blend_amount * mask, 0.0, 1.0));
	COLOR = tex * COLOR;
	COLOR.a *= a;
}
