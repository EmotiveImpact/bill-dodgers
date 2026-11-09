extends SceneTree
## Actual main.tscn host wiring. Explicit fixtures isolate boundary cases;
## suppressed waves, actor placements and HP edits are NOT full-run evidence.
const Base = preload("res://tests/test_festival_integration.gd")
const SaveStore = preload("res://src/save_store.gd")
const Campaign = preload("res://src/campaign_progression.gd")
const NativeLevels = preload("res://src/native_levels.gd")

class ProbeHost extends "res://src/main.gd":
	var save_calls := 0
	var draw_callbacks := 0
	var observed_events: Array = []
	var observed_drops: Array = []
	func _save_progress() -> void:
		save_calls += 1; super._save_progress()
	func festival_event(event: Dictionary) -> void:
		observed_events.append(event.duplicate(true)); super.festival_event(event)
	func add_coins(point: Vector2, count: int) -> void:
		observed_drops.append({"p": point, "count": count}); super.add_coins(point, count)
	func _draw() -> void:
		draw_callbacks += 1; super._draw()

class ProbeFinale extends "res://src/festival_finale.gd":
	var trace: Array = []
	var samples: Array = []
	func after_mini_trigger(dt: float, host, runtime) -> void:
		trace.append(["finale", host.mode]); super.after_mini_trigger(dt, host, runtime)
	func sync_visuals(host, runtime) -> void:
		trace.append(["visual", host.mode]); super.sync_visuals(host, runtime)
		if host.boss != null: samples.append({"x": host.boss.state.x, "sample": host.boss.state.visual_x, "t": runtime.level_time})

class ProbePainter extends "res://src/festival_tout_renderer.gd":
	var calls: Array = []
	var painted_moves: Array = []
	var hud_calls := 0
	func draw_sky(host, runtime = null) -> void: calls.append("sky"); super.draw_sky(host, runtime)
	func draw_level(host, runtime = null) -> void: calls.append("level"); super.draw_level(host, runtime)
	func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void: calls.append("finds"); super.draw_mid(host, runtime, pickups)
	func draw_boss(host, runtime = null) -> void: calls.append("boss"); super.draw_boss(host, runtime)
	func draw_enemy(host, enemy: Dictionary) -> bool: calls.append("bot"); return super.draw_enemy(host, enemy)
	func draw_jar(host, runtime = null) -> void: calls.append("jar"); super.draw_jar(host, runtime)
	func draw_player_back(host, player = null) -> void: calls.append("player_back"); super.draw_player_back(host, player)
	func draw_player_front(host, player = null) -> void: calls.append("player_front"); super.draw_player_front(host, player)
	func draw_bill(host, bullet: Dictionary) -> void: calls.append("bill"); super.draw_bill(host, bullet)
	func draw_front(host, runtime = null) -> void: calls.append("front"); super.draw_front(host, runtime)
	func draw_commands(host, commands: Array) -> void:
		for command in commands:
			if command.get("type") == "tout_texture": painted_moves.append(command.animation)
			if command.get("tag") == "festival_boss_health": hud_calls += 1
		super.draw_commands(host, commands)

var game
var checks := 0
var failures: Array[String] = []
var trace: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a-b) < 0.002
func fresh(who: String = "jp", skills: Array = []) -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": skills.duplicate(), "kitty": 13, "seen": {}, "cleared": {}}
	game.load_level("3-6")
	for wave in game.combat.waves: wave.at = INF
	game.step(0, {})
	game.audio.clear_log(); game.save_calls = 0; trace.clear()
	game.observed_events.clear(); game.observed_drops.clear()
func place(point: Vector2 = Vector2(3910,482), camera_x: float = 3660) -> void:
	game.player = point; game.camera = Vector2(camera_x,0); game.camera_speed = 0
	game.camera_lock = null; game.velocity = Vector2.ZERO; game.grounded = true
	game.on_platform = false; game.invincible = 999; game.hurt_lock = 0
	game.jump_held = false; game.drop_time = 0; game._last_floor = point.y
	game.world_three._standing_surface = {}
func mark_waves() -> void:
	for wave in game.combat.waves: wave.started = true; wave.done = true; wave.index = wave.group.size()
func arena(who: String = "jp", skills: Array = []) -> Dictionary:
	fresh(who, skills); mark_waves(); place(); game.step(0,{})
	var state: Dictionary = game.boss.state
	state.state = "walk"; state.x = 4165.0; state.next = 100.0
	state.called = [true,true]; state.dz = true
	game.camera_lock = 3662.0
	return state
func tick(seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.000000001:
		var dt := minf(seconds,0.01); game.step(dt,controls); seconds -= dt
func shot(point: Vector2, damage: int = 1, ghost: bool = false) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "life": 20.0, "enemy": false, "damage": damage, "ghost": ghost, "ghost_age": 0.0}
func bill(point: Vector2, tie: bool = true) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "life": 20.0, "enemy": true, "gravity": 0.0, "tie": tie}
func bot(point: Vector2) -> Dictionary:
	return game.combat.new_bot(game,point.x,game.world_three.below(game,point.x,point.y),"throw",{"entered":true,"speed":0.0,"cd":100.0,"hp":20,"dz":10.0})
func jar_fixture(age: float = 1.4, x: float = 4200) -> Dictionary:
	var state := arena()
	state.state = "down"; state.t = 2.0; state.hp = 0
	state.jar = {"x": x, "y": 452.0, "vx":0.0,"vy":0.0,"t":age,"got":false}
	return state.jar
func snapshot() -> String:
	return var_to_str([
		game.player,game.velocity,game.camera,game.hearts,game.elapsed,game.face,game.grounded,game.on_platform,
		game.power,game.power_time,game.cooldown,game.invincible,game.hurt_lock,game.score,game.pop_count,
		game.boss.state if game.boss != null else {},game.world_three.snapshot(),game.enemies,game.bullets,
		game.coins,game.items,game.crates,game.receipts,game.combat.waves,game.combat.go_time,
		game.abilities.effects,game.abilities._time,game.abilities.active,game.abilities.remaining,game.abilities.meter,
		game.movement_skills.time,game.movement_skills.slide_remaining,game.movement_skills.dash_remaining,
		game.movement_skills.ground_pounding,game.movement_skills.effects,
		game.world_three.rng.state,game.combat.rng.state,game.abilities.rng.state,
		game.boss.rng.state if game.boss != null else 0,game.save,
	])
func button(prefix: String) -> Button:
	return preload("res://tests/campaign_ui_support.gd").button(game, prefix)

func touch(point: Vector2, pressed: bool, index: int = 5) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = root.get_screen_transform()*point; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func tap(control: Button) -> void:
	check(control != null, "Required native GUI button exists")
	if control == null: return
	var point := control.get_global_rect().get_center()
	await touch(point,true); await touch(point,false)

func run() -> void:
	game = load("res://main.tscn").instantiate(); game.set_script(ProbeHost)
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = Base.AudioLog.new()
	game.world_three = Base.ProbeWorld.new(); game.world_three.trace = trace
	game.world_three.finale = ProbeFinale.new(); game.world_three.finale.trace = trace
	game.festival_combat = Base.ProbeCombat.new(); game.festival_combat.trace = trace
	game.abilities = Base.ProbeAbilities.new(); game.abilities.trace = trace
	game.festival_tout_renderer = ProbePainter.new()
	await process_frame
	test_entry_and_order()
	test_stage_hops_and_visuals()
	test_shots_and_late_effects()
	test_collision_boundaries()
	test_six_housemates()
	test_jar_and_knockout()
	await test_touch_and_lifecycle()
	await test_drawing()
	await test_campaign_clear()
	game.queue_free(); await process_frame
	print("Ticket Tout actual-main integration: ",checks," checks; ",failures.size()," failures (explicit fixtures, not full-route/device evidence)")
	quit(0 if failures.is_empty() else 1)

func test_entry_and_order() -> void:
	fresh()
	check(game.is_native_supported() and game._native_world_three() and game.scene_runtime == game.world_three and game.combat == game.festival_combat and game.festival_renderer == game.festival_tout_renderer,"3-6 selects native runtime, combat and exact Tout painter")
	check(game._source_ability_shots() and not game._native_world_one() and not game._native_world_two(),"3-6 uses source ghost semantics without aliasing another world")
	check(game.combat.waves.size() == 3 and game.combat.waves.map(func(w): return w.group.size()) == [3,3,4],"Exact three solo approach waves contain ten entries")
	check(game.world_three.surfaces(game).size() == 9 and game.crates.size() == 3 and game.receipts.size() == 3 and game.world_three.tents.is_empty(),"Authored eight solids, stage platform, three crates and receipts; no invented tents")
	check(game.player == Vector2(300,482) and game.boss == null,"Fresh source starting point has no premature boss")
	var original := JSON.stringify(game.meta)
	place(); game.step(0,{})
	check(game.boss == null and game.mode == "play" and game.world_three.end_time == 0,"Arena camera cannot bypass unfinished waves or start ordinary timed ending")
	mark_waves(); game.combat.waves[2].done = false; game.combat.waves[2].index = 0
	game.step(0,{})
	check(game.boss == null,"Third incomplete approach wave blocks entry even after first two")
	mark_waves(); place(Vector2(3910,482),3659.999); game.step(0,{})
	check(game.boss == null,"Entry excludes camera strictly below3660")
	place(); game.step(0,{})
	check(game.boss != null and game.boss.state.hp == 160 and game.boss.state.max == 160 and game.boss.state.kind == "tout" and not game.boss.state.cfg.has("mini"),"Inclusive3660 starts original non-mini160HP Tout")
	check(game.camera_lock == 3662 and game.boss.state.cam == 3662 and game.boss.state.x == 4310 and game.boss.state.state == "enter","Entry full-lock3662 and same-frame boss pass clamps initial4560 to4310")
	check(game.audio.starts == [true] and game.audio.effects.count("warn") == 1,"Entry emits one warning and one boss soundtrack request")
	var state: Dictionary = game.boss.state
	game.step(0,{})
	check(is_same(state,game.boss.state) and game.audio.starts == [true],"Repeated end trigger never replaces boss or starts soundtrack twice")
	tick(0.61)
	check(state.state == "walk" and near(state.next,1.6),"Actual host entry walks into the arena before becoming vulnerable")
	check(JSON.stringify(game.meta) == original,"Full entry leaves original metadata unchanged")
	fresh(); game.combat.reset(game,2,31); mark_waves(); place(); game.step(0,{})
	check(game.boss.state.hp == 220 and game.boss.state.max == 220 and game.combat.waves.map(func(w): return w.group.size()) == [4,4,5],"Explicit participant-count adapter gives220HP and13pair entries; not native co-op claim")
	fresh(); place(); mark_waves()
	var last: Dictionary = game.combat.waves[-1]; last.done = false
	var enemy := bot(Vector2(4050,482)); enemy.hp = 1; enemy.dz = 0
	game.bullets = [shot(enemy.p-Vector2(0,60))]; game.step(0,{})
	check(enemy.state == "pop" and not last.done and game.boss == null,"Final bot killed in shot pass does not finish wave or start boss earlier that frame")
	game.step(0,{})
	check(last.done and game.boss != null,"Following wave pass releases last wave and same-frame late hook starts Tout")
	trace.clear(); game.step(0.01,{})
	check(trace.map(func(row): return row[0]) == ["motion","carry","after_motion","pre","camera","waves","objective","bots","bubbles","shots","pickups","world","finale","boss","jar","visual","effects","finish"],"Actual main preserves complete player/combat/late-world/boss/jar/snapshot/late-ability order")
	check(game.world_three.finale.samples.back().x == game.boss.state.x and game.world_three.finale.samples.back().sample == game.boss.state.x,"Visual sample observes completed boss motion")

func test_stage_hops_and_visuals() -> void:
	var state := arena()
	check(is_same(game.boss._stage,game.world_three.surfaces(game)[8]) and game.boss._stage.row[0] == 4040 and game.boss._stage.row[1] == 4290 and game.boss._stage.row[2] == 354 and game.boss._stage.base == 482,"Numeric stage zero binds live cases surface, not first solid or false")
	state.hp = 100; state.t = 1; state.next = 0; state.stage_t = 0
	game.step(0,{})
	check(state.has("hop") and state.hop.end == Vector2(4165,354) and state.hop.duration == 0.8 and state.hop.height == 160 and not state.hop.slam and state.stage_t == 9,"Middle-health attack uses authored stage hop")
	var before_x: float = state.x
	game.step(0.01,{})
	check(near(state.visual_x,state.x) and state.visual_t == game.world_three.level_time and state.fy < 482,"Host samples after airborne boss interpolation")
	tick(0.78)
	state.hop.t = 0.79 # Exact final-step boundary, avoiding accumulated float drift in fixture.
	game.step(0.01,{})
	check(not state.has("hop") and near(state.fy,354) and state.next == 0.9 and state.stage_t == 9,"Stage hop lands on live354 top; early return freezes stage timer")
	state.stage_t = 0; state.t = 1; state.next = 0; game.step(0,{})
	check(state.hop.slam and state.hop.end == Vector2(game.player.x,482) and state.hop.duration == 0.9 and state.hop.height == 140,"Expired stage timer creates targeted ground slam")
	tick(0.88); state.hop.t = 0.89; game.step(0.01,{})
	check(not state.has("hop") and state.fy == 482 and state.land_t == 0.32 and state.waves.size() == 2 and state.waves[0].vx == -460 and state.waves[1].vx == 460,"Slam landing spawns exact two460px/s waves and320ms landing snapshot")
	check(state.visual_x == state.x and state.moved and state.x != before_x,"Slam displacement is sampled on landing frame")
	state = arena(); state.x = 4200; state.visual_x = 4200; state.visual_t = game.world_three.level_time
	game.step(0.01,{})
	check(state.moved and near(state.visual_x,4199.1),"Actual walking90px/s sets movement flag after boss tick")
	var sampled: float = state.visual_x; state.x += 1; game.step(0,{})
	check(state.visual_x == sampled and state.moved,"Repeated zero-delta level_time does not resample changed x")
	state.x = game.player.x+100; game.step(0.01,{})
	game.step(0.01,{})
	check(not state.moved,"Stationary next distinct simulation time returns to hide snapshot")
	state = arena(); state.hp = 80; state.dz = false; game.step(0,{})
	check(state.dizzy == 0 and not state.dz,"Exactly half health does not activate dizzy")
	game.bullets = [shot(Vector2(state.x,400))]; game.step(0,{})
	check(state.hp == 79 and state.dizzy == 2.6 and state.dz,"Shot crossing strict half-health activates dizzy in later boss pass")
	game.bullets = [shot(Vector2(state.x,400),999,true)]; game.step(0.01,{})
	check(state.hp == 77 and near(state.dizzy,2.59),"Following ghost hit sees prior dizzy for fixed2 damage before countdown")
	state.dizzy = 0; game.step(0,{})
	check(state.dizzy == 0,"One-time half-health dizzy cannot retrigger")

func test_shots_and_late_effects() -> void:
	for ghost in [false,true]:
		var state := arena(); var point := Vector2(state.x,430)
		var enemy := bot(Vector2(state.x,482)); enemy.dz = 0
		var crate := {"p":Vector2(state.x,482),"hp":3,"give":"heart","broken":false,"hit":0.0}
		game.crates.append(crate); game.bullets = [shot(point,1,ghost)]; game.step(0,{})
		check(enemy.hp == 19 and state.hp == 160 and crate.hp == 3,str(ghost)+" ordinary bot consumes shot before Tout and crate")
		game.enemies.clear(); game.bullets = [shot(point,999,ghost)]; game.step(0,{})
		check(state.hp == 159 and crate.hp == 3 and game.bullets.is_empty(),str(ghost)+" Tout consumes hit before crate and ignores999 damage payload")
		state.dizzy = 1; game.bullets = [shot(point,999,ghost)]; game.step(0,{})
		check(state.hp == 157,str(ghost)+" dizzy Tout damage is exactly2")
		state.state = "enter"; game.bullets = [shot(point,999,ghost)]; game.step(0,{})
		check(state.hp == 157 and crate.hp == 2,str(ghost)+" invulnerable enter passes shot to crate for fixed1")
		state.state = "down"; state.t = 0; game.crates.clear(); game.bullets = [shot(point,999,ghost)]; game.step(0,{})
		check(state.hp == 157,str(ghost)+" down Tout rejects all shot damage")
	var state := arena("ama"); game.abilities.meter = 1; game.step(0,{"special":true})
	check(state.hp == 158 and state.dizzy == 3.5,"Ama special sets dizzy before same-frame ghost: source3 payload becomes fixed2")
	state = arena("theo")
	game.abilities.effects = [{"kind":"ball","p":Vector2(state.x,350),"v":Vector2.ZERO,"age":0.0,"life":5.0,"spin":0.0,"free":0.0,"boss_next":0.0,"floor":482.0,"trail":[]}]
	game.step(0.01,{})
	check(state.hp == 160 and game.bullets.any(func(b): return b.get("ghost",false)),"Theo late football creates ghost only after this frame's boss/shot pass")
	game.step(0,{})
	check(state.hp == 159,"Next main shot pass applies football ghost once for fixed1")
	for stage in [false,true]:
		state = arena(); state.state = "throw"; state.t = 0.31; state.pending_throw = true
		state.fy = 354 if stage else 482
		game.step(0.01,{})
		check(game.bullets.size() == (5 if stage else 3) and game.bullets.all(func(b): return b.enemy and b.tie and b.gravity == 1600 and b.age == 0),"Late "+str(stage)+" stage volley uses source count/ties/gravity without same-frame motion")
		var projectile: Dictionary = game.bullets[0]; var p: Vector2 = projectile.p
		game.step(0.01,{})
		check(projectile.p != p and near(projectile.age,0.01),"New Tout band first moves on following ordinary projectile pass")

func test_collision_boundaries() -> void:
	for fixture in [
		[Vector2(4235,350),false],[Vector2(4234.99,350),true],
		[Vector2(4095,350),false],[Vector2(4095.01,350),true],
		[Vector2(4165,232),false],[Vector2(4165,232.01),true],
		[Vector2(4165,482),false],[Vector2(4165,481.99),true],
	]:
		var state := arena(); game.bullets = [shot(fixture[0],999,true)]; game.step(0,{})
		check(state.hp == (159 if fixture[1] else 160),"Actual shot strict70px/250px/feet bound "+str(fixture[0]))
	for fixture in [[Vector2(3888,482),false],[Vector2(3888.01,482),true],[Vector2(3950,362),false],[Vector2(3950,362.01),true]]:
		var state := arena(); state.x = 3950; game.player = fixture[0]; game.invincible = 0
		game.step(0,{})
		check(game.hearts == (2 if fixture[1] else 3),"Actual boss body strict62px/120px contact bound "+str(fixture[0]))
	for fixture in [[24.0,482.0,false],[23.99,482.0,true],[0.0,452.0,false],[0.0,452.01,true]]:
		var state := arena(); game.player.y = fixture[1]; game.invincible = 0
		state.waves = [{"x":game.player.x+fixture[0],"vx":0.0,"t":0.0}]; game.step(0,{})
		check(game.hearts == (2 if fixture[2] else 3),"Actual shockwave strict24px/ground-minus30 bound "+str(fixture))
	fresh(); place(Vector2(4165,354)); game.on_platform = true; game.world_three.tied = 1
	check(game.skill_floor_below(4165,340) == 354 and game.ability_land_on(4165,350,355) == 354 and not game.ability_inside_wall(Vector2(4165,400)),"Main movement/ability queries share stage0 one-way surface")
	game.step(0,{"jump":true,"down":true})
	check(not game.grounded and game.velocity.y == 120 and game.drop_time == 0.26,"Tied stage0 Down+freshJump still drops through platform before blocked ordinary jump")

func test_six_housemates() -> void:
	for who in game.CHARACTERS:
		var state := arena(who); game.player.x = state.x-100; game.face = 1
		game.step(0,{"shoot":true})
		check(state.hp == 159 and game.cooldown == 0.21 and game.shoot_time == 0.3,who+" actual shoot control reaches Tout once")
		game.step(0,{"shoot":true})
		check(state.hp == 159,who+" held shoot cannot bypass cooldown")
		fresh(who); game.invincible = 0
		game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0.01,{})
		check(game.hearts == 2 and near(game.world_three.tied,2.19) and game.hurt_lock == 0.42,who+" actual wristband removes one heart and ties before late countdown")
		game.hurt_lock = 0; game.velocity = Vector2.ZERO; game.bullets = [bill(game.player-Vector2(0,80))]
		game.step(0.01,{"jump":true,"right":true})
		check(game.hearts == 2 and near(game.world_three.tied,2.19) and game.grounded,who+" invulnerable wristband still refreshes tie; tied ordinary jump stays blocked")
		fresh(who); game.invincible = 0; var high: float = game.character_height()*0.7
		game.bullets = [bill(game.player-Vector2(0,high))]; game.step(0,{"down":true})
		check(game.hearts == 3 and game.world_three.tied == 0 and game.crouching,who+" crouching hitbox dodges high wristband")
		fresh(who,["slide"]); game.invincible = 0; game.movement_skills.slide_remaining = 0.2
		game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0,{})
		check(game.hearts == 3 and game.world_three.tied == 2.2,who+" earned slide blocks heart damage but not source tie side effect")
		fresh(who); game.invincible = 0; game.abilities.meter = 1
		game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0,{"special":true})
		var cancels: bool = who in ["maya","ama"]
		check(game.abilities.active == who and game.abilities.meter == 0,who+" actual special control activates its own ability")
		check(game.hearts == (3 if cancels else 2) and game.world_three.tied == (0 if cancels else 2.2),who+" only Maya shield/Ama bubble cancel band before contact")
		fresh(who)
		for i in game.receipts.size():
			var p: Vector2 = game.receipts[i].position
			place(Vector2(p.x+42,p.y+50),maxf(0,p.x-300)); game.step(0,{})
			check(not game.receipts[i].taken,who+" receipt"+str(i)+" strict42px edge excluded")
			game.player.x -= 0.01; game.step(0,{})
			check(game.receipts[i].taken and game.receipts[i].position == p,who+" receipt"+str(i)+" collects at unchanged source center")
		var saved := SaveStore.read_save()
		check(game.receipts.map(func(r): return r.position) == [Vector2(1820,312),Vector2(2000,252),Vector2(4170,282)] and saved.receipts.get("3-6",[]) == [0,1,2] and saved.kitty == 13 and game.score == 0 and game.save_calls == 3,who+" all three exact source receipts persist once without money")
		game.load_level("3-6")
		check(game.receipts.all(func(r): return not r.taken and r.previously_collected),who+" replay resets live receipts but preserves saved collection markers")
	fresh("maya"); game.invincible = 0
	game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0,{})
	game.invincible = 0; game.hurt_lock = 0; game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0,{})
	check(game.hearts == 2 and game.invincible == 0.9 and game.world_three.tied == 2.2,"Maya alternating passive blocks second eligible heart hit but retains wristband tie")
	fresh("maya"); game.invincible = 0; game.abilities.active = "maya"; game.abilities.duration = 6; game.abilities.remaining = 0.01
	game.bullets = [bill(game.player-Vector2(0,81))]; game.step(0.01,{})
	check(game.abilities.active == "" and game.hearts == 3 and game.world_three.tied == 0 and game.bullets.is_empty(),"Maya exact-expiry shield cancels band before ordinary projectile loop")

func test_jar_and_knockout() -> void:
	var state := arena(); state.hp = 1
	game.bullets = [shot(Vector2(state.x,400),999)]; game.step(0,{})
	check(state.state == "down" and state.jar.is_empty() and game.mode == "play" and game.save_calls == 0 and not game.save.cleared.has("3-6"),"Last real hit defeats Tout without awarding completion")
	check(game.coins.size() == 16 and game.observed_drops.back().count == 16 and game.audio.starts == [true,false],"Defeat drops sixteen coins and switches from boss to ordinary soundtrack")
	tick(1.5)
	check(state.jar.is_empty() and game.mode == "play","Jar waits through exact1.5s down age")
	game.step(0.001,{})
	check(not state.jar.is_empty() and near(state.jar.t,0.001) and near(state.jar.x,state.x-10-0.12) and near(state.jar.vy,-897.6),"Crossing down delay creates jar then runs same-frame jar gravity/clock")
	var jar := jar_fixture(1.4)
	game.step(0.01,{})
	check(jar.x == 4200 and near(jar.t,1.41),"Magnet uses previous age: exact1.4 gets no movement despite current jar age crossing")
	game.step(0.01,{})
	check(near(jar.x,4198.8) and near(jar.t,1.42),"Following late magnet moves exactly120px/s before jar clock")
	jar = jar_fixture(1.401); jar.y = 200; jar.vx = -120; jar.vy = 0
	game.step(0.01,{})
	check(near(jar.x,4197.6) and near(jar.y,200.24) and near(jar.vy,24),"Late magnet and subsequent airborne jar velocity both apply once in source order")
	jar = jar_fixture(0.59,4000); game.player = Vector2(4000,100); game.grounded = false
	game.step(0.01,{})
	check(near(jar.t,0.6) and not jar.got and game.mode == "play","Strict jar pickup age excludes exact600ms even at matching x")
	game.player.x = 4050; game.step(0.001,{})
	check(not jar.got and game.mode == "play","Mature jar excludes exact50px horizontal pickup edge")
	game.player.x -= 0.01; game.step(0,{})
	check(jar.got and game.mode == "clear" and game.player.y < 110 and game.save_calls == 1,"Inside horizontal edge collects despite large vertical separation and settles once")
	var saved := SaveStore.read_save(); var before := snapshot(); var kitty: int = saved.kitty
	game.step(1,{}); game._complete_level(); game.combat.jar_tick(1,game)
	check(game.save_calls == 1 and SaveStore.read_save().kitty == kitty and saved.cleared.get("3-6",false),"Repeated clear/frame/jar callbacks do not double bank or double save")
	check(snapshot() == before,"Completed encounter remains frozen")
	jar = jar_fixture(2,3910); game.hearts = 1; game.invincible = 0
	game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0.01,{})
	check(game.mode == "over" and game.hearts == 0 and not jar.got and game.save_calls == 0 and not game.save.cleared.has("3-6"),"Lethal bill before mature jar leaves no living collector and never false-clears")
	before = snapshot(); game.step(10,{})
	check(snapshot() == before,"Game-over freezes defeated boss, uncollected jar and all late clocks")
	game._continue_level(); game.step(0,{})
	check(game.mode == "clear" and jar.got and game.save_calls == 1,"Continue preserves eligible jar and genuine living pickup can now clear")

func test_touch_and_lifecycle() -> void:
	for who in game.CHARACTERS:
		var state := arena(who); game.player.x = state.x-100; game.face = 1
		await touch(game.buttons.shoot.get_center(),true)
		game._physics_process(0.016)
		check(state.hp == 159 and game._held("shoot"),who+" real ScreenTouch dispatch routes shoot through actual physics controls")
		await touch(game.buttons.shoot.get_center(),false)
		check(not game._held("shoot") and game.touches.is_empty(),who+" real touch release removes held shoot")
	var jar := jar_fixture(1.45); game.world_three.tied = 0.8
	await touch(game.buttons.right.get_center(),true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await touch(game.buttons.right.get_center(),false) # Release the physical finger before a new GUI tap.
	var before := snapshot(); var generation: int = game.world_three.run_generation
	game.step(5,{"right":true})
	check(game.mode == "paused" and game.touches.is_empty() and game.audio.paused and snapshot() == before,"Focus pause clears touch and freezes full jar/boss/clock/RNG state")
	await tap(button("Resume"))
	check(game.mode == "play" and game.world_three.run_generation == generation and is_same(jar,game.boss.state.jar),"Real Resume GUI preserves active jar and generation")
	game.hearts = 1; game.invincible = 0; game.bullets = [bill(game.player-Vector2(0,80))]; game.step(0,{})
	before = snapshot(); var state: Dictionary = game.boss.state
	await tap(button("Continue"))
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5 and is_same(game.boss.state,state) and is_same(game.boss.state.jar,jar),"Real Continue heals in place while preserving same boss/jar objects")
	check(game.world_three.run_generation == generation and state.hp == 0 and near(jar.t,1.45),"Continue preserves clocks and zeroHP down state without restarting encounter")
	game.load_level("3-6")
	check(game.boss == null and game.player == Vector2(300,482) and game.world_three.tied == 0 and game.world_three.level_time == 0 and game.camera_lock == null and game.world_three.run_generation != generation,"Fresh replay resets encounter, jar, stage clocks and camera lock")
	check(not game.world_three._apply_scene_transition(game,generation) and game.boss == null,"Stale prior-generation callback cannot mutate fresh Tout run")
	jar_fixture(); jar = game.boss.state.jar; var old_x: float = jar.x
	game._show_menu(); game.world_three.finale.after_mini_trigger(1,game,game.world_three)
	check(jar.x == old_x and game.mode == "menu" and not game.world_three._can_step(game),"Menu invalidates late magnet rather than moving old jar off-screen")
	fresh(); game._physics_process(1)
	check(near(game.elapsed,0.034) and near(game.world_three.level_time,0.034),"Real physics host clamps long frame to source34ms")

func test_drawing() -> void:
	var state := arena(); var painter = game.festival_renderer
	bot(Vector2(4000,482)); game.bullets = [bill(Vector2(4030,300))]
	state.jar = {"x":4020.25,"y":230.125,"t":0.8,"got":false,"vx":0.0,"vy":0.0}
	painter.calls.clear(); painter.hud_calls = 0; var callbacks: int = game.draw_callbacks
	var before := snapshot(); var meta_before := JSON.stringify(game.meta)
	game.queue_redraw(); await process_frame; await process_frame
	check(game.draw_callbacks > callbacks and painter.calls.has("sky") and painter.calls.has("level") and painter.calls.has("finds") and painter.calls.has("bill"),"Actual CanvasItem _draw invokes source sky/level/finds/bands")
	var calls: Array = painter.calls
	check(calls.find("boss") < calls.find("bot") and calls.find("bot") < calls.find("jar") and calls.find("jar") < calls.find("player_back") and calls.find("player_front") < calls.find("bill") and calls.find("bill") < calls.find("front"),"Actual world draw order is Tout, bots, jar, players, bands, foreground")
	check(calls.count("jar") == game.draw_callbacks-callbacks,"Host calls jar painter exactly once per actual world callback")
	check(snapshot() == before and JSON.stringify(game.meta) == meta_before,"Actual drawing preserves every gameplay snapshot, metadata and RNG")
	check(painter.hud_calls > 0,"Real SceneOverlay CanvasItem callback paints Tout health HUD through selected painter")
	for animation in ["walk","hide","throw","stomp","dizzy","surf","down"]:
		state.erase("hop"); state.dizzy = 0; state.land_t = 0; state.state = "walk"; state.moved = false; state.t = 0.17
		match animation:
			"walk": state.moved = true
			"throw", "stomp", "down": state.state = animation
			"dizzy": state.dizzy = 1
			"surf": state.hop = {"t":0.2,"duration":0.8,"slam":false}
		state.face = 1; state.flash = 0.08; before = snapshot(); painter.painted_moves.clear()
		game.queue_redraw(); await process_frame; await process_frame
		check(painter.painted_moves.has(animation),"Real host callback draws original "+animation+" strip, mirrored and flashed")
		check(snapshot() == before,animation+" real repeated draw cannot advance movement/age or consume RNG")
	check(not painter._tout_flashes.is_empty(),"Actual flashing draw exercised dedicated pixel cache")
	game.load_level("3-5")
	check(game.festival_renderer == game.festival_hayride_renderer and painter._tout_flashes.is_empty(),"Leaving Tout restores hayride painter and clears Tout flash cache")
	game.load_level("3-6")
	check(game.festival_renderer == painter and game.boss == null,"Returning to Tout restores its painter without stale boss")

func test_campaign_clear() -> void:
	fresh(); game._show_menu()
	check(not game.start_campaign_level("3-6"),"Fresh campaign cannot enter locked Tout")
	for world in range(1,4):
		for stage in range(1,7 if world < 3 else 6): game.save.cleared["%d-%d" % [world,stage]] = true
	check(game.start_campaign_level("3-6") and game.mode == "story" and game.story.playing and game.save.seen.get("3-boss",false),"Eligible campaign opens original3-boss story before encounter")
	check(not game.start_campaign_level("3-6"),"Duplicate campaign entry cannot bypass active story")
	game.story.skip()
	check(game.mode == "play" and game.campaign_run and game.boss == null,"Skipping boss story returns to genuine empty approach")
	mark_waves(); place(); game.step(0,{})
	var state: Dictionary = game.boss.state
	state.state = "walk"; state.x = 4165; state.hp = 1; state.dizzy = 0; state.called = [true,true]; state.dz = true
	game.score = 7; game.save_calls = 0; game.observed_events.clear()
	game.bullets = [shot(Vector2(state.x,400))]; game.step(0,{})
	check(game.mode == "play" and not game.save.cleared.has("3-6"),"Campaign defeat still waits for real jar rather than committing clear")
	tick(1.51)
	check(not state.jar.is_empty(),"Campaign actual down lifecycle spawns jar")
	state.jar.x = game.player.x; state.jar.y = 452; state.jar.vx = 0; state.jar.vy = 0; state.jar.t = 0.6
	game.step(0.001,{})
	var score: int = game.score; var saved := SaveStore.read_save()
	check(game.mode == "clear" and state.jar.got and game.save_calls == 1 and saved.cleared.get("3-6",false),"Actual campaign jar pickup commits single persistent clear")
	check(saved.kitty == 13+score and game.coins.is_empty() and score == 23,"Jar pickup banks existing7 plus all16 scattered coins once")
	check(not game.story.playing and game.save.seen.get("3-boss",false),"Tout has pre-boss story only; no invented post-clear scene")
	game._complete_level(); game.step(1,{})
	check(game.save_calls == 1 and SaveStore.read_save().kitty == 13+score,"Duplicate finish cannot re-award campaign kitty")
	game._settle_up(); await tap(button("Next level"))
	check(game.mode == "menu" and game.campaign_view and game.campaign_target == "4-1" and game.campaign_map.auto_target == "4-1","Real next-level GUI focuses original World4 boundary, not leftover bonus")
	var next := button("→ 4-1")
	check(next != null and not next.disabled and not game.save.cleared.has("4-1"),"Native World4 unlocks without a false automatic clear")
	var progress := Campaign.snapshot(saved,game.catalog,NativeLevels.SUPPORTED)
	check(progress.worlds[2].completed and progress.worlds[3].unlocked and progress.levels["4-1"].playable,"Verified source progression records completed festival and playable holiday")
	check(game.start_campaign_level("3-6") and game.mode == "play" and game.boss == null,"Seen boss story replay starts fresh approach without repeat intro or inherited jar")
