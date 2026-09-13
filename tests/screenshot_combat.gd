extends "res://tests/harness.gd"
## Renders the tile fight for a visual check and saves screenshots to user://. Needs a window
## (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/screenshot_combat.gd
##
## Saves the opening of a fight, the middle of one, the elite at the end, and the two verdicts. Also
## saves a contact sheet of every enemy's idle frame at the size the fight draws it, which is what
## catches a frame or crop measured wrong in EnemyRoster.

const MAP_SEED := 1
## The tile the shots are taken on: far enough out that the enemies have some health.
const CELL := Vector2i(6, 0)
const ENVIRONMENT := "grass"


func _run() -> void:
	await _shoot_fight()
	await _shoot_roster()
	quit()


func _shoot_fight() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = "user://screenshot_combat_inventory.json"
	root.add_child(main)
	for i in 3:
		await process_frame

	var fight := Encounter.for_tile(CELL, ENVIRONMENT)
	# Drops are rare, so the winning shot is seeded and its elite promised one: the point of the shot
	# is the panel that lists them.
	fight.loot_rng.seed = WORLD_SEED
	fight.guarantee_elite = true
	print("Lineup for %s on %s:" % [CELL, ENVIRONMENT])
	for i in fight.lineup.size():
		print("  %2d %-18s %3d hp%s" % [i + 1, fight.lineup[i], fight.health[i],
				"   <- elite" if i == Encounter.ENEMIES - 1 else ""])

	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	main.add_child(combat)
	combat.begin(fight, CELL, main.ui_scale)
	main.map.hide()
	# Let the first enemy finish running in, so the shot shows the fight rather than an empty field.
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)
	await _save(combat, "combat_start.png")

	# Part way through the first enemy.
	for i in int(fight.enemy_max_hp() / 2.0):
		fight.hit()
	await _save(combat, "combat_hurt.png")

	# On to the elite at the end, so its size against the commons can be seen.
	while not fight.on_elite() and not fight.finished:
		if not fight.hit():
			fight.advance(0.1)
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)
	await _save(combat, "combat_elite.png")

	# The two verdicts.
	while not fight.finished:
		if not fight.hit():
			fight.advance(0.05)
	await _save(combat, "combat_won.png")

	# One of those drops, opened: what clicking a square on the verdict panel gives.
	if not combat._drops.is_empty():
		combat._inspect_drop(0)
		await _save(combat, "combat_drop.png")
		combat._inspect_drop(-1)

	var lost: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	main.add_child(lost)
	var doomed := Encounter.for_tile(CELL, ENVIRONMENT)
	lost.begin(doomed, CELL, main.ui_scale)
	combat.hide()
	doomed.advance(Encounter.SECONDS + 1.0)
	await _save(lost, "combat_lost.png")


## Every enemy's idle frame at the height the fight draws it, so a bad frame or crop is obvious.
func _shoot_roster() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame

	var page := Node2D.new()
	root.add_child(page)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.12, 0.12, 0.16)
	backdrop.size = Vector2(root.get_visible_rect().size)
	page.add_child(backdrop)

	var names := EnemyRoster.names()
	var columns := 8
	var cell_size := Vector2(root.get_visible_rect().size) / Vector2(columns, ceilf(names.size() / float(columns)))
	for i in names.size():
		var actor := CombatActor.new()
		page.add_child(actor)
		var band: float = CombatScene.SIZE_HEIGHT[EnemyRoster.size_of(names[i])]
		actor.setup_enemy(names[i], cell_size.y * 0.55 * band)
		var row := i / columns
		actor.position = Vector2((i % columns + 0.5) * cell_size.x, (row + 0.82) * cell_size.y)
		var label := Label.new()
		label.theme = UITheme.theme()
		label.theme_type_variation = "PanelLabel"
		label.text = names[i]
		label.position = Vector2((i % columns) * cell_size.x + 4, (row + 0.84) * cell_size.y)
		page.add_child(label)
	await _save(null, "combat_roster.png")


func _save(_scene: Node, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://" + name
	root.get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
