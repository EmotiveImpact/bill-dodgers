extends SceneTree
## Explicit real-main integration fixtures for the shared party phase;
## this is not reachable co-op acceptance, a complete route or device test.
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", label)
func run() -> void:
	game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_physics_process(false); preload("res://tests/test_support.gd").silence(game)
	game.character = "jp"
	game.save = {"schema":1,"receipts":{},"skills":[],"seen":{}}
	check(game.configure_party("p2", "maya"), "Explicit valid pair accepted at menu")
	game.load_level("1-1")
	var session = game.party_session
	var p1 = session.runtime.actors[0]; var p2 = session.runtime.actors[1]
	check(session.active and session.runtime.actors.size() == 2, "Real two-actor session started")
	check(p1.player - p2.player == Vector2(80,0), "Source80px spawn offset floor-resolved")
	check(game.combat.participant_count == 2, "Real combat scales party, not decorative actor")
	check(game.combat.waves[0].group.size() == game.level.waves[0][1].size()+1, "Exact party wave addition loaded")
	check(not game.configure_party("solo"), "Mode cannot mutate during play")
	var before1: Vector2 = p1.player; var before2: Vector2 = p2.player
	session.step(game,.016,{"right":true,"shoot":true},{"left":true,"shoot":true})
	check(is_equal_approx(game.elapsed,.016), "World clock advances once, not once per actor")
	check(absf(p1.player.x-before1.x-270*.016)<.001, "P1 ordinary right movement")
	check(absf(p2.player.x-before2.x+270*.016)<.001, "P2 independent left movement")
	check(game.player == p1.player and game.character == "jp", "Facade restores P1 after shared pass")
	check(game.bullets.filter(func(b): return not b.enemy and b.owner_slot==0).size()==1, "P1 shot owns slot0")
	check(game.bullets.filter(func(b): return not b.enemy and b.owner_slot==1).size()==1, "P2 shot owns slot1")
	check(p1.abilities != p2.abilities and p1.movement_skills != p2.movement_skills, "Abilities and movement state are independent")
	check(absf(p1.abilities._time-.016)<.00001 and absf(p2.abilities._time-.016)<.00001, "Each ability clock once")
	check(game.combat.waves[0].t == 0 and not game.combat.waves[0].started, "Untriggered source wave does not advance")
	# Poll the actual engine keyboard path, with both release guards rearmed.
	game._physics_process(.016)
	var old_p1: Vector2 = p1.player; var old_p2: Vector2 = p2.player
	var key := InputEventKey.new(); key.physical_keycode=KEY_D; key.keycode=KEY_D; key.pressed=true
	Input.parse_input_event(key); Input.flush_buffered_events()
	game._physics_process(.016)
	check(p1.player==old_p1 and p2.player.x>old_p2.x, "Real D event moves P2 only through native polling")
	key=key.duplicate(); key.pressed=false
	Input.parse_input_event(key); Input.flush_buffered_events()
	game._physics_process(.016)
	check(not session.input.read(1,"p2").right, "Native P2 release clears routed action")
	# A proxy-level hit must route to P2, not active P1. Maya's first hit lands.
	session.bridge.begin_shared(0)
	game.hurt_combat_participant(session.bridge.record(1), p2.player.x+30)
	session.bridge.end_shared(0)
	check(p1.hearts==3 and p2.hearts==2, "P2-specific real damage leaves P1 alone")
	check(game.hearts==3 and game.character=="jp", "Damage callback restores active facade")
	p1.hearts=1;p1.invincible=0;p1.apply_native(game)
	var help_before:int=game.visual_feedback.floats.filter(func(f):return f.text=="Help!").size()
	session.bridge.begin_shared(0);game.hurt_combat_participant(session.bridge.record(0),p1.player.x+30);session.bridge.end_shared(0)
	check(p1.down and game.status=="Jean Phil is down. Stand next to them to help them up.","Lethal actor hit presents source rescue instructions once")
	check(game.visual_feedback.floats.filter(func(f):return f.text=="Help!").size()==help_before+1,"Lethal actor hit creates one source Help float")
	session.bridge.begin_shared(0);game.hurt_combat_participant(session.bridge.record(0),p1.player.x+30);session.bridge.end_shared(0)
	check(game.visual_feedback.floats.filter(func(f):return f.text=="Help!").size()==help_before+1,"Repeated hit on downed actor cannot repeat rescue feedback")
	p1.continue_in_place();p1.apply_native(game)

	# Explicit down/revive fixture uses only ordinary idle ticks after setup.
	p2.hearts=0; p2.mark_down(); p2.player=p1.player-Vector2(30,0)
	for i in 90: session.step(game,1.0/60,{}, {})
	check(not p2.down and p2.hearts==2 and game.mode=="play", "Nearby mate revives through real simulation")
	check(p2.player_animation=="win" and p2.hurt_lock>0, "Revive celebration survives next actor update")
	check(p2.invincible>2.0, "Revive protection belongs to revived actor")
	p1.hearts=0; p1.mark_down(); p2.hearts=0; p2.mark_down(); p1.apply_native(game)
	session.step(game,.016,{}, {})
	check(game.mode=="over", "All-down after world phase opens Continue")
	var world_time: float = game.elapsed; var wave_time: float = game.combat.waves[0].t
	game._continue_level()
	check(p1.hearts==3 and p2.hearts==3 and game.mode=="play", "Continue revives both in place")
	check(game.elapsed==world_time and game.combat.waves[0].t==wave_time, "Continue never resets world")
	game._show_menu(); check(game.configure_party("solo"), "Solo mode can be restored at menu")
	game.load_level("1-1")
	check(not session.active and game.combat.participant_count==1, "Solo reset preserves one-player wave policy")
	var solo: Vector2 = game.player; game.step(.016,{"right":true})
	check(absf(game.player.x-solo.x-270*.016)<.001 and is_equal_approx(game.elapsed,.016), "Solo helper retains original motion/clock")
	game._show_menu(); game.configure_party("cpu", "maya"); game.load_level("1-1")
	var lead = session.runtime.actors[0]; var mate = session.runtime.actors[1]
	lead.player=Vector2(300,482); mate.player=Vector2(164,482); lead.apply_native(game)
	session.step(game,.016,{"right":true})
	check(is_equal_approx(mate.player.x,164), "CPU uses pre-motion P1 at exact26px intent boundary")
	check(lead.player.x>300, "P1 moves after CPU intent was gathered")
	game._show_menu();game.configure_party("p2","maya");game.load_level("1-1")
	lead=session.runtime.actors[0];mate=session.runtime.actors[1]
	lead.player=Vector2(300,482);mate.player=Vector2(430,482);lead.mark_down();lead.apply_native(game)
	game.score=5;game.coins=[{"p":Vector2(300,400)},{"p":Vector2(430,400)},{"p":Vector2(600,400)}]
	session.bridge.begin_shared(0);game._complete_level();session.bridge.end_shared(0)
	check(lead.coins==0 and mate.coins==3,"Clear sweep attributes to living mate before revival")
	check(game.score==8 and game.save.kitty==8,"Clear sweep increments shared kitty only once")
	check(lead.hearts==1 and not lead.down,"Clear rescue follows personal attribution")
	game._complete_level();check(mate.coins==3 and game.save.kitty==8,"Repeated clear cannot double sweep")
	game._show_menu(); game.configure_party("p2", "maya"); game.load_level("2-1")
	game._physics_process(.1)
	check(is_equal_approx(game.elapsed,.034) and is_equal_approx(session.runtime.actors[0].abilities._time,.034) and is_equal_approx(session.runtime.actors[1].abilities._time,.034),"Later-world native frame cap matches solo for both actors and shared clock")
	game._show_menu(); game.configure_party("cpu", "ama"); game.load_level("6-1")
	check(session.active and session.INTEGRATING_LEVELS.size()==42, "All six adapted worlds can start the hidden party phase")
	game.level_id="future-preview";session.start(game)
	check(not session.active, "Unknown future content cannot silently enable partial pair")
	game.mode="menu"
	game.queue_free(); await process_frame
	print("Party actual host: %d checks, %d failures (bounded1-1 fixtures, not complete co-op)" % [checks,failures])
	quit(0 if failures==0 else 1)
