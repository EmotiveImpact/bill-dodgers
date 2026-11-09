class_name StoryPlayer
extends Node2D
## Local native story overlay. Dialogue advances manually; silent shots honor hold.
signal finished(scene_id: String, skipped: bool)
const ART = "res://assets/cutscenes/"
const NAMES = {"jp":"Jean Phil", "maya":"Maya", "ama":"Ama", "leo":"Leo", "theo":"Theo", "mei":"Mei", "crunch":"Crunch", "binman":"Binman Bot", "phone":"Commune", "all":"Everyone", "narr":"", "bot":"Robot", "till":"Unexpected Item", "tout":"The Ticket Tout", "captain":"Captain Overcharge", "king":"The Cardboard King", "charge":"Sir Charge"}
var data: Dictionary = {}
var shots: Array = []
var scene_id = ""
var shot_index = -1
var elapsed = 0.0
var playing = false
var paused = false
var shot: Dictionary = {}
var textures: Dictionary = {}
var font: Font = ThemeDB.fallback_font
var panel: Control
var dialogue: Label
var insert_label: Label
var caption: Label
var heading: Label
var next_button: Button
var skip_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/fonts/pixelify.woff2"):
		font = load("res://assets/fonts/pixelify.woff2")
		font.fallbacks = [ThemeDB.fallback_font]
	z_index = 100
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content/story.json"))
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size = Vector2(960, 540)
	add_child(panel)
	dialogue = _label(Vector2(24, 391), Vector2(912, 108), 23)
	insert_label = _label(Vector2(205, 57), Vector2(550, 312), 18)
	caption = _label(Vector2(24, 12), Vector2(750, 32), 18)
	heading = _label(Vector2(150, 150), Vector2(660, 210), 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists("res://assets/fonts/silk.woff2"):
		heading.add_theme_font_override("font", load("res://assets/fonts/silk.woff2"))
	next_button = _button("Next ›", Vector2(770, 502), advance)
	skip_button = _button("Skip story", Vector2(800, 8), skip)
	hide()

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = pos
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func _button(text: String, pos: Vector2, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(150, 36)
	button.add_theme_font_override("font", font)
	button.pressed.connect(action)
	panel.add_child(button)
	return button

func play(id: String) -> bool:
	if not data.get("scenes", {}).has(id):
		push_warning("Unknown story: " + id)
		return false
	if playing:
		stop()
	scene_id = id
	shots = resolve_shots(data.scenes[id].shots)
	shot_index = -1
	playing = true
	set_paused(false)
	show()
	advance()
	return true

func stop() -> void:
	_finish(true)

func skip() -> void:
	if paused: return
	_finish(true)

func set_paused(value: bool) -> void:
	paused = value
	if next_button != null: next_button.disabled = value
	if skip_button != null: skip_button.disabled = value

func _finish(skipped: bool) -> void:
	if not playing:
		return
	playing = false
	hide()
	finished.emit(scene_id, skipped)

func advance() -> void:
	if not playing or paused:
		return
	shot_index += 1
	if shot_index >= shots.size():
		_finish(false)
		return
	shot = shots[shot_index]
	elapsed = 0
	var say: Dictionary = shot.get("say", {})
	dialogue.text = (str(NAMES.get(say.get("w", ""), say.get("w", ""))) + "\n" + str(say.get("t", ""))).strip_edges()
	caption.text = str(shot.get("cap", ""))
	var title: Dictionary = shot.get("title", {})
	heading.text = "\n".join([str(title.get("top", "")), str(title.get("title", "")), str(title.get("sub", ""))]).strip_edges()
	insert_label.text = insert_text(shot.get("insert", {}))
	next_button.text = "Finish ›" if shot_index == shots.size() - 1 else "Next ›"
	queue_redraw()

static func insert_text(ins: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["head", "time", "title", "sub"]:
		if ins.has(key): lines.append(str(ins[key]))
	for line in ins.get("lines", []):
		lines.append(str(line).replace("|hi", "").replace("|", "   "))
	for line in ins.get("total", []): lines.append(str(line))
	for key in ["stamp", "badge", "footer"]:
		if ins.has(key): lines.append(str(ins[key]))
	return "\n".join(lines)

func _process(delta: float) -> void:
	if not playing or paused:
		return
	elapsed += delta * 1000.0
	insert_label.visible = elapsed >= float(shot.get("insert", {}).get("dl", 250))
	if not shot.has("say") and elapsed >= float(shot.get("hold", 1800)):
		advance()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not playing or paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			advance()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()

func resolve_shots(source: Array) -> Array:
	var resolved: Array = []
	for original in source:
		var current: Dictionary = original.duplicate(true)
		if current.get("keep", false) and not resolved.is_empty():
			var previous: Dictionary = resolved.back()
			if not current.has("bg"): current.bg = previous.bg
			if not current.has("cam"): current.cam = previous.get("cam2", previous.cam).duplicate()
			if not current.has("tint") and previous.has("tint"): current.tint = previous.tint
			for kind in ["actors", "props"]:
				var carry: Array = []
				for item in previous.get(kind, []):
					var actor: Dictionary = item.duplicate(true)
					if actor.has("to"):
						actor.x = actor.to[0]
						actor.y = actor.to[1]
						actor.erase("to")
					for pair in [["a2", "a"], ["h2", "hold"], ["f2", "f"]]:
						if actor.get(pair[0]) != null: actor[pair[1]] = actor[pair[0]]
						actor.erase(pair[0])
					for key in ["dl", "d", "once", "fadeIn", "appear", "adl"]: actor.erase(key)
					if actor.get("id", "") in current.get("drop", []): continue
					actor.merge(current.get("set", {}).get(actor.get("id", ""), {}), true)
					carry.append(actor)
				current[kind] = carry + current.get(kind, [])
		for kind in ["actors", "props"]:
			for i in range(current.get(kind, []).size()):
				var actor: Dictionary = current[kind][i]
				if not actor.has("id"): actor.id = str(actor.get("s", actor.get("p", "undefined"))) + str(i)
		if not current.has("cam"): current.cam = [0, 0, data.meta.bg.get(current.bg, [1536, 1024])[0]]
		resolved.append(current)
	return resolved

func _texture(key: String) -> Texture2D:
	if not textures.has(key):
		textures[key] = load(ART + key) if ResourceLoader.exists(ART + key) else null
	return textures[key]

func _ease(t: float) -> float:
	return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2

func _state(actor: Dictionary, time: float) -> Dictionary:
	var pos = Vector2(actor.get("x", 0), actor.get("y", 0))
	var progress = 1.0
	if actor.has("to"):
		progress = clampf((time - float(actor.get("dl", 0))) / maxf(1, float(actor.get("d", 1200))), 0, 1)
		pos = pos.lerp(Vector2(actor.to[0], actor.to[1]), progress if actor.get("lin", false) else _ease(progress))
	pos.y -= abs(sin(time / 1000 * PI * float(actor.get("hopf", 2)))) * float(actor.get("hop", 0))
	pos.y += sin(time / 1000 * TAU * float(actor.get("bobf", 0.5))) * float(actor.get("bob", 0))
	return {"pos":pos, "arrived":progress >= 1}

func _draw() -> void:
	if not playing or shot.is_empty(): return
	var time = 0.0 if shot.get("freeze", false) else elapsed
	var cam: Array = shot.cam.duplicate()
	if shot.has("cam2"):
		var t = _ease(clampf(time / maxf(1, float(shot.get("pd", 7000))), 0, 1))
		for i in range(3): cam[i] = lerpf(float(cam[i]), float(shot.cam2[i]), t)
	var zoom = 960.0 / float(cam[2])
	var origin = Vector2(cam[0], cam[1])
	draw_rect(Rect2(0, 0, 960, 540), Color.BLACK)
	var bg = _texture("bg-" + str(shot.bg) + ".webp")
	if bg: draw_texture_rect_region(bg, Rect2(0, 0, 960, 540), Rect2(origin, Vector2(cam[2], float(cam[2]) * 9 / 16)))
	var objects: Array = shot.get("props", []) + shot.get("actors", [])
	objects.sort_custom(func(a, b): return float(a.get("z", a.get("y", 0))) < float(b.get("z", b.get("y", 0))))
	for actor in objects:
		if actor.get("hidden", false) or time < float(actor.get("appear", 0)): continue
		var state = _state(actor, time)
		var pos: Vector2 = (state.pos - origin) * zoom
		var k = float(data.meta.k.get(shot.bg, 1)) * float(actor.get("sc", 1)) * zoom
		var alpha = float(actor.get("op", 1)) * minf(1, time / maxf(1, float(actor.get("fadeIn", 1))))
		var tint = Color(1, 1, 1, alpha)
		var flip: bool = actor.get("f2", actor.get("f", false)) if actor.has("to") and state.arrived else actor.get("f", false)
		if actor.has("shape"):
			_draw_shape(actor, pos, k, time)
			continue
		var tex: Texture2D
		var region: Rect2
		if actor.has("p"):
			tex = _texture("prop-" + str(actor.p) + ".png")
			if not tex: continue
			region = Rect2(Vector2.ZERO, tex.get_size())
		else:
			var meta: Dictionary = data.meta.spr.get(actor.get("s", ""), {})
			if meta.is_empty(): continue
			tex = _texture("spr-" + str(actor.s) + ".webp")
			if not tex: continue
			var animation: String = actor.get("a2", actor.get("a", "idle")) if actor.has("to") and state.arrived else actor.get("a", "idle")
			var anim: Dictionary = meta.anims.get(animation, meta.anims.values()[0])
			var defaults = {"idle":5, "run":12, "walk":9, "win":6, "hit":7, "jump":6, "shoot":10, "throw":7, "pop":8, "crouch":6}
			var animation_time = time - float(actor.get("adl", 0))
			if actor.has("to") and state.arrived and actor.has("a2"):
				animation_time = time - float(actor.get("dl", 0)) - float(actor.get("d", 1200))
			var frame = int(maxf(0, animation_time) / 1000 * float(actor.get("fps", defaults.get(animation, 8))))
			frame = mini(frame, int(anim.frames) - 1) if actor.get("once", false) else frame % int(anim.frames)
			var held = actor.get("h2", actor.get("hold")) if actor.has("to") and state.arrived else actor.get("hold")
			if held != null: frame = mini(int(anim.frames) - 1, int(held))
			region = Rect2(frame * float(meta.w), float(anim.row) * float(meta.h), meta.w, meta.h)
			if meta.get("faceLeft", false): flip = not flip
		var dimensions = region.size * k
		var angle = float(actor.get("rot", 0)) + time / 1000 * float(actor.get("spin", 0))
		draw_set_transform(pos - Vector2(0, dimensions.y / 2), angle, Vector2(-1 if flip else 1, 1))
		draw_texture_rect_region(tex, Rect2(-dimensions / 2, dimensions), region, tint)
		draw_set_transform(Vector2.ZERO)
		var carries = actor.get("carry", [])
		if carries is Dictionary: carries = [carries]
		for carry in carries:
			var prop = _texture("prop-" + str(carry.p) + ".png")
			if not prop: continue
			var size = prop.get_size() * k * float(carry.get("sc", 1))
			var cp = pos + Vector2(float(carry.get("dx", 0)) * (-1 if actor.get("f", false) else 1), -float(carry.get("dy", 0))) * k
			draw_texture_rect(prop, Rect2(cp - Vector2(size.x / 2, 0 if carry.get("hang", false) else size.y / 2), size), false)
	if shot.has("tint"): draw_rect(Rect2(0, 0, 960, 540), _css_color(str(shot.tint)))
	if not heading.text.is_empty(): draw_rect(Rect2(140, 140, 680, 220), Color(0.04, 0.04, 0.08, 0.85))
	if not insert_label.text.is_empty() and insert_label.visible: draw_rect(Rect2(190, 48, 580, 325), Color(0.04, 0.04, 0.08, 0.95))
	if not dialogue.text.is_empty(): draw_rect(Rect2(12, 380, 936, 122), Color(0.04, 0.04, 0.08, 0.95))

func _draw_shape(actor: Dictionary, pos: Vector2, k: float, time: float) -> void:
	# Original bin silhouette geometry, including hinge animation and eyes.
	if actor.shape != "bin": return
	draw_set_transform(pos, 0, Vector2(k, k))
	var color = Color("06050b")
	draw_colored_polygon(PackedVector2Array([Vector2(-96,-244), Vector2(96,-244), Vector2(84,-40), Vector2(64,-22), Vector2(-64,-22), Vector2(-84,-40)]), color)
	draw_circle(Vector2(-62,-18), 20, color)
	draw_circle(Vector2(62,-18), 20, color)
	draw_rect(Rect2(-104,-250,208,14), Color("86dc92"))
	draw_set_transform(pos + Vector2(-108,-252) * k, -maxf(0, sin(time / 700)) * float(actor.get("lid", 0)), Vector2(k,k))
	draw_rect(Rect2(0,-14,218,16), color)
	draw_set_transform(pos, 0, Vector2(k,k))
	for x in [-38,38]: draw_rect(Rect2(x-8,-200,16,8), Color("ffeb99"))
	draw_set_transform(Vector2.ZERO)

func _css_color(value: String) -> Color:
	if value.begins_with("rgba("):
		var parts = value.trim_prefix("rgba(").trim_suffix(")").split(",")
		if parts.size() == 4:
			return Color(float(parts[0])/255, float(parts[1])/255, float(parts[2])/255, float(parts[3]))
	return Color.from_string(value, Color.TRANSPARENT)
