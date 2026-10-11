"""Parses GDScript files with Godot's own checker (`--check-only`), a third of a second a file and
side by side: a parse error, an unknown name or a type that does not fit, found without running a suite.

Usage: python tools/check.py [file.gd ...] [--all]
  no file  the scripts git says have changed or are new
  --all    every script under Scenes/ and tests/
  --hook   for .claude/settings.json's PostToolUse hook: reads the hook's JSON on stdin and, when the
           file just edited is a script of this project that does not parse, says so to the agent
Exits 1 if any file does not parse. Set GODOT to use another executable.
"""
import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
from pathlib import Path

GODOT = os.environ.get("GODOT", r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
ROOT = Path(__file__).resolve().parent.parent


def changed() -> list[Path]:
    out = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=ROOT,
            capture_output=True, text=True).stdout
    return [ROOT / line[3:].strip().strip('"') for line in out.splitlines()
            if line[3:].strip().strip('"').endswith(".gd")
            and not line.startswith(" D") and not line.startswith("D ")]


def check(file: Path) -> list[str]:
    run = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--check-only", "-s",
            "res://" + file.resolve().relative_to(ROOT).as_posix()], capture_output=True, text=True, errors="replace")
    lines = (run.stdout + run.stderr).splitlines()
    return [line for at, line in enumerate(lines)
            if line.startswith("SCRIPT ERROR") or (at and lines[at - 1].startswith("SCRIPT ERROR"))]


def hook() -> None:
    """Quiet unless the edit broke the script: then the errors go back to the agent as context."""
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return
    said = payload.get("tool_response")
    path = (said.get("filePath") if isinstance(said, dict) else None) or (payload.get("tool_input")
            or {}).get("file_path") or ""
    file = Path(path).resolve()
    if file.suffix != ".gd" or not file.exists() or ROOT not in file.parents:
        return
    errors = check(file)
    if errors:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext":
                "%s does not parse after that edit (python tools/check.py):\n%s"
                % (file.relative_to(ROOT).as_posix(), "\n".join(errors))}}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", nargs="*", type=Path)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--hook", action="store_true")
    args = parser.parse_args()
    if args.hook:
        hook()
        return
    files = [file.resolve() for file in args.file]
    if args.all:
        files = sorted(set(ROOT.glob("Scenes/**/*.gd")) | set(ROOT.glob("tests/*.gd")))
    elif not files:
        files = changed()
    bad = 0
    with concurrent.futures.ThreadPoolExecutor(os.cpu_count() or 4) as pool:
        for file, errors in zip(files, pool.map(check, files)):
            if errors:
                bad += 1
                print("%s\n%s" % (file.relative_to(ROOT).as_posix(), "\n".join("    " + line for line in errors)))
    print("%d of %d scripts parse" % (len(files) - bad, len(files)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
