extends SceneTree
## Base for everything in tests/: the deferred start every script needs, plus the failure count and
## the pass/fail tail the assertion suites need. A script extends this and overrides _run; a suite
## also checks with _check and finishes with _report("its name"). The screenshot scripts use only the
## start and the shared seed.
##
## Each _test_* function returns true, and _run checks that it did, because a script error aborts the
## function and makes it return null instead — which would otherwise pass silently.

## Seed the suites and the screenshot scripts generate their town world from.
const WORLD_SEED := 12345

var _failures := 0


func _initialize() -> void:
	# The root only enters the tree after _initialize, so nodes added here would not get _ready yet.
	_run.call_deferred()


## Overridden by each suite.
func _run() -> void:
	pass


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


## Prints the verdict and quits non-zero if anything failed. `label` names the suite, e.g. "hex map".
func _report(label: String) -> void:
	if _failures == 0:
		print("All %s tests passed" % label)
	else:
		printerr("%d %s check(s) failed" % [_failures, label])
	quit(1 if _failures else 0)
