class_name TownWorld
extends RefCounted
## Where the towns of the world are and which of them are connected. Independent of the rendered map,
## which shows a window of this world.

enum Tier { SMALL, MEDIUM, FORTRESS }

## Sprite suffix for each Tier.
const TIER_NAMES := ["small", "medium", "fortress"]
const SIZE := Vector2i(256, 256)
## Chance per spot to become a town of each tier.
const TIER_CHANCES := {Tier.FORTRESS: 0.001, Tier.MEDIUM: 0.005, Tier.SMALL: 0.01}
## How many of its nearest towns a town of each tier connects to. Links go both ways, so a town can end up
## with more links than its own tier asks for.
const LINKS_PER_TIER := {Tier.SMALL: 1, Tier.MEDIUM: 2, Tier.FORTRESS: 4}
## Towns further apart than this many hex steps are never connected.
const MAX_LINK_DISTANCE := 20

var size: Vector2i

var _tiers: Dictionary[Vector2i, int] = {}
var _links: Dictionary[Vector2i, Array] = {}


## Every spot rolls for a town, except spots next to an existing town, so towns never touch.
static func generate(seed_value: int, world_size := SIZE) -> TownWorld:
	var world := TownWorld.new()
	world.size = world_size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in world_size.y:
		for x in world_size.x:
			var spot := Vector2i(x, y)
			var tier := _roll_tier(rng.randf())
			if tier != -1 and not HexGrid.neighbors(spot).any(world.has_town):
				world._tiers[spot] = tier
	world._connect_towns()
	return world


## The town's Tier, or -1 if there is no town.
func tier_at(spot: Vector2i) -> int:
	return _tiers.get(spot, -1)


func has_town(spot: Vector2i) -> bool:
	return _tiers.has(spot)


func towns() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_tiers.keys())
	return result


## Towns directly connected to the town at `spot`.
func connections(spot: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_links.get(spot, []))
	return result


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	return _links.has(a) and b in _links[a]


static func _roll_tier(roll: float) -> int:
	var threshold := 0.0
	for tier: int in TIER_CHANCES:
		threshold += TIER_CHANCES[tier]
		if roll < threshold:
			return tier
	return -1


func _connect_towns() -> void:
	# Buckets as large as the link distance: every town in range is in the same or an adjacent bucket.
	var buckets: Dictionary[Vector2i, Array] = {}
	for spot in _tiers:
		_links[spot] = []
		var bucket := spot / MAX_LINK_DISTANCE
		if not buckets.has(bucket):
			buckets[bucket] = []
		buckets[bucket].append(spot)

	for spot in _tiers:
		var nearby: Array[Vector2i] = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for other: Vector2i in buckets.get(spot / MAX_LINK_DISTANCE + Vector2i(dx, dy), []):
					if other != spot and HexGrid.distance(spot, other) <= MAX_LINK_DISTANCE:
						nearby.append(other)
		nearby.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := HexGrid.distance(spot, a)
			var distance_b := HexGrid.distance(spot, b)
			return distance_a < distance_b or (distance_a == distance_b and a < b))
		for other in nearby.slice(0, LINKS_PER_TIER[_tiers[spot]]):
			if not (other in _links[spot]):
				_links[spot].append(other)
				_links[other].append(spot)
