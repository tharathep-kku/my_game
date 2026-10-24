# Perf probe: uncapped FPS + draw calls per stage through the real pipeline (run with the renderer to test).
#   Godot --rendering-method gl_compatibility --path . res://tests/perf_probe.tscn
extends Node

func _ready() -> void:
	Game.save_path = "user://test_save.cfg"
	Game.settings_path = "user://test_settings.cfg"
	Game.skip_cutscenes = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for i in 4:
		Game.new_game()
		Game.stage = i
		main.start_stage()
		await get_tree().create_timer(1.5).timeout
		if "--flashlight" in OS.get_cmdline_user_args():
			Game.player.flashlight.visible = true
		var f0 := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		var rot := 0.0
		var max_draws := 0
		var max_prims := 0
		var vpr: RID = main.view.get_viewport_rid()
		while Time.get_ticks_usec() - t0 < 3000000:   # spin the camera: worst-case views
			rot += 0.05
			Game.player.rotation.y = rot
			await get_tree().process_frame
			max_draws = maxi(max_draws, RenderingServer.viewport_get_render_info(vpr, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) 				+ RenderingServer.viewport_get_render_info(vpr, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			max_prims = maxi(max_prims, RenderingServer.viewport_get_render_info(vpr, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		var fps := (Engine.get_frames_drawn() - f0) / ((Time.get_ticks_usec() - t0) / 1e6)
		print("PERF stage %d  fps=%.0f  worst-frame draws=%d prims=%d" % [i + 1, fps, max_draws, max_prims])
	main.stop_play()
	Game.clear_save()
	get_tree().quit()
