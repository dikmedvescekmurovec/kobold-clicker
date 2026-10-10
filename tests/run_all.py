"""Runs the tests/test_*.gd suites headless, side by side, each in a user:// folder of its own, so no
suite can read or write the player's saves or another run's scratch files (Godot keeps user:// under
%APPDATA%, which is pointed at a temp folder per suite).

A suite fails on a non-zero exit, a SCRIPT ERROR or an engine ERROR in its output, a missing
"All ... tests passed" line, or running past --timeout: Godot exits 0 when a script a suite depends on
does not parse, a null load() only logs an ERROR, and a suite stuck on an await never exits. Before
anything runs, every `_test_*` function must be called somewhere with its result checked.

Usage: python tests/run_all.py [suite ...] [--only TEST] [--list] [--jobs N] [--timeout SECONDS]
  suite   a name or the start of one: `inventory` runs every tests/test_inventory*.gd
  --only  one `_test_*` function (one that takes no arguments) of the one suite named
  --list  the suites and their tests, and nothing run
Each suite's whole output is kept in <temp>/kobold_tests/<suite>.log. Set GODOT to use another executable.
"""
import argparse
import concurrent.futures
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

GODOT = os.environ.get("GODOT", r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = os.path.join(tempfile.gettempdir(), "kobold_tests")
# Errors that are not a failure: what a SceneTree script leaks as it quits, and a save refused on
# purpose (`main_scene._refuse_save` logs the refusal it is being tested for).
IGNORE = ("at exit", "were leaked", "Refusing to load the saved")
PASSED = re.compile(r"^All .* tests passed$", re.M)
DEFINED = re.compile(r"^func (_test_\w+)\(", re.M)
CALLED = re.compile(r"(?<!func )\b(_test_\w+)\(")


def suites(wanted: list[str]) -> list[str]:
    every = sorted(os.path.basename(p)[5:-3] for p in glob.glob(os.path.join(ROOT, "tests", "test_*.gd")))
    if not wanted:
        return every
    picked = [name for name in every if any(name == w or name.startswith(w + "_") for w in wanted)]
    missing = [w for w in wanted if not any(name == w or name.startswith(w + "_") for name in every)]
    if missing:
        sys.exit("no such suite: %s (there are: %s)" % (", ".join(missing), ", ".join(every)))
    return picked


def tests_of(name: str) -> list[str]:
    with open(os.path.join(ROOT, "tests", "test_%s.gd" % name), encoding="utf-8") as file:
        return DEFINED.findall(file.read())


def unchecked(name: str) -> list[str]:
    """Tests a suite defines and never runs, or runs without looking at what came back: either way a
    test that stopped on a script error would pass."""
    with open(os.path.join(ROOT, "tests", "test_%s.gd" % name), encoding="utf-8") as file:
        source = file.read()
    called = set()
    problems = []
    for line in source.splitlines():
        for test in CALLED.findall(line):
            called.add(test)
            # A test that hands back another's answer is checked where it is itself called.
            if "_check(" not in line and not line.strip().startswith("return "):
                problems.append("%s: %s is called without its result checked" % (name, test))
    return problems + ["%s: %s is never called" % (name, test) for test in DEFINED.findall(source) if test not in called]


def run(name: str, only: str, timeout: float) -> tuple[str, bool, float, list[str]]:
    home = tempfile.mkdtemp(prefix="kobold_%s_" % name)
    command = [GODOT, "--headless", "--path", ROOT, "-s", "res://tests/test_%s.gd" % name]
    if only:
        command += ["--", "--only=" + only]
    began = time.time()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            errors="replace", env=dict(os.environ, APPDATA=home, XDG_DATA_HOME=home))
    try:
        output = process.communicate(timeout=timeout)[0]
        timed_out = False
    except subprocess.TimeoutExpired:
        # The console executable is a wrapper round the real one: the whole tree, or Godot runs on.
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True)
        process.kill()
        output = process.communicate()[0]
        timed_out = True
    shutil.rmtree(home, ignore_errors=True)
    with open(os.path.join(LOGS, name + ".log"), "w", encoding="utf-8") as log:
        log.write(output)
    lines = output.splitlines()
    wrong = []
    for at, line in enumerate(lines):
        if line.startswith(("FAIL", "SCRIPT ERROR")) or (line.startswith("ERROR") and not any(skip in line for skip in IGNORE)):
            # An error's second line says where it was raised.
            wrong += [line] + [after for after in lines[at + 1:at + 2] if after.startswith("   at:")]
    if timed_out:
        wrong.append("still running after %d s: stopped" % timeout)
    elif process.returncode != 0:
        wrong.append("exit code %d" % process.returncode)
    if not timed_out and not PASSED.search(output):
        wrong.append("ended without its \"All ... tests passed\" line")
    return name, not wrong, time.time() - began, wrong


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("suite", nargs="*")
    parser.add_argument("--only", default="")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    parser.add_argument("--timeout", type=float, default=600)
    args = parser.parse_args()
    names = suites(args.suite)
    if args.list:
        for name in names:
            print("%s\n    %s" % (name, "\n    ".join(tests_of(name))))
        return
    if args.only and len(names) != 1:
        sys.exit("--only takes one suite")
    # A video tool's override (a 360x640 viewport) left behind by a killed run would lay every suite out wrong.
    if os.path.exists(os.path.join(ROOT, "override.cfg")):
        sys.exit("override.cfg is in the project folder (tools/reels.py or tools/clip_video.py is recording, or was killed): wait, or delete it")
    problems = [problem for name in names for problem in unchecked(name)]
    if problems:
        sys.exit("\n".join(problems))
    os.makedirs(LOGS, exist_ok=True)
    failed = []
    with concurrent.futures.ThreadPoolExecutor(max(1, min(args.jobs, len(names)))) as pool:
        for name, ok, seconds, wrong in pool.map(lambda name: run(name, args.only, args.timeout), names):
            print("%s %-22s %3.0f s" % ("ok  " if ok else "FAIL", name, seconds), flush=True)
            if not ok:
                failed.append(name)
                print("\n".join("    " + line for line in wrong[:60]))
                if len(wrong) > 60:
                    print("    ... and %d more lines" % (len(wrong) - 60))
                print("    the whole output: " + os.path.join(LOGS, name + ".log"))
    print("%d of %d suites passed" % (len(names) - len(failed), len(names)))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
