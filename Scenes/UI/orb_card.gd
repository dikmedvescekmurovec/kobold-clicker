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
## own CanvasLayer, scaled by `ui_scale` and placed by the scene, exactly as CombatScene's toasts and
## its full-bag warning are placed, and for exactly the same reason.
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
	theme_type_variation = "WoodPanel"
	# It follows the cursor, so it must never be under it: a card that took the mouse would take the
	# press meant for the square it is describing.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Fills the card for one orb. `held` is how many the player has, and `against` is the piece the bag
## has open -- null when none is, which is the tray at rest and the case where there is nothing to
## refuse.
##
## Bone for the name and cream for the sentence: the card stands on the pack's wood page, and the
## darker half of the palette was picked to be read on the white one.
func fill(orb: String, held: int, against: Item) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(ItemDetails.line(orb, Palette.BONE, WIDTH))
	_rows.add_child(ItemDetails.line(OrbTable.describe(orb), Palette.PANEL_CREAM, WIDTH))
	var status := ""
	var tone := Palette.PANEL_CREAM
	if held <= 0:
		# Said plainly rather than left to the faded icon. A ghost says "not here"; only a word says
		# whether that is because it was spent or because it has never been found.
		status = "Not found yet"
		tone = Palette.STONE_LT
	elif against == null:
		status = "You hold %d" % held
	elif OrbTable.can_apply(orb, against):
		status = "Use on %s" % against.display_name()
		tone = Palette.LEAF_LT
	else:
		status = OrbTable.why_not(orb, against)
		tone = Palette.RUST
	_rows.add_child(ItemDetails.line(status, tone, WIDTH))
	# The card is measured the frame after it is filled, so whoever places it has a size to place.
	reset_size()
