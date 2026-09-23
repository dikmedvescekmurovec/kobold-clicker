"""The pixellab prompts for the item bases, as used on 2026-09-23 -- the source of truth for them.

Run from the project folder: `python tools/pixellab_prompts.py` writes every prompt to
`tools/qa/pixellab_item_prompts.md`. How they were found, and the rules they keep, are in
tools/DESIGN.md, *Pixellab prompts*. Older palettes (t1..t5, b1..b5) are kept where a piece that is
already drawn was made from them.
"""
# The item bases' pixellab prompts, one kind at a time. Helmets first: the leather helmet the user chose
# (Assets/Potential/Bases/Leather Helmet.png) sets the shape, and every material after it keeps that
# shape word for word and adds one sturdier part.

# Every helmet's outline, the same words in every prompt so the five read as one helmet at five strengths.
HELM_SHAPE = ("Shape: a rounded dome with a seam down the middle, a band round the brow, and long side "
              "flaps that hang down well below the brow band and flare outward at the bottom; the face is a dark open gap between "
              "the flaps.")
POSE = {
 "HELM": "Front view, turned slightly to the left: the face opening sits a little left of centre and more of the right side flap shows.",
 "BODY": ("Front view, turned slightly to the left, standing upright as if on an armour stand; "
          "more of the right shoulder shows."),
}
PAL = {
 "leather": "warm brown #80553a, grey-brown #706050, burlap tan #a09080",
 "iron": "warm grey #847767 and pale steel #a6aabb on the iron, warm brown #80553a on the leather",
 "steel": "pale steel #a6aabb and #cfd3de, slate #565a6e",
 "gold": "pale steel #a6aabb, slate #565a6e, dull gold #b2984e and #cba952 only on the gold parts",
 "master": "dark charcoal steel #34374a and #565a6e, pale grey #a6aabb only on the bevelled edges, dark crimson #7a2a36 and #923a35 only on the cloth and the eye glow",
 "master_plate": ("very dark charcoal steel #34374a and #565a6e, pale grey #a6aabb only on the thin bevelled edges, "
                  "dark crimson #7a2a36 only on the strips of cloth"),
}
# The helmets, written again (2026-09-23) to match the body and greaves of their tier as they came back: each
# tier's colours measured off its Wooden Armor / Leather Boot, Iron Armor / Iron Greaves and so on, named in chart
# words. The shape line and the view are the first helmets', which the user liked; the size line is new, because
# the first helmets were denser than the bodies and boots beside them on the doll.
HELM_SIZE = "The helmet fills about 26 of the 32 pixels in height, centred, with clear space all round."
PAL.update({
 "h1": ("tan orange leather #d16e2b and #a54919, bronze #8a4427, apricot highlights #d9985a, dark brown shadows "
        "#55291b and #463328"),
 "h2": ("iron grey #5e5c60 and #444851, slate #70747f, light grey highlights #a6a8ae, reddish brown leather #7f3b2e and "
        "#57261b, dark brown shadows #441b14"),
 "h3": ("grey-brown steel #725138 and #5e422d, pale steel highlights #a1a6a2 and #c6b099, bronze leather #7c4421 and "
        "#a35e33, dark brown shadows #4a2e1f"),
 "h4": ("lilac grey steel #a09eb9 and #847d9d, dusky plum shadows #5e4473 and #3e2052, tan orange trim #e74408, bright "
        "gold highlights #f59803 and #fdde36"),
 "h5": ("navy steel #222c4d and #1d1f3f, slate #3f5663 and #567079, dusty blue highlights #839db1, light grey edges "
        "#bbc4cc"),
})
HELM_LOOK = {
 "h1": ("Look: warm leather, tan orange on the upper-left of every rounded part, bronze in the middle tones and dark "
        "brown in the shadows; stitched seams drawn as short dark dashes."),
 "h2": ("Look: cool iron grey, light grey along the upper-left of every curve and slate in the shadows, set against "
        "reddish brown leather; rivets as single light dots."),
 "h3": ("Look: warm grey-brown steel with pale steel highlights along the upper-left edges and dark brown in the "
        "shadows, strapped with bronze leather; plates overlapping in clear steps, rivets as single light dots."),
 "h4": ("Look: cool lilac grey steel with dusky plum in the shadows, trimmed with tan orange that shines bright gold at "
        "its highlights."),
 "h5": ("Look: dark navy steel, slate and dusty blue on the faces the light reaches, navy in the shadows, a thin light "
        "grey highlight along every bevelled edge, and no other colour."),
}
# The helmet is empty: a dark face opening under a grey dome read as a head (the Iron Helmet came back as skulls,
# 2026-09-23), so it is said outright, without naming what it must not be.
OPEN_FACE = ("An empty helmet with nothing inside it: the face opening is plain dark shadow. Nothing across the face: "
             "no visor, no bars, no strap.")
NOSE_GUARD = "A short, narrow nose guard hangs from the brow band down the middle of the face; nothing else crosses it."
ITEMS = [
 ("Helmets", [
  ("Leather Helmet", "HELM", "h1",
   "A soft leather helmet: a padded leather cap with a stitched seam down the middle of the dome, a thicker stitched "
   "leather band round the brow, and long leather side flaps.\n"
   + HELM_LOOK["h1"] + "\n" + HELM_SHAPE + "\n" + HELM_SIZE + "\n" + OPEN_FACE),
  ("Iron Helmet", "HELM", "h2",
   "An iron-capped helmet: a plain rounded iron cap with a raised ridge down the middle, riveted to a thick reddish brown "
   "leather brow band, with long reddish brown leather side flaps.\n"
   + HELM_LOOK["h2"] + "\n" + HELM_SHAPE + "\n" + HELM_SIZE + "\n" + OPEN_FACE),
  ("Steel Helm", "HELM", "h3",
   "A steel helmet: a grey-brown steel dome with a raised ridge down the middle, a riveted steel brow band, and side "
   "flaps of three overlapping steel plates held by a bronze leather strap.\n"
   + HELM_LOOK["h3"] + "\n" + HELM_SHAPE + "\n" + HELM_SIZE + "\n" + NOSE_GUARD),
  ("Golden Helm", "HELM", "h4",
   "A steel helmet trimmed in tan orange and bright gold: a lilac grey steel dome with a raised tan orange ridge down "
   "the middle, a tan orange brow band with rivets, and side flaps of three overlapping steel plates with bright gold "
   "edges.\n"
   + HELM_LOOK["h4"] + "\n" + HELM_SHAPE + "\n" + HELM_SIZE + "\n" + NOSE_GUARD),
  ("Masterwork Helm", "HELM", "h5",
   "A masterwork helmet of dark navy steel, heavy and angular: a dome of broad flat faceted plates with a crown of short "
   "pointed spikes along the top, a thick brow band whose edge dips into a sharp V at the front, and side flaps of "
   "three broad angular plates, every plate with a thin bevelled edge. The side flaps flare outward past the width of "
   "the dome at the bottom.\n"
   + HELM_LOOK["h5"] + "\n" + HELM_SHAPE + "\n" + HELM_SIZE + "\n"
   "No bars or visor: the face opening is dark navy shadow, crossed only by the point of the brow's V."),
 ]),
]

# Body armour: plate first. A body of a tier has to feel exactly like the helmet of the same tier, so each
# subject repeats that helmet's material words and palette (leather helmet = wooden armour, iron = iron, steel =
# steel, golden = golden, masterwork = masterwork). The build is the one the user liked in the first run's wooden,
# iron and golden pieces; steel and masterwork came back as other builds and are told this one outright.
NO_BODY = "Only the empty armour: no arms, no head, no person inside it."
# The steel set follows the Steel Helm as it came back (2026-09-23, the user's call): neutral grey steel with cool
# pale highlights, bronze and warm brown leather, pale tan buckles -- measured off Assets/Potential/Bases/Steel Helm.png.
PAL["s3"] = ("neutral grey steel #757a76 and #504c4e, pale steel highlights #a6b6ba and #d9eff7, bronze leather #93572e "
             "and #ad6f48, warm brown #825d4a, dark brown shadows #5a392a and #652a11, pale tan #ede0b9 and #c1b298 only "
             "on the buckles and rivets")
STEEL_LOOK = ("Look: cool neutral grey steel, pale steel highlights along the upper-left edges and iron grey in the "
              "shadows, strapped and belted with bronze leather that turns dark brown in its folds; buckles and rivets "
              "as small pale tan dots; plates overlapping in clear steps.")
# The user cannot give pixellab a reference image, so the likeness to each tier's helmet is written out: the
# helmet's own colours, measured off its file (the palettes the helmets were asked for are not what came back),
# and its look in words. Every piece of a tier, whatever its kind, takes that tier's palette and look.
PAL.update({
 "t1": "rust-orange #aa5526 and #953e22, bright orange highlights #f5a24e, deep red-brown shadows #6c2119 and #4e2d1f",
 "t1_wood": ("natural wood browns #80553a, #a6754b and #5c3b2b, pale wood highlights #c39a61, dark brown grain "
             "#3a2521, rust-brown leather #953e22 and #6c2119 only on the straps and belt"),
 "t2": ("neutral grey iron #858382 and #71716f, pale grey highlights #a3a2a0 and #d5d4d3, dark grey shadows #454544, "
        "reddish-brown leather #9b6247, #7f4336 and #6e352f"),
 "t3": "warm grey steel #958980, light steel highlights #b9b6b1, bronze-brown #7a6144, dark brown shadows #3c2410",
 "t4": ("cool lavender-grey steel #bcc7e2, #8380ad and #736b9e, orange gold #b5602e and #d98435 with bright gold "
        "highlights #f6b62b, deep plum shadows #532630 and #472236"),
 "t5": ("dark slate steel with a teal tint #26313a and #3b5154, grey #545857, pale bone highlights #9c9a89 and #f0f3e0 "
        "only on the bevelled edges, dark crimson #4d0c1c only on the cloth, dark grey shadows #2f3236"),
})
LOOK = {
 "t1": ("Look: warm and soft, all rust-orange, with a bright orange highlight on the upper-left of every rounded part "
        "and deep red-brown in the shadows; stitched seams drawn as short dark dashes."),
 "t2": ("Look: plain neutral grey iron, a near-white highlight along the upper-left of every curve and dark grey on "
        "the right, set against reddish-brown leather; rivets as single light dots."),
 "t3": ("Look: warm, slightly brownish grey steel, light highlights along the upper-left edges and dark brown in the "
        "shadows, with bronze-brown in the deepest parts; plates overlapping in clear steps, rivets as single light dots."),
 "t4": ("Look: pale cool steel with a lavender tint and deep plum shadows, trimmed with orange gold that shines bright "
        "yellow at its highlights."),
 "t5": ("Look: very dark slate steel with a faint teal tint and dark grey shadows, a thin bone-white highlight along "
        "every bevelled edge, and dark crimson only in the cloth."),
}
PLATE_SHAPE = ("Shape: a breastplate shaped to a chest, broad at the shoulders and narrowing to the waist, a big "
               "rounded shoulder guard on each side, an opening at the neck, a belt, and a short skirt of overlapping "
               "bands below it; the armour fills the canvas, nearly as wide as it is tall.")
ITEMS.append(("Plate armour", [
  # The wood in natural browns, not the leather helmet's orange (the user's call); that rust leather stays on the
  # straps and belt, which is what ties the piece to its tier.
  ("Wooden Armor", "BODY", "t1_wood",
   "A wooden armour of plain brown wood with rust-brown leather straps: a chest of upright wooden slats laced "
   "together side by side with leather thongs, a thick stitched leather strap over each shoulder holding a rounded "
   "wooden shoulder guard, and a skirt of short wooden slats hanging from a stitched leather belt.\n"
   "Look: natural brown wood, never orange: mid wood brown with pale tan highlights along the upper-left edge of "
   "each slat and dark brown in the grain and the shadows; only the straps, thongs and belt are the rust-brown of a "
   "stitched leather helmet, their seams drawn as short dark dashes.\n"
   + PLATE_SHAPE + "\n" + NO_BODY),
  ("Iron Armor", "BODY", "t2",
   "An iron breastplate, one step sturdier than a wooden one: plain neutral grey iron, never dark and never brown, "
   "with a raised ridge down the middle and rows of rivets along its edges, rounded iron shoulder guards, a thick "
   "reddish-brown leather belt, and a skirt of short reddish-brown leather strips.\n"
   + LOOK["t2"] + "\n" + PLATE_SHAPE + "\n" + NO_BODY),
  ("Steel Plate", "BODY", "s3",
   "A steel plate armour: a neutral grey steel breastplate with a raised ridge down the middle, big rounded shoulder "
   "guards of three overlapping steel plates each held on by bronze leather straps, a bronze leather belt with a pale "
   "tan buckle, and a skirt of three overlapping steel bands.\n"
   + STEEL_LOOK + "\n" + PLATE_SHAPE + "\n" + NO_BODY),
  ("Golden Plate", "BODY", "t4",
   "A steel plate armour trimmed in gold, one step grander than a plain steel one: pale cool steel with a raised gold "
   "ridge down the middle, big rounded shoulder guards of three overlapping steel plates edged in gold, a gold belt "
   "with rivets, and a skirt of three overlapping steel bands with gold edges.\n"
   + LOOK["t4"] + "\n" + PLATE_SHAPE + "\n" + NO_BODY),
  ("Masterwork Plate", "BODY", "t5",
   "A masterwork plate armour, the finest of its line and the grimmest: very dark slate steel, heavy and angular, a "
   "breastplate of broad flat faceted plates with a raised ridge down the middle, huge angular shoulder guards each "
   "crowned with two short pointed spikes, a collar whose edge dips into a sharp V at the neck, and a skirt of three "
   "broad angular plates. Every plate has a thin bevelled edge; dark crimson cloth shows only in thin strips at the "
   "neck and between the skirt plates, never on the plates themselves.\n"
   "The shoulder guards are the widest part of the armour, like every plainer armour of this line.\n"
   + LOOK["t5"] + "\n" + PLATE_SHAPE + "\n" + NO_BODY),
]))

# Boots: a pair, the plate recipe again -- one outline a kind, a tier's measured helmet colours (the hex palette)
# and its look. Colour words are the chart names only (tools/DESIGN.md, *Colour names come from the charts*);
# where a helmet's colour has no chart name the nearest is used and a new chart has been asked for. A pair is a side
# pair as in the user's reference (2026-09-23): side by side from the front-left, toes to the lower left.
POSE["BOOT"] = ("A pair standing side by side, seen from the front and a little from the left and above: both toes "
                "point down and to the lower left; the left boot stands a little lower and in front, the right boot a "
                "little higher and behind it, overlapping it by about a third; together the pair runs from the top of "
                "the canvas to the bottom and is a little taller than it is wide.")
NO_LEG = "A pair of matching boots: no legs, no feet, no person inside them."
GREAVES_SHAPE = ("Shape: each armoured boot is tall and slim: a curved shin plate rising to just below the knee and "
                 "ending in a wide knee guard that flares outward with a point at the front, a narrow ankle, a short "
                 "foot of overlapping plates with a rounded toe, and a low heel.")
BOOT_SHAPE = ("Shape: each boot is tall and slim: the shaft rising to just below the knee and ending in a wide "
              "folded-over cuff that flares outward with a point at the front, a narrow ankle, a short foot with a "
              "rounded toe, a low heel and a separate darker sole.")
PAL.update({
 "t3_leather": ("taupe leather #7a6144, dark brown shadows #3c2410, pale steel #958980 and #b9b6b1 only on the "
                "toe caps and buckles"),
 "t4_leather": ("plum brown leather #532630 and #472236, lavender grey highlights #8380ad and #bcc7e2, copper #b5602e with "
                "bright gold highlights #f6b62b only on the buckles"),
 # The masterwork follows the Masterwork Plate, the best of that set (the user's call): navy and blue slate with
 # pale grey edges and no crimson, measured off Assets/Potential/Bases/Masterwork Plate.png.
 "t5_leather": ("navy leather #222c4d and #15203d, slate plates #3f5663 and #567079, light grey stitching #9daa9b and "
                "#cad4b9 only on the edges, navy shadows #1a2134"),
})
# The tier palettes again, the same measured hex, named in chart words only.
PAL.update({
 "b1": "warm brown #aa5526 and #953e22, apricot highlights #f5a24e, dark brown shadows #6c2119 and #4e2d1f",
 "b2": ("neutral grey iron #858382 and #71716f, light grey highlights #a3a2a0 and #d5d4d3, iron grey shadows #454544, "
        "warm brown leather #9b6247, #7f4336 and #6e352f"),
 "b3": "grey-brown steel #958980, pale steel highlights #b9b6b1, taupe #7a6144, dark brown shadows #3c2410",
 "b4": ("lavender grey steel #bcc7e2, #8380ad and #736b9e, copper #b5602e and #d98435 with bright gold highlights "
        "#f6b62b, plum brown shadows #532630 and #472236"),
 "b5": ("navy steel #222c4d and #15203d, slate #3f5663 and #567079, light grey highlights #9daa9b and #cad4b9 only "
        "on the bevelled edges, navy shadows #1a2134"),
})
BOOT_LOOK = {
 "t1": ("Look: warm brown leather, apricot where the light falls on the upper-left of every rounded part and "
        "dark brown in the shadows; stitched seams drawn as short dark dashes."),
 "t2": ("Look: plain neutral grey iron, light grey along the upper-left of every curve and iron grey on the right, "
        "set against warm brown leather; rivets as single light dots."),
 "t3": ("Look: grey-brown steel, pale steel along the upper-left edges and dark brown in the shadows, with taupe in "
        "the deepest parts; plates overlapping in clear steps, rivets as single light dots."),
 "t4": ("Look: lavender grey steel with plum brown in the deepest shadows, trimmed with copper that shines bright gold at "
        "its highlights."),
 "t5": ("Look: dark navy steel, slate on the faces the light reaches and navy in the shadows, a thin light grey "
        "highlight along every bevelled edge, and no other colour."),
 "t3_leather": ("Look: tough taupe leather with dark brown shadows and a light grey highlight along the upper-left "
                "of each fold; the toe caps and buckles in pale steel."),
 "t4_leather": ("Look: supple plum brown leather, lavender grey highlights along the upper-left edges and plum brown in "
                "the deepest shadows; the copper buckles shine bright gold at their highlights."),
 "t5_leather": ("Look: dark navy leather, slate on the folds the light reaches and navy in the shadows, a thin light "
                "grey stitched edge on every panel, slate plates, and no other colour."),
}
# The user's working assumption (2026-09-23, details later): tier one is one piece a slot, and from tier two every
# slot has a strength piece (armour, the metal line) and a dexterity piece (dodge, the leather line). So the boots
# are the Leather Boot alone, then greaves and leather boots side by side; the Bronze Greaves have no place.
ITEMS.append(("Boots: tier 1", [
  ("Leather Boot", "BOOT", "b1",
   "A pair of soft leather boots in warm brown and rust orange: smooth stitched leather, a folded-over cuff at the "
   "top, and a thin leather tie round each ankle.\n"
   + BOOT_LOOK["t1"] + "\n" + BOOT_SHAPE + "\n" + NO_LEG),
]))
ITEMS.append(("Boots: strength", [
  ("Iron Greaves", "BOOT", "b2",
   "A pair of iron armoured boots: plain neutral grey iron plates over "
   "the shin, knee and foot with rows of rivets, strapped on with warm brown leather straps and buckles, and a warm "
   "brown leather cuff at the top.\n"
   + BOOT_LOOK["t2"] + "\n" + GREAVES_SHAPE + "\n" + NO_LEG),
  ("Steel Greaves", "BOOT", "s3",
   "A pair of steel armoured boots: neutral grey steel, a shin plate with a raised ridge down the front, a round knee "
   "plate, three overlapping steel bands over the foot, and bronze leather straps with pale tan buckles at the ankle "
   "and below the knee.\n" + STEEL_LOOK + "\n" + GREAVES_SHAPE + "\n" + NO_LEG),
  ("Golden Greaves", "BOOT", "b4",
   "A pair of steel armoured boots trimmed in gold: lavender grey steel, a "
   "shin plate with a raised copper ridge down the front, a round knee plate edged in copper, three overlapping steel "
   "bands over the foot with copper edges, and a copper strap at the ankle.\n"
   + BOOT_LOOK["t4"] + "\n" + GREAVES_SHAPE + "\n" + NO_LEG),
  ("Masterwork Greaves", "BOOT", "b5",
   "A pair of masterwork armoured boots, finely made, heavy and grim: dark navy steel, heavy and "
   "angular, a shin plate of broad flat faceted plates with a raised ridge down the front, an angular knee plate "
   "crowned with one short pointed spike, and three broad angular plates over the foot ending in a pointed toe cap. "
   "Every plate has a thin bevelled edge.\n"
   + BOOT_LOOK["t5"] + "\n" + GREAVES_SHAPE + "\n" + NO_LEG),
]))
ITEMS.append(("Boots: dexterity", [
  ("Studded Boot", "BOOT", "b2",
   "A pair of studded leather boots: warm brown leather with rows of small "
   "neutral grey iron studs down the shaft and round the cuff, and an iron-buckled strap at each ankle.\n"
   + BOOT_LOOK["t2"] + "\n" + BOOT_SHAPE + "\n" + NO_LEG),
  ("Ranger's Boot", "BOOT", "t3_leather",
   "A pair of ranger's boots: tough taupe leather laced up the front with a "
   "leather cord, a wide folded cuff, a pale steel toe cap and a pale steel buckle at each ankle.\n"
   + BOOT_LOOK["t3_leather"] + "\n" + BOOT_SHAPE + "\n" + NO_LEG),
  ("Shadow Boot", "BOOT", "t4_leather",
   "A pair of shadow boots: supple plum brown leather, a soft folded cuff, a "
   "slightly pointed toe, and two thin straps with copper buckles on each boot.\n"
   + BOOT_LOOK["t4_leather"] + "\n" + BOOT_SHAPE + "\n" + NO_LEG),
  ("Masterwork Boot", "BOOT", "t5_leather",
   "A pair of masterwork leather boots, finely made, heavy and grim: stiff dark navy leather in "
   "angular panels, small slate plates on the knee and the toe with one short pointed spike each, and a high cuff "
   "whose edge dips into a sharp V.\n"
   + BOOT_LOOK["t5_leather"] + "\n" + BOOT_SHAPE + "\n" + NO_LEG),
]))


# The top materials are the finest of their line and should look it: the same dusty set, but polished.
# Without this the golden and masterwork helms came out duller than the steel one (2026-09-23).
SHINE = {"h4": "the tan orange and bright gold parts", "h5": "the thin light grey edges",
         "gold": "the gold parts", "master": "the pale bevelled edges", "t4": "the gold parts", "t5": "the thin bone-white edges",
         "b4": "the copper and bright gold parts", "b5": "the thin light grey edges"}
# The leather line's top two: finer leather rather than polished metal.
SHINE_LEATHER = {"t4_leather": "the copper buckles", "t5_leather": "the light grey stitched edges"}


def prompt(pose, pal, subject):
    muted = ("Muted, dusty, faded colours like an old hand-painted item sheet; warm browns and greys dominate, "
             "every colour greyed down, never pure or bright.")
    light = "Soft light from the top-left, 2-3 shades per material, a single highlight pixel on metal."
    if pal in SHINE_LEATHER:
        muted = ("Muted, dusty colours, but finely made: supple oiled leather with bright highlights and deep shadows, "
                 f"{SHINE_LEATHER[pal]} clearly catching the light.")
        light = "Soft light from the top-left, 3-4 shades per material, a soft highlight along each seam and edge."
    if pal in SHINE:
        # Said on its own terms: pixellab sees one prompt and nothing else, so "finer than steel" means nothing.
        muted = ("Muted, dusty colours, but polished: bright highlights and deep shadows, "
                 f"{SHINE[pal]} clearly catching the light.")
        light = "Soft light from the top-left, 3-4 shades per material, a bright highlight along each ridge and rim."
    # No outline line: pixellab's Outline setting draws its own, and `_outlined` repaints it in ink anyway.
    # A helmet carries its own size line (HELM_SIZE), which this one would contradict.
    margin = [] if pose == "HELM" else ["Object fills most of the canvas with a 2-3 pixel margin, centred."]
    return "\n".join([subject,
     "Single game inventory icon, 32x32 pixel art in the style of a classic fantasy RPG item pack.",
     POSE[pose]] + margin + [
     "A plain, common item: simple shapes and a clean readable silhouette, no engraving, no decoration, no gems or trim beyond what is named.",
     muted,
     f"Palette: {PAL[pal]}, pale cream highlights #faedb1.",
     light,
     "No text, no background, no shadow, no frame."])


out = ["# Pixellab prompts: item bases", "",
 "Settings: 32x32, transparent background on, Direction and View None, Single color outline; the advanced model. "
 "Make a kind's first piece first and pick one; the others are written to match it in words.",
 "Save each as `Assets/Potential/Bases/<its heading>.png`. The Masterwork names are placeholders.", ""]
n = 0
for group, items in ITEMS:
    out += [f"## {group}", ""]
    for name, pose, pal, subject in items:
        out += [f"### {name}", "", "```", prompt(pose, pal, subject), "```", ""]
        n += 1
open("tools/qa/pixellab_item_prompts.md", "w", encoding="utf-8").write("\n".join(out))
print(n, "prompts")
