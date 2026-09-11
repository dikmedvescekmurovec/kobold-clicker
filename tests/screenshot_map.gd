extends SceneTree
## Renders the main scene for a few map seeds and saves screenshots to user://, for checking the look.
## Also prints the environment weights of a few blended tiles and saves a 3x crop around the first one.
## Needs a window (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/screenshot_map.gd

const WORLD_SEED := 12345
const MAP_SEEDS := [1, 2, 3, 4]
const CROP_ZOOM := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEEDS[0]
	root.add_child(main)
	for i in 3:
		await process_frame

	# Center the window on a town-rich spot: the world's first fortress.
	var towns: TownWorld = main.towns
	var map: HexMap = main.map
	var camera: Camera2D = main.camera
	var fortress := towns.towns().filter(func(spot: Vector2i) -> bool: return towns.tier_at(spot) == TownWorld.Tier.FORTRESS)[0] as Vector2i
	var origin := Vector2i(fortress.x - MapBuilder.SIZE.x / 2, (fortress.y - MapBuilder.SIZE.y / 2) & ~1)
	main.map_origin = origin
	for map_seed: int in MAP_SEEDS:
		MapBuilder.build(map, towns, origin, map_seed)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "user://map_seed_%d.png" % map_seed
		image.save_png(path)
		print("Saved ", ProjectSettings.globalize_path(path))

		# Tiles blended from more than one environment, in row order.
		var cells := map.ground_layer.get_used_cells()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		var blended := cells.filter(func(cell: Vector2i) -> bool: return map.env_weights(cell).size() >= 3)
		if blended.is_empty():
			blended = cells.filter(func(cell: Vector2i) -> bool: return map.env_weights(cell).size() == 2)
		for cell: Vector2i in blended.slice(0, 3):
			print("  %s %s: %s" % [cell, map.get_tile_info(cell)["name"], map.env_weights(cell)])
		if not blended.is_empty():
			var screen_origin := Vector2(image.get_size()) / 2 - camera.position * camera.zoom
			var center := screen_origin + map.ground_layer.map_to_local(blended[0]) * camera.zoom
			var half := Vector2(84, 96) * camera.zoom
			var crop := image.get_region(Rect2i(Rect2(center - half, half * 2)))
			crop.resize(crop.get_width() * CROP_ZOOM, crop.get_height() * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
			crop.save_png("user://blend_crop_seed_%d.png" % map_seed)
	quit()
