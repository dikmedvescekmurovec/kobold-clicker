"""Records the hype trailer (tests/trailer.gd) with Godot's Movie Maker and cuts it to build/trailer.mp4.

    python tools/trailer.py            # record, then encode
    python tools/trailer.py --encode   # encode the last recording again (a mix change needs no re-record)

Needs Godot 4.7.2 and ffmpeg. The film is recorded at the game's 1152x648, blown up 3x with nearest
neighbour so the pixels stay square, then brought down to 1080p. Under it: Sounds/Music/battle.mp3 from
its first beat, which is the beat trailer.gd counts from, and the fight's own sounds recorded with it.
"""
import os, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
FRAMES = Path(tempfile.gettempdir()) / "trailer_frames"
OUT = ROOT / "build" / "trailer.mp4"
MUSIC = ROOT / "Sounds" / "Music" / "battle.mp3"
FPS = 60
# Where battle.mp3's first beat falls, and the trailer's length in its beats (trailer.gd's END_BEAT).
FIRST_BEAT = 0.525
BEAT = 60 / 80
END_BEAT = 68
TAIL = 1.0  # seconds of black after the last beat, under the music's fade
MUSIC_VOLUME = 0.9
SFX_VOLUME = 0.55


def record() -> int:
    FRAMES.mkdir(exist_ok=True)
    for old in FRAMES.iterdir():
        old.unlink()
    run = subprocess.run([GODOT, "--path", str(ROOT), "--write-movie", str(FRAMES / "t.png"),
                          "--fixed-fps", str(FPS), "-s", "res://tests/trailer.gd"],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(run.stdout[-3000:], run.stderr[-3000:], sep="\n")
    if "SCRIPT ERROR" in run.stdout + run.stderr:
        sys.exit("trailer.gd failed")
    start = int(re.search(r"TRAILER_START (\d+)", run.stdout).group(1))
    (FRAMES / "start.txt").write_text(str(start))
    return start


def encode(start: int) -> None:
    length = END_BEAT * BEAT + TAIL
    fade_at = (END_BEAT - 4) * BEAT
    OUT.parent.mkdir(exist_ok=True)
    graph = (
        "[0:v]scale=iw*3:ih*3:flags=neighbor,scale=1920:1080:flags=lanczos,"
        f"tpad=stop_mode=add:stop_duration={TAIL}:color=black[v];"
        f"[1:a]volume={SFX_VOLUME}[sfx];"
        f"[2:a]volume={MUSIC_VOLUME},afade=t=out:st={fade_at}:d={length - fade_at}[music];"
        "[music][sfx]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]"
    )
    subprocess.run([
        "ffmpeg", "-y", "-v", "error",
        "-framerate", str(FPS), "-start_number", str(start), "-i", str(FRAMES / "t%08d.png"),
        "-ss", str(start / FPS), "-i", str(FRAMES / "t.wav"),
        "-ss", str(FIRST_BEAT), "-i", str(MUSIC),
        "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-t", str(length),
        "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(OUT),
    ], check=True)
    print("Wrote", OUT)


if __name__ == "__main__":
    os.chdir(ROOT)
    encode(int((FRAMES / "start.txt").read_text()) if "--encode" in sys.argv else record())
