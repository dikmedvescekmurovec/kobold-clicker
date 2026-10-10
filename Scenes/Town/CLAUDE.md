<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Town/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Towns (`Scenes/Town/`)
What a settlement is for: which counters it has, what everything over them costs, what work it has posted, and what the player has left behind in each one. All rules classes, static or node-free like `OrbTable`, so the tests need no interface.
**Read `DESIGN.md` here before changing what a town offers, what a price means or how the page and the bag share the window** -- it holds the why. The page itself is `Scenes/UI/town_page.gd`.

Each file's functions and dials and each rule's full text: the end of `DESIGN.md`, "Reference (moved here from CLAUDE.md on 2026-10-10)". A rule's `(DESIGN.md: "...")` names its heading there.

## Files
| File | Contents |
|---|---|
| `town_services.gd` (`TownServices`) | Which counters a settlement has, by its tier and world spot, and what each counter is called. |
| `town_prices.gd` (`TownPrices`) | Every price, quoted in bodies: a piece sold or bought, the smith's work, an orb, a shelf's reroll, the fortuneteller's readings. |
| `blacksmith.gd` (`Blacksmith`) | What the fortress smith does to a piece: an upgrade that may break it, and a lock on one modifier. |
| `town_state.gd` (`TownState`) | What the towns the player has walked into hold: one drawer per world spot, saved as `inventory.towns`. |
| `bounty_board.gd` (`BountyBoard`) | The work a settlement has posted: postings, the accepted one and its kills, the hand-in, the board's tier, a cleared board's options. |
| `fortune_teller.gd` (`FortuneTeller`) | What the fortuneteller can be asked: readings, great spells, the way out, the banishing. Also the key and reader of `inventory.fortunes`. |
| `vendor_stock.gd` (`VendorStock`) | What a vendor has on its shelf: the first stocking, bought squares, paid rerolls and the favourable item roll. |

## Rules

### Shape and saves
- **Key by world spot.** Never by map cell: `TownState.key` is `"x,y"`; cross a cell over with `MapBuilder.town_tier(cell)` and `view.origin + cell`. (DESIGN.md: "Key by world spot")
- **Derive services, write stock down.** Counters are a pure function of tier and spot; anything rolled goes in `TownState` -- never re-derive a shelf from a seed, and a caller must not roll one of its own. (DESIGN.md: "Derive services, write stock down")
- **Never read a drawer in `TownState`.** Whoever puts something there knows its shape. (DESIGN.md: "town_state.gd")
- **Use a town only when it can be visited.** `MapBuilder.can_visit(cell)`: charted, standing on it, not walking. (DESIGN.md: "Use a town only when it can be visited")
- **Write what she sells where it belongs.** Bought readings go in the town's drawer (`ASKED`); `inventory.fortunes` is only the player's own (the chest's world spot, the spent scour), read through `FortuneTeller`'s statics -- `Inventory` never names `FortuneTeller`. (DESIGN.md: "Write what she sells where it belongs")
- **Ignore an old save's retired keys:** `cast` (no count since 2026-10-01) and `peeked` (the Relic reading, removed 2026-09-28). (DESIGN.md: "fortune_teller.gd")
- **Read an old posting, skip an unreadable one.** `bounties` reads an older save's one `orb` name as a list; `item_of` and `choice` drop what this build cannot read. (DESIGN.md: "bounty_board.gd")

### Counters (`TownServices`)
- **Give every settlement the fortuneteller.** `services_for`, in `ORDER`: a village is the board and one vendor (`hash([seed, spot, "vendor"])`), a town the board and both, a fortress adds the smith. (DESIGN.md: "town_services.gd")
- **Name a counter only through `label(service)`.** No town (-1) offers nothing; any other tier without counters is a logged error. (DESIGN.md: "town_services.gd")

### Prices (`TownPrices`)
- **Quote prices in bodies.** Never write a gold figure here: retuning `Encounter.BASE_GOLD` or `GOLD_GROWTH` has to retune the shops with it. (DESIGN.md: "Quote prices in bodies")
- **Leave prices to the user.** Tuned by hand (the balance table is gone); the dials and where they last stood are in DESIGN.md only. (DESIGN.md: "Leave prices to the user")
- **Price a piece at its own level.** `sell_price`, `upgrade_price`, `lock_price`; an orb, a reroll and a reading go by the town's (`orb_value`, `reroll_price`, `fortune_price`). (DESIGN.md: "Price a piece at its own level")
- **Derive `buy_price` from `sell_price`.** Divided by `SELL_SHARE`, never a second figure, so no counter is a loop. (DESIGN.md: "Derive `buy_price` from `sell_price`")
- **Never buy an orb back.** Bought, never sold back. (DESIGN.md: "town_prices.gd")
- **Price the way out and a banishing on fixed ground.** `transcend_steps()`, the same in every town and world, and `transcend` is never cast twice. `banish` is that times `FORTUNE_GROWTH` per one paid for in this world; nothing else passes `cast` to `fortune_price`. (DESIGN.md: "town_prices.gd")

### Vendors (`VendorStock`)
- **Stock a vendor only on the way in.** `TownPage.open` and nowhere else; a bought square stays empty until that shelf's Restock is paid for -- no free restock, no kills clock. (DESIGN.md: "Stock a vendor only on the way in")
- **Never reset a reroll count.** Each costs `REROLL_GROWTH` times the last, for the whole playthrough (`rerolls`). The gear and orb shelves count and reroll separately, and paying never touches the board. (DESIGN.md: "Never reset a reroll count")
- **Never add to a full bag.** No `Inventory.add` past the cap: the Buy is refused, greyed, with the reason in its tooltip. (DESIGN.md: "Never add to a full bag")
- **Roll a shelf piece the favourable way.** `roll_item`: under `ceiling(cell, tier)`, never `COMMON_REACH`, at the rarity tier above the town's rabble. The level is rolled first and handed to `LootTable`'s draw, so no vendor deals a material that level has not unlocked. (DESIGN.md: "vendor_stock.gd")

### The bounty board (`BountyBoard`)
- **Keep no clock on the board.** `restock` is refused until `cleared`, and is asked on the way in and again at each Claim. (DESIGN.md: "Keep no clock on the board")
- **Allow one bounty at a time.** `accept` is refused while any posting anywhere is accepted and not yet handed in (finished is not enough); `count_kill` moves that one posting and nothing else. While it is out a board shows it first, the rest dimmed, Accept grey. (DESIGN.md: "Allow one bounty at a time")
- **Count a kill through `FightLedger.add_kill`, never from the interface,** and only on a tile of the town's level or deeper (`FightLedger.tile_level`, set by the main scene). `see` only puts the journal in the corner. (DESIGN.md: "Allow one bounty at a time")
- **Post only reachable targets.** `restock` posts only what lives on the `envs` handed in: never the mimic, never a boss, nothing where there is no land. It asks `MapBuilder` for nothing but a cell's level (`level_of`). (DESIGN.md: "Post only reachable targets")
- **Hand a bounty in where it was posted.** Once: `claim` refuses a posting not `ready` or already `done`, and it keeps its square, spent, until the whole board is cleared. (DESIGN.md: "Hand a bounty in where it was posted")
- **Put a promised piece in the bag by the vendor's own rule** (`_why_not`): over a full bag the Claim is greyed and pays nothing. Emit `item_claimed(piece)` before the log and the bag hear of it; the Claim also banks the XP (`TownPage.xp_claimed`). (DESIGN.md: "Hand a bounty in where it was posted")
- **Keep a posting's `item` a promise, not a piece.** Rolled at posting (`_item_promise`), paid by `reward_item` at the hand-in: what the piece is exactly is written nowhere before it is in the bag. (DESIGN.md: "bounty_board.gd")
- **Call `clear` before `restock`.** It writes `CHOICE` at the old tier and counts the clear, and is refused on a board with work out or nothing posted. (DESIGN.md: "bounty_board.gd")
- **Write a cleared board's options down.** Rolled whole at the clear and kept in the drawer until `take_choice` returns one and erases the rest: closing the game, the X or a full bag never loses or rerolls them. (DESIGN.md: "Write a cleared board's options down")
- **Never share a board's tier between towns.** `board_tier(drawer)` is 1 + `CLEARS`, that town's own record, up to `BOARD_TIERS`. (DESIGN.md: "Write a cleared board's options down")
- **Draw the options by the rng, never `shuffle`.** `roll_choice`: `CHOICES` different kinds, an `ORB_BUNDLE` only of orbs `OrbTable.unlocked(walls)` and none while none is. Lucky is rolled again and the better kept (`_lucky`). (DESIGN.md: "bounty_board.gd")

### The smith (`Blacksmith`)
- **Let only the smith raise a level.** The one exception to "a piece's level and base stats never change" (`Scenes/Items/CLAUDE.md`), paid for by `BREAK_CHANCE` on every upgrade and a cap. (DESIGN.md: "Let only the smith raise a level")
- **Cap an upgrade at `MapBuilder.circle_level(town cell)`.** Per wall circle, not per tile level (the user's call, 2026-09-28; no boss's `TIER_LEVEL` on top since 2026-10-03, the user's). The caller hands the cap in: `Blacksmith` never names the map. (DESIGN.md: "Let only the smith raise a level")
- **Leave modifiers alone on an upgrade.** Every tier and number stays as it was (`Item.level_up`); a perfected line goes to the new top, an heirloom's climbs back towards its `"peak"`. (DESIGN.md: "blacksmith.gd")
- **Let the smith pick the locked modifier, at random.** `BROKEN` is the sentence both refusals share. (DESIGN.md: "blacksmith.gd")
- **Hold an heirloom up from its own page,** which the crown swaps in at the counter (`main_scene._counter_page`). The ground's cap holds for it too, and `can_upgrade` refuses one under its `safe_level`. (DESIGN.md: "Hold an heirloom up from its own page")
- **Let the smith work on a worn piece.** `_smith_why_not` refuses only what `Blacksmith` refuses and a purse that is short. (DESIGN.md: "Hold an heirloom up from its own page")
- **Keep broken final and locked forever.** Broken: no orb, no upgrade, no lock, a lower `sell_price`. Locked: survives every orb (`OrbTable`), only ever one to a piece. (DESIGN.md: "Keep broken final and locked forever")

### The fortuneteller (`FortuneTeller`)
- **Sell a great spell once a settlement.** `GREAT` is refused in a town that has cast it (`asked`); `COMMON` is sold as often as it is paid for, at the same price (no doubling since 2026-10-01, the user's call). (DESIGN.md: "Sell a great spell once a settlement")
- **Refuse the roads where they were bought:** they write the same drawer key. They show settlements with the land `ROADS_RADIUS` round each, and no directions (since 2026-09-25). (DESIGN.md: "Sell a great spell once a settlement")
- **Charge a great spell on the map.** `TownPage` only emits `spell_aimed`; the main scene charges and writes the drawer key only when the spell did something, and Escape and the panel's X cost nothing. (DESIGN.md: "Charge a great spell on the map")
- **Point Treasure at an unseen chest.** Only ever: `MapBuilder.nearest_chest(true)`. (DESIGN.md: "Point Treasure at an unseen chest")
- **Never appraise a unique.** `why_not_appraise` refuses it. (DESIGN.md: "fortune_teller.gd")
- **Draw her spells as two grids,** squares the way a shelf is (`TownPage._spell_square`): price under the mark, name only in the tooltip, greyed in place with the reason. The way out keeps its word and the full width under both. (DESIGN.md: "Draw her spells as two grids")
- **Ask before transcending, never charge.** Listed only once `MapBuilder.walls_fallen()` is above 0; its square among the great spells only asks (`TownPage._ask_way_out`), nothing is deducted, and it is never marked `ASKED`. (DESIGN.md: "Ask before transcending, never charge")
- **Never say what waits.** Her question is a warning in her own voice (`TRANSCEND_LINES`; the user's rule). (DESIGN.md: "Ask before transcending, never charge")
- **Write a transcension only on leaving `TranscendPage`.** `main_scene._on_transcend_pressed` checks the purse and fades to it; only leaving it writes `inventory.transcended()`, deletes the map and reloads. (DESIGN.md: "Ask before transcending, never charge")
- **Offer the banishing only once `BANISH_FROM` uniques are unlocked** (the user's, 2026-10-10). The dev's `Settings.banish_unlocked()` lifts that and nothing else. (DESIGN.md: "fortune_teller.gd")
- **Keep a banished unique out of every draw.** And nothing else: `dropping` goes in `Achievements.unlocked`'s place to the fight (`main_scene._open_fight`), a bounty's promised unique and a cleared board's options (`TownPage._dropping`), and is asked nowhere else. (DESIGN.md: "Keep a banished unique out of every draw")
- **Count a ban from the next fight opened.** Options already written in a drawer stay as rolled, and both keys go with the world. (DESIGN.md: "Keep a banished unique out of every draw")
- **Keep the banishing's floor.** `BANISH_LEAVES` in `why_not_banish`: `BountyBoard.reward_item` and `roll_choice` index straight into the dropping list. (DESIGN.md: "Keep a banished unique out of every draw")
- **Pay for a banishing on the page, never mark it `ASKED`.** `banish` counts one more paid; `restore` brings one back for nothing and leaves the count. (DESIGN.md: "Keep a banished unique out of every draw")
- **Sell nobody the cave's hot and cold.** `warmth(steps)` is `CaveSense`'s, read every frame; a save's `seeing_stone` is ignored (the Seeing Stone went on 2026-10-03). (DESIGN.md: "Sell nobody the cave's hot and cold")

## Gotchas
- **Never name `Inventory` in `TownState`:** Godot's cycle checker bites. For the same reason `TownPrices.RARITY_MULT` is a list in `ItemRarity.Rarity`'s own order, not a `const` naming another class's enum. (DESIGN.md: "Never name `Inventory` in `TownState`")
- **Write `FORTUNE_BODIES`' keys as literals,** never `FortuneTeller`'s consts (the cycle checker again). `test_town` holds them to `LABELS`, and `COMMON` + `GREAT` + `TRANSCEND` + `BANISH` to `READINGS`. (DESIGN.md: "Write `FORTUNE_BODIES`' keys as literals")
- **Ask `can_upgrade` before charging.** `upgrade` returns false for a break as well as for a refusal, and the gold is spent either way. (DESIGN.md: "Ask `can_upgrade` before charging")
- **Write a shelf piece back with `VendorStock.put`.** `items(drawer)` hands out fresh `Item`s, so an orb spent on a shelf piece survives only through `put`. (DESIGN.md: "vendor_stock.gd")
