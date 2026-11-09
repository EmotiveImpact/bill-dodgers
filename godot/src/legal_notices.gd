extends Control
## Standalone read-only notices. The host owns navigation, pausing and saves.
## Engine attribution is read from the running binary, never reconstructed.
signal close_requested

const TAP_SIZE := 48.0
const FONT_FILES := [
	"res://legal/FONT_NOTICES.txt",
	"res://legal/Silkscreen-OFL.txt",
	"res://legal/PixelifySans-OFL.txt",
]
var heading: Label
var close_button: Button
var body: RichTextLabel
var opened := false
var safe_padding := Vector2(18, 14)
var text_font: Font
var missing_notice_paths: Array[String] = []
var _touch_index := -1
var _touch_region := ""
var _touch_last := Vector2.ZERO

static func build_text(engine_license: String, components: Array, licenses: Dictionary, font_texts: Dictionary) -> String:
	# Pure formatter: no node, filesystem, Engine API, save or network access.
	var sections: Array[String] = ["GODOT ENGINE", engine_license, "ENGINE COMPONENT COPYRIGHT NOTICES"]
	for component in components:
		sections.append(str(component.get("name", "")))
		for part in component.get("parts", []):
			var attribution: Array[String] = ["Copyright notices:"]
			for owner in part.get("copyright", []): attribution.append(str(owner))
			attribution.append("Source files:")
			for path in part.get("files", []): attribution.append(str(path))
			attribution.append("License: " + str(part.get("license", "")))
			sections.append("\n".join(attribution))
	sections.append("ENGINE AND THIRD-PARTY LICENSE TEXTS")
	var keys := licenses.keys()
	keys.sort()
	for key in keys:
		sections.append(str(key))
		sections.append(str(licenses[key]))
	sections.append("BUNDLED GAME FONT NOTICES")
	for path in FONT_FILES:
		sections.append(path.get_file())
		sections.append(str(font_texts.get(path, "Required notice unavailable: " + path)))
	return "\n\n".join(sections)

func configure(source_font: Font = null, safe: Vector2 = Vector2(18, 14)) -> void:
	text_font = source_font
	safe_padding = Vector2(maxf(0, safe.x), maxf(0, safe.y))
	if is_node_ready():
		_apply_font()
		_relayout()

func _ready() -> void:
	name = "LegalNotices"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var background := ColorRect.new()
	background.color = Color("101b2b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	heading = Label.new()
	heading.name = "Heading"
	heading.text = "Licenses"
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_color_override("font_color", Color("f4c542"))
	add_child(heading)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.tooltip_text = "Close licenses and return to the previous menu"
	close_button.pressed.connect(request_close)
	add_child(close_button)
	body = RichTextLabel.new()
	body.name = "NoticeText"
	body.bbcode_enabled = false
	body.selection_enabled = true
	body.context_menu_enabled = true
	body.shortcut_keys_enabled = true
	body.scroll_active = true
	body.scroll_following = false
	body.fit_content = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.focus_mode = Control.FOCUS_ALL
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_theme_color_override("default_color", Color("f5f1ea"))
	add_child(body)
	_apply_font()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	hide()

func _apply_font() -> void:
	var font := text_font if text_font != null else ThemeDB.fallback_font
	heading.add_theme_font_override("font", font)
	close_button.add_theme_font_override("font", font)
	body.add_theme_font_override("normal_font", font)

func _relayout() -> void:
	if body == null or not is_inside_tree(): return
	release_contacts()
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var screen_scale := get_viewport().get_screen_transform().get_scale().abs()
	var ui_scale := maxf(1.0, 1.0 / maxf(0.01, minf(screen_scale.x, screen_scale.y)))
	var padding := Vector2(maxf(12.0 * ui_scale, safe_padding.x), maxf(12.0 * ui_scale, safe_padding.y))
	var target := TAP_SIZE * ui_scale
	var close_width := 112.0 * ui_scale
	# Apply typography before assigning rectangles: stale larger font minimums
	# would otherwise keep Close too tall after returning from a small window.
	heading.add_theme_font_size_override("font_size", roundi(26.0 * ui_scale))
	close_button.add_theme_font_size_override("font_size", roundi(18.0 * ui_scale))
	body.add_theme_font_size_override("normal_font_size", roundi(18.0 * ui_scale))
	close_button.custom_minimum_size = Vector2(close_width, target)
	close_button.position = Vector2(size.x - padding.x - close_width, padding.y)
	close_button.size = Vector2(close_width, target)
	heading.position = padding
	heading.size = Vector2(maxf(0, close_button.position.x - padding.x - 12.0 * ui_scale), target)
	body.position = Vector2(padding.x, padding.y + target + 16.0 * ui_scale)
	body.size = Vector2(maxf(0, size.x - padding.x * 2), maxf(0, size.y - body.position.y - padding.y))
	body.get_v_scroll_bar().custom_minimum_size.x = target

func open() -> void:
	if not is_node_ready() or opened: return
	release_contacts()
	missing_notice_paths.clear()
	var font_texts := {}
	for path in FONT_FILES:
		if FileAccess.file_exists(path):
			var text := FileAccess.get_file_as_string(path)
			if not text.is_empty():
				font_texts[path] = text
				continue
		missing_notice_paths.append(path)
	body.text = build_text(Engine.get_license_text(), Engine.get_copyright_info(), Engine.get_license_info(), font_texts)
	opened = true
	show()
	_relayout()
	body.get_v_scroll_bar().value = 0
	close_button.grab_focus()

func close() -> void:
	# Silent host replacement is distinct from a user navigation request.
	release_contacts()
	opened = false
	hide()

func request_close() -> void:
	if not opened: return
	close()
	close_requested.emit()

func release_contacts() -> void:
	_touch_index = -1
	_touch_region = ""
	if close_button != null: close_button.set_pressed_no_signal(false)

func _scrub_scrollbar(y: float) -> void:
	var bar := body.get_v_scroll_bar()
	var rect := bar.get_global_rect()
	var fraction := clampf((y - rect.position.y) / maxf(1, rect.size.y), 0, 1)
	bar.value = lerpf(bar.min_value, maxf(bar.min_value, bar.max_value - bar.page), fraction)

func _unhandled_key_input(event: InputEvent) -> void:
	if opened and is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_close()

func _input(event: InputEvent) -> void:
	if not opened or not is_visible_in_tree(): return
	# Native touch owns its activation/scroll path, so emulated mouse events
	# cannot trigger Close twice. Real mouse selection and scrolling stay native.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.canceled:
			if _touch_index != -1: return
			_touch_index = event.index
			_touch_last = event.position
			if close_button.get_global_rect().has_point(event.position):
				_touch_region = "close"
				close_button.set_pressed_no_signal(true)
			elif body.get_v_scroll_bar().get_global_rect().has_point(event.position):
				_touch_region = "scrollbar"
				_scrub_scrollbar(event.position.y)
			elif body.get_global_rect().has_point(event.position):
				_touch_region = "scroll"
		elif event.index == _touch_index:
			var activate: bool = not event.canceled and _touch_region == "close" and close_button.get_global_rect().has_point(event.position)
			release_contacts()
			if activate: request_close()
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index != _touch_index: return
		if _touch_region == "close":
			close_button.set_pressed_no_signal(close_button.get_global_rect().has_point(event.position))
		elif _touch_region == "scrollbar":
			_scrub_scrollbar(event.position.y)
		elif _touch_region == "scroll":
			body.get_v_scroll_bar().value -= event.position.y - _touch_last.y
		_touch_last = event.position

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if opened and is_visible_in_tree(): request_close()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_contacts()
