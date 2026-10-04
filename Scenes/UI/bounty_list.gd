class_name BountyList
extends Control
## The bounty the player has taken on, as a page against the left edge: what the board wants, how
## far along it is, what it pays, and -- the whole point of it -- the lands that monster lives on.
##
## The same rows the town page's board draws, because they are built here and it calls them: a bounty
## reads the same standing at the board that posted it and standing ten tiles away from it. What this
## page adds is the town's name over the postings and a line saying where to hand a finished one in;
## what the board adds is the Claim button, which only the town that posted it ever shows.
##
## Built like the other left-hand pages (`SkillsPage`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## The one thing it changes is giving the work up (Cancel), which it saves; a bounty is still handed
## in only at the town that posted it.

## The page's X was pressed.
signal closed
## Cancel gave the work up (and saved): a board open on the other edge has to be drawn again.
signal abandoned

## How wide the page's rows run, in panel pixels. Wider than the town page's 140, because nothing here
## is standing beside a bag: a tile's name and the line it sits on are what set it.
const WIDTH := 170.0
## The air between one posting and the next, and between the rows inside one.
const ROW_GAP := 8
const LINE_GAP := 4
## The coin beside a reward, at half the sprite's own 16 -- the same whole-number step the shelf's
## prices take.
const REWARD_COIN := 8
## The progress bar: how tall it is, and how far its count hangs off its bottom-right corner -- it
## overhangs for the reason `OrbSlot`'s does, 16 px being the smallest Pixellari draws cleanly and
## twice the height of the bar it is counting.
const BAR_HEIGHT := 8
const BAR_BORDER := 1
const COUNT_OVERHANG := 9
## What stands for a unique on a reward square: the fortuneteller's relic mark, since the piece's own
## icon would say which unique it is, which is the one thing the card must not.
const UNIQUE_MARK := preload("res://Assets/Fortune/relic.png")
## The experience a posting pays, behind the fight's own gem at twice its 6 px, as the verdict draws it.
const XP_GEM := preload("res://Assets/UI/xp_gem.png")
const REWARD_GEM := 12
## A card: the air inside its frame, how tall the monster's picture stands, and the air around it.
const CARD_PAD := 6
const PORTRAIT := 40
const PORTRAIT_PAD := 2
## The card's picture: a square as big as an item's, so an elite's frame lies on it at its own pixels.
const CARD_PORTRAIT := ItemSlot.SIDE - PORTRAIT_PAD * 2
## The promised piece on a card, at half an item square: the orbs' size, drawn at its own pixels.
const REWARD_SQUARE := ItemSlot.SIDE / 2
## The row of lands a monster lives on, named so the tests can find it.
const LANDS_NAME := "Lands"

var inventory: Inventory
var view: MapBuilder
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer


func _init(player_inventory: Inventory, map_view: MapBuilder, save_path: String,
		ui_scale: float) -> void:
	inventory = player_inventory
	view = map_view
	_save_path = save_path
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
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(ROW_GAP, WIDTH)
	# At least as tall as the scroll, so the accepted card can take the column.
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	open()


## Redraws the page: the accepted bounty, under the name of the town that posted it.
func open() -> void:
	UITheme.clear(_rows)
	var listed := 0
	for at: String in inventory.towns.towns:
		var drawer: Dictionary = inventory.towns.towns[at]
		if not BountyBoard.seen(drawer):
			continue
		var town := town_name(TownState.spot(at))
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
			var card := BountyList.row(bounty, view, WIDTH, true,
					"Finished. Claim it at %s." % town if BountyBoard.ready(bounty) else "")
			BountyList.actions_of(card).add_child(_cancel_button(bounty))
			_rows.add_child(card)
	if listed == 0:
		_rows.add_child(wrapped("No work is out. Accept a bounty at a board.", WIDTH, Palette.TEXT_SOFT))


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)


## One posting as a card, for this page and for the board that posted it: the monster's picture in a
## frame, its name and how many, what it pays, and a row of buttons along the foot -- **Info** and
## whatever the caller adds through `actions_of` (the board's Accept or Claim, the journal's Give up).
## An accepted posting carries its progress bar; `note` is one leaf-green line over the buttons.
##
## Info folds out the part a wanted poster has no room for: the level of land a kill has to fall on,
## and the lands that monster lives on as the tile panel's own swatches -- which lands, never which
## tile: finding one is the map's business (the user's, 2026-10-01). It starts `unfolded` on the
## journal, which is read for exactly that, and shut on the board, where three postings have to share
## a 284 px column.
static func row(bounty: Dictionary, map_view: MapBuilder, width: float,
		unfolded: bool, note := "") -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", flat(Color.TRANSPARENT, CARD_PAD))
	var inner := width - CARD_PAD * 2
	var lines := UITheme.vbox(LINE_GAP, inner)
	card.add_child(lines)
	var enemy := str(bounty.get(BountyBoard.ENEMY, ""))
	var known := EnemyRoster.ENEMIES.has(enemy)
	# An elite's picture wears its frame and its name the nameplate's skull, as the fight's toast does.
	var elite := known and EnemyRoster.tier_of(enemy) == EnemyRoster.Tier.ELITE
	var face := portrait_box(enemy, CARD_PORTRAIT,
			ItemRarity.frame(ItemRarity.Rarity.ELITE) if elite else null)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var need := int(bounty.get(BountyBoard.NEED, 0))
	# How many is said once: by the bar once the work is taken on, beside the name until then -- and
	# not at all for one body, where "x1" says nothing.
	var taken := BountyBoard.is_active(bounty)
	# The one bounty that is out takes the whole column it is given, on the board and the journal alike.
	if taken:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 3)
	if elite:
		var skull: Texture2D = CombatScene.TIER_MARK[EnemyRoster.Tier.ELITE]
		heading.add_child(icon(skull, skull.get_width()))
	heading.add_child(UITheme.label(enemy if taken or need <= 1 else "%s x%d" % [enemy, need]))
	lines.add_child(heading)
	# The picture beside what it pays rather than over it: three postings share one column, and a
	# poster stacked picture, name, gold, goods was two of them to a window.
	var poster := HBoxContainer.new()
	poster.add_theme_constant_override("separation", CARD_PAD)
	poster.add_child(face)
	var pays := UITheme.vbox(LINE_GAP)
	pays.alignment = BoxContainer.ALIGNMENT_CENTER
	pays.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pays.add_child(_sums(bounty))
	pays.add_child(_goods(bounty))
	poster.add_child(pays)
	lines.add_child(poster)
	if taken:
		lines.add_child(progress_bar(int(bounty.get(BountyBoard.HAVE, 0)), need, inner))

	var details := UITheme.vbox(LINE_GAP, inner)
	details.visible = unfolded
	lines.add_child(details)
	var depth := int(bounty.get(BountyBoard.LEVEL, 0))
	if depth > 1:
		details.add_child(wrapped("On level %d land or deeper." % depth, inner, Palette.TEXT_SOFT))
	if map_view != null and known:
		var swatches := HBoxContainer.new()
		swatches.name = LANDS_NAME
		swatches.add_theme_constant_override("separation", 2)
		for env: String in EnemyRoster.environments_of(enemy):
			var swatch := map_view.map.tileset.env_icon(env)
			swatch.tooltip_text = HexTileset.env_name(env)
			swatches.add_child(swatch)
		details.add_child(swatches)
	if not note.is_empty():
		lines.add_child(wrapped(note, inner, Palette.LEAF))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", CARD_PAD)
	# At the card's foot however tall the card has been stretched.
	actions.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	lines.add_child(actions)
	var info := UITheme.button("Info", "SmallButton", "Where it lives")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.pressed.connect(func() -> void: details.visible = not details.visible)
	actions.add_child(info)
	return card


## What a posting pays that is a figure: the gold behind a coin and the experience behind a gem.
static func _sums(bounty: Dictionary) -> HBoxContainer:
	var sums := _reward_row(6)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 2)
	purse.add_child(icon(Coins.icon(), REWARD_COIN))
	purse.add_child(UITheme.label(BigNumber.format(float(bounty.get(BountyBoard.GOLD, 0))),
			Palette.TEXT_SOFT, true))
	sums.add_child(purse)
	var xp := int(bounty.get(BountyBoard.XP, 0))
	if xp > 0:
		var worth := HBoxContainer.new()
		worth.add_theme_constant_override("separation", 2)
		worth.add_child(icon(XP_GEM, REWARD_GEM))
		worth.add_child(UITheme.label(BigNumber.format(float(xp)), Palette.TEXT_SOFT, true))
		sums.add_child(worth)
	return sums


## What a posting pays that goes in the bag: each orb once, in the tray's order, with how many on its
## corner as the tray writes it, and its name for whoever hovers -- then the promised piece, its kind's
## plainest picture in its rarity's frame and no more, since what it is exactly is rolled at the
## hand-in. A unique shows the relic mark, not a kind.
static func _goods(bounty: Dictionary) -> HBoxContainer:
	# Wide enough for a count hanging off an orb's corner (`OrbSlot.COUNT_OVERHANG`).
	var goods := _reward_row(8)
	var orbs := BountyBoard.orbs_of(bounty)
	for orb: String in OrbTable.ORBS:
		var count := orbs.count(orb)
		if count == 0:
			continue
		var gem := icon(OrbTable.icon(orb), OrbSlot.ICON)
		gem.tooltip_text = orb if count == 1 else "%d %s" % [count, orb]
		if count > 1:
			gem.add_child(OrbSlot.count_label(str(count)))
		goods.add_child(gem)
	var promise := BountyBoard.item_of(bounty)
	if not promise.is_empty():
		var kind := str(promise[BountyBoard.ITEM_KIND])
		var mark: Texture2D = UNIQUE_MARK if kind.is_empty() \
				else LootTable.icon(str(LootTable.KINDS[kind]["tiers"][0]))
		var square := ItemSlot.teaser(mark, ItemRarity.from_name(str(promise[BountyBoard.ITEM_RARITY])),
				int(promise[BountyBoard.ITEM_PLUS]), BountyBoard.reward_text(bounty).capitalize(),
				REWARD_SQUARE)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		goods.add_child(square)
	return goods


static func _reward_row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	return row


## The monster's picture on a tan socket, `side` panel pixels tall: the card's, and the toast's and the
## banner's a counted kill raises in a fight. With `frame`, that art (`ItemRarity.frame`) is laid over the
## socket the way `ItemSlot` frames its icon, which is how an elite's or a boss's is set apart.
static func portrait_box(enemy: String, side: int, frame: Texture2D = null) -> Panel:
	# A Panel and anchors rather than a PanelContainer: a container lays every child inside its pad,
	# and the frame has to reach the socket's edge as it does on an `ItemSlot`.
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", flat(Palette.SLOT_TAN, PORTRAIT_PAD))
	box.custom_minimum_size = Vector2.ONE * (side + PORTRAIT_PAD * 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	# Set before the texture and the size: a TextureRect's minimum is its own texture until
	# `expand_mode` says otherwise, and the packs' frames run to 245 px.
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.texture = EnemyRoster.portrait(enemy) if EnemyRoster.ENEMIES.has(enemy) else null
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PORTRAIT_PAD)
	box.add_child(face)
	if frame != null:
		var ring := TextureRect.new()
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_SCALE
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.texture = frame
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(ring)
	return box


## The button row along a card's foot, where the board puts its Accept or its Claim beside Info.
static func actions_of(card: PanelContainer) -> HBoxContainer:
	return card.get_child(0).get_child(-1)


## A reward's picture at `side` panel pixels, a whole-number step down from its sprite.
static func icon(texture: Texture2D, side: int) -> TextureRect:
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
static func flat(fill: Color, pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.SLOT_TAN_DK
	style.set_border_width_all(1)
	style.set_content_margin_all(pad)
	return style


## How far along a posting is, as a bar: an ink trough filling with leaf, snapped to whole panel pixels,
## with the count hanging off its bottom-right corner the way an orb's does. The row under it is kept
## clear of the numeral by the control's own height. Not `counted`, the bar alone, for a caller that
## writes the count itself (the character page, in the body font under it).
static func progress_bar(have: int, need: int, width: float, counted := true) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, BAR_HEIGHT + (COUNT_OVERHANG if counted else 0))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trough := ColorRect.new()
	trough.color = Palette.INK
	trough.size = Vector2(width, BAR_HEIGHT)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(trough)
	var inside := width - BAR_BORDER * 2
	var fill := ColorRect.new()
	fill.color = Palette.LEAF_LT
	fill.position = Vector2(BAR_BORDER, BAR_BORDER)
	fill.size = Vector2(floorf(inside * clampf(float(have) / maxi(need, 1), 0.0, 1.0)),
			BAR_HEIGHT - BAR_BORDER * 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	if not counted:
		return holder
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
## are filed by spot, and a spot is not something to show the player. The main scene asks it for the
## banner a filled bounty raises, which says where to hand the work in.
func town_name(spot: Vector2i) -> String:
	if view == null:
		return "Town"
	var called := view.name_of(spot - view.origin)
	return called if not called.is_empty() else "Town"


## Cancel gives the work up, and asks first on the button itself: a second press is the answer, since
## what it throws away is every kill counted so far.
func _cancel_button(bounty: Dictionary) -> Button:
	var button := UITheme.button("Give up", "SmallDangerButton", "Give this bounty up")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		if button.text != "Sure?":
			button.text = "Sure?"
			button.tooltip_text = "Press again to give it up and lose its progress"
			return
		if BountyBoard.abandon(bounty):
			print("Gave up the bounty on %s" % str(bounty.get(BountyBoard.ENEMY, "")))
			inventory.save(_save_path)
			abandoned.emit()
		open.call_deferred())
	return button

