# Scripted scare: walk into the box and something happens. Lives under "Scares" in a stage scene:
# duplicate one, drag it, pick the kind in the Inspector. Move the child marker "At" to set
# where the figure stands / the sound comes from.
#   lights_out  every light on the floor dies for `secs` (coworkers see less, so does Tong)
#   figure      `preset` stands at At staring at Tong; gone when looked at (or after `secs`)
#   behind      `preset` appears right behind Tong; turn around in time and it lunges, then gone
#   sound       play `sfx` at At (a door slams down the hall, a knock inside a locker...)
extends Area3D

@export_enum("lights_out", "figure", "behind", "sound") var kind := "sound"
## Who appears (Story.BODIES key: guard, manager, sweeper, goblin, dummy, tong...)
@export var preset := "guard"
## Sound name from assets/sfx (no extension). Plays with every kind.
@export var sfx := "whisper"
## How long it lasts (lights_out) / stays if you never look (figure, behind)
@export var secs := 3.0
## Optional subtitle when it happens
@export_multiline var line := ""
## 0..1: chance it happens when you walk in (re-rolled each attempt)
@export_range(0.0, 1.0) var chance := 1.0

var done := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b == Game.player: fire())

func at() -> Vector3:
	var m := get_node_or_null("At")
	return m.global_position if m else global_position

func fire() -> void:
	if done or Game.in_cutscene or Game.busy or not is_instance_valid(Game.level):
		return
	done = true
	if randf() <= chance:
		Game.level.scare(self)
