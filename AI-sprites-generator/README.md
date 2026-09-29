# AI-sprites generator

Rebuilds the 432-sprite hex tileset in `../AI-sprites/` (36 environments, 63 roads, 18 towns, 315 blend overlays, plus the spritesheet and JSON),
the 120 battle backdrops in `../Assets/Area/`,
the six per-environment slimes in `../Assets/Enemies/` (21 frames each, recoloured from the blue slime pack),
the combat nameplate's health-bar parts in `../Assets/UI/`,
and the gear icons no bought pack draws (55 item bases and ten uniques), which `../tools/ui_kit.py` imports and writes to `../Assets/Gear/`.
The earlier 18-sprite 9-slice UI kit in `../AI-sprites/ui/` (2 panels, 16 buttons) is still buildable but no longer wired to anything: the interface is cut from a bought pack by `tools/ui_kit.py`.
Everything is procedural and deterministic: the same code always produces the same pixels.

Godot skips this folder because of `.gdignore`.

## Requirements
- Python 3 with Pillow (`pip install pillow`)
- Aseprite. `build.py` expects the source build at
  `C:\Users\Dik\Documents\Git\aseprite\aseprite\build\bin\aseprite.exe`. Change `ASEPRITE` at the top of `build.py` if it moves.

## Commands (run from this folder)
| Command | What it does |
|---|---|
| `python qa.py phase1 <tag>` | Environments: border-match check between variants, illegal-border check, plus `qa/p1_sheet_<tag>.png` and `qa/p1_map_<tag>.png` |
| `python qa.py phase2 <tag>` | Roads: edge-zone match check, plus sheet and random road-network map |
| `python qa.py phase3 <tag>` | Towns: containment and border match vs `v1`, plus sheet |
| `python qa.py towns <tag>` | Settlements as the map shows them: each ground tile among its own land with its building sprite over it, clear and under the fog, in `qa/towns_<tag>.png` |
| `python qa.py showcase <tag>` | One map mixing all terrain, variants, roads and towns (illegal-border check included) |
| `python qa.py blends <tag>` | Blend overlays: spill, seam coverage and seam match vs `v1`, illegal borders, plus `qa/blend_pairs_<tag>.png` (before/after for each allowed pair), `qa/blend_map_<tag>.png` and 3× zooms `qa/blend_<hi>_<lo>_<tag>.png` |
| `python qa.py slimes <tag>` | Slimes: silhouette, palette and ramp checks, plus `qa/slimes_<tag>.png` (the baseline above all six, every frame) and `qa/slimes_ground_<tag>.png` |
| `python vista_scenes.py <tag> [env...] [variant...] [layout...] [fighters]` | Battle backdrops: every named (environment, variant, layout) on one sheet, `qa/vista_<tag>.png` -- one cell at 2x, more two to a row. Defaults are all six places, `plain`, layout 1; `fighters` stands the hero and a Masked Orc where the fight puts them (`vista_fighters.py`). A scene is about a third of a second |
| `python qa.py hpbar <tag>` | The health bar's nine parts: checks, plus `qa/hpbar_<tag>.png` |
| `python qa.py gear <tag>` | The generated gear icons among the pack's own: doubling, soft alpha, outline room, determinism, colour count and outline-ink checks, plus `qa/gear_<tag>.png` |
| `python qa.py ui <tag>` | The old 9-slice UI (unwired): size, silhouette, outline and 8-periodicity checks, plus `qa/ui_sheet_<tag>.png` and a `qa/ui_mock_<tag>.png` showing every state and the panels stretched from 16 px to 428 px |
| `python build.py` | Exports every hex PNG through Aseprite into `../AI-sprites/`, writes the spritesheet and JSON, then verifies each file pixel by pixel |
| `python build_ui.py` | The same for the UI sprites, into `../AI-sprites/ui/` with its own `ui_sheet.json` |
| `python build_areas.py` | Writes the 120 backdrops (`vista_scenes.render`) into `../Assets/Area/<env>_<variant>_<n>.png` at 4x, prunes names it no longer writes, and reads every file back to check it. About two and a half minutes; refuses to start while the Godot editor holds the files |
| `python build_towns.py` | Writes the 18 settlement building sprites (84x96, RGBA) into `../Assets/Towns/` and reads every file back. No Aseprite. Run `build.py` too: the ground tiles under them are in the atlas |
| `python build_hpbar.py` | Writes the health bar's parts loose into `../Assets/UI/` and reads every file back. No Aseprite |
| `python build_slimes.py` | Writes the six slimes into `../Assets/Enemies/<Env> Slime/` and reads every file back to check it. No Aseprite: the source is already a PNG pack and these ship as ordinary RGBA sprites, not as part of an indexed atlas |

`qa/` output is preview-only and git-ignored. `build.py` overwrites the files in `../AI-sprites/` (change `OUT` in `build.py` to write elsewhere).

## Files
| File | Contents |
|---|---|
| `hexlib.py` | Hex geometry, the palette (the original 32 plus the terrain ramps), dithering, lattice-periodic noise, `Tile` |
| `stamps.py` | Scatter placement, shaded domes, boulders, tufts, pebbles, lines, `seg_dist` |
| `terrain.py` | The six environments and their six variants (`v1`-`v3`, `accent`-`accent3`; `objects=False` gives bare ground for towns), the lighting kit (`relief`, `raised`, `canopy`, `pine`, `rock`, `pond`), the `"base"` pseudo-variant, and the adjacency rules (`ADJACENT`, `can_border`, `ENV_CHAIN`) |
| `roads.py` | Road overlays for dirt, stone and snow, with every rotation |
| `towns.py`, `build_towns.py` | The settlements: a 3/4 building renderer (`render`, `box`, `round_part`, `curtain`, `tiered`), each environment's looks and its village, town and fortress. `build(env, tier)` gives the ground tile (atlas) and the building sprite (`sprites()`, written by `build_towns.py`) |
| `blends.py` | Blend overlays: priority, coverage mask, fringe details per environment |
| `preview.py`, `qa.py` | Preview images and checks |
| `slimes.py` | The per-environment slimes: the baseline's eight colours, and the five-step `hexlib.PALETTE` body ramp each environment swaps in |
| `vista.py` | Backdrop toolkit, numpy on a 576x324 `Canvas`: stepped skies, cumulus and cirrus, sun and glow, stars and aurora, tent-peak ranges, mesas, dunes, rolling hills, drifts, trees, firs, leaf clumps, ferns, sun shafts; `tint` (a quantised wash) and `seat` (the row a footprint stands on) |
| `vista_build.py` | Building parts, front-on and lit from the upper left: walls (with batter and courses), timber framing, windows, doors, lancets, gable and pediment roofs, cones, domes, crenels and teeth, stacked tiers, arches, pennants, palms |
| `vista_towns.py` | `Site` (where a settlement stands, the hill raised under it, `build`), `row` (the placer that seats each piece), and the grass people's kit |
| `vista_kits.py` | The other five peoples' kits: dirt, forest, desert, mountains, ice -- one section each, reaching only its own pieces |
| `vista_props.py` | The open land: the road (`road_path`, `near_road`, `far_road`), signpost, milestone, cart, fence, pond, and each plain's landmark (oak, dead tree, standing stones, ruin, shards, cairn, log, mushrooms) |
| `vista_scenes.py` | The six places, one function each, `LAND` (road and landmark per place), `render(env, variant, layout)` and the preview CLI |
| `vista_fighters.py` | QA only: the hero and an enemy stood on a scene where `CombatScene` puts them |
| `hpbar.py` | The health bar's parts: a left cap, a right cap and a track in three tier colourways, in `hexlib.PALETTE` |
| `gearlib.py`, `gear.py` | The gear icons: `gearlib` is the kit and what was measured off the RPG pack, `gear` one function a kind (`ICONS`) and a unique (`UNIQUES`). No build script: `tools/ui_kit.py` writes them |
| `ui.py` | The old 9-slice UI (unwired): `RectTile` (rectangular, not hex), rect primitives, the two panels and the 16 buttons |
| `build.py`, `build_ui.py`, `buildlib.py`, `emit.lua` | Export through Aseprite in batch mode, JSON metadata, verification. `emit.lua` takes per-sprite `w`/`h`, and `buildlib.py` holds the Aseprite call and the read-back, so both builds share them |
| `build_areas.py`, `build_slimes.py`, `build_hpbar.py` | The builds that skip Aseprite: straight to RGBA PNGs under `../Assets/`, every file read back and compared |

## Rules that keep the set consistent
- **Geometry:** 56×64 pointy-top hex. Place tiles at 56 px columns and 48 px rows, with odd rows shifted 28 px.
- **Seamless edges:** anything within the outer band of a tile must come from environment-seeded, lattice-periodic data (`blend_fields`, `details(... shared ...)`), never from per-variant seeds. Towns copy their outer 2 px ring back from `v1`.
- **`"base"` pseudo-variant:** `ENVS[env]("base")` renders only the shared data, so it equals every variant's border band. Blends depend on this. Route any new per-variant data through `mix()` / `details()` so `"base"` skips it.
- **Roads:** centerlines run through edge midpoints on the center-to-center line, so they meet exactly. Rotation `_rK` means the canonical edges turned clockwise by K×60°.
- **Atlas layout:** groups are laid out in `build.GROUPS` order (environments, roads, towns, blends). Append new groups at the end so existing atlas coordinates don't move.
- **Palette:** all art uses `hexlib.PALETTE` (index 0 transparent). The first 32 entries are the original set and never move -- towns, roads, slimes and the UI index them. The terrain ramps (`gr` meadow, `fo`/`co` forest, `di` earth, `st` straw, `de` sand, `sn` snow, `ro` rock, `sc` scree, `wa` water, and for buildings `rf` terracotta and `pl` plaster) are appended after them; each runs dark to light and shifts hue as it goes, shadows cooler, lights warmer. Append, never insert.
- **Look:** light from the top-left, a dark outline (the ramp's darkest step, not ink) on the shaded side of objects only, no outline on terrain edges. Buildings use roofs from above plus a thin south-facing front wall.
- **Aseprite quirk:** in Lua, `json.decode` returns floats, and `Image:drawPixel` silently writes palette index 1 for a float. `emit.lua` converts with `math.tointeger` and reads every pixel back.
- **Build hiccup:** if `build.py` prints `Cannot save file ... in the given location` and reports a `sheet mismatch`, the spritesheet PNG was briefly locked (typically by the open Godot editor reimporting the new PNGs), and the JSON no longer matches the old sheet. Rerun `build.py` until `problems` are all zero.

### Environment tiles
- **Ground is lit, not painted.** Every environment builds a small lattice-periodic height field and `relief` shades it from the top-left, so tone comes from the light rather than from noise. Keep the relief shallow -- about one ramp step either side of the base tone. The first pass ran it at three steps and grass read as melted camouflage, dune slip faces as cracks and snow as crumpled paper.
- **Tall things are raised.** Peaks and mesas are height fields drawn by `raised`: each ground pixel is lifted by its height and drawn near-to-far per column, so the front hides the back. They are lit by `RAISED_LIGHT`, from the front-left, not by the ground's top-left `LIGHT`: a raised shape shows its south faces most, and a top-left light leaves every face the viewer sees in shade. `raised` never touches pixels within 6.5 of the border, so the shared band holds.
- **A feature must stand off its ground.** A rock, mesa or bush in its own environment's ramp disappears -- the first sandstone mesa and the grass bushes did. Give it a ramp at least a step darker, or another hue.
- **The shared band repeats on every tile,** so anything in it reads as a pattern across a region: the snow's wind streaks did at 3x until most of them moved into the variants' own interiors.
- **Known limit:** peaks can only live inside the band, so a big range still shows one massif per hex.

### Settlements
- **An icon, not a street plan.** One tight cluster in the middle, a few big shapes, two tones a surface. The first pass drew lanes, fields, stalls, windows and roof courses, and on the map it read as clutter; the user asked for "less detailed and more iconic".
- **Each environment keeps only its people's signature** from the backdrops: red gables, thatch cones under crossed poles, rammed-earth cubes with teeth, snow roofs over a warm light, tiered roofs under a gold finial, plaster blocks under a red spire.
- **Colours come from the terrain's ramps** (plus `rf` and `pl`), never the original 32: `bone`, `brick` and `rust` are brighter and more saturated than anything on the new ground and made every settlement look pasted on.
- **No ink outline.** An edge is the surface's own colour a step darker, on the shaded sides (right and below) and where a nearer part stands in front of a farther one; a lit side gets one only where the building would melt into the ground (a snow roof on snow). The black ring round every building was the other half of why they looked pasted on.
- **The buildings are a sprite, not part of the tile.** Inside the tile a town could only be about 35 px wide and sat under the fog's veil, and on the map it hid (the user: "a bit hidden, make them pop"). The tile now holds only the ground -- clearing, plate, shadows, halo -- and the buildings are an 84x96 sprite, laid out in tile units and scaled by `K` (1.35), which Godot draws over the fog and past the hex. A tile pixel and a sprite pixel are the same size, so the tile's shadows line up under the sprite through `SHIFT`.
- **A settlement must differ from its ground in value, not only hue.** Grass towns measured the same brightness as their meadow and vanished; the plate is a clear step lighter or darker than the land, and the buildings a clear step off the plate.
- **The ground round a town is calmed** (a majority filter on the clearing), so the buildings are the busiest thing there.

### 9-slice UI
- **Geometry:** 24x24 sprites made of nine 8x8 cells, so a `StyleBoxTexture` with an 8 px texture margin stretches them to any size down to 16x16. The four corner pixels are transparent, which rounds every panel and button the same way.
- **Periodicity:** Godot repeats the centre cell on both axes and the edge cells along theirs, so **all interior art must be a pure function of `(x % 8, y % 8)`**; borders and bevels must depend only on the distance to the sprite edge and stay in the outer cells. Tile the axes, never stretch them. `qa.py ui` fails if an interior pixel breaks this.
- **Which is why a panel face gets one mark at most.** Periodicity turns any interior texture into a stripe every 8 px, and the wood panel runs the full height of the window, so four marked rows per cell came out as corduroy that the labels on it had to be read through. The face is now a single `earth` plank seam on `soil`: the lit row, the butt-joints and the second dark row are gone, and the ink outline and dark inner rim do the rest of the wooden read. The white panel's face stays bare. Detail belongs in the outer 2 px, the only rows that do not repeat.
- **States:** normal (bevel out), hover (face one ramp step lighter), pressed (**the hover face with the bevel inverted**, so the dark rim merges with the ink outline and the button sinks - the label sinks 1 px with it), disabled (no bevel, one flat dull ring, face collapsed toward its own backdrop).
- **Surfaces:** `wood` buttons are light-faced for the brown panel, `light` buttons dark-faced for the white one. The `danger` flavour runs deep red to bright red (`brick_dk` -> `brick`); the palette's lighter steps skew orange, so `rust` appears only as a 1 px lit rim.
- **Own sheet:** the UI ships in `AI-sprites/ui/`, not the hex atlas, so hex atlas coordinates never move.

### Battle backdrops
- **The grid is the reference's:** `Assets/Area/Summer2.png` is 2304x1296 but blocky at exactly 4x, so the art is **576x324** and ships nearest-upscaled (`vista.W/H/SCALE`).
- **Depth is value.** A scene is painted back to front -- sky, far range, far hills, middle distance with its settlement, the near ground the fight is on -- and every layer further back is pulled toward that place's haze colour (`hz`). Nothing else says what is far: no outlines, no scale tricks.
- **A place is a time of day as much as a terrain.** Grass is a bright morning; forest a misty clearing, three walls of firs fading into haze, sun shafts and a canopy over the top edge; dirt a golden-hour steppe under a low sun, mesas lit on their left faces; desert noon over the dunes; mountains a sharp alpine valley; ice twilight, stars and an aurora, which is what makes the ice people's lit windows glow. Two places sharing a sky is the first thing that makes them one place.
- **Washes are quantised, never dithered across an area.** A Bayer dither over a whole region reads as a mesh at 2x; `Canvas.tint` pulls pixels toward a colour in a few flat steps with only a thin dithered seam between them. Skies are stepped bands for the same reason.
- **Clouds are heaps, lit from above.** The first backdrops' striped cloud layer read as a glitch and sat behind the HUD. A `cumulus` is overlapping puffs, each lit on top and shaded underneath, drawn back to front, its base cut flat.
- **Nothing can float, by construction.** A settlement's `Site` raises the middle ground into a hill before it is filled, then every piece is seated with `vista.seat` -- the lowest ground under its whole footprint -- so its foot reaches down to the land on every column; a piece on a slope stands in front of the rise rather than over a gap. The old generator anchored pieces to a single crest row and 71 of them hung in the air.
- **The fight owns the near ground; the landmark stands between the fighters.** The fighters stand at `CombatScene.GROUND` (0.86, row 278) on the near ground, the hero at 0.24 and the enemy at 0.72 of the width, so whatever a scene is about -- a fortress, an oak, a pond -- is centred between them in the middle distance (`Site` centres 0.47-0.53). A settlement behind the hero is a settlement nobody sees.
- **Six places, six ways of building, and nothing shared between them.** Each environment commits
  to one wall material, one roof logic and one signature motif, and no two share any of the three:

  | env | wall | roof | signature |
  |---|---|---|---|
  | grass | cream plaster in dark oak, on limestone | steep gables, gable-front townhouses | round stair-turret under a tall slate cone and a pennant |
  | dirt | brown daub and warm rubble | fat thatch cone; flat crenellated | crossed poles over a thatch apex; grouped lancets |
  | ice | dark timber and carved ice | upswept eaves under a load of snow | a warm light in every opening; ice needles |
  | forest | timber on posts over mossy stone | steep dark thatch; receding stacked tiers (meru) | a gold finial on every apex; split gates |
  | mountains | warm ashlar, timber galleries bolted on | flat parapet deck | red cone, pennant, arcaded viaduct |
  | desert | red rammed earth, battered | flat parapet deck | pointed merlon teeth, incised lattice, palms |

  Within one environment the village, the town and the fortress are the same people at three scales. A kit reaches only its own pieces (`vista_kits.py` one section a people), which is what stops the old mistake -- one shared castle kit made four of six fortresses the same grey building.
- **A fortress is one dominant mass on a hill,** everything stepping down from it, its foot hidden (a curtain along the slope, the temple's terraces, a toothed outer wall, a wall of ice blocks), and its tallest point wears the culture's crown. Dirt's is the exception by design: a rubble box with the top bitten out of it, windows open onto the sky, and no crown at all -- the grimmest of them.
- **The viaduct only spans a drop.** Its deck is level and its piers run down to the ground, so it is only as tall as the land falling away beneath it; laid under a whole castle it read as a platform, so it strides off the hill toward one edge of the frame.
- **A road curves up into the distance.** `road_path` runs from low on one side to the crest on the other, its width falling with distance from the horizon, and narrows to nothing over the rise rather than stopping square; two of the four layouts pick it up again beyond the hill (`far_road`). The first backdrops laid a straight band across the whole width, which read as a stripe.
- **Every plain has its landmark,** one per layout, standing at the back of the fighting ground between the two sides: an oak, a pond, standing stones, a colonnade, a dead tree, cairns, an oasis, ice shards, a fallen log. Drawn on the middle distance they came out as specks.
- **Every (variant, layout) has its own sky.** `render` seeds by both, so the plain and the village of one layout are not the same picture with houses added.

### Slimes
- **A pure swap:** every environment slime is the blue pack under `Assets/Enemies/Slime` with its five-step body ramp exchanged for one built from `hexlib.PALETTE`, pixel for pixel. Nothing is drawn on top, so the silhouette, the shading and the animation timing stay the baseline's -- `qa.py slimes` fails on a single changed alpha pixel, an off-palette colour, a leftover baseline colour, or a frame whose colour count moved (a ramp step collapsing into its neighbour).
- **Ramps start mid-dark:** the baseline spends its largest mass on the *darkest* step, so a ramp that starts at the palette's floor reads as a black blob with a lit rim. Every ramp begins one or two steps up from it.
- **The eye stays red** (`brick_dk` / `brick` / `rust`) in all six: it is what makes them read as one creature. `rust` stands in for a light red because the palette's lighter steps skew orange, the same substitution the UI kit's danger buttons make.
- **The blue original is the source, not an enemy.** It has no roster entry; `EnemyRoster` lists the six, each on its own environment.

### Environment adjacency
Which environments may border each other (`terrain.ADJACENT`, exported as `env_adjacency`). The table is symmetric, and the same environment is always allowed. Maps, QA layouts and demos must only use allowed borders. `ENV_CHAIN` (desert, dirt, forest, grass, ice, mountains) is a legal order for side-by-side bands.

| | grass | dirt | desert | ice | forest | mountains |
|---|---|---|---|---|---|---|
| grass | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ |
| dirt | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| desert | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ |
| ice | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ |
| forest | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ |
| mountains | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### Blend overlays (soft transitions)
- **Precedence:** `blends.PRIORITY` (exported as `blend_priority`) is dirt < grass < desert < ice < forest < mountains. Where env A borders a lower-priority tile, A's overlay is drawn on that tile. Allowed spreads: grass→dirt, desert→dirt, ice→grass, forest→grass/dirt, mountains→all.
- **Sprites:** `blends/blend_<env>_<edges>.png` (e.g. `blend_forest_E_SE`) names the edges that touch A, and the JSON entries carry `env` and `edges`. All 63 edge sets are pre-rendered for each env except dirt (315). Draw order: environment, then overlays in priority order, then roads.
- **Seams:** covered pixels copy A's `"base"` tile at the same local pixel. Coverage depends only on the distance to A's hexes plus lattice-periodic noise, so both sides of every seam and corner agree. Forest trees are drawn whole, copied from `forest_shared_trees()` in the same order as the forest tile. Fringe details must fit inside the hex.
- **Towns** never receive overlays, but their environment still spreads into weaker neighbours.
- **Approved look (mockup m2):** `FULL` 4, `DEPTH` 26, `WOBBLE` 7, patch noise `0.55·big + 0.25·fine + 0.2·bayer`. A single weaker tile surrounded by a stronger env is mostly covered; this is accepted.
- **Workflow:** change art as a mockup first (`qa.py blends <new tag>`), review the images, then export.
