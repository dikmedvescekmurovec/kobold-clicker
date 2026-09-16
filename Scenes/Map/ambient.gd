class_name Ambient
extends Node2D
## What makes the map feel lived in without being drawn: a little weather in the air around the
## player -- snow on ice, dust on desert, fireflies in forest, seeds on grass, flurries on the peaks --
## and a slow day that dims to blue and comes back.
##
## One particle node, retuned when the player's environment changes, following the camera and
## emitting in world space so the air stays put while the view pans through it. Sparse on purpose: it
## is a hint of air, not a storm over the tiles. The day is a CanvasModulate, which tints the map's
## canvas and nothing on a CanvasLayer -- the interface and the fight keep their own colours.

## A whole day and night, in seconds, and the tint at the darkest point of the night.
const DAY_LENGTH := 480.0
const NIGHT := Color(0.74, 0.78, 0.95)

## Per environment: how many particles are in the air at once, what colour, how long each lives, fall
## speed (negative rises), sideways drift, and pixel size. An environment not listed has clear air.
const WEATHER := {
	"ice": {"amount": 12, "color": Color("f4f8ff"), "life": 6.0, "fall": 14.0, "drift": 6.0, "size": 1.0},
	"mountains": {"amount": 5, "color": Color("e8eef6"), "life": 5.0, "fall": 20.0, "drift": 14.0, "size": 1.0},
	"desert": {"amount": 8, "color": Color("e3c48a"), "life": 4.0, "fall": 2.0, "drift": 30.0, "size": 1.0},
	"forest": {"amount": 5, "color": Color("d8f070"), "life": 4.0, "fall": -2.0, "drift": 3.0, "size": 1.0},
	"grass": {"amount": 3, "color": Color("fff6d0"), "life": 6.0, "fall": 3.0, "drift": 8.0, "size": 1.0},
}

var _camera: Camera2D
var _air: CPUParticles2D
var _day: CanvasModulate
var _env := "?"


func setup(camera: Camera2D) -> void:
	_camera = camera
	_air = CPUParticles2D.new()
	_air.local_coords = false
	_air.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_air.spread = 30.0
	_air.color_ramp = _twinkle()
	_air.emitting = false
	add_child(_air)
	_day = CanvasModulate.new()
	add_child(_day)


## Changes the weather to what `env` has. Asking for the one already falling does nothing, so the
## air does not restart every time the player steps within one environment.
func set_env(env: String) -> void:
	if env == _env:
		return
	_env = env
	if not WEATHER.has(env):
		_air.emitting = false
		return
	var weather: Dictionary = WEATHER[env]
	_air.amount = weather["amount"]
	_air.lifetime = weather["life"]
	_air.color = weather["color"]
	_air.scale_amount_min = weather["size"]
	_air.scale_amount_max = weather["size"]
	var fall: float = weather["fall"]
	_air.direction = Vector2(1, 0) if absf(fall) < 1.0 else Vector2(0, signf(fall))
	_air.initial_velocity_min = absf(fall) * 0.6
	_air.initial_velocity_max = absf(fall)
	_air.gravity = Vector2(weather["drift"], 0)
	_air.preprocess = weather["life"]
	_air.restart()
	_air.emitting = true


func _process(_delta: float) -> void:
	if _camera == null:
		return
	# The whole view, whatever the zoom, so the edges never run dry.
	_air.position = _camera.position
	_air.emission_rect_extents = get_viewport_rect().size / _camera.zoom / 2.0
	# Noon at the start, midnight half way through: 1 in the day, 0 at the dead of night.
	var light := (cos(TAU * fmod(Time.get_ticks_msec() / 1000.0, DAY_LENGTH) / DAY_LENGTH) + 1.0) / 2.0
	_day.color = NIGHT.lerp(Color.WHITE, light)


## In and out of sight over a particle's life, so nothing pops.
static func _twinkle() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color.WHITE)
	ramp.add_point(0.8, Color.WHITE)
	return ramp
