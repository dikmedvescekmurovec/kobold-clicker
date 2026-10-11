class_name FightSounds
extends Node
## A fight's sounds, each on a player of its own under this node. `CombatScene` makes one a fight, from
## the kind of weapon in the hero's hand, and plays them; when a drop's sound plays is the scene's
## (`CombatScene._land`).

const ATTACK_SOUND := preload("res://Assets/Player/attack.mp3")
## A blow landing on the enemy, over the swing: the punch for bare hands and a blade, `BLUNT_HIT` for a
## weapon of a `BLUNT` kind (the user's ruling, 2026-10-02).
const HIT_SOUND := preload("res://Sounds/universfield-punch-03-352040.mp3")
const BLUNT_HIT := preload("res://Sounds/Sfx/blunt_hit.ogg")
## A crit, in place of the blow: blunt for bare hands and a `BLUNT` weapon, a slash for every blade --
## with `GENERAL_CRIT` over the slash (the user's pairing, 2026-10-06).
const BLUNT_CRIT := preload("res://Sounds/Sfx/blunt_crit.ogg")
const SLASH_CRIT := preload("res://Sounds/Sfx/slash_crit.ogg")
const GENERAL_CRIT := preload("res://Sounds/Sfx/general_crit.ogg")
## The kinds of weapon (`LootTable.KINDS`) that strike blunt.
const BLUNT := ["mace"]
const DEATH_SOUND := preload("res://Sounds/universfield-character-fall-impact-352287.mp3")
## An enemy's blow that took time off the clock; a dodged or blocked one is silent.
const STRUCK_SOUND := preload("res://Sounds/Sfx/player_hit.ogg")
## A lost fight's verdict, through `Juice.sound` so the scene can close under it. A won one is silent:
## its fanfare was annoying (the user's ruling, 2026-10-02).
const DEFEAT_SOUND := preload("res://Sounds/Sfx/defeat.ogg")
## A find landing (`drop_sound_of`), each a pool of takes: a unique its own, every other piece one
## (the user's ruling, 2026-10-06).
const DROP_SOUNDS := {
	"unique": [preload("res://Sounds/Sfx/unique_drop.ogg")],
	"gear": [preload("res://Sounds/Sfx/item_drop.ogg")],
}
## Every coin a purse throws, each as it lands (the user's ask), quiet for it.
const COIN_SOUND := preload("res://Sounds/Sfx/coin_drop.ogg")
const ORB_DROP_SOUND := preload("res://Sounds/Sfx/orb_drop.ogg")
## The most a find, a coin or an orb is pitched up or down, at random, each time it lands.
const DROP_PITCH := 1.04
## A body's experience reaching the bar (`CombatScene.xp_absorbed`).
const XP_SOUNDS := [preload("res://Sounds/Sfx/xp_1.ogg"), preload("res://Sounds/Sfx/xp_2.ogg"),
		preload("res://Sounds/Sfx/xp_3.ogg"), preload("res://Sounds/Sfx/xp_4.ogg"),
		preload("res://Sounds/Sfx/xp_5.ogg")]

## One voice: a swing struck up mid-swing restarts it (`CombatScene._swing`).
var swing: AudioStreamPlayer
var hit: AudioStreamPlayer
var crit: AudioStreamPlayer
## `GENERAL_CRIT` for a blade, null otherwise.
var crit_layer: AudioStreamPlayer
var death: AudioStreamPlayer
var struck: AudioStreamPlayer
## `DROP_SOUNDS`' keys -> each one's player.
var drops := {}
var coin: AudioStreamPlayer
var orb: AudioStreamPlayer
var xp: AudioStreamPlayer


## `weapon_kind` is one of `LootTable.KINDS`, "" bare-handed.
func _init(weapon_kind: String) -> void:
	name = "Sounds"
	swing = _player(ATTACK_SOUND, 1)
	hit = _player(BLUNT_HIT if weapon_kind in BLUNT else HIT_SOUND)
	var blade := weapon_kind != "" and weapon_kind not in BLUNT
	crit = _player(SLASH_CRIT if blade else BLUNT_CRIT)
	if blade:
		crit_layer = _player(GENERAL_CRIT)
	death = _player(DEATH_SOUND)
	struck = _player(STRUCK_SOUND)
	for key: String in DROP_SOUNDS:
		drops[key] = _player(Juice.takes(DROP_SOUNDS[key], DROP_PITCH))
	coin = _player(Juice.takes([COIN_SOUND], DROP_PITCH))
	orb = _player(Juice.takes([ORB_DROP_SOUND], DROP_PITCH))
	xp = _player(Juice.takes(XP_SOUNDS))


func _player(stream: AudioStream, voices := 4) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Settings.SFX_BUS
	player.stream = stream
	player.max_polyphony = voices
	add_child(player)
	return player


## A blow that landed: a crit's sound plays in place of the blow's.
func blow(critical: bool) -> void:
	(crit if critical else hit).play()
	if critical and crit_layer != null:
		crit_layer.play()


## Which of `DROP_SOUNDS` a find lands with.
static func drop_sound_of(item: Item) -> String:
	return "unique" if item.rarity == ItemRarity.Rarity.UNIQUE else "gear"
