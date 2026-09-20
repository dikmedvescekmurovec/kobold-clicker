extends "res://tests/harness.gd"
## Headless checks for camping (`Scenes/Combat/camp.gd`). Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_camp.gd
## Samples real farm runs and does the arithmetic a night of one comes to, with no scene and no window.

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
	_check(_test_a_camp_survives_the_save() == true, "camp save tests ran to the end")
	await _test_the_map_camps_and_strikes_camp()
	_report("camp")


## A camp is armed from the player's gear and fought by the weapon alone: a hero whose weapon does
## not swing itself earns nothing at all, and a better weapon earns more.
func _test_a_camp_is_the_farm_run_nobody_clicks() -> bool:
	var bare := Camp.rates(_armed(0.0, 1.0))
	_check(float(bare[Camp.GOLD]) == 0.0, "a weapon that does not swing on its own earns no gold")
	_check(float(bare[Camp.KILLS]) == 0.0, "and drives nothing off")
	_check(not Camp.hunts(_armed(0.0, 1.0)), "and cannot hold a camp at all")

	var slow := Camp.rates(_armed(1.0, 4.0))
	var fast := Camp.rates(_armed(4.0, 4.0))
	_check(float(slow[Camp.KILLS]) > 0.0, "a weapon that swings drives monsters off")
	_check(float(slow[Camp.GOLD]) > 0.0, "and brings back gold")
	_check(float(slow[Camp.XP]) > 0.0, "and experience")
	_check(float(fast[Camp.KILLS]) > float(slow[Camp.KILLS]),
			"a faster weapon drives more off in the same hour")
	_check(float(fast[Camp.GOLD]) > float(slow[Camp.GOLD]), "and brings back more gold")

	# The Berserker's Band stops the weapon swinging itself, so it stops a camp dead.
	var berserk := _armed(4.0, 4.0)
	berserk.effects = ["berserk"]
	_check(not Camp.hunts(berserk), "a hero whose weapon never swings itself cannot camp")
	_check(float(Camp.rates(berserk)[Camp.KILLS]) == 0.0, "and would drive nothing off")
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


## A camp goes into the save and comes back the same camp, and a save from before there were camps
## reads as a hero who is not resting anywhere.
func _test_a_camp_survives_the_save() -> bool:
	_clear()
	var inventory := Inventory.new()
	inventory.camp = Camp.make(TILE, "Somewhere", _armed(4.0, 4.0), 1000.0)
	var owed := Camp.earned(inventory.camp, 1000.0 + 3600.0)
	_check(inventory.save(SCRATCH_INVENTORY), "an inventory with a camp saves")

	var problem: Array = []
	var read := Inventory.load_from(SCRATCH_INVENTORY, problem)
	_check(problem.is_empty(), "and reads back without complaint")
	_check(not read.camp.is_empty(), "the camp is still there")
	_check(Camp.cell_of(read.camp) == TILE, "on the same tile")
	_check(is_equal_approx(float(Camp.earned(read.camp, 1000.0 + 3600.0)[Camp.GOLD]),
			float(owed[Camp.GOLD])), "and owing exactly what it owed")

	_check(Inventory.new().camp.is_empty(), "a fresh player is camped nowhere")
	# What a version 16 save looks like: every key but this one.
	var older := Inventory.load_from(SCRATCH_INVENTORY, problem)
	older.camp = {}
	older.save(SCRATCH_INVENTORY)
	_check(Inventory.load_from(SCRATCH_INVENTORY, problem).camp.is_empty(),
			"and so is a save that was written before camps existed")
	_clear()
	return true


## The whole of it through the real scene: the button's gate, the screen standing where a fight
## stands, what breaking camp pays, and -- the point of the feature -- a game that comes back to the
## camp it was closed at and pays for the hours it was shut.
func _test_the_map_camps_and_strikes_camp() -> void:
	for path in [SCRATCH_SCENE_INVENTORY, SCRATCH_SCENE_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_SCENE_INVENTORY
	main.map_path = SCRATCH_SCENE_MAP
	root.add_child(main)
	for i in 3:
		await process_frame

	var cell: Vector2i = main.view.player_cell
	main.map.select_cell(cell)
	main._update_buttons()
	_check(main._camp_button.visible, "the tile under the player offers a camp")
	_check(main._camp_button.disabled, "greyed while nothing would swing at it")
	_check(main._cannot_camp() != "", "with the reason on the button")

	# A weapon that swings on its own is the whole of what a camp needs.
	var sword := Item.rolled("Iron Sword", ItemRarity.Rarity.COMMON, RandomNumberGenerator.new())
	main.inventory.items.append(sword)
	main.inventory.equip(sword, main.inventory.equipment.sockets_for(sword)[0])
	main._update_buttons()
	_check(not main._camp_button.disabled, "and armed, the button can be pressed")

	main._on_camp_pressed()
	await process_frame
	_check(not main.inventory.camp.is_empty(), "pressing it makes camp")
	_check(main._camp != null, "and stands the camp screen up")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"with the map away behind it, as a fight has it")
	_check(float(main.inventory.camp[Camp.GOLD]) > 0.0, "a camp with a weapon earns")

	# Escape does nothing here: a stray press must not end a night's rest.
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main._camp != null, "Escape leaves a camp standing")

	# Closed at a camp and opened again: the same camp, and the hours count.
	var made: Dictionary = main.inventory.camp.duplicate()
	main.free()
	await process_frame
	var second: Node = load("res://Scenes/main_scene.tscn").instantiate()
	second.world_seed = WORLD_SEED
	second.map_seed = 1
	second.inventory_path = SCRATCH_SCENE_INVENTORY
	second.map_path = SCRATCH_SCENE_MAP
	root.add_child(second)
	for i in 3:
		await process_frame
	_check(second._camp != null, "a game closed at a camp comes back to it")
	_check(Camp.cell_of(second.inventory.camp) == Camp.cell_of(made), "on the same tile")

	# An hour of it, paid out by the way back to the map.
	second.inventory.camp[Camp.SINCE] = int(Time.get_unix_time_from_system()) - 3600
	var owed := Camp.earned(second.inventory.camp, Time.get_unix_time_from_system())
	var purse: float = second.inventory.gold
	second._break_camp()
	await process_frame
	_check(second._camp == null, "breaking camp takes the screen away")
	_check(second.map.visible and second.map.process_mode == Node.PROCESS_MODE_INHERIT,
			"and brings the map back")
	_check(second.inventory.camp.is_empty(), "the camp is struck")
	_check(is_equal_approx(second.inventory.gold, purse + float(owed[Camp.GOLD])),
			"the hour's gold is in the purse")
	_check(second.inventory.level > 1, "and its experience has been spent on levels")
	_check(Inventory.load_from(SCRATCH_SCENE_INVENTORY).camp.is_empty(),
			"and the save says so")
	second.free()
	await process_frame
	for path in [SCRATCH_SCENE_INVENTORY, SCRATCH_SCENE_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A farm run on TILE, armed by hand: `speed` swings a second at `damage` a swing.
func _armed(speed: float, damage: float) -> Encounter:
	return _armed_on(TILE, speed, damage)


## The same, on a tile of its own: the cell is what decides both the health and the purse.
func _armed_on(cell: Vector2i, speed: float, damage: float) -> Encounter:
	var fight := Encounter.farm(cell, ENV)
	fight.arm({"damage": damage, "attack_speed": speed})
	return fight


func _clear() -> void:
	if FileAccess.file_exists(SCRATCH_INVENTORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_INVENTORY))
