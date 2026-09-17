<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Map/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Map code (`Scenes/Map/`)
A procedurally generated hex map, uncovered tile by tile and grown at its edges. **Read `DESIGN.md` here before changing generation, saving or naming** -- it holds the why.

| File | Contents |
|---|---|
| `hex_grid.gd` (`HexGrid`) | Pointy-top offset grid, odd rows shifted right (same as the TileMapLayers). `Edge` enum (E, SE, SW, W, NW, NE), `EDGES`, `neighbor`, `neighbors`, `opposite`, `distance`, `corners`, `edge_mask` / `mask_edges` |
| `sheet_meta.gd` (`SheetMeta`) | Reads `AI-sprites/spritesheet/hex_tileset.json` once and hands out its `meta` block. `env_adjacency()` has each environment's self-entry stripped |
| `hex_tileset.gd` (`HexTileset`) | Builds the TileSet at runtime from that JSON (56x64 tiles). `atlas_coords`, `road_name`, `blend_name`, `env_rank`, `can_border`, `opaque_mask`, `legal_road_masks` |
| `hex_map.tscn` / `hex_map.gd` (`HexMap`) | GroundLayer, one `Blend_<env>` layer per spreading environment, RoadLayer, Highlight, plus `fog`, `chests` and the `player` token made in code. `set_ground` redraws the blends of the cell **and its six neighbours**, reading undrawn cells through the `hidden_env` Callable. `get_tile_info` (incl. `blends`, `environments`). Signals `tile_hovered`, `tile_clicked`, `dragged`. `select_cell`, `deselect`, `selected_cell`, `NO_CELL`, `DRAG_THRESHOLD` |
| `player_token.gd` (`PlayerToken`) | The player's `AnimatedSprite2D` (idle, run), cropped by one shared `BOUNDS`. `walk(path)`, `advance(delta)` (tests drive it), `finish_walk()`, signal `arrived`. Dust comes from `_process`, so tests make none |
| `fog_overlay.gd` (`FogOverlay`) | The grey hex over seen-but-uncharted tiles. A removed cell fades over `LIFT_TIME`; `has_cell` is false at once |
| `ambient.gd` (`Ambient`) | Weather particles (`set_env`, from `WEATHER`) and a `CanvasModulate` day cycle. A child of `HexMap`, so it hides with it |
| `chest_pointer.gd` (`ChestPointer`) | A twinkling star pinned to the window's edge toward `target`; hidden when the chest is on screen and seen, or the map is hidden |
| `hex_highlight.gd` | Hover and selection outlines |
| `environment_generator.gd` (`EnvironmentGenerator`) | Random-frontier growth under `ALLOWED`, region size boosts and damping, small-region merge. `extend()` grows into new cells and freezes the old. Tunables at the top |
| `town_world.gd` (`TownWorld`) | 256x256 world of towns (small 1%, medium 0.5%, fortress 0.1%, never adjacent), each linked to its 1/2/4 nearest within 20 steps. `to_dict` / `from_dict` for the save |
| `road_network.gd` (`RoadNetwork`) | A* roads along town links, only in shapes the sprites have; roads stop at town edges. `extend()` adds links a bigger window reaches and never moves a laid road |
| `map_builder.gd` (`MapBuilder`) | Generates and draws the map. `START_RECT` 20x11 around cell (0, 0); `expand_if_needed` grows `rect` by `EXPAND_BY` within `EXPAND_MARGIN` of an edge, on arrival. Cell `State`: `HIDDEN`, `UNCHARTED`, `CHARTED`. `create` / `restore` / `to_save`; `chart`, `can_chart`, `chart_from`, `move_to`, `can_move_to`, `route_to`, `can_farm`, `walking`, signal `arrived`; `name_of`, `level_of`, `area_variant`, `seen`, `has_chest`, `nearest_chest`, `reveal_all`. `origin` is the world spot at cell (0, 0); `_spot(cell)` crosses from cells to world spots |
| `tile_names.gd` (`TileNames`) | `generate`: a made-up word plus a feature word from the environment or the settlement tier. A pure function of map seed and cell; names neither `MapBuilder` nor `TownWorld` |
| `map_save.gd` (`MapSave`) | `user://map.json`: seeds, origin, window, the whole town world, land, roads, tile names, states, player cell. Env and state rows are one string per map row against a legend. `fingerprint(tileset)` hashes the three sheet tables a map is read through. `save` goes through `SafeFile`; `load_from(path, problem, expect_sheet)` |

## Rules and gotchas
- **Generation rules come from the sheet's JSON meta** (`blend_rule`, `blend_priority`, `env_adjacency`) through `SheetMeta`: `HexTileset.can_border` and `EnvironmentGenerator.allowed()` are one table, so the generator cannot make a border the sprites cannot draw.
- **Map origins must be on even rows** (`MapBuilder` asserts it), or world neighbours stop matching on-screen ones.
- **Nothing generated is ever regenerated.** Both generators are order-dependent, not seed-dependent, so the same seed and rect do *not* give the same land. Land, roads, the town world and tile names are all written into the save; growing the map only ever adds.
- **A tile is named once, when it first comes out of the fog (`_show`), and the name is saved.** Do not recompute names on load.
- **`MapSave.load_from` has two nulls:** empty `problem` is a first run; a reason in `problem` is a refusal, and the caller must stop and never write over the file.
- **`MapSave` never names `MapBuilder`** (Godot's cycle checker): states are raw ints there, with `STATE_NAMES` as the legend.
- **Drawing a whole map goes through `_draw_saved`, not `_show`:** `set_ground` refreshes seven cells per call.
- **`MapBuilder.create` clears towns within `START_TOWN_DISTANCE` (5) of the centre and guarantees a small one exactly that far out,** linked by road to cell (0, 0). `restore` does none of that: the saved world already has it.
- **Chests are derived, not saved:** `has_chest` is a per-cell roll (open land, `CHEST_MIN_DISTANCE` out) that holds until the tile is charted. `nearest_chest()` scans every cell, so call it on arrival only, never per frame.
- **`level_of(cell)` comes in widening bands** (level `n` starts at the nth triangular number of steps); it is the tile panel's number and the ceiling on drops. Enemy health uses the smooth distance instead.
- **`can_farm` asks nothing about where the player stands;** `can_move_to` refuses everything while `walking`.
