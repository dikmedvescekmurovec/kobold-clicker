class_name Settings
extends RefCounted
## What the player has chosen about the game rather than done in it: sound, how much a fight throws
## about, and how much an item says. Static, because everything that reads it (`Juice`, `CombatScene`,
## `ItemDetails`) is asked from somewhere different and none of them owns it.
##
## Its own file rather than a corner of the inventory's, so Reset -- which deletes the saves -- leaves
## it alone. Not a save either: a file that cannot be read means the defaults, and nothing is refused.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## How much a fight throws about. LOW is one coin and one gem a body, numbers that do not pop, and no
## shake or freeze; NONE throws and writes nothing at all, and what was earned still reaches its counter.
enum Anim { NONE, LOW, DEFAULT }

static var music := true
static var sfx := true
static var animations := Anim.DEFAULT
## Whether a modifier's line carries the band it rolled in: "+14(8-20)% increased Damage".
static var item_details := false
## What Sell all and the bin do with a unique among the handful: ask (the second question, whose tick
## writes the answer given here), sell it with the rest, or leave it in the bag.
enum Uniques { ASK, SELL, KEEP }
static var uniques := Uniques.ASK
## Dev: the collection log draws every unique as found, and its trophy is there from the start. Read
## through `show_all_uniques()`, which a release build answers no to whatever the file says.
static var all_uniques := false
## Dev: every chest on the map is drawn, fog or not. Read through `show_all_chests()`, like the uniques.
static var all_chests := false
## Dev: a unique or a base whose icon was replaced wears the one it had before (`UniqueTable.OLD_ROOT`,
## `LootTable.OLD_ROOT`), to compare the two in the bag. Read through `show_old_icons()`, like the uniques.
static var old_icons := false
## Dev: every settlement offers every counter (`TownServices.show_all`). On by default, so read through
## `show_all_services()`, which also answers no off the player's own settings file: the tests and the
## screenshot scripts still see what a town of each tier really has.
static var all_services := true
## Where the file is. Empty means nowhere: nothing is read and nothing written, which is what every
## test and screenshot script gets, because the main scene only sets it on the player's own save.
static var path := ""


static func load_settings() -> void:
	var file := ConfigFile.new()
	if path.is_empty() or file.load(path) != OK:
		return
	music = bool(file.get_value(SECTION, "music", music))
	sfx = bool(file.get_value(SECTION, "sfx", sfx))
	animations = clampi(int(file.get_value(SECTION, "animations", animations)), Anim.NONE, Anim.DEFAULT) as Anim
	item_details = bool(file.get_value(SECTION, "item_details", item_details))
	uniques = clampi(int(file.get_value(SECTION, "uniques", uniques)), Uniques.ASK, Uniques.KEEP) as Uniques
	all_uniques = bool(file.get_value(SECTION, "all_uniques", all_uniques))
	all_chests = bool(file.get_value(SECTION, "all_chests", all_chests))
	old_icons = bool(file.get_value(SECTION, "old_icons", old_icons))
	all_services = bool(file.get_value(SECTION, "all_services", all_services))


static func save() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "music", music)
	file.set_value(SECTION, "sfx", sfx)
	file.set_value(SECTION, "animations", int(animations))
	file.set_value(SECTION, "item_details", item_details)
	file.set_value(SECTION, "uniques", int(uniques))
	file.set_value(SECTION, "all_uniques", all_uniques)
	file.set_value(SECTION, "all_chests", all_chests)
	file.set_value(SECTION, "old_icons", old_icons)
	file.set_value(SECTION, "all_services", all_services)
	if file.save(path) != OK:
		push_warning("Settings: cannot write %s" % path)


static func show_all_uniques() -> bool:
	return all_uniques and OS.is_debug_build()


static func show_all_chests() -> bool:
	return all_chests and OS.is_debug_build()


static func show_old_icons() -> bool:
	return old_icons and OS.is_debug_build()


static func show_all_services() -> bool:
	return all_services and OS.is_debug_build() and not path.is_empty()


## Mutes or opens the two buses, making them first if this run has not yet. Made here rather than in
## a `default_bus_layout.tres`, which the open editor would have to be told about.
static func apply_audio() -> void:
	for bus: Array in [[MUSIC_BUS, music], [SFX_BUS, sfx]]:
		var index := AudioServer.get_bus_index(bus[0])
		if index == -1:
			index = AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(index, bus[0])
		AudioServer.set_bus_mute(index, not bus[1])
