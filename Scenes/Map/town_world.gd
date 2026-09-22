class_name TownWorld
extends RefCounted
## Where the towns of the world are and which of them are connected. Laid out round the map's origin,
## ring by ring, since the rings of land are counted from there; the rendered map shows a window of it.

enum Tier { SMALL, MEDIUM, FORTRESS }

## Sprite suffix for each Tier.
const TIER_NAMES := ["small", "medium", "fortress"]
const SIZE := Vector2i(256, 256)
## The share of a ring's spots that hold a town of each tier, rounded per ring.
const TIER_CHANCES := {Tier.FORTRESS: 0.001, Tier.MEDIUM: 0.005, Tier.SMALL: 0.01}
## The width of a ring of land: `MapBuilder.START_LAND_RADIUS` and `WALL_STEP`, both 10, which TownWorld may
## not name (MapBuilder names it). `test_generation` holds them together. Counted in `WALL_STEP`s whatever the
## Ring of Walls says, the way `Encounter.walls_inside` counts: the land is the same land.
const RING := 10
## No town is generated nearer than this to the origin: `MapBuilder.START_TOWN_DISTANCE`, held together the
## same way, so the start clearing finds nothing and a ring's one fortress can never be cleared away.
const KEEP_OUT := 5
## How many of its nearest towns a town of each tier connects to. Links go both ways, so a town can end up
## with more links than its own tier asks for.
const LINKS_PER_TIER := {Tier.SMALL: 1, Tier.MEDIUM: 2, Tier.FORTRESS: 4}
## Towns further apart than this many hex steps are never connected.
const MAX_LINK_DISTANCE := 20
## Returned when no spot can hold a town.
const NO_SPOT := Vector2i(-1, -1)

var size: Vector2i
## The seed this world was generated with, so later insertions can stay deterministic.
var seed_value: int

var _tiers: Dictionary[Vector2i, int] = {}
var _links: Dictionary[Vector2i, Array] = {}
## Towns by spot / MAX_LINK_DISTANCE: every town within link range is in the same or an adjacent bucket.
var _buckets: Dictionary[Vector2i, Array] = {}


## Lays the towns out ring by ring round `origin`: each ring of land gets `round(spots * TIER_CHANCES)` of
## each tier, at least one fortress, on a seeded shuffle of its spots, never next to another town.
static func generate(seed_value: int, origin := SIZE / 2, world_size := SIZE) -> TownWorld:
	var world := TownWorld.new()
	world.size = world_size
	world.seed_value = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array[Array] = []
	for y in world_size.y:
		for x in world_size.x:
			var spot := Vector2i(x, y)
			var ring := ring_of(HexGrid.distance(origin, spot))
			if ring == -1:
				continue
			while rings.size() <= ring:
				rings.append([])
			rings[ring].append(spot)
	for spots: Array in rings:
		for i in range(spots.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: Vector2i = spots[i]
			spots[i] = spots[j]
			spots[j] = swap
		var next := 0
		for tier: int in [Tier.FORTRESS, Tier.MEDIUM, Tier.SMALL]:
			var want := roundi(spots.size() * float(TIER_CHANCES[tier]))
			if tier == Tier.FORTRESS:
				want = maxi(want, 1)
			while want > 0 and next < spots.size():
				var spot: Vector2i = spots[next]
				next += 1
				if not HexGrid.neighbors(spot).any(world.has_town):
					world._tiers[spot] = tier
					want -= 1
	world._connect_towns()
	return world


## Which ring of land a spot `steps` from the origin is in, counted the way `MapBuilder.ring_of` counts:
## 0 inside the first wall, n between the nth wall and the next. -1 inside the keep-out.
static func ring_of(steps: int) -> int:
	return -1 if steps < KEEP_OUT else maxi(0, ceili(float(steps - RING) / RING))


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


## Removes every town within `distance` steps of `center`, and the links pointing at them, so the nearest town
## ends up at least that far out. Returns how many were removed.
func clear_towns_near(center: Vector2i, distance: int) -> int:
	var removed: Array[Vector2i] = []
	for spot in _tiers:
		if HexGrid.distance(spot, center) < distance:
			removed.append(spot)
	for spot in removed:
		for other: Vector2i in _links.get(spot, []):
			if _links.has(other):
				_links[other].erase(spot)
		_links.erase(spot)
		_tiers.erase(spot)
		_bucket_for(spot).erase(spot)
	return removed.size()


## Makes sure one of `spots` has a small town and returns that spot (NO_SPOT if none can). A spot that already
## has one is kept, so this is idempotent; a new town never touches another and gets its links like any other.
func ensure_small_town(spots: Array[Vector2i]) -> Vector2i:
	for spot in spots:
		if tier_at(spot) == Tier.SMALL:
			return spot

	var free: Array[Vector2i] = []
	for spot in spots:
		if _in_bounds(spot) and not has_town(spot) and not HexGrid.neighbors(spot).any(has_town):
			free.append(spot)
	if not free.is_empty():
		var spot: Vector2i = free[absi(hash([seed_value, spots.size(), spots[0]])) % free.size()]
		_tiers[spot] = Tier.SMALL
		_links[spot] = []
		_bucket_for(spot).append(spot)
		_connect_one(spot)
		return spot

	# Every candidate is taken or boxed in by a neighbor, so turn a town that is already there into a small one.
	for spot in spots:
		if has_town(spot):
			_tiers[spot] = Tier.SMALL
			return spot
	push_warning("None of the %d candidate spots can hold a small town" % spots.size())
	return NO_SPOT


## The whole world as plain data, for the map save. Written down rather than regenerated because
## "a pure function of its seed" is a property of this code today, not a promise to the player:
## retuning TIER_CHANCES, or a change to Godot's own hash(), would otherwise move every settlement
## under land somebody had already walked.
##
## `spots` is flat [x, y, tier, ...] with the tier an index into `tiers`, which is written by name
## for the reason rarities are -- an enum value is only a position. `_links` is symmetric, so
## `links` holds each pair once, the lower spot first; from_dict fills both directions. `_buckets`
## is a spatial index over `_tiers` and is rebuilt rather than stored.
func to_dict() -> Dictionary:
	var spots: Array[int] = []
	for spot in _tiers:
		spots.append_array([spot.x, spot.y, _tiers[spot]])
	var links: Array[int] = []
	for spot in _links:
		for other: Vector2i in _links[spot]:
			if spot < other:
				links.append_array([spot.x, spot.y, other.x, other.y])
	return {
		"size": [size.x, size.y],
		"seed": seed_value,
		"tiers": TIER_NAMES,
		"spots": spots,
		"links": links,
	}


## The world `to_dict` wrote, or null if the data isn't one. A town whose tier is no longer a tier
## this build knows is dropped along with its links, rather than coming back as some other tier.
static func from_dict(data: Dictionary) -> TownWorld:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var world := TownWorld.new()
	var saved_size: Variant = data.get("size", [])
	if typeof(saved_size) != TYPE_ARRAY or saved_size.size() != 2:
		return null
	world.size = Vector2i(int(saved_size[0]), int(saved_size[1]))
	world.seed_value = int(data.get("seed", 0))

	# Tiers are resolved through the saved legend, so reordering Tier can't reinterpret a file.
	var legend: Array[int] = []
	for name: Variant in data.get("tiers", []):
		legend.append(TIER_NAMES.find(str(name)))
	var spots: Variant = data.get("spots", [])
	if typeof(spots) != TYPE_ARRAY or spots.size() % 3 != 0:
		return null
	for i in range(0, spots.size(), 3):
		var index := int(spots[i + 2])
		if index < 0 or index >= legend.size() or legend[index] == -1:
			push_warning("TownWorld: dropping the town at %s, whose tier this build has no name for"
					% Vector2i(int(spots[i]), int(spots[i + 1])))
			continue
		var spot := Vector2i(int(spots[i]), int(spots[i + 1]))
		world._tiers[spot] = legend[index]
		world._links[spot] = []
		world._bucket_for(spot).append(spot)

	var links: Variant = data.get("links", [])
	if typeof(links) != TYPE_ARRAY or links.size() % 4 != 0:
		return null
	for i in range(0, links.size(), 4):
		var a := Vector2i(int(links[i]), int(links[i + 1]))
		var b := Vector2i(int(links[i + 2]), int(links[i + 3]))
		if not (world._links.has(a) and world._links.has(b)):
			continue  # One end was dropped above; a link to nowhere is worse than no link.
		world._links[a].append(b)
		world._links[b].append(a)
	return world


func _in_bounds(spot: Vector2i) -> bool:
	return spot.x >= 0 and spot.y >= 0 and spot.x < size.x and spot.y < size.y


func _connect_towns() -> void:
	for spot in _tiers:
		_links[spot] = []
		_bucket_for(spot).append(spot)
	for spot in _tiers:
		_connect_one(spot)


## Links a town to as many of its nearest towns as its tier asks for.
func _connect_one(spot: Vector2i) -> void:
	var nearby: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other: Vector2i in _buckets.get(spot / MAX_LINK_DISTANCE + Vector2i(dx, dy), []):
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


func _bucket_for(spot: Vector2i) -> Array:
	var key := spot / MAX_LINK_DISTANCE
	if not _buckets.has(key):
		_buckets[key] = []
	return _buckets[key]
