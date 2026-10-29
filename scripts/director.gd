# The fear director: one per chapter (stage.gd adds it). It keeps the night's rhythm so nobody is
# on Tong all the time: quiet -> the coworker comes looking somewhere near him, out of view (stalk)
# -> a chase if it sees him -> it withdraws to the far side for a while (relief). In between come
# things that can't hurt him but get under his skin, and the stranger texts what he is doing.
# Everything here is tuning: the times, the lines, which events come in which chapter.
class_name Director
extends Node

## Quiet seconds before a coworker comes looking for him (less as Social Battery falls)
@export var stalk_every := Vector2(45.0, 75.0)
## Seconds a coworker keeps to the far side after a chase / a catch
@export var relief_secs := Vector2(28.0, 42.0)
## Seconds between psychological events (less as Social Battery falls)
@export var event_every := Vector2(28.0, 48.0)
## Seconds between texts that react to what Tong is doing
@export var react_every := Vector2(45.0, 80.0)
## Opening seconds of a chapter when its ghost is only heard, kept out of sight (ends early with the
## first thing collected); then it is shown to him once, on purpose (_reveal)
@export var veil_secs := 75.0

const STRANGER := "เบอร์ไม่รู้จัก"
# What the stranger texts when Tong... (each line once per night)
const REACT := {
	"hide": ["ในนั้นแคบนะครับ ผมเคยเข้าไปนั่งเหมือนกัน", "หายใจเบาๆ หน่อยครับ ได้ยินถึงข้างนอกเลย", "ซ่อนเก่งจังครับ ...แต่ผมรู้ว่าตรงไหน"],
	"still": ["ยืนนิ่งทำไมครับ กำลังฟังเสียงผมอยู่เหรอ", "ไม่เดินต่อเหรอครับ ผมรออยู่นะ", "ยืนตรงนั้นแหละครับ ดีแล้ว"],
	"light": ["ไฟฉายสวยดีครับ ผมเห็นจากอีกฝั่งของชั้นเลย", "ปิดไฟเถอะครับ เดี๋ยวคนอื่นเห็นคุณก่อนผม", "ส่องหาอะไรอยู่ครับ ผมไม่ได้อยู่ตรงนั้นหรอก"],
	"run": ["วิ่งไปไหนครับ ตึกนี้ไม่มีทางออกหรอก", "อย่าวิ่งครับ เสียงดัง", "เหนื่อยไหมครับ"],
	"crouch": ["ก้มต่ำๆ แบบนั้น... คิดว่าผมมองไม่เห็นเหรอครับ", "เดินย่องเหมือนคุณฝนเลยครับ"],
	"turn": ["หันมาทำไมครับ ผมไม่ได้อยู่ข้างหลัง... ตอนนี้", "เกือบเห็นแล้วนะครับ"],
	"read": ["อ่านแล้วอย่าเชื่อหมดนะครับ บางใบผมเขียนเอง", "ลายมือผมสวยไหมครับ"],
}
const MONITOR := ["ต๋อง กลับบ้านไม่ได้", "งานคืบหน้า 0%", "ข้างหลัง", "ตื่นสิ", "02:14", "คุณหลับอยู่", "แม่รออยู่"]
const SELF := ["อย่าหันหลัง", "ฉันยังนั่งอยู่ที่โต๊ะ", "ใครกำลังเดินอยู่ตอนนี้", "ตื่นได้แล้ว", "เราออกไปจากที่นี่ไม่ได้"]
# Events by how far into the night it is (chapter index): early ones stay in the pool later on.
const EVENTS := [
	[0, "steps"], [0, "whisper"], [0, "lights"], [0, "hum"], [0, "printer"],
	[1, "peripheral"], [1, "monitor"], [2, "silence"], [2, "clock"],
	[3, "self_text"], [4, "mum_call"],
	# the office changes when he isn't looking
	[0, "papers"], [1, "chair"], [1, "screen"], [2, "lights_behind"], [3, "phone"],
]

var lvl: Node3D
var menace := 0.0          # 0..1: how close a coworker has been lately
var calm_t := 50.0         # until a coworker comes looking
var event_t := 30.0        # until the next psychological event
var react_t := 35.0        # until a reactive text may come
var steps_t := 0.0         # footsteps behind him (event): seconds left
var _step_d := 0.0
var _steps_yaw := 0.0
var _was := {}             # npc -> its state last frame (a chase ending = relief)
var _caught_by: Node = null
var _used := {}            # lines and one-off events already used tonight
var _still := 0.0
var _hide := 0.0
var _light := 0.0
var _run := 0.0
var _crouch := 0.0
var _yaw := 0.0
var _silent := false
var hallu_t := 40.0        # low Social Battery: until the next thing that isn't there
var veil_t := 75.0
var revealed := false
var _clock_was := ""

func _ready() -> void:
	lvl = get_parent()
	calm_t = randf_range(stalk_every.x, stalk_every.y)
	event_t = randf_range(event_every.x, event_every.y) * 0.7
	veil_t = veil_secs
	revealed = lvl.npcs.is_empty() or lvl.get("raging") == true
	Game.caught.connect(_on_caught)   # methods, not lambdas: they go away with this node
	Game.event.connect(_on_event)

func _on_caught(n: Node) -> void:
	_caught_by = n

func _on_event(what: String) -> void:
	if what == "read" and react_t <= 0.0:
		_react("read")

func _exit_tree() -> void:   # never leave the office silent or the clock stuck
	if _silent:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Amb"), false)
	if _clock_was != "":
		Game.clock = _clock_was if _clock_was != "-" else ""

# 0..1, how frayed Tong is (low Social Battery): everything comes sooner.
func fray() -> float:
	return clampf((70.0 - Game.battery) / 60.0, 0.0, 1.0)

func _process(dt: float) -> void:
	var p: Node3D = Game.player
	if not is_instance_valid(p) or Game.in_cutscene or Game.busy:
		return
	var chasing := false
	for n in lvl.npcs:
		chasing = chasing or n.state == "chase"
	if not revealed:
		_veil(dt, p)
	else:
		_rhythm(dt, p)
	_footsteps(dt, p)
	if lvl.gloom < 0.5:   # nothing creepy by daylight
		return
	if not chasing:
		_hallucinate(dt)
		event_t -= dt * lerpf(1.0, 1.7, fray())
		if event_t <= 0.0:
			event_t = randf_range(event_every.x, event_every.y)
			fire(_pick_event())
	_watch_player(dt, p)

# ---------- rhythm ----------
func _rhythm(dt: float, p: Node3D) -> void:
	if is_instance_valid(_caught_by):   # caught and back at the checkpoint: whoever did it backs off
		for n in lvl.npcs:
			n.retreat(_far_point(n), randf_range(relief_secs.x, relief_secs.y) + 10.0)
		_caught_by = null
		menace = 0.0
		calm_t = maxf(calm_t, stalk_every.x)
	var near := INF
	for n in lvl.npcs:
		var was: String = _was.get(n, "patrol")
		if was == "chase" and n.state != "chase" and n.state != "away" and not n.raging:
			# lost him: a last look around where it saw him, then it withdraws for a while
			get_tree().create_timer(4.5, false).timeout.connect(_relieve.bind(n))
		_was[n] = n.state
		var d: float = n.global_position.distance_to(p.global_position)
		near = minf(near, d)
		if n.state == "chase":
			menace += dt * 0.3
		elif d < 8.0:
			menace += dt * 0.2
		elif d < 14.0:
			menace += dt * 0.08
	if near > 14.0:
		menace -= dt * 0.05
	menace = clampf(menace, 0.0, 1.0)
	if menace >= 1.0:   # it has been on him a long time without a catch: it backs off (relief)
		for n in lvl.npcs:
			if n.state != "chase":
				_relieve(n)
		menace = 0.35
	if near > 14.0:
		calm_t -= dt * lerpf(1.0, 1.6, fray())
	if calm_t <= 0.0:
		calm_t = randf_range(stalk_every.x, stalk_every.y)
		stalk()

func _relieve(n: Node) -> void:
	if is_instance_valid(n) and n.state != "chase" and not n.raging:
		n.retreat(_far_point(n), randf_range(relief_secs.x, relief_secs.y))

# The point of its patrol farthest from Tong.
func _far_point(n: Node) -> Vector3:
	var best: Vector3 = n.home
	var best_d := -1.0
	var pts: Array = n.route.duplicate()
	pts.append(n.home)
	for r in pts:
		var d: float = r.distance_to(Game.player.global_position)
		if d > best_d:
			best_d = d
			best = r
	return best

# A coworker comes to somewhere near Tong he can't see from where he is, and looks around.
func stalk() -> bool:
	var p: Node3D = Game.player
	var who: Node = null
	for n in lvl.npcs:
		if n.can_stalk and n.state == "patrol" and not n.raging:
			who = n
			break
	if who == null:
		return false
	var map: RID = lvl.get_world_3d().navigation_map
	var space := lvl.get_world_3d().direct_space_state
	var fwd: Vector3 = -p.global_basis.z
	var best := Vector3.INF
	var best_score := -INF
	for i in 90:
		var q := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := q.distance_to(p.global_position)
		if d < 8.0 or d > 16.0:
			continue
		var head := q + Vector3.UP * 1.6
		var ray := PhysicsRayQueryParameters3D.create(p.eye(), head, 1)
		if p.cam.is_position_in_frustum(head) and space.intersect_ray(ray).is_empty():
			continue   # he'd see it walk up: not that
		var to := (q - p.global_position).normalized()
		var score := -to.dot(fwd) - absf(d - 11.0) * 0.1   # behind him, about 11 m off
		if score > best_score:
			best_score = score
			best = q
	if best == Vector3.INF:
		return false
	who.state = "investigate"
	who.inv_pos = best
	who.inv_t = 7.0   # lingers, looking round
	who.repath = 0.0
	return true

# ---------- what he does: the stranger notices ----------
func _watch_player(dt: float, p: Node3D) -> void:
	react_t -= dt
	var moving: bool = Vector2(p.velocity.x, p.velocity.z).length() > 0.3
	_still = (_still + dt) if (not moving and not p.hidden) else 0.0
	_hide = (_hide + dt) if p.hidden else 0.0
	_light = (_light + dt) if p.flashlight.visible else 0.0
	_run = (_run + dt) if Vector2(p.velocity.x, p.velocity.z).length() > 3.7 else 0.0   # faster than a walk
	_crouch = (_crouch + dt) if (p.crouching and moving) else 0.0
	var yaw: float = p.rotation.y
	var turned := absf(wrapf(yaw - _yaw, -PI, PI)) > 2.2   # spun round in a moment
	_yaw = lerp_angle(_yaw, yaw, minf(dt * 3.0, 1.0))
	if react_t > 0.0:
		return
	if _hide > 7.0:
		_react("hide")
	elif _still > 11.0:
		_react("still")
	elif _light > 9.0:
		_react("light")
	elif _run > 4.0:
		_react("run")
	elif _crouch > 10.0:
		_react("crouch")
	elif turned:
		_react("turn")

func _react(kind: String) -> bool:
	var lines: Array = REACT[kind].filter(func(l): return not _used.has(l))
	if lines.is_empty():
		return false
	var line: String = lines.pick_random()
	_used[line] = true
	Game.text(STRANGER, line)
	react_t = randf_range(react_every.x, react_every.y)
	return true

# ---------- psychological events ----------
func _pick_event() -> String:
	var pool: Array = EVENTS.filter(func(e): return e[0] <= Game.stage and not _used.has(e[1]))
	if pool.is_empty():
		return "steps"
	var e: Array = pool.pick_random()
	if e[1] in ["mum_call", "clock"]:   # once a night is enough for these
		_used[e[1]] = true
	return e[1]

func fire(kind: String) -> void:
	var p: Node3D = Game.player
	match kind:
		"steps":   # someone a few steps behind, matching his pace; stops when he stops or turns
			steps_t = 7.0
			_steps_yaw = p.rotation.y
		"whisper":
			_sound("whisper", p.global_position + p.global_basis.z * 1.2 + Vector3.UP * 1.6, 0.0)
			Game.say("(เสียงกระซิบ ข้างหลัง... \"ต๋อง\")", 2.5)
		"lights":   # the tubes die one by one, toward him, then come back
			var ls: Array = lvl.lights.filter(func(l): return l.global_position.distance_to(p.global_position) < 22.0)
			ls.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) > b.global_position.distance_to(p.global_position))
			for i in ls.size():
				get_tree().create_timer(i * 0.14, false).timeout.connect(func(): if is_instance_valid(ls[i]): ls[i].visible = false)
			get_tree().create_timer(ls.size() * 0.14 + 1.6, false).timeout.connect(_lights_back)
		"hum":   # Mum's lullaby, from somewhere on the floor
			var at := _floor_point(12.0, 20.0)
			if at != Vector3.INF:
				_sound("hum", at + Vector3.UP * 1.5, -2.0)
				Game.say("(เสียงฮัมเพลงกล่อมเด็ก... เพลงที่แม่เคยร้องตอนต๋องเด็กๆ)", 3.5)
		"printer":   # a printer starts on its own, near him
			var at := _floor_point(6.0, 12.0)
			if at != Vector3.INF:
				_sound("printer", at + Vector3.UP, 0.0)
		"peripheral":   # someone at the edge of his eye; gone when he looks
			_peripheral()
		"monitor":   # words on a dead screen, ahead of him
			_monitor()
		"silence":   # every sound stops... then a breath at his neck
			_silent = true
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Amb"), true)
			get_tree().create_timer(6.0, false).timeout.connect(_breath)
		"clock":   # the clock jumps to 02:14 for a moment
			if _clock_was == "":
				_clock_was = Game.clock if Game.clock != "" else "-"
				Game.clock = "02:14"
				get_tree().create_timer(4.0, false).timeout.connect(_clock_back)
		"self_text":   # a text from his own number
			var lines: Array = SELF.filter(func(l): return not _used.has(l))
			if not lines.is_empty():
				var l: String = lines.pick_random()
				_used[l] = true
				Game.text("ต๋อง", l)
		"papers", "chair", "screen", "lights_behind", "phone":
			_anomaly(kind)
		"mum_call":   # Mum calls: only breathing, then the line goes dead
			Game.sfx("vibrate", null, -2.0)
			Game.say("(สายเรียกเข้า: แม่ ...ไม่มีเสียงพูด มีแต่เสียงหายใจช้าๆ แล้วสายก็ตัดไป)", 4.0)
			get_tree().create_timer(6.0, false).timeout.connect(Game.text.bind("แม่", "ลูกโทรหาแม่เหรอ แม่ไม่ได้ยินอะไรเลย มีแต่เสียงเครื่องช่วยหายใจ"))

func _footsteps(dt: float, p: Node3D) -> void:
	if steps_t <= 0.0:
		return
	steps_t -= dt
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	if v < 0.3 or absf(wrapf(p.rotation.y - _steps_yaw, -PI, PI)) > 2.0:
		steps_t = 0.0   # he stopped, or turned round: nothing there, and silence
		return
	_step_d += v * dt
	if _step_d > 1.3:
		_step_d = 0.0
		_sound("footstep0%d" % randi_range(0, 3), p.global_position + p.global_basis.z * 2.6, -2.0)

func _lights_back() -> void:
	if is_instance_valid(lvl):
		for l in lvl.lights:
			l.visible = not lvl.dark

func _breath() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Amb"), false)
	_silent = false
	var p: Node3D = Game.player
	if is_instance_valid(p):
		var a := _sound("breathing", p.global_position + p.global_basis.z * 0.6 + Vector3.UP * 1.6, 2.0)
		get_tree().create_timer(1.6, false).timeout.connect(func(): if is_instance_valid(a): a.queue_free())

func _clock_back() -> void:
	Game.clock = _clock_was if _clock_was != "-" else ""
	_clock_was = ""

func _peripheral() -> void:
	var p: Node3D = Game.player
	var cam: Camera3D = p.cam
	var fwd: Vector3 = -cam.global_basis.z
	var space := lvl.get_world_3d().direct_space_state
	var map: RID = lvl.get_world_3d().navigation_map
	for i in 30:
		var q := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := q.distance_to(p.global_position)
		var head := q + Vector3.UP * 1.7
		var to := (head - cam.global_position).normalized()
		var ang := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))
		if d < 8.0 or d > 18.0 or absf(ang) < 24.0 or absf(ang) > 34.0 or not cam.is_position_in_frustum(head):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(p.eye(), head, 1)).is_empty():
			var who: Array = lvl.npcs.map(func(n): return n.body.preset)
			lvl._figure(who.pick_random() if not who.is_empty() else "staff", q, 2.5, false, "")
			return

func _monitor() -> void:
	var p: Node3D = Game.player
	var eye: Vector3 = p.eye()
	var dir: Vector3 = -p.global_basis.z
	var hit := lvl.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * 10.0, 1))
	if hit.is_empty() or eye.distance_to(hit.position) < 3.0:
		return
	var l := Label3D.new()
	l.text = MONITOR.pick_random()
	l.font = Kit.TITLE
	l.font_size = 72
	l.outline_size = 0
	l.pixel_size = 0.006
	l.modulate = Color(0.85, 1.0, 0.9)
	l.no_depth_test = false
	l.shaded = false
	l.double_sided = true
	lvl.add_child(l)
	l.global_position = hit.position + hit.normal * 0.04
	l.look_at(l.global_position - hit.normal, Vector3.UP)
	_sound("printer", l.global_position, -10.0)
	var t := l.create_tween()
	for k in 3:
		t.tween_property(l, "modulate:a", 0.2, 0.08)
		t.tween_property(l, "modulate:a", 1.0, 0.08)
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)

# A spot on the floor dist_min..dist_max from Tong (INF: none found).
func _floor_point(dist_min: float, dist_max: float) -> Vector3:
	var map: RID = lvl.get_world_3d().navigation_map
	for i in 20:
		var q := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := q.distance_to(Game.player.global_position)
		if d >= dist_min and d <= dist_max:
			return q
	return Vector3.INF

func _sound(sfx_name: String, at: Vector3, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = Game.stream(sfx_name)
	a.bus = "SFX"
	a.volume_db = db + Game.mix_db(sfx_name)
	a.add_to_group("occlude")
	a.unit_size = 4.0
	a.finished.connect(a.queue_free)
	lvl.add_child(a)
	a.global_position = at
	a.play()
	return a

# ---------- the office changes when he isn't looking ----------
# Only ever somewhere he can't see at that moment; chairs and screens are not solid, so nothing
# ends up in his way. Each prop moves once a night.
func _unseen(at: Vector3) -> bool:
	var p: Node3D = Game.player
	if not p.cam.is_position_in_frustum(at):
		return true
	return not lvl.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.eye(), at, 1)).is_empty()

# Kenney furniture of one kind (the holders the stage placed), near enough and out of sight.
func _props_of(model: String, dmin: float, dmax: float, movable := true) -> Array:
	var p: Node3D = Game.player
	var out := []
	for n in lvl.find_children("*", "Node3D", true, false):
		if not n.scene_file_path.ends_with("/%s.glb" % model):
			continue
		var h: Node3D = n.get_parent()
		if (movable and h is CollisionObject3D) or h.has_meta("moved"):
			continue
		var d := h.global_position.distance_to(p.global_position)
		if d >= dmin and d <= dmax and _unseen(h.global_position + Vector3.UP * 0.6):
			out.append(h)
	return out

func _anomaly(kind: String) -> bool:
	var p: Node3D = Game.player
	match kind:
		"chair":   # an office chair rolls out into the aisle, turned to face him
			var cs := _props_of("chairDesk", 4.0, 14.0)
			if cs.is_empty():
				return false
			var c: Node3D = cs.pick_random()
			c.set_meta("moved", true)
			var to: Vector3 = p.global_position - c.global_position
			to.y = 0.0
			var t := create_tween().set_trans(Tween.TRANS_SINE)
			t.tween_property(c, "global_position", c.global_position + to.normalized() * 0.9, 1.3)
			t.parallel().tween_property(c, "rotation:y", c.rotation.y + wrapf(atan2(to.x, to.z) - c.rotation.y, -PI, PI), 1.3)   # (a chair faces +z)
			_sound("chair_creak", c.global_position + Vector3.UP * 0.5, -2.0)
			return true
		"screen":   # a screen that was turned away has turned round to face him
			var ss := _props_of("computerScreen", 3.0, 12.0)
			if ss.is_empty():
				return false
			var s: Node3D = ss.pick_random()
			s.set_meta("moved", true)
			var to: Vector3 = p.global_position - s.global_position
			create_tween().tween_property(s, "rotation:y", s.rotation.y + wrapf(atan2(to.x, to.z) - s.rotation.y, -PI, PI), 2.5).set_trans(Tween.TRANS_SINE)
			return true
		"lights_behind":   # the lights he just walked under go out, one by one, and stay out a while
			var fwd: Vector3 = -p.global_basis.z
			var ls: Array = lvl.lights.filter(func(l):
				var to: Vector3 = l.global_position - p.global_position
				var dd := Vector2(to.x, to.z).length()
				return l.visible and dd > 3.0 and dd < 16.0 and Vector2(to.x, to.z).dot(Vector2(fwd.x, fwd.z)) < 0.0)
			if ls.is_empty():
				return false
			ls.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
			for i in ls.size():
				get_tree().create_timer(0.35 * i, false).timeout.connect(func(): if is_instance_valid(ls[i]): ls[i].visible = false)
			get_tree().create_timer(20.0, false).timeout.connect(_lights_back)
			return true
		"papers":   # someone's papers all over the floor, just round the corner
			var at := Vector3.INF
			for i in 30:
				var q := _floor_point(4.0, 10.0)
				if q != Vector3.INF and _unseen(q + Vector3.UP * 0.1):
					at = q
					break
			if at == Vector3.INF:
				return false
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.88, 0.87, 0.82)
			m.roughness = 0.9
			for i in 7:
				var sheet := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.21, 0.002, 0.297)
				sheet.mesh = bm
				sheet.material_override = m
				sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				lvl.add_child(sheet)
				sheet.global_position = at + Vector3(randf_range(-0.7, 0.7), 0.004 + i * 0.001, randf_range(-0.7, 0.7))
				sheet.rotation.y = randf() * TAU
			_sound("bookFlip1", at + Vector3.UP * 0.3, 0.0)
			return true
		"phone":   # a desk phone rings out of sight; it stops when he gets near it
			var at := Vector3.INF
			for it in lvl.get_node("Items").get_children():
				if it.get("kind") == "phone" and _unseen(it.global_position):
					at = it.global_position
			if at == Vector3.INF:
				var ds := _props_of("desk", 5.0, 16.0, false)
				if ds.is_empty():
					return false
				at = (ds.pick_random() as Node3D).global_position + Vector3.UP * 0.8
			var ring := _sound("phone_ring", at, -2.0)
			ring.finished.disconnect(ring.queue_free)
			ring.stream = Game.looped("phone_ring")
			ring.play()
			var stop := func():
				if is_instance_valid(ring):
					ring.queue_free()
			get_tree().create_timer(9.0, false).timeout.connect(stop)
			_watch_ring(ring)
			return true
	return false

func _watch_ring(ring: AudioStreamPlayer3D) -> void:
	while is_instance_valid(ring) and is_instance_valid(Game.player):
		if ring.global_position.distance_to(Game.player.global_position) < 3.0:
			ring.queue_free()   # he got to it: dead line
			return
		await get_tree().create_timer(0.2, false).timeout

# ---------- low Social Battery: things that aren't there (at most one every 40 s) ----------
func _hallucinate(dt: float) -> void:
	if Game.battery >= 40.0:
		hallu_t = maxf(hallu_t, 20.0)
		return
	hallu_t -= dt
	if hallu_t > 0.0:
		return
	hallu_t = randf_range(40.0, 65.0)
	if Game.phone_open:
		Game.hallucinate.emit("phone")
	else:
		approach()

# Its sound (pen, heels, keys, mop...) coming up behind him, step by step, getting close... and
# when he turns round, or it arrives, nothing. There was nobody there.
func approach() -> bool:
	var p: Node3D = Game.player
	var who: Node = null
	for n in lvl.npcs:
		if n.cue != "":
			who = n
	if who == null:
		return false
	var cue: String = who.cue
	var vars: int = who.cue_vars
	var back: Vector3 = p.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var from: Vector3 = p.global_position + back * 12.0 + Vector3.UP * 1.0
	var to: Vector3 = p.global_position + back * 2.0 + Vector3.UP * 1.0
	var yaw0: float = p.rotation.y
	var steps := 8
	for i in steps:
		if not is_instance_valid(p) or absf(wrapf(p.rotation.y - yaw0, -PI, PI)) > 2.0 or Game.busy:
			return true   # he turned round: silence
		_sound(("%s_%d" % [cue, randi() % vars]) if vars > 0 else cue, from.lerp(to, float(i) / (steps - 1)), -3.0 + i * 0.8)
		await get_tree().create_timer(0.75 - i * 0.04, false).timeout
	return true

# ---------- the opening: heard, not seen ----------
# Its sound carries across the floor but it keeps away; it is first seen when the director shows it.
func _veil(dt: float, p: Node3D) -> void:
	veil_t -= dt
	if veil_t <= 0.0 or Game.goal_count >= 1:
		_reveal()
		return
	for n in lvl.npcs:
		if n.state in ["patrol", "investigate"] and not n.raging and n.global_position.distance_to(p.global_position) < 16.0:
			n.retreat(_far_point(n), 6.0)

# The first sight of it: standing at the end of his view, facing him, still... its head comes round,
# and it walks away. (main.gd plays the sighting sting when it comes into view.)
func _reveal() -> void:
	revealed = true
	calm_t = randf_range(stalk_every.x, stalk_every.y) * 0.6
	var p: Node3D = Game.player
	var who: Node = null
	for n in lvl.npcs:
		if n.can_stalk and n.state != "chase" and not n.raging:
			who = n
			break
	if who == null or not _unseen(who.global_position + Vector3.UP * 1.4):
		return
	var cam: Camera3D = p.cam
	var map: RID = lvl.get_world_3d().navigation_map
	var space := lvl.get_world_3d().direct_space_state
	var fwd: Vector3 = -cam.global_basis.z
	for i in 40:
		var q := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := q.distance_to(p.global_position)
		var head := q + Vector3.UP * 1.6
		var to := (head - cam.global_position).normalized()
		if d < 10.0 or d > 18.0 or to.dot(fwd) < 0.85 or not cam.is_position_in_frustum(head):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(p.eye(), head, 1)).is_empty():
			who.global_position = q
			who.face(p.global_position - q)
			who.velocity = Vector3.ZERO
			who.state = "patrol"
			who._freeze_t = 2.6   # stands there; its head turns to him
			who._freeze_cd = 12.0
			get_tree().create_timer(2.8, false).timeout.connect(func():
				if is_instance_valid(who) and who.state != "chase":
					who.retreat(_far_point(who), 14.0))
			return
