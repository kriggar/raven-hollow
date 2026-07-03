shader_type canvas_item;

// Exact-color ramp remap for the szadi villager sheets (see NPC.RAMPS).
// Each source ramp STEP is compared with a half-8-bit-step epsilon and
// replaced by its precomputed destination step, so pixel-art shading is
// preserved (no flat tint). Pixels that match no step — outlines, eyes,
// props like hats / flowers / glasses — pass through untouched.
//
// COLOR arrives as vertex_color * texture (Godot 4 canvas_item), so the
// swap multiplies by dst/src instead of overwriting: any modulate or
// day-night canvas tint stays intact. Runtime only — no sprite files are
// modified (user law). Requires nearest-neighbour filtering (project-wide
// default_texture_filter = 0), which guarantees exact 8-bit texel values.

const float EPS = 0.002; // < half of 1/255: only exact texel matches swap
const int MAX_COLORS = 32;

uniform int color_count = 0;
uniform vec4 src_colors[MAX_COLORS];
uniform vec4 dst_colors[MAX_COLORS];

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	for (int i = 0; i < color_count; i++) {
		if (distance(tex.rgb, src_colors[i].rgb) < EPS) {
			COLOR.rgb *= dst_colors[i].rgb / max(src_colors[i].rgb, vec3(EPS));
			break;
		}
	}
}
