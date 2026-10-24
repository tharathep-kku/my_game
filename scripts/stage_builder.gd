# Turns an ASCII map (story.gd) into a stage scene tree. Used once by tools/bake_stages.tscn to
# generate scenes/stages/*.tscn (then you edit those in the editor), and by tests for tiny maps.
# Cell = 2m, map origin at (0,0,0). Layout:
#   Stage (stage.gd) > WorldEnvironment, NavRegion (all solid geometry, baked navmesh), Items,
#   Lights, Signs, Triggers, Markers (PlayerSpawn, Route/1..n), Cameos, Exit, <coworker>
#   Tutorial only: Coworkers (coworker.gd), Windows, Tutorial (tutorial.gd)
class_name StageBuilder
extends RefCounted

const CELL := 2.0
const WALL_H := 3.0
const SOLID := "#=DBkbodnKCctTXHWeQYFmiOy"
const PSX := preload("res://shaders/psx.gdshader")
const PICKUP := preload("res://scripts/pickup.gd")
const STAGE := preload("res://scripts/stage.gd")
const STORY_TRIGGER := preload("res://scripts/story_trigger.gd")
const SCARE := preload("res://scripts/scare.gd")
const TUTORIAL := preload("res://scripts/tutorial.gd")
const COWORKER := preload("res://scripts/coworker.gd")
const MOBS := {"M": "manager", "S": "sweeper", "G": "goblin", "R": "guard", "N": "dummy", "V": "dummy", "I": "hr", "U": "doctor"}
const LOOP := preload("res://scripts/loop.gd")
# stage-data keys copied onto the stage root's Inspector ("Stage mechanics")
const ROOT_KEYS := ["dark_start", "rage_on_goal", "rage_line", "rage_objective", "flicker", "finale", "wet_start"]

static var baking := false   # true while tools/bake_stages runs: stage.gd skips its runtime setup

var root: Node3D
var nav: NavigationRegion3D
var grid: Array = []
var data: Dictionary
var wall_nodes := 0
var _nodes := {}
var _count := {}
var _tex_cache := {}
var _sky: StandardMaterial3D   # what every window shows
var _rng := RandomNumberGenerator.new()

static func build(stage_data: Dictionary, props := {}, with_player := true) -> Node3D:
	return StageBuilder.new()._build(stage_data, props, with_player)

func _build(stage_data: Dictionary, props: Dictionary, with_player: bool) -> Node3D:
	_rng.seed = 42
	data = stage_data
	grid = data.map
	var h := grid.size()
	var w: int = grid[0].length()
	root = Node3D.new()
	root.name = "Stage"
	root.set_script(STAGE)
	root.data = data
	root.with_player = with_player
	for k in props:
		root.set(k, props[k])
	for k in ROOT_KEYS:
		if data.has(k):
			root.set(k, data[k])
	_environment()
	nav = NavigationRegion3D.new()
	nav.name = "NavRegion"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.25
	nav.navigation_mesh = nm
	root.add_child(nav)
	for g in ["Items", "Lights", "Emergency", "Signs", "Triggers", "Scares", "Markers", "Cameos", "Coworkers", "Windows"]:
		_nodes[g] = Node3D.new()
		_nodes[g].name = g
		root.add_child(_nodes[g])
	var route_node := Node3D.new()
	route_node.name = "Route"
	_nodes.Markers.add_child(route_node)
	_floor_and_ceiling(w, h)
	_walls(w, h)
	var route := {}
	for z in h:
		for x in w:
			var c := Vector2i(x, z)
			var ch: String = grid[z][x]
			var p := cell_pos(c)
			match ch:
				"=":
					var along_x := _at(x - 1, z) in "=D#d" or _at(x + 1, z) in "=D#d"
					var size := Vector3(CELL, 1.3, 0.12) if along_x else Vector3(0.12, 1.3, CELL)
					_block(p + Vector3.UP * 0.65, size, Color(0.35, 0.42, 0.55), "fabric", "Partition")
				"D":
					_desk(p)
					_hide("desk", c, p + Vector3.UP * 0.35)
				"H": _locker(c, p)
				"W": _stall(c, p)
				"s": _item("throwable", p + Vector3.UP * 0.08, Vector3(0.14, 0.16, 0.14), Color(0.9, 0.9, 0.95))
				"e":
					_prop("sideTableDrawers", p, 0.0, 2.0)
					_note(_item("read", p + Vector3.UP * 0.8, Vector3(0.3, 0.02, 0.4), Color(0.85, 0.9, 1.0)), data.get("notes", []), _nth("e"))
				"Z": _item("clue", p + Vector3.UP * 0.15, Vector3(0.28, 0.2, 0.22), Color(0.75, 0.95, 1.0))
				"z": _item("powerbank", p + Vector3.UP * 0.06, Vector3(0.12, 0.05, 0.2), Color(0.1, 0.9, 0.3))
				"g":
					var b := Body.new()
					b.name = "GuardCameo%d" % _nth("g")
					b.preset = "guard"
					b.position = p
					_nodes.Cameos.add_child(b)
				"!": _trigger(p, _nth("!"))
				"r": _sign(p, _nth("r"))
				"B": _rack(p)
				"k": _prop("kitchenBar", p, 0.0, 2.4)
				"Q": _prop("bedSingle", p, PI / 2, 2.2)
				"b":
					_prop("cardboardBoxClosed", p, 0.3, 2.5)
					_prop("cardboardBoxClosed", p + Vector3(0.1, 0.7, 0.1), 1.0, 2.2, false)
				"o": _prop("pottedPlant", p, 0.0, 2.2)
				"d":
					_prop("sideTableDrawers", p, 0.0, 2.0)
					_item("doc", p + Vector3.UP * 0.8, Vector3(0.42, 0.06, 0.32), Color(0.95, 0.95, 0.85))
				"n":
					_desk(p)
					_note(_item("note", p + Vector3(0.3, 0.8, 0), Vector3(0.18, 0.03, 0.18), Color(1.0, 0.9, 0.2)), data.get("postits", []), _nth("n"))
				"Y":   # breaker panel
					_block(p + Vector3.UP * 1.2, Vector3(0.7, 1.0, 0.7), Color(0.55, 0.5, 0.2), "fabric", "BreakerBox")
					_item("breaker", p + Vector3.UP * 1.2, Vector3(0.75, 0.25, 0.75), Color(1.0, 0.25, 0.1))
				"F":   # fingerprint scanner on a stand
					_block(p + Vector3.UP * 0.55, Vector3(0.4, 1.1, 0.4), Color(0.2, 0.2, 0.22), "fabric", "ScannerStand")
					_item("scanner", p + Vector3.UP * 1.15, Vector3(0.3, 0.08, 0.3), Color(0.2, 1.0, 0.4))
				"f": _item("fuse", p + Vector3.UP * 0.1, Vector3(0.12, 0.12, 0.3), Color(1.0, 0.6, 0.1))
				"p":   # fuse panel for the scanner, flat on the wall east of the cell
					var panel := _item("fuse_box", p + Vector3(0.88, 1.4, 0), Vector3(0.15, 0.8, 0.6), Color(0.45, 0.5, 0.55))
					panel.name = "FuseBox"
				"u": _emergency(p)
				"J": _scare(p, _nth("J"))
				"A": _coworker(p, _nth("A"))
				"i": _block(p + Vector3.UP * WALL_H / 2, Vector3(CELL, WALL_H, 0.2), data.wall, "wall", "ThinWall")
				"O": _door(c, p)
				"m": _mirror(c, p)
				"K":
					_desk(p)
					var glow := OmniLight3D.new()
					glow.name = "ScreenGlow"
					glow.light_color = Color(0.3, 0.6, 1.0)
					glow.omni_range = 3.0
					glow.position = p + Vector3(0, 1.3, 0)
					root.add_child(glow)
					_item("pc", p + Vector3(0, 1.1, 0), Vector3.ZERO, Color.WHITE).code = data.get("pc_code", "")
				"C", "c":
					_prop("sideTableDrawers", p, 0.0, 2.0)
					_prop("kitchenCoffeeMachine", p + Vector3.UP * 0.77, 0.0, 2.0, false)
					_item("coffee_goal" if ch == "C" else "coffee", p + Vector3.UP * 1.0, Vector3.ZERO, Color.WHITE)
				"t":
					_prop("sideTableDrawers", p, 0.0, 2.0)
					_prop("radio", p + Vector3.UP * 0.77, 0.0, 1.6, false)
					_item("phone", p + Vector3.UP * 0.9, Vector3.ZERO, Color.WHITE)
				"T":
					_prop("kitchenBar", p, 0.0, 2.4)
					_item("guard_phone", p + Vector3.UP * 1.05, Vector3(0.12, 0.03, 0.22), Color(0.05, 0.05, 0.08))
				"X": _exit(c, p)
				"L": _light(p)
				"P":
					var m := Marker3D.new()
					m.name = "PlayerSpawn"
					m.position = p
					m.rotation.y = _spawn_yaw(c)
					_nodes.Markers.add_child(m)
				"y":   # this stage's goal item ("items" in reading order: title + what it says)
					_prop("sideTableDrawers", p, 0.0, 2.0)
					var it := _item("file", p + Vector3.UP * 0.8, Vector3(0.36, 0.07, 0.28), Color(0.95, 0.8, 0.45))
					var list: Array = data.get("items", [])
					var n := _nth("y")
					if n < list.size():
						it.title = list[n].get("title", "")
						it.text = list[n].get("text", "")
						it.evidence = list[n].get("evidence", false)
				"v", "w": _loop_trigger(p, ch == "v")
				"M", "S", "G", "R", "N", "V", "I", "U":
					var n: Node3D = load("res://scenes/mobs/%s.tscn" % MOBS[ch]).instantiate()
					n.position = p
					if ch == "V":
						n.name = "Watcher"
						n.stay = true
					root.add_child(n)
				_:
					if ch.is_valid_int():
						route[ch.to_int()] = p
	var keys := route.keys()
	keys.sort()
	for k in keys:
		var m := Marker3D.new()
		m.name = str(k)
		m.position = route[k]
		route_node.add_child(m)
	for c: Vector2i in data.get("windows", []):
		_window(c)
	if data.has("phone"):
		_tutorial()
	if data.has("loop"):
		_loop_node()
	for n in root.get_children():   # coworkers start facing the player spawn
		if n is Npc and _nodes.Markers.has_node("PlayerSpawn"):
			var d: Vector3 = _nodes.Markers.get_node("PlayerSpawn").position - n.position
			n.rotation.y = atan2(-d.x, -d.z)
	root.wall_nodes = wall_nodes
	_own(root)
	return root

# Everything we created belongs to the root so PackedScene.pack saves it; instanced scenes
# (GLB props, mob scenes) are saved as instances, so their insides are left alone.
func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c)

func _nth(ch: String) -> int:
	var i: int = _count.get(ch, 0)
	_count[ch] = i + 1
	return i

func _at(x: int, z: int) -> String:
	if z < 0 or z >= grid.size() or x < 0 or x >= grid[z].length():
		return "#"
	return grid[z][x]

static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL + CELL / 2, 0, c.y * CELL + CELL / 2)

# Face the longest open run from the spawn cell (never start staring at a wall).
func _spawn_yaw(s: Vector2i) -> float:
	var best := Vector2i(0, 1)
	var best_n := -1
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var n := 0
		while not _at(s.x + d.x * (n + 1), s.y + d.y * (n + 1)) in SOLID:
			n += 1
		if n > best_n:
			best_n = n
			best = d
	return atan2(-float(best.x), -float(best.y))

# Unit vector from cell c toward its first walkable neighbour (where lockers/stalls/desks open).
func _open_dir(c: Vector2i) -> Vector3:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if not _at(c.x + d.x, c.y + d.y) in SOLID:
			return Vector3(d.x, 0, d.y)
	return Vector3.BACK

static func psx_mat(color: Color, tex: Texture2D = null, world := false, emit := Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("world_uv", world)
	m.set_shader_parameter("emission", Vector3(emit.r, emit.g, emit.b))
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	return m

func _tex(kind: String) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var v := 1.0
			match kind:
				"carpet": v = 0.8 + _rng.randf() * 0.2 - (0.08 if (x / 4 + y / 4) % 2 == 0 else 0.0)
				"wall": v = 0.9 + (0.07 if x % 8 == 0 else 0.0) + _rng.randf() * 0.04
				"ceiling": v = 0.95 - (0.4 if x == 0 or y == 0 else 0.0) + _rng.randf() * 0.04
				_: v = 0.85 + _rng.randf() * 0.15
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = data.light * 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.07
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"   # stage.gd looks it up by name
	we.environment = env
	root.add_child(we)

func _floor_and_ceiling(w: int, h: int) -> void:
	var size := Vector2(w * CELL, h * CELL)
	var center := Vector3(size.x / 2, 0, size.y / 2)
	# Floor collider only under non-wall cells (row runs). Recast bakes box colliders as hollow
	# shells, so floor running under a wall would leave walkable islands inside every wall.
	var body := StaticBody3D.new()
	body.name = "Floor"
	nav.add_child(body)
	for z in h:
		var x := 0
		while x < w:
			var x0 := x
			while x < w and grid[z][x] != "#":
				x += 1
			if x > x0:
				var s := CollisionShape3D.new()
				var b := BoxShape3D.new()
				b.size = Vector3((x - x0) * CELL, 1.0, CELL)
				s.shape = b
				s.position = Vector3((x0 + (x - x0) / 2.0) * CELL, -0.5, z * CELL + CELL / 2)
				body.add_child(s)
			x = maxi(x, x0 + 1)
	var lid := StaticBody3D.new()   # ceiling collider: wall/rack tops get no headroom, so no navmesh up there
	lid.name = "Ceiling"
	var ls := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(size.x, 0.5, size.y)
	ls.shape = lb
	ls.position = center + Vector3.UP * (WALL_H + 0.25)
	lid.add_child(ls)
	nav.add_child(lid)
	for up in [false, true]:
		var m := MeshInstance3D.new()
		m.name = "CeilingMesh" if up else "FloorMesh"
		var pm := PlaneMesh.new()
		pm.size = size
		m.mesh = pm
		m.position = center + (Vector3.UP * WALL_H if up else Vector3.ZERO)
		if up:
			m.rotation.x = PI
		m.material_override = psx_mat(Color(0.8, 0.8, 0.78) if up else data.floor, _tex("ceiling" if up else "carpet"), true)
		(root if up else body).add_child(m)

func _block(pos: Vector3, size: Vector3, color: Color, tex: String, nm := "Block", parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = nm
	body.position = pos
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	s.shape = b
	body.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	if not _tex_cache.has(tex + str(color)):
		_tex_cache[tex + str(color)] = psx_mat(color, _tex(tex), true)
	m.material_override = _tex_cache[tex + str(color)]
	body.add_child(m)
	(parent if parent else nav).add_child(body)
	return body

# One collider + mesh per run of '#': horizontal runs first, leftover cells merged vertically.
func _walls(w: int, h: int) -> void:
	var done := {}
	for z in h:
		var x := 0
		while x < w:
			var x0 := x
			while x < w and grid[z][x] == "#":
				x += 1
			if x - x0 >= 2:
				for i in range(x0, x):
					done[Vector2i(i, z)] = true
				_wall_box(Vector2(x0, z), Vector2(x - x0, 1))
			x = maxi(x, x0 + 1)
	for x in w:
		var z := 0
		while z < h:
			var z0 := z
			while z < h and grid[z][x] == "#" and not done.has(Vector2i(x, z)):
				z += 1
			if z > z0:
				_wall_box(Vector2(x, z0), Vector2(1, z - z0))
			z = maxi(z, z0 + 1)

func _wall_box(at: Vector2, cells: Vector2) -> void:
	_block(Vector3((at.x + cells.x / 2) * CELL, WALL_H / 2, (at.y + cells.y / 2) * CELL), Vector3(cells.x * CELL, WALL_H, cells.y * CELL), data.wall, "wall", "Wall")
	wall_nodes += 1

# Kenney model, bottom-centred at pos; solid props get a box collider from the mesh bounds.
func _prop(model: String, pos: Vector3, rot := 0.0, scale_by := 2.0, solid := true) -> Node3D:
	var n: Node3D = load("res://assets/models/%s.glb" % model).instantiate()
	var ab := AABB()
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var cab: AABB = c.transform * c.get_aabb()
		ab = cab if ab.size == Vector3.ZERO else ab.merge(cab)
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.name = model.capitalize().replace(" ", "")
	holder.position = pos
	holder.rotation.y = rot
	n.scale = Vector3.ONE * scale_by
	n.position = -Vector3(ab.get_center().x, ab.position.y, ab.get_center().z) * scale_by
	holder.add_child(n)
	if solid:
		var s := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = ab.size * scale_by
		s.shape = b
		s.position.y = b.size.y / 2
		holder.add_child(s)
	nav.add_child(holder)
	return holder

func _desk(p: Vector3) -> void:
	var r := _rng.randf_range(-0.08, 0.08)
	_prop("desk", p, r)
	# "screens_ok" (the tutorial's daytime office): monitors face the chair. Everywhere else, at
	# night, every one of them has been turned to face away (Tong notices in the stage 1 intro).
	_prop("computerScreen", p + Vector3(0, 0.77, -0.15), r + (0.0 if data.get("screens_ok", false) else PI), 2.0, false)
	_prop("computerKeyboard", p + Vector3(0, 0.77, 0.2), r + PI, 2.0, false)
	_prop("chairDesk", p + Vector3(0, 0, 0.85), r + PI + _rng.randf_range(-0.5, 0.5), 2.0, false)

func _rack(p: Vector3) -> void:
	var rack := _block(p + Vector3.UP * 1.1, Vector3(1.6, 2.2, 1.2), Color(0.12, 0.13, 0.16), "fabric", "ServerRack")
	for i in 6:   # status LEDs
		var led := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.02)
		led.mesh = bm
		var col := Color(0.2, 1, 0.3) if _rng.randf() > 0.3 else Color(1, 0.6, 0.1)
		led.material_override = psx_mat(col, null, false, col * 2.0)
		led.position = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.7, 0.9), 0.61 * (1 if i % 2 else -1))
		rack.add_child(led)

# 'O' -> a closed door in a gap of the wall: brown slab across the gap, frame above, a handle.
func _door(c: Vector2i, p: Vector3) -> void:
	var along_x := _at(c.x - 1, c.y) == "#" and _at(c.x + 1, c.y) == "#"   # walls left and right: the door runs along x
	var size := Vector3(CELL, 2.2, 0.15) if along_x else Vector3(0.15, 2.2, CELL)
	var d := _block(p + Vector3.UP * 1.1, size, Color(0.42, 0.26, 0.15), "fabric", "Door")
	_block(p + Vector3.UP * (2.2 + (WALL_H - 2.2) / 2), Vector3(size.x, WALL_H - 2.2, size.z), data.wall, "wall", "DoorTop")
	var knob := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.06, 0.24) if not along_x else Vector3(0.24, 0.06, 0.1)
	knob.mesh = bm
	knob.material_override = psx_mat(Color(0.75, 0.7, 0.4))
	knob.position = (Vector3(0.6, 0, 0) if along_x else Vector3(0, 0, 0.6)) + Vector3.UP * -0.1
	d.add_child(knob)

# Pickup with a small glowing box so it can be found. Also used at runtime (thrown objects).
static func make_item(kind: String, pos: Vector3, size: Vector3, color: Color) -> Area3D:
	var a: Area3D = PICKUP.new()
	a.name = kind.capitalize().replace(" ", "")
	a.position = pos
	a.setup(kind)
	if size != Vector3.ZERO:
		var m := MeshInstance3D.new()
		m.name = "Mesh"
		var bm := BoxMesh.new()
		bm.size = size
		m.mesh = bm
		m.material_override = psx_mat(color, null, false, color * 0.35)
		a.add_child(m)
	return a

func _item(kind: String, pos: Vector3, size: Vector3, color: Color) -> Area3D:
	var a := make_item(kind, pos, size, color)
	_nodes.Items.add_child(a, true)   # readable names (Doc, Doc2...) for the editor
	return a

func _light(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.name = "CeilingLight"
	l.light_color = data.light
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.omni_attenuation = 1.2
	l.position = p + Vector3.UP * (WALL_H - 0.3)
	_nodes.Lights.add_child(l)
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.04, 0.35)
	panel.mesh = bm
	panel.material_override = psx_mat(data.light, null, false, data.light * 1.5)
	panel.position = Vector3.UP * 0.27
	l.add_child(panel)

func _exit(c: Vector2i, p: Vector3) -> void:
	var ex := Node3D.new()
	ex.name = "Exit"
	root.add_child(ex)
	var along_x := _at(c.x, c.y - 1) != "#" or _at(c.x, c.y + 1) != "#"   # floor above/below = wall runs along x
	var size := Vector3(CELL, WALL_H, 0.2) if along_x else Vector3(0.2, WALL_H, CELL)
	_block(p + Vector3.UP * WALL_H / 2, size, Color(0.45, 0.25, 0.12), "fabric", "Door", ex)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = data.get("exit_label", "EXIT")
	sign.font_size = 64
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1, 0.2, 0.2)
	sign.position = p + Vector3.UP * 2.6
	ex.add_child(sign)
	var trig := Area3D.new()
	trig.name = "Trigger"
	trig.collision_layer = 0
	trig.collision_mask = 2
	trig.position = p + Vector3.UP
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(CELL * 0.9, 2, CELL * 0.9)
	s.shape = b
	trig.add_child(s)
	ex.add_child(trig)

# Hide spot: player's eye goes to `inside`, looking out along the open side; NPCs search from the front cell.
func _hide(kind: String, c: Vector2i, inside: Vector3) -> Area3D:
	var dir := _open_dir(c)
	var a: Area3D = PICKUP.new()
	a.name = "Hide" + kind.capitalize()
	a.position = inside
	a.setup("hide", 0.6)
	a.hide_type = kind
	a.inside = inside
	a.look = dir
	a.front = cell_pos(c + Vector2i(int(dir.x), int(dir.z)))
	_nodes.Items.add_child(a, true)   # readable names (Doc, Doc2...) for the editor
	return a

func _locker(c: Vector2i, p: Vector3) -> void:
	var dir := _open_dir(c)
	var locker := _block(p + Vector3.UP * 1.05, Vector3(0.9, 2.1, 0.9), Color(0.42, 0.48, 0.5), "wall", "Locker")
	for i in 4:   # vent slits
		var slit := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, 0.03, 0.02)
		slit.mesh = bm
		slit.material_override = psx_mat(Color(0.02, 0.02, 0.02))
		slit.position = dir * 0.46 + Vector3.UP * (0.5 + i * 0.07)
		slit.rotation.y = atan2(dir.x, dir.z)
		locker.add_child(slit)
	_hide("locker", c, p + Vector3.UP * 1.5 + dir * 0.25)

func _stall(c: Vector2i, p: Vector3) -> void:
	var dir := _open_dir(c)
	var side := Vector3(dir.z, 0, -dir.x)
	var col := Color(0.6, 0.66, 0.62)
	var across := Vector3(absf(side.x) * CELL + 0.1, 1.9, absf(side.z) * CELL + 0.1)
	var along := Vector3(absf(dir.x) * CELL + 0.1, 1.9, absf(dir.z) * CELL + 0.1)
	_block(p - dir * 0.95 + Vector3.UP * 0.95, across, col, "fabric", "StallWall")
	_block(p + side * 0.95 + Vector3.UP * 0.95, along, col, "fabric", "StallWall")
	_block(p - side * 0.95 + Vector3.UP * 0.95, along, col, "fabric", "StallWall")
	var door := _block(p + dir * 0.95 + Vector3.UP * 1.1, Vector3(across.x * 0.8, 1.6, across.z * 0.8), col.darkened(0.2), "fabric", "StallDoor")
	door.position += side * 0.15   # left ajar: a gap to peek through
	var seat := MeshInstance3D.new()
	seat.name = "Toilet"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.45, 0.6)
	seat.mesh = bm
	seat.material_override = psx_mat(Color(0.95, 0.95, 0.95))
	seat.position = p - dir * 0.5 + Vector3.UP * 0.22
	nav.add_child(seat)
	_hide("stall", c, p + Vector3.UP * 1.45 + dir * 0.3)

# Player-detecting box (layer 0, mask 2) of size cells x 2m x cells.
func _area(script: Script, nm: String, p: Vector3, parent: Node, cells := 1.0) -> Area3D:
	var t: Area3D = script.new()
	t.name = nm
	t.collision_layer = 0
	t.collision_mask = 2
	t.position = p + Vector3.UP
	var s := CollisionShape3D.new()
	s.name = "Shape"
	var b := BoxShape3D.new()
	b.size = Vector3(CELL * cells, 2, CELL * cells)
	s.shape = b
	t.add_child(s)
	parent.add_child(t)
	return t

# '!' -> story_trigger.gd, filled from the stage's "triggers" (reading order).
func _trigger(p: Vector3, id: int) -> void:
	var t := _area(STORY_TRIGGER, "Trigger%d" % id, p, _nodes.Triggers)
	var d: Dictionary = data.get("triggers", [])[id] if id < data.get("triggers", []).size() else {}
	t.say = d.get("say", "")
	t.secs = d.get("secs", 4.0)
	t.sfx = d.get("sfx", "")
	t.photo = d.get("photo", false)
	if d.has("text"):
		t.thread = d.text[0]
		t.message = d.text[1]

# 'J' -> scare.gd, filled from the stage's "scares" (reading order). "at" = map cell of the
# figure / sound (a child marker you can drag in the editor), "cells" = trigger box size.
func _scare(p: Vector3, id: int) -> void:
	var list: Array = data.get("scares", [])
	if id >= list.size():
		return
	var d: Dictionary = list[id]
	var s := _area(SCARE, "Scare%d_%s" % [id, d.kind], p, _nodes.Scares, d.get("cells", 1.0))
	for k in ["kind", "preset", "sfx", "secs", "line", "chance"]:
		if d.has(k):
			s.set(k, d[k])
	for k in ["at", "to"]:
		if d.has(k):
			var m := Marker3D.new()
			m.name = k.capitalize()
			m.position = cell_pos(d[k]) - s.position   # floor level
			s.add_child(m)

# 'e' / 'n' notes: text + what reading gives, from the stage's "notes" / "postits".
func _note(item: Area3D, list: Array, id: int) -> void:
	if id >= list.size():
		return
	var d: Dictionary = list[id]
	item.title = d.get("title", "")
	item.text = d.get("text", "")
	item.reveal = d.get("reveal", "none")
	item.evidence = d.get("evidence", false)

# Dim red light that only comes on when the power is out (stage.gd set_dark).
func _emergency(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.name = "EmergencyLight"
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.position = p + Vector3.UP * (WALL_H - 0.4)
	l.visible = false
	_nodes.Emergency.add_child(l)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.15, 0.15)
	box.mesh = bm
	box.material_override = psx_mat(Color(0.4, 0.05, 0.05), null, false, Color(0.8, 0.05, 0.05))
	box.position = Vector3.UP * 0.3
	l.add_child(box)

# 'A' -> friendly daytime coworker (coworker.gd), filled from the stage's "coworkers" (reading
# order). "to" = cell they walk / mop to, "look" = cell they face, "offset" = metres off the cell centre.
func _coworker(p: Vector3, id: int) -> void:
	var list: Array = data.get("coworkers", [])
	if id >= list.size():
		return
	var d: Dictionary = list[id]
	var c: AnimatableBody3D = COWORKER.new()
	c.name = d.preset.capitalize()
	c.position = p + d.get("offset", Vector3.ZERO)
	c.setup(d.preset)
	c.lines = PackedStringArray(d.get("lines", []))
	for k in ["display_name", "work", "speed", "bye", "leave_at"]:
		if d.has(k):
			c.set(k, d[k])
	if d.has("to"):
		c.walk_to = cell_pos(d.to)
	var look: Vector3 = cell_pos(d.get("look", d.get("to", Vector2i.ZERO))) - c.position
	c.rotation.y = atan2(-look.x, -look.z)
	_nodes.Coworkers.add_child(c)

# Daylight in a wall cell `c`, on the face toward the room. One shared material: stage.gd
# set_gloom slides it from sky blue to night.
func _window(c: Vector2i) -> void:
	var dir := _open_dir(c)
	if not _sky:
		_sky = StandardMaterial3D.new()
		_sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sky.albedo_color = Color(0.02, 0.03, 0.07)
	var w := MeshInstance3D.new()
	w.name = "Window"
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.3)
	w.mesh = q
	w.material_override = _sky
	w.position = cell_pos(c) + dir * (CELL / 2 + 0.02) + Vector3.UP * 1.75
	w.rotation.y = atan2(dir.x, dir.z)   # a quad faces +Z: turn it into the room
	_nodes.Windows.add_child(w, true)
	var bar := MeshInstance3D.new()   # glazing bar down the middle
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 1.3, 0.04)
	bar.mesh = bm
	bar.material_override = psx_mat(Color(0.85, 0.85, 0.82))
	w.add_child(bar)

# 'm' -> one 2 m length of washroom mirror, running along x: basin counter below, wall above, and
# an opening between them with a sheen of glass. Behind it the map repeats the washroom mirrored
# (the PS1 trick), and tutorial.gd moves Tong's reflection around in there.
func _mirror(c: Vector2i, p: Vector3) -> void:
	_block(p + Vector3.UP * 0.425, Vector3(CELL, 0.85, 1.0), Color(0.88, 0.9, 0.9), "fabric", "Basin")
	_block(p + Vector3.UP * 2.65, Vector3(CELL, 0.7, 0.2), data.wall, "wall", "MirrorTop")
	var frame := Color(0.36, 0.38, 0.42)   # steel rim: bottom, top, and a post where the run ends
	var rims := [[Vector3(0, 0.88, 0), Vector3(CELL, 0.06, 0.23)], [Vector3(0, 2.27, 0), Vector3(CELL, 0.06, 0.23)]]
	for side in [-1, 1]:
		if _at(c.x + side, c.y) != "m":
			rims.append([Vector3(side * (CELL / 2 - 0.03), 1.575, 0), Vector3(0.06, 1.45, 0.23)])
	for r in rims:
		var m := MeshInstance3D.new()
		m.name = "MirrorFrame"
		var bm := BoxMesh.new()
		bm.size = r[1]
		m.mesh = bm
		m.material_override = psx_mat(frame)
		m.position = p + r[0]
		nav.add_child(m, true)
	var g := MeshInstance3D.new()
	g.name = "Glass"
	var q := QuadMesh.new()
	q.size = Vector2(CELL, 1.45)
	g.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.7, 0.85, 0.9, 0.1)
	g.material_override = mat
	g.position = p + Vector3.UP * 1.575
	nav.add_child(g)

# Tutorial (tutorial.gd): the stranger's texts ("phone") + where the mirror is. MirrorPlane sits in
# the middle of the 'm' cells with +Z pointing into the mirror ("mirror_faces" = map direction
# from the mirror toward the washroom); MirrorSpot is the box in front that starts the ending.
func _tutorial() -> void:
	var tut: Node3D = TUTORIAL.new()
	tut.name = "Tutorial"
	root.add_child(tut)
	tut.sender = data.phone.sender
	tut.controls = PackedStringArray(data.phone.controls)
	tut.rumour = PackedStringArray(data.phone.rumour)
	tut.day_clock = data.clock
	var mid := Vector3.ZERO
	var n := 0
	for z in grid.size():
		for x in grid[z].length():
			if grid[z][x] == "m":
				mid += cell_pos(Vector2i(x, z))
				n += 1
	mid /= maxf(n, 1.0)
	var room: Vector2i = data.get("mirror_faces", Vector2i(0, -1))
	var plane := Marker3D.new()
	plane.name = "MirrorPlane"
	plane.position = mid
	plane.rotation.y = atan2(-room.x, -room.y)
	tut.add_child(plane)
	var spot := Area3D.new()
	spot.name = "MirrorSpot"
	spot.collision_layer = 0
	spot.collision_mask = 2
	spot.position = mid + Vector3(room.x, 0, room.y) * 1.8 + Vector3.UP
	var s := CollisionShape3D.new()
	s.name = "Shape"
	var b := BoxShape3D.new()
	b.size = Vector3(n * CELL - 1.0, 2, 2.6) if room.x == 0 else Vector3(2.6, 2, n * CELL - 1.0)
	s.shape = b
	spot.add_child(s)
	tut.add_child(spot)

# Fire-stairs loop (loop.gd): 'v' = end of the corridor (went on), 'w' = behind the start (turned back).
var _loop: Node3D
func _loop_node() -> Node3D:
	if not _loop:
		_loop = LOOP.new()
		_loop.name = "Loop"
		root.add_child(_loop)
		_loop.laps = data.loop.get("laps", 8)
	return _loop

func _loop_trigger(p: Vector3, forward: bool) -> void:
	var t := Area3D.new()
	t.name = "Forward" if forward else "Back"
	t.collision_layer = 0
	t.collision_mask = 2
	t.position = p + Vector3.UP
	var s := CollisionShape3D.new()
	s.name = "Shape"
	var b := BoxShape3D.new()
	b.size = Vector3(CELL, 2, CELL)
	s.shape = b
	t.add_child(s)
	_loop_node().add_child(t, true)

func _sign(p: Vector3, id: int) -> void:
	var signs: Array = data.get("signs", [])
	var l := Label3D.new()
	l.name = "Sign%d" % id
	l.text = signs[id] if id < signs.size() else "?"
	l.font_size = 72
	l.outline_size = 12
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.modulate = Color(0.85, 0.9, 0.8)
	l.position = p + Vector3.UP * 2.5
	_nodes.Signs.add_child(l)
