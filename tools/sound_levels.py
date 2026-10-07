"""Cuts the game's sounds out of the user's picks (CUTS, LOOPS), then sets every sound the game plays
to its level in LEVELS, in place (plain Python and ffmpeg, no Godot).

The picks in `Sounds/Selected/` stay as they came: a cut is a window of one -- started at the sound
rather than at the silence before it (a coin heard 0.3 s after it lands reads as lag), several takes
in one file split apart -- written to `Sounds/Sfx/` with a short fade at each end, so it never starts
or stops on a click. A cut is rendered from its pick at its level in one encode (`make`), and again
whenever it is off it; a cut whose window changed has to be deleted to be cut again.

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

PICKS = ROOT / "Sounds/Selected"
SFX = "Sounds/Sfx"
## Seconds faded in at a cut's start and out at its end.
FADE_IN = 0.005
FADE_OUT = 0.03
LIMIT = f"alimiter=limit={10 ** (PEAK / 20):.4f}:level=disabled:latency=1"
## Renders a cut gets to reach its level before it is kept as near as it came.
TRIES = 8


def _takes(name: str, pick: str, windows: list[tuple[float, float]]) -> dict:
    """One cut a take, `name_1` on: the files that hold several of the same sound."""
    return {f"{SFX}/{name}_{i}.ogg": (pick, *w) for i, w in enumerate(windows, 1)}


## Out path -> (the pick, start s, end s[, a filter run before its level]). The windows are read off each
## pick's waveform: from just before its onset to where it has died away. `blunt critical` starts at its blow, past the whoosh in front of
## it -- the swing already has one, and the crit has to land with its number.
CUTS = {
    f"{SFX}/player_hit.ogg": ("player hit.mp3", 0.28, 0.95),
    f"{SFX}/blunt_hit.ogg": ("blunt hit.mp3", 0.07, 1.15),
    f"{SFX}/blunt_crit.ogg": ("blunt critical.mp3", 0.30, 1.10),
    f"{SFX}/slash_crit.ogg": ("slash critical.mp3", 0.05, 2.19),
    # Played over `slash_crit` (the user's pairing), so it starts on its hit, not on the swell before.
    f"{SFX}/general_crit.ogg": ("general crit.mp3", 0.07, 0.80),
    f"{SFX}/defeat.ogg": ("defeat.mp3", 0.06, 2.55),
    f"{SFX}/unique_drop.ogg": ("unique drop.mp3", 0.30, 4.10),
    f"{SFX}/cloth_drop.ogg": ("clothes drop.mp3", 0.13, 1.10),
    f"{SFX}/item_drop.ogg": ("Drop Large Item.wav", 0.16, 1.00),
    # Its ring and the little bounce after it, at 0.8 s.
    f"{SFX}/orb_drop.ogg": ("Drop, Complex Crystaline Item.wav", 0.27, 1.00),
    # Gated: the pick is a quiet clink over a steady hiss, which its level raised to 11 dB under it.
    f"{SFX}/jewel_drop.ogg": ("jewelry drop 2.mp3", 0.44, 1.94,
                              "agate=threshold=0.015:ratio=20:attack=0.5:release=80:range=0.001"),
    f"{SFX}/coin_drop.ogg": ("coin drop.mp3", 0.29, 0.72),
    f"{SFX}/level_up.ogg": ("level up.mp3", 0.05, 2.30),
    f"{SFX}/orb_applied.ogg": ("orb applied.ogg", 0.0, 0.33),
    # Played over `orb_applied` rather than instead of it (the user's pairing): its swell is over by
    # 1.5 s, and the rest of the pick is near silence.
    f"{SFX}/orb_applied_layer.ogg": ("orb_applied 2.mp3", 0.09, 1.50),
    f"{SFX}/equip.ogg": ("equip.mp3", 0.05, 0.53),
    # Its whole crumble, down to the last of the debris at 13.6 s.
    f"{SFX}/ice_wall_fall.ogg": ("ice wall fall.mp3", 0.01, 13.70),
    f"{SFX}/anvil_hit.ogg": ("anvil hit.mp3", 0.43, 1.00),
    f"{SFX}/anvil_break.ogg": ("anvil break.mp3", 0.05, 1.07),
    **_takes("weapon_drop", "weapon drop.mp3",
             [(0.52, 1.50), (2.84, 3.90), (5.49, 6.50), (7.62, 9.00), (9.97, 11.20)]),
    **_takes("base_drop", "base item drop.mp3", [(0.22, 1.40), (1.44, 2.90)]),
    # The first six, alike; the rest of the file is quieter or different.
    **_takes("orb_drop", "orb drop.mp3",
             [(1.19, 1.70), (3.36, 3.85), (5.50, 6.05), (7.53, 8.10), (9.75, 10.30), (11.95, 12.50)]),
    **_takes("xp", "xp collected.mp3", [(0.09, 0.50), (0.79, 1.25), (1.55, 2.00), (2.07, 2.55), (2.80, 3.14)]),
    **_takes("voice", "npc dialogue.mp3", [(0.06, 0.36), (0.75, 1.25), (1.69, 2.30), (2.69, 3.60), (3.90, 4.18)]),
}
## Out path -> (the pick, start s, end s) of a sound that loops: a whole number of its pulses (the hum's
## is 1.297 s, ten of them here), its first LOOP_FADE seconds crossfaded with the LOOP_FADE that follows
## the end -- the same point in a pulse -- so its end runs into its start without a seam. Godot loops it
## from its `.import` (`loop=true`).
LOOPS = {f"{SFX}/loot_beam.ogg": ("loot beam.mp3", 1.30, 14.27)}
LOOP_FADE = 0.5

MUSIC = -25.0
FOOTSTEP = -22.0
CLICK = -23.0
DROP = -14.0
LEVELS = {
    **{f"Sounds/Music/ogg/{name}.ogg": MUSIC
       for name in [*(f"Action {i}" for i in range(1, 6)), *(f"Ambient {i}" for i in range(1, 11))]},
    "Assets/Player/attack.mp3": -18.0,
    "Sounds/universfield-punch-03-352040.mp3": -16.0,
    "Sounds/universfield-character-fall-impact-352287.mp3": -16.0,
    "Sounds/UI/click1.ogg": CLICK,
    "Sounds/UI/click4.ogg": CLICK,
    "Sounds/UI/bookFlip2.ogg": CLICK,
    "Sounds/UI/handleCoins.ogg": -19.0,
    **{f"Sounds/Footsteps/footstep{i:02d}.ogg": FOOTSTEP for i in range(10)},
    f"{SFX}/player_hit.ogg": -16.0,
    f"{SFX}/blunt_hit.ogg": -16.0,
    f"{SFX}/blunt_crit.ogg": -14.0,
    f"{SFX}/slash_crit.ogg": -14.0,
    f"{SFX}/general_crit.ogg": -16.0,
    f"{SFX}/defeat.ogg": -17.0,
    f"{SFX}/unique_drop.ogg": -10.0,
    f"{SFX}/cloth_drop.ogg": DROP,
    # Under the other drops: heard every few kills (the user's, 2026-10-06).
    f"{SFX}/item_drop.ogg": -18.0,
    f"{SFX}/orb_drop.ogg": -18.0,
    f"{SFX}/jewel_drop.ogg": DROP,
    **{name: DROP for name in CUTS if "weapon_drop" in name or "base_drop" in name or "orb_drop_" in name},
    f"{SFX}/coin_drop.ogg": -25.0,
    **{name: -27.0 for name in CUTS if "/xp_" in name},
    f"{SFX}/level_up.ogg": -15.0,
    f"{SFX}/orb_applied.ogg": -17.0,
    f"{SFX}/orb_applied_layer.ogg": -18.0,
    f"{SFX}/equip.ogg": -19.0,
    f"{SFX}/ice_wall_fall.ogg": -13.0,
    f"{SFX}/anvil_hit.ogg": -16.0,
    f"{SFX}/anvil_break.ogg": -15.0,
    **{name: -21.0 for name in CUTS if "/voice_" in name},
    # A bed under the fight, one for every beam standing.
    f"{SFX}/loot_beam.ogg": -24.0,
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
    if "Music" in path.parts:
        return float(re.search(r"I:\s*(-?[\d.]+)", summary).group(1)), peak
    return max(float(m) for m in re.findall(r"M:\s*(-?[\d.]+)", log[:log.rindex("Summary:")])), peak


def encoding(path: Path) -> list[str]:
    """The ffmpeg arguments that write the file back as it came: codec, rate and bitrate."""
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=sample_rate,bit_rate", "-of", "csv=p=0", str(path)],
                           capture_output=True, text=True, check=True).stdout.strip().split(",")
    codec = "libmp3lame" if path.suffix == ".mp3" else "libvorbis"
    return ["-c:a", codec, "-ar", probe[0], "-b:a", probe[1]]


def render(name: str, gain: float, out: Path) -> None:
    """The cut `name` out of its pick into `out`, `gain` dB louder and through the limiter."""
    level = f"volume={gain:.2f}dB,{LIMIT}"
    if name in LOOPS:
        pick, start, end = LOOPS[name]
        # acrossfade(x, y) is x's end faded into y's start: x is what follows the end, y the loop itself.
        args = ["-filter_complex", f"[0]asplit[a][b];[a]atrim={end}:{end + LOOP_FADE},asetpts=PTS-STARTPTS[x];"
                f"[b]atrim={start}:{end},asetpts=PTS-STARTPTS[y];[x][y]acrossfade=d={LOOP_FADE}:c1=tri:c2=tri,{level}"]
    else:
        pick, start, end, *clean = CUTS[name]
        args = ["-af", ",".join([f"atrim={start}:{end},asetpts=PTS-STARTPTS", *clean, f"afade=t=in:d={FADE_IN}",
                                 f"afade=t=out:st={end - start - FADE_OUT}:d={FADE_OUT}", level])]
    _ffmpeg("-y", "-i", str(PICKS / pick), "-map_metadata", "-1", *args, "-c:a", "libvorbis", "-q:a", "8", str(out))


def make(name: str) -> str:
    """Renders a cut at its level, always from its pick, each try's gain the last one's plus however far
    that one measured from the level -- so a spiky sound (a clink) gets there by having its spike shaved
    by the limiter, where raising the file in place stopped at its peak -- with one encode between the
    pick and the file."""
    path = ROOT / name
    out = path.with_name(path.stem + ".tmp" + path.suffix)
    gain = off = 0.0
    for _ in range(TRIES):
        gain += off
        render(name, gain, out)
        off = LEVELS[name] - measure(out)[0]
        if abs(off) < TOLERANCE / 2:
            break
    try:
        out.replace(path)
    except PermissionError:
        out.unlink()
        return f"{name}: open in another program (a player, the game), skipped"
    return f"{name}: rendered {gain:+.1f} dB from its pick, {LEVELS[name] - off:.1f}"


def main() -> None:
    (ROOT / SFX).mkdir(exist_ok=True)
    for name in {**CUTS, **LOOPS}:
        path = ROOT / name
        if path.exists():
            loudness, peak = measure(path)
            if abs(LEVELS[name] - loudness) < TOLERANCE and peak <= 0:
                print(f"{name}: {loudness:.1f}, left alone")
                continue
        print(make(name))
    for name, level in LEVELS.items():
        if name in CUTS or name in LOOPS:
            continue
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
            chain += f",{LIMIT}"
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
