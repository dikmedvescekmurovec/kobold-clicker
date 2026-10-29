<!-- Loaded automatically when a file in this folder is read. Rules only: the measurements and the reasoning are in tools/DESIGN.md, which is read on demand. The project overview is in the root CLAUDE.md. -->

## Sprites cut from bought packs (`tools/ui_kit.py`)
The interface is **cut, not generated**, from packs under `Assets/Potential/`. `tools/ui_kit.py` is the one place that says which rectangle of which pack sheet is which sprite and where its nine-slice margins fall; Python with Pillow and numpy, no Godot.
The gear is not cut from a pack either: it is the user's own pixellab art, finished here -- see the item bases' row.
**Read `DESIGN.md` here before adding or re-cutting a sprite** -- it holds the pack layouts, the measured grids and what was tried and turned down.

That row and the rest of the old table are in `DESIGN.md` under "Files in full". How to run each tool is in the root `COMMANDS.md`.

## Files
| File | What it is for |
|---|---|
| `ui_kit.py` | Cuts the interface and the orbs out of the bought packs; finishes the user's pixellab gear, unique, capstone and spell icons. |
| `item_frames.py` | Draws the rarity frames round an item's square: drawn, not cut (the user's design, 2026-10-04). |
| `pixellab_prompts.py` | The pixellab prompts for the item bases (text, not sprites); writes `tools/qa/pixellab_item_prompts.md`. |
| `cave_dungeon.py` | Cuts the dungeon's art out of Admurin's packs: eight creatures, Gollux, the cave's seven layers. |
| `pips.py` | Draws the pips of the fight's kill bar and the bounty boards, lit and spent (the user's design, 2026-10-03). |
| `skill_stones.py` | Carves numerals I to IX into the user's three pixellab stones; draws the tree's 16 px nodes and its root. |
| `npc_portraits.py` | Cuts the dialogue portraits out of the NPC pack, each speaker's idle as one strip for `DialogueBox`. |
| `characters.py` | Cuts the other heroes out of the CraftPix packs: each one's idle, walk and attack, its dialogue portrait, corner face and map badge; prints the rows for `Characters.ROSTER`. |
| `seeing_stone.py` | Draws the Seeing Stone: **unused since 2026-10-03**, when `CaveSense` replaced the stone, and nothing loads its files. |
| `sound_levels.py` | Cuts the sound effects out of `Sounds/Selected/` into `Sounds/Sfx/`, then sets every file's level (`LEVELS`): the mix. |
| `pixel_flatten.py` | Flattens an AI-generated creature's frames to the bought packs' look (one palette across every frame). |
| `web.py` | Exports the web build to `build/web/`; `--deploy` uploads it and deploys the Worker that serves it. |
| `recording.py` | What the Movie Maker recorders share (`GODOT`, `ready`, `viewport`); not a tool of its own. |
| `trailer.py` | Records the hype trailer (`tests/trailer.gd`) with Movie Maker and cuts `build/trailer.mp4`. |
| `reels.py` | Records the upright reels (`tests/reels.gd`) and cuts each to `build/reels/`. |
| `clip_video.py` | Records an upright marketing clip (`tests/<name>_video.gd`) and encodes `build/<name>_video.mp4`. |
| `landing_media.py` | Cuts the landing page's five shorts (four reels and the craft clip) and four stills out of the recorders' frames into `build/landing/`. |
| `check.py` | Parses GDScript with Godot's own checker (`--check-only`): the changed scripts, or `--all`. |

## Rules
A rule's old text is in `DESIGN.md` under "Rules in full", headed by the rule's bold title, unless the rule ends in `(DESIGN.md: "<heading>")`, which names the heading that holds it.

### Running and writing
- **Take `--help` and refuse an unknown argument** in every script (`argparse`): a typo must never start an export, a recording or a deploy. `web.py` exports only; `--deploy` is what uploads and deploys.
- **Write only the preview without `--export`** in `item_frames.py`, `cave_dungeon.py`, `characters.py`, `pips.py`, `skill_stones.py`, `seeing_stone.py`, `pixel_flatten.py` and `landing_media.py` (its preview is `build/landing/`). (DESIGN.md: "Files in full")
- **After cutting, run the Godot import** and commit the `.import` files.
- **Write `Assets/` last:** `ui_kit.py`'s `main` holds every write (`writes`) until all that can refuse a sprite has run; only `tools/qa/` previews are written as it goes.
- **Never read what the build writes:** every source is under `Assets/Potential/` or drawn, so two runs leave `Assets/` byte for byte the same; one read back out of `Assets/Gear` would be outlined again on each run.
- **Share `recording.py` between the recorders** (`trailer.py`, `reels.py`, `clip_video.py`): `GODOT`, `ready` (what a recording needs, asked for before anything is recorded) and `viewport`.
- **Leave a reel's scenario as the user has it** (2026-10-11): re-record a reel or a clip only when asked, or where it comes out exactly the same; otherwise cut from the recording there is. Recording also overwrites the frames and the video, so copy both aside first. (`Scenes/DESIGN.md`: "Landing page (2026-10-11)")
- **Remove `viewport`'s `override.cfg` however the run ends:** it is made only if none is there and git-ignored, and `tests/run_all.py` refuses to run while it exists. (DESIGN.md: "Share `recording.py` between the recorders")

### The theme sheet and its palette
- **Keep a nine-slice's tiled rows and columns one colour:** `check()` re-reads each theme sprite and refuses to export one that is not. Icons and parts skip it: they are drawn, never stretched.
- **Put only theme sprites in `ui_sheet.png` / `ui_sheet.json`:** everything else is a loose file, and `test_ui_theme` counts the sheet exactly.
- **Put `Assets/UI/` into ENDESGA 64** (the user's call, 2026-09-30): `_e64` puts each sprite through `hexlib.to_e64` last, the pack's chrome pinned by hand in `UI_FIXED`; `item_frames.py` and `build_hpbar.py` do the same. The hero's portrait and the gear, orb, skill and spell icons keep their own colours.
- **Play the red title bar and its body off the green ones** through `GREEN_TO_RED`, after the remap. (DESIGN.md: "Put `Assets/UI/` into ENDESGA 64")

### Buttons, panels and marks
- **Swap the green button's palette for every face** (brown, red, pale tan for a dead one), each step's lightness kept; only `ui_btn_light_go_*` is the green itself, for the cream surface (`GO_SURFACES`). The pack's own brown square button is not cut: its gradient face cannot tile.
- **Cut the title bar off its panel:** the pack fixes it at 13 px and Pixellari needs 16; `UITheme.titled_panel` stacks bar over body.
- **Recolour a mark by its surface:** `BONE_RAMP` on a brown face, the pack's brown (`_brown`) bare on the cream, `_green` on an open tab.
- **Cut a mark that stands on theme art at scale 1, centred on one `ICON_SIDE` square.** One no pack draws is written into `ICONS_DRAWN` in `ICON_KEY`'s five shades and goes through the same recolour. (DESIGN.md: "Recolour a mark by its surface")
- **Shade a drawn silhouette with `_edged`, the corner marks' rule** (`SLOT_MARKS`, `char_marks`). (DESIGN.md: "ui_kit.py")
- **Keep `notch_places` the same arithmetic as `UITheme.notched`** (`NOTCH_*`). (DESIGN.md: "ui_kit.py")
- **Cut the keys (`KEYS`, `LETTERS`) at their own size, in ENDESGA 64 like the rest:** they stand on cream, not on a button. (DESIGN.md: "ui_kit.py")
- **Keep every item frame 40 wide and `HEAD` (4) taller than the square:** nothing may stand past the sides. (DESIGN.md: "item_frames.py")
- **Cut only the white colourway of the loot beam:** `modulate` multiplies, so white times a rarity colour is that colour.

### Gear, unique and skill icons
- **End every gear icon in one outline (`_outlined`):** every opaque pixel that touches clear is ink (`OUTLINE_INK`), one pixel thick. `base_gear()` refuses an icon with under `OUTLINE_FLOOR` (0.97) of its edge in ink, and `qa.py gear` counts the same.
- **Put every base and unique icon through `_paletted`,** after the outline and before the checks: each colour to its nearest in `hexlib.PALETTE`, every edge pixel its `ink`, alpha never touched. Neighbours more than `PALETTE_KEEP_APART` apart in lightness are never merged, and a torch's glow is drawn after.
- **Append a ramp to `hexlib.PALETTE`, never insert one** (it has no dark purple, if that ever matters). (DESIGN.md: "Put every base and unique icon through `_paletted`")
- **Allow no doubled art in a base:** `_doubled` (every 2x2 block one colour) stops the build.
- **Let no recolour pass `GREY_CEILING` (0.88):** both halves of `_shift` clamp to it.
- **Never recolour a whole sprite, or a tier:** `_shift` moves a band of hues, by part, and a tier is a more intricate drawing. (DESIGN.md: "ui_kit.py")
- **Finish a pixellab base in order:** `_plugged` (`BASE_HOLE_MOST`), `_filled` (`BASE_FILL`), then `_outlined(own_edge=True)`, which repaints its own outline where it stands: a ring added outside would not fit 32. (DESIGN.md: "ui_kit.py")
- **Put no saturation ceiling on a pixellab piece** (the user's call, 2026-09-30), and no glow round a unique's fire, which would smudge its black outline in the log. (DESIGN.md: "ui_kit.py")
- **Point every dagger to the bottom-left, away from the swords** (`BASE_TRANSPOSE`). (DESIGN.md: "ui_kit.py")
- **Mark a base with no art `MISSING`** until its pixellab tuple lands; base and unique icons are written while `BASES_EXPORT` and `UNIQUE_EXPORT` are on (they are). (DESIGN.md: "ui_kit.py")
- **Keep writing what a pixellab piece replaced** to the `Old/` folders (`BASE_OLD`, `UNIQUE_OLD`, `UNIQUE_OLD_DRAWN`), for the dev tick "Show old icons". (DESIGN.md: "ui_kit.py")
- **Name a base's icon by `LootTable.KINDS`' tier name, apostrophes and all,** and a unique's by its `UniqueTable` id. (DESIGN.md: "ui_kit.py")
- **Tint a capstone's badge by its node's base** (`SKILLS`, `SKILL_TINTS`; since 2026-10-09). (DESIGN.md: "ui_kit.py")

### Pixellab prompts
- **Write a pixellab prompt in `tools/pixellab_prompts.py`,** the source of every base prompt, after reading `DESIGN.md`'s "Pixellab prompts for gear icons (2026-09-23)".
- **Never put into a prompt** an item's name, a comparison, the word "outline", black, a body word in a helmet, or a colour word that names a thing ("bone white" drew bones); colour words come only from the user's colour charts. (DESIGN.md: "Lessons")
- **Work one kind at a time from a piece the user picks,** tied to its tier's measured colours; judge on the real doll, and change one line between tries. (DESIGN.md: "Lessons")

### Dungeon art, pips, stones and portraits
- **Give every dungeon creature frame the hero's outline** (`INK`, `outlined`), each animation laid out as the one row `EnemyRoster` wants. Of Gollux's strips only the painted cells are kept, and `GROUND` is `CombatScene.CAVE_GROUND`. (DESIGN.md: "cave_dungeon.py")
- **Draw the pips, never cut them** (the user's design, 2026-10-03): every sprite `WIDTH` (9) across with the round one centred, and `spent` one step above the ink, so a dead skull keeps its face. (DESIGN.md: "pips.py")
- **Carve a numeral with every stroke straight** (one stepped sideways read as a Z), in shades taken from the whole stone's lightness (`DEEP`, `DARK`, `LIGHT`), the user's approved look. (DESIGN.md: "skill_stones.py")
- **Snap a 16 px node back onto the stone's own colours, its outer ring the darkest** (`small`), so the outline stays one pixel. Capstone badges are not drawn small: at 16 px they are mush. (DESIGN.md: "skill_stones.py")
- **Cut every portrait `HEIGHT` (52, `DialogueBox.PORTRAIT_HEIGHT`) tall,** one crop for every frame of the idle. The user's picks stay: `player`'s 52 px crop, head to the curl of his tail, and `blacksmith` 68 wide to keep his anvil, cut at the anvil's top. (DESIGN.md: "npc_portraits.py")
- **Cut a hero's three strips to one crop, facing right, a clear pixel round every cell** (`characters.py`), split at the clear column nearest each cell's edge; a cut that loses a pixel stops the tool. Never rename an id in `CHARACTERS`: a save holds it. (DESIGN.md: "characters.py")
- **Take a hero's `feet` from the user's marks** (2026-10-11), and cut its corner face and its map badge round one point at one `zoom`, the badge only wider: the user's rule that the two show the same face. The dialogue portrait moves on its own (`portrait`). (DESIGN.md: "characters.py")

### Sound
- **Tune the mix in `LEVELS`, never in a player:** no `AudioStreamPlayer` in the game sets a volume, and a sound added to the game gets a line there. (DESIGN.md: "sound_levels.py")
- **Start a cut at its sound's onset, not the silence before it** (`CUTS`), and delete a cut whose window changed: it is rendered again only when it is off its level. (DESIGN.md: "sound_levels.py")
- **Level music by integrated LUFS (-25, the user's ask, 2026-10-02) and everything else by its loudest 400 ms,** in place in the same codec, rate and bitrate. A file within 0.5 dB is left alone, and a spike at the -1 dBTP ceiling is not raised again. (DESIGN.md: "sound_levels.py")

## Gotchas
- **Measure each `Icons.png` entry:** its rows are not evenly spaced, so each entry's y and height are that icon's measured extent.
- **Centre orbs on an even offset:** `OrbSlot` draws them at half size, and an odd offset loses a column.
- **Give `_shift`'s grey tuple its third number, a lightness multiplier:** without it an iron piece and a steel one come out the same value. (DESIGN.md: "Let no recolour pass `GREY_CEILING` (0.88)")
- **Do not copy the cave pack's `0.png` as a layer:** it is a preview of all seven put together, and hid the rest when it was drawn as one. (DESIGN.md: "cave_dungeon.py")
- **Run the screenshot scripts before `pips.py`'s preview,** which is put into their pictures. (DESIGN.md: "pips.py")
- **Keep the cuts at Vorbis quality 8** (at 5 a quiet, noisy pick drifted past the tolerance on every re-level), each rendered at its level from its pick in one encode (`make`): raising a file in place stopped at its peak. (DESIGN.md: "sound_levels.py")
- **Run a cut's filter first where it carries one:** without the jewel drop's gate its level raised the pick's hiss. (DESIGN.md: "sound_levels.py")
- **Have ffmpeg on the path;** `sound_levels.py` skips a file another program holds open. (DESIGN.md: "sound_levels.py")
