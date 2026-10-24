// PSX look: vertex snapping (wobbly polys) on characters/props + nearest-filtered texture.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float snap_res = 120.0;       // lower = more jitter
uniform bool world_uv = false;        // texture boxes by world position (walls, floors)
uniform float world_uv_scale = 0.5;   // repeats per metre
uniform vec3 emission = vec3(0.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// wobble only on characters and small props: big world surfaces (floor, walls) are a few huge
	// triangles, and snapping their far-off corners made the whole floor swim
	if (!world_uv) {
		clip.xy = floor(clip.xy / clip.w * snap_res) / snap_res * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv = UV;
	if (world_uv) {
		vec3 n = abs(wnorm);
		uv = (n.y > 0.5 ? wpos.xz : (n.x > 0.5 ? wpos.zy : wpos.xy)) * world_uv_scale;
	}
	vec4 c = texture(albedo_tex, uv) * albedo;
	ALBEDO = c.rgb;
	EMISSION = emission;
}
