extends RefCounted
## Native port of game/1-6/index.html sceneBossDraw/drawBinmanShape/drawBin.
## The host applies the world camera/zoom before draw_world, and switches back
## to logical 960x540 UI coordinates before draw_hud. No canvas transform leaks.
## Simulation times are seconds. Render plans never mutate the boss or RNG.

const SharedRenderer = preload("res://src/rooftop_renderer.gd")
const WIDTH := 960.0
const HEIGHT := 540.0
const BODY_HEIGHT := 300.0
const BODY_WIDTH := 210.0
const SCRAP_COLOURS := [Color("2a6fb0"), Color("2f5d3a"), Color("3a3f4d")]
var _shared = SharedRenderer.new()
var _textures: Dictionary = {}

func draw_world(host, boss) -> void:
	draw_commands(host, build_world_commands(host, boss))

func draw_hud(host, boss) -> void:
	draw_commands(host, build_hud_commands(host, boss))

static func source_round(value: float) -> float:
	return floorf(value + 0.5)

func _state(boss) -> Dictionary:
	if boss == null: return {}
	if boss is Dictionary: return boss
	return boss.state

func _snapped_x(host, x: float) -> float:
	return host.camera.x + source_round(x - host.camera.x)

func build_world_commands(host, boss) -> Array:
	var out: Array = []
	var b := _state(boss)
	if b.is_empty(): return out
	var ground := float(b.get("fy", host.meta.get("ground", 482)))
	# Source snaps camY separately from object Y, unlike the host transform.
	var y_snap := float(host.camera.y) - source_round(host.camera.y)
	var x := _snapped_x(host, b.x)
	var origin := Vector2(x, ground + y_snap)
	var down: bool = b.state == "down"
	_ellipse(out, origin + Vector2(0, -2), Vector2(110, 12), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "boss_shadow")
	if host.images.has("binman") and host.meta.has("binman"):
		_sprite_body(out, host, b, origin, down)
	else:
		_body(out, b, origin, down)
	for wave in b.get("waves", []):
		# Rolling-bin markers exist solely to inform companion AI.
		if wave.get("bin", false): continue
		var wx := _snapped_x(host, wave.x)
		for i in 4:
			_rect(out, Rect2(wx - 6 - i * 8 * signf(wave.vx), ground - 10 - (3 - i) * 7 - sin(float(wave.t) / 0.05 + i) * 3 + y_snap, 12, 10 + (3 - i) * 4), Color("e8e1d2"), "shockwave")
	for bin in b.get("bins", []):
		_bin(out, host, bin, Vector2(_snapped_x(host, bin.x), source_round(bin.y) + y_snap))
	for scrap in b.get("rain", []):
		var rx := _snapped_x(host, scrap.x)
		var ry := source_round(scrap.y) + y_snap
		_rect(out, Rect2(rx - 18, ry - 14, 36, 28), SCRAP_COLOURS[int(scrap.k)], "scrap")
		_rect(out, Rect2(rx - 14, ry - 10, 12, 6), Color(1, 1, 1, 0.35), "scrap_highlight")
	return out

func _body(out: Array, b: Dictionary, origin: Vector2, down: bool) -> void:
	var t := float(b.t)
	var face := float(b.face)
	var step := sin(t / 0.12) * 6 if b.state == "walk" or b.state == "enter" else 0.0
	var rotation := -0.35 * minf(1, t / 0.5) * face if down else 0.0
	var transform := Transform2D(rotation, origin)
	_transformed_rect(out, Rect2(-70 + step, -40, 56, 40), transform, Color("3a2a1e"), "left_boot")
	_transformed_rect(out, Rect2(14 - step, -40, 56, 40), transform, Color("3a2a1e"), "right_boot")
	_transformed_rect(out, Rect2(-BODY_WIDTH / 2, -BODY_HEIGHT + 50, BODY_WIDTH, BODY_HEIGHT - 80), transform, Color("1d4a30"), "body_shell")
	_transformed_rect(out, Rect2(-BODY_WIDTH / 2 + 8, -BODY_HEIGHT + 58, BODY_WIDTH - 16, BODY_HEIGHT - 96), transform, Color("2c6a45"), "body_panel")
	_transformed_rect(out, Rect2(-BODY_WIDTH / 2 + 8, -BODY_HEIGHT + 150, BODY_WIDTH - 16, 14), transform, Color("f07a1c"), "reflective_stripe")
	_transformed_rect(out, Rect2(-BODY_WIDTH / 2 + 8, -BODY_HEIGHT + 156, BODY_WIDTH - 16, 3), transform, Color("f4e27a"), "stripe_highlight")
	var arm := -minf(1, t / 0.4) * 1.6 if b.state == "throw" or b.state == "roll" else sin(t / 0.16) * 0.2
	var arm_transform := transform * Transform2D(arm * face, Vector2(face * (BODY_WIDTH / 2 - 6), -BODY_HEIGHT + 110))
	for i in 6:
		# Signed widths are intentional: the source arm points toward face.
		_transformed_rect(out, Rect2(face * 2, i * 16, 26 * face, 13), arm_transform, Color("8b93a3"), "active_arm_rib")
	_transformed_rect(out, Rect2(0, 96, 34 * face, 26), arm_transform, Color("c3c9d4"), "active_hand")
	for i in 6:
		_transformed_rect(out, Rect2(-face * (BODY_WIDTH / 2 + 22), -BODY_HEIGHT + 110 + i * 16, 22, 13), transform, Color("8b93a3"), "rear_arm_rib")
	var lid := float(b.get("lid", 0))
	_transformed_rect(out, Rect2(-BODY_WIDTH / 2 + 10, -BODY_HEIGHT + 50, BODY_WIDTH - 20, 30 + lid * 40), transform, Color("081a10"), "mouth")
	if lid > 0.3:
		_transformed_rect(out, Rect2(-40, -BODY_HEIGHT + 66, 24, 14), transform, Color("ffde59"), "left_eye")
		_transformed_rect(out, Rect2(16, -BODY_HEIGHT + 66, 24, 14), transform, Color("ffde59"), "right_eye")
		# Canvas paints the translucent disk AFTER the eyes, not as a shadow.
		_ellipse(out, transform * Vector2(0, -BODY_HEIGHT + 80), Vector2(70, 70), Color(1, 222 / 255.0, 89 / 255.0, 0.25), "eye_glow")
	var lid_transform := transform * Transform2D(-lid * 1.2 * face, Vector2(-face * BODY_WIDTH / 2, -BODY_HEIGHT + 50))
	_transformed_rect(out, Rect2(0 if face > 0 else -BODY_WIDTH - 16, -16, BODY_WIDTH + 16, 18), lid_transform, Color("163a26"), "hinged_lid")
	if float(b.get("flash", 0)) > 0:
		# The hurt flash is outside the body rotation in the source as well.
		_rect(out, Rect2(origin + Vector2(-BODY_WIDTH / 2, -BODY_HEIGHT + 40), Vector2(BODY_WIDTH, BODY_HEIGHT - 40)), Color(1, 1, 1, 0.3), "hurt_flash")

func _sprite_body(out: Array, host, b: Dictionary, origin: Vector2, down: bool) -> void:
	# No binman sheet exists in the present 1-6 source, but honor a future
	# imported original sheet rather than substituting the Jar Thief image.
	var dimensions: Dictionary = host.meta.binman
	var size := Vector2(dimensions.w, dimensions.h)
	var moving: bool = b.state == "walk" or b.state == "enter"
	var row := 2 if down else 0 if moving else 1
	var frame := 3 if down else floori(float(b.t) / 0.16) % 4 if moving else mini(3, floori(float(b.t) / 0.21))
	if float(b.get("lid", 0)) > 0.6 and not down and b.state == "walk":
		row = 2
		# Source produces a negative array index after a 2.4s backup opening.
		frame = clampi(floori((1 - float(b.get("lid_t", 0)) / 1.6) * 3), 0, 2)
	var transform := Transform2D(0, origin)
	if float(b.face) > 0: transform = transform * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	if down: transform = transform * Transform2D(-0.25 * minf(1, float(b.t) / 0.5), Vector2.ZERO)
	_texture(out, "binman", Rect2(Vector2(-size.x / 2, -size.y + 6), size), Rect2(Vector2(frame * size.x, row * size.y), size), transform, "boss_sprite")
	if float(b.get("flash", 0)) > 0:
		_rect(out, Rect2(origin + Vector2(-BODY_WIDTH / 2, -BODY_HEIGHT), Vector2(BODY_WIDTH, BODY_HEIGHT)), Color(1, 1, 1, 0.35), "hurt_flash")

func _bin(out: Array, host, bin: Dictionary, origin: Vector2) -> void:
	var transform := Transform2D(float(bin.rot), origin)
	if host.images.has("bin"):
		var size: Vector2 = host.images.bin.get_size()
		_texture(out, "bin", Rect2(-size / 2, size), Rect2(Vector2.ZERO, size), transform, "bin_sprite")
		return
	_transformed_rect(out, Rect2(-30, -40, 60, 80), transform, Color("1f4d32"), "bin_body")
	_transformed_rect(out, Rect2(-26, -36, 52, 72), transform, Color("2f6b44"), "bin_panel")
	_transformed_rect(out, Rect2(-34, -46, 68, 10), transform, Color("173a26"), "bin_lid")
	for wheel_x in [-18, 18]:
		_ellipse(out, transform * Vector2(wheel_x, 40), Vector2(8, 8), Color("222222"), "bin_wheel")

func build_hud_commands(host, boss) -> Array:
	var out: Array = []
	var b := _state(boss)
	if b.is_empty() or b.state == "down": return out
	var width := 420.0
	var x := (WIDTH - width) / 2
	var y := HEIGHT - 40
	_rounded_rect(out, Rect2(x - 4, y - 4, width + 8, 26), 8, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.85), "health_background", Color("f5f1ea"), 2)
	var health := maxf(0, float(b.hp) / float(b.max)) if float(b.max) > 0 else 0.0
	if health > 0:
		_rounded_rect(out, Rect2(x, y, width * health, 18), 6, Color("f4c542") if float(b.get("dizzy", 0)) > 0 else Color("e23b3b"), "health_fill")
	out.append({"type": "left_text", "position": Vector2(x + 8, y - 16), "text": host.meta.get("text", {}).get("boss", "Binman Bot"), "size": 14,
		"colour": Color("f5f1ea"), "outline": Color("0e1726"), "stroke_width": 3.5, "tag": "boss_label"})
	return out

func _rect(out: Array, rectangle: Rect2, colour: Color, tag: String) -> void:
	out.append({"type": "rect", "rect": rectangle, "colour": colour, "tag": tag})

static func rect_points(rectangle: Rect2, transform := Transform2D.IDENTITY) -> PackedVector2Array:
	return transform * PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)])

func _transformed_rect(out: Array, rectangle: Rect2, transform: Transform2D, colour: Color, tag: String) -> void:
	out.append({"type": "polygon", "points": rect_points(rectangle, transform), "colour": colour, "tag": tag})

func _ellipse(out: Array, center: Vector2, radius: Vector2, colour: Color, tag: String) -> void:
	var points := PackedVector2Array()
	for i in 64:
		var angle := TAU * float(i) / 64
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	out.append({"type": "polygon", "points": points, "colour": colour, "tag": tag})

func _rounded_rect(out: Array, rectangle: Rect2, radius: float, colour: Color, tag: String, outline := Color.TRANSPARENT, line_width := 0.0) -> void:
	# Canvas arcTo can cross its own edge at a near-empty health width. Clamp
	# just that corner radius for a valid native polygon, preserving fill width.
	radius = minf(radius, minf(rectangle.size.x, rectangle.size.y) / 2)
	var points := PackedVector2Array()
	var centers := [rectangle.position + Vector2(radius, radius), Vector2(rectangle.end.x - radius, rectangle.position.y + radius), rectangle.end - Vector2(radius, radius), Vector2(rectangle.position.x + radius, rectangle.end.y - radius)]
	for corner in 4:
		for segment in 9:
			var angle := PI + corner * PI / 2 + segment * PI / 16
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	out.append({"type": "rounded_polygon", "points": points, "colour": colour, "outline": outline, "width": line_width, "rect": rectangle, "radius": radius, "tag": tag})

func _texture(out: Array, key: String, rectangle: Rect2, source: Rect2, transform: Transform2D, tag: String) -> void:
	out.append({"type": "textured_polygon", "points": rect_points(rectangle, transform), "key": key, "source": source, "rect": rectangle, "tag": tag})

func _filtered(texture: Texture2D) -> CanvasTexture:
	var id := texture.get_instance_id()
	if not _textures.has(id):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = texture
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_textures[id] = canvas
	return _textures[id]

func clear_cache() -> void:
	_textures.clear()
	_shared.clear_cache()

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		match command.type:
			"polygon": host.draw_colored_polygon(command.points, command.colour)
			"rounded_polygon":
				# Canvas fills, then outlines this helper (not the reverse).
				host.draw_colored_polygon(command.points, command.colour)
				if command.width > 0 and command.outline.a > 0:
					var outline: PackedVector2Array = command.points.duplicate()
					outline.append(outline[0])
					host.draw_polyline(outline, command.outline, command.width)
			"textured_polygon":
				var texture: Texture2D = host.images[command.key]
				var uv := rect_points(command.source)
				for i in uv.size(): uv[i] /= texture.get_size()
				host.draw_polygon(command.points, PackedColorArray([Color.WHITE]), uv, _filtered(texture))
			"left_text":
				var baseline: Vector2 = command.position + Vector2(0, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				host.draw_string_outline(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, int(ceilf(command.stroke_width / 2)), command.outline)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
			_: _shared.draw_commands(host, [command])
