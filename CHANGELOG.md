# Changelog

The newest version is first, and its heading is the version the game is: the web build shows every version
a player has not seen yet once, together, newest first (`main_scene.gd` `_show_changelog`). A version is
`## vX.Y.Z (YYYY-MM-DD)`, its sections `### Name`, and each change one line under them starting `- `,
written for players. A section may hold a two-column table instead (`| left | right |`, a header row, then
`|---|---|`): the game draws its rows as its own tables, the left column wrapping and the right kept short.

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
