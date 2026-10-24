# Scene flow + all UI: menu, HUD, pause, game over, endings.
# 3D renders in a SubViewport at 1/3 res (PSX look); UI stays sharp for Thai text.
extends Control

const YELLOW := Color(1.0, 0.82, 0.2)
const RED := Color(0.9, 0.15, 0.15)

const ENDINGS := {
	"A": ["A · GOOD END", "กลับบ้านสบายใจ", "guard",
		"ต๋องเดินออกจากตึกพร้อมมือถือของพี่สมชาย...\nในนั้นมีรูปแอบถ่ายต๋องอยู่หลายร้อยรูป\n\nต๋องกดโทรแจ้งตำรวจทันที\nคืนนั้นเขาหลับสบายเป็นครั้งแรกในรอบปี\n\n...วันจันทร์ต้องกลับไปทำงานอีกแล้วสินะ"],
	"B": ["B · DREAM END", "ทุกอย่างเป็นแค่ฝัน", "manager",
		"ต๋องลืมตาขึ้นมาที่โรงพยาบาล\nหมอบอกว่าเขาหมดสติเพราะทำงานหนักเกินไป\n\nหันซ้าย... คุณหมอยิ้มให้\nหันขวา... หัวหน้าธนายื่นหน้ามาพร้อมรอยยิ้มค้าง\n\n\"งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ?\""],
	"C": ["C · BAD END", "มีคนตามกลับบ้าน", "guard",
		"ต๋องถึงห้องพักตอนตีสอง ล็อกประตูแล้วถอนหายใจโล่งอก\n\nก๊อก... ก๊อก... ก๊อก...\n\"ข้าวมันไก่ครับ... ซื้อมาฝาก\"\n\nต๋องไม่เคยบอกใครเลยว่าบ้านอยู่ที่ไหน\n\n(คำใบ้: รับสายโทรศัพท์ที่ดัง มองหาพี่สมชายที่ยืนอยู่ไกลๆ อ่านโน้ตที่พูดถึงเขา\nแล้วขโมยมือถือเขามาแจ้งตำรวจ — หรือเก็บของแปลกๆ ที่ไม่ควรอยู่ในออฟฟิศให้ครบ — หรือทำทั้งสองอย่าง...)"],
	"D": ["D · TRUE END", "ตื่นแล้ว", "tong",
		"ต๋องลืมตาขึ้นที่โรงพยาบาล เตียง 4 ห้อง 7 — ของจริง\nเขาหมดสติที่โต๊ะทำงานมาสามวัน\n\nก่อนหมดสติ เขากดโทรแจ้งตำรวจไว้ทัน\nพี่สมชายถูกจับที่ทางเดินหน้าห้องพักผู้ป่วย\n\nข้อความสุดท้ายที่ต๋องส่งถึงบริษัท:\n\"ผมขอลาออกครับ\""],
}

var view: SubViewport
var level: Node3D
var playing := false
var ambience: AudioStreamPlayer

var hud: Control
var battery_bar: ProgressBar
var battery_fill: StyleBoxFlat
var objective: Label
var subtitle: Label
var prompt: Label
var banner: Label
var crosshair: Label
var fade: ColorRect
var status: Control      # HUD widgets hidden during cutscenes
var bars: Array[ColorRect] = []
var skip_hint: Label     # "hold Space to skip" in the top letterbox bar
var skip_fill: ColorRect
var stamina_bar: ColorRect
var hide_view: Control
var phone: Panel
var phone_head: Label
var phone_app := ""   # "" = app picker, "chat", "gps", "docs"
var phone_home: VBoxContainer
var phone_chat: VBoxContainer
var phone_tabs: HBoxContainer
var phone_list: VBoxContainer
var phone_gps: Control
var phone_docs: VBoxContainer
var phone_scroll: ScrollContainer
var phone_foot: Label
var _seen := {}          # thread -> messages already shown: the phone opens at the first new one
var lock_hint: Label     # "read your phone" while Game.phone_lock holds Tong still
var phone_thread := ""
var phone_hint: Label
var toast: Label
var unread := 0
var stage_time := 0.0
var heartbeat: AudioStreamPlayer
var drone: AudioStreamPlayer
var card: Label
var continue_btn: Button
var _load_id := 0   # bumps per start_stage(); stale overlapping calls bail out
var _story_seen: Array[int] = []   # stages whose black-screen story already played (-1 = tutorial)
var _was_captured := false
var fps_label: Label
var flash_rect: ColorRect
var chase_loop: AudioStreamPlayer
var screens := {}
var over_cause: Label
var end_labels := {}
var _sub_t := 0.0
var scare_face: FaceView
var hud_face: FaceView
var _scaring := false   # death jumpscare playing
const SCARE_POS := Vector2(120, 0)
const DEBUG_PASS := "1234"
var debug_pw: LineEdit
var debug_err: Label
var debug_list: VBoxContainer
var debug_lock: Array = []   # password box + confirm: hidden once unlocked
var screen_fx: ShaderMaterial   # VHS / hallucination post-process on the 3D view
var note_panel: PanelContainer
var note_labels := {}
var _note_at := Vector3.ZERO     # note closes once you walk away from where you read it
var keypad: PanelContainer
var keypad_edit: LineEdit
var _keypad_pc: Node
var skip_tut_btn: Button
var tut_hint: Label
var beacons: Control   # on-screen markers: what a note revealed, the exit, the tutorial step
var peephole: TextureRect   # door-viewer vignette (cutscene "peephole" step)
var heart_label: Label      # heart rate (stages with "heartbeat": the doctor hears it)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font_size = 22
	_build_world()
	_build_hud()
	_build_screens()
	ambience = AudioStreamPlayer.new()
	ambience.stream = Game.looped("ambience")
	ambience.volume_db = -8
	ambience.bus = "Amb"
	add_child(ambience)
	drone = AudioStreamPlayer.new()   # dark bed under the fluorescent buzz
	drone.stream = Game.looped("drone")
	drone.bus = "Amb"
	drone.volume_db = -12
	add_child(drone)
	heartbeat = AudioStreamPlayer.new()
	heartbeat.stream = Game.looped("heartbeat")
	heartbeat.bus = "Tension"
	heartbeat.volume_db = -60
	add_child(heartbeat)
	chase_loop = AudioStreamPlayer.new()
	chase_loop.stream = Game.looped("breathing")   # being hunted: Tong's own panicked breathing
	chase_loop.bus = "Tension"
	chase_loop.volume_db = -60
	add_child(chase_loop)
	Game.battery_changed.connect(_on_battery)
	Game.message.connect(_on_message)
	Game.objective_changed.connect(func(t): objective.text = t)
	Game.caught.connect(_on_caught)
	Game.game_over.connect(_on_game_over)
	Game.stage_cleared.connect(_on_stage_cleared)
	Game.cutscene_changed.connect(_on_cutscene)
	Game.hidden_changed.connect(_on_hidden)
	Game.phone_message.connect(_on_phone_message)
	Game.story_event.connect(_on_story_event)
	Game.flash.connect(_on_flash)
	Game.note_opened.connect(_on_note)
	Game.code_requested.connect(_on_code_requested)
	Game.scare_face.connect(_face_slam)
	Game.fade.connect(func(a, secs): _fade_to(a, secs))
	Game.overlay.connect(func(kind): peephole.visible = kind == "peephole")
	show_screen("menu")

# ---------- flow ----------
func start_game() -> void:
	Game.new_game()
	_seen.clear()
	Game.tutorial = true   # stage 0 first; skippable from the pause menu
	start_stage()

func skip_tutorial() -> void:
	get_tree().paused = false
	Game.tutorial = false
	Game.stage = 0
	Game.times_caught = 0   # practice catches don't count
	Game.reset_stage()
	start_stage()

# Every entry (start, retry, continue, next stage) comes through here. It awaits the clock
# card, so a second call during that wait must win and the first must bail out; otherwise
# both build a level and two coworkers roam the same map.
func start_stage() -> void:
	_load_id += 1
	var my_load := _load_id
	show_screen("")   # hide menu/game-over now: their buttons stayed clickable under the card
	_clear_scare()
	for c in view.get_children():
		c.queue_free()
	level = null
	if not Game.skip_cutscenes:   # clock card: time is running out
		hud.hide()
		fade.color.a = 1.0
		var key := -1 if Game.tutorial else Game.stage
		if not key in _story_seen:   # story text on black, once per stage per session (not on retry)
			_story_seen.append(key)
			card.add_theme_font_size_override("font_size", 28)
			for line in Game.stage_data().get("story", []):
				card.text = line
				card.modulate.a = 0.0
				card.show()
				create_tween().tween_property(card, "modulate:a", 1.0, 0.6)
				await _story_wait(2.0 + line.length() * 0.05)
				if my_load != _load_id:
					break
			card.add_theme_font_size_override("font_size", 44)
			card.modulate.a = 1.0
			if my_load != _load_id:
				return
		card.text = "%s\n\n%s" % [Game.stage_data().get("clock", ""), Game.stage_data().title]
		card.show()
		if not Game.tutorial:   # stage 0 opens on an ordinary afternoon
			Game.sfx("heartbeat", null, -6.0)
		await get_tree().create_timer(2.4).timeout
		if my_load != _load_id:
			return
		card.hide()
	level = load(Game.scene_path()).instantiate()
	tut_hint.visible = Game.tutorial
	view.add_child(level)
	Game.save_progress()
	Game.busy = false
	playing = true
	get_tree().paused = false
	show_screen("")
	hud.show()
	objective.text = Game.objective_text()
	_on_battery(Game.battery)
	ambience.play()
	drone.play()
	heartbeat.play()
	chase_loop.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade_to(0.0, 0.8)
	stage_time = 0.0
	close_phone()
	note_panel.hide()
	_close_keypad()
	for t in Game.stage_data().get("texts", []):   # [delay, thread, msg] scheduled phone texts
		get_tree().create_timer(t[0], false).timeout.connect(func(): if playing: Game.text(t[1], t[2]))
	await Cutscene.new().play(level, Game.stage_data().get("intro", []))
	if my_load != _load_id:
		return
	if is_instance_valid(level):
		for n in level.npcs:   # coworkers were posed for the intro: back to their posts
			n.reset()
	banner.text = Game.stage_data().title
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 1.5).set_delay(2.5)

# Waits secs; E / Space jumps to the next line early.
func _story_wait(secs: float) -> void:
	var t := 0.0
	await get_tree().process_frame
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("breath"):
			return

func stop_play() -> void:
	playing = false
	hud.hide()
	ambience.stop()
	drone.stop()
	heartbeat.stop()
	chase_loop.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_id += 1   # cancel a start_stage() still waiting on its clock card (or a jumpscare)
	_clear_scare()
	bars[0].position.y = -90.0   # an ending keeps its letterbox until here
	bars[1].position.y = 720.0
	status.show()
	peephole.hide()
	for c in view.get_children():
		c.queue_free()
	level = null

func _on_caught(npc: Node) -> void:
	var my_load := _load_id
	level.player.frozen = true
	close_phone()
	_scaring = true
	await _jumpscare(npc as Npc)   # ends on a black screen
	_scaring = false
	if my_load != _load_id or Game.battery <= 0.0:   # retried/quit, or game over takes it from here
		return
	await get_tree().create_timer(0.8).timeout   # black, ears ringing (scare_ring)
	if my_load != _load_id:
		return
	level.respawn()
	_scare_quiet(false)
	level.player.frozen = false
	Game.busy = false
	_fade_to(0.0, 0.6)

# Death jumpscare: the camera whips onto the coworker, they do their own lunge (Npc.jumpscare),
# then their face slams full screen and it hard-cuts to black.
func _jumpscare(npc: Npc) -> void:
	var p = level.player
	p.unhide()   # found in a hide spot: the door gets yanked open
	npc.mark.text = ""
	status.hide()   # nothing between you and them
	banner.modulate.a = 0.0
	var cam: Camera3D = p.cam
	_scare_quiet(true)   # the office hum, heartbeat and breathing cut out: dead silence, then...
	_scare_sound("scare_grab", 0.0)   # ...a heavy thud the instant they grab you
	var dur: float = npc.jumpscare(p)
	get_tree().create_timer(maxf(dur - 0.3, 0.0)).timeout.connect(func():   # swell lands on the slam
		if _scaring:
			_scare_sound("scare_riser", -3.0))
	var t := 0.0
	while t < dur:
		if not is_instance_valid(npc) or not is_instance_valid(p):
			return
		var dt := get_process_delta_time()
		var d: Vector3 = npc.scare_target() - cam.global_position
		var w := minf(dt * 30.0, 1.0)   # near-instant whip round
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-d.x, -d.z), w)
		cam.rotation.x = lerpf(cam.rotation.x, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4), w)
		var shake := 0.01 + 0.04 * t / dur   # trembling builds up
		cam.h_offset = randf_range(-shake, shake)
		cam.v_offset = randf_range(-shake, shake)
		await get_tree().process_frame
		t += dt
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	scare_face.set_preset(npc.body.preset)   # their real 3D head, rushing into the lens
	scare_face.scale = Vector2.ONE * 0.4
	scare_face.zoom = 1.0
	scare_face.shake = 1.0
	scare_face.show()
	flash_rect.color = npc.scare_color
	_scare_sound("scare_slam", 2.0)   # sub-bass impact + monster scream doubled down low
	_scare_sound("gasp", -4.0)
	if npc.scare_sfx != "":   # their own voice, dragged down into something that isn't human
		_scare_sound(npc.scare_sfx, 2.0, 0.68)
		_scare_sound(npc.scare_sfx, -2.0)
	var z := create_tween()
	z.tween_property(scare_face, "scale", Vector2.ONE * 1.4, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	z.tween_property(scare_face, "scale", Vector2.ONE * 1.55, 0.35)
	z.parallel().tween_property(scare_face, "zoom", 3.2, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	z.parallel().tween_property(flash_rect, "color", npc.scare_color.darkened(0.7), 0.35)
	t = 0.0
	while t < 0.4:   # shake only; no strobing
		scare_face.position = SCARE_POS + Vector2(randf_range(-22, 22), randf_range(-22, 22))
		await get_tree().process_frame
		t += get_process_delta_time()
	fade.color.a = 1.0
	_scare_sound("scare_ring", -6.0)   # ears ringing in the black
	_clear_scare(true)   # stays silent until play resumes (_on_caught)

# Non-lethal face slam (cutscene "scare" step, "face" scares): their head rushes into the lens with a
# scream and is gone again. Nothing else happens.
func _face_slam(preset: String, sfx_name := "") -> void:
	if _scaring:
		return
	scare_face.set_preset(preset)
	scare_face.scale = Vector2.ONE * 0.4
	scare_face.zoom = 1.0
	scare_face.shake = 1.0
	scare_face.position = SCARE_POS
	scare_face.show()
	flash_rect.color = Color(0.35, 0.02, 0.02, 0.85)
	_scare_sound("scare_slam", 0.0)
	_scare_sound("gasp", -6.0)
	if sfx_name != "":
		_scare_sound(sfx_name, 0.0, 0.7)
	var z := create_tween()
	z.tween_property(scare_face, "scale", Vector2.ONE * 1.4, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	z.parallel().tween_property(scare_face, "zoom", 2.6, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	z.tween_callback(func():
		if not _scaring:
			scare_face.hide()
			scare_face.scale = Vector2.ONE
		flash_rect.color = Color(0, 0, 0, 0))
	var t := 0.0
	while t < 0.5 and scare_face.visible:
		scare_face.position = SCARE_POS + Vector2(randf_range(-18, 18), randf_range(-18, 18))
		await get_tree().process_frame
		t += get_process_delta_time()
	scare_face.position = SCARE_POS

# Jumpscare audio goes straight to Master: dry (no office reverb), never muffled by a hide spot.
func _scare_sound(sfx_name: String, db: float, pitch := 1.0) -> void:
	Game.sfx(sfx_name, null, db + Npc.SCARE_DB, pitch).bus = "Master"

# Ambience + tension layers off for the scare (the silence before the hit), back on after.
func _scare_quiet(on: bool) -> void:
	for b in ["Amb", "Tension"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), on)

func _clear_scare(keep_quiet := false) -> void:
	_scare_quiet(keep_quiet)
	_scaring = false
	status.show()
	scare_face.hide()
	scare_face.position = SCARE_POS
	flash_rect.color = Color(0, 0, 0, 0)

func _on_game_over(cause: String) -> void:
	var my_load := _load_id
	var scared := _scaring   # a catch: caught fired first and its jumpscare is running
	while _scaring:
		await get_tree().process_frame
	await get_tree().create_timer(0.8 if scared else 1.6).timeout
	if my_load != _load_id:
		return
	stop_play()
	over_cause.text = cause
	show_screen("over")
	fade.color.a = 0.0

func _on_stage_cleared() -> void:
	level.player.frozen = true
	await _fade_to(1.0, 1.0)
	if Game.tutorial:   # training done: the real night starts
		skip_tutorial()
	elif Game.is_last_stage():
		stop_play()
		var id := Game.ending()
		Game.clear_save()
		await _ending_scene(id)
		_show_ending(id)
		fade.color.a = 0.0
	else:
		Game.stage += 1
		Game.goal_count = 0
		start_stage()

# Short 3D vignette before the ending card.
func _ending_scene(id: String) -> void:
	if Game.skip_cutscenes:
		return
	level = load("res://scenes/endings/ending_%s.tscn" % id).instantiate()
	view.add_child(level)
	var data: Dictionary = level.data
	hud.show()
	ambience.play()
	_fade_to(0.0, 1.0)
	await Cutscene.new().play(level, data.steps)
	await _fade_to(1.0, 1.0)
	stop_play()

func _on_flash(kind: String) -> void:
	var colors: Array = {"hospital": [Color(0.9, 1.0, 1.0, 0.85)], "holy": [Color(0.55, 0.8, 1.0, 0.5)], "rage": [Color(0.8, 0.0, 0.0, 0.55)], "police": [Color(1, 0.1, 0.1, 0.5), Color(0.1, 0.2, 1, 0.5)], "pa": [Color(0.6, 0.0, 0.05, 0.25), Color(0, 0, 0, 0), Color(0.6, 0.0, 0.05, 0.25)]}.get(kind, [Color.WHITE])
	var t := create_tween()
	for c in colors:
		t.tween_property(flash_rect, "color", c, 0.05)
		t.tween_interval(0.2)
	t.tween_property(flash_rect, "color", Color(0, 0, 0, 0), 0.4)

func _show_ending(id: String) -> void:
	var e: Array = ENDINGS[id]
	end_labels.letter.text = e[0]
	end_labels.title.text = e[1]
	end_labels.face.set_preset(e[2])
	end_labels.body.text = e[3]
	end_labels.stats.text = "โดนจับ %d ครั้ง  ·  หลักฐานเรื่องพี่สมชาย %d (ต้องมี %d)  ·  เบาะแสความฝัน %d/%d  ·  มือถือพี่สมชาย: %s" % [
		Game.times_caught, Game.hints, Game.EVIDENCE_NEEDED, Game.clues.size(), Game.CLUE_TOTAL, "ขโมยมา" if Game.phone_taken else "ไม่ได้แตะ"]
	show_screen("ending")

func _fade_to(a: float, secs: float) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", a, secs)
	await t.finished

func _unhandled_input(e: InputEvent) -> void:
	if not playing:
		return
	if Game.in_cutscene or _scaring:
		return
	if keypad.visible:
		if e.is_action_pressed("pause"):
			_close_keypad()
			get_viewport().set_input_as_handled()
		return
	if note_panel.visible and (e.is_action_pressed("pause") or e.is_action_pressed("phone")):
		note_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("fps"):   # F3: show frame rate (check 60 fps in the browser)
		fps_label.visible = not fps_label.visible
		return
	if phone.visible and phone_app != "" and not Game.phone_lock and e.is_action_pressed("pause"):   # back to the app picker (a text he must read: Esc closes)
		_show_app("")
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("phone") or (phone.visible and e.is_action_pressed("pause")):
		if phone.visible:
			close_phone()
		else:
			open_phone()
		get_viewport().set_input_as_handled()
		return
	if phone.visible and phone_app == "":
		var app := ""
		if e.is_action_pressed("phone_app_1"):
			app = "chat"
		elif e.is_action_pressed("phone_app_2"):
			app = "gps"
		elif e.is_action_pressed("phone_app_3"):
			app = "docs"
		if app != "":
			_show_app(app)
			get_viewport().set_input_as_handled()
			return
	if e.is_action_pressed("pause"):
		var p := not get_tree().paused
		get_tree().paused = p
		show_screen("pause" if p else "")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("mouse") and not get_tree().paused and not phone.visible:   # M: let the mouse go / lock it again
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_was_captured = false   # on purpose: not the lost capture _watch_capture pauses for
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and not get_tree().paused and not phone.visible:
		# A click always locks it. Off first: if the window never really took the lock (the mode already
		# says captured), setting captured again would do nothing and the mouse would stay loose.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func clock_text() -> String:
	if Game.clock != "":   # tutorial: the afternoon runs on into the night
		return Game.clock
	var start: String = Game.stage_data().get("clock", "23:47")
	if "?" in start:   # the dream: no time there
		return start
	var mins := int(start.get_slice(":", 0)) * 60 + int(start.get_slice(":", 1)) + int(stage_time / 10.0)
	return "%02d:%02d" % [(mins / 60) % 24, mins % 60]

func open_phone() -> void:
	phone.show()
	Game.event.emit("phone")
	unread = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_app("chat" if Game.phone_lock else "")   # the app picker, unless a text is holding Tong still: straight to it

# "" = app picker, "chat" = the thread view, "gps" = compass to the nearest objective.
func _show_app(app: String) -> void:
	phone_app = app
	phone_home.visible = app == ""
	phone_chat.visible = app == "chat"
	phone_gps.visible = app == "gps"
	phone_docs.visible = app == "docs"
	phone_docs.get_parent().visible = app == "docs"   # its ScrollContainer: left showing, it took half the phone from the chat
	Game.sfx("metalClick", null, -14.0)
	if app == "chat":
		var first: String = Game.threads.keys()[0] if not Game.threads.is_empty() else ""
		_show_thread(phone_thread if phone_thread != "" else first)
	elif app == "docs":
		_show_docs()

func close_phone() -> void:
	if phone and phone.visible:
		phone.hide()
		Game.phone_lock = false   # he's read it
		Game.event.emit("phone_read")
		if playing and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_thread(t: String, live := false) -> void:
	phone_thread = t
	for c in phone_tabs.get_children():
		c.queue_free()
	for tname in Game.threads.keys():
		var b := Button.new()
		b.text = tname
		b.add_theme_font_size_override("font_size", 14)
		b.toggle_mode = true
		b.button_pressed = tname == t
		b.pressed.connect(_show_thread.bind(tname))
		phone_tabs.add_child(b)
	for c in phone_list.get_children():
		c.queue_free()
	for m in Game.threads.get(t, []):
		var l := _label(m.text, 16, Color(0.1, 0.1, 0.12))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_constant_override("outline_size", 0)
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.8, 0.8) if t == "เบอร์ไม่รู้จัก" else Color(0.85, 0.95, 0.8)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		bubble.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		bubble.add_child(v)
		if m.img:
			var tr := TextureRect.new()
			tr.texture = m.img
			tr.custom_minimum_size = Vector2(240, 180)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			v.add_child(tr)
		v.add_child(l)
		phone_list.add_child(bubble)
	_scroll_to_new(9999 if live else _seen.get(t, 0))   # one arriving while he reads: show it
	_seen[t] = Game.threads.get(t, []).size()

# Put message i (the first one not read yet) at the top of the phone; all read = the newest.
func _scroll_to_new(i: int) -> void:
	await get_tree().process_frame   # the old bubbles are freed and the new ones laid out by then
	await get_tree().process_frame
	var bubbles := phone_list.get_children()
	phone_scroll.scroll_vertical = int(bubbles[i].position.y) if i < bubbles.size() else int(phone_scroll.get_v_scroll_bar().max_value)

# Every note/post-it read so far (Game.read_log) - they get taken off the wall once read, so
# this is the only place to double-check a password you forgot.
func _show_docs() -> void:
	for c in phone_docs.get_children():
		c.queue_free()
	if Game.read_log.is_empty():
		_label("ยังไม่ได้อ่านอะไรเลย", 14, Color(0.6, 0.6, 0.65), phone_docs)
		return
	for entry in Game.read_log:
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.88, 0.8)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		bubble.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		bubble.add_child(v)
		var title_l := _label(entry.title, 15, Color(0.3, 0.05, 0.05), v)
		title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_l.add_theme_constant_override("outline_size", 0)
		var body_l := _label(entry.text, 14, Color(0.1, 0.1, 0.12), v)
		body_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body_l.add_theme_constant_override("outline_size", 0)
		phone_docs.add_child(bubble)

func _on_phone_message(thread: String, m: Dictionary) -> void:
	if phone.visible and phone_app == "chat":
		_show_thread(phone_thread if phone_thread != "" else thread, true)
		return
	unread += 1
	phone_thread = thread   # the phone opens on whoever just texted
	toast.text = "ข้อความใหม่ · %s: %s" % [thread, "(รูปภาพ)" if m.img else m.text]
	toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(toast, "modulate:a", 0.0, 0.8)

func _on_story_event(t: Dictionary) -> void:
	if t.get("photo", false) and is_instance_valid(level):
		var img: Texture2D = await level.snapshot()
		Game.sfx("metalClick")   # shutter
		Game.text(t.text[0], t.text[1], img)
	elif t.has("text"):
		Game.text(t.text[0], t.text[1])

# Each beacon (stage.gd _marker) on screen: a pointer + name + distance above the thing, or, when
# it's out of view, an arrow on the screen edge pointing the way (if the beacon allows it).
func _draw_beacons() -> void:
	if not is_instance_valid(Game.player) or Game.player.hidden:
		return
	var cam: Camera3D = Game.player.cam
	var k := Vector2(960, 720) / Vector2(view.size)   # 3D renders at 1/3 res
	var font := get_theme_default_font()
	var centre := Vector2(480, 360)
	var inner := Rect2(60, 90, 840, 560)
	for m: Node3D in get_tree().get_nodes_in_group("beacon"):
		if not m.is_inside_tree():
			continue
		var col: Color = m.get_meta("color")
		var label: String = m.get_meta("label")
		var wp := m.global_position
		var dist := cam.global_position.distance_to(wp)
		var behind := cam.is_position_behind(wp)
		var sp := cam.unproject_position(wp) * k
		var bob := sin(Time.get_ticks_msec() * 0.006) * 5.0
		var text := "%s  %d ม." % [label, roundi(dist)]
		if not behind and inner.has_point(sp):
			var tip := sp + Vector2(0, -8 + bob)
			beacons.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -20), tip + Vector2(12, -20)]), col)
			_beacon_text(beacons, font, text, tip + Vector2(0, -26), col)
		elif m.get_meta("edge"):
			var d := (sp - centre) * (-1.0 if behind else 1.0)
			if d.length() < 1.0:
				d = Vector2.DOWN
			d = d.normalized()
			var t := minf(absf((inner.size.x / 2) / d.x) if d.x != 0.0 else INF, absf((inner.size.y / 2) / d.y) if d.y != 0.0 else INF)
			var p := centre + d * t
			var side := d.orthogonal()
			beacons.draw_colored_polygon(PackedVector2Array([p + d * 22, p - d * 8 + side * 16, p - d * 8 - side * 16]), col)
			_beacon_text(beacons, font, text, p - d * 40, col)

func _beacon_text(canvas: CanvasItem, font: Font, text: String, at: Vector2, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
	var pos := at - Vector2(w / 2, 0)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color.BLACK)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

# GPS app: a compass needle rotated to your bearing toward the nearest unfinished objective
# (or the exit, once it's open) - "up" is straight ahead, so turn until it points up.
func _draw_gps() -> void:
	var c := phone_gps.size / 2.0
	var r := minf(c.x, c.y) - 14.0
	var font := get_theme_default_font()
	phone_gps.draw_arc(c, r, 0.0, TAU, 48, Color(0.3, 0.9, 0.45, 0.5), 2.0)
	phone_gps.draw_circle(c, 4.0, Color(0.3, 0.9, 0.45))
	var t := _gps_target()
	if t.is_empty():
		_beacon_text(phone_gps, font, "ไม่มีเป้าหมายตอนนี้", c + Vector2(0, r + 30), Color(0.6, 0.6, 0.65))
		return
	var fwd := -Game.player.global_basis.z
	var to: Vector3 = t.pos - Game.player.global_position
	var bearing := Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))
	var dir := Vector2(0, -1).rotated(bearing)
	var side := dir.orthogonal()
	var tip := c + dir * r
	phone_gps.draw_colored_polygon(PackedVector2Array([tip, c + dir * (r - 26) + side * 12, c + dir * (r - 26) - side * 12]), Color(0.3, 0.9, 0.45))
	var dist := Game.player.global_position.distance_to(t.pos)
	_beacon_text(phone_gps, font, "%s  ·  %d ม." % [t.label, roundi(dist)], c + Vector2(0, r + 30), Color(0.85, 0.95, 0.85))

# Nearest item still needed (or the exit once unlocked) - what the GPS app points to.
func _gps_target() -> Dictionary:
	if not is_instance_valid(level) or not is_instance_valid(Game.player):
		return {}
	if level.exit_open:
		var trig := level.get_node_or_null("Exit/Trigger")
		if trig:
			return {"pos": trig.global_position, "label": "ทางออก"}
	var items := level.get_node_or_null("Items")
	if not items:
		return {}
	var best: Node3D = null
	var best_d := INF
	for it in items.get_children():
		if it.get("used") != false or not level.GOAL_NAMES.has(it.kind):
			continue
		if it.kind == "pc" and (Game.goal_count < 3 or level.dark):
			continue   # not actually usable yet: notes (and the breaker) come first
		if (it.kind == "fuse_box" and not Game.has_fuse) or (it.kind == "scanner" and not level.scanner_powered()):
			continue   # fuse first, then the panel, then the scanner
		var d: float = it.global_position.distance_to(Game.player.global_position)
		if d < best_d:
			best_d = d
			best = it
	if best:
		return {"pos": best.global_position, "label": level.goal_name(best)}
	return {}

# Note reader: the paper's text + what reading it gave you. Walk away (or Esc/Tab) to close.
func _on_note(title: String, body: String, tip: String) -> void:
	note_labels.title.text = title
	note_labels.body.text = body
	note_labels.tip.text = tip
	note_labels.tip.visible = tip != ""
	banner.modulate.a = 0.0   # the stage title would sit on top of the text
	note_panel.show()
	if is_instance_valid(Game.player):
		_note_at = Game.player.global_position

# PC keypad: Tong types the code from the post-its. The world keeps moving while you type.
func _on_code_requested(pc: Node) -> void:
	_keypad_pc = pc
	keypad_edit.text = ""
	keypad.show()
	Game.player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	keypad_edit.grab_focus.call_deferred()

func _submit_code(typed: String) -> void:
	if is_instance_valid(_keypad_pc):
		Game.submit_code(_keypad_pc, typed)
	_close_keypad()

func _close_keypad() -> void:
	if not keypad or not keypad.visible:
		return
	keypad.hide()
	keypad_edit.release_focus()
	_keypad_pc = null
	if is_instance_valid(Game.player):
		Game.player.frozen = false
	if playing and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# 0..1: how badly Tong is losing it. Low Social Battery, plus a spike while hunted.
func fear() -> float:
	return clampf((60.0 - Game.battery) / 60.0, 0.0, 1.0) * 0.85 + tension().y * 0.15

# Heartbeat swells as the nearest coworker closes in; a chase loop fades in while hunted.
func tension() -> Vector2:
	var d := INF
	var hunted := false
	if is_instance_valid(level) and is_instance_valid(Game.player):
		for n in level.npcs:
			d = minf(d, n.global_position.distance_to(Game.player.global_position))
			hunted = hunted or n.state in ["chase", "search"]
	var close := clampf(1.0 - (d - 2.0) / 12.0, 0.0, 1.0)
	return Vector2(close, 1.0 if hunted else 0.0)

func _process(dt: float) -> void:
	_watch_capture()
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if playing:
		var t := tension()
		var listening: bool = is_instance_valid(level) and level.data.get("heartbeat", false)
		heart_label.visible = listening
		if listening:   # the doctor's stage: you hear (and see) your own heart, the way he does
			var bpm := 60 + int(Game.heart)
			heart_label.text = "♥ %d BPM%s" % [bpm, "  — เขาได้ยิน!" if Game.heart > 65.0 else ""]
			heart_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25) if Game.heart > 65.0 else Color(1, 0.7, 0.7))
			heartbeat.volume_db = lerpf(heartbeat.volume_db, lerpf(-24.0, 2.0, Game.heart / 100.0), dt * 3.0)
			heartbeat.pitch_scale = 0.8 + Game.heart / 100.0 * 0.9
		else:
			heartbeat.volume_db = lerpf(heartbeat.volume_db, lerpf(-40.0, 0.0, t.x) if t.x > 0.0 else -60.0, dt * 3.0)
			heartbeat.pitch_scale = 1.0 + 0.4 * t.y
		chase_loop.volume_db = lerpf(chase_loop.volume_db, -4.0 if t.y > 0.0 else -60.0, dt * 2.0)
		drone.volume_db = lerpf(-60.0, -12.0, level.gloom if is_instance_valid(level) else 1.0)   # no dread by daylight (tutorial)
		var f: float = screen_fx.get_shader_parameter("fear")
		screen_fx.set_shader_parameter("fear", lerpf(f, fear(), dt * 2.0))
		beacons.queue_redraw()
		hud_face.shake = fear()
		if note_panel.visible and is_instance_valid(Game.player) and Game.player.global_position.distance_to(_note_at) > 1.2:
			note_panel.hide()
	if playing and not Game.in_cutscene:
		stage_time += dt
	var held := Game.skip_hold / Game.SKIP_HOLD
	skip_fill.size.x = 160.0 * held
	skip_hint.modulate.a = 0.55 + 0.45 * held
	lock_hint.visible = playing and Game.phone_lock and not phone.visible and not get_tree().paused
	lock_hint.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	if phone.visible:
		phone_head.text = "%s        แบต %d%%" % [clock_text(), int(Game.phone_battery)]
		if Game.typing:
			phone_foot.text = "กำลังพิมพ์" + ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
		elif phone_app == "":
			phone_foot.text = "[1] แชท   [2] GPS   [3] เอกสาร   [Esc] ปิด"
		else:
			phone_foot.text = "[Esc] ปิด" if Game.phone_lock else "[Esc] กลับ   [Tab] ปิด"
		if phone_app == "gps":
			phone_gps.queue_redraw()
	var badge := (" (%d ใหม่)" % unread) if unread > 0 else ""
	phone_hint.text = "[Tab] มือถือ%s   [F] ไฟฉาย   [M] ปล่อยเมาส์   %s" % [badge, clock_text()]
	if playing and not get_tree().paused and not phone.visible and not keypad.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		phone_hint.text = "คลิกที่จอ หรือกด [M] เพื่อล็อกเมาส์   %s" % clock_text()
	if _sub_t > 0.0:
		_sub_t -= dt
		if _sub_t <= 0.0:
			subtitle.text = ""
	if playing and is_instance_valid(Game.player):
		var f: Node = Game.player.focus()
		prompt.text = f.prompt() if f else ""
		crosshair.modulate = YELLOW if f else Color(1, 1, 1, 0.5)
		stamina_bar.size.x = 240.0 * Game.player.stamina / 100.0
		if prompt.text == "" and Game.player.held:
			prompt.text = "[Q / คลิกขวา] ขว้างของล่อ"
		if Game.player.hidden:
			prompt.text = "[E] ออกมา  ·  [Space ค้าง] กลั้นหายใจ" + ("  (กำลังกลั้น...)" if Game.player.holding_breath else "")

func _on_hidden(kind: String) -> void:
	for c in hide_view.get_children():
		c.queue_free()
	var rects: Array = {   # [x, y, w, h] black shapes around what you can see
		"locker": [[0, 0, 960, 250], [0, 470, 960, 250], [0, 250, 60, 220], [900, 250, 60, 220],
			[0, 318, 960, 26], [0, 396, 960, 26]],
		"desk": [[0, 0, 960, 200], [0, 620, 960, 100], [0, 200, 90, 420], [870, 200, 90, 420]],
		"stall": [[0, 0, 330, 720], [630, 0, 330, 720], [330, 0, 300, 90]],
	}.get(kind, [])
	for r in rects:
		var c := ColorRect.new()
		c.color = Color(0.01, 0.01, 0.01, 0.97)
		c.position = Vector2(r[0], r[1])
		c.size = Vector2(r[2], r[3])
		c.mouse_filter = MOUSE_FILTER_IGNORE
		hide_view.add_child(c)

func _on_cutscene(on: bool) -> void:
	if not on and not playing:   # an ending vignette: keep the letterbox and no HUD until it has faded out
		return
	if on:   # a mid-stage scene can start while he's reading something
		close_phone()
		note_panel.hide()
		_close_keypad()
	status.visible = not on
	var t := create_tween().set_parallel()
	t.tween_property(bars[0], "position:y", 0.0 if on else -90.0, 0.4)
	t.tween_property(bars[1], "position:y", 630.0 if on else 720.0, 0.4)

func _on_battery(v: float) -> void:
	battery_bar.value = v
	battery_fill.bg_color = Color(0.3, 0.85, 0.35) if v > 60 else (YELLOW if v > 30 else RED)

func _on_message(text: String, secs: float) -> void:
	subtitle.text = text
	_sub_t = secs

func show_screen(sname: String) -> void:
	for k in screens:
		screens[k].visible = k == sname
	if sname == "menu":
		continue_btn.visible = Game.has_save()
	elif sname == "pause":
		skip_tut_btn.visible = Game.tutorial
	elif sname == "debug":   # locked again every time you come back
		debug_pw.text = ""
		debug_err.text = ""
		debug_list.hide()
		for c in debug_lock:
			c.show()
		debug_pw.grab_focus.call_deferred()

func _debug_unlock() -> void:
	if debug_pw.text != DEBUG_PASS:
		debug_err.text = "รหัสผ่านไม่ถูกต้อง"
		debug_pw.text = ""
		return
	debug_err.text = ""
	for c in debug_lock:
		c.hide()
	debug_list.show()

func _debug_start(i: int) -> void:
	Game.new_game()
	Game.stage = i
	start_stage()

func continue_game() -> void:
	if Game.load_progress():
		start_stage()

# ---------- building UI ----------
func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = 3
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.process_mode = Node.PROCESS_MODE_PAUSABLE   # pause menu freezes the world
	screen_fx = ShaderMaterial.new()
	screen_fx.shader = preload("res://shaders/vhs.gdshader")
	screen_fx.set_shader_parameter("fear", 0.0)
	box.material = screen_fx
	add_child(box)
	view = SubViewport.new()
	view.audio_listener_enable_3d = true
	box.add_child(view)

func _label(text: String, size := 22, color := Color.WHITE, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent:
		parent.add_child(l)
	return l

func _button(text: String, cb: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.14)
	sb.border_color = YELLOW
	sb.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = Color(0.35, 0.1, 0.1)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_color_override("font_color", YELLOW)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(PRESET_FULL_RECT)
	hud.mouse_filter = MOUSE_FILTER_IGNORE
	hud.hide()
	add_child(hud)
	for top in [true, false]:   # cutscene letterbox
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(960, 90)
		bar.position = Vector2(0, -90 if top else 720)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		hud.add_child(bar)
		bars.append(bar)
	skip_hint = _label("กด [Space] ค้างไว้เพื่อข้าม", 15, Color(0.75, 0.75, 0.8), bars[0])   # slides in with the bar
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.position = Vector2(560, 26)
	skip_hint.size = Vector2(384, 24)
	var skip_back := ColorRect.new()
	skip_back.color = Color(0.25, 0.25, 0.28)
	skip_back.position = Vector2(784, 56)
	skip_back.size = Vector2(160, 5)
	bars[0].add_child(skip_back)
	skip_fill = ColorRect.new()
	skip_fill.color = YELLOW
	skip_fill.size = Vector2(0, 5)
	skip_back.add_child(skip_fill)
	status = Control.new()
	status.set_anchors_preset(PRESET_FULL_RECT)
	status.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(status)
	hud_face = FaceView.new("tong", 64)   # Tong's own head; trembles as Social Battery drains
	hud_face.position = Vector2(16, 16)
	hud_face.size = Vector2(64, 64)
	hud_face.turn = 0.12
	status.add_child(hud_face)
	var cap := _label("SOCIAL BATTERY", 16, YELLOW, status)
	cap.position = Vector2(92, 14)
	cap.size = Vector2(240, 26)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	battery_bar = ProgressBar.new()
	battery_bar.position = Vector2(92, 44)
	battery_bar.size = Vector2(240, 26)
	battery_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	bg.border_color = Color.WHITE
	bg.set_border_width_all(2)
	battery_fill = StyleBoxFlat.new()
	battery_bar.add_theme_stylebox_override("background", bg)
	battery_bar.add_theme_stylebox_override("fill", battery_fill)
	status.add_child(battery_bar)
	var sback := ColorRect.new()   # thin stamina bar (ProgressBar enforces a text-height minimum)
	sback.color = Color(0.05, 0.05, 0.05, 0.8)
	sback.position = Vector2(92, 76)
	sback.size = Vector2(240, 6)
	status.add_child(sback)
	stamina_bar = ColorRect.new()
	stamina_bar.color = Color(0.4, 0.7, 1.0)
	stamina_bar.position = sback.position
	stamina_bar.size = sback.size
	status.add_child(stamina_bar)
	heart_label = _label("", 18, Color(1, 0.6, 0.6), status)
	heart_label.position = Vector2(92, 86)
	heart_label.size = Vector2(240, 26)
	heart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	beacons = Control.new()
	beacons.set_anchors_preset(PRESET_FULL_RECT)
	beacons.mouse_filter = MOUSE_FILTER_IGNORE
	beacons.draw.connect(_draw_beacons)
	status.add_child(beacons)
	hide_view = Control.new()   # peek-slit overlay, filled per hide type
	hide_view.set_anchors_preset(PRESET_FULL_RECT)
	hide_view.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(hide_view)
	hud.move_child(hide_view, 0)
	phone_hint = _label("", 16, Color(0.8, 0.85, 1.0), status)
	phone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phone_hint.position = Vector2(560, 680)
	phone_hint.size = Vector2(384, 30)
	toast = _label("", 18, Color(0.8, 1.0, 0.8), hud)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.position = Vector2(380, 80)
	toast.size = Vector2(564, 60)
	toast.modulate.a = 0.0
	phone = Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.08, 0.1)
	psb.border_color = Color(0.3, 0.3, 0.35)
	psb.set_border_width_all(6)
	psb.set_corner_radius_all(24)
	phone.add_theme_stylebox_override("panel", psb)
	phone.position = Vector2(680, 160)
	phone.size = Vector2(260, 420)
	phone.hide()
	hud.add_child(phone)
	var pv := VBoxContainer.new()
	pv.position = Vector2(14, 14)
	pv.size = Vector2(232, 392)
	phone.add_child(pv)
	phone_head = _label("", 13, Color.WHITE, pv)
	phone_home = VBoxContainer.new()
	phone_home.add_theme_constant_override("separation", 10)
	phone_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(phone_home)
	_label("เลือกแอป", 13, Color(0.6, 0.6, 0.7), phone_home)
	var chat_btn := Button.new()
	chat_btn.text = "1  ·  แชท"
	chat_btn.add_theme_font_size_override("font_size", 20)
	chat_btn.pressed.connect(_show_app.bind("chat"))
	phone_home.add_child(chat_btn)
	var gps_btn := Button.new()
	gps_btn.text = "2  ·  GPS"
	gps_btn.add_theme_font_size_override("font_size", 20)
	gps_btn.pressed.connect(_show_app.bind("gps"))
	phone_home.add_child(gps_btn)
	var docs_btn := Button.new()
	docs_btn.text = "3  ·  เอกสาร"
	docs_btn.add_theme_font_size_override("font_size", 20)
	docs_btn.pressed.connect(_show_app.bind("docs"))
	phone_home.add_child(docs_btn)
	phone_chat = VBoxContainer.new()
	phone_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(phone_chat)
	phone_tabs = HBoxContainer.new()
	phone_chat.add_child(phone_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone_chat.add_child(scroll)
	phone_scroll = scroll
	phone_list = VBoxContainer.new()
	phone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_list.add_theme_constant_override("separation", 8)
	scroll.add_child(phone_list)
	phone_gps = Control.new()
	phone_gps.custom_minimum_size = Vector2(232, 340)
	phone_gps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phone_gps.draw.connect(_draw_gps)
	pv.add_child(phone_gps)
	var docs_scroll := ScrollContainer.new()
	docs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(docs_scroll)
	phone_docs = VBoxContainer.new()
	phone_docs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_docs.add_theme_constant_override("separation", 8)
	docs_scroll.add_child(phone_docs)
	phone_foot = _label("[Esc] ปิด", 12, Color(0.6, 0.6, 0.7), pv)
	note_panel = _paper(Vector2(200, 120), Vector2(560, 440))   # note reader
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 10)
	note_panel.add_child(nv)
	note_labels.title = _label("", 24, Color(0.35, 0.05, 0.05), nv)
	note_labels.body = _label("", 19, Color(0.12, 0.1, 0.1), nv)
	note_labels.body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note_labels.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_labels.tip = _label("", 17, Color(0.1, 0.35, 0.15), nv)
	_label("(เดินออก / Esc เพื่อปิด)", 13, Color(0.4, 0.4, 0.4), nv)
	for l in nv.get_children():
		l.add_theme_constant_override("outline_size", 0)
	keypad = _paper(Vector2(300, 220), Vector2(360, 230))   # PC login
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 12)
	keypad.add_child(kv)
	var kt := _label("ห้อง Admin · ใส่รหัสผ่าน", 22, Color(0.1, 0.1, 0.15), kv)
	kt.add_theme_constant_override("outline_size", 0)
	keypad_edit = LineEdit.new()
	keypad_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	keypad_edit.max_length = 8
	keypad_edit.custom_minimum_size = Vector2(200, 52)
	keypad_edit.add_theme_font_size_override("font_size", 30)
	keypad_edit.text_submitted.connect(_submit_code)
	kv.add_child(keypad_edit)
	var kh := _label("Enter = ยืนยัน · Esc = ยกเลิก\nรหัสผิด = เสียงเตือนดังลั่น!", 14, Color(0.4, 0.1, 0.1), kv)
	kh.add_theme_constant_override("outline_size", 0)
	tut_hint = _label("บทนำ · [Esc] แล้วกด \"ข้ามบทนำ\" เพื่อเริ่มด่าน 1 ทันที", 14, Color(0.7, 0.75, 0.9), status)
	tut_hint.position = Vector2(16, 690)
	tut_hint.size = Vector2(520, 24)
	tut_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tut_hint.hide()
	objective = _label("", 18, Color.WHITE, status)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.position = Vector2(360, 16)
	objective.size = Vector2(584, 60)
	subtitle = _label("", 22, Color(1, 1, 0.85), hud)
	subtitle.position = Vector2(60, 600)
	subtitle.size = Vector2(840, 100)
	prompt = _label("", 20, YELLOW, status)
	prompt.position = Vector2(280, 400)
	prompt.size = Vector2(400, 40)
	crosshair = _label("·", 32, Color.WHITE, status)
	crosshair.position = Vector2(460, 336)
	crosshair.size = Vector2(40, 40)
	lock_hint = _label("มีข้อความเข้า!\nกด [Tab] เปิดมือถืออ่าน", 30, YELLOW, hud)
	lock_hint.position = Vector2(180, 420)
	lock_hint.size = Vector2(600, 100)
	lock_hint.hide()
	banner = _label("", 40, YELLOW, hud)
	banner.position = Vector2(0, 220)
	banner.size = Vector2(960, 80)
	peephole = TextureRect.new()   # fish-eye door viewer: a round hole in the black
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.62, Color(0, 0, 0, 0.15))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	peephole.texture = gt
	peephole.stretch_mode = TextureRect.STRETCH_SCALE
	peephole.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peephole.position = Vector2(120, 0)
	peephole.size = Vector2(720, 720)
	peephole.mouse_filter = MOUSE_FILTER_IGNORE
	peephole.hide()
	hud.add_child(peephole)
	hud.move_child(peephole, 0)
	for r in [Rect2(0, 0, 120, 720), Rect2(840, 0, 120, 720)]:   # the sides beyond the round hole
		var side := ColorRect.new()
		side.color = Color.BLACK
		side.position = r.position
		side.size = r.size
		side.mouse_filter = MOUSE_FILTER_IGNORE
		peephole.add_child(side)
		side.position = r.position - peephole.position
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.set_anchors_preset(PRESET_FULL_RECT)
	flash_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	scare_face = FaceView.new("", 160)   # death jumpscare: the coworker's 3D head slammed full screen
	scare_face.position = SCARE_POS
	scare_face.size = Vector2(720, 720)
	scare_face.pivot_offset = Vector2(360, 360)
	scare_face.turn = 0.0
	scare_face.set_horror(true)
	scare_face.hide()
	add_child(scare_face)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(PRESET_FULL_RECT)
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fade)
	fps_label = _label("", 16, Color(0.6, 1, 0.6))
	fps_label.position = Vector2(8, 690)
	fps_label.size = Vector2(120, 24)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fps_label.hide()
	add_child(fps_label)
	card = _label("", 44, Color(0.9, 0.9, 0.9))
	card.set_anchors_preset(PRESET_FULL_RECT)
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.hide()
	add_child(card)

# Hidden off-white sheet on the HUD (note reader, keypad).
func _paper(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.91, 0.82)
	sb.border_color = Color(0.55, 0.5, 0.4)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.hide()
	hud.add_child(p)
	return p

func _screen(sname: String, bg := Color(0.04, 0.03, 0.06, 1.0)) -> VBoxContainer:
	var root := ColorRect.new()
	root.color = bg
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	var v := VBoxContainer.new()
	v.set_anchors_preset(PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	screens[sname] = root
	return v

# Live 3D head of a character (Story.BODIES preset) at px x px.
func _face(preset: String, parent: Node, px := 128) -> FaceView:
	var t := FaceView.new(preset, clampi(px, 64, 112))
	t.custom_minimum_size = Vector2(px, px)
	parent.add_child(t)
	return t

func _centered(n: Control) -> Control:
	n.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return n

func _build_screens() -> void:
	var m := _screen("menu")
	_label("SOCIAL BATTERY", 18, YELLOW, m)
	var faces := HBoxContainer.new()
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	faces.add_theme_constant_override("separation", 12)
	for f in ["manager", "sweeper", "tong", "goblin", "guard"]:
		_face(f, faces, 128 if f == "tong" else 88)
	m.add_child(faces)
	_label("Salary man:", 44, Color.WHITE, m)
	_label("NIGHTMARE", 72, RED, m)
	_label("Horror Comedy · Workplace Survival · Low-Poly PSX", 18, Color(0.7, 0.7, 0.8), m)
	_centered(_button("▶  เริ่มเกม", start_game, m)).grab_focus.call_deferred()
	continue_btn = _centered(_button("เล่นต่อ (ด่านล่าสุด)", continue_game, m))
	_centered(_button("ตั้งค่า", func(): show_screen("settings"), m))
	_centered(_button("Debug", func(): show_screen("debug"), m))
	if not OS.has_feature("web"):   # a web page can't close itself
		_centered(_button("ออกจากเกม", get_tree().quit, m))
	_label("WASD เดิน · Shift วิ่ง · C/Ctrl ก้ม · E เก็บ/ใช้/ซ่อน · Space กลั้นหายใจ · Q ขว้าง · Tab มือถือ · F ไฟฉาย · Esc หยุด", 15, Color(0.6, 0.6, 0.7), m)

	var st := _screen("settings")
	_label("ตั้งค่า", 44, YELLOW, st)
	for row in [["ความไวเมาส์", "sensitivity", 0.3, 2.0], ["ระดับเสียง", "volume", 0.0, 1.0]]:
		_label(row[0], 20, Color.WHITE, st)
		var sl := HSlider.new()
		sl.min_value = row[2]
		sl.max_value = row[3]
		sl.step = 0.05
		sl.value = Game.get(row[1])
		sl.custom_minimum_size = Vector2(360, 30)
		sl.value_changed.connect(func(v): Game.set(row[1], v); Game.save_settings())
		st.add_child(_centered(sl))
	var cb := CheckBox.new()
	cb.text = "ข้ามคัตซีน"
	cb.button_pressed = Game.skip_cutscenes
	cb.toggled.connect(func(on): Game.skip_cutscenes = on; Game.save_settings())
	st.add_child(_centered(cb))
	_centered(_button("กลับ", func(): show_screen("menu"), st))

	# Debug: password, then jump straight into any stage (for testing / demoing).
	var dbg := _screen("debug")
	_label("DEBUG MODE", 44, YELLOW, dbg)
	debug_pw = LineEdit.new()
	debug_pw.secret = true
	debug_pw.placeholder_text = "รหัสผ่าน"
	debug_pw.alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_pw.custom_minimum_size = Vector2(320, 48)
	debug_pw.text_submitted.connect(func(_t): _debug_unlock())
	dbg.add_child(_centered(debug_pw))
	debug_err = _label("", 18, RED, dbg)
	var ok := _centered(_button("ยืนยัน", _debug_unlock, dbg))
	debug_list = VBoxContainer.new()
	debug_list.add_theme_constant_override("separation", 10)
	debug_list.hide()
	dbg.add_child(_centered(debug_list))
	_label("เลือกด่าน", 20, Color.WHITE, debug_list)
	_button(Story.TUTORIAL.title, start_game, debug_list)
	for i in Game.STAGES.size():
		_button(Game.STAGES[i].title, _debug_start.bind(i), debug_list)
	debug_lock = [debug_pw, ok]
	_centered(_button("กลับ", func(): show_screen("menu"), dbg))

	var p := _screen("pause", Color(0, 0, 0, 0.7))
	_label("หยุดพัก...", 48, YELLOW, p)
	_centered(_button("เล่นต่อ", func(): _unhandled_input(_pause_event()), p))
	skip_tut_btn = _centered(_button("ข้ามบทนำ → ด่าน 1", skip_tutorial, p))
	_centered(_button("เมนูหลัก", func(): get_tree().paused = false; stop_play(); show_screen("menu"), p))

	var o := _screen("over", Color(0.08, 0.0, 0.0, 1.0))
	_centered(_face("tong", o, 140))
	_label("GAME OVER", 64, RED, o)
	_label("Social Battery = 0  ·  ล้มนอนตาลอยกลางออฟฟิศ", 22, Color.WHITE, o)
	over_cause = _label("", 22, YELLOW, o)
	_centered(_button("ลองใหม่ (ด่านนี้)", func(): Game.reset_stage(); start_stage(), o))
	_centered(_button("เมนูหลัก", func(): show_screen("menu"), o))

	var e := _screen("ending")
	end_labels.letter = _label("", 28, YELLOW, e)
	end_labels.title = _label("", 48, Color.WHITE, e)
	end_labels.face = _centered(_face("tong", e, 120))
	end_labels.body = _label("", 21, Color(0.9, 0.9, 0.9), e)
	end_labels.stats = _label("", 16, Color(0.6, 0.6, 0.7), e)
	_centered(_button("เมนูหลัก", func(): show_screen("menu"), e))
	show_screen("")

# Browsers release the mouse on Esc without passing the key to the game. If capture is lost
# mid-play, open the pause menu; its Resume click is the user gesture needed to lock again.
func _watch_capture() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and playing and not get_tree().paused 			and not phone.visible and not keypad.visible and not Game.in_cutscene and not Game.busy:
		_unhandled_input(_pause_event())
	_was_captured = captured

func _pause_event() -> InputEvent:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev
