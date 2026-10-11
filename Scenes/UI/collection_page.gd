class_name CollectionPage
extends Control
## The collection log on the left edge: every unique the game has, one square each, the starters
## (`Achievements.STARTERS`) then the ones achievements unlock, each by name (the user's, 2026-10-02).
##
## Every square carries its card as a `hint` (`write_hint`), a found one too, so `ItemCard` skips its
## Alt comparison on all of them -- which is right, because a square is a `specimen`, never the piece in
## the bag. It saves nothing: a find new to the log (`Inventory.uniques_new`) glints until hovered or the
## page is closed, and then `seen` asks the main scene to save.

signal closed
## A new find was hovered, or the page closed over one, and it left `Inventory.uniques_new`.
signal seen

const HELP_ICON := "res://Assets/UI/ui_icon_info.png"
## The foot's two labels, for the tests.
const BONUS_NAME := "Bonus"
const COUNT_NAME := "Count"

var inventory: Inventory
var area := Rect2()
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
var _foot: HBoxContainer


func _init(player_inventory: Inventory, ui_scale: float) -> void:
	inventory = player_inventory
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Collection", "Close the collection", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(BountyList.ROW_GAP, BagPage.WIDTH)
	scroll.add_child(_rows)
	# Under the scroll and not in it: what the log is worth and how full it is are true of the whole page.
	UITheme.body_of(_panel).add_child(UITheme.rule(BagPage.WIDTH))
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 4)
	UITheme.body_of(_panel).add_child(_foot)
	visibility_changed.connect(_on_visibility_changed)
	open()


func open() -> void:
	UITheme.clear(_rows)
	UITheme.clear(_foot)
	var help := TextureRect.new()
	help.texture = load(HELP_ICON)
	help.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	Cursors.wear(help, Cursors.HELP)
	# The mark is only there to be read, so its card is up at once.
	help.set_meta(TipCard.NOW, true)
	help.tooltip_text = ("Each unique found adds %d%% increased Damage, worn or not"
			% UniqueTable.COLLECTION_DAMAGE)
	var bonus := UITheme.label("+%d%% Damage" % inventory.collection_bonus(), Palette.TEXT_SOFT, true)
	bonus.name = BONUS_NAME
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(bonus)
	var count := UITheme.label("Found %d of %d" % [inventory.uniques_found.size(),
			UniqueTable.UNIQUES.size()], Palette.TEXT_SOFT, true)
	count.name = COUNT_NAME
	_foot.add_child(count)
	# Last in the row, so its card stands past the panel and not over the two figures it explains.
	_foot.add_child(help)
	var known := Achievements.state(inventory)
	for starters: bool in [true, false]:
		_rows.add_child(UITheme.section("Starters" if starters else "Trophies"))
		var squares := grid()
		_rows.add_child(squares)
		var ids := UniqueTable.ids().filter(func(id: String) -> bool: return (id in Achievements.STARTERS) == starters)
		for id: String in by_name(ids, UniqueTable.UNIQUES):
			_add_square(squares, id, known)


## A grid of squares at the bag's columns and gaps.
static func grid() -> GridContainer:
	var made := GridContainer.new()
	made.columns = BagPage.GRID_COLS
	made.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	made.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	return made


## `ids` put in the order of their names in `table` (id -> a row with a "name"), and returned.
static func by_name(ids: Array, table: Dictionary) -> Array:
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(table[a]["name"]).naturalnocasecmp_to(str(table[b]["name"])) < 0)
	return ids


## One unique's square in `into`, glinting while it is a find new to the log, with the achievement
## that unlocks it under Alt (none for a starter).
func _add_square(into: GridContainer, id: String, known: Dictionary) -> void:
	# Dev (`Settings.show_all_uniques`): every square as found. The count and the bonus stay the save's.
	var found := Settings.show_all_uniques() or inventory.uniques_found.has(id)
	var slot := CollectionPage.square(id, found, Achievements.is_unlocked(inventory, id))
	if Achievements.ACHIEVEMENTS.has(id):
		slot.set_meta(ItemCard.ALT_CARD, AchievementsPage.write_card.bind(inventory, id, known))
		slot.set_meta(ItemCard.KEYS, {"alt": "achievement"})
	into.add_child(slot)
	if found and id in inventory.uniques_new:
		slot.shine_until_hovered(_on_seen.bind(id))


func _on_seen(id: String) -> void:
	if inventory.uniques_new.has(id):
		inventory.uniques_new.erase(id)
		seen.emit()


## Closing the page is seeing what was new on it, hovered or not.
func _on_visibility_changed() -> void:
	if not visible and not inventory.uniques_new.is_empty():
		inventory.uniques_new.clear()
		seen.emit()


## One unique's square. A specimen rather than the player's own: the log says what the thing *is*, at
## level 1 and the bottom of every band, and the one in the bag says what theirs rolled.
static func square(id: String, found: bool, unlocked := false) -> ItemSlot:
	var piece := CollectionPage.specimen(id)
	if found:
		# Still: only a find new to the log glints.
		var slot := ItemSlot.make(piece)
		slot.still()
		slot.hint = CollectionPage.write_hint.bind(piece, unlocked)
		return slot
	return ItemSlot.shadow(piece, CollectionPage.write_hint.bind(piece if unlocked else null, unlocked,
			false), unlocked)


## The log's own copy of a unique: level 1, every modifier at the bottom of its band.
static func specimen(id: String) -> Item:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var piece := Item.rolled_unique(id, rng)
	for mod in piece.mods:
		mod["value"] = int(ModifierTable.band_for(str(mod["id"]), 1)[0])
	return piece


## What the card says beside a unique in the log:
## - no `specimen` (one still locked): only "Locked" -- what unlocks it is the achievements page's to
##   say (the user's call, 2026-09-28);
## - not `unlocked` (a find the player must earn again, or an achievement's square under Alt): its name
##   and its `UniqueTable.hint`, never its stats, modifiers or rule (the user's, 2026-10-07);
## - unlocked: the piece itself (the log's own), and "Not found yet" if it is not `found` -- a grey
##   square beside a full card was read as a piece in hand.
static func write_hint(rows: VBoxContainer, width: float, specimen: Item = null, unlocked := true,
		found := true) -> void:
	if specimen == null:
		rows.add_child(ItemDetails.line("Locked", Palette.TEXT_SOFT, width))
		return
	if not unlocked:
		rows.add_child(ItemDetails.line(specimen.display_name(), specimen.text_color(), width))
		rows.add_child(ItemDetails.line(UniqueTable.hint(specimen.unique), Palette.TEXT, width, true))
		rows.add_child(UITheme.rule())
		rows.add_child(ItemDetails.line("Locked", Palette.TEXT_SOFT, width, true))
		return
	# `fill` empties the rows it is given, so the piece goes in first.
	ItemDetails.fill(rows, specimen, width, [], Settings.item_details)
	if not found:
		rows.add_child(UITheme.rule())
		rows.add_child(ItemDetails.line("Not found yet", Palette.TEXT_SOFT, width, true))


func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)
