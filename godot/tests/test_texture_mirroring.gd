extends SceneTree
## Run headless for CanvasItem argument regressions, or without --headless for
## actual framebuffer checks. Optional user arg is the PNG destination.
## The reference uses positive destination bounds and Godot's in-place mirror,
## not Canvas 2D's translate(right_edge); scale(-1, 1) coordinate convention.
const Rooftop = preload("res://src/rooftop_renderer.gd")
const Street = preload("res://src/street_renderer.gd")
const Bus = preload("res://src/bus_renderer.gd")
const Supermarket = preload("res://src/supermarket_renderer.gd")
const Festival = preload("res://src/festival_renderer.gd")
const Tout = preload("res://src/festival_tout_renderer.gd")
const BACK := Color("101020")
const OFFSET := 384.0

class Spy extends RefCounted:
	var images: Dictionary = {}
	var draws: Array = []
	func draw_texture_rect_region(texture, rect, source, colour):
		draws.append({"texture": texture, "rect": rect, "source": source, "colour": colour})

class Canvas extends Node2D:
	var images: Dictionary = {}
	var cases: Array = []
	var font: Font = ThemeDB.fallback_font
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 720), BACK)
		draw_string(font, Vector2(20, 30), "Native texture mirroring: production vs fixed-position reference", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2(224, 64), "Production: normal / mirror / normal / crop", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(font, Vector2(608, 64), "Reference", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		for entry in cases:
			draw_string(font, Vector2(20, entry.y + 22), entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			entry.renderer.draw_commands(self, entry.commands)
			for i in entry.commands.size():
				var command: Dictionary = entry.commands[i]
				var call: Dictionary = entry.draws[i]
				var destination: Rect2 = command.rect
				destination.position.x += OFFSET
				if command.flip_h: destination.size.x = -destination.size.x
				draw_texture_rect_region(call.texture, destination, call.source, call.colour)
		# Independent engine contract: do not derive either from production.
		draw_string(font, Vector2(20, 634), "Raw Godot: x=224, width=-64", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_texture_rect_region(images.atlas, Rect2(224, 650, -64, 32), Rect2(8, 0, 8, 4))
		draw_string(font, Vector2(320, 670), "Paints [224,288), mirrored. It does not paint [160,224).", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")

func make_atlas() -> ImageTexture:
	var pixels := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	var colours := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color("ff8000"), Color.WHITE]
	for y in 4:
		for x in 16: pixels.set_pixel(x, y, colours[x / 2])
	return ImageTexture.create_from_image(pixels)

func make_command(kind: String, texture: Texture2D, rectangle: Rect2, flip: bool, options: Dictionary) -> Dictionary:
	var command := {"type": kind, "key": "atlas", "texture": texture, "rect": rectangle, "source": Rect2(8, 0, 8, 4),
		"flip_h": flip, "alpha": 1.0, "smooth": false, "big": false, "flash": false, "filter": "", "tag": "mirror_fixture"}
	command.merge(options, true)
	return command

func run() -> void:
	var texture := make_atlas()
	var definitions := [
		["Rooftop tile", Rooftop.new(), "texture", {}],
		["Street decoration", Street.new(), "texture", {}],
		["Bus / scooter", Bus.new(), "texture", {}],
		["Supermarket tile", Supermarket.new(), "texture", {}],
		["Supermarket bot", Supermarket.new(), "bot_texture", {}],
		["Security + flash", Supermarket.new(), "bot_texture", {"big": true, "flash": true}],
		["Festival sprite", Festival.new(), "festival_texture", {}],
		["Festival tint + flash", Festival.new(), "festival_texture", {"filter": "mid_prop", "flash": true}],
		["Tout sprite", Tout.new(), "tout_texture", {}],
		["Tout flash", Tout.new(), "tout_texture", {"flash": true}]]
	var cases: Array = []
	for index in definitions.size():
		var definition: Array = definitions[index]
		var y := 88.0 + index * 52
		var commands: Array = []
		for tile in 3:
			commands.append(make_command(definition[2], texture, Rect2(224 + tile * 64, y, 64, 32), tile == 1, definition[3]))
		var clipped := make_command(definition[2], texture, Rect2(456, y, 64, 32), true, definition[3])
		var region := Rooftop.clipped_region(clipped.rect, clipped.source, Rect2(464, y, 24, 32), true)
		clipped.unclipped_rect = clipped.rect
		clipped.rect = region.rect
		clipped.source = region.source
		commands.append(clipped)
		var before := var_to_str(commands)
		var spy := Spy.new()
		spy.images.atlas = texture
		definition[1].draw_commands(spy, commands)
		check(spy.draws.size() == 4, definition[0] + " draws every tile and cropped sprite")
		for tile in mini(4, spy.draws.size()):
			var command: Dictionary = commands[tile]
			var call: Dictionary = spy.draws[tile]
			check(call.rect.position == command.rect.position, definition[0] + " retains source left/top for tile %d" % tile)
			check(call.rect.size == command.rect.size * Vector2(-1 if command.flip_h else 1, 1), definition[0] + " only negates destination width %d" % tile)
			check(call.colour == Color.WHITE, definition[0] + " retains opacity %d" % tile)
		check(spy.draws[0].rect.position.x + absf(spy.draws[0].rect.size.x) == spy.draws[1].rect.position.x and spy.draws[1].rect.position.x + absf(spy.draws[1].rect.size.x) == spy.draws[2].rect.position.x, definition[0] + " adjacent normal/mirror/normal spans have no gaps or overlap")
		check(region.source == Rect2(12, 0, 3, 4), definition[0] + " mirrored asymmetric clip selects correct atlas pixels")
		check(var_to_str(commands) == before, definition[0] + " command snapshots remain unchanged")
		cases.append({"label": definition[0], "renderer": definition[1], "commands": commands, "draws": spy.draws, "y": y})
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 720)
		root.content_scale_size = Vector2i(960, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var canvas := Canvas.new()
		canvas.images.atlas = texture
		canvas.cases = cases
		root.add_child(canvas)
		await process_frame
		await RenderingServer.frame_post_draw
		var actual := root.get_texture().get_image()
		check(actual.get_size() == Vector2i(960, 720), "real framebuffer dimensions")
		for entry in cases:
			var difference := 0
			for y in range(int(entry.y), int(entry.y) + 32):
				for x in range(220, 508):
					if actual.get_pixel(x, y) != actual.get_pixel(x + int(OFFSET), y): difference += 1
			check(difference == 0, "%s actual framebuffer matches in-place reference (%d differing pixels)" % [entry.label, difference])
		check(actual.get_pixel(200, 660).is_equal_approx(BACK), "Godot negative width does not move pixels left of destination x")
		check(actual.get_pixel(232, 660).is_equal_approx(Color.WHITE), "Godot negative width starts with reversed right edge at original x")
		check(actual.get_pixel(280, 660).is_equal_approx(Color.CYAN), "Godot negative width ends with source left edge at x+abs(width)")
		var args := OS.get_cmdline_user_args()
		if not args.is_empty():
			DirAccess.make_dir_recursive_absolute(args[0].get_base_dir())
			check(actual.save_png(args[0]) == OK, "framebuffer PNG saved")
		canvas.queue_free()
		await process_frame
	else:
		print("Framebuffer checks skipped: headless driver. Run this suite without --headless for actual pixel proof.")
	for entry in cases:
		if entry.renderer.has_method("clear_cache"): entry.renderer.clear_cache()
	print("Texture mirroring: %d checks, %d failures. Backend: %s." % [checks, failures.size(), DisplayServer.get_name()])
	quit(0 if failures.is_empty() else 1)
