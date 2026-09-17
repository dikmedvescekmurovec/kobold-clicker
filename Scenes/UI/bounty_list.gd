class_name BountyList
extends Control
## Every bounty the player has taken on, as a page against the left edge: what each board wants, how
## far along it is, what it pays, and -- the whole point of it -- where that monster lives.
##
## The same rows the town page's board draws, because they are built here and it calls them: a bounty
## reads the same standing at the board that posted it and standing ten tiles away from it. What this
## page adds is the town's name over the postings and a line saying where to hand a finished one in;
## what the board adds is the Claim button, which only the town that posted it ever shows.
##
## Built like the other left-hand pages (`SkillsPage`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## It changes nothing and so saves nothing -- a bounty is handed in at the town that posted it.

## The page's X was pressed.
signal closed
## A Show button was pressed: put the map on this cell. The page cannot do it itself -- the map, the
## camera and the pages that have to get out of the way are the main scene's.
signal show_cell(cell: Vector2i)

## How wide the page's rows run, in panel pixels. Wider than the town page's 140, because nothing here
## is standing beside a bag: a tile's name and the line it sits on are what set it.
const WIDTH := 170.0
## The air between one posting and the next, and between the rows inside one.
const ROW_GAP := 6
const LINE_GAP := 2
## The coin beside a reward, at half the sprite's own 16 -- the same whole-number step the shelf's
## prices take.
const REWARD_COIN := 8
## The progress bar: how tall it is, and how far its count hangs off its bottom-right corner -- it
## overhangs for the reason `OrbSlot`'s does, 16 px being the smallest Pixellari draws cleanly and
## twice the height of the bar it is counting.
const BAR_HEIGHT := 8
const BAR_BORDER := 1
const COUNT_OVERHANG := 9
## A card: the air inside its frame, how tall the monster's picture stands, and the air around it.
const CARD_PAD := 4
const PORTRAIT := 40
const PORTRAIT_PAD := 2

var inventory: Inventory
var view: MapBuilder
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer


func _init(player_inventory: Inventory, map_view: MapBuilder, ui_scale: float) -> void:
	inventory = player_inventory
	view = map_view
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Bounties", "Close the bounty list", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Everything on the page scrolls: three postings a board and a board for every town walked into is
	# more than a 648 px window holds, and a page that cannot be wound down is a page with work hidden
	# under its own foot.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(ROW_GAP, WIDTH)
	# At least as tall as the scroll, so the accepted card can take the column.
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	open()


## Redraws the page: every board the player has stood at, town by town, with what is still open on it.
func open() -> void:
	UITheme.clear(_rows)
	var listed := 0
	for at: String in inventory.towns.towns:
		var drawer: Dictionary = inventory.towns.towns[at]
		if not BountyBoard.seen(drawer):
			continue
		var town := _town_name(TownState.spot(at))
		var posted := 0
		for bounty: Dictionary in BountyBoard.bounties(drawer):
			if not BountyBoard.is_active(bounty):
				continue
			if posted == 0:
				_rows.add_child(UITheme.label(town))
				_rows.add_child(UITheme.rule(WIDTH))
			posted += 1
			listed += 1
			# A finished bounty is paid for where it was taken on, which is the one thing this page
			# cannot do and so the one thing it has to say.
			_rows.add_child(BountyList.row(bounty, view, WIDTH, _on_show_pressed,
					"Finished. Claim it at %s." % town if BountyBoard.ready(bounty) else ""))
	if listed == 0:
		_rows.add_child(wrapped("No work is out. Accept a bounty at a board.", WIDTH, Palette.SLATE))


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, get_viewport_rect().size.y / _ui_scale)
	_panel.position = Vector2.ZERO


## One posting as a card, for this page and for the board that posted it: the monster's picture in a
## frame, its name and how many, what it pays, and a row of buttons along the foot -- **Info** and
## whatever the caller adds through `actions_of` (the board's Accept or Claim) or the Show built here.
## An accepted posting carries its progress bar; `note` is one leaf-green line over the buttons.
##
## Info folds out the part a wanted poster has no room for: the level of land a kill has to fall on,
## the land that monster lives on as the tile panel's own swatches, and the nearest piece of it the
## player has seen. It starts open on the journal (a valid `on_show`), which is read for exactly that,
## and shut on the board, where three postings have to share a 284 px column.
##
## The swatches and the line under them are the whole reason a board is worth reading: "Werewolf" says
## nothing about where to go, and a player who has to guess which of six terrains to walk is being
## sent on an errand rather than given one.
static func row(bounty: Dictionary, map_view: MapBuilder, width: float,
		on_show: Callable, note := "") -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color.TRANSPARENT, CARD_PAD))
	var inner := width - CARD_PAD * 2
	var lines := UITheme.vbox(LINE_GAP, inner)
	card.add_child(lines)
	var enemy := str(bounty.get(BountyBoard.ENEMY, ""))
	var known := EnemyRoster.ENEMIES.has(enemy)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _flat(Palette.SLOT_TAN, PORTRAIT_PAD))
	var face := TextureRect.new()
	# Set before the texture and the size: a TextureRect's minimum is its own texture until
	# `expand_mode` says otherwise, and the packs' frames run to 245 px.
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.texture = EnemyRoster.portrait(enemy) if known else null
	face.custom_minimum_size = Vector2(0, PORTRAIT)
	frame.add_child(face)
	lines.add_child(frame)
	var need := int(bounty.get(BountyBoard.NEED, 0))
	# How many is said once: by the bar once the work is taken on, beside the name until then.
	var taken := BountyBoard.is_active(bounty)
	# The one bounty that is out takes the whole column it is given, on the board and the journal alike.
	if taken:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := UITheme.label(enemy if taken else "%s x%d" % [enemy, need])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(title)
	if taken:
		lines.add_child(progress_bar(int(bounty.get(BountyBoard.HAVE, 0)), need, inner))
	var pay := HBoxContainer.new()
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	pay.add_theme_constant_override("separation", 2)
	pay.add_child(_icon(Coins.icon(), REWARD_COIN))
	pay.add_child(UITheme.label(BigNumber.format(float(bounty.get(BountyBoard.GOLD, 0))),
			Palette.SLATE, true))
	# The orb as its own picture, the tray's size, and its name for whoever hovers: a word here was
	# the one reward on the card that had to be read rather than seen.
	var orb := str(bounty.get(BountyBoard.ORB, ""))
	if not orb.is_empty():
		var gem := _icon(OrbTable.icon(orb), OrbSlot.ICON)
		gem.tooltip_text = orb
		pay.add_child(gem)
	lines.add_child(pay)

	var details := UITheme.vbox(LINE_GAP, inner)
	details.visible = on_show.is_valid()
	lines.add_child(details)
	var depth := int(bounty.get(BountyBoard.LEVEL, 0))
	if depth > 1:
		details.add_child(wrapped("On level %d land or deeper." % depth, inner, Palette.SLATE))
	var near := HexMap.NO_CELL
	if map_view != null and known:
		var envs := EnemyRoster.environments_of(enemy)
		var swatches := HBoxContainer.new()
		swatches.add_theme_constant_override("separation", 2)
		for env: String in envs:
			swatches.add_child(map_view.map.tileset.env_icon(env))
		details.add_child(swatches)
		near = map_view.nearest_env(envs, depth)
		details.add_child(wrapped("Nearest: %s" % (map_view.name_of(near) if near != HexMap.NO_CELL
				else "none you have seen yet."), inner, Palette.SLATE))
	if not note.is_empty():
		lines.add_child(wrapped(note, inner, Palette.LEAF))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", LINE_GAP)
	# At the card's foot however tall the card has been stretched.
	actions.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	lines.add_child(actions)
	var info := UITheme.button("Info", "LightButton", "Where it lives")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.pressed.connect(func() -> void: details.visible = not details.visible)
	actions.add_child(info)
	# The board passes no callable: it offers Accept instead, and Show is the journal's.
	if on_show.is_valid() and near != HexMap.NO_CELL:
		var button := UITheme.button("Show", "LightButton", "Put the map on %s" % map_view.name_of(near))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_show.bind(near))
		actions.add_child(button)
	return card


## The button row along a card's foot, where the board puts its Accept or its Claim beside Info.
static func actions_of(card: PanelContainer) -> HBoxContainer:
	return card.get_child(0).get_child(-1)


## A reward's picture at `side` panel pixels, a whole-number step down from its sprite.
static func _icon(texture: Texture2D, side: int) -> TextureRect:
	var icon := TextureRect.new()
	# Set before the texture and the size: a TextureRect's minimum is its own texture until
	# `expand_mode` says otherwise, so a 16 px coin asked for 8 comes back 16.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


## A card's frame and the portrait's socket: the pack's slot brown as a one-pixel line, the way
## `ItemSlot` draws its own square.
static func _flat(fill: Color, pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.SLOT_TAN_DK
	style.set_border_width_all(1)
	style.set_content_margin_all(pad)
	return style


## How far along a posting is, as a bar: an ink trough filling with leaf, snapped to whole panel pixels,
## with the count hanging off its bottom-right corner the way an orb's does. The row under it is kept
## clear of the numeral by the control's own height.
static func progress_bar(have: int, need: int, width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, BAR_HEIGHT + COUNT_OVERHANG)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trough := ColorRect.new()
	trough.color = Palette.INK
	trough.size = Vector2(width, BAR_HEIGHT)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(trough)
	var inside := width - BAR_BORDER * 2
	var fill := ColorRect.new()
	fill.color = Palette.LEAF
	fill.position = Vector2(BAR_BORDER, BAR_BORDER)
	fill.size = Vector2(floorf(inside * clampf(float(have) / maxi(need, 1), 0.0, 1.0)),
			BAR_HEIGHT - BAR_BORDER * 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	var tally := UITheme.label("%d/%d" % [have, need], Palette.BONE)
	tally.add_theme_color_override("font_outline_color", Palette.INK)
	tally.add_theme_constant_override("outline_size", 4)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tally.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tally.size = Vector2(width, BAR_HEIGHT + COUNT_OVERHANG)
	holder.add_child(tally)
	return holder


## A wrapped line of the page's own width. Word wrapping, because these are sentences.
static func wrapped(text: String, width: float, color: Variant = null) -> Label:
	var label := UITheme.label(text, color, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label


## What the town on a world spot is called. Read off the map, which is what named it -- the drawers
## are filed by spot, and a spot is not something to show the player.
func _town_name(spot: Vector2i) -> String:
	if view == null:
		return "Town"
	var called := view.name_of(spot - view.origin)
	return called if not called.is_empty() else "Town"


func _on_show_pressed(cell: Vector2i) -> void:
	show_cell.emit(cell)
