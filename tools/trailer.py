"""Records the hype trailer (tests/trailer.gd) with Godot's Movie Maker and cuts it to build/trailer.mp4.

    python tools/trailer.py            # record, then encode
    python tools/trailer.py --encode   # encode the last recording again (a mix change needs no re-record)
    python tools/trailer.py --opening  # only the words and the shatter, to build/trailer_opening.mp4

Needs Godot 4.7.2 and ffmpeg. The film is recorded at the game's 1152x648, blown up 3x with nearest
neighbour so the pixels stay square, then brought down to 1080p. Under it: Sounds/Music/battle.mp3 from
the beat trailer.gd counts from, and the fight's own sounds recorded with it.
"""
import os, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
FRAMES = Path(tempfile.gettempdir()) / "trailer_frames"
OUT = ROOT / "build" / "trailer.mp4"
MUSIC = ROOT / "Sounds" / "Music" / "battle.mp3"
FPS = 60
# Where in battle.mp3 the trailer's beat 0 falls: a beat, four in, so the track's big hits land on
# beats 6, 14, 22... And the trailer's length in its beats (trailer.gd's END_BEAT).
FIRST_BEAT = 3.525
BEAT = 60 / 80
END_BEAT = 80
TAIL = 1.0  # seconds of black after the last beat, under the music's fade
MUSIC_VOLUME = 0.9
SFX_VOLUME = 0.55
# Where --opening stops: a couple of beats past the shatter.
OPENING_END = 10


def record(until: float = 0) -> int:
    FRAMES.mkdir(exist_ok=True)
    for old in FRAMES.iterdir():
        old.unlink()
    run = subprocess.run([GODOT, "--path", str(ROOT), "--write-movie", str(FRAMES / "t.png"),
                          "--fixed-fps", str(FPS), "-s", "res://tests/trailer.gd"]
                         + (["--", f"--until={until}"] if until else []),
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(run.stdout[-3000:], run.stderr[-3000:], sep="\n")
    if "SCRIPT ERROR" in run.stdout + run.stderr:
        sys.exit("trailer.gd failed")
    start = int(re.search(r"TRAILER_START (\d+)", run.stdout).group(1))
    (FRAMES / "start.txt").write_text(str(start))
    return start


def encode(start: int, end_beat: float = END_BEAT, out: Path = OUT, fade_beats: float = 4) -> None:
    length = end_beat * BEAT + TAIL
    fade_at = (end_beat - fade_beats) * BEAT
    out.parent.mkdir(exist_ok=True)
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
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(out),
    ], check=True)
    print("Wrote", out)


if __name__ == "__main__":
    os.chdir(ROOT)
    if "--opening" in sys.argv:
        encode(record(OPENING_END), OPENING_END, OUT.with_name("trailer_opening.mp4"), fade_beats=1)
    else:
        encode(int((FRAMES / "start.txt").read_text()) if "--encode" in sys.argv else record())
