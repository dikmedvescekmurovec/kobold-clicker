<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/UI/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## UI code (`Scenes/UI/`)
Everything is built in code, drawn in panel pixels and scaled by the main scene's `ui_scale`. **Read `DESIGN.md` here before changing how a widget looks or is laid out** -- it holds the why. The bag's and the character sheet's design reasoning is in `Scenes/DESIGN.md`.

Where a rule's full text is: `(DESIGN.md)` means under a heading that is the rule's own title, `(DESIGN.md: "x")` under the heading `x` -- a file's name is its full description (functions, constants, signals, its page's rulings), in the last section, *Reference*. A pointer on a group's heading covers the rules under it that have none, and an indented rule shares the pointer of the rule it hangs from.

## Rules

### Layout: whole scales, the room, the sheet held upright
- **Use whole-number scales only** (`PIXEL`, `Doll.SCALE`, 2:1 orb icons on an even offset), so a sprite pixel stays square. (DESIGN.md)
  - **Pick `ui_scale` with `UITheme.pick_scale`:** the largest whole one leaving 324 x 576 panel pixels (`MIN_SHORT`, `MIN_LONG`). A window under `MIN_LONG` across, held upright, is `UITheme.narrow`. (DESIGN.md: "ui_theme.gd")
- **Stand every page in the room the main scene hands it** (`area`, set in `_layout_ui`), through `UITheme.dock`, never against the window itself. A new page gets an `area` and a `layout()` that docks and applies `UITheme.EDGE`. (DESIGN.md)
  - **Held upright, dock a page as a sheet along the foot of its room:** centred at its own width, as tall as what it holds (`natural_height`), never more than half the window. (DESIGN.md: "ui_theme.gd")
  - **Let `dock` run the page's `layout` once more the next frame** (`again`, `_settle`): a flow measures its height only as it lays out. (DESIGN.md: "ui_theme.gd")
- **Budget 324 panel pixels across held upright, not 576:** what stands side by side across a monitor stacks, wraps or narrows there. Check a new panel at `--resolution 324x576` as well as at the default. (DESIGN.md)
  - **Give a new page, or a new state of one, a line in `_pages` of `tests/test_ui_pages.gd`** (every page, headless, in four windows; `KOBOLD_LAYOUT_DUMP` writes the layouts as JSON).
- **Put a panel's long part in `UITheme.scroll()`,** with what must stay in reach pinned above or below it: a page that outgrows a 648 px window scrolls rather than running off the foot. (DESIGN.md)
  - **Show a scroll bar only on the skill tree's scrolls** (`SCROLL_BAR`, `SCROLL_MODE_AUTO`); `UITheme.scroll` is barless and down-only. (DESIGN.md: "ui_theme.gd")
- **Work widths out by arithmetic, not taste:** six `OrbSlot.SIDE` and five `ORB_GAP` fit `BagPage.WIDTH` (`test_ui_theme`), and `Doll.SOCKETS` keep 40 px sockets apart (`test_inventory`). (DESIGN.md)
  - **Treat `TownPage.BODY_WIDTH`, `ROW_GAP` and `TranscendPage`'s `CURSE_*_WIDTH` as budgets,** not taste. (DESIGN.md: "town_page.gd", "transcend_page.gd")
  - **Keep the left pages at `BagPage.WIDTH`:** the skill tree never narrower than the bag, and a zoomed tree scrolling in its box, never widening the page. (DESIGN.md: "skills_page.gd")
- **Fit three panels in a town's 576 panel pixels:** the bag's grid and the town page's width never move, and the doll stands between them. (DESIGN.md)
  - **Keep `TownPage` as tight down the page as across:** all under the counter's name in `_scrolled`, the tabs and name pinned above, an offer's Buy below. Measure anything added both ways (`Scenes/Town/DESIGN.md`).
  - **Held upright, take `BagPage.least_height()` from the counter** (`LEAST_ROWS` of the grid, and the doll). (DESIGN.md: "bag_page.gd")
- **Assemble bars from parts with no separation,** each blown up through its minimum size, not the node's `scale`; `HealthBar._init` and `KillPips._init` assert the sprites still measure what the consts say. (DESIGN.md)
  - **Show at most `KillPips.SHOWN` (10) pips,** so `width_for(slots)` is `mini(slots, SHOWN) * WIDTH`; `HealthBar.TROUGH` is the same width in every tier. (DESIGN.md: "kill_pips.gd")

### Fonts and words
- **Use two fonts, each at its native size:** Pixellari 16 for a name, a heading or a button face (`PanelLabel`); Ark Pixel 10 for any line of a block (`SmallLabel`, `UITheme.label(.., .., true)`, `ItemDetails.line(.., true)`). (DESIGN.md; the why: "Why there are two fonts")
- **Write no descriptive text on a page** (the user's rule, 2026-09-30): no sentence saying what a field is for, how a rule works or what a number means. Controls, values, headings, an empty state and a refusal only; anything more is a tooltip, and only when asked. (DESIGN.md)
  - **Say why a button is dead in its tooltip, never as a line on the page** -- Buy, Restock, Upgrade and Lock alike. (DESIGN.md: "town_page.gd")
  - **Give a counter no Buy heading and no helper sentences;** an empty state is the only line it writes. (DESIGN.md: "town_page.gd")
  - **Say on a black-screen card only where it stands** ("Done", "3 to spend"), never what the card is for. (DESIGN.md: "transcend_page.gd")
- **Write a curse's sentences to be understood, not to fit** (`Curses`): they wrap and the table scrolls, so a new curse never means cutting an old one's words. (DESIGN.md: "transcend_page.gd")
- **Give a level's heading marks, not words,** on one line: Auto a bare chest struck through (`AUTO_ICON`, green `AUTO_ON_ICON` while on), Clear a bare bin, in a town that buys gear coins (`SELL_ICON`). Tests find either by its tooltip. (DESIGN.md)
- **Make Back the arrow, `UITheme.back_button(tooltip)`, never the word;** only the verdict of a won tile or an ended run leaves by a word, Collect. (DESIGN.md)
- **Call the tree "Skill tree" everywhere** (`SkillsPage.TITLE`), and what goes in it a node. (DESIGN.md: "skills_page.gd")

### Palette
- **Draw in ENDESGA 64 only** (`Palette.E64`): `test_ui_theme` holds `Palette`, the theme sheet's pixels and every colour in this folder's other scripts to it; one that is not stands on its `OFF_PALETTE` with its reason. (DESIGN.md: "palette.gd")
- **Hold a word on the cream to its contrast:** `TEXT`, `TEXT_SOFT`, `SLOT_TAN_DK`, `LEAF`, `ICE_DK`, `RUST`, `BRICK` (4.5:1), a rarity's 16 px name (`ItemRarity.TEXT_COLORS`, `GOLD_TEXT`; 3:1). (DESIGN.md: "palette.gd")
  - **Never write a line on the cream in the bright ones** (`GOLD`, `FRAME_GOLD`, `FRAME_GOLD_DK`, `LEAF_LT`, `BRICK_LT`, `ICE`, `STONE_LT`): they are for fills, frames and words outlined on the backdrop.
  - **Leave `PANEL_CREAM` (f6ca9f, the user's pick), `SLOT_TAN`, `SLOT_TAN_DK` and `BUTTON_BROWN` as `tools/ui_kit.py` `UI_FIXED` picked them,** so a slot drawn in code matches the art.
- **Keep `Palette.GOLD` for the unique rarity step,** never currency text (`TEXT_SOFT` there). A unique's name is gold at 16 px, its effect sentence ink between gold lines: gold at 10 px on cream cannot be read. (DESIGN.md)
- **Write stat blocks on `TextPanel`, never wood:** the darker half of the rarity ramp is for cream panels, the ring half for backdrops. (DESIGN.md)

### The theme's parts
- **Set `theme_type_variation` on a plain `Button`** and Godot drives hover, press and disable; `Wood*` buttons stand on `WoodPanel`, `Light*` on `TextPanel`. (DESIGN.md)
  - **Make the one press a counter is there for green** (`UITheme.GO_BUTTON`: Buy, Accept, Claim, Upgrade); Restock, Lock and the way out stay brown. (DESIGN.md: "town_page.gd")
  - **Give `BareIconButton` (`UITheme.BARE_BUTTON`) the `_brown` cut of a mark, never the cream one.** (DESIGN.md: "ui_theme.gd")
- **Build a button gold moves through with `UITheme.priced_button`:** its word is the button's own `text` (tests find it by `begins_with`), its figure and coin a child named `PRICE_NAME`, read with `price_of`. Never `"%s %s" % [word, price]` with `icon = Coins.icon()` again. (DESIGN.md)
  - **Make every priced square one cell, `TownPage._cost_cell`** (`_price_cell` is it with the coin): the figure `TEXT_SOFT`, or `BRICK` while the purse or the orbs held cannot cover it. (DESIGN.md: "town_page.gd")
- **Draw a table with `UITheme.table_row`s in a `vbox(0)`, and with nothing else.** Pass `width` when it stands in something that sizes itself round its contents (a card); `can_stack` false never drops a value under its name. (DESIGN.md)
- **Make a section heading that says what is under it an `Accordion`,** so it can be folded; an id is `"<page>:<heading>"`. (DESIGN.md)
  - **Make a sub-heading inside a counter `UITheme.section`,** as the tile panel's Services and Modifiers are. (DESIGN.md: "town_page.gd")
  - **Keep what is folded or filtered for the session, never in a save:** an `Accordion`'s shut sections (a static, by `id`), the bag's filter tab (`_filter`), its folded trays (`_trays_hidden`). (DESIGN.md: "accordion.gd", "bag_page.gd")
- **Free children with `UITheme.clear`, not bare `queue_free`:** a queued child still counts in hit-tests and minimum sizes until the frame ends (`test_ui_theme` reads the scripts for it). One node swapped for another is `remove_child` then `queue_free`. (DESIGN.md)
- **Stand tabs (`TownPage.tab_faces`) on `tab_line`, never on a separate `rule`,** which would run under the open tab too; the bag's filter and the leaderboards wear the same faces. (DESIGN.md: "town_page.gd")
- **Keep `UITheme.notch_places(size, bar)` the same arithmetic as the kit's preview** (`tools/ui_kit.py`). (DESIGN.md: "ui_theme.gd")

### Popups and questions
- **Make every popup behave like the rewards' panel** (the user's rule, 2026-09-25): a `titled_panel` with no X (an empty `on_close`), left by a button at its foot and by Escape, brought up by `Juice.popup` and taken away by `Juice.pop_out`. (DESIGN.md)
  - **Let go of the holder at once:** `_confirm`, `_told`, `_tip_panel` go null before the shrink ends, so the next question or deed never finds the old one.
  - **Never size a popup's holder:** `Juice.popup` stands it over the whole window, and again however the window is resized. (DESIGN.md: "Popups over the whole window, after the review of 2026-10-10")
  - **Ask `Juice.leaving(panel)` before a button answers:** the buttons can be pressed for the `LEAVE_TIME` the panel shrinks, and a second press is no second answer.
  - **Close a page's popup as the page hides** (`BagPage`'s and `TownPage`'s `visibility_changed`), or `asking()` / `telling()` hold every hotkey and banner behind a question nobody can see.
  - **Pass `win` (the wash and sparks) only for something gained,** never on a question or a tip; name the panel (`CONFIRM_PANEL`, `TOLD_PANEL`), the wash being added before it in its holder.
- **Bring a page to the front with its popup** (`move_to_front()` in `BagPage._ask` and `TownPage._open_told`), or held upright the question stands under whichever page came later in the layer. (DESIGN.md)
- **Ask before Sell all and the bin, through `BagPage._ask`:** Cancel beside the verb, and "Don't show this again" beside a toggled `BrownIconButton` named `TICK_NAME`, never a Godot `CheckBox`. A ticked Yes writes `SKIP_CONFIRM + id` into `inventory.tips` (`_remember`). (DESIGN.md: "Give a level's heading marks, not words")
  - **Ask the same before a rarity orb lowers a piece** (`_craft`, id `lower_rarity`), and spend nothing until Use: `_apply_orb` is the deed, and the shelf redraws from its `written`, not after `craft_held` returns.
  - **Ask a second time about a level's uniques** (`_drop_level`, under `Settings.uniques` Ask): the tick keeps the answer in `Settings.uniques` (Sell or Keep), never in `tips`. A lone piece's own Sell or Discard asks nothing.
- **Ask every time before an heirloom's Discard** (`_ask(..., can_skip false)`), and hold a banner behind any question (`BagPage.asking()`). (DESIGN.md: "bag_page.gd")
- **Build the fortuneteller's answer as `BagPage._ask` is built** (`TownPage._tell`, `_place_told`): a ticked Dismiss writes `SKIP_TOLD + reading` into `inventory.tips`, Escape reads no tick, and the appraisal alone offers none. (DESIGN.md: "town_page.gd")
- **Let no key past `CloudQuestion`** (no X, no Escape; every key taken in `_input`) **or `TextPrompt`** (it eats every key its field leaves), so no hotkey opens a page under them. (DESIGN.md: "cloud_question.gd", "text_prompt.gd")
- **Give `DialogueBox` no button:** every click anywhere is its own (every child `MOUSE_FILTER_IGNORE`), it leaves by its own `leave()`, not `Juice.pop_out`, and only a `TIPS` entry with a fourth element raises it. (DESIGN.md: "dialogue_box.gd")
  - **Put the hero's portrait on the left, everyone else's on the right** (`PLAYER`; the user's rule), every frame `PORTRAIT_HEIGHT` tall, stacked top to bottom.
  - **Have the speaker babble as a page comes in** (`VOICE`): a syllable every `LETTERS_PER_SYLLABLE` letters, each cutting off the last (the user's ask).

### Cards and tooltips
- **Keep every card cream (`TextPanel`), a plain tooltip too:** set `tooltip_text` as ever and `TipCard` writes it (tests find buttons by that text). Never turn Godot's own tooltip back on (`gui/timers/tooltip_delay_sec` in `project.godot`), never write a card in the wood half of the palette. (DESIGN.md)
  - **Make only a tooltip wait** (`TipCard.DELAY`); the item, orb and skill cards are up at once.
  - **Keep a tooltip beside its control while it is up** (`TipCard._place` every frame), so one over a popup still settling follows it. (DESIGN.md)
- **Serve every square with the one `ItemCard`** (the main scene's, on layer 3, over the pages and a fight), which finds squares through `ItemSlot.GROUP` (`slot_at`). (DESIGN.md: "item_card.gd")
  - **Steer a square's card through its metas:** `ItemCard.BESIDE`, `KEYS`, `NO_COMPARE`, `ALT_CARD`, `STAYS`, `PINNED`; `TipCard` reads `NOW` and `KEY`.
  - **Write the second (Alt) card only in `ItemCard.write_second(slot)`:** what the swap takes off (`worn_for`), or `BARE` when nothing would come off, so Alt never looks like a dead key.
  - **Put the card away at a press, but never at a craft:** with an orb held it stays (`hovered`, `Cursors.holding`, `_orb_press`) and is lit (`BagPage.crafted` -> `shine`). It is the pressed place that goes quiet, not the piece: a redraw makes new squares, a shelf new `Item`s.

### Squares, presses and cursors
- **Leave a bag square deaf to the mouse,** so the grid's and the doll's handlers see every press and work out the square from the cursor (`_index_at`, `Doll.socket_at`); an `OrbSlot` is the opposite on purpose. (DESIGN.md)
  - **Let a filled `ItemSlot` join `GROUP`,** which is how `ItemCard` finds it; a `teaser` stays out, so the card writes nothing beside it. (DESIGN.md: "item_slot.gd")
  - **Lay the rarity frame over the icon** (`FRAME_NAME`), so the icon stays child 0. (DESIGN.md: "item_slot.gd")
- **Stand a selected piece's buttons in `BagPage._actions`, beside its square** (stacked, no Back); tests find them with `_deep_button(page._actions, ..)`. Escape clears the selection first and closes the bag only on a second press. (DESIGN.md)
  - **Let a click select a square and nothing more:** no stat block, the hover card saying what the piece is past the buttons (`ItemCard.BESIDE`, `_place_actions`). (DESIGN.md: "bag_page.gd")
  - **Press the open square's own buttons for Shift-click and Ctrl-click** (`_press_action`), so every refusal is the grey button's; a square names its keys in `ItemCard.KEYS` (`_bag_keys`). (DESIGN.md: "bag_page.gd")
- **Ask for the hand wherever a press does something:** a button gets it for nothing (`Cursors.install`, run before the main scene's first button), anything else through `Cursors.wear`, or `Cursors.over_squares` from the `gui_input` of a Control answering for squares that take no mouse. (DESIGN.md)
  - **Set `Input.set_default_cursor_shape` where no Control lies under the mouse** (`HexMap._point`, `CombatScene`).

### Drag and drop
- **Keep drag and drop a mouse's alone** (the user's ask, 2026-10-09): a travelling press lifts a bag or worn piece (`BagPage._lifts`, `_lift`: `force_drag`), while a finger's drag, and a mouse's from bare panel, still scroll. (DESIGN.md)
  - **Drag the item itself, never an index:** loot arriving mid-drag moves every index.
  - **Call the button's own handler at a drop** (`_on_equip_pressed`, `_on_unequip_pressed`, `_place`, through `set_drag_forwarding`), so every refusal is the button's.
  - **Open nothing at a lift** (the user's), and dim what cannot take the piece (`Inventory.can_equip`, `SkillTree.can_place`) while `_lifted` is set; `NOTIFICATION_DRAG_END` clears it.
  - **Find the drop square (`DROP_MARK`) every frame from the mouse** (`_drop_square` in `_process`), not from Godot's drop callbacks, which never say the cursor has left.
  - **Count the doll's click as it lets go,** as the grid's and the tree's do, or the redraw its press caused cuts the drag off.

### Touch
- **Give a finger a tap for everything hover, Alt and a right click do** (`Cursors.touched`): what hover shows a tap shows, a tooltip is a held finger, and what only Escape or a right click undoes needs a tap too. (DESIGN.md)
  - **Let a tap select and the next tap on the same thing apply** (the user's rule, 2026-10-10): every press that spends, a new one too, asks `Cursors.applies(what)` first, and leaves the thing's card or panel to come up.
  - **Treat an orb or a rune in the bag's trays as the tool, not the thing:** a tap picks it up and says nothing, a held finger reads it (`OrbSlot.picks_up`). A vendor's orb is the thing: read on the first tap, pressed on the next.
  - **In a test, set `Cursors.touched` yourself** and add one to `Cursors.taps` between two taps: a test's events are a mouse's.
- **Let a finger held on a skill node go on spending** once its second tap has learned (`SkillTreeView.repeating`). (DESIGN.md: "skills_page.gd")
- **Show the item card at a tap and keep it until the next tap lands elsewhere;** the worn card is always the second, and no key row is written. (DESIGN.md: "item_card.gd")
- **Bring a tooltip up under a finger held `TipCard.DELAY`:** a button held to be read is disabled and enabled again, which drops its press. (DESIGN.md: "tip_card.gd")
- **Let the X answer in `UITheme.TOUCH_TARGET` round it on a touchscreen** (`_widen_for_fingers`); a finger may wobble `Cursors.TOUCH_SLOP` and still tap. (DESIGN.md: "ui_theme.gd", "cursors.gd")

### The bag, the doll and the orbs (DESIGN.md: "bag_page.gd")
- **Save through `_save()` after every change;** it does nothing without a path, so a transcension's bag (`transcending`, the fifth argument) writes no file.
- **Keep `_purse` the player's** (gold, orbs, tips, super orbs, the one thing ever saved) on the heirlooms' page too: `BagPage` with a fourth argument `true`, over `inventory.stash()`, with no Auto, bin, Sell or count.
- **Make no heirloom in the ordinary bag:** Make heirloom (`_make_button`, asks first) stands only on a transcension's, where a selected piece gets no buttons.
- **Use a super orb as an ordinary orb is used:** picked up (`_armed`), then pressed on an heirloom (the user's, 2026-10-03; `_super_press`).
- **Put the upgrade arrow only on a piece Equip would take** (`is_upgrade`, `Inventory.can_equip`), never over a greyed Equip.
- **Show only the doll in the sheet:** what a selected piece would replace is the hover card's under Alt, and Equip's tooltip names what it takes off (`Equipment.displaced_by`).
- **Let a level's bin and Sell all take only what the open filter tab shows** (`Inventory.discard_level(.., slot)`); never hide a level holding nothing at all, and keep a hidden piece selected. (DESIGN.md: "The bag's filter tabs (2026-10-07)")
- **Pass a locked piece by in Sell all and the bin** (`Item.locked`, in the save; `Inventory.discard_level`): its own Sell is greyed too, its own Discard still takes it. Its toggle reads "Never sell", never Lock, the smith's word. (DESIGN.md: "Give a level's heading marks, not words")
- **Use an orb one way: pick it up, then press it on a piece** (the user's rule, 2026-10-01; `_armed`, `_craft`): with a piece open the tray's press shuts it first, and the orb is never spent on it. (DESIGN.md)
  - **Only ever assign `_armed`, never work round it:** its setter makes the orb the cursor (`Cursors.hold`) and emits `held_changed`.
  - **Put a held orb down for Escape and a right click in `_input`,** since a panel would eat them before `_unhandled_input`.
  - **Craft a vendor's shelf piece through the bag's `craft_held(item, written)`:** `written` (`VendorStock.put`) runs between the change and the save, so the shelf and the orb go down in one write.
  - **Never sell an orb:** the tray crafts at every counter, and at an orb vendor too a press picks the orb up (`test_town`).
- **Keep the runes a row over the orbs** (`_rune_tray`; the user's, 2026-10-09), on the ordinary bag alone, pressed on a tile (`rune_on`); `_input` keeps one held through a press off the bag (`_off_the_bag`).
- **Stand the doll at every counter** (the user's, 2026-10-07; `shop(services)`).
- **Sell what the open tab buys, not what the town has:** one counter is live at a time, and `BagPage._buys` is the one place that asks. (DESIGN.md)
  - **Sell nothing at the board's tab:** `_buys` is false for every service but `GEAR` and `ORBS`, so Discard stays Discard and the tray still crafts. (DESIGN.md)
  - **Sell a level's mark at the board too where the town has a gear merchant:** the main scene adds it to whichever tab is open, so the mark never throws away beside a buyer.
- **Hand between the two pages only the piece that is open** (`TownPage.offer_changed` -> `BagPage.offer`, `BagPage.selection_changed` -> `TownPage.bag_changed`, wired in the main scene): never a second path for a bought piece. (DESIGN.md)
  - **Draw nothing of a shelf piece in the bag:** `offer(item)` is only the counter's redraw of it.

### Towns and bounties (DESIGN.md: "town_page.gd", "bounty_list.gd")
- **Save every purchase and every blow** (`TownPage`); `view` and the bag's `craft_held` are set on it from outside, and only the board and the fortuneteller read `view`. Every deed ends in `_deed_done` (save, redraw, `offer_changed(null)`).
- **Give every service a tab:** `COUNTERS` is `TownServices.ORDER`, and one `_fill` has no counter for says so (`push_error`) and draws nothing.
- **Call `BountyBoard.clear` before `restock` in the Claim that clears a board,** and keep the claim's order in `take_choice(index)`: `item_claimed` -> `note_unique` -> `add`, orbs to the tray, then save.
- **Open a town on its board,** the one tab every settlement has; it has no Show.
- **Write a bounty out in one place, `BountyList.row`,** which the board and the journal both call; terrain swatches are `HexTileset.env_icon`, never a second set of art. (DESIGN.md)
  - **Always show where a bounty lives** (the user's, 2026-10-07; no Info button): its level as a `UITheme.chip`, its environments as swatches, never which tile.
  - **Name an orb it pays in its tooltip, never as words;** `xN` never for one body.
- **Show no square, no smith and no counter name at the smith with a piece open** (the user's, 2026-10-07): the piece's whole `ItemDetails` block, then Upgrade over Lock pinned at the foot.
- **Give a fortuneteller's spell no name, over it or in its tooltip, and never say how often it was asked;** grey the mark alone when she refuses. A great spell emits `spell_aimed` and charges nothing.
- **Make the way out a square among the great spells, never a button of its own, and never grey it** (`TRANSCEND`, once a wall has fallen; `_ask_way_out`: a short purse greys only its Transcend).
- **Open the banishing as a screen in her list's place** (`_fill_banish`; the user's, 2026-10-10), its square never greyed; the deed saves and redraws in place, and a press on its grid counts as it lets go, not one that travelled.
  - **Give its back arrow and Restore no tooltip, and Banish none but her floor's** (the user's, 2026-10-10 -- the one button whose other refusals say nothing).

### The skill tree (DESIGN.md: "skill_tree_view.gd", "skills_page.gd")
- **Build the squares only when the root's slots or the stones change** (`SkillTreeView.fill`, `_shape`): rebuilding hundreds a point froze a grown tree.
- **Fade, never darken** (`FAINT`, `UNLEARNED`): a dimmed disc lost its base's colour. (DESIGN.md: "The skill tree's look (2026-10-09)")
- **Mark what something can go into (`_rings`) with a light on the skills page** (`_light`, `node_glow.gdshader`; the user's, 2026-10-10) **and a gold ring on the black screen** (`RING`); the light shows at every animation level.
  - **Breathe the root's light until the player's first point ever is spent** (`teaching`, `Inventory.FIRST_POINT`), still at `Anim.NONE`.
  - **Flash a node's card as a point goes in** (`SkillsPage.learned` -> `ItemCard.flash`: the node's colour at `POINT_POWER`, no rays; the user's, 2026-10-10), a second light swelling on from where the last had got to.
- **Stop each line at its slots' edges** (`_reach`), so none shows through a faded slot; into a stone holding a point it is ink.
- **Stand the corner words in `_marks`,** over the canvas, never scaled or faded with it.
- **Count a press as it lets go** (`slot_pressed`): past `BagPage.DRAG_THRESHOLD` it drags the scroll, and held still it repeats on the skills page only (`repeating`), saved once as it lets go (`hold_ended`).
- **Scale the tree in whole steps** (`fit`; `zoom_by` up to `ZOOM_MOST`, the user's, 2026-10-09), and keep `zoom` across redraws.
- **Keep the nodes small** (the user's, 2026-10-09): a stone is `ItemSlot.bare` with `SkillTree.node_icon`, kept apart by `_room`; the root has one branch, straight down.

### The other pages
- **Read every number on `CharacterPage` off the fight** (`_numbers`: `Encounter.armed(owner, totals)`, never `wear`, which wants a lineup), as the character panel's are. (DESIGN.md: "character_page.gd")
  - **Write a curse out there, never in a tooltip,** folding it once the page has been looked at and put away (`Accordion.fold`).
  - **Name a stat's row for its stat,** say where it comes from in its tooltip (`_sources`), and show one in `ALWAYS` at zero, so a fresh hero's page is never an empty frame.
  - **Mark a number that moved since the page was last put away** (`_change`, `_seen`), never the time played.
- **Change and save nothing from `CharacterPage`, `CollectionPage` or `AchievementsPage`;** the pencil only emits `rename_pressed`. (DESIGN.md: "character_page.gd", "collection_page.gd", "achievements_page.gd")
- **Write nothing from `TranscendPage`:** `finished` is the main scene's cue for the one write, `lost` stays public for `Inventory.transcended(lost)`, and what is taken lives in `Inventory.pending_curses`, cleared as the screen comes up. (DESIGN.md: "transcend_page.gd")
  - **Make one heirloom a transcension** (`_made`), and ask a second time at Enter the new world only where it would leave the heirloom unmade.
  - **Name a curse's tick box for its id,** and fade a row the skulls cannot pay for (`Curses.fits`, `_budget`) or that cannot stand with a ticked one (`Curses.allowed`).
- **Give `CharacterPanel` no name** (2026-10-03) **and no mouse:** its press is the main scene's `_character_button`, and its widest figures keep clear of the fight's centred column (`test_ui_theme`). (DESIGN.md: "character_panel.gd")
  - **Mirror it by a negative `scale.x`,** its words put back through `_reads`: the kobold is never flipped, and the badge widens to its number, never the frame.
- **Leave what unlocks a unique to the achievements page, never the log,** whose card says "Not found yet", never "everywhere" or who carries it (the user's call, 2026-09-28). (DESIGN.md: "collection_page.gd")
  - **Write a locked unique's card as its name, its `UniqueTable.hint` and "Locked"** (`CollectionPage.write_hint`), never its stats or rule (the user's, 2026-10-07).
  - **Under Alt, show a log square's achievement and an achievement's unique** (`ItemCard.ALT_CARD`; the user's, 2026-10-02).
  - **Draw a missing unique as `ItemSlot.shadow`, never with a ring;** once unlocked, darkened and greyed (`SHADOW`, `GREY`), never darker again (the user's "way too dark").
  - **List the log by name, Starters then Trophies** (the user's, 2026-10-02).
  - **Glint only a square new to its page** (`ItemSlot.shine_until_hovered`; `achievements_new`, `uniques_new`), until hovered or the page is closed.
- **Use the item card for an achievement** (`write_card`; the user's pick, 2026-10-07), with no line naming the unique and no verb; the page is one grid by name, no headings (the user's reference, 2026-09-28), a progress bar on every square. (DESIGN.md: "achievements_page.gd")
- **Put every dev tool on the Developer screen and nowhere else** (`SettingsPage._open_dev`, a debug build only); Fullscreen stands only where `Settings.has_window`, Controls not on a phone. (DESIGN.md: "settings_page.gd")
  - **Write `Settings` and its file at every change;** `layout()` emits `laid_out`, the generator being wider than the settings.
  - **Keep `CREDITS` in step with `credits.md`:** `test_ui_theme` holds every name it thanks in bold to a line of it.
- **Draw on `LeaderboardPage` only what the `Cloud` holds,** and keep its name field through every redraw (`_naming`), or the next letters would be the corner's hotkeys. (DESIGN.md: "leaderboard_page.gd")
- **Take up a fresh piece after `ItemGenerator.add_to_bag()`,** so the bag's is never crafted on from the generator. (DESIGN.md: "item_generator.gd")
- **Write a modifier as one row, its whole sentence** (`ItemDetails.fill`), and one the rarity still has room for as a row holding only `OPEN_ROW`, never on a broken piece. (DESIGN.md: "item_details.gd", "The open modifier row (2026-10-07)")
  - **Write "Broken" and "· Two-handed" in `ItemDetails`,** which the hover card, `DropsView` and a vendor's shelf all fill from.
  - **Pass `deltas(item, against)` an `Array[Item]`,** everything a swap takes off, and find the rarity line by name (`RARITY_LINE`), not by place.
  - **Set a unique's rule between two gold lines** (`_gold_rule`), in `TEXT` ink. (DESIGN.md: "A unique's rule between gold lines (2026-10-07)")

### Effects and animation levels
- **Honour the animation level:** `Juice`'s panel effects run at `LOW`, all but the wash and sparks, and none at `NONE` -- nor a float, a glint, the card's light, the black screen's fade or the cursor's twitch; `shake` none without `Settings.shake`. (DESIGN.md: "juice.gd")
  - **Run `Juice`'s tweens whatever the panel's process mode,** since a tip pauses a fight over its verdict; `pop_out` runs once, and of two `hit_stop`s the one that ends last wins.
  - **Slide a page by its canvas item's transform alone** (`Juice.slides`), so the node is where it settles, and hidden at once, to every check and test; none in a headless run.
- **Draw the loot beam as pixel art:** pixels of `pixel` (`CombatScene._snap`), two strengths, three colours only -- `colour`, `HOT[colour]` (`test_combat`) and white; a line thickness in the shader is `* pixel`. (DESIGN.md: "loot_beam.gd / loot_beam.gdshader")
  - **Keep `orb_shine.gdshader` and `node_glow.gdshader` smooth, not pixel art** (the user's word). (DESIGN.md: "orb_shine.gdshader", "node_glow.gdshader")
- **Multiply by `COLOR` in `shine.gdshader`,** so a modulate still reaches a glinting icon; it has no clock of its own (`ItemSlot._shine`). (DESIGN.md: "shine.gdshader")
- **Spin the coin only in the air** (`Coins.frames()`; `icon()` is still), and never count more than `MOST` (10) coins (`count_for`). (DESIGN.md: "coins.gd")

## Gotchas
- **Give a Control with no themed ancestor `UITheme.theme()` itself** -- anything added straight to a `CanvasLayer` (icon buttons, cards, pages) -- or its type variation means nothing. (DESIGN.md)
- **Never make a floating card a Godot tooltip,** which is its own window and cannot inherit `ui_scale`: place an ordinary Control with `ItemCard.beside`, twice (now and deferred), labels not having laid out on the first pass. (DESIGN.md; the why: "Rules and gotchas")
- **Call `accept_event()` before a press redraws its own Control out of the tree** (the doll, a shelf cell, a spell square, `OrbSlot`, `SkillTreeView`), or the map behind takes the press and the release and selects the tile under it. (DESIGN.md)
- **Turn a mark in its image, never through the node:** a container sets its children's `rotation` and `scale` back whenever it lays them out (`Accordion` draws its caret both ways). (DESIGN.md)
- **Add what overhangs last:** tree order is draw order on a `CanvasLayer` (`OrbCard` after the character sheet). (DESIGN.md)
- **Pad a scroll whose first row is squares by `ItemRarity.FRAME_HEAD` (4),** inside the scroll (`TownPage`'s counter, `DropsView`'s grid): a frame stands that far above its square, never past its sides, and a scroll clips. (DESIGN.md)
  - **Pad a scroll by whatever its children draw past their rect** (`SkillsPage`). (DESIGN.md: "Put a panel's long part in `UITheme.scroll()`")
- **Give `CloseButton` its size,** `UITheme.icon_size("CloseButton")`: it has no minimum size of its own. (DESIGN.md)
- **Give a `table_row` a width in a panel that sizes itself:** with none it wraps its name at nothing on the first pass, and the panel never shrinks back from that height (`CloudQuestion.COLUMN`). (DESIGN.md: "cloud_question.gd")
- **Clip a shelf square's price label** (`clip_text`), never let it push: a six-figure price would widen the page into the panel beside it. The whole number is in the tooltip and on the Buy button. (DESIGN.md)
- **Count coins in whole tens, never with `log()`** (`Coins.count_for`): `log(1000)/log(10)` floors to 2. (DESIGN.md)
- **Trust the coin sheet's measured geometry:** `FRAMES` is 9 though the sheet is wider. (DESIGN.md)
- **In a headless test, move `Input`'s mouse for a drag:** a drop lands there, not where a pushed event says (`test_inventory`'s `_mouse_drag`: `Input.parse_input_event`, a frame an event). (DESIGN.md: "Keep drag and drop a mouse's alone")
- **Slide out a picture of a page as it hides** (`Juice._slide_out`): Godot draws nothing of a hidden Control. (DESIGN.md: "juice.gd")
- **Light nothing on the cream in white, a pale grey or gold:** none was seen there, nor the card's `orb_shine` at a node's size -- hence `ROOT_GLOW`, the tree's ink lines and `node_glow.gdshader`. (DESIGN.md: "skill_tree_view.gd", "node_glow.gdshader")
- **Do not read `TownPage.TAB_REST` as the tabs':** it is the fade a posting wears while another bounty is out, and a curse the skulls cannot pay for. (DESIGN.md: "town_page.gd")
- **Leave a settings slider's `scrollable` off,** so the wheel scrolls the page. (DESIGN.md: "settings_page.gd")

## Files
| File | Contents |
|---|---|
| `ui_theme.gd` (`UITheme`) | Builds the shared `Theme` from `Assets/UI/ui_sheet.json`: type variations, static widget builders, and the window's shape (`pick_scale`, `narrow`, `dock`). |
| `accordion.gd` (`Accordion`) | A section that folds: a heading with a drawn triangle over a `body` the caller fills. |
| `palette.gd` (`Palette`) | The colours drawn in code, every one in ENDESGA 64. |
| `bag_page.gd` (`BagPage`) | The bag, the doll beside it and the orb and rune trays at its foot; also the heirlooms' page, a transcension's bag and its stones page. |
| `doll.gd` (`Doll`) | The figure on the bag's sheet under its eight socket squares: where each sits, and which is under a point. |
| `skills_page.gd` (`SkillsPage`) | The skill tree page: the free points and the zoom over a `SkillTreeView`, and one Reset. |
| `town_page.gd` (`TownPage`) | The settlement on the right edge, a tab a counter: shelves, smith, bounty board, fortuneteller and her banishing. |
| `smith_swing.gd` (`SmithSwing`) | The smith at `TownPage`'s bench: his portrait, his hammer strike's clock and its sound. |
| `transcend_page.gd` (`TranscendPage`) | The black screen between two worlds: four cards (heirlooms, curses, skill tree) and the way into the new world. |
| `bounty_list.gd` (`BountyList`) | The bounty journal on the left edge, and `row`, the card a posting is written out as. |
| `bounty_rewards.gd` (`BountyRewards`) | What the bounty board hands over, each a panel in a screen-wide catch over the town: a claim's verdict (`show_paid`) and a cleared board's three options (`show_choice`). |
| `leaderboard_page.gd` (`LeaderboardPage`) | The leaderboards on the left edge, a tab a board, with the sign-in and the name. |
| `cloud_question.gd` (`CloudQuestion`) | The cloud's "Keep which save?" over the whole window: the two saves and a button each. |
| `text_prompt.gd` (`TextPrompt`) | A line of text asked for over the whole window: a field, Cancel and a green verb. |
| `settings_page.gd` (`SettingsPage`) | The settings on the left edge, and its Controls, Credits and Developer screens. |
| `item_generator.gd` (`ItemGenerator`) | Dev only: a piece made to order and added to the bag. |
| `achievements_page.gd` (`AchievementsPage`) | The achievements on the left edge: a share bar over one grid of squares, each with its progress bar and card. |
| `collection_page.gd` (`CollectionPage`) | The collection log on the left edge: every unique by name, found, known or locked, over the bonus and the count. |
| `character_panel.gd` (`CharacterPanel`) | The player in the top corner: portrait, level badge, damage line and experience bar. |
| `character_page.gd` (`CharacterPage`) | The character sheet on the left edge: name card, the two headline damages, curses, effects and stat tables. |
| `item_details.gd` (`ItemDetails`) | One item written into a `VBoxContainer` as a table (`fill`), and what a swap would change (`deltas`). |
| `item_slot.gd` (`ItemSlot`) | One item as a square: icon on a tan socket under its rarity's frame, with its corner marks. |
| `item_card.gd` (`ItemCard`) | The floating card for the piece under the cursor, the worn piece's under Alt, its key row and its light. |
| `tip_card.gd` (`TipCard`) | Every `tooltip_text` in the game as a cream card beside its Control. |
| `tile_panel.gd` (`TilePanel`) | The selected tile's panel on the right edge: name, kind and level, lands, services, modifiers, runes, a wall's unlocks, and the buttons that can be pressed (`fill`, `update_buttons`). |
| `banner.gd` (`Banner`) | What is announced over the map and a fight: the banner (a new unique, a filled bounty, an achievement), the bounty toast and the level-up fanfare. |
| `changelog.gd` (`Changelog`) | `CHANGELOG.md` read into versions (`versions`, `since`) and laid out as the web build's start-up page (`page`). |
| `dialogue_box.gd` (`DialogueBox`) | Someone speaking: a box along the window's foot, words coming in beside a portrait. |
| `orb_slot.gd` (`OrbSlot`) | One orb, super orb or rune as a square in its tray. |
| `orb_card.gd` (`OrbCard`) | The floating card for the orb under the cursor. |
| `skill_tree_view.gd` (`SkillTreeView`) | The skill tree round its root: lays it out, draws, lights and zooms it, and takes its presses. |
| `coins.gd` (`Coins`) | The coin's icon and spin, and how many coins an amount is worth. |
| `kill_pips.gd` (`KillPips`) | A row of pips, one an enemy and its shape its tier: the fight's kill bar and a board's row. |
| `health_bar.gd` (`HealthBar`) | The enemy's health: a tier frame of three parts, a drawn fill and a ghost that drains. |
| `loot_beam.gd` (`LootBeam`) / `loot_beam.gdshader` | The beam over a rare-or-better find or a good orb in the arena. |
| `cursors.gd` (`Cursors`) | The mouse cursors, the orb held as one, and what a finger's tap means (`touched`, `applies`). |
| `juice.gd` (`Juice`) | Static effects: sounds, bursts, hit stop, shake, how popups come and go, how side pages slide. |
| `orb_shine.gdshader` | The light `ItemCard.shine` puts behind a card when an orb went into its piece. |
| `node_glow.gdshader` | The light behind a skill node a point can go into. |
| `grey.gdshader` | Greys a piece the collection log knows of and the player has not found. |
| `shine.gdshader` | The diagonal glint `ItemSlot` puts on rare and better. |
