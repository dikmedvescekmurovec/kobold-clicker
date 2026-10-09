class_name UITheme
extends RefCounted
## Builds the pixel-art UI Theme at runtime from Assets/UI/ui_sheet.json, the way HexTileset builds
## the TileSet from hex_tileset.json. Every sprite becomes an AtlasTexture on the shared sheet
## wrapped in a StyleBoxTexture with that sprite's own nine-slice margin, so panels and buttons
## stretch to any size.
##
## The margin is per sprite rather than one number for the sheet: the art is cut from a bought pack
## (tools/ui_kit.py says which rectangle of which sheet is which sprite), and a panel's frame and a
## button's bevel are not the same thickness. tools/ui_kit.py measures each margin against the
## pixels and refuses to export a sprite whose tiled rows and columns are not one flat colour.
##
## Use it through the type variations: a plain Button with theme_type_variation "WoodButton" gets
## all four states for free, and Godot drives hover, press and disable itself.

const SHEET_JSON := "res://Assets/UI/ui_sheet.json"
const FONT := "res://Assets/Pixellari.ttf"
const FONT_SIZE := 16   # Pixellari is a pixel font: 16 is its native size, below ~14 the glyphs break up
## Body text -- stat lines, modifiers, card bodies -- is set in a second, smaller pixel font, because
## Pixellari cannot shrink and a stat block in it is half a window tall. Native size only, as above.
const SMALL_FONT := "res://Assets/ArkPixel10.ttf"
const SMALL_FONT_SIZE := 10
## The face pads its 7 px capitals out to a 14 px line; this much comes off the top and the bottom of
## every line, which leaves 11 and still clears the ascenders and the descenders.
const SMALL_FONT_TRIM := Vector2i(2, 1)   # x: top, y: bottom
## `table_row`: its padding (x: sides, y: top and bottom), the least air between a name and its value,
## the wash on every other row, and what the value's Label is called.
const TABLE_PAD := Vector2i(3, 2)
const TABLE_GAP := 6
const TABLE_STRIPE := Color(Palette.SLOT_TAN, 0.4)
const TABLE_VALUE := "Value"

## Panel variations, based on PanelContainer so they can hold and pad their contents. "HeaderBar" is
## the green title bar: it is a panel like the others rather than part of the panel below it, so it
## can grow to hold a 16 px title -- see the note in tools/ui_kit.py.
const PANELS := {
	"WoodPanel": "ui_panel_wood",
	"TextPanel": "ui_panel_white",
	"HeaderBar": "ui_bar_green",
	# The same bar in the red face's colours, for a fight lost (`danger_bar`), and the body under it
	# with its drop line in the same red.
	"HeaderBarDanger": "ui_bar_red",
	"HeadedPanelDanger": "ui_panel_headed_red",
	# The cream body as it stands under the bar: no top frame, a drop line and a tan row instead, so
	# the bar sits on the cream the way the pack draws it rather than over a second dark edge.
	"HeadedPanel": "ui_panel_headed",
}
## The bar is trim rather than a container, so it pads its title far less than a panel pads its
## contents -- enough to keep the text off the bevel and no more.
const BAR_MARGIN := Vector2i(6, 2)   # x: left and right, y: top and bottom
## Button variations -> the sprite's surface and variant. "wood" buttons stand on the wooden panel,
## "light" buttons on the white one; "danger" is the destructive flavour.
const BUTTONS := {
	"WoodButton": ["wood", "normal"],
	"WoodDangerButton": ["wood", "danger"],
	"LightButton": ["light", "normal"],
	"LightDangerButton": ["light", "danger"],
	# The pack's own green, for the one press a counter is there for: Buy, Accept, Claim, Upgrade.
	"LightGoButton": ["light", "go"],
	# The landing page's Golden door.
	"WoodGoldButton": ["wood", "gold"],
}
## The green and gold faces are lettered in ink, as the pack letters its green bar: cream on them is too pale.
const GO_BUTTON := "LightGoButton"
const GOLD_BUTTON := "WoodGoldButton"
const GO_FONT_COLOR := Palette.INK
## The same faces lettered in the body font, for a row of buttons inside a card (a bounty's Accept
## and Claim) where Pixellari's 16 px made the buttons outweigh what they act on. Each is the face it
## names, its padding cut to `SMALL_BUTTON_MARGIN`; a priced one carries a half-size coin.
const SMALL_BUTTONS := {
	"SmallButton": "LightButton",
	"SmallGoButton": "LightGoButton",
	"SmallDangerButton": "LightDangerButton",
}
const SMALL_BUTTON_MARGIN := Vector2i(6, 3)   # x: left and right, y: top and bottom
const SMALL_COIN := 8
const STATES := ["normal", "hover", "pressed", "disabled"]

## Buttons that frame an icon instead of a label -> the sprite family they are built from. A face
## like the ones above, stretched to whatever it holds, but padded equally on all four sides, so one
## wearing a square mark comes out square. "brown" is a key of its own rather than a surface: these
## stand on the map rather than on a panel, which is also what they are brown for -- a green face in
## the corner reads as an action to take, and the corner buttons are places to go.
const ICON_FACES := {"BrownIconButton": "ui_btn_brown"}
## What such a face pads its mark by; tools/ui_kit.py draws its preview at the same number.
const ICON_FACE_MARGIN := 4

## Buttons that are a drawn icon rather than a stretched face -> the sprite name they are built from.
## The pack draws its close button once, at one size, for every panel it has, so this one is drawn
## whole at `ICON_BUTTON_SCALE` times that size (the user's, 2026-10-09: the pack's 9 px X was too
## small to hit) and never tiled -- which is also why it carries no content margin and no pressed
## sink: the sprite already holds the pixel the face drops by.
const ICON_BUTTONS := {"CloseButton": "ui_close"}
const ICON_BUTTON_SCALE := 2

## A mark with no face at all, the way the pack lays its marks on the cream body: the button is
## empty styleboxes round the icon, hover lifts the mark by the step the pack lifts its arrows,
## pressed sinks it the pixel every face sinks, and dead fades it. The marks it wears are the
## `_brown` cut of the pack's own ramp (tools/ui_kit.py `BARE`), never the cream ones, which wash
## out on cream -- and `_green` is the pack's open tab.
const BARE_BUTTON := "BareIconButton"
const BARE_MARGIN := 2
const BARE_HOVER := Color(1.25, 1.25, 1.25)
const BARE_DISABLED := Color(1, 1, 1, 0.4)
## How thick a scroll's bar is, in panel pixels, where one is shown at all.
const SCROLL_BAR := 2.0

## One label colour for every button: the faces are the pack's green replayed in the icon buttons'
## brown (or red for danger), and the words are the same cream as the icon buttons' marks.
const FONT_COLOR := Palette.PANEL_CREAM
## A dead button keeps its label but stops shouting: the wood's brown on the pale tan face
## (`tools/ui_kit.py` `DISABLED`) is legible and plainly switched off, where cream on brown reads as live.
const DISABLED_FONT_COLOR := Palette.SLOT_TAN_DK
const PANEL_MARGIN := 10
## How far a page's panel stands off the window's edge, in panel pixels: the pack floats its panels,
## and one flush against the edge read as part of the window rather than as a thing in it.
const EDGE := 4
const BUTTON_MARGIN := Vector2i(8, 4)   # x: left and right, y: top and bottom

## The window every layout is budgeted for, in panel pixels: the default 1152x648 at `ui_scale` 2. A
## window is drawn at the largest whole `ui_scale` that still leaves it this much (`pick_scale`), and
## one left narrower than `MIN_LONG` -- by that rule only ever one held upright -- is laid out narrow.
const MIN_SHORT := 324.0
const MIN_LONG := 576.0
## Which edge of its room a page's panel stands against (`dock`). A narrow window centres it.
enum Dock { LEFT, RIGHT }
## The meta a panel carries between asking `dock` to lay its page out again and that happening.
const SETTLING := "settling"

static var _theme: Theme
## How big each icon button's sprite is. A Button with no text and no content margin has no minimum
## size of its own, so whoever places one asks here rather than repeating the number.
static var _icon_sizes := {}


## The size to give a `variation` icon button, in sprite pixels.
static func icon_size(variation: String) -> Vector2i:
	if _icon_sizes.is_empty():
		theme()
	return _icon_sizes.get(variation, Vector2i.ZERO)


## The whole-number `ui_scale` for a window of `window` pixels: the largest that still leaves
## `MIN_SHORT` panel pixels on its short side and `MIN_LONG` on its long one, never under 1. Whole, so a
## sprite pixel stays square; picked by the window rather than fixed, so a phone's is as big as a monitor's.
static func pick_scale(window: Vector2) -> float:
	var short := minf(window.x, window.y)
	var long := maxf(window.x, window.y)
	return maxf(1.0, minf(floorf(short / MIN_SHORT), floorf(long / MIN_LONG)))


## Whether a window of `window` pixels at `ui_scale` is too narrow for the panels to stand side by side
## as they do across a monitor -- a phone held upright -- so they stand one over another instead.
static func narrow(window: Vector2, ui_scale: float) -> bool:
	return window.x / ui_scale < MIN_LONG


## The part of the viewport a panel may stand in, in its pixels: all of it, but on a phone only the
## display's safe area, clear of a notch and the rounded corners.
static func safe_rect(viewport: Viewport) -> Rect2:
	var whole := viewport.get_visible_rect()
	if not OS.has_feature("mobile"):
		return whole
	var safe := Rect2(DisplayServer.get_display_safe_area())
	return whole.intersection(safe) if safe.has_area() else whole


## Stands a page's `panel` in `room` (window pixels; an empty one is the whole window): its full height
## less `EDGE` at the top and foot, at the panel's own width, against the room's `side`. **Held upright**
## (`narrow`) it is a sheet along the foot of the room instead: centred at its own width, as tall as what
## it holds (`natural_height`) and never more than half the window, scrolling past that (the user's call).
## `again` is the caller's whole layout, run once more the next frame: a flow (a grid of squares, the
## trees) measures how tall it is only as it lays out, a frame after it was made wider.
static func dock(panel: Control, room: Rect2, ui_scale: float, side := Dock.LEFT,
		again := Callable()) -> void:
	if not room.has_area():
		room = panel.get_viewport_rect()
	var window := panel.get_viewport_rect().size
	if narrow(window, ui_scale):
		var most := minf(room.size.y, window.y / 2.0) / ui_scale - 2 * EDGE
		var across := panel.get_combined_minimum_size().x
		panel.size = Vector2(across, minf(natural_height(panel), most))
		panel.position = Vector2(floorf(room.position.x + (room.size.x - across * ui_scale) / 2.0),
				room.end.y - (panel.size.y + EDGE) * ui_scale)
		_settle(panel, again)
		return
	var width := panel.get_combined_minimum_size().x
	panel.size = Vector2(width, room.size.y / ui_scale - 2 * EDGE)
	var x := room.position.x + EDGE * ui_scale
	if side == Dock.RIGHT:
		x = room.end.x - (width + EDGE) * ui_scale
	panel.position = Vector2(x, room.position.y + EDGE * ui_scale)


## Runs `again` the next frame, once however often it is asked for meanwhile -- the run itself docks
## the panel again, which asks for no other.
static func _settle(panel: Control, again: Callable) -> void:
	if not again.is_valid() or panel.has_meta(SETTLING) or not panel.is_inside_tree():
		return
	panel.set_meta(SETTLING, true)
	panel.get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(panel) and again.is_valid():
			again.call()
			panel.remove_meta(SETTLING), CONNECT_ONE_SHOT)


## How tall `panel` would be with nothing in it scrolled: its minimum, which counts a scroll as nothing,
## and everything each of its scrolls holds. A scroll that does not scroll is in the minimum already.
static func natural_height(panel: Control) -> float:
	var tall := panel.get_combined_minimum_size().y
	for scroll: ScrollContainer in panel.find_children("*", "ScrollContainer", true, false):
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and scroll.get_child_count() > 0:
			tall += (scroll.get_child(0) as Control).get_combined_minimum_size().y
	return tall


## A finger is broader than the X: on a touchscreen the X is pressed anywhere in `TOUCH_TARGET`
## round it, and still drawn at its own size in the middle of that.
const TOUCH_TARGET := Vector2(28, 20)
static func _widen_for_fingers(close: Button) -> void:
	var pad := (TOUCH_TARGET - Vector2(icon_size("CloseButton"))) / 2.0
	for state: String in STATES:
		var box := theme().get_stylebox(state, "CloseButton").duplicate() as StyleBoxTexture
		box.set_expand_margin(SIDE_LEFT, -pad.x)
		box.set_expand_margin(SIDE_RIGHT, -pad.x)
		box.set_expand_margin(SIDE_TOP, -pad.y)
		box.set_expand_margin(SIDE_BOTTOM, -pad.y)
		close.add_theme_stylebox_override(state, box)
	close.custom_minimum_size = TOUCH_TARGET


## The shared Theme, built once per run.
static func theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func build() -> Theme:
	var built := Theme.new()
	var text := FileAccess.get_file_as_string(SHEET_JSON)
	if text.is_empty():
		push_error("UITheme: cannot read " + SHEET_JSON)
		return built
	var data: Variant = JSON.parse_string(text)
	var meta: Dictionary = data["meta"]
	var sheet: Texture2D = load(SHEET_JSON.get_base_dir().path_join(meta["image"]))
	var regions := {}
	var margins := {}
	for sprite: Dictionary in data["sprites"]:
		regions[sprite["name"]] = Rect2(sprite["x"], sprite["y"], sprite["w"], sprite["h"])
		margins[sprite["name"]] = sprite["margin"]

	var font: Font = load(FONT)
	built.default_font = font
	built.default_font_size = FONT_SIZE

	# Labels default to white, which is invisible on the cream panel. INK also carries the title on
	# the green bar, which is the colour the pack letters its own bars in.
	built.set_type_variation("PanelLabel", "Label")
	built.set_color("font_color", "PanelLabel", Palette.TEXT)
	built.set_font_size("font_size", "PanelLabel", FONT_SIZE)

	built.set_type_variation("SmallLabel", "Label")
	built.set_color("font_color", "SmallLabel", Palette.TEXT)
	var small := FontVariation.new()
	small.base_font = load(SMALL_FONT)
	small.set_spacing(TextServer.SPACING_TOP, -SMALL_FONT_TRIM.x)
	small.set_spacing(TextServer.SPACING_BOTTOM, -SMALL_FONT_TRIM.y)
	built.set_font("font", "SmallLabel", small)
	built.set_font_size("font_size", "SmallLabel", SMALL_FONT_SIZE)

	for variation: String in PANELS:
		built.set_type_variation(variation, "PanelContainer")
		var box := _style(sheet, regions[PANELS[variation]], margins[PANELS[variation]])
		if variation in ["HeaderBar", DANGER_BAR]:
			box.content_margin_left = BAR_MARGIN.x
			box.content_margin_right = BAR_MARGIN.x
			box.content_margin_top = BAR_MARGIN.y
			box.content_margin_bottom = BAR_MARGIN.y
		else:
			box.set_content_margin_all(PANEL_MARGIN)
		built.set_stylebox("panel", variation, box)

	for variation: String in BUTTONS:
		var surface: String = BUTTONS[variation][0]
		var variant: String = BUTTONS[variation][1]
		built.set_type_variation(variation, "Button")
		for state: String in STATES:
			var sprite_name := "ui_btn_%s_%s_%s" % [surface, variant, state]
			var box := _style(sheet, regions[sprite_name], margins[sprite_name])
			# The pack draws the pressed face a pixel lower with its drop shadow gone, so the label
			# has to sink with it or it floats off the face it is written on.
			var sink := 1 if state == "pressed" else 0
			box.content_margin_left = BUTTON_MARGIN.x
			box.content_margin_right = BUTTON_MARGIN.x
			box.content_margin_top = BUTTON_MARGIN.y + sink
			box.content_margin_bottom = BUTTON_MARGIN.y - sink
			built.set_stylebox(state, variation, box)
		for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			built.set_color(item, variation, GO_FONT_COLOR if variation in [GO_BUTTON, GOLD_BUTTON] else FONT_COLOR)
		built.set_color("font_disabled_color", variation, DISABLED_FONT_COLOR)
		built.set_font("font", variation, font)
		built.set_font_size("font_size", variation, FONT_SIZE)

	for variation: String in SMALL_BUTTONS:
		var big: String = SMALL_BUTTONS[variation]
		built.set_type_variation(variation, "Button")
		for state: String in STATES:
			var box: StyleBoxTexture = built.get_stylebox(state, big).duplicate()
			var sink := 1 if state == "pressed" else 0
			box.content_margin_left = SMALL_BUTTON_MARGIN.x
			box.content_margin_right = SMALL_BUTTON_MARGIN.x
			box.content_margin_top = SMALL_BUTTON_MARGIN.y + sink
			box.content_margin_bottom = SMALL_BUTTON_MARGIN.y - sink
			built.set_stylebox(state, variation, box)
		for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_disabled_color"]:
			built.set_color(item, variation, built.get_color(item, big))
		built.set_font("font", variation, small)
		built.set_font_size("font_size", variation, SMALL_FONT_SIZE)

	for variation: String in ICON_FACES:
		built.set_type_variation(variation, "Button")
		for state: String in STATES:
			var sprite_name: String = "%s_%s" % [ICON_FACES[variation], state]
			var box := _style(sheet, regions[sprite_name], margins[sprite_name])
			# The same sink the lettered buttons take: the pack draws the pressed face a pixel lower,
			# so the mark on it has to drop with the face it is sitting on.
			var sink := 1 if state == "pressed" else 0
			box.content_margin_left = ICON_FACE_MARGIN
			box.content_margin_right = ICON_FACE_MARGIN
			box.content_margin_top = ICON_FACE_MARGIN + sink
			box.content_margin_bottom = ICON_FACE_MARGIN - sink
			built.set_stylebox(state, variation, box)

	for variation: String in ICON_BUTTONS:
		built.set_type_variation(variation, "Button")
		for state: String in STATES:
			var sprite_name: String = "%s_%s" % [ICON_BUTTONS[variation], state]
			var box := _style(sheet, regions[sprite_name], margins[sprite_name])
			# Stretched, never tiled: one X blown up by a whole number, not `ICON_BUTTON_SCALE` squared of them.
			box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			built.set_stylebox(state, variation, box)
		_icon_sizes[variation] = Vector2i(regions[ICON_BUTTONS[variation] + "_normal"].size) * ICON_BUTTON_SCALE

	built.set_type_variation(BARE_BUTTON, "Button")
	for state: String in STATES + ["focus"]:
		var box := StyleBoxEmpty.new()
		var sink := 1 if state == "pressed" else 0
		box.content_margin_left = BARE_MARGIN
		box.content_margin_right = BARE_MARGIN
		box.content_margin_top = BARE_MARGIN + sink
		box.content_margin_bottom = BARE_MARGIN - sink
		built.set_stylebox(state, BARE_BUTTON, box)
	built.set_color("icon_hover_color", BARE_BUTTON, BARE_HOVER)
	built.set_color("icon_disabled_color", BARE_BUTTON, BARE_DISABLED)

	# The bar a scroll wears where it shows one at all (the skill tree, zoomed past its box): a thin ink
	# grabber half seen, on no track, so it reads on the cream and says only that there is more.
	for bar: String in ["HScrollBar", "VScrollBar"]:
		var track := StyleBoxEmpty.new()
		track.set_content_margin_all(SCROLL_BAR / 2.0)
		built.set_stylebox("scroll", bar, track)
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(Palette.INK, 0.5)
		grabber.set_content_margin_all(SCROLL_BAR / 2.0)
		for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			built.set_stylebox(state, bar, grabber)
	return built


static func _style(sheet: Texture2D, region: Rect2, margin: Dictionary) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	var box := StyleBoxTexture.new()
	box.texture = atlas
	box.texture_margin_left = margin["left"]
	box.texture_margin_top = margin["top"]
	box.texture_margin_right = margin["right"]
	box.texture_margin_bottom = margin["bottom"]
	# Tile rather than stretch: every row and column outside the margin is one flat colour, so tiling
	# is seamless at any size while stretching would land the bevel on a half pixel.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box


# Builders for the Controls the scenes make in code, so each is put together one way.

## The line drawn between two blocks of text on a panel.
const RULE_HEIGHT := 1
const BACK_ICON := "res://Assets/UI/ui_icon_back.png"


static func button(text: String, variation: String, tooltip: String) -> Button:
	var made := Button.new()
	made.text = text
	made.theme_type_variation = variation
	made.tooltip_text = tooltip
	return made


## The least air between a paying button's word and its figure, and the name of the node holding the
## figure and the coin, which is how `price_of` and the tests find it.
const PRICE_GAP := 6
const PRICE_NAME := "Price"


## A button that gold moves through: the word on the left, then the figure, then the coin against
## the right edge -- [Buy      120 (c)]. Every such button in the game is made here, so they all
## read the same way round. `figure` false leaves the number off (a bounty's Claim, whose reward is
## on the card above it); a price of nothing is a plain button with no coin at all.
static func priced_button(text: String, price: float, variation: String, tooltip: String,
		figure := true) -> Button:
	var made := button(text, variation, tooltip)
	made.alignment = HORIZONTAL_ALIGNMENT_LEFT
	set_price(made, price, figure)
	return made


## Puts a new figure on a button `priced_button` made, or takes figure and coin off at nothing.
static func set_price(made: Button, price: float, figure := true) -> void:
	var old := made.get_node_or_null(PRICE_NAME)
	if old != null:
		made.remove_child(old)
		old.queue_free()
	made.custom_minimum_size.x = 0
	if price <= 0.0:
		return
	var tail := HBoxContainer.new()
	tail.name = PRICE_NAME
	tail.alignment = BoxContainer.ALIGNMENT_END
	tail.add_theme_constant_override("separation", 2)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var small := SMALL_BUTTONS.has(made.theme_type_variation)
	if figure:
		var amount := label(BigNumber.format(price), null, small)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail.add_child(amount)
	var coin := TextureRect.new()
	if small:
		# Mode before texture and size, as every stepped-down icon: a 16 px coin asked for 8 comes back 16.
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.custom_minimum_size = Vector2(SMALL_COIN, SMALL_COIN)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.texture = Coins.icon()
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if small else TextureRect.STRETCH_KEEP_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.add_child(coin)
	made.add_child(tail)
	tail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place_price(made, 0)
	# The figure is a Label and not the button's own text, so it is told what the button's text is
	# told: grey when the button is dead, and a pixel lower while the face is held down.
	if not made.draw.is_connected(_tint_price):
		made.draw.connect(_tint_price.bind(made))
		made.button_down.connect(_place_price.bind(made, 1))
		made.button_up.connect(_place_price.bind(made, 0))
		made.ready.connect(_fit_price.bind(made))
	_fit_price(made)


## What a priced button says it costs, as written on it ("" with no figure). For the tests.
static func price_of(made: Button) -> String:
	var tail := made.get_node_or_null(PRICE_NAME)
	if tail == null or not (tail.get_child(0) is Label):
		return ""
	return (tail.get_child(0) as Label).text


## Wide enough for the word, the gap and the figure. A Button sizes itself to its own text only, and
## a Label only knows its width once it has a theme, which is once it is in the tree.
static func _fit_price(made: Button) -> void:
	var tail: Control = made.get_node_or_null(PRICE_NAME)
	if tail != null and made.is_inside_tree():
		made.custom_minimum_size.x = (made.get_minimum_size().x + PRICE_GAP
				+ tail.get_combined_minimum_size().x)


static func _place_price(made: Button, sink: int) -> void:
	var tail: Control = made.get_node_or_null(PRICE_NAME)
	if tail == null:
		return
	var pad := SMALL_BUTTON_MARGIN if SMALL_BUTTONS.has(made.theme_type_variation) else BUTTON_MARGIN
	tail.offset_left = pad.x
	tail.offset_right = -pad.x
	tail.offset_top = pad.y + sink
	tail.offset_bottom = -pad.y + sink


static func _tint_price(made: Button) -> void:
	var tail := made.get_node_or_null(PRICE_NAME)
	if tail == null:
		return
	var color := made.get_theme_color("font_disabled_color" if made.disabled else "font_color")
	if tail.get_child(0) is Label:
		(tail.get_child(0) as Label).add_theme_color_override("font_color", color)
	tail.get_child(-1).modulate = Color(1, 1, 1, 0.5) if made.disabled else Color.WHITE


## A brown face with a mark and no words. It stands on the map with no themed ancestor, so it carries
## the theme itself.
static func icon_button(texture: Texture2D, tooltip: String, ui_scale: float) -> Button:
	var made := button("", "BrownIconButton", tooltip)
	made.theme = theme()
	made.icon = texture
	made.expand_icon = false
	made.scale = Vector2(ui_scale, ui_scale)
	return made


## The way back out of whatever is open: the brown face with the arrow, never the word. Its parent
## must be themed; it keeps its own width, so what shares its row should expand.
static func back_button(tooltip: String) -> Button:
	var made := button("", "BrownIconButton", tooltip)
	made.icon = load(BACK_ICON)
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return made


## A panel label, in the theme's ink unless `color` says otherwise. `small` sets it in the body font.
static func label(text := "", color: Variant = null, small := false) -> Label:
	var made := Label.new()
	made.theme_type_variation = "SmallLabel" if small else "PanelLabel"
	made.text = text
	if color != null:
		made.add_theme_color_override("font_color", color)
	return made


## A few words in bone on a chip in the rule's brown, cut as the character page's attribute chips are:
## the credits' "AI", a bounty's level.
static func chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SLOT_TAN_DK
	box.set_corner_radius_all(CharacterPage.CHIP_CORNER)
	box.anti_aliasing = false
	box.content_margin_left = CharacterPage.CHIP_PAD.x
	box.content_margin_right = CharacterPage.CHIP_PAD.x
	box.content_margin_top = CharacterPage.CHIP_PAD.y
	box.content_margin_bottom = CharacterPage.CHIP_PAD.y
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(label(text, Palette.BONE, true))
	return chip


## The game's text field: a `LineEdit` in the cream panel's own white box, so it reads as something to
## write in, `width` wide and taking at most `most` characters.
static func text_field(placeholder: String, most: int, width: float) -> LineEdit:
	var field := LineEdit.new()
	field.max_length = most
	field.placeholder_text = placeholder
	field.custom_minimum_size.x = width
	for state: String in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, theme().get_stylebox("panel", "TextPanel"))
	field.add_theme_color_override("font_color", Palette.TEXT)
	field.add_theme_color_override("font_placeholder_color", Palette.TEXT_SOFT)
	field.add_theme_color_override("caret_color", Palette.TEXT)
	return field


## A box for whatever may run past the window's foot: it takes the column's slack and scrolls by the
## wheel, down only and with no bar drawn. What goes after it in the column stays pinned under it.
static func scroll() -> ScrollContainer:
	var made := ScrollContainer.new()
	made.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	made.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return made


## A small heading: a word in the body font and a rule run out to the edge (a counter's Trade up, her
## Readings and Great spells, the tile panel's Services). Small, because something above it is already
## the heading; these only say where one part ends and the next begins.
static func section(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(label(text, Palette.TEXT_SOFT, true))
	var line := rule()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


static func rule(width := 0.0) -> ColorRect:
	var made := ColorRect.new()
	made.color = Palette.SLOT_TAN_DK
	made.custom_minimum_size = Vector2(width, RULE_HEIGHT)
	return made


static func vbox(separation: int, width := 0.0) -> VBoxContainer:
	var made := VBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	made.custom_minimum_size = Vector2(width, 0)
	return made


## One row of a table, and the one way the game draws one: the name against the left edge, the value
## against the right, and every other row (`striped`) washed with `TABLE_STRIPE` so the eye can follow
## a name across to its number. Stack them in a `vbox(0)`, or the stripes come apart.
##
## `width` is for a table standing in something that sizes itself round its contents (a floating
## card): the name then wraps in what the value leaves of it, measured here because a wrapping Label
## has to be told its width before it can say its height. At 0 the name takes what the parent gives.
## Where the name and the value will not share one line, the value drops under the name, against the
## right edge: a long value ("+607K(416K-997K)%") squeezed the name into a word a line, four lines tall.
## The value's Label is named `TABLE_VALUE`, for a caller with a tooltip to hang on it. With `can_stack`
## false the value always stands on the name's first line, the name wrapping in what it leaves: a short
## value beside a long name (the changelog's table).
static func table_row(text: String, value: String, striped: bool, width := 0.0,
		text_color: Variant = null, value_color: Variant = null, can_stack := true) -> PanelContainer:
	var row := _row_panel(striped)
	var room := width - 2 * TABLE_PAD.x
	var taken := 0.0
	var stacked := false
	# With no value there is nothing to drop under the name, which only wraps.
	if width > 0.0 and not value.is_empty():
		var font := theme().get_font("font", "SmallLabel")
		taken = ceilf(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT_SIZE).x)
		stacked = can_stack and ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT_SIZE).x) \
				+ TABLE_GAP + taken > room
	var cells: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	cells.add_theme_constant_override("separation", 0 if stacked else TABLE_GAP)
	row.add_child(cells)
	var name_cell := label(text, text_color, true)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cells.add_child(name_cell)
	var value_cell := label(value, value_color, true)
	value_cell.name = TABLE_VALUE
	value_cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	value_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cells.add_child(value_cell)
	if width > 0.0:
		name_cell.custom_minimum_size.x = maxf(room if stacked else room - TABLE_GAP - taken, 0.0)
	return row


## The padded, maybe washed box every table row stands in.
static func _row_panel(striped: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = TABLE_STRIPE if striped else Color.TRANSPARENT
	box.set_content_margin_all(TABLE_PAD.y)
	box.content_margin_left = TABLE_PAD.x
	box.content_margin_right = TABLE_PAD.x
	row.add_theme_stylebox_override("panel", box)
	return row


## A green title bar with an X at its right end over a cream body. Two panels stacked rather than the
## pack's one headered sprite, whose bar is 13 px and too short for Pixellari (see tools/ui_kit.py);
## the body is the `HeadedPanel` cut, which has no top frame, so the two meet as the pack's one
## sprite does. Fill the body through `body_of`.
static func titled_panel(title_text: String, tooltip: String, on_close: Callable) -> VBoxContainer:
	var stack := vbox(0)
	stack.theme = theme()
	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	stack.add_child(bar)
	var header := HBoxContainer.new()
	bar.add_child(header)
	# The pack letters its bars in near-black, and the panel's brown text would sink into the green.
	var title := label(title_text, Palette.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	# Air between a long name and the X, which otherwise runs the one into the other.
	header.add_theme_constant_override("separation", 6)
	# A drawn X at the size the pack drew it: a Button with no text has no minimum size of its own.
	# None where `on_close` is empty: a panel left by its own button (a verdict's Collect).
	if on_close.is_valid():
		var close := button("", "CloseButton", tooltip)
		close.custom_minimum_size = Vector2(icon_size("CloseButton"))
		if DisplayServer.is_touchscreen_available():
			_widen_for_fingers(close)
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close.pressed.connect(on_close)
		header.add_child(close)
	notched(bar, true)
	var body := PanelContainer.new()
	body.theme_type_variation = "HeadedPanel"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	body.add_child(vbox(6))
	notched(body)
	return stack


## The pack's frames wobble: along every edge the brown shifts a shade for a stretch and swells a
## pixel or three into the cream, which is what makes its panels look torn rather than drawn. A
## nine-slice cannot carry that, so the wobbles are patches (tools/ui_kit.py `NOTCHES`, cut off the
## pack's own composed panel) laid over a cream panel's left, right and bottom edges as it draws --
## the frame under them is the same art, so only the wobble shows. Left and right alternate their two
## patches down the edge at `NOTCH_PITCH`, staggered against each other; the bottom cycles its three
## along; a patch goes only where it fits clear of the corners. Not a cream panel's top, which is
## its bar or, on a card, too short to wobble -- the bar wobbles on its own (`bar`): its highlight
## breaks along its top at `NOTCH_BAR_PITCH`.
const NOTCH := "res://Assets/UI/ui_notch_%s_%s.png"
## The red title bar's variation (`danger_bar`).
const DANGER_BAR := "HeaderBarDanger"
const NOTCH_PITCH := 40
const NOTCH_STAGGER := 20
const NOTCH_BOTTOM_PITCH := 36
const NOTCH_BAR_PITCH := 56
const NOTCH_START := 10
const NOTCH_CLEAR := 8
static var _notches := {}


static func notched(panel: Control, bar := false) -> void:
	panel.draw.connect(_draw_notches.bind(panel, bar))


static func _draw_notches(panel: Control, bar: bool) -> void:
	# The bar's patch is cut off the green bar; a red bar wears its red twin.
	var red := bar and panel.theme_type_variation == DANGER_BAR
	for place: Array in notch_places(panel.size, bar):
		panel.draw_texture(_notches["bar_reda"] if red else place[0], place[1])


## Where the patches fall on a panel of `size`: [texture, position] each. tools/ui_kit.py
## `notch_places` is the same arithmetic, so its preview shows what this draws.
static func notch_places(size: Vector2, bar := false) -> Array:
	if _notches.is_empty():
		for side: String in ["left", "right", "bottom", "bar"]:
			for letter: String in ("abc" if side == "bottom" else "ab" if side != "bar" else "a"):
				_notches[side + letter] = load(NOTCH % [side, letter])
		_notches["bar_reda"] = load(NOTCH % ["bar_red", "a"])
	var places := []
	if bar:
		var patch: Texture2D = _notches["bara"]
		var x := NOTCH_START
		while x + patch.get_width() <= size.x - NOTCH_CLEAR:
			places.append([patch, Vector2(x, 0)])
			x += NOTCH_BAR_PITCH
		return places
	for side: String in ["left", "right"]:
		var y := NOTCH_START + (NOTCH_STAGGER if side == "right" else 0)
		var i := 0
		while true:
			var patch: Texture2D = _notches[side + "ab"[i % 2]]
			if y + patch.get_height() > size.y - NOTCH_CLEAR:
				break
			places.append([patch, Vector2(0 if side == "left" else size.x - patch.get_width(), y)])
			y += NOTCH_PITCH
			i += 1
	var x := NOTCH_START
	var i := 0
	while true:
		var patch: Texture2D = _notches["bottom" + "abc"[i % 3]]
		if x + patch.get_width() > size.x - NOTCH_CLEAR:
			break
		places.append([patch, Vector2(x, size.y - patch.get_height())])
		x += NOTCH_BOTTOM_PITCH
		i += 1
	return places


static func body_of(panel: VBoxContainer) -> VBoxContainer:
	return panel.get_child(1).get_child(0)


static func title_of(panel: VBoxContainer) -> Label:
	return panel.get_child(0).get_child(0).get_child(0)


## A `titled_panel`'s bar worn red (`DANGER_BAR`, its title in bone) or green again: a fight lost was
## headed in the same green as a fight won.
static func danger_bar(panel: VBoxContainer, on: bool) -> void:
	var bar := panel.get_child(0) as PanelContainer
	bar.theme_type_variation = DANGER_BAR if on else "HeaderBar"
	(panel.get_child(1) as PanelContainer).theme_type_variation = "HeadedPanelDanger" if on else "HeadedPanel"
	title_of(panel).add_theme_color_override("font_color", Palette.BONE if on else Palette.INK)
	bar.queue_redraw()


## Frees every child but `keep`, taking each out of the tree at once: a queued child still counts in
## hit-tests and minimum sizes until the frame ends.
static func clear(parent: Node, keep: Node = null) -> void:
	for child: Node in parent.get_children():
		if child != keep:
			parent.remove_child(child)
			child.queue_free()
