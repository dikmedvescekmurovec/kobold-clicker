class_name CollectionPage
extends Control
## The collection log, as a page against the left edge: every unique the game has, one square each in
## `UniqueTable`'s order. One the player has found is drawn as the piece it is; one a fortuneteller
## has shown them (`FortuneTeller.peek`) is the same piece darkened, and the card beside it says what
## it is and where it is found; any other is its outline in black, and its card says nothing but that.
##
## Built like the other left-hand pages (`BountyList`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## It changes nothing and so saves nothing -- `FightLedger` is what writes a find into the log.
##
## Every square is an `ItemSlot`, so the one `ItemCard` the main scene built describes these too: a
## found one through `ItemDetails` as anywhere else, a missing one through the `hint` it carries.

## The page's X was pressed.
signal closed

const HELP_ICON := "res://Assets/UI/ui_icon_info.png"
## The foot's two labels, for the tests.
const BONUS_NAME := "Bonus"
const COUNT_NAME := "Count"

var inventory: Inventory
var view: MapBuilder
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
var _foot: HBoxContainer


func _init(player_inventory: Inventory, map_view: MapBuilder, ui_scale: float) -> void:
	inventory = player_inventory
	view = map_view
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Collection", "Close the collection", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Scrolled, like the journal: the uniques run to more rows than a 648 px window holds.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var bonus := UITheme.label("+%d%% Damage" % inventory.collection_bonus(), Palette.SLATE, true)
	bonus.name = BONUS_NAME
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(bonus)
	var count := UITheme.label("Found %d of %d" % [inventory.uniques_found.size(),
			UniqueTable.UNIQUES.size()], Palette.SLATE, true)
	count.name = COUNT_NAME
	_foot.add_child(count)
	# Last in the row, so its card stands past the panel and not over the two figures it explains.
	_foot.add_child(help)
	var grid := GridContainer.new()
	grid.columns = BagPage.GRID_COLS
	grid.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	grid.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	_rows.add_child(grid)
	var peeked := FortuneTeller.peeked(inventory.fortunes)
	for id: String in UniqueTable.ids():
		# Dev (`Settings.show_all_uniques`): every square as found. The count and the bonus stay the save's.
		var found := Settings.show_all_uniques() or inventory.uniques_found.has(id)
		grid.add_child(CollectionPage.square(id, found, view, id in peeked))


## One unique's square. A specimen rather than the player's own: the log says what the thing *is*, at
## level 1 and the bottom of every band, and the one in the bag says what theirs rolled.
static func square(id: String, found: bool, map_view: MapBuilder, peeked := false) -> ItemSlot:
	var piece := CollectionPage.specimen(id)
	if found:
		return ItemSlot.make(piece)
	return ItemSlot.shadow(piece, CollectionPage.write_hint.bind(id, map_view, piece if peeked else null),
			peeked)


## The log's own copy of a unique: level 1, every modifier at the bottom of its band.
static func specimen(id: String) -> Item:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var piece := Item.rolled_unique(id, rng)
	for mod in piece.mods:
		mod["value"] = int(ModifierTable.band_for(str(mod["id"]), 1)[0])
	return piece


## What the card says beside a unique not found yet. With no `specimen` -- one no fortuneteller has
## shown -- that and who to ask. With one: the piece itself (the log's own), then where to look -- the ground it is found on as the
## tile panel's own swatches, and the nearest piece of that ground the player has seen
## (`MapBuilder.nearest_env`, which never names land under the fog). The fortuneteller's own page
## writes the same card, so a relic reads the same at her table and in the log.
static func write_hint(rows: VBoxContainer, width: float, id: String, map_view: MapBuilder,
		specimen: Item = null) -> void:
	if specimen == null:
		rows.add_child(ItemDetails.line("Not found yet", Palette.SLATE, width))
		rows.add_child(ItemDetails.line("A fortuneteller could say more.", Palette.SLATE, width, true))
		return
	# `fill` empties the rows it is given, so the piece goes in first and "not found" under it.
	ItemDetails.fill(rows, specimen, width)
	rows.add_child(UITheme.rule())
	rows.add_child(ItemDetails.line("Not found yet", Palette.SLATE, width, true))
	var envs: Array = UniqueTable.UNIQUES[id]["envs"]
	if envs.is_empty():
		rows.add_child(ItemDetails.line("Carried by monsters everywhere.", Palette.INK, width, true))
	else:
		rows.add_child(ItemDetails.line("Carried by the monsters of:", Palette.INK, width, true))
		if map_view != null:
			var swatches := HBoxContainer.new()
			swatches.add_theme_constant_override("separation", 2)
			for env: String in envs:
				swatches.add_child(map_view.map.tileset.env_icon(env))
			rows.add_child(swatches)
		else:
			rows.add_child(ItemDetails.line(", ".join(PackedStringArray(envs)), Palette.INK, width, true))
		if map_view != null:
			var near := map_view.nearest_env(PackedStringArray(envs), 0)
			rows.add_child(ItemDetails.line("Nearest: %s" % (map_view.name_of(near)
					if near != HexMap.NO_CELL else "none you have seen yet."), Palette.SLATE, width, true))
	rows.add_child(ItemDetails.line("Bosses carry one far more often than the rabble.",
			Palette.SLATE, width, true))


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, get_viewport_rect().size.y / _ui_scale)
	_panel.position = Vector2.ZERO
