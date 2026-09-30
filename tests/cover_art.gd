extends "res://tests/harness.gd"
## Renders the cover-art candidates out of the game's own pieces -- a backdrop, the fighters
## (`CombatActor`) held on a chosen frame of one of their animations, the loot beams (`LootBeam`), gear
## icons, coins, experience gems, the cursor (`Cursors`) and Pixellari -- at the backdrops' own size,
## 2304x1296. Every fighter is drawn one backdrop pixel a pixel, as the packs drew them against each
## other, rather than by the fight's size bands, which would give a crowd three sizes of pixel. Around
## them it takes liberties the fight does not: sparks, dust, speed lines, bodies in the air. Needs a
## window (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/cover_art.gd [-- clash leap ...]
## Names after `--` render only those covers; none renders all of them, each to
## user://cover_<name>.png.

const COVERS := ["horde_day", "horde_dusk", "haul", "clash", "aftermath", "leap", "boss"]
const SIZE := Vector2i(2304, 1296)
## One backdrop pixel on the cover: the backdrop drawn at its own size.
const PIXEL := CombatScene.AREA_UPSCALE * 1.0
## The fight's `ui_scale` at this size: 2 in its 1152-wide window, and this is twice that.
const UI := 4.0
## Where the fight stands everyone's feet: the top of the backdrop's ground strip.
const G := SIZE.y * CombatScene.GROUND
const DUSK := Color(0.86, 0.6, 0.68)
const AREA := "res://Assets/Area/%s.png"
const UNIQUE_ICON := "res://Assets/Gear/Unique/%s.png"
const TITLE := "Kobold Clicker"
const SUBTITLE := "An Idle Loot RPG"
## Pixels of cursor per pixel of its 16 px tile: big enough to read as the player's hand in it.
const CURSOR_PX := 12.0
## The red-and-gold chest of `Chests.png` (48x32 cells), closed.
const CHEST_CELL := Rect2i(0, 128, 48, 32)
## The coin's spin frames that face the viewer, or nearly: the edge-on ones read as a slit.
const COIN_FACES := [0, 1, 8, 2, 7]

## The effects, as letter pictures: each letter a colour in `INKS`, a dot clear.
const SPARK := [
	"......W......",
	"......W......",
	"......Y......",
	"..W...Y...W..",
	"...Y..Y..Y...",
	"....YYWYY....",
	"WWYYYWWWYYYWW",
	"....YYWYY....",
	"...Y..Y..Y...",
	"..W...Y...W..",
	"......Y......",
	"......W......",
	"......W......",
]
const TWINKLE := [
	"..W..",
	"..Y..",
	"WYWYW",
	"..Y..",
	"..W..",
]
const DUST := [
	"....dd.........",
	"..dDDDd..dd....",
	".dDDDDDddDDd.d.",
	"dDDDDDDDDDDDdDd",
	".ddddddddddddd.",
]
const INKS := {
	"W": Color("ffffff"),
	"Y": Palette.GOLD,
	"D": Color("d7b594"),
	"d": Color("a8836a"),
}


func _run() -> void:
	seed(7)
	var wanted := OS.get_cmdline_user_args()
	for cover: String in COVERS:
		if wanted.is_empty() or cover in wanted:
			await _shoot("cover_" + cover, Callable(self, "_" + cover))
	quit()


func _shoot(file: String, build: Callable) -> void:
	var view := SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	build.call(stage)
	# Long enough for every beam to have shot up.
	await create_timer(LootBeam.RISE + 0.5).timeout
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % file
	view.get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
	view.queue_free()
	await process_frame


# ---- the covers

func _horde_day(stage: Node2D) -> void:
	_horde(stage, false)


func _horde_dusk(stage: Node2D) -> void:
	_horde(stage, true)


## The hero, sword out, facing a line of monsters, the ground between them lit by what the last
## ones dropped; the cursor rests on the unique's name.
func _horde(stage: Node2D, dusk: bool) -> void:
	_backdrop(stage, AREA % "grass_plain_3", DUSK if dusk else Color.WHITE)
	var light := Color.WHITE.lerp(DUSK, 0.5) if dusk else Color.WHITE
	var line := [["Stone Golem", 2150.0], ["Skeleton Warrior", 1930.0], ["Imp", 1760.0],
			["Goblin", 1610.0]]
	for i in line.size():
		_fighter(stage, line[i][0], Vector2(line[i][1], G), light).z_index = 10 + i
	_find(stage, _gear("Iron Helmet"), ItemRarity.Rarity.RARE, Vector2(730, G))
	_find(stage, _gear("Jade Ring"), ItemRarity.Rarity.RARE, Vector2(880, G))
	_find(stage, _gear("Golden Kris"), ItemRarity.Rarity.ELITE, Vector2(990, G))
	var unique := _find(stage, _unique("stonebreaker"), ItemRarity.Rarity.UNIQUE, Vector2(1215, G))
	_fighter(stage, "", Vector2(430, G), light).z_index = 30
	var plate := _plate(stage, "Stonebreaker", unique.position - Vector2(0, 250))
	_cursor(stage, Cursors.HAND, plate.end - Vector2(30, 10))
	_title(stage, Vector2(80, 60), 0.0)


## The hero walking the road under a tower of loot; ahead, the cursor clicks an imp and what it drops
## arcs up onto the top of the pile, while more monsters wait their turn.
func _haul(stage: Node2D) -> void:
	_backdrop(stage, AREA % "grass_road_1")
	var hero := _fighter(stage, "", Vector2(560, G), Color.WHITE, "walk", 2)
	hero.z_index = 5
	var px := hero.scale.x
	# The pile stands on his back (a point measured off the run sheet's third frame, behind his
	# shoulders) and leans back off it as he walks.
	var base := _on_sheet(hero, Vector2(40, 62))
	var pile: Array = [
		[_chest(), 0],
		[_gear("Iron Shield"), -8],
		[_gear("Iron Armour"), -13],
		[_gear("Golden Helm"), -16],
		[_unique("crown_of_accord"), -20],
	]
	var foot := base
	var top := foot
	for i in pile.size():
		var piece := _piece(stage, pile[i][0], Vector2(base.x + pile[i][1] * px, foot.y), px, 4)
		top = piece.position
		foot = Vector2(base.x, piece.position.y + 3 * px)
	_piece(stage, _gear("Iron Claymore"), base + Vector2(-34, -30) * px, px, 3)
	_piece(stage, _gear("Golden Sceptre"), base + Vector2(2, -58) * px, px, 3)
	for spot in [Vector2(-34, 4), Vector2(-40, 20), Vector2(-44, 36)]:
		_coin(stage, base + spot * px, 6)

	var imp := _fighter(stage, "Imp", Vector2(1690, G), Color.WHITE)
	imp.z_index = 5
	_fighter(stage, "Desert Slime", Vector2(2020, G), Color.WHITE).z_index = 4
	_fighter(stage, "Goblin", Vector2(2200, G), Color.WHITE).z_index = 4

	var from := imp.position - Vector2(imp.drawn_size().x * 0.3, imp.drawn_size().y * 0.9)
	var to := top + Vector2(0, -20)
	var bend := Vector2((from.x + to.x) / 2.0, minf(from.y, to.y) - 380)
	_trail(stage, from, bend, to)
	for thing in [[_gear("Gold Ring"), 0.3], [_gear("Iron Dagger"), 0.55]]:
		_find(stage, thing[0], ItemRarity.Rarity.UNCOMMON, _bezier(from, bend, to, thing[1])).z_index = 20
	for t in [0.18, 0.42, 0.7]:
		_coin(stage, _bezier(from, bend, to, t), 20)
	var back := imp.position + Vector2(imp.drawn_size().x * 0.3, -imp.drawn_size().y * 0.6)
	_cursor(stage, Cursors.SWORD, back)
	_text(stage, "48!", CombatScene.CRIT_COLOR, 8.0, imp.position - Vector2(0, imp.drawn_size().y + 220), 0.5)
	_title(stage, Vector2(SIZE.x - 80, 60), 1.0)


## Mid-fight: the hero's slash knocks a goblin off its feet in a burst of coin and a unique, while
## the rest of the line comes on swinging, the golem at the back splitting the ground.
func _clash(stage: Node2D) -> void:
	_backdrop(stage, AREA % "grass_plain_2")
	# What went down before this one, lying in its light behind him.
	_fighter(stage, "Masked Orc", Vector2(150, G), Color.WHITE, "death", 9)
	_find(stage, _gear("Iron Helmet"), ItemRarity.Rarity.RARE, Vector2(180, G + 12))
	_fighter(stage, "Skeleton Warrior", Vector2(340, G), Color.WHITE, "death", 5)
	_find(stage, _gear("Golden Kris"), ItemRarity.Rarity.ELITE, Vector2(320, G + 18))

	var line := [["Stone Golem", 2130.0, "attack", 12], ["Minotaur", 1880.0, "attack", 2],
			["Masked Orc", 1600.0, "attack", 2]]
	for i in line.size():
		_fighter(stage, line[i][0], Vector2(line[i][1], G), Color.WHITE, line[i][2], line[i][3]).z_index = 5 + i
	_pixels(stage, DUST, Vector2(1660, G - 12), PIXEL, 12)

	var goblin := _fighter(stage, "Goblin", Vector2(1110, G - 70), Color.WHITE, "hurt", 0)
	goblin.z_index = 12
	var hero := _fighter(stage, "", Vector2(660, G), Color.WHITE, "attack", 2)
	hero.z_index = 14
	_pixels(stage, DUST, Vector2(570, G - 12), PIXEL, 15)

	var body := goblin.drawn_size()
	var struck := goblin.position - Vector2(body.x * 0.45, body.y * 0.45)
	_pixels(stage, SPARK, struck, PIXEL, 20)
	for spot in [Vector2(-60, -300), Vector2(40, -380), Vector2(140, -310), Vector2(210, -210),
			Vector2(-150, -230), Vector2(250, -90)]:
		_coin(stage, goblin.position + spot, 18)
	var flying := goblin.position + Vector2(-300, -560)
	_trail(stage, goblin.position - Vector2(0, body.y), goblin.position + Vector2(-110, -700), flying, 12)
	_find(stage, _unique("stonebreaker"), ItemRarity.Rarity.UNIQUE, flying, false).z_index = 20
	for spot in [Vector2(-130, -150), Vector2(120, -120), Vector2(-40, 30)]:
		_pixels(stage, TWINKLE, flying + spot, PIXEL, 21)
	_text(stage, "48!", CombatScene.CRIT_COLOR, 8.0, goblin.position + Vector2(60, -body.y - 300), 0.0)
	_cursor(stage, Cursors.SWORD, goblin.position + Vector2(body.x * 0.2, -body.y * 0.7))
	_title(stage, Vector2(80, 60), 0.0)


## After the blow: the hero follows through over a field of the fallen, each lying in its beam, the
## cursor on the unique's name, while the next wave is already coming at a run.
func _aftermath(stage: Node2D) -> void:
	_backdrop(stage, AREA % "grass_plain_3")
	var fallen := [
		["Goblin", 800.0, "death", 9, _gear("Jade Ring"), ItemRarity.Rarity.RARE],
		["Skeleton Warrior", 1040.0, "death", 5, _gear("Golden Kris"), ItemRarity.Rarity.ELITE],
		["Masked Orc", 1290.0, "death", 9, _unique("stonebreaker"), ItemRarity.Rarity.UNIQUE],
		["Imp", 1520.0, "death", 6, _gear("Iron Helmet"), ItemRarity.Rarity.RARE],
	]
	var unique: Sprite2D
	for body in fallen:
		_fighter(stage, body[0], Vector2(body[1], G), Color.WHITE, body[2], body[3])
		var find := _find(stage, body[4], body[5], Vector2(body[1] + 30, G + 14))
		if body[5] == ItemRarity.Rarity.UNIQUE:
			unique = find
		# Their experience, on its way up to the hero's bar.
		_gem(stage, Vector2(body[1] - 60, G - 340 - randi() % 140))
	var wave := [["Cyclops", 2170.0, "walk", 3], ["Minotaur", 1930.0, "walk", 3]]
	for i in wave.size():
		_fighter(stage, wave[i][0], Vector2(wave[i][1], G), Color.WHITE, wave[i][2], wave[i][3]).z_index = 5 + i
	_pixels(stage, DUST, Vector2(2040, G - 12), PIXEL, 20)
	_fighter(stage, "Harpy", Vector2(1720, G - 420), Color.WHITE, "walk", 3).z_index = 8
	_streaks(stage, Vector2(1880, G - 640), 20)
	_fighter(stage, "", Vector2(480, G), Color.WHITE, "attack", 4).z_index = 20
	var plate := _plate(stage, "Stonebreaker", unique.position - Vector2(0, 250))
	_cursor(stage, Cursors.HAND, plate.end - Vector2(30, 10))
	_title(stage, Vector2(80, 60), 0.0)


## The hero in the air, bringing his blade down on an imp that bursts into ash, coin and a unique;
## a harpy dives, a goblin charges and a cyclops winds up behind it.
func _leap(stage: Node2D) -> void:
	_backdrop(stage, AREA % "grass_road_3")
	_fighter(stage, "Masked Orc", Vector2(200, G), Color.WHITE, "death", 9)
	_find(stage, _gear("Golden Kris"), ItemRarity.Rarity.ELITE, Vector2(225, G + 14))
	_find(stage, _gear("Iron Helmet"), ItemRarity.Rarity.RARE, Vector2(420, G + 8))

	_fighter(stage, "Cyclops", Vector2(2060, G), Color.WHITE, "attack", 8).z_index = 4
	_fighter(stage, "Goblin", Vector2(1660, G), Color.WHITE, "walk", 0).z_index = 6
	_streaks(stage, Vector2(1790, G - 220), 7)
	_pixels(stage, DUST, Vector2(1740, G - 12), PIXEL, 7)
	_fighter(stage, "Harpy", Vector2(1640, G - 560), Color.WHITE, "attack", 3).z_index = 8

	var imp := _fighter(stage, "Imp", Vector2(1200, G), Color.WHITE, "death", 1)
	imp.z_index = 9
	_fighter(stage, "", Vector2(850, G - 330), Color.WHITE, "attack", 2).z_index = 12
	_pixels(stage, DUST, Vector2(640, G - 12), PIXEL, 5)
	_streaks(stage, Vector2(560, G - 520), 11, -1)

	var burst := imp.position - Vector2(0, imp.drawn_size().y * 0.6)
	_pixels(stage, SPARK, burst + Vector2(-60, -20), PIXEL, 20)
	for spot in [Vector2(-160, -300), Vector2(-40, -420), Vector2(90, -360), Vector2(190, -250),
			Vector2(240, -120), Vector2(-230, -160)]:
		_coin(stage, burst + spot, 18)
	var flying := burst + Vector2(80, -520)
	_trail(stage, burst, burst + Vector2(60, -700), flying, 12)
	_find(stage, _unique("crown_of_accord"), ItemRarity.Rarity.UNIQUE, flying, false).z_index = 20
	for spot in [Vector2(-120, -140), Vector2(130, -90), Vector2(20, 40)]:
		_pixels(stage, TWINKLE, flying + spot, PIXEL, 21)
	_text(stage, "96!", CombatScene.CRIT_COLOR, 8.0, burst + Vector2(190, -300), 0.0)
	_cursor(stage, Cursors.SWORD, imp.position + Vector2(imp.drawn_size().x * 0.25, -imp.drawn_size().y * 0.4))
	_title(stage, Vector2(80, 60), 0.0)


## The hero dashing through the last of the guard at a Huge Knight with his blade raised over his head.
func _boss(stage: Node2D) -> void:
	_backdrop(stage, AREA % "grass_plain_4")
	_find(stage, _unique("stonebreaker"), ItemRarity.Rarity.UNIQUE, Vector2(2210, G + 10))
	var knight := _fighter(stage, "Huge Knight", Vector2(1790, G), Color.WHITE, "attack", 4)
	knight.z_index = 5
	_fighter(stage, "Goblin", Vector2(1150, G), Color.WHITE, "death", 6).z_index = 6
	_find(stage, _gear("Iron Helmet"), ItemRarity.Rarity.RARE, Vector2(1170, G + 12))
	_fighter(stage, "Skeleton Warrior", Vector2(1390, G), Color.WHITE, "death", 2).z_index = 6
	_find(stage, _gear("Golden Kris"), ItemRarity.Rarity.ELITE, Vector2(1410, G + 16))
	_fighter(stage, "", Vector2(740, G), Color.WHITE, "walk", 6).z_index = 10
	_streaks(stage, Vector2(470, G - 230), 11, -1)
	_pixels(stage, DUST, Vector2(580, G - 12), PIXEL, 11)
	_pixels(stage, DUST, Vector2(440, G - 30), PIXEL, 11)
	var body := knight.drawn_size()
	_boss_plate(stage, "Huge Knight", Vector2(knight.position.x, 90))
	_cursor(stage, Cursors.SWORD, knight.position + Vector2(-body.x * 0.1, -body.y * 0.55))
	_title(stage, Vector2(80, 60), 0.0)


# ---- the pieces

func _backdrop(stage: Node2D, path: String, tint := Color.WHITE) -> void:
	var art := Sprite2D.new()
	art.texture = load(path)
	art.centered = false
	art.modulate = tint
	stage.add_child(art)


## A fighter -- `who` from EnemyRoster, or "" for the hero -- one backdrop pixel a pixel (`px` of
## one), feet on `feet`, held on one frame of `animation`.
func _fighter(stage: Node2D, who: String, feet: Vector2, light: Color, animation := "idle", frame := 0,
		px := 1.0) -> CombatActor:
	var actor := CombatActor.new()
	stage.add_child(actor)
	if who.is_empty():
		actor.setup_player(100.0)
	else:
		actor.setup_enemy(who, 100.0)
	actor.scale = Vector2.ONE * PIXEL * px
	actor.position = feet
	actor.self_modulate = light
	actor.play(animation)
	actor.pause()
	actor.frame = frame
	return actor


## Where a pixel of the hero's sheet frame lands on the cover.
func _on_sheet(actor: CombatActor, pixel: Vector2) -> Vector2:
	var feet := Vector2(actor.standing.position.x + actor.standing.size.x / 2.0, actor.standing.end.y)
	return actor.position + (pixel - feet) * actor.scale.x


func _gear(item: String) -> Texture2D:
	return load("res://Assets/Gear/%s.png" % item)


func _unique(id: String) -> Texture2D:
	return load(UNIQUE_ICON % id)


## A find with its foot on `foot`, drawn the way the fight draws one: at its rarity's size, standing
## in its beam if it has one and `lying` (one in the air has not landed, so has none yet).
func _find(stage: Node2D, icon: Texture2D, rarity: int, foot: Vector2, lying := true) -> Sprite2D:
	var find := Sprite2D.new()
	find.texture = icon
	var size: float = CombatScene.FIND_SIZE[rarity]
	if lying and LootBeam.has(rarity):
		var pillar := LootBeam.make(rarity, ItemRarity.BORDER_COLORS[rarity], 0.0,
				icon.get_size() * Vector2(0.5, 1.0) * size, PIXEL / UI)
		pillar.position = Vector2(0, icon.get_height() / 2.0)
		pillar.scale = Vector2.ONE / size
		find.add_child(pillar)
	find.scale = Vector2.ONE * UI * size
	find.position = foot - Vector2(0, icon.get_height() / 2.0 * UI * size)
	find.z_index = 1 + rarity
	stage.add_child(find)
	return find


## One piece of the pile: its drawn part (clear margins cut off) standing on `foot`, one of its pixels
## `px` of the cover's. Returns the sprite, whose `position` is the middle of its top edge.
func _piece(stage: Node2D, icon: Texture2D, foot: Vector2, px: float, z: int) -> Sprite2D:
	var image := icon.get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	var sprite := Sprite2D.new()
	sprite.texture = icon
	sprite.region_enabled = true
	sprite.region_rect = Rect2(used)
	sprite.centered = false
	sprite.offset = Vector2(-used.size.x / 2.0, 0)
	sprite.scale = Vector2(px, px)
	sprite.position = foot - Vector2(0, used.size.y * px)
	sprite.z_index = z
	stage.add_child(sprite)
	return sprite


func _chest() -> Texture2D:
	var cell := AtlasTexture.new()
	cell.atlas = load("res://Assets/Chests/Chests.png")
	cell.region = Rect2(CHEST_CELL)
	return ImageTexture.create_from_image(cell.get_image())


## A coin caught at some point of its spin where it faces the viewer.
func _coin(stage: Node2D, at: Vector2, z: int) -> void:
	var coin := Sprite2D.new()
	coin.texture = Coins.SHEET
	coin.region_enabled = true
	coin.region_rect = Rect2(COIN_FACES.pick_random() * Coins.SIZE, 0, Coins.SIZE, Coins.SIZE)
	coin.scale = Vector2(UI, UI)
	coin.position = at
	coin.z_index = z
	stage.add_child(coin)


## One of the fight's experience gems, drawn at its size there.
func _gem(stage: Node2D, at: Vector2) -> void:
	var gem := Sprite2D.new()
	gem.texture = CombatScene.XP_GEM
	gem.scale = Vector2.ONE * UI * CombatScene.XP_GEM_SCALE
	gem.position = at
	gem.z_index = 25
	stage.add_child(gem)


## A letter picture (`INKS`), `px` cover pixels a pixel, centred on `centre`.
func _pixels(stage: Node2D, rows: Array, centre: Vector2, px: float, z: int) -> void:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if INKS.has(rows[y][x]):
				image.set_pixel(x, y, INKS[rows[y][x]])
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.scale = Vector2(px, px)
	sprite.position = centre.snapped(Vector2(px, px))
	sprite.z_index = z
	stage.add_child(sprite)


## Speed lines trailing whatever is at `at`, running off behind it (`toward` 1 to the right, -1 to
## the left), a backdrop pixel thick.
func _streaks(stage: Node2D, at: Vector2, z: int, toward := 1.0) -> void:
	for line in [[0, 36, 0], [40, 22, 4], [90, 30, 1], [140, 18, 6], [180, 26, 2]]:
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.75)
		bar.size = Vector2(line[1] * PIXEL, PIXEL)
		var start := at + Vector2(line[2] * PIXEL * toward, line[0])
		bar.position = (start if toward > 0 else start - Vector2(bar.size.x, 0)).snapped(Vector2(PIXEL, PIXEL))
		bar.z_index = z
		stage.add_child(bar)


## A dotted line along the arc from `from` bent toward `bend` to `to`, a backdrop pixel a dot.
func _trail(stage: Node2D, from: Vector2, bend: Vector2, to: Vector2, z := 15) -> void:
	for i in range(1, 30):
		var dot := ColorRect.new()
		dot.color = Color(Palette.BONE, 0.8)
		dot.size = Vector2(PIXEL, PIXEL)
		dot.position = _bezier(from, bend, to, i / 30.0).snapped(Vector2(PIXEL, PIXEL))
		dot.z_index = z
		stage.add_child(dot)


func _bezier(from: Vector2, bend: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(bend, t).lerp(bend.lerp(to, t), t)


func _cursor(stage: Node2D, shape: int, tip: Vector2) -> void:
	var spec: Array = Cursors.SHAPES[shape]
	var sprite := Sprite2D.new()
	sprite.texture = load(Cursors.TILE % spec[0])
	sprite.centered = false
	sprite.scale = Vector2(CURSOR_PX, CURSOR_PX)
	sprite.position = tip - spec[1] * CURSOR_PX
	sprite.z_index = 100
	stage.add_child(sprite)


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.theme = UITheme.theme()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Text in the fight's outlined label, `scale` times its native size, its top at `at.y` and
## `align` of its width left of `at.x` (0 left, 0.5 centred, 1 right).
func _text(stage: Node2D, text: String, colour: Color, scale: float, at: Vector2, align: float) -> Label:
	var label := _label(text, colour)
	label.add_theme_constant_override("outline_size", CombatScene.LABEL_OUTLINE)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.scale = Vector2(scale, scale)
	label.z_index = 110
	stage.add_child(label)
	label.position = at - Vector2(label.get_combined_minimum_size().x * scale * align, 0)
	return label


func _title(stage: Node2D, at: Vector2, align: float) -> void:
	var title := _text(stage, TITLE, Palette.GOLD, 8.0, at, align)
	_text(stage, SUBTITLE, Palette.BONE, 4.0,
			Vector2(at.x, at.y + title.get_combined_minimum_size().y * 8.0), align)


## A find's name on a dark plate under the cursor, the way a loot game labels what lies on the
## ground. Returns the plate's rectangle on the cover.
func _plate(stage: Node2D, text: String, centre: Vector2) -> Rect2:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.INK, 0.85)
	box.border_color = Palette.BONE
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(_label(text, ItemRarity.BORDER_COLORS[ItemRarity.Rarity.UNIQUE]))
	panel.scale = Vector2(UI, UI)
	panel.z_index = 90
	stage.add_child(panel)
	var size := panel.get_combined_minimum_size() * UI
	panel.position = (centre - size / 2.0).snapped(Vector2(UI, UI))
	return Rect2(panel.position, size)


## A boss's name the way the fight crowns it: gold, a crown either side, its top centred on `at`.
func _boss_plate(stage: Node2D, text: String, at: Vector2) -> void:
	var name := _text(stage, text, Palette.GOLD, 8.0, at, 0.5)
	var half := name.get_combined_minimum_size() * 8.0 / 2.0
	var crown: Texture2D = load("res://Assets/UI/ui_icon_crown.png")
	for side in [-1.0, 1.0]:
		var mark := Sprite2D.new()
		mark.texture = crown
		mark.scale = Vector2(UI * 2, UI * 2)
		mark.position = at + Vector2(side * (half.x + crown.get_width() * UI * 1.4), half.y)
		mark.z_index = 110
		stage.add_child(mark)
