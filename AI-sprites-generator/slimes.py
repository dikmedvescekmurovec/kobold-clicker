"""Per-environment slime variants, recoloured from the shipped blue slime pack.

The pack under Assets/Enemies/Slime is the baseline: 21 frames of 32x25 drawn in exactly eight
colours, a five-step body ramp plus a three-step red eye. Every environment slime is that art with
the body ramp swapped for one built from hexlib.PALETTE, so a slime looks like it grew out of the
terrain it belongs to.

The swap is pixel for pixel and nothing else is drawn: the silhouette, the shading and the animation
timing are the baseline's, which is what qa.py checks. The eye stays red in every environment -- it
is what makes all six read as one creature.
"""
import os

from PIL import Image

from hexlib import PALETTE

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "Assets", "Enemies", "Slime", "Individual Sprites")

## The pack's animations and how many frames each has, in the order a fight uses them.
ANIMATIONS = [("idle", 4), ("move", 4), ("attack", 5), ("hurt", 4), ("die", 4)]

## The baseline's eight colours. BODY runs darkest to lightest; EYE is the red the pack draws the
## eye and mouth with. Anything outside these two would be a colour family the swap misses, so
## _index refuses it rather than letting an unrecoloured pixel through.
BODY = [(35, 64, 117), (58, 91, 148), (88, 138, 224), (176, 203, 245), (210, 224, 247)]
EYE = [(171, 41, 63), (232, 70, 70), (245, 120, 120)]

_PAL = {n: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for n, h in PALETTE[1:]}

## Each environment's five-step body ramp, darkest first, from hexlib.PALETTE, so the slimes are
## coloured with the same entries as the ground they belong to. The baseline spends its largest mass
## on the *darkest* step, so every ramp starts at a middling dark and never at the palette's floor --
## start a ramp at ink and the creature reads as a black blob with a lit rim.
ENVS = {
    "grass":     ["pine", "leaf_dk", "leaf", "leaf_lt", "leaf_hi"],
    "dirt":      ["earth", "soil", "soil_lt", "sand_dk", "sand_lt"],
    "desert":    ["soil_lt", "sand_dk", "sand", "sand_lt", "bone"],
    "ice":       ["abyss", "ice_dk", "ice", "ice_lt", "snow"],
    "forest":    ["pine_dk", "pine", "leaf_dk", "leaf", "leaf_lt"],
    "mountains": ["slate_dk", "slate", "stone", "stone_lt", "mist"],
}

## The eye, in the palette's reds. The lighter steps of the palette skew orange, so the lit pixel is
## rust -- the same substitution the UI kit's danger buttons make.
EYE_RAMP = ["brick_dk", "brick", "rust"]

_BODY_AT = {c: i for i, c in enumerate(BODY)}
_EYE_AT = {c: i for i, c in enumerate(EYE)}


def frame_names():
    """Every frame of the pack, as ("slime-idle-0", ...) in animation order."""
    return [f"slime-{a}-{i}" for a, n in ANIMATIONS for i in range(n)]


def source(name):
    """One baseline frame as an RGBA image."""
    return Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")


def _index(px):
    """Which ramp step a source pixel is: ("body", 0..4), ("eye", 0..2) or None for transparent."""
    if px[3] == 0:
        return None
    rgb = px[:3]
    if rgb in _BODY_AT:
        return ("body", _BODY_AT[rgb])
    if rgb in _EYE_AT:
        return ("eye", _EYE_AT[rgb])
    raise AssertionError(f"colour {rgb} is not one of the baseline's eight")


def recolour(img, env):
    """The baseline frame with its body ramp swapped for the environment's."""
    ramp = [_PAL[n] for n in ENVS[env]]
    eye = [_PAL[n] for n in EYE_RAMP]
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            at = _index(src[x, y])
            if at:
                dst[x, y] = (ramp if at[0] == "body" else eye)[at[1]] + (255,)
    return out


def variants():
    """Every generated frame: (env, frame name, image), in a stable order."""
    for env in ENVS:
        for name in frame_names():
            yield env, name, recolour(source(name), env)
