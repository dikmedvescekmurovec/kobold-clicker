"""Exports the web build (export_presets.cfg's "Web") to build/web/ and puts it live at
https://play.kobold-clicker.workers.dev: every file into the R2 bucket, then the Worker that
serves them (backend/web/).

    python tools/web.py               # export, upload, deploy
    python tools/web.py --no-upload   # export only

Needs Godot 4.7.2 with its web export templates, and wrangler signed in (backend/leaderboard/'s, so
`npm install` there first). Set GODOT to use another executable.
"""
import os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT", r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
OUT = ROOT / "build" / "web"
BUCKET = "kobold-clicker-web"
WRANGLER_DIR = ROOT / "backend" / "leaderboard"
TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript", ".wasm": "application/wasm",
         ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml", ".json": "application/json"}


def wrangler(*args: str) -> None:
    subprocess.run([shutil.which("npx"), "wrangler", *args], cwd=WRANGLER_DIR, check=True)


def export() -> None:
    # The export's own PNGs would otherwise be imported into the next one.
    (ROOT / "build" / ".gdignore").touch()
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    run = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--export-release", "Web", str(OUT / "index.html")],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = run.stdout + run.stderr
    if run.returncode != 0 or "ERROR" in out or not (OUT / "index.pck").exists():
        print(out[-4000:])
        sys.exit("export failed")
    for file in sorted(OUT.iterdir()):
        print(f"{file.name:32} {file.stat().st_size / 1e6:8.1f} MB")


def upload() -> None:
    # index.html last, so a page loaded mid-upload still finds the files it names.
    for file in sorted(OUT.iterdir(), key=lambda f: f.suffix == ".html"):
        wrangler("r2", "object", "put", f"{BUCKET}/{file.name}", "--file", str(file),
                 "--content-type", TYPES.get(file.suffix, "application/octet-stream"), "--remote")
    wrangler("deploy", "--config", "../web/wrangler.toml")


if __name__ == "__main__":
    export()
    if "--no-upload" not in sys.argv:
        upload()
