# HD remaster look (Game.retro off, the default): the stage's surfaces get HD textures, the lights
# cast shadows, and the environment gets tonemapping, glow, ambient occlusion and volumetric fog
# (the last two only on the Forward+ renderer: desktop; the web build keeps the cheaper ones).
# Game.retro on = the original PSX look (low resolution, wobbly polygons, VHS).
# Game.graphics: 0 low, 1 medium, 2 high.
class_name HD
extends RefCounted

const TEX := "res://assets/textures/hd/%s.png"
# Per surface: roughness, normal map strength
const KINDS := {
	"carpet": [0.95, 0.7], "wall": [0.82, 0.35], "ceiling": [0.9, 0.5], "fabric": [0.95, 0.6],
	"tile": [0.32, 0.6], "concrete": [0.9, 0.8], "wood": [0.55, 0.4], "plastic": [0.45, 0.3],
}
static var _tex := {}
static var look := 0.0   # what retro_look was last set to (reading it back is editor-only)

# The global shader switch (psx.gdshader): call when the setting changes.
static func apply_look() -> void:
	look = 1.0 if Game.retro else 0.0
	RenderingServer.global_shader_parameter_set("retro_look", look)

static func forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

static func texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX % name)
	return _tex[name]

# Which of the builder's 16x16 textures (stage_builder.gd _tex) this is: the ceiling has a dark
# first row and column, the wall brighter columns 0 and 8, the carpet a 4x4 checker; else fabric.
static func kind_of(tex: Texture2D) -> String:
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null or img.get_width() != 16:
		return "fabric"
	var col := func(x: int) -> float:
		var s := 0.0
		for y in range(1, 16):
			s += img.get_pixel(x, y).r
		return s / 15.0
	if col.call(0) < col.call(5) - 0.2:
		return "ceiling"
	if (col.call(0) + col.call(8)) / 2.0 > (col.call(3) + col.call(4) + col.call(11) + col.call(12)) / 4.0 + 0.035:
		return "wall"
	var dark := 0.0
	var light := 0.0
	for y in 16:
		for x in 16:
			if (x / 4 + y / 4) % 2 == 0:
				dark += img.get_pixel(x, y).r
			else:
				light += img.get_pixel(x, y).r
	if light - dark > 0.04 * 128.0:
		return "carpet"
	return "fabric"

# Every builder surface under root gets its HD texture. floor_kind replaces the carpet (hospital
# vinyl, stairwell concrete).
static func dress(root: Node, floor_kind := "carpet") -> void:
	var done := {}
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var m = g.material_override
		if not (m is ShaderMaterial) or done.has(m) or m.shader == null or not m.shader.resource_path.ends_with("psx.gdshader"):
			continue
		done[m] = true
		var tex = m.get_shader_parameter("albedo_tex")
		if tex == null:
			continue
		var kind := kind_of(tex)
		if kind == "carpet":
			kind = floor_kind
		m.set_shader_parameter("has_hd", true)
		m.set_shader_parameter("hd_albedo", texture(kind))
		m.set_shader_parameter("hd_normal", texture(kind + "_n"))
		m.set_shader_parameter("hd_roughness", KINDS[kind][0])
		m.set_shader_parameter("hd_normal_strength", KINDS[kind][1])
		m.set_shader_parameter("world_uv", true)   # small blocks too: no stretched faces
		m.set_shader_parameter("hd_trim", kind == "wall")
	_props(root)

# The furniture kit is flat colours (roughness 1): give each a surface by its colour (tan = wood
# laminate, grey/white = plastic, dark = metal, colourful = fabric) and some shine.
static func _props(root: Node) -> void:
	var made := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override != null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if mi.get_surface_override_material(i) != null or not (src is StandardMaterial3D) or src.albedo_texture != null:   # (characters have their own)
				continue
			if not made.has(src):
				var c: Color = src.albedo_color
				var kind := "fabric"
				if c.s < 0.14:
					kind = "plastic"
				elif c.r > c.g and c.g > c.b and c.v > 0.5:
					kind = "wood"
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_texture = texture(kind)
				m.normal_enabled = true
				m.normal_texture = texture(kind + "_n")
				m.normal_scale = KINDS[kind][1]
				m.roughness = KINDS[kind][0]
				if kind == "plastic" and c.v < 0.35:   # dark grey: metal
					m.metallic = 0.6
					m.roughness = 0.38
				m.uv1_triplanar = true
				m.uv1_world_triplanar = true
				m.uv1_scale = Vector3.ONE * 1.4
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				made[src] = m
			mi.set_surface_override_material(i, made[src])

# The night: filmic tonemapping, glow on the lit panels, and on Forward+ ambient occlusion and
# volumetric fog (the flashlight cuts a beam through it). Fog density scales with `gloom` later.
static func environment(env: Environment) -> void:
	var q: int = Game.graphics
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ambient_light_energy = 0.55   # the dark between the lights is darker
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.08
	if not forward_plus():
		return
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_enabled = q >= 2
	env.volumetric_fog_enabled = q >= 1
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.55, 0.58, 0.62)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 36.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.15
	if env.volumetric_fog_enabled:
		env.fog_density *= 0.35   # the volume does most of the hiding now

# Shadows from the ceiling lights on High (Medium/Low: only the flashlight casts them).
static func lights(lights: Array) -> void:
	for l in lights:
		l.shadow_enabled = false   # stage.gd turns them on for the few lights nearest Tong (nearest_shadows)
		l.shadow_blur = 1.5
		l.light_energy *= 1.6       # pools of light under each tube, darker between them
		l.omni_attenuation = 1.8
		l.omni_range = 10.0
		l.light_specular = 0.6
		l.light_volumetric_fog_energy = 1.2

# How many of the nearest ceiling lights cast shadows (0 on Low and on the web renderer).
static func shadow_count() -> int:
	return [0, 3, 8][clampi(Game.graphics, 0, 2)] if forward_plus() and not Game.retro else 0

# The flashlight in the HD look: a wide soft spill plus a narrow hot core (a second light inside
# it, so it goes on and off with it), a longer throw, and a beam through the fog.
static func flashlight(l: SpotLight3D) -> void:
	l.light_energy = 2.6
	l.spot_range = 20.0
	l.spot_angle = 30.0
	l.spot_attenuation = 1.2
	l.light_volumetric_fog_energy = 2.0
	l.shadow_blur = 1.2
	if l.get_node_or_null("Core") == null:
		var core := SpotLight3D.new()
		core.name = "Core"
		core.light_color = l.light_color
		core.light_energy = 3.2
		core.spot_range = 22.0
		core.spot_angle = 11.0
		core.spot_angle_attenuation = 1.5
		core.light_volumetric_fog_energy = 1.5
		l.add_child(core)
