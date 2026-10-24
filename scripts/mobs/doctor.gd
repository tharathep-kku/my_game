# The dream's doctor: he barely sees you, but he hears your heart (Game.heart). Running, getting
# close to him and being frightened make it pound; creeping, hiding and holding your breath calm it.
# Scene: scenes/mobs/doctor.tscn (stage with "heartbeat": true; the HUD shows the heart rate)
class_name Doctor
extends Npc

## Metres he can hear your heart from: calm .. pounding
@export var hear_range := Vector2(3.0, 24.0)
var listen_t := 1.0

func _init() -> void:
	display_name = "หมอ"
	speed = 1.9
	chase_speed = 3.4
	view = 5.0
	fov = 70.0
	drain = 35.0
	anim_fps = 8.0
	catch_line = "หมอ: ชีพจรเต้นแรงจังนะครับ... นอนลงก่อน เดี๋ยวหมอทำให้มันหยุดเต้นเอง"
	death_text = "หมอฉีดยานอนหลับให้ ต๋องหลับลึก... ลึกจนไม่ได้ตื่นขึ้นมาอีก"
	scare_color = Color(0.05, 0.3, 0.3)
	scare_sfx = "flatline"

func hear_radius() -> float:
	return lerpf(hear_range.x, hear_range.y, Game.heart / 100.0)

# Jumpscare: the scalpel goes up, and he's on you.
func jumpscare(_p: Node3D) -> float:
	face_player()
	body.pose(0.0, "idle")
	var t := create_tween()
	t.tween_property(body.parts.ArmR, "rotation:x", -2.9, 0.12)
	t.parallel().tween_property(body.parts.Head, "rotation:z", -0.4, 0.12)
	t.tween_property(self, "global_position", lunge_point(0.5), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body.parts.ArmR, "rotation:x", -1.6, 0.12)
	return 0.4

func reset() -> void:
	super()
	listen_t = 1.0

func _think(dt: float) -> void:
	super(dt)
	listen_t -= dt
	if listen_t > 0.0 or raging:
		return
	listen_t = 0.7
	var p: Node3D = Game.player
	if global_position.distance_to(p.global_position) > hear_radius():
		return
	if p.hidden:   # a pounding heart gives a hide spot away; a calm one doesn't
		if Game.heart > 65.0 and state in ["patrol", "investigate"]:
			search(p.spot)
			Game.say("หมอ: ...ได้ยินเสียงหัวใจใครเต้นแรงๆ แถวนี้นะครับ", 2.5)
	elif Game.heart > 80.0 and state != "chase":
		spot()
		Game.say("หมอ: เจอแล้ว... หัวใจเต้นแรงขนาดนี้ อาการหนักนะครับ", 2.5)
	elif state in ["patrol", "investigate"]:
		hear(p.global_position)
