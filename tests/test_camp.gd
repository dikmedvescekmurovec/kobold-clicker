extends "res://tests/harness.gd"
## Headless checks for camping (`Scenes/Combat/camp.gd`). Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_camp.gd
## Samples real farm runs and does the arithmetic a night of one comes to, then camps through the scene.

const SCRATCH_INVENTORY := "user://test_camp_inventory.json"
## The scene test explores and saves, so never the player's own two files.
const SCRATCH_SCENE_INVENTORY := "user://test_camp_scene_inventory.json"
const SCRATCH_SCENE_MAP := "user://test_camp_scene_map.json"

## A tile a few steps out, so a body is worth more than the very middle's and the sums have room.
const TILE := Vector2i(3, 0)
const ENV := "grass"


func _run() -> void:
	_check(_test_a_camp_is_the_farm_run_nobody_clicks() == true, "camp rate tests ran to the end")
	_check(_test_what_a_camp_pays() == true, "camp earning tests ran to the end")
	_check(_test_camp_earnings() == true, "camp earnings line tests ran to the end")
	_check(_test_a_camp_survives_the_save() == true, "camp save tests ran to the end")
	await _test_the_map_camps_and_strikes_camp()
	_report("camp")


## A camp is the farm run played actively, cut to a share: a hero whose weapon does not swing
## still earns by the clicks, a better weapon earns more.
func _test_a_camp_is_the_farm_run_nobody_clicks() -> bool:
	var bare := Camp.rates(_armed(0.0, 4.0))
	_check(float(bare[Camp.GOLD]) > 0.0, "clicks alone bring back gold")
	_check(float(bare[Camp.KILLS]) > 0.0, "and drive monsters off")

	var slow := Camp.rates(_armed(1.0, 4.0))
	var fast := Camp.rates(_armed(4.0, 4.0))
	_check(float(slow[Camp.XP]) > 0.0, "a camp brings back experience")
	_check(float(fast[Camp.KILLS]) > float(slow[Camp.KILLS]),
			"a faster weapon drives more off in the same hour")
	_check(float(fast[Camp.GOLD]) > float(slow[Camp.GOLD]), "and brings back more gold")
	return true


## What a camp pays is the rate times the hours, up to the cap -- and never a negative number, a
## system clock being something a player can wind backwards.
func _test_what_a_camp_pays() -> bool:
	var camp := Camp.make(TILE, "Somewhere", _armed(4.0, 4.0), 1000.0)
	_check(int(camp[Camp.SINCE]) == 1000, "a camp remembers the hour it was made at")
	_check(Camp.cell_of(camp) == TILE, "and the tile it stands on")
	_check(str(camp[Camp.PLACE]) == "Somewhere", "and what that tile is called")

	var hour := Camp.earned(camp, 1000.0 + 3600.0)
	var two := Camp.earned(camp, 1000.0 + 7200.0)
	_check(float(hour["seconds"]) == 3600.0, "an hour of camp is an hour")
	_check(float(hour[Camp.GOLD]) > 0.0, "and pays")
	_check(is_equal_approx(float(two[Camp.GOLD]), float(hour[Camp.GOLD]) * 2.0),
			"two hours pay twice one")
	_check(not bool(hour["full"]), "an hour is not the whole a hero can hold")

	var night := Camp.earned(camp, 1000.0 + Camp.MAX_SECONDS)
	var week := Camp.earned(camp, 1000.0 + 7.0 * 24.0 * 3600.0)
	_check(bool(night["full"]) and bool(week["full"]), "the cap is reached and then held")
	_check(float(week["seconds"]) == Camp.MAX_SECONDS, "a week away is capped at a night")
	_check(float(week[Camp.GOLD]) == float(night[Camp.GOLD]), "and paid as one")

	var wound_back := Camp.earned(camp, 500.0)
	_check(float(wound_back["seconds"]) == 0.0, "a clock wound backwards pays nothing")
	_check(float(wound_back[Camp.GOLD]) == 0.0, "and no gold with it")

	# Deeper ground is worth more an hour, the way it is worth more a body -- with damage enough
	# that both die in a swing, so what is being compared is the purse and not the health.
	var near := Camp.make(Vector2i(1, 0), "Near", _armed_on(Vector2i(1, 0), 4.0, 40.0), 0.0)
	var far := Camp.make(Vector2i(6, 0), "Far", _armed_on(Vector2i(6, 0), 4.0, 40.0), 0.0)
	_check(float(far[Camp.GOLD]) > float(near[Camp.GOLD]), "a camp deeper out pays more an hour")
	return true


## The body armour's Camp Earnings: the same run sampled, and half as much again of its gold and its
## experience, and not one body more.
func _test_camp_earnings() -> bool:
	var plain := _armed(4.0, 40.0)
	var paid := Encounter.farm(TILE, ENV)
	paid.lineup = plain.lineup.duplicate()
	paid.health = plain.health.duplicate()
	paid.hp = plain.hp
	paid.arm({"damage": 40.0, "attack_speed": 4.0, "camp_earnings": 50.0})
	for fight: Encounter in [plain, paid]:
		fight.roster_rng.seed = WORLD_SEED
	var bare := Camp.make(TILE, "Here", plain, 0.0)
	var more := Camp.make(TILE, "Here", paid, 0.0)
	_check(float(bare[Camp.GOLD]) > 0.0 and is_equal_approx(float(more[Camp.GOLD]), float(bare[Camp.GOLD]) * 1.5),
			"half as much gold again (%s, %s)" % [bare[Camp.GOLD], more[Camp.GOLD]])
	_check(is_equal_approx(float(more[Camp.XP]), float(bare[Camp.XP]) * 1.5), "and experience")
	_check(is_equal_approx(float(more[Camp.KILLS]), float(bare[Camp.KILLS])), "for the same bodies")
	return true


## The hour the save was written goes into it and comes back, and a version 22 save camped by hand
## counts from that camp's hour.
func _test_a_camp_survives_the_save() -> bool:
	_clear()
	var inventory := Inventory.new()
	_check(inventory.save(SCRATCH_INVENTORY), "an inventory saves")
	var problem: Array = []
	var read := Inventory.load_from(SCRATCH_INVENTORY, problem)
	_check(problem.is_empty(), "and reads back without complaint")
	_check(absf(read.saved_at - Time.get_unix_time_from_system()) < 5.0, "stamped with the hour it was written")
	_check(Inventory.new().saved_at == 0.0, "a fresh player has never left")

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_INVENTORY))
	data.erase("saved_at")
	data["camp"] = {Camp.SINCE: 1000}
	_write(SCRATCH_INVENTORY, data)
	_check(Inventory.load_from(SCRATCH_INVENTORY, problem).saved_at == 1000.0,
			"an old save camped by hand counts from that camp")
	data.erase("camp")
	_write(SCRATCH_INVENTORY, data)
	_check(Inventory.load_from(SCRATCH_INVENTORY, problem).saved_at == 0.0,
			"and one camped nowhere is owed nothing")
	_clear()
	return true


## The whole of it through the real scene: nothing to press, a game opened hours after it was shut
## camps on the best ground taken, pays at once, and the way back to the map brings the map back.
func _test_the_map_camps_and_strikes_camp() -> void:
	_clear_scene()
	var main := await _launch()
	_check(main._camp == null, "a first run has been nowhere")
	var best: Vector2i = main.view.best_farm()
	_check(best != HexMap.NO_CELL, "the start offers ground to camp on")
	main.inventory.save(SCRATCH_SCENE_INVENTORY)
	main.free()
	await process_frame

	# Opened again at once: a minute is not worth a camp.
	main = await _launch()
	_check(main._camp == null, "a game opened straight back is not camped")
	var purse: float = main.inventory.gold
	main.free()
	await process_frame

	# Three hours shut.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_SCENE_INVENTORY))
	data["saved_at"] = Time.get_unix_time_from_system() - 3.0 * 3600.0
	_write(SCRATCH_SCENE_INVENTORY, data)
	main = await _launch()
	_check(main._camp != null, "a game shut for hours comes back to a camp")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"with the map away behind it, as a fight has it")
	_check(main.inventory.gold > purse, "and it is paid already")
	_check(main.inventory.level > 1, "experience and all")
	_check(is_equal_approx(Inventory.load_from(SCRATCH_SCENE_INVENTORY).gold, main.inventory.gold),
			"and the save says so")

	# Escape does nothing here: a stray press must not throw the report away unread.
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main._camp != null, "Escape leaves a camp standing")

	var paid: float = main.inventory.gold
	main._break_camp()
	await process_frame
	_check(main._camp == null, "breaking camp takes the screen away")
	_check(main.map.visible and main.map.process_mode == Node.PROCESS_MODE_INHERIT,
			"and brings the map back")
	_check(main.inventory.gold == paid, "without paying twice")
	main.free()
	await process_frame
	_clear_scene()


func _launch() -> Node:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_SCENE_INVENTORY
	main.map_path = SCRATCH_SCENE_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	return main


## A farm run on TILE, armed by hand: `speed` swings a second at `damage` a swing.
func _armed(speed: float, damage: float) -> Encounter:
	return _armed_on(TILE, speed, damage)


## The same, on a tile of its own: the cell is what decides both the health and the purse.
func _armed_on(cell: Vector2i, speed: float, damage: float) -> Encounter:
	var fight := Encounter.farm(cell, ENV)
	fight.arm({"damage": damage, "attack_speed": speed})
	return fight


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _clear() -> void:
	if FileAccess.file_exists(SCRATCH_INVENTORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_INVENTORY))


func _clear_scene() -> void:
	for path in [SCRATCH_SCENE_INVENTORY, SCRATCH_SCENE_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
