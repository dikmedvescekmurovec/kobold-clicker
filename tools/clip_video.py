"""Records an upright marketing clip, tests/<name>_video.gd, with Movie Maker and encodes
build/<name>_video.mp4: 1080x1920 at 60 fps, the 270x480 the clip shows of the 360x640 game blown up 4x
(nearest), and from its close-up on, if it has one, that 180x320 blown up 6x.

    python tools/clip_video.py craft            record, then encode
    python tools/clip_video.py loot --encode    encode the last recording again

The clips: craft (a Masterwork Greatsword exalted until its lines come up right, then divined three times
to an amazing roll), loot (a farm run clicked through to a unique) , travel (one-click kills cut
between grounds and skies) and tree (a skill node crafted and placed on a transcension's tree).

Opens a window for a minute or so and moves the mouse: leave the mouse and keyboard alone while it runs.
Plain Python and ffmpeg beside the Godot 4.7.2 console build.
"""
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = pathlib.Path.home() / "Godot_v4.7.2-stable_win64.exe" / "Godot_v4.7.2-stable_win64_console.exe"
WIDTH, HEIGHT, FPS = 360, 640, 60
OUTPUT = (1080, 1920)
# Movie Maker records at the project's viewport size, not the window's, so the run gets its own.
OVERRIDE = f"[display]\nwindow/size/viewport_width={WIDTH}\nwindow/size/viewport_height={HEIGHT}\n"


def record(name: str, frames: pathlib.Path, cuts: pathlib.Path) -> None:
    shutil.rmtree(frames, ignore_errors=True)
    frames.mkdir(parents=True)
    override = ROOT / "override.cfg"
    override.write_text(OVERRIDE)
    try:
        run = subprocess.run([str(GODOT), "--path", str(ROOT), "--write-movie", str(frames / "frame.png"),
                              "-s", f"res://tests/{name}_video.gd"], capture_output=True, text=True)
    finally:
        override.unlink()
    print(run.stdout[-1500:])
    # A clip that falls back on a seed it could not find still runs to its end: say so.
    for line in run.stderr.splitlines():
        if "ERROR" in line and "UID duplicate" not in line:
            print(line)
    start = re.search(r"CLIP_START (\d+)", run.stdout)
    frame = re.search(r"FRAME (\d+) (\d+) (\d+) (\d+)", run.stdout)
    closeup = re.search(r"CLOSEUP (\d+) (\d+) (\d+) (\d+) (\d+)", run.stdout)
    end = re.search(r"CLIP_END (\d+)", run.stdout)
    if run.returncode or not (start and frame and end) or "SCRIPT ERROR" in run.stderr:
        sys.exit(run.stderr[-3000:] or "The recording never reached its end")
    # No close-up: one that starts at the end, and is never shown.
    cut = closeup.groups() if closeup else (end[1], *frame.groups())
    cuts.write_text(" ".join([start[1], end[1], *frame.groups(), *cut]))


def encode(name: str, frames: pathlib.Path, cuts: pathlib.Path) -> None:
    start, end, fx, fy, fw, fh, cut, x, y, w, h = (int(n) for n in cuts.read_text().split())
    size = f"{OUTPUT[0]}:{OUTPUT[1]}"
    wide = f"crop={fw}:{fh}:{fx}:{fy},scale={size}:flags=neighbor"
    if cut < end:
        graph = (f"[0:v]split[a][b];[a]trim=end_frame={cut - start},{wide}[wide];"
                 f"[b]trim=start_frame={cut - start},setpts=PTS-STARTPTS,crop={w}:{h}:{x}:{y},"
                 f"scale={size}:flags=neighbor[close];[wide][close]concat=n=2:v=1:a=0,format=yuv420p[v]")
    else:
        graph = f"[0:v]{wide},format=yuv420p[v]"
    length = (end - start) / FPS
    target = ROOT / "build" / f"{name}_video.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y",
                    "-framerate", str(FPS), "-start_number", str(start), "-i", str(frames / "frame%08d.png"),
                    "-ss", f"{start / FPS:.4f}", "-t", f"{length:.4f}", "-i", str(frames / "frame.wav"),
                    "-filter_complex", graph, "-map", "[v]", "-map", "1:a", "-frames:v", str(end - start),
                    "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-c:a", "aac", "-b:a", "192k",
                    "-af", f"afade=t=out:st={length - 0.5:.3f}:d=0.5",
                    "-movflags", "+faststart", str(target)], check=True)
    print("Wrote", target)


if __name__ == "__main__":
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    out = ROOT / "build" / f"{args[0]}_video"
    if "--encode" not in sys.argv:
        record(args[0], out / "frames", out / "cuts.txt")
    encode(args[0], out / "frames", out / "cuts.txt")
