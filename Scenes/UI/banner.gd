class_name Banner
extends Node
## What the game announces over the map and over a fight alike: the banner (a unique new to the log, a
## bounty filled, an achievement), the bounty toast and the level-up fanfare. A child of the character's
## layer, which stands over a fight's, and everything it raises goes on that layer and takes no mouse but
## the banner's X. The main scene owns the one there is and feeds it frames and presses (`tick`, `press`).

## The banner goes by itself `HOLD` seconds after it rises, while the mouse is off it; under a finger
## only its X or a tap off it after `HOLD` puts it down (the user's, 2026-09-29, 2026-10-03, 2026-10-09).
## `GAP` is the air it keeps under the fight's top column, in window pixels.
const HOLD := 5.0
const WIDTH := ItemCard.WIDTH * 1.5
const FADE := 0.4
const GAP := 12.0
## The toast: how long it hangs, how far it rises, and how tall the monster's picture stands, small for
## a common and the bounty card's own for an elite or a boss.
const TOAST_TIME := 5.0
const TOAST_RISE := 24.0
const TOAST_PORTRAIT := 24
const TOAST_BIG_PORTRAIT := BountyList.PORTRAIT
## An elite's or a boss's bounty: the frame round its picture and the colour of its count, from the
## half of the ramp that reads on a cream card (`LEAF_LT` and `GOLD` do not).
const BOUNTY_TIER := {
	EnemyRoster.Tier.ELITE: {"frame": ItemRarity.Rarity.ELITE, "colour": Palette.LEAF},
	EnemyRoster.Tier.BOSS: {"frame": ItemRarity.Rarity.UNIQUE, "colour": Palette.SLOT_TAN_DK},
}
## The level-up: how long the words hang, and their size, a whole multiple of Pixellari's 16.
const LEVEL_UP_TIME := 1.6
const LEVEL_UP_FONT := 48
const LEVEL_UP_SOUND := preload("res://Sounds/Sfx/level_up.ogg")

## The banner that is up, or null, and its heading row, the X at its end.
var panel: Control
var head: HBoxContainer
## The toast over the last counted bounty kill, while it is up. The next one puts it down.
var toast: Control

var _ui_scale: float
## The window y the fight's top column ends at, which the banner hangs under.
var _top: Callable
## Whether a pop-up stands over the window: a banner raised then would lie over its title, so it waits.
var _waits: Callable
## Seconds until the banner may go.
var _left := 0.0
## `raise`'s four arguments for the latest banner raised under a pop-up; empty with none waiting.
var _held: Array = []


func _init(ui_scale: float, top: Callable, waits: Callable) -> void:
	_ui_scale = ui_scale
	_top = top
	_waits = waits


## Every frame: a waiting banner goes up once the window is clear, and one whose time is up goes.
func tick(delta: float) -> void:
	if not _held.is_empty() and not _waits.call():
		var held := _held
		_held = []
		raise(held[0], held[1], held[2], held[3])
	if panel != null:
		_left -= delta
		if _left <= 0.0 and not Cursors.touched and not over(get_viewport().get_mouse_position()):
			close()


## Every event, before the interface has it: a press off a banner whose time is up puts it down, and
## still lands on whatever it was for.
func press(event: InputEvent) -> void:
	if _left <= 0.0 and event is InputEventMouseButton and event.pressed and not over(event.position):
		close()


## Whether `at` (window pixels) is on the banner.
func over(at: Vector2) -> bool:
	return panel != null and panel.get_global_rect().has_point(at)


## A unique the log has never held: its name, rarity line and rule, and none of its numbers, since a
## banner is read at a glance mid-fight and the tables are the bag's.
func unique(item: Item) -> void:
	var lines: Array[Control] = [
		ItemDetails.line(item.display_name(), item.text_color(), WIDTH),
		ItemDetails.line("%s · Level %d" % [item.rarity_label(), item.level], Palette.TEXT_SOFT, WIDTH, true),
		ItemDetails.line(item.effect_text(), Palette.SLOT_TAN_DK, WIDTH, true),
	]
	if not item.peak_text().is_empty():
		lines.append(ItemDetails.line(item.peak_text(), Palette.SLOT_TAN_DK, WIDTH, true))
	raise("Unique found", item.text_color(), _square(item), lines)


## A bounty filled, to be claimed at `town`. For an elite or a boss the filling kill is the only kill,
## so the banner carries the toast's weight: the picture framed, the count behind the tier's mark.
func bounty(enemy: String, tier: EnemyRoster.Tier, have: int, need: int, town: String) -> void:
	var colour := _bounty_colour(tier)
	var lines: Array[Control] = [ItemDetails.line(enemy, colour, WIDTH)]
	var count := "%d of %d" % [have, need]
	if tier == EnemyRoster.Tier.COMMON:
		lines.append(ItemDetails.line(count, Palette.TEXT_SOFT, WIDTH, true))
	else:
		var row := _row(4)
		row.add_child(_tier_mark(tier))
		row.add_child(UITheme.label(count, colour))
		lines.append(row)
	lines.append(ItemDetails.line("Claim it at %s." % town, Palette.LEAF, WIDTH, true))
	raise("Bounty filled", colour, _bounty_face(enemy, tier, true), lines)


## Achievements earned or climbed: the first one's unique in the square, and for each what was done and
## what it did, "Unlocks" the unique at rank I and past it the unique's rule at its new numbers.
func achievements(ids: Array[String], inventory: Inventory) -> void:
	var piece := CollectionPage.specimen(ids[0])
	var lines: Array[Control] = []
	for id: String in ids:
		var rank := Achievements.rank(inventory, id)
		var named := str(Achievements.ACHIEVEMENTS[id]["name"])
		var gear := str(UniqueTable.UNIQUES[id]["name"])
		lines.append(ItemDetails.line(named if rank <= 1 else "%s %s" % [named, Achievements.RANK_NAMES[rank]],
				Palette.TEXT, WIDTH))
		lines.append(ItemDetails.line(Achievements.text(id, rank), Palette.SLOT_TAN_DK, WIDTH, true))
		if rank <= 1:
			lines.append(ItemDetails.line("Unlocks %s" % gear, Palette.TEXT_SOFT, WIDTH, true))
		else:
			lines.append(ItemDetails.line("Strengthens %s" % gear, Palette.TEXT_SOFT, WIDTH, true))
			lines.append(ItemDetails.line(UniqueTable.effect_text(id, rank), Palette.SLOT_TAN_DK, WIDTH, true))
			if rank >= UniqueTable.PEAK:
				lines.append(ItemDetails.line(UniqueTable.peak_text(id), Palette.SLOT_TAN_DK, WIDTH, true))
	var title := "%d Achievements" % ids.size()
	if ids.size() == 1:
		title = "Achievement" if Achievements.rank(inventory, ids[0]) <= 1 else "Rank up"
	raise(title, piece.text_color(), _square(piece), lines)


## A counted kill short of filling the bounty: "+1" beside the monster's picture, up for a moment. The
## latest wins, and there is none at `Anim.NONE` (the journal carries the count). `too_low` is the level
## a posting wants when the body fell on shallower land and did not count, said in brick instead.
func toast_bounty(enemy: String, tier: EnemyRoster.Tier, too_low := 0) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	if toast != null:
		toast.queue_free()
	var card := _card()
	var row := _row()
	card.add_child(row)
	var big := tier != EnemyRoster.Tier.COMMON
	row.add_child(_bounty_face(enemy, tier, big))
	if too_low > 0:
		var words := UITheme.vbox(0)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_child(UITheme.label("Level too low", Palette.BRICK))
		words.add_child(UITheme.label("Needs level %d or higher" % too_low, Palette.TEXT_SOFT, true))
		row.add_child(words)
	else:
		if big:
			row.add_child(_tier_mark(tier))
		var count := UITheme.label("+1", _bounty_colour(tier))
		if big:
			count.add_theme_font_size_override("font_size", FightHud.BOSS_FONT)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
	get_parent().add_child(card)
	toast = card
	# Twice, as the banner is: the labels have not laid out on the first pass.
	_place_toast()
	_place_toast.call_deferred()
	if Settings.animations == Settings.Anim.DEFAULT:
		_spring(card)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "position:y", card.position.y - TOAST_RISE, TOAST_TIME)
	tween.tween_property(card, "modulate:a", 0.0, 0.4).set_delay(TOAST_TIME - 0.4)
	tween.chain().tween_callback(card.queue_free)


## A level gained: the window washes warm and the words pop up over the middle and float away.
func level_up(level: int) -> void:
	Juice.sound(LEVEL_UP_SOUND)
	if Settings.animations == Settings.Anim.NONE:
		return
	_wash()
	var label := Label.new()
	label.theme = UITheme.theme()
	label.theme_type_variation = "PanelLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "Level %d!" % level
	label.add_theme_font_size_override("font_size", LEVEL_UP_FONT)
	label.add_theme_color_override("font_color", Palette.GOLD)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	get_parent().add_child(label)
	var view_size := get_viewport().get_visible_rect().size
	var text := label.get_combined_minimum_size()
	label.pivot_offset = text / 2.0
	label.position = (view_size - text) / 2.0 - Vector2(0, view_size.y * 0.15)
	label.scale = Vector2.ONE * 3.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE * 2.0, 0.25).set_trans(
			Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 30.0, LEVEL_UP_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(LEVEL_UP_TIME - 0.4)
	tween.chain().tween_callback(label.queue_free)


## `square` beside `lines` under a heading, on the cards' cream, its X up at once. Under a pop-up it
## waits instead, and the latest one waiting goes up once the window is clear (`tick`).
func raise(title: String, colour: Color, square: Control, lines: Array[Control]) -> void:
	if _waits.call():
		if not _held.is_empty():
			(_held[2] as Control).queue_free()
			for line: Control in _held[3]:
				line.queue_free()
		_held = [title, colour, square, lines]
		return
	close()
	# The banner says more than the toast before it did, and stands where it stood.
	if toast != null:
		toast.queue_free()
	if Settings.animations == Settings.Anim.DEFAULT:
		# Added before the card, so it washes the fight behind it and not the words.
		_wash()
	var card := _card()
	var body := UITheme.vbox(4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	head = _row()
	body.add_child(head)
	var heading := UITheme.label(title, colour)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var shut := UITheme.button("", "CloseButton", "Close")
	shut.custom_minimum_size = Vector2(UITheme.icon_size("CloseButton"))
	shut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shut.pressed.connect(close)
	head.add_child(shut)
	var row := _row()
	body.add_child(row)
	square.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(square)
	var rows := UITheme.vbox(2, WIDTH)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rows)
	for line: Control in lines:
		rows.add_child(line)
	get_parent().add_child(card)
	panel = card
	# Placed now, again once the labels have laid out (with the sparks thrown from where it actually
	# landed) and again whenever it settles at another size.
	card.resized.connect(_place)
	_place()
	_place.call_deferred(Settings.animations == Settings.Anim.DEFAULT)
	if Settings.animations != Settings.Anim.NONE:
		_spring(card)
	_left = HOLD


## The one way a banner goes down: its timer, its X, a press off it once its time is up, another banner.
func close() -> void:
	if panel == null:
		return
	var card := panel
	panel = null
	head = null
	if Settings.animations == Settings.Anim.NONE:
		card.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, FADE)
	tween.tween_callback(card.queue_free)


## The banner and the toast both put down: what a camp's pay announced goes with its screen.
func drop() -> void:
	close()
	if toast != null:
		toast.queue_free()


## Under the fight's top column, the one thing the banner must not cover. `spark` throws the puff of
## gold, and only the deferred first placing passes it, so it is never thrown twice.
func _place(spark := false) -> void:
	if panel == null:
		return
	var corner := _hang(panel, _top.call() + GAP)
	if spark:
		Juice.burst(get_parent(), corner + panel.size * _ui_scale / 2.0, Palette.GOLD, 28, 220.0, 3.0, 0.7)


## Under the fight's column, or under the banner when one is up, so the two never overlap.
func _place_toast() -> void:
	if toast == null:
		return
	var top: float = _top.call() + GAP
	if panel != null:
		top = panel.position.y + panel.get_combined_minimum_size().y * _ui_scale + GAP
	_hang(toast, top)


## `card` centred across the window with its top at `top`, and where its corner lands. It springs in
## about its middle, so that is its pivot, and a scaled Control is drawn about its pivot: its corner
## lands `pivot * (scale - 1)` back from `position`.
func _hang(card: Control, top: float) -> Vector2:
	card.size = card.get_combined_minimum_size()
	card.pivot_offset = card.size / 2.0
	var corner := Vector2((get_viewport().get_visible_rect().size.x - card.size.x * _ui_scale) / 2.0, top)
	card.position = corner + card.pivot_offset * (_ui_scale - 1.0)
	return corner


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme = UITheme.theme()
	card.theme_type_variation = "TextPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.scale = Vector2(_ui_scale, _ui_scale)
	return card


func _row(separation := 6) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _spring(card: Control) -> void:
	card.scale = Vector2(_ui_scale, _ui_scale) * 1.4
	create_tween().tween_property(card, "scale", Vector2(_ui_scale, _ui_scale), 0.25).set_trans(
			Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A win's warm wash over the whole window (`Juice.FLASH`).
func _wash() -> void:
	var flash := ColorRect.new()
	flash.color = Juice.FLASH
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child(flash)
	var fade := create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, Juice.FLASH_TIME)
	fade.tween_callback(flash.queue_free)


## A piece as the banner's square. Out of `ItemSlot.GROUP` at once, or the one `ItemCard` finds it
## under the cursor and stands its own card over the banner.
func _square(item: Item) -> ItemSlot:
	var slot := ItemSlot.make(item)
	slot.remove_from_group(ItemSlot.GROUP)
	return slot


func _bounty_face(enemy: String, tier: EnemyRoster.Tier, big: bool) -> Control:
	var frame: Texture2D = null
	if BOUNTY_TIER.has(tier):
		# A boss wears the unique's frame at its fullest crest.
		frame = ItemRarity.frame(BOUNTY_TIER[tier]["frame"], UniqueTable.PEAK)
	return BountyList.portrait_box(enemy, TOAST_BIG_PORTRAIT if big else TOAST_PORTRAIT, frame)


func _bounty_colour(tier: EnemyRoster.Tier) -> Color:
	return BOUNTY_TIER[tier]["colour"] if BOUNTY_TIER.has(tier) else Palette.TEXT


## The nameplate's mark for the tier (`FightHud.TIER_MARK`): a bone skull, or a gilded crown at twice the size.
func _tier_mark(tier: EnemyRoster.Tier) -> TextureRect:
	var boss := tier == EnemyRoster.Tier.BOSS
	var texture: Texture2D = FightHud.TIER_MARK[tier]
	var mark := BountyList.icon(texture, texture.get_width() * (2 if boss else 1))
	mark.modulate = Palette.GOLD if boss else Color.WHITE
	return mark
