"""QA only: stands the hero and an enemy on a vista backdrop where the fight puts them
(combat_scene.gd: PLAYER_X 0.24, ENEMY_X 0.72, GROUND 0.86), at about their size on screen, so a
backdrop can be judged by whether the fighters still read on it."""
import numpy as np
from PIL import Image

from vista import H, W

ROOT = "../Assets/"
HERO_TALL = 105     # the hero's drawn height in backdrop pixels, measured off a screenshot


def _first_frame(path, frames=None):
    """The first figure on a strip: from its first opaque column to the next empty one."""
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3] > 0
    cols = a.any(axis=0)
    x0 = int(np.argmax(cols))
    x1 = x0
    while x1 < im.width and cols[x1]:
        x1 += 1
    f = im.crop((x0, 0, x1, im.height))
    return f.crop(f.getbbox())


def _stand(bg, sprite, cx, feet, tall, flip=False):
    k = tall / sprite.height
    s = sprite.resize((max(1, round(sprite.width * k)), max(1, round(sprite.height * k))),
                      Image.NEAREST)
    if flip:
        s = s.transpose(Image.FLIP_LEFT_RIGHT)
    bg.alpha_composite(s, (int(cx - s.width / 2), int(feet - s.height)))


def with_fighters(scene):
    bg = scene.convert("RGBA")
    hero = _first_frame(ROOT + "Player/idle.png", 8)
    orc = _first_frame(ROOT + "Enemies/Masked Orc/Sprites/IDLE.png", 4)
    feet = int(H * 0.86)
    _stand(bg, hero, W * 0.24, feet, HERO_TALL)
    _stand(bg, orc, W * 0.72, feet, 88,
           flip=True)
    return bg.convert("RGB")
