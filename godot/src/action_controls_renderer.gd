extends RefCounted
## Original vector artwork, not copied game UI/assets. Visual-only: existing
## rectangular multitouch hitboxes remain authoritative, including their edges.
const Controls = preload("res://src/touch_controls.gd")
const HUD = preload("res://src/player_hud.gd")
const INK := Color("0e1726")
const WHITE := Color("f5f1ea")

static func build_commands(host) -> Array:
	var commands: Array = []
	var power := HUD.special_state(host)
	for action in ["jump", "shoot", "special", "dash"]:
		if not host.buttons.has(action): continue
		var rect: Rect2 = host.buttons[action]
		var center := rect.get_center()
		var radius := minf(rect.size.x, rect.size.y) * 0.5 - 3
		var held := Controls.held(host.touches, action)
		var colour := Color("75d7ef") if action == "jump" else Color("f6b86d")
		if action == "dash": colour = Color("a0c5f4")
		elif action == "special": colour = power.colour
		var bright: bool = held or (action == "special" and power.ready)
		commands.append({"type":"circle", "at":center + Vector2(0, 3), "radius":radius + 2, "colour":Color(0.02, 0.04, 0.08, 0.28), "tag":action + "_shadow"})
		commands.append({"type":"circle", "at":center, "radius":radius, "colour":Color(colour, 0.91) if bright else Color(0.055, 0.09, 0.14, 0.64), "tag":action + "_face"})
		commands.append({"type":"ring", "at":center, "radius":radius - 1, "start":0.0, "end":TAU, "width":2.0, "colour":Color(colour, 0.96 if bright else 0.76), "tag":action + "_rim"})
		var icon_colour := INK if bright else WHITE
		var scale := radius / 36.0
		if action == "special":
			commands.append({"type":"ring", "at":center, "radius":radius - 5, "start":0.0, "end":TAU, "width":4.0, "colour":Color(0, 0, 0, 0.34), "tag":"special_track"})
			if power.fill > 0:
				commands.append({"type":"ring", "at":center, "radius":radius - 5, "start":-PI / 2, "end":-PI / 2 + TAU * power.fill, "width":4.0, "colour":INK if power.ready else colour, "tag":"special_active" if power.active else "special_charge"})
			_polygon(commands, center, scale, [Vector2(3,-19), Vector2(-12,3), Vector2(-2,3), Vector2(-5,19), Vector2(13,-5), Vector2(3,-5)], icon_colour, "special_bolt")
			if power.ready:
				for offset in [Vector2(-14,-17), Vector2(17,14)]:
					_line(commands, center + offset * scale, [Vector2(-3,0), Vector2(3,0)], 1.0, icon_colour, 2, "special_ready_spark")
					_line(commands, center + offset * scale, [Vector2(0,-3), Vector2(0,3)], 1.0, icon_colour, 2, "special_ready_spark")
		elif action == "jump":
			_polygon(commands, center, scale, [Vector2(-17,-1), Vector2(0,-19), Vector2(17,-1), Vector2(7,-1), Vector2(7,12), Vector2(-7,12), Vector2(-7,-1)], icon_colour, "jump_arrow")
			_line(commands, center, [Vector2(-15,20), Vector2(15,20)], scale, icon_colour, 3, "jump_ground")
		elif action == "shoot":
			commands.append({"type":"ring", "at":center, "radius":14 * scale, "start":0.0, "end":TAU, "width":2.5, "colour":icon_colour, "tag":"shoot_sight"})
			commands.append({"type":"circle", "at":center, "radius":4 * scale, "colour":icon_colour, "tag":"shoot_center"})
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_line(commands, center, [direction * 10, direction * 23], scale, icon_colour, 3, "shoot_crosshair")
		else:
			for x in [-8, 8]: _line(commands, center, [Vector2(x-6,-12), Vector2(x+6,0), Vector2(x-6,12)], scale, icon_colour, 4, "dash_chevron")
	return commands

static func draw(canvas: CanvasItem, host) -> void:
	for command in build_commands(host):
		match command.type:
			"circle": canvas.draw_circle(command.at, command.radius, command.colour, true, -1, true)
			"ring": canvas.draw_arc(command.at, command.radius, command.start, command.end, 64, command.colour, command.width, true)
			"polygon": canvas.draw_colored_polygon(command.points, command.colour)
			"line": canvas.draw_polyline(command.points, command.colour, command.width, true)

static func _polygon(commands: Array, center: Vector2, scale: float, points: Array, colour: Color, tag: String) -> void:
	var transformed := PackedVector2Array()
	for point in points: transformed.append(center + point * scale)
	commands.append({"type":"polygon", "points":transformed, "colour":colour, "tag":tag})

static func _line(commands: Array, center: Vector2, points: Array, scale: float, colour: Color, width: float, tag: String) -> void:
	var transformed := PackedVector2Array()
	for point in points: transformed.append(center + point * scale)
	commands.append({"type":"line", "points":transformed, "colour":colour, "width":width, "tag":tag})
