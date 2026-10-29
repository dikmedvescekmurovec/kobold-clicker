extends Node2D
## The game on the map: start-up and the two saves, the corner buttons and which page is up, tips, and
## opening and closing fights. What it owns and every rule it keeps: `Scenes/CLAUDE.md`.

## Seeds for the town world and the rendered map. 0 carries on with the save's, or picks a random one
## when there is no save; any other value replaces a save of another world. The used seeds are printed.
@export var world_seed := 0
@export var map_seed := 0
## World spot shown at the map's center cell (0, 0), which is the middle of the screen. The row must be even.
@export var map_origin := Vector2i(128, 128)
## Whole-number pixel zoom, so sprite pixels stay square. 0 is `ZOOM_PER_UI` times `ui_scale`, rounded:
## 3 on the default window.
@export var zoom := 0.0
## The interface's whole-number scale. 0 is picked from the window as the game starts
## (`UITheme.pick_scale`): 2 on the default window.
@export var ui_scale := 0.0
## Where the two saves are kept. The tests and the screenshot scripts point both elsewhere before the
## scene enters the tree: they all pin a seed, and a pinned seed that differs from a save is a request
## for another world that replaces it on the first write.
@export var inventory_path := Inventory.SAVE_PATH
@export var map_path := MapSave.SAVE_PATH

## The map's zoom for each step of `ui_scale`, and how far the mouse wheel (or a pinch) takes it either
## way, in the same whole steps: from 1 to `ZOOM_MOST` times `ui_scale`.
const ZOOM_PER_UI := 1.5
const ZOOM_MIN := 1.0
const ZOOM_MOST := 3.0
## How far two fingers have to spread (or close, by its inverse) to step the zoom once.
const PINCH_STEP := 1.3
## Held upright (`UITheme.narrow`) a town is the bag over its page, the page this share of the room.
const TOWN_SPLIT := 0.5
## Seconds a camera glide takes (`_glide_camera`).
const CAMERA_LIFT := 0.25
## Where a headless run left at the player's own two paths plays instead (`_ready`).
const HEADLESS_INVENTORY := "user://headless_inventory.json"
const HEADLESS_MAP := "user://headless_map.json"
const COMBAT_SCENE := "res://Scenes/Combat/combat_scene.tscn"
## What the dungeon is called over its fight.
const DUNGEON_NAME := "The Descent"
## How long the game has to have been shut for a camp to be worth a screen, in seconds.
const CAMP_LEAST := 60.0

## The corner buttons' marks.
const CHEST_ICON := "res://Assets/UI/ui_icon_chest.png"
const TREE_ICON := "res://Assets/UI/ui_icon_tree.png"
const SCROLL_ICON := "res://Assets/UI/ui_icon_scroll.png"
const COG_ICON := "res://Assets/UI/ui_icon_cog.png"
const ROSETTE_ICON := "res://Assets/UI/ui_icon_rosette.png"
const BOOK_ICON := "res://Assets/UI/ui_icon_book.png"
const PODIUM_ICON := "res://Assets/UI/ui_icon_podium.png"
## The items' chest with a gleam on its corner; the chest stands pixel for pixel where `CHEST_ICON`'s
## does (the user's rule, 2026-10-11).
const HEIRLOOM_ICON := "res://Assets/UI/ui_icon_heirloom.png"
## A stand-in too: the bag's helmet tab's mark, until the heroes have one.
const ROSTER_ICON := "res://Assets/UI/ui_icon_slot_helmet.png"
## The red pip over a corner button's top-right corner while its page has something new (`_mark_new`).
const NEW_PIP := "res://Assets/UI/ui_pip_new.png"
## What the chest's pip is for, and nothing else in the bag is: the first of each of these to reach it,
## by the id `inventory.tips` has it under. The next time the bag is up each is `SEEN` + its id there.
const BAG_FIRSTS: Array[String] = ["first_item", "first_orb", "first_stone", "first_unique", Inventory.FIRST_RUNE]
const SEEN := "seen_"
## The corner's keys -> the button each presses (`_unhandled_input`). Letters only, and none the item
## card answers to (Shift, Ctrl, Alt).
const HOTKEYS := {
	KEY_I: "_bag_button", KEY_K: "_skills_button", KEY_C: "_character_button", KEY_J: "_bounty_button",
	KEY_L: "_collection_button", KEY_Y: "_achievements_button", KEY_H: "_heirloom_button",
	KEY_P: "_leaderboard_button", KEY_O: "_settings_button", KEY_R: "_roster_button",
}
## The air between one corner button and the next, in panel pixels.
const CORNER_GAP := 4.0
## How tall the corner buttons' navigation bar is held upright, in panel pixels (`_place_corner_row`), and
## how far the open page's tab stands up out of it.
const NAV_HEIGHT := 36.0
const NAV_RISE := 2
## The bar's other marks while a page of its is open, so the open one stands out: warmed toward the tan
## rather than greyed, which muddied them.
const NAV_DIM := Color(0.9, 0.72, 0.62)
## Where a corner button's red pip stands off its face's top-right corner, in panel pixels.
const PIP_AT := Vector2(-6, -2)
## How far the character panel stands in from the window's corner, in window pixels.
const CHARACTER_EDGE := Vector2(8, 8)
## A panel of plain words (the refused save's, the changelog's): how wide it may be in panel pixels,
## and the air it keeps either side of it on a window too narrow for that.
const REFUSAL_WIDTH := 300.0
const REFUSAL_MARGIN := 32.0
const FLASH_BRIGHT := Color(1.6, 1.6, 1.6)
const FLASH_SECONDS := 0.5

## What marks a tip as the hero's: their box is titled with the name the player has given them
## (`Inventory.hero`).
const HERO := "Adventurer"
## First-time tips, in the order they are shown, each `[id, speaker, pages, portrait]`, the portrait a
## name under `DialogueBox.PORTRAITS` (`DialogueBox.PLAYER` for the hero, who stands on the left). Each
## is shown once, after the fight that earned it, and the corner button it is about only appears with
## it. Every id needs its rule in `_tip_due`. The copy is the user's own: change it only when asked.
const TIPS := [
	["first_item", HERO, [
		"That one dropped something. Mine now.",
		"Let's see if it fits.",
	], "player"],
	["first_orb", HERO, [
		"It's warm, and it's glowing. My gear would look good glowing.",
	], "player"],
	["first_stone", HERO, [
		"Can't wear it. Can't eat it. I checked both. Maybe I can learn from it.",
	], "player"],
	["level_up", HERO, [
		"I feel stronger. Taller, even.",
		"Well...",
		"...probably not taller.",
	], "player"],
	["first_farm", HERO, [
		"They just keep coming! Good. No rush, then.",
	], "player"],
	["first_chart", HERO, [
		"Right, clock's ticking. I love it when the clock's ticking.",
	], "player"],
	["first_death", HERO, [
		"Ouch. Not ready for that one yet.",
		"I need to get stronger. The ones back on my own land go down easy.",
	], "player"],
	["first_town", HERO, [
		"Ohh ... a proper place. With a gate and everything.",
		"Right. Plan. Sell the sticky stuff, keep the sharp stuff.",
	], "player"],
	["first_unique", HERO, [
		"Now this is something. I wonder how many more are out there.",
	], "player"],
	["first_heirloom", "Fortuneteller", [
		"The wall's down, then. Took you long enough.",
		"Come see me in town when you want out of this world. It'll cost you everything but you'll thank me in the next one.",
	], "fortuneteller"],
	["first_cave", HERO, [
		"Something big lives at the bottom. I can hear it breathing.",
	], "player"],
	["first_sense", HERO, [
		"Ugh. Something evil woke up out there. I can feel it pulling at my scales. I should go and look.",
	], "player"],
	["first_accept", "Blacksmith", [
		"Took one on, did you. Good.",
		"Clear the whole board and there's something extra in it for you. My own work.",
	], "blacksmith"],
	["first_fortune", "Fortuneteller", [
		"You'll want to know where the chest is. They always want to know where the chest is.",
		"Choose other spells too if you like. The great ones I can only manage once a town though. I'm not young anymore.",
	], "fortuneteller"],
	["first_smith", "Blacksmith", [
		"Put it on the anvil. Don't touch anything else.",
		"I can make it better quality. Whatever's on it stays on it. Pay more and I'll make one of them stay for good.",
		"Now and then the metal breaks. That's the metal's fault, not mine. You still pay.",
	], "blacksmith"],
	["first_board_cleared", "Blacksmith", [
		"Cleared the whole board, did you. Fine. You'll do.",
		"Here. Best I've got. Pick one. One.",
		"I'll tell them you're ready for the nasty jobs. Nasty pays better.",
	], "blacksmith"],
]
## The first steps a player is made to take (the user's asks, 2026-10-29), a tip's id -> its step's,
## first owed first. A step is put in `inventory.tips` as its tip is queued, so a save that saw the tip
## before there were steps owes none, and struck off once taken (`_step_taken`); while it is owed,
## everything but the next thing to press for it is shaded (`_spotlight`, `_step_target`).
const SPOTLIGHTS := {
	"first_item": "step_equip",
	"first_orb": "step_orb",
	"level_up": "step_point",
}

var towns: TownWorld
var view: MapBuilder
## Everything the player has picked up, loaded from `inventory_path` and written back as it grows.
var inventory: Inventory

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D

## The music and every click, from `_enter_tree` on.
var sounds: Jukebox
## The selected tile's panel against the right edge, its buttons at its foot.
var tile_panel: TilePanel
## The banner, the bounty toast and the level-up fanfare.
var banner: Banner
## A claimed bounty's verdict and a cleared board's options, up over the town.
var rewards: BountyRewards
## The fingers on the screen, by index, where each is now; how far apart two of them were when the map
## last stepped its zoom; and a trackpad's pinch gathered since its last step (`_pinch`).
var _fingers := {}
var _pinch_from := 0.0
var _magnified := 1.0
## Runes found in the descent that is open, so leaving it saves them (`_bank_depths`).
var _cave_runes := 0
## The settlement the player has walked into, in the tile panel's place, and the cell it stands on --
## kept because the map is still clickable behind the page, so the selection is not what the town is.
var town_page: TownPage
var _town_cell := HexMap.NO_CELL
## The tile the player is walking onto to fight on, NO_CELL when they aren't, and whether that fight is a
## run (Farm) rather than the tile's own (Chart).
var _fight_target := HexMap.NO_CELL
var _fight_farms := false
## Whether the last fight to end was a tile fight lost: the first one is the first death's tip.
var _tile_lost := false
## The settlement the player is walking to to go inside (Enter town pressed from afar), NO_CELL when they aren't.
var _town_target := HexMap.NO_CELL
## The charted tile the player stepped onto the fought-for one from: a lost fight runs them back there,
## and a save made while they stand on the uncharted tile puts them there.
var _retreat_cell := HexMap.NO_CELL
## The Nightwalkers' way into the dark still to fight for, the goal last (`MapBuilder.dark_path`): each
## won fight walks on to the next by itself. A loss ends it, and so does anything that stops the next
## fight opening; Retry keeps it.
var _dark_way: Array[Vector2i] = []
## The left-hand pages (`_left_pages`). They share the edge, so only one is ever up.
var bag_page: BagPage
## The heirlooms: a second bag page over `inventory.stash()`, and the one left-hand page that can also
## stand at a town's counter, in the bag's place (`_counter_page`).
var heirloom_page: BagPage
var skills_page: SkillsPage
var bounty_page: BountyList
var settings_page: SettingsPage
var collection_page: CollectionPage
var achievements_page: AchievementsPage
var character_page: CharacterPage
var leaderboard_page: LeaderboardPage
var roster_page: RosterPage
## The run's one `Cloud`: under the root on the player's own save (it outlives the reloads a download
## makes), a child that is off anywhere else.
var cloud: Cloud
## The question the cloud asked (which of two saves to keep), while it is up; null otherwise.
var _cloud_question: Control
## See-through, over the character panel, which takes no mouse itself because it stands over fights
## too. This one comes and goes with the corner buttons.
var _character_button: Button
## The corner buttons (`_corner_buttons`), set by name in `_build_pages` and named by `HOTKEYS`.
var _bag_button: Button
var _skills_button: Button
var _bounty_button: Button
var _settings_button: Button
var _collection_button: Button
var _achievements_button: Button
var _leaderboard_button: Button
var _roster_button: Button
## There while an heirloom is held, and the one corner button a town leaves standing: pressed there it
## swaps the bag and the heirlooms at the counter.
var _heirloom_button: Button
## The bar under the corner buttons while they are a navigation bar, held upright (`_place_corner_row`), and
## the open page's tab in it.
var _nav_bar: Panel
var _nav_tab: StyleBoxTexture
## The card beside the square under the cursor. Its Alt comparison follows the doll of whichever bag
## page is up.
var _item_card: ItemCard
## The player in the top-left corner, over the map and over a fight alike -- or mirrored in the
## top-right while a bag page is up (`_place_character`).
var _character: CharacterPanel
## The side the panel last slid in on, so it slides only when it changes (`_slide_character`).
var _character_slid_right := false

## What the fight going on now has earned, and how it is written down. Never null: between fights
## it is the last fight's, or an empty one, so `ledger.farming` can always be asked.
var ledger: FightLedger
## The fight in front of the map, while there is one.
var _combat: CombatScene
## Whether a save on disk was refused, which stops every write: a refused save is never written over.
var _save_blocked := false
var _ui_layer: CanvasLayer
## Set as the files are replaced under the scene (Reset, a cloud download, a transcension): it keeps
## `_exit_tree` from writing the old ones back.
var _resetting := false
## The black screen between two worlds, while the player is on it; null otherwise.
var _transcend_page: TranscendPage
## Tips earned but not shown yet, and the one that is up. A queued entry of three is the changelog
## (`_show_changelog`), and one of one the comic (`_queue_comic`).
var _tip_queue: Array = []
var _tip_panel: Control
## The shade over all but the button a first step is about, while one is owed (`SPOTLIGHTS`).
var _spot: Spotlight
## Pulses on corner buttons: the id -> `[tween, button]`.
var _flashes := {}
## What the hero's camp paid for the hours the game was shut, while its screen is up; null otherwise.
## Like a fight, it stands over the hidden map on layer 2 and takes the corner buttons away.
var _camp: CampScene
## The levels that pay brought, celebrated once its screen is gone.
var _camp_levels := 0
## The weather and the day over the map.
var _ambient: Ambient
## The badge pointing at the chest a fortuneteller was paid to find (`_sync_chest`).
var _chest_pointer: MapPointer
## The badge pointing at the hero once they are off screen; a press brings the camera back (`_find_hero`).
var _hero_pointer: MapPointer
## Floating at the map's foot while a walk can be cut short (`_on_stop_pressed`).
var _stop_button: Button
var _camera_glide: Tween
## The red light at the map's edge the way this world's Gollux cave lies, until it is seen.
var _cave_sense: CaveSense
## The fortuneteller's aimed spell while its land is being chosen: which one it is ("" when nobody is
## choosing), what the click will cost, and the town whose drawer it is spent out of.
var _aiming := ""
var _aim_price := 0.0
var _aim_town := TownWorld.NO_SPOT


## Closing the window writes the save, so the hour it was shut is the hour a camp pays from. Signed in,
## the cloud closes the scene (which banks and writes the rest), uploads, and only then quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_inventory()
		if cloud != null and cloud.signed_in() and not _save_blocked and not _resetting:
			cloud.leave.call_deferred(self)
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and cloud != null:
		cloud.push()
	elif (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) \
			and OS.has_feature("web"):
		_keep_run()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Answered wherever Escape is -- a fight, the bag, a question, this scene -- by being Escape.
		for down: bool in [true, false]:
			var back := InputEventAction.new()
			back.action = "ui_cancel"
			back.pressed = down
			Input.parse_input_event(back)


## Whether the inventory may be written now: never over a refused save or a reset, and never while the
## black screen is up, where a game closed has not transcended.
func _may_save() -> bool:
	return inventory != null and not _resetting and not _save_blocked and _transcend_page == null


## The one way this scene writes the inventory, and whether it was written (`_may_save`). The pages and
## the ledger write their own, and none of them is up on the black screen.
func _save_inventory() -> bool:
	return _may_save() and inventory.save(inventory_path)


## What is held and not yet on disk, written now, and safe to write again: the web build's one chance,
## whose tab closes with no close request and no `_exit_tree`. A farm run's finds are in the inventory
## as they land (`FightLedger`) and a descent's depths are each a most-ever (`_bank_depths`); a run's
## kills still wait for its end, since `bank_kills` counts a fight's whole tally once.
func _keep_run() -> void:
	if _combat != null and _combat.fight != null and _combat.fight.dungeon:
		_bank_depths()
	else:
		_save_inventory()


## Before the scene's own children enter, so the jukebox hears every button made.
func _enter_tree() -> void:
	sounds = Jukebox.new()
	add_child(sounds)


func _ready() -> void:
	# A headless run pointed nowhere -- the landing page's straight-through, a quick check that the
	# game starts -- plays on scratch files, so code half-way through a change can never load, rewrite
	# or upload the player's own saves (their settings and account go with the inventory's path).
	if DisplayServer.get_name() == "headless":
		if inventory_path == Inventory.SAVE_PATH:
			inventory_path = HEADLESS_INVENTORY
		if map_path == MapSave.SAVE_PATH:
			map_path = HEADLESS_MAP
	# A real window is drawn at its own pixels, and every scale in it is a whole number of them: the
	# project's stretch would blow the default window up by a fraction on anything but its own size. A
	# headless run keeps the stretch, whose window every test lays out against.
	if DisplayServer.get_name() != "headless":
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# The player's own settings only beside the player's own save: a test or a screenshot sees the
	# defaults and writes nothing. Before the scale is picked, so a window put full screen is measured
	# full (the landing page has done it already on a real start; this is for a run straight in).
	Settings.path = Settings.SAVE_PATH if inventory_path == Inventory.SAVE_PATH else ""
	Settings.load_settings()
	Settings.apply_window()
	Settings.apply_audio()
	if ui_scale <= 0.0:
		ui_scale = UITheme.pick_scale(get_viewport().get_visible_rect().size)
	if zoom <= 0.0:
		zoom = roundf(ZOOM_PER_UI * ui_scale)
	map.ui_scale = ui_scale
	# A phone's back button is Escape (`_notification`), never a way out of the game.
	get_tree().quit_on_go_back = false
	sounds.play_music(Jukebox.IDLE)
	TownServices.show_all = Settings.show_all_services()
	# Before either save is judged, so a refusal stops the cloud as well (`_refuse_save`), and before
	# anything of this start-up is written (`Cloud.launched`).
	_find_cloud()
	# No file at all is a first run; a file that cannot be honoured stops everything (`_refuse_save`):
	# a world or an empty bag made in its place would be written over it on the first step or kill.
	var problem: Array = []
	inventory = Inventory.load_from(inventory_path, problem)
	_unread(inventory_path, inventory, problem)
	if not problem.is_empty():
		_refuse_save("inventory", inventory_path, str(problem[0]))
		return
	inventory.traded.connect(sounds.coins.play)
	# What every card writes a unique's numbers at, from the first card drawn.
	UniqueTable.ranks = Achievements.ranks(inventory)
	# Before anything below saves over it: the hour the player left is what the camp pays from.
	var left_at := inventory.saved_at
	ledger = FightLedger.new(inventory, inventory_path)
	var save := MapSave.load_from(map_path, problem, MapSave.fingerprint(map.tileset))
	_unread(map_path, save, problem)
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
	# What the Ring of Walls asks of the map, said before anything is drawn, charted or paid: a saved map
	# draws the rubble of the walls that fell, which stood every `step` rings.
	var step := (MapBuilder.RING_OF_WALLS_STEP if Curses.RING_OF_WALLS in inventory.curses
			else MapBuilder.WALL_STEP)
	if save != null:
		view = MapBuilder.restore(map, TownWorld.from_dict(save.towns), save, step)
	else:
		view = MapBuilder.create(map, TownWorld.generate(used_world_seed, map_origin), map_origin,
				used_map_seed)
	view.wall_step = step
	towns = view.towns
	_settle_homeland()
	print("%s world seed %d (%d towns), map seed %d, first town at cell %s" % [
			"Loaded" if save else "New", used_world_seed, towns.towns().size(), used_map_seed,
			view.start_town - map_origin])
	map.tile_clicked.connect(_on_tile_clicked)
	map.dragged.connect(_on_map_dragged)
	map.cell_aimed.connect(_on_cell_aimed)
	view.arrived.connect(_on_player_arrived)
	view.dark_reach = func() -> int: return inventory.dark_reach()
	map.player.move_speed = func() -> float:
		var speed := float(inventory.stats().get("move_speed", 0.0))
		# An overfull bag slows the whole pace, whatever the boots add to it.
		return (100.0 + speed) * Inventory.ENCUMBERED_SPEED - 100.0 if inventory.encumbered() else speed
	# Before the interface, which is what decides whether the heirlooms' button stands in the corner.
	_credit_walls()
	_build_ui()
	# A first run opens on the comic, before the changelog and every tip; only on the player's own save,
	# so a test or a screenshot opens on the map.
	if inventory_path == Inventory.SAVE_PATH and Comic.owed(inventory):
		_queue_comic()
	if OS.has_feature("web") and not Settings.path.is_empty():
		_show_changelog()
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
	# Last, over everything the rest of start-up put up: the hours the game was shut, paid.
	_camp_while_away(left_at)
	# Then the cloud: what this start-up wrote goes up, or a newer save comes down and the scene reloads.
	cloud.sync.call_deferred(true)


## The run's one cloud, found again after a reload, or made: under the root on the player's own save,
## where quitting waits for it (`_notification`), and a child that is off in a test or a screenshot.
func _find_cloud() -> void:
	var real := inventory_path == Inventory.SAVE_PATH
	cloud = get_tree().root.get_node_or_null(Cloud.NODE) as Cloud if real else null
	if cloud == null:
		cloud = Cloud.new(Cloud.save_path() if real else "")
		if real:
			cloud.name = Cloud.NODE
			get_tree().root.add_child.call_deferred(cloud)
		else:
			add_child(cloud)
	if real:
		get_tree().set_auto_accept_quit(false)
	# Whatever an earlier scene refused, this one judges its own files (`_refuse_save`).
	cloud.blocked = false
	# Before anything of this start-up is written: what the device held is what it is judged by.
	cloud.launched()
	# Nor on the walk to a fight, which would open under the question (`_on_player_arrived`).
	cloud.calm = func() -> bool:
		return (is_inside_tree() and _combat == null and _transcend_page == null and _camp == null
				and _cloud_question == null and not _save_blocked and not _resetting
				and _fight_target == HexMap.NO_CELL and _dark_way.is_empty())
	cloud.replaced.connect(_on_cloud_replaced)
	cloud.asked.connect(_on_cloud_asked)


## The cloud's save is on disk now: nothing of this one may be written over it, and the scene loads it.
func _on_cloud_replaced() -> void:
	_resetting = true
	print("Loaded the cloud's save, revision %d" % cloud.revision)
	_reload()


## The scene loaded again from the files as they now stand. A test stands this scene under the root
## rather than as the current one, and has nothing to reload.
func _reload() -> void:
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Two saves to choose between: asked over the whole window.
func _on_cloud_asked() -> void:
	if _cloud_question != null:
		return
	_on_left_page_closed()
	_cloud_question = CloudQuestion.new(cloud.question, ui_scale)
	_cloud_question.answered.connect(func(keep_cloud: bool) -> void:
		_cloud_question.queue_free()
		_cloud_question = null
		if keep_cloud:
			cloud.keep_cloud()
		else:
			cloud.keep_device())
	_ui_layer.add_child(_cloud_question)


## Points the badge at the chest a fortuneteller was paid to find, for as long as it stands: a chest
## goes when its tile is charted, and the badge and what was written down go with it. Nothing points
## at a chest for nothing any more.
func _sync_chest() -> void:
	var spot := FortuneTeller.chest(inventory.fortunes)
	var cell := spot - view.origin if spot != TownWorld.NO_SPOT else HexMap.NO_CELL
	if cell != HexMap.NO_CELL and not view.has_chest(cell):
		inventory.fortunes.erase(FortuneTeller.CHEST)
		_save_inventory()
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
	var save := view.to_save()
	# Standing on a tile only being fought for: a game shut now comes back where the walk set out from,
	# as a lost fight would have left it.
	if not view.charted(save.player_cell):
		save.player_cell = _retreat_cell
	save.save(map_path)


## A loader that handed back nothing and said nothing about a file that is there has failed some way it
## did not foresee, and that is a refusal like any other: only a missing file is a first run.
static func _unread(path: String, loaded: Object, problem: Array) -> void:
	SafeFile.recover(path)
	if loaded == null and problem.is_empty() and FileAccess.file_exists(path):
		problem.append("it could not be read")


## A save that cannot be honoured, `what` being "map" or "inventory". Nothing is generated, written or
## built, so nothing can reach either save, and the player is told what happened and where the file is.
func _refuse_save(what: String, path: String, reason: String) -> void:
	_save_blocked = true
	# Nor may the cloud move either file: a refused one sent up would come down on every other device.
	cloud.blocked = true
	# Nothing was built, so there is nothing for a frame, a key or the wheel to reach.
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
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
	var width := _notice_width()
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


## How wide a panel of plain words may be, in panel pixels.
func _notice_width() -> float:
	return minf(get_viewport().get_visible_rect().size.x / ui_scale - REFUSAL_MARGIN, REFUSAL_WIDTH)


## The camera keeps up with the walking player and otherwise moves only where it is dragged. The play
## clock is wound on here: every frame the game is open counts.
func _process(delta: float) -> void:
	inventory.play_seconds += delta
	if tile_panel != null:
		tile_panel.watch_bag()
	_refresh_bag_room()
	if view != null and view.walking:
		camera.position = _clamp_to_map(map.player.position)
	if _hero_pointer != null:
		# None while walking (the camera follows, and `player_cell` is already the tile walked to), nor
		# under a page or a town, which cover the map it would stand on.
		var away := view.walking or _left_page_up() or town_page.visible
		_hero_pointer.target = HexMap.NO_CELL if away else view.player_cell
		_hero_pointer.room = _map_room()
	if _stop_button != null:
		# In the badge's place, which is never up during a walk, and like it not under a page.
		_stop_button.visible = map.player.can_stop() and not _left_page_up()
		var room := _map_room()
		_stop_button.position = (Vector2(room.get_center().x, room.end.y - MapPointer.MARGIN)
				- _stop_button.size * ui_scale / 2.0).round()
	if _cave_sense != null:
		_cave_sense.room = _map_room()
	if banner != null:
		banner.tick(delta)
	if bag_page != null:
		_spotlight()


## Whether a page's question, the fortuneteller's answer or the cloud's question stands over the window.
func _popup_up() -> bool:
	return _cloud_question != null \
			or (bag_page != null and (bag_page.asking() or heirloom_page.asking() or town_page.telling()))


## Built in code so the scene file stays untouched while the Godot editor has it open.
func _build_ui() -> void:
	# Before the first button exists: it hands each one the pointing hand as it joins the tree.
	Cursors.install(get_tree(), int(ui_scale))
	var layer := CanvasLayer.new()
	layer.name = "UI"
	# Over a fight's (2), so the bag can be opened over one. The character's layer is a 3 as well and is
	# added after this one, so the cards, tips and banners on it still stand over the pages.
	layer.layer = 3
	add_child(layer)
	_ui_layer = layer
	# First on the layer, so the map's pointers stand over its light as the panels do.
	_cave_sense = CaveSense.new(map, view)
	layer.add_child(_cave_sense)
	_chest_pointer = MapPointer.new(map, view, ui_scale,
			MapPointer.cut(MapBuilder.CHEST_TEXTURE, MapBuilder.CHEST_REGION))
	layer.add_child(_chest_pointer)
	_hero_pointer = MapPointer.new(map, view, ui_scale, load(Characters.path(inventory.character, "badge")),
			"Find the hero", _find_hero)
	layer.add_child(_hero_pointer)
	# Floating at the map's foot, where the hero's badge stands (`_process`), and under every panel as it is.
	_stop_button = UITheme.button("Stop", "LightButton", "Stop on the next tile")
	_stop_button.theme = UITheme.theme()
	_stop_button.scale = Vector2(ui_scale, ui_scale)
	_stop_button.pressed.connect(_on_stop_pressed)
	_stop_button.hide()
	layer.add_child(_stop_button)

	tile_panel = TilePanel.new(layer, map, view, inventory, ui_scale)
	tile_panel.room = _pages_room
	tile_panel.mods_of = _mods_of
	tile_panel.closed.connect(_on_close_pressed)
	tile_panel.chart_button.pressed.connect(_on_chart_pressed)
	tile_panel.move_button.pressed.connect(_on_move_pressed)
	tile_panel.farm_button.pressed.connect(_on_farm_pressed)
	# Visiting a town is being there: pressed from afar it walks the player there first
	# (`_town_target`), as Chart and Farm do.
	tile_panel.town_button.pressed.connect(_on_town_pressed)
	tile_panel.cave_button.pressed.connect(_on_cave_pressed)

	_build_character()
	_build_pages(layer)
	_wear_character()

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui.call_deferred()
	# A new player has nothing for either corner button to open yet.
	_show_corner(true)


## The character panel, on a layer of its own. Its 3 is the UI layer's too and it comes after that one,
## so it stands over the pages and over a fight (`CombatScene` is a CanvasLayer on 2). It takes no
## mouse input anywhere, so standing over a fight costs the player no swings.
func _build_character() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Character"
	layer.layer = 3
	add_child(layer)
	_character = CharacterPanel.new()
	_character.scale = Vector2(ui_scale, ui_scale)
	_character.position = CHARACTER_EDGE
	layer.add_child(_character)
	banner = Banner.new(ui_scale, _banner_top, _popup_up)
	layer.add_child(banner)
	_sync_character()


## Where a fight's top column ends, in window pixels, which the banner and the toast hang under: off
## a fight the window's top, or held upright under the character panel they would cover.
func _banner_top() -> float:
	return _combat.hud.hud_bottom() if _combat != null else _fight_top()


## Whether the character panel has the top-right corner: a bag page or the skill tree is up across a wide
## window, out of a town, and the panel stands mirrored on the other side of it, so it stays in view.
func _character_right() -> bool:
	var page := _left_page()
	# Nor beside the tile panel, which has that edge: a rune in a finger's hand has both up (`_on_cell_aimed`).
	return (page is BagPage or page == skills_page) and not town_page.visible and not _narrow() \
			and not tile_panel.panel.visible


## The character panel in its corner -- the top-left, or mirrored in the top-right (`_character_right`),
## there under a fight's Terminate flag -- shown unless a page covers it or the black screen is up, with
## the see-through button over it and a fight's gems flying to it. Run by `_layout_ui` and `_show_corner`.
func _place_character() -> void:
	var right := _character_right()
	var safe := UITheme.safe_rect(get_viewport())
	_character.mirrored = right
	_character.position = safe.position + CHARACTER_EDGE
	if right:
		# Mirrored, the panel's position is its right edge.
		_character.position.x = safe.end.x - CHARACTER_EDGE.x
		if _combat != null:
			_character.position.y = _combat.hud.corner_bottom() + FightHud.HUD_MARGIN
	_character.visible = _transcend_page == null and (right or _left_page() == null)
	var drawn := _character.get_transform() * Rect2(Vector2.ZERO, _character.size)
	_character_button.position = drawn.position
	_character_button.size = drawn.size
	if _combat != null:
		_combat.xp_target = _character.xp_point()
	_slide_character.call_deferred()


## Once a frame, after every placing in it: a panel that came out on the other side slides in from that
## side's edge. Settled at the frame's end, so a page closed on the way to another bag page -- which puts
## the panel back on the left for a moment -- does not slide it in twice.
func _slide_character() -> void:
	if _character.mirrored == _character_slid_right:
		return
	_character_slid_right = _character.mirrored
	if not _character.visible:
		return
	var drawn := _character.get_transform() * Rect2(Vector2.ZERO, _character.size)
	var away := get_viewport_rect().size.x - drawn.position.x if _character.mirrored else -drawn.end.x
	Juice.glide(_character, _character.position + Vector2(away, 0.0))


## Puts the panel back in step with the inventory: gems still in the air when a fight closed never arrive.
func _sync_character() -> void:
	_character.set_state(inventory.level, inventory.xp)
	_show_damage()


## The panel's damage line: a click and a second, as the character page heads itself. Over a fight
## they are that fight's, so a tile's modifiers and the curses are in them; anywhere else, a fight armed
## the way one would be. `announce` has a figure that moved say so (`CharacterPanel.set_damage`): after
## a save, which is where gear, skills and crafting land -- never as a fight opens or closes, whose
## tile is what moved them.
func _show_damage(announce := false) -> void:
	var fight: Encounter = _combat.fight if _combat != null and _combat.fight != null \
			else CharacterPage.armed(inventory, inventory.stats())
	_character.set_damage(fight.average_blow(false), fight.per_second(), announce)


## The left-hand pages and the corner buttons that open them, built before the first `_layout_ui`,
## which places all of them.
func _build_pages(layer: CanvasLayer) -> void:
	# Under the buttons, and taking the presses that land between them, which would otherwise reach the
	# map or the fight under the bar.
	# Edged as the brown button's face is: the outline, then its lit row, along the top; the tab lit on
	# the top and left and shaded on the right, standing `NAV_RISE` out of the bar.
	_nav_bar = Panel.new()
	_nav_bar.add_theme_stylebox_override("panel", _nav_box(["a", "l", "b"], 0))
	_nav_bar.scale = Vector2(ui_scale, ui_scale)
	_nav_tab = _nav_box([".aaaa.", "ahhhha", "ahllba", "ahllba"], 2)
	_nav_tab.expand_margin_top = NAV_RISE
	_nav_bar.hide()
	layer.add_child(_nav_bar)
	# In the order they join the layer. Each tooltip is the page's own name.
	for made: Array in [
			["_skills_button", TREE_ICON, SkillsPage.TITLE, _on_skills_pressed],
			["_roster_button", ROSTER_ICON, RosterPage.TITLE, func() -> void: _toggle_left_page(roster_page)],
			["_bag_button", CHEST_ICON, "Items", _on_bag_pressed],
			["_bounty_button", SCROLL_ICON, "Bounties", _on_bounty_pressed],
			["_settings_button", COG_ICON, "Settings", _on_settings_pressed],
			["_collection_button", BOOK_ICON, "Collection", _on_collection_pressed],
			["_achievements_button", ROSETTE_ICON, "Achievements", _on_achievements_pressed],
			["_leaderboard_button", PODIUM_ICON, "Leaderboard",
					func() -> void: _toggle_left_page(leaderboard_page)],
			["_heirloom_button", HEIRLOOM_ICON, "Heirlooms", _on_heirlooms_pressed]]:
		var button := UITheme.icon_button(load(made[1]), made[2], ui_scale)
		button.pressed.connect(made[3])
		layer.add_child(button)
		set(made[0], button)
	# Every corner button gets one, hidden: `_mark_new` says which pages have something new.
	for button in _corner_buttons():
		var pip := TextureRect.new()
		pip.name = "New"
		pip.texture = load(NEW_PIP)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pip.offset_left = PIP_AT.x
		pip.offset_top = PIP_AT.y
		pip.hide()
		button.add_child(pip)
	_character_button = Button.new()
	_character_button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_character_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_character_button.tooltip_text = "Character"
	_character_button.pressed.connect(_on_character_pressed)
	# The frame is this button's face, a bare one, so it lights under the mouse as a bare mark does
	# (`_show_corner` puts it out when the button stops taking the mouse).
	_character_button.mouse_entered.connect(func() -> void: _character.modulate = UITheme.BARE_HOVER)
	_character_button.mouse_exited.connect(func() -> void: _character.modulate = Color.WHITE)
	layer.add_child(_character_button)
	# Passes its press up, so the bar opens the character page as the rest of the panel does -- and in a
	# fight, where the button takes no mouse, on to the swing (`_show_corner`).
	_character.xp_hover.mouse_filter = Control.MOUSE_FILTER_PASS
	_character_button.add_child(_character.xp_hover)
	character_page = CharacterPage.new(inventory, ui_scale)
	character_page.rename_pressed.connect(_on_rename_pressed)
	# Something new hovered on either log, or the page closed over it, is seen, and that is kept.
	collection_page = CollectionPage.new(inventory, ui_scale)
	collection_page.seen.connect(_save_inventory)
	achievements_page = AchievementsPage.new(inventory, ui_scale)
	achievements_page.seen.connect(_save_inventory)
	# Everything that changes the player ends in a save, so a save is where an achievement is noticed,
	# where a piece put on, taken off or crafted in the bag mid-fight reaches the fight, where the
	# character panel's damage line moves (after the fight it may read is armed again) and where the
	# corner buttons' red pips change.
	for heard: Callable in [_check_achievements, _rearm, _show_damage.bind(true), _mark_new]:
		inventory.save_written.connect(heard, CONNECT_DEFERRED)
	skills_page = SkillsPage.new(inventory, inventory_path, ui_scale)
	skills_page.changed.connect(func() -> void: _pulse(_skills_button, "skill_point", _skill_point_free()))
	bag_page = BagPage.new(inventory, inventory_path, ui_scale)
	heirloom_page = BagPage.new(inventory, inventory_path, ui_scale, true)
	bounty_page = BountyList.new(inventory, view, inventory_path, ui_scale)
	settings_page = SettingsPage.new(ui_scale)
	settings_page.cloud = cloud
	settings_page.inventory = inventory
	settings_page.inventory_path = inventory_path
	# Each corner button's key: its picture on the button's tip card (`TipCard.KEY`), and on the
	# settings' controls screen beside the page's name, which is the button's tooltip.
	for key: int in HOTKEYS:
		var button: Button = get(HOTKEYS[key])
		var named := OS.get_keycode_string(key).to_lower()
		button.set_meta(TipCard.KEY, named)
		settings_page.hotkeys.append([named, button.tooltip_text])
	settings_page.reset_pressed.connect(_on_reset_pressed)
	settings_page.uniques_toggled.connect(_show_corner.bind(true))
	settings_page.chests_toggled.connect(view.redraw_chests)
	# Dev only: an empty purse becomes 10, so the button always does something.
	settings_page.cash_pressed.connect(func() -> void:
		inventory.gold = maxf(inventory.gold, 1.0) * 10.0
		_save_inventory())
	# Dev only: a skill point is a level (`Skills.earned`), never stored, so ten points are ten levels.
	# The tips put the star up the first time, and light it.
	settings_page.points_pressed.connect(func() -> void:
		inventory.level += 10
		_save_inventory()
		_sync_character()
		_check_tips())
	# The town page stands on the other edge, but it is closed by the same X rule and hidden by the
	# same fight, so it is built and wired here with the pages that share the left one.
	town_page = TownPage.new(inventory, inventory_path, ui_scale)
	town_page.view = view
	town_page.tab_changed.connect(_on_town_tab_changed)
	town_page.chest_bought.connect(func(_cell: Vector2i) -> void: _sync_chest())
	town_page.spell_aimed.connect(_on_spell_aimed)
	town_page.towns_revealed.connect(_save_map)
	town_page.transcend_pressed.connect(_on_transcend_pressed)
	town_page.xp_claimed.connect(_on_xp_absorbed)
	town_page.bounty_accepted.connect(_check_tips)
	# A bounty's piece is announced as a body's would be: only a unique the log has never held.
	town_page.item_claimed.connect(func(item: Item) -> void:
		if _is_new_unique(item):
			banner.unique(item))
	# A bounty given up on the journal frees the board standing open on the other edge.
	bounty_page.abandoned.connect(town_page.redraw)
	bounty_page.town_shown.connect(_show_town)
	# What the counter does goes straight to the bag: a purchase reaches the purse and the grid by the
	# same redraw (`offer`; the bag draws nothing of the shelf piece itself). Back the other way, the
	# counter redraws around whatever the bag has open, so a piece sold to make room unlocks the Buy
	# that was greyed out for a full bag. An orb in the bag's hand works on a shelf piece too; the bag
	# still does the spending and saving. Both bag pages are wired alike, and only the one that is up
	# ever speaks (`_counter_page`): a hidden page has nothing open and no orb in hand, and standing it
	# at the counter (`shop`) forgets any offer it overheard.
	town_page.craft_held = func(item: Item, written: Callable) -> void:
		_counter_page().craft_held(item, written)
	for page: BagPage in [bag_page, heirloom_page]:
		town_page.offer_changed.connect(page.offer)
		page.selection_changed.connect(town_page.bag_changed)
		page.held_changed.connect(town_page.orb_held)
		page.laid_out.connect(_place_corner)
	settings_page.laid_out.connect(_place_corner)
	leaderboard_page = LeaderboardPage.new(cloud, func() -> int: return inventory.dungeon_floors, ui_scale)
	roster_page = RosterPage.new(inventory, inventory_path, ui_scale)
	roster_page.changed.connect(_wear_character)
	for page: Control in _left_pages() + [town_page]:
		page.hide()
		page.closed.connect(_on_left_page_closed)
		layer.add_child(page)
		# In from its own edge and back out to it, whatever shows or hides it (`Juice.slides`).
		Juice.slides(page, page != town_page)
		page.visibility_changed.connect(sounds.page_slid)
	Juice.slides(tile_panel.panel, false)
	tile_panel.panel.visibility_changed.connect(sounds.page_slid)
	# On the character's layer, over the pages and over a fight (layer 2), so a find in the loot
	# popup or under the verdict gets its card too. It takes no mouse, so it costs no swings.
	var top := _character.get_parent()
	_item_card = ItemCard.new(ui_scale)
	_item_card.equipment = inventory.equipment
	top.add_child(_item_card)
	for page: BagPage in [bag_page, heirloom_page]:
		page.crafted.connect(_item_card.shine)
		page.held_changed.connect(func(orb: String) -> void: _item_card.held = orb)
	# The bag saved the orb's work before saying so, so striking off the step is a write of its own.
	bag_page.crafted.connect(func(_orb: String) -> void:
		if inventory.tips.has("step_orb"):
			inventory.tips.erase("step_orb")
			_save_inventory())
	# A skill point lights the card as an orb does, in its node's colour.
	skills_page.learned.connect(_item_card.flash)
	# A rune in the bag's hand goes on a tile: the map is aimed at while one is held (`_rune_on`).
	bag_page.held_changed.connect(func(orb: String) -> void:
		if _aiming.is_empty():
			map.aim_radius = 0 if RuneTable.has(orb) else -1)
	# Every `tooltip_text` there is, on the same cream card and the same layer.
	top.add_child(TipCard.new(ui_scale))
	rewards = BountyRewards.new(town_page, _item_card, ui_scale)
	top.add_child(rewards)
	town_page.bounty_paid.connect(rewards.show_paid)
	town_page.choice_asked.connect(rewards.show_choice)
	# The smith's word, over the options, the first time a board is cleared.
	rewards.choice_shown.connect(_check_tips)


func _update_weather() -> void:
	var ground := map.ground_layer.get_cell_tile_data(view.player_cell)
	_ambient.set_env(ground.get_custom_data("env") if ground != null else "")


## Whether this find fills a slot in the collection log: a unique never logged. Every find reaches the
## log as it lands, so a second copy in the same fight is already there.
func _is_new_unique(item: Item) -> bool:
	return not item.unique.is_empty() and not inventory.uniques_found.has(item.unique)


## The rune in the bag's hand pressed on a tile of the map, which is aimed at while one is held: spent
## there where the tile is ground a farm run can be fought on and the rune does something to it
## (`BagPage.rune_on`, which saves), and the tile panel says what it did if it shows that tile.
func _rune_on(cell: Vector2i) -> void:
	if _combat != null or not view.can_farm_ground(cell) \
			or not bag_page.rune_on(view.origin + cell, TileMods.farmable(_mods_of(cell))):
		return
	if map.selected_cell == cell:
		tile_panel.show_runes(cell)
		_layout_ui()


## The tile panel is a full-height column against the right edge, its buttons at its foot. The
## left-hand pages lay themselves out against the other edge. Held upright, every page stands over the
## corner row, one at a time -- but a town, whose page stands under the bag.
func _layout_ui() -> void:
	_place_character()
	var room := _pages_room()
	var left := room
	town_page.area = room
	var tabbed := _narrow() and _town_cell != HexMap.NO_CELL
	bag_page.tabbed = tabbed
	heirloom_page.tabbed = tabbed
	if tabbed:
		# The bag over the counter, its doll a tab of its own (the user's sketch, 2026-10-29): the counter
		# gives up what the bag needs, but keeps what its own tabs and buttons need.
		var low := floorf(minf(room.size.y * TOWN_SPLIT, room.size.y - _counter_page().least_height()))
		low = maxf(low, (town_page.get_child(0) as Control).get_combined_minimum_size().y * ui_scale
				+ 2 * UITheme.EDGE * ui_scale)
		town_page.area = Rect2(room.position.x, room.end.y - low, room.size.x, low)
		left = Rect2(room.position, Vector2(room.size.x, room.size.y - low))
	for page in _left_pages():
		page.set("area", left)
	tile_panel.place()
	for page in _left_pages():
		page.call("layout")
	town_page.layout()
	_place_corner()
	if _combat != null:
		_combat.hud.hud_top = _fight_top()
		_combat.hud.hud_foot = _pages_room().end.y


func _on_tile_clicked(cell: Vector2i, info: Dictionary) -> void:
	# A tile chosen has the screen to itself: any page closes, as opening a page drops the tile
	# (`_toggle_left_page`). Not in a town, whose page keeps the map's edge and the tile panel hidden.
	# Nor while a rune in the bag's hand aims the map (a finger's first tap on a tile, `_on_cell_aimed`):
	# the bag put away would put the rune down, so the panel stands with it -- and in front of it, since
	# held upright both are sheets along the foot and the pages are drawn after the panel.
	if map.aim_radius >= 0:
		tile_panel.panel.move_to_front()
	elif _town_cell == HexMap.NO_CELL and _left_page_up():
		_on_left_page_closed()
	tile_panel.update_buttons()
	# The map is still clickable behind an open town page, which has this edge until the player leaves
	# it -- and `_close_town` is what brings the panel back, already filled in for whatever was clicked.
	tile_panel.panel.visible = _town_cell == HexMap.NO_CELL
	_layout_ui()
	tile_panel.fill(cell, info)
	# The rows are filled after `_layout_ui` ran, and the level line can be wider than the rows that
	# pin the panel's width, so the panel is measured again now that it holds everything.
	_layout_ui()
	_keep_above_sheet(cell)


## Dragging moves the camera the other way, so the map follows the cursor.
func _on_map_dragged(relative: Vector2) -> void:
	camera.position = _clamp_to_map(camera.position - relative / camera.zoom.x)


## The wheel: one whole step of zoom, about the point under the cursor so it stays put on screen.
## Never in a town: the map behind its pages stays as it was.
func _zoom_at(screen_point: Vector2, step: float) -> void:
	if town_page.visible:
		return
	var to := clampf(camera.zoom.x + step, ZOOM_MIN, ZOOM_MOST * ui_scale)
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


## Chart: the selected tile's own fight, a lineup against a clock, walked onto first. Winning charts
## the tile; losing leaves the map exactly as it was, free to try again.
func _on_chart_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_chart(cell) or inventory.encumbered():
		return
	# Not on it yet: walk onto it, and the fight opens on arrival. Already on it is a Retry. Further out --
	# into the dark under the Nightwalkers, across seen land under distant charting (the fourth wall's) --
	# onto the first tile of the way, and the rest follow as each is won.
	if view.player_cell != cell:
		var way := view.dark_path(cell)
		_dark_way = way.slice(2)
		_walk_to_fight(way[1], false)
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


## Farm: the selected tile's enemies coming forever, with no clock and nothing riding on it. It takes
## a tile already taken, so nothing about the map can change.
func _on_farm_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_farm(cell) or not inventory.farm_unlocked() or inventory.encumbered():
		return
	if view.player_cell != cell:
		_walk_to_fight(cell, true)
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	var variant := view.area_variant(cell)
	print("Farming %s, %s (%s, %s)" % [view.name_of(cell), cell, env, variant])
	# The runes working on the tile (`RuneTable`): their modifiers beside its own, a level a Depth, and
	# the Ascent. A farm run alone carries them -- never the camp.
	var work := inventory.rune_work(view.origin + cell)
	var fight := Encounter.farm(cell, env, variant, _mods_of(cell) + RuneTable.mods_of(work),
			RuneTable.deeper(work))
	fight.ascended = RuneTable.ascended(work)
	_open_fight(fight, cell, true)


## Sends the player onto `cell` -- a charted tile to farm, or the uncharted one to chart, which they
## step onto from the charted tile beside it -- and the fight opens when they arrive (`_on_player_arrived`).
func _walk_to_fight(cell: Vector2i, farming: bool) -> void:
	_fight_target = cell
	_fight_farms = farming
	# The charted tile they step onto it from, not where the walk began: never a tile of a walk into
	# the dark, which is not theirs until the fight is won.
	_retreat_cell = view.player_cell if farming else view.chart_from(cell)
	var route: Array[Vector2i] = view.move_to(cell) if farming else view.walk_onto(cell)
	print("Walking onto %s to %s it, %d tile(s) away" % [cell, "farm" if farming else "chart", route.size()])
	tile_panel.update_buttons()


## Why the hero holds no camp in this world, or "" where they do. Two curses say so in their text.
func _cannot_camp() -> String:
	if Curses.NO_REST in inventory.curses:
		return "This world is under No Rest: no camp can be set up in it."
	if Curses.BERSERKERS_WORLD in inventory.curses:
		return "This is a Berserker's World: no camp can be set up in it."
	return ""


## The camp nobody sets up: the hours since the save was written at `left_at`, spent on the best ground
## taken so far (`MapBuilder.best_farm`), paid now and shown over the hidden map the way a fight stands
## there. Worked out from the gear the hero stands up in, which the shut hours cannot have changed. A
## camp worth nothing (a first run, a minute away, a world under No Rest) is not shown at all.
func _camp_while_away(left_at: float) -> void:
	var cell := view.best_farm()
	var now := Time.get_unix_time_from_system()
	if left_at <= 0.0 or now - left_at < CAMP_LEAST or cell == HexMap.NO_CELL \
			or not _cannot_camp().is_empty():
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	# Armed exactly as `_open_fight` arms one, and for the same reason: a camp is that fight. Its bodies
	# drop what a run's do (the user's, 2026-10-11) -- but nothing while a scripted first find is still
	# owed: they are not counted towards it, and a stray orb or node would spend the script unseen.
	var fight := Encounter.farm(cell, env, view.area_variant(cell), _mods_of(cell))
	_arm(fight)
	var drops := inventory.promised().is_empty()
	if drops:
		_hand_drops(fight)
	var camp := Camp.make(cell, view.name_of(cell), fight, left_at,
			WallUnlocks.camp_hours(inventory.walls_ever()))
	var earned := Camp.earned(camp, now)
	if float(earned[Camp.GOLD]) <= 0.0 and int(earned[Camp.XP]) <= 0:
		return
	inventory.gold += float(earned[Camp.GOLD])
	_camp_levels = inventory.add_xp(int(earned[Camp.XP]))
	var found := _bank_camp_finds(Camp.finds(fight, int(earned[Camp.KILLS]) if drops else 0))
	_save_inventory()
	print("Camped %s on %s, %s: %s gold, %d experience, %d driven off, %d find(s) kept and %d left"
			% [Camp.spell_time(float(earned["seconds"])), view.name_of(cell), cell,
				BigNumber.format(float(earned[Camp.GOLD])), int(earned[Camp.XP]), int(earned[Camp.KILLS]),
				found[Camp.ITEMS].size(), int(found["left"])])
	_camp = CampScene.new()
	_camp.broke_camp.connect(_break_camp)
	add_child(_camp)
	_camp.begin(camp, earned, env, view.area_variant(cell), ui_scale, found[Camp.ITEMS], found[Camp.ORBS],
			int(found["left"]))
	_cover_map()


## What a camp's bodies dropped (`Camp.finds`) into the bag, each find asked of the player's own rule
## as a fight asks it (`Inventory.leaves_behind`) and one left behind salvaged as a fight's is. Nothing
## is written here: the camp's one save follows. Returns what was kept, `Camp.ITEMS` and `Camp.ORBS`,
## and how many finds were `left`.
func _bank_camp_finds(found: Dictionary) -> Dictionary:
	var kept: Array[Item] = []
	var left := 0
	# A run's ledger writes nothing of its own, which is what a camp's hundred finds want.
	ledger.farming = true
	for item: Item in found[Camp.ITEMS]:
		if inventory.leaves_behind(item):
			left += 1
			_on_loot_autodiscarded(0, item)
		else:
			kept.append(item)
			_on_loot_dropped(0, item)
	for orb: String in found[Camp.ORBS]:
		for one in int(found[Camp.ORBS][orb]):
			_on_orb_gained(orb)
	ledger.farming = false
	return {Camp.ITEMS: kept, Camp.ORBS: found[Camp.ORBS], "left": left}


## Breaking camp: it was paid as it was made, so this takes its screen away and brings the map back
## exactly as it was left.
func _break_camp() -> void:
	var levels := _camp_levels
	_camp_levels = 0
	_camp.queue_free()
	_camp = null
	Input.set_default_cursor_shape(Cursors.ARROW)
	_uncover_map()
	# Whatever the camp's pay announced goes with its screen.
	banner.drop()
	_sync_character()
	bag_page.refresh_gold()
	if levels > 0:
		banner.level_up(inventory.level)
	_restore_panel()
	# The start-up's sync waited for this (`Cloud.sync`): now, so a save from another device comes down
	# before anything is played over it.
	cloud.sync(true)


## A fight armed from what the hero stands up in -- a tile's, a run's, the dungeon's and a camp's alike.
## What is worn and learned first, with the rank of every unique: `arm` reads some of it.
func _arm(fight: Encounter) -> void:
	fight.wear(inventory.effects(), Achievements.ranks(inventory))
	fight.arm(inventory.stats())


## What the save lets a fight's bodies drop beside their gear -- a tile's, a run's and a camp's alike.
## Not the scripted first finds (`fight.promised`), which only a fight the player is in can deal.
func _hand_drops(fight: Encounter) -> void:
	# Skill nodes once the sword has dropped -- the first find of any kind spends its promise -- and,
	# while the first node is owed, none but it (the fight's own rule).
	fight.stone_drops = inventory.first_sword_taken
	fight.orbs_after = maxi(0, OrbTable.FIRST_ORB_KILLS - inventory.kills)
	fight.walls_down = inventory.walls_ever()
	fight.uniques_after = maxi(0, UniqueTable.FIRST_UNIQUE_KILLS - inventory.kills)
	# Less whatever a fortuneteller has banished from this world's drops.
	fight.unlocked = FortuneTeller.dropping(Achievements.unlocked(inventory), inventory.fortunes)


## The map and every Control out of the way of what stands over them: a fight, the dungeon or a camp.
func _cover_map() -> void:
	# The map keeps its state but stops running, so nothing walks on underneath.
	map.hide()
	map.process_mode = Node.PROCESS_MODE_DISABLED
	# Before the panel is hidden: leaving a town brings the tile panel back, which a fight then takes away.
	_close_town()
	tile_panel.panel.hide()
	# The pages go and the corner buttons stay (`_show_corner`); the tile panel and the character
	# button do not, since a Control takes the mouse before the fight sees it.
	_close_left_pages()
	_show_corner(false)
	_character.show()


## The map back and running, the corner buttons with it: what `_cover_map` took away.
func _uncover_map() -> void:
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	_show_corner(true)


## The tile panel back for the tile still chosen, as a fight, a camp or a town gives the screen back.
func _restore_panel() -> void:
	if map.selected_cell != HexMap.NO_CELL:
		tile_panel.panel.show()
	tile_panel.update_buttons()


## Puts a tile's fight or a farm run on the screen: armed from what is worn, handed what the save owes
## the player, its gains wired to the ledger, then staged as every fight is (`_stage`).
func _open_fight(fight: Encounter, cell: Vector2i, farming: bool) -> void:
	# What the player is wearing as the fight opens; a change in the bag mid-fight arms it again (`_rearm`).
	_arm(fight)
	# What a new player's first kills are scripted to leave (`Encounter.PROMISED`): the Broken Sword, the
	# two orbs to craft it with, the first unique and the first skill node, each inside its own kills.
	fight.promised = inventory.promised()
	fight.kills_before = inventory.kills
	_hand_drops(fight)
	fight.strikes = true
	fight.even_loot = Settings.even_loot_on()
	ledger = FightLedger.new(inventory, inventory_path, farming)
	ledger.tile_level = view.level_of(cell)
	# Straight off the fight rather than through the scene: what a body was is the fight's business,
	# and the boards want the monster's name, not a drop.
	fight.enemy_died.connect(_on_enemy_died)
	fight.kill_paid.connect(_on_kill_paid)
	ledger.bounty_counted.connect(_on_bounty_counted)
	ledger.bounty_too_low.connect(_on_bounty_too_low)
	_combat = load(COMBAT_SCENE).instantiate()
	_combat.finished.connect(_on_combat_finished.bind(cell))
	_combat.retry.connect(_on_combat_retry.bind(cell))
	# Not `Encounter.loot_dropped`: the fight applies the player's autodiscard rule, and everything
	# downstream believes the fight. A second listener applying the rule a second way is how the
	# counter and the bag would come to disagree about what a fight found.
	_combat.autodiscard = inventory.leaves_behind
	# The Nightwalkers and distant charting take a won tile's loot for the player, so a way runs by itself.
	_combat.auto_collect = not farming and (view.distant or "nightwalker" in inventory.effects())
	_combat.loot_kept.connect(_on_loot_dropped)
	_combat.loot_discarded.connect(_on_loot_autodiscarded)
	_combat.hud.drop_discarded.connect(_on_drop_discarded)
	_combat.gold_gained.connect(_on_gold_gained)
	_combat.orb_gained.connect(_on_orb_gained)
	_combat.xp_gained.connect(ledger.add_xp)
	_combat.xp_absorbed.connect(_on_xp_absorbed)
	_stage(fight, cell, view.name_of(cell), view.area_variant(cell))
	# The tips about the fight itself come as it opens rather than after it, when they are needed.
	_check_tips()
	# A tip already up -- raised as the last fight closed, under a Retry -- holds this fight still as one
	# shown over it does (`_show_next_tip`), so its clock does not run under words that take the clicks.
	if _tip_panel != null:
		_combat.process_mode = Node.PROCESS_MODE_DISABLED


## The fight's scene put on the screen, every kind exactly alike, so one cannot quietly come to differ
## from another: the bag free to open over it, the map and every Control out of its way.
func _stage(fight: Encounter, cell: Vector2i, place: String, variant := "plain") -> void:
	_combat.weapon_kind = _weapon_kind()
	_combat.character = inventory.character
	_let_bag_over()
	add_child(_combat)
	# Told before the fight is built, so a run that opens with a full bag says so on its first frame.
	_refresh_bag_room()
	_combat.place = place
	_combat.xp_target = _character.xp_point()
	_combat.hud.hud_top = _fight_top()
	_combat.hud.hud_foot = _pages_room().end.y
	_combat.begin(fight, cell, ui_scale, variant)
	sounds.play_music(Jukebox.BATTLE)
	_cover_map()
	_show_damage()


## The bag can be opened over every fight: the loot popup and the verdict put it away, since the pages
## stand on a layer above the fight's, and Escape is the bag's while it is up.
func _let_bag_over() -> void:
	_combat.hud.panel_up.connect(_on_left_page_closed)
	_combat.page_up = _left_page_up


## A piece put on, taken off or crafted in the bag mid-fight counts from the next blow. Effects and
## ranks are set rather than worn: `wear` would take the Dreadmask and the curses on again, and both
## shape a lineup that is already being fought. `arm` moves the clock by what changed, never refills it.
func _rearm() -> void:
	if _combat == null or _combat.fight == null or _combat.fight.finished:
		return
	_combat.fight.effects = inventory.effects()
	_combat.fight.ranks = Achievements.ranks(inventory)
	_combat.fight.arm(inventory.stats())


## The kind of weapon the hero has in hand (`LootTable.KINDS`), "" with none: what a fight's blows sound like.
func _weapon_kind() -> String:
	var weapon: Item = inventory.equipment.worn.get(Equipment.Socket.WEAPON)
	return LootTable.kind_of(weapon.type) if weapon != null else ""


## Enter cave: down the dungeon from the cave's own tile, stood on.
func _on_cave_pressed() -> void:
	if view.can_enter_cave(map.selected_cell):
		_on_dungeon_pressed()


## Down the dungeon: a fight on the screen as `_open_fight` puts one there, and nothing else of what
## that does -- it pays nothing, so there is no ledger, no drop to promise and no body for a board.
## It begins under the depths already won, whichever world they were won in.
func _on_dungeon_pressed() -> void:
	var fight := Encounter.for_dungeon(inventory.dungeon_depth)
	_arm(fight)
	# The runes are the third wall's, and Gollux's cave is the only place they fall.
	fight.runes_drop = WallUnlocks.has(inventory.walls_ever(), WallUnlocks.RUNES)
	_cave_runes = 0
	print("Down the dungeon, depth %d" % fight.depth())
	_combat = load(COMBAT_SCENE).instantiate()
	_combat.finished.connect(_on_dungeon_finished)
	_combat.rune_gained.connect(_on_rune_gained)
	_stage(fight, Vector2i.ZERO, DUNGEON_NAME)


## Back from the dungeon. The depths it won are the whole of what it earned.
func _on_dungeon_finished(_won: bool) -> void:
	_bank_depths()
	_combat.queue_free()
	_combat = null
	_show_damage()
	sounds.play_music(Jukebox.IDLE)
	_uncover_map()
	_restore_panel()


## A rune off a body in the cave: the player's at once, written as the descent is left (`_bank_depths`).
func _on_rune_gained(rune: String) -> void:
	inventory.add_rune(rune)
	_cave_runes += 1
	bag_page.refresh_orbs()


## Writes down the depths the open descent has won, if any, and the runes it found: on the way out of
## it and on the way out of the game, so quitting under a dead Gollux cannot cost him.
func _bank_depths() -> void:
	var fight: Encounter = _combat.fight
	var won := fight.first_floor / fight.enemies + fight.cleared()
	var floors := fight.first_floor + fight.index
	print("Left the dungeon at depth %d, %d won, %s on the board" % [fight.depth(), fight.cleared(),
			Cloud.score_text(floors)])
	if fight.cleared() > 0 or won > inventory.dungeon_depth or floors > inventory.dungeon_floors \
			or _cave_runes > 0:
		inventory.dungeon_depth = maxi(inventory.dungeon_depth, won)
		inventory.dungeon_floors = maxi(inventory.dungeon_floors, floors)
		_save_inventory()
		_cave_runes = 0
	# The board is scored from the cloud save, so a descent goes up at once rather than at the next tick.
	cloud.sync.call_deferred(true)


## Back from the fight. The tile is charted only if it was won, and the player stays on it; a lost one
## runs them back to the charted tile they stepped onto it from, unless `retrying` keeps them there
## for the next go.
func _on_combat_finished(won: bool, cell: Vector2i, retrying := false) -> void:
	var kills: int = _combat.fight.kills()
	# Read before the fight is freed.
	var earned: float = _combat.fight.gold
	# Before the kills are banked, whose save -- a run's one write -- is what the achievements are checked on.
	Achievements.record(inventory, _combat.fight)
	ledger.bank_kills(kills)
	_combat.queue_free()
	_combat = null
	if not retrying:
		sounds.play_music(Jukebox.IDLE)
	# Gems still in the air when the fight closed never arrive, so the panel is put back on the ledger.
	_sync_character()
	_uncover_map()
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
		_chart_won(cell)
	else:
		print("Lost the fight for %s; it stays uncharted" % cell)
	var world_lost := not won and not ledger.farming and Curses.NO_SECOND_CHANCES in inventory.curses
	# Off land that is not theirs. Not onto the black screen, where the world is already gone.
	if not won and not ledger.farming and not retrying and not world_lost:
		view.move_to(_retreat_cell)
	# The Nightwalkers: a tile won on the way walks on to the next. Anything but a win or a Retry ends it.
	var next := HexMap.NO_CELL
	if won and not ledger.farming and not _dark_way.is_empty():
		next = _dark_way.pop_front()
	elif not retrying:
		_dark_way.clear()
	_tile_lost = not won and not ledger.farming
	ledger.farming = false
	# A run counts the runes on its tile down.
	if map.selected_cell != HexMap.NO_CELL:
		tile_panel.show_runes(map.selected_cell)
	_restore_panel()
	# After the fight, so a pop-up never covers one.
	_check_tips()
	# Walked onto like any tile beside the charted land, so its fight opens on arrival -- unless the bag
	# filled on the way, which stops the fights and so the way.
	if next != HexMap.NO_CELL:
		if view.can_chart(next) and not inventory.encumbered():
			map.select_cell(next)
			_walk_to_fight(next, false)
		else:
			_dark_way.clear()
	# No Second Chances: the tile's fight was the world's. Last, so everything the fight earned is
	# banked and saved before the black screen, on which nothing may be.
	if world_lost:
		print("No Second Chances: the world ends with the fight for %s" % cell)
		_open_transcend(true)


## A tile's fight won: the tile charted with what it shows behind it, and what that brought down or put
## down paid and placed (`_credit_walls`).
func _chart_won(cell: Vector2i) -> void:
	print("Charted %s, showing %d tile(s) behind it" % [cell, view.chart(cell, _sight())])
	_credit_walls()


## Every wall down in this world that has not yet paid its super orb pays it; the heirlooms climb to
## the land charted; the land's furthest reach and its deepest tile are written down; and the world's
## cave is put down if it is due. Asked wherever a wall can have fallen (a tile charted) and once at
## start-up, which pays a save from before there were heirlooms for the walls it already has down.
func _credit_walls() -> void:
	var paid := inventory.credit_walls(view.walls_fallen())
	if paid:
		print("A wall is down: %d super orb(s) to spend at a transcension" % inventory.super_orbs)
	# The heirlooms climb with the land charted; a page already up shows the new levels.
	var charted := view.charted_level()
	var climbed := inventory.raise_heirlooms(charted)
	# Not before the pages are built, nor once they are gone (`_exit_tree` charts a tile won and not collected).
	if climbed and bag_page != null and bag_page.is_inside_tree():
		bag_page.refresh()
		heirloom_page.refresh()
	# The deepest tile ever charted is a leaderboard's score.
	var deeper := inventory.chart(charted)
	# How far the land has ever reached is the cave's bound in every world after this one.
	if inventory.reach(view.land_radius) or paid or climbed or deeper:
		_save_inventory()
	# Distant charting, once the fourth wall has fallen in any world.
	view.distant = WallUnlocks.has(inventory.walls_ever(), WallUnlocks.DISTANT)
	# One cave a world, once Gollux is unlocked (the third wall, in any world): beside the next wall broken.
	if WallUnlocks.has(inventory.walls_ever(), WallUnlocks.GOLLUX) and view.place_cave(view.breach):
		print("The Gollux cave is at %s" % view.cave)
		_save_map()


## How far the player sees from a tile they have just taken (`Inventory.sight`). It is read here and
## nowhere else -- at the moment the tile is charted -- so a torch put on afterwards uncovers nothing
## and one taken off hides nothing. What a tile showed is what it showed.
func _sight() -> int:
	return inventory.sight()


## The Homeland's two lands, chosen once, the first time the cursed world's map exists: the kind the
## start stands on, so the first fights leave something, and one other, seeded from the map so a world
## reloaded before its first save chooses the same. Saved with the inventory from then on.
func _settle_homeland() -> void:
	if not Curses.HOMELAND in inventory.curses or not inventory.homeland.is_empty():
		return
	var first := view.env_at(MapBuilder.CENTER)
	var others: Array = SheetMeta.env_adjacency().keys().filter(
			func(env: String) -> bool: return env != first)
	others.sort()
	inventory.homeland.assign([first, others[absi(hash([view.env_seed, "homeland"])) % others.size()]])
	print("Homeland: %s" % [inventory.homeland])
	_save_inventory()


## What the land on `cell` does to its own fight, under this world's curses.
func _mods_of(cell: Vector2i) -> Array[String]:
	return view.mods_of(cell, Curses.WILD_TILES in inventory.curses)


## Retry under a lost verdict. Out through the one door every fight leaves by, so what it earned is
## banked and its kills counted, and back in through Chart, so the second go is opened like the first.
func _on_combat_retry(cell: Vector2i) -> void:
	_on_combat_finished(false, cell, true)
	# Under No Second Chances the loss just ended the world, and there is no second go.
	if _transcend_page == null:
		map.select_cell(cell)
		_on_chart_pressed()
	# A retry that did not open a fight (a full bag, No Second Chances) is back on the map.
	if _combat == null:
		sounds.play_music(Jukebox.IDLE)
		# And off land that is not theirs, as any loss leaves them, the rest of a way dropped with it.
		# Not onto the black screen, where the world is already gone.
		if _transcend_page == null:
			_dark_way.clear()
			view.move_to(_retreat_cell)
			tile_panel.update_buttons()


func _on_move_pressed() -> void:
	var cell := map.selected_cell
	print("Walking to %s, %d tile(s) away" % [cell, view.move_to(cell).size()])
	tile_panel.update_buttons()


## The floating Stop: the walk ends on the tile being stepped onto. Whatever waited at its end -- a fight,
## a town, the rest of a way -- is dropped first, or that arrival would press its button again.
func _on_stop_pressed() -> void:
	if not map.player.can_stop():
		return
	_fight_target = HexMap.NO_CELL
	_town_target = HexMap.NO_CELL
	_dark_way.clear()
	map.player.stop_walk()


## Where the map's own state has changed: charting a tile walks the player onto it (a paid scour is
## the one other change, `_on_cell_aimed`). So it is written down here, and a crash costs at most the
## step in progress rather than the session.
func _on_player_arrived(cell: Vector2i) -> void:
	print("Arrived at %s" % cell)
	_update_weather()
	_sync_chest()
	_save_map()
	tile_panel.update_buttons()
	if _fight_target != HexMap.NO_CELL:
		var target := _fight_target
		_fight_target = HexMap.NO_CELL
		# Selecting it again is what the fight reads, in case the player clicked elsewhere on the way.
		map.select_cell(target)
		if _fight_farms:
			_on_farm_pressed()
		else:
			_on_chart_pressed()
	if _town_target != HexMap.NO_CELL:
		var target := _town_target
		_town_target = HexMap.NO_CELL
		map.select_cell(target)
		_on_town_pressed()
	# Where standing on a settlement becomes true: walking to one, and the walk a won settlement fight
	# sends the player on when it charts the tile. Last, so a walk that ends in a fight has opened it
	# first and a pop-up holds that fight still rather than letting its clock run under it.
	_check_tips()


## Held upright the sheet covers the foot of the map: a tile chosen under it is brought up into the
## middle of what the sheet leaves, so the panel never hides the tile it describes.
func _keep_above_sheet(cell: Vector2i) -> void:
	if not _narrow() or not tile_panel.panel.visible:
		return
	var at := map.ground_layer.map_to_local(cell)
	var view_size := get_viewport().get_visible_rect().size
	var foot := at.y + map.ground_layer.tile_set.tile_size.y / 2.0
	if (foot - camera.position.y) * camera.zoom.y + view_size.y / 2.0 <= tile_panel.panel.position.y:
		return
	var lift := (tile_panel.panel.position.y - view_size.y) / 2.0 / camera.zoom.y
	_glide_camera(_clamp_to_map(Vector2(camera.position.x, at.y - lift)))


## The part of the window the map is seen through: the pages' room less the tile panel, beside it on a
## monitor and over its foot held upright.
func _map_room() -> Rect2:
	var room := _pages_room()
	if tile_panel.panel.visible:
		if _narrow():
			room.end.y = tile_panel.panel.position.y
		else:
			room.end.x = tile_panel.panel.position.x
	return room


## The hero's badge pressed: the camera back over them, in the middle of the map the panels leave.
func _find_hero() -> void:
	_centre_on(view.player_cell)


## The journal's "Claim at": the town that posted a finished bounty chosen, which puts the page away
## and its tile panel up (`_on_tile_clicked`), and brought into the middle of the map that leaves.
func _show_town(spot: Vector2i) -> void:
	var cell := spot - view.origin
	map.select_cell(cell)
	_centre_on(cell)


## The camera glided over `cell`, in the middle of the map the panels leave.
func _centre_on(cell: Vector2i) -> void:
	var off_middle := _map_room().get_center() - get_viewport().get_visible_rect().size / 2.0
	_glide_camera(_clamp_to_map(map.ground_layer.map_to_local(cell) - off_middle / camera.zoom.x))


## The camera moved `to` over `CAMERA_LIFT`, or at once with animations off. A new glide takes over
## from one still under way, so two never pull the camera at once.
func _glide_camera(to: Vector2) -> void:
	if _camera_glide != null:
		_camera_glide.kill()
	if Settings.animations == Settings.Anim.NONE:
		camera.position = to
	else:
		_camera_glide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_camera_glide.tween_property(camera, "position", to, CAMERA_LIFT)


## Where a fight's top-centre column stands, in window pixels: at the top of the safe part of the
## window, or held upright, where there is no room for it beside the character panel, under that.
func _fight_top() -> float:
	if _narrow():
		return _character.position.y + (_character.size.y + 4) * ui_scale
	return UITheme.safe_rect(get_viewport()).position.y + FightHud.HUD_MARGIN


## Whether the window is held upright, too narrow for the panels to stand side by side.
func _narrow() -> bool:
	return UITheme.narrow(UITheme.safe_rect(get_viewport()).size, ui_scale)


## Where the pages stand, in window pixels: the safe part of the window, less the corner buttons' bar
## along its foot while the window is narrow and any corner button is up.
func _pages_room() -> Rect2:
	var room := UITheme.safe_rect(get_viewport())
	var shown := _bag_button != null and _corner_buttons().any(
			func(button: Button) -> bool: return button.visible)
	if shown and _narrow():
		room.size.y -= NAV_HEIGHT * ui_scale
	return room


## A kill left something behind, which the ledger puts straight into the bag; what is left to do here
## is show it -- in the bag too, which can be open over the fight.
func _on_loot_dropped(_index: int, item: Item) -> void:
	print("Dropped %s (%s, level %d, %d modifier(s))"
			% [item.type, item.rarity_name(), item.level, item.mods.size()])
	# Asked before the ledger has it: a tile fight banks at once, and the log would already say it was
	# found by the time the banner went up.
	var first := _is_new_unique(item)
	ledger.add_loot(item)
	if first:
		banner.unique(item)
	bag_page.refresh()


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
		banner.level_up(_character.level)


func _on_loot_autodiscarded(_index: int, item: Item) -> void:
	print("Autodiscarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
	ledger.autodiscarded()
	_pay_salvage(item)


## A find the player threw away by hand, from the fight's verdict. Only one still in the bag is paid
## for: a piece sold, thrown away or put on from the bag mid-fight has gone already.
func _on_drop_discarded(item: Item) -> void:
	if ledger.discard(item):
		bag_page.refresh()
		_pay_salvage(item)


## The Rag and Bone Sack, for a find thrown away in a fight. Through the ledger like any gold, which
## writes it down when the fight's rule says; the bag pays for its own discards (`BagPage`).
func _pay_salvage(item: Item) -> void:
	inventory.tick("discarded")
	var paid := inventory.salvage(item)
	if paid > 0.0:
		ledger.add_gold(paid)
	var orb := inventory.salvage_orb()
	if not orb.is_empty():
		ledger.add_orb(orb)


## Tells the fight how much room is left, which is what puts the full-bag warning up. Every frame
## (`_process`): drops, the verdict and the bag open over the fight all change it.
func _refresh_bag_room() -> void:
	if _combat != null:
		_combat.hud.bag_size = inventory.capacity()
		_combat.hud.bag_room = inventory.room_left()


## A body has fallen. What it was goes to the ledger, which hands it to the boards.
func _on_enemy_died(index: int) -> void:
	if _combat != null and index < _combat.fight.lineup.size():
		ledger.add_kill(_combat.fight.lineup[index])


## That body's loot has been rolled and handed over (`Encounter.kill_paid`): on a farm run it counts
## down what the runes on the tile are doing (`RuneTable.count_kill`), and the fight forgets whatever
## ran out from the next body on. Never sooner (`enemy_died` comes before the loot), or a rune's last
## body would be fought under the rune and paid without it.
func _on_kill_paid(_index: int) -> void:
	if _combat == null or not ledger.farming:
		return
	var fight: Encounter = _combat.fight
	var spot := view.origin + fight.cell
	if not inventory.has_runes(spot):
		return
	var gone := RuneTable.count_kill(inventory.rune_state(spot))
	if not RuneTable.any_gone(gone):
		return
	for mod: Dictionary in gone["mods"]:
		for tier in int(mod["tier"]):
			fight.forget_mod(mod["id"])
	fight.deeper -= int(gone["depth"])
	if gone["ascent"]:
		fight.ascended = false
	_rearm()


## The ledger counted a body against the accepted bounty. The kill that fills it is the banner alone;
## every one before it is the toast.
func _on_bounty_counted(enemy: String, have: int, need: int) -> void:
	var tier := EnemyRoster.tier_of(enemy)
	if have < need:
		banner.toast_bounty(enemy, tier)
		return
	var spot := BountyBoard.active_spot(inventory.towns)
	banner.bounty(enemy, tier, have, need,
			bounty_page.town_name(TownState.spot(spot)) if not spot.is_empty() else "the town")


## The bounty's monster killed on land too shallow for its posting: the toast says so, in brick.
func _on_bounty_too_low(enemy: String, level: int) -> void:
	banner.toast_bounty(enemy, EnemyRoster.tier_of(enemy), level)


## The corner buttons in a column, the ones there are closed up: under the character panel on the map,
## or beside whichever page is up, which has that panel's corner, so one press goes from page to page
## without an X between.
func _place_corner() -> void:
	# The bag measures itself as it is built (`laid_out`), before the pages after it exist.
	if not is_instance_valid(character_page) or not character_page.is_inside_tree():
		return
	if _narrow():
		_place_corner_row()
		return
	_nav_bar.hide()
	for button in _corner_buttons():
		_fit_cell(button, 0.0)
	var at := Vector2(_character.position.x, _character.position.y + (_character.size.y + 4) * ui_scale)
	var page := _left_page()
	if page != null:
		# Every page's own panel is its first child, against the left edge; the bag runs on past its.
		# The bag's sheet is centred down the window, and a column at the window's top beside it
		# belonged to nothing: it starts where the sheet does, or under the caret that brings it back.
		# From the top-left corner, wherever the character panel has gone (`_place_character`).
		var top := UITheme.safe_rect(get_viewport()).position.y + CHARACTER_EDGE.y
		var panel: Control = page.get_child(0)
		var bag := page as BagPage
		at = (bag.column_origin(CORNER_GAP, top) if bag != null
				else Vector2(panel.position.x + (panel.size.x + CORNER_GAP) * ui_scale, top))
	var step := (_bag_button.get_combined_minimum_size().y + CORNER_GAP) * ui_scale
	for button in _corner_buttons():
		if button.visible:
			_move_corner(button, at)
			at.y += step


## Held upright, the corner buttons are a navigation bar along the window's foot, where a thumb is, and
## every page stands over it (`_pages_room`): dark brown across the window, the buttons sharing out the
## width of the left pages' panel over it, the open page's share light brown (the user's, 2026-10-29).
func _place_corner_row() -> void:
	var shown := _corner_buttons().filter(func(button: Button) -> bool: return button.visible)
	var safe := UITheme.safe_rect(get_viewport())
	var window := get_viewport().get_visible_rect()
	var top := floorf(safe.end.y - NAV_HEIGHT * ui_scale)
	_nav_bar.visible = not shown.is_empty()
	_nav_bar.position = Vector2(window.position.x, top)
	_nav_bar.size = (Vector2(window.size.x, window.end.y - top) / ui_scale).ceil()
	# Centred as `UITheme.dock` centres a page, so the shares line up under its panel.
	var across := minf(BagPage.WIDTH + 2 * UITheme.PANEL_MARGIN, floorf(safe.size.x / ui_scale))
	var left := floorf(safe.position.x + (safe.size.x - across * ui_scale) / 2.0)
	var pages := {_bag_button: bag_page, _heirloom_button: heirloom_page, _skills_button: skills_page,
			_roster_button: roster_page, _bounty_button: bounty_page, _collection_button: collection_page,
			_achievements_button: achievements_page, _leaderboard_button: leaderboard_page,
			_settings_button: settings_page}
	var open := shown.any(func(button: Button) -> bool: return (pages[button] as Control).visible)
	for i in shown.size():
		var button: Button = shown[i]
		var from := floorf(across * i / shown.size())
		var here := (pages[button] as Control).visible
		_fit_cell(button, floorf(across * (i + 1) / shown.size()) - from, here, open and not here)
		_move_corner(button, Vector2(left + from * ui_scale, top))


## A box for the navigation bar cut from `rows` (`UITheme.stamp`: `a` the brown button's outline, `h` the
## tan, `l` its lit brown, `b` its brown), the top two rows and `side` columns each side kept as drawn.
static func _nav_box(rows: Array[String], side: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(UITheme.stamp(rows, {"a": Palette.BUTTON_INK,
			"h": Palette.SLOT_TAN, "l": Palette.BUTTON_BROWN_LT, "b": Palette.BUTTON_BROWN}))
	box.texture_margin_top = 2
	box.texture_margin_left = side
	box.texture_margin_right = side
	return box


## A corner button as a share of the navigation bar, `width` panel pixels across and answering anywhere
## in it: no face, its mark alone in the middle on the bar, or lifted on the tab while `here` or pressed,
## and darkened while `dim`. A zero `width` gives the button back its own size and faces, for the column.
func _fit_cell(button: Button, width: float, here := false, dim := false) -> void:
	var mark := Vector2(button.icon.get_size())
	var cell := Vector2(width, NAV_HEIGHT)
	# Where the mark stands in the button: the content is the mark alone, so it is on whole pixels
	# whatever the share's width.
	var pad := ((cell - mark) / 2.0).floor() if width > 0.0 else Vector2.ONE * UITheme.ICON_FACE_MARGIN
	for state: String in UITheme.STATES:
		if width == 0.0:
			button.remove_theme_stylebox_override(state)
			continue
		var tab := here or state == "pressed"
		var box: StyleBox = _nav_tab.duplicate() if tab else StyleBoxEmpty.new()
		var lift := NAV_RISE / 2.0 if tab else 0.0
		box.content_margin_left = pad.x
		box.content_margin_top = pad.y - lift
		box.content_margin_right = cell.x - mark.x - pad.x
		box.content_margin_bottom = cell.y - mark.y - pad.y + lift
		button.add_theme_stylebox_override(state, box)
	# Under the mouse or a press, a dim mark lights as the open one is.
	for color: String in ["icon_normal_color", "icon_focus_color"]:
		if dim:
			button.add_theme_color_override(color, NAV_DIM)
		else:
			button.remove_theme_color_override(color)
	# Clamped up to the button's minimum, so a zero width is its own size again.
	button.size = cell if width > 0.0 else Vector2.ZERO
	# Where it stood off the face's top-right corner, face or none.
	(button.get_node(^"New") as Control).position = (pad + PIP_AT
			+ Vector2(mark.x + UITheme.ICON_FACE_MARGIN, -UITheme.ICON_FACE_MARGIN))


## The corner buttons in the order they stand: what you carry (the bag, then the heirlooms), what you
## are (the tree, then the hero), what you have promised to do, the logs, and the settings last (the
## user's, 2026-10-11).
func _corner_buttons() -> Array[Button]:
	return [_bag_button, _heirloom_button, _skills_button, _roster_button, _bounty_button, _collection_button,
			_achievements_button, _leaderboard_button, _settings_button]


## One corner button put `at`, gliding there after a page that comes or goes rather than jumping --
## but not from the corner it is made in, on its first placing.
func _move_corner(button: Button, at: Vector2) -> void:
	var was := button.position
	button.position = at
	if was != at and was != Vector2.ZERO:
		Juice.glide(button, was)


## Every corner button at once. They come and go together because what takes them away is never
## about one of them: a fight that must see every click, or a town, whose three panels leave the
## window no room. A page does not -- they stand beside it (`_place_corner`) -- but it does cover the
## character panel, unless it is a bag page that sends the panel to the other corner (`_place_character`,
## run first), and the see-through button over the panel goes where it goes. **A fight leaves every one
## of them** until its verdict (`_fight_up`): each page opens over a farm or a chart as on the map (the
## user's, 2026-10-02, 2026-10-03, 2026-10-07).
func _show_corner(shown: bool) -> void:
	_place_character()
	shown = shown and _combat == null
	# A fight never stands in a town, so `buttons` is `shown` past the town's line as well.
	var buttons := shown or _fight_up()
	# The one button a town leaves standing, because it is the only way to hold an heirloom up to a
	# smith, a fortuneteller or a held orb: there it swaps the bag and the heirlooms at the counter.
	_heirloom_button.visible = buttons and (inventory.stash().total() > 0
			or not inventory.stash().equipment.worn.is_empty())
	if _heirloom_button.visible:
		_flash(_heirloom_button, "opened_heirlooms")
	shown = shown and not town_page.visible
	buttons = shown or _fight_up()
	_bag_button.visible = buttons and ("first_item" in inventory.tips or "first_orb" in inventory.tips)
	_skills_button.visible = buttons and "level_up" in inventory.tips
	# The journal has nothing in it until the player has stood at a board, which is also when their
	# kills start counting towards one.
	_bounty_button.visible = buttons and BountyBoard.any_seen(inventory.towns)
	# Nothing earns the settings: they are there from the first step.
	_settings_button.visible = buttons
	# Nor the heroes, but never over a fight: a fighter is dressed as it is staged, not mid-swing.
	_roster_button.visible = shown
	_character_button.visible = (shown or _combat != null) and _character.visible
	# Over a fight it stays only for the experience bar's tooltip (`xp_hover`, which lets every press
	# through): the button itself takes no mouse there, no key and no hand.
	_character_button.disabled = not shown
	_character_button.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	if not shown:
		_character.modulate = Color.WHITE
	Cursors.wear(_character.xp_hover, Cursors.HAND if shown else Cursors.ARROW)
	# The log is a thing to be found, like what it lists: it is not there until the first unique is.
	_collection_button.visible = buttons and (Settings.show_all_uniques()
			or not inventory.uniques_found.is_empty())
	_flash(_collection_button, "opened_collection")
	# The goals are not shown until the first is reached: the page appears with the unique it unlocked.
	_achievements_button.visible = buttons and not inventory.achievements.is_empty()
	_flash(_achievements_button, "opened_achievements")
	# The boards are there once the player has a score worth one: a wall broken (the cave comes after one).
	_leaderboard_button.visible = buttons and cloud.enabled() and (int(inventory.tally.get("walls", 0)) > 0
			or inventory.dungeon_floors > 0)
	if _bag_button.visible:
		_flash(_bag_button, "opened_bag")
	_pulse(_skills_button, "skill_point", _skill_point_free())
	_mark_new()
	# Held upright the row takes its height from the pages' room, so they are laid out again with it.
	if _narrow():
		_layout_ui()
	else:
		_place_corner()


## Whether a fight is on and not yet over: the bag can be opened over it until its verdict.
func _fight_up() -> bool:
	return _combat != null and _combat.fight != null and not _combat.fight.finished


## Whether the thing a tip is about has happened yet.
func _tip_due(id: String) -> bool:
	match id:
		"first_item":
			return inventory.total() > 0
		"first_orb":
			return inventory.total_orbs() > 0
		"first_stone":
			return inventory.items.any(func(item: Item) -> bool: return item.is_stone())
		"level_up":
			return inventory.level > 1
		"first_farm":
			return ledger.farming and _combat != null
		"first_chart":
			return not ledger.farming and _combat != null
		"first_death":
			return _tile_lost
		"first_town":
			return view != null and view.can_visit(view.player_cell)
		"first_accept":
			return not BountyBoard.active(inventory.towns).is_empty()
		"first_unique":
			return not inventory.uniques_found.is_empty()
		"first_heirloom":
			return inventory.super_orbs > 0
		"first_fortune":
			return town_page.visible and town_page.open_tab() == TownServices.FORTUNE
		"first_smith":
			return town_page.visible and town_page.open_tab() == TownServices.SMITH
		"first_board_cleared":
			# Over the reward it is about, so he is handing it over as he says so.
			return rewards.choice != null
		"first_cave":
			return (view != null and view.cave != HexMap.NO_CELL and view.seen(view.cave)
					and view.is_land(view.cave))
		"first_sense":
			# As the wall in front of the cave falls, its fight over, and the light comes up at the edge.
			return _cave_sense != null and _cave_sense.felt()
	# A tip in `TIPS` with no rule here would never come up, and say nothing about it.
	push_error("No rule says when the tip \"%s\" is due" % id)
	return false


## Queues every tip that has come due and not been shown, and brings on the buttons they unlock.
func _check_tips() -> void:
	var added := false
	for tip: Array in TIPS:
		if tip[0] not in inventory.tips and _tip_due(tip[0]):
			inventory.tips.append(tip[0])
			if SPOTLIGHTS.has(tip[0]):
				inventory.tips.append(SPOTLIGHTS[tip[0]])
			_tip_queue.append(tip)
			added = true
	# Not mid-fight: a run writes nothing until it ends, and `bank_kills` saves the seen tip then.
	if added and _combat == null:
		_save_inventory()
	# A tip can come due with a page up or a town open, and `_show_corner` knows about both.
	_show_corner(_combat == null and _camp == null)
	if _tip_panel == null:
		_show_next_tip()


## Every version newer than the one last shown, as one tip, once: the web build's start-up asks, and
## the newest is written to the settings as it is queued, so nothing comes up again until a newer one.
func _show_changelog() -> void:
	var unseen := Changelog.since(Settings.changelog_seen)
	if unseen.is_empty():
		return
	Settings.changelog_seen = unseen[0]["version"]
	Settings.save()
	_tip_queue.append([Changelog.PATH, Changelog.TITLE, unseen])
	if _tip_panel == null:
		_show_next_tip()


## The comic a first run opens on (`Comic`), as a tip: marked seen as it is queued, so a game shut
## under it never shows it again, and let go by Escape like any tip.
func _queue_comic() -> void:
	inventory.tips.append(Comic.ID)
	_save_inventory()
	_tip_queue.append([Comic.ID])
	if _tip_panel == null:
		_show_next_tip()


## One tip at a time: the comic over the whole window, someone speaking, in a `DialogueBox` along the
## window's foot, or the changelog -- the one plain panel left, in the middle of the window, built the
## way the refused-save panel is.
func _show_next_tip() -> void:
	if _tip_queue.is_empty():
		return
	var tip: Array = _tip_queue.pop_front()
	# A fight holds still under a tip: a charting fight's clock must not run while the player reads.
	if _combat != null:
		_combat.process_mode = Node.PROCESS_MODE_DISABLED
	if tip.size() == 1:
		var comic := Comic.new(ui_scale)
		comic.finished.connect(_on_tip_closed)
		_tip_panel = comic
		_character.get_parent().add_child(comic)
		return
	if tip.size() > 3:
		# The hero speaks under the name the player gave them.
		var box := DialogueBox.new(inventory.hero() if tip[1] == HERO else tip[1], tip[2],
				load(Characters.path(inventory.character, "portrait") if tip[3] == DialogueBox.PLAYER
						else DialogueBox.PORTRAITS % tip[3]),
				tip[3] == DialogueBox.PLAYER)
		box.finished.connect(_on_tip_closed)
		_tip_panel = box
		_character.get_parent().add_child(box)
		box.pop_up(ui_scale)
		return
	# The changelog (`_show_changelog`). No X: like a reward's panel, its one way out is the button at
	# its foot (and Escape).
	var panel := UITheme.titled_panel(tip[1], "", Callable())
	_tip_panel = panel
	# The character panel's layer, which stands over the fight's, so a tip can come up mid-run.
	_character.get_parent().add_child(panel)
	# Scrolling past what the window leaves.
	var scroll := UITheme.scroll()
	var lines := Changelog.page(tip[2], _notice_width())
	scroll.add_child(lines)
	UITheme.body_of(panel).add_child(scroll)
	# Twice: a wrapped label only knows how tall it is once it has been laid out once.
	var fit := func() -> void:
		scroll.custom_minimum_size.y = minf(lines.get_combined_minimum_size().y,
				get_viewport().get_visible_rect().size.y / ui_scale - TownPage.TOLD_CHROME)
	fit.call()
	fit.call_deferred()
	var close := UITheme.button("Got it", "LightButton", "")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_on_tip_closed)
	UITheme.body_of(panel).add_child(close)
	Juice.popup(null, _tip_panel, ui_scale)


## Got it and Escape: the tip shrinks away while the next one, if any, comes up.
func _on_tip_closed() -> void:
	if _tip_panel == null:
		return
	var leaving := _tip_panel
	_tip_panel = null
	# Someone speaking stands over a shade of their own, which fades rather than shrinks, and the comic
	# fades whole.
	if leaving is DialogueBox:
		(leaving as DialogueBox).leave()
	elif leaving is Comic:
		(leaving as Comic).leave()
	else:
		Juice.pop_out(leaving, leaving.queue_free)
	_show_next_tip()
	if _tip_panel == null and _combat != null:
		_combat.process_mode = Node.PROCESS_MODE_INHERIT


## Every frame: puts up, moves on or takes down the shade over all but the next press of the first owed
## step (`SPOTLIGHTS`) that has one, and strikes off a step taken. Never over a tip, a pop-up, a fight,
## a camp, a town or the black screen, so a question or a tip that comes up is never shaded.
func _spotlight() -> void:
	var lit: Control = null
	if (_tip_panel == null and _tip_queue.is_empty() and _combat == null and _camp == null
			and _transcend_page == null and not town_page.visible and not _popup_up()):
		for step: String in SPOTLIGHTS.values():
			if step not in inventory.tips:
				continue
			if _step_taken(step):
				inventory.tips.erase(step)
				_save_inventory()
				continue
			lit = _step_target(step)
			if lit != null and lit.is_visible_in_tree():
				break
			lit = null
	if lit == null:
		if _spot != null:
			_spot.get_parent().remove_child(_spot)
			_spot.queue_free()
			_spot = null
	elif _spot == null:
		_spot = Spotlight.new(lit, ui_scale)
		# Under the item card and the tooltips, which take no mouse: the lit square's card reads unshaded.
		var top := _character.get_parent()
		top.add_child(_spot)
		top.move_child(_spot, _item_card.get_index())
	else:
		_spot.target = lit


## Whether an owed step has been taken. The orb's is struck off by the bag's `crafted` (`_build_pages`).
func _step_taken(step: String) -> bool:
	match step:
		"step_equip":
			return not inventory.equipment.worn.is_empty()
		"step_point":
			return inventory.skills.spent() > 0
	return false


## The next thing to press for an owed step, or null while there is none.
func _step_target(step: String) -> Control:
	match step:
		"step_equip":
			# "Let's see if it fits": the bag, the piece, its Equip.
			var piece: Item = null
			for item: Item in inventory.items:
				var sockets := inventory.equipment.sockets_for(item)
				if not sockets.is_empty() and inventory.can_equip(item, sockets[0]):
					piece = item
					break
			if piece == null:
				return null
			if not bag_page.visible:
				return _bag_button
			# Only the piece's square is lit, so the piece open can only be this one.
			var equip: Button = bag_page.action("Equip")
			return equip if equip != null else bag_page.square_of(piece)
		"step_orb":
			# "My gear would look good glowing": the bag, the orb, a piece it can go on, worn first.
			if not bag_page.visible:
				return _bag_button
			var orb: String = bag_page.orb_in_hand()
			if orb.is_empty():
				for kind: String in OrbTable.orbs():
					if inventory.orb_count(kind) > 0:
						return bag_page.tray_square(kind)
				return null
			for item: Item in inventory.equipment.worn.values() + inventory.items:
				if OrbTable.can_apply(orb, item):
					return bag_page.square_of(item)
			return null
		"step_point":
			# "I feel stronger": the skill tree, its root.
			if inventory.skills.points(inventory.level) <= 0:
				return null
			return skills_page.square("") if skills_page.visible else _skills_button
	return null


## Pulses a button until it has been pressed once.
func _flash(button: Button, id: String) -> void:
	_pulse(button, id, id not in inventory.tips)


## The first press: the pulse stops for good.
func _stop_flash(id: String) -> void:
	if id in inventory.tips:
		return
	inventory.tips.append(id)
	_save_inventory()
	_pulse(null, id, false)


## Pulses a button while `on` and stills it once not. The tween is the scene's, so a button hidden for
## a fight is still pulsing when it comes back.
func _pulse(button: Button, id: String, on: bool) -> void:
	if on == _flashes.has(id):
		return
	if on:
		var tween := create_tween().set_loops()
		tween.tween_property(button, "modulate", FLASH_BRIGHT, FLASH_SECONDS)
		tween.tween_property(button, "modulate", Color.WHITE, FLASH_SECONDS)
		_flashes[id] = [tween, button]
		return
	_flashes[id][0].kill()
	_flashes[id][1].modulate = Color.WHITE
	_flashes.erase(id)


## The red pip on each corner button whose page has something new: a first of its kind in the bag, a
## rank to buy, a bounty to claim, a find or an achievement not looked at yet.
func _mark_new() -> void:
	var has_new := {
		_bag_button: _bag_first(),
		_skills_button: _skill_point_free(),
		_bounty_button: BountyBoard.ready(BountyBoard.active(inventory.towns)),
		_collection_button: not inventory.uniques_new.is_empty(),
		_achievements_button: not inventory.achievements_new.is_empty(),
	}
	for button: Button in has_new:
		(button.get_node(^"New") as CanvasItem).visible = has_new[button]


## Whether a first of its kind (`BAG_FIRSTS`) has reached the bag since it was last up: the only thing
## its pip is for (the user's, 2026-10-10; the bag's own arrows say the rest). The bag up is each of
## them looked at, which the next save keeps.
func _bag_first() -> bool:
	var unseen := BAG_FIRSTS.filter(func(id: String) -> bool:
		return id in inventory.tips and SEEN + id not in inventory.tips)
	if bag_page.visible:
		for id: String in unseen:
			inventory.tips.append(SEEN + id)
		return false
	return not unseen.is_empty()


## Whether a rank can be bought anywhere in the skill tree: the root takes every point there is and is
## never refused, so while one is left to spend -- a new hero's tree being the root alone.
func _skill_point_free() -> bool:
	return inventory.why_not_skill("").is_empty()


## Every page that stands against the left edge. They share it, so opening one closes the rest and
## there is one place that knows which those are: what is wired, laid out and closed is this list.
func _left_pages() -> Array[Control]:
	return [bag_page, heirloom_page, skills_page, bounty_page, settings_page, collection_page,
			achievements_page, character_page, leaderboard_page, roster_page]


## The hero the player is (`inventory.character`) on everything that draws them outside a fight: the map's
## token, the corner's face and the badge that points at them. A fight is told as it is staged (`_stage`),
## and the character page and a spoken tip ask as they are drawn.
func _wear_character() -> void:
	var id := inventory.character
	map.player.dress(id)
	_character.set_portrait(load(Characters.path(id, "face")))
	_hero_pointer.set_picture(load(Characters.path(id, "badge")))


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
	# The bag over a fight: the loot popup it would stand over goes.
	if _combat != null:
		_combat.hud.close_loot()
	# Alt on a square compares against the doll of the page it is on.
	_item_card.equipment = (inventory.stash().equipment if page == heirloom_page
			else inventory.equipment)
	# The page covers the left edge and the character panel goes, or for a bag page moves to the other
	# corner (`_place_character`, which this runs).
	_show_corner(true)


## The X on any page: the same things follow from closing any of them. A town page and the bag in
## shop mode are one thing on screen, so either X puts both away. The character panel comes back to
## its corner with the rest (`_show_corner`).
func _on_left_page_closed() -> void:
	_close_left_pages()
	_close_town()
	_show_corner(true)


## A corner button or the character panel pressed: its page, redrawn because what it shows moves
## while it is shut -- or, pressed beside its own open page, that page put away as its X would.
## Opening one drops the selected tile, so nothing stays outlined behind the page; in a town the
## tile stays, since the town stands on it, and so it does in a fight, which is fought on it.
func _toggle_left_page(page: Control) -> void:
	if page.visible:
		_on_left_page_closed()
		return
	if not town_page.visible and _combat == null:
		_on_close_pressed()
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
	_restore_panel()


func _on_skills_pressed() -> void:
	_toggle_left_page(skills_page)


func _on_bag_pressed() -> void:
	_stop_flash("opened_bag")
	_toggle_left_page(bag_page)


## The heirlooms' button. On the map it is a page like the rest. In a town it swaps which of the two bag pages
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


## Whichever bag page is standing beside the town: the bag, unless the heirlooms' button has swapped it out.
func _counter_page() -> BagPage:
	return heirloom_page if heirloom_page.visible else bag_page


func _on_bounty_pressed() -> void:
	_toggle_left_page(bounty_page)


func _on_collection_pressed() -> void:
	_stop_flash("opened_collection")
	_toggle_left_page(collection_page)


func _on_achievements_pressed() -> void:
	_stop_flash("opened_achievements")
	_toggle_left_page(achievements_page)


## After every save: earns what the player has reached (`Achievements.earn`), keeps it, and raises the
## banner. Never while the black screen is up, where nothing may be saved, nor over a refused or reset
## save.
func _check_achievements() -> void:
	if not _may_save():
		return
	var earned := Achievements.earn(inventory)
	if earned.is_empty():
		return
	# Every card from here on writes the uniques at their new ranks.
	UniqueTable.ranks = Achievements.ranks(inventory)
	_save_inventory()
	_show_corner(_combat == null)
	banner.achievements(earned, inventory)


func _on_character_pressed() -> void:
	_toggle_left_page(character_page)


## The character page's pencil: the game's own text box over the window, holding the name as it is.
func _on_rename_pressed() -> void:
	var prompt := TextPrompt.new("Rename", inventory.hero(), "Rename", Inventory.NAME_MOST, ui_scale)
	prompt.entered.connect(_on_name_entered)
	_ui_layer.add_child(prompt)


## What the text box handed back: the character's name from now on, unless it leaves nothing. It asks
## what every save asks: never over a refused save, a reset or the black screen.
func _on_name_entered(text: String) -> void:
	if not _may_save() or not inventory.rename(text):
		return
	_save_inventory()
	if character_page.visible:
		character_page.open()


func _on_settings_pressed() -> void:
	_toggle_left_page(settings_page)


## Inside the settlement the player is standing on: the town page takes the tile panel's edge and the
## bag opens on the other one in shop mode, so what is being sold is already laid out beside the
## counter buying it. The two are one thing on screen and close together.
func _on_town_pressed() -> void:
	var cell := map.selected_cell
	# Not on it yet: walk there, and the town opens on arrival (`_on_player_arrived`).
	if view.town_tier(cell) != -1 and view.can_move_to(cell):
		_town_target = cell
		_on_move_pressed()
		return
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
	tile_panel.panel.hide()
	town_page.show()
	# The bag first and the counter second: which page is up is what `_stand_at_counter` asks.
	_open_left_page(bag_page)
	_stand_at_counter()
	_layout_ui()
	# Drawing the board is reading it, and a town always opens on its board (`TownServices.ORDER`), so
	# this is where the journal comes into the corner.
	_check_tips()


## One of the fortuneteller's aimed spells, asked for and not yet paid: the town and the tile panel
## get out of the way and the map is aimed at, an outline under the cursor -- a patch of them for the
## scour, one tile for the road home. The click is what pays (`_on_cell_aimed`); a right click or
## Escape puts the spell away for nothing.
func _on_spell_aimed(reading: String, price: float, spot: Vector2i) -> void:
	_on_left_page_closed()
	_on_close_pressed()
	_aiming = reading
	_aim_price = price
	_aim_town = spot
	map.aim_radius = FortuneTeller.SCOUR_RADIUS if reading == FortuneTeller.SCOUR else 0


## Land chosen. A spell that could do nothing with it -- a patch with nothing left to show, all seen
## already or past the edge of what the map has made; a tile that is no settlement or cave the player has
## charted -- is refused and the aim stays up, so the town's one casting is never spent on nothing.
func _on_cell_aimed(cell: Vector2i) -> void:
	# A finger's first tap on a tile only chooses it, and the next does the deed (`Cursors.applies`):
	# the outline stands on it either way (`HexMap`), and under a rune its panel comes up to be read,
	# the bag left standing (`_on_tile_clicked`).
	if not Cursors.applies(cell):
		if _aiming.is_empty() and map.has_tile(cell):
			map.select_cell(cell)
		return
	if _aiming.is_empty():
		_rune_on(cell)
		return
	if _aim_price <= 0.0 or inventory.gold < _aim_price:
		return
	var scouring := _aiming == FortuneTeller.SCOUR
	var shown := view.scour(cell) if scouring else 0
	var done := shown > 0 if scouring else view.jump_to(cell)
	if not done:
		# A finger has no right click, and a phone no Escape: a tap where the spell can do nothing puts
		# it away as they would.
		if Cursors.touched:
			_end_aim()
		return
	inventory.gold -= _aim_price
	# A great spell is one a settlement, and it is this town that cast it.
	inventory.towns.visit(_aim_town)[FortuneTeller.ASKED + _aiming] = true
	_save_inventory()
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


## Another counter opened: the bag buys what that counter buys and nothing else. A page of its own
## (skills, bounties, settings) standing in the bag's place leaves the counter's other half missing
## -- the smith with nothing held up to him, no Sell beside a vendor -- so the bag comes back first.
func _on_town_tab_changed(_service: String) -> void:
	if not bag_page.visible and not heirloom_page.visible:
		_open_left_page(bag_page)
		_layout_ui()
	_stand_at_counter()
	# Held upright, the counter over the bag is stood again at the height its new tab needs.
	if _narrow():
		_layout_ui()
	# Her tab or his opened for the first time is where the fortuneteller or the smith speaks.
	_check_tips()


## Points the bag at the town page's open tab. The town's own cell rather than whatever is selected:
## the map is still clickable behind the page, and what an orb is worth is a property of the town the
## player walked into, not of the tile they last looked at.
##
## A town with a gear merchant buys from the bag whichever tab is open: otherwise the same mark that
## sells a level at his counter would throw it away for nothing at the board beside it.
func _stand_at_counter() -> void:
	var tab := town_page.open_tab()
	var services := PackedStringArray() if tab.is_empty() else PackedStringArray([tab])
	if not tab.is_empty() and tab != TownServices.GEAR and town_page.has_counter(TownServices.GEAR):
		services.append(TownServices.GEAR)
	_counter_page().shop(services)


## Quitting mid-fight. A run has written nothing since it began, and `bank_kills` is its write --
## a run left by closing the window found what it found -- and the map goes down as it stands.
func _exit_tree() -> void:
	Cursors.put_away()
	# A refused save built nothing, so there is nothing to bank and nothing that may be written.
	if _resetting or _save_blocked:
		return
	# A descent's bodies are nobody's kills -- what they count towards is for the land -- but a depth
	# it has won is won.
	if _combat != null and _combat.fight.dungeon:
		_bank_depths()
	elif _combat != null:
		Achievements.record(inventory, _combat.fight)
		ledger.bank_kills(_combat.fight.kills())
		# Shut on a won verdict: Collect only puts the panel away, so the tile is charted as it would
		# have been -- or a wall beaten stands again. Nobody is left to hear of the arrival.
		if _combat.fight.victory and not ledger.farming:
			view.arrived.disconnect(_on_player_arrived)
			_chart_won(_combat.cell)
	_save_map()


## The settings page's Reset, once confirmed: deletes the inventory and the map and reloads, which
## generates a new world. The settings are a file of their own and stay.
func _on_reset_pressed() -> void:
	_resetting = true
	# Signed in, the cloud's copy goes first: otherwise the next start-up would bring it back down.
	await cloud.forget_save()
	# Each with any write of it left half-way, which would come back as the save (`SafeFile.remove`). A
	# file that will not go is no reset: the game carries on as it was, and what it holds is written
	# back over whatever did go.
	if not SafeFile.remove(map_path) or not SafeFile.remove(inventory_path):
		push_warning("Reset: a save file could not be deleted, so nothing was reset")
		_resetting = false
		_save_inventory()
		_save_map()
		return
	_reload()


## The fortuneteller's way out, asked for and answered yes: everything on screen goes and the game
## fades to `TranscendPage`, where the player is paid for the world they are leaving. **Nothing is
## written until that page is left** (`_transcend`), so a game closed on it has not transcended.
## The price is checked and never taken, because the purse is one of the things that stays behind.
func _on_transcend_pressed() -> void:
	if inventory.gold < TownPrices.fortune_price(FortuneTeller.TRANSCEND, _town_cell):
		return
	_open_transcend(false)


## Stands the black screen up. `lost` is a world ended by No Second Chances rather than left through
## the fortuneteller: it asks no price, waits for no wall, and makes no heirloom -- or losing a fight
## on purpose would be the cheapest way out there is.
func _open_transcend(lost: bool) -> void:
	if _transcend_page != null:
		return
	_on_left_page_closed()
	_on_close_pressed()
	_show_corner(false)
	_character.hide()
	_transcend_page = TranscendPage.new(inventory, ui_scale, lost)
	_transcend_page.finished.connect(_transcend)
	_ui_layer.add_child(_transcend_page)


## The black screen left behind. The world goes the way Reset sends it -- the map deleted, the scene
## loaded again into a new one -- but the inventory is not deleted: it is written over with what
## `Inventory.transcended` keeps, the heirlooms first among it.
func _transcend() -> void:
	print("Transcended with %d heirloom(s)" % (inventory.stash().total()
			+ inventory.stash().equipment.worn.size()))
	# Written before anything is deleted: a crash between the two leaves the new inventory on the old
	# map, which plays, and never the old inventory on no map at all. Not through `_save_inventory`:
	# this is the next world's inventory, the one write the black screen is there to make.
	var before := FileAccess.get_file_as_string(inventory_path)
	if not inventory.transcended().save(inventory_path):
		return
	# The old map goes with it, and any write of it left half-way (`SafeFile.remove`): back under the
	# new inventory, which has been paid for none of its walls, it would pay every one again. If it
	# will not go, neither has the world: the old inventory is put back and the black screen stays up.
	if not SafeFile.remove(map_path):
		push_warning("Transcend: the map could not be deleted, so the world stays")
		if not before.is_empty():
			SafeFile.write(inventory_path, before)
		return
	_resetting = true
	_reload()


## Every event, before the interface has it: the cursor's own (`Cursors`), a pinch, and a press off a
## banner whose time is up, which puts it down and still lands.
func _input(event: InputEvent) -> void:
	Cursors.feel(event)
	Cursors.twitch(get_tree(), event)
	_pinch(event)
	if banner != null:
		banner.press(event)


## Two fingers spread or pinched over bare map zoom it a whole step at a time (`PINCH_STEP` of spread
## a step) about the point between them, as the wheel does, and so does a trackpad's own pinch.
func _pinch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = event.position
		else:
			_fingers.erase(event.index)
		_pinch_from = _spread()
		return
	var zooms := _combat == null and map.visible and get_viewport().gui_get_hovered_control() == null
	if event is InputEventScreenDrag:
		_fingers[event.index] = event.position
		var spread := _spread()
		if zooms and _pinch_from > 0.0 and spread > 0.0 and absf(log(spread / _pinch_from)) >= log(PINCH_STEP):
			_zoom_at((_fingers.values()[0] + _fingers.values()[1]) / 2.0, signf(spread - _pinch_from))
			_pinch_from = spread
	elif event is InputEventMagnifyGesture and zooms:
		_magnified *= event.factor
		if absf(log(_magnified)) >= log(PINCH_STEP):
			_zoom_at(event.position, signf(_magnified - 1.0))
			_magnified = 1.0


## How far apart the two fingers on the screen are, or 0 with any other number of them down.
func _spread() -> float:
	if _fingers.size() != 2:
		return 0.0
	return (_fingers.values()[0] as Vector2).distance_to(_fingers.values()[1])


## The wheel over bare map, a right click on an aimed spell, the corner's keys, and Escape, which is
## every X at once: the tip if one is up, otherwise the pages, the town and the tile panel together. A
## fight answers for itself (`CombatScene._unhandled_input`) and gets the key first, being further down
## the tree -- except under a tip, where it is not processing and the tip is what closes.
func _unhandled_input(event: InputEvent) -> void:
	# A Control's STOP filter never stops the wheel (only an accepted one does), so a wheel over a
	# panel or a page still lands here: it zooms only with nothing under the cursor but the map.
	if (event is InputEventMouseButton and event.pressed and _combat == null and map.visible
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
			and get_viewport().gui_get_hovered_control() == null):
		_zoom_at(event.position, 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		get_viewport().set_input_as_handled()
		return
	# A right click puts an aimed spell away, the way it puts a held orb down in the bag.
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
			and not _aiming.is_empty()):
		_end_aim()
		get_viewport().set_input_as_handled()
		return
	# A corner key presses its button, and only while that button could be pressed by hand: never under
	# a tip, a pop-up, a camp or the black screen, nor with a modifier held (those are the item card's).
	if (event is InputEventKey and event.pressed and not event.echo and HOTKEYS.has(event.keycode)
			and not (event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed)
			and _tip_panel == null and _transcend_page == null and _camp == null and not _popup_up()):
		var button: Button = get(HOTKEYS[event.keycode])
		if button.is_visible_in_tree() and not button.disabled:
			get_viewport().set_input_as_handled()
			button.pressed.emit()
		return
	# A camp answers for itself: its X and its Break camp are the ways out, so a stray Escape cannot
	# quietly end a night's rest. The black screen of a transcension is the same.
	if not event.is_action_pressed("ui_cancel") or _transcend_page != null or _camp != null:
		return
	get_viewport().set_input_as_handled()
	if _tip_panel != null:
		_on_tip_closed()
	elif rewards.paid != null:
		rewards.leave_paid()
	elif rewards.choice != null:
		rewards.leave_choice()
	elif not _aiming.is_empty():
		_end_aim()
	# A fight answers for itself unless the bag stands over it (`CombatScene.page_up`).
	elif _combat == null or _left_page_up():
		if _left_page_up() or town_page.visible:
			_on_left_page_closed()
		if tile_panel.panel.visible:
			_on_close_pressed()


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	tile_panel.panel.hide()
	map.deselect()
	tile_panel.update_buttons()
	# The character panel has the edge back where a bag page was up beside it (`_character_right`).
	_place_character()
