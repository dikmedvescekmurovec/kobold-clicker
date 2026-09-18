# Item bases: kinds and material tiers for every slot

## Context

Every slot has one base today (`LootTable.ITEMS`, eight rows), so a drop only differs by level, rarity and modifiers. The goal is PoE-style bases: each slot gets several **kinds** that play differently (sword average, dagger weak and fast, mace bleeds, two-hander slow and heavy and takes the offhand), and each kind comes in **material tiers** gated by item level. Decisions taken with the user: every slot now; a two-hander closes the offhand; bleed is a base stat that does not stack; kinds *and* tiers.

## Approach

### 1. `Scenes/Items/loot_table.gd` -- `KINDS` in, `ITEMS` built from it

- New `const KINDS`: kind id -> `slot`, `weight`, `stats`, `affixes`, `globals`, optional `power` (per-stat factor), optional `two_handed`, and `tiers` (the full item names, weakest first -- each base has its own name, as in PoE).
- `static var ITEMS := _build_items()` replaces the const, **same row shape as today** plus `kind`, `tier`, `power`. Every existing caller (`ITEMS[type]`, `slot_of`, `stats_of`, `Item.from_dict`, `UniqueTable` bases, 57 test mentions of "Wooden Sword") keeps working untouched. The eight current names are tier 0 of their kind with today's numbers, and their kind is listed first in its slot, so saves, uniques and `test_combat._commons/_farmed` (first item per slot) see no change.
- **Power is applied after `scale`, not to the base value.** `LEVEL_FLAT` adds a point of damage a level to every weapon alike, so a dagger written as `damage: 0.6` would be within 10% of a sword by level 10. `power_of(type, stat)` = kind factor x `1 + TIER_POWER * tier` (tier factor skips `CHANCE_STATS` and `RATE_STATS`); `Item.scaled_stats` multiplies by it -- the one place, so the smith's upgrade follows for free.
- `TIER_MIN_LEVEL := [1, 4, 7, 10]`, `TIER_POWER := 0.2` (dials). A kind may name its own `tier_levels` and per-tier `tier_stats` instead -- the torch is the one that does (`[1, 10]`, Sight 1 then 2).
- `_weighted(rng, level := 1)`: kind by weight (the same single draw as today), then a tier drawn evenly from the top two unlocked at `level` (no draw while only one is unlocked). `roll` settles rarity and level **before** type so the tier can be gated by the piece's own level. `VendorStock` (`Scenes/Town/vendor_stock.gd:95`) passes its level.
- Kind weights are chosen so each **slot's** share of drops stays what it is today.
- New stat `bleed`: `STAT_LABELS` "Bleed", `PERCENT_STATS`, `CHANCE_STATS` (flat step only -- a share of a hit must not take the exponent, leech's reasoning), `LEVEL_FLAT` 1.0. Base stat of the mace only; no modifier rolls it yet.
- `icon_path` falls back to the kind's tier-0 icon while a file is missing (what `UniqueTable.icon` does), so code lands before the art is approved.

### 1b. The bases (69 in all: today's 8 and 61 new)

How to read this:

- Numbers are a level-1, tier-1 piece. A name marked *(today's)* is an existing piece and keeps its numbers, the torch aside.
- Tiers unlock at item level 1, 4, 7 and 10.
- A tier multiplies the quantity stats (damage, armour, health, energy shield, crit damage, move speed) by 1.0, 1.2, 1.4 and 1.6. Chances, rates, Bleed and Sight never move with a tier.
- "Share" is how often the kind comes up within its slot. Each slot's own share of all drops stays what it is today.

#### Weapon

All four share base damage 1 and differ by a damage factor applied after level scaling. Damage at level 10: sword 12, dagger 7, mace 11, greatsword 26 at tier 1, and 19, 11, 17, 41 at tier 4.

- **Sword** (share 1/3)
  - Tiers: Wooden Sword *(today's)*, Iron Sword, Steel Sword, Golden Sword
  - Base: damage factor 1.0, 5% Crit Chance, 50% Crit Damage, 1.0/s Attack Speed
  - Affixes: leech, life on hit, strength
- **Dagger** (share 1/4)
  - Tiers: Bone Knife, Iron Dagger, Steel Stiletto, Golden Kris
  - Base: damage factor 0.6, 8% Crit Chance, 50% Crit Damage, 1.8/s Attack Speed
  - Affixes: leech, life on hit, dexterity
- **Mace** (share 1/4)
  - Tiers: Wooden Club, Iron Mace, Steel Morningstar, Golden Sceptre
  - Base: damage factor 0.9, 50% Crit Damage, 0.9/s Attack Speed, 20% Bleed
  - Affixes: leech, life on hit, strength
- **Greatsword**, two-handed (share 1/6)
  - Tiers: Wooden Greatsword, Iron Claymore, Steel Zweihander, Golden Greatsword
  - Base: damage factor 2.2, 5% Crit Chance, 75% Crit Damage, 0.5/s Attack Speed
  - Affixes: leech, life on hit, strength

On auto-swings the dagger, the sword and the greatsword come out about even. The dagger is the idler's weapon; the greatsword is the clicker's (a click deals `damage`) and pays for it with a socket.

#### Offhand

- **Shield** (share 5/12)
  - Tiers: Wooden Shield *(today's)*, Iron Shield, Steel Kite Shield, Golden Aegis
  - Base: 3 Armour, 5% Block Chance
  - Affixes: health, energy shield, strength
- **Buckler** (share 4/12)
  - Tiers: Hide Buckler, Iron Buckler, Steel Targe, Golden Buckler
  - Base: 3% Dodge Chance, 4% Block Chance
  - Affixes: health, armour, dexterity
- **Torch** (share 3/12)
  - Tiers: Wooden Torch *(today's)*, 1 Sight, from item level 1; **Blazing Torch**, 2 Sight, from item level 10. Two tiers, not four: Sight is the whole piece, and it only has two values.
  - Base: Sight and nothing else. A level never moves it; only the tier does.
  - Affixes: block chance, energy shield, health regen, crit damage, intelligence. Flat modifiers only: there is no base number for a percent one to scale.

#### Helmet (share 1/3 each)

- **Helm**
  - Tiers: Leather Helmet *(today's)*, Iron Helmet, Steel Helm, Golden Helm
  - Base: 3 Armour, 5 Health
  - Affixes: energy shield, strength, intelligence
- **Hood**
  - Tiers: Hide Hood, Leather Hood, Studded Hood, Shadow Hood
  - Base: 3% Dodge Chance, 5 Health
  - Affixes: armour, dexterity, intelligence
- **Hat**
  - Tiers: Apprentice Hat, Wizard Hat, Sage's Hat, Archmage's Hat
  - Base: 5 Energy Shield, 0.5/s Health Regen
  - Affixes: health, armour, intelligence

#### Body (share 1/3 each)

- **Plate**
  - Tiers: Wooden Armor *(today's)*, Iron Armor, Steel Plate, Golden Plate
  - Base: 5 Armour, 10 Health
  - Affixes: energy shield, dodge chance, strength
- **Jerkin**
  - Tiers: Hide Jerkin, Leather Jerkin, Studded Jerkin, Shadow Leathers
  - Base: 4% Dodge Chance, 10 Health
  - Affixes: armour, energy shield, dexterity
- **Robe**
  - Tiers: Linen Robe, Silk Robe, Sage's Robe, Archmage's Robe
  - Base: 8 Energy Shield, 1.0/s Health Regen
  - Affixes: health, dodge chance, intelligence

#### Boots (share 1/3 each; every boot keeps Move Speed)

- **Boot**
  - Tiers: Leather Boot *(today's)*, Studded Boot, Ranger's Boot, Shadow Boot
  - Base: 5% Move Speed, 2% Dodge Chance
  - Affixes: armour, health, dexterity
- **Greaves**
  - Tiers: Bronze Greaves, Iron Greaves, Steel Greaves, Golden Greaves
  - Base: 4% Move Speed, 3 Armour
  - Affixes: health, dodge chance, strength
- **Slippers**
  - Tiers: Linen Slippers, Silk Slippers, Sage's Slippers, Archmage's Slippers
  - Base: 5% Move Speed, 4 Energy Shield
  - Affixes: health, health regen, intelligence

#### Ring and amulet (rings share 1/3 each, amulets 1/4 each)

One tier per kind: PoE's jewellery is untiered, and there is one drawing of each, so the kinds are gem and metal recolours. All seven keep the globals damage and attack speed.

- **Gold Ring** *(today's)*
  - Base: 5% Drop Rate. Life on Hit comes off it (rings already held keep theirs).
  - Affixes: as now, plus item rarity
- **Iron Band**
  - Base: 6 Health, 2 Armour
  - Affixes: health regen, damage, crit chance, crit damage, strength, dexterity, intelligence, item rarity
- **Jade Ring**
  - Base: 2% Dodge Chance, 0.5/s Health Regen
  - Affixes: health, damage, crit chance, crit damage, strength, dexterity, intelligence, item rarity
- **Ruby Amulet** *(today's)*
  - Base: 8 Health, 10% Crit Damage
  - Affixes: as now, plus item rarity
- **Gold Amulet**
  - Base: 20% Gold Find -- the first ordinary piece to show it
  - Affixes: health, energy shield, health regen, crit chance, crit damage, damage, drop rate, leech, strength, dexterity, intelligence, item rarity
- **Sapphire Amulet**
  - Base: 8 Energy Shield, 0.5/s Health Regen
  - Affixes: health, crit chance, crit damage, damage, drop rate, leech, strength, dexterity, intelligence, item rarity
- **Emerald Amulet**
  - Base: 5% Dodge Chance
  - Affixes: health, energy shield, health regen, crit chance, crit damage, damage, drop rate, leech, strength, dexterity, intelligence, item rarity

#### Notes on the table

- Only damage, crit, attack speed, drop rate, Bleed and Sight do anything today. The armour, dodge and energy shield split is PoE's and waits, as those stats already do, on something that can hurt the player.
- The Wooden Torch loses its energy shield, regen and crit damage. Torches already held keep the numbers they rolled (pieces are frozen) and have no Sight.
- **Item rarity becomes an affix on all jewellery, and gold find a base stat.** Both are skill-only today (`LEVEL_FLAT` 0, "no piece shows or rolls them"). New FLAT modifier `added_item_rarity` (10-25 against `added_drop_rate`'s 3-10, weight 4 like it); `item_rarity` joins `CHANCE_STATS` with a step of 1 a level, for drop rate's reason -- it multiplies weights. `gold_find` gets a step of 1 a level, and the unique-only `added_gold_find` names `level_flat` 0 so The Tithe's band does not move. The comments and any test that says no piece rolls them are updated.
- **Drop rate is the broad finder and the other two are narrow, so the narrow ones carry bigger numbers.** Drop rate lifts gear, uniques, orbs *and* gold; item rarity lifts only what rarity gear rolls; gold find only the purse. Hence 5% Drop Rate on the Gold Ring against 20% Gold Find on the Gold Amulet, and an item rarity modifier about two and a half times a drop rate one.
- The three uniques on the torch base (Hunter's Lantern, Overflowing Chalice, Lucky Wound) roll 1 Sight from now on instead of the old numbers.

### 2. Two-handers -- `equipment.gd`, `inventory.gd`, `bag_page.gd`, `item_details.gd`

- `Equipment.displaced_by(socket, item) -> Array[Item]`: the socket's piece, plus the offhand for a two-hander going on, plus a worn two-hander when an offhand goes on. `equip` returns that array (only `Inventory.equip` and tests call it). `from_dict` drops an offhand saved beside a two-hander.
- `Inventory.equip` refuses when `items.size() - 1 + displaced.size() > CAPACITY`; `BagPage` greys Equip with "The bag is full" in the tooltip (existing `_unequip_button` pattern).
- Doll: while a two-hander is worn the offhand socket draws its icon faded, and a press there selects the weapon socket.
- `ItemDetails.deltas` takes everything the swap takes off (`displaced_by`), so a greatsword's comparison counts the lost shield. "Two-handed" is written on the rarity line.

### 3. Bleed -- `Scenes/Combat/encounter.gd`

- `arm` reads `bleed`. In `_strike` after `hp -= dealt`: `_bleed = maxf(_bleed, dealt * bleed / 100.0)` (a new blow only replaces a weaker bleed). In `advance`, beside Heatstroke and through one shared helper: `hp -= _bleed * delta` while `WAITING`, `enemy_hit`, `_kill()` at zero with `_domino = false`. Cleared in `_advance_phase` with `_struck`. No clock involved, so runs need no special case.

### 3b. Drop rate reaches orbs and gold -- `Scenes/Combat/encounter.gd`

Today drop rate lifts gear (`LootTable.chance_for`) and uniques only. In `_kill`, two more lines read it, **added** to the narrow stat the way two globals add:

- the purse: `1.0 + (gold_find + drop_rate) / 100.0`
- the orb roll: `OrbTable.roll(..., orb_find + drop_rate)`

`gold_of` and `OrbTable.chance_for` themselves do not change, so town prices (quoted in bodies, with no player in them) stay where they are. Tests in `test_combat`: a worn drop rate fattens the purse and the orb rate by exactly its share; with none, both are what they were. `Scenes/CLAUDE.md`'s line on which stats do what is updated.

### 4. The torch sees further -- `loot_table.gd`, `Scenes/Map/map_builder.gd`, `main_scene.gd`

- New base stat `sight` ("1 Sight", "2 Sight" on the Blazing Torch), the torch's one base stat and nobody else's: `LEVEL_FLAT` 0 and listed in `CHANCE_STATS`, so a level never moves it. No modifier rolls it.
- `MapBuilder.chart(cell, sight := 1)`: the fog comes off every hidden tile within `sight` steps of the charted cell instead of its six neighbours (walk `HexGrid.neighbors` outward `sight` times). Returns the count as now.
- `main_scene` passes `1 + int(inventory.stats().get("sight", 0))` at both `view.chart` calls (`main_scene.gd:314`, `:696`). **It is read only at the moment a tile is charted**: putting a torch on reveals nothing, and taking it off hides nothing. A two-hander closes the offhand, so it costs the torch too.
- Tests: `test_generation` -- `chart(cell, 2)` shows the second ring, `chart(cell)` does not; `test_inventory` -- `sight` is on the torch and nothing else, is its only base stat, is still 1 on a level-30 Wooden Torch and 2 on a Blazing one, and no Blazing Torch rolls under item level 10.

### 5. Art -- `tools/ui_kit.py` (mockup first, per the standing rule)

- `GEAR_KINDS`: kind -> source tuple (unused "32 Free Weapon Icons", RPG pack Knife / Hammer / Wizard Hat etc.; armour silhouettes may be shared with a unique, as PoE does). `MATERIALS`: tier -> a `_shift` recolour recipe (existing function). Names generated from `KINDS`' tiers; 61 new 32x32 icons.
- Write only `tools/qa/ui_kit_gear.png` first and **get approval** before exporting to `Assets/Gear/`, then run the Godot import and keep the `.import` files.

### 6. Tests

- `test_inventory`: `_test_rolls` shares by **kind** at level 1, no tier above what the level unlocks, upper tiers at depth; `_test_slot_locks` by kind; power ordering at one level (dagger under sword under greatsword, each tier over the one before); two-hander equip / displace / full-bag refusal / load; an old "Wooden Sword" save loads unchanged. `_test_items` already walks every row and icon.
- `test_combat`: bleed ticks, does not stack, kills with no blow, is gone on the next enemy. Add a far-edge check with a **top-tier** plain set and tune `TIER_POWER` until the existing "8+ clicks a second" frontier line still holds.

### 7. Docs

`Scenes/Items/CLAUDE.md` + `DESIGN.md` (kinds, tiers, why power is post-scale), `Scenes/CLAUDE.md` (bleed is a live stat; equip can displace two), `Scenes/Combat/CLAUDE.md`, `tools/CLAUDE.md`, root `CLAUDE.md` ("the eight pieces").

## Execution: work packages for Opus subagents

Each package goes to one Opus subagent with this plan file (`item-bases-plan.md`), the section numbers it owns, the files it may touch and the suites it must run. Packages that run side by side own disjoint files, tests included. No agent commits.

- **A. Bases** (sections 1, 1b) -- first, alone
  - Owns: `loot_table.gd`, `modifier_table.gd`, `item.gd`, `vendor_stock.gd`, `test_inventory.gd`, `test_town.gd`
  - Runs: `python tests/run_all.py inventory town`
- **E. Art mockup** (section 5) -- alongside A
  - Owns: `tools/ui_kit.py`, `tools/qa/`
  - Runs: `python tools/ui_kit.py`, preview only
- **B. Two-handers** (section 2) -- after A
  - Owns: `equipment.gd`, `inventory.gd`, `bag_page.gd`, `item_details.gd`, `item_card.gd`, `test_inventory.gd`
  - Runs: `inventory ui_theme`
- **C. Fight** (sections 3, 3b) -- after A, beside B and D
  - Owns: `encounter.gd`, `test_combat.gd`
  - Runs: `combat`
- **D. Torch** (section 4) -- after A, beside B and C
  - Owns: `map_builder.gd`, `main_scene.gd`, `test_generation.gd`
  - Runs: `generation hex_map`
- **F. Docs** (section 7) -- after B, C and D
  - Owns: every `CLAUDE.md` and `DESIGN.md` named there

**What I do between packages** (the agents' reports are claims, not results):

1. Read the whole diff of the package against this plan: the numbers in 1b, the rules in each section, the repo's own rules in the folder `CLAUDE.md`s (one place a stat is spelled, whole-number modifier values, names on disk, comment voice and density matching the file).
2. Run the package's suites myself, and after B, C and D `python tests/run_all.py` whole, reading for `SCRIPT ERROR` as well as the exit code.
3. Anything short of that goes back to the same agent (SendMessage, so it keeps its context) with the file, the line and what is wrong; it is re-checked the same way. A package is done when I would have been content to have written it.
4. **E stops at the preview.** I show `tools/qa/ui_kit_gear.png` to the user; the export to `Assets/Gear/` and the Godot import happen only after approval, by the same agent.
5. Last, myself: the verification list below, including the UI screenshots.

## Not in this pass

- Uniques keep their current bases (Stonebreaker stays on the sword row); rebasing moves their numbers and the Pilgrim tests -- say so if wanted.
- No bleed modifiers or bleed uniques; no floating numbers for bleed ticks (the health bar moves).

## Verification

1. `--headless --path . --editor --quit` (class cache), then `python tests/run_all.py` -- all suites, no `SCRIPT ERROR`.
2. `--headless --path . -s res://tests/balance_town.gd` before and after: prices are per body, so they should not move.
3. `--path . -s res://tests/screenshot_ui.gd`: check `ui_item_card.png`, the comparison and the doll with a greatsword worn.
4. Play: debug Gold x10, buy from a gear vendor at depth, equip a greatsword over sword + shield with a full and a non-full bag, fight with a mace and watch the bar drain between blows.
