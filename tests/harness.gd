extends SceneTree
## Base for everything in tests/: the deferred start every script needs, plus the failure count and
## the pass/fail tail the assertion suites need. A script extends this and overrides _run; a suite
## also checks with _check and finishes with _report("its name"). The screenshot scripts use only the
## start and the shared seed.
##
## Each _test_* function returns true, and _run checks that it did, because a script error aborts the
## function and makes it return null instead — which would otherwise pass silently. (`run_all.py`
## refuses a suite that calls one without checking it.) `-- --only=_test_name` after the script's path
## runs that one test instead of _run.

## Seed the suites and the screenshot scripts generate their town world from.
const WORLD_SEED := 12345
## The player's own files. Nothing under tests/ may write them: a suite that did fails as it reports.
const PLAYERS_FILES := ["user://inventory.json", "user://map.json", "user://settings.cfg", "user://cloud.cfg"]

var _failures := 0
var _reported := false
var _players_files := {}


func _initialize() -> void:
	for path: String in PLAYERS_FILES:
		_players_files[path] = _written_at(path)
	# The root only enters the tree after _initialize, so nodes added here would not get _ready yet.
	_begin.call_deferred()


func _begin() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	if only.is_empty():
		@warning_ignore("redundant_await")
		await _run()
	else:
		var takes := -1
		for method: Dictionary in (get_script() as Script).get_script_method_list():
			if method.name == only:
				takes = (method.args as Array).size()
		if takes != 0:
			_check(false, "%s %s" % [only, "is not a test of this suite" if takes < 0
					else "takes arguments, which only its suite's _run knows"])
		else:
			_check(await call(only) == true, "%s ran to the end" % only)
		_report(only)
	# A script error in a suite's _run itself stops it short of its _report, and it would never quit.
	# (The screenshot and video scripts report nothing and quit themselves.)
	var suite: bool = (get_script() as Script).resource_path.get_file().begins_with("test_")
	if suite and not _reported:
		printerr("FAIL: the script ended before its report")
		quit(1)


## Overridden by each suite.
func _run() -> void:
	pass


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


## Prints the verdict and quits non-zero if anything failed. `label` names the suite, e.g. "hex map".
func _report(label: String) -> void:
	_reported = true
	for path: String in PLAYERS_FILES:
		_check(_written_at(path) == _players_files[path], "%s, the player's own, is left alone" % path)
	if _failures == 0:
		print("All %s tests passed" % label)
	else:
		printerr("%d %s check(s) failed" % [_failures, label])
	quit(1 if _failures else 0)


func _written_at(path: String) -> int:
	return FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
