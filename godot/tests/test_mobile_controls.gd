extends SceneTree
## Low-memory real Control event tests plus deterministic original-vector plans.
## Actual main lifecycle and rendered evidence have a separate integration suite.
const Menu = preload("res://src/mobile_game_menu.gd")
const Actions = preload("res://src/action_controls_renderer.gd")
const Controls = preload("res://src/touch_controls.gd")
const Abilities = preload("res://src/abilities.gd")
class Host extends RefCounted:
	var buttons: Dictionary
	var touches := {}
	var character := "jp"
	var abilities = Abilities.new()
class Drawing extends Node2D:
	var host
	var submitted := 0
	func _draw() -> void:
		Actions.draw(self, host)
		submitted += 1
var checks := 0
var failures: Array[String] = []
var events: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(command): return command.tag == tag)
func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * position
	event.index = 10
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func tap(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	await touch(point, true)
	await touch(point, false)
func run() -> void:
	for viewport in [Vector2(960,540),Vector2(1170,540),Vector2(844,390),Vector2(568,320),Vector2(540,960)]:
		root.size = Vector2i(viewport)
		root.content_scale_size = Vector2i(viewport)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for safe in [Vector2(18,14),Vector2(44,24)]:
			var menu := Menu.new()
			root.add_child(menu)
			menu.configure(ThemeDB.fallback_font, true, false)
			menu.action_requested.connect(func(action: String): events.append(action))
			menu.relayout(viewport, safe)
			await process_frame
			var boxes := Menu.layout(viewport, safe)
			check(boxes.safe.encloses(menu.launcher.get_global_rect()), "launcher respects safe bounds %s/%s" % [viewport,safe])
			check(menu.launcher.position.y > 69, "launcher never covers either player's authored header")
			check(boxes.safe.encloses(menu.panel.get_global_rect()), "pause panel respects safe bounds %s/%s" % [viewport,safe])
			events.clear()
			await tap(menu.launcher)
			check(events == ["open"], "real Menu tap signals exactly once")
			menu.open("play", false)
			await process_frame
			check(menu.opened and not menu.launcher.visible and menu.shade.visible, "open menu hides launcher and blocks world")
			check(menu.shade.mouse_filter == Control.MOUSE_FILTER_STOP, "pause shade blocks accidental world input")
			var buttons := [menu.resume_button,menu.story_button,menu.sound_button,menu.map_button]
			for i in buttons.size():
				var button: Button = buttons[i]
				check(button.size.x >= 44 and button.size.y >= 44, "every mobile action is touch sized")
				check(menu.panel.get_global_rect().encloses(button.get_global_rect()), "every mobile action fits panel")
				for j in range(i): check(not button.get_global_rect().intersects(buttons[j].get_global_rect()), "mobile actions do not overlap")
				events.clear()
				await tap(button)
				check(events == [["resume","story","sound","map"][i]], "actual touch action %s" % button.name)
			events.clear()
			var sound_center: Vector2 = menu.sound_button.get_global_rect().get_center()
			await touch(sound_center, true)
			var drag := InputEventScreenDrag.new()
			drag.index = 10
			drag.position = root.get_screen_transform() * Vector2(4, 4)
			Input.parse_input_event(drag); Input.flush_buffered_events(); await process_frame
			await touch(Vector2(4,4), false)
			check(events.is_empty(), "dragging outside does not activate a menu action")
			await touch(sound_center, true)
			var cancel := InputEventScreenTouch.new()
			cancel.index = 10; cancel.pressed = false; cancel.canceled = true
			cancel.position = root.get_screen_transform() * sound_center
			Input.parse_input_event(cancel); Input.flush_buffered_events(); await process_frame
			check(events.is_empty() and menu._touch_buttons.is_empty(), "canceled contact never activates")
			await touch(sound_center, true)
			menu.relayout(viewport, safe)
			await touch(sound_center, false)
			check(events.is_empty() and menu._touch_buttons.is_empty(), "rotation cancels pending GUI activation")
			menu.set_sound_enabled(true)
			check(menu.sound_button.text == "Sound: On", "sound label reflects enabled state")
			menu.open("story", false)
			events.clear()
			await tap(menu.story_button)
			check(events.is_empty() and menu.story_button.disabled, "paused story cannot recursively replay")
			menu.close()
			check(not menu.opened and menu.launcher.visible and not menu.shade.visible, "close removes input shade")
			menu.queue_free()
			await process_frame
	# Production canvas scaled into smaller phone windows: retain rendered target
	# size, rather than claiming 48 logical units always mean 48 screen pixels.
	for window_size in [Vector2i(844,390),Vector2i(568,320)]:
		root.size = window_size; root.content_scale_size = Vector2i(960,540)
		await process_frame
		var menu := Menu.new(); root.add_child(menu)
		menu.configure(ThemeDB.fallback_font,true,false)
		menu.relayout(root.get_visible_rect().size,Vector2(44,24))
		menu.open("play",false)
		await process_frame
		var scale := root.get_screen_transform().get_scale()
		var gameplay := Controls.layout(root.get_visible_rect().size,Vector2(44,24),true)
		var actions := ["jump","shoot","special","dash"]
		for i in actions.size():
			var rect: Rect2 = gameplay.buttons[actions[i]]
			check(rect.size.x * scale.x >= 44 and rect.size.y * scale.y >= 44, "graphical action target remains at least44 screen pixels")
			check(not rect.intersects(gameplay.pad), "enlarged action does not cover joystick")
			for j in range(i): check(not rect.intersects(gameplay.buttons[actions[j]]), "enlarged graphical actions do not overlap")
		for button in [menu.launcher,menu.resume_button,menu.story_button,menu.sound_button,menu.map_button]:
			check(button.size.x * scale.x >= 44 and button.size.y * scale.y >= 44, "scaled phone target remains at least44 screen pixels")
		var bounds: Rect2 = Menu.layout(root.get_visible_rect().size,Vector2(44,24)).safe
		check(bounds.encloses(menu.panel.get_global_rect()), "scaled phone menu stays inside safe bounds")
		menu.queue_free(); await process_frame
	var host := Host.new()
	host.buttons = Controls.layout(Vector2(960,540), Vector2(18,14), true).buttons
	host.abilities.reset("jp")
	var snapshot := var_to_str(host.buttons)
	for who in Abilities.SPEC:
		host.character = who
		host.abilities.reset(who)
		for charge in [0.0,0.25,0.5,1.0]:
			host.abilities.meter = charge
			var commands := Actions.build_commands(host)
			var rings := tagged(commands,"special_charge")
			check(rings.is_empty() if charge == 0 else is_equal_approx(rings[0].end - rings[0].start, TAU * charge), "%s truthful circular charge %s" % [who,charge])
			check(tagged(commands,"jump_arrow").size() == 1 and tagged(commands,"shoot_crosshair").size() == 4, "original graphical jump and shoot")
			check(not commands.any(func(c): return c.type == "text"), "actions do not fall back to text blocks")
			check(tagged(commands,"special_ready_spark").size() == (4 if charge == 1 else 0), "ready sparkle only when power earned")
		host.abilities.meter = 0
		host.abilities.active = who
		host.abilities.duration = 4
		host.abilities.remaining = 1
		var active := tagged(Actions.build_commands(host),"special_active")
		check(active.size() == 1 and is_equal_approx(active[0].end - active[0].start, TAU * .25), "%s active ring counts remaining duration" % who)
	host.touches = {1:"jump",2:"shoot"}
	var pressed := Actions.build_commands(host)
	check(tagged(pressed,"jump_face")[0].colour.a > .9 and tagged(pressed,"shoot_face")[0].colour.a > .9,"independent simultaneous pressed visuals")
	check(snapshot == var_to_str(host.buttons), "visual changes never mutate authoritative input rectangles")
	host.buttons.erase("dash")
	check(tagged(Actions.build_commands(host),"dash_chevron").is_empty(), "unearned dash stays hidden")
	var drawing := Drawing.new()
	drawing.host = host
	root.add_child(drawing)
	drawing.queue_redraw()
	await process_frame
	await process_frame
	check(drawing.submitted > 0, "actual CanvasItem submits icon drawing")
	drawing.queue_free()
	await process_frame
	if failures.is_empty(): print("Mobile menu and graphical actions: %d checks passed." % checks); quit(0)
	else: printerr("Mobile controls failed: %d/%d" % [failures.size(),checks]); quit(1)
