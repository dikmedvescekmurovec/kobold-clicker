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
## the corner reads as an action to take, and these two are places to go.
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
