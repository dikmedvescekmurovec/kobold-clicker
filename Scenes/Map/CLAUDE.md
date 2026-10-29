<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Map/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Map code (`Scenes/Map/`)
A procedurally generated hex map, uncovered tile by tile: a hexagon of land ringed by an ice wall, with frozen wasteland past it. **Read `DESIGN.md` here before changing generation, saving or naming** -- it holds the why.

## Files
| File | What it is for |
|---|---|
| `hex_grid.gd` (`HexGrid`) | Pointy-top offset grid, odd rows shifted right (same as the TileMapLayers): neighbours, distance, corners, edge masks |
| `sheet_meta.gd` (`SheetMeta`) | Reads `AI-sprites/spritesheet/hex_tileset.json` once and hands out its `meta` block |
| `hex_tileset.gd` (`HexTileset`) | Builds the TileSet at runtime from that JSON, plus the fallen walls' rubble and each environment's swatch (`env_icon`) |
| `hex_map.tscn` / `hex_map.gd` (`HexMap`) | The map's layers and what is drawn on them; hover, selection, clicks and drags |
| `player_token.gd` (`PlayerToken`) | The player's sprite walking a path, with dust, footsteps, footprints and a shadow |
| `backdrop.gdshader` | The thick fog behind the map |
| `cave_glow.gdshader` | The dark red light out of the Gollux cave's pit |
| `edge_fog.gd` (`EdgeFog`) | The backdrop's fog lapping onto every shown cell's edge that faces an unshown one |
| `fog_overlay.gd` (`FogOverlay`) | The grey hex over seen-but-uncharted tiles |
| `ambient.gd` (`Ambient`) | Weather particles and a `CanvasModulate` day cycle |
| `map_pointer.gd` (`MapPointer`) | A badge pinned to the window's edge toward a cell (a found chest, the hero) |
| `cave_sense.gd` (`CaveSense`) / `cave_sense.gdshader` | The Gollux cave as the hero feels it: a red band on the map room's edge toward it |
| `ice_overlay.gd` (`IceOverlay`) | The ice: snow on wall and seen wasteland cells, the wall's band, accents, the spill onto land |
| `hex_highlight.gd` | Hover and selection outlines |
| `environment_generator.gd` (`EnvironmentGenerator`) | Random-frontier growth of the environments under the sheet's `env_adjacency` |
| `town_world.gd` (`TownWorld`) | 256x256 world of towns laid out ring by ring round the map's origin, and their links |
| `road_network.gd` (`RoadNetwork`) | A* roads along town links |
| `map_builder.gd` (`MapBuilder`) | Generates and draws the map: land, wall and wasteland, cell states, charting, walking, and what each cell is |
| `tile_names.gd` (`TileNames`) | `generate`: a made-up word plus a feature word from the environment or the settlement tier |
| `map_save.gd` (`MapSave`) | `user://map.json`: everything generated and uncovered, read and written; the sheet's `fingerprint` |

## Rules
`(DESIGN.md: "X")` is the heading under `## Reference` in `DESIGN.md` that holds the full text (a file's name: its entry in "Files in full"); `why:` is an older section there.

### Generation and saves: nothing a seed or a save already holds may change
- **Never regenerate.** Both generators are order-dependent, not seed-dependent: the same seed and rect do *not* give the same land. (DESIGN.md: "Never regenerate")
- **Only ever add to a map:** land, roads, the town world and tile names are all saved, `EnvironmentGenerator.extend()` freezes the old cells and `RoadNetwork.extend()` never moves a laid road. (DESIGN.md: "Never regenerate")
- **Never move a `GOLDEN` digest** (`test_generation` pins what a seed generates): put the generator back, never the digest. (DESIGN.md: "Never move a `GOLDEN` digest")
- **Never reorder generation:** not the order or number of rolls, an iteration order, a sort or a `hash` seed -- saves hold that land and derive the rest from the same seeds. (DESIGN.md: "Never move a `GOLDEN` digest")
- **Widen `env_adjacency` only with `WIDENED_SHEETS`:** add the old `MapSave.fingerprint` against the new one, or every saved map is refused. (DESIGN.md: "Widen `env_adjacency` only with `WIDENED_SHEETS`"; why: "Even environments")
- **Never narrow `env_adjacency` that way:** an old map could hold a border the new table forbids. (DESIGN.md: "Widen `env_adjacency` only with `WIDENED_SHEETS`")
- **Stop on a refused save** and never write over it: `MapSave.load_from` has two nulls -- empty `problem` is a first run, a reason in it a refusal. (DESIGN.md: "Stop on a refused save")
- **Check every saved value's shape before reading it** (`TownWorld.is_numbers`, `typeof`): a typed read of the wrong thing stops the function short of its reason, which leaves by the first null. (DESIGN.md: "Stop on a refused save")
- **Keep the save's form:** env and state rows are one string per map row against a legend, and `MapSave.save` goes through `SafeFile`. (DESIGN.md: "map_save.gd")
- **Name a tile once,** as it first comes out of the fog (`_show`), and save the name; never recompute names on load. (DESIGN.md: "Name a tile once")
- **Place a pre-wall save's wall with `MapBuilder.migrated_radius(states)`;** `land_radius` is saved. (DESIGN.md: "map_builder.gd")
- **Put map origins on even rows** (`MapBuilder` asserts it), or world neighbours stop matching on-screen ones. (DESIGN.md: "Put map origins on even rows")
- **Take generation rules from the sheet's meta** through `SheetMeta`: `HexTileset.can_border` and `EnvironmentGenerator.allowed()` are one table, so the generator cannot make a border the sprites cannot draw. (DESIGN.md: "Take generation rules from the sheet's meta")

### Towns, roads and who may name whom
- **Lay towns out ring by ring round the origin** (`TownWorld.generate`): the fortress floored at one a ring, none within `KEEP_OUT`, never adjacent. (DESIGN.md: "town_world.gd")
- **Mirror `MapBuilder`'s rings in `TownWorld`:** `RING`, `FIRST_RING`, `KEEP_OUT` are its `WALL_STEP`, `START_LAND_RADIUS`, `START_TOWN_DISTANCE` (`test_generation` holds them), as TownWorld may not name MapBuilder. Rings count in `WALL_STEP`s whatever the Ring of Walls says. (DESIGN.md: "Mirror `MapBuilder`'s rings in `TownWorld`")
- **Plant the start town in `create` only** (towns within `START_TOWN_DISTANCE` of the centre cleared, a small one exactly that far out, a road to cell (0, 0)): `restore` does none of it, the saved world already has it. (DESIGN.md: "Plant the start town in `create` only")
- **Route roads only in shapes the sprites have, stopping at town edges.** (DESIGN.md: "road_network.gd")
- **Never name `MapBuilder` in `MapSave`** (Godot's cycle checker): states are raw ints there, `STATE_NAMES` the legend. (DESIGN.md: "Never name `MapBuilder` in `MapSave`")
- **Never name `MapBuilder` or `TownWorld` in `TileNames`:** a pure function of map seed and cell. (DESIGN.md: "tile_names.gd")

### Drawing
- **Draw a whole map through `_draw_saved`,** not `_show`: `set_ground` refreshes seven cells per call. (DESIGN.md: "Draw a whole map through `_draw_saved`")
- **List what stands on a cell's ground in `MapBuilder._draw_cell` only** (road, rubble, chest, footprints, lair, settlement, cave). `_draw_rubble` covers every land tile of a ring a wall stood on (`on_wall_ring`) but a settlement's. (DESIGN.md: "map_builder.gd")
- **Keep the layer order:** the `Backdrop` first; rubble over the blends, under the roads and the fog; `IceOverlay` then `EdgeFog` under `chests`; `towns` over the fog, the ice and the chests. (DESIGN.md: "hex_map.tscn / hex_map.gd")
- **Draw a settlement as two pictures:** the `town_<env>_<tier>` ground tile, and its buildings on `HexMap.towns` wherever a cell is drawn (`_draw_town`) but only on seen land, none on the wall or past it. (DESIGN.md: "Draw a settlement as two pictures")
- **Keep the generator's constants in step:** `IceOverlay`'s sheet constants (change both, rerun `build_ice.py`), `TOWN_ANCHOR` (`towns.ANCHOR`), `CAVE_GLOW_AT` (`caves.HOLE`). (DESIGN.md: "Keep the generator's constants in step")
- **Lift `EdgeFog` as a front from the player only for a charting or a reveal** (`_show(..., lift)`); a load, `create` and `reveal_all` show at once. (DESIGN.md: "edge_fog.gd")
- **Still the cave's light and `CaveSense` with animations off** (`breath`, `depth`, `flicker` at 0; `Anim.NONE`). (DESIGN.md: "cave_glow.gdshader")
- **Hide `MapPointer` only when its cell is inside `room` and seen, or the map is hidden;** it and `CaveSense` sit at `z_index` -1, under every panel. (DESIGN.md: "map_pointer.gd")
- **Let `CaveSense` tell which way and roughly how far, never which tile.** (DESIGN.md: "cave_sense.gd")
- **Keep `Ambient` a child of `HexMap`,** so it hides with it. (DESIGN.md: "ambient.gd")

### Pointer, finger and walk
- **Under a finger the hover is the tile last tapped, never where a drag went.** `DRAG_THRESHOLD` is in panel pixels, times `ui_scale` (`Cursors.TOUCH_SLOP` under a finger). (DESIGN.md: "hex_map.tscn / hex_map.gd")
- **While land is being chosen (`aim_radius` not -1) a click emits `cell_aimed`** instead of selecting. (DESIGN.md: "hex_map.tscn / hex_map.gd")
- **Stop a walk with `PlayerToken.stop_walk()`, never `stop`,** the sprite's own. (DESIGN.md: "player_token.gd")
- **Stand the token by its hero's marked feet** (`PlayerToken.dress`, `Characters.feet`; the user's, 2026-10-11): that column on the tile's foot point, the shadow under it, every hero `TALL`. `_face` mirrors the shift, since `flip_h` leaves `offset` alone. (DESIGN.md: "player_token.gd (PlayerToken)")
- **Run `_on_player_arrived` from `jump_to(cell)`,** so an arrival's every consequence follows. (DESIGN.md: "map_builder.gd")

### The wall and the land past it
- **Grow the map only when the wall falls** (`_break_wall` -> `_cover`); arrival grows nothing. (DESIGN.md: "Grow the map only when the wall falls")
- **Generate a wall's environments ahead on a `WorkerThreadPool` task** (`_generate_ahead`) that touches only its copy of `_envs` and `EnvironmentGenerator`'s statics. `_envs` changes nowhere but `_generate`; the dev's skip and the tests' `chart` of a wall generate in place. (DESIGN.md: "Grow the map only when the wall falls")
- **Give nothing past the wall until it falls:** wasteland is seen as snow, never charted or walked to, and `has_chest`, `envs_within` and `town_tier` only answer for `is_land`. (DESIGN.md: "Give nothing past the wall until it falls")
- **Read a wall tile as `WALL_NAME`, `area_variant` "plain" and `town_tier` -1,** and never save wall or wasteland names: the land under them is named once it thaws. (DESIGN.md: "Give nothing past the wall until it falls")
- **Use `wall_step` for walls only:** where the next stands and the fallen lie (`_break_wall`, `walls_fallen`). It is never saved: the main scene says it as the world is built, to `restore` itself. (DESIGN.md: "Use `wall_step` for walls only")
- **Keep `Encounter.walls_inside` counting in `WALL_STEP`s,** so the land is as hard as it ever was under the Ring of Walls. (DESIGN.md: "Use `wall_step` for walls only")
- **Keep the walls on level edges:** `START_LAND_RADIUS + 1` and `WALL_STEP` are multiples of `LEVEL_TILES` (4), which `test_generation` holds. `level_of` is the tile panel's number and the ceiling on drops; enemy health uses the smooth distance. (DESIGN.md: "Keep the walls on level edges"; why: "Walls on level edges (2026-09-28)")

### Charting and sight
- **Chart the first tile blind:** `can_chart` wants generated land or wall beside a charted tile, seen or not, and `chart` floors its sight at 0. (DESIGN.md: "Chart the first tile blind"; why: "Charting blind (2026-09-21)")
- **Under the Nightwalkers reach `dark_reach` steps out, across land** (`reach()` is 1 without it); the wall only ever ends a way. (DESIGN.md: "Chart the first tile blind")
- **Let distant charting (`distant`, the fourth wall's unlock) add seen tiles only** -- never a hidden one, never across the dark. (DESIGN.md: "Chart the first tile blind")
- **Clear `_chartable` whenever what may be charted changes** (`_show`, `_break_wall`, `place_cave`, a changed reach, `distant`): the hover asks `can_chart` on every mouse move. (DESIGN.md: "Chart the first tile blind")
- **Fight for every tile of `dark_path(cell)` in turn** (the main scene's `_dark_way`): `walk_onto` refuses a tile further out, `chart` takes the whole way at once only for the dev's skip, and a lost fight retreats to `chart_from(cell)`. (DESIGN.md: "Chart the first tile blind")
- **Never ask `name_of` of an undrawn cell,** which would name it: `HexMap.can_pick` lets a click land on one, so ask the builder's `env_at` and `level_of`. (DESIGN.md: "Chart the first tile blind")
- **Read a torch once, as a tile is charted:** `main_scene._sight()` is passed to `chart` there only. The shared `_reveal_around` (`chart`, `scour`) cannot reach past generated land. (DESIGN.md: "Read a torch once, as a tile is charted")
- **Let fog give way to gold in two places only:** `scour` and the chest star, both the fortuneteller's. (DESIGN.md: "Let fog give way to gold in two places only")

### Derived, never saved
- **Derive chests,** never save them: `has_chest` is a per-cell roll that holds until the tile is charted, drawn once seen (or anywhere under `Settings.show_all_chests()`). (DESIGN.md: "Derive chests")
- **Derive lairs as chests are** (`boss_at`, `trail_of`): a per-cell roll on open land that holds until the tile is charted, never on a chest or a fallen wall's ring nor within `LAIR_SPACING` of a lair nearer the middle; `_find_lairs` indexes every trail after `_generate` and as a save loads, and a boss and its prints are drawn on seen tiles only (anywhere under `Settings.show_all_bosses()`, `redraw_lairs`). (DESIGN.md: "Boss lairs on the map (2026-10-29)")
- **Never scan per frame:** `nearest_chest()` and `envs_within` go through every cell, so ask on arrival and when a town is walked into. (DESIGN.md: "Never scan per frame")
- **Derive `mods_of`** like `has_chest`, off `env_seed` and `ring_of` (not `Encounter.walls_inside`), and `[]` for anything but open land, any ring a wall stood on included. (DESIGN.md: "Derive `mods_of`")
- **Keep `can_farm` blind to where the player stands,** and refusing every settlement; `best_farm()` is the farmable tile farthest out. `can_move_to` refuses everything while `walking`. (DESIGN.md: "Keep `can_farm` blind to where the player stands")

### The Gollux cave
- **Keep one Gollux cave a world, saved** (`MapSave` version 4, `cave` absent for none). (DESIGN.md: "Keep one Gollux cave a world, saved")
- **Place it beside the wall tile just broken** (the user's, 2026-10-09; `breach`, not saved): `place_cave(breach)`, asked by the main scene only once `WallUnlocks.GOLLUX` is unlocked, picks by `hash([env_seed, "cave"])`, never on `on_wall_ring` or a settlement. (DESIGN.md: "Keep one Gollux cave a world, saved")
- **Treat a lair as a set piece too:** `mods_of` refuses it, the tile panel calls it "<boss>'s Lair", and the main scene fights it through `Encounter.for_lair` before it asks for a chest. (DESIGN.md: "Boss lairs on the map (2026-10-29)")
- **Treat the cave as a set piece:** `road_at`, `has_chest`, `mods_of`, `can_farm` / `can_farm_ground` all refuse it, and `name_of` names it from `TileNames.CAVE_FEATURES`. (DESIGN.md: "Keep one Gollux cave a world, saved")
- **Draw it through `HexMap.set_cave`** once seen and on land; a missing picture draws nothing. (DESIGN.md: "Keep one Gollux cave a world, saved")

## Gotchas
- **Find regions once in `_merge_small_regions`** and join them as they merge (`_join`): finding them all again after every merge was quadratic, 17 s of the third wall's fall and 80 s of the sixth's. (DESIGN.md: "Grow the map only when the wall falls")
- **The adjacency table is built the first time it is asked for (`allowed()`),** which after a load may be on the generate-ahead task's own thread. (DESIGN.md: "Grow the map only when the wall falls")
- **Every other wall of the Ring of Walls stands off a level edge:** `RING_OF_WALLS_STEP` is no multiple of `LEVEL_TILES`. (DESIGN.md: "Keep the walls on level edges")
- **`SheetMeta.env_adjacency()` has each environment's self-entry stripped.** (DESIGN.md: "sheet_meta.gd")
- **`FogOverlay.has_cell` is false at once,** though a removed cell fades over `LIFT_TIME`. (DESIGN.md: "fog_overlay.gd")
- **Nothing listens to `HexMap.tile_hovered`,** and its info is worked out only for a listener. (DESIGN.md: "hex_map.tscn / hex_map.gd")
- **Tests make no dust:** `PlayerToken`'s dust, footsteps and footprints come from `_process`, and tests drive `advance(delta)`. (DESIGN.md: "player_token.gd")
- **A `MapPointer` pinned to the edge went under the panels, out of a press's reach:** with a `pressed` Callable its disc is a `Button` that stands still at the foot of `room`. (DESIGN.md: "map_pointer.gd")
- **`player_cell` stands on the uncharted tile after `walk_onto` until the fight is decided;** `chart` of the tile underfoot arrives in place. (DESIGN.md: "map_builder.gd")
