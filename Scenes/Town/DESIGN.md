<!-- The long-form design notes for this folder: why things are the way they are. Not loaded automatically -- Scenes/Town/CLAUDE.md holds the short rules and points here. -->

# Towns

A settlement used to be nothing but a harder fight -- the `SETTLEMENT` profile with a boss on the end -- and gold had exactly one sink, the skill reset. A charted town is now somewhere to go with the bag full: sell what has piled up, and later buy, upgrade and take bounties. What follows is the reasoning behind the shape of it; the short rules are in `CLAUDE.md` beside this file.

## Tiers, and why a village is not a small town

The three tiers already exist on the map and already look different, so they are what the counters hang off rather than a second table nobody can see from the map: a **village** has a bounty board and **one** vendor, a **town** has the board and both vendors, a **fortress** has all of that and a blacksmith. That makes walking further mean something specific rather than meaning "bigger numbers", and it makes the fortress on the far side of the map a destination rather than a harder tile.

Which vendor a village gets is drawn from the world seed and the village's own spot. Two villages a day apart are not the same errand, and because it is drawn rather than rolled there is nothing to write down and nothing to migrate: walking back finds the same counter forever. That is the line this folder draws everywhere -- **what a town *is* is derived, what a town *has done* is written down**. The counters are derived. The stock a vendor rolls, and the bounties a board issues, are rolled, and so they go in `TownState` with the names and the town world, for the same reason those do: "a pure function of the seed" is a property of today's tables and not a promise to the player.

## One save, one write

Town state lives inside `inventory.json` as `inventory.towns`, the way `skills` does, rather than beside the map. A purchase moves the purse, the bag and a town's shelf in one act, and two files is two ways for them to disagree about whether it happened. `Inventory.VERSION` goes 9 to 10 and an absent `towns` key reads as no settlement walked into yet, which is exactly what every save written before there was anything in a town to do actually means.

`TownState` is keyed by **world spot** rather than by map cell, because a cell is a place in the drawn window and the window grows as the player travels. It is written `"x,y"` because JSON object keys are strings and a `Vector2i` stringified by Godot is not something to hand a save file.

## Everything is priced in bodies

`TownPrices` is the only place a price is made, and every price is a **number of bodies' worth of gold** times a named dial. The unit is `gold_at_level(level)`: what an ordinary common body on the *first tile of that level band* is carrying, which is `Encounter.gold_at_steps` at the nth triangular number of steps (`MapBuilder.level_of` inverted). `Encounter.base_gold` was split into `gold_at_steps` for this, so the tile's purse and the shop's prices come out of one curve and retuning `BASE_GOLD`, `GOLD_PER_STEP` or `GOLD_GROWTH` retunes the shops without anybody remembering to.

The consequence worth stating: **nothing here ever writes a figure in gold.** A price says "three bodies" and the gold follows from wherever the player is standing.

A **piece** is priced at its own level and an **orb** at the town's. A find carried home from the frontier is worth what it is worth, and selling it back at the village you started at should not punish the walk. An orb has no level at all -- it is a count, like gold -- so the only thing that can make one worth more is where it is being sold, which is also what keeps the deep towns worth reaching.

An orb's price is **inverse to how often one drops** (`OrbTable.ORBS[orb].weight` against the commonest weight), so the Exalted orb nobody sees is worth eight Transmutation orbs and there is no second table of orb values to keep in step with the drop rates. Tuning the drop rate tunes the price.

The dials, and what they were set to and why:

- `SELL_BODIES` **3.0** -- a common piece at its own level fetches three bodies. A full bag of forty at the level being fought is worth a couple of minutes' farming: enough that the walk to town pays, never enough that farming *for* the gold beats farming for the gear. The gear is the prize; the gold is what is left of the gear you already have.
- `RARITY_MULT` **1 / 2 / 5 / 14 / 24** -- climbing far faster than the modifier count does, about two and a half times a step.
- `ORB_BODIES` **4.0** -- what the commonest orb is worth to *buy*; everything rarer climbs off it. At a level-5 town that is a Transmutation orb at 136 gold and an Exalted at 1088.
- `SELL_SHARE` **0.20** -- a vendor pays a fifth of what it asks, so buying back what you just sold costs five times what it paid and there is no loop to stand in at one counter. It is the same share for gear and for orbs, because a player who has to remember two spreads has been given a spreadsheet rather than a shop.

The share is also the whole of what a **buy** price is. `buy_price` is `sell_price` divided by `SELL_SHARE` rather than a figure of its own, exactly as an orb's sell price is `SELL_SHARE` of what a vendor asks for one. One number decides both directions, so there is no way to tune them apart and wake up with a town that prints money -- and the arithmetic comes out where it should: a common piece at its own level is three bodies to sell and fifteen to buy, an elite fourteen times that again. At the village five tiles out that is a few hundred gold for something plain off the shelf, which is a tile fight or two; ten bands deep it is six figures, and so is the purse by then, because both are the same curve.

## The balance pass, and what the table said

Nothing above is guessed at any more. `tests/balance_town.gd` prints, for tile levels 1, 3, 5, 8 and 10, what the ground pays against what a town asks -- one body, one tile fight, a hundred kills, what the gear and orbs of those hundred kills fetch, every price on every counter, and all of it again in the only unit a player has, which is **tile fights**. It reads the live tables (`Encounter.gold_of`, `LootTable.chance_for`, `OrbTable.chance_for`, `TownPrices` itself), so it cannot drift from what the game charges, and it is not named `test_*` because a table is not a verdict.

Because every price is bodies and every purse is the same curve, almost every row is **flat across the map**: a shelf common is 1.5 fights at level 3 and 1.5 fights at level 10. That is the whole point of quoting in bodies, and it is what lets three numbers be judged once rather than five times.

What the first run said, and what moved:

- **Selling was already a side income and stayed one.** A hundred kills turn up 3.6 pieces and 5.7 orbs; sold, and counting the rares and elites nobody actually sells, they come to 39% of that run's purse at level 1 and 23% at level 10. Keeping rare and better -- which is what a player does with them -- it is **20% falling to 13%**. Under a quarter, tapering with depth, and never close to the gold the bodies handed over directly. No dial moved for this.
- **An orb was creeping up on a piece of gear.** At the old `RARITY_MULT` a rare at the town's own level fetched 7.8 bodies and an Orb of Exalted fetched 8 -- so the rarest currency in the game was worth more than the find of the afternoon, and the temptation was to farm orbs for gold rather than craft with them. With the ramp below, a rare at the town's level is 15 bodies against the Exalted's 6.4, and every other orb is further behind. The orbs are back to being what you spend.
- **`RARITY_MULT` 1 / 1.6 / 2.6 / 4.2 / 7 -> 1 / 2 / 5 / 14 / 24.** The row that forced it was the shelf: an elite off a vendor cost **5 tile fights**, which is not a decision, it is pocket change. The same dial sets what a sold piece fetches and what a bought one costs, so steepening the top of the ramp is the one move that makes the good end of a shelf an errand (**21 fights** for an elite, 7.5 for a rare) without touching the common end that a bag is emptied at. It cost some sale income -- the rare and elite drops fetch more too -- which is the other half of why `SELL_SHARE` moved.
- **`SELL_SHARE` 0.25 -> 0.20.** The only dial that moves the two directions *against* each other: a shelf gets a quarter dearer while a bag of finds fetches a fifth less. It took the shelf's plain end from 1.2 fights to **1.5**, its elite end to 21, and put the sell-everything share back under 40% at level 1 and 23% at level 10. "Five times what it fetched" is no worse to remember than four, and it is still one number for both counters and both goods.
- **`LOCK_BODIES` 500 -> 2500.** The table caught this one outright: 500 bodies is **50 tile fights**, at every level, including the 3.77 million at level 10 that reads enormous and is four sessions' farming. A lock is meant to be the one thing in the game that cannot be rolled away and the largest sink there is; 2500 bodies is **250 fights** (18.9 million at level 10, 2500 at level 1), which is a season rather than an afternoon, and still reachable at any depth because the purse at the deep end of a band pays three times what its first tile does. It is no longer "twenty-five upgrades" -- the ratio was rhetoric, since no piece can be walked twenty-five levels -- it is simply the biggest number in the game.
- **`UPGRADE_BODIES` 20.0 stayed.** Two tile fights a level at every depth, which is exactly "affordable every few fights at the piece's level", and a fifth of what a plain elite costs off a shelf.
- **`BREAK_CHANCE` 0.05 stayed.** Twenty upgrades to a break is forty fights' gold gambled before the hammer is expected to land wrong, and a piece walked five levels has survived five real chances at 77%. Nothing in the table argues with it.
- **`RESTOCK_KILLS` is gone** (see "A shelf turns over when it is paid for" below); the table's hundred-kill session is still the unit a run is measured in.
- **`NEED_COMMON` 24, `NEED_ELITE` 5 and `REWARD_MULT` 3.0 stayed.** A common posting pays **5.4 fights' purse** for 24 bodies, which is 2.7 fights of fighting; an elite posting pays 4.9 fights' purse plus an orb for five elites, which come round once a fight. So a board roughly trebles what those same bodies paid on their own and never approaches a shelf's prices, which is where a bounty belongs: worth going out of the way for, never a better living than the fighting itself. The elite posting is dearer in kills than the common one, and that is fine -- the three postings are worked off by the same walk, and the elite one is the only thing on the board that pays currency.

## What a vendor has, and why it is worth gold

A shelf is six things. Six is small enough that every square can be read at a glance and large enough that walking to a town is a choice rather than a look, and it is the same six for gear and for orbs so that a counter is a counter whichever one you are standing at.

What makes the shelf worth its five-times price is that it is **luck you would otherwise have to farm for**, and it is made out of the drop tables rather than out of a second set of numbers:

- the **type** is `LootTable`'s own weights, so a shop deals in the same kinds a body does and the amulet is as rare on a shelf as it is on the ground. The level is settled first and handed to the draw, so the materials a shelf offers are gated exactly as the ground's are: no counter hands over a Steel Helm at a level that could not have dropped one;
- the **rarity** is rolled at the tier *above* the rabble that walks around the town -- a village trades as well as its elites do, a town and a fortress as well as a boss does. So a vendor is a better class of luck rather than a different game, and tuning `ItemRarity.TIER_WEIGHTS` tunes the shops with it;
- the **level** is the better of two rolls under what that tier could drop on that ground. It lifts the middle of the band without ever passing the ceiling the ground sets, which is what keeps a shop from walking a player past the frontier -- the same rule the blacksmith's cap will obey.
- an **orb** is two draws of the ordinary drop table with the rarer kept. What a shop is for is the orb nobody has seen fall, and doing it by drawing twice means the orb rates stay the one place an orb's rarity is written down.

Stock is **written down, never re-derived**. A shelf is rolled, and the project's rule for rolled things is that they go in the save: what a vendor happens to have is not a property of the world, it is something that happened to the player, and a later build's tables must not quietly restock a town they have already walked out of. It lives in that town's own drawer in `TownState`, so a purchase moves the purse, the bag and the shelf in one write.

**A shelf turns over when it is paid for, and at no other time.** It first restocked itself every hundred kills, and the user took that out with the board's clock: a number of kills is arbitrary, and with Restock on the page there were two answers to "when is this shelf new" where one does. So the shelf is filled **the first time a town is walked into** and then only by Restock, whose doubling price is the whole brake. It still cannot change while it is being looked at except by the player's own press. A bought square stays on the shelf with nothing on it until then, which says "you bought that" where closing the gap would have said "there were only five".

## The smith, and the two things he is for

A fortress is the only settlement with one, which is the whole of what makes the deep map worth walking to once the vendors have stopped being interesting. He does two things, and both of them are about a piece the player already has rather than about getting another one.

**Upgrade** raises a piece's level by one and rewrites its base stats to exactly what a fresh roll at that level would have carried (`Item.scaled_stats`). That makes him the one exception to the oldest rule in `Scenes/Items/`, that a piece is frozen when it is rolled -- and the exception is the point: the whole game up to here has been "find a better base and start again", and the smith is the answer to the elite sword with the perfect modifiers that is four levels behind the frontier. The **modifiers keep the numbers they rolled**, at the level they rolled them, which is what leaves the Divine orb a job: an upgraded piece is a good piece at the right level with stale rolls on it, and that is a thing to spend currency on rather than a finished article.

The upgrade **can break the piece**, one time in twenty. That is what stops the smith being a gold-for-levels machine with nothing to think about: a piece walked five levels is a piece that survived five real chances of ruin, and it is worth something for that reason as much as for its numbers. A break is deliberately not a loss of the piece -- it is still worn, still sold, and simply never changed again -- because destroying what the player was carrying would make the button one nobody presses. There is no safer, dearer upgrade to buy instead: two buttons would turn every press into a sum, and the whole of the design here is a press you can make without one.

The **cap** is `level_of(town cell) + LootTable.TIER_LEVEL[BOSS]`: what a boss on that ground could drop, which is the ceiling a vendor's shelf already rolls under. So no counter in a town can walk gear past the frontier the player has actually fought their way to, and the fortress deep in the map is worth reaching for that reason as well as for its shelves. The cap is handed to `Blacksmith` rather than worked out in it, because what a level means on a map is the map's business.

**Lock** pins one modifier to a piece for good: every orb then rerolls around it and Divine steps over its value. No orb takes a piece down a rarity, so a locked piece is never a common, which would be a contradiction in `ItemRarity.MOD_COUNT`. The locked line is one of the rarity's handful and never an extra on top, so the ceilings all still hold -- which is what keeps a lock from being a back door to a seven-modifier elite.

Two decisions make the lock what it is. The **smith picks the modifier, not the player**: being able to choose would make a lock the last step of every craft, a tidy way to finish a piece off, and what it is meant to be is a bet on the line that came up. And it is **extremely expensive** -- `LOCK_BODIES` 2500 against `UPGRADE_BODIES` 20, which the balance table puts at 250 tile fights against two. A locked modifier is the only thing in the game that cannot be rolled away, and if every piece ended up carrying one the orbs would stop meaning anything. Locking never breaks: paying that and losing the piece to a coin toss is not a risk, it is a mugging.

Both prices are `gold_at_level(item.level)` times their dial -- the piece's own level, like `sell_price`, so the quote on the button is read against the piece in front of the player, and so that walking a piece up the map gets dearer with every step the way the ground it is walking towards does. At level 5 that is 680 gold to upgrade and 85,000 to lock; at level 10, 150,880 and 18,857,500, against an elite of the same level that sells for 316,806 and costs 1,584,030 off a shelf. Those are the figures the balance table is read against, above.

He acts on the piece **the bag has open** (`BagPage.selection_changed`), never on a worn one: the crafting rule the orb tray has always obeyed, for the reason it has always obeyed it -- the bag is where no fight and no socket is holding a second reference to the same object. His tab is the only counter with no shelf, so it is the piece's name, the two prices with a coin on each, what the hammer would make of it, and the reason a button is grey in that button's tooltip. A break is the one thing that happens on that page the player did not ask for, so it is said out loud in rust as well as written into the piece's own stat block, where "Broken" stands under its rarity and reads the same in the bag, in the comparison, over a drop and on a shelf.

## The board, and the one thing it is really for

Every settlement has one, and it is the only counter that is not a shop. What it is for is not the
gold: it is that **it says where the monsters are**. Up to here the map has been a thing to uncover
and a fight has been a thing that happens on the tile in front of the player, and nothing in the game
has ever answered "where do I go next". A posting saying "twenty-four goblins" with four terrain
swatches under it and the name of the nearest tile the player has actually seen is a reason to walk
somewhere in particular, which is a thing the map had no way of giving before.

That is why the row is built the way it is, and why it is built in **one place** (`BountyList.row`)
for both the board and the journal: the swatches are the tile panel's own (`HexTileset.env_icon`, cut
out of the same sheet the map is drawn from), so the picture on the row is literally the ground being
described, and the **Nearest** line is `MapBuilder.nearest_env` over the cells the player has seen or
charted and never one still under the fog -- telling them about a place they have not found would be
the map giving away what charting is for. A charted tile wins a tie over a merely seen one, because a
charted tile can be farmed and a seen one is only somewhere to head towards.

It is measured from **where the player is standing**, not from the town that posted the work, and it
**never offers a settlement**. A board reading "Nearest: this village" is the first thing the line did
when it was measured from the issuing town, and it is both odd to read and useless as advice: the
ground under a town is a set piece with a boss on the end rather than somewhere to hunt goblins, and
the answer a player wants is which way to walk from here. So the two corrections are one correction
-- the line answers the question it is actually being asked. **Show** closes the page,
selects that tile and takes the camera to it, and then stops: what happens next is the tile panel's own
Move here, Farm or Chart, so the board hands the player back to the interface they already know rather
than growing a fourth way to travel.

**Three postings, two of the rabble and one elite.** The pair of commons are something a walk works
off by itself; the elite is the one worth going out of the way for, and it is the one that pays an orb
-- `OrbTable.roll_favoured`, the vendor's own draw, because what a bounty is for is the thing the
ground will not hand over. `NEED_COMMON` 24 is two or three tiles' fighting and `NEED_ELITE` 5 is the
same walk the other way round, since a tile fields one elite in ten.

The reward is quoted the way everything else in a town is, in bodies: `REWARD_MULT` 3.0 times what
`need` of that monster were carrying (`Encounter.gold_of` at the town's cell). So a board out at the
frontier pays frontier money with no second curve to keep in step, and a bounty is worth about three
times the purses it was earned from -- enough to notice beside a shelf's prices, never enough to make
farming for gold beat farming for gear. The balance pass left it exactly there: a common posting pays
five and a half tile fights' gold for under three fights of work.

**One bounty at a time, and it has to be accepted.** The first cut had no accept button -- reading
the board took all three postings on, and a kill counted against every open one anywhere. The user
turned that down: a bounty is a job taken on, not three tallies that run by themselves, so each
posting carries **Accept**, only an accepted posting counts kills, and nothing else can be accepted
until that one is **handed in** (finished is not enough: the walk back is part of the job). The board
therefore has no Show -- Accept stands where it stood -- and the journal, which now lists the one
bounty that is out, keeps it. `see` is still set where the tab is drawn, and is now only what puts the
journal in the corner.

**New work comes when the old work is done.** The board first shared the shelves' clock -- a hundred
kills and everything a town kept turned over -- and the user turned that down as arbitrary: a number
of kills has nothing to do with a board, and it wiped work the player had been meaning to get to. So
`restock` is refused until the board is `cleared` (all three handed in), and it is asked on the way in
and at every Claim, so handing in the third posts the next three under the player's hand. Nothing is
ever kept across one, because nothing is ever out when one happens.

**A bounty is done where the town is, not on the doorstep.** A kill counts only on a tile of the
posting town's level or deeper (`LEVEL` on the posting, `FightLedger.tile_level` from the fight): a
deep town pays deep-town gold, and two dozen goblins off the first ring should not collect it. The
row says so ("On level 3 land or deeper."), and "Nearest" skips land too shallow to count. With a
bounty out, a board shows only that posting -- the others cannot be taken, so they are noise -- and
progress is a bar with its count on the corner rather than a sentence, read at a glance like the
fight's own bars.

**A shelf can be bought fresh.** Restock, directly under the six squares, clears that shelf for gold:
`REROLL_BODIES` (thirty, two plain pieces thrown away) at the town's level, doubling with every reroll
this town has ever sold -- the count is saved with the town and never reset, closing the game included. Doubling is the whole design: the first is an
errand's change, the sixth is thirty-two of them, so a purse cannot be stood at a counter and turned
into the one piece it wants. Paying never touches the board. The two vendors are two counters:
Restock clears the open tab's shelf only and each keeps its own count, so hunting an orb does not make
the gear merchant dearer.

It is handed in at the town that posted it and nowhere else. That is what keeps a bounty a reason to
come back rather than a number that ticks over in a corner, and it is why the **journal** in the corner
says so in as many words on a finished one rather than growing a Claim button of its own. The journal
exists because progress and the walk to the monster are both wanted **away** from town -- that is where
the fighting happens -- and it is the same rows, so a posting reads the same in both places. It only
appears once a board has been read, for the reason the bag and the skills buttons only appear once
there is something in them.

**A posting is a card, not a paragraph.** The user drew it: the monster's picture in a frame, two
lines under it, and Info beside Accept along the foot. The first cut wrote everything out -- bar,
reward, level, swatches, nearest -- and three of those was a column of text nobody's eye landed on.
The picture is `EnemyRoster.portrait`, the first idle frame cut to its own pixels rather than to
`bounds`, which is the union of every animation and leaves a creature with a long swing small in its
own frame. Where the monster lives is still the point of a board, so it is one press away behind
**Info** rather than gone, and the journal -- which is opened for exactly that -- starts with it open.
Claim lost its figure because it now shares a row with Info and a reward grows without limit; the
figure is on the card above it.

**A dead button says why in its tooltip and nowhere else.** Buy, Restock, Upgrade and Lock each used
to put their refusal under themselves in rust ("Your purse is short."). The user took the lines out:
they were the page talking about itself, they cost height the column does not have, and at a counter
where most things are out of reach most of the time they made the page read as a list of complaints.
The grey is the statement; the reason is for whoever asks, which is what a tooltip is.

## Making the counter obvious

The first cut of this page was two tabs and a sentence telling the player to go and press something in the bag, and the verdict on it was "I don't understand how to buy orbs". A counter has two halves and only one of them is on this page, so **both have to be said on it**: a **Buy** heading over the six squares, each square's price under it in coin and figures, and under the shelf one line saying where the selling happens -- the bag on the left for gear, the orb tray for orbs. Nothing on the page is a verb the player has to guess at.

The price is on the square rather than behind a click because six squares with no numbers on them are six questions, and a shop that has to be opened six times to be read is a shop nobody reads. It is drawn with the coin at half its 16 px sprite, a clean 2:1 step, because a full-size coin takes a fifth of a square's width and leaves a four-figure price nowhere to go. Deep in the map prices run past four figures and the label clips; the whole number is in the square's tooltip and on the Buy button, and this is the one place the interface admits that gold grows faster than a panel can.

That width is the whole shape of the page. Three squares across plus their gutters is 140 panel pixels, which with the pack's margins makes the page 160 of the 576 the window has; the bag kept its 240 (five squares, when this was settled; four and 195 now, so there is slack) and the comparison gives up the difference (`BagPage.SHOP_WORN_WIDTH`, 170 to 146). Two columns would have fitted the old width and needed three rows, and three rows of squares and prices do not fit down a 648 px window with tabs and two lines of sign -- **the page is as tight vertically as it is horizontally**, and that is what settled it. The same budget is what took the settlement's tier off the page: with the shelf on it the row saying "Village" was the one thing costing height that nothing was reading, and the rows now sit 4 apart rather than 6.

The smith is what finally broke that budget. A fortress carries three tabs and so a **second row of them**, which cost the gear tab fifteen panel pixels it did not have -- and Tier 4's board makes four tabs on the same two rows, so the row is here to stay. Rather than shave the shelf or drop a line, everything under the counter's **name** now sits in a scroll (`_scrolled`), the way an open piece's modifiers already did: the tabs and the counter's name stay pinned above it, the Buy button stays pinned below it, and what runs past the foot of a 648 px window is the shelf's own tail rather than a button. It also means the page survives a window the game has not been shown in yet. One line was shortened with it -- "Stock: 100 kills" rather than a sentence -- because the restock is the least urgent thing on the page and was costing two lines to say what fits on one.

A piece off the shelf **opens like any other piece**: the same `ItemDetails` block the bag writes, with Buy and its price under it, and the comparison on the other edge pointed at what is worn in that socket. So judging a purchase is the same act as judging a drop, and the player learns one thing rather than two. Buy is greyed, **with the reason in its tooltip**, when the purse is short or the bag is full -- the bag's refusal is not a nicety, because `Inventory.add` on a full bag destroys the worst piece in it, and a vendor who takes your gold and throws away your boots is a bug with a receipt.

## Where it stands on screen, and what gives way

The town page takes the **right edge, in the tile panel's place**: the player is inside the settlement, so the panel that describes the tile from outside steps aside while they are. The **bag opens on the left in shop mode** rather than the town page carrying a grid of its own -- what the player wants to sell is already laid out in the bag, sectioned by level, and a second grid of the same items is a second place to hunt through. So a tab on the town page is a **sign over a counter**, not a counter: it says what this one takes, and the Discard button in the bag quietly becomes Sell.

That gives three panels in a 1152 px window at `ui_scale` 2, which is 576 panel pixels, and they do not all fit at their natural widths. In order of what gives way:

1. **The doll goes first.** With no piece open the character sheet is the pack's silhouette and its eight sockets, which answers "what am I wearing" -- a question nobody is asking while emptying a bag over a counter. Shop mode simply hides it.
2. **The comparison narrows, and never goes.** It is the one thing on that side of the screen that answers the shop's own question: is this worth more than what I have on? `BagPage.SHOP_WORN_WIDTH` (146) is what is left after the bag's 240, `WORN_GAP` and the town page's 160. The cost is real and was weighed twice, once when the page arrived and again when the shelf widened it: the comparison and the bag's own stat block no longer wrap alike while a town is open, so a long modifier takes three lines on one side and one on the other. The alternative was a shelf whose prices could not be read or a comparison that vanished when it was most wanted.
3. **The bag's grid never moves.** Five squares across is what the bag is.

The town page's tabs are **one word each** (`Gear`, `Orbs`, `Board`, `Smith`) with the counter's full name spelled as the heading under them, two to a row, so a fortress's four still fit that width. And the open counter is named **in words** as well as by the tab that is held down: the pack presses a button by drawing it a pixel lower, which is right for a press you are watching and far too quiet for a state you are reading off a row of them -- the same reason the bag says "Level 3 auto" in its heading rather than leaving it to the toggle.

The two pages talk to each other in one line each, and both are wired in the main scene rather than knowing about one another. The counter hands the bag whatever it has open (`TownPage.offer_changed` -> `BagPage.offer`), which is also how a purchase reaches the purse, the grid and the tray -- one redraw, so there is no second path for a bought piece to arrive by. The bag hands the counter whatever *it* has open (`BagPage.selection_changed` -> `TownPage.bag_changed`), which is what the blacksmith will act on, and meanwhile is what makes a Buy greyed out for a full bag come back live the moment a piece is sold out from under it: selling closes what was open, so the counter hears about it.

## What the bag buys, and what it does not

Shop mode is pointed at the town page's **open tab**, not at everything the town offers. The gear merchant's Sell button and the orb vendor's tray are never live at the same time, so a town with both is two counters the player walks between rather than one counter that does everything. Inside the bag it is one rule in one place (`_buys`), which is why there is never a Discard sitting next to a Sell for the player to press by mistake: the same button is one or the other.

The orb tray keeps its second job. With a piece open it crafts, exactly as it always has; with nothing open and a vendor beside it, a press is a sale. So standing in a town never costs the player the crafting tray, and closing the piece they have open is the whole of how they switch between the two. Both paths obey the tray's original rule -- apply first and spend second when crafting, spend first and pay second when selling -- so an orb is never consumed for nothing and never paid for twice.

A **worn** piece cannot be sold, for the reason it cannot be discarded: the cap is the bag's alone, and nothing should push the player into stripping what they are wearing.

## The fortuneteller, and what she took off the free list

Every settlement has her, villages included. She is the one counter that sells nothing to carry: six readings, each a button with its price, and her answer written in the list's place with the arrow back under it, the way a shelf piece opens and closes. The list lives in the scroll rather than pinned at the foot because six buttons are 152 panel pixels and an answer needs the same room.

Three of the six are things the game gave away until she arrived, and the user moved them behind her on purpose: the **chest star**, a bounty's **"where it lives"**, and the collection log's **"where it is found"**. Each was information with no price, which made it furniture. Behind a fee each is a small decision, and the fee is small on purpose -- half a fight for a bounty's land against the five and a half the bounty pays -- so nobody is locked out of a board, they are only asked whether they already know where goblins live. The level line on a bounty stayed free: it is a rule of the job, not a location.

- **Roads** (10 bodies, 1 fight): the nearest village, town and fortress, each as a wind and a walk. One tile is an hour, eight hours a day, seven days a week, rounded to the largest unit that fits, because "37 tiles" is a map coordinate and "about 5 days" is a journey. Read off `TownWorld`, which holds the whole 256 x 256 world, so she sees past the drawn window -- the one reading that can. Paid once per town; after that the town tells it again for nothing, since the world has not moved and charging twice for the same sentence is a tax on forgetting.
- **Treasure** (20, 2 fights): the star goes over the chest nearest the player when she is paid and stays on that chest until its tile is charted. One chest a fee, by the user's choice over a permanent unlock: a chest is a mimic with a boss's drop, and two fights for a pointer at one is a trade worth making every time. Refused while a star is out, and when the generated map holds no chest.
- **Quarry** (5, half a fight): `located` on the accepted posting, and the board opens on that card with Info already folded out -- that is what was bought. It is still `nearest_env`, so it still never names land under the fog: she sells the answer the board used to give, not a better one.
- **Relic** (50, 5 fights): one unique neither found nor shown, written out in full -- the first time the game says what a missing unique *is* -- with the ground it drops on. The log's card for it says the same from then on (`write_hint` is the one place it is written). Unpeeked, the log says "Not found yet" and who to ask.
- **Appraise** (5): the whole pool the open piece's kind can roll, each line with its band at the piece's level and its share of the weight, commonest first. The game has no modifier tiers; the band at the item's level is what a tier would be. The whole pool rather than the pool less what the piece carries, because a reroll draws from all of it and an Exalted's smaller pool is this list less what is on the card. A unique is refused: its lines are its row's.
- **Scour** (1000, a hundred fights, **once in a playthrough**): the clicked tile and two rings, nineteen tiles, out of the dark as *uncharted* land. The user asked for a 4x4 hexagon; a hexagon on this grid is 3, 5 or 7 across, and 19 tiles is the nearest to 16. Uncharted rather than charted is what keeps it from being a teleport: the patch can be looked at and walked towards, and `can_chart` still wants a charted neighbour. It is paid for on the map and only when at least one tile came out, so the single spell cannot be wasted on land already seen or on the edge of what has been generated -- land past the window does not exist yet and is never generated on demand (`Scenes/Map/DESIGN.md`: nothing generated is ever regenerated, and generation is order-dependent).

**Each reading is sold once a settlement**, by the user's choice (2026-09-18): without it one village could be asked for every relic in the log, a star after every chest and a reading of every piece in the bag, and the walk between settlements would buy nothing. Once a settlement makes her a reason to go to the next town. The roads stay told again for nothing, since that is the same sentence and not a second sale; the scour stays once in a playthrough. What was bought is `fortune_<reading>` in the town's drawer, which is the key the roads were already saved under.

The prices are `FORTUNE_BODIES` at the town's level, like an orb: knowledge has no level of its own, and what makes it dearer at the frontier is that everything there is. The balance table puts them at 1 / 2 / 0.5 / 5 / 0.5 / 100 fights, flat across the map.

Her tab wears the question mark until a mark of her own is cut from the pack.
