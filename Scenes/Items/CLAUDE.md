<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Items/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Items (`Scenes/Items/`)
Every kill rolls for gear (about one body in thirty), always hands over gold, and rolls separately for an orb. A body that does leave gear rolls again for more, up to `Encounter.MOST_DROPS`. Every drop is its own `Item` with a rarity, a level and modifiers; nothing stacks. **Read `DESIGN.md` here before changing what stats, modifiers, rarities or orbs mean** -- it holds the why.

## Files
| File | Contents |
|---|---|
| `loot_table.gd` (`LootTable`) | The kinds of gear and the pieces built from them, the gear roll, what a level does to a number, and how every stat is spelled. |
| `item_rarity.gd` (`ItemRarity`) | The five rarity steps: saved names and shown labels, weights, modifier counts, colours, frames, and the level a drop rolls. |
| `modifier_table.gd` (`ModifierTable`) | The modifier pool and its three kinds (PERCENT, FLAT, GLOBAL), each line's tiers and bands, and how a line is rolled and written. |
| `equipment.gd` (`Equipment`) | What is worn: the eight sockets, what a swap takes off, and the set's totals over one doll or two. |
| `item.gd` (`Item`) | One dropped piece: type, rarity, level, stats, modifiers, what the smith, the orbs and a transcension leave on it, its lines and its save. |
| `orb_table.gd` (`OrbTable`) | The six orbs, one job each: the one rule for applying one, which exist behind which wall, and their drop and shelf rolls. |
| `super_orb_table.gd` (`SuperOrbTable`) | The six super orbs, spent only on `TranscendPage` and only on heirlooms. |
| `unique_table.gd` (`UniqueTable`) | The unique items: each one's row, its ranked dials and card text, and the uniques' own drop roll. |
| `achievements.gd` (`Achievements`) | What unlocks a unique into the drops and what ranks it: the starters, the achievements, their progress, and what a finished fight records. |
| `wall_unlocks.gd` (`WallUnlocks`) | What each ice wall opens for good, read off `Inventory.walls_ever()`, the hours a camp holds and the squares a wall adds to the bag. |
| `rune_table.gd` (`RuneTable`) | The six runes, dropped only in Gollux's cave and spent on a charted tile, and a tile's rune work. |
| `player_level.gd` (`PlayerLevel`) | What a level costs in experience, and banking it. |
| `inventory.gd` (`Inventory`) | All the player holds (bag, worn gear, heirloom stash, gold, orbs, runes, skills, tallies), the stats a fight is armed with, and `save` / `load_from`. |
| `inventory_save.gd` (`InventorySave`) | The save file's shape behind `Inventory.save` and `load_from`: every key written, every older version read, and the list of what each version added. |

## Rules
Full text, numbers and reasons: `DESIGN.md`, "Reference (moved here from CLAUDE.md on 2026-10-10)". `(DESIGN.md)` is the `####` heading there that is the rule's own title, `(DESIGN.md: "x")` the heading x (a file's name is its heading under "Files in full"), and an indented rule is under its parent's heading.

### Saves, versions and renames
- **Put names on disk, never enum positions** (rarities, sockets, orbs). (DESIGN.md)
  - **Drop what a load cannot honour, never guess at it:** a retired item, mod, orb or ill-fitting socket.
- **Never let `Inventory` save itself:** the path is always a parameter, so tests never touch the player's save. (DESIGN.md)
  - **Never save over a file that came back with a `problem`:** one that is there and cannot be honoured comes back empty, with the reason in it.
- **Write the save through `SafeFile`:** `Inventory.save(path)` stamps `saved_at` only where the write got there, and says `save_written` either way. (DESIGN.md: "inventory.gd")
- **Read a field of the wrong kind as absent** (`Inventory.load_from`, which migrates old versions); a `version` that is no number is a `problem`. (DESIGN.md: "inventory_save.gd")
- **Name in `lost`, and in the log, every name a save holds and this build has not got** (`load_from`; `Item.from_dict(data, lost)`). (DESIGN.md: "inventory_save.gd", "item.gd")
- **Read a hand-edited number or flag of another kind as none,** and `broken` absent as whole (`Item.from_dict`). (DESIGN.md: "item.gd")
- **Load a renamed piece under its new name:** `LootTable.RENAMED` / `current(type)`, in `Item.from_dict`. (DESIGN.md: "loot_table.gd")
- **Count a renamed orb under its new name wherever a save is read** (bag, shelf, posting): `OrbTable.RENAMED` / `current(orb)`. (DESIGN.md: "orb_table.gd")
- **Load a retired `PLAYER` modifier as the FLAT line it became:** `ModifierTable.RENAMED` (the line and a factor for its number), read by `Item.from_dict` alone. (DESIGN.md: "modifier_table.gd")
- **Keep the old skill trees' lines `RENAMED` to the stone-rank lines** (Power strength, Fortune intelligence, Guard dexterity). (DESIGN.md: "Never open a modifier's line on a name")
- **Load a retired unique id, piece or kind as null,** and drop a stat `STAT_LABELS` has not got (`Item.from_dict`). (DESIGN.md: "Make a unique an `Item` with `unique` set", "Spend all four defence stats on the fight clock")
- **Save an optional field only where it is set:** `safe_level`, `plus`, `ascension`, `extra_slot`, `nickname`, a line's `"under"`, a stone's `stone_tier`, `connectors` and `capstone` (read before the lines). (DESIGN.md: "item.gd", "modifier_table.gd", "Treat skill nodes as items you cannot wear")
- **Tier a line saved before tiers with `ModifierTable.fit_under`;** read a line locked before `"at"` existed at the piece's level. (DESIGN.md: "modifier_table.gd", "Change nothing on a broken piece")
- **Drop an offhand saved beside a two-hander** (`Equipment.from_dict`). (DESIGN.md: "equipment.gd")
- **Save curses by name** (version 18; an older save is a world under none). (DESIGN.md: "Keep `Inventory.curses` apart from `pending_curses`")
- **Ignore a version 21-31 save's `skull_budget`.** (DESIGN.md: "Pay skulls only from Gollux")
- **Let a version 24 save learn `farthest_land`** (version 25) in the main scene's `_credit_walls`; ignore the `seeing_stone` saved beside it until 2026-10-03. (DESIGN.md: "Only ever raise `farthest_land`")
- **Read a version 25 save's `dungeon_floors` as `dungeon_depth * Encounter.DUNGEON.enemies`** (the field is version 26). (DESIGN.md: "Only ever raise `dungeon_floors`")
- **Read a version 28 `achievements` list as rank I** (id -> rank since version 29; `achievements_new` and `tally` are version 28 too). (DESIGN.md: "Drop a unique only once it is unlocked")
- **Mind the other versions** (the whole list heads `inventory_save.gd`): 20 the second batch of curses (`homeland`, `uniques_doubled`), 31 `hero_name`, 33 `skill_tree` and `skill_ranks`, 34 `runed` (only tiles still worked), 35 the heroes bought and the one in use (`characters`, `character`). (DESIGN.md: "Spend a skill point through the inventory, never `skills`", "inventory.gd", "Treat skill nodes as items you cannot wear")
- **Set `SkillTree.root_slots` before the tree is read:** `load_from` sets the root's one at the top and the save's own after `farthest_land` and before the tree, which keeps a stone only in a slot the root has. (DESIGN.md: "Only ever raise `farthest_land`")
- **Add a saved field in `InventorySave`, in `write` and in `_read_fields`, whose order is a rule:** the level before the tree, and the uniques found before the curses, or `note_unique` doubles every find of a Forgotten world. (DESIGN.md: "inventory_save.gd")
- **Never save `most_worn`:** `stash()` sets it on the heirlooms. (DESIGN.md: "Spend a skill point through the inventory, never `skills`")
- **Hold every build to the golden save** `tests/fixtures/inventory_golden.json`: read with nothing lost, written back field for field (`test_inventory._test_golden_save`, `_test_wrong_types`). A meant change shows there first; renew the file by loading and saving it. (DESIGN.md: "The walls' ladder (2026-10-09)")

### Levels and stats
- **Let only `LootTable.scale` know what a level does:** PERCENT and GLOBAL mods take the multiplier only, `CHANCE_STATS` the flat step only, a FLAT mod may name its own step (`level_flat`), the four weapon damage lines the multiplier and no step. (DESIGN.md)
- **Apply power after `scale`, in `Item.scaled_stats` alone** (`LootTable.power_of`): never write a kind's factor into `stats`, where `LEVEL_FLAT` would level it out. The material's share skips `CHANCE_STATS` and `RATE_STATS`; the kind's does not. (DESIGN.md)
- **Never move a rolled item's level or base stats:** frozen when rolled and saved with it; an orb changes only rarity and modifiers. The exceptions: the fortress smith (`Item.level_up`), `Item.transcend`, `Inventory.raise_heirlooms`. (DESIGN.md)
  - **Keep every tier and number through a smith's upgrade,** but a perfected line (the new top) and an heirloom's (back towards its `"peak"`).
- **Keep every modifier value a whole number** (saves hold `14`, not `14.0`; round-tripped items compare with `==`); stats are stored as the number they display. (DESIGN.md)
- **Spell a stat in one place:** `LootTable.STAT_LABELS`, `stat_line`, `stat_value`, `stat_delta`, `delta_shows`. (DESIGN.md: "loot_table.gd")
- **Store `SECONDS_STATS` (block, time on hit) in tenths of a second,** written in seconds by `seconds_of` / `seconds_text`; a whole-number roll can be a fraction of one. (DESIGN.md: "loot_table.gd")
- **Lead every line an item writes with its number:** `ItemDetails` splits on the first space. (DESIGN.md: "item.gd")
- **Write no word for a lock on its line:** `ItemDetails` writes `Item.locked_line()` in a base stat's ink. (DESIGN.md: "item.gd")
- **Add flat mods, then scale by percent mods** (`Item.effective_stats`). (DESIGN.md: "item.gd")
- **Apply a GLOBAL mod in `Equipment.totals`, never in `Item.effective_stats`:** once for the set, and two of them add rather than compound. (DESIGN.md)
- **Spend all four defence stats on the fight clock** (`Encounter.taken`): `armor` and `dodge` are ratings that grow with the level, never chances on the gear; `block` and `time_on_hit` are tenths. Block lives only on what is held. (DESIGN.md)
- **Keep `gold_find`, `item_rarity`, `bleed` and `sight` in `CHANCE_STATS`:** a level adds a point and never multiplies; only the material moves `sight`. (DESIGN.md)
- **Give the narrow finders the bigger numbers:** `drop_rate` is the broad one, `item_rarity`, `gold_find` and `orb_find` the narrow; all four are `CHANCE_STATS`. (DESIGN.md)
- **Roll `spawn_speed` on every piece** (`LootTable.ANY_AFFIXES`, read by `can_roll`): no flat step and one band at every level, so the cap is a set's worth of top rolls, not a level's. (DESIGN.md)

### Kinds, materials and drops
- **Walk every weighted pick with `LootTable.weighted_index`,** so no table's draw moves what a seed gives. (DESIGN.md: "loot_table.gd")
- **Settle rarity and level before the type** in `LootTable.roll`; `ITEMS` is read-only rows. (DESIGN.md: "loot_table.gd")
- **Gate a material by the tile's level, never the piece's own** (the user's, 2026-09-28): `roll` hands `tile_level` to `weighted`; `tier_at` draws evenly among the materials unlocked (`TIER_MIN_LEVEL`), and not at all while only one is. (DESIGN.md)
  - **Pass the town's tile level the same way** for a vendor's shelf and a bounty's promised piece.
  - **Keep the kind weights' sum:** it keeps each slot's share of drops what it was.
- **Read a piece's strength step from its `material`, never its `tier`:** a kind can begin past the plainest material (`tier_levels`). (DESIGN.md)
  - **Under `first_level`, deal a roll as the slot's plainest piece;** a bounty promising the kind lifts the piece to `first_level`.
- **Keep the eight shipped pieces tier 0 of their kind, the kind written first for its slot,** with the numbers they always had: "a plain piece for this socket", old saves, the uniques' bases and `icon_path`'s fallback rely on it. (DESIGN.md)
- **Treat a tile's level as a ceiling, not a payout:** `LootTable.drop_level` is the one place (`TIER_LEVEL`, `COMMON_REACH`), which `UniqueTable.roll` asks too. Balance numbers describe a piece at the ceiling. (DESIGN.md)
- **Hand out the Broken Torch only in `Inventory.transcended()`,** under the Thick Fog: `LootTable.BROKEN_TORCH` has weight 0, like the Broken Sword. (DESIGN.md)
- **Never let `affixes` overlap `stats`,** and give every affix a FLAT mod and every global a GLOBAL one, or it is unreachable (`test_inventory._test_items`; `_test_slot_locks` pins which stats are locked to which piece). (DESIGN.md)
  - **Leave out a stat's PERCENT mod where the piece may globalize it** (`ModifierTable.pool_for`): the two write the same sentence.
- **Lift weights with item rarity, never add steps:** UNIQUE has no weight in `TIER_WEIGHTS` and never comes out of `ItemRarity.roll` (a test holds that). (DESIGN.md)
  - **Roll uniques with `UniqueTable.roll`, beside the gear:** item rarity reaches them in `chance_for` (`RARITY_STEP[UNIQUE]`), after the drop rate (the user's ask, 2026-09-28).
- **Say "Epic" for the elite step** (since 2026-09-30): `ItemRarity.NAMES` is what a save holds, `LABELS` / `label_of` what the screen says. (DESIGN.md: "item_rarity.gd")
- **Gate Equip, and nothing else, on a piece's attribute** (`LootTable.requirement` past `NEEDS_FROM`; `Inventory.why_not_equip`): a worn piece keeps working when the points fall short. (DESIGN.md)
  - **Count the points without what the swap takes off** (`points_without(displaced)`, both dolls), so a piece never lifts itself; the heirlooms reach the player's through `keeper`, a `WeakRef` `stash()` sets.

### Modifiers
- **Build only legal candidates in `ModifierTable.pool_for`:** PERCENT needs `has_stat` and not `can_globalize` of that stat, FLAT `can_roll`, GLOBAL `can_globalize`. (DESIGN.md: "modifier_table.gd")
- **Pass a stone's `stone_tier` to every draw on it** (`Item.rolled`, the orbs, the super orbs, the fortuneteller's odds); a new line on a made piece is `Item.extra_mod`, which does. (DESIGN.md: "modifier_table.gd", "item.gd")
- **Make a line only with `ModifierTable.rolled_mod`:** it has a tier, 1 to the level its bands are read at, and `Item._set_tier` is the one place a line is put at a tier by hand. (DESIGN.md: "modifier_table.gd", "item.gd")
- **Write `line` and `band_line` through the same `_written`.** (DESIGN.md: "modifier_table.gd")
- **Read a made piece's bands at `Item.mod_level()`, never `item.level`,** and a line's tier with `item.tier_of(mod)`. (DESIGN.md: "item.gd", "Honour what a super orb leaves on a piece")
- **Call `Item.refresh_perfect()` from whatever moves `mod_level`.** (DESIGN.md: "item.gd")
- **Never open a modifier's line on a name** (the user's: "never start a line with <Name>:"): a `MODS` entry's `text` says what the line does, written by `_written`. (DESIGN.md)
  - **Keep `added_enemies` signed and never 0** (`range`, `wide` from `wide_from`; `reroll_value`, `band_for`, `rescaled`, `amount`).
- **Read `Inventory.ALL_ATTRIBUTES` only in `_points`:** added to each attribute there, counted as an attribute line, erased from `stats()`. The character page tables every other new stat (`CharacterPage.GROUPS`). (DESIGN.md)
- **Keep `ModifierTable.UNIQUE_ONLY`, empty as it is today:** `test_inventory` tells a unique's own modifier from a dead one by it, as it does `DORMANT`. (DESIGN.md)
  - **Never give a row a PERCENT and a GLOBAL on one stat:** they write the same sentence.

### Orbs, the smith and held lines
- **Write an orb's rule once, in `why_not`:** `can_apply` is it, empty, and `apply` refuses on it (`OrbTable`, `SuperOrbTable`, `RuneTable`). (DESIGN.md: "orb_table.gd")
- **Pass `Inventory.walls_ever()` to every source of orbs:** `OrbTable.unlocked(walls)` is which exist (the user's, 2026-10-03, permanent 2026-10-09); `EVERY_WALL` is the tests' default. (DESIGN.md: "orb_table.gd")
- **Reroll with a rarity orb from below or above:** an epic transmuted comes down to uncommon (the user's ruling, 2026-10-02). (DESIGN.md: "orb_table.gd")
- **Lean the shops on the drop rates, not on a table of their own** (`OrbTable.roll_favoured`). (DESIGN.md: "orb_table.gd")
- **Give every orb, ordinary and super, a `glow`** off its icon, in ENDESGA 64. (DESIGN.md: "orb_table.gd")
- **Craft only on a piece the bag page has open, carried or worn,** or, an orb in hand, on one still on a vendor's shelf (`craft_held`); crafted over a fight, it counts from the next blow (`main_scene._rearm`). (DESIGN.md)
- **Change nothing on a broken piece:** no orb, no upgrade, no lock (the top of `OrbTable.why_not`); it takes Mending and nothing else. (DESIGN.md)
  - **Keep a locked modifier through every orb** (`_reroll_at`, where rarity and count are settled, fills around it; Divine skips it); a lock is one of the rarity's handful, never an extra.
  - **Freeze a held-fast line (locked or bound) in number and band** (`Item.hold`, `"at"`): `ascend()` and the smith walk past it, only `transcend()` moves it.
  - **Never make a common with an orb,** so a locked piece is never a common.
- **Honour what a super orb leaves on a piece:** `_reroll_at` keeps `held_fast` lines and counts `extra_slot`; `reroll_values` steps over `held_fast` and `"perfect"`. (DESIGN.md)
  - **Keep the tier on a Divine and at the smith;** Perfection is the top tier's top.
  - **Refuse Replacement, Expansion and Binding on a unique.**
- **Spend super orbs only on `TranscendPage` and only on heirlooms,** one count for all six (`Inventory.super_orbs`). (DESIGN.md: "super_orb_table.gd")
- **Expect a +n piece as a drop:** `Item.ascend()` is the Orb of Ascension's act and what Lean Pickings does to a find, every modifier but a held-fast one kept in its place. (DESIGN.md)
- **Take `Item.ascension_cost()` Orbs of Ascension for the next plus** (the user's, 2026-10-03). (DESIGN.md: "item.gd")

### Uniques, achievements and ranks
- **Make a unique an `Item` with `unique` set:** `type` its base piece, rarity UNIQUE, its row's modifiers in the row's order, only the values rolled (`Item.rolled_unique`). (DESIGN.md)
  - **Apply only Orbs of Divine and Chaos to a unique** (`OrbTable.why_not`).
- **A lair's unique (`lair`) drops from its boss alone:** `UniqueTable.pool_for` leaves it out of every body's pool, `Achievements.is_unlocked` calls it unlocked, and it has no ranks. The Leafwrap is read in `Inventory._needs_waived`, the Hoardheart in `stats()`. (`Scenes/Combat/DESIGN.md`: "Boss lairs (2026-10-29)")
- **Drop a unique only once it is unlocked** (`Achievements.unlocked`), and only by luck after `UniqueTable.FIRST_UNIQUE_KILLS` but for the promised `FIRST_UNIQUE`. (DESIGN.md)
  - **Hand every source the list less what a fortuneteller has banished** (`FortuneTeller.dropping`): banished is still unlocked, and ends with the world.
  - **Do not take found for unlocked** (the user's ruling): an old save's finds must be earned again to drop.
  - **Never reset `achievements`, `achievements_new` or `tally`:** the player's, carried by `transcended()`.
  - **Add a count outside a fight only through `Inventory.tick`,** and check the achievements where `save_written` is said (`main_scene._check_achievements`, deferred).
- **Make every achievement one number reaching a need** (`Achievements.progress`: the larger of the tally and `state(inventory)`'s figure), `need` four numbers, one a rank. (DESIGN.md: "achievements.gd")
- **Ask `Inventory.gear_attributes()` for an achievement's attributes:** the gear's over both dolls, before any unique counts them. (DESIGN.md: "achievements.gd")
- **Save nothing in `Achievements.earn`.** (DESIGN.md: "achievements.gd")
- **Record streaks and wall feats for a tile fight only, never the dungeon** (`Achievements.record`); `kills` never counts the camp or the dungeon. (DESIGN.md: "achievements.gd")
- **Write a `hint` in words and no number;** a unique carries at most `MOST_MODS` modifiers, and the starters have no ranks. (DESIGN.md: "unique_table.gd")
- **Read a rank live, never write it onto an item:** every number a ranked rule reads is `UniqueTable.dial(id, key, rank)` (`Inventory._dial`, `Encounter._dial`, a card at `UniqueTable.ranks`). (DESIGN.md)
  - **Write a rank IV line on the card only once it is reached** (`Item.peak_text`, the user's call); its rule asks `_peak(id)` beside whether the piece is worn.
  - **Count gear as it is not on copies** (`_counted_dolls`).
- **Keep the starters' numbers in `Inventory` or the fight** (`SQUIRE_DAMAGE`, `COURIER_SPAWN`, `NOVICE_XP`; `Encounter.BEGINNERS_LUCK`). (DESIGN.md)
  - **Leave the Stat Stick (`wayfarers_torch`) the one unique with no rule** (the user's stat stick); `test_inventory` allows it for that id alone.
- **Tell the fight one `UniqueTable.effect_of` a worn unique** (`Equipment.effects()`), a home piece as `"home:<env>"`. The Pilgrim's set went on 2026-09-29 (the user's, "for now"). (DESIGN.md)
- **Carry what a unique asks of the player in `Inventory.stats()`:** the Spiked Helm's share goes in with the skill tree's flat damage, so the percents scale it. (DESIGN.md)
  - **Put the attributes through `attributes()` first** (both dolls, the Echo, the Crown, then the Brand); everything reads those counted points.
- **Only ever grow `uniques_found`** (`Inventory.note_unique`, beside each `add`: `FightLedger.add_loot`, `TownPage`). (DESIGN.md)
  - **Apply the collection bonus in `Inventory.stats()`, never in `Equipment.totals`:** its own multiplier after gear and skills.

### Two dolls, heirlooms and the end of a world
- **Wear two dolls at once: flats add, percents multiply** (`Equipment.totals`' `also`, whose globals are a multiplier of their own). (DESIGN.md)
  - **Count a stat, and anything that shapes the fight, over both dolls; a count and a set per side** (`Inventory._side_count`). The attributes are the one global count (the user's ruling, 2026-09-27).
  - **Ask the user when a new unique could be read either way; never guess.**
- **Make an heirloom only on `TranscendPage`, one a transcension:** a piece in `stash()`, marked by nothing but `safe_level`. Never back to the bag, never sold, discarded one at a time. (DESIGN.md)
  - **Work on copies in `transcended()`,** so a caller whose write fails still holds the heirlooms as they were.
  - **Carry through it the stash and its doll, unspent super orbs, `uniques_found`, `kills`, `tips`, and `first_sword_taken` forced true.**
- **Leave the count of heirlooms to `TranscendPage`;** `Inventory.make_heirloom` takes a bag piece or a worn one, never a broken one. (DESIGN.md: "inventory.gd")
- **Carry `play_seconds`, `hero_name` and the heroes (`owned_characters`, `character`) through a transcension; leave `runes` and `runed` with the world.** (DESIGN.md: "inventory.gd")
- **Buy and pick a hero only through `buy_character` / `use_character`** (`Characters` ids): one is bought once, and only an owned one is picked. A saved id the roster has not got is named in `lost`, and a pick not owned reads as the first. (DESIGN.md: "inventory.gd")
- **Use only `items` and `equipment` of `stash()`;** it keeps to `CAPACITY` where the bag asks `capacity()`. (DESIGN.md: "inventory.gd")
- **Climb only a whole heirloom, and only to `min(safe_level, land_level)`** (`Inventory.raise_heirlooms`). (DESIGN.md: "inventory.gd")
- **Keep `Inventory.curses` apart from `pending_curses`:** the first is the world's, the second only chosen, and `transcended()` is the one place the second becomes the first. (DESIGN.md)
  - **Ask `skill_worth()` what a skill point counts for** (`stats()`, `SkillCard.fill`); the capstones' effects are not doubled.
- **Spend a skill point through the inventory, never `skills`** (`why_not_skill(path)` / `rank_up_skill(path)`): the Specialist's branch is the inventory's to know. (DESIGN.md)
  - **Give Equip one reason to be dead:** `why_not_equip(item, socket)`, and `can_equip` is it, empty.
  - **Only ever grow `uniques_doubled`;** `collection_bonus()` is nothing under Forgotten.
- **Pay skulls only from Gollux** (the user's, 2026-10-03): `skull_allowance()` is `dungeon_depth` and nothing else, whole again in every world. (DESIGN.md)
- **Only ever raise `dungeon_floors`** (the leaderboard's score; the main scene's `_bank_depths`); carried by `transcended()`. (DESIGN.md)
- **Only ever raise `farthest_land`** (`reach(radius)`); carried by `transcended()`, it sets `SkillTree.root_slots` as it rises. (DESIGN.md)

### Skill stones, runes and walls
- **Treat skill nodes as items you cannot wear** (the user's, 2026-10-08): `LootTable.KINDS` rows of slot `stone` and weight 0, which the gear's draw, shelves and bounties pass by; their pools are `SkillTree.LINES`. (DESIGN.md)
  - **Read a node's bands at its item level, as gear's** (the user's, 2026-10-09); `stone_tier` is how deep it sits and which lines it may roll.
  - **Ask `ItemRarity.band(rarity, type)` how many lines a piece holds;** a stone has one a rarity step (`STONE_MOD_COUNT`).
  - **Refuse every orb on a capstone** (beside `broken` in `why_not`); orbs work on a stone as on gear.
  - **Never an heirloom** (`can_make_heirloom`).
  - **Spare a capstone wherever a unique is spared:** the bin, Sell all's question and autodiscard ask the rarity, not `unique`.
  - **Never add the tree's attributes at `skill_worth`,** and copy the tree but not its ranks in `transcended()`.
- **Never leave behind a unique or a capstone** (`Inventory.leaves_behind`); a skill stone answers by its rarity alone. (DESIGN.md: "inventory.gd")
- **Drop runes only in Gollux's cave; spend them only on a charted tile a farm run can be fought on** (the user's design, 2026-10-09). (DESIGN.md: "rune_table.gd")
- **Never touch a tile's own modifiers with a rune:** its rune work is one Dictionary (`RuneTable.fresh()`), each entry lasting `KILLS` kills on its own count; `pool` deals only rows a farm run feels. (DESIGN.md: "rune_table.gd")
- **Spend a rune only where it does something** (`Inventory.use_rune`; a refusal leaves no record); `rune_work(spot)` reads without keeping, `rune_state(spot)` keeps. (DESIGN.md: "inventory.gd")
- **Read every wall unlock off `Inventory.walls_ever()`** through `WallUnlocks` (the user's ladder, 2026-10-09), a camp's hours and the bag's room too (`camp_hours`, `bag_slots`, 2026-10-11); `walls_credited` is the super orbs' alone. (DESIGN.md: "wall_unlocks.gd", "inventory.gd")

### The bag
- **Never destroy gear to fit the bag:** anything over `capacity()` stays whole and makes the player `encumbered()`. (DESIGN.md)
  - **Read the bag level-major** (`order()`, pinned by `_test_bag_order`).
- **Hold a piece's place in the bag after an orb's lift** until the bag is shut or a town tab changes (`order(held)`). (DESIGN.md: "inventory.gd")
- **Move a piece only through `Inventory.equip` / `unequip`:** in the bag or a socket, never both. Both refuse on a full bag (`can_equip`); worn gear is outside `CAPACITY`. (DESIGN.md)
- **Ask `Equipment.displaced_by` what a swap costs:** the one answer for the tooltip, the comparison and `equip`, which returns exactly it. A two-hander closes the offhand. (DESIGN.md)
- **Keep gold and orbs out of `items`:** never capped, sorted or autodiscarded; a spent-out orb is erased, not left at zero. (DESIGN.md)
- **Ask `Inventory.sight()` for sight:** the map's and the character page's one answer. (DESIGN.md: "inventory.gd")
- **Never name `FortuneTeller` in `inventory.gd`:** `fortunes` is a plain Dictionary read through its statics. (DESIGN.md: "inventory.gd")

## Gotchas
- **Never mention `Item` in `ItemRarity`,** and never name another class's enum in a `const`: that is where Godot's cycle checker bites. (DESIGN.md)
- **Give an `Item` built by hand its `stats`** (tests do this), or it is worth nothing. (DESIGN.md: "Never move a rolled item's level or base stats")
- **Put a deep piece on a test fixture through `Equipment.equip`** when the test is about another rule. (DESIGN.md: "Gate Equip, and nothing else, on a piece's attribute")
- **Add a tally with `tick`, not `count`:** `Inventory` already had a `count(type)`. (DESIGN.md: "Drop a unique only once it is unlocked")
- **Expect Replacement to write a fresh dictionary,** so a perfected line replaced is perfect no longer. (DESIGN.md: "Honour what a super orb leaves on a piece")
- **Remember a two-hander costs the torch too,** so a greatsword charts one ring of map less. (DESIGN.md: "Ask `Equipment.displaced_by` what a swap costs")
- **Never ask the pool what a unique carries:** it may carry a line its base could never roll, and `effective_stats` applies by kind. (DESIGN.md: "Make a unique an `Item` with `unique` set")
- **Draw no border on the slot's `StyleBoxFlat`:** it is the socket only; the frame is `ItemRarity.frame(rarity, rank)`, null for common. (DESIGN.md: "item_rarity.gd")
- **Expect `LootTable.icon` to cache by path,** so the `Settings.show_old_icons()` tick shows at the next draw. (DESIGN.md: "loot_table.gd")
- **Treat `RuneTable.icon(rune)` as a stand-in:** the crystal mark tinted its `glow`, made once. (DESIGN.md: "rune_table.gd")
