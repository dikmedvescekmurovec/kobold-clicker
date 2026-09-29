"""Sets every sound the game plays to its level in LEVELS, in place (plain Python and ffmpeg, no Godot).

No player in the game sets a volume (the SFX bus as a whole sits `Settings.SFX_DB` under the files),
so how loud each sound is beside the others is the files' own level, and this table is where it
is tuned. A music track is measured over its whole length (integrated LUFS); a sound effect by its
loudest 400 ms (EBU R128 momentary), because a 0.04 s click has no whole-length loudness worth the
name. A file within TOLERANCE of its level is left alone, so a second run changes nothing. A raise
that would push the peak past PEAK, or a file already over 0 dB, goes through a limiter. Run the
Godot import after it.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOLERANCE = 0.5
PEAK = -1.0

MUSIC = -20.0
FOOTSTEP = -22.0
CLICK = -23.0
LEVELS = {
    **{f"Sounds/Music/{name}.mp3": MUSIC for name in ("idle", "idle2", "battle", "battle2")},
    "Assets/Player/attack.mp3": -18.0,
    "Sounds/universfield-punch-03-352040.mp3": -16.0,
    "Sounds/universfield-character-fall-impact-352287.mp3": -16.0,
    "Sounds/UI/click1.ogg": CLICK,
    "Sounds/UI/click4.ogg": CLICK,
    "Sounds/UI/bookFlip2.ogg": CLICK,
    "Sounds/UI/handleCoins.ogg": -19.0,
    **{f"Sounds/Footsteps/footstep{i:02d}.ogg": FOOTSTEP for i in range(10)},
}


def _ffmpeg(*args: str) -> str:
    run = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", *args], capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit(run.stderr)
    return run.stderr


def measure(path: Path) -> tuple[float, float]:
    """The file's loudness as LEVELS means it, and its true peak in dBTP."""
    log = _ffmpeg("-loglevel", "verbose", "-i", str(path),
                  "-af", "apad=pad_dur=0.5,ebur128=peak=true", "-f", "null", "-")
    summary = log[log.rindex("Summary:"):]
    peak = float(re.search(r"Peak:\s*(-?[\d.]+|-inf)", summary).group(1))
    if path.parent.name == "Music":
        return float(re.search(r"I:\s*(-?[\d.]+)", summary).group(1)), peak
    return max(float(m) for m in re.findall(r"M:\s*(-?[\d.]+)", log[:log.rindex("Summary:")])), peak


def encoding(path: Path) -> list[str]:
    """The ffmpeg arguments that write the file back as it came: codec, rate and bitrate."""
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=sample_rate,bit_rate", "-of", "csv=p=0", str(path)],
                           capture_output=True, text=True, check=True).stdout.strip().split(",")
    codec = "libmp3lame" if path.suffix == ".mp3" else "libvorbis"
    return ["-c:a", codec, "-ar", probe[0], "-b:a", probe[1]]


def main() -> None:
    for name, level in LEVELS.items():
        path = ROOT / name
        loudness, peak = measure(path)
        gain = level - loudness
        if abs(gain) < TOLERANCE and peak <= 0:
            print(f"{name}: {loudness:.1f}, left alone")
            continue
        # A spike already at the ceiling: raising it again only re-encodes it for a limiter to undo.
        if gain > 0 and PEAK - TOLERANCE < peak <= 0:
            print(f"{name}: {loudness:.1f}, as loud as its peak allows")
            continue
        chain = f"volume={gain:.2f}dB"
        if peak + gain > PEAK:
            chain += f",alimiter=limit={10 ** (PEAK / 20):.4f}:level=disabled:latency=1"
        out = path.with_name(path.stem + ".tmp" + path.suffix)
        _ffmpeg("-y", "-i", str(path), "-map_metadata", "-1", "-af", chain, *encoding(path), str(out))
        try:
            out.replace(path)
        except PermissionError:
            out.unlink()
            print(f"{name}: open in another program (a player, the game), skipped")
            continue
        print(f"{name}: {loudness:.1f} -> {measure(path)[0]:.1f} ({gain:+.1f} dB)")


if __name__ == "__main__":
    main()
