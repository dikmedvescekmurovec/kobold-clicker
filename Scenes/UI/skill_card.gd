class_name SkillCard
extends PanelContainer
## What a skill does, shown while the cursor is over it: its name, what one point buys, what the points
## in it add up to, and whether another can go in.
##
## Not a Godot tooltip, for OrbCard's reason -- see the gotcha in CLAUDE.md. The item card's cream
## page and the same three kinds of line, so every card reads as one kind of thing.

const WIDTH := OrbCard.WIDTH

var _rows: VBoxContainer


func _init() -> void:
	theme_type_variation = "TextPanel"
	UITheme.notched(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Fills the card for skill `id`, for a player whose learned skills are `skills` at `level`. `worth`
## is what a point counts for (`Inventory.skill_worth`: two under Hard Lessons), so the card says what
## the fight will be armed with.
func fill(id: String, skills: Skills, level: int, worth := 1.0, refused: Variant = null) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var entry := SkillTree.node(id)
	var rank := skills.rank_of(id)
	var most := int(entry["max_rank"])
	_rows.add_child(ItemDetails.line(str(entry["name"]), Palette.TEXT, WIDTH))
	_rows.add_child(ItemDetails.line("Per point: " + SkillTree.describe(id, worth), Palette.TEXT_SOFT, WIDTH, true))
	if entry.has("effect_text"):
		_rows.add_child(ItemDetails.line(str(entry["effect_text"]), Palette.SLOT_TAN_DK, WIDTH, true))
	if rank > 0:
		_rows.add_child(ItemDetails.line("Now: " + SkillTree.describe(id, rank * worth), Palette.LEAF, WIDTH, true))
	# `refused` is whoever owns the skills saying why not, where there is more to it than the trees'
	# own rules (`Inventory.why_not_skill`: the Specialist's one tree).
	var refusal: String = skills.why_not(id, level) if refused == null else str(refused)
	var cost := SkillTree.rank_cost(id, rank)
	var status := "Click to learn (%d/%d)" % [rank, most]
	if cost > 1:
		status = "Click to learn for %d points (%d/%d)" % [cost, rank, most]
	var tone := Palette.LEAF
	if refusal == SkillTree.FULL:
		status = refusal
		# Not gold: at 10 px on cream it cannot be read, which is why a unique's sentence is this too.
		tone = Palette.SLOT_TAN_DK
	elif not refusal.is_empty():
		status = refusal
		tone = Palette.RUST
	_rows.add_child(ItemDetails.line(status, tone, WIDTH, true))
	reset_size()
