# เต้: crawls from desk to desk (random), squats under one for a while, and when you walk past
# he scrambles out and grabs your legs. Talks tech at you. Scene: scenes/mobs/goblin.tscn
class_name Goblin
extends Npc

const GRAB_R := 2.4          # walk this close to his desk and he comes for your legs
const SNEAK_R := 1.3         # ...unless you creep past crouched
const WINDUP := 0.35         # desk rattles, then he lunges: a beat to react

var desks: Array[Area3D] = []   # the stage's under-desk hide spots = his dens
var den: Area3D                 # desk he's heading to / squatting under
var under := false              # tucked under `den`
var lurk := 0.0                 # seconds left under it
var ambush_t := 0.0             # >0 while scrambling out at you
var checked: Area3D             # desk he already looked under while you held your breath: he doesn't come back to it
var _slide: Tween

func _init() -> void:
	display_name = "เต้"
	speed = 1.6
	chase_speed = 3.7
	eye_h = 0.5
	view = 8.0
	fov = 100.0
	drain = 30.0
	anim_mode = "crawl"
	leashed = false   # goes desk to desk, not after you
	catch_line = "เต้: จับขาได้แล้ว~! รู้จัก Kubernetes ป่ะ? DNS มัน resolve ไม่ได้เพราะว่า... (อีก 45 นาที)"
	death_text = "โดนเต้ลากขาเข้าใต้โต๊ะ แล้วชวนคุยเรื่องการ์ตูนกับ DNS จนถ่านหมด"
	scare_color = Color(0.04, 0.3, 0.1)
	scare_sfx = "techspeak"

func init_in(lvl: Node3D, pts: Array[Vector3]) -> void:
	super(lvl, pts)
	for a in lvl.find_children("*", "Area3D", true, false):
		if a.get("hide_type") == "desk":
			desks.append(a)

# Jumpscare: he's got your ankle. You look down into his upturned face at your feet, he yanks,
# then his face rushes up into yours.
func jumpscare(_p: Node3D) -> float:
	_kill_slide()
	under = false
	face_player()
	_posture(false)
	body.pose(0.0, "crawl")
	body.parts.Head.rotation.x = 1.7   # craning up at you
	body.parts.ArmL.rotation.x = -1.9  # both hands reaching for your legs
	body.parts.ArmR.rotation.x = -1.9
	# lying flat, his head sticks out well ahead of his origin: place him by where the face ends up
	var h: Vector3 = scare_target() - global_position
	var reach := Vector2(h.x, h.z).length()
	global_position = lunge_point(reach + 0.7)
	var t := create_tween()
	t.tween_interval(0.22)
	t.tween_callback(Game.sfx.bind("techspeak", self, 6.0 + SCARE_DB))
	t.tween_property(body.parts.ArmL, "rotation:x", -1.2, 0.12)   # yank
	t.parallel().tween_property(body.parts.ArmR, "rotation:x", -1.2, 0.12)
	# climbs up you: face rushes in just under your eyes (higher and his chest blocks it)
	t.tween_property(self, "global_position", lunge_point(reach + 0.3), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "position:y", 0.5, 0.1)
	t.parallel().tween_property(body.parts.Head, "rotation:z", 0.45, 0.1)
	return 0.5

func _style() -> void:
	_posture(false)

func _posture(standing: bool) -> void:
	body.rotation.x = 0.0 if standing else -1.2
	body.parts.Head.rotation.x = 0.0 if standing else 1.2
	body.position.y = 0.0 if standing else 0.35
	anim_mode = "walk" if standing else "crawl"
	eye_h = 1.6 if standing else 0.5

# Cutscene: bursts up from under the desk.
func cut_pop() -> void:
	_posture(false)
	body.position.y = -1.2
	var t := create_tween()
	t.tween_property(body, "position:y", 0.35, 0.25)
	t.tween_callback(func():
		_posture(true)
		Game.sfx("techspeak", self)
		Game.sfx("sting", self, -6.0))

# Cutscene: drops down onto all fours.
func cut_crawl() -> void:
	_stop_writhe()
	_free_twin()
	body.parts.Head.position.x = 0.0
	_posture(false)
	Game.sfx("techspeak", self, 0.0, 0.6)

var _writhe: Tween    # cut_writhe's twitch loop
var _twin: Node3D     # cut_split's second head

# Cutscene: on his feet in the aisle, convulsing - every limb jerking somewhere new, a few times a second.
func cut_writhe() -> void:
	_posture(true)
	_writhe = create_tween().set_loops()
	_writhe.tween_callback(_twitch)
	_writhe.tween_interval(0.11)

func _twitch() -> void:
	body.rotation.z = randf_range(-0.35, 0.35)
	body.rotation.x = randf_range(-0.3, 0.25)
	body.parts.Head.rotation = Vector3(randf_range(-0.7, 0.6), randf_range(-0.8, 0.8), randf_range(-1.0, 1.0))
	for p in ["ArmL", "ArmR"]:
		body.parts[p].rotation.x = randf_range(-2.6, 0.6)
		body.parts[p].rotation.z = randf_range(-0.8, 0.8)
	for p in ["LegL", "LegR"]:
		body.parts[p].rotation.x = randf_range(-0.5, 0.5)
	if randf() < 0.3:   # joints cracking
		Game.sfx("creak%d" % randi_range(1, 3), self, -6.0, randf_range(0.5, 0.8))

# Cutscene: stops dead and snaps round to face you... and his head comes apart into two,
# leaning away from each other. A second later it snaps back together as if nothing happened.
func cut_split(hold := 1.4) -> void:
	_stop_writhe()
	var cam := get_viewport().get_camera_3d()
	if cam:
		face(cam.global_position - global_position)
	var head: Node3D = body.parts.Head
	_twin = head.duplicate()
	body.parts.Neck.add_child(_twin)
	Game.sfx("sting", self)
	Game.sfx("techspeak", self, 4.0, 0.5)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(head, "position:x", -0.16, 0.12)
	t.tween_property(head, "rotation:z", 0.55, 0.12)
	t.tween_property(_twin, "position:x", 0.16, 0.12)
	t.tween_property(_twin, "rotation:z", -0.55, 0.12)
	t.chain().tween_interval(hold)
	t.chain().tween_callback(func():
		head.position.x = 0.0
		head.rotation.z = 0.0
		Game.sfx("metalClick", self, -4.0)
		_free_twin())

func _stop_writhe() -> void:
	if _writhe:
		_writhe.kill()
		_writhe = null
	body.rotation = Vector3.ZERO
	body.parts.Head.rotation = Vector3.ZERO
	for p in ["ArmL", "ArmR", "LegL", "LegR"]:
		body.parts[p].rotation = Vector3.ZERO

func _free_twin() -> void:
	if is_instance_valid(_twin):
		_twin.queue_free()
	_twin = null

func reset() -> void:
	_kill_slide()
	if _writhe or _twin:
		_stop_writhe()
		_free_twin()
		body.parts.Head.position.x = 0.0
	super()
	den = null
	checked = null
	under = false
	lurk = 0.0
	ambush_t = 0.0
	_posture(false)

func _kill_slide() -> void:
	if _slide and _slide.is_valid():
		_slide.kill()
	_slide = null

func _sliding() -> bool:
	return _slide != null and _slide.is_running()

# Tucked under a desk he only reacts to you walking up, not to sight or noise.
func sees_player(any_angle := false) -> bool:
	return not under and super(any_angle)

func hear(pos: Vector3) -> void:
	if not under and not _sliding():
		super(pos)

# Anything that sends him after you (seen, search) first gets him out from under the desk.
func spot() -> void:
	_leave_den()
	super()
	_posture(true)
	Game.sfx("techspeak", self)
	Game.say("เต้: เฮ้ย! IP? DNS? 01101!! รู้จัก Kubernetes ป่ะ!?", 3.0)

func search(s: Area3D) -> void:
	_leave_den()
	checked = s   # one look per time you get in, or holding your breath could never outlast him
	super(s)

func _leave_den() -> void:
	_kill_slide()
	if under and den:
		global_position = Vector3(den.front.x, global_position.y, den.front.z)
	under = false
	lurk = 0.0
	ambush_t = 0.0

func _think(dt: float) -> void:
	var p: Node3D = Game.player
	if not p.hidden:
		checked = null
	elif state == "patrol" and p.spot.hide_type == "desk" and p.spot != checked \
			and global_position.distance_to(p.spot.front) < 12.0:
		search(p.spot)   # under-desk is HIS territory: he checks it
		Game.say("เต้: ...มีใครมาแย่งที่ใต้โต๊ะผมเหรอ?", 2.5)
		return
	match state:
		"ambush":
			ambush_t -= dt
			if _sliding():
				velocity = Vector3.ZERO   # wind-up: scrambling out from under the desk
			elif ambush_t > 0.0:
				go_to(p.global_position, chase_speed * 1.25, dt)   # low and fast, at your legs
			else:
				spot()   # missed you: stands up and gives chase
		"patrol":
			_den_tick(dt)
		_:
			super(dt)
			if state == "patrol":
				_posture(false)

func _den_tick(dt: float) -> void:
	if desks.is_empty():   # map without desks: plain route patrol
		super._think(dt)
		return
	if _sliding():
		velocity = Vector3.ZERO
		return
	var p: Node3D = Game.player
	if under:
		velocity = Vector3.ZERO
		lurk -= dt
		var r := SNEAK_R if p.crouching else GRAB_R
		if not p.hidden and near_player(r):
			_ambush()
		elif lurk <= 0.0:   # bored: crawl out, pick another desk
			under = false
			_slide = create_tween()
			_slide.tween_property(self, "global_position", Vector3(den.front.x, global_position.y, den.front.z), 0.5)
			den = null
		return
	if den == null or den == p.spot:
		var free := desks.filter(func(d): return d != p.spot)   # not the one you are under: he just looked there
		if free.is_empty():
			velocity = Vector3.ZERO
			return
		den = free.pick_random()
	if go_to(den.front, speed, dt):   # at the desk: slip underneath, facing out
		face(den.front - den.inside)
		under = true
		lurk = randf_range(6.0, 12.0)
		_slide = create_tween()
		_slide.tween_property(self, "global_position", Vector3(den.inside.x, global_position.y, den.inside.z), 0.5)
		return
	alert = clampf(alert + (1.6 if sees_player() else -0.5) * dt, 0.0, 1.0)
	if alert >= 1.0 or (not p.hidden and near_player(2.0)):   # hidden: he just searched it and found nothing
		spot()

# You walked up to his desk: the desk rattles, then he scrambles out low at your legs.
func _ambush() -> void:
	under = false
	state = "ambush"
	ambush_t = 1.2
	alert = 1.0
	face_player()
	Game.sfx("chair_creak", self, 4.0)
	Game.sfx("sting", self, -8.0)
	Game.say("เต้: ...ขาใครเนี่ย? ขอจับหน่อย~", 2.0)
	_slide = create_tween()
	_slide.tween_property(self, "global_position", Vector3(den.front.x, global_position.y, den.front.z), WINDUP)
