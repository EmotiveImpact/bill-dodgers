extends Control
## Source MAP4 overworld, rendered natively. Campaign decisions remain in Campaign.
## This is presentation only: map navigation never writes a clear, skill or reward.
const Campaign = preload("res://src/campaign_progression.gd")
const NativeLevels = preload("res://src/native_levels.gd")
const Painter = preload("res://src/campaign_map_painter.gd")
const CharacterSelect = preload("res://src/character_select.gd")
const SaveStore = preload("res://src/save_store.gd")
const GOLD := Color("f4c542")
const INK := Color("14102a")
const COLORS := [Color("e84a5f"), Color("3f7fe0"), Color("ff9f1c"), Color("19c3b4"), Color("b05fd6"), GOLD]
var game
var data: Dictionary = {}
var map: Dictionary = {}
var info: Dictionary = {}
var pictures: Dictionary = {}
var state: Dictionary = {}
var edges: Array = []
var nodes: Dictionary = {}
var shown: Dictionary = {}
var stored_shown: Dictionary = {}
var reveal_queue: Array = []
var island_reveal: Dictionary = {}
var painter = Painter.new()
var at := "HOME"
var selected := ""
var walker := Vector2.ZERO
var route: Array = []
var face := 1
var boat := false
var time := 0.0
var camera := Vector2.ZERO
var look := Vector2.ZERO
var zoom := 0.65
var zoom_target := 0.65
var near_zoom := 0.65
var fit_zoom := 0.1
var wide := false
var auto_target := ""
var auto_delay := 0.0
var contacts: Dictionary = {}
var drag_start := Vector2.ZERO
var drag_look := Vector2.ZERO
var drag_moved := false
var pinch_distance := 0.0
var pinch_zoom := 0.0
var suspended := false
var header: Control
var header_world: Label
var header_level: Label
var card: Panel
var play_button: Button
var card_title: Label
var card_copy: Label
var card_kind: Label
var friend_panel: Control
var pending_party_level := ""
var selection_return_stage := ""
var default_party_mode := "cpu"
var world_panel: Panel
var stage_panel: Panel
var world_buttons: Dictionary = {}
var stage_buttons: Dictionary = {}
var zoom_button: Button
var friend_button: Button
var title_button: Button
var next_button: Button
var font: Font
var ui_font: Font
var banner_text := ""
var banner_time := 0.0
var banner_world := 1
var layout_size := Vector2.ZERO
var layout_transform := Transform2D.IDENTITY
var layout_padding := Vector2.ZERO
var ui_contacts: Dictionary = {}
var ui_scale := 1.0
var ui_buttons: Array[Button] = []
var world_scroll: ScrollContainer
var world_list: VBoxContainer
var stage_scroll: ScrollContainer
var stage_list: VBoxContainer
var card_scroll: ScrollContainer

func configure(host, target: String = "") -> bool:
	game = host
	default_party_mode = str(game.save.get("party_mode", "cpu"))
	font = host.font
	ui_font = host.ui_font
	if not FileAccess.file_exists("res://content/map.json"): return false
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content/map.json"))
	map = data.map
	info = data.game
	for key in data.pictures:
		if ResourceLoader.exists(data.pictures[key]): pictures[key] = load(data.pictures[key])
	state = Campaign.snapshot(game.save, game.catalog, NativeLevels.SUPPORTED)
	for id in map.stops:
		nodes[id] = map.stops[id].duplicate(true)
		nodes[id].id = id
		nodes[id].neighbors = []
	for original in map.edges:
		var edge: Dictionary = original.duplicate(true)
		edge.index = edges.size()
		edge.points = PackedVector2Array()
		edge.length = 0.0
		for p in edge.pts:
			var point := Vector2(p[0], p[1])
			if not edge.points.is_empty(): edge.length += edge.points[-1].distance_to(point)
			edge.points.append(point)
		edge.kind = edge.get("kind", "path")
		edges.append(edge)
		nodes[edge.a].neighbors.append(edge.index)
		nodes[edge.b].neighbors.append(edge.index)
	# Use actual campaign context, not arbitrary local preview clears.
	var saved_at: String = str(game.save.get("map_at", "HOME"))
	var origin: String = saved_at if saved_at in nodes and is_open(saved_at) and nodes[saved_at].kind != "gate" else "HOME"
	if not target.is_empty() and game.level_id in nodes and is_open(game.level_id): origin = game.level_id
	if target.is_empty() and origin == "HOME" and not game.save.has("map_at") and not state.verified_cleared.is_empty():
		origin = state.next_route.get("level_id", "HOME")
		if origin.is_empty(): origin = "6-6"
	at = origin
	walker = point(at)
	camera = walker
	for island in map.islands: island_reveal[int(island.n)] = 1.0 if world_open(int(island.n)) else 0.0
	# Presentation saves never authorize an edge: intersect with the real graph
	# and the independently verified campaign chain before restoring anything.
	for value in game.save.get("map_shown", []):
		if (value is int or value is float) and is_finite(float(value)) and float(int(value)) == float(value) and value >= 0 and value < edges.size() and edge_open(edges[int(value)]): stored_shown[int(value)] = true
	for edge in edges:
		if edge_open(edge):
			var newly_opened: bool = not stored_shown.has(edge.index) and not target.is_empty() and edge.get("need") == game.level_id and state.verified_cleared.has(game.level_id)
			shown[edge.index] = 0.0 if newly_opened else edge.length
			if newly_opened: reveal_queue.append(edge.index)
	if not target.is_empty() and is_open(target):
		auto_target = target
		auto_delay = 0.9
		if origin.ends_with("-6") and origin != target:
			banner_text = "World %s complete\nNext island open!" % origin[0]
			banner_world = int(origin[0]); banner_time = 3.4; auto_delay = 3.4
			var new_world := int(target[0])
			if new_world != int(origin[0]) and not reveal_queue.is_empty(): island_reveal[new_world] = 0.0
	return true

func _ready() -> void:
	name = "CampaignMap"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_map_input)
	get_viewport().size_changed.connect(func(): release_contacts(); _layout())
	_build_ui()
	_layout()
	_update_header(at)
	if auto_target.is_empty() and at != "HOME": show_card(at)
	queue_redraw()

func point(id: String) -> Vector2:
	var node: Dictionary = nodes.get(id, {})
	return Vector2(float(node.get("x", 0)), float(node.get("y", 0)))

func edge_open(edge: Dictionary) -> bool:
	return edge.get("need") == null or str(edge.get("need", "")).is_empty() or state.verified_cleared.has(edge.need)

func is_open(id: String) -> bool:
	if id == "HOME": return true
	if not nodes.has(id): return false
	if nodes[id].kind != "gate": return state.levels.get(id, {}).get("unlocked", false)
	for i in nodes[id].neighbors:
		if edge_open(edges[i]): return true
	return false

func world_open(world: int) -> bool:
	return state.worlds[world - 1].unlocked

func route_to(target: String) -> Array:
	if not is_open(target): return []
	var previous := {at: {}}
	var pending := [at]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if current == target: break
		for i in nodes[current].neighbors:
			var edge: Dictionary = edges[i]
			if not edge_open(edge): continue
			var other: String = edge.b if edge.a == current else edge.a
			if not previous.has(other):
				previous[other] = {"from": current, "edge": i}
				pending.append(other)
	if not previous.has(target): return []
	var result: Array = []
	var cursor := target
	while cursor != at:
		var step: Dictionary = previous[cursor]
		var edge: Dictionary = edges[step.edge]
		var points: PackedVector2Array = edge.points.duplicate()
		if edge.a == cursor: points.reverse()
		points.remove_at(0)
		result.push_front({"to": cursor, "kind": edge.kind, "points": points, "length": edge.length})
		cursor = step.from
	return result

func go_to(id: String, allow_hop: bool = false) -> void:
	if not nodes.has(id) or nodes[id].kind == "gate": return
	# A second click replaces, rather than appends to, a walk. Anchor at last stop.
	if not route.is_empty(): walker = point(at); route.clear()
	close_card()
	if id == at or not is_open(id): show_card(id); return
	var path := route_to(id)
	if path.is_empty(): show_card(id); return
	var length := 0.0
	for leg in path: length += leg.length
	if allow_hop and length > 2400:
		at = id; walker = point(id); show_card(id); _persist(); return
	route = path
	set_wide(false)

func nudge(direction: Vector2) -> void:
	if not route.is_empty(): return
	var best := ""
	var score := 0.35
	for index in nodes[at].neighbors:
		var edge: Dictionary = edges[index]
		if not edge_open(edge): continue
		var points: PackedVector2Array = edge.points.duplicate()
		if edge.b == at: points.reverse()
		var dot: float = (points[mini(points.size() - 1, 3)] - points[0]).normalized().dot(direction)
		if dot <= score: continue
		var other: String = edge.b if edge.a == at else edge.a
		var previous: int = index
		for guard in 6:
			if nodes[other].kind != "gate": break
			for next_index in nodes[other].neighbors:
				if next_index == previous or not edge_open(edges[next_index]): continue
				var next: Dictionary = edges[next_index]
				other = next.b if next.a == other else next.a
				previous = next_index; break
		if nodes[other].kind != "gate": best = other; score = dot
	if not best.is_empty(): go_to(best)

func tick(delta: float) -> void:
	if suspended or (is_instance_valid(friend_panel) and friend_panel.visible): return
	time += delta
	banner_time = maxf(0, banner_time - delta)
	if not reveal_queue.is_empty():
		var index: int = reveal_queue[0]
		shown[index] = minf(edges[index].length, shown[index] + delta * 350)
		if shown[index] >= edges[index].length: reveal_queue.pop_front(); _persist()
	for island in map.islands:
		var world := int(island.n)
		if world_open(world): island_reveal[world] = minf(1, island_reveal[world] + delta / 1.8)
	if not route.is_empty():
		var remaining := delta
		# Consume the frame across vertices, so winding paths retain source speed.
		while remaining > 0 and not route.is_empty():
			var leg: Dictionary = route[0]
			boat = leg.kind == "boat"
			var speed := 300.0 if boat else 260.0
			var destination: Vector2 = leg.points[0]
			var distance := walker.distance_to(destination)
			if absf(destination.x - walker.x) > 0.5: face = 1 if destination.x > walker.x else -1
			if distance <= remaining * speed:
				walker = destination; remaining -= distance / speed; leg.points.remove_at(0)
				if leg.points.is_empty():
					at = leg.to; route.pop_front()
					if route.is_empty(): boat = false; show_card(at); _persist()
			else: walker = walker.move_toward(destination, remaining * speed); remaining = 0
		look *= pow(0.99, delta * 1000)
	if not auto_target.is_empty():
		auto_delay -= delta
		if auto_delay <= 0 and reveal_queue.is_empty() and route.is_empty():
			var target := auto_target; auto_target = ""; go_to(target, true)
	zoom = lerpf(zoom, zoom_target, minf(1, delta * 6))
	var focus := Vector2(float(map.W) / 2, float(map.H) / 2) if wide else walker
	if not reveal_queue.is_empty(): focus = path_point(edges[reveal_queue[0]], shown[reveal_queue[0]])
	elif not wide:
		var nearest := 900.0
		for island in map.islands:
			var texture: Texture2D = pictures.get("island-%d" % int(island.n))
			if texture == null: continue
			var center := Vector2(island.x, island.y) + texture.get_size() / 2
			var distance := walker.distance_to(center)
			if distance < nearest: nearest = distance; focus = walker + (center - walker) * Vector2(0.28, 0.18)
	camera = camera.lerp(focus, minf(1, delta * 4))
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or game.mode != "menu" or not is_visible_in_tree(): return
	if layout_size != get_viewport_rect().size or layout_transform != get_viewport().get_screen_transform() or layout_padding != game.safe_padding: release_contacts(); _layout()
	tick(minf(delta, 0.05))


func _persist() -> void:
	game.save.friend = game.character
	game.save.party_mode = game.party_session.runtime.mode
	game.save.party_mate = game.party_session.runtime.p2
	game.save.map_at = at
	var complete: Array = []
	for edge in edges:
		if edge_open(edge) and shown.get(edge.index, 0.0) >= edge.length: complete.append(edge.index)
	game.save.map_shown = complete
	game._save_progress()
	if game.status == "Progress could not be saved on this device." and has_node("MapHint"):
		get_node("MapHint").text = game.status

func path_point(edge: Dictionary, distance: float) -> Vector2:
	var points: PackedVector2Array = edge.points
	for i in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if distance <= length: return points[i - 1].lerp(points[i], distance / maxf(length, 0.001))
		distance -= length
	return points[-1]

func view_rect() -> Rect2:
	var visible := get_viewport_rect().size / maxf(zoom, 0.001)
	var origin := camera + look - visible * Vector2(0.5, 0.52)
	var bounds := Vector2(map.W, map.H)
	for axis in 2:
		origin[axis] = (bounds[axis] - visible[axis]) / 2 if visible[axis] >= bounds[axis] else clampf(origin[axis], 0, bounds[axis] - visible[axis])
	return Rect2(origin, visible)

func world_to_screen(position: Vector2) -> Vector2:
	return (position - view_rect().position) * zoom

func screen_to_world(position: Vector2) -> Vector2:
	return position / zoom + view_rect().position

func set_wide(value: bool) -> void:
	wide = value; look = Vector2.ZERO
	zoom_target = fit_zoom if wide else near_zoom
	if is_instance_valid(zoom_button): zoom_button.text = "Close up" if wide else "Whole map"

func release_contacts() -> void:
	contacts.clear(); ui_contacts.clear(); pinch_distance = 0; drag_moved = false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: suspended = true; release_contacts()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false; release_contacts()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if not is_instance_valid(friend_panel) or not friend_panel.visible: close_overlays()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or game == null or game.mode != "menu" or suspended: return
	if is_instance_valid(friend_panel) and friend_panel.visible: return
	# Native touch owns UI activation. Engine mouse emulation must never replay a
	# canceled release, or a release after a page/overlay/geometry change.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			var target := _touch_button(event.position)
			var scroll := _touch_scroll(event.position)
			if target != null or scroll != null:
				ui_contacts[event.index] = {"button": target, "scroll": scroll, "start": event.position, "last": event.position, "moved": false}
				get_viewport().set_input_as_handled()
				return
		elif ui_contacts.has(event.index):
			var contact: Dictionary = ui_contacts[event.index]
			ui_contacts.erase(event.index)
			var target = contact.button
			# Menu/Play may synchronously remove this map from the tree. Consume
			# the release before activation, with no viewport access afterward.
			get_viewport().set_input_as_handled()
			if not event.canceled and not contact.moved and is_instance_valid(target) and target == _touch_button(event.position):
				target.pressed.emit()
			return
	elif event is InputEventScreenDrag and ui_contacts.has(event.index):
		var contact: Dictionary = ui_contacts[event.index]
		if event.position.distance_to(contact.start) > 8 * ui_scale: contact.moved = true
		if contact.moved and is_instance_valid(contact.scroll):
			contact.scroll.scroll_vertical -= int(event.position.y - contact.last.y)
		contact.last = event.position
		get_viewport().set_input_as_handled()
		return
	# Release a drag even when the finger ends over a stage card or top-bar button.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and contacts.has(event.index):
		_pointer_up(event.index, event.position, event.canceled)
	elif event is InputEventScreenDrag and contacts.has(event.index): _pointer_move(event.index, event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and contacts.has(-1): _pointer_up(-1, event.position)
	elif event is InputEventMouseMotion and contacts.has(-1): _pointer_move(-1, event.position)

func _touch_scroll(position: Vector2) -> ScrollContainer:
	for scroll in [stage_scroll, world_scroll, card_scroll]:
		if is_instance_valid(scroll) and scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(position): return scroll
	return null

func _touch_button(position: Vector2) -> Button:
	var overlay: Control = stage_panel if stage_panel.visible else (world_panel if world_panel.visible else (card if card.visible else null))
	for button in ui_buttons:
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled: continue
		if overlay != null and not overlay.is_ancestor_of(button):
			if overlay != card or not header.is_ancestor_of(button): continue
		if not button.get_global_rect().has_point(position): continue
		var scroll := _touch_scroll(position)
		if (world_list.is_ancestor_of(button) or (is_instance_valid(stage_list) and stage_list.is_ancestor_of(button))) and scroll == null: continue
		return button
	return null

func _map_input(event: InputEvent) -> void:
	if suspended: return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _pointer_down(event.index, event.position)
		else: _pointer_up(event.index, event.position, event.canceled)
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target * (1.14 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.14), fit_zoom, 2.2); wide = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _pointer_down(-1, event.position)
			else: _pointer_up(-1, event.position)
		accept_event()

func _pointer_down(id: int, position: Vector2) -> void:
	contacts[id] = position
	if contacts.size() == 1: drag_start = position; drag_look = look; drag_moved = false
	elif contacts.size() == 2:
		var points: Array = contacts.values(); pinch_distance = points[0].distance_to(points[1]); pinch_zoom = zoom; drag_moved = true

func _pointer_move(id: int, position: Vector2) -> void:
	if not contacts.has(id): return
	contacts[id] = position
	if pinch_distance > 0 and contacts.size() == 2:
		var points: Array = contacts.values()
		zoom_target = clampf(pinch_zoom * points[0].distance_to(points[1]) / pinch_distance, fit_zoom, 2.2)
		zoom = zoom_target; wide = false; return
	if pinch_distance > 0: return # Do not turn the remaining pinch finger into a tap.
	var displacement := position - drag_start
	if displacement.length() > 10: drag_moved = true
	if drag_moved: look = (drag_look - displacement / zoom).clamp(Vector2(-2600, -2600), Vector2(2600, 2600))

func _pointer_up(id: int, position: Vector2, canceled: bool = false) -> void:
	if not contacts.has(id): return
	var click := contacts.size() == 1 and not drag_moved and pinch_distance <= 0 and not canceled
	contacts.erase(id)
	if contacts.is_empty(): release_contacts()
	if not click: return
	var position_world := screen_to_world(position)
	var best := ""
	var distance := 34.0 / minf(1, zoom)
	for key in nodes:
		if nodes[key].kind == "gate" or not is_open(key): continue
		var candidate := position_world.distance_to(point(key))
		if candidate < distance: distance = candidate; best = key
	if best.is_empty(): close_card()
	else: go_to(best)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or game.mode != "menu" or suspended or friend_panel.visible or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_ESCAPE: close_overlays()
		KEY_M: set_wide(not wide)
		KEY_LEFT: nudge(Vector2.LEFT)
		KEY_RIGHT: nudge(Vector2.RIGHT)
		KEY_UP: nudge(Vector2.UP)
		KEY_DOWN: nudge(Vector2.DOWN)
		KEY_ENTER, KEY_SPACE:
			if card.visible and is_instance_valid(play_button) and not play_button.disabled: _play_selected()
			elif route.is_empty(): show_card(at)
		_: return
	get_viewport().set_input_as_handled()

func close_overlays() -> void:
	if friend_panel.visible: _cancel_party()
	world_panel.hide(); stage_panel.hide(); close_card(); release_contacts()

func show_card(id: String) -> void:
	if not nodes.has(id) or nodes[id].kind == "gate": return
	release_contacts()
	selected = id
	card.show()
	next_button.hide()
	get_node("MapHint").hide()
	_update_header(id)
	if id == "HOME":
		card_title.text = "Home"
		card_kind.text = "Your house"
		card_copy.text = "The robots took the house kitty from right here. Follow the paths across the islands to get it back. Clearing a level opens the next path. Each boss opens the bridge to the next island."
		play_button.hide()
	else:
		var descriptor: Dictionary = info.levels.get(id, {})
		var entry: Dictionary = state.levels[id]
		card_title.text = ("Bonus: " if entry.bonus else id + "  ") + str(descriptor.get("name", entry.title))
		card_kind.text = ("Cleared · " if entry.cleared else "") + str(descriptor.get("kindName", "")) + (" · %d/3 receipts" % entry.receipts.size())
		card_copy.text = str(descriptor.get("text", "")) if entry.playable else entry.reason
		play_button.text = entry.play_label if entry.playable else "Locked"
		play_button.disabled = not entry.playable
		play_button.show()
	_layout_card()

func close_card() -> void:
	release_contacts()
	selected = ""
	if is_instance_valid(card): card.hide()
	if is_instance_valid(next_button): next_button.show()
	if has_node("MapHint"): get_node("MapHint").show()

func _play_selected() -> void:
	if selected.is_empty() or selected == "HOME" or not state.levels[selected].playable: return
	if not game.save.get("party_confirmed", false):
		_show_friends(selected)
		return
	game.start_campaign_level(selected)

func _update_header(id: String) -> void:
	var world: int = nodes[id].world
	game.world_selected = world
	header_world.text = "World %d: %s" % [world, Campaign.WORLD_NAMES[world - 1]]
	header_world.modulate = COLORS[world - 1]
	header_level.text = "Home" if id == "HOME" else (id + "  " + str(info.levels.get(id, {}).get("name", "")))

func _panel(parent: Node) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.078, 0.063, 0.165, 0.96)
	style.border_color = Color(0.96, 0.94, 0.92, 0.24)
	style.set_border_width_all(1); style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int) -> Label:
	var control := Label.new()
	control.text = text
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_override("font", ui_font)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", Color("f5f1ea"))
	parent.add_child(control)
	return control

func _button(parent: Node, text: String, callback: Callable, main: bool = false) -> Button:
	var control := Button.new()
	control.text = text
	control.add_theme_font_override("font", ui_font)
	control.add_theme_font_size_override("font_size", 17)
	for variant in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if main else Color("28223e")
		if variant == "hover": style.bg_color = style.bg_color.lightened(0.12)
		elif variant == "pressed": style.bg_color = style.bg_color.darkened(0.12)
		elif variant == "disabled": style.bg_color = Color("262537")
		style.border_color = GOLD if variant == "focus" else Color("6b627d")
		style.set_border_width_all(2 if variant == "focus" else 1); style.set_corner_radius_all(10)
		control.add_theme_stylebox_override(variant, style)
		control.add_theme_color_override("font_" + ("color" if variant == "normal" else variant + "_color"), INK if main else Color("f5f1ea"))
	control.pressed.connect(callback)
	ui_buttons.append(control)
	parent.add_child(control)
	return control

func _build_ui() -> void:
	header = _panel(self)
	header_world = _label(header, "", 16); header_world.position = Vector2(14, 8)
	header_level = _label(header, "", 18); header_level.position = Vector2(14, 29)
	title_button = _button(header, "Menu", func():
		if game.has_method("_show_title"): game._show_title(true)
		else: game._show_menu())
	zoom_button = _button(header, "Whole map", func(): set_wide(not wide))
	friend_button = _button(header, "Change character", _show_friends)
	friend_button.tooltip_text = "Current housemate: " + str(info.cast[game.character])
	var worlds := _button(header, "Worlds", func(): close_overlays(); world_panel.show())
	worlds.name = "Worlds"
	card = _panel(self); card.z_index = 2
	card_title = _label(card, "", 24); card_title.position = Vector2(18, 12)
	card_kind = _label(card, "", 15); card_kind.position = Vector2(18, 43); card_kind.modulate = GOLD
	card_scroll = ScrollContainer.new(); card_scroll.name = "DescriptionScroll"; card.add_child(card_scroll)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_copy = _label(card_scroll, "", 18); card_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button = _button(card, "Play", _play_selected, true)
	play_button.name = "PlayStage"
	var close := _button(card, "Close", close_card); close.name = "CloseCard"
	card.hide()
	world_panel = _panel(self); world_panel.z_index = 3; world_panel.hide()
	var world_title := _label(world_panel, "The six worlds", 26); world_title.name = "ListTitle"
	world_scroll = ScrollContainer.new(); world_scroll.name = "ListScroll"; world_panel.add_child(world_scroll)
	world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	world_list = VBoxContainer.new(); world_scroll.add_child(world_list); world_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for world in range(1, 7):
		var button := _button(world_list, "WORLD %d   %s" % [world, Campaign.WORLD_NAMES[world - 1]], func(): _show_stages(world))
		button.position = Vector2(18, 58 + (world - 1) * 46); button.size = Vector2(444, 44)
		button.disabled = not world_open(world); world_buttons[world] = button
	var world_close := _button(world_panel, "Close", func(): world_panel.hide()); world_close.name = "CloseList"
	stage_panel = _panel(self); stage_panel.z_index = 3; stage_panel.hide()
	friend_panel = CharacterSelect.new()
	friend_panel.configure(game, info, pictures)
	add_child(friend_panel)
	friend_panel.confirmed.connect(_confirm_party)
	friend_panel.cancelled.connect(_cancel_party)
	next_button = _button(self, state.menu_label, func():
		var target: String = state.next_route.get("level_id", "")
		if not target.is_empty(): go_to(target, true)
		elif state.credits_unlocked: game._show_credits(), true)
	var help := _label(self, "Kitty £%d  ·  Tap a stop · Drag / pinch to explore" % int(game.save.get("kitty", 0)), 16); help.name = "MapHint"
	help.add_theme_color_override("font_outline_color", INK); help.add_theme_constant_override("outline_size", 5)

func _show_friends(level_to_start: String = "") -> void:
	if game.mode != "menu": return
	var previous_stage := selected
	close_overlays()
	selection_return_stage = previous_stage
	pending_party_level = level_to_start
	var party = game.party_session.runtime
	friend_panel.open({"mode": party.mode if game.save.get("party_confirmed", false) else default_party_mode, "p1": game.character, "p2": party.p2})

func _cancel_party() -> void:
	friend_panel.hide()
	pending_party_level = ""
	var previous_stage := selection_return_stage
	selection_return_stage = ""
	if not previous_stage.is_empty(): show_card(previous_stage)
	friend_button.grab_focus()
	release_contacts()

func _confirm_party(choice: Dictionary) -> void:
	if game.mode != "menu" or not friend_panel.visible: return
	if choice.get("mode") not in CharacterSelect.MODES or choice.get("p1") not in CharacterSelect.CAST: return
	if choice.mode != "solo" and (choice.get("p2") not in CharacterSelect.CAST or choice.p2 == choice.p1): return
	var mate: String = choice.get("p2", "")
	if choice.mode == "solo" and mate not in CharacterSelect.CAST:
		mate = game.party_session.runtime.p2
	if mate not in CharacterSelect.CAST or mate == choice.p1: mate = "maya" if choice.p1 != "maya" else "jp"
	var candidate: Dictionary = game.save.duplicate(true)
	candidate.friend = choice.p1; candidate.party_mode = choice.mode; candidate.party_mate = mate; candidate.party_confirmed = true
	if SaveStore.write_save(candidate) != OK:
		friend_panel.show_error("Could not save. Your previous party is unchanged.")
		return
	game.save = candidate; game.character = choice.p1
	game.configure_party(choice.mode, mate)
	friend_button.tooltip_text = "Current housemate: " + str(info.cast[game.character])
	var target := pending_party_level
	_cancel_party()
	queue_redraw()
	if not target.is_empty(): game.start_campaign_level(target)

func _show_stages(world: int) -> void:
	release_contacts()
	world_panel.hide()
	for child in stage_panel.get_children(): stage_panel.remove_child(child); child.queue_free()
	stage_buttons.clear()
	var stage_title := _label(stage_panel, "World %d: %s" % [world, Campaign.WORLD_NAMES[world - 1]], 23); stage_title.name = "ListTitle"
	stage_scroll = ScrollContainer.new(); stage_scroll.name = "ListScroll"; stage_panel.add_child(stage_scroll)
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_list = VBoxContainer.new(); stage_scroll.add_child(stage_list); stage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in 7:
		var id := "%d-%s" % [world, str(index + 1) if index < 6 else "S"]
		var entry: Dictionary = state.levels[id]
		var button := _button(stage_list, ("✓ " if entry.cleared else "") + entry.label, func(): stage_panel.hide(); go_to(id, true))
		button.position = Vector2(18, 50 + index * 46); button.size = Vector2(444, 44); button.disabled = not entry.playable; stage_buttons[id] = button
	var close := _button(stage_panel, "Close", func(): stage_panel.hide()); close.name = "CloseList"
	stage_panel.show()
	_layout_list(stage_panel, stage_list)

func _layout() -> void:
	if not is_instance_valid(header): return
	layout_size = get_viewport_rect().size
	layout_transform = get_viewport().get_screen_transform()
	layout_padding = game.safe_padding
	ui_scale = maxf(1.0, 1.0 / maxf(0.1, minf(layout_transform.x.length(), layout_transform.y.length())))
	size = layout_size
	near_zoom = maxf(0.55, minf(1.4, minf(size.x / 1250, size.y / 860)))
	fit_zoom = minf(size.x / float(map.W), size.y / float(map.H)) * 0.98
	zoom_target = fit_zoom if wide else near_zoom
	if time == 0: zoom = zoom_target
	var pad: Vector2 = game.safe_padding
	var width := size.x - pad.x * 2
	var unit := ui_scale
	header.position = pad; header.size = Vector2(width, 88 * unit)
	header_world.position = Vector2(10, 3) * unit
	header_level.position = Vector2(10, 22) * unit
	for label in [header_world, header_level]:
		label.add_theme_font_size_override("font_size", roundi(16 * unit))
		label.size = Vector2(width - 20 * unit, 20 * unit); label.clip_text = true
	friend_button.text = "Change character" if width / unit > 600 else "Character"
	var controls: Array = [friend_button, zoom_button, header.get_node("Worlds"), title_button]
	var available := width - 20 * unit
	var ratios := [0.29, 0.29, 0.23, 0.19]
	var x := 7 * unit
	for index in 4:
		var button: Button = controls[index]
		button.position = Vector2(x, 42 * unit)
		button.size = Vector2((available - 12 * unit) * ratios[index], 44 * unit)
		x += button.size.x + 4 * unit
	for button in ui_buttons:
		if is_instance_valid(button): button.add_theme_font_size_override("font_size", roundi(16 * unit))
	_layout_list(world_panel, world_list)
	if is_instance_valid(stage_list): _layout_list(stage_panel, stage_list)
	next_button.size = Vector2(minf(width * 0.5, 240 * unit), 44 * unit)
	next_button.position = Vector2(size.x - pad.x - next_button.size.x, size.y - pad.y - next_button.size.y)
	var hint: Label = get_node("MapHint")
	hint.text = "Kitty £%d\nTap a stop · Drag / pinch" % int(game.save.get("kitty", 0))
	hint.add_theme_font_size_override("font_size", roundi(14 * unit))
	hint.position = Vector2(pad.x, size.y - pad.y - 42 * unit)
	hint.size = Vector2(width - next_button.size.x - 8 * unit, 42 * unit)
	hint.clip_text = true
	_layout_card()

func _layout_list(panel: Panel, list: VBoxContainer) -> void:
	var unit := ui_scale
	var pad: Vector2 = game.safe_padding
	panel.size = Vector2(minf(480 * unit, size.x - pad.x * 2), size.y - pad.y * 2) - Vector2(0.02, 0.02)
	panel.position = Vector2((size.x - panel.size.x) / 2, pad.y + 0.01)
	var title: Label = panel.get_node("ListTitle")
	title.position = Vector2(12, 6) * unit; title.size = Vector2(panel.size.x - 24 * unit, 32 * unit)
	title.add_theme_font_size_override("font_size", roundi(20 * unit)); title.clip_text = true
	var scroll: ScrollContainer = panel.get_node("ListScroll")
	scroll.position = Vector2(12, 42) * unit
	scroll.size = Vector2(panel.size.x - 24 * unit, panel.size.y - 98 * unit)
	list.add_theme_constant_override("separation", roundi(4 * unit))
	for button in list.get_children():
		button.custom_minimum_size = Vector2(0, 44 * unit)
		button.add_theme_font_size_override("font_size", roundi(16 * unit))
	var close: Button = panel.get_node("CloseList")
	close.size = Vector2(120, 44) * unit
	close.position = Vector2(panel.size.x - close.size.x - 12 * unit, panel.size.y - 50 * unit)

func _layout_card() -> void:
	if not is_instance_valid(card): return
	var pad: Vector2 = game.safe_padding
	var unit := ui_scale
	card.size = Vector2(minf(680 * unit, size.x - pad.x * 2), minf(208 * unit, size.y - pad.y * 2 - header.size.y - 6 * unit))
	card.position = Vector2((size.x - card.size.x) / 2, size.y - pad.y - card.size.y)
	card_title.position = Vector2(12, 5) * unit
	card_title.add_theme_font_size_override("font_size", roundi(20 * unit))
	card_title.size = Vector2(card.size.x - 24 * unit, 26 * unit); card_title.clip_text = true
	card_kind.position = Vector2(12, 31) * unit
	card_kind.add_theme_font_size_override("font_size", roundi(14 * unit))
	card_kind.size = Vector2(card.size.x - 24 * unit, 20 * unit); card_kind.clip_text = true
	card_scroll.position = Vector2(12, 53) * unit
	card_scroll.size = Vector2(card.size.x - 24 * unit, maxf(20 * unit, card.size.y - 109 * unit))
	card_copy.add_theme_font_size_override("font_size", roundi(16 * unit))
	play_button.position = Vector2(12 * unit, card.size.y - 50 * unit); play_button.size = Vector2(160, 44) * unit
	var close: Button = card.get_node("CloseCard")
	close.position = Vector2(card.size.x - 132 * unit, card.size.y - 50 * unit); close.size = Vector2(120, 44) * unit

func _draw() -> void:
	if map.is_empty(): return
	painter.draw(self)
