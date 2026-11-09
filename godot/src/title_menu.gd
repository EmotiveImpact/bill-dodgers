extends Control
## Original title painting and arcade attract roll; no progress/reset bypass.
const Campaign = preload("res://src/campaign_progression.gd")
const Story = preload("res://src/story_player.gd")
const LegalNotices = preload("res://src/legal_notices.gd")
const SaveStore = preload("res://src/save_store.gd")
const GOLD := Color("f4c542")
const INK := Color("14102a")
var game
var state: Dictionary
var page := "press"
var elapsed := 0.0
var opened_at := -1.0
var idle := 0.0
var attract_time := 0.0
var attracting := false
var suspended := false
var reduce_motion := false
var painting: Texture2D
var controls: Control
var attract
var buttons: Dictionary = {}
var layout_size := Vector2.ZERO
var open_to_menu := false
var legal
var content_scroll: ScrollContainer
var panel_rect := Rect2()
var screen_transform := Transform2D()
var last_safe := Vector2.ZERO
var touch_index := -1
var touch_button: Button
var touch_start := Vector2.ZERO
var touch_last := Vector2.ZERO
var touch_moved := false
var touch_scroll: ScrollContainer
var touch_page := ""

func configure(host, menu: bool = false) -> void:
	game = host; painting = host.title; open_to_menu = menu
	state = Campaign.snapshot(game.save, game.catalog)

func _ready() -> void:
	name = "TitleMenu"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_title_input)
	attract = Story.new(); add_child(attract)
	attract.z_index = 0; attract.set_process_input(false)
	attract.finished.connect(func(_id, _skipped):
		if attracting: end_attract())
	controls = Control.new(); controls.mouse_filter = Control.MOUSE_FILTER_IGNORE; controls.z_index = 1; add_child(controls)
	legal = LegalNotices.new()
	legal.configure(game.ui_font, game.safe_padding)
	add_child(legal)
	legal.close_requested.connect(func():
		release_contacts()
		opened_at = elapsed
		if buttons.has("licenses"): buttons.licenses.grab_focus())
	get_viewport().size_changed.connect(_layout)
	show_page("menu" if open_to_menu else "press")
	_layout()

func _button(label: String, key: String, callback: Callable, main: bool = false) -> Button:
	var button := Button.new(); button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.text = label
	button.add_theme_font_override("font", game.ui_font); button.add_theme_font_size_override("font_size", 19)
	for variant in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if main else Color(0.078, 0.063, 0.165, 0.95)
		if variant == "hover": style.bg_color = style.bg_color.lightened(0.13)
		if variant == "pressed": style.bg_color = style.bg_color.darkened(0.12)
		style.border_color = GOLD if variant == "focus" else Color("857483")
		style.set_border_width_all(2 if variant == "focus" else 1); style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(variant, style)
		button.add_theme_color_override("font_color" if variant == "normal" else "font_%s_color" % variant, INK if main else Color("f5f1ea"))
	button.pressed.connect(func():
		# Prevent the opening tap/key repeat from also activating the new menu.
		if legal.opened or suspended or (page != "press" and elapsed - opened_at < 0.45): return
		callback.call(), CONNECT_DEFERRED)
	controls.add_child(button); buttons[key] = button
	return button

func _label(text: String, font_size: int = 20, wrap: bool = false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", game.ui_font); label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f1ea")); label.add_theme_color_override("font_outline_color", INK); label.add_theme_constant_override("outline_size", 4)
	controls.add_child(label); return label

func show_page(value: String) -> void:
	release_contacts()
	end_attract()
	content_scroll = null
	page = value; idle = 0; opened_at = elapsed
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()
	buttons.clear()
	match page:
		"press":
			_button("Press start", "start", func(): show_page("menu"), true)
			var hint := _label("Tap or press Enter", 17); hint.name = "Hint"
		"menu":
			var continued: bool = not state.verified_cleared.is_empty()
			_button("Story complete" if state.story_complete else ("Continue story" if continued else "Story mode"), "story", func():
				if continued: game._show_campaign()
				else: start_story(), true)
			if continued: _button("New story", "new", func(): show_page("reset"))
			_button("Free play / stage previews", "free", func(): game._show_menu())
			_button("Story scenes", "scenes", func(): show_page("scenes"))
			if state.credits_unlocked: _button("The credits", "credits", func(): game._show_credits())
			_button("How to play", "help", func(): show_page("help"))
			_button("Licenses", "licenses", func():
				release_contacts()
				legal.configure(game.ui_font, game.safe_padding)
				legal.open())
			content_scroll = ScrollContainer.new()
			content_scroll.name = "MenuScroll"
			content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			controls.add_child(content_scroll)
			var list := VBoxContainer.new()
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_scroll.add_child(list)
			for button in buttons.values():
				controls.remove_child(button)
				list.add_child(button)
		"help":
			_label("How to play", 30).name = "Heading"
			var help := _label("Phone\nJoystick on the left moves. Push up to aim, down to duck. Jump, Shoot and Special on the right.\n\nKeyboard\nArrows move, Up aims, Z jumps, Space or X shoots, C special.\n\nGoal\nChase the robots, win back the kitty jar, and pay every bill back to whoever it belongs to.", 20, true)
			help.name = "Copy"; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button("Back", "back", func(): show_page("menu"), true)
		"reset":
			_label("Start a new story?", 30).name = "Heading"
			var copy := _label("Your native cleared levels, coins, receipts and earned skills will be reset. The story starts again from your street. Your web save is separate.", 22, true)
			copy.name = "Copy"; copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button("Keep my story", "back", func(): show_page("menu"), true)
			_button("Yes, start again", "reset", reset_story)
		"scenes":
			_label("Story scenes", 28).name = "Heading"
			var scroll := ScrollContainer.new(); scroll.name = "Scenes"; controls.add_child(scroll)
			var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); scroll.add_child(box)
			for id in Campaign.story_library(game.save, game.catalog):
				var button := _button(str(game.story.data.scenes.get(id, {}).get("title", id)), id, func(): game._open_story(id))
				controls.remove_child(button); box.add_child(button); button.custom_minimum_size = Vector2(0, 42)
			_button("Back", "back", func(): show_page("menu"), true)
	if page in ["help", "reset"]:
		content_scroll = ScrollContainer.new()
		content_scroll.name = "CopyScroll"
		content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		controls.add_child(content_scroll)
		var copy := controls.get_node("Copy")
		controls.remove_child(copy)
		content_scroll.add_child(copy)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if page != "press":
		_label("Scroll for more ↓", 14).name = "ScrollHint"
	_layout(); queue_redraw()

func reset_story() -> void:
	if page != "reset": return
	# Explicit in-game confirmation, atomic SaveStore write. Preserve old progress
	# in memory if storage refuses the reset rather than silently reporting success.
	var fresh := {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0,"friend":game.character,"party_mode":game.party_session.runtime.mode,"party_mate":game.party_session.runtime.p2,"party_confirmed":bool(game.save.get("party_confirmed",false)),"map_at":"HOME","map_shown":[]}
	if SaveStore.write_save(fresh) != OK:
		content_scroll.get_node("Copy").text = "The new story could not be saved on this device. Your current story is still here."
		return
	game.save = fresh; game.level_id = ""; game.world_selected = 1
	start_story()

func start_story() -> void:
	# Source startStory always presents the introduction before revealing the map.
	# The normal host records seen/skip and returns to this preserved map; the
	# first stage then uses its existing guarded entry without replaying the intro.
	var host = game
	host._show_campaign()
	host._open_story("1-intro")

func start_attract() -> void:
	if page != "press" or reduce_motion or suspended: return
	attracting = true; attract_time = 0
	if not attract.play("title"): attracting = false; return
	attract.next_button.hide(); attract.skip_button.hide(); attract.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attract.set_process_input(false)
	queue_redraw()

func end_attract() -> void:
	if not attracting: return
	attracting = false
	attract.stop(); idle = 0; attract_time = 0
	queue_redraw()

func tick(delta: float) -> void:
	if suspended: return
	elapsed += delta
	if page == "press":
		idle += delta
		if attracting:
			attract_time += delta
			if attract_time >= 19.8: end_attract()
		elif idle >= 7 and not reduce_motion: start_attract()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or game.mode != "menu": return
	if layout_size != get_viewport_rect().size or screen_transform != get_viewport().get_screen_transform() or last_safe != game.safe_padding: _layout()
	tick(maxf(delta, 0.0))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_contacts()
		suspended = true
		if is_instance_valid(attract): attract.set_paused(true)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false; idle = 0
		if is_instance_valid(attract): attract.set_paused(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(controls):
		# The overlay handles the same notification itself. Never navigate behind it.
		if legal.opened: return
		show_page("press" if page == "menu" else "menu")

func _title_input(event: InputEvent) -> void:
	if legal.opened: return
	if event is InputEventMouseMotion and not attracting: idle = 0
	var press: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION)
	if press and page == "press": show_page("menu"); accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if legal.opened or not is_visible_in_tree() or game.mode != "menu" or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if page == "press" and key in [KEY_ENTER, KEY_SPACE, KEY_Z]: show_page("menu"); get_viewport().set_input_as_handled()
	elif page == "press": end_attract(); idle = 0
	elif key == KEY_ESCAPE: show_page("press" if page == "menu" else "menu"); get_viewport().set_input_as_handled()

func release_contacts() -> void:
	if is_instance_valid(touch_button): touch_button.set_pressed_no_signal(false)
	touch_index = -1
	touch_button = null
	touch_scroll = null
	touch_moved = false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or game.mode != "menu" or legal.opened: return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.canceled:
			if suspended or touch_index != -1: return
			touch_index = event.index
			touch_start = event.position
			touch_last = event.position
			touch_page = page
			for button in buttons.values():
				if button.get_global_rect().has_point(event.position):
					var ancestor: Node = button.get_parent()
					var clipped := false
					while ancestor != controls:
						if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(event.position): clipped = true
						ancestor = ancestor.get_parent()
					if not clipped:
						touch_button = button
						button.set_pressed_no_signal(true)
			if content_scroll != null and content_scroll.get_global_rect().has_point(event.position): touch_scroll = content_scroll
			var scenes := controls.get_node_or_null("Scenes")
			if scenes != null and scenes.get_global_rect().has_point(event.position): touch_scroll = scenes
		elif event.index == touch_index:
			var button := touch_button
			var activate: bool = not event.canceled and not touch_moved and touch_page == page and not suspended
			if button != null: activate = activate and button.get_global_rect().has_point(event.position)
			release_contacts()
			if activate:
				if button != null: button.pressed.emit()
				elif page == "press": show_page("menu")
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index != touch_index: return
		if (event.position - touch_start).length() > 8.0 * _density():
			touch_moved = true
			if touch_button != null: touch_button.set_pressed_no_signal(false)
		if touch_scroll != null:
			touch_scroll.scroll_vertical -= roundi(event.position.y - touch_last.y)
		touch_last = event.position

func _density() -> float:
	var scale := get_viewport().get_screen_transform().get_scale().abs()
	return maxf(1.0, 1.0 / maxf(0.01, minf(scale.x, scale.y)))

func _layout() -> void:
	if not is_instance_valid(controls): return
	release_contacts()
	layout_size = get_viewport_rect().size
	screen_transform = get_viewport().get_screen_transform()
	last_safe = game.safe_padding
	size = layout_size
	controls.size = size
	var density := _density()
	var pad: Vector2 = game.safe_padding.max(Vector2(16, 16) * density)
	# ScrollContainer scroll offsets are integral; ceil targets so the last
	# row cannot leave a fractional clipped edge after ensure_control_visible.
	var target := ceilf(48.0 * density)
	var gap := 8.0 * density
	for button in buttons.values():
		button.add_theme_font_size_override("font_size", roundi(18 * density))
		button.custom_minimum_size = Vector2(0, target)
	if page == "press":
		buttons.start.size = Vector2(minf(260 * density, size.x - 2 * pad.x), target)
		buttons.start.position = Vector2(clampf(size.x * 0.72 - buttons.start.size.x / 2, pad.x, size.x - pad.x - buttons.start.size.x), size.y - pad.y - target - 32 * density)
		var hint: Label = controls.get_node("Hint")
		hint.add_theme_font_size_override("font_size", roundi(16 * density))
		hint.position = buttons.start.position + Vector2(0, target + 4 * density)
		hint.size = Vector2(buttons.start.size.x, 26 * density)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif page == "menu":
		# Preserve the source cast on the left; a scrollable right-hand menu
		# keeps real screen-sized targets instead of shrinking into a bottom row.
		content_scroll.position = Vector2(maxf(pad.x, size.x * 0.56), maxf(pad.y, size.y * 0.44))
		content_scroll.size = (size - content_scroll.position - pad - Vector2(0, 24 * density)).floor() - Vector2.ONE
		content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		content_scroll.follow_focus = true
		content_scroll.get_child(0).add_theme_constant_override("separation", roundi(gap))
		var hint: Label = controls.get_node("ScrollHint")
		hint.add_theme_font_size_override("font_size", roundi(14 * density))
		hint.position = content_scroll.position + Vector2(0, content_scroll.size.y + 2 * density)
		hint.size = Vector2(content_scroll.size.x, 22 * density)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		panel_rect = Rect2(pad, size - pad * 2)
		var heading: Label = controls.get_node("Heading")
		heading.add_theme_font_size_override("font_size", roundi(26 * density))
		heading.position = panel_rect.position + Vector2(gap, 0)
		heading.size = Vector2(panel_rect.size.x - gap * 2, target)
		var scroll: ScrollContainer = controls.get_node("Scenes") if page == "scenes" else content_scroll
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.follow_focus = true
		scroll.position = panel_rect.position + Vector2(gap, target + gap)
		scroll.size = Vector2(panel_rect.size.x - gap * 2, panel_rect.size.y - target * 2 - gap * 3 - 24 * density)
		var hint: Label = controls.get_node("ScrollHint")
		hint.add_theme_font_size_override("font_size", roundi(14 * density))
		hint.position = scroll.position + Vector2(0, scroll.size.y + 2 * density)
		hint.size = Vector2(scroll.size.x, 22 * density)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if page == "scenes":
			scroll.get_child(0).add_theme_constant_override("separation", roundi(gap))
		else:
			var copy: Label = scroll.get_node("Copy")
			copy.add_theme_font_size_override("font_size", roundi(20 * density))
		buttons.back.size = Vector2(minf(210 * density, (panel_rect.size.x - gap * 3) / 2), target)
		buttons.back.position = panel_rect.end - Vector2(gap + buttons.back.size.x, gap + target)
		if page == "reset":
			buttons.reset.size = Vector2((panel_rect.size.x - gap * 3) / 2, target)
			buttons.reset.position = Vector2(panel_rect.position.x + gap, buttons.back.position.y)
	attract.scale = size / Vector2(960, 540)
	if is_instance_valid(legal): legal.configure(game.ui_font, game.safe_padding)
	queue_redraw()

func _draw() -> void:
	if painting != null and not attracting:
		var amount := maxf(size.x / painting.get_width(), size.y / painting.get_height())
		var dimensions := painting.get_size() * amount
		var offset := Vector2((size.x - dimensions.x) / 2, (size.y - dimensions.y) * 0.08)
		draw_texture_rect(painting, Rect2(offset, dimensions), false)
	if page not in ["press", "menu"]:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.025, 0.08, 0.65))
		var rect := panel_rect
		var panel := StyleBoxFlat.new(); panel.bg_color = Color(0.078, 0.063, 0.165, 0.96); panel.set_corner_radius_all(16); panel.border_color = GOLD; panel.set_border_width_all(1); draw_style_box(panel, rect)
