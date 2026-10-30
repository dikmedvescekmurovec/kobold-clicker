class_name OrbCard
extends PanelContainer
## The floating card for the orb under the cursor: its name, what it does, and one more line where there
## is something to say (`fill`). An ordinary Control scaled and placed by whoever owns it, never Godot's
## tooltip (Scenes/UI/CLAUDE.md: "Never make a floating card a Godot tooltip").

## Where a line wraps, in panel pixels: the width of every floating block of text (`ItemCard.WIDTH`,
## `DropsView.INSPECT_WIDTH`).
const WIDTH := 150.0

var _rows: VBoxContainer


func _init() -> void:
	theme_type_variation = "TextPanel"
	UITheme.notched(self)
	# It stands by the cursor and must never take the press meant for the square it describes.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = UITheme.vbox(2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Fills the card for one orb or rune. `held` is how many the player has. `note`, where given, is the third line: a vendor's price, or why it cannot be had
## (`TownPage`).
func fill(orb: String, held: int, note := "", note_tone := Palette.TEXT_SOFT) -> void:
	UITheme.clear(_rows)
	_rows.add_child(ItemDetails.line(orb, Palette.TEXT, WIDTH))
	var does := str(RuneTable.RUNES[orb]["does"]) if RuneTable.has(orb) else OrbTable.describe(orb)
	_rows.add_child(ItemDetails.line(does, Palette.TEXT_SOFT, WIDTH, true))
	if not note.is_empty():
		_rows.add_child(ItemDetails.line(note, note_tone, WIDTH, true))
	elif held <= 0:
		# A faded icon cannot say whether the orb was spent or never found. With any held there is nothing
		# to add: the count is on the square, and an orb is only picked up, never spent on the open piece.
		_rows.add_child(ItemDetails.line("Not found yet",
				Palette.SLOT_TAN_DK, WIDTH, true))
	# Sized now, not a frame later, so whoever places the card has a size to place.
	reset_size()
