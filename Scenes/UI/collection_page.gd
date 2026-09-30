class_name CollectionPage
extends Control
## The collection log, as a page against the left edge: every unique the game has, one square each in
## `UniqueTable`'s order. One the player has found is drawn as the piece it is; one unlocked and not
## yet found (`Achievements.is_unlocked`) is the same piece darkened; one still locked is its outline in
## black -- either with no socket or ring, the sprite alone -- and its card says only "Locked".
##
## **A found square carries its card as well as an unlocked one** (`write_hint`): a found piece that is
## locked says so, since an old save's finds must be earned again to drop (the user's ruling), and the
## achievements page says how. The cost is that `ItemCard` skips its Alt comparison on any square that
## carries a `hint` -- which is right, because the square is a `specimen`, never the piece in the bag.
## Every unique is carried on every ground, so the card names none (the user's, 2026-09-29).
##
## Built like the other left-hand pages (`BountyList`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## It changes one thing and saves nothing: a find new to the log (`Inventory.uniques_new`) glints until
## the cursor has been over it, and then `seen` asks the main scene to save and still the button.
##
## Every square is an `ItemSlot`, so the one `ItemCard` the main scene built describes these too --
## every one of them through the `hint` it carries, a locked one's saying only that.

## The page's X was pressed.
signal closed
## A new find was hovered for the first time and left `Inventory.uniques_new`.
signal seen

const HELP_ICON := "res://Assets/UI/ui_icon_info.png"
## The foot's two labels, for the tests.
const BONUS_NAME := "Bonus"
const COUNT_NAME := "Count"

var inventory: Inventory
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
	# Scrolled, like the journal: the uniques run to more rows than a 648 px window holds.
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(BountyList.ROW_GAP, BagPage.WIDTH)
	scroll.add_child(_rows)
	# Under the scroll and not in it: what the log is worth and how full it is are true of the whole
	# page, and stay in sight wherever the grid has been dragged to.
	UITheme.body_of(_panel).add_child(UITheme.rule(BagPage.WIDTH))
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 4)
	UITheme.body_of(_panel).add_child(_foot)
	open()


## Redraws the page: the grid, and the foot under it -- what the log adds on the left, how much of
## it is found on the right and the info mark after it, both figures in the body font.
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
	help.tooltip_text = ("Each unique found adds %d%% increased Damage, worn or not."
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
	var grid := GridContainer.new()
	grid.columns = BagPage.GRID_COLS
	grid.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	grid.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	_rows.add_child(grid)
	for id: String in UniqueTable.ids():
		# Dev (`Settings.show_all_uniques`): every square as found. The count and the bonus stay the save's.
		var found := Settings.show_all_uniques() or inventory.uniques_found.has(id)
		var slot := CollectionPage.square(id, found, Achievements.is_unlocked(inventory, id))
		grid.add_child(slot)
		if found and id in inventory.uniques_new:
			slot.keep_shining()
			# The card writes the hint as the cursor comes onto the square, which is when it is seen.
			var write := slot.hint
			slot.hint = func(rows: VBoxContainer, width: float) -> void:
				write.call(rows, width)
				_on_seen(id, slot)


func _on_seen(id: String, slot: ItemSlot) -> void:
	if not inventory.uniques_new.has(id):
		return
	inventory.uniques_new.erase(id)
	slot.stop_shining()
	seen.emit()


## One unique's square. A specimen rather than the player's own: the log says what the thing *is*, at
## level 1 and the bottom of every band, and the one in the bag says what theirs rolled.
static func square(id: String, found: bool, unlocked := false) -> ItemSlot:
	var piece := CollectionPage.specimen(id)
	if found:
		# The piece as it is, and the card still says whether it is locked.
		var slot := ItemSlot.make(piece)
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


## What the card says beside a unique in the log. With no `specimen` -- one still locked -- only the
## word "Locked". With one: the piece itself (the log's own), and then "Locked" if it is, or "Not found
## yet" if it is not `found`: a grey square beside a full card was read as a piece in hand.
static func write_hint(rows: VBoxContainer, width: float, specimen: Item = null, unlocked := true,
		found := true) -> void:
	# A locked one says so and nothing else: what unlocks it is the achievements page's to say (the
	# user's call, 2026-09-28).
	if specimen == null:
		rows.add_child(ItemDetails.line("Locked", Palette.TEXT_SOFT, width))
		return
	# `fill` empties the rows it is given, so the piece goes in first. The square itself says whether
	# it is found, so the card does not: under the piece is only "Locked".
	ItemDetails.fill(rows, specimen, width, [], Settings.item_details)
	if not unlocked or not found:
		rows.add_child(UITheme.rule())
		rows.add_child(ItemDetails.line("Locked" if not unlocked else "Not found yet", Palette.TEXT_SOFT,
				width, true))


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x,
			get_viewport_rect().size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = Vector2.ONE * UITheme.EDGE * _ui_scale
