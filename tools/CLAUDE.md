<!-- Loaded automatically when a file in this folder is read. Rules only: the measurements and the reasoning are in tools/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Sprites cut from bought packs (`tools/ui_kit.py`, `tools/loot_beam.py`)
The interface is **cut, not generated**, from packs under `Assets/Potential/`. `tools/ui_kit.py` is the one place that says which rectangle of which pack sheet is which sprite and where its nine-slice margins fall; plain Python, no Godot. **Read `DESIGN.md` here before adding or re-cutting a sprite** -- it holds the pack layouts, the measured grids and what was tried and turned down.

| What (table in `ui_kit.py`) | Source | Output | Preview in `tools/qa/` |
|---|---|---|---|
| Panels, buttons, close button (`PANELS`, `BUTTON_*`, `CLOSE`) | `2D Pixel UI/PNG/Main_tiles.png`, `Buttons.png` | `Assets/UI/ui_sheet.png` + `ui_sheet.json` (what `UITheme` reads) | `ui_kit_tiling.png` |
| Kill-pip parts: head, body, tail x three tiers + empty grey (`PIP_*`) | `Pixel UI pack 3/06.png` | 12 loose PNGs in `Assets/UI/` | `ui_kit_pips.png` |
| Gear icons (`GEAR`), doll and socket marks (`PARTS`) | RPG pack; ring and amulet off `Icons.png` | `Assets/Gear/` (32x32), `Assets/UI/` | `ui_kit_gear.png` |
| Orb icons (`ORBS`) | `OreAndGem/OreGemSpritesheet.png`, 10x5 on a 32 px pitch | `Assets/Orbs/` | `ui_kit_orbs.png` |
| Button marks (`ICONS` cut: chest, star; `ICONS_DRAWN` drawn as letter rows: flag, sack, scroll, the town tabs' sword, gem and anvil, and the bag's back arrow, bin, sell-all coins, Auto funnel, the comparison's swap and its two carets, the settings' cog) | `Icons.png` | `Assets/UI/ui_icon_*.png` | `ui_kit_icons.png` |
| Skill icons + Locked marks (`SKILLS`, `SKILL_LOCKS`) | `Ability Icons/` | `Assets/Skills/<skill id>.png` | `ui_kit_skills.png` |
| Character panel frame, bars, portrait, xp gem (`CHAR_*`, `XP_GEM`) | `2D Pixel UI/PNG/character_panel` | `Assets/UI/ui_char_*.png` | `ui_kit_character.png` |
| Loot beam (`tools/loot_beam.py`) | `Effects`, "Mini Falem", white colourway only | `Assets/Effects/loot_beam.png`, a 15-frame strip | |

The one generated piece of interface is the nameplate's health bar (`AI-sprites-generator/hpbar.py`, `build_hpbar.py`), because no pack draws one.

## Rules and gotchas
- **A nine-slice margin is only correct if what it leaves over is flat:** the centre and edge cells tile, so every tiled row and column must be one colour. `check()` re-reads each theme sprite and refuses to export one that is not. Icons and parts skip `check()`: they are drawn, never stretched.
- **Only theme sprites go in `ui_sheet.png` / `ui_sheet.json`.** Pips, gear, orbs, marks, skills, character parts, health-bar parts and the beam are loose files; `test_ui_theme` counts the sheet exactly.
- **Every button face is a palette swap of the pack's one green button** (brown, red, grey), mapped by hue and saturation with each step's lightness kept. The pack's own brown square button is not cut: its gradient face cannot tile.
- **The title bar is cut off its panel,** because the pack fixes it at 13 px and Pixellari needs 16; `UITheme.titled_panel` stacks bar over body.
- **Marks that stand on theme art are cut at scale 1 and recoloured through `BONE_RAMP`,** and every one is centred on one `ICON_SIDE` square so the corner buttons come out the same size whatever they wear. A mark no pack draws is written into `ICONS_DRAWN` in `ICON_KEY`'s five shades (outline plus a dark-to-light ramp) and goes through the same recolour, so a drawn one cannot be told from a cut one. Gear off `Icons.png` is doubled instead, to match the RPG pack's 28 px art.
- **`Icons.png` rows are not evenly spaced:** each entry's y and height are that icon's measured extent.
- **Orbs are centred on an even offset:** `OrbSlot` draws them at half size, and an odd offset loses a column.
- **The pip capsule sits on a rigid 4 px segment pitch** (an n-segment fill is columns `1 .. 4n+1`); the right end always comes off the empty capsule. That pitch is what lets `KillPips` assemble any length.
- **Only the white colourway of the loot beam is cut:** `modulate` multiplies, so white times a rarity colour is exactly that colour.
- **After cutting, run the Godot import** (`--headless --path . --editor --quit`) and commit the `.import` files.
