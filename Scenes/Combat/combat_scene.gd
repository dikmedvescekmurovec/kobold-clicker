class_name CombatScene
extends CanvasLayer
## Draws one Encounter: the player on the left, the tile's enemies walking in one at a time from the
## right, and a click doing a point of damage to whichever is standing there.
##
## Everything below the HUD is built in code, so the .tscn stays a stub the editor can hold open --
## the same convention as main_scene._build_ui and HexMap._ready. The scene owns no rules: it asks
## the Encounter what is happening and shows it.
##
## It is a CanvasLayer rather than a scene of its own, so the main scene can put a fight in front of
## the map without unloading it. The map holds a whole generated world in memory that a scene change
## would throw away.

## The fight is over. `won` says whether the tile was taken.
signal finished(won: bool)

## Where the fighters stand, as a share of the viewport: the grass band of the backdrop.
const GROUND := 0.86
const PLAYER_X := 0.24
const ENEMY_X := 0.72
## How tall an ordinary fighter stands, as a share of the viewport height. Sheets vary wildly (a
## slime frame is 32x25, a Demon Boss 162x148), so nobody is drawn at their sheet's scale -- they are
## drawn at the size the roster says their body is.
const ACTOR_HEIGHT := 0.33
## What each Size band is worth against that, so a slime is knee-high and a boss looms.
const SIZE_HEIGHT := {
	EnemyRoster.Size.TINY: 0.45,
	EnemyRoster.Size.SMALL: 0.80,
	EnemyRoster.Size.MEDIUM: 1.00,
	EnemyRoster.Size.LARGE: 1.25,
	EnemyRoster.Size.HUGE: 1.55,
}
## The elite at the end stands a little taller than its body alone would, so it reads as the wall it is.
const ELITE_SCALE := 1.15
## Where an enemy starts its run-in, past the right edge.
const OFFSCREEN_X := 1.15
const BACKDROP := preload("res://Assets/Area/Summer2.png")
const ATTACK_SOUND := preload("res://Assets/Player/attack.mp3")

## The bar behind the enemy's health and the clock, and the two fills.
const BAR_BACK := Color(0.08, 0.07, 0.11, 0.85)
const BAR_HEALTH := Color("c4453a")
const BAR_TIME := Color("6fa84a")
## The clock turns red once this little is left, so running out is never a surprise.
const TIME_WARNING := 10.0

var fight: Encounter
## The cell being fought for, so the main scene knows what was won.
var cell: Vector2i

var _ui_scale := 2.0
var _player: CombatActor
var _enemy: CombatActor
var _sound: AudioStreamPlayer

var _clock_fill: ColorRect
var _clock_label: Label
var _count_label: Label
var _enemy_panel: PanelContainer
var _enemy_label: Label
var _enemy_fill: ColorRect
var _result: PanelContainer
var _result_label: Label


## Starts the fight for `cell`. `ui_scale` matches the map's, so the panels are the same size.
func begin(encounter: Encounter, for_cell: Vector2i, ui_scale: float) -> void:
	fight = encounter
	cell = for_cell
	_ui_scale = ui_scale
	fight.enemy_coming.connect(_on_enemy_coming)
	fight.enemy_spawned.connect(_on_enemy_spawned)
	fight.enemy_hit.connect(_on_enemy_hit)
	fight.enemy_died.connect(_on_enemy_died)
	fight.won.connect(_on_finished.bind(true))
	fight.lost.connect(_on_finished.bind(false))
	_build()
	fight.start()
	_refresh()


func _process(delta: float) -> void:
	if fight == null or fight.finished:
		return
	fight.advance(delta)
	_slide_enemy()
	_refresh()


## A click anywhere in the arena is a swing. The fail state is the clock, so asking the player to
## hit a moving sprite as well would be a second difficulty on top of the one the fight is about.
func _unhandled_input(event: InputEvent) -> void:
	if fight == null or fight.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_player.play_once("attack")
		_sound.play()
		fight.hit()
		_refresh()


func _size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


# ---- building

func _build() -> void:
	var view := _size()
	var arena := Node2D.new()
	arena.name = "Arena"
	add_child(arena)

	var backdrop := Sprite2D.new()
	backdrop.texture = BACKDROP
	backdrop.centered = false
	# Cover the viewport whatever its shape; the grass band stays across the bottom.
	var cover := maxf(view.x / BACKDROP.get_width(), view.y / BACKDROP.get_height())
	backdrop.scale = Vector2(cover, cover)
	backdrop.position = (view - Vector2(BACKDROP.get_size()) * cover) / 2.0
	arena.add_child(backdrop)

	_player = CombatActor.new()
	_player.name = "Player"
	arena.add_child(_player)
	_player.setup_player(view.y * ACTOR_HEIGHT)
	_player.position = Vector2(view.x * PLAYER_X, view.y * GROUND)
	_player.animation_finished.connect(func() -> void: _player.play("idle"))

	_enemy = CombatActor.new()
	_enemy.name = "Enemy"
	arena.add_child(_enemy)

	_sound = AudioStreamPlayer.new()
	_sound.stream = ATTACK_SOUND
	add_child(_sound)

	_build_hud()


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UITheme.theme()
	add_child(hud)

	# Top left: the clock. Top right: how many are left.
	var top := PanelContainer.new()
	top.theme_type_variation = "WoodPanel"
	top.scale = Vector2(_ui_scale, _ui_scale)
	top.position = Vector2(8, 8)
	hud.add_child(top)
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	top.add_child(rows)
	var clock := VBoxContainer.new()
	clock.add_theme_constant_override("separation", 2)
	rows.add_child(clock)
	_clock_label = _label("")
	clock.add_child(_clock_label)
	var clock_bar := _bar(120, 6, BAR_TIME)
	_clock_fill = clock_bar.get_child(0)
	clock.add_child(clock_bar)
	_count_label = _label("")
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rows.add_child(_count_label)

	# Over the enemy: its name and health.
	_enemy_panel = PanelContainer.new()
	_enemy_panel.theme_type_variation = "WoodPanel"
	_enemy_panel.scale = Vector2(_ui_scale, _ui_scale)
	hud.add_child(_enemy_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	_enemy_panel.add_child(stack)
	_enemy_label = _label("")
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_enemy_label)
	var enemy_bar := _bar(120, 6, BAR_HEALTH)
	_enemy_fill = enemy_bar.get_child(0)
	stack.add_child(enemy_bar)

	# The verdict, hidden until there is one.
	_result = PanelContainer.new()
	_result.theme_type_variation = "WoodPanel"
	_result.scale = Vector2(_ui_scale, _ui_scale)
	_result.hide()
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_result)
	var verdict := VBoxContainer.new()
	verdict.add_theme_constant_override("separation", 8)
	_result.add_child(verdict)
	_result_label = _label("")
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_child(_result_label)
	var back := Button.new()
	back.text = "Back to the map"
	back.theme_type_variation = "WoodButton"
	back.pressed.connect(_on_back_pressed)
	verdict.add_child(back)


func _label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	return label


## A track with a fill inside it. The fill is the first child, and its width is set as things change.
## Drawn rather than cut from Assets/bars.png, whose bars come in seven fixed steps in a glossier
## style than the rest of the interface.
func _bar(width: int, height: int, fill: Color) -> Control:
	var track := ColorRect.new()
	track.color = BAR_BACK
	track.custom_minimum_size = Vector2(width, height)
	var bar := ColorRect.new()
	bar.color = fill
	bar.size = Vector2(width, height)
	bar.position = Vector2.ZERO
	track.add_child(bar)
	return track


# ---- drawing what the encounter is doing

## Puts the enemy that is on its way onto the field, off screen and running.
func _on_enemy_coming(_index: int, enemy_name: String, _hp: int) -> void:
	if enemy_name.is_empty():
		_enemy.hide()
		return
	var view := _size()
	_enemy.show()
	var band: float = SIZE_HEIGHT[EnemyRoster.size_of(enemy_name)]
	var elite := ELITE_SCALE if fight.on_elite() else 1.0
	_enemy.setup_enemy(enemy_name, view.y * ACTOR_HEIGHT * band * elite)
	_enemy.position = Vector2(view.x * OFFSCREEN_X, view.y * GROUND)
	_enemy.play("walk")
	_slide_enemy()


## Runs the enemy in over the walk-in, then leaves it standing.
func _slide_enemy() -> void:
	if fight.finished or fight.index >= Encounter.ENEMIES:
		return
	var view := _size()
	var home := view.x * ENEMY_X
	if fight.phase == Encounter.Phase.WALKING_IN:
		var left := fight.phase_left / Encounter.WALK_IN
		_enemy.position.x = lerpf(home, view.x * OFFSCREEN_X, left)
	else:
		_enemy.position.x = home


func _refresh() -> void:
	if fight == null:
		return
	var view := _size()
	var seconds := ceili(fight.time_left)
	_clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_clock_fill.size.x = _clock_fill.get_parent().size.x * (fight.time_left / Encounter.SECONDS)
	_clock_fill.color = BAR_HEALTH if fight.time_left <= TIME_WARNING else BAR_TIME
	_count_label.text = "%d left" % fight.remaining()

	if fight.index >= Encounter.ENEMIES or fight.finished:
		_enemy_panel.hide()
		return
	_enemy_panel.show()
	_enemy_label.text = fight.enemy_name() + ("  (elite)" if fight.on_elite() else "")
	var share := float(fight.hp) / maxi(fight.enemy_max_hp(), 1)
	_enemy_fill.size.x = _enemy_fill.get_parent().size.x * maxf(share, 0.0)
	# Sit the panel over the enemy's head, wherever it has walked to, but never off the screen edge.
	var panel := _enemy_panel.get_combined_minimum_size() * _ui_scale
	_enemy_panel.position = Vector2(
			clampf(_enemy.position.x - panel.x / 2.0, 8.0, view.x - panel.x - 8.0),
			view.y * GROUND - _enemy.drawn_size().y - panel.y - 8.0)


func _on_enemy_spawned(_index: int, _enemy_name: String, _hp: int) -> void:
	_enemy.play("idle")
	_slide_enemy()


func _on_enemy_hit(hp_left: int) -> void:
	if hp_left > 0:
		_enemy.play_once("hurt")


func _on_enemy_died(_index: int) -> void:
	_enemy.play_once("death")


func _on_finished(won: bool) -> void:
	_refresh()
	_enemy_panel.hide()
	if won:
		_enemy.hide()
	_result_label.text = "Tile discovered" if won else "Out of time"
	_result.show()
	# Centre it once it knows how big it is.
	await get_tree().process_frame
	var size := _result.get_combined_minimum_size() * _ui_scale
	_result.position = (_size() - size) / 2.0


func _on_back_pressed() -> void:
	finished.emit(fight.victory)

