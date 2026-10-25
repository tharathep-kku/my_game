# Live 3D head for the 2D UI (menu, HUD, death jumpscare, game over, endings): the character's
# actual Blender model in its own little world, rendered at low res and scaled up with nearest
# filtering, so it's the PSX look and it's the same face you meet in the game. It's a TextureRect,
# so size / scale / position / pivot work like any picture.
class_name FaceView
extends TextureRect

## How far the head sways left-right (radians). 0 = still.
var turn := 0.25
## 0..1: trembling (low Social Battery, jumpscare).
var shake := 0.0
## 1 = normal head-and-shoulders framing; bigger = the camera pushes into the face.
var zoom := 1.0
var preset := ""
var body: Body
var _vp: SubViewport
var _cam: Camera3D
var _head_y := 1.7
var _t := randf() * 10.0
# The Compatibility renderer (web) lights in sRGB: same numbers come out far brighter. Tone it down.
var _k := 0.45 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0
var _key: DirectionalLight3D
var _rim: DirectionalLight3D
var _env: Environment

func _init(p := "", res := 96) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Game.retro else CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(res, res) * (1 if Game.retro else 3)   # HD look: a sharp portrait, not pixels
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Game.retro else Viewport.MSAA_4X
	_vp.own_world_3d = true   # never shares the stage's world/lights
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_env = Environment.new()
	var env := _env
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6) * _k
	_cam.environment = env
	_vp.add_child(_cam)
	_key = DirectionalLight3D.new()   # from above-front-left: the nose and brow cast shadows down
	var key := _key
	key.shadow_enabled = true   # brow shadows the eyes, nose shadows the cheek: that is what reads as 3D
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 4.0
	key.rotation = Vector3(-0.6, PI - 0.5, 0.0)   # lights shine along -Z: turn it round to face the face
	key.light_energy = 1.3 * _k
	_vp.add_child(key)
	_rim = DirectionalLight3D.new()   # horror only: red light from behind, outlining the head
	_rim.rotation = Vector3(-0.3, 0.4, 0.0)
	_rim.light_color = Color(1, 0.15, 0.1)
	_rim.light_energy = 2.5 * _k
	_rim.visible = false
	_vp.add_child(_rim)
	texture = _vp.get_texture()
	if p != "":
		set_preset(p)

# Jumpscare lighting: lit from below like a torch under the chin, near-black ambient, red rim.
func set_horror(on: bool) -> void:
	_key.rotation = Vector3(0.9, PI + 1.0, 0.0) if on else Vector3(-0.6, PI - 0.5, 0.0)   # horror: low and from the side
	_key.light_color = Color(1, 0.85, 0.7) if on else Color.WHITE
	_key.light_energy = (1.9 if on else 1.3) * _k
	_env.ambient_light_color = (Color(0.07, 0.05, 0.06) if on else Color(0.55, 0.55, 0.6)) * _k
	_rim.visible = on

func set_preset(p: String) -> void:
	if p == preset:
		return
	preset = p
	if is_instance_valid(body):
		body.free()
	body = Body.new()
	_vp.add_child(body)
	body.build(Story.BODIES[p])
	_head_y = body.head_top() - body.head_size * 0.55

func _process(dt: float) -> void:
	if not is_instance_valid(body) or not is_visible_in_tree():
		return
	_t += dt
	body.rotation.y = sin(_t * 0.6) * turn
	var j := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.012 * shake
	body.parts.Head.rotation.z = randf_range(-1, 1) * 0.06 * shake
	_cam.position = Vector3(0, _head_y + 0.02, -1.45 / zoom) + j   # the body faces -Z: stand in front
	_cam.look_at(Vector3(0, _head_y - 0.04, 0) + j * 0.5)
