class_name Changelog
extends RefCounted
## `CHANGELOG.md` read into versions and laid out as the page the web build's start-up shows
## (`main_scene._show_changelog`).

## Packed into the web build only by `export_presets.cfg`'s include filter: it is no resource.
const PATH := "res://CHANGELOG.md"
const TITLE := "What's new"
## Between one version and the next, and within one between its heading and each section; a section's
## rows are `BagPage.SLOT_GAP` apart.
const VERSION_GAP := 16
const SECTION_GAP := 8
## A change's square bullet, and how far its words stand in from the edge.
const BULLET := 2.0
const INDENT := 7.0


## Every version, newest first: `{version, date, sections}`, a section `[heading, [item, ...]]` (heading
## "" for items before any `### `), an item a change's line or a table row's cells (an Array; the first
## of a run is the header, the `|---|` row dropped). Empty with no file.
static func versions() -> Array:
	var found: Array = []
	for raw in FileAccess.get_file_as_string(PATH).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("## "):
			found.append({"version": line.get_slice(" ", 1),
					"date": line.get_slice("(", 1).get_slice(")", 0), "sections": []})
			continue
		if found.is_empty():
			continue
		var sections: Array = found[-1]["sections"]
		if line.begins_with("### "):
			sections.append([line.trim_prefix("### "), []])
		elif line.begins_with("- ") or line.begins_with("|"):
			if sections.is_empty():
				sections.append(["", []])
			if line.begins_with("- "):
				sections[-1][1].append(line.trim_prefix("- "))
			elif not line.replace("|", "").replace("-", "").replace(":", "").strip_edges().is_empty():
				var cells: Array = Array(line.trim_prefix("|").trim_suffix("|").split("|")).map(
						func(cell: String) -> String: return cell.strip_edges())
				sections[-1][1].append(cells)
	return found


## The versions newer than `seen`, newest first.
static func since(seen: String) -> Array:
	var unseen: Array = []
	for version: Dictionary in versions():
		if version["version"] == seen:
			break
		unseen.append(version)
	return unseen


static func page(shown: Array, width: float) -> VBoxContainer:
	var column := UITheme.vbox(VERSION_GAP, width)
	for version: Dictionary in shown:
		column.add_child(_version(version, width))
	return column


## One version: its name with the date small beside it, each section under a counter's heading
## (`UITheme.section`), a change behind a bullet with its wrapped lines hanging clear of it, a table as
## the game's own (`UITheme.table_row`): the header soft over a rule, the rows striped.
static func _version(version: Dictionary, width: float) -> VBoxContainer:
	var column := UITheme.vbox(SECTION_GAP, width)
	var head := HBoxContainer.new()
	head.add_child(UITheme.label(version["version"]))
	var date := UITheme.label(version["date"], Palette.TEXT_SOFT, true)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(date)
	column.add_child(head)
	# On the first line's middle, whatever the body font's height.
	var line_height := UITheme.theme().get_font("font", "SmallLabel").get_height(UITheme.small_size())
	var bullet_top := floorf((line_height - BULLET) / 2.0)
	for section: Array in version["sections"]:
		var block := UITheme.vbox(BagPage.SLOT_GAP)
		column.add_child(block)
		if not str(section[0]).is_empty():
			block.add_child(UITheme.section(section[0]))
		var table: VBoxContainer = null
		for item: Variant in section[1]:
			if item is Array:
				var cells: Array = item
				if table == null:
					table = UITheme.vbox(0)
					block.add_child(table)
					table.add_child(UITheme.table_row(cells[0], cells[-1], false, width,
							Palette.TEXT_SOFT, Palette.TEXT_SOFT, false))
					table.add_child(UITheme.rule(width))
				else:
					table.add_child(UITheme.table_row(cells[0], cells[-1],
							table.get_child_count() % 2 == 0, width, null, null, false))
				continue
			table = null
			var line: String = item
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 0)
			var hang := Control.new()
			hang.custom_minimum_size.x = INDENT
			var bullet := ColorRect.new()
			bullet.color = Palette.SLOT_TAN_DK
			bullet.position = Vector2(1, bullet_top)
			bullet.size = Vector2(BULLET, BULLET)
			hang.add_child(bullet)
			row.add_child(hang)
			row.add_child(BountyList.wrapped(line, width - INDENT))
			block.add_child(row)
	return column
