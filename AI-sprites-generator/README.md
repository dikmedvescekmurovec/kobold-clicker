# AI-sprites generator

Rebuilds the 420-sprite hex tileset in `../AI-sprites/` (24 environments, 63 roads, 18 towns, 315 blend overlays, plus the spritesheet and JSON),
the 18-sprite 9-slice UI kit in `../AI-sprites/ui/` (2 panels, 16 buttons),
and the six per-environment slimes in `../Assets/Enemies/` (21 frames each, recoloured from the blue slime pack).
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
| `python qa.py showcase <tag>` | One map mixing all terrain, variants, roads and towns (illegal-border check included) |
| `python qa.py blends <tag>` | Blend overlays: spill, seam coverage and seam match vs `v1`, illegal borders, plus `qa/blend_pairs_<tag>.png` (before/after for each allowed pair), `qa/blend_map_<tag>.png` and 3× zooms `qa/blend_<hi>_<lo>_<tag>.png` |
| `python qa.py slimes <tag>` | Slimes: silhouette, palette and ramp checks, plus `qa/slimes_<tag>.png` (the baseline above all six, every frame) and `qa/slimes_ground_<tag>.png` |
| `python qa.py ui <tag>` | 9-slice UI: size, silhouette, outline and 8-periodicity checks, plus `qa/ui_sheet_<tag>.png` and a `qa/ui_mock_<tag>.png` showing every state and the panels stretched from 16 px to 428 px |
| `python build.py` | Exports every hex PNG through Aseprite into `../AI-sprites/`, writes the spritesheet and JSON, then verifies each file pixel by pixel |
| `python build_ui.py` | The same for the UI sprites, into `../AI-sprites/ui/` with its own `ui_sheet.json` |
| `python build_slimes.py` | Writes the six slimes into `../Assets/Enemies/<Env> Slime/` and reads every file back to check it. No Aseprite: the source is already a PNG pack and these ship as ordinary RGBA sprites, not as part of an indexed atlas |

`qa/` output is preview-only and git-ignored. `build.py` overwrites the files in `../AI-sprites/` (change `OUT` in `build.py` to write elsewhere).

## Files
| File | Contents |
|---|---|
| `hexlib.py` | Hex geometry, locked 32-color palette, dithering, lattice-periodic noise, `Tile` |
| `stamps.py` | Scatter placement, shaded domes, boulders, tufts, pebbles, lines, `seg_dist` |
| `terrain.py` | The six environments and their 4 variants (`objects=False` gives bare ground for towns), the `"base"` pseudo-variant, and the adjacency rules (`ADJACENT`, `can_border`, `ENV_CHAIN`) |
| `roads.py` | Road overlays for dirt, stone and snow, with every rotation |
| `town_parts.py` | Building and prop primitives (roofs, front walls, towers, walls, gatehouse, wells, stalls...) |
| `towns.py` | Small, medium and fortress layouts, plus per-environment materials and landmarks |
| `blends.py` | Blend overlays: priority, coverage mask, fringe details per environment |
| `preview.py`, `qa.py` | Preview images and checks |
| `slimes.py` | The per-environment slimes: the baseline's eight colours, and the five-step `hexlib.PALETTE` body ramp each environment swaps in |
| `ui.py` | 9-slice UI: `RectTile` (rectangular, not hex), rect primitives, the two panels and the 16 buttons |
| `build.py`, `build_ui.py`, `build_slimes.py`, `emit.lua` | Export through Aseprite in batch mode, JSON metadata, verification. `emit.lua` takes per-sprite `w`/`h`, so both builds share it |

## Rules that keep the set consistent
- **Geometry:** 56×64 pointy-top hex. Place tiles at 56 px columns and 48 px rows, with odd rows shifted 28 px.
- **Seamless edges:** anything within the outer band of a tile must come from environment-seeded, lattice-periodic data (`blend_fields`, `details(... shared ...)`), never from per-variant seeds. Towns copy their outer 2 px ring back from `v1`.
- **`"base"` pseudo-variant:** `ENVS[env]("base")` renders only the shared data, so it equals every variant's border band. Blends depend on this. Route any new per-variant data through `mix()` / `details()` so `"base"` skips it.
- **Roads:** centerlines run through edge midpoints on the center-to-center line, so they meet exactly. Rotation `_rK` means the canonical edges turned clockwise by K×60°.
- **Atlas layout:** groups are laid out in `build.GROUPS` order (environments, roads, towns, blends). Append new groups at the end so existing atlas coordinates don't move.
- **Palette:** all art uses the 32 entries in `hexlib.PALETTE` (index 0 transparent). Adding colors breaks the locked palette.
- **Look:** light from the top-left, 1 px ink outline on objects only, no outline on terrain edges. Buildings use roofs from above plus a thin south-facing front wall.
- **Aseprite quirk:** in Lua, `json.decode` returns floats, and `Image:drawPixel` silently writes palette index 1 for a float. `emit.lua` converts with `math.tointeger` and reads every pixel back.
- **Build hiccup:** if `build.py` prints `Cannot save file ... in the given location` and reports a `sheet mismatch`, the spritesheet PNG was briefly locked (typically by the open Godot editor reimporting the new PNGs), and the JSON no longer matches the old sheet. Rerun `build.py` until `problems` are all zero.

### 9-slice UI
- **Geometry:** 24x24 sprites made of nine 8x8 cells, so a `StyleBoxTexture` with an 8 px texture margin stretches them to any size down to 16x16. The four corner pixels are transparent, which rounds every panel and button the same way.
- **Periodicity:** Godot repeats the centre cell on both axes and the edge cells along theirs, so **all interior art must be a pure function of `(x % 8, y % 8)`**; borders and bevels must depend only on the distance to the sprite edge and stay in the outer cells. Tile the axes, never stretch them. `qa.py ui` fails if an interior pixel breaks this.
- **Which is why a panel face gets one mark at most.** Periodicity turns any interior texture into a stripe every 8 px, and the wood panel runs the full height of the window, so four marked rows per cell came out as corduroy that the labels on it had to be read through. The face is now a single `earth` plank seam on `soil`: the lit row, the butt-joints and the second dark row are gone, and the ink outline and dark inner rim do the rest of the wooden read. The white panel's face stays bare. Detail belongs in the outer 2 px, the only rows that do not repeat.
- **States:** normal (bevel out), hover (face one ramp step lighter), pressed (**the hover face with the bevel inverted**, so the dark rim merges with the ink outline and the button sinks - the label sinks 1 px with it), disabled (no bevel, one flat dull ring, face collapsed toward its own backdrop).
- **Surfaces:** `wood` buttons are light-faced for the brown panel, `light` buttons dark-faced for the white one. The `danger` flavour runs deep red to bright red (`brick_dk` -> `brick`); the palette's lighter steps skew orange, so `rust` appears only as a 1 px lit rim.
- **Own sheet:** the UI ships in `AI-sprites/ui/`, not the hex atlas, so hex atlas coordinates never move.

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
