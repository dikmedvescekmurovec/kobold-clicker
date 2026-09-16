extends Node2D

## Seeds for the town world and the rendered map. 0 picks a random seed each run; the used seeds are printed.
@export var world_seed := 0
@export var map_seed := 0
## World spot shown at the map's center cell (0, 0), which is the middle of the screen. The row must be even.
@export var map_origin := Vector2i(128, 128)
## Whole-number pixel zoom, so sprite pixels stay square: 3 draws every sprite pixel as 3x3 on screen.
@export var zoom := 3.0
## The same for the UI panel. Pixellari only renders cleanly at its native 16 px, so the way to make
## the interface smaller is to draw its pixels smaller, not to shrink the font.
@export var ui_scale := 2.0
## Where the collection log is kept. The tests and the screenshot scripts point this somewhere else
## before the scene enters the tree, so they never read or overwrite the player's own inventory.
@export var inventory_path := Inventory.SAVE_PATH
## Where the explored map is kept. Pointed elsewhere by the tests and the screenshot scripts for the
## reason `inventory_path` is -- and more sharply, since they all pin a seed, and a pinned seed that
## differs from a save is a request for another world that replaces it on the first write.
@export var map_path := MapSave.SAVE_PATH

## Side of the terrain swatch shown next to each environment percentage, in sprite pixels.
const ENV_ICON := 16
const ENV_ICON_SIZE := Vector2i(ENV_ICON, ENV_ICON)
## The item grid: four squares to a row with a little air between them. ItemSlot decides how big a
## square is; this is only how they are laid out. The gutter is the UI pack's own proportion -- it
## lays its slots out seven parts square to one part gutter -- so the grid reads as the pack's even
## though the square is sized by the gear art rather than by the pack.
## Five columns rather than four, which is what a section heading costs: "Level 12" with an Auto and
## a Clear button beside it does not fit in four squares' worth of width at Pixellari's 16 px, and
## the font is not a dial -- `ui_scale` is, and it moves the whole interface. Five also suits the
## cap: forty items is eight even rows.
const GRID_COLS := 5
const SLOT_GAP := ItemSlot.SIDE / 7
## How wide the bag's contents are, which is what fixes the panel's width. The grid, the headings
## and the stat block all use it, so the panel does not change width as the bag fills.
const BAG_WIDTH := GRID_COLS * ItemSlot.SIDE + (GRID_COLS - 1) * SLOT_GAP
## The orb tray: all eight in one row, because there are eight orbs and there always will be -- a
## tray the player learns the shape of is worth more than one that grows. The gap is what is left
## over rather than a number of its own, so the row is exactly BAG_WIDTH and stays exactly BAG_WIDTH
## if the square is ever resized; test_ui_theme holds the arithmetic.
const ORB_COLS := 8
const ORB_GAP := (BAG_WIDTH - ORB_COLS * OrbSlot.SIDE) / (ORB_COLS - 1)
## How far a press may travel and still count as a click rather than a drag of the list. In panel
## pixels, so half what it would be on screen at ui_scale 2 -- the same rule HexMap uses to tell a
## pan from a tile click.
const BAG_DRAG_THRESHOLD := 4.0

## The character sheet. The doll is the pack's silhouette at 43x46; WORN_GAP is the air between the
## item panel and the sheet standing beside it.
##
## DOLL_SCALE is set by the sockets, not by taste. A 40 px square has to sit on the head, the chest
## and the feet without the three touching, and those are 17 and 15 sprite pixels apart, so anything
## under 2.7 overlaps them. Three is the first whole number that clears it -- and whole numbers only,
## for the reason `zoom` is: a fraction stops a sprite pixel being square.
##
## WORN_WIDTH is the comparison's width only. It matches the bag page because the two stat blocks
## are read side by side, and a comparison whose columns are different widths wraps its lines
## differently and stops being a comparison. The doll is narrower and sizes itself, as it always did.
const DOLL_TEXTURE := "res://Assets/UI/ui_doll.png"
const SOCKET_RING_TEXTURE := "res://Assets/UI/ui_socket_ring.png"
const SOCKET_AMULET_TEXTURE := "res://Assets/UI/ui_socket_amulet.png"
## The marks the two corner buttons wear. A chest for what has been carried home and a star for what
## the player has become: both are places to go rather than actions to take, which is what the brown
## face says and what puts them in a row of their own rather than among the panels' green buttons.
const CHEST_ICON := "res://Assets/UI/ui_icon_chest.png"
const STAR_ICON := "res://Assets/UI/ui_icon_star.png"
## The air between the two, in panel pixels.
const CORNER_GAP := 4.0
## The gap between the two skill trees, in panel pixels.
const SKILL_TREE_GAP := 20
const DOLL_SCALE := 3.0
const WORN_WIDTH := BAG_WIDTH
const WORN_GAP := 6.0

## The panel that stands in for the map when its save cannot be read: how wide it is allowed to be
## in panel pixels, and the air it keeps either side of it on a window too narrow for that.
const REFUSAL_WIDTH := 300.0
const REFUSAL_MARGIN := 32.0

## Where each socket sits on the silhouette, as the centre of its square in the doll's own pixels
## before DOLL_SCALE. Measured off the sprite rather than guessed: the head runs y 0-16 on x 14-27,
## the chest y 17-33, the feet y 34-45, the shield hand x 0-8 and the sword hand x 37-40.
##
## The last three sit below the figure, at a y the sprite does not reach. A body says where a helmet
## and a boot go and says nothing at all about a ring, which is why the pack draws marks for exactly
## those and why they get a row of their own rather than a place on the figure.
const DOLL_SOCKETS := {
	Equipment.Socket.HELMET: Vector2(21, 8),
	Equipment.Socket.OFFHAND: Vector2(4, 26),
	Equipment.Socket.BODY: Vector2(21, 25),
	Equipment.Socket.WEAPON: Vector2(38, 25),
	Equipment.Socket.BOOTS: Vector2(21, 41),
	Equipment.Socket.RING_LEFT: Vector2(4, 58),
	Equipment.Socket.AMULET: Vector2(21, 58),
	Equipment.Socket.RING_RIGHT: Vector2(38, 58),
}

var towns: TownWorld
var view: MapBuilder
## Everything the player has picked up, loaded from `inventory_path` and written back as it grows.
var inventory: Inventory

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D

var _chart_button: Button
var _move_button: Button
var _farm_button: Button
## The tile the player is walking over to chart, NO_CELL when they aren't.
var _chart_target := HexMap.NO_CELL
var _env_rows: VBoxContainer
var _tile_title: Label
var _level_label: Label
var _panel: VBoxContainer
## The left-hand collection log, the button that opens it, and the rows inside it.
var _bag_panel: VBoxContainer
var _bag_button: Button
## The skills page and its button, beside the bag's. It stands against the same edge, so only ever
## one of the two is up: opening either closes the other.
var _skills_panel: VBoxContainer
var _skills_button: Button
## What the skills page is showing: the free points over the trees, each tree's view and its reset.
var _skill_points: Label
var _skill_views := {}
var _respec_buttons := {}
var _skill_card: SkillCard
## The player in the top-left corner, over the map and over a fight alike.
var _character: CharacterPanel

var _bag_scroll: ScrollContainer
## One section per level, highest first: a heading with its two buttons, a rule, and that level's
## squares. It replaces the one flat grid this had, which is also what retired working an item's
## index out from where its square sat.
var _bag_sections: VBoxContainer
## How full the bag is, over the sections.
var _bag_count: Label
## What the player has earned, pinned to the bottom of the panel under everything else.
var _bag_gold: Label
var _orb_tray: HBoxContainer
var _orb_card: OrbCard
## What an orb draws from when it is spent. Its own generator, unseeded like the fight's: what a
## reroll gives is the attempt's business, and a test that wants a known answer seeds it itself.
var _craft_rng := RandomNumberGenerator.new()
## The stat block: the scrolling lines, and the buttons pinned under them that do not scroll.
var _bag_detail: VBoxContainer
var _bag_detail_scroll: ScrollContainer
var _bag_detail_rows: VBoxContainer
## Which item's stat block is open, as an index into the inventory, or -1 for none. Kept across a
## refresh so a drop landing while it is open does not slam it shut.
var _bag_selected := -1
## The equipped page standing beside the item panel: its own panel, the rows inside it, and which
## socket is open as an `Equipment.Socket`, or -1. Only ever one of this and `_bag_selected` is set:
## both open into the same space on the item panel.
var _worn_panel: PanelContainer
var _worn_body: VBoxContainer
## The doll itself, while that is the state the page is in.
var _doll: Control
var _worn_selected := -1
## Where a press on the grid started and how far it has travelled since.
var _bag_drag_from := Vector2.ZERO
var _bag_drag_scroll := 0
var _bag_dragged := 0.0
## What the fight going on now has turned up. A charting fight has already written each of these
## to the bag as it landed; a farm run has not -- for a run this is the pouch, and it is emptied
## into the bag in one go when the run ends.
var _fight_drops: Array[Item] = []
## And what it has earned. A charting fight banks each purse as it lands, the way it banks each
## find; a run holds its gold in here and it goes in with the pouch.
var _fight_gold := 0
## A run's currency, waiting the way its finds and its gold do. Orb name -> how many.
var _fight_orbs := {}
## A run's experience, waiting the way its gold does.
var _fight_xp := 0
## Whether the fight on now is a farm run rather than a fight for the tile.
var _farming := false
## Whether the run's pouch has already been emptied into the bag. Both ways out of a run bank it,
## and this is what keeps the second from repeating the first.
var _banked := false
## Whether an elite has handed something over in the fight going on. It is what retires the promise
## of a first drop, and a run's elites are not at any fixed place in its lineup.
var _elite_dropped := false
## The fight in front of the map, while there is one.
var _combat: CombatScene
## Whether the map on disk was refused, which stops every write to it. A refused save is never
## written over: overwriting is how a save gets eaten, and the build that wrote it can still read it.
var _save_blocked := false


func _ready() -> void:
	# Two different nulls: no file at all is a first run, and a file that cannot be honoured stops.
	# Generating a world in its place would write over it on the player's first step, and a map lost
	# to a bad read is worse than an error message.
	var problem: Array = []
	var save := MapSave.load_from(map_path, problem, MapSave.fingerprint(map.tileset))
	if not problem.is_empty():
		_refuse_save(str(problem[0]))
		return
	# A seed written into the scene is a deliberate request for that world, so it wins over a save
	# of a different one; 0 means "whatever was being played, else somewhere new". A changed
	# map_origin reads the same way, being as much a choice of world as a seed is.
	if save != null and ((world_seed != 0 and world_seed != save.world_seed)
			or (map_seed != 0 and map_seed != save.map_seed) or map_origin != save.origin):
		save = null
	var used_world_seed := world_seed if world_seed != 0 else (save.world_seed if save else randi())
	var used_map_seed := map_seed if map_seed != 0 else (save.map_seed if save else randi())
	if save != null:
		view = MapBuilder.restore(map, TownWorld.from_dict(save.towns), save)
	else:
		view = MapBuilder.create(map, TownWorld.generate(used_world_seed), map_origin, used_map_seed)
	towns = view.towns
	print("%s world seed %d (%d towns), map seed %d, first town at cell %s" % [
			"Loaded" if save else "New", used_world_seed, towns.towns().size(), used_map_seed,
			view.start_town - map_origin])
	inventory = Inventory.load_from(inventory_path)
	map.tile_clicked.connect(_on_tile_clicked)
	map.dragged.connect(_on_map_dragged)
	view.arrived.connect(_on_player_arrived)
	_build_ui()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.ground_layer.map_to_local(view.player_cell)
	# The world is decided the moment it is generated, so it is written down then: a first run
	# killed before the player moves would otherwise come back as somewhere else entirely.
	_save_map()


## Writes the map as it stands. A refused save is never written over -- that is the whole point of
## refusing, and `_save_blocked` is what carries it to every write path.
func _save_map() -> void:
	if _save_blocked or view == null:
		return
	view.to_save().save(map_path)


## A save that cannot be honoured. Nothing is generated and nothing is written; the player is told
## what happened and where the file is, because a console error is not something they can act on
## and a blank window is worse.
func _refuse_save(reason: String) -> void:
	_save_blocked = true
	push_error("MapSave: refusing to load %s -- %s" % [map_path, reason])
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	# The X quits: there is no map behind this to close it onto.
	var panel := _titled_panel("Saved map", "Quit", get_tree().quit)
	panel.scale = Vector2(ui_scale, ui_scale)
	layer.add_child(panel)
	# Fixed width and wrapped, because the one line that matters is a file path: it has no length
	# worth guessing at, and left to size itself the panel runs off both edges of the window and
	# takes its own close button with it. Arbitrary wrapping, since a path need not break on spaces.
	var rows := _body_of(panel)
	var width := minf(get_viewport().get_visible_rect().size.x / ui_scale - REFUSAL_MARGIN, REFUSAL_WIDTH)
	for line in ["The saved map could not be loaded:", reason + ".",
			"", "It has been left exactly as it is, at", ProjectSettings.globalize_path(map_path),
			"", "Move that file aside to start a new world."]:
		var label := Label.new()
		label.theme_type_variation = "PanelLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.custom_minimum_size.x = width
		label.text = line
		rows.add_child(label)
	# Deferred: a wrapped label only knows how tall it is once it has been laid out once.
	_center_panel.call_deferred(panel)


## Puts a panel in the middle of the window, at the size its contents settled on.
func _center_panel(panel: Control) -> void:
	panel.size = panel.get_combined_minimum_size()
	panel.position = (Vector2(get_viewport().get_visible_rect().size) - panel.size * ui_scale) / 2.0


## The camera keeps up with the walking player, so they never walk off screen. Standing still, it only moves
## where the player drags it.
func _process(_delta: float) -> void:
	if view != null and view.walking:
		camera.position = _clamp_to_map(map.player.position)


## Built in code so the scene file stays untouched while the Godot editor has it open.
## The side panel is laid out in sprite pixels and scaled by `ui_scale`. It stays hidden until a
## tile is selected, and _layout_ui keeps it flush against the right edge, running the full height
## of the window, whenever that window resizes.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	_panel = _titled_panel("Tile", "Close and deselect the tile", _on_close_pressed)
	_panel.scale = Vector2(ui_scale, ui_scale)
	_panel.hide()
	layer.add_child(_panel)
	_tile_title = _title_of(_panel)
	var rows := _body_of(_panel)

	# How far out this tile is, which is both how hard it fights and the ceiling on what drops here.
	_level_label = Label.new()
	_level_label.theme_type_variation = "PanelLabel"
	rows.add_child(_level_label)

	_env_rows = VBoxContainer.new()
	_env_rows.add_theme_constant_override("separation", 4)
	_env_rows.custom_minimum_size = Vector2(ENV_ICON + 46, 0)
	rows.add_child(_env_rows)

	# An expanding spacer pushes the button to the bottom of the full-height panel.
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(filler)

	# Only the buttons that can be pressed are shown (`_update_buttons`).
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	rows.add_child(buttons)
	_chart_button = _button("Chart", "LightButton", "Fight for this tile and what lies behind it")
	_chart_button.pressed.connect(_on_chart_pressed)
	buttons.add_child(_chart_button)
	_move_button = _button("Move here", "LightButton", "Walk to the selected tile")
	_move_button.pressed.connect(_on_move_pressed)
	buttons.add_child(_move_button)
	# And a third thing to do with a tile you have already taken: stand on it and fight until you
	# have had enough. Nothing is won by it but what the bodies were carrying.
	_farm_button = _button("Farm", "LightButton", "Fight here for as long as you like, for the loot")
	_farm_button.pressed.connect(_on_farm_pressed)
	buttons.add_child(_farm_button)
	# `_button` makes them disabled; these are hidden instead, so a shown one is always pressable.
	for button: Button in buttons.get_children():
		button.disabled = false

	_build_character()
	# Skills before the bag: building the bag lays its character sheet out, which measures the whole
	# interface, and `_layout_ui` places every left-hand page including this one.
	_build_skills(layer)
	_build_bag(layer)

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui.call_deferred()


## The character panel, on a layer of its own above the fight: `CombatScene` is a CanvasLayer on
## layer 2, so anything on the UI layer -- or on layer 2 but added before the fight -- is drawn under
## the fight's backdrop. It takes no mouse input anywhere, so standing over a fight costs the player no swings.
func _build_character() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Character"
	layer.layer = 3
	add_child(layer)
	_character = CharacterPanel.new()
	_character.scale = Vector2(ui_scale, ui_scale)
	_character.position = Vector2(8, 8)
	layer.add_child(_character)
	_sync_character()


## Puts the panel back in step with the ledger: what is banked, plus what a run is still pouching.
func _sync_character() -> void:
	var shown := PlayerLevel.add(inventory.level, inventory.xp, _fight_xp if _farming else 0)
	_character.set_state(shown["level"], shown["xp"])


## The skills page: the second square button in the corner and the page it opens, built and placed
## exactly as the bag is and standing against the same edge. The free points stand over the trees, and
## the trees stand side by side under them, each with the button that buys its points back.
func _build_skills(layer: CanvasLayer) -> void:
	_skills_button = _icon_button(STAR_ICON, "What the player has become")
	# Placed beside the bag's button by `_layout_ui`, once both can be measured.
	_skills_button.position = Vector2(8, 8)
	_skills_button.pressed.connect(_on_skills_pressed)
	layer.add_child(_skills_button)

	_skills_panel = _titled_panel("Skills", "Close the skills panel", _on_left_page_closed)
	_skills_panel.scale = Vector2(ui_scale, ui_scale)
	_skills_panel.hide()
	layer.add_child(_skills_panel)
	var rows := _body_of(_skills_panel)
	_skill_points = Label.new()
	_skill_points.theme_type_variation = "PanelLabel"
	_skill_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_skill_points)

	var trees := HBoxContainer.new()
	trees.add_theme_constant_override("separation", SKILL_TREE_GAP)
	rows.add_child(trees)
	for tree: String in SkillTree.trees():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		trees.add_child(column)
		var name_label := Label.new()
		name_label.theme_type_variation = "PanelLabel"
		name_label.text = SkillTree.TREES[tree]["label"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var view := SkillTreeView.new()
		view.node_pressed.connect(_on_skill_pressed)
		view.node_hovered.connect(_on_skill_hovered)
		view.node_unhovered.connect(_hide_skill_card)
		column.add_child(view)
		_skill_views[tree] = view
		# The coin says it costs gold, the number says how much -- the bag's purse, read the same way.
		var reset := _button("", "LightButton", "Take back every point in %s, for gold" % name_label.text)
		reset.icon = Coins.icon()
		reset.pressed.connect(_on_respec_pressed.bind(tree))
		column.add_child(reset)
		_respec_buttons[tree] = reset

	# Last on the layer the page stands on, so it is drawn over the page it describes; and carrying the
	# theme itself, for the orb card's reason.
	_skill_card = SkillCard.new()
	_skill_card.theme = UITheme.theme()
	_skill_card.scale = Vector2(ui_scale, ui_scale)
	_skill_card.hide()
	layer.add_child(_skill_card)
	_refresh_skills()


## The page, redrawn from the inventory: free points, both trees, and what each reset would cost.
func _refresh_skills() -> void:
	var free := inventory.skills.points(inventory.level)
	_skill_points.text = "%d skill point%s" % [free, "" if free == 1 else "s"]
	_skill_points.add_theme_color_override("font_color", Palette.LEAF if free > 0 else Palette.SLATE)
	for tree: String in _skill_views:
		_skill_views[tree].fill(tree, inventory.skills.ranks)
		var reset: Button = _respec_buttons[tree]
		var spent := inventory.skills.spent(tree)
		var cost := inventory.respec_cost(tree)
		reset.text = "Reset %d" % cost if spent > 0 else "Reset"
		reset.disabled = spent <= 0 or inventory.gold < cost
	# Whatever the cursor was over has just been freed.
	_hide_skill_card()


## One point into a skill. Refused quietly when it cannot take one -- the card already says why.
func _on_skill_pressed(id: String) -> void:
	if not inventory.skills.rank_up(id, inventory.level):
		return
	inventory.save(inventory_path)
	print("Learned %s (%d/%d)" % [SkillTree.node(id)["name"], inventory.skills.rank_of(id),
			SkillTree.node(id)["max_rank"]])
	_refresh_skills()


func _on_respec_pressed(tree: String) -> void:
	var cost := inventory.respec_cost(tree)
	if not inventory.respec(tree):
		return
	inventory.save(inventory_path)
	print("Reset %s for %d gold" % [tree, cost])
	_refresh_skills()
	_refresh_gold()


## The card beside the skill under the cursor, measured and placed twice for the orb card's reason.
func _on_skill_hovered(id: String, slot: SkillSlot) -> void:
	_skill_card.fill(id, inventory.skills, inventory.level)
	_skill_card.show()
	_place_skill_card(slot.get_global_rect())
	_place_skill_card.call_deferred(slot.get_global_rect())


func _hide_skill_card() -> void:
	if _skill_card != null:
		_skill_card.hide()


## Beside the page rather than beside the square: the page stands against the left edge with the map
## to its right, so there is always room there, and a card laid over the tree would hide the very
## lines and counts it is being read against. Level with the square, so the eye does not travel.
func _place_skill_card(anchor: Rect2) -> void:
	if not _skill_card.visible:
		return
	var card := _skill_card.get_combined_minimum_size() * ui_scale
	var view_size := get_viewport_rect().size
	var page_right := _skills_panel.position.x + _skills_panel.size.x * ui_scale
	var spot := Vector2(page_right + SLOT_GAP * ui_scale, anchor.position.y)
	_skill_card.position = spot.clamp(Vector2.ZERO, (view_size - card).max(Vector2.ZERO))


## The bag: a button under the character panel and the panel it opens, built the same way as the tile
## panel opposite and flush against the other edge. Inside it, every item the world has handed over
## as a grid of squares, and under that whatever one is being looked at.
func _build_bag(layer: CanvasLayer) -> void:
	_bag_button = _icon_button(CHEST_ICON, "What the monsters have dropped")
	# Placed under the character panel by `_layout_ui`, which is the first moment it can be measured.
	_bag_button.position = Vector2(8, 8)
	_bag_button.pressed.connect(_on_bag_pressed)
	layer.add_child(_bag_button)

	_bag_panel = _titled_panel("Items", "Close the item panel", _on_bag_closed)
	_bag_panel.scale = Vector2(ui_scale, ui_scale)
	_bag_panel.hide()
	layer.add_child(_bag_panel)
	var rows := _body_of(_bag_panel)

	# How full it is and what is in the purse, on one line: the two things that are true of the whole
	# bag rather than of anything in it. Together at the top because they are read together -- "what
	# have I got room for and what can I spend" is one glance -- and because it leaves the foot of
	# the panel to the orb tray, which needs the width.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SLOT_GAP)
	top.custom_minimum_size = Vector2(BAG_WIDTH, 0)
	rows.add_child(top)
	_bag_count = Label.new()
	_bag_count.theme_type_variation = "PanelLabel"
	_bag_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_bag_count)
	# The coin says what the number is, so the word does not have to. A picture reads at a glance and
	# survives the panel being scanned rather than read, which is how a header is looked at.
	var coin := TextureRect.new()
	coin.texture = Coins.icon()
	coin.custom_minimum_size = Vector2(Coins.SIZE, Coins.SIZE)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin)
	_bag_gold = Label.new()
	_bag_gold.theme_type_variation = "PanelLabel"
	# Read on the cream body, so the panel's own dark text rather than Palette.GOLD -- amber on cream
	# is the same weak pairing the palette keeps GOLD out of, and GOLD is the unique item step besides.
	_bag_gold.add_theme_color_override("font_color", Palette.SLATE)
	top.add_child(_bag_gold)

	# The grid scrolls but never shows a bar: Godot's own would sit against the pixel art badly, and
	# drawing one is an art job of its own. The wheel is the ScrollContainer's; dragging is ours. It
	# sits straight on the cream body, the way the pack lays its own inventory out -- a panel inside
	# the panel would be a second frame around the same squares.
	_bag_scroll = ScrollContainer.new()
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_scroll.gui_input.connect(_on_bag_grid_input)
	rows.add_child(_bag_scroll)
	_bag_sections = VBoxContainer.new()
	_bag_sections.add_theme_constant_override("separation", SLOT_GAP)
	# Fixed, so the panel does not change width as the bag fills.
	_bag_sections.custom_minimum_size = Vector2(BAG_WIDTH, 0)
	_bag_scroll.add_child(_bag_sections)

	# What one item is. It takes the grid's place rather than sitting under it: the panel is only as
	# tall as the window, and an elite piece carrying six modifiers would squeeze the squares down to
	# a sliver. Nothing floats, so nothing new can cover the map.
	#
	# The lines scroll and the buttons do not. An elite piece carrying six modifiers and a block of
	# gains under them is taller than a short window, and a panel that simply grew would push Equip
	# and Discard off the bottom of the screen -- the two things the block is opened to press.
	_bag_detail = VBoxContainer.new()
	_bag_detail.add_theme_constant_override("separation", 2)
	_bag_detail.custom_minimum_size = Vector2(BAG_WIDTH, 0)
	_bag_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_detail.hide()
	rows.add_child(_bag_detail)
	_bag_detail_scroll = ScrollContainer.new()
	_bag_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bag_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_detail.add_child(_bag_detail_scroll)
	_bag_detail_rows = VBoxContainer.new()
	_bag_detail_rows.add_theme_constant_override("separation", 2)
	_bag_detail_rows.custom_minimum_size = Vector2(BAG_WIDTH, 0)
	_bag_detail_scroll.add_child(_bag_detail_rows)

	# The orb tray, pinned to the bottom of the panel. It comes after both of the two things above,
	# which are the ones that expand to fill the panel's height -- so it sits under whichever of them
	# is up and stands in both of the bag's states. That is what makes it a footer rather than a
	# section: orbs are not sorted, filtered or chosen between, so the tray wants no heading and no
	# buttons, and it must never scroll out of sight -- least of all while a piece is open, which is
	# exactly when it is being used.
	var orb_rule := ColorRect.new()
	orb_rule.color = Palette.SLATE
	orb_rule.custom_minimum_size = Vector2(0, ItemDetails.RULE_HEIGHT)
	rows.add_child(orb_rule)
	_orb_tray = HBoxContainer.new()
	_orb_tray.add_theme_constant_override("separation", ORB_GAP)
	_orb_tray.custom_minimum_size = Vector2(BAG_WIDTH, 0)
	rows.add_child(_orb_tray)

	layer.add_child(_build_worn())

	# The card floats over everything, so it is a child of the layer rather than of the panel -- a
	# card inside the panel would be clipped by it and would push the tray about as it grew. Scaled
	# here for the reason everything else in this scene is: it is drawn in panel pixels.
	#
	# And added last, after the character sheet, because a CanvasLayer draws its children in tree
	# order. The card is wider than the right-hand end of the tray has room for -- it is placed at the
	# square's own x, and five of the eight squares put it out over the sheet standing against the bag
	# panel's edge. Hanging over that page is the arrangement; being drawn under it is the bug.
	_orb_card = OrbCard.new()
	# It stands on the layer rather than inside a panel, so it carries the theme itself: a type
	# variation means nothing to a Control with no themed ancestor, which is the same reason the
	# "Items" button above sets one.
	_orb_card.theme = UITheme.theme()
	_orb_card.scale = Vector2(ui_scale, ui_scale)
	_orb_card.hide()
	layer.add_child(_orb_card)

	_refresh_bag()


## The character sheet: its own panel standing beside the item panel, not inside it, the way the
## pack draws a wood page next to a cream one. It has no title bar of its own for the same reason --
## the pack gives the spread one, over the other page.
##
## It has two states, and which one is up is decided by what the bag is showing rather than by
## anything the page itself remembers. With nothing selected it is the doll, exactly as it has
## always been. With a bag item selected the comparison takes its place: the piece that item would
## replace, standing beside that item's own block, which is the question the bag is being read to
## answer and cannot be answered by a silhouette.
##
## The panel's own face changes with it. The doll is brown on brown and wants the pack's wood page;
## a stat block wants the cream one, because the darker half of the rarity ramp was picked to be
## read on white and vanishes into wood.
func _build_worn() -> Control:
	_worn_body = VBoxContainer.new()
	_worn_body.add_theme_constant_override("separation", SLOT_GAP)

	_worn_panel = PanelContainer.new()
	_worn_panel.theme = UITheme.theme()
	_worn_panel.theme_type_variation = "WoodPanel"
	_worn_panel.scale = Vector2(ui_scale, ui_scale)
	_worn_panel.hide()
	_worn_panel.add_child(_worn_body)
	return _worn_panel


## The page redrawn from what is worn and what is selected. Called whenever the bag is, because
## equipping moves an item between the two and neither is right on its own.
##
## Children are taken out of the tree as well as freed, the reason `_refresh_bag` gives: a queued
## child is still a child until the end of the frame, and the click hit-test walks exactly this list.
func _refresh_worn() -> void:
	if _worn_body == null:
		return
	_doll = null
	for child: Node in _worn_body.get_children():
		_worn_body.remove_child(child)
		child.queue_free()
	if _bag_selected >= 0 and _bag_selected < inventory.total():
		_show_compare(inventory.items[_bag_selected])
	else:
		_show_doll()
	# The two states are different sizes, so the page is measured and centred again whenever it
	# changes. Twice, for the reason the tile panel is: a container's minimum size is not right until
	# it has laid its new children out, which has not happened yet on this line.
	_layout_ui()
	_layout_ui.call_deferred()


## The doll, with the eight sockets laid *over* the figure, each on the part of the body it belongs
## to. They are translucent, which is what makes an overlay work at all: an opaque square would hide
## the very thing it is pointing at.
##
## Placed by hand against DOLL_SOCKETS. No container expresses "over the shield hand", and there is
## nothing for one to work out -- the figure is a fixed size and so is every socket.
func _show_doll() -> void:
	_worn_panel.theme_type_variation = "WoodPanel"
	_worn_body.custom_minimum_size = Vector2.ZERO
	_doll = Control.new()
	var figure := TextureRect.new()
	figure.texture = load(DOLL_TEXTURE)
	figure.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.position = _doll_origin()
	_doll.add_child(figure)
	var art: Vector2 = figure.texture.get_size() * DOLL_SCALE + _doll_origin()
	for socket: Equipment.Socket in DOLL_SOCKETS:
		art = art.max(_socket_spot(socket) + Vector2(ItemSlot.SIDE, ItemSlot.SIDE))
	_doll.custom_minimum_size = art
	_doll.gui_input.connect(_on_doll_input)
	for socket: Equipment.Socket in DOLL_SOCKETS:
		var item := inventory.equipment.item_at(socket)
		var chosen := _worn_selected == socket
		var slot := (ItemSlot.make(item, chosen, true) if item != null
				else ItemSlot.empty(Equipment.LABELS[socket], _socket_mark(socket), chosen, true))
		slot.position = _socket_spot(socket)
		slot.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
		slot.set_meta("socket", socket)
		_doll.add_child(slot)
	_worn_body.add_child(_doll)


## How far everything is pushed right so that no socket hangs off the left of the page. The hand
## sockets are centred on hands that sit at the very edge of the sprite, so without this the offhand
## would be cut in half by the frame.
func _doll_origin() -> Vector2:
	var least := Vector2.ZERO
	for socket: Equipment.Socket in DOLL_SOCKETS:
		least = least.min(_socket_corner(socket))
	return -least.min(Vector2.ZERO)


## The top-left corner of a socket's square, before the page is shifted to fit it.
func _socket_corner(socket: Equipment.Socket) -> Vector2:
	return (DOLL_SOCKETS[socket] * DOLL_SCALE - Vector2(ItemSlot.SIDE, ItemSlot.SIDE) / 2.0).floor()


## Where the socket actually goes on the page.
func _socket_spot(socket: Equipment.Socket) -> Vector2:
	return _socket_corner(socket) + _doll_origin()


## What the selected piece would replace. The socket is the one the Equip button beside it targets
## -- `sockets_for` puts the emptiest first -- so the page shows precisely what pressing Equip would
## take off, and rings and the shield-or-torch offhand are settled without a second rule.
func _show_compare(item: Item) -> void:
	var open := inventory.equipment.sockets_for(item)
	if open.is_empty():
		# Nothing in the game has no socket, but a piece retired from the tables would, and the doll
		# is a better answer to that than an empty page.
		_show_doll()
		return
	_worn_panel.theme_type_variation = "TextPanel"
	_worn_body.custom_minimum_size = Vector2(WORN_WIDTH, 0)
	var socket: Equipment.Socket = open[0]
	var worn := inventory.equipment.item_at(socket)
	_worn_body.add_child(_worn_heading("Equipped · %s" % Equipment.LABELS[socket]))
	if worn == null:
		_worn_body.add_child(ItemDetails.line("Nothing worn", Palette.SLATE, WORN_WIDTH))
		return
	# Its own box under the heading: ItemDetails.fill empties whatever it is given, so the heading
	# cannot share a container with the block.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	ItemDetails.fill(column, worn, WORN_WIDTH)
	_worn_body.add_child(column)
	var full := inventory.is_full()
	var take_off := _button("Unequip", "LightButton", "The bag is full" if full
			else "Take this off and put it back in the bag")
	take_off.disabled = full
	take_off.pressed.connect(_on_compare_unequip_pressed.bind(item, socket))
	_worn_body.add_child(take_off)


## Taking the worn piece off without losing the piece being judged against it. `_on_unequip_pressed`
## ends on the socket list, which is right when the socket is what was opened and wrong here: the
## player is halfway through deciding about a piece in the bag and should not have to find it again.
##
## The item is found again by identity rather than kept by index, because the piece coming back into
## the bag changes `inventory.order()` and so what every index after it points at.
func _on_compare_unequip_pressed(item: Item, socket: Equipment.Socket) -> void:
	if inventory.unequip(socket):
		inventory.save(inventory_path)
	_select_item(inventory.items.find(item))


## The heading over the comparison, with the rule the stat blocks use under it. The doll needs none:
## a figure with a helmet on its head does not have to be told it is what you are wearing.
func _worn_heading(text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.theme_type_variation = "PanelLabel"
	title.text = text
	title.add_theme_color_override("font_color", Palette.SLATE)
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Palette.SLATE
	rule.custom_minimum_size = Vector2(WORN_WIDTH, ItemDetails.RULE_HEIGHT)
	box.add_child(rule)
	return box


## The faint mark an empty socket carries, for the two the doll's own body does not explain.
func _socket_mark(socket: Equipment.Socket) -> Texture2D:
	if socket == Equipment.Socket.AMULET:
		return load(SOCKET_AMULET_TEXTURE)
	if socket in [Equipment.Socket.RING_LEFT, Equipment.Socket.RING_RIGHT]:
		return load(SOCKET_RING_TEXTURE)
	return null


## A click on a socket opens what is in it, the way a click on a bag square does. An empty one is not
## worth opening, and a second click on the one already open closes it.
func _on_doll_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	for slot: Control in _doll.get_children():
		if not slot.has_meta("socket") or not Rect2(slot.position, slot.size).has_point(event.position):
			continue
		var socket: Equipment.Socket = slot.get_meta("socket")
		if inventory.equipment.item_at(socket) == null:
			continue
		_select_socket(-1 if socket == _worn_selected else socket)
		return


## Opens a worn piece's stat block, in the grid's place, with Unequip under it. -1 closes it.
func _select_socket(socket: int) -> void:
	_worn_selected = socket
	_bag_selected = -1
	_refresh_bag()


## The bag, in sections: one per level, highest first, and inside a level the best and newest first.
## A level is what the player reads a bag by -- it is the ceiling on what a piece is worth and the
## thing that changes as they walk -- so it is the heading, and rarity sorts underneath it.
##
## Every square carries the index of the item it draws. The grid used to be one flat rectangle and
## an item's place in it could be counted back from where its square sat; sections make that
## arithmetic wrong, and saying which item a square is is both simpler and true whatever the order.
func _refresh_bag() -> void:
	# Taken out of the tree as well as freed. A queued child is still a child until the end of the
	# frame, and the click hit-test walks exactly this list -- so a square left standing there is a
	# square that can be clicked after the item behind it has gone.
	for child: Node in _bag_sections.get_children():
		_bag_sections.remove_child(child)
		child.queue_free()
	var by_level := {}
	for i in inventory.order():
		var level: int = inventory.items[i].level
		if not by_level.has(level):
			by_level[level] = []
		by_level[level].append(i)
	for level: int in inventory.levels():
		_bag_sections.add_child(_section_heading(level))
		var rule := ColorRect.new()
		rule.color = Palette.SLATE
		rule.custom_minimum_size = Vector2(0, ItemDetails.RULE_HEIGHT)
		_bag_sections.add_child(rule)
		# A level with a rule on it and nothing in it gets its heading and no squares: that is where
		# the rule is turned off again, and it would have nowhere to live otherwise.
		if not by_level.has(level):
			continue
		var grid := GridContainer.new()
		grid.columns = GRID_COLS
		grid.add_theme_constant_override("h_separation", SLOT_GAP)
		grid.add_theme_constant_override("v_separation", SLOT_GAP)
		_bag_sections.add_child(grid)
		for i: int in by_level[level]:
			var slot := ItemSlot.make(inventory.items[i], i == _bag_selected)
			slot.set_meta("bag_index", i)
			grid.add_child(slot)
	_bag_count.text = "%d / %d" % [inventory.total(), Inventory.CAPACITY]
	_bag_count.add_theme_color_override("font_color",
			Palette.RUST if inventory.is_full() else Palette.SLATE)
	_refresh_gold()
	_refresh_orbs()
	_refresh_worn()
	if _bag_selected >= 0 and _bag_selected < inventory.total():
		_show_item(_bag_selected)
	elif _worn_selected >= 0 and inventory.equipment.item_at(_worn_selected) != null:
		_show_worn(_worn_selected)
	else:
		_hide_item()


## The purse. Its own call rather than a line inside `_refresh_bag`, because a kill moves it and
## nothing else: rebuilding every square in the grid for a number at the bottom of the panel is work
## with nothing to show for it, and there are ten or fifteen kills to a fight and no end of them to a run.
func _refresh_gold() -> void:
	_bag_gold.text = str(inventory.gold)


## The piece the bag currently has open, or null when it is showing the grid. The one place that
## knows a stat block can be a bag item *or* a worn one, so everything that asks "what is open"
## gets the same answer.
func _open_piece() -> Item:
	if _bag_selected >= 0 and _bag_selected < inventory.total():
		return inventory.items[_bag_selected]
	if _worn_selected >= 0:
		return inventory.equipment.item_at(_worn_selected)
	return null


## The orb tray, rebuilt. Its own call beside `_refresh_gold` for the same reason that one is: a
## kill moves one count and nothing else, and rebuilding every square in the grid for it is work
## with nothing to show.
##
## The tray has two states, and the bag decides which -- the same way the character sheet beside it
## swaps its doll for a comparison. At rest it is what the player holds, every owned orb lit. With a
## piece open it answers a different question: which of these can do anything to *this*. So there is
## no crafting row in the stat block and no arming step; the thing that is already on screen becomes
## the thing you press.
func _refresh_orbs() -> void:
	for child: Node in _orb_tray.get_children():
		_orb_tray.remove_child(child)
		child.queue_free()
	var against := _open_piece()
	for orb: String in OrbTable.orbs():
		var held := inventory.orb_count(orb)
		# With nothing open every held orb is usable: the tray is not refusing anything, it is simply
		# saying what is there.
		var usable := against == null or OrbTable.can_apply(orb, against)
		var slot := OrbSlot.make(orb, held, usable)
		slot.pressed.connect(_on_orb_pressed)
		slot.hovered.connect(_on_orb_hovered.bind(slot))
		slot.unhovered.connect(_on_orb_unhovered)
		_orb_tray.add_child(slot)
	# Whatever the cursor was over has just been freed, so the card is describing a square that no
	# longer exists. It comes back the moment the cursor moves.
	_hide_orb_card()


## One orb spent on whatever the bag has open. Applied first and spent second, so an orb that turns
## out to have nothing to do is never consumed -- `OrbTable.apply` is the only thing that decides
## whether it did anything, and the count follows its answer.
func _on_orb_pressed(orb: String) -> void:
	var item := _open_piece()
	if item == null or inventory.orb_count(orb) <= 0:
		return
	if not OrbTable.apply(orb, item, _craft_rng):
		return
	inventory.spend_orb(orb)
	inventory.save(inventory_path)
	print("Spent %s on %s (%s, level %d)"
			% [orb, item.display_name(), item.rarity_name(), item.level])
	# Crafting adds nothing to the bag and takes nothing out of it, so the selection is still the
	# same piece and `_refresh_bag` reopens it -- the block stays put and simply says something new.
	_refresh_bag()


## The card, beside the square the cursor is on. Measured and placed twice, for the reason the tile
## panel is: the first pass is before the labels have laid themselves out and so is a guess.
func _on_orb_hovered(orb: String, slot: OrbSlot) -> void:
	_orb_card.fill(orb, inventory.orb_count(orb), _open_piece())
	_orb_card.show()
	_place_orb_card(slot.get_global_rect())
	_place_orb_card.call_deferred(slot.get_global_rect())


func _on_orb_unhovered() -> void:
	_hide_orb_card()


func _hide_orb_card() -> void:
	if _orb_card != null:
		_orb_card.hide()


## Puts the card over the square and inside the window.
##
## Above it rather than beside it, which is the one direction there is room in: the tray is at the
## foot of a panel that runs the whole height of the window and stands against its left edge, so one
## side of it is the screen and the other is the character sheet. Above, it covers the foot of
## whatever the bag is showing for as long as the cursor rests there, which is what a card is for.
func _place_orb_card(anchor: Rect2) -> void:
	if not _orb_card.visible:
		return
	var card := _orb_card.get_combined_minimum_size() * ui_scale
	var view := get_viewport_rect().size
	var spot := Vector2(anchor.position.x, anchor.position.y - card.y - SLOT_GAP * ui_scale)
	_orb_card.position = spot.clamp(Vector2.ZERO, (view - card).max(Vector2.ZERO))


## A press that stays put is a click on whatever square is under it; a press that travels drags the
## list. The same rule HexMap uses to tell a tile click from a pan, for the same reason: one gesture
## should not need a second button. Everything arrives here rather than at the squares themselves,
## because a square that took the press would break every drag that began on one.
func _on_bag_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_bag_drag_from = event.position
			_bag_drag_scroll = _bag_scroll.scroll_vertical
			_bag_dragged = 0.0
		elif _bag_dragged < BAG_DRAG_THRESHOLD:
			# The event is in the scroll container's own space, so how far the grid has been scrolled
			# is what turns it into a spot on the grid.
			_on_bag_clicked(event.position + Vector2(0.0, _bag_scroll.scroll_vertical))
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_bag_dragged += absf(event.relative.y)
		_bag_scroll.scroll_vertical = _bag_drag_scroll - int(event.position.y - _bag_drag_from.y)


## One section's heading: which level it is, and the two things that can be done with the whole of
## it. Clear throws away what is there; Auto stops any more of it arriving. They are deliberately
## two buttons rather than one -- turning the rule on does not empty the section, because a player
## who is done with level 3 from now on has not necessarily finished with the three they are holding.
func _section_heading(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	# The rule is said in the heading, in a word and in a colour, and not left to the button's own
	# pressed face: the pack presses a button by drawing it one pixel lower with its shadow gone,
	# which is right for a press you are watching happen and far too quiet for a state you are
	# reading off four headings at once.
	var ruled := inventory.autodiscards(level)
	var title := Label.new()
	title.theme_type_variation = "PanelLabel"
	title.text = "Level %d auto" % level if ruled else "Level %d" % level
	title.add_theme_color_override("font_color", Palette.RUST if ruled else Palette.SLATE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	# A toggle rather than a second sprite: the theme already draws a held-down face, so the rule
	# being on looks like the pack's own pressed button. Four letters cannot say what it does, so the
	# tooltip says it in full.
	var auto := _button("Auto", "LightButton",
			"Stop throwing away what is found at level %d" % level if ruled
			else "Throw away everything found at level %d from now on" % level)
	auto.disabled = false
	auto.toggle_mode = true
	auto.button_pressed = ruled
	auto.toggled.connect(_on_autodiscard_toggled.bind(level))
	row.add_child(auto)

	var clear := _button("Clear", "LightDangerButton",
			"Throw away the %d item(s) held at level %d" % [inventory.count_at(level), level])
	clear.disabled = inventory.count_at(level) == 0
	clear.pressed.connect(_on_clear_level_pressed.bind(level))
	row.add_child(clear)
	return row


## Tells the bag to stop bringing a level, or to start again. It touches nothing already held: that
## is what the button beside it is for.
func _on_autodiscard_toggled(on: bool, level: int) -> void:
	inventory.set_autodiscard(level, on)
	inventory.save(inventory_path)
	if _combat != null:
		_combat.autodiscard = inventory.autodiscards
	_select_item(-1)


## Throws away a whole level at once.
func _on_clear_level_pressed(level: int) -> void:
	var gone := inventory.discard_level(level)
	print("Discarded %d item(s) at level %d" % [gone.size(), level])
	inventory.save(inventory_path)
	_select_item(-1)
	_refresh_bag_room()


## Opens the square under `at`, or closes the stat block when the click landed on bare panel. The
## squares take no input, so which one was hit is worked out from where the cursor is -- and now
## from which section it is in, since a square's position is its own grid's.
func _on_bag_clicked(at: Vector2) -> void:
	for section: Node in _bag_sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Control in (section as GridContainer).get_children():
			if not Rect2((section as Control).position + slot.position, slot.size).has_point(at):
				continue
			var index: int = slot.get_meta("bag_index", -1)
			_select_item(-1 if index == _bag_selected else index)
			return
	_select_item(-1)


func _select_item(index: int) -> void:
	_bag_selected = index
	_worn_selected = -1
	_refresh_bag()


## What one item in the bag is, shown in the grid's place, with Equip under it where there is
## somewhere for it to go. ItemDetails writes the lines, so an item reads the same here as it does on
## the panel at the end of a fight -- and the same as the worn piece beside it: the block says what
## this piece is and nothing about what it would replace. The character sheet shows that piece whole,
## which is the comparison, so a second one worked out in signed numbers under the stats said the
## same thing twice in two different languages.
func _show_item(index: int) -> void:
	var item := inventory.items[index]
	# The emptiest socket it fits, so a bare ring finger fills before a ring already on is swapped.
	var open := inventory.equipment.sockets_for(item)
	_fill_detail(item)
	if not open.is_empty():
		var socket: Equipment.Socket = open[0]
		var worn := inventory.equipment.item_at(socket)
		var equip := _button("Equip", "LightButton", "Wear this in the %s socket%s"
				% [Equipment.LABELS[socket].to_lower(),
					"" if worn == null else ", putting %s back in the bag" % worn.display_name()])
		equip.disabled = false
		equip.pressed.connect(_on_equip_pressed.bind(item, socket))
		_bag_detail.add_child(equip)
	# No confirmation. The gesture is already two clicks deep, items are plentiful, and a game that
	# asks twice about a level-2 common teaches the player to click through the question.
	var discard := _button("Discard", "LightDangerButton", "Throw this away for good")
	discard.disabled = false
	discard.pressed.connect(_on_discard_pressed.bind(item))
	_bag_detail.add_child(discard)
	_add_back_button("Back to everything you are carrying", _select_item.bind(-1))


## What one worn piece is, in the same space, with Unequip under it.
## A worn piece gets no Discard of its own: the cap is on the bag alone, so nothing presses the
## player to destroy what they are wearing, and Unequip then Discard says it in two honest steps.
## Which is also why a full bag greys the one button here -- there is nowhere for the piece to go,
## and destroying something to make room for a piece being looked at would be a trap.
func _show_worn(socket: Equipment.Socket) -> void:
	_fill_detail(inventory.equipment.item_at(socket))
	var full := inventory.is_full()
	var take_off := _button("Unequip", "LightButton", "The bag is full" if full
			else "Take this off and put it back in the bag")
	take_off.disabled = full
	take_off.pressed.connect(_on_unequip_pressed.bind(socket))
	_bag_detail.add_child(take_off)
	_add_back_button("Back to everything you are carrying", _select_socket.bind(-1))


## The stat block itself, and whatever buttons were under it cleared off.
##
## The lines go inside the scroll and the buttons outside it, so only the two lists that can run long
## ever move.
func _fill_detail(item: Item) -> void:
	for child: Node in _bag_detail.get_children():
		if child != _bag_detail_scroll:
			_bag_detail.remove_child(child)
			child.queue_free()
	ItemDetails.fill(_bag_detail_rows, item, BAG_WIDTH)
	_bag_detail_scroll.scroll_vertical = 0


## Light, not wood: these stand on the white panel, and the theme pairs them that way round.
func _add_back_button(hint: String, action: Callable) -> void:
	var back := _button("Back", "LightButton", hint)
	back.disabled = false
	back.pressed.connect(action)
	_bag_detail.add_child(back)
	_bag_scroll.hide()
	_bag_detail.show()


## Wearing something moves it out of the bag, so the stat block that was open is gone with it -- the
## panel goes back to the grid rather than to a piece that is no longer where it was.
func _on_equip_pressed(item: Item, socket: Equipment.Socket) -> void:
	if inventory.equip(item, socket):
		inventory.save(inventory_path)
	_select_item(-1)


func _on_unequip_pressed(socket: Equipment.Socket) -> void:
	if inventory.unequip(socket):
		inventory.save(inventory_path)
	_select_socket(-1)


## One item thrown away by hand, from the bag.
func _on_discard_pressed(item: Item) -> void:
	if inventory.remove(item):
		print("Discarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
		inventory.save(inventory_path)
	_select_item(-1)
	_refresh_bag_room()


func _hide_item() -> void:
	_bag_detail.hide()
	_bag_scroll.show()


## One row per environment on the tile: a swatch of that terrain, then its share of the tile.
func _show_environments(weights: Dictionary) -> void:
	for child: Node in _env_rows.get_children():
		child.queue_free()
	var envs := weights.keys()
	envs.sort_custom(func(a: String, b: String) -> bool: return weights[a] > weights[b])
	for env: String in envs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_env_icon(env))
		var percent := Label.new()
		percent.theme_type_variation = "PanelLabel"
		percent.text = "%d%%" % round(weights[env] * 100.0)
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(percent)
		_env_rows.add_child(row)


## A swatch cut from the middle of that environment's own tile on the hex sheet, so the icon always
## shows the terrain the player sees on the map and there is no second set of art to keep in step.
func _env_icon(env: String) -> TextureRect:
	var source := map.tileset.tile_set.get_source(HexTileset.SOURCE_ID) as TileSetAtlasSource
	var tile_size := map.tileset.tile_size
	@warning_ignore("integer_division")  # 56 and 64 less 16 are both even, so the swatch is centred
	var origin := map.tileset.atlas_coords("env_%s_v1" % env) * tile_size + (tile_size - ENV_ICON_SIZE) / 2
	var atlas := AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = Rect2(origin, ENV_ICON_SIZE)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(ENV_ICON_SIZE)
	return icon


## A panel the way the UI pack draws one: a green title bar with the title on it and an X at its
## right end, and a cream body under it running the rest of the height. The two are separate panels
## stacked in a VBox rather than one sprite, because the pack's headered panel fixes its bar at 13 px
## and Pixellari needs 16 to stay legible -- see the note in tools/ui_kit.py. Stacked, the bar grows
## to whatever the title needs and the body takes the rest.
##
## The X sits on the map side of the panel, where the hand already is. The caller fills the body,
## which `_body_of` hands back.
func _titled_panel(title_text: String, tooltip: String, on_close: Callable) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.theme = UITheme.theme()
	stack.add_theme_constant_override("separation", 0)

	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	stack.add_child(bar)
	var header := HBoxContainer.new()
	bar.add_child(header)
	var title := Label.new()
	title.theme_type_variation = "PanelLabel"
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	# The pack's own close button: a drawn X rather than the letter typed on a green button, so it is
	# placed at the size the pack drew it and asks the theme what that is.
	var close := _button("", "CloseButton", tooltip)
	close.disabled = false
	close.custom_minimum_size = Vector2(UITheme.icon_size("CloseButton"))
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	header.add_child(close)

	var body := PanelContainer.new()
	body.theme_type_variation = "TextPanel"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	body.add_child(rows)
	return stack


## Where a titled panel's contents go: the VBox inside its body, which is the second child.
func _body_of(panel: VBoxContainer) -> VBoxContainer:
	return panel.get_child(1).get_child(0)


## A titled panel's title label: the first thing in its header bar.
func _title_of(panel: VBoxContainer) -> Label:
	return panel.get_child(0).get_child(0).get_child(0)


func _button(text: String, variation: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.tooltip_text = tooltip
	button.disabled = true
	return button


## One of the corner's square buttons: a brown face with a mark on it and no words at all. It takes
## its size from the mark, which is why both marks are cut on one square (see tools/ui_kit.py), and
## it carries the theme itself for the reason the bag's button always has -- it stands on the map,
## and a type variation means nothing to a Control with no themed ancestor.
func _icon_button(texture: String, tooltip: String) -> Button:
	var button := _button("", "BrownIconButton", tooltip)
	button.theme = UITheme.theme()
	button.disabled = false
	button.icon = load(texture)
	button.expand_icon = false
	button.scale = Vector2(ui_scale, ui_scale)
	return button


## Both panels are scaled by `ui_scale`, so they are sized in sprite pixels: a height of
## view/ui_scale fills the window exactly. Their contents keep their own heights and stack from the
## top. The tile panel is flush against the right edge, the item panel against the left; the button
## that opens it keeps its corner.
func _layout_ui() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var height := view_size.y / ui_scale
	var width := _panel.get_combined_minimum_size().x
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(view_size.x - width * ui_scale, 0.0)
	_bag_panel.size = Vector2(_bag_panel.get_combined_minimum_size().x, height)
	_bag_panel.position = Vector2.ZERO
	_skills_panel.size = Vector2(_skills_panel.get_combined_minimum_size().x, height)
	_skills_panel.position = Vector2.ZERO
	# The two square buttons in a row under the character panel: what you carry, then what you are.
	var corner := Vector2(8, _character.position.y + (_character.size.y + 4) * ui_scale)
	_bag_button.position = corner
	_skills_button.position = corner + Vector2(
			(_bag_button.get_combined_minimum_size().x + CORNER_GAP) * ui_scale, 0.0)
	if _combat != null:
		_combat.xp_target = _character.xp_point()
	# The character sheet stands outside the item panel, against its right edge and only as tall as it
	# needs to be -- a wood page next to the cream one, the way the pack draws the spread. The item
	# panel runs the full height of the window and this one does not, so it is centred against it
	# rather than hung from the top, where the odd heights would read as one of them having slipped.
	if _worn_panel != null:
		_worn_panel.size = _worn_panel.get_combined_minimum_size()
		_worn_panel.position = Vector2((_bag_panel.size.x + WORN_GAP) * ui_scale,
				(view_size.y - _worn_panel.size.y * ui_scale) / 2.0)


func _on_tile_clicked(cell: Vector2i, info: Dictionary) -> void:
	_update_buttons()
	_panel.show()
	_layout_ui()
	var spot := map_origin + cell
	var weights: Dictionary = info["environments"]
	var parts := PackedStringArray()
	for env: String in weights:
		parts.append("%s %.1f%%" % [env, weights[env] * 100])
	var line := "Clicked %s (world %s): %s | %s" % [cell, spot, info["name"], ", ".join(parts)]
	if towns.has_town(spot):
		line += " | town connected to %s" % [towns.connections(spot)]
	print(line)
	var tile_name := view.name_of(cell)
	_tile_title.text = tile_name if tile_name != "" else "Tile"
	_level_label.text = "Level %d" % view.level_of(cell)
	_show_environments(weights)
	# The rows are filled after _layout_ui ran, and the level line can be wider than the environment
	# rows that pin the panel's width, so the panel is measured again now that it holds everything.
	_layout_ui()


## Dragging moves the camera the other way, so the map follows the cursor.
func _on_map_dragged(relative: Vector2) -> void:
	camera.position = _clamp_to_map(camera.position - relative / camera.zoom.x)


## Keeps the camera over the map, on the middle of the outermost tiles.
func _clamp_to_map(to: Vector2) -> Vector2:
	var first := map.ground_layer.map_to_local(view.rect.position)
	var last := map.ground_layer.map_to_local(view.rect.end - Vector2i.ONE)
	return to.clamp(first, last)


## A tile has to be taken before it can be charted: a lineup of whatever lives on it, against a
## clock. How long a lineup and how long a clock is the tile's own -- a settlement is a set piece --
## which is what the variant is passed in for, beside picking the backdrop.
## Winning charts it as before; losing leaves the map exactly as it was, free to try again.
func _on_chart_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_chart(cell):
		return
	# Not next to it yet: walk to the nearest charted tile beside it, and the fight opens on arrival.
	var from := view.chart_from(cell)
	if from != view.player_cell:
		_chart_target = cell
		print("Walking to %s to chart %s" % [from, cell])
		view.move_to(from)
		_update_buttons()
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	var variant := view.area_variant(cell)
	print("Fighting for %s, %s (%s, %s %d)" % [view.name_of(cell), cell, env, variant,
			CombatScene.layout_for(cell)])
	_open_fight(Encounter.for_tile(cell, env, variant), cell, false)


## Farming the selected tile: the same arena and the same enemies, coming forever, with no clock
## and nothing riding on it. It takes a tile already taken, so nothing about the map can change.
func _on_farm_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_farm(cell):
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	var variant := view.area_variant(cell)
	print("Farming %s, %s (%s, %s)" % [view.name_of(cell), cell, env, variant])
	_open_fight(Encounter.farm(cell, env, variant), cell, true)


## Puts a fight on the screen, whichever kind it is. Both kinds are opened exactly alike -- armed
## from what is worn, drawn on the tile's own backdrop, with the map and every Control out of the
## way -- so the one that comes later cannot quietly differ from the one that came first.
func _open_fight(fight: Encounter, cell: Vector2i, farming: bool) -> void:
	# What the player is wearing, read once as the fight opens. Changing gear mid-fight is not a
	# thing that can happen -- the bag goes away while one is on -- so there is nothing to keep live.
	fight.arm(inventory.stats())
	# Until the player has seen their first drop, the first elite they meet is promised one.
	fight.guarantee_elite = not inventory.first_elite_taken
	_farming = farming
	_banked = false
	_elite_dropped = false
	_fight_drops.clear()
	_fight_gold = 0
	_fight_orbs = {}
	_fight_xp = 0
	_combat = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	_combat.finished.connect(_on_combat_finished.bind(cell))
	# Not `Encounter.loot_dropped`: the fight applies the player's autodiscard rule, and everything
	# downstream believes the fight. A second listener applying the rule a second way is how the
	# counter, the pouch and the bag would come to disagree about what a run found.
	_combat.autodiscard = inventory.autodiscards
	_combat.loot_kept.connect(_on_loot_dropped)
	_combat.loot_discarded.connect(_on_loot_autodiscarded)
	_combat.drop_discarded.connect(_on_drop_discarded)
	_combat.gold_gained.connect(_on_gold_gained)
	_combat.orb_gained.connect(_on_orb_gained)
	_combat.xp_gained.connect(_on_xp_gained)
	_combat.xp_absorbed.connect(_on_xp_absorbed)
	add_child(_combat)
	# Told before the fight is built, so the warning is right on its first frame rather than a frame
	# later: a run that opens with a full bag should say so as it opens.
	_refresh_bag_room()
	# What the tile has been called since the player first laid eyes on it. Read off the map rather
	# than worked out here: the map is what named it and what remembers the name.
	_combat.place = view.name_of(cell)
	_combat.xp_target = _character.xp_point()
	_combat.begin(fight, cell, ui_scale, view.area_variant(cell))
	# The map keeps its state but stops running, so nothing walks on underneath the fight.
	map.hide()
	map.process_mode = Node.PROCESS_MODE_DISABLED
	_panel.hide()
	# The buttons have to go, not just be covered: a Control takes the mouse before the fight sees
	# it, so one left in that corner would quietly eat the player's swings.
	_close_left_pages()
	_show_corner(false)
	_character.show()


## Back from the fight. The tile is charted only if it was won; either way the map comes back
## exactly as it was left.
func _on_combat_finished(won: bool, cell: Vector2i) -> void:
	var kills: int = _combat.fight.kills()
	# Read before the fight is freed, and before banking, which zeroes the run's own pouch.
	var earned: int = _combat.fight.gold
	_bank_farm_loot()
	_combat.queue_free()
	_combat = null
	# Gems still in the air when the fight closed never arrive, so the panel is put back on the ledger.
	_sync_character()
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	_show_corner(true)
	var turned_up := PackedStringArray()
	for drop in _fight_drops:
		turned_up.append("%s (%s)" % [drop.type, drop.rarity_name()])
	print("The fight turned up: %s, and %d gold"
			% ["nothing" if turned_up.is_empty() else ", ".join(turned_up), earned])
	if _farming:
		# Nothing about the map moves for a run. The tile was already taken; the loot is the whole of it.
		print("Farmed %s, %d slain" % [cell, kills])
	elif won:
		print("Charted %s, showing %d tile(s) behind it; walking there" % [cell, view.chart(cell)])
	else:
		print("Lost the fight for %s; it stays uncharted" % cell)
	_farming = false
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()


## The player walks to the tile; both buttons stay disabled until they get there.
func _on_move_pressed() -> void:
	var cell := map.selected_cell
	print("Walking to %s, %d tile(s) away" % [cell, view.move_to(cell).size()])
	_update_buttons()


## The one place the map's own state changes: charting a tile walks the player onto it, and the
## map grows on arrival. So this is where it is written down, and a crash costs at most the step in
## progress rather than the session.
func _on_player_arrived(cell: Vector2i) -> void:
	print("Arrived at %s" % cell)
	_save_map()
	_update_buttons()
	if _chart_target != HexMap.NO_CELL:
		var target := _chart_target
		_chart_target = HexMap.NO_CELL
		# Selecting it again is what the fight reads, in case the player clicked elsewhere on the way.
		map.select_cell(target)
		_on_chart_pressed()


## A tile is either something to look at or somewhere to go, and neither while the player is walking.
## A button that can't be pressed is not shown at all.
func _update_buttons() -> void:
	var cell := map.selected_cell
	_chart_button.visible = view.can_chart(cell)
	_move_button.visible = view.can_move_to(cell)
	_farm_button.visible = view.can_farm(cell)


## A kill left something behind. It is the player's whatever the fight does next, so a charting
## fight writes it to disk as it lands rather than at the end: closing the game mid-fight cannot
## cost a find. A farm run has no end of its own to write at and could run for an hour, so its
## finds wait in the pouch and go in as one write when the run is over.
func _on_loot_dropped(index: int, item: Item) -> void:
	_fight_drops.append(item)
	_elite_dropped = _elite_dropped or _dropped_by_elite(index)
	print("Dropped %s (%s, level %d, %d modifier(s))"
			% [item.type, item.rarity_name(), item.level, item.mods.size()])
	if _farming:
		_refresh_bag_room()
		return
	_report_destroyed(inventory.add(item))
	if _elite_dropped:
		inventory.first_elite_taken = true
	inventory.save(inventory_path)
	_refresh_bag()
	_refresh_bag_room()


## A body's purse. It follows the same rule its finds do, and for the same reasons: a charting
## fight is over in a minute and writes each one as it lands, so closing the game mid-fight cannot
## cost them; a run could go an hour and has no end of its own, so its gold waits here and goes in
## with the pouch. Nothing about a purse can be refused -- it is a number, not a square, so the bag's
## cap has nothing to say about it and no rule of the player's filters it.
func _on_gold_gained(amount: int) -> void:
	_fight_gold += amount
	if _farming:
		return
	inventory.gold += amount
	inventory.save(inventory_path)
	_refresh_gold()


## An orb off a body. It follows gold exactly, and for exactly gold's reasons: banked as it lands in
## a charting fight, pouched until the end of a run. Nothing about an orb can be refused either --
## it is a count rather than a square, so the cap has nothing to say about it and no rule of the
## player's filters it.
## A body's experience, banked or pouched exactly as its purse is. The panel is not told here: it fills
## when the gems reach it, on `_on_xp_absorbed`.
func _on_xp_gained(amount: int) -> void:
	_fight_xp += amount
	if _farming:
		return
	var gained := inventory.add_xp(amount)
	inventory.save(inventory_path)
	if gained > 0:
		print("Level up: %d" % inventory.level)


## The gems of one body have landed in the bar.
func _on_xp_absorbed(amount: int) -> void:
	var gained := _character.absorb(amount)
	if gained > 0 and _farming:
		print("Level up: %d (banked when the run ends)" % _character.level)


func _on_orb_gained(orb: String) -> void:
	_fight_orbs[orb] = int(_fight_orbs.get(orb, 0)) + 1
	if _farming:
		return
	inventory.add_orb(orb)
	inventory.save(inventory_path)
	_refresh_orbs()


## A find the player's own rule threw away on sight. It is never in the pouch and never in the bag,
## so the only thing left to do with it is retire the promise of a first elite drop: an elite did
## hand something over, and a rule the player set themselves is not a reason to promise it again.
func _on_loot_autodiscarded(index: int, item: Item) -> void:
	print("Autodiscarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
	if not _dropped_by_elite(index):
		return
	_elite_dropped = true
	if _farming:
		return
	inventory.first_elite_taken = true
	inventory.save(inventory_path)


## A find the player threw away by hand, from the fight's own panel. A run is still holding its
## pouch, so dropping it there is the whole of it; a tile fight has already banked it, so it comes
## out of the bag and off the disk too.
func _on_drop_discarded(item: Item) -> void:
	_fight_drops.erase(item)
	if not _farming and inventory.remove(item):
		inventory.save(inventory_path)
		_refresh_bag()
	_refresh_bag_room()


## Tells the fight how much room is left, which is what puts the full-bag warning up. A run's pouch
## is not in the bag yet but is going there, so it counts against the room it will need.
func _refresh_bag_room() -> void:
	if _combat == null:
		return
	_combat.bag_room = maxi(0, inventory.room_left() - (_fight_drops.size() if _farming else 0))


## Says what the bag had to destroy to fit what was found. Nothing is said when nothing went, which
## is almost always.
func _report_destroyed(destroyed: Array[Item]) -> void:
	for item: Item in destroyed:
		print("The bag was full: destroyed %s (%s, level %d)"
				% [item.type, item.rarity_name(), item.level])


## Whether the enemy in slot `index` of the fight going on is an elite. Asked of the roster rather
## than of the position: a farm run's elites come round forever and there is no last one.
func _dropped_by_elite(index: int) -> bool:
	if _combat == null or index >= _combat.fight.lineup.size():
		return false
	return EnemyRoster.tier_of(_combat.fight.lineup[index]) == EnemyRoster.Tier.ELITE


## Empties a farm run's pouch into the bag, in one write. Called both on the way out of a run and
## on the way out of the game, so quitting mid-run cannot cost the finds; `_banked` is what keeps
## the second call from repeating the first.
func _bank_farm_loot() -> void:
	if not _farming or _banked:
		return
	_banked = true
	# The gold as well as the finds, and the gold first: a run that turned up nothing but purses --
	# which most short ones do -- would otherwise be handed back nothing at all.
	if _fight_drops.is_empty() and _fight_gold == 0 and _fight_orbs.is_empty() and _fight_xp == 0:
		return
	inventory.gold += _fight_gold
	_fight_gold = 0
	# With the gold, above the finds, for the gold's reason.
	if inventory.add_xp(_fight_xp) > 0:
		print("Level up: %d" % inventory.level)
	_fight_xp = 0
	# Above the finds for the same reason the gold is: a run that turned up currency and no gear has
	# still earned its way, and nothing here can refuse either of them.
	for orb: String in _fight_orbs:
		inventory.add_orb(orb, int(_fight_orbs[orb]))
	_fight_orbs = {}
	for drop: Item in _fight_drops:
		_report_destroyed(inventory.add(drop))
	if _elite_dropped:
		inventory.first_elite_taken = true
	inventory.save(inventory_path)
	_refresh_bag()


## Both corner buttons at once. They come and go together because what takes them away is never
## about one of them -- a page standing on their edge, or a fight that must see every click.
func _show_corner(shown: bool) -> void:
	_bag_button.visible = shown
	_skills_button.visible = shown


## Every page that stands against the left edge. They share it, so opening one closes the rest and
## there is one place that knows which those are.
func _close_left_pages() -> void:
	_bag_panel.hide()
	_worn_panel.hide()
	_skills_panel.hide()
	_hide_skill_card()


## A page takes the corner's place while it is open, so that corner never holds both.
func _open_left_page(page: VBoxContainer) -> void:
	_close_left_pages()
	_layout_ui()
	page.show()
	_show_corner(false)
	# The page covers the left edge, and it stands on a layer above the character panel.
	_character.hide()


## The X on either page: the same two things follow from closing either one.
func _on_left_page_closed() -> void:
	_close_left_pages()
	_show_corner(true)
	_character.show()


func _on_skills_pressed() -> void:
	# Levels and gold both move while the page is shut, and both change what it says.
	_refresh_skills()
	_open_left_page(_skills_panel)


func _on_bag_pressed() -> void:
	# Always opens on the grid: a stat block left over from last time is not what was asked for.
	# Both selections, not just the bag's -- leaving the other set reopens the bag on a worn piece,
	# which is the very thing this reset exists to prevent.
	_bag_selected = -1
	_worn_selected = -1
	_refresh_bag()
	_open_left_page(_bag_panel)
	# The character sheet is the bag's other half rather than a page of its own, so it comes up with it.
	_worn_panel.show()


## Quitting with a run still on. The pouch goes in rather than evaporating -- a run that is left
## by closing the window found what it found -- and the map goes down as it stands.
func _exit_tree() -> void:
	_bank_farm_loot()
	_save_map()


## The bag's own X. Closing it is closing a left-hand page and nothing more, but it keeps its name:
## that is what the tests press, and "close the bag" is what the button means to whoever reads it.
func _on_bag_closed() -> void:
	_on_left_page_closed()


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	_panel.hide()
	map.deselect()
	_update_buttons()
