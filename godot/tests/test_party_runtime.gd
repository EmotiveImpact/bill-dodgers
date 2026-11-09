extends SceneTree
const Party = preload("res://src/party_runtime.gd")
const Actor = preload("res://src/party_actor.gd")
class Host:
	extends "res://src/party_actor.gd"
	var elapsed := 7.0
	var score := 91
	var camera := Vector2(300, -200)
	var bullets: Array = [{"owner_slot": 0}]
	var world_timer := 4.5
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void:
	var party = Party.new()
	check(not party.configure("unknown", "jp", "maya"), "reject unknown mode")
	check(not party.configure("cpu", "jp", "jp"), "distinct source mate required")
	check(not party.configure("cpu", "not-a-character", "maya"), "reject invalid housemate")
	check(party.mode == "solo", "invalid selection is atomic")
	check(party.configure("cpu", "jp", "maya"), "CPU selection accepted")
	party.start("2-2", Vector2(180, 482), ["slide"])
	var first = party.actors[0]
	var second = party.actors[1]
	check(party.actors.size() == 2 and second.cpu and not first.cpu, "source computer roster")
	check(first.player == Vector2(180, 482) and second.player == Vector2(100, 482), "source eighty pixel spawn offset")
	check(second.abilities != first.abilities and second.movement_skills != first.movement_skills, "abilities and skill state independent")
	first.abilities.meter = 0.9
	first.movement_skills.dash_remaining = 0.2
	first.scene_state.carrying_crate = true
	check(second.abilities.meter == 0.5 and second.movement_skills.dash_remaining == 0 and second.scene_state.is_empty(), "no mutable actor-state sharing")
	check(first.movement_skills.skills == ["slide"] and second.movement_skills.skills == ["slide"], "only earned skills propagate at start")
	party.grant_skill("dash")
	party.grant_skill("unknown")
	check(first.movement_skills.skills == ["slide", "dash"] and second.abilities.skills == ["slide", "dash"], "actual shared card grants both actors without invented skills")
	check(party.participants()[1].slot == 1 and party.participants()[1].height == 162, "boss participant retains identity and character height")
	var host = Host.new()
	var old_abilities = host.abilities
	first.apply_native(host)
	host.player += Vector2(25, -10)
	host.hearts = 2
	host.cooldown = 0.21
	first.capture_native(host)
	second.apply_native(host)
	check(first.player == Vector2(205, 472) and first.hearts == 2 and second.hearts == 3, "actor swap saves movement and health independently")
	check(host.elapsed == 7 and host.score == 91 and host.camera == Vector2(300, -200) and host.bullets.size() == 1 and host.world_timer == 4.5, "swap never rewinds or duplicates shared world state")
	check(host.abilities == second.abilities and host.abilities != old_abilities, "swap uses actor ability instance")
	first.player = Vector2(300, 482)
	second.player = Vector2(900, 482)
	check(party.camera_actors() == [first], "CPU never drives human camera")
	check(party.nearest_actor(850) == second, "enemy targeting can choose second actor")
	party.record_pop(1, 2)
	party.record_coin(1, 7)
	check(first.pop_count == 0 and second.pop_count == 2 and second.coins == 7 and first.coins == 0, "attribution identifies the actual player")
	first.mark_down()
	check(not party.all_down() and party.living_participants().size() == 1, "one down is not game over")
	check(party.camera_actors() == [first], "downed human stays in camera rescue roster")
	check(party.nearest_actor(300) == second, "downed actor is excluded from enemy target query")
	second.player = Vector2(330, 482)
	check(party.tick_revives(1.4).is_empty() and first.down, "source revive uses strictly more than 1.4 seconds")
	second.player.x = 500
	party.tick_revives(0.4)
	check(is_equal_approx(first.revive, 1.2), "rescue decays at half speed when helper moves away")
	second.player.x = 330
	party.tick_revives(1, false)
	check(is_equal_approx(first.revive, 1.2), "paused rescue does not tick")
	var events: Array = party.tick_revives(0.21)
	check(events.size() == 1 and events[0].slot == 0 and events[0].helper_slot == 1, "revive event has actor identities")
	check(first.hearts == 2 and first.invincible == 2.2 and first.hurt_lock == 0.6 and first.player_animation == "win", "source revive health protection and celebration lock")
	first.mark_down()
	first.revive = 0.5
	second.player = first.player + Vector2(80, 0)
	party.tick_revive_actor(first, 0.2)
	check(is_equal_approx(first.revive, 0.4), "exact eighty pixel revive boundary is outside")
	second.player = first.player + Vector2(79, 70)
	party.tick_revive_actor(first, 0.2)
	check(is_equal_approx(first.revive, 0.3), "exact seventy pixel vertical revive boundary is outside")
	second.player = first.player + Vector2(79, 69)
	party.tick_revive_actor(first, 0.2)
	check(is_equal_approx(first.revive, 0.5), "actor-position revive sees only current helper location")
	second.player.x += 10
	check(is_equal_approx(first.revive, 0.5), "later helper movement does not retroactively change prior revive phase")
	var other_revival: float = second.revive
	party.tick_revive_actor(first, 0.2, false)
	check(is_equal_approx(first.revive, 0.5) and second.revive == other_revival, "single-actor paused revive changes neither actor")
	first.mark_down()
	second.mark_down()
	check(party.all_down(), "only all-down ends the encounter")
	var location: Vector2 = second.player
	party.continue_in_place()
	check(not party.all_down() and second.player == location and second.coins == 7 and second.abilities.meter == 0.5, "continue preserves location earnings ability charge and encounter")
	check(first.hearts == 3 and second.hearts == 3 and first.invincible == 2.5, "source full-party continue")
	first.mark_down()
	party.settle_clear()
	check(first.hearts == 1 and not first.down and second.hearts == 3, "clear rescues downed mate with one heart")
	check(party.plate_hold_seconds() == 5.2, "CPU gets long source shelf hold")
	party.configure("p2", "ama", "leo")
	party.start("1-1", Vector2(100, 482))
	first = party.actors[0]
	second = party.actors[1]
	check(not second.cpu and party.plate_hold_seconds() == 2.6, "two humans use source short shelf hold")
	first.player.x = 600
	second.player.x = 900
	check(party.camera_actors().size() == 2 and party.camera_follow_x(100, 700, 2000) == 540, "camera is front follow capped by back actor")
	check(party.camera_follow_x(100, 700, 2000, 200) == 200, "party camera respects wave lock")
	second.player.y = 200
	check(party.camera_follow_y(482, 540 / 1.3) < 0, "vertical camera considers both humans")
	second.out = true
	check(party.camera_actors() == [first], "out actor is excluded")
	check(party.configure("solo", "mei"), "solo needs no mate")
	party.start("6-4", Vector2.ZERO)
	check(party.actors.size() == 1 and party.actors[0].character == "mei" and party.actors[0].abilities.meter == 0.5, "fresh solo roster resets old actors")
	print("Party lifecycle: %d checks, %d failures. Module tests, not integrated co-op/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
