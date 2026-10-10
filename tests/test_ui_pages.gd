extends "res://tests/harness.gd"
## Headless checks for the pages as they stand in a window. Run from the project folder:
##   python tests/run_all.py ui_pages
##
## Two halves. **How each page lies** (`_test_layouts`): every page the game has, built over a scratch
## hero in a scratch world and laid out in four windows (`SHAPES`: the default one, a phone held
## upright, the smallest upright budget and a phone on its side), then held to what must be true of
## all of them (`_wrongs`). **What the pages do**: a question answered once, a hidden page asking
## nothing, a field that keeps its cursor, and the rest, one test a bug.
##
## **A layout dump, for whoever cannot look at a screenshot.** With the environment variable
## `KOBOLD_LAYOUT_DUMP` naming a folder, `_test_layouts` also writes `<page>_<width>x<height>.json`
## there, one a page and a window: every Control under the page in tree order, as its path (a name
## where it has one of its own, else its class and its place among its siblings), its class, its rect
## in window pixels, whether it is shown and what it says. Dump before a change and after it into two
## folders and the difference is a text diff (in PowerShell, `$env:KOBOLD_LAYOUT_DUMP = "<folder>"`
## on a line of its own first):
##   KOBOLD_LAYOUT_DUMP=<folder> python tests/run_all.py ui_pages --only _test_layouts

const SAVE := "user://test_ui_pages.json"
const ACCOUNT := "user://test_ui_pages_cloud.cfg"
const MAP := "user://test_ui_pages_map.json"
const DUMP := "KOBOLD_LAYOUT_DUMP"
## The main scene's own, and an even row (`MapBuilder.create`).
const ORIGIN := Vector2i(128, 128)
## Each window a page is laid out in, and the `ui_scale` the main scene would pick for it
## (`UITheme.pick_scale`).
const SHAPES := [[Vector2i(1152, 648), 2.0], [Vector2i(360, 780), 1.0], [Vector2i(324, 576), 1.0],
		[Vector2i(780, 360), 1.0]]
## How far a rect may stand past the window and still be inside it: a pixel's rounding.
const SLACK := 0.5

var _map: HexMap
var _view: MapBuilder


## Hears whatever key or action reaches `_unhandled_input` past everything later in the tree.
class Listener extends Node:
	var heard: Array = []

	func _unhandled_input(event: InputEvent) -> void:
		heard.append(event)


## A map with two chests on it, the nearer brought into sight by the fortuneteller's roads.
class Roads extends MapBuilder:
	var chests: Array[Vector2i] = [Vector2i(3, 0), Vector2i(9, 0)]

	func nearest_chest(_unseen_only := false) -> Vector2i:
		return chests[0] if not chests.is_empty() else HexMap.NO_CELL

	func reveal_ring_towns(_cell: Vector2i) -> int:
		chests.pop_front()
		return 1


func _run() -> void:
	_check(await _test_layouts() == true, "layout tests ran to the end")
	_check(await _test_answered_once() == true, "answered once tests ran to the end")
	_check(await _test_hidden_page_asks_nothing() == true, "hidden page tests ran to the end")
	_check(await _test_questions_cover_the_window() == true, "window cover tests ran to the end")
	_check(await _test_answer_in_a_smaller_window() == true, "smaller window tests ran to the end")
	_check(await _test_leaderboard() == true, "leaderboard tests ran to the end")
	_check(await _test_worn_card() == true, "worn card tests ran to the end")
	_check(_test_orb_card() == true, "orb card tests ran to the end")
	_check(await _test_black_screen_upright() == true, "upright black screen tests ran to the end")
	_check(await _test_treasure_after_the_roads() == true, "treasure after the roads tests ran to the end")
	_check(await _test_counters() == true, "counter tests ran to the end")
	_check(await _test_upright_popups() == true, "upright popup tests ran to the end")
	_check(_test_every_script_has_its_row() == true, "notes tests ran to the end")
	_check(await _test_pages_in_the_scene() == true, "scene tests ran to the end")
	for scratch: String in [SAVE, ACCOUNT, MAP]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	_report("UI pages")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## A left press, for the handlers that are handed one.
func _press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press


## A hero some way into a run: a bag of every kind at a few levels and rarities, a unique and three
## skill nodes among them, a set worn, every orb and rune, a grown tree, an heirloom, a curse.
func _hero() -> Inventory:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var hero := Inventory.new()
	hero.level = 30
	hero.xp = 123
	hero.gold = 123456789.0
	hero.kills = 4321
	hero.dungeon_depth = 6
	hero.super_orbs = 3
	hero.farthest_land = MapBuilder.START_LAND_RADIUS + 7 * MapBuilder.WALL_STEP
	hero.tips.append("first_orb")
	var rarities := [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON, ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]
	var kinds := LootTable.KINDS.keys()
	for at in kinds.size():
		var tiers: Array = LootTable.KINDS[kinds[at]]["tiers"]
		hero.add(Item.rolled(tiers[0], rarities[at % rarities.size()], rng, 1 + at % 3))
	for id: String in UniqueTable.ids().slice(0, 3):
		hero.add(Item.rolled_unique(id, rng, 2))
		hero.uniques_found.append(id)
	for tier in 3:
		hero.add(Item.rolled("Strength Node", ItemRarity.Rarity.COMMON, rng, 1, tier + 1, 3))
	# Worn: the first piece of each slot the doll will take, at level 1, which asks for no attribute.
	for kind: String in kinds:
		var piece := Item.rolled(LootTable.KINDS[kind]["tiers"][0], ItemRarity.Rarity.RARE, rng, 1)
		var sockets := hero.equipment.sockets_for(piece)
		if not sockets.is_empty() and hero.equipment.item_at(sockets[0]) == null \
				and hero.equipment.displaced_by(sockets[0], piece).is_empty():
			hero.add(piece)
			hero.equip(piece, sockets[0])
	for orb: String in OrbTable.orbs():
		hero.add_orb(orb, 12)
	for rune: String in RuneTable.names():
		hero.add_rune(rune, 3)
	for path: String in ["0", "0.0", "0.1", "0.2", "0.0.0", "0.0.1", "0.1.0"]:
		hero.skills.stones[path] = Item.rolled("Strength Node", ItemRarity.Rarity.COMMON, rng, 1, 3, 3)
	var heirloom := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 3)
	heirloom.plus = 1
	hero.stash().add(heirloom)
	hero.curses = [Curses.IRON_FOES]
	return hero


## A cloud that answers from a script, signed in or not, with a board fifty long.
func _cloud(signed_in: bool, named := "") -> Cloud:
	var cloud := Cloud.new(ACCOUNT)
	cloud.token = "token" if signed_in else ""
	cloud.provider = "google"
	cloud.player_name = named
	cloud.inventory_path = "user://test_ui_pages_no_save.json"
	cloud.transport = func(_method: int, _route: String, _body: Variant, _bearer: String) -> Dictionary:
		return {"status": 0, "data": {}}
	var top := []
	for place in Cloud.TOP:
		top.append({"rank": place + 1, "name": "Adventurer the %dth of Long Names" % place,
				"score": 1000 - place * 7, "reached_at": 1790000000000})
	for board: String in Cloud.BOARDS:
		cloud.boards[board] = {"top": top, "me": {"score": 512, "rank": 12}}
	return cloud


## Every page there is, by name: each a call that builds it for `ui_scale` over `hero`, stands it under
## the root as the main scene would and returns it. A call that needs a frame between its steps awaits.
func _pages(hero: Inventory) -> Dictionary:
	var town_cell := _view.start_town - _view.origin
	var town := func(scale: float) -> TownPage:
		var page := TownPage.new(hero, SAVE, scale)
		page.view = _view
		root.add_child(page)
		page._stock_rng.seed = WORLD_SEED
		page.open("Testholm on the Water", PackedStringArray(TownPage.COUNTERS), town_cell, _view.start_town,
				TownWorld.Tier.FORTRESS)
		return page
	var counter := func(scale: float, service: String) -> TownPage:
		var page: TownPage = town.call(scale)
		page._on_tab_pressed(service)
		return page
	var black := func(scale: float) -> TranscendPage:
		var page := TranscendPage.new(hero, scale)
		root.add_child(page)
		return page
	var settings := func(scale: float) -> SettingsPage:
		var page := SettingsPage.new(scale)
		page.inventory = hero
		page.inventory_path = SAVE
		page.cloud = _cloud(true, "Adventurer")
		page.hotkeys = [["i", "Items"], ["k", "Skill tree"], ["c", "Character"], ["o", "Settings"]]
		root.add_child(page)
		# The cloud is no part of the tree: it goes with the page.
		page.tree_exited.connect(page.cloud.free)
		return page
	var board := func(scale: float, signed_in: bool, named: String) -> LeaderboardPage:
		var cloud := _cloud(signed_in, named)
		var page := LeaderboardPage.new(cloud, func() -> int: return 20, scale)
		root.add_child(page)
		page.tree_exited.connect(cloud.free)
		return page
	var card := func(scale: float, alt: bool) -> Control:
		# A square in the window's far corner, where the card has the least room, and its card.
		var holder := Control.new()
		holder.theme = UITheme.theme()
		root.add_child(holder)
		var slot := ItemSlot.make(hero.items[2])
		slot.scale = Vector2(scale, scale)
		slot.position = root.get_visible_rect().size - Vector2.ONE * (ItemSlot.SIDE + 4) * scale
		holder.add_child(slot)
		var item_card := ItemCard.new(scale)
		item_card.equipment = hero.equipment
		holder.add_child(item_card)
		# Written by hand: left running, it would ask about the real cursor every frame.
		item_card.set_process(false)
		await process_frame
		ItemDetails.fill(item_card._rows, slot.item, ItemCard.WIDTH)
		item_card._rows.add_child(ItemCard.key_row(item_card.hints_for(slot, alt)))
		item_card.show()
		item_card._worn.visible = alt and item_card.write_second(slot)
		item_card._place(slot.get_global_transform() * Rect2(Vector2.ZERO, slot.size))
		await process_frame
		item_card._place(slot.get_global_transform() * Rect2(Vector2.ZERO, slot.size))
		return holder
	# The piece in the grid's first square, the one square sure to be in sight, opened.
	var select_first := func(page: BagPage) -> void:
		for section: Node in page._sections.get_children():
			if section is GridContainer:
				page._select_item(section.get_child(0).get_meta("bag_index"))
				return
	return {
		"bag": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale)
			root.add_child(page)
			return page,
		"bag_selected": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale)
			root.add_child(page)
			select_first.call(page)
			return page,
		"bag_question": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale)
			root.add_child(page)
			page._ask("test", "Discard", "Discard 12 level 3 items?", "Discard", "LightDangerButton",
					func() -> void: pass)
			return page,
		"bag_orb_card": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale)
			root.add_child(page)
			await _frames(2)
			page.layout()
			var slot: OrbSlot = page._orb_tray.get_child(page._orb_tray.get_child_count() - 1)
			page._on_orb_hovered(slot.orb, slot)
			return page,
		"bag_at_counter": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale)
			root.add_child(page)
			page.shop(PackedStringArray([TownServices.GEAR]))
			select_first.call(page)
			return page,
		"heirlooms": func(scale: float) -> Control:
			var page := BagPage.new(hero, "", scale, true)
			root.add_child(page)
			select_first.call(page)
			return page,
		"skills": func(scale: float) -> Control:
			var page := SkillsPage.new(hero, "", scale)
			root.add_child(page)
			return page,
		"town_board": func(scale: float) -> Control: return counter.call(scale, TownServices.BOUNTIES),
		"town_board_taken": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.BOUNTIES)
			if BountyBoard.active_spot(hero.towns).is_empty():
				BountyBoard.accept(hero.towns, BountyBoard.bounties(page._drawer)[0])
			page.redraw()
			return page,
		"town_gear": func(scale: float) -> Control: return counter.call(scale, TownServices.GEAR),
		"town_gear_offer": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.GEAR)
			page._on_shelf_input(_press(), 0)
			return page,
		"town_orbs": func(scale: float) -> Control: return counter.call(scale, TownServices.ORBS),
		"town_smith_idle": func(scale: float) -> Control: return counter.call(scale, TownServices.SMITH),
		"town_smith": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.SMITH)
			page.bag_changed(hero.items[3])
			return page,
		"town_fortune": func(scale: float) -> Control: return counter.call(scale, TownServices.FORTUNE),
		"town_fortune_told": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.FORTUNE)
			page._tell(FortuneTeller.ROADS)
			return page,
		"town_fortune_appraised": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.FORTUNE)
			page.bag_changed(hero.items[3])
			page._tell(FortuneTeller.APPRAISE)
			return page,
		"town_way_out": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.FORTUNE)
			page._ask_way_out()
			return page,
		"town_banish": func(scale: float) -> Control:
			var page: TownPage = counter.call(scale, TownServices.FORTUNE)
			page._banishing = true
			page._banish_pick = UniqueTable.ids()[0]
			page.redraw()
			return page,
		"black_choice": func(scale: float) -> Control: return black.call(scale),
		"black_curses": func(scale: float) -> Control:
			var page: TranscendPage = black.call(scale)
			page._show_curses()
			return page,
		"black_create": func(scale: float) -> Control:
			var page: TranscendPage = black.call(scale)
			page._open(page._create_page, true)
			return page,
		"black_upgrade": func(scale: float) -> Control:
			var page: TranscendPage = black.call(scale)
			page._open(page._upgrade_page)
			return page,
		"black_upgrade_aimed": func(scale: float) -> Control:
			var page: TranscendPage = black.call(scale)
			page._open(page._upgrade_page)
			page._upgrade_page._super_press(SuperOrbTable.REPLACEMENT, hero.stash().items[0])
			return page,
		"black_stones": func(scale: float) -> Control:
			var page: TranscendPage = black.call(scale)
			page._open(page._stones_page)
			return page,
		"settings": func(scale: float) -> Control: return settings.call(scale),
		"settings_reset": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._ask(true)
			return page,
		"settings_controls": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._open_controls()
			return page,
		"settings_credits": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._open_credits()
			return page,
		"settings_developer": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._open_dev()
			return page,
		"settings_balancing": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._open_balance()
			return page,
		"settings_generator": func(scale: float) -> Control:
			var page: SettingsPage = settings.call(scale)
			page._open_generator()
			return page,
		"collection": func(scale: float) -> Control:
			var page := CollectionPage.new(hero, scale)
			root.add_child(page)
			return page,
		"achievements": func(scale: float) -> Control:
			var page := AchievementsPage.new(hero, scale)
			root.add_child(page)
			return page,
		"character": func(scale: float) -> Control:
			var page := CharacterPage.new(hero, scale)
			root.add_child(page)
			return page,
		"leaderboard_sign_in": func(scale: float) -> Control: return board.call(scale, false, ""),
		"leaderboard_name": func(scale: float) -> Control: return board.call(scale, true, ""),
		"leaderboard": func(scale: float) -> Control: return board.call(scale, true, "Adventurer"),
		"bounties": func(scale: float) -> Control:
			var page := BountyList.new(hero, _view, SAVE, scale)
			root.add_child(page)
			return page,
		"cloud_question": func(scale: float) -> Control:
			var summary := {"level": 30, "play_seconds": 7260, "saved_at": 1790000000, "dungeon_floors": 20}
			var page := CloudQuestion.new({"local": summary, "cloud": summary}, scale)
			root.add_child(page)
			return page,
		"text_prompt": func(scale: float) -> Control:
			var page := TextPrompt.new("Rename", "Adventurer", "Rename", Inventory.NAME_MOST, scale)
			root.add_child(page)
			return page,
		"dialogue": func(scale: float) -> Control:
			var page := DialogueBox.new("Fortuneteller", ["The ice takes this world back, and you wake up in "
					+ "another. You'll lose the bag, the gold, the orbs, the levels and the land."],
					load(DialogueBox.PORTRAITS % "fortuneteller"))
			root.add_child(page)
			page.pop_up(scale)
			return page,
		"dialogue_smith": func(scale: float) -> Control:
			var page := DialogueBox.new("Blacksmith", ["Clear the board and there is something extra in it."],
					load(DialogueBox.PORTRAITS % "blacksmith"))
			root.add_child(page)
			page.pop_up(scale)
			return page,
		"dialogue_hero": func(scale: float) -> Control:
			var page := DialogueBox.new(hero.hero(), ["A sword. Broken, but a sword."],
					load(DialogueBox.PORTRAITS % DialogueBox.PLAYER), true)
			root.add_child(page)
			page.pop_up(scale)
			return page,
		"item_card": func(scale: float) -> Control: return await card.call(scale, false),
		"item_card_worn": func(scale: float) -> Control: return await card.call(scale, true),
	}


## Every page in every window of `SHAPES`, settled, with nothing wrong in it (`_wrongs`). The project
## stretches a headless window's canvas to its 1152x648; turned off here, as the main scene turns it
## off on a real window, so a 360 px window is 360 px to lay out in.
func _test_layouts() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	var was_animations := Settings.animations
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# As the screenshots are taken: pages where they settle, not part way through popping in.
	Settings.animations = Settings.Anim.NONE
	_map = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(_map)
	_view = MapBuilder.create(_map, TownWorld.generate(WORLD_SEED, ORIGIN), ORIGIN, WORLD_SEED)
	var folder := OS.get_environment(DUMP)
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	for shape: Array in SHAPES:
		var window: Vector2i = shape[0]
		var scale: float = shape[1]
		root.size = window
		await _frames(2)
		_check(root.get_visible_rect().size == Vector2(window), "the window is %s to lay out in (%s)"
				% [window, root.get_visible_rect().size])
		_check(UITheme.pick_scale(Vector2(window)) == scale, "and is drawn at %s" % scale)
		var hero := _hero()
		var pages := _pages(hero)
		for page_name: String in pages:
			var page: Control = await (pages[page_name] as Callable).call(scale)
			await _frames(2)
			if page.has_method("layout"):
				page.call("layout")
			await _frames(3)
			for wrong: String in _wrongs(page, Vector2(window)):
				_check(false, "%s in %dx%d: %s" % [page_name, window.x, window.y, wrong])
			if not folder.is_empty():
				var file := FileAccess.open(folder.path_join("%s_%dx%d.json" % [page_name, window.x, window.y]),
						FileAccess.WRITE)
				file.store_string(JSON.stringify(_dump(page, page, []), "\t"))
			page.queue_free()
			await process_frame
	_map.queue_free()
	_view = null
	Settings.animations = was_animations
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true


## A Control's rect in window pixels, its scale and its ancestors' counted.
func _rect(control: Control) -> Rect2:
	return (control.get_global_transform() * Rect2(Vector2.ZERO, control.size)).abs()


## What a page keeps under it that is drawn as a thing of its own: a panel, a card or a loose button,
## through whatever only holds them -- a popup's holder, a page inside a page. Never a shade or a wash.
func _panels(node: Node, found: Array[Control]) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control == null or not control.visible or control is ColorRect:
			continue
		if control is Container or control is BaseButton:
			found.append(control)
		else:
			_panels(control, found)


## What is wrong with how `page` lies in a window of `window` pixels, a sentence each, and none where
## all of this holds:
##   - every panel, card and loose button of the page lies inside the window;
##   - every button that can be pressed is inside the window, or in a scroll that brings it there;
##   - no line that neither wraps nor cuts itself is wider than what holds it;
##   - every word is in one of the theme's two fonts, each at its own size.
func _wrongs(page: Control, window: Vector2) -> PackedStringArray:
	var wrong := PackedStringArray()
	var inside := Rect2(Vector2.ZERO, window).grow(SLACK)
	var panels: Array[Control] = []
	_panels(page, panels)
	for panel: Control in panels:
		if not inside.encloses(_rect(panel)):
			wrong.append("%s stands at %s, outside the window" % [_path(page, panel), _rect(panel)])
	var pixellari := UITheme.theme().default_font
	var ark := UITheme.theme().get_font("font", "SmallLabel")
	for node: Node in page.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control is BaseButton and not (control as BaseButton).disabled and not inside.encloses(_rect(control)) \
				and not _scrolled(control):
			wrong.append("%s can be pressed at %s, outside the window" % [_path(page, control), _rect(control)])
		var label := control as Label
		var holder := control.get_parent() as Control
		# A numeral hung off its square's corner on purpose reaches past it (`OrbSlot.count_label`).
		if label != null and holder != null and label.autowrap_mode == TextServer.AUTOWRAP_OFF \
				and not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
				and not (label.anchor_right == 1.0 and (label.offset_left < 0.0 or label.offset_right > 0.0)) \
				and label.size.x > holder.size.x + SLACK:
			wrong.append("%s (\"%s\") is %s wide in %s" % [_path(page, label), label.text, label.size.x,
					holder.size.x])
		var lettered: bool = label != null or control is LineEdit \
				or (control is Button and not (control as Button).text.is_empty())
		if lettered:
			var font := control.get_theme_font("font")
			var size := control.get_theme_font_size("font_size")
			if not ((font == pixellari and size == UITheme.FONT_SIZE) or (font == ark and size == UITheme.SMALL_FONT_SIZE)):
				wrong.append("%s is lettered at %d in neither of the theme's two fonts" % [_path(page, control), size])
	return wrong


## Whether `control` stands in something that scrolls it into view.
func _scrolled(control: Control) -> bool:
	var above := control.get_parent()
	while above != null:
		if above is ScrollContainer:
			return true
		above = above.get_parent()
	return false


## `node`'s path under `page`, which no two runs spell differently: a name the code gave it, or its
## class and its place among its siblings where Godot named it.
func _path(page: Node, node: Node) -> String:
	var steps := PackedStringArray()
	while node != page and node != null:
		steps.append(str(node.name) if not str(node.name).begins_with("@")
				else "%s%d" % [node.get_class(), node.get_index()])
		node = node.get_parent()
	steps.reverse()
	return "/".join(steps)


## `node` and every Control under it, in tree order, added to `rows` for the layout dump.
func _dump(page: Control, node: Control, rows: Array) -> Array:
	var rect := _rect(node)
	var row := {"path": _path(page, node), "class": node.get_class(), "visible": node.is_visible_in_tree(),
			"rect": [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
				snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]}
	var text: Variant = node.get("text")
	if text is String and not (text as String).is_empty():
		row["text"] = text
	rows.append(row)
	for child: Node in node.get_children():
		if child is Control:
			_dump(page, child, rows)
	return rows


## The first button under `node` whose face begins with `text`, live or dead, or null.
func _button(node: Node, text: String) -> Button:
	for button: Button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			return button
	return null


## A popup is answered once. Its buttons stay under the cursor while it shrinks away (`Juice.LEAVE_TIME`),
## and a second press on one then -- a double click -- is no second answer: not a deed done twice, not
## an orb spent twice, not a deed done after Cancel.
func _test_answered_once() -> bool:
	var hero := _hero()
	var bag := BagPage.new(hero, "", 2.0)
	root.add_child(bag)
	await process_frame
	var done: Array = []
	var ask := func() -> Control:
		bag._ask("test_once", "Discard", "Discard it?", "Discard", "LightDangerButton",
				func() -> void: done.append(true))
		return bag._confirm
	var asked: Control = ask.call()
	(asked.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	_button(asked, "Discard").pressed.emit()
	_button(asked, "Discard").pressed.emit()
	_check(done.size() == 1, "a question's Yes pressed twice does its deed once (%d)" % done.size())
	_check(hero.tips.count(BagPage.SKIP_CONFIRM + "test_once") == 1, "and its tick is written once")
	hero.tips.erase(BagPage.SKIP_CONFIRM + "test_once")
	asked = ask.call()
	_button(asked, "Cancel").pressed.emit()
	_button(asked, "Discard").pressed.emit()
	_check(done.size() == 1, "and a Yes pressed after Cancel does nothing")
	bag.queue_free()

	# An aimed super orb asks which modifier: the line pressed twice spends one orb.
	var heirlooms := BagPage.new(hero, "", 2.0, true, true)
	root.add_child(heirlooms)
	await process_frame
	var treasure: Item = hero.stash().items[0]
	hero.super_orbs = 3
	heirlooms._super_press(SuperOrbTable.REPLACEMENT, treasure)
	_check(heirlooms._confirm != null, "an aimed super orb asks which modifier")
	var lines: Array = heirlooms._confirm.find_children("*", "Button", true, false).filter(
			func(button: Button) -> bool: return not button.disabled and button.text != "Cancel")
	_check(not lines.is_empty(), "with a line to press")
	(lines[0] as Button).pressed.emit()
	(lines[0] as Button).pressed.emit()
	_check(hero.super_orbs == 2, "and a line pressed twice spends one orb (%d left of 3)" % hero.super_orbs)
	heirlooms.queue_free()

	# Her answer's Dismiss, ticked: the reading is written down once. And the way out is not taken
	# by a Transcend pressed after Cancel.
	var town := TownPage.new(hero, SAVE, 2.0)
	root.add_child(town)
	await process_frame
	town.open("Testholm", PackedStringArray([TownServices.FORTUNE]), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.SMALL)
	town._tell(FortuneTeller.ROADS)
	var told := town._told
	(told.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	_button(told, "Dismiss").pressed.emit()
	_button(told, "Dismiss").pressed.emit()
	_check(hero.tips.count(TownPage.SKIP_TOLD + FortuneTeller.ROADS) == 1,
			"a ticked Dismiss pressed twice writes its reading once")
	var left: Array = []
	town.transcend_pressed.connect(func() -> void: left.append(true))
	town._ask_way_out()
	told = town._told
	_button(told, "Cancel").pressed.emit()
	_button(told, "Transcend").pressed.emit()
	_check(left.is_empty(), "and a Transcend pressed after Cancel leaves the world be")
	town._ask_way_out()
	_button(town._told, "Transcend").pressed.emit()
	_check(left.size() == 1, "where the Transcend of a question still up takes the way out")
	town.queue_free()
	await process_frame
	return true


## A page that goes away takes its question with it: left up where nobody can answer it, it would still
## be the window's to every hotkey and banner that asks (`asking`, `telling`).
func _test_hidden_page_asks_nothing() -> bool:
	var hero := _hero()
	var bag := BagPage.new(hero, "", 2.0)
	var town := TownPage.new(hero, SAVE, 2.0)
	root.add_child(bag)
	root.add_child(town)
	await process_frame
	bag._ask("test_hidden", "Discard", "Discard it?", "Discard", "LightDangerButton", func() -> void: pass)
	_check(bag.asking(), "a question up is asked")
	bag.hide()
	_check(not bag.asking(), "and a bag put away asks nothing")
	bag.show()
	_check(not bag.asking() and bag._confirm == null, "nor does it ask again when it comes back")
	town.open("Testholm", PackedStringArray([TownServices.FORTUNE]), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.SMALL)
	town._tell(FortuneTeller.TREASURE)
	_check(town.telling(), "her answer up is told")
	town.hide()
	_check(not town.telling(), "and a town left tells nothing")
	bag.queue_free()
	town.queue_free()
	await process_frame
	return true


## Every popup stands over the whole window and goes on standing over it as the window is turned or
## resized, its panel in the middle and inside it -- the cloud's two saves side by side or one over the
## other as the window now is -- and a speaker's box goes to the window's new foot; and the cloud's
## question, which has no way out but its two buttons, lets no key through to the pages under it.
func _test_questions_cover_the_window() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	var was_animations := Settings.animations
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Settled, so a panel is measured where it stands and not part way through swelling in.
	Settings.animations = Settings.Anim.NONE
	root.size = Vector2i(1152, 648)
	await _frames(2)
	var hero := _hero()
	var listener := Listener.new()
	root.add_child(listener)
	var bag := BagPage.new(hero, "", 1.0)
	var town := TownPage.new(hero, SAVE, 1.0)
	var prompt := TextPrompt.new("Rename", "Adventurer", "Rename", Inventory.NAME_MOST, 1.0)
	var summary := {"level": 3, "play_seconds": 60, "saved_at": 1790000000, "dungeon_floors": 20}
	var question := CloudQuestion.new({"local": summary, "cloud": summary}, 1.0)
	var speaker := DialogueBox.new("Blacksmith", ["Clear the board and there is something extra in it."],
			load(DialogueBox.PORTRAITS % "blacksmith"))
	for made: Control in [bag, town, prompt, speaker, question]:
		root.add_child(made)
	speaker.pop_up(1.0)
	await process_frame
	bag._ask("test_cover", "Discard", "Discard it?", "Discard", "LightDangerButton", func() -> void: pass)
	town.open("Testholm", PackedStringArray([TownServices.FORTUNE]), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.SMALL)
	town._tell(FortuneTeller.ROADS)
	var popups := {"the bag's question": bag._confirm, "her answer": town._told, "the text prompt": prompt,
			"the cloud's question": question}
	for turn: Vector2i in [Vector2i(1152, 648), Vector2i(360, 780), Vector2i(780, 360)]:
		root.size = turn
		await _frames(3)
		for what: String in popups:
			var holder: Control = popups[what]
			var panel: Control = holder.find_children("*", "VBoxContainer", false, false)[0]
			_check(_rect(holder).is_equal_approx(Rect2(Vector2.ZERO, Vector2(turn))),
					"%s covers a %dx%d window (%s)" % [what, turn.x, turn.y, _rect(holder)])
			_check(_rect(panel).get_center().distance_to(Vector2(turn) / 2.0) <= 1.0,
					"with its panel in the middle (%s)" % _rect(panel).get_center())
			_check(Rect2(Vector2.ZERO, Vector2(turn)).grow(SLACK).encloses(_rect(panel)),
					"and inside the window (%s)" % _rect(panel))
		var box := _rect(speaker._panel)
		_check(Rect2(Vector2.ZERO, Vector2(turn)).grow(SLACK).encloses(box)
				and absf(box.end.y - (turn.y - DialogueBox.FOOT_GAP)) <= 1.0
				and absf(box.get_center().x - turn.x / 2.0) <= 1.0,
				"a speaker's box stands at the foot of a %dx%d window (%s)" % [turn.x, turn.y, box])
	speaker.queue_free()

	# The prompt takes every key itself: out of the way, so what is not heard is the question's doing.
	prompt.queue_free()
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	root.push_input(key)
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	root.push_input(back)
	_check(listener.heard.is_empty(), "no key gets past the cloud's question (%d did)" % listener.heard.size())
	_check(town.telling() and bag.asking(), "nor Escape, to close what stands under it")
	question.queue_free()
	await process_frame
	root.push_input(key)
	_check(listener.heard.size() == 1, "and one does once it is answered")
	for made: Node in [listener, bag, town]:
		made.queue_free()
	Settings.animations = was_animations
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true


## Her longest answer, the appraisal, scrolls in what the window leaves it -- and in what a smaller
## window leaves it, once the window is made smaller under it. The main scene picks `ui_scale` once, so
## the smaller window is laid out again at the scale it had.
func _test_answer_in_a_smaller_window() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1152, 648)
	await _frames(2)
	var hero := _hero()
	var town := TownPage.new(hero, SAVE, 2.0)
	root.add_child(town)
	await process_frame
	town.open("Testholm", PackedStringArray([TownServices.FORTUNE]), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.SMALL)
	town.bag_changed(hero.items[3])
	town._tell(FortuneTeller.APPRAISE)
	await _frames(3)
	var panel: Control = town._told.get_node(TownPage.TOLD_PANEL)
	var tall := town._told_scroll.custom_minimum_size.y
	_check(tall > 0.0 and Rect2(0, 0, 1152, 648).grow(SLACK).encloses(_rect(panel)),
			"her appraisal stands inside the window (%s)" % _rect(panel))
	root.size = Vector2i(780, 360)
	await _frames(2)
	town.layout()
	await _frames(3)
	_check(town._told_scroll.custom_minimum_size.y < tall, "a smaller window leaves its scroll less (%s of %s)"
			% [town._told_scroll.custom_minimum_size.y, tall])
	_check(Rect2(0, 0, 780, 360).grow(SLACK).encloses(_rect(panel)), "and it still stands inside it (%s)" % _rect(panel))
	town.queue_free()
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true


## The leaderboard: a name being typed is not lost to a redraw, the board is read only once the save
## has gone up, and a tab opens its board.
func _test_leaderboard() -> bool:
	var cloud := _cloud(true)
	var sent: Array = []
	cloud.transport = func(_method: int, route: String, _body: Variant, _bearer: String) -> Dictionary:
		sent.append("asked " + route.get_slice("?", 0))
		await process_frame
		sent.append("answered " + route.get_slice("?", 0))
		return {"status": 200, "data": {"name": null, "top": [], "me": {}}}
	var page := LeaderboardPage.new(cloud, func() -> int: return 20, 2.0)
	root.add_child(page)
	await process_frame
	var field: LineEdit = page.find_children("*", "LineEdit", true, false)[0]
	field.grab_focus()
	field.text = "Ada"
	field.caret_column = 2
	field.text_changed.emit("Ada")
	_check(field.has_focus() and not _button(page, "Choose name").disabled, "a name of three letters can be chosen")
	# Every call the cloud makes says `changed`, its thirty-second tick among them.
	cloud.changed.emit()
	cloud.changed.emit()
	var fields := page.find_children("*", "LineEdit", true, false)
	_check(fields.size() == 1 and fields[0] == field and is_instance_valid(field) and field.is_inside_tree(),
			"a redraw keeps the field being typed in")
	_check(field.has_focus() and field.text == "Ada" and field.caret_column == 2,
			"with its cursor where it was (%s, %d)" % [field.text, field.caret_column])
	var under := field.get_parent()
	_check(under.get_child(field.get_index() + 1) == _button(page, "Choose name")
			and under.get_child(field.get_index() - 1) is HBoxContainer,
			"and it stands where it stood: under \"You\", over its button")
	_check(not _button(page, "Choose name").disabled, "whose button was made again, live")

	# Opened, the page sends the save first and reads the board after: a board read before the upload
	# has landed is a board without the descent just made.
	sent.clear()
	page.open()
	await _frames(4)
	_check(sent.find("answered /me") >= 0 and sent.find("answered /me") < sent.find("asked /leaderboard"),
			"the board is asked for once the sync is over (%s)" % [sent])

	# A name given: the field goes, and the player's own row stands in its place.
	cloud.player_name = "Ada"
	cloud.boards["walls"] = {"top": [{"rank": 1, "name": "Ada", "score": 7, "reached_at": 0}],
			"me": {"score": 7, "rank": 1}}
	cloud.changed.emit()
	_check(page.find_children("*", "LineEdit", true, false).is_empty(), "a name chosen takes the field away")
	_button(page, "Walls").pressed.emit()
	var said := page.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	_check("Walls" in said and "7" in said and not "Depth" in said,
			"the Walls tab opens its board under its own heading (%s)" % [said])
	# The call the tab made is still out: the cloud outlives it.
	await _frames(3)
	page.queue_free()
	cloud.free()
	await process_frame
	return true


## The second card under Alt says "· worn" on the worn piece's rarity line -- on that line whatever
## stands over it: a piece with a plus wears a bar over its name, which pushed the mark onto the name.
## And a block written over another holds the new one alone.
func _test_worn_card() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var card := ItemCard.new(1.0)
	root.add_child(card)
	card.set_process(false)
	await process_frame
	card.equipment = Equipment.new()
	var worn := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 1)
	worn.plus = 1
	card.equipment.worn[Equipment.Socket.WEAPON] = worn
	var slot := ItemSlot.make(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 1))
	_check(card.write_second(slot), "a piece held against a worn one has a second card")
	var written: Array = card._worn_rows.get_children().filter(func(row: Node) -> bool: return row is Label)
	_check(card._worn_rows.get_child(0).name == ItemDetails.ASCENSION_BAR, "a plussed piece's bar stands over its name")
	_check((written[0] as Label).text == worn.display_name(), "its name says its name (%s)" % (written[0] as Label).text)
	_check((written[1] as Label).text.ends_with(" · worn") and (written[1] as Label).text.begins_with("Rare"),
			"and its rarity line says it is worn (%s)" % (written[1] as Label).text)
	var rows := card._worn_rows.get_child_count()
	card.write_second(slot)
	_check(card._worn_rows.get_child_count() == rows, "written again, the card holds the one block (%d, %d)"
			% [card._worn_rows.get_child_count(), rows])
	var block := VBoxContainer.new()
	ItemDetails.fill(block, worn, 150.0)
	var once := block.get_child_count()
	ItemDetails.fill(block, worn, 150.0)
	_check(block.get_child_count() == once, "and so does any block filled twice (%d, %d)" % [block.get_child_count(), once])
	block.free()
	slot.free()
	card.queue_free()
	await process_frame
	return true


## The orb's card: its name, what it does, and where the player stands with it -- or the note whoever
## fills it hands over, a vendor's price, in that line's place.
func _test_orb_card() -> bool:
	var holder := Control.new()
	holder.theme = UITheme.theme()
	root.add_child(holder)
	var card := OrbCard.new()
	holder.add_child(card)
	var says := func() -> Array:
		return card._rows.get_children().map(func(row: Label) -> String: return row.text)
	var orb: String = OrbTable.orbs()[0]
	card.fill(orb, 3)
	_check(says.call() == [orb, OrbTable.describe(orb)], "an orb held says its name and what it does (%s)" % [says.call()])
	card.fill(orb, 0)
	_check(says.call() == [orb, OrbTable.describe(orb), "Not found yet"], "one never found says so")
	card.fill(SuperOrbTable.ASCENSION, 0)
	_check(says.call() == [SuperOrbTable.ASCENSION, SuperOrbTable.describe(SuperOrbTable.ASCENSION),
			"None left to spend"], "a super orb with none left says that")
	card.fill(orb, 0, "120 gold", Palette.RUST)
	_check(says.call() == [orb, OrbTable.describe(orb), "120 gold"]
			and (card._rows.get_child(2) as Label).get_theme_color("font_color") == Palette.RUST,
			"a vendor's note stands in the status line's place, in its own colour")
	var rune: String = RuneTable.names()[0]
	card.fill(rune, 1)
	_check(says.call() == [rune, str(RuneTable.RUNES[rune]["does"])], "and a rune is the same card over its own table")
	_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE and card.theme_type_variation == "TextPanel",
			"a cream card that never takes a press")
	holder.queue_free()
	return true


## The black screen held upright: its cards one over another, the curses' table inside the window --
## and with no room left for the arrow beside it, Escape (a phone's back) still the way back.
func _test_black_screen_upright() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	var was_animations := Settings.animations
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(324, 576)
	Settings.animations = Settings.Anim.NONE
	await _frames(2)
	var black := TranscendPage.new(_hero(), 1.0)
	root.add_child(black)
	await _frames(2)
	var cards: GridContainer = black._choice.find_children("*", "GridContainer", true, false)[0]
	_check(cards.columns == 1, "held upright the four cards stand one over another")
	black._show_curses()
	await _frames(2)
	_check(not black._choice.visible and black._curse_face != null, "a card opens its face")
	_check(_rect(black._curse_face).size.x <= 324.0, "the curses' table gives up width to stand in the window (%s)"
			% _rect(black._curse_face).size.x)
	_check(not black._back.visible, "which leaves the arrow beside it nowhere to stand")
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	black._unhandled_input(back)
	_check(black._choice.visible and black._curse_face == null, "and Escape still goes back to the choice")
	var choice := black._choice
	black._unhandled_input(back)
	_check(black._choice == choice, "where it is nothing: there is no way back into the world")
	black._open(black._create_page, true)
	black._unhandled_input(back)
	_check(black._choice.visible and not black._create_page.visible, "as it does from a page")
	black.queue_free()
	Settings.animations = was_animations
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true


## The fortuneteller's treasure only ever points at a chest the player has not seen -- one the roads,
## bought in the same visit, have just brought into sight is no longer it.
func _test_treasure_after_the_roads() -> bool:
	var hero := _hero()
	var roads := Roads.new()
	roads.origin = ORIGIN
	var town := TownPage.new(hero, SAVE, 2.0)
	town.view = roads
	root.add_child(town)
	await process_frame
	town.open("Testholm", PackedStringArray([TownServices.FORTUNE]), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.SMALL)
	var starred: Array = []
	town.chest_bought.connect(func(cell: Vector2i) -> void: starred.append(cell))
	_check(town._near_chest == Vector2i(3, 0), "walking in, the nearest hidden chest is the near one")
	town._on_reading_pressed(FortuneTeller.ROADS)
	town._close_told()
	_check(roads.chests == [Vector2i(9, 0)], "the roads bring the near chest into sight")
	town._on_reading_pressed(FortuneTeller.TREASURE)
	_check(starred == [Vector2i(9, 0)], "and the star goes over the chest still hidden (%s)" % [starred])
	_check(FortuneTeller.chest(hero.fortunes) == ORIGIN + Vector2i(9, 0), "which is the one written down")
	town.queue_free()
	await process_frame
	return true


## Every service a town can offer has a counter on the page, and one the page was never taught says so
## and draws nothing -- not a gear shelf with a Restock under another counter's name.
func _test_counters() -> bool:
	_check(TownPage.COUNTERS == TownServices.ORDER, "every service there is gets a tab")
	var hero := _hero()
	var town := TownPage.new(hero, SAVE, 2.0)
	root.add_child(town)
	await process_frame
	town.open("Testholm", PackedStringArray(TownPage.COUNTERS), Vector2i(2, 0), ORIGIN + Vector2i(2, 0),
			TownWorld.Tier.FORTRESS)
	for service: String in TownPage.COUNTERS:
		# Under the runner, which fails on any error: every counter there is draws without one.
		town._on_tab_pressed(service)
		_check(town.open_tab() == service and town._rows.get_child_count() > 1, "the %s counter is drawn" % service)
	town._on_tab_pressed(TownServices.GEAR)
	_check(_button(town._rows, "Restock") != null and town._scroll.visible, "a shelf has its squares and its Restock")
	# The error is the point, and is not printed: the runner would take it for a failure.
	Engine.print_error_messages = false
	town._open_tab = "embassy"
	town._fill()
	Engine.print_error_messages = true
	_check(_button(town._rows, "Restock") == null and not town._scroll.visible,
			"a counter nobody built draws no shelf")
	town.queue_free()
	await process_frame
	return true


## Held upright the cloud's two saves and its two buttons stand one over the other, and a speaker's
## words take what the window leaves beside the portrait.
func _test_upright_popups() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var summary := {"level": 3, "play_seconds": 60, "saved_at": 1790000000, "dungeon_floors": 20}
	for upright: bool in [false, true]:
		root.size = Vector2i(324, 576) if upright else Vector2i(1152, 648)
		await _frames(2)
		var scale := 1.0 if upright else 2.0
		var question := CloudQuestion.new({"local": summary, "cloud": summary}, scale)
		root.add_child(question)
		await process_frame
		var rows: Array = question.find_children("*", "BoxContainer", true, false).filter(
				func(row: Node) -> bool: return row.get_class() == "BoxContainer")
		_check(rows.size() == 2 and rows.all(func(row: BoxContainer) -> bool: return row.vertical == upright),
				"the cloud's two saves and two buttons stand %s" % ("one over the other" if upright else "side by side"))
		question.queue_free()
		var speaker := DialogueBox.new("Blacksmith", ["Clear the board and there is something extra in it."],
				load(DialogueBox.PORTRAITS % "blacksmith"))
		root.add_child(speaker)
		speaker.pop_up(scale)
		await process_frame
		_check((speaker._words.custom_minimum_size.x < DialogueBox.TEXT_WIDTH) == upright,
				"a speaker's words are %s (%s)" % ["narrowed to the window" if upright else "their own width",
					speaker._words.custom_minimum_size.x])
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(SLACK).encloses(_rect(speaker._panel)),
				"and the box stands inside the window (%s)" % _rect(speaker._panel))
		speaker.queue_free()
		await process_frame
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true


## Every script and shader in `Scenes/UI/` has its row in the folder's notes, in the table at their head.
func _test_every_script_has_its_row() -> bool:
	var rows: Array = []
	for line: String in FileAccess.get_file_as_string("res://Scenes/UI/CLAUDE.md").split("\n"):
		if line.begins_with("| `"):
			rows.append(line.get_slice("|", 1))
	_check(rows.size() > 30, "the notes open on a table of the folder's files (%d rows)" % rows.size())
	for file: String in DirAccess.get_files_at("res://Scenes/UI"):
		if file.get_extension() in ["gd", "gdshader"]:
			_check(rows.any(func(row: String) -> bool: return ("`%s`" % file) in row),
					"Scenes/UI/CLAUDE.md has a row for %s" % file)
	return true


## A town in the scene itself, where its page shares the window with the bag: beside it across a
## window, over it held upright (`main_scene._layout_ui`). Every counter of the start village's, in
## every window, with both pages held to what `_wrongs` holds a page to -- and the left-hand pages each
## opened in the room the scene gives them.
func _test_pages_in_the_scene() -> bool:
	var was_size := root.size
	var was_mode := root.content_scale_mode
	var was_animations := Settings.animations
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Settings.animations = Settings.Anim.NONE
	for shape: Array in SHAPES:
		var window: Vector2i = shape[0]
		root.size = window
		await _frames(2)
		for scratch: String in [SAVE, MAP]:
			if FileAccess.file_exists(scratch):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
		main.world_seed = WORLD_SEED
		main.map_seed = 1
		main.inventory_path = SAVE
		main.map_path = MAP
		root.add_child(main)
		await _frames(3)
		_check(main.ui_scale == shape[1], "a %dx%d window is drawn at %s (%s)" % [window.x, window.y, shape[1], main.ui_scale])
		var rng := RandomNumberGenerator.new()
		rng.seed = WORLD_SEED
		for at in 12:
			main.inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 1 + at % 3))
		main.inventory.gold = 1.0e9
		for left: Control in [main.bag_page, main.skills_page, main.settings_page, main.character_page]:
			main._toggle_left_page(left)
			await _frames(3)
			for wrong: String in _wrongs(left, Vector2(window)):
				_check(false, "%s in the scene at %dx%d: %s" % [left.get_script().get_global_name(), window.x, window.y, wrong])
			main._toggle_left_page(left)
		var town: Vector2i = main.view.start_town - main.view.origin
		main.view._show(town, MapBuilder.State.CHARTED)
		main.view.player_cell = town
		main.map.set_player_cell(town)
		main.map.select_cell(town)
		main._on_town_pressed()
		await _frames(3)
		_check(main.town_page.visible and main.bag_page.visible, "a town is its page and the bag together")
		for service: String in main.town_page._tabs:
			main.town_page._on_tab_pressed(service)
			await _frames(3)
			for page: Control in [main.town_page, main.bag_page]:
				for wrong: String in _wrongs(page, Vector2(window)):
					_check(false, "the %s counter's %s at %dx%d: %s" % [service, page.get_script().get_global_name(),
							window.x, window.y, wrong])
			if UITheme.narrow(Vector2(window), main.ui_scale):
				_check(_rect(main.town_page._panel).end.y <= _rect(main.bag_page._panel).position.y + SLACK,
						"held upright the %s counter stands over the bag (%s, %s)" % [service,
							_rect(main.town_page._panel), _rect(main.bag_page._panel)])
			else:
				_check(_rect(main.bag_page._panel).end.x <= _rect(main.town_page._panel).position.x + SLACK,
						"across a window the bag stands beside the %s counter" % service)
		main.queue_free()
		await _frames(2)
	Settings.animations = was_animations
	root.content_scale_mode = was_mode
	root.size = was_size
	await process_frame
	return true
