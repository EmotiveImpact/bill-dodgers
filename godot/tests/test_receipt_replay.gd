extends SceneTree
## Actual-main W1 receipt replay and disk/HUD regression. Direct contact
## fixtures call the normal collection phase, not an input-driven traversal.
## No fixture grants a clear, skill, coin pickup or completion reward.
const Save = preload("res://src/save_store.gd")
const STAGES = ["1-1","1-2","1-3","1-4","1-5","1-6","1-S"]
const HEROES = ["jp","maya","ama","leo","theo","mei"]
const BANKED_KITTY = 73
var checks := 0
var failures: Array[String] = []
var game
var contacts := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

func saved_fixture() -> Dictionary:
	var history := {}
	for id in STAGES: history[id] = [0,1,2]
	return {"schema":1,"receipts":history,"skills":[],"cleared":{},"kitty":BANKED_KITTY}

func fresh(id: String, who: String, mode: String = "solo", mate: String = "maya") -> void:
	game.mode = "menu"
	game.character = who
	check(game.configure_party(mode,mate),id+" "+who+" configure "+mode)
	game.save = saved_fixture()
	check(Save.write_save(game.save)==OK,id+" initial history written")
	game.save = Save.read_save()
	check(game.load_level(id,false),id+" actual main load")

func history_intact(label: String) -> void:
	var saved := Save.read_save()
	check(saved.receipts==saved_fixture().receipts and game.save.receipts==saved.receipts,label+" saved identities unchanged/no duplicates")
	check(saved.get("kitty",0)==BANKED_KITTY and game.save.get("kitty",0)==BANKED_KITTY,label+" no premature banking")
	check(saved.get("cleared",{}).is_empty() and game.save.get("cleared",{}).is_empty(),label+" no clear granted")
	check(saved.get("skills",[]).is_empty() and game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),label+" no skill granted")
	check(game.mode=="play" and game.pop_count==0,label+" remains uncompleted play")

func hud_text(tag: String) -> String:
	var commands: Array = game.player_hud.build_commands(game)
	var matching: Array = commands.filter(func(c):return c.tag==tag)
	return "missing" if matching.is_empty() else str(matching[0].text)

func fresh_run(label: String) -> void:
	check(game.receipts.size()==3 and game.receipts.all(func(r):return not r.taken and r.previously_collected),label+" saved receipts visible and available again")
	check(game.score==0 and game.receipt_score==0 and hud_text("player_coins")=="x0",label+" no free run/personal coins on reload")
	check(game.coins.is_empty(),label+" no loose coin inventory created by saved receipts")
	for index in 3:
		var source: Array = game.level.receipts[index]
		check(game.receipts[index].position==Vector2(source[0],source[1]-60),label+" unchanged source draw anchor "+str(index))
	history_intact(label)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	for id in STAGES:
		for who in HEROES:
			fresh(id,who)
			for replay in 2:
				var label: String = "%s/%s run%d" % [id,who,replay+1]
				if replay>0:
					game.save = Save.read_save()
					check(game.load_level(id,false),label+" disk reload")
				fresh_run(label)
				var immutable_source := JSON.stringify(game.meta)
				for index in 3:
					# Place feet inside the source receipt contact box. This does
					# not claim a natural path to its ledge or moving-bus position.
					game.player = game.receipts[index].position+Vector2(0,60)
					game.velocity = Vector2.ZERO
					game.collect_level_pickups()
					contacts += 1
					var expected := (index+1)*5
					check(game.receipts[index].taken,label+" physically recollected "+str(index))
					check(game.score==expected and game.receipt_score==expected,label+" exactly five shared Kitty per receipt")
					check(hud_text("player_coins")=="x0" and hud_text("kitty_label")=="Kitty £%d" % expected,label+" receipt excluded from personal coins")
					game.collect_level_pickups()
					check(game.score==expected and game.receipt_score==expected,label+" same-run contact cannot reward twice")
					history_intact(label+" receipt"+str(index))
				check(game.receipts.all(func(r):return r.taken) and game.score==15,label+" all three replay receipts collected")
				check(JSON.stringify(game.meta)==immutable_source,label+" original metadata never changed")
		print("RECEIPT_REPLAY_STAGE ",id," all six heroes; two direct-contact runs each")
	for mode in ["p2","cpu"]:
		pair_case(mode,false)
		pair_case(mode,true)
	game.mode = "menu"
	game.queue_free()
	await process_frame
	await process_frame
	print("World 1 receipt replay: %d checks, %d failures, %d solo receipt contacts + four pair fixtures. Direct-contact/save/HUD regression, not natural traversal." % [checks,failures.size(),contacts])
	quit(0 if failures.is_empty() else 1)

func pair_case(mode: String, both_touch: bool) -> void:
	var label: String = mode+" "+("both touching" if both_touch else "P2 only")
	fresh("1-1","jp",mode,"maya")
	check(game.party_session.active and game.party_session.runtime.actors.size()==2,label+" native pair active")
	fresh_run(label)
	var session = game.party_session
	var point: Vector2 = game.receipts[0].position+Vector2(0,60)
	var p1 = session.runtime.actors[0]
	var p2 = session.runtime.actors[1]
	p1.player = point if both_touch else point-Vector2(200,0)
	p2.player = point
	p1.coins = 0
	p2.coins = 0
	session.bind(game,0)
	check(session.bridge.begin_shared(0),label+" real shared pickup phase begins")
	for actor in session.runtime.living_actors():
		session.bridge.call_for_actor(actor.slot,game.collect_level_pickups)
	check(game.score==5 and game.receipt_score==5 and game.receipts[0].taken,label+" one shared reward")
	for actor in session.runtime.living_actors():
		session.bridge.call_for_actor(actor.slot,game.collect_level_pickups)
	check(game.score==5 and game.receipt_score==5,label+" repeated actor callbacks cannot duplicate reward")
	check(session.bridge.end_shared(0),label+" shared phase reconciles")
	check(p1.coins==0 and p2.coins==0 and hud_text("player_coins")=="x0" and hud_text("p2_player_coins")=="x0",label+" neither actor credited a coin")
	history_intact(label)
	game.save = Save.read_save()
	check(game.load_level("1-1",false),label+" replay loads")
	fresh_run(label+" replay")
	check(game.party_session.runtime.actors.all(func(actor):return actor.coins==0),label+" replay retains zero personal money")
