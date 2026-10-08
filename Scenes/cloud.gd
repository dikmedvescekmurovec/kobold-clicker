class_name Cloud
extends Node
## The player's account and cloud save, and the leaderboards, against the Worker in
## `backend/leaderboard/` (its README holds the API, the sign-in flow and what the server keeps).
##
## Signing in is optional. `sign_in` opens the browser at the server's sign-in page, where the player
## picks Google or Discord; the game polls until the server hands it a session token, and shows the
## same four letters the page shows (`signing_check`). From then on `sync` keeps the two save files and
## the cloud together: this device's files are the cloud's `revision`, as they were when their hash was
## `synced`. A change here alone is uploaded; a change in the cloud alone is downloaded over the files
## and the main scene reloads (`replaced`); both is a question (`asked`) the player answers with
## `keep_cloud` or `keep_device`. The server takes every save at its word: the player is trusted not
## to cheat. Nothing here ever blocks the game: a call that fails is a sentence (`problem`) and the next
## tick tries again.
##
## One lives under the root for the whole run (`NODE`), outliving the reloads a download or a
## transcension makes; the main scene finds it again each time. Off (`path` empty) everywhere but the
## player's own save, as the settings are.

## The account, the board, the sync or `problem` changed: the pages redraw.
signal changed
## The cloud's save was written over this device's files. The main scene must reload without saving.
signal replaced
## A question for the player: `question` says which. Asked only while `calm` says one may be.
signal asked

enum Action { NONE, UPLOAD, DOWNLOAD, ASK }

## Where the Worker answers, with no slash at the end. Shipped builds call this for ever, so the Worker
## is never renamed. `LEADERBOARD_URL` in the environment overrides it (a local `npm run dev`).
const URL := "https://gollux-leaderboard.kobold-clicker.workers.dev"
const NODE := "Cloud"
const SAVE_PATH := "user://cloud.cfg"
## An account made against an overridden URL is kept apart, so testing never touches the real one.
const DEV_PATH := "user://cloud_dev.cfg"
## The anonymous leaderboard's account file from before sign-in: its token is sent once, at the first
## sign-in, so the server hands that name to the account, and the file is then deleted.
const LEGACY_PATHS := ["user://leaderboard.cfg", "user://leaderboard_dev.cfg"]
const TIMEOUT := 10.0
## On the way out of the game: a slow server must not hold the window open for long.
const QUIT_TIMEOUT := 4.0
## How many of the top the board page asks for; the server gives at most 100.
const TOP := 50
## How often the game looks at the cloud while it runs, and uploads at most: every save rewrites the
## files, so this is what a player's hour costs in requests. Leaving the game and a descent upload at once.
const TICK := 30.0
const UPLOAD_EVERY := 300.0
## A sign-in: how often the game asks whether the player has finished it, and for how long.
const POLL_EVERY := 2.0
const SIGN_IN_SECONDS := 600.0

## Where the account is kept; empty is a cloud that is off. Given at `_init`.
var path := ""
## The two files it keeps in the cloud: the player's saves, anywhere but a test.
var inventory_path := Inventory.SAVE_PATH
var map_path := MapSave.SAVE_PATH
var token := ""
## "google" or "discord": what the account was signed in with on this device.
var provider := ""
## The board name, "" until chosen.
var player_name := ""
## The cloud revision this device's files grew from, 0 for none; and their hash as they were then.
var revision := 0
var synced := ""
## When this device last uploaded or downloaded, in unix seconds; 0 for never.
var synced_at := 0.0
## The four letters a sign-in under way shows, "" when none is.
var signing_check := ""
## Two saves that both moved on, waiting for the player to keep one, `{local, cloud}` (each a
## `summary_of`); empty when nothing waits. `sync` holds back while it waits.
var question := {}
## The boards the server keeps: Gollux's floors, ice walls broken in every world (`tally.walls`) and
## the deepest tile charted (`Inventory.deepest_level`).
const BOARDS: Array[String] = ["gollux", "walls", "deepest"]
## Each board as last read, by its name: `{top, me}`, `top` its rows best first (`{rank, name, score,
## reached_at}`) and `me` the player's own `{score, rank}` on it. A board not yet read is absent.
var boards := {}
## The player's own row as last read (`/me`): name, floors, rank, providers, save. Empty until read.
var me := {}
## Why the last call failed, for the pages; empty when it did not.
var problem := ""
## The main scene's say on whether a question may be put up or the save replaced now: never mid-fight,
## on the black screen or in a camp. A cloud with none set does neither.
var calm := Callable()
## How the sign-in page is opened. Tests hand it a Callable that only keeps the address.
var open_url := func(address: String) -> void: OS.shell_open(address)

var _out := 0
var _syncing := false
## The files' hash as a scene found them, before its start-up wrote anything (`launched`): the first
## sync judges this device by it, so the start-up's own writes are not taken for play.
var _launch_hash := ""
## When the last upload went, in engine ticks (ms); a start-up's first sync uploads whenever it is due.
var _uploaded_ms := -1
var _timeout := TIMEOUT


func _init(account_path := "") -> void:
	path = account_path
	if path.is_empty():
		return
	var saved := ConfigFile.new()
	SafeFile.recover(path)
	if saved.load(path) == OK:
		token = str(saved.get_value("account", "token", ""))
		provider = str(saved.get_value("account", "provider", ""))
		player_name = str(saved.get_value("account", "name", ""))
		revision = int(saved.get_value("sync", "revision", 0))
		synced = str(saved.get_value("sync", "hash", ""))
		synced_at = float(saved.get_value("sync", "at", 0.0))


func _ready() -> void:
	if path.is_empty():
		return
	var timer := Timer.new()
	timer.wait_time = TICK
	timer.timeout.connect(sync)
	add_child(timer)
	timer.start()


static func url() -> String:
	return OS.get_environment("LEADERBOARD_URL").trim_suffix("/") if OS.has_environment("LEADERBOARD_URL") \
			else URL


## The account file for the player's own save.
static func save_path() -> String:
	return DEV_PATH if OS.has_environment("LEADERBOARD_URL") else SAVE_PATH


func enabled() -> bool:
	return not path.is_empty() and not url().is_empty()


func signed_in() -> bool:
	return enabled() and not token.is_empty()


## A call is out: the pages grey their buttons.
func busy() -> bool:
	return _out > 0


## A score as the depth reached and the floors of it beaten: 44 is depth 3, floor 14. Gollux is the
## fifteenth, so killing him is the next depth's floor 0.
static func depth_and_floor(floors: int) -> Vector2i:
	var depth: int = Encounter.DUNGEON.enemies
	return Vector2i(floors / depth + 1, floors % depth)


## The same in words. It was "3.14" once, which read as a decimal.
static func score_text(floors: int) -> String:
	var at := depth_and_floor(floors)
	return "Depth %d, floor %d" % [at.x, at.y]


## What to do about two sides that may each have changed since they last agreed.
static func decide(here_changed: bool, cloud_changed: bool) -> Action:
	if here_changed and cloud_changed:
		return Action.ASK
	if cloud_changed:
		return Action.DOWNLOAD
	return Action.UPLOAD if here_changed else Action.NONE


## What the question between two saves shows of one, read from its inventory file: the server's own
## `summary` (src/index.js) worked out here for this device's side.
static func summary_of(inventory_text: String) -> Dictionary:
	var reader := JSON.new()
	var save: Dictionary = reader.data if reader.parse(inventory_text) == OK and reader.data is Dictionary else {}
	return {
		"level": int(save.get("level", 0)),
		"play_seconds": int(save.get("play_seconds", 0)),
		"saved_at": int(save.get("saved_at", 0)),
		"dungeon_floors": int(save.get("dungeon_floors", 0)),
	}


## The two save files as they stand, `{inventory, map}`; empty when there is no inventory to send.
func files() -> Dictionary:
	for file: String in [inventory_path, map_path]:
		SafeFile.recover(file)
	if not FileAccess.file_exists(inventory_path):
		return {}
	return {
		"inventory": FileAccess.get_file_as_string(inventory_path),
		"map": FileAccess.get_file_as_string(map_path) if FileAccess.file_exists(map_path) else "",
	}


static func hash_of(saved: Dictionary) -> String:
	return (str(saved.get("inventory", "")) + "\n" + str(saved.get("map", ""))).sha256_text()


## How the cloud stands, for the settings page.
func status_text() -> String:
	if not signed_in():
		return ""
	if not question.is_empty():
		return "Waiting for your answer"
	if synced_at <= 0.0:
		return "Not saved to the cloud yet"
	var ago := int(Time.get_unix_time_from_system() - synced_at)
	if ago < 60:
		return "Saved to the cloud just now"
	if ago < 3600:
		return "Saved to the cloud %d min ago" % (ago / 60)
	return "Saved to the cloud %d h ago" % (ago / 3600)


# ---------------------------------------------------------------------------------------------------
# Signing in and out.

## Starts a sign-in: the browser opens at the server's page, and this polls until the player has
## finished there, the time runs out, or `cancel_sign_in` is pressed. Then the first sync.
func sign_in() -> void:
	if not enabled() or signed_in() or not signing_check.is_empty():
		return
	var started := await _call(HTTPClient.METHOD_POST, "/logins", {}, _legacy_token())
	if started.status != 201:
		return
	var check := str(started.data.get("check", ""))
	var code := str(started.data.get("code", ""))
	signing_check = check
	changed.emit()
	open_url.call(str(started.data.get("url", "")))
	var until := Time.get_ticks_msec() + int(SIGN_IN_SECONDS * 1000.0)
	while signing_check == check and Time.get_ticks_msec() < until:
		await get_tree().create_timer(POLL_EVERY).timeout
		if signing_check != check:
			return
		var polled := await _call(HTTPClient.METHOD_POST, "/logins/poll", {"code": code}, "")
		if polled.status == 200:
			token = str(polled.data.get("token", ""))
			provider = str(polled.data.get("provider", ""))
			signing_check = ""
			# A new account on this device: whatever the cloud holds, this device grew from none of it.
			revision = 0
			synced = ""
			_save()
			for legacy: String in LEGACY_PATHS:
				if FileAccess.file_exists(legacy):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy))
			await sync(true)
			return
		if polled.status == 404:
			break
	if signing_check == check:
		signing_check = ""
		problem = "Signing in ran out of time. Try again"
		changed.emit()


func cancel_sign_in() -> void:
	signing_check = ""
	changed.emit()


## This device forgets the account; the save files stay as they are.
func sign_out() -> void:
	if signed_in():
		await _call(HTTPClient.METHOD_DELETE, "/sessions/me")
	_forget()


## The server forgets everything it holds about the player, and this device the account.
func delete_account() -> void:
	if not signed_in():
		return
	var reply := await _call(HTTPClient.METHOD_DELETE, "/me")
	if reply.status == 200:
		_forget()


## The board name. The server checks it and says why it will not have it.
func choose_name(wanted: String) -> void:
	if not signed_in() or busy():
		return
	var reply := await _call(HTTPClient.METHOD_PUT, "/me/name", {"name": wanted.strip_edges()})
	if reply.status == 200:
		_take_me(reply.data)
		_save()
	changed.emit()


## Reads the top of `board` (one of `BOARDS`), and the player's own place on it.
func refresh(board: String = BOARDS[0]) -> void:
	if not enabled():
		return
	var reply := await _call(HTTPClient.METHOD_GET, "/leaderboard?board=%s&limit=%d" % [board, TOP])
	if reply.status == 200:
		boards[board] = {"top": reply.data.get("top") if reply.data.get("top") is Array else [],
				"me": reply.data.get("me") if reply.data.get("me") is Dictionary else {}}
	changed.emit()


# ---------------------------------------------------------------------------------------------------
# Syncing.

## Called by a scene before it writes anything: the files as they stand are what this device holds.
## A start-up rewrites the map and may pay a camp, and without this every change of device would be a
## question rather than a download.
func launched() -> void:
	var saved := files()
	_launch_hash = hash_of(saved) if not saved.is_empty() else ""

## Brings this device and the cloud together (`decide`). An upload waits for `UPLOAD_EVERY` unless
## `now`; a download or a question waits for `calm`. Safe to call as often as wanted.
func sync(now := false) -> void:
	if not signed_in() or _syncing or not question.is_empty():
		return
	_syncing = true
	# Only the first sync after a start-up may read the launch's hash, reached or not: later, what was
	# saved since is real play, and a download judged by the old hash would overwrite it.
	var launch := _launch_hash
	_launch_hash = ""
	var reply := await _call(HTTPClient.METHOD_GET, "/me")
	if reply.status == 200:
		_take_me(reply.data)
		var saved := files()
		var cloud: Variant = reply.data.get("save")
		var cloud_revision := int(cloud.get("revision", 0)) if cloud is Dictionary else 0
		if not saved.is_empty():
			if cloud_revision == 0:
				# The cloud holds nothing (a first sign-in, or a reset elsewhere): this device's save is it.
				revision = 0
				await _upload(saved, false)
			else:
				var here := launch if not launch.is_empty() else hash_of(saved)
				match decide(here != synced, cloud_revision != revision):
					Action.UPLOAD:
						if now or _uploaded_ms < 0 or Time.get_ticks_msec() - _uploaded_ms >= UPLOAD_EVERY * 1000.0:
							await _upload(saved, false)
					Action.DOWNLOAD:
						if _calm():
							await _download()
					Action.ASK:
						if _calm():
							_ask(saved, cloud.get("summary", {}))
	_syncing = false
	changed.emit()


## Uploads now if this device has changed since it last agreed with the cloud, and nothing else: the
## way out of the game, where nothing may be asked or replaced. Quick to give up.
func push() -> void:
	var saved := files()
	if not signed_in() or not question.is_empty() or saved.is_empty() or hash_of(saved) == synced:
		return
	_timeout = QUIT_TIMEOUT
	await _upload(saved, false)
	_timeout = TIMEOUT


## Closes `scene` the way quitting would -- its `_exit_tree` banks the run and writes the saves --
## uploads what that wrote, and quits. Lives here because the scene is gone by the time the upload is.
func leave(scene: Node) -> void:
	var tree := get_tree()
	scene.get_parent().remove_child(scene)
	scene.queue_free()
	await push()
	tree.quit()


## The question answered for the cloud's save: it comes down over this device's files.
func keep_cloud() -> void:
	question = {}
	changed.emit()
	await _download()


## The question answered for this device's save: it goes up in the cloud's place.
func keep_device() -> void:
	question = {}
	changed.emit()
	var saved := files()
	if saved.is_empty():
		return
	await _upload(saved, true)


## Reset save: the cloud's copy goes too, and this device starts from none of it. Awaited before the
## files are deleted, so the fresh game that follows is the cloud's first save and not a conflict.
func forget_save() -> void:
	if not signed_in():
		return
	var reply := await _call(HTTPClient.METHOD_DELETE, "/save")
	if reply.status == 200:
		revision = 0
		synced = ""
		_save()


func _upload(saved: Dictionary, replace: bool) -> void:
	var reply := await _call(HTTPClient.METHOD_PUT, "/save", {"base_revision": revision, "replace": replace,
			"inventory": saved.inventory, "map": saved.map})
	match reply.status:
		200:
			revision = int(reply.data.get("revision", revision))
			synced = hash_of(saved)
			synced_at = Time.get_unix_time_from_system()
			_uploaded_ms = Time.get_ticks_msec()
			_take_me(reply.data)
			_save()
		409:
			# Another device got there first; the next sync finds out and asks.
			problem = ""


## The cloud's save written over this device's files, and `replaced` for the main scene to reload. Not
## if the game stopped being calm while it came down: then the next tick tries again.
func _download() -> void:
	var reply := await _call(HTTPClient.METHOD_GET, "/save")
	if reply.status != 200 or not _calm():
		return
	var saved := {"inventory": str(reply.data.get("inventory", "")), "map": str(reply.data.get("map", ""))}
	if not SafeFile.write(inventory_path, saved.inventory):
		return
	if saved.map.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	elif not SafeFile.write(map_path, saved.map):
		return
	revision = int(reply.data.get("revision", 0))
	synced = hash_of(saved)
	synced_at = Time.get_unix_time_from_system()
	_save()
	replaced.emit()


func _ask(saved: Dictionary, cloud_summary: Variant) -> void:
	question = {"local": summary_of(saved.inventory),
			"cloud": cloud_summary if cloud_summary is Dictionary else {}}
	asked.emit()


func _calm() -> bool:
	return calm.is_valid() and calm.call()


func _take_me(row: Variant) -> void:
	if not row is Dictionary:
		return
	for key: String in row:
		me[key] = row[key]
	player_name = str(me.get("name")) if me.get("name") != null else ""


## The anonymous leaderboard's token, if this device had one.
func _legacy_token() -> String:
	for legacy: String in LEGACY_PATHS:
		var saved := ConfigFile.new()
		if saved.load(legacy) == OK:
			return str(saved.get_value("account", "token", ""))
	return ""


func _forget() -> void:
	token = ""
	provider = ""
	player_name = ""
	revision = 0
	synced = ""
	synced_at = 0.0
	question = {}
	me = {}
	_save()
	changed.emit()


## One request, awaited: `{status, data}`, status 0 where nothing came back. Sets `problem` from the
## server's own sentence. A 401 on a signed-in call is a session the server no longer knows (signed out
## or deleted elsewhere): this device forgets the account, and its files stay.
func _call(method: HTTPClient.Method, route: String, body: Variant = null, bearer: Variant = null) -> Dictionary:
	_out += 1
	problem = ""
	changed.emit()
	var request := HTTPRequest.new()
	request.timeout = _timeout
	add_child(request)
	var sent_token: String = token if bearer == null else str(bearer)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not sent_token.is_empty():
		headers.append("Authorization: Bearer " + sent_token)
	var status := 0
	var data := {}
	if request.request(url() + route, headers, method, "" if body == null else JSON.stringify(body)) == OK:
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
		problem = "The cloud cannot be reached"
	elif status >= 400 and status != 409:
		problem = str(data.get("error", "The cloud said no (%d)" % status))
	if status == 401 and bearer == null and signed_in():
		_forget()
		problem = "You were signed out. Sign in again"
	return {"status": status, "data": data}


func _save() -> void:
	if path.is_empty():
		return
	var saved := ConfigFile.new()
	saved.set_value("account", "token", token)
	saved.set_value("account", "provider", provider)
	saved.set_value("account", "name", player_name)
	saved.set_value("sync", "revision", revision)
	saved.set_value("sync", "hash", synced)
	saved.set_value("sync", "at", synced_at)
	SafeFile.write(path, saved.encode_to_text())
