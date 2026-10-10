extends "res://tests/harness.gd"
## What the combat suites share: their scratch files and the helpers their tests are written with.
## (They were one file, tests/test_combat.gd, until it outgrew a single read.)

## Never the player's own two saves: the scene test fights, drops loot and explores. They are cleared
## at the *start* of a run rather than the end, because the scene writes its map from _exit_tree,
## which fires as the tree comes down after the last line of _run -- so a run always leaves one
## behind, and only the next run starting clean can be relied on. A map left over from last time
## would be loaded, and the fight would be handed a tile that had already been taken.
const SCRATCH_INVENTORY := "user://test_combat_inventory.json"
const SCRATCH_MAP := "user://test_combat_map.json"


func _clear_saves() -> void:
	for path in [SCRATCH_INVENTORY, SCRATCH_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _environments() -> PackedStringArray:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	return envs


func _thrown_piece(rarity: ItemRarity.Rarity) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = 1
	item.stats = Item.scaled_stats(item.type, 1)
	return item


func _struck_standing(tier: EnemyRoster.Tier, stats := {}) -> Encounter:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	fight.lineup[0] = _enemy_of(tier)
	fight.health[0] = 1.0e9
	fight.hp = 1.0e9
	fight.strikes = true
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	return fight


## Some enemy of `tier` that lives on grass.
func _enemy_of(tier: EnemyRoster.Tier) -> String:
	for name: String in EnemyRoster.names():
		if EnemyRoster.tier_of(name) == tier:
			return name
	return ""


## A descent played to the end of its clock with a weapon worth `damage` a swing, `speed` swings a
## second, begun under `won` depths: the fight, finished.
func _descended(damage: float, speed: float, won := 0) -> Encounter:
	var fight := Encounter.for_dungeon(won)
	fight.strikes = true
	fight.arm({"damage": damage, "attack_speed": speed})
	fight.start()
	for i in 100000:
		if fight.finished:
			break
		fight.advance(0.05)
	return fight


## Every unique a fight hands over, gathered off `loot_dropped` as [index, id] pairs.
func _uniques_of(fight: Encounter) -> Array:
	var found := []
	fight.loot_dropped.connect(func(index: int, item: Item) -> void:
		if not item.unique.is_empty():
			found.append([index, item.unique]))
	return found


## A fight on `env` with `effects` worn, its first enemy standing and given `hp` to soak blows with.
func _standing(effects: Array, stats: Dictionary, hp := 1.0e9, env := "grass") -> Encounter:
	var fight := Encounter.for_tile(Vector2i(12, 0), env)
	fight.effects = effects
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	fight.health[0] = hp
	fight.hp = hp
	return fight


## A fight on `env` told `worn` and the unique `ranks`, its first enemy standing with `hp` to soak.
func _told(worn: Array, ranks: Dictionary, stats: Dictionary, hp := 1.0e9, env := "grass",
		variant := "") -> Encounter:
	var fight := Encounter.for_tile(Vector2i(12, 0), env, variant)
	fight.wear(worn, ranks)
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	fight.health[0] = hp
	fight.hp = hp
	return fight


## Puts `fight` on its last body -- an elite, or a settlement's boss -- standing with `hp`.
func _on_last(fight: Encounter, hp := 1.0e9) -> Encounter:
	fight.index = fight.enemies - 1
	fight.health[fight.index] = hp
	fight.hp = hp
	return fight


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


## Every one of `bodies` in `heard` -- ["died" / "left" / "paid", index] as the fight said them -- died
## first, was paid last and once, and left at least `least` things between.
func _paid_in_order(heard: Array, bodies: int, least: int, what: String) -> void:
	for body in bodies:
		var said: Array = heard.filter(func(entry: Array) -> bool: return entry[1] == body) \
				.map(func(entry: Array) -> String: return entry[0])
		_check(said.count("died") == 1 and said.count("paid") == 1 and said.size() >= least + 2
				and said.front() == "died" and said.back() == "paid",
				"%s %d dies, leaves what it carried, and is paid once after it (%s)" % [what, body, said])


## One function of a script's source, from its `func` line to the next function's.
func _body_of(source: String, function: String) -> String:
	var from := source.find("\nfunc %s(" % function)
	var to := source.find("\nfunc ", from + 1)
	return "" if from < 0 else source.substr(from, (to if to > from else source.length()) - from)
