# Scene flow + all UI: menu, HUD, phone, pause, the paperwork screens, endings.
# 3D renders in a SubViewport at 1/3 res (PSX look); UI stays sharp for Thai text.
# Look and feel (fonts, colours, styles, UI sounds): scripts/ui/kit.gd.
extends Control

const YELLOW := Color(1.0, 0.82, 0.2)
const RED := Color(0.9, 0.15, 0.15)

const VHS := preload("res://shaders/vhs.gdshader")     # retro look
const FILM := preload("res://shaders/film.gdshader")   # HD look
const ENDINGS := {
	"A": ["A · GOOD END", "กลับบ้านสบายใจ", "guard",
		"ต๋องเดินออกจากตึกพร้อมมือถือของพี่สมชาย...\nในนั้นมีรูปแอบถ่ายต๋องอยู่หลายร้อยรูป\n\nต๋องกดโทรแจ้งตำรวจทันที\nคืนนั้นเขาหลับสบายเป็นครั้งแรกในรอบปี\n\n...วันจันทร์ต้องกลับไปทำงานอีกแล้วสินะ"],
	"B": ["B · DREAM END", "ทุกอย่างเป็นแค่ฝัน", "manager",
		"ต๋องลืมตาขึ้นมาที่โรงพยาบาล\nหมอบอกว่าเขาหมดสติเพราะทำงานหนักเกินไป\n\nหันซ้าย... คุณหมอยิ้มให้\nหันขวา... หัวหน้าธนายื่นหน้ามาพร้อมรอยยิ้มค้าง\n\n\"งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ?\""],
	"C": ["C · BAD END", "มีคนตามกลับบ้าน", "guard",
		"ต๋องถึงห้องพักตอนตีสอง ล็อกประตูแล้วถอนหายใจโล่งอก\n\nก๊อก... ก๊อก... ก๊อก...\n\"ข้าวมันไก่ครับ... ซื้อมาฝาก\"\n\nต๋องไม่เคยบอกใครเลยว่าบ้านอยู่ที่ไหน"],
	"D": ["D · TRUE END", "ตื่นแล้ว", "tong",
		"ต๋องลืมตาขึ้นที่โรงพยาบาล เตียง 4 ห้อง 7 — ของจริง\nเขาหมดสติที่โต๊ะทำงานมาสามวัน\n\nก่อนหมดสติ เขากดโทรแจ้งตำรวจไว้ทัน\nพี่สมชายถูกจับที่ทางเดินหน้าห้องพักผู้ป่วย\n\nข้อความสุดท้ายที่ต๋องส่งถึงบริษัท:\n\"ผมขอลาออกครับ\""],
}
# ฝน's whole story found (her six jobs): what became of her, after each ending.
const EPILOGUES := {
	"A": "บทส่งท้าย · ฝน\nรูปที่ต๋องส่งให้แม่ ทำให้ตำรวจเปิดคดีของฝนอีกครั้ง\nหนึ่งเดือนต่อมา ฝนลืมตาขึ้นที่หอผู้ป่วย 5\nคำแรกที่เธอพูดคือ \"กาแฟ... อย่าดื่ม\"",
	"B": "บทส่งท้าย · ฝน\nต๋องตื่นมาพร้อมชื่อหนึ่งติดอยู่ในหัว: ฝน\nเขาไม่รู้ว่าเป็นใคร จนพยาบาลเข็นเตียงผ่านหน้าห้อง\nป้ายข้อมือเขียนว่า \"ฝน · หอผู้ป่วย 5\" — มีพวงกุญแจรูปแมวผูกอยู่ที่ราวเตียง",
	"C": "บทส่งท้าย · ฝน\nรูปหลักฐานถึงมือแม่แล้ว ตำรวจกำลังมา\n...แต่คนที่ยืนอยู่หน้าประตูห้องคืนนี้ ก็ได้อ่านข้อความนั้นเหมือนกัน",
	"D": "บทส่งท้าย · ฝน\nวันที่ตำรวจพาตัวสมชายไป ฝนก็ฟื้น\nสองคนที่ไม่เคยคุยกันเลยในชีวิตจริง จำกันได้ทันทีที่เจอหน้า\n\"เธอคือคนที่เปิดลิ้นชักให้ฉันใช่ไหม\"",
}
# How to get each ending: shown on its locked card (the gallery) and after a bad end.
const ENDING_HINTS := {
	"A": "ขโมยมือถือพี่สมชาย + หาหลักฐานเรื่องเขาให้ครบ 6 ชิ้น",
	"B": "เก็บของแปลกๆ ที่ไม่ควรอยู่ในออฟฟิศให้ครบทุกบท และอย่าแตะมือถือพี่สมชาย",
	"C": "แค่หนีออกมาให้ได้... ก็พอ",
	"D": "ทำทั้ง A และ B ในการเล่นรอบเดียว",
}
# Your boss's verdict on the performance review, by grade.
const BOSS_SAYS := {
	"S": "งานคืบหน้า 100% แล้วจ๊ะ! ...งั้นพรุ่งนี้มาเช้ากว่าเดิมนะ",
	"A": "ดีมากจ๊ะ ต๋อง ผมไว้ใจต๋องที่สุดเลย ^_^",
	"B": "ก็พอไหวนะจ๊ะ แต่เดี๋ยวเรามาคุยกันหน่อย... แค่ 3 ชั่วโมงเอง",
	"C": "งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ? ...ไม่ต้องตอบ ผมรู้แล้ว",
	"D": "ต๋องจ๊ะ... เราต้องคุยกันยาวๆ แล้วล่ะ",
}
const MENU_SCREENS := ["menu", "chapters", "archive", "gallery", "credits", "settings", "debug"]

var view: SubViewport
var level: Node3D
var playing := false
var ambience: AudioStreamPlayer
var menu_music: AudioStreamPlayer

var hud: Control
var battery_bar: ProgressBar
var battery_fill: StyleBoxFlat
var battery_pct: Label
var objective: Label
var objective_note: PanelContainer
var subtitle: RichTextLabel
var sub_panel: PanelContainer
var prompt: Label
var prompt_key: Label
var prompt_box: PanelContainer
var banner: Label
var crosshair: Control
var fade: ColorRect
var status: Control      # HUD widgets hidden during cutscenes
var bars: Array[ColorRect] = []
var skip_hint: Label     # "hold Space to skip" in the top letterbox bar
var skip_fill: ColorRect
var stamina_bar: ColorRect
var lamp_label: Label    # phone battery, shown while the flashlight is on (it drains it)
var vignette: TextureRect   # red edges when Social Battery runs low
var tip_panel: PanelContainer
var tip_label: Label
var _tips := {}          # first-time tips already shown this session
var hide_view: Control
var phone: Panel
var phone_head: Label
var phone_app := ""   # "" = home screen, "chat", "gps", "docs", "map"
var phone_home: VBoxContainer
var phone_clock: Label
var phone_chat: VBoxContainer
var phone_tabs: HBoxContainer
var phone_list: VBoxContainer
var phone_gps: Control
var phone_docs: VBoxContainer
var phone_map: PhoneMap
var phone_jobs: VBoxContainer   # app 5: jobs under way + the case file of finished ones
var side_label: Label           # HUD: the side job you're on, under the sticky note
var objective_head: Label       # "ภารกิจ" on the note (+ the key, folded)
var _obj_peek := 0.0            # seconds the folded note stays open after a change
var view_box: SubViewportContainer   # holds the 3D view: shrinks it to 320x240 in the retro look
var phone_scroll: ScrollContainer
var phone_foot: Label
var _seen := {}          # thread -> messages already shown: the phone opens at the first new one
var lock_hint: Label     # "read your phone" while Game.phone_lock holds Tong still
var phone_thread := ""
var phone_hint: Label
var toast: Label
var toast_panel: PanelContainer
var unread := 0
var stage_time := 0.0
var heartbeat: AudioStreamPlayer
var drone: AudioStreamPlayer
var card: Label
var card_fx: Control     # CCTV overlay around the chapter card (REC, camera, timestamp)
var card_chapter: Label
var card_osd: Label
var continue_btn: Button
var _load_id := 0   # bumps per start_stage(); stale overlapping calls bail out
var _story_seen: Array[int] = []   # stages whose black-screen story already played (-1 = tutorial)
var _was_captured := false
var fps_label: Label
var flash_rect: ColorRect
var chase_loop: AudioStreamPlayer
var chase_music: AudioStreamPlayer   # pounding loop while someone is after you
# Music states (_music): calm -> unease (something near you can't see) -> chase -> after (it has
# let you go: the dread dips, the unease stays away a while). And a sting the first time you see
# it in a chapter.
var unease: AudioStreamPlayer
var music_state := "calm"
var _after_t := 0.0
var _sighted := false
var _seen_t := 0.0
var _ghost_seen := false
var saved_label: Label
var over_tip: Label
# HR's advice at the bottom of the warning letter (one at random each time)
const TIPS := [
	"ได้ยินเสียงฝีเท้าใกล้ๆ ให้ก้ม (C) แล้วย่อง — ก้มแล้วไม่มีเสียงเท้าเลย",
	"ขว้างของ (Q) ไปอีกทาง ศัตรูจะเดินไปดูเสียง",
	"โดนไล่ไม่ต้องวิ่งไปตลอด: เลี้ยวหลบให้พ้นสายตาสัก 3 วินาที เขาจะเลิกตามแล้วถอยไปอีกฝั่ง",
	"เสียงฝีเท้าข้างหลังที่หยุดตอนคุณหยุด... หันไปดูก็ไม่มีอะไร มันทำร้ายคุณไม่ได้ เดินต่อไป",
	"โน้ตทุกใบมีประโยชน์: บอกทางเดินศัตรู ที่ซ่อน หรือของที่ต้องเก็บ",
	"กาแฟ = Social Battery +40 · พาวเวอร์แบงก์ = แบตมือถือ (ไฟฉาย)",
	"ในที่มืด ไฟฉายคือเป้าให้ศัตรูเห็นจากไกล ใช้เท่าที่จำเป็น",
	"ซ่อนอยู่แล้วมีคนมายืนข้างหน้า: กด Space ค้างกลั้นหายใจ",
	"มือถือ (Tab) → 4 แผนที่: ดูว่าเดินผ่านตรงไหนมาแล้ว · 2 GPS: ชี้ไปของที่ต้องเก็บ",
	"พี่สมชายขยับเฉพาะตอนที่ไม่มีใครมองเขา",
	"ป้าพรไม่เห็นคุณ แต่ถ้าเหยียบพื้นเปียกเมื่อไหร่ ป้ามาแน่",
	"เต้ซ่อนอยู่ใต้โต๊ะ เดินผ่านโต๊ะแบบก้มย่อง เขาจะไม่ทันจับขา",
	"พี่แหม่มประกาศชื่อเมื่อไหร่ ต้องซ่อนให้ทันก่อนประกาศจบ",
	"บันไดหนีไฟ: จำโปสเตอร์ นาฬิกา ประตู ต้นไม้ ไว้ให้ดี อะไรเปลี่ยน = เดินกลับ",
	"หมอฟังเสียงหัวใจ: อย่าวิ่งถ้าไม่จำเป็น ก้มย่องให้ใจเย็น",
	"เมนูตั้งค่ามีโหมดง่าย ถ้ายากเกินไป ไม่ผิดอะไรเลย",
]
var screens := {}
var over_cause: Label
var over_count: Label
var end_labels := {}
var review_labels := {}
var _review_done := false
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
var _map_t := 0.0
# main menu
var menu_bg: MenuBg
var title_ghosts: Array[Label] = []
var _glitch := 0.0
var badge_stats: Label
var menu_osd: Label
var _osd_secs := 0.0
var _credit_y := 0.0
var chapter_grid: GridContainer
var archive_list: VBoxContainer
var archive_title: Label
var archive_body: Label
var archive_count: Label
var gallery_row: HBoxContainer
var credits_scroll: ScrollContainer
var pause_info: RichTextLabel
var _settings_back := "menu"
var _settings_rows := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(PRESET_FULL_RECT)
	theme = Kit.theme()
	_build_world()
	_build_hud()
	_build_screens()
	ambience = AudioStreamPlayer.new()
	ambience.stream = Game.looped("ambience")
	ambience.volume_db = Game.mix_db("ambience")
	ambience.bus = "Amb"
	add_child(ambience)
	drone = AudioStreamPlayer.new()   # dark bed under the fluorescent buzz
	drone.stream = Game.looped("drone")
	drone.bus = "Amb"
	drone.volume_db = Game.mix_db("drone")
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
	chase_music = AudioStreamPlayer.new()
	chase_music.stream = Game.looped("chase_theme")
	chase_music.bus = "Tension"
	chase_music.volume_db = -60
	add_child(chase_music)
	unease = AudioStreamPlayer.new()
	unease.stream = Game.looped("unease")
	unease.bus = "Tension"
	unease.volume_db = -60
	add_child(unease)
	menu_music = AudioStreamPlayer.new()
	menu_music.stream = Game.looped("menu_theme")
	menu_music.bus = "Music"
	menu_music.volume_db = Game.mix_db("menu_theme")
	add_child(menu_music)
	Game.battery_changed.connect(_on_battery)
	Game.message.connect(_on_message)
	Game.objective_changed.connect(_on_objective)
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
	Game.quests_changed.connect(_on_quests)
	Game.fade.connect(func(a, secs): _fade_to(a, secs))
	Game.overlay.connect(func(kind): peephole.visible = kind == "peephole")
	apply_settings()
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
	if not Game.skip_cutscenes:   # chapter card: the CCTV feed of the next floor
		hud.hide()
		fade.color.a = 1.0
		card_chapter.text = "บทนำ" if Game.tutorial else "บทที่ %d / %d" % [Game.stage + 1, Game.STAGES.size()]
		card_osd.text = "CAM %02d · %s" % [(Game.stage + 1) * 3 + 1 if not Game.tutorial else 1, Game.stage_data().get("clock", "")]
		card_fx.show()
		var key := -1 if Game.tutorial else Game.stage
		if not key in _story_seen:   # story text on black, once per stage per session (not on retry)
			_story_seen.append(key)
			card.add_theme_font_size_override("font_size", 28)
			card.add_theme_font_override("font", Kit.BODY)
			for line in Game.stage_data().get("story", []):
				card.text = line
				card.show()
				_typewrite(card, line.length())
				await _story_wait(2.4 + line.length() * 0.05)
				if my_load != _load_id:
					break
			card.add_theme_font_size_override("font_size", 46)
			card.add_theme_font_override("font", Kit.TITLE)
			if my_load != _load_id:
				return
		card.text = "%s\n%s" % [Game.stage_data().get("clock", ""), Game.stage_data().title]
		card.show()
		_typewrite(card, card.text.length(), 0.03)
		if not Game.tutorial:   # stage 0 opens on an ordinary afternoon
			Game.sfx("heartbeat", null, -6.0)
		await get_tree().create_timer(2.6).timeout
		if my_load != _load_id:
			return
		card.hide()
		card_fx.hide()
	level = load(Game.scene_path()).instantiate()
	tut_hint.visible = Game.tutorial
	Game.begin_stage()   # before the level is in: its first texts belong to this try
	view.add_child(level)
	Game.save_progress()
	Game.busy = false
	playing = true
	get_tree().paused = false
	show_screen("")
	hud.show()
	objective.text = Game.objective_text()
	_obj_peek = 8.0   # the objective, open for a moment as the chapter starts
	_on_battery(Game.battery)
	ambience.play()
	drone.play()
	heartbeat.play()
	chase_loop.play()
	chase_music.play()
	unease.play()
	music_state = "calm"
	_after_t = 0.0
	_sighted = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade_to(0.0, 0.8)
	if not Game.tutorial:   # checkpoint: say so
		saved_label.modulate.a = 1.0
		create_tween().tween_property(saved_label, "modulate:a", 0.0, 1.0).set_delay(2.5)
	stage_time = 0.0
	phone_map.reset()
	_on_quests()
	close_phone()
	note_panel.hide()
	_close_keypad()
	for t in Game.stage_data().get("texts", []):   # [delay, thread, msg] scheduled phone texts
		get_tree().create_timer(t[0], false).timeout.connect(func(): if playing and my_load == _load_id: Game.text(t[1], t[2]))
	await Cutscene.new().play(level, Game.stage_data().get("intro", []))
	if my_load != _load_id:
		return
	if is_instance_valid(level):
		for n in level.npcs:   # coworkers were posed for the intro: back to their posts
			n.reset()
	banner.text = Game.stage_data().title
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 1.5).set_delay(2.5)
	if Game.tutorial:
		_tip("move", "เดิน WASD · วิ่ง Shift ค้าง · ก้มย่อง C · มองแล้วกด E เพื่อใช้ของ")

# The label types itself out, a clack per few letters.
func _typewrite(l: Label, chars: int, per := 0.035) -> void:
	l.visible_ratio = 0.0
	var secs := clampf(chars * per, 0.3, 2.2)
	var t := create_tween()
	t.tween_property(l, "visible_ratio", 1.0, secs)
	for i in int(secs / 0.09):
		get_tree().create_timer(i * 0.09).timeout.connect(func(): if l.visible and l.visible_ratio < 1.0: Kit.ui_sound("type", -16.0))

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
	chase_music.stop()
	unease.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_id += 1   # cancel a start_stage() still waiting on its clock card (or a jumpscare)
	_clear_scare()
	bars[0].position.y = -90.0   # an ending keeps its letterbox until here
	bars[1].position.y = 720.0
	status.show()
	peephole.hide()
	card.hide()
	card_fx.hide()
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
	_tip("caught", "โดนจับ = Social Battery ลด แล้วกลับไปจุดเช็คพอยต์ · หมดเมื่อไหร่ = Game Over · กาแฟช่วยเติมพลัง")

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
	_slam_fx(npc.scare_color, 0.45)
	_scare_sound("scare_slam", 2.0)   # sub-bass impact + monster scream doubled down low
	_scare_sound("gasp", -4.0)
	if npc.scare_sfx != "":   # their own voice, dragged down into something that isn't human
		_scare_sound(npc.scare_sfx, 2.0, 0.68)
		_scare_sound(npc.scare_sfx, -2.0)
	var z := create_tween()
	z.tween_property(scare_face, "scale", Vector2.ONE * 1.4, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	z.tween_property(scare_face, "scale", Vector2.ONE * 1.55, 0.35)
	z.parallel().tween_property(scare_face, "zoom", 3.2, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	z.parallel().tween_property(flash_rect, "color", npc.scare_color.darkened(0.7 if Game.retro else 0.9), 0.35)
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
	_slam_fx(Color(0.35, 0.02, 0.02), 0.5)
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

# HD look: the slam opens on a white flash that drops to near-black, the face lit from below in
# stutters, torn and grainy, settling as it goes. (Retro: the original red slam.)
func _slam_fx(tint: Color, secs: float) -> void:
	if Game.retro or scare_face.material == null:
		return
	flash_rect.color = Color(1, 1, 1, 0.9)
	var t := create_tween()
	t.tween_property(flash_rect, "color", Color(tint.darkened(0.88), 0.97), 0.07)
	scare_face.strobe = 1.0
	scare_face.material.set_shader_parameter("amount", 1.0)
	var k := create_tween()
	k.tween_method(func(v: float):
		scare_face.material.set_shader_parameter("amount", v)
		scare_face.strobe = v, 1.0, 0.25, secs)
	k.tween_callback(func(): scare_face.strobe = 0.0)

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
	over_tip.text = "คำแนะนำจาก HR: " + TIPS.pick_random()
	over_count.text = "%s\nโดนจับรวม %d ครั้ง · เวลาในบทนี้ %s" % [Game.stage_data().title, Game.times_caught, _mmss(stage_time)]
	show_screen("over")
	fade.color.a = 0.0
	_stamp(screens.over.get_meta("stamp"))

func _on_stage_cleared() -> void:
	level.player.frozen = true
	await _fade_to(1.0, 1.0)
	if Game.tutorial:   # training done: the real night starts
		skip_tutorial()
		return
	if not Game.skip_cutscenes:   # the performance review
		stop_play()   # before taking my_load: stop_play() bumps it
		var my_load := _load_id
		await _review()
		if my_load != _load_id:
			return
	if Game.is_last_stage():
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

# "ใบประเมินผลการปฏิบัติงาน": what this chapter took, a grade, a stamp, and what the boss thinks.
func _review() -> void:
	var found_clue: bool = Game.clues.has(Game.stage)
	var evidence := Game.hints - Game.stage_hints0
	var chapter_jobs := Game.all_quests().filter(func(e): return e.chapter == Game.stage)
	var jobs_done := chapter_jobs.filter(func(e): return Game.quest_done(e.q.id) and not e.q.get("main", false)).size()
	var side_jobs := chapter_jobs.filter(func(e): return not e.q.get("main", false)).size()
	var g := Game.grade_for(Game.stage_caught, stage_time, found_clue, evidence, jobs_done)
	Game.record_grade(g)
	review_labels.chapter.text = "บทที่ %d · %s" % [Game.stage + 1, Game.stage_data().title.get_slice(" : ", 1)]
	review_labels.rows.text = "เวลาที่ใช้\t%s\nโดนจับ\t%d ครั้ง\nหลักฐานเรื่องพี่สมชาย (บทนี้)\t+%d\nเบาะแสความฝัน\t%s\nเอกสารที่อ่าน\t%d%s" % [
		_mmss(stage_time), Game.stage_caught, evidence, "พบแล้ว" if found_clue else "ไม่พบ", Game.stage_reads,
		("\nงานเสริมที่ทำเสร็จ\t%d / %d" % [jobs_done, side_jobs]) if side_jobs > 0 else ""]
	review_labels.grade.text = g
	review_labels.boss.text = "หัวหน้าธนา: \"%s\"" % BOSS_SAYS[g]
	review_labels.best.text = "เกรดดีที่สุดของบทนี้: %s" % Game.grades.get(Game.stage, g)
	fade.color.a = 0.0
	show_screen("review")
	_review_done = false
	_stamp(review_labels.stamp)
	var t := 0.0
	while not _review_done and t < 30.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.8 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
			_review_done = true
	Kit.ui_sound("ui_click", -8.0)
	show_screen("")
	fade.color.a = 1.0

# A rubber stamp comes down: big and tilted, then slams to size with a thud and a shake.
func _stamp(s: Control) -> void:
	s.scale = Vector2.ONE * 2.6
	s.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.45)
	t.tween_property(s, "modulate:a", 1.0, 0.01)
	t.parallel().tween_property(s, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): Kit.ui_sound("stamp", -2.0))

func _mmss(secs: float) -> String:
	return "%02d:%02d" % [int(secs) / 60, int(secs) % 60]

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
	var first := Game.see_ending(id)
	end_labels.letter.text = e[0]
	end_labels.title.text = e[1]
	end_labels.face.set_preset(e[2])
	end_labels.body.text = e[3] + ("" if id != "C" else "\n\n(ยังมีทางจบอื่นอีก... ดูคำใบ้ได้ที่เมนู \"ฉากจบ\")")
	end_labels.epi.text = ""
	if Game.quest_done("fon_6"):   # her whole story: what became of her
		end_labels.epi.text = EPILOGUES[id]
	elif Game.quests.keys().any(func(k): return k.begins_with("fon_")):
		end_labels.epi.text = "เรื่องของฝนยังไม่จบ...\nทำงานของเธอให้ครบทั้ง 6 งาน (งานจาก \"เบอร์ไม่รู้จัก\") แล้วจะรู้ว่าเธอเป็นอย่างไร"
	end_labels.epi_box.visible = end_labels.epi.text != ""
	end_labels.new.visible = first
	end_labels.stats.text = "โดนจับ %d ครั้ง  ·  หลักฐานเรื่องพี่สมชาย %d/%d  ·  เบาะแสความฝัน %d/%d  ·  มือถือพี่สมชาย: %s" % [
		Game.times_caught, Game.hints, Game.EVIDENCE_NEEDED, Game.clues.size(), Game.CLUE_TOTAL, "ขโมยมา" if Game.phone_taken else "ไม่ได้แตะ"]
	_fill_gallery(end_labels.gallery, true, id)
	show_screen("ending")

func _fade_to(a: float, secs: float) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", a, secs)
	await t.finished

func _unhandled_input(e: InputEvent) -> void:
	if not playing:
		if e.is_action_pressed("pause") and screens.has("menu"):   # Esc backs out of the menu's sub-screens
			for s in ["chapters", "archive", "gallery", "credits", "debug"]:
				if screens[s].visible:
					show_screen("menu")
					get_viewport().set_input_as_handled()
					return
			if screens.settings.visible:
				show_screen(_settings_back)
				get_viewport().set_input_as_handled()
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
	if e.is_action_pressed("objective"):   # O: keep the objective note open / let it fold
		Game.objective_pin = not Game.objective_pin
		Game.save_settings()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("fps"):   # F3: show frame rate (check 60 fps in the browser)
		fps_label.visible = not fps_label.visible
		return
	if phone.visible and phone_app != "" and not Game.phone_lock and e.is_action_pressed("pause"):   # back to the home screen (a text he must read: Esc closes)
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
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_4:
			app = "map"
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_5:
			app = "jobs"
		if app != "":
			_show_app(app)
			get_viewport().set_input_as_handled()
			return
	if e.is_action_pressed("pause") and screens.settings.visible:   # settings opened from the pause menu
		show_screen("pause")
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

func _resume() -> void:
	get_tree().paused = false
	show_screen("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func clock_text() -> String:
	if Game.clock != "":   # tutorial: the afternoon runs on into the night
		return Game.clock
	var start: String = Game.stage_data().get("clock", "23:47")
	if "?" in start:   # the dream: no time there
		return start
	var mins := int(start.get_slice(":", 0)) * 60 + int(start.get_slice(":", 1)) + int(stage_time / 10.0)
	return "%02d:%02d" % [(mins / 60) % 24, mins % 60]

# ---------- phone ----------
func open_phone() -> void:
	phone.show()
	Game.event.emit("phone")
	unread = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	phone.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(phone, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_app("chat" if Game.phone_lock else "")   # the home screen, unless a text is holding Tong still: straight to it

# "" = home screen, "chat" = the thread view, "gps" = compass to the nearest objective,
# "docs" = everything read so far, "map" = the floor plan (where you have been).
func _show_app(app: String) -> void:
	phone_app = app
	phone_home.visible = app == ""
	phone_chat.visible = app == "chat"
	phone_gps.visible = app == "gps"
	phone_docs.visible = app == "docs"
	phone_docs.get_parent().visible = app == "docs"   # its ScrollContainer: left showing, it took half the phone from the chat
	phone_map.visible = app == "map"
	phone_jobs.get_parent().visible = app == "jobs"
	Game.sfx("metalClick", null, -14.0)
	if app == "chat":
		var first: String = Game.threads.keys()[0] if not Game.threads.is_empty() else ""
		_show_thread(phone_thread if phone_thread != "" else first)
	elif app == "docs":
		_show_docs()
	elif app == "jobs":
		_show_jobs()

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
		b.toggle_mode = true
		b.button_pressed = tname == t
		b.add_theme_font_size_override("font_size", 13)
		var on := Kit.box(Kit.speaker_color(tname).darkened(0.35), Color(0, 0, 0, 0), 0, 10, 6)
		var off := Kit.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 10, 6)
		b.add_theme_stylebox_override("normal", on if tname == t else off)
		b.add_theme_stylebox_override("hover", on)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("focus", off)
		b.pressed.connect(_show_thread.bind(tname))
		phone_tabs.add_child(b)
	for c in phone_list.get_children():
		c.queue_free()
	var col := Kit.speaker_color(t)
	for m in Game.threads.get(t, []):
		var row := HBoxContainer.new()   # one row per message: avatar + bubble (+ time under it)
		row.add_theme_constant_override("separation", 6)
		var av := Kit.panel(Kit.box(col.darkened(0.2), Color(1, 1, 1, 0.3), 1, 16, 0))
		av.custom_minimum_size = Vector2(30, 30)
		av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var ini := Kit.label("?" if t == "เบอร์ไม่รู้จัก" else t.left(1), 15, Kit.NIGHT, Kit.TITLE, av)
		ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(av)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 1)
		row.add_child(v)
		var bubble := Kit.panel(Kit.box(Color(0.42, 0.06, 0.1) if t == "เบอร์ไม่รู้จัก" else Color(0.18, 0.19, 0.24), Color(0, 0, 0, 0), 0, 12, 8))
		v.add_child(bubble)
		var bv := VBoxContainer.new()
		bubble.add_child(bv)
		if m.img:
			var tr := TextureRect.new()
			tr.texture = m.img
			tr.custom_minimum_size = Vector2(190, 140)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bv.add_child(tr)
		Kit.label(m.text, 15, Color(0.95, 0.95, 0.97), Kit.BODY, bv)
		Kit.label(m.get("time", ""), 11, Kit.DIM, Kit.UI, v)
		phone_list.add_child(row)
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
		Kit.label("ยังไม่ได้อ่านอะไรเลย", 14, Kit.DIM, Kit.UI, phone_docs)
		return
	for entry in Game.read_log:
		var bubble := Kit.panel(Kit.box(Kit.PAPER, Color(0, 0, 0, 0), 0, 8, 9))
		var v := VBoxContainer.new()
		bubble.add_child(v)
		Kit.label(entry.title, 15, Color(0.5, 0.08, 0.1), Kit.HAND, v)
		Kit.label(entry.text, 13, Kit.INK, Kit.BODY, v)
		phone_docs.add_child(bubble)

# Jobs app: the ones under way (what to do next), then the case file: what each finished job told
# you, in story order. ฝน's arc gets its own count.
func _show_jobs() -> void:
	for c in phone_jobs.get_children():
		c.queue_free()
	if Game.quests.is_empty():
		Kit.label("ยังไม่มีใครส่งงานมา\n(งานจะมาทางแชท ระหว่างเล่น)", 14, Kit.DIM, Kit.UI, phone_jobs)
		return
	var fon := Game.all_quests().filter(func(e): return e.q.id.begins_with("fon_"))
	var fon_done := fon.filter(func(e): return Game.quest_done(e.q.id)).size()
	if fon_done > 0:
		Kit.label("เรื่องของฝน  %d / %d" % [fon_done, fon.size()], 15, Color(1, 0.55, 0.65), Kit.TITLE, phone_jobs)
	var doing := Game.all_quests().filter(func(e): return Game.quests.has(e.q.id) and not Game.quest_done(e.q.id))
	if not doing.is_empty():
		Kit.label("กำลังทำ", 13, Kit.DIM, Kit.UI, phone_jobs)
	for e in doing:
		var b := Kit.panel(Kit.box(Color(0.32, 0.12, 0.42, 0.85), Color(0.78, 0.55, 1.0, 0.6), 1, 10, 9), phone_jobs)
		var v := VBoxContainer.new()
		b.add_child(v)
		Kit.label("%s%s · จาก %s" % ["★ " if e.q.get("main", false) else "", e.q.title, e.q.from], 14, Color.WHITE, Kit.TITLE, v)
		Kit.label("→ " + Game.quest_step(e.q.id).do, 13, Color(0.9, 0.85, 1.0), Kit.BODY, v)
	var done := Game.all_quests().filter(func(e): return Game.quest_done(e.q.id))
	if not done.is_empty():
		Kit.label("แฟ้มคดี (งานที่เสร็จแล้ว)", 13, Kit.DIM, Kit.UI, phone_jobs)
	for e in done:
		var b := Kit.panel(Kit.box(Kit.PAPER, Color(0, 0, 0, 0), 0, 8, 9), phone_jobs)
		var v := VBoxContainer.new()
		b.add_child(v)
		Kit.label("บทที่ %d · %s" % [e.chapter + 1, e.q.title], 14, Color(0.5, 0.08, 0.1), Kit.HAND, v)
		Kit.label(e.q.get("log", e.q.get("done", "")), 13, Kit.INK, Kit.BODY, v)

func _on_phone_message(thread: String, m: Dictionary) -> void:
	if phone.visible and phone_app == "chat":
		_show_thread(phone_thread if phone_thread != "" else thread, true)
		return
	unread += 1
	phone_thread = thread   # the phone opens on whoever just texted
	toast.text = "%s\n%s" % [thread, "(รูปภาพ)" if m.img else m.text]
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast_panel.position.y = -80.0
	toast_panel.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(toast_panel, "position:y", 12.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(3.5)
	t.tween_property(toast_panel, "modulate:a", 0.0, 0.6)

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
	var font := Kit.UI
	var centre := Vector2(480, 360)
	var inner := Rect2(60, 110, 840, 520)
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
			beacons.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-11, -18), tip + Vector2(11, -18)]), col)
			_beacon_text(beacons, font, text, tip + Vector2(0, -24), col)
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
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
	var pos := at - Vector2(w / 2, 0)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 6, Color.BLACK)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)

# GPS app: a compass needle rotated to your bearing toward the nearest unfinished objective
# (or the exit, once it's open) - "up" is straight ahead, so turn until it points up.
func _draw_gps() -> void:
	var c := phone_gps.size / 2.0 - Vector2(0, 16)
	var r := minf(c.x, c.y) - 18.0
	var font := Kit.UI
	for i in 3:
		phone_gps.draw_arc(c, r * (1.0 - i * 0.3), 0.0, TAU, 48, Color(0.3, 0.9, 0.45, 0.45 - i * 0.12), 2.0)
	phone_gps.draw_circle(c, 4.0, Color(0.3, 0.9, 0.45))
	var t := _gps_target()
	if t.is_empty():
		_beacon_text(phone_gps, font, "ไม่มีเป้าหมายตอนนี้", c + Vector2(0, r + 34), Color(0.6, 0.6, 0.65))
		return
	var fwd := -Game.player.global_basis.z
	var to: Vector3 = t.pos - Game.player.global_position
	var bearing := Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))
	var dir := Vector2(0, -1).rotated(bearing)
	var side := dir.orthogonal()
	var tip := c + dir * r
	phone_gps.draw_colored_polygon(PackedVector2Array([tip, c + dir * (r - 28) + side * 13, c + dir * (r - 28) - side * 13]), Color(0.3, 0.9, 0.45))
	var dist := Game.player.global_position.distance_to(t.pos)
	_beacon_text(phone_gps, font, t.label, c + Vector2(0, r + 30), Color(0.85, 0.95, 0.85))
	_beacon_text(phone_gps, font, "%d เมตร" % roundi(dist), c + Vector2(0, r + 52), Kit.DIM)

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
	var job: Node3D = null   # nothing else to do here: the nearest job step (a required job's, too)
	for it in items.get_children():
		if it.get("kind") == "quest" and not it.used:
			var d: float = it.global_position.distance_to(Game.player.global_position)
			if job == null or d < best_d:
				best_d = d
				job = it
	if job:
		return {"pos": job.global_position, "label": "งาน: " + job.title}
	return {}

# Note reader: the paper's text + what reading it gave you. Walk away (or Esc/Tab) to close.
func _on_note(title: String, body: String, tip: String) -> void:
	note_labels.title.text = title
	note_labels.body.text = body
	note_labels.tip.text = tip
	note_labels.tip.get_parent().visible = tip != ""
	banner.modulate.a = 0.0   # the stage title would sit on top of the text
	note_panel.show()
	note_panel.rotation = randf_range(-0.025, 0.025)
	note_panel.modulate.a = 0.0
	create_tween().tween_property(note_panel, "modulate:a", 1.0, 0.15)
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

func _music(dt: float, t: Vector2) -> void:
	_seen_t -= dt
	if _seen_t <= 0.0:
		_seen_t = 0.25
		_ghost_seen = _ghost_on_screen()
	if t.y > 0.0:
		music_state = "chase"
		_after_t = 7.0
	elif _after_t > 0.0:
		_after_t -= dt
		music_state = "after"
	elif t.x > 0.0 and not _ghost_seen and is_instance_valid(level) and level.gloom > 0.5:
		music_state = "unease"
	else:
		music_state = "calm"
	var on := music_state == "unease"
	unease.volume_db = lerpf(unease.volume_db, Game.mix_db("unease") if on else -60.0, dt * (0.5 if on else 1.2))
	if _ghost_seen and not _sighted and not Game.in_cutscene and level.gloom > 0.5:
		_sighted = true
		Game.sfx("sighting", null, -2.0)

# A ghost on screen: in view, not behind anything, near enough to make out.
func _ghost_on_screen() -> bool:
	if not is_instance_valid(level) or not is_instance_valid(Game.player):
		return false
	var cam: Camera3D = Game.player.cam
	var space: PhysicsDirectSpaceState3D = Game.player.get_world_3d().direct_space_state
	for n in level.npcs:
		var head: Vector3 = n.global_position + Vector3.UP * 1.4
		if head.distance_to(cam.global_position) < 18.0 and cam.is_position_in_frustum(head):
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, head, 1)).is_empty():
				return true
	return false

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
	_menu_tick(dt)
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	Game.hud_clock = clock_text() if playing else ""
	if playing:
		var t := tension()
		var listening: bool = is_instance_valid(level) and level.data.get("heartbeat", false)
		heart_label.visible = listening
		if listening:   # the doctor's stage: you hear (and see) your own heart, the way he does
			var bpm := 60 + int(Game.heart)
			heart_label.text = "♥ %d BPM%s" % [bpm, "  เขาได้ยิน!" if Game.heart > 65.0 else ""]
			heart_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25) if Game.heart > 65.0 else Color(1, 0.7, 0.7))
			heartbeat.volume_db = lerpf(heartbeat.volume_db, lerpf(-24.0, 2.0, Game.heart / 100.0) + Game.mix_db("heartbeat"), dt * 3.0)
			heartbeat.pitch_scale = 0.8 + Game.heart / 100.0 * 0.9
		else:
			heartbeat.volume_db = lerpf(heartbeat.volume_db, lerpf(-40.0, 0.0, t.x) + Game.mix_db("heartbeat") if t.x > 0.0 else -60.0, dt * 3.0)
			heartbeat.pitch_scale = 1.0 + 0.4 * t.y
		chase_loop.volume_db = lerpf(chase_loop.volume_db, -4.0 + Game.mix_db("breathing") if t.y > 0.0 else -60.0, dt * 2.0)
		chase_music.volume_db = lerpf(chase_music.volume_db, Game.mix_db("chase_theme") if t.y > 0.0 else -60.0, dt * (3.0 if t.y > 0.0 else 0.8))
		drone.volume_db = lerpf(-60.0, Game.mix_db("drone") - (6.0 if music_state == "after" else 0.0), level.gloom if is_instance_valid(level) else 1.0)   # no dread by daylight (tutorial)
		_music(dt, t)
		var f: float = screen_fx.get_shader_parameter("fear")
		screen_fx.set_shader_parameter("fear", lerpf(f, fear(), dt * 2.0))
		beacons.queue_redraw()
		hud_face.shake = fear()
		if note_panel.visible and is_instance_valid(Game.player) and Game.player.global_position.distance_to(_note_at) > 1.2:
			note_panel.hide()
		_obj_peek -= dt
		_fold_objective(Game.objective_pin or _obj_peek > 0.0)
		var low := Game.battery < 35.0   # red edges throb when Social Battery runs low
		vignette.modulate.a = lerpf(vignette.modulate.a, (0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.006)) if low else 0.0, dt * 4.0)
		if t.y > 0.0:
			_tip("chase", "โดนไล่! วิ่ง (Shift) ให้พ้นสายตาสักพัก เขาจะเลิกตามแล้วถอยไป · หรือหาที่ซ่อน: ล็อกเกอร์ ห้องน้ำ ใต้โต๊ะ (E)")
		if is_instance_valid(level) and level.get("dark"):
			_tip("dark", "มืด... เปิดไฟฉาย (F) — แต่ไฟฉายกินแบตมือถือ และศัตรูเห็นแสงได้จากไกล")
		if is_instance_valid(Game.player):
			_map_t -= dt
			if _map_t <= 0.0:
				_map_t = 0.25
				phone_map.reveal(Game.player.global_position)
				if phone_map.visible:
					phone_map.queue_redraw()
			var lamp: bool = Game.player.flashlight.visible
			lamp_label.visible = lamp or Game.phone_battery < 30.0
			lamp_label.text = "ไฟฉาย · แบตมือถือ %d%%" % int(Game.phone_battery)
			lamp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if Game.phone_battery < 25.0 else Color(0.75, 0.85, 1.0))
			if Game.player.hidden:
				_tip("hide", "กำลังซ่อน · ถ้ามีคนมายืนใกล้ๆ กด Space ค้างเพื่อกลั้นหายใจ (ระวังแรงหมด)")
	if playing and not Game.in_cutscene:
		stage_time += dt
	var held := Game.skip_hold / Game.SKIP_HOLD
	skip_fill.size.x = 160.0 * held
	skip_hint.modulate.a = 0.55 + 0.45 * held
	lock_hint.visible = playing and Game.phone_lock and not phone.visible and not get_tree().paused
	lock_hint.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	if phone.visible:
		phone_head.text = "%s                แบต %d%%" % [clock_text(), int(Game.phone_battery)]
		phone_clock.text = clock_text()
		if Game.typing:
			phone_foot.text = "กำลังพิมพ์" + ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
		elif phone_app == "":
			phone_foot.text = "1 แชท · 2 GPS · 3 เอกสาร · 4 แผนที่ · 5 งาน · Esc ปิด"
		else:
			phone_foot.text = "[Esc] ปิด" if Game.phone_lock else "[Esc] กลับ · [Tab] ปิด"
		if phone_app == "gps":
			phone_gps.queue_redraw()
	var badge := ("  (%d ใหม่)" % unread) if unread > 0 else ""
	phone_hint.text = "[Tab] มือถือ%s    [F] ไฟฉาย    [Esc] พัก    %s" % [badge, clock_text()]
	if playing and not get_tree().paused and not phone.visible and not keypad.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		phone_hint.text = "คลิกที่จอ หรือกด [M] เพื่อล็อกเมาส์    %s" % clock_text()
	if _sub_t > 0.0:
		_sub_t -= dt
		if _sub_t <= 0.0:
			subtitle.text = ""
			sub_panel.hide()
	if playing and is_instance_valid(Game.player):
		var f: Node = Game.player.focus()
		var ptext: String = f.prompt() if f else ""
		if ptext == "" and Game.player.held:
			ptext = "[Q] ขว้างของล่อ"
		if Game.player.hidden:
			ptext = "[E] ออกมา · [Space ค้าง] กลั้นหายใจ" + ("  (กำลังกลั้น...)" if Game.player.holding_breath else "")
		_set_prompt(ptext)
		crosshair.set_meta("on", f != null)
		crosshair.queue_redraw()
		stamina_bar.size.x = 180.0 * Game.player.stamina / 100.0
		stamina_bar.color = Color(1, 0.45, 0.3) if Game.player.exhausted else Color(0.45, 0.75, 1.0)

# "[E] อ่าน" -> a key cap with E on it, then "อ่าน". Empty = nothing shown.
func _set_prompt(ptext: String) -> void:
	if ptext == "":
		prompt.text = ""
		prompt_box.hide()
		return
	var key := ""
	var rest := ptext
	if ptext.begins_with("["):
		var j := ptext.find("]")
		key = ptext.substr(1, j - 1)
		rest = ptext.substr(j + 1).strip_edges()
	prompt_key.text = key
	prompt_key.get_parent().visible = key != ""
	prompt.text = rest
	prompt_box.show()

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
	battery_pct.text = "%d%%" % int(v)
	battery_fill.bg_color = Color(0.3, 0.85, 0.45) if v > 60 else (YELLOW if v > 30 else RED)

func _on_objective(t: String) -> void:
	if objective.text == t:
		return
	objective.text = t
	objective_note.visible = t != ""
	_obj_peek = 6.0   # opens by itself for a moment, then folds away again
	if playing and t != "":   # a little bounce and a pen scribble when it changes
		Kit.ui_sound("pen", -14.0)
		objective_note.scale = Vector2(1.08, 1.08)
		create_tween().tween_property(objective_note, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

# The sticky note: open = the objective (+ side job); folded = a small tab in the corner.
func _fold_objective(open: bool) -> void:
	var was := objective.visible
	objective.visible = open
	side_label.visible = open and side_label.text != ""
	objective_head.text = "ภารกิจ" if open else "ภารกิจ  ·  กด O"
	if was != open or objective_note.size.x < 1.0:
		objective_note.reset_size()
		objective_note.position.x = 944.0 - objective_note.size.x   # keep it in the corner

# A job arrived / moved on / finished: the side-job line under the sticky note, the phone app.
func _on_quests() -> void:
	var side := ""
	for e in Game.all_quests():
		if not e.q.get("main", false) and Game.quests.has(e.q.id) and not Game.quest_done(e.q.id) and e.chapter == Game.stage:
			side = "งานเสริม · %s\n%s" % [e.q.title, Game.quest_step(e.q.id).do]
	if side != side_label.text:
		_obj_peek = 6.0
	side_label.text = side
	if phone.visible and phone_app == "jobs":
		_show_jobs()
	if playing and not Game.quests.is_empty():
		_tip("jobs", "มีงานเข้ามาทางแชท! ของที่ต้องไปหาเรืองแสงสีม่วง · ดูงานทั้งหมดในมือถือ (Tab แล้วกด 5)")

func _on_message(text: String, secs: float) -> void:
	subtitle.text = Kit.subtitle_bbcode(text)
	sub_panel.visible = text != ""
	_sub_t = secs

# First-time help, once per session each: a small card on the left.
func _tip(id: String, text: String) -> void:
	if _tips.has(id) or Game.in_cutscene:
		return
	_tips[id] = true
	tip_label.text = text
	tip_panel.show()
	tip_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(tip_panel, "modulate:a", 1.0, 0.3)
	t.tween_interval(7.0)
	t.tween_property(tip_panel, "modulate:a", 0.0, 0.8)
	t.tween_callback(tip_panel.hide)

func show_screen(sname: String) -> void:
	for k in screens:
		screens[k].visible = k == sname
	if playing and hud:   # paused: just the coffee-break sheet, no HUD showing through
		hud.visible = not sname in ["pause", "settings"]
	if menu_music:
		if sname in MENU_SCREENS and not playing:
			if not menu_music.playing:
				menu_music.play()
		elif menu_music.playing:
			menu_music.stop()
	match sname:
		"menu":
			continue_btn.visible = Game.has_save()
			var at := Game.saved_stage()
			continue_btn.text = "▶  เล่นต่อ · บทที่ %d %s" % [at + 1, Game.STAGES[at].title.get_slice(" : ", 1)] if at >= 0 and at < Game.STAGES.size() else "▶  เล่นต่อ"
			_refresh_badge()
			var f: Button = continue_btn if continue_btn.visible else screens.menu.get_meta("first")
			f.grab_focus.call_deferred()
		"pause":
			skip_tut_btn.visible = Game.tutorial
			_refresh_pause()
		"debug":   # locked again every time you come back
			debug_pw.text = ""
			debug_err.text = ""
			debug_list.hide()
			for c in debug_lock:
				c.show()
			debug_pw.grab_focus.call_deferred()
		"chapters":
			_fill_chapters()
		"archive":
			_fill_archive()
		"gallery":
			_fill_gallery(gallery_row, false, "")
		"credits":
			credits_scroll.scroll_vertical = 0
		"settings":
			_refresh_settings()

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

# Settings that change something on screen right away.
func apply_settings() -> void:
	HD.apply_look()   # the PSX look or the HD one: resolution, post-process, anti-aliasing
	view_box.stretch_shrink = 3 if Game.retro else 1
	view_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Game.retro else CanvasItem.TEXTURE_FILTER_LINEAR
	var post: Shader = VHS if Game.retro else FILM
	if screen_fx.shader != post:
		screen_fx.shader = post
	view.msaa_3d = Viewport.MSAA_DISABLED if Game.retro else [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(Game.graphics, 0, 2)]
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not Game.retro and Game.graphics == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	var scale := 1.0 if Game.retro else clampf(Game.render_scale, 0.5, 1.0)
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 and HD.forward_plus() else Viewport.SCALING_3D_MODE_BILINEAR
	view.scaling_3d_scale = scale
	screen_fx.set_shader_parameter("fear", screen_fx.get_shader_parameter("fear") if screen_fx.get_shader_parameter("fear") != null else 0.0)
	screen_fx.set_shader_parameter("strength", Game.vhs)
	screen_fx.set_shader_parameter("brightness", Game.brightness)
	subtitle.add_theme_font_size_override("normal_font_size", Game.sub_size)
	subtitle.add_theme_font_size_override("bold_font_size", Game.sub_size)
	subtitle.add_theme_font_size_override("italics_font_size", Game.sub_size)
	if is_instance_valid(Game.player):
		Game.player.cam.fov = Game.fov

# ---------- building: the 3D view ----------
func _build_world() -> void:
	var box := SubViewportContainer.new()
	view_box = box
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = 3
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.process_mode = Node.PROCESS_MODE_PAUSABLE   # pause menu freezes the world
	screen_fx = ShaderMaterial.new()
	screen_fx.shader = VHS if Game.retro else FILM
	screen_fx.set_shader_parameter("fear", 0.0)
	box.material = screen_fx
	add_child(box)
	view = SubViewport.new()
	view.audio_listener_enable_3d = true
	box.add_child(view)

func _crt(parent: Control, corners := 0.55, scan := 0.12) -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/crt.gdshader")
	m.set_shader_parameter("corners", corners)
	m.set_shader_parameter("scan", scan)
	c.material = m
	parent.add_child(c)
	return c

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c

# ---------- building: HUD ----------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(PRESET_FULL_RECT)
	hud.mouse_filter = MOUSE_FILTER_IGNORE
	hud.hide()
	add_child(hud)
	vignette = TextureRect.new()   # red edges: low Social Battery
	var vg := Gradient.new()
	vg.set_color(0, Color(0.6, 0, 0.02, 0))
	vg.set_color(1, Color(0.6, 0, 0.02, 0.85))
	vg.add_point(0.55, Color(0.6, 0, 0.02, 0))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 1.0)
	vignette.texture = vt
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	hud.add_child(vignette)
	for top in [true, false]:   # cutscene letterbox
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(960, 90)
		bar.position = Vector2(0, -90 if top else 720)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		hud.add_child(bar)
		bars.append(bar)
	skip_hint = Kit.label("กด [Space] ค้างไว้เพื่อข้าม", 15, Color(0.75, 0.75, 0.8), Kit.UI, bars[0])   # slides in with the bar
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_at(skip_hint, Vector2(560, 26), Vector2(384, 24))
	var skip_back := ColorRect.new()
	skip_back.color = Color(0.25, 0.25, 0.28)
	_at(skip_back, Vector2(784, 56), Vector2(160, 5))
	bars[0].add_child(skip_back)
	skip_fill = ColorRect.new()
	skip_fill.color = Kit.RED
	skip_fill.size = Vector2(0, 5)
	skip_back.add_child(skip_fill)
	status = Control.new()
	status.set_anchors_preset(PRESET_FULL_RECT)
	status.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(status)
	# top left: Tong + his Social Battery
	var card_l := Kit.panel(Kit.box(Color(0.03, 0.03, 0.05, 0.72), Color(1, 1, 1, 0.1), 1, 10, 0), status)
	_at(card_l, Vector2(12, 12), Vector2(318, 96))
	var frame := Kit.panel(Kit.box(Color(0.12, 0.13, 0.18), Kit.YELLOW.darkened(0.3), 2, 8, 0), status)
	_at(frame, Vector2(20, 20), Vector2(72, 72))
	hud_face = FaceView.new("tong", 64)   # Tong's own head; trembles as Social Battery drains
	_at(hud_face, Vector2(24, 24), Vector2(64, 64))
	hud_face.turn = 0.12
	status.add_child(hud_face)
	var cap := Kit.label("SOCIAL BATTERY", 14, Kit.YELLOW, Kit.TITLE, status)
	_at(cap, Vector2(104, 18), Vector2(180, 20))
	battery_pct = Kit.label("100%", 16, Color.WHITE, Kit.TITLE, status)
	battery_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_at(battery_pct, Vector2(244, 16), Vector2(76, 22))
	battery_bar = ProgressBar.new()
	_at(battery_bar, Vector2(104, 42), Vector2(214, 18))
	battery_bar.show_percentage = false
	var bg := Kit.box(Color(0.02, 0.02, 0.03, 0.9), Color(1, 1, 1, 0.5), 2, 4, 0)
	battery_fill = Kit.box(Color(0.3, 0.85, 0.45), Color(0, 0, 0, 0), 0, 3, 0)
	battery_bar.add_theme_stylebox_override("background", bg)
	battery_bar.add_theme_stylebox_override("fill", battery_fill)
	status.add_child(battery_bar)
	for i in range(1, 5):   # cell dividers: reads as a battery
		var div := ColorRect.new()
		div.color = Color(0, 0, 0, 0.55)
		_at(div, Vector2(104 + 214 * i / 5.0, 44), Vector2(2, 14))
		div.mouse_filter = MOUSE_FILTER_IGNORE
		status.add_child(div)
	var sback := ColorRect.new()   # thin stamina bar (ProgressBar enforces a text-height minimum)
	sback.color = Color(0.02, 0.02, 0.03, 0.9)
	_at(sback, Vector2(104, 66), Vector2(180, 5))
	status.add_child(sback)
	stamina_bar = ColorRect.new()
	stamina_bar.color = Color(0.45, 0.75, 1.0)
	_at(stamina_bar, sback.position, sback.size)
	status.add_child(stamina_bar)
	var stc := Kit.label("แรง", 11, Kit.DIM, Kit.UI, status)
	_at(stc, Vector2(290, 60), Vector2(30, 16))
	heart_label = Kit.label("", 15, Color(1, 0.6, 0.6), Kit.TITLE, status)
	_at(heart_label, Vector2(104, 76), Vector2(214, 22))
	lamp_label = Kit.label("", 13, Color(0.75, 0.85, 1.0), Kit.UI, status)
	_at(lamp_label, Vector2(16, 112), Vector2(300, 20))
	# top right: the objective, on a sticky note
	objective_note = Kit.panel(Kit.box(Kit.STICKY, Kit.STICKY.darkened(0.2), 1, 2, 12), status)
	objective_note.get_theme_stylebox("panel").shadow_color = Color(0, 0, 0, 0.5)
	objective_note.get_theme_stylebox("panel").shadow_size = 6
	objective_note.get_theme_stylebox("panel").shadow_offset = Vector2(3, 4)
	_at(objective_note, Vector2(634, 14), Vector2(310, 60))
	objective_note.rotation = -0.025
	objective_note.pivot_offset = Vector2(155, 20)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	objective_note.add_child(ov)
	objective_head = Kit.label("ภารกิจ", 15, Color(0.7, 0.12, 0.12), Kit.HAND, ov, 0, false)
	objective = Kit.label("", 16, Kit.INK, Kit.HAND, ov)
	objective.custom_minimum_size.x = 286
	side_label = Kit.label("", 14, Color(0.42, 0.16, 0.55), Kit.HAND, ov)   # the side job, in purple pen under it
	side_label.custom_minimum_size.x = 286
	beacons = Control.new()
	beacons.set_anchors_preset(PRESET_FULL_RECT)
	beacons.mouse_filter = MOUSE_FILTER_IGNORE
	beacons.draw.connect(_draw_beacons)
	status.add_child(beacons)
	hide_view = Control.new()   # peek-slit overlay, filled per hide type
	hide_view.set_anchors_preset(PRESET_FULL_RECT)
	hide_view.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(hide_view)
	hud.move_child(hide_view, 1)
	# centre: crosshair + what E does
	crosshair = Control.new()
	_at(crosshair, Vector2(470, 350), Vector2(20, 20))
	crosshair.mouse_filter = MOUSE_FILTER_IGNORE
	crosshair.set_meta("on", false)
	crosshair.draw.connect(func():
		if crosshair.get_meta("on"):
			crosshair.draw_arc(Vector2(10, 10), 8.0, 0.0, TAU, 24, Kit.YELLOW, 2.0)
			crosshair.draw_circle(Vector2(10, 10), 2.0, Kit.YELLOW)
		else:
			crosshair.draw_circle(Vector2(10, 10), 2.0, Color(1, 1, 1, 0.6)))
	status.add_child(crosshair)
	prompt_box = Kit.panel(Kit.box(Color(0.02, 0.02, 0.04, 0.7), Color(1, 1, 1, 0.12), 1, 8, 8), status)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_box.add_child(ph)
	var keycap := Kit.panel(Kit.box(Color(0.92, 0.9, 0.84), Color(0.55, 0.52, 0.45), 2, 5, 4), ph)
	keycap.custom_minimum_size = Vector2(30, 28)
	prompt_key = Kit.label("E", 16, Kit.NIGHT, Kit.TITLE, keycap, 0, false)
	prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = Kit.label("", 18, Color.WHITE, Kit.UI, ph, 0, false)
	prompt_box.hide()
	prompt_box.resized.connect(func(): prompt_box.position = Vector2(480 - prompt_box.size.x / 2, 392))
	# bottom right: keys + clock · bottom left: tutorial hint · left: first-time tips
	phone_hint = Kit.label("", 15, Color(0.8, 0.85, 1.0), Kit.UI, status, 4)
	phone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_at(phone_hint, Vector2(480, 684), Vector2(464, 26))
	saved_label = Kit.label("บันทึกจุดเช็คพอยต์แล้ว", 15, Kit.GREEN, Kit.TITLE, status, 4)
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_at(saved_label, Vector2(600, 656), Vector2(344, 24))
	saved_label.modulate.a = 0.0
	tut_hint = Kit.label("บทนำ · [Esc] แล้วกด \"ข้ามบทนำ\" เพื่อเริ่มบทที่ 1 ทันที", 14, Color(0.7, 0.75, 0.9), Kit.UI, status, 4)
	_at(tut_hint, Vector2(16, 688), Vector2(460, 24))
	tut_hint.hide()
	tip_panel = Kit.panel(Kit.box(Color(0.03, 0.05, 0.08, 0.85), Color("#4aa3ff"), 0, 8, 12), status)
	tip_panel.get_theme_stylebox("panel").border_width_left = 4
	_at(tip_panel, Vector2(16, 150), Vector2(300, 0))
	var tv := VBoxContainer.new()
	tip_panel.add_child(tv)
	Kit.label("คำแนะนำ", 14, Color("#4aa3ff"), Kit.TITLE, tv)
	tip_label = Kit.label("", 15, Color(0.9, 0.92, 0.95), Kit.BODY, tv)
	tip_label.custom_minimum_size.x = 276
	tip_panel.hide()
	# bottom: subtitles (stay up in cutscenes)
	sub_panel = Kit.panel(Kit.box(Color(0, 0, 0, 0.62), Color(0, 0, 0, 0), 0, 8, 10), hud)
	sub_panel.hide()
	subtitle = Kit.rich(Game.sub_size, sub_panel)
	subtitle.custom_minimum_size.x = 760
	subtitle.add_theme_font_override("italics_font", Kit.BODY)
	subtitle.add_theme_color_override("default_color", Color(1, 1, 0.94))
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_panel.resized.connect(func(): sub_panel.position = Vector2(480 - sub_panel.size.x / 2, 640 - sub_panel.size.y))
	# phone notification, slides down from the top
	toast_panel = Kit.panel(Kit.box(Color(0.1, 0.1, 0.13, 0.94), Color(1, 1, 1, 0.12), 1, 14, 10), hud)
	_at(toast_panel, Vector2(330, -80), Vector2(300, 0))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	toast_panel.add_child(th)
	var tic := AppIcon.new("chat", Color("#3dbb6b"))
	tic.custom_minimum_size = Vector2(36, 36)
	tic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	th.add_child(tic)
	toast = Kit.label("", 14, Color.WHITE, Kit.BODY, th)
	toast.custom_minimum_size.x = 230
	toast.max_lines_visible = 3
	toast_panel.modulate.a = 0.0
	lock_hint = Kit.label("มีข้อความเข้า!\nกด [Tab] เปิดมือถืออ่าน", 30, Kit.YELLOW, Kit.TITLE, hud, 8)
	lock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(lock_hint, Vector2(180, 420), Vector2(600, 100))
	lock_hint.hide()
	banner = Kit.label("", 40, Color.WHITE, Kit.TITLE, hud, 10)   # chapter title as play starts
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(banner, Vector2(0, 200), Vector2(960, 80))
	_build_phone()
	note_panel = _note_reader()
	keypad = _keypad()
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
	_at(peephole, Vector2(120, 0), Vector2(720, 720))
	peephole.mouse_filter = MOUSE_FILTER_IGNORE
	peephole.hide()
	hud.add_child(peephole)
	hud.move_child(peephole, 1)
	for r in [Rect2(0, 0, 120, 720), Rect2(840, 0, 120, 720)]:   # the sides beyond the round hole
		var side := ColorRect.new()
		side.color = Color.BLACK
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
	if not Game.retro:   # HD: the face tears, splits and strobes (shaders/scare.gdshader, _slam_fx)
		scare_face.material = ShaderMaterial.new()
		scare_face.material.shader = preload("res://shaders/scare.gdshader")
	scare_face.hide()
	add_child(scare_face)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(PRESET_FULL_RECT)
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fade)
	fps_label = Kit.label("", 16, Color(0.6, 1, 0.6), Kit.UI, null, 4)
	_at(fps_label, Vector2(8, 690), Vector2(120, 24))
	fps_label.hide()
	add_child(fps_label)
	_build_card()

# The chapter card: a CCTV feed of the next floor. REC blinking, the camera, a running timestamp.
func _build_card() -> void:
	card_fx = Control.new()
	card_fx.set_anchors_preset(PRESET_FULL_RECT)
	card_fx.mouse_filter = MOUSE_FILTER_IGNORE
	card_fx.hide()
	add_child(card_fx)
	_crt(card_fx, 0.7, 0.16)
	var rec := HBoxContainer.new()
	_at(rec, Vector2(40, 34), Vector2(300, 30))
	card_fx.add_child(rec)
	var dot := Kit.panel(Kit.box(Kit.RED, Color(0, 0, 0, 0), 0, 9, 0), rec)
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var blink := create_tween().set_loops()
	blink.tween_property(dot, "modulate:a", 0.0, 0.01).set_delay(0.6)
	blink.tween_property(dot, "modulate:a", 1.0, 0.01).set_delay(0.6)
	Kit.label("  REC", 22, Kit.CCTV, Kit.TITLE, rec, 0, false)
	card_osd = Kit.label("CAM 04", 22, Kit.CCTV, Kit.TITLE, card_fx)
	card_osd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_at(card_osd, Vector2(560, 34), Vector2(360, 30))
	var corp := Kit.label("NIGHTSHIFT CO., LTD. · SECURITY", 15, Kit.CCTV.darkened(0.3), Kit.UI, card_fx)
	_at(corp, Vector2(40, 670), Vector2(400, 24))
	card_chapter = Kit.label("", 20, Kit.RED, Kit.TITLE, card_fx)
	card_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(card_chapter, Vector2(0, 230), Vector2(960, 30))
	for xy in [Vector2(30, 24), Vector2(906, 24), Vector2(30, 670), Vector2(906, 670)]:   # viewfinder corners
		var hl := ColorRect.new()
		hl.color = Kit.CCTV
		_at(hl, xy + Vector2(0, 0 if xy.y < 360 else 22), Vector2(24, 2))
		card_fx.add_child(hl)
		var vl := ColorRect.new()
		vl.color = Kit.CCTV
		_at(vl, xy + Vector2(0 if xy.x < 480 else 22, 0), Vector2(2, 24))
		card_fx.add_child(vl)
	card = Kit.label("", 44, Color(0.92, 0.92, 0.9), Kit.TITLE, null, 0)
	card.set_anchors_preset(PRESET_FULL_RECT)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.offset_left = 80
	card.offset_right = -80
	card.hide()
	add_child(card)

# The phone: a handset on the right of the screen. Home screen with app icons, chats with
# avatars and times, the GPS compass, the documents read so far, and the floor map.
func _build_phone() -> void:
	phone = Panel.new()
	var body := Kit.box(Color(0.05, 0.05, 0.06), Color(0.22, 0.22, 0.26), 5, 34, 0)
	body.shadow_color = Color(0, 0, 0, 0.6)
	body.shadow_size = 18
	phone.add_theme_stylebox_override("panel", body)
	_at(phone, Vector2(640, 96), Vector2(290, 560))
	phone.pivot_offset = Vector2(145, 560)
	phone.hide()
	hud.add_child(phone)
	var scr := Panel.new()   # the glass
	scr.add_theme_stylebox_override("panel", Kit.box(Color(0.07, 0.07, 0.1), Color(0, 0, 0, 0), 0, 26, 0))
	_at(scr, Vector2(10, 10), Vector2(270, 540))
	scr.clip_contents = true
	phone.add_child(scr)
	var wall := TextureRect.new()
	var wg := Gradient.new()
	wg.set_color(0, Color("#1c2340"))
	wg.set_color(1, Color("#3a0d1c"))
	var wt := GradientTexture2D.new()
	wt.gradient = wg
	wt.fill_from = Vector2(0, 0)
	wt.fill_to = Vector2(0.4, 1)
	wall.texture = wt
	wall.set_anchors_preset(PRESET_FULL_RECT)
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.modulate = Color(1, 1, 1, 0.9)
	scr.add_child(wall)
	var notch := Panel.new()
	notch.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.02, 0.03), Color(0, 0, 0, 0), 0, 10, 0))
	_at(notch, Vector2(95, 6), Vector2(80, 18))
	scr.add_child(notch)
	var pv := VBoxContainer.new()
	_at(pv, Vector2(12, 8), Vector2(246, 520))
	pv.add_theme_constant_override("separation", 6)
	scr.add_child(pv)
	phone_head = Kit.label("", 12, Color.WHITE, Kit.UI, pv)
	phone_home = VBoxContainer.new()
	phone_home.add_theme_constant_override("separation", 10)
	phone_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(phone_home)
	phone_clock = Kit.label("23:47", 58, Color.WHITE, Kit.TITLE, phone_home)
	phone_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var date := Kit.label("วันศุกร์ · กะดึก", 15, Color(0.85, 0.85, 0.95), Kit.UI, phone_home)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	phone_home.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	phone_home.add_child(grid)
	for app in [["chat", "1 · แชท", Color("#2fae5f")], ["gps", "2 · GPS", Color("#2f6fd6")], ["docs", "3 · เอกสาร", Color("#d6902f")],
			["map", "4 · แผนที่", Color("#8a3fd1")], ["jobs", "5 · งาน", Color("#c23b4e")]]:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(100, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_app.bind(app[0]))
		var bv := VBoxContainer.new()
		bv.set_anchors_preset(PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(bv)
		var ic := AppIcon.new(app[0], app[2])
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ic)
		var al := Kit.label(app[1], 14, Color.WHITE, Kit.UI, bv)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(b)
	phone_chat = VBoxContainer.new()
	phone_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(phone_chat)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size.y = 34
	phone_chat.add_child(tabs_scroll)
	phone_tabs = HBoxContainer.new()
	phone_tabs.add_theme_constant_override("separation", 4)
	tabs_scroll.add_child(phone_tabs)
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
	phone_gps.custom_minimum_size = Vector2(246, 360)
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
	phone_map = PhoneMap.new()
	phone_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phone_map.custom_minimum_size = Vector2(246, 380)
	pv.add_child(phone_map)
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(jobs_scroll)
	phone_jobs = VBoxContainer.new()
	phone_jobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_jobs.add_theme_constant_override("separation", 8)
	jobs_scroll.add_child(phone_jobs)
	phone_foot = Kit.label("[Esc] ปิด", 12, Color(0.7, 0.7, 0.8), Kit.UI, pv)
	phone_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := Panel.new()   # home indicator
	bar.add_theme_stylebox_override("panel", Kit.box(Color(1, 1, 1, 0.6), Color(0, 0, 0, 0), 0, 3, 0))
	_at(bar, Vector2(95, 528), Vector2(80, 5))
	scr.add_child(bar)

# Note reader: a sheet of ruled paper, slightly askew. Title in handwriting, what reading it gave
# you in a green box at the bottom.
func _note_reader() -> PanelContainer:
	var img := Image.create(32, 30, false, Image.FORMAT_RGBA8)
	img.fill(Kit.PAPER)
	for x in 32:
		img.set_pixel(x, 29, Kit.PAPER_LINE)
	var st := StyleBoxTexture.new()
	st.texture = ImageTexture.create_from_image(img)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.set_content_margin_all(26)
	st.content_margin_left = 54
	var p := Kit.panel(st, hud)
	_at(p, Vector2(190, 110), Vector2(580, 450))
	p.pivot_offset = Vector2(290, 225)
	p.draw.connect(func(): p.draw_line(Vector2(40, 0), Vector2(40, p.size.y), Color(0.85, 0.35, 0.35, 0.7), 2.0))   # the red margin line
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 10)
	p.add_child(nv)
	note_labels.title = Kit.label("", 28, Color(0.42, 0.06, 0.08), Kit.HAND, nv)
	note_labels.body = Kit.label("", 19, Kit.INK, Kit.BODY, nv)
	note_labels.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tb := Kit.panel(Kit.box(Color(0.82, 0.93, 0.82), Color(0.2, 0.55, 0.3), 2, 6, 10), nv)
	note_labels.tip = Kit.label("", 16, Color(0.08, 0.32, 0.14), Kit.UI, tb)
	Kit.label("(เดินออก / Esc เพื่อปิด)", 13, Color(0.45, 0.42, 0.4), Kit.UI, nv)
	p.hide()
	return p

# PC login: a little window from the accounts system.
func _keypad() -> PanelContainer:
	var k := Kit.panel(Kit.box(Color(0.82, 0.83, 0.86), Color(0.1, 0.25, 0.6), 2, 4, 0), hud)
	_at(k, Vector2(290, 220), Vector2(380, 250))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	k.add_child(v)
	var bar := Kit.panel(Kit.box(Color(0.1, 0.25, 0.6), Color(0, 0, 0, 0), 0, 0, 8), v)
	Kit.label("ระบบบัญชี v2.3 · ห้อง Admin", 16, Color.WHITE, Kit.UI, bar)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.add_child(inner)
	v.add_child(m)
	Kit.label("ใส่รหัสผ่านเพื่อเข้าสู่ระบบ", 18, Kit.INK, Kit.UI, inner)
	keypad_edit = LineEdit.new()
	keypad_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	keypad_edit.max_length = 8
	keypad_edit.secret = false
	keypad_edit.custom_minimum_size = Vector2(200, 52)
	keypad_edit.add_theme_font_size_override("font_size", 30)
	keypad_edit.add_theme_font_override("font", Kit.TITLE)
	keypad_edit.text_submitted.connect(_submit_code)
	inner.add_child(keypad_edit)
	Kit.label("Enter = ยืนยัน · Esc = ยกเลิก · รหัสผิด = เสียงเตือนดังลั่น!", 13, Color(0.5, 0.1, 0.1), Kit.UI, inner)
	k.hide()
	return k

# ---------- building: screens ----------
func _screen(sname: String, bg := Kit.NIGHT, crt := true) -> Control:
	var root := ColorRect.new()
	root.color = bg
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	screens[sname] = root
	if crt:
		_crt(root, 0.6, 0.08)
	return root

func _vbox(parent: Control, pos: Vector2, sz: Vector2, sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	_at(v, pos, sz)
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

func _header(parent: Control, text: String, sub := "") -> void:
	var h := Kit.label(text, 40, Color.WHITE, Kit.TITLE, parent)
	_at(h, Vector2(60, 36), Vector2(840, 54))
	var line := ColorRect.new()
	line.color = Kit.RED
	_at(line, Vector2(60, 92), Vector2(120, 4))
	parent.add_child(line)
	if sub != "":
		var s := Kit.label(sub, 16, Kit.DIM, Kit.UI, parent)
		_at(s, Vector2(60, 102), Vector2(840, 24))

func _back(parent: Control, cb: Callable) -> Button:
	var b := Kit.button("‹  กลับ  (Esc)", cb, parent, 18, 180)
	_at(b, Vector2(60, 650), Vector2(180, 44))
	return b

func _build_screens() -> void:
	_build_menu()
	_build_chapters()
	_build_archive()
	_build_gallery()
	_build_credits()
	_build_settings()
	_build_debug()
	_build_pause()
	_build_over()
	_build_review()
	_build_ending()
	show_screen("")

func _build_menu() -> void:
	var m := _screen("menu", Color.BLACK, false)
	menu_bg = MenuBg.new()
	m.add_child(menu_bg)
	var shade := TextureRect.new()   # dark on the left so the menu reads over the office
	var sg := Gradient.new()
	sg.set_color(0, Color(0.02, 0.01, 0.03, 0.94))
	sg.set_color(1, Color(0.02, 0.01, 0.03, 0.15))
	var stx := GradientTexture2D.new()
	stx.gradient = sg
	stx.fill_from = Vector2(0.25, 0)
	stx.fill_to = Vector2(0.9, 0)
	shade.texture = stx
	shade.set_anchors_preset(PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	m.add_child(shade)
	_crt(m, 0.5, 0.1)
	menu_osd = Kit.label("", 16, Kit.CCTV, Kit.TITLE, m, 4)
	_at(menu_osd, Vector2(40, 22), Vector2(880, 24))
	var rec := Kit.panel(Kit.box(Kit.RED, Color(0, 0, 0, 0), 0, 7, 0), m)
	_at(rec, Vector2(22, 27), Vector2(14, 14))
	var blink := create_tween().set_loops()
	blink.tween_property(rec, "modulate:a", 0.0, 0.01).set_delay(0.7)
	blink.tween_property(rec, "modulate:a", 1.0, 0.01).set_delay(0.7)
	var t1 := Kit.label("Salary man:", 40, Color(0.9, 0.9, 0.92), Kit.TITLE, m)
	_at(t1, Vector2(58, 64), Vector2(500, 56))
	for c in [Color(0.2, 0.9, 1.0, 0.0), Color(1.0, 0.1, 0.3, 0.0)]:   # glitch ghosts behind the title
		var gl := Kit.label("NIGHTMARE", 84, c, Kit.TITLE, m)
		_at(gl, Vector2(54, 106), Vector2(520, 110))
		title_ghosts.append(gl)
	var t2 := Kit.label("NIGHTMARE", 84, Kit.RED, Kit.TITLE, m)
	_at(t2, Vector2(54, 106), Vector2(520, 110))
	var tag := Kit.label("Horror Comedy · Workplace Survival · " + ("Low-Poly PSX" if Game.retro else "3D HD Remaster"), 15, Kit.DIM, Kit.UI, m)
	_at(tag, Vector2(60, 212), Vector2(480, 22))
	var v := _vbox(m, Vector2(56, 246), Vector2(340, 420), 5)
	continue_btn = Kit.button("▶  เล่นต่อ (บทล่าสุด)", continue_game, v, 19)
	var first := Kit.button("▶  เริ่มเกมใหม่", start_game, v, 19)
	m.set_meta("first", first)
	Kit.button("เลือกบท", func(): show_screen("chapters"), v, 19)
	Kit.button("คลังหลักฐาน", func(): show_screen("archive"), v, 19)
	Kit.button("ฉากจบ", func(): show_screen("gallery"), v, 19)
	Kit.button("ตั้งค่า", func(): _settings_back = "menu"; show_screen("settings"), v, 19)
	Kit.button("เครดิต", func(): show_screen("credits"), v, 19)
	if not OS.has_feature("web"):   # a web page can't close itself
		Kit.button("ออกจากเกม", get_tree().quit, v, 19)
	var dbg := Kit.button("Debug", func(): show_screen("debug"), m, 13, 70, true)
	_at(dbg, Vector2(880, 680), Vector2(70, 28))
	dbg.modulate.a = 0.5
	var keys := Kit.label("WASD เดิน · Shift วิ่ง · C ก้ม · E ใช้/ซ่อน · Space กลั้นหายใจ · Q ขว้าง · Tab มือถือ · F ไฟฉาย", 13, Kit.DIM, Kit.UI, m)
	_at(keys, Vector2(60, 688), Vector2(800, 20))
	# Tong's staff ID on a lanyard: who you are and how far you've got
	var lan := ColorRect.new()
	lan.color = Color(0.75, 0.12, 0.2)
	_at(lan, Vector2(744, 0), Vector2(8, 120))
	m.add_child(lan)
	var badge := Kit.panel(Kit.paper_box(Color("#f4f2ec"), 0), m)
	_at(badge, Vector2(640, 100), Vector2(216, 330))
	badge.rotation = 0.06
	badge.pivot_offset = Vector2(108, 0)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	badge.add_child(bv)
	var strip := Kit.panel(Kit.box(Kit.RED.darkened(0.15), Color(0, 0, 0, 0), 0, 0, 6), bv)
	var sl := Kit.label("NIGHTSHIFT CO., LTD.", 14, Color.WHITE, Kit.TITLE, strip)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ph := Kit.panel(Kit.box(Color("#b9c3cf"), Color(0.3, 0.3, 0.35), 2, 2, 0), bv)
	ph.custom_minimum_size = Vector2(120, 120)
	ph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := FaceView.new("tong", 112)
	face.custom_minimum_size = Vector2(116, 116)
	face.turn = 0.08
	ph.add_child(face)
	var nm := Kit.label("ต๋อง", 26, Kit.INK, Kit.TITLE, bv)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dept := Kit.label("ฝ่ายบัญชี · พนักงานกะดึก", 13, Color(0.35, 0.33, 0.32), Kit.UI, bv)
	dept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_stats = Kit.label("", 13, Kit.INK, Kit.BODY, bv)
	badge_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var code := Control.new()   # barcode
	code.custom_minimum_size = Vector2(180, 26)
	code.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	code.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4471
		var x := 0.0
		while x < 176.0:
			var w := rng.randi_range(1, 3)
			code.draw_rect(Rect2(x, 0, w, 26), Kit.INK)
			x += w + rng.randi_range(1, 3))
	bv.add_child(code)

func _refresh_badge() -> void:
	var docs := Game.all_docs()
	var found := docs.filter(func(d): return Game.docs_found.has(d.title)).size()
	var best := ""
	for g in "SABCD":
		if Game.grades.values().has(g):
			best = g
			break
	badge_stats.text = "บทที่ไปถึง  %d / %d\nฉากจบ  %d / 4\nเอกสาร  %d / %d%s" % [
		Game.reached + 1 if Game.reached >= 0 else 0, Game.STAGES.size(), Game.endings_seen.size(), found, docs.size(),
		("\nเกรดดีที่สุด  " + best) if best != "" else ""]

# Main menu motion: the CCTV clock ticks, and the title glitches now and then.
func _menu_tick(dt: float) -> void:
	if screens.has("credits") and screens.credits.visible:
		_credit_y += dt * 28.0   # roll slowly; the wheel still works
		credits_scroll.scroll_vertical += int(_credit_y)
		_credit_y -= int(_credit_y)
	if not screens.has("menu") or not screens.menu.visible:
		return
	_osd_secs += dt
	var s := 23 * 3600 + 47 * 60 + int(_osd_secs)
	menu_osd.text = "REC   CAM 01 · ชั้น 4 · ฝ่ายบัญชี                                                  ศุกร์ 24/10   %02d:%02d:%02d" % [(s / 3600) % 24, (s / 60) % 60, s % 60]
	if _glitch > 0.0:
		_glitch -= dt
		for i in title_ghosts.size():
			title_ghosts[i].position = Vector2(54, 106) + Vector2(randf_range(-9, 9), randf_range(-3, 3))
			title_ghosts[i].modulate.a = 0.85
		if _glitch <= 0.0:
			for g in title_ghosts:
				g.modulate.a = 0.0
	elif randf() < dt * 0.35:
		_glitch = randf_range(0.08, 0.3)

func _build_chapters() -> void:
	var c := _screen("chapters")
	_header(c, "เลือกบท", "เริ่มจากกลางเรื่องได้ · หลักฐาน/เบาะแสจากบทก่อนหน้าจะไม่ถูกนับในรอบนั้น")
	chapter_grid = GridContainer.new()
	chapter_grid.columns = 2
	chapter_grid.add_theme_constant_override("h_separation", 16)
	chapter_grid.add_theme_constant_override("v_separation", 10)
	_at(chapter_grid, Vector2(60, 140), Vector2(840, 490))
	c.add_child(chapter_grid)
	_back(c, func(): show_screen("menu"))

func _fill_chapters() -> void:
	for ch in chapter_grid.get_children():
		ch.queue_free()
	var tut := Kit.button("บทนำ · เย็นวันศุกร์ ก่อนกะดึก\n17:30", start_game, chapter_grid, 17, 412)
	tut.custom_minimum_size.y = 96
	for i in Game.STAGES.size():
		var d: Dictionary = Game.STAGES[i]
		var open := i <= Game.reached
		var grade: String = Game.grades.get(i, "")
		var text := ("บทที่ %d · %s\n%s%s" % [i + 1, d.title.get_slice(" : ", 1), d.clock, ("   ·   เกรด " + grade) if grade != "" else ""]) if open else "บทที่ %d · ???\nยังไม่ปลดล็อก" % (i + 1)
		var b := Kit.button(text, _debug_start.bind(i), chapter_grid, 17, 412)
		b.custom_minimum_size.y = 96
		b.disabled = not open

func _build_archive() -> void:
	var a := _screen("archive")
	_header(a, "คลังหลักฐาน")
	archive_count = Kit.label("", 16, Kit.DIM, Kit.UI, a)
	_at(archive_count, Vector2(60, 102), Vector2(840, 24))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_at(scroll, Vector2(60, 140), Vector2(330, 490))
	a.add_child(scroll)
	archive_list = VBoxContainer.new()
	archive_list.add_theme_constant_override("separation", 4)
	archive_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(archive_list)
	var paper := Kit.panel(Kit.paper_box(), a)
	_at(paper, Vector2(420, 140), Vector2(480, 490))
	paper.rotation = 0.012
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	paper.add_child(pv)
	archive_title = Kit.label("", 26, Color(0.42, 0.06, 0.08), Kit.HAND, pv)
	archive_body = Kit.label("", 17, Kit.INK, Kit.BODY, pv)
	_back(a, func(): show_screen("menu"))

func _fill_archive() -> void:
	for c in archive_list.get_children():
		c.queue_free()
	var docs := Game.all_docs()
	var found := docs.filter(func(d): return Game.docs_found.has(d.title))
	archive_count.text = "เอกสาร โน้ต และของที่เก็บได้ในทุกการเล่น · พบแล้ว %d / %d" % [found.size(), docs.size()]
	archive_title.text = "เลือกเอกสารทางซ้าย"
	archive_body.text = "ทุกอย่างที่ต๋องเคยอ่าน จะถูกเก็บไว้ที่นี่ตลอดไป\nเอกสารที่ยังไม่เจอ ซ่อนอยู่ในบทนั้นๆ"
	var last := -2
	for d in docs:
		if d.chapter != last:
			last = d.chapter
			Kit.label("บทนำ" if last < 0 else "บทที่ %d" % (last + 1), 14, Kit.RED, Kit.TITLE, archive_list)
		var have: bool = Game.docs_found.has(d.title)
		var read := func(): archive_title.text = d.title; archive_body.text = d.text
		var b := Kit.button(d.title if have else "???  (ยังไม่พบ)", read, archive_list, 15, 316)
		b.custom_minimum_size.y = 34
		b.disabled = not have

func _build_gallery() -> void:
	var g := _screen("gallery")
	_header(g, "ฉากจบ", "4 ทางจบ · ทางไหนที่ยังไม่เจอ มีคำใบ้ให้")
	gallery_row = HBoxContainer.new()
	gallery_row.add_theme_constant_override("separation", 14)
	_at(gallery_row, Vector2(60, 150), Vector2(840, 460))
	g.add_child(gallery_row)
	_back(g, func(): show_screen("menu"))

# Four ending cards; small = the row on the ending screen (the one just reached glows).
func _fill_gallery(row: HBoxContainer, small: bool, just: String) -> void:
	for c in row.get_children():
		c.queue_free()
	for id in ["A", "B", "C", "D"]:
		var seen: bool = Game.endings_seen.has(id)
		var col := Kit.YELLOW if id == just else (Color(1, 1, 1, 0.25) if seen else Color(1, 1, 1, 0.08))
		var cardp := Kit.panel(Kit.box(Color(0.06, 0.06, 0.09, 0.95), col, 2, 8, 10), row)
		cardp.custom_minimum_size = Vector2(100 if small else 199, 0 if small else 440)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		cardp.add_child(v)
		if seen:
			var fv := FaceView.new(ENDINGS[id][2], 96)
			fv.custom_minimum_size = Vector2(70, 70) if small else Vector2(170, 170)
			fv.set_horror(id != "D")
			v.add_child(fv)
		else:
			var q := Kit.label("?", 60 if not small else 34, Color(1, 1, 1, 0.15), Kit.TITLE, v)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.custom_minimum_size.y = 70 if small else 170
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var l := Kit.label(ENDINGS[id][0], 13 if small else 16, Kit.YELLOW if seen else Kit.DIM, Kit.TITLE, v)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not small:
			var tl := Kit.label(ENDINGS[id][1] if seen else "ยังไม่พบ", 20, Color.WHITE if seen else Kit.DIM, Kit.TITLE, v)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var hint := Kit.label(ENDING_HINTS[id] if not seen or id == "D" else ENDINGS[id][3].get_slice("\n", 0), 14, Kit.DIM, Kit.BODY, v)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_credits() -> void:
	var c := _screen("credits")
	_header(c, "เครดิต")
	credits_scroll = ScrollContainer.new()
	credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_at(credits_scroll, Vector2(60, 130), Vector2(840, 500))
	c.add_child(credits_scroll)
	var r := Kit.rich(18, credits_scroll)
	r.custom_minimum_size.x = 820
	r.add_theme_color_override("default_color", Color(0.88, 0.88, 0.9))
	r.text = """[b][color=#f2c94c]Salary man: Nightmare[/color][/b]
Horror Comedy · Workplace Survival · Low-Poly PSX
CP410844 กลุ่ม 2

[b][color=#d8263a]เกมและเนื้อเรื่อง[/color][/b]
ออกแบบ เขียนเรื่อง ตัวละคร ด่าน และระบบทั้งหมด — ทีมกลุ่ม 2

[b][color=#d8263a]เครื่องมือ[/color][/b]
Godot Engine 4.7 · Blender 5.2 · Python + numpy (เสียงสังเคราะห์)

[b][color=#d8263a]โมเดล 3D[/color][/b]
ตัวละครทุกตัว (ร่างกลางวัน / กลางคืน): สร้างใน Blender ด้วยสคริปต์ของทีม
เฟอร์นิเจอร์ออฟฟิศ: Furniture Kit โดย Kenney (CC0)

[b][color=#d8263a]ฟอนต์[/color][/b]
Kanit, Sriracha (Cadson Demak) · Sarabun — SIL Open Font License 1.1

[b][color=#d8263a]เสียง[/color][/b]
Kenney RPG Audio (CC0) · เสียงจาก freesound.org (CC0) โดย MathewHenry, Johnnie_Holiday, DavidJohnson2019,
Cloud-10, CVLTIV8R, tlcolbe, XfiXy8, nayahnaidoo, Kleber_KGF, BFMGames, Ligidium, DigPro120, baidonovan,
PSsoundproject, sickfin, Lancemartin, szegvari, Nox_Sound, jayfrosting, egomassive
เพลงกล่องดนตรี เสียง UI ไซเรน และเสียงสังเคราะห์อื่นๆ: สร้างเองด้วยสคริปต์

[b][color=#d8263a]ขอบคุณ[/color][/b]
ทุกคนที่เคยอยู่กะดึก ...และกลับบ้านได้

[color=#8a8a99]บริษัท ไนท์ชิฟต์ จำกัด เป็นบริษัทสมมุติ ไม่มีพนักงานคนไหนได้รับอันตรายระหว่างการสร้างเกมนี้
(ยกเว้น Social Battery)[/color]"""
	_back(c, func(): show_screen("menu"))

func _build_settings() -> void:
	var s := _screen("settings", Color(0.03, 0.025, 0.04, 0.97))
	_header(s, "ตั้งค่า")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	_at(grid, Vector2(60, 130), Vector2(840, 480))
	s.add_child(grid)
	var row := func(label: String, ctrl: Control, key: String, fmt: String) -> void:
		var name_l := Kit.label(label, 19, Color(0.9, 0.88, 0.85), Kit.UI, grid)
		name_l.custom_minimum_size.x = 260
		ctrl.custom_minimum_size = Vector2(380, 30)
		ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(ctrl)
		var val := Kit.label("", 17, Kit.YELLOW, Kit.TITLE, grid)
		val.custom_minimum_size.x = 120
		_settings_rows[key] = [ctrl, val, fmt]
	var diff := HBoxContainer.new()
	diff.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = ["ง่าย", "ปกติ", "ยาก"][i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(120, 32)
		Kit.button_styles(b, 17, true)
		b.add_theme_stylebox_override("pressed", Kit.box(Kit.RED.darkened(0.2), Kit.RED, 1, 4, 6))
		b.pressed.connect(func(): Game.difficulty = i; _setting_changed())
		diff.add_child(b)
	row.call("ความยาก", diff, "difficulty", "")
	var gfx := HBoxContainer.new()   # HD look quality
	gfx.add_theme_constant_override("separation", 6)
	var ggroup := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = ["ต่ำ", "กลาง", "สูง"][i]
		b.toggle_mode = true
		b.button_group = ggroup
		b.custom_minimum_size = Vector2(120, 32)
		Kit.button_styles(b, 17, true)
		b.add_theme_stylebox_override("pressed", Kit.box(Kit.RED.darkened(0.2), Kit.RED, 1, 4, 6))
		b.pressed.connect(func(): Game.graphics = i; _setting_changed())
		gfx.add_child(b)
	row.call("คุณภาพกราฟิก", gfx, "graphics", "")
	for spec in [["ความไวเมาส์", "sensitivity", 0.3, 2.0, 0.05, "%.2f"], ["เสียงทั้งหมด", "volume", 0.0, 1.0, 0.05, "%d%%"],
			["เพลงเมนู", "music", 0.0, 1.0, 0.05, "%d%%"], ["ความสว่าง", "brightness", 0.6, 1.6, 0.05, "%d%%"],
			["มุมมอง (FOV)", "fov", 55.0, 95.0, 1.0, "%d°"], ["เอฟเฟกต์ภาพ VHS", "vhs", 0.0, 1.5, 0.05, "%d%%"],
			["ขนาดซับไตเติล", "sub_size", 16.0, 32.0, 1.0, "%d"], ["ความละเอียด 3D", "render_scale", 0.5, 1.0, 0.05, "%d%%"]]:
		var sl := HSlider.new()
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = spec[4]
		sl.focus_mode = Control.FOCUS_ALL
		var key: String = spec[1]
		sl.value_changed.connect(func(v):
			Game.set(key, int(v) if key == "sub_size" else v)
			_setting_changed())
		row.call(spec[0], sl, key, spec[5])
	for spec in [["กลับแกนเมาส์ขึ้น-ลง", "invert_y"], ["ข้ามคัตซีนทั้งหมด", "skip_cutscenes"], ["แสดงกระดาษภารกิจตลอด (O)", "objective_pin"], ["ภาพย้อนยุค (PSX 320x240)", "retro"], ["เต็มจอ", "fullscreen"]]:
		if spec[1] == "fullscreen" and OS.has_feature("web"):
			continue
		var cb := CheckBox.new()
		var key2: String = spec[1]
		cb.toggled.connect(func(on): Game.set(key2, on); _setting_changed())
		row.call(spec[0], cb, key2, "")
	_back(s, func(): show_screen(_settings_back))

func _refresh_settings() -> void:
	for key in _settings_rows:
		var r: Array = _settings_rows[key]
		var ctrl: Control = r[0]
		if ctrl is HSlider:
			ctrl.set_value_no_signal(Game.get(key))
		elif ctrl is CheckBox:
			ctrl.set_pressed_no_signal(Game.get(key))
		elif key == "difficulty":
			ctrl.get_child(Game.difficulty).set_pressed_no_signal(true)
		elif key == "graphics":
			ctrl.get_child(clampi(Game.graphics, 0, 2)).set_pressed_no_signal(true)
	_settings_labels()

func _settings_labels() -> void:
	for key in _settings_rows:
		var r: Array = _settings_rows[key]
		var v = Game.get(key)
		var fmt: String = r[2]
		r[1].text = "" if fmt == "" else (fmt % (v * 100.0 if fmt == "%d%%" else v))
	_settings_rows.difficulty[1].text = ["ศัตรูช้าลง โดนจับเจ็บน้อย", "", "ศัตรูเร็ว กาแฟน้อย"][Game.difficulty]
	_settings_rows.graphics[1].text = "มีผลบทถัดไป" if playing else ""   # shadows / fog are set as a chapter loads

func _setting_changed() -> void:
	Game.save_settings()
	apply_settings()
	_settings_labels()

func _build_debug() -> void:
	var d := _screen("debug")
	_header(d, "DEBUG MODE", "รหัสผ่าน แล้วกระโดดไปบทไหนก็ได้ (สำหรับทดสอบ / สาธิต)")
	var v := _vbox(d, Vector2(300, 150), Vector2(360, 480), 8)
	debug_pw = LineEdit.new()
	debug_pw.secret = true
	debug_pw.placeholder_text = "รหัสผ่าน"
	debug_pw.alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_pw.custom_minimum_size = Vector2(320, 48)
	debug_pw.text_submitted.connect(func(_t): _debug_unlock())
	v.add_child(debug_pw)
	debug_err = Kit.label("", 18, Kit.RED, Kit.UI, v)
	var ok := Kit.button("ยืนยัน", _debug_unlock, v, 20, 360, true)
	debug_list = VBoxContainer.new()
	debug_list.add_theme_constant_override("separation", 6)
	debug_list.hide()
	v.add_child(debug_list)
	Kit.button(Story.TUTORIAL.title, start_game, debug_list, 16, 360)
	for i in Game.STAGES.size():
		Kit.button(Game.STAGES[i].title, _debug_start.bind(i), debug_list, 16, 360)
	debug_lock = [debug_pw, ok]
	_back(d, func(): show_screen("menu"))

# Pause = coffee break: the menu on the left, where you are on a sheet of paper on the right.
func _build_pause() -> void:
	var p := _screen("pause", Color(0, 0, 0, 0.72), false)
	var t := Kit.label("พักเบรก", 52, Color.WHITE, Kit.TITLE, p)
	_at(t, Vector2(60, 70), Vector2(400, 70))
	var line := ColorRect.new()
	line.color = Kit.RED
	_at(line, Vector2(62, 142), Vector2(120, 4))
	p.add_child(line)
	var v := _vbox(p, Vector2(56, 180), Vector2(340, 400), 8)
	var resume := Kit.button("▶  เล่นต่อ", func(): _unhandled_input(_pause_event()), v, 21)
	p.set_meta("first", resume)
	Kit.button("ตั้งค่า", func(): _settings_back = "pause"; show_screen("settings"), v, 21)
	skip_tut_btn = Kit.button("ข้ามบทนำ → บทที่ 1", skip_tutorial, v, 21)
	Kit.button("เริ่มบทนี้ใหม่", func(): get_tree().paused = false; Game.restart_stage(); start_stage(), v, 21)
	Kit.button("เมนูหลัก", func(): get_tree().paused = false; stop_play(); show_screen("menu"), v, 21)
	var paper := Kit.panel(Kit.paper_box(), p)
	_at(paper, Vector2(450, 70), Vector2(450, 580))
	paper.rotation = 0.015
	pause_info = Kit.rich(17, paper)
	pause_info.add_theme_color_override("default_color", Kit.INK)
	pause_info.add_theme_font_override("bold_font", Kit.TITLE)

func _refresh_pause() -> void:
	if not playing:
		return
	screens.pause.get_meta("first").grab_focus.call_deferred()
	var d := Game.stage_data()
	var jobs := ""
	for e in Game.all_quests().filter(func(x): return x.chapter == Game.stage and Game.quests.has(x.q.id)):
		jobs += "\n%s %s%s" % ["✓" if Game.quest_done(e.q.id) else "•", e.q.title, "" if Game.quest_done(e.q.id) else " → " + Game.quest_step(e.q.id).do]
	pause_info.text = "[b][font_size=24]%s[/font_size][/b]\n[color=#7a6f66]%s · ความยาก: %s[/color]\n\n[b]ภารกิจ[/b]\n%s%s\n\n[b]สิ่งที่สะสม (ทั้งเกม)[/b]\nเบาะแสความฝัน  %d / %d\nหลักฐานเรื่องพี่สมชาย  %d / %d\nมือถือพี่สมชาย  %s\nโดนจับ  %d ครั้ง\n\n[b]ปุ่ม[/b]\nWASD เดิน · Shift วิ่ง · C ก้มย่อง\nE ใช้ของ / ซ่อน / คุย · Space ค้าง กลั้นหายใจ\nQ ขว้างของล่อ · F ไฟฉาย · Tab มือถือ · O กระดาษภารกิจ" % [
		d.title, clock_text(), ["ง่าย", "ปกติ", "ยาก"][Game.difficulty], Game.objective_text(), ("\n\n[b]งาน[/b]" + jobs) if jobs != "" else "",
		Game.clues.size(), Game.CLUE_TOTAL, Game.hints, Game.EVIDENCE_NEEDED, "อยู่ในมือ" if Game.phone_taken else "ยังไม่ได้", Game.times_caught]

# Game over = a warning letter from HR.
func _build_over() -> void:
	var o := _screen("over", Color(0.07, 0.0, 0.01))
	var paper := Kit.panel(Kit.paper_box(), o)
	_at(paper, Vector2(200, 40), Vector2(560, 560))
	paper.rotation = -0.012
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	paper.add_child(v)
	Kit.label("บริษัท ไนท์ชิฟต์ จำกัด · ฝ่ายบุคคล", 14, Color(0.4, 0.36, 0.33), Kit.UI, v)
	Kit.label("หนังสือเตือน", 40, Color(0.55, 0.05, 0.08), Kit.TITLE, v)
	Kit.label("ถึง: คุณต๋อง ฝ่ายบัญชี\nเรื่อง: Social Battery หมด ล้มนอนตาลอยกลางออฟฟิศ", 17, Kit.INK, Kit.BODY, v)
	var hr := ColorRect.new()
	hr.color = Color(0.4, 0.36, 0.33, 0.5)
	hr.custom_minimum_size.y = 2
	v.add_child(hr)
	over_cause = Kit.label("", 19, Kit.INK, Kit.HAND, v)
	over_count = Kit.label("", 15, Color(0.35, 0.32, 0.3), Kit.BODY, v)
	Kit.label("\nจึงเรียนมาเพื่อทราบ และกลับไปทำงานต่อโดยด่วน\n— พี่แหม่ม HR", 16, Kit.INK, Kit.BODY, v)
	over_tip = Kit.label("", 15, Color(0.15, 0.3, 0.5), Kit.HAND, v)
	var stamp := _stamp_label("พักงาน", o, Vector2(540, 450))
	o.set_meta("stamp", stamp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_at(h, Vector2(200, 628), Vector2(560, 56))
	o.add_child(h)
	var retry := Kit.button("ลองใหม่ (บทนี้)", func(): Game.restart_stage(); start_stage(), h, 20, 272, true)
	o.set_meta("first", retry)
	Kit.button("เมนูหลัก", func(): show_screen("menu"), h, 20, 272, true)

func _stamp_label(text: String, parent: Control, pos: Vector2) -> Control:
	var s := Kit.panel(Kit.box(Color(0, 0, 0, 0), Color(0.8, 0.08, 0.12, 0.85), 5, 6, 10), parent)
	var l := Kit.label(text, 42, Color(0.8, 0.08, 0.12, 0.85), Kit.TITLE, s, 0, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(s, pos, Vector2(220, 80))
	s.pivot_offset = Vector2(110, 40)
	s.rotation = -0.3
	s.set_meta("label", l)
	return s

# Stage clear = the performance review.
func _build_review() -> void:
	var r := _screen("review", Color(0.05, 0.05, 0.07))
	var paper := Kit.panel(Kit.paper_box(), r)
	_at(paper, Vector2(170, 34), Vector2(620, 590))
	paper.rotation = 0.01
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	paper.add_child(v)
	Kit.label("บริษัท ไนท์ชิฟต์ จำกัด · แบบฟอร์ม HR-07", 14, Color(0.4, 0.36, 0.33), Kit.UI, v)
	Kit.label("ใบประเมินผลการปฏิบัติงาน", 34, Kit.INK, Kit.TITLE, v)
	review_labels.chapter = Kit.label("", 20, Color(0.55, 0.05, 0.08), Kit.UI, v)
	var hr := ColorRect.new()
	hr.color = Color(0.4, 0.36, 0.33, 0.5)
	hr.custom_minimum_size.y = 2
	v.add_child(hr)
	review_labels.rows = Kit.label("", 19, Kit.INK, Kit.BODY, v)
	review_labels.rows.tab_stops = PackedFloat32Array([330.0])
	review_labels.boss = Kit.label("", 18, Color(0.25, 0.22, 0.4), Kit.HAND, v)
	review_labels.best = Kit.label("", 14, Color(0.4, 0.36, 0.33), Kit.UI, v)
	Kit.label("\nผู้ประเมิน: หัวหน้าธนา                    ผู้อนุมัติ: พี่แหม่ม HR", 15, Kit.INK, Kit.HAND, v)
	var stamp := Kit.panel(Kit.box(Color(0, 0, 0, 0), Color(0.8, 0.08, 0.12, 0.85), 5, 70, 4), r)
	_at(stamp, Vector2(600, 300), Vector2(150, 150))
	stamp.pivot_offset = Vector2(75, 75)
	stamp.rotation = -0.25
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	stamp.add_child(sv)
	var sl := Kit.label("เกรด", 18, Color(0.8, 0.08, 0.12, 0.85), Kit.TITLE, sv, 0, false)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	review_labels.grade = Kit.label("A", 64, Color(0.8, 0.08, 0.12, 0.9), Kit.TITLE, sv, 0, false)
	review_labels.grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	review_labels.stamp = stamp
	var go := Kit.button("ไปต่อ  (E)", func(): _review_done = true, r, 20, 260, true)
	_at(go, Vector2(350, 640), Vector2(260, 50))
	r.set_meta("first", go)

# Ending = a certificate, with every ending found so far underneath.
func _build_ending() -> void:
	var e := _screen("ending", Color(0.03, 0.03, 0.05))
	var frame := Kit.panel(Kit.box(Color(0.07, 0.065, 0.09, 0.96), Color("#b8963e"), 3, 4, 22), e)
	_at(frame, Vector2(80, 22), Vector2(800, 486))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	end_labels.face = FaceView.new("tong", 112)
	end_labels.face.custom_minimum_size = Vector2(130, 130)
	top.add_child(end_labels.face)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	end_labels.letter = Kit.label("", 22, Kit.YELLOW, Kit.TITLE, tv)
	end_labels.title = Kit.label("", 46, Color.WHITE, Kit.TITLE, tv)
	end_labels.new = Kit.label("ปลดล็อกฉากจบใหม่!", 16, Kit.GREEN, Kit.TITLE, tv)
	var row := HBoxContainer.new()   # the ending on the left; ฝน's epilogue (once her story is found) on the right
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	end_labels.body = Kit.label("", 18, Color(0.88, 0.88, 0.9), Kit.BODY, row)
	end_labels.body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_labels.epi_box = Kit.panel(Kit.box(Color(0.22, 0.12, 0.3, 0.9), Color(0.84, 0.72, 1.0, 0.5), 1, 6, 12), row)
	end_labels.epi_box.custom_minimum_size.x = 290
	end_labels.epi_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	end_labels.epi = Kit.label("", 16, Color(0.93, 0.88, 1.0), Kit.HAND, end_labels.epi_box)
	end_labels.stats = Kit.label("", 14, Kit.DIM, Kit.UI, v)
	end_labels.gallery = HBoxContainer.new()
	end_labels.gallery.add_theme_constant_override("separation", 10)
	end_labels.gallery.alignment = BoxContainer.ALIGNMENT_CENTER
	_at(end_labels.gallery, Vector2(80, 520), Vector2(800, 130))
	e.add_child(end_labels.gallery)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	_at(h, Vector2(80, 662), Vector2(800, 46))
	e.add_child(h)
	var again := Kit.button("เล่นอีกครั้ง", start_game, h, 18, 220, true)
	e.set_meta("first", again)
	Kit.button("ฉากจบทั้งหมด", func(): show_screen("gallery"), h, 18, 220, true)
	Kit.button("เมนูหลัก", func(): show_screen("menu"), h, 18, 220, true)

# Browsers release the mouse on Esc without passing the key to the game. If capture is lost
# mid-play, open the pause menu; its Resume click is the user gesture needed to lock again.
func _watch_capture() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and playing and not get_tree().paused \
			and not phone.visible and not keypad.visible and not Game.in_cutscene and not Game.busy:
		_unhandled_input(_pause_event())
	_was_captured = captured

func _pause_event() -> InputEvent:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev
