# AI-sprites generator

Rebuilds the 420-sprite hex tileset in `../AI-sprites/` (24 environments, 63 roads, 18 towns, 315 blend overlays, plus the spritesheet and JSON).
Everything is procedural and deterministic: the same code always produces the same pixels.
The Godot map does not draw the blend overlays yet (see `blend_rule` in the JSON meta).

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
| `python build.py` | Exports every PNG through Aseprite into `../AI-sprites/`, writes the spritesheet and JSON, then verifies each file pixel by pixel |

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
| `build.py`, `emit.lua` | Export through Aseprite in batch mode, JSON metadata, verification |

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
