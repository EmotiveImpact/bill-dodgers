extends RefCounted
## Direction input is independent from its final selected visual style. A single
## thumb supports diagonals and a neutral center; actions use other touch IDs.
const DIRECTIONS := ["left", "right", "aim", "down"]
const CELL := 64.0

static func layout(viewport: Vector2, safe: Vector2, has_dash: bool) -> Dictionary:
	var pad := Rect2(safe.x + 8, viewport.y - safe.y - CELL * 3 - 8, CELL * 3, CELL * 3)
	var buttons := {
		"left": Rect2(pad.position + Vector2(0, CELL), Vector2.ONE * CELL),
		"right": Rect2(pad.position + Vector2(CELL * 2, CELL), Vector2.ONE * CELL),
		"aim": Rect2(pad.position + Vector2(CELL, 0), Vector2.ONE * CELL),
		"down": Rect2(pad.position + Vector2(CELL, CELL * 2), Vector2.ONE * CELL),
		"jump": Rect2(viewport.x - safe.x - 174, viewport.y - safe.y - 82, 76, 76),
		"shoot": Rect2(viewport.x - safe.x - 86, viewport.y - safe.y - 100, 86, 86),
		"special": Rect2(viewport.x - safe.x - 106, viewport.y - safe.y - 184, 106, 76)
	}
	if has_dash: buttons.dash = Rect2(viewport.x - safe.x - 280, viewport.y - safe.y - 152, 86, 76)
	return {"pad": pad, "buttons": buttons}

static func direction_at(pad: Rect2, position: Vector2) -> String:
	if not pad.has_point(position): return ""
	var offset := (position - pad.get_center()) / (pad.size * 0.5)
	var actions: Array[String] = []
	# 1/3 is the neutral square; corners activate both compatible axes.
	if offset.x < -1.0 / 3: actions.append("left")
	elif offset.x > 1.0 / 3: actions.append("right")
	if offset.y < -1.0 / 3: actions.append("aim")
	elif offset.y > 1.0 / 3: actions.append("down")
	return "+".join(actions)

static func held(touches: Dictionary, action: String) -> bool:
	for value in touches.values():
		if action in str(value).split("+"): return true
	return false

static func joystick_direction(pad: Rect2, position: Vector2) -> String:
	var offset := position - pad.get_center()
	if offset.length() <= pad.size.x * 0.10: return ""
	var actions: Array[String] = []
	# Eight sectors, retaining the original digital side-scroller movement.
	# Up aims and down ducks; jumping remains an independent button.
	if absf(offset.x) >= absf(offset.y) * 0.414214: actions.append("left" if offset.x < 0 else "right")
	if absf(offset.y) >= absf(offset.x) * 0.414214: actions.append("aim" if offset.y < 0 else "down")
	return "+".join(actions)

static func joystick_knob(pad: Rect2, contacts: Dictionary) -> Vector2:
	if contacts.is_empty(): return pad.get_center()
	var offset: Vector2 = contacts.values()[0] - pad.get_center()
	return pad.get_center() + offset.limit_length(pad.size.x * 0.29)

static func draw_joystick(canvas: CanvasItem, pad: Rect2, contacts: Dictionary) -> void:
	var center := pad.get_center()
	var radius := pad.size.x * 0.46
	var knob := joystick_knob(pad, contacts)
	# Reference-style transparent travel zone and pale thumb grip. The base
	# stays anchored, so lifting always returns the grip to a predictable rest.
	canvas.draw_circle(center, radius, Color(0.06,0.10,0.16,0.22), true, -1, true)
	canvas.draw_circle(center, radius, Color(0.95,0.97,1,0.28), false, 2, true)
	canvas.draw_circle(center, radius * 0.76, Color(0.95,0.97,1,0.09), false, 1, true)
	canvas.draw_circle(knob + Vector2(0,3), pad.size.x * 0.18, Color(0.04,0.07,0.11,0.22), true, -1, true)
	canvas.draw_circle(knob, pad.size.x * 0.17, Color(0.85,0.89,0.94,0.55), true, -1, true)
	canvas.draw_circle(knob, pad.size.x * 0.17, Color(1,1,1,0.62), false, 2, true)

static func draw_dpad(canvas: CanvasItem, pad: Rect2, touches: Dictionary) -> void:
	var cell := pad.size.x / 3
	var outline := PackedVector2Array()
	for point in [Vector2(1,0),Vector2(2,0),Vector2(2,1),Vector2(3,1),Vector2(3,2),Vector2(2,2),Vector2(2,3),Vector2(1,3),Vector2(1,2),Vector2(0,2),Vector2(0,1),Vector2(1,1)]: outline.append(pad.position + point * cell)
	canvas.draw_circle(pad.get_center(), cell * 1.47, Color(0.035,0.05,0.08,0.18), true, -1, true)
	canvas.draw_colored_polygon(outline, Color(0.055,0.075,0.11,0.84))
	var ring := outline.duplicate();ring.append(ring[0]);canvas.draw_polyline(ring,Color(0.82,0.87,0.92,0.86),2,true)
	var zones := {"left":Vector2(0,1),"right":Vector2(2,1),"aim":Vector2(1,0),"down":Vector2(1,2)}
	for action in DIRECTIONS:
		var center: Vector2 = pad.position + (zones[action] + Vector2(0.5,0.5)) * cell
		var active := held(touches,action)
		if active: canvas.draw_rect(Rect2(center-Vector2.ONE*(cell/2-3),Vector2.ONE*(cell-6)),Color(0.96,0.77,0.26,0.82))
		var angle: float = {"left":PI,"right":0.0,"aim":-PI/2,"down":PI/2}[action]
		var transform := Transform2D(angle,center)
		var arrow := transform * PackedVector2Array([Vector2(13,0),Vector2(-6,-12),Vector2(-6,12)])
		canvas.draw_colored_polygon(arrow,Color("14243b") if active else Color("f5f1ea"))
	canvas.draw_circle(pad.get_center(),cell*0.2,Color(0.26,0.31,0.39,0.9),true,-1,true)
