extends RefCounted
## Source co-op lifecycle and queries; deliberately owns no world simulation.
const Actor = preload("res://src/party_actor.gd")
const CHARACTERS := ["jp", "maya", "ama", "leo", "theo", "mei"]
const MODES := ["cpu", "p2", "solo"]
const MODE_LABELS := {"cpu": "Mate: computer", "p2": "Mate: player 2 (keys)", "solo": "No mate, solo"}
var mode := "solo" # Preserve native solo until explicitly configured by selection.
var p1 := "jp"
var p2 := "maya"
var actors: Array = []

func configure(selected_mode: String, first: String, second: String = "") -> bool:
	if selected_mode not in MODES or first not in CHARACTERS: return false
	if selected_mode != "solo" and (second not in CHARACTERS or second == first): return false
	mode = selected_mode
	p1 = first
	p2 = second
	return true

func start(level_id: String, spawn_feet: Vector2, skills: Array = []) -> void:
	actors.clear()
	var count := 1 if mode == "solo" else 2
	for index in count:
		var actor = Actor.new()
		actor.initialize(p1 if index == 0 else p2, index, index == 1 and mode == "cpu", spawn_feet - Vector2(index * 80, 0), level_id, skills)
		actors.append(actor)

func actor_at(slot: int):
	for actor in actors:
		if actor.slot == slot: return actor
	return null

func living_actors() -> Array:
	return actors.filter(func(actor): return actor.is_alive())

func participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in actors: result.append(actor.participant())
	return result

func living_participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in living_actors(): result.append(actor.participant())
	return result

func nearest_actor(x: float):
	var nearest = null
	var distance := INF
	for actor in living_actors():
		var candidate := absf(actor.player.x - x)
		if candidate < distance:
			nearest = actor
			distance = candidate
	return nearest

func camera_actors() -> Array:
	# Source deliberately includes a knocked-down human to keep rescue visible.
	# A CPU never drags the camera away from the human they are helping.
	var humans := actors.filter(func(actor): return not actor.cpu and not actor.remote and not actor.out)
	return humans if not humans.is_empty() else living_actors()

func camera_follow_x(current: float, width: float, world_width: float, camera_lock: Variant = null) -> float:
	var roster := camera_actors()
	if roster.is_empty() or living_actors().is_empty(): return current
	var front := -INF
	var back := INF
	for actor in roster:
		front = maxf(front, actor.player.x)
		back = minf(back, actor.player.x)
	var wanted := maxf(current, minf(front - width * 0.45, back - 60))
	if camera_lock != null: wanted = minf(wanted, float(camera_lock))
	return minf(world_width - width, wanted)

func camera_follow_y(ground: float, visible_height: float) -> float:
	var roster := camera_actors()
	if roster.is_empty(): return 0
	var hi := INF
	var lo := -INF
	for actor in roster:
		if actor.grounded or actor.player.y > actor._last_floor: actor._last_floor = actor.player.y
		var feet := minf(actor._last_floor, actor.player.y + 170)
		hi = minf(hi, feet)
		lo = maxf(lo, feet)
	var wanted := (hi + lo) / 2 - ground + 30
	wanted = maxf(wanted, lo - ground - 10 - (visible_height - 200))
	wanted = minf(wanted, hi - ground + 40)
	return minf(wanted, 0)

func tick_revive_actor(actor, delta: float, playing := true) -> Dictionary:
	# Called at this actor's source update position, before its downed return.
	# The caller does not revisit an actor knocked down later in the same frame.
	if not playing or actor == null or actor not in actors: return {}
	if actor.hearts <= 0 and not actor.down: actor.mark_down()
	if not actor.down: return {}
	actor.velocity.y = 0
	var helper = null
	for other in living_actors():
		if other != actor and absf(other.player.x - actor.player.x) < 80 and absf(other.player.y - actor.player.y) < 70:
			helper = other
			break
	if helper != null:
		actor.revive += delta
		if actor.revive > 1.4:
			actor.revive_nearby()
			return {"kind": "revived", "slot": actor.slot, "helper_slot": helper.slot, "position": actor.player}
	else: actor.revive = maxf(0, actor.revive - delta * 0.5)
	return {}

func tick_revives(delta: float, playing := true) -> Array[Dictionary]:
	# Convenience for isolated lifecycle fixtures; integrated actor motion calls
	# tick_revive_actor in roster order rather than a blanket late-frame pass.
	var events: Array[Dictionary] = []
	for actor in actors:
		var event := tick_revive_actor(actor, delta, playing)
		if not event.is_empty(): events.append(event)
	return events

func all_down() -> bool:
	return not actors.is_empty() and living_actors().is_empty()

func continue_in_place() -> void:
	for actor in actors: actor.continue_in_place()

func settle_clear() -> void:
	for actor in actors:
		if actor.down or actor.hearts <= 0:
			actor.down = false
			actor.hearts = 1
		actor.player_animation = "win"
		actor.animation_time = 0

func record_coin(slot: int, count := 1) -> void:
	# The caller increments shared kitty once. Receipts are not player coins.
	var actor = actor_at(slot)
	if actor != null: actor.coins += maxi(0, count)

func record_pop(slot: int, count := 1) -> void:
	var actor = actor_at(slot)
	if actor != null: actor.pop_count += maxi(0, count)

func grant_skill(skill: String) -> void:
	if skill not in Actor.MovementSkills.ALL: return
	for actor in actors:
		if skill not in actor.movement_skills.skills: actor.movement_skills.skills.append(skill)
		if skill not in actor.abilities.skills: actor.abilities.skills.append(skill)

func plate_hold_seconds() -> float:
	return 2.6 if mode == "p2" and actors.size() > 1 else 5.2
