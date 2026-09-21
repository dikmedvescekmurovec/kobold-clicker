extends Node2D

## Seeds for the town world and the rendered map. 0 carries on with the save's, or picks a random one when
## there is no save; any other value replaces a save of another world. The used seeds are printed.
@export var world_seed := 0
@export var map_seed := 0
## World spot shown at the map's center cell (0, 0), which is the middle of the screen. The row must be even.
@export var map_origin := Vector2i(128, 128)
## Whole-number pixel zoom, so sprite pixels stay square: 3 draws every sprite pixel as 3x3 on screen.
@export var zoom := 3.0
## How far the mouse wheel takes the map's zoom either way, in the same whole steps.
const ZOOM_MIN := 1.0
const ZOOM_MAX := 6.0
## The same for the UI panel. Pixellari only renders cleanly at its native 16 px, so the way to make
## the interface smaller is to draw its pixels smaller, not to shrink the font.
@export var ui_scale := 2.0
## Where the inventory is kept. The tests and the screenshot scripts point this somewhere else
## before the scene enters the tree, so they never read or overwrite the player's own inventory.
@export var inventory_path := Inventory.SAVE_PATH
## Where the explored map is kept. Pointed elsewhere by the tests and the screenshot scripts for the
## reason `inventory_path` is -- and more sharply, since they all pin a seed, and a pinned seed that
## differs from a save is a request for another world that replaces it on the first write.
@export var map_path := MapSave.SAVE_PATH
## Dev: every settlement offers every counter (`TownServices.show_all`). Debug builds only, and only
## on the player's own save, so the tests and the screenshot scripts -- which all point
## `inventory_path` elsewhere -- still see what a town of each tier really has.
@export var debug_all_services := true

## The marks the corner buttons wear. The first three: a chest for what has been carried home, a star for what
## the player has become and a scroll for the work they have taken on: all three are places to go
## rather than actions to take, which is what the brown face says and what puts them in a row of their
## own rather than among the panels' green buttons.
const CHEST_ICON := "res://Assets/UI/ui_icon_chest.png"
const STAR_ICON := "res://Assets/UI/ui_icon_star.png"
const SCROLL_ICON := "res://Assets/UI/ui_icon_scroll.png"
## And a fourth that is about the game rather than the player: the settings, behind a cog.
const COG_ICON := "res://Assets/UI/ui_icon_cog.png"
const TROPHY_ICON := "res://Assets/UI/ui_icon_trophy.png"
## The heirlooms'. A stand-in from the pack until they have a mark of their own.
const CROWN_ICON := "res://Assets/UI/ui_icon_crown.png"
## The air between one and the next, in panel pixels.
const CORNER_GAP := 4.0
## The panel that stands in for the map when its save cannot be read: how wide it is allowed to be
## in panel pixels, and the air it keeps either side of it on a window too narrow for that.
const REFUSAL_WIDTH := 300.0
const REFUSAL_MARGIN := 32.0
## What a tile modifier's sentences wrap at on the tile panel, so a long one never widens the column.
const MOD_WIDTH := 130.0

## What the panel over an aimed spell says to do with the map behind it, by the spell's own name.
const AIM_LINES := {
	FortuneTeller.SCOUR: "Choose the land to uncover.",
	FortuneTeller.HOMECOMING: "Choose the settlement to stand in.",
}

var towns: TownWorld
var view: MapBuilder
## Everything the player has picked up, loaded from `inventory_path` and written back as it grows.
var inventory: Inventory

## The level-up fanfare: how bright the screen flashes, how long the words hang and how big they
## arrive before settling at LEVEL_UP_FONT, which is a whole multiple of Pixellari's 16.
const LEVEL_UP_FLASH := Color(1.0, 0.95, 0.75, 0.35)
const LEVEL_UP_TIME := 1.6
const LEVEL_UP_FONT := 48

## The banner a unique new to the collection log raises. It is up for `BANNER_HOLD` whatever the
## player does, then goes by the rule in `_on_banner_held`; `BANNER_GAP` is the air it keeps under the
## fight's own top-centre column, in screen pixels.
const BANNER_HOLD := 5.0
const BANNER_WIDTH := ItemCard.WIDTH * 1.5
const BANNER_FADE := 0.4
const BANNER_GAP := 12.0

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D

var _chart_button: Button
## Dev: charts the selected tile with no fight. Debug builds only.
var _skip_button: Button
var _move_button: Button
var _farm_button: Button
## Rest on the selected tile: the same ground as Farm, held by the weapon alone while the player is
## away. Greyed rather than hidden where nothing would swing (`_cannot_camp`).
var _camp_button: Button
var _town_button: Button
## What a town on the selected tile offers, listed under the land it stands on.
var _service_rows: VBoxContainer
## What the land does to its own fight (`TileMods`), one row a modifier, under the services.
var _mod_rows: VBoxContainer
## The settlement the player has walked into, on the right edge in the tile panel's place, and the
## cell it stands on -- kept because the map is still clickable behind the page, so the selection is
## not what the town is.
var town_page: TownPage
var _town_cell := HexMap.NO_CELL
## The tile the player is walking over to chart, NO_CELL when they aren't.
var _chart_target := HexMap.NO_CELL
var _env_rows: VBoxContainer
var _tile_title: Label
var _level_label: Label
var _panel: VBoxContainer
## The left-hand pages and the corner buttons that open them. They share the edge, so only one page is
## ever up: opening any of them closes the rest.
var bag_page: BagPage
## The heirlooms: a second bag page over `inventory.stash()`, with its own grid and its own doll. The
## one left-hand page that can also stand at a town's counter, in the bag's place (`_counter_page`).
var heirloom_page: BagPage
var skills_page: SkillsPage
## The bounties taken on, everywhere: a left-hand page like the rest, so progress and the walk to
## the monster are readable away from the town that posted the work.
var bounty_page: BountyList
## Sound, animations, what an item says, and Reset. A left-hand page like the rest, always on offer.
var settings_page: SettingsPage
var collection_page: CollectionPage
## What the player adds up to, opened by a press anywhere on the character panel.
var character_page: CharacterPage
## See-through, over the character panel, which takes no mouse itself because it stands over fights
## too. This one comes and goes with the corner buttons, so a fight never finds it there.
var _character_button: Button
var _bag_button: Button
var _skills_button: Button
var _bounty_button: Button
var _settings_button: Button
var _collection_button: Button
## There while an heirloom is held, and the one corner button a
## town leaves standing: pressed there it swaps the bag and the heirlooms at the counter.
var _heirloom_button: Button
## The card beside the square under the cursor. Kept so its Alt comparison can follow the doll of
## whichever bag page is up.
var _item_card: ItemCard
## The player in the top-left corner, over the map and over a fight alike.
var _character: CharacterPanel
## The banner over a unique the log has never held, while it is up; null otherwise. `_banner_head` is
## the row its heading sits in, which is where the X goes if one is ever needed.
var _unique_banner: Control
var _banner_head: HBoxContainer
## Whether a left press has landed since it went up, and whether it may now be put down by one.
var _banner_clicked := false
var _banner_closable := false

## What the fight going on now has earned, and whether it is banked yet. Never null: between fights
## it is the last fight's, or an empty one, so `ledger.farming` can always be asked.
var ledger: FightLedger
## The fight in front of the map, while there is one.
var _combat: CombatScene
## Whether the map on disk was refused, which stops every write to it. A refused save is never
## written over: overwriting is how a save gets eaten, and the build that wrote it can still read it.
var _save_blocked := false

## First-time pop-ups, in the order they are shown: id, title, what it says. Each is shown once for the
## player, after the fight that earned it, and the corner button it is about only appears with it.
const TIPS := [
	["first_item", "Spoils of Battle", "The fallen leave treasure behind! Open your bag with the chest in the top-left corner, then look over what you found and gear up for the fights ahead."],
	["first_orb", "A Spark of Power", "This orb hums with raw magic, and it can reshape your gear. Open a piece in your bag, and the orbs that answer its call glow. Pick one and see what happens."],
	["level_up", "Power Grows Within", "Battle has hardened you. A skill point awaits, so open the skills page with the star in the top-left corner and choose your path."],
	["first_farm", "The Endless Hunt", "The enemies here will never stop coming, but there is no clock to beat. Fight as long as you like and gather their spoils. When you have had your fill, raise the flag in the top-right corner to head home with everything you found."],
	["first_chart", "Claim the Land", "Foes stand between you and this land, and the clock at the top of the screen is ticking. Strike them all down before it runs out and the tile is yours. Fall short and nothing is lost, so catch your breath and try again."],
	["first_town", "Gates Stand Open", "People live here, and they will deal with a wanderer. Press Enter town on the panel at the right to step inside, where traders buy what you have gathered and sell what they have found. A board by the gate posts work for anyone willing to hunt, and a fortuneteller sells what she sees."],
	["first_unique", "A Legend Found", "This is no ordinary find. A unique piece bends the rules of a fight, so read what it does before you wear it. The trophy in the top-left corner keeps count of every one you have found. A fortuneteller can say what the rest are and where they hide."],
	["first_heirloom", "A Way Out", "The wall is down, and something of it has stayed with you. A fortuneteller can now show you the way out of this world. It costs everything you have here, and it is worth it."],
	["first_bounty", "Names on the Board", "The board names creatures the town wants gone. Press Accept on a notice and every such creature you strike down counts towards it, one notice at a time. The scroll in the top-left corner keeps it wherever you go, and the fortuneteller in town can say where that creature lives."],
]
const FLASH_BRIGHT := Color(1.6, 1.6, 1.6)
const FLASH_SECONDS := 0.5

var _ui_layer: CanvasLayer
## Set by the settings page's Reset, which wipes both saves: it keeps `_exit_tree` from writing them back.
var _resetting := false
## The black screen between two worlds, while the player is on it; null otherwise.
var _transcend_page: TranscendPage
## Tips earned but not shown yet, and the one that is up.
var _tip_queue: Array = []
var _tip_panel: VBoxContainer
## Pulses on corner buttons that have not been pressed yet: the pressed-once id -> its tween.
var _flashes := {}
## The camp the player is resting at, while its screen is up; null otherwise. Like a fight, it
## stands over the hidden map on layer 2 and takes the corner buttons away.
var _camp: CampScene
## The weather and the day over the map.
var _ambient: Ambient
## The badge pointing at the chest a fortuneteller was paid to find (`_sync_chest`).
var _chest_pointer: ChestPointer
## The fortuneteller's aimed spell while its land is being chosen: which one it is ("" when nobody is
## choosing), what the click will cost, the town whose drawer it is spent out of, and the panel saying
## what to do.
var _aiming := ""
var _aim_price := 0.0
var _aim_town := TownWorld.NO_SPOT
var _aim_panel: VBoxContainer


func _ready() -> void:
	# Two different nulls: no file at all is a first run, and a file that cannot be honoured stops.
	# Generating a world in its place would write over it on the player's first step, and a map lost
	# to a bad read is worse than an error message.
	# The inventory first, and by the same rule: it is what the player owns, and an empty bag saved over
	# a file that could not be read is that file gone on the first kill.
	TownServices.show_all = (debug_all_services and OS.is_debug_build()
			and inventory_path == Inventory.SAVE_PATH)
	# The player's own settings only beside the player's own save, for the same reason: a test or a
	# screenshot sees the defaults and writes nothing.
	Settings.path = Settings.SAVE_PATH if inventory_path == Inventory.SAVE_PATH else ""
	Settings.load_settings()
	Settings.apply_audio()
	var problem: Array = []
	inventory = Inventory.load_from(inventory_path, problem)
	if not problem.is_empty():
		_refuse_save("inventory", inventory_path, str(problem[0]))
		return
	ledger = FightLedger.new(inventory, inventory_path)
	var save := MapSave.load_from(map_path, problem, MapSave.fingerprint(map.tileset))
	if not problem.is_empty():
		_refuse_save("map", map_path, str(problem[0]))
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
	map.tile_clicked.connect(_on_tile_clicked)
	map.dragged.connect(_on_map_dragged)
	map.cell_aimed.connect(_on_cell_aimed)
	view.arrived.connect(_on_player_arrived)
	map.player.move_speed = func() -> float: return float(inventory.stats().get("move_speed", 0.0))
	# Before the interface, which is what decides whether the crown stands in the corner.
	_credit_walls()
	_build_ui()
	# A save from before there were heirlooms has just been paid for its walls: say what that means.
	if inventory.super_orbs > 0:
		_check_tips()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.ground_layer.map_to_local(view.player_cell)
	# A child of the map, so it hides and stops with it while a fight is on.
	_ambient = Ambient.new()
	map.add_child(_ambient)
	_ambient.setup(camera)
	_update_weather()
	_sync_chest()
	# The world is decided the moment it is generated, so it is written down then: a first run
	# killed before the player moves would otherwise come back as somewhere else entirely.
	_save_map()
	# Last, over everything the rest of start-up put up: a camp is somewhere the player *is*, so a
	# game closed at one comes back to it, and the hours it was shut for are the hours it paid for.
	if not inventory.camp.is_empty():
		_open_camp()


## Points the badge at the chest a fortuneteller was paid to find, for as long as it stands: a chest
## goes when its tile is charted, and the badge and what was written down go with it. Nothing points
## at a chest for nothing any more.
func _sync_chest() -> void:
	var spot := FortuneTeller.chest(inventory.fortunes)
	var cell := spot - view.origin if spot != TownWorld.NO_SPOT else HexMap.NO_CELL
	if cell != HexMap.NO_CELL and not view.has_chest(cell):
		inventory.fortunes.erase(FortuneTeller.CHEST)
		inventory.save(inventory_path)
		cell = HexMap.NO_CELL
	_chest_pointer.target = cell
	# Dev: a fallen wall adds hidden land, whose chests only a full pass draws.
	if Settings.show_all_chests():
		view.redraw_chests()


## Writes the map as it stands. A refused save is never written over -- that is the whole point of
## refusing, and `_save_blocked` is what carries it to every write path.
func _save_map() -> void:
	if _save_blocked or view == null:
		return
	view.to_save().save(map_path)


## A save that cannot be honoured, `what` being "map" or "inventory". Nothing is generated and nothing
## is written -- no UI is built, so nothing can reach either save; the player is told what happened
## and where the file is, because a console error is not something they can act on and a blank window
## is worse.
func _refuse_save(what: String, path: String, reason: String) -> void:
	_save_blocked = true
	push_error("Refusing to load the saved %s %s -- %s" % [what, path, reason])
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	# The X quits: there is no map behind this to close it onto.
	var panel := UITheme.titled_panel("Saved %s" % what, "Quit", get_tree().quit)
	panel.scale = Vector2(ui_scale, ui_scale)
	layer.add_child(panel)
	# Fixed width and wrapped, because the one line that matters is a file path: it has no length
	# worth guessing at, and left to size itself the panel runs off both edges of the window and
	# takes its own close button with it. Arbitrary wrapping, since a path need not break on spaces.
	var rows := UITheme.body_of(panel)
	var width := minf(get_viewport().get_visible_rect().size.x / ui_scale - REFUSAL_MARGIN, REFUSAL_WIDTH)
	for line in ["The saved %s could not be loaded:" % what, reason + ".",
			"", "It has been left exactly as it is, at", ProjectSettings.globalize_path(path),
			"", "Move that file aside to start over without it."]:
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
## where the player drags it. The play clock is wound on here: every frame the game is open counts.
func _process(delta: float) -> void:
	inventory.play_seconds += delta
	if view != null and view.walking:
		camera.position = _clamp_to_map(map.player.position)


## Built in code so the scene file stays untouched while the Godot editor has it open.
## The side panel is laid out in sprite pixels and scaled by `ui_scale`. It stays hidden until a
## tile is selected, and _layout_ui keeps it flush against the right edge, running the full height
## of the window, whenever that window resizes.
func _build_ui() -> void:
	# Before the first button exists: it hands each one the pointing hand as it joins the tree.
	Cursors.install(get_tree(), int(ui_scale))
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_ui_layer = layer
	_chest_pointer = ChestPointer.new(map, view, ui_scale)
	layer.add_child(_chest_pointer)

	_panel = UITheme.titled_panel("Tile", "Close and deselect the tile", _on_close_pressed)
	_panel.scale = Vector2(ui_scale, ui_scale)
	_panel.hide()
	layer.add_child(_panel)
	_tile_title = UITheme.title_of(_panel)
	var rows := UITheme.body_of(_panel)

	# How far out this tile is, which is both how hard it fights and the ceiling on what drops here.
	_level_label = Label.new()
	_level_label.theme_type_variation = "PanelLabel"
	rows.add_child(_level_label)

	_env_rows = VBoxContainer.new()
	_env_rows.add_theme_constant_override("separation", 4)
	_env_rows.custom_minimum_size = Vector2(HexTileset.ENV_ICON + 46, 0)
	rows.add_child(_env_rows)

	# What a settlement on the tile offers, under the land it is built on: the tile says what is there
	# before the player has walked to it, so the walk can be worth taking for a fortress's smith.
	_service_rows = VBoxContainer.new()
	_service_rows.add_theme_constant_override("separation", 4)
	rows.add_child(_service_rows)
	_mod_rows = UITheme.vbox(2)
	rows.add_child(_mod_rows)

	# Only the buttons that can be pressed are shown (`_update_buttons`), at the column's foot.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	rows.add_child(buttons)
	_chart_button = UITheme.button("Chart", "LightButton", "Fight for this tile and what lies behind it")
	_chart_button.pressed.connect(_on_chart_pressed)
	Cursors.wear(_chart_button, Cursors.SWORD)
	buttons.add_child(_chart_button)
	_skip_button = UITheme.button("Skip fight", "LightButton", "Dev: chart this tile without fighting for it")
	_skip_button.pressed.connect(func() -> void:
		print("Dev: charted %s, showing %d tile(s) behind it" % [map.selected_cell,
				view.chart(map.selected_cell, _sight())])
		_credit_walls()
		_check_tips()
		_update_buttons())
	buttons.add_child(_skip_button)
	_move_button =UITheme.button("Move here", "LightButton", "Walk to the selected tile")
	_move_button.pressed.connect(_on_move_pressed)
	Cursors.wear(_move_button, Cursors.BOOT)
	buttons.add_child(_move_button)
	# And a third thing to do with a tile you have already taken: stand on it and fight until you
	# have had enough. Nothing is won by it but what the bodies were carrying.
	_farm_button = UITheme.button("Farm", "LightButton", "Fight here for as long as you like, for the loot")
	_farm_button.pressed.connect(_on_farm_pressed)
	Cursors.wear(_farm_button, Cursors.SWORD)
	buttons.add_child(_farm_button)
	# And the same tile left to hold itself: the hours the game is shut are the hours the hero
	# spends here, and what they drive off pays in coin and experience alone.
	_camp_button = UITheme.button("Set up camp", "LightButton", CAMP_TIP)
	_camp_button.pressed.connect(_on_camp_pressed)
	Cursors.wear(_camp_button, Cursors.BOOT)
	buttons.add_child(_camp_button)
	# And a fourth, on the tiles people live on: go inside and trade. It takes standing on the tile
	# rather than looking at it, because visiting a town is being there.
	_town_button = UITheme.button("Enter town", "LightButton", "Go inside and see what is traded here")
	_town_button.pressed.connect(_on_town_pressed)
	buttons.add_child(_town_button)

	_build_character()
	_build_pages(layer)

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui.call_deferred()
	# A new player has nothing for either corner button to open yet.
	_show_corner(true)


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
	var shown := PlayerLevel.add(inventory.level, inventory.xp, ledger.pending_xp())
	_character.set_state(shown["level"], shown["xp"])


## The left-hand pages and the square buttons that open them. The pages are built before the first
## `_layout_ui`, which places all of them.
func _build_pages(layer: CanvasLayer) -> void:
	_skills_button = UITheme.icon_button(load(STAR_ICON), "What the player has become", ui_scale)
	_skills_button.pressed.connect(_on_skills_pressed)
	layer.add_child(_skills_button)
	_bag_button = UITheme.icon_button(load(CHEST_ICON), "What the monsters have dropped", ui_scale)
	_bag_button.pressed.connect(_on_bag_pressed)
	layer.add_child(_bag_button)
	_bounty_button = UITheme.icon_button(load(SCROLL_ICON), "The work you have taken on", ui_scale)
	_bounty_button.pressed.connect(_on_bounty_pressed)
	layer.add_child(_bounty_button)
	_settings_button = UITheme.icon_button(load(COG_ICON), "Settings", ui_scale)
	_settings_button.pressed.connect(_on_settings_pressed)
	layer.add_child(_settings_button)
	_collection_button = UITheme.icon_button(load(TROPHY_ICON), "The uniques you have found", ui_scale)
	_collection_button.pressed.connect(_on_collection_pressed)
	layer.add_child(_collection_button)
	_heirloom_button = UITheme.icon_button(load(CROWN_ICON), "What you would take to another world", ui_scale)
	_heirloom_button.pressed.connect(_on_heirlooms_pressed)
	layer.add_child(_heirloom_button)
	_character_button = Button.new()
	_character_button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_character_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_character_button.tooltip_text = "Your character"
	_character_button.pressed.connect(_on_character_pressed)
	layer.add_child(_character_button)
	character_page = CharacterPage.new(inventory, ui_scale)
	collection_page = CollectionPage.new(inventory, view, ui_scale)
	skills_page = SkillsPage.new(inventory, inventory_path, ui_scale)
	bag_page = BagPage.new(inventory, inventory_path, ui_scale)
	heirloom_page = BagPage.new(inventory, inventory_path, ui_scale, true)
	bounty_page = BountyList.new(inventory, view, inventory_path, ui_scale)
	bounty_page.show_cell.connect(_on_show_cell)
	settings_page = SettingsPage.new(ui_scale)
	settings_page.inventory = inventory
	settings_page.inventory_path = inventory_path
	settings_page.reset_pressed.connect(_on_reset_pressed)
	settings_page.uniques_toggled.connect(_show_corner.bind(true))
	settings_page.chests_toggled.connect(view.redraw_chests)
	# Dev only: an empty purse becomes 10, so the button always does something.
	settings_page.cash_pressed.connect(func() -> void:
		inventory.gold = maxf(inventory.gold, 1.0) * 10.0
		inventory.save(inventory_path))
	# The town page stands on the other edge, but it is closed by the same X rule and hidden by the
	# same fight, so it is built and wired here with the two that share the left one.
	town_page = TownPage.new(inventory, inventory_path, ui_scale)
	town_page.view = view
	town_page.tab_changed.connect(_on_town_tab_changed)
	town_page.chest_bought.connect(func(_cell: Vector2i) -> void: _sync_chest())
	town_page.spell_aimed.connect(_on_spell_aimed)
	town_page.transcend_pressed.connect(_on_transcend_pressed)
	# A bounty given up on the journal frees the board standing open on the other edge.
	bounty_page.abandoned.connect(town_page.redraw)
	# What the counter has open goes straight to the bag: the comparison points at what wearing it
	# would replace, and a purchase reaches the purse and the grid by the same redraw. Back the other
	# way, the counter redraws around whatever the bag has open, so a piece sold to make room unlocks
	# the Buy that was greyed out for a full bag.
	# An orb in the bag's hand works on a shelf piece too; the bag still does the spending and saving.
	# Both bag pages are wired alike, and only the one that is up ever speaks: a hidden page has nothing
	# open and no orb in hand, and standing it at the counter (`shop`) forgets any offer it overheard.
	# `craft_held` goes through `_counter_page`, which is whichever of them that is.
	town_page.craft_held = func(item: Item, written: Callable) -> void:
		_counter_page().craft_held(item, written)
	for page: BagPage in [bag_page, heirloom_page]:
		town_page.offer_changed.connect(page.offer)
		page.selection_changed.connect(town_page.bag_changed)
		page.held_changed.connect(town_page.orb_held)
		page.laid_out.connect(_place_corner)
	settings_page.laid_out.connect(_place_corner)
	for page: Control in [skills_page, bag_page, heirloom_page, bounty_page, settings_page,
			collection_page, character_page, town_page]:
		page.hide()
		page.closed.connect(_on_left_page_closed)
		layer.add_child(page)
	# On the character's layer, over the pages and over a fight (layer 2), so a find in the loot
	# popup or under the verdict gets its card too. It takes no mouse, so it costs no swings.
	_item_card = ItemCard.new(ui_scale)
	_item_card.equipment = inventory.equipment
	_character.get_parent().add_child(_item_card)
	# A held orb changes a piece without opening it, and the card is the only place the result is read.
	bag_page.crafted.connect(_item_card.unmute)
	heirloom_page.crafted.connect(_item_card.unmute)
	# Every `tooltip_text` there is, on the same cream card and the same layer.
	_character.get_parent().add_child(TipCard.new(ui_scale))


## The weather for wherever the player now stands.
func _update_weather() -> void:
	var ground := map.ground_layer.get_cell_tile_data(view.player_cell)
	_ambient.set_env(ground.get_custom_data("env") if ground != null else "")


## A level gained: the screen flashes warm, the words pop up over the middle and float away. On the
## character panel's layer, so it stands over a fight as well as the map.
func _celebrate_level(level: int) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	var layer := _character.get_parent()
	var flash := ColorRect.new()
	flash.color = LEVEL_UP_FLASH
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var label := Label.new()
	label.theme = UITheme.theme()
	label.theme_type_variation = "PanelLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "Level %d!" % level
	label.add_theme_font_size_override("font_size", LEVEL_UP_FONT)
	label.add_theme_color_override("font_color", Palette.GOLD)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	layer.add_child(label)
	var view_size := get_viewport_rect().size
	var text := label.get_combined_minimum_size()
	label.pivot_offset = text / 2.0
	label.position = (view_size - text) / 2.0 - Vector2(0, view_size.y * 0.15)
	label.scale = Vector2.ONE * 3.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	tween.tween_property(label, "scale", Vector2.ONE * 2.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 30.0, LEVEL_UP_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(LEVEL_UP_TIME - 0.4)
	tween.chain().tween_callback(flash.queue_free)
	tween.tween_callback(label.queue_free)


## Whether this find fills a slot in the collection log: a unique, never logged, and not one this same
## fight has already turned up. The bag cannot answer alone -- a run pouches its finds, so nothing has
## reached `uniques_found` yet and a second copy would raise a second banner.
func _is_new_unique(item: Item) -> bool:
	if item.unique.is_empty() or inventory.uniques_found.has(item.unique):
		return false
	return not ledger.drops.any(func(drop: Item) -> bool: return drop.unique == item.unique)


## A unique the log has never held, announced under the fight's own column: the piece as a square and
## the whole of what it does, on the cards' cream, on the character's layer so it stands over the fight.
##
## It writes the name, the rarity line and the piece's own rule, and **none of its numbers**: the
## tables are what a bag is for, and a banner read mid-fight has to be read in a glance. The square is
## an `ItemSlot`, so the gold frame and its glint come for nothing. What that costs is one line -- the
## square has to leave `ItemSlot.GROUP` at once, or the one `ItemCard` finds it under the cursor and
## stands its own card over this one.
func _announce_unique(item: Item) -> void:
	_close_unique_banner()
	var layer := _character.get_parent()
	if Settings.animations == Settings.Anim.DEFAULT:
		# Added before the panel, so it washes the fight behind it and not the words.
		var flash := ColorRect.new()
		flash.color = LEVEL_UP_FLASH
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(flash)
		var wash := create_tween()
		wash.tween_property(flash, "modulate:a", 0.0, 0.5)
		wash.tween_callback(flash.queue_free)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme()
	panel.theme_type_variation = "TextPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.scale = Vector2(ui_scale, ui_scale)
	var body := UITheme.vbox(4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	_banner_head = HBoxContainer.new()
	_banner_head.add_theme_constant_override("separation", 6)
	_banner_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_banner_head)
	# The unique's own name colour, which is the half of the ramp picked to be read on cream.
	var heading := UITheme.label("Unique Found", item.text_color())
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_head.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(row)
	var slot := ItemSlot.make(item)
	slot.remove_from_group(ItemSlot.GROUP)
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(slot)
	# What the piece *is* and the rule it bends, and none of its numbers: a banner is read in a glance
	# in the middle of a fight, and the stat and modifier tables are what made it a wall of text. They
	# are two presses away in the bag, and the rule is the thing that cannot be guessed from the icon.
	var rows := UITheme.vbox(2, BANNER_WIDTH)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rows)
	rows.add_child(ItemDetails.line(item.display_name(), item.text_color(), BANNER_WIDTH))
	rows.add_child(ItemDetails.line("%s · level %d" % [item.rarity_name(), item.level],
			item.text_color(), BANNER_WIDTH, true))
	rows.add_child(ItemDetails.line(item.effect_text(), Palette.SLOT_TAN_DK, BANNER_WIDTH, true))
	if item.is_set():
		rows.add_child(ItemDetails.line(item.set_text(), ItemRarity.SET_TEXT, BANNER_WIDTH, true))
	layer.add_child(panel)
	_unique_banner = panel
	_banner_clicked = false
	_banner_closable = false
	# Placed now, again once the labels have laid out -- with the sparks thrown from where it actually
	# landed -- and again whenever it settles at another size, which is what the X at five seconds does.
	panel.resized.connect(_place_unique_banner)
	_place_unique_banner()
	_place_unique_banner.call_deferred(Settings.animations == Settings.Anim.DEFAULT)
	if Settings.animations != Settings.Anim.NONE:
		panel.scale = Vector2(ui_scale, ui_scale) * 1.4
		var spring := create_tween()
		spring.tween_property(panel, "scale", Vector2(ui_scale, ui_scale), 0.25).set_trans(
				Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A beat of slow motion, as an elite find already gets: this is the rarer thing of the two.
	Juice.hit_stop(get_tree(), 0.12, 0.25)
	get_tree().create_timer(BANNER_HOLD).timeout.connect(_on_banner_held.bind(panel))


## Centred under the fight's top column, which is the one thing it must not cover. Run again whenever
## the panel settles at another size (`resized`), so nothing here depends on the labels having laid
## out. `spark` throws the puff of gold, and is only ever passed by the deferred first placement, so
## it cannot be thrown twice.
func _place_unique_banner(spark := false) -> void:
	if _unique_banner == null:
		return
	var view_size := get_viewport_rect().size
	var top: float = (_combat.hud_bottom() if _combat != null else CombatScene.HUD_MARGIN) + BANNER_GAP
	_unique_banner.size = _unique_banner.get_combined_minimum_size()
	var side := _unique_banner.size * ui_scale
	# It springs in about its middle, so that is where the pivot goes -- and a Control is scaled about
	# its pivot, which draws its corner `pivot * (scale - 1)` back from wherever `position` puts it.
	# `corner` is where it actually lands; `position` is what has to be set to land it there.
	_unique_banner.pivot_offset = _unique_banner.size / 2.0
	var corner := Vector2((view_size.x - side.x) / 2.0, top)
	_unique_banner.position = corner + _unique_banner.pivot_offset * (ui_scale - 1.0)
	if spark:
		Juice.burst(_unique_banner.get_parent(), corner + side / 2.0,
				Palette.GOLD, 28, 220.0, 3.0, 0.7)


## The five seconds are up. Someone who was swinging through them has read it or does not care, so it
## goes; someone who stopped to read gets an X, and from then on the next swing puts it down as well.
func _on_banner_held(panel: Control) -> void:
	if _unique_banner != panel:
		return
	if _banner_clicked:
		_close_unique_banner()
		return
	_banner_closable = true
	var shut := UITheme.button("", "CloseButton", "Close")
	shut.custom_minimum_size = Vector2(UITheme.icon_size("CloseButton"))
	shut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shut.pressed.connect(_close_unique_banner)
	# The X widens the heading; `resized` is what centres the panel again on its new size.
	_banner_head.add_child(shut)


## Puts it down, from the timer, the X, a swing past the five seconds, a second unique, or the fight
## ending -- so it is never left standing over a verdict.
func _close_unique_banner() -> void:
	if _unique_banner == null:
		return
	var panel := _unique_banner
	_unique_banner = null
	_banner_head = null
	_banner_clicked = false
	_banner_closable = false
	if Settings.animations == Settings.Anim.NONE:
		panel.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, BANNER_FADE)
	tween.tween_callback(panel.queue_free)


## One row per environment on the tile: a swatch of that terrain, then its share of the tile.
func _show_environments(weights: Dictionary) -> void:
	for child: Node in _env_rows.get_children():
		child.queue_free()
	var envs := weights.keys()
	envs.sort_custom(func(a: String, b: String) -> bool: return weights[a] > weights[b])
	for env: String in envs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(map.tileset.env_icon(env))
		var percent := Label.new()
		percent.theme_type_variation = "PanelLabel"
		percent.text = "%d%%" % round(weights[env] * 100.0)
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(percent)
		_env_rows.add_child(row)


## What the settlement on a tile trades in, one mark per counter, and nothing at all where there is no
## settlement. Shown for any town tile the player can see rather than only the ones they have taken:
## which town has a blacksmith is exactly the sort of thing that decides where to walk next.
func _show_services(cell: Vector2i) -> void:
	UITheme.clear(_service_rows)
	# Nothing about a tile still under the fog, which one taken blind is when it is clicked.
	var tier := view.town_tier(cell) if view.seen(cell) else -1
	if tier == -1:
		return
	_service_rows.add_child(UITheme.rule())
	var services := Accordion.new("Services", "tile:services", 4)
	_service_rows.add_child(services)
	# The marks the town page's tabs wear, so a counter looks the same from the road as from inside;
	# the name is the tooltip, as it is on the tab.
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	for service: String in TownServices.services_for(tier, view.origin + cell, towns.seed_value):
		# On the tab's brown face too: the marks are cut pale for it and wash out on the cream panel.
		var face := PanelContainer.new()
		face.add_theme_stylebox_override("panel", UITheme.theme().get_stylebox("normal", "BrownIconButton"))
		face.tooltip_text = TownServices.label(service)
		var icon := TextureRect.new()
		icon.texture = load(TownPage.TAB_ICONS[service])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(icon)
		icons.add_child(face)
	services.body.add_child(icons)


## What the land on a tile does to the fight for it: each modifier's name, then what it does and what
## it pays written out under it, never hidden in a tooltip -- they are what the tile is chosen on.
## Only for a tile the player can see: what lies under the fog is for charting to find out.
func _show_mods(cell: Vector2i) -> void:
	UITheme.clear(_mod_rows)
	var mods: Array = _mods_of(cell) if view.seen(cell) else []
	if mods.is_empty():
		return
	_mod_rows.add_child(UITheme.rule())
	var section := Accordion.new("Modifiers", "tile:modifiers")
	_mod_rows.add_child(section)
	for id: String in mods:
		var mod: Dictionary = TileMods.MODS[id]
		section.body.add_child(UITheme.label(str(mod["name"]), Palette.INK))
		section.body.add_child(ItemDetails.line(str(mod["text"]), Palette.INK, MOD_WIDTH, true))
		if not str(mod["reward"]).is_empty():
			section.body.add_child(ItemDetails.line(str(mod["reward"]), Palette.LEAF, MOD_WIDTH, true))


## The tile panel is a full-height column against the right edge, its buttons at its foot. The
## left-hand pages lay themselves out against the other edge.
func _layout_ui() -> void:
	_place_panel()
	bag_page.layout()
	heirloom_page.layout()
	skills_page.layout()
	bounty_page.layout()
	settings_page.layout()
	collection_page.layout()
	character_page.layout()
	town_page.layout()
	_character_button.position = _character.position
	_character_button.size = _character.size * ui_scale
	_place_corner()
	if _combat != null:
		_combat.xp_target = _character.xp_point()


func _on_tile_clicked(cell: Vector2i, info: Dictionary) -> void:
	_update_buttons()
	# The map is still clickable behind an open town page, which has this edge until the player leaves
	# it -- and `_close_town` is what brings the panel back, already filled in for whatever was clicked.
	_panel.visible = _town_cell == HexMap.NO_CELL
	_layout_ui()
	var spot := map_origin + cell
	# The ice hides whatever land is under it, so it has no rows of its own.
	# A tile under the fog that can be taken blind has nothing drawn, so no `info` and no rows either.
	var weights: Dictionary = info.get("environments", {}) if view.is_land(cell) else {}
	var parts := PackedStringArray()
	for env: String in weights:
		parts.append("%s %.1f%%" % [env, weights[env] * 100])
	var line := "Clicked %s (world %s): %s | %s" % [cell, spot, info.get("name", "fog"), ", ".join(parts)]
	if towns.has_town(spot):
		line += " | town connected to %s" % [towns.connections(spot)]
	print(line)
	# Not named either: a tile is named as it comes out of the fog, and asking would name it now.
	var tile_name := view.name_of(cell) if view.seen(cell) else "Unknown land"
	_tile_title.text = tile_name if tile_name != "" else "Tile"
	_level_label.text = "Level %d" % view.level_of(cell)
	_show_environments(weights)
	_show_services(cell)
	_show_mods(cell)
	# The rows are filled after _layout_ui ran, and the level line can be wider than the environment
	# rows that pin the panel's width, so the panel is measured again now that it holds everything.
	_layout_ui()


## Dragging moves the camera the other way, so the map follows the cursor.
func _on_map_dragged(relative: Vector2) -> void:
	camera.position = _clamp_to_map(camera.position - relative / camera.zoom.x)


## The wheel: one whole step of zoom, about the point under the cursor so it stays put on screen.
func _zoom_at(screen_point: Vector2, step: float) -> void:
	var to := clampf(camera.zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	if to == camera.zoom.x:
		return
	var from_middle := screen_point - get_viewport().get_visible_rect().size / 2.0
	var under := camera.position + from_middle / camera.zoom.x
	camera.zoom = Vector2(to, to)
	camera.position = _clamp_to_map(under - from_middle / to)


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
	# Asked of the builder and not of what is drawn: a tile taken blind has nothing drawn on it yet.
	var env := view.env_at(cell)
	var variant := view.area_variant(cell)
	print("Fighting for %s, %s (%s, %s %d)" % [view.name_of(cell), cell, env, variant,
			CombatScene.layout_for(cell)])
	if view.is_wall(cell):
		print("The ice wall stands on %s" % cell)
		_open_fight(Encounter.for_wall(cell), cell, false)
		return
	var chest := view.has_chest(cell)
	if chest:
		print("A treasure chest waits on %s" % cell)
	_open_fight(Encounter.for_tile(cell, env, variant, chest, _mods_of(cell)), cell, false)


## Farming the selected tile: the same arena and the same enemies, coming forever, with no clock
## and nothing riding on it. It takes a tile already taken, so nothing about the map can change.
func _on_farm_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_farm(cell):
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	var variant := view.area_variant(cell)
	print("Farming %s, %s (%s, %s)" % [view.name_of(cell), cell, env, variant])
	_open_fight(Encounter.farm(cell, env, variant, _mods_of(cell)), cell, true)


## What the Set up camp button says while it can be pressed.
const CAMP_TIP := "Rest here, and let the hero hold the tile while you are away"


## Why the hero cannot hold a camp, or "" where they can. A camp is fought by the weapon alone --
## nobody is there to click -- so a weapon that does not swing itself would rest all night for
## nothing. That is worth saying on the button rather than finding out in the morning. The two
## conditions are `Camp.hunts`', asked of what is worn rather than of a fight nobody has built yet.
func _cannot_camp() -> String:
	if Curses.NO_REST in inventory.curses:
		return "This world is under No Rest: no camp can be set up in it."
	if float(inventory.stats().get("attack_speed", 0.0)) <= 0.0:
		return "Your weapon does not swing on its own, and a camp is held by the weapon alone."
	if "berserk" in inventory.effects():
		return "The Berserker's Band never lets the weapon swing on its own, so nothing would hold this camp."
	return ""


## Camping the selected tile: the farm run nobody clicks. What it pays an hour is worked out here,
## once, from the gear the hero stands up in -- and then it is arithmetic (`Camp`), so the hours the
## game is shut pay exactly what the hours it is open would have.
func _on_camp_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_farm(cell) or not _cannot_camp().is_empty():
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	# Armed exactly as `_open_fight` arms one, and for the same reason: a camp is that fight. What it
	# is never given is the things a camp does not pay -- no first sword, no orbs, no uniques.
	var fight := Encounter.farm(cell, env, view.area_variant(cell), _mods_of(cell))
	fight.wear(inventory.effects())
	fight.arm(inventory.stats())
	inventory.camp = Camp.make(cell, view.name_of(cell), fight, Time.get_unix_time_from_system())
	inventory.save(inventory_path)
	print("Camped on %s, %s: %s gold, %d experience and %d bodies an hour"
			% [view.name_of(cell), cell, BigNumber.format(float(inventory.camp[Camp.GOLD]) * 3600.0),
				int(float(inventory.camp[Camp.XP]) * 3600.0),
				int(float(inventory.camp[Camp.KILLS]) * 3600.0)])
	_open_camp()


## Puts the camp on the screen, the way `_open_fight` puts a fight there: the map away behind it,
## every page and corner button gone, nothing in the top-left to take a press. It is opened both by
## the button and by start-up, so coming back to a camp and making one look the same.
func _open_camp() -> void:
	var cell := Camp.cell_of(inventory.camp)
	_camp = CampScene.new()
	_camp.broke_camp.connect(_break_camp)
	add_child(_camp)
	_camp.begin(inventory.camp, str(map.get_tile_info(cell).get("env", "")),
			view.area_variant(cell), ui_scale)
	map.hide()
	map.process_mode = Node.PROCESS_MODE_DISABLED
	_close_town()
	_panel.hide()
	_close_left_pages()
	_show_corner(false)
	_character.show()


## Breaking camp: what the rest earned goes in, the camp is struck, and the map comes back exactly
## as it was left. The purse and the experience are read from `Camp.earned` -- the same sum the
## screen has been showing all along -- so what was watched and what is paid cannot differ.
func _break_camp() -> void:
	var earned := Camp.earned(inventory.camp, Time.get_unix_time_from_system())
	inventory.camp = {}
	inventory.gold += float(earned[Camp.GOLD])
	var levels := inventory.add_xp(int(earned[Camp.XP]))
	inventory.save(inventory_path)
	print("Broke camp after %s: %s gold, %d experience, %d driven off"
			% [Camp.spell_time(float(earned["seconds"])), BigNumber.format(float(earned[Camp.GOLD])),
				int(earned[Camp.XP]), int(earned[Camp.KILLS])])
	_camp.queue_free()
	_camp = null
	Input.set_default_cursor_shape(Cursors.ARROW)
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	_show_corner(true)
	# It was placed against the fight's HUD, which has just gone, and the verdict stands where it does.
	_close_unique_banner()
	_sync_character()
	bag_page.refresh_gold()
	if levels > 0:
		_celebrate_level(inventory.level)
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()


## Puts a fight on the screen, whichever kind it is. Both kinds are opened exactly alike -- armed
## from what is worn, drawn on the tile's own backdrop, with the map and every Control out of the
## way -- so the one that comes later cannot quietly differ from the one that came first.
func _open_fight(fight: Encounter, cell: Vector2i, farming: bool) -> void:
	# What the player is wearing, read once as the fight opens. Changing gear mid-fight is not a
	# thing that can happen -- the bag goes away while one is on -- so there is nothing to keep live.
	# What is worn and learned first: `arm` reads some of it, and two home pieces reshape the lineup.
	fight.wear(inventory.effects())
	fight.arm(inventory.stats())
	# Until the Broken Sword has dropped, the first piece of gear is it, and an elite is promised it.
	fight.first_sword = not inventory.first_sword_taken
	fight.guarantee_elite = fight.first_sword
	fight.orbs_after = maxi(0, OrbTable.FIRST_ORB_KILLS - inventory.kills)
	fight.uniques_after = maxi(0, UniqueTable.FIRST_UNIQUE_KILLS - inventory.kills)
	fight.strikes = true
	ledger = FightLedger.new(inventory, inventory_path, farming)
	ledger.tile_level = view.level_of(cell)
	# Straight off the fight rather than through the scene: what a body was is the fight's business,
	# and the boards want the monster's name, not a drop. The ledger decides when it reaches them.
	fight.enemy_died.connect(_on_enemy_died)
	_combat = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	_combat.finished.connect(_on_combat_finished.bind(cell))
	_combat.retry.connect(_on_combat_retry.bind(cell))
	# Not `Encounter.loot_dropped`: the fight applies the player's autodiscard rule, and everything
	# downstream believes the fight. A second listener applying the rule a second way is how the
	# counter, the pouch and the bag would come to disagree about what a run found.
	_combat.autodiscard = inventory.autodiscards
	_combat.loot_kept.connect(_on_loot_dropped)
	_combat.loot_discarded.connect(_on_loot_autodiscarded)
	_combat.drop_discarded.connect(_on_drop_discarded)
	_combat.gold_gained.connect(_on_gold_gained)
	_combat.orb_gained.connect(_on_orb_gained)
	_combat.xp_gained.connect(ledger.add_xp)
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
	# Before the panel is hidden: leaving a town brings the tile panel back, which a fight then takes away.
	_close_town()
	_panel.hide()
	# The buttons have to go, not just be covered: a Control takes the mouse before the fight sees
	# it, so one left in that corner would quietly eat the player's swings.
	_close_left_pages()
	_show_corner(false)
	_character.show()
	# The tips about the fight itself come as it opens rather than after it, when they are needed.
	_check_tips()


## Back from the fight. The tile is charted only if it was won; either way the map comes back
## exactly as it was left.
func _on_combat_finished(won: bool, cell: Vector2i) -> void:
	var kills: int = _combat.fight.kills()
	# Read before the fight is freed, and before banking, which zeroes the run's own pouch.
	var earned: float = _combat.fight.gold
	_bank_run()
	ledger.bank_kills(kills)
	_combat.queue_free()
	_combat = null
	# Gems still in the air when the fight closed never arrive, so the panel is put back on the ledger.
	_sync_character()
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	_show_corner(true)
	var turned_up := PackedStringArray()
	for drop in ledger.drops:
		turned_up.append("%s (%s)" % [drop.type, drop.rarity_name()])
	print("The fight turned up: %s, and %s gold"
			% ["nothing" if turned_up.is_empty() else ", ".join(turned_up),
				BigNumber.format(earned)])
	if ledger.farming:
		# Nothing about the map moves for a run. The tile was already taken; the loot is the whole of it.
		print("Farmed %s, %d slain" % [cell, kills])
	elif won:
		print("Charted %s, showing %d tile(s) behind it; walking there" % [cell, view.chart(cell, _sight())])
		_credit_walls()
	else:
		print("Lost the fight for %s; it stays uncharted" % cell)
	ledger.farming = false
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()
	# After banking, so a run's pouch counts; after the fight, so a pop-up never covers one.
	_check_tips()


## Every wall down in this world that has not yet paid its super orb pays it, and the save says
## so. Asked wherever a wall can have fallen -- a tile charted -- and once at start-up, which is what
## pays a save from before there were heirlooms for the walls it already has down.
func _credit_walls() -> void:
	if inventory.credit_walls(view.walls_fallen()):
		print("A wall is down: %d super orb(s) to spend at a transcension" % inventory.super_orbs)
		inventory.save(inventory_path)


## How far the player sees from a tile they have just taken: their own ring behind it, plus whatever a
## torch adds. It is read here and nowhere else -- at the moment the tile is charted -- so a torch put
## on afterwards uncovers nothing and one taken off hides nothing. What a tile showed is what it showed.
func _sight() -> int:
	# Under the Thick Fog the player's own ring is gone, and a torch is what buys it back. None at all
	# is a chart that uncovers the tile taken and nothing round it (`MapBuilder.chart`).
	return (0 if Curses.THICK_FOG in inventory.curses else 1) + int(inventory.stats().get("sight", 0))


## What the land on `cell` does to its own fight, under this world's curses.
func _mods_of(cell: Vector2i) -> Array[String]:
	return view.mods_of(cell, Curses.WILD_TILES in inventory.curses)


## Retry under a lost verdict. Out through the one door every fight leaves by, so what it earned is
## banked and its kills counted, and back in through Chart, so the second go is opened like the first.
func _on_combat_retry(cell: Vector2i) -> void:
	_on_combat_finished(false, cell)
	map.select_cell(cell)
	_on_chart_pressed()


## The player walks to the tile; the tile panel's buttons stay hidden until they get there.
func _on_move_pressed() -> void:
	var cell := map.selected_cell
	print("Walking to %s, %d tile(s) away" % [cell, view.move_to(cell).size()])
	_update_buttons()


## Where the map's own state has changed: charting a tile walks the player onto it (and a paid scour
## is the one other change, `_on_cell_aimed`). So this is where it is written down, and a crash costs at most the step in
## progress rather than the session.
func _on_player_arrived(cell: Vector2i) -> void:
	print("Arrived at %s" % cell)
	_update_weather()
	_sync_chest()
	_save_map()
	_update_buttons()
	if _chart_target != HexMap.NO_CELL:
		var target := _chart_target
		_chart_target = HexMap.NO_CELL
		# Selecting it again is what the fight reads, in case the player clicked elsewhere on the way.
		map.select_cell(target)
		_on_chart_pressed()
	# Where standing on a settlement becomes true: walking to one, and the walk a won settlement fight
	# sends the player on when it charts the tile. Last, so a walk that ends in a fight has opened it
	# first and a pop-up holds that fight still rather than letting its clock run under it.
	_check_tips()


## A tile is either something to look at or somewhere to go, and neither while the player is walking.
## A button that can't be pressed is not shown at all.
func _update_buttons() -> void:
	var cell := map.selected_cell
	_chart_button.visible = view.can_chart(cell)
	_skip_button.visible = _chart_button.visible and OS.is_debug_build()
	_move_button.visible = view.can_move_to(cell)
	_farm_button.visible = view.can_farm(cell)
	# Camping takes exactly what farming takes -- a tile already won -- because it is that fight
	# with nobody clicking. Where nothing would swing it is greyed with the reason rather than
	# taken away: "why can I not camp" is a worse question than the answer.
	_camp_button.visible = _farm_button.visible
	var why := _cannot_camp()
	_camp_button.disabled = not why.is_empty()
	_camp_button.tooltip_text = why if not why.is_empty() else CAMP_TIP
	_town_button.visible = view.can_visit(cell)
	_place_panel()


## Stands the tile panel against the whole right edge, as `TownPage.layout` has its page, so Enter
## town changes what the column holds and not where it is. Called whenever a row or a button comes
## or goes, because the column's width is its contents'.
func _place_panel() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	_panel.reset_size()
	_panel.size.y = view_size.y / ui_scale
	_panel.position = Vector2(view_size.x - _panel.size.x * ui_scale, 0.0)


## A kill left something behind. Whether it goes straight into the bag or waits in the run's pouch is
## the ledger's rule (`FightLedger`); what is left to do here is show it.
func _on_loot_dropped(_index: int, item: Item) -> void:
	print("Dropped %s (%s, level %d, %d modifier(s))"
			% [item.type, item.rarity_name(), item.level, item.mods.size()])
	# Asked before the ledger has it: a tile fight banks at once, and the log would already say it was
	# found by the time the banner went up.
	var first := _is_new_unique(item)
	ledger.add_loot(item)
	if first:
		_announce_unique(item)
	if not ledger.farming:
		bag_page.refresh()
	_refresh_bag_room()


func _on_gold_gained(amount: float) -> void:
	ledger.add_gold(amount)
	bag_page.refresh_gold()


func _on_orb_gained(orb: String) -> void:
	ledger.add_orb(orb)
	bag_page.refresh_orbs()


## The gems of one body have landed in the bar. The panel fills here rather than when the experience
## is earned, which is the ledger's business.
func _on_xp_absorbed(amount: int) -> void:
	if _character.absorb(amount) > 0:
		_celebrate_level(_character.level)


func _on_loot_autodiscarded(_index: int, item: Item) -> void:
	print("Autodiscarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
	ledger.autodiscarded()
	_pay_salvage(item)


## A find the player threw away by hand, from the fight's own panel.
func _on_drop_discarded(item: Item) -> void:
	if ledger.discard(item):
		bag_page.refresh()
	_pay_salvage(item)
	_refresh_bag_room()


## The Rag and Bone Sack, for a find thrown away in a fight. Through the ledger like any gold, so a
## run pouches it and a tile fight banks it; the bag pays for its own discards (`BagPage`).
func _pay_salvage(item: Item) -> void:
	var paid := inventory.salvage(item)
	if paid > 0.0:
		ledger.add_gold(paid)


## Tells the fight how much room is left, which is what puts the full-bag warning up.
func _refresh_bag_room() -> void:
	if _combat != null:
		_combat.bag_room = ledger.room_left()


## A body has fallen. What it was goes to the ledger, which is what knows whether a bounty hears about
## it now or when the run banks.
func _on_enemy_died(index: int) -> void:
	if _combat != null and index < _combat.fight.lineup.size():
		ledger.add_kill(_combat.fight.lineup[index])


## Empties a farm run's pouch into the bag. Called on the way out of a run and on the way out of the
## game, so quitting mid-run cannot cost the finds; the ledger keeps the second from repeating the first.
func _bank_run() -> void:
	if ledger.bank():
		bag_page.refresh()


## The square buttons in a column, the ones there are closed up: what you carry (the bag, then the
## heirlooms), what you are, what you have promised to do, then the settings and the log. Under the character panel on the map; beside whichever page is
## up -- which has that panel's corner -- so one press goes from page to page without an X between.
func _place_corner() -> void:
	# The bag measures itself as it is built (`laid_out`), before the pages after it exist.
	if not is_instance_valid(character_page) or not character_page.is_inside_tree():
		return
	var at := Vector2(8, _character.position.y + (_character.size.y + 4) * ui_scale)
	var page := _left_page()
	if page != null:
		# Every page's own panel is its first child, against the left edge; the bag runs on past its.
		var panel: Control = page.get_child(0)
		var bag := page as BagPage
		var edge: float = (bag.right_edge() if bag != null
				else panel.position.x + panel.size.x * ui_scale)
		# The bag's sheet is centred down the window, and a column at the window's top beside it
		# belonged to nothing: it starts where the sheet does.
		var top: float = (bag.sheet_top(_character.position.y) if bag != null
				else _character.position.y)
		at = Vector2(edge + CORNER_GAP * ui_scale, top)
	var step := (_bag_button.get_combined_minimum_size().y + CORNER_GAP) * ui_scale
	for button: Button in [_bag_button, _heirloom_button, _skills_button, _bounty_button,
			_settings_button, _collection_button]:
		if button.visible:
			button.position = at
			at.y += step


## Every corner button at once. They come and go together because what takes them away is never
## about one of them: a fight that must see every click, or a town, whose three panels leave the
## window no room. A page does not -- they stand beside it (`_place_corner`) -- but it does cover the
## character panel, and the see-through button over that goes with it.
func _show_corner(shown: bool) -> void:
	# The one button a town leaves standing, because it is the only way to hold an heirloom up to a
	# smith, a fortuneteller or a held orb: there it swaps the bag and the heirlooms at the counter.
	_heirloom_button.visible = shown and (inventory.stash().total() > 0
			or not inventory.stash().equipment.worn.is_empty())
	if _heirloom_button.visible:
		_flash(_heirloom_button, "opened_heirlooms")
	shown = shown and not town_page.visible
	_bag_button.visible = shown and ("first_item" in inventory.tips or "first_orb" in inventory.tips)
	_skills_button.visible = shown and "level_up" in inventory.tips
	# The journal has nothing in it until the player has stood at a board, which is also when their
	# kills start counting towards one.
	_bounty_button.visible = shown and BountyBoard.any_seen(inventory.towns)
	# Nothing earns the settings: they are there from the first step.
	_settings_button.visible = shown
	_character_button.visible = shown and _left_page() == null
	# The log is a thing to be found, like what it lists: it is not there until the first unique is.
	_collection_button.visible = shown and (Settings.show_all_uniques()
			or not inventory.uniques_found.is_empty())
	if _collection_button.visible:
		_flash(_collection_button, "opened_collection")
	if _bag_button.visible:
		_flash(_bag_button, "opened_bag")
	if _skills_button.visible:
		_flash(_skills_button, "opened_skills")
	_place_corner()


## Whether the thing a tip is about has happened yet.
func _tip_due(id: String) -> bool:
	match id:
		"first_item":
			return inventory.total() > 0
		"first_orb":
			return inventory.total_orbs() > 0
		"level_up":
			return inventory.level > 1
		"first_farm":
			return ledger.farming and _combat != null
		"first_chart":
			return not ledger.farming and _combat != null
		"first_town":
			return view != null and view.can_visit(view.player_cell)
		"first_bounty":
			return BountyBoard.any_seen(inventory.towns)
		"first_unique":
			return not inventory.uniques_found.is_empty()
		"first_heirloom":
			return inventory.super_orbs > 0
	return false


## Queues every tip that has come due and not been shown, and brings on the buttons they unlock.
func _check_tips() -> void:
	var added := false
	for tip: Array in TIPS:
		if tip[0] not in inventory.tips and _tip_due(tip[0]):
			inventory.tips.append(tip[0])
			_tip_queue.append(tip)
			added = true
	# Not mid-fight: a run writes nothing until it ends, and `bank_kills` saves the seen tip then.
	if added and _combat == null:
		inventory.save(inventory_path)
	# A tip can come due with a page up or a town open, and `_show_corner` knows about both.
	_show_corner(_combat == null and _camp == null)
	if _tip_panel == null:
		_show_next_tip()


## One tip at a time, in the middle of the window, built the way the refused-save panel is.
func _show_next_tip() -> void:
	if _tip_queue.is_empty():
		return
	var tip: Array = _tip_queue.pop_front()
	_tip_panel = UITheme.titled_panel(tip[1], "Close", _on_tip_closed)
	_tip_panel.scale = Vector2(ui_scale, ui_scale)
	# A fight holds still under a tip: a charting fight's clock must not run while the player reads.
	if _combat != null:
		_combat.process_mode = Node.PROCESS_MODE_DISABLED
	# The character panel's layer, which stands over the fight's, so a tip can come up mid-run.
	_character.get_parent().add_child(_tip_panel)
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(get_viewport().get_visible_rect().size.x / ui_scale - REFUSAL_MARGIN, REFUSAL_WIDTH)
	label.text = tip[2]
	UITheme.body_of(_tip_panel).add_child(label)
	# Deferred: a wrapped label only knows how tall it is once it has been laid out once.
	_center_panel.call_deferred(_tip_panel)


func _on_tip_closed() -> void:
	_tip_panel.queue_free()
	_tip_panel = null
	_show_next_tip()
	if _tip_panel == null and _combat != null:
		_combat.process_mode = Node.PROCESS_MODE_INHERIT


## Pulses a button until it has been pressed once. The tween is the scene's, so a button hidden for
## a fight is still pulsing when it comes back.
func _flash(button: Button, id: String) -> void:
	if id in inventory.tips or _flashes.has(id):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(button, "modulate", FLASH_BRIGHT, FLASH_SECONDS)
	tween.tween_property(button, "modulate", Color.WHITE, FLASH_SECONDS)
	_flashes[id] = [tween, button]


## The first press: the pulse stops for good.
func _stop_flash(id: String) -> void:
	if id in inventory.tips:
		return
	inventory.tips.append(id)
	inventory.save(inventory_path)
	if _flashes.has(id):
		_flashes[id][0].kill()
		_flashes[id][1].modulate = Color.WHITE
		_flashes.erase(id)


## Every page that stands against the left edge. They share it, so opening one closes the rest and
## there is one place that knows which those are.
func _left_pages() -> Array[Control]:
	return [bag_page, heirloom_page, skills_page, bounty_page, settings_page, collection_page,
			character_page]


func _close_left_pages() -> void:
	for page in _left_pages():
		page.hide()


## The one that is up, or null.
func _left_page() -> Control:
	for page in _left_pages():
		if page.visible:
			return page
	return null


func _left_page_up() -> bool:
	return _left_page() != null


## The corner buttons move over to stand beside it (`_show_corner` places them).
func _open_left_page(page: Control) -> void:
	_close_left_pages()
	_layout_ui()
	page.show()
	# Alt on a square compares against the doll of the page it is on.
	_item_card.equipment = (inventory.stash().equipment if page == heirloom_page
			else inventory.equipment)
	_show_corner(true)
	# The page covers the left edge, and it stands on a layer above the character panel.
	_character.hide()


## The X on any page: the same things follow from closing any of them. A town page and the bag in
## shop mode are one thing on screen, so either X puts both away.
func _on_left_page_closed() -> void:
	_close_left_pages()
	_close_town()
	_show_corner(true)
	_character.show()


## A corner button or the character panel pressed: its page, redrawn because what it shows moves
## while it is shut -- or, pressed beside its own open page, that page put away as its X would.
func _toggle_left_page(page: Control) -> void:
	if page.visible:
		_on_left_page_closed()
		return
	page.open()
	_open_left_page(page)


## Leaves the town: the page goes, the bag stops being a shop, and the tile panel takes its edge back.
## Does nothing when there is no town open, so every path out of one can call it.
func _close_town() -> void:
	if not town_page.visible:
		return
	town_page.hide()
	_town_cell = HexMap.NO_CELL
	bag_page.shop(PackedStringArray())
	heirloom_page.shop(PackedStringArray())
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()


func _on_skills_pressed() -> void:
	_stop_flash("opened_skills")
	_toggle_left_page(skills_page)


func _on_bag_pressed() -> void:
	_stop_flash("opened_bag")
	_toggle_left_page(bag_page)


## The crown. On the map it is a page like the rest. In a town it swaps which of the two bag pages
## stands at the counter, and never closes the town: the X does that.
func _on_heirlooms_pressed() -> void:
	_stop_flash("opened_heirlooms")
	if not town_page.visible:
		_toggle_left_page(heirloom_page)
		return
	_open_left_page(bag_page if heirloom_page.visible else heirloom_page)
	_stand_at_counter()
	# What the other page had open is no longer what is held up to the counter.
	town_page.bag_changed(null)
	_layout_ui()


## Whichever bag page is standing beside the town: the bag, unless the crown has swapped it out.
func _counter_page() -> BagPage:
	return heirloom_page if heirloom_page.visible else bag_page


func _on_bounty_pressed() -> void:
	_toggle_left_page(bounty_page)


func _on_collection_pressed() -> void:
	_stop_flash("opened_collection")
	_toggle_left_page(collection_page)


func _on_character_pressed() -> void:
	_toggle_left_page(character_page)


func _on_settings_pressed() -> void:
	_toggle_left_page(settings_page)


## A bounty said where its monster lives and the player asked to be shown: every page gets out of the
## way, the tile is selected and the camera walks over to it, so what happens next is the tile panel's
## own Move here, Farm or Chart rather than a third way of doing those.
func _on_show_cell(cell: Vector2i) -> void:
	_on_left_page_closed()
	map.select_cell(cell)
	camera.position = _clamp_to_map(map.ground_layer.map_to_local(cell))


## Inside the settlement the player is standing on: the town page takes the tile panel's edge and the
## bag opens on the other one in shop mode, so what is being sold is already laid out beside the
## counter buying it. The two are one thing on screen and close together.
func _on_town_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_visit(cell):
		return
	var spot := view.origin + cell
	var tier := view.town_tier(cell)
	var services := TownServices.services_for(tier, spot, towns.seed_value)
	print("Entered %s, %s (%s): %s" % [view.name_of(cell), cell, spot, services])
	_town_cell = cell
	# The page is what marks the town visited and fills its shelves, and it saves when it does: one
	# place walks into a town, so there is one place the save has to be right.
	town_page.open(view.name_of(cell), services, cell, spot, tier)
	_panel.hide()
	town_page.show()
	# The bag first and the counter second: which page is up is what `_stand_at_counter` asks.
	_open_left_page(bag_page)
	_stand_at_counter()
	_layout_ui()
	# Drawing the board is reading it, and a town always opens on its board (`TownServices.ORDER`), so
	# this is where the tip about the bounties comes due.
	_check_tips()


## One of the fortuneteller's aimed spells, asked for and not yet paid: the town and the tile panel
## get out of the way and the map is aimed at, an outline under the cursor -- a patch of them for the
## scour, one tile for the road home. The click is what pays (`_on_cell_aimed`); the panel's X and
## Escape put the spell away for nothing.
func _on_spell_aimed(reading: String, price: float, spot: Vector2i) -> void:
	_on_left_page_closed()
	_on_close_pressed()
	_aiming = reading
	_aim_price = price
	_aim_town = spot
	map.aim_radius = FortuneTeller.SCOUR_RADIUS if reading == FortuneTeller.SCOUR else 0
	_aim_panel = UITheme.titled_panel(FortuneTeller.LABELS[reading], "Keep the spell for later", _end_aim)
	_aim_panel.scale = Vector2(ui_scale, ui_scale)
	_ui_layer.add_child(_aim_panel)
	UITheme.body_of(_aim_panel).add_child(UITheme.label(AIM_LINES[reading], null, true))
	_aim_panel.position = Vector2(
			(get_viewport().get_visible_rect().size.x - _aim_panel.get_combined_minimum_size().x * ui_scale) / 2.0, 0.0)


## Land chosen. A spell that could do nothing with it -- a patch with nothing left to show, all seen
## already or past the edge of what the map has made; a tile that is no settlement the player has
## charted -- is refused and the aim stays up, so the town's one casting is never spent on nothing.
func _on_cell_aimed(cell: Vector2i) -> void:
	if _aiming.is_empty() or _aim_price <= 0.0 or inventory.gold < _aim_price:
		return
	var scouring := _aiming == FortuneTeller.SCOUR
	var shown := view.scour(cell) if scouring else 0
	if scouring and shown == 0:
		return
	if not scouring and not view.jump_to(cell):
		return
	inventory.gold -= _aim_price
	# A great spell is one a settlement, and it is this town that cast it.
	inventory.towns.visit(_aim_town)[FortuneTeller.ASKED + _aiming] = true
	inventory.save(inventory_path)
	if scouring:
		_save_map()
		print("Scoured %d tiles round %s for %s gold" % [shown, cell, BigNumber.format(_aim_price)])
	else:
		print("Came home to %s for %s gold" % [cell, BigNumber.format(_aim_price)])
	_end_aim()


## The aim put away, paid for or not.
func _end_aim() -> void:
	_aiming = ""
	_aim_price = 0.0
	_aim_town = TownWorld.NO_SPOT
	map.aim_radius = -1
	if _aim_panel != null:
		_aim_panel.queue_free()
		_aim_panel = null


## Another counter opened: the bag buys what that counter buys and nothing else. A page of its own
## (skills, bounties, settings) standing in the bag's place leaves the counter's other half missing
## -- the smith with nothing held up to him, no Sell beside a vendor -- so the bag comes back first.
func _on_town_tab_changed(_service: String) -> void:
	if not bag_page.visible and not heirloom_page.visible:
		_open_left_page(bag_page)
		_layout_ui()
	_stand_at_counter()


## Points the bag at the town page's open tab. The town's own cell rather than whatever is selected:
## the map is still clickable behind the page, and what an orb is worth is a property of the town the
## player walked into, not of the tile they last looked at.
func _stand_at_counter() -> void:
	var tab := town_page.open_tab()
	_counter_page().shop(PackedStringArray() if tab.is_empty() else PackedStringArray([tab]), _town_cell)


## Quitting with a run still on. The pouch goes in rather than evaporating -- a run that is left
## by closing the window found what it found -- and the map goes down as it stands.
func _exit_tree() -> void:
	Cursors.put_away()
	# A refused save built nothing, so there is nothing to bank and nothing that may be written.
	if _resetting or _save_blocked:
		return
	_bank_run()
	if _combat != null:
		ledger.bank_kills(_combat.fight.kills())
	_save_map()


## The settings page's Reset, once confirmed: deletes the inventory and the map and reloads, which
## generates a new world. The settings are a file of their own and stay.
func _on_reset_pressed() -> void:
	_resetting = true
	for path: String in [inventory_path, map_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().reload_current_scene()


## The fortuneteller's way out, asked for and answered yes: everything on screen goes and the game
## fades to `TranscendPage`, where the player is paid for the world they are leaving. **Nothing is
## written until that page is left** (`_transcend`), so a game closed on it has not transcended.
## The price is checked and never taken, because the purse is one of the things that stays behind.
func _on_transcend_pressed() -> void:
	if _transcend_page != null \
			or inventory.gold < TownPrices.fortune_price(FortuneTeller.TRANSCEND, _town_cell):
		return
	_on_left_page_closed()
	_on_close_pressed()
	_show_corner(false)
	_character.hide()
	_transcend_page = TranscendPage.new(inventory, ui_scale)
	_transcend_page.finished.connect(_transcend)
	_ui_layer.add_child(_transcend_page)


## The black screen left behind. The world goes the way Reset sends it -- the map deleted, the scene
## loaded again into a new one -- but the inventory is not deleted: it is written over with what
## `Inventory.transcended` keeps, the heirlooms first among it.
func _transcend() -> void:
	print("Transcended with %d heirloom(s)" % (inventory.stash().total()
			+ inventory.stash().equipment.worn.size()))
	# Written before anything is deleted: a crash between the two leaves the new inventory on the old
	# map, which plays, and never the old inventory on no map at all.
	if not inventory.transcended().save(inventory_path):
		return
	_resetting = true
	if FileAccess.file_exists(map_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	# A test stands this scene under the root rather than as the current one, and has nothing to reload.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Escape is every X at once: the tip if one is up, otherwise the pages, the town and the tile panel
## together. A fight answers for itself (`CombatScene._unhandled_input`) and gets the key first, being
## further down the tree -- except under a tip, where it is not processing and the tip is what closes.
func _input(event: InputEvent) -> void:
	Cursors.twitch(get_tree(), event)
	# A swing decides how the unique banner goes away: one in its first five seconds closes it at the
	# end of them, one after that closes it there and then. Never marked handled, so the click still
	# reaches the fight and costs the player nothing.
	if (_unique_banner != null and event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		_banner_clicked = true
		if _banner_closable:
			_close_unique_banner()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _combat == null and map.visible 			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(event.position, 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		get_viewport().set_input_as_handled()
		return
	# A camp answers for itself: its X and its Break camp are the ways out, so a stray Escape cannot
	# quietly end a night's rest. The black screen of a transcension is the same.
	if not event.is_action_pressed("ui_cancel") or _transcend_page != null or _camp != null:
		return
	get_viewport().set_input_as_handled()
	if _tip_panel != null:
		_on_tip_closed()
	elif _aim_panel != null:
		_end_aim()
	elif _combat == null:
		if _left_page_up() or town_page.visible:
			_on_left_page_closed()
		if _panel.visible:
			_on_close_pressed()


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	_panel.hide()
	map.deselect()
	_update_buttons()
