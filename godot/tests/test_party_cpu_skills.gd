extends SceneTree
const Support=preload("res://tests/test_support.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run()->void:
 var game=load("res://src/main.gd").new();root.add_child(game);game.set_physics_process(false);Support.silence(game)
 for world in range(1,7):
  game._show_menu();game.character="jp";game.save={"schema":1,"receipts":{},"skills":["dash"]};game.configure_party("cpu","maya");game.load_level("%d-1"%world)
  var s=game.party_session;var mate=s.runtime.actors[1]
  s.bind(game,1);game.grounded=true;game.crouching=false;game.hurt_lock=0;game.shoot_time=.3;game.shoot_diagonal=true
  for power in ["","split","debit"]:
   game.power=power;game.bullets.clear();game._fire({"aim":true})
   check(game.bullets.size()==(3 if power=="split" else 1),"CPU stationary aim preserves source shot count %d/%s"%[world,power])
   check(game.bullets[0].v.is_equal_approx(Vector2(game.face*553.8,-553.8)) and game.bullets[0].owner_slot==1,"CPU stationary aim stays owned diagonal %d/%s"%[world,power])
   check(game.bullets[0].homing==(power=="debit"),"CPU debit retains homing %d/%s"%[world,power])
  game._update_player_animation(.016,{"aim":true},0)
  check(game.player_animation=="diag" and not game.aim_up and game.aim_time==0,"CPU never enters human-only up pose %d"%world)
  # Explicit ordinary input facade reproduces two quick direction presses.
  # The CPU flag, rather than lack of a dash key, must block automatic Dash.
  game.power="";game.power_time=0;game.hurt_lock=0;game.shoot_time=0;game.velocity=Vector2.ZERO
  for controls in [{"right":true},{},{"right":true},{"dash":true}]:
   game._actor_step(.016,controls)
   if world==4:game.holiday_dash_step()
  check(game.movement_skills.dash_remaining==0 and game.movement_skills.dash_cooldown<=0 and not "dash" in game.movement_skills.events,"CPU cannot activate earned Dash by double tap or button %d"%world)
  s.capture(game);s.bind(game,0);game.grounded=true;game.crouching=false;game.hurt_lock=0;game.power="debit";game.bullets.clear()
  game._fire({"aim":true})
  check(game.bullets.size()==2 and absf(game.bullets[0].v.x)<1 and game.bullets.all(func(b):return not b.homing and b.owner_slot==0),"Human stationary aim retains source upward debit pair %d"%world)
  game.movement_skills.begin_step(.016,{"dash":true},game)
  if world==4:game.holiday_dash_step()
  else:game.movement_skills.post_step(game,"","idle",game.actor_is_cpu())
  check(game.movement_skills.dash_cooldown>0,"Human earned Dash still works %d"%world)
 game.queue_free();await process_frame
 print("Party CPU skill/aim source guards: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
