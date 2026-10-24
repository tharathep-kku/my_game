# หุ่นซ้อม: faceless training mannequin for the tutorial. Walks the route, or (stay) stands in one
# spot slowly turning to look around. Catching you costs nothing: back to the last step.
# Scene: scenes/mobs/dummy.tscn
class_name Dummy
extends Npc

## Stand still and slowly turn (a watcher) instead of walking the route
@export var stay := false

func _init() -> void:
	display_name = "หุ่นซ้อม"
	speed = 1.4
	chase_speed = 2.8
	view = 10.0
	fov = 70.0
	drain = 0.0
	leashed = false
	catch_line = "หุ่นซ้อม: ...(ไม่มีหน้า แต่รู้สึกได้ว่ามันจ้องอยู่)  โดนจับแล้ว! ลองใหม่"
	death_text = ""
	scare_color = Color(0.3, 0.27, 0.22)
	scare_sfx = "whisper"

func _think(dt: float) -> void:
	if stay and state == "patrol":
		velocity = Vector3.ZERO
		rotation.y += dt * 0.6
		alert = clampf(alert + (1.6 if sees_player() else -0.5) * dt, 0.0, 1.0)
		if alert >= 1.0:
			spot()
		return
	super(dt)
