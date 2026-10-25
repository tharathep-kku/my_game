# Phone app icon: a rounded tile with a simple drawn symbol (no icon images to keep track of).
class_name AppIcon
extends Control

var kind := "chat"   # chat / gps / docs / map / jobs
var tint := Color("#3dbb6b")

func _init(k := "chat", c := Color("#3dbb6b")) -> void:
	kind = k
	tint = c
	custom_minimum_size = Vector2(52, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(Kit.box(tint, Color(1, 1, 1, 0.25), 1, 14, 0), r)
	var c := size / 2.0
	var w := Color.WHITE
	match kind:
		"chat":
			draw_circle(c - Vector2(0, 3), 15.0, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 7), c + Vector2(-14, 18), c + Vector2(0, 10)]), w)
			for i in 3:
				draw_circle(c + Vector2(-7 + i * 7, -3), 2.4, tint)
		"gps":
			draw_arc(c, 16.0, 0.0, TAU, 32, w, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(6, 3), c + Vector2(-6, 3)]), Color("#ff4d5e"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 13), c + Vector2(6, 3), c + Vector2(-6, 3)]), w)
		"docs":
			draw_rect(Rect2(c - Vector2(12, 16), Vector2(24, 32)), w)
			for i in 4:
				draw_line(c + Vector2(-8, -9 + i * 6), c + Vector2(8, -9 + i * 6), tint, 2.0)
		"map":
			var pts := PackedVector2Array([c + Vector2(-16, -12), c + Vector2(-5, -16), c + Vector2(5, -12), c + Vector2(16, -16),
				c + Vector2(16, 12), c + Vector2(5, 16), c + Vector2(-5, 12), c + Vector2(-16, 16)])
			draw_colored_polygon(pts, w)
			draw_line(c + Vector2(-5, -16), c + Vector2(-5, 12), tint, 2.0)
			draw_line(c + Vector2(5, -12), c + Vector2(5, 16), tint, 2.0)
			draw_circle(c + Vector2(10, -2), 3.5, Color("#ff4d5e"))
		"jobs":   # a clipboard with ticks
			draw_rect(Rect2(c - Vector2(12, 14), Vector2(24, 31)), w)
			draw_rect(Rect2(c - Vector2(6, 18), Vector2(12, 7)), Color(0.8, 0.8, 0.85))
			for i in 3:
				var y := -5.0 + i * 8.0
				draw_polyline(PackedVector2Array([c + Vector2(-8, y), c + Vector2(-5, y + 3), c + Vector2(-1, y - 3)]), tint, 2.0)
				draw_line(c + Vector2(2, y), c + Vector2(8, y), tint, 2.0)
