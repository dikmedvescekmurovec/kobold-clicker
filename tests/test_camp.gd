extends "res://tests/harness.gd"
## Headless checks for camping (`Scenes/Combat/camp.gd`). Run from the project folder:
##   python tests/run_all.py camp
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
	_check(_test_a_camp_pays_whole_coins() == true, "camp whole coin tests ran to the end")
	_check(_test_camp_earnings() == true, "camp earnings line tests ran to the end")
	_check(_test_a_camp_brings_finds() == true, "camp finds tests ran to the end")
	_check(_test_a_camp_survives_the_save() == true, "camp save tests ran to the end")
	_check(await _test_the_map_camps_and_strikes_camp() == true, "the map camps and strikes camp tests ran to the end")
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
	# Four hours of it: the hero's with three walls down.
	var camp := Camp.make(TILE, "Somewhere", _armed(4.0, 4.0), 1000.0, 4.0)
	_check(int(camp[Camp.SINCE]) == 1000, "a camp remembers the hour it was made at")
	_check(Camp.cell_of(camp) == TILE, "and the tile it stands on")
	_check(str(camp[Camp.PLACE]) == "Somewhere", "and what that tile is called")

	var hour := Camp.earned(camp, 1000.0 + 3600.0)
	var two := Camp.earned(camp, 1000.0 + 7200.0)
	_check(float(hour["seconds"]) == 3600.0, "an hour of camp is an hour")
	_check(float(hour[Camp.GOLD]) > 0.0, "and pays")
	_check(absf(float(two[Camp.GOLD]) - float(hour[Camp.GOLD]) * 2.0) <= 1.0,
			"two hours pay twice one, to the coin")
	_check(not bool(hour["full"]), "an hour is not the whole a hero can hold")

	var night := Camp.earned(camp, 1000.0 + 4.0 * 3600.0)
	var week := Camp.earned(camp, 1000.0 + 7.0 * 24.0 * 3600.0)
	_check(bool(night["full"]) and bool(week["full"]), "the cap is reached and then held")
	_check(float(week["seconds"]) == 4.0 * 3600.0, "a week away is capped at the hours the camp holds")
	_check(float(week[Camp.GOLD]) == float(night[Camp.GOLD]), "and paid as them")
	# With no wall down a camp holds its first hour, and every wall is an hour more.
	var first := Camp.earned(Camp.make(TILE, "Somewhere", _armed(4.0, 4.0), 1000.0), 1000.0 + 7200.0)
	_check(bool(first["full"]) and float(first["seconds"]) == WallUnlocks.CAMP_HOURS * 3600.0,
			"a camp nobody gave hours holds the first (%s s)" % first["seconds"])
	_check(WallUnlocks.camp_hours(3) - WallUnlocks.camp_hours(2) == WallUnlocks.CAMP_HOURS_A_WALL
			and WallUnlocks.camp_hours(0) == WallUnlocks.CAMP_HOURS, "and a wall is its hours more")

	var wound_back := Camp.earned(camp, 500.0)
	_check(float(wound_back["seconds"]) == 0.0, "a clock wound backwards pays nothing")
	_check(float(wound_back[Camp.GOLD]) == 0.0, "and no gold with it")

	# Deeper ground is worth more an hour, the way it is worth more a body -- with damage enough
	# that both die in a swing, so what is being compared is the purse and not the health.
	var near := Camp.make(Vector2i(1, 0), "Near", _armed_on(Vector2i(1, 0), 4.0, 40.0), 0.0)
	var far := Camp.make(Vector2i(6, 0), "Far", _armed_on(Vector2i(6, 0), 4.0, 40.0), 0.0)
	_check(float(far[Camp.GOLD]) > float(near[Camp.GOLD]), "a camp deeper out pays more an hour")
	return true


## A camp pays whole coins, as it pays whole experience and whole bodies: a rate is a fraction of a
## coin a second, and a purse with that fraction left in it reads as a coin more than it can pay.
func _test_a_camp_pays_whole_coins() -> bool:
	var third := {Camp.SINCE: 0, Camp.GOLD: 1.0 / 3.0, Camp.XP: 1.0 / 3.0, Camp.KILLS: 1.0 / 3.0,
			Camp.MOST: 8.0 * 3600.0}
	for seconds: float in [1.0, 100.0, 3601.0, 8.0 * 3600.0]:
		var paid := Camp.earned(third, seconds)
		var gold := float(paid[Camp.GOLD])
		var owed := float(third[Camp.GOLD]) * seconds
		_check(gold == floorf(gold) and gold <= owed and gold > owed - 1.0,
				"%s s at a third of a coin a second is whole coins, the fraction left behind (%s of %s)" % [seconds, gold, owed])
		_check(gold == float(int(paid[Camp.XP])), "as much gold as experience, which was always whole")
	return true


## The body armour's Camp Earnings: the same run sampled, and half as much again of its gold, its
## experience and its bodies, whose finds are the camp's too.
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
	_check(is_equal_approx(float(more[Camp.KILLS]), float(bare[Camp.KILLS]) * 1.5), "and bodies")
	return true


## What a camp's bodies drop is the camp's, and they are fought for it: the run played on until that
## many more have fallen, a piece and an orb a body where every body is made to leave both -- on a
## fresh run and on one `make` has sampled -- and nothing a tile's own rule keeps from falling.
func _test_a_camp_brings_finds() -> bool:
	var sampled := _armed(4.0, 40.0)
	Camp.make(TILE, "Here", sampled, 0.0)
	for fight: Encounter in [_armed(4.0, 40.0), sampled]:
		fight.always_drop = true
		fight.always_orb = true
		var before := fight.kills()
		var found := Camp.finds(fight, 6)
		var orbs := 0
		for orb: String in found[Camp.ORBS]:
			orbs += int(found[Camp.ORBS][orb])
		_check(fight.kills() - before >= 6, "a camp's bodies are fought (%d)" % (fight.kills() - before))
		_check(found[Camp.ITEMS].size() == 6 and orbs == 6,
				"and each leaves its piece and its orb (%d, %d)" % [found[Camp.ITEMS].size(), orbs])
		var none := Camp.finds(fight, 0)
		_check(none[Camp.ITEMS].is_empty() and none[Camp.ORBS].is_empty(), "no bodies leave nothing")

	var gilded := Encounter.farm(TILE, ENV, "", ["gilded"])
	gilded.arm({"damage": 40.0, "attack_speed": 4.0})
	gilded.always_drop = true
	_check(Camp.finds(gilded, 6)[Camp.ITEMS].is_empty(), "a Gilded tile's bodies leave no gear in a camp either")
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
func _test_the_map_camps_and_strikes_camp() -> bool:
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
	var held: int = main.inventory.total()
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
	_check(bool(main._camp._earned["full"])
			and float(main._camp._earned["seconds"]) == WallUnlocks.camp_hours(0) * 3600.0,
			"a hero with no wall down held it for the first hour of the three")
	_check(Encounter.SWORD in main.inventory.promised() and main.inventory.total() == held,
			"and brought no finds back while the Broken Sword is still owed")
	# Past the sword, gear falls before Farm stands, but no kind whose first find is still owed.
	var kills: int = main.inventory.kills
	main.inventory.first_sword_taken = true
	var camped := Encounter.farm(best, main.map.get_tile_info(best).get("env", ""))
	_check(main._hand_camp_drops(camped) and camped.orbs_after > 1000000
			and camped.uniques_after == Encounter.NO_UNIQUES and not camped.stone_drops,
			"a camp past the sword drops gear and nothing else a first find is owed for")
	main.inventory.kills = 1000
	camped = Encounter.farm(best, main.map.get_tile_info(best).get("env", ""))
	_check(main._hand_camp_drops(camped) and camped.orbs_after == 0
			and camped.uniques_after == 0 and camped.stone_drops, "and everything once nothing is owed")
	main.inventory.first_sword_taken = false
	main.inventory.kills = kills

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

	# What a camp's bodies dropped goes through the player's own rule on its way into the bag.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var body: String = Encounter.farm(TILE, ENV).lineup[0]
	var wanted := LootTable.roll(body, rng, true)
	var unwanted := LootTable.roll(body, rng, true)
	unwanted.level = wanted.level + 1
	main.inventory.set_autodiscard(unwanted.level, true)
	var dropped: Array[Item] = [wanted, unwanted]
	var orbs: int = main.inventory.orb_count(OrbTable.FIRST_ORB)
	var banked: Dictionary = main._bank_camp_finds({Camp.ITEMS: dropped, Camp.ORBS: {OrbTable.FIRST_ORB: 2}})
	_check(banked[Camp.ITEMS] == [wanted] and int(banked["left"]) == 1,
			"a camp keeps the find the player's rule keeps and leaves the other (%s)" % [banked])
	_check(main.inventory.items.has(wanted) and not main.inventory.items.has(unwanted),
			"and only the kept one is in the bag")
	_check(main.inventory.orb_count(OrbTable.FIRST_ORB) == orbs + 2, "with its orbs")
	_check(not main.ledger.farming, "and the ledger is left a tile fight's, as it was found")
	main.free()
	await process_frame
	_clear_scene()
	return true


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
