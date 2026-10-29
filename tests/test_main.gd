extends "res://tests/harness.gd"
## The main scene's own rules (`Scenes/main_scene.gd`): when it may write a save and when it refuses
## one, what a closed window keeps, how a fight is opened and left, and the lists it keeps by hand --
## the tips, the left-hand pages, the settings and the web build's music.

const MAIN := preload("res://Scenes/main_scene.gd")
const SCRATCH_INVENTORY := "user://test_main_inventory.json"
const SCRATCH_MAP := "user://test_main_map.json"
const SCRATCH_SETTINGS := "user://test_main_settings.cfg"
const SCRATCH_ACCOUNT := "user://test_main_cloud.cfg"
## The tile beside the start, which a new hero can fight for and win.
const NEXT_DOOR := Vector2i(1, 0)
## The only music the web build carries (the root `CLAUDE.md`).
const WEB_MUSIC: Array[String] = ["Action 2.ogg", "Ambient 1.ogg"]


func _run() -> void:
	_check(await _test_a_headless_run_plays_on_scratch_files() == true, "headless path tests ran to the end")
	_check(await _test_the_black_screen_saves_nothing() == true, "black screen tests ran to the end")
	_check(_test_a_loader_that_says_nothing_is_refused() == true, "silent loader tests ran to the end")
	_check(await _test_a_refused_save_stops_everything() == true, "refusal tests ran to the end")
	_check(await _test_a_won_tile_survives_a_closed_window() == true, "closed window tests ran to the end")
	_check(await _test_reset_and_transcend_leave_no_map() == true, "leftover map tests ran to the end")
	_check(await _test_a_run_is_kept_as_it_goes() == true, "mid-run save tests ran to the end")
	_check(await _test_the_cloud_waits_out_a_camp_and_a_walk() == true, "calm tests ran to the end")
	_check(await _test_a_runes_last_body_is_paid_under_it() == true, "rune tests ran to the end")
	_check(await _test_a_tip_already_up_holds_a_new_fight() == true, "held fight tests ran to the end")
	_check(await _test_a_first_run_opens_on_the_comic() == true, "comic tests ran to the end")
	_check(await _test_no_key_reaches_under_the_clouds_question() == true, "cloud question tests ran to the end")
	_check(await _test_a_retry_refused_runs_the_hero_back() == true, "refused retry tests ran to the end")
	_check(_test_every_tip_has_its_rule() == true, "tip rule tests ran to the end")
	_check(await _test_every_page_has_its_button_and_key() == true, "page list tests ran to the end")
	_check(_test_every_setting_is_saved() == true, "settings tests ran to the end")
	_check(_test_the_web_ships_two_tracks() == true, "web music tests ran to the end")
	_clear()
	_report("main")


## The main scene on the scratch save as it stands, three frames in.
func _launch() -> Node:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	return main


func _clear() -> void:
	for path: String in [SCRATCH_INVENTORY, SCRATCH_MAP]:
		SafeFile.remove(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A veteran's save, every tip read: a tip up holds a fight still.
func _read_tips(main: Node) -> void:
	for tip: Array in MAIN.TIPS:
		main.inventory.tips.append(tip[0])


## Clicks until `count` more bodies are down, eight clicks a second.
func _slay(fight: Encounter, count: int) -> void:
	var until := fight.kills() + count
	for i in 20000:
		if fight.finished or fight.kills() >= until:
			return
		fight.hit()
		fight.advance(0.125)


## Walks onto `cell` and opens its fight (Chart) or a run on it (Farm).
func _fight_for(main: Node, cell: Vector2i, farming := false) -> Encounter:
	main.map.select_cell(cell)
	if farming:
		main._on_farm_pressed()
	else:
		main._on_chart_pressed()
	main.map.player.finish_walk()
	return main._combat.fight


## A headless run left at the player's own paths -- the documented quick check that the game starts --
## never loads, rewrites or uploads the player's saves.
func _test_a_headless_run_plays_on_scratch_files() -> bool:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	root.add_child(main)
	for i in 3:
		await process_frame
	_check(main.inventory_path == MAIN.HEADLESS_INVENTORY and main.map_path == MAIN.HEADLESS_MAP,
			"a headless run pointed nowhere plays on the two scratch files (%s, %s)"
			% [main.inventory_path, main.map_path])
	_check(Settings.path.is_empty(), "off the player's own settings")
	_check(not main.cloud.enabled() and main.cloud.get_parent() == main, "and with the cloud off")
	main.free()
	await process_frame
	for path: String in [MAIN.HEADLESS_INVENTORY, MAIN.HEADLESS_MAP]:
		SafeFile.remove(path)
	return true


## Nothing saves the inventory while the black screen is up: a game closed there has not transcended.
func _test_the_black_screen_saves_nothing() -> bool:
	_clear()
	var main := await _launch()
	_check(main._save_inventory() and FileAccess.file_exists(SCRATCH_INVENTORY), "on the map the scene saves")
	var before := FileAccess.get_file_as_string(SCRATCH_INVENTORY)
	main._open_transcend(false)
	main.inventory.gold += 5.0
	_check(not main._save_inventory(), "on the black screen it does not, which is what the window's close asks")
	main.inventory.level = 2
	main._check_tips()
	main._stop_flash("opened_bag")
	_check(FileAccess.get_file_as_string(SCRATCH_INVENTORY) == before,
			"nor does a tip come due or a button's first press there")
	main.free()
	await process_frame
	_check(FileAccess.get_file_as_string(SCRATCH_INVENTORY) == before, "nor the scene as it goes")
	# One door: a save written past it is a save the black screen cannot stop.
	var source := FileAccess.get_file_as_string("res://Scenes/main_scene.gd")
	_check(source.count("inventory.save(inventory_path)") == 1,
			"every inventory save of the main scene's goes through _save_inventory")
	return true


## A loader that hands back nothing and says nothing about a file that is there is no first run.
func _test_a_loader_that_says_nothing_is_refused() -> bool:
	_clear()
	var problem: Array = []
	MAIN._unread(SCRATCH_MAP, null, problem)
	_check(problem.is_empty(), "no file at all is a first run")
	_write(SCRATCH_MAP, "{}")
	MAIN._unread(SCRATCH_MAP, RefCounted.new(), problem)
	_check(problem.is_empty(), "a file that loaded is not in question")
	MAIN._unread(SCRATCH_MAP, null, problem)
	_check(problem.size() == 1, "a file that is there and gave nothing is refused, whatever the loader said")
	MAIN._unread(SCRATCH_MAP, null, problem)
	_check(problem.size() == 1, "and a loader's own reason stands alone")
	# A write that never got its name is still the save.
	_clear()
	_write(SCRATCH_MAP + SafeFile.TMP, "{}")
	problem.clear()
	MAIN._unread(SCRATCH_MAP, null, problem)
	_check(problem.size() == 1 and FileAccess.file_exists(SCRATCH_MAP), "and so is one left half-way")
	return true


## A save refused: nothing is written, the cloud moves neither file, and no key or wheel reaches the
## interface that was never built.
func _test_a_refused_save_stops_everything() -> bool:
	_clear()
	_write(SCRATCH_INVENTORY, "not a save")
	var main := await _launch()
	_check(main._save_blocked and main.cloud.blocked, "a refused save blocks the cloud with the rest")
	_check(not main.is_processing() and not main.is_processing_input() and not main.is_processing_unhandled_input(),
			"and the scene takes no frame and no input")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for event: InputEvent in [escape, key, wheel]:
		Input.parse_input_event(event)
		await process_frame
		await process_frame
	main.free()
	await process_frame
	_check(FileAccess.get_file_as_string(SCRATCH_INVENTORY) == "not a save" and not FileAccess.file_exists(SCRATCH_MAP),
			"the file is left exactly as it is, and no map is made beside it")
	# The next scene judges its own files.
	_clear()
	main = await _launch()
	_check(not main._save_blocked and not main.cloud.blocked and main.is_processing_unhandled_input(),
			"a save that reads plays")
	main.free()
	await process_frame
	return true


## Only Collect charts a won tile, so a window closed on the verdict has to as well.
func _test_a_won_tile_survives_a_closed_window() -> bool:
	_clear()
	var main := await _launch()
	_read_tips(main)
	var fight := _fight_for(main, NEXT_DOOR)
	_slay(fight, fight.enemies)
	_check(fight.victory and main._combat != null and not main.view.charted(NEXT_DOOR),
			"won, the verdict is up and the tile waits for Collect")
	main.free()
	await process_frame
	main = await _launch()
	_check(main.view.charted(NEXT_DOOR) and main.view.player_cell == NEXT_DOOR,
			"a window closed on the verdict keeps the tile, the hero on it")
	main.free()
	await process_frame
	return true


## A new world starts on no map: not the old one, nor a write of it left half-way, which a recovery
## would put back as the save.
func _test_reset_and_transcend_leave_no_map() -> bool:
	_clear()
	var main := await _launch()
	_write(SCRATCH_MAP + SafeFile.TMP, "{}")
	main._open_transcend(false)
	main._transcend()
	_check(not FileAccess.file_exists(SCRATCH_MAP) and not FileAccess.file_exists(SCRATCH_MAP + SafeFile.TMP),
			"a transcension leaves no map and no half-written one")
	_check(FileAccess.file_exists(SCRATCH_INVENTORY), "beside the next world's inventory")
	main.free()
	await process_frame
	_check(not FileAccess.file_exists(SCRATCH_MAP), "and the scene it left writes none back")

	main = await _launch()
	main._save_inventory()
	for path: String in [SCRATCH_INVENTORY, SCRATCH_MAP]:
		_write(path + SafeFile.TMP, "{}")
	await main._on_reset_pressed()
	var left := [SCRATCH_INVENTORY, SCRATCH_MAP].filter(func(path: String) -> bool:
		return FileAccess.file_exists(path) or FileAccess.file_exists(path + SafeFile.TMP))
	_check(left.is_empty(), "a reset leaves neither save and no half-written one (%s)" % [left])
	main.free()
	await process_frame
	return true


## What the web build writes as its tab loses the focus (`_keep_run`): a run's gains, as often as asked,
## and never its kills, which are counted once as it ends; a descent's depths the same.
func _test_a_run_is_kept_as_it_goes() -> bool:
	_clear()
	var main := await _launch()
	_read_tips(main)
	var fight := _fight_for(main, main.view.best_farm(), true)
	_slay(fight, 2)
	main._on_gold_gained(7.0)
	_check(not is_equal_approx(Inventory.load_from(SCRATCH_INVENTORY).gold, main.inventory.gold),
			"a run writes nothing of its own")
	main._keep_run()
	main._keep_run()
	var kept := Inventory.load_from(SCRATCH_INVENTORY)
	_check(is_equal_approx(kept.gold, main.inventory.gold) and kept.kills == 0,
			"kept, its gold is on disk and its kills are not yet")
	fight.stop()
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.kills == 2, "and they are counted once when it ends (%d)" % main.inventory.kills)

	main._on_dungeon_pressed()
	fight = main._combat.fight
	fight.damage = 1.0e30
	_slay(fight, 2)
	main._keep_run()
	main._keep_run()
	_check(Inventory.load_from(SCRATCH_INVENTORY).dungeon_floors == 2, "a descent's floors are kept as it goes")
	main._on_dungeon_finished(false)
	await process_frame
	_check(main.inventory.dungeon_floors == 2 and main.inventory.dungeon_depth == 0,
			"and are the same floors when it ends, with no depth won short of Gollux")
	main.free()
	await process_frame
	return true


## The cloud asks nothing and replaces nothing over a camp or on the walk to a fight, and syncs as the
## camp is struck.
func _test_the_cloud_waits_out_a_camp_and_a_walk() -> bool:
	_clear()
	var main := await _launch()
	_read_tips(main)
	_check(main.cloud.calm.call(), "on the map the game is calm")
	main.map.select_cell(NEXT_DOOR)
	main._on_chart_pressed()
	_check(main.view.walking and main._combat == null and not main.cloud.calm.call(),
			"not on the walk to a fight, which would open under a question")
	main._save_inventory()
	main.free()
	await process_frame

	# Three hours shut: the start-up stands a camp up before its first sync.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_INVENTORY))
	data["saved_at"] = Time.get_unix_time_from_system() - 3.0 * 3600.0
	_write(SCRATCH_INVENTORY, JSON.stringify(data))
	main = await _launch()
	_check(main._camp != null and not main.cloud.calm.call(), "nor over a camp")
	var asked: Array = []
	main.cloud.path = SCRATCH_ACCOUNT
	main.cloud.token = "t"
	main.cloud.inventory_path = SCRATCH_INVENTORY
	main.cloud.map_path = SCRATCH_MAP
	main.cloud.transport = func(_method: int, route: String, _body: Variant, _bearer: String) -> Dictionary:
		asked.append(route)
		return {"status": 0, "data": {}}
	main._break_camp()
	_check(asked == ["/me"], "striking camp syncs at once (%s)" % [asked])
	main.cloud.token = ""
	main.free()
	await process_frame
	return true


## A rune's last kill is fought under the rune, so it is paid under it too: the rune runs out after the
## body's loot, not before.
func _test_a_runes_last_body_is_paid_under_it() -> bool:
	_clear()
	var main := await _launch()
	_read_tips(main)
	var ground: Vector2i = main.view.best_farm()
	var spot: Vector2i = main.view.origin + ground
	var work: Dictionary = main.inventory.rune_state(spot)
	RuneTable.apply(RuneTable.DEPTH, [], work, RandomNumberGenerator.new())
	work["depth"][0] = 1
	var fight := _fight_for(main, ground, true)
	_check(fight.deeper == 1, "a Depth with one kill left has the run a level deeper")
	var paid_at: Array = []
	fight.xp_dropped.connect(func(_index: int, _amount: int) -> void: paid_at.append(fight.deeper))
	_slay(fight, 1)
	_check(paid_at == [1], "its last body is paid a level deeper, as it was fought (%s)" % [paid_at])
	_check(fight.deeper == 0 and RuneTable.deeper(main.inventory.rune_work(spot)) == 0,
			"and the rune is gone from the next body on")
	main.free()
	await process_frame
	return true


## A fight opened while a tip is already up -- a first find's, under Retry -- is held still under it.
func _test_a_tip_already_up_holds_a_new_fight() -> bool:
	_clear()
	var main := await _launch()
	main._tip_queue.append(MAIN.TIPS[0])
	main._show_next_tip()
	_check(main._tip_panel != null and main._combat == null, "a tip is up with no fight under it")
	main._open_fight(Encounter.for_tile(NEXT_DOOR, main.view.env_at(NEXT_DOOR), main.view.area_variant(NEXT_DOOR)),
			NEXT_DOOR, false)
	_check(main._combat.process_mode == Node.PROCESS_MODE_DISABLED, "the fight opened under it does not run")
	for i in MAIN.TIPS.size():
		if main._tip_panel != null:
			main._on_tip_closed()
	_check(main._tip_panel == null and main._combat.process_mode == Node.PROCESS_MODE_INHERIT,
			"and runs once the last tip is closed")
	main.free()
	await process_frame
	return true


## A first run opens on the comic, once: owed only by a save no body has fallen in, never off the
## player's own save, marked seen as it is queued, held over the corner keys, let go by Escape; a press
## brings on each panel and the one after the last lets it go.
func _test_a_first_run_opens_on_the_comic() -> bool:
	_clear()
	var main := await _launch()
	_check(main._tip_panel == null, "a scratch save opens on the map")
	_check(Comic.owed(main.inventory), "though a save no body has fallen in is owed the comic")
	var veteran := Inventory.new()
	veteran.kills = 1
	_check(not Comic.owed(veteran), "and one with a body down is not")
	main._queue_comic()
	_check(main._tip_panel is Comic, "queued, it stands over the window")
	_check(Comic.ID in main.inventory.tips and not Comic.owed(main.inventory), "marked seen as it comes up")
	var key := InputEventKey.new()
	key.keycode = KEY_O
	key.pressed = true
	main._unhandled_input(key)
	_check(not main.settings_page.visible, "no corner key opens a page under it")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	main._unhandled_input(escape)
	_check(main._tip_panel == null, "Escape lets it go")
	var comic := Comic.new(1.0)
	root.add_child(comic)
	var ended := [0]
	comic.finished.connect(func() -> void: ended[0] += 1)
	for i in comic.presses() - 1:
		comic.advance()
	_check(ended[0] == 0, "every panel but the first comes up a press at a time")
	comic.advance()
	_check(ended[0] == 1, "and the press after the last lets it go")
	comic.free()
	main.free()
	await process_frame
	return true


## The cloud's question is a pop-up like a page's: no corner key opens a page beneath it.
func _test_no_key_reaches_under_the_clouds_question() -> bool:
	_clear()
	var main := await _launch()
	main.cloud.question = {"local": {}, "cloud": {}}
	main._on_cloud_asked()
	_check(main._cloud_question != null and main._popup_up(), "the cloud's question stands over the window")
	var key := InputEventKey.new()
	key.keycode = KEY_O
	key.pressed = true
	main._unhandled_input(key)
	_check(not main.settings_page.visible, "and a corner key opens nothing under it")
	main.free()
	await process_frame
	return true


## Retry with the bag past its cap opens no fight, and must not leave the hero on the uncharted tile.
func _test_a_retry_refused_runs_the_hero_back() -> bool:
	_clear()
	var main := await _launch()
	_read_tips(main)
	var fight := _fight_for(main, NEXT_DOOR)
	while not main.inventory.encumbered():
		var piece := Item.new()
		piece.type = "Wooden Sword"
		piece.stats = Item.scaled_stats(piece.type, 1)
		main.inventory.add(piece)
	fight.give_up()
	main._combat.retry.emit()
	_check(main._combat == null and not main.view.charted(NEXT_DOOR), "a bag too heavy has no second go")
	_check(main.view.walking, "and the hero runs back off the tile")
	main.map.player.finish_walk()
	_check(main.view.player_cell == MapBuilder.CENTER and main._dark_way.is_empty(),
			"to the charted tile they stepped onto it from")
	main.free()
	await process_frame
	return true


## Every tip in `TIPS` has a rule in `_tip_due` and every rule a tip, and each is spoken: the plain
## panel is the changelog's alone.
func _test_every_tip_has_its_rule() -> bool:
	var body := FileAccess.get_file_as_string("res://Scenes/main_scene.gd").get_slice(
			"func _tip_due(", 1).get_slice("\nfunc ", 0)
	var ruled: Array = []
	for arm: RegExMatch in RegEx.create_from_string("\\n\\t\\t\"(\\w+)\":").search_all(body):
		ruled.append(arm.get_string(1))
	var named: Array = MAIN.TIPS.map(func(tip: Array) -> String: return tip[0])
	_check(not ruled.is_empty(), "the rules are read off _tip_due")
	for id: String in named:
		_check(id in ruled, "the tip %s has a rule for when it is due" % id)
	for id: String in ruled:
		_check(id in named, "the rule %s has a tip to show" % id)
	for tip: Array in MAIN.TIPS:
		_check(tip.size() == 4 and tip[2] is Array, "%s is spoken by someone, in pages" % tip[0])
	return true


## The lists kept by hand agree: every corner button opens a left-hand page of its own, every such page
## has one, and every corner key names one of those buttons.
func _test_every_page_has_its_button_and_key() -> bool:
	_clear()
	var main := await _launch()
	var buttons: Array = Array(main._corner_buttons()) + [main._character_button]
	var opened: Array = []
	for button: Button in buttons:
		button.pressed.emit()
		var page: Control = main._left_page()
		_check(page != null and page not in opened, "%s opens a page of its own" % button.tooltip_text)
		opened.append(page)
		button.pressed.emit()
		_check(main._left_page() == null, "and pressed again puts it away")
	for page: Control in main._left_pages():
		_check(page in opened, "every left-hand page has a button (%s)" % page.get_script().resource_path.get_file())
	_check(main.HOTKEYS.size() == buttons.size(), "every one of them has a key")
	for key: int in main.HOTKEYS:
		_check(main.get(main.HOTKEYS[key]) in buttons,
				"%s presses a corner button (%s)" % [OS.get_keycode_string(key), main.HOTKEYS[key]])
	main.free()
	await process_frame
	return true


## Every setting is written by `save` and read back by `load_settings`: a new one that is not fails here,
## where in the game it would be silent (the tests run with no settings file).
func _test_every_setting_is_saved() -> bool:
	var settings: Script = Settings
	var names: Array[String] = []
	for property: Dictionary in settings.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "path":
			names.append(property.name)
	_check("music_volume" in names and "wall_hp" in names, "the settings are read off the script (%s)" % [names])
	var defaults := {}
	var moved := {}
	for setting in names:
		var value: Variant = settings.get(setting)
		defaults[setting] = value
		match typeof(value):
			TYPE_BOOL:
				moved[setting] = not value
			TYPE_INT:
				moved[setting] = 2 if value == 1 else 1
			TYPE_FLOAT:
				moved[setting] = 0.25 if value != 0.25 else 0.5
			TYPE_STRING:
				moved[setting] = "moved"
			TYPE_ARRAY:
				moved[setting] = range(1, value.size() + 1).map(func(n: int) -> float: return float(n))
			_:
				_check(false, "%s is of a kind this test does not know how to move" % setting)
				moved[setting] = value
		settings.set(setting, moved[setting])
	Settings.path = SCRATCH_SETTINGS
	Settings.save()
	for setting in names:
		settings.set(setting, defaults[setting])
	Settings.load_settings()
	for setting in names:
		_check(settings.get(setting) == moved[setting], "%s is saved and loaded (%s, not %s)"
				% [setting, settings.get(setting), moved[setting]])
	for setting in names:
		settings.set(setting, defaults[setting])
	Settings.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SETTINGS))
	return true


## The web build carries two tracks, and its preset leaves the rest out one by one: a track dropped
## into the folder ships with it unless the preset says otherwise.
func _test_the_web_ships_two_tracks() -> bool:
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "the export presets read")
	var excluded := PackedStringArray()
	for section in presets.get_sections():
		if str(presets.get_value(section, "name", "")) == "Web":
			excluded = str(presets.get_value(section, "exclude_filter", "")).split(",")
	var tracks := ResourceLoader.list_directory(Jukebox.MUSIC_DIR)
	_check(tracks.size() > WEB_MUSIC.size(), "the music is read off its folder (%d)" % tracks.size())
	for track in tracks:
		var path: String = Jukebox.MUSIC_DIR.trim_prefix("res://").path_join(track)
		var left_out := false
		for pattern in excluded:
			left_out = left_out or path.matchn(pattern.strip_edges())
		_check(left_out != (track in WEB_MUSIC), "%s is %s" % [track,
				"left out of the web build, which plays it" if left_out else "packed into the web build, which never plays it"])
	return true
