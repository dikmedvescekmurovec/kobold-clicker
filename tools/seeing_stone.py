"""The Seeing Stone: the orb on its stand the map's corner button is, and the glow the game tints to say
how near the Gollux cave is.

Two pictures, one size (SIDE square). `seeing_stone.png` is the stone at rest: a smoky dark orb with
one highlight, in a brass claw on a foot. `seeing_stone_glow.png` is the light inside it, white with
the alpha falling off to the rim, which `main_scene` modulates to the temperature's colour and fades --
so five temperatures are one sprite and a tint, never five pictures. A stand-in until the user's own
pixellab stone replaces the first.

    python tools/seeing_stone.py            writes the preview tools/qa/seeing_stone.png only
    python tools/seeing_stone.py --export   also writes both into Assets/UI/, and her badge (the stone
                                            lit warm) into Assets/Fortune/stone.png
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Assets", "UI")
QA = os.path.join(HERE, "qa")
SIDE = 32
# The orb: centre and radius, in pixels.
ORB = (16.0, 13.5, 10.5)
# The temperatures the preview shows the glow in, coldest first: `main_scene.STONE_COLOURS`.
TEMPERATURES = [("cold", "#7fb8ff"), ("cool", "#9fd8e8"), ("warm", "#f2c96b"), ("hot", "#f08a3c"),
                ("burning", "#e8452c")]


def hexc(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (a,)


# Two tones a surface, from the map's palette (hexlib): the orb's smoke in ink and abyss, the stand in
# brass (st1, st2) over the dirt ramp's darkest step.
ORB_DARK, ORB_MID, ORB_RIM = hexc("#14101e"), hexc("#26325e"), hexc("#3a4a86")
SHINE = hexc("#f6faff")
BRASS_LIT, BRASS_SHADE, BRASS_DARK = hexc("#c0a45c"), hexc("#8e7a3c"), hexc("#34211e")


def stone():
    img = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    px = img.load()
    cx, cy, r = ORB
    # The foot and the claw, drawn first so the orb sits in it.
    for y in range(24, 31):
        half = 4 if y < 27 else 7 if y < 30 else 8
        for x in range(int(cx) - half, int(cx) + half):
            lit = x < cx - 1
            px[x, y] = BRASS_DARK if y in (26, 30) else BRASS_LIT if lit else BRASS_SHADE
    for x0, y0 in ((cx - 8, 19), (cx + 7, 19)):                     # two prongs up the orb's sides
        for k in range(6):
            px[int(x0) + (1 if x0 < cx else -1) * (k // 3), y0 + k] = BRASS_LIT if x0 < cx else BRASS_SHADE
    for y in range(SIDE):
        for x in range(SIDE):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > r:
                continue
            # Smoke: darker to the lower right, a rim of the lighter blue where the light comes round.
            shade = (x + 0.5 - cx) * 0.6 + (y + 0.5 - cy) * 0.8
            c = ORB_RIM if d > r - 1.2 and shade < 0 else ORB_MID if shade < 2.0 else ORB_DARK
            px[x, y] = c
    for x, y in ((11, 8), (12, 8), (11, 9), (10, 9), (12, 7)):         # the one highlight
        px[x, y] = SHINE
    return img


def glow():
    """The light inside the orb, white, full at its heart and gone at the rim. Only inside the orb."""
    img = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    px = img.load()
    cx, cy, r = ORB
    for y in range(SIDE):
        for x in range(SIDE):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - (cy + 1.0))
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) > r - 1.0:
                continue
            # Stepped rather than smooth, the way everything here is: three bands of alpha.
            a = 230 if d < r * 0.35 else 150 if d < r * 0.65 else 70
            px[x, y] = (255, 255, 255, a)
    return img


def tinted(glow_img, colour):
    tint = hexc(colour)
    out = Image.new("RGBA", glow_img.size)
    out.putdata([(tint[0], tint[1], tint[2], a) for _, _, _, a in glow_img.get_flattened_data()])
    return out


def preview(base, light):
    """At rest, then lit in each temperature, on the map's dark and on grass, at 4x."""
    shots = [base]
    for _, colour in TEMPERATURES:
        lit = base.copy()
        lit.alpha_composite(tinted(light, colour))
        for x, y in ((11, 8), (12, 8), (11, 9), (10, 9), (12, 7)):     # the highlight stays on top
            lit.putpixel((x, y), SHINE)
        shots.append(lit)
    sheet = Image.new("RGBA", ((SIDE + 4) * len(shots), (SIDE + 4) * 2), (20, 20, 24, 255))
    for i, shot in enumerate(shots):
        sheet.alpha_composite(shot, (i * (SIDE + 4) + 2, 2))
        grass = Image.new("RGBA", (SIDE + 4, SIDE + 4), hexc("#5a9147"))
        grass.alpha_composite(shot, (2, 2))
        sheet.alpha_composite(grass, (i * (SIDE + 4), SIDE + 4))
    return sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)


def main():
    base, light = stone(), glow()
    os.makedirs(QA, exist_ok=True)
    preview(base, light).save(os.path.join(QA, "seeing_stone.png"))
    print("wrote tools/qa/seeing_stone.png (at rest, then cold .. burning; on dark and on grass)")
    if "--export" in sys.argv:
        base.save(os.path.join(OUT, "seeing_stone.png"))
        light.save(os.path.join(OUT, "seeing_stone_glow.png"))
        # Her badge is the stone itself, lit warm, until a pixellab symbol is framed for it by ui_kit.py.
        badge = base.copy()
        badge.alpha_composite(tinted(light, TEMPERATURES[2][1]))
        badge.save(os.path.join(HERE, "..", "Assets", "Fortune", "stone.png"))
        print("wrote Assets/UI/seeing_stone.png, seeing_stone_glow.png and Assets/Fortune/stone.png")


if __name__ == "__main__":
    main()
