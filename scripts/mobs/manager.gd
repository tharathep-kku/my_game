# หัวหน้าธนา: fast squeaky shuffle in circles; stops to stretch his neck over partitions.
# Scene: scenes/mobs/manager.tscn
class_name Manager
extends Npc

var peek_t := 5.0
var peeking := 0.0
var squeak_d := 0.0

func _init() -> void:
	display_name = "หัวหน้าธนา"
	speed = 2.3
	chase_speed = 3.4
	drain = 35.0
	anim_mode = "shuffle"
	catch_line = "หัวหน้าธนา: งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ~? มานั่งคุยกันหน่อย... แค่ 3 ชั่วโมงเอง"
	death_text = "โดนหัวหน้าธนาลากไปฟังเลกเชอร์ชีวิต 3 ชั่วโมงจนถ่านหมด"
	scare_color = Color(0.45, 0.36, 0.04)
	scare_sfx = "mutter"

# Jumpscare: neck telescopes up and looms over you, head cocked... then swoops down into your face.
# He stays where he caught you (backing up could put him in a wall); the neck fits the gap.
func jumpscare(_p: Node3D) -> float:
	peeking = 0.0
	eye_h = 1.6
	face_player()
	body.pose(0.0, "idle")
	Game.sfx("mutter", self, 4.0 + SCARE_DB)
	var gap := Vector2(Game.player.global_position.x - global_position.x, Game.player.global_position.z - global_position.z).length()
	var reach := clampf(gap - 0.4, 0.3, 1.4)   # head stops 0.4 m from your eyes
	var neck: Node3D = body.parts.Neck
	var head: Node3D = body.parts.Head
	var t := create_tween()
	t.tween_method(body.set_neck, body.neck_len, 1.4, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(head, "rotation:z", 0.4, 0.25)
	t.tween_callback(Game.sfx.bind("squeak", self, 4.0 + SCARE_DB))
	t.tween_interval(0.1)
	# neck bends ~90° toward you; the head counter-rotates so the grin stays level
	t.tween_property(neck, "rotation:x", -1.6, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(head, "rotation:x", 1.6, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(body.set_neck, 1.4, reach, 0.1)
	t.parallel().tween_property(head, "rotation:z", 0.0, 0.1)
	return 0.5

# Cutscene (stage intro): he just stands there while his neck keeps on coming, head tipping over.
func cut_stretch() -> void:
	face(get_viewport().get_camera_3d().global_position - global_position)
	body.pose(0.0, "idle")
	Game.sfx("mutter", self)
	var t := create_tween().set_parallel()
	t.tween_method(body.set_neck, 0.1, 1.6, 3.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(body.parts.Head, "rotation:z", 0.45, 3.4)

# Cutscene: neck telescopes up over the partitions, then back.
func cut_peek() -> void:
	Game.sfx("mutter", self)
	var t := create_tween()
	t.tween_method(body.set_neck, 0.1, 1.2, 1.0)
	t.tween_interval(1.6)
	t.tween_method(body.set_neck, 1.2, 0.1, 0.6)

func reset() -> void:
	super()
	peeking = 0.0
	body.set_neck(0.1)
	eye_h = 1.6

func _think(dt: float) -> void:
	if peeking > 0.0:
		peeking -= dt
		velocity = Vector3.ZERO
		var target_len := 1.1 if peeking > 0.6 else 0.1
		body.set_neck(move_toward(body.neck_len, target_len, dt * 2.5))
		eye_h = 1.66 + body.neck_len
		var old_view := view
		view = 7.0
		if sees_player():
			alert = clampf(alert + 2.5 * dt, 0.0, 1.0)
			if alert >= 1.0:
				peeking = 0.0
				body.set_neck(0.1)
				eye_h = 1.6
				spot()
		view = old_view
		return
	super(dt)
	squeak_d += velocity.length() * dt
	if squeak_d > 0.55:
		squeak_d = 0.0
		Game.sfx("squeak", self, -4.0)
	if state == "patrol":
		peek_t -= dt
		if peek_t <= 0.0:
			peek_t = randf_range(7.0, 11.0)
			peeking = 2.8
			Game.sfx("mutter", self)
			if global_position.distance_to(Game.player.global_position) < 12.0:
				Game.say("หัวหน้าธนา: งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ~?", 2.5)
