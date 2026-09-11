class_name MapBuilder
extends RefCounted
## Fills a HexMap with a window of the world: procedural environments, with the world's towns drawn as the
## town sprite of the environment they stand on. Blend overlays follow automatically, since HexMap.set_ground
## redraws them.

const SIZE := Vector2i(20, 11)
## About 1 in 10 environment tiles use the accent sprite (JSON meta accent_frequency: 1 in 8-12).
const ACCENT_CHANCE := 0.1


## `origin` is the world spot shown in the top-left cell. Its row must be even, or odd rows of the world would
## be drawn as even rows and world neighbors wouldn't match map neighbors.
static func build(map: HexMap, towns: TownWorld, origin: Vector2i, env_seed: int) -> void:
	assert(origin.y % 2 == 0, "MapBuilder origin row must be even")
	var envs := EnvironmentGenerator.generate(SIZE, env_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "variants"])
	map.clear_map()
	for cell in envs:
		var env := envs[cell]
		var tier := towns.tier_at(origin + cell)
		if tier != -1:
			map.set_ground(cell, "town_%s_%s" % [env, TownWorld.TIER_NAMES[tier]])
		else:
			var variant := "accent" if rng.randf() < ACCENT_CHANCE else "v%d" % rng.randi_range(1, 3)
			map.set_ground(cell, "env_%s_%s" % [env, variant])
