class_name SkillCard
extends PanelContainer
## What a skill does, shown while the cursor is over it: its name, what one point buys, what the points
## in it add up to, and whether another can go in.
##
## Not a Godot tooltip, for OrbCard's reason -- see the gotcha in CLAUDE.md. The same wood page and the
## same three kinds of line, so the two cards read as one kind of thing.

const WIDTH := OrbCard.WIDTH

var _rows: VBoxContainer


func _init() -> void:
	theme_type_variation = "WoodPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Fills the card for skill `id`, for a player whose learned skills are `skills` at `level`.
func fill(id: String, skills: Skills, level: int) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var entry := SkillTree.node(id)
	var rank := skills.rank_of(id)
	var most := int(entry["max_rank"])
	_rows.add_child(ItemDetails.line(str(entry["name"]), Palette.BONE, WIDTH))
	_rows.add_child(ItemDetails.line("Per point: " + SkillTree.describe(id), Palette.PANEL_CREAM, WIDTH))
	if entry.has("effect_text"):
		_rows.add_child(ItemDetails.line(str(entry["effect_text"]), Palette.GOLD, WIDTH))
	if rank > 0:
		_rows.add_child(ItemDetails.line("Now: " + SkillTree.describe(id, rank), Palette.LEAF_LT, WIDTH))
	var refusal := skills.why_not(id, level)
	var status := "Click to learn (%d/%d)" % [rank, most]
	var tone := Palette.LEAF_LT
	if rank >= most:
		status = "Fully learned"
		tone = Palette.GOLD
	elif not refusal.is_empty():
		status = refusal
		tone = Palette.RUST
	_rows.add_child(ItemDetails.line(status, tone, WIDTH))
	reset_size()
