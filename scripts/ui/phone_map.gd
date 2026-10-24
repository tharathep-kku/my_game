# Phone "map" app: the floor plan of this stage, only the parts Tong has walked near (fog of war).
# You (arrow), the way out once it's open, and whatever a note has revealed (yellow dots).
class_name PhoneMap
extends Control

const SEE := 3   # cells around Tong that get mapped
var explored := {}   # Vector2i -> true
var _for: Node = null   # the level this map belongs to

func reset() -> void:
	explored.clear()
	_for = null

# Called a few times a second while playing.
func reveal(pos: Vector3) -> void:
	if _for != Game.level:
		explored.clear()
		_for = Game.level
	var c := Vector2i(floori(pos.x / StageBuilder.CELL), floori(pos.z / StageBuilder.CELL))
	for dz in range(-SEE, SEE + 1):
		for dx in range(-SEE, SEE + 1):
			explored[c + Vector2i(dx, dz)] = true

func _draw() -> void:
	var lvl: Node = Game.level
	var font := Kit.UI
	if not is_instance_valid(lvl) or not lvl.get("data") or not lvl.data.has("map") or not is_instance_valid(Game.player):
		draw_string(font, Vector2(10, size.y / 2), "ไม่มีสัญญาณ", HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 16, Kit.DIM)
		return
	var grid: Array = lvl.data.map
	var h := grid.size()
	var w: int = grid[0].length()
	var cs := minf((size.x - 8) / w, (size.y - 30) / h)
	var o := Vector2((size.x - cs * w) / 2.0, 6)
	draw_rect(Rect2(o - Vector2(3, 3), Vector2(cs * w, cs * h) + Vector2(6, 6)), Color(0.02, 0.05, 0.04))
	for z in h:
		for x in w:
			if not explored.has(Vector2i(x, z)):
				continue
			var ch: String = grid[z][x]
			var col := Color(0.16, 0.42, 0.3) if ch != "#" else Color(0.55, 0.9, 0.7)
			if ch in "=DBkbH":
				col = Color(0.25, 0.55, 0.4)
			draw_rect(Rect2(o + Vector2(x, z) * cs, Vector2(cs, cs) * 0.96), col)
	var to_map := func(p: Vector3) -> Vector2: return o + Vector2(p.x, p.z) / StageBuilder.CELL * cs
	for m: Node3D in get_tree().get_nodes_in_group("beacon"):   # what notes revealed
		if m.is_inside_tree():
			draw_circle(to_map.call(m.global_position), maxf(cs * 0.45, 2.5), m.get_meta("color"))
	var p: Vector3 = Game.player.global_position
	var fwd: Vector3 = -Game.player.global_basis.z
	var a: Vector2 = to_map.call(p)
	var d := Vector2(fwd.x, fwd.z).normalized()
	var s := d.orthogonal()
	var r := maxf(cs * 0.9, 5.0)
	draw_colored_polygon(PackedVector2Array([a + d * r, a - d * r * 0.6 + s * r * 0.6, a - d * r * 0.6 - s * r * 0.6]), Color("#ff4d5e"))
	draw_string(font, Vector2(0, size.y - 6), "สำรวจแล้ว · แดง = คุณ · เหลือง/เขียว = สิ่งที่รู้", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Kit.DIM)
