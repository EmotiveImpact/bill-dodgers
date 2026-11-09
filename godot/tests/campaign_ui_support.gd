extends RefCounted
## UI/story fixtures may focus a real card or panel directly. Actual map walking,
## buttons, gestures and title navigation have their own end-to-end GUI suite.
## This helper never starts a stage, changes a save or manufactures a clear.
static func visible_button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and child.text.begins_with(prefix): return child
		var nested := visible_button(child, prefix)
		if nested != null: return nested
	return null

static func button(game, prefix: String) -> Button:
	if game.mode == "menu" and is_instance_valid(game.title_menu):
		game.title_menu.tick(0.5) # Preserve the existing title focus/debounce fixture.
	var visible := visible_button(game.ui, prefix)
	if visible != null: return visible
	if game.mode != "menu": return null
	if is_instance_valid(game.campaign_map):
		var map = game.campaign_map
		if prefix.begins_with("WORLD "):
			var world := int(prefix.trim_prefix("WORLD ").get_slice(" ",0))
			map.close_overlays(); map.world_panel.show()
			return map.world_buttons.get(world)
		var id := prefix.trim_prefix("→ ").trim_prefix("✓ ").get_slice(" ",0)
		if map.state.levels.has(id):
			map.close_overlays(); map.show_card(id)
			return map.play_button
		if prefix == "Stage previews":
			game._show_title(true)
			game.title_menu.tick(0.5) # Focus fixture, not input debounce proof.
			return game.title_menu.buttons.get("free")
		if prefix == "The credits" and not map.state.credits_unlocked: return null
	if is_instance_valid(game.title_menu):
		game.title_menu.tick(0.5)
		for candidate in game.title_menu.buttons.values():
			if candidate.text.begins_with(prefix): return candidate
	return null
