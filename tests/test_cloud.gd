extends "res://tests/harness.gd"
## The game's side of the cloud: what `Cloud` decides without calling anyone, its account file, the
## question it raises, and a sync played against scripted replies (`Cloud.transport`).

const ACCOUNT := "user://test_cloud.cfg"
## The two files a scripted cloud keeps in step, never the player's own.
const INVENTORY := "user://test_cloud_inventory.json"
const MAP := "user://test_cloud_map.json"
const METHODS := {HTTPClient.METHOD_GET: "GET", HTTPClient.METHOD_PUT: "PUT", HTTPClient.METHOD_POST: "POST",
		HTTPClient.METHOD_DELETE: "DELETE"}


func _run() -> void:
	_check(_test_decide() == true, "decide tests ran to the end")
	_check(_test_summary() == true, "summary tests ran to the end")
	_check(_test_score() == true, "score tests ran to the end")
	_check(_test_account() == true, "account tests ran to the end")
	_check(_test_off() == true, "off tests ran to the end")
	_check(await _test_question() == true, "question tests ran to the end")
	_check(await _test_a_first_save_goes_up() == true, "first save tests ran to the end")
	_check(await _test_a_session_gone_forgets_the_account() == true, "signed out tests ran to the end")
	_check(await _test_a_409_is_said_unless_it_is_a_save() == true, "conflict tests ran to the end")
	_check(await _test_a_failed_call_is_on_the_pages_at_once() == true, "failed call tests ran to the end")
	_check(await _test_a_download_is_read_before_it_is_written() == true, "download tests ran to the end")
	_check(await _test_a_blocked_cloud_moves_nothing() == true, "blocked tests ran to the end")
	_check(await _test_the_launch_hash_waits_for_calm() == true, "launch hash tests ran to the end")
	_check(await _test_an_answer_is_a_sync_of_its_own() == true, "answer tests ran to the end")
	_check(await _test_a_tick_reads_the_cloud_only_when_owed() == true, "tick tests ran to the end")
	_check(await _test_a_held_download_is_the_ticks_to_finish() == true, "held download tests ran to the end")
	_check(_test_the_waiting_list_follows_the_cloud() == true, "waiting list tests ran to the end")
	for path: String in [ACCOUNT, INVENTORY, MAP]:
		SafeFile.remove(path)
	_report("cloud")


func _test_decide() -> bool:
	_check(Cloud.decide(false, false) == Cloud.Action.NONE, "nothing moved, nothing to do")
	_check(Cloud.decide(true, false) == Cloud.Action.UPLOAD, "this device moved on: it goes up")
	_check(Cloud.decide(false, true) == Cloud.Action.DOWNLOAD, "the cloud moved on: it comes down")
	_check(Cloud.decide(true, true) == Cloud.Action.ASK, "both moved on: the player is asked")
	return true


func _test_summary() -> bool:
	var text := JSON.stringify({"level": 12, "play_seconds": 3725.6, "saved_at": 1790000000.5,
			"dungeon_floors": 44, "items": []})
	_check(Cloud.summary_of(text) == {"level": 12, "play_seconds": 3725, "saved_at": 1790000000,
			"dungeon_floors": 44}, "a save's summary is read off its inventory file (%s)" % Cloud.summary_of(text))
	_check(Cloud.summary_of("not json").level == 0, "and a file that is not a save reads as nothing")
	var files := {"inventory": text, "map": "{}"}
	_check(Cloud.hash_of(files) == Cloud.hash_of(files.duplicate()) and Cloud.hash_of(files)
			!= Cloud.hash_of({"inventory": text, "map": "{ }"}), "the hash follows both files, byte for byte")
	_check(CloudQuestion.played(3725) == "1h 2m" and CloudQuestion.played(125) == "2m 5s",
			"time played reads as hours once there are any")
	_check(CloudQuestion.when(0) == "Never", "a save never made says so")
	return true


func _test_score() -> bool:
	_check(Cloud.depth_and_floor(44) == Vector2i(3, 14) and Cloud.depth_and_floor(45) == Vector2i(4, 0)
			and Cloud.depth_and_floor(5) == Vector2i(1, 5), "a score is the depth and the floors of it beaten")
	_check(Cloud.score_text(44) == "Depth 3, floor 14", "and says so in words, not as a decimal")
	return true


func _test_account() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNT))
	var cloud := Cloud.new(ACCOUNT)
	_check(cloud.token.is_empty() and cloud.revision == 0, "a device with no account file has none")
	cloud.token = "t"
	cloud.provider = "discord"
	cloud.player_name = "Kobold"
	cloud.revision = 7
	cloud.synced = "abc"
	cloud.synced_at = 12.5
	cloud._save()
	var again := Cloud.new(ACCOUNT)
	_check([again.token, again.provider, again.player_name, again.revision, again.synced, again.synced_at]
			== ["t", "discord", "Kobold", 7, "abc", 12.5], "the account and where the sync stood come back")
	again._forget()
	_check(Cloud.new(ACCOUNT).token.is_empty() and Cloud.new(ACCOUNT).revision == 0,
			"forgetting the account forgets where the sync stood too")
	cloud.free()
	again.free()
	return true


func _test_off() -> bool:
	var off := Cloud.new()
	_check(not off.enabled() and not off.signed_in(), "a cloud with no account file is off")
	off.token = "t"
	_check(not off.signed_in(), "and stays off whatever it holds")
	off.free()
	return true


func _test_question() -> bool:
	var summary := {"level": 3, "play_seconds": 60, "saved_at": 1790000000, "dungeon_floors": 20}
	var answers: Array = []
	var question := CloudQuestion.new({"local": summary, "cloud": {}}, 1.0)
	question.answered.connect(func(keep_cloud: bool) -> void: answers.append(keep_cloud))
	root.add_child(question)
	await process_frame
	var buttons := question.find_children("*", "Button", true, false)
	var faces := buttons.map(func(made: Button) -> String: return made.text)
	_check(faces == ["Keep this device's", "Keep the cloud's"], "two saves ask with two answers %s" % [faces])
	var labels := question.find_children("*", "Label", true, false).map(func(made: Label) -> String: return made.text)
	_check("Unknown" in labels and "Depth 2, floor 5" in labels, "each side shows what is known of it")
	(buttons[0] as Button).pressed.emit()
	(buttons[1] as Button).pressed.emit()
	question.queue_free()
	_check(answers == [false, true], "the left keeps this device's and the right the cloud's (%s)" % [answers])
	return true


## A signed-in cloud over the two scratch files, calm, answering from `replies` ("GET /me" ->
## `{status, data}`; anything else cannot be reached) and keeping every request in `sent` as
## `[route, body]`, the route with its method.
func _scripted(replies: Dictionary, sent: Array) -> Cloud:
	var cloud := Cloud.new(ACCOUNT)
	cloud.token = "t"
	cloud.revision = 0
	cloud.synced = ""
	cloud.inventory_path = INVENTORY
	cloud.map_path = MAP
	cloud.calm = func() -> bool: return true
	cloud.transport = func(method: int, route: String, body: Variant, _bearer: String) -> Dictionary:
		var asked := "%s %s" % [METHODS[method], route]
		sent.append([asked, body])
		return replies.get(asked, {"status": 0, "data": {}})
	return cloud


## The two scratch files as a device holds them: an inventory at `level`, and a map.
func _write_saves(level: int) -> void:
	for file: Array in [[INVENTORY, JSON.stringify({"version": 1, "level": level})], [MAP, "{}"]]:
		var out := FileAccess.open(file[0], FileAccess.WRITE)
		out.store_string(file[1])
		out.close()


func _routes(sent: Array) -> Array:
	return sent.map(func(call: Array) -> String: return call[0])


## A cloud that holds nothing takes this device's save as its first, whatever this device thought it
## had grown from.
func _test_a_first_save_goes_up() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"GET /me": {"status": 200, "data": {"name": "Kobold", "save": null}},
			"PUT /save": {"status": 200, "data": {"revision": 1}}}, sent)
	cloud.revision = 4
	cloud.synced = "of another account"
	await cloud.sync()
	_check(_routes(sent) == ["GET /me", "PUT /save"] and sent[1][1].base_revision == 0 and not sent[1][1].replace,
			"a cloud with no save is sent this device's, as its first (%s)" % [_routes(sent)])
	_check(cloud.revision == 1 and cloud.synced == Cloud.hash_of(cloud.files()) and cloud.player_name == "Kobold",
			"and the device stands at that revision")
	cloud.free()
	return true


func _test_a_session_gone_forgets_the_account() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"GET /me": {"status": 401, "data": {"error": "Sign in first"}}}, sent)
	cloud.revision = 2
	await cloud.sync()
	_check(cloud.token.is_empty() and cloud.revision == 0 and not cloud.signed_in(),
			"a session the server no longer knows signs this device out")
	_check(cloud.problem == "You were signed out. Sign in again", "and says so (%s)" % cloud.problem)
	_check(_routes(sent) == ["GET /me"] and FileAccess.file_exists(INVENTORY), "with its files left alone")
	cloud.free()
	return true


## A name that is taken is a 409 the player must be told; a save another device beat is one they need not.
func _test_a_409_is_said_unless_it_is_a_save() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"PUT /me/name": {"status": 409, "data": {"error": "That name is taken"}},
			"GET /me": {"status": 200, "data": {"save": {"revision": 2, "summary": {}}}},
			"PUT /save": {"status": 409, "data": {"error": "The cloud has a newer save", "revision": 3}}}, sent)
	await cloud.choose_name("Gollux")
	_check(cloud.problem == "That name is taken" and cloud.player_name.is_empty(),
			"a name that is taken says so (%s)" % cloud.problem)
	cloud.revision = 2
	cloud.synced = "as it was"
	await cloud.sync()
	_check(_routes(sent).slice(1) == ["GET /me", "PUT /save"] and cloud.problem.is_empty(),
			"a save another device beat to the cloud is no problem to show (%s)" % cloud.problem)
	_check(cloud.revision == 2 and cloud.synced == "as it was", "and the next sync still has it to ask about")
	cloud.free()
	return true


## The pages hear of a call as it comes back, not only as it goes out.
func _test_a_failed_call_is_on_the_pages_at_once() -> bool:
	var sent: Array = []
	var cloud := _scripted({}, sent)
	var heard: Array = []
	cloud.changed.connect(func() -> void: heard.append([cloud.busy(), cloud.problem]))
	await cloud.delete_account()
	_check(_routes(sent) == ["DELETE /me"] and cloud.signed_in(),
			"an account the server could not be asked to delete stays")
	_check(not heard.is_empty() and heard[-1] == [false, "The cloud cannot be reached"],
			"and the pages are told the call is back, and why it failed (%s)" % [heard])
	cloud.free()
	return true


## Whatever a 200 carried is not written until it reads as a save this build can load.
func _test_a_download_is_read_before_it_is_written() -> bool:
	_write_saves(3)
	var sent: Array = []
	var replies := {"GET /me": {"status": 200, "data": {"save": {"revision": 5, "summary": {}}}}}
	var cloud := _scripted(replies, sent)
	cloud.revision = 2
	cloud.synced = Cloud.hash_of(cloud.files())
	var replaced: Array = []
	cloud.replaced.connect(func() -> void: replaced.append(true))
	var held := Cloud.hash_of(cloud.files())
	var newer := JSON.stringify({"version": Inventory.VERSION + 1, "level": 9})
	for carried: Dictionary in [{}, {"revision": 5, "inventory": "<html>", "map": ""},
			{"revision": 5, "inventory": newer, "map": ""},
			{"revision": 5, "inventory": JSON.stringify({"version": 1}), "map": "not a map"}]:
		replies["GET /save"] = {"status": 200, "data": carried}
		await cloud.sync()
		_check(Cloud.hash_of(cloud.files()) == held and cloud.revision == 2 and replaced.is_empty(),
				"a reply that is no save this build reads is not written (%s)" % [carried])
		_check(not cloud.problem.is_empty(), "and the pages say the cloud's save cannot be loaded")
	replies["GET /save"] = {"status": 200, "data": {"revision": 5,
			"inventory": JSON.stringify({"version": 1, "level": 9}), "map": ""}}
	await cloud.sync()
	_check(replaced.size() == 1 and cloud.revision == 5 and Cloud.summary_of(cloud.files().inventory).level == 9
			and not FileAccess.file_exists(MAP), "one that reads comes down, a save with no map taking the map away")
	cloud.free()
	return true


## Over a save the main scene refused, nothing goes up and nothing comes down.
func _test_a_blocked_cloud_moves_nothing() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"GET /me": {"status": 200, "data": {"save": null}}}, sent)
	cloud.blocked = true
	await cloud.sync(true)
	await cloud.push()
	_check(sent.is_empty(), "a blocked cloud calls nobody (%s)" % [_routes(sent)])
	cloud.blocked = false
	await cloud.push()
	_check(_routes(sent) == ["PUT /save"], "and unblocked, the way out uploads")
	cloud.free()
	return true


## A change of device is a download, not a question, even when the start-up stood a camp up before its
## first sync: the launch's hash is not spent on a sync that could not act.
func _test_the_launch_hash_waits_for_calm() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"GET /me": {"status": 200, "data": {"save": {"revision": 3, "summary": {}}}},
			"GET /save": {"status": 200, "data": {"revision": 3,
				"inventory": JSON.stringify({"version": 1, "level": 9}), "map": ""}}}, sent)
	cloud.revision = 2
	cloud.synced = Cloud.hash_of(cloud.files())
	var calm := [false]
	cloud.calm = func() -> bool: return calm[0]
	cloud.launched()
	# The start-up's own writes: the map, a camp's pay.
	_write_saves(4)
	await cloud.sync(true)
	_check(sent.is_empty() and cloud.question.is_empty(), "under a camp the first sync waits (%s)" % [_routes(sent)])
	calm[0] = true
	await cloud.sync(true)
	_check(_routes(sent) == ["GET /me", "GET /save"] and cloud.question.is_empty() and cloud.revision == 3,
			"and once the camp is struck the other device's save comes down, unasked (%s)" % [_routes(sent)])
	# Later, what was saved since is play: both sides moved on, and that is a question.
	_write_saves(5)
	sent.clear()
	cloud.revision = 2
	await cloud.sync(true)
	_check(_routes(sent) == ["GET /me"] and not cloud.question.is_empty(), "the launch's hash is read once")
	cloud.free()
	return true


## A tick in the middle of an answer waits for it rather than asking again.
func _test_an_answer_is_a_sync_of_its_own() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({}, sent)
	cloud.revision = 2
	cloud.transport = func(_method: int, route: String, _body: Variant, _bearer: String) -> Dictionary:
		sent.append(route)
		if route == "/save":
			await process_frame
			return {"status": 200, "data": {"revision": 7}}
		return {"status": 200, "data": {"save": {"revision": 6, "summary": {}}}}
	cloud.question = {"local": {}, "cloud": {}}
	var heard: Array = []
	cloud.changed.connect(func() -> void: heard.append(cloud.busy()))
	cloud.keep_device()
	await cloud.sync()
	_check(sent == ["/save"] and cloud.question.is_empty(),
			"a tick while the answer is going up asks nothing (%s)" % [sent])
	for i in 3:
		await process_frame
	_check(cloud.revision == 7 and cloud.synced == Cloud.hash_of(cloud.files()), "the answer lands")
	_check(not heard.is_empty() and heard[-1] == false, "and the pages are told when it has")
	await cloud.sync()
	_check(sent.slice(0, 2) == ["/save", "/me"], "and the next tick syncs as ever (%s)" % [sent])
	cloud.free()
	return true


## A tick reads `/me` only while a sync is owed: otherwise it uploads a changed save when due, and an
## upload another device beat to the cloud (409) is a sync there and then.
func _test_a_tick_reads_the_cloud_only_when_owed() -> bool:
	_write_saves(3)
	var sent: Array = []
	var replies := {"GET /me": {"status": 200, "data": {"save": {"revision": 2, "summary": {}}}},
			"PUT /save": {"status": 200, "data": {"revision": 3}}}
	var cloud := _scripted(replies, sent)
	cloud.revision = 2
	cloud.synced = Cloud.hash_of(cloud.files())
	await cloud._tick()
	_check(_routes(sent) == ["GET /me"], "a new cloud's first tick is a full sync (%s)" % [_routes(sent)])
	sent.clear()
	await cloud._tick()
	_check(sent.is_empty(), "a tick over an unchanged save calls nobody (%s)" % [_routes(sent)])
	_write_saves(4)
	await cloud._tick()
	_check(_routes(sent) == ["PUT /save"] and cloud.revision == 3,
			"a changed save goes up with no /me before it (%s)" % [_routes(sent)])
	_write_saves(5)
	sent.clear()
	await cloud._tick()
	_check(sent.is_empty(), "and the next change waits for UPLOAD_EVERY (%s)" % [_routes(sent)])
	cloud._uploaded_ms = -1
	replies["PUT /save"] = {"status": 409, "data": {"error": "The cloud has a newer save", "revision": 4}}
	replies["GET /me"] = {"status": 200, "data": {"save": {"revision": 4, "summary": {}}}}
	await cloud._tick()
	_check(_routes(sent) == ["PUT /save", "GET /me"] and not cloud.question.is_empty(),
			"an upload another device beat syncs at once, and asks (%s)" % [_routes(sent)])
	cloud.free()
	return true


## A newer save found mid-fight waits for calm, and the tick keeps syncing until it is down.
func _test_a_held_download_is_the_ticks_to_finish() -> bool:
	_write_saves(3)
	var sent: Array = []
	var cloud := _scripted({"GET /me": {"status": 200, "data": {"save": {"revision": 3, "summary": {}}}},
			"GET /save": {"status": 200, "data": {"revision": 3,
				"inventory": JSON.stringify({"version": 1, "level": 9}), "map": ""}}}, sent)
	cloud.revision = 2
	cloud.synced = Cloud.hash_of(cloud.files())
	var calm := [false]
	cloud.calm = func() -> bool: return calm[0]
	await cloud.sync(true)
	_check(_routes(sent) == ["GET /me"] and cloud.revision == 2, "mid-fight the newer save waits")
	calm[0] = true
	await cloud._tick()
	_check(_routes(sent) == ["GET /me", "GET /me", "GET /save"] and cloud.revision == 3,
			"and the next calm tick brings it down (%s)" % [_routes(sent)])
	sent.clear()
	await cloud._tick()
	_check(sent.is_empty(), "after which a tick calls nobody (%s)" % [_routes(sent)])
	cloud.free()
	return true


## The landing page's waiting list is the cloud's Worker, wherever that is pointed.
func _test_the_waiting_list_follows_the_cloud() -> bool:
	var landing: Variant = load("res://Scenes/landing.gd")
	var was := OS.get_environment("LEADERBOARD_URL")
	OS.set_environment("LEADERBOARD_URL", "http://localhost:8787/")
	_check(landing.waitlist() == "http://localhost:8787/waitlist",
			"a run pointed at a local Worker sends no address to the real list (%s)" % landing.waitlist())
	if was.is_empty():
		OS.unset_environment("LEADERBOARD_URL")
	else:
		OS.set_environment("LEADERBOARD_URL", was)
	return true
