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
## The marks the two corner buttons wear. A chest for what has been carried home and a star for what
## the player has become: both are places to go rather than actions to take, which is what the brown
## face says and what puts them in a row of their own rather than among the panels' green buttons.
const CHEST_ICON := "res://Assets/UI/ui_icon_chest.png"
const STAR_ICON := "res://Assets/UI/ui_icon_star.png"
## The air between the two, in panel pixels.
const CORNER_GAP := 4.0

## The panel that stands in for the map when its save cannot be read: how wide it is allowed to be
## in panel pixels, and the air it keeps either side of it on a window too narrow for that.
const REFUSAL_WIDTH := 300.0
const REFUSAL_MARGIN := 32.0

var towns: TownWorld
var view: MapBuilder
## Everything the player has picked up, loaded from `inventory_path` and written back as it grows.
var inventory: Inventory

## The level-up fanfare: how bright the screen flashes, how long the words hang and how big they
## arrive before settling at LEVEL_UP_FONT, which is a whole multiple of Pixellari's 16.
const LEVEL_UP_FLASH := Color(1.0, 0.95, 0.75, 0.35)
const LEVEL_UP_TIME := 1.6
const LEVEL_UP_FONT := 48

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
## The two left-hand pages and the corner buttons that open them. They share the edge, so only one
## page is ever up: opening either closes the other.
var bag_page: BagPage
var skills_page: SkillsPage
var _bag_button: Button
var _skills_button: Button
## The player in the top-left corner, over the map and over a fight alike.
var _character: CharacterPanel

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
]
const FLASH_BRIGHT := Color(1.6, 1.6, 1.6)
const FLASH_SECONDS := 0.5

var _ui_layer: CanvasLayer
## Dev only: wipes both saves and starts over. `_resetting` keeps `_exit_tree` from writing them back.
var _reset_button: Button
var _resetting := false
## Tips earned but not shown yet, and the one that is up.
var _tip_queue: Array = []
var _tip_panel: VBoxContainer
## Pulses on corner buttons that have not been pressed yet: the pressed-once id -> its tween.
var _flashes := {}
## The weather and the day over the map.
var _ambient: Ambient
## The glimmer pointing at the nearest chest; its target is worked out on arrival.
var _chest_pointer: ChestPointer


func _ready() -> void:
	# Two different nulls: no file at all is a first run, and a file that cannot be honoured stops.
	# Generating a world in its place would write over it on the player's first step, and a map lost
	# to a bad read is worse than an error message.
	# The inventory first, and by the same rule: it is what the player owns, and an empty bag saved over
	# a file that could not be read is that file gone on the first kill.
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
	view.arrived.connect(_on_player_arrived)
	_build_ui()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.ground_layer.map_to_local(view.player_cell)
	# A child of the map, so it hides and stops with it while a fight is on.
	_ambient = Ambient.new()
	map.add_child(_ambient)
	_ambient.setup(camera)
	_update_weather()
	_chest_pointer.target = view.nearest_chest()
	# The world is decided the moment it is generated, so it is written down then: a first run
	# killed before the player moves would otherwise come back as somewhere else entirely.
	_save_map()


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
	_chart_button = UITheme.button("Chart", "LightButton", "Fight for this tile and what lies behind it")
	_chart_button.pressed.connect(_on_chart_pressed)
	buttons.add_child(_chart_button)
	_move_button = UITheme.button("Move here", "LightButton", "Walk to the selected tile")
	_move_button.pressed.connect(_on_move_pressed)
	buttons.add_child(_move_button)
	# And a third thing to do with a tile you have already taken: stand on it and fight until you
	# have had enough. Nothing is won by it but what the bodies were carrying.
	_farm_button = UITheme.button("Farm", "LightButton", "Fight here for as long as you like, for the loot")
	_farm_button.pressed.connect(_on_farm_pressed)
	buttons.add_child(_farm_button)

	_reset_button = UITheme.button("Reset", "LightButton", "Dev: delete the saves and start a new game")
	_reset_button.theme = UITheme.theme()
	_reset_button.scale = Vector2(ui_scale, ui_scale)
	_reset_button.pressed.connect(_on_reset_pressed)
	layer.add_child(_reset_button)

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
	skills_page = SkillsPage.new(inventory, inventory_path, ui_scale)
	bag_page = BagPage.new(inventory, inventory_path, ui_scale)
	for page: Control in [skills_page, bag_page]:
		page.hide()
		page.closed.connect(_on_left_page_closed)
		layer.add_child(page)


## The weather for wherever the player now stands.
func _update_weather() -> void:
	var ground := map.ground_layer.get_cell_tile_data(view.player_cell)
	_ambient.set_env(ground.get_custom_data("env") if ground != null else "")


## A level gained: the screen flashes warm, the words pop up over the middle and float away. On the
## character panel's layer, so it stands over a fight as well as the map.
func _celebrate_level(level: int) -> void:
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


## The tile panel is scaled by `ui_scale`, so it is sized in sprite pixels: a height of view/ui_scale
## fills the window exactly. It stands flush against the right edge; the left-hand pages lay
## themselves out against the other.
func _layout_ui() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var height := view_size.y / ui_scale
	var width := _panel.get_combined_minimum_size().x
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(view_size.x - width * ui_scale, 0.0)
	bag_page.layout()
	skills_page.layout()
	# The two square buttons in a row under the character panel: what you carry, then what you are.
	var corner := Vector2(8, _character.position.y + (_character.size.y + 4) * ui_scale)
	_bag_button.position = corner
	_skills_button.position = corner + Vector2(
			(_bag_button.get_combined_minimum_size().x + CORNER_GAP) * ui_scale, 0.0)
	_reset_button.position = Vector2(8, view_size.y - (_reset_button.get_combined_minimum_size().y * ui_scale) - 8)
	if _combat != null:
		_combat.xp_target = _character.xp_point()


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
	var chest := view.has_chest(cell)
	if chest:
		print("A treasure chest waits on %s" % cell)
	_open_fight(Encounter.for_tile(cell, env, variant, chest), cell, false)


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
	fight.effects = inventory.skills.effects()
	fight.orbs_after = maxi(0, OrbTable.FIRST_ORB_KILLS - inventory.kills)
	ledger = FightLedger.new(inventory, inventory_path, farming)
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
	var earned: int = _combat.fight.gold
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
	print("The fight turned up: %s, and %d gold"
			% ["nothing" if turned_up.is_empty() else ", ".join(turned_up), earned])
	if ledger.farming:
		# Nothing about the map moves for a run. The tile was already taken; the loot is the whole of it.
		print("Farmed %s, %d slain" % [cell, kills])
	elif won:
		print("Charted %s, showing %d tile(s) behind it; walking there" % [cell, view.chart(cell)])
	else:
		print("Lost the fight for %s; it stays uncharted" % cell)
	ledger.farming = false
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()
	# After banking, so a run's pouch counts; after the fight, so a pop-up never covers one.
	_check_tips()


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
	_update_weather()
	_chest_pointer.target = view.nearest_chest()
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


## A kill left something behind. Whether it goes straight into the bag or waits in the run's pouch is
## the ledger's rule (`FightLedger`); what is left to do here is show it.
func _on_loot_dropped(index: int, item: Item) -> void:
	print("Dropped %s (%s, level %d, %d modifier(s))"
			% [item.type, item.rarity_name(), item.level, item.mods.size()])
	ledger.add_loot(item, _dropped_by_elite(index))
	if not ledger.farming:
		bag_page.refresh()
	_refresh_bag_room()


func _on_gold_gained(amount: int) -> void:
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


func _on_loot_autodiscarded(index: int, item: Item) -> void:
	print("Autodiscarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
	ledger.autodiscarded(_dropped_by_elite(index))


## A find the player threw away by hand, from the fight's own panel.
func _on_drop_discarded(item: Item) -> void:
	if ledger.discard(item):
		bag_page.refresh()
	_refresh_bag_room()


## Tells the fight how much room is left, which is what puts the full-bag warning up.
func _refresh_bag_room() -> void:
	if _combat != null:
		_combat.bag_room = ledger.room_left()


## Whether the enemy in slot `index` of the fight going on is an elite. Asked of the roster rather
## than of the position: a farm run's elites come round forever and there is no last one.
func _dropped_by_elite(index: int) -> bool:
	if _combat == null or index >= _combat.fight.lineup.size():
		return false
	return EnemyRoster.tier_of(_combat.fight.lineup[index]) == EnemyRoster.Tier.ELITE


## Empties a farm run's pouch into the bag. Called on the way out of a run and on the way out of the
## game, so quitting mid-run cannot cost the finds; the ledger keeps the second from repeating the first.
func _bank_run() -> void:
	if ledger.bank():
		bag_page.refresh()


## Both corner buttons at once. They come and go together because what takes them away is never
## about one of them -- a page standing on their edge, or a fight that must see every click.
func _show_corner(shown: bool) -> void:
	_bag_button.visible = shown and ("first_item" in inventory.tips or "first_orb" in inventory.tips)
	_skills_button.visible = shown and "level_up" in inventory.tips
	# Off the map in a release build, and out of a fight's way like the rest of the corner.
	_reset_button.visible = shown and OS.is_debug_build()
	if _bag_button.visible:
		_flash(_bag_button, "opened_bag")
	if _skills_button.visible:
		_flash(_skills_button, "opened_skills")


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
	_show_corner(_combat == null)
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
func _close_left_pages() -> void:
	bag_page.hide()
	skills_page.hide()


## A page takes the corner's place while it is open, so that corner never holds both.
func _open_left_page(page: Control) -> void:
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
	_stop_flash("opened_skills")
	# Levels and gold both move while the page is shut, and both change what it says.
	skills_page.open()
	_open_left_page(skills_page)


func _on_bag_pressed() -> void:
	_stop_flash("opened_bag")
	bag_page.open()
	_open_left_page(bag_page)


## Quitting with a run still on. The pouch goes in rather than evaporating -- a run that is left
## by closing the window found what it found -- and the map goes down as it stands.
func _exit_tree() -> void:
	# A refused save built nothing, so there is nothing to bank and nothing that may be written.
	if _resetting or _save_blocked:
		return
	_bank_run()
	if _combat != null:
		ledger.bank_kills(_combat.fight.kills())
	_save_map()


## Dev: deletes the inventory and the map and reloads, which generates a new world.
func _on_reset_pressed() -> void:
	_resetting = true
	for path: String in [inventory_path, map_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().reload_current_scene()


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	_panel.hide()
	map.deselect()
	_update_buttons()
