"""The other heroes, cut from the CraftPix packs under `Assets/Potential/Other player characters/`.

A pack draws each animation as one row of square cells, the body anywhere in them and now and then a
few pixels over a cell's edge. Each hero's idle, walk and attack are cut here at the clear column
nearest every edge, turned to face right, cropped to the one box all three fill (so nothing jumps as
the animation changes) and laid out as one row each with a clear pixel round every cell. With them
go the dialogue portrait (the idle's head and shoulders, a frame under a frame, `DialogueBox`'s
strip) and the corner panel's face on its disc.

No arguments writes the previews `tools/qa/characters_*.png` only -- the heroes in a fight beside the
kobold, each one's map token, portrait, face and badge, and every strip as cut -- and prints the rows
for `Characters.ROSTER`. `--export` writes `Assets/Characters/<id>/`. Run the Godot import after it.
"""
import argparse
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import npc_portraits
import ui_kit

ROOT = Path(__file__).resolve().parent.parent
PACKS = ROOT / "Assets/Potential/Other player characters"
OUT = ROOT / "Assets/Characters"
QA = ROOT / "tools/qa"
ANIMATIONS = ("idle", "walk", "attack")
PAD = 8  # how far a body may reach past its cell's edge and still be cut whole
GUTTER = 1  # clear pixels round every exported cell: no neighbour bleeds in at a fractional scale
ATTACK_LEAST = 4  # CombatScene.SWING_RESTART_FRAME cuts a swing back in at frame 2
THICK = 7  # a row with this many solid pixels in a run is body; a spear, a bow or a staff is thinner
POLE = 12  # what stands this far over the body's first thick row is held, not worn: not the hero's height
PORTRAIT = 52  # DialogueBox.PORTRAIT_HEIGHT, and as wide
HEAD_AT = (30, 20)  # a head's middle in its portrait, as the kobold's is in his
FACE_FROM_HEAD = (2, 1)  # the face looks right, so its disc is centred a little ahead of the head
BACKDROP = (384, 216)
GROUND = 0.86  # CombatScene.GROUND
FIGHT_TALL = BACKDROP[1] * 0.33 / 1.05  # CombatScene.ACTOR_HEIGHT of the view, less BACKDROP_BLEED
TOKEN_TALL = 31  # the kobold's height on the map, which every hero's token is drawn at
TOKEN_FOOT = 6  # PlayerToken.FOOT_OFFSET
MAP_ZOOM = 3  # the default window's
KOBOLD_FRAME = 148  # CombatActor's frame for him, the one hero whose cells are not square
KOBOLD_STAND = (27, 29, 51, 62)
KOBOLD_FEET = 61  # the column of his frame the user marked his feet at (2026-10-11)
BADGE = 34  # MapPointer's disc: twice its DISC_RADIUS
TOKEN_SHADOW = 36 / 62  # PlayerToken's shadow under the kobold, as a share of his height
TILE = (0, 64, 56, 128)  # the hex sheet's plain sand: a tile with a bush on it reads as a second shadow

BOSSES = "craftpix-891165-cave-bosses-pixel-art-game-sprites/"
SAMURAI = "craftpix-net-123681-free-samurai-pixel-art-sprite-sheets/"
SATYRS = "craftpix-net-131479-free-satyr-sprite-sheet-pixel-art-pack/"
MEN = "craftpix-net-218292-anime-warrior-man-character-pixel-sprite-pack/"
WOLVES = "craftpix-net-248468-free-werewolf-sprite-sheets-pixel-art/"
YOKAI = "craftpix-net-605776-free-yokai-pixel-art-character-sprites/"
SKELETONS = "craftpix-net-707873-tiny-skeleton-monster-pixel-sprite-pack/Craftpix_Skeleton_32px/"
ORCS = "craftpix-net-723951-orc-character-sprite-sheets-pixel-art/"
MEGA = "craftpix-net-809571-mega-boss-for-pixel-platformer-character-pack/"
DEMONS = "craftpix-net-838634-demon-sprite-sheet-pixel-art-pack/"
KNIGHTS = "craftpix-net-901238-tiny-medieval-knight-pixel-art-sprite-pack/Craftpix_Knight_32px/"

# id, name, folder, idle, walk, attack, and what only this one needs:
#   flip      drawn facing left
#   top       the idle is measured from this row down: a banner on the back is not the body's height
#   foot      the row of its cell the ground is at, where it floats over it
#   feet      the column of its cell, as it faces right, that the middle of its feet stands in: the user's
#             own marks (2026-10-11), which a map token is stood on its tile by
#   head      the head moved (dx, dy) from where `head_of` finds it
#   portrait  the hero moved (dx, dy) in the dialogue portrait
#   face      the hero moved (dx, dy) in the corner's face and the map's badge, which are one picture
#   zoom      how far that picture is drawn back: 1 is the art's own pixels
# **An id is for ever:** it is what a save holds, and one renamed is a hero bought and gone. The
# attack is one of `ATTACK_LEAST` frames or more with no body across a cell's edge.
CHARACTERS = [
    ("knight_1", "Knight", KNIGHTS + "Knight_1", "Idle", "Run", "Attack_3",
     {"feet": 63, "portrait": (-6, 0), "zoom": 1.25}),
    ("knight_2", "Mace Knight", KNIGHTS + "Knight_2", "Idle", "Run", "Attack_2",
     {"feet": 61, "head": (4, 2), "portrait": (-6, 0), "zoom": 1.25}),
    ("knight_3", "Lancer", KNIGHTS + "Knight_3", "Idle", "Run", "Attack_2",
     {"feet": 61, "top": 84, "head": (4, 0), "portrait": (-6, 0), "zoom": 1.25}),
    ("samurai", "Samurai", SAMURAI + "Samurai", "Idle", "Run", "Attack_1",
     {"feet": 33, "head": (2, -7)}),
    ("samurai_archer", "Samurai Archer", SAMURAI + "Samurai_Archer", "Idle", "Run", "Attack_1",
     {"feet": 66, "head": (2, -6)}),
    ("samurai_commander", "Samurai Commander", SAMURAI + "Samurai_Commander", "Idle", "Run", "Attack_1",
     {"feet": 60, "top": 59, "head": (3, -2)}),
    ("man_1", "Swordsman", MEN + "Man_1", "Idle", "Run", "Attack_1",
     {"feet": 63}),
    ("man_2", "Ronin", MEN + "Man_2", "Idle", "Run", "Attack_2",
     {"feet": 69, "head": (0, -3)}),
    ("man_3", "Spearman", MEN + "Man_3", "Idle", "Run", "Attack_1",
     {"feet": 61, "face": (0, -3)}),
    ("karasu_tengu", "Karasu Tengu", YOKAI + "Karasu_tengu", "Idle", "Run", "Attack_2",
     {"feet": 68, "head": (16, -9)}),
    ("kitsune", "Kitsune", YOKAI + "Kitsune", "Idle", "Run", "Attack_3",
     {"feet": 62, "head": (4, 0), "zoom": 1.25}),
    ("yamabushi_tengu", "Yamabushi Tengu", YOKAI + "Yamabushi_tengu", "Idle", "Run", "Attack_3",
     {"feet": 62, "head": (6, 0)}),
    ("orc_warrior_brown", "Brown Orc", ORCS + "Orc_Warrior_Brown", "Idle", "Run", "Attack_1",
     {"feet": 61, "head": (6, -2)}),
    ("orc_warrior_green", "Green Orc", ORCS + "Orc_Warrior_Green", "Idle", "Run", "Attack_1",
     {"feet": 60, "head": (5, -2)}),
    ("orc_woman", "Orc Huntress", ORCS + "Orc_Woman", "Idle", "Run", "Attack_2",
     {"feet": 63, "head": (2, -5)}),
    ("satyr_1", "Faun", SATYRS + "Satyr_1", "Idle", "Walk", "Attack",
     {"feet": 62}),
    ("satyr_2", "Satyr Shaman", SATYRS + "Satyr_2", "Idle", "Walk", "Attack",
     {"feet": 56}),
    ("satyr_3", "Satyr", SATYRS + "Satyr_3", "Idle", "Walk", "Attack",
     {"feet": 63}),
    ("skeleton_1", "Skeleton Archer", SKELETONS + "Skeleton_1", "Idle", "Walk", "Attack_1",
     {"feet": 59, "head": (6, 4), "face": (-3, -3), "zoom": 1.5}),
    ("skeleton_2", "Skeleton Warrior", SKELETONS + "Skeleton_2", "Idle", "Walk", "Attack_1",
     {"feet": 58, "face": (-1, -2), "zoom": 1.5}),
    ("skeleton_3", "Skeleton Spearman", SKELETONS + "Skeleton_3", "Idle", "Walk", "Attack_1",
     {"feet": 60, "top": 88, "face": (-1, -2), "zoom": 1.5}),
    ("black_werewolf", "Black Werewolf", WOLVES + "Black_Werewolf", "Idle", "Run", "Attack_1",
     {"feet": 72, "head": (17, 4), "face": (-3, 0), "zoom": 1.5}),
    ("red_werewolf", "Red Werewolf", WOLVES + "Red_Werewolf", "Idle", "Run", "Attack_1",
     {"feet": 62, "head": (15, 4), "face": (-3, 0), "zoom": 1.5}),
    ("white_werewolf", "White Werewolf", WOLVES + "White_Werewolf", "Idle", "Run", "Attack_1",
     {"feet": 62, "head": (15, 4), "face": (-3, 0), "zoom": 1.5}),
    ("demon_1", "Evil Eye", DEMONS + "Demon_1", "Idle", "Walk", "Attack",
     {"feet": 60, "foot": 110, "head": (0, 12), "portrait": (-4, 6), "face": (-11, 1)}),
    ("demon_2", "Demon", DEMONS + "Demon_2", "Idle", "Walk", "Attack",
     {"feet": 57, "head": (12, 2), "zoom": 1.25}),
    ("demon_3", "Imp", DEMONS + "Demon_3", "Idle", "Walk", "Attack",
     {"feet": 67, "zoom": 1.25}),
    ("huge_mushroom", "Huge Mushroom", BOSSES + "1 Huge mushroom", "HugeMushroom_idle", "HugeMushroom_walk",
     "HugeMushroom_attack1", {"feet": 26, "flip": True, "head": (0, 6), "portrait": (-6, 0), "zoom": 1.25}),
    ("goblin_king", "Goblin King", BOSSES + "2 Goblin king", "GoblinKing_idle", "GoblinKing_walk",
     "GoblinKing_attack3", {"feet": 26, "flip": True, "portrait": (-6, 0)}),
    ("vampire_bat", "Vampire Bat", BOSSES + "3 Vampire bat", "VampireBat_idle", "VampireBat_walk",
     "VampireBat_attack1", {"feet": 27, "flip": True, "head": (-6, -2)}),
    ("mega_boss", "Hell Knight", MEGA + "1", "Idle", "Run", "Attack",
     {"feet": 124, "head": (0, 3), "face": (0, -4), "zoom": 1.5}),
]


def frames_of(path: Path, flip: bool = False, side: int = 0) -> list:
    """A strip's frames, each `PAD` wider than its cell either side so a body cut at the clear column
    nearest its cell's edge keeps the pixels it had over that edge, where they were."""
    strip = Image.open(path).convert("RGBA")
    side = side or strip.height
    if strip.width % side:
        raise SystemExit(f"{path}: {strip.width} wide is no whole number of {side} px cells")
    solid = np.asarray(strip)[:, :, 3].any(axis=0)
    cuts = [0]
    for edge in range(side, strip.width, side):
        cut = edge
        if solid[edge - 1] and solid[edge]:
            near = [edge + d for reach in range(1, PAD + 1) for d in (-reach, reach) if not solid[edge + d]]
            if not near:
                raise SystemExit(f"{path}: no clear column within {PAD} px of the cell edge at {edge}")
            cut = near[0]
        cuts.append(cut)
    cuts.append(strip.width)
    frames = []
    for i in range(len(cuts) - 1):
        frame = Image.new("RGBA", (side + 2 * PAD, strip.height))
        frame.paste(strip.crop((cuts[i], 0, cuts[i + 1], strip.height)), (cuts[i] - i * side + PAD, 0))
        frames.append(frame.transpose(Image.FLIP_LEFT_RIGHT) if flip else frame)
    if solid_count(frames) != int((np.asarray(strip)[:, :, 3] > 0).sum()):
        raise SystemExit(f"{path}: the cut lost or doubled pixels")
    return frames


def solid_count(frames: list) -> int:
    return sum(int((np.asarray(frame)[:, :, 3] > 0).sum()) for frame in frames)


def used(frame: Image.Image, top: int = 0):
    """What `frame` draws from row `top` down, as a box, or None."""
    box = frame.crop((0, top, frame.width, frame.height)).getbbox()
    return box and (box[0], box[1] + top, box[2], box[3] + top)


def union(boxes) -> tuple:
    boxes = [box for box in boxes if box]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def widest(row) -> tuple:
    """The longest unbroken run of solid pixels in a row of alpha, as (start, end)."""
    best, start = (0, 0), None
    for x, on in enumerate(list(row) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > best[1] - best[0]:
                best = (start, x)
            start = None
    return best


def crown_of(first: Image.Image, box: tuple) -> int:
    """The first row of `box` that is body and not a pole held over it: one with `THICK` solid pixels in a run."""
    solid = np.asarray(first)[:, :, 3] > 0
    for y in range(box[1], box[3]):
        run = widest(solid[y, box[0]:box[2]])
        if run[1] - run[0] >= THICK:
            return y
    return box[1]


def head_of(first: Image.Image, stand: tuple) -> tuple:
    """Where the first idle frame's head is, near enough: the middle of the thickest thing it draws in
    the top of its standing box. A row's `head` moves it where wings, a hunch or a crest drag that off."""
    reach = min(22, max(7, round(0.2 * (stand[3] - stand[1]))))
    solid = np.asarray(first)[:, :, 3] > 0
    middles = []
    for y in range(stand[1], min(stand[3], stand[1] + 2 * reach)):
        run = widest(solid[y, stand[0]:stand[2]])
        if run[1] - run[0] >= THICK:
            middles.append((run[0] + run[1]) / 2)
    middle = float(np.median(middles)) if middles else (stand[2] - stand[0]) / 2
    return stand[0] + round(middle), stand[1] + reach


def shrunk(image: Image.Image, side: int) -> Image.Image:
    """`image` at `side` pixels a side, still in its own colours: a box filter's average snapped back
    onto them (as `skill_stones.small` draws a stone small), so drawn back it is still pixel art."""
    if image.width == side:
        return image
    small = np.asarray(image.convert("RGBa").resize((side, side), Image.BOX).convert("RGBA")).astype(int)
    pixels = np.asarray(image).reshape(-1, 4)
    colours = np.unique(pixels[pixels[:, 3] > 0], axis=0).astype(int)
    out = np.zeros((side, side, 4), np.uint8)
    solid = small[:, :, 3] >= 128
    if len(colours):
        nearest = ((small[:, :, None, :3] - colours[None, None, :, :3]) ** 2).sum(axis=3).argmin(axis=2)
        out[solid] = colours[nearest][solid]
    return Image.fromarray(out, "RGBA")


def close_up(frame: Image.Image, middle: tuple, zoom: float, side: int) -> Image.Image:
    """`frame` round `middle` as a picture `side` across, drawn back by `zoom`."""
    half = round(side * zoom / 2)
    return shrunk(frame.crop((middle[0] - half, middle[1] - half, middle[0] + half, middle[1] + half)), side)


def face_of(close: Image.Image, mask: Image.Image) -> Image.Image:
    """The corner panel's portrait: a close-up on the frame's disc, as ui_kit draws the kobold's."""
    disc = Image.new("RGBA", mask.size, ui_kit.CHAR_DISC)
    disc.alpha_composite(close)
    return Image.composite(disc, Image.new("RGBA", mask.size), mask)


def stacked(frames: list, box: tuple) -> Image.Image:
    """Every frame's `box`, one under another: `DialogueBox`'s strip."""
    side = box[3] - box[1]
    strip = Image.new("RGBA", (box[2] - box[0], side * len(frames)))
    for i, frame in enumerate(frames):
        strip.paste(frame.crop(box), (0, i * side))
    return strip


def hero(ident: str, name: str, raw: dict, how: dict, mask: Image.Image) -> dict:
    """One hero from its three animations' frames: cropped to the one box they share, with its
    standing box and its feet in that crop, its portrait strip, its face and its badge."""
    plain = union(used(frame) for frame in raw["idle"])
    crown = crown_of(raw["idle"][0], plain)
    top = how.get("top", crown if crown - plain[1] >= POLE else plain[1])
    stand = union(used(frame, top) for frame in raw["idle"])
    stand = (stand[0], stand[1], stand[2], how.get("foot", stand[3]))
    drawn = union([used(frame) for frames in raw.values() for frame in frames] + [stand])
    box = (drawn[0] - GUTTER, drawn[1] - GUTTER, drawn[2] + GUTTER, drawn[3] + GUTTER)
    first = raw["idle"][0]
    head = head_of(first, stand)
    head = (head[0] + how.get("head", (0, 0))[0], head[1] + how.get("head", (0, 0))[1])
    moved = how.get("portrait", (0, 0))
    window = (head[0] - HEAD_AT[0] - moved[0], head[1] - HEAD_AT[1] - moved[1])
    moved = how.get("face", (0, 0))
    middle = (head[0] + FACE_FROM_HEAD[0] - moved[0], head[1] + FACE_FROM_HEAD[1] - moved[1])
    zoom = how.get("zoom", 1.0)
    feet = how["feet"] + PAD if "feet" in how else (stand[0] + stand[2]) / 2
    return {
        "id": ident, "name": name,
        "frames": {anim: [frame.crop(box) for frame in frames] for anim, frames in raw.items()},
        "size": (box[2] - box[0], box[3] - box[1]),
        # Where the crop's corner is in the pack's own cell, as the hero faces right.
        "cell": (box[0] - PAD, box[1]),
        "stand": (stand[0] - box[0], stand[1] - box[1], stand[2] - stand[0], stand[3] - stand[1]),
        "measured": stand == plain,
        "feet": (feet - box[0], stand[3] - box[1]),
        "head": (head[0] - box[0], head[1] - box[1]),
        "portrait": stacked(raw["idle"], (window[0], window[1], window[0] + PORTRAIT, window[1] + PORTRAIT)),
        "face": face_of(close_up(first, middle, zoom, mask.width), mask),
        "badge": close_up(first, middle, zoom, BADGE),
    }


def heroes(mask: Image.Image) -> list:
    found = []
    for ident, name, folder, idle, walk, attack, how in CHARACTERS:
        raw = {anim: frames_of(PACKS / folder / (file + ".png"), how.get("flip", False))
               for anim, file in zip(ANIMATIONS, (idle, walk, attack))}
        if len(raw["attack"]) < ATTACK_LEAST:
            raise SystemExit(f"{ident}: its attack has {len(raw['attack'])} frames, under {ATTACK_LEAST}")
        found.append(hero(ident, name, raw, how, mask))
    if len({one["id"] for one in found}) != len(found):
        raise SystemExit("two heroes share an id")
    return found


def kobold(face: Image.Image) -> dict:
    """The kobold as the game has him today, for the previews to stand the others beside: his own
    portrait, face and badge, and the feet the user marked for him."""
    raw = {anim: frames_of(ROOT / "Assets/Player" / f"{file}.png", side=KOBOLD_FRAME)
           for anim, file in zip(ANIMATIONS, ("idle", "run", "attack"))}
    him = hero("kobold", "Kobold", raw, {"feet": KOBOLD_FEET}, face.getchannel("A"))
    stand = union(used(frame) for frame in raw["idle"])
    if (stand[0] - PAD, stand[1], stand[2] - stand[0], stand[3] - stand[1]) != KOBOLD_STAND:
        raise SystemExit(f"the kobold stands at {stand}, not at {KOBOLD_STAND}: this tool measures wrongly")
    _, _, crop = npc_portraits.PORTRAITS["player"]
    him["portrait"] = stacked(raw["idle"], (crop[0] + PAD, crop[1], crop[2] + PAD, crop[3]))
    him["face"] = face
    half = BADGE // 2
    him["badge"] = him["portrait"].crop((HEAD_AT[0] - half, HEAD_AT[1] - half, HEAD_AT[0] + half, HEAD_AT[1] + half))
    return him


def fight_scale(one: dict) -> float:
    """`CombatActor.fit` at a backdrop pixel of 1: half steps, from one to two."""
    return min(2.0, max(1.0, np.floor(FIGHT_TALL / one["stand"][3] / 0.5 + 0.5) * 0.5))


def scaled(image: Image.Image, by: float) -> Image.Image:
    return image.resize((max(1, round(image.width * by)), max(1, round(image.height * by))), Image.NEAREST)


def stood(view: Image.Image, frame: Image.Image, by: float, at: tuple, on: tuple) -> None:
    """`frame` drawn `by` times its size with its own point `at` on the picture's point `on`."""
    drawn = scaled(frame, by)
    # `paste`, not `alpha_composite`, which refuses a corner off the picture; the art's alpha is all or nothing.
    view.paste(drawn, (round(on[0] - at[0] * by), round(on[1] - at[1] * by)), drawn)


def shade(view: Image.Image, middle: tuple, wide: float, alpha: float) -> None:
    """The ellipse under a hero's feet, a quarter as deep as it is wide (`CombatActor.shadow_texture`)."""
    deep = max(2.0, wide / 4)
    over = Image.new("RGBA", view.size)
    ImageDraw.Draw(over).ellipse((middle[0] - wide / 2, middle[1] - deep / 2, middle[0] + wide / 2,
                                  middle[1] + deep / 2), fill=(15, 10, 23, round(255 * alpha)))
    view.alpha_composite(over)


def fight_shadow(one: dict) -> tuple:
    """`CombatActor._lay_shadow`, in the hero's own pixels: how wide, and how far its middle is from the
    middle of the standing box -- under what the first idle frame draws in its bottom quarter."""
    x, y, w, h = one["stand"]
    solid = np.asarray(one["frames"]["idle"][0])[max(0, y + h - max(1, h // 4)):y + h, :, 3] > 0
    columns = np.nonzero(solid.any(axis=0))[0]
    span = (columns.min(), columns.max() + 1) if len(columns) else (x, x + w)
    return max(4, round(min((span[1] - span[0]) * 0.9, h * 1.2))), (span[0] + span[1]) / 2 - (x + w / 2)


def said(view: Image.Image, at: tuple, words: str, colour=(255, 255, 255, 255)) -> None:
    draw = ImageDraw.Draw(view)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        draw.text((at[0] + dx, at[1] + dy), words, fill=(20, 16, 24, 255))
    draw.text(at, words, fill=colour)


def backdrop(width: int) -> Image.Image:
    """A forest at noon, its layers as the fight lays them, repeated to `width` backdrop pixels."""
    area = ROOT / "Assets/Area"
    layers = [area / "sky/noon.png"] + sorted((area / "land").glob("forest_1_*.png")) + [area / "forest_plain_1.png"]
    view = Image.new("RGBA", (width, BACKDROP[1]))
    for path in layers:
        layer = Image.open(path).convert("RGBA")
        for x in range(0, width, layer.width):
            view.alpha_composite(layer, (x, BACKDROP[1] - layer.height))
    return view


def preview_fight(found: list, him: dict) -> None:
    """Every hero in a fight beside the kobold, at the size `CombatActor.fit` gives it, stood by the
    middle of its standing box over the shadow the fight would lay."""
    zoom, slot, across, sky = 2, 130, 6, 46
    rows = [found[i:i + across - 1] for i in range(0, len(found), across - 1)]
    tall = (BACKDROP[1] - sky) * zoom
    sheet = Image.new("RGBA", (slot * across * zoom, tall * len(rows)))
    for r, row in enumerate(rows):
        view = scaled(backdrop(slot * across).crop((0, sky, slot * across, BACKDROP[1])), zoom)
        for i, one in enumerate([him] + row):
            by = fight_scale(one) * zoom
            x, y, w, h = one["stand"]
            ground = ((i + 0.5) * slot * zoom, (BACKDROP[1] * GROUND - sky) * zoom)
            wide, shift = fight_shadow(one)
            shade(view, (ground[0] + shift * by, ground[1]), wide * by, 0.32)
            stood(view, one["frames"]["idle"][0], by, (x + w / 2, y + h), ground)
            said(view, (i * slot * zoom + 6, 4), f"{one['name']}  x{by / zoom:g}  {round(h * by / zoom)} px")
        sheet.paste(view, (0, r * tall))
    sheet.save(QA / "characters_fight.png")


def preview_cards(found: list, him: dict) -> None:
    """Each hero's map token on a tile at the default zoom -- its marked feet on the tile's own foot
    point, over its shadow -- its portrait, its face on the disc and its badge, sixteen to a page."""
    tiles = Image.open(ROOT / "AI-sprites/spritesheet/hex_tileset.png").convert("RGBA")
    tile = scaled(tiles.crop(TILE), MAP_ZOOM)
    wide, tall, per = 356, 218, 16
    everyone = [him] + found
    for page in range(0, len(everyone), per):
        sheet = Image.new("RGBA", (wide * 4, tall * 4), (58, 48, 62, 255))
        for i, one in enumerate(everyone[page:page + per]):
            card = Image.new("RGBA", (wide, tall), (58, 48, 62, 255))
            card.alpha_composite(tile, (4, 4))
            token = TOKEN_TALL / one["stand"][3]
            foot = (4 + tile.width / 2, 4 + tile.height / 2 + TOKEN_FOOT * MAP_ZOOM)
            shade(card, foot, TOKEN_SHADOW * one["stand"][3] * token * MAP_ZOOM, 0.5)
            stood(card, one["frames"]["idle"][0], token * MAP_ZOOM, one["feet"], foot)
            socket = Image.new("RGBA", (PORTRAIT * 2, PORTRAIT * 2), (230, 156, 105, 255))
            socket.alpha_composite(scaled(one["portrait"].crop((0, 0, PORTRAIT, PORTRAIT)), 2))
            card.alpha_composite(socket, (180, 4))
            card.alpha_composite(scaled(one["face"], 4), (180, 114))
            card.alpha_composite(badge(one["badge"]), (274, 120))
            said(card, (4, 200), f"{one['id']}  {one['name']}  token x{token:.2f}  "
                 + "/".join(str(len(one["frames"][anim])) for anim in ANIMATIONS))
            sheet.paste(card, (i % 4 * wide, i // 4 * tall))
        sheet.save(QA / f"characters_cards_{page // per + 1}.png")


def badge(close: Image.Image) -> Image.Image:
    """`MapPointer`'s disc at twice its size: the badge's picture on ink, ringed in gold."""
    ring = 2
    disc = Image.new("RGBA", close.size, (28, 18, 28, 255))
    disc.alpha_composite(close)
    round_mask = Image.new("L", (BADGE + 2 * ring, BADGE + 2 * ring))
    ImageDraw.Draw(round_mask).ellipse((ring, ring, BADGE + ring - 1, BADGE + ring - 1), fill=255)
    out = Image.new("RGBA", round_mask.size)
    ImageDraw.Draw(out).ellipse((0, 0, out.width - 1, out.height - 1), fill=(255, 200, 37, 255))
    lifted = Image.new("RGBA", round_mask.size)
    lifted.paste(disc, (ring, ring))
    out.paste(lifted, (0, 0), round_mask)
    return scaled(out, 2)


def preview_strips(found: list) -> None:
    """Every strip as it would be exported, a line at each cell's edge, six heroes to a page."""
    per = 6
    for page in range(0, len(found), per):
        some = found[page:page + per]
        wide = max(one["size"][0] * max(len(frames) for frames in one["frames"].values()) for one in some)
        tall = sum(one["size"][1] * len(ANIMATIONS) + 16 for one in some)
        sheet = Image.new("RGBA", (wide, tall), (58, 48, 62, 255))
        y = 0
        for one in some:
            said(sheet, (2, y + 2), "%s  %dx%d  at (%d, %d) of its cell, feet at %g"
                 % (one["id"], *one["size"], *one["cell"], one["feet"][0]))
            y += 16
            for anim in ANIMATIONS:
                for i, frame in enumerate(one["frames"][anim]):
                    sheet.alpha_composite(frame, (i * one["size"][0], y))
                    ImageDraw.Draw(sheet).line((i * one["size"][0], y, i * one["size"][0], y + 3), fill=(255, 0, 255))
                y += one["size"][1]
        sheet.save(QA / f"characters_strips_{page // per + 1}.png")


def strip_of(frames: list) -> Image.Image:
    strip = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * frame.width, 0))
    return strip


def export(found: list, him: dict) -> None:
    for one in found:
        out = OUT / one["id"]
        out.mkdir(parents=True, exist_ok=True)
        for anim in ANIMATIONS:
            strip_of(one["frames"][anim]).save(out / f"{anim}.png")
        one["portrait"].save(out / "portrait.png")
        one["face"].save(out / "face.png")
        one["badge"].save(out / "badge.png")
    # The kobold's art stays where it is; his badge alone was only ever a cut the main scene made of his
    # portrait, and every hero's badge is a file now.
    (OUT / "kobold").mkdir(parents=True, exist_ok=True)
    him["badge"].save(OUT / "kobold" / "badge.png")
    print("exported", len(found), "heroes and the kobold's badge to", OUT.relative_to(ROOT))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--export", action="store_true", help="also write Assets/Characters/<id>/")
    args = parser.parse_args()
    # ui_kit's paths are from the project folder.
    os.chdir(ROOT)
    face = ui_kit.character()[0]["ui_char_portrait"]
    found = heroes(face.getchannel("A"))
    him = kobold(face)
    for one in found:
        stand = "" if one["measured"] else ', "stand": Rect2i(%d, %d, %d, %d)' % one["stand"]
        print('\t"%s": {"name": "%s", "frame": Vector2i(%d, %d), "feet": %d%s},'
              % (one["id"], one["name"], *one["size"], round(one["feet"][0]), stand))
    QA.mkdir(exist_ok=True)
    preview_fight(found, him)
    preview_cards(found, him)
    preview_strips(found)
    print("wrote", (QA / "characters_*.png").relative_to(ROOT))
    if args.export:
        export(found, him)


if __name__ == "__main__":
    main()
