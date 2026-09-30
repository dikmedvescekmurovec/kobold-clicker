class_name CampScene
extends CanvasLayer
## Draws a camp: the tile's own arena at night with nobody on it, and a panel saying what the hero
## drove off there while the game was shut. Shown at start-up, already paid.
##
## It is deliberately the fight's screen without the fight. Camping is the same ground and the same
## monsters as farming it -- the player is *there* -- so the way in is the way into a fight, the
## backdrop is the tile's own, and the map is put away behind it. What is missing is the whole
## point: no hero on the left, no enemies walking in from the right, nothing to click. A player who
## sees this screen knows at a glance both where they are and that nothing needs them.
##
## It owns no rules: `Camp` says what the hours were worth and this shows it.
## A CanvasLayer for `CombatScene`'s reason -- the map stays loaded behind it.

## Break camp: go back to the map. The one way out.
signal broke_camp

## The layer a fight is drawn on, so a camp stands exactly where a fight would.
const LAYER := 2
## Dusk over the tile's own backdrop: a camp is what the hours away look like.
const NIGHT := Color(0.45, 0.52, 0.72)
## A little over the viewport, the way a fight's backdrop is, so no edge can show.
const BACKDROP_BLEED := 1.02
## How wide the panel is, in panel pixels. Fixed, because its one long sentence has no width of its
## own and a panel that sizes itself round a changing number breathes in and out every second.
const WIDTH := 190.0

var _camp := {}
var _earned := {}
var _ui_scale := 2.0
var _panel: VBoxContainer


## Puts the camp on the screen. `camp` is what `Camp.make` built and `earned` what `Camp.earned` said
## it came to; `env` and `variant` are the tile's, for the backdrop it would have fought on.
func begin(camp: Dictionary, earned: Dictionary, env: String, variant: String, scale: float) -> void:
	_camp = camp
	_earned = earned
	_ui_scale = scale
	layer = LAYER
	# Nothing here is clicked for damage, so the cursor is the one every other panel wears.
	Input.set_default_cursor_shape(Cursors.ARROW)
	_build(env, variant)
	get_viewport().size_changed.connect(_layout)


func _build(env: String, variant: String) -> void:
	var art := CombatScene.backdrop_for(env, variant,
			CombatScene.layout_for(Camp.cell_of(_camp)))
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.texture = art
	backdrop.centered = false
	backdrop.modulate = NIGHT
	add_child(backdrop)

	_panel = UITheme.titled_panel("Camp", "Go back to the map", _on_break_pressed)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)

	var place := UITheme.label(str(_camp.get(Camp.PLACE, "")), Palette.GOLD)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(place)
	var told := UITheme.label("While you were away, your hero camped on the best ground taken so "
			+ "far. A camp brings back coin and what the fighting taught, and nothing that can be carried.",
			null, true)
	told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	told.custom_minimum_size.x = WIDTH
	rows.add_child(told)
	rows.add_child(UITheme.rule(WIDTH))

	var table := UITheme.vbox(0, WIDTH)
	rows.add_child(table)
	var striped := false
	for named in [["Resting", Camp.spell_time(float(_earned["seconds"]))],
			["Kills", str(int(_earned[Camp.KILLS]))],
			["Gold", BigNumber.format(float(_earned[Camp.GOLD]))],
			["Experience", str(int(_earned[Camp.XP]))]]:
		table.add_child(UITheme.table_row(str(named[0]), str(named[1]), striped,
				0.0, null, Palette.GOLD if named[0] == "Gold" else null))
		striped = not striped

	# Only where the cap is what stopped it, so a player back after a week is told why rather than
	# left to wonder what went missing.
	if bool(_earned["full"]):
		var capped := UITheme.label("A hero can hold a camp for %d hours before rest is needed."
				% int(float(_camp.get(Camp.MOST, Camp.MAX_SECONDS)) / 3600.0), Palette.STONE_LT, true)
		capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		capped.custom_minimum_size.x = WIDTH
		rows.add_child(capped)

	# At the panel's foot, where every button in the game stands.
	var buttons := UITheme.vbox(4)
	buttons.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	rows.add_child(buttons)
	var leave := UITheme.button("Break camp", "LightButton", "Go back to the map")
	leave.pressed.connect(_on_break_pressed)
	Cursors.wear(leave, Cursors.BOOT)
	buttons.add_child(leave)

	_layout.call_deferred()


func _layout() -> void:
	var size := Vector2(get_viewport().get_visible_rect().size)
	var backdrop: Sprite2D = get_node("Backdrop")
	var art := backdrop.texture.get_size()
	var cover := maxf(size.x / art.x, size.y / art.y) * BACKDROP_BLEED
	backdrop.scale = Vector2(cover, cover)
	backdrop.position = (size - art * cover) / 2.0
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (size - _panel.size * _ui_scale) / 2.0


func _on_break_pressed() -> void:
	broke_camp.emit()
