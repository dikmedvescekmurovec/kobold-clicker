extends Node2D

## Seeds for the town world and the rendered map. 0 picks a random seed each run; the used seeds are printed.
@export var world_seed := 0
@export var map_seed := 0
## World spot shown in the map's top-left cell (centered in the 256x256 world). The row must be even.
@export var map_origin := Vector2i(118, 122)

var towns: TownWorld

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	var used_world_seed := world_seed if world_seed != 0 else randi()
	var used_map_seed := map_seed if map_seed != 0 else randi()
	towns = TownWorld.generate(used_world_seed)
	MapBuilder.build(map, towns, map_origin, used_map_seed)
	print("World seed %d (%d towns), map seed %d" % [used_world_seed, towns.towns().size(), used_map_seed])
	map.tile_clicked.connect(_on_tile_clicked)
	_fit_camera()


## Centers the camera on the map at the largest whole-number zoom that fits, so pixels stay crisp.
func _fit_camera() -> void:
	var cells := map.ground_layer.get_used_rect()
	var half_tile := Vector2(map.tileset.tile_size) / 2
	var top_left := map.ground_layer.map_to_local(cells.position) - half_tile
	var bottom_right := map.ground_layer.map_to_local(cells.end - Vector2i.ONE) + half_tile
	var map_size := bottom_right - top_left
	var view := get_viewport_rect().size
	var zoom := maxf(1.0, floorf(minf(view.x / map_size.x, view.y / map_size.y)))
	camera.zoom = Vector2(zoom, zoom)
	camera.position = (top_left + bottom_right) / 2


func _on_tile_clicked(cell: Vector2i, info: Dictionary) -> void:
	var spot := map_origin + cell
	var weights: Dictionary = info["environments"]
	var parts := PackedStringArray()
	for env: String in weights:
		parts.append("%s %.1f%%" % [env, weights[env] * 100])
	var line := "Clicked %s (world %s): %s | %s" % [cell, spot, info["name"], ", ".join(parts)]
	if towns.has_town(spot):
		line += " | town connected to %s" % [towns.connections(spot)]
	print(line)
