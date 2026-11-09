extends SceneTree
## Production main._sprite versus an independent transform-based Canvas 2D
## reference. Headless execution checks resources/callbacks only. The real GL
## run compares every pixel of all six housemates facing both ways.
const BACK := Color("101020")
class SpriteCanvas extends "res://src/main.gd":
	var reference := false
	var draw_count := 0
	func _ready() -> void: pass
	func _notification(_what: int) -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _input(_event: InputEvent) -> void: pass
	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(0, 0, 960, 720), Color("101020"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 32), "Six housemates: left / right, same feet and asymmetric 45% anchor", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(ThemeDB.fallback_font, Vector2(24, 56), "Production main._sprite" if not reference else "Independent transform reference", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		for index in CHARACTERS.size():
			var key: String = CHARACTERS[index]
			var data: Dictionary = sheet_meta[key]
			var start := Vector2(320 * (index % 3), 76 + 308 * int(index / 3))
			draw_string(ThemeDB.fallback_font, start + Vector2(20, 22), NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
			var height := minf(float(data.h), 180)
			var width := height * float(data.w) / float(data.h)
			for direction in [-1, 1]:
				var feet := start + Vector2(84 if direction == -1 else 232, 242)
				var tint := Color("43aaa4") if direction == -1 else Color("f4c542")
				# Expected frame bounds are calculated without main's rectangle.
				var left := feet.x - width * 0.55 if direction == -1 else feet.x - width * 0.45
				var top := feet.y - height + 3 * height / float(data.h)
				draw_rect(Rect2(left - 1, top - 1, width + 2, height + 2), tint, false)
				if reference:
					# Original Canvas: translate(feet); scale(face, 1);
					# drawImage(frame, -anchor, top). Native continuous scaling is
					# intentionally retained; this test targets the width shift.
					draw_set_transform(feet, 0, Vector2(direction, 1))
					draw_texture_rect_region(sheets[key], Rect2(-width * 0.45, -height + 3 * height / float(data.h), width, height), Rect2(data.w, float(data.anims.shoot.row) * float(data.h), data.w, data.h))
					draw_set_transform(Vector2.ZERO)
				else: _sprite(key, "shoot", feet, direction, height, 1)
				draw_line(feet + Vector2(0, -10), feet + Vector2(0, 20), tint, 1)
				draw_line(feet + Vector2(-12, 0), feet + Vector2(12, 0), tint, 1)
				draw_string(ThemeDB.fallback_font, feet + Vector2(-20, 40), "Left" if direction == -1 else "Right", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(960, 720)
	root.content_scale_size = Vector2i(960, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var canvas := SpriteCanvas.new()
	for key in canvas.CHARACTERS:
		canvas.sheets[key] = load("res://assets/sprites/%s-sheet.png" % key)
		canvas.sheet_meta[key] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s-sheet.json" % key))
		check(canvas.sheets[key] != null and not canvas.sheet_meta[key].is_empty(), key + " original sheet and metadata")
	root.add_child(canvas)
	await process_frame
	await process_frame
	check(canvas.draw_count > 0, "production main._sprite CanvasItem callback ran for six left/right pairs")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var production := root.get_texture().get_image()
		canvas.reference = true
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var reference := root.get_texture().get_image()
		for index in canvas.CHARACTERS.size():
			var x0 := 320 * (index % 3)
			var y0 := 76 + 308 * int(index / 3)
			var changed_left := 0
			var changed_right := 0
			for y in range(y0 + 30, y0 + 266):
				for x in range(x0, x0 + 320):
					if production.get_pixel(x, y) != reference.get_pixel(x, y):
						if x - x0 < 160: changed_left += 1
						else: changed_right += 1
			check(changed_left == 0, "%s mirrored pixels match original transform anchor (%d differ)" % [canvas.CHARACTERS[index], changed_left])
			check(changed_right == 0, "%s right-facing pixels unchanged (%d differ)" % [canvas.CHARACTERS[index], changed_right])
		var args := OS.get_cmdline_user_args()
		if not args.is_empty():
			DirAccess.make_dir_recursive_absolute(args[0])
			check(production.save_png(args[0].path_join("native-sprite-mirroring.png")) == OK, "production screenshot saved")
			check(reference.save_png(args[0].path_join("native-sprite-reference.png")) == OK, "transform reference screenshot saved")
	else: print("Framebuffer checks skipped: headless backend cannot prove sprite anchor pixels.")
	canvas.queue_free()
	await process_frame
	print("Main sprite mirroring: %d checks, %d failures. Backend: %s." % [checks, failures.size(), DisplayServer.get_name()])
	quit(0 if failures.is_empty() else 1)
