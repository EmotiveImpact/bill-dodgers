extends Node2D
## Source drawHUD + ability meter, in screen coordinates above the world and
## below interactive controls, transitions, pause and story. Never mutates play.
const Abilities = preload("res://src/abilities.gd")
const Notifications = preload("res://src/hud_notifications.gd")
const HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
const NAMES := {"jp": "Jean Phil", "maya": "Maya", "ama": "Ama", "leo": "Leo", "theo": "Theo", "mei": "Mei"}
const GOLD := Color("f4c542")
const WHITE := Color("f5f1ea")
const INK := Color("0e1726")
var game
var _styles: Dictionary = {}
var draw_count := 0
var notifications := Notifications.new()

func _process(_delta: float) -> void:
	queue_redraw()

func is_game_visible(host) -> bool:
	return host != null and not host.meta.is_empty() and (host.mode in ["play", "over", "clear"] or (host.mode == "paused" and host._paused_mode == "play"))

func _draw() -> void:
	if not is_game_visible(game): return
	draw_commands(self, game.font, build_commands(game, get_viewport_rect().size))
	draw_count += 1

static func special_state(host) -> Dictionary:
	var spec: Dictionary = Abilities.SPEC.get(host.character, Abilities.SPEC.jp)
	var active: bool = not host.abilities.active.is_empty() and host.abilities.remaining > 0
	var fill: float = host.abilities.remaining / maxf(0.001, host.abilities.duration) if active else host.abilities.meter
	return {"colour": Color(spec.color), "fill": clampf(fill, 0, 1), "active": active,
		"ready": not active and host.abilities.meter >= 1, "name": str(spec.name)}

static func has_pair(host) -> bool:
	return "party_session" in host and host.party_session.active and host.party_session.runtime.actors.size() >= 2

static func layout(viewport: Vector2, safe: Vector2, pair := false) -> Dictionary:
	# Original 960x540 layout with a notch inset, rather than world/camera space.
	var inset := maxf(12, safe.x)
	var right := viewport.x - maxf(12, safe.x)
	var controls_y := 76.0 if pair else 11.0
	return {"left": inset, "center": viewport.x * 0.5, "right": right,
		"portrait": Rect2(inset, 6, 54, 54), "right_portrait": Rect2(right - 54, 6, 54, 54), "hearts": Rect2(inset + 64, 30, 73, 18),
		"special": Rect2(inset + 64, 54, 150, 8), "kitty": Rect2(viewport.x * 0.5 - 70, 26, 160, 16),
		"controls": [Rect2(right - 286, controls_y, 64, 44), Rect2(right - 214, controls_y, 66, 44), Rect2(right - 140, controls_y, 62, 44), Rect2(right - 70, controls_y, 70, 44)]}

func build_commands(host, viewport := Vector2(960, 540)) -> Array:
	var out: Array = []
	var pair := has_pair(host)
	var boxes := layout(viewport, host.safe_padding, pair)
	var roster: Array = host.party_session.runtime.actors if pair else [host]
	var mx := float(boxes.center)
	_rect(out, Rect2(0, 0, viewport.x, 66), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.86), "hud_back")
	_rect(out, Rect2(0, 66, viewport.x, 3), Color("2d6a4f"), "hud_rule")
	if host.level_id == "1-1" and host.boss != null and host.boss.state.state != "down":
		var boss_state: Dictionary = host.boss.state
		var boss_x := (viewport.x - 420) / 2
		var boss_y := viewport.y - 40
		_rounded(out, Rect2(boss_x - 4, boss_y - 4, 428, 26), 8, Color(INK, 0.85), "thief_health_back", WHITE, 2)
		var fraction := clampf(float(boss_state.hp) / maxf(1, float(boss_state.max)), 0, 1)
		if fraction > 0: _rounded(out, Rect2(boss_x, boss_y, 420 * fraction, 18), 6, GOLD if float(boss_state.get("dizzy", 0)) > 0 else Color("e23b3b"), "thief_health_fill")
		_text(out, Vector2(boss_x + 8, boss_y - 16), str(host.meta.get("text", {}).get("boss", "Jar thief")), 14, WHITE, "thief_health_label")
	for slot in mini(2, roster.size()):
		var member = roster[slot]
		var coins := int(member.coins) if pair else maxi(0, int(host.score) - int(host.receipt_score))
		_player_block(out, host, member, boxes, slot, bool(member.cpu) if pair else false, coins)
	var kitty_fill := clampf(float(host.score) / 120.0, 0, 1)
	_jar(out, Vector2(mx - 92, 40), kitty_fill, 1.1)
	_rounded(out, boxes.kitty, 8, Color("2a3a52"), "kitty_back", WHITE, 2)
	if kitty_fill > 0: _rounded(out, Rect2(mx - 68, 28, maxf(12, 156 * kitty_fill), 12), 6, GOLD, "kitty_fill")
	_text(out, Vector2(mx + 10, 54), "Kitty £%d" % host.score, 11, Color("dce8d3"), "kitty_label", true)
	_text(out, Vector2(mx + 10, 14), str(host.meta.get("text", {}).get("hud", host.level_id)), 11, Color("9fb0c8"), "level_label", true, false)
	# Source drawWorld's banners precede the outer ability HUD wrapper.
	var ending: bool = host.mode != "play" or host.scene_runtime.end_time > 0
	out.append_array(notifications.build_commands(viewport, ending))
	# Original ability activation briefly washes the screen before the meter.
	# AB.flash is one global wash: simultaneous specials use the last actor,
	# otherwise the most recently activated actor supplies its colour.
	var flash_member = null
	var flash_age := 0.26
	for member in roster:
		var age: float = member.abilities.duration - member.abilities.remaining
		if not member.abilities.active.is_empty() and age >= 0 and age <= flash_age:
			flash_member = member; flash_age = age
	if flash_member != null and flash_age < 0.26:
		_rect(out, Rect2(Vector2.ZERO, viewport), Color(Color(Abilities.SPEC.get(flash_member.character, Abilities.SPEC.jp).color), 0.16 * (1 - flash_age / 0.26)), "special_flash")
	for slot in mini(2, roster.size()):
		_special_block(out, host, roster[slot], boxes, slot, bool(roster[slot].cpu) if pair else false)

	return out

func _player_block(out: Array, host, member, boxes: Dictionary, slot: int, cpu: bool, coin_count: int) -> void:
	var right := slot == 1
	var px := float(boxes.right) - 54 if right else float(boxes.left)
	var tx := px - 10 if right else px + 64
	var start := out.size()
	_rounded(out, Rect2(px,6,54,54), 8, Color("2a3a52"), "portrait_back", WHITE, 2)
	var who: String = member.character
	var head: Dictionary = host.meta.get("heads", {}).get(who, {})
	if not head.is_empty() and host.sheets.has(who):
		var sheet: Dictionary = host.meta.get("sheets", {}).get(who, host.sheet_meta.get(who, {}))
		var frame_y := float(sheet.get("h", 0)) * float(sheet.get("anims", {}).get("idle", {}).get("row", 0))
		out.append({"type":"texture", "texture":host.sheets[who], "rect":Rect2(px+2,8,50,50), "source":Rect2(float(head.x),frame_y+float(head.y),float(head.size),float(head.size)), "tag":"portrait"})
	var name_tag := "CPU " if cpu else "P%d " % (slot+1)
	_text(out, Vector2(tx,18), name_tag + str(NAMES.get(who,who)),14, Color("ff8fc7") if right else GOLD,"player_name",false,true,right)
	for i in 3: _heart(out, Vector2(tx-24-i*26 if right else tx+i*26,30),i<member.hearts,i)
	var cx := tx-100 if right else tx+92
	_coin(out,Vector2(cx,39),1.2,host.elapsed/.08)
	_text(out,Vector2(cx-12 if right else cx+12,40),"x%d"%coin_count,14,WHITE,"player_coins",false,true,right)
	if not member.power.is_empty() and member.power_time>0:
		_text(out,Vector2(tx-170 if right else tx+160,40),str({"split":"x3 ","debit":"DD ","wellies":"WB "}.get(member.power,"DD "))+str(ceili(member.power_time)),12,GOLD,"weapon_countdown",false,true,right)
	if right:
		for i in range(start,out.size()):out[i].tag="p2_"+str(out[i].tag)

func _special_block(out: Array, host, member, boxes: Dictionary, slot: int, cpu: bool) -> void:
	var right := slot == 1
	var tx := float(boxes.right)-64-150 if right else float(boxes.left)+64
	var start := out.size()
	var power := special_state(member)
	var border: Color = (Color.WHITE if int(host.elapsed / 0.22) % 2 else power.colour) if power.ready else Color(WHITE, 0.35)
	_rounded(out,Rect2(tx-2,52,154,12),5,Color(0,0,0,.5),"special_back",border,2 if power.ready else 1)
	var fill := floorf(150 * float(power.fill) + 0.5)
	if fill>0:
		var fx := tx+150-fill if right else tx
		_rounded(out,Rect2(fx,54,fill,8),4,power.colour,"special_fill")
		_rect(out,Rect2(fx+2,55,maxf(0,fill-4),2),Color(1,1,1,.35),"special_highlight")
	var ready_key := "READY" if cpu else ("TAP" if DisplayServer.is_touchscreen_available() else ("R" if right else "C"))
	var key := ready_key if power.ready else (str(power.name).split(" ")[0].to_upper() if power.active else "SP")
	_text(out,Vector2(tx-8 if right else tx+158,58),key,10,power.colour if power.ready or power.active else Color("9fb0c8"),"special_label",false,true,right)
	if right:
		for i in range(start,out.size()):out[i].tag="p2_"+str(out[i].tag)

func draw_commands(canvas: CanvasItem, source_font: Font, commands: Array) -> void:
	for c in commands:
		match c.type:
			"rect": canvas.draw_rect(c.rect, c.colour)
			"polygon": canvas.draw_colored_polygon(c.points, c.colour)
			"texture": canvas.draw_texture_rect_region(c.texture, c.rect, c.source)
			"rounded":
				var key := "%s:%s:%s:%s" % [c.radius, c.colour, c.stroke, c.width]
				if not _styles.has(key):
					var style := StyleBoxFlat.new()
					style.bg_color = c.colour
					style.set_corner_radius_all(int(c.radius))
					style.set_border_width_all(int(c.width))
					style.border_color = c.stroke
					_styles[key] = style
				canvas.draw_style_box(_styles[key], c.rect)
			"text":
				var position: Vector2 = c.position + Vector2(0, c.size * 0.36)
				if c.center: position.x -= source_font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.size).x * 0.5
				elif c.get("right",false): position.x -= source_font.get_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.size).x
				if c.outline: canvas.draw_string_outline(source_font, position, c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.size, maxi(3, c.size / 4), Color(INK, c.colour.a))
				canvas.draw_string(source_font, position, c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.size, c.colour)

func _heart(out: Array, position: Vector2, on: bool, index: int) -> void:
	for row in HEART.size():
		for col in 7:
			if HEART[row][col] != "X": continue
			var colour := (Color("ffb3b3") if row == 1 and col == 1 else Color("e23b3b")) if on else Color("3a4458")
			_rect(out, Rect2(position + Vector2(col, row) * 3, Vector2(3, 3)), colour, "heart_%d" % index)

func _coin(out: Array, position: Vector2, scale: float, phase: float) -> void:
	var width: float = [12, 9, 4, 9][int(phase) % 4] * scale
	var height := 12 * scale
	_rect(out, Rect2(position - Vector2(width, height) / 2 - Vector2.ONE * scale, Vector2(width, height) + Vector2.ONE * scale * 2), Color("7a5410"), "coin_edge")
	_rect(out, Rect2(position - Vector2(width, height) / 2, Vector2(width, height)), GOLD, "coin_face")
	if width > 5 * scale:
		_rect(out, Rect2(position - Vector2(width, height) / 2 + Vector2.ONE * scale, Vector2(2, 5) * scale), Color("fff1a8"), "coin_shine")
		_rect(out, Rect2(position - Vector2(1, 3) * scale, Vector2(2, 6) * scale), Color("c99a1d"), "coin_mark")

func _jar(out: Array, position: Vector2, fill: float, scale: float) -> void:
	_rect(out, Rect2(position + Vector2(-9, -22) * scale, Vector2(18, 6) * scale), Color("b07a2a"), "jar_lid")
	_rounded(out, Rect2(position + Vector2(-14, -16) * scale, Vector2(28, 30) * scale), 8 * scale, Color(200 / 255.0, 230 / 255.0, 1, 0.3), "jar_glass", Color("dce8f0"), 2)
	var height := floorf(26 * fill + 0.5)
	if height > 0:
		# Clip the original rounded interior at its moving liquid level.
		var points := PackedVector2Array()
		var corners := [Vector2(5, -7), Vector2(5, 5), Vector2(-5, 5), Vector2(-5, -7)]
		for corner in 4:
			for j in 9:
				var angle := (-PI / 2 + corner * PI / 2) + j * PI / 16
				var point: Vector2 = corners[corner] + Vector2(cos(angle), sin(angle)) * 7
				point.y = maxf(point.y, 12 - height)
				points.append(position + point * scale)
		out.append({"type": "polygon", "points": points, "colour": GOLD, "tag": "jar_fill"})
		for i in 6:
			var coin := Rect2(Vector2(-10 + (i * 7) % 20, 10 - fmod(i * 5, height)), Vector2(4, 2))
			coin = coin.intersection(Rect2(-12, 12 - height, 24, height))
			if coin.has_area(): _rect(out, Rect2(position + coin.position * scale, coin.size * scale), Color("c99a1d"), "jar_coin")
	_rect(out, Rect2(position + Vector2(-10, -12) * scale, Vector2(3, 8) * scale), Color.WHITE, "jar_shine")

func _rect(out: Array, rect: Rect2, colour: Color, tag: String) -> void:
	if rect.has_area(): out.append({"type": "rect", "rect": rect, "colour": colour, "tag": tag})

func _rounded(out: Array, rect: Rect2, radius: float, colour: Color, tag: String, stroke := Color.TRANSPARENT, width := 0) -> void:
	if rect.has_area(): out.append({"type": "rounded", "rect": rect, "radius": minf(radius, minf(rect.size.x, rect.size.y) / 2), "colour": colour, "stroke": stroke, "width": width, "tag": tag})

func _text(out: Array, position: Vector2, text: String, size: int, colour: Color, tag: String, center := false, outline := true, right := false) -> void:
	out.append({"type": "text", "position": position, "text": text, "size": size, "colour": colour, "center": center, "outline": outline, "tag": tag})
	if right: out[-1].right=true
