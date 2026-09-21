<!-- Loaded automatically when a file in this folder is read. The project overview and shared rules are in the root CLAUDE.md. -->

## Enemies (`Scenes/Enemies/`)

| File | Contents |
|---|---|
| `enemy_roster.gd` (`EnemyRoster`) | Every enemy under `Assets/Enemies`: its `Tier` (COMMON/ELITE/BOSS), its `Size`, its `Facing` (the packs disagree; `CombatActor` mirrors only the ones drawn facing right, so nobody walks in backwards), the environments it lives on, and its sheet per animation. Health is not written per enemy — `SIZE_HP` and `TIER_HP` multiply into `hp_modifier`, so the whole curve is tuned from two tables. `weight` is written per entry, because being numerous has little to do with being big: whole numbers on one absolute scale, commons 30-100, elites 8-20, bosses 1-4, bands that never overlap. `pick` draws weighted by it, and a slime at 100 is the commonest thing on every terrain. `frame` and `bounds` are measured, not guessed (see the gotcha below). `portrait(name)` is the first idle frame cut to the pixels it uses, for a bounty card |

## Rules and gotchas
- **The nine cave creatures (Rat, Bat, Pebble, Spiked Slime, Crab, Skull, Golem, Armored Golem, Gollux) live in `"cave"` alone,** `Encounter.DUNGEON_ENV`, which is no land on the map: only the dungeon fields them. Their strips are cut by `tools/cave_dungeon.py`, which prints each one's `frame` and `bounds`; the pack draws no attack for the Pebble and the Skull and no death for Gollux, which is allowed (an empty animation is skipped). In the dungeon their `size` is for show only -- a floor's health ignores it -- and Gollux is LARGE by eye, not HUGE by measurement, because he is as wide as he is tall and stood on his own nameplate.
- **Enemy sheet geometry is measured, not guessed:** frame widths run 32 to 245 px with no relation to the sheet height, and a greatest-common-divisor guess gets Dwarf Warrior and Mimic wrong. The frame width is the smallest divisor of every sheet width in the pack where each frame boundary lands on a fully transparent column; `test_enemies.gd` re-checks that against the sprites, so adding an enemy means measuring it the same way.
