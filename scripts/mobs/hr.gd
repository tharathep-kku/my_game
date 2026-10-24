# พี่แหม่ม HR: patrols her floor like anyone else, but every so often she calls Tong's name over the
# PA. When the chime ends she knows exactly where he is... unless he's in a hide spot by then.
# Scene: scenes/mobs/hr.tscn
class_name Hr
extends Npc

## Seconds between PA calls (they come faster as Tong gets things done)
@export var call_every := Vector2(24.0, 34.0)
## From the chime to the moment she knows where you are
@export var warn_secs := 3.4
var call_t := 16.0
var calling := -1.0   # >= 0 while a call counts down

func _init() -> void:
	display_name = "พี่แหม่ม HR"
	speed = 2.1
	chase_speed = 3.5
	drain = 35.0
	view = 11.0
	catch_line = "พี่แหม่ม HR: ยินดีด้วยค่ะ~ คุณต๋องได้รับอนุมัติ... ให้ทำงานล่วงเวลาตลอดชีพ ปั๊ม!"
	death_text = "โดนพี่แหม่มปั๊มตรา \"อนุมัติ\" กลางหน้าผาก แล้วนั่งกรอกแบบฟอร์มลาออก 400 หน้าจนถ่านหมด"
	scare_color = Color(0.4, 0.02, 0.08)
	scare_sfx = "pa_chime"

func reset() -> void:
	super()
	call_t = 16.0
	calling = -1.0
	body.parts.ArmL.rotation = Vector3.ZERO

# Jumpscare: the stamp goes up... and comes down on your forehead.
func jumpscare(_p: Node3D) -> float:
	calling = -1.0
	face_player()
	body.pose(0.0, "idle")
	var arm: Node3D = body.parts.ArmL
	var t := create_tween()
	t.tween_property(self, "global_position", lunge_point(0.6), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(arm, "rotation:x", -3.0, 0.16)
	t.parallel().tween_property(body.parts.Head, "rotation:z", 0.45, 0.16)
	t.tween_callback(Game.sfx.bind("metalLatch", self, 6.0 + SCARE_DB, 0.7))
	t.tween_property(arm, "rotation:x", -1.5, 0.05)
	return 0.45

# Cutscene: raises the stamp and brings it down on the desk. BANG.
func cut_stamp() -> void:
	var arm: Node3D = body.parts.ArmL
	var t := create_tween()
	t.tween_property(arm, "rotation:x", -2.8, 0.4)
	t.tween_property(arm, "rotation:x", -1.2, 0.06)
	t.tween_callback(Game.sfx.bind("metalLatch", self, 4.0, 0.7))
	t.tween_property(arm, "rotation:x", 0.0, 0.5).set_delay(0.3)

func _think(dt: float) -> void:
	super(dt)
	if raging:
		return
	if calling >= 0.0:
		calling -= dt
		if calling < 0.0:
			_ping()
	elif state == "patrol":
		call_t -= dt * (1.0 + 0.3 * Game.goal_count)
		if call_t <= 0.0:
			call_t = randf_range(call_every.x, call_every.y)
			_call()

func _call() -> void:
	calling = warn_secs
	Game.sfx("pa_chime", null, -2.0)
	Game.flash.emit("pa")
	Game.say("พี่แหม่ม HR (ประกาศ): คุณต๋อง... คุณต๋องคะ เชิญที่ฝ่ายบุคคลด่วนค่ะ  (ซ่อนตัว!)", warn_secs)

# The call is over: she knows where you are, unless you made it into a hide spot.
func _ping() -> void:
	if Game.busy or Game.in_cutscene or not is_instance_valid(Game.player):
		return
	if Game.player.hidden:
		Game.say("พี่แหม่ม HR (ประกาศ): ...ไม่อยู่เหรอคะ แปลกจัง", 2.5)
		return
	Game.say("พี่แหม่ม HR (ประกาศ): เจอแล้วค่ะ~ อยู่ตรงนั้นเองนะคะ คุณต๋อง", 2.5)
	spot()
