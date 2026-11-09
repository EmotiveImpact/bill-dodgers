extends Node2D
## Draw transitions above the game HUD, but below a separate pause/story screen.
var game
var font: Font

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.mode != "play": return
	font = game.font
	if game.level_id == "3-3": game.draw_touch_controls(self)
	if game._native_world_three(): game.festival_renderer.draw_commands(self, game.festival_renderer.build_hud(game, game.world_three))
	elif game._native_world_four(): game.holiday_renderer.draw_commands(self, game.holiday_renderer.build_hud(game, game.world_four))
	elif game._native_world_six(): game.billing_renderer.draw_commands(self, game.billing_renderer.build_hud(game, game.world_six))
	elif game._native_world_five(): game.moving_day_renderer.draw_commands(self, game.moving_day_renderer.build_hud(game, game.world_five))
	elif game._native_world_two(): game.supermarket_renderer.draw_commands(self, game.supermarket_renderer.build_hud(game, game.world_two))
