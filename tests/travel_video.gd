extends "res://tests/clip.gd"
## The hero on the road: hard cuts between fights on six grounds, open land and roads (never a settlement),
## under six skies, a different monster walking in on each -- the backdrop sliding by as it comes, which is the
## travelling -- and falling to one click. The last, the dragon, freezes as it bursts under "Kobold Clicker".

const CELL := Vector2i(6, 0)
## [ground, open land or road, sky, monster]: one a cut.
const SHOTS := [
	["grass", "plain", "morning", "Goblin"],
	["desert", "road", "noon", "Medusa"],
	["forest", "plain", "golden", "Werewolf"],
	["ice", "road", "alpine", "Harpy"],
	["mountains", "plain", "twilight", "Cyclops"],
	["dirt", "road", "night", "Dragon"],
]
## How long a body takes to walk in (`Encounter.WALK_IN` less spawn speed), how long it stands before the
## click, and how long a shot runs on past it: long enough for the body to burst and its coins to land.
const SPAWN_SPEED := 25.0
const BEFORE_KILL := 0.15
const AFTER_KILL := 0.6
## How far into the last body's burst the clip freezes for the title.
const FREEZE := 0.2


func _run() -> void:
	await _open_main("travel")
	# Nothing of the map's over the fights: they are built here, not opened by the main scene.
	main.map.hide()
	main._panel.hide()
	main._show_corner(false)
	main._play_music(main.BATTLE_MUSIC)
	# The whole window: a boss stands out past the right edge of anything narrower. The title in the sky.
	_show(Rect2(Vector2.ZERO, root.size))
	_caption_middle = 200.0
	var combat: CombatScene = null
	for i in SHOTS.size():
		var shot: Array = SHOTS[i]
		var fight := Encounter.for_tile(CELL, shot[0], shot[1])
		fight.lineup[0] = shot[3]
		fight.health[0] = Encounter.hp_of(shot[3], CELL)
		fight.hp = fight.health[0]
		# Certain crits, so every kill throws up the loud number.
		fight.arm({"damage": fight.hp, "crit_chance": 100.0, "crit_damage": 80.0, "attack_speed": 0.1,
				"spawn_speed": SPAWN_SPEED})
		var next: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		main.add_child(next)
		next.place = TileNames.generate(CELL, shot[0], main.map_seed)
		next.hud_top = main._fight_top()
		next.xp_target = main._character.xp_point()
		next.begin(fight, CELL, main.ui_scale, shot[1], 1 + i % CombatScene.AREA_LAYOUTS, shot[2])
		# A hard cut: the last fight gone the frame this one comes.
		if combat != null:
			combat.hide()
			combat.queue_free()
		combat = next
		if i == 0:
			_start()
		await process_frame
		# Where it will stand, waited for there.
		var enemy: CombatActor = combat._enemy
		_pointer = Vector2(root.size.x * CombatScene.ENEMY_X,
				enemy.global_position.y - enemy.drawn_size().y * 0.5).round()
		while fight.phase != Encounter.Phase.WAITING:
			await process_frame
		await create_timer(BEFORE_KILL).timeout
		await _click(0.04, 0.0)
		await create_timer(AFTER_KILL if i < SHOTS.size() - 1 else FREEZE).timeout
	# Frozen mid-burst, the next body never coming, the cursor out of the picture.
	combat.process_mode = Node.PROCESS_MODE_DISABLED
	_pointer = Vector2(root.size) + Vector2(40, 40)
	_say("Kobold Clicker", "")
	await create_timer(1.6, true, false, true).timeout
	await _end()
