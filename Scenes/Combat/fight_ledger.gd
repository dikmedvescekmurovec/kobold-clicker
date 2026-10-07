class_name FightLedger
extends RefCounted
## What one fight has earned, and the one rule for when it is written down.
##
## Every gain goes into the inventory as it lands, whatever the fight -- the bag can be opened over
## any fight, so what it shows has to be what the fight has turned up. A charting fight also writes
## each one to disk: it is over in half a minute, and closing the game mid-fight must not cost a find.
## A farm run has no end of its own and could go an hour, so it leaves the writing to whatever saves
## next -- at the latest `bank_kills`, which both ways out of a run call.

## A body the accepted bounty took, and what that bounty stands at with it: `have >= need` is filled.
## The one thing the screen hears of a bounty mid-fight.
signal bounty_counted(enemy: String, have: int, need: int)
## A body the accepted bounty wants, short of filling it, that fell on land shallower than `level`, the
## posting's: it did not count, and the screen says why.
signal bounty_too_low(enemy: String, level: int)

## What the fight has turned up. Kept after it ends, for the report.
var drops: Array[Item] = []
## Whether this is a farm run, which writes once as it ends, rather than a fight for a tile, which
## writes as it goes.
var farming: bool
## The level of the tile being fought on, which a bounty asks about. -1 until the main scene says.
var tile_level := -1

var _inventory: Inventory
var _path: String


func _init(inventory: Inventory, save_path: String, is_farming := false) -> void:
	_inventory = inventory
	_path = save_path
	farming = is_farming


func add_loot(item: Item) -> void:
	drops.append(item)
	# Anything at all dropping spends the Broken Sword and the elite's promise of it.
	_inventory.first_sword_taken = true
	# The collection log hears of a unique where the bag does.
	_inventory.note_unique(item.unique)
	_inventory.add(item)
	_write()


func add_gold(amount: float) -> void:
	_inventory.gold += amount
	_write()


func add_orb(orb: String) -> void:
	if orb == OrbTable.FIRST_ORB:
		_inventory.first_orb_taken = true
	_inventory.add_orb(orb)
	_write()


func add_xp(amount: int) -> void:
	if _inventory.add_xp(amount) > 0:
		print("Level up: %d" % _inventory.level)
	_write()


## One body down, for the boards that have work out on that monster. The boards are reached through
## the inventory, which is what this already holds -- nothing here knows there is a page showing them.
func add_kill(enemy: String) -> void:
	if not BountyBoard.count_kill(_inventory.towns, enemy, 1, tile_level):
		# Its monster, and not filled: only the tile's level can have refused it.
		var wanted := BountyBoard.active(_inventory.towns)
		if BountyBoard.takes(wanted, enemy) and not BountyBoard.ready(wanted):
			bounty_too_low.emit(enemy, int(wanted.get(BountyBoard.LEVEL, 0)))
		return
	_write()
	var bounty := BountyBoard.active(_inventory.towns)
	bounty_counted.emit(enemy, int(bounty.get(BountyBoard.HAVE, 0)), int(bounty.get(BountyBoard.NEED, 0)))


## A find the player's own rule threw away on sight. It is not in the bag; all that is left of it is
## that something dropped, which spends the Broken Sword.
func autodiscarded() -> void:
	if _inventory.first_sword_taken:
		return
	_inventory.first_sword_taken = true
	_write()


## A find thrown away by hand from the fight's verdict. Returns whether the bag changed: a piece
## already sold, thrown away or put on from the bag is not there to come out.
func discard(item: Item) -> bool:
	drops.erase(item)
	if not _inventory.remove(item):
		return false
	_write()
	return true


## A fight's kills go on the lifetime count, which is what holds the first orb back. Both ways out of
## every fight call it, so it is also where a run is written down.
func bank_kills(kills: int) -> void:
	_inventory.kills += kills
	_inventory.save(_path)


func _write() -> void:
	if not farming:
		_inventory.save(_path)
