extends SceneTree
## Actual desktop renderer, fresh save and ordinary gameplay input. Not phone QA.
const Support = preload("res://tests/test_support.gd")
var output := "user://captures/latest"
func _initialize() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 output = ProjectSettings.globalize_path(output)
 call_deferred("run")
func snap(game, file: String) -> void:
 game.queue_redraw(); game.player_hud.queue_redraw()
 await process_frame; await RenderingServer.frame_post_draw
 if root.get_texture().get_image().save_png(output.path_join(file)) != OK:
  printerr("Capture failed: ",file); quit(1)
func run() -> void:
 if DisplayServer.get_name() == "headless": printerr("Actual rendering backend required"); quit(1); return
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 DirAccess.make_dir_recursive_absolute(output)
 var game=load("res://src/main.gd").new();root.add_child(game);await process_frame;Support.silence(game);game.set_physics_process(false)
 game.save={"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0};game.character="jp";game.level_id=""
 game._show_campaign();await process_frame;game.campaign_map.set_process(false)
 game.campaign_map.at="1-1";game.campaign_map.walker=game.campaign_map.point("1-1");game.campaign_map.camera=game.campaign_map.walker
 game.campaign_map.show_card("1-1")
 await snap(game,"native-map-change-character.png")
 game.load_level("1-1",false);game.player_hud.notifications.reset()
 game.status="";game.status_label.text=""
 await snap(game,"native-joystick-default.png")
 for frame in 240:game.step(1.0/60.0,{"right":true,"shoot":true})
 var event:=InputEventScreenTouch.new();event.index=41;event.pressed=true;event.position=root.get_screen_transform()*(game.dpad_rect.get_center()+Vector2(60,0))
 Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 game.status="";game.status_label.text=""
 await snap(game,"native-joystick-active.png")
 print("Fresh default joystick/map captures written to ",output)
 game.queue_free();await process_frame;quit(0)
