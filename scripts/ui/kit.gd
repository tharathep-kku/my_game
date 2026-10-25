# The look of every screen (main.gd builds them with these): fonts, colours, panel and button
# styles, UI sounds. Two motifs: the CCTV feed (someone is watching) and company paperwork.
class_name Kit
extends RefCounted

const NIGHT := Color("#0d0c12")        # screen background
const PANEL := Color(0.06, 0.055, 0.08, 0.92)
const PAPER := Color("#ece5d3")
const PAPER_LINE := Color("#c9d6e3")
const INK := Color("#241d19")
const RED := Color("#d8263a")
const YELLOW := Color("#f2c94c")
const STICKY := Color("#f6df74")
const DIM := Color(0.6, 0.6, 0.68)
const CCTV := Color(0.9, 0.95, 0.88)
const GREEN := Color("#6fdc8c")

static var TITLE: Font = load("res://assets/fonts/Kanit-Bold.ttf")
static var UI: Font = load("res://assets/fonts/Kanit-Medium.ttf")
static var BODY: Font = load("res://assets/fonts/Sarabun-Regular.ttf")
static var HAND: Font = load("res://assets/fonts/Sriracha-Regular.ttf")

# Who's talking -> the colour of their name in the subtitles and chat.
const SPEAKERS := {
	"ต๋อง": Color("#9fd3ff"), "หัวหน้าธนา": Color("#ffd166"), "ป้าพร": Color("#ff8fb1"),
	"เต้": Color("#8ef0c8"), "พี่สมชาย": Color("#ff6b6b"), "พี่แหม่ม": Color("#ff9e7a"),
	"พี่แหม่ม HR": Color("#ff9e7a"), "หมอ": Color("#c5f6ff"), "แม่": Color("#ffe3a3"),
	"เบอร์ไม่รู้จัก": Color("#ff5d73"), "กลุ่ม IT": Color("#8ef0c8"), "ฝน": Color("#d7b8ff"),
}

static func speaker_color(name: String) -> Color:
	for k in SPEAKERS:
		if name.begins_with(k):
			return SPEAKERS[k]
	return Color(0.95, 0.92, 0.8)

static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 6, margin := 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb

static func paper_box(color := PAPER, margin := 26.0) -> StyleBoxFlat:
	var sb := box(color, color.darkened(0.25), 1, 3, margin)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(4, 6)
	return sb

# Buttons: a dark slip with a red bar that slides in on hover / focus.
static func button_styles(b: Button, size := 22, centered := false) -> void:
	var n := box(Color(0.08, 0.07, 0.1, 0.75), Color(1, 1, 1, 0.08), 1, 4, 10)
	n.content_margin_left = 22
	var h := n.duplicate()
	h.bg_color = Color(0.32, 0.05, 0.08, 0.92)
	h.border_color = RED
	h.border_width_left = 6
	h.set_border_width(SIDE_TOP, 0)
	h.set_border_width(SIDE_RIGHT, 0)
	h.set_border_width(SIDE_BOTTOM, 0)
	var p := h.duplicate()
	p.bg_color = RED.darkened(0.3)
	var d := n.duplicate()
	d.bg_color = Color(0.05, 0.05, 0.06, 0.5)
	for st in [["normal", n], ["hover", h], ["focus", h], ["pressed", p], ["disabled", d], ["hover_pressed", p]]:
		b.add_theme_stylebox_override(st[0], st[1])
	b.add_theme_font_override("font", UI)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.5))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT

static func button(text: String, cb: Callable, parent: Node, size := 22, width := 340, centered := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, size * 2.2)
	button_styles(b, size, centered)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.focus_entered.connect(func(): ui_sound("ui_hover", -14.0))
	b.pressed.connect(func(): ui_sound("ui_click", -8.0))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func label(text: String, size := 20, color := Color.WHITE, font: Font = null, parent: Node = null, outline := 0, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else UI)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if parent:
		parent.add_child(l)
	return l

static func rich(size := 20, parent: Node = null, font: Font = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font if font else BODY)
	r.add_theme_font_override("bold_font", UI)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	if parent:
		parent.add_child(r)
	return r

# "หัวหน้าธนา: งานคืบหน้า..." -> the name in its colour, then the line. "(...)" = a thought, grey.
static func subtitle_bbcode(text: String) -> String:
	var t := text.replace("[", "[lb]")
	if t.begins_with("(") or t.begins_with("ต๋อง: ("):   # a thought (checked first: it has a name too)
		return "[color=#b8b8c4][i]%s[/i][/color]" % t
	var i := t.find(": ")
	if i > 0 and i < 28:
		var who := t.substr(0, i)
		return "[b][color=#%s]%s[/color][/b]  %s" % [speaker_color(who).to_html(false), who, t.substr(i + 2)]
	return t

static func panel(style: StyleBox, parent: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(p)
	return p

# UI sounds go straight to Master: never muffled by a hide spot, never echo in the office reverb.
static func ui_sound(name: String, db := -8.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("Game"):
		Game.sfx(name, null, db).bus = "Master"

# The app-wide theme: Kanit for the interface, styled sliders / check boxes / line edits / scrollbars.
static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = UI
	th.default_font_size = 22
	th.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.04, 0.06), Color(1, 1, 1, 0.25), 1, 4, 10))
	th.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), RED, 2, 4, 10))
	th.set_color("font_color", "LineEdit", Color.WHITE)
	var track := box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", track)
	var fill := box(RED, Color(0, 0, 0, 0), 0, 3, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	knob.fill(Color(0, 0, 0, 0))
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			if d < 8.5:
				knob.set_pixel(x, y, Color.WHITE if d < 6.5 else RED)
	var kt := ImageTexture.create_from_image(knob)
	th.set_icon("grabber", "HSlider", kt)
	th.set_icon("grabber_highlight", "HSlider", kt)
	for on in [false, true]:   # check boxes: a light box, a red fill with a white tick when on
		var im := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		im.fill(Color(0, 0, 0, 0))
		for y in 24:
			for x in 24:
				var edge := x < 2 or y < 2 or x > 21 or y > 21
				if edge:
					im.set_pixel(x, y, Color(0.85, 0.85, 0.9))
				elif on:
					im.set_pixel(x, y, RED)
		if on:
			for i in 12:   # the tick
				var px := 6 + i
				var py := 13 + i if i < 4 else 17 - (i - 4)
				for w in 2:
					im.set_pixel(clampi(px, 0, 23), clampi(py + w, 0, 23), Color.WHITE)
		var tex := ImageTexture.create_from_image(im)
		th.set_icon("checked" if on else "unchecked", "CheckBox", tex)
	th.set_color("font_color", "CheckBox", Color(0.9, 0.88, 0.85))
	th.set_color("font_hover_color", "CheckBox", Color.WHITE)
	th.set_stylebox("focus", "CheckBox", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 4, 4))
	var sb := box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 3, 0)
	th.set_stylebox("scroll", "VScrollBar", sb)
	th.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.3), Color(0, 0, 0, 0), 0, 3, 0))
	th.set_stylebox("grabber_highlight", "VScrollBar", box(RED, Color(0, 0, 0, 0), 0, 3, 0))
	th.set_stylebox("grabber_pressed", "VScrollBar", box(RED, Color(0, 0, 0, 0), 0, 3, 0))
	th.set_stylebox("panel", "TooltipPanel", box(PANEL, RED, 1, 4, 8))
	return th
