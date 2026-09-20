"""Flatten an AI-generated sprite down to a bought pack's look.

PixelLab renders a creature with a hundred-odd colours of blended ramp packed into one
value band; the enemy packs under Assets/Enemies use 14-22 colours a frame (Goblin 14,
Harpy 18, Minotaur 22) with the body, the weapon and the straps at clearly different
lightnesses. A generated sprite dropped in beside them reads as mud. Three passes fix it:

  1. one palette, median cut, across *every* frame given -- never per frame, or the
     creature shimmers as the animation plays;
  2. the palette's lightness stretched back out to the packs' range, hue and saturation
     untouched (boosting saturation instead was tried and turned down: it drove the
     troll's olive skin to orange);
  3. a despeckle, because median cut leaves lone pixels where two ramps met and no pack
     sprite has single-pixel noise.

Shrinking the sprite to the packs' body size was tried too and is not done here: LANCZOS
averages the black outline away and the face goes with it. The sprites are already the
right size -- pack bodies run 35x45 to 73x79 and the Bog Troll's is 52x58.

Pass a whole character at once:

    python tools/pixel_flatten.py "Assets/Enemies/Bog Troll/**/*.png"

Preview only, into tools/qa/pixel_flatten.png. Add --export to overwrite the sprites.
"""
import sys, glob, colorsys
import numpy as np
from PIL import Image

COLOURS = 16       # the middle of the packs' 14-22
STRETCH = 0.8      # how far towards the full lightness range the palette is pulled
DARK, LIGHT = 0.10, 0.92
REFERENCE = "Assets/Enemies/Minotaur/Sprites/with_outline/IDLE.png"
QA = "tools/qa/pixel_flatten.png"


def palette(frames, colours):
    """Median cut over the opaque pixels of every frame at once, weighted by how many there are."""
    opaque = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames])
    strip = Image.fromarray(opaque.reshape(1, -1, 3), "RGB")
    cut = strip.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.array(cut.getpalette()[:colours * 3], dtype=np.int32).reshape(-1, 3)


def stretch(pal, amount=STRETCH):
    """The palette's lightness pulled out to DARK..LIGHT, each colour's hue and saturation kept.

    What makes a generated sprite read as mud is not the colour count -- 16 is under the Minotaur's
    22 -- it is that skin, club and straps all sit in one narrow band. Spreading that band is what
    separates the forms; touching hue or saturation is what wrecks them.
    """
    hls = [colorsys.rgb_to_hls(*(c / 255)) for c in pal.astype(float)]
    lights = [l for _, l, _ in hls]
    low, high = min(lights), max(lights)
    out = []
    for hue, light, sat in hls:
        share = (light - low) / (high - low) if high > low else 0.0
        want = DARK + share * (LIGHT - DARK)
        out.append([round(v * 255) for v in colorsys.hls_to_rgb(hue, light + (want - light) * amount, sat)])
    return np.array(out, dtype=np.int32)


def map_to(frame, pal):
    """Nearest palette colour per opaque pixel; a transparent pixel gets -1 and no colour."""
    rgb = frame[..., :3].astype(np.int32)
    near = ((rgb[..., None, :] - pal[None, None, :, :]) ** 2).sum(-1).argmin(-1)
    return np.where(frame[..., 3] > 0, near, -1)


def despeckle(idx):
    """A lone pixel three of whose four neighbours agree on something else becomes that."""
    out = idx.copy()
    pad = np.pad(idx, 1, constant_values=-1)
    ways = [pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]]
    for y, x in zip(*np.where(idx >= 0)):
        near = [w[y, x] for w in ways if w[y, x] >= 0]
        if not near or idx[y, x] in near:
            continue
        top = max(set(near), key=near.count)
        if near.count(top) >= 3:
            out[y, x] = top
    return out


def flatten(paths, colours=COLOURS, amount=STRETCH):
    frames = [np.array(Image.open(p).convert("RGBA")) for p in paths]
    cut = palette(frames, colours)
    pal = stretch(cut, amount)
    done = []
    for f in frames:
        idx = despeckle(map_to(f, cut))          # matched on the cut, painted in the stretched
        done.append(np.dstack([pal[np.clip(idx, 0, None)].astype(np.uint8),
                               np.where(idx >= 0, 255, 0).astype(np.uint8)]))
    return frames, done


def colours_in(a):
    return len({tuple(px) for px in a[a[..., 3] > 0][:, :3]})


def preview(before, after, scale=6):
    """Every frame before, every frame after, and a pack sprite at the end for scale."""
    ref = Image.open(REFERENCE).convert("RGBA")
    ref = ref.crop((0, 0, ref.height, ref.height)).crop(Image.open(REFERENCE).convert("RGBA")
                                                        .crop((0, 0, ref.height, ref.height)).getbbox())
    rows = [before, after]
    tall = max(a.shape[0] for a in before + after)
    high = tall * len(rows)
    wide = max(sum(a.shape[1] + 2 for a in row) for row in rows) + ref.width + 4
    sheet = Image.new("RGBA", (wide, max(high, ref.height)), (100, 100, 100, 255))
    for r, row in enumerate(rows):
        x = 0
        for a in row:
            cell = Image.fromarray(a)
            sheet.alpha_composite(cell, (x, tall * r + tall - cell.height))
            x += cell.width + 2
    sheet.alpha_composite(ref, (wide - ref.width, sheet.height - ref.height))
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(QA)


if __name__ == "__main__":
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    paths = sorted({p for a in sys.argv[1:] if not a.startswith("--")
                    for p in glob.glob(a, recursive=True)})
    if not paths:
        sys.exit("no sprites matched")
    colours = next((int(f.split("=")[1]) for f in flags if f.startswith("--colors=")), COLOURS)
    amount = next((float(f.split("=")[1]) for f in flags if f.startswith("--stretch=")), STRETCH)
    before, after = flatten(paths, colours, amount)
    for p, b, a in zip(paths, before, after):
        print(f"{p}: {colours_in(b)} -> {colours_in(a)} colours")
    preview(before, after)
    print(f"preview {QA} -- before above, after below, a Minotaur frame at the end for scale")
    if "--export" in flags:
        for p, a in zip(paths, after):
            Image.fromarray(a).save(p)
        print(f"wrote {len(paths)} sprites")
