// HD post-process on the 3D view (main.gd, Game.retro off): a quiet film look that frays as Tong
// breaks down. Same uniforms as vhs.gdshader (fear, strength, brightness), so main.gd drives either.
// fear 0: fine grain + a soft vignette. fear 1: colour splits at the edges, the picture breathes
// and drifts, it drains to grey-red and the dark closes in.
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
	vec2 d = uv - 0.5;
	// the picture breathes: a slow lens pulse and drift when scared
	float pulse = sin(TIME * 1.7) * 0.5 + 0.5;
	uv -= d * (0.012 * f * pulse);
	uv.x += sin(uv.y * 9.0 + TIME * 1.3) * 0.0018 * f;
	// a rare torn row at the worst
	float row = floor(uv.y * 90.0);
	uv.x += step(0.996 - f * 0.02, hash(vec2(row, floor(TIME * 12.0)))) * smoothstep(0.55, 0.9, f) * 0.012;
	// chromatic aberration, strongest at the edges
	float ca = (0.0006 + 0.006 * f) * length(d) * 2.0;
	vec2 dir = normalize(d + 1e-5);
	vec3 col = vec3(texture(TEXTURE, uv + dir * ca).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - dir * ca).b);
	// grain: always a little, more when scared
	col += (hash(uv * 1024.0 + fract(TIME * 7.0) * 91.0) - 0.5) * (0.035 * strength + 0.09 * f);
	// drain toward sick grey-red
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g * 1.12, g * 0.74, g * 0.7), f * 0.5);
	// vignette, closing in
	col *= clamp(1.0 - dot(d, d) * (0.55 * strength + 2.2 * f + 0.4 * f * pulse), 0.0, 1.0);
	COLOR = vec4(col * brightness, 1.0);
}
