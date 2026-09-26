"""Cut the dialogue portraits out of the NPC pack and the hero's own sheet: each speaker's head and
shoulders, every frame of their idle, as one strip for `DialogueBox` to step through.

    python tools/npc_portraits.py

Plain Python with Pillow, no Godot. Run the Godot import after it.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = "Assets/Potential/2D enemies/NPC Pack 2D Pixel Art/Sprites/"
OUT = ROOT / "Assets/NPC"

# speaker -> (sheet, frame width, crop inside a frame). Every frame of a sheet is the same size and
# the speaker stands still in it, so one crop holds for all of them. `player` is the hero, whose box
# puts him on the left (`DialogueBox.PLAYER`).
PORTRAITS = {
    # The enchanter: her hat, face and the hand on her staff, clear of the cauldron's steam.
    "fortuneteller": (PACK + "ENCHANTER.png", 128, (64, 8, 116, 60)),
    # The kobold's own idle (`CombatActor.PLAYER_FRAME`): ears, face, chest and the curl of his tail.
    "player": ("Assets/Player/idle.png", 148, (30, 26, 82, 78)),
}


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for name, (sheet, frame, box) in PORTRAITS.items():
        src = Image.open(ROOT / sheet).convert("RGBA")
        w, h = box[2] - box[0], box[3] - box[1]
        count = src.width // frame
        strip = Image.new("RGBA", (w * count, h))
        for i in range(count):
            strip.alpha_composite(src.crop((i * frame + box[0], box[1], i * frame + box[2], box[3])), (i * w, 0))
        strip.save(OUT / f"{name}.png")
        print(f"{name}: {count} frames of {w}x{h}")


if __name__ == "__main__":
    main()
