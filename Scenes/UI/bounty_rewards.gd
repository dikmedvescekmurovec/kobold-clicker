class_name BountyRewards
extends Node
## What a town's bounty board hands over, each a titled panel named "Panel" in a screen-wide catch, so
## the town under it cannot be pressed: what a claimed bounty paid (`show_paid`) and a cleared board's
## three options (`show_choice`). A child of the character's layer, where the catches go too.

## A reward option's column and the gap between two, in panel pixels: three columns and two gaps fit
## the narrowest window's 324.
const CHOICE_WIDTH := 92.0
const CHOICE_GAP := 8

## The options are up: where the smith speaks over them the first time (`first_board_cleared`).
signal choice_shown

## A claim's verdict, up until Collect; null otherwise.
var paid: Control
## A cleared board's options, up until one is taken or they are put away; null otherwise.
var choice: Control

var _town: TownPage
## Lifted back over each catch with the tooltips: they share the layer, and a later child draws over.
var _item_card: ItemCard
var _ui_scale: float


func _init(town: TownPage, item_card: ItemCard, ui_scale: float) -> void:
	_town = town
	_item_card = item_card
	_ui_scale = ui_scale


## What a bounty paid, laid out and arriving as a fight's verdict does. It is paid already: Collect only
## puts the panel away, so a game closed under it loses nothing.
func show_paid(enemy: String, gold: float, xp: int, orbs: Dictionary, piece: Item) -> void:
	close_paid()
	paid = _catch("Bounty claimed", Callable())
	var panel := paid.get_node("Panel") as VBoxContainer
	var body := UITheme.body_of(panel)
	body.add_theme_constant_override("separation", 8)
	var whom := UITheme.label(enemy)
	whom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(whom)
	var sums := HBoxContainer.new()
	sums.add_theme_constant_override("separation", 10)
	sums.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(sums)
	sums.add_child(_sum(_mark(Coins.icon(), Vector2.ONE * Coins.SIZE), gold))
	if xp > 0:
		sums.add_child(_sum(_mark(CombatScene.XP_GEM,
				CombatScene.XP_GEM.get_size() * CombatScene.XP_GEM_SCALE), float(xp)))
	var drops := DropsView.new()
	body.add_child(drops)
	var found: Array[Item] = []
	if piece != null:
		found.append(piece)
	drops.fill(found, orbs)
	var collect := UITheme.button("Collect", "LightButton", "Put it all away")
	collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	collect.pressed.connect(leave_paid)
	body.add_child(collect)
	drops.resized_contents.connect(_centre.bind(panel))
	_arrive(paid, drops.pieces())


## Collect and Escape: the panel shrinks away, and a board the claim cleared puts up its reward.
func leave_paid() -> void:
	if paid != null:
		Juice.pop_out(paid.get_node("Panel"), func() -> void:
			close_paid()
			show_choice())


func close_paid() -> void:
	if paid != null:
		paid.queue_free()
		paid = null


## A cleared board's reward: its options side by side, each its square (a piece opens its card under
## the cursor, as anywhere), its name and Take. One is taken and the rest go; the X and Escape put them
## away untaken, to come back from the board's Reward (`TownPage.choice_asked`).
func show_choice() -> void:
	close_choice()
	var offered := _town.pending_choice() if _town.visible else []
	if offered.is_empty():
		return
	choice = _catch("Board cleared", leave_choice)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", CHOICE_GAP)
	UITheme.body_of(choice.get_node("Panel") as VBoxContainer).add_child(cards)
	var squares := []
	for i in offered.size():
		var option: Dictionary = offered[i]
		var piece: Item = option.get(BountyBoard.CHOICE_ITEM)
		var card := UITheme.vbox(6, CHOICE_WIDTH)
		cards.add_child(card)
		var square: Control
		var called: Label
		if piece != null:
			square = ItemSlot.make(piece)
			called = UITheme.label(piece.display_name(), piece.text_color(), true)
		elif option.has(BountyBoard.CHOICE_GOLD):
			square = _pile_square(Coins.icon())
			called = _pile_name("%s gold", option[BountyBoard.CHOICE_GOLD])
		elif option.has(BountyBoard.CHOICE_XP):
			square = _pile_square(BountyList.XP_GEM)
			called = _pile_name("%s experience", option[BountyBoard.CHOICE_XP])
		else:
			var orb := str(option[BountyBoard.CHOICE_ORB])
			square = OrbSlot.make(orb, int(option[BountyBoard.CHOICE_COUNT]), true, false, ItemSlot.SIDE)
			# Read, not pressed: Take is what takes it.
			Cursors.wear(square, Cursors.ARROW)
			square.tooltip_text = OrbTable.describe(orb)
			called = UITheme.label(orb, Palette.TEXT, true)
		square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(square)
		squares.append(square)
		called.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		called.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		called.custom_minimum_size.x = CHOICE_WIDTH
		# The names wrap to different heights, and the three Takes still stand on one line.
		called.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(called)
		var why := _town.why_not_take(i)
		var take := UITheme.button("Take", "SmallGoButton", why if not why.is_empty() else "Take this one")
		take.disabled = not why.is_empty()
		take.pressed.connect(_on_choice_taken.bind(i))
		card.add_child(take)
	_arrive(choice, squares)
	choice_shown.emit()


func _on_choice_taken(index: int) -> void:
	if _town.take_choice(index):
		leave_choice()


## Take, the X and Escape: the options shrink away. Untaken, they wait in the town's drawer.
func leave_choice() -> void:
	if choice != null:
		Juice.pop_out(choice.get_node("Panel"), close_choice)


func close_choice() -> void:
	if choice != null:
		choice.queue_free()
		choice = null


## A screen-wide catch on the layer, a titled panel named "Panel" in it (`close` its X; none where it
## is empty).
func _catch(title: String, close: Callable) -> Control:
	var layer := get_parent()
	var catch := Control.new()
	catch.theme = UITheme.theme()
	catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	catch.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(catch)
	var panel := UITheme.titled_panel(title, "", close)
	# Named, because the win's wash goes in under it and it is no longer the first child.
	panel.name = "Panel"
	catch.add_child(panel)
	layer.move_child(_item_card, -1)
	for card: Node in layer.get_children():
		if card is TipCard:
			layer.move_child(card, -1)
	return catch


## `catch`'s panel arriving as a fight's verdict does: popped in and `pieces` revealed at once (what
## the caller does next still runs before the frame's wait), then centred and washed.
func _arrive(catch: Control, pieces: Array) -> void:
	var panel := catch.get_node("Panel") as Control
	panel.resized.connect(_centre.bind(panel))
	Juice.pop_in(panel, _ui_scale)
	Juice.reveal(pieces)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	_centre(panel)
	Juice.celebrate(catch, panel, _ui_scale, (panel.get_child(0) as Control).size.y)


func _centre(panel: Control) -> void:
	Juice.centre(panel, get_viewport().get_visible_rect().size)


func _mark(picture: Texture2D, side: Vector2) -> TextureRect:
	var mark := TextureRect.new()
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture = picture
	mark.custom_minimum_size = side
	return mark


## One of the claim's sums: a mark and a bare number, counted up once it is shown.
func _sum(mark: TextureRect, amount: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(mark)
	var figure := UITheme.label()
	row.add_child(figure)
	# The coin spins while it counts; the gem is not a coin.
	figure.ready.connect(func() -> void:
		Juice.count_up(figure, amount, mark if mark.texture == Coins.icon() else null))
	return row


## A pile of gold or experience as a square: its mark on a plain socket at the largest whole scale the
## icon's room takes, so a pixel stays square (the coin at 2x, the gem at 5x).
static func _pile_square(mark: Texture2D) -> ItemSlot:
	var square := ItemSlot.teaser(mark, ItemRarity.Rarity.COMMON, 0, "")
	var icon := square.get_child(0) as TextureRect
	icon.size = mark.get_size() * floorf(ItemSlot.ICON / mark.get_size().x)
	icon.position = (square.custom_minimum_size - icon.size) / 2.0
	return square


static func _pile_name(words: String, amount: Variant) -> Label:
	return UITheme.label(words % BigNumber.format(float(amount)), Palette.TEXT, true)
