<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/UI/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## UI code (`Scenes/UI/`)
Everything is built in code, drawn in panel pixels and scaled by the main scene's `ui_scale`. **Read `DESIGN.md` here before changing how a widget looks or is laid out** -- it holds the why. The bag's and the character sheet's design reasoning is in `Scenes/DESIGN.md`.

| File | Contents |
|---|---|
| `ui_theme.gd` (`UITheme`) | Builds the shared `Theme` at runtime from `Assets/UI/ui_sheet.json` (each sprite an `AtlasTexture` in a tiled `StyleBoxTexture` with its own nine-slice margin). `theme()`; type variations `WoodPanel`, `TextPanel`, `HeaderBar`, `PanelLabel`, `WoodButton`, `WoodDangerButton`, `LightButton`, `LightDangerButton`, `BrownIconButton`, `CloseButton`; `icon_size(variation)`; `STATES`. Static builders: `button`, `icon_button`, `label`, `rule`, `vbox`, `titled_panel` (+ `body_of`, `title_of`), `clear(parent, keep)` |
| `palette.gd` (`Palette`) | The colours drawn in code. `INK`, `BONE`, `GOLD`, `EARTH_DK`, `SLATE` and the rarity ramp are `hexlib.py` hexes; `PANEL_CREAM`, `SLOT_TAN`, `SLOT_TAN_DK` are the UI pack's |
| `bag_page.gd` (`BagPage`) | The bag, the character sheet beside it and the orb tray at its foot, as one Control. Owns the selection, the doll (`DOLL_SOCKETS`, `DOLL_SCALE`), the comparison, orb crafting and the orb card, and saves after every change. `open()`, `refresh()`, `refresh_gold()`, `refresh_orbs()`, `layout()`, signal `closed`. `WIDTH`, `SLOT_GAP`, `GRID_COLS`, `ORB_COLS`, `ORB_GAP` |
| `skills_page.gd` (`SkillsPage`) | Free points over two `SkillTreeView`s, a Reset per tree (coin + price), and the `SkillCard` beside the page. `open()` redraws it; `layout()`, `closed` |
| `character_panel.gd` (`CharacterPanel`) | The player in the top-left corner: name, level, portrait, and health, mana and experience bars (only experience moves; bars empty by clipping to whole sprite pixels). `set_state`, `absorb(amount)` (returns levels gained), `xp_point()` where gems fly to. Ignores the mouse |
| `item_details.gd` (`ItemDetails`) | One item written into a `VBoxContainer` (`fill`), `line`, and `deltas(item, against)` as a plain Dictionary. Used by the bag and by `DropsView` |
| `item_slot.gd` (`ItemSlot`) | One item as a square: icon on a tan socket, ringed in its rarity colour above common. `make`, `empty`, `SIDE`. Takes **no mouse input** |
| `orb_slot.gd` (`OrbSlot`) | One orb in the tray: `SIDE` 24, `ICON` 16. Three states (never found, held but unusable = `DIM`, usable). Takes the mouse: `pressed`, `hovered`, `unhovered` |
| `orb_card.gd` / `skill_card.gd` (`OrbCard`, `SkillCard`) | The floating card for the orb or skill under the cursor: name, what it does, a status line (`OrbTable.why_not` / `SkillTree.why_not` in rust) |
| `skill_slot.gd` (`SkillSlot`) | One skill icon at 2x with `rank/max` on its corner; locked, open, learning, maxed (gold ring). Passes every press on; `Skills` decides |
| `skill_tree_view.gd` (`SkillTreeView`) | One tree placed by hand on `SkillTree`'s grid, lines drawn in `_draw` under the icons. `GAP_Y` is set by the page having to fit a 648 px window |
| `coins.gd` (`Coins`) | `icon()` (still), `frames()` (the spin, only for coins in the air), `count_for(amount)` = 1 + floor(log10) |
| `kill_pips.gd` (`KillPips`) | The fight's progress bar, a pip per enemy in its tier colour, assembled from head / body / tail parts at any length (`_init(slots)`, `width_for(slots)`, `PIXEL`) |
| `health_bar.gd` (`HealthBar`) | The enemy's health: a tier frame (plain, gem, crown) assembled from three generated parts, a drawn `FILL` and a `GHOST` that holds then drains. `TROUGH` is the same width in every tier |
| `loot_beam.gd` (`LootBeam`) | The flame over a find in the arena, tinted to the rarity's ring colour |
| `juice.gd` (`Juice`) | Static effects: `burst`, `hit_stop` (latest call wins), `shake` (whole pixels) |
| `shine.gdshader` | The diagonal glint `ItemSlot` puts on rare and better, in whole source pixels |

## Rules and gotchas
- **Set `theme_type_variation` on a plain `Button`** and Godot drives hover, press and disable. `Wood*` buttons stand on `WoodPanel`, `Light*` on `TextPanel`.
- **A Control with no themed ancestor must carry `UITheme.theme()` itself,** or its type variation means nothing: anything added straight to a `CanvasLayer` (icon buttons, cards, pages).
- **A floating card cannot be a Godot tooltip:** a tooltip is its own window and cannot inherit `ui_scale`. Cards are ordinary Controls, scaled by `ui_scale`, placed by hand, and placed **twice** (now and deferred) because labels have not laid out on the first pass.
- **Tree order is draw order on a `CanvasLayer`:** `OrbCard` is added after the character sheet because it overhangs it.
- **Free children with `UITheme.clear`, not bare `queue_free`:** a queued child still counts in hit-tests and minimum sizes until the frame ends.
- **A bag square ignores the mouse** so a drag that starts on one still scrolls; which square was clicked is worked out from the cursor. An `OrbSlot` is the opposite on purpose.
- **Widths are arithmetic, not taste:** eight `OrbSlot.SIDE` plus seven `ORB_GAP` is exactly `BagPage.WIDTH` (`test_ui_theme` holds it); `DOLL_SCALE` 3 is the smallest whole number that keeps 40 px sockets apart; `test_inventory` checks no socket overlaps or runs off the page.
- **Whole-number scales only** (`PIXEL`, `DOLL_SCALE`, 2:1 orb icons on an even offset), so a sprite pixel stays square.
- **Bars of any length are assembled from parts with no separation,** each blown up through its minimum size, not the node's `scale`. `KillPips._init` and `HealthBar._init` assert the sprites still measure what the consts say.
- **`Coins.count_for` counts in whole tens, never `log()`:** `log(1000)/log(10)` floors to 2.
- **The coin sheet's geometry is measured:** `FRAMES` is 9 though the sheet is wider.
- **`Palette.GOLD` is the unique rarity step;** do not spend it on currency text. Amber on cream is too weak; use `SLATE` there.
- **The darker half of the rarity ramp is for cream panels, the ring half for backdrops:** a stat block needs `TextPanel`, never wood.
- **`CloseButton` has no minimum size of its own:** give it `UITheme.icon_size("CloseButton")`.
