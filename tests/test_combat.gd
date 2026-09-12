extends "res://tests/harness.gd"
## Headless checks for the tile fight. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_combat.gd
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.


func _run() -> void:
	_check(_test_lineup() == true, "lineup tests ran to the end")
	_check(_test_health() == true, "health tests ran to the end")
	_check(_test_a_won_fight() == true, "won fight tests ran to the end")
	_check(_test_a_lost_fight() == true, "lost fight tests ran to the end")
	_check(_test_hits_only_land_on_a_waiting_enemy() == true, "hit timing tests ran to the end")
	await _test_the_map_hands_over_and_takes_back()
	_report("combat")


func _environments() -> PackedStringArray:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	return envs


## Nine commons and an elite, never a boss, all of them native to the tile's terrain.
func _test_lineup() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(3, 4), env)
		_check(fight.lineup.size() == Encounter.ENEMIES, "%s fields %d enemies" % [env, Encounter.ENEMIES])
		for i in fight.lineup.size():
			var enemy: String = fight.lineup[i]
			var tier := EnemyRoster.tier_of(enemy)
			var wanted := EnemyRoster.Tier.ELITE if i == Encounter.ENEMIES - 1 else EnemyRoster.Tier.COMMON
			_check(tier == wanted, "%s sends %s (%s) as number %d" % [env, enemy, tier, i + 1])
			_check(tier != EnemyRoster.Tier.BOSS, "%s is no boss" % enemy)
			_check(env in EnemyRoster.environments_of(enemy), "%s lives on %s" % [enemy, env])
		_check(EnemyRoster.tier_of(fight.lineup[Encounter.ENEMIES - 1]) == EnemyRoster.Tier.ELITE,
				"%s ends on an elite" % env)

	# A tile always fields the same fight, however often it is attempted.
	var again := Encounter.for_tile(Vector2i(3, 4), "grass")
	_check(again.lineup == Encounter.for_tile(Vector2i(3, 4), "grass").lineup, "a tile keeps its enemies")
	var differ := 0
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(0, 2), Vector2i(-4, 6), Vector2i(7, -2)]:
		if Encounter.for_tile(cell, "grass").lineup != again.lineup:
			differ += 1
	_check(differ >= 3, "other tiles field other enemies (%d of 4 differ)" % differ)
	return true


## Health grows with the walk from the middle of the map, and with the enemy's own size and tier.
func _test_health() -> bool:
	var near := Vector2i(1, 0)
	var far := Vector2i(20, 0)
	_check(HexGrid.distance(MapBuilder.CENTER, near) == 1, "the near cell is the first ring")
	_check(Encounter.base_hp(near) == Encounter.BASE_HP + Encounter.HP_PER_STEP, "an ordinary body next door")
	_check(Encounter.base_hp(far) > Encounter.base_hp(near), "and a tougher one at the edge")

	for enemy in EnemyRoster.names():
		_check(Encounter.hp_of(enemy, near) >= 1, "%s is worth at least one click" % enemy)
		_check(Encounter.hp_of(enemy, far) > Encounter.hp_of(enemy, near), "%s is tougher further out" % enemy)
	_check(Encounter.hp_of("Slime", near) < Encounter.hp_of("Skeleton Warrior", near), "a slime is the softest")

	# The elite is the wall at the end: it must outlast any common the same tile can send.
	var fight := Encounter.for_tile(near, "grass")
	var elite: int = fight.health[Encounter.ENEMIES - 1]
	for i in Encounter.ENEMIES - 1:
		_check(elite > fight.health[i], "the elite outlasts enemy %d" % [i + 1])
	return true


## Ten enemies clicked down inside the minute, with the clock running through every walk-in and death.
func _test_a_won_fight() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	var coming: Array[String] = []
	var spawned: Array[int] = []
	var died: Array[int] = []
	var results: Array[bool] = []
	fight.enemy_coming.connect(func(_i: int, n: String, _hp: int) -> void: coming.append(n))
	fight.enemy_spawned.connect(func(i: int, _n: String, _hp: int) -> void: spawned.append(i))
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

	# The far edge is meant to be hard but possible: the whole fight has to fit in the minute at a
	# realistic click rate, with the walk-ins and deaths eating into it.
	var far := Encounter.for_tile(Vector2i(20, 0), "grass")
	var total := 0
	for hp: int in far.health:
		total += hp
	var spare := Encounter.SECONDS - Encounter.ENEMIES * (Encounter.WALK_IN + Encounter.DEATH)
	print("Edge fight: %d clicks in %.1fs of clicking time (%.1f/s)" % [total, spare, total / spare])
	_check(total / spare < 8.0, "the far edge is beatable at a human click rate (%.1f/s)" % (total / spare))
	_check(total / spare > 1.0, "and is not a walkover (%.1f/s)" % (total / spare))
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


## Discovering a tile goes through a fight now, so the map has to hand over and take back cleanly:
## winning discovers the tile as it always did, losing leaves the map exactly as it was.
func _test_the_map_hands_over_and_takes_back() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	root.add_child(main)
	for i in 3:
		await process_frame

	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	_check(main.view.can_discover(target), "the tile next door can be fought for")

	# Losing changes nothing.
	main.map.select_cell(target)
	main._on_discover_pressed()
	_check(main._combat != null, "pressing Discover starts a fight")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"the map stops while the fight is on")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	_check(main._combat == null, "the fight is torn down")
	_check(main.map.visible and main.map.process_mode == Node.PROCESS_MODE_INHERIT, "and the map is back")
	_check(not main.view.discovered(target), "a lost tile stays undiscovered")
	_check(main.view.can_discover(target), "and can be fought for again straight away")

	# Winning discovers it, exactly as pressing Discover used to.
	main._on_discover_pressed()
	var fight: Encounter = main._combat.fight
	_play(fight, 10000)
	_check(fight.victory, "the rematch is won")
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.discovered(target), "a won tile is discovered")
	_check(main.map.visible, "and the map is back")
	main.queue_free()


## Clicks the fight to its end at a steady rate, stepping the clock between clicks. Returns the clicks
## it took. `limit` stops a broken encounter from looping forever.
func _play(fight: Encounter, limit: int) -> int:
	var clicks := 0
	var step := 1.0 / 8.0   # A brisk but human eight clicks a second.
	while not fight.finished and clicks < limit:
		if not fight.hit():
			fight.advance(step)      # Walking in or dying: let the clock run.
			continue
		clicks += 1
		fight.advance(step)
	return clicks
