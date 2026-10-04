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
	# Every shot is of a page where it settles, not of one sliding in (`Juice.slides`).
	var animations := Settings.animations
	Settings.animations = Settings.Anim.NONE
	await _shoot_main_scene()
	await _shoot_cave()
	await _shoot_inventory()
	await _shoot_skills()
	await _shoot_town()
	await _shoot_board()
	Settings.animations = animations
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


## The Gollux cave: what the hero says as it is put down (`ui_sense_dialogue.png`), the red light at the
## map's edge the way it lies, from the start far off (`ui_cave_sense_far.png`) and four steps off it
## (`ui_cave_sense.png`), then the cave itself, lit, with its tile panel and Enter cave (`ui_cave.png`),
## and the pit on its own with the hero beside it (`ui_cave_map.png`).
func _shoot_cave() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = SCRATCH_SAVE
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	var view: MapBuilder = main.view
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	main._credit_walls()
	var cave: Vector2i = view.cave
	# The wall in front of it broken, which is when the hero first feels it.
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	view._cover()
	# Every other tip read, so the hero's about the cave is the one that comes due.
	for tip: Array in main.TIPS:
		if tip[0] != "first_sense" and not str(tip[0]) in main.inventory.tips:
			main.inventory.tips.append(str(tip[0]))
	main._check_tips()
	await create_timer(Juice.POP_TIME + 0.1).timeout
	await _save_window("ui_sense_dialogue.png")
	main._on_tip_closed()
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	await _save_window("ui_cave_sense_far.png")
	var near := cave
	for step in 4:
		near = HexGrid.neighbor(near, HexGrid.Edge.W)
	# The hero's own patch of the land out there shown, the cave still two steps past it.
	view.player_cell = near
	main.map.set_player_cell(near)
	main.camera.position = main.map.ground_layer.map_to_local(near)
	view._reveal_around(near, 2)
	# The fog lifts as a front sweeping out from the hero (`EdgeFog`), whatever the animation level.
	await create_timer(1.5).timeout
	await _save_window("ui_cave_sense.png")

	view.reveal_all()
	view.player_cell = cave
	main.map.set_player_cell(cave)
	main.map.select_cell(cave)
	main._on_tile_clicked(cave, main.map.get_tile_info(cave))
	main.camera.position = main.map.ground_layer.map_to_local(cave)
	for i in 3:
		await process_frame
	await _save_window("ui_cave.png")
	# And the pit itself, the hero a step off it and nothing selected over it.
	main._on_close_pressed()
	var beside := HexGrid.neighbor(cave, HexGrid.Edge.SW)
	view.player_cell = beside
	main.map.set_player_cell(beside)
	for i in 3:
		await process_frame
	await _save_window("ui_cave_map.png")
	main.queue_free()
	await process_frame


func _save_window(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://" + file)
	print("Saved ", ProjectSettings.globalize_path("user://" + file))


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
	for spec in [["Leather Boots", ItemRarity.Rarity.COMMON, 1],
			["Wooden Armour", ItemRarity.Rarity.COMMON, 1],
			["Wooden Sword", ItemRarity.Rarity.UNCOMMON, 1],
			["Wooden Shield", ItemRarity.Rarity.COMMON, 3],
			["Wooden Torch", ItemRarity.Rarity.COMMON, 3],
			["Gold Ring", ItemRarity.Rarity.RARE, 3],
			["Leather Boots", ItemRarity.Rarity.RARE, 3],
			["Wooden Armour", ItemRarity.Rarity.COMMON, 7],
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
	main.inventory.add_orb("Orb of Augmentation", 3)
	main.inventory.add_orb("Orb of Chaos")
	main.inventory.add_orb("Orb of Divinity", 2)
	# Most of a set worn, so the shot shows what an equipped socket looks like against an empty one.
	# The offhand and one ring are left bare on purpose: the empty squares and their marks are half
	# of what this panel has to get right.
	for pair in [["Wooden Sword", Equipment.Socket.WEAPON],
			["Leather Helmet", Equipment.Socket.HELMET],
			["Wooden Armour", Equipment.Socket.BODY],
			["Leather Boots", Equipment.Socket.BOOTS],
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

	# The card beside a hovered piece. The cursor is put over the first square in the bag, because the
	# card asks the viewport where the mouse is and nothing else.
	# A warp moves nothing while the window is not the one in front, so it is brought there first.
	DisplayServer.window_move_to_foreground()
	for slot: ItemSlot in root.get_tree().get_nodes_in_group(ItemSlot.GROUP):
		if slot.is_visible_in_tree() and slot.has_meta("bag_index"):
			root.warp_mouse(slot.get_global_rect().get_center())
			break
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_item_card.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_item_card.png"))
	# And with Alt held: what is worn in that piece's place, on a second card past the first.
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_item_card_worn.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_item_card_worn.png"))
	alt = alt.duplicate()
	alt.pressed = false
	Input.parse_input_event(alt)
	root.warp_mouse(Vector2.ZERO)
	await process_frame

	var panel: Control = main.bag_page._panel
	# The panel as it is actually laid out, not as small as it could be: it is stretched to the window
	# height, and its minimum size is now only the few rows at the top of it.
	var rect := Rect2i(Rect2(panel.position, panel.size * panel.scale))
	rect = rect.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("user://ui_inventory_crop.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_inventory_crop.png"))

	# The elite sword selected -- the newest item -- with its buttons beside its square, and the doll
	# still standing beside the bag: what the piece would replace is the hover card's to say under Alt.
	main.bag_page._select_item(main.inventory.total() - 1)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	image.save_png("user://ui_item_detail.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_item_detail.png"))

	# The two pages together and nothing else, doubled. The whole question the spread exists to
	# answer is whether the two columns read as one comparison, and that cannot be judged from a shot
	# of the map with them off in the corner.
	var spread := Rect2i(Rect2(main.bag_page._panel.position,
			main.bag_page._panel.size * main.bag_page._panel.scale))
	spread = spread.merge(Rect2i(Rect2(main.bag_page._worn_panel.position,
			main.bag_page._worn_panel.size * main.bag_page._worn_panel.scale)))
	spread = spread.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var pages := image.get_region(spread)
	pages.resize(pages.get_width() * 2, pages.get_height() * 2, Image.INTERPOLATE_NEAREST)
	pages.save_png("user://ui_compare.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_compare.png"))
	# An orb pressed with the sword open: the sword is shut and the orb is in hand, every square it can
	# do nothing to grey -- the whole of the crafting interface, and the one thing no still of the grid
	# at rest can show.
	main.bag_page._on_orb_pressed("Orb of Chaos")
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var held := root.get_texture().get_image()
	var bag := Rect2i(Rect2(main.bag_page._panel.position, main.bag_page._panel.size * main.bag_page._panel.scale))
	var craft := held.get_region(bag.grow(8).intersection(Rect2i(Vector2i.ZERO, held.get_size())))
	craft.resize(craft.get_width() * 2, craft.get_height() * 2, Image.INTERPOLATE_NEAREST)
	craft.save_png("user://ui_orb_craft.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_orb_craft.png"))
	# The card over the last orb, with the cursor really on it: a card near the left end fits inside the
	# bag panel, and the arrangement worth seeing is the one where it hangs out over the character sheet.
	var last: OrbSlot = main.bag_page._orb_tray.get_child(main.bag_page._orb_tray.get_child_count() - 1)
	root.warp_mouse(last.get_global_rect().get_center())
	main.bag_page._on_orb_hovered(last.orb, last)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_orb_card.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_orb_card.png"))
	main.bag_page._hide_orb_card()
	root.warp_mouse(Vector2.ZERO)
	main.bag_page._on_orb_pressed("Orb of Chaos")
	# A greatsword on, with the block shut so the doll is back: the weapon hand holds the piece and
	# the offhand wears the same icon faded, which is the one state of the doll no other shot has.
	var heavy := Item.rolled("Wooden Greatsword", ItemRarity.Rarity.RARE, rng, 12)
	main.inventory.add(heavy)
	main.inventory.equip(heavy, Equipment.Socket.WEAPON)
	main.bag_page._select_item(-1)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_two_handed.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_two_handed.png"))
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
	main.inventory.level = 17
	main.inventory.gold = 900
	main.inventory.skills = Skills.new()
	for id in ["sharpened_edge", "sharpened_edge", "sharpened_edge", "sharpened_edge", "sharpened_edge",
			"keen_eye", "keen_eye", "keen_eye", "battle_rhythm", "might", "might", "quick_hands", "titan",
			"scavenger", "scavenger", "scavenger"]:
		main.inventory.skills.rank_up(id, main.inventory.level)
	main._on_skills_pressed()
	for i in 2:
		await process_frame
	var view: SkillTreeView = main.skills_page._skill_views["power"]
	for child: Node in view.get_children():
		if child is SkillSlot and child.id == "whirlwind":
			main.skills_page._on_skill_hovered(child.id, child)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://ui_skills.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_skills.png"))

	# A plain tooltip on the tip card: the cursor left on a Reset for longer than `TipCard.DELAY`.
	main.skills_page._hide_card()
	var reset: Button = main.skills_page._respec_buttons["power"]
	root.warp_mouse(reset.get_global_rect().get_center())
	# The viewport only learns what is hovered from a motion event, and a warp sends none.
	var motion := InputEventMouseMotion.new()
	motion.position = reset.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion)
	await create_timer(TipCard.DELAY + 0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_tooltip.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_tooltip.png"))
	root.warp_mouse(Vector2.ZERO)

	# The trees burst once, the second tree begun, with the card over Titan: its numbers, no effect.
	main.inventory.level = 100
	main.inventory.skills = Skills.new()
	main.inventory.skills.bursts = 1
	for id: String in ["sharpened_edge", "sharpened_edge", "sharpened_edge", "keen_eye", "scavenger"]:
		main.inventory.skills.rank_up(id, main.inventory.level)
	main.skills_page.open()
	var away := InputEventMouseMotion.new()
	away.position = Vector2(root.size) - Vector2.ONE
	away.global_position = away.position
	root.push_input(away)
	for i in 2:
		await process_frame
	for slot: Node in main.skills_page._skill_views["power"].get_children():
		if slot is SkillSlot and slot.id == "titan":
			main.skills_page._on_skill_hovered("titan", slot)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_skills_burst.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_skills_burst.png"))
	main.queue_free()
	await process_frame


## A settlement: what the tile panel says about one from outside, then the inside of it -- each
## counter's shelf with the bag standing beside it, and one piece off the shelf open with its price.
## The whole point of these is the width and the height: the town page, the bag and the doll at the smith
## have to share a 1152x648 window and the shelf has to fit down the page, so they are full-window
## shots.
func _shoot_town() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = SCRATCH_SAVE
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	# A bag worth selling out of: two levels of it, so a heading's Sell all is photographed beside one
	# that is not, and a spread of rarities, because the price is what changes with them.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for spec in [["Wooden Sword", ItemRarity.Rarity.ELITE, 6], ["Leather Boots", ItemRarity.Rarity.RARE, 6],
			["Gold Ring", ItemRarity.Rarity.UNCOMMON, 6], ["Wooden Shield", ItemRarity.Rarity.COMMON, 6],
			["Wooden Armour", ItemRarity.Rarity.COMMON, 3], ["Wooden Torch", ItemRarity.Rarity.COMMON, 3],
			["Ruby Amulet", ItemRarity.Rarity.RARE, 3]]:
		main.inventory.add(Item.rolled(spec[0], spec[1], rng, spec[2]))
	# A purse that can actually afford the shelf, so the Buy button is photographed live rather than
	# greyed out with the reason -- and the smith's lock, which is the dearest thing in a town by a
	# distance, so his counter is photographed with both buttons alive.
	main.inventory.gold = 60000
	main.inventory.add_orb("Orb of Transmutation", 11)
	main.inventory.add_orb("Orb of Chaos", 2)
	main.inventory.add_orb("Orb of Exaltation")
	# Something worn, so the doll at the smith has a piece to hand him.
	var worn := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	main.inventory.add(worn)
	main.inventory.equip(worn, Equipment.Socket.WEAPON)

	# Every first-time pop-up marked seen. Walking into a town checks them, and a bag filled by hand
	# has earned several: they come up in the middle of the window, and what these shots are of is the
	# pages behind them.
	for tip: Array in main.TIPS:
		main.inventory.tips.append(str(tip[0]))

	# Standing on the village the map guarantees five tiles out, which is the first town any player
	# reaches. Uncharted land cannot be clicked, so the window is charted first.
	var town: Vector2i = main.view.start_town - main.view.origin
	main.view.reveal_all()
	main.view.player_cell = town
	main.map.set_player_cell(town)
	main.map.select_cell(town)
	main._update_buttons()
	main.camera.position = main.map.ground_layer.map_to_local(town)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_tile_panel_town.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_tile_panel_town.png"))

	# Inside, with every counter: the guaranteed start town is a village, which by the rules has one
	# vendor and no smith, and the shot that has to be checked is the one where a page carries every
	# tab it can.
	main.towns._tiers[main.view.start_town] = TownWorld.Tier.FORTRESS
	# A pinned shelf, so the shot is the same shop every time and can be read against the last one.
	main.town_page._stock_rng.seed = WORLD_SEED
	main._on_town_pressed()
	for i in 2:
		await process_frame

	# The board as a town opens on it: three cards, each a picture, a name, a reward, Info and Accept.
	# Two of the postings are made to promise a piece -- an elite sword +1 and a unique -- so the shot
	# has both reward squares on it whatever the seed rolled.
	var board := BountyBoard.bounties(main.inventory.towns.visit(main.view.origin + town))
	if board.size() > 1:
		board[0][BountyBoard.ITEM] = {"kind": "sword", "rarity": "elite", "plus": 1}
		board[1][BountyBoard.ITEM] = {"kind": "", "rarity": "unique", "plus": 0}
		main.town_page._fill()
		main.town_page.layout()
		for i in 2:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_board.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_board.png"))

	# And with one posting taken on and part worked off: its card first, the rest dimmed under it.
	if board.size() > 1:
		# The elite, which is last and the one that pays an orb, so the shot has the orb's picture in it.
		var taken: Dictionary = board[-1]
		BountyBoard.accept(main.inventory.towns, taken)
		BountyBoard.count_kill(main.inventory.towns, str(taken[BountyBoard.ENEMY]),
				maxi(int(taken[BountyBoard.NEED]) / 3, 1))
	main.town_page._fill()
	main.town_page.layout()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_bounties.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_bounties.png"))

	# What the Claim puts up, with that posting's own pay -- raised straight, so nothing is paid and the
	# shots after this one see the purse and the bag they always did.
	if board.size() > 1:
		var paid: Dictionary = board[-1]
		var orbs := {}
		for orb: String in BountyBoard.orbs_of(paid):
			orbs[orb] = int(orbs.get(orb, 0)) + 1
		var paid_rng := RandomNumberGenerator.new()
		paid_rng.seed = WORLD_SEED
		main._show_bounty_paid(str(paid[BountyBoard.ENEMY]), float(paid[BountyBoard.GOLD]),
				int(paid.get(BountyBoard.XP, 0)), orbs, BountyBoard.reward_item(paid, town, paid_rng))
		# Once it has popped in, counted up and shown its finds.
		await create_timer(Juice.REVEAL_DELAY + Juice.REVEAL_MOST + Juice.REVEAL_TIME + 0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://ui_town_claimed.png")
		print("Saved ", ProjectSettings.globalize_path("user://ui_town_claimed.png"))
		main._close_bounty_paid()

	# What clearing a board offers, at tier III: three side by side, one to take. Written into the drawer
	# straight, and taken out again after, so the board's shots below have no Reward on them.
	var here_drawer: Dictionary = main.inventory.towns.visit(main.view.origin + town)
	var choice_rng := RandomNumberGenerator.new()
	choice_rng.seed = WORLD_SEED
	# The first as rolled, then the two piles, which have squares of their own.
	var offered := BountyBoard.roll_choice(3, town, choice_rng)
	offered[1] = {BountyBoard.CHOICE_GOLD: BountyBoard.pile_gold(3, town)}
	offered[2] = {BountyBoard.CHOICE_XP: BountyBoard.pile_xp(3, town)}
	here_drawer[BountyBoard.CHOICE] = offered
	# One posting handed in behind it, so the board's heading shows a gold pip and the chest lit.
	if board.size() > 1:
		board[0][BountyBoard.DONE] = true
		main.town_page._fill()
		main.town_page.layout()
	main._show_board_choice()
	await create_timer(Juice.REVEAL_DELAY + Juice.REVEAL_MOST + Juice.REVEAL_TIME + 0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_board_choice.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_board_choice.png"))
	# And the smith over it, as the first board a player clears has him: that tip unseen again.
	main.inventory.tips.erase("first_board_cleared")
	main._check_tips()
	await create_timer(Juice.POP_TIME + 0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_board_dialogue.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_board_dialogue.png"))
	main._on_tip_closed()
	main._close_board_choice()
	here_drawer.erase(BountyBoard.CHOICE)
	if board.size() > 1:
		board[0][BountyBoard.DONE] = false
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout

	# The same board with the work out taken at another town instead: that bounty's card first, saying
	# where it is handed in, and this board's own postings under it, dimmed. Put back after, so the
	# journal's shots below see the work they always did.
	var away_spot := Vector2i.MAX
	for spot: Vector2i in main.towns._tiers:
		if spot != main.view.start_town:
			away_spot = spot
			break
	if board.size() > 1 and away_spot != Vector2i.MAX:
		var here: Dictionary = board[-1]
		var have := int(here.get(BountyBoard.HAVE, 0))
		BountyBoard.abandon(here)
		var away_drawer: Dictionary = main.inventory.towns.visit(away_spot)
		BountyBoard.restock(away_drawer, main.view.envs_within(away_spot - main.view.origin,
				BountyBoard.BOUNTY_RANGE), away_spot - main.view.origin, rng)
		var away: Dictionary = BountyBoard.bounties(away_drawer)[0]
		BountyBoard.accept(main.inventory.towns, away)
		BountyBoard.count_kill(main.inventory.towns, str(away[BountyBoard.ENEMY]), 1)
		main.town_page._fill()
		main.town_page.layout()
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://ui_town_board_away.png")
		print("Saved ", ProjectSettings.globalize_path("user://ui_town_board_away.png"))
		BountyBoard.abandon(away)
		BountyBoard.accept(main.inventory.towns, here)
		BountyBoard.count_kill(main.inventory.towns, str(here[BountyBoard.ENEMY]), have)

	# The gear merchant, with a piece open, which is where the Sell button that replaces Discard lives.
	# So this shot has both halves of the counter at once: what it sells on the right, what it buys on
	# the left.
	main.town_page._on_tab_pressed(TownServices.GEAR)
	main.bag_page._select_item(0)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_gear.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_gear.png"))

	# The question a heading's coins ask before a whole level goes over the counter.
	main.bag_page._select_item(-1)
	for button: Button in main.bag_page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Sell "):
			button.pressed.emit()
			break
	# Ticked, which is the state with the mark in it.
	(main.bag_page._confirm.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_confirm_sell.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_confirm_sell.png"))
	main.bag_page._close_confirm()

	# The second question, about a unique among the handful: the level's ordinary pieces have gone over
	# the counter on the first answer, and this one names what is left.
	var before: Array[Item] = main.inventory.items.duplicate()
	main.inventory.add(Item.rolled_unique("stonebreaker", rng, 6))
	main.bag_page.refresh()
	await process_frame
	for button: Button in main.bag_page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Sell "):
			button.pressed.emit()
			break
	for button: Button in main.bag_page._confirm.find_children("", "Button", true, false):
		if button.text == "Sell":
			button.pressed.emit()
			break
	(main.bag_page._confirm.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_confirm_uniques.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_confirm_uniques.png"))
	main.bag_page._close_confirm()
	# The bag and the purse put back as they were, so the shots below are the ones they have always been.
	main.inventory.items.assign(before)
	main.inventory.gold = 60000
	main.bag_page.refresh()

	# One piece off the shelf, open: the price on the Buy button. The square whose piece fills a socket
	# that is worn, and the best of those, so the block is photographed carrying modifiers.
	main.bag_page._select_item(-1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var shelf := VendorStock.items(main.inventory.towns.visit(main.view.origin + town))
	var picked := 0
	var best := -1
	for at in shelf.size():
		var piece: Item = shelf[at]
		if piece == null or main.inventory.equipment.item_at(
				main.inventory.equipment.sockets_for(piece)[0]) == null:
			continue
		# And the best of those, so the block is photographed carrying modifiers rather than as the four
		# bare lines a common has.
		if piece.rarity > best:
			best = piece.rarity
			picked = at
	main.town_page._on_shelf_input(press, picked)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_buy.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_buy.png"))

	# The other counter: no piece open, so the tray sells rather than crafts, with the card up over an
	# orb saying what it fetches -- and the vendor's own six orbs on the page beside it, priced.
	main.town_page._close_offer(true)
	main.bag_page._select_item(-1)
	main.town_page._on_tab_pressed(TownServices.ORBS)
	for i in 2:
		await process_frame
	for child: Node in main.bag_page._orb_tray.get_children():
		if child is OrbSlot and (child as OrbSlot).orb == "Orb of Exaltation":
			main.bag_page._on_orb_hovered((child as OrbSlot).orb, child)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_orbs.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_orbs.png"))

	# The smith, with the rare amulet open in the bag: he has no shelf, so his counter is the piece the
	# player is holding up to him, his two prices, and what the hammer would make of it. The bag on the
	# other edge is the same piece, which is the whole arrangement this shot is here to check.
	#
	# The level-3 piece rather than one of the level-6 ones, because five tiles out the ground only
	# allows level 5 and the deeper pieces photograph the cap's refusal instead of a live hammer.
	main.bag_page._hide_orb_card()
	main.town_page._on_tab_pressed(TownServices.SMITH)
	# First with nothing held up to him: himself at the anvil, the empty square, and his two services.
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_smith_idle.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_smith_idle.png"))
	main.bag_page._select_item(6)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_smith.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_smith.png"))
	# What he says the first time his tab opens, his anvil beside him: that tip unseen again.
	main.inventory.tips.erase("first_smith")
	main.town_page._on_tab_pressed(TownServices.SMITH)
	await create_timer(Juice.POP_TIME + 0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_smith_dialogue.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_smith_dialogue.png"))
	main._on_tip_closed()
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	main.bag_page._select_item(6)
	await process_frame

	# And the doll beside the bag, which is how a worn piece is handed to him: he works on
	# one as readily as on a carried piece, so the sheet at his counter is the figure rather than the
	# room the other counters give away. The shot is here to check it fits beside his page.
	main.bag_page._select_socket(Equipment.Socket.WEAPON)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_smith_worn.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_smith_worn.png"))

	# And what he leaves behind, on the elite sword: a locked modifier, which every orb now works
	# around, and a break, which is the end of the piece as far as crafting goes. Both are read off the
	# hover card, and both grey the counter on the right with one reason between them.
	var marked: Item = main.inventory.items[0]
	Blacksmith.lock(marked, rng)
	marked.broken = true
	main.bag_page._select_item(0)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_broken.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_broken.png"))

	# The fortuneteller: what she can be asked with its prices, then two of her answers in the list's
	# place -- the roads and a whole piece read (the rare amulet).
	main.inventory.gold = 1.0e9
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	main.bag_page._select_item(6)
	for i in 2:
		await process_frame
	# One square lit as the cursor lights it, which is the only way the hover halo reaches a shot.
	main.town_page._rows.find_child(FortuneTeller.ROADS, true, false).mouse_entered.emit()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_fortune.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_fortune.png"))
	# What she says the first time her tab opens: that tip unseen again, and the tab opened afresh.
	main.inventory.tips.erase("first_fortune")
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	await create_timer(Juice.POP_TIME + 0.1).timeout
	# Animations are off for these shots, so her first page is already all there.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_fortune_dialogue.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_fortune_dialogue.png"))
	main._on_tip_closed()
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	# And the hero, whose portrait stands on the left: the tip about the first find, unseen again.
	main.inventory.tips.erase("first_item")
	main._check_tips()
	await create_timer(Juice.POP_TIME + 0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_player_dialogue.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_player_dialogue.png"))
	main._on_tip_closed()
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	for shot: Array in [[FortuneTeller.ROADS, "ui_town_roads"], [FortuneTeller.APPRAISE, "ui_town_appraise"]]:
		main.town_page._on_reading_pressed(shot[0])
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://%s.png" % shot[1])
		print("Saved ", ProjectSettings.globalize_path("user://%s.png" % shot[1]))
		main.town_page._close_told()
		main._close_banner()

	# A wall down: the way out joins her list, and asked for it is a question before it is a deed.
	main.view.land_radius += MapBuilder.WALL_STEP
	main._credit_walls()
	main.inventory.super_orbs = 3
	main.town_page.redraw()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_way_out.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_way_out.png"))
	main.town_page._on_reading_pressed(FortuneTeller.TRANSCEND)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_transcend.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_transcend.png"))
	main.town_page._close_told()

	# Two heirlooms out of a world that has ended, one of them worn on the heirlooms' own doll, and the
	# other held up to the smith from the heirlooms' page, which the crown swaps in at the counter: the
	# three panels and the one corner button a town leaves standing have to share the window.
	var carried: Array[Item] = [main.inventory.items[1], main.inventory.items[2]]
	for piece in carried:
		main.inventory.make_heirloom(piece)
		piece.transcend()
	main.inventory.stash().equip(carried[1], main.inventory.stash().equipment.sockets_for(carried[1])[0])
	main.town_page._on_tab_pressed(TownServices.SMITH)
	main._on_heirlooms_pressed()
	main.heirloom_page._select_item(0)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_town_heirloom_smith.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_town_heirloom_smith.png"))

	# Out of town: the heirlooms' page behind the crown, with its own doll.
	main._on_left_page_closed()
	main._on_heirlooms_pressed()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_heirlooms.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_heirlooms.png"))
	main._on_left_page_closed()

	# The black screen between two worlds: the choice, a piece of the bag open to be kept, an heirloom
	# open over the super orbs, and the question an aimed one asks. Stood over the scene rather than
	# gone to through the fortuneteller, so the rest of this script still has a world to shoot; with no
	# animations, so it is black at once.
	var animations := Settings.animations
	Settings.animations = Settings.Anim.NONE
	# Budget enough for the two curses the shot takes, and some left over: six depths won are six skulls.
	var depth: int = main.inventory.dungeon_depth
	main.inventory.dungeon_depth = 6
	var black := TranscendPage.new(main.inventory, main.ui_scale)
	main.inventory.dungeon_depth = depth
	main._ui_layer.add_child(black)
	main._character.hide()
	var black_shots: Array[Array] = [
		[func() -> void: pass, "ui_transcend_choice"],
		[func() -> void:
			black._open(black._create_page, true)
			black._create_page._select_item(1), "ui_transcend_create"],
		[func() -> void:
			black._open(black._upgrade_page)
			# One Ascension fed into a +1 piece, so its card wears the bar toward +2.
			var shown: Item = black._upgrade_page.inventory.items[0]
			shown.plus = maxi(shown.plus, 1)
			shown.ascension = 1
			black._upgrade_page._select_item(0), "ui_transcend_upgrade"],
		[func() -> void:
			black._upgrade_page._on_orb_pressed(SuperOrbTable.PERFECTION)
			black._upgrade_page._craft(SuperOrbTable.PERFECTION, black._upgrade_page.inventory.items[0]),
			"ui_transcend_aim"],
		# The curses behind the third card, two of them taken.
		[func() -> void:
			black._show_choice()
			black._show_curses()
			black._on_curse_toggled(true, Curses.THICK_FOG)
			black._on_curse_toggled(true, Curses.LEAN_PICKINGS), "ui_transcend_curses"],
		# And the foot of the same table, which is longer than the window and scrolls under its headings.
		[func() -> void: black._curse_scroll.scroll_vertical = 100000, "ui_transcend_curses_end"],
	]
	for shot in black_shots:
		(shot[0] as Callable).call()
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://%s.png" % shot[1])
		print("Saved ", ProjectSettings.globalize_path("user://%s.png" % shot[1]))
	black.queue_free()
	main.inventory.pending_curses.clear()
	main._character.show()
	Settings.animations = animations

	# And out of the town again, where the same postings are read off the journal in the corner: the
	# town that posted them over the top, the swatches and the nearest tile under each, and the line
	# that says a finished one is paid for back where it was taken on.
	main._on_left_page_closed()
	main._on_bounty_pressed()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_bounty_journal.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_bounty_journal.png"))

	# The collection log behind the corner's trophy, with a few uniques found and two more unlocked by
	# achievements: the card beside a found one says what it is, and beside a darkened one where it
	# hides as well. The locked ones are outlines in black.
	main._on_left_page_closed()
	for id: String in ["metronome", "knucklebone_ring", "rimeplate"]:
		main.inventory.note_unique(id)
	# A starter: unlocked from the first, not yet found, and in the grid's top row.
	var told := ["couriers_boots"]
	# Rimeplate at rank III, so its card writes its rank's numbers.
	main.inventory.achievements.merge({"rimeplate": 3, "knucklebone_ring": 1})
	UniqueTable.ranks = Achievements.ranks(main.inventory)
	# The wall broken above earned Thaw on the next save; its banner is not what this shot is of.
	for i in 2:
		await process_frame
	main._close_banner()
	main._on_collection_pressed()
	for i in 2:
		await process_frame
	var squares: Array = main.collection_page.find_children("*", "ItemSlot", true, false)
	# A home piece for the found one, at the rank above.
	for shot: Array in [["ui_collection", "rimeplate"], ["ui_collection_missing", told[0]]]:
		var at: Array = squares.filter(func(square: ItemSlot) -> bool: return square.item.unique == shot[1])
		root.warp_mouse((at[0] as ItemSlot).get_global_rect().get_center())
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://%s.png" % shot[0])
		print("Saved ", ProjectSettings.globalize_path("user://%s.png" % shot[0]))
	# The same Rimeplate under detailed descriptions: every rank's numbers, and rank IV's line locked.
	Settings.item_details = true
	root.warp_mouse(Vector2.ZERO)
	for i in 3:
		await process_frame
	var rime: Array = squares.filter(func(square: ItemSlot) -> bool: return square.item.unique == "rimeplate")
	root.warp_mouse((rime[0] as ItemSlot).get_global_rect().get_center())
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_collection_detailed.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_collection_detailed.png"))
	Settings.item_details = false
	# What the log is worth, on the tip card beside the mark at the count's end.
	var help: Control = main.collection_page.find_children("*", "TextureRect", true, false).filter(
			func(mark: Control) -> bool: return not mark.tooltip_text.is_empty())[0]
	var over := InputEventMouseMotion.new()
	over.position = help.get_global_rect().get_center()
	over.global_position = over.position
	root.warp_mouse(over.position)
	root.push_input(over)
	await create_timer(TipCard.DELAY + 0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_collection_help.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_collection_help.png"))
	root.warp_mouse(Vector2.ZERO)

	# An achievement earned on the map: its banner, then its page with a square's card up.
	main._on_left_page_closed()
	main.inventory.tick("crits", 100)
	main.inventory.save(main.inventory_path)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_achievement_banner.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_achievement_banner.png"))
	main._close_banner()
	main.inventory.tick("blows_taken", 320)
	main._on_achievements_pressed()
	for i in 2:
		await process_frame
	var tile: ItemSlot = main.achievements_page.find_children("*", "ItemSlot", true, false).filter(
			func(slot: ItemSlot) -> bool: return slot.item.unique == "spiked_helm")[0]
	root.warp_mouse(tile.get_global_rect().get_center())
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_achievements.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_achievements.png"))
	root.warp_mouse(Vector2.ZERO)

	# The character page, behind a press on the corner's character panel.
	main._on_left_page_closed()
	main._on_character_pressed()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_character.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_character.png"))

	# The same page late in a run, which is how it is mostly read: a hero of its own (the world's is
	# left as it is for the shots after this), its page standing where the world's does. Then the
	# weapon swapped for a better one since the last look, so the changes are written beside the numbers.
	var late := _late_hero()
	var sheet := CharacterPage.new(late, main.ui_scale)
	main.character_page.get_parent().add_child(sheet)
	sheet.area = main.character_page.area
	main.character_page.hide()
	sheet.layout()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_character_late.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_character_late.png"))
	sheet.hide()
	sheet.show()
	var weapon: Item = late.equipment.worn[Equipment.Socket.WEAPON]
	weapon.stats["damage"] = float(weapon.stats.get("damage", 0.0)) * 1.3
	weapon.stats["attack_speed"] = float(weapon.stats.get("attack_speed", 0.0)) + 0.4
	sheet.open()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_character_change.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_character_change.png"))
	sheet.queue_free()
	main.character_page.show()

	# The same page in a world under curses, which it lists at its foot; and the tile panel of land
	# that carries modifiers. That land lies past the second wall, which this world has not reached, so
	# Wild Tiles and a wall counted as fallen stand in: the rings generated past the first wall then
	# carry theirs.
	main.inventory.curses.assign([Curses.WILD_TILES, Curses.HOMELAND, Curses.LONG_WINTER])
	main.inventory.homeland.assign(["grass", "forest"])
	main.character_page.open()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_character_curses.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_character_curses.png"))
	# The curses folded away, and the page drawn again to show it stays folded.
	main.character_page.find_children("*", "VBoxContainer", true, false).filter(func(n: Node) -> bool: return n is Accordion)[0].toggle()
	main.character_page.open()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_character_folded.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_character_folded.png"))
	main.character_page.find_children("*", "VBoxContainer", true, false).filter(func(n: Node) -> bool: return n is Accordion)[0].toggle()
	main._on_left_page_closed()
	var radius: int = main.view.land_radius
	var generated := MapBuilder.START_LAND_RADIUS + MapBuilder.WASTE_DEPTH + 1
	main.view.land_radius = maxi(radius, generated)
	for x in range(MapBuilder.START_LAND_RADIUS + 2, generated):
		var wild := Vector2i(x, 0)
		if main._mods_of(wild).size() > 1:
			main.map.select_cell(wild)
			break
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_tile_mods.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_tile_mods.png"))
	main.view.land_radius = radius
	main.inventory.curses.clear()
	main.inventory.homeland.clear()
	main.map.deselect()
	main._panel.hide()

	# The settings, behind the corner's cog, and then the question its Reset asks.
	main._on_left_page_closed()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_corner.png")
	main._on_settings_pressed()
	for shot: String in ["ui_settings", "ui_settings_reset"]:
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://%s.png" % shot)
		print("Saved ", ProjectSettings.globalize_path("user://%s.png" % shot))
		main.settings_page._ask(true)
	# The dev generator in the settings' place, a golden helm some orbs in.
	main.settings_page._open_generator()
	var forge: ItemGenerator = main.settings_page._rows.get_child(-1)
	forge.pick("helm", 3, 12)
	for i in 3:
		forge.spend("Orb of Alchemy")
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_item_generator.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_item_generator.png"))
	main.queue_free()
	await process_frame
	for scratch in [SCRATCH_SAVE, SCRATCH_MAP]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))


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


## Godot only shows hover and pressed on real input, so each state is a real Button wearing that
## state's stylebox and font colour as its normal ones. A Panel with a centred Label stood in once, and
## drew the label where no button puts it -- hover and pressed read as lifting the word, which the
## game never did (pressed sinks it a pixel, `UITheme.build`).
## A hero some way into a run, for the character page: level 53, a set of rolled pieces at level 50,
## two uniques worn, a capstone learned, a share of the collection found and a depth of the Descent won.
func _late_hero() -> Inventory:
	var hero := Inventory.new()
	hero.level = 53
	hero.xp = 342
	hero.kills = 6216
	hero.dungeon_depth = 4
	hero.uniques_found.assign(UniqueTable.ids().slice(0, 22))
	hero.skills.ranks["assassin"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for id: String in ["worry_stone", "couriers_boots"]:
		var unique := Item.rolled_unique(id, rng, 50)
		hero.equipment.equip(hero.equipment.sockets_for(unique)[0], unique)
	var enemy: String = EnemyRoster.ENEMIES.keys()[0]
	var tries := 0
	while hero.equipment.worn.size() < Equipment.NAMES.size() and tries < 200:
		tries += 1
		var piece := LootTable.roll(enemy, rng, true, 50, 0.0, 0.0, ItemRarity.Rarity.ELITE)
		for socket: Equipment.Socket in hero.equipment.sockets_for(piece):
			if not hero.equipment.worn.has(socket) and hero.equipment.displaced_by(socket, piece).is_empty():
				hero.equipment.equip(socket, piece)
				break
	return hero


func _sample(variation: String, state: String, size: Vector2) -> Control:
	var button := Button.new()
	button.theme_type_variation = variation
	button.text = "" if size.x < 40 else state
	button.disabled = state == "disabled"
	button.custom_minimum_size = size
	if state == "hover" or state == "pressed":
		button.add_theme_stylebox_override("normal", UITheme.theme().get_stylebox(state, variation))
		button.add_theme_color_override("font_color",
				UITheme.theme().get_color("font_%s_color" % state, variation))
	return button
