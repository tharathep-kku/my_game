# Base coworker (the tutorial's "Mob"): patrol route -> notice (vision cone + line of sight)
# -> chase -> catch. Each coworker is its own scene in scenes/mobs/ (tune stats in the Inspector).
# Walks with NavigationAgent3D on the stage's baked NavigationMesh.
class_name Npc
extends CharacterBody3D

@export var display_name := ""
@export var speed := 2.0
@export var chase_speed := 3.6
@export var eye_h := 1.6
@export var view := 12.0          ## metres it can see
@export var fov := 80.0           ## vision cone, degrees
@export var drain := 30.0         ## Social Battery lost when it catches you
@export var rage_speed := 3.2     ## chase speed when enraged (stage chases): a little under a sprint
@export_multiline var catch_line := ""
@export var death_text := ""
@export var home_radius := 0.0    ## 0 = unbounded; >0 pins every destination (patrol/chase/search/...) within this many metres of home, so it never wanders out of its spawn room
var anim_mode := "walk"
var anim_fps := 12.0
var smooth := true        # realistic body: animate every frame (false = stop-motion even then)
var stares := false       # realistic body: the head keeps turning to follow you while it patrols
var can_freeze := true    # realistic body: watched from behind, it stops dead and turns its head round
var _freeze_t := 0.0
var _freeze_cd := 6.0
var scare_color := Color(0.5, 0.04, 0.04)   # backdrop tint of the death face-slam
var scare_sfx := ""                          # voice played with the face-slam
const SCARE_DB := -4.0   # trim on every jumpscare sound: -2 dB ≈ 80% volume
var search_spot: Area3D
var search_t := 0.0
var inv_pos := Vector3.ZERO
var inv_t := 0.0

var level: Node3D
var home: Vector3
var route: Array[Vector3] = []
var wp := 0
var state := "patrol"
var alert := 0.0
var cooldown := 3.0
var repath := 0.0
var stuck_t := 0.0
var unstick_t := 0.0
var _stuck_pos := Vector3.ZERO
var leash_pt := Vector3.ZERO
var leash_cd := 0.0
var leashed := false  # patrol drifts toward the player when too far (off by default: the director brings them near)
var lost_t := 0.0     # chase: seconds since it last saw you
var last_seen := Vector3.ZERO
var away_pos := Vector3.ZERO   # "away": where it withdraws to after a chase or a catch (director.gd)
var away_t := 0.0
var can_stalk := true          # the director may walk it to somewhere near you, out of view
var raging := false   # stage chase: comes for you and never gives up (stage.gd rage/finale)
@onready var body: Body = $Body
@onready var mark: Label3D = $Mark
@onready var agent: NavigationAgent3D = $NavigationAgent3D
var _anim_t := 0.0
var _anim_acc := 0.0

func _ready() -> void:
	_style()
	_stuck_pos = global_position

# Stage calls this once: where home is and which markers to patrol.
func init_in(lvl: Node3D, pts: Array[Vector3]) -> void:
	level = lvl
	home = global_position
	route = pts.duplicate()
	if route.is_empty():
		route.append(home)

func _style() -> void:
	pass

func reset() -> void:
	global_position = home
	velocity = Vector3.ZERO
	state = "patrol"
	alert = 0.0
	wp = 0
	repath = 0.0
	cooldown = 3.0
	stuck_t = 0.0
	unstick_t = 0.0
	_stuck_pos = home
	leash_cd = 0.0
	lost_t = 0.0
	away_t = 0.0
	raging = false
	body.scale = Vector3.ONE   # undo whatever the jumpscare bent
	body.parts.Neck.rotation = Vector3.ZERO
	body.parts.Head.rotation = Vector3.ZERO
	_freeze_t = 0.0
	_freeze_cd = 6.0

# ---------- death jumpscare ----------
# main.gd plays this while Game.busy freezes everyone: animate with tweens and return how long
# the camera stays locked on scare_target(). Each mob overrides it with its own lunge.
func jumpscare(_p: Node3D) -> float:
	face_player()
	body.pose(0.0, "idle")
	var t := create_tween()
	t.tween_property(self, "global_position", lunge_point(0.5), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	return 0.35

# Middle of the face: where the camera looks.
func scare_target() -> Vector3:
	return body.parts.Head.global_transform * Vector3(0, body.head_size / 2, 0)

# `dist` metres from the player on the line from us to them (open floor: we just walked it).
func lunge_point(dist: float) -> Vector3:
	var p: Vector3 = Game.player.global_position
	var d := global_position - p
	d.y = 0.0
	if d.length() < 0.05:
		d = -Game.player.global_basis.z
	d = d.normalized() * dist
	return Vector3(p.x + d.x, global_position.y, p.z + d.z)

func face_player() -> void:
	face(Game.player.global_position - global_position)

func _physics_process(dt: float) -> void:
	if Game.busy or Game.in_cutscene or not is_instance_valid(Game.player) or not level:
		return
	cooldown -= dt
	if raging and not state in ["chase", "search"] and not Game.player.hidden:
		spot()   # enraged: lost you in a hide spot, back on you the moment you come out
	if not _frozen(dt):
		_think(dt)
	mark.position.y = body.head_top() + 0.4
	mark.text = "" if Game.difficulty > 0 else ("!" if state in ["chase", "search", "ambush"] else ("?" if alert > 0.05 or state == "investigate" else ""))   # Easy only: no UI over their heads
	if _freeze_t > 0.0:
		pass   # held mid-step
	elif body.real and smooth:   # the realistic body moves smoothly; its pace follows its speed
		_anim_t += dt * clampf(velocity.length() / 2.0, 0.7, 1.8)
		body.pose(_anim_t, anim_mode if velocity.length() > 0.1 else "idle")
	else:
		_anim_acc += dt
		if _anim_acc >= 1.0 / anim_fps:   # jerky stepped animation
			_anim_t += _anim_acc
			_anim_acc = 0.0
			body.pose(_anim_t, anim_mode if velocity.length() > 0.1 else "idle")
	if body.real and _freeze_t <= 0.0:
		var look := 0.0
		if stares and state in ["patrol", "investigate"] and global_position.distance_to(Game.player.global_position) < 12.0:
			look = _yaw_to_player(1.5)
		body.parts.Head.rotation.y = lerp_angle(body.parts.Head.rotation.y, look, dt * 3.0)
	if cooldown <= 0.0 and not Game.player.hidden and near_player(1.1):
		Game.catch(self)

func _think(dt: float) -> void:
	match state:
		"patrol":
			# Don't let the route carry it more than half the map away from you: past that,
			# park the next stop near you instead and pick up the route again once it's close.
			var dest := _patrol_dest()
			if leashed and global_position.distance_to(Game.player.global_position) > level.leash:
				leash_cd -= dt
				if leash_cd <= 0.0:
					leash_pt = _near_player_point()
					leash_cd = 3.0
				go_to(leash_pt, speed, dt)
			elif go_to(dest, speed, dt) and dest == route[wp]:
				wp = (wp + 1) % route.size()
			var seen := sees_player()
			alert = clampf(alert + (1.6 if seen else -0.5) * dt, 0.0, 1.0)
			if alert >= 1.0:
				spot()
		"investigate":
			if go_to(inv_pos, speed * 1.3, dt) or velocity == Vector3.ZERO:
				rotation.y += dt * 1.8   # look around
				inv_t -= dt
				if inv_t <= 0.0:
					state = "patrol"
			var seen := sees_player()
			alert = clampf(alert + (2.0 if seen else -0.3) * dt, 0.0, 1.0)
			if alert >= 1.0:
				spot()
		"search":
			# Standing right at the spot is what actually gives you away (see player.gd
			# _hidden_tick: hold your breath in time or it hears you). This is just it
			# lingering there a while, looking around, before giving up.
			if go_to(search_spot.front, chase_speed, dt):
				rotation.y += dt * 1.2
				search_t -= dt
				if search_t <= 0.0 or not (Game.player.hidden and Game.player.spot == search_spot):
					state = "patrol"
					alert = 0.0
		"chase":
			# It follows you while it can see you, and for a moment after (round a corner it
			# still knows). Out of sight for longer than lose_secs(): it goes to where it last
			# saw you and searches there. A stage chase (raging) never lets go.
			# A room-locked mob (home_radius) gives up at its own doorway: otherwise it would
			# walk up to the edge of its territory and camp there, aggroed forever.
			if home_radius > 0.0 and not raging and _out_of_territory(Game.player.global_position):
				state = "patrol"
				alert = 0.0
			elif raging:
				go_to(Game.player.global_position, minf(chase_speed, rage_speed), dt)
			else:
				if sees_player(true):
					lost_t = 0.0
					last_seen = Game.player.global_position
				else:
					lost_t += dt
				if lost_t > lose_secs():
					lose_track()
				else:
					go_to(Game.player.global_position if lost_t < 1.0 else last_seen, chase_speed, dt)
		"away":
			# Withdrawn (director.gd): goes to the far side and stays there a while. It still
			# catches you if you walk into it, but it isn't looking.
			away_t -= dt
			if go_to(away_pos, speed, dt):
				velocity = Vector3.ZERO
			if away_t <= 0.0:
				state = "patrol"
				alert = 0.0

# Seconds out of sight before a chase gives up (Easy lets go sooner, Hard holds on longer).
func lose_secs() -> float:
	return [2.2, 3.2, 4.5][clampi(Game.difficulty, 0, 2)]

# Lost you: walk to where you were last seen and look around there, then back to the route.
func lose_track() -> void:
	state = "investigate"
	inv_pos = last_seen
	inv_t = 4.0
	alert = 0.3
	repath = 0.0
	lost_t = 0.0

# Director: withdraw to `pos` and keep away for `secs` (relief after a chase or a catch).
func retreat(pos: Vector3, secs: float) -> void:
	if raging:
		return
	state = "away"
	away_pos = pos
	away_t = secs
	alert = 0.0
	repath = 0.0

# Where to walk during patrol - the scripted route by default. A mob can override this to
# do something smarter than pacing a route.
func _patrol_dest() -> Vector3:
	return route[wp]

# A random reachable spot near the player, to patrol toward when the route would
# otherwise carry this coworker out past the leash range.
func _near_player_point() -> Vector3:
	var map := get_world_3d().navigation_map
	for i in 10:
		var p := NavigationServer3D.map_get_random_point(map, 1, false)
		if p.distance_to(Game.player.global_position) < 8.0:
			return p
	return Game.player.global_position

# Saw the player get into a hide spot: walk over and yank it open.
func search(s: Area3D) -> void:
	search_spot = s
	state = "search"
	alert = 1.0
	repath = 0.0
	search_t = 4.0

# Heard a noise: go look, glance around, give up. Repeated noises (a player jogging
# instead of sneaking) stack onto the same alert meter sight uses, so a few footsteps
# in a row are as damning as being seen — it doesn't need to lay eyes on you.
func hear(pos: Vector3) -> void:
	if state in ["patrol", "investigate"]:   # ("away": it isn't listening)
		state = "investigate"
		inv_pos = pos
		inv_t = 3.5
		repath = 0.0
		alert = clampf(alert + 0.35, 0.0, 1.0)
		if alert >= 1.0:
			spot()

func found_player() -> void:
	if Game.busy:
		return
	Game.sfx("metalLatch", self)
	Game.catch(self)

func spot() -> void:
	state = "chase"
	lost_t = 0.0
	last_seen = Game.player.global_position if is_instance_valid(Game.player) else global_position
	Game.sfx("sting", self, -8.0)

# Stage chase: knows where you are and keeps coming (only a hide spot it didn't see stops it).
func enrage() -> void:
	raging = true
	if state != "chase":
		spot()

# ---------- watched from behind (realistic body) ----------
# Patrolling with its back to you while you look at it: it stops dead mid-step, and its head turns
# round to you - further than a neck goes - then it walks on as if nothing happened.
func _frozen(dt: float) -> bool:
	_freeze_cd -= dt
	if _freeze_t > 0.0:
		_freeze_t -= dt
		velocity = Vector3.ZERO
		var head: Node3D = body.parts.Head
		head.rotation.y = lerp_angle(head.rotation.y, _yaw_to_player(2.6) if _freeze_t > 0.5 else 0.0, dt * (1.4 if _freeze_t > 0.5 else 6.0))
		if _freeze_t <= 0.0:
			_freeze_cd = 12.0
			alert = maxf(alert, 0.3)   # it knows you are there
		return true
	if can_freeze and body.real and state == "patrol" and _freeze_cd <= 0.0 and _watched_from_behind():
		_freeze_t = 2.8
		return true
	return false

func _watched_from_behind() -> bool:
	var p := Game.player
	if p.hidden or sees_player():
		return false
	var head := global_position + Vector3.UP * (body.head_top() - 0.15)
	var d := head.distance_to(p.cam.global_position)
	if d < 3.0 or d > 14.0 or not p.cam.is_position_in_frustum(head):
		return false
	var fwd := -global_basis.z
	var to := p.global_position - global_position
	if Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)) < deg_to_rad(110.0) and Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)) > -deg_to_rad(110.0):
		return false   # not its back
	var q := PhysicsRayQueryParameters3D.create(p.cam.global_position, head, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# Head yaw (relative to the body) that faces the player, clamped to `limit` radians.
func _yaw_to_player(limit: float) -> float:
	var d := global_basis.inverse() * (Game.player.global_position - global_position)
	return clampf(atan2(-d.x, -d.z), -limit, limit)

func near_player(r: float) -> bool:
	var d := Game.player.global_position - global_position
	return Vector2(d.x, d.z).length() < r and absf(d.y) < 1.5

func eye() -> Vector3:
	return global_position + Vector3.UP * eye_h

# Vision cone + unobstructed line to the player's eye (walls/desks/partitions block).
func sees_player(any_angle := false) -> bool:
	if Game.player.hidden:
		return false
	var target: Vector3 = Game.player.eye()
	var to := target - eye()
	if to.length() > view * (level.sight_mult() if level else 1.0):   # dark hides you, flashlight doesn't
		return false
	if not any_angle:
		var fwd := -global_basis.z
		if absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))) > deg_to_rad(fov / 2):
			return false
	var q := PhysicsRayQueryParameters3D.create(eye(), target, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# Walk along the navmesh toward target. Returns true on arrival.
func go_to(target: Vector3, spd: float, dt: float) -> bool:
	if home_radius > 0.0:
		target = _clamp_to_home(target)
	spd *= 1.2 * Game.speed_mult()   # base +20% speed, x difficulty (no creep per goal: the director sets the pressure)
	if unstick_t > 0.0:
		unstick_t -= dt
		velocity = -global_basis.z * spd
		move_and_slide()
		return false
	repath -= dt
	if repath <= 0.0 or agent.target_position.distance_to(target) > 0.5:
		agent.target_position = target
		repath = 0.4
	if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.4:
		velocity = Vector3.ZERO
		stuck_t = 0.0
		return true
	var d := agent.get_next_path_position() - global_position
	d.y = 0
	if d.length() < 0.05:   # no path yet / unreachable
		velocity = Vector3.ZERO
		return agent.is_navigation_finished()
	velocity = d.normalized() * spd
	face(d)
	move_and_slide()
	_track_stuck(dt)
	return false

# Trying to walk but barely getting anywhere for a while (wedged on a desk corner, bad
# navmesh seam): spin to a random new heading and push forward on it for a moment so it
# can shake itself loose, instead of vibrating in place forever.
func _track_stuck(dt: float) -> void:
	stuck_t += dt
	if stuck_t < 1.5:
		return
	if global_position.distance_to(_stuck_pos) < 0.3:
		var turn := deg_to_rad(randf_range(50.0, 180.0)) * (-1.0 if randf() < 0.5 else 1.0)
		rotation.y += turn
		unstick_t = 0.6
		repath = 0.0
	stuck_t = 0.0
	_stuck_pos = global_position

func _out_of_territory(pos: Vector3) -> bool:
	return Vector2(pos.x - home.x, pos.z - home.z).length() > home_radius

# Pull a destination back to the edge of home_radius if it would carry this mob out of its
# spawn room (tutorial: the training dummies must never block a doorway into another room).
func _clamp_to_home(target: Vector3) -> Vector3:
	var off := Vector2(target.x - home.x, target.z - home.z)
	if off.length() <= home_radius:
		return target
	off = off.normalized() * home_radius
	return Vector3(home.x + off.x, target.y, home.z + off.y)

func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)
