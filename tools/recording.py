"""What the Movie Maker recorders (trailer.py, reels.py, clip_video.py) share: the Godot executable, the
check that everything a recording needs is there before minutes are spent on it, and the override.cfg
a recording at another viewport size has to leave beside project.godot while it runs.

Not a tool of its own: `python tools/recording.py` runs its self-check in a temporary folder.
"""
import contextlib
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT", r"C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
OVERRIDE = ROOT / "override.cfg"
STALE = ("%s is already there: another recording is running, or a killed one left it behind. "
         "Wait for it, or delete the file.")


def ready(*inputs, record: bool = True) -> None:
    """Exits, naming everything that is missing, unless ffmpeg and each of `inputs` (the music, a clip's
    script, the last recording's files) are there -- and, to record, the Godot executable and no
    override.cfg, under which Godot would lay the film out at somebody else's viewport size."""
    missing = [] if shutil.which("ffmpeg") else ["ffmpeg is not on the PATH"]
    if record and not shutil.which(GODOT):
        missing.append(f"the Godot executable, {GODOT} (set GODOT to use another)")
    if record and OVERRIDE.exists():
        missing.append(STALE % OVERRIDE)
    missing += [f"{path} does not exist" for path in inputs if not Path(path).exists()]
    if missing:
        sys.exit("Nothing was recorded or encoded:\n  " + "\n  ".join(missing))


@contextlib.contextmanager
def viewport(width: int, height: int, path: Path = OVERRIDE):
    """An override.cfg beside project.godot for as long as the block runs: Movie Maker records at the
    project's viewport size, not the window's, and takes no flag for it. Every other Godot run in that
    time lays out at this size too (tests/run_all.py refuses to start while the file is there), so the
    file is made only if there is none -- it is never somebody else's that gets overwritten or deleted --
    and it is taken away however the block ends, Ctrl+C included. A killed process cannot tidy up:
    that file is the one the next run refuses to start over."""
    try:
        with open(path, "x") as file:
            file.write(f"[display]\n\nwindow/size/viewport_width={width}\nwindow/size/viewport_height={height}\n")
    except FileExistsError:
        sys.exit(STALE % path)
    try:
        yield
    finally:
        path.unlink(missing_ok=True)


if __name__ == "__main__":
    import argparse
    import tempfile
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    scratch = Path(tempfile.mkdtemp()) / "override.cfg"
    try:
        with viewport(360, 640, scratch):
            assert "viewport_width=360" in scratch.read_text()
            try:
                with viewport(1, 1, scratch):
                    raise AssertionError("a second override was written over the first")
            except SystemExit:
                assert "viewport_width=360" in scratch.read_text(), "the refusal touched the file"
            raise KeyboardInterrupt
    except KeyboardInterrupt:
        assert not scratch.exists(), "an interrupted recording left its override behind"
    scratch.parent.rmdir()
    print("recording.py: ok")
