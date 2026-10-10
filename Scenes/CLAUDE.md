<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

# Main scene (`Scenes/main_scene.gd`) and rules that span several folders

**Read `Scenes/DESIGN.md` before changing how the bag, the character sheet, the orb tray, the tips or the balance are meant to work.** It holds the why; this file holds what must stay true.

Short forms only. The full text is in `DESIGN.md` under "Reference (moved here from CLAUDE.md on 2026-10-10)": a responsibility under the `####` heading of its own name, a rule under the one it names.

## What the main scene owns
- **Exports:** `world_seed` / `map_seed`, `map_origin`, `zoom`, `ui_scale` (0 = from the save or the window), `inventory_path` / `map_path`.
- **Start-up** (`_ready`): scratch paths if headless, the cloud, the inventory, the map, `MapBuilder`, the UI, one map save.
- **The UI is built in code** from `UITheme`'s static builders, so the `.tscn` stays untouched while the editor has it open:
  - **The tile panel** (`_panel`, right edge): name, kind and level, lands, services, modifiers, runes, a wall's unlocks, its buttons (`_update_buttons`).
  - **The corner** (top-left): `CharacterPanel` on `CanvasLayer` 3 over the corner buttons (`_place_character`, `_show_damage`, `_place_corner`, `_show_corner`, `HOTKEYS`).
  - **The crown:** the corner button for `heirloom_page`, a second `BagPage`, there while an heirloom is held.
  - **Sliding panels** (`Juice.slides`, registered in `_build_pages`); the corner column glides after them (`Juice.glide`).
  - **Left-hand pages:** nine (`Scenes/UI/`), listed by `_left_pages()`.
  - **The town page** (`TownPage`, in the tile panel's place), the bag in shop mode beside it (`_stand_at_counter`).
  - **Promised piece** (`town_page.item_claimed`): a bounty's is announced as a body's would be (`_is_new_unique`, `_announce_unique`), and nothing for any other piece.
  - **Bounty verdict** (`_show_bounty_paid`, `_close_bounty_paid`): what a handed-in bounty paid; everything is already paid, so it only shows.
  - **Board reward** (`_show_board_choice`, `_catch`): a cleared board's three options; put away untaken it waits in the town's drawer.
  - **Chest pointer** (`_chest_pointer`, `_sync_chest`): a `MapPointer` up for as long as the fortuneteller's chest is, and at no chest for nothing.
  - **Hero pointer** (`_hero_pointer`, `_find_hero`): a button at the map's foot once the map is dragged or zoomed off the hero.
  - **Aimed spells** (`_on_spell_aimed`, `_on_cell_aimed`, `_end_aim`): the fortuneteller's scour and road home.
- **Super orbs** (`_credit_walls`): pays the fallen walls and climbs the heirlooms to the charted level.
- **Transcending** (`_open_transcend`, `_transcend`): the black `TranscendPage`, in memory only, then a Reset with the inventory written over.
- **Tile modifiers** (`_mods_of`, `_show_mods`): what a tile's fight is built with and what the panel writes.
- **Curses:** the Ring of Walls (`view.wall_step`), the homeland (`_settle_homeland`), No Second Chances, `_sight` and `_cannot_camp`.
- **The dungeon** (`_on_cave_pressed`, `_on_dungeon_pressed`, `_on_dungeon_finished`, `_bank_depths`): the descent from the Gollux cave.
- **The cloud** (`cloud`, `leaderboard_page`, `_cloud_question`): the account, the cloud save and the board; the server is `backend/leaderboard/README.md`.
- **The cave felt** (`_cave_sense`, a `CaveSense`): the red light at the map's edge toward an unseen cave.
- **Camps** (`_camp_while_away`, `_break_camp`): pay for the hours the game was shut, under `CampScene`.
- **Farm runes** (`_on_farm_pressed`, `_on_kill_paid`): a tile's rune work (`inventory.rune_work`), counted down a body at a time.
- **Walking to a fight** (`_walk_to_fight`, `_on_player_arrived`, `_retreat_cell`).
- **Stop** (`_stop_button`, `_on_stop_pressed`): cuts a walk short.
- **Fights** (`_open_fight`, `_on_combat_finished`); all three kinds go through `_arm`, `_cover_map` and `_uncover_map`.
- **Bag over a fight** (`_let_bag_over`, `_rearm`, `_refresh_bag_room`).
- **The banner** (`_raise_banner`, `_close_banner`, `_place_banner`): a new unique (`_announce_unique`) or a filled bounty (`_announce_bounty`).
- **Bounty toast** (`_toast_bounty`, `_place_toast`): "+1" for a counted kill, or "Level too low".
- **Tips** (`TIPS`, `_check_tips`, `_tip_due`), and the corner buttons' flash, pulse and red pip (`_flash`, `_pulse`, `_mark_new`).
- **Changelog** (`_show_changelog`, `changelog()`): the web build's start-up panel of new `CHANGELOG.md` versions.
- **Achievements** (`_check_achievements`, `_announce_achievements`, `_on_achievements_pressed`).
- **Window shape** (`_layout_ui`, `_pages_room`, `_narrow`): every page's room, wide or held upright.
- **Under a finger** (`Cursors.touched`, fed by `_input` through `Cursors.feel`).
- **Escape** (`ui_cancel`, `_unhandled_input`).
- **Reset** (`_on_reset_pressed`): the settings page's Reset save.
- **Play clock:** `_process` adds to `inventory.play_seconds`, written only when something else writes the inventory; only the character page's Misc table reads it.
- **Character's name** (`_on_rename_pressed`, `_on_name_entered`): a `TextPrompt`, then `Inventory.rename`; `inventory.hero()` titles the panel, the page and the hero's tips.

## Rules

### Saves
- **Refuse an unreadable save,** never overwrite it: `_refuse_save` runs before any UI exists, and `_save_blocked` stops every later write, the cloud, frames and input. Only a *missing* file is a fresh start. (DESIGN.md: "Refuse an unreadable save")
- **Play headless on scratch files** (`HEADLESS_INVENTORY`, `HEADLESS_MAP`, first thing in `_ready`), so a headless run never loads, rewrites or uploads the player's saves. (DESIGN.md: "Play headless on scratch files")
- **Redirect both save paths** (`map_path`, `inventory_path`) in every test and screenshot script: a non-zero seed or a changed `map_origin` wins over a save of another world. (DESIGN.md: "Redirect both save paths")
- **Write the map in six places:** the end of `_ready`, `_on_player_arrived`, a paid scour (`_on_cell_aimed`), `town_page.towns_revealed`, a cave put down (`_credit_walls`), `_exit_tree`. (DESIGN.md: "Write the map in six places")
- **Never save the player onto uncharted land:** mid-fight `_save_map` writes them at `_retreat_cell`. (DESIGN.md: "Walking to a fight")
- **Save the inventory only through `_save_inventory()`** (`_may_save`), and never while `_transcend_page` is up: a game closed there has not transcended. (DESIGN.md: "Transcending")
- **Keep `_transcend`'s order:** `inventory.transcended().save`, the map deleted (`SafeFile.remove`), the reload under `_resetting`; a map that will not go puts the old inventory back. (DESIGN.md: "Transcending")
- **Ask before a Reset, in every build:** `_on_reset_pressed` awaits `cloud.forget_save()`, deletes both saves and reloads under `_resetting`; a file that will not go is no reset, and the settings file stays. (DESIGN.md: "Reset", "The cloud")
- **Rename never over a refused save, a reset or the black screen** (`_on_name_entered`). (DESIGN.md: "Character's name")
- **Write as the web build loses the focus** (`_keep_run`, safe to repeat): its tab closes with no `_exit_tree`. (DESIGN.md: "Take every gain as it lands")

### Start-up, settings and sound
- **Keep `_ready`'s order:** scratch paths, `_find_cloud`, the inventory, the map; either unreadable, or handed back as nothing with no word about a file that is there (`_unread`), stops everything (`_refuse_save`). (DESIGN.md: "Start-up")
- **Keep `zoom` and `ui_scale` whole numbers** (a sprite pixel stays square) and `map_origin` on an even row; zoom only on bare map outside a fight and a town (`_zoom_at`). (DESIGN.md: "Exports")
- **Pick `ui_scale` after reading the settings** (a full-screen start is measured full) and after turning the project's stretch off, never headless: the tests lay out against it. (DESIGN.md: "Never pass Settings around", "Window shape")
- **Never pass Settings around:** it is static and read where it matters. `Settings.path` is empty off the player's own save, so tests write nothing; a test that moves a static puts it back. (DESIGN.md: "Never pass Settings around")
- **Load sound effects only from `Sounds/Sfx/`** (cut by `tools/sound_levels.py`). Every sound plays whatever the animation level, a one-off through `Juice.sound`, on the root, so a closing page cannot cut it. (DESIGN.md: "Never pass Settings around")

### The cloud
- **Keep the cloud on only beside the player's own save:** `_find_cloud` finds the run's one under the root (`Cloud.NODE`) or makes it, off in a test or a screenshot; quitting goes through `Cloud.leave`. (DESIGN.md: "The cloud")
- **Run `cloud.launched()` before `_ready` writes anything,** or every change of device becomes a question: the first sync judges the device by the files as found. (DESIGN.md: "The cloud", "The cloud save (2026-09-30)")
- **Block the cloud on a refused save** (`cloud.blocked`; the next scene's `_find_cloud` clears it, which is why that runs before either save is loaded). (DESIGN.md: "The cloud")
- **Hold a download or a question for `cloud.calm`, never an upload;** the launch's first sync waits for calm whole, so a start-up camp syncs in `_break_camp`. (DESIGN.md: "The cloud")
- **Reload on a download** (`_on_cloud_replaced` sets `_resetting`), so nothing of the old scene is written over the files; a download is read before it is written (`Cloud._download`). (DESIGN.md: "The cloud")

### Fights and loot
- **Take every gain as it lands,** in every fight; when it is written is `FightLedger`'s rule alone: a tile fight saves each gain, a farm run nothing of its own until `bank_kills`, which both ways out call (`_on_combat_finished`, `_exit_tree`). (DESIGN.md: "Take every gain as it lands")
- **Count a bounty kill in the ledger, never in the interface** (`_on_enemy_died` -> `ledger.add_kill`); the screen hears only `bounty_counted`. (DESIGN.md: "Take every gain as it lands")
- **Wait for `Encounter.kill_paid` before changing what the next body pays:** `enemy_died` fires before the loot, so a rune's last body would be fought under it and paid without it (`_on_kill_paid`). (DESIGN.md: "Take every gain as it lands", "Farm runes")
- **Autodiscard in one place,** `CombatScene._on_loot_dropped` (`Inventory.leaves_behind`), and gear only: gold, orbs and experience are never refused. Listen to `loot_kept` / `loot_discarded`, never `Encounter.loot_dropped`. (DESIGN.md: "Autodiscard in one place")
- **Keep the fight's corner clear:** no Control in the top-left but the corner buttons, or it eats the player's swings; the one exception is the experience bar's tooltip (`MOUSE_FILTER_PASS`). (DESIGN.md: "Keep the fight's corner clear")
- **Call wear before arm:** `_arm` calls `fight.wear(inventory.effects(), Achievements.ranks(inventory))` before `fight.arm(inventory.stats())`, for `_open_fight`, the camp and the dungeon alike. (DESIGN.md: "Call wear before arm")
- **Rearm mid-fight, never wear again** (`_rearm`, deferred on `inventory.save_written`): a changed piece counts from the next blow, and `arm` moves the clock by the gear's seconds, never refilling it. (DESIGN.md: "Bag over a fight")
- **Let the bag open over every fight** (the user's, 2026-10-02), its button and `I`, the cog and `O` (2026-10-03), standing until the verdict while the clock runs on (`_let_bag_over`, `panel_up`, `page_up`). (DESIGN.md: "Bag over a fight")
- **Keep the layers:** the UI's and the character's are 3, over a fight's 2, the character's the later sibling, so cards, tips and banners stand over the pages. (DESIGN.md: "Bag over a fight")
- **Chart a won tile from `_exit_tree` too** (`_chart_won`): only Collect would have charted it. (DESIGN.md: "Fights")
- **Hand `_mods_of(cell)` to all three places a fight is built** (Chart, Farm, the camp). (DESIGN.md: "Tile modifiers")
- **Turn the strikes on here** (`fight.strikes = true` in `_open_fight`): a hand-built fight, a farm run, a camp and the ice wall are never struck. Block is in tenths of a second (`LootTable.SECONDS_STATS`), and time on hit never wins back more than the blows took. (DESIGN.md: "Turn the strikes on here")
- **Pay salvage in all four places** gear is thrown away (`Inventory.salvage`, `salvage_orb`: `_on_loot_autodiscarded`, `_on_drop_discarded`, `BagPage._on_discard_pressed`, `_on_clear_level_pressed`). (DESIGN.md: "Pay salvage in all four places")
- **Add only drops to a full bag** (`Inventory.add`): a drop past `CAPACITY` is kept, never destroyed, and overencumbers the player (`Inventory.encumbered()`, Chart and Farm refused). A purchase is refused instead, and an Equip that would hand two pieces back into room for one (`Inventory.can_equip`). (DESIGN.md: "Add only drops to a full bag")

### A new player's first kills
- **No orb before kill 20** (`OrbTable.FIRST_ORB_KILLS`, passed as `Encounter.orbs_after`); `FightLedger.bank_kills` adds a fight's kills when it ends or the game closes. (DESIGN.md: "No orb before kill 20")
- **No unique before kill 100** (`UniqueTable.FIRST_UNIQUE_KILLS`), nor one not unlocked (`Achievements.unlocked`) or banished (`FortuneTeller.dropping`, which `TownPage` asks too). None is promised but the first and a chest's (`Encounter.MIMIC_UNIQUE`, else `MIMIC_ROLLS` certain pieces). (DESIGN.md: "No unique before kill 100")
- **Deal a Broken Sword first** (`LootTable.FIRST_DROP`, weight 0): any gear that falls is it until `inventory.first_sword_taken`, set on any drop, autodiscarded or not. Its first Transmutation while common is always "+1 Damage" alone (`OrbTable._reroll_at`, the user's, 2026-10-10). (DESIGN.md: "Deal a Broken Sword first")
- **Script the first kills** (the user's, 2026-10-10; `Encounter.PROMISED`): the Broken Sword in kills 1-10, a Transmutation in 11-20, an Augmentation in 21-30, the Squire's Blade in 101-120, a common Strength Node with three connectors in 151-170. (DESIGN.md: "Script the first kills")
- **Make every kill of a promise as likely as the next and its last certain** (`Encounter._due`); the fight is handed only `Inventory.promised()` and `inventory.kills`, and `guarantee_elite` is the tests' and the screenshots'. (DESIGN.md: "Script the first kills")
- **Owe a promise only while it is never had, its kills not run out and no transcension yet** (a save past its kills gets nothing, a second world none); it is spent as the find lands (`FightLedger`), the unique by anything in the collection log. (DESIGN.md: "Script the first kills")
- **Drop no skill node while the first is owed;** the two orbs come through `orbs_after`, which holds every other. (DESIGN.md: "Script the first kills")
- **Read an old save as already dealt:** before version 13 the sword is taken, before version 27 the first orb. (DESIGN.md: "Deal a Broken Sword first", "Script the first kills")

### Stats, numbers and money
- **Read only these stats** in a fight, all in `Encounter.arm()`: `damage`, `crit_chance`, `crit_damage`, `attack_speed`, `bleed`, `armor`, `dodge`, `block`, `time_on_hit`, `drop_rate`, `item_rarity`, `gold_find`, `orb_find`, `spawn_speed`, `fight_clock` (capped at `Encounter.CLOCK_MOST`, not on a run). (DESIGN.md: "Read only these stats")
- **Read the attributes in `Inventory.stats()`,** in the fight only for the Brawler's Wraps. No fight reads `move_speed` (`PlayerToken.move_speed`) or `sight` (`_sight()`, only where a won tile is charted). (DESIGN.md: "Read only these stats")
- **Keep drop rate the broad finder:** `_kill` adds it to `gold_find` and `orb_find`; `gold_of` and `OrbTable.chance_for` stay untouched, so town prices do not move. (DESIGN.md: "Read only these stats")
- **Let monsters outgrow gear:** `HP_GROWTH` a hex step, `LAND_GROWTH` an ice wall behind the cell, `LEVEL_GROWTH` a level, every `WALL_STEP` wall on a band edge (`MapBuilder.LEVEL_TILES`). Tuned by hand, no test holding any of it. (DESIGN.md: "Let monsters outgrow gear")
- **Format growing numbers** through `BigNumber.format`: gold, prices, rewards, monster health and damage are whole-valued `float`s. Levels, kills, counts, percents, experience and modifier values stay `int`, but modifier numbers and percent stats are written through it too. (DESIGN.md: "Format growing numbers")
- **Make money only in TownPrices,** in bodies: nothing outside it writes a figure in gold, and its purse is `Encounter.gold_at_steps`, which `base_gold` is built on. (DESIGN.md: "Make money only in TownPrices")

### The map, walking and the dungeon
- **Walk onto the tile before Chart or Farm** (`_walk_to_fight`; `_on_player_arrived` presses the button again). A lost tile runs the player back to `_retreat_cell`, the charted tile they stepped from, but not under Retry nor No Second Chances. (DESIGN.md: "Walking to a fight")
- **Drop `_fight_target`, `_town_target` and `_dark_way` before a Stop** (the user's, 2026-10-10), or the arrival presses their button again. The last step is never stoppable (`PlayerToken.can_stop`), and the button never stands under a page. (DESIGN.md: "Stop", "Stopping a walk (2026-10-10)")
- **Let a tile under the fog be clicked** (`HexMap.can_pick`): `_on_tile_clicked` calls it "Unknown land" without asking `name_of`, and `_on_chart_pressed` reads the terrain from `view.env_at`, never from what is drawn. (DESIGN.md: "Tile modifiers")
- **Write a tile's modifiers on the panel, never in a tooltip, and only for a seen tile** (`_show_mods`). (DESIGN.md: "Tile modifiers")
- **Run `_credit_walls` at start-up, before the interface is built, and after every `view.chart`:** it pays the walls, raises the heirlooms, puts the cave down and sets `view.distant`. (DESIGN.md: "Super orbs", "The dungeon")
- **Put the cave down only once Gollux is unlocked** (`WallUnlocks.GOLLUX`, the user's, 2026-10-09), beside the wall tile just broken (`view.place_cave(view.breach)`, after `inventory.reach`); one a world, and a world that holds a cave keeps it. (DESIGN.md: "The dungeon")
- **Enter the dungeon only by the tile panel's Enter cave** (`MapBuilder.can_enter_cave`), and pay only runes there: no ledger, nothing connected but `finished` and `rune_gained`, so no board hears of a body and no kill is banked. (DESIGN.md: "The dungeon")
- **Bank depths on the way out and from `_exit_tree`** (`_bank_depths`), so quitting under a dead Gollux cannot cost him, and sync at once (`cloud.sync(true)`): the board is scored from the cloud save's `dungeon_floors`. (DESIGN.md: "The dungeon", "The cloud")
- **Only ever raise `dungeon_depth`,** carried through every transcension (the user's ruling); each depth won is exactly one skull, the only skulls there are (`Inventory.skull_allowance`, the user's, 2026-10-03). (DESIGN.md: "The dungeon")
- **Walk distant charting's way as the Nightwalkers'** (`view.distant`, `_dark_way`), collecting a won tile's loot by itself as they do (`CombatScene.auto_collect`, the user's, 2026-10-09). (DESIGN.md: "The dungeon")
- **Keep camps automatic, with no button:** `_ready` reads `inventory.saved_at` before anything saves over it and, last of all, arms a run on `MapBuilder.best_farm()` as `_open_fight` does, pays `Camp.earned` at once and saves. `_break_camp` only takes the screen away, then syncs the cloud. (DESIGN.md: "Camps")
- **Forbid a camp under No Rest and Berserker's World** (`_cannot_camp()`); `_sight()` loses its own ring under the Thick Fog. (DESIGN.md: "Camps", "Tile modifiers")
- **Carry no rune work into a camp,** which builds its own run; on a farm run what ran out leaves the fight there and then (`Encounter.forget_mod`, `deeper`, `ascended`, then `_rearm`). (DESIGN.md: "Farm runes")
- **Take the held runes from the bag** (the user's, 2026-10-09): picked up off its rune row they aim the map, and the tile pressed is `_on_cell_aimed` -> `_rune_on` -> `BagPage.rune_on`. (DESIGN.md: "The tile panel")
- **Charge an aimed spell only where it did something** (`_on_cell_aimed`); `_end_aim` costs nothing, and `_on_spell_aimed` puts nothing up (the user's call). (DESIGN.md: "Aimed spells")

### Transcending and curses
- **Reach the black screen only through `_open_transcend(lost)`;** `_on_transcend_pressed` checks the price, never takes it, and calls it with false. (DESIGN.md: "Curses", "Transcending")
- **End a lost tile fight under No Second Chances on `_open_transcend(true)`,** last, so the fight is banked and saved first; never for a run, and `_on_combat_retry` stops there. (DESIGN.md: "Curses")
- **Set the curses' world straight after the map is built:** `view.wall_step` for the Ring of Walls, then `_settle_homeland()`, chosen once and saved with the inventory. (DESIGN.md: "Curses")

### Pages, the corner and the tile panel
- **Keep one left-hand page up, known only to `_left_pages()`:** what is wired, laid out and closed is that list, and each page saves what it changes itself. (DESIGN.md: "Left-hand pages")
- **Place the character panel only in `_place_character`:** a bag page or the skill tree across a wide window, out of a town, mirrors it top-right (the user's, 2026-10-07). The corner column's top never follows it (`_place_corner`, `CHARACTER_EDGE`). (DESIGN.md: "The corner")
- **Announce a damage change only on the save's run** (`_show_damage(true)`, the user's, 2026-10-07); the line is the live fight's numbers over a fight, `CharacterPage.armed`'s elsewhere. (DESIGN.md: "The corner")
- **Show and hide the corner buttons together** (`_show_corner`): a town takes them away, a fight leaves every one until its verdict (`_fight_up`, the user's, 2026-10-07), a page moves the column beside itself. A hotkey (`HOTKEYS`) answers only while its button could be pressed by hand and no modifier is held. (DESIGN.md: "The corner")
- **Swap pages in one press** (`_toggle_left_page`); a tile chosen outside a town closes the page (`_on_tile_clicked`), but never the bag while a rune in its hand aims the map. (DESIGN.md: "The corner")
- **Open `CharacterPage` through `_character_button`:** the panel takes no mouse. Over a fight the button stays, disabled and taking no mouse, only so the experience bar's tooltip still shows. (DESIGN.md: "The corner")
- **Leave the crown standing in a town:** it swaps which bag page stands at the counter (`_counter_page`) and never closes the town. Both bag pages are wired to the town alike, and `ItemCard.equipment` follows the one that is up. (DESIGN.md: "The crown")
- **Slide only the drawing** (`Juice.slides`): `visible` and `position` are the truth the moment a page is shown or hidden. (DESIGN.md: "Sliding panels")
- **Stand buttons at the foot of every right-hand column,** the tile panel's shown only while they can be pressed (`_update_buttons`, which re-places the column through `_place_panel`). (DESIGN.md: "The tile panel")
- **Hand every page its room only in `_layout_ui`** (`area`, `UITheme.dock`); held upright (`UITheme.narrow`), `_show_corner` and a town's tab lay everything out again. (DESIGN.md: "Window shape")
- **Keep the doll on a selection:** a selected bag item draws nothing of what it would replace, the worn piece is the hover card's second card under Alt (`ItemCard.worn_for`), and no block shows deltas. (DESIGN.md: "Keep the doll on a selection")
- **Equip onto the emptiest socket the piece fits** (`BagPage._socket_pick`; a ring's Swap turns it to the other finger). Hide folds the doll for the session only (`_doll_hidden`, not saved). (DESIGN.md: "Keep the doll on a selection")
- **No mouse on a bag square** (`MOUSE_FILTER_IGNORE`): the `ScrollContainer` must see every press, so the clicked square is worked out from the cursor position. (DESIGN.md: "No mouse on a bag square")

### Towns and bounties
- **Keep a town one thing:** `TownPage` and the bag in shop mode open together and close only through `_close_town` (the X on either page, and `_open_fight`). Point the bag at `_town_cell`, never `map.selected_cell`, still clickable behind the page. (DESIGN.md: "Keep a town one thing", "The town page")
- **Walk to a settlement before entering it:** Enter town is there on a charted one Move here could reach (`_town_target`, opened by `_on_player_arrived`; the user's, 2026-10-10). (DESIGN.md: "The town page")
- **Only the smith levels a piece** (`Blacksmith`: level and base stats), one the bag page has open, carried or worn, never one off a shelf (the orb tray does craft there: `BagPage.craft_held`). His cap is the town's wall circle (`MapBuilder.circle_level`), not its tile's level. (DESIGN.md: "Only the smith levels a piece")
- **Derive counters, save doings:** `TownServices.services_for` is pure; anything rolled (`VendorStock`, `BountyBoard`) goes in `TownState` inside `inventory.towns`, keyed by world spot as `"x,y"`, so one save is one write. (DESIGN.md: "Derive counters, save doings")
- **Name a bounty's lands,** never its tile (the user's, 2026-10-01): there is no "Nearest" and no Show. (DESIGN.md: "Name a bounty's lands")
- **Count nothing for a bounty's monster killed on land shallower than its posting, and say so** (`FightLedger.bounty_too_low` -> `_on_bounty_too_low`); nothing once it is filled. (DESIGN.md: "Bounty toast")
- **Raise the banner and no toast for the kill that fills a bounty** (`_on_bounty_counted`); the latest toast wins, and there is none at `Anim.NONE`. (DESIGN.md: "Bounty toast")

### Tips, banners and achievements
- **Have every tip spoken, by the hero or an NPC, never a narrator** (the user's rule, 2026-09-26; a fourth `TIPS` entry names the portrait). The copy is the user's own, word for word: change it only when asked. (DESIGN.md: "Tips", "Spoken tips (2026-09-26)")
- **Keep tip copy in voice:** a short title-case title, then two or three plain sentences, what happened and what to do, naming a button by its picture and corner. No system words, no dashes, nothing Pixellari may not draw. (DESIGN.md: "Keep tip copy in voice")
- **Give every tip in `TIPS` its rule in `_tip_due`,** which logs an error for an id it does not know. (DESIGN.md: "Tips")
- **Check a tip where its thing becomes true** (`_open_fight`, `_on_combat_finished`, `_on_player_arrived` for `first_town`), never in `_close_town`, which is also the way onto the black screen. (DESIGN.md: "Tips", "The cave felt")
- **Pause a fight under a tip,** one over it or one already up as it opens. (DESIGN.md: "Tips")
- **Flash a corner button until its first press and never again** (`_flash`; the user's rule, 2026-09-30); seen ids live in `inventory.tips`, and the star pulses on state (`_pulse`). (DESIGN.md: "Tips")
- **Work the red pip out from state,** in `_show_corner` and after every save (`_mark_new`; the user's ask, 2026-10-07); the chest wears it only for a first of its kind (`BAG_FIRSTS`, the user's, 2026-10-10). (DESIGN.md: "Tips")
- **Put a banner down only through `_close_banner`.** It wears its X from the start and goes after `BANNER_HOLD`, never while the mouse is on it or under a finger (the user's rules, 2026-09-29, 2026-10-03, 2026-10-09). (DESIGN.md: "The banner")
- **Hold a banner while a pop-up is up** (`_popup_up`, `_held_banner`). A fight ending does not put one down, and a swing never touches it before its time has run out. (DESIGN.md: "The banner")
- **Raise a new unique's banner before `ledger.add_loot`** (`_on_loot_dropped`), the last moment `uniques_found` can still answer "is this new?". (DESIGN.md: "The banner")
- **Notice achievements on every save** (`save_written`, deferred, to `_check_achievements`), never while the black screen is up, nor over a refused or reset save. (DESIGN.md: "Achievements")
- **Record a fight before `ledger.bank_kills`** (`Achievements.record`, in `_on_combat_finished` and `_exit_tree`); a descent counts only the depth it wins, and `_pay_salvage` ticks `discarded`. (DESIGN.md: "Achievements")
- **Set `UniqueTable.ranks` from `Achievements.ranks` as the save loads and after every climb.** (DESIGN.md: "Achievements")
- **Show each changelog version once,** through the tip queue as the one plain panel left (`Settings.changelog_seen`, written as it is queued; a Reset does not bring it back). A new version is a new `## vX.Y.Z (YYYY-MM-DD)` heading with `### ` sections on top of `CHANGELOG.md`. (DESIGN.md: "Changelog")

### Touch and keys
- **Treat Android's back button as Escape** (`_notification`; `quit_on_go_back` is off), and a tap where an aimed spell can do nothing as a right click. (DESIGN.md: "Under a finger")
- **Let a finger's first tap on an aimed tile only choose it;** the next there does the deed (`Cursors.applies` in `_on_cell_aimed`; the user's, 2026-10-10). Under a held rune the tile's panel comes up with the bag left standing, since closing it puts the rune down. (DESIGN.md: "Under a finger")
- **Give Escape to a tip first,** then the pages, the town and the tile panel in one press. A fight gets the key first unless the bag stands over it (`page_up`), and the bag answers for its question, held orb and selection before it closes. (DESIGN.md: "Escape")
- **Do nothing on Escape under the black screen or a camp.** (DESIGN.md: "Transcending", "Camps")

## Gotchas
- **Round with `roundf` / `maxf`, never `roundi` / `maxi`,** which overflow at 9.2e18, and print with `%s`, never `%d`. `round()` / `max()` return a Variant and will not parse under `:=`. (DESIGN.md: "Format growing numbers")
- **A pass-through Control nothing handles lets a press reach the fight's `_unhandled_input`** (checked in a real window, 4.7); headless pushes never reach the GUI, so a test cannot show it. (DESIGN.md: "The corner")
- **Defer `_slide_character` to the frame's end,** or a page swapped for another bag page slides the panel twice. (DESIGN.md: "The corner")
- **A scaled Control is drawn about its `pivot_offset`:** the banner's placement accounts for it and re-runs on the panel's `resized`. (DESIGN.md: "The banner")
- **Mid-fight, the hit sounds and a Dreadmask put on are not followed** (`weapon_kind` is read in `_build`). (DESIGN.md: "Bag over a fight")
- **Health, energy shield, regen, leech and the resistances are gone,** with the hat, robe, slippers and Sapphire Amulet built on them. (DESIGN.md: "Turn the strikes on here")
- **`screenshot_ui.gd` runs under `Anim.NONE`,** so its shots are of settled pages. (DESIGN.md: "Sliding panels")
- **No test passes through the landing page,** which on a real start has read the settings and gone full screen already (`landing.gd`). (DESIGN.md: "Never pass Settings around")
- **`CHANGELOG.md` is packed only by `export_presets.cfg`'s include filter** (`test_inventory` checks it). (DESIGN.md: "Changelog")
- **A cave from before 2026-10-09 could stand walls out,** so `CaveSense.felt` asks that its cell is land. (DESIGN.md: "The cave felt")
