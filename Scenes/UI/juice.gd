class_name Juice
extends RefCounted
## The small one-shot effects that make a blow or a step feel like something: a puff of pixels, a
## freeze on a heavy hit, a shake. Static and node-free, the way `Coins` and `LootBeam` are, because
## the fight and the map both use them and neither owns them.


## A one-shot puff of square pixels at `at`, in `parent`'s space, that fades as it goes and frees
## itself. No texture: an untextured particle is a 1 px square scaled by `size`, which is already
## pixel art. `gravity` is in pixels a second squared, negative to rise.
static func burst(parent: Node, at: Vector2, colour: Color, amount := 16, speed := 120.0,
		size := 4.0, life := 0.5, gravity := 300.0) -> CPUParticles2D:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = amount
	puff.lifetime = life
	puff.explosiveness = 1.0
	puff.direction = Vector2.UP
	puff.spread = 180.0
	puff.initial_velocity_min = speed * 0.4
	puff.initial_velocity_max = speed
	puff.gravity = Vector2(0, gravity)
	puff.scale_amount_min = size * 0.5
	puff.scale_amount_max = size
	puff.color = colour
	puff.color_ramp = fade_ramp()
	puff.position = at
	parent.add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	return puff


## Solid to transparent over a particle's life.
static func fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp


## Freezes the game for `seconds` of real time -- or slows it to `slow` -- then lets it go. Everything
## driven by the frame's delta stops with it, the fight's clock included, so a freeze never costs the
## player time. The latest call wins: one landing during another replaces it, so a kill's short
## freeze cannot cut short the slow-motion a rare find it dropped has just asked for.
static func hit_stop(tree: SceneTree, seconds: float, slow := 0.0) -> void:
	# The one guard for every caller: a freeze and a shake are the first things a lower level gives up.
	if Settings.animations != Settings.Anim.DEFAULT:
		return
	_stops += 1
	var mine := _stops
	Engine.time_scale = slow
	await tree.create_timer(seconds, true, false, true).timeout
	if mine == _stops:
		Engine.time_scale = 1.0


static var _stops := 0


## Rattles `node` about where it stands, dying away over `time`. Offsets are whole pixels so the art
## stays on the grid; a shake landing on a shake replaces it rather than drifting the node's home.
static func shake(node: Node2D, strength: float, time := 0.2) -> void:
	if Settings.animations != Settings.Anim.DEFAULT:
		return
	var home: Vector2 = node.get_meta("shake_home", node.position)
	node.set_meta("shake_home", home)
	if node.has_meta("shake_tween"):
		var running: Tween = node.get_meta("shake_tween")
		if running.is_valid():
			running.kill()
	var tween := node.create_tween()
	node.set_meta("shake_tween", tween)
	const STEPS := 6
	for i in STEPS:
		var reach := strength * (1.0 - float(i) / STEPS)
		var jolt := Vector2(randf_range(-reach, reach), randf_range(-reach, reach)).round()
		tween.tween_property(node, "position", home + jolt, time / (STEPS + 1))
	tween.tween_property(node, "position", home, time / (STEPS + 1))
