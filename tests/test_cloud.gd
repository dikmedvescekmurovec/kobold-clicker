extends "res://tests/harness.gd"
## The game's side of the cloud: what `Cloud` decides without calling anyone, its account file, the
## question it raises, and that the server's two copies of the game's numbers still agree with it.

const ACCOUNT := "user://test_cloud.cfg"
const CHECKS_JS := "res://backend/leaderboard/src/checks.js"


func _run() -> void:
	for passed: Variant in [_test_decide(), _test_summary(), _test_score(), _test_account(), _test_off(),
			_test_server_mirrors(), await _test_question()]:
		_check(passed == true, "a test function finished")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNT))
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
	_check(Cloud.score_text(44) == "3.14" and Cloud.score_text(45) == "4.00" and Cloud.score_text(5) == "1.05",
			"a score is the depth and the floors of it beaten, two digits")
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


## checks.js cannot read the game, so it copies two numbers; a change to either here must reach it.
func _test_server_mirrors() -> bool:
	var source := FileAccess.get_file_as_string(CHECKS_JS)
	_check("FLOORS_PER_DEPTH = %d;" % Encounter.DUNGEON.enemies in source,
			"the server's depth is Encounter.DUNGEON's %d floors" % Encounter.DUNGEON.enemies)
	var seconds := RegEx.create_from_string("SECONDS_PER_FLOOR = ([0-9.]+);").search(source)
	_check(seconds != null and float(seconds.get_string(1)) <= Encounter.DEATH,
			"no floor falls faster than the server allows (Encounter.DEATH %s)" % Encounter.DEATH)
	return true


func _test_question() -> bool:
	var summary := {"level": 3, "play_seconds": 60, "saved_at": 1790000000, "dungeon_floors": 20}
	var answers: Array = []
	for kind: String in ["conflict", "refused"]:
		var question := CloudQuestion.new({"kind": kind, "local": summary, "cloud": {}, "reason": "Kills went down"}, 1.0)
		question.answered.connect(func(keep_cloud: bool) -> void: answers.append([kind, keep_cloud]))
		root.add_child(question)
		await process_frame
		var buttons := question.find_children("*", "Button", true, false)
		var faces := buttons.map(func(made: Button) -> String: return made.text)
		_check(faces == (["Keep this device's", "Keep the cloud's"] if kind == "conflict"
				else ["Start over from this device", "Keep the cloud's"]), "%s asks with two answers %s" % [kind, faces])
		var labels := question.find_children("*", "Label", true, false).map(func(made: Label) -> String: return made.text)
		_check("Unknown" in labels and "2.05" in labels, "each side shows what is known of it")
		if kind == "refused":
			_check(labels.any(func(text: String) -> bool: return "Kills went down" in text), "and a refusal says why")
		(buttons[0] as Button).pressed.emit()
		(buttons[1] as Button).pressed.emit()
		question.queue_free()
	_check(answers == [["conflict", false], ["conflict", true], ["refused", false], ["refused", true]],
			"the left keeps this device's and the right the cloud's (%s)" % [answers])
	return true
