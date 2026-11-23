# Writes assets/textures/gore/scrawl_N.png: each line of HD.SCRAWLS smeared on a wall in blood with
# a finger. Godot draws the Thai (PIL can't shape it without raqm); then each letter's strokes are
# wobbled row by row, eaten into by dry patches, and the wettest ones run.
#   Godot --path . res://tools/make_scrawls.tscn
extends Node

const W := 1024
const H := 384

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 214
	for i in HD.SCRAWLS.size():
		var img := await _text(HD.SCRAWLS[i], rng.randf_range(-0.06, 0.06))
		_bleed(img, rng)
		img.save_png("res://assets/textures/gore/scrawl_%d.png" % i)
		print("wrote scrawl_%d (%s)" % [i, HD.SCRAWLS[i]])
	get_tree().quit()

# White text on transparent, as big as fits.
func _text(text: String, tilt: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var size := 150
	while size > 40 and Kit.HAND.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > W * 0.86:
		size -= 6
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Kit.HAND)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 9)   # a finger is thicker than the font's pen
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(W, H * 0.8)
	l.pivot_offset = l.size / 2
	l.rotation = tilt
	vp.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img

func _bleed(img: Image, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.045
	var a := PackedFloat32Array()
	a.resize(W * H)
	for y in H:   # a finger, not a pen: each row pushed sideways a little, unevenly
		var shift := int(round(sin(y * 0.09 + rng.randf()) * 2.0 + noise.get_noise_2d(0, y * 3.0) * 4.0))
		for x in W:
			var sx := clampi(x - shift, 0, W - 1)
			a[y * W + x] = img.get_pixel(sx, y).a
	var out := a.duplicate()
	for y in H:   # dry patches where the finger ran out
		for x in W:
			out[y * W + x] = a[y * W + x] * clampf(noise.get_noise_2d(x, y) * 1.3 + 1.0, 0.3, 1.0)
	for k in 16:   # the wettest strokes run down the wall
		var x := rng.randi_range(40, W - 40)
		var bottom := -1
		for y in range(H - 1, -1, -1):
			if a[y * W + x] > 0.6:
				bottom = y
				break
		if bottom < 0:
			continue
		var length := rng.randf_range(20.0, H - bottom - 6.0)
		var width := rng.randf_range(1.2, 3.2)
		for y in range(bottom, mini(bottom + int(length), H - 1)):
			var w := width * (1.0 - float(y - bottom) / length * 0.5)
			for dx in range(-4, 5):
				var cov := clampf(w - absf(dx) + 0.5, 0.0, 1.0)
				var i := y * W + clampi(x + dx, 0, W - 1)
				out[i] = maxf(out[i], cov * 0.95)
	for y in H:
		for x in W:
			var v := out[y * W + x]
			var g := 0.8 + noise.get_noise_2d(x * 3.0, y * 3.0) * 0.2
			img.set_pixel(x, y, Color((0.11 + 0.2 * v) * g, 0.01, 0.012, v))
