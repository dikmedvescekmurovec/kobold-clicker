"""The dungeon's art, cut from Admurin's packs: the cave creatures, Gollux and the cave's layers.

The creature pack draws each animation as a grid of 64 px cells, four across; EnemyRoster wants one
row, so every grid is laid out end to end and its empty trailing cells dropped. Gollux is already
in strips, but all but his idle leave an empty 128 px cell either side of him for effects he never
uses, so only the painted cells are kept. The cave's layers are whole pictures, copied as they are:
1 to 7, numbered from the front. The pack's 0 is all seven put together, a preview, and is left behind.

No arguments writes the preview `tools/qa/cave_dungeon.png` only -- a common, an elite and the boss
standing in the cave at the fight's own proportions -- and prints each creature's frame and crop
for `EnemyRoster`. `--export` writes `Assets/Enemies/<name>/<animation>.png` and
`Assets/Area/cave/<n>.png`. Run the Godot import after it.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "Assets/Potential/Admurin Free"
GALORE = PACK / "Enemy_Galore_I"
GOLLUX = ROOT / "Assets/Bosses/Bosses_Gollux/Gollux"
CAVE = PACK / "Parallax_Backgrounds_Cave"
ENEMIES_OUT = ROOT / "Assets/Enemies"
CAVE_OUT = ROOT / "Assets/Area/cave"
PREVIEW = ROOT / "tools/qa/cave_dungeon.png"
CELL = 64
NEAREST, FARTHEST = 1, 7
GROUND = 0.915  # CombatScene.CAVE_GROUND: where the fighters' feet are, down the view

# name -> (source folder, {animation: grid file}). An animation the pack does not draw is left out.
GRIDS = {
    "Rat": ("Rat", {"idle": "Rat_Idle", "walk": "Rat_Run", "attack": "Rat_Attack",
                    "hurt": "Rat_Hit", "death": "Rat_Death"}),
    # The bat and the skull never land: their flight is how they stand still.
    "Bat": ("Bat", {"idle": "Bat_Fly", "walk": "Bat_Fly", "attack": "Bat_Attack",
                    "hurt": "Bat_Hit", "death": "Bat_Death"}),
    "Pebble": ("Pebble", {"idle": "Pebble_Idle", "walk": "Pebble_Run", "hurt": "Pebble_Hit",
                          "death": "Pebble_Death"}),
    "Spiked Slime": ("Slime", {"idle": "Slime_Spiked_Idle", "walk": "Slime_Spiked_Run",
                               "attack": "Slime_Spiked_Ability", "hurt": "Slime_Spiked_Hit",
                               "death": "Slime_Spiked_Death"}),
    "Crab": ("Crab", {"idle": "Crab_Idle", "walk": "Crab_Run", "attack": "Crab_AttackA",
                      "hurt": "Crab_Hit", "death": "Crab_Death"}),
    "Skull": ("Skull", {"idle": "Bones_SingleSkull_Idle", "walk": "Bones_SingleSkull_Fly",
                        "hurt": "Bones_SingleSkull_Hit", "death": "Bones_SingleSkull_Death"}),
    "Golem": ("Golem/No Armor", {"idle": "Golem_IdleA", "walk": "Golem_Run",
                                 "attack": "Golem_AttackA", "hurt": "Golem_HitA",
                                 "death": "Golem_DeathA"}),
    # It has no death of its own: its armour coming off is the nearest thing the pack draws.
    "Armored Golem": ("Golem/Armored", {"idle": "Golem_Armor_Idle", "walk": "Golem_Armor_Run",
                                        "attack": "Golem_Armor_AttackA", "hurt": "Golem_Armor_Hit",
                                        "death": "Golem_Armor_ArmorBreak"}),
}
STRIPS = {"Gollux": {"idle": "gollux_idle", "walk": "gollux_move", "attack": "gollux_attack_A",
                     "hurt": "gollux_hit"}}


def strip_of(grid: Image.Image) -> Image.Image:
    """A grid's cells in reading order as one row, without the empty ones the grid ends on."""
    cells = [grid.crop((x, y, x + CELL, y + CELL))
             for y in range(0, grid.height, CELL) for x in range(0, grid.width, CELL)]
    while cells and cells[-1].getbbox() is None:
        cells.pop()
    strip = Image.new("RGBA", (CELL * len(cells), CELL))
    for i, cell in enumerate(cells):
        strip.paste(cell, (i * CELL, 0))
    return strip


def painted(strip: Image.Image, side: int) -> Image.Image:
    """A strip without the cells nothing is drawn in."""
    cells = [strip.crop((x, 0, x + side, side)) for x in range(0, strip.width, side)]
    cells = [cell for cell in cells if cell.getbbox()]
    kept = Image.new("RGBA", (side * len(cells), side))
    for i, cell in enumerate(cells):
        kept.paste(cell, (i * side, 0))
    return kept


def creatures() -> dict:
    """name -> {animation: strip}, every creature of the dungeon."""
    found = {}
    for name, (folder, files) in GRIDS.items():
        found[name] = {anim: strip_of(Image.open(GALORE / folder / (file + ".png")).convert("RGBA"))
                       for anim, file in files.items()}
    for name, files in STRIPS.items():
        found[name] = {anim: painted(Image.open(GOLLUX / (file + ".png")).convert("RGBA"), 128)
                       for anim, file in files.items()}
    return found


def bounds_of(strips: dict, frame: int) -> tuple:
    """The part of a frame the creature uses across every animation: EnemyRoster's `bounds`."""
    boxes = [strip.crop((x, 0, x + frame, strip.height)).getbbox()
             for strip in strips.values() for x in range(0, strip.width, frame)]
    boxes = [box for box in boxes if box]
    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    return left, top, max(b[2] for b in boxes) - left, max(b[3] for b in boxes) - top


def lay(view: Image.Image, layers) -> None:
    """Draws those layers of the cave over `view`, at the whole-number scale that covers it."""
    scale = -(-view.height // 216)
    for n in layers:
        layer = Image.open(CAVE / f"{n}.png").convert("RGBA")
        layer = layer.resize((layer.width * scale, layer.height * scale), Image.NEAREST)
        for x in range(0, view.width, layer.width):
            view.alpha_composite(layer, (x, view.height - layer.height))


def stand(view: Image.Image, sprite: Image.Image, tall: float, x: float, mirror: bool) -> None:
    """Stands `sprite` on the fight's ground line, `tall` pixels high, as CombatActor does."""
    sprite = sprite.crop(sprite.getbbox())
    if mirror:
        sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
    factor = tall / sprite.height
    sprite = sprite.resize((round(sprite.width * factor), round(tall)), Image.NEAREST)
    view.alpha_composite(sprite, (round(x - sprite.width / 2), round(view.height * GROUND - sprite.height)))


def preview(found: dict) -> None:
    width, height = 1152, 648
    actor = height * 0.33  # CombatScene.ACTOR_HEIGHT, and SIZE_HEIGHT under it
    hero = Image.open(ROOT / "Assets/Player/idle.png").convert("RGBA").crop((0, 0, 148, 96))
    sheet = Image.new("RGBA", (width, height * 3))
    for row, (name, share) in enumerate([("Rat", 0.45), ("Armored Golem", 1.0 * 1.15), ("Gollux", 1.25)]):
        # The fighters stand behind the nearest rock, as the fight draws them.
        view = Image.new("RGBA", (width, height))
        lay(view, range(FARTHEST, NEAREST, -1))
        stand(view, hero, actor, width * 0.24, False)
        frame = 128 if name in STRIPS else CELL
        stand(view, found[name]["idle"].crop((0, 0, frame, frame)), actor * share, width * 0.72,
              True)
        lay(view, [NEAREST])
        sheet.paste(view, (0, row * height))
    PREVIEW.parent.mkdir(exist_ok=True)
    sheet.save(PREVIEW)
    print("wrote", PREVIEW.relative_to(ROOT))


def export(found: dict) -> None:
    for name, strips in found.items():
        out = ENEMIES_OUT / name
        out.mkdir(parents=True, exist_ok=True)
        for anim, strip in strips.items():
            strip.save(out / f"{anim}.png")
    CAVE_OUT.mkdir(parents=True, exist_ok=True)
    for n in range(NEAREST, FARTHEST + 1):
        shutil.copyfile(CAVE / f"{n}.png", CAVE_OUT / f"{n}.png")
    print("exported", len(found), "creatures and", FARTHEST - NEAREST + 1, "layers")


if __name__ == "__main__":
    all_of_them = creatures()
    for who, its in all_of_them.items():
        side = 128 if who in STRIPS else CELL
        print(f'"{who}": frame ({side}, {side}), bounds {bounds_of(its, side)}, '
              + ", ".join(f"{anim} {strip.width // side}" for anim, strip in its.items()))
    preview(all_of_them)
    if "--export" in sys.argv:
        export(all_of_them)
