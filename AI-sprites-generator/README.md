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
| `python qa.py areas <tag> [env...]` | Battle backdrops: skeleton, variant, palette-size, layout-twin and cross-environment `cousins` checks, plus the 6x5 contact sheet `qa/area_sheet_<tag>.png` and the layouts sheet. Name environments to scope it -- a full pass is over two minutes, one place is ten seconds |
| `python qa.py frozen check` | The desert's twenty scenes against their recorded hashes. Two seconds; run it after anything that touches a shared primitive |
| `python qa.py audit` | Every piece name every plan asks for, resolved against the kit that would draw it, plus whether anything anchored to a rock actually sits on it. Under a second, no rendering |
| `python qa.py hpbar <tag>` | The health bar's nine parts: checks, plus `qa/hpbar_<tag>.png` |
| `python qa.py gear <tag>` | The generated gear icons among the pack's own: doubling, soft alpha, outline room, determinism, colour count and outline-ink checks, plus `qa/gear_<tag>.png` |
| `python qa.py ui <tag>` | The old 9-slice UI (unwired): size, silhouette, outline and 8-periodicity checks, plus `qa/ui_sheet_<tag>.png` and a `qa/ui_mock_<tag>.png` showing every state and the panels stretched from 16 px to 428 px |
| `python build.py` | Exports every hex PNG through Aseprite into `../AI-sprites/`, writes the spritesheet and JSON, then verifies each file pixel by pixel |
| `python build_ui.py` | The same for the UI sprites, into `../AI-sprites/ui/` with its own `ui_sheet.json` |
| `python build_areas.py` | Writes the 120 backdrops into `../Assets/Area/<env>_<variant>_<n>.png` at 4x, prunes names it no longer writes, and reads every file back to check it |
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
| `town_parts.py` | The old building and prop primitives; no hex tile uses them any more, only the backdrops' `areaplan.py` |
| `towns.py`, `build_towns.py` | The settlements: a 3/4 building renderer (`render`, `box`, `round_part`, `curtain`, `tiered`), each environment's looks and its village, town and fortress. `build(env, tier)` gives the ground tile (atlas) and the building sprite (`sprites()`, written by `build_towns.py`) |
| `blends.py` | Blend overlays: priority, coverage mask, fringe details per environment |
| `preview.py`, `qa.py` | Preview images and checks |
| `slimes.py` | The per-environment slimes: the baseline's eight colours, and the five-step `hexlib.PALETTE` body ramp each environment swaps in |
| `arealib.py` | Backdrop toolkit: banded skies, cloud ceilings and banks, triangular mountain ranges, ridges, foliage clumps, rocks, furrows, patches, flowers |
| `areapal.py` | One palette per environment for the backdrops, plus the peak and haze colours |
| `areabuild.py` | The primitives and what every place shares: rectangles and boxes, road, rock, water, haze, trees, fences, a signpost. Nothing that is *built* -- that lives in the six `bld_<env>.py` |
| `areas.py` | The scenes themselves: skylines, ground cover, the settlement dispatch, and the `sheet` and `layout_sheet` previews. `scene(env, variant, seed, layout)` -- one layout step moves the *shared* seed, so `plain` and `road`, which build nothing, still come in four |
| `bld_<env>.py` | One culture's own pieces, six files. A piece here cannot be reached by another environment, which is the point rather than the filing -- see the rule below |
| `lay_<env>.py` | One culture's own twelve plans, four to a variant |
| `areaplan.py` | The settlement layout engine: `Site`, the `Land`/`Row`/`Course`/`Fix`/`Belt` steps, and the `KIT`/`TREE`/`LATE` tables. `KIT[env]` -- there is no style name in between, because nothing is shared. A plan is an ordered list of steps and list order is draw order |
| `arealayouts.py` | A thin index over the six `lay_<env>` catalogues: `LAYOUTS[env][variant]`, one plan per layout index |
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
- **The reference sets the grid:** `Assets/Area/Summer2.png` is 2304x1296 but blocky at exactly 4x, so the art is **576x324** and ships nearest-upscaled. `arealib.W/H/SCALE` hold that.
- **One skeleton, six places:** every scene has the horizon at y=200 and the land starting at y=202, with four bands under it. An enemy standing at a given height stands in the same spot whatever the backdrop, and `qa.py areas` fails if a scene moves the land.
- **A settlement is a plan, not a function.** `areaplan.py` walks a cursor along a span dropping seeded pieces, so two seeds give two villages rather than one village jittered; `arealayouts.py` says which plan each (environment, variant) builds. The bar the engine had to clear was the ksar -- a `Land("mesa")` publishes a standing line, a `Course` walks down it and draws the highest houses first, which is why it reads as a stack of cubes and not a pile.
- **Measure a layout family by its roofline, not by its pixels.** Two seeds of one plan already differ in thousands of pixels and still read as one town, and a whole-image diff passes at about a third whatever you do, because the sky and the cover are seeded anyway. `qa.py areas` takes the topmost row where a scene differs from `plain` at the same layout -- which isolates the settlement exactly -- and counts columns whose roofline moved, out of the columns that have anything built in them.
- **Six places, six ways of building, and nothing shared between them.** Each environment commits
  to one wall material, one roof logic and one signature motif, and no two share any of the three:

  | env | wall | roof | signature |
  |---|---|---|---|
  | grass | cream plaster in dark oak, on limestone | steep, dormered | round stair-turret under a tall slate cone |
  | dirt | brown daub and undressed rubble | fat thatch cone; flat crenellated | crossed poles over a thatch apex; grouped lancets |
  | ice | dark timber and carved ice | upswept eaves under a load of snow | a warm light in every opening |
  | forest | timber posts on mossy stone | receding stacked tiers | a finial on every apex |
  | mountains | warm ashlar, timber galleries bolted on | flat parapet deck | red cone, pennant, arcaded viaduct |
  | desert | red rammed earth, battered | flat parapet deck | pointed merlon teeth, incised lattice |

  Both halves matter. Within one environment the village, the town and the fortress are the same
  people at three scales; between environments no two build the same shape out of the same stuff.
  `qa.py areas` measures the second half as `cousins`, and it takes both axes -- on silhouette
  alone it called a gold temple and a white ice palace one place, and on material alone it would
  miss four grey castles that each had a different `stone` value.

- **A fortress is composed to three rules, in its own culture's terms.** One dominant mass with
  everything stepping down from it. The base hidden, so you cannot see where it meets the ground --
  haze, a curtain, a viaduct, whatever that place has. And the tallest thing carries that culture's
  own crown: a slate cone and a pennant in grass, a red cone in the mountains, a needle in ice, a
  gold finial in forest, toothed merlons in the desert, and in dirt nothing at all, because dirt's
  fortress is a box with the top taken off and that is what makes it the grimmest of them.

- **There was a shared castle once, and it is why this was rewritten.** A grand tower, a curtain,
  a great gate and a flight of steps used to be injected into every style, so six cultures drew
  from one set of castle pieces and differed only by tint -- four of the six fortresses were the
  same building. Pieces now live one culture to a file and a plan can only reach its own, which
  makes the mistake unavailable rather than merely discouraged.

- **A piece standing on a rock wants `on="land"`, not `on="crest"`.** A mesa is only at full
  height in the middle: its profile is `(1 - t**1.7)`, so anything anchored to the single highest
  row and placed further out hangs in the air over the shoulder. `crest` is for things that must be
  level with the summit, and a wall running wider than its rock is an outer curtain -- it belongs
  at ground level with the citadel above it. `qa.py audit` checks this.

- **A fortress is the one thing allowed to dominate the frame.** The twenty non-desert ones are hand-written rather than varied off a template, and each keeps three rules: height comes from ONE dominant mass with everything stepping down from it, never several towers of a height; the base is hidden, in `Land("mist")` or behind a curtain or over a `mesa`, because a castle you can see the bottom of is a building; and the tallest thing carries a `pennant`, which at this size does more for scale than another fifty pixels of stone. The first pass built them wide and low -- dirt's rose twenty-nine pixels above the horizon -- and they now clear a hundred.
- **Haze must blend, and the blend must be quantised.** `mist` mixes toward the palette's `horizon` in three fixed steps. Replacing pixels outright drew a bright band across the curtain wall that read as damage, and a *continuous* mix is no longer a limited palette -- it put six scenes over the colour ceiling on its own, which is what that check is for.
- **A ruin is drawn top-first.** Work out the broken profile, then draw each column only up to it. Painting the missing part dark instead puts a black slab on the skyline where there should be sky.
- **A fortress is mostly `Fix` pieces**, so its layouts are the ones that come out as twins: walls, towers and a gate that do not move leave only the outliers to vary. That is the worklist the twins check prints, not a bug in it.
- **The pale top is the cloud ceiling, not a band.** Each sky ramp starts at its deepest blue and `overcast()` paints the pale sheet over it with a ragged edge; baking the pale into the ramp gives a dead straight line across the top of the picture.
- **Ground reads as noise when every mark is the same size.** Each cover is big soft `patches` first, then mid-scale marks (`furrows`, `ripple_layer`, `clump_layer`), then a few `boulders` -- never one dense speckle layer.
- **A road runs across the shot, not into it.** The fight happens on the near band, and at this scale a vanishing point is four pixels wide and reads as a spike, so the road variant lays a track across the front and a second one out in the field. Roads on the map run town to town anyway.
- **The desert builds in earth, so it gets its own vocabulary.** Re-tinting a gabled hut sand-colour gives a European village in a desert; `bld_desert`'s mud set is drawn from the kasbah references instead -- walls that batter inward as they rise, flat roofs behind a parapet, pointed merlons, a lattice pressed into the upper courses. The town is Ait Benhaddou: houses placed by walking down a crag in courses and drawing the highest first, so every roof line sits against the wall behind it. Four towers of one height at one spacing read as a fence, so nothing in the fortress is mirrored and its quarter stands a storey above the curtain.
- **The desert settlement goes in front of its cover, not behind it.** Its cover is dune ripples and dust patches drawn right across the mid band, which scribble over a mud wall rather than standing in front of it. The palm belt each desert settlement ends with is what stands in front instead -- and that belt stays broken and low, because a continuous green stripe across a desert reads as a lawn.
- **Settlements sit on the mid band, behind the cover**, on a low trodden `_patch`: anything taller than about ten pixels reads as a wall of earth behind the houses rather than as ground.
- **Mountains are triangles.** A noise ridge makes hills; `mountain_range` overlaps straight-sloped peaks and snows the ones above the snow line. Distant ranges are mixed toward `PEAKS[env]["haze"]`.
- **Forest is framed by the nearest tree:** two edge trunks and a hanging canopy, drawn last of all, after the road.

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
