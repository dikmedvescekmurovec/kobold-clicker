class_name Leaderboard
extends Node
## The Gollux leaderboard's client: an anonymous account (a name and the secret token the server gave
## for it, in `user://leaderboard.cfg`) and the three calls the server answers -- join, send a best,
## read the board. The server and how it is deployed: `backend/leaderboard/README.md`.
##
## A score is every floor of the dungeon ever beaten (`Inventory.dungeon_floors`), written "3.14":
## depth 3, its fourteenth floor beaten. Nothing here ever blocks the game or asks twice: a call that
## fails is said on the page and nothing more, and a best the server never heard of is sent again at
## the next start-up (`sent` is what it last acknowledged).

## The account, the board or `problem` changed: the page redraws.
signal changed

## Where the Worker answers, with no slash at the end. Empty is a build with no leaderboard.
## `LEADERBOARD_URL` in the environment overrides it (a local `npm run dev` is http://127.0.0.1:8787).
const URL := ""
const SAVE_PATH := "user://leaderboard.cfg"
## An account made against an overridden URL is kept apart, so testing never touches the real one.
const DEV_PATH := "user://leaderboard_dev.cfg"
const TIMEOUT := 10.0
## How many of the top the page asks for; the server gives at most 100.
const TOP := 50

## Where the account is kept. Empty (a test, a screenshot: anything not on the player's own save) is a
## board that is off -- it never reads the account, calls out or writes. Set before it enters the tree.
var path := ""
var player_name := ""
var token := ""
## The best the server has acknowledged, in floors.
var sent := 0
## The board as last read: `{rank, name, floors, reached_at}` a row, best first.
var top: Array = []
## The player's own row as last read, with `rank` null until they have beaten a floor. Empty until read.
var me: Dictionary = {}
## Why the last call failed, for the page; empty when it did not.
var problem := ""
## How many calls are out. Each is its own `HTTPRequest`, so a send and a read can overlap.
var _out := 0


func _ready() -> void:
	if path.is_empty():
		return
	var saved := ConfigFile.new()
	SafeFile.recover(path)
	if saved.load(path) == OK:
		player_name = str(saved.get_value("account", "name", ""))
		token = str(saved.get_value("account", "token", ""))
		sent = int(saved.get_value("account", "sent", 0))


static func url() -> String:
	return OS.get_environment("LEADERBOARD_URL").trim_suffix("/") if OS.has_environment("LEADERBOARD_URL") \
			else URL


func enabled() -> bool:
	return not path.is_empty() and not url().is_empty()


func joined() -> bool:
	return not token.is_empty()


## A call is out: the page greys its buttons.
func busy() -> bool:
	return _out > 0


## A score as the board writes it: the depth, then the floors of it beaten, "3.14". Gollux is the
## fifteenth, so killing him is the next depth's ".00".
static func score_text(floors: int) -> String:
	var depth: int = Encounter.DUNGEON.enemies
	return "%d.%02d" % [floors / depth + 1, floors % depth]


## An account under `wanted`. The server checks the name and says why it will not have it.
func join(wanted: String) -> void:
	if joined() or busy() or not enabled():
		return
	var reply := await _call(HTTPClient.METHOD_POST, "/players", {"name": wanted.strip_edges()})
	if reply.status == 201:
		player_name = str(reply.data.get("name", wanted))
		token = str(reply.data.get("token", ""))
		sent = 0
		_save()
	changed.emit()


## Sends `floors` if it beats what the server already has. Safe to call as often as wanted.
func submit(floors: int) -> void:
	if not joined() or floors <= sent or not enabled():
		return
	var reply := await _call(HTTPClient.METHOD_POST, "/scores", {"floors": floors})
	if reply.status == 200:
		_take_me(reply.data)
		sent = maxi(sent, int(reply.data.get("floors", 0)))
		_save()
	changed.emit()


## Reads the top of the board, and the player's own place on it.
func refresh() -> void:
	if not enabled():
		return
	var reply := await _call(HTTPClient.METHOD_GET, "/leaderboard?limit=%d" % TOP)
	if reply.status == 200:
		top = reply.data.get("top", []) if reply.data.get("top") is Array else []
		_take_me(reply.data.get("me"))
	changed.emit()


func _take_me(row: Variant) -> void:
	me = row if row is Dictionary else {}


## One request, awaited: `{status, data}`, status 0 where nothing came back. Sets `problem` from the
## server's own sentence, and forgets an account the server no longer knows (401) so the page offers
## to join again -- its token is worth nothing any more.
func _call(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	_out += 1
	problem = ""
	changed.emit()
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if joined():
		headers.append("Authorization: Bearer " + token)
	var status := 0
	var data := {}
	if request.request(url() + path, headers, method, "" if body == null else JSON.stringify(body)) == OK:
		var reply: Array = await request.request_completed
		if reply[0] == HTTPRequest.RESULT_SUCCESS:
			status = reply[1]
			var reader := JSON.new()
			if reader.parse((reply[3] as PackedByteArray).get_string_from_utf8()) == OK \
					and reader.data is Dictionary:
				data = reader.data
	request.queue_free()
	_out -= 1
	if status == 0:
		problem = "The leaderboard cannot be reached"
	elif status >= 400:
		problem = str(data.get("error", "The leaderboard said no (%d)" % status))
	if status == 401:
		player_name = ""
		token = ""
		sent = 0
		me = {}
		_save()
	return {"status": status, "data": data}


func _save() -> void:
	var saved := ConfigFile.new()
	saved.set_value("account", "name", player_name)
	saved.set_value("account", "token", token)
	saved.set_value("account", "sent", sent)
	SafeFile.write(path, saved.encode_to_text())


## The account file for the player's own save.
static func save_path() -> String:
	return DEV_PATH if OS.has_environment("LEADERBOARD_URL") else SAVE_PATH
