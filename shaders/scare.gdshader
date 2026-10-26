// HD jumpscare face (main.gd): the picture tears, its colours split, grain crawls over it and the
// edges sink into black. amount 0..1 (1 at the slam).
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 24.0);
	float row = floor(uv.y * 40.0);
	if (hash(vec2(row, t)) > 1.0 - 0.22 * amount) {   // a few rows slide sideways
		uv.x += (hash(vec2(row, t + 7.0)) - 0.5) * 0.14 * amount;
	}
	float ca = 0.014 * amount;
	vec4 c = texture(TEXTURE, uv);
	c.r = texture(TEXTURE, uv + vec2(ca, 0.0)).r;
	c.b = texture(TEXTURE, uv - vec2(ca, 0.0)).b;
	c.rgb += (hash(uv * 512.0 + t) - 0.5) * 0.3 * amount;
	c.rgb *= mix(1.0, smoothstep(0.72, 0.2, length(uv - 0.5)), 0.85 * min(amount * 4.0, 1.0));
	COLOR = c * COLOR;
}
