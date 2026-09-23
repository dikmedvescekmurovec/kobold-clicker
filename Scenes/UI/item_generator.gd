class_name ItemGenerator
extends VBoxContainer
## Dev only: a piece made to order. Pick a kind and one of its materials, set its level, spend as
## many orbs on it as it takes, and put it in the bag. `SettingsPage` stands it in its own rows' place
## in a debug build; nothing a player can reach builds one.
##
## The orbs go through `OrbTable.can_apply` / `apply` like the bag's, so what comes out is a piece the
## game could have dropped -- except its level, which is not held to `LootTable.TIER_MIN_LEVEL`.
## A change of type or level starts the piece again as a common: a level's numbers are frozen as a
## piece is rolled, and a modifier rolled at one level is not one rolled at another.

## The bag's width: four squares to a row is a kind's four materials, and six orbs fit by the tray's
## own arithmetic (`BagPage.ORB_GAP`).
const WIDTH := BagPage.WIDTH
const ROW_GAP := 6
const MAX_LEVEL := 99
const LEVEL_STEPS := [-10, -1, 1, 10]
## What every orb square is said to hold. They cost nothing; `OrbSlot` only lights for a count above 0.
const FREE := 99

var item: Item
var _inventory: Inventory
var _path: String
var _back: Callable
var _kind := 0
var _rng := RandomNumberGenerator.new()


func _init(inventory: Inventory, path: String, back: Callable) -> void:
	_inventory = inventory
	_path = path
	_back = back
	_rng.randomize()
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", ROW_GAP)
	pick(LootTable.KINDS.keys()[0], 0, maxi(1, inventory.level))


## Starts the piece again: tier `tier` of `kind` at `level`, common and bare.
func pick(kind: String, tier: int, level: int) -> void:
	_kind = LootTable.KINDS.keys().find(kind)
	var tiers: Array = LootTable.KINDS[kind]["tiers"]
	item = Item.rolled(tiers[clampi(tier, 0, tiers.size() - 1)], ItemRarity.Rarity.COMMON, _rng,
			clampi(level, 1, MAX_LEVEL))
	_redraw()


## One free orb on the piece; false when it has nothing to do to it.
func spend(orb: String) -> bool:
	if not OrbTable.can_apply(orb, item) or not OrbTable.apply(orb, item, _rng):
		return false
	_redraw()
	return true


## Into the bag and saved, and a fresh common of the same type taken up: a piece in the bag must not
## be one this page can still craft on. False on a full bag, which `Inventory.add` would trim.
func add_to_bag() -> bool:
	if _inventory.is_full():
		return false
	_inventory.add(item)
	_inventory.save(_path)
	pick(_kind_name(), _tier(), item.level)
	return true


func _kind_name() -> String:
	return LootTable.KINDS.keys()[_kind]


func _tier() -> int:
	return LootTable.KINDS[_kind_name()]["tiers"].find(item.type)


func _redraw() -> void:
	UITheme.clear(self)
	var kinds := LootTable.KINDS.keys()
	var kind_row := HBoxContainer.new()
	for step: int in [-1, 1]:
		var turn := UITheme.button("", "BrownIconButton", "Previous kind" if step < 0 else "Next kind")
		turn.icon = load(BagPage.HIDE_ICON if step < 0 else BagPage.SHOW_ICON)
		turn.pressed.connect(func() -> void:
			pick(kinds[posmod(_kind + step, kinds.size())], _tier(), item.level))
		kind_row.add_child(turn)
	var kind_name := UITheme.label("%s · %s" % [_kind_name().capitalize(), LootTable.slot_of(item.type)])
	kind_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_row.add_child(kind_name)
	kind_row.move_child(kind_name, 1)
	add_child(kind_row)

	# The squares take no mouse of their own (`ItemSlot`), so the row answers for them, as the bag's
	# grid does; being in `ItemSlot.GROUP` is what gives each one its card under the cursor.
	var tiers: Array = LootTable.KINDS[_kind_name()]["tiers"]
	# The bag's own four columns, so a kind's five materials wrap onto a second row rather than widen
	# the page.
	var tier_row := GridContainer.new()
	tier_row.columns = BagPage.GRID_COLS
	tier_row.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	tier_row.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	tier_row.mouse_filter = Control.MOUSE_FILTER_STOP
	for type: String in tiers:
		var shown := item if type == item.type else Item.rolled(type, ItemRarity.Rarity.COMMON, _rng, item.level)
		tier_row.add_child(ItemSlot.make(shown, type == item.type))
	tier_row.gui_input.connect(func(event: InputEvent) -> void:
		Cursors.over_squares(tier_row, event, false)
		var press := event as InputEventMouseButton
		if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
			return
		var pitch := ItemSlot.SIDE + BagPage.SLOT_GAP
		var at := int(press.position.y / pitch) * BagPage.GRID_COLS + int(press.position.x / pitch)
		if at < tiers.size() and tiers[at] != item.type:
			pick(_kind_name(), at, item.level))
	add_child(tier_row)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 2)
	for step: int in LEVEL_STEPS:
		var nudge := UITheme.button("%+d" % step, "LightButton", "")
		nudge.disabled = clampi(item.level + step, 1, MAX_LEVEL) == item.level
		nudge.pressed.connect(func() -> void: pick(_kind_name(), _tier(), item.level + step))
		level_row.add_child(nudge)
	var level_name := UITheme.label("Level %d" % item.level)
	level_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_row.add_child(level_name)
	level_row.move_child(level_name, 2)
	add_child(level_row)

	add_child(UITheme.rule(WIDTH))
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", BagPage.ORB_GAP)
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	for orb: String in OrbTable.orbs():
		var usable := OrbTable.can_apply(orb, item)
		var slot := OrbSlot.make(orb, FREE, usable)
		slot.tooltip_text = "%s: %s" % [orb, OrbTable.describe(orb) if usable else OrbTable.why_not(orb, item)]
		slot.pressed.connect(spend)
		tray.add_child(slot)
	add_child(tray)
	add_child(UITheme.rule(WIDTH))

	# In a scroll, and the scroll takes the slack: an elite's six modifiers are taller than a 648 px
	# window leaves, and Add to bag belongs at the page's foot either way.
	var details := UITheme.vbox(0, WIDTH)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ItemDetails.fill(details, item, WIDTH)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	add_child(scroll)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 2)
	var back := UITheme.back_button("Back to the settings")
	back.pressed.connect(_back)
	foot.add_child(back)
	var add := UITheme.button("Add to bag", "LightButton", "The bag is full" if _inventory.is_full() else "")
	add.disabled = _inventory.is_full()
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.pressed.connect(add_to_bag)
	foot.add_child(add)
	add_child(foot)
