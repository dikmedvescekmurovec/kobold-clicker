# Incremendal Side Scroller

Godot 4.7 (GDScript) incremental game. Current work: a clickable, procedurally generated hex map drawn with AI-generated pixel-art sprites.

## Commands
Use the console build, so output reaches the terminal: `C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. The 4.5.1 exe on the Desktop is too old for this project.

| Task | Arguments (run from the project folder) |
|---|---|
| Import sprites and refresh the class cache (after adding scripts or sprites) | `--headless --path . --editor --quit` |
| Map and tileset tests | `--headless --path . -s res://tests/test_hex_map.gd` |
| Generation, town, map builder and map save tests | `--headless --path . -s res://tests/test_generation.gd` |
| UI theme tests | `--headless --path . -s res://tests/test_ui_theme.gd` |
| Enemy roster and sprite geometry tests | `--headless --path . -s res://tests/test_enemies.gd` |
| Combat tests | `--headless --path . -s res://tests/test_combat.gd` |
| Skill tree tests | `--headless --path . -s res://tests/test_skills.gd` |
| Loot, rarity, inventory and save tests | `--headless --path . -s res://tests/test_inventory.gd` |
| Run the game briefly | `--headless --path . --quit-after 30` |
| Screenshots (opens a window) | `--path . -s res://tests/screenshot_map.gd`, saved to `%APPDATA%\Godot\app_userdata\Incremendal Side Scroller\` |
| Cut the UI sprites, the gear, orb and skill icons, the corner buttons' marks and the kill pips out of the bought packs | `python tools/ui_kit.py` (plain Python, no Godot) |
| Cut the loot beam out of the bought effects pack | `python tools/loot_beam.py` (plain Python, no Godot) |
| UI screenshots (opens a window) | `--path . -s res://tests/screenshot_ui.gd` (`ui_in_scene.png`, `ui_panel_crop.png`, `ui_inventory.png`, `ui_inventory_crop.png`, `ui_item_detail.png`, `ui_orb_craft.png` (the tray with a piece open, lit beside grey), `ui_orb_card.png`, `ui_skills.png` (the skills page part-spent with a card up), `ui_kit.png`) |
| Combat screenshots (opens a window) | `--path . -s res://tests/screenshot_combat.gd` (`combat_start/hurt/elite/won/lost.png`, `combat_nearly_dead.png` and `combat_boss_bar.png`, the two states of the nameplate's health bar nothing else shoots -- the boss one taken in a village fight, which is the only kind that fields one, so it shows the fifteen-pip bar and its minute's clock too, `combat_drop.png`, `combat_farm.png` with `combat_farm_loot/drop/ended.png`, plus `combat_area_<env>_<variant>_<n>.png`, one fight per environment on its own backdrop, `combat_layout_grass_village_<n>.png`, the same settlement in all four of its layouts, and `combat_roster.png`, every enemy at fight size) |

"UID duplicate" warnings come from duplicated asset folders under `Assets/` and are harmless.

## Where things are documented
Each code folder has its own `CLAUDE.md` holding the per-file descriptions and that area's rules and gotchas. It loads automatically once a file in that folder is read, so **read the source file before changing it or explaining it** — that loads the notes that go with it. `tests/` has no notes of its own: before editing a test, read the source it tests. Before a change that spans areas (a fight's loot reaching the bag, a stat reaching combat), read `Scenes/main_scene.gd` or `Scenes/CLAUDE.md`, which holds the cross-cutting rules.

**Map** — details in `Scenes/Map/CLAUDE.md`: `hex_grid.gd` (`HexGrid`), `sheet_meta.gd` (`SheetMeta`), `hex_tileset.gd` (`HexTileset`), `hex_map.tscn` / `hex_map.gd` (`HexMap`), `player_token.gd` (`PlayerToken`), `fog_overlay.gd` (`FogOverlay`), `hex_highlight.gd`, `environment_generator.gd` (`EnvironmentGenerator`), `town_world.gd` (`TownWorld`), `road_network.gd` (`RoadNetwork`), `map_builder.gd` (`MapBuilder`), `tile_names.gd` (`TileNames`), `map_save.gd` (`MapSave`)

**Main scene** — `Scenes/main_scene.gd`: seeds, zoom, `ui_scale`, and the whole UI built in code (tile panel, corner buttons, skills page, bag, character sheet, orb tray). Details and cross-area rules in `Scenes/CLAUDE.md`.

**Combat** — details in `Scenes/Combat/CLAUDE.md`: `encounter.gd` (`Encounter`), `drops_view.gd` (`DropsView`), `combat_actor.gd` (`CombatActor`), `combat_scene.tscn` / `combat_scene.gd` (`CombatScene`)

**Enemies** — details in `Scenes/Enemies/CLAUDE.md`: `enemy_roster.gd` (`EnemyRoster`)

**Skills** — details in `Scenes/Skills/CLAUDE.md`: `skill_tree.gd` (`SkillTree`), `skills.gd` (`Skills`)

**Items** — details in `Scenes/Items/CLAUDE.md`: `loot_table.gd` (`LootTable`), `item_rarity.gd` (`ItemRarity`), `modifier_table.gd` (`ModifierTable`), `equipment.gd` (`Equipment`), `item.gd` (`Item`), `orb_table.gd` (`OrbTable`), `inventory.gd` (`Inventory`)

**UI** — details in `Scenes/UI/CLAUDE.md`: `palette.gd` (`Palette`), `item_details.gd` (`ItemDetails`), `item_slot.gd` (`ItemSlot`), `coins.gd` (`Coins`), `kill_pips.gd` (`KillPips`), `health_bar.gd` (`HealthBar`), `orb_slot.gd` (`OrbSlot`), `orb_card.gd` (`OrbCard`), `loot_beam.gd` (`LootBeam`), `skill_slot.gd` (`SkillSlot`), `skill_tree_view.gd` (`SkillTreeView`), `skill_card.gd` (`SkillCard`), `ui_theme.gd` (`UITheme`)

## Sprites
The sprites are generated by `AI-sprites-generator/` (Python, exported through Aseprite). Its README holds the palette, geometry, adjacency table and blend rules. `AI-sprites/` is build output: change the generator, preview with `qa.py` and get the user's approval, then run `build.py`.
Generated sets (hex tiles, backdrops, slimes, the health bar): `AI-sprites-generator/CLAUDE.md`. Sprites cut from bought packs (UI theme, pips, gear, orbs, skill icons, loot beam): `tools/CLAUDE.md`.

## Rules and gotchas
- **Test pattern:** everything in `tests/` extends `tests/harness.gd`, which starts `_run` deferred and holds `_check`, the failure count, `_report("suite name")` and the shared `WORLD_SEED`. Each `_test_*` function returns `true` and `_run` checks that it did, so a script error counts as a failure.
- **Editor conflicts:** the Godot editor is often open. After changing `project.godot` or `.tscn` files outside it, reload the project so the editor doesn't overwrite them.
- **Pixellari renders cleanly only at 16 px**, its native size; below about 14 the glyphs break up. To make the interface smaller, lower `ui_scale` rather than the theme's `FONT_SIZE`.
- **A `Control`'s `size` is clamped to its minimum as it is set, and a `TextureRect`'s minimum is its texture until `expand_mode` says otherwise.** So asking a 32 px icon for a 16 px size while the mode is still the default gets 32, and lowering the minimum afterwards does not shrink what was already set -- `OrbSlot` sets `expand_mode` and `stretch_mode` *before* the texture and the size, and the orbs drew at double size until it did.
- **A lambda captures by value, and so is a `PackedStringArray`:** anything a test gathers from a signal has to be collected in an `Array`, which is shared, or the count outside the lambda never moves.
- **Commit** `.uid` and `.import` files.
