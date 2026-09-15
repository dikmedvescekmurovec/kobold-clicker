extends SceneTree

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var counts := {}
	for i in 20000:
		var it := LootTable.roll("Slime", rng, true, 10)
		if it == null:
			continue
		counts[it.type] = int(counts.get(it.type, 0)) + 1
	print(counts)
	quit()
