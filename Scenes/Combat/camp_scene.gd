class_name CampScene
extends CanvasLayer
## Draws a camp: the tile's own arena at night with nobody on it, and a panel saying what the hero
## has driven off while resting there.
##
## It is deliberately the fight's screen without the fight. Camping is the same ground and the same
## monsters as farming it -- the player is *there* -- so the way in is the way into a fight, the
## backdrop is the tile's own, and the map is put away behind it. What is missing is the whole
## point: no hero on the left, no enemies walking in from the right, nothing to click. A player who
## sees this screen knows at a glance both where they are and that nothing needs them.
##
## It owns no rules: `Camp` says what the hours are worth and this reads it once a second.
## A CanvasLayer for `CombatScene`'s reason -- the map stays loaded behind it.

## Break camp: take what the rest earned and go back to the map. The one way out.
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
var _ui_scale := 2.0
var _rows := {}
var _capped: Label
var _panel: VBoxContainer
## Once a second is as often as a figure in whole seconds can change.
var _since := 1.0


## Puts the camp on the screen. `camp` is the drawer `Camp.make` built, `env` and `variant` are the
## tile's, for the backdrop it would have fought on.
func begin(camp: Dictionary, env: String, variant: String, scale: float) -> void:
	_camp = camp
	_ui_scale = scale
	layer = LAYER
	# Nothing here is clicked for damage, so the cursor is the one every other panel wears.
	Input.set_default_cursor_shape(Cursors.ARROW)
	_build(env, variant)
	get_viewport().size_changed.connect(_layout)
	_refresh()


func _build(env: String, variant: String) -> void:
	var art := CombatScene.backdrop_for(env, variant,
			CombatScene.layout_for(Camp.cell_of(_camp)))
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.texture = art
	backdrop.centered = false
	backdrop.modulate = NIGHT
	add_child(backdrop)

	_panel = UITheme.titled_panel("Camp", "Break camp and go back to the map", _on_break_pressed)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)

	var place := UITheme.label(str(_camp.get(Camp.PLACE, "")), Palette.GOLD)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(place)
	var told := UITheme.label("Your hero rests here, fighting off the occasional monster. A camp "
			+ "brings back coin and what the fighting taught, and nothing that can be carried.",
			null, true)
	told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	told.custom_minimum_size.x = WIDTH
	rows.add_child(told)
	rows.add_child(UITheme.rule(WIDTH))

	var table := UITheme.vbox(0, WIDTH)
	rows.add_child(table)
	var striped := false
	for named in [["Resting", "seconds"], ["Driven off", Camp.KILLS], ["Gold", Camp.GOLD],
			["Experience", Camp.XP]]:
		var row := UITheme.table_row(str(named[0]), "", striped,
				0.0, null, Palette.GOLD if named[1] == Camp.GOLD else null)
		table.add_child(row)
		_rows[named[1]] = row.find_child(UITheme.TABLE_VALUE, true, false)
		striped = not striped

	# Shown only once the cap is what is holding the numbers still, so a player back after a week is
	# told why rather than left to wonder what went missing.
	_capped = UITheme.label("A hero can hold a camp for %d hours before rest is needed."
			% int(Camp.MAX_SECONDS / 3600.0), Palette.STONE_LT, true)
	_capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capped.custom_minimum_size.x = WIDTH
	_capped.hide()
	rows.add_child(_capped)

	# At the panel's foot, where every button in the game stands.
	var buttons := UITheme.vbox(4)
	buttons.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	rows.add_child(buttons)
	var leave := UITheme.button("Break camp", "LightButton",
			"Take what the rest earned and go back to the map")
	leave.pressed.connect(_on_break_pressed)
	Cursors.wear(leave, Cursors.BOOT)
	buttons.add_child(leave)

	_layout.call_deferred()


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0:
		return
	_since = 0.0
	_refresh()


## What the camp has earned by now, in the panel. The same sum the way out pays, asked of the same
## place, so the screen can never say one thing and the purse take another.
func _refresh() -> void:
	var earned := Camp.earned(_camp, Time.get_unix_time_from_system())
	_rows["seconds"].text = Camp.spell_time(float(earned["seconds"]))
	_rows[Camp.KILLS].text = str(int(earned[Camp.KILLS]))
	_rows[Camp.GOLD].text = BigNumber.format(float(earned[Camp.GOLD]))
	_rows[Camp.XP].text = str(int(earned[Camp.XP]))
	_capped.visible = bool(earned["full"])


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
