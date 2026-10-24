# Stage 0: an ordinary Friday afternoon that turns into the night shift. Half cutscene, half play.
#   day     bright office, everyone at work (coworker.gd). A stranger texts: nothing works until
#           you open the phone and read it (Tab). The texts are the controls; they come in one
#           at a time while the phone is open.
#   meet    walk round and talk to every coworker (E)
#   dusk    the clock runs on to `night_clock`: the daylight goes and they leave one by one
#   rumour  the stranger texts again (locked until read): the night-shift story
#   mirror  go to the washroom mirror. Tong stares at himself for `hold_secs`... then they fade
#           in behind him, with the music, and it cuts to black -> stage 1.
# Children (drag them in the editor): MirrorPlane = middle of the mirror, its blue arrow (Z) pointing
# INTO the mirror · MirrorSpot = box in front of it that starts the ending.
# The "mirror" is a hole in the wall with a copy of the washroom behind it; Tong's reflection is a
# stand-in body moved to the mirrored spot every frame.
extends Node3D

const HIT_AT := 6.5   # seconds into mirror_theme.wav where it hits (tools/synth_music.py HIT)
# Who fades in: [preset, metres right of Tong, metres behind the glass]
const BEHIND := [["sweeper", -1.6, 3.0], ["manager", -0.5, 3.7], ["goblin", 1.0, 3.3], ["guard", 1.7, 2.8]]

@export_group("Stranger's texts")
## Who the texts come from (phone thread)
@export var sender := "เบอร์ไม่รู้จัก"
## First texts: the controls. One bubble per entry.
@export var controls: PackedStringArray = []
## Texts once night has fallen: the night-shift rumour, and the nudge toward the mirror
@export var rumour: PackedStringArray = []
@export_group("Day to night")
@export var day_clock := "17:30"
@export var night_clock := "23:30"
## Seconds the daylight takes to go
@export var dusk_secs := 18.0
@export_multiline var night_line := "ต๋อง: ...เงียบจัง เหลือเราคนเดียวอีกแล้วสินะ"
@export_group("Mirror ending")
@export_multiline var mirror_line := "ต๋อง: ...หน้าโทรมชะมัด เครียดสะสมจริงๆ ด้วย"
## Seconds Tong just looks at himself before anything happens
@export var hold_secs := 3.0
## How long หัวหน้าธนา's neck gets as he fades in
@export var neck := 1.05

var phase := "day"   # day -> read1 -> meet -> dusk -> night -> read2 -> mirror -> end
var _t := 0.0
var _buzz := 0.0
var pending: Array[String] = []   # the stranger's texts still to come: one at a time, while Tong reads
var _reading := false             # the phone is open
var _type_t := 0.0
var _in_spot := false
var _skip := false
var _amb_db := 0.0
var _reflection: Body
var _black: ColorRect
@onready var lvl: Node3D = get_parent()
@onready var plane: Node3D = $MirrorPlane
@onready var spot: Area3D = $MirrorSpot

func _ready() -> void:
	if StageBuilder.baking:
		return
	# An editor save has dropped these text lists from the scene before (the game then froze on the
	# first text): story.gd keeps a copy, so an empty list falls back to it.
	if controls.is_empty():
		controls = PackedStringArray(Story.TUTORIAL.phone.controls)
	if rumour.is_empty():
		rumour = PackedStringArray(Story.TUTORIAL.phone.rumour)
	for c in lvl.get_node("Coworkers").get_children():
		for d in Story.TUTORIAL.coworkers:
			if c is Coworker and c.lines.is_empty() and d.display_name == c.display_name:
				c.lines = PackedStringArray(d.lines)
	_amb_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Amb"))
	Game.clock = day_clock
	Game.event.connect(_on_event)
	Game.skip_cutscene.connect(_on_skip)
	spot.body_entered.connect(func(b): if b == Game.player: _in_spot = true)
	spot.body_exited.connect(func(b): if b == Game.player: _in_spot = false)
	_reflection = Body.new()
	lvl.add_child.call_deferred(_reflection)
	_reflection.build(Story.BODIES.tong)
	_daylight.call_deferred()   # the stage sets its lights and the player up after us

# No fog by day, so you can see the length of the office: nothing may pop out at the fog's edge.
func _daylight() -> void:
	lvl.set_gloom(0.0)
	lvl.player.cam.far = 70.0
	for g: GeometryInstance3D in lvl.get_node("NavRegion").find_children("*", "GeometryInstance3D", true, false):
		g.visibility_range_end = 0.0
	for l: OmniLight3D in lvl.lights:
		l.distance_fade_enabled = false

func coworkers() -> Array:
	var all: Array = lvl.get_node("Coworkers").get_children().filter(func(c): return c is Coworker and not c.is_queued_for_deletion())
	all.sort_custom(func(a, b): return a.leave_at < b.leave_at)
	return all

func _on_event(what: String) -> void:
	if what == "phone":
		_reading = true
	if what != "phone_read":
		return
	_reading = false
	if not pending.is_empty():   # put it away before he'd finished: it isn't done with Tong yet
		Game.phone_lock = true
		return
	if phase == "read1":
		phase = "meet"
		for c in coworkers():
			lvl._marker(c, Color(1, 0.85, 0.1), c.body.head_top() + 0.35, 9999.0, c.display_name)
		_meet_objective()
	elif phase == "read2":
		phase = "mirror"
		Game.objective_changed.emit("ไปล้างหน้าที่ห้องน้ำ แล้วส่องกระจกดู")
		lvl._marker(spot, Color(1, 0.85, 0.1), 0.6, 9999.0, "กระจก")

func _meet_objective() -> void:
	var all := coworkers()
	Game.objective_changed.emit("เดินไปทักทายเพื่อนร่วมงาน (มองแล้วกด E)  %d/%d" % [all.filter(func(c): return c.talked).size(), all.size()])

# The stranger texts and Tong can do nothing else until he has read it all (main.gd close_phone
# unlocks). Only the first text arrives now; the rest are typed out one by one once the phone is
# open, each after time to read the one before, so they never pile up.
func _lock(texts: PackedStringArray, next: String) -> void:
	phase = next
	_buzz = 2.5
	pending.assign(texts)
	Game.phone_lock = true
	Game.objective_changed.emit("มีข้อความเข้า! กด [Tab] เปิดมือถืออ่าน")
	_send_next()

func _send_next() -> void:
	var m: String = pending.pop_front()
	Game.text(sender, m)
	_type_t = clampf(m.length() * 0.05, 1.8, 4.0)   # reading time, then "typing..."
	Game.typing = not pending.is_empty()
	if pending.is_empty():
		Game.objective_changed.emit("อ่านจบแล้วกด [ESC] ปิดมือถือ")

func _texting(dt: float) -> void:
	if _reading and not pending.is_empty():
		_type_t -= dt
		if _type_t <= 0.0:
			_send_next()
		return
	_buzz -= dt
	if _buzz <= 0.0 and Game.phone_lock and not _reading:   # it keeps buzzing until you look
		_buzz = 2.5
		Game.sfx("vibrate", null, -6.0)

func _process(dt: float) -> void:
	var p: Node3D = Game.player
	if not is_instance_valid(p):
		return
	_mirror(p)
	if Game.busy or Game.in_cutscene:
		return
	_t += dt
	match phase:
		"day":
			if _t > 1.2:
				_lock(controls, "read1")
		"read1", "read2":
			_texting(dt)
		"meet":
			for c in coworkers():
				if c.talked and c.has_node("RevealMarker"):
					c.get_node("RevealMarker").free()
					Game.sfx("pickup", null, -6.0)
					_meet_objective()
			if coworkers().all(func(c): return c.talked):
				phase = "dusk"
				_t = 0.0
				Game.objective_changed.emit("...เวลาผ่านไป")
		"dusk":
			_dusk()
		"night":   # a beat alone in the dark office before the phone buzzes again
			if _t > 3.0:
				_lock(rumour, "read2")
		"mirror":
			if _in_spot and not p.hidden:
				_ending()

# Daylight drains, the clock races to night, and they go home one by one.
func _dusk() -> void:
	var k := clampf(_t / dusk_secs, 0.0, 1.0)
	lvl.set_gloom(smoothstep(0.0, 1.0, k))
	var a := day_clock.get_slice(":", 0).to_int() * 60 + day_clock.get_slice(":", 1).to_int()
	var b := night_clock.get_slice(":", 0).to_int() * 60 + night_clock.get_slice(":", 1).to_int()
	var mins := int(lerpf(a, b, k))
	@warning_ignore("integer_division")
	Game.clock = "%02d:%02d" % [mins / 60, mins % 60]
	var all := coworkers()
	if not all.is_empty() and k >= lerpf(0.12, 0.85, all[0].leave_at):
		_leave(all[0])
	if k >= 1.0 and all.is_empty():
		Game.say(night_line, 3.5)
		Game.objective_changed.emit("")
		phase = "night"
		_t = 0.0

func _leave(c: Coworker) -> void:
	if c.bye != "":
		Game.say(c.bye, 3.0)
	c.leave_at = 2.0   # sorted last: the next one's turn
	await get_tree().create_timer(2.2, false).timeout
	if not is_instance_valid(c):
		return
	# Nobody sees them walk out. Looking right at them: the lights blink and they're not there.
	if Game.player.cam.is_position_in_frustum(c.global_position + Vector3.UP * 1.4):
		lvl.blackout(0.3)
	else:
		Game.sfx("doorOpen_1", null, -10.0)
	c.queue_free()

# ---------- mirror ----------
# Tong's reflection: the stand-in body at his position / heading flipped through the mirror plane.
func _mirror(p: Node3D) -> void:
	if not is_instance_valid(_reflection) or not _reflection.is_inside_tree():
		return
	var local: Vector3 = plane.to_local(p.global_position)
	_reflection.visible = local.z < 0.0 and local.length() < 8.0   # only while he's in the washroom
	if not _reflection.visible:
		return
	local.z = -local.z
	_reflection.global_position = plane.to_global(local)
	var n: Vector3 = plane.global_basis.z
	var f: Vector3 = (-p.global_basis.z).bounce(n)
	_reflection.rotation.y = atan2(-f.x, -f.z)

# Seconds, cut short when the ending is skipped (hold Space, like any cutscene).
func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()

func _on_skip() -> void:
	if phase == "end":
		_skip = true

func _ending() -> void:
	phase = "end"
	var p: Node3D = Game.player
	if Game.skip_cutscenes:
		_finish()
		return
	Game.in_cutscene = true   # letterbox, HUD off, Tong's hands off the controls
	Game.cutscene_changed.emit(true)
	Game.objective_changed.emit("")
	p.crouching = false
	p.flashlight.visible = false
	# he walks up to the glass and looks himself in the eye
	var into: Vector3 = plane.global_basis.z
	var stand: Vector3 = plane.global_position - into * 1.3
	var cam: Camera3D = p.cam
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(p, "global_position", Vector3(stand.x, p.global_position.y, stand.z), 1.0)
	t.tween_property(p, "rotation:y", p.rotation.y + angle_difference(p.rotation.y, atan2(-into.x, -into.z)), 1.0)
	t.tween_property(cam, "rotation:x", 0.0, 1.0)
	t.tween_property(cam, "fov", 50.0, 1.0 + hold_secs + HIT_AT)   # one slow push-in to the end
	t.tween_method(_ambience, _amb_db, -50.0, 2.0)   # the office hum drains away
	await _wait(1.0)
	Game.say(mirror_line, hold_secs)
	await _wait(hold_secs)   # just Tong and his own tired face
	# ...and then he isn't alone
	if not _skip:
		Game.sfx("mirror_theme").bus = "Master"   # dry, like the jumpscare sounds
	Game.say("", 0.1)
	var red := create_tween().set_parallel()
	for l: OmniLight3D in lvl.lights:
		if l.global_position.distance_to(plane.global_position) < 8.0:
			red.tween_property(l, "light_color", Color(0.85, 0.2, 0.15), HIT_AT)
			red.tween_property(l, "light_energy", l.light_energy * 1.4, HIT_AT)   # red reads dim: push it
	for i in BEHIND.size():
		var b := Body.new()
		lvl.add_child(b)
		b.build(Story.BODIES[BEHIND[i][0]])
		b.global_position = plane.to_global(Vector3(-BEHIND[i][1], 0.0, BEHIND[i][2]))
		var d: Vector3 = plane.global_position - b.global_position   # all facing the glass: facing him
		b.rotation.y = atan2(-d.x, -d.z)
		b.set_fade(0.0)
		var ft := b.create_tween()
		ft.tween_interval(i * 0.7)
		ft.tween_method(b.set_fade, 0.0, 1.0, HIT_AT - 2.6)
		if BEHIND[i][0] == "manager":   # his head rises over Tong's shoulder as he comes into view
			ft.parallel().tween_method(b.set_neck, b.neck_len, neck, HIT_AT - 2.6)
		ft.tween_property(b.parts.Head, "rotation:z", [0.45, -0.3, 0.5, -0.4][i % 4], 0.25).set_delay(0.3)
	await _wait(HIT_AT)
	_black = ColorRect.new()   # hard cut on the hit (a 2D rect inside the 3D view: the subtitles stay)
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(_black)
	lvl.add_child(layer)
	await _wait(2.6)   # the boom rings out in the dark
	_finish()

func _ambience(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), db)

# Tutorial over: main.gd fades out and starts stage 1.
func _finish() -> void:
	Game.busy = true
	Game.stage_cleared.emit()

# Whatever we changed that outlives the level (skipped from the pause menu, quit to the menu...).
func _exit_tree() -> void:
	if StageBuilder.baking:
		return
	_ambience(_amb_db)
	Game.phone_lock = false
	Game.typing = false
	Game.clock = ""
	if phase == "end" and Game.in_cutscene:
		Game.in_cutscene = false
		Game.cutscene_changed.emit(false)
