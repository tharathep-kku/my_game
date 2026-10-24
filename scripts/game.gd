# Autoload "Game": run state, rules, stage data, ending resolver, sfx helper.
extends Node

signal battery_changed(value: float)
signal message(text: String, secs: float)
signal objective_changed(text: String)
signal caught(npc: Node)        # main.gd fades + respawns
signal game_over(cause: String)
signal stage_cleared
signal note_opened(title: String, body: String, tip: String)   # main.gd shows the note reader
signal code_requested(pc: Node)   # main.gd shows the keypad
signal event(what: String)        # player did something (tutorial listens): read/phone/phone_read/talk/throw/hide
signal flash(kind: String)       # dream-clue hospital flash etc.
signal story_event(t: Dictionary)  # phone texts / photo handled by main + level
signal cutscene_changed(on: bool)
signal skip_cutscene             # Space held for SKIP_HOLD seconds during a cutscene
signal phone_message(thread: String, msg: Dictionary)
signal hidden_changed(kind: String)   # "" = came out
signal scare_face(preset: String, sfx: String)   # non-lethal face slam (cutscenes, "face" scares)
signal fade(alpha: float, secs: float)   # cutscene "fade" step: black over the picture
signal overlay(kind: String)             # "peephole" / "" (main.gd)

const MAX_BATTERY := 100.0
const HINT_TOTAL := 4           # one guard phone call per stage
const EVIDENCE_NEEDED := 6      # Ending A/D: calls answered + cameos spotted + evidence notes read
const REVEAL_TIPS := {
	"goals": "รู้แล้วว่าของที่ต้องเก็บอยู่ไหน → ดูลูกศรสีเหลืองบนจอ (40 วินาที)",
	"hides": "รู้แล้วว่าซ่อนตรงไหนได้ → ดูป้ายสีเขียวบนจอ (40 วินาที)",
	"npc": "รู้ทางเดินของเขาแล้ว → ลูกศรสีแดงบนจอบอกว่าเขาอยู่ไหน (40 วินาที)",
}
static var CLUE_TOTAL: int = Story.STAGES.filter(func(d): return d.has("clue_line")).size()   # one dream clue per stage that has one
const SKIP_HOLD := 3.0          # seconds Space must be held to skip a cutscene

const STAGES := Story.STAGES
const GUARD_CALLS := Story.GUARD_CALLS

var battery := MAX_BATTERY
var stage := 0
var goal_count := 0
var times_caught := 0
var hints := 0
var noticed := {}              # hint id -> true (calls, guard cameos); retries can't double-count
var clues := {}                # stage -> true
var fired := {}                # story trigger ids already played this stage
var phone_battery := 100.0
var threads := {}              # phone chat: thread name -> Array of {text, img}
var read_log: Array[Dictionary] = []   # every note/post-it read so far: {title, text} - re-readable in the phone
var in_cutscene := false
var skip_hold := 0.0           # seconds Space has been held in this cutscene (main.gd draws the bar)
var _skip_release := false     # just skipped one: let go of Space before the next can be skipped
var skip_cutscenes := false    # tests + settings
var sensitivity := 1.0         # settings: mouse look multiplier
var volume := 0.8              # settings: master volume 0..1
var save_path := "user://save_v4.cfg"       # tests point these elsewhere (v4: 7 stages, old saves do not fit)
var settings_path := "user://settings.cfg"
var phone_taken := false
var has_fuse := false           # stage 4: carrying the fuse from the security room to the panel in the mail room
var busy := false               # true during catch/fade: NPCs freeze
var tutorial := false           # playing stage 0 (Story.TUTORIAL) before stage 1
var phone_lock := false         # a text Tong must read first: no moving or acting until the phone has been opened (tutorial.gd)
var typing := false             # whoever is texting is still typing (phone shows it)
var clock := ""                 # HUD clock override ("" = stage clock + play time)
var heart := 30.0               # 0 = calm .. 100 = pounding (stages with "heartbeat": the doctor hears it)
var player: Node3D
var level: Node3D
var _last_cause := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	load_settings()
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_C, KEY_CTRL])
	_bind("interact", [KEY_E])
	_bind("breath", [KEY_SPACE])
	_bind("throw", [KEY_Q])
	_bind("phone", [KEY_TAB])
	_bind("phone_app_1", [KEY_1])
	_bind("phone_app_2", [KEY_2])
	_bind("phone_app_3", [KEY_3])
	_bind("flashlight", [KEY_F])
	_bind("fps", [KEY_F3])
	_bind("mouse", [KEY_M])   # let go of / grab the mouse without pausing
	_bind("pause", [KEY_ESCAPE, KEY_P])

# Cutscenes skip only on a deliberate hold of Space, never on a stray key press.
func _process(dt: float) -> void:
	var held := Input.is_action_pressed("breath")
	if not held:
		_skip_release = false
	if in_cutscene and held and not _skip_release:
		skip_hold += dt
		if skip_hold >= SKIP_HOLD:
			skip_hold = 0.0
			_skip_release = true   # still holding as the next cutscene starts: that one plays
			skip_cutscene.emit()
	else:
		skip_hold = 0.0

# Master <- SFX (office reverb + low-pass while hiding), Amb (low-pass while hiding), Tension.
func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	for bname in ["SFX", "Amb", "Tension"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bname)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())   # jumpscare layers stack up: no clipping
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.wet = 0.18
	AudioServer.add_bus_effect(sfx_bus, rev, 0)
	for b in [sfx_bus, AudioServer.get_bus_index("Amb")]:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 650.0
		AudioServer.add_bus_effect(b, lp)
		AudioServer.set_bus_effect_enabled(b, AudioServer.get_bus_effect_count(b) - 1, false)

# --- settings + save (ConfigFile in user://) ---
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(settings_path) == OK:
		sensitivity = cf.get_value("s", "sensitivity", sensitivity)
		volume = cf.get_value("s", "volume", volume)
		skip_cutscenes = cf.get_value("s", "skip_cutscenes", skip_cutscenes)
	apply_volume()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "sensitivity", sensitivity)
	cf.set_value("s", "volume", volume)
	cf.set_value("s", "skip_cutscenes", skip_cutscenes)
	cf.save(settings_path)
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

# Checkpoint at the start of each stage: what the endings depend on carries over.
func save_progress() -> void:
	if tutorial:
		return
	var cf := ConfigFile.new()
	for k in ["stage", "times_caught", "noticed", "clues", "phone_taken", "phone_battery"]:
		cf.set_value("run", k, get(k))
	cf.save(save_path)

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func load_progress() -> bool:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return false
	new_game()
	for k in ["stage", "times_caught", "noticed", "clues", "phone_taken", "phone_battery"]:
		set(k, cf.get_value("run", k, get(k)))
	hints = noticed.size()
	return true

func clear_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func new_game() -> void:
	stage = 0
	times_caught = 0
	hints = 0
	noticed.clear()
	clues.clear()
	phone_battery = 100.0
	threads.clear()
	read_log.clear()
	phone_taken = false
	tutorial = false
	reset_stage()

func reset_stage() -> void:
	battery = MAX_BATTERY
	goal_count = 0
	has_fuse = false
	busy = false
	phone_lock = false
	typing = false
	heart = 30.0
	clock = ""
	fired.clear()
	battery_changed.emit(battery)

func stage_data() -> Dictionary:
	return Story.TUTORIAL if tutorial else STAGES[stage]

# The scene file of the current stage (each stage entry in story.gd names its own: "scene").
func scene_path() -> String:
	return "res://scenes/stages/%s.tscn" % ("tutorial" if tutorial else STAGES[stage].scene)

# Data of the level actually built (test maps differ from STAGES).
func level_data() -> Dictionary:
	return level.data if is_instance_valid(level) else stage_data()

func objective_text() -> String:
	var o: String = stage_data().objective
	return o % goal_count if "%d" in o else o

func damage(amount: float, cause := "") -> void:
	battery = clampf(battery - amount, 0.0, MAX_BATTERY)
	battery_changed.emit(battery)
	if battery <= 0.0:
		game_over.emit(cause)

func heal(amount: float) -> void:
	battery = clampf(battery + amount, 0.0, MAX_BATTERY)
	battery_changed.emit(battery)

func say(text: String, secs := 3.5) -> void:
	message.emit(text, secs)

func catch(npc: Node) -> void:
	if busy:
		return
	busy = true
	times_caught += 1   # the sting plays on main.gd's jumpscare face-slam
	say(npc.catch_line, 4.0)
	caught.emit(npc)
	damage(npc.drain, npc.death_text)

func collect() -> void:
	goal_count += 1
	objective_changed.emit(objective_text())
	if level and goal_count >= level.goal:
		level.unlock_exit()
	if is_instance_valid(level) and level.has_method("goal_reached"):
		level.goal_reached(goal_count)

# Keeps one copy per title - re-reading a "read"-kind note shouldn't pile up duplicates.
func _log_read(title: String, text: String) -> void:
	if not read_log.any(func(e): return e.title == title):
		read_log.append({"title": title, "text": text})

# Pickups call this. Returns true when the item is used up.
func use(kind: String, node: Node = null) -> bool:
	match kind:
		"doc":
			sfx("bookFlip1"); say("ได้เอกสารงบดุลมา 1 ชุด", 2.0); collect()
		"file":   # this stage's goal item (story.gd "items"): picking it up reads it too
			sfx("bookFlip1")
			collect()
			var tip := "เก็บแล้ว (%d/%d)" % [goal_count, level.goal if is_instance_valid(level) else goal_count]
			if node.evidence and not noticed.has("file_%d_%s" % [stage, node.name]):
				notice("file_%d_%s" % [stage, node.name])
				tip += "\nหลักฐานเรื่องพี่สมชาย +1 (รวม %d)" % hints
			if node.text != "":
				_log_read(node.title, node.text)
				note_opened.emit(node.title, node.text, tip)
				event.emit("read")
			else:
				say("ได้ %s แล้ว — %s" % [node.title, tip], 2.5)
		"note":   # password post-it: the digits are in its text, the PC keypad wants them
			sfx("bookFlip1")
			_log_read(node.title, node.text)   # it gets taken off the wall after this: keep it in the phone
			note_opened.emit(node.title, node.text, "จดไว้ในหัวแล้ว... เอาไปใส่ที่คอมห้อง Admin"); collect()
			event.emit("read")
		"pc":
			if is_instance_valid(level) and level.dark:
				say("ต๋อง: ไฟดับ คอมเปิดไม่ติด... ต้องไปสับเบรกเกอร์ก่อน", 3.0)
				return false
			if goal_count < 3:
				say("ต๋อง: ต้องหาโพสต์อิทรหัสผ่านให้ครบ 3 ชิ้นก่อน...", 2.5)
				return false
			sfx("metalClick")
			code_requested.emit(node)   # main.gd: keypad -> submit_code()
			return false
		"breaker":
			level.restore_power()
			sfx("metalLatch", node, 6.0); sfx("hum", node)
			noise(node.global_position, 40.0)   # the whole floor hears the power come back
			say("ต๋อง: ไฟมาแล้ว! ...แต่เสียงดังขนาดนี้ เต้ต้องได้ยินแน่", 3.0)
		"fuse":
			has_fuse = true
			sfx("metalClick"); say("ต๋อง: ฟิวส์ของเครื่องสแกน... เอาไปใส่แผงวงจรที่ห้องจดหมาย", 3.0); collect()
		"fuse_box":   # in the mail room: the power goes to the scanner, the floor goes dark until you're out
			if not has_fuse:
				say("ต๋อง: แผงวงจรเครื่องสแกนนิ้ว... ช่องฟิวส์ว่าง ต้องหาฟิวส์มาใส่ (ห้อง รปภ. น่าจะมีอะไหล่)", 3.5)
				return false
			has_fuse = false
			sfx("metalLatch", node, 6.0); sfx("hum", node)
			noise(node.global_position, 20.0)
			if is_instance_valid(level):
				level.fuse_power_cut()
			say("ต๋อง: เครื่องสแกนมีไฟแล้ว! ...แต่ไฟทั้งชั้นดับ — พี่สมชายขยับ?! เปิดไฟฉาย!", 3.5); collect()
		"coffee", "coffee_goal":
			sfx("pour"); heal(40.0); say("กาแฟดำแก้วใหญ่... Social Battery +40", 2.5)
			if kind == "coffee_goal":
				collect()
		"phone":
			notice("call_%d" % stage)
			sfx("guard_talk"); say(GUARD_CALLS[mini(stage, GUARD_CALLS.size() - 1)], 5.0)
		"guard_phone":
			phone_taken = true
			sfx("metalLatch"); say("ต๋อง: (หยิบมือถือพี่สมชายมา... เอาไว้แจ้งตำรวจ)", 3.5)
		"read":   # notes stay readable; what they give you happens on every read
			sfx("bookFlip1")
			_log_read(node.title, node.text)
			var tip: String = REVEAL_TIPS.get(node.reveal, "")
			if node.reveal in REVEAL_TIPS and is_instance_valid(level):
				level.reveal(node.reveal)
			if node.evidence:
				var first := not noticed.has("note_%d_%s" % [stage, node.name])
				notice("note_%d_%s" % [stage, node.name])
				tip += ("\n" if tip != "" else "") + ("หลักฐานเรื่องพี่สมชาย +1 (รวม %d)" % hints if first else "เก็บเป็นหลักฐานไว้แล้ว")
			note_opened.emit(node.title, node.text, tip)
			event.emit("read")
			return false
		"clue":
			clues[stage] = true
			sfx("beep"); flash.emit("hospital")
			say(level_data().get("clue_line", "ต๋อง: ...ทำไมมีของแบบนี้ในออฟฟิศ?"), 4.0)
		"powerbank":
			phone_battery = minf(phone_battery + 60.0, 100.0)
			sfx("metalClick"); say("ชาร์จมือถือ +60%", 2.0)
		"throwable":
			return player.pick_throwable() if player else false
		"hide":
			if player:
				player.hide_in(node)
			return false
	return true

func text(thread: String, msg: String, img: Texture2D = null) -> void:
	if not threads.has(thread):
		threads[thread] = []
	var m := {"text": msg, "img": img}
	threads[thread].append(m)
	sfx("vibrate", null, -6.0)
	phone_message.emit(thread, m)

func set_hidden(kind: String) -> void:
	for bname in ["SFX", "Amb"]:   # last effect on each = low-pass: muffled inside
		var bus := AudioServer.get_bus_index(bname)
		AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, kind != "")
	hidden_changed.emit(kind)

# Coworkers within radius go to check the spot.
func noise(pos: Vector3, radius: float) -> void:
	if not is_instance_valid(level):
		return
	for n in level.npcs:
		if n.global_position.distance_to(pos) < radius:
			n.hear(pos)

func notice(id: String) -> void:
	noticed[id] = true
	hints = noticed.size()

# Story trigger (story_trigger.gd) -> monologue / phone text / photo, once per stage attempt.
# t = {say, secs, sfx, text: [thread, msg], photo}
func trigger(id: String, t: Dictionary) -> void:
	if fired.has(id):
		return
	fired[id] = true
	if t.get("say", "") != "":
		say(t.say, t.get("secs", 4.0))
	if t.get("sfx", "") != "":
		sfx(t.sfx)
	story_event.emit(t)

# PC keypad answer (main.gd). Wrong code = loud error beep: everyone nearby comes to look.
func submit_code(pc: Node, typed: String) -> bool:
	if typed.strip_edges() == pc.code:
		pc.used = true
		sfx("metalClick"); say("เข้าระบบได้แล้ว! ดาวน์โหลดงบดุลลับเรียบร้อย", 3.0); collect()
		return true
	sfx("beep", pc, 8.0); sfx("beep", pc, 8.0)
	noise(pc.global_position, 30.0)
	say("ต๋อง: รหัสผิด! เสียงเตือนดังลั่นห้อง...", 2.5)
	return false

func stage_clear() -> void:
	busy = true
	sfx("doorOpen_1")
	stage_cleared.emit()

func is_last_stage() -> bool:
	return stage >= STAGES.size() - 1

# Ending precedence: D (true end) = every dream clue AND his phone with enough evidence: Tong wakes
# up for real and the police already have him; B = every dream clue, never took the phone (it was
# all a dream... or was it); A = took his phone with enough evidence (answered calls, spotted him,
# read the notes about him) and report him; everything else, he follows you home.
static func resolve_ending(clue_count: int, hint_count: int, took_phone: bool) -> String:
	var dream := clue_count >= CLUE_TOTAL
	var proof := took_phone and hint_count >= EVIDENCE_NEEDED
	if dream and proof:
		return "D"
	if dream and not took_phone:
		return "B"
	if proof:
		return "A"
	return "C"

func ending() -> String:
	return resolve_ending(clues.size(), hints, phone_taken)

# --- audio helpers ---
func stream(sfx_name: String) -> AudioStream:
	var path := "res://assets/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		path = "res://assets/sfx/%s.ogg" % sfx_name
	return load(path)

func looped(sfx_name: String) -> AudioStream:
	var s: AudioStream = stream(sfx_name).duplicate()
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s

func sfx(sfx_name: String, at: Node3D = null, db := 0.0, pitch := 1.0) -> Node:
	var p = AudioStreamPlayer3D.new() if at else AudioStreamPlayer.new()
	p.stream = stream(sfx_name)
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.finished.connect(p.queue_free)
	if at:
		p.unit_size = 3.0   # falls off fast: footsteps/squeaks are a proximity cue
		at.add_child(p)
	else:
		add_child(p)
	p.play()
	return p
