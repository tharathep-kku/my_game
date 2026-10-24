// Screen post-process on the 3D view (main.gd): CCTV/VHS look that gets worse as Tong breaks
// down. fear 0 = calm (steady picture: scanlines + vignette only), 1 = Social Battery nearly gone: colour bleeds
// apart, the picture tears and wobbles, it goes grey-red and the edges close in.
shader_type canvas_item;

uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.5) = 1.0;    // settings: how strong the effects are
uniform float brightness : hint_range(0.5, 1.8) = 1.0;  // settings: picture brightness

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float f = fear * strength;
	// horizontal tear: a few rows jump sideways, more often when scared
	float row = floor(uv.y * 48.0);
	float tear = step(0.992 - f * 0.05, hash(vec2(row, floor(TIME * 9.0)))) * smoothstep(0.25, 0.6, f);   // calm: none
	uv.x += tear * (0.01 + 0.04 * f) * sin(TIME * 50.0);
	uv.x += sin(uv.y * 25.0 + TIME * 2.5) * 0.0025 * f;   // slow wobble
	// colour bleed
	float ca = 0.001 + 0.007 * f;
	vec3 col = vec3(texture(TEXTURE, uv + vec2(ca, 0.0)).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - vec2(ca, 0.0)).b);
	// scanlines + grain
	col *= 1.0 - (0.05 + 0.05 * sin(uv.y * 480.0 * 3.14159)) * strength;
	col += (hash(uv * 512.0 + fract(TIME) * 37.0) - 0.5) * (0.006 + 0.12 * f);   // calm: barely any grain
	// drain the colour toward sick grey-red
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g * 1.15, g * 0.7, g * 0.68), f * 0.55);
	// vignette closes in
	vec2 d = uv - 0.5;
	col *= clamp(1.0 - dot(d, d) * (0.9 * strength + 2.4 * f), 0.0, 1.0);
	COLOR = vec4(col * brightness, 1.0);
}
