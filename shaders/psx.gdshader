// Surfaces, props and characters. Two looks, picked by the global `retro_look` (Game.retro):
//  retro (PSX): vertex snapping (wobbly polys) on characters/props, the 16x16 nearest-filtered
//               texture, no specular.
//  HD: no snapping; world surfaces get their HD texture + normal map (hd.gd sets has_hd and the
//      textures per kind); everything gets a soft specular so lights and the flashlight read.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float retro_look;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float snap_res = 120.0;       // lower = more jitter
uniform bool world_uv = false;        // texture boxes by world position (walls, floors)
uniform float world_uv_scale = 0.5;   // repeats per metre
uniform vec3 emission = vec3(0.0);
uniform bool has_hd = false;
uniform sampler2D hd_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D hd_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float hd_roughness = 0.85;
uniform float hd_normal_strength = 0.5;
uniform float roughness = 0.7;        // HD: everything without its own texture
uniform bool hd_trim = false;         // HD walls: a skirting board, and the corners a little darker
uniform float wall_h = 3.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// wobble only on characters and small props: big world surfaces (floor, walls) are a few huge
	// triangles, and snapping their far-off corners made the whole floor swim
	if (!world_uv && retro_look > 0.5) {
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
	if (retro_look > 0.5) {
		ALBEDO = (texture(albedo_tex, uv) * albedo).rgb;
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = emission;
	} else if (has_hd) {
		vec3 col = (texture(hd_albedo, uv) * albedo).rgb;
		float rough = hd_roughness;
		if (hd_trim && abs(wnorm.y) < 0.5) {
			col *= mix(0.62, 1.0, smoothstep(0.1, 0.9, wpos.y));             // contact shadow by the floor
			col *= mix(0.72, 1.0, smoothstep(wall_h, wall_h - 0.5, wpos.y));  // and under the ceiling
			if (wpos.y < 0.11) {   // skirting board
				col = vec3(0.16, 0.16, 0.17);
				rough = 0.45;
			}
		}
		ALBEDO = col;
		NORMAL_MAP = texture(hd_normal, uv).rgb;
		NORMAL_MAP_DEPTH = hd_normal_strength;
		ROUGHNESS = rough;
		SPECULAR = 0.5;
		EMISSION = emission * 1.6;
	} else {
		ALBEDO = (world_uv ? texture(albedo_tex, uv) * albedo : albedo).rgb;
		ROUGHNESS = roughness;
		SPECULAR = 0.4;
		EMISSION = emission * 1.6;   // lit panels and glowing eyes bloom (HD glow)
	}
}
