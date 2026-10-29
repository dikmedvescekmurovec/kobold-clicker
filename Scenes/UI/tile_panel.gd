class_name TilePanel
extends RefCounted
## The tile panel against the right edge: the selected tile's name, kind and level, its lands, a
## settlement's services, the land's modifiers, the runes working on it and an ice wall's unlocks, over
## the buttons that can be pressed. The main scene owns the one there is: it wires the buttons and the
## X (`closed`), says when the panel shows, and fills it as a tile is chosen (`fill`).

signal closed

## What a modifier's sentences wrap at, and the width of the scrolled column, so it never jumps as a
## name or a row comes and goes.
const MOD_WIDTH := 150.0
## The square an ice wall's unlock is drawn in.
const UNLOCK_ICON := 16
## `PAD` more padding round the body than a titled panel has, `GAP` between rows and twice that between
## the parts (the user: "give it more white space").
const PAD := 4
const GAP := 8
## What a settlement is called ahead of the tile's level, by `TownWorld.Tier`.
const SETTLEMENT_KINDS: Array[String] = ["Village", "Town", "Fortress"]
const CHART_TIP := "Fight for this tile and what lies behind it"
const FARM_TIP := "Fight here for as long as you like, for the loot"
## Chart's and Farm's tooltip while an overfull bag greys them, the cap (`Inventory.capacity`) written
## in, since the Packmule's Harness at IV moves it.
const ENCUMBERED_TIP := "Your bag is too heavy to fight with. Sell or discard gear until it holds %d or fewer"
const CAVE_TIP := "Go down to depth %d. Kill Gollux to go deeper: each depth won is a skull for your curses"

var panel: VBoxContainer
var title: Label
## "Village · Level 4": how hard the tile fights and the ceiling on what drops there.
var level_label: Label
var env_rows := UITheme.vbox(GAP)
var service_rows := UITheme.vbox(GAP)
var mod_rows := UITheme.vbox(GAP)
var rune_rows := UITheme.vbox(GAP)
var unlock_rows := UITheme.vbox(GAP)
var chart_button := UITheme.button("Chart", "LightButton", CHART_TIP)
var move_button := UITheme.button("Move here", "LightButton", "Walk to the selected tile")
var farm_button := UITheme.button("Farm", "LightButton", FARM_TIP)
## Green (`UITheme.GO_BUTTON`, as in town): of the panel's presses, the ones a place is for.
var town_button := UITheme.button("Enter town", UITheme.GO_BUTTON, "Go inside and see what is traded here")
var cave_button := UITheme.button("Enter cave", UITheme.GO_BUTTON, "")
## Where the pages stand, in window pixels (`main_scene._pages_room`): the panel docks in it.
var room: Callable
## What the land on a cell does to its own fight (`main_scene._mods_of`).
var mods_of: Callable

var _map: HexMap
var _view: MapBuilder
var _inventory: Inventory
var _ui_scale: float
## What `update_buttons` last greyed the fights for (`watch_bag`).
var _was_encumbered := false


## Built on `layer`, hidden until a tile is chosen.
func _init(layer: Node, map: HexMap, view: MapBuilder, inventory: Inventory, ui_scale: float) -> void:
	_map = map
	_view = view
	_inventory = inventory
	_ui_scale = ui_scale
	panel = UITheme.titled_panel("Tile", "Close and deselect the tile", closed.emit)
	panel.scale = Vector2(ui_scale, ui_scale)
	panel.hide()
	layer.add_child(panel)
	title = UITheme.title_of(panel)
	var rows := UITheme.body_of(panel)
	var body := panel.get_child(1) as PanelContainer
	var padded := body.get_theme_stylebox("panel").duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		padded.set_content_margin(side, padded.get_content_margin(side) + PAD)
	body.add_theme_stylebox_override("panel", padded)
	rows.add_theme_constant_override("separation", GAP)
	level_label = UITheme.label("", Palette.TEXT_SOFT, true)
	rows.add_child(level_label)
	# The parts scroll and the level and the buttons stay pinned: a fortress past the second wall
	# carries more rows than a 648 px window holds.
	var scroll := UITheme.scroll()
	rows.add_child(scroll)
	var scrolled := UITheme.vbox(GAP * 2, MOD_WIDTH)
	scroll.add_child(scrolled)
	for part: VBoxContainer in [env_rows, service_rows, mod_rows, rune_rows, unlock_rows]:
		scrolled.add_child(part)
	var buttons := UITheme.vbox(GAP)
	rows.add_child(buttons)
	Cursors.wear(chart_button, Cursors.SWORD)
	Cursors.wear(move_button, Cursors.BOOT)
	Cursors.wear(farm_button, Cursors.SWORD)
	for button: Button in [chart_button, move_button, farm_button, town_button, cave_button]:
		buttons.add_child(button)


## Everything the panel says about `cell`, `info` being what the map drew on it (nothing for a tile
## under the fog that can be taken blind).
func fill(cell: Vector2i, info: Dictionary) -> void:
	var spot := _view.origin + cell
	# The ice hides whatever land is under it, so a wall tile has no lands of its own.
	var weights: Dictionary = info.get("environments", {}) if _view.is_land(cell) else {}
	var parts := PackedStringArray()
	for env: String in weights:
		parts.append("%s %.1f%%" % [env, weights[env] * 100])
	var line := "Clicked %s (world %s): %s | %s" % [cell, spot, info.get("name", "fog"), ", ".join(parts)]
	if _view.towns.has_town(spot):
		line += " | town connected to %s" % [_view.towns.connections(spot)]
	print(line)
	# A tile is named as it comes out of the fog, and asking would name it now.
	var tile_name := _view.name_of(cell) if _view.seen(cell) else "Unknown land"
	title.text = tile_name if tile_name != "" else "Tile"
	var tier := _view.town_tier(cell) if _view.seen(cell) else -1
	var kind := SETTLEMENT_KINDS[tier] if tier != -1 else "Cave" if _is_cave(cell) else ""
	level_label.text = ("%s · " % kind if kind != "" else "") + "Level %d" % _view.level_of(cell)
	_put(env_rows, _lands(weights))
	_put(service_rows, _services(cell))
	_put(mod_rows, _mods(cell))
	show_runes(cell)
	_put(unlock_rows, _unlocks(cell))


## The runes' part alone: a rune spent on the tile, or a run's kills counting one down.
func show_runes(cell: Vector2i) -> void:
	_put(rune_rows, _runes(cell))


## Only the buttons that can be pressed are shown, never one that cannot, and none during a walk. An
## overfull bag greys the fights rather than hiding them, with the reason on each.
func update_buttons() -> void:
	var cell := _map.selected_cell
	chart_button.visible = _view.can_chart(cell)
	move_button.visible = _view.can_move_to(cell)
	farm_button.visible = _view.can_farm(cell) and _inventory.farm_unlocked()
	_was_encumbered = _inventory.encumbered()
	for fight: Array in [[chart_button, CHART_TIP], [farm_button, FARM_TIP]]:
		var button: Button = fight[0]
		button.disabled = _was_encumbered
		button.tooltip_text = ENCUMBERED_TIP % _inventory.capacity() if _was_encumbered else fight[1]
	# Stood on, or a settlement Move here could reach: the press walks there first.
	town_button.visible = _view.can_visit(cell) or (move_button.visible and _view.town_tier(cell) != -1)
	cave_button.visible = _view.can_enter_cave(cell)
	cave_button.tooltip_text = CAVE_TIP % (_inventory.dungeon_depth + 1)
	place()


## Every frame: the bag is emptied from several pages (a discard, a sale, Clear level), so the cap is
## watched here rather than wired to each, and the fight buttons come back the moment it is under.
func watch_bag() -> void:
	if _inventory.encumbered() != _was_encumbered:
		update_buttons()


## Against the whole right edge, as `TownPage.layout` has its page. Run whenever a row or a button comes
## or goes: the column's width is its contents'.
func place() -> void:
	panel.reset_size()
	UITheme.dock(panel, room.call(), _ui_scale, UITheme.Dock.RIGHT, place)


## A part's rows swapped for `rows`. An empty part is hidden, or it would still take its gap.
func _put(part: VBoxContainer, rows: Array[Control]) -> void:
	UITheme.clear(part)
	for row: Control in rows:
		part.add_child(row)
	part.visible = not rows.is_empty()


## Whether `cell` is this world's cave, as far as the player can tell: seen, and not under the ice.
func _is_cave(cell: Vector2i) -> bool:
	return cell == _view.cave and _view.seen(cell) and _view.is_land(cell)


## One row per environment on the tile, its share written only where it has to share it.
func _lands(weights: Dictionary) -> Array[Control]:
	var rows: Array[Control] = []
	var envs := weights.keys()
	envs.sort_custom(func(a: String, b: String) -> bool: return weights[a] > weights[b])
	for env: String in envs:
		var text := HexTileset.env_name(env)
		if envs.size() > 1:
			text += " %d%%" % round(weights[env] * 100.0)
		rows.append(_named(_map.tileset.env_icon(env), text))
	return rows


## What the settlement on a tile trades in, for any town tile the player can see, taken or not: which
## town has a smith decides where to walk next. Each counter wears the mark its tab does in town.
func _services(cell: Vector2i) -> Array[Control]:
	var rows: Array[Control] = []
	var tier := _view.town_tier(cell) if _view.seen(cell) else -1
	# The cave's panel is its name and Enter cave, nothing under them.
	if _is_cave(cell) or tier == -1:
		return rows
	rows.append(UITheme.section("Services"))
	for service: String in TownServices.services_for(tier, _view.origin + cell, _view.towns.seed_value):
		var icon := TextureRect.new()
		icon.texture = TownPage.tab_mark(service, false)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		rows.append(_named(icon, TownServices.label(service)))
	return rows


## What the land does to the fight for it, written out and never in a tooltip: it is what the tile is
## chosen on. Only for a tile the player can see.
func _mods(cell: Vector2i) -> Array[Control]:
	var rows: Array[Control] = []
	var mods: Array = mods_of.call(cell) if _view.seen(cell) else []
	if mods.is_empty():
		return rows
	rows.append(UITheme.section("Modifiers"))
	var shown := {}
	for id: String in mods:
		if not shown.has(id):
			shown[id] = true
			rows.append(_block(TileMods.describe(id, mods.count(id), _wild())))
	return rows


## What the runes on a tile are doing to it (`RuneTable`), once the third wall has opened them, on
## ground a farm run can be fought on, each with the kills it has left. The runes held are the bag's.
func _runes(cell: Vector2i) -> Array[Control]:
	var rows: Array[Control] = []
	if not WallUnlocks.has(_inventory.walls_ever(), WallUnlocks.RUNES) or not _view.can_farm_ground(cell):
		return rows
	var work := _inventory.rune_work(_view.origin + cell)
	if not RuneTable.working(work):
		return rows
	rows.append(UITheme.section("Runes"))
	for mod: Dictionary in work["mods"]:
		rows.append(_block(TileMods.describe(mod["id"], int(mod["tier"]), _wild()), int(mod["left"])))
	var depths: Array = work["depth"]
	if not depths.is_empty():
		rows.append(_block(PackedStringArray(["Depth +%d" % depths.size(), "Enemies are %d level%s higher."
				% [depths.size(), "" if depths.size() == 1 else "s"], ""]), int(depths.min())))
	if RuneTable.ascended(work):
		rows.append(_block(PackedStringArray(["Ascended", "What enemies drop may be ascended.", ""]),
				int(work["ascent"])))
	return rows


## What the ice wall on a tile opens for good once broken (`WallUnlocks.of_wall`): each its mark and
## name, what it does in the tooltip, and one an earlier world already opened greyed (`OrbSlot.DIM`).
func _unlocks(cell: Vector2i) -> Array[Control]:
	var rows: Array[Control] = []
	if not _view.is_wall(cell):
		return rows
	# The wall standing is always the next to fall: the number the land would reach past it, in whole
	# wall steps, as `Inventory.walls_ever` counts.
	var wall := (_view.land_radius + _view.wall_step - MapBuilder.START_LAND_RADIUS) / MapBuilder.WALL_STEP
	var unlocks := WallUnlocks.of_wall(wall)
	if unlocks.is_empty():
		return rows
	rows.append(UITheme.section("Unlocks"))
	var opened := _inventory.walls_ever() >= wall
	for unlock: Dictionary in unlocks:
		var icon := TextureRect.new()
		icon.texture = load(unlock["icon"])
		# A 32 px picture (an orb, the root) halved, a 14 px mark as it is. The mode before the size,
		# or the texture's own size wins (the root CLAUDE.md).
		if icon.texture.get_width() > UNLOCK_ICON:
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(UNLOCK_ICON, UNLOCK_ICON)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := _named(icon, unlock["name"])
		row.tooltip_text = unlock["tip"]
		(row.get_child(1) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if opened:
			row.modulate = OrbSlot.DIM
		rows.append(row)
	return rows


func _wild() -> bool:
	return Curses.WILD_TILES in _inventory.curses


## A mark with its name beside it in the body font.
static func _named(icon: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(icon)
	var named := UITheme.label(text, Palette.TEXT, true)
	named.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(named)
	return row


## One thing done to a tile's fight, from `[name, what it does, what it pays]` (`TileMods.describe`),
## the pay in leaf; a rune's also says the kills it has `left`.
static func _block(lines: PackedStringArray, left := -1) -> VBoxContainer:
	var block := UITheme.vbox(2)
	block.add_child(UITheme.label(lines[0], Palette.TEXT))
	block.add_child(ItemDetails.line(lines[1], Palette.TEXT, MOD_WIDTH, true))
	if not lines[2].is_empty():
		block.add_child(ItemDetails.line(lines[2], Palette.LEAF, MOD_WIDTH, true))
	if left >= 0:
		block.add_child(ItemDetails.line("%d kill%s left" % [left, "" if left == 1 else "s"],
				Palette.TEXT_SOFT, MOD_WIDTH, true))
	return block
