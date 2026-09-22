class_name OrbCard
extends PanelContainer
## What an orb is, shown while the cursor is over it: its name, what it does, and where the player
## stands with it -- how many they hold, or why it is greyed out against the piece they have open.
##
## It is not Godot's tooltip, and that is a decision rather than an oversight.
##
## A tooltip is its own popup window. It cannot inherit the bag panel's `ui_scale` transform, so the
## only way to make it match the panel beside it would be to ask for type at `FONT_SIZE * ui_scale`
## -- and Pixellari renders cleanly only at its native 16. A tooltip asked for 32 px type comes back
## interpolated, sitting next to art that is not. So the card is an ordinary Control on the bag's
## own CanvasLayer, scaled by `ui_scale` and placed by the scene, exactly as CombatScene's full-bag
## warning is placed, and for exactly the same reason.
##
## Three lines, and the third is the one worth having. A player who can see that an orb is grey does
## not need to be told it is grey; they need to be told what would have to be true for it not to be,
## and OrbTable.why_not is where that sentence lives.

## How wide the card runs before its lines wrap. DropsView.INSPECT_WIDTH, which is what the game
## already uses for a block of text that floats rather than one that fills a panel -- narrow enough
## to place anywhere, wide enough that a sentence is three lines and not seven.
const WIDTH := 150.0

var _rows: VBoxContainer


func _init() -> void:
	theme_type_variation = "TextPanel"
	UITheme.notched(self)
	# It follows the cursor, so it must never be under it: a card that took the mouse would take the
	# press meant for the square it is describing.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Fills the card for one orb. `held` is how many the player has, and `against` is the piece the bag
## has open -- null when none is, which is the tray at rest and the case where there is nothing to
## refuse. `sell_for` is what a vendor beside the bag pays for one, and 0 everywhere else.
##
## Ink for the name and slate for the sentence: the card stands on the item card's cream page, which
## the darker half of the palette was picked to be read on.
func fill(orb: String, held: int, against: Item, sell_for := 0.0) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(ItemDetails.line(orb, Palette.TEXT, WIDTH))
	# A super orb (`SuperOrbTable`) is the same card over another table; `held` is the one count the
	# six of them share, and it is never armed, so with nothing open it says to open something.
	var is_super := SuperOrbTable.has(orb)
	_rows.add_child(ItemDetails.line(SuperOrbTable.describe(orb) if is_super else OrbTable.describe(orb),
			Palette.TEXT_SOFT, WIDTH, true))
	var status := ""
	var tone := Palette.TEXT_SOFT
	if held <= 0:
		# Said plainly rather than left to the faded icon. A ghost says "not here"; only a word says
		# whether that is because it was spent or because it has never been found.
		status = "None left to spend" if is_super else "Not found yet"
		tone = Palette.SLOT_TAN_DK
	elif is_super:
		var fits := SuperOrbTable.can_apply(orb, against)
		status = ("Open an heirloom, then press this" if against == null
				else "Use on %s" % against.display_name() if fits else SuperOrbTable.why_not(orb, against))
		tone = Palette.TEXT_SOFT if against == null else Palette.LEAF if fits else Palette.RUST
	elif against == null and sell_for > 0.0:
		# What the square does now, rather than what is in it: with a vendor beside the bag and no piece
		# open, pressing it is a sale and the price is the one thing the player needs before they press.
		status = "Sell for %s" % BigNumber.format(sell_for)
		tone = Palette.LEAF
	elif against == null:
		# And how it is used from here, since nothing else on the page says a held orb can be picked up.
		status = "You hold %d. Press it, then the piece to use it on" % held
	elif OrbTable.can_apply(orb, against):
		status = "Use on %s" % against.display_name()
		tone = Palette.LEAF
	else:
		status = OrbTable.why_not(orb, against)
		tone = Palette.RUST
	_rows.add_child(ItemDetails.line(status, tone, WIDTH, true))
	# The card is measured the frame after it is filled, so whoever places it has a size to place.
	reset_size()
