extends SceneTree
## Source-derived HUD geometry/state + actual integrated CanvasItem callbacks.
## Headless passes do not substitute for native rendered screenshot inspection.
const HUD = preload("res://src/player_hud.gd")
const Menu = preload("res://src/mobile_game_menu.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c): return c.tag == tag)
func run() -> void:
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/1-1/index.html"))
	for snippet in ["g.fillRect(0, 0, VW, 66)", "const w = 150, h = 8, y = 54", "sp ? a.spT / a.spT0 : a.m", "Math.min(1, kitty / 120)", "hd.x, hd.y, src, src", "'P1 '"]:
		check(source.contains(snippet), "original source HUD contract: " + snippet)
	var game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	Support.silence(game)
	game.set_physics_process(false)
	check(not game.player_hud.is_game_visible(game), "no active player HUD on menu")
	game.load_level("1-1", false)
	game.safe_padding = Vector2(12, 14)
	game._layout_game_hud()
	var commands: Array = game.player_hud.build_commands(game)
	check(tagged(commands, "hud_back")[0].rect == Rect2(0, 0, 960, 66), "original screen-space header height")
	check(tagged(commands, "portrait")[0].source == Rect2(48, 57, 54, 54), "JP original idle face crop")
	check(tagged(commands, "portrait")[0].rect == Rect2(14, 8, 50, 50), "portrait has original 2px frame inset")
	check(tagged(commands, "special_fill")[0].rect == Rect2(76, 54, 75, 8), "initial half-charged150x8 special meter")
	check(tagged(commands, "kitty_fill").is_empty(), "zero kitty has no false filled bar")
	for i in 3:
		check(tagged(commands, "heart_%d" % i).size() == 27, "original27-pixel heart%d" % i)
		check(tagged(commands, "heart_%d" % i).any(func(c): return c.colour == Color("ffb3b3")), "heart highlight%d" % i)
	var before := var_to_str([game.hearts, game.score, game.abilities.meter, game.abilities.remaining, game.receipts])
	game.camera = Vector2(1000, -400)
	check(var_to_str(commands) == var_to_str(game.player_hud.build_commands(game)), "HUD does not move or zoom with world camera")
	check(before == var_to_str([game.hearts, game.score, game.abilities.meter, game.abilities.remaining, game.receipts]), "render planning is read-only")
	game.invincible = 0; game.hurt_player(game.player.x + 60)
	commands = game.player_hud.build_commands(game)
	check(game.hearts == 2 and tagged(commands, "heart_2").all(func(c): return c.colour == Color("3a4458")), "actual damage dims one heart")
	game.hearts = 0
	commands = game.player_hud.build_commands(game)
	check(tagged(commands, "heart_0").all(func(c): return c.colour == Color("3a4458")), "zero health dims hearts")
	game.hearts = 3; game.score = 65; game.receipt_score = 5
	commands = game.player_hud.build_commands(game)
	check(tagged(commands, "player_coins")[0].text == "x60" and tagged(commands, "kitty_label")[0].text == "Kitty £65", "collected coins differ from receipt kitty rewards")
	check(is_equal_approx(tagged(commands, "kitty_fill")[0].rect.size.x, 156.0 * 65 / 120), "kitty120-point meter source proportion")
	game.score = 150
	check(game.player_hud.build_commands(game).filter(func(c): return c.tag == "kitty_fill")[0].rect.size.x == 156, "kitty bar clamps above120")
	for who in HUD.NAMES:
		game.character = who; game.abilities.reset(who)
		var spec: Dictionary = HUD.Abilities.SPEC[who]
		game.abilities.meter = 1
		commands = game.player_hud.build_commands(game)
		check(tagged(commands, "portrait")[0].texture == game.sheets[who], "%s original portrait texture" % who)
		check(tagged(commands, "special_fill")[0].rect.size.x == 150 and tagged(commands, "special_fill")[0].colour == Color(spec.color), "%s full character-coloured meter" % who)
		check(HUD.special_state(game).ready and tagged(commands, "special_label")[0].text in ["C", "TAP"], "%s ready key" % who)
		game.abilities.active = who; game.abilities.duration = spec.duration; game.abilities.remaining = spec.duration / 2; game.abilities.meter = 0
		commands = game.player_hud.build_commands(game)
		check(tagged(commands, "special_fill")[0].rect.size.x == 75, "%s active remaining-time meter instead of empty charge" % who)
		check(not HUD.special_state(game).ready and tagged(commands, "special_label")[0].text == str(spec.name).split(" ")[0].to_upper(), "%s active special name" % who)
	game.power = "split"; game.power_time = 4.2
	check(tagged(game.player_hud.build_commands(game), "weapon_countdown")[0].text == "x3 5", "split shot countdown rounds up")
	game.power = "debit"; game.power_time = 0.01
	check(tagged(game.player_hud.build_commands(game), "weapon_countdown")[0].text == "DD 1", "debit countdown")
	game.power = "wellies"; game.power_time = 3.1
	check(tagged(game.player_hud.build_commands(game), "weapon_countdown")[0].text == "WB 4", "source wellies tag and countdown")
	game.power_time = 0
	check(tagged(game.player_hud.build_commands(game), "weapon_countdown").is_empty(), "expired weapon countdown hidden")
	game.abilities.reset("jp"); game.character = "jp"
	game.abilities.active="jp";game.abilities.duration=4;game.abilities.remaining=4
	commands=game.player_hud.build_commands(game)
	check(tagged(commands,"special_flash").size()==1 and is_equal_approx(tagged(commands,"special_flash")[0].colour.a,0.16),"source activation wash begins at16 percent")
	check(commands.find(tagged(commands,"special_flash")[0])>commands.find(tagged(commands,"kitty_label")[0]) and commands.find(tagged(commands,"special_flash")[0])<commands.find(tagged(commands,"special_back")[0]),"activation wash before special meter and after base HUD")
	game.abilities.remaining=3.87
	check(is_equal_approx(tagged(game.player_hud.build_commands(game),"special_flash")[0].colour.a,0.08),"activation wash fades across260ms")
	game.abilities.remaining=3.7
	check(tagged(game.player_hud.build_commands(game),"special_flash").is_empty(),"activation wash expires")
	# Real coin + receipt pickup verifies accounting without changing combat.
	game.load_level("1-1", false)
	game.start_boss();game.boss.state.hp=game.boss.state.max/2.0
	commands=game.player_hud.build_commands(game)
	check(tagged(commands,"thief_health_fill")[0].rect==Rect2(270,500,210,18),"source bottom Jar Thief health and fraction")
	check(tagged(commands,"thief_health_label")[0].text=="Jar thief","source boss name")
	game.boss.state.dizzy=1
	check(tagged(game.player_hud.build_commands(game),"thief_health_fill")[0].colour==HUD.GOLD,"dizzy boss health turns gold")
	game.boss.state.state="down"
	check(tagged(game.player_hud.build_commands(game),"thief_health_back").is_empty(),"defeated boss bar hidden")
	game.load_level("1-1", false)
	game.score = 10
	game.player = game.receipts[0].position
	game._collect_receipts()
	check(game.receipt_score == 5 and game.score == 15, "receipt reward bookkeeping preserves gameplay score")
	check(tagged(game.player_hud.build_commands(game), "player_coins")[0].text == "x10", "receipt does not inflate collected coin counter")
	game.load_level("3-1", false)
	check(game.receipt_score == 0 and game.score == 0, "new stage resets both counters")
	game.player = game.receipts[0].position; game._collect_receipts()
	check(game.receipt_score == 0, "W3 receipts correctly add no coin reward")
	for id in ["1-1", "1-6", "2-1", "2-6", "3-1", "3-3", "3-4", "3-5", "3-6", "3-S", "4-1", "4-6", "5-1", "5-6", "6-1", "6-6"]:
		game.load_level(id, false)
		check(game.player_hud.is_game_visible(game), "%s native/preview both have player HUD" % id)
		check(tagged(game.player_hud.build_commands(game), "portrait").size() == 1, "%s has original portrait" % id)
		check(game.player_hud.get_parent() == game.ui.get_parent() and game.player_hud.get_index() < game.ui.get_index(), "%s header below clickable controls" % id)
		for control in game.hud_controls:
			check(control.size.y >= 44 and control.position.x >= 600 and control.position.x + control.size.x <= 960 - game.safe_padding.x, "%s touch-sized menu control clear of player/kitty" % id)
		await process_frame; await process_frame
	check(game.player_hud.draw_count > 0, "actual CanvasItem submitted HUD draw commands")
	for viewport in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]:
		for safe in [Vector2(18, 14), Vector2(44, 20)]:
			var boxes := HUD.layout(viewport, safe)
			var menu := Menu.layout(viewport, safe)
			check(boxes.portrait.position.x >= safe.x and menu.launcher.end.x <= viewport.x - safe.x, "HUD respected safe margins %s %s" % [viewport, safe])
			check(boxes.special.end.x < boxes.kitty.position.x - 24 and not menu.launcher.intersects(Rect2(0, 0, viewport.x, 69)), "player/kitty/actions never overlap %s" % viewport)
	game._pause()
	check(game.player_hud.is_game_visible(game) and is_instance_valid(game.mobile_game_menu) and game.mobile_game_menu.opened, "pause screen covers frozen HUD")
	game._resume()
	game._open_story("1-intro")
	check(not game.player_hud.is_game_visible(game), "HUD hidden for story")
	game._pause()
	check(not game.player_hud.is_game_visible(game), "HUD remains hidden for paused story")
	game._return_to_map()
	check(not game.player_hud.is_game_visible(game), "HUD hidden after returning to map")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("Player HUD: %d checks passed." % checks); quit(0)
	else: printerr("Player HUD failed: %d/%d" % [failures.size(), checks]); quit(1)
