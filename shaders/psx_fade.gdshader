// psx.gdshader for a character that fades in or out (body.gd set_fade): ordered-dither "screen door"
// see-through, the way PS1 games did it. Stays in the opaque pass, so no sorting and it works on
// the web renderer.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float snap_res = 120.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;   // 0 = gone, 1 = solid

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap_res) / snap_res * clip.w;
	POSITION = clip;
}

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	if (fade < (BAYER[p.x + p.y * 4] + 0.5) / 16.0) {
		discard;
	}
	ALBEDO = albedo.rgb;
}
