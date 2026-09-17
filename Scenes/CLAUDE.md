<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

# Main scene (`Scenes/main_scene.gd`) and rules that span several folders

**Read `Scenes/DESIGN.md` before changing how the bag, the character sheet, the orb tray, the tips or the balance are meant to work.** It holds the why; this file holds what must stay true.

## What the main scene owns
- **Exports:** `world_seed` / `map_seed` (0 = carry on from the save, else random; used seeds are printed), `map_origin` (even row), `zoom` (3) and `ui_scale` (2), whole numbers only so a sprite pixel stays square, and `inventory_path` / `map_path`.
- **Start-up (`_ready`):** loads the inventory, then the map; either one unreadable stops everything (`_refuse_save`). Then builds or restores the map through `MapBuilder`, builds the UI, and saves the map once.
- **The UI is built in code**, so the `.tscn` stays untouched while the editor has it open. Shared builders are statics on `UITheme` (`titled_panel`, `body_of`, `button`, `icon_button`, `label`, `rule`, `vbox`, `clear`).
  - Right edge: the tile panel (`_panel`) with the tile's name, level, one row per environment, and Chart / Move here / Farm, each **shown only while it can be pressed** (`_update_buttons`).
  - Top-left: `CharacterPanel` on its own `CanvasLayer` 3, above a fight (layer 2). Under it the two brown corner buttons (chest, star), which come and go together (`_show_corner`).
  - Left edge: `BagPage` and `SkillsPage` (`Scenes/UI/`). Each takes the inventory, the save path and `ui_scale`, saves what it changes itself, and offers `open()`, `layout()` and `closed`. Only one is ever up: `_open_left_page` / `_close_left_pages` are the one place that knows which pages there are.
  - `ChestPointer` (`Scenes/Map/`): main sets its `target` on arrival.
- **Fights:** `_open_fight` arms an `Encounter` from `inventory.stats()`, makes a `FightLedger`, hides the map and every left-hand Control, and wires `CombatScene`'s signals to the ledger. `_on_combat_finished` banks, charts the tile if it was won, and brings the map back.
- **Tips (`TIPS`, `_check_tips`):** one-time pop-ups, one at a time, on layer 3. Seen ids live in `inventory.tips`, which also drives which corner buttons exist and whether they still pulse (`_flash`, `opened_bag` / `opened_skills`). A tip over a fight pauses the fight's processing.
- **Dev reset:** a debug-build-only button deletes both saves and reloads; `_resetting` stops `_exit_tree` writing them back.

## Rules and gotchas
- **A save that cannot be read is refused, never overwritten.** `_refuse_save` runs before any UI exists, so nothing can write; `_save_blocked` also stops `_save_map` and `_exit_tree`. Only a *missing* file means a fresh start.
- **The map is written in three places:** the end of `_ready`, every arrival (`_on_player_arrived`, the one place the map's state changes) and `_exit_tree`.
- **A non-zero seed in the scene wins over a save of another world**, and so does a changed `map_origin`. Every test and screenshot script pins a seed, so every one of them **must redirect `map_path` and `inventory_path`** or it replaces the player's saves.
- **Bank or pouch is `FightLedger`'s rule and nobody else's.** A tile fight banks and saves each find, purse, orb and experience as it lands; a farm run holds them until `bank()`. Both ways out of a run bank (`_on_combat_finished`, `_exit_tree`), and `bank()` is safe to call twice. Gold, orbs and experience can never be refused: the bag's cap and autodiscard apply to gear only.
- **Autodiscard is applied in exactly one place, `CombatScene._on_loot_dropped`.** The main scene listens to `loot_kept` / `loot_discarded`, never to `Encounter.loot_dropped`, so the counter, the pouch and the bag cannot disagree.
- **No Control may sit in the top-left corner during a fight:** it would take the mouse before the fight saw it and eat the player's swings. `_open_fight` closes the pages and hides the corner buttons; `CharacterPanel` ignores the mouse.
- **No orb drops before the player's 50th kill** (`OrbTable.FIRST_ORB_KILLS`): `_open_fight` passes what is left to `Encounter.orbs_after`, and `FightLedger.bank_kills` adds a fight's kills when it ends or the game closes.
- **The first elite is promised a drop until one has handed something over** (`inventory.first_elite_taken`, set by the ledger -- an autodiscarded elite drop counts).
- **Only the offensive stats, drop rate and the skill-only stats do anything:** `damage`, `crit_chance`, `crit_damage`, `attack_speed`, `drop_rate`, `item_rarity`, `orb_find`, `gold_find`, all read in `Encounter.arm()`. Capstone skills arrive as `Encounter.effects`. Every defensive stat is rolled, saved and shown and does nothing, because nothing can hurt the player yet.
- **Monsters outgrow gear on purpose.** `HP_GROWTH` is per hex step, `LEVEL_GROWTH` per level, and levels come in widening bands. `test_combat._test_a_won_fight` pins the three ends (first ring beatable bare-handed; a plain set at the far edge needs 8+ clicks a second; farmed rares bring it under 8 but over 1). Dials: `HP_GROWTH`, `LEVEL_GROWTH`, `LEVEL_FLAT`, `Encounter.SECONDS`.
- **The comparison beside an open bag item is against `Equipment.sockets_for(item)[0]`**, the same socket Equip targets. The stat block itself never shows deltas.
- **A bag square takes no mouse input** (`MOUSE_FILTER_IGNORE`): the `ScrollContainer` must see every press to tell a drag from a click, so the clicked square is worked out from the cursor position.
- **Tip copy:** a short title-case title, then two or three plain sentences in the game's voice: what happened, then what to do, naming a button by its picture and corner. No system words ("pouch", "autodiscard"), no dashes, nothing Pixellari may not draw.
