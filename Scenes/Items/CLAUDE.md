<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Items/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Items (`Scenes/Items/`)
Every kill rolls for gear (about one body in thirty), always hands over gold, and rolls separately for an orb. Every drop is its own `Item` with a rarity, a level and modifiers; nothing stacks. **Read `DESIGN.md` here before changing what stats, modifiers, rarities or orbs mean** -- it holds the why.

| File | Contents |
|---|---|
| `loot_table.gd` (`LootTable`) | `ITEMS`: the eight pieces (sword, shield, armour, helmet, boot, torch, ring, amulet) with icon, weight, `slot`, and three lists: `stats` (what it shows; all a PERCENT mod can scale), `affixes` (stats it may roll a FLAT mod for), `globals` (stats it may roll a GLOBAL percent for; jewellery only). `chance_for` = `TIER_CHANCE * SIZE_CHANCE`, lifted by `drop_rate`, capped at 1. `roll(enemy, rng, guaranteed, tile_level, drop_rate)` gives `null` or an `Item`. `scale(stat, value, level, flat)` with `LEVEL_GROWTH` / `LEVEL_FLAT` is the one place a level touches a number. `STAT_LABELS`, `stat_line`, `stat_delta`, `delta_shows` are the one place a stat is spelled |
| `item_rarity.gd` (`ItemRarity`) | The five steps (common, uncommon, rare, elite, unique), per-tier weights out of 1000, `MOD_COUNT`, both colour ramps, the slot `StyleBoxFlat`, `LEVEL_FLOOR` / `roll_level`, `weights_for(rarity%)` |
| `modifier_table.gd` (`ModifierTable`) | The pool and the four kinds: `PERCENT` (needs `has_stat`), `FLAT` (needs `can_roll`), `GLOBAL` (needs `can_globalize`), `PLAYER` (fits anything, applied by nothing yet). `pool_for` builds only legal candidates; `roll` draws without replacement. `DORMANT` names the resistance mods nothing can roll. `level_flat` on an entry overrides the stat's own level step |
| `equipment.gd` (`Equipment`) | What is worn. Eight `Socket`s; `TAKES` joins a socket to an item `slot` (rings fit either hand, shield and torch share the offhand). `sockets_for(item)` puts the emptiest first. `totals(flat, percent)` adds every piece's `effective_stats`, then applies the set's GLOBAL percents once |
| `item.gd` (`Item`) | type, rarity, level, rolled `stats`, `mods`. `effective_stats()` = flat mods added, then percent mods scaling. `global_percents()` feeds `Equipment.totals`. `to_dict` / `from_dict` are the save |
| `orb_table.gd` (`OrbTable`) | The eight orbs in tray order (`ORBS`), and `can_apply` / `apply` / `why_not` as three branches of one `match`. `_reroll_at` is where rarity and modifier count are settled. Drop chance has `LootTable.chance_for`'s shape; weights are flat with no depth gating |
| `inventory.gd` (`Inventory`) | `items`, `equipment`, `gold`, `orbs` (name -> count), `kills`, `level` / `xp`, `skills`, `tips`, `first_elite_taken`, `autodiscard`. `CAPACITY` 40 loose items; `add` appends then `trim`s and returns what was destroyed. `equip` / `unequip` move a piece as one step. `order()` reads the bag, `worst_first()` empties it. `stats()` is what a fight is armed with. `save(path)` goes through `SafeFile`; `load_from(path, problem)` migrates old versions |

## Rules and gotchas
- **An item's level and base stats are frozen when it is rolled** and saved with it; only an orb changes a held piece, and only its rarity and modifiers. An `Item` built by hand (tests do this) must be given `stats` or it is worth nothing.
- **Crafting happens only from the bag,** where no fight is holding a second reference to the same `Item`.
- **`LootTable.scale` is the only place that knows what a level does.** PERCENT and GLOBAL mods take the multiplier only, PLAYER mods take neither, `CHANCE_STATS` (crit, block, dodge, drop rate) take the flat step only, and a FLAT mod may name its own step (`level_flat`).
- **A tile's level is a ceiling, not a payout:** a drop rolls evenly up to `level_of(cell) + TIER_LEVEL[tier]`, with rarity lifting the floor. Balance numbers describe a piece at the ceiling.
- **`stats`, `affixes` and `globals` must not overlap,** and every affix needs a FLAT mod naming it and every global a GLOBAL one, or it is unreachable. `test_inventory._test_items` fails on all of it. `_test_slot_locks` pins which stats are locked to which piece.
- **A GLOBAL mod is applied by `Equipment.totals`, never by `Item.effective_stats`,** and two of them add rather than compound.
- **Increased item rarity lifts weights, it does not add steps;** a zero weight stays zero, so UNIQUE cannot drop. A test holds that.
- **The resistances are off every piece on purpose** (nothing can hurt the player). Their labels, steps and mods stay written down; `DORMANT` is how a dormant mod is told from a dead one.
- **`order()` is level-major and `worst_first()` is rarity-major; they are not each other reversed.** `_test_bag_order` pins both.
- **A piece is in the bag or a socket, never both:** always go through `Inventory.equip` / `unequip`. `unequip` refuses on a full bag. Worn gear is outside `CAPACITY`.
- **Gold and orbs are not in `items`:** never capped, trimmed, sorted or autodiscarded. A spent-out orb is erased, not left at zero.
- **Every modifier value is a whole number,** so saves hold `14` not `14.0` and round-tripped items compare with `==`. Stats are stored as the number they display.
- **Names, not enum positions, go on disk** (rarities, sockets, orbs). A retired item, mod, orb or ill-fitting socket is dropped on load rather than guessed at.
- **`Inventory` never saves itself** and the path is always a parameter, so tests never touch the player's save. A file that is there and cannot be honoured comes back empty **with a reason in `problem`**, and the caller must then never save over it.
- **`ItemRarity` must never mention `Item`,** and a `const` must not name another class's enum: that is where Godot's cycle checker bites.
