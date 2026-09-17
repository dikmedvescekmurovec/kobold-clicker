"""Runs every tests/test_*.gd suite headless. A suite fails on a non-zero exit or on any SCRIPT ERROR
in its output -- Godot exits 0 when a script a suite depends on fails to parse, so the exit code
alone is not enough. Usage: python tests/run_all.py [suite ...], e.g. `python tests/run_all.py combat`.
Set GODOT to use another executable."""
import glob
import os
import subprocess
import sys

GODOT = os.environ.get("GODOT", r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Noise that is not a failure: duplicated asset folders, and what a SceneTree script leaks on quit.
IGNORE = ("UID duplicate", "ObjectDB instances were leaked", "resources still in use", "at: cleanup", "at: clear")

names = sys.argv[1:] or sorted(os.path.basename(p)[5:-3] for p in glob.glob(os.path.join(ROOT, "tests", "test_*.gd")))
failed = []
for name in names:
    run = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tests/test_%s.gd" % name],
            capture_output=True, text=True, errors="replace")
    output = run.stdout + run.stderr
    ok = run.returncode == 0 and "SCRIPT ERROR" not in output
    print("%s %s" % ("ok  " if ok else "FAIL", name))
    if not ok:
        failed.append(name)
        lines = [l for l in output.splitlines() if l.strip() and not any(skip in l for skip in IGNORE)]
        print("\n".join("    " + l for l in lines[-25:]))
print("%d of %d suites passed" % (len(names) - len(failed), len(names)))
sys.exit(1 if failed else 0)
