# AI-sprites generator

Rebuilds the 105-sprite hex tileset in `../AI-sprites/` (24 environments, 63 roads, 18 towns, plus the spritesheet and JSON).
Everything is procedural and deterministic: the same code always produces the same pixels.

Godot skips this folder because of `.gdignore`.

## Requirements
- Python 3 with Pillow (`pip install pillow`)
- Aseprite. `build.py` expects the source build at
  `C:\Users\Dik\Documents\Git\aseprite\aseprite\build\bin\aseprite.exe`. Change `ASEPRITE` at the top of `build.py` if it moves.

## Commands (run from this folder)
| Command | What it does |
|---|---|
| `python qa.py phase1 <tag>` | Environments: border-match check between variants, plus `qa/p1_sheet_<tag>.png` and `qa/p1_map_<tag>.png` |
| `python qa.py phase2 <tag>` | Roads: edge-zone match check, plus sheet and random road-network map |
| `python qa.py phase3 <tag>` | Towns: containment and border match vs `v1`, plus sheet |
| `python qa.py showcase <tag>` | One map mixing all terrain, variants, roads and towns |
| `python build.py` | Exports every PNG through Aseprite into `../AI-sprites/`, writes the spritesheet and JSON, then verifies each file pixel by pixel |

`qa/` output is preview-only and git-ignored. `build.py` overwrites the files in `../AI-sprites/` (change `OUT` in `build.py` to write elsewhere).

## Files
| File | Contents |
|---|---|
| `hexlib.py` | Hex geometry, locked 32-color palette, dithering, lattice-periodic noise, `Tile` |
| `stamps.py` | Scatter placement, shaded domes, boulders, tufts, pebbles, lines |
| `terrain.py` | The six environments and their 4 variants (`objects=False` gives bare ground for towns) |
| `roads.py` | Road overlays for dirt, stone and snow, with every rotation |
| `town_parts.py` | Building and prop primitives (roofs, front walls, towers, walls, gatehouse, wells, stalls...) |
| `towns.py` | Small, medium and fortress layouts, plus per-environment materials and landmarks |
| `preview.py`, `qa.py` | Preview images and checks |
| `build.py`, `emit.lua` | Export through Aseprite in batch mode, JSON metadata, verification |

## Rules that keep the set consistent
- **Geometry:** 56×64 pointy-top hex. Place tiles at 56 px columns and 48 px rows, with odd rows shifted 28 px.
- **Seamless edges:** anything within the outer band of a tile must come from environment-seeded, lattice-periodic data (`blend_fields`, `details(... shared ...)`), never from per-variant seeds. Towns copy their outer 2 px ring back from `v1`.
- **Roads:** centerlines run through edge midpoints on the center-to-center line, so they meet exactly. Rotation `_rK` means the canonical edges turned clockwise by K×60°.
- **Palette:** all art uses the 32 entries in `hexlib.PALETTE` (index 0 transparent). Adding colors breaks the locked palette.
- **Look:** light from the top-left, 1 px ink outline on objects only, no outline on terrain edges. Buildings use roofs from above plus a thin south-facing front wall.
- **Aseprite quirk:** in Lua, `json.decode` returns floats, and `Image:drawPixel` silently writes palette index 1 for a float. `emit.lua` converts with `math.tointeger` and reads every pixel back.
