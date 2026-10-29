<!-- Loaded automatically when a file in this folder is read. Rules only: the reasoning behind them is in Scenes/Combat/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Combat code (`Scenes/Combat/`)
A tile is taken by beating a lineup of enemies against a clock; a taken tile can be farmed endlessly with no clock, or **camped** -- that same run, played for the hours the game is shut on the best tile taken, an hour away paying what 3 min 45 s of active play does, finds and all, for one hour and one more a wall broken.
**The dungeon** is the third kind: a clock and a lineup that never ends, in depths of fifteen floors, and a depth is won only by killing the Gollux at the foot of it. **Read `DESIGN.md` here before changing the HUD's layout, what drops show as, or the fight profiles** -- it holds the why.

The bracket closing a rule names the heading in `DESIGN.md` that holds its full text (under "Reference", at the end); each file's long description is there too, under its name.

## Files
| File | Contents |
|---|---|
| `encounter.gd` (`Encounter`) | The rules, no nodes: the lineup of a tile, a farm run, the ice wall or the dungeon, the clock, blows, the enemies' strikes, deaths and what drops |
| `tile_mods.gd` (`TileMods`) | What land past the second wall does to its own fight, and what it pays |
| `curses.gd` (`Curses`) | The world curses as a table, what a set of them costs in skulls and which may be taken together |
| `fight_ledger.gd` (`FightLedger`) | What one fight has turned up and the one rule for when it is written; no nodes |
| `drops_view.gd` (`DropsView`) | A fight's finds as a grid of `ItemSlot`s with its orbs in a row under them; used by both the verdict panel and the loot popup |
| `camp.gd` (`Camp`) | The camp made for the hours the game was shut, all rules and no nodes |
| `camp_scene.gd` (`CampScene`) | The camp on screen, already paid: the tile's own backdrop under the night sky with nobody on it, and a centred panel |
| `combat_actor.gd` (`CombatActor`) | An `AnimatedSprite2D` built from a sheet at runtime, for both sides |
| `combat_scene.tscn` / `combat_scene.gd` (`CombatScene`) | The view, a `CanvasLayer` the main scene adds over the hidden map: the parallax backdrop, both fighters, the numbers, what a body throws; it makes the HUD (`hud`) and tells it what happened |
| `fight_hud.gd` (`FightHud`) | Everything over the arena, one Control named "HUD": the place, pips and clock, the nameplate, the loot counter and Terminate, the loot popup, the verdict |
| `fight_sounds.gd` (`FightSounds`) | A fight's sounds, a player each under one node the view makes: which blow and crit a weapon lands with, which sound a find lands with |

`EnemyRoster` is in `Scenes/Enemies/`. Effects (`burst`, `hit_stop`, `shake`) come from `Juice` in `Scenes/UI/`.

## Rules

### Order and single paths in `Encounter`
- **`wear` before `arm` before `start`.** `effects` set by hand does all but take the curses on, at rank I; `arm` may run again mid-fight (the main scene's `_rearm`), starting from the stats and moving the clock by `_clock_more`, never refilling it. (DESIGN.md: "`wear` before `arm` before `start`")
- **`_append_enemy` is the one place an enemy joins a fight,** from `tier_for(position)`. Ask `EnemyRoster.tier_of`, never "is it the last one": a run's elites come round forever. No land profile rolls a boss since 2026-10-29 (a settlement's ends on an elite): a lair, the wall and a chest set theirs by hand, and only the dungeon rolls one, its Gollux. (DESIGN.md: "Boss lairs (2026-10-29)")
- **A stat that lands on a field of its own name is a row of `ARM_STATS`** (the stat -> the most it may be, never under nought; `ARM_SECONDS` for the ones kept in tenths), which `arm` sets through `set`. So there is no `armor = ` to grep for, and a new plain stat is a row and a `var`. (DESIGN.md: "`wear` before `arm` before `start`")
- **`_health_of` is the one place a body's starting health is worked out;** it is sized again (`_size_again`) only under a curse that moves health, so a fight built by hand keeps its own. The ice wall answers there to `WALL_HP` and the Long Winter and to nothing else. (DESIGN.md: "A curse is one `if`")
- **`_shape` is the once-a-fight say over the rolled lineup** (`_promoted`): the count, health only where the gear moved it, then the elite chance. (DESIGN.md: "Defence-slot lines are read in `arm`")
- **`_kill` is the one path to a death,** out of `_strike` because a wound and Dominoes' carry kill with no blow; the per-enemy flags are cleared in `_advance_phase`. (DESIGN.md: "`_kill` is the one path to a death")
- **`_pay` is everything a land body leaves, and its steps stay in the order their generators are drawn and their signals go out:** the chest's toss, `_drop_gear`, `_drop_purse`, experience, `_drop_unique`, the Hourglass, `_drop_orb`, `_drop_stone`. `_roll_gear` and `_roll_unique` are the only calls to `LootTable.roll` and `UniqueTable.roll` here but `_even_find`'s forced one. (DESIGN.md: "`_kill` is the one path to a death")
- **A lair pays its boss's unique and its experience, nothing else** (`for_lair`, `lair`, `_pay_lair`): every time, at a boss's drop level, whatever is unlocked or owed. (DESIGN.md: "Boss lairs (2026-10-29)")
- **`_wear_down` is the one path for damage nobody dealt:** `WAITING` only, and a death that way sets `_domino = false`. (DESIGN.md: "`_wear_down` is the one path for damage nobody dealt")
- **`enemy_died` goes out before the body's loot is rolled and `kill_paid(index)` once all of it has gone out,** so whatever changes what the next body pays waits for `kill_paid`. (DESIGN.md: "encounter.gd")
- **`tier_in(slot)` is the tier both `KillPips` and `HealthBar` read.**
- **The lineup is seeded from the cell; loot is not.** `loot_rng` / `orb_rng` are unseeded, so re-fighting a tile drops something else. Tests seed them. `always_drop` exists for tests and screenshots only.
- **`guarantee_elite` (an elite's certain piece) is set by nothing in the game, like `always_drop`.**

### The clock and the enemies' strikes
- **An endless run has no clock and no loss.** `advance` leaves `time_left` alone while `endless`; a run ends only by `stop()` or `give_up()`. Anything reading `time_left`, `remaining()` or `enemies` must ask `endless` first, and the lineup grows, so `lineup.size()` is its only honest end.
- **A body already going down when a fight ends is a kill** (`_end`, the one way the clock, `stop()` and `give_up()` end a fight): its health ran out first, so it is counted whatever the frame rate, the last body of a tile's wins the fight (`_winning`, with no save spent on it), and Gollux felled there is his depth won.
- **Keep `advance`'s clock order:** what `recoup` owes is paid before the clock runs, and a blow takes only what the clock still had (`_struck_by`'s `off`). (DESIGN.md: "Keep `advance`'s clock order")
- **Nothing strikes a missing clock, or a wall:** `_be_struck` asks `strikes` (the main scene's, off in a hand-built fight), `endless` and `WALL_NAME` first; time on hit asks `endless`. The strikes' dials are `HIT_SECONDS`, `HIT_GROWTH`, `HIT_WALL_GROWTH`, `ARMOUR_K` and `DODGE_K`. (DESIGN.md: "Nothing strikes a missing clock, or a wall")
- **A strike is a dodge, else the hit less armour's share less block** (`_struck_by`, `taken`), added to `wounds`; `test_combat._test_enemy_strikes` pins the user's example. (DESIGN.md: "encounter.gd")
- **Everything that wins clock back goes through `_win_back`, out of `wounds` and never more.**
- **Anything new that touches the clock must ask `endless` and must not be able to bank time.**
- **A save of the clock is once a fight each:** `second_wind` and `worry_stone` are read where the clock runs out in `advance`, the two adding up (`_saves_used`), never `endless`. (DESIGN.md: "`wear` before `arm` before `start`")
- **`walk_in` is the fight's own** (`WALK_IN`, doubled in a Mire, cut by the gear's `spawn_speed` in `arm` -- to nothing at 100%, so `arm` works from the const and the view guards the division): tests that play an unmodified fight still step by the const.
- **Both hands are capped** (the user's, 2026-10-03): `arm` clamps `attack_speed` to `SWING_CAP` last, and the scene's clicks go through `click()` (`CLICK_CAP`, `CLICK_BURST`), past which a click is nothing. Only the scene calls `click()`: tests and the camp call `hit()`, which is never capped. (DESIGN.md: "Both hands are capped")

### Blows and the gear's lines
- **Weapon lines are one sum, `gear_more`,** applied in `_strike` just before `unique_more` and never inside it. Double Strike (`crit_rng`) and Elite Chance (`_promote`, its own `elite_rng`) draw only while there is a chance, both clamped to 100, and Elite Chance never promotes in the dungeon. (DESIGN.md: "Weapon lines are one sum, `gear_more`")
- **Unique damage is one sum, `unique_more`,** applied once, never a multiplier of its own: a new damage unique adds a line to that sum, its ranked numbers its own row's (`UniqueTable`). (DESIGN.md: "Unique damage is one sum, `unique_more`")
- **The Serpent's Eye stays out of `unique_more`:** it is crit chance (`_serpent`), and one on each doll counts twice (the user's ruling). (DESIGN.md: "The Serpent's Eye stays out of `unique_more`")
- **Change `average_blow` with `_strike`:** it is `_strike` averaged, for the character page's and panel's damage per second and per click. (DESIGN.md: "Change `average_blow` with `_strike`")
- **Deepen a wound, never stack it:** `_bleed` is the greatest, set only where the body survived the blow. (DESIGN.md: "Deepen a wound, never stack it")
- **`arm` clamps crit chance to `CRIT_CAP`;** crit damage is what a crit *adds* (50 = half again). An auto-swing only lands while an enemy is standing, so nothing banks through a walk-in.
- **Dominoes' `_carried` is dealt as the next body takes its stand,** never to an elite or a boss (half at IV); Cleave's `_overkill` and a rank IV Headsman never fell a body. (DESIGN.md: "`_kill` is the one path to a death")
- **Defence-slot lines are read in `arm`** (2026-10-07), the three "less" lines stopping at `WARD_MOST`. `tile_ward` leaves the counts and a tile's pay untouched, `extra_enemies` never touches the last body, a run, the dungeon, a wall or a mimic, and `less_health` is on every body. (DESIGN.md: "Defence-slot lines are read in `arm`")
- **`beginners_luck` gives the Overflowing Chalice and the Serpent's Eye nothing:** the raw crit chance is `BEGINNERS_LUCK`. (DESIGN.md: "`wear` before `arm` before `start`")

### Drops
- **One listener to `loot_dropped`:** `CombatScene._on_loot_dropped`, the only place autodiscard is applied. A discarded find appears nowhere and is counted once under the verdict. (DESIGN.md: "One listener to `loot_dropped`")
- **A beaten gear roll rolls again,** to `MOST_DROPS` pieces off one body and never `guaranteed`. A certain roll never cascades: each leaves exactly one piece a roll. (DESIGN.md: "A beaten gear roll rolls again")
- **Drop rate is the broad finder and is *added* to a narrow one where they meet** (`_drop_purse`, `_drop_orb`): `gold_find + drop_rate` for the purse, `orb_find + drop_rate` for `OrbTable.roll`, the way two global percents add. `gold_of` and `OrbTable.chance_for` are untouched, so what a body is worth -- and so a town's prices -- does not move.
- **Gold does not step with the walls** (`base_gold(cell) * hp_modifier`); `gold_at_steps` lets `TownPrices` quote a price in bodies with no cell. (DESIGN.md: "encounter.gd")
- **Roll a promise only when owed** (`PROMISED`, `_due`; the rule is `Scenes/CLAUDE.md`'s), on the find's own generator. A promise is erased as its find falls, luck's too. (DESIGN.md: "Roll a promise only when owed")
- **Roll a unique beside the gear,** on `unique_rng`; autodiscard never applies to one, and `uniques_after` is `NO_UNIQUES` until the main scene sets it. Nothing promises one but a chest and the first, and the mimic never takes the ordinary roll (`MIMIC_UNIQUE`). (DESIGN.md: "Roll a unique beside the gear")
- **Pass `unlocked` to every `_roll_unique` here but the promised first's** (`Achievements.unlocked`); a fight nobody tells has none. (DESIGN.md: "Only the main scene reads `tally`")
- **Skill nodes roll on their own** (`SkillTree.roll`, `stone_rng`), only while `stone_drops` is on and never while the first node is owed. Neither a curse nor a unique that keeps gear from falling keeps a stone. (DESIGN.md: "Skill nodes roll on their own")
- **Orbs never enter `_drops`;** only the verdict hands them over, so every `_result_drops.fill` passes `fight.orbs`. (DESIGN.md: "Orbs never enter `_drops`")
- **`even_loot` replaces gear and unique rolls** (dev, `_even_find`); a chest keeps its own rules, and the purse and the orb are rolled as ever. (DESIGN.md: "`even_loot` replaces gear and unique rolls")
- **`FightLedger` holds the one rule for when a gain is written** (see `Scenes/CLAUDE.md`): a tile fight saves each, a run (`farming`) writes at `bank_kills`. `add_kill` says a bounty body by `bounty_counted`, or by `bounty_too_low` on land shallower than the posting's `level`, and one past `need` by neither. (DESIGN.md: "fight_ledger.gd")
- **`DropsView` never edits its own list:** with `discardable` it emits `discarded(item)`. (DESIGN.md: "drops_view.gd")

### Tile modifiers, runes and curses
- **Tile modifiers reach a fight one way:** `for_tile(.., mods)` / `farm(.., mods)`, shaped by `_take_mods` right after the profile and before the lineup is rolled, and paid in the tail of `arm()`. `farm` keeps only `TileMods.farmable`; a chest and the wall carry none. (DESIGN.md: "Tile modifiers reach a fight one way")
- **`TileMods.for_cell` is a pure function,** `MapBuilder.mods_of` its one caller; a modifier drawn twice is listed twice, and that is its tier (`once` rows never repeat). A tile's pay goes through `paid(percent, wild)`, so the panel and the fight cannot disagree. (DESIGN.md: "tile_mods.gd")
- **A farm run carries its tile's runes** in `mods` (`RuneTable`); a camp carries none of it. `forget_mod(id)` takes a worn-off modifier out from the next body on. (DESIGN.md: "A farm run carries its tile's runes")
- **A curse is one `if`** on `Curses.effect(id) in effects`, like a worn unique's; the ones that shape the fight are taken on once in `wear` (`_take_curses`). (DESIGN.md: "A curse is one `if`")
- **Lift a finished chance with `_lifted`,** never by adding points; Hard Lessons is a "less" too (`LESSONS_XP`). `_lean` draws on `loot_rng` only under its curse, so nobody else's loot stream moves, and never for the Broken Sword. (DESIGN.md: "Lift a finished chance with `_lifted`")
- **A curse that is a unique's rule adds in the unique's place** (the user's ruling): `unique_more`, `_glass()`, the Metronome's stilled click. `swings()` is the one answer to whether the weapon swings on its own; Pacifist Hands' swings are in `Inventory.stats()`, not here. (DESIGN.md: "A curse that is a unique's rule adds in the unique's place")
- **Raw Finds strips before `_lean`** (`_raw`, never a unique). A fight abroad under the Homeland rolls no gear -- but never a mimic or the wall, which are no land's. (DESIGN.md: "Raw Finds strips before `_lean`")
- **Write a curse's figure from the rule's own constant, never typed in twice.** Curses are capped by skulls, never by how many (`fits`, `allowed`), and `known(saved)` drops ids this build has not got. (DESIGN.md: "curses.gd")
- **A curse's `xp_more` is read by `Encounter.arm` alone;** its other `stats` are what `Inventory.stats()` adds. (DESIGN.md: "curses.gd")

### Uniques, ranks and achievements
- **A worn unique is one `if`** in `Encounter`, beside the capstones'; two of one ring are counted with `effects.count`. `hourglass` never pays past `seconds`, for a BOSS or while `endless`, and `tithe` makes no `LootTable.roll` at all. (DESIGN.md: "A worn unique is one `if`")
- **The lairs' uniques are one `if` each as well:** `challenge` in `_promote` (and `_take_challenge` once, after the Dreadmask), `torc` and `labrys` where a surviving body takes its wound, `chisel` at the wall. (DESIGN.md: "Boss lairs (2026-10-29)")
- **A rank IV line is one `if` beside its rule** (`_peak(id)`, `_home_peak()`). One that rolls draws only under its piece at IV, and the clock ones ask `endless`. (DESIGN.md: "A rank IV line is one `if` beside its rule")
- **The Dreadmask is taken on once, before the curses** (`_take_dread`): commons off the front of a tile fight, never the last body, never `endless` or `dungeon`. (DESIGN.md: "`wear` before `arm` before `start`")
- **Only the main scene reads `tally`,** as the fight ends (`Achievements.record`). The camp's fights keep one nobody reads, which is why the camp counts nothing. (DESIGN.md: "Only the main scene reads `tally`")

### The dungeon and the ice wall
- **The dungeon measures damage only:** its health takes nothing of the roster's sizes, a tile's modifiers or a world's curses, nothing strikes, and `_kill` pays nothing but a rune (`runes_drop`). Every rule of it is one `if dungeon` in `Encounter`. (DESIGN.md: "The dungeon measures damage only")
- **A depth is won only when its Gollux has fallen** (`depth()`, `cleared()`, `gollux_hp()`). The clock runs and a click lands as in any fight (the user's rulings), and the clock running out is `_finish(true)`, an end and not a loss. (DESIGN.md: "The dungeon measures damage only")
- **`endless` stays false in the dungeon:** the four places that mean "the lineup grows" ask `dungeon` beside it (`_advance_phase`, `wear`, `KillPips.show_fight`, the view's Terminate). (DESIGN.md: "The dungeon measures damage only")
- **A descent has no ledger and banks no kills;** `_bank_depths` writes `inventory.dungeon_depth` and `inventory.dungeon_floors` on the way out of it and out of the game. Its view has no loot counter and no finds, and **Leave** in Collect's place. (DESIGN.md: "Cave layer 1 goes in front")
- **The ice wall has no growth term of its own** (`for_wall`): `hp_of(.., WALL_GROWTH)` already steps once per wall, and `WALL_HP` is the dial. From `LATE_WALL_FROM` on it is `LATE_WALL_BODIES` ordinary bodies, and every wall behind a cell multiplies its bodies by `LAND_GROWTH`. (DESIGN.md: "encounter.gd")

### The camp
- **A camp pays gold, experience and what its bodies drop** (the user's, 2026-10-11), but no bodies for a bounty board and nothing on `inventory.kills` or an achievement. `Camp` never touches an `Inventory`; the main scene pays it at start-up. (DESIGN.md: "camp.gd")
- **A camp's finds are fought for, never rolled from a table:** `Camp.finds` plays the run `make` sampled on until the camp's bodies have fallen, so every rule over a drop is the fight's own (the user's: all gear modifiers apply). A fight drops only what it was handed, which is how the main scene keeps a camp from a kind of find. (DESIGN.md: "camp.gd")
- **A camp holds the hours `make` is handed** (`WallUnlocks.camp_hours`: one, and one more a wall ever broken; the user's, 2026-10-11), written into it as `MOST`. An hour pays `IDLE_SHARE` of an hour's play, however many it holds. (DESIGN.md: "camp.gd")
- **A camp is never a second economy.** What it pays an hour is sampled off a real `Encounter.farm`, so every dial that moves what a tile is worth moves a camp with it and there is no figure here to keep in step. Nothing in `Camp` writes a number in gold.
- **The rates are worked out once and then it is arithmetic.** `make` samples at start-up, from the gear the save holds -- the gear the player shut the game in -- and `earned` is a sum over the hours since `Inventory.saved_at`.
- **Camp Earnings is more of everything, Restless of the gold and experience alone:** `make` puts the gear's line on the bodies too, and so on the finds. (DESIGN.md: "camp.gd")
- **A Restless camp is still arithmetic:** `Camp.make` reads the curse off the fight's `effects` and writes its `MOST`, `RESTLESS_SHARE` of the hours, into the camp. (DESIGN.md: "A Restless camp is still arithmetic")
- **`earned` is clamped to its `MOST` and never negative,** in whole coins as in whole experience and bodies. (DESIGN.md: "camp.gd")
- **The camp's screen is already paid and has nobody on it,** under the night sky whatever the clock says. Its finds are a `DropsView` that is a record only, and it writes no sentence but the cap's, on one line. (DESIGN.md: "camp_scene.gd")

### The view: backdrop and fighters
- **Cave layer 1 goes in front:** `_build_cave` lays 7 down to 2 behind the fighters and `_build` adds 1 after them; the pack's 0 is not exported. Every fight has the one scroll (`_scroll`), none of it at `Settings.Anim.NONE`. (DESIGN.md: "Cave layer 1 goes in front")
- **A settlement is held, not walked through** (`_walks_on`): nothing scrolls. What a body throws lies on `_ground_drops`, which `_scroll` slides with the ground. (DESIGN.md: "combat_scene.tscn / combat_scene.gd")
- **`layer_sprite` and `fit_layer` are the camp's and `tests/cover_art.gd`'s too.** (DESIGN.md: "combat_scene.tscn / combat_scene.gd")
- **Size a fighter with `_actor_height`** and snap it to `_snap(view)`, half the backdrop's pixel on a window held upright (`UITheme.narrow`), where the fight stands mid-window (`GROUND_UPRIGHT`). Anything placed on the ground asks `_ground()`, never `GROUND`. (DESIGN.md: "Size a fighter with `_actor_height`")
- **Lay the arena out again on a resize** (`_layout`, on the viewport's `size_changed`, as `CampScene`'s is). (DESIGN.md: "Lay the arena out again on a resize")
- **A `CombatActor`'s `position` is the middle of its feet.** Tint it through `self_modulate`, which leaves `modulate` to the hit flash. (DESIGN.md: "combat_actor.gd")
- **Draw the player's fighter from `Characters`** (`CombatScene.character`, set before `begin`; `setup_player(.., id)`), stood by its row's `stand` where it has one. No hero's swing runs longer than the kobold's (`SWING_FRAMES`), so `_swing` cuts back a time into it, not a frame. (DESIGN.md: "combat_actor.gd")

### The HUD, loot popup and verdict (`FightHud`, the scene's `hud`)
- **The HUD reads the Encounter and nothing of the scene's.** The scene tells it what happened (`keep`, `loot_changed`, `dress_nameplate`, `flash_clock`, `show_verdict`) and hears `back_pressed` / `retry_pressed`; the main scene sets `hud.hud_top`, `hud.hud_foot` and `hud.bag_room` and hears `hud.panel_up` and `hud.drop_discarded`. (DESIGN.md: "fight_hud.gd")
- **The fight's `HUD` is drawn over everything else in the fight** (`z_index` `RenderingServer.CANVAS_ITEM_Z_MAX`, the user's, 2026-10-03): a find, its beam, a coin, a gem, a number or a burst carries a `z_index` of its own, and never one that reaches it. `test_combat` holds a beam under it.
- **Everything in the HUD is placed by `_place_corners` every frame, not anchored:** it is scaled by `ui_scale`, which anchors know nothing about. Columns are centred, so a wider elite or boss bar grows evenly either side.
- **The HUD's corners keep to `UITheme.safe_rect`.**
- **HUD words stand on the backdrop with no panel:** use `FightHud.hud_label` (bone with a dark outline) and `BAR_BORDER`, never a plain `Label`.
- **Keep what the main scene stands over a fight off the HUD** (`hud_bottom()`, `corner_bottom()`, `hud_top`, `hud_foot`). Terminate is `stop()` for a run and `give_up()` for a tile fight; while `page_up` answers true, Escape is left to the bag. (DESIGN.md: "fight_hud.gd")
- **Dress the nameplate once per enemy,** in `dress_nameplate` (from the scene's `_on_enemy_coming`), never in `refresh`; a boss's plate pops in (`_plate_pop`) at `Settings.Anim.DEFAULT` only. A title is for show: bounties and everything else count `enemy_name()`. (DESIGN.md: "Dress the nameplate once per enemy")
- **Answer `player_hit` in `_on_player_hit`;** a flinch never cuts a swing off. Everything that floats off a fight goes through `_float_text`. (DESIGN.md: "Answer `player_hit` in `_on_player_hit`")
- **The clock bar is `KillPips.width_for(slots)` less its border,** so pips and clock are one column to the pixel.
- **Colours ramp, they do not switch:** `_clock_color` and the counter's face are both shares of the whole, so retuning `Encounter.SECONDS` or the bag's cap retunes them.
- **`Palette.GOLD` is the unique item step:** the verdict's gold total is in the panel's own colour behind a coin.
- **The loot popup is a summary and nothing more** (the user's, 2026-10-02): its `DropsView` is not `discardable`; the verdict's still is. The counter is never disabled. (DESIGN.md: "The loot popup is a summary and nothing more")
- **The verdict has no X** and is left through `leave`; the scene's `_on_back_pressed` itself is still immediate, which is what the tests call. (DESIGN.md: "The verdict has no X")
- **The verdict reads top to bottom:** the word, one row of sums (bare numbers, no `+`, the kills under `KILLS_MARK`, never a skull), finds and orbs, the autodiscard footnote, the way out; only a loss has a second line. A retry banks and opens like any other fight (`_on_combat_retry`). (DESIGN.md: "The verdict reads top to bottom")
- **`auto_collect` leaves through the same `leave` as Collect,** never for a run. It is a Timer child, so a tip holds it too, and `Juice.pop_out` leaves once, so a press first wins. (DESIGN.md: "`wear` before `arm` before `start`")
- **Run `_fit_window` before the verdict and the loot popup are centred** (`DropsView.fit_rows`, still ending on a half row). (DESIGN.md: "drops_view.gd")

### Sounds and the animation level
- **Set `weapon_kind` before `begin`:** the view makes its `FightSounds` from it. A crit plays instead of the blow: `BLUNT_CRIT` bare-handed or blunt, `SLASH_CRIT` for a blade (the user's ruling), with `GENERAL_CRIT` over it (the user's pairing, 2026-10-06). (DESIGN.md: "fight_sounds.gd")
- **A won fight's verdict plays nothing** (the user's ruling, 2026-10-02). A find sounds as it lands (`CombatScene._land`), by `FightSounds.drop_sound_of` (the user's, 2026-10-06), and takes of one sound are one `Juice.takes` pool. (DESIGN.md: "fight_sounds.gd")
- **The animation level thins the view, never the fight** (`Settings.animations`): anything new that is only for show asks the level; anything that carries an amount must not be behind it. (DESIGN.md: "The animation level thins the view, never the fight")
- **The `hit_stop` that ends last wins** (`Juice.hit_stop`); the unique banner raises none of its own. (DESIGN.md: "The `hit_stop` that ends last wins")

## Gotchas
- **`flip_h` does not mirror `offset`:** it flips the picture inside its box. `CombatActor._finish` negates `offset.x` for a mirrored fighter, and anything placed as its child (the shadow) is mirrored by hand. Before 2026-09-30 every mirrored enemy stood off `ENEMY_X` by twice its frame's off-centre.
- **Tint the loot counter's styleboxes, not the Button:** `modulate` would take the icon and the count with it (`_tint_loot_button`, one copy per `UITheme.STATES`).
- **At `GROUND` everyone floated in the cave:** its floor lies lower than a backdrop's grass band (`CAVE_GROUND`). (DESIGN.md: "Cave layer 1 goes in front")
- **Block and time on hit arrive in tenths:** `arm` converts them with `LootTable.seconds_of`. (DESIGN.md: "`wear` before `arm` before `start`")
- **Size the `DropsView` box by counting rows:** the grid is not laid out yet when `fill` runs. (DESIGN.md: "drops_view.gd")
- **Keep what is read off a texture's pixels in `CombatActor._read`:** reading one back from the GPU is slow. (DESIGN.md: "combat_actor.gd")
- **Grazing, Flush out, Heatstroke, the Frozen clock, Giantsbane and Restless dead went with the Pilgrim's set (2026-09-29).**
