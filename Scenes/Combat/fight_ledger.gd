class_name FightLedger
extends RefCounted
## What one fight has earned, and the one rule for when it reaches the inventory.
##
## A charting fight banks every gain as it lands and writes it to disk: it is over in half a minute,
## and closing the game mid-fight must not cost a find. A farm run has no end of its own and could go
## an hour, so everything it earns waits here -- the pouch -- and goes in as one write when `bank` is
## called, by the run ending or by the game closing. Finds, gold, orbs and experience all follow that
## one rule; they differ only in that the bag's cap can destroy a find and can refuse nothing else.

## A body the accepted bounty took, and what that bounty stands at with it: `have >= need` is filled.
## The one thing the screen hears of a bounty mid-fight. A tile fight says it as the board is written;
## a run says what its pouched bodies will count as at `bank`, which is never wrong, since both ways
## out of a run bank.
signal bounty_counted(enemy: String, have: int, need: int)

## What the fight has turned up, banked or not. Kept after banking, for the report.
var drops: Array[Item] = []
## These four are zeroed by `bank`, so a second call has nothing to repeat. Gold is a whole
## number in a double, the way `Encounter.gold` is: a purse grows exponentially with the walk.
var gold := 0.0
## Orb name -> how many.
var orbs := {}
var xp := 0
## What the fight has killed and not handed to the bounty boards yet: enemy name -> how many. A tile
## fight's is always empty, because it counts each body as it falls.
var slain := {}
## Whether this is a farm run, which pouches, rather than a fight for a tile, which banks as it goes.
var farming: bool
## The level of the tile being fought on, which a bounty asks about. -1 until the main scene says.
var tile_level := -1

var _inventory: Inventory
var _path: String
## Whether anything at all has dropped, which spends the Broken Sword and the elite's promise of it.
var _gear_dropped := false
var _first_orb_dropped := false
var _banked := false


func _init(inventory: Inventory, save_path: String, is_farming := false) -> void:
	_inventory = inventory
	_path = save_path
	farming = is_farming


func add_loot(item: Item) -> void:
	drops.append(item)
	_gear_dropped = true
	if farming:
		return
	_put_in_bag(item)
	_save()


func add_gold(amount: float) -> void:
	gold += amount
	if farming:
		return
	_inventory.gold += amount
	_save()


func add_orb(orb: String) -> void:
	orbs[orb] = int(orbs.get(orb, 0)) + 1
	_first_orb_dropped = _first_orb_dropped or orb == OrbTable.FIRST_ORB
	if farming:
		return
	_inventory.add_orb(orb)
	_save()


func add_xp(amount: int) -> void:
	xp += amount
	if farming:
		return
	_add_xp(amount)
	_save()


## One body down, for the boards that have work out on that monster. The same bank-or-pouch rule
## everything else here follows: a tile fight counts it and writes it now, a run holds it and hands
## the lot over at `bank`. The boards are reached through the inventory, which is what this already
## holds -- nothing here knows there is a page showing them.
func add_kill(enemy: String) -> void:
	if farming:
		slain[enemy] = int(slain.get(enemy, 0)) + 1
		_report(enemy, int(slain[enemy]))
		return
	if BountyBoard.count_kill(_inventory.towns, enemy, 1, tile_level):
		_save()
		_report(enemy, 0)


## Says what the accepted bounty stands at with this fight's bodies counted: the board's own count for
## a tile fight, the board's plus the pouch's for a run. A run's body past the job is nothing to say.
func _report(enemy: String, pouched: int) -> void:
	var bounty := BountyBoard.active(_inventory.towns)
	if not BountyBoard.takes(bounty, enemy, tile_level):
		return
	var need := int(bounty.get(BountyBoard.NEED, 0))
	var have := int(bounty.get(BountyBoard.HAVE, 0)) + pouched
	if have > need:
		return
	bounty_counted.emit(enemy, have, need)


## A find the player's own rule threw away on sight. It is in neither the pouch nor the bag; all that
## is left of it is that something dropped, which spends the Broken Sword.
func autodiscarded() -> void:
	if _gear_dropped:
		return
	_gear_dropped = true
	if not farming:
		_save()


## A find thrown away by hand from the fight's panel. Returns whether the bag changed: a run's find
## was only ever in the pouch, a tile fight's has already been banked and comes out of the bag.
func discard(item: Item) -> bool:
	drops.erase(item)
	if farming or not _inventory.remove(item):
		return false
	_save()
	return true


## Room left in the bag, counting what a run's pouch is going to need.
func room_left() -> int:
	return maxi(0, _inventory.room_left() - (drops.size() if farming else 0))


## Experience earned and not banked yet, which the character panel shows on top of the inventory's.
func pending_xp() -> int:
	return xp if farming else 0


## Empties a run's pouch into the inventory in one write. Returns whether anything went in. Safe to
## call twice (the run ending, then the game closing) and a no-op for a tile fight, which banked as
## it went. Gold, experience and orbs go in even when no gear was found: nothing can refuse them.
func bank() -> bool:
	if not farming or _banked:
		return false
	_banked = true
	if drops.is_empty() and gold == 0.0 and orbs.is_empty() and xp == 0 and slain.is_empty():
		return false
	_inventory.gold += gold
	gold = 0.0
	_add_xp(xp)
	xp = 0
	for orb: String in orbs:
		_inventory.add_orb(orb, int(orbs[orb]))
	orbs = {}
	# The run's bodies reach the boards here and nowhere else, so a run that is banked twice cannot
	# count one goblin twice.
	for enemy: String in slain:
		BountyBoard.count_kill(_inventory.towns, enemy, int(slain[enemy]), tile_level)
	slain = {}
	for drop: Item in drops:
		_put_in_bag(drop)
	_save()
	return true


## A fight's kills go on the lifetime count, which is what holds the first orb back.
func bank_kills(kills: int) -> void:
	_inventory.kills += kills
	_save()


func _put_in_bag(item: Item) -> void:
	# The collection log hears of a unique where the bag does, so it follows the bank-or-pouch rule
	# for free: at once for a tile fight, at `bank` for a run.
	_inventory.note_unique(item.unique)
	_inventory.add(item)


func _add_xp(amount: int) -> void:
	if _inventory.add_xp(amount) > 0:
		print("Level up: %d" % _inventory.level)


func _save() -> void:
	if _gear_dropped:
		_inventory.first_sword_taken = true
	if _first_orb_dropped:
		_inventory.first_orb_taken = true
	_inventory.save(_path)
