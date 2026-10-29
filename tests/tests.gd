# Game tests. Runs as a scene so the Game autoload exists:
#   Godot_v4.7-stable_win64.exe --path . res://tests/tests.tscn
# Saves a screenshot of every stage to user://stage_N.png. Exit code 0 = all pass.
extends Node

func stage_scene(i: int) -> Node3D:   # the real, editor-editable stage
	return load("res://scenes/stages/%s.tscn" % Game.STAGES[i].scene).instantiate()

func idx(scene: String) -> int:   # stage index of a scene file (the order in story.gd can change)
	for i in Game.STAGES.size():
		if Game.STAGES[i].scene == scene:
			return i
	return -1
var fails := 0

func _ready() -> void:
	Game.save_path = "user://test_save.cfg"   # never touch the player's real save/settings
	Game.settings_path = "user://test_settings.cfg"
	Game.profile_path = "user://test_profile.cfg"
	Game.skip_cutscenes = true
	var only := OS.get_cmdline_user_args()   # quick run of one test: ... tests.tscn -- t_notes
	if only.size() > 0 and has_method(only[0]):
		await call(only[0])
		print("TESTS ", "OK" if fails == 0 else "FAILED %d" % fails)
		get_tree().quit(1 if fails else 0)
		return
	await t_lint()
	await t_rules()
	await t_cutscene()
	await t_builder()
	await t_hide()
	await t_noise()
	await t_phone()
	await t_audio()
	await t_cameo()
	await t_endings()
	await t_save()
	await t_perf()
	await t_no_dupes()
	await t_hide_teardown()
	await t_jumpscare()
	await t_debug()
	await t_keys_uncaptured()
	await t_models()
	await t_notes()
	await t_power()
	await t_rage()
	await t_finale()
	await t_fuse()
	await t_scares()
	await t_guard_dark()
	await t_guard_room()
	await t_tutorial()
	await t_tutorial_phone()
	await t_room_lock()
	await t_vhs()
	await t_real_notes()
	await t_real_chase()
	await t_floor_still()
	await t_still_screen()
	await t_stages()
	await t_reach()
	await t_vision()
	await t_catch()
	await t_guard()
	await t_wet()
	await t_wet_start()
	await t_goblin_den()
	await t_goblin_hide()
	await t_locker()
	await t_exit()
	await t_flow()
	await t_review_flow()
	await t_lineup()
	await t_loop()
	await t_hr()
	await t_heart()
	await t_new_scares()
	await t_mid_scenes()
	await t_quests()
	await t_chase_gives_up()
	await t_director()
	await t_objective_fold()
	await t_hd_look()
	await t_sound_bed()
	await t_creep_gaits()
	await t_ghost_cues()
	await t_occlusion()
	await t_music_states()
	await t_anomalies()
	await t_hallucinations()
	await t_render_budget()
	await t_catch_costs()
	print("TESTS ", "OK" if fails == 0 else "FAILED %d" % fails)
	get_tree().quit(1 if fails else 0)

# The editor treats some warnings as errors (e.g. a type inferred from a Variant) and then
# refuses to run the game, while a plain run still works. Parse every script the editor's way.
func t_lint() -> void:
	var files := []
	var dirs := ["res://scripts", "res://tools", "res://tests"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				files.append(d.path_join(f))
	var bad := []
	for f in files:
		var out := []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--check-only", "--script", f], out, true)
		if "Parse Error" in "".join(out):
			bad.append(f)
	check(files.size() > 20 and bad.is_empty(), "every script parses like in the editor (%d files) %s" % [files.size(), bad])

func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func pframes(n: int) -> void:   # process frames (cutscenes run on process, not physics)
	for i in n:
		await get_tree().process_frame

func make(map: Array, goal := 1, extra := {}) -> Node3D:
	var d := {"map": map, "goal": goal, "floor": Color.GRAY, "wall": Color.GRAY, "light": Color.WHITE}
	d.merge(extra)
	var lvl := StageBuilder.build(d)
	add_child(lvl)
	await frames(3)
	return lvl

func done(lvl: Node3D) -> void:
	lvl.queue_free()
	await frames(2)
	Game.new_game()

func t_rules() -> void:
	check(Game.resolve_ending(Game.CLUE_TOTAL, 0, false) == "B", "ending B: every dream clue + no phone")
	check(Game.resolve_ending(3, 5, false) == "C", "3 clues, no phone -> C")
	check(Game.resolve_ending(Game.CLUE_TOTAL, Game.EVIDENCE_NEEDED, true) == "D", "every clue + his phone + enough evidence -> D (true end)")
	check(Game.resolve_ending(Game.CLUE_TOTAL - 1, Game.EVIDENCE_NEEDED, true) == "A", "phone + evidence without every clue -> A")
	check(Game.resolve_ending(Game.CLUE_TOTAL, Game.EVIDENCE_NEEDED - 1, true) == "C", "every clue but took the phone without enough evidence -> C")
	check(Game.resolve_ending(0, Game.EVIDENCE_NEEDED - 1, true) == "C", "phone but not enough evidence -> C")
	Game.new_game()
	Game.heal(50)
	check(Game.battery == 100.0, "battery clamps at max")
	var over := []
	Game.game_over.connect(func(c): over.append(c), CONNECT_ONE_SHOT)
	Game.damage(30)
	check(Game.battery == 70.0, "damage reduces battery")
	Game.damage(500, "x")
	check(Game.battery == 0.0 and over == ["x"], "battery 0 emits game_over")
	Game.new_game()
	check(Game.use("pc") == false, "PC refuses before 3 notes")
	Game.text("แม่", "ก่อนบทนี้")
	Game.begin_stage()
	Game.text("แม่", "ในบทนี้")
	Game.restart_stage()
	check(Game.threads["แม่"].size() == 1, "retrying a chapter drops its texts from the last try (they come again)")
	Game.new_game()

func t_stages() -> void:
	for i in Game.STAGES.size():
		Game.new_game()
		Game.stage = i
		var data: Dictionary = Game.STAGES[i]
		var w: int = data.map[0].length()
		check(data.map.all(func(r): return r.length() == w), "stage %d map rows equal width" % (i + 1))
		var lvl := stage_scene(i)
		add_child(lvl)
		var looping: bool = data.has("loop")   # fire stairs: nobody hunts you there, the corridor itself does
		check(lvl.npcs.size() == (0 if looping else 1) and (looping or lvl.npcs[0].route.size() >= 1), "stage %d has its coworker + route" % (i + 1))
		var goals := lvl.find_children("*", "Area3D", true, false).filter(func(a): return a.get("kind") in ["doc", "note", "pc", "coffee_goal", "scanner", "fuse", "fuse_box", "file"])
		check(goals.size() == (0 if looping else data.goal), "stage %d goal items = %d" % [i + 1, data.goal])
		check(lvl.exit_open == (data.goal == 0), "stage %d exit locked until goal" % (i + 1))
		var n: Npc = null if looping else lvl.npcs[0]
		var p0 := n.global_position if n else Vector3.ZERO
		for f in 90:
			await get_tree().physics_frame
		check(Game.player.global_position.y > -1.0, "stage %d player stands on floor" % (i + 1))
		if n and not n is Guard:   # the guard waits at his monitors for the dark
			check(n.global_position.distance_to(p0) > 0.3, "stage %d coworker moves" % (i + 1))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://stage_%d.png" % (i + 1))
		await done(lvl)

func t_vision() -> void:
	var lvl := await make(["#########", "#M..=..P#", "#########"])
	var n: Npc = lvl.npcs[0]
	n.set_physics_process(false)
	n.view = 20.0
	lvl.player.crouching = false
	await frames(30)
	check(n.sees_player(), "standing player seen over partition")
	lvl.player.crouching = true
	await frames(30)
	check(not n.sees_player(), "crouched player hidden behind partition")
	n.rotation.y += PI
	lvl.player.crouching = false
	await frames(5)
	check(not n.sees_player(), "player behind NPC is outside vision cone")
	await done(lvl)

func t_catch() -> void:
	var lvl := await make(["#######", "#M...P#", "#######"])
	var n: Npc = lvl.npcs[0]
	n.cooldown = 0.0
	lvl.player.global_position = n.global_position + Vector3(0.6, 0, 0)
	await frames(3)
	check(Game.times_caught == 1 and Game.battery == 100.0 - n.drain, "touching coworker = caught, battery drained")
	await done(lvl)

func t_guard() -> void:
	var lvl := await make(["#########", "#P.....R#", "#########"], 0)
	var g = lvl.npcs[0]
	g.wake = 0.0
	lvl.player.rotation.y = -PI / 2   # look at him (+x)
	await frames(2)
	var p0: Vector3 = g.global_position
	await frames(30)
	check(g.global_position.distance_to(p0) < 0.05, "guard frozen while watched")
	lvl.player.rotation.y = PI / 2    # look away
	await frames(30)
	check(g.global_position.distance_to(p0) > 0.5, "guard advances when not watched")
	await done(lvl)

func t_wet() -> void:
	var lvl := await make(["#######", "#S...P#", "#######"])
	var s: Npc = lvl.npcs[0]
	check(s.state == "patrol", "sweeper starts calm")
	lvl.add_wet(lvl.player.global_position, s)
	await frames(5)
	check(s.state == "chase", "stepping on wet floor makes sweeper chase")
	s.chase_t = 0.01
	await frames(3)
	check(s.state == "patrol", "sweeper gives up the chase after a while")
	await done(lvl)

# Stage 2 is wet from the first second: puddles all over the floor, never where Tong can't get round them.
func t_wet_start() -> void:
	var lvl := await make(["###############", "#P............#", "#.............#", "#.............#", "#.......S.....#", "#.............#", "#############X#"], 0, {"wet_start": 8})
	var s: Npc = lvl.npcs[0]
	s.set_physics_process(false)   # no mopped trail in the count
	await frames(4)
	var wet := get_tree().get_nodes_in_group("wet")
	check(wet.size() == 8, "wet_start scatters that many puddles (%d)" % wet.size())
	check(wet.all(func(w): return w.global_position.distance_to(lvl.spawn) > 5.0), "...none on Tong's first steps")
	check(wet.all(func(w): return w.find_children("*", "Timer", false, false).is_empty()), "...and they don't dry up")
	lvl.player.global_position = wet[0].global_position
	await frames(5)
	check(s.state == "chase", "stepping in one angers ป้าพร")
	await done(lvl)
	Game.new_game()
	Game.stage = 1
	lvl = stage_scene(1)
	add_child(lvl)
	await frames(6)
	wet = get_tree().get_nodes_in_group("wet")
	var items: Array = lvl.get_node("Items").get_children().filter(func(it): return it.get("kind") != "hide")
	check(wet.size() >= 25, "real stage 2 starts with puddles all over (%d)" % wet.size())
	check(wet.all(func(w): return items.all(func(it): return w.global_position.distance_to(it.global_position) > 1.5)), "...none right on something Tong has to walk up to")
	wet.sort_custom(func(a, b): return a.global_position.distance_to(lvl.spawn) < b.global_position.distance_to(lvl.spawn))
	var to: Vector3 = wet[0].global_position - lvl.player.global_position   # look at the nearest one from where he starts
	lvl.player.rotation.y = atan2(-to.x, -to.z)
	lvl.player.cam.rotation.x = -0.25
	await frames(3)
	await shot("stage2_wet.png")
	await done(lvl)

# เต้ crawls to a desk, squats under it; creeping past crouched is safe, walking up gets your legs grabbed.
func t_goblin_den() -> void:
	var lvl := await make(["###########", "#.....D...#", "#.........#", "#G.......P#", "###########"])
	var g: Goblin = lvl.npcs[0]
	g.cooldown = 0.0
	g.view = 0.5   # only the desk ambush is under test, not spotting you across the room
	var t := 0.0
	while not g.under and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await get_tree().create_timer(0.6).timeout   # finish slipping under
	check(g.under and g.global_position.distance_to(Vector3(g.den.inside.x, g.global_position.y, g.den.inside.z)) < 0.2, "goblin crawls to a desk and hides under it")
	var pl = lvl.player
	var out: Vector3 = (g.den.front - g.den.inside).normalized()
	pl.crouching = true
	pl.global_position = g.global_position + out * 1.8
	await get_tree().create_timer(0.5).timeout
	check(g.under and g.state == "patrol", "creeping past crouched doesn't wake him")
	pl.crouching = false
	pl.global_position = g.global_position + out * 2.0
	await frames(3)
	check(g.state == "ambush", "walking up to his desk: he scrambles out")
	await get_tree().create_timer(2.0).timeout
	check(Game.times_caught == 1, "...and grabs your legs (caught)")
	await done(lvl)

# Hiding from เต้ works: he looks once, finds nothing while you hold your breath, and goes back to his desks.
func t_goblin_hide() -> void:
	for kind in ["locker", "desk"]:
		var lvl := await make(["###########", "#P.%s......#" % ("H" if kind == "locker" else "D"), "#.........#", "#......G..#", "#.......DD#", "###########"])
		var g: Goblin = lvl.npcs[0]
		var spot = kinds(lvl, "hide").filter(func(h): return h.hide_type == kind)[0]
		spot.interact()
		g.search(spot)   # he saw you get in
		Input.action_press("breath")
		await get_tree().create_timer(8.0).timeout
		check(g.state == "patrol" and Game.times_caught == 0, "%s: เต้ searches, finds nothing, gives up" % kind)
		await get_tree().create_timer(3.0).timeout
		Input.action_release("breath")
		check(g.state == "patrol" and g.global_position.distance_to(spot.front) > 3.0, "%s: ...and leaves instead of camping on it" % kind)
		await get_tree().create_timer(1.5).timeout
		check(lvl.player.hidden and Game.times_caught == 0, "%s: you got away with it" % kind)
		await done(lvl)

# Lockers dropped into a stage by hand (assets/models/locker.tscn) are hide spots with no setup.
func t_locker() -> void:
	Game.new_game()
	Game.stage = idx("stage_3")
	var lvl := stage_scene(Game.stage)
	add_child(lvl)
	await frames(10)
	for n in lvl.npcs:
		n.set_physics_process(false)
	lvl.restore_power()   # stage 3 starts blacked out: light it for the screenshots
	var map := lvl.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(map)
	var spots := get_tree().get_nodes_in_group("hide_spot")
	check(spots.size() >= 3, "stage 3: hand-placed lockers are hide spots (%d)" % spots.size())
	var pl = lvl.player
	for s in spots:
		var who: String = s.get_parent().name
		var q := NavigationServer3D.map_get_closest_point(map, s.front)
		check(Vector2(q.x - s.front.x, q.z - s.front.z).length() < 0.6, "%s opens onto walkable floor" % who)
		pl.global_position = s.front
		pl.rotation.y = atan2(s.look.x, s.look.z)   # standing in front of it, facing it
		await frames(3)
		await shot("locker%s.png" % who)
		s.interact()
		await frames(2)
		check(pl.hidden and pl.spot == s, "%s: E hides you inside" % who)
		pl.unhide()
		await frames(2)
	await done(lvl)

func t_exit() -> void:
	var lvl := await make(["#####", "#P.dX", "#####"], 1)
	check(not lvl.exit_open and is_instance_valid(lvl.door), "exit starts locked")
	var doc = lvl.find_children("*", "Area3D", true, false).filter(func(a): return a.get("kind") == "doc")[0]
	doc.interact()
	await frames(2)
	check(lvl.exit_open and not is_instance_valid(lvl.door), "collecting goal unlocks exit")
	var cleared := []
	Game.stage_cleared.connect(func(): cleared.append(1), CONNECT_ONE_SHOT)
	lvl.player.global_position = lvl.cell_pos(Vector2i(4, 1))
	await frames(5)
	check(cleared.size() == 1, "walking into open exit clears stage")
	await done(lvl)

func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://" + file)

func t_flow() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	check(main.screens.menu.visible, "menu shown on boot")
	await shot("menu.png")
	main.start_game()
	await get_tree().create_timer(1.0).timeout
	check(main.view.size == (Vector2i(320, 240) if Game.retro else Vector2i(main.size)), "3D renders at 320x240 (retro) / full size (HD)")
	check(Game.tutorial and main.level != null and main.level.has_node("Tutorial") and main.hud.visible, "new game starts with the tutorial (stage 0)")
	await shot("tutorial.png")
	Game.stage_clear()
	await get_tree().create_timer(1.5).timeout
	check(not Game.tutorial and Game.stage == 0 and main.level.npcs.size() == 1, "finishing the tutorial starts stage 1")
	Game.say("หัวหน้าธนา: งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ~?")
	await shot("hud.png")
	for i in Game.STAGES.size() - 1:
		Game.stage_clear()
		await get_tree().create_timer(1.5).timeout
		check(Game.stage == i + 1 and main.level.npcs.size() == (0 if Game.stage_data().has("loop") else 1), "advanced to stage %d" % (i + 2))
	await shot("stage4_main.png")
	Game.phone_taken = true
	Game.hints = Game.EVIDENCE_NEEDED
	Game.stage_clear()
	await get_tree().create_timer(1.5).timeout
	check(main.screens.ending.visible and main.end_labels.letter.text.begins_with("A"), "exit with phone + hints shows ending A")
	await shot("ending.png")
	main.start_game()
	await get_tree().create_timer(1.0).timeout
	Game.damage(500, "test cause")
	await get_tree().create_timer(2.0).timeout
	check(main.screens.over.visible and main.over_cause.text == "test cause", "battery 0 shows game over")
	await shot("gameover.png")
	main.queue_free()
	await frames(2)

# With cutscenes on (the default), clearing a chapter shows the performance review and then
# goes on to the next chapter. A restart must not get the old chapter's timed texts.
func t_review_flow() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	Game.skip_cutscenes = false
	Game.new_game()
	Game.stage = 0
	main._story_seen.append_array([0, 1])   # no story text on black: straight to the clock card
	main.start_stage()
	var t := 0.0
	while (main.level == null or Game.in_cutscene) and t < 15.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	check(main.level != null, "chapter 1 loads with cutscenes on")
	Game.stage_clear()
	t = 0.0
	while not main.screens.review.visible and t < 5.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	check(main.screens.review.visible, "clearing it shows the performance review")
	await get_tree().create_timer(1.0).timeout
	main._review_done = true
	t = 0.0
	while (Game.stage != 1 or main.level == null or not main.playing) and t < 15.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	check(Game.stage == 1 and main.level != null and main.playing, "after the review chapter 2 starts")
	Game.skip_cutscenes = true
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Jobs ("งาน"): offered by text, a thing per step, story on each, a payoff; a required job holds
# the exit; a retry puts them back the way the chapter began.
func t_quests() -> void:
	var ids := {}
	var ok := true
	for e in Game.all_quests():
		var q: Dictionary = e.q
		ok = ok and not ids.has(q.id) and q.has("from") and q.has("ask") and q.has("title") and not q.steps.is_empty()
		ids[q.id] = true
		for st in q.steps:
			ok = ok and st.has("do") and st.at is Vector2i and st.has("item")
			if st.has("scare"):
				ok = ok and (st.scare.kind in ["lights_out", "sound"] or Story.BODIES.has(st.scare.get("preset", "")))
	for e in Game.all_quests():
		ok = ok and (e.q.get("needs", "") == "" or ids.has(e.q.needs))
	check(ok and ids.size() >= 3, "jobs: every job is complete (%d jobs)" % ids.size())
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(5)
	Game.begin_stage()
	var mine := func(id: String) -> Array: return kinds(lvl, "quest").filter(func(it): return not it.used and it.get_meta("quest") == id)
	Game.battery = 50.0
	Game.offer_quest("mum_lunch")
	var it: Array = mine.call("mum_lunch")
	check(Game.threads.has("แม่") and it.size() == 1 and Vector2(it[0].global_position.x, it[0].global_position.z).distance_to(Vector2(lvl.cell_pos(Vector2i(9, 19)).x, lvl.cell_pos(Vector2i(9, 19)).z)) < 0.5, "jobs: a text offers it, the first step's thing appears")
	it[0].interact()
	await frames(2)
	check(Game.quests.mum_lunch == 1 and mine.call("mum_lunch").size() == 1 and Game.docs_found.has("หยิบข้าวกล่องของแม่"), "jobs: a step done (its note read), the next thing appears")
	mine.call("mum_lunch")[0].interact()
	await frames(2)
	check(Game.quest_done("mum_lunch") and Game.battery == 75.0 and mine.call("mum_lunch").is_empty(), "jobs: finished, the payoff lands (Social Battery +25)")
	Game.goal_count = lvl.goal - 1
	Game.collect()
	check(not lvl.exit_open and Game.quests.has("boss_bind") and Game.objective_text().begins_with("งานด่วน"), "jobs: goals done, a required job holds the exit and is the objective")
	for k in 2:
		mine.call("boss_bind")[0].interact()
		await frames(2)
	check(lvl.exit_open and Game.quest_done("boss_bind"), "jobs: the required job done, the exit opens")
	Game.restart_stage()
	check(Game.quests.is_empty(), "jobs: a retry puts the jobs back the way the chapter began")
	Game.quests = {"fon_1": 1}
	Game.save_progress()
	Game.new_game()
	Game.load_progress()
	check(Game.quests.get("fon_1") == 1, "jobs: saved with the checkpoint")
	await done(lvl)
	Game.clear_save()

# A chase ends when Tong is out of sight for a few seconds (no more hunting him down forever),
# and there is no "!" over their heads unless the game is on Easy.
func t_chase_gives_up() -> void:
	var lvl := await make(["###########", "#N.......P#", "#.#########", "#.........#", "###########"])
	var n: Npc = lvl.npcs[0]
	var pl = lvl.player
	n.spot()
	await frames(5)
	check(n.state == "chase" and n.mark.text == "", "spotted: it chases, with no mark over its head (normal)")
	pl.global_position = lvl.cell_pos(Vector2i(9, 3)) + Vector3.UP * 0.1   # round the wall, out of sight
	var t := 0.0
	while n.state == "chase" and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(n.state != "chase" and t > n.lose_secs() - 0.5, "out of sight for %.1f s: it gives up and searches where it saw him" % t)
	await done(lvl)

# The fear director: a coworker withdraws after a chase, comes looking somewhere near and out of
# view when it has been quiet, and the psychological events and reactive texts all work.
func t_director() -> void:
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(10)
	NavigationServer3D.map_force_update(lvl.get_world_3d().navigation_map)
	var d: Node = lvl.find_children("*", "Director", false, false).front() if not lvl.find_children("*", "Director", false, false).is_empty() else null
	check(d != null, "director: every chapter has one")
	var n: Npc = lvl.npcs[0]
	var pl = lvl.player
	d._relieve(n)
	check(n.state == "away" and n.away_pos.distance_to(pl.global_position) > 12.0, "director: after a chase it withdraws to the far side (%.0f m)" % n.away_pos.distance_to(pl.global_position))
	n.reset()
	await frames(2)
	var ok: bool = d.stalk()
	var dist: float = n.inv_pos.distance_to(pl.global_position)
	check(ok and n.state == "investigate" and dist >= 8.0 and dist <= 16.0, "director: quiet too long -> it comes looking near him (%.0f m), out of view" % dist)
	n.reset()
	Game.threads.clear()
	pl.hide_in(kinds(lvl, "hide")[0])
	d._hide = 7.5
	d.react_t = 0.0
	d._watch_player(0.1, pl)
	check(Game.threads.has("เบอร์ไม่รู้จัก") and Director.REACT.hide.has(Game.threads["เบอร์ไม่รู้จัก"][-1].text), "director: hiding a while -> the stranger texts about it")
	pl.unhide()
	for k in ["steps", "whisper", "lights", "hum", "printer", "peripheral", "monitor", "silence", "clock", "self_text", "mum_call"]:
		d.fire(k)
		await frames(3)
	check(Game.clock == "02:14" and d._silent and Game.threads.has("ต๋อง"), "director: every psychological event runs (clock 02:14, silence, a text from himself)")
	await get_tree().create_timer(6.5).timeout
	check(Game.clock != "02:14" and not d._silent and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Amb")) and lvl.lights.slice(1).all(func(l): return l.visible == not lvl.dark),   # (lights[0] is the stage's own dying tube)
		"director: and they all wear off (clock, sound, lights back)")
	await done(lvl)

# The objective note folds to a tab; it opens for a moment when the objective changes; O pins it.
func t_objective_fold() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	Game.new_game()
	Game.stage = 0
	Game.objective_pin = false
	main.start_stage()
	await get_tree().create_timer(1.0).timeout
	check(main.objective.visible, "objective note: open for a moment at the start")
	main._obj_peek = 0.0
	await pframes(3)   # process frames: the HUD updates there (a slow renderer runs several physics frames per one)
	check(not main.objective.visible and main.objective_head.text.contains("O"), "objective note: then it folds to a tab")
	var ev := InputEventAction.new()
	ev.action = "objective"
	ev.pressed = true
	main._unhandled_input(ev)
	await pframes(3)
	check(main.objective.visible and Game.objective_pin, "objective note: O pins it open")
	main._unhandled_input(ev)
	check(not Game.objective_pin, "objective note: O again lets it fold")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# HD remaster: the stage's surfaces get their HD textures, the furniture a surface, the torch its
# hot core; the retro setting brings back the PSX look (320x240, wobble on).
func t_hd_look() -> void:
	Game.retro = false
	HD.apply_look()
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(5)
	var surfaces := {}
	for g in lvl.find_children("*", "GeometryInstance3D", true, false):
		var m = g.material_override
		if m is ShaderMaterial and m.get_shader_parameter("has_hd"):
			surfaces[m.get_shader_parameter("hd_albedo").resource_path.get_file()] = true
	check(surfaces.has("carpet.png") and surfaces.has("wall.png") and surfaces.has("ceiling.png"), "HD: floor, walls and ceiling get HD textures %s" % [str(surfaces.keys())])
	var props := lvl.find_children("*", "MeshInstance3D", true, false).filter(func(mi): return mi.material_override == null and mi.mesh and mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) is StandardMaterial3D and mi.get_surface_override_material(0).albedo_texture != null)
	check(props.size() > 20, "HD: the furniture gets surfaces (%d meshes)" % props.size())
	check(lvl.player.flashlight.get_node_or_null("Core") != null and HD.look == 0.0, "HD: the torch has its hot core, the shaders are in HD mode")
	# realistic furniture in place of the Kenney models, fitted to the same box
	var desks := lvl.find_children("Desk*", "StaticBody3D", true, false)
	var swapped := desks.filter(func(d): return d.find_child("Real", true, false) != null)
	check(desks.size() > 0 and swapped.size() == desks.size(), "HD: every desk is the realistic model (%d/%d)" % [swapped.size(), desks.size()])
	if desks.size() > 0:
		var real: Node3D = desks[0].find_child("Real", true, false)
		var kenney: Node3D = real.get_parent()
		var ab := HD._bounds(real)
		ab = real.transform * ab
		check(absf(ab.position.y) < 0.01 and absf(ab.end.y * kenney.scale.y - 0.77) < 0.03, "HD: the real desk stands on the floor with its top at desk height (%.2f m)" % (ab.end.y * kenney.scale.y))
		check(kenney.get_children().all(func(c): return c == real or not c is VisualInstance3D), "HD: the Kenney meshes are gone")
	# fixtures: troffers in place of the flat panels, things on the walls and ceiling, an exit sign
	var troffers: int = lvl.find_children("*", "Node3D", true, false).filter(func(n): return n.get_meta("fixture", "") == "troffer").size()
	var panels_hidden: bool = lvl.lights.all(func(l): return l.get_node_or_null("Panel") == null or not l.get_node("Panel").visible)
	check(panels_hidden and troffers >= lvl.lights.size(), "HD: every ceiling light is a recessed fitting (%d for %d lights)" % [troffers, lvl.lights.size()])
	var decor := {}
	for n in lvl.get_children():
		if n.has_meta("fixture"):
			decor[n.get_meta("fixture")] = true
	check(decor.has("outlet") and decor.has("vent") and decor.has("exit_sign"), "HD: sockets, vents and an exit sign dressed on %s" % [str(decor.keys())])
	await done(lvl)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	Game.retro = true
	main.apply_settings()
	await pframes(3)
	check(main.view.size == Vector2i(320, 240) and HD.look == 1.0, "retro setting: back to 320x240 and the PSX shaders")
	Game.retro = false
	main.apply_settings()
	main.queue_free()
	await frames(2)

# The realistic ghosts move wrong: each has its own gait with bending knees and elbows, the
# manager's head follows you, and a ghost watched from behind stops dead and turns its head round.
func t_creep_gaits() -> void:
	Game.retro = false
	var modes := {}
	for scene in ["manager", "sweeper", "goblin", "hr", "doctor"]:
		var n: Npc = load("res://scenes/mobs/%s.tscn" % scene).instantiate()
		modes[n.anim_mode] = true
		n.free()
	check(modes.size() == 5, "every ghost has its own gait %s" % [str(modes.keys())])
	var g: Npc = load("res://scenes/mobs/guard.tscn").instantiate()
	check(not g.smooth and not g.can_freeze, "the guard stays stop-motion (he only moves unwatched anyway)")
	g.free()
	var b := Body.new()
	add_child(b)
	b.build(Story.BODIES.tong)
	var knee := Vector2(INF, -INF)
	var straight := 0
	for k in 24:
		b.pose(k * TAU / 9.0 / 24.0, "walk")
		knee.x = minf(knee.x, b.parts.ShinL.rotation.x)
		knee.y = maxf(knee.y, b.parts.ShinL.rotation.x)
		if absf(b.parts.LegL.rotation.x) < 0.01 and absf(b.parts.ShinL.rotation.x) < 0.01 and absf(b.parts.ForearmL.rotation.x) < 0.01:
			straight += 1
	check(knee.y - knee.x > 0.5 and knee.y <= 0.0 and straight == 0, "walking, the knee folds and straightens (%.2f..%.2f rad), never a stiff stick" % [knee.x, knee.y])
	b.queue_free()
	# watched from behind: it stops, its head comes round, then it walks on
	var lvl := await make(["#############", "#...........#", "#.M.......P.#", "#...........#", "#############"])
	var n: Npc = lvl.npcs[0]
	var pl = lvl.player
	n._freeze_cd = 0.0
	n.global_position = lvl.cell_pos(Vector2i(6, 2))
	n.rotation.y = PI / 2   # facing -x: its back to the player at x = 10
	pl.rotation.y = PI / 2  # the player looks -x, at its back
	n.state = "patrol"
	await frames(3)
	var p0 := n.global_position
	await get_tree().create_timer(1.6).timeout
	check(n._freeze_t > 0.0 and n.global_position.distance_to(p0) < 0.05, "watched from behind: it stops dead")
	check(absf(n.body.parts.Head.rotation.y) > 1.2, "...and its head turns round to you (%.0f degrees)" % rad_to_deg(n.body.parts.Head.rotation.y))
	await get_tree().create_timer(2.0).timeout
	check(n._freeze_t <= 0.0 and n._freeze_cd > 5.0, "then it goes on (and won't do it again straight away)")
	await done(lvl)

# Heard before seen: every ghost has its own sound, one per step while it moves, none while it stands.
func t_ghost_cues() -> void:
	for scene in ["manager", "sweeper", "goblin", "guard", "hr", "doctor"]:
		var n: Npc = load("res://scenes/mobs/%s.tscn" % scene).instantiate()
		var f: String = ("%s_0" % n.cue) if n.cue_vars > 0 else n.cue
		check(n.cue != "" and Game.stream(f) != null, "%s has its own sound (%s)" % [scene, n.cue])
		n.free()
	var lvl := await make(["#############", "#.M.........#", "#...........#", "#...........#", "#...........#", "#..........P#", "#############"])
	var n: Npc = lvl.npcs[0]
	n.can_freeze = false
	n.spot()   # coming for him across the room
	var heard := {}
	var t := 0.0
	while t < 4.0:
		for c in n.get_children():
			if c is AudioStreamPlayer3D and c.stream and c.stream.resource_path.contains(n.cue):
				heard[c.get_instance_id()] = c.unit_size
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(heard.size() >= 2 and heard.values().all(func(u): return u >= 6.0), "a walking manager clicks his pen as he goes (%d clicks), heard a room away" % heard.size())
	n.set_physics_process(false)
	n.velocity = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	var still := n.get_children().filter(func(c): return c is AudioStreamPlayer3D and c.playing and c.stream and c.stream.resource_path.contains(n.cue))
	check(still.is_empty(), "standing still, he makes no sound")
	await done(lvl)

# A sound behind a wall comes through muffled and quieter; in the open it is clear.
func t_occlusion() -> void:
	var lvl := await make(["#########", "#P..#...#", "#...#...#", "#...#...#", "#########"])
	var behind := Node3D.new()
	lvl.add_child(behind)
	behind.global_position = lvl.cell_pos(Vector2i(6, 2)) + Vector3.UP * 1.2
	var open := Node3D.new()
	lvl.add_child(open)
	open.global_position = lvl.cell_pos(Vector2i(2, 3)) + Vector3.UP * 1.2
	var a: AudioStreamPlayer3D = Game.sfx("printer", behind)
	var b: AudioStreamPlayer3D = Game.sfx("printer", open)
	await get_tree().create_timer(0.4).timeout
	check(a.attenuation_filter_cutoff_hz <= 1500.0 and a.volume_db < b.volume_db, "behind the wall: muffled (%d Hz) and quieter" % a.attenuation_filter_cutoff_hz)
	check(b.attenuation_filter_cutoff_hz >= 5000.0, "in the open: clear (%d Hz)" % b.attenuation_filter_cutoff_hz)
	await done(lvl)

# The music follows what is happening: calm, unease when it is near but unseen, the chase, the
# breather after; a sting the first time you see it in a chapter, once.
func t_music_states() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = false
	main.show_screen("")
	Game.skip_cutscene.emit()
	await get_tree().create_timer(0.6).timeout
	var lvl: Node3D = main.level
	var n: Npc = lvl.npcs[0]
	var pl = lvl.player
	n.set_physics_process(false)
	n.global_position = pl.global_position + Vector3(40, 0, 40)
	await get_tree().create_timer(0.5).timeout
	check(main.music_state == "calm", "far away: calm (%s)" % main.music_state)
	n.global_position = pl.global_position + pl.global_basis.z * 5.0   # right behind him, out of view
	await get_tree().create_timer(0.6).timeout
	check(main.music_state == "unease" and not main._sighted, "near but unseen: unease (%s)" % main.music_state)
	var stings := []
	var count := func(nd): if nd is AudioStreamPlayer and nd.stream and nd.stream.resource_path.contains("sighting"): stings.append(nd)
	get_tree().node_added.connect(count)
	n.global_position = pl.global_position - pl.global_basis.z * 6.0   # in front of him, in plain view
	await get_tree().create_timer(0.6).timeout
	check(main._sighted and stings.size() == 1, "first sight of it: one sting (%d)" % stings.size())
	n.spot()
	n.set_physics_process(true)
	await pframes(3)
	await get_tree().create_timer(0.3).timeout
	check(main.music_state == "chase", "hunted: the chase (%s)" % main.music_state)
	n.set_physics_process(false)
	n.state = "patrol"
	n.global_position = pl.global_position + Vector3(40, 0, 40)
	await get_tree().create_timer(0.5).timeout
	check(main.music_state == "after", "let go: the breather after (%s)" % main.music_state)
	n.global_position = pl.global_position - pl.global_basis.z * 6.0
	await get_tree().create_timer(0.6).timeout
	check(stings.size() == 1, "seen again: no second sting")
	get_tree().node_added.disconnect(count)
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# The office changes when he isn't looking: never in view, and nothing ends up in his way.
func t_anomalies() -> void:
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(10)
	var d: Director = lvl.find_children("*", "Director", false, false).front()
	var pl = lvl.player
	var chairs: Array = d._props_of("chairDesk", 4.0, 14.0)
	check(not chairs.is_empty() and chairs.all(func(c): return d._unseen(c.global_position + Vector3.UP * 0.6)), "chairs to move: only ones out of his sight (%d)" % chairs.size())
	var before := {}
	for c in lvl.find_children("*", "Node3D", true, false).filter(func(n): return n.scene_file_path.ends_with("/chairDesk.glb")):
		before[c.get_parent()] = c.get_parent().global_position
	check(d._anomaly("chair"), "a chair rolls out")
	var moved: Array = []
	var w := 0.0
	while w < 3.0 and moved.is_empty():
		await get_tree().create_timer(0.25).timeout
		w += 0.25
		moved = before.keys().filter(func(h): return h.global_position.distance_to(before[h]) > 0.5)
	check(moved.size() == 1 and not moved[0] is CollisionObject3D and moved[0].find_children("*", "CollisionShape3D", true, false).is_empty(), "one chair moved (%d), and it can't block the way" % moved.size())
	var s_ok: bool = d._anomaly("screen")
	check(s_ok, "a screen turns to face him")
	var fwd: Vector3 = -pl.global_basis.z
	var behind: Array = lvl.lights.filter(func(l):
		var to: Vector3 = l.global_position - pl.global_position
		return Vector2(to.x, to.z).length() > 3.0 and Vector2(to.x, to.z).length() < 16.0 and Vector2(to.x, to.z).dot(Vector2(fwd.x, fwd.z)) < 0.0)
	if not behind.is_empty():
		d._anomaly("lights_behind")
		await get_tree().create_timer(0.4 * behind.size() + 0.3).timeout
		check(behind.all(func(l): return not l.visible), "the lights he walked under go out behind him (%d)" % behind.size())
	check(d._anomaly("papers"), "papers on the floor round the corner")
	check(d._anomaly("phone"), "a phone rings out of sight")
	await done(lvl)

# Low Social Battery: its steps come up behind him and there's nobody; a text garbles on the open
# phone. Never more than one every 40 s, and nothing at a healthy battery.
func t_hallucinations() -> void:
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(10)
	var d: Director = lvl.find_children("*", "Director", false, false).front()
	Game.battery = 90.0
	d.hallu_t = 0.0
	d._hallucinate(0.1)
	check(d.hallu_t >= 20.0, "healthy: nothing that isn't there")
	Game.battery = 30.0
	d.hallu_t = 0.0
	var heard := []
	var count := func(nd): if nd is AudioStreamPlayer3D and nd.stream and nd.stream.resource_path.contains(lvl.npcs[0].cue): (func(): if is_instance_valid(nd): heard.append(nd.global_position)).call_deferred()   # (placed just after it is added)
	get_tree().node_added.connect(count)
	d._hallucinate(0.1)
	check(d.hallu_t >= 40.0, "frayed: one now, the next not for 40 s or more (%.0f)" % d.hallu_t)
	await get_tree().create_timer(3.5).timeout
	get_tree().node_added.disconnect(count)
	var pl = lvl.player
	check(heard.size() >= 3 and heard.back().distance_to(pl.global_position) < heard.front().distance_to(pl.global_position), "its steps come up behind him (%d), getting closer" % heard.size())
	check(lvl.npcs[0].global_position.distance_to(pl.global_position) > 4.0, "...and nobody is there")
	await done(lvl)

# PC budget (HD): chapter 1 in play stays well under what a mid-range PC draws without effort, and
# hidden screens' portraits cost nothing.
func t_render_budget() -> void:
	Game.retro = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = false
	main.show_screen("")
	Game.skip_cutscene.emit()
	await get_tree().create_timer(1.5).timeout
	var worst := Vector2.ZERO
	for k in 4:
		main.level.player.rotation.y = k * PI / 2.0
		await get_tree().create_timer(0.5).timeout
		worst.x = maxf(worst.x, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		worst.y = maxf(worst.y, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	check(worst.x < 150000.0 and worst.y < 800.0, "chapter 1 in play: at most %d triangles, %d draw calls a frame" % [worst.x, worst.y])
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# The full jumpscare once a chapter; after that a quick dark one, and each catch costs something
# for the rest of the chapter (not on Easy).
func t_catch_costs() -> void:
	Game.difficulty = 1
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = false
	main.show_screen("")
	Game.skip_cutscene.emit()
	await get_tree().create_timer(0.6).timeout
	var n: Npc = main.level.npcs[0]
	var slams := [0]
	var watch := func(): if main.scare_face.visible: slams[0] += 1
	get_tree().process_frame.connect(watch)
	Game.catch(n)
	await get_tree().create_timer(3.5).timeout
	check(slams[0] > 0, "first catch of the chapter: the full jumpscare")
	slams[0] = 0
	var torch: float = Game.phone_battery
	Game.catch(n)
	await get_tree().create_timer(2.5).timeout
	check(slams[0] == 0 and not Game.busy, "second catch: a quick dark one, no face")
	check(Game.phone_battery <= torch - 29.0, "...and the torch took a knock (%.0f -> %.0f)" % [torch, Game.phone_battery])
	var sp: float = n.speed
	Game.battery = 100.0   # (not the catch that ends it)
	Game.catch(n)
	await get_tree().create_timer(2.5).timeout
	check(n.speed > sp * 1.05 and n.speed <= n.get_meta("base_speed").x * 1.2 + 0.001, "third: it is faster now (%.2f -> %.2f)" % [sp, n.speed])
	get_tree().process_frame.disconnect(watch)
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Sound: footsteps follow the floor, the reverb fits it, every tube hums and goes quiet when it dies.
func t_sound_bed() -> void:
	Game.new_game()
	var i := idx("stage_1")
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(3)
	check(Game.stream("footstep02").resource_path.ends_with("step_carpet_2.ogg"), "office footsteps are on carpet")
	var rev := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"), 0) as AudioEffectReverb
	check(rev and is_equal_approx(rev.room_size, Game.ROOMS.carpet[0]), "the office reverb is small and dead")
	var l: OmniLight3D = lvl.lights[0]
	var hum := l.get_node_or_null("Hum") as AudioStreamPlayer3D
	check(hum != null and hum.playing and not hum.stream_paused, "a ceiling light hums")
	lvl.set_dark(true)
	await frames(1)
	check(hum.stream_paused, "a dead light is silent")
	lvl.set_dark(false)
	await frames(1)
	check(not hum.stream_paused, "...and hums again when the power is back")
	await done(lvl)
	var j := idx("stage_hospital")
	Game.stage = j
	lvl = stage_scene(j)
	add_child(lvl)
	await frames(3)
	check(Game.stream("footstep00").resource_path.ends_with("step_tile_0.ogg") and is_equal_approx(rev.room_size, Game.ROOMS.tile[0]), "hospital: footsteps on vinyl, a ringing room")
	await done(lvl)
	for n in ["ambience", "drone", "chase_theme", "menu_theme", "light_hum", "lights_off", "lights_on", "pickup", "ui_click"]:
		check(Game.stream(n) is AudioStreamOggVorbis, "%s is the new synthesized sound" % n)
	# one volume table: every sound file has its line in Game.MIX (its own or its family's)
	var missing := []
	for f in DirAccess.get_files_at("res://assets/sfx"):
		if f.get_extension() in ["ogg", "wav"]:
			var n := f.get_basename()
			if not Game.MIX.has(n) and not Game.MIX.has(n.rstrip("0123456789").trim_suffix("_")):
				missing.append(n)
	check(missing.is_empty(), "every sound can be turned up or down in Game.MIX %s" % [str(missing)])
	var p := Game.sfx("pickup", null, -6.0)
	check(is_equal_approx(p.volume_db, -6.0 + Game.mix_db("pickup")), "Game.sfx applies the MIX trim")

# Character lineup screenshot (for review / report), not an assertion-heavy test.
func t_lineup() -> void:
	var lvl := await make(["###########", "#.........#", "#.M.S.G.R.#", "#..L...L..#", "#.........#", "#....P....#", "###########"])
	for n in lvl.npcs:
		n.set_physics_process(false)
		n.face(lvl.player.global_position - n.global_position)
		n.body.pose(0.0, "idle")
	lvl.player.rotation.y = 0.0
	lvl.player.set_physics_process(false)
	lvl.player.cam.position.y = 1.5
	await frames(5)
	check(lvl.npcs.size() == 4, "all four coworkers build")
	await shot("lineup.png")
	await done(lvl)

func kinds(lvl: Node3D, k: String) -> Array:
	return lvl.find_children("*", "Area3D", true, false).filter(func(a): return a.get("kind") == k)

func t_builder() -> void:
	var map: Array = Game.STAGES[0].map
	var hashes := 0
	for r in map:
		hashes += r.count("#")
	var lvl := await make(map, 3)
	check(lvl.wall_nodes * 10 <= hashes * 4, "walls merged into runs (%d nodes for %d cells)" % [lvl.wall_nodes, hashes])
	await done(lvl)
	lvl = await make(["##########", "#P.H.W.s.#", "#.e.Z.!.z#", "#r...g...#", "##########"], 1, {"signs": ["ห้องทดสอบ"], "notes": [{"title": "หัวข้อ", "text": "เนื้อหา"}]})
	var hides := kinds(lvl, "hide")
	check(hides.size() == 2 and hides.any(func(h): return h.hide_type == "locker") and hides.any(func(h): return h.hide_type == "stall"), "locker + stall hide spots")
	check(kinds(lvl, "throwable").size() == 1 and kinds(lvl, "clue").size() == 1 and kinds(lvl, "powerbank").size() == 1, "throwable, clue, power bank built")
	check(lvl.cameos.size() == 1, "guard cameo spot recorded")
	var opened := []
	Game.note_opened.connect(func(t, _b, _tip): opened.append(t), CONNECT_ONE_SHOT)
	kinds(lvl, "read")[0].interact()
	check(opened == ["หัวข้อ"], "reading a note opens it")
	kinds(lvl, "clue")[0].interact()
	check(Game.clues.size() == 1, "dream clue collected")
	var fired := []
	Game.story_event.connect(func(t): fired.append(t), CONNECT_ONE_SHOT)
	lvl.player.global_position = lvl.cell_pos(Vector2i(6, 2))
	await frames(5)
	check(Game.fired.size() == 1 and fired.size() == 1, "walking into ! fires its story trigger")
	var labels := lvl.find_children("*", "Label3D", true, false).filter(func(l): return l.text == "ห้องทดสอบ")
	check(labels.size() == 1, "room sign shows its text")
	await done(lvl)

func t_cutscene() -> void:
	Game.skip_cutscenes = false
	var lvl := await make(["#######", "#P.M..#", "#######"])
	var steps := [["cam", Vector3(1, 1.6, 1), Vector3(3, 1.6, 1), 0.0], ["say", "ทดสอบ", 0.2], ["text", "แม่", "กลับกี่โมงลูก"], ["wait", 0.2]]
	var cs := Cutscene.new()
	var run := func(): await cs.play(lvl, steps)
	run.call()
	await frames(2)
	check(Game.in_cutscene and not lvl.player.cam.current, "cutscene takes the camera")
	await get_tree().create_timer(0.8).timeout
	check(not Game.in_cutscene and lvl.player.cam.current, "cutscene ends and returns the camera")
	check(Game.threads.get("แม่", []).size() == 1, "cutscene can send a phone text")
	var cs2 := Cutscene.new()
	var run2 := func(): await cs2.play(lvl, [["wait", 30.0]])
	run2.call()
	await frames(2)
	cs2.skipping = true
	await pframes(3)
	check(not Game.in_cutscene, "skipping ends a cutscene immediately")
	# a tap of E / Space / Esc does nothing; Space held for Game.SKIP_HOLD seconds skips
	var cs3 := Cutscene.new()
	var run3 := func(): await cs3.play(lvl, [["wait", 30.0]])
	run3.call()
	await frames(2)
	for a in ["interact", "breath", "pause"]:
		Input.action_press(a)
	await frames(3)
	for a in ["interact", "breath", "pause"]:
		Input.action_release(a)
	await get_tree().create_timer(0.3).timeout
	check(Game.in_cutscene and Game.skip_hold == 0.0, "a tap of E / Space / Esc doesn't skip a cutscene")
	Input.action_press("breath")
	await get_tree().create_timer(Game.SKIP_HOLD * 0.6).timeout
	check(Game.in_cutscene and Game.skip_hold > Game.SKIP_HOLD * 0.4, "holding Space fills the skip bar")
	await get_tree().create_timer(Game.SKIP_HOLD * 0.5).timeout
	check(not Game.in_cutscene, "holding Space for %.0f s skips the cutscene" % Game.SKIP_HOLD)
	var cs4 := Cutscene.new()   # still holding from the last skip: this one isn't skipped
	var run4 := func(): await cs4.play(lvl, [["wait", 30.0]])
	run4.call()
	await get_tree().create_timer(Game.SKIP_HOLD + 0.3).timeout
	check(Game.in_cutscene, "Space still held from a skip doesn't skip the next cutscene too")
	Input.action_release("breath")
	cs4.skipping = true
	await pframes(3)
	# walk: ends exactly on the spot, level (bob settled); player: ends in Tong's own eyes
	var cs5 := Cutscene.new()
	var run5 := func(): await cs5.play(lvl, [["cam", Vector3(1, 1.6, 1), Vector3(5, 1.6, 1), 0.0],
		["walk", Vector3(2.5, 1.6, 1), Vector3(5, 1.6, 1), 0.5], ["wait", 0.6], ["player", 0.3], ["wait", 0.6]])
	run5.call()
	await get_tree().create_timer(0.8).timeout
	check(cs5.cam.global_position.distance_to(Cutscene.cell(Vector3(2.5, 1.6, 1))) < 0.01, "walk ends on its spot")
	var w := 0.0
	while w < 2.0 and not cs5.cam.global_transform.is_equal_approx(lvl.player.cam.global_transform):   # (slow frames: give it time)
		await get_tree().process_frame
		w += get_process_delta_time()
	check(cs5.cam.global_transform.is_equal_approx(lvl.player.cam.global_transform), "player step hands over in Tong's own eyes")
	cs5.skipping = true
	await pframes(3)
	Game.skip_cutscenes = true
	await done(lvl)

func hide_map() -> Node3D:
	return await make(["###########", "#P.H......#", "#.........#", "#.......M.#", "###########"])

func t_hide() -> void:
	var lvl := await hide_map()
	var pl = lvl.player
	var n: Npc = lvl.npcs[0]
	n.set_physics_process(false)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(pl.stamina < 90.0, "sprinting drains stamina")
	await done(lvl)

	# hidden unseen: coworker right in front can't see you; lingering there finds you
	lvl = await hide_map()
	pl = lvl.player
	n = lvl.npcs[0]
	n.set_physics_process(false)
	n.rotation.y = 0.0   # facing away (-z wall)
	var locker = kinds(lvl, "hide")[0]
	locker.interact()
	await frames(2)
	check(pl.hidden and n.state == "patrol", "hiding unseen: nobody searches")
	n.global_position = locker.front + Vector3(0.5, 0, 0.5)
	n.face(locker.front - n.global_position + Vector3(0, 0, 1))
	check(not n.sees_player(true), "hidden player can't be seen")
	Input.action_press("breath")
	await get_tree().create_timer(1.8).timeout
	check(Game.times_caught == 0, "holding breath: not found while stamina lasts")
	pl.stamina = 5.0
	await get_tree().create_timer(0.8).timeout
	Input.action_release("breath")
	check(Game.times_caught == 1, "running out of breath next to a coworker = found")
	await done(lvl)

	lvl = await hide_map()
	n = lvl.npcs[0]
	n.set_physics_process(false)
	n.rotation.y = PI
	kinds(lvl, "hide")[0].interact()
	await get_tree().create_timer(0.3).timeout
	n.global_position = kinds(lvl, "hide")[0].front + Vector3(0.6, 0, 0)
	await get_tree().create_timer(2.0).timeout
	check(Game.times_caught == 1, "breathing normally next to a coworker = found")
	await done(lvl)

	# seen getting in: coworker walks over and searches; standing there unmasked gives you away
	lvl = await hide_map()
	n = lvl.npcs[0]
	n.view = 20.0
	n.face(lvl.player.global_position - n.global_position)
	n.set_physics_process(false)
	kinds(lvl, "hide")[0].interact()
	check(n.state == "search", "coworker that saw you hide starts searching")
	n.set_physics_process(true)
	await get_tree().create_timer(6.0).timeout
	check(Game.times_caught == 1, "search finds the player (caught)")
	await done(lvl)

	# เต้ checks under-desk spots
	lvl = await make(["###########", "#P.D......#", "#.........#", "#.......G.#", "###########"])
	var desk = kinds(lvl, "hide")[0]
	check(desk.hide_type == "desk", "desk is a hide spot")
	desk.interact()
	await frames(3)
	check(lvl.npcs[0].state == "search", "goblin searches an occupied desk")
	await done(lvl)

func t_noise() -> void:
	var lvl := await make(["#############", "#P.s........#", "#...........#", "#.........M.#", "#############"])
	var n: Npc = lvl.npcs[0]
	n.rotation.y = 0.0
	var home := n.global_position
	Game.noise(lvl.cell_pos(Vector2i(6, 2)), 12.0)
	check(n.state == "investigate", "noise nearby -> coworker investigates")
	await get_tree().create_timer(2.5).timeout
	check(n.global_position.distance_to(lvl.cell_pos(Vector2i(6, 2))) < home.distance_to(lvl.cell_pos(Vector2i(6, 2))) - 3.0, "coworker walks toward the noise")
	await done(lvl)

	lvl = await make(["#############", "#P.s........#", "#...........#", "#.........M.#", "#############"])
	n = lvl.npcs[0]
	n.rotation.y = 0.0
	kinds(lvl, "throwable")[0].interact()
	check(lvl.player.held, "picked up a throwable")
	lvl.player.rotation.y = -PI / 2 - 0.3   # toward the coworker side
	lvl.player.throw()
	await get_tree().create_timer(1.5).timeout
	check(n.state == "investigate", "thrown object lands -> coworker investigates")
	await get_tree().create_timer(2.0).timeout
	check(kinds(lvl, "throwable").filter(func(a): return a.usable()).size() == 1, "thrown object can be picked up again")
	await done(lvl)

	lvl = await make(["#########", "#P......#", "#....M..#", "#########"])
	n = lvl.npcs[0]
	n.rotation.y = 0.0
	n.set_physics_process(false)
	lvl.player.crouching = true
	lvl.player.rotation.y = -PI / 2
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(n.state == "patrol", "crouch-walking makes no noise")
	await done(lvl)

func t_phone() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.5).timeout
	Game.text("แม่", "กลับกี่โมงลูก")
	Game.story_event.emit({"text": ["เบอร์ไม่รู้จัก", "ยังไม่กลับอีกเหรอครับ"]})
	check(Game.threads.has("เบอร์ไม่รู้จัก") and main.unread == 2, "story trigger texts arrive + unread count")
	main.open_phone()
	await frames(3)
	check(main.phone.visible and main.phone_app == "" and main.phone_home.visible, "phone opens on the app picker")
	main._show_app("chat")
	await frames(3)
	check(main.phone_tabs.get_child_count() == 2 and main.phone_list.get_child_count() == 1, "chat app lists threads and messages")
	await shot("phone.png")
	main._show_app("gps")
	await frames(3)
	check(main.phone_gps.visible and not main.phone_chat.visible, "gps app shown, chat hidden")
	check(not main._gps_target().is_empty(), "gps points at an unfinished objective")
	main._show_app("docs")
	await frames(3)
	check(main.phone_docs.visible and not main.phone_gps.visible, "docs app shown, gps hidden")
	main.close_phone()
	var pl = main.level.player
	pl.toggle_flashlight()
	check(pl.flashlight.visible, "flashlight turns on")
	Game.phone_battery = 0.3
	await get_tree().create_timer(1.0).timeout
	check(not pl.flashlight.visible and Game.phone_battery == 0.0, "flashlight drains phone battery and dies at 0")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

func t_audio() -> void:
	for b in ["SFX", "Amb", "Tension"]:
		check(AudioServer.get_bus_index(b) >= 0, "audio bus %s exists" % b)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var lp := AudioServer.get_bus_effect_count(sfx_bus) - 1
	Game.set_hidden("locker")
	check(AudioServer.is_bus_effect_enabled(sfx_bus, lp), "hiding muffles sound")
	Game.set_hidden("")
	check(not AudioServer.is_bus_effect_enabled(sfx_bus, lp), "coming out un-muffles")
	for s in ["heartbeat", "breathing", "drone", "door_slam", "elevator_ding", "chair_creak", "printer", "whisper", "knock", "footsteps_far"]:
		check(Game.stream(s) != null, "sound %s loads" % s)
	for s in ["squeak", "hum", "mutter", "techspeak", "guard_talk", "sting", "gasp"]:   # coworkers sound human, not synth tones
		check(Game.stream(s) is AudioStreamOggVorbis, "coworker sound %s is a real recording" % s)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.5).timeout
	var n: Npc = main.level.npcs[0]
	n.set_physics_process(false)
	n.global_position = Game.player.global_position + Vector3(14, 0, 0)
	var far: float = main.tension().x
	n.global_position = Game.player.global_position + Vector3(3, 0, 0)
	var near: float = main.tension().x
	check(near > far, "heartbeat rises as a coworker gets close (%.2f > %.2f)" % [near, far])
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Every objective/item on the big maps is reachable from the spawn, and intro "act" steps exist.
func t_reach() -> void:
	for i in Game.STAGES.size():
		Game.new_game()
		Game.stage = i
		var data: Dictionary = Game.STAGES[i]
		var lvl := stage_scene(i)
		add_child(lvl)
		await frames(10)   # region swap needs a few physics frames to reach the navigation map
		var map := lvl.get_world_3d().navigation_map
		NavigationServer3D.map_force_update(map)   # previous stage's region was just removed: sync now
		var bad := []
		for t in lvl.find_children("*", "Area3D", true, false):
			var p: Vector3 = t.front if t.get("kind") == "hide" else t.global_position
			var q := NavigationServer3D.map_get_closest_point(map, p)
			var path := NavigationServer3D.map_get_path(map, lvl.spawn, q, true)
			if Vector2(q.x - p.x, q.z - p.z).length() > 1.8 or path.is_empty() or path[path.size() - 1].distance_to(q) > 0.3:
				bad.append("%s@%.0f,%.0f" % [t.name, p.x, p.z])
		check(bad.is_empty(), "stage %d: every item/exit reachable %s" % [i + 1, bad])
		var n: Npc = lvl.npcs[0] if not lvl.npcs.is_empty() else null
		var scenes: Array = data.get("intro", []) + data.get("rage_scene", [])
		for k in data.get("item_scenes", {}):
			scenes += data.item_scenes[k]
		var missing: Array = scenes.filter(func(st): return st[0] == "act" and not (n and n.has_method(st[1])))
		check(missing.is_empty(), "stage %d: intro actions exist on %s" % [i + 1, n.display_name if n else "-"])
		check(data.get("signs", []).size() == data.map.reduce(func(a, r): return a + r.count("r"), 0), "stage %d: one sign text per r" % (i + 1))
		check(data.get("notes", []).size() == data.map.reduce(func(a, r): return a + r.count("e"), 0), "stage %d: one note per e" % (i + 1))
		check(data.get("triggers", []).size() == data.map.reduce(func(a, r): return a + r.count("!"), 0), "stage %d: one trigger per !" % (i + 1))
		check(data.get("scares", []).size() == data.map.reduce(func(a, r): return a + r.count("J"), 0), "stage %d: one scare per J" % (i + 1))
		check(data.get("postits", []).size() == data.map.reduce(func(a, r): return a + r.count("n"), 0), "stage %d: one post-it text per n" % (i + 1))
		var notes := kinds(lvl, "read")
		check(notes.all(func(nt): return nt.title != "" and nt.text != "") and (data.has("loop") or notes.any(func(nt): return nt.reveal != "none" or nt.evidence)), "stage %d: notes have text and give something" % (i + 1))
		check(data.get("items", []).size() == data.map.reduce(func(a, r): return a + r.count("y"), 0), "stage %d: one item per y" % (i + 1))
		check(kinds(lvl, "file").all(func(it): return it.title != ""), "stage %d: goal items have names" % (i + 1))
		check(data.map.reduce(func(a, r): return a + r.count("Z"), 0) == 1, "stage %d: one dream clue" % (i + 1))
		var qbad := []   # every job step: a spot Tong can walk up to from the start
		for q in data.get("quests", []):
			for st in q.steps:
				var p: Vector3 = lvl.cell_pos(st.at)
				var qp := NavigationServer3D.map_get_closest_point(map, p)
				var path := NavigationServer3D.map_get_path(map, lvl.spawn, qp, true)
				if Vector2(qp.x - p.x, qp.z - p.z).length() > 1.0 or path.is_empty() or path[path.size() - 1].distance_to(qp) > 0.3:
					qbad.append("%s@%s" % [q.id, st.at])
		check(qbad.is_empty(), "stage %d: every job step reachable %s" % [i + 1, qbad])
		await done(lvl)
	# play each intro for a moment, then skip: control returns
	Game.skip_cutscenes = false
	for i in Game.STAGES.size():
		Game.new_game()
		Game.stage = i
		var lvl := stage_scene(i)
		add_child(lvl)
		var cs := Cutscene.new()
		var run := func(): await cs.play(lvl, Game.STAGES[i].intro)
		run.call()
		await get_tree().create_timer(3.0).timeout
		await shot("intro_%d.png" % (i + 1))
		check(Game.in_cutscene, "stage %d intro is playing" % (i + 1))
		cs.skipping = true
		await pframes(3)
		check(not Game.in_cutscene and lvl.player.cam.current, "stage %d intro skip returns control" % (i + 1))
		await done(lvl)
	Game.skip_cutscenes = true

func t_cameo() -> void:
	var lvl := await make(["###########", "#P.......g#", "#.........#", "###########"])
	check(lvl.cameos.size() == 1, "guard cameo spawned")
	lvl.player.rotation.y = -PI / 2   # look at him
	await get_tree().create_timer(1.0).timeout
	check(Game.hints == 1 and not is_instance_valid(lvl.cameos[0].body), "looking at a cameo = hint noticed, he vanishes")
	await done(lvl)
	lvl = await make(["###########", "#P.......g#", "#.........#", "###########"])
	lvl.player.rotation.y = PI / 2    # never looks
	await get_tree().create_timer(1.0).timeout
	check(Game.hints == 0 and is_instance_valid(lvl.cameos[0].body), "unseen cameo stays, no hint")
	await done(lvl)

	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.5).timeout
	Game.story_event.emit({"photo": true, "text": ["เบอร์ไม่รู้จัก", "ถ่ายมุมนี้หล่อดีนะครับ"]})
	await get_tree().create_timer(0.5).timeout
	var msgs: Array = Game.threads.get("เบอร์ไม่รู้จัก", [])
	var img: Texture2D = msgs.back().img if not msgs.is_empty() else null
	check(img != null and img.get_width() == 200, "photo message arrives with an image")
	if img:
		var im := img.get_image()
		var a := im.get_pixel(20, 20)
		var varied := false
		for p in [Vector2i(100, 75), Vector2i(180, 130), Vector2i(100, 30), Vector2i(60, 120)]:
			varied = varied or not im.get_pixel(p.x, p.y).is_equal_approx(a)
		check(varied, "photo has actual content")
		im.save_png("user://photo.png")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

func t_endings() -> void:
	Game.skip_cutscenes = false
	for id in ["A", "B", "C", "D"]:
		var lvl: Node3D = load("res://scenes/endings/ending_%s.tscn" % id).instantiate()
		add_child(lvl)
		var data: Dictionary = lvl.data
		var missing: Array = data.steps.filter(func(st): return st[0] == "body" and not Story.BODIES.has(st[1]))
		check(missing.is_empty(), "ending %s: all extras defined" % id)
		var cs := Cutscene.new()
		var done_flag := [false]
		var run := func():
			await cs.play(lvl, data.steps)
			done_flag[0] = true
		run.call()
		await get_tree().create_timer(4.5).timeout
		await shot("ending_%s.png" % id)
		cs.skipping = true
		await pframes(3)
		check(done_flag[0] and not Game.in_cutscene, "ending %s scene plays and finishes" % id)
		lvl.queue_free()
		await frames(2)
	Game.skip_cutscenes = true
	Game.new_game()

func t_save() -> void:
	Game.new_game()
	Game.stage = 2
	Game.times_caught = 3
	Game.notice("call_0")
	Game.clues[0] = true
	Game.phone_taken = true
	Game.save_progress()
	Game.new_game()
	check(Game.load_progress() and Game.stage == 2 and Game.times_caught == 3 and Game.hints == 1 and Game.clues.size() == 1 and Game.phone_taken, "save/continue restores progress")
	Game.clear_save()
	check(not Game.has_save(), "save cleared after an ending")
	Game.sensitivity = 1.5
	Game.save_settings()
	Game.sensitivity = 1.0
	Game.load_settings()
	check(Game.sensitivity == 1.5, "settings persist")
	Game.sensitivity = 1.0
	Game.volume = 0.8
	Game.save_settings()
	Game.new_game()

# Frame rate on each 2x stage through the real 1/3-res pipeline.
func t_perf() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	for i in Game.STAGES.size():
		Game.new_game()
		Game.stage = i
		main.start_stage()
		await get_tree().create_timer(1.0).timeout
		var t0 := Time.get_ticks_msec()
		var f0 := Engine.get_frames_drawn()
		await get_tree().create_timer(2.0).timeout
		var fps := (Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
		check(fps >= 50.0, "stage %d runs at %.0f fps" % [i + 1, fps])
		await shot("play_%d.png" % (i + 1))
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.clear_save()
	Game.new_game()

# Regression: Start/Retry pressed again during the clock card built a 2nd level (2 managers).
func t_no_dupes() -> void:
	Game.skip_cutscenes = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.3).timeout
	check(not main.screens.menu.visible, "menu hides as soon as Start is pressed")
	check(main.card.visible and main.card.text == Game.STAGES[0].story[0], "stage story text plays on black before the clock card")
	main.start_stage()   # impatient second press
	await get_tree().create_timer(4.0).timeout
	check(main.view.find_children("*", "Npc", true, false).size() == 1, "double Start -> still exactly one coworker")
	Game.damage(500, "x")
	await get_tree().create_timer(2.5).timeout
	Game.reset_stage()
	main.start_stage()
	await get_tree().create_timer(0.3).timeout
	main.start_stage()   # double Retry
	await get_tree().create_timer(4.0).timeout
	check(main.view.find_children("*", "Npc", true, false).size() == 1 and main.view.get_child_count() == 1, "double Retry -> one level, one coworker")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.skip_cutscenes = true
	Game.clear_save()
	Game.new_game()

# Each coworker's death jumpscare: lunge (screenshot), face slam (screenshot), then respawn;
# with an empty battery it ends on the game-over screen instead.
func t_jumpscare() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	for i in Game.STAGES.size():
		if Game.STAGES[i].has("loop"):
			continue
		Game.new_game()
		Game.stage = i
		main.start_stage()
		await get_tree().create_timer(0.5).timeout
		var n: Npc = main.level.npcs[0]
		var pl = main.level.player
		pl.global_position = n.global_position - n.global_basis.z * 1.0   # on its open path, like a catch
		await frames(2)
		Game.catch(n)
		var dur: float = {"Manager": 0.5, "Sweeper": 0.45, "Goblin": 0.5, "Guard": 0.75, "Hr": 0.45, "Doctor": 0.4}[n.get_script().get_global_name()]   # what each mob's jumpscare() returns
		await get_tree().create_timer(dur - 0.05).timeout
		await shot("scare_%d_lunge.png" % (i + 1))
		await get_tree().create_timer(0.15).timeout
		check(main.scare_face.visible and main._scaring and AudioServer.is_bus_mute(AudioServer.get_bus_index("Amb")), "stage %d %s: face slam shows (ambience cut to silence)" % [i + 1, n.display_name])
		if not Game.retro:   # HD: the face is torn, strobing, sunk in dark - never a bright portrait
			var lum := 0.0
			var img: Image = main.scare_face.texture.get_image()
			for y in range(0, img.get_height(), 8):
				for x in range(0, img.get_width(), 8):
					var c := img.get_pixel(x, y)
					lum += c.get_luminance() * c.a
			lum /= float((img.get_height() / 8) * (img.get_width() / 8))
			check(main.scare_face.material != null and main.scare_face.material.get_shader_parameter("amount") > 0.2 and lum < 0.3, "stage %d: the HD slam is dark and torn (mean light %.2f)" % [i + 1, lum])
		await shot("scare_%d_slam.png" % (i + 1))
		await get_tree().create_timer(2.4).timeout
		check(not Game.busy and not pl.frozen and not main.scare_face.visible and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Amb")), "stage %d: jumpscare ends -> respawn, play + ambience resume" % (i + 1))
		check(n.body.parts.Neck.rotation == Vector3.ZERO and n.body.scale == Vector3.ONE and pl.cam.h_offset == 0.0, "stage %d: coworker + camera reset after jumpscare" % (i + 1))
		if n is Guard:   # lights[0] is the dying tube that flickers on its own
			check(main.level.lights.slice(1).all(func(l): return l.visible), "guard's blackout restores the lights")
	Game.battery = 10.0
	Game.catch(main.level.npcs[0])
	await get_tree().create_timer(4.5).timeout
	check(main.screens.over.visible, "battery-emptying catch: jumpscare then game over")
	main.queue_free()
	await frames(2)
	Game.new_game()

# Debug menu: wrong password stays locked, 1234 unlocks the stage list, picking one loads it.
func t_debug() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main.show_screen("debug")
	main.debug_pw.text = "0000"
	main._debug_unlock()
	check(not main.debug_list.visible and main.debug_err.text != "", "debug: wrong password stays locked")
	main.debug_pw.text = "1234"
	main._debug_unlock()
	check(main.debug_list.visible and not main.debug_pw.visible, "debug: 1234 unlocks the stage list")
	main.show_screen("menu")
	main.show_screen("debug")
	check(not main.debug_list.visible and main.debug_pw.text == "", "debug: locks again when reopened")
	main._debug_start(idx("stage_3"))
	await get_tree().create_timer(1.0).timeout
	check(Game.stage == idx("stage_3") and main.level != null and main.level.npcs[0] is Goblin and main.hud.visible, "debug: jump straight to the server room")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Regression: found while hiding -> game over -> retry left the slit overlay + muffle on.
func t_hide_teardown() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.5).timeout
	kinds(main.level, "hide")[0].interact()
	await get_tree().create_timer(0.2).timeout
	Game.battery = 10.0
	main.level.npcs[0].found_player()
	await get_tree().create_timer(2.5).timeout
	Game.reset_stage()
	main.start_stage()
	await get_tree().create_timer(1.0).timeout
	var bus := AudioServer.get_bus_index("SFX")
	check(main.hide_view.get_child_count() == 0 and not AudioServer.is_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1), "game over while hidden: overlay + muffle cleared on retry")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.clear_save()
	Game.new_game()

func press(key: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	await pframes(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await pframes(2)

# Regression (web): the browser drops mouse capture (Esc, focus). Keys must still work,
# e.g. E to climb out from under a desk. Uses real key events through main + SubViewport.
func t_keys_uncaptured() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)   # stage 1 (start_game plays the tutorial)
	await get_tree().create_timer(0.5).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # browser never granted / dropped capture
	await pframes(2)
	get_tree().paused = false   # (the capture-loss auto-pause is tested below)
	main.show_screen("")
	main._was_captured = false
	var pl = main.level.player
	kinds(main.level, "hide")[0].interact()
	check(pl.hidden, "hid (setup)")
	await press(KEY_E)
	check(not pl.hidden, "E gets you out of a hide spot even when the mouse isn't captured")
	var c0: bool = pl.crouching
	await press(KEY_C)
	check(pl.crouching != c0, "C crouches even when the mouse isn't captured")
	main._was_captured = true   # as if the browser just dropped pointer lock (Esc)
	await pframes(2)
	check(get_tree().paused and main.screens.pause.visible, "losing mouse capture mid-play opens the pause menu")
	get_tree().paused = false
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.clear_save()
	Game.new_game()

# ---------- v3: models, notes, power, chases, scares, tutorial ----------

# Blender models: every preset builds with the parts the animations and jumpscares drive.
func t_models() -> void:
	for p in Story.BODIES:
		var b := Body.new()
		add_child(b)
		b.build(Story.BODIES[p])
		var ok := ["LegL", "LegR", "ArmL", "ArmR", "Torso", "Neck", "NeckMesh", "Head"].all(func(k): return b.parts.has(k) and b.parts[k] is Node3D)
		check(ok and b.head_top() > (1.45 if b.real else 1.7) and b.head_top() < 3.2, "model %s builds with all parts (head top %.2f m)" % [p, b.head_top()])
		if b.real:
			check(["Chest", "ShinL", "ShinR", "ForearmL", "ForearmR"].all(func(k): return b.parts.has(k)), "model %s has knees, elbows and a chest" % p)
		b.queue_free()
	await frames(1)
	# the realistic body bends at the knee and the elbow: the bones follow the stand-ins
	Game.retro = false
	var r := Body.new()
	add_child(r)
	r.build(Story.BODIES.tong)
	r.parts.ShinL.rotation.x = -1.0
	r.parts.ForearmR.rotation.x = 1.4
	r.parts.LegL.rotation.x = 0.5
	await pframes(2)
	var sk: Skeleton3D = r._skel
	var knee := sk.get_bone_pose_rotation(sk.find_bone("ShinL"))
	var elbow := sk.get_bone_pose_rotation(sk.find_bone("ForearmR"))
	check(knee.is_equal_approx(r.parts.ShinL.quaternion) and elbow.is_equal_approx(r.parts.ForearmR.quaternion), "realistic body: the knee and elbow bones follow their stand-ins")
	var shin_dir := sk.get_bone_global_pose(sk.find_bone("ShinL")).basis.y
	var thigh_dir := sk.get_bone_global_pose(sk.find_bone("LegL")).basis.y
	check(rad_to_deg(shin_dir.angle_to(thigh_dir)) > 50.0, "realistic body: the knee really bends (%.0f degrees)" % rad_to_deg(shin_dir.angle_to(thigh_dir)))
	r.queue_free()
	await frames(1)

# Notes: reader gets the text + a tip, the reveal marks goals, evidence counts once.
func t_notes() -> void:
	var lvl := await make(["#########", "#P.e.e.d#", "#.......#", "#########"], 1, {"notes": [
		{"title": "รายการเอกสาร", "text": "แฟ้มอยู่สุดห้อง", "reveal": "goals"},
		{"title": "สมุดเวร", "text": "...", "evidence": true}]})
	var got := []
	var on_note := func(t, b, tip): got.append([t, b, tip])
	Game.note_opened.connect(on_note)
	var notes := kinds(lvl, "read")
	notes[0].interact()
	var doc = kinds(lvl, "doc")[0]
	check(got.size() == 1 and got[0][1] == "แฟ้มอยู่สุดห้อง" and got[0][2] != "", "note reader gets the text and what it gave you")
	check(doc.find_children("RevealMarker", "", true, false).size() == 1, "reveal=goals marks the goal through walls")
	notes[1].interact()
	notes[1].interact()
	check(Game.hints == 1 and notes[1].usable(), "evidence note counts once and stays readable")
	Game.note_opened.disconnect(on_note)
	await done(lvl)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.5).timeout
	kinds(main.level, "read")[0].interact()
	await frames(2)
	check(main.note_panel.visible and main.note_labels.body.text != "", "note reader shows on screen")
	await shot("note.png")
	main.level.player.global_position += Vector3(2, 0, 0)
	await pframes(3)   # _process closes it (physics frames can bunch up while the stage loads)
	check(not main.note_panel.visible, "walking away closes the note")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Stage 3 mechanics: power out -> breaker; post-its -> keypad; wrong code is loud.
func t_power() -> void:
	var lvl := await make(["###########", "#P.n.n.n..#", "#..Y..K...#", "#.L...u..M#", "###########"], 4,
		{"dark_start": true, "pc_code": "4471", "postits": [{"title": "1", "text": "4___"}, {"title": "2", "text": "_47_"}, {"title": "3", "text": "___1"}]})
	check(lvl.dark and lvl.lights.all(func(l): return not l.visible) and lvl.get_node("Emergency").get_child(0).visible, "dark_start: lights off, emergency light on")
	var pc = kinds(lvl, "pc")[0]
	check(pc.code == "4471", "pc gets its code from stage data")
	var asked := []
	var on_ask := func(p): asked.append(p)
	Game.code_requested.connect(on_ask)
	for n in kinds(lvl, "note"):
		n.interact()
	pc.interact()
	check(asked.is_empty() and Game.goal_count == 3, "PC won't boot without power")
	var dark_mult: float = lvl.sight_mult()
	kinds(lvl, "breaker")[0].interact()
	check(not lvl.dark and lvl.lights.all(func(l): return l.visible) and lvl.sight_mult() > dark_mult, "breaker brings the lights back (and you're easier to see)")
	check(lvl.npcs[0].state == "investigate", "flipping the breaker is loud: the coworker comes to look")
	lvl.npcs[0].reset()
	pc.interact()
	check(asked.size() == 1, "with power + 3 post-its the PC asks for the code")
	Game.code_requested.disconnect(on_ask)
	Game.submit_code(pc, "1234")
	check(Game.goal_count == 3 and lvl.npcs[0].state == "investigate", "wrong code: alarm beep draws the coworker")
	Game.submit_code(pc, "4471")
	check(Game.goal_count == 4 and lvl.exit_open, "right code logs in and opens the exit")
	lvl.player.flashlight.visible = true
	check(lvl.sight_mult() > 1.0, "a lit flashlight makes you visible from farther")
	lvl.player.flashlight.visible = false
	await done(lvl)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(idx("stage_3"))
	await get_tree().create_timer(0.5).timeout
	check(main.level.dark, "stage 3 starts in a blackout")
	var early_target: Dictionary = main._gps_target()
	check(not early_target.is_empty() and early_target.label != main.level.GOAL_NAMES.pc, "gps points at a post-it/breaker before the PC is even usable")
	await shot("stage3_dark.png")
	main.level.restore_power()
	Game.goal_count = 3
	var real_pc = kinds(main.level, "pc")[0]
	real_pc.interact()
	await frames(2)
	check(main.keypad.visible and main.level.player.frozen, "keypad opens on screen")
	await shot("keypad.png")
	main._submit_code("4471")
	check(not main.keypad.visible and not main.level.player.frozen and Game.goal_count == 4, "typing the post-it code logs in")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Stage 2 mechanic: coffee done -> she comes for you, even after a catch.
func t_rage() -> void:
	var lvl := await make(["###############", "#S...........C#", "#.............#", "#P............#", "###############"], 1,
		{"rage_on_goal": true, "rage_line": "ป้าพร: !!"})
	var s: Npc = lvl.npcs[0]
	lvl.player.global_position = lvl.cell_pos(Vector2i(12, 2))
	kinds(lvl, "coffee_goal")[0].interact()
	check(lvl.exit_open and lvl.raging and lvl.spawn.distance_to(lvl.cell_pos(Vector2i(12, 2))) < 0.5, "coffee: exit opens, chase starts, checkpoint here")
	await get_tree().create_timer(1.8).timeout
	check(s.raging and s.state == "chase", "she comes for you after a beat")
	lvl.respawn()
	await get_tree().create_timer(1.8).timeout
	check(s.raging and s.state == "chase", "caught mid-chase: the chase resumes")
	await done(lvl)

# Stage 4 mechanic: holding the scanner brings everyone; the scan opens the exit.
func t_finale() -> void:
	var lvl := await make(["##############", "#P..........R#", "#..F.........#", "#............#", "##############"], 1, {"finale": true})
	var pl = lvl.player
	var sc = kinds(lvl, "scanner")[0]
	pl.global_position = lvl.cell_pos(Vector2i(3, 3))
	pl.rotation.y = 0.0   # face -z: the scanner is one cell north
	pl.cam.rotation.x = -0.35
	await frames(3)
	check(pl.focus() == sc, "looking at the scanner (setup)")
	sc.interact()
	check(Game.goal_count == 0, "a tap doesn't scan: you have to hold")
	Input.action_press("interact")
	await get_tree().create_timer(0.3).timeout
	check(lvl.extras.size() == 3 and lvl.npcs.all(func(n): return n.raging), "scanning wakes everyone: 3 more coworkers come")
	for n in lvl.npcs:
		n.set_physics_process(false)   # (they'd catch you in a room this small)
	await get_tree().create_timer(3.0).timeout
	Input.action_release("interact")
	check(Game.goal_count == 1 and lvl.exit_open, "held scan completes and opens the exit")
	lvl.respawn()
	check(lvl.extras.is_empty() and lvl.npcs.size() == 1 and not lvl.raging, "caught: the finale resets")
	await done(lvl)

# Stage 4: the scanner is dead until the fuse (security room) is in the panel (mail room).
func t_fuse() -> void:
	var lvl := await make(["#########", "#P......#", "#.f.p.F.#", "#########"], 3)
	var fu = kinds(lvl, "fuse")[0]
	var fb = kinds(lvl, "fuse_box")[0]
	check(not lvl.scanner_powered(), "scanner is dead before the fuse is in")
	fb.interact()
	check(not fb.used and Game.goal_count == 0, "panel refuses without the fuse")
	fu.interact()
	check(Game.has_fuse and Game.goal_count == 1, "fuse picked up")
	fb.interact()
	check(fb.used and not Game.has_fuse and Game.goal_count == 2, "fuse goes into the panel")
	check(lvl.scanner_powered() and lvl.dark and lvl.fuse_dark, "scanner powered; the floor goes dark")
	await get_tree().create_timer(3.0).timeout
	lvl.respawn()
	check(lvl.dark, "...and stays dark until the exit (even after being caught)")
	Game.phone_battery = 100.0
	lvl.player.flashlight.visible = true
	await get_tree().create_timer(1.0).timeout
	lvl.player.flashlight.visible = false
	var used := 100.0 - Game.phone_battery
	check(used > 0.4 and used < 0.75, "flashlight drains slower in the fuse blackout (%.2f%%/s)" % used)
	await done(lvl)

# Scare nodes: lights_out, behind, figure.
func t_scares() -> void:
	var lvl := await make(["###########", "#P.J.J.J.L#", "#.........#", "###########"], 1, {"scares": [
		{"kind": "lights_out", "secs": 0.5, "sfx": "whisper"},
		{"kind": "behind", "preset": "guard", "secs": 3.0},
		{"kind": "figure", "preset": "manager", "at": Vector2i(9, 2), "secs": 3.0}]})
	var sc := lvl.get_node("Scares").get_children()
	check(sc.size() == 3 and sc[2].has_node("At"), "scare nodes built (figure has a draggable At marker)")
	sc[0].fire()
	check(lvl.dark, "lights_out scare kills the lights")
	await get_tree().create_timer(0.8).timeout
	check(not lvl.dark, "...and they come back")
	lvl.player.rotation.y = -PI / 2   # facing +x
	sc[1].fire()
	var behind: Node3D = lvl.cameos.back().body
	check(is_instance_valid(behind) and (behind.global_position - lvl.player.global_position).dot(Vector3.RIGHT) < 0.0, "behind scare appears behind you")
	lvl.player.rotation.y = PI / 2   # turn around
	await get_tree().create_timer(0.8).timeout
	check(not is_instance_valid(behind), "turn around: it lunges and is gone")
	sc[2].fire()
	sc[2].fire()
	check(lvl.cameos.filter(func(c): return c.id == "" and is_instance_valid(c.body)).size() == 1, "a scare fires once")
	await done(lvl)
	# hallucinations at low Social Battery
	lvl = await make(["###################", "#P................#", "#.................#", "###################"], 1)
	lvl.player.rotation.y = -PI / 2
	Game.battery = 10.0
	for f in 20:   # random spots: the navigation map can take a few frames to be ready under load
		lvl._phantom_t = 0.0
		await frames(1)
		if lvl.cameos.size() > 0:
			break
	check(lvl.cameos.size() == 1, "low Social Battery: a phantom coworker appears in view")
	await done(lvl)

# พี่สมชาย in the dark: watching him doesn't work unless your flashlight is on.
func t_guard_dark() -> void:
	var lvl := await make(["#########", "#P.....R#", "#########"], 0)
	var g = lvl.npcs[0]
	g.wake = 0.0
	lvl.player.rotation.y = -PI / 2
	lvl.set_dark(true)
	var p0: Vector3 = g.global_position
	await frames(30)
	check(g.global_position.distance_to(p0) > 0.3, "lights out: he moves even while you look")
	lvl.player.flashlight.visible = true
	await frames(2)
	p0 = g.global_position
	await frames(30)
	check(g.global_position.distance_to(p0) < 0.05, "flashlight on him: frozen again")
	lvl.player.flashlight.visible = false
	await done(lvl)

# Stage 4: พี่สมชาย waits in the security room, at his CCTV wall, until the dark or his phone going missing.
func t_guard_room() -> void:
	Game.new_game()
	Game.stage = idx("stage_4")
	var lvl := stage_scene(Game.stage)
	add_child(lvl)
	await frames(10)
	lvl.flicker = Vector2.ZERO   # no random blackout mid-test
	var g: Guard = lvl.npcs[0]
	var pl = lvl.player
	var p0: Vector3 = g.global_position
	check(g.waiting and Vector2(p0.x - 11.0, p0.z - 36.3).length() < 0.5, "stage 4: guard starts in the security room, waiting")
	g.wake = 0.0
	await frames(40)   # Tong is up in the lobby, not looking at him
	check(g.global_position.distance_to(p0) < 0.05, "...and stays at his monitors while the lights are on")
	pl.global_position = Vector3(11, pl.global_position.y, 31)   # in the doorway, looking in
	pl.rotation.y = PI
	await frames(3)
	await shot("guard_room.png")
	pl.global_position = Vector3(9.5, pl.global_position.y, 35)   # his bed corner
	pl.rotation.y = PI / 2
	await frames(3)
	await shot("guard_room_bed.png")
	lvl.set_dark(true)
	await frames(3)
	lvl.set_dark(false)
	pl.global_position = lvl.spawn
	await frames(40)
	check(not g.waiting and g.global_position.distance_to(p0) > 0.5, "first blackout: he is up and coming")
	lvl.respawn()
	await frames(2)
	check(g.waiting and g.global_position.distance_to(p0) < 0.05, "caught -> respawn: back at the monitors")
	kinds(lvl, "guard_phone")[0].interact()
	g.wake = 0.0
	await frames(40)
	check(not g.waiting and g.global_position.distance_to(p0) > 0.5, "taking his phone gets him up too")
	await done(lvl)

func wait_phase(tut: Node, phase: String, secs: float) -> void:
	var t := 0.0
	while tut.phase != phase and t < secs:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func read_all(tut: Node) -> void:   # phone open until the stranger has sent everything
	var t := 0.0
	while not tut.pending.is_empty() and t < 30.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func walk_dist(pl: Node3D, n: int) -> float:
	var p0: Vector3 = pl.global_position
	Input.action_press("move_forward")
	await frames(n)
	Input.action_release("move_forward")
	return pl.global_position.distance_to(p0)

# Tutorial: a bright afternoon with everyone at work -> the stranger's texts hold Tong still until
# read -> talk to everyone -> night falls and they leave -> the rumour texts -> the mirror ends it.
func t_tutorial() -> void:
	Game.new_game()
	Game.tutorial = true
	var lvl: Node3D = load("res://scenes/stages/tutorial.tscn").instantiate()
	add_child(lvl)
	await frames(5)
	var tut: Node = lvl.get_node("Tutorial")
	var pl = lvl.player
	var crew: Array = tut.coworkers()
	check(lvl.npcs.is_empty() and crew.size() == 4 and crew.all(func(c): return c.lines.size() > 0), "tutorial: four friendly coworkers with something to say, nobody hunting")
	check(lvl.gloom == 0.0 and lvl._env.fog_density == 0.0 and Game.clock == tut.day_clock, "tutorial starts as a bright afternoon (%s)" % Game.clock)
	await shot("tutorial_day.png")
	var sweeper: Node3D = crew[0]
	var s0 := sweeper.global_position
	await wait_phase(tut, "read1", 4.0)
	await get_tree().create_timer(2.5).timeout
	check(sweeper.global_position.distance_to(s0) > 0.5, "coworkers get on with their work (ป้าพร mops along)")
	check(Game.phone_lock and Game.threads.get(tut.sender, []).size() == 1, "the stranger's first text arrives and holds Tong still; the rest wait for the phone")
	check(await walk_dist(pl, 20) < 0.05, "can't walk until the phone has been read")
	Game.event.emit("phone")   # what main.gd open_phone / close_phone do
	await get_tree().create_timer(3.4).timeout
	var got: int = Game.threads[tut.sender].size()
	check(got >= 2 and got < tut.controls.size() and Game.typing, "phone open: the texts come one at a time (%d so far), still typing" % got)
	Game.phone_lock = false
	Game.event.emit("phone_read")
	await frames(2)
	check(Game.phone_lock and tut.phase == "read1", "closed before the last text: still held")
	Game.event.emit("phone")
	await read_all(tut)
	check(Game.threads[tut.sender].size() == tut.controls.size() and not Game.typing, "all %d texts in, nothing more being typed" % tut.controls.size())
	Game.phone_lock = false
	Game.event.emit("phone_read")
	await frames(2)
	check(tut.phase == "meet" and await walk_dist(pl, 20) > 0.3, "read it: free to walk, go and say hello")
	var said := []
	Game.message.connect(func(text, _secs): said.append(text))
	for c in crew:
		check(c.usable() and c.prompt().contains(c.display_name), "%s can be talked to" % c.display_name)
		c.interact()
	check(said.size() == 4 and said[0] == sweeper.lines[0], "each coworker answers with their own line")
	await pframes(3)   # (the phase moves on in _process)
	check(tut.phase == "dusk", "said hello to everyone: the afternoon starts to go (%s, busy %s, cutscene %s, talked %s)" % [tut.phase, Game.busy, Game.in_cutscene, str(crew.map(func(c): return c.talked))])
	tut.dusk_secs = 2.0
	await wait_phase(tut, "night", 20.0)
	check(lvl.gloom == 1.0 and lvl._env.fog_density > 0.0 and tut.coworkers().is_empty() and Game.clock == tut.night_clock, "night (%s): lights down, fog in, everyone gone home" % Game.clock)
	await get_tree().create_timer(0.6).timeout   # the lights blink as the last one goes
	await shot("tutorial_night.png")
	await wait_phase(tut, "read2", 6.0)
	Game.event.emit("phone")
	await read_all(tut)
	check(Game.phone_lock and Game.threads[tut.sender].size() == tut.controls.size() + tut.rumour.size(), "alone at night: the rumour texts hold him again")
	Game.phone_lock = false
	Game.event.emit("phone_read")
	await frames(2)
	check(tut.phase == "mirror", "read: off to the washroom mirror")
	# the mirror: Tong's reflection, then the ending
	var plane: Node3D = tut.plane
	pl.global_position = plane.global_position - plane.global_basis.z * 4.5 + Vector3(1.0, 0.1, 0.0)   # inside the door, short of the spot
	pl.rotation.y = atan2(-plane.global_basis.z.x, -plane.global_basis.z.z)
	await pframes(5)   # (the reflection follows him in _process)
	var back: Vector3 = plane.to_local(tut._reflection.global_position)
	check(tut._reflection.visible and absf(back.z - 4.5) < 0.1 and absf(back.x - 1.0) < 0.1, "Tong's reflection stands as far behind the glass as he is in front")
	check(tut.phase == "mirror", "nothing happens until he walks up to it")
	Game.skip_cutscenes = false
	tut.hold_secs = 0.5
	var cleared := []
	Game.stage_cleared.connect(func(): cleared.append(1), CONNECT_ONE_SHOT)
	pl.global_position = tut.spot.global_position - Vector3.UP * 0.9
	await wait_phase(tut, "end", 2.0)
	check(tut.phase == "end" and Game.in_cutscene, "at the mirror: the ending cutscene takes over")
	await get_tree().create_timer(1.3).timeout
	var behind := func() -> Array: return lvl.get_children().filter(func(b): return b is Body and b != tut._reflection)
	check(behind.call().is_empty(), "first it's just Tong and the mirror")
	await shot("tutorial_mirror.png")
	await get_tree().create_timer(tut.HIT_AT - 0.3).timeout   # hold + music, up to just before the hit
	check(behind.call().size() == 4 and behind.call().all(func(b): return b.visible and plane.to_local(b.global_position).z > 2.0), "the four of them have faded in behind his reflection")
	check(absf(pl.cam.rotation.x) < 0.02 and plane.to_local(pl.global_position).z < -1.0, "Tong is held in front of the glass, looking straight in")
	await shot("tutorial_behind.png")
	var t := 0.0
	while cleared.is_empty() and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(cleared.size() == 1, "cut to black, then the tutorial is over")
	Game.skip_cutscenes = true
	await done(lvl)
	check(not Game.in_cutscene and not Game.phone_lock and Game.clock == "", "tutorial leaves nothing switched on behind it")
	Game.tutorial = false

# The same opening through main.gd: the HUD says to read the phone, and closing the phone is what
# frees Tong.
func t_tutorial_phone() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main.start_game()
	await get_tree().create_timer(1.0).timeout
	var tut: Node = main.level.get_node("Tutorial")
	await wait_phase(tut, "read1", 4.0)
	await get_tree().create_timer(2.5).timeout
	check(main.lock_hint.visible and main.clock_text() == tut.day_clock and main.drone.volume_db < -50.0, "HUD: read-your-phone prompt, afternoon clock, no dread drone by day")
	await shot("tutorial_lock.png")
	main.open_phone()
	await pframes(3)
	check(main.phone_foot.text.begins_with("กำลังพิมพ์"), "phone shows the stranger is still typing")
	await read_all(tut)
	await pframes(4)
	check(Game.phone_lock and not main.lock_hint.visible and main.phone_thread == tut.sender and main.phone_list.get_child_count() == tut.controls.size(), "phone opens on the stranger's texts; Tong is still held while reading")
	await shot("tutorial_phone.png")
	main.close_phone()
	await pframes(3)
	check(not Game.phone_lock and tut.phase == "meet" and not main.lock_hint.visible, "closing the phone frees Tong")
	var guard: Node3D = tut.coworkers()[3]
	var pl = main.level.player
	pl.global_position = guard.global_position + Vector3(-1.8, 0.1, 0)
	pl.rotation.y = -PI / 2   # facing +x: him
	await frames(20)
	check(pl.focus() == guard and main.prompt.text.contains(guard.display_name), "look at a coworker: [E] talk prompt")
	await shot("tutorial_meet.png")
	var day: String = tut.day_clock
	main.skip_tutorial()
	await get_tree().create_timer(1.0).timeout
	check(not Game.tutorial and Game.stage == 0 and not Game.phone_lock and main.clock_text() != day, "skipping the tutorial from the pause menu starts stage 1 clean")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()
# Regression: a room-locked mob (home_radius) must give up at the edge of its territory instead
# of parking there mid-chase - else a doorway it got lured past stays permanently blocked.
func t_room_lock() -> void:
	var lvl := await make(["##############", "#N...........#", "#...........P#", "##############"])
	var n: Npc = lvl.npcs[0]
	n.home_radius = 6.0
	var pl = lvl.player
	pl.global_position = n.home + Vector3(2, 0, 0)   # well inside its own room
	n.spot()
	await frames(5)
	check(n.state == "chase", "spotted: dummy gives chase")
	pl.global_position = lvl.cell_pos(Vector2i(12, 2)) + Vector3.UP * 0.1   # far end, well outside home_radius
	var t := 0.0
	var max_d := 0.0
	while n.state == "chase" and t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		max_d = maxf(max_d, Vector2(n.global_position.x - n.home.x, n.global_position.z - n.home.z).length())
	check(n.state == "patrol" and n.alert == 0.0, "player runs out of the room: dummy gives up the chase instead of camping the doorway")
	check(max_d <= n.home_radius + 0.5, "dummy never leaves its own room while chasing (max %.1fm from home)" % max_d)
	await done(lvl)
# The screen falls apart as Social Battery drops.
func t_vhs() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.5).timeout
	var calm: float = main.fear()
	Game.battery = 8.0
	await get_tree().create_timer(2.5).timeout
	check(main.fear() > calm + 0.5 and main.screen_fx.get_shader_parameter("fear") > 0.5, "low Social Battery: screen distortion ramps up")
	await shot("fear.png")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# ---------- real scenes, played like a player: walk up, look, press the real E key ----------

# Stand in front of an item and look at it (as if the player walked up to it).
func face_item(pl: Node3D, item: Node3D, dist := 1.3) -> void:
	var map := pl.get_world_3d().navigation_map
	var best := Vector3.ZERO
	var best_d := INF
	for a in 16:   # an open floor spot around the item, at about `dist`
		var dir := Vector3(cos(a * TAU / 16), 0, sin(a * TAU / 16))
		var p := NavigationServer3D.map_get_closest_point(map, item.global_position + dir * dist)
		var d := absf(Vector2(p.x - item.global_position.x, p.z - item.global_position.z).length() - dist)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.55, item.global_position, 1)
		if d < best_d and pl.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			best_d = d
			best = p
	pl.global_position = Vector3(best.x, 0.05, best.z)
	var to: Vector3 = item.global_position - (pl.global_position + Vector3.UP * 1.55)
	pl.rotation.y = atan2(-to.x, -to.z)
	pl.cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

# Stage 1: the IT ticket says where the 3 documents are -> you can see it on screen.
func t_real_notes() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(1.0).timeout
	main.show_screen("")
	get_tree().paused = false
	var pl = main.level.player
	for n in main.level.npcs:
		n.set_physics_process(false)
	var ticket = kinds(main.level, "read").filter(func(n): return n.reveal == "goals")[0]
	face_item(pl, ticket)
	await frames(3)
	await pframes(2)   # the prompt label updates on the next drawn frame (slow machines run several physics frames per frame)
	check(pl.focus() == ticket and main.prompt.text.contains("อ่าน"), "real stage 1: standing at the IT ticket shows the [E] prompt")
	await shot("real_note_0_prompt.png")
	await press(KEY_E)
	await pframes(2)
	check(main.note_panel.visible and main.note_labels.title.text == ticket.title, "real stage 1: E opens the note on screen")
	await shot("real_note_1_open.png")
	var docs := kinds(main.level, "doc")
	check(docs.all(func(d): return d.find_children("RevealMarker", "", true, false).size() == 1), "real stage 1: all 3 documents get a marker")
	var doc: Node3D = docs[0]
	face_item(pl, doc, 6.0)   # walk off and look toward a document
	await pframes(4)
	check(not main.note_panel.visible, "real stage 1: note closes when you walk away")
	await shot("real_note_2_marker.png")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Stage 2: brew the coffee -> ป้าพร comes for you; the way out is shown.
func t_real_chase() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(1)
	await get_tree().create_timer(1.0).timeout
	main.show_screen("")
	get_tree().paused = false
	var pl = main.level.player
	var s: Npc = main.level.npcs[0]
	var coffee = kinds(main.level, "coffee_goal")[0]
	face_item(pl, coffee)
	await frames(3)
	check(pl.focus() == coffee, "real stage 2: standing at the coffee machine (setup)")
	await press(KEY_E)
	await pframes(2)
	check(main.level.exit_open and main.level.raging, "real stage 2: brewing the coffee starts the chase")
	await shot("real_chase_0_brew.png")
	var d0 := s.global_position.distance_to(pl.global_position)
	await get_tree().create_timer(3.0).timeout
	var d1 := s.global_position.distance_to(pl.global_position)
	check(s.raging and s.state == "chase" and d1 < d0 - 3.0, "real stage 2: ป้าพร runs at you (%.0f m -> %.0f m)" % [d0, d1])
	var to: Vector3 = s.global_position - pl.global_position
	pl.rotation.y = atan2(-to.x, -to.z)
	pl.cam.rotation.x = 0.0
	await pframes(3)
	await shot("real_chase_1_coming.png")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Floor must not swim: creep forward 2 cm per frame, measure how much the floor (lower part of the
# screen) changes frame to frame. With per-vertex snapping on the floor quads this jumped around.
func t_floor_still() -> void:
	Game.retro = true   # the swim is vertex snapping, a retro-look thing (HD textures move with the view, as they should)
	HD.apply_look()
	var lvl := stage_scene(0)
	add_child(lvl)
	lvl.set_process(false)   # the dying tube's random flicker isn't the swim being measured
	for n in lvl.npcs:
		n.set_physics_process(false)
	var pl = lvl.player
	pl.set_physics_process(false)
	pl.cam.rotation.x = -0.5   # look at the floor
	await frames(10)
	var prev: Image = null
	var diffs := []
	for i in 12:
		pl.global_position += -pl.global_basis.z * 0.02
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_L8)
		var w := img.get_width()
		var h := img.get_height()
		if prev:
			var d := 0.0
			for y in range(int(h * 0.6), h, 4):
				for x in range(0, w, 4):
					d += absf(img.get_pixel(x, y).r - prev.get_pixel(x, y).r)
			diffs.append(d / ((h * 0.4 / 4) * (w / 4)))
		prev = img
	diffs.sort()
	print("FLOOR frame diff median=%.4f max=%.4f" % [diffs[diffs.size() / 2], diffs.back()])
	check(diffs.back() < 0.004, "floor doesn't swim when you move a little (max frame diff %.4f)" % diffs.back())
	await done(lvl)
	Game.retro = false
	HD.apply_look()

# Standing still in the real game screen (VHS overlay on, calm): the floor should be still too.
func t_still_screen() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(5.0).timeout   # banner gone
	main.show_screen("")
	get_tree().paused = false
	for n in main.level.npcs:
		n.set_physics_process(false)
	main.level.lights[0].visible = true
	main.level.set_process(false)   # (no dying-tube flicker / scares: only the screen effect counts)
	var pl = main.level.player
	pl.cam.rotation.x = -0.5
	await pframes(10)
	var prev: Image = null
	var diffs := []
	for i in 12:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_L8)
		var w := img.get_width()
		var h := img.get_height()
		if prev:
			var d := 0.0
			for y in range(int(h * 0.55), int(h * 0.85), 3):
				for x in range(0, w, 3):
					d += absf(img.get_pixel(x, y).r - prev.get_pixel(x, y).r)
			diffs.append(d / ((h * 0.3 / 3) * (w / 3)))
		prev = img
	diffs.sort()
	print("STILL frame diff median=%.4f max=%.4f" % [diffs[diffs.size() / 2], diffs.back()])
	check(diffs.back() < 0.004, "standing still, calm: the screen is still (max frame diff %.4f)" % diffs.back())
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()


# Fire stairs: right calls count up, a wrong one resets, every anomaly applies and cleans up,
# the last right call opens the door at the end.
func t_loop() -> void:
	var i := idx("stage_stairs")
	Game.new_game()
	Game.stage = i
	var lvl := stage_scene(i)
	add_child(lvl)
	await frames(10)
	var loop: Node = lvl.get_node("Loop")
	var fwd: Area3D = loop.get_node("Forward")
	var back: Area3D = loop.get_node("Back")
	check(loop.anomaly == "" and loop.counter.text.contains("0 / 8"), "stairs: first time round is normal, counter at 0")
	var walk_in := func(a: Area3D) -> void:
		Game.player.global_position = Vector3(20, 0, 5)   # off the landing first, like walking the corridor
		await pframes(3)   # process frames: loop.gd notices he left on _process (slow renderers batch physics frames)
		Game.player.global_position = a.global_position - Vector3.UP
		await get_tree().create_timer(0.8).timeout
	await walk_in.call(fwd)
	check(Game.goal_count == 1 and Game.player.global_position.distance_to(lvl.spawn) < 0.5, "stairs: nothing wrong + went on = right, back at the start")
	loop._round(true)
	loop.anomaly = "red"
	loop._apply("red")
	check(lvl.lights.all(func(l): return l.light_color.g < 0.2), "stairs: red anomaly tints the lights")
	await walk_in.call(back)
	check(Game.goal_count == 2 and lvl.lights.all(func(l): return l.light_color.g > 0.5), "stairs: something wrong + turned back = right, corridor back to normal")
	loop._round(true)
	await walk_in.call(back)
	check(Game.goal_count == 0, "stairs: nothing wrong but turned back = wrong, back to 0")
	var before := lvl.get_child_count()
	for a in loop.ANOMALIES:
		loop._round(true)
		loop.anomaly = a
		loop._apply(a)
		await frames(2)
	loop._round(true)
	await frames(3)
	check(lvl.get_child_count() <= before + 2, "stairs: every anomaly applies and is cleaned up (%d -> %d nodes)" % [before, lvl.get_child_count()])
	var door: Node3D = loop._door_at(loop.cfg().door_a)
	var door_col := func() -> bool: return door.find_children("*", "CollisionShape3D", false, false).any(func(c): return not c.disabled)
	loop.anomaly = "door"
	loop._apply("door")
	var open_ok: bool = door != null and not door.visible and not door_col.call()
	loop._round(true)
	check(open_ok and door.visible and door_col.call(), "stairs: the open door can be walked through, and closes again")
	loop._round(true)
	loop.anomaly = "staff_end"
	loop._apply("staff_end")
	await shot("stairs_anomaly.png")
	loop._round(true)
	Game.goal_count = loop.laps - 1
	await walk_in.call(fwd)
	check(lvl.exit_open and Game.goal_count == loop.laps, "stairs: the last right call opens the exit")
	await done(lvl)

# HR: the PA call. Out in the open when it ends = she comes for you; hidden = she doesn't know.
func t_hr() -> void:
	var lvl := await make(["###########", "#P...H....#", "#.........#", "#.......I.#", "###########"], 1)
	var hr: Npc = lvl.npcs[0]
	check(hr is Hr, "HR builds from 'I'")
	hr.view = 0.5   # can't see: only the PA call can give Tong away
	hr.call_t = 0.0
	await frames(3)
	check(hr.calling > 0.0, "HR: PA call starts")
	await get_tree().create_timer(hr.warn_secs + 0.4).timeout
	check(hr.state == "chase", "HR: still in the open when the call ends -> she comes")
	await done(lvl)
	lvl = await make(["###########", "#P...H....#", "#.........#", "#.......I.#", "###########"], 1)
	hr = lvl.npcs[0]
	hr.view = 0.5
	hr.call_t = 0.0
	await frames(3)
	lvl.player.hide_in(kinds(lvl, "hide")[0])
	await get_tree().create_timer(hr.warn_secs + 0.4).timeout
	check(hr.state != "chase", "HR: hidden in time -> she doesn't know where you are")
	await done(lvl)

# Hospital: running pounds the heart, holding your breath in a hide spot calms it, and a pounding
# heart in range brings the doctor.
func t_heart() -> void:
	var lvl := await make(["#################", "#P..............#", "#...............#", "#H............U.#", "#################"], 1, {"heartbeat": true})
	var doc: Npc = lvl.npcs[0]
	check(doc is Doctor, "doctor builds from 'U'")
	doc.set_physics_process(false)
	Game.heart = 30.0
	lvl.player.rotation.y = -PI / 2   # facing down the room (+x)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await get_tree().create_timer(1.4).timeout
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(Game.heart > 60.0, "heart: sprinting makes it pound (%.0f)" % Game.heart)
	lvl.player.hide_in(kinds(lvl, "hide")[0])
	Input.action_press("breath")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("breath")
	check(Game.heart < 45.0, "heart: holding your breath in a hide spot calms it (%.0f)" % Game.heart)
	lvl.player.unhide()
	doc.set_physics_process(true)
	Game.heart = 95.0
	doc.global_position = lvl.player.global_position + Vector3(8, 0, 0)
	doc.listen_t = 0.0
	await frames(3)
	check(doc.state == "chase", "heart: pounding within earshot -> the doctor comes")
	await done(lvl)

# The new scare kinds run and clean up after themselves; "face" slams a face on screen.
func t_new_scares() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	main._debug_start(0)
	await get_tree().create_timer(0.8).timeout
	main.show_screen("")
	var lvl: Node3D = main.level
	for n in lvl.npcs:
		n.set_physics_process(false)
	var count := lvl.get_child_count()
	lvl.scare({"kind": "face", "preset": "manager"})
	await frames(2)
	check(main.scare_face.visible, "face scare: their face slams on screen")
	await get_tree().create_timer(0.8).timeout
	check(not main.scare_face.visible, "face scare: and it's gone again")
	lvl.scare({"kind": "rush", "preset": "staff"})
	await frames(2)
	check(lvl.get_child_count() == count + 1, "rush scare: someone appears ahead")
	await get_tree().create_timer(3.5).timeout
	check(lvl.get_child_count() <= count, "rush scare: gone after reaching you")
	lvl.scare({"kind": "crawl", "preset": "goblin"})
	lvl.scare({"kind": "peek", "preset": "manager_long", "secs": 0.5})
	await get_tree().create_timer(2.0).timeout
	check(lvl.get_child_count() <= count + 1, "crawl + peek scares clean up")
	main.stop_play()
	main.queue_free()
	await frames(2)
	Game.new_game()

# Mid-stage cutscenes: brewing ป้าพร's coffee plays the chase scene, Tong ends up down the room and
# the chase is on; flipping the breaker plays เต้'s scene.
func t_mid_scenes() -> void:
	Game.skip_cutscenes = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)
	Game.new_game()
	Game.stage = idx("stage_2")
	main._story_seen.append(Game.stage)
	main.start_stage()
	await get_tree().create_timer(3.0).timeout
	Game.skip_cutscene.emit()   # past the intro
	await get_tree().create_timer(1.0).timeout
	var lvl: Node3D = main.level
	var coffee = kinds(lvl, "coffee_goal")[0]
	lvl.player.global_position = coffee.global_position + Vector3(1.2, -1.0, 0)
	coffee.interact()
	await get_tree().create_timer(1.5).timeout
	check(Game.in_cutscene, "coffee: the chase cutscene plays")
	await get_tree().create_timer(14.0).timeout
	check(not Game.in_cutscene and lvl.raging, "coffee: after it the chase is on")
	check(lvl.player.global_position.x > 15.0, "coffee: Tong ran off down the room (warp)")
	main.stop_play()
	await frames(2)
	Game.new_game()
	Game.stage = idx("stage_3")
	main._story_seen.append(Game.stage)
	main.start_stage()
	await get_tree().create_timer(3.0).timeout
	Game.skip_cutscene.emit()
	await get_tree().create_timer(1.0).timeout
	lvl = main.level
	var br = kinds(lvl, "breaker")[0]
	lvl.player.global_position = br.global_position + Vector3(-1.2, -1.2, 0)
	br.interact()
	await get_tree().create_timer(1.5).timeout
	check(Game.in_cutscene, "breaker: เต้'s cutscene plays")
	Game.skip_cutscene.emit()
	await get_tree().create_timer(0.5).timeout
	check(not Game.in_cutscene and not lvl.dark, "breaker: skipping it returns control, lights on")
	var ran_to := Cutscene.cell(Vector3(27.6, 0, 11.6))
	check(Vector2(lvl.player.global_position.x - ran_to.x, lvl.player.global_position.z - ran_to.z).length() < 0.5
		and lvl.npcs[0].global_position.distance_to(Cutscene.cell(Vector3(24.5, 0, 14.6))) < 3.0,   # (he is already moving again)
		"breaker: skipped, Tong and เต้ still end up where the scene leaves them")
	main.queue_free()
	await frames(2)
	Game.skip_cutscenes = true
	Game.new_game()
