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


## Freezes the game for `seconds` of real time -- or slows it to `slow` -- then lets it go, easing
## back to full speed over `recover` real seconds. Everything driven by the frame's delta stops with
## it, the fight's clock included, so a freeze never costs the player time. The one that ends last
## wins: a call that would end sooner than the one running is dropped, so a kill's short freeze
## cannot cut short the slow-motion a rare find has just asked for.
static func hit_stop(tree: SceneTree, seconds: float, slow := 0.0, recover := 0.0) -> void:
	# The one guard for every caller: a freeze and a shake are the first things a lower level gives up.
	if Settings.animations != Settings.Anim.DEFAULT:
		return
	var until := Time.get_ticks_msec() + int((seconds + recover) * 1000.0)
	if until <= _until:
		return
	_until = until
	Engine.time_scale = slow
	await tree.create_timer(seconds, true, false, true).timeout
	var eased := Time.get_ticks_msec()
	while _until == until:
		var share := 1.0 if recover <= 0.0 else (Time.get_ticks_msec() - eased) / (recover * 1000.0)
		if share >= 1.0:
			Engine.time_scale = 1.0
			return
		Engine.time_scale = lerpf(slow, 1.0, share * share)
		await tree.process_frame


## When the running stop ends, in `Time.get_ticks_msec`.
static var _until := 0


## Rattles `node` about where it stands, dying away over `time`. Offsets are whole pixels so the art
## stays on the grid; a shake landing on a shake replaces it rather than drifting the node's home.
static func shake(node: Node2D, strength: float, time := 0.2) -> void:
	if Settings.animations != Settings.Anim.DEFAULT or not Settings.shake:
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


## A sound played once and freed when it ends, for a moment rather than a run of them (a level, a
## verdict, the smith's hammer). On the tree's root rather than under whoever asked, so the page or the
## fight that asked can close under it without cutting it off; added deferred, so it can be asked for
## while the tree is busy laying out a scene.
static func sound(stream: AudioStream, pitch := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Settings.SFX_BUS
	player.pitch_scale = pitch
	player.autoplay = true
	player.finished.connect(player.queue_free)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(player)


## Several takes of one sound as one stream, a different take each play -- `AudioStreamRandomizer`
## never plays the same one twice running -- so a sound heard every kill does not wear a groove.
## `pitch` is the most a play is pitched up or down by (1.0: never).
static func takes(streams: Array, pitch := 1.0) -> AudioStreamRandomizer:
	var pool := AudioStreamRandomizer.new()
	pool.random_pitch = pitch
	for stream: AudioStream in streams:
		pool.add_stream(-1, stream)
	return pool


## How a reward panel (a fight's verdict, a bounty's pay) comes and goes: it swells in from
## `POP_FROM` of its size past its own and settles, then shrinks away as it leaves. Its sums count up
## from nothing, its finds pop in one after another, and a win washes the screen warm and throws
## sparks off the ends of its bar. Only a flash and sparks are too much for `LOW`; `NONE` has none of it. The tweens run
## whatever their panel's process mode: a tip pauses a fight, and it comes up over the verdict.
const POP_FROM := 0.8
const POP_TIME := 0.28
const LEAVE_TIME := 0.16
const COUNT_DELAY := 0.2
const COUNT_TIME := 0.6
const REVEAL_DELAY := 0.45
## A find's pop, and the most a whole handful of them may take, so a big run does not queue for ages.
const REVEAL_STEP := 0.12
const REVEAL_MOST := 1.2
const REVEAL_TIME := 0.2
const FLASH := Color(1.0, 0.95, 0.75, 0.35)
const FLASH_TIME := 0.5


## Places a scaled panel in the middle of `view`, drawn at `final` times its own size, with its pivot
## at its centre so it swells and shrinks about the middle: a Control is drawn at
## `position + pivot * (1 - scale)`, which puts the middle at `view / 2` for any scale.
static func centre(panel: Control, view: Vector2) -> void:
	var own := panel.get_combined_minimum_size()
	panel.pivot_offset = own / 2.0
	panel.position = ((view - own) / 2.0).round()


static func pop_in(panel: Control, final: float) -> void:
	panel.scale = Vector2.ONE * final
	panel.modulate.a = 1.0
	if panel.has_meta("leaving"):
		panel.remove_meta("leaving")
	if Settings.animations == Settings.Anim.NONE:
		return
	panel.scale = Vector2.ONE * final * POP_FROM
	panel.modulate.a = 0.0
	var tween := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tween.tween_property(panel, "scale", Vector2.ONE * final, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, POP_TIME * 0.5)


## Shrinks the panel away and then calls `then`, once: a second press while it goes is ignored, so a
## double-clicked Collect cannot leave twice.
static func pop_out(panel: Control, then: Callable) -> void:
	if panel.has_meta("leaving"):
		return
	panel.set_meta("leaving", true)
	if Settings.animations == Settings.Anim.NONE or not panel.is_inside_tree():
		then.call()
		return
	var tween := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tween.tween_property(panel, "scale", panel.scale * POP_FROM, LEAVE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, LEAVE_TIME)
	tween.chain().tween_callback(then)


## Every popup comes up the way the rewards do (a bounty's pay, a fight's verdict): `panel` -- a titled
## panel with no X, its one way out a button at its foot -- swells in about its middle and is kept in
## the middle of the window as its contents settle, and with `win`, for something gained, the warm wash
## and the sparks go under it once it stands still. `holder` is the full-window Control it stands in,
## which eats the clicks under it (only `win` needs one). It leaves by `pop_out`.
static func popup(holder: Control, panel: Control, final: float, win := false) -> void:
	var settle := func() -> void:
		if is_instance_valid(panel) and panel.is_inside_tree():
			centre(panel, panel.get_viewport_rect().size)
	panel.resized.connect(settle)
	pop_in(panel, final)
	settle.call()
	await panel.get_tree().process_frame
	if not is_instance_valid(panel) or panel.has_meta("leaving"):
		return
	settle.call()
	if win and holder != null:
		celebrate(holder, panel, final, (panel.get_child(0) as Control).size.y)


## A win's wash and sparks, for a panel already centred in `parent` (a full-window Control): the wash
## goes under the panel, the sparks fly off both ends of its bar (`bar_height` panel pixels tall).
static func celebrate(parent: Control, panel: Control, final: float, bar_height: float) -> void:
	if Settings.animations != Settings.Anim.DEFAULT:
		return
	var wash := ColorRect.new()
	wash.color = FLASH
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(wash)
	parent.move_child(wash, panel.get_index())
	var fade := wash.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(wash, "modulate:a", 0.0, FLASH_TIME)
	fade.tween_callback(wash.queue_free)
	var own := panel.get_combined_minimum_size()
	var top_left := panel.position + panel.pivot_offset * (1.0 - final)
	var y := top_left.y + bar_height * final / 2.0
	for x: float in [top_left.x, top_left.x + own.x * final]:
		burst(parent, Vector2(x, y), Palette.GOLD, 20, 90.0 * final, 2.0 * final, 0.6, 120.0 * final)


## Counts `label` up from nothing to `amount`, the coin beside it spinning while it does. The label
## is held at the final figure's width first, so the row does not grow under the player's eye.
static func count_up(label: Label, amount: float, coin: TextureRect = null) -> void:
	label.text = BigNumber.format(amount)
	label.custom_minimum_size.x = 0.0
	if Settings.animations == Settings.Anim.NONE or amount <= 0.0:
		return
	label.custom_minimum_size.x = label.get_minimum_size().x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = BigNumber.format(0.0)
	var rest: Texture2D = coin.texture if coin != null else null
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(COUNT_DELAY)
	tween.tween_method(func(at: float) -> void:
		label.text = BigNumber.format(roundf(amount * at))
		if coin != null:
			coin.texture = Coins.frames().get_frame_texture("spin",
					int(at * COUNT_TIME * Coins.FPS) % Coins.FRAMES),
		0.0, 1.0, COUNT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		label.text = BigNumber.format(amount)
		if coin != null:
			coin.texture = rest)


## Pops `pieces` in one after another, from nothing to their size about their middles.
static func reveal(pieces: Array) -> void:
	if Settings.animations == Settings.Anim.NONE or pieces.is_empty():
		return
	var step := minf(REVEAL_STEP, REVEAL_MOST / pieces.size())
	for i in pieces.size():
		var piece: Control = pieces[i]
		piece.modulate.a = 0.0
		var tween := piece.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(REVEAL_DELAY + step * i)
		tween.tween_callback(func() -> void:
			piece.pivot_offset = piece.size / 2.0
			piece.scale = Vector2.ONE * 0.4
			piece.modulate.a = 1.0)
		tween.tween_property(piece, "scale", Vector2.ONE, REVEAL_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## How the side panels come and go: a page slides in from its edge and back out to it, and the corner
## buttons glide to wherever they are placed next. **The node itself never moves and never lingers:**
## a page opened is where it will be to every check, click and test, only its drawing sliding in (the
## canvas item's transform, on the RenderingServer); a page closed is hidden at once, and what slides
## out is a picture of it taken off the last frame -- Godot draws nothing of a hidden Control, however
## its canvas item is told. Driven by `visibility_changed`, so no `show()` or `hide()` anywhere has to
## know. `NONE` snaps, as it always did, and so does a window with nothing to take a picture of.
const SLIDE_IN_TIME := 0.22
const SLIDE_OUT_TIME := 0.16
const GLIDE_TIME := 0.2
## The last frame, read back once however many panels close on the same one.
static var _shot: Image
static var _shot_frame := -1


static func slides(node: Control, from_left: bool) -> void:
	node.visibility_changed.connect(_slide.bind(node, from_left))


static func _slide(node: Control, from_left: bool) -> void:
	_stop_moving(node)
	_settle(node)
	if Settings.animations == Settings.Anim.NONE or not node.is_inside_tree():
		return
	var rects := _drawn(node)
	var reach := 0.0
	var view := node.get_viewport_rect().size.x
	for rect in rects:
		reach = maxf(reach, rect.end.x if from_left else view - rect.position.x)
	if reach <= 0.0:
		return
	var away := Vector2(-reach if from_left else reach, 0.0)
	if node.visible:
		_slide_in(node, away)
	else:
		_slide_out(node, rects, away)


static func _slide_in(node: Control, away: Vector2) -> void:
	var rid := node.get_canvas_item()
	var step := func(at: float) -> void:
		RenderingServer.canvas_item_set_transform(rid, node.get_transform().translated(away * at))
	# The first frame is set now, so a page never shows at its place before it slides into it.
	step.call(1.0)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta("moving", tween)
	tween.tween_method(step, 1.0, 0.0, SLIDE_IN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_settle.bind(node))


## The picture of each panel the page drew, cut off the last frame, laid where the page stood and slid
## off the edge. It takes no mouse and frees itself.
static func _slide_out(node: Control, rects: Array[Rect2], away: Vector2) -> void:
	var shot := _last_frame(node)
	if shot == null:
		return
	var ghost := Control.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bounds := Rect2i(Vector2i.ZERO, shot.get_size())
	for rect in rects:
		var cut := Rect2i(rect).intersection(bounds)
		if cut.has_area():
			var part := TextureRect.new()
			part.texture = ImageTexture.create_from_image(shot.get_region(cut))
			part.position = cut.position
			part.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.add_child(part)
	var parent := node.get_parent()
	parent.add_child(ghost)
	parent.move_child(ghost, node.get_index() + 1)
	var tween := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ghost, "position", away, SLIDE_OUT_TIME) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)


static func _last_frame(node: Control) -> Image:
	# A headless run renders nothing, and reading its texture back only logs errors.
	if DisplayServer.get_name() == "headless":
		return null
	if _shot_frame != Engine.get_process_frames():
		_shot = node.get_viewport().get_texture().get_image()
		_shot_frame = Engine.get_process_frames()
	return _shot if _shot != null and not _shot.is_empty() else null


## From `from` to where the node stands now, drawn only.
static func glide(node: Control, from: Vector2) -> void:
	_stop_moving(node)
	if Settings.animations == Settings.Anim.NONE or not node.is_inside_tree():
		return
	var rid := node.get_canvas_item()
	var step := func(at: float) -> void:
		RenderingServer.canvas_item_set_transform(rid,
				node.get_transform().translated((from - node.position) * at))
	step.call(1.0)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta("moving", tween)
	tween.tween_method(step, 1.0, 0.0, GLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_settle.bind(node))


static func _stop_moving(node: Control) -> void:
	# `get_meta` with a null default still complains of a missing key, so it is asked first.
	if not node.has_meta("moving"):
		return
	var running: Variant = node.get_meta("moving")
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	node.remove_meta("moving")


## The canvas item back in step with the node: its own transform, and drawn only if it is shown.
static func _settle(node: Control) -> void:
	if node.has_meta("moving"):
		node.remove_meta("moving")
	var rid := node.get_canvas_item()
	RenderingServer.canvas_item_set_transform(rid, node.get_transform())
	RenderingServer.canvas_item_set_visible(rid, node.visible)


## What `node` draws, in window pixels: itself if it has a size, and each shown Control child, which
## is where a page keeps its panels.
static func _drawn(node: Control) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if node.size != Vector2.ZERO:
		rects.append(node.get_global_transform() * Rect2(Vector2.ZERO, node.size))
	for child: Node in node.get_children():
		if child is Control and (child as Control).visible:
			rects.append((child as Control).get_global_transform() * Rect2(Vector2.ZERO, (child as Control).size))
	return rects
