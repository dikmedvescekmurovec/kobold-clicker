class_name Inventory
extends RefCounted
## Everything the player has picked up, and the file it is kept in.
##
## A plain data object with no nodes: it holds items and reads and writes its own JSON, and that is
## all. It never saves itself -- the main scene owns it and decides when to write, which keeps the
## rules tests off the disk and the save policy a one-line change.
##
## Items do not stack. Each one rolled its own rarity and its own modifiers, so two Wooden Swords are
## two different swords and this is a list, not a tally.
##
## The save is the first file this game keeps. It has to survive being missing, half-written, edited
## by hand or written by a build that no longer exists, because a bad save must never be the reason
## the game won't start.

const SAVE_PATH := "user://inventory.json"
## 1 was the tally of names this kept before items had rarities. 2 is the list of items.
const VERSION := 2

## What is held, oldest first: the panel shows them the other way round.
var items: Array[Item] = []

## Whether the one promised elite drop has been handed over. It lives in the save, so it is once for
## the player rather than once per launch.
var first_elite_taken := false


func add(item: Item) -> void:
	items.append(item)


## How many of that piece are held, whatever their rarities.
func count(type: String) -> int:
	var held := 0
	for item in items:
		if item.type == type:
			held += 1
	return held


func total() -> int:
	return items.size()


## Nothing drops or sells an item yet. It is here so the first feature that does is a call rather
## than a save migration -- without it the file only ever grows.
func remove(item: Item) -> bool:
	var at := items.find(item)
	if at < 0:
		return false
	items.remove_at(at)
	return true


## Writes the inventory to `path`. Returns whether it got there; a failed write is worth a warning
## but never worth stopping play for.
func save(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Inventory: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	var saved := []
	for item in items:
		saved.append(item.to_dict())
	# Indented, so the save can be read and edited by a person.
	file.store_string(JSON.stringify({
		"version": VERSION,
		"first_elite_taken": first_elite_taken,
		"items": saved,
	}, "\t"))
	return true


## The inventory in `path`, or an empty one when there isn't a usable file there. Missing,
## unreadable, unparseable and the wrong shape all come back empty: a first run and a corrupt save
## look the same from here, and neither is an error the player should meet.
static func load_from(path := SAVE_PATH) -> Inventory:
	var inventory := Inventory.new()
	if not FileAccess.file_exists(path):
		return inventory
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Inventory: cannot read " + path)
		return inventory
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Inventory: %s is not a save file; starting empty" % path)
		return inventory
	inventory.first_elite_taken = bool(data.get("first_elite_taken", false))
	var version := int(data.get("version", 1))
	if version > VERSION:
		# A save from a newer build. Guessing at a shape never seen is how a save gets eaten; leaving
		# it alone means the build that wrote it can still read it.
		push_warning("Inventory: %s was written by a newer version (%d); starting empty" % [path, version])
		return inventory
	if version < VERSION:
		inventory._read_v1(data)
		return inventory
	var saved: Variant = data.get("items", [])
	if typeof(saved) != TYPE_ARRAY:
		push_warning("Inventory: %s has no items; starting empty" % path)
		return inventory
	for entry: Variant in saved:
		var item := Item.from_dict(entry)
		if item != null:
			inventory.items.append(item)
	return inventory


## The old shape: item name -> how many were held. Each becomes that many plain common items with no
## modifiers, which is the honest reading of a save that never knew an item could be anything more.
## Handing them rarities would be handing the player power for having played earlier. The next save
## writes the new shape, so this runs at most once per file.
func _read_v1(data: Dictionary) -> void:
	var counts: Variant = data.get("counts", {})
	if typeof(counts) != TYPE_DICTIONARY:
		return
	for type: String in counts:
		if not LootTable.ITEMS.has(type):
			continue
		for i in int(counts[type]):
			var item := Item.new()
			item.type = type
			items.append(item)
