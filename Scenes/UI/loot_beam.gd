class_name LootBeam
## The beam over a find lying in the arena, drawn by `loot_beam.gdshader`: a pillar of light in the
## rarity's colour over a ring on the ground, the find standing inside it. Rare and better only, and a
## good orb (`OrbTable` names the rarity whose look its beam borrows).

const SHADER := preload("res://Scenes/UI/loot_beam.gdshader")

## What each rarity stands, in the find's own pixels (the find is scaled by `ui_scale`, and the beam
## with it, less the find's own `CombatScene.FIND_SIZE`): the pillar's height and width, how many rings
## lie round the foot (a second pulses out), how many ribbons wind up it, and whether sparks rise. Each
## key is a uniform of the shader. Each step up adds something rather than only growing, so a unique is
## told from an elite at a glance.
const LOOKS := {
	ItemRarity.Rarity.RARE: {"height": 80.0, "width": 2.0, "rings": 1, "ribbons": 0, "sparks": false},
	ItemRarity.Rarity.ELITE: {"height": 140.0, "width": 2.5, "rings": 1, "ribbons": 1, "sparks": true},
	ItemRarity.Rarity.UNIQUE: {"height": 300.0, "width": 3.5, "rings": 2, "ribbons": 2, "sparks": true},
}
## The step above each beam's colour on its own ENDESGA 64 ramp, which its bright edges are drawn in:
## the rarities' ring colours and the good orbs' glows (`test_combat` holds each to having one). Picked
## by hand, because the palette colour nearest a lightened lilac is a grey.
const HOT := {
	Palette.LILAC: Color("ca52c9"),
	Palette.BRICK: Color("f5555d"),
	Palette.GOLD: Color("ffeb57"),
	Palette.STONE_LT: Color("c7cfdd"),
	Color("ff5000"): Color("ffa214"),
}
## Seconds the beam takes to shoot up once the find has landed, and to sink back as it is picked up.
const RISE := 0.3
const FALL := 0.15
## A loop: `tools/sound_levels.py` cuts it from whole pulses, and its `.import` loops it.
const HUM := preload("res://Sounds/Sfx/loot_beam.ogg")


## Whether `rarity` stands a beam at all.
static func has(rarity: int) -> bool:
	return LOOKS.has(rarity)


## A beam of `rarity`'s look in `colour`, its foot at its origin, its rings round a find of `cover`
## (half-width, height) standing on it, shooting up once `landed` seconds have passed, drawn in pixels
## `pixel` of its own wide (the backdrop's). Two layers: `Back` under the find it is a child of and
## `Front` over it, so the find stands inside the light.
static func make(rarity: int, colour: Color, landed: float, cover: Vector2, pixel := 1.0) -> Node2D:
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
		# A colour not in `HOT` is lightened, off the palette.
		material.set_shader_parameter("hot_colour", HOT.get(colour, colour.lerp(Color.WHITE, 0.4)))
		material.set_shader_parameter("pixel", pixel)
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
			layer.create_tween().tween_property(material, "shader_parameter/grow", 1.0, RISE) \
					.set_delay(landed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT), CONNECT_ONE_SHOT)
	# Each beam's hum starts somewhere else in the loop, so beams standing together do not pulse in
	# step. It is faded, never turned down: it ends at the file's own level, which `sound_levels.py` sets.
	var hum := AudioStreamPlayer.new()
	hum.name = "Hum"
	hum.stream = HUM
	hum.bus = Settings.SFX_BUS
	hum.volume_linear = 0.0
	beam.add_child(hum)
	hum.tree_entered.connect(func() -> void:
		hum.play(randf() * HUM.get_length())
		hum.create_tween().tween_property(hum, "volume_linear", 1.0, RISE).set_delay(landed), CONNECT_ONE_SHOT)
	return beam


## Sinks a beam `make` built back into its foot over `FALL`, its hum fading with it, then frees it.
static func collapse(beam: Node2D) -> void:
	var fall := beam.create_tween().set_parallel(true)
	for part: Node in beam.get_children():
		if part is AudioStreamPlayer:
			fall.tween_property(part, "volume_linear", 0.0, FALL)
		else:
			fall.tween_property((part as Polygon2D).material, "shader_parameter/grow", 0.0, FALL) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall.chain().tween_callback(beam.queue_free)
