class_name EnvironmentGenerator
extends RefCounted
## Procedurally assigns an environment to every cell of a map.
##
## Growth starts at one random cell and repeatedly fills a random cell touching the generated area.
## A new cell prefers the environments around it, favours neighboring regions that are still small,
## and never breaks the adjacency table. Regions still smaller than MIN_REGION_SIZE are merged into a neighbor at the end.
## Every pick and every merge leans towards the environments the new land has least of, so each covers about a sixth.

## Which environments may border each other, read from the spritesheet's own JSON meta env_adjacency
## (see AI-sprites-generator/README.md) so the generator can only produce borders the sprites can draw.
## Symmetric; an environment may always border itself, which can_border handles rather than the table.
static var _allowed: Dictionary[String, PackedStringArray]


static func allowed() -> Dictionary[String, PackedStringArray]:
	if _allowed.is_empty():
		_allowed = SheetMeta.env_adjacency()
	return _allowed

## Weight each generated neighbor adds to its own environment.
const SAME_WEIGHT := 1.0
## Weight of every allowed environment that isn't around the cell yet. This is how new regions start.
const NEW_REGION_WEIGHT := 0.05
## Regions smaller than this get a boost while growing, and are merged away at the end.
const MIN_REGION_SIZE := 15
## Extra weight multiplier for a 1-tile region, shrinking linearly to none at MIN_REGION_SIZE.
const SMALL_BOOST := 3.0
## Regions larger than this grow at LARGE_DAMPING weight, so one environment doesn't swallow the map.
## Tuned on the 20x11 maps from before the ice wall: about 3.7 environments and 4.5 regions per map, largest region about 43%.
## Since every border but desert-ice is allowed and SHARE_PULL evens the shares: 5.7 environments and 6.6 regions.
const MAX_REGION_SIZE := 50
const LARGE_DAMPING := 0.25
## Every weight is scaled by exp(SHARE_PULL * (even share - the environment's cells) / even share), counting the
## cells this call has filled, and then the neighbors' environments and the new ones are each brought back to the
## weight they had: the pull picks which environment a cell takes, never how often a new region starts, which
## would make regions smaller. Even with every border allowed but desert-ice, those two came out at 13% and 15%
## of the land without it; at 10 each environment covers 16-17% (Scenes/Map/DESIGN.md).
const SHARE_PULL := 10.0
## Cells added to every environment's count before comparing, so the first regions don't swing it.
const SHARE_PRIOR := 10.0


## Fills every cell of `cells` with an environment.
static func generate(cells: Rect2i, seed_value: int) -> Dictionary[Vector2i, String]:
	var envs: Dictionary[Vector2i, String] = {}
	extend(envs, cells, seed_value)
	return envs


## Fills the cells of `cells` that `envs` doesn't have yet, growing out of the ones it does, so a map can be
## enlarged when an ice wall falls. Cells already in `envs` are never changed, and the new ones border them
## legally; what is already there also decides what the new land is likely to be. `envs` may hold cells
## outside `cells`, which count as neighbors but are not filled in.
static func extend(envs: Dictionary[Vector2i, String], cells: Rect2i, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var regions := Regions.new()
	var grown: Dictionary[Vector2i, bool] = {}
	for cell in envs:
		regions.add(cell, envs)
		grown[cell] = true

	# The frontier starts on the land already there, or on one random cell when there is none.
	var frontier: Array[Vector2i] = []
	var queued: Dictionary[Vector2i, bool] = {}
	for cell in envs:
		for next in HexGrid.neighbors(cell):
			if cells.has_point(next) and not envs.has(next) and not queued.has(next):
				queued[next] = true
				frontier.append(next)
	if frontier.is_empty() and envs.is_empty():
		var start := cells.position + Vector2i(rng.randi_range(0, cells.size.x - 1), rng.randi_range(0, cells.size.y - 1))
		queued[start] = true
		frontier.append(start)

	# How many cells of the new land each environment has taken so far.
	var counts: Dictionary[String, int] = {}
	for env: String in allowed():
		counts[env] = 0
	while not frontier.is_empty():
		var index := rng.randi_range(0, frontier.size() - 1)
		var cell := frontier[index]
		frontier[index] = frontier.back()
		frontier.pop_back()

		envs[cell] = _pick(choice_weights(cell, envs, regions, counts), rng)
		counts[envs[cell]] += 1
		regions.add(cell, envs)
		for next in HexGrid.neighbors(cell):
			if cells.has_point(next) and not envs.has(next) and not queued.has(next):
				queued[next] = true
				frontier.append(next)

	_merge_small_regions(envs, grown)


static func can_border(a: String, b: String) -> bool:
	return a == b or b in allowed()[a]


## Weight of every environment the cell may take, given the cells generated so far. `counts` is how many cells
## of the new land each environment has taken, which pulls them all towards an even share.
static func choice_weights(cell: Vector2i, envs: Dictionary[Vector2i, String], regions: Regions,
		counts: Dictionary[String, int] = {}) -> Dictionary[String, float]:
	var weights: Dictionary[String, float] = {}
	var neighbor_envs: Array[String] = []
	for next in HexGrid.neighbors(cell):
		if envs.has(next):
			neighbor_envs.append(envs[next])
			weights[envs[next]] = weights.get(envs[next], 0.0) + SAME_WEIGHT * _size_factor(regions.size_of(next))
	for env: String in allowed():
		if not weights.has(env):
			weights[env] = NEW_REGION_WEIGHT
	for env: String in weights.keys():
		if not neighbor_envs.all(func(other: String) -> bool: return can_border(env, other)):
			weights.erase(env)
	if not counts.is_empty():
		var total := 0
		for env: String in counts:
			total += counts[env]
		var even := SHARE_PRIOR + total / float(counts.size())
		# Weight moves among the neighbors' environments, and among the new ones, never from one to the other.
		for around: bool in [true, false]:
			var before := 0.0
			var after := 0.0
			var pulled: Dictionary[String, float] = {}
			for env: String in weights:
				if neighbor_envs.has(env) == around:
					pulled[env] = weights[env] * exp(SHARE_PULL * (even - SHARE_PRIOR - counts[env]) / even)
					before += weights[env]
					after += pulled[env]
			for env: String in pulled:
				weights[env] = pulled[env] * before / after
	return weights


## Connected groups of same-environment cells.
static func find_regions(envs: Dictionary[Vector2i, String]) -> Array[Array]:
	var regions: Array[Array] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for start in envs:
		if seen.has(start):
			continue
		seen[start] = true
		var region: Array[Vector2i] = [start]
		var i := 0
		while i < region.size():
			for next in HexGrid.neighbors(region[i]):
				if envs.has(next) and not seen.has(next) and envs[next] == envs[start]:
					seen[next] = true
					region.append(next)
			i += 1
		regions.append(region)
	return regions


static func _size_factor(region_size: int) -> float:
	if region_size < MIN_REGION_SIZE:
		return 1.0 + SMALL_BOOST * (MIN_REGION_SIZE - region_size) / float(MIN_REGION_SIZE)
	if region_size > MAX_REGION_SIZE:
		return LARGE_DAMPING
	return 1.0


static func _pick(weights: Dictionary[String, float], rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for weight in weights.values():
		total += weight
	var roll := rng.randf() * total
	for env in weights:
		roll -= weights[env]
		if roll <= 0.0:
			return env
	return weights.keys().back()


## Merges regions under MIN_REGION_SIZE into a neighboring region, smallest first, until none can be merged.
## Regions holding any cell of `frozen` are left alone: land the player may already have seen never changes.
static func _merge_small_regions(envs: Dictionary[Vector2i, String], frozen: Dictionary[Vector2i, bool] = {}) -> void:
	while true:
		var regions := find_regions(envs)
		var region_of: Dictionary[Vector2i, int] = {}
		var counts: Dictionary[String, int] = {}
		for i in regions.size():
			for cell: Vector2i in regions[i]:
				region_of[cell] = i
				if not frozen.has(cell):
					counts[envs[cell]] = counts.get(envs[cell], 0) + 1
		var order := range(regions.size())
		order.sort_custom(func(a: int, b: int) -> bool: return regions[a].size() < regions[b].size())
		var merged := false
		for i: int in order:
			if regions[i].size() >= MIN_REGION_SIZE:
				break
			if regions[i].any(func(cell: Vector2i) -> bool: return frozen.has(cell)):
				continue
			if _absorb(regions, i, region_of, envs, counts):
				merged = true
				break  # Regions changed; recompute them.
		if not merged:
			return


## Recolors a region to the environment of a neighboring region that is allowed next to all of the region's
## other neighbors: the one with the fewest new cells in `counts`, then the largest. Returns false if none is.
static func _absorb(regions: Array[Array], index: int, region_of: Dictionary[Vector2i, int], envs: Dictionary[Vector2i, String],
		counts: Dictionary[String, int]) -> bool:
	var bordering: Dictionary[int, bool] = {}
	for cell: Vector2i in regions[index]:
		for next in HexGrid.neighbors(cell):
			if region_of.has(next) and region_of[next] != index:
				bordering[region_of[next]] = true
	var candidates := bordering.keys()
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var count_a: int = counts.get(envs[regions[a][0]], 0)
		var count_b: int = counts.get(envs[regions[b][0]], 0)
		return count_a < count_b if count_a != count_b else regions[a].size() > regions[b].size())
	for candidate: int in candidates:
		var new_env := envs[regions[candidate][0]]
		if bordering.keys().all(func(other: int) -> bool: return can_border(new_env, envs[regions[other][0]])):
			for cell: Vector2i in regions[index]:
				envs[cell] = new_env
			return true
	return false


## Region sizes while generating (union-find), so each new cell can look up its neighbors' region sizes.
class Regions:
	var _parent: Dictionary[Vector2i, Vector2i] = {}
	var _size: Dictionary[Vector2i, int] = {}

	## Adds a cell whose environment is already in `envs`, joining neighboring regions of the same environment.
	func add(cell: Vector2i, envs: Dictionary[Vector2i, String]) -> void:
		_parent[cell] = cell
		_size[cell] = 1
		for next in HexGrid.neighbors(cell):
			if _parent.has(next) and envs[next] == envs[cell]:
				_union(cell, next)

	func size_of(cell: Vector2i) -> int:
		return _size[_find(cell)]

	func _find(cell: Vector2i) -> Vector2i:
		var root := cell
		while _parent[root] != root:
			root = _parent[root]
		while _parent[cell] != root:
			var next := _parent[cell]
			_parent[cell] = root
			cell = next
		return root

	func _union(a: Vector2i, b: Vector2i) -> void:
		var root_a := _find(a)
		var root_b := _find(b)
		if root_a == root_b:
			return
		if _size[root_a] < _size[root_b]:
			var swap := root_a
			root_a = root_b
			root_b = swap
		_parent[root_b] = root_a
		_size[root_a] += _size[root_b]
