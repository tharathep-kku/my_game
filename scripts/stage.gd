# Runtime for a stage scene (scenes/stages/stage_N.tscn, scenes/endings/ending_X.tscn).
# Edit the scene in the editor: move props / items / lights, drag Markers/PlayerSpawn and
# Markers/Route/1..n (the coworker's patrol), then select NavRegion > "Bake NavigationMesh".
# Text (notes, triggers, phone texts, intro cutscene) lives in story.gd under this stage_index.
extends Node3D

const PLAYER := preload("res://scenes/player.tscn")
const DISTANT := ["door_slam", "elevator_ding", "chair_creak", "printer", "whisper", "knock", "footsteps_far"]

@export var stage_index := -1     ## Story.STAGES index (stages); -2 = tutorial (Story.TUTORIAL, run by its Tutorial node)
@export var ending_id := ""       ## Story.ENDING_SCENES key (endings)
@export_group("Stage mechanics")
## Power is out when the stage starts: only emergency lights, find the breaker (kind "breaker")
@export var dark_start := false
## Once every goal is done, every coworker comes for you (a chase to the exit)
@export var rage_on_goal := false
## What they shout when that happens
@export var rage_line := ""
## Objective shown on the HUD during the chase
@export var rage_objective := "หนี!! ทุกคนไล่มาแล้ว — วิ่งไปทางออก (ตามลูกศรเขียว)"
## Random blackouts every x..y seconds (0 = never). In the dark you can't keep an eye on anyone.
@export var flicker := Vector2.ZERO
## Holding the exit scanner wakes everyone: the other coworkers come running (final stage)
@export var finale := false
## ป้าพร: this many puddles lie around the floor from the first second and never dry (0 = only her trail)
@export var wet_start := 0
@export_group("")

const GOAL_KINDS := ["doc", "note", "pc", "coffee_goal", "breaker", "scanner", "fuse", "fuse_box", "file"]
const SCAN_SECS := 3.0
const MOB_SCENES := ["manager", "sweeper", "goblin"]

var data: Dictionary
var with_player := true
var spawn := Vector3.ZERO
var spawn_rot := 0.0
var exit_open := false
var goal := 0
var door: Node3D
var exit_sign: Label3D
var npcs: Array[Npc] = []
var player: CharacterBody3D
var lights: Array[OmniLight3D] = []
var cameos: Array[Dictionary] = []   # {body, watch, id}
var wall_nodes := 0
var leash := 20.0          ## patrol won't wander farther than this from the player - ~half the map
var _rng := RandomNumberGenerator.new()
var _event_t := 12.0
var _hunch_t := randf_range(10.0, 20.0)
var dark := false          ## lights are off right now (power cut or a blackout)
var power_out := false     ## lights stay off until the breaker is flipped
var fuse_dark := false     ## stage 4: the fuse took the floor's power - dark until the exit, the flashlight lasts longer
var raging := false        ## rage_on_goal / finale chase is on
var scan_t := 0.0          ## seconds the exit scanner has been held
var extras: Array[Npc] = []   # finale coworkers (freed on respawn)
var _blackout_id := 0
var _flicker_t := 0.0
var _phantom_t := 25.0
var gloom := 1.0           ## 0 = a bright working day .. 1 = the usual night (set_gloom; only the tutorial changes it)
var _night := {}
var _sky: StandardMaterial3D
var _env: Environment
var _ambient := 1.0
var _base_flicker := Vector2.ZERO

func _ready() -> void:
	if StageBuilder.baking:
		return
	if data.is_empty():
		if stage_index == -2:
			data = Story.TUTORIAL
		elif stage_index >= 0:
			data = Story.STAGES[stage_index]
		elif ending_id != "":
			data = Story.ENDING_SCENES[ending_id].duplicate()
			with_player = false
	goal = data.get("goal", 0)
	var nav: NavigationRegion3D = $NavRegion
	if nav.navigation_mesh.get_polygon_count() == 0:   # built at runtime (tests): bake now
		nav.bake_navigation_mesh(false)
	var verts := nav.navigation_mesh.get_vertices()
	if verts.size() > 0:
		var mn: Vector3 = verts[0]
		var mx: Vector3 = verts[0]
		for v in verts:
			mn = mn.min(v)
			mx = mx.max(v)
		leash = maxf(maxf(mx.x - mn.x, mx.z - mn.z) * 0.5, 12.0)
	var sp := get_node_or_null("Markers/PlayerSpawn")
	if sp:
		spawn = sp.global_position
		spawn_rot = sp.rotation.y
	for l in $Lights.get_children():
		if l is OmniLight3D:
			lights.append(l)
	_optimize()
	door = get_node_or_null("Exit/Door")
	exit_sign = get_node_or_null("Exit/Sign")
	var exit_trig: Area3D = get_node_or_null("Exit/Trigger")
	if exit_trig:
		exit_trig.body_entered.connect(func(bd): if bd == player and exit_open and not Game.busy: Game.stage_clear())
	var we := get_node_or_null("WorldEnvironment")
	if we:
		we.environment = we.environment.duplicate()   # ours to change: the scene's copy is shared by every play of it
		_env = we.environment
		_ambient = _env.ambient_light_energy
		_night = {"ambient": _env.ambient_light_color, "fog": _env.fog_density,
			"light": lights[0].light_color if not lights.is_empty() else Color.WHITE,
			"energy": lights[0].light_energy if not lights.is_empty() else 1.4}
	var win := get_node_or_null("Windows")
	if win and win.get_child_count() > 0:
		_sky = win.get_child(0).material_override.duplicate()
		for w in win.get_children():
			w.material_override = _sky
	var route: Array[Vector3] = []
	var marks := $Markers/Route.get_children()
	marks.sort_custom(func(a, b): return a.name.to_int() < b.name.to_int())
	for m in marks:
		route.append(m.global_position)
	for n in find_children("*", "Npc", true, false):
		n.init_in(self, route)
		npcs.append(n)
	var i := 0
	for b in $Cameos.get_children():
		cameos.append({"body": b, "watch": 0.0, "id": "cameo_%d_%d" % [Game.stage, i]})
		i += 1
	if with_player:
		player = PLAYER.instantiate()
		add_child(player)
		player.global_position = spawn
		player.rotation.y = spawn_rot
		Game.player = player
	Game.level = self
	if goal == 0:
		unlock_exit(true)
	power_out = dark_start
	set_dark(dark_start)
	_base_flicker = flicker
	_flicker_t = randf_range(flicker.x, flicker.y)
	if wet_start > 0:
		_scatter_wet()

# Fog hides everything past ~30 m, so don't pay for it: small props (desks are 4 models each)
# stop drawing at 30 m and far lights fade out. Big meshes (walls, floor) are left alone,
# since visibility range is measured to their centre and they'd pop.
func _optimize() -> void:
	for g in $NavRegion.find_children("*", "GeometryInstance3D", true, false):
		if g.visibility_range_end == 0.0 and g.get_aabb().size.length() < 5.0:
			g.visibility_range_end = 30.0
			g.visibility_range_end_margin = 2.0
	for l in lights:
		l.distance_fade_enabled = true
		l.distance_fade_begin = 26.0
		l.distance_fade_length = 6.0

func cell_pos(c: Vector2i) -> Vector3:
	return StageBuilder.cell_pos(c)

func unlock_exit(silent := false) -> void:
	exit_open = true
	if is_instance_valid(door):
		door.queue_free()
	if exit_sign:
		exit_sign.modulate = Color(0.2, 1, 0.3)
	if not silent:
		Game.sfx("doorOpen_1")
		Game.say("ประตูทางออกปลดล็อกแล้ว! รีบไปเลย", 3.0)
		var trig := get_node_or_null("Exit/Trigger")
		if trig:   # point the way out (stays up for the whole chase)
			_marker(trig, Color(0.3, 1, 0.4), 1.2, 9999.0 if (rage_on_goal or finale) else 45.0, "ทางออก")
		if rage_on_goal and is_instance_valid(player):
			_start_rage()

# The chase: its cutscene first if the stage has one (Tong runs; play picks up where he got to).
func _start_rage() -> void:
	if data.has("rage_scene") and not Game.skip_cutscenes:
		await play_scene(data.rage_scene)
		await get_tree().process_frame
	if not is_instance_valid(player):
		return
	spawn = player.global_position   # checkpoint: caught mid-chase restarts the run from here
	spawn_rot = player.rotation.y
	rage(rage_line)

# Every coworker comes for you, after a beat to start running. Survives being caught (respawn).
func rage(line := "") -> void:
	raging = true
	Game.sfx("sting", null, -2.0)
	Game.flash.emit("rage")
	if line != "":
		Game.say(line, 3.5)
	Game.objective_changed.emit(rage_objective)
	get_tree().create_timer(1.5, false).timeout.connect(func():
		if raging:
			for n in npcs:
				n.enrage())

func respawn() -> void:
	player.unhide()
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	player.rotation.y = spawn_rot
	for n in extras:   # finale: back to the quiet lobby
		npcs.erase(n)
		n.queue_free()
	extras.clear()
	scan_t = 0.0
	if finale:
		raging = false
		flicker = _base_flicker
	for n in npcs:
		n.reset()
	if raging:
		rage()

# ---------- lights ----------
# Lights off/on. Emergency lights (red, "Emergency" node) come on whenever the lights are out.
func set_dark(on: bool) -> void:
	dark = on
	for l in lights:
		l.visible = not on
	var em := get_node_or_null("Emergency")
	if em:
		for e in em.get_children():
			e.visible = on
	if _env:
		_env.ambient_light_energy = _ambient * (0.25 if on else 1.0)

# Breaker flipped: lights back for good.
func restore_power() -> void:
	power_out = false
	set_dark(false)

# Fuse in the scanner panel: the floor's lights die and stay dead (even after being caught).
func fuse_power_cut() -> void:
	fuse_dark = true
	power_out = true
	Game.sfx("metalClick", null, -4.0)
	set_dark(true)

# The lights die for a few seconds (scare / flicker). Coworkers keep moving; you can't watch them.
func blackout(secs: float) -> void:
	if dark:
		return
	_blackout_id += 1
	var my := _blackout_id
	Game.sfx("metalClick", null, -4.0)
	set_dark(true)
	get_tree().create_timer(secs, false).timeout.connect(func():
		if my == _blackout_id and not power_out:
			set_dark(false))

# Time of day (tutorial.gd): 0 = bright afternoon, warm lamps, sky in the windows, no fog;
# 1 = the night every other stage is set in. main.gd fades the dark drone in with it.
func set_gloom(v: float) -> void:
	gloom = clampf(v, 0.0, 1.0)
	if _env:
		_env.ambient_light_color = Color(0.8, 0.8, 0.76).lerp(_night.ambient, gloom)
		_env.fog_density = _night.fog * gloom
		for l in lights:
			l.light_color = Color(1.0, 0.96, 0.86).lerp(_night.light, gloom)
			l.light_energy = lerpf(2.2, _night.energy, gloom)
	if _sky:
		_sky.albedo_color = Color(0.6, 0.82, 1.0).lerp(Color(0.02, 0.03, 0.07), sqrt(gloom))   # the sky goes first

# How far coworkers can see you, relative to their normal sight: the dark hides you, the
# flashlight gives you away.
func sight_mult() -> float:
	var lamp: bool = is_instance_valid(player) and player.flashlight.visible
	if dark:   # in the dark a flashlight is a beacon: seen from farther than in normal light
		return 1.3 if lamp else 0.45
	return 1.6 if lamp else 1.0

# ---------- notes: show what the note told you ----------
# What each goal is called on its on-screen marker.
const GOAL_NAMES := {"doc": "เอกสารงบดุล", "note": "โพสต์อิทรหัส", "pc": "คอมห้อง Admin", "coffee_goal": "เครื่องชงกาแฟ",
	"breaker": "เบรกเกอร์", "scanner": "เครื่องสแกนนิ้ว", "fuse": "ฟิวส์", "fuse_box": "แผงวงจร", "file": "ของที่ต้องหา"}

# What a goal item is called on markers / the GPS ("file" items have their own name).
static func goal_name(it: Node) -> String:
	return it.title if it.kind == "file" and it.title != "" else GOAL_NAMES[it.kind]
const REVEAL_SECS := 40.0

func reveal(kind: String, secs := REVEAL_SECS) -> void:
	if kind == "npc":
		for n in npcs:
			_marker(n, Color(1, 0.2, 0.15), n.body.head_top() + 0.4, secs, n.display_name)
		return
	for it in $Items.get_children() + get_tree().get_nodes_in_group("hide_spot"):   # + lockers dropped in by hand
		if it.get("used") != false:
			continue
		if kind == "goals" and it.kind in GOAL_NAMES:
			_marker(it, Color(1, 0.85, 0.1), 0.5, secs, goal_name(it))
		elif kind == "hides" and it.kind == "hide" and it.hide_type != "desk":   # desks are everywhere
			_marker(it, Color(0.3, 1, 0.5), 0.4, secs, "ที่ซ่อน", false)

# Beacon: a small glow on the spot (seen through walls) + main.gd draws its name/distance on screen,
# or an arrow at the screen edge pointing to it (edge) when it's out of view. Gone after secs.
func _marker(on: Node3D, color: Color, h: float, secs: float, label := "", edge := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "RevealMarker"
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.albedo_color = color
	m.material_override = mat
	m.position = Vector3.UP * h
	m.add_to_group("beacon")
	m.set_meta("label", label)
	m.set_meta("color", color)
	m.set_meta("edge", edge)
	on.add_child(m)
	get_tree().create_timer(secs, false).timeout.connect(func(): if is_instance_valid(m): m.queue_free())
	return m

# ---------- scares (scare.gd nodes) + hallucinations ----------
# s = a scare.gd node, or a Dictionary from story.gd ("goal_scares"): then it happens straight
# ahead of wherever Tong is looking.
func scare(s) -> void:
	if s is Dictionary:
		var d := {"kind": "rush", "preset": "guard", "sfx": "", "secs": 3.0, "line": ""}
		d.merge(s, true)
		s = d
	var at_pos: Vector3 = s.at() if s is Node else _ahead()
	if s.line != "":
		Game.say(s.line, 3.0)
	match s.kind:
		"lights_out":
			Game.sfx(s.sfx)
			blackout(s.secs)
		"sound":
			_sound_at(s.sfx, at_pos)
		"figure":
			_figure(s.preset, at_pos, s.secs, false, s.sfx)
		"rush":
			_rush(s.preset, at_pos, s.sfx)
		"face":
			Game.scare_face.emit(s.preset, s.sfx)
		"peek":
			var b := _figure(s.preset, at_pos, s.secs, false, s.sfx)
			b.rotation.z = 0.45   # leaning out from behind something
			b.parts.Head.rotation.z = 1.1
		"crawl":
			_crawl(s.preset, at_pos, s.to() if s is Node else at_pos + player.global_basis.x * 6.0, s.sfx)
		"behind":
			var back: Vector3 = player.global_basis.z
			var p: Vector3 = player.global_position + back * 1.7
			var q := PhysicsRayQueryParameters3D.create(player.eye(), p + Vector3.UP * 1.5, 1)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				p = player.global_position + back * 0.9
			_figure(s.preset, p, s.secs, true, s.sfx)

# A spot on the floor straight ahead of Tong, short of the first wall (at most `far` metres).
func _ahead(far := 11.0) -> Vector3:
	var dir: Vector3 = -player.global_basis.z
	var eye: Vector3 = player.eye()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * far, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3 = (hit.position - dir * 0.8) if not hit.is_empty() else eye + dir * far
	return Vector3(p.x, 0.0, p.z)

# It stands there a beat, staring... then sprints straight at him (through anything) and is gone
# at arm's length, with its face in his. Harmless: it's the fright that counts.
func _rush(preset: String, from: Vector3, sfx_name := "") -> void:
	var b := Body.new()
	b.build(Story.BODIES[preset])
	add_child(b)
	b.global_position = Vector3(from.x, 0.0, from.z)
	if sfx_name != "":
		Game.sfx(sfx_name, b, 0.0, 0.75)
	var t := 0.0
	var ran := false
	while is_instance_valid(b) and is_instance_valid(player) and t < 4.5:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if Game.in_cutscene or Game.busy or not is_instance_valid(b) or not is_instance_valid(player):
			break
		var to := player.global_position - b.global_position
		to.y = 0.0
		b.rotation.y = atan2(-to.x, -to.z)
		if t < 0.7:   # the stare
			continue
		if not ran:
			ran = true
			Game.sfx("scare_riser", null, -4.0)
		if to.length() < 1.3:
			Game.scare_face.emit(preset, "")
			break
		b.global_position += to.normalized() * minf(10.0 * dt, to.length())
		b.pose(snappedf(t, 1.0 / 12.0) * 1.8, "walk")
	if is_instance_valid(b):
		b.queue_free()

# Scuttles on all fours across his view, then it's gone.
func _crawl(preset: String, from: Vector3, to: Vector3, sfx_name := "") -> void:
	var b := Body.new()
	b.build(Story.BODIES[preset])
	add_child(b)
	b.global_position = Vector3(from.x, 0.35, from.z)
	var d := to - from
	b.rotation = Vector3(-1.2, atan2(-d.x, -d.z), 0.0)
	b.parts.Head.rotation.x = 1.2
	Game.sfx(sfx_name if sfx_name != "" else "creak2", b, 2.0, 0.7)
	var secs := maxf(Vector2(d.x, d.z).length() / 7.0, 0.4)
	var t := 0.0
	while t < secs and is_instance_valid(b):
		await get_tree().process_frame
		t += get_process_delta_time()
		if not is_instance_valid(b):
			return
		b.global_position = Vector3(from.x, 0.35, from.z).lerp(Vector3(to.x, 0.35, to.z), minf(t / secs, 1.0))
		b.pose(snappedf(t, 1.0 / 12.0) * 2.0, "crawl")
	if is_instance_valid(b):
		b.queue_free()

# ---------- mid-stage cutscenes (story.gd: "item_scenes", "goal_scares", "rage_scene") ----------
var _played := {}

func play_scene(steps: Array) -> void:
	if Game.busy or Game.in_cutscene or not is_instance_valid(player):
		return
	player.unhide()
	await get_tree().create_timer(0.35, false).timeout   # let the pickup sound and subtitle land first
	if Game.busy or not is_instance_valid(player):
		return
	await Cutscene.new().play(self, steps)

# A one-of-a-kind item (breaker, the coffee, the fuse panel) can set off a cutscene.
func item_used(kind: String) -> void:
	var scenes: Dictionary = data.get("item_scenes", {})
	if scenes.has(kind) and not _played.has(kind):
		_played[kind] = true
		play_scene(scenes[kind])

# The n-th goal of the stage can set off a scare, wherever Tong happens to be.
func goal_reached(n: int) -> void:
	var gs: Dictionary = data.get("goal_scares", {})
	if gs.has(n) and is_instance_valid(player):
		scare(gs[n])

func _sound_at(sfx_name: String, pos: Vector3) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = Game.stream(sfx_name)
	a.bus = "SFX"
	a.unit_size = 6.0
	a.position = pos + Vector3.UP * 1.2
	a.finished.connect(a.queue_free)
	add_child(a)
	a.play()

# Someone standing there, staring. Look at it and it's gone (lunge: it springs at you first).
func _figure(preset: String, pos: Vector3, ttl: float, lunge: bool, sfx_name := "") -> Node3D:
	var b := Body.new()
	b.build(Story.BODIES[preset])
	add_child(b)
	b.global_position = Vector3(pos.x, 0.0, pos.z)
	if sfx_name != "":
		Game.sfx(sfx_name, b, -4.0)
	cameos.append({"body": b, "watch": 0.0, "id": "", "ttl": ttl, "lunge": lunge})
	return b

# Low Social Battery: Tong starts seeing coworkers who aren't there.
func _phantom(dt: float) -> void:
	if Game.battery > 50.0 or Game.busy or player.hidden:
		return
	_phantom_t -= dt
	if _phantom_t > 0.0:
		return
	var fear := 1.0 - Game.battery / 50.0
	_phantom_t = lerpf(30.0, 10.0, fear) * randf_range(0.8, 1.2)
	var map := get_world_3d().navigation_map
	for i in 25:
		var p := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := p.distance_to(player.global_position)
		var head := p + Vector3.UP * 1.8
		if d > 7.0 and d < 16.0 and player.cam.is_position_in_frustum(head):
			var q := PhysicsRayQueryParameters3D.create(player.eye(), head, 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				_figure(["manager", "sweeper", "goblin", "guard"].pick_random(), p, 1.5, false, "whisper")
				return

# ---------- final stage: hold the scanner while everyone comes ----------
# A stage with a fuse panel: the scanner is dead until the fuse is in.
func scanner_powered() -> bool:
	return not $Items.get_children().any(func(it): return it.get("kind") == "fuse_box" and not it.used)

func _scan(dt: float) -> void:
	var f: Node = player.focus()
	if f and f.kind == "scanner" and Input.is_action_pressed("interact") and not player.hidden and not Game.busy:
		if not scanner_powered():
			Game.say("ต๋อง: เครื่องสแกนไม่มีไฟ... ต้องใส่ฟิวส์ที่แผงวงจรที่ห้องจดหมายก่อน", 0.5)
			return
		if finale and extras.is_empty() and not raging:
			_start_finale()
		scan_t += dt
		Game.say("กำลังสแกนลายนิ้วมือ... %d%%  (ห้ามปล่อยมือ!)" % int(minf(scan_t / SCAN_SECS, 1.0) * 100), 0.3)
		if scan_t >= SCAN_SECS:
			f.used = true
			Game.sfx("beep", null, 4.0)
			Game.say("สแกนผ่าน! ประตูเปิดแล้ว... วิ่ง!!", 3.0)
			Game.collect()
	else:
		scan_t = maxf(scan_t - dt * 0.5, 0.0)

func _start_finale() -> void:
	raging = true
	Game.sfx("elevator_ding")
	Game.say("ต๋อง: ...ลิฟต์เปิด? ทุกคนลงมากันหมดเลย!!", 3.0)
	Game.flash.emit("rage")
	Game.objective_changed.emit("ห้ามปล่อยมือ!! สแกนนิ้วให้ครบ ทุกคนกำลังมา")
	flicker = Vector2(3.0, 6.0)
	_flicker_t = 1.0
	var map := get_world_3d().navigation_map
	for mob in MOB_SCENES:
		var n: Npc = load("res://scenes/mobs/%s.tscn" % mob).instantiate()
		var best := spawn
		for i in 30:   # far from Tong, so there's a beat before they arrive
			var p := NavigationServer3D.map_get_random_point(map, 1, false)
			if p.distance_to(player.global_position) > 16.0:
				best = p
				break
		add_child(n)
		n.global_position = best
		var pts: Array[Vector3] = [best]
		n.init_in(self, pts)
		npcs.append(n)
		extras.append(n)
	for n in npcs:
		n.enrage()

func spawn_throwable(pos: Vector3) -> void:
	$Items.add_child(StageBuilder.make_item("throwable", Vector3(pos.x, 0.08, pos.z), Vector3(0.14, 0.16, 0.14), Color(0.9, 0.9, 0.95)))

# Puddles on the floor from the start (wet_start): random spots on the navmesh, kept out of doorways
# (you could not get past), off Tong's first steps and off anything he has to walk up to.
func _scatter_wet() -> void:
	var map := get_world_3d().navigation_map
	for i in 30:   # walls reach the physics space, and the stage the navigation map, a few physics frames in
		await get_tree().physics_frame
		if i > 0 and not NavigationServer3D.map_get_path(map, spawn, spawn + Vector3(0.6, 0, 0), true).is_empty():
			break
	var sweepers := npcs.filter(func(n): return n is Sweeper)
	if sweepers.is_empty():
		return
	var nm: NavigationMesh = $NavRegion.navigation_mesh
	var verts := nm.get_vertices()
	var tris: Array[PackedVector3Array] = []   # the walkable floor as triangles...
	var upto := PackedFloat32Array()            # ...and their running area, so open floor gets its share
	var total := 0.0
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for j in range(1, poly.size() - 1):
			var tri := PackedVector3Array([verts[poly[0]], verts[poly[j]], verts[poly[j + 1]]])
			total += (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() / 2.0
			tris.append(tri)
			upto.append(total)
	if tris.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var keep_clear: Array[Vector3] = [spawn]
	for it in $Items.get_children():
		keep_clear.append(it.front if it.get("kind") == "hide" else it.global_position)
	var placed: Array[Vector3] = []
	for attempt in wet_start * 40:
		if placed.size() >= wet_start:
			break
		var tri := tris[mini(upto.bsearch(_rng.randf() * total), tris.size() - 1)]
		var u := _rng.randf()
		var v := _rng.randf()
		if u + v > 1.0:   # fold the square onto the triangle: an even spread inside it
			u = 1.0 - u
			v = 1.0 - v
		var p: Vector3 = $NavRegion.to_global(tri[0] + (tri[1] - tri[0]) * u + (tri[2] - tri[0]) * v)
		p.y = 0.02
		var flat := func(q: Vector3) -> float: return Vector2(q.x - p.x, q.z - p.z).length()
		if flat.call(spawn) < 6.0 or keep_clear.any(func(q): return flat.call(q) < 2.0) or placed.any(func(q): return flat.call(q) < 2.4):
			continue
		# Tong must be able to walk there: the bake leaves islands of navmesh inside toilet stalls and walls
		var path := NavigationServer3D.map_get_path(map, spawn, p, true)
		if path.is_empty() or flat.call(path[path.size() - 1]) > 0.3:
			continue
		var from := Vector3(p.x, 0.5, p.z)
		var tight := false   # something solid close on both sides = a doorway or a gap between desks
		for d in [Vector3.RIGHT, Vector3.BACK]:
			var hit_a := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + d * 1.8, 1))
			var hit_b := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - d * 1.8, 1))
			tight = tight or (not hit_a.is_empty() and not hit_b.is_empty())
		if tight:
			continue
		placed.append(p)
		add_wet(p, sweepers[0], 0.0)

# secs = how long it stays wet (0 = for good).
func add_wet(pos: Vector3, sweeper: Npc, secs := 10.0) -> void:
	var a := Area3D.new()
	a.add_to_group("wet")
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = Vector3(pos.x, 0.02, pos.z)
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.1, 0.4, 1.1)
	s.shape = b
	a.add_child(s)
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.3, 1.3)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic = 0.6
	m.material_override = mat
	a.add_child(m)
	if secs > 0.0:
		var t := Timer.new()
		t.wait_time = secs
		t.one_shot = true
		t.autostart = true
		t.timeout.connect(a.queue_free)
		a.add_child(t)
	a.body_entered.connect(func(bd): if bd == player: sweeper.anger())
	add_child(a)

func _process(dt: float) -> void:
	if not dark and gloom > 0.5 and ending_id == "" and not lights.is_empty() and _rng.randf() < 0.04:   # one dying fluorescent tube (endings set their own lights)
		lights[0].visible = not lights[0].visible or _rng.randf() < 0.5
	_cameos(dt)
	if is_instance_valid(player) and not Game.in_cutscene:
		_phantom(dt)
		_scan(dt)
		if flicker.y > 0.0:
			_flicker_t -= dt
			if _flicker_t <= 0.0:
				_flicker_t = randf_range(flicker.x, flicker.y)
				blackout(randf_range(1.2, 2.4))
	_event_t -= dt
	if _event_t <= 0.0 and gloom > 0.5 and is_instance_valid(player) and not Game.in_cutscene:   # nothing creepy by day
		_event_t = randf_range(14.0, 32.0)
		distant_event(DISTANT.pick_random())
	_hunch_t -= dt
	if _hunch_t <= 0.0 and is_instance_valid(player) and not Game.in_cutscene and not Game.busy:
		_hunch_t = randf_range(10.0, 20.0)
		if not player.hidden:   # every 10-20s, a patrolling coworker might just get a hunch
			var hunch: Array[Npc] = []
			for n in npcs:
				if n.state in ["patrol", "investigate"] and not (n is Sweeper) and _rng.randf() < 0.4:
					hunch.append(n)
			if not hunch.is_empty():
				Game.sfx("heartbeat", null, -4.0)   # warning stinger - a beat to react before it comes
				var pos := player.global_position
				get_tree().create_timer(0.8, false).timeout.connect(func():
					if Game.busy or Game.in_cutscene or not is_instance_valid(player) or player.hidden:
						return
					for n in hunch:
						if is_instance_valid(n):
							n.hear(pos))

# พี่สมชาย standing still at the far end of a sightline. Look at him for half a second:
# you noticed (hint) and he's gone. Glance away or walk up to him: gone, and you missed it.
# Scare figures / phantoms (id "") work the same, minus the hint, and fade on their own (ttl).
func _cameos(dt: float) -> void:
	if not is_instance_valid(player) or Game.in_cutscene:
		return
	for c in cameos:
		if not is_instance_valid(c.body):
			continue
		var b: Node3D = c.body
		var d := Vector3(player.global_position.x - b.global_position.x, 0, player.global_position.z - b.global_position.z)
		b.rotation.y = atan2(-d.x, -d.z)
		if c.id == "":
			c.ttl -= dt
			if _cameo_seen(b):
				c.watch += dt
				if c.watch >= 0.3:
					_scare_out(b, c.lunge)
					c.body = null
			elif c.ttl <= 0.0:
				b.queue_free()   # never noticed: it was just... there
			continue
		if _cameo_seen(b):
			c.watch += dt
			if c.watch >= 0.5:
				Game.notice(c.id)
				_vanish(b)
		elif c.watch > 0.1 or d.length() < 6.0:
			_vanish(b)

# You saw it. A lunger springs at your face with a shriek; the rest just aren't there anymore.
func _scare_out(b: Node3D, lunge: bool) -> void:
	if not lunge:
		_vanish(b)
		return
	Game.sfx("stab", null, -2.0)
	Game.sfx("gasp", null, -6.0)
	var to: Vector3 = player.eye() - Vector3.UP * 1.6
	var t := b.create_tween()
	t.tween_property(b, "global_position", b.global_position.lerp(to, 0.7), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _vanish(b))

func _cameo_seen(b: Node3D) -> bool:
	var head := b.global_position + Vector3.UP * 1.8
	if head.distance_to(player.eye()) > 30.0 or not player.cam.is_position_in_frustum(head):
		return false
	var q := PhysicsRayQueryParameters3D.create(player.eye(), head, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _vanish(b: Node3D) -> void:
	Game.sfx("whisper", null, -10.0)
	if not dark:
		blackout(0.25)
	b.queue_free()

# Photo of the player taken from behind, for the unknown number's creepy message.
func snapshot() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 150)
	vp.world_3d = get_viewport().world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var me := Body.new()   # the player has no body in first person: pose a stand-in for the shot
	me.build(Story.BODIES.tong)
	add_child(me)
	me.global_position = player.global_position
	me.rotation.y = player.rotation.y
	# From behind if there's room, else behind-left/right or the sides: whichever is most open.
	var eye: Vector3 = player.global_position + Vector3.UP * 2.6
	var best := eye
	var best_d := -1.0
	for ang in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var dir: Vector3 = player.global_basis.z.rotated(Vector3.UP, ang)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 4.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var d: float = 4.0 if hit.is_empty() else eye.distance_to(hit.position) - 0.3
		if d > best_d + 0.5:
			best_d = d
			best = eye + dir * d
	var cam := Camera3D.new()
	cam.fov = 75
	vp.add_child(cam)
	cam.global_position = best
	cam.look_at(player.global_position + Vector3.UP * 1.3)
	cam.current = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	me.queue_free()
	return tex

# A sound somewhere 10-25 m away (on the navmesh) with nobody there.
func distant_event(sfx_name: String) -> void:
	var map := get_world_3d().navigation_map
	for i in 20:
		var p := NavigationServer3D.map_get_random_point(map, 1, false)
		var d := p.distance_to(player.global_position)
		if d > 10.0 and d < 25.0:
			var a := AudioStreamPlayer3D.new()
			a.stream = Game.stream(sfx_name)
			a.bus = "SFX"
			a.unit_size = 6.0
			a.position = p + Vector3.UP * 1.5
			a.finished.connect(a.queue_free)
			add_child(a)
			a.play()
			return
