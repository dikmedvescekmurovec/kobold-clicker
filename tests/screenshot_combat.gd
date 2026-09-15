extends "res://tests/harness.gd"
## Renders the tile fight for a visual check and saves screenshots to user://. Needs a window
## (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/screenshot_combat.gd
##
## Saves the opening of a fight, the middle of one, the elite at the end, and the two verdicts, plus
## a farm run with its counter, its toast, its full-bag warning and its way out, the popup the
## counter opens and one find opened inside it. Also
## saves a contact sheet of every enemy's idle frame at the size the fight draws it, which is what
## catches a frame or crop measured wrong in EnemyRoster, and one shot per environment on its own
## backdrop (combat_area_<env>_<variant>.png).

const MAP_SEED := 1
## The tile the shots are taken on: far enough out that the enemies have some health.
const CELL := Vector2i(6, 0)
## The one settlement shot in every layout, so the four can be put side by side.
const LAYOUT_ENV := "grass"
const LAYOUT_VARIANT := "village"
const ENVIRONMENT := "grass"


func _run() -> void:
	await _shoot_fight()
	await _shoot_farm()
	await _shoot_backdrops()
	await _shoot_roster()
	quit()


## One shot per environment, each on a different variant, so all six places and all five variants
## are seen with fighters standing on them -- the check that the ground line survived the swap.
func _shoot_backdrops() -> void:
	# The fight shots leave their scenes standing, and a CanvasLayer left behind draws over these.
	for child in root.get_children():
		child.queue_free()
	await process_frame

	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = "user://screenshot_combat_inventory.json"
	main.map_path = "user://screenshot_combat_map.json"
	root.add_child(main)
	for i in 3:
		await process_frame
	main.map.hide()

	var envs := SheetMeta.env_adjacency().keys()
	var variants := ["plain", "road", "village", "town", "fortress"]
	for i in envs.size():
		var env: String = envs[i]
		var variant: String = variants[i % variants.size()]
		var layout: int = 1 + i % CombatScene.AREA_LAYOUTS
		var fight := Encounter.for_tile(CELL, env)
		var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		main.add_child(combat)
		combat.place = TileNames.generate(CELL, env, MAP_SEED)
		combat.begin(fight, CELL, main.ui_scale, variant, layout)
		while fight.phase != Encounter.Phase.WAITING:
			fight.advance(0.05)
		await _save(combat, "combat_area_%s_%s_%d.png" % [env, variant, layout])
		combat.queue_free()
		await process_frame

	# Every layout of one settlement, in four files: the shot that says whether a village is four
	# villages or one village with the clouds moved.
	for layout in range(1, CombatScene.AREA_LAYOUTS + 1):
		var fight := Encounter.for_tile(CELL, LAYOUT_ENV)
		var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		main.add_child(combat)
		combat.place = TileNames.generate(CELL, LAYOUT_ENV, MAP_SEED, "small")
		combat.begin(fight, CELL, main.ui_scale, LAYOUT_VARIANT, layout)
		while fight.phase != Encounter.Phase.WAITING:
			fight.advance(0.05)
		await _save(combat, "combat_layout_%s_%s_%d.png" % [LAYOUT_ENV, LAYOUT_VARIANT, layout])
		combat.queue_free()
		await process_frame
	main.queue_free()
	await process_frame


func _shoot_fight() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = "user://screenshot_combat_inventory.json"
	main.map_path = "user://screenshot_combat_map.json"
	root.add_child(main)
	for i in 3:
		await process_frame

	var fight := Encounter.for_tile(CELL, ENVIRONMENT)
	# Drops are rare, so the winning shot is seeded and its elite promised one: the point of the shot
	# is the panel that lists them.
	fight.loot_rng.seed = WORLD_SEED
	fight.guarantee_elite = true
	# Armed, because an unarmed fight takes one point a click and the shots would say nothing about
	# what gear is worth. Certain crits: the number floating off a hit is the only place the player
	# can read their damage, so the shot has to show the loudest version of it.
	fight.arm({"damage": 5.0, "crit_chance": 100.0, "crit_damage": 80.0, "attack_speed": 1.0})
	print("Lineup for %s on %s:" % [CELL, ENVIRONMENT])
	for i in fight.lineup.size():
		print("  %2d %-18s %3d hp%s" % [i + 1, fight.lineup[i], fight.health[i],
				"   <- elite" if i == Encounter.ENEMIES - 1 else ""])

	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	main.add_child(combat)
	# The tile's own name, the way the map would have handed it over.
	combat.place = TileNames.generate(CELL, ENVIRONMENT, MAP_SEED)
	combat.begin(fight, CELL, main.ui_scale)
	main.map.hide()
	# Let the first enemy finish running in, so the shot shows the fight rather than an empty field.
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)
	await _save(combat, "combat_start.png")

	# Part way through the first enemy, with a frame between the blows so the numbers floating off
	# them are caught spread out rather than stacked on one spot.
	for i in int(fight.enemy_max_hp() / 2.0 / fight.damage):
		fight.hit()
		await process_frame
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
		combat._result_drops.inspect(0)
		await _save(combat, "combat_drop.png")
		combat._result_drops.inspect(-1)

	var lost: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	main.add_child(lost)
	var doomed := Encounter.for_tile(CELL, ENVIRONMENT)
	lost.place = TileNames.generate(CELL, ENVIRONMENT, MAP_SEED)
	lost.begin(doomed, CELL, main.ui_scale)
	combat.hide()
	doomed.advance(Encounter.SECONDS + 1.0)
	await _save(lost, "combat_lost.png")


## A farm run: no clock, a tally counting up, the counter in the corner with what it has found, and
## Terminate low and out of the way. Three things are worth looking at here that no other shot has --
## whether the counter clears the enemy's name panel, whether a toast is readable over the backdrop,
## and whether Terminate is far enough from where the player is clicking.
func _shoot_farm() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	main.inventory_path = "user://screenshot_combat_inventory.json"
	main.map_path = "user://screenshot_combat_map.json"
	root.add_child(main)
	for i in 3:
		await process_frame

	var fight := Encounter.farm(CELL, ENVIRONMENT)
	fight.roster_rng.seed = WORLD_SEED
	fight.loot_rng.seed = WORLD_SEED
	fight.arm({"damage": 5.0, "crit_chance": 100.0, "crit_damage": 80.0, "attack_speed": 1.0})
	# Every body carries something. At the real 3% a shot of a pouch with three finds in it is a
	# hundred-odd kills away, and this script waits a frame per swing.
	fight.always_drop = true
	# And an orb off every body too, for the same reason and at a rarer rate still. It is what puts
	# an orb toast on this shot beside a find's, which is the only place the two can be compared.
	fight.always_orb = true
	fight.orb_rng.seed = WORLD_SEED
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	main.add_child(combat)
	# A run with nowhere to put what it finds, so the shot shows the warning that stands under the
	# counter while the bag is full. Said before `begin`, so it is up on the first frame.
	combat.bag_room = 0
	combat.place = TileNames.generate(CELL, ENVIRONMENT, MAP_SEED)
	combat.begin(fight, CELL, main.ui_scale)
	main.map.hide()

	# Far enough in that the counter has something on it and the tally reads properly.
	var guard := 0
	while combat._drops.size() < 3 and guard < 2000:
		guard += 1
		if not fight.hit():
			fight.advance(0.05)
		await process_frame
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)
		await process_frame
	await _save(combat, "combat_farm.png")

	# The popup the counter opens, which for a run is the only way to see what it has turned up.
	combat._on_loot_pressed()
	await _save(combat, "combat_farm_loot.png")
	# One of them opened, which is where a find can be thrown away by hand -- the way out of a run
	# that has turned up more than the bag will hold.
	combat._loot_drops.inspect(0)
	await _save(combat, "combat_farm_drop.png")
	combat._loot_drops.inspect(-1)
	combat._on_loot_closed()

	# And what the run says for itself once the player has had enough.
	combat._on_terminate_pressed()
	await _save(combat, "combat_farm_ended.png")


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
