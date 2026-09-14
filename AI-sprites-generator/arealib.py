"""Toolkit for the battle backdrops in ../Assets/Area/.

The shipped backdrops are 2304x1296, but the reference (Summer2.png) is blocky at exactly 4x:
the art is 576x324 pixels and is nearest-upscaled on export. Everything here draws at native size.

Unlike the hex tiles these are not part of the locked 32-colour atlas -- they are ordinary RGB
PNGs in the reference's own softer palette, so each environment carries its own ramps (areas.py).
"""
import random

from PIL import Image, ImageDraw

W, H = 576, 324
SCALE = 4
HORIZON = 200          # the far waterline / haze line
GROUND_TOP = 202       # first row of land


# ---------------------------------------------------------------- noise

def smooth_noise(seed, n, k):
    """k random lattice points smoothstepped across n samples, wrapping."""
    rng = random.Random(seed)
    pts = [rng.random() for _ in range(k)]
    out = []
    for i in range(n):
        t = i / n * k
        a = int(t) % k
        f = t - int(t)
        f = f * f * (3 - 2 * f)
        out.append(pts[a] * (1 - f) + pts[(a + 1) % k] * f)
    return out


def fbm(seed, n, layers):
    """Sum of smooth_noise octaves, layers = ((lattice points, amplitude), ...), scaled to 0..1."""
    out = [0.0] * n
    total = 0.0
    for i, (k, a) in enumerate(layers):
        s = smooth_noise(seed * 131 + i * 17, n, k)
        out = [o + v * a for o, v in zip(out, s)]
        total += a
    return [o / total for o in out]


# ---------------------------------------------------------------- bands

def bands(d, ramp, x0=0, x1=W - 1):
    """Fills stacked colour bands from ramp = ((y, colour), ...), the last entry being the bottom.

    Each boundary gets three alternating rows of the next colour: the single-row dither the
    reference uses instead of a smooth gradient.
    """
    for (y0, c0), (y1, c1) in zip(ramp, ramp[1:]):
        d.rectangle([x0, y0, x1, y1 - 1], fill=c0)
    for (y0, c0), (y1, c1) in zip(ramp, ramp[1:]):
        if y1 - y0 >= 8 and c1 is not None:
            for dy in (5, 3, 1):
                d.line([x0, y1 - dy, x1, y1 - dy], fill=c1)
            for dy in (4, 2):
                d.line([x0, y1 - dy, x1, y1 - dy], fill=c0)


# ---------------------------------------------------------------- masks

def mask_paint(im, mask, colour):
    px = im.load()
    for x, y in mask:
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = colour


def shrink(mask):
    """The pixels of a mask whose four neighbours are all in it."""
    return {(x, y) for (x, y) in mask
            if (x - 1, y) in mask and (x + 1, y) in mask and (x, y - 1) in mask and (x, y + 1) in mask}


def top_rows(mask, n):
    """The topmost n pixels of every column of a mask -- the lit edge of a cloud or a hill."""
    cols = {}
    for x, y in mask:
        cols.setdefault(x, []).append(y)
    out = set()
    for x, ys in cols.items():
        for y in sorted(ys)[:n]:
            out.add((x, y))
    return out


# ---------------------------------------------------------------- clouds

def streak_mass(seed, x0, x1, y0, y1, rows=(3, 9)):
    """A wide cloud bank: horizontal slabs of varying width stacked between y0 and y1.

    Slabs rather than an ellipse is what gives the reference its wind-blown, layered look.
    """
    rng = random.Random(seed)
    mask = set()
    y = y0
    i = 0
    while y < y1:
        h = rng.randint(*rows)
        span = x1 - x0
        a = x0 + int(span * rng.uniform(0.0, 0.30))
        b = x1 - int(span * rng.uniform(0.0, 0.30))
        if b - a < 8:
            y += h
            i += 1
            continue
        edge = fbm(seed * 7 + i, b - a, ((3, 1.0), (11, 0.4)))
        for x in range(a, b):
            wobble = int(edge[x - a] * 4) - 2
            for yy in range(y + max(0, wobble), min(y1, y + h + wobble)):
                mask.add((x, yy))
        y += h
        i += 1
    return mask


def puff(seed, cx, base, r):
    """One cumulus: overlapping discs sitting on a flat baseline."""
    rng = random.Random(seed)
    mask = set()
    lobes = [(0, 0, r)] + [(rng.randint(-r, r), rng.randint(-r // 2, 0), rng.randint(r // 2, r))
                           for _ in range(rng.randint(3, 5))]
    for dx, dy, rr in lobes:
        for y in range(-rr, rr + 1):
            w = int((rr * rr - y * y) ** 0.5)
            for x in range(-w, w + 1):
                py = base - rr + dy + y
                if py <= base:
                    mask.add((cx + dx + x, py))
    for x in range(cx - 2 * r, cx + 2 * r):
        if (x, base - 1) in mask:
            mask.add((x, base))
    return mask


def overcast(im, seed, colour, base, height, layers=((2, 1.0), (5, 0.6), (11, 0.35),
                                                    (27, 0.18))):
    """The pale sheet the sky hangs from: everything above a ragged line near the top.

    The reference's white top is not a band, it is the underside of a cloud ceiling -- so the
    line between it and the blue has to wander, and the big teal banks are drawn inside it.
    """
    n = fbm(seed, W, layers)
    px = im.load()
    for x in range(W):
        bottom = base - int(n[x] * height)
        for y in range(0, max(0, bottom)):
            px[x, y] = colour
    return [base - int(v * height) for v in n]


def cloud_bank(im, seed, pal, y0, y1, x0=-60, x1=W + 60, n=3):
    """The big upper cloud masses: dark core, lit fringe, pale halo."""
    rng = random.Random(seed)
    for i in range(n):
        a = rng.randint(x0, x1 - 200)
        b = a + rng.randint(220, 520)
        t = rng.randint(y0, max(y0 + 1, y1 - 30))
        mask = streak_mass(seed * 13 + i, a, b, t, t + rng.randint(34, 76), rows=(4, 11))
        core = shrink(shrink(mask))
        mask_paint(im, mask, pal["cloud_edge"])
        mask_paint(im, core, pal["cloud_core"])
        mask_paint(im, top_rows(core, 2), pal["cloud_lit"])


def cumulus_row(im, seed, pal, base, count=6, r=(8, 20)):
    """The little clouds that sit on the horizon."""
    rng = random.Random(seed)
    for i in range(count):
        cx = int((i + rng.random()) * W / count) - 10
        rr = rng.randint(*r)
        mask = puff(seed * 17 + i, cx, base - rng.randint(0, 6), rr)
        mask_paint(im, mask, pal["cloud_lo"])
        mask_paint(im, top_rows(mask, max(2, rr // 3)), pal["cloud_hi"])


# ---------------------------------------------------------------- land

def ridge(im, seed, base, height, colour, lit=None, layers=((3, 1.0), (9, 0.45), (23, 0.2)),
          x0=0, x1=W):
    """A distant silhouette (hills, dunes, peaks): a noise skyline filled down to base."""
    n = fbm(seed, x1 - x0, layers)
    px = im.load()
    top = {}
    for x in range(x0, x1):
        t = base - int(n[x - x0] * height)
        top[x] = t
        for y in range(t, base):
            if 0 <= y < H and 0 <= x < W:
                px[x, y] = colour
    if lit:
        for x, t in top.items():
            for y in range(t, min(t + 2, base)):
                if 0 <= y < H and 0 <= x < W:
                    px[x, y] = lit
    return top


def mountain_range(im, seed, base, height, rock, lit, snow=None, shade=None, x0=0, x1=W,
                   spacing=(42, 110), steep=(0.6, 1.35)):
    """Overlapping triangular peaks.

    A noise ridge makes hills, never mountains: what reads as a mountain at this size is a
    straight slope meeting another straight slope at a point. Each peak is a triangle whose
    skyline is min(apex + |x - apex_x| / steepness); the west slope takes the light.
    """
    rng = random.Random(seed)
    peaks = []
    x = x0 - rng.randint(20, 60)
    while x < x1 + 40:
        ax = x + rng.randint(*spacing)
        ay = base - int(height * rng.uniform(0.32, 1.0) ** 1.3)
        peaks.append((ax, ay, rng.uniform(*steep)))
        x = ax
    px = im.load()
    top, west = {}, {}
    for x in range(x0, x1):
        best, side = base, True
        for ax, ay, st in peaks:
            y = ay + int(abs(x - ax) / st)
            if y < best:
                best, side = y, x <= ax
        top[x], west[x] = best, side
        for y in range(best, base):
            if 0 <= y < H and 0 <= x < W:
                px[x, y] = rock if side else (shade or rock)
    for x in range(x0, x1):                      # the lit rim along every west face
        if west[x]:
            for y in range(top[x], min(top[x] + 2, base)):
                if 0 <= y < H and 0 <= x < W:
                    px[x, y] = lit
    if snow:
        line = base - int(height * 0.68)
        wob = fbm(seed * 3, max(1, x1 - x0), ((7, 1.0), (19, 0.5)))
        for x in range(x0, x1):
            depth = line + int(wob[x - x0] * 10) - top[x]
            for y in range(top[x], top[x] + max(0, depth)):
                if 0 <= y < H and 0 <= x < W and y < base:
                    px[x, y] = snow
    return top


def scatter(im, seed, y0, y1, count, colours, size=1, xmin=0, xmax=W):
    """Specks (flowers, pebbles, sparkles) spread over a band, denser toward the bottom."""
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        t = rng.random() ** 0.6
        y = int(y0 + t * (y1 - y0))
        x = rng.randrange(xmin, xmax)
        c = rng.choice(colours)
        for dy in range(size):
            for dx in range(size):
                if 0 <= x + dx < W and 0 <= y + dy < H:
                    px[x + dx, y + dy] = c


def leaf(px, x, y, h, colour, w=1):
    """One blade: a stroke that leans as it rises and tapers to a point.

    Wide blades are what make the near foreground read as leaves rather than fur, so w grows
    with the clump; the taper is two rows so even a 2 px blade ends in a point.
    """
    lean = 1 if (x + y) % 2 else -1
    for i in range(h):
        xx = x + lean * (i * 2 // max(2, h))
        yy = y - i
        ww = max(1, w - (i >= h - 2) - (i >= h - 1))
        for dx in range(ww):
            if 0 <= xx + dx < W and 0 <= yy < H:
                px[xx + dx, yy] = colour


def clump(px, rng, cx, cy, w, h, colour, lit, size, leaves, blade=1):
    """One bush: a solid body so the layer reads as mass, then blades off the top of it."""
    for y in range(cy - h, cy + 1):
        t = (cy - y) / max(1, h)
        half = int(w / 2 * (1 - t * t) ** 0.5)
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = colour
    for _ in range(rng.randint(*leaves)):
        x = cx + rng.randint(-w // 2, w // 2)
        leaf(px, x, cy - h + rng.randint(-1, 2), rng.randint(*size), colour, blade)
    if lit:
        for _ in range(rng.randint(1, 3)):
            x = cx + rng.randint(-w // 2, w // 2)
            leaf(px, x, cy - h + rng.randint(-1, 1), rng.randint(size[0], size[1]), lit, blade)


def clump_layer(im, seed, y_top, y_bot, colours, density=1.0, size=(3, 7), leaves=(4, 9),
                width=(9, 20), body=(3, 7), lit=True):
    """Overlapping foliage, drawn back to front: each depth row is one step darker than the last."""
    rng = random.Random(seed)
    px = im.load()
    rows = max(1, (y_bot - y_top) // 7)
    for r in range(rows):
        y = y_top + (r + 1) * (y_bot - y_top) // rows
        base_i = min(len(colours) - 1, r * len(colours) // rows)
        grow = 0.6 + 1.1 * r / max(1, rows - 1)          # near clumps are bigger than far ones
        for _ in range(int(W * density / 9)):
            # Mixing neighbouring ramp steps within a row keeps the mass reading as separate
            # bushes; a row of one flat colour turns the whole foreground into a dark slab.
            i = max(0, min(len(colours) - 1, base_i + rng.randint(-1, 1)))
            colour = colours[i]
            hi = colours[max(0, i - 2)] if lit and rng.random() < 0.75 - 0.4 * r / rows else None
            clump(px, rng, rng.randrange(-6, W + 6), y + rng.randint(-2, 2),
                  int(rng.randint(*width) * grow), int(rng.randint(*body) * grow), colour, hi,
                  (int(size[0] * grow) + 1, int(size[1] * grow) + 1), leaves,
                  blade=1 + (grow > 0.95) + (grow > 1.3))


def blossom(px, x, y, petal, centre, r=2):
    """A flower big enough to read: a ring of petals round a bright centre."""
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            if abs(dx) + abs(dy) <= r and 0 <= x + dx < W and 0 <= y + dy < H:
                px[x + dx, y + dy] = petal
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = centre


def flowers(im, seed, y0, y1, count, kinds):
    """Scatters blossoms over a band; kinds are (petal, centre) pairs."""
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        petal, centre = rng.choice(kinds)
        blossom(px, rng.randrange(0, W), int(y0 + (rng.random() ** 0.7) * (y1 - y0)),
                petal, centre, rng.randint(1, 2))


def rock(px, rng, cx, base, rx, ry, body, lit, shade):
    """One stone: a squat lump sitting flat on the ground, with a 1 px lit crown.

    Keep the light to the top row. Shading half the lump makes a mushroom, and tapering the
    silhouette makes a tent; a rock at this size is a flat-bottomed dome in one colour.
    """
    widths = []
    for dy in range(-ry, 1):
        t = 1 - (dy / -ry) ** 2 if ry else 1
        half = max(1, int(rx * (t ** 0.5)))
        widths.append(half)
        for dx in range(-half, half + 1):
            x, y = cx + dx, base + dy
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = body
    top = widths[0]
    for dx in range(-top, top + 1):                     # lit crown, drifting left with the light
        x, y = cx + dx - 1, base - ry
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = lit
    for dx in range(-widths[-1] + 1, widths[-1]):       # the stone's own shadow on the ground
        x, y = cx + dx, base + 1
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = shade
    if rng.random() < 0.4 and rx > 3:                   # a crack or a second facet
        x, y = cx + rng.randint(-rx // 2, rx // 2), base - rng.randint(1, max(1, ry - 1))
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = shade


def pebble_layer(im, seed, y_top, y_bot, colours, density=1.0, size=(2, 6), flat=1.6):
    """Stones and clods, bigger and darker toward the front."""
    rng = random.Random(seed)
    px = im.load()
    rows = max(1, (y_bot - y_top) // 7)
    for r in range(rows):
        y = y_top + (r + 1) * (y_bot - y_top) // rows
        grow = 0.6 + 1.2 * r / max(1, rows - 1)
        base_i = min(len(colours) - 1, r * len(colours) // rows)
        for _ in range(int(W * density / 7)):
            i = max(0, min(len(colours) - 1, base_i + rng.randint(-1, 1)))
            rx = max(1, int(rng.randint(*size) * grow))
            rock(px, rng, rng.randrange(-4, W + 4), y + rng.randint(-2, 2), rx,
                 max(1, int(rx / flat)), colours[i], colours[max(0, i - 2)],
                 colours[min(len(colours) - 1, i + 2)])


def patches(im, seed, y0, y1, colours, count=14, rx=(18, 60), ry=(4, 12), fill=0.75):
    """Broad, soft blotches of a neighbouring ramp step: large-scale variation in a flat surface.

    Ground reads as noise when every mark is the same size. The big shapes go down first and the
    stones and tufts sit on top of them.
    """
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        cx = rng.randrange(-30, W + 30)
        cy = rng.randint(y0, y1)
        a, b = rng.randint(*rx), rng.randint(*ry)
        c = colours[rng.randrange(len(colours))]
        for dy in range(-b, b + 1):
            for dx in range(-a, a + 1):
                if (dx / a) ** 2 + (dy / b) ** 2 <= 1 and rng.random() < fill:
                    x, y = cx + dx, cy + dy
                    if 0 <= x < W and 0 <= y < H:
                        px[x, y] = c


def boulders(im, seed, y0, y1, colours, count=18, size=(3, 14), flat=1.9):
    """A handful of stones, placed with gaps and in clearly different sizes, front ones biggest."""
    rng = random.Random(seed)
    px = im.load()
    for i in range(count):
        t = (i + rng.random()) / count
        y = int(y0 + (y1 - y0) * t)
        rx = max(2, int(size[0] + (size[1] - size[0]) * (t ** 0.8) * rng.uniform(0.5, 1.3)))
        j = min(len(colours) - 1, int(t * len(colours)) + rng.randint(-1, 1))
        j = max(0, j)
        rock(px, rng, rng.randrange(-6, W + 6), y, rx, max(2, int(rx / flat)), colours[j],
             colours[max(0, j - 2)], colours[min(len(colours) - 1, j + 2)])


def ripple_layer(im, seed, y_top, y_bot, colours, density=1.0, length=(4, 14)):
    """Wind ripples or furrows: short horizontal dashes that lengthen as they come forward."""
    rng = random.Random(seed)
    px = im.load()
    rows = max(1, (y_bot - y_top) // 5)
    for r in range(rows):
        y = y_top + (r + 1) * (y_bot - y_top) // rows
        grow = 0.5 + 1.5 * r / max(1, rows - 1)
        base_i = min(len(colours) - 1, r * len(colours) // rows)
        for _ in range(int(W * density / 12)):
            i = max(0, min(len(colours) - 1, base_i + rng.randint(-1, 1)))
            x = rng.randrange(-10, W)
            yy = y + rng.randint(-2, 2)
            n = int(rng.randint(*length) * grow)
            for k in range(n):
                dip = (k * 3 // max(1, n)) - 1
                if 0 <= x + k < W and 0 <= yy + dip < H:
                    px[x + k, yy + dip] = colours[i]
                    if 0 <= yy + dip - 1 < H and rng.random() < 0.4:
                        px[x + k, yy + dip - 1] = colours[max(0, i - 2)]


def furrows(im, seed, y0, y1, colours, gap=(5, 22), run=(10, 46), skip=(2, 14)):
    """Ploughed lines running across the field, spaced wider as they come forward.

    Perspective lives in the spacing: even gaps read as wallpaper, widening ones read as ground
    receding. Each line is drawn as long runs with gaps between them -- randomising pixel by pixel
    turns the field into Morse code.
    """
    rng = random.Random(seed)
    px = im.load()
    y = y0
    i = 0
    while y < y1:
        t = (y - y0) / max(1, y1 - y0)
        wob = fbm(seed * 7 + i, W, ((3, 1.0), (11, 0.4)))
        dark = colours[min(len(colours) - 1, int(t * len(colours)))]
        lit = colours[max(0, int(t * len(colours)) - 2)]
        x = -rng.randint(0, 30)
        while x < W:
            n = rng.randint(*run)
            for k in range(n):
                xx = x + k
                if not 0 <= xx < W:
                    continue
                yy = y + int(wob[xx] * (2 + 3 * t))
                for d in range(1 + int(t * 1.5)):
                    if 0 <= yy + d < H:
                        px[xx, yy + d] = dark
                if 0 <= yy - 1 < H and rng.random() < 0.35:
                    px[xx, yy - 1] = lit
            x += n + rng.randint(*skip)
        y += int(gap[0] + (gap[1] - gap[0]) * t) + rng.randint(0, 1)
        i += 1


def verge_tufts(im, seed, line, colours, density=0.5):
    """Grass hanging over the lip of a road, so the verge is not a drawn line."""
    rng = random.Random(seed)
    px = im.load()
    for x in range(W):
        if rng.random() > density:
            continue
        y = line[x] + rng.randint(-1, 2)
        c = colours[rng.randrange(len(colours))]
        for _ in range(rng.randint(1, 3)):
            leaf(px, x + rng.randint(-1, 1), y + rng.randint(0, 2), rng.randint(2, 5), c)


def canvas():
    im = Image.new("RGB", (W, H), (0, 0, 0))
    return im, ImageDraw.Draw(im)


def export(im, path, scale=SCALE):
    im.resize((W * scale, H * scale), Image.NEAREST).save(path)
