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
#         ["body", face, cell, look_cell]  spawn a posed extra (endings)
class_name Cutscene
extends Node

const STRIDE := 0.8   # metres per footstep when walking

var level: Node3D
var cam: Camera3D
var skipping := false
var _active := false
var _look := Vector3.ZERO   # what the camera is looking at (world), so walks turn the head smoothly
var _stride := 0.0          # metres walked: bob phase + when the next footstep lands

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
	cam.queue_free()
	if lvl.player:
		lvl.player.cam.current = true
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

# Tong walks from where the camera is to `to` at an even pace while his eyes move from what they
# were on to `look`. The head dips on every step and sways side to side, and each step is heard.
func _walk(to: Vector3, look: Vector3, secs: float) -> void:
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
		if floori(_stride / STRIDE) > floori(before / STRIDE):
			Game.sfx("footstep0%d" % (floori(_stride / STRIDE) % 4), null, -6.0)
		var phase := _stride / STRIDE * PI
		# no bob turning on the spot; it settles at both ends so the next shot starts level
		var amp := minf(dist / STRIDE, 1.0) * clampf(minf(k, 1.0 - k) * 8.0, 0.0, 1.0)
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
