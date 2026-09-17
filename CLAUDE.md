# Incremendal Side Scroller

Godot 4.7 (GDScript) incremental game. Current work: a clickable, procedurally generated hex map drawn with AI-generated pixel-art sprites.

## Commands
Use the console build, so output reaches the terminal: `C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. The 4.5.1 exe on the Desktop is too old for this project.

| Task | Arguments (run from the project folder) |
|---|---|
| Import sprites and refresh the class cache (after adding scripts or sprites) | `--headless --path . --editor --quit` |
| **All tests** (run before calling anything done) | `python tests/run_all.py` -- every `tests/test_*.gd`, failing on a non-zero exit **or any `SCRIPT ERROR`**: Godot exits 0 when a script a suite depends on does not parse, so a bare exit code lies |
| One or more suites | `python tests/run_all.py combat inventory` -- `hex_map` (map, tileset), `generation` (generation, towns, map builder, map save), `ui_theme`, `enemies` (roster, sprite geometry), `combat`, `skills`, `inventory` (loot, rarity, inventory, save), `town` (services, prices, selling, buying, vendor stock, town state, bounty board) |
| A suite with its full output | `--headless --path . -s res://tests/test_<suite>.gd` |
| Run the game briefly | `--headless --path . --quit-after 30` |
| The town balance table (prices against what a fight pays, at tile levels 1/3/5/8/10) | `--headless --path . -s res://tests/balance_town.gd` -- prints only, asserts nothing; run it before and after moving a dial in `Scenes/Town/` |
| Screenshots (opens a window) | `--path . -s res://tests/screenshot_map.gd`, saved to `%APPDATA%\Godot\app_userdata\Incremendal Side Scroller\` |
| Cut the UI sprites, the gear, orb and skill icons, the corner buttons' marks and the kill pips out of the bought packs | `python tools/ui_kit.py` (plain Python, no Godot) |
| Cut the loot beam out of the bought effects pack | `python tools/loot_beam.py` (plain Python, no Godot) |
| UI screenshots (opens a window) | `--path . -s res://tests/screenshot_ui.gd` -- `ui_*.png`: the tile panel, the bag, the card beside a hovered piece (`ui_item_card.png`), an item open, orb crafting, the orb card, the comparison, the skills page, a town tile's panel, the town page at each of its counters, the question Sell all asks (`ui_confirm_sell.png`), a piece off a vendor's shelf open with its Buy button (`ui_town_buy.png`), the blacksmith with a piece held up to him (`ui_town_smith.png`) and what he leaves on one (`ui_town_broken.png`), a bounty board's three cards (`ui_town_board.png`) and the same board with one taken on (`ui_town_bounties.png`), the bounty journal away from town (`ui_bounty_journal.png`), the theme kit |
| Combat screenshots (opens a window) | `--path . -s res://tests/screenshot_combat.gd` -- `combat_*.png`: each fight state (start, hurt, elite, won, lost, nearly dead, boss bar, drop), a farm run, one fight per environment and variant (`combat_area_*`), one settlement in its four layouts (`combat_layout_*`), and `combat_roster.png` |

"UID duplicate" warnings come from duplicated asset folders under `Assets/` and are harmless.

## Where things are documented
Each code folder has its own `CLAUDE.md`: a one-line description per file plus that area's rules and gotchas. It loads automatically once a file in that folder is read, so **read the source file before changing it or explaining it**. Beside most of them is a **`DESIGN.md`** holding the long-form reasoning (why the UI is laid out as it is, what was tried and turned down, how the balance is meant to feel). It is *not* loaded automatically: **read it before changing how something is meant to work, and put new reasoning there, not in `CLAUDE.md`** -- keep each `CLAUDE.md` to short rules. `tests/` has no notes of its own: before editing a test, read the source it tests. Before a change that spans areas (a fight's loot reaching the bag, a stat reaching combat), read `Scenes/CLAUDE.md`, which holds the cross-cutting rules.

**Map** — details in `Scenes/Map/CLAUDE.md`: `hex_grid.gd` (`HexGrid`), `sheet_meta.gd` (`SheetMeta`), `hex_tileset.gd` (`HexTileset`), `hex_map.tscn` / `hex_map.gd` (`HexMap`), `player_token.gd` (`PlayerToken`), `fog_overlay.gd` (`FogOverlay`), `hex_highlight.gd`, `environment_generator.gd` (`EnvironmentGenerator`), `town_world.gd` (`TownWorld`), `road_network.gd` (`RoadNetwork`), `map_builder.gd` (`MapBuilder`), `tile_names.gd` (`TileNames`), `map_save.gd` (`MapSave`), `ambient.gd` (`Ambient`), `chest_pointer.gd` (`ChestPointer`)

**Main scene** — `Scenes/main_scene.gd`: seeds, zoom, `ui_scale`, start-up and saves, the tile panel and corner buttons, which left-hand page is up, tips, and opening and closing fights. Details and cross-area rules in `Scenes/CLAUDE.md`.

**Combat** — details in `Scenes/Combat/CLAUDE.md`: `encounter.gd` (`Encounter`), `fight_ledger.gd` (`FightLedger`), `drops_view.gd` (`DropsView`), `combat_actor.gd` (`CombatActor`), `combat_scene.tscn` / `combat_scene.gd` (`CombatScene`)

**Towns** — details in `Scenes/Town/CLAUDE.md`: `town_services.gd` (`TownServices`), `town_prices.gd` (`TownPrices`), `town_state.gd` (`TownState`), `vendor_stock.gd` (`VendorStock`), `blacksmith.gd` (`Blacksmith`), `bounty_board.gd` (`BountyBoard`)

**Enemies** — details in `Scenes/Enemies/CLAUDE.md`: `enemy_roster.gd` (`EnemyRoster`)

**Skills** — details in `Scenes/Skills/CLAUDE.md`: `skill_tree.gd` (`SkillTree`), `skills.gd` (`Skills`)

**Items** — details in `Scenes/Items/CLAUDE.md`: `loot_table.gd` (`LootTable`), `item_rarity.gd` (`ItemRarity`), `modifier_table.gd` (`ModifierTable`), `equipment.gd` (`Equipment`), `item.gd` (`Item`), `orb_table.gd` (`OrbTable`), `inventory.gd` (`Inventory`)

**UI** — details in `Scenes/UI/CLAUDE.md`: `bag_page.gd` (`BagPage`), `skills_page.gd` (`SkillsPage`), `town_page.gd` (`TownPage`), `bounty_list.gd` (`BountyList`), `character_panel.gd` (`CharacterPanel`), `juice.gd` (`Juice`), `palette.gd` (`Palette`), `item_details.gd` (`ItemDetails`), `item_slot.gd` (`ItemSlot`), `item_card.gd` (`ItemCard`), `coins.gd` (`Coins`), `kill_pips.gd` (`KillPips`), `health_bar.gd` (`HealthBar`), `orb_slot.gd` (`OrbSlot`), `orb_card.gd` (`OrbCard`), `loot_beam.gd` (`LootBeam`), `skill_slot.gd` (`SkillSlot`), `skill_tree_view.gd` (`SkillTreeView`), `skill_card.gd` (`SkillCard`), `ui_theme.gd` (`UITheme`)

## Sprites
The sprites are generated by `AI-sprites-generator/` (Python, exported through Aseprite). Its README holds the palette, geometry, adjacency table and blend rules. `AI-sprites/` is build output: change the generator, preview with `qa.py` and get the user's approval, then run `build.py`.
Generated sets (hex tiles, backdrops, slimes, the health bar): `AI-sprites-generator/CLAUDE.md`. Sprites cut from bought packs (UI theme, pips, gear, orbs, skill icons, loot beam): `tools/CLAUDE.md`.

## Rules and gotchas
- **Test pattern:** everything in `tests/` extends `tests/harness.gd`, which starts `_run` deferred and holds `_check`, the failure count, `_report("suite name")` and the shared `WORLD_SEED`. Each `_test_*` function returns `true` and `_run` checks that it did, so a script error counts as a failure.
- **Editor conflicts:** the Godot editor is often open. After changing `project.godot` or `.tscn` files outside it, reload the project so the editor doesn't overwrite them.
- **Pixellari renders cleanly only at 16 px**, its native size; below about 14 the glyphs break up. To make the interface smaller, lower `ui_scale` rather than the theme's `FONT_SIZE`. **Body text (stat lines, modifiers, card bodies, sentences) is Ark Pixel at its native 10 px** (`UITheme.SMALL_FONT`, the `SmallLabel` variation); names, headings and button faces stay Pixellari.
- **A `Control`'s `size` is clamped to its minimum as it is set, and a `TextureRect`'s minimum is its texture until `expand_mode` says otherwise.** So asking a 32 px icon for a 16 px size while the mode is still the default gets 32, and lowering the minimum afterwards does not shrink what was already set -- `OrbSlot` sets `expand_mode` and `stretch_mode` *before* the texture and the size, and the orbs drew at double size until it did.
- **A lambda captures by value, and so is a `PackedStringArray`:** anything a test gathers from a signal has to be collected in an `Array`, which is shared, or the count outside the lambda never moves.
- **Saves are written through `SafeFile` (`Scenes/safe_file.gd`) and a save that cannot be read is refused, never overwritten:** `SafeFile.write` goes to `<path>.tmp` and renames, `SafeFile.recover` runs before a read. `Inventory.load_from` and `MapSave.load_from` both report a bad file through a `problem` array, and `main_scene._ready` stops on either (`_refuse_save`) before anything can write.
- **Commit** `.uid` and `.import` files.
