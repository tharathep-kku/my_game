# Plays a step list from story.gd on its own camera. `await Cutscene.new().play(level, steps)`.
# Positions are in map cells: Vector3(cell_x, height_m, cell_z). Skip: hold Space (Game.SKIP_HOLD s).
# Steps:  ["cam", pos, look, secs]   move (secs > 0) or cut the camera
#         ["walk", pos, look, secs]  walk there on foot (head bob + footsteps), eyes turning to look
#         ["look", look, secs]       turn the head, stay put
#         ["player", secs]           glide into Tong's own eyes (end of an intro: control picks up there)
#         ["say", text, secs]        subtitle, waits secs
#         ["sub", text, secs]        subtitle, doesn't wait (talk over the next steps)
#         ["text", thread, msg]      phone message
#         ["sfx", name, "npc"?]      sound (optionally from the coworker)
#         ["wait", secs]  ["flash", kind]  ["lights", on]  ["fov", degrees]
#         ["npc", cell, look_cell]   place the stage coworker
#         ["act", method, args...]   call a cutscene method on the coworker (cut_peek, cut_pop...)
#         ["body", preset, cell, look_cell, id?]  spawn a posed extra (id = preset if not given)
#         ["run", pos, look, secs]   like walk, but running for your life: long strides, heavy bob, panting
#         ["move", who, cell, secs, anim?]  who = an extra's id or "npc": walks there (doesn't wait)
#         ["turn", who, look_cell]   who faces that cell
#         ["gone", who]              an extra vanishes (the lights blink)
#         ["neck", who, length, secs]  stretch who's neck (doesn't wait)
#         ["shake", strength, secs]  camera shake (doesn't wait)
#         ["scare", preset, sfx?]    their face slams full screen with a scream (non-lethal, 0.7 s)
#         ["fade", alpha, secs]      black over the picture (doesn't wait)
#         ["peephole", on]           door-viewer vignette
#         ["tint", color]            every ceiling light takes this colour
#         ["part", who, part, rot]   set a body part's rotation (Vector3, radians): "Head", "ArmL"...
#         ["warp", cell, look_cell]  put Tong there (mid-stage scenes: play picks up where he ran to)
# A stage cutscene starts in Tong's own eyes, so a mid-stage one can begin with "look"/"walk".
# Extras spawned in a stage intro are removed when it ends; in an ending they stay (and so does the
# last shot, until the ending fades out: an ending has no player camera to go back to).
class_name Cutscene
extends Node

const STRIDE := 0.8   # metres per footstep when walking
const RUN_STRIDE := 1.4

var level: Node3D
var cam: Camera3D
var skipping := false
var _active := false
var _look := Vector3.ZERO   # what the camera is looking at (world), so walks turn the head smoothly
var _stride := 0.0          # metres walked: bob phase + when the next footstep lands
var _bodies := {}           # extras by id ("body" steps)
var _shake := 0.0           # camera shake strength while _shake_t > 0
var _shake_t := 0.0

static func cell(v: Vector3) -> Vector3:
	return Vector3(v.x * 2.0 + 1.0, v.y, v.z * 2.0 + 1.0)

func play(lvl: Node3D, steps: Array) -> void:
	if Game.skip_cutscenes or steps.is_empty():
		queue_free()
		return
	level = lvl
	lvl.add_child(self)
	cam = Camera3D.new()
	cam.fov = 60
	cam.near = 0.05
	lvl.add_child(cam)
	if lvl.get("player") and is_instance_valid(lvl.player):
		cam.global_transform = lvl.player.cam.global_transform
	cam.current = true
	Game.in_cutscene = true
	Game.cutscene_changed.emit(true)
	Game.skip_cutscene.connect(_on_skip)
	_active = true
	var extras: Array[Node3D] = []   # พี่สมชาย cameos etc. standing about: not in anyone's cutscene
	for c in lvl.get("cameos") if lvl.get("cameos") != null else []:
		if is_instance_valid(c.body) and c.body.visible:
			c.body.visible = false
			extras.append(c.body)
	for st in steps:
		if skipping:
			break
		await _run(st)
	if not is_instance_valid(lvl):
		return
	for b in extras:
		if is_instance_valid(b):
			b.visible = true
	if lvl.get("dark") != null:   # flickered by "lights" steps (or skipped mid-flicker): back to the real state
		for l in lvl.lights:
			l.visible = not lvl.dark
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	Game.overlay.emit("")
	if lvl.player:   # a stage: back to Tong's eyes, intro extras gone
		cam.queue_free()
		lvl.player.cam.current = true
		for b in _bodies.values():
			if is_instance_valid(b):
				b.queue_free()
	_end()
	queue_free()

func _end() -> void:
	if _active:
		_active = false
		Game.in_cutscene = false
		Game.cutscene_changed.emit(false)

# Level freed mid-cutscene (quit to menu, tests): don't leave the game stuck in cutscene mode.
func _exit_tree() -> void:
	_end()

func _run(st: Array) -> void:
	match st[0]:
		"cam":
			var pos := cell(st[1])
			var xf := Transform3D.IDENTITY.looking_at(cell(st[2]) - pos).translated(pos)
			var secs: float = st[3] if st.size() > 3 else 0.0
			_look = cell(st[2])
			if secs <= 0.0:
				cam.global_transform = xf
			else:
				var tw := create_tween()
				tw.tween_property(cam, "global_transform", xf, secs).set_trans(Tween.TRANS_SINE)
				await _wait(secs)
				tw.kill()
		"walk":
			await _walk(cell(st[1]), cell(st[2]), st[3])
		"run":
			Game.sfx("breathing", null, -2.0)
			await _walk(cell(st[1]), cell(st[2]), st[3], true)
		"look":
			await _walk(cam.global_position, cell(st[1]), st[2])
		"player":
			if is_instance_valid(level.player):
				var tw := create_tween()
				tw.tween_property(cam, "global_transform", level.player.cam.global_transform, st[1]).set_trans(Tween.TRANS_SINE)
				await _wait(st[1])
				tw.kill()
				if not skipping:
					cam.global_transform = level.player.cam.global_transform
		"say":
			Game.say(st[1], st[2])
			await _wait(st[2])
		"sub":
			Game.say(st[1], st[2])
		"text":
			Game.text(st[1], st[2])
		"sfx":
			Game.sfx(st[1], level.npcs[0] if st.size() > 2 and not level.npcs.is_empty() else null)
		"wait":
			await _wait(st[1])
		"flash":
			Game.flash.emit(st[1])
		"fov":
			cam.fov = st[1]
		"lights":
			for l in level.lights:
				l.visible = st[1]
		"npc":
			var n: Npc = level.npcs[0]
			n.global_position = cell(Vector3(st[1].x, 0, st[1].z))
			n.face(cell(st[2]) - n.global_position)
		"act":
			level.npcs[0].callv(st[1], st.slice(2))
		"body":
			var b := Body.new()
			b.build(Story.BODIES[st[1]])
			level.add_child(b)
			b.global_position = cell(Vector3(st[2].x, st[2].y, st[2].z))
			var d := cell(st[3]) - b.global_position
			b.rotation.y = atan2(-d.x, -d.z)
			_bodies[st[4] if st.size() > 4 else st[1]] = b
		"move":
			_move(st[1], cell(Vector3(st[2].x, 0, st[2].z)), st[3], st[4] if st.size() > 4 else "walk")
		"turn":
			var w := _who(st[1])
			if w:
				var d := cell(st[2]) - w.global_position
				w.rotation.y = atan2(-d.x, -d.z)
		"gone":
			var w := _who(st[1])
			if w:
				Game.sfx("whisper", null, -8.0)
				for l in level.lights:
					l.visible = false
				w.visible = false
				await _wait(0.15)
				for l in level.lights:
					l.visible = true
		"neck":
			var w := _who(st[1])
			var b: Body = w if w is Body else (w.body if w else null)
			if b:
				create_tween().tween_method(b.set_neck, b.neck_len, st[2], st[3]).set_trans(Tween.TRANS_SINE)
		"shake":
			_shake = st[1]
			_shake_t = st[2]
		"scare":
			Game.scare_face.emit(st[1], st[2] if st.size() > 2 else "")
			await _wait(0.7)
		"fade":
			Game.fade.emit(st[1], st[2])
		"peephole":
			Game.overlay.emit("peephole" if st[1] else "")
		"tint":
			for l in level.lights:
				l.light_color = st[1]
		"warp":
			var p: Node3D = level.player
			if is_instance_valid(p):
				p.global_position = cell(Vector3(st[1].x, 0.0, st[1].z))
				var d := cell(st[2]) - p.global_position
				p.rotation.y = atan2(-d.x, -d.z)
				p.cam.rotation.x = 0.0
				p.velocity = Vector3.ZERO
		"part":
			var w := _who(st[1])
			var b: Body = w if w is Body else (w.body if w else null)
			if b:
				b.parts[st[2]].rotation = st[3]

# An extra by id, or the stage's coworker ("npc").
func _who(id: String) -> Node3D:
	if id == "npc":
		return level.npcs[0] if not level.npcs.is_empty() else null
	var b = _bodies.get(id)
	return b if is_instance_valid(b) else null

# Walks/shuffles/slides/crawls `who` to `to` over secs, facing the way it goes (doesn't wait).
func _move(id: String, to: Vector3, secs: float, anim: String) -> void:
	var w := _who(id)
	if not w:
		return
	var b: Body = w if w is Body else w.body
	var from := w.global_position
	to.y = from.y
	var d := to - from
	if Vector2(d.x, d.z).length() > 0.01:
		w.rotation.y = atan2(-d.x, -d.z)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(w):
			w.global_position = from.lerp(to, k)
			b.pose(snappedf(k * secs, 1.0 / 12.0), anim if k < 1.0 else "idle"), 0.0, 1.0, maxf(secs, 0.01))

func _process(dt: float) -> void:
	if not is_instance_valid(cam):
		return
	if _shake_t > 0.0:
		_shake_t -= dt
		cam.h_offset = randf_range(-_shake, _shake)
		cam.v_offset = randf_range(-_shake, _shake)
		if _shake_t <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

# Tong walks from where the camera is to `to` at an even pace while his eyes move from what they
# were on to `look`. The head dips on every step and sways side to side, and each step is heard.
func _walk(to: Vector3, look: Vector3, secs: float, running := false) -> void:
	var stride := RUN_STRIDE if running else STRIDE
	var from := cam.global_position
	var look0 := _look if _look != Vector3.ZERO else from - cam.global_basis.z
	_look = look
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var start := _stride
	var t := 0.0
	while not skipping:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / secs, 0.0, 1.0) if secs > 0.0 else 1.0
		var pos := from.lerp(to, k)
		var before := _stride
		_stride = start + dist * k
		if floori(_stride / stride) > floori(before / stride):
			Game.sfx("footstep0%d" % (floori(_stride / stride) % 4), null, -1.0 if running else -6.0)
		var phase := _stride / stride * PI
		# no bob turning on the spot; it settles at both ends so the next shot starts level
		var amp := minf(dist / stride, 1.0) * clampf(minf(k, 1.0 - k) * 8.0, 0.0, 1.0) * (2.2 if running else 1.0)
		var eye := look0.lerp(look, smoothstep(0.0, 1.0, k))
		var xf := Transform3D.IDENTITY.looking_at(eye - pos).translated(pos)
		cam.global_transform = xf.translated_local(Vector3(sin(phase) * 0.025, -absf(sin(phase)) * 0.05, 0.0) * amp)
		if k >= 1.0:
			break

func _on_skip() -> void:
	skipping = true

func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not skipping:
		await get_tree().process_frame
		t += get_process_delta_time()
