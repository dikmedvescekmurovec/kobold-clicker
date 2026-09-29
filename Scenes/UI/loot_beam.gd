class_name LootBeam
## The beam that stands over a find lying in the arena: a pillar of light in the rarity's own colour over
## a ring on the ground, the find standing inside it, drawn by `loot_beam.gdshader` on rectangles rather
## than cut from a sheet, so that one piece of code can stand a modest beam over a rare and a towering
## one wound with ribbons over a unique.
##
## Rare and better only, and a good orb (`OrbTable` names the rarity its beam borrows): a beam means
## "this one is worth stopping for", and one over every uncommon ring would mean nothing.

const SHADER := preload("res://Scenes/UI/loot_beam.gdshader")

## What each rarity stands, in the find's own pixels (the find is scaled by `ui_scale`, and the beam
## with it, less the find's own `CombatScene.FIND_SIZE`): how tall and how wide the pillar is, how many
## rings lie round the foot (a second pulses out), how many ribbons wind up it, and whether sparks rise.
## Each step up adds something rather than only growing, so a unique is told from an elite at a glance.
const LOOKS := {
	ItemRarity.Rarity.RARE: {"height": 80.0, "width": 2.0, "rings": 1, "ribbons": 0, "sparks": false},
	ItemRarity.Rarity.ELITE: {"height": 140.0, "width": 2.5, "rings": 1, "ribbons": 1, "sparks": true},
	ItemRarity.Rarity.UNIQUE: {"height": 300.0, "width": 3.5, "rings": 2, "ribbons": 2, "sparks": true},
}
## Seconds the beam takes to shoot up to its height once the find has landed.
const RISE := 0.3
## Seconds it takes to sink back into the ground once the find is picked up (`collapse`).
const FALL := 0.15


## Whether `rarity` stands a beam at all.
static func has(rarity: int) -> bool:
	return LOOKS.has(rarity)


## A beam of `rarity`'s look in `colour`, its foot at its origin, its rings round a find of `cover`
## (half-width, height) standing on it, shooting up once `landed` seconds have passed. Two layers:
## `Back` drawn under the find it is a child of and `Front` over it, so the find stands inside the light.
static func make(rarity: int, colour: Color, landed: float, cover: Vector2) -> Node2D:
	var beam := Node2D.new()
	var look: Dictionary = LOOKS[rarity]
	# Wide enough for the second ring at its widest, tall enough for the pillar.
	var half := cover.x * 1.1 * 1.6 + 2.0
	var top: float = -look.height - 2.0
	var bottom := half * 0.3 + 2.0
	# One seed for both layers, or a ribbon's near turns would not meet its far ones.
	var seed := randf()
	for front in [false, true]:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("colour", colour)
		material.set_shader_parameter("cover", cover)
		material.set_shader_parameter("front", front)
		for key: String in look:
			material.set_shader_parameter(key, look[key])
		material.set_shader_parameter("speed", 1.0 if Settings.animations == Settings.Anim.DEFAULT else 0.0)
		material.set_shader_parameter("grow", 0.0)
		material.set_shader_parameter("seed", seed)
		var layer := Polygon2D.new()
		layer.name = "Front" if front else "Back"
		layer.polygon = PackedVector2Array([Vector2(-half, top), Vector2(half, top),
				Vector2(half, bottom), Vector2(-half, bottom)])
		layer.material = material
		layer.z_index = 0 if front else -1
		beam.add_child(layer)
		layer.tree_entered.connect(func() -> void:
			layer.create_tween().tween_property(material, "shader_parameter/grow", 1.0, RISE) 					.set_delay(landed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT), CONNECT_ONE_SHOT)
	return beam


## Sinks a beam `make` built back into its foot over `FALL`, then frees it.
static func collapse(beam: Node2D) -> void:
	var fall := beam.create_tween().set_parallel(true)
	for layer: Polygon2D in beam.get_children():
		fall.tween_property(layer.material, "shader_parameter/grow", 0.0, FALL) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall.chain().tween_callback(beam.queue_free)
