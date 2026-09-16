extends "res://tests/harness.gd"
## Headless checks for the tile fight. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_combat.gd
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.

## Never the player's own two saves: the scene test fights, drops loot and explores. They are cleared
## at the *start* of a run rather than the end, because the scene writes its map from _exit_tree,
## which fires as the tree comes down after the last line of _run -- so a run always leaves one
## behind, and only the next run starting clean can be relied on. A map left over from last time
## would be loaded, and the fight would be handed a tile that had already been taken.
const SCRATCH_INVENTORY := "user://test_combat_inventory.json"
const SCRATCH_MAP := "user://test_combat_map.json"


func _run() -> void:
	_clear_saves()
	_check(_test_lineup() == true, "lineup tests ran to the end")
	_check(_test_health() == true, "health tests ran to the end")
	_check(_test_a_won_fight() == true, "won fight tests ran to the end")
	_check(_test_a_lost_fight() == true, "lost fight tests ran to the end")
	_check(_test_hits_only_land_on_a_waiting_enemy() == true, "hit timing tests ran to the end")
	_check(_test_what_a_hit_is_worth() == true, "damage tests ran to the end")
	_check(_test_the_weapon_swings_itself() == true, "attack speed tests ran to the end")
	_check(_test_backdrops() == true, "backdrop tests ran to the end")
	_check(_test_backdrop_layouts() == true, "backdrop layout tests ran to the end")
	_check(_test_a_farm_run_never_ends() == true, "farm run tests ran to the end")
	_check(_test_a_settlement_is_a_set_piece() == true, "settlement fight tests ran to the end")
	_check(_test_gold() == true, "gold tests ran to the end")
	_check(_test_coins() == true, "coin tests ran to the end")
	_check(_test_orb_drops() == true, "orb drop tests ran to the end")
	await _test_thrown_finds()
	await _test_the_nameplate_wears_the_tier()
	await _test_the_map_hands_over_and_takes_back()
	_report("combat")


func _clear_saves() -> void:
	for path in [SCRATCH_INVENTORY, SCRATCH_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _environments() -> PackedStringArray:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	return envs


## What a click takes off, and what a crit turns it into.
func _test_what_a_hit_is_worth() -> bool:
	var fight := Encounter.for_tile(Vector2i(3, 0), "grass")
	fight.start()
	fight.advance(Encounter.WALK_IN)
	_check(fight.damage == Encounter.BARE_DAMAGE, "an unarmed fight does %d a click" % Encounter.BARE_DAMAGE)
	_check(fight.attack_speed == 0.0, "and nothing swings on its own")
	var before := fight.hp
	fight.hit()
	_check(fight.hp == before - Encounter.BARE_DAMAGE, "a bare-handed click takes one point off")

	# Gear is read once, and a sword is worth its damage on top of the fist, never instead of it.
	var armed := Encounter.for_tile(Vector2i(3, 0), "grass")
	armed.arm({"damage": 4.0, "crit_chance": 0.0, "crit_damage": 50.0, "attack_speed": 0.0})
	armed.start()
	armed.advance(Encounter.WALK_IN)
	var landed: Array = []
	armed.hit_landed.connect(func(amount: int, crit: bool, auto: bool) -> void:
		landed.append([amount, crit, auto]))
	var full := armed.hp
	armed.hit()
	_check(armed.damage == 5, "four points of gear plus the fist is five")
	_check(armed.hp == full - 5, "and five comes off")
	_check(landed.size() == 1 and landed[0] == [5, false, false],
			"the blow is reported as a click for five")

	# A certain crit adds its crit damage, and no more: 50 is half again, not fifty times.
	var critting := Encounter.for_tile(Vector2i(3, 0), "grass")
	critting.arm({"damage": 3.0, "crit_chance": 100.0, "crit_damage": 50.0, "attack_speed": 0.0})
	critting.start()
	critting.advance(Encounter.WALK_IN)
	var crits: Array = []
	critting.hit_landed.connect(func(_a: int, crit: bool, _auto: bool) -> void: crits.append(crit))
	var start_hp := critting.hp
	critting.hit()
	_check(critting.hp == start_hp - 6, "a crit on four damage at +50%% is six, not %d"
			% (start_hp - critting.hp))
	_check(crits == [true], "and says it crit")

	# Crit chance is a percentage, so zero never crits however many times it is asked.
	var never := Encounter.for_tile(Vector2i(0, 0), "grass")
	never.arm({"damage": 1.0, "crit_chance": 0.0, "crit_damage": 500.0, "attack_speed": 0.0})
	never.start()
	never.advance(Encounter.WALK_IN)
	var any := [false]
	never.hit_landed.connect(func(_a: int, crit: bool, _auto: bool) -> void: any[0] = any[0] or crit)
	for i in 200:
		never.hit()
		if never.phase != Encounter.Phase.WAITING:
			never.advance(Encounter.DEATH + Encounter.WALK_IN)
	_check(not any[0], "no crit chance never crits")

	# And a chance in between is a chance: a quarter crits about a quarter of the time, not always.
	# Loose bounds on purpose -- this holds that the roll happens at all, not that the RNG is fair.
	var sometimes := Encounter.farm(Vector2i(0, 0), "grass")
	sometimes.arm({"damage": 1.0, "crit_chance": 25.0, "crit_damage": 50.0, "attack_speed": 0.0})
	sometimes.start()
	sometimes.advance(Encounter.WALK_IN)
	var tally := [0, 0]
	sometimes.hit_landed.connect(func(_a: int, crit: bool, _auto: bool) -> void:
		tally[0] += 1
		tally[1] += 1 if crit else 0)
	for i in 2000:
		sometimes.hit()
		if sometimes.phase != Encounter.Phase.WAITING:
			sometimes.advance(Encounter.DEATH + Encounter.WALK_IN)
	var share := 100.0 * float(tally[1]) / float(maxi(int(tally[0]), 1))
	_check(share > 15.0 and share < 35.0, "a quarter crit chance crits about a quarter (%.0f%%)" % share)

	# Gear that adds up past certainty is still a chance, not a promise: a save written before a
	# probability stopped taking the level multiplier holds pieces that do exactly that.
	var piled := Encounter.for_tile(Vector2i(0, 0), "grass")
	piled.arm({"damage": 1.0, "crit_chance": 400.0, "crit_damage": 50.0, "attack_speed": 0.0})
	_check(piled.crit_chance == Encounter.CRIT_CAP, "crit chance is capped at %d%%" % Encounter.CRIT_CAP)
	return true


## The weapon swinging on its own: it lands, it counts, and it earns nothing while there is nobody
## standing there to hit.
func _test_the_weapon_swings_itself() -> bool:
	var fight := Encounter.for_tile(Vector2i(40, 0), "grass")
	fight.arm({"damage": 0.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 2.0})
	fight.start()
	var automatic := [0]
	fight.hit_landed.connect(func(_a: int, _c: bool, auto: bool) -> void:
		if auto:
			automatic[0] += 1)

	# Nothing swings while the first enemy is still walking in.
	fight.advance(Encounter.WALK_IN * 0.5)
	_check(automatic[0] == 0, "the weapon waits for something to hit")
	fight.advance(Encounter.WALK_IN * 0.5)
	_check(fight.phase == Encounter.Phase.WAITING, "the enemy is up")

	# Two a second means two in a second, whether that second arrives in one step or in many.
	fight.advance(1.0)
	_check(automatic[0] == 2, "two swings in a second, not %d" % automatic[0])
	for i in 10:
		fight.advance(0.1)
	_check(automatic[0] == 4, "and two more across ten tenths, not %d" % (automatic[0] - 2))

	# A fight with a weapon and no hands at all still gets somewhere, which is what idle damage is.
	var idle := Encounter.for_tile(Vector2i(1, 0), "grass")
	idle.arm({"damage": 9.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 8.0})
	idle.start()
	for i in int(Encounter.SECONDS / 0.05):
		idle.advance(0.05)
	_check(idle.finished and idle.victory, "a fast weapon wins the first ring on its own")
	return true


## Every place the world can send the player to has a backdrop, and anything else falls back rather
## than leaving a fight with nothing behind it.
func _test_backdrops() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(1, 2), env)
		_check(fight.env == env, "the fight on %s knows its terrain" % env)
		for variant in ["plain", "road", "village", "town", "fortress"]:
			for layout in range(1, CombatScene.AREA_LAYOUTS + 1):
				var path: String = CombatScene.AREA_PATH % [env, variant, layout]
				_check(ResourceLoader.exists(path),
						"%s has a %s backdrop (%d)" % [env, variant, layout])
				# One at a time, and never cached: a backdrop is 2304x1296, and holding all of them
				# at once would be over a gigabyte of texture for a size check.
				var art: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
				# The fighters are placed as a share of the picture, so every backdrop is the same
				# shape: one that was not would stand them off the ground.
				_check(art != null and art.get_size() == Vector2(2304, 1296),
						"%s/%s/%d is the standard size" % [env, variant, layout])
			_check(CombatScene.backdrop_for(env, variant) != null, "%s/%s loads" % [env, variant])

	var fallback := CombatScene.backdrop_for("swamp", "plain")
	_check(fallback == load(CombatScene.AREA_FALLBACK), "terrain with no art falls back")
	# A layout number that was never drawn is clamped rather than left as a missing file: the number
	# comes out of a hash, and a fight with no picture behind it would be unplayable.
	_check(CombatScene.backdrop_for("grass", "village", 99) != null, "a layout past the end clamps")
	_check(CombatScene.backdrop_for("grass", "village", 0) != null, "and so does one before it")
	return true


## A tile always fights on the same backdrop, and neighbouring tiles do not all fight on one.
func _test_backdrop_layouts() -> bool:
	var cell := Vector2i(3, 4)
	var pick := CombatScene.layout_for(cell)
	_check(CombatScene.layout_for(cell) == pick, "a tile keeps its backdrop")
	_check(pick >= 1 and pick <= CombatScene.AREA_LAYOUTS, "and it is one that was drawn")
	var seen := {}
	for x in 40:
		for y in 4:
			seen[CombatScene.layout_for(Vector2i(x, y))] = true
	_check(seen.size() == CombatScene.AREA_LAYOUTS,
			"all %d layouts turn up on a map (saw %d)" % [CombatScene.AREA_LAYOUTS, seen.size()])
	return true


## Nine commons and an elite, never a boss, all of them native to the tile's terrain.
func _test_lineup() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(3, 4), env)
		_check(fight.enemies == Encounter.ENEMIES and fight.seconds == Encounter.SECONDS,
				"%s fights open land's own fight: %d in %.0fs" % [env, fight.enemies, fight.seconds])
		_check(fight.lineup.size() == fight.enemies, "%s fields %d enemies" % [env, fight.enemies])
		for i in fight.lineup.size():
			var enemy: String = fight.lineup[i]
			var tier := EnemyRoster.tier_of(enemy)
			var wanted := EnemyRoster.Tier.ELITE if i == fight.enemies - 1 else EnemyRoster.Tier.COMMON
			_check(tier == wanted, "%s sends %s (%s) as number %d" % [env, enemy, tier, i + 1])
			# The HUD's bar draws a farm run's pips before their enemies are rolled, so it asks the
			# position rather than the roster. The two must never drift.
			_check(fight.tier_for(i) == tier,
					"tier_for(%d) agrees with the enemy the lineup put there" % i)
			_check(tier != EnemyRoster.Tier.BOSS, "%s is no boss" % enemy)
			_check(env in EnemyRoster.environments_of(enemy), "%s lives on %s" % [enemy, env])
		_check(EnemyRoster.tier_of(fight.lineup[fight.enemies - 1]) == EnemyRoster.Tier.ELITE,
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


## What a body is carrying: one gold at the very middle, growing with the walk both ways at once,
## and worth what the body itself was worth to kill.
func _test_gold() -> bool:
	_check(Encounter.base_gold(MapBuilder.CENTER) == 1, "a body in the middle carries one gold")
	_check(Encounter.gold_of("Skeleton Warrior", MapBuilder.CENTER) == 1,
			"and so does an ordinary common one, which is where the curve is pinned")

	# Linear *and* exponential: every step adds GOLD_PER_STEP and multiplies by GOLD_GROWTH. Checked
	# step by step out to the edge, with the slack rounding to whole gold allows.
	for steps in range(0, 21):
		var here := Vector2i(steps, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		var want: float = (Encounter.BASE_GOLD + Encounter.GOLD_PER_STEP * steps) 				* pow(Encounter.GOLD_GROWTH, steps)
		_check(absf(Encounter.base_gold(here) - want) <= 0.5,
				"step %d carries %d, not the curve's %.1f" % [steps, Encounter.base_gold(here), want])
		if steps > 0:
			_check(Encounter.base_gold(here) > Encounter.base_gold(Vector2i(steps - 1, 0)),
					"step %d pays better than step %d" % [steps, steps - 1])

	# A purse is worth what the body was worth to kill, so it is the same hp_modifier its health is,
	# and nobody keeps a second table in step with the first. Floored at one all the same.
	var far := Vector2i(12, 0)
	for enemy in EnemyRoster.names():
		_check(Encounter.gold_of(enemy, MapBuilder.CENTER) >= 1, "%s carries at least one gold" % enemy)
		_check(Encounter.gold_of(enemy, far) > Encounter.gold_of(enemy, MapBuilder.CENTER),
				"%s carries more further out" % enemy)
	_check(Encounter.gold_of("Grass Slime", far) < Encounter.gold_of("Skeleton Warrior", far),
			"a slime carries the least")
	_check(Encounter.gold_of("Skeleton Warrior", far) < Encounter.gold_of("Medusa", far),
			"and an elite more than a common of the same size")

	# Every body pays, unlike every body dropping something: what the fight has earned is the sum of
	# what fell off it, and nothing is rolled for.
	var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
	var purses: Array = []
	fight.gold_dropped.connect(func(_index: int, amount: int) -> void: purses.append(amount))
	fight.start()
	_play(fight, 4000)
	_check(fight.finished and fight.victory, "the fight was won")
	_check(purses.size() == Encounter.ENEMIES, "all %d bodies paid, not %d"
			% [Encounter.ENEMIES, purses.size()])
	var summed := 0
	for purse: int in purses:
		summed += purse
	_check(fight.gold == summed, "the fight holds %d gold, and %d fell" % [fight.gold, summed])

	# A lost fight keeps what fell before the clock ran out, the way its drops do.
	var lost := Encounter.for_tile(Vector2i(4, 0), "grass")
	lost.start()
	_play(lost, 30)
	var banked := lost.gold
	_check(banked > 0, "a body or two went down before giving up")
	lost.give_up()
	_check(lost.gold == banked, "and giving up keeps every purse that fell")
	return true


## The coins a purse is drawn as: how many of them, and the sheet they are cut from.
func _test_coins() -> bool:
	# 1 + log10, floored. A decade of gold buys one more coin, and nothing else moves the count.
	_check(Coins.count_for(1) == 1, "one gold is one coin")
	_check(Coins.count_for(9) == 1, "and so is nine")
	_check(Coins.count_for(10) == 2, "ten is two")
	_check(Coins.count_for(99) == 2, "and so is ninety-nine")
	_check(Coins.count_for(100) == 3, "a hundred is three")
	_check(Coins.count_for(1000) == 4, "a thousand is four")
	_check(Coins.count_for(1000000) == 7, "and a million is only seven")
	# A body always throws something, whatever nonsense it is handed: gold is floored at one, but
	# nothing downstream should have to know that for a body to be seen to pay.
	_check(Coins.count_for(0) == 1, "an empty purse still throws a coin")
	_check(Coins.count_for(-5) == 1, "and so does an impossible one")
	var last := 0
	for amount in [1, 10, 100, 1000, 10000]:
		_check(Coins.count_for(amount) > last, "%d throws more than the decade under it" % amount)
		last = Coins.count_for(amount)

	# The sheet's geometry, which is measured rather than guessed -- this is what fails loudly if the
	# coin is ever re-exported at another size or with another number of frames in it.
	var spin := Coins.frames()
	_check(spin.has_animation("spin"), "the coin has a spin")
	_check(spin.get_frame_count("spin") == Coins.FRAMES,
			"of %d frames, not %d" % [Coins.FRAMES, spin.get_frame_count("spin")])
	_check(spin.get_animation_loop("spin"), "and it loops")
	_check(Coins.SHEET.get_width() >= Coins.FRAMES * Coins.SIZE,
			"the sheet holds them: %d px" % Coins.SHEET.get_width())
	_check(Coins.SHEET.get_height() == Coins.SIZE,
			"one row of them: %d px" % Coins.SHEET.get_height())
	_check(Coins.icon().region == Rect2(0, 0, Coins.SIZE, Coins.SIZE),
			"the resting coin is the first frame")
	_check(Coins.icon() == Coins.icon(), "and it is built once")
	return true


## The nameplate's bar drains with the enemy and wears that enemy's tier. Needs a scene rather than an
## Encounter: the encounter knows the hit points and the view is what turns them into a width.
##
## The two halves are one test because they are one claim. The bar and the kill pips both read
## Encounter.tier_in, so what this really holds is that the frame over the enemy's head and the pip
## standing for it are the same answer -- a green-framed bar over a common, or a brown one over the
## elite, would be worse than either of them simply being the wrong colour.
func _test_the_nameplate_wears_the_tier() -> void:
	var cell := Vector2i(4, 0)
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var fight := Encounter.for_tile(cell, "grass")
	combat.begin(fight, cell, 2.0)
	await process_frame
	var bar := combat._enemy_bar
	var full := HealthBar.TROUGH * HealthBar.PIXEL

	# A tile fight opens on a common, and opens full.
	_check(Encounter.tier_in(fight, 0) == EnemyRoster.Tier.COMMON, "the first of the ten is a common")
	_check(bar._fill.size.x == full, "a fight opens with the bar full")
	_check(bar._cap_l.texture == HealthBar.CAP_L[EnemyRoster.Tier.COMMON],
			"wearing the common frame")

	# Take the enemy down and the red follows it, in proportion. Set rather than hit, so this measures
	# the bar and not the damage tables -- and measured against the share the fight actually has
	# rather than against a half, because hit points are whole numbers and the first commons have
	# very few of them: half of seven is three, and the bar is honest about that.
	var max_hp := fight.enemy_max_hp()
	fight.hp = max_hp / 2
	combat._refresh()
	var want := float(full) * fight.hp / max_hp
	_check(absf(bar._fill.size.x - want) <= HealthBar.PIXEL,
			"%d of %d hit points is %d px of the bar's %d, wanted about %d"
					% [fight.hp, max_hp, bar._fill.size.x, full, want])
	fight.hp = 1
	combat._refresh()
	_check(bar._fill.size.x > 0.0 and bar._fill.size.x < full / 4.0,
			"one hit point left still shows, and shows as nearly nothing")

	# Walk the lineup to the elite. The frame changes and the trough does not.
	var elite := fight.enemies - 1
	_check(Encounter.tier_in(fight, elite) == EnemyRoster.Tier.ELITE, "the tenth is the elite")
	fight.index = elite
	fight.hp = fight.enemy_max_hp()
	combat._refresh()
	_check(bar._cap_l.texture == HealthBar.CAP_L[EnemyRoster.Tier.ELITE],
			"the elite's own frame is worn when it walks in")
	_check(bar._tracks[0].texture == HealthBar.TRACK[EnemyRoster.Tier.ELITE],
			"and its rail with it, not only its ends")
	_check(bar._fill.size.x == full, "an elite at full health is exactly as much red as a common")
	_check(bar.custom_minimum_size.x > HealthBar.width_of(EnemyRoster.Tier.COMMON),
			"and its bar is the wider one")

	# The pips beside it are drawn in that same tier, which is the whole reason the lookup was shared
	# rather than written out twice. The elite is the last of the ten, so it is the last pip.
	_check(combat._pips._pips[elite].texture == KillPips.BODY[EnemyRoster.Tier.ELITE],
			"the pip standing for the elite is green, like the frame over its head")

	# Nothing standing means no nameplate at all, rather than an empty frame.
	fight.index = fight.lineup.size()
	combat._refresh()
	_check(not combat._enemy_panel.visible, "with the lineup spent the nameplate goes")
	combat.queue_free()
	await process_frame

	# A settlement is a longer fight, so its bar is a longer bar: a pip an enemy, gold at the end,
	# and the clock still cut to exactly the width of the pips above it.
	var town: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(town)
	var siege := Encounter.for_tile(cell, "grass", "village")
	town.begin(siege, cell, 2.0, "village")
	await process_frame
	_check(town._pips._pips.size() == siege.enemies,
			"a village's bar stands %d pips, not %d" % [siege.enemies, town._pips._pips.size()])
	_check(town._pips._pips[siege.enemies - 1].texture == KillPips.BODY[EnemyRoster.Tier.BOSS],
			"and the pip at its far end is the boss's gold")
	_check(town._pips._tail.texture == KillPips.TAIL[EnemyRoster.Tier.BOSS],
			"which the bar closes in, the way it closes in whatever is at its end")
	_check(town._clock_fill.get_parent().size.x
			== KillPips.width_for(siege.enemies) - 2 * CombatScene.BAR_BORDER,
			"the clock is cut to the pip bar it stands under")
	town.queue_free()
	await process_frame


## What a body drops lands in the arena, the way its purse does: a sprite thrown out of it, glowing
## in its rarity above common, and no panel anywhere. Needs a scene rather than an Encounter, because
## the throwing is the view's half of it.
func _test_thrown_finds() -> void:
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.begin(Encounter.for_tile(Vector2i(4, 0), "grass"), Vector2i(4, 0), 2.0)
	await process_frame
	_check(combat._finds_shown == 0, "a fight starts having thrown nothing")

	# A common piece: the icon and nothing else. Counted by what is on the scene rather than only by
	# the tally, so this fails if the throw ever stops reaching the tree.
	var before := combat.get_child_count()
	combat._on_loot_dropped(0, _thrown_piece(ItemRarity.Rarity.COMMON))
	_check(combat._finds_shown == 1, "a kept find is thrown")
	_check(combat.get_child_count() == before + 1, "and it is a node in the arena")
	var plain := combat.get_child(combat.get_child_count() - 1)
	_check(plain is Sprite2D, "drawn as a sprite, like a coin")
	_check(plain.get_child_count() == 0, "with no beam over a common piece")

	# A rare one carries the wash of its own colour behind it.
	var rare := _thrown_piece(ItemRarity.Rarity.RARE)
	combat._on_loot_dropped(1, rare)
	_check(combat._finds_shown == 2, "and so is the next")
	var lit := combat.get_child(combat.get_child_count() - 1)
	_check(lit.get_child_count() == 1, "a rare piece is thrown with a beam over it")
	if lit.get_child_count() == 1:
		var beam := lit.get_child(0) as AnimatedSprite2D
		_check(beam != null, "the pack's own flame, playing")
		if beam != null:
			# The white colourway tinted, which is the whole reason one sheet serves the ramp: white
			# times a colour is that colour, and any other colourway would come back muddied.
			var want: Color = ItemRarity.BORDER_COLORS[rare.rarity]
			_check(is_equal_approx(beam.modulate.r, want.r) and is_equal_approx(beam.modulate.g, want.g)
					and is_equal_approx(beam.modulate.b, want.b), "in the rarity's own colour")
			_check(beam.is_playing() and beam.animation == "burn", "and it burns")
			_check(is_equal_approx(beam.rotation, LootBeam.RISE), "stood up out of the pack's comet")
			_check(beam.z_index < 0 and beam.position.y < 0.0, "behind the piece and over it")

	# The sheet's geometry, measured rather than guessed, the way the coin's is.
	var burn := LootBeam.frames()
	_check(burn.has_animation("burn"), "the beam has a burn")
	_check(burn.get_frame_count("burn") == LootBeam.FRAMES,
			"of %d frames, not %d" % [LootBeam.FRAMES, burn.get_frame_count("burn")])
	_check(burn.get_animation_loop("burn"), "and it loops")
	_check(LootBeam.SHEET.get_width() == LootBeam.FRAMES * LootBeam.SIZE
			and LootBeam.SHEET.get_height() == LootBeam.SIZE,
			"one row of %d square frames: %dx%d" % [LootBeam.FRAMES,
					LootBeam.SHEET.get_width(), LootBeam.SHEET.get_height()])
	_check(LootBeam.frames() == LootBeam.frames(), "and it is built once")

	# An orb is thrown the same way and plain: it has no rarity to borrow.
	combat._on_orb_dropped(2, OrbTable.ORBS.keys()[0])
	_check(combat._finds_shown == 3, "an orb is thrown too")
	_check(combat.get_child(combat.get_child_count() - 1).get_child_count() == 0,
			"and never carries a beam")

	# The toasts are gone, so nothing may still be reaching for them.
	_check(not ("_toasts" in combat), "there is no toast left to raise")
	combat.queue_free()
	await process_frame


## A piece to throw. The type is any real one -- what is being checked is the throw, not the roll.
func _thrown_piece(rarity: ItemRarity.Rarity) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = 1
	item.stats = Item.scaled_stats(item.type, 1)
	return item


## Health grows with the walk from the middle of the map, and with the enemy's own size and tier.
func _test_health() -> bool:
	var near := Vector2i(1, 0)
	var far := Vector2i(20, 0)
	_check(HexGrid.distance(MapBuilder.CENTER, near) == 1, "the near cell is the first ring")
	_check(Encounter.base_hp(MapBuilder.CENTER) == Encounter.BASE_HP, "an ordinary body in the middle")
	_check(Encounter.base_hp(far) > Encounter.base_hp(near), "and a tougher one at the edge")

	# Health is exponential in the walk, not a flat sum: every step multiplies by HP_GROWTH, so the
	# frontier pulls away from whatever the player is carrying. Checked step by step out to the edge,
	# with the slack that rounding to whole points of health allows.
	for steps in range(1, 21):
		var here := Vector2i(steps, 0)
		var back := Vector2i(steps - 1, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		_check(Encounter.base_hp(here) > Encounter.base_hp(back),
				"step %d is tougher than step %d" % [steps, steps - 1])
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps)
		_check(absf(Encounter.base_hp(here) - want) <= 0.5,
				"step %d is %d, not the curve's %.1f" % [steps, Encounter.base_hp(here), want])

	for enemy in EnemyRoster.names():
		_check(Encounter.hp_of(enemy, near) >= 1, "%s is worth at least one click" % enemy)
		_check(Encounter.hp_of(enemy, far) > Encounter.hp_of(enemy, near), "%s is tougher further out" % enemy)
	_check(Encounter.hp_of("Grass Slime", near) < Encounter.hp_of("Skeleton Warrior", near), "a slime is the softest")

	# The elite is the wall at the end: it must outlast any common the same tile can send.
	var fight := Encounter.for_tile(near, "grass")
	var elite: int = fight.health[fight.enemies - 1]
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

	# How much of the clock is actually spent fighting: the rest goes on enemies walking in and
	# dying. At SECONDS that overhead is a third of the fight, which is what makes the frontier the
	# problem it is below.
	var spare := Encounter.SECONDS - Encounter.ENEMIES * (Encounter.WALK_IN + Encounter.DEATH)
	# The first ring stays beatable with nothing on at all: it is where a new player starts, and it
	# must never need gear they have not been given a chance to find.
	var bare := _click_rate(Encounter.for_tile(Vector2i(1, 0), "grass"), spare,
			Encounter.BARE_DAMAGE, 0.0)
	_check(bare < 8.0, "the first ring is beatable with nothing on (%.1f/s)" % bare)

	# The far edge is meant to be hard but possible, and since the clock came down to SECONDS it is
	# no longer possible in the plain gear a tile hands over. That is the design, not a regression:
	# the frontier is past what unmodified pieces carry, and reaching it means farming for better
	# rolls. Farming cannot raise the level a tile drops at -- that ceiling is the tile's own -- so
	# what a long run actually buys is modifiers, which is what `_farmed` builds. Both halves are
	# pinned here, because either one alone would let the map drift out of reach or into a walkover.
	var edge := Vector2i(20, 0)
	var level := MapBuilder.level_of(edge)
	var plain := _rate_for(edge, _commons(level), spare)
	_check(plain >= 8.0, "the far edge is past a plain set of commons (%.1f/s)" % plain)

	var far := Encounter.for_tile(edge, "grass")
	far.arm(_farmed(level, ItemRarity.Rarity.RARE).totals())
	var per_hit := far.damage * (1.0 + far.crit_chance / 100.0 * far.crit_damage / 100.0)
	var rate := _click_rate(far, spare, per_hit, far.attack_speed)
	print("Edge fight in a farmed set of rares: %d health, %.2f a hit, %.1f swings/s free, %.1f clicks/s"
			% [_total_health(far), per_hit, far.attack_speed, rate])
	_check(rate < 8.0, "the far edge is beatable in farmed gear at a human click rate (%.1f/s)" % rate)
	# And gear has to be worth wearing: the same fight must want fewer clicks than bare hands.
	_check(rate < _click_rate(far, spare, Encounter.BARE_DAMAGE, 0.0), "gear beats bare hands there")
	_check(rate > 1.0, "and is not a walkover in farmed gear either (%.1f/s)" % rate)
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
	# A fight drops loot into whatever inventory the scene was pointed at, so never the player's own.
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
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
## Every point of health in a fight, the whole ten.
func _total_health(fight: Encounter) -> float:
	var total := 0.0
	for hp: int in fight.health:
		total += hp
	return total


## How many clicks a second this fight needs, given what a hit is worth and what the weapon swings
## for free. The automatic swings come off the top: they are damage the player does not have to ask
## for, which is exactly what attack speed buys.
func _click_rate(fight: Encounter, seconds: float, per_hit: float, swings: float) -> float:
	var left := maxf(0.0, _total_health(fight) - seconds * swings * per_hit)
	return left / per_hit / seconds


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


## A plain set at `level`: one common piece in every socket, the modest gear a player would have by
## the time they reached that far out. Nothing rolled, so the reference set cannot drift with the
## dice -- but the pieces are scaled, because a player at the frontier is carrying frontier gear and
## measuring level-1 gear against a frontier fight measures a fight nobody will ever have.
## What a set of gear has to be clicked at to beat the fight on `cell` inside `seconds`. Asked of an
## armed Encounter rather than worked out beside one, so it uses exactly the numbers the fight will.
func _rate_for(cell: Vector2i, gear: Equipment, seconds: float, variant := "") -> float:
	var fight := Encounter.for_tile(cell, "grass", variant)
	fight.arm(gear.totals())
	var per_hit := fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0)
	return _click_rate(fight, seconds, per_hit, fight.attack_speed)


## A set the player has farmed for: the same pieces at the same level, carrying the modifiers a
## rarity buys. Seeded, so the frontier is measured against the same set on every run.
func _farmed(level: int, rarity: ItemRarity.Rarity) -> Equipment:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["farmed", level, rarity])
	var gear := Equipment.new()
	for socket: Equipment.Socket in Equipment.sockets():
		for type in LootTable.items():
			if LootTable.slot_of(type) != Equipment.TAKES[socket]:
				continue
			var item := Item.new()
			item.type = type
			item.rarity = rarity
			item.level = level
			item.stats = Item.scaled_stats(type, level)
			var band: Array = ItemRarity.MOD_COUNT[rarity]
			item.mods = ModifierTable.roll(type, rng.randi_range(band[0], band[1]), rng, level)
			gear.equip(socket, item)
			break
	return gear


func _commons(level := 1) -> Equipment:
	var gear := Equipment.new()
	for socket: Equipment.Socket in Equipment.sockets():
		for type in LootTable.items():
			if LootTable.slot_of(type) != Equipment.TAKES[socket]:
				continue
			var item := Item.new()
			item.type = type
			item.level = level
			item.stats = Item.scaled_stats(type, level)
			gear.equip(socket, item)
			break
	return gear


## A settlement is a set piece: fifteen enemies in a minute, an elite every fifth and a boss last.
## All three tiers fight it -- what makes a town a longer fight is that people live there -- and a
## farm run on one keeps that elite rhythm and never the boss.
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

	# What the set piece actually costs, measured the way the ordinary fight is: the clock less what
	# goes on walking in and dying, against the health the whole lineup carries. A settlement is a
	# step up by design -- a boss is worth twelve commons on its own -- so this is reported at three
	# distances rather than pinned, and only the one claim that has to hold everywhere is checked:
	# the first ring is where a new player starts, and it must never need gear they have not had a
	# chance to find.
	for steps in [1, MapBuilder.START_TOWN_DISTANCE, 12]:
		var at := Vector2i(steps, 0)
		var siege := Encounter.for_tile(at, "grass", "village")
		var spare := siege.seconds - siege.enemies * (Encounter.WALK_IN + Encounter.DEATH)
		var level := MapBuilder.level_of(at)
		print("Village %d step(s) out (level %d): %d health, %.1f clicks/s bare, %.1f in commons, %.1f in farmed rares"
				% [steps, level, _total_health(siege),
					_click_rate(siege, spare, Encounter.BARE_DAMAGE, 0.0),
					_rate_for(at, _commons(level), spare, "village"),
					_rate_for(at, _farmed(level, ItemRarity.Rarity.RARE), spare, "village")])
	var first := Encounter.for_tile(Vector2i(1, 0), "grass", "village")
	var room := first.seconds - first.enemies * (Encounter.WALK_IN + Encounter.DEATH)
	_check(_click_rate(first, room, Encounter.BARE_DAMAGE, 0.0) < 8.0,
			"a village in the first ring is beatable with nothing on (%.1f/s)"
			% _click_rate(first, room, Encounter.BARE_DAMAGE, 0.0))
	return true


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


## Orbs off the bodies: a third draw, on its own generator and its own curve, beside the gear rather
## than instead of it.
func _test_orb_drops() -> bool:
	# Guaranteed, so the tally is the kill count and not a sample of a 5% chance.
	var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
	fight.always_orb = true
	var dropped: Array = []
	fight.orb_dropped.connect(func(_index: int, orb: String) -> void: dropped.append(orb))
	fight.start()
	_play(fight, 4000)
	_check(fight.finished and fight.victory, "the fight was won")
	_check(dropped.size() == Encounter.ENEMIES,
			"all %d bodies carried an orb, not %d" % [Encounter.ENEMIES, dropped.size()])
	var tallied := 0
	for orb: String in fight.orbs:
		_check(OrbTable.ORBS.has(orb), "%s is an orb this build has" % orb)
		tallied += int(fight.orbs[orb])
	_check(tallied == dropped.size(), "the fight's pouch counts what it emitted")

	# Beside the gear, not against it: one body can hand over both, which is what makes the two rates
	# independent numbers rather than one number split in two.
	var both := Encounter.for_tile(Vector2i(4, 0), "grass")
	both.always_drop = true
	both.always_orb = true
	# Gathered into Arrays rather than counted into ints: a lambda captures by value, so a counter
	# incremented inside one never moves outside it.
	var gear: Array = []
	var currency: Array = []
	both.loot_dropped.connect(func(_index: int, item: Item) -> void: gear.append(item))
	both.orb_dropped.connect(func(_index: int, orb: String) -> void: currency.append(orb))
	both.start()
	_play(both, 4000)
	_check(gear.size() == Encounter.ENEMIES and currency.size() == Encounter.ENEMIES,
			"every body left gear (%d) and an orb (%d)" % [gear.size(), currency.size()])

	# Left alone, the rate is the table's: a fight of nine commons and an elite turns up rather less
	# than a fight of ten guaranteed ones, and never nothing over many attempts.
	var quiet := Encounter.for_tile(Vector2i(4, 0), "grass")
	quiet.orb_rng.seed = 31337
	var seen: Array = []
	quiet.orb_dropped.connect(func(_index: int, orb: String) -> void: seen.append(orb))
	quiet.start()
	_play(quiet, 4000)
	_check(seen.size() < Encounter.ENEMIES, "an ordinary fight does not empty the table")
	return true
