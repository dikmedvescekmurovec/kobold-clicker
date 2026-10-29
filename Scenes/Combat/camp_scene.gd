class_name CampScene
extends CanvasLayer
## Draws a camp, shown at start-up and already paid: deliberately the fight's screen without the fight
## -- the tile's own backdrop at night with nobody on it, nothing to click -- and a panel saying what
## the hours came to. It owns no rules: `Camp` says what the hours were worth. A CanvasLayer for
## `CombatScene`'s reason: the map stays loaded behind it.

## Break camp: back to the map. The one way out.
signal broke_camp

## The layer a fight is drawn on.
const LAYER := 2
## Night, whatever the clock says.
const SKY := "night"
## A little over the viewport, as a fight's backdrop is, so no edge can show.
const BACKDROP_BLEED := 1.02
## The panel's width, in panel pixels. Fixed: the cap's sentence has no width of its own, and a
## panel sized round a changing number breathes in and out.
const WIDTH := 190.0
## The least the panel keeps clear of the window's top and foot, in panel pixels, as a verdict does.
const GAP := 4.0

var _camp := {}
var _earned := {}
var _finds: Array[Item] = []
var _orbs := {}
var _left := 0
var _ui_scale := 2.0
var _panel: VBoxContainer
## What the camp's bodies dropped, or null where they dropped nothing that was kept.
var _drops: DropsView
## The backdrop's layers, back to front, which `_layout` fits to the window.
var _backdrop: Node2D


## `camp` is what `Camp.make` built and `earned` what `Camp.earned` said it came to; `env` and `variant`
## are the tile's, for the backdrop it would have fought on. `finds` and `orbs` (kind -> count) are
## what its bodies dropped and the player's rule kept, already in the bag, and `left` how many finds
## that rule left behind.
func begin(camp: Dictionary, earned: Dictionary, env: String, variant: String, ui_scale: float,
		finds: Array[Item] = [], orbs := {}, left := 0) -> void:
	_camp = camp
	_earned = earned
	_finds = finds
	_orbs = orbs
	_left = left
	_ui_scale = ui_scale
	layer = LAYER
	# Nothing here is clicked for damage.
	Input.set_default_cursor_shape(Cursors.ARROW)
	_build(env, variant)
	get_viewport().size_changed.connect(_layout)


func _build(env: String, variant: String) -> void:
	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	var layers := CombatScene.backdrop_layers(env, variant,
			CombatScene.layout_for(Camp.cell_of(_camp)), SKY)
	for i in layers.size():
		var sprite := CombatScene.layer_sprite(layers[i][0])
		# The night's light falls on everything but the sky.
		sprite.modulate = CombatScene.SKY_LIGHT[SKY] if i > 0 else Color.WHITE
		_backdrop.add_child(sprite)

	_panel = UITheme.titled_panel("Camp", "Go back to the map", _on_break_pressed)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)

	var place := UITheme.label(str(_camp.get(Camp.PLACE, "")), Palette.GOLD_TEXT)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(place)
	rows.add_child(UITheme.rule(WIDTH))

	var table := UITheme.vbox(0, WIDTH)
	rows.add_child(table)
	var striped := false
	for named in [["Resting", Camp.spell_time(float(_earned["seconds"]))],
			["Kills", str(int(_earned[Camp.KILLS]))],
			["Gold", BigNumber.format(float(_earned[Camp.GOLD]))],
			["Experience", str(int(_earned[Camp.XP]))]]:
		table.add_child(UITheme.table_row(str(named[0]), str(named[1]), striped,
				0.0, null, Palette.GOLD_TEXT if named[0] == "Gold" else null))
		striped = not striped

	# The finds as the verdict of a fight shows them, a record only: they are in the bag already.
	if not _finds.is_empty() or not _orbs.is_empty():
		_drops = DropsView.new()
		# A frame on, once the panel knows what an opened find made of its height.
		_drops.resized_contents.connect(_layout, CONNECT_DEFERRED)
		rows.add_child(_drops)
		_drops.fill(_finds, _orbs)
	if _left > 0:
		var behind := UITheme.label("1 item discarded automatically" if _left == 1
				else "%d items discarded automatically" % _left, Palette.TEXT_SOFT, true)
		behind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(behind)

	# Only where the cap is what stopped it: a player back after a week is told why the sum looks short.
	# One line: with finds, their orbs and the footnote over it, a second ran the panel off a 648 px window.
	if bool(_earned["full"]):
		var capped := UITheme.label("A hero can hold a camp for %s."
				% Camp.spell_time(float(_earned["seconds"])), Palette.TEXT_SOFT, true)
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
	for sprite in _backdrop.get_children():
		CombatScene.fit_layer(sprite, size, BACKDROP_BLEED)
	# A panel taller than the window gives up rows of its finds, which then scroll (`FightHud._fit_window`).
	var over := _panel.get_combined_minimum_size().y - (size.y / _ui_scale - 2.0 * GAP)
	if over > 0.0 and _drops != null:
		_drops.fit_rows(over)
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (size - _panel.size * _ui_scale) / 2.0


func _on_break_pressed() -> void:
	broke_camp.emit()
