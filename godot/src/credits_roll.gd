extends Control
## Source game/index.html#tCred: original text, cast, painting and timed roll.
## No save writes or game completion here. The host verifies the campaign first.
signal finished
const CAST := [["jp", "Jean Phil"], ["maya", "Maya"], ["theo", "Theo"], ["ama", "Ama"], ["mei", "Mei"], ["leo", "Leo"]]
const INTRO := "The kitty jar is home, and every bill is paid back to whoever it belongs to."
const WORLDS := "Your street. The big shop. Festival weekend. Group holiday. Moving day. The Bill-ding."
const CRUNCH_UNPAID := "Crunch, who still owes everyone 85p."
const CRUNCH_PAID := "Crunch, who paid everyone back their 85p. In coppers."
var roll: Control
var skip_button: Button
var playing := false
var paused := false
var elapsed := 0.0
var duration := 30.0
var roll_height := 0.0
var reduced_motion := false
var text_font: Font
var heading_font: Font
var painting: Texture2D
var content: Array[String] = []

func _ready() -> void:
	size = Vector2(960, 540)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	text_font = load("res://assets/fonts/pixelify.woff2") if ResourceLoader.exists("res://assets/fonts/pixelify.woff2") else ThemeDB.fallback_font
	heading_font = load("res://assets/fonts/silk.woff2") if ResourceLoader.exists("res://assets/fonts/silk.woff2") else ThemeDB.fallback_font
	painting = load("res://assets/title.jpg") if ResourceLoader.exists("res://assets/title.jpg") else null
	hide()

func _label(text: String, y: float, height: float, font_size: int, heading: bool = false, colour: Color = Color("f5f1ea")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(160, y)
	label.size = Vector2(640, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", heading_font if heading else text_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	roll.add_child(label)
	content.append(text)
	return label

func play(crunch_paid: bool = false, calm: bool = false) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	content.clear()
	roll = Control.new()
	roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll.size = Vector2(960, 0)
	add_child(roll)
	_label("Bill Dodgers", 0, 72, 46, true, Color("f4c542"))
	_label(INTRO, 94, 90, 24)
	_label("Starring", 220, 38, 17, true, Color("9fe0b8"))
	for i in range(CAST.size()):
		var entry: Array = CAST[i]
		var x := 270.0 + (i % 3) * 162.0
		var y := 282.0 + (i / 3) * 144.0
		var ring := Panel.new()
		ring.position = Vector2(x - 3, y - 3)
		ring.size = Vector2(102, 102)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("2a2050")
		style.border_color = Color("f4c542")
		style.set_border_width_all(3)
		style.set_corner_radius_all(51)
		ring.add_theme_stylebox_override("panel", style)
		roll.add_child(ring)
		var path: String = "res://assets/cutscenes/face-%s.png" % entry[0]
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(0, 0, texture.get_width() / 8.0, texture.get_height())
			var portrait := TextureRect.new()
			portrait.texture = atlas
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.position = Vector2.ZERO
			portrait.size = Vector2(96, 96)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Source CSS border-radius clips the background portrait to a disk.
			# Use a real CanvasItem alpha mask, not a gold outline over a square.
			var mask := Panel.new()
			mask.name = "PortraitMask"
			mask.position = Vector2(3, 3)
			mask.size = Vector2(96, 96)
			mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			var mask_style := StyleBoxFlat.new()
			mask_style.bg_color = Color("2a2050")
			mask_style.set_corner_radius_all(48)
			mask.add_theme_stylebox_override("panel", mask_style)
			ring.add_child(mask)
			mask.add_child(portrait)
		var name_label := _label(entry[1], y + 104, 28, 16, true)
		name_label.position.x = x - 24
		name_label.size.x = 144
	_label("And", 604, 38, 17, true, Color("9fe0b8"))
	_label(CRUNCH_PAID if crunch_paid else CRUNCH_UNPAID, 664, 70, 24)
	_label("Six worlds", 778, 38, 17, true, Color("9fe0b8"))
	_label(WORLDS, 840, 110, 24)
	_label("A Commune game", 994, 38, 17, true, Color("9fe0b8"))
	_label("for people who do life, together.", 1054, 50, 24, false, Color("f4c542"))
	_label("ourcommune.io", 1128, 42, 24)
	_label("Thanks for playing", 1240, 80, 36, true, Color("f4c542"))
	roll_height = 1320
	roll.size.y = roll_height
	reduced_motion = calm
	duration = clampf((roll_height + size.y) / 55.0, 22, 40) * (1.6 if calm else 1.0)
	elapsed = 0
	playing = true
	paused = false
	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.position = Vector2(816, 476)
	skip_button.size = Vector2(120, 48)
	skip_button.add_theme_font_override("font", heading_font)
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	_update_position()
	show()
	skip_button.grab_focus()
	queue_redraw()

func _update_position() -> void:
	if is_instance_valid(roll): roll.position.y = size.y - (roll_height + size.y) * clampf(elapsed / duration, 0, 1)

func tick(delta: float) -> void:
	if not playing or paused or not is_finite(delta) or delta < 0: return
	elapsed += delta
	_update_position()
	if elapsed >= duration + 0.6: skip()

func _process(delta: float) -> void: tick(delta)

func set_paused(value: bool) -> void:
	paused = value
	if is_instance_valid(skip_button): skip_button.disabled = value

func stop() -> void:
	playing = false
	paused = false
	hide()

func skip() -> void:
	if not playing or paused: return
	stop()
	finished.emit()

func _draw() -> void:
	if painting != null: draw_texture_rect(painting, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(20.0 / 255, 16.0 / 255, 42.0 / 255, 0.86))
