extends SceneTree
## Actual main.tscn fixtures, not full-route, framebuffer or device evidence.
## Explicit placements/state suppression isolate source phase boundaries.
const SaveStore = preload("res://src/save_store.gd")
const AudioLog = preload("res://tests/test_festival_integration.gd").AudioLog

class ProbeHost extends "res://src/main.gd":
	var observed_events: Array = []
	var observed_drops: Array = []
	var save_calls := 0
	func festival_event(event: Dictionary) -> void:
		observed_events.append(event.duplicate(true)); super.festival_event(event)
	func add_coins(point: Vector2, count: int) -> void:
		observed_drops.append({"p":point,"count":count}); super.add_coins(point,count)
	func _save_progress() -> void:
		save_calls += 1; super._save_progress()

class ProbePainter extends "res://src/festival_hayride_renderer.gd":
	var calls: Array = []
	var textured_polygons := 0
	func draw_level(host, runtime = null) -> void:
		calls.append("level"); super.draw_level(host,runtime)
	func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
		calls.append("finds"); super.draw_mid(host,runtime,pickups)
	func draw_enemy(host, enemy: Dictionary) -> bool:
		calls.append("enemy"); return super.draw_enemy(host,enemy)
	func draw_player_back(host, player = null) -> void:
		calls.append("player"); super.draw_player_back(host,player)
	func draw_front(host, runtime = null) -> void:
		calls.append("front"); super.draw_front(host,runtime)
	func draw_commands(host, commands: Array) -> void:
		textured_polygons += commands.filter(func(c): return c.type == "hayride_texture").size()
		super.draw_commands(host,commands)

var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func near(a: float,b: float) -> bool: return absf(a-b) < 0.002
func fresh(who: String = "jp") -> void:
	game.character = who
	game.save = {"schema":1,"receipts":{},"skills":[],"kitty":13}
	game.load_level("3-5")
	for wave in game.combat.waves: wave.at = INF
	game.step(0,{})
	game.coins.clear(); game.audio.clear_log()
	game.observed_events.clear(); game.observed_drops.clear(); game.save_calls = 0
func place(camera_x: float, relative_x: float = 300, feet: float = 402) -> void:
	# Explicit relocation of the one live deck, never META or an added floor.
	var deck: Dictionary = game.world_three.trailer
	deck.row[0] = camera_x+60; deck.row[1] = camera_x+540; deck.dx = 0.0
	game.player = Vector2(camera_x+relative_x,feet); game.camera = Vector2(camera_x,0)
	game.velocity = Vector2.ZERO; game.grounded = feet == 402; game.on_platform = game.grounded
	game.invincible = 999; game.hurt_lock = 0; game.jump_held = false; game.drop_time = 0
	game.camera_lock = null; game.camera_speed = 0; game._last_floor = feet
	game.world_three._standing_surface = deck if game.grounded else {}
func suppress_scene_and_harvester() -> void:
	game.world_three._scenes[1].done = true
	game.world_three.checkpoint_done = true
	game.world_three.hayride.harvester = {"dead":true,"hp":0.0,"x":-1e9,"flash":0.0,"t":0.0,"done":true}
func tick(seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.00000001:
		var dt := minf(seconds,0.01); game.step(dt,controls); seconds -= dt
func shot(point: Vector2, damage: int = 1, ghost: bool = false) -> Dictionary:
	return {"p":point,"v":Vector2.ZERO,"life":20.0,"enemy":false,"damage":damage,"ghost":ghost,"ghost_age":0.0}
func bill(point: Vector2) -> Dictionary:
	return {"p":point,"v":Vector2.ZERO,"life":20.0,"enemy":true,"gravity":0.0}
func bot(point: Vector2) -> Dictionary:
	return game.combat.new_bot(game,point.x,{"row":[point.x-500,point.x+500,point.y],"plat":true},"throw",{"entered":true,"hp":20,"speed":0.0,"cd":100.0})
func harvester_fixture() -> Dictionary:
	fresh(); place(15000)
	game.world_three._scenes[1].done = true; game.world_three.checkpoint_done = true
	game.step(0,{}) # Actual inclusive camera trigger.
	var h: Dictionary = game.world_three.hayride.harvester
	h.x = 15380.0 # Visible range permits testing the actual early shot-cull pass.
	return h
func chance_seed(dt: float) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in range(1,100000):
		rng.seed = candidate
		if rng.randf() < dt/2.6: return candidate
	return -1
func run() -> void:
	game = load("res://main.tscn").instantiate(); game.set_script(ProbeHost)
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	test_selection_and_carry()
	test_camera_and_fall()
	test_source_events_and_input()
	test_branches_and_receipts()
	test_scene_and_lifecycle()
	test_harvester_boundaries()
	test_projectile_precedence()
	test_death_and_bills()
	test_carriers()
	await test_draw()
	test_exit()
	game.queue_free(); await process_frame
	print("Festival hayride integration: ",checks," checks; ",failures.size()," failures (explicit actual-main fixtures)")
	quit(0 if failures.is_empty() else 1)

func test_selection_and_carry() -> void:
	for who in game.CHARACTERS:
		fresh(who)
		check(game._native_world_three() and game.scene_runtime == game.world_three and game.combat == game.festival_combat and game.festival_renderer == game.festival_hayride_renderer,who+" selects actual hayride runtime/combat/painter")
		check(game.player == Vector2(300,402) and game.grounded,who+" fresh floor query finds deck before initial placement")
		var q: Dictionary = game.world_three.trailer
		check(game.world_three.surfaces(game).size() == 1 and game.world_three.surfaces(game,true).is_empty() and is_same(q,game.world_three.surfaces(game)[0]) and is_same(q.row,game.world_three.surfaces(game)[0].row),who+" only platform keeps exact live dictionary/row identity")
		check(near(q.row[0],60) and near(q.row[1],540) and near(q.row[2],402) and q.nospawn and q.nodrop and q.style == "trailer" and q.dx == 0,who+" fresh authored deck properties and zero delta")
		var original := JSON.stringify(game.meta)
		game.world_three.level_time = 3
		var enemy: Dictionary = game.combat.new_bot(game,440,q,"throw",{"entered":true,"speed":0.0,"cd":100.0,"dz":10.0})
		game.step(0.01,{})
		check(near(game.player.x,300) and near(q.row[0],61.7) and near(q.dx,1.7),who+" camera/deck move late without same-frame player carry")
		check(near(enemy.p.x,441.7) and enemy.p.y == 402 and is_same(enemy.surface,q),who+" bot late carry reads exact moved surface")
		game.step(0.01,{})
		check(near(game.player.x,301.7) and near(enemy.p.x,443.4),who+" next player pass consumes previous deck delta")
		check(game.skill_floor_below(300,392) == 402 and game.ability_land_on(300,401,403) == 402 and not game.ability_inside_wall(Vector2(300,410)),"Skill/ability queries use live one-way deck")
		game.step(0,{"down":true,"jump":true})
		check(not game.grounded and game.velocity.y < 0 and game.drop_time == 0,who+" nodrop down+jump becomes ordinary jump, not drop")
		var airborne_x: float = game.player.x
		game.step(0.01,{})
		check(near(game.player.x,airborne_x),who+" airborne actor never receives deck carry")
		check(JSON.stringify(game.meta) == original,who+" deck/carry/query path leaves imported META unchanged")
	fresh()
	check(game.combat.waves.size() == 16 and game.combat.waves.reduce(func(n,w): return n+w.group.size(),0) == 39,"Actual sixteen solo groups retain39 carrier/fly entries")
	check(game.crates.is_empty() and game.coins.is_empty() and game.world_three.tents.is_empty(),"No invented crates/authored coins/tents")
	check(game.receipts.map(func(r): return r.position) == [Vector2(8000,212),Vector2(20000,212),Vector2(30000,212)],"Receipts retain stationary source centers")
	game.load_level("3-2"); check(game.festival_renderer == game.festival_queue_renderer and game.world_three.trailer.is_empty(),"Queue restores its own extension and no live deck")
	game.load_level("3-4"); check(game.festival_renderer == game.festival_big_top_renderer and game.world_three.big_top.movers.size() == 4,"Big top restores four trapezes")
	game.load_level("4-1"); game.level_id = "7-1"; game._complete_level()
	check(not game.is_native_supported() and game.mode == "play" and not game.save.get("cleared",{}).get("7-1",false),"Unknown run ID still cannot earn false completion")

func test_camera_and_fall() -> void:
	fresh(); game.world_three.level_time = 1.79; game.camera_speed = 91
	game.step(0.01,{})
	check(game.camera.x == 0 and game.camera_speed == 91 and game.world_three.trailer.dx == 0,"Exact1.8s warmup leaves follow speed and deck unchanged")
	game.step(0.001,{})
	check(near(game.camera.x,0.17) and near(game.world_three.trailer.dx,0.17),"Crossing warmup enables exact170px/s")
	fresh(); place(100,30); game.world_three.level_time = 3
	game.step(0.01,{})
	check(near(game.player.x,130) and near(game.camera.x,101.7),"Base left clamp samples previous camera before auto")
	game.step(0.01,{})
	check(near(game.player.x,131.7),"Following frame uses advanced left margin")
	fresh(); place(1000,300); suppress_scene_and_harvester()
	game.player.y = 572; game.grounded = false; game.velocity = Vector2.ZERO
	game.step(0,{})
	check(game.hearts == 3 and game.player.y == 572,"Exact authored fall572 boundary does not recover")
	game.player.y += 0.01; game.step(0,{})
	check(game.hearts == 2 and game.grounded and game.on_platform and game.player.y == 402 and game.velocity.x == 0,"Crossing fall boundary recovers onto live deck and bypasses ordinary invulnerability")
	check(game.player.x > game.world_three.trailer.row[0] and game.player.x < game.world_three.trailer.row[1],"Recovery selects actual moved deck interior")
	fresh(); var q: Dictionary = game.world_three.trailer
	var enemy: Dictionary = game.combat.new_bot(game,440,q,"throw",{"entered":true,"speed":0.0,"cd":100.0,"dz":10.0})
	enemy.p.y = 390; game.step(0,{})
	check(enemy.p.y == 390 and q.dx == 0,"Source zero-delta bot carry intentionally does not snap feet")

func test_source_events_and_input() -> void:
	for who in game.CHARACTERS:
		harvester_fixture(); game.character = who; game.abilities.reset(who)
		game.player.x = 15260; game.face = 1
		game.step(0,{"shoot":true})
		check(game.world_three.hayride.harvester.hp == 69 and game.cooldown > 0 and game.shoot_time > 0,who+" actual shoot control reaches late harvester once")
	fresh(); place(31461.99); suppress_scene_and_harvester(); game.step(0,{})
	check(game.world_three.stage_data.events_done.is_empty(),"Main-road event waits below exact31462 camera")
	place(31462); game.step(0,{})
	check(game.world_three.stage_data.events_done == [0] and game.status == "The main road!. Hold on, nearly there","Inclusive source main-road event uses exact authored text")
	var count: int = game.observed_events.size(); game.step(0,{})
	check(game.observed_events.size() == count,"One-shot road event cannot repeat")
	game.load_level("3-5")
	check(game.world_three.stage_data.events_done.is_empty(),"Fresh replay resets source road event")
	fresh(); game.world_three.level_time = 3
	game.combat.start_boss(game,{"name":"Fixture","kind":"seller","hp":60,"cam":900,"mini":true})
	game.step(0.01,{})
	check(game.camera.x == 0,"Only ordinary living host.boss blocks auto")
	game.boss.state.state = "down"; game.boss.state.t = 0; game.step(0.01,{})
	check(near(game.camera.x,1.7),"Ordinary down boss allows auto as source requires")

func test_branches_and_receipts() -> void:
	for who in game.CHARACTERS:
		fresh(who); suppress_scene_and_harvester()
		check(game.level.duck.size() == 18,who+" all18 original low branches loaded")
		var original := JSON.stringify(game.meta)
		for row in game.level.duck:
			place(float(row[0])-200,200); game.invincible = 0; game.hearts = 3; game.abilities.reset(who)
			game.step(0,{"down":true})
			check(game.hearts == 3 and game.player_animation == "crouch",who+" source crouch clears branch"+str(row[0]))
			game.step(0,{})
			check(game.hearts == 2 and game.hurt_lock > 0,who+" source upright branch hurts"+str(row[0]))
		check(JSON.stringify(game.meta) == original,who+" branch damage never edits immutable source")
		fresh(who); suppress_scene_and_harvester()
		for i in range(game.receipts.size()):
			var p: Vector2 = game.receipts[i].position
			place(p.x-300,342,300); game.step(0,{})
			check(not game.receipts[i].taken,who+" receipt exact42 horizontal edge remains uncollected")
			game.player.x -= 0.01; game.step(0,{})
			check(game.receipts[i].taken and game.receipts[i].position == p,who+" high receipt collects at unchanged world center")
		check(game.score == 0 and SaveStore.read_save().receipts.get("3-5",[]) == [0,1,2] and SaveStore.read_save().kitty == 13,who+" all receipts persist with zero money reward")
	fresh(); suppress_scene_and_harvester(); var row: Array = game.level.duck[0]
	for offset in [-10.001,-10.0,float(row[1])-row[0]+10,float(row[1])-row[0]+10.001]:
		place(float(row[0])-200,200+offset); game.invincible = 0; game.hearts = 3; game.abilities.reset("jp")
		game.step(0,{})
		check((game.hearts == 2) == (offset >= -10 and offset <= float(row[1])-row[0]+10),"Branch inclusive x margin "+str(offset))
	place(float(row[0])-200,200,float(row[2])-40); game.invincible = 0; game.hearts = 3; game.step(0,{})
	check(game.hearts == 3,"Branch strict feet lower edge is safe")
	game.player.y += 0.01; game.step(0,{})
	check(game.hearts == 2,"Branch just-inside feet lower edge hurts")
	place(float(row[0])-200,200,float(row[2])+game.character_height()*0.86+0.0001); game.invincible = 0; game.hearts = 3; game.step(0,{})
	check(game.hearts == 3,"Branch first representable point above head-underhang edge is safe")
	game.player.y -= 0.01; game.step(0,{})
	check(game.hearts == 2,"Branch just-inside head boundary hurts")

func test_scene_and_lifecycle() -> void:
	fresh(); place(13000,300,300); game.invincible = 0; game.hearts = 1
	game.world_three.level_time = 5; game.velocity.y = -123
	game.combat.waves[0].started = true
	var enemy: Dictionary = bot(Vector2(13400,402))
	game.step(0,{})
	check(not game.world_three.wiping and not game.world_three.checkpoint_done,"Exact13300 scene/checkpoint x stays inactive")
	game.player.x += 0.01; game.step(0,{})
	check(game.world_three.wiping and game.world_three.wipe_kind == "fade" and game.world_three.checkpoint_done and game.hearts == 3,"Dusk fade ignores live bot/busy wave and checkpoint heals")
	var generation: int = game.world_three.run_generation
	var deck: Dictionary = game.world_three.trailer
	game._pause(); var state: Dictionary = game.world_three.snapshot(); var rng_state: int = game.world_three.rng.state
	game.step(10,{"right":true})
	check(game.world_three.snapshot() == state and game.world_three.rng.state == rng_state,"Pause freezes all deck/scene/encounter clocks and RNG")
	game._resume()
	# A live harvester at a scene jump is an explicit source-compatible seam fixture.
	game.world_three.hayride.harvester = {"x":12900.0,"hp":70.0,"max":70.0,"flash":0.0,"t":0.0,"dead":false}
	tick(1.42)
	game.player.y = 250; game.velocity = Vector2(42,-77); game.grounded = false
	game.bullets.append(shot(Vector2(game.camera.x+100,200)))
	var camera_x: float = game.camera.x; var deck_x: float = deck.row[0]
	var harv_x: float = game.world_three.hayride.harvester.x
	var relative_x: float = game.player.x-camera_x
	game.step(0.01,{})
	check(game.camera.x == 14500 and game.world_three.scene_index == 1 and game.world_three.wipe_midpoint_done,"Production guarded callback reaches dusk14500 at1.43s")
	check(near(deck.row[0],deck_x+14500-camera_x) and is_same(deck,game.world_three.trailer) and deck.dx == 0,"Scene translates same deck by camera delta without fabricated carry")
	check(near(game.world_three.hayride.harvester.x,harv_x+0.5+14500-camera_x),"Scene translates live harvester after its late50px/s approach")
	check(near(game.player.y,249.56) and near(game.velocity.y,-44) and near(game.player.x-game.camera.x,relative_x+0.42) and game.velocity.x == 0,"Auto scene preserves airborne y/vy and relative x, clears vx only")
	check(game.enemies.is_empty() and game.bullets.is_empty() and enemy != null,"Scene clears ordinary actors/shots after late hooks")
	state = game.world_three.snapshot(); game._game_over(); game.step(5,{})
	check(game.world_three.snapshot() == state,"Knockout freezes pending fade and live encounter")
	game._continue_level()
	check(game.mode == "play" and game.world_three.snapshot() == state,"Continue keeps deck/harvester/fade state instead of reload")
	tick(0.74)
	check(not game.world_three.wiping and game.world_three.run_generation == generation,"Continue finishes same generation fade at2.17s")
	game.load_level("3-5")
	check(game.player == Vector2(300,402) and near(game.world_three.trailer.row[0],60) and near(game.world_three.trailer.row[1],540) and near(game.world_three.trailer.row[2],402) and game.world_three.trailer.dx == 0 and game.world_three.hayride.harvester.is_empty(),"Fresh replay after translated deck repairs original below-before-reset bug")
	check(not game.world_three._apply_scene_transition(game,generation) and game.camera.x == 0,"Old-generation callback cannot translate fresh replay")
	game._show_menu(); game.step(5,{})
	check(not game.world_three._apply_scene_transition(game,game.world_three.run_generation) and game.mode == "menu","Menu invalidates scene callbacks")

func test_harvester_boundaries() -> void:
	fresh(); place(14999.999); game.world_three._scenes[1].done = true; game.world_three.checkpoint_done = true
	game.step(0,{})
	check(game.world_three.hayride.harvester.is_empty(),"Harvester absent just below15000 camera")
	place(15000); game.step(0,{})
	var h: Dictionary = game.world_three.hayride.harvester
	check(h.hp == 70 and h.max == 70 and h.x == 14580 and game.boss == null and game.camera_lock == null,"Inclusive15000 starts exact70HP independent harvester")
	check(game.audio.starts == [true] and game.audio.effects.count("warn") == 1 and game.status.contains("harvester"),"Start event requests actual source boss music/warning once")
	game.step(0,{})
	check(is_same(h,game.world_three.hayride.harvester) and game.audio.starts == [true],"Repeated threshold neither replaces harvester nor restarts music")
	game.world_three.level_time = 3; game.step(0.01,{})
	check(near(game.camera.x,15001.7) and game.boss == null,"Live harvester does not stop auto camera")
	game.combat.reset(game,2); game.world_three.hayride.harvester = {}; game.step(0,{})
	check(game.world_three.hayride.harvester.hp == 91 and game.combat.waves.reduce(func(n,w):return n+w.group.size(),0) == 62,"Pair data adapter scales to91HP/62 entries without claiming co-op input")
	for ghost in [false,true]:
		for offset in [Vector2(-340,200),Vector2(-339.99,200),Vector2(10,200),Vector2(9.99,200),Vector2(0,102),Vector2(0,102.01),Vector2(0,579)]:
			h = harvester_fixture()
			game.bullets.append(shot(Vector2(h.x+offset.x,offset.y),99,ghost)); game.step(0,{})
			var hit: bool = offset.x > -340 and offset.x < 10 and offset.y > 102
			check(h.hp == (69 if hit else 70),"Harvester strict unswept rectangle "+str(offset)+" ghost="+str(ghost))
			if hit: check(h.x == 15374 and h.flash == 0.08,"Each surviving hit costs one and pushes exactly6")
	h = harvester_fixture(); game.bullets.append(bill(Vector2(h.x,200))); game.step(0,{})
	check(h.hp == 70,"Hostile bills never damage harvester")
	for offset in [Vector2(30,0),Vector2(29.99,0),Vector2(-200,60),Vector2(-200,59.99),Vector2(-200,-60),Vector2(-200,-59.99)]:
		h = harvester_fixture(); game.invincible = 0
		game.player = Vector2(h.x+offset.x,402+offset.y); game.grounded = false; game.on_platform = false
		game.step(0,{})
		var hit: bool = offset.x < 30 and absf(offset.y) < 60
		check(game.hearts == (2 if hit else 3),"Contact strict x/y boundaries "+str(offset))
		if hit: check(game.velocity.x > 0,"Harvester source hurt origin pushes player forward")

func test_projectile_precedence() -> void:
	for ghost in [false,true]:
		for kind in ["bot","boss","crate","wall","camera","dead","expired"]:
			var h: Dictionary = harvester_fixture(); var p := Vector2(h.x,200)
			match kind:
				"bot": bot(p+Vector2(0,50))
				"boss":
					game.combat.start_boss(game,{"name":"Fixture","kind":"seller","hp":60,"cam":15000,"mini":true})
					game.boss.state.state = "walk"; game.boss.state.x = p.x; game.boss.state.fy = p.y+100; game.boss.state.next = 100
				"crate": game.crates.append({"p":p+Vector2(0,35),"hp":3,"broken":false,"hit":0.0,"give":"heart"})
				"wall": game.world_three.surfaces(game).append({"row":[p.x-20,p.x+20,p.y-10],"plat":false})
				"camera": p.y = game.view_top()-60
			var projectile: Dictionary = shot(p,99,ghost)
			if kind == "dead": projectile.dead = true
			if kind == "expired": projectile.life = 0
			game.bullets.append(projectile); game.step(0,{})
			check(h.hp == 70 and game.bullets.is_empty(),kind+" consumes/removes before late harvester ghost="+str(ghost))
	var h: Dictionary = harvester_fixture()
	var fast: Dictionary = shot(Vector2(h.x-350,200)); fast.v.x = 40000
	game.bullets.append(fast); game.step(0.01,{})
	check(h.hp == 70 and not game.bullets.is_empty(),"Crossing entire body in one frame misses: late harvester is intentionally unswept")
	h = harvester_fixture()
	game.abilities.effects.append({"kind":"ball","p":Vector2(h.x,200),"v":Vector2.ZERO,"age":0.0,"life":5.0,"spin":0.0,"free":0.0,"boss_next":100.0,"floor":402.0,"trail":[]})
	game.step(0,{})
	check(h.hp == 70 and game.bullets.size() == 1 and game.bullets[0].ghost,"Late Theo effect queues a ghost after harvester scan")
	game.step(0,{})
	check(h.hp == 69,"Late-born ability ghost reaches harvester next frame only")
	h = harvester_fixture(); game.abilities.reset("maya"); game.abilities.active = "maya"; game.abilities.duration = 1; game.abilities.remaining = 0.01
	var canceled: Dictionary = bill(game.player-Vector2(0,81)); canceled.tie = true
	game.bullets.append(canceled); game.step(0.01,{})
	check(game.abilities.active == "" and game.hearts == 3 and game.world_three.tied == 0 and game.bullets.is_empty(),"Exact-expiry shield cancellation removes bill before hurt/tie and late harvester")

func test_death_and_bills() -> void:
	var h: Dictionary = harvester_fixture(); h.hp = 1; game.invincible = 0
	game.bullets = [shot(Vector2(h.x,200),999,true),shot(Vector2(h.x-1,200),999)]
	game.step(0,{})
	check(h.hp == -1 and h.x == 15368 and not h.dead and game.observed_drops.is_empty(),"Lethal scan keeps excess shot/6px pushes and defers death until next late frame")
	check(game.hearts == 2 and game.mode == "play","Lethal-shot frame still executes harvester contact")
	game.invincible = 999; game.step(0.01,{})
	check(h.dead and h.t == 0 and near(h.x,15365) and game.observed_drops == [{"p":Vector2(15140,302),"count":14}],"Next frame drops14 at deck+80/top-100, resets clock and retreats300px/s")
	check(game.coins.size() == 14 and game.coins.all(func(c):return c.age == 0),"Late death coins receive no same-frame pickup/motion")
	check(game.audio.starts == [true,false] and game.audio.effects.has("pop") and game.audio.effects.has("stomp"),"Death event resumes ordinary music with source pop/stomp")
	var event: Dictionary = game.observed_events[-1]
	check(event.type == "harvester_down" and event.shake == 14 and event.bits.size() == 5 and event.text == "Harvested!","Death passes source shake/debris/text event through host")
	h.t = 3.0; game.step(0,{})
	check(not game.world_three.hayride.harvester.get("done",false),"Exact3s retreat boundary keeps body")
	game.step(0.001,{})
	check(game.world_three.hayride.harvester.done and game.world_three.hayride.harvester.x == -1e9 and game.observed_drops.size() == 1,"Strict greater-than3s retires to nonempty done sentinel once")
	game.step(0.01,{})
	check(game.world_three.hayride.harvester.done and game.audio.starts == [true,false],"Done sentinel prevents respawn/music restart")
	h = harvester_fixture(); h.hp = 1; game.world_three.rng.seed = chance_seed(0.01)
	game.bullets.append(shot(Vector2(h.x,200))); game.step(0.01,{})
	check(h.hp == 0 and not h.dead and game.bullets.any(func(b):return b.enemy and b.get("big",false)),"Lethal hit does not suppress same-frame source random bill")
	h = harvester_fixture(); game.world_three.rng.seed = chance_seed(0.01)
	game.step(0.01,{})
	check(game.bullets.size() == 1 and game.bullets[0].enemy and game.bullets[0].big,"Actual late seeded random branch emits big bill")
	var projectile: Dictionary = game.bullets[0]
	check(projectile.p == Vector2(h.x-120,122) and projectile.v.x >= 250 and projectile.v.x <= 450 and projectile.v.y == -400 and projectile.gravity == 1400 and projectile.get("age",0) == 0,"Fresh harvester bill retains source origin/speed/gravity without early integration")
	var p: Vector2 = projectile.p
	game.step(0.01,{})
	check(projectile.p != p and near(projectile.age,0.01) and near(projectile.v.y,-386),"Following frame moves/gravitates ordinary hostile bill once")

func test_carriers() -> void:
	fresh(); game.combat.spawn(game,"k","throw"); game.combat.spawn(game,"d","flat")
	check(game.enemies.size() == 2 and game.enemies[0].carry and game.enemies[0].hp == 3 and game.enemies[0].p.y == 327 and game.enemies[1].fly and game.enemies[1].hp == 2 and game.enemies[1].p.y == 372,"Actual native carrier/fly factories use live deck and source HP/altitude")
	var carrier: Dictionary = game.enemies[0]
	carrier.p.x = carrier.tx; carrier.hop_t = 0; carrier.cd = 100
	game.world_three.level_time = 3; game.invincible = 999; game.step(0.01,{})
	check(not carrier.carry and not carrier.ride and carrier.type == "rush" and carrier.hop.duration == 0.42 and is_same(carrier.hop.surface,game.world_three.trailer),"Actual early carrier hook drops into420ms hop onto live deck")
	check(near(carrier.hop.end.x,clampf(carrier.p.x,120,480)+game.world_three.cam_dx*30) and game.combat.ex_drones.size() == 1 and game.combat.ex_drones[0].age == 0,"Carrier uses source camDX*30 lead and detaches once without drawing")
	carrier.hop.t = 0.41; game.step(0.01,{})
	check(not carrier.has("hop") and is_same(carrier.surface,game.world_three.trailer) and carrier.p.y == 402,"Hop completion retains live surface identity and top")
	game.combat.spawn(game,"k","throw"); var doomed: Dictionary = game.enemies.back()
	doomed.p.x = game.camera.x+450; doomed.cd = 100; doomed.hop_t = 100
	game.bullets.append(shot(doomed.p-Vector2(0,60),9)); game.step(0,{})
	check(doomed.state == "pop" and not doomed.carry and not doomed.ride and game.combat.ex_drones.size() == 2,"Real ordinary projectile kill detaches carrier during simulation")
	var drone: Dictionary = game.combat.ex_drones[-1]
	for departing in game.combat.ex_drones: departing.born = 0.0 # Exact clock boundary without subtractive rounding.
	game.world_three.level_time = 2.599; game.step(0,{})
	check(game.combat.ex_drones.has(drone),"Detached drone persists immediately before2.6s")
	game.world_three.level_time = 2.6; game.step(0,{})
	check(game.combat.ex_drones.is_empty(),"Actual visuals phase removes drones at2.6s with no render dependency")

func test_draw() -> void:
	fresh(); place(500); suppress_scene_and_harvester()
	game.world_three.hayride.harvester = {"x":600.0,"hp":35.0,"max":70.0,"flash":0.08,"t":1.0,"dead":false}
	game.combat.spawn(game,"k","throw"); game.combat.spawn(game,"d","flat")
	game.enemies[0].p.x = 750; game.enemies[1].p.x = 950; game.enemies[1].flash = 0.08
	game.combat.ex_drones.append({"p":Vector2(800,250),"age":0.3,"born":-0.3,"dir":1})
	var painter := ProbePainter.new(); game.festival_renderer = painter
	var state := JSON.stringify(game.world_three.snapshot())
	var meta := JSON.stringify(game.meta)
	var enemies := JSON.stringify(game.enemies); var drones := JSON.stringify(game.combat.ex_drones)
	var runtime_rng: int = game.world_three.rng.state; var combat_rng: int = game.combat.rng.state
	game.queue_redraw(); await process_frame; await process_frame
	check(painter.calls.has("level") and painter.calls.has("finds") and painter.calls.has("enemy") and painter.calls.has("player") and painter.calls.has("front"),"Actual CanvasItem dispatch executes dedicated hayride wrappers")
	check(painter.calls.find("level") < painter.calls.find("finds") and painter.calls.find("finds") < painter.calls.find("enemy") and painter.calls.find("enemy") < painter.calls.find("player") and painter.calls.find("player") < painter.calls.find("front"),"Actual draw order retains deck/finds/bots/players/harvester-front")
	check(painter.textured_polygons >= 4,"Real draw callback submits carrier/robot/fly/departure textured polygons with UV/texture arguments")
	var commands: Array = painter.build_level(game,game.world_three)
	var trailer: Dictionary = commands.filter(func(c):return c.tag == "hayride_trailer")[0]
	check(near(trailer.rect.position.x-game.camera.x,60) and near(trailer.rect.size.x,480/0.858),"Painter uses translated live deck width and camera-relative x")
	var hud: Array = painter.build_hud(game,game.world_three)
	check(hud.any(func(c):return c.tag == "hayride_health") and hud.any(func(c):return c.tag == "hayride_health_name" and c.text == "Harvester bot"),"Actual HUD receives source separate harvester health/label")
	game.queue_redraw(); await process_frame; await process_frame
	check(JSON.stringify(game.world_three.snapshot()) == state and JSON.stringify(game.meta) == meta and JSON.stringify(game.enemies) == enemies and JSON.stringify(game.combat.ex_drones) == drones and game.world_three.rng.state == runtime_rng and game.combat.rng.state == combat_rng,"Repeated actual draw is simulation/drone/metadata/RNG read-only")
	game.world_three.wiping = true; game.world_three.wipe_kind = "fade"; game.world_three.wipe_elapsed = 0.26
	hud = painter.build_hud(game,game.world_three)
	check(hud.find(hud.filter(func(c):return c.tag == "hayride_health")[0]) < hud.find(hud.filter(func(c):return c.tag == "wipe_cover")[0]),"Harvester health precedes source fade cover")
	game._show_menu(); await process_frame
	game.festival_renderer = game.festival_hayride_renderer

func test_exit() -> void:
	var h: Dictionary = harvester_fixture(); h.hp = 0; game.step(0,{})
	check(game.mode == "play" and not game.save.get("cleared",{}).get("3-5",false),"Harvester defeat alone never manufactures stage clear")
	fresh(); place(33259.99); game.world_three._scenes[1].done = true; game.world_three.checkpoint_done = true
	game.step(0,{})
	check(game.world_three.end_time == 0 and game.mode == "play","Camera below33260 cannot start end countdown")
	place(33260); game.world_three.level_time = 300; game.score = 7
	var enemy: Dictionary = game.combat.new_bot(game,33700,game.world_three.trailer,"throw",{"entered":true,"speed":0.0,"cd":100.0,"dz":100.0})
	game.step(0,{})
	check(game.world_three.end_time > 0 and game.world_three.hayride.harvester.hp == 70 and game.boss == null and game.combat.waves.any(func(w):return not w.done) and enemy.state != "pop","True auto endpoint starts with live harvester/bot/unfinished waves")
	game.world_three.end_time = 2.59; var x: float = game.camera.x
	game.step(0.01,{})
	check(game.mode == "play" and near(game.world_three.end_time,2.6) and near(game.camera.x,x),"Exact2.6s ending still plays and freezes auto")
	game.step(0.001,{})
	check(game.mode == "clear" and SaveStore.read_save().cleared.get("3-5",false) and SaveStore.read_save().kitty == 20,"Strict timed endpoint saves/banks exactly once despite live harvester")
	check(game.world_three.stage_data.end_run == 0,"Hayride does not accidentally advance queue jar-runner clock")
	var saved: Dictionary = SaveStore.read_save(); var count: int = game.save_calls
	game.step(10,{}); game._complete_level()
	check(SaveStore.read_save() == saved and game.save_calls == count,"Repeated completion cannot bank or save twice")
	game._return_to_map(); check(game.mode == "menu","Completed hayride returns to map")
