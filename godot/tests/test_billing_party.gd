extends SceneTree
## Real W6 world/combat/SirCharge and mutable PartyCombat. These are scoped
## fixtures, not a production scheduler or normal-difficulty route acceptance.
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const World = preload("res://src/world_six.gd")
const Combat = preload("res://src/billing_combat.gd")
const Charge = preload("res://src/sir_charge.gd")
class Host extends Fixtures.Host:
	var world_six = World.new()
	var pickup_slots: Array = []
	func view_width(): return 960.0 / 1.3
	func view_top(): return camera.y + 540 - 540 / 1.3
	func _land(x, a, b):
		var surface: Dictionary = world_six.land_on(self, x, a, b)
		return INF if surface.is_empty() else float(surface.row[2])
	func ability_inside_wall(point): return world_six.inside_wall(self, point)
	func combat_owner_slot(): return bridge.active_slot
	func party_capture_scene(actor): actor.scene_state.safe_position = world_six.safe_position
	func party_apply_scene(actor): world_six.safe_position = actor.scene_state.get("safe_position", actor.player)
	func collect_level_pickups(): pickup_slots.append(bridge.active_slot)
	func hurt_player(from_x):
		if invincible > 0 or hearts <= 0 or mode != "play": return
		if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
		hits.append(bridge.active_slot)
		hearts -= 1
		invincible = 1.5
		velocity.x = -350 if player.x < from_x else 350
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func fresh(id := "6-1", mode := "p2") -> Dictionary:
	var host = Host.new()
	host.level_id = id
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
	host.level = host.meta.level
	host.player = Vector2(host.level.start, host.meta.ground)
	host.combat = Combat.new()
	host.world_six.reset(host)
	var party = Party.new()
	party.configure(mode, "jp", "maya")
	party.start(id, host.player)
	for actor in party.actors:
		var surface: Dictionary = host.world_six.below(host, actor.player.x, host.player.y - 10)
		actor.player.y = surface.row[2]
		actor.scene_state.safe_position = actor.player
	party.actors[0].apply_native(host)
	host.world_six.safe_position = party.actors[0].player
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	host.combat.reset(host, party.actors.size())
	return {"host": host, "party": party, "bridge": bridge}
func finish(f: Dictionary) -> void:
	f.bridge.end_shared()
	f.host.world_six.invalidate_run()
func shot(p: Vector2, owner := 1, damage := 1) -> Dictionary:
	return {"p": p, "v": Vector2(780, 0), "enemy": false, "life": 20.0, "owner_slot": owner, "owner_x": 600.0, "damage": damage}
func bot(h, x := 550.0, hp := 1) -> Dictionary:
	return h.combat.new_bot(h, x, h.world_six.surfaces(h)[0], "rush", {"entered": true, "hp": hp, "speed": 100.0})
func _initialize() -> void:
	_scaling_and_clocks()
	_support_and_transitions()
	_lift_ride_and_fees()
	_targeting_and_loot()
	_owners_and_debits()
	_bosses()
	_hold_checkpoint_and_storm()
	print("Billing party integration: %d checks, %d failures. Mutable bridge fixtures, not party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _scaling_and_clocks() -> void:
	for id in World.SUPPORTED_LEVELS:
		var f := fresh(id)
		var h = f.host
		for i in h.level.waves.size():
			var expected: Array = h.level.waves[i].g.duplicate(true)
			expected.append_array(h.level.waves[i].get("x", []))
			check(h.combat.waves[i].group == expected, "%s wave %d exact unsorted pair extension" % [id, i])
		check(h.combat.participant_count == 2, id + " final pair roster count")
		h.world_six.pre_motion(0.1, h)
		check(is_equal_approx(h.world_six.level_time, 0.1) and h.world_six.world_time == 0, id + " pre-motion only advances source level clock")
		h.world_six.world_tick(0.1, h)
		check(is_equal_approx(h.world_six.world_time, 0.1), id + " once-shared world clock")
		check(h.pickup_slots == [0, 1], id + " physical secret callbacks for both living actors")
		finish(f)
	var f := fresh("6-4")
	var h = f.host
	f.bridge.record(0).p.y = 800
	f.bridge.record(1).p.y = -100
	check(h.world_six.wave_ready({"atY": 0}, h), "height wave starts for higher P2")
	f.bridge.record(1).down = true
	check(not h.world_six.wave_ready({"atY": 0}, h), "height wave ignores downed P2")
	finish(f)
func _support_and_transitions() -> void:
	var f := fresh()
	var h = f.host
	var a: Dictionary = f.bridge.record(0)
	var b: Dictionary = f.bridge.record(1)
	var surface: Dictionary = h.world_six.surfaces(h)[0]
	a.p = Vector2(surface.row[0] + 150, surface.row[2])
	b.p = Vector2(surface.row[0] + 260, surface.row[2])
	f.bridge.call_for_actor(0, h.world_six.after_motion, [h])
	f.bridge.call_for_actor(1, h.world_six.after_motion, [h])
	check(a.safe_position == a.p and b.safe_position == b.p and a.safe_position != b.safe_position, "safe floors are independently captured")
	surface.vx = 0.12
	var old_a: Vector2 = a.p
	var old_b: Vector2 = b.p
	f.bridge.call_for_actor(0, h.world_six.carry_player, [0.1, h])
	f.bridge.call_for_actor(1, h.world_six.carry_player, [0.1, h])
	check(a.p.x == old_a.x + 12 and b.p.x == old_b.x + 12, "belt carries both actor facades once")
	check(a.safe_position == old_a and b.safe_position == old_b, "carrying does not overwrite safe floors")
	b.grounded = false
	f.bridge.call_for_actor(1, h.world_six.carry_player, [0.1, h])
	check(b.p.x == old_b.x + 12, "airborne actor is not carried")
	# A living mate opens a door while leader is down. Door callbacks preserve
	# source velocity/platform/safe flags and do not silently revive.
	h.world_six.wiping = false
	for wave in h.combat.waves: wave.done = true
	var door: Dictionary = h.level.doors[0]
	a.down = true; a.hearts = 0
	b.p.x = door.x - 60
	h.world_six._doors_tick(h)
	check(h.world_six.wiping and h.world_six.doors_used.has(door.x), "P2 independently triggers door with downed P1")
	h.world_six._door.cp = true
	a.velocity = Vector2(123, 450); a.on_platform = true
	b.velocity = Vector2(-87, 220); b.on_platform = true
	var safe_a: Vector2 = a.safe_position
	h.bullets = [shot(Vector2(50, 300)), {"enemy": true, "p": Vector2.ZERO}]
	h.world_six._apply_door(h)
	check(a.p == Vector2(door.to + 80, h.meta.ground) and b.p == Vector2(door.to + 150, h.meta.ground), "door relocates every actor with source +70 slot spacing")
	check(a.px == a.p.x and b.px == b.p.x and a.grounded and b.grounded, "door stamps both actor previous x and grounded")
	check(a.down and a.hearts == 2 and b.hearts == 3, "cp door heals all but never revives a downed actor")
	check(a.velocity == Vector2(123, 0) and b.velocity == Vector2(-87, 0) and a.on_platform and b.on_platform, "party door retains source horizontal knockback and platform flags")
	check(a.safe_position == safe_a and h.bullets.size() == 1 and not h.bullets[0].enemy, "party door retains safe floor and friendly shots")
	check(h.world_six.checkpoint_done and h.world_six.scene_index == 1 and is_equal_approx(h.combat.go_time, 1.8), "door checkpoint latch and source go clock each set once")
	finish(f)
	f = fresh("6-S"); h = f.host
	a = f.bridge.record(0); b = f.bridge.record(1)
	a.down = true; a.hearts = 0
	b.p.x = h.level.dash.finish
	h.world_six.dash.left = 8.2
	check(h.world_six.done(h) and h.world_six.dash.bonus == 9, "living P2 finishes coffee dash")
	check(h.score == 9 and a.coins == 9 and b.coins == 0, "source coffee time bonus credits first slot even when downed")
	h.world_six.done(h)
	check(h.score == 9 and a.coins == 9, "native one-shot dash bonus preserved")
	finish(f)
func _lift_ride_and_fees() -> void:
	var f := fresh("6-4"); var h = f.host; var w = h.world_six
	var a: Dictionary = f.bridge.record(0); var b: Dictionary = f.bridge.record(1)
	w.level_time = 10
	var initial: float = w.lift.row[2]
	a.p.y = initial - 300; b.p.y = initial - 800
	var c: Dictionary = h.level.climb
	var progress := clampf((float(c.start) - b.p.y) / (float(c.start) - float(c.top)), 0, 1)
	var expected: float = initial - lerpf(float(c.v0), float(c.v1), progress) * 100
	w._lift_tick(0.1, h)
	check(is_equal_approx(w.lift.row[2], expected), "lift progress uses highest living and acceleration uses lowest living")
	a.p.y = w.lift.row[2] + 40; a.down = true; a.hearts = 0; a.velocity.y = 200
	b.p.y = w.lift.row[2] + 40; b.velocity.y = 300
	w._lift_tick(0, h)
	check(is_equal_approx(a.p.y, w.lift.row[2]) and a.grounded and a.down and a.hearts == 0 and a.velocity.y == 0, "lift pushes downed actor without harm or revival")
	check(b.hearts == 2 and b.velocity.y == -900 and not b.grounded and h.hits == [1], "lift harms and bounces actual living P2")
	for wave in h.combat.waves: wave.done = true
	b.p.y = h.level.climb.top; b.grounded = true
	check(w.done(h), "P2 can finish climb with downed leader")
	finish(f)
	f = fresh("6-5"); h = f.host; w = h.world_six
	a = f.bridge.record(0); b = f.bridge.record(1)
	var hazard: Dictionary = w.hazards.filter(func(e): return e.kind == "box")[0]
	for player in [a,b]: player.p = Vector2(hazard.x, w.ride.row[2])
	w._ride_tick(h)
	check(hazard.hit_slots.size() == 2 and a.hearts == 2 and b.hearts == 2, "ride box has per-actor hit set, harms both")
	check(a.velocity.x == -300 and b.velocity.x == -300, "ride kick applies to both victim records")
	for player in [a,b]: player.invincible = 0
	w._ride_tick(h)
	check(h.hits == [0,1], "already hit actor cannot consume ride hazard twice")
	finish(f)
	f = fresh(); h = f.host; w = h.world_six
	a = f.bridge.record(0); b = f.bridge.record(1)
	for player in [a,b]: player.p = Vector2(400, 482)
	w.fees = [{"x":400.0,"y":400.0,"vy":0.0,"t":1.0,"warn":0.7,"r":16.0}]
	w._fees_tick(0,h)
	check(a.hearts == 2 and b.hearts == 2 and w.fees.is_empty(), "one falling fee hits every overlapping actor then is removed once")
	finish(f)
func _targeting_and_loot() -> void:
	var f := fresh(); var h = f.host
	var a: Dictionary = f.bridge.record(0); var b: Dictionary = f.bridge.record(1)
	a.p = Vector2(200,482); b.p = Vector2(600,482)
	check(h.combat._nearest(h,400).slot == 0, "nearest target ties preserve source roster order")
	var enemy := bot(h,550,3)
	h.combat.enemies_tick(0.1,h)
	check(enemy.p.x > 550 and enemy.face == 1, "ordinary bot chases nearer P2")
	h.enemies.clear()
	h.bullets = [{"p":Vector2(600,400),"v":Vector2.ZERO,"gravity":0.0,"enemy":true,"life":20.0}]
	h.combat.projectiles_tick(0,h)
	check(b.hearts == 2 and a.hearts == 3 and h.hits == [1], "hostile shot damages actual P2, restores P1 facade")
	b.invincible = 0
	h.bullets = [{"p":Vector2(600,400),"v":Vector2.ZERO,"gravity":0.0,"enemy":true,"life":20.0}]
	h.combat.projectiles_tick(0,h)
	check(b.hearts == 2 and b.invincible == 0.9 and f.party.actors[1].abilities._hits == 2, "P2 Maya second hit uses her own passive")
	h.coins = [{"p":Vector2(600,420),"v":Vector2.ZERO,"rest":true,"age":1.0}]
	h.items = [{"p":Vector2(600,400),"vy":0.0,"rest":true,"age":1.0,"give":"split"}]
	h.combat.pickups_tick(0,h)
	check(h.score == 1 and b.coins == 1 and a.coins == 0, "shared kitty once, exact P2 coin credit")
	check(b.power == "split" and b.power_time == 12 and a.power == "", "pickup gives weapon only to actual collector")
	b.p.y = 200
	h.combat.spawn_flier(h,"r")
	check(is_equal_approx(h.world_six.fliers[-1].p.y, maxf(h.view_top()+80,-100)), "flyer spawn uses highest living floor")
	var flyer: Dictionary = h.world_six.fliers[-1]
	flyer.p = Vector2(550,230); flyer.off = 0; flyer.entered = true; flyer.cd = 0
	h.combat.fliers_tick(0.1,h)
	check(flyer.p.x > 550 and flyer.face == 1, "mailer follows nearer P2")
	check(h.bullets[-1].enemy and h.bullets[-1].v.x > 0, "mailer aims projectile at P2")
	finish(f)
func _owners_and_debits() -> void:
	var f := fresh(); var h = f.host
	var a: Dictionary = f.bridge.record(0); var b: Dictionary = f.bridge.record(1)
	a.p = Vector2(200,482); b.p = Vector2(600,482)
	var enemy := bot(h,630)
	h.bullets = [shot(Vector2(630,400))]
	h.combat.projectiles_tick(0,h)
	check(enemy.state == "pop" and b.pop_count == 1 and a.pop_count == 0, "ordinary shot kill credits exact firing P2")
	check(h.coins.size() >= 4 and h.coins.size() <= 6, "ordinary kill drops source 4-6 coins once")
	h.enemies.clear(); h.coins.clear()
	enemy = bot(h,630)
	var unowned := shot(Vector2(630,400)); unowned.erase("owner_slot")
	h.bullets = [unowned]
	h.combat.projectiles_tick(0,h)
	check(enemy.state == "pop" and b.pop_count == 1 and a.pop_count == 0, "unowned party shot damages without false active-actor credit")
	h.enemies.clear()
	b.p.x = 600; b.down = true; b.hearts = 0
	enemy = bot(h,630)
	var sweep := shot(Vector2(700,400)); sweep.first_frame = true; sweep.owner_x = 1000
	h.bullets = [sweep]
	h.combat.projectiles_tick(0,h)
	check(enemy.state == "pop" and b.pop_count == 2, "first-frame sweep reads current downed owner, not stale spawn x")
	h.enemies.clear(); b.down = false; b.hearts = 3
	h.combat.spawn_flier(h,"r")
	var flyer: Dictionary = h.world_six.fliers[-1]; flyer.p = Vector2(630,300); flyer.hp = 1
	h.bullets = [shot(flyer.p)]
	h.combat.projectiles_tick(0,h)
	check(flyer.state == "pop" and b.pop_count == 3 and a.pop_count == 0, "mailer kill credits firing owner")
	finish(f)
	f = fresh(); h = f.host
	a = f.bridge.record(0); b = f.bridge.record(1)
	a.p = Vector2(200,482); b.p = Vector2(600,482); a.coins = 3; b.coins = 2; h.score = 5
	var first := bot(h,200,2); first.type = "debit"
	var second := bot(h,600,2); second.type = "debit"
	var duplicate := bot(h,600,2); duplicate.type = "debit"
	h.combat.debits_tick(0,h)
	check(first.latch_slot == 0 and second.latch_slot == 1 and not duplicate.get("latch",false), "each actor gets at most one independently owned debit")
	h.combat.debits_tick(0.66,h)
	check(a.coins == 2 and b.coins == 1 and h.score == 3, "debits drain own victim contributions and shared kitty once each")
	a.down = true; a.hearts = 0
	b.grounded = false
	h.combat.debits_tick(0,h)
	check(not first.latch and second.latch and second.jumps == 1, "downed victim releases only own debit, P2 first jump counted")
	b.grounded = true; h.combat.debits_tick(0,h)
	b.grounded = false; h.combat.debits_tick(0,h)
	check(not second.latch and second.has("hop") and second.cool == 1.5, "P2 second jump releases own debit with source hop/cooldown")
	check(not second.has("latch_slot"), "released debit discards stale slot identity")
	finish(f)
func _bosses() -> void:
	var f := fresh(); var h = f.host
	var a: Dictionary = f.bridge.record(0); var b: Dictionary = f.bridge.record(1)
	h.combat.start_mini(h,"franker")
	var mini: Dictionary = h.world_six.mini_boss
	check(mini.hp == 60 and mini.max == 60, "pair mini has source 60 HP")
	mini.state = "fight"; mini.x = 630; mini.hp = 1
	h.bullets = [shot(Vector2(630,400))]
	h.combat.projectiles_tick(0,h)
	check(mini.state == "down" and b.pop_count == 5 and a.pop_count == 0, "mini defeat credits source five pops to exact firing owner")
	check(h.coins.size() == 18, "mini shared payout is 18 coins once")
	finish(f)
	f = fresh(); h = f.host
	a = f.bridge.record(0); b = f.bridge.record(1)
	a.p = Vector2(200,482); b.p = Vector2(600,482)
	h.combat.start_mini(h,"franker"); mini = h.world_six.mini_boss
	mini.state = "fight"; mini.x = 650; mini.cd = 0
	h.combat.mini_tick(0,h)
	check(h.bullets.size() == 3 and h.bullets[1].v.x == -50, "franker volley aims at nearest P2")
	check(a.hearts == 3 and b.hearts == 2 and b.velocity.x == -500, "mini body harms actual P2 and applies source shove")
	finish(f)
	f = fresh("6-6"); h = f.host
	a = f.bridge.record(0); b = f.bridge.record(1)
	h.camera.x = h.level.w - h.view_width()
	for wave in h.combat.waves: wave.done = true
	h.world_six.world_tick(0,h)
	check(h.boss != null and h.boss.state.hp == 150, "Sir Charge spawned using source pair 150 HP")
	var state: Dictionary = h.boss.state
	state.state = "fight"; state.x = h.camera.x + 400; state.act = "volley"
	a.p = Vector2(state.x - 300,482); b.p = Vector2(state.x + 100,482)
	h.bullets.clear(); h.boss.attack(h)
	check(h.bullets.size() == 3 and h.bullets[1].v.x == 100, "Sir Charge volley aims at nearest P2")
	state.dizzy = 1.0
	h.bullets = [shot(Vector2(state.x,300),1,99)]
	h.combat.projectiles_tick(0,h)
	check(state.hp == 148 and b.boss_hits == 1 and not a.has("boss_hits"), "Sir Charge ignores shot dmg, doubles dizzy, records actual owner hit")
	check(is_finite(state.fy) and state.fy == 482, "native finite fy compatibility alias preserved")
	state.waves = [{"x":b.p.x,"vx":0.0,"t":0.0}]
	h.boss.boss_tick(0,h,h.world_six)
	check(b.hearts == 2 and a.hearts == 3, "boss shockwave harms actual P2")
	state.state = "down"; state.jar = {"x":b.p.x,"y":452.0,"vx":0.0,"vy":0.0,"t":0.7,"got":false}
	a.down = true; a.hearts = 0
	check(h.boss.jar_tick(0,h) == "clear" and state.jar.got, "living P2 collects final jar while leader is down")
	finish(f)

func _hold_checkpoint_and_storm() -> void:
	var f := fresh("6-2"); var h = f.host; var w = h.world_six
	var a: Dictionary = f.bridge.record(0); var b: Dictionary = f.bridge.record(1)
	h.camera.x = h.level.w - h.view_width()
	for wave in h.combat.waves: wave.done = true
	w._hold_tick(0.1,h)
	check(w.hold.on and is_equal_approx(w.hold.t,0.1), "pair hold starts one shared clock")
	check(is_equal_approx(w.hold.spawn_t,2.1-0.1/60), "pair hold uses source 2.1s initial spawn pace")
	h.enemies.clear();w.fliers.clear();w.hold.spawn_t=0
	for i in 7: bot(h,h.camera.x+60,3)
	w._hold_tick(0,h)
	check(h.enemies.size()==7 and w.fliers.is_empty() and w.hold.spawn_t==0,"pair hold respects source seven-live cap")
	h.enemies[0].p=Vector2(h.level.hold.door,482)
	w.hold.t=20
	for i in range(1,h.enemies.size()): h.enemies[i].p.x=h.camera.x+60
	w._hold_tick(0,h)
	check(w.hold.jams==1 and w.hold.t==15 and a.pop_count==0 and b.pop_count==0,"jam subtracts five seconds without player pop credit")
	w.hold.t=w.hold.secs
	w._hold_tick(0,h)
	check(w.hold.done and not w.hold.on and h.enemies.all(func(e):return e.state=="pop"),"hold finish cleans threats once")
	check(a.pop_count==0 and b.pop_count==0,"hold cleanup is intentionally unowned")
	finish(f)
	f=fresh("6-5");h=f.host;w=h.world_six
	a=f.bridge.record(0);b=f.bridge.record(1)
	a.down=true;a.hearts=0;b.hearts=1
	h.camera.x=h.level.cp
	w.world_tick(0,h)
	check(w.checkpoint_done and a.down and a.hearts==0 and b.hearts==2,"ordinary checkpoint only heals living actors")
	finish(f)
	f=fresh("6-6");h=f.host;w=h.world_six
	a=f.bridge.record(0);b=f.bridge.record(1)
	h.camera.x=h.level.w-h.view_width()
	h.boss=Charge.new();h.boss.reset(h.level.w,h.view_width(),482,2,61)
	var state:Dictionary=h.boss.state
	state.state="fight";state.x=h.camera.x+400;state.hp=70;state.mail_t=100
	a.p=Vector2(h.camera.x+110,482);b.p=Vector2(h.camera.x+620,482)
	var left_seen:=false;var right_seen:=false
	for i in 30:
		state.fee_t=0
		h.boss.boss_tick(0,h,w)
		if w.fees[-1].x<h.camera.x+350:left_seen=true
		else:right_seen=true
	check(left_seen and right_seen,"fee storm randomly targets both living actors, not just nearest")
	check(state.fee_t==0.52,"pair fee storm uses source 520ms pace")
	state.hp=40;state.phase=3;state.act="charge";state.vx=550;state.rock_t=100
	a.p=Vector2(state.x-10,482);b.p=Vector2(state.x+10,482)
	h.boss.boss_tick(0,h,w)
	check(a.hearts==2 and b.hearts==2 and h.hits==[0,1],"boss charge body damages all overlapping victims")
	check(a.velocity.x==495 and b.velocity.x==495,"boss charge applies source knockback to both actual victims")
	finish(f)
