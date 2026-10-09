class_name Achievements
extends RefCounted
## The achievements, the uniques they unlock, and the ranks that grow those uniques.
##
## A unique drops only once it is unlocked (`unlocked`, which every fight is handed): the eight
## `STARTERS` from the first unique on, and every other one when its achievement is earned. An
## achievement is earned in **ranks**, I to IV (`UniqueTable.PEAK`), one a number in its `need`; rank I
## is the unlock, and every rank raises the numbers in its unique's rule (`UniqueTable.dial`). The rank
## is the player's and is read live (`rank`, `ranks`), so every copy of the unique they hold -- in the
## bag, on either doll, in a run's pouch -- is the stronger at once. The harder the achievement, the
## stronger the unique; once unlocked it still has to drop by luck, after `UniqueTable.FIRST_UNIQUE_KILLS`.
##
## Every achievement is one number reaching `need`: a count in `Inventory.tally` (kept by `record` as a
## fight ends and by `Inventory.tick` where the player does something), or a figure read off the player
## as they are (`state`), which `earn` also keeps at its best in the tally. `progress` takes the larger
## of the two, so the page, the check and a test read the same thing -- the best ever reached.
##
## What counts where is the user's ruling: counts add up in tile fights and farm runs; the streaks and
## the ice-wall feats are one fight's doing and count only in a tile fight, which has a clock; the camp
## counts nothing, and the dungeon only the depth it wins. The same const shape as `UniqueTable`: a
## table and statics, no state.

## In the pool before anything is earned: one a socket, plainly good early and outgrown by the frontier.
## They have no ranks.
const STARTERS := ["squires_blade", "wayfarers_torch", "novices_cap", "snowball", "couriers_boots",
		"magpies_band", "beginners_luck", "worry_stone"]

## The single fight's longest streaks (`Encounter.tally`), counted only in a tile fight.
const STREAKS := ["dry_streak"]
## A fight's counts that add up over every tile fight and farm run.
const COUNTS := ["clicks", "crits", "crit_kills", "bleed_kills", "blows_taken", "blocked"]
## How the page heads each tier.
const TIER_NAMES := ["", "First Steps", "The Walls", "Far Lands", "Legends"]
## What a rank is called where it is written.
const RANK_NAMES := ["", "I", "II", "III", "IV"]
## An ice wall named in an ask, from the middle out (`{nth}`).
const ORDINALS := ["first", "second", "third", "fourth", "fifth", "sixth"]
## Clean Sweep: the one-blow kills in a row, in one tile fight, that count the land it was fought on.
const DOMINO_STREAK := 10
## Keyed by the unique each one unlocks: its name, what it asks, its tier (1-4), the key its number is
## kept under and the four numbers its ranks need, easiest first. `text` writes the rank's number
## through `{need}` -- or `{nth}` where the number is an ice wall -- or is four sentences, one a rank.
## A key of `kills:<env>` counts the kills on that ground; one beginning `wall_` is a feat of a won
## ice-wall fight, kept as the furthest wall out it was done at (`record`).
const ACHIEVEMENTS := {
	# --- I: the first hour.
	"knucklebone_ring": {"name": "Drumroll", "text": "Click {need} times.",
			"tier": 1, "key": "clicks", "need": [1000, 10000, 100000, 1000000]},
	"duelists_buckler": {"name": "Sharp Eye", "text": "Land {need} crits.",
			"tier": 1, "key": "crits", "need": [100, 1000, 10000, 100000]},
	"serpents_eye": {"name": "Cold Streak", "text": "Land {need} blows in a row without a crit.",
			"tier": 1, "key": "dry_streak", "need": [30, 60, 100, 150]},
	"spiked_helm": {"name": "Tough Hide", "text": "Take {need} blows.",
			"tier": 1, "key": "blows_taken", "need": [500, 2500, 10000, 50000]},
	"ogres_knuckle": {"name": "Heavy Lifter", "text": "Reach {need} strength.",
			"tier": 1, "key": "strength", "need": [20, 75, 200, 500]},
	"fencers_signet": {"name": "Nimble", "text": "Reach {need} dexterity.",
			"tier": 1, "key": "dexterity", "need": [20, 75, 200, 500]},
	"packmule": {"name": "Overloaded", "text": "Carry {need} items in your bag.",
			"tier": 1, "key": "carried", "need": [40, 50, 60, 80]},
	"rag_and_bone_sack": {"name": "Scrapper", "text": "Discard {need} items.",
			"tier": 1, "key": "discarded", "need": [100, 500, 2500, 10000]},
	"butchers_cleaver": {"name": "Bloodletter", "text": "Kill {need} enemies with bleed.",
			"tier": 1, "key": "bleed_kills", "need": [100, 1000, 10000, 100000]},
	# --- II: the first walls.
	"meadowstriders": {"name": "Meadow Hunter", "text": "Kill {need} enemies in grassland.",
			"tier": 2, "key": "kills:grass", "need": [1000, 5000, 25000, 100000]},
	"hunters_lantern": {"name": "Woodland Hunter", "text": "Kill {need} enemies in forest.",
			"tier": 2, "key": "kills:forest", "need": [1000, 5000, 25000, 100000]},
	"sunscorched_cowl": {"name": "Dune Hunter", "text": "Kill {need} enemies in desert.",
			"tier": 2, "key": "kills:desert", "need": [1000, 5000, 25000, 100000]},
	"rimeplate": {"name": "Frost Hunter", "text": "Kill {need} enemies on ice.",
			"tier": 2, "key": "kills:ice", "need": [1000, 5000, 25000, 100000]},
	"stonebreaker": {"name": "Peak Hunter", "text": "Kill {need} enemies in mountains.",
			"tier": 2, "key": "kills:mountains", "need": [1000, 5000, 25000, 100000]},
	"gravediggers_charm": {"name": "Barrow Hunter", "text": "Kill {need} enemies in the barrens.",
			"tier": 2, "key": "kills:dirt", "need": [1000, 5000, 25000, 100000]},
	"lucky_wound": {"name": "Lucky Strikes", "text": "Kill {need} enemies with a crit.",
			"tier": 2, "key": "crit_kills", "need": [1000, 5000, 25000, 100000]},
	"bulwark": {"name": "Wall of Wood", "text": "Block {need} blows entirely.",
			"tier": 2, "key": "blocked", "need": [100, 500, 2000, 10000]},
	"patchwork_coat": {"name": "Motley", "text": "Wear {need} attribute modifiers at once.",
			"tier": 2, "key": "attribute_lines", "need": [10, 20, 30, 40]},
	"quickdraw_boots": {"name": "Rush", "text": "Reach {need} Spawn Speed.",
			"tier": 2, "key": "spawn_speed", "need": [50, 75, 100, 150]},
	"brawlers_wraps": {"name": "All-Rounder", "text": "Reach {need} strength and {need} dexterity.",
			"tier": 2, "key": "strength_and_dexterity", "need": [50, 150, 300, 600]},
	"dreadmask": {"name": "Dreaded", "text": "Kill {need} enemies.",
			"tier": 2, "key": "kills", "need": [5000, 25000, 100000, 500000]},
	# --- III: far lands.
	"last_gasp": {"name": "By a Hair", "text": "Break the {nth} ice wall with under a second left.",
			"tier": 3, "key": "wall_last_second", "need": [1, 2, 3, 4]},
	"ascetics_cord": {"name": "Travelling Light", "text": "Break the {nth} ice wall with three empty slots.",
			"tier": 3, "key": "wall_bare", "need": [1, 2, 3, 4]},
	"purists_seal": {"name": "Unadorned", "text": "Break the {nth} ice wall wearing no attribute modifiers.",
			"tier": 3, "key": "wall_pure", "need": [1, 2, 3, 4]},
	"dominoes": {"name": "Clean Sweep",
			"text": "Kill 10 enemies in a row, each with one blow, past the {nth} ice wall.",
			"tier": 3, "key": "domino_wall", "need": [1, 2, 3, 4]},
	"scholars_circlet": {"name": "Bookworm", "text": "Reach {need} intelligence.",
			"tier": 3, "key": "intelligence", "need": [100, 175, 300, 500]},
	"sages_abacus": {"name": "Mastery", "text": "Grow your skill tree to {need} nodes.",
			"tier": 3, "key": "mastery", "need": [6, 10, 15, 21]},
	"gamblers_die": {"name": "Gambler", "text": "Use {need} Orbs of Chaos.",
			"tier": 3, "key": "chaos", "need": [10, 100, 200, 500]},
	"the_tithe": {"name": "Hoarder", "text": "Hold {need} gold at once.",
			"tier": 3, "key": "gold", "need": [1e5, 1e7, 1e9, 1e11]},
	"heartwood_plate": {"name": "Ironclad", "text": "Reach {need} armour.",
			"tier": 3, "key": "armor", "need": [250, 1000, 2500, 10000]},
	"hourglass_amulet": {"name": "Thaw", "text": ["Break an ice wall.", "Break {need} ice walls.",
			"Break {need} ice walls.", "Break {need} ice walls."],
			"tier": 3, "key": "walls", "need": [1, 5, 20, 50]},
	"heirlooms_echo": {"name": "Legacy", "text": ["Transcend.", "Transcend {need} times.",
			"Transcend {need} times.", "Transcend {need} times."],
			"tier": 3, "key": "transcended", "need": [1, 3, 10, 25]},
	"nightwalkers": {"name": "Into the Dark", "text": "Break the {nth} ice wall.",
			"tier": 3, "key": "furthest_wall", "need": [3, 4, 5, 6]},
	# --- IV: legends.
	"metronome": {"name": "Hands Off", "text": "Break the {nth} ice wall without clicking.",
			"tier": 4, "key": "wall_no_clicks", "need": [1, 2, 3, 4]},
	"berserkers_band": {"name": "Bare Knuckles", "text": "Break the {nth} ice wall with no weapon in your hand.",
			"tier": 4, "key": "wall_no_weapon", "need": [1, 2, 3, 4]},
	"glass_edge": {"name": "Time to Spare", "text": "Break the {nth} ice wall with half its clock unused.",
			"tier": 4, "key": "wall_half_clock", "need": [1, 2, 3, 4]},
	"headsman": {"name": "Kingslayer", "text": ["Kill Gollux.", "Win depth {need} of the dungeon.",
			"Win depth {need} of the dungeon.", "Win depth {need} of the dungeon."],
			"tier": 4, "key": "depth", "need": [1, 3, 6, 10]},
	"overflowing_chalice": {"name": "Sure Thing", "text": "Reach {need}% crit chance.",
			"tier": 4, "key": "crit_chance", "need": [100, 150, 200, 250]},
	"crown_of_accord": {"name": "Balance",
			"text": "Reach {need} in all three attributes, each within a tenth of the others.",
			"tier": 4, "key": "accord", "need": [100, 200, 400, 800]},
	"zealots_brand": {"name": "Fanatic", "text": "Reach {need} in one attribute, with none in the other two.",
			"tier": 4, "key": "zealot", "need": [200, 400, 800, 1500]},
}


## The uniques that can drop for this player: the starters and those their achievements unlocked.
static func unlocked(inventory: Inventory) -> Array:
	return STARTERS + inventory.achievements.keys()


## Whether `id`, a unique, is in the drops.
static func is_unlocked(inventory: Inventory, id: String) -> bool:
	return id in STARTERS or inventory.achievements.has(id)


## The rank of `id` the player has earned, 0 for none.
static func rank(inventory: Inventory, id: String) -> int:
	return int(inventory.achievements.get(id, 0))


## Every rank the player has earned, id -> rank: what a fight is told (`Encounter.wear`) and what the
## cards write (`UniqueTable.ranks`). A copy, so neither can move the player's.
static func ranks(inventory: Inventory) -> Dictionary:
	return inventory.achievements.duplicate()


## The number `id` asks for at rank `at`.
static func need_at(id: String, at: int) -> float:
	var ladder: Array = ACHIEVEMENTS[id]["need"]
	return float(ladder[clampi(at, 1, ladder.size()) - 1])


## What `id` asks at rank `at`, as the page and the banner say it.
static func text(id: String, at := 1) -> String:
	var step := clampi(at, 1, UniqueTable.PEAK)
	var said: Variant = ACHIEVEMENTS[id]["text"]
	var sentence := str(said[step - 1]) if said is Array else str(said)
	var need := need_at(id, step)
	return sentence.format({"need": BigNumber.format(need),
			"nth": ORDINALS[clampi(int(need), 1, ORDINALS.size()) - 1]})


## The figures read off the player as they are, by key. Asked once a check and handed to `progress`.
##
## The attributes are what the gear itself adds up to over both dolls (`Inventory.gear_attributes`),
## before the Echo, the Crown and the Brand multiply them (the user's ruling, 2026-09-29): the Brand
## brings the two lower up to the highest, and would otherwise earn Balance on its own.
static func state(inventory: Inventory) -> Dictionary:
	var points := inventory.gear_attributes()
	var stats := inventory.stats()
	var values := [float(points["strength"]), float(points["dexterity"]), float(points["intelligence"])]
	var most: float = values.max()
	var least: float = values.min()
	# Dreaded: every kill on every ground, which is only ever counted where `record` counts.
	var kills := 0
	for key: String in inventory.tally:
		if key.begins_with("kills:"):
			kills += int(inventory.tally[key])
	return {
		"strength": values[0],
		"dexterity": values[1],
		"intelligence": values[2],
		"strength_and_dexterity": minf(values[0], values[1]),
		# Crown of Accord: all three together, and only while none is more than a tenth off the most.
		"accord": least if most - least <= most / 10.0 else 0.0,
		# Zealot's Brand: the one, and only while the other two are nothing at all.
		"zealot": most if values.count(0.0) == 2 else 0.0,
		"carried": float(inventory.items.size()),
		"attribute_lines": float(stats.get("attribute_lines", 0)),
		"spawn_speed": float(stats.get("spawn_speed", 0.0)),
		"crit_chance": float(stats.get("crit_chance", 0.0)),
		"armor": float(stats.get("armor", 0.0)),
		"gold": inventory.gold,
		# Mastery: the stones standing in the skill tree.
		"mastery": float(inventory.skills.stones.size()),
		"depth": float(inventory.dungeon_depth),
		"kills": float(kills),
		# Into the Dark: the furthest wall ever broken, in any world, off how far the land has reached.
		"furthest_wall": float(inventory.walls_ever()),
	}


## How far the player is with `id`: its count, or its figure out of `known` (`state`).
static func progress(inventory: Inventory, id: String, known: Dictionary) -> float:
	var key := str(ACHIEVEMENTS[id]["key"])
	return maxf(float(inventory.tally.get(key, 0)), float(known.get(key, 0.0)))


## Raises every achievement to the highest rank the player has reached -- several at once where the
## figures already stood past them -- writing each into `achievements` and `achievements_new`, and
## returns the ones that rose. Ranks only ever rise. Nothing is saved: the caller does.
static func earn(inventory: Inventory) -> Array[String]:
	var known := state(inventory)
	# Each figure read off the player kept at its best, so a card past IV says the most ever reached.
	for key: String in known:
		inventory.keep_best(key, known[key])
	var earned: Array[String] = []
	for id: String in ACHIEVEMENTS:
		var have := progress(inventory, id, known)
		var was := rank(inventory, id)
		var reached := was
		while reached < UniqueTable.PEAK and have >= need_at(id, reached + 1):
			reached += 1
		if reached > was:
			inventory.achievements[id] = reached
			if not inventory.achievements_new.has(id):
				inventory.achievements_new.append(id)
			earned.append(id)
	return earned


## What a finished fight counts: its counts and kills for a tile fight or a farm run, and -- a tile fight
## only -- its streaks, Clean Sweep's land and, where it broke an ice wall, the wall's feats. Never the
## dungeon, whose descent counts only the depth it wins (`Inventory.dungeon_depth`), and never the camp,
## which is not handed here.
static func record(inventory: Inventory, fight: Encounter) -> void:
	if fight.dungeon:
		return
	for key: String in COUNTS:
		inventory.tick(key, int(fight.tally.get(key, 0)))
	inventory.tick("kills:" + fight.env, fight.kills())
	if fight.endless:
		return
	for key: String in STREAKS:
		_best(inventory, key, int(fight.tally.get(key, 0)))
	# Clean Sweep: the land the streak was made on, counted in the walls behind it.
	if int(fight.tally.get("domino_streak", 0)) >= DOMINO_STREAK:
		_best(inventory, "domino_wall", Encounter.walls_inside(fight.cell))
	if not fight.victory or fight.lineup.is_empty() or fight.lineup[0] != Encounter.WALL_NAME:
		return
	# Which wall this was, from the middle out: its own ring counts none of itself.
	var wall := Encounter.walls_inside(fight.cell) + 1
	var feats := {
		"wall_last_second": fight.time_left < 1.0,
		"wall_bare": Equipment.NAMES.size() - inventory.equipment.worn.size() >= 3,
		"wall_pure": int(inventory.stats().get("attribute_lines", 0)) == 0,
		"wall_no_clicks": int(fight.tally.get("clicks", 0)) == 0,
		"wall_no_weapon": inventory.equipment.item_at(Equipment.Socket.WEAPON) == null,
		"wall_half_clock": fight.time_left >= fight.seconds / 2.0,
	}
	for key: String in feats:
		if feats[key]:
			_best(inventory, key, wall)


## Keeps the larger of what `key` already holds and `value`.
static func _best(inventory: Inventory, key: String, value: int) -> void:
	inventory.tally[key] = maxi(int(inventory.tally.get(key, 0)), value)
