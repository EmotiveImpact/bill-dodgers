extends Control
## Native-only mobile menu. The source player HUD remains entirely unobstructed
## while playing. Main owns pause/story/map transitions and all game state.
signal action_requested(action: String)
const HEADER_BOTTOM := 69.0
const TAP_SIZE := 48.0
var launcher: Button
var shade: ColorRect
var panel: Panel
var heading: Label
var subtitle: Label
var resume_button: Button
var story_button: Button
var sound_button: Button
var map_button: Button
var opened := false
var replay_available := false
var _font: Font
var _touch_buttons: Dictionary = {}

static func layout(viewport: Vector2, safe: Vector2, ui_scale := 1.0) -> Dictionary:
	# Keep the existing authored header in logical coordinates. The menu itself
	# can grow when a small phone window scales the 960x540 canvas down.
	var inset := Vector2(maxf(12, safe.x), maxf(12, safe.y))
	var bounds := Rect2(inset, viewport - inset * 2)
	var width := minf(400 * ui_scale, bounds.size.x - 16 * ui_scale)
	var height := 256 * ui_scale
	var card := Rect2(Vector2(viewport.x * 0.5 - width * 0.5, viewport.y * 0.5 - height * 0.5), Vector2(width, height))
	card.position.y = clampf(card.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - card.size.y))
	var entry := Rect2(viewport.x - inset.x - 96 * ui_scale, maxf(HEADER_BOTTOM + 9, inset.y), 96 * ui_scale, TAP_SIZE * ui_scale)
	var inner := width - 32 * ui_scale
	var half := (inner - 12 * ui_scale) * 0.5
	return {"safe": bounds, "launcher": entry, "panel": card,
		"resume": Rect2(16 * ui_scale, 72 * ui_scale, inner, TAP_SIZE * ui_scale),
		"story": Rect2(16 * ui_scale, 130 * ui_scale, half, TAP_SIZE * ui_scale),
		"sound": Rect2(28 * ui_scale + half, 130 * ui_scale, half, TAP_SIZE * ui_scale),
		"map": Rect2(16 * ui_scale, 188 * ui_scale, inner, TAP_SIZE * ui_scale)}

func configure(source_font: Font, can_replay: bool, sound_enabled: bool) -> void:
	name = "MobileGameMenu"
	_font = source_font
	replay_available = can_replay
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	launcher = _button("Menu", self, "MenuButton", "open")
	launcher.tooltip_text = "Pause and open game menu"
	shade = ColorRect.new()
	shade.name = "PauseShade"
	shade.color = Color(0.025, 0.04, 0.065, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = Panel.new()
	panel.name = "PausePanel"
	panel.add_theme_stylebox_override("panel", _style(Color("15263b"), Color("7f94ac"), 18))
	shade.add_child(panel)
	heading = _label("Game paused", 26, Vector2(16, 13))
	heading.add_theme_color_override("font_color", Color("f4c542"))
	subtitle = _label("Your run is paused.", 14, Vector2(16, 46))
	subtitle.add_theme_color_override("font_color", Color("b8c7da"))
	resume_button = _button("Resume", panel, "ResumeButton", "resume")
	resume_button.add_theme_stylebox_override("normal", _style(Color("2d6a4f"), Color("86c6a3")))
	story_button = _button("Story", panel, "StoryButton", "story")
	sound_button = _button("Sound", panel, "SoundButton", "sound")
	map_button = _button("Level map", panel, "PauseMap", "map")
	map_button.tooltip_text = "Leave this run and return to level selection"
	set_sound_enabled(sound_enabled)
	close()
	relayout(Vector2(960, 540), Vector2(18, 14))

func relayout(viewport: Vector2, safe: Vector2) -> void:
	if launcher == null: return
	release_contacts()
	size = viewport
	var ui_scale := 1.0
	if is_inside_tree():
		var screen_scale := get_viewport().get_screen_transform().get_scale()
		ui_scale = maxf(1, 1 / maxf(0.01, minf(screen_scale.x, screen_scale.y)))
		# Tiny/headless windows cannot supply physical touch sizing. Never let
		# their scale produce an oversized control over gameplay or offscreen UI.
		var available := viewport - Vector2(maxf(12, safe.x), maxf(12, safe.y)) * 2
		ui_scale = minf(ui_scale, minf((available.x - 16) / 400, available.y / 256))
	var boxes := layout(viewport, safe, ui_scale)
	heading.position = Vector2(16, 13) * ui_scale
	subtitle.position = Vector2(16, 46) * ui_scale
	heading.add_theme_font_size_override("font_size", roundi(26 * ui_scale))
	subtitle.add_theme_font_size_override("font_size", roundi(14 * ui_scale))
	for button in [launcher, resume_button, story_button, sound_button, map_button]:
		button.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
	launcher.position = boxes.launcher.position
	launcher.size = boxes.launcher.size
	panel.position = boxes.panel.position
	panel.size = boxes.panel.size
	for pair in [[resume_button, "resume"], [story_button, "story"], [sound_button, "sound"], [map_button, "map"]]:
		var rect: Rect2 = boxes[pair[1]]
		pair[0].position = rect.position
		pair[0].size = rect.size

func open(context: String, sound_enabled: bool) -> void:
	release_contacts()
	opened = true
	launcher.hide()
	shade.show()
	story_button.disabled = not replay_available or context != "play"
	subtitle.text = "The story is paused." if context == "story" else "Your run is paused."
	set_sound_enabled(sound_enabled)
	if is_inside_tree(): resume_button.grab_focus()

func close() -> void:
	release_contacts()
	opened = false
	if shade != null: shade.hide()
	if launcher != null: launcher.show()

func set_sound_enabled(value: bool) -> void:
	if sound_button != null: sound_button.text = "Sound: On" if value else "Sound: Off"

func _button(caption: String, parent: Control, node_name: String, action: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("f5f1ea"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color("253a52"), Color("738aa4")))
	button.add_theme_stylebox_override("hover", _style(Color("34526e"), Color("c0d7ea")))
	button.add_theme_stylebox_override("pressed", _style(Color("172b40"), Color("f4c542")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("f4c542")))
	button.add_theme_stylebox_override("disabled", _style(Color("1d2b3c"), Color("42546c")))
	button.pressed.connect(func(): action_requested.emit(action))
	parent.add_child(button)
	return button

func _label(caption: String, font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	panel.add_child(label)
	return label

func _style(fill: Color, edge: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func _input(event: InputEvent) -> void:
	# Mouse emulation owns only one finger. Handle native GUI contacts ourselves
	# so a third finger can pause while the steering/fire thumbs remain held.
	if not is_visible_in_tree(): return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if opened or not _touch_buttons.is_empty() or (launcher.visible and launcher.get_global_rect().has_point(event.position)):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			for button in [launcher, resume_button, story_button, sound_button, map_button]:
				if button == null or not button.is_visible_in_tree() or button.disabled: continue
				if button.get_global_rect().has_point(event.position):
					_touch_buttons[event.index] = button
					button.set_pressed_no_signal(true)
					get_viewport().set_input_as_handled()
					return
		elif _touch_buttons.has(event.index):
			var button: Button = _touch_buttons[event.index]
			_touch_buttons.erase(event.index)
			button.set_pressed_no_signal(false)
			get_viewport().set_input_as_handled()
			if not event.canceled and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
			return
		if opened: get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_buttons.has(event.index):
		var button: Button = _touch_buttons[event.index]
		button.set_pressed_no_signal(button.get_global_rect().has_point(event.position))
		get_viewport().set_input_as_handled()

func release_contacts() -> void:
	for button in _touch_buttons.values():
		if is_instance_valid(button): button.set_pressed_no_signal(false)
	_touch_buttons.clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: release_contacts()
