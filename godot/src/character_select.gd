extends Control
## Original stage selector, now entered deliberately from the campaign map.
## Drafts are transactional: only confirmed emits a party for the host to save.
signal confirmed(party: Dictionary)
signal cancelled
const Painter = preload("res://src/character_select_painter.gd")
const CAST := ["jp","maya","ama","leo","theo","mei"]
const MODES := ["cpu","p2","solo"]
const MODE_LABELS := {"cpu":"Mate: computer","p2":"Mate: player 2 (keys)","solo":"No mate, solo"}
var game
var info: Dictionary = {}
var pictures: Dictionary = {}
var background: Texture2D
var font: Font
var draft := {"mode":"cpu","p1":"jp","p2":"maya"}
var step := 0
var cursor := 0
var elapsed := 0.0
var suspended := false
var message := ""
var cards: Dictionary = {}
var choices: Dictionary = {}
var mode_button: Button
var start_button: Button
var back_button: Button
var cancel_button: Button
var layout_size := Vector2.ZERO
var layout_screen_scale := Vector2.ONE
var layout_screen_transform := Transform2D.IDENTITY
var ui_scale := 1.0
var _touch_buttons: Dictionary = {}
var _touch_origins: Dictionary = {}
var _touch_dragged: Dictionary = {}
var heading_center := Vector2(480,52)
var heading_size := 26
var hint_center := Vector2(480,86)
var hint_size := 13
var hint_lines: Array[String] = []
var header_text_width := 700.0
var footer_size := 11
var painter = Painter.new()

func configure(host, source_info: Dictionary, source_pictures: Dictionary) -> void:
	game = host; info = source_info; pictures = source_pictures; font = host.font
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/1-1.json"))
	var path: String = source.get("imgs",{}).get("st0","")
	if not path.is_empty() and ResourceLoader.exists(path): background = load(path)

func _ready() -> void:
	name = "OfficialCharacterSelect"; mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; z_index = 10
	for index in CAST.size():
		var slot: int = index
		var control := _button(str(info.cast[CAST[index]]),func(): pick(slot))
		control.mouse_entered.connect(func(): cursor = slot; queue_redraw())
		control.focus_entered.connect(func(): cursor = slot; queue_redraw())
		choices[CAST[index]] = control
	mode_button = _button("Mate: computer",cycle_mode)
	start_button = _button("Start",confirm_selection)
	back_button = _button("Back",go_back)
	cancel_button = _button("Cancel",cancel)
	get_viewport().size_changed.connect(_layout)
	_layout(); hide()

func _button(text: String, callback: Callable) -> Button:
	var control := Button.new(); control.text = text; control.tooltip_text = text
	# The painter owns the exact source canvas presentation. Native transparent
	# buttons provide real GUI focus, touch hit testing and accessible labels.
	control.add_theme_font_override("font",font)
	control.add_theme_font_size_override("font_size",11)
	for variant in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(variant,StyleBoxEmpty.new())
		control.add_theme_color_override("font_color" if variant == "normal" else "font_%s_color" % variant,Color.TRANSPARENT)
	control.pressed.connect(callback,CONNECT_DEFERRED)
	add_child(control); return control

func open(party: Dictionary) -> void:
	release_contacts()
	draft = party.duplicate(true)
	if draft.get("mode") not in MODES: draft.mode = "cpu"
	if draft.get("p1") not in CAST: draft.p1 = "jp"
	if draft.get("p2") not in CAST or draft.p2 == draft.p1: draft.p2 = "maya" if draft.p1 != "maya" else "jp"
	step = 0; cursor = CAST.find(draft.p1); elapsed = 0; message = ""; suspended = false
	_layout(); show(); choices[CAST[cursor]].grab_focus(); _refresh()

func can_start() -> bool:
	return draft.p1 in CAST and (draft.mode == "solo" or (draft.p2 in CAST and draft.p2 != draft.p1))

func pick(index: int) -> void:
	if not is_visible_in_tree() or game.mode != "menu" or suspended or index < 0 or index >= CAST.size(): return
	var key: String = CAST[index]
	cursor = index; message = ""
	if step == 0:
		var previous: String = draft.p1
		if draft.mode != "solo" and key == draft.p2: draft.p2 = previous
		draft.p1 = key
		step = 2 if draft.mode == "solo" else 1
		if step == 1: cursor = (index + 1) % CAST.size()
	elif step == 1:
		if key == draft.p1:
			if draft.p2 in CAST and draft.p2 != draft.p1:
				draft.p1 = draft.p2; draft.p2 = key; step = 2
			else: step = 0
		else: draft.p2 = key; step = 2
	elif draft.mode == "solo": draft.p1 = key
	elif key == draft.p1: step = 1; cursor = (index + 1) % CAST.size()
	else: draft.p2 = key
	game.sfx("select"); _refresh()

func cycle_mode() -> void:
	if not is_visible_in_tree() or game.mode != "menu" or suspended: return
	draft.mode = MODES[(MODES.find(draft.mode) + 1) % MODES.size()]
	if draft.mode == "solo" and draft.p1 in CAST: step = 2
	elif draft.p1 in CAST and draft.p2 not in CAST: step = 1
	message = ""; game.sfx("select"); _refresh()

func go_back() -> void:
	if not is_visible_in_tree() or suspended: return
	if step > 0:
		step -= 1
		if step == 0: draft.p2 = ""
		message = ""; _refresh()
	else: cancel()

func cancel() -> void:
	if not is_visible_in_tree(): return
	release_contacts()
	hide(); cancelled.emit()

func confirm_selection() -> void:
	if not is_visible_in_tree() or game.mode != "menu" or suspended or not can_start(): return
	game.sfx("power"); confirmed.emit(draft.duplicate(true))

func show_error(text: String) -> void:
	message = text; queue_redraw()

func _refresh() -> void:
	mode_button.text = MODE_LABELS[draft.mode]
	mode_button.tooltip_text = mode_button.text + ". Change mate mode."
	start_button.disabled = not can_start()
	start_button.text = "Start" if can_start() else ("Pick player 1" if step == 0 else "Pick your mate")
	for key in choices:
		var role := "Player 1" if key == draft.p1 else (("CPU partner" if draft.mode == "cpu" else "Player 2") if key == draft.p2 and draft.mode != "solo" else "Choose")
		choices[key].tooltip_text = "%s: %s" % [role,info.cast[key]]
	_layout(); queue_redraw()

func hint_text() -> String:
	if step == 0: return "Tap a door to pick a friend"
	if draft.mode == "cpu": return "The computer will play them"
	if draft.mode == "solo": return "One housemate. Your progress is kept."
	return "Player 2: A D move, W aims, G jumps, F shoots, R power"

func _layout() -> void:
	if not is_instance_valid(mode_button): return
	release_contacts()
	layout_size = get_viewport_rect().size; size = layout_size
	layout_screen_transform = get_viewport().get_screen_transform()
	layout_screen_scale = layout_screen_transform.get_scale().abs()
	ui_scale = maxf(1.0,1.0 / maxf(0.01,minf(layout_screen_scale.x,layout_screen_scale.y)))
	var pad: Vector2 = game.safe_padding
	# Preserve the authored six-door row. Only navigation/action density adapts
	# when the same 960x540 canvas is rendered into a smaller desktop fixture.
	var target := 44.0 * ui_scale
	var nav_font := roundi(13 * ui_scale)
	var back_width := maxf(96,font.get_string_size("Back",HORIZONTAL_ALIGNMENT_LEFT,-1,nav_font).x + 20 * ui_scale)
	var cancel_width := maxf(96,font.get_string_size("Cancel",HORIZONTAL_ALIGNMENT_LEFT,-1,nav_font).x + 20 * ui_scale)
	back_button.position = pad; back_button.size = Vector2(back_width,target)
	cancel_button.position = Vector2(size.x - pad.x - cancel_width,pad.y); cancel_button.size = Vector2(cancel_width,target)
	var action_width := minf(300 * ui_scale,(size.x - pad.x * 2 - 60) / 2)
	var action_y := size.y - pad.y - maxf(78,target + 30)
	mode_button.position = Vector2(size.x / 2 - action_width - 30,action_y); mode_button.size = Vector2(action_width,target)
	start_button.position = Vector2(size.x / 2 + 30,action_y); start_button.size = Vector2(action_width,target)
	header_text_width = maxf(80,size.x - 2 * (pad.x + maxf(back_width,cancel_width) + 12))
	hint_lines.clear()
	var line := ""
	for word in hint_text().split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if ui_scale > 1.05 and not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x > header_text_width:
			hint_lines.append(line); line = word
		else: line = candidate
	hint_lines.append(line)
	var width := minf(138,(size.x - pad.x * 2 - 70) / 6)
	var first := (size.x - width * 6 - 70) / 2
	var bottom := minf(size.y - pad.y - 118,action_y - 20)
	var top := maxf(pad.y + 88,minf(118,bottom - 200)) + maxf(0,hint_lines.size() - 1) * 18
	for index in CAST.size():
		var rect := Rect2(first + index * (width + 14),top,width,bottom - top)
		cards[CAST[index]] = rect
		choices[CAST[index]].position = rect.position; choices[CAST[index]].size = rect.size
	heading_size = 26
	while heading_size > 12 and font.get_string_size("Player 1: pick your friend",HORIZONTAL_ALIGNMENT_LEFT,-1,heading_size).x > header_text_width: heading_size -= 1
	heading_center = Vector2(size.x / 2,52)
	hint_center = Vector2(size.x / 2,86)
	hint_size = 13
	footer_size = 11
	queue_redraw()

func release_contacts() -> void:
	for button in _touch_buttons.values():
		if is_instance_valid(button): button.set_pressed_no_signal(false)
	_touch_buttons.clear(); _touch_origins.clear(); _touch_dragged.clear()

func _touch_input(event: InputEvent) -> bool:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.canceled:
			for button in [mode_button,start_button,back_button,cancel_button] + choices.values():
				if button.disabled or not button.is_visible_in_tree() or not button.get_global_rect().has_point(event.position): continue
				if not _touch_buttons.values().has(button):
					_touch_buttons[event.index] = button
					_touch_origins[event.index] = event.position
					button.grab_focus(); button.set_pressed_no_signal(true)
				return true
		elif _touch_buttons.has(event.index):
			var button: Button = _touch_buttons[event.index]
			var dragged: bool = _touch_dragged.get(event.index,false)
			_touch_buttons.erase(event.index); _touch_origins.erase(event.index); _touch_dragged.erase(event.index); button.set_pressed_no_signal(false)
			if not dragged and not event.canceled and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position): button.pressed.emit()
		return true
	if event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if _touch_buttons.has(event.index):
			var button: Button = _touch_buttons[event.index]
			if event.position.distance_to(_touch_origins[event.index]) >= 10 * ui_scale: _touch_dragged[event.index] = true
			button.set_pressed_no_signal(not _touch_dragged.get(event.index,false) and button.get_global_rect().has_point(event.position))
		return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or game.mode != "menu" or suspended: return
	if _touch_input(event): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_RIGHT,KEY_D: cursor = (cursor + 1) % CAST.size(); choices[CAST[cursor]].grab_focus(); game.sfx("select")
		KEY_LEFT,KEY_A: cursor = (cursor + CAST.size() - 1) % CAST.size(); choices[CAST[cursor]].grab_focus(); game.sfx("select")
		KEY_F: cycle_mode()
		KEY_BACKSPACE,KEY_ESCAPE: go_back()
		KEY_ENTER,KEY_SPACE:
			if mode_button.has_focus(): cycle_mode()
			elif cancel_button.has_focus(): cancel()
			elif back_button.has_focus(): go_back()
			elif start_button.has_focus() or step == 2: confirm_selection()
			else: pick(cursor)
		_: return
	get_viewport().set_input_as_handled(); queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: suspended = true; release_contacts()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: suspended = false
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and is_visible_in_tree(): go_back()

func _process(delta: float) -> void:
	if not visible or suspended: return
	if layout_size != get_viewport_rect().size or layout_screen_transform != get_viewport().get_screen_transform(): _layout()
	elapsed += minf(delta,0.05); queue_redraw()

func _draw() -> void:
	if not cards.is_empty(): painter.draw(self)
