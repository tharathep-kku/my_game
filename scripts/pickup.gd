# Interactable item (doc, note, pc, coffee, phone, hide spot...). Player ray hits layer 4.
# Lives in the stage scenes: select one in the editor to change what it is in the Inspector.
extends Area3D

const PROMPTS := {
	"doc": "[E] เก็บเอกสารงบดุล", "note": "[E] ดูโพสต์อิทรหัสผ่าน", "pc": "[E] ล็อกอินคอมพิวเตอร์",
	"coffee": "[E] ชงกาแฟ", "coffee_goal": "[E] ชงกาแฟ", "phone": "[E] รับสาย",
	"guard_phone": "[E] หยิบมือถือพี่สมชาย", "read": "[E] อ่าน", "clue": "[E] หยิบ... นี่มันอะไรกัน?",
	"powerbank": "[E] เก็บพาวเวอร์แบงก์", "throwable": "[E] หยิบไว้ขว้าง", "breaker": "[E] สับเบรกเกอร์ (เสียงดัง!)",
	"scanner": "[E ค้างไว้] สแกนนิ้วออกงาน", "fuse": "[E] เก็บฟิวส์", "fuse_box": "[E] ใส่ฟิวส์ที่แผงวงจร",
	"hide_desk": "[E] มุดใต้โต๊ะ", "hide_locker": "[E] ซ่อนในล็อกเกอร์", "hide_stall": "[E] หลบในห้องน้ำ",
}

## doc / note / pc / coffee / coffee_goal / phone / guard_phone / read / clue / powerbank / throwable / hide / breaker / scanner / fuse / fuse_box / file (goal: Title = its name, Text = what it says)
@export var kind := ""
@export_group("Note (read / note)")
## Heading shown in the note reader
@export var title := ""
## What the paper says. Put a real hint in it: players read notes to get an edge.
@export_multiline var text := ""
## What reading it gives you: goals = marks where this stage's goals are, hides = marks hide spots,
## npc = shows the coworker through walls for a while
@export_enum("none", "goals", "hides", "npc") var reveal := "none"
## Counts as evidence against พี่สมชาย (Ending A needs his phone + enough evidence)
@export var evidence := false
@export_group("PC")
## pc: code typed on the keypad (hide its digits in the stage's post-it notes)
@export var code := ""
@export_group("Hide spot")
## hide spots only: desk / locker / stall
@export var hide_type := ""
## hide spots: where the player's eye goes, which way it looks out, and where coworkers stand to search
@export var inside := Vector3.ZERO
@export var look := Vector3.BACK
@export var front := Vector3.ZERO

var used := false
var ringer: AudioStreamPlayer3D   # only for "phone"

# Builder use: layers + sphere shape (saved into the scene).
func setup(k: String, radius := 0.7) -> void:
	kind = k
	collision_layer = 4
	collision_mask = 0
	var s := CollisionShape3D.new()
	s.name = "Shape"
	var sp := SphereShape3D.new()
	sp.radius = radius
	s.shape = sp
	add_child(s)

# Sounds are made at runtime (not saved in scenes).
func _ready() -> void:
	if Engine.is_editor_hint() or StageBuilder.baking:
		return
	if kind == "hide" and inside == Vector3.ZERO:   # placed by hand (assets/models/locker.tscn): it opens along its blue arrow (Z)
		look = global_basis.z.normalized()
		inside = global_position
		front = global_position + look * 1.75
		front.y = 0.0
	if kind == "phone":
		ringer = AudioStreamPlayer3D.new()
		ringer.stream = Game.stream("phone_ring")
		ringer.max_distance = 30
		ringer.bus = "SFX"
		add_child(ringer)
		var t := Timer.new()
		t.wait_time = 7.0
		t.autostart = true
		t.timeout.connect(func(): if not used: ringer.play())
		add_child(t)
	elif kind == "clue":   # heart-monitor beep: findable by ear
		var beep := AudioStreamPlayer3D.new()
		beep.name = "Beep"
		beep.stream = Game.looped("beep")
		beep.unit_size = 2.0
		beep.volume_db = -8.0
		beep.bus = "SFX"
		beep.autoplay = true
		add_child(beep)

func usable() -> bool:
	return not used and (kind != "phone" or ringer.playing)

func prompt() -> String:
	if kind == "file":
		return "[E] เก็บ" + title
	return PROMPTS.get("hide_" + hide_type if kind == "hide" else kind, "[E]")

func interact() -> void:
	if kind == "scanner" or not usable() or not Game.use(kind, self):   # scanner: hold E (stage.gd)
		return
	used = true
	if ringer:
		ringer.stop()
	if is_instance_valid(Game.level) and Game.level.has_method("item_used"):
		Game.level.item_used(kind)
	# drop the item mesh so it reads as taken; machines/phones stay put
	if kind in ["doc", "note", "guard_phone", "clue", "powerbank", "throwable", "fuse", "file"]:
		for c in get_children():
			if c is Node3D and not c is CollisionShape3D:
				c.queue_free()
