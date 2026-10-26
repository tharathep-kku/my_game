# ป้าพร: slides without stepping, mops a wet trail, hums off-key. Step on wet = holy-water chase.
# Scene: scenes/mobs/sweeper.tscn
class_name Sweeper
extends Npc

var wet_d := 0.0
var splash_t := 0.0
var chase_t := 0.0   # an angry chase only lasts so long
var lost := 0.0      # seconds you've been out of her sight mid-chase

func _init() -> void:
	display_name = "ป้าพร"
	speed = 1.3
	chase_speed = 4.1
	drain = 30.0
	anim_mode = "slide"
	cue = "mop_drag"
	cue_every = 0.9
	cue_db = -3.0
	leashed = false   # mops her own route; never drifts toward you
	can_stalk = false
	catch_line = "ป้าพร: เหยียบพื้นเปียกป้าทำไม! เดี๋ยวพรมน้ำมนต์ให้... สาธุ! สาธุ!"
	death_text = "โดนป้าพรบ่นใส่หูพร้อมพรมน้ำมนต์จนถ่านหมด"
	scare_color = Color(0.08, 0.22, 0.45)
	scare_sfx = "splash"

# Jumpscare: head snaps sideways, holy water flicked in your eyes, then she glides into your
# face without moving her legs.
func jumpscare(_p: Node3D) -> float:
	face_player()
	body.pose(0.0, "slide")
	var head: Node3D = body.parts.Head
	var arm: Node3D = body.parts.ArmL
	var t := create_tween()
	t.tween_property(self, "global_position", lunge_point(1.4), 0.06)
	t.parallel().tween_property(head, "rotation:z", 0.6, 0.06)
	t.tween_property(arm, "rotation:x", -3.1, 0.06)
	t.tween_callback(func(): Game.sfx("splash", self, 4.0 + SCARE_DB); Game.flash.emit("holy"))
	t.tween_property(arm, "rotation:x", -2.2, 0.08)
	t.parallel().tween_property(body, "scale", Vector3(0.95, 1.08, 0.95), 0.08)   # gangly: stretches taller
	t.tween_property(self, "global_position", lunge_point(0.45), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(head, "rotation:z", -0.3, 0.12)
	return 0.45

func _style() -> void:
	var hum := AudioStreamPlayer3D.new()
	hum.stream = Game.looped("hum")
	hum.unit_size = 4.0
	hum.bus = "SFX"
	hum.autoplay = true
	hum.add_to_group("occlude")
	add_child(hum)

# She never notices by sight, only when you step on her floor.
func sees_player(any_angle := false) -> bool:
	return state == "chase" and super(any_angle)

# Stone deaf too - noise (and the random "hunch" event) can't tip her off either.
func hear(_pos: Vector3) -> void:
	pass

# Cutscene: flicks holy water toward the camera.
func cut_sprinkle() -> void:
	body.pose(0.0, "slide")
	Game.sfx("splash", self)
	var t := create_tween()
	for i in 3:
		t.tween_property(body.parts.ArmL, "rotation:x", -3.0, 0.15)
		t.tween_property(body.parts.ArmL, "rotation:x", -2.2, 0.15)
	t.tween_callback(func(): Game.sfx("splash", self))

# Cutscene: her back to you... and her head turns all the way round to look at you, joints cracking.
func cut_unscrew() -> void:
	body.pose(0.0, "idle")
	var t := create_tween()
	for i in 3:
		t.tween_callback(Game.sfx.bind("creak%d" % (i + 1), self, 0.0, 0.6))
		t.tween_property(body.parts.Head, "rotation:y", PI * (i + 1) / 3.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.12)
	t.tween_property(body.parts.Head, "rotation:z", 0.35, 0.2)
	t.tween_property(body.parts.ArmL, "rotation:x", -3.0, 0.15)
	t.parallel().tween_property(body.parts.ArmR, "rotation:x", -2.6, 0.15)

func anger() -> void:
	if state != "chase" and not Game.busy:
		spot()
		chase_t = 7.0
		lost = 0.0
		Game.say("ป้าพร: ใครเหยียบพื้นป้าาา!! สาธุ... ไปให้พ้น!", 3.0)

func reset() -> void:
	super()
	chase_t = 0.0
	lost = 0.0

# She chases along the navmesh, but only for a while: out-run her or break sight for a bit
# and she huffs off back to her mopping route.
func _think(dt: float) -> void:
	if state == "chase":
		chase_t -= dt
		lost = 0.0 if sees_player(true) else lost + dt
		if not raging and (chase_t <= 0.0 or lost > 2.5):
			state = "patrol"
			alert = 0.0
			repath = 0.0
			Game.say("ป้าพร: ฮึ่ม... รอบหน้าไม่รอดแน่ สาธุ!", 2.5)
	super(dt)
	if state == "patrol":
		wet_d += velocity.length() * dt
		if wet_d > 1.0:
			wet_d = 0.0
			level.add_wet(global_position, self)
	else:
		splash_t -= dt
		if splash_t <= 0.0:
			splash_t = 1.5
			Game.sfx("splash", self)
