# Story moment: walk into the box -> Tong says something / a phone message arrives / a sound.
# Fires once per stage attempt. Lives under "Triggers" in a stage scene: duplicate one, drag it
# where you want, and fill in the Inspector. Resize the CollisionShape3D child to change the area.
extends Area3D

## Tong's line (subtitle). Leave empty for none.
@export_multiline var say := ""
## Seconds the subtitle stays up
@export var secs := 4.0
## Phone message: who sends it (แม่ / หัวหน้าธนา / กลุ่ม IT / เบอร์ไม่รู้จัก / ...). Empty = no message.
@export var thread := ""
@export_multiline var message := ""
## Attach a photo of Tong taken from behind right now (the creepy unknown number)
@export var photo := false
## Sound name from assets/sfx (no extension), e.g. whisper, knock, elevator_ding
@export var sfx := ""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # the player
	body_entered.connect(func(b): if b == Game.player: fire())

func fire() -> void:
	var t := {"say": say, "secs": secs, "sfx": sfx, "photo": photo}
	if thread != "":
		t.text = [thread, message]
	Game.trigger(str(get_path()), t)
