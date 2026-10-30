# Brings stage scenes that already exist in line with story.gd without re-baking them (a re-bake
# loses editor edits): wall cells the map has turned into floor are cut out of their wall, the
# stage's "slants" (angled walls) are added, then the navmesh is baked again. Safe to run twice.
# Refuses a slant that would bury an item, light, sign or prop, and says what's in the way.
#   Godot --path . res://tools/remodel_stages.tscn -- stage_1 stage_2
extends Node

const CELL := StageBuilder.CELL

func _ready() -> void:
	var only := Array(OS.get_cmdline_user_args())
	StageBuilder.baking = true   # stage.gd skips its runtime setup (HD materials would be saved into the scene)
	for d: Dictionary in Story.STAGES:
		if not only.is_empty() and not d.scene in only:
			continue
		var path := "res://scenes/stages/%s.tscn" % d.scene
		var before := FileAccess.get_file_as_string(path)
		var root: Node3D = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		add_child(root)   # navmesh baking reads the geometry from the tree
		var nav: NavigationRegion3D = root.get_node("NavRegion")
		var changed := _open(root, nav, d.map) + _slants(root, nav, d.map, d.get("slants", []))
		if changed == 0:
			print("unchanged: ", path)
			root.free()
			continue
		nav.bake_navigation_mesh(false)
		var spawn: Vector3 = root.get_node("Markers/PlayerSpawn").position
		var dropped := StageBuilder.prune_islands(nav.navigation_mesh, spawn)
		remove_child(root)
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		var polys := nav.navigation_mesh.get_polygon_count()
		root.free()
		_tidy(path, before)
		print("remodelled %s: %d changes, navmesh %d polys (%d unreachable dropped), err=%d" % [path, changed, polys, dropped, err])
	StageBuilder.baking = false
	get_tree().quit()

# Every straight wall run (one cell thick) that covers a cell the map no longer calls '#' is cut
# into the runs that are still wall; the opened cells get floor to stand on.
func _open(root: Node3D, nav: Node3D, grid: Array) -> int:
	var opened := 0
	for b in nav.get_children():
		var shape := _box_of(b)
		if shape == null or shape.size.y < 2.9 or b.rotation != Vector3.ZERO:
			continue
		var nx := roundi(shape.size.x / CELL)
		var nz := roundi(shape.size.z / CELL)
		if nx < 1 or nz < 1 or nx > 1 and nz > 1:
			continue
		var x0 := roundi(b.position.x / CELL - nx / 2.0)
		var z0 := roundi(b.position.z / CELL - nz / 2.0)
		var step := Vector2i(1, 0) if nx > 1 else Vector2i(0, 1)
		var runs := []
		var run := []
		var gaps := []
		for k in maxi(nx, nz):
			var c := Vector2i(x0, z0) + step * k
			if grid[c.y][c.x] == "#":
				run.append(c)
			else:
				gaps.append(c)
				if not run.is_empty():
					runs.append(run)
				run = []
		if not run.is_empty():
			runs.append(run)
		if gaps.is_empty():
			continue
		for c: Vector2i in gaps:
			_warn_near(root, StageBuilder.cell_pos(c), 1.2, "opening %s" % c)
			var fs := CollisionShape3D.new()
			var fb := BoxShape3D.new()
			fb.size = Vector3(CELL, 1.0, CELL)
			fs.shape = fb
			fs.position = StageBuilder.cell_pos(c) + Vector3.DOWN * 0.5
			nav.get_node("Floor").add_child(fs, true)
			fs.owner = root
			opened += 1
		for i in runs.size():
			var piece: StaticBody3D = b if i == 0 else b.duplicate()
			if i > 0:
				nav.add_child(piece, true)
				piece.owner = root
				for ch in piece.get_children():
					ch.owner = root
			var cells: Array = runs[i]
			var size := Vector3(CELL * (cells.size() if nx > 1 else 1), shape.size.y, CELL * (cells.size() if nz > 1 else 1))
			piece.position = Vector3((cells[0].x * CELL + (cells.back().x + 1) * CELL) / 2.0, b.position.y, (cells[0].y * CELL + (cells.back().y + 1) * CELL) / 2.0)
			for ch in piece.get_children():
				if ch is CollisionShape3D:
					ch.shape = BoxShape3D.new()
					ch.shape.size = size
				elif ch is MeshInstance3D:
					var bm := BoxMesh.new()
					bm.size = size
					ch.mesh = bm
		if runs.is_empty():
			b.free()
	return opened

func _slants(root: Node3D, nav: Node3D, grid: Array, list: Array) -> int:
	var mat: Material = null
	for b in nav.get_children():
		var shape := _box_of(b)
		if shape and shape.size.y >= 2.9 and mat == null:
			mat = b.get_children().filter(func(c): return c is MeshInstance3D)[0].material_override
	var added := 0
	for sl in list:
		var a: Vector2 = sl[0]
		var bb: Vector2 = sl[1]
		var at := Vector3((a.x + bb.x) / 2 * CELL, StageBuilder.WALL_H / 2, (a.y + bb.y) / 2 * CELL)
		if nav.get_children().any(func(n): return n is StaticBody3D and String(n.name).begins_with("Slant") and n.position.distance_to(at) < 0.05):
			continue
		var blocked := _in_the_way(root, a * CELL, bb * CELL, _pocket(grid, a, bb))
		if not blocked.is_empty():
			push_warning("slant %s-%s skipped, in the way: %s" % [a, bb, blocked])
			continue
		var w := StageBuilder.slant_wall(a, bb, mat)
		nav.add_child(w, true)
		w.owner = root
		for ch in w.get_children():
			ch.owner = root
		added += 1
	return added

# The corner a slant cuts off: of the two grid points that make a triangle with it, the one with
# wall on three sides. None (INF) for a divider standing out from one wall.
func _pocket(grid: Array, a: Vector2, b: Vector2) -> Vector2:
	for c: Vector2 in [Vector2(a.x, b.y), Vector2(b.x, a.y)]:
		var walls := 0
		for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			var cell: Vector2i = Vector2i(c) + o
			if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[0].length() or grid[cell.y][cell.x] == "#":
				walls += 1
		if walls >= 3:
			return c * CELL
	return Vector2.INF

# Things a slant must not bury or stand on: anything within 0.7 m of it, or behind it in the cut-off corner.
func _in_the_way(root: Node3D, a: Vector2, b: Vector2, corner: Vector2) -> Array:
	var out := []
	for n in _things(root):
		var p := Vector2(n.global_position.x, n.global_position.z)
		var behind := corner != Vector2.INF and Geometry2D.is_point_in_polygon(p, PackedVector2Array([a, b, corner]))
		if behind or Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.7:
			out.append("%s %s" % [n.name, p.snapped(Vector2.ONE * 0.1)])
	return out

func _warn_near(root: Node3D, p: Vector3, r: float, what: String) -> void:
	for n in _things(root):
		if Vector2(n.global_position.x - p.x, n.global_position.z - p.z).length() < r:
			push_warning("%s: %s is right by it" % [what, n.name])

# Items, lights, signs, markers, coworkers, props: everything but the walls, floor and ceiling.
func _things(root: Node3D) -> Array:
	var nav := root.get_node("NavRegion")
	return root.find_children("*", "Node3D", true, false).filter(func(n):
		if n.get_parent() == nav:
			var shape := _box_of(n)
			return not (n.name in [&"Floor", &"Ceiling"] or shape and shape.size.y >= 2.9)
		return n is Area3D or n is Light3D or n is Marker3D or n is Label3D or n is CharacterBody3D)

func _box_of(n: Node) -> BoxShape3D:
	if not n is StaticBody3D:
		return null
	var shapes := n.get_children().filter(func(c): return c is CollisionShape3D)
	if shapes.size() == 1 and shapes[0].shape is BoxShape3D:
		return shapes[0].shape
	return null

# Make the saved file look like the editor's: ResourceSaver writes every unset shader uniform as
# "= null" and, run from the command line, drops the uids the file had. Keeps the diff small.
func _tidy(path: String, before: String) -> void:
	var uids := {}   # path or "" (the scene itself) -> uid="..."
	for l in before.split("\n"):
		var m := RegEx.create_from_string('^\\[(gd_scene|ext_resource).*?(uid="[^"]+")(.*path="([^"]+)")?').search(l)
		if m:
			uids[m.get_string(4)] = m.get_string(2)
	var keep := PackedStringArray()
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.begins_with("shader_parameter/") and l.ends_with(" = null"):
			continue
		if l.begins_with("[gd_scene") and not "uid=" in l and uids.has(""):
			l = l.replace("]", " %s]" % uids[""])
		var m := RegEx.create_from_string('^\\[ext_resource [^\\]]*path="([^"]+)"').search(l)
		if m and not "uid=" in l and uids.has(m.get_string(1)):
			l = l.replace(" path=", " %s path=" % uids[m.get_string(1)])
		keep.append(l)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(keep))
	f.close()
