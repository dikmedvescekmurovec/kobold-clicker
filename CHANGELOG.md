# Changelog

The newest version is first. Its heading is the version the game is: the web build shows what is listed
under it once, the first time a player starts this version (`main_scene.gd` `_show_changelog`). A version is
`## vX.Y.Z (YYYY-MM-DD)`, its sections `### Name`, and each change one line under them starting `- `,
written for players. A section may hold a two-column table instead (`| left | right |`, a header row, then
`|---|---|`): the game draws its rows as its own tables, the left column wrapping and the right kept short.

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
