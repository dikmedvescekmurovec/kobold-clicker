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


static func save() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "music", music)
	file.set_value(SECTION, "sfx", sfx)
	file.set_value(SECTION, "animations", int(animations))
	file.set_value(SECTION, "item_details", item_details)
	if file.save(path) != OK:
		push_warning("Settings: cannot write %s" % path)


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
