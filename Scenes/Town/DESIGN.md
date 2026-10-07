<!-- The long-form design notes for this folder: why things are the way they are. Not loaded automatically -- Scenes/Town/CLAUDE.md holds the short rules and points here. -->

# Towns

A settlement used to be nothing but a harder fight -- the `SETTLEMENT` profile with a boss on the end -- and gold had exactly one sink, the skill reset. A charted town is now somewhere to go with the bag full: sell what has piled up, and later buy, upgrade and take bounties. What follows is the reasoning behind the shape of it; the short rules are in `CLAUDE.md` beside this file.

## Tiers, and why a village is not a small town

The three tiers already exist on the map and already look different, so they are what the counters hang off rather than a second table nobody can see from the map: a **village** has a bounty board and **one** vendor, a **town** has the board and both vendors, a **fortress** has all of that and a blacksmith. That makes walking further mean something specific rather than meaning "bigger numbers", and it makes the fortress on the far side of the map a destination rather than a harder tile.

Which vendor a village gets is drawn from the world seed and the village's own spot. Two villages a day apart are not the same errand, and because it is drawn rather than rolled there is nothing to write down and nothing to migrate: walking back finds the same counter forever. That is the line this folder draws everywhere -- **what a town *is* is derived, what a town *has done* is written down**. The counters are derived. The stock a vendor rolls, and the bounties a board issues, are rolled, and so they go in `TownState` with the names and the town world, for the same reason those do: "a pure function of the seed" is a property of today's tables and not a promise to the player.

## One save, one write

Town state lives inside `inventory.json` as `inventory.towns`, the way `skills` does, rather than beside the map. A purchase moves the purse, the bag and a town's shelf in one act, and two files is two ways for them to disagree about whether it happened. `Inventory.VERSION` goes 9 to 10 and an absent `towns` key reads as no settlement walked into yet, which is exactly what every save written before there was anything in a town to do actually means.

`TownState` is keyed by **world spot** rather than by map cell, because a cell is a place in the drawn window and the window grows when an ice wall falls. It is written `"x,y"` because JSON object keys are strings and a `Vector2i` stringified by Godot is not something to hand a save file.

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

- **Selling was already a side income and stayed one.** A hundred kills turn up 3.6 pieces and 5.7 orbs; sold, and counting the rares and elites nobody actually sells, they come to 39% of that run's purse at level 1 and 23% at level 10. Keeping rare and better -- which is what a player does with them -- it is **20% falling to 13%**. Under a quarter, tapering with depth, and never close to the gold the bodies handed over directly. No dial moved for this. *Since the cascade* (a gear find rolls again, `Encounter.MOST_DROPS`) the same hundred kills turn up **3.99** pieces, and the two shares read 32.4% -> 20.5% and **23% -> 15%**: a tenth more side income and the same story. Still no dial moved.
- **An orb was creeping up on a piece of gear.** At the old `RARITY_MULT` a rare at the town's own level fetched 7.8 bodies and an Orb of Exaltation fetched 8 -- so the rarest currency in the game was worth more than the find of the afternoon, and the temptation was to farm orbs for gold rather than craft with them. With the ramp below, a rare at the town's level is 15 bodies against the Exalted's 6.4, and every other orb is further behind. The orbs are back to being what you spend.
- **`RARITY_MULT` 1 / 1.6 / 2.6 / 4.2 / 7 -> 1 / 2 / 5 / 14 / 24.** The row that forced it was the shelf: an elite off a vendor cost **5 tile fights**, which is not a decision, it is pocket change. The same dial sets what a sold piece fetches and what a bought one costs, so steepening the top of the ramp is the one move that makes the good end of a shelf an errand (**21 fights** for an elite, 7.5 for a rare) without touching the common end that a bag is emptied at. It cost some sale income -- the rare and elite drops fetch more too -- which is the other half of why `SELL_SHARE` moved.
- **`SELL_SHARE` 0.25 -> 0.20.** The only dial that moves the two directions *against* each other: a shelf gets a quarter dearer while a bag of finds fetches a fifth less. It took the shelf's plain end from 1.2 fights to **1.5**, its elite end to 21, and put the sell-everything share back under 40% at level 1 and 23% at level 10. "Five times what it fetched" is no worse to remember than four, and it is still one number for both counters and both goods.
- **`LOCK_BODIES` 500 -> 2500.** The table caught this one outright: 500 bodies is **50 tile fights**, at every level, including the 3.77 million at level 10 that reads enormous and is four sessions' farming. A lock is meant to be the one thing in the game that cannot be rolled away and the largest sink there is; 2500 bodies is **250 fights** (18.9 million at level 10, 2500 at level 1), which is a season rather than an afternoon, and still reachable at any depth because the purse at the deep end of a band pays three times what its first tile does. It is no longer "twenty-five upgrades" -- the ratio was rhetoric, since no piece can be walked twenty-five levels -- it is simply the biggest number in the game. **Then 2500 -> 250 (the user, 2026-09-28): ten times cheaper, 25 fights.**
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

**Upgrade** raises a piece's level by one and rewrites its base stats to exactly what a fresh roll at that level would have carried (`Item.scaled_stats`). That makes him the one exception to the oldest rule in `Scenes/Items/`, that a piece is frozen when it is rolled -- and the exception is the point: the whole game up to here has been "find a better base and start again", and the smith is the answer to the elite sword with the perfect modifiers that is four levels behind the frontier. The **modifiers stay as they were**, tier and number (the user's call, 2026-09-28, undoing an interlude in which the upgrade rerolled them at the new level and took every tier up a step). The piece now comes off the anvil wholly at its new level rather than as a good base carrying stale numbers, and the blow stops being free in the one way that mattered: it is a gamble with the good rolls as well as with the piece, so a well-rolled piece is a real decision to hammer rather than an obvious one. What it costs is Divine's job on an upgradeable piece; the orb keeps it everywhere the smith cannot reach -- a piece at the ground's cap, a broken one, a unique, and the whole game outside a fortress. **A locked or bound line is the exception**, and that is the second thing a lock is now bought for: pin the roll that came up and the hammer walks past it.

The upgrade **can break the piece**, one time in twenty. That is what stops the smith being a gold-for-levels machine with nothing to think about: a piece walked five levels is a piece that survived five real chances of ruin, and it is worth something for that reason as much as for its numbers. A break is deliberately not a loss of the piece -- it is still worn, still sold, and simply never changed again -- because destroying what the player was carrying would make the button one nobody presses. There is no safer, dearer upgrade to buy instead: two buttons would turn every press into a sum, and the whole of the design here is a press you can make without one.

The **cap** is `MapBuilder.circle_level(town cell)`: the level of the deepest land of the town's wall circle, 3 inside the first wall. Until 2026-10-03 a boss's `TIER_LEVEL` rode on top -- what a boss there could drop -- and the user took it off: the smith takes a piece as far as the land goes, and only a body past its tile's level hands over more. It was `level_of(town cell)`, the town's own tile, until the user asked (2026-09-28) for it to be gated per wall tier instead: every fortress between the same two walls now works to the same ceiling, so which one the player happens to find first stops mattering, and the ceiling rises when a wall falls -- the frontier the game is actually built around. A fortress near the inner wall can take a piece a few levels past what its own tile drops, never past what its circle does. The cap is handed to `Blacksmith` rather than worked out in it, because what a level means on a map is the map's business.

**Lock** pins one modifier to a piece for good: every orb then rerolls around it, and a Divine steps over its value. No orb takes a piece down a rarity, so a locked piece is never a common, which would be a contradiction in `ItemRarity.MOD_COUNT`. The locked line is one of the rarity's handful and never an extra on top, so the ceilings all still hold -- which is what keeps a lock from being a back door to a seven-modifier elite.

Two decisions make the lock what it is. The **smith picks the modifier, not the player**: being able to choose would make a lock the last step of every craft, a tidy way to finish a piece off, and what it is meant to be is a bet on the line that came up. And it is **expensive** -- `LOCK_BODIES` 250 against `UPGRADE_BODIES` 20, about 25 tile fights against two (it was 2500 until the user cut it tenfold, 2026-09-28). A locked modifier is the only thing in the game that cannot be rolled away, and if every piece ended up carrying one the orbs would stop meaning anything. Locking never breaks: paying that and losing the piece to a coin toss is not a risk, it is a mugging.

Both prices are `gold_at_level(item.level)` times their dial -- the piece's own level, like `sell_price`, so the quote on the button is read against the piece in front of the player, and so that walking a piece up the map gets dearer with every step the way the ground it is walking towards does. At level 5 that is 680 gold to upgrade and 85,000 to lock; at level 10, 150,860 and 18,857,500, against an elite of the same level that sells for 316,806 and costs 1,584,030 off a shelf. Those are the figures the balance table is read against, above.

He acts on the piece **the bag page has open** (`BagPage.selection_changed`), carried or worn: the crafting rule the orb tray obeys, which is where the piece is being looked at rather than which half of the page it sits on. A worn piece was refused at first, on the grounds that the bag is where nothing else is holding a second reference to the object -- but no fight can be on while the page is up, and the doll's own squares already take an orb, so the refusal only made the player strip a set off to improve it and put it back on again. That is a step with no decision in it, and it is gone. His tab is the only counter with no shelf, so it is the piece's name, the two prices with a coin on each, what the hammer would make of it, and the reason a button is grey in that button's tooltip. A break is the one thing that happens on that page the player did not ask for, so it is said out loud in rust as well as written into the piece's own stat block, where "Broken" stands under its rarity and reads the same in the bag, in the comparison, over a drop and on a shelf.

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
than growing a fourth way to travel. (The Nearest line and Show went on 2026-10-01: see *The lands, for
nothing* at the end of this file.)

**Three postings, two of the rabble and one elite.** The pair of commons are something a walk works
off by itself; the elite is the one worth going out of the way for, and it is the one that pays an orb
-- `OrbTable.roll_favoured`, the vendor's own draw, because what a bounty is for is the thing the
ground will not hand over. `NEED_COMMON` 5 is a tile's fighting or less and `NEED_ELITE` 1 is a tile
or so of looking, since a tile fields one elite in ten. (Cut from 24 and 5 on 2026-09-21 at the
user's call: postings should be quick errands, paying what they paid before.)

The reward is quoted the way everything else in a town is, in bodies: `REWARD_COMMON` 100 and
`REWARD_ELITE` 20 purses of that monster (72 and 15 until 2026-09-23, when the user raised them) (`Encounter.gold_of` at the town's cell). So a board out at
the frontier pays frontier money with no second curve to keep in step. Those were first `REWARD_MULT`
3.0 times `need` -- three times the purses a posting was earned from -- with the old counts of 24 and
5; when `need` was cut the payout was held where it was rather than cut with it, so a posting now pays
well over its bodies' purses: a common one about five and a half tile fights' gold for under one
fight of work.

**A posting can promise a piece of gear, and says only what kind and how good (2026-09-22).** The
user asked for bounties that reward an item besides gold -- a unique, an elite piece, a +1 -- with the
card never saying exactly what: the item's type and its rarity by its border, a generic icon for a
unique, and "+1" on an ascended one. So a posting carries a *promise* (`item`: kind, rarity, plus) and
not a piece: the piece is rolled at the hand-in (`reward_item`), which is what keeps the exact reward
out of the save and off the card at once, and the card's square (`ItemSlot.teaser`) is the kind's
plainest material's icon in the rarity's frame -- the plainest, because the material is rolled with the
piece and the icon must not say it. A unique wears the fortuneteller's relic mark and no kind at all:
its base is one of eight, and "a unique amulet" would narrow twenty-seven to four. The rarity is a
boss's own draw, the elite posting taking the better of two, the way a vendor's shelf takes the better
of two levels; the piece's level is the town's ceiling for the posting's tier, as a shelf piece's is,
so no board hands out gear the ground would not. `ITEM_CHANCE` (a common posting one in two, an elite
always), `UNIQUE_CHANCE` (one in twenty, one in five) and `PLUS_CHANCES` (at least +1, +2, +3, +4 at
25, 5, 1 and 0.1%, then `PLUS_TAIL` a tenth as likely each step; it was one +1 in four) are unplayed
dials. A promised piece has to fit in the bag, and the Claim greys over a full one by the vendor's
rule rather than paying the gold and dropping the piece: the two are one reward.

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
own frame. Where the monster lives is still the point of a board: it once sat one press away behind an
**Info** button (open from the start on the journal), and since 2026-10-07 it is always shown on both
and Info is gone (the user's call). Claim has no figure because a reward grows without limit and a
small button has no room for it; the figure is on the card above it.

**A dead button says why in its tooltip and nowhere else.** Buy, Restock, Upgrade and Lock each used
to put their refusal under themselves in rust ("Your purse is short."). The user took the lines out:
they were the page talking about itself, they cost height the column does not have, and at a counter
where most things are out of reach most of the time they made the page read as a list of complaints.
The grey is the statement; the reason is for whoever asks, which is what a tooltip is.

## Making the counter obvious

The first cut of this page was two tabs and a sentence telling the player to go and press something in the bag, and the verdict on it was "I don't understand how to buy orbs". A counter has two halves and only one of them is on this page, so **both have to be said on it**: a **Buy** heading over the six squares, each square's price under it in coin and figures, and under the shelf one line saying where the selling happens -- the bag on the left, for gear. (Orbs were once sold from the tray too; see below.) Nothing on the page is a verb the player has to guess at.

The price is on the square rather than behind a click because six squares with no numbers on them are six questions, and a shop that has to be opened six times to be read is a shop nobody reads. It is drawn with the coin at half its 16 px sprite, a clean 2:1 step, because a full-size coin takes a fifth of a square's width and leaves a four-figure price nowhere to go. Deep in the map prices run past four figures and the label clips; the whole number is in the square's tooltip and on the Buy button, and this is the one place the interface admits that gold grows faster than a panel can.

That width is the whole shape of the page. Three squares across plus their gutters is 140 panel pixels, which with the pack's margins makes the page 160 of the 576 the window has; the bag kept its 240 (five squares, when this was settled; four and 195 now, so there is slack) and the comparison gives up the difference (`BagPage.SHOP_WORN_WIDTH`, 170 to 146). Two columns would have fitted the old width and needed three rows, and three rows of squares and prices do not fit down a 648 px window with tabs and two lines of sign -- **the page is as tight vertically as it is horizontally**, and that is what settled it. The same budget is what took the settlement's tier off the page: with the shelf on it the row saying "Village" was the one thing costing height that nothing was reading, and the rows now sit 4 apart rather than 6.

The smith is what finally broke that budget. A fortress carries three tabs and so a **second row of them**, which cost the gear tab fifteen panel pixels it did not have -- and Tier 4's board makes four tabs on the same two rows, so the row is here to stay. Rather than shave the shelf or drop a line, everything under the counter's **name** now sits in a scroll (`_scrolled`), the way an open piece's modifiers already did: the tabs and the counter's name stay pinned above it, the Buy button stays pinned below it, and what runs past the foot of a 648 px window is the shelf's own tail rather than a button. It also means the page survives a window the game has not been shown in yet. One line was shortened with it -- "Stock: 100 kills" rather than a sentence -- because the restock was the least urgent thing on the page; that line went with the kills clock, and the tabs have since become marks in one row (below).

A piece off the shelf **opens like any other piece**: the same `ItemDetails` block the bag writes, with Buy and its price under it, and the comparison on the other edge pointed at what is worn in that socket. So judging a purchase is the same act as judging a drop, and the player learns one thing rather than two. Buy is greyed, **with the reason in its tooltip**, when the purse is short or the bag is full -- the bag's refusal is not a nicety, because `Inventory.add` past the cap overencumbers the player (no fight until the bag is cleared; it once destroyed the worst piece instead), and a vendor should never sell someone into that.

## Where it stands on screen, and what gives way

The town page takes the **right edge, in the tile panel's place**: the player is inside the settlement, so the panel that describes the tile from outside steps aside while they are. The **bag opens on the left in shop mode** rather than the town page carrying a grid of its own -- what the player wants to sell is already laid out in the bag, sectioned by level, and a second grid of the same items is a second place to hunt through. So a tab on the town page is a **sign over a counter**, not a counter: it says what this one takes, and the Discard button in the bag quietly becomes Sell.

That gives three panels in a 1152 px window at `ui_scale` 2, which is 576 panel pixels, and they do not all fit at their natural widths. In order of what gives way:

1. **The doll stays -- at every counter since 2026-10-07.** It went first at first: "what am I wearing" seemed a question nobody asked while emptying a bag over a counter, so shop mode hid it everywhere but at the smith, who works on a worn piece and takes it off the doll. The user asked for it at every vendor: what is worn is what a shelf piece and a sale are weighed against. It fits beside every counter, each page being the smith's width (the fortuneteller's answers stand over the middle, as they did over his doll); held upright the counter gives it its height, as it did at the smith, and the caret folds it away where that leaves too little.
2. **The comparison narrowed, and never went -- until 2026-09-22, when it went altogether.** It was the one thing on that side of the screen that answered the shop's own question -- is this worth more than what I have on? -- at `SHOP_WORN_WIDTH` (146), what was left after the bag, `WORN_GAP` and the town page's 160, with a long modifier wrapping to three lines on one side and one on the other. The user then asked for the worn piece only under Alt: the hover card's second card says it for a shelf piece as for any square, at the card's own width, and nothing on the bag's side is narrowed for it any more.
3. **The bag's grid never moves.** Four squares across (`BagPage.GRID_COLS`) is what the bag is.

The town page's tabs are **marks** (`TownPage.TAB_ICONS`: scroll, sword, gem, anvil, and a question mark for her), one row of up to five, with the counter's full name as each tab's tooltip and spelled as the heading under them. They were one word each, two to a row, until the second row pushed the gear tab past the window's foot. And the open counter is named **in words** as well as by the tab that is green: the pack presses a button by drawing it a pixel lower, which is right for a press you are watching and far too quiet for a state you are reading off a row of them, and since 2026-09-22 the tabs are bare marks on the cream the way the pack's craft tabs are, the open one turned to the pack's green -- which is all the pack changes on its open tab -- the same reason the bag says "Level 3 auto" in its heading rather than leaving it to the toggle.

The two pages talk to each other in one line each, and both are wired in the main scene rather than knowing about one another. The counter hands the bag whatever it has open (`TownPage.offer_changed` -> `BagPage.offer`), which is also how a purchase reaches the purse, the grid and the tray -- one redraw, so there is no second path for a bought piece to arrive by. The bag hands the counter whatever *it* has open (`BagPage.selection_changed` -> `TownPage.bag_changed`), which is what the blacksmith will act on, and meanwhile is what makes a Buy greyed out for a full bag come back live the moment a piece is sold out from under it: selling closes what was open, so the counter hears about it.

## What the bag buys, and what it does not

Shop mode is pointed at the town page's **open tab**, not at everything the town offers. The gear merchant's Sell button and the orb vendor's tray are never live at the same time, so a town with both is two counters the player walks between rather than one counter that does everything. Inside the bag it is one rule in one place (`_buys`), which is why there is never a Discard sitting next to a Sell for the player to press by mistake: the same button is one or the other.

**Orbs cannot be sold (2026-09-23, the user's ruling).** The tray used to sell an orb when pressed with no piece open beside the orb vendor. That was taken out: an orb vendor sells orbs and buys none, and the tray only crafts, in town and out. In its place the vendor **trades up** (the user's ask, the same day): under the shelf, every orb but the first for three of the one before it in the tray (`OrbTable.UPSCALE_COST`), no gold, so a pile of Transmutations still has a use.

A **worn** piece cannot be sold, for the reason it cannot be discarded: the cap is the bag's alone, and nothing should push the player into stripping what they are wearing.

## The fortuneteller, and what she took off the free list

Every settlement has her, villages included. She is the one counter that sells nothing to carry: six readings and her answer written in their place with the arrow back under it, the way a shelf piece opens and closes. They live in the scroll rather than pinned at the foot because an answer needs the same room they do.

**They stand on the shelf's own grid** (2026-09-20, the user's sketch; since 2026-09-25 each price is `_cost_cell`'s, in the body font -- at Pixellari 16 two four-figure great spells ran into each other and off the page's foot): three across, each its name over a 32 px mark with its price under it, `_price_cell` and `STOCK_COLS` exactly as a vendor's squares use them. **Two grids, one per half of her list** (2026-09-20), with a bare heading over each -- "Readings" and "Great spells" -- and no rule under it, which would cost the second grid's prices the row they need to sit above the fold. The heading is the only place the rule is written as words; what a square will and will not do is still only ever in its tooltip. The name is written out rather than left to the tooltip -- the marks are placeholders and say nothing on their own, and six pictures a player has to hover one by one are six questions, which is the same reason the shelf writes its prices under its squares. It is set in the body font, which is what makes the longest of them ("Treasure") fit a shelf square's width, and clipped so no name can widen the column and through it the page. A refused reading keeps its name lit and greys only its mark: what a spell *is* has not changed, only whether she will read it now.

**The names came off again on 2026-09-25** (the user: "remove titles of spells from the fortuneteller ui"), once the placeholders had become the pixellab badges: the art now says what it is, and the name led the tooltip ("Roads: ..."). Later that day the name came off the tooltip too (the user: "remove titles from the tooltips of fortuneteller"): the tooltip is only what the spell does, or why she refuses it. So did the tooltip's "Asked n times" (the user's call the same day): the price under the square already shows that it has climbed.

**A live square lights up under the cursor** (the user asked for a shine): a gold `StyleBoxFlat` grown `HOVER_GLOW` px past the square by `expand_margin` and drawn behind the mark, so what shows is a rim of light around it, with the mark itself lifted to `HOVER_LIFT`. The pack draws no hover face for a loose mark and these are not buttons, so there was nothing to cut; a rim is also what the eye wants here, since the thing being pointed at is a picture rather than a word. A greyed square wears none: nothing is being offered, so nothing lights. They were a column of six priced buttons, which read as a menu of words in a window where every other counter sells out of a grid of pictures -- and six long words down one edge is the shape that decides how wide the page must be. A square is a picture, a price and a tooltip, and the tooltip was already where the sentence lived. A reading she will not give is **greyed where it stands** (`OrbSlot.DIM`) with the reason in its tooltip, which is the orb tray's rule and the shelf's: a spent spell keeps its square, the way a bought piece keeps its socket. The roads, already bought in this town, write "Bought" and no coin where the price was (the user's, 2026-10-03; it said "Free" while a second telling cost nothing).

**The way out is on neither grid** and keeps its word and the full width under them: it is not a spell, it leaves the world rather than telling something about it, and a seventh square beside the six would read as one more reading.

**The marks are placeholders** cut by `tools/ui_kit.py` off the skill icons' pack (`Assets/Fortune/`), in the one colourway neither skill tree uses -- purple is hers, so nothing on her grid can be mistaken for a skill. They await art of her own, as her tab does.

Three of the six are things the game gave away until she arrived, and the user moved them behind her on purpose: the **chest star**, a bounty's **"where it lives"**, and the collection log's **"where it is found"**. Each was information with no price, which made it furniture. Behind a fee each is a small decision, and the fee is small on purpose -- half a fight for a bounty's land against the five and a half the bounty pays -- so nobody is locked out of a board, they are only asked whether they already know where goblins live. The level line on a bounty stayed free: it is a rule of the job, not a location.

- **Roads** (50 bodies, 5 fights; 10 and one fight until 2026-09-21, when the user made it dearer and gave it the map): the nearest village, town and fortress, each as a wind and a walk, and **every settlement in the town's own ring of land** (`MapBuilder.ring_of`: the land between two walls) lifted out of the dark as uncharted, the way the scour shows land (`reveal_ring_towns`). The ring and not the world, because past the wall is the next ring's business. One tile is an hour, eight hours a day, seven days a week, rounded to the largest unit that fits, because "37 tiles" is a map coordinate and "about 5 days" is a journey. Read off `TownWorld`, which holds the whole 256 x 256 world, so she sees past the drawn window -- the one reading that can. Paid once per town; after that the town tells it again for nothing, since the world has not moved and charging twice for the same sentence is a tax on forgetting.

  **2026-09-25:** the winds and walks came off (the user: "Remove the direction and distance from roads. Just tell the player that all towns are now visible on the map"), and with them `bearing`, `walk_time`, `nearest_towns` and `road_lines`. The answer is one sentence; the map already shows where each settlement lies.
- **Treasure** (20, 2 fights): the star goes over the chest nearest the player when she is paid and stays on that chest until its tile is charted. One chest a fee, by the user's choice over a permanent unlock: a chest is a mimic with a boss's drop, and two fights for a pointer at one is a trade worth making every time. Refused while a star is out, and when the generated map holds no chest.
- **Quarry** (removed 2026-10-01 -- see *The lands, for nothing*; kept here as history) (5, half a fight): `located` on the accepted posting, and the board opens on that card with Info already folded out -- that is what was bought. It is still `nearest_env`, so it still never names land under the fog: she sells the answer the board used to give, not a better one.
- **Relic** (removed 2026-09-28, when achievements took over telling the player what to hunt -- `Scenes/Items/DESIGN.md`, *Achievements unlock uniques*; kept here as history) (50, 5 fights): one unique neither found nor shown, raised in the collection log's own banner headed "Unique Revealed" (`main_scene._announce_unique`) and written out in full -- the first time the game says what a missing unique *is* -- with the ground it drops on. The log's card for it says the same from then on (`write_hint` is the one place it is written). Unpeeked, the log says "Not found yet" and who to ask.
- **Appraise** (5): the whole pool the open piece's kind can roll, each line with its band at the piece's level and its share of the weight, commonest first. The game has no modifier tiers; the band at the item's level is what a tier would be. The whole pool rather than the pool less what the piece carries, because a reroll draws from all of it and an Exalted's smaller pool is this list less what is on the card. A unique is refused: its lines are its row's.
- **Homecoming** (200, twenty fights, **once a settlement**, labelled **Return** because "Homecoming" is two letters wider than a shelf square): the player is put down in any settlement they have charted, with no walk and no route (`MapBuilder.jump_to`, which runs `_on_player_arrived` so everything an arrival does still happens). Aimed at the map the way the scour is, one tile rather than a patch, and charged only where the tile was a charted settlement that is not the one underfoot -- so the town's one casting cannot be spent on empty ground. It is the only thing in the game that moves the player without crossing what is between, which is why it is a great spell and not a reading: the walk is the map's whole cost, and buying past it should be a decision, not a habit. Twenty fights against a walk of a week or more is meant to be worth it every time it is offered, and there is only ever one on offer per town.
- **Scour** (1000, a hundred fights, **once a settlement**): the clicked tile and two rings, nineteen tiles, out of the dark as *uncharted* land. The user asked for a 4x4 hexagon; a hexagon on this grid is 3, 5 or 7 across, and 19 tiles is the nearest to 16. Uncharted rather than charted is what keeps it from being a teleport: the patch can be looked at and walked towards, and `can_chart` still wants a charted neighbour. It is paid for on the map and only when at least one tile came out, so the single spell cannot be wasted on land already seen or on the edge of what has been generated -- land past the window does not exist yet and is never generated on demand (`Scenes/Map/DESIGN.md`: nothing generated is ever regenerated, and generation is order-dependent).

## Readings and great spells (2026-09-20)

Her list was **one reading a settlement** (2026-09-18) for a good reason -- without it one village could be asked for every relic in the log, a star after every chest and a reading of every piece in the bag -- but the price of that was that no reading was ever a **cost**. It was the same figure every time and the only way to ask twice was to walk, which taxes forgetting rather than asking. So the user split her list in two (2026-09-20).

**The five readings are asked as often as they are paid for, and every casting doubles the next one's price** (`TownPrices.FORTUNE_GROWTH` 2.0, the shelf reroll's own dial and the same shape: base times growth to the power of the count). What stopped a purse being stood in front of her is now the price rather than the door: the eighth relic costs what a hundred and twenty-eight firsts do, so a player can have the third and fourth relic they actually want and cannot have all twenty-seven. She becomes a gold sink -- the thing the game was short of between the smith's lock and the shelves -- rather than a rationed counter.

**The count is global to the world, not per town** (the user's choice). Per town it would be reset by the walk, which is exactly the tax that was being removed, and a player would simply carry their questions to the next village. Global, the *base* still climbs with the town's level, so where a reading is bought still matters; how often it has been bought is the player's own history. It lives in `inventory.fortunes` under `cast`, and `Inventory.transcended()` does not carry `fortunes`, so a new world starts at the base price -- the exponent is one of the things left behind.

**The doubling was taken out on 2026-10-01** (the user: "Remove the 2x prices of fortune teller. Just make them more expensive"). The two paragraphs above are history: a reading now costs `FORTUNE_BODIES` at the town's level every time, the count is gone (an old save's `cast` key is ignored), and the three readings' bodies went up threefold to make up for it -- roads 150, treasure 60, appraise 15, i.e. 15 / 6 / 1.5 fights. Three was picked as roughly what the third casting used to cost; the user tunes it from there. **2026-10-02:** the user asked for the roads to cost more and to show one tile round each settlement as well; they went to 300 (30 fights), my pick of a number, and `ROADS_RADIUS` 1.

**The roads are sold once a town** (the user's, 2026-10-03: "don't say free when already bought. Say bought and disable the button"). Until then a town that had sold them told them again for nothing, since that is the same sentence read off a world that has not moved; a free square read as an offer, though. It is the one reading that still writes a drawer key, as a great spell does.

**The two great spells are one a settlement, the scour included** (the user's ruling: "powerful spells can be cast once per town. Even scour"). The scour was once in a whole playthrough, which made it a thing most players would never dare spend; one a town makes it a reason to walk into a village -- the same reason the old rule was protecting -- while leaving it dear enough that it is not a way to chart the map. Which half a spell is in is now the whole of its rule: `FortuneTeller.COMMON` climbs, `FortuneTeller.GREAT` is written in the town's drawer under the key every reading used to use.

**Relic went into the commons rather than the great spells.** There are 27 uniques; one a run would be a curiosity, and one a town was already the thing being loosened. Doubling from five fights is the right shape for a list that long: the first few are cheap enough to be worth asking and the whole log is never buyable.

The prices are `FORTUNE_BODIES` at the town's level, like an orb: knowledge has no level of its own, and what makes it dearer at the frontier is that everything there is. The balance table puts the **first** casting at 1 / 2 / 0.5 / 5 / 0.5 fights for the readings and 100 / 20 for the scour and the road home, flat across the map (since 2026-10-01 the readings are 15 / 6 / 1.5 and never climb). **Unplayed;** the scour's 1000 -- now bought once a town rather than once a world -- are the two dials to watch.

Her tab wears the question mark until a mark of her own is cut from the pack.

## The way out, and what it costs (2026-09-19)
Transcending is sold by the fortuneteller (the user's choice over a button in the settings or on the wall): every settlement has her, and she is already the counter that sells what is not a thing. It joins her list only once a wall has fallen, because until then there is nothing to take along.

**The price is the one on her list that is not at the town's level.** It is `FORTUNE_BODIES["transcend"]` = 2000 bodies on the second ring of land behind the first wall (`transcend_steps()`, step 12), the same in every town and every world -- the user's words were "very expensive, but easily farmable with monsters from the second ring". On `balance_town.gd` that is 102000 gold: 8300 tile fights' worth at level 1, 300 at level 5, 15 at level 8, 1.3 at level 10. So it is out of reach from inside the first wall, a long farm on the first ground behind it, and small change to anyone who has gone deep -- who no longer needs it to be dear, since what they are giving up is the depth. **Unplayed;** the dial is the one number.

**Asked, then done, and never charged.** The first press only turns her list into her answer -- what stays, what goes, and the price -- over a back arrow and the button that does it, the settings' Reset pattern rather than a new dialog. A short purse greys the deed and not the asking, since the asking is where the price is said. Nothing is deducted: the purse is one of the things left behind. Both buttons wear a coin and no figure, as Claim does -- with the figure on it the button under her answer widened the page by some fifty panel pixels, into the room the comparison and the crown stand in (the first screenshots showed it).

**The smith and an heirloom.** ~~`Blacksmith.break_chance` is nothing under `Item.safe_level`, and the ground's cap still holds: an heirloom that was level 30 is walked back to 30 only where the ground allows 30.~~ Since 2026-10-03 he does not walk it back at all: it climbs by itself with the land charted, and he takes it only from its `safe_level` on, at the ordinary risk (`Scenes/Items/DESIGN.md`, "Heirlooms climb with the land"). To hold one up to him at all, the heirlooms' page has to stand at the counter, so the crown is the one corner button a town leaves standing, and pressed there it swaps the two bag pages. The window had room: the crown stands past the comparison at 745-785 px and the town page begins at 833 (`ui_town_heirloom_smith.png`).

**Reworked 2026-09-20:** her answer no longer says what goes along. The user wanted a warning that all progress is lost and that the reward is great, without saying what it is; the black screen after it (`TranscendPage`) is where the player finds out. See the last section of `Scenes/Items/DESIGN.md`. **2026-09-30:** "All you have made here is lost" was not true -- the heirlooms, the collection, the achievements and the depth go along -- so it names what is lost ("Your bag, gold, orbs, levels and this land are lost") and still says nothing of what is kept, as the 2026-09-20 ruling asks.

## One look for every counter (2026-09-25)
The user said they did not like how the town page looked and, shown a list of what to change, said "do your best and I'll judge after". The complaint underneath was that the four counters each drew "a thing with a price under it" their own way -- dark badges, framed tan squares, 16 px orbs lost in a 24 px socket, "x3" under a trade -- and that the headings stacked four deep (town, tabs, counter, "Buy"/"Readings"), all in Pixellari 16, so none of them led.

- **One cell** (`_cost_cell`): the square, then the mark and the figure centred under it in the body font. Pixellari digits were what ran two great spells' prices into each other; Ark Pixel's fit a four-figure price inside the column. The figure turns brick when the purse cannot cover it, so a short purse is read off the shelf, not only off a tooltip.
- **Orbs on the shelf are item-sized** (`OrbSlot` `side`), the icon at its own 32. The tray keeps 24: that width is the bag's arithmetic, and it has none of the shelf's room.
- **"Buy" is gone; sub-headings are small.** A vendor's tab only ever sells, and the counter's name is already the heading, so Trade up and her two halves are a small word on a rule (`_section`, since 2026-09-25 `UITheme.section`).
- **Tabs are folder tabs.** A green mark alone was a colour change on twelve pixels. The first pass put the open one on a tan square, and the user asked for them to "look like tabs": shut ones stand lower and washed in tan on a line, and the open one stands taller in the page's own cream with the line broken under it, so the counter reads as its page.
- **The smith shows the piece.** His page was a name and two buttons over a blank column; the square and its `ItemDetails` block fill it, and what a blow changes is watched where it changes. *(2026-10-07, the user: with a piece open the square and the smith are gone and the block is written whole, base stats too; Upgrade and Lock are the small faces, one over the other -- side by side they stretched the page past `BODY_WIDTH`.)* The level line reads "Level 3 → 4 of 5 / Break 5%": the old "Level 6 of 6" read as though the piece were already at its cap.
- **Green is the one press a counter is for** (Buy, Accept, Claim, Upgrade), the pack's own green lettered in ink. This was item 1 of the 2026-09-22 look-and-feel list and is still limited to the town: the bag's Equip and the fight verdict's Collect are the obvious next candidates, and that is for the user to decide.
- **A bounty card puts the picture beside what it pays.** Stacked (picture, name, gold, goods, buttons), the board fitted one and a half postings to a window. Its buttons are the small faces (`UITheme.SMALL_BUTTONS`, the user's ask): at Pixellari 16, Info and Accept outweighed the posting they act on.
- **More air** (the user: "give the panels a bit more room to breathe"): `ROW_GAP` and `STOCK_GAP` 4 to 8, a card's pad 4 to 6 and its lines 2 to 4. The width this costs (`BODY_WIDTH` 140 to 148) comes out of the gap between the smith's doll and the page, which was about 45 panel pixels.

Not done: the fortuneteller's question-mark tab is still a smaller mark than the others (the square now evens out the row), and her badges stay purple, as the committed skill-style art draws them.

## Her answers are popups (2026-09-25)
The user: "Instead of opening a new panel after a reading, simply show a popup with a dismiss button visible from the start and a 'don't show again' message, which reduces the popup to a simple text line of which spell was cast." So a reading no longer swaps her list for its answer with a back arrow: the answer comes up over the whole window as the bag's questions do, with **Dismiss** pinned under a scroll so a long appraisal cannot push it out of reach, and a tick kept per reading in `inventory.tips` (`SKIP_TOLD`), as the bag keeps its questions'. Ticked, the reading answers with "You cast Roads." under her grids.

- **Treasure gets a popup too**, saying the star is up: before, it said nothing on the page, and with the popups its silence would have read as a press that did nothing. **Quarry** first opened the board on the located card instead; the user asked for a popup there too, so it answers as the others do -- the monster's picture, its lands and the nearest of them -- and the card says the same from then on.
- **The appraisal has no tick.** Its table is the whole of what was paid for; ticked away it would be a reading that tells nothing. A choice made without asking the user -- theirs to reverse.
- **The relic is the unique's banner, always** (the user: "Relic should always look as the 2nd option pop up. Just make sure dismiss button is there immediately"): the collection log's "Unique Revealed" banner with its X up from the start, not after the five seconds a fight's banner waits. No popup and no tick; where it is carried is in the log.
- **The way out is a square and a popup too** (the user: "Use this icon for transcending. Remove the button. Show this spell under the same limitations"): the user's own cracked orb, cut on her badge frame like the others (`tools/ui_kit.py` `FORTUNE_SYMBOLS`), stands third among the great spells, and only once a wall has fallen, as the button did. Asking is free and never greyed; its question is a popup (`_ask_way_out`, no wash -- it is a warning, not a reward) with Cancel and Transcend.

**Tooltips say the outcome** (the user: "descriptive of exactly what the spell does. Not how it's used, just the outcome"), each after the spell's name: "Scour: Brings a tile and the two rings of land around it, nineteen tiles, out of the fog", not "Uncover a patch of the map you choose".

## The lands, for nothing (2026-10-01)
The user removed the Quarry reading: a bounty card says which lands its monster lives on -- the tile panel's own
swatches -- for nothing, on the board and on the journal alike, and **never which tile**. The Nearest line and the
journal's Show went with it (the user: "Don't show the nearest, just show the environments"), and with them
`MapBuilder.nearest_env`, `BountyBoard.locate` / `located` and the main scene's `_on_show_cell`. What came before:
the board said where the monster lived for nothing until 2026-09-25, when it moved behind her at half a fight. The
review of 2026-10-01 pointed out that a fee that small is a click rather than a decision, and that it sold the one
thing the board was said to be for. Finding a tile of that land is now the map's business, which is what charting
is for. A save's `located` key on a posting is read by nothing, and her `quarry` count in `inventory.fortunes` is
never asked again. The same day the swatches became hexagons, a quarter of the map tile ringed in the cards' slot
brown -- the user's pick of four mockups (`HexTileset.ENV_HEX_ROWS`), on the tile panel's rows as well.

## Board tiers and the clearing choice (2026-10-03)

The user found bounties unrewarding. Everything a posting paid -- gold, experience, a vendor's orb, a piece
at the town's ceiling -- the ground paid too, and clearing a whole board earned nothing that one more
posting did not. Two things went in together.

**A town's board has a tier, I to III.** It goes up by one for every board that town clears, and stops at
III (the user: "cap the tiers at 3"). It is a **per-town record** (`CLEARS` in the drawer), so a town the
player keeps coming back to becomes worth more than one they pass through, and a new town starts at I. A
higher tier asks for more bodies (the user's answer to whether "tougher assignments" should mean more
work) and pays better on every line: more gold, experience and orbs, the rarity drawn more times, a
unique likelier, and every ascension step likelier. The user turned down tiers that switch things on
(a fourth "Wanted" card, a vendor a rarity better, and so on): "just improve the rarity in general".

**Clearing a board offers three rewards, and the player takes one** -- Hearthstone's way, the user's
reference. All three are good, and they are three *different* kinds drawn at random from five: an
ascended epic, an epic above the town's ceiling in the best material that level has, a unique, an
ascended unique, and a handful of one of the three dearest orbs (Divinity, Chaos, Exaltation). The tier
makes each one better: more ascensions, more levels, more orbs. The bundle **keeps the walls' unlock**
(the user's ruling of the same day: every way an orb is had draws only from what the walls have
unlocked), so before the first wall falls there is no bundle, and the three come from the other four.

The options are **rolled whole when the board is cleared and written down** in the town's drawer, the
way a shelf is. They are real pieces that the player can open and compare against their own, which a
promise could not offer. And nothing that happens before one is taken -- a closed game, the X, a full
bag -- rerolls them or loses them: the board's **Reward** puts them back up.

**The first clear has the smith say so** (`first_board_cleared`), over the choice he is handing over:
the player is a proper adventurer, here is some of his best work, and he will tell the board they can
take the nastier jobs, which pay better. That is the tier explained in his voice instead of in a
sentence on the page. He says it in a village too, where he has no counter.

Every number is a dial for the user, unplayed: `TIER_*`, `CHOICE_PLUS`, `CHOICE_LEVELS`, `CHOICE_ORBS`.

**The same day the user reshaped the reward (2026-10-03), and widened it to eight kinds.** The first
cut grew every option fast with the tier (+1/+2/+3 ascensions, 3/6/10 levels over the ceiling). Now:
the epic at the ceiling is a plain +1 at I, a **lucky** +1 at II and a lucky +2 at III; the high epic stands only
1, 2 or 3 levels over, its material drawn lucky, twice lucky and three times lucky (the best of two,
three and four draws); the ascended unique is +1, +1, +2. Three kinds went in beside them: a plain rare
rolled lucky, a pile of gold and a pile of experience. **Lucky is rolled twice and the better kept**,
the ARPG word: on a piece every modifier (tier and number) is rolled again and the higher number stays
-- the modifier count is the rarity's ordinary draw. **The piles are filler** (the user's word): there so
that not every clear hands over something epic, and so small -- one common posting's gold or
experience at that tier (`PILE_GOLD`, `PILE_XP`, in bodies at the town's level). A first cut at a whole
board's worth was too much. The postings changed with it: a
unique is 2/3/5% of a common posting's piece and 10/15/25% of an elite's, and at least +1 is 25/33/50%,
every later step moving by the same factor.
