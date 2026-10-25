# พี่สมชาย: stands like a mannequin; only moves when you are NOT looking at him.
# Scene: scenes/mobs/guard.tscn
class_name Guard
extends Npc

## Stays where the stage put him (at his CCTV monitors) until the lights first go out or his phone is taken
@export var waits_for_dark := false
var waiting := false
var wake := 3.0
var step_d := 0.0
var _home_yaw := 0.0

func _init() -> void:
	display_name = "พี่สมชาย"
	speed = 2.7
	drain = 40.0
	anim_fps = 8.0
	catch_line = "พี่สมชาย: ไปไหนครับ... ไม่ต้องรีบ เดี๋ยวผมไปส่งถึงบ้านนะ"
	death_text = "พี่สมชายยืนจ้องหน้าเงียบ ๆ อยู่ตรงนั้นจนถ่านหมด"
	scare_color = Color(0.02, 0.02, 0.02)
	scare_sfx = "whisper"
	can_stalk = false   # he only moves when nobody is looking: his own kind of stalking

# Jumpscare: he only stares. The lights die; when they come back he's against your face,
# head tilted. Nobody saw him move.
func jumpscare(p: Node3D) -> float:
	face_player()
	body.pose(0.0, "idle")
	var lamp: bool = p.flashlight.visible
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_callback(func():
		_lights(false)
		p.flashlight.visible = false
		Game.sfx("whisper", null, 2.0 + SCARE_DB)
		global_position = lunge_point(0.5)
		body.parts.Head.rotation.z = 0.5)
	t.tween_interval(0.3)
	t.tween_callback(func():
		_lights(true)
		p.flashlight.visible = lamp)
	t.tween_interval(0.15)
	return 0.75

func _lights(on: bool) -> void:
	for l in level.lights:
		l.visible = on

# Cutscene: between two camera shots he has turned to face you. Nobody saw him move.
# Caught feeding (cut_feed): he stops chewing and gets up slowly as he turns.
func cut_turn() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		face(cam.global_position - global_position)
	if _feed:
		_feed.kill()
		_feed = null
		var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		t.tween_property(body, "rotation:x", 0.0, 1.0)
		t.tween_property(body, "position:y", _feed_y, 1.0)
		t.tween_property(body.parts.Head, "rotation:x", -0.15, 1.0)   # chin down, eyes up at you
		for arm in ["ArmL", "ArmR"]:
			t.tween_property(body.parts[arm], "rotation:x", -0.35, 1.0)

# ---------- stage 4 intro: on his knees by the guard desk, eating something ----------
var _feed: Tween          # the chewing loop
var _feed_y := 0.0        # body height before he knelt
var _fed := false         # posture to undo on reset()

# Kneels (legs sunk through the floor), hunched over a carcass, tearing at it. The carcass stays
# where it is after the cutscene; the blood stays on his mouth and hands.
func cut_feed() -> void:
	if not _fed:
		_feed_y = body.position.y
		_carcass(global_position - global_basis.z * 0.75)
		_blood()
	_fed = true
	body.position.y = _feed_y - 0.55
	body.rotation.x = -0.65
	for arm in ["ArmL", "ArmR"]:
		body.parts[arm].rotation.x = -0.9
	_feed = create_tween().set_loops()
	_feed.tween_property(body.parts.Head, "rotation:x", -0.7, 0.18)   # bite
	_feed.tween_callback(func(): Game.sfx("stab", self, -14.0, randf_range(0.55, 0.75)))
	_feed.tween_property(body.parts.Head, "rotation:x", -0.25, 0.3).set_delay(0.12)   # tear and chew
	_feed.parallel().tween_property(body, "rotation:x", -0.58, 0.3)
	_feed.tween_property(body, "rotation:x", -0.65, 0.25)
	_feed.tween_interval(randf_range(0.2, 0.5))

func _blood() -> void:
	var red := Body.mat(Color(0.45, 0.02, 0.02))
	var head: MeshInstance3D = body.parts.Head
	# the realistic body's head and arms are empty joints: their sizes are known instead
	var hb := AABB(Vector3(-0.08, -0.03, -0.105), Vector3(0.16, 0.25, 0.2)) if body.real else head.get_aabb()
	var c := hb.get_center()
	_blob(head, red, Vector3(c.x, hb.position.y + hb.size.y * 0.28, hb.position.z - 0.01), Vector3(hb.size.x * 0.55, hb.size.y * 0.16, 0.03))   # round the mouth
	_blob(head, red, Vector3(c.x + hb.size.x * 0.1, hb.position.y + hb.size.y * 0.1, hb.position.z - 0.012), Vector3(0.05, hb.size.y * 0.25, 0.03))   # down the chin
	for arm in ["ArmL", "ArmR"]:
		if body.real:
			_blob(body.parts[arm], red, Vector3(0, -0.66, -0.01), Vector3(0.11, 0.15, 0.1))   # hands
			continue
		var m := body.parts[arm] as MeshInstance3D
		if m:
			var ab := m.get_aabb()
			_blob(m, red, Vector3(ab.get_center().x, ab.position.y + 0.07, ab.get_center().z), Vector3(ab.size.x + 0.02, 0.15, ab.size.z + 0.02))   # hands

func _blob(on: Node3D, m: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	if body.real:   # smeared, not boxed
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		b.mesh = sm
		b.scale = size
	else:
		var bm := BoxMesh.new()
		bm.size = size
		b.mesh = bm
	b.material_override = m
	b.position = pos
	on.add_child(b)
	return b

# Whatever it was: a torn lump in a pool of blood, ribs sticking up, a bone, and the chicken rice
# packet from his duty log, unopened.
func _carcass(at: Vector3) -> void:
	var c := Node3D.new()
	c.name = "Carcass"
	level.add_child(c)
	c.global_position = Vector3(at.x, 0.0, at.z)
	c.rotation.y = rotation.y + 0.4
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 0.8
	cm.height = 0.01
	pool.mesh = cm
	pool.material_override = Body.mat(Color(0.22, 0.01, 0.01))
	pool.position.y = 0.006
	c.add_child(pool)
	_blob(c, Body.mat(Color(0.42, 0.07, 0.06)), Vector3(0, 0.13, 0), Vector3(0.8, 0.26, 0.42))
	_blob(c, Body.mat(Color(0.3, 0.03, 0.03)), Vector3(0.25, 0.27, 0.05), Vector3(0.3, 0.06, 0.3))
	var bone := Body.mat(Color(0.85, 0.8, 0.7))
	for i in 4:
		var r := _blob(c, bone, Vector3(-0.2 + i * 0.13, 0.32, 0), Vector3(0.035, 0.035, 0.42))
		r.rotation.x = 0.35 if i % 2 else -0.35
	var leg := _blob(c, bone, Vector3(-0.55, 0.06, 0.25), Vector3(0.5, 0.06, 0.06))
	leg.rotation.y = 0.6
	var pack := _blob(c, Body.mat(Color(0.92, 0.9, 0.82)), Vector3(0.75, 0.04, -0.45), Vector3(0.26, 0.08, 0.18))
	pack.rotation.y = -0.3

func init_in(lvl: Node3D, pts: Array[Vector3]) -> void:
	super(lvl, pts)
	_home_yaw = rotation.y
	waiting = waits_for_dark

func reset() -> void:
	super()
	wake = 3.0
	rotation.y = _home_yaw   # back at his monitors, back turned
	waiting = waits_for_dark

func watched() -> bool:
	var cam: Camera3D = Game.player.cam
	# lights out and no flashlight: you're staring into black, he can move (unless he's at your nose)
	if level.dark and not Game.player.flashlight.visible and global_position.distance_to(cam.global_position) > 2.5:
		return false
	for h in [1.8, 1.0]:
		var p: Vector3 = global_position + Vector3.UP * h
		if cam.is_position_in_frustum(p):
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return true
	return false

func _think(dt: float) -> void:
	if waiting:   # watching you on the monitors: only the dark, or his phone going missing, gets him up
		if not (level.dark or Game.phone_taken or raging):
			velocity = Vector3.ZERO
			return
		waiting = false
	wake -= dt
	if (wake > 0.0 and not raging) or watched():
		velocity = Vector3.ZERO
		return
	face(Game.player.global_position - global_position)
	go_to(Game.player.global_position, speed * (1.3 if raging else 1.0), dt)
	step_d += speed * dt
	if step_d > 1.6:
		step_d = 0.0
		Game.sfx("footstep0%d" % randi_range(0, 3), self)
