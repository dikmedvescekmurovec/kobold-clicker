extends "res://tests/harness.gd"
## The hype trailer, played out shot by shot and cut to the beat of Sounds/Music/battle.mp3. Recorded
## by `python tools/trailer.py`, which runs this under Movie Maker and lays the track under it; run on
## its own (no --headless) it just plays in a window, silent but for the game's own sounds. Keep the
## real mouse off that window: the pages are clicked through with pushed input events.
##
## Everything is timed in beats from beat 0 and waits on frames, never on the clock, so a slow machine
## records the same film. battle.mp3 is 80 BPM; `tools/trailer.py` starts it 3.525 s in, which puts a
## bar on every fourth beat from beat 2 and the track's big hits on beats 6, 14, 22... -- the glass
## breaking, the loot, the Gryphon's fall, the burst and the title all land on one.
##
## The fights are dressed for the film: the hero wears the Gambler's Die, the next body stands in the
## moment the last falls, and every body has as much health as about five blows (`_open`).

const BPM := 80.0
const FPS := 60
## The last beat the film holds before it cuts to black (`tools/trailer.py` reads the length off it).
const END_BEAT := 80.0
const MAP_SEED := 1
const CELL := Vector2i(6, 0)
## What the film ends on.
const TITLE := "Kobold Clicker"
const SUBTITLE := "An Idle Loot RPG"
const INVENTORY := "user://trailer_inventory.json"
const MAP := "user://trailer_map.json"
## What an ordinary body takes to fall: this many average blows, which the Die makes four to six.
const HITS := 5.0
## The Gambler's Die, worn in every fight, at this rank.
const DIE_RANK := 1
## How long a body lies before the next stands in its place (the game's is `Encounter.DEATH`).
const BODY_LIES := 0.2
## Frames between clicks in a fight: about five and a half a second.
const CLICK_EVERY := 11
## The skill whose point goes in last, before the trees burst.
const CAPSTONE := "titan"
## The pointer the pages are clicked with: the game's own hand (`Cursors.SHAPES`), at the UI's scale.
const HAND_TILE := "res://Assets/Cursor/Tiles/tile_0137.png"
const HAND_POINT := Vector2(6, 1)

var _start := 0
var _main: Node
var _combat: CombatScene
var _layer: CanvasLayer
var _black: ColorRect
var _cursor: TextureRect
var _rng := RandomNumberGenerator.new()


func _run() -> void:
	_rng.seed = WORLD_SEED
	# A fresh world every take, so every take is the same film.
	for path in [INVENTORY, MAP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_build_overlay()
	_black.show()
	_main = load("res://Scenes/main_scene.tscn").instantiate()
	_main.world_seed = WORLD_SEED
	_main.map_seed = MAP_SEED
	_main.inventory_path = INVENTORY
	_main.map_path = MAP
	root.add_child(_main)
	for i in 3:
		await process_frame
	# The track goes under it afterwards; the game's own would fight it.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS), true)
	# Every tip already read: a first visit's dialogue would stop the film to talk.
	for tip: Array in _main.get_script().get_script_constant_map()["TIPS"]:
		_main.inventory.tips.append(tip[0])
	_main.inventory.level = 42
	_main._sync_character()
	_start = Engine.get_process_frames()
	print("TRAILER_START ", Engine.get_frames_drawn())
	# `-- --until=<beat>` (`tools/trailer.py --opening`) stops the film there, to work on one part.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--until="):
			var stop := float(arg.get_slice("=", 1))
			var cut := func() -> void:
				await _until(stop)
				quit()
			cut.call()

	await _fight_and_loot()
	await _explore()
	await _grow()
	await _transcend()
	await _title()
	quit()


# ---- the shots

## The lands the kills cut between, one a kill, in turn, and the backdrop each is fought on.
const LANDS_FOUGHT := [["ice", "town"], ["desert", "village"], ["forest", "fortress"],
		["mountains", "town"], ["dirt", "fortress"], ["grass", "village"]]
## The sky over each land in the cut: the one it was drawn under, rather than whatever hour the
## trailer happens to be recorded at.
const SKIES := {"grass": "morning", "forest": "morning", "dirt": "golden", "desert": "noon",
		"mountains": "alpine", "ice": "twilight"}
## From this beat each kill throws a find, and after the first kill past `GRYPHON_FROM` the cut is
## to the Gryphon, who falls on `GRYPHON_FALLS` -- the hit at 30 -- and drops `PRIZE`.
const LOOT_FROM := 14.0
const GRYPHON_FROM := 23.0
const GRYPHON_FALLS := 30.0
## The unique the Gryphon drops: the Berserker's Band, clicks at three times and more.
const PRIZE := "berserkers_band"


## Beats 0-34: "Every click counts." falling onto black glass over a farm run, each word knocking
## holes in it, and the glass breaking after the last; then a cut to another land on every kill, the
## kills throwing loot from the hit at 14, and last the Gryphon, whose fall drops the unique.
func _fight_and_loot() -> void:
	# Stood up behind the glass first, so its holes have something to show.
	_main.map.hide()
	_farm_in(0)
	var glass := _intro()
	await _until(LANDS[-1] + _beats(HOLD_SECONDS))
	await _shatter(glass)
	var rarities := [ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]
	var n := 0
	while _beats_since(0.0) < GRYPHON_FROM:
		await _until_kill(rarities[n % 2] if _beats_since(0.0) >= LOOT_FROM else -1)
		n += 1
		_close_fight()
		if _beats_since(0.0) < GRYPHON_FROM:
			_farm_in(n)
	await _gryphon()


## A farm run in `LANDS_FOUGHT[n]` (going round), on screen.
func _farm_in(n: int) -> void:
	var land: Array = LANDS_FOUGHT[n % LANDS_FOUGHT.size()]
	var fight := Encounter.farm(CELL, land[0])
	fight.roster_rng.seed = WORLD_SEED + n
	_arm(fight, {"damage": 5.0, "crit_chance": 40.0, "crit_damage": 80.0})
	# Named off a tile of its own, or every land would be the same hamlet.
	var place := TileNames.generate(CELL + Vector2i(n * 3, n), land[0], MAP_SEED, "small")
	_open(fight, CELL, land[1], 1 + n % CombatScene.AREA_LAYOUTS, land[0], place)


## Clicks the fight in front until its enemy falls, then holds on the body a moment before the cut --
## longer where it throws a find of `rarity` (-1 for none), so the beam is seen standing.
func _until_kill(rarity: int) -> void:
	var fight := _combat.fight
	if rarity >= 0:
		fight.always_orb = true
		fight.orb_rng.seed = WORLD_SEED + fight.roster_rng.seed
	while fight.phase != Encounter.Phase.DYING:
		if (Engine.get_process_frames() - _start) % CLICK_EVERY == 0:
			_combat._swing()
			fight.hit()
			_combat._refresh()
		await process_frame
	# Nobody steps in over it before the cut.
	fight.phase_left = 10.0
	if rarity >= 0:
		var piece := LootTable.roll(fight.enemy_name(), _rng, true, 8, 0.0, 0.0, rarity)
		_combat._show_find(piece.icon(), piece.rarity, piece.border_color())
	for i in 40 if rarity >= 0 else 20:
		await process_frame


## The last kill: the Gryphon, in the grass village, the clock running down under him, felled on the
## hit at 30 with a sliver of it left, and dropping the unique -- the game's own slow motion and banner.
func _gryphon() -> void:
	var fight := Encounter.for_tile(CELL, "grass", "village")
	fight.lineup[0] = EnemyRoster.in_environment("grass", EnemyRoster.Tier.BOSS)[0]
	_arm(fight, {"damage": 5.0, "crit_chance": 40.0, "crit_damage": 80.0})
	var from := _beats_since(0.0)
	# About the blows the shot has time for, and a little more, so he is standing to the end; the
	# blow on the hit is made the last.
	var blows := _seconds(GRYPHON_FALLS - from) * FPS / CLICK_EVERY
	fight.health[0] = roundf(_blow(fight) * blows * 1.15)
	fight.hp = fight.health[0]
	# His blows would take the clock, and the clock is what this shot runs down by hand.
	fight.strikes = false
	_open(fight, CELL, "village", 3, "grass", "", 0.0)
	var hold := func(_frame: int) -> void:
		var share := clampf((_beats_since(0.0) - from) / (GRYPHON_FALLS - from), 0.0, 1.0)
		fight.time_left = lerpf(6.0, 0.4, share)
		# A lucky run of the Die must not fell him before the hit.
		fight.hp = maxf(fight.hp, fight.health[0] * 0.06)
	await _clicking(GRYPHON_FALLS, CLICK_EVERY, hold)
	fight.hp = 1.0
	_combat._swing()
	fight.hit()
	_combat._refresh()
	# Down: the clock stands where the last blow left it, and nobody steps in over him.
	_combat.fight = null
	_main._combat = _combat
	_main.inventory.uniques_found.erase(PRIZE)
	var prize := Item.rolled_unique(PRIZE, _rng, 8)
	_combat._on_loot_dropped(0, prize)
	_main._on_loot_dropped(0, prize)
	# Gone before the cut: it fades for half a second.
	await _until(GRYPHON_FALLS + 3.3)
	_main._close_banner()
	await _until(GRYPHON_FALLS + 4.0)
	_main._combat = null
	_close_fight()


## Beats 34-46: the hero put down out on `EXPLORE_CELL`, a few rings short of the ice wall, in the
## middle of the window and the dark; then the land coming out of the dark as one front sweeping out
## from him, surging on every beat, the wall in sight within a few beats and the window clear by 45.
## The sweep carries on under the skills and the town (`_sweep`).
func _explore() -> void:
	Engine.time_scale = 1.0
	_main.map.show()
	# The badge that points at a chest off screen would walk it across the dark as the camera pulls out.
	_main._chest_pointer.target = HexMap.NO_CELL
	_main._chest_pointer.hide()
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	var camera: Camera2D = _main.camera
	# The hover outline follows the real mouse wherever it rests on the window: none in the film.
	map.highlight.hide()
	view.player_cell = EXPLORE_CELL
	map.set_player_cell(EXPLORE_CELL)
	var from := map.ground_layer.map_to_local(EXPLORE_CELL)
	camera.position = from
	camera.zoom = Vector2(1.25, 1.25)
	var zoom := camera.create_tween()
	zoom.tween_property(camera, "zoom", Vector2.ONE, _seconds(6.0)) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_caption("EXPLORE", 34.0, 37.0)

	for cell: Vector2i in view._tiles:
		view._show(cell, MapBuilder.State.CHARTED if view.is_land(cell) else MapBuilder.State.UNCHARTED)
	# The land is all drawn at once; the dark over it is one ring of the map's own fog whose hole grows
	# from the hero (`Reveal`), which costs a frame nothing where lifting it tile by tile cost a second.
	var reveal := Reveal.new()
	reveal.centre = from
	map.chests.add_child(reveal)
	# Paced to clear the window, once the camera is out, by `WINDOW_CLEAR`.
	var corner := Vector2(root.get_visible_rect().size).length() / 2.0
	_sweep(reveal, (corner + EdgeFog.LIFT_SOFT) / (WINDOW_CLEAR - SWEEP_FROM))
	await _until(46.0)


## Where the hero stands for the map shot, the beat the front starts from him, and the beat it has
## cleared the window.
const EXPLORE_CELL := Vector2i(6, 6)
const SWEEP_FROM := 35.0
const WINDOW_CLEAR := 45.0


## The fog over land not yet uncovered: the backdrop's shader (`HexMap.BACKDROP_SHADER`, as `EdgeFog`
## draws it) on a ring round `centre`, clear inside `front`, thickening over `EdgeFog.LIFT_SOFT` to
## full, and full from there to well past any window. Under the settlements, over everything else.
class Reveal extends Node2D:
	var centre := Vector2.ZERO
	var front := 0.0

	func _init() -> void:
		material = ShaderMaterial.new()
		material.shader = HexMap.BACKDROP_SHADER

	func _draw() -> void:
		const SIDES := 96
		var radii := [maxf(front, 1.0), maxf(front, 1.0) + EdgeFog.LIFT_SOFT, 8000.0]
		var fog := [0.0, 1.0, 1.0]
		for i in SIDES:
			var a := Vector2.from_angle(TAU * i / SIDES)
			var b := Vector2.from_angle(TAU * (i + 1) / SIDES)
			for k in 2:
				var inner := Color(1, 1, 1, fog[k])
				var outer := Color(1, 1, 1, fog[k + 1])
				draw_polygon(PackedVector2Array([centre + a * radii[k], centre + b * radii[k],
						centre + b * radii[k + 1], centre + a * radii[k + 1]]),
						PackedColorArray([inner, inner, outer, outer]))


## Runs the front out from the hero at `rate` world pixels a beat -- fastest on the beat, still
## between (x + sin(2 pi x) / 2 pi never runs backwards) -- showing a town or the cave only once it has
## passed them: they are drawn over the fog, and would stand in the dark ahead of it. Left to run
## until the black screen, then the fog goes.
func _sweep(reveal: Reveal, rate: float) -> void:
	var map: HexMap = _main.map
	while Engine.get_process_frames() < _frame_of(62.0):
		var x := maxf(_beats_since(SWEEP_FROM), 0.0)
		reveal.front = minf(rate * (x + sin(TAU * x) / TAU), 6000.0)
		reveal.queue_redraw()
		for sprite: Node2D in map.towns.get_children():
			sprite.visible = (sprite.position + HexMap.TOWN_ANCHOR).distance_to(reveal.centre) <= reveal.front
		await process_frame
	for sprite: Node2D in map.towns.get_children():
		sprite.show()
	reveal.queue_free()


## Beats 46-56: the skills page sliding in over the map, the trees filled point by point with the
## pointer, the last point into a capstone with its card up, and the burst popping on the hit at 54.
func _grow() -> void:
	var level := SkillTree.total_capacity() + 1
	_main.inventory.level = level
	var order: Array[String] = []
	var full := Skills.new()
	var learned := true
	while learned:
		learned = false
		for tree: String in SkillTree.trees():
			for id: String in SkillTree.nodes_of(tree):
				if full.rank_up(id, level):
					order.append(id)
					learned = true
	order.erase(CAPSTONE)
	var presses: Array[String] = order.slice(order.size() - 5)
	presses.append(CAPSTONE)
	var skills := Skills.new()
	_learn(skills, order.slice(0, order.size() - 5), level)
	_main.inventory.skills = skills
	# Filling the trees earns achievements, and their banner would stand over the burst.
	_main._resetting = true
	_main._on_skills_pressed()
	_caption("GROW", 46.0, 48.0)
	# The burst takes BURST_GLINT + BURST_SHAKE after the last press to pop: 4.8 beats.
	var pop_at := 54.0 - _beats(SkillsPage.BURST_GLINT + SkillsPage.BURST_SHAKE)
	var page: SkillsPage = _main.skills_page
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.55, 0.9)
	_cursor.show()
	for i in presses.size():
		# The capstone is pointed at a beat and a half early and held under the pointer, so its card
		# is up for a beat before the point goes in; the rest go in a point every 0.4 beat.
		var at := pop_at if i == presses.size() - 1 else pop_at - 3.0 + i * 0.4
		var lead := 1.5 if i == presses.size() - 1 else 0.3
		await _until(at - lead)
		await _point_at(_slot(page, presses[i]), lead if i == presses.size() - 1 else 0.3)
		await _until(at)
		var had := skills.rank_of(presses[i])
		await _click()
		# A pushed click can land in a hold still being let go; the point goes in regardless.
		if skills.rank_of(presses[i]) == had:
			page._on_skill_pressed(presses[i])
			page._stop_holding()
	await _until(pop_at + 1.0)
	_cursor.hide()
	await _until(56.0)
	# Earned here, quietly, so the next check has nothing left to announce.
	Achievements.earn(_main.inventory)
	_main._resetting = false


## Beats 56-70: the skills page giving way to the town's, the pointer to the fortuneteller, her way
## out asked for and taken, and the black screen between worlds -- an heirloom already held, so every
## card on it is live. The camera stays where it is: only the interface changes.
func _transcend() -> void:
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	# A wall down, which is what puts the way out on her list, and a purse that covers it. Both earn
	# achievements, taken quietly here so no banner stands over the town.
	_main._resetting = true
	view.land_radius += MapBuilder.WALL_STEP
	_main._credit_walls()
	_main.inventory.skull_budget = 6
	var heirloom := LootTable.roll("Imp", _rng, true, 8, 0.0, 0.0, ItemRarity.Rarity.ELITE)
	_main.inventory.add(heirloom)
	_main.inventory.make_heirloom(heirloom)
	_main.inventory.super_orbs = 3
	var town := view.start_town - view.origin
	_main.inventory.gold = TownPrices.fortune_price(FortuneTeller.TRANSCEND, town) * 3.0
	Achievements.earn(_main.inventory)
	_main._resetting = false
	# Standing in the town, without a walk: the camera holds on the land it has just uncovered.
	var camera_at: Vector2 = _main.camera.position
	_main._close_left_pages()
	view.player_cell = town
	map.set_player_cell(town)
	map.select_cell(town)
	_main._on_tile_clicked(town, map.get_tile_info(town))
	_main._on_town_pressed()
	_main.camera.position = camera_at
	var page: TownPage = _main.town_page

	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.5, 0.8)
	_cursor.show()
	await _until(57.0)
	var tab: Control = null
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).tooltip_text == TownServices.label(TownServices.FORTUNE):
			tab = button
	await _point_at(tab, 1.0)
	await _until(58.5)
	await _click()
	await _until(59.0)
	await _point_at(page.find_child(FortuneTeller.TRANSCEND, true, false), 1.0)
	await _until(60.5)
	await _click()
	await _until(61.0)
	var leave: Control = null
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text == "Transcend" and button.is_visible_in_tree():
			leave = button
	await _point_at(leave, 1.0)
	await _until(62.5)
	await _click()
	_cursor.hide()
	_caption("BEGIN AGAIN", 64.0, 67.0, 0.82)
	_caption("STRONGER", 67.0, 70.0, 0.82)
	await _until(70.0)


## Beats 70-80: the title on black, the hero above it.
func _title() -> void:
	_black.show()
	_main.hide()
	var size := Vector2(root.get_visible_rect().size)
	var hero := CombatActor.new()
	hero.setup_player(size.y * 0.4)
	hero.position = Vector2(size.x / 2.0, size.y * 0.47)
	_layer.add_child(hero)
	_caption(TITLE, 70.0, END_BEAT - 1.0, 0.6, 64,
			Palette.GOLD)
	_caption(SUBTITLE, 74.0, END_BEAT - 1.0, 0.72, 32)
	await _until(END_BEAT - 2.0)
	var fade := hero.create_tween().set_ignore_time_scale()
	fade.tween_property(hero, "modulate:a", 0.0, _seconds(1.0))
	await _until(END_BEAT)


# ---- the glass

const CRACK := Color(0.93, 0.96, 1.0, 0.95)


## The cracks in the glass, drawn in the order the words put them there.
class Cracks extends Node2D:
	var lines: Array[PackedVector2Array] = []

	func _draw() -> void:
		for line in lines:
			draw_polyline(line, CRACK, 2.0)


## One pane of black glass over the fight: rays out of the middle, crossed by rings, and the pieces
## between them. The words' cracks are drawn along its lines and it breaks along the same ones, so
## what falls or flies apart is what was cracked. `points[i][k]` is where ray i meets ring k; the last
## ring is well off the window.
class Pane:
	const RAYS := 13
	const RADII := [34.0, 90.0, 170.0, 280.0, 430.0, 640.0, 1400.0]
	var centre: Vector2
	var points: Array = []
	## How far each ray has cracked, by stage, as an index into RADII.
	var reach: Array = []
	## A number for each ring segment, which decides the stage it cracks in.
	var chance: Array = []
	## Every piece, in window pixels, and the ring it starts on (-1 for the middle's triangles).
	var pieces: Array[PackedVector2Array] = []
	var bands: Array[int] = []

	## `window` is what the pieces are cut to: a piece reaching far past it would sweep the whole
	## window as it fell.
	func _init(at: Vector2, window: Rect2, rng: RandomNumberGenerator) -> void:
		centre = at
		for i in RAYS:
			var angle := TAU * i / RAYS + rng.randf_range(-0.12, 0.12)
			var row: Array[Vector2] = []
			for radius: float in RADII:
				row.append(at + Vector2.from_angle(angle + rng.randf_range(-0.05, 0.05))
						* radius * rng.randf_range(0.85, 1.15))
			points.append(row)
			var first := rng.randi_range(0, 2) if i % 2 == 0 else rng.randi_range(-1, 1)
			reach.append([first, maxi(first, rng.randi_range(2, 4)), RADII.size() - 1])
			var rings: Array[float] = []
			for k in RADII.size():
				rings.append(rng.randf())
			chance.append(rings)
		var edge := PackedVector2Array([window.position, Vector2(window.end.x, window.position.y),
				window.end, Vector2(window.position.x, window.end.y)])
		for i in RAYS:
			var j := (i + 1) % RAYS
			_cut(PackedVector2Array([centre, points[i][0], points[j][0]]), -1, edge)
			for k in RADII.size() - 1:
				_cut(PackedVector2Array([points[i][k], points[j][k], points[j][k + 1],
						points[i][k + 1]]), k, edge)

	func _cut(piece: PackedVector2Array, band: int, edge: PackedVector2Array) -> void:
		# A convex piece and a rectangle meet in one polygon, or none.
		var inside := Geometry2D.intersect_polygons(piece, edge)
		if not inside.is_empty():
			pieces.append(inside[0])
			bands.append(band)

	## Every crack standing after `stage` (0, 1 or 2) blows.
	func cracks(stage: int) -> Array[PackedVector2Array]:
		const RING_ODDS := [[0.5], [0.9, 0.7, 0.35], [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]]
		var lines: Array[PackedVector2Array] = []
		for i in RAYS:
			var to: int = reach[i][stage]
			if to >= 0:
				var line := PackedVector2Array([centre])
				for k in to + 1:
					line.append(points[i][k])
				lines.append(line)
		for i in RAYS:
			var j := (i + 1) % RAYS
			var odds: Array = RING_ODDS[stage]
			for k in odds.size():
				if reach[i][stage] >= k and reach[j][stage] >= k and chance[i][k] < odds[k]:
					lines.append(PackedVector2Array([points[i][k], points[j][k]]))
		return lines

	## `count` pieces not yet gone, off the middle and on the window, to come loose.
	func loose(count: int, gone: Array[int], window: Rect2, rng: RandomNumberGenerator) -> Array[int]:
		var free: Array[int] = []
		for n in pieces.size():
			if bands[n] >= 1 and bands[n] <= 3 and n not in gone \
					and window.grow(-40.0).has_point(middle(n)):
				free.append(n)
		var picked: Array[int] = []
		while picked.size() < count and not free.is_empty():
			picked.append(free.pop_at(rng.randi_range(0, free.size() - 1)))
		return picked

	func middle(n: int) -> Vector2:
		var sum := Vector2.ZERO
		for point in pieces[n]:
			sum += point
		return sum / pieces[n].size()

	## A piece's edge, closed, for the crack round the hole it leaves.
	func outline(n: int) -> PackedVector2Array:
		var line := pieces[n].duplicate()
		line.append(line[0])
		return line


## How long a word takes to fall onto the glass, in beats, and how big it starts, over its own size.
const FALL := 0.5
const FALL_FROM := 5.0
## The beats each word lands on, how many pieces each blow knocks out of the glass, and how long the
## glass, broken through by the last word, holds together for the line to be read before it falls.
const LANDS := [2.0, 4.0, 6.0]
const KNOCKED := [2, 3, 5]
const HOLD_SECONDS := 1.0


## The glass up over the fight, and the words falling one by one onto the middle of it, each bigger
## than the last. Each lands with a jolt, cracks the glass further and knocks pieces out of it, and
## through the holes the fight shows. Returns what `_shatter` breaks.
func _intro() -> Dictionary:
	var view := Vector2(root.get_visible_rect().size)
	# Cut a little past the window, so a jolt (`_jolt`) never shows an edge.
	var pane := Pane.new(view / 2.0 + Vector2(0, 8), Rect2(Vector2.ZERO, view).grow(24.0), _rng)
	var glass := Node2D.new()
	var shown: Array[Polygon2D] = []
	for piece in pane.pieces:
		var part := Polygon2D.new()
		part.polygon = piece
		part.color = Color.BLACK
		glass.add_child(part)
		shown.append(part)
	_layer.add_child(glass)
	var cracks := Cracks.new()
	_layer.add_child(cracks)
	_black.hide()
	var gone: Array[int] = []
	# Over the glass and its cracks: the words fall onto it from the viewer's side.
	var words := [["Every", 64], ["click", 112], ["counts.", 224]]
	var labels: Array[Label] = []
	for word: Array in words:
		var label := _label(word[0], word[1], Palette.BONE)
		label.size = label.get_combined_minimum_size()
		# As massive as the window allows, a whole 16 px step at a time.
		while label.size.x > view.x - 48.0:
			var smaller: int = label.get_theme_font_size("font_size") - 16
			label.add_theme_font_size_override("font_size", smaller)
			label.add_theme_constant_override("outline_size", smaller / 4)
			label.size = Vector2.ZERO
			label.size = label.get_combined_minimum_size()
		labels.append(label)
	for i in labels.size():
		var drop := func() -> void:
			var label := labels[i]
			var land: float = LANDS[i]
			var rest := (view - label.size) / 2.0
			label.pivot_offset = label.size / 2.0
			# Falling at the glass from the viewer's side: huge and faint over the middle, shrinking
			# and quickening onto its place, and landing there at its own size.
			await _until(land - FALL)
			label.position = rest
			label.scale = Vector2.ONE * FALL_FROM
			label.modulate.a = 0.0
			label.show()
			var fall := label.create_tween().set_parallel()
			fall.tween_property(label, "scale", Vector2.ONE, _seconds(FALL)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.tween_property(label, "modulate:a", 1.0, _seconds(FALL) * 0.6)
			await _until(land)
			if i > 0:
				labels[i - 1].hide()
			for n in pane.loose(KNOCKED[i], gone, Rect2(Vector2.ZERO, view), _rng):
				gone.append(n)
				_fall_off(shown[n], pane, n)
			var lines := pane.cracks(i)
			for n in gone:
				lines.append(pane.outline(n))
			cracks.lines = lines
			cracks.queue_redraw()
			_jolt(6.0 + i * 4.0)
			# Knocked a little flat against the glass, and back.
			label.scale = Vector2.ONE * 0.92
			label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.15) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.call()
	return {"pane": pane, "glass": glass, "cracks": cracks, "labels": labels, "gone": gone}


## A piece knocked out of the glass: it drops away, turning, its broken edge lit so it reads against
## the black it falls across, and leaves a hole onto the fight.
func _fall_off(part: Polygon2D, pane: Pane, n: int) -> void:
	var start := pane.middle(n)
	var local := PackedVector2Array()
	for point in pane.pieces[n]:
		local.append(point - start)
	part.polygon = local
	part.position = start
	var edge := Line2D.new()
	edge.points = local
	edge.closed = true
	edge.width = 2.0
	edge.default_color = CRACK
	part.add_child(edge)
	# Over the rest of the glass while it falls.
	part.get_parent().move_child(part, -1)
	var drift := (start - pane.centre).normalized() * _rng.randf_range(20.0, 60.0) \
			+ Vector2(0, _rng.randf_range(-80.0, -20.0))
	var spin := _rng.randf_range(-2.5, 2.5)
	const DROP := 1.0
	var tumble := func(t: float) -> void:
		part.position = start + drift * t + Vector2(0, 1800.0) * t * t / 2.0
		part.rotation = spin * t
		part.modulate.a = clampf((DROP - t) / 0.3, 0.0, 1.0)
	var tween := part.create_tween().set_ignore_time_scale()
	tween.tween_method(tumble, 0.0, DROP, DROP)
	tween.tween_callback(part.queue_free)


## The broken glass letting go: what is left of it, as the window stands, words and cracks and all,
## drops off the fight piece by piece under its own weight -- a little drift and turn, nothing thrown.
func _shatter(glass: Dictionary) -> void:
	var pane: Pane = glass["pane"]
	var gone: Array[int] = glass["gone"]
	await RenderingServer.frame_post_draw
	var picture := ImageTexture.create_from_image(root.get_texture().get_image())
	glass["glass"].queue_free()
	glass["cracks"].queue_free()
	for label: Label in glass["labels"]:
		label.queue_free()
	# Long enough for a piece from the top edge, let go last, to clear the bottom one.
	const FLIGHT := 1.2
	const LET_GO := 0.3
	for n in pane.pieces.size():
		if n in gone:
			continue
		var polygon := pane.pieces[n]
		var middle := pane.middle(n)
		var shard := Polygon2D.new()
		shard.texture = picture
		shard.uv = polygon
		var local := PackedVector2Array()
		for point in polygon:
			local.append(point - middle)
		shard.polygon = local
		shard.position = middle
		_layer.add_child(shard)
		var drift := Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-40.0, 0.0))
		var spin := _rng.randf_range(-1.2, 1.2)
		var fall := func(t: float) -> void:
			shard.position = middle + drift * t + Vector2(0, 1800.0) * t * t / 2.0
			shard.rotation = spin * t
		var tween := shard.create_tween().set_ignore_time_scale()
		# Not all at once: each lets go a moment apart, so the pane crumbles rather than bursts.
		tween.tween_interval(_rng.randf_range(0.0, LET_GO))
		tween.tween_method(fall, 0.0, FLIGHT, FLIGHT)
		tween.tween_callback(shard.queue_free)


## Knocks the whole overlay about by up to `strength` pixels, dying away over a fifth of a second.
func _jolt(strength: float) -> void:
	var shake := _layer.create_tween().set_ignore_time_scale()
	for i in 5:
		var left := strength * (1.0 - i / 5.0)
		shake.tween_property(_layer, "offset",
				Vector2(_rng.randf_range(-left, left), _rng.randf_range(-left, left)).round(), 0.04)
	shake.tween_property(_layer, "offset", Vector2.ZERO, 0.04)


# ---- the pointer

## Moves the pointer onto the middle of `target` over `beats`, sending the motion the page would get
## from a real mouse, so what lights under a hovering cursor lights here too.
func _point_at(target: Control, beats: float) -> void:
	if target == null:
		push_warning("Nothing to point at")
		return
	var to := target.get_global_rect().get_center() - HAND_POINT * _cursor.scale
	var move := _cursor.create_tween().set_ignore_time_scale()
	move.tween_property(_cursor, "position", to, _seconds(beats)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	while move.is_running():
		_send_motion()
		await process_frame
	_send_motion()


## A press and a release under the pointer, a frame apart, with the pointer tilting as the game's does.
func _click() -> void:
	var at := _cursor.position + HAND_POINT * _cursor.scale
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		root.push_input(event)
		_cursor.rotation = deg_to_rad(-Cursors.TILT) if pressed else 0.0
		for i in 4:
			await process_frame


func _send_motion() -> void:
	var event := InputEventMouseMotion.new()
	event.position = _cursor.position + HAND_POINT * _cursor.scale
	event.global_position = event.position
	root.push_input(event)


func _slot(page: SkillsPage, id: String) -> Control:
	for slot: Node in page._skill_views[SkillTree.tree_of(id)].get_children():
		if slot is SkillSlot and slot.id == id:
			return slot
	return null


# ---- helpers

## The Gambler's Die worn and `stats` armed, on seeded dice so every take throws the same blows.
func _arm(fight: Encounter, stats: Dictionary) -> void:
	fight.wear(["gamble"], {"gamblers_die": DIE_RANK})
	fight.arm(stats)
	fight.crit_rng.seed = WORLD_SEED
	fight.gamble_rng.seed = WORLD_SEED


## What an average blow of `fight` comes to, crits and the Die's throw both at their mean.
func _blow(fight: Encounter) -> float:
	var top := UniqueTable.dial("gamblers_die", "top", DIE_RANK)
	return fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0) \
			* (Encounter.GAMBLE_LEAST + top) / 2.0


## Puts `fight` on screen. For the film the next body stands in the moment the last falls, and each
## is given `hits` average blows of health -- twice that for a boss; 0 leaves the health alone.
func _open(fight: Encounter, cell: Vector2i, variant: String, layout: int, env := "grass",
		place := "", hits := HITS) -> void:
	fight.walk_in = 0.0
	fight.enemy_died.connect(func(_index: int) -> void:
		fight.phase_left = minf(fight.phase_left, BODY_LIES))
	if hits > 0.0:
		fight.enemy_coming.connect(func(index: int, _enemy: String, _hp: float) -> void:
			var boss := Encounter.tier_in(fight, index) == EnemyRoster.Tier.BOSS
			fight.health[index] = roundf(_blow(fight) * hits * (2.0 if boss else 1.0))
			fight.hp = fight.health[index])
	_combat = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	_main.add_child(_combat)
	_combat.place = place if place != "" else TileNames.generate(cell, env, MAP_SEED, "small")
	_combat.xp_target = _main._character.xp_point()
	_combat.begin(fight, cell, _main.ui_scale, variant, layout, SKIES.get(env, "morning"))
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)


func _close_fight() -> void:
	_combat.queue_free()
	_combat = null


## Ranks `ids` in turn, going round again until none will take a point: a list cut short can leave a
## skill ahead of the points its row asks for.
func _learn(skills: Skills, ids: Array, level: int) -> void:
	var left := ids.duplicate()
	var learned := true
	while learned:
		learned = false
		for id: String in left.duplicate():
			if skills.rank_up(id, level):
				left.erase(id)
				learned = true


## Clicks the fight every `every` frames until `beat`, the way a player's press does
## (`CombatScene._unhandled_input`). `tick` runs first on every frame.
func _clicking(beat: float, every: int, tick := Callable()) -> void:
	while Engine.get_process_frames() < _frame_of(beat):
		var frame := Engine.get_process_frames() - _start
		if tick.is_valid():
			tick.call(frame)
		if frame % every == 0 and _combat != null and _combat.fight != null \
				and not _combat.fight.finished:
			_combat._swing()
			_combat.fight.hit()
			_combat._refresh()
		await process_frame


func _until(beat: float) -> void:
	while Engine.get_process_frames() < _frame_of(beat):
		await process_frame


func _frame_of(beat: float) -> int:
	return _start + roundi(_seconds(beat) * FPS)


## Beats gone since `beat`, by the frame count.
func _beats_since(beat: float) -> float:
	return _beats(float(Engine.get_process_frames() - _start) / FPS) - beat


func _seconds(beats: float) -> float:
	return beats * 60.0 / BPM


func _beats(seconds: float) -> float:
	return seconds * BPM / 60.0


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	root.add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Past the window's edges, so a jolt of the layer (`_jolt`) never shows what is behind it.
	for side in [SIDE_LEFT, SIDE_TOP]:
		_black.set_offset(side, -32.0)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_black.set_offset(side, 32.0)
	_layer.add_child(_black)
	# Above everything, in its own layer: a caption must not come between it and what it points at.
	var top := CanvasLayer.new()
	top.layer = 101
	root.add_child(top)
	_cursor = TextureRect.new()
	_cursor.texture = load(HAND_TILE)
	_cursor.scale = Vector2(2, 2)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.hide()
	top.add_child(_cursor)


## A caption's face: Pixellari at a whole multiple of its native 16 px, so it stays crisp, outlined
## and shadowed to read over anything. Hidden until it is due.
func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.theme = UITheme.theme()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", font_size / 4)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", font_size / 16)
	label.add_theme_constant_override("shadow_offset_y", font_size / 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.hide()
	_layer.add_child(label)
	return label


## A line punched in on `from` and gone by `to`, its middle at `height` of the window.
func _caption(text: String, from: float, to: float, height := 0.5, font_size := 96,
		colour := Palette.BONE) -> void:
	var label := _label(text, font_size, colour)
	var show := func() -> void:
		var size := Vector2(root.get_visible_rect().size)
		label.size = label.get_combined_minimum_size()
		label.position = Vector2((size.x - label.size.x) / 2.0, size.y * height - label.size.y / 2.0)
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2.ONE * 1.6
		label.show()
		# Blind to the slow motion a unique asks for: a caption keeps the music's time.
		var pop := label.create_tween().set_ignore_time_scale().set_parallel()
		pop.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		pop.chain().tween_interval(_seconds(to - from) - 0.4)
		pop.chain().tween_property(label, "modulate:a", 0.0, 0.2)
		pop.chain().tween_callback(label.queue_free)
	var wait := func() -> void:
		await _until(from)
		show.call()
	wait.call()
