extends "res://tests/harness.gd"
## The heroes a player can be (`Scenes/characters.gd`): the roster's art as `tools/characters.py` cut it,
## each hero in a fight and on the map, buying and picking and their save, the page, and the main scene
## dressed in the pick. Run from the project folder:
##   python tests/run_all.py characters

const MAIN := preload("res://Scenes/main_scene.gd")
const SAVE := "user://test_characters.json"
const MAP := "user://test_characters_map.json"
## The tile beside the start, which a new hero can fight for.
const NEXT_DOOR := Vector2i(1, 0)


func _run() -> void:
	_check(_test_the_roster_has_its_art() == true, "roster art tests ran to the end")
	_check(await _test_every_hero_fights_and_walks() == true, "fighter and token tests ran to the end")
	_check(_test_buying_and_picking() == true, "buying and picking tests ran to the end")
	_check(await _test_the_page() == true, "page tests ran to the end")
	_check(await _test_the_scene_wears_the_hero() == true, "scene tests ran to the end")
	_clear()
	_report("characters")


func _clear() -> void:
	for path: String in [SAVE, MAP]:
		SafeFile.remove(path)


func _write(text: String) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Every row's files are there and are the shape the three loaders take them for: a null `load` only
## logs, and a hero drawn from a sheet that does not divide is a sliver of the next frame.
func _test_the_roster_has_its_art() -> bool:
	_check(Characters.has(Characters.FIRST) and Characters.ids().size() == 32, "the kobold and 31 more (%d)"
			% Characters.ids().size())
	var face_side := CharacterPanel.PORTRAIT.get_size()
	for id: String in Characters.ids():
		var frame := Characters.frame(id)
		var crop := Characters.bounds(id)
		_check(Rect2i(Vector2i.ZERO, frame).encloses(crop), "%s's crop is in its frame" % id)
		for animation: String in Characters.ANIMATIONS:
			var path := Characters.path(id, animation)
			if not ResourceLoader.exists(path):
				_check(false, "%s has no %s" % [id, path])
				continue
			var image := EnemyRoster.sheet_image(path)
			_check(image.get_width() % frame.x == 0 and image.get_height() == frame.y,
					"%s's %s is whole frames of %s (%s)" % [id, animation, frame, image.get_size()])
			# A boundary with art on both sides is a body cut in two.
			for k in range(1, image.get_width() / frame.x):
				_check(not (_solid(image, k * frame.x) and _solid(image, k * frame.x - 1)),
						"%s's %s frame %d starts on a clear column" % [id, animation, k])
		var swing := EnemyRoster.sheet_image(Characters.path(id, "attack")).get_width() / frame.x
		# The scene cuts back into a swing two frames in (`CombatScene.SWING_RESTART_FRAME`).
		_check(swing >= 4, "%s's swing has frames to cut back into (%d)" % [id, swing])
		var stand := Characters.stand(id)
		_check(stand.size == Vector2i.ZERO or crop.encloses(stand), "%s's own standing box is in its crop" % id)
		_check(Characters.feet(id) > crop.position.x and Characters.feet(id) < crop.end.x,
				"%s's feet stand in its crop" % id)
		_check(not Characters.name_of(id).is_empty(), "%s has a name" % id)
		var portrait: Texture2D = load(Characters.path(id, "portrait"))
		var idle: Texture2D = load(Characters.path(id, "idle"))
		_check(portrait != null and portrait.get_height() == DialogueBox.PORTRAIT_HEIGHT * idle.get_width() / frame.x,
				"%s's portrait is a frame of its idle a %d px row" % [id, DialogueBox.PORTRAIT_HEIGHT])
		var face: Texture2D = load(Characters.path(id, "face"))
		_check(face != null and face.get_size() == face_side, "%s's face is the corner circle's size" % id)
		var badge: Texture2D = load(Characters.path(id, "badge"))
		_check(badge != null and badge.get_size() == Vector2.ONE * MapPointer.DISC_RADIUS * 2.0,
				"%s's badge is the pointer's disc across" % id)
	# The kobold's art is where it always was, and what the dialogue box and the corner panel call theirs.
	_check(Characters.path(Characters.FIRST, "portrait") == DialogueBox.PORTRAITS % DialogueBox.PLAYER,
			"the kobold's portrait is the dialogue box's player")
	_check(Characters.path(Characters.FIRST, "face") == CharacterPanel.PORTRAIT.resource_path,
			"and his face the corner panel's own")
	return true


func _solid(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


## Each hero as a fight's fighter and as the map's token: scaled and stood by its own numbers, with no
## swing longer than the kobold's and its marked feet on the tile whichever way it faces.
func _test_every_hero_fights_and_walks() -> bool:
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var token := map.player
	var kobold := CombatActor.new()
	root.add_child(kobold)
	kobold.setup_player(124.0)
	_check(kobold.standing == Rect2i(27, 29, 51, 62) and kobold.bounds == Rect2i(1, 29, 115, 62)
			and kobold.scale == Vector2(2, 2), "with no hero named a fighter is the kobold, as he ever was")
	_check(kobold.sprite_frames.get_animation_speed("attack") == CombatActor.FPS, "his swing at its own pace")
	kobold.free()
	for id: String in Characters.ids():
		var actor := CombatActor.new()
		root.add_child(actor)
		actor.setup_player(100.0, 0.0, id)
		for animation: String in Characters.ANIMATIONS:
			_check(actor.sprite_frames.has_animation(animation) and actor.sprite_frames.get_frame_count(animation) > 0,
					"%s has a %s to play" % [id, animation])
		_check(actor.standing.size.y > 0 and is_equal_approx(actor.drawn_size().y, 100.0),
				"%s stands as tall as it is asked to (%s)" % [id, actor.drawn_size()])
		var swing := actor.sprite_frames.get_frame_count("attack") / actor.sprite_frames.get_animation_speed("attack")
		_check(swing <= CombatActor.SWING_FRAMES / CombatActor.FPS + 0.001,
				"%s's swing is no longer than the kobold's (%.2f s)" % [id, swing])
		actor.free()

		token.dress(id)
		var crop := Characters.bounds(id)
		var stand := CombatActor.player_standing(id)
		var feet := Vector2(Characters.feet(id), stand.end.y) - Vector2(crop.position) - Vector2(crop.size) / 2.0
		_check(is_equal_approx(stand.size.y * token.scale.y, PlayerToken.TALL), "%s's token stands %s tall"
				% [id, PlayerToken.TALL])
		for west: bool in [false, true]:
			token._face(west)
			var at := (Vector2(-feet.x if west else feet.x, feet.y) + token.offset) * token.scale
			_check(at.is_equal_approx(Vector2(0, PlayerToken.FOOT_OFFSET)),
					"%s's feet are on the tile's foot point facing %s (%s)" % [id, "west" if west else "east", at])
		var shadow := token.get_child(0) as Sprite2D
		_check((shadow.position * token.scale).is_equal_approx(Vector2(0, PlayerToken.FOOT_OFFSET)),
				"and %s's shadow under them" % id)
		_check(token.sprite_frames.has_animation("idle") and token.sprite_frames.has_animation("run")
				and token.is_playing(), "%s's token idles and can run" % id)
	# A hero dressed mid-walk walks on.
	map.set_player_cell(Vector2i.ZERO)
	token.walk([HexGrid.neighbor(Vector2i.ZERO, HexGrid.Edge.W)] as Array[Vector2i])
	token.dress("samurai")
	_check(token.animation == &"run" and token.is_playing() and token.flip_h and token.is_walking(),
			"a hero dressed mid-walk runs on the way it was going")
	map.free()
	await process_frame
	return true


## Buying, picking, and what a save and a transcension keep of both.
func _test_buying_and_picking() -> bool:
	_clear()
	var player := Inventory.new()
	_check(player.character == Characters.FIRST and player.owns(Characters.FIRST) and not player.owns("samurai"),
			"a new player is the kobold and owns nobody else")
	_check(not player.use_character("samurai") and player.character == Characters.FIRST,
			"a hero not bought cannot be picked")
	_check(not player.buy_character("nobody") and not player.buy_character(Characters.FIRST),
			"nor one the roster has not got, or the kobold, be bought")
	_check(player.buy_character("samurai") and player.owns("samurai") and not player.buy_character("samurai"),
			"a hero is bought once")
	_check(player.character == Characters.FIRST, "and buying is not picking")
	_check(player.use_character("samurai") and player.character == "samurai" and not player.use_character("samurai"),
			"a bought hero is picked, once")
	player.buy_character("mega_boss")
	_check(player.save(SAVE), "the player is saved")
	var problem: Array = []
	var back := Inventory.load_from(SAVE, problem)
	_check(problem.is_empty() and back.character == "samurai" and back.owned_characters == ["samurai", "mega_boss"],
			"the heroes bought and the one picked come back (%s, %s)" % [back.character, back.owned_characters])
	var next := player.transcended()
	_check(next.character == "samurai" and next.owned_characters == ["samurai", "mega_boss"],
			"and are carried through a transcension")
	next.buy_character("kitsune")
	_check(not player.owns("kitsune"), "which hands the new world a list of its own")

	# A save from before there were heroes, and ones a hand has been at.
	_write('{"version": 34, "items": []}')
	var old := Inventory.load_from(SAVE, problem)
	_check(problem.is_empty() and old.character == Characters.FIRST and old.owned_characters.is_empty(),
			"a version 34 save is the kobold alone")
	_write('{"version": %d, "items": [], "characters": ["samurai", "retired_hero", 7, "samurai"], "character": "kitsune"}'
			% Inventory.VERSION)
	var edited := Inventory.load_from(SAVE, problem)
	_check(problem.is_empty() and edited.owned_characters == ["samurai"] and "retired_hero" in edited.lost,
			"a hero this build has not got is left out and named as lost (%s)" % [edited.lost])
	_check(edited.character == Characters.FIRST, "and a pick that is not owned is the kobold")
	_write('{"version": %d, "items": [], "characters": "samurai", "character": ["samurai"]}' % Inventory.VERSION)
	var wrong := Inventory.load_from(SAVE, problem)
	_check(problem.is_empty() and wrong.owned_characters.is_empty() and wrong.character == Characters.FIRST,
			"fields of the wrong kind read as absent")
	_clear()
	return true


## The page by itself: a square a hero, Buy then Select, each saved and said.
func _test_the_page() -> bool:
	_clear()
	var player := Inventory.new()
	var page := RosterPage.new(player, SAVE, 2.0)
	root.add_child(page)
	await process_frame
	var said: Array = []
	page.changed.connect(func() -> void: said.append(true))
	var squares := page._grid.get_children()
	_check(squares.size() == Characters.ids().size(), "a square a hero (%d)" % squares.size())
	_check(_square(page, Characters.FIRST).has_node(RosterPage.USING_NAME)
			and not _square(page, "samurai").has_node(RosterPage.USING_NAME), "the hero in use wears the edge")
	_check((_square(page, "samurai").get_child(0) as CanvasItem).modulate == OrbSlot.DIM
			and (_square(page, Characters.FIRST).get_child(0) as CanvasItem).modulate == Color.WHITE,
			"a hero not bought is dimmed")
	_check(page._deed.text == "Select" and page._deed.disabled and page._deed.tooltip_text == "In use",
			"the hero in use can only be told so")

	# A press on a square counts as it lets go; one that travelled is a drag of the grid.
	var at := _square(page, "samurai").get_global_rect().get_center()
	page._on_grid_input(_press(at, true))
	page._on_grid_input(_press(at + Vector2(0, 40), false))
	_check(page._picked == Characters.FIRST, "a press that travelled picks nobody")
	page._on_grid_input(_press(at, true))
	page._on_grid_input(_press(at, false))
	_check(page._picked == "samurai" and page._name.text == "Samurai", "a press let go on a square shows its hero")
	_check(page._actor.sprite_frames.get_frame_texture("idle", 0).atlas.resource_path
			== Characters.path("samurai", "idle"), "standing in the box as a fight draws it")
	_check(page._deed.text == "Buy" and not page._deed.disabled, "one not bought can be bought")
	_check(said.is_empty() and not FileAccess.file_exists(SAVE), "and looking changes nothing")

	page._deed.pressed.emit()
	_check(player.owns("samurai") and player.character == Characters.FIRST, "Buy buys and does not pick")
	_check(Inventory.load_from(SAVE).owns("samurai") and said.size() == 1, "and is saved and said")
	_check(page._deed.text == "Select" and not page._deed.disabled, "a bought hero can be picked")
	_check((_square(page, "samurai").get_child(0) as CanvasItem).modulate == Color.WHITE, "its square lit")
	page._deed.pressed.emit()
	_check(player.character == "samurai" and Inventory.load_from(SAVE).character == "samurai" and said.size() == 2,
			"Select makes it the hero, saved and said")
	_check(page._deed.disabled and _square(page, "samurai").has_node(RosterPage.USING_NAME)
			and not _square(page, Characters.FIRST).has_node(RosterPage.USING_NAME), "and the edge moves to it")
	page.pick("knight_1")
	page.open()
	_check(page._picked == "samurai", "opened again, the page shows the hero in use")
	page.free()
	await process_frame
	_clear()
	return true


func _square(page: RosterPage, id: String) -> Control:
	return page._grid.get_node(id)


func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = down
	press.position = at
	press.global_position = at
	return press


## The main scene: its button opens the page, a pick dresses the token, the corner and the badge at once
## and the next fight's fighter, and a game opened again is still that hero.
func _test_the_scene_wears_the_hero() -> bool:
	_clear()
	var main := await _launch()
	for tip: Array in MAIN.TIPS:
		main.inventory.tips.append(tip[0])
	_check(_worn(main) == Characters.FIRST, "a new game is the kobold everywhere")
	_check(main._roster_button.visible, "the heroes' button is there from the first step")
	main._roster_button.pressed.emit()
	_check(main.roster_page.visible, "and opens their page")
	main.roster_page.pick("knight_1")
	main.roster_page._deed.pressed.emit()
	_check(_worn(main) == Characters.FIRST, "a hero bought is not yet worn")
	main.roster_page._deed.pressed.emit()
	_check(main.inventory.character == "knight_1" and _worn(main) == "knight_1",
			"a hero picked is on the map, in the corner and on the badge at once (%s)" % _worn(main))
	main.character_page.open()
	var faces := 0
	for rect: TextureRect in main.character_page.find_children("*", "TextureRect", true, false):
		if rect.texture != null and rect.texture.resource_path == Characters.path("knight_1", "face"):
			faces += 1
	_check(faces == 1, "and on the character page")

	main.map.select_cell(NEXT_DOOR)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main._combat != null and main._combat.character == "knight_1"
			and main._combat._player.sprite_frames.get_frame_texture("idle", 0).atlas.resource_path
			== Characters.path("knight_1", "idle"), "the fight's fighter is the hero picked")
	_check(not main._roster_button.visible, "and over a fight nobody is picked again")
	main.free()
	await process_frame

	main = await _launch()
	_check(main.inventory.character == "knight_1" and _worn(main) == "knight_1", "opened again, still that hero")
	main.free()
	await process_frame
	_clear()
	return true


func _launch() -> Node:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SAVE
	main.map_path = MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	return main


## The hero the scene is dressed as outside a fight, or what disagrees.
func _worn(main: Node) -> String:
	var token: String = main.map.player.sprite_frames.get_frame_texture("idle", 0).atlas.resource_path
	var corner: String = main._character._portrait.texture.resource_path
	var badge: String = main._hero_pointer._picture.texture.resource_path
	for id: String in Characters.ids():
		if token == Characters.path(id, "idle") and corner == Characters.path(id, "face") \
				and badge == Characters.path(id, "badge"):
			return id
	return "token %s, corner %s, badge %s" % [token, corner, badge]
