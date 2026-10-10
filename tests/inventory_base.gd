extends "res://tests/harness.gd"
## What the inventory suites share: their scratch files and the helpers their tests are written with.
## (They were one file, tests/test_inventory.gd, until it outgrew a single read.)

## A lambda captures what it can see by value, and a PackedStringArray is a value too, so everything
## these tests collect from a signal is gathered in an Array, which is shared rather than copied.
## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_inventory.json"
## Nor MapSave.SAVE_PATH, for the same reason and one more: these pin a seed, and a pinned seed
## that differs from a save is a request for another world, which replaces it on the first write.
const TEST_MAP_PATH := "user://test_inventory_map.json"
## A whole save as `Inventory.save` wrote it, everything a save can hold in it: bag, both dolls, the
## tree, heirlooms, orbs, runes and a tile they work, a town, what was earned and counted. Kept as it
## was written: to renew it once a change to the save is meant, load it, save it and keep that file.
const GOLDEN := "res://tests/fixtures/inventory_golden.json"
## Enough rolls that a rate lands within a percent or so of the chance behind it. Most of these
## come back empty on purpose -- what is being measured is how often anything falls at all.
const ROLLS := 20000
## Enough *guaranteed* rolls to measure what a drop looks like when there is one. Far fewer are
## needed than above because every one of them lands: going through a common's 3% gate threw 97
## rolls in 100 away and left a rare step's share as mostly noise.
const SHAPE_ROLLS := 4000


func _clear_save() -> void:
	for path in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A hero with nothing under their gear but the gear: a fresh tree holds no point, so it adds nothing.
func _hero() -> Inventory:
	return Inventory.new()


## What `ItemDetails.deltas` says one swap is worth, against what `Equipment.totals` actually comes to
## before and after making it. `worn` is [type, socket] pairs. Plain pieces on both sides, so the set's
## GLOBAL percents -- which a delta knows nothing about -- have nothing to say either way.
func _swap_reads_true(worn: Array, type: String, socket: Equipment.Socket, what: String) -> void:
	var gear := Equipment.new()
	for pair: Array in worn:
		gear.equip(pair[1], _plain(pair[0]))
	var judged := _plain(type)
	var change := ItemDetails.deltas(judged, gear.displaced_by(socket, judged))
	var before := gear.totals()
	gear.equip(socket, judged)
	var after := gear.totals()
	for stat: String in change:
		var moved: float = float(after.get(stat, 0.0)) - float(before.get(stat, 0.0))
		_check(is_equal_approx(float(change[stat]), moved),
				"%s: %s reads %s and the player moved %s" % [what, stat, change[stat], moved])
	# And nothing the swap really moved is left off the page.
	for stat: String in before.keys() + after.keys():
		var moved: float = float(after.get(stat, 0.0)) - float(before.get(stat, 0.0))
		if LootTable.delta_shows(stat, moved):
			_check(change.has(stat), "%s: %s moved by %s and the page said nothing" % [what, stat, moved])


## A piece of one kind at one level with nothing rolled on top: the table's own numbers, which is
## what lets what a swap is worth be checked against what the set adds up to.
func _plain(type: String, level := 1) -> Item:
	var item := Item.new()
	item.type = type
	item.rarity = ItemRarity.Rarity.COMMON
	item.level = level
	item.stats = Item.scaled_stats(type, level)
	return item


## How good a tier's drops are on average, as a position on the rarity ramp: 0 if it only ever
## dropped plain gear, 3 if every piece were elite. The one number that says "better enemies
## carry better things" without caring which band the weight is sitting in.
func _mean_step(tier: EnemyRoster.Tier) -> float:
	var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
	var total := 0
	var sum := 0
	for step: ItemRarity.Rarity in row:
		total += int(row[step])
		sum += int(row[step]) * int(step)
	return float(sum) / maxi(total, 1)


## How far a measured share may sit from the share behind it before it means something. Three
## standard errors, so a band's own thinness sets its own margin: a step worth 45% of drops scatters
## far more in absolute terms than one worth 1.5%, and holding both to one flat number either lets
## the thin one drift unnoticed or fails the fat one on nothing. The floor is for a weight of zero,
## where the error is zero and the count still has to be exactly right.
func _tolerance(want: float, samples: int) -> float:
	return maxf(3.0 * sqrt(want * (1.0 - want) / samples), 0.002)


## What share of a tier's drops one rarity step is worth, straight off the table. Every share a
## test holds a roll to comes from here, so retuning the curve retunes what is expected of it
## rather than leaving a number written in a test to go quietly stale.
func _rarity_share(tier: EnemyRoster.Tier, step: ItemRarity.Rarity) -> float:
	var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
	var total := 0
	for weight: int in row.values():
		total += weight
	return float(int(row[step])) / maxi(total, 1)


## How many pieces each body of one seeded tile fight left, by the slot it stood in.
func _drops_per_body(drop_rate: float, certain: bool, seed_value := WORLD_SEED) -> Dictionary:
	var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
	fight.loot_rng.seed = seed_value
	fight.always_drop = certain
	fight.arm({"damage": 1.0e9, "drop_rate": drop_rate})
	var counts := {}
	fight.loot_dropped.connect(func(index: int, _item: Item) -> void:
		counts[index] = int(counts.get(index, 0)) + 1)
	_play(fight)
	return counts


## A farm run owed `owed`, by a player `kills_before` kills in, that kills at a blow.
func _owed_run(owed: Array, kills_before: int, seeded: int) -> Encounter:
	var run := Encounter.farm(MapBuilder.CENTER + Vector2i(1, 0), "grass")
	run.promised = owed
	run.kills_before = kills_before
	run.damage = 1.0e9
	for rng: RandomNumberGenerator in [run.loot_rng, run.orb_rng, run.unique_rng, run.stone_rng]:
		rng.seed = seeded
	run.start()
	return run


func _kill_more(run: Encounter, bodies: int) -> void:
	var until := run.kills() + bodies
	while run.kills() < until:
		run.hit()
		run.advance(0.1)


## Presses the first level heading's bin, found by its tooltip as the mark has no words.
func _press_bin(main: Node) -> void:
	for button: Button in main.bag_page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Discard ") and not button.disabled:
			button.pressed.emit()
			return


## A button of the question standing over the bag, by its words.
## Whether `names` stand in alphabetical order, as the pages sort them.
func _by_name(names: Array) -> bool:
	var sorted := names.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return names == sorted


func _confirm_button(main: Node, text: String) -> Button:
	for button: Button in main.bag_page._confirm.find_children("", "Button", true, false):
		if button.text == text:
			return button
	return null


## Everything the question standing over the bag says, in one string.
func _confirm_text(main: Node) -> String:
	var said := PackedStringArray()
	for label: Label in main.bag_page._confirm.find_children("", "Label", true, false):
		said.append(label.text)
	return " ".join(said)


## Every square the bag is showing, in the order the sections lay them out. The grid is no longer one
## rectangle, so a test asking what the bag holds has to walk the sections the way the click does.
## `main` is anything with a `bag_page`: the scene, or a Dictionary standing in for one.
func _bag_squares(main) -> Array:
	var squares := []
	for section: Node in main.bag_page._sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Node in section.get_children():
			squares.append(slot)
	return squares


## The middle of `control` in the window's pixels, where a pushed mouse event lands.
func _middle(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


## A mouse's drag from `from` to `to` (window pixels): down, across in steps, up, a frame each. Through
## `Input` rather than straight into the viewport, because a drop is placed where the mouse is, and
## headless that is `Input`'s mouse; the frames let the doll the lift redraws be laid out under it.
## `midway` is called over `to` before letting go.
func _mouse_drag(from: Vector2, to: Vector2, midway := Callable()) -> void:
	var at := from
	for step in 6:
		if step == 5 and midway.is_valid():
			# A frame more, for the page's `_process` to have followed the mouse there.
			await process_frame
			midway.call()
		var event: InputEventMouse
		if step == 0 or step == 5:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = step == 0
		else:
			var next := from.lerp(to, step / 4.0)
			event = InputEventMouseMotion.new()
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
			event.relative = next - at
			at = next
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame


## A click on the doll at `at` (its own pixels), straight to its handler: a socket counts as it lets go.
func _click_doll(page: BagPage, at: Vector2, shift := false) -> void:
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.shift_pressed = shift
		click.position = at
		page._on_doll_input(click)


## Every socket square on the doll, or nothing at all while the doll is folded away. It is
## the same list `_on_doll_input` hit-tests against, and whether it is empty is how a test tells the
## page's two states apart.
func _socket_squares(main) -> Array:
	var squares := []
	if main.bag_page._doll == null:
		return squares
	for slot: Node in main.bag_page._doll.get_children():
		if slot.has_meta("socket"):
			squares.append(slot)
	return squares


## Every line of text on a node and everything under it, which is how a test reads a stat block
## whose lines are nested in columns rather than laid flat.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


## The middle of a square in the sections' own space -- which is the space `_on_bag_clicked` works
## in. A square's own position is its grid's, so its section has to be added back on.
func _square_spot(slot: Control) -> Vector2:
	return (slot.get_parent() as Control).position + slot.position + slot.size / 2.0


## What each super orb does to a piece, and what it leaves there for the ordinary orbs and the smith.
## What a modifier's band was at an item level before there were tiers, worked out here rather than
## asked of `ModifierTable`: the mean the tiers have to keep.
func _old_band(id: String, level: int) -> Array:
	var entry: Dictionary = ModifierTable.MODS[id]
	var band: Array = entry["range"]
	if entry["kind"] == ModifierTable.Kind.FLAT:
		var step := float(entry.get("level_flat", LootTable.LEVEL_FLAT.get(entry["stat"], 0.0)))
		return [LootTable.scale(entry["stat"], float(band[0]), level, step),
				LootTable.scale(entry["stat"], float(band[1]), level, step)]
	var grow := pow(LootTable.LEVEL_GROWTH, level - 1)
	return [float(band[0]) * grow, float(band[1]) * grow]


## A generator whose first draw is as high as a draw gets, so the smith's hammer never breaks a piece.
func _never_breaks() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in 1000:
		rng.seed = seed_value
		var state := rng.state
		if rng.randf() > Blacksmith.BREAK_CHANCE:
			rng.state = state
			return rng
	return rng


## The first live Button anywhere under `parent` whose face starts with `text`, or null. Pages are
## built fresh on every refresh, so a test finds its button rather than holding one.
func _deep_button(parent: Node, text: String) -> Button:
	for button: Button in parent.find_children("", "Button", true, false):
		if button.text.begins_with(text) and not button.is_queued_for_deletion():
			return button
	return null


## The same, by what its tooltip starts with: a level's marks have no words on them.
func _by_tooltip(parent: Node, text: String) -> Button:
	for button: Button in parent.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with(text) and not button.is_queued_for_deletion():
			return button
	return null


## An item built to order, for the tests that care about where a piece sorts rather than what it
## rolled. `Item.rolled` needs a generator and rolls modifiers; these want neither.
func _piece(rarity: ItemRarity.Rarity, level: int) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = level
	item.stats = Item.scaled_stats(item.type, level)
	return item


## Every Label anywhere under `node`, so a test can read what a panel actually says without knowing
## how it is stacked.
func _labels_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in node.get_children():
		if child is Label:
			found.append(child)
		found.append_array(_labels_under(child))
	return found


## A mouse button going down or coming up on the grid, in the panel's own coordinates.
func _press(main: Node, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	main.bag_page._on_grid_input(event)


## The cursor moving `by` pixels down the grid with the button held.
func _drag(main: Node, from: Vector2, by: float) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = from + Vector2(0, by)
	event.relative = Vector2(0, by)
	main.bag_page._on_grid_input(event)


## One item as a string, so two of them can be compared across a save.
func _fingerprint(item: Item) -> String:
	var parts := PackedStringArray()
	for mod in item.mods:
		parts.append("%s:%d" % [mod["id"], mod["value"]])
	return "%s|%s|%s" % [item.type, item.rarity_name(), ", ".join(parts)]


func _fingerprint_all(items: Array[Item]) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append(_fingerprint(item))
	return " / ".join(parts)


## What one seeded fight drops, in order, as one string to compare.
func _drops_of(seed_value: int) -> String:
	var fight := Encounter.for_tile(Vector2i(1, 1), "grass")
	fight.loot_rng.seed = seed_value
	var drops: Array[Item] = []
	fight.loot_dropped.connect(func(_index: int, item: Item) -> void: drops.append(item))
	_play(fight)
	return _fingerprint_all(drops)


## Beats a fight without a scene: hit when there is something to hit, let the clock run otherwise.
func _play(fight: Encounter) -> void:
	var guard := 0
	while not fight.finished and guard < 10000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)


## A skill stone made by hand: an uncommon leaf of tier 1 carrying `line` at 1, as every hero's first
## stones once were.
func _node(type: String, line: String) -> Item:
	var stone := Item.new()
	stone.type = type
	stone.rarity = ItemRarity.Rarity.UNCOMMON
	stone.stone_tier = 1
	stone.stats = Item.scaled_stats(type, 1)
	# Its tier read off its number the way a save reads one (`Item.from_dict`), so it saves as it is.
	var mod := {"id": line, "value": 1}
	var under := ModifierTable.fit_under(line, 1, stone.mod_level())
	if under > 0:
		mod["under"] = under
	stone.mods = [mod]
	return stone


## The colour the hover card's light is in (`ItemCard.shine`), or black with none up.
func _card_lit(main: Node) -> Color:
	var light: Node2D = main._item_card.get_node_or_null(ItemCard.SHINE_NAME)
	return Color.BLACK if light == null else (light.material as ShaderMaterial).get_shader_parameter("colour")


## The right-hand edge of a panel on the UI layer, in window pixels.
func _panel_right(panel: Control, ui_scale: float) -> float:
	return panel.get_global_position().x + panel.size.x * ui_scale


## Everything a banner says, run together.
func _said_by(node: Node) -> String:
	var said := ""
	for label: Node in node.find_children("*", "Label", true, false):
		said += (label as Label).text + " "
	return said


## The number on the character page's row for `stat`, or "" where there is no such row.
func _sheet_value(page: CharacterPage, stat: String) -> String:
	var row := page.find_child(stat, true, false)
	return "" if row == null else (row.find_child(UITheme.TABLE_VALUE, true, false) as Label).text


## The walk every weighted pick in the tables is: one `randi_range` over the weights' sum, then the
## first weight the pick falls inside. Written out here so each table's own draw is held to it.
func _walk(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight: int in weights:
		total += weight
	var pick := rng.randi_range(0, total - 1)
	for index in weights.size():
		pick -= int(weights[index])
		if pick < 0:
			return index
	return 0


## What an orb took before `can_apply` was read off `why_not`, word for word: the two are held to it
## over every orb and every sort of piece, so the rule and its sentence cannot come apart.
func _orb_took(orb: String, item: Item) -> bool:
	if item == null or not OrbTable.ORBS.has(orb):
		return false
	if item.broken or not item.capstone.is_empty():
		return false
	if item.rarity == ItemRarity.Rarity.UNIQUE and orb not in ["Orb of Divinity", "Orb of Chaos"]:
		return false
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exaltation":
			return true
		"Orb of Augmentation":
			return item.mods.size() < OrbTable.room(item)
		"Orb of Divinity", "Orb of Chaos":
			return not item.mods.is_empty()
	return false


## Where `got` is not what `want` holds, a line each. Every key and every entry of `want` is asked for,
## so a later build may add a field to a save but never lose or move one.
func _differences(want: Variant, got: Variant, path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if want is Dictionary and got is Dictionary:
		for key: Variant in want:
			if got.has(key):
				out.append_array(_differences(want[key], got[key], "%s.%s" % [path, key]))
			else:
				out.append("%s.%s is gone" % [path, key])
	elif want is Array and got is Array and want.size() == got.size():
		for at: int in want.size():
			out.append_array(_differences(want[at], got[at], "%s[%d]" % [path, at]))
	elif typeof(want) != typeof(got) or want != got:
		out.append("%s is %s, not %s" % [path, got, want])
	return out


## Every place in a save a wrong value could stand: each key of each table and the first entry of each
## list, down from the top, as the keys and indices that lead there. A table of a shape already walked
## is not walked again, so one piece of each make stands for the rest.
func _places(value: Variant, path: Array, shapes: Dictionary, out: Array) -> void:
	if value is Dictionary:
		var shape := "%s" % [value.keys()]
		if not path.is_empty() and shapes.has(shape):
			return
		shapes[shape] = true
		for key: Variant in value:
			out.append(path + [key])
			_places(value[key], path + [key], shapes, out)
	elif value is Array and not value.is_empty():
		out.append(path + [0])
		_places(value[0], path + [0], shapes, out)


## Every script under `dir`, its path -> its text, for the checks that read the source for a name.
func _scripts(dir := "res://Scenes") -> Dictionary:
	var out := {}
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out[dir.path_join(file)] = FileAccess.get_file_as_string(dir.path_join(file))
	for folder: String in DirAccess.get_directories_at(dir):
		out.merge(_scripts(dir.path_join(folder)))
	return out
