extends "res://tests/harness.gd"
## Prints what a town costs against what the ground pays, so the dials in `Scenes/Town/` can be read
## rather than guessed at. Nothing is asserted and nothing is saved -- it touches no inventory and no
## map, so there is no save path to redirect.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/balance_town.gd
##
## Deliberately not named `test_*`: `tests/run_all.py` picks those up, and a table is not a verdict.
##
## Everything is read off the live tables -- `Encounter.gold_of`, `LootTable.chance_for`,
## `OrbTable.chance_for` and `TownPrices` itself -- so retuning a dial retunes this page with it. The
## lineup is the one an ordinary tile fields: nine of the rabble and an elite, drawn against
## `EnemyRoster`'s own weights on one environment, and a farm run keeps that rhythm forever.

## The level bands the table is printed for. Level 1 is the middle of the map, 10 is deep enough that
## the purse has run away from anything a new player has seen.
const LEVELS := [1, 3, 5, 8, 10]
## The terrain the lineup is drawn from. Grass is the land the start sits on and fields both tiers.
const ENV := "grass"
## What the table measures a price in besides gold: one ordinary tile fight of `Encounter.ENEMIES`.
const FIGHT_KILLS := Encounter.ENEMIES
## And a session out: ten tile fights.
const RUN_KILLS := 100

const LABEL_W := 32
const CELL_W := 13


func _run() -> void:
	print("Town balance, %s, levels %s" % [ENV, LEVELS])
	print("A 'fight' is one ordinary tile: %d bodies, the last an elite. A 'run' is %d kills."
			% [FIGHT_KILLS, RUN_KILLS])
	_income()
	_prices()
	_orbs()
	_verdicts()
	quit()


## The tile at the first step of a level band, which is what `TownPrices.gold_at_level` quotes
## against: level n begins at the nth triangular number of steps out.
static func _cell(level: int) -> Vector2i:
	@warning_ignore("integer_division")
	return MapBuilder.CENTER + Vector2i(level * (level - 1) / 2, 0)


## The average of `of` over the enemies of `tier` that live on `ENV`, weighted the way a fight draws
## them -- a slime for every two goblins, so the average body is the body a player actually meets.
static func _avg(tier: int, of: Callable) -> float:
	var total := 0.0
	var weight := 0.0
	for enemy: String in EnemyRoster.in_environment(ENV, tier):
		var share := float(EnemyRoster.weight_of(enemy))
		total += share * float(of.call(enemy))
		weight += share
	return 0.0 if weight <= 0.0 else total / weight


## What one body of `tier` is carrying on that tile.
static func _purse(level: int, tier: int) -> float:
	var cell := _cell(level)
	return _avg(tier, func(enemy: String) -> float: return float(Encounter.gold_of(enemy, cell)))


## How often a body of `tier` leaves a piece of gear, and an orb.
static func _gear_chance(tier: int) -> float:
	return _avg(tier, func(enemy: String) -> float: return LootTable.chance_for(enemy))


static func _orb_chance(tier: int) -> float:
	return _avg(tier, func(enemy: String) -> float: return OrbTable.chance_for(enemy))


## What a merchant pays for one piece off a body of `tier` on a tile of this level: every rarity that
## tier can roll, weighted, at every level the drop could come out at -- a tile's level is a ceiling
## and not a payout, so a find is usually worth a good deal less than one at the frontier.
## With `plain_only`, the rare and elite finds are kept rather than sold, which is what a player
## actually does with them -- the difference between the two rows is how much of "selling everything"
## is selling the things nobody sells.
static func _gear_value(level: int, tier: int, plain_only := false) -> float:
	var weights: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
	var ceiling: int = maxi(1, level + int(LootTable.TIER_LEVEL[tier]))
	var total := 0.0
	var share := 0.0
	var piece := Item.new()
	for rarity: ItemRarity.Rarity in weights:
		var weight := float(weights[rarity])
		if weight <= 0.0:
			continue
		share += weight
		if plain_only and rarity > ItemRarity.Rarity.UNCOMMON:
			continue
		var floor_level: int = clampi(ceili(ceiling * float(ItemRarity.LEVEL_FLOOR[rarity])), 1, ceiling)
		var sum := 0.0
		for at in range(floor_level, ceiling + 1):
			piece.rarity = rarity
			piece.level = at
			sum += float(TownPrices.sell_price(piece))
		total += weight * sum / float(ceiling - floor_level + 1)
	return 0.0 if share <= 0.0 else total / share


## What a vendor pays for one orb that fell, averaged over how often each one falls.
static func _orb_value(level: int) -> float:
	var cell := _cell(level)
	var total := 0.0
	var share := 0.0
	for orb: String in OrbTable.ORBS:
		var weight := float(OrbTable.ORBS[orb]["weight"])
		share += weight
		total += weight * float(TownPrices.orb_sell_price(orb, cell))
	return 0.0 if share <= 0.0 else total / share


## What the ground pays, per fight and per run, and what the run's finds fetch on top of it.
func _income() -> void:
	print("\n-- What the ground pays --")
	_row("tile level", _each(func(level: int) -> String: return str(level)))
	_row("one body (gold_at_level)", _each(func(level: int) -> String:
			return _gold(TownPrices.gold_at_level(level))))
	_row("tile fight, purse", _each(func(level: int) -> String: return _gold(_fight_gold(level))))
	_row("run of %d, purse" % RUN_KILLS, _each(func(level: int) -> String:
			return _gold(_run_gold(level))))
	_row("gear found per run", _each(func(_level: int) -> String:
			return "%.2f" % _run_gear()))
	_row("  what it sells for", _each(func(level: int) -> String: return _gold(_run_gear_gold(level))))
	_row("orbs found per run", _each(func(_level: int) -> String: return "%.2f" % _run_orbs()))
	_row("  what they sell for", _each(func(level: int) -> String: return _gold(_run_orb_gold(level))))
	_row("selling, share of the purse", _each(func(level: int) -> String:
			return "%.1f%%" % (100.0 * (_run_gear_gold(level) + _run_orb_gold(level)) / _run_gold(level))))
	_row("  keeping rare and better", _each(func(level: int) -> String:
			return "%.1f%%" % (100.0 * (_run_gear_gold(level, true) + _run_orb_gold(level))
					/ _run_gold(level))))


## What a town asks, against that.
func _prices() -> void:
	print("\n-- What a town asks --")
	var piece := Item.new()
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON,
			ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
		_row("shelf %s, buy" % ItemRarity.name_of(rarity), _each(func(level: int) -> String:
			piece.rarity = rarity
			piece.level = level
			return _gold(TownPrices.buy_price(piece))))
	_row("  (elite, sold back)", _each(func(level: int) -> String:
		piece.rarity = ItemRarity.Rarity.ELITE
		piece.level = level
		return _gold(TownPrices.sell_price(piece))))
	_row("smith, one level", _each(func(level: int) -> String:
		piece.rarity = ItemRarity.Rarity.ELITE
		piece.level = level
		return _gold(TownPrices.upgrade_price(piece))))
	_row("smith, one lock", _each(func(level: int) -> String:
		piece.rarity = ItemRarity.Rarity.ELITE
		piece.level = level
		return _gold(TownPrices.lock_price(piece))))
	for reading: String in FortuneTeller.READINGS:
		_row("fortune, %s" % reading, _each(func(level: int) -> String:
				return _gold(TownPrices.fortune_price(reading, _cell(level)))))
	_row("bounty, %d common" % BountyBoard.NEED_COMMON, _each(func(level: int) -> String:
			return _gold(_bounty(level, EnemyRoster.Tier.COMMON))))
	_row("bounty, %d elite" % BountyBoard.NEED_ELITE, _each(func(level: int) -> String:
			return _gold(_bounty(level, EnemyRoster.Tier.ELITE))))


## Every orb, in bodies and in gold, since an orb is priced at the town rather than at itself.
func _orbs() -> void:
	print("\n-- Every orb, at the town's own level --")
	var line := "orb".rpad(LABEL_W) + "weight".lpad(8) + "bodies".lpad(9)
	for level: int in LEVELS:
		line += ("buy L%d" % level).lpad(CELL_W)
	print(line)
	for orb: String in OrbTable.ORBS:
		var row := orb.rpad(LABEL_W) + str(int(OrbTable.ORBS[orb]["weight"])).lpad(8)
		row += ("%.1f" % (TownPrices.ORB_BODIES * TownPrices.commonest()
				/ float(OrbTable.ORBS[orb]["weight"]))).lpad(9)
		for level: int in LEVELS:
			row += ("%s/%s" % [_gold(TownPrices.orb_value(orb, _cell(level))),
					_gold(TownPrices.orb_sell_price(orb, _cell(level)))]).lpad(CELL_W)
		print(row)
	print("buy/sell. A body at those levels: %s" % [_each(func(level: int) -> String:
			return _gold(TownPrices.gold_at_level(level)))])


## The same numbers said as fights, which is the only unit a player has.
func _verdicts() -> void:
	print("\n-- In fights (one ordinary tile) --")
	var piece := Item.new()
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.ELITE]:
		_row("fights for a shelf %s" % ItemRarity.name_of(rarity), _each(func(level: int) -> String:
			piece.rarity = rarity
			piece.level = level
			return "%.1f" % (TownPrices.buy_price(piece) / _fight_gold(level))))
	_row("kills for a shelf common", _each(func(level: int) -> String:
		piece.rarity = ItemRarity.Rarity.COMMON
		piece.level = level
		return "%.0f" % (FIGHT_KILLS * TownPrices.buy_price(piece) / _fight_gold(level))))
	_row("fights for an upgrade", _each(func(level: int) -> String:
		piece.level = level
		return "%.1f" % (TownPrices.upgrade_price(piece) / _fight_gold(level))))
	_row("fights for a lock", _each(func(level: int) -> String:
		piece.level = level
		return "%.0f" % (TownPrices.lock_price(piece) / _fight_gold(level))))
	for reading: String in FortuneTeller.READINGS:
		_row("fights for her %s" % reading, _each(func(level: int) -> String:
				return "%.1f" % (TownPrices.fortune_price(reading, _cell(level)) / _fight_gold(level))))
	_row("common bounty, in fights", _each(func(level: int) -> String:
			return "%.1f" % (_bounty(level, EnemyRoster.Tier.COMMON) / _fight_gold(level))))
	_row("  the same kills paid", _each(func(level: int) -> String:
			return "%.1f" % (BountyBoard.NEED_COMMON * _purse(level, EnemyRoster.Tier.COMMON)
					/ _fight_gold(level))))
	_row("elite bounty, in fights", _each(func(level: int) -> String:
			return "%.1f" % (_bounty(level, EnemyRoster.Tier.ELITE) / _fight_gold(level))))
	_row("  the same kills paid", _each(func(level: int) -> String:
			return "%.1f" % (BountyBoard.NEED_ELITE * _purse(level, EnemyRoster.Tier.ELITE)
					/ _fight_gold(level))))
	_row("run's selling, in fights", _each(func(level: int) -> String:
			return "%.2f" % ((_run_gear_gold(level) + _run_orb_gold(level)) / _fight_gold(level))))


## One ordinary tile's purse: the rabble and the elite that ends it.
func _fight_gold(level: int) -> float:
	return (FIGHT_KILLS - 1) * _purse(level, EnemyRoster.Tier.COMMON) \
			+ _purse(level, EnemyRoster.Tier.ELITE)


## A run keeps the tile's elite rhythm, one in `Encounter.ELITE_EVERY`, forever.
func _run_gold(level: int) -> float:
	var elites := float(RUN_KILLS) / float(Encounter.ELITE_EVERY)
	return (RUN_KILLS - elites) * _purse(level, EnemyRoster.Tier.COMMON) \
			+ elites * _purse(level, EnemyRoster.Tier.ELITE)


func _run_gear() -> float:
	var elites := float(RUN_KILLS) / float(Encounter.ELITE_EVERY)
	return (RUN_KILLS - elites) * _gear_chance(EnemyRoster.Tier.COMMON) \
			+ elites * _gear_chance(EnemyRoster.Tier.ELITE)


func _run_gear_gold(level: int, plain_only := false) -> float:
	var elites := float(RUN_KILLS) / float(Encounter.ELITE_EVERY)
	var rabble := (RUN_KILLS - elites) * _gear_chance(EnemyRoster.Tier.COMMON)
	var fewer := elites * _gear_chance(EnemyRoster.Tier.ELITE)
	return rabble * _gear_value(level, EnemyRoster.Tier.COMMON, plain_only) \
			+ fewer * _gear_value(level, EnemyRoster.Tier.ELITE, plain_only)


func _run_orbs() -> float:
	var elites := float(RUN_KILLS) / float(Encounter.ELITE_EVERY)
	return (RUN_KILLS - elites) * _orb_chance(EnemyRoster.Tier.COMMON) \
			+ elites * _orb_chance(EnemyRoster.Tier.ELITE)


func _run_orb_gold(level: int) -> float:
	return _run_orbs() * _orb_value(level)


## What a board pays for `need` of that tier, the way `BountyBoard._posting` prices one.
func _bounty(level: int, tier: int) -> float:
	var need: int = BountyBoard.NEED_ELITE if tier == EnemyRoster.Tier.ELITE else BountyBoard.NEED_COMMON
	return maxf(1.0, roundf(_purse(level, tier) * need * BountyBoard.REWARD_MULT))


## One cell of the row per level.
func _each(of: Callable) -> Array:
	var cells := []
	for level: int in LEVELS:
		cells.append(of.call(level))
	return cells


func _row(label: String, cells: Array) -> void:
	var line := label.rpad(LABEL_W)
	for cell: Variant in cells:
		line += str(cell).lpad(CELL_W)
	print(line)


func _gold(amount: float) -> String:
	return BigNumber.format(amount)
