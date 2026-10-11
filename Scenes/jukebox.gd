class_name Jukebox
extends Node
## The main scene's own sound: the music, and the click of every button, page and coin. A child of the
## scene, added as the scene enters the tree, so no button made after it is missed.

## One of the pack's `Ambient` tracks on the map (never its `Dark Ambient` or `Light Ambient`, which
## start otherwise) and one of its `Action` tracks under a fight or the dungeon, picked at random as one
## gives way to the other (the user's, 2026-10-02). Read off the folder: a track dropped in is played.
const MUSIC_DIR := "res://Sounds/Music/ogg"
const IDLE := "Ambient"
const BATTLE := "Action"

## A press of any button, and of a toggle (a button held down on its own, not a tab of a group).
var button := _player(preload("res://Sounds/UI/click1.ogg"))
var toggle := _player(preload("res://Sounds/UI/click4.ogg"))
## A side panel sliding in or out, and anything bought or sold.
var page := _player(preload("res://Sounds/UI/bookFlip2.ogg"))
var coins := _player(preload("res://Sounds/UI/handleCoins.ogg"))

var _music := AudioStreamPlayer.new()
## Every track of `MUSIC_DIR`, looped, under the name it starts with.
var _tracks := {IDLE: [], BATTLE: []}
var _page_flipped_at := -1


func _init() -> void:
	for player: AudioStreamPlayer in [button, toggle, page, coins]:
		add_child(player)
	_music.bus = Settings.MUSIC_BUS
	add_child(_music)
	for file in ResourceLoader.list_directory(MUSIC_DIR):
		for kind: String in _tracks:
			if file.begins_with(kind):
				var track: AudioStream = load(MUSIC_DIR.path_join(file))
				track.loop = true
				_tracks[kind].append(track)


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


## A random track of `kind` from its start, unless one of that kind is already playing, so a retried
## fight's music carries on through the close and the open.
func play_music(kind: String) -> void:
	var tracks: Array = _tracks[kind]
	if tracks.is_empty() or (_music.playing and _music.stream in tracks):
		return
	_music.stream = tracks.pick_random()
	_music.play()


## A panel shown or hidden, once a frame: one page swapped for another is one flip.
func page_slid() -> void:
	if _page_flipped_at != Engine.get_process_frames():
		_page_flipped_at = Engine.get_process_frames()
		page.play()


static func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Settings.SFX_BUS
	player.max_polyphony = 4
	return player


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_on_button_pressed.bind(node))


## Asked at the press rather than as the button is made, which may set its toggle mode after.
func _on_button_pressed(pressed: BaseButton) -> void:
	(toggle if pressed.toggle_mode and pressed.button_group == null else button).play()
