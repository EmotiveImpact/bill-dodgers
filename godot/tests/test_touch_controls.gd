extends SceneTree
const Controls = preload("res://src/touch_controls.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func event_touch(position:Vector2,pressed:bool,index:int)->void:
	var e:=InputEventScreenTouch.new();e.position=root.get_screen_transform()*position;e.pressed=pressed;e.index=index
	Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func event_drag(position:Vector2,index:int)->void:
	var e:=InputEventScreenDrag.new();e.position=root.get_screen_transform()*position;e.index=index
	Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func event_mouse(position:Vector2,pressed:bool)->void:
	var e:=InputEventMouseButton.new();e.position=root.get_screen_transform()*position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func event_motion(position:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=root.get_screen_transform()*position;e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func run()->void:
	for viewport in [Vector2(960,540),Vector2(1280,720),Vector2(1920,1080)]:
		for safe in [Vector2(18,14),Vector2(44,24)]:
			var layout:=Controls.layout(viewport,safe,true);var pad:Rect2=layout.pad;var buttons:Dictionary=layout.buttons
			check(pad.position.x>=safe.x and pad.end.y<=viewport.y-safe.y,"pad clear of notch/home margins")
			check(Controls.direction_at(pad,pad.get_center()).is_empty(),"neutral thumb center")
			for action in Controls.DIRECTIONS:
				check(Controls.direction_at(pad,buttons[action].get_center())==action,"cardinal %s"%action)
				check(buttons[action].size.x>=60 and buttons[action].size.y>=60,"large thumb target %s"%action)
			for pair in [[Vector2(0.1,0.1),"left+aim"],[Vector2(0.9,0.1),"right+aim"],[Vector2(0.1,0.9),"left+down"],[Vector2(0.9,0.9),"right+down"]]:
				check(Controls.direction_at(pad,pad.position+pad.size*pair[0])==pair[1],"diagonal %s"%pair[1])
			for action in ["jump","shoot","special","dash"]:
				check(not buttons[action].intersects(pad),"independent right-side %s"%action)
				check(buttons[action].size.x>=60 and buttons[action].size.y>=60,"action tap size %s"%action)
			check(Controls.direction_at(pad,pad.end+Vector2.ONE).is_empty(),"leaving pad releases directions")
	check(Controls.held({1:"left+aim",2:"shoot"},"left") and Controls.held({1:"left+aim",2:"shoot"},"aim"),"one thumb diagonal two actions")
	check(not Controls.held({1:"right+down"},"left"),"opposite direction never sticks")
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame
	Support.silence(game);game.set_physics_process(false);game.load_level("1-1",false)
	check(game.touch_control_style == "joystick", "Requested virtual joystick is the production default")
	game.touch_control_style="classic" # Retain explicit alternative regression coverage.
	var center:Vector2=game.dpad_rect.get_center();var left:Vector2=game.buttons.left.get_center();var right:Vector2=game.buttons.right.get_center()
	await event_touch(left,true,7)
	check(game._held("left"),"actual touch begins left")
	await event_drag(center,7)
	check(not game._held("left") and game.gameplay_contacts.has(7),"actual thumb center neutral without losing contact")
	await event_drag(right,7)
	check(game._held("right") and not game._held("left"),"actual drag crosses center to opposite arm")
	await event_drag(game.dpad_rect.position+Vector2(180,12),7)
	check(game._held("right") and game._held("aim") and not game._held("jump"),"actual diagonal move/aim preserves separate jump")
	await event_touch(game.buttons.shoot.get_center(),true,8)
	await event_touch(game.buttons.jump.get_center(),true,9)
	check(game._held("right") and game._held("aim") and game._held("shoot") and game._held("jump"),"three contacts allow steering/aiming/shooting/jumping")
	await event_touch(game.buttons.shoot.get_center(),false,8)
	check(game._held("right") and not game._held("shoot") and game._held("jump"),"releasing one action does not release others")
	game._pause();check(game.touches.is_empty() and game.gameplay_contacts.is_empty(),"pause releases neutral and active contacts")
	game._resume();await event_touch(right,false,7);await event_touch(game.buttons.jump.get_center(),false,9)
	await event_mouse(left,true);await event_motion(center)
	check(not game._held("left") and game.gameplay_contacts.has(-1),"mouse neutral center retains drag ownership")
	await event_motion(right)
	check(game._held("right"),"mouse leaves neutral without another click")
	await event_mouse(right,false)
	check(game.touches.is_empty() and game.gameplay_contacts.is_empty(),"mouse lift clears all ownership")
	await event_touch(center,true,10);await event_drag(left,10)
	check(game._held("left"),"touch starting at neutral can steer")
	game._resize()
	check(game.touches.is_empty() and game.gameplay_contacts.is_empty(),"rotation/resize cancels all contacts")
	game.touch_control_style="joystick"
	check(Controls.joystick_direction(game.dpad_rect,center+Vector2(12,8)).is_empty(),"joystick radial dead zone")
	for sample in [[Vector2(70,0),"right"],[Vector2(-70,0),"left"],[Vector2(0,-70),"aim"],[Vector2(0,70),"down"],[Vector2(60,-45),"right+aim"],[Vector2(-60,45),"left+down"]]:
		check(Controls.joystick_direction(game.dpad_rect,center+sample[0])==sample[1],"joystick sector %s"%sample[1])
	await event_touch(center,true,21);await event_drag(center+Vector2(60,-40),21)
	check(game._held("right") and game._held("aim") and not game._held("jump"),"joystick one-thumb diagonal aim")
	await event_touch(center+Vector2(-60,0),true,25)
	check(not game._held("left") and game.joystick_contacts.size()==1,"second thumb cannot steal steering")
	await event_touch(center,false,25)
	check(game._held("right") and game._held("aim"),"second thumb lift leaves original steering")
	check(Controls.joystick_knob(game.dpad_rect,game.joystick_contacts).distance_to(center)<=game.dpad_rect.size.x*.29+.01,"joystick knob limited to travel zone")
	await event_touch(game.buttons.shoot.get_center(),true,22);await event_touch(game.buttons.jump.get_center(),true,23)
	check(game._held("right") and game._held("aim") and game._held("shoot") and game._held("jump"),"joystick with simultaneous shoot and jump")
	await event_drag(center+Vector2(300,-100),21)
	check(game._held("right") and not game._held("aim") and game.joystick_contacts.has(21),"joystick preserves captured thumb beyond base")
	await event_touch(game.buttons.shoot.get_center(),false,22)
	check(game._held("right") and game._held("jump") and not game._held("shoot"),"joystick independent action release")
	await event_drag(game.hud_controls[0].get_global_rect().get_center(),21)
	check(not game._held("left") and not game._held("right") and not game._held("aim") and not game._held("down") and game.joystick_contacts.has(21), "Captured joystick suspends all steering over native HUD")
	await event_drag(center+Vector2(60,0),21)
	check(game._held("right"), "Leaving HUD resumes same owned thumb without a fresh press")
	await event_drag(center,21)
	check(not game._held("right") and game.joystick_contacts.has(21),"joystick return to neutral stops movement")
	await event_drag(center+Vector2(-60,40),21)
	check(game._held("left") and game._held("down"),"joystick reverses and ducks without lift")
	await event_touch(center,false,21)
	check(game.joystick_contacts.is_empty() and not game._held("left") and Controls.joystick_knob(game.dpad_rect,game.joystick_contacts)==center,"joystick lift resets knob and directions")
	await event_touch(center,true,24);game._pause()
	check(game.joystick_contacts.is_empty() and game.gameplay_contacts.is_empty(),"joystick focus/pause clears captured contacts")
	game._resume()
	check(game.touch_control_style == "joystick", "Pause/resume retains requested joystick")
	game._show_menu();game.load_level("2-1",false)
	check(game.touch_control_style == "joystick" and game.joystick_contacts.is_empty(), "Next level retains joystick with neutral fresh contacts")
	game.queue_redraw();await process_frame;await process_frame
	game.queue_free();await process_frame
	if failures.is_empty():print("Touch control foundation: %d checks passed."%checks);quit(0)
	else:printerr("Touch controls failed: %d/%d"%[failures.size(),checks]);quit(1)
