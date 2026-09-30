class_name AchievementsPage
extends Control
## The achievements, as a page against the left edge -- simple, after the user's reference (2026-09-28):
## a bar across the top saying how much of the list is earned, rank by rank, and under it one grid of
## squares in `Achievements.ACHIEVEMENTS`' order, the easiest first. A square is the unique it unlocks:
## lit once earned, with the rank reached on its corner, the same square dimmed until then. Its card,
## the item card's own (`ItemSlot.hint`), says the achievement's name and rank, what the next rank
## asks, how far the player is, and which unique it unlocks or strengthens.
##
## Built like the collection log beside it: `open()` redraws it, `layout()` fits it to the window,
## `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`. It saves
## nothing: the main scene clears what was new when it opens the page.

## The page's X was pressed.
signal closed

## The bar's label, for the tests.
const SHARE_NAME := "Share"
## The bar across the top.
const BAR_HEIGHT := 16
## Each square's own bar (`progress_bar`): its node name for the tests, its height and how far in
## from the square's edges it lies.
const PROGRESS_NAME := "Progress"
const PROGRESS_HEIGHT := 2
const PROGRESS_INSET := 3

var inventory: Inventory
var _ui_scale: float
var _panel: VBoxContainer
var _head: VBoxContainer
var _rows: VBoxContainer


func _init(player_inventory: Inventory, ui_scale: float) -> void:
	inventory = player_inventory
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Achievements", "Close the achievements", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Above the scroll and not in it: how much is earned is true of the whole page.
	_head = UITheme.vbox(0, BagPage.WIDTH)
	UITheme.body_of(_panel).add_child(_head)
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(BountyList.ROW_GAP, BagPage.WIDTH)
	scroll.add_child(_rows)
	open()


## Redraws the page: the bar, then the grid.
func open() -> void:
	UITheme.clear(_head)
	UITheme.clear(_rows)
	var ranks := 0
	for id: String in inventory.achievements:
		ranks += Achievements.rank(inventory, id)
	_head.add_child(share_bar(ranks, Achievements.ACHIEVEMENTS.size() * UniqueTable.PEAK))
	var known := Achievements.state(inventory)
	var grid := GridContainer.new()
	grid.columns = BagPage.GRID_COLS
	grid.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	grid.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	_rows.add_child(grid)
	for tier in range(1, Achievements.TIER_NAMES.size()):
		for id: String in Achievements.ACHIEVEMENTS:
			if int(Achievements.ACHIEVEMENTS[id]["tier"]) == tier:
				grid.add_child(tile(inventory, id, known))


## The bar across the top: an ink trough filling with leaf, the share earned written over its middle.
static func share_bar(have: int, need: int) -> Control:
	var share := clampf(float(have) / maxi(need, 1), 0.0, 1.0)
	var trough := ColorRect.new()
	trough.color = Palette.INK
	trough.custom_minimum_size = Vector2(BagPage.WIDTH, BAR_HEIGHT)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.LEAF_LT
	fill.position = Vector2.ONE
	fill.size = Vector2(floorf((BagPage.WIDTH - 2) * share), BAR_HEIGHT - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(fill)
	var said := UITheme.label("%d%%" % roundi(share * 100.0), Palette.BONE, true)
	said.name = SHARE_NAME
	said.add_theme_color_override("font_outline_color", Palette.INK)
	said.add_theme_constant_override("outline_size", 4)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# On the bar's middle line and grown both ways: the label's box is taller than the bar, and grown
	# down from its top the words sat low.
	said.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	said.grow_vertical = Control.GROW_DIRECTION_BOTH
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(said)
	return trough


## One achievement's square: the unique it unlocks, lit once earned with the rank reached on its corner
## and dimmed until then, its card written by `write_card`.
static func tile(player: Inventory, id: String, known: Dictionary) -> ItemSlot:
	var slot := ItemSlot.make(CollectionPage.specimen(id))
	slot.hint = AchievementsPage.write_card.bind(player, id, known)
	# No rarity frame: a square here is an achievement, not a piece (the user's call, 2026-09-28).
	var frame := slot.get_node_or_null(ItemSlot.FRAME_NAME)
	if frame != null:
		slot.remove_child(frame)
		frame.free()
	var rank := Achievements.rank(player, id)
	# Before the rank's numeral, which is drawn over it.
	slot.add_child(progress_bar(player, id, rank, known))
	if rank <= 0:
		slot.modulate = ItemSlot.SHADOW
		# No glint: that is for a piece in hand.
		(slot.get_child(0) as TextureRect).material = null
	else:
		slot.add_child(OrbSlot.count_label(Achievements.RANK_NAMES[rank]))
	return slot


## How far a square's achievement is toward its next rank, along the square's foot: an ink trough
## filling with leaf, and full and gold at rank IV. It is what sets this page apart from the collection
## log's grid of the same pieces: here a square is a thing being worked at.
static func progress_bar(player: Inventory, id: String, rank: int, known: Dictionary) -> ColorRect:
	var share := 1.0
	if rank < UniqueTable.PEAK:
		var need := Achievements.need_at(id, rank + 1)
		share = clampf(minf(Achievements.progress(player, id, known), need) / maxf(need, 1.0), 0.0, 1.0)
	var trough := ColorRect.new()
	trough.name = PROGRESS_NAME
	trough.color = Palette.INK
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.position = Vector2(PROGRESS_INSET, ItemSlot.SIDE - PROGRESS_INSET - PROGRESS_HEIGHT)
	trough.size = Vector2(ItemSlot.SIDE - 2 * PROGRESS_INSET, PROGRESS_HEIGHT)
	var fill := ColorRect.new()
	fill.color = Palette.GOLD if rank >= UniqueTable.PEAK else Palette.LEAF_LT
	fill.size = Vector2(floorf(trough.size.x * share), PROGRESS_HEIGHT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(fill)
	return trough


## What the card beside a square says: the achievement's name and the rank reached, what the next rank
## asks and how far along the player is (or that every rank is earned), and the name of the unique it
## unlocks -- or strengthens, once it has.
static func write_card(rows: VBoxContainer, width: float, player: Inventory, id: String,
		known: Dictionary) -> void:
	UITheme.clear(rows)
	var row: Dictionary = Achievements.ACHIEVEMENTS[id]
	var rank := Achievements.rank(player, id)
	rows.add_child(ItemDetails.line(str(row["name"]), Palette.TEXT, width))
	if rank > 0:
		rows.add_child(ItemDetails.line("Rank %s of %s" % [Achievements.RANK_NAMES[rank],
				Achievements.RANK_NAMES[UniqueTable.PEAK]], Palette.TEXT_SOFT, width, true))
	if rank >= UniqueTable.PEAK:
		rows.add_child(ItemDetails.line(Achievements.text(id, rank), Palette.TEXT, width, true))
		rows.add_child(ItemDetails.line("Achieved", Palette.LEAF, width, true))
	else:
		rows.add_child(ItemDetails.line(Achievements.text(id, rank + 1), Palette.TEXT, width, true))
		var need := Achievements.need_at(id, rank + 1)
		var have := minf(Achievements.progress(player, id, known), need)
		# A feat done at a wall is a number of walls out, not a count to watch climb.
		if need > 1.0 and not str(row["key"]).begins_with("wall_") and row["key"] != "domino_wall":
			rows.add_child(ItemDetails.line("Progress: %s / %s (%d%%)" % [BigNumber.format(have),
					BigNumber.format(need), floori(have / need * 100.0)], Palette.LEAF, width, true))
	# Small and in ink rather than the unique's gold, which cannot be read at 10 px on cream; no rule over
	# it and nothing of what the piece does -- the log says that (the user's call, 2026-09-28).
	rows.add_child(ItemDetails.line("%s %s" % ["Strengthens" if rank > 0 else "Unlocks",
			UniqueTable.UNIQUES[id]["name"]], Palette.TEXT, width, true))


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale)
