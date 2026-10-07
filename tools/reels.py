"""Records the upright reels (tests/reels.gd) with Godot's Movie Maker and cuts each to build/reels/<n>_<name>.mp4.

    python tools/reels.py                  # record and encode all ten
    python tools/reels.py click loot       # only these
    python tools/reels.py --encode click   # encode the last recording again (a mix change needs no re-record)

Needs Godot 4.7.2 and ffmpeg. Each reel is recorded at 360x640 (ui_scale 1, the narrow layout), blown up 3x
with nearest neighbour to 1080x1920. Under it: one of the game's own Action tracks, started so a hit of the
track (found by ear-less onset search, `MUSIC`) lands on the reel's punch (`REEL_HIT`), and the fight's own
sounds recorded with it.
"""
import json, os, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
FRAMES = Path(tempfile.gettempdir()) / "reel_frames"
OUT = ROOT / "build" / "reels"
OVERRIDE = ROOT / "override.cfg"
TRACK = str(ROOT / "Sounds" / "Music" / "ogg" / "Action {}.ogg")
FPS = 60
# The order they are numbered in, each with its track and the second of a section hit in it (where the
# energy jumps after a quieter stretch) that the reel's punch lands on.
REELS = {
    "click": (1, 48.01), "loot": (2, 55.31), "boss": (5, 24.94), "explore": (3, 24.02),
    "craft": (4, 11.55), "skills": (1, 54.01), "wall": (2, 67.30), "descent": (5, 91.38),
    "transcend": (3, 38.01), "camp": (4, 22.21),
}
MUSIC_VOLUME = 0.8
SFX_VOLUME = 0.7
FADE = 0.6  # seconds the end fades to black under the music


def record(name: str) -> dict:
    frames = FRAMES / name
    frames.mkdir(parents=True, exist_ok=True)
    for old in frames.iterdir():
        old.unlink()
    # Movie Maker records at the project's viewport size, not the window's, and takes no flag for it: an
    # override.cfg beside project.godot sets it for this run only.
    OVERRIDE.write_text("[display]\n\nwindow/size/viewport_width=360\nwindow/size/viewport_height=640\n")
    try:
        run = subprocess.run([GODOT, "--path", str(ROOT), "--resolution", "360x640",
                              "--write-movie", str(frames / "f.png"), "--fixed-fps", str(FPS),
                              "-s", "res://tests/reels.gd", "--", f"--reel={name}"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace")
    finally:
        OVERRIDE.unlink()
    out = run.stdout + run.stderr
    if "SCRIPT ERROR" in out or "REEL_END" not in out:
        print(out[-4000:])
        sys.exit(f"reels.gd failed on {name}")
    marks = {key: float(re.search(rf"{key} (-?[\d.]+)", out).group(1)) for key in ("REEL_START", "REEL_END", "REEL_HIT")}
    (frames / "marks.txt").write_text(json.dumps(marks))
    return marks


def encode(name: str, marks: dict) -> None:
    frames = FRAMES / name
    start, end, hit = int(marks["REEL_START"]), int(marks["REEL_END"]), marks["REEL_HIT"]
    length = (end - start) / FPS
    track, track_hit = REELS[name]
    music_from = max(0.0, track_hit - max(hit, 0.0))
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{list(REELS).index(name) + 1:02d}_{name}.mp4"
    graph = (
        f"[0:v]scale=iw*3:ih*3:flags=neighbor,fade=t=out:st={length - FADE}:d={FADE}[v];"
        f"[1:a]volume={SFX_VOLUME}[sfx];"
        f"[2:a]volume={MUSIC_VOLUME},afade=t=in:d=0.05,afade=t=out:st={length - FADE}:d={FADE}[music];"
        # Every reel brought to the -14 LUFS a phone feed plays at, so a quiet one is not lost between loud ones.
        "[music][sfx]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]"
    )
    subprocess.run([
        "ffmpeg", "-y", "-v", "error",
        "-framerate", str(FPS), "-start_number", str(start), "-i", str(frames / "f%08d.png"),
        "-ss", str(start / FPS), "-i", str(frames / "f.wav"),
        "-ss", str(music_from), "-i", TRACK.format(track),
        "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-t", str(length),
        "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(out),
    ], check=True)
    print(f"Wrote {out} ({length:.1f} s, music from {music_from:.2f} s)")


if __name__ == "__main__":
    os.chdir(ROOT)
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or list(REELS)
    for name in names:
        if "--encode" in sys.argv:
            encode(name, json.loads((FRAMES / name / "marks.txt").read_text()))
        else:
            encode(name, record(name))
