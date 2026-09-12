# Incremendal Side Scroller

Godot 4.7 (GDScript) incremental game. Current work: a clickable, procedurally generated hex map drawn with AI-generated pixel-art sprites.

## Commands
Use the console build, so output reaches the terminal: `C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. The 4.5.1 exe on the Desktop is too old for this project.

| Task | Arguments (run from the project folder) |
|---|---|
| Import sprites and refresh the class cache (after adding scripts or sprites) | `--headless --path . --editor --quit` |
| Map and tileset tests | `--headless --path . -s res://tests/test_hex_map.gd` |
| Generation, town and map builder tests | `--headless --path . -s res://tests/test_generation.gd` |
| UI theme tests | `--headless --path . -s res://tests/test_ui_theme.gd` |
| Enemy roster and sprite geometry tests | `--headless --path . -s res://tests/test_enemies.gd` |
| Combat tests | `--headless --path . -s res://tests/test_combat.gd` |
| Run the game briefly | `--headless --path . --quit-after 30` |
| Screenshots (opens a window) | `--path . -s res://tests/screenshot_map.gd`, saved to `%APPDATA%\Godot\app_userdata\Incremendal Side Scroller\` |
| UI screenshots (opens a window) | `--path . -s res://tests/screenshot_ui.gd` (`ui_in_scene.png`, `ui_panel_crop.png`, `ui_kit.png`) |
| Combat screenshots (opens a window) | `--path . -s res://tests/screenshot_combat.gd` (`combat_start/hurt/elite/won/lost.png`, plus `combat_roster.png`, every enemy at fight size) |

"UID duplicate" warnings come from duplicated asset folders under `Assets/` and are harmless.

## Map code (`Scenes/Map/`)
| File | Contents |
|---|---|
| `hex_grid.gd` (`HexGrid`) | Pointy-top offset grid with odd rows shifted right (same as the TileMapLayers). `Edge` enum (E, SE, SW, W, NW, NE) and `EDGES`, `neighbor`, `neighbors`, `opposite`, `distance`, `corners`, and the edge bitmask pair `edge_mask` / `mask_edges` that roads are described with |
| `sheet_meta.gd` (`SheetMeta`) | Reads `AI-sprites/spritesheet/hex_tileset.json` once per run and hands out its `meta` block, so nothing restates the rules the sprites were drawn to. `env_adjacency()` is the adjacency table, with each environment's self-entry stripped |
| `hex_tileset.gd` (`HexTileset`) | Builds the TileSet at runtime from `AI-sprites/spritesheet/hex_tileset.json` (56×64 tiles). `atlas_coords`, `road_name`, `blend_name`, `env_rank`, `can_border`, `opaque_mask` |
| `hex_map.tscn` / `hex_map.gd` (`HexMap`) | GroundLayer, one `Blend_<env>` layer per spreading environment (created in `_ready`), RoadLayer, Highlight. `set_ground` redraws the blends of the cell and its neighbors, reading the environment of cells that aren't drawn yet through the `hidden_env` Callable, so a tile looks the same however late it is discovered. `get_tile_info` includes `blends` and `environments` (visible pixel share per environment). Owns the `fog` overlay and the `player` token. Signals `tile_hovered`, `tile_clicked`, and `dragged` (mouse movement while dragging, for the owner of the camera). A click selects a tile; a press that travels more than `DRAG_THRESHOLD` pans instead. `set_player_cell` moves the player token |
| `player_token.gd` (`PlayerToken`) | The player's character, an `AnimatedSprite2D` with an "idle" and a "run" animation from `Assets/Player`. The sheets' frames are wide (room for the attack swing), so one `BOUNDS` crop, the union over both sheets, cuts every frame down to the character; sharing it keeps the character still when the animation changes. Drawn at `SCALE` (half size). `walk(path)` runs it from tile to tile at `SECONDS_PER_TILE`, `advance(delta)` steps that on (tests drive it directly), `finish_walk()` jumps to the end, and `arrived` fires on the last tile. `HexMap` creates it in code, after the highlight, so it draws on top |
| `fog_overlay.gd` (`FogOverlay`) | The translucent grey hex drawn over every tile that is seen but not discovered. `HexMap` creates it in code, between the roads and the outlines |
| `hex_highlight.gd` | Hover and selection outlines: a bright band with a dark ink border, readable on every terrain |
| `environment_generator.gd` (`EnvironmentGenerator`) | Random-frontier growth under `ALLOWED`: prefers neighbors, boosts regions under `MIN_REGION_SIZE`, damps regions over `MAX_REGION_SIZE`, then merges small regions. `extend()` grows an existing map into new cells without touching the old ones (they are frozen against merging), which is how the map enlarges. Tunables are at the top |
| `town_world.gd` (`TownWorld`) | 256×256 world of towns (small 1%, medium 0.5%, fortress 0.1%, never on neighboring spots). Each town links to its 1/2/4 nearest towns (small/medium/fortress) within 20 steps, in both directions |
| `road_network.gd` (`RoadNetwork`) | Routes roads along the town links with A*, using only shapes the sprites have (straight, 120° curve, 3/4/6-way). Roads stop at town edges and never cross a town tile. Terrain-independent, so a world always gives the same roads. `extend()` adds the links a window brings into reach, routing each inside its own box (around its two towns), so a road never moves once laid — growing the map only ever adds edges, sometimes turning a drawn road into a junction |
| `map_builder.gd` (`MapBuilder`) | Generates the map (`START_RECT`: 20×11 cells around cell (0, 0), which the camera centers on screen) and draws it as the player uncovers it. `rect` is what the map covers now: coming within `EXPAND_MARGIN` of an edge grows it by `EXPAND_BY` on that side (`expand_if_needed`, on arrival), generating the new land, its tiles and the roads it brings into reach, and redrawing the blends and roads of drawn tiles the new land touches. Everything already generated stays exactly as it is. Every cell is in one `State`: `HIDDEN` (the fog of war, nothing drawn), `UNDISCOVERED` (drawn under the grey fog, can't be walked to) or `DISCOVERED`. `create()` generates everything and draws `start_cells()`: the discovered center, where the player starts, ringed by six undiscovered tiles. `discover(cell)` takes the grey off a tile next to the player (`can_discover`), draws the tiles behind it as undiscovered, and sends the player walking onto it. `move_to(cell)` sends the player walking to a discovered tile over `route_to(cell)`, a shortest path of discovered tiles (`can_move_to` refuses anything else, and anything at all while `walking`); arriving emits `arrived(cell)` and discovers nothing by itself. `reveal_all()` discovers the lot. `origin` is the world spot at cell (0, 0): generated environments, plus that environment's town sprite where the world has a town. Before drawing, it clears any town within `START_TOWN_DISTANCE` (5) of the center and guarantees a small town exactly that far out, which a road links to cell (0, 0); that town's world spot is `start_town`. `_spot(cell)` is the crossing from map cells to world spots |

`Scenes/main_scene.gd` has the exported `world_seed` and `map_seed` (0 = random; the used seeds are printed), `map_origin`, `zoom` (3 by default, whole numbers only so sprite pixels stay square) and `ui_scale` (2). It prints the clicked tile's environment weights and town connections, and builds the UI in code, so the scene file stays untouched while the editor has it open: a side panel flush against the right edge, running the full window height and hidden until a tile is selected, holding one row per environment on the tile (a 16 px swatch cut from that environment's own hex-sheet tile, plus its percentage), a "Discover" and a "Move here" button pinned to the bottom — discovering the tile next to you walks you onto it, and "Move here" goes back to any tile already discovered (the camera follows until the player arrives), and an X top-right that closes the panel and calls `HexMap.deselect()`.

## Combat code (`Scenes/Combat/`, `Scenes/Enemies/`)
A tile has to be taken before it can be discovered: ten enemies in 60 seconds, one click per point of damage. Winning calls `MapBuilder.discover` exactly as pressing Discover used to; losing changes nothing and can be retried at once.

| File | Contents |
|---|---|
| `enemy_roster.gd` (`EnemyRoster`) | Every enemy under `Assets/Enemies`: its `Tier` (COMMON/ELITE/BOSS), its `Size`, the environments it lives on, and its sheet per animation. Health is not written per enemy — `SIZE_HP` and `TIER_HP` multiply into `hp_modifier`, so the whole curve is tuned from two tables. `frame` and `bounds` are measured, not guessed (see the gotcha below) |
| `encounter.gd` (`Encounter`) | The rules, with no nodes: `for_tile(cell, env)` rolls nine commons and an elite, seeded from the cell so a tile always fields the same fight. Bosses are never rolled here. `hit()` takes a point off, `advance(delta)` runs the clock through the walk-ins and deaths, `won`/`lost` end it. Health is `hp_modifier` over a base that grows with the distance from cell (0, 0) |
| `combat_actor.gd` (`CombatActor`) | An `AnimatedSprite2D` built from a sheet at runtime, as `PlayerToken` is. Serves both sides. Scaled and stood up by its *idle* frames, so `position` is the middle of its feet whatever the attack or death frames sprawl into |
| `combat_scene.tscn` / `combat_scene.gd` (`CombatScene`) | The view: backdrop, the two fighters, the HUD, the clicks, the verdict. A `CanvasLayer` the main scene adds in front of the map rather than a scene change — the map holds a whole generated world in memory that a scene change would throw away, so it is hidden and its `process_mode` disabled instead. Drawn height comes from `SIZE_HEIGHT`, so a slime is knee-high and a boss looms |

## UI code (`Scenes/UI/`)
| File | Contents |
|---|---|
| `palette.gd` (`Palette`) | The few sprite-palette colours the game draws with in code rather than through a sprite (`INK`, `BONE`, `GOLD`, `EARTH_DK`, `SLATE`), the same hexes `hexlib.py` uses |
| `ui_theme.gd` (`UITheme`) | Builds the `Theme` at runtime from `AI-sprites/ui/ui_sheet.json`, the way `HexTileset` builds the TileSet. Each 24×24 sprite becomes an `AtlasTexture` in a `StyleBoxTexture` with an 8 px texture margin and tiled (never stretched) axes. `UITheme.theme()` returns the shared theme; use it through the type variations `WoodPanel`, `TextPanel`, `PanelLabel`, `WoodButton`, `WoodDangerButton`, `LightButton`, `LightDangerButton` |

Set `theme_type_variation` on a plain `Button` and Godot drives hover, press and disable itself; `wood` buttons are meant to stand on `WoodPanel`, `light` buttons on `TextPanel`. The main scene scales its panel by `ui_scale`, so UI pixels are a whole multiple of the screen pixel like the map's.

## Sprites
The sprites are generated by `AI-sprites-generator/` (Python, exported through Aseprite). Its README holds the palette, geometry, adjacency table and blend rules. `AI-sprites/` is build output: change the generator, preview with `qa.py` and get the user's approval, then run `build.py`.
The 9-slice UI sprites are separate: `ui.py` draws them, `qa.py ui <tag>` previews them and `build_ui.py` exports them to `AI-sprites/ui/` with their own `ui_sheet.json`. They stay out of the hex atlas so no existing atlas coordinate ever moves.
Both builds share `buildlib.py`: the Aseprite call, the pass that reads every exported PNG back and compares it to the source pixels, and the report. Which environments each road material is used on lives in `roads.py` (`MATERIAL_ENVS`), and is what ships to the engine as JSON meta `road_materials`.

## Rules and gotchas
- **Rules come from the JSON meta:** `blend_rule`, `blend_priority` and `env_adjacency`, all read through `SheetMeta` — `HexTileset.can_border` and `EnvironmentGenerator.allowed()` are the same table, so the generator cannot produce a border the sprites can't draw.
- **Map origins must be on even rows**, otherwise world neighbors don't match on-screen neighbors (`MapBuilder` asserts this).
- **Test pattern:** everything in `tests/` extends `tests/harness.gd`, which starts `_run` deferred and holds `_check`, the failure count, `_report("suite name")` and the shared `WORLD_SEED`. Each `_test_*` function returns `true` and `_run` checks that it did, so a script error counts as a failure.
- **Editor conflicts:** the Godot editor is often open. After changing `project.godot` or `.tscn` files outside it, reload the project so the editor doesn't overwrite them.
- **9-slice interiors must be 8-periodic:** a `StyleBoxTexture` repeats the centre and edge cells, so UI interior art has to be a pure function of `(x % 8, y % 8)` or the seams show when a panel is stretched. `qa.py ui` checks this.
- **Pixellari renders cleanly only at 16 px**, its native size; below about 14 the glyphs break up. To make the interface smaller, lower `ui_scale` rather than the theme's `FONT_SIZE`.
- **Enemy sheet geometry is measured, not guessed:** frame widths run 32 to 245 px with no relation to the sheet height, and a greatest-common-divisor guess gets Dwarf Warrior and Mimic wrong. The frame width is the smallest divisor of every sheet width in the pack where each frame boundary lands on a fully transparent column; `test_enemies.gd` re-checks that against the sprites, so adding an enemy means measuring it the same way.
- **Commit** `.uid` and `.import` files.
