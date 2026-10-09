extends "res://tests/clip.gd"
## A plain Masterwork Greatsword turned into a great one in the real bag: Exaltation pressed again and
## again until the modifiers come up all offence, then three Divinities rolling their numbers to the top.
## The bag alone, the map behind it. The rolls are the game's own; the two seeds are picked up front
## (`_exalt_seed`, `_divine_seed`).

const SWORD := "Masterwork Greatsword"
const SWORD_LEVEL := 18
const EXALT := "Orb of Exaltation"
const DIVINE := "Orb of Divinity"
## The press of Exaltation the great roll may land on, first to last: the first two read slowly, the
## rest spammed.
const SPAM := Vector2i(8, 14)
const DIVINES := 3
## Words in a modifier's id that make it a line a weapon wants.
const OFFENCE := ["damage", "crit", "attack", "strike", "blow"]
const SEEDS := 20000

var sword: Item


func _run() -> void:
	var inventory: Inventory = await _open_main("craft")
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# A lived-in bag around the sword.
	for spec in [["Steel Zweihander", ItemRarity.Rarity.RARE, 12], ["Golden Helm", ItemRarity.Rarity.UNCOMMON, 14],
			["Shadow Boots", ItemRarity.Rarity.COMMON, 15], ["Golden Plate", ItemRarity.Rarity.RARE, 16],
			["Opal Ring", ItemRarity.Rarity.UNCOMMON, 17]]:
		inventory.add(Item.rolled(spec[0], spec[1], rng, spec[2]))
	sword = Item.rolled(SWORD, ItemRarity.Rarity.COMMON, rng, SWORD_LEVEL)
	inventory.add(sword)
	var exalt := _exalt_seed(sword)
	var presses: int = exalt[1]
	var rolled := Item.from_dict(sword.to_dict())
	rng.seed = exalt[0]
	for press in presses:
		OrbTable.apply(EXALT, rolled, rng)
	var divine := _divine_seed(rolled)
	for orb in [["Orb of Transmutation", 14], ["Orb of Augmentation", 6], ["Orb of Alchemy", 4],
			[DIVINE, DIVINES + 4], ["Orb of Chaos", 5], [EXALT, presses + 9]]:
		inventory.add_orb(orb[0], orb[1])
	main.bag_page._craft_rng.seed = exalt[0]
	# Every tile inside the wall charted, for the map behind the bag.
	main.view.reveal_all()
	main._on_bag_pressed()
	# The inventory alone: the doll put away by its own button, the corner row faded out where it stands
	# (hiding it would lay the page out again); the map stays behind it.
	main.bag_page._on_fold_pressed()
	for button: Button in main._corner_buttons():
		button.modulate.a = 0.0
	# The fold redrew the bag; its squares are placed a frame on.
	for wait in 2:
		await process_frame
	# The frame: the bag and the card beside the sword (always as wide), down to the window's foot, which
	# the tallest card reaches.
	_pointer = _sword_spot()
	for wait in 120:
		if main._item_card.visible:
			break
		await process_frame
	await process_frame
	var bag: Rect2 = main.bag_page._panel.get_global_rect()
	var shown := bag.merge(main._item_card.get_global_rect())
	_show(Rect2(clampf(shown.get_center().x - FRAME.x / 2.0, 0.0, root.size.x - FRAME.x),
			root.size.y - FRAME.y, FRAME.x, FRAME.y))
	_pointer = _sword_spot() + Vector2(40, -60)
	await create_timer(0.5).timeout

	_start()
	_say("Masterwork", "Common")
	await _glide(_sword_spot(), 0.4)
	await create_timer(0.8).timeout
	_say("Exaltation", "")
	await _glide(_orb_spot(EXALT), GLIDE)
	await _click()
	await _glide(_sword_spot(), GLIDE)
	await _click()
	_say("Exaltation", "Meh.")
	await create_timer(1.0).timeout
	_say("Again...", "")
	await create_timer(0.3).timeout
	await _click()
	_say("Again...", "Nope.")
	await create_timer(0.8).timeout
	for press in range(3, presses + 1):
		await _click(0.04, 0.09)
		_say("Exaltation x%d" % press, "")
	_say("There it is!", "")
	await create_timer(1.4).timeout

	main.bag_page._craft_rng.seed = divine
	_say("Divinity", "")
	await _glide(_orb_spot(DIVINE), GLIDE)
	await _click()
	await _glide(_sword_spot(), GLIDE)
	for press in DIVINES - 1:
		await _click()
		_say("Divinity x%d" % (press + 1), "")
		await create_timer(0.5).timeout
	# The last press lands in a close-up of the card, the end caption inside it.
	var card: Rect2 = main._item_card.get_global_rect()
	_close_up(Rect2(clampf(card.get_center().x - CLOSEUP.x / 2.0, 0.0, root.size.x - CLOSEUP.x),
			clampf(card.end.y + 6.0 - CLOSEUP.y, 0.0, root.size.y - CLOSEUP.y), CLOSEUP.x, CLOSEUP.y))
	await _click()
	_say("", "")
	await create_timer(0.5).timeout
	_say("Amazing roll.", "")
	await create_timer(1.4).timeout
	_say("Kobold Clicker", "")
	await create_timer(1.5).timeout
	print("Exalted %d times (seed %d), divined with seed %d: %s" % [presses, exalt[0], divine,
			", ".join(sword.mod_lines(true))])
	await _end()


## [seed, presses]: the seed whose Exaltations, pressed again and again on a copy of `piece`, first come
## up great (`_great`) on a press inside `SPAM` -- the first two plainly poor, with two lines or more no
## weapon wants -- and of those the one with the highest tiers.
func _exalt_seed(piece: Item) -> Array:
	var best := [0, 0]
	var best_tiers := -1
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var copy := Item.from_dict(piece.to_dict())
		for press in range(1, SPAM.y + 1):
			OrbTable.apply(EXALT, copy, rng)
			if _great(copy):
				if press >= SPAM.x and _tiers(copy) > best_tiers:
					best_tiers = _tiers(copy)
					best = [candidate, press]
				break
			if press <= 2 and copy.mods.filter(func(mod: Dictionary) -> bool: return not _offence(mod)).size() < 2:
				break
	return best


## The seed whose `DIVINES` Divinities on a copy of `piece` end with its numbers highest in their bands,
## the last press better than both before it.
func _divine_seed(piece: Item) -> int:
	var best := 0
	var best_values := -1.0
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var copy := Item.from_dict(piece.to_dict())
		var values: Array[float] = []
		for press in DIVINES:
			OrbTable.apply(DIVINE, copy, rng)
			values.append(_values(copy))
		if values[-1] > values.slice(0, -1).max() and values[-1] > best_values:
			best_values = values[-1]
			best = candidate
	return best


## Every line one a weapon wants, as many as an epic can carry.
func _great(piece: Item) -> bool:
	return piece.mods.size() == ItemRarity.MOD_COUNT[ItemRarity.Rarity.ELITE][1] and piece.mods.all(_offence)


func _offence(mod: Dictionary) -> bool:
	return OFFENCE.any(func(word: String) -> bool: return word in str(mod["id"]))


func _tiers(piece: Item) -> int:
	var total := 0
	for mod in piece.mods:
		total += piece.tier_of(mod)
	return total


## How far up its band each modifier's number sits, 0 to 1, summed.
func _values(piece: Item) -> float:
	var total := 0.0
	for mod in piece.mods:
		var band := ModifierTable.band_for(mod["id"], piece.tier_of(mod))
		total += inverse_lerp(band[0], maxf(band[1], band[0] + 1), float(mod["value"]))
	return total


func _sword_spot() -> Vector2:
	for slot: ItemSlot in get_nodes_in_group(ItemSlot.GROUP):
		if slot.item == sword and slot.is_visible_in_tree():
			return slot.get_global_rect().get_center()
	return Vector2.ZERO


func _orb_spot(orb: String) -> Vector2:
	for slot: OrbSlot in main.bag_page._orb_tray.get_children():
		if slot.orb == orb:
			return slot.get_global_rect().get_center()
	return Vector2.ZERO
