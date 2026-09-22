extends "res://tests/harness.gd"
## Headless checks for the 9-slice UI theme. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_ui_theme.gd

func _run() -> void:
	var theme := UITheme.build()
	_check(_test_sheet() == true, "sheet JSON tests ran to the end")
	_check(_test_panels(theme) == true, "panel tests ran to the end")
	_check(_test_buttons(theme) == true, "button tests ran to the end")
	_check(_test_icon_faces(theme) == true, "icon face tests ran to the end")
	_check(_test_icon_buttons(theme) == true, "icon button tests ran to the end")
	_check(_test_controls(theme) == true, "live control tests ran to the end")
	_check(_test_orb_tray() == true, "orb tray tests ran to the end")
	_check(_test_health_bar() == true, "health bar tests ran to the end")
	_check(_test_character_panel() == true, "character panel tests ran to the end")
	_check(await _test_item_card() == true, "item card tests ran to the end")
	_check(_test_cursors() == true, "cursor tests ran to the end")
	_check(_test_tip_card() == true, "tip card tests ran to the end")
	_check(_test_accordion() == true, "accordion tests ran to the end")
	_report("UI theme")


func _test_sheet() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))
	var meta: Dictionary = data["meta"]
	var sheet: Texture2D = load(UITheme.SHEET_JSON.get_base_dir().path_join(meta["image"]))
	var sheet_size := Vector2i(int(meta["sheet_size"][0]), int(meta["sheet_size"][1]))
	_check(sheet != null and sheet.get_size() == Vector2(sheet_size), "the sheet matches its declared size")

	var names := {}
	for sprite: Dictionary in data["sprites"]:
		names[sprite["name"]] = true
		var region := Rect2i(sprite["x"], sprite["y"], sprite["w"], sprite["h"])
		_check(Rect2i(Vector2i.ZERO, sheet_size).encloses(region), "%s lies inside the sheet" % sprite["name"])
		# The margins are what makes a sprite a nine-slice: they have to leave a centre to tile.
		var margin: Dictionary = sprite["margin"]
		_check(int(margin["left"]) + int(margin["right"]) < region.size.x
				and int(margin["top"]) + int(margin["bottom"]) < region.size.y,
				"%s keeps a centre between its margins" % sprite["name"])

	var expected: Array[String] = []
	for variation: String in UITheme.PANELS:
		expected.append(UITheme.PANELS[variation])
	# Off UITheme's own table rather than off a list written twice: a family the theme asks for and
	# the sheet does not hold is exactly what the count below is here to catch.
	for variation: String in UITheme.BUTTONS:
		for state: String in UITheme.STATES:
			expected.append("ui_btn_%s_%s_%s" % [UITheme.BUTTONS[variation][0],
					UITheme.BUTTONS[variation][1], state])
	for variation: String in UITheme.ICON_FACES:
		for state: String in UITheme.STATES:
			expected.append("%s_%s" % [UITheme.ICON_FACES[variation], state])
	for variation: String in UITheme.ICON_BUTTONS:
		for state: String in UITheme.STATES:
			expected.append("%s_%s" % [UITheme.ICON_BUTTONS[variation], state])
	for name: String in expected:
		_check(names.has(name), "the sheet has %s" % name)
	_check(names.size() == expected.size(), "the sheet has exactly %d sprites" % expected.size())
	return true


func _test_panels(theme: Theme) -> bool:
	for variation: String in UITheme.PANELS:
		_check(theme.get_type_variation_base(variation) == "PanelContainer", "%s is a PanelContainer" % variation)
		var box := theme.get_stylebox("panel", variation)
		_check(_is_nine_slice(box, UITheme.PANELS[variation], variation) == true,
				"%s is a tiled 9-slice" % variation)
		# The bar is trim rather than a container, so it pads its title far less than a panel does.
		var pad := UITheme.BAR_MARGIN.x if variation == "HeaderBar" else UITheme.PANEL_MARGIN
		_check(box.content_margin_left == pad, "%s pads its contents" % variation)
	return true


func _test_buttons(theme: Theme) -> bool:
	for variation: String in UITheme.BUTTONS:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		var surface: String = UITheme.BUTTONS[variation][0]
		var variant: String = UITheme.BUTTONS[variation][1]
		for state: String in UITheme.STATES:
			_check(theme.has_stylebox(state, variation), "%s has a %s style" % [variation, state])
			var sprite_name := "ui_btn_%s_%s_%s" % [surface, variant, state]
			_check(_is_nine_slice(theme.get_stylebox(state, variation), sprite_name, variation) == true,
					"%s %s is a tiled 9-slice" % [variation, state])
		# Pressed inverts the bevel, so its label sits one pixel lower than in any other state.
		var normal := theme.get_stylebox("normal", variation)
		var pressed := theme.get_stylebox("pressed", variation)
		_check(pressed.content_margin_top == normal.content_margin_top + 1, "%s sinks when pressed" % variation)
		_check(pressed.content_margin_bottom == normal.content_margin_bottom - 1,
				"%s keeps its height when pressed" % variation)
		_check(theme.has_color("font_disabled_color", variation), "%s dims its label when disabled" % variation)
	return true


## An icon face is a stretched 9-slice like a lettered button, but padded equally on all four sides:
## the claim is that one wearing a square mark comes out square, whatever the mark is.
func _test_icon_faces(theme: Theme) -> bool:
	for variation: String in UITheme.ICON_FACES:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		for state: String in UITheme.STATES:
			var sprite_name: String = "%s_%s" % [UITheme.ICON_FACES[variation], state]
			_check(_is_nine_slice(theme.get_stylebox(state, variation), sprite_name, variation) == true,
					"%s %s is a tiled 9-slice" % [variation, state])
		var normal := theme.get_stylebox("normal", variation)
		_check(normal.content_margin_left == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_right == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_top == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_bottom == UITheme.ICON_FACE_MARGIN,
				"%s pads its mark the same on all four sides" % variation)
		var pressed := theme.get_stylebox("pressed", variation)
		_check(pressed.content_margin_top == normal.content_margin_top + 1, "%s sinks when pressed" % variation)
		_check(pressed.content_margin_bottom == normal.content_margin_bottom - 1,
				"%s keeps its height when pressed" % variation)

	# The marks themselves, and the size a button wearing one comes out at. Both are cut on one
	# square by tools/ui_kit.py precisely so the corner's two buttons are the same size; a Button
	# takes its minimum from its icon, so an untrimmed mark would be the end of that.
	# The main scene has no class_name, so its constants are read off the script resource itself.
	var scene := preload("res://Scenes/main_scene.gd")
	var side := 0
	for path: String in [scene.CHEST_ICON, scene.STAR_ICON]:
		var texture: Texture2D = load(path)
		_check(texture != null, "%s is on disk" % path)
		if texture == null:
			continue
		_check(texture.get_width() == texture.get_height(), "%s is a square" % path)
		_check(side == 0 or texture.get_width() == side, "%s is the size the other marks are" % path)
		side = texture.get_width()
	var button := Button.new()
	button.theme = theme
	button.theme_type_variation = UITheme.ICON_FACES.keys()[0]
	button.icon = load(scene.CHEST_ICON)
	button.expand_icon = false
	root.add_child(button)
	var wanted := side + 2 * UITheme.ICON_FACE_MARGIN
	_check(button.get_combined_minimum_size() == Vector2(wanted, wanted),
			"an icon face comes out square (%s)" % button.get_combined_minimum_size())
	button.queue_free()
	return true


## An icon button is drawn, not stretched: no texture margin, no content margin, and the four states
## are the one sprite the pack drew plus the three the pack's own rules give it.
func _test_icon_buttons(theme: Theme) -> bool:
	for variation: String in UITheme.ICON_BUTTONS:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		var size := UITheme.icon_size(variation)
		_check(size.x > 0 and size.y > 0, "%s knows how big it is (%s)" % [variation, size])
		for state: String in UITheme.STATES:
			var box := theme.get_stylebox(state, variation) as StyleBoxTexture
			_check(box != null, "%s %s draws from the sheet" % [variation, state])
			if box == null:
				continue
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_check(box.get_texture_margin(side) == 0,
						"%s %s is never sliced" % [variation, state])
				_check(box.get_content_margin(side) <= 0,
						"%s %s pads nothing" % [variation, state])
			_check(box.texture.region.size == Vector2(size),
					"%s %s is the size the pack drew" % [variation, state])
	return true


## The theme has to work on real nodes, not just as a resource.
func _test_controls(theme: Theme) -> bool:
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.theme_type_variation = "WoodPanel"
	root.add_child(panel)
	var button := Button.new()
	button.theme_type_variation = "LightDangerButton"
	panel.add_child(button)
	_check(button.get_theme_stylebox("normal") == theme.get_stylebox("normal", "LightDangerButton"),
			"a child button resolves its variation through the panel's theme")
	_check(button.get_combined_minimum_size().x <= _sprite("ui_btn_light_danger_normal")["w"],
			"an empty button fits in one sprite width (%s)" % button.get_combined_minimum_size())
	panel.queue_free()
	return true


## The sheet entry `sprite_name` describes, so a margin is checked against the JSON rather than
## against a number repeated here.
func _sprite(sprite_name: String) -> Dictionary:
	for sprite: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))["sprites"]:
		if sprite["name"] == sprite_name:
			return sprite
	_check(false, "the sheet has %s" % sprite_name)
	return {"w": 0, "h": 0, "margin": {"left": 0, "top": 0, "right": 0, "bottom": 0}}


func _is_nine_slice(box: StyleBox, sprite_name: String, what: String) -> bool:
	var textured := box as StyleBoxTexture
	if textured == null:
		_check(false, "%s uses a StyleBoxTexture" % what)
		return false
	var margin: Dictionary = _sprite(sprite_name)["margin"]
	var sides := {SIDE_LEFT: "left", SIDE_TOP: "top", SIDE_RIGHT: "right", SIDE_BOTTOM: "bottom"}
	for side: Side in sides:
		_check(textured.get_texture_margin(side) == int(margin[sides[side]]),
				"%s takes its %s margin from the sheet" % [what, sides[side]])
	_check(textured.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			and textured.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
			"%s tiles rather than stretches" % what)
	_check(textured.texture is AtlasTexture, "%s draws from the shared sheet" % what)
	return true


## The orb tray is exactly as wide as the bag's grid, and every icon it draws is the size it is drawn
## at. Held here the way KillPips asserts its own parts still add up: the row is assembled from eight
## fixed squares and a gap worked out from what is left over, so a change to either number that broke
## the arithmetic would show as a tray a few pixels out rather than as anything that looks wrong.
## The card that stands beside a hovered piece: it finds the square under the cursor without the
## square taking the mouse, keeps quiet about the open one and about one scrolled out of its box.
func _test_item_card() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng)
	var box := ScrollContainer.new()
	box.position = Vector2(100, 100)
	box.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	root.add_child(box)
	var column := VBoxContainer.new()
	box.add_child(column)
	var seen := ItemSlot.make(sword)
	var below := ItemSlot.make(sword)
	column.add_child(seen)
	column.add_child(below)
	var open := ItemSlot.make(sword, true)
	open.position = Vector2(300, 100)
	open.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	root.add_child(open)
	var card := ItemCard.new(2.0)
	root.add_child(card)
	await process_frame
	await process_frame
	_check(seen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a square still takes no mouse")
	var raised := Item.from_dict(sword.to_dict())
	raised.plus = 2
	var marked := ItemSlot.make(raised)
	_check(not seen.get_children().any(func(n: Node) -> bool: return n is Label)
			and (marked.get_child(marked.get_child_count() - 1) as Label).text == "+2",
			"a piece with a plus wears it on its corner, one without wears nothing")
	marked.free()
	_check(card.slot_at(Vector2(110, 110)) == seen, "the square under the cursor is found")
	_check(card.slot_at(below.get_global_rect().get_center()) == null,
			"one scrolled out of its box is not")
	_check(card.slot_at(Vector2(310, 110)) == open, "the open piece has a card too: nothing else says what it is")
	_check(card.slot_at(Vector2(5, 5)) == null, "and bare window is nothing")
	_check(card.hovered(Vector2(110, 110), false) == seen, "a hovered square gets its card")
	_check(card.hovered(Vector2(110, 110), true) == null, "a press puts the card away")
	_check(card.hovered(Vector2(110, 110), false) == null, "and letting go does not bring it back")
	_check(card.hovered(Vector2(112, 112), false) == null, "nor does moving about on the same piece")
	_check(card.hovered(Vector2(5, 5), false) == null and card.hovered(Vector2(110, 110), false) == seen,
			"until the cursor has been somewhere else")
	_check(card.theme_type_variation == "TextPanel" and card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"it is a cream panel that never takes a press")
	# The second card, under Alt: what is worn where the hovered piece would go.
	_check(card.worn_for(sword) == null, "nothing to hold a piece against with no equipment")
	card.equipment = Equipment.new()
	_check(card.worn_for(sword) == null, "or with nothing on")
	_check(card.bare_for(sword), "which Alt says in so many words, rather than doing nothing")
	_check(card.bare_text(sword) == "Nothing is equipped in the weapon slot", "naming the socket it means")
	var other := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng)
	card.equipment.worn[Equipment.Socket.WEAPON] = other
	_check(card.worn_for(sword) == other, "a worn sword is what a hovered sword is held against")
	_check(card.worn_for(other) == null, "and the worn piece is not held against itself")
	_check(not card.bare_for(sword) and not card.bare_for(other),
			"and a taken socket, or the worn piece itself, is not called bare")
	# The keys at the card's foot: Alt while the card can answer it, and whatever the square names.
	for key: String in ItemCard.KEY_ICONS:
		_check(ResourceLoader.exists(ItemCard.KEY_ICONS[key]), "the %s key is cut" % key)
	var row := ItemCard.key_row({"alt": "compare", "shift": "equip"})
	_check(row.get_child_count() == 2 and row.get_child(0).get_child(0) is TextureRect
			and (row.get_child(0).get_child(1) as Label).text == "compare"
			and (row.get_child(1).get_child(1) as Label).text == "equip",
			"a key row is a picture and a word a key, each pair a box that wraps whole")
	_check((row.get_child(0).get_child(0) as TextureRect).texture.get_size() == Vector2(18, 12),
			"the picture at the key's own size")
	_check(row.custom_minimum_size.x == ItemCard.WIDTH, "wrapping inside the card")
	seen.set_meta(ItemCard.KEYS, {"ctrl": "discard"})
	_check(card.hints_for(seen, false) == {"alt": "compare", "ctrl": "discard"},
			"over a bag square the foot names Alt and the square's own key")
	_check(card.hints_for(seen, true) == {"ctrl": "discard"},
			"held, Alt is answered by the second card and leaves the foot")
	var worn_square := ItemSlot.make(other)
	_check(card.hints_for(worn_square, false) == {}, "the worn piece itself has no Alt to offer")
	worn_square.free()
	row.free()
	for node: Node in [box, open, card]:
		node.queue_free()
	return true


func _test_orb_tray() -> bool:
	var cols: int = BagPage.ORB_COLS
	var gap: int = BagPage.ORB_GAP
	var width: int = BagPage.WIDTH
	var assembled := cols * OrbSlot.SIDE + (cols - 1) * gap
	_check(assembled <= width and width - assembled < cols - 1,
			"six orbs and their gaps come to %d, not the grid's %d" % [assembled, width])
	_check(cols == OrbTable.ORBS.size(),
			"the tray has a square for each of the %d orbs" % OrbTable.ORBS.size())
	_check(gap > 0, "the squares do not touch")
	_check(OrbSlot.ICON * 2 == ItemSlot.ICON,
			"an orb is drawn at exactly half the size it is cut at, so its pixels stay square")
	_check(OrbSlot.SIDE > OrbSlot.ICON, "an orb square has a gutter round its icon")
	# Every orb builds into a live square, and the three states are three different pictures. That
	# last part is the whole of what the tray communicates, and it is the one thing a table of names
	# cannot tell us: an orb never found, one held but useless here, and one ready to spend have to
	# be told apart at a glance in a row of six.
	for orb: String in OrbTable.orbs():
		var ghost := OrbSlot.make(orb, 0, true)
		var dim := OrbSlot.make(orb, 2, false)
		var lit := OrbSlot.make(orb, 2, true)
		for slot: OrbSlot in [ghost, dim, lit]:
			_check(slot.custom_minimum_size == Vector2(OrbSlot.SIDE, OrbSlot.SIDE),
					"%s builds a %d square" % [orb, OrbSlot.SIDE])
			_check(slot.mouse_filter == Control.MOUSE_FILTER_STOP,
					"%s takes the mouse, unlike an item square" % orb)
		# Approximately: a Color's components are single-precision, so they never compare equal to a
		# double literal on the nose.
		_check(is_equal_approx(ghost._icon.modulate.a, ItemSlot.EMPTY_MARK_ALPHA),
				"%s never found is drawn faint" % orb)
		_check(lit._icon.modulate.is_equal_approx(Color.WHITE),
				"%s ready to spend is drawn plain" % orb)
		_check(dim._icon.modulate.is_equal_approx(OrbSlot.DIM),
				"%s held but useless is drawn grey" % orb)
		_check(dim._icon.modulate != ghost._icon.modulate,
				"%s tells 'not yours' from 'not for this' " % orb)
		# A count past one is drawn and a count of one is not -- seven squares wearing a 1 would be
		# seven numbers saying nothing.
		_check(_labels_in(OrbSlot.make(orb, 1, true)) == 0, "%s held once wears no count" % orb)
		_check(_labels_in(OrbSlot.make(orb, 2, true)) == 1, "%s held twice wears a count" % orb)
		for slot: OrbSlot in [ghost, dim, lit]:
			slot.free()
	return true


## The nameplate's health bar, held the way the orb tray and the pip bar are: it is assembled from
## generated parts against constants written down before anything is laid out, so what can go wrong
## is arithmetic rather than appearance. Two things matter beyond the parts fitting together.
##
## The trough has to be the same length in all three tiers, because the fill is a share of it: if a
## boss's channel were shorter, half a bar would mean a different number of hit points depending on
## what walked in. And the ornament has to actually grow, which is the whole promise of the elite and
## boss frames and the one part of "more intricate" that can be stated as a number.
func _test_health_bar() -> bool:
	var tiers: Array = [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]
	var caps: Array[int] = []
	var troughs := {}
	for tier: EnemyRoster.Tier in tiers:
		var cap_l: Texture2D = HealthBar.CAP_L[tier]
		var cap_r: Texture2D = HealthBar.CAP_R[tier]
		var track: Texture2D = HealthBar.TRACK[tier]
		caps.append(int(cap_l.get_width()))
		# Every part is one height, or the row they are butted into would step.
		for part: Texture2D in [cap_l, cap_r, track]:
			_check(part.get_height() == HealthBar.HEIGHT,
					"a tier %d part is %d tall, not HEIGHT" % [tier, part.get_height()])
		_check(cap_l.get_width() == cap_r.get_width(), "tier %d's two caps differ in width" % tier)
		_check(track.get_width() == 4, "tier %d's track is not the 4 px the trough maths assumes" % tier)
		# A cap's last column is a channel column, which is the one at each end.
		troughs[2 + HealthBar.SEGMENTS * track.get_width()] = true
		_check(HealthBar.width_of(tier)
				== (cap_l.get_width() + HealthBar.SEGMENTS * track.get_width() + cap_r.get_width())
				* HealthBar.PIXEL, "tier %d's width_of agrees with its parts" % tier)
	_check(troughs.size() == 1 and troughs.has(HealthBar.TROUGH),
			"every tier leaves TROUGH (%d) px of channel: found %s" % [HealthBar.TROUGH, troughs.keys()])
	_check(caps == [3, 9, 13] and caps[0] < caps[1] and caps[1] < caps[2],
			"the ornament grows common to elite to boss: caps are %s" % [caps])
	_check(HealthBar.CHANNEL_TOP + HealthBar.CHANNEL_HEIGHT < HealthBar.HEIGHT,
			"the channel leaves a rim under it as well as over it")

	# And a live bar: the pieces are laid out at the size they are drawn, the fill sits on the
	# channel, and it never says nothing while something is still standing.
	var bar := HealthBar.new()
	bar.show_health(EnemyRoster.Tier.COMMON, 1.0)
	var common_width := bar.custom_minimum_size.x
	_check(common_width == HealthBar.width_of(EnemyRoster.Tier.COMMON),
			"a common bar measures its own width")
	for part: TextureRect in ([bar._cap_l, bar._cap_r] as Array[TextureRect]) + bar._tracks:
		_check(part.custom_minimum_size == part.texture.get_size() * HealthBar.PIXEL,
				"every piece is laid out at PIXEL, not scaled after the fact")
	_check(bar._fill.size == Vector2(HealthBar.TROUGH * HealthBar.PIXEL,
			HealthBar.CHANNEL_HEIGHT * HealthBar.PIXEL), "a full bar fills the whole channel")
	_check(bar._fill.position.y == HealthBar.CHANNEL_TOP * HealthBar.PIXEL,
			"the fill sits on the channel rather than over the rim")
	bar.show_health(EnemyRoster.Tier.COMMON, 0.0)
	_check(bar._fill.size.x == 0.0, "an empty bar shows no red at all")
	bar.show_health(EnemyRoster.Tier.COMMON, 0.001)
	_check(bar._fill.size.x == HealthBar.PIXEL,
			"an enemy on its last hit point still shows a sliver")
	# Changing tier moves where the channel starts but not how long it is, and widens the bar.
	bar.show_health(EnemyRoster.Tier.BOSS, 1.0)
	_check(bar.custom_minimum_size.x > common_width, "a boss's bar is wider than a common's")
	_check(bar._fill.size.x == HealthBar.TROUGH * HealthBar.PIXEL,
			"a boss's full bar is exactly as much red as a common's")
	_check(bar._fill.position.x
			== (HealthBar.CAP_L[EnemyRoster.Tier.BOSS].get_width() - 1) * HealthBar.PIXEL,
			"the fill moved in behind the boss's ornament")
	bar.free()
	return true


## How many Labels a square is carrying, which is how the count is checked for without reaching for
## a node path that would break the moment the square is built differently.
func _labels_in(slot: OrbSlot) -> int:
	var found := 0
	for child: Node in slot.get_children():
		if child is Label:
			found += 1
	slot.free()
	return found


## The character panel: every bar lies inside the frame, the portrait inside it too, and the XP bar
## empties by whole sprite pixels, never to nothing while there is anything to show.
func _test_character_panel() -> bool:
	var frame := CharacterPanel.FRAME.get_size()
	var portrait := CharacterPanel.PORTRAIT.get_size()
	_check(Vector2(CharacterPanel.PORTRAIT_AT) + portrait <= frame, "the portrait fits in the frame")
	for bar: String in CharacterPanel.BARS:
		var texture: Texture2D = load(CharacterPanel.ROOT + "ui_char_bar_%s.png" % bar)
		_check(texture != null, "the %s bar exists" % bar)
		var end := Vector2(CharacterPanel.BARS[bar]) + texture.get_size()
		_check(end.x <= frame.x and end.y <= frame.y, "the %s bar lies inside the frame" % bar)
	var gem: Texture2D = load("res://Assets/UI/xp_gem.png")
	_check(gem != null and gem.get_size() == Vector2(6, 6), "the gem is the 6 px cut")

	var panel := CharacterPanel.new()
	root.add_child(panel)
	var full: int = roundi(load(CharacterPanel.ROOT + "ui_char_bar_xp.png").get_width())
	_check(panel.shown_pixels("xp") == 0, "no experience shows no bar")
	_check(panel.shown_pixels("hp") == roundi(load(CharacterPanel.ROOT + "ui_char_bar_hp.png").get_width()),
			"health stands full")
	# A level deep enough that one point is far under half a pixel, which would round to nothing.
	panel.set_state(10, 1)
	_check(panel.shown_pixels("xp") == 1, "one point still shows one pixel")
	panel.set_state(1, PlayerLevel.xp_to_next(1) / 2)
	_check(absi(panel.shown_pixels("xp") - full / 2) <= 1, "half shows half: %d of %d"
			% [panel.shown_pixels("xp"), full])
	_check(panel.absorb(PlayerLevel.xp_to_next(1)) == 1 and panel.level == 2, "absorbing a level levels up")
	_check(panel.size.y > frame.y * CharacterPanel.PIXEL, "the name line stands over the frame")
	_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the panel never takes the mouse")
	panel.queue_free()
	return true


## Every live button that joins the tree points; one that chose a cursor keeps it, a dead one keeps
## the arrow, and a tile for every shape is there to be drawn.
func _test_cursors() -> bool:
	Cursors.install(self, 2)
	for shape: int in Cursors.SHAPES:
		_check(ResourceLoader.exists(Cursors.TILE % Cursors.SHAPES[shape][0]), "shape %d has its tile" % shape)
	var plain := Button.new()
	var smith := Button.new()
	Cursors.wear(smith, Cursors.HAMMER)
	var dead := Button.new()
	dead.disabled = true
	for button: Button in [plain, smith, dead]:
		root.add_child(button)
	_check(plain.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "a button gets the hand")
	_check(smith.mouse_default_cursor_shape == Control.CURSOR_BUSY, "a chosen cursor is kept")
	_check(dead.mouse_default_cursor_shape == Control.CURSOR_ARROW, "a dead button keeps the arrow")
	for button: Button in [plain, smith, dead]:
		button.queue_free()
	# A press tilts the picture about the tile's bottom right corner; the hotspot keeps its place.
	var pair: Array = Cursors._drawn[Cursors.HAND]
	var pad: Vector2 = (pair[2].get_size() - pair[0].get_size()) / 2.0
	_check(pair[3] == pair[1] + pad, "the tilted hand clicks where the straight one does")
	_check(pair[2].get_image().get_used_rect().size != pair[0].get_image().get_used_rect().size, "and it is turned")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Cursors.twitch(self, press)
	_check(Cursors._twitched == Input.get_current_cursor_shape(), "a press twitches the cursor under it")
	Cursors.put_away()
	_check(Cursors._twitched == -1, "and putting the cursors away forgets it")
	return true


## Whose words the tip card writes: Godot's own rule, since it stands in for Godot's tooltip.
func _test_tip_card() -> bool:
	var row := HBoxContainer.new()
	row.tooltip_text = "the row"
	var plain := Control.new()
	plain.mouse_filter = Control.MOUSE_FILTER_PASS
	var named := Button.new()
	named.tooltip_text = "the button"
	var silent := Button.new()
	for child: Control in [plain, named, silent]:
		row.add_child(child)
	root.add_child(row)
	_check(TipCard.text_of(named, Vector2.ZERO) == "the button", "a Control's own tooltip is what is written")
	_check(TipCard.text_of(plain, Vector2.ZERO) == "the row", "one with none, that lets the mouse through, speaks for its parent")
	_check(TipCard.text_of(silent, Vector2.ZERO) == "", "and one that stops the mouse says nothing")
	_check(TipCard.text_of(null, Vector2.ZERO) == "", "as does bare map")
	_check(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) > 1000.0,
			"Godot's own tooltip is out of reach, so nothing is said twice")
	row.queue_free()
	return true


## A section folds and opens on a press, and one built again under the same id stays as it was left.
func _test_accordion() -> bool:
	var section := Accordion.new("Stats", "test:accordion")
	_check(section.is_open() and section.body.visible, "a section starts open")
	section.toggle()
	_check(not section.body.visible, "a press folds it")
	var again := Accordion.new("Stats", "test:accordion")
	_check(not again.is_open(), "and the page drawn again keeps it folded")
	again.toggle()
	var third := Accordion.new("Stats", "test:accordion")
	_check(third.is_open(), "until it is opened")
	for made: Node in [section, again, third]:
		made.free()
	return true
