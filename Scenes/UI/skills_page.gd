class_name SkillsPage
extends Control
## The skills page against the left edge: the free points over the player's skill tree, drawn round its
## root (`SkillTreeView`), and a Reset that buys every point back for gold. A press on a stone puts a
## point in it; the card under the cursor is the bag's, since a stone is an item. The tree itself is
## built on the black screen of a transcension, never here. Showing or hiding this node opens or closes
## the whole page. The tree zooms by the wheel, a pinch or the − and + beside the points, and the page is
## never narrower than the bag, the width every left-hand page shares.

## The bar's name, the black screen's card's and its tree panel's too: the tree is "Skill tree" wherever
## it stands, and what is placed in it a node (the review of 2026-10-09).
const TITLE := "Skill tree"

## The page's X was pressed.
signal closed
## Redrawn, and the points to spend may have moved with it.
signal changed
## A point went into a node, whose light is `glow` (`SkillTreeView.glow_of`): the main scene hands it to
## `ItemCard.flash`, the card under the cursor being that node's.
signal learned(glow: Color)

var inventory: Inventory
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _body: VBoxContainer
var _points: Label
var _scroll: ScrollContainer
var _view: SkillTreeView
var _reset: Button

## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


func _init(player_inventory: Inventory, save_path: String, ui_scale: float) -> void:
	inventory = player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel(TITLE, "Close the skill tree", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)
	_body = rows
	var top := HBoxContainer.new()
	rows.add_child(top)
	_points = UITheme.label()
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_points)
	# Scrolled both ways under the points, which stay pinned: a grown tree is wider than a phone. Its
	# thin bars show only once the tree is bigger than its box, which says it can be dragged about.
	_scroll = UITheme.scroll()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rows.add_child(_scroll)
	_view = SkillTreeView.new()
	_view.slot_pressed.connect(_on_stone_pressed)
	_view.zoomed.connect(layout)
	_view.hold_ended.connect(func() -> void: inventory.save(_save_path))
	_scroll.add_child(_view)
	top.add_child(SkillTreeView.zoom_buttons(_view))
	_reset = UITheme.priced_button("Reset", 0.0, "SmallButton", "Take back every point, for gold")
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reset.pressed.connect(_on_respec_pressed)
	rows.add_child(_reset)
	open()


## Redraws the page from the inventory: levels and gold both move while it is shut.
func open() -> void:
	changed.emit()
	var free := inventory.skills.points(inventory.level)
	_points.text = "%d skill point%s" % [free, "" if free == 1 else "s"]
	_points.add_theme_color_override("font_color", Palette.LEAF if free > 0 else Palette.TEXT_SOFT)
	# A new player's cue for where a point goes, over once one has ever been spent.
	_view.teaching = Inventory.FIRST_POINT not in inventory.tips and inventory.skills.spent() == 0
	_view.fill(inventory.skills, true, null, free)
	var spent := inventory.skills.spent()
	var cost := inventory.respec_cost()
	UITheme.set_price(_reset, cost if spent > 0 else 0.0)
	_reset.disabled = spent <= 0 or inventory.gold < cost
	if is_inside_tree():
		layout()


## Full window height against the left edge, or a sheet along the foot held upright (as tall as the tree
## at its zoom, half the window at most), and the bag's width at the least; the tree scaled into what
## that leaves it, a whole window pixel at a time, and at the player's zoom scrolled in that box.
func layout() -> void:
	var room := area if area.has_area() else get_viewport_rect()
	var window := get_viewport_rect().size
	var tall := room.size.y
	if UITheme.narrow(window, _ui_scale):
		tall = minf(tall, window.y / 2.0)
	# The frame's sides and everything above and below the scroll, which takes no room of its own.
	_scroll.custom_minimum_size = Vector2.ZERO
	var outer := _panel.get_combined_minimum_size()
	var chrome := Vector2(outer.x - _body.get_combined_minimum_size().x, outer.y)
	var most := Vector2(room.size.x, tall) / _ui_scale - Vector2.ONE * 2.0 * UITheme.EDGE - chrome
	# As wide as the tree fits (the bag's width at the least), whatever the zoom: zoomed, it scrolls inside.
	var tree := _view.fit(most, _ui_scale)
	_scroll.custom_minimum_size.x = maxf(minf(tree.x, most.x), BagPage.WIDTH)
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)


## One point into a stone. A refused press does nothing: the card says what the stone is, and the count
## on its corner whether it has room. A press held down puts one in again and again, saved once it lets
## go (`SkillTreeView.hold_ended`), so the save and the corner's damage float come once, not each point.
func _on_stone_pressed(path: String) -> void:
	# A finger has no hover: its first tap on a stone is what puts the card up, and the next learns it --
	# or a finger held on it then, point after point.
	if not Cursors.applies("node:" + path):
		return
	if not inventory.rank_up_skill(path):
		return
	if not _view.repeating:
		inventory.save(_save_path)
	if path.is_empty():
		print("Learned the root (%d)" % inventory.skills.rank_of(path))
	else:
		print("Learned %s at %s (%d/%d)" % [inventory.skills.stones[path].display_name(), path,
				inventory.skills.rank_of(path), SkillTree.most_ranks(inventory.skills.stones[path])])
	open()
	learned.emit(SkillTreeView.glow_of(inventory.skills.stones.get(path)))


func _on_respec_pressed() -> void:
	var cost := inventory.respec_cost()
	if not inventory.respec():
		return
	inventory.save(_save_path)
	print("Reset the skill tree for %s gold" % BigNumber.format(cost))
	open()
