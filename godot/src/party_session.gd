extends RefCounted
## Host integration is deliberately gated while each world's shared phase is
## validated. No menu advertises an unsupported mode. This never steps main twice.
const Runtime = preload("res://src/party_runtime.gd")
const CombatBridge = preload("res://src/party_combat.gd")
const InputRouter = preload("res://src/party_input.gd")
const AI = preload("res://src/companion_ai.gd")
const Context = preload("res://src/companion_context.gd")
const INTEGRATING_LEVELS := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-S", "2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S", "3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S", "4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S", "5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S", "6-1", "6-2", "6-3", "6-4", "6-5", "6-6", "6-S"]
var runtime = Runtime.new()
var bridge = CombatBridge.new()
var input = InputRouter.new()
var ai = AI.new()
var active := false
var active_slot := 0
var _host: WeakRef

func configure(host, selected_mode: String, mate: String) -> bool:
	if host.mode not in ["menu", "clear"] or not runtime.configure(selected_mode, host.character, mate): return false
	_host = weakref(host)
	active = false
	return true

func start(host) -> void:
	active = runtime.mode != "solo" and host.level_id in INTEGRATING_LEVELS
	if not active: return
	_host = weakref(host)
	runtime.p1 = host.character
	# A later hero selection may invalidate the mate, never silently duplicate.
	if runtime.p1 == runtime.p2:
		active = false
		return
	runtime.start(host.level_id, host.player, host.save.get("skills", []))
	for actor in runtime.actors:
		actor.player.y = host.floor_at(actor.player.x, host.player.y - 10)
		actor.checkpoint = actor.player
		actor._last_floor = actor.player.y
		actor.scene_state.safe_position = actor.player
	active_slot = 0
	runtime.actors[0].apply_native(host)
	host.scene_runtime.safe_position = runtime.actors[0].player
	bridge.configure(runtime, host)
	input.release_all()

func capture(host) -> void:
	var actor = runtime.actor_at(active_slot)
	if actor == null: return
	actor.capture_native(host)
	host.party_capture_scene(actor)

func bind(host, slot: int) -> void:
	active_slot = slot
	bridge.active_slot = slot
	var actor = runtime.actor_at(slot)
	actor.apply_native(host)
	host.party_apply_scene(actor)

func step(host, delta: float, first: Dictionary, second: Dictionary = {}) -> void:
	if not active or host.mode != "play": return
	host.player_hud.notifications.step(delta)
	host._defer_knockout = true
	host._step_delta = delta
	host.elapsed += delta
	capture(host)
	var world: int = int(host.level_id.get_slice("-", 0))
	if world in [4, 6]:
		bridge.begin_shared(active_slot)
		if world == 4: host.world_four.pre_motion(delta, host)
		else: host.world_six.pre_motion(delta, host)
		bridge.end_shared(0)
		active_slot = 0
	# Source gathers every CPU intent before updating any player's movement.
	# Do not let P2 react to a future P1 position from this same frame.
	var inputs := {0: first, 1: second}
	for actor in runtime.actors:
		if actor.cpu and actor.is_alive(): inputs[actor.slot] = ai.controls(delta, actor, Context.build(host, runtime, actor))
	for actor in runtime.actors:
		if not actor.is_alive():
			# Source timer prelude runs even for a downed actor, then returns
			# before movement/skills. Revive sees earlier actors' new positions
			# and later actors' old positions, exactly like updatePlayer order.
			actor.invincible = maxf(0, actor.invincible - delta)
			actor.power_time = maxf(0, actor.power_time - delta)
			if actor.power_time == 0: actor.power = ""
			var revived: Dictionary = runtime.tick_revive_actor(actor, delta)
			if not revived.is_empty():
				host.sfx("revive")
				host.fx_float("Back up!", actor.player - Vector2(0, actor.character_height() + 20), Color("9fe0b8"))
			continue
		var controls: Dictionary = inputs[actor.slot]
		bind(host, actor.slot)
		host._pre_grounded = host.grounded
		host._actor_step(delta, controls)
		capture(host)
	var living: Array = runtime.living_actors()
	# A living mate can finish the objective while P1 is down. All-down is checked
	# after scene/boss completion, never inside another actor's damage callback.
	var representative: int = living[0].slot if not living.is_empty() else 0
	bind(host, representative)
	bridge.begin_shared(representative)
	if world == 5:
		for receipt in host.receipts: receipt.age += delta
		host.world_five.before_camera(delta, host, inputs)
	if not living.is_empty() or (world == 3 and float(host.level.get("auto", 0)) > 0): host._update_camera(delta)
	if world == 1: host.world_one.after_camera(delta, host)
	elif world == 3: host.world_three.after_camera(delta, host)
	if world == 1:
		host.combat.tick(delta, host)
	else:
		host.combat.waves_tick(delta, host)
		host.scene_objective(delta)
		if world == 4:
			for receipt in host.receipts: receipt.age += delta
			host.world_four.before_combat(delta, host)
		if world == 6: host.world_six.world_tick(delta, host)
		if host.mode == "play" or world in [3, 4, 5, 6]:
			host.combat.enemies_tick(delta, host)
			host.combat_bubbles_tick(delta)
			host.combat.projectiles_tick(delta, host)
			host.combat.pickups_tick(delta, host)
	if host.mode == "play" or world in [3, 4, 5, 6]:
		if world == 1:
			host.world_one.crumble_step(delta, host)
			host.combat.bob_flyers(delta, host)
			host.world_one.chimney_step(host)
			host.combat.bailiff_volleys(delta, host)
			for actor in runtime.living_actors(): bridge.call_for_actor(actor.slot, host.collect_level_pickups)
		elif world == 2:
			for receipt in host.receipts: receipt.age += delta
			host.world_two.after_pickups(delta, host)
		elif world == 3: host.world_three.after_pickups(delta, host)
		if world != 4:
			for actor in runtime.living_actors(): bridge.call_for_actor(actor.slot, Callable(self, "_late_skill"), [host])
		if world == 1:
			host.world_one.after_pickups(host)
			host.bus_ride.tick(delta, host)
			if host.boss != null:
				# Reconcile damage/pickups before constructing boss targets.
				for actor in runtime.actors: bridge.reconcile(actor.slot)
				var events: Array = host.boss.tick(delta, runtime.participants(), host.bullets, host.view_top(), host.mode == "play") if host.level_id == "1-6" else host.boss.tick(delta, runtime.participants())
				for event in events: host._boss_event(event)
		elif world == 3:
			if host.combat.boss_tick(delta, host) == "mini_done": host.world_three.mini_done = true
			if host.combat.jar_tick(delta, host) == "clear": host._complete_level()
			host.combat.visuals_tick(delta, host)
			if host.level_id == "3-6": host.world_three.finale.sync_visuals(host, host.world_three)
		elif world == 4:
			host.world_four.boss_tick(delta, host)
			if host.world_four.jar_tick(delta, host) == "clear": host._complete_level()
			host.combat.visuals_tick(delta, host)
		elif world == 5:
			host.combat.boss_tick(delta, host)
			if host.combat.jar_tick(delta, host) == "clear": host._complete_level()
			host.combat.visuals_tick(delta, host)
		elif world == 6:
			host.world_six.boss_tick(delta, host)
			if host.world_six.jar_tick(delta, host) == "clear": host._complete_level()
			host.combat.visuals_tick(delta, host)
	# Reconcile all proxy hits before source all-down, but keep the shared phase
	# open so post-base abilities and delayed scene relocation retain ownership.
	bridge.call_for_actor(bridge.active_slot, Callable(self, "_no_op"))
	for actor in runtime.actors: bridge.reconcile(actor.slot)
	if host.mode == "play" and runtime.all_down(): host._game_over()
	for actor in runtime.actors: bridge.call_for_actor(actor.slot, Callable(self, "_effects"), [host, delta])
	host.visual_feedback.tick(delta)
	host._expire_ability_zaps(delta)
	if world == 2: host.world_two.finish_frame(host)
	elif world == 3: host.world_three.finish_frame(host)
	elif world == 4: host.world_four.finish_frame(host)
	elif world == 5: host.world_five.finish_frame(host)
	elif world == 6: host.world_six.finish_frame(host)
	bridge.end_shared(0)
	active_slot = 0
	host.party_apply_scene(runtime.actors[0])
	host._defer_knockout = false

func _no_op() -> void: pass

func _late_skill(host) -> void:
	if host.hearts > 0: host.movement_skills.late_step(host, host.player_animation, host.actor_is_cpu())
	for event in host.movement_skills.events:
		if event in ["double-jump", "wall-jump"]: host.sfx("jump")
		elif event == "ground-pound-land": host.sfx("stomp")
		elif event.begins_with("card:"): host.sfx("power")

func _effects(host, delta: float) -> void:
	host.abilities.effects_tick(delta, host)

func bubbles_tick(host, delta: float) -> void:
	# Bubble state lives on enemies, so this clock advances once for the whole
	# party. Duplicate characters are forbidden, so the unique Ama owns pops.
	var owner := active_slot
	for actor in runtime.actors:
		if actor.character == "ama": owner = actor.slot; break
	bridge.call_for_actor(owner, Callable(self, "_bubbles"), [host, delta])

func _bubbles(host, delta: float) -> void:
	host.abilities.bubbles_tick(delta, host)

func continue_in_place(host) -> void:
	runtime.continue_in_place()
	bind(host, 0)
	bridge.configure(runtime, host)
	input.release_all()

func settle_coins(host) -> void:
	# Source sweep chooses nearest living actor before stage-clear revival.
	# Kitty is still incremented once by main; this is personal attribution only.
	capture(host)
	if bridge.shared_phase:
		for actor in runtime.actors: bridge.reconcile(actor.slot)
	for coin in host.coins:
		var owner = runtime.nearest_actor(float(coin.p.x))
		if owner == null: owner = runtime.actors[0]
		if bridge.shared_phase: bridge.credit_coin(owner.slot)
		else: runtime.record_coin(owner.slot)

func settle_clear(host) -> void:
	capture(host)
	if bridge.shared_phase:
		for actor in runtime.actors: bridge.reconcile(actor.slot)
	runtime.settle_clear()
	# Publish celebration state before the remaining final-frame proxy merge.
	for actor in runtime.actors: bridge._publish(actor)
	bind(host, active_slot)
