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
signal quests_changed                    # a job was offered / moved on / finished (HUD, phone)
signal hallucinate(kind: String)         # director.gd, low Social Battery: "phone" (main.gd garbles a text)
var phone_open := false                  # main.gd: the phone is up

const MAX_BATTERY := 100.0
const HINT_TOTAL := 4           # one guard phone call per stage
const EVIDENCE_NEEDED := 6      # Ending A/D: calls answered + cameos spotted + evidence notes read
const REWARD_TIPS := {"battery": "Social Battery +25", "phone": "แบตมือถือ +50%", "evidence": "หลักฐานเรื่องพี่สมชาย +1",
	"reveal": "รู้แล้วว่าของที่ต้องเก็บอยู่ไหน (ลูกศรเหลือง)"}
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
var music := 0.7               # settings: menu music 0..1
var difficulty := 1            # settings: 0 easy, 1 normal, 2 hard (catch drain + coworker speed)
var brightness := 1.0          # settings: picture brightness
var fov := 70.0                # settings: field of view (degrees)
var vhs := 1.0                 # settings: strength of the VHS / fear picture effects
var sub_size := 22             # settings: subtitle text size
var invert_y := false          # settings: mouse look up/down inverted
var fullscreen := false        # settings (desktop only)
var objective_pin := false     # settings: the objective note stays open (else it folds to a tab)
var retro := false             # settings: the original PSX look (low resolution, wobbly polygons, VHS)
var graphics := 1              # settings: 0 low, 1 medium, 2 high (HD look: shadows, ambient occlusion, volumetric fog)
var render_scale := 1.0        # settings: 3D resolution (FSR upscales on desktop)
const SETTINGS := ["sensitivity", "volume", "music", "skip_cutscenes", "difficulty", "brightness", "fov", "vhs", "sub_size", "invert_y", "fullscreen", "objective_pin", "retro", "graphics", "render_scale"]
# Profile: what this player has done across every run (main menu: chapters, archive, endings).
var profile_path := "user://profile.cfg"
var reached := -1              # furthest chapter started (-1 = only the tutorial so far)
var endings_seen := {}         # "A".."D" -> true
var docs_found := {}           # document title -> true (notes, post-its, goal items ever read)
var grades := {}               # chapter -> best performance-review grade
# This chapter so far (performance review at the end of it)
var stage_caught := 0
var stage_hints0 := 0
var stage_reads := 0
var _threads_at_start := {}    # the phone as this chapter began: a retry starts from it again
# Jobs ("งาน", story.gd "quests"): offered by text, a few steps each, story on every step.
var quests := {}               # job id -> steps done (offered = in here; finished = all steps done)
var _quests_at_start := {}
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
var hud_clock := ""             # what the HUD clock shows right now (main.gd): stamped on phone messages
var player: Node3D
var level: Node3D
var _last_cause := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	load_settings()
	load_profile()
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
	_bind("objective", [KEY_O])   # pin the objective note open / let it fold away
	_bind("pause", [KEY_ESCAPE, KEY_P])

# Cutscenes skip only on a deliberate hold of Space, never on a stray key press.
func _process(dt: float) -> void:
	_occlude_t -= dt
	if _occlude_t <= 0.0:
		_occlude_t = 0.15
		_occlude()
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
	# bus_count, not add_bus(): on the web add_bus() puts the new bus in the wrong slot of the
	# browser's mixer, the sends then loop back into Master and the browser mutes it all.
	var names := ["SFX", "Amb", "Tension", "Music"]
	AudioServer.bus_count = 1 + names.size()
	for i in names.size():
		AudioServer.set_bus_name(i + 1, names[i])
		AudioServer.set_bus_send(i + 1, "Master")
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

# The SFX reverb fits the floor: the office is soft and dead, the hospital rings, the stairwell
# echoes. [room size, damping, wet]
const ROOMS := {"carpet": [0.45, 0.75, 0.12], "tile": [0.7, 0.35, 0.24], "concrete": [0.9, 0.25, 0.34]}

func set_room(kind: String) -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var rev := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
	var r: Array = ROOMS.get(kind, ROOMS.carpet)
	if rev:
		rev.room_size = r[0]
		rev.damping = r[1]
		rev.wet = r[2]

# --- settings + save (ConfigFile in user://) ---
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(settings_path) == OK:
		for k in SETTINGS:
			set(k, cf.get_value("s", k, get(k)))
	apply_volume()

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in SETTINGS:
		cf.set_value("s", k, get(k))
	cf.save(settings_path)
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	var mb := AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_volume_db(mb, linear_to_db(maxf(music, 0.001)))
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)

# Difficulty: how much a catch drains and how fast they move.
func drain_mult() -> float:
	return [0.6, 1.0, 1.35][clampi(difficulty, 0, 2)]

func speed_mult() -> float:
	return [0.88, 1.0, 1.1][clampi(difficulty, 0, 2)]

# --- profile: kept across runs ---
func load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(profile_path) == OK:
		for k in ["reached", "endings_seen", "docs_found", "grades"]:
			set(k, cf.get_value("p", k, get(k)))

func save_profile() -> void:
	var cf := ConfigFile.new()
	for k in ["reached", "endings_seen", "docs_found", "grades"]:
		cf.set_value("p", k, get(k))
	cf.save(profile_path)

# Every document in the game, in story order: {title, text, chapter (-1 = tutorial)}.
static func all_docs() -> Array:
	var out := []
	for d in Story.TUTORIAL.get("notes", []):
		out.append({"title": d.title, "text": d.text, "chapter": -1})
	for i in Story.STAGES.size():
		for key in ["notes", "items", "postits"]:
			for d in Story.STAGES[i].get(key, []):
				out.append({"title": d.title, "text": d.text, "chapter": i})
		for q in Story.STAGES[i].get("quests", []):   # what a job's steps let you read
			for st in q.steps:
				if st.has("text"):
					out.append({"title": st.item, "text": st.text, "chapter": i})
	return out

# A new chapter starts (main.gd): remember how far the player has got, zero this chapter's stats.
func begin_stage() -> void:
	_threads_at_start = threads.duplicate(true)
	_quests_at_start = quests.duplicate()
	stage_caught = 0
	stage_hints0 = hints
	stage_reads = 0
	if not tutorial and stage > reached:
		reached = stage
		save_profile()

# Performance review: 0..100 score -> S/A/B/C/D. Side jobs done count for it (and the time they take
# is allowed for: 4 minutes each).
static func grade_for(caught: int, secs: float, found_clue: bool, evidence: int, jobs := 0) -> String:
	var score := 100 - caught * 15 - maxf(0.0, secs / 60.0 - 8.0 - jobs * 4.0) * 3.0 + (10 if found_clue else 0) + evidence * 5 + jobs * 5
	if score >= 100:
		return "S"
	if score >= 85:
		return "A"
	if score >= 70:
		return "B"
	if score >= 50:
		return "C"
	return "D"

func record_grade(g: String) -> void:
	var old: String = grades.get(stage, "")
	if old == "" or "SABCD".find(g) < "SABCD".find(old):
		grades[stage] = g
		save_profile()

func see_ending(id: String) -> bool:   # true = first time
	var first := not endings_seen.has(id)
	endings_seen[id] = true
	save_profile()
	return first

# Checkpoint at the start of each stage: what the endings depend on carries over.
func save_progress() -> void:
	if tutorial:
		return
	var cf := ConfigFile.new()
	for k in ["stage", "times_caught", "noticed", "clues", "phone_taken", "phone_battery", "quests"]:
		cf.set_value("run", k, get(k))
	cf.save(save_path)

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

# Which chapter the save is at (-1 = none), without loading it.
func saved_stage() -> int:
	var cf := ConfigFile.new()
	return cf.get_value("run", "stage", -1) if cf.load(save_path) == OK else -1

func load_progress() -> bool:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return false
	new_game()
	for k in ["stage", "times_caught", "noticed", "clues", "phone_taken", "phone_battery", "quests"]:
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
	quests.clear()
	phone_taken = false
	tutorial = false
	reset_stage()

# Retry / restart this chapter: its timed texts come again, so the copies from the last try go.
func restart_stage() -> void:
	threads = _threads_at_start.duplicate(true)
	quests = _quests_at_start.duplicate()
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
	if is_instance_valid(level) and goal_count >= level.goal:
		for id in level_quest_ids(true):   # goals done, a required job left: that's the objective now
			if not quest_done(id):
				var st := quest_step(id)
				return "งานด่วน (%s): %s" % [quest_def(id).title, st.do] if not st.is_empty() else "งานด่วน: %s" % quest_def(id).title
	if o.count("%d") == 2:   # "(done/total)": the total is the level's goal (fire stairs: Loop's Laps)
		return o % [goal_count, level.goal if is_instance_valid(level) else stage_data().get("goal", 0)]
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
	stage_caught += 1
	say(npc.catch_line, 4.0)
	caught.emit(npc)
	damage(npc.drain * drain_mult(), npc.death_text)

func collect() -> void:
	goal_count += 1
	if is_instance_valid(level) and goal_count >= level.goal and level.has_method("quests_on_goals"):
		level.quests_on_goals()   # jobs that come once the chapter's goals are done
	objective_changed.emit(objective_text())
	if level and goal_count >= level.goal and not main_quests_pending():
		level.unlock_exit()
	if is_instance_valid(level) and level.has_method("goal_reached"):
		level.goal_reached(goal_count)

# Keeps one copy per title - re-reading a "read"-kind note shouldn't pile up duplicates.
func _log_read(title: String, text: String) -> void:
	if not read_log.any(func(e): return e.title == title):
		read_log.append({"title": title, "text": text})
		stage_reads += 1
	if not docs_found.has(title):   # the main menu's archive keeps it for good
		docs_found[title] = true
		save_profile()

# ---------- jobs ("งาน") ----------
# Every job in story order, with its chapter: [{q, chapter}].
static func all_quests() -> Array:
	var out := []
	for i in Story.STAGES.size():
		for q in Story.STAGES[i].get("quests", []):
			out.append({"q": q, "chapter": i})
	return out

static func quest_def(id: String) -> Dictionary:
	for e in all_quests():
		if e.q.id == id:
			return e.q
	return {}

func quest_done(id: String) -> bool:
	return quests.has(id) and quests[id] >= quest_def(id).get("steps", []).size()

# The step Tong is on ({} = not offered yet, or finished).
func quest_step(id: String) -> Dictionary:
	if not quests.has(id) or quest_done(id):
		return {}
	return quest_def(id).steps[quests[id]]

# Jobs of the level being played (main_only: the ones the exit waits for).
func level_quest_ids(main_only := false) -> Array:
	var out := []
	for q in level_data().get("quests", []):
		if not main_only or q.get("main", false):
			out.append(q.id)
	return out

func main_quests_pending() -> bool:
	return level_quest_ids(true).any(func(id): return not quest_done(id))

# A job arrives by text; its first step's item appears (stage.gd).
func offer_quest(id: String) -> void:
	if quests.has(id):
		return
	var q := quest_def(id)
	quests[id] = 0
	text(q.from, q.ask)
	if is_instance_valid(level) and level.has_method("spawn_quest_step"):
		level.spawn_quest_step(id)
	quests_changed.emit()
	objective_changed.emit(objective_text())

# Tong did the step this item is for: its story plays, then the next step (or the payoff).
func _quest_advance(id: String) -> void:
	var q := quest_def(id)
	var st: Dictionary = q.steps[quests[id]]
	sfx(st.get("sfx", "bookFlip1"))
	quests[id] += 1
	var done := quest_done(id)
	var tip: String = ("งานเสร็จ: %s%s" % [q.title, (" · " + REWARD_TIPS[q.reward]) if REWARD_TIPS.has(q.get("reward", "")) else ""]) if done \
		else ("ต่อไป: " + q.steps[quests[id]].do)
	if st.has("text"):
		_log_read(st.item, st.text)
		note_opened.emit(st.item, st.text, tip)
	if st.has("say"):
		say(st.say, st.get("secs", 3.5))
	elif not st.has("text"):
		say("ต๋อง: (%s) — %s" % [st.item, tip], 3.0)
	if is_instance_valid(level):
		if not done and level.has_method("spawn_quest_step"):
			level.spawn_quest_step(id)
		if st.has("scare"):
			level.scare(st.scare)
		if st.has("scene"):
			level.play_scene(st.scene)
	if done:
		_quest_finish(id, q)
	quests_changed.emit()
	objective_changed.emit(objective_text())

func _quest_finish(id: String, q: Dictionary) -> void:
	if q.has("done"):
		get_tree().create_timer(2.5, false).timeout.connect(text.bind(q.from, q.done))   # the reply, a moment later
	match q.get("reward", ""):
		"battery":
			heal(25.0)
		"phone":
			phone_battery = minf(phone_battery + 50.0, 100.0)
		"evidence":
			notice("job_" + id)
		"reveal":
			if is_instance_valid(level):
				level.reveal("goals")
	if q.get("main", false) and is_instance_valid(level) and goal_count >= level.goal and not main_quests_pending():
		level.unlock_exit()

# Pickups call this. Returns true when the item is used up.
func use(kind: String, node: Node = null) -> bool:
	match kind:
		"doc":
			sfx("bookFlip1"); say("ได้เอกสารงบดุลมา 1 ชุด", 2.0); collect()
		"quest":
			_quest_advance(node.get_meta("quest"))
		"file":   # this stage's goal item (story.gd "items"): picking it up reads it too
			if node.code != "" and not node.has_meta("unlocked"):   # locked away: a code to work out
				sfx("metalClick")
				say("ต๋อง: ลิ้นชักล็อกรหัส 4 หลัก... มีลายมือเขียนไว้ว่า \"เวลาที่เขาล้มลง\"", 4.0)
				code_requested.emit(node)
				return false
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
			var cup := 28.0 if difficulty >= 2 else 40.0
			sfx("pour"); heal(cup); say("กาแฟดำแก้วใหญ่... Social Battery +%d" % cup, 2.5)
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
	var m := {"text": msg, "img": img, "time": hud_clock}
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
	if typed.strip_edges().replace(":", "") == pc.code and pc.kind == "file":   # a locked drawer: open, take it
		pc.set_meta("unlocked", true)
		sfx("metalLatch", pc, 2.0)
		pc.interact.call_deferred()
		return true
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
	if sfx_name.begins_with("footstep0"):   # footsteps sound like the floor (tools/synth_horror.py)
		var floor_kind := "carpet"
		if is_instance_valid(level) and level.get("data") is Dictionary:
			floor_kind = level.data.get("hd_floor", "carpet")
		sfx_name = "step_%s_%s" % [floor_kind, sfx_name.right(1)]
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

# The mix: one place to turn any sound up or down (dB, added to whatever the caller asks for).
# Families: "step_carpet" covers step_carpet_0..3, "creak" covers creak1..3, and so on.
# The looping beds (main.gd) take their level from here too.
const MIX := {
	# beds and music (main.gd)
	"ambience": -8.0, "drone": -12.0, "menu_theme": -3.0, "chase_theme": -2.0, "heartbeat": 0.0, "breathing": 0.0,
	"unease": -6.0, "sighting": 0.0,
	"light_hum": 0.0, "mirror_theme": 0.0,
	# Tong
	"footstep": 0.0, "step_carpet": 0.0, "step_tile": 0.0, "step_concrete": 0.0, "gasp": 0.0, "pickup": 0.0,
	# the building
	"lights_off": 0.0, "lights_on": 0.0, "metalClick": 0.0, "metalLatch": 0.0, "metalPot": 0.0, "door_slam": 0.0,
	"doorOpen": 0.0, "creak": 0.0, "chair_creak": 0.0, "printer": 0.0, "elevator_ding": 0.0, "pa_chime": 0.0,
	"siren": 0.0, "static": 0.0, "knock": 0.0, "footsteps_far": 0.0, "splash": 0.0, "pour": 0.0, "beep": 0.0,
	"flatline": 0.0, "bookFlip": 0.0,
	# the coworkers
	"hum": 0.0, "mutter": 0.0, "techspeak": 0.0, "guard_talk": 0.0, "whisper": 0.0, "squeak": 0.0, "stab": 0.0,
	"sting": 0.0,
	# each ghost's own sound (npc.gd cue)
	"pen_click": 0.0, "heel_click": 0.0, "keys_jingle": 0.0, "mop_drag": 0.0, "knuckle_tap": 0.0,
	# jumpscares
	"scare_grab": 0.0, "scare_riser": 0.0, "scare_slam": 0.0, "scare_ring": 0.0,
	# the phone and the UI
	"vibrate": 0.0, "phone_ring": 0.0, "ui_click": 0.0, "ui_hover": 0.0, "type": 0.0, "stamp": 0.0, "pen": 0.0,
}

# MIX trim for a sound (its own entry, else its family's: trailing digits / _N dropped).
static func mix_db(sfx_name: String) -> float:
	if MIX.has(sfx_name):
		return MIX[sfx_name]
	var fam := sfx_name.rstrip("0123456789").trim_suffix("_")
	return MIX.get(fam, 0.0)

# Sounds behind a wall come through it muffled and quieter: every 0.15 s a ray from Tong's ears to
# each 3D sound in the "occlude" group (Game.sfx at a place, the light hums, Pa Porn's humming).
const OCCLUDED_HZ := 1200.0
const OCCLUDED_DB := -7.0
var _occlude_t := 0.0

func _occlude() -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var ear: Vector3 = player.cam.global_position
	var space := player.get_world_3d().direct_space_state
	for p: AudioStreamPlayer3D in get_tree().get_nodes_in_group("occlude"):
		if not p.playing or p.stream_paused or not p.is_inside_tree():
			continue
		if not p.has_meta("base_db"):
			p.set_meta("base_db", p.volume_db)
		var q := PhysicsRayQueryParameters3D.create(ear, p.global_position, 1)
		var hit := space.intersect_ray(q)
		var blocked: bool = not hit.is_empty() and (hit.position as Vector3).distance_to(p.global_position) > 0.3
		p.attenuation_filter_cutoff_hz = OCCLUDED_HZ if blocked else 5000.0
		p.volume_db = p.get_meta("base_db") + (OCCLUDED_DB if blocked else 0.0)

func sfx(sfx_name: String, at: Node3D = null, db := 0.0, pitch := 1.0) -> Node:
	var p = AudioStreamPlayer3D.new() if at else AudioStreamPlayer.new()
	p.stream = stream(sfx_name)
	p.volume_db = db + mix_db(p.stream.resource_path.get_file().get_basename() if p.stream else sfx_name)
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.finished.connect(p.queue_free)
	if at:
		p.unit_size = 3.0   # falls off fast: footsteps/squeaks are a proximity cue
		p.add_to_group("occlude")
		at.add_child(p)
	else:
		add_child(p)
	p.play()
	return p
