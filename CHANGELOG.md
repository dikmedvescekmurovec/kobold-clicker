# Changelog

The newest version is first, and its heading is the version the game is: the web build shows every version
a player has not seen yet once, together, newest first (`main_scene.gd` `_show_changelog`). A version is
`## vX.Y.Z (YYYY-MM-DD)`, its sections `### Name`, and each change one line under them starting `- `,
written for players. A section may hold a two-column table instead (`| left | right |`, a header row, then
`|---|---|`): the game draws its rows as its own tables, the left column wrapping and the right kept short.

## v0.8.0 (2026-10-30)

### Transcending
- The fortuneteller reads your way out in the stars now. Transcending opens on her star chart, drifting through a nebula.
- Three stars to pick from: Create an heirloom, Take on a curse (once you hold a skull), and the Skill tree.
- Super orbs are gone, and so is upgrading heirlooms with them. Your heirlooms keep everything they already got from them.

### Curses
| Curse | New reward |
|---|---|
| Long Winter | +25% damage for every ice wall broken this world |
| Ring of Walls | +15% damage for every ice wall broken this world |
| No Second Chances | +40% drop rate and +40% item rarity |

### Skill nodes
- Nodes hold a lot more now: tier + 2 skill points before their own line. A tier I node takes 3, a tier IX takes 11.
- A node's card tells you what it takes: "Takes 5 SP".
- The ranks line is now "Takes +N skill points", on top of that.

## v0.7.3 (2026-10-30)

### Settings
- Squinting at your loot? Tick Larger text under Display.

### Map
- On a phone, dragging the map follows your finger now, instead of flinging you halfway across the world.

## v0.7.2 (2026-10-30)

### Loot
- Weapons can now roll +1 Attack Speed. It's the rarest line there is, so good luck.

### Camps
- Once you've found the Broken Sword, camps bring gear back too, even before you've seen your first orb, unique or skill node.

### Map
- Clicking the map while a page or a town is open just closes it. Clicking again picks a tile.
- On a phone, pinching zooms around the middle of the screen, and the map stays still until you let go.

## v0.7.1 (2026-10-29)

### First steps
- Your first Orb of Augmentation shows you what to do with it, just like your first orb did.
- Augment the Broken Sword and it gets +1 Attack Speed. It finally swings on its own.

### Towns
- The blacksmith gets around now. A village has one of the gear merchant, the orb vendor and the smith, a town two of them, a fortress all three.

### Bag
- Rings get Equip left and Equip right, so you always know which finger you're filling. Shift-click still takes the emptier one.

## v0.7.0 (2026-10-29)

### Story
- A new game opens on a comic: how a knight fell to Gollux and woke up a kobold at the ice wall.

### First steps
- Your first item, your first orb and your first level now show you what to do next: the screen darkens around the one thing to press until it is done.
- On a phone, the first orb also lists the three taps of crafting: tap an orb, tap the item, then tap it again to apply.
- Farm now appears after you first lose a fight on a tile.
- Wander five tiles off the road on the way to the first town and the hero will remind you where roads lead.

### Bosses
- The bosses have left the towns. Each one now waits in a lair out on the map at the end of a trail of footprints, and drops a unique of its own.
- Lairs are never close to one another, and their trails are eight tiles long.
- New boss: the Frozen Golem rules the frozen lands.

### Phones
- Held upright, the corner buttons are now a bar along the bottom of the screen.
- Held upright, a town shows your bag on top, with Items and Equipment tabs, over the counter.
- The orb you are holding keeps its card at the top of the screen, clear of your items.
- Spoken tips now appear at the top of the screen.
- The comic reads as one tall column in any window taller than it is wide.
- The bounty board, the journal and every other list now scroll with a finger.
- Entering the Golden door password no longer starts the game at a tiny size while the keyboard is still up.

### Interface
- The tile panel sits in the top right and is only as tall as what it shows.
- Holding Alt over an item that would replace nothing no longer shows an empty card.
- A skill tree slot's tooltip now appears beside the slot, and an empty slot tells you what goes in it.

## v0.6.1 (2026-10-11)

### Front page
- The front page now scrolls: under the cover, nine short films and pictures of what the game is, and the waiting list again at the end.
- Golden door asks for its password once. After that it opens at a press.

### Camps
- A camp now brings back what its monsters dropped, as well as gold and experience. Your item filter and your level rules decide what it keeps.
- A camp lasts one hour to begin with, and one hour longer for every ice wall you have ever broken.
- Camp Earnings on your armour now also means more monsters driven off, and so more finds.
- The Restless curse fills a camp four times sooner.

### Bag
- Your bag holds 10 more items for every ice wall you have ever broken.

## v0.6.0 (2026-10-11)

### Characters
- New page, Characters, behind the helmet button in the corner or the R key: 31 new heroes to buy and play as. Every one is free for now.

### Interface
- Five corner buttons have new pictures, so each shows what it opens: branching nodes for the Skill tree, a gleaming chest for Heirlooms, a tome for the Collection, a rosette for Achievements and a winner on a podium for the Leaderboard.

### Dialogue
- The hero, the fortuneteller and the blacksmith have new lines.

### Fixes
- Closing the game on the black screen between two worlds no longer changes your save: you have not transcended until you enter the new world.
- A tile you won but had not collected yet is charted when you close the game.
- A save the game cannot read is refused with a reason, never replaced by a new game.
- Coming back to what your camp earned no longer makes the cloud ask which save to keep.
- A fight whose clock has run out now ends, whatever your defences give back.
- An enemy already dying when the clock runs out counts as a kill.
- The last kill under a rune is paid with the rune's bonus.
- The loot filter no longer leaves the Masterwork Torch behind.
- The tile panel now shows what the Wild Tiles curse really pays.
- A question answers once, however fast you press its button, and closes with its page.
- The leaderboard's name box keeps your cursor while the board refreshes, and says when a name is taken.
- The back arrow works on the black screen on a phone held upright.
- A fight that opens while someone is speaking waits until they have finished.
- The fortuneteller's appraisal no longer writes "a Iron Sword".

## v0.5.0 (2026-10-10)

### First steps
- The Broken Sword drops within the first 10 kills, an Orb of Transmutation by the 20th, an Orb of Augmentation by the 30th, the Squire's Blade by the 120th and a first skill node by the 170th.
- The first Orb of Transmutation used on the Broken Sword always gives it +1 Damage.
- A new skill tree starts as the root alone

### Fortuneteller
- New spell, Banish: once you have unlocked 24 uniques, the fortuneteller can keep a unique you pick from dropping in this world.

### Map
- Stop, a new button at the foot of the map, cuts a walk short on the next tile.
- Enter town now works from afar on a settlement you have charted: your hero walks there and the town opens on arrival.

### Skill tree
- Improvements to visual clarity

### Phones and tablets
- A tap now selects and the next tap applies, so you can read a thing before you spend on it.
- Tap a skill node to read it, then tap it again to spend a point. Keep your finger on it to automatically spend your skill points
- Tap an orb to pick it up, tap a piece to read it, then tap the piece again to use the orb on it.
- Tap a rune to pick it up, tap a tile to open its panel, then tap the tile again to spend the rune there.
- Hold your finger on an orb or a rune to read what it does.
- A fortuneteller's spell shows what it does on the first tap and is cast on the second. Scour and Return outline the land on the first tap.

### Interface
- The red dot on the bag button now marks a first of its kind: your first item, orb, skill node, unique and rune.

## v0.4.1 (2026-10-09)

### Front page
- Leave your email on the front page to join the waiting list and hear when the game comes out.
- The game now waits behind the Golden door, which asks for a password.

### Fixes
- Typing on a phone now works in every text box: your email, the password and your hero's name.
- The password box no longer slides into the top corner when a phone's keyboard opens.

## v0.4.0 (2026-10-09)

### Runes
- Runes now sit in a row above your orbs in the bag. Pick one up and click a tile on the map to spend it there.
- A rune's effect now lasts 1000 kills instead of 100.
- The arrow in the line above the orbs folds the orbs and runes away, and opens them again.

### World
- Gollux's cave now appears beside the ice wall you just broke: the third in your first world, the first in every world after.
- From the fourth ice wall on, a wall has as much health as 150 enemies of the land just inside it.
- Distant charting collects the loot of every tile you fight through on its own.
- Breaking a later ice wall no longer freezes the game while the new land is made.

### Achievements
- An achievement past rank IV keeps counting, and shows the most you ever reached.

### Skill tree
- Spending points in a large tree no longer stutters.
- The character panel stays in view while the skill tree is open.

### Credits
- Thanks to Benjamin Medvešček Murovec for ideas and testing.

## v0.3.1 (2026-10-09)

### Skill tree
- Hold the mouse button down on a skill node or the root to keep spending points on it, faster the longer you hold.

## v0.3.0 (2026-10-09)

### Skill tree
- The Power, Fortune and Guard trees are gone. Now you build your own skill tree out of skill nodes you find.
- Strength, Dexterity and Intelligence Nodes drop as loot, and each has its own modifiers. An uncommon node carries one modifier, a rare two and an epic three.
- A node's tier, carved on its face from I to IX, is how deep in the tree it can stand. Deeper land drops higher tiers, and higher tiers unlock stronger modifiers.
- A node holds up to three nodes below it. A node that holds none is a leaf.
- Capstones are unique nodes with fixed effects: Assassin, Whirlwind, Titan, Collector, Midas, Alchemist, Phantom, Bastion and Undying.
- You place nodes on the new Skill tree card when you transcend. A node left in the bag, or pushed out by a swap, is lost when the new world starts.
- Spend skill points on placed nodes as you level. The root takes any number of points, and each one gives +1 damage and +1% increased damage.
- Orbs and the blacksmith work on nodes as they do on gear. Capstones can't be changed.
- Zoom the tree with the mouse wheel, a pinch or its − and + buttons, and drag to move around it.
- Helmets that gave Power, Fortune or Guard skill ranks now give Strength, Intelligence or Dexterity Node ranks.
- The Mastery achievement counts the nodes in your tree. The Specialist curse allows points in only one branch.
- Old saves get their skill points back unspent, and their tree starts with a single Dexterity Node.

### What each ice wall unlocks
| Unlock | Wall |
|---|---|
| Orbs of Transmutation and Augmentation | From the start |
| Orbs of Alchemy and Divinity | 1st |
| Orbs of Chaos and Exaltation | 2nd |
| Gollux's cave and runes | 3rd |
| Distant charting | 4th |
| Two more branches off the skill tree's root | 5th |
| Item filter | 6th |
| Abilities (coming later) | 7th |
| One more branch off the root | Each wall from the 8th |

### World
- Each ice wall's panel lists what it unlocks. What you unlock stays unlocked in every world after it.
- The orbs you have unlocked stay unlocked when you transcend.
- Gollux's cave only appears once you have broken the third wall.
- Distant charting lets you chart any tile you can see, fighting your way through every tile between.
- The item filter, in the settings, leaves behind loot below the rarity, material and item level you pick. It can also keep only ascended items.

### Runes
- Runes drop only in Gollux's cave, and Gollux always drops one.
- Spend a rune from a charted tile's panel. Its effect works in farm runs on that tile, not in camps, and lasts 100 kills.
- Rune of Unrest gives the tile a new modifier, and Rune of Stillness takes one away.
- Rune of Shifting rerolls the tiers of those modifiers, and Rune of Upheaval turns them into different ones.
- Rune of Depth makes the tile's enemies a level higher, and stacks.
- Rune of Ascent lets the tile's enemies drop ascended items.
- Runes only change the modifiers runes gave. A tile's own modifiers stay as they are.

### Drag & Drop
- Drag gear between the bag and the doll, and skill nodes from the bag onto the tree. The spots that can't take what you hold go dim, and a gold outline marks where it will land.
- The bag has a new tab for skill nodes.

### Heirlooms
- Name each heirloom when you make it.

### Leaderboards
- Two new boards: the most ice walls broken across all your worlds, and the deepest tile ever charted.
- The leaderboard button appears once you have broken an ice wall.

## v0.2.1 (2026-10-07)
- Changelog formatting

## v0.2.0 (2026-10-07)

### New modifiers
| Modifiers | Rolls on |
|---|---|
| Click Damage, Swing Damage, Elite Damage, First Blow Damage, Double Strike | Weapons |
| Bleed | Maces |
| Gold Find, Orb Find, Time on Hit, Experience, Elite Chance, Crit Chance, Crit Damage | Rings |
| All Attributes, Time on Hit, Armour, Dodge, Bleed | Amulets |
| Experience, Enemy First Blow Delay, Elite Blow Reduction, Tile Modifier Reduction, Enemy Health Reduction, Power, Fortune and Guard Skill Ranks | Helmets |
| Camp Earnings, Enemies per Fight, Thorns, Recoup | Body armour |
| Time on Block | Shields |
| Crit after a Dodge | Bucklers |
| Burn, Move Speed, Experience, Orb Find | Torches |

### Interface
- An item card shows an empty row for every modifier its piece still has room for.
- Filter the bag by slot with the new tabs. A level's bin and Sell all take only what the filter shows.
- Rename your hero with the pencil on the character page.
- Your damage figures flash and show the change when gear, skills or crafting move them.
- The character panel moves to the top right while the bag is open.
- The corner buttons stay up during fights, and a red dot marks one whose page has something new.
- Achievement cards show a bar toward the next rank.

### Towns
- The blacksmith shows the whole piece you hold up to him.
- Your doll stands at every town counter.
- Bounty cards always show the land level and the lands an enemy lives in.
- A kill on land too shallow for your bounty tells you so, and Claim takes you to the town.

### World
- A fallen ice wall leaves rubble on the map.
- Pinch a trackpad to zoom the map.
- New sounds for critical hits and for item and orb drops.

## v0.1.0 (2026-10-04)
- The first version.
