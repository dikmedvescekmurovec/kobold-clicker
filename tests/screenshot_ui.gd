extends "res://tests/harness.gd"
## Renders the UI kit for a visual check: the main scene's panel over the map, then a board showing
## every button state at three sizes, including the 16x16 minimum. Needs a window (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/screenshot_ui.gd

const MAP_SEED := 1
## The board is drawn at 2x rather than the scene's 3x so all four states of every variation fit in
## one 1152x648 window, at the 16x16 minimum and at a realistic button size.
const UI_SCALE := 2
const SIZES := [Vector2(16, 16), Vector2(100, 26)]


## Never the player's own saves: these shots put fake items in the inventory, and they pin a seed,
## which is a request for that world and would replace a save of another one on the first write.
const SCRATCH_SAVE := "user://screenshot_inventory.json"
const SCRATCH_MAP := "user://screenshot_ui_map.json"


func _run() -> void:
	await _shoot_main_scene()
	await _shoot_inventory()
	await _shoot_skills()
	await _shoot_board()
	quit()


## The kit in place: the wooden panel over the generated map, as the player sees it.
func _shoot_main_scene() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = SCRATCH_SAVE
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	# Select the centre tile, which is what opens the side panel.
	main.map.select_cell(Vector2i.ZERO)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://ui_in_scene.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_in_scene.png"))

	# A 3x crop of the panel itself, to inspect the borders pixel by pixel.
	var panel: Control = main._panel
	var rect := Rect2i(Rect2(panel.position, panel.get_combined_minimum_size() * panel.scale))
	rect = rect.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("user://ui_panel_crop.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_panel_crop.png"))
	main.queue_free()
	await process_frame


## The collection log open over the map, with some of it found and some of it still to find.
func _shoot_inventory() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = SCRATCH_SAVE
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	# One of every rarity, because the borders are the thing these shots are here to check, plus
	# enough plain gear behind them to fill the grid out.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# Every gear type appears at least once, so the shot also shows the three cut from the UI pack
	# sitting next to the four that came with the game -- and spread over four levels, because the
	# bag is sectioned by level now and one section would photograph none of that.
	for spec in [["Leather Boot", ItemRarity.Rarity.COMMON, 1],
			["Wooden Armor", ItemRarity.Rarity.COMMON, 1],
			["Wooden Sword", ItemRarity.Rarity.UNCOMMON, 1],
			["Wooden Shield", ItemRarity.Rarity.COMMON, 3],
			["Wooden Torch", ItemRarity.Rarity.COMMON, 3],
			["Gold Ring", ItemRarity.Rarity.RARE, 3],
			["Leather Boot", ItemRarity.Rarity.RARE, 3],
			["Wooden Armor", ItemRarity.Rarity.COMMON, 7],
			["Ruby Amulet", ItemRarity.Rarity.ELITE, 7],
			["Wooden Sword", ItemRarity.Rarity.ELITE, 12]]:
		main.inventory.add(Item.rolled(spec[0], spec[1], rng, spec[2]))
	# One level ruled out, so the shot shows an Auto button held down next to one that is not.
	main.inventory.set_autodiscard(12, true)
	# A purse worth a few tiles' farming, so the footer at the bottom of the panel is photographed
	# with a number in it rather than at nothing.
	main.inventory.gold = 3847
	# Some orbs held and some never found, so the tray at the foot of the panel is photographed in
	# all three of its states at once -- and one of them past nine, because a two-digit count on a
	# 24 px square is the tightest thing in the row.
	main.inventory.add_orb("Orb of Transmutation", 12)
	main.inventory.add_orb("Orb of Alteration", 3)
	main.inventory.add_orb("Orb of Chaos")
	main.inventory.add_orb("Orb of Scouring", 2)
	# Most of a set worn, so the shot shows what an equipped socket looks like against an empty one.
	# The offhand and one ring are left bare on purpose: the empty squares and their marks are half
	# of what this panel has to get right.
	for pair in [["Wooden Sword", Equipment.Socket.WEAPON],
			["Leather Helmet", Equipment.Socket.HELMET],
			["Wooden Armor", Equipment.Socket.BODY],
			["Leather Boot", Equipment.Socket.BOOTS],
			["Ruby Amulet", Equipment.Socket.AMULET],
			["Gold Ring", Equipment.Socket.RING_LEFT]]:
		var worn := Item.rolled(pair[0], ItemRarity.Rarity.RARE, rng)
		main.inventory.add(worn)
		main.inventory.equip(worn, pair[1])
	main._on_bag_pressed()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://ui_inventory.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_inventory.png"))

	var panel: Control = main._bag_panel
	# The panel as it is actually laid out, not as small as it could be: it is stretched to the window
	# height, and its minimum size is now only the few rows at the top of it.
	var rect := Rect2i(Rect2(panel.position, panel.size * panel.scale))
	rect = rect.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("user://ui_inventory_crop.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_inventory_crop.png"))

	# The stat block, open on the elite sword -- the newest item, and the only shot that shows what a
	# modifier reads like. A rare sword is worn, so this is also the comparison: the elite piece on
	# the left, what it would replace on the right, and what the swap is worth under its stats.
	main._select_item(main.inventory.total() - 1)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	image.save_png("user://ui_item_detail.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_item_detail.png"))

	# The tray doing its second job. The elite sword is still open, so the orbs that can touch an
	# elite stand lit beside the ones that cannot -- which is the whole of the crafting interface and
	# the one thing no still of the grid can show.
	var tray_rect := Rect2(main._orb_tray.get_global_position(),
			main._orb_tray.size * Vector2(main.ui_scale, main.ui_scale))
	var craft := image.get_region(Rect2i(tray_rect).grow(12)
			.intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	craft.resize(craft.get_width() * 3, craft.get_height() * 3, Image.INTERPOLATE_NEAREST)
	craft.save_png("user://ui_orb_craft.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_orb_craft.png"))

	# The card, over an orb that cannot be used on what is open -- the case worth photographing,
	# because it is the only place the game says why a square is grey. The *last* such orb rather than
	# the first: a card near the left end fits inside the bag panel, and the arrangement worth seeing
	# is the one where it hangs out over the character sheet.
	var grey: OrbSlot = null
	for child: Node in main._orb_tray.get_children():
		if child is OrbSlot and not OrbTable.can_apply((child as OrbSlot).orb,
				main.inventory.items[main._bag_selected]):
			grey = child
	if grey != null:
		main._on_orb_hovered(grey.orb, grey)
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		image.save_png("user://ui_orb_card.png")
		print("Saved ", ProjectSettings.globalize_path("user://ui_orb_card.png"))
		main._on_orb_unhovered()

	# The two pages together and nothing else, doubled. The whole question the spread exists to
	# answer is whether the two columns read as one comparison, and that cannot be judged from a shot
	# of the map with them off in the corner.
	var spread := Rect2i(Rect2(main._bag_panel.position,
			main._bag_panel.size * main._bag_panel.scale))
	spread = spread.merge(Rect2i(Rect2(main._worn_panel.position,
			main._worn_panel.size * main._worn_panel.scale)))
	spread = spread.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var pages := image.get_region(spread)
	pages.resize(pages.get_width() * 2, pages.get_height() * 2, Image.INTERPOLATE_NEAREST)
	pages.save_png("user://ui_compare.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_compare.png"))
	main.queue_free()
	await process_frame
	for scratch in [SCRATCH_SAVE, SCRATCH_MAP]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))


## The skills page part-spent, with the card up over a skill that cannot be learned yet.
func _shoot_skills() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = SCRATCH_SAVE
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	main.inventory.level = 14
	main.inventory.gold = 900
	main.inventory.skills = Skills.new()
	for id in ["sharpened_edge", "sharpened_edge", "sharpened_edge", "sharpened_edge", "sharpened_edge",
			"keen_eye", "battle_rhythm", "might", "might", "titan",
			"scavenger", "scavenger", "appraiser"]:
		main.inventory.skills.rank_up(id, main.inventory.level)
	main._on_skills_pressed()
	for i in 2:
		await process_frame
	var view: SkillTreeView = main._skill_views["power"]
	for child: Node in view.get_children():
		if child is SkillSlot and child.id == "whirlwind":
			main._on_skill_hovered(child.id, child)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://ui_skills.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_skills.png"))
	main.queue_free()
	await process_frame


## Every variation and state, at three sizes, on the surface each one is meant to stand on.
func _shoot_board() -> void:
	var theme := UITheme.theme()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("1c1e28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)

	var board := VBoxContainer.new()
	board.theme = theme
	board.scale = Vector2(UI_SCALE, UI_SCALE)
	board.position = Vector2(8, 8)
	board.add_theme_constant_override("separation", 6)
	layer.add_child(board)
	for panel_variation: String in ["WoodPanel", "TextPanel"]:
		var surface := "wood" if panel_variation == "WoodPanel" else "light"
		var panel := PanelContainer.new()
		panel.theme_type_variation = panel_variation
		board.add_child(panel)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 4)
		panel.add_child(rows)
		for variation: String in UITheme.BUTTONS:
			if UITheme.BUTTONS[variation][0] != surface:
				continue
			for size: Vector2 in SIZES:
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 4)
				rows.add_child(line)
				for state: String in UITheme.STATES:
					line.add_child(_sample(variation, state, size))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_kit.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_kit.png"))


## Godot only shows hover and pressed on real input, so force each state with draw_mode overrides:
## a disabled button draws disabled, and for hover/pressed we draw the stylebox behind a plain label.
func _sample(variation: String, state: String, size: Vector2) -> Control:
	if state == "normal" or state == "disabled":
		var button := Button.new()
		button.theme_type_variation = variation
		button.text = "" if size.x < 40 else state
		button.disabled = state == "disabled"
		button.custom_minimum_size = size
		return button
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UITheme.theme().get_stylebox(state, variation))
	box.custom_minimum_size = size
	if size.x >= 40:
		var label := Label.new()
		label.text = state
		label.add_theme_color_override("font_color", UITheme.theme().get_color("font_color", variation))
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		box.add_child(label)
	return box
