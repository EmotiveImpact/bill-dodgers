extends RefCounted
## Translation of game/1-1/index.html drawSelect(), including its final source
## full-frame sprite anchors and original colored arched-doorway geometry.
const COLORS := [Color("2d6a4f"),Color("7a2e3a"),Color("1f3a66"),Color("28604a"),Color("6b4a2b"),Color("4b3a6e")]
const GOLD := Color("f4c542")
const PINK := Color("ff8fc7")

func panel(host, rect: Rect2, color: Color, border: Color, radius: int, border_width: int = 2) -> void:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = border
	style.set_corner_radius_all(radius); style.set_border_width_all(border_width)
	host.draw_style_box(style,rect)

func text(host, value: String, position: Vector2, font_size: int, color: Color) -> void:
	var width: float = host.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline: float = position.y + (host.font.get_ascent(font_size) - host.font.get_descent(font_size)) / 2
	host.draw_string(host.font,Vector2(position.x - width / 2,baseline),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func sprite_state(host, key: String) -> Dictionary:
	var chosen: bool = key == host.draft.p1 or (key == host.draft.p2 and host.draft.mode != "solo")
	var anim := "win" if chosen else "idle"
	var data: Dictionary = host.info.sheets[key]
	var frame := int(host.elapsed / (0.16 if chosen else 0.20)) % int(data.anims[anim].frames)
	return {"animation":anim,"frame":frame,"source":Rect2(frame * data.w,float(data.anims[anim].row) * data.h,data.w,data.h)}

func draw(host) -> void:
	host.draw_rect(Rect2(Vector2.ZERO,host.size),Color("2a3348"))
	if host.background != null:
		var factor: float = host.size.y / 540
		host.draw_texture_rect(host.background,Rect2(Vector2.ZERO,host.background.get_size() * factor),false)
	host.draw_rect(Rect2(Vector2.ZERO,host.size),Color(14/255.0,23/255.0,38/255.0,0.62))
	var center: float = host.size.x / 2
	text(host,"Player 1: pick your friend" if host.step == 0 else "Now pick your mate",host.heading_center,host.heading_size,GOLD)
	for line in host.hint_lines.size():
		text(host,host.hint_lines[line],host.hint_center + Vector2(0,line * 18),host.hint_size,Color("dce8d3"))
	for index in host.CAST.size():
		var key: String = host.CAST[index]
		var rect: Rect2 = host.cards[key]
		var p1: bool = host.draft.p1 == key
		var p2: bool = host.draft.p2 == key and host.draft.mode != "solo"
		var hover: bool = host.cursor == index
		var border := GOLD if p1 else (PINK if p2 else (Color("f5f1ea") if hover else Color("556178")))
		panel(host,rect,Color("2a2f3d"),border,14,4 if p1 or p2 or hover else 2)
		var sy := rect.size.y / 290
		var sx := rect.size.x / 138
		var arch := PackedVector2Array([rect.position + Vector2(14*sx,rect.size.y - 40*sy),rect.position + Vector2(14*sx,70*sy)])
		for vertex in range(21):
			var angle := PI + vertex * PI / 20
			arch.append(rect.position + Vector2(rect.size.x/2 + cos(angle)*(rect.size.x/2-14*sx),70*sy + sin(angle)*(rect.size.x/2-14*sx)))
		arch.append(rect.position + Vector2(rect.size.x-14*sx,rect.size.y-40*sy))
		host.draw_colored_polygon(arch,COLORS[index])
		var inner := PackedVector2Array()
		for vertex in range(21):
			var angle := PI + vertex * PI / 20
			inner.append(rect.position + Vector2(rect.size.x/2 + cos(angle)*(rect.size.x/2-22*sx),70*sy + sin(angle)*(rect.size.x/2-22*sx)))
		host.draw_colored_polygon(inner,Color(1,1,1,0.08))
		host.draw_rect(Rect2(rect.position + Vector2(6*sx,rect.size.y-40*sy),Vector2(rect.size.x-12*sx,10*sy)),Color("c9bfae"))
		var state := sprite_state(host,key)
		var data: Dictionary = host.info.sheets[key]
		var texture: Texture2D = host.pictures.get("sprite-" + key)
		if texture != null:
			var amount := minf(sx,sy)
			var feet := rect.position + Vector2(rect.size.x/2,rect.size.y-40*sy)
			var dest := Rect2(feet - Vector2(float(data.w)*0.45,float(data.h)-3)*amount,Vector2(data.w,data.h)*amount)
			host.draw_texture_rect_region(texture,dest,state.source)
		panel(host,Rect2(rect.position + Vector2(10*sx,rect.size.y-30*sy),Vector2(rect.size.x-20*sx,24*sy)),Color("14243b"),Color.TRANSPARENT,6,0)
		text(host,str(host.info.cast[key]),rect.position + Vector2(rect.size.x/2,rect.size.y-18*sy),14,Color("f5f1ea"))
		if p1 or p2:
			var badge := Rect2(rect.position + Vector2(rect.size.x/2-28,-16),Vector2(56,26))
			panel(host,badge,GOLD if p1 else PINK,Color.TRANSPARENT,8,0)
			text(host,"P1" if p1 else ("CPU" if host.draft.mode == "cpu" else "P2"),badge.get_center(),14,Color("14243b"))
	var mode_rect: Rect2 = host.mode_button.get_rect()
	panel(host,mode_rect,Color(14/255.0,23/255.0,38/255.0,0.9),GOLD if host.mode_button.has_focus() else Color("dce8d3"),22)
	text(host,host.MODE_LABELS[host.draft.mode],mode_rect.get_center(),roundi(13 * host.ui_scale),Color("dce8d3"))
	var go_rect: Rect2 = host.start_button.get_rect()
	panel(host,go_rect,Color("2d6a4f") if host.can_start() else Color(45/255.0,106/255.0,79/255.0,0.35),GOLD if host.start_button.has_focus() else Color("9fe0b8"),22)
	text(host,host.start_button.text,go_rect.get_center(),roundi(15 * host.ui_scale),Color.WHITE if host.can_start() else Color("9fb0c8"))
	for control in [host.back_button,host.cancel_button]:
		panel(host,control.get_rect(),Color(14/255.0,23/255.0,38/255.0,0.9),GOLD if control.has_focus() else Color("556178"),12)
		text(host,control.text,control.get_rect().get_center(),roundi(13 * host.ui_scale),Color("dce8d3"))
	var footer := "F changes mate · Backspace goes back · Two players is local keyboard"
	if not host.message.is_empty(): footer = host.message
	text(host,footer,Vector2(center,host.size.y - host.game.safe_padding.y - 10),11,Color("9fb0c8"))
