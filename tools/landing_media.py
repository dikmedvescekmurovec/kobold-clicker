"""Cuts the landing page's pictures (Scenes/landing.gd) out of what the recorders left: five silent shorts
(four reels and the craft clip) and four stills. It encodes and crops only, and never records.

    python tools/landing_media.py            # build/landing/, for a look, and each file's size
    python tools/landing_media.py --export   # then copies them into Assets/Landing/ (run the Godot import after)

Needs ffmpeg and Pillow, and the sources as they were last recorded: the reels click, loot, wall, descent,
explore and camp (`tools/reels.py`), the clips craft and tree (`tools/clip_video.py`) and
`tests/screenshot_ui.gd` at `--resolution 360x780` (COMMANDS.md). A reel's or a clip's scenario is the user's:
this cuts from the recording there is, and nothing here is a reason to record one again (tools/CLAUDE.md).
"""
import argparse, json, os, shutil, subprocess, sys
from pathlib import Path

from PIL import Image

from recording import ROOT, ready
from reels import FPS, FRAMES

OUT = ROOT / "build" / "landing"
ASSETS = ROOT / "Assets" / "Landing"
SHOTS = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Incremendal Side Scroller"
# Every picture is this wide, the recordings' own pixels: the page blows them up by a whole number.
WIDTH = 360
# A reel's short is its 640 rows less two at either end: 636 divides by 2, 3, 4 and 6, 640 by no 3.
SHORT_TOP, SHORT_HEIGHT = 2, 636
# The dials of a short's size on disk (about 1 MB each is the budget): frames a second and Theora's quality.
# At 7 the first four came to 7.4 MB and looked no better at the page's size (2026-10-11).
SHORT_FPS = 15
QUALITY = 4
FADE = 0.5  # seconds the end fades to black, since the page plays it round again
REELS = ["click", "loot", "wall", "descent"]
# The clips shown as shorts: the window's full width over the rows the clip shows (`cuts.txt`'s frame). A
# clip's close-up is the encoder's, so its short has none. `Scenes/landing.gd` is told a clip's rows.
CLIPS = ["craft"]
# name -> (the picture, its first row kept, how many rows). A reel's frame is (reel, seconds into it). Every
# height divides by 12, as a short's does, so the page's whole zooms land on whole pixels.
STILLS = {
    "tree": (ROOT / "build" / "tree_video" / "frames" / "frame00000700.png", 226, 408),
    "map": (("explore", 7.4), SHORT_TOP, SHORT_HEIGHT),
    "camp": (("camp", 5.0), SHORT_TOP, SHORT_HEIGHT),
    "transcend": (SHOTS / "ui_transcend_choice.png", 168, 444),
}


def marks(reel: str) -> dict:
    return json.loads((FRAMES / reel / "marks.txt").read_text())


def cuts(clip: str) -> Path:
    return ROOT / "build" / f"{clip}_video" / "cuts.txt"


def source(picture) -> Path:
    if isinstance(picture, Path):
        return picture
    reel, second = picture
    return FRAMES / reel / f"f{int(marks(reel)['REEL_START']) + round(second * FPS):08d}.png"


def short(name: str, frames: Path, start: int, end: int, top: int, height: int) -> Path:
    """Frames `start` to `end` of `frames` (a printf pattern), rows `top` on, as build/landing/<name>.ogv."""
    length = (end - start) / FPS
    out = OUT / f"{name}.ogv"
    subprocess.run([
        "ffmpeg", "-y", "-v", "error",
        "-framerate", str(FPS), "-start_number", str(start), "-t", str(length), "-i", str(frames),
        "-vf", f"fps={SHORT_FPS},crop={WIDTH}:{height}:0:{top},fade=t=out:st={length - FADE}:d={FADE}",
        "-pix_fmt", "yuv420p", "-c:v", "libtheora", "-q:v", str(QUALITY), "-an", str(out),
    ], check=True)
    return out


def reel_short(name: str) -> Path:
    start, end = int(marks(name)["REEL_START"]), int(marks(name)["REEL_END"])
    return short(name, FRAMES / name / "f%08d.png", start, end, SHORT_TOP, SHORT_HEIGHT)


def clip_short(name: str) -> Path:
    # cuts.txt: start, end, then the frame the clip shows as x, y, width, height (tools/clip_video.py).
    start, end, _x, top, _width, height = (int(n) for n in cuts(name).read_text().split()[:6])
    out = short(name, cuts(name).parent / "frames" / "frame%08d.png", start, end, top, height)
    print(f"{name}: {height} rows, which Scenes/landing.gd's FEATURES row must say")
    return out


def still(name: str) -> Path:
    picture, top, height = STILLS[name]
    out = OUT / f"{name}.png"
    Image.open(source(picture)).convert("RGB").crop((0, top, WIDTH, top + height)).save(out)
    return out


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--export", action="store_true", help="copy the pictures into Assets/Landing/ as well")
    args = parser.parse_args()
    os.chdir(ROOT)
    # Everything asked for before the first encode: the reels' marks and the clips' cuts, then the frames
    # the stills point at.
    reels = REELS + [picture[0] for picture, _top, _height in STILLS.values() if not isinstance(picture, Path)]
    ready(*[FRAMES / reel / "marks.txt" for reel in reels], *[cuts(clip) for clip in CLIPS], record=False)
    ready(*[source(picture) for picture, _top, _height in STILLS.values()], record=False)
    for name, (picture, top, height) in STILLS.items():
        size = Image.open(source(picture)).size
        if size[0] != WIDTH or top + height > size[1]:
            sys.exit(f"{name}: {source(picture)} is {size[0]}x{size[1]}, not {WIDTH} wide and {top + height} tall")
    OUT.mkdir(parents=True, exist_ok=True)
    made = [reel_short(name) for name in REELS] + [clip_short(name) for name in CLIPS] \
        + [still(name) for name in STILLS]
    for path in made:
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size / 1024:.0f} KB")
    print(f"{sum(path.stat().st_size for path in made) / 1024 / 1024:.1f} MB in all")
    # Assets/ last, once nothing can refuse a picture.
    if args.export:
        for path in made:
            shutil.copyfile(path, ASSETS / path.name)
        print(f"Copied to {ASSETS.relative_to(ROOT)}: run the Godot import for their .import and .uid files")
