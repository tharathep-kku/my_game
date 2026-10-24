# Generates scenes/stages/stage_N.tscn and scenes/endings/ending_X.tscn from the ASCII maps in
# story.gd, with the navmesh baked. After that, the .tscn files are what you edit in the editor.
#   Godot --path . res://tools/bake_stages.tscn             (only creates missing scenes)
#   Godot --path . res://tools/bake_stages.tscn -- --force  (overwrites: loses editor edits!)
#   Godot --path . res://tools/bake_stages.tscn -- --force ending_C stage_hr   (overwrites only these)
extends Node

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var force := "--force" in args
	var only := args.filter(func(a): return a != "--force")
	var jobs := []
	for i in Story.STAGES.size():
		jobs.append(["res://scenes/stages/%s.tscn" % Story.STAGES[i].scene, Story.STAGES[i], {"stage_index": i}, true])
	jobs.append(["res://scenes/stages/tutorial.tscn", Story.TUTORIAL, {"stage_index": -2}, true])
	for id in Story.ENDING_SCENES:
		var d: Dictionary = Story.ENDING_SCENES[id].duplicate()
		d.goal = 0
		jobs.append(["res://scenes/endings/ending_%s.tscn" % id, d, {"ending_id": id}, false])
	StageBuilder.baking = true
	for j in jobs:
		if not only.is_empty() and not j[0].get_file().get_basename() in only:
			continue
		if ResourceLoader.exists(j[0]) and not force:
			print("skip (already exists): ", j[0])
			continue
		var root := StageBuilder.build(j[1], j[2], j[3])
		root.name = j[0].get_file().get_basename().capitalize().replace(" ", "")
		add_child(root)   # navmesh baking reads the geometry from the tree
		var nav: NavigationRegion3D = root.get_node("NavRegion")
		nav.bake_navigation_mesh(false)
		remove_child(root)
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, j[0])
		print("baked ", j[0], " polys=", nav.navigation_mesh.get_polygon_count(), " err=", err)
		root.free()
	StageBuilder.baking = false
	get_tree().quit()
