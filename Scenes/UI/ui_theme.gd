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
}
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
## The pack draws its close button once, at one size, for every panel it has, so this one is placed
## at its own size and never scaled or tiled -- which is also why it carries no content margin and
## no pressed sink: the sprite already holds the pixel the face drops by.
const ICON_BUTTONS := {"CloseButton": "ui_close"}

## One label colour for every button: the faces are the pack's green replayed in the icon buttons'
## brown (or red for danger), and the words are the same cream as the icon buttons' marks.
const FONT_COLOR := Palette.PANEL_CREAM
## A dead button keeps its label but stops shouting: pale grey on the grey face is legible and
## plainly switched off, where a dark ink would read as live.
const DISABLED_FONT_COLOR := Palette.STONE_LT
const PANEL_MARGIN := 10
const BUTTON_MARGIN := Vector2i(8, 4)   # x: left and right, y: top and bottom

static var _theme: Theme
## How big each icon button's sprite is. A Button with no text and no content margin has no minimum
## size of its own, so whoever places one asks here rather than repeating the number.
static var _icon_sizes := {}


## The size to give a `variation` icon button, in sprite pixels.
static func icon_size(variation: String) -> Vector2i:
	if _icon_sizes.is_empty():
		theme()
	return _icon_sizes.get(variation, Vector2i.ZERO)


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
	built.set_color("font_color", "PanelLabel", Palette.INK)
	built.set_font_size("font_size", "PanelLabel", FONT_SIZE)

	built.set_type_variation("SmallLabel", "Label")
	built.set_color("font_color", "SmallLabel", Palette.INK)
	var small := FontVariation.new()
	small.base_font = load(SMALL_FONT)
	small.set_spacing(TextServer.SPACING_TOP, -SMALL_FONT_TRIM.x)
	small.set_spacing(TextServer.SPACING_BOTTOM, -SMALL_FONT_TRIM.y)
	built.set_font("font", "SmallLabel", small)
	built.set_font_size("font_size", "SmallLabel", SMALL_FONT_SIZE)

	for variation: String in PANELS:
		built.set_type_variation(variation, "PanelContainer")
		var box := _style(sheet, regions[PANELS[variation]], margins[PANELS[variation]])
		if variation == "HeaderBar":
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
			built.set_color(item, variation, FONT_COLOR)
		built.set_color("font_disabled_color", variation, DISABLED_FONT_COLOR)
		built.set_font("font", variation, font)
		built.set_font_size("font_size", variation, FONT_SIZE)

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
			built.set_stylebox(state, variation, _style(sheet, regions[sprite_name], margins[sprite_name]))
		_icon_sizes[variation] = Vector2i(regions[ICON_BUTTONS[variation] + "_normal"].size)
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
	if figure:
		var amount := label(BigNumber.format(price))
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail.add_child(amount)
	var coin := TextureRect.new()
	coin.texture = Coins.icon()
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
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
	tail.offset_left = BUTTON_MARGIN.x
	tail.offset_right = -BUTTON_MARGIN.x
	tail.offset_top = BUTTON_MARGIN.y + sink
	tail.offset_bottom = -BUTTON_MARGIN.y + sink


static func _tint_price(made: Button) -> void:
	var tail := made.get_node_or_null(PRICE_NAME)
	if tail == null:
		return
	var color := DISABLED_FONT_COLOR if made.disabled else FONT_COLOR
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


static func rule(width := 0.0) -> ColorRect:
	var made := ColorRect.new()
	made.color = Palette.SLATE
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
## The value's Label is named `TABLE_VALUE`, for a caller with a tooltip to hang on it.
static func table_row(text: String, value: String, striped: bool, width := 0.0,
		text_color: Variant = null, value_color: Variant = null) -> PanelContainer:
	var row := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = TABLE_STRIPE if striped else Color.TRANSPARENT
	box.set_content_margin_all(TABLE_PAD.y)
	box.content_margin_left = TABLE_PAD.x
	box.content_margin_right = TABLE_PAD.x
	row.add_theme_stylebox_override("panel", box)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", TABLE_GAP)
	row.add_child(cells)
	var name_cell := label(text, text_color, true)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cells.add_child(name_cell)
	var value_cell := label(value, value_color, true)
	value_cell.name = TABLE_VALUE
	value_cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cells.add_child(value_cell)
	if width > 0.0:
		var taken := theme().get_font("font", "SmallLabel").get_string_size(value,
				HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT_SIZE).x
		name_cell.custom_minimum_size.x = maxf(width - 2 * TABLE_PAD.x - TABLE_GAP - ceilf(taken), 0.0)
	return row


## A green title bar with an X at its right end over a cream body. Two panels stacked rather than the
## pack's one headered sprite, whose bar is 13 px and too short for Pixellari (see tools/ui_kit.py).
## Fill the body through `body_of`.
static func titled_panel(title_text: String, tooltip: String, on_close: Callable) -> VBoxContainer:
	var stack := vbox(0)
	stack.theme = theme()
	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	stack.add_child(bar)
	var header := HBoxContainer.new()
	bar.add_child(header)
	var title := label(title_text)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	# A drawn X at the size the pack drew it: a Button with no text has no minimum size of its own.
	var close := button("", "CloseButton", tooltip)
	close.custom_minimum_size = Vector2(icon_size("CloseButton"))
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	header.add_child(close)
	var body := PanelContainer.new()
	body.theme_type_variation = "TextPanel"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	body.add_child(vbox(6))
	return stack


static func body_of(panel: VBoxContainer) -> VBoxContainer:
	return panel.get_child(1).get_child(0)


static func title_of(panel: VBoxContainer) -> Label:
	return panel.get_child(0).get_child(0).get_child(0)


## Frees every child but `keep`, taking each out of the tree at once: a queued child still counts in
## hit-tests and minimum sizes until the frame ends.
static func clear(parent: Node, keep: Node = null) -> void:
	for child: Node in parent.get_children():
		if child != keep:
			parent.remove_child(child)
			child.queue_free()
