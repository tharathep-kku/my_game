# Friendly coworker for the daytime intro (stage 0): busy at their post, stops and chats when you
# walk up and press E. Harmless: no vision, no chase (the night versions are scripts/mobs/*).
# Lives under "Coworkers" in scenes/stages/tutorial.tscn: who they are (Body > Preset), what they
# say and how they work are all in the Inspector.
class_name Coworker
extends AnimatableBody3D

@export var display_name := ""
## What they say, one line per E press (goes round again after the last)
@export var lines: PackedStringArray = []
## stand = at their post, looking around · walk = paces to `Walk To` and back · mop = same, sliding
## with the mop · type = busy with both hands on what's in front of them
@export_enum("stand", "walk", "mop", "type") var work := "stand"
## walk / mop: the other end of the path (position in the stage)
@export var walk_to := Vector3.ZERO
@export var speed := 1.1
## What they say on the way out when night falls
@export var bye := ""
## When they go home: 0 = as soon as the daylight starts to go, 1 = last one out
@export_range(0.0, 1.0) var leave_at := 0.5

var kind := "talk"   # player.gd / stage.gd read .kind on whatever the interact ray hits
var talked := false
var _line := 0
var _from := Vector3.ZERO
var _yaw := 0.0
var _outbound := true
var _rest := 0.0    # walk / mop: pause at each end
var _chat := 0.0    # keeps facing you for a moment after talking
var _t := 0.0
var _acc := 0.0
@onready var body: Body = $Body

# Builder use: solid to the player (layer 1) + hit by the interact ray (layer 4), saved in the scene.
func setup(preset: String) -> void:
	collision_layer = 5
	collision_mask = 0
	sync_to_physics = false   # moved by hand below
	var s := CollisionShape3D.new()
	s.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	s.shape = cap
	s.position.y = 0.85
	add_child(s)
	var b := Body.new()
	b.name = "Body"
	b.preset = preset
	add_child(b)

func _ready() -> void:
	if StageBuilder.baking:
		set_physics_process(false)
		return
	if Story.BODIES.has(body.preset + "_day"):   # by day they still look like themselves
		body.preset += "_day"
	_from = global_position
	_yaw = rotation.y
	if work == "mop":   # ป้าพร hums while she mops
		var hum := AudioStreamPlayer3D.new()
		hum.stream = Game.looped("hum")
		hum.unit_size = 3.0
		hum.volume_db = -6.0
		hum.bus = "SFX"
		hum.autoplay = true
		add_child(hum)

func usable() -> bool:
	return not lines.is_empty()

func prompt() -> String:
	return "[E] คุยกับ" + display_name

func interact() -> void:
	Game.say(lines[_line % lines.size()], 4.0)
	_line += 1
	_chat = 4.0
	talked = true
	Game.event.emit("talk")

func _physics_process(dt: float) -> void:
	_t += dt
	_chat = maxf(_chat - dt, 0.0)
	var p := Game.player
	var moving := false
	if _chat > 0.0 or (is_instance_valid(p) and not Game.in_cutscene and global_position.distance_to(p.global_position) < 2.6):
		_turn(p.global_position - global_position, dt)   # someone's here: stop and look at them
	elif work in ["walk", "mop"] and _from.distance_to(walk_to) > 0.5:
		moving = _walk(dt)
	elif work == "stand":
		rotation.y = lerp_angle(rotation.y, _yaw + sin(_t * 0.5) * 0.7, dt * 2.0)
	else:
		rotation.y = lerp_angle(rotation.y, _yaw, dt * 4.0)
	_acc += dt
	if _acc >= 1.0 / 12.0:   # same stepped animation as the mobs
		_acc = 0.0
		if moving:
			body.pose(_t, "slide" if work == "mop" else "walk")
		else:
			body.pose(_t, "idle")
			if work == "type" and _chat <= 0.0:
				body.parts.ArmL.rotation.x = -1.25 + sin(_t * 13.0) * 0.12
				body.parts.ArmR.rotation.x = -1.25 + cos(_t * 11.0) * 0.12

func _walk(dt: float) -> bool:
	if _rest > 0.0:
		_rest -= dt
		return false
	var to := (walk_to if _outbound else _from) - global_position
	to.y = 0.0
	if to.length() < 0.15:
		_outbound = not _outbound
		_rest = 2.0
		return false
	_turn(to, dt)
	global_position += to.normalized() * speed * dt
	return true

func _turn(dir: Vector3, dt: float) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), dt * 6.0)
