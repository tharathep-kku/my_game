# HD remaster look (Game.retro off, the default): the stage's surfaces get HD textures, the lights
# cast shadows, and the environment gets tonemapping, glow, ambient occlusion and volumetric fog
# (the last two only on the Forward+ renderer: desktop; the web build keeps the cheaper ones).
# Game.retro on = the original PSX look (low resolution, wobbly polygons, VHS).
# Game.graphics: 0 low, 1 medium, 2 high.
class_name HD
extends RefCounted

const TEX := "res://assets/textures/hd/%s.png"
const REAL := "res://assets/models/real/%s.glb"   # tools/blender/build_props.py
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
	dress_props(root)
	_decorate(root)

# Furniture under node: the realistic models in place of the Kenney ones, then HD surfaces.
static func dress_props(node: Node) -> void:
	realize(node)
	_props(node)

# Each Kenney model (assets/models/X.glb) with a realistic version (assets/models/real/X.glb) gets
# it instead, fitted to the same box: placement and colliders stay as they were.
static func realize(root: Node) -> void:
	var todo: Array[Node3D] = []
	for n in root.find_children("*", "Node3D", true, false):
		var path: String = n.scene_file_path
		if path.begins_with("res://assets/models/") and path.get_base_dir() == "res://assets/models" and not n.has_meta("real"):
			todo.append(n)
	if root is Node3D and (root as Node3D).scene_file_path.get_base_dir() == "res://assets/models" and not root.has_meta("real"):
		todo.append(root)
	for n in todo:
		var real_path := REAL % n.scene_file_path.get_file().get_basename()
		if not ResourceLoader.exists(real_path):
			continue
		var real: Node3D = load(real_path).instantiate()
		var kab := _bounds(n)
		var rab := _bounds(real)
		if kab.size.x <= 0.0 or rab.size.x <= 0.0:
			real.free()
			continue
		var s := kab.size / rab.size
		var g := pow(s.x * s.y * s.z, 1.0 / 3.0)   # one scale; each axis may stretch a little to fit
		s = Vector3(clampf(s.x, g * 0.85, g * 1.15), clampf(s.y, g * 0.85, g * 1.15), clampf(s.z, g * 0.85, g * 1.15))
		var kb := Vector3(kab.get_center().x, kab.position.y, kab.get_center().z)
		var rb := Vector3(rab.get_center().x, rab.position.y, rab.get_center().z)
		for c in n.get_children():
			if c is VisualInstance3D or c.find_children("*", "VisualInstance3D", true, false).size() > 0:
				c.free()
		real.name = "Real"
		real.transform = Transform3D(Basis.from_scale(s), kb - rb * s)
		n.add_child(real)
		n.set_meta("real", true)
		# far away in the dark they are not drawn (the fog has them by then): small things sooner
		_far(real, 32.0 if (kab.size * n.scale).length() > 1.2 else 18.0)

static func _far(node: Node, dist: float) -> void:
	for g: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		g.visibility_range_end = dist
		g.visibility_range_end_margin = 2.0

# Box around every mesh under node, in node's own space (works outside the tree too).
static func _bounds(node: Node) -> AABB:
	var ab := AABB()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var p: Node = mi
		while p != node and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * mi.get_aabb()
		ab = b if ab.size == Vector3.ZERO else ab.merge(b)
	return ab

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

# The realistic models' materials say what they are (build_props.py): "<surface>_<what>" keeps
# its colour, roughness and metalness and gets that surface's texture; glow_* lights up; screen_* is
# glossy black glass.
static func _named(src: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = src.duplicate()
	var kind: String = (src.resource_name as String).get_slice("_", 0)
	match kind:
		"glow":
			m.emission_enabled = true
			m.emission = src.albedo_color
			m.emission_energy_multiplier = 2.5
		"screen":
			m.roughness = 0.06
			m.metallic_specular = 0.9
		_:
			var tex := "plastic" if kind == "metal" else kind
			if KINDS.has(tex):
				m.albedo_texture = texture(tex)
				m.normal_enabled = true
				m.normal_texture = texture(tex + "_n")
				m.normal_scale = KINDS[tex][1] * 0.7
				m.uv1_triplanar = true
				m.uv1_world_triplanar = true
				m.uv1_scale = Vector3.ONE * (0.7 if tex == "wood" else 1.4)
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

# ---------- fixtures: what an office has on its walls and ceilings ----------
static func fixture(name: String, shadows := false, far := 0.0) -> Node3D:
	var n: Node3D = load(REAL % name).instantiate()
	n.set_meta("real", true)
	n.set_meta("fixture", name)
	if far > 0.0:
		_far(n, far)
	if not shadows:
		for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

# Power sockets, notice boards and the odd fire extinguisher along the open walls; air vents,
# smoke detectors and sprinklers in the ceiling; an exit sign by the exit. Same layout every time
# (seeded by the stage), nothing in front of windows, signs, mirrors, doors or things to pick up.
static func _decorate(root: Node) -> void:
	var floor := root.find_child("Floor", true, false)
	if floor == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(root.scene_file_path) + String(root.name))
	var walls: Array[Rect2] = []
	for b in root.find_children("*Wall*", "StaticBody3D", true, false):
		for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", false, false):
			var ab: AABB = mi.global_transform * mi.get_aabb()
			if ab.size.y > 2.0:
				walls.append(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z))
	var floors: Array[Rect2] = []
	for cs: CollisionShape3D in floor.find_children("*", "CollisionShape3D", false, false):
		if cs.shape is BoxShape3D:
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var c := cs.global_position
			floors.append(Rect2(c.x - sz.x / 2, c.z - sz.z / 2, sz.x, sz.z))
	var avoid: Array[Vector3] = []
	for n in root.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("Window") or nm.begins_with("Mirror") or nm.begins_with("Sign") or nm.begins_with("Door") \
				or nm.begins_with("Exit") or nm.begins_with("FuseBox") or nm.begins_with("Breaker") or nm.begins_with("Locker") \
				or nm.begins_with("Stall") or n is Area3D and n.get("kind") != null:
			avoid.append(n.global_position)
	var open := func(p: Vector2) -> bool:
		if not floors.any(func(r: Rect2) -> bool: return r.has_point(p)):
			return false
		return not walls.any(func(r: Rect2) -> bool: return r.grow(0.02).has_point(p))
	var free_at := func(p: Vector3, d: float) -> bool:
		return not avoid.any(func(a: Vector3) -> bool: return Vector2(a.x - p.x, a.z - p.z).length() < d)
	var put := func(name: String, p: Vector3, yaw: float) -> void:
		var f := fixture(name, false, 12.0 if name in ["outlet", "sprinkler", "smoke"] else 22.0)
		root.add_child(f)
		f.global_position = p
		f.rotation.y = yaw
		avoid.append(p)
	# cubicle partitions: an aluminium cap along the top
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.6, 0.62, 0.64)
	trim.metallic = 0.7
	trim.roughness = 0.35
	for b in root.find_children("Partition*", "StaticBody3D", true, false):
		for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", false, false):
			var ab := mi.get_aabb()
			var cap := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(ab.size.x + 0.02, 0.03, ab.size.z + 0.02)
			cap.mesh = bm
			cap.material_override = trim
			cap.position = Vector3(ab.get_center().x, ab.end.y + 0.012, ab.get_center().z)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(cap)
	var boards := 0
	var extinguishers := 0
	for r in walls:
		# each side: outward normal, start corner, direction along it, length
		for side in [[Vector2(0, 1), Vector2(r.position.x, r.end.y), Vector2(1, 0), r.size.x],
				[Vector2(0, -1), Vector2(r.position.x, r.position.y), Vector2(1, 0), r.size.x],
				[Vector2(1, 0), Vector2(r.end.x, r.position.y), Vector2(0, 1), r.size.y],
				[Vector2(-1, 0), Vector2(r.position.x, r.position.y), Vector2(0, 1), r.size.y]]:
			var nrm: Vector2 = side[0]
			var start: Vector2 = side[1]
			var dir: Vector2 = side[2]
			var length: float = side[3]
			var yaw := atan2(nrm.x, nrm.y)
			var t := 0.5
			var run := 0.0
			while t < length - 0.4:
				var q: Vector2 = start + dir * t + nrm * 0.25
				if open.call(q):
					run += 0.5
				else:
					run = 0.0
				var w: Vector2 = start + dir * t
				var at := Vector3(w.x, 0.0, w.y)
				if run >= 1.0 and free_at.call(at, 1.4):
					var roll := rng.randf()
					if run >= 3.0 and boards < 3 and roll < 0.07 and open.call(q + dir * 0.6) and open.call(q - dir * 0.6):
						put.call("board", at + Vector3(0, 1.5, 0), yaw)
						boards += 1
					elif run >= 2.0 and extinguishers < 2 and roll > 0.985:
						put.call("extinguisher", at + Vector3(0, 0.7, 0), yaw)
						extinguishers += 1
					elif roll < 0.09:
						put.call("outlet", at + Vector3(0, 0.32, 0), yaw)
				t += 0.5
	var ceiling := root.find_child("CeilingMesh", true, false) as Node3D
	if ceiling == null:
		return
	var top := ceiling.global_position.y
	var lamps: Array[Vector3] = []
	for l in root.find_children("*", "OmniLight3D", true, false):
		lamps.append(l.global_position)
	for r in floors:
		var x := r.position.x + 1.0
		while x < r.end.x:
			var z := r.get_center().y
			var near := lamps.any(func(l: Vector3) -> bool: return Vector2(l.x - x, l.z - z).length() < 1.4)
			if not near:
				var roll := rng.randf()
				var at := Vector3(x + rng.randf_range(-0.3, 0.3), top - 0.03, z + rng.randf_range(-0.3, 0.3))
				if roll < 0.16:
					put.call("vent", Vector3(x, top - 0.031, z), 0.0)
				elif roll < 0.27:
					put.call("smoke", at - Vector3(0, 0.003, 0), 0.0)
				elif roll < 0.4:
					put.call("sprinkler", at + Vector3(0, 0.014, 0), 0.0)
			x += 2.0
	var door := root.find_child("Exit", true, false) as Node3D
	if door:
		var s := fixture("exit_sign")
		root.add_child(s)
		s.global_position = Vector3(door.global_position.x, top, door.global_position.z)
		s.global_rotation.y = door.global_rotation.y

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
# Each light's flat panel becomes a recessed fluorescent fitting: it stays up there when the light
# dies, its tubes just go dark.
static func lights(lights: Array) -> void:
	for l in lights:
		var panel := l.get_node_or_null("Panel") as Node3D
		if panel and panel.visible and l.get_parent():
			panel.visible = false
			var t := fixture("troffer")
			_props(t)
			l.get_parent().add_child(t)
			t.position = l.position + Vector3.UP * (panel.position.y + 0.03 - 0.062)   # flush with the ceiling
			t.rotation = l.rotation
			var tubes: Array[StandardMaterial3D] = []
			for mi: MeshInstance3D in t.find_children("*", "MeshInstance3D", true, false):
				for i in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(i) as StandardMaterial3D
					if m and m.emission_enabled:
						m.emission = l.light_color
						m.emission_energy_multiplier = 3.0
						tubes.append(m)
			l.visibility_changed.connect(func():
				for m in tubes:
					m.emission_energy_multiplier = 3.0 if l.visible else 0.0)
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
