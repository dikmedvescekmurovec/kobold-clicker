class_name AchievementsPage
extends Control
## The achievements, as a page against the left edge -- simple, after the user's reference (2026-09-28):
## a bar across the top saying how much of the list is earned, rank by rank, and under it one grid of
## squares by the achievement's name (the user's, 2026-10-02). A square is the unique it unlocks:
## lit once earned, with the rank reached on its corner, the same square dimmed until then. Its card,
## the item card's own (`ItemSlot.hint`), says the achievement's name and rank, what the next rank
## asks and how far the player is; its Alt key names the unique.
##
## Built like the collection log beside it: `open()` redraws it, `layout()` fits it to the window,
## `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`. It saves
## nothing: an achievement new since the last look (`Inventory.achievements_new`) is the only square
## that glints, until the cursor has been over it or the page is closed, and then `seen` asks the main
## scene to save.

## The page's X was pressed.
signal closed
## A new achievement was hovered, or the page closed over one, and it left `Inventory.achievements_new`.
signal seen

## The bar's label, for the tests.
const SHARE_NAME := "Share"
## The bar across the top, and a card's.
const BAR_HEIGHT := 16
const CARD_BAR_HEIGHT := 12
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
	visibility_changed.connect(_on_visibility_changed)
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
	var ids := Achievements.ACHIEVEMENTS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(Achievements.ACHIEVEMENTS[a]["name"]).naturalnocasecmp_to(str(Achievements.ACHIEVEMENTS[b]["name"])) < 0)
	for id: String in ids:
		var slot := tile(inventory, id, known)
		grid.add_child(slot)
		if id in inventory.achievements_new:
			slot.shine_until_hovered(_on_seen.bind(id))


func _on_seen(id: String) -> void:
	if inventory.achievements_new.has(id):
		inventory.achievements_new.erase(id)
		seen.emit()


## Closing the page is seeing what was new on it, hovered or not.
func _on_visibility_changed() -> void:
	if not visible and not inventory.achievements_new.is_empty():
		inventory.achievements_new.clear()
		seen.emit()


## The bar across the top: the share earned, rank by rank.
static func share_bar(have: int, need: int) -> Control:
	var share := clampf(float(have) / maxi(need, 1), 0.0, 1.0)
	return bar(share, "%d%%" % roundi(share * 100.0), BagPage.WIDTH, BAR_HEIGHT)


## An ink trough filling with leaf -- gold once `done` -- with `text` written over its middle: the bar
## across the page's top, and a card's toward its next rank.
static func bar(share: float, text: String, width: float, height: int, done := false) -> Control:
	var trough := ColorRect.new()
	trough.color = Palette.INK
	trough.custom_minimum_size = Vector2(width, height)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.GOLD if done else Palette.LEAF_LT
	fill.position = Vector2.ONE
	fill.size = Vector2(floorf((width - 2) * clampf(share, 0.0, 1.0)), height - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(fill)
	var said := UITheme.label(text, Palette.BONE, true)
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
## and dimmed until then, its card written by `write_card` -- and under Alt, the unique's own card as
## the collection log writes it.
static func tile(player: Inventory, id: String, known: Dictionary) -> ItemSlot:
	var slot := ItemSlot.make(CollectionPage.specimen(id))
	slot.hint = AchievementsPage.write_card.bind(player, id, known)
	slot.set_meta(ItemCard.ALT_CARD, CollectionPage.write_hint.bind(slot.item, Achievements.is_unlocked(player, id),
			Settings.show_all_uniques() or player.uniques_found.has(id)))
	# The unique it unlocks, named where Alt is said to show it.
	slot.set_meta(ItemCard.KEYS, {"alt": UniqueTable.UNIQUES[id]["name"]})
	# No rarity frame: a square here is an achievement, not a piece (the user's call, 2026-09-28).
	var frame := slot.get_node_or_null(ItemSlot.FRAME_NAME)
	if frame != null:
		slot.remove_child(frame)
		frame.free()
	# Still: only what is new glints, and the page decides that.
	slot.still()
	var rank := Achievements.rank(player, id)
	# Before the rank's numeral, which is drawn over it.
	slot.add_child(progress_bar(player, id, rank, known))
	if rank <= 0:
		slot.modulate = ItemSlot.SHADOW
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


## What the card beside a square says, after the user's pick (2026-10-07, `tools/qa/achievement_card_m2.png`):
## the achievement's name with the rank reached at its right end ("I / IV"), what the next rank asks,
## and how far along the player is as the page's own bar -- full and gold, "Achieved", at IV. The unique
## it unlocks is the square's Alt key's word (`tile`), never a line here.
static func write_card(rows: VBoxContainer, width: float, player: Inventory, id: String,
		known: Dictionary) -> void:
	UITheme.clear(rows)
	var row: Dictionary = Achievements.ACHIEVEMENTS[id]
	var rank := Achievements.rank(player, id)
	var head := HBoxContainer.new()
	var title := ItemDetails.line(str(row["name"]), Palette.TEXT, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if rank > 0:
		var reached := UITheme.label("%s / %s" % [Achievements.RANK_NAMES[rank],
				Achievements.RANK_NAMES[UniqueTable.PEAK]], Palette.TEXT_SOFT, true)
		reached.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(reached)
	rows.add_child(head)
	if rank >= UniqueTable.PEAK:
		rows.add_child(ItemDetails.line(Achievements.text(id, rank), Palette.TEXT, width, true))
		rows.add_child(bar(1.0, "Achieved", width, CARD_BAR_HEIGHT, true))
		return
	rows.add_child(ItemDetails.line(Achievements.text(id, rank + 1), Palette.TEXT, width, true))
	var need := Achievements.need_at(id, rank + 1)
	var have := minf(Achievements.progress(player, id, known), need)
	# A feat done at a wall is a number of walls out, not a count to watch climb.
	if need > 1.0 and not str(row["key"]).begins_with("wall_") and row["key"] != "domino_wall":
		rows.add_child(bar(have / need, "%s / %s" % [BigNumber.format(have), BigNumber.format(need)],
				width, CARD_BAR_HEIGHT))


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)
