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
var neck_len := 0.1
var head_size := 0.42
var _fade_mats: Array[ShaderMaterial] = []

static func mat(color: Color, tex: Texture2D = null) -> ShaderMaterial:
	var key := str(color) + str(tex)
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PSX
		m.set_shader_parameter("albedo", color)
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
	var src: Node = load("res://assets/characters/%s.glb" % spec.model).instantiate()
	for n in PARTS:
		var part: Node3D = src.get_node(n)
		src.remove_child(part)
		add_child(part)
		parts[n] = part
	src.free()
	parts.NeckMesh = parts.Neck.get_node("NeckMesh")
	parts.Head = parts.Neck.get_node("Head")
	head_size = (parts.Head as MeshInstance3D).get_aabb().end.y
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():   # Blender colours, redrawn with the PSX shader
			var sm := m.mesh.surface_get_material(i)
			m.set_surface_override_material(i, mat(sm.albedo_color if sm is BaseMaterial3D else Color.WHITE))
	set_neck(spec.get("neck", neck_len))
	return self

# NeckMesh is 1 m tall from its base: its y scale is the neck length.
func set_neck(length: float) -> void:
	neck_len = length
	parts.NeckMesh.scale.y = length
	parts.Head.position.y = length

func head_top() -> float:
	return parts.Neck.position.y + neck_len + head_size

# 0 = gone .. 1 = solid, dithered in between (psx_fade.gdshader). The first call gives this body
# its own materials, so nobody else sharing the colours fades with it.
func set_fade(a: float) -> void:
	if _fade_mats.is_empty():
		for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			for i in m.mesh.get_surface_count():
				var f := ShaderMaterial.new()
				f.shader = FADE
				f.set_shader_parameter("albedo", (m.get_surface_override_material(i) as ShaderMaterial).get_shader_parameter("albedo"))
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
