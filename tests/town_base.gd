extends "res://tests/harness.gd"
## What the town suites share: their scratch files and the helpers their tests are written with.
## (They were one file, tests/test_town.gd, until it outgrew a single read.)

## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_town.json"
## Nor MapSave.SAVE_PATH, for the same reason and one more: this pins a seed, and a pinned seed that
## differs from a save is a request for another world, which replaces it on the first write.
const TEST_MAP_PATH := "user://test_town_map.json"
## The corner of the world the village rolls are read over: enough spots that a village's coin lands
## both ways and that another seed visibly deals other vendors.
const SPOTS := 20
## The tile the priced things are bought and sold on, ten steps out: deep enough that a level band is
## worth real gold and the rounding at the middle of the map is behind us.
const TOWN_CELL := Vector2i(10, 0)


## Which kind of a cleared board's reward `option` is, read off the thing itself, or "" when it is none
## of them as the rules make them: at `tier`, over a board at `ceiling`, in a world with `walls` down.
func _choice_kind(option: Dictionary, tier: int, ceiling: int, walls: int) -> String:
	var at := tier - 1
	if option.has(BountyBoard.CHOICE_ORB):
		var orb := str(option[BountyBoard.CHOICE_ORB])
		var ok := BountyBoard.CHOICE_ORBS.has(orb) and orb in OrbTable.unlocked(walls) \
				and int(option[BountyBoard.CHOICE_COUNT]) == int(BountyBoard.CHOICE_ORBS[orb][at])
		return BountyBoard.ORB_BUNDLE if ok else ""
	if option.has(BountyBoard.CHOICE_GOLD):
		return BountyBoard.GOLD_PILE if float(option[BountyBoard.CHOICE_GOLD]) == BountyBoard.pile_gold(tier, TOWN_CELL) else ""
	if option.has(BountyBoard.CHOICE_XP):
		return BountyBoard.XP_PILE if int(option[BountyBoard.CHOICE_XP]) == BountyBoard.pile_xp(tier, TOWN_CELL) else ""
	var piece: Item = option[BountyBoard.CHOICE_ITEM]
	if piece.rarity == ItemRarity.Rarity.UNIQUE:
		if not (str(piece.unique) in Achievements.STARTERS) or piece.level != ceiling:
			return ""
		return BountyBoard.UNIQUE if piece.plus == 0 \
				else (BountyBoard.ASCENDED_UNIQUE if piece.plus == int(BountyBoard.UNIQUE_PLUS[at]) else "")
	if piece.rarity == ItemRarity.Rarity.RARE:
		return BountyBoard.RARE if piece.plus == 0 and piece.level == ceiling else ""
	if piece.rarity != ItemRarity.Rarity.ELITE:
		return ""
	if piece.plus == int(BountyBoard.EPIC_PLUS[at]) and piece.level == ceiling:
		return BountyBoard.ASCENDED
	# The high piece's material is a lucky draw, so any the level has unlocked will do.
	var level := ceiling + int(BountyBoard.CHOICE_LEVELS[at])
	var item_row: Dictionary = LootTable.ITEMS[piece.type]
	var tier_levels: Array = LootTable.KINDS[item_row["kind"]].get("tier_levels", LootTable.TIER_MIN_LEVEL)
	if piece.plus == 0 and piece.level == level and level >= int(tier_levels[int(item_row["tier"])]):
		return BountyBoard.HIGH
	return ""


## How far along the posting in square `at` of a town's board is.
func _have(drawer: Dictionary, at: int) -> int:
	var posted := BountyBoard.bounties(drawer)
	return 0 if at >= posted.size() else int((posted[at] as Dictionary).get(BountyBoard.HAVE, 0))


## A seeded stream whose very next `randf` does or does not break a piece. `seed` rewinds the stream,
## so the draw probed here is the draw the smith will make.
func _stream_that(breaks: bool) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in 500:
		rng.seed = seed_value
		if (rng.randf() < Blacksmith.BREAK_CHANCE) == breaks:
			rng.seed = seed_value
			return rng
	_check(false, "no seed found whose first draw %s" % ["breaks" if breaks else "holds"])
	return rng


## A left click, for the squares that are worked out from a press rather than pressed themselves.
func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## Every Label's text under `parent`, run together, for a test that asks what a page says.
func _said(parent: Node) -> String:
	var text := ""
	for child: Node in parent.get_children():
		if child is Label and not child.is_queued_for_deletion():
			text += (child as Label).text + " "
		text += _said(child)
	return text


## The first Button under `parent` whose label starts with `text`, or null. The blocks are built fresh
## on every refresh, so a test finds its button rather than holding one.
func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
	return null


## The same, anywhere under `parent`: a board's rows sit in a scroll inside a box inside the page.
## One of the fortuneteller's spell squares, by reading, or null when it is not on her grid.
func _spell(main: Node, reading: String) -> Control:
	return main.town_page._rows.find_child(reading, true, false)


## Whether she is refusing that reading: a square she will not read is greyed and takes no press.
func _dead(main: Node, reading: String) -> bool:
	var square := _spell(main, reading)
	return square != null and square.modulate == OrbSlot.DIM


## What one of her squares says it costs, read off the price under it.
func _price(main: Node, reading: String) -> float:
	return main.town_page._fortune_price(reading)


## Whether the town on `spot` has cast `reading` and so will not cast it again.
func _spent(main: Node, spot: Vector2i, reading: String) -> bool:
	return FortuneTeller.asked(main.inventory.towns.visit(spot), reading)


## A left click on one of her squares, which is how a reading is asked for.
func _ask(main: Node, reading: String) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_spell(main, reading).gui_input.emit(click)


func _deep_button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
		var found := _deep_button(child, text)
		if found != null:
			return found
	return null


## The first pip row anywhere under `parent`, or null.
func _deep_pips(parent: Node) -> KillPips:
	for child: Node in parent.get_children():
		if child is KillPips:
			return child
		var found := _deep_pips(child)
		if found != null:
			return found
	return null


func _clear_scratch() -> void:
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
