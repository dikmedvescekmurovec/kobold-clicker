# New uniques for `Scenes/Items/unique_table.gd`

Read `Scenes/Items/CLAUDE.md`, `Scenes/Items/DESIGN.md`, `unique_table.gd` and `Scenes/Combat/encounter.gd` first.
Follow the rules the table already states:

- A unique is worn for its `effect`, which `Encounter` reads exactly as it reads a capstone's. It is meant to **lose to a crafted elite on raw numbers**.
- At most `MOST_MODS` (3) modifiers, all ids from `ModifierTable`. Only their values roll.
- `base` is a `LootTable.ITEMS` name. `envs` are from grass / forest / desert / ice / mountains / dirt (`[]` = anywhere).
- `effect_text` is in the game's voice: plain sentences, no dashes, no system words ("pouch", "autodiscard"), nothing Pixellari cannot draw.
- One new effect id each, handled in `Encounter` beside `metronome` / `headsman` / `hourglass`. Anything only for show asks `Settings.animations`; anything carrying an amount must not.
- Each effect gets a test in `tests/test_combat.gd` (seeded `loot_rng`, harness pattern). Run `python tests/run_all.py` before calling it done.
- Icons may come later: `UniqueTable.icon` already falls back to the base piece's.
- Already taken, do not duplicate: `metronome`, `headsman`, `knucklebone`, `tithe`, `hourglass`, `home:<env>`.
- The rows below put mods on pieces that cannot normally roll them, as the existing rows do (Rimeplate has `added_damage` on armour). If a test enforces legality for uniques, follow the test.

## Rows

```gdscript
	# --- Trade-offs ---
	"berserkers_band": {
		"name": "Berserker's Band", "base": "Gold Ring",
		"mods": ["added_damage", "added_crit_damage"],
		"effect": "berserk",
		"effect_text": "Your clicks deal triple damage. Your weapon never swings on its own.",
		"envs": ["mountains", "ice"],
	},
	"glass_edge": {
		"name": "Glass Edge", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_crit"],
		"effect": "glass_edge",
		"effect_text": "Double damage. The clock runs a third faster.",
		"envs": ["ice", "desert"],
	},
	"gamblers_die": {
		"name": "Gambler's Die", "base": "Ruby Amulet",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "gamble",
		"effect_text": "Every blow deals anywhere from almost nothing to three times its worth.",
		"envs": [],
	},
	"ascetics_cord": {
		"name": "Ascetic's Cord", "base": "Ruby Amulet",
		"mods": ["global_increased_damage"],
		"effect": "ascetic",
		"effect_text": "15% more damage for every place on you that is bare.",
		"envs": ["desert", "mountains"],
	},

	# --- The clock ---
	"last_gasp": {
		"name": "Last Gasp", "base": "Leather Helmet",
		"mods": ["added_crit", "increased_health"],
		"effect": "last_gasp",
		"effect_text": "Triple damage while five seconds or fewer remain.",
		"envs": ["dirt", "forest"],
	},

	# --- Crits and the lineup ---
	"duelists_buckler": {
		"name": "Duelist's Buckler", "base": "Wooden Shield",
		"mods": ["added_crit_damage", "increased_block"],
		"effect": "opening_strike",
		"effect_text": "Your first blow against every enemy is a critical strike.",
		"envs": ["grass", "forest"],
	},
	"overflowing_chalice": {
		"name": "Overflowing Chalice", "base": "Wooden Torch",
		"mods": ["added_crit", "increased_crit_damage"],
		"effect": "overcrit",
		"effect_text": "Critical chance past the most you can have becomes critical damage.",
		"envs": [],
	},
	"dominoes": {
		"name": "Dominoes", "base": "Leather Boot",
		"mods": ["added_damage", "increased_move_speed"],
		"effect": "domino",
		"effect_text": "An enemy felled in one blow costs the next a fifth of its health.",
		"envs": ["grass", "dirt"],
	},
	"snowball": {
		"name": "Snowball", "base": "Wooden Armor",
		"mods": ["increased_armor", "added_damage"],
		"effect": "momentum",
		"effect_text": "2% more damage for every kill this fight.",
		"envs": ["ice"],
	},
	"packmule": {
		"name": "Packmule's Harness", "base": "Wooden Armor",
		"mods": ["increased_health", "added_drop_rate"],
		"effect": "packmule",
		"effect_text": "1% more damage for every piece in your bag.",
		"envs": ["mountains", "dirt"],
	},

	# --- Dead stats given a job (armor, health and block do nothing otherwise) ---
	"bulwark": {
		"name": "Bulwark", "base": "Wooden Shield",
		"mods": ["increased_block", "added_block"],
		"effect": "riposte",
		"effect_text": "Your chance to block is your chance to swing again at once.",
		"envs": ["mountains"],
	},
	"heartwood_plate": {
		"name": "Heartwood Plate", "base": "Wooden Armor",
		"mods": ["increased_health", "added_health"],
		"effect": "heartwood",
		"effect_text": "Every hundred health you have is a second more on the clock.",
		"envs": ["forest"],
	},
	"spiked_helm": {
		"name": "Spiked Helm", "base": "Leather Helmet",
		"mods": ["increased_armor", "added_armor"],
		"effect": "spikes",
		"effect_text": "A hundredth of your armour is added to your damage.",
		"envs": ["desert", "mountains"],
	},

	# --- Loot ---
	"magpies_band": {
		"name": "Magpie's Band", "base": "Gold Ring",
		"mods": ["added_drop_rate", "added_gold_find"],
		"effect": "magpie",
		"effect_text": "One purse in twenty is a piece of gear instead.",
		"envs": ["forest", "grass"],
	},
	"lucky_wound": {
		"name": "Lucky Wound", "base": "Wooden Torch",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "lucky_wound",
		"effect_text": "An enemy you have struck critically rolls its drop twice and keeps the better.",
		"envs": [],
	},
	"rag_and_bone_sack": {
		"name": "Rag and Bone Sack", "base": "Wooden Armor",
		"mods": ["added_gold_find", "increased_health"],
		"effect": "salvage",
		"effect_text": "Gear you throw away pays a quarter of its price.",
		"envs": ["dirt"],
	},
```

## Notes per effect

| Effect | Where it lands | Watch for |
|---|---|---|
| `berserk` | `hit()` x3, skip the auto-swing in `advance` | Worn with Metronome means no damage at all. Let it be so, the texts say so. |
| `glass_edge` | damage x2 in `arm`, `time_left -= delta * 1.33` | Must ask `endless` first: a farm run has no clock, so there it is free damage. **Open: ask the user whether that is wanted.** |
| `gamble` | multiply each blow by `rng.randf_range(0.01, 3.0)` | Use a seedable rng so tests can pin it. The mean is 1.5, which is the upside. |
| `ascetic` | count empty `Equipment` sockets when arming | The count must reach `Encounter` through `Inventory.stats()` / effects, not a node lookup. |
| `last_gasp` | damage x3 while `time_left <= 5` | Does nothing while `endless`. |
| `opening_strike` | per-enemy flag, cleared in `_append_enemy`'s walk-in | An auto-swing counts as a first blow too. |
| `overcrit` | in `arm`, before the `CRIT_CAP` clamp: the excess goes to `crit_damage` | One point of chance to how much damage is a dial; start at 1:2. |
| `domino` | on death, if the enemy died from full health in one blow | Stacks with `cleave`: apply the domino first, then the carried overkill. |
| `momentum` | `1 + 0.02 * kills()` | Unbounded on an endless run by design; cap it if the balance test complains. |
| `packmule` | bag count read once in `arm` | Does not grow mid-fight as drops land. Say nothing about it, simpler. |
| `riposte` | after a landed blow, roll `block_chance` for one more | The extra blow cannot itself riposte. |
| `heartwood` | `time_left += floor(health / 100)` in `arm` | Health scales with level, so check the far edge; may need "every N" to grow. |
| `spikes` | `damage += armor * 0.01` in `arm` | Added flat, before the percents. |
| `magpie` | in the gold drop: 1 in 20 rolls `LootTable.roll(guaranteed)` instead | The find goes out by `loot_dropped` so autodiscard still applies in its one place. |
| `lucky_wound` | per-enemy `crit` flag; roll twice, keep the higher rarity then level | Uniques and orbs roll on their own generators and are not doubled. |
| `salvage` | `CombatScene._on_loot_dropped`'s discard fork | The price comes from `TownPrices`, never a gold figure written here. **Open: ask the user whether a hand discard from `DropsView` pays too.** |

## Give the six home pieces a second clause

They all read "Double damage on X". Keep that and add one themed rule each, same effect id:

Suggestions:
Meadowstriders (boots, grass): speed, open ground

- Running start: on grass, enemies walk in twice as fast, so less of the clock is spent waiting.
- Trample: on grass, your first blow on each enemy lands during its walk-in. This breaks the "swings only land on a standing enemy" rule for this one piece.
- Second wind: on grass, a kill doubles your attack speed for two seconds.
- Well trodden: on grass, road tiles pay double purses. This is the only piece that would make roads matter.
- Grazing: on grass, the lineup is two enemies longer with the same clock. That means more bodies, more drops and more bounty kills, so it is the farming boot.

Hunter's Lantern (torch, forest): sight, tracking, ambush

- Flush out: in forest, the elite comes first instead of last. You fight it on a full clock and the rest is cleanup.
- Marked prey: in forest, elites always drop an item (the trophy capstone, but only in forest).
- Eyeshine: in forest, every fifth blow is a critical strike.
- Tracker: in forest, the monster your bounty asks for turns up twice as often. It hooks the lineup roll, not the board.
- Lantern light: in forest, you see what an enemy is carrying before it dies. A small glint shows on enemies that will drop an item. It does not add power, but a player would love it on a timed fight ("kill that one first" does not apply, but "keep going, the elite has something" does).

Sunscorched Cowl (helmet, desert): heat, mirage, endurance

- Heatstroke: in desert, enemies lose 2% of their health every second they stand. It is the game's only damage over time and it suits idle play.
- Mirage: in desert, one enemy in five is a mirage that dies to a single blow.
- High noon: in desert, you deal double damage in the first ten seconds of the clock, on top of the home bonus. This mirrors Last Gasp.
- Uncapped: in desert, your critical chance has no cap.
- Bleached bones: in desert, the bodies you leave pay their purse again when the fight is won.

Rimeplate (armour, ice): cold, stillness, brittleness

- Frozen clock: on ice, the clock stands still while an enemy walks in.
- Brittle: on ice, an enemy under half health takes double damage. It stacks well with Headsman.
- Shatter: on ice, a critical strike on a full-health enemy takes a quarter of its health.
- Permafrost: on ice, the clock starts five seconds longer for every piece of armour you wear. This gives the dead armour stat a job on its home ground.
- Cold snap: on ice, the first kill of a fight freezes the clock for three seconds.

Stoneward (shield, mountains): weight, stone, giants

- Avalanche: in mountains, damage past a kill carries on at double (cleave, but better). Without Whirlwind it grants plain cleave on mountains.
- Giantsbane: in mountains, the bonus against elites and bosses is triple, not double. Mountains become where you go to kill bosses.
- Bedrock: in mountains, your block chance is added to your critical chance. Another dead stat gets a job.
- Rockfall: in mountains, every tenth blow hits every enemy still to come for a tenth of its health. It is unusual, but it makes the pips move all at once.
- Echo: in mountains, each click lands again half a second later at half strength.

Gravedigger's Charm (amulet, dirt): graves, digging, the dead

- Grave goods: on dirt, every tenth body drops twice.
- Exhume: on dirt, a fight won digs up one extra find, rolled at the elite's tier. You get it as a drop on the verdict screen.
- Restless dead: on dirt, a slain ordinary enemy has a one-in-ten chance to rise again at half health and pay again. That is more kills and more purses on the same clock, so it carries risk on a timed tile and is pure gain on a farm run.
- Deep pockets: on dirt, purses grow 1% for every kill this fight.
- Six feet under: on dirt, a blow that leaves an enemy under 15% kills it. It is a home Headsman, and the two add together.

Cross-cutting options (apply to all six the same way)

- Homesick: off its ground the piece does something small but real, like +10% damage anywhere, so it is not dead weight five tiles out of six. This is the cheapest fix to the "I never wear these" problem.
- Blends count: a tile with a blend overlay toward the home environment counts as home. Your click weights are already exported, so it could count only when the weight is at least 0.5, or scale the bonus by the weight. It makes border tiles valuable.
- Pilgrim set: wearing two home pieces makes each work on the other's ground as well. Wearing all six means everywhere is home. It is a collection goal that turns into a build, and it uses the uniques_found log you already keep.
- Settled ground: the bonus grows with how much of that environment you have charted: +1% per charted tile of the kind, capped at double. It rewards exploring one biome deeply instead of rushing outward.
- Home turf settlements: in a settlement on its ground, the piece also adds ten seconds to the clock. Settlement fights are the 60 s boss fights, so that is where a home piece should matter most.

My picks

These six each make a differently shaped fight:

- Grass: Grazing (longer lineup)
- Forest: Flush out (elite first)
- Desert: Heatstroke (damage over time)
- Ice: Frozen clock
- Mountains: Giantsbane (boss ground)
- Dirt: Restless dead (kills pay twice)

## Docs to update when done
- `Scenes/Items/CLAUDE.md`: the `unique_table.gd` row. Root `CLAUDE.md`: add `UniqueTable` to the Items line (it is missing today).
- Reasoning (why these lose to elites, why dead stats were given jobs through uniques rather than by making enemies hit back) goes in `Scenes/Items/DESIGN.md`, not `CLAUDE.md`.
