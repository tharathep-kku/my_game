# Main menu backdrop: the office at night, seen through a security camera. The camera drifts along
# the desks; every so often the lights stutter, and when they come back someone is standing there.
class_name MenuBg
extends SubViewportContainer

const MAP := [
	"################",
	"#o.L....L....L.#",
	"#.D=D=D..D=D=D.#",
	"#..............#",
	"#.D=D=D..D=D=D.#",
	"#..............#",
	"#.D=D=D..D=D=D.#",
	"#o.L....L....L.#",
	"################",
]
const WHO := ["manager_long", "sweeper", "goblin", "guard", "hr", "staff"]

var vp: SubViewport
var cam: Camera3D
var lights: Array[OmniLight3D] = []
var figure: Body
var _t := 0.0
var _next := 7.0
var _shown := 0.0

func _init() -> void:
	stretch = true
	stretch_shrink = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true   # its own little world: never mixes with the stage
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(vp)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fx := ShaderMaterial.new()
	fx.shader = preload("res://shaders/vhs.gdshader")
	fx.set_shader_parameter("fear", 0.22)
	fx.set_shader_parameter("brightness", 1.4)
	material = fx
	var office := StageBuilder.build({"map": MAP, "goal": 0, "floor": Color(0.28, 0.32, 0.4),
		"wall": Color(0.55, 0.55, 0.5), "light": Color(0.75, 1.0, 0.82)}, {}, false)
	office.set_script(null)   # scenery: no stage logic, no player
	vp.add_child(office)
	for l in office.get_node("Lights").get_children():
		if l is OmniLight3D:
			lights.append(l)
	cam = Camera3D.new()
	cam.fov = 62.0
	vp.add_child(cam)
	cam.current = true
	figure = Body.new()
	vp.add_child(figure)
	figure.visible = false

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	var k := sin(_t * 0.08) * 0.5 + 0.5   # slow there-and-back pan, like a camera on a motor
	cam.position = Vector3(lerpf(5.0, 27.0, k), 2.6, 15.4)
	cam.look_at(Vector3(lerpf(9.0, 23.0, k), 1.0, 6.0))
	if randf() < 0.01 and not lights.is_empty():   # a dying tube
		var l: OmniLight3D = lights.pick_random()
		l.visible = not l.visible
	if _shown > 0.0:
		_shown -= dt
		if _shown <= 0.0:
			_blink(false)
	_next -= dt
	if _next <= 0.0:
		_next = randf_range(9.0, 16.0)
		_blink(true)

# Lights out for a moment; someone appears in the aisle (or is gone again).
func _blink(show_someone: bool) -> void:
	for l in lights:
		l.visible = false
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(figure):
		return
	if show_someone:
		figure.preset = WHO.pick_random()
		figure.position = Vector3(randf_range(10.0, 22.0), 0.0, randf_range(6.5, 11.0))
		var d := cam.global_position - figure.global_position
		figure.rotation.y = atan2(-d.x, -d.z)
		figure.visible = true
		_shown = 2.2
	else:
		figure.visible = false
	for l in lights:
		l.visible = true
