"""Cut the dialogue portraits out of the NPC pack and the hero's own sheet: each speaker's head and
shoulders, every frame of their idle, stacked top to bottom as one strip for `DialogueBox` to step
through. Every portrait is `HEIGHT` tall, so every box stands the same height; how wide one is, is
the speaker's own (the smith keeps his anvil).

    python tools/npc_portraits.py

Plain Python with Pillow, no Godot. Run the Godot import after it.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = "Assets/Potential/2D enemies/NPC Pack 2D Pixel Art/Sprites/"
OUT = ROOT / "Assets/NPC"
# `DialogueBox.PORTRAIT_HEIGHT`: a frame's height, which is how the box finds the frames in a strip.
HEIGHT = 52

# speaker -> (sheet, frame width, crop inside a frame). Every frame of a sheet is the same size and
# the speaker stands still in it, so one crop holds for all of them. `player` is the hero, whose box
# puts him on the left (`DialogueBox.PLAYER`).
PORTRAITS = {
    # The enchanter: her hat, face and the hand on her staff, clear of the cauldron's steam.
    "fortuneteller": (PACK + "ENCHANTER.png", 128, (64, 8, 116, 60)),
    # The kobold's own idle (`CombatActor.PLAYER_FRAME`): ears, face, chest and the curl of his tail.
    "player": ("Assets/Player/idle.png", 148, (30, 26, 82, 78)),
    # The smith and his anvil (the user's ask), from his hat to the anvil's top: his boots and its
    # foot are cut to keep him at `HEIGHT`, the sparks off the anvil are kept.
    "blacksmith": (PACK + "BLACKSMITH.png", 96, (9, 22, 77, 74)),
}


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for name, (sheet, frame, box) in PORTRAITS.items():
        src = Image.open(ROOT / sheet).convert("RGBA")
        w, h = box[2] - box[0], box[3] - box[1]
        assert h == HEIGHT, f"{name} is {h} tall, not {HEIGHT}"
        count = src.width // frame
        strip = Image.new("RGBA", (w, h * count))
        for i in range(count):
            strip.alpha_composite(src.crop((i * frame + box[0], box[1], i * frame + box[2], box[3])), (0, i * h))
        strip.save(OUT / f"{name}.png")
        print(f"{name}: {count} frames of {w}x{h}")


if __name__ == "__main__":
    main()
