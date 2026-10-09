extends "res://tests/clip.gd"
## The skill tree built on the black screen of a transcension, opened on its Skill tree page: a plain
## Strength Node in the bag exalted until its lines come up right, picked up and pressed into the empty
## slot the tree rings for it -- which opens two more under it -- then a plain Dexterity Node the same
## way. Then "Craft your own skill tree", "Kobold Clicker". The rolls are the game's own, on a seed a
## node picked up front (`_exalt_seed`).

const EXALT := "Orb of Exaltation"
## The nodes crafted and placed, in turn: [base, tier, connectors, the empty slot it goes in, the lines
## that make it (whatever else an epic node could carry is a miss), the presses of Exaltation it may come
## right on, first to last -- the presses before it missing].
const CRAFTS := [
	["Strength Node", 3, 2, "0.1.1", ["added_stone_ranks", "added_damage", "added_crit_damage"], Vector2i(3, 4)],
	["Dexterity Node", 3, 2, "0.0.1", ["added_stone_ranks", "global_increased_attack_speed", "added_dexterity"],
			Vector2i(2, 3)],
]
const SEEDS := 20000

var black: TranscendPage


func _run() -> void:
	var inventory: Inventory = await _open_main("tree")
	inventory.level = 40
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# A tree a few worlds grown, with two slots standing empty three deep: one under each of the root's
	# stone's two branches.
	var skills: Skills = inventory.skills
	skills.stones.clear()
	skills.stones["0"] = Item.rolled("Strength Node", ItemRarity.Rarity.RARE, rng, 20, 1, 2)
	skills.stones["0.0"] = Item.rolled("Dexterity Node", ItemRarity.Rarity.RARE, rng, 20, 2, 2)
	skills.stones["0.0.0"] = Item.rolled("Dexterity Node", ItemRarity.Rarity.UNCOMMON, rng, 20, 3)
	skills.stones["0.1"] = Item.rolled("Intelligence Node", ItemRarity.Rarity.RARE, rng, 20, 2, 2)
	skills.stones["0.1.0"] = Item.rolled("Intelligence Node", ItemRarity.Rarity.UNCOMMON, rng, 20, 3)
	# The bag's nodes, which it reads by level, then rarity, then newest first (`Inventory.order`): the
	# two plain ones a level above the rest and picked up last first, so each stands first in turn, with
	# room for its card to its right; and a couple of others found along the way.
	var stones: Array[Item] = []
	var seeds: Array = []
	var exalts := 0
	for craft: Array in CRAFTS:
		stones.append(Item.rolled(craft[0], ItemRarity.Rarity.COMMON, rng, 20, craft[1], craft[2]))
		seeds.append(_exalt_seed(stones[-1], craft[4], craft[5]))
		exalts += int(seeds[-1][1])
	for shape: Array in [["Intelligence Node", ItemRarity.Rarity.RARE, 4, 2],
			["Dexterity Node", ItemRarity.Rarity.ELITE, 5, 3]]:
		inventory.add(Item.rolled(shape[0], shape[1], rng, 15, shape[2], shape[3]))
	for i in range(stones.size() - 1, -1, -1):
		inventory.add(stones[i])
	for orb in [["Orb of Transmutation", 9], ["Orb of Augmentation", 4], ["Orb of Alchemy", 3],
			["Orb of Divinity", 2], ["Orb of Chaos", 3], [EXALT, exalts + 4]]:
		inventory.add_orb(orb[0], orb[1])

	black = TranscendPage.new(inventory, main.ui_scale)
	main._ui_layer.add_child(black)
	main._character.hide()
	# The black screen faded in and its Skill tree page open before the clip starts: the crafting alone.
	await create_timer(TranscendPage.FADE + 0.3).timeout
	black._open(black._stones_page)
	for wait in 3:
		await process_frame
	# The tree over the bag at the window's foot, the words to come in the black above them.
	_show(_around(Vector2(root.size.x / 2.0, root.size.y - FRAME.y / 2.0)))
	_caption_middle = _frame.position.y + 45.0
	_pointer = _orb_spot(EXALT) + Vector2(-60, -110)
	_start()
	# Each node: straight for the Exaltation, then onto the node.
	for i in CRAFTS.size():
		var stone := stones[i]
		black._stones_page._craft_rng.seed = seeds[i][0]
		await _glide(_orb_spot(EXALT), 0.4)
		await _click()
		await _glide(_stone_spot(stone), GLIDE)
		for press in int(seeds[i][1]):
			await _click()
			await create_timer(0.45).timeout
		await create_timer(0.45).timeout
		# The orb put down, the node picked up, and the slot it rings pressed.
		await _click(0.08, 0.15, MOUSE_BUTTON_RIGHT)
		await _click()
		await create_timer(0.45).timeout
		await _glide(_slot_spot(CRAFTS[i][3]), 0.45)
		await create_timer(0.15).timeout
		await _click()
		await create_timer(0.7).timeout
	_pointer = Vector2(root.size) + Vector2(40, 40)
	_say("Craft your own\nskill tree", "")
	await create_timer(1.8).timeout
	_say("Kobold Clicker", "")
	await create_timer(1.5).timeout
	for i in CRAFTS.size():
		print("%s exalted %d times (seed %d): %s, placed at %s: %s" % [CRAFTS[i][0], seeds[i][1], seeds[i][0],
				", ".join(stones[i].mod_lines()), CRAFTS[i][3], inventory.skills.stones.get(CRAFTS[i][3]) == stones[i]])
	await _end()


## A `FRAME` centred on `middle`, kept inside the window.
func _around(middle: Vector2) -> Rect2:
	var corner := (middle - FRAME / 2.0).clamp(Vector2.ZERO, Vector2(root.size) - FRAME).round()
	return Rect2(corner, FRAME)


## [seed, presses]: the seed whose Exaltations on a copy of `piece` first carry every `wanted` line on a
## press inside `presses`, the presses before it missing.
func _exalt_seed(piece: Item, wanted: Array, presses: Vector2i) -> Array:
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var copy := Item.from_dict(piece.to_dict())
		for press in range(1, presses.y + 1):
			OrbTable.apply(EXALT, copy, rng)
			var ids := copy.mods.map(func(mod: Dictionary) -> String: return mod["id"])
			if wanted.all(func(id: String) -> bool: return id in ids):
				if press >= presses.x:
					return [candidate, press]
				break
	push_error("No seed in %d exalts the %s right" % [SEEDS, piece.type])
	return [0, presses.x]


func _stone_spot(stone: Item) -> Vector2:
	for slot: ItemSlot in get_nodes_in_group(ItemSlot.GROUP):
		if slot.item == stone and slot.is_visible_in_tree() and black._stones_page.is_ancestor_of(slot):
			return slot.get_global_rect().get_center()
	return Vector2.ZERO


func _orb_spot(orb: String) -> Vector2:
	for slot: OrbSlot in black._stones_page._orb_tray.get_children():
		if slot.orb == orb:
			return slot.get_global_rect().get_center()
	return Vector2.ZERO


func _slot_spot(path: String) -> Vector2:
	return (black._stones_page._tree.squares[path] as Control).get_global_rect().get_center()
