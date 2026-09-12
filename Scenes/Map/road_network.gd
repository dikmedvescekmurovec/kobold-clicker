class_name RoadNetwork
extends RefCounted
## Routes roads between connected towns (see TownWorld). Every road leads to a town: a route runs from the edge
## of one town to the edge of another, whether or not the window shows both ends. Terrain plays no part, so the
## same world always gives the same roads.
##
## A road is an edge bitmask per world spot: bit `edge` is set when the road touches that HexGrid.Edge.

## How far outside the requested rect towns are collected and routes may wander.
const MARGIN := 8
## Extra cost per tile from a seeded jitter, which bends routes instead of leaving them ruler-straight.
const WANDER := 0.9
## Extra cost for a 120 degree turn, so a route doesn't zigzag for free.
const TURN_COST := 0.35


## Lays the roads of every link with a town in `rect` that `routed` doesn't hold yet, adding them to `roads`
## (an edge mask per world spot) and keying `routed` by link. Each link is routed inside its own box, around
## its two towns only, so a road never depends on the window it was first needed for: the map can grow without
## anything the player has already seen moving. `legal_masks` comes from HexTileset.legal_road_masks();
## `stats` counts the routes laid ("routes") and the links no legal route could serve ("skipped").
static func extend(towns: TownWorld, rect: Rect2i, legal_masks: Dictionary, roads: Dictionary[Vector2i, int],
		routed: Dictionary[String, bool], stats: Dictionary = {}) -> void:
	for link: Array in _links_in(towns, rect.grow(MARGIN)):
		var key := "%s%s" % link
		if routed.has(key):
			continue
		routed[key] = true
		if _route(towns, link[0], link[1], _box(link[0], link[1]), legal_masks, roads):
			stats["routes"] = stats.get("routes", 0) + 1
		else:
			stats["skipped"] = stats.get("skipped", 0) + 1


## Lays the one road that ends somewhere other than a town: from `town` to a plain cell, the map's center.
static func route_to_cell(towns: TownWorld, town: Vector2i, cell: Vector2i, legal_masks: Dictionary,
		roads: Dictionary[Vector2i, int]) -> bool:
	return _route(towns, town, cell, _box(town, cell), legal_masks, roads, false)


## The area one road is routed inside: the box around its two ends, with MARGIN to wander in.
static func _box(a: Vector2i, b: Vector2i) -> Rect2i:
	var corner := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(corner, (a - b).abs() + Vector2i.ONE).grow(MARGIN)


## The edges of a mask, in HexGrid.Edge order.
static func mask_edges(mask: int) -> Array[int]:
	var edges: Array[int] = []
	for edge in 6:
		if mask & (1 << edge):
			edges.append(edge)
	return edges


## Linked town pairs with at least one town in `area`, each pair once, in a stable order.
static func _links_in(towns: TownWorld, area: Rect2i) -> Array:
	var links: Array = []
	var seen := {}
	for spot in towns.towns():
		if not area.has_point(spot):
			continue
		for other in towns.connections(spot):
			var link: Array = [spot, other] if spot < other else [other, spot]
			var key := "%s%s" % link
			if not seen.has(key):
				seen[key] = true
				links.append(link)
	links.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return links


## Lays one road from the edge of `from_town` to the edge of `to_town`, if a legal route exists (A*).
## States are a cell plus the edge the route entered it through, so a tile's shape is decided as it is crossed.
## With `target_is_town` false, `to_town` is a plain cell and the road ends on it instead of at its edge.
static func _route(towns: TownWorld, from_town: Vector2i, to_town: Vector2i, area: Rect2i,
		legal_masks: Dictionary, roads: Dictionary[Vector2i, int], target_is_town := true) -> bool:
	var open := _Heap.new()
	var target_outside := target_is_town and not area.has_point(to_town)
	var cost: Dictionary[Vector3i, float] = {}
	var came_from: Dictionary[Vector3i, Vector3i] = {}
	for edge in 6:
		var cell := HexGrid.neighbor(from_town, edge)
		if not _usable(towns, cell, area):
			continue
		var state := Vector3i(cell.x, cell.y, (edge + 3) % 6)
		cost[state] = _cell_cost(towns, cell)
		open.push(cost[state] + _heuristic(cell, to_town), state)

	while not open.is_empty():
		var state := open.pop()
		var cell := Vector2i(state.x, state.y)
		var entry: int = state.z
		var existing: int = roads.get(cell, 0)

		if target_is_town:
			# Done as soon as a tile can legally carry an edge facing the target town.
			var to_target := _edge_toward(cell, to_town)
			if to_target != -1 and legal_masks.has(existing | (1 << entry) | (1 << to_target)):
				return _apply(_path_masks(came_from, state, to_target), legal_masks, roads)
		elif cell == to_town:
			# The road ends here, carrying only the edge it arrived through.
			return _apply(_path_masks(came_from, state, entry), legal_masks, roads)

		for turn: int in [3, 2, 4]:  # Straight ahead, then the two 120 degree curves. Sharper turns have no sprite.
			var out := (entry + turn) % 6
			if not legal_masks.has(existing | (1 << entry) | (1 << out)):
				continue
			var next := HexGrid.neighbor(cell, out)
			if not area.has_point(next):
				# The target town lies outside the area: leaving on its side is a valid ending, and the road
				# carries on towards it off-area.
				if not target_outside or HexGrid.distance(next, to_town) >= HexGrid.distance(cell, to_town):
					continue
				return _apply(_path_masks(came_from, state, out), legal_masks, roads)
			if not _usable(towns, next, area):
				continue
			var next_state := Vector3i(next.x, next.y, (out + 3) % 6)
			var next_cost: float = cost[state] + _cell_cost(towns, next) + (0.0 if turn == 3 else TURN_COST)
			if cost.has(next_state) and cost[next_state] <= next_cost:
				continue
			cost[next_state] = next_cost
			came_from[next_state] = state
			open.push(next_cost + _heuristic(next, to_town), next_state)
	return false


## The edges each cell of the finished route adds, walking back from the last tile.
static func _path_masks(came_from: Dictionary[Vector3i, Vector3i], last_state: Vector3i, last_out: int) -> Dictionary[Vector2i, int]:
	var added: Dictionary[Vector2i, int] = {}
	var state := last_state
	var out := last_out
	while true:
		var cell := Vector2i(state.x, state.y)
		added[cell] = added.get(cell, 0) | (1 << state.z) | (1 << out)
		if not came_from.has(state):
			return added
		# The previous cell was left through the edge facing this one.
		out = (state.z + 3) % 6
		state = came_from[state]
	return added


static func _apply(added: Dictionary[Vector2i, int], legal_masks: Dictionary, roads: Dictionary[Vector2i, int]) -> bool:
	# A route that crosses itself can still form a shape with no sprite, so check every cell before committing.
	for cell in added:
		if not legal_masks.has(roads.get(cell, 0) | added[cell]):
			return false
	for cell in added:
		roads[cell] = roads.get(cell, 0) | added[cell]
	return true


## Roads never run onto a town tile; they stop at its edge.
static func _usable(towns: TownWorld, cell: Vector2i, area: Rect2i) -> bool:
	return area.has_point(cell) and not towns.has_town(cell)


## The edge from `cell` to `target` if they are neighbors, else -1.
static func _edge_toward(cell: Vector2i, target: Vector2i) -> int:
	for edge in 6:
		if HexGrid.neighbor(cell, edge) == target:
			return edge
	return -1


## At least one tile per remaining step, so it never overestimates and A* stays optimal.
static func _heuristic(cell: Vector2i, to_town: Vector2i) -> float:
	return maxf(HexGrid.distance(cell, to_town) - 1, 0)


static func _cell_cost(towns: TownWorld, cell: Vector2i) -> float:
	return 1.0 + WANDER * (absi(hash([towns.seed_value, cell])) % 1000) / 1000.0


## Binary min-heap of (priority, state), the A* frontier.
class _Heap:
	var _items: Array = []

	func is_empty() -> bool:
		return _items.is_empty()

	func push(priority: float, state: Vector3i) -> void:
		_items.append([priority, state])
		var i := _items.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _items[parent][0] <= _items[i][0]:
				break
			_swap(parent, i)
			i = parent

	func pop() -> Vector3i:
		var top: Array = _items[0]
		var last: Array = _items.pop_back()
		if not _items.is_empty():
			_items[0] = last
			var i := 0
			while true:
				var smallest := i
				for child in [2 * i + 1, 2 * i + 2]:
					if child < _items.size() and _items[child][0] < _items[smallest][0]:
						smallest = child
				if smallest == i:
					break
				_swap(smallest, i)
				i = smallest
		return top[1]

	func _swap(a: int, b: int) -> void:
		var held: Array = _items[a]
		_items[a] = _items[b]
		_items[b] = held
