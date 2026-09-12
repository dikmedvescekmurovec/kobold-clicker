class_name UITheme
extends RefCounted
## Builds the pixel-art UI Theme at runtime from AI-sprites/ui/ui_sheet.json, the way HexTileset
## builds the TileSet from hex_tileset.json. Every sprite becomes an AtlasTexture on the shared
## sheet wrapped in a StyleBoxTexture with the JSON's 8 px slice as its texture margin, so panels
## and buttons stretch to any size down to 16x16.
##
## Use it through the type variations: a plain Button with theme_type_variation "WoodButton" gets
## all four states for free, and Godot drives hover, press and disable itself.

const SHEET_JSON := "res://AI-sprites/ui/ui_sheet.json"
const FONT := "res://Assets/Pixellari.ttf"
const FONT_SIZE := 16   # Pixellari is a pixel font: 16 is its native size, below ~14 the glyphs break up

## Panel variations, based on PanelContainer so they can hold and pad their contents.
const PANELS := {"WoodPanel": "ui_panel_wood", "TextPanel": "ui_panel_white"}
## Button variations -> the sprite's surface and variant. "wood" buttons stand on the wooden panel,
## "light" buttons on the white one; "danger" is the destructive flavour.
const BUTTONS := {
	"WoodButton": ["wood", "normal"],
	"WoodDangerButton": ["wood", "danger"],
	"LightButton": ["light", "normal"],
	"LightDangerButton": ["light", "danger"],
}
const STATES := ["normal", "hover", "pressed", "disabled"]

## Label colours, picked for contrast against each face: the wood buttons are light-faced except
## the red ones, and every disabled face is pale.
const FONT_COLORS := {
	"wood_normal": Color("14101e"), "wood_danger": Color("f4eedc"),       # ink, bone
	"light_normal": Color("f4eedc"), "light_danger": Color("f4eedc"),
}
const DISABLED_COLORS := {
	"wood_normal": Color("3a2521"), "wood_danger": Color("3a2521"),       # earth_dk
	"light_normal": Color("565a6e"), "light_danger": Color("565a6e"),     # slate
}
const PANEL_MARGIN := 10
const BUTTON_MARGIN := Vector2i(8, 4)   # x: left and right, y: top and bottom

static var _theme: Theme


## The shared Theme, built once per run.
static func theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


## Applies the theme to a node and everything under it.
static func apply_to(node: Control) -> void:
	node.theme = theme()


static func build() -> Theme:
	var built := Theme.new()
	var text := FileAccess.get_file_as_string(SHEET_JSON)
	if text.is_empty():
		push_error("UITheme: cannot read " + SHEET_JSON)
		return built
	var data: Variant = JSON.parse_string(text)
	var meta: Dictionary = data["meta"]
	var slice := int(meta["slice"])
	var sheet: Texture2D = load(SHEET_JSON.get_base_dir().path_join(meta["image"]))
	var regions := {}
	for sprite: Dictionary in data["sprites"]:
		regions[sprite["name"]] = Rect2(sprite["x"], sprite["y"], sprite["w"], sprite["h"])

	var font: Font = load(FONT)
	built.default_font = font
	built.default_font_size = FONT_SIZE

	# Labels default to white, which is invisible on the bone panel.
	built.set_type_variation("PanelLabel", "Label")
	built.set_color("font_color", "PanelLabel", Color("14101e"))
	built.set_font_size("font_size", "PanelLabel", FONT_SIZE)

	for variation: String in PANELS:
		built.set_type_variation(variation, "PanelContainer")
		var box := _style(sheet, regions[PANELS[variation]], slice)
		box.set_content_margin_all(PANEL_MARGIN)
		built.set_stylebox("panel", variation, box)

	for variation: String in BUTTONS:
		var surface: String = BUTTONS[variation][0]
		var variant: String = BUTTONS[variation][1]
		built.set_type_variation(variation, "Button")
		for state: String in STATES:
			var box := _style(sheet, regions["ui_btn_%s_%s_%s" % [surface, variant, state]], slice)
			# Pressed inverts the bevel, so the label sinks a pixel with it.
			var sink := 1 if state == "pressed" else 0
			box.content_margin_left = BUTTON_MARGIN.x
			box.content_margin_right = BUTTON_MARGIN.x
			box.content_margin_top = BUTTON_MARGIN.y + sink
			box.content_margin_bottom = BUTTON_MARGIN.y - sink
			built.set_stylebox(state, variation, box)
		var key := "%s_%s" % [surface, variant]
		for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			built.set_color(item, variation, FONT_COLORS[key])
		built.set_color("font_disabled_color", variation, DISABLED_COLORS[key])
		built.set_font("font", variation, font)
		built.set_font_size("font_size", variation, FONT_SIZE)
	return built


static func _style(sheet: Texture2D, region: Rect2, slice: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	var box := StyleBoxTexture.new()
	box.texture = atlas
	box.set_texture_margin_all(slice)
	# Tile rather than stretch: the interior art is periodic in `slice` px, so tiling is seamless
	# while stretching would smear the plank grain.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box
