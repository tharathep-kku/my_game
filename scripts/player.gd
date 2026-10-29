# First-person ต๋อง: walk / sprint / crouch-toggle / interact ray. Scene: scenes/player.tscn
extends CharacterBody3D

const WALK := 3.2
const SPRINT := 5.0
const SNEAK := 1.6
const STAND_H := 1.7
const CROUCH_H := 0.9
const SENS := 0.0025
const FUSE_LAMP_SAVE := 0.25   ## stage 4 after the fuse (dark until the exit): the flashlight drains this much slower

@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = shape.shape
@onready var cam: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
var crouching := false
var frozen := false
var step_dist := 0.0
var stamina := 100.0
var exhausted := false
var hidden := false
var spot: Area3D                 # hide spot we're in
var holding_breath := false
var exposure := 0.0              # seconds a coworker has been right next to our hide spot
var _pre_hide := Transform3D()
var held := false               # carrying a throwable (mug/stapler)

func _ready() -> void:
	cam.fov = Game.fov
	if not Game.retro:
		HD.flashlight(flashlight)
	if OS.has_feature("web"):   # a shadowed light re-renders the scene: too heavy for WebGL
		flashlight.shadow_enabled = false

func eye() -> Vector3:
	return cam.global_position

func _unhandled_input(e: InputEvent) -> void:
	if frozen or Game.in_cutscene or Game.phone_lock:
		return
	# Only mouse-look needs the captured mouse. Keys must work regardless: in a browser the
	# capture drops on its own (Esc, focus), and E then couldn't even get you out of a hide spot.
	if e is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventMouseMotion:
		rotate_y(-e.relative.x * SENS * Game.sensitivity)
		cam.rotation.x = clampf(cam.rotation.x - e.relative.y * SENS * Game.sensitivity * (-1.0 if Game.invert_y else 1.0), -1.4, 1.4)
		if hidden:   # peeking: only a narrow view out of the hide spot
			var base := atan2(-spot.look.x, -spot.look.z)
			rotation.y = base + clampf(wrapf(rotation.y - base, -PI, PI), -0.6, 0.6)
			cam.rotation.x = clampf(cam.rotation.x, -0.35, 0.35)
	elif held and not hidden and (e.is_action_pressed("throw") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT)):
		throw()
	elif e.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif hidden and e.is_action_pressed("interact"):
		unhide()
	elif e.is_action_pressed("crouch"):
		crouching = not crouching
	elif e.is_action_pressed("interact"):
		var f := focus()
		if f:
			f.interact()

# Interactable in front of the camera (pickup.gd), or null.
func focus() -> Node:
	var c := ray.get_collider()
	if c and c.has_method("interact") and c.usable():
		return c
	return null

func toggle_flashlight() -> void:
	if not flashlight.visible and Game.phone_battery <= 0.0:
		Game.say("ต๋อง: แบตมือถือหมด...", 1.5)
		return
	flashlight.visible = not flashlight.visible
	Game.sfx("metalClick", null, -12.0)

func pick_throwable() -> bool:
	if held:
		Game.say("ต๋อง: มือเต็มแล้ว...", 1.5)
		return false
	held = true
	Game.sfx("pickup", null, -6.0)
	return true

# Lob the held object; where it lands makes a noise coworkers go to check. It can be picked up again.
func throw() -> void:
	held = false
	Game.event.emit("throw")
	var fwd := -cam.global_basis.z
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = 0.3
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.14, 0.16, 0.14)
	s.shape = b
	rb.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	m.mesh = bm
	m.material_override = Body.mat(Color(0.9, 0.9, 0.95))
	rb.add_child(m)
	Game.level.add_child(rb)
	rb.global_position = cam.global_position + fwd * 0.5
	rb.linear_velocity = fwd * 11.0 + Vector3.UP * 2.0
	rb.angular_velocity = Vector3(randf(), randf(), randf()) * 8.0
	var landed := [false]
	rb.body_entered.connect(func(_b):
		if not landed[0]:
			landed[0] = true
			Game.sfx("metalPot%d" % randi_range(1, 3), rb)
			Game.noise(rb.global_position, 18.0))
	get_tree().create_timer(3.0, false).timeout.connect(func():
		if is_instance_valid(rb):
			Game.level.spawn_throwable(rb.global_position)
			rb.queue_free())

# Enter a hide spot. Coworkers who saw us get in come and search it.
func hide_in(s: Area3D) -> void:
	if hidden:
		return
	var witnesses: Array = Game.level.npcs.filter(func(n): return n.state == "chase" or n.sees_player())
	hidden = true
	spot = s
	exposure = 0.0
	_pre_hide = global_transform
	crouching = false
	shape.disabled = true
	velocity = Vector3.ZERO
	global_position = s.inside - Vector3.UP * (capsule.height - 0.15)
	rotation.y = atan2(-s.look.x, -s.look.z)
	cam.rotation.x = 0.0
	Game.sfx("creak%d" % randi_range(1, 3), null, -4.0)
	Game.set_hidden(s.hide_type)
	Game.event.emit("hide")
	for n in witnesses:
		n.search(s)
	# the same spot again and again: they learn it. From the third time it comes to check, seen or not
	var uses: int = s.get_meta("uses", 0) + 1
	s.set_meta("uses", uses)
	if uses >= 3 and witnesses.is_empty():
		get_tree().create_timer(randf_range(4.0, 7.0), false).timeout.connect(_checked.bind(s))

func _checked(s: Area3D) -> void:
	if not hidden or spot != s or not is_instance_valid(Game.level):
		return
	var best: Node = null
	for n in Game.level.npcs:
		var d: float = n.global_position.distance_to(global_position)
		if not n.raging and n.state in ["patrol", "investigate", "away"] and d < 22.0 and (best == null or d < best.global_position.distance_to(global_position)):
			best = n
	if best:
		best.search(s)   # standing at the spot: hold your breath (_hidden_tick) or it hears you

func unhide() -> void:
	if not hidden:
		return
	hidden = false
	spot = null
	holding_breath = false
	global_transform = _pre_hide
	shape.disabled = false
	Game.sfx("creak%d" % randi_range(1, 3), null, -4.0)
	Game.set_hidden("")

# Level torn down while we were hiding (found -> game over, quit, next stage): the slit
# overlay and muffled audio are global UI/bus state, so clear them here, not per caller.
func _exit_tree() -> void:
	if hidden:
		hidden = false
		Game.set_hidden("")

func _hidden_tick(dt: float) -> void:
	var near: Npc = null
	var d := INF
	for n in Game.level.npcs:
		var nd: float = n.global_position.distance_to(spot.front)
		if nd < d:
			d = nd
			near = n
	holding_breath = Input.is_action_pressed("breath") and stamina > 0.0
	if holding_breath:
		stamina -= 7.0 * dt   # ~14s from full: enough to outlast a search (gives up after 4s) and let it walk off
		if stamina <= 0.0:
			stamina = 0.0
			Game.sfx("gasp")
			if near and d < 4.0:
				near.found_player()
			return
	else:
		stamina = minf(stamina + 10.0 * dt, 100.0)
	# A coworker right in front of the spot hears you breathing within a second unless you hold it.
	exposure = exposure + dt if (near and d < 3.0 and not holding_breath) else maxf(exposure - dt, 0.0)
	if exposure > 1.0:
		near.found_player()

# Heart rate (stages with "heartbeat"): what Tong is doing sets where it heads; anyone close by
# makes it race. Holding your breath in a hide spot calms it fastest.
func _heart(dt: float) -> void:
	if not is_instance_valid(Game.level) or not Game.level.data.get("heartbeat", false) or Game.in_cutscene:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	var target := 30.0
	if hidden:
		target = 10.0 if holding_breath else 35.0
	elif moving:
		target = 92.0 if Vector2(velocity.x, velocity.z).length() > WALK + 0.5 else (24.0 if crouching else 50.0)
	elif crouching:
		target = 18.0
	for n in Game.level.npcs:   # someone close: it races
		var d: float = n.global_position.distance_to(global_position)
		if d < 7.0:
			target = maxf(target, lerpf(90.0, 45.0, d / 7.0) - (25.0 if holding_breath else 0.0))
	Game.heart = move_toward(Game.heart, clampf(target, 0.0, 100.0), (30.0 if target > Game.heart else (24.0 if holding_breath else 12.0)) * dt)

func _physics_process(dt: float) -> void:
	if flashlight.visible:   # ~2 minutes of light per full phone battery
		var save: float = FUSE_LAMP_SAVE if is_instance_valid(Game.level) and Game.level.get("fuse_dark") else 0.0
		Game.phone_battery = maxf(Game.phone_battery - 0.8 * (1.0 - save) * dt, 0.0)
		if Game.phone_battery <= 0.0:
			flashlight.visible = false
			Game.say("ต๋อง: แบตหมด! ...มืดสนิทเลย", 2.0)
	_heart(dt)
	if hidden:
		if not Game.busy and not Game.in_cutscene:
			_hidden_tick(dt)
		return
	var target_h := CROUCH_H if crouching else STAND_H
	capsule.height = move_toward(capsule.height, target_h, dt * 4.0)
	shape.position.y = capsule.height / 2
	cam.position.y = capsule.height - 0.15
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	var dir := Vector3.ZERO
	if not frozen and not Game.in_cutscene and not Game.phone_lock:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and not crouching and not exhausted and dir != Vector3.ZERO
	if sprinting:
		stamina -= 22.0 * dt
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			Game.sfx("gasp", null, -8.0)
	else:
		stamina = minf(stamina + 14.0 * dt, 100.0)
		if exhausted and stamina > 30.0:
			exhausted = false
	var spd := SNEAK if crouching else (SPRINT if sprinting else WALK)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()
	var speed_now := Vector2(velocity.x, velocity.z).length()
	step_dist += speed_now * dt
	if step_dist > (1.4 if crouching else 1.9):
		step_dist = 0.0
		Game.sfx("footstep0%d" % randi_range(0, 3), self, -14.0 if crouching else -6.0)
		if not crouching:   # sneaking is silent; walking still carries, running carries a lot farther
			Game.noise(global_position, 21.0 if spd == SPRINT else 14.0)
	cam.position.y += sin(Time.get_ticks_msec() * 0.012) * 0.03 * minf(speed_now / WALK, 1.0)  # head bob
