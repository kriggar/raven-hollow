shader_type canvas_item;
render_mode blend_mix;

// VFX PALETTE-QUANTIZE (Raven Hollow VFX pipeline, procedural particle-bake route).
// Posterizes an emissive VFX render to a fixed 12-step fire+ash ramp and BINARISES
// alpha to {0,1} -> hard-edged, near-palette pixels BEFORE any post touches them
// (crisp-by-construction, VFX_PIPELINE 2a.1 / 4). Requires nearest-neighbour
// filtering (project default_texture_filter = 0). The SAME 12 colours are used by
// the Python master-palette lock so in-engine frames and the packed GIF agree.

const int NCOL = 12;
uniform float alpha_cut = 0.42;   // below this the pixel is fully transparent

vec3 pal(int i) {
	// hot fire ramp (0 = white-hot core .. 9 = deep ember) + 2 dark edge/smoke steps
	if (i == 0)  return vec3(255.0, 250.0, 235.0) / 255.0; // white-hot
	if (i == 1)  return vec3(255.0, 238.0, 170.0) / 255.0; // pale gold
	if (i == 2)  return vec3(255.0, 214.0,  96.0) / 255.0; // gold
	if (i == 3)  return vec3(255.0, 176.0,  48.0) / 255.0; // amber
	if (i == 4)  return vec3(250.0, 130.0,  28.0) / 255.0; // orange
	if (i == 5)  return vec3(224.0,  86.0,  18.0) / 255.0; // dark orange
	if (i == 6)  return vec3(188.0,  50.0,  16.0) / 255.0; // red
	if (i == 7)  return vec3(140.0,  30.0,  18.0) / 255.0; // dark red
	if (i == 8)  return vec3( 92.0,  22.0,  20.0) / 255.0; // maroon
	if (i == 9)  return vec3( 52.0,  14.0,  18.0) / 255.0; // deep ember
	if (i == 10) return vec3( 40.0,  30.0,  34.0) / 255.0; // dark edge
	return               vec3( 22.0,  18.0,  24.0) / 255.0; // near-black smoke
}

void fragment() {
	vec4 t = texture(TEXTURE, UV) * COLOR;
	if (t.a < alpha_cut) {
		COLOR = vec4(0.0);
	} else {
		float best = 1e9;
		vec3 bc = vec3(0.0);
		for (int i = 0; i < NCOL; i++) {
			vec3 p = pal(i);
			float d = distance(t.rgb, p);
			if (d < best) { best = d; bc = p; }
		}
		COLOR = vec4(bc, 1.0);
	}
}
