extends "res://tests/combat_base.gd"
## Headless checks for the tile fight. Run from the project folder:
##   python tests/run_all.py combat_fights
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.


func _run() -> void:
	_clear_saves()
	_check(_test_health() == true, "health tests ran to the end")
	_check(_test_a_won_fight() == true, "won fight tests ran to the end")
	_check(_test_the_ice_wall() == true, "ice wall tests ran to the end")
	_check(_test_the_dungeon() == true, "dungeon tests ran to the end")
	_check(_test_runes_in_the_fight() == true, "rune fight tests ran to the end")
	_check(_test_a_lost_fight() == true, "lost fight tests ran to the end")
	_check(_test_enemy_strikes() == true, "enemy strike tests ran to the end")
	_check(_test_guard_capstones() == true, "guard capstone tests ran to the end")
	_check(_test_hits_only_land_on_a_waiting_enemy() == true, "hit timing tests ran to the end")
	_check(_test_unique_drops() == true, "unique drop tests ran to the end")
	_check(_test_unique_effects() == true, "unique effect tests ran to the end")
	_check(_test_more_unique_effects() == true, "second batch unique effect tests ran to the end")
	_check(_test_dominoes() == true, "dominoes tests ran to the end")
	_check(_test_unique_ranks() == true, "unique rank tests ran to the end")
	_check(_test_rank_four() == true, "rank IV tests ran to the end")
	_check(_test_a_farm_run_never_ends() == true, "farm run tests ran to the end")
	_check(_test_a_settlement_is_a_set_piece() == true, "settlement fight tests ran to the end")
	_check(_test_a_chest_is_a_mimic() == true, "chest fight tests ran to the end")
	_check(await _test_the_map_hands_over_and_takes_back() == true, "the map hands over and takes back tests ran to the end")
	_check(await _test_the_nightwalkers_fight_their_way() == true, "the nightwalkers fight their way tests ran to the end")
	_report("combat: fights")


## Health grows with the walk from the middle of the map, and with the enemy's own size and tier.
func _test_health() -> bool:
	# The settings' balancing page scales a body by the walls inside its tile, and never the ice wall.
	var past_one := Vector2i(MapBuilder.START_LAND_RADIUS + 5, 0)
	var plain := Encounter.hp_of("Centaur", past_one)
	var wall := Encounter.hp_of(Encounter.WALL_NAME, past_one)
	var inner := Encounter.hp_of("Centaur", Vector2i(5, 0))
	var circle := Encounter.walls_inside(past_one)
	Settings.wall_hp[circle] = Encounter.circle_base_hp(circle) * 2.0
	_check(Encounter.hp_of("Centaur", past_one) == roundf(plain * 2.0),
			"a base number twice the formula's doubles this circle's bodies")
	_check(Encounter.hp_of("Centaur", Vector2i(5, 0)) == inner, "and leaves another circle's alone")
	_check(Encounter.hp_of(Encounter.WALL_NAME, past_one) == wall, "and never the ice wall")
	Settings.wall_hp = [0.0, 0.0, 0.0]
	_check(SettingsPage._nudged(5.0, "/10") == 1.0 and SettingsPage._nudged(1.0, "-1") == 1.0
			and SettingsPage._nudged(7.0, "x10") == 70.0 and SettingsPage._nudged(7.0, "+1") == 8.0,
			"the page's buttons step the number and never take it under 1")
	var near := Vector2i(1, 0)
	var far := Vector2i(20, 0)
	_check(HexGrid.distance(MapBuilder.CENTER, near) == 1, "the near cell is the first ring")
	_check(Encounter.base_hp(MapBuilder.CENTER) == Encounter.BASE_HP, "an ordinary body in the middle")
	_check(Encounter.base_hp(far) > Encounter.base_hp(near), "and a tougher one at the edge")

	# Health is exponential in the walk, not a flat sum: every step multiplies by HP_GROWTH, so the
	# frontier pulls away from whatever the player is carrying. Checked step by step out to the wall,
	# with the slack that rounding to whole points of health allows. Only to the wall: past one the
	# curve has a second term, pinned below.
	for steps in range(1, MapBuilder.START_LAND_RADIUS + 2):
		var here := Vector2i(steps, 0)
		var back := Vector2i(steps - 1, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		_check(Encounter.base_hp(here) > Encounter.base_hp(back),
				"step %d is tougher than step %d" % [steps, steps - 1])
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps)
		_check(absf(Encounter.base_hp(here) - want) <= 0.5,
				"step %d is %d, not the curve's %.1f" % [steps, Encounter.base_hp(here), want])

	# The other term: every wall behind a cell multiplies its bodies by WALL_GROWTH, so the land a
	# fallen wall opens is a frontier again rather than a walkover to whoever just broke through. A
	# wall's own ring counts none of itself -- it is the edge of the land inside it -- so the step
	# lands on the first ring past a wall and the wall itself stays what its dial says.
	var wall_ring := MapBuilder.START_LAND_RADIUS + 1
	for steps: int in [1, MapBuilder.START_LAND_RADIUS, wall_ring]:
		_check(Encounter.walls_inside(Vector2i(steps, 0)) == 0,
				"no wall stands inside step %d" % steps)
	for walls: int in [1, 2, 3]:
		var first := wall_ring + (walls - 1) * MapBuilder.WALL_STEP + 1
		for steps in range(first, wall_ring + walls * MapBuilder.WALL_STEP + 1):
			_check(Encounter.walls_inside(Vector2i(steps, 0)) == walls,
					"%d wall(s) stand inside step %d" % [walls, steps])
	for walls in range(0, 4):
		var steps := wall_ring + walls * MapBuilder.WALL_STEP + 1
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps) * pow(Encounter.LAND_GROWTH, walls + 1)
		_check(absf(Encounter.base_hp(Vector2i(steps, 0)) / want - 1.0) < 0.01,
				"step %d is %s, not the curve's %s past %d wall(s)"
				% [steps, BigNumber.format(Encounter.base_hp(Vector2i(steps, 0))),
					BigNumber.format(want), walls + 1])
	# Rounding to whole points of health is why this is a ratio with slack rather than an equality: the
	# first ring past a wall is one step and one whole wall harder than the wall's own ring.
	var across := Encounter.base_hp(Vector2i(wall_ring + 1, 0)) / Encounter.base_hp(Vector2i(wall_ring, 0))
	_check(absf(across / (Encounter.HP_GROWTH * Encounter.LAND_GROWTH) - 1.0) < 0.01,
			"crossing the wall is one step and one wall at once (x%.2f)" % across)

	for enemy in EnemyRoster.names():
		_check(Encounter.hp_of(enemy, near) >= 1, "%s is worth at least one click" % enemy)
		_check(Encounter.hp_of(enemy, far) > Encounter.hp_of(enemy, near), "%s is tougher further out" % enemy)
	_check(Encounter.hp_of("Grass Slime", near) < Encounter.hp_of("Skeleton Warrior", near), "a slime is the softest")

	# The map has no edge, and health is exponential in the walk: an int64 ran out about 250 hexes
	# out and came back negative, which made the frontier a walkover. A double reaches some 4,200.
	var deep := Encounter.base_hp(MapBuilder.CENTER + Vector2i(300, 0))
	var shallower := Encounter.base_hp(MapBuilder.CENTER + Vector2i(299, 0))
	_check(is_finite(deep) and deep > 0.0,
			"a body 300 steps out has real health (%s)" % BigNumber.format(deep))
	_check(deep > shallower, "and more of it than one 299 steps out (%s)"
			% BigNumber.format(shallower))

	# The elite is the wall at the end: it must outlast any common the same tile can send.
	var fight := Encounter.for_tile(near, "grass")
	var elite: float = fight.health[fight.enemies - 1]
	for i in fight.enemies - 1:
		_check(elite > fight.health[i], "the elite outlasts enemy %d" % [i + 1])
	return true


## Ten enemies clicked down inside the minute, with the clock running through every walk-in and death.
func _test_a_won_fight() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	var coming: Array[String] = []
	var spawned: Array[int] = []
	var died: Array[int] = []
	var results: Array[bool] = []
	fight.enemy_coming.connect(func(_i: int, n: String, _hp: float) -> void: coming.append(n))
	fight.enemy_spawned.connect(func(i: int, _n: String, _hp: float) -> void: spawned.append(i))
	fight.enemy_died.connect(func(i: int) -> void: died.append(i))
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))

	_check(not fight.hit(), "no hit lands before the first enemy is on")
	fight.start()
	_check(coming.size() == 1 and coming[0] == fight.lineup[0], "the first enemy is announced on its way in")
	var clicks := _play(fight, 10000)
	_check(fight.finished and fight.victory, "the fight is won")
	_check(results == [true], "winning is reported once")
	_check(spawned.size() == Encounter.ENEMIES and died.size() == Encounter.ENEMIES,
			"all ten came out and all ten went down")
	# Every enemy has to be announced on its way in, or the scene draws the one before it.
	_check(coming.size() == Encounter.ENEMIES, "all ten were announced (%d)" % coming.size())
	_check(PackedStringArray(coming) == fight.lineup, "in the order the fight lists them")
	_check(fight.remaining() == 0, "none are left")
	_check(fight.time_left > 0.0, "with %.1fs to spare" % fight.time_left)
	_check(not fight.hit(), "a hit after the last one does nothing")
	print("First-ring fight: %d clicks, %.1fs left of %ds" % [clicks, fight.time_left, Encounter.SECONDS])

	return true


## The clock is the only way to lose, and it keeps running while enemies walk in and die.
func _test_a_lost_fight() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	var results: Array[bool] = []
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))

	fight.advance(Encounter.SECONDS + 1.0)
	_check(fight.finished and not fight.victory, "standing still loses")
	_check(results == [false], "losing is reported once")
	_check(fight.time_left == 0.0, "the clock is out")
	_check(not fight.hit(), "hits after time do nothing")
	fight.advance(10.0)
	_check(results == [false], "and the clock stays quiet afterwards")

	# The last enemy going down on the final sliver of clock still wins. How long a fight actually
	# takes depends on the ten it rolled, so measure one and then start another that late.
	var measured := Encounter.for_tile(Vector2i(1, 0), "grass")
	_play(measured, 10000)
	var takes := Encounter.SECONDS - measured.time_left

	var close := Encounter.for_tile(Vector2i(1, 0), "grass")
	var won: Array[bool] = []
	close.lost.connect(func() -> void: won.append(false))
	close.won.connect(func() -> void: won.append(true))
	close.advance(Encounter.SECONDS - takes - 0.1)
	_check(not close.finished, "the fight is still on with a sliver of clock left")
	_play(close, 10000)
	_check(close.finished and close.victory, "beating the last one just in time still wins")
	_check(won == [true], "and is reported as a win")
	_check(close.time_left < 1.0, "with almost nothing to spare (%.2fs)" % close.time_left)
	return true


## The enemies strike the clock: every tier on its own rhythm, each blow cut by armour and then block,
## dodged whole now and then, and won back by time on hit -- and never on a run, which has no clock.
func _test_enemy_strikes() -> bool:
	# The user's own example, as the formula: a hundred-second blow against 90% armour and ten seconds
	# of block is nothing. 90% armour is a rating of 9 * ARMOUR_K.
	var sums := Encounter.new()
	sums.arm({"armor": 9.0 * Encounter.ARMOUR_K, "block": 100.0})
	_check(is_equal_approx(sums.taken(100.0), 0.0), "100s against 90%% armour and 10s block is 0 (%.3f)"
			% sums.taken(100.0))
	sums.arm({"armor": 9.0 * Encounter.ARMOUR_K})
	_check(is_equal_approx(sums.taken(100.0), 10.0), "armour alone takes 90%% (%.3f)" % sums.taken(100.0))
	sums.arm({"block": 100.0})
	_check(is_equal_approx(sums.taken(100.0), 90.0), "block alone takes its ten seconds (%.3f)" % sums.taken(100.0))
	# A flat share, so the same armour turns the same part of a small blow as of a big one, and none
	# of it is ever the whole.
	sums.arm({"armor": Encounter.ARMOUR_K})
	_check(is_equal_approx(sums.taken(1.0), 0.5) and is_equal_approx(sums.taken(100.0), 50.0),
			"K armour is half of any blow")
	sums.arm({"armor": 1.0e12})
	_check(sums.taken(1.0) > 0.0, "and never all of one")
	sums.arm({"dodge": 9.0 * Encounter.DODGE_K})
	_check(is_equal_approx(sums.dodge_chance(), 0.9), "dodge is the same share, as a chance")

	# Each tier strikes on its own rhythm, and the first blow waits a whole interval.
	# Common every second, elite every two, boss every four: nothing lands in the first 0.999 s, and in
	# the first 4.001 s that is four, two and one.
	for case: Array in [[EnemyRoster.Tier.COMMON, 4], [EnemyRoster.Tier.ELITE, 2], [EnemyRoster.Tier.BOSS, 1]]:
		var fight := _struck_standing(case[0])
		var blows: Array = []
		fight.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: blows.append(t))
		fight.advance(0.999)
		_check(blows.is_empty(), "tier %d waits out its first interval (%d)" % [case[0], blows.size()])
		fight.advance(3.002)
		_check(blows.size() == case[1], "and strikes %d times in four seconds (%d)" % [case[1], blows.size()])
		var hit := Encounter.hit_of(fight.enemy_name(), fight.cell)
		_check(is_equal_approx(float(blows[-1]), hit), "a blow with nothing on is the whole of it")
		_check(is_equal_approx(fight.time_left, Encounter.SECONDS - Encounter.WALK_IN - 4.001 - hit * blows.size()),
				"and comes off the clock (%.3f)" % fight.time_left)
	# A boss's blow is four commons', which its slower rhythm pays for: every tier takes the same a second.
	var here := Vector2i(12, 0)
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		var some := _enemy_of(tier)
		_check(is_equal_approx(Encounter.hit_of(some, here) / float(Encounter.ATTACK_EVERY[tier]),
				Encounter.hit_of(_enemy_of(EnemyRoster.Tier.COMMON), here)
				/ float(Encounter.ATTACK_EVERY[EnemyRoster.Tier.COMMON])), "tier %d takes what a common does a second" % tier)
	# Blows grow by their own HIT_GROWTH a ring and HIT_WALL_GROWTH a wall, not by health's.
	var common := _enemy_of(EnemyRoster.Tier.COMMON)
	var inside := MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS, 0)
	var past := inside + Vector2i(2, 0)
	_check(Encounter.walls_inside(inside) == 0 and Encounter.walls_inside(past) == 1, "one wall between them")
	_check(is_equal_approx(Encounter.hit_of(common, past) / Encounter.hit_of(common, inside),
			Encounter.HIT_GROWTH * Encounter.HIT_GROWTH * Encounter.HIT_WALL_GROWTH), "a blow grows with the walk and its wall's step")

	# Dodge: over a long run of blows, about the share the formula says, and a dodge costs nothing.
	var dodger := _struck_standing(EnemyRoster.Tier.COMMON, {"dodge": 0.5 * Encounter.DODGE_K})
	dodger.crit_rng.seed = WORLD_SEED
	var hit := Encounter.hit_of(dodger.enemy_name(), dodger.cell)
	var chance := dodger.dodge_chance()
	var dodged := [0, 0]
	dodger.player_hit.connect(func(t: float, d: bool, _b: bool) -> void:
		dodged[0 if d else 1] += 1
		if d:
			_check(t == 0.0, "a dodge costs nothing"))
	for i in 2000:
		dodger.time_left = 1000.0
		dodger._struck_by(hit)
	var share := float(dodged[0]) / 2000.0
	_check(absf(share - chance) < 0.04, "dodged %.2f of blows where the formula says %.2f" % [share, chance])

	# Time on hit wins back what the blows took and never more: the clock's own running is not a wound.
	var healer := _struck_standing(EnemyRoster.Tier.COMMON, {"time_on_hit": 10.0})
	var start := healer.time_left
	healer.hit()
	_check(healer.time_left == start, "with no wound, a hit wins nothing back")
	healer._struck_by(2.5)
	healer.hit()
	_check(is_equal_approx(healer.time_left, start - 1.5) and is_equal_approx(healer.wounds, 1.5),
			"a hit wins back its second of the blow (%.2f)" % healer.time_left)
	healer.hit()
	healer.hit()
	_check(is_equal_approx(healer.time_left, start) and healer.wounds == 0.0,
			"and stops once the wound is healed (%.2f)" % healer.time_left)

	# Nobody strikes a run, the wall or a fight nobody told to (`strikes`).
	var run := Encounter.farm(Vector2i(12, 0), "grass")
	run.strikes = true
	var run_blows: Array = []
	run.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: run_blows.append(t))
	run.start()
	run.advance(10.0)
	_check(run_blows.is_empty(), "a farm run is never struck")
	var wall := Encounter.for_wall(Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0))
	wall.strikes = true
	wall.start()
	wall.advance(10.0)
	_check(is_equal_approx(wall.time_left, wall.seconds - 10.0), "the ice wall never strikes")
	var quiet := Encounter.for_tile(Vector2i(12, 0), "grass")
	quiet.start()
	quiet.advance(5.0)
	_check(is_equal_approx(quiet.time_left, Encounter.SECONDS - 5.0), "nor does a fight nobody armed for it")

	return true


## A tile fight with the enemies striking and the first body of `tier` standing there, armed with
## `stats`. Walked on to the moment it can be hit, so its first blow is a whole interval away.
## The Guard tree's three capstones.
func _test_guard_capstones() -> bool:
	# Afterimage: a dodge wins back up to a second of what blows took, and never more than they took.
	var dodger := _struck_standing(EnemyRoster.Tier.COMMON, {"dodge": 1.0e12})
	dodger.effects = ["afterimage"]
	var start := dodger.time_left
	dodger._struck_by(3.0)
	_check(dodger.time_left == start, "with no wound, a dodge wins nothing back")
	dodger.wounds = 2.5
	dodger.time_left = start - 2.5
	dodger._struck_by(3.0)
	_check(is_equal_approx(dodger.wounds, 1.5) and is_equal_approx(dodger.time_left, start - 1.5),
			"a dodge wins back one second (%.2f)" % dodger.time_left)

	# Shield Wall: block counts double against an elite, and only against one.
	for case: Array in [[EnemyRoster.Tier.COMMON, 2.0], [EnemyRoster.Tier.ELITE, 1.0]]:
		var guard := _struck_standing(case[0], {"block": 10.0})
		guard.effects = ["shieldwall"]
		var before := guard.time_left
		guard._struck_by(3.0)
		_check(is_equal_approx(before - guard.time_left, case[1]),
				"tier %d takes %.1fs of a 3s blow (%.2f)" % [case[0], case[1], before - guard.time_left])

	# Second Wind: the clock running out gives back five seconds, once.
	var winded := Encounter.for_tile(Vector2i(1, 0), "grass")
	winded.health[0] = 1.0e9
	winded.effects = ["second_wind"]
	winded.start()
	winded.advance(Encounter.SECONDS + 0.01)
	_check(not winded.finished and is_equal_approx(winded.time_left, Encounter.SECOND_WIND_SECONDS),
			"the first time out is a second wind (%.2f)" % winded.time_left)
	winded.advance(Encounter.SECOND_WIND_SECONDS + 0.01)
	_check(winded.finished, "and the second is the end")
	return true


## An enemy can only be hit while it is standing in front of the player.
func _test_hits_only_land_on_a_waiting_enemy() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	_check(fight.phase == Encounter.Phase.WALKING_IN, "the first enemy starts by running in")
	fight.advance(Encounter.WALK_IN / 2.0)
	_check(not fight.hit(), "it can't be hit on the way in")
	_check(fight.hp == fight.enemy_max_hp(), "so it has taken no damage")

	fight.advance(Encounter.WALK_IN)
	_check(fight.phase == Encounter.Phase.WAITING, "then it stands to be hit")
	_check(fight.hit() and fight.hp == fight.enemy_max_hp() - 1, "and a click takes a point off")

	while fight.hp > 0:
		fight.hit()
	_check(fight.phase == Encounter.Phase.DYING, "at zero it starts dying")
	_check(not fight.hit(), "a corpse can't be hit")
	_check(fight.index == 0, "and the next one is not out yet")

	fight.advance(Encounter.DEATH + Encounter.WALK_IN)
	_check(fight.index == 1 and fight.phase == Encounter.Phase.WAITING, "the second enemy takes its place")
	_check(fight.remaining() == Encounter.ENEMIES - 1, "nine to go")
	_check(not fight.on_elite(), "the second of ten is no elite")

	fight.give_up()
	_check(fight.finished and not fight.victory, "leaving counts as a loss")
	return true


## Charting a tile goes through a fight now, so the map has to hand over and take back cleanly:
## winning charts the tile as it always did, losing leaves the map exactly as it was.
func _test_the_map_hands_over_and_takes_back() -> bool:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	# A fight drops loot into whatever inventory the scene was pointed at, so never the player's own.
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame

	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	_check(main.view.can_chart(target), "the tile next door can be fought for")

	# Losing changes nothing.
	main.map.select_cell(target)
	main._on_chart_pressed()
	_check(main._combat == null and main.view.walking, "pressing Chart walks the player onto the tile first")
	main.map.player.finish_walk()
	_check(main.view.player_cell == target, "onto the tile itself")
	_check(main._combat != null, "and the fight starts there")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"the map stops while the fight is on")
	main._combat._on_terminate_pressed()
	_check(main._combat.fight.finished and not main._combat.fight.victory,
			"Terminate gives a tile fight up as a loss")
	_check(main._combat._result_detail.text == "Given up", "and the verdict says it was given up")
	_check(main._combat._lost_row.visible and not main._combat._collect.visible,
			"a lost fight offers the arrow and Retry, and nothing to collect")
	# Retry is a loss left and the same tile's fight opened again, in one press.
	var first: CombatScene = main._combat
	first.retry.emit()
	_check(main._combat != null and main._combat != first and main._combat.cell == target,
			"Retry opens the same tile's fight afresh")
	_check(not main.view.charted(target) and not main.map.visible, "with nothing charted by the loss")
	_check(main.view.player_cell == target and not main.view.walking, "and the player still on the tile")
	# Shut mid-fight, the save has the player back where they set out from, as a loss would.
	main._save_map()
	_check(MapSave.load_from(SCRATCH_MAP, []).player_cell == MapBuilder.CENTER,
			"a save made on the tile being fought for puts the player back where they came from")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	_check(main._combat == null, "the fight is torn down")
	_check(main.map.visible and main.map.process_mode == Node.PROCESS_MODE_INHERIT, "and the map is back")
	_check(not main.view.charted(target), "a lost tile stays uncharted")
	_check(main.view.walking, "and the player runs back off it")
	main.map.player.finish_walk()
	_check(main.view.player_cell == MapBuilder.CENTER, "to the tile they set out from")
	_check(main.view.can_chart(target), "and it can be fought for again")

	# Winning charts it, and the player stays on it.
	main._on_chart_pressed()
	main.map.player.finish_walk()
	var fight: Encounter = main._combat.fight
	_play(fight, 10000)
	_check(fight.victory, "the rematch is won")
	_check(main._combat._collect.visible and not main._combat._lost_row.visible and not main._combat.auto_collect,
			"and a won tile leaves by Collect, pressed: nothing collects by itself without the Nightwalkers")
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.charted(target), "a won tile is charted")
	_check(main.map.visible, "and the map is back")
	_check(main.view.player_cell == target and not main.view.walking, "with the player staying on it")

	# Escape: Terminate on a run, Back under its verdict, then the tile panel's X.
	main._on_farm_pressed()
	_check(main._combat != null and main._combat.fight.endless, "a run starts on the won tile, where they stand")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	# A tip still up from the fight before holds the run and takes the key first, a press each.
	for i in main.TIPS.size() + 1:
		if main._combat == null or main._combat.fight.finished:
			break
		Input.parse_input_event(escape)
		await process_frame
		await process_frame
	_check(main._combat != null and main._combat.fight.finished, "Escape ends a farm run")
	Input.parse_input_event(escape)
	await process_frame
	# The verdict shrinks away before it goes.
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	_check(main._combat == null, "again leaves its verdict")
	_check(main._panel.visible, "with the tile panel still up")
	# A tip that came due with the run is what Escape closes first, one press each.
	for i in main.TIPS.size():
		if main._tip_panel == null:
			break
		Input.parse_input_event(escape)
		await process_frame
		await process_frame
	_check(main._tip_panel == null and main._panel.visible, "a tip takes the press before the panel does")
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(not main._panel.visible and main.map.selected_cell == HexMap.NO_CELL,
			"and once more closes the tile panel")
	main.map.select_cell(target)

	# A tile away from the player: they walk through the charted tile beside it and onto it, and the fight
	# opens there.
	var far_side := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.W)
	main.map.select_cell(far_side)
	_check(main._chart_button.visible and not main._chart_button.disabled and not main._move_button.visible and not main._farm_button.visible, "only the buttons that can be pressed show")
	main._on_chart_pressed()
	_check(main._combat == null and main.view.walking, "charting a tile out of reach walks there first")
	_check(not main._chart_button.visible, "and hides the buttons on the way")
	# Stop ends the walk on the tile being stepped onto, and the fight it was for never opens.
	await process_frame
	_check(main._stop_button.visible, "Stop floats over the map while tiles are still ahead")
	main._on_stop_pressed()
	main.map.player.finish_walk()
	_check(main.view.player_cell == MapBuilder.CENTER and main._combat == null and main._chart_button.visible,
			"a stopped walk ends a tile on, with no fight and Chart back")
	await process_frame
	_check(not main._stop_button.visible, "and Stop goes with the walk")
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main.view.player_cell == far_side and main._combat != null, "the fight opens on arrival")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.map.player.finish_walk()
	# Back to the charted tile they stepped onto it from, not to where the walk began.
	_check(main.view.player_cell == MapBuilder.CENTER and not main.view.walking,
			"and a loss runs them back to the charted tile they stepped onto it from")

	# Farming a tile away from the player walks there too, and they stay when the run ends.
	main.map.select_cell(target)
	main._on_farm_pressed()
	_check(main._combat == null and main.view.walking, "farming a tile away walks there first")
	main.map.player.finish_walk()
	_check(main.view.player_cell == target and main._combat != null and main._combat.fight.endless,
			"and the run opens on arrival")
	main._combat.fight.stop()
	main._combat._on_back_pressed()
	await process_frame
	_check(not main.view.walking and main.view.player_cell == target, "a run ended leaves them where it was")
	main.queue_free()
	return true


## The Nightwalkers: Chart on a tile a few steps into the dark fights for every tile of the way in turn,
## each won one collecting its loot and walking on to the next by itself; Retry keeps the way, and a
## loss ends it.
func _test_the_nightwalkers_fight_their_way() -> bool:
	_clear_saves()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var boots := Item.rolled_unique("nightwalkers", rng, 1)
	main.inventory.add(boots)
	main.inventory.equip(boots, Equipment.Socket.BOOTS)
	# A veteran's save, every tip read: a tip up holds the fight still, and its automatic Collect with it.
	for tip: Array in main.TIPS:
		main.inventory.tips.append(tip[0])
	var line: Array[Vector2i] = [MapBuilder.CENTER]
	for i in 3:
		line.append(HexGrid.neighbor(line[-1], HexGrid.Edge.E))
	main.map.select_cell(line[3])
	_check(main.view.can_chart(line[3]) and main._chart_button.visible, "three steps into the dark can be charted")
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main.view.player_cell == line[1] and main._combat != null and main._combat.cell == line[1],
			"the first fight is for the first tile of the way")
	_play(main._combat.fight, 10000)
	_check(main._combat.auto_collect and main._combat._collect.visible, "won, the verdict is up")
	await create_timer(CombatScene.AUTO_COLLECT_SECONDS + Juice.LEAVE_TIME + 0.3).timeout
	_check(main.view.charted(line[1]) and main.view.walking and main._combat == null,
			"and with nobody pressing Collect the loot is taken, the tile charted and the hero walks on")
	main.map.player.finish_walk()
	_check(main._combat != null and main._combat.cell == line[2], "and the next tile's fight opens")
	# Retry keeps the way.
	main._combat.fight.give_up()
	main._combat.retry.emit()
	_check(main._combat != null and main._combat.cell == line[2] and main._dark_way == [line[3]],
			"Retry fights the same tile again, the way kept")
	_play(main._combat.fight, 10000)
	await create_timer(CombatScene.AUTO_COLLECT_SECONDS + Juice.LEAVE_TIME + 0.3).timeout
	main.map.player.finish_walk()
	_check(main.view.charted(line[2]) and main._combat != null and main._combat.cell == line[3],
			"won, on to the goal")
	# A loss ends the way, and runs the hero back to the last tile won.
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.map.player.finish_walk()
	_check(not main.view.charted(line[3]) and main._dark_way.is_empty() and main._combat == null
			and main.view.player_cell == line[2] and not main.view.walking,
			"a loss leaves the goal uncharted, the way over and the hero on the last tile won")
	main.queue_free()
	await process_frame
	_clear_saves()
	return true


## The runes in a fight (`RuneTable`, the third wall's): the cave's bodies carry them once the main
## scene says so (`runes_drop`), Gollux every time; a farm run Depth runes deeper fields bodies those
## levels on, health and drops; an ascended one drops ascended finds; and a rune's modifier worn off
## leaves the run (`forget_mod`).
func _test_runes_in_the_fight() -> bool:
	for drops in [false, true]:
		var down := Encounter.for_dungeon()
		down.runes_drop = drops
		var found := []
		down.rune_dropped.connect(func(_index: int, rune: String) -> void: found.append(rune))
		down.arm({"damage": 1e15, "attack_speed": 10.0})
		down.start()
		for i in 100000:
			if down.finished:
				break
			down.advance(0.05)
		if drops:
			_check(down.cleared() > 0 and found.size() >= down.cleared()
					and found.all(func(rune: String) -> bool: return RuneTable.has(rune)),
					"every Gollux leaves a rune, and the rest of the cave now and then (%d in %d depths)"
					% [found.size(), down.cleared()])
		else:
			_check(found.is_empty(), "before the third wall the cave carries none")

	var cell := Vector2i(8, 0)
	var plain := Encounter.farm(cell, "grass")
	var deep := Encounter.farm(cell, "grass", "", [], 2)
	var body := plain.lineup[0]
	var ratio := deep._raw_health_of(body) / plain._raw_health_of(body)
	var want := pow(Encounter.HP_GROWTH, MapBuilder.LEVEL_TILES * 2)
	_check(absf(ratio - want) / want < 0.02 and deep._level() == MapBuilder.level_of(cell) + 2,
			"two Depths are two levels on: health as eight rings out, drops two levels up (%.2f)" % ratio)

	var juiced := Encounter.farm(cell, "grass", "", ["thick_skinned", "thick_skinned", "elite_ground"])
	var thick := juiced._raw_health_of(body)
	var pace := juiced.elite_every
	juiced.forget_mod("thick_skinned")
	juiced.forget_mod("thick_skinned")
	_check(juiced._raw_health_of(body) < thick and is_zero_approx(juiced._hp_more) and juiced.mods == ["elite_ground"],
			"a modifier worn off takes its health with it")
	juiced.forget_mod("elite_ground")
	_check(pace < juiced.elite_every and juiced.elite_every == plain.elite_every, "and its elites, back to the tile's own pace")

	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var ascended := Encounter.farm(cell, "grass")
	ascended.ascended = true
	var pluses := [0, 0]
	for i in 2000:
		pluses[0] += ascended._lean(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 3)).plus
		pluses[1] += plain._lean(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 3)).plus
	_check(pluses[0] > 0 and pluses[1] == 0, "an ascended tile drops ascended finds, a plain one none (%s)" % [pluses])
	return true


func _test_the_dungeon() -> bool:
	var fight := Encounter.for_dungeon()
	var block := int(Encounter.DUNGEON["enemies"])
	_check(fight.dungeon and fight.env == Encounter.DUNGEON_ENV and not fight.endless
			and is_equal_approx(fight.time_left, float(Encounter.DUNGEON["seconds"])),
			"the dungeon is a clocked fight in the cave")
	# Its creatures are the cave's and nobody else's, and no land fields one.
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		_check(not EnemyRoster.in_environment(Encounter.DUNGEON_ENV, tier).is_empty(),
				"the cave has a tier %d creature" % tier)
	for name in EnemyRoster.in_environment(Encounter.DUNGEON_ENV):
		_check(EnemyRoster.environments_of(name) == PackedStringArray([Encounter.DUNGEON_ENV]),
				name + " lives in the cave alone")
	# A depth is fifteen floors: an elite every fifth and the boss on the fifteenth, for ever, and a
	# descent begun under depths already won meets them on the same floors.
	for won in [0, 3]:
		var from := Encounter.for_dungeon(won)
		_check(from.first_floor == won * block and from.depth() == won + 1 and from.cleared() == 0,
				"%d depths won begins depth %d, on its first floor" % [won, won + 1])
		for position in 40:
			var want := EnemyRoster.Tier.BOSS if position % block == block - 1 \
					else EnemyRoster.Tier.ELITE if position % 5 == 4 else EnemyRoster.Tier.COMMON
			_check(from.tier_for(position) == want, "floor %d under %d is tier %d" % [position + 1, won, want])
	# A floor's health is the floor and the tier: the same whoever stands there, and one step a floor,
	# so a depth is DUNGEON_GROWTH ^ 15 harder than the one over it.
	_check(is_equal_approx(fight.hp, Encounter.BASE_HP), "the first floor is one ordinary body")
	var deep := Encounter.for_dungeon(2)
	_check(is_equal_approx(deep.hp, roundf(Encounter.BASE_HP * pow(Encounter.DUNGEON_GROWTH, 2 * block))),
			"and the third depth opens thirty steps on (%s)" % BigNumber.format(deep.hp))
	# A world's curse that sizes bodies again leaves a floor the health its floor gives it.
	var cursed := Encounter.for_dungeon(2)
	cursed.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(cursed.hp, deep.hp), "Iron Foes does not reach down the dungeon")
	# The player's own hand lands as it does anywhere, and nothing strikes the clock -- which runs as it
	# does anywhere, through a walk-in too (the user's, 2026-10-03).
	fight.start()
	fight.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fight.time_left, float(Encounter.DUNGEON["seconds"]) - Encounter.WALK_IN),
			"the walk-in costs its seconds down here")
	_check(fight.hit() and fight.hp < Encounter.BASE_HP, "a click lands down here")
	# With no swing at all the whole minute is seen out on the first floor -- and running out is an
	# end, not a loss.
	var bare := _descended(0.0, 0.0)
	_check(bare.finished and bare.victory and bare.depth() == 1 and bare.cleared() == 0 and bare.index == 0,
			"nobody swinging ends on the first floor of the first depth, not lost")
	_check(is_zero_approx(bare.wounds), "and was never struck")
	# It pays nothing, however far it goes.
	var paid: Array = []
	var armed := Encounter.for_dungeon()
	armed.always_drop = true
	armed.always_orb = true
	armed.uniques_after = 0
	armed.effects = ["hourglass"]
	for sent: Signal in [armed.loot_dropped, armed.gold_dropped, armed.orb_dropped, armed.xp_dropped]:
		sent.connect(func(_index: int, _what: Variant) -> void: paid.append(1))
	armed.arm({"damage": 50.0, "attack_speed": 4.0})
	armed.start()
	while not armed.finished:
		armed.advance(0.05)
	_check(armed.kills() > 5 and paid.is_empty() and is_zero_approx(armed.gold) and armed.xp == 0,
			"%d floors cleared and nothing paid" % armed.kills())
	_check(armed.time_left <= 0.0, "and the Hourglass held no clock")
	# A depth is won by killing its Gollux and by nothing short of it: the floor under him is still
	# his depth, and the one after him is the next.
	var under := Encounter.for_dungeon()
	under.arm({"damage": 1e9})
	under.start()
	while under.index < block - 1:
		under.advance(Encounter.WALK_IN)
		under.hit()
		under.advance(Encounter.DEATH)
	_check(under.enemy_name() == "Gollux" and under.depth() == 1 and under.cleared() == 0,
			"fourteen floors down is Gollux, and still the first depth")
	var wall := Encounter.for_wall(Vector2i(MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP, 0)).hp
	_check(is_equal_approx(under.hp, Encounter.gollux_hp())
			and is_zero_approx(fmod(under.hp, Encounter.GOLLUX_ROUND))
			and absf(under.hp - wall) <= Encounter.GOLLUX_ROUND / 2.0,
			"and he is the second ice wall rounded to the nearest 500k (%s for %s)"
			% [BigNumber.format(under.hp), BigNumber.format(wall)])
	under.advance(Encounter.WALK_IN)
	under.hit()
	_check(under.depth() == 1 and under.cleared() == 0, "he is not dead until he has fallen")
	under.advance(Encounter.DEATH)
	_check(under.depth() == 2 and under.cleared() == 1 and not under.finished,
			"with him dead it is the second depth, and the descent goes on")
	_check(is_equal_approx(Encounter.for_dungeon(1)._health_of("Gollux", block - 1),
			roundf(Encounter.gollux_hp() * pow(Encounter.DUNGEON_GROWTH, block))),
			"and the next Gollux is a depth's growth on")
	# More damage gets deeper, and a depth is a real step: DUNGEON_GROWTH ^ 15 of it.
	var damage := Encounter.gollux_hp() / 100.0
	var weak := _descended(damage, 2.0)
	var strong := _descended(damage * pow(Encounter.DUNGEON_GROWTH, block), 2.0)
	_check(strong.cleared() > weak.cleared(),
			"a depth's worth more damage wins more depths (%d against %d)" % [strong.cleared(), weak.cleared()])
	print("The dungeon: %s damage at 2 swings/s wins %d depth(s) from the top, %s damage %d"
			% [BigNumber.format(damage), weak.cleared(), BigNumber.format(damage * pow(Encounter.DUNGEON_GROWTH, block)), strong.cleared()])
	return true


func _test_the_ice_wall() -> bool:
	var cell := Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0)
	var fight := Encounter.for_wall(cell)
	_check(fight.lineup == PackedStringArray([Encounter.WALL_NAME]) and fight.env == "ice" and fight.enemies == 1,
			"the wall stands alone, on the ice")
	_check(EnemyRoster.tier_of(Encounter.WALL_NAME) == EnemyRoster.Tier.BOSS, "and is a boss")
	for env in ["grass", "dirt", "desert", "forest", "ice", "mountains"]:
		_check(not (Encounter.WALL_NAME in EnemyRoster.in_environment(env)), "the wall lives nowhere, not on %s" % env)
	# A wall is a fixed check on the land inside it and nothing more: WALL_HP over its own body, with
	# no term of its own for the walls already down. That term lives in `base_hp` now, where it makes
	# the land past a fallen wall a frontier again, and a wall's ring counts none of itself -- so the
	# second wall comes out WALL_GROWTH times the first without `for_wall` doing anything about it.
	var second := Encounter.for_wall(Vector2i(cell.x + MapBuilder.WALL_STEP, 0))
	_check(Encounter.walls_inside(cell) == 0 and Encounter.walls_inside(second.cell) == 1,
			"a wall's own ring counts none of itself")
	for wall: Encounter in [fight, second]:
		_check(is_equal_approx(wall.hp, roundf(Encounter.hp_of(Encounter.WALL_NAME, wall.cell, Encounter.WALL_GROWTH) * Encounter.WALL_HP)),
				"the wall on ring %d is WALL_HP over its own body" % HexGrid.distance(MapBuilder.CENTER, wall.cell))
	var by_ring := pow(Encounter.HP_GROWTH, MapBuilder.WALL_STEP)
	_check(absf(second.hp / fight.hp / by_ring / Encounter.WALL_GROWTH - 1.0) < 0.01,
			"the second wall is %.0f times the first on top of its ring (%s health)"
			% [Encounter.WALL_GROWTH, BigNumber.format(second.hp)])
	# From the fourth wall on, a wall is LATE_WALL_BODIES ordinary bodies of the ring just inside it.
	var third := Encounter.for_wall(Vector2i(cell.x + 2 * MapBuilder.WALL_STEP, 0))
	_check(is_equal_approx(third.hp, roundf(Encounter.hp_of(Encounter.WALL_NAME, third.cell, Encounter.WALL_GROWTH) * Encounter.WALL_HP)),
			"the third wall is still WALL_HP over its own body")
	var fourth := Encounter.for_wall(Vector2i(cell.x + 3 * MapBuilder.WALL_STEP, 0))
	var inside := Vector2i(fourth.cell.x - 1, 0)
	_check(is_equal_approx(fourth.hp, roundf(Encounter.base_hp(inside) * Encounter.hp_tuning(3) * Encounter.LATE_WALL_BODIES)),
			"the fourth wall is %.0f bodies of the ring inside it (%s health)" % [Encounter.LATE_WALL_BODIES, BigNumber.format(fourth.hp)])
	return true


## A farm run: the same enemies, coming forever, with no clock and no count. The only two ways out
## are the player saying so and give_up(), so everything here is about the ways it does *not* end.
func _test_a_farm_run_never_ends() -> bool:
	var idle := Encounter.farm(Vector2i(3, 0), "grass")
	idle.roster_rng.seed = WORLD_SEED
	idle.start()
	# Twice the budget a tile fight gets, with nobody lifting a finger. A tile fight is long over.
	idle.advance(Encounter.SECONDS * 2.0)
	_check(not idle.finished, "a farm run does not run out of time")
	_check(is_equal_approx(idle.time_left, Encounter.SECONDS), "a farm run never spends the clock")

	var fight := Encounter.farm(Vector2i(3, 0), "grass")
	fight.roster_rng.seed = WORLD_SEED
	fight.arm({"damage": 200.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 0.0})
	fight.start()
	_check(fight.lineup.size() == 1, "a run starts with one enemy and finds the rest as it goes")
	var clicks := _play(fight, 300)
	_check(not fight.finished, "%d clicks in, the run is still going" % clicks)
	_check(fight.kills() > Encounter.ENEMIES, "a run runs past what a tile fight is, at %d kills"
			% fight.kills())
	_check(fight.lineup.size() == fight.health.size(),
			"every enemy in the lineup has health: %d against %d"
			% [fight.lineup.size(), fight.health.size()])
	_check(fight.index < fight.lineup.size(), "there is always one more waiting")

	# Elites keep the rhythm a tile fight has: the tenth, the twentieth, and so on forever.
	var elites := 0
	for i in fight.lineup.size():
		var is_elite := EnemyRoster.tier_of(fight.lineup[i]) == EnemyRoster.Tier.ELITE
		if is_elite:
			elites += 1
		_check(is_elite == (i % fight.elite_every == fight.elite_every - 1),
				"slot %d is %s, which is not the elite rhythm" % [i, fight.lineup[i]])
	_check(elites > 0, "a run long enough to pass ten threw up %d elite(s)" % elites)

	# Terminating is not losing. The kills and the loot are the player's either way.
	var results := []
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))
	fight.stop()
	_check(fight.finished and fight.victory, "stopping a run ends it, and not as a loss")
	_check(results == [true], "stopping fires won exactly once, and lost never: %s" % [results])
	fight.stop()
	_check(results == [true], "stopping a stopped run says nothing more")

	# on_elite() asks the roster, so it is the same question in a tile fight as in a run.
	var tile := Encounter.for_tile(Vector2i(3, 0), "grass")
	for i in tile.enemies:
		tile.index = i
		_check(tile.on_elite() == (i == tile.enemies - 1),
				"slot %d of a tile fight reads the wrong way round" % i)
	return true


## A settlement is a set piece: fifteen enemies in a minute, an elite every fifth and a boss last.
## All three tiers fight it -- what makes a town a longer fight is that people live there -- and a
## farm run on one keeps that elite rhythm and never the boss.
## A chest tile fields the mimic alone, which no other lineup ever does, and it pays either one
## unique or MIMIC_ROLLS pieces of gear, never both.
func _test_a_chest_is_a_mimic() -> bool:
	for env in _environments():
		for variant in ["plain", "village"]:
			var ordinary := Encounter.for_tile(Vector2i(4, 6), env, variant)
			_check(not Encounter.MIMIC in ordinary.lineup, "no mimic on an ordinary %s %s" % [env, variant])
	var outcomes := {"unique": 0, "gear": 0}
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(4, 6), "grass", "plain", true)
		_check(fight.lineup == PackedStringArray([Encounter.MIMIC]), "a chest fields the mimic alone")
		_check(fight.tier_for(0) == EnemyRoster.Tier.BOSS, "and it is a boss")
		fight.loot_rng.seed = attempt
		fight.unique_rng.seed = attempt
		fight.unlocked = Achievements.STARTERS
		var found: Array[Item] = []
		fight.loot_dropped.connect(func(_i: int, item: Item) -> void: found.append(item))
		fight.damage = 1 << 20
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		var uniques := found.filter(func(item: Item) -> bool: return not item.unique.is_empty()).size()
		if uniques > 0:
			outcomes["unique"] += 1
			_check(found.size() == 1, "a chest's unique comes alone (%d finds)" % found.size())
		else:
			outcomes["gear"] += 1
			_check(found.size() == Encounter.MIMIC_ROLLS,
					"otherwise it pays %d pieces (%d)" % [Encounter.MIMIC_ROLLS, found.size()])
		fight.advance(Encounter.DEATH)
		_check(fight.finished and fight.victory, "beating it takes the tile")
	_check(outcomes["unique"] > 0 and outcomes["gear"] > 0, "both halves of the toss come up %s" % outcomes)
	return true


func _test_a_settlement_is_a_set_piece() -> bool:
	for variant in ["village", "town", "fortress"]:
		for env in _environments():
			var fight := Encounter.for_tile(Vector2i(4, 6), env, variant)
			_check(fight.enemies == 15 and fight.seconds == 60.0 and fight.elite_every == 5,
					"a %s on %s fields %d in %.0fs, an elite every %d"
					% [variant, env, fight.enemies, fight.seconds, fight.elite_every])
			_check(fight.time_left == fight.seconds, "and opens with its whole clock")
			_check(fight.lineup.size() == fight.enemies,
					"a %s lines up %d, not %d" % [variant, fight.enemies, fight.lineup.size()])
			_check(fight.remaining() == fight.enemies, "with all of them still to beat")
			var bosses := 0
			var elites := 0
			for i in fight.lineup.size():
				var tier := EnemyRoster.tier_of(fight.lineup[i])
				_check(fight.tier_for(i) == tier,
						"tier_for(%d) agrees with the enemy the lineup put there" % i)
				_check(env in EnemyRoster.environments_of(fight.lineup[i]),
						"%s lives on %s" % [fight.lineup[i], env])
				match tier:
					EnemyRoster.Tier.BOSS:
						bosses += 1
						_check(i == fight.enemies - 1, "the boss is last, not number %d" % [i + 1])
					EnemyRoster.Tier.ELITE:
						elites += 1
						_check(i % fight.elite_every == fight.elite_every - 1,
								"an elite stands at %d, off the rhythm" % i)
			_check(bosses == 1, "a %s on %s ends on exactly one boss (%d)" % [variant, env, bosses])
			# Slots 4 and 9: the boss takes the fifteenth, which would otherwise be the third elite.
			_check(elites == 2, "and two elites before it (%d)" % elites)

	# The same tile, fought twice, fields the same fifteen -- a settlement is decided before the
	# player reaches it, like every other tile.
	_check(Encounter.for_tile(Vector2i(4, 6), "grass", "town").lineup
			== Encounter.for_tile(Vector2i(4, 6), "grass", "town").lineup,
			"a settlement keeps its enemies")

	# A variant this build has never heard of is open land as far as the fight is concerned.
	var plain := Encounter.for_tile(Vector2i(4, 6), "grass", "ruins")
	_check(plain.enemies == Encounter.ENEMIES and plain.seconds == Encounter.SECONDS
			and not plain.boss_last, "an unknown variant fights the ordinary fight")

	# A run on a town: the rhythm comes with it and the boss does not.
	var run := Encounter.farm(Vector2i(4, 6), "grass", "fortress")
	run.roster_rng.seed = WORLD_SEED
	run.start()
	_play(run, 400)
	_check(run.elite_every == 5, "a run on a fortress throws up an elite every %d" % run.elite_every)
	_check(run.lineup.size() > run.elite_every * 2,
			"and runs past two whole cycles of it, at %d" % run.lineup.size())
	var run_elites := 0
	for i in run.lineup.size():
		var tier := EnemyRoster.tier_of(run.lineup[i])
		_check(tier != EnemyRoster.Tier.BOSS, "no boss comes round in a run (slot %d)" % i)
		if tier == EnemyRoster.Tier.ELITE:
			run_elites += 1
		_check((tier == EnemyRoster.Tier.ELITE) == (i % run.elite_every == run.elite_every - 1),
				"slot %d is %s, which is not the settlement rhythm" % [i, run.lineup[i]])
	_check(run_elites > 2, "a long run on a town is thick with elites (%d)" % run_elites)

	return true


## Where uniques come from: nothing before the wait is over, chance alone after it, and the rabble
## far less often than what leads it.
func _test_unique_drops() -> bool:
	var cell := Vector2i(6, 0)
	# A drop rate this size caps every chance at certain, so the tally is about the gate and not luck.
	var sure := {"damage": 1.0e9, "drop_rate": 1.0e12}

	var untold := Encounter.farm(cell, "grass")
	untold.arm(sure)
	var none := _uniques_of(untold)
	untold.start()
	_play(untold, 60)
	_check(none.is_empty(), "a fight nobody tells drops no uniques (%s)" % [none])

	var run := Encounter.farm(cell, "grass")
	run.arm(sure)
	run.uniques_after = 30
	run.unlocked = Achievements.STARTERS
	var found := _uniques_of(run)
	run.start()
	_play(run, 60)
	_check(not found.is_empty() and int(found[0][0]) == 30,
			"the first unique falls on the kill the wait ends at (%s)" % [found.slice(0, 2)])
	for pair: Array in found:
		_check(str(pair[1]) in Achievements.STARTERS, "%s is one the player has unlocked" % pair[1])

	# Only what is unlocked falls -- a home piece on any ground, since the Pilgrim's set went.
	for unlocked: Array in [["metronome"], ["rimeplate"], []]:
		var locked := Encounter.farm(cell, "grass")
		locked.arm(sure)
		locked.uniques_after = 0
		locked.unlocked = unlocked
		var fell := _uniques_of(locked)
		locked.start()
		_play(locked, 40)
		var names := fell.map(func(pair: Array) -> String: return pair[1])
		if unlocked.is_empty():
			_check(names.is_empty(), "nothing locked falls (%s)" % [names])
		else:
			_check(not names.is_empty() and names.all(func(id: String) -> bool: return id == unlocked[0]),
					"one unlocked unique is the only one that falls, on grass (%s)" % [names])
	_check(UniqueTable.pool_for(["rimeplate", "metronome", "no_such_unique"]) == ["rimeplate", "metronome"],
			"the pool is what is unlocked and this build has")

	# Not even a boss, at a drop rate that makes every chance certain, jumps the wait.
	var early := Encounter.for_tile(cell, "grass", "village")
	early.arm(sure)
	early.uniques_after = 1000
	var too_soon := _uniques_of(early)
	early.start()
	_play(early, 100)
	_check(early.victory and too_soon.is_empty(), "no unique before the wait is over (%s)" % [too_soon])

	for enemy: String in EnemyRoster.ENEMIES:
		var chance := UniqueTable.chance_for(enemy)
		match EnemyRoster.tier_of(enemy):
			EnemyRoster.Tier.COMMON:
				_check(chance > 0.0 and chance < 0.002, "%s almost never carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.ELITE:
				_check(chance >= 0.005 and chance < 0.05, "%s sometimes carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.BOSS:
				_check(chance >= 0.05 and chance <= 0.25, "%s often carries one (%f)" % [enemy, chance])
	# Item rarity lifts it at unique's rung of the ramp, on top of the drop rate.
	var step := float(ItemRarity.RARITY_STEP[ItemRarity.Rarity.UNIQUE])
	var any: String = EnemyRoster.ENEMIES.keys()[0]
	var base := UniqueTable.chance_for(any)
	_check(is_equal_approx(UniqueTable.chance_for(any, 0.0, 50.0), base * (1.0 + 0.5 * step))
			and is_equal_approx(UniqueTable.chance_for(any, 100.0, 50.0), base * 2.0 * (1.0 + 0.5 * step)),
			"item rarity lifts the unique chance")
	return true


## What each unique changes about a fight, held to the sentence on its card.
func _test_unique_effects() -> bool:
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# Metronome: the hand does nothing, the weapon does three times as much.
	var metro := _standing(["metronome"], {"damage": 9.0, "attack_speed": 1.0})
	_check(not metro.hit() and metro.hp == 1.0e9, "a click lands nothing beside a Metronome")
	metro.advance(1.0)
	_check(metro.hp == 1.0e9 - 30.0, "and its own swing deals triple (%s)" % (1.0e9 - metro.hp))

	# Headsman: a quarter on its own, and Execute's tenth on top.
	var axe := _standing(["headsman"], {"damage": 69.0}, 100.0)
	axe.hit()
	_check(axe.phase == Encounter.Phase.WAITING and axe.hp == 30.0, "30% left is past the Headsman")
	var axe_kill := _standing(["headsman"], {"damage": 75.0}, 100.0)
	axe_kill.hit()
	_check(axe_kill.phase == Encounter.Phase.DYING, "under 25% the Headsman finishes it")
	var both := _standing(["headsman", "execute"], {"damage": 69.0}, 100.0)
	both.hit()
	_check(both.phase == Encounter.Phase.DYING, "with Execute the line is 35%")
	var over := _standing(["headsman", "execute"], {"damage": 59.0}, 100.0)
	over.hit()
	_check(over.phase == Encounter.Phase.WAITING, "and 40% left is still past it")

	# Knucklebone: two points a click, fifty at most a ring, gone after a pause.
	var ring := _standing(["knucklebone"], {"damage": 99.0})
	listen.call(ring)
	for i in 40:
		ring.hit()
		ring.advance(0.1)
	_check(blows[0] == 100.0 and blows[1] == 102.0, "a streak adds 2 points a click (%s)" % [blows.slice(0, 3)])
	_check(blows[-1] == 150.0, "and stops at half again (%s)" % blows[-1])
	ring.advance(Encounter.KNUCKLE_WINDOW + 0.1)
	ring.hit()
	_check(blows[-1] == 100.0, "a pause loses the streak (%s)" % blows[-1])
	blows.clear()
	var rings := _standing(["knucklebone", "knucklebone"], {"damage": 99.0})
	listen.call(rings)
	for i in 40:
		rings.hit()
	_check(blows[-1] == 200.0, "two rings add, to double and no further (%s)" % blows[-1])
	# A click through a walk-in lands nothing and still keeps the streak.
	var walking := Encounter.for_tile(Vector2i(12, 0), "grass")
	walking.effects = ["knucklebone"]
	walking.start()
	_check(not walking.hit() and walking._click_streak == 1, "a click that lands nothing still counts")

	# Home ground: double there, nothing anywhere else.
	blows.clear()
	var home := _standing(["home:grass"], {"damage": 9.0})
	listen.call(home)
	home.hit()
	var away := _standing(["home:grass"], {"damage": 9.0}, 1.0e9, "desert")
	listen.call(away)
	away.hit()
	_check(blows == [20.0, 10.0], "a home piece doubles a blow at home alone (%s)" % [blows])

	# Hourglass: a second a kill, never past the start, never for a boss, never on a run.
	var glass := Encounter.for_tile(Vector2i(12, 0), "grass")
	glass.effects = ["hourglass"]
	glass.arm({"damage": 1.0e9})
	glass.start()
	glass.advance(Encounter.WALK_IN)
	glass.hit()
	_check(glass.time_left == glass.seconds, "the clock is never pushed past its start (%s)" % glass.time_left)
	glass.advance(5.0)
	var before := glass.time_left
	glass.hit()
	_check(is_equal_approx(glass.time_left, before + 1.0), "a kill puts a second back")
	var boss := Encounter.for_tile(Vector2i(12, 0), "grass", "village")
	boss.effects = ["hourglass"]
	boss.arm({"damage": 1.0e9})
	boss.index = boss.enemies - 1
	boss.hp = 1.0
	boss.phase = Encounter.Phase.WAITING
	boss.time_left = 10.0
	boss.hit()
	_check(boss.time_left == 10.0, "a boss gives no time back")
	var endless := Encounter.farm(Vector2i(12, 0), "grass")
	endless.effects = ["hourglass"]
	endless.arm({"damage": 1.0e9})
	endless.time_left = 10.0
	endless.start()
	_play(endless, 20)
	_check(endless.time_left == 10.0, "a run has no clock for the Hourglass to touch")

	# The Tithe: no ordinary gear however sure the drop, and the purse three times over -- five for two.
	var purses := []
	for worn: Array in [[], ["tithe"], ["tithe", "tithe"]]:
		var fight := Encounter.for_tile(Vector2i(12, 0), "grass")
		fight.effects = worn
		fight.always_drop = true
		fight.arm({"damage": 1.0e9})
		var gear := [0]
		fight.loot_dropped.connect(func(_i: int, _item: Item) -> void: gear[0] += 1)
		fight.start()
		_play(fight, 100)
		purses.append(fight.gold)
		_check((gear[0] == 0) == (not worn.is_empty()), "a Tithe means no ordinary gear (%d with %s)" % [gear[0], worn])
	_check(purses[1] == purses[0] * 3.0 and purses[2] == purses[0] * 5.0,
			"and three times the gold, five for two (%s)" % [purses])
	return true


## The frontier stays a frontier. The best a clicker can wear -- the Glass Edge, a Berserker's Band, a
## Knucklebone Ring, the Gambler's Die, the Packmule's Harness and the ground's own home piece, every
## line at the top of its band, over a farmed set of rares -- is worth a handful of hex steps and no
## more: monsters grow by `HP_GROWTH` a step for ever, and a set that multiplies a blow a fixed number
## of times is caught up.
##
## The steps are counted inside one band of land, from the first ring past a fallen wall out to the
## next wall, because a wall is no longer a step on that curve -- it is a cliff, and the last check
## here is that the set cannot walk over one.
## The second batch of uniques, each held to the sentence on its card.
func _test_more_unique_effects() -> bool:
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))
	var cell := Vector2i(12, 0)

	# One sum, not a product: a Metronome's swing at home is four times a blow, not six.
	var sum := _standing(["metronome", "home:grass"], {"damage": 9.0, "attack_speed": 1.0})
	sum.advance(1.0)
	_check(sum.hp == 1.0e9 - 40.0, "what uniques add to a blow is added up (%s)" % (1.0e9 - sum.hp))

	# Berserker's Band: the hand triples, the weapon stops.
	var bear := _standing(["berserk"], {"damage": 9.0, "attack_speed": 2.0})
	bear.advance(2.0)
	_check(bear.hp == 1.0e9, "the weapon never swings beside a Berserker's Band")
	bear.hit()
	_check(bear.hp == 1.0e9 - 30.0, "and a click deals triple (%s)" % (1.0e9 - bear.hp))

	# Glass Edge: double, paid for in clock -- and neither half on a run, which has none.
	var glass := _standing(["glass_edge"], {"damage": 9.0})
	var clock := glass.time_left
	glass.advance(3.0)
	_check(is_equal_approx(glass.time_left, clock - 4.0), "the Glass Edge spends the clock a third faster")
	glass.hit()
	_check(glass.hp == 1.0e9 - 20.0, "for double damage")
	var run := Encounter.farm(cell, "grass")
	run.effects = ["glass_edge", "last_gasp"]
	run.arm({"damage": 9.0})
	run.time_left = 1.0
	run.start()
	run.advance(Encounter.WALK_IN)
	run.health[0] = 1.0e9
	run.hp = 1.0e9
	run.hit()
	_check(run.hp == 1.0e9 - 10.0, "a run has no clock, so neither clock piece is worth anything on one")

	# Gambler's Die: anywhere from almost nothing to three times, a half more on the whole.
	var die := _standing(["gamble"], {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	listen.call(die)
	for i in 2000:
		die.hit()
	var total := 0.0
	for amount: float in blows:
		total += amount
		_check(amount >= 10.0 and amount <= 3000.0, "a gambled blow stays inside its sentence (%s)" % amount)
	_check(total / 2000.0 > 1350.0 and total / 2000.0 < 1650.0, "and averages half again (%.0f)" % (total / 2000.0))
	blows.clear()

	# Serpent's Eye: from no crit chance at all, each blow that misses adds 5% until one crits.
	var serpent := _standing(["serpent"], {"damage": 9.0})
	serpent.hit()
	_check(serpent._serpent == UniqueTable.dial("serpents_eye", "step"),
			"a blow that did not crit builds the chance (%s)" % serpent._serpent)
	var crits: Array = []
	serpent.hit_landed.connect(func(_amount: float, crit: bool, _a: bool) -> void:
		crits.append([crit, serpent._serpent]))
	for i in 60:
		serpent.hit()
	var first_crit := crits.find_custom(func(blow: Array) -> bool: return blow[0])
	_check(first_crit >= 0 and first_crit <= 19, "a crit comes by the time the chance is certain (blow %d)" % first_crit)
	_check(crits.all(func(blow: Array) -> bool: return (blow[1] == 0.0) == blow[0]),
			"a crit spends what was built, and only a crit does")
	var twice := _standing(["serpent", "serpent"], {"damage": 9.0})
	twice.hit()
	_check(twice._serpent == 2.0 * UniqueTable.dial("serpents_eye", "step"),
			"one on each doll builds twice as fast (%s)" % twice._serpent)
	var without := _standing([], {"damage": 9.0})
	without.hit()
	_check(without._serpent == 0.0, "and nothing builds without one")

	# Ascetic's Cord and the Packmule's Harness read a count the inventory hands over.
	var bare := _standing(["ascetic"], {"damage": 9.0, "bare_sockets": 4})
	bare.hit()
	_check(bare.hp == 1.0e9 - 16.0, "15%% a bare socket (%s)" % (1.0e9 - bare.hp))
	var mule := _standing(["packmule"], {"damage": 9.0, "bag_pieces": 40})
	mule.hit()
	_check(mule.hp == 1.0e9 - 14.0, "1%% a piece in the bag (%s)" % (1.0e9 - mule.hp))
	# And the Patchwork Coat and the Purist's Seal, theirs.
	var patch := _standing(["patchwork"], {"damage": 9.0, "attribute_lines": 10})
	patch.hit()
	_check(patch.hp == 1.0e9 - 12.0, "2%% an attribute line (%s)" % (1.0e9 - patch.hp))
	var pure := _standing(["purist"], {"damage": 9.0, "pure_pieces": 5})
	pure.hit()
	_check(pure.hp == 1.0e9 - 15.0, "10%% a piece without one (%s)" % (1.0e9 - pure.hp))

	# Brawler's Wraps: strength on the hand, dexterity on the weapon's own swing.
	var brawl := _standing(["brawler"], {"damage": 9.0, "attack_speed": 1.0, "strength": 50.0, "dexterity": 100.0})
	listen.call(brawl)
	brawl.hit()
	brawl.advance(1.0)
	_check(blows == [15.0, 20.0], "a click takes the strength, a swing the dexterity (%s)" % [blows])
	blows.clear()

	# Last Gasp: the last five seconds and not a moment before.
	var gasp := _standing(["last_gasp"], {"damage": 9.0})
	listen.call(gasp)
	gasp.time_left = 5.5
	gasp.hit()
	gasp.time_left = 5.0
	gasp.hit()
	_check(blows == [10.0, 30.0], "Last Gasp triples under five seconds (%s)" % [blows])
	blows.clear()

	# Duelist's Buckler: the first blow on each enemy crits, with no crit chance at all.
	var duel := _standing(["opening_strike"], {"damage": 9.0, "crit_damage": 100.0}, 25.0)
	listen.call(duel)
	duel.hit()
	duel.hit()
	duel.advance(Encounter.DEATH)
	duel.advance(Encounter.WALK_IN)
	duel.hit()
	_check(blows == [20.0, 10.0, 20.0], "the first blow on every enemy is a crit (%s)" % [blows])
	blows.clear()

	# Overflowing Chalice: what the cap throws away comes back as crit damage.
	var chalice := Encounter.for_tile(cell, "grass")
	chalice.effects = ["overcrit"]
	chalice.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(chalice.crit_chance == Encounter.CRIT_CAP
			and chalice.crit_damage == 50.0 + 30.0 * UniqueTable.dial("overflowing_chalice", "times"),
			"crit chance past the cap becomes crit damage (%s)" % chalice.crit_damage)
	var plain := Encounter.for_tile(cell, "grass")
	plain.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(plain.crit_damage == 50.0, "and is simply lost without it")

	# Snowball: 2% a kill, and no further than double.
	var snow := _standing(["momentum"], {"damage": 9.0})
	snow.index = 10
	var ten := snow.unique_more(false)
	snow.index = 500
	var many := snow.unique_more(false)
	_check(is_equal_approx(ten, 0.2) and is_equal_approx(many, 1.0), "momentum builds and stops at double (%s, %s)"
			% [ten, many])

	# Bulwark: a blow block stops entirely is answered with a swing; one it only cuts is not.
	var wall := _standing(["riposte"], {"damage": 0.0, "block": 50.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows.size() == 1, "a blow blocked whole is answered (%d)" % blows.size())
	wall._struck_by(9.0)
	_check(blows.size() == 1, "and one that gets through is not (%d)" % blows.size())
	blows.clear()

	# Heartwood Plate: a second every HEARTWOOD_ARMOUR armour, its rank's most at most, none on a run.
	for case: Array in [[225.0, 4.0], [50000.0, UniqueTable.dial("heartwood_plate", "most")]]:
		var oak := Encounter.for_tile(cell, "grass")
		oak.effects = ["heartwood"]
		oak.arm({"armor": case[0]})
		_check(oak.seconds == Encounter.SECONDS + float(case[1]) and oak.time_left == oak.seconds,
				"%s armour is %s seconds" % case)
	var oak_run := Encounter.farm(cell, "grass")
	oak_run.effects = ["heartwood"]
	oak_run.arm({"armor": 225.0})
	_check(oak_run.seconds == Encounter.SECONDS, "and a run has no clock to add to")

	# The Fight Clock on gear, in tenths: capped at CLOCK_MOST, and none on a run either.
	for case: Array in [[25.0, 2.5], [400.0, Encounter.CLOCK_MOST]]:
		var clocked := Encounter.for_tile(cell, "grass")
		clocked.arm({"fight_clock": case[0]})
		_check(clocked.seconds == Encounter.SECONDS + float(case[1]) and clocked.time_left == clocked.seconds,
				"%s tenths of Fight Clock are %s seconds (%s)" % [case[0], case[1], clocked.seconds])
	var clocked_run := Encounter.farm(cell, "grass")
	clocked_run.arm({"fight_clock": 25.0})
	_check(clocked_run.seconds == Encounter.SECONDS, "and a run's clock is not lengthened")
	# Armed again mid-fight (gear changed in the bag): the clock moves by what changed, never refills.
	var rearmed := Encounter.for_tile(cell, "grass")
	rearmed.arm({"fight_clock": 25.0})
	rearmed.time_left -= 10.0
	rearmed.arm({"fight_clock": 25.0})
	_check(rearmed.seconds == Encounter.SECONDS + 2.5 and rearmed.time_left == rearmed.seconds - 10.0,
			"arming again with the same gear leaves the clock where it was (%s)" % rearmed.time_left)
	rearmed.arm({})
	_check(rearmed.seconds == Encounter.SECONDS and rearmed.time_left == Encounter.SECONDS - 10.0,
			"and taking the piece off takes its seconds back (%s)" % rearmed.time_left)

	# Magpie's Band: some purses are gear instead -- unless a Tithe says there is no gear.
	for worn: Array in [["magpie"], ["magpie", "tithe"]]:
		var nest := Encounter.farm(cell, "grass")
		nest.effects = worn
		nest.arm({"damage": 1.0e9})
		nest.loot_rng.seed = WORLD_SEED
		# Purses, finds and bodies, counted as they fall: `kills` lags a body still going down.
		var seen := [0, 0, 0]
		nest.gold_dropped.connect(func(_i: int, _g: float) -> void: seen[0] += 1)
		nest.loot_dropped.connect(func(_i: int, _item: Item) -> void: seen[1] += 1)
		nest.enemy_died.connect(func(_i: int) -> void: seen[2] += 1)
		nest.start()
		_play(nest, 400)
		var traded: int = seen[2] - seen[0]
		if "tithe" in worn:
			_check(traded == 0 and seen[1] == 0, "the Tithe keeps every purse a purse")
		else:
			_check(traded >= 5 and traded <= 45 and seen[1] >= traded,
					"about one purse in twenty is gear (%d of %d)" % [traded, seen[2]])

	# Lucky Wound: a body that took a crit leaves the better of two rolls.
	var worth := {}
	for kind: String in ["plain", "lucky", "no crit"]:
		var wound := Encounter.farm(cell, "grass")
		wound.effects = [] if kind == "plain" else ["lucky_wound"]
		wound.always_drop = true
		wound.arm({"damage": 1.0e9, "crit_chance": 0.0 if kind == "no crit" else 100.0})
		wound.loot_rng.seed = WORLD_SEED
		var tally := [0]
		wound.loot_dropped.connect(func(_i: int, item: Item) -> void: tally[0] += int(item.rarity) * 100 + item.level)
		wound.start()
		_play(wound, 300)
		worth[kind] = tally[0]
	_check(worth["lucky"] > worth["plain"], "two rolls and the better kept (%s)" % [worth])
	_check(worth["no crit"] == worth["plain"], "and only where a crit landed")

	# Only the killing blow counts: the Duelist's Buckler crits each body's first blow, and a plain
	# blow finishes it, so the Wound pays nothing over the same fight without it. A tile fight, whose
	# lineup is seeded from the cell, so both meet the same ten bodies.
	var opened := {}
	for kind: String in ["plain", "lucky"]:
		var wound := Encounter.for_tile(cell, "grass")
		wound.effects = ["opening_strike"] if kind == "plain" else ["opening_strike", "lucky_wound"]
		wound.always_drop = true
		wound.arm({"damage": wound.health[0] * 0.6, "crit_chance": 0.0, "crit_damage": 0.0})
		wound.loot_rng.seed = WORLD_SEED
		var tally := [0, 0]
		wound.loot_dropped.connect(func(_i: int, item: Item) -> void:
			tally[0] += int(item.rarity) * 100 + item.level
			tally[1] += 1)
		wound.start()
		_play(wound, 300)
		opened[kind] = tally
	_check(opened["plain"][1] == Encounter.ENEMIES and opened["lucky"] == opened["plain"],
			"a crit that did not kill buys no second roll (%s)" % [opened])
	return true


## Dominoes: what a one-blow kill had left over goes into the next body at its rank's share as that body
## takes its stand, a body it fells passes its own leftover on, and nothing of it reaches an elite.
func _test_dominoes() -> bool:
	var share := UniqueTable.dial("dominoes", "share") / 100.0
	# A thousand into a hundred leaves nine hundred over.
	var fall := _standing(["domino"], {"damage": 999.0}, 100.0)
	fall.health[1] = 1.0e6
	fall.hit()
	fall.advance(Encounter.DEATH)
	_check(fall.hp == 1.0e6, "the next comes on whole (%s)" % fall.hp)
	fall.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fall.hp, 1.0e6 - 900.0 * share), "and takes the share as it stands (%s)" % (1.0e6 - fall.hp))

	# A body the carry is enough for falls as it stands, a one-blow kill, and its leftover goes on.
	var chain := _standing(["domino"], {"damage": 999.0}, 100.0)
	chain.health[1] = 900.0 * share - 10.0
	chain.health[2] = 1.0e6
	chain.hit()
	chain.advance(Encounter.DEATH)
	chain.advance(Encounter.WALK_IN)
	_check(chain.index == 1 and chain.phase == Encounter.Phase.DYING, "the carry fells a body it is enough for")
	chain.advance(Encounter.DEATH)
	chain.advance(Encounter.WALK_IN)
	_check(is_equal_approx(chain.hp, 1.0e6 - 10.0 * share),
			"and what that had left over goes on at the same share (%s)" % (1.0e6 - chain.hp))
	_check(chain.tally.get("domino_streak") == 2, "a body it fells is a one-blow kill (%s)" % [chain.tally])

	# Never into an elite: an ordinary fight's last body is its elite.
	var elite := _standing(["domino"], {"damage": 999.0}, 100.0)
	var last := elite.enemies - 1
	elite.index = last - 1
	elite.health[last - 1] = 100.0
	elite.hp = 100.0
	elite.hit()
	elite.advance(Encounter.DEATH)
	elite.advance(Encounter.WALK_IN)
	_check(EnemyRoster.tier_of(elite.lineup[last]) == EnemyRoster.Tier.ELITE and elite.hp == elite.health[last],
			"nothing is carried into an elite")

	# A body that took two blows carries nothing.
	var slow := _standing(["domino"], {"damage": 59.0}, 100.0)
	slow.hit()
	slow.hit()
	slow.advance(Encounter.DEATH)
	slow.advance(Encounter.WALK_IN)
	_check(slow.hp == slow.health[1], "two blows topple nothing")

	# Cleave beside it: the whole of what was over comes off before the body is out, and the share on top.
	var both := _standing(["domino", "cleave"], {"damage": 999.0}, 100.0)
	both.health[1] = 1.0e6
	both.hit()
	both.advance(Encounter.DEATH)
	_check(both.hp == 1.0e6 - 900.0, "Cleave takes all of it off as the body comes on (%s)" % both.hp)
	both.advance(Encounter.WALK_IN)
	_check(is_equal_approx(both.hp, 1.0e6 - 900.0 - 900.0 * share), "and Dominoes its share as it stands")
	return true


## A fight reads every ranked unique's numbers at the rank it was told (`Encounter.wear`), each the
## card's own figure (`UniqueTable.dial`). A fight told nothing is rank I, which every test above plays.
func _test_unique_ranks() -> bool:
	var told := func(worn: Array, ranks: Dictionary, stats: Dictionary, hp := 1.0e9, env := "grass") -> Encounter:
		var fight := Encounter.for_tile(Vector2i(12, 0), env)
		fight.wear(worn, ranks)
		fight.arm(stats)
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.health[0] = hp
		fight.hp = hp
		return fight
	var four := func(id: String, key: String) -> float: return UniqueTable.dial(id, key, UniqueTable.PEAK)
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# A blow of 10, and what each rank IV piece makes of it.
	var metro: Encounter = told.call(["metronome"], {"metronome": 4}, {"damage": 9.0, "attack_speed": 1.0})
	metro.advance(1.0)
	_check(metro.hp == 1.0e9 - 10.0 * four.call("metronome", "times"), "a Metronome at IV (%s)" % (1.0e9 - metro.hp))
	var band: Encounter = told.call(["berserk"], {"berserkers_band": 4}, {"damage": 9.0})
	band.hit()
	_check(band.hp == 1.0e9 - 10.0 * four.call("berserkers_band", "times"), "a Berserker's Band at IV")
	var edge: Encounter = told.call(["glass_edge"], {"glass_edge": 4}, {"damage": 9.0})
	edge.hit()
	_check(edge.hp == 1.0e9 - 10.0 * four.call("glass_edge", "times"), "a Glass Edge at IV")
	var home: Encounter = told.call(["home:grass"], {"meadowstriders": 3}, {"damage": 9.0})
	home.hit()
	_check(home.hp == 1.0e9 - 10.0 * UniqueTable.dial("meadowstriders", "times", 3), "a home piece at III, on its ground")
	var other: Encounter = told.call(["home:grass"], {"rimeplate": 4}, {"damage": 9.0})
	other.hit()
	_check(other.hp == 1.0e9 - 10.0 * UniqueTable.dial("meadowstriders", "times", 1),
			"and another ground's piece's rank is not its own")
	for case: Array in [["ascetic", "ascetics_cord", "bare_sockets", 4], ["packmule", "packmule", "bag_pieces", 40],
			["patchwork", "patchwork_coat", "attribute_lines", 10], ["purist", "purists_seal", "pure_pieces", 5]]:
		var fight: Encounter = told.call([case[0]], {case[1]: 4}, {"damage": 9.0, case[2]: case[3]})
		fight.hit()
		_check(is_equal_approx(fight.hp, 1.0e9 - roundf(10.0 * (1.0 + four.call(case[1], "more") / 100.0 * case[3]))),
				"%s at IV reads its count at its rank (%s)" % [case[1], 1.0e9 - fight.hp])
	var brawl: Encounter = told.call(["brawler"], {"brawlers_wraps": 4}, {"damage": 9.0, "strength": 50.0})
	brawl.hit()
	_check(brawl.hp == 1.0e9 - roundf(10.0 * (1.0 + four.call("brawlers_wraps", "more") / 100.0 * 50.0)),
			"Brawler's Wraps at IV")
	var gasp: Encounter = told.call(["last_gasp"], {"last_gasp": 4}, {"damage": 9.0})
	gasp.time_left = four.call("last_gasp", "seconds")
	gasp.hit()
	_check(gasp.hp == 1.0e9 - 30.0, "Last Gasp's window at IV")

	# Knucklebone at IV: its rank's step a click, and its rank's most.
	var ring: Encounter = told.call(["knucklebone"], {"knucklebone_ring": 4}, {"damage": 99.0})
	listen.call(ring)
	for i in 100:
		ring.hit()
	# The first click lands before it is counted, so the second is the first with the step on it.
	_check(blows[1] == roundf(100.0 * (1.0 + four.call("knucklebone_ring", "step") / 100.0))
			and blows[-1] == roundf(100.0 * (1.0 + four.call("knucklebone_ring", "most") / 100.0)),
			"a Knucklebone Ring at IV (%s, %s)" % [blows[1], blows[-1]])
	blows.clear()

	# The Headsman's line, the Duelist's opening blows, the Serpent's step.
	var line: float = four.call("headsman", "share")
	# A blow of 101 - line leaves line - 1: under the rank IV line, and well over rank I's.
	var axe: Encounter = told.call(["headsman"], {"headsman": 4}, {"damage": 100.0 - line}, 100.0)
	axe.hit()
	_check(axe.phase == Encounter.Phase.DYING, "a Headsman at IV finishes a body under %s%%" % line)
	var duel: Encounter = told.call(["opening_strike"], {"duelists_buckler": 3}, {"damage": 9.0, "crit_damage": 100.0})
	listen.call(duel)
	for i in 5:
		duel.hit()
	var opening := int(UniqueTable.dial("duelists_buckler", "blows", 3))
	_check(blows.count(20.0) == opening and blows.count(10.0) == 5 - opening,
			"a Duelist's Buckler at III crits the first %d blows (%s)" % [opening, blows])
	blows.clear()
	var serpent: Encounter = told.call(["serpent"], {"serpents_eye": 4}, {"damage": 9.0})
	serpent.hit()
	_check(serpent._serpent == four.call("serpents_eye", "step"), "a Serpent's Eye at IV")

	# The Bulwark's answer, at its rank's share of a swing.
	var wall: Encounter = told.call(["riposte"], {"bulwark": 4}, {"damage": 9.0, "block": 50.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows == [roundf(10.0 * four.call("bulwark", "share") / 100.0)], "a Bulwark at IV answers harder (%s)" % [blows])
	blows.clear()

	# The Gambler's Die reaches its rank's top, and never past it.
	var die: Encounter = told.call(["gamble"], {"gamblers_die": 4}, {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	listen.call(die)
	for i in 2000:
		die.hit()
	var top: float = 1000.0 * four.call("gamblers_die", "top")
	_check(blows.max() <= top and blows.max() > 1000.0 * UniqueTable.dial("gamblers_die", "top", 1),
			"a Gambler's Die at IV (best %s of %s)" % [blows.max(), top])
	blows.clear()

	# What `arm` reads: the Chalice's overflow and the Heartwood's most.
	var chalice := Encounter.for_tile(Vector2i(12, 0), "grass")
	chalice.wear(["overcrit"], {"overflowing_chalice": 4})
	chalice.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(chalice.crit_damage == 50.0 + 30.0 * four.call("overflowing_chalice", "times"), "an Overflowing Chalice at IV")
	var oak := Encounter.for_tile(Vector2i(12, 0), "grass")
	oak.wear(["heartwood"], {"heartwood_plate": 4})
	oak.arm({"armor": 1.0e6})
	_check(oak.seconds == Encounter.SECONDS + four.call("heartwood_plate", "most"), "a Heartwood Plate at IV")

	# What a kill pays: the Hourglass's seconds, the Tithe's purse, Dominoes' share.
	var glass: Encounter = told.call(["hourglass"], {"hourglass_amulet": 4}, {"damage": 1.0e9}, 1.0)
	glass.advance(5.0)
	var before := glass.time_left
	glass.hit()
	_check(is_equal_approx(glass.time_left, before + four.call("hourglass_amulet", "seconds")), "an Hourglass at IV")
	var purses := []
	for ranks: Dictionary in [{}, {"the_tithe": 4}]:
		var fight: Encounter = told.call(["tithe"] if not ranks.is_empty() else [], ranks, {"damage": 1.0e9}, 1.0)
		fight.hit()
		purses.append(fight.gold)
	_check(purses[1] == purses[0] * four.call("the_tithe", "times"), "The Tithe at IV (%s)" % [purses])
	var fall: Encounter = told.call(["domino"], {"dominoes": 4}, {"damage": 999.0}, 100.0)
	fall.health[1] = 1.0e6
	fall.hit()
	fall.advance(Encounter.DEATH)
	fall.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fall.hp, 1.0e6 - 900.0 * four.call("dominoes", "share") / 100.0), "Dominoes at IV")
	return true


## The line each unique gains at rank IV, and that rank III has not got it. Each held to its card.
func _test_rank_four() -> bool:
	var iv := UniqueTable.PEAK
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# Knucklebone Ring: at the full bonus the weapon's swings get it too.
	for rank in [3, iv]:
		var ring := _told(["knucklebone"], {"knucklebone_ring": rank}, {"damage": 99.0})
		var clicks := int(ceilf(UniqueTable.dial("knucklebone_ring", "most", rank)
				/ UniqueTable.dial("knucklebone_ring", "step", rank)))
		for i in clicks:
			ring.hit()
		var swung := ring.unique_more(true)
		_check(is_equal_approx(swung, UniqueTable.dial("knucklebone_ring", "most", rank) / 100.0 if rank == iv else 0.0),
				"a full Knucklebone reaches the swings only at IV (rank %d: %s)" % [rank, swung])

	# Duelist's Buckler: an opening crit on an elite adds its crit damage twice.
	for rank in [3, iv]:
		var duel := _on_last(_told(["opening_strike"], {"duelists_buckler": rank}, {"damage": 9.0, "crit_damage": 100.0}))
		duel._blows = 0
		listen.call(duel)
		duel.hit()
	_check(blows == [20.0, 30.0], "the Buckler's opening crit on an elite, at III and at IV (%s)" % [blows])
	blows.clear()

	# Serpent's Eye: a crit keeps half of what was built.
	for rank in [3, iv]:
		var serpent := _told(["serpent"], {"serpents_eye": rank}, {"damage": 9.0, "crit_chance": 100.0})
		serpent._serpent = 40.0
		serpent.hit()
		_check(serpent._serpent == (40.0 * Encounter.SERPENT_KEPT if rank == iv else 0.0),
				"a crit leaves the Serpent %s at rank %d" % [serpent._serpent, rank])

	# Spiked Helm: a blow blocked whole, or dodged, sends a tenth of the armour back.
	for stats: Dictionary in [{"armor": 1000.0, "block": 1.0e6}, {"armor": 1000.0, "dodge": 1.0e12}]:
		for rank in [3, iv]:
			var helm := _told(["spikes"], {"spiked_helm": rank}, stats)
			helm._struck_by(1.0)
			_check(helm.hp == (1.0e9 - 1000.0 * Encounter.SPIKES_BACK if rank == iv else 1.0e9),
					"the Helm sends %s back at rank %d (%s)" % [1.0e9 - helm.hp, rank, stats.keys()])

	# Ogre's Knuckle: strength is Execute too, to its most.
	for rank in [3, iv]:
		var ogre := _told(["ogre"], {"ogres_knuckle": rank}, {"damage": 75.0, "strength": 1.0e6}, 100.0)
		ogre.hit()
		_check((ogre.phase == Encounter.Phase.DYING) == (rank == iv), "the Knuckle executes 24 of 100 only at IV")

	# Butcher's Cleaver: a body that dies of its wound hands it to the next.
	for rank in [3, iv]:
		var cleaver := _told(["butcher"], {"butchers_cleaver": rank}, {"damage": 19.0, "bleed": 50.0}, 30.0)
		cleaver.hit()
		cleaver.advance(1.0)
		cleaver.advance(Encounter.DEATH)
		_check(cleaver.index == 1 and cleaver._bleed == (10.0 if rank == iv else 0.0),
				"the wound goes on at rank %d: %s" % [rank, cleaver._bleed])

	# The home pieces, on their own grounds: experience, a promised elite, a purse, the clock.
	var meadow := Encounter.for_tile(Vector2i(12, 0), "grass")
	meadow.wear(["home:grass"], {"meadowstriders": iv})
	meadow.arm({})
	_check(meadow.xp_more == Encounter.HOME_XP, "Meadowstriders at IV: double experience on grass")
	var promised := []
	for rank in [3, iv]:
		var lantern := _on_last(_told(["home:forest"], {"hunters_lantern": rank}, {"damage": 1.0e9}, 1.0e9, "forest"), 1.0)
		var found := [0]
		lantern.loot_dropped.connect(func(_i: int, _item: Item) -> void: found[0] += 1)
		lantern.hit()
		promised.append(found[0])
	_check(promised[1] >= 1, "the Lantern at IV: a forest elite always drops (%s)" % [promised])
	var purses := []
	for rank in [3, iv]:
		var cowl := _told(["home:desert"], {"sunscorched_cowl": rank}, {"damage": 1.0e9}, 1.0, "desert")
		cowl.hit()
		purses.append(cowl.gold)
	_check(purses[1] == purses[0] * Encounter.HOME_PURSE, "the Cowl at IV: desert purses twice as full (%s)" % [purses])
	for rank in [3, iv]:
		var rime := _told(["home:ice"], {"rimeplate": rank}, {}, 1.0e9, "ice")
		var left := rime.time_left
		rime.advance(2.0)
		_check(is_equal_approx(left - rime.time_left, 2.0 * (Encounter.HOME_CLOCK if rank == iv else 1.0)),
				"the clock on ice at rank %d" % rank)

	# A second chance at a unique, drawn only where one is owed: an empty pool keeps it to one draw a roll.
	for case: Array in [[["home:mountains"], {"stonebreaker": iv}, "mountains", {}],
			[["lucky_wound"], {"lucky_wound": iv}, "grass", {"crit_chance": 100.0}]]:
		for rank_of: int in [3, iv]:
			var ranks := {}
			for id: String in case[1]:
				ranks[id] = rank_of
			var stats: Dictionary = {"damage": 1.0e9}
			stats.merge(case[3])
			var fight := _on_last(_told(case[0], ranks, stats, 1.0e9, case[2], "village"), 1.0)
			fight.uniques_after = 0
			fight.unlocked = []
			fight.unique_rng.seed = WORLD_SEED
			var reference := RandomNumberGenerator.new()
			reference.seed = WORLD_SEED
			for draw in (2 if rank_of == iv else 1):
				reference.randf()
			fight.hit()
			_check(fight.unique_rng.state == reference.state,
					"%s draws the unique %d time(s) at rank %d" % [case[0], 2 if rank_of == iv else 1, rank_of])

	# Gravedigger's Charm: orbs twice as often on dirt.
	var orbs := []
	for rank in [3, iv]:
		var run := Encounter.farm(Vector2i(12, 0), "dirt")
		run.wear(["home:dirt"], {"gravediggers_charm": rank})
		run.arm({"damage": 1.0e9})
		run.orb_rng.seed = WORLD_SEED
		run.start()
		_play(run, 600)
		orbs.append(run.orbs.values().reduce(func(a: int, b: int) -> int: return a + b, 0))
	_check(orbs[1] > orbs[0] * 1.5, "the Charm at IV: more orbs on dirt (%s)" % [orbs])

	# Bulwark: the answer is always a crit.
	var wall := _told(["riposte"], {"bulwark": iv}, {"damage": 9.0, "block": 50.0, "crit_damage": 100.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows == [roundf(20.0 * UniqueTable.dial("bulwark", "share", iv) / 100.0)], "the Bulwark at IV answers with a crit (%s)" % [blows])
	blows.clear()

	# Brawler's Wraps: strength and dexterity both, on clicks and on swings.
	var brawl := _told(["brawler"], {"brawlers_wraps": iv}, {"damage": 9.0, "strength": 50.0, "dexterity": 100.0})
	var each := UniqueTable.dial("brawlers_wraps", "more", iv) / 100.0 * 150.0
	_check(is_equal_approx(brawl.unique_more(false), each) and is_equal_approx(brawl.unique_more(true), each),
			"the Wraps at IV count both on both")

	# Last Gasp: in its last seconds the enemies hold their blows.
	for rank in [3, iv]:
		var gasp := _told(["last_gasp"], {"last_gasp": rank}, {})
		gasp.strikes = true
		gasp.time_left = 3.0
		gasp.advance(2.5)
		_check(gasp.tally.has("blows_taken") == (rank != iv), "blows in the last seconds at rank %d" % rank)

	# Ascetic's Cord: a little dodge a bare place, never past the most.
	for case: Array in [[4, 4 * Encounter.ASCETIC_DODGE], [100, Encounter.DODGE_MOST]]:
		var cord := _told(["ascetic"], {"ascetics_cord": iv}, {"bare_sockets": case[0]})
		_check(is_equal_approx(cord.dodge_chance(), case[1]), "%d bare places at IV dodge %s" % [case[0], cord.dodge_chance()])

	# Dominoes: into an elite, half of the carry.
	var elite := _told(["domino"], {"dominoes": iv}, {"damage": 999.0}, 100.0)
	var last := elite.enemies - 1
	elite.index = last - 1
	elite.health[last - 1] = 100.0
	elite.health[last] = 1.0e6
	elite.hp = 100.0
	elite.hit()
	elite.advance(Encounter.DEATH)
	elite.advance(Encounter.WALK_IN)
	_check(is_equal_approx(elite.hp, elite.health[last] - 900.0 * UniqueTable.dial("dominoes", "share", iv) / 100.0
			* Encounter.DOMINO_BIG), "Dominoes at IV reaches an elite at half")

	# Gambler's Die: the first blow on each enemy is drawn twice and the better kept.
	var die := _told(["gamble"], {"gamblers_die": iv}, {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	var draws := RandomNumberGenerator.new()
	draws.seed = WORLD_SEED
	var top := UniqueTable.dial("gamblers_die", "top", iv)
	var best := maxf(draws.randf_range(Encounter.GAMBLE_LEAST, top), draws.randf_range(Encounter.GAMBLE_LEAST, top))
	listen.call(die)
	die.hit()
	_check(blows[0] == maxf(1.0, roundf(1000.0 * best)), "the Die at IV draws the first blow twice (%s)" % [blows])
	blows.clear()

	# The Tithe: an elite's gear gets through.
	var through := []
	for rank in [3, iv]:
		var tithe := _on_last(_told(["tithe"], {"the_tithe": rank}, {"damage": 1.0e9}), 1.0)
		tithe.always_drop = true
		var gear := [0]
		tithe.loot_dropped.connect(func(_i: int, _item: Item) -> void: gear[0] += 1)
		tithe.hit()
		through.append(gear[0])
	_check(through[0] == 0 and through[1] >= 1, "the Tithe lets an elite's gear through at IV (%s)" % [through])

	# Heartwood Plate: every enemy's first blow is blocked whole, and a Bulwark answers it.
	var oak := _told(["heartwood", "riposte"], {"heartwood_plate": iv}, {"damage": 9.0})
	listen.call(oak)
	var clock := oak.time_left
	oak._struck_by(5.0)
	_check(oak.time_left == clock and oak.tally.get("blocked") == 1 and blows.size() == 1,
			"the first blow is blocked, counted and answered")
	oak._struck_by(5.0)
	_check(oak.time_left < clock, "and the second is not")
	blows.clear()

	# Hourglass Amulet: a boss kill puts its seconds back.
	for rank in [3, iv]:
		var boss := _on_last(_told(["hourglass"], {"hourglass_amulet": rank}, {"damage": 1.0e9}, 1.0e9, "grass", "village"), 1.0)
		boss.time_left = 10.0
		boss.hit()
		_check(boss.time_left == (10.0 + Encounter.HOURGLASS_BOSS if rank == iv else 10.0), "a boss kill at rank %d" % rank)

	# Metronome: a swing that kills leaves the next swing ready.
	for rank in [3, iv]:
		var metro := _told(["metronome"], {"metronome": rank}, {"damage": 1.0e9, "attack_speed": 1.0}, 1.0)
		metro.advance(1.0)
		_check(metro.phase == Encounter.Phase.DYING and metro._swing == (1.0 if rank == iv else 0.0),
				"the next swing is ready at rank %d" % rank)

	# Berserker's Band: every tenth click strikes twice.
	var band := _told(["berserk"], {"berserkers_band": iv}, {"damage": 9.0})
	listen.call(band)
	for i in Encounter.BERSERK_EVERY:
		band.hit()
	_check(blows[-1] == 2.0 * blows[0] and blows[-2] == blows[0], "the tenth click strikes twice (%s)" % [blows])
	blows.clear()

	# Glass Edge: its damage in a farm run too.
	for rank in [3, iv]:
		var run := Encounter.farm(Vector2i(12, 0), "grass")
		run.wear(["glass_edge"], {"glass_edge": rank})
		_check(is_equal_approx(run.unique_more(false),
				UniqueTable.dial("glass_edge", "times", rank) - 1.0 if rank == iv else 0.0),
				"the Edge in a run at rank %d" % rank)

	# Headsman: what the execution took goes on into the next body.
	var axe := _told(["headsman"], {"headsman": iv}, {"damage": 79.0}, 100.0)
	axe.health[1] = 1.0e6
	axe.hit()
	axe.advance(Encounter.DEATH)
	_check(axe.hp == 1.0e6 - 20.0, "the Headsman at IV carries the 20 it executed (%s)" % (1.0e6 - axe.hp))

	# Overflowing Chalice: about one crit in ten strikes twice.
	var chalice := _told(["overcrit"], {"overflowing_chalice": iv}, {"damage": 9.0, "crit_chance": 100.0})
	chalice.crit_rng.seed = WORLD_SEED
	listen.call(chalice)
	for i in 1000:
		chalice.hit()
	var doubled := blows.count(blows.min() * 2.0)
	_check(doubled > 50 and doubled < 150, "about one crit in ten strikes twice (%d of 1000)" % doubled)
	blows.clear()
	return true
