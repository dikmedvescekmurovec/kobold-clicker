class_name Settings
extends RefCounted
## What the player has chosen about the game rather than done in it: how loud, whether full screen,
## how much a fight throws about and shakes, and how much an item says. Static, because everything that reads it (`Juice`, `CombatScene`,
## `ItemDetails`) is asked from somewhere different and none of them owns it.
##
## Its own file rather than a corner of the inventory's, so Reset -- which deletes the saves -- leaves
## it alone. Not a save either: a file that cannot be read means the defaults, and nothing is refused.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## How far every sound effect sits under its file's own level: the files hold how loud each is beside
## the others (`tools/sound_levels.py`), and this is how loud they all are beside the music.
const SFX_DB := -6.0

## How much a fight throws about. LOW is one coin and one gem a body, numbers that do not pop, and no
## shake or freeze; NONE throws and writes nothing at all, and what was earned still reaches its counter.
enum Anim { NONE, LOW, DEFAULT }

## How loud the music and the sound effects are, 0 to 1 in `VOLUME_STEP`s; 0 is silent. A file from
## before there were volumes held only whether each was on, which reads as all or nothing.
static var music_volume := 1.0
static var sfx_volume := 1.0
const VOLUME_STEP := 0.1
static var animations := Anim.DEFAULT
## Whether the screen shakes on a heavy blow, apart from the animations: shaking is what some players
## cannot watch while they still want the coins and the numbers. Shaking needs Default as well.
static var shake := true
## Whether a desktop window fills the screen (`apply_window`). Nothing on a phone or the web asks it.
static var fullscreen := false
## Whether a modifier's line carries the band it rolled in: "+14(8-20)% increased Damage".
static var item_details := false
## What Sell all and the bin do with a unique among the handful: ask (the second question, whose tick
## writes the answer given here), sell it with the rest, or leave it in the bag.
enum Uniques { ASK, SELL, KEEP }
static var uniques := Uniques.ASK
## The loot filter, the sixth wall's unlock (`WallUnlocks.FILTER`): what a find must be to be kept, the
## rest left behind as it drops (`Inventory.leaves_behind`). The least rarity (`ItemRarity.Rarity`'s
## order: 0 keeps every one), the least material (0 keeps every one; a kind with one material, the
## jewellery, has none to fall short), the least item level (1 keeps every one) and whether only an
## ascended piece (+1 or more) is kept.
static var filter_rarity := 0
static var filter_material := 0
static var filter_level := 1
static var filter_ascended := false
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
## Dev: a body drops one find a time in three, every rarity from common to unique as likely
## (`Encounter.even_loot`). Read through `even_loot_on()`, like the uniques.
static var even_loot := false
## Dev: the health an ordinary body has on the first ring of each circle of land, by how many walls
## stand inside it (`Encounter.walls_inside`): inside the first wall, between the first and second,
## between the second and third. 0 is the formula's own; every body in the circle scales with it
## (`Encounter.hp_tuning`), and land further out never does. Read through `hp_base()`.
static var wall_hp: Array = [0.0, 0.0, 0.0]
## The newest `CHANGELOG.md` version already shown (`main_scene._show_changelog`). Here rather than in
## the save so a Reset does not show it again, and a browser's settings file is that player's.
static var changelog_seen := ""
## Where the file is. Empty means nowhere: nothing is read and nothing written, which is what every
## test and screenshot script gets, because the main scene only sets it on the player's own save.
static var path := ""


static func load_settings() -> void:
	var file := ConfigFile.new()
	if path.is_empty() or file.load(path) != OK:
		return
	music_volume = _volume(file, "music_volume", "music", music_volume)
	sfx_volume = _volume(file, "sfx_volume", "sfx", sfx_volume)
	shake = bool(file.get_value(SECTION, "shake", shake))
	fullscreen = bool(file.get_value(SECTION, "fullscreen", fullscreen))
	animations = clampi(int(file.get_value(SECTION, "animations", animations)), Anim.NONE, Anim.DEFAULT) as Anim
	item_details = bool(file.get_value(SECTION, "item_details", item_details))
	uniques = clampi(int(file.get_value(SECTION, "uniques", uniques)), Uniques.ASK, Uniques.KEEP) as Uniques
	filter_rarity = maxi(0, int(file.get_value(SECTION, "filter_rarity", filter_rarity)))
	filter_material = maxi(0, int(file.get_value(SECTION, "filter_material", filter_material)))
	filter_level = maxi(1, int(file.get_value(SECTION, "filter_level", filter_level)))
	filter_ascended = bool(file.get_value(SECTION, "filter_ascended", filter_ascended))
	all_uniques = bool(file.get_value(SECTION, "all_uniques", all_uniques))
	all_chests = bool(file.get_value(SECTION, "all_chests", all_chests))
	old_icons = bool(file.get_value(SECTION, "old_icons", old_icons))
	all_services = bool(file.get_value(SECTION, "all_services", all_services))
	even_loot = bool(file.get_value(SECTION, "even_loot", even_loot))
	changelog_seen = str(file.get_value(SECTION, "changelog_seen", changelog_seen))
	var bases: Variant = file.get_value(SECTION, "wall_hp_base", wall_hp)
	if bases is Array and bases.size() == wall_hp.size():
		wall_hp = bases.map(func(base: Variant) -> float: return maxf(0.0, float(base)))


static func save() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "music_volume", music_volume)
	file.set_value(SECTION, "sfx_volume", sfx_volume)
	file.set_value(SECTION, "shake", shake)
	file.set_value(SECTION, "fullscreen", fullscreen)
	file.set_value(SECTION, "animations", int(animations))
	file.set_value(SECTION, "item_details", item_details)
	file.set_value(SECTION, "uniques", int(uniques))
	file.set_value(SECTION, "filter_rarity", filter_rarity)
	file.set_value(SECTION, "filter_material", filter_material)
	file.set_value(SECTION, "filter_level", filter_level)
	file.set_value(SECTION, "filter_ascended", filter_ascended)
	file.set_value(SECTION, "all_uniques", all_uniques)
	file.set_value(SECTION, "all_chests", all_chests)
	file.set_value(SECTION, "old_icons", old_icons)
	file.set_value(SECTION, "all_services", all_services)
	file.set_value(SECTION, "even_loot", even_loot)
	file.set_value(SECTION, "changelog_seen", changelog_seen)
	file.set_value(SECTION, "wall_hp_base", wall_hp)
	if file.save(path) != OK:
		push_warning("Settings: cannot write %s" % path)


## A volume off the file, or off the on/off it held before there were volumes: on is all, off nothing.
static func _volume(file: ConfigFile, key: String, old_key: String, fallback: float) -> float:
	if file.has_section_key(SECTION, key):
		return clampf(float(file.get_value(SECTION, key)), 0.0, 1.0)
	if file.has_section_key(SECTION, old_key):
		return 1.0 if bool(file.get_value(SECTION, old_key)) else 0.0
	return fallback


static func show_all_uniques() -> bool:
	return all_uniques and OS.is_debug_build()


static func show_all_chests() -> bool:
	return all_chests and OS.is_debug_build()


static func show_old_icons() -> bool:
	return old_icons and OS.is_debug_build()


static func even_loot_on() -> bool:
	return even_loot and OS.is_debug_build()


## The balancing page's base health for the circle with `walls` walls inside it, or 0 for the
## formula's own: past the third wall, never set, and always in a release build.
static func hp_base(walls: int) -> float:
	if not OS.is_debug_build() or walls < 0 or walls >= wall_hp.size():
		return 0.0
	return float(wall_hp[walls])


static func show_all_services() -> bool:
	return all_services and OS.is_debug_build() and not path.is_empty()


## Sets the two buses to their volumes -- the effects `SFX_DB` under the files' own levels -- muting one
## at nothing, and makes them first if this run has not yet. Made here rather than in a
## `default_bus_layout.tres`, which the open editor would have to be told about.
static func apply_audio() -> void:
	for bus: Array in [[MUSIC_BUS, music_volume, 0.0], [SFX_BUS, sfx_volume, SFX_DB]]:
		var index := AudioServer.get_bus_index(bus[0])
		if index == -1:
			index = AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(index, bus[0])
		var volume: float = bus[1]
		AudioServer.set_bus_mute(index, volume <= 0.0)
		if volume > 0.0:
			AudioServer.set_bus_volume_db(index, linear_to_db(volume) + float(bus[2]))


## Whether a window can be made to fill the screen here: a desktop with a real window.
static func has_window() -> bool:
	return OS.has_feature("pc") and DisplayServer.get_name() != "headless"


## Fills the screen or gives the window back, as `fullscreen` says, where there is a window to fill.
static func apply_window() -> void:
	if not has_window():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
