shader_type canvas_item;

// RenderFXSystem atmospheric fog (BACKLOG #67, Drova-style).
// A screen-space, self-animating fog veil drawn on a full-rect ColorRect inside
// a self-instanced CanvasLayer. Drifting fbm value-noise + a soft radial
// vignette that darkens toward the screen edges. Everything is procedural, so
// the layer needs no texture asset and is safe to instance headless.
//
// The host RenderFXSystem ramps `density` by time-of-day (denser at night).
// GATED OFF by default -- the layer only exists when fog is explicitly enabled.

uniform vec4 fog_color : source_color = vec4(0.03, 0.04, 0.06, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float drift_speed = 0.02;
uniform vec2 drift_dir = vec2(1.0, 0.35);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 flow = drift_dir * TIME * drift_speed;
	float n = fbm(UV * 3.0 + flow);
	n = mix(0.55, 1.0, n);
	// Radial vignette: soft-darken toward the edges.
	float r = distance(UV, vec2(0.5));
	float vig = smoothstep(0.25, 0.78, r) * vignette;
	float a = clamp(density * (0.35 + 0.65 * n) + vig * 0.5, 0.0, 1.0);
	COLOR = vec4(fog_color.rgb, a * fog_color.a);
}
