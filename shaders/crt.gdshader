// Overlay for the UI screens (chapter card, menu, paperwork screens): CCTV scanlines, a sparkle of
// noise and dark corners, drawn over whatever is behind it.
shader_type canvas_item;

uniform float scan = 0.12;    // scanline darkness
uniform float corners = 0.55; // vignette
uniform float sparkle = 0.18; // noise dots

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float s = 0.5 + 0.5 * sin(uv.y * 720.0 * 1.6);
	float n = hash(floor(uv * vec2(480.0, 360.0)) + floor(TIME * 24.0) * 1.37);
	vec2 d = uv - 0.5;
	float v = smoothstep(0.3, 0.9, length(d * vec2(1.1, 1.0)) * 1.25);
	float dot_ = step(0.9985, n);
	COLOR = vec4(vec3(dot_), max(s * scan + v * corners, dot_ * sparkle));
}
