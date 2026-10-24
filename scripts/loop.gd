# Fire stairs: the same stretch of corridor, over and over (scenes/stages/stage_stairs.tscn).
# Each time round it is either exactly as it should be... or something about it is wrong.
#   nothing wrong -> keep going to the end (the "Forward" boxes)
#   anything wrong -> turn back to where you started (the "Back" boxes, behind the start)
# Right `laps` times in a row and the door at the end opens. One wrong call: back to 0.
# The corridor's posters, clock and the spots the anomalies use are in story.gd ("loop").
extends Node3D

## Right calls in a row to get out
@export var laps := 8
## Chance that something is wrong this time round
@export_range(0.0, 1.0) var anomaly_chance := 0.55

const ANOMALIES := ["staff_end", "staff_wall", "red", "dark", "sign", "plant", "footsteps", "phone", "wet",
	"peek", "crawler", "rush", "behind", "door", "flicker", "voice", "clock", "tong"]
const AGGRESSIVE := ["crawler", "rush", "behind"]   # they come at you: they cost some Social Battery

var anomaly := ""          # "" = everything as it should be this time round
var seen := {}             # anomalies already met: a fresh one is picked while any are left
var _last := ""
var _left_start := false   # walked off the landing this round (turning back only counts after that)
var _busy := false
var _sprung := false       # this round's aggressive anomaly already went for him
var _added: Array[Node] = []   # whatever this round's anomaly put in the corridor
var _undo: Array[Callable] = []
var _t := 0.0
var posters: Array[Label3D] = []
var clock: Label3D
var counter: Label3D
@onready var lvl: Node3D = get_parent()

func _ready() -> void:
	if StageBuilder.baking:
		return
	for c in get_children():
		if c is Area3D:
			c.body_entered.connect(_entered.bind(c.name.begins_with("Forward")))
	_decor.call_deferred()

func cfg() -> Dictionary:
	return lvl.data.get("loop", {})

func cell(c: Vector2i) -> Vector3:
	return StageBuilder.cell_pos(c)

# A label flat on a corridor wall: side = which wall of that cell (n/s/e/w).
func _wall_label(c: Vector2i, side: String, text: String, size := 40) -> Label3D:
	var dir: Vector3 = {"n": Vector3.FORWARD, "s": Vector3.BACK, "e": Vector3.RIGHT, "w": Vector3.LEFT}[side]
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 8
	l.pixel_size = 0.006
	l.modulate = Color(0.9, 0.9, 0.85)
	l.position = cell(c) + dir * 0.97 + Vector3.UP * 1.75
	l.rotation.y = atan2(-dir.x, -dir.z) + PI   # face back into the corridor
	lvl.add_child(l)
	return l

func _decor() -> void:
	for p in cfg().get("posters", []):
		posters.append(_wall_label(p[0], p[1], p[2]))
	var ck: Array = cfg().get("clock", [Vector2i(1, 1), "n"])
	clock = _wall_label(ck[0], ck[1], "02:14", 64)
	clock.modulate = Color(1, 0.3, 0.25)
	var ct: Array = cfg().get("counter", [Vector2i(2, 2), "n"])
	counter = _wall_label(ct[0], ct[1], "", 48)
	counter.modulate = Color(0.4, 1, 0.5)
	_round(false)

func _process(dt: float) -> void:
	var p: Node3D = Game.player
	if not is_instance_valid(p) or Game.in_cutscene or Game.busy or _busy:
		return
	if not _left_start and p.global_position.distance_to(lvl.spawn) > 6.0:
		_left_start = true
	_t += dt
	match anomaly:
		"footsteps":   # someone a few steps behind, matching his pace
			if _t > 1.1 and Vector2(p.velocity.x, p.velocity.z).length() > 0.5:
				_t = 0.0
				var a := AudioStreamPlayer3D.new()
				a.stream = Game.stream("footstep0%d" % randi_range(0, 3))
				a.bus = "SFX"
				a.position = p.global_position + p.global_basis.z * 3.0
				a.finished.connect(a.queue_free)
				lvl.add_child(a)
				a.play()
		"phone":
			if _t > 3.0:
				_t = 0.0
				lvl._sound_at("phone_ring", cell(cfg().door_b))
		"voice":
			if _t > 5.0:
				_t = 0.0
				lvl._sound_at("mutter", cell(cfg().door_c))
				Game.say("(เสียงจากหลังประตู): ...งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ...", 2.5)
		"flicker":
			if randf() < 0.08 and not lvl.lights.is_empty():
				var l: OmniLight3D = lvl.lights[cfg().get("flicker_light", 2) % lvl.lights.size()]
				l.visible = not l.visible
		"crawler", "rush", "behind":
			if not _sprung and _in(cfg().get(anomaly + "_zone", [])):
				_sprung = true
				_spring()

# Player inside a zone [Vector2i from, Vector2i to] (cells, inclusive)?
func _in(zone: Array) -> bool:
	if zone.size() < 2:
		return false
	var p: Vector3 = Game.player.global_position
	var c := Vector2i(floori(p.x / StageBuilder.CELL), floori(p.z / StageBuilder.CELL))
	return c.x >= zone[0].x and c.x <= zone[1].x and c.y >= zone[0].y and c.y <= zone[1].y

func _spring() -> void:
	match anomaly:
		"crawler":
			lvl._crawl("goblin", cell(cfg().crawl_from), cell(cfg().crawl_to), "techspeak")
			_hurt(10.0)
		"rush":
			lvl._rush("staff", cell(cfg().end), "whisper")
			get_tree().create_timer(1.6, false).timeout.connect(_hurt.bind(15.0))
		"behind":
			lvl.scare({"kind": "behind", "preset": "guard", "sfx": "whisper", "secs": 4.0})
			_hurt(8.0)

func _hurt(amount: float) -> void:
	if not Game.busy and anomaly in AGGRESSIVE:
		Game.damage(amount, "บันไดหนีไฟไม่มีวันจบ... ต๋องเดินวนอยู่ตรงนั้นจนหมดแรง")

func _entered(b: Node, forward: bool) -> void:
	if b != Game.player or _busy or Game.busy or Game.in_cutscene:
		return
	if lvl.exit_open:   # all done: the door at the end is open, nothing loops any more
		return
	if not forward and not _left_start:
		return   # just backed into the wall behind the start
	_judge(forward)

func _judge(went_on: bool) -> void:
	_busy = true
	var right := (anomaly == "") == went_on
	if right:
		Game.sfx("elevator_ding", null, -8.0)
		Game.collect()   # the stage's goal counts the laps; the last one opens the exit
	else:
		Game.goal_count = 0
		Game.objective_changed.emit(Game.objective_text())
		Game.sfx("door_slam", null, -4.0)
		Game.say("ต๋อง: ...ชั้น 4 อีกแล้ว ป้ายบอกว่ากลับมาที่เดิม", 2.5)
	if lvl.exit_open:   # that was the last one: leave him where he is, the way out is just ahead
		_round(true)
		_busy = false
		return
	Game.fade.emit(1.0, 0.15)
	await get_tree().create_timer(0.25, false).timeout
	if is_instance_valid(Game.player):
		Game.player.global_position = lvl.spawn
		Game.player.rotation.y = lvl.spawn_rot
		Game.player.cam.rotation.x = 0.0
		Game.player.velocity = Vector3.ZERO
	_round(false)
	Game.fade.emit(0.0, 0.35)
	_busy = false

# Put the corridor back to normal, then maybe make one thing wrong.
func _round(force_normal: bool) -> void:
	for f in _undo:
		f.call()
	_undo.clear()
	for n in _added:
		if is_instance_valid(n):
			n.queue_free()
	_added.clear()
	_left_start = false
	_sprung = false
	_t = 0.0
	anomaly = ""
	if counter:
		counter.text = "บันไดหนีไฟ · ชั้น 4\nผ่านแล้ว %d / %d" % [Game.goal_count, laps]
	if force_normal or (Game.goal_count == 0 and _last == "" and seen.is_empty()) or randf() > anomaly_chance:
		_last = ""
		return
	var pool := ANOMALIES.filter(func(a): return a != _last and not seen.has(a))
	if pool.is_empty():
		pool = ANOMALIES.filter(func(a): return a != _last)
	anomaly = pool.pick_random()
	seen[anomaly] = true
	_last = anomaly
	_apply(anomaly)

func _body(preset: String, c: Vector2i, look: Vector2i) -> Body:
	var b := Body.new()
	b.build(Story.BODIES[preset])
	lvl.add_child(b)
	b.global_position = cell(c)
	var d := cell(look) - b.global_position
	b.rotation.y = atan2(-d.x, -d.z)
	_added.append(b)
	return b

func _apply(a: String) -> void:
	var c := cfg()
	match a:
		"staff_end":
			_body("staff", c.end, c.end_look)
		"staff_wall":   # someone standing with their face to the wall
			var b := _body("staff", c.wall_spot, c.wall_face)
			b.parts.Head.rotation.x = -0.3
		"red":
			for l in lvl.lights:
				var col: Color = l.light_color
				l.light_color = Color(1, 0.12, 0.08)
				_undo.append(func(): l.light_color = col)
		"dark":
			lvl.set_dark(true)
			_undo.append(func(): lvl.set_dark(false))
		"sign":
			var i := randi() % posters.size()
			var old := posters[i].text
			posters[i].text = c.posters[i][3]
			_undo.append(func(): posters[i].text = old)
		"plant":   # every pot plant hanging upside down from the ceiling
			for pl in lvl.get_node("NavRegion").get_children().filter(func(n): return n.get_child_count() > 0 and n.get_child(0).scene_file_path.ends_with("pottedPlant.glb")):
				var xf: Transform3D = pl.transform
				pl.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(xf.origin.x, StageBuilder.WALL_H, xf.origin.z))
				_undo.append(func(): pl.transform = xf)
		"wet":   # wet footprints coming toward him
			for i in 7:
				var m := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(0.25, 0.4)
				m.mesh = pm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.2, 0.3, 0.45, 0.6)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.material_override = mat
				var from := cell(c.wet_from)
				var to := cell(c.wet_to)
				m.position = from.lerp(to, i / 6.0) + Vector3(0.25 if i % 2 else -0.25, 0.02, 0)
				lvl.add_child(m)
				_added.append(m)
		"peek":   # the boss's head round the corner, neck stretched
			var b := _body("manager_long", c.peek, c.peek_look)
			b.rotation.z = 0.5
			b.parts.Head.rotation.z = 1.1
		"door":   # a side door stands open; someone is in there
			var d := _door_at(c.door_a)
			if d:
				d.visible = false
				var col: CollisionShape3D = d.get_node_or_null("CollisionShape3D")
				if col:
					col.disabled = true
				_undo.append(func():
					d.visible = true
					if col:
						col.disabled = false)
			_body("staff", c.door_a, c.door_a_look)
		"clock":
			clock.text = "04:44"
			_undo.append(func(): clock.text = "02:14")
		"tong":   # Tong, standing at the end, his back to you
			_body("tong", c.end, c.end_away)

# The door slab of an 'O' cell (stage_builder _door puts it 1.1 m up in the middle of the cell).
func _door_at(c: Vector2i) -> Node3D:
	var at := cell(c) + Vector3.UP * 1.1
	for n in lvl.get_node("NavRegion").get_children():
		if n is StaticBody3D and n.position.distance_to(at) < 0.2:
			return n
	return null
