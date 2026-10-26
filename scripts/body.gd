# Low-poly PSX character, modelled in Blender (assets/characters/<model>.blend -> .glb, built by
# tools/blender/build_characters.py, see EDITING.md). Rigid parts that rotate at the joints, like
# PS1 games: LegL/LegR/ArmL/ArmR/Torso + Neck (NeckMesh, Head). Faces -Z (Godot forward).
# @tool: pick a `preset` (Story.BODIES key) in the Inspector and the character shows in the editor.
@tool
class_name Body
extends Node3D

const PSX := preload("res://shaders/psx.gdshader")
const FADE := preload("res://shaders/psx_fade.gdshader")
const PARTS := ["LegL", "LegR", "ArmL", "ArmR", "Torso", "Neck"]
static var _mats := {}

@export var preset := "":
	set(v):
		preset = v
		if is_inside_tree():
			_rebuild()

var parts := {}
var built_spec := {}   # what build() was given (a copy of this character: goblin.gd cut_split)
var neck_len := 0.1
var head_size := 0.42
var _fade_mats: Array = []
# HD look: a realistic skinned model (assets/characters/real/, tools/blender/build_humans.py).
# `parts` are then stand-ins at the bones; whatever turns them, the bones follow (_process).
var real := false
var _skel: Skeleton3D
var _bones := {}      # part -> bone index
var _rest := {}       # part -> its stand-in's first position
const REAL_PARTS := ["Torso", "Chest", "LegL", "LegR", "ShinL", "ShinR", "ArmL", "ArmR", "ForearmL", "ForearmR", "Neck", "Head"]
# The joints the rigid models never had (knees, elbows, upper back): their stand-ins sit inside
# the old parts, so code that swings a whole leg or arm still works, and new poses can bend them.
const REAL_SUB := {"Chest": "Torso", "ShinL": "LegL", "ShinR": "LegR", "ForearmL": "ArmL", "ForearmR": "ArmR"}
var _driven: Array[String] = []   # stand-ins whose bone follows them (_process)
const REAL_SCALE := 1.08   # the MakeHuman people are life-size; a touch taller looms over Tong

static func mat(color: Color, tex: Texture2D = null, emit := Color.BLACK) -> ShaderMaterial:
	var key := str(color) + str(tex) + str(emit)
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PSX
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("emission", Vector3(emit.r, emit.g, emit.b))
		if tex:
			m.set_shader_parameter("albedo_tex", tex)
		_mats[key] = m
	return _mats[key]

func _ready() -> void:
	if parts.is_empty() and preset != "":
		build(Story.BODIES[preset])

func _rebuild() -> void:
	for c in get_children():
		c.free()
	parts.clear()
	if Story.BODIES.has(preset):
		build(Story.BODIES[preset])

# spec keys: model (assets/characters/<model>.glb), face (2D portrait for HUD/jumpscare), neck
# Parts are added at runtime (no owner), so they never get saved into scenes.
func build(spec: Dictionary) -> Body:
	built_spec = spec
	var real_path := "res://assets/characters/real/%s.glb" % spec.model
	if not Engine.is_editor_hint() and not Game.retro and ResourceLoader.exists(real_path):
		return _build_real(spec, real_path)
	var src: Node = load("res://assets/characters/%s.glb" % spec.model).instantiate()
	for n in PARTS:
		var part: Node3D = src.get_node(n)
		src.remove_child(part)
		part.owner = null   # it belonged to the .glb scene: no owner in ours (and no warning)
		add_child(part)
		parts[n] = part
	src.free()
	parts.NeckMesh = parts.Neck.get_node("NeckMesh")
	parts.Head = parts.Neck.get_node("Head")
	head_size = (parts.Head as MeshInstance3D).get_aabb().end.y
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():   # Blender colours, redrawn with the PSX shader
			var sm := m.mesh.surface_get_material(i)
			var emit := Color.BLACK   # glowing eyes (Emission in Blender)
			if sm is BaseMaterial3D and sm.emission_enabled:
				emit = sm.emission * sm.emission_energy_multiplier
			m.set_surface_override_material(i, mat(sm.albedo_color if sm is BaseMaterial3D else Color.WHITE, null, emit))
	set_neck(spec.get("neck", neck_len))
	return self

func _build_real(spec: Dictionary, path: String) -> Body:
	real = true
	var src: Node3D = load(path).instantiate()
	add_child(src)
	src.scale = Vector3.ONE * REAL_SCALE
	_skel = src.find_children("*", "Skeleton3D", true, false)[0]
	var to_body: Transform3D = src.transform * _skel.transform
	for p in REAL_PARTS:
		_bones[p] = _skel.find_bone(p)
	var at := func(p: String) -> Vector3: return to_body * _skel.get_bone_global_rest(_bones[p]).origin
	for p in ["Torso", "LegL", "LegR", "ArmL", "ArmR", "Neck"]:
		var n := Node3D.new()
		n.name = p
		n.position = at.call(p)
		add_child(n)
		parts[p] = n
	parts.NeckMesh = Node3D.new()   # (the rigid model's neck block: here only its scale is read)
	parts.Neck.add_child(parts.NeckMesh)
	var head := MeshInstance3D.new()   # typed like the rigid head (code adds things to it)
	head.name = "Head"
	parts.Neck.add_child(head)
	parts.Head = head
	_rest.Neck_head = at.call("Head") - at.call("Neck")
	_driven.assign(["Torso", "LegL", "LegR", "ArmL", "ArmR", "Neck"])
	for p in REAL_SUB:
		if _bones[p] < 0:   # (a model built before the rig had them)
			continue
		var n := Node3D.new()
		n.name = p
		n.position = at.call(p) - at.call(REAL_SUB[p])
		parts[REAL_SUB[p]].add_child(n)
		parts[p] = n
		_driven.append(p)
	for p in _driven:
		_rest[p] = parts[p].position
	head_size = 0.24 * REAL_SCALE
	for m: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, real_mat(m.mesh.surface_get_material(i)))
	set_neck(spec.get("neck", neck_len))
	set_process(true)
	return self

# The realistic model's materials: vertex colours (skin tone, lips, clothes, blood) with a fine
# detail normal map, and the glow on the night faces' eyes.
static func real_mat(src: Material) -> Material:
	var key := "real_" + src.resource_name
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = {"skin": 0.5, "eye": 0.12, "eye_glow": 0.2, "teeth": 0.35, "hair": 0.55, "shoes": 0.3}.get(src.resource_name, 0.85)
	match src.resource_name:
		"skin":
			m.normal_enabled = true
			m.normal_texture = HD.texture("plastic_n")
			m.normal_scale = 0.25
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 6.0
			m.rim_enabled = true   # a little skin-like light at the edges
			m.rim = 0.25
			m.rim_tint = 0.6
		"shirt", "pants", "skirt":
			m.normal_enabled = true
			m.normal_texture = HD.texture("fabric_n")
			m.normal_scale = 0.25
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 5.0
		"hair":
			m.normal_enabled = true
			m.normal_texture = HD.texture("wood_n")   # long grain: strands
			m.normal_scale = 0.8
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 4.0
		_ when src.resource_name.begins_with("glow_"):   # night eyes: "glow_ff2a18"
			m.emission_enabled = true
			m.emission = Color(src.resource_name.trim_prefix("glow_"))
			m.emission_energy_multiplier = 4.0
	_mats[key] = m
	return m

# The stand-ins drive the bones (rest rotations are all identity: tools/blender/build_humans.py).
func _process(_dt: float) -> void:
	if not real or not is_instance_valid(_skel):
		return
	for p in _driven:
		var i: int = _bones[p]
		_skel.set_bone_pose_rotation(i, parts[p].quaternion)
		_skel.set_bone_pose_position(i, _skel.get_bone_rest(i).origin + (parts[p].position - _rest[p]) / REAL_SCALE)
	var h: int = _bones.Head
	_skel.set_bone_pose_rotation(h, parts.Head.quaternion)
	# the head rides up its neck: the stand-in sits `neck_len` up, the real head at its rest
	_skel.set_bone_pose_position(h, _skel.get_bone_rest(h).origin + Vector3(parts.Head.position.x, parts.Head.position.y - 0.1, parts.Head.position.z) / REAL_SCALE)

# NeckMesh is 1 m tall from its base: its y scale is the neck length.
func set_neck(length: float) -> void:
	neck_len = length
	parts.NeckMesh.scale.y = length
	parts.Head.position.y = length

func head_top() -> float:
	if real:
		return parts.Neck.position.y + _rest.Neck_head.y + (neck_len - 0.1) + 0.17 * REAL_SCALE
	return parts.Neck.position.y + neck_len + head_size

# 0 = gone .. 1 = solid, dithered in between (psx_fade.gdshader). The first call gives this body
# its own materials, so nobody else sharing the colours fades with it.
func set_fade(a: float) -> void:
	if real:
		if _fade_mats.is_empty():
			for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
				if m.mesh == null:
					continue
				for i in m.mesh.get_surface_count():
					var f: StandardMaterial3D = m.get_surface_override_material(i).duplicate()
					f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH   # dithered, no sorting
					m.set_surface_override_material(i, f)
					_fade_mats.append(f)
		visible = a > 0.0
		for f in _fade_mats:
			f.albedo_color.a = a
		return
	if _fade_mats.is_empty():
		for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			for i in m.mesh.get_surface_count():
				var f := ShaderMaterial.new()
				f.shader = FADE
				var src := m.get_surface_override_material(i) as ShaderMaterial
				f.set_shader_parameter("albedo", src.get_shader_parameter("albedo"))
				f.set_shader_parameter("emission", src.get_shader_parameter("emission"))
				m.set_surface_override_material(i, f)
				_fade_mats.append(f)
	visible = a > 0.0
	for f in _fade_mats:
		f.set_shader_parameter("fade", a)

# Stepped (12 fps) poses: t is already quantised by the caller.
func pose(t: float, mode: String) -> void:
	var swing := sin(t * 9.0) * 0.6
	match mode:
		"walk":
			parts.LegL.rotation.x = swing; parts.LegR.rotation.x = -swing
			parts.ArmL.rotation.x = -swing; parts.ArmR.rotation.x = swing
		"shuffle":
			swing = sin(t * 20.0) * 0.35
			parts.LegL.rotation.x = swing; parts.LegR.rotation.x = -swing
			parts.ArmL.rotation.x = 0.0; parts.ArmR.rotation.x = -0.6
		"slide":
			parts.LegL.rotation.x = 0.0; parts.LegR.rotation.x = 0.0
			parts.ArmR.rotation.x = -0.4 + sin(t * 6.0) * 0.5
			parts.ArmL.rotation.x = -2.6 + sin(t * 3.0) * 0.3
		"crawl":
			parts.LegL.rotation.x = 1.4 + swing * 0.5; parts.LegR.rotation.x = 1.4 - swing * 0.5
			parts.ArmL.rotation.x = -1.4 - swing * 0.5; parts.ArmR.rotation.x = -1.4 + swing * 0.5
		_:
			for p in ["LegL", "LegR", "ArmL", "ArmR"]:
				parts[p].rotation.x = 0.0
