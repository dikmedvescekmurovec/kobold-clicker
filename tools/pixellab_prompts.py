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

# Jewellery (2026-09-24): no tiers, one material apiece, so each piece takes its own palette rather than a tier's.
# Three rings of three builds and three pendants of three shapes; the kind's Shape line is shared. Colour words and
# hex are the charts' (tools/DESIGN.md), and every piece takes the polished lines (SHINE).
POSE["RING"] = ("Seen from a slight three-quarter angle above: the band forms a thick oval, its widest part at the "
                "top, the open middle showing the empty background.")
POSE["PENDANT"] = ("Hanging straight down, front view: the necklace loops across the top, the pendant hangs centred below "
                   "it.")
RING_SHAPE = ("Shape: one thick ring, its open middle about a third of its width, the band thickest at the top where "
              "its main part sits and thinner at the bottom.")
PENDANT_SHAPE = ("Shape: a thin necklace dips from near the top corners into a V that meets at a small loop just above "
                 "the middle; the pendant hangs from that loop and fills the lower half of the canvas.")
PAL.update({
 "gold_ring": ("dull gold #c49e48 and #9b7227, bright gold highlights #e9bc3d, a dusty blue stone #628ab9 with steel "
               "blue shadows #546783, dark brown shadows #4e2d1f"),
 "iron_band": "iron grey #41454b, slate #616c79, light grey highlights #d1d1d1, dark grey shadows #2f3236",
 "jade_ring": "moss green #69903e, pine green shadows #226723, dark grey in the deepest shadow #2f3236",
 "opal_ring": ("a lavender grey stone #a598b4 with #776587 shadows and glints of dusty blue #628ab9 and dusty rose "
               "#cc636b, silver #bdbebf and #848585 on the band and setting, dark grey shadows #2f3236"),
 "pearl_ring": ("a bone white pearl #f3f3dc shaded with light grey #d1d1d1 and lavender grey #a598b4, dull gold "
                "#c49e48 and #9b7227 on the band, dark brown shadows #4e2d1f"),
 "ruby_amulet": ("a brick red stone #ba3423 with wine red shadows #8f0d22 and a dusty rose highlight #e1828f, dull "
                 "gold #c49e48 and #9b7227 on the setting and chain"),
 "gold_amulet": ("bright gold #e9bc3d, brass #b78932 and #815119 in the shadows, a dark brown leather cord #4e2d1f"),
 "emerald_amulet": ("a pine green stone #226723 with moss green highlights #69903e, silver #bdbebf and #848585 on the "
                    "setting and chain, dark grey shadows #2f3236"),
})
ITEMS.append(("Rings", [
  ("Gold Ring", "RING", "gold_ring",
   "A dull gold ring with one small round dusty blue stone set on top in four short gold claws; the stone is "
   "the only blue, the band plain and smooth.\n" + RING_SHAPE),
  ("Iron Band", "RING", "iron_band",
   "A broad, flat iron grey ring, as wide as a finger joint, with a row of small round rivets running round "
   "the middle of the band; no stone.\n" + RING_SHAPE),
  ("Jade Ring", "RING", "jade_ring",
   "A thick ring carved from one piece of moss green jade, no metal at all: a smooth rounded band that swells "
   "into a flat oval face on top.\n" + RING_SHAPE),
  ("Opal Ring", "RING", "opal_ring",
   "A silver ring with one large flat oval lavender grey stone lying across the top of the band in a thick smooth "
   "silver rim; the stone is milky, with a few glints of dusty blue and dusty rose, and fills the whole top of the "
   "ring.\n" + RING_SHAPE),
  ("Pearl Ring", "RING", "pearl_ring",
   "A dull gold ring with one big round bone white pearl raised high above the band on a short gold stem, "
   "so the pearl stands clear of the ring like a ball on a post; the pearl is the only white.\n" + RING_SHAPE),
]))
ITEMS.append(("Amulets", [
  ("Ruby Amulet", "PENDANT", "ruby_amulet",
   "A dull gold chain with a teardrop brick red stone hanging point down, held in a thin dull gold rim with a "
   "small cap at the top; red only on the stone.\n" + PENDANT_SHAPE),
  ("Gold Amulet", "PENDANT", "gold_amulet",
   "A dark brown leather cord with a round bright gold medallion hanging from it: a thick flat disc with a raised "
   "rim and a smooth raised dome in the middle.\n" + PENDANT_SHAPE),
  ("Emerald Amulet", "PENDANT", "emerald_amulet",
   "A silver chain with a pine green stone cut as a tall diamond, point down, held in a thin silver frame with a "
   "small silver loop at the top; green only on the stone.\n" + PENDANT_SHAPE),
]))

# Swords (2026-09-24): the helmet recipe on a weapon -- one Shape line for all five, each material adding one part
# (wood; iron adds the groove; steel curves the guard; golden adds the boss and trim; masterwork facets and spikes),
# each in its tier's palette and look as the helmets, bodies and boots wear them. The wood keeps its own browns, the
# tier's tan orange leather only on the grip, as the Wooden Armor does.
POSE["WEAPON"] = ("Lying diagonally, seen flat from the front: the grip at the bottom-left, the tip at the top-right, "
                  "the sword running from corner to corner.")
# Written again from the Wooden Sword that came back (Assets/Potential/Bases/Wooden Sword.png, 2026-09-24): a broad
# blade split lengthwise into a lit and a shaded half, a guard about twice its width, a very short grip, a ball pommel.
SWORD_SHAPE = ("Shape: one straight one-handed sword: a broad straight blade about six pixels wide, split lengthwise "
               "into a lit upper-left half and a shaded lower-right half, taking up about two thirds of the length; a "
               "crossguard about twice as wide as the blade; a very short grip; a small ball pommel at the end.")
SWORD_ALONE = "A single sword on its own and nothing else."
PAL["w1"] = ("warm brown wood #80553a and #a6754b, sand highlights #c39a61, dark brown grain and shadows #5c3b2b and "
             "#3a2521, tan orange leather #d16e2b and #a54919 only on the grip")
PAL["s3_sword"] = PAL["s3"].replace("on the buckles and rivets", "on the grip's rings")
SWORD_LOOK = {
 "w1": ("Look: natural brown wood, never orange: warm brown with sand highlights along the upper-left edge and dark "
        "brown in the grain and the shadows; only the grip is tan orange leather, its wrap drawn as short dark dashes."),
 "h2": ("Look: cool iron grey, light grey along the upper-left edge of the blade and slate on the lower-right, set "
        "against reddish brown leather on the grip."),
 "s3": ("Look: cool neutral grey steel, pale steel highlights along the upper-left edge of the blade and iron grey in "
        "the shadows; the grip in bronze leather that turns dark brown in its folds, pale tan on its rings."),
 "h5": ("Look: dark navy steel, slate and dusty blue on the faces the light reaches, navy in the shadows, a thin light "
        "grey highlight along every bevelled edge, and no other colour."),
}
ITEMS.append(("Swords", [
  ("Wooden Sword", "WEAPON", "w1",
   "A practice sword carved from plain brown wood: a flat wooden blade, a plain wooden crossguard, a grip wrapped in "
   "tan orange leather, and a round wooden pommel.\n"
   + SWORD_LOOK["w1"] + "\n" + SWORD_SHAPE + "\n" + SWORD_ALONE),
  ("Iron Sword", "WEAPON", "h2",
   "An iron sword: a plain iron grey blade with a dark groove down its middle, a plain bar crossguard of iron, a grip "
   "wrapped in reddish brown leather, and a round iron pommel.\n"
   + SWORD_LOOK["h2"] + "\n" + SWORD_SHAPE + "\n" + SWORD_ALONE),
  ("Masterwork Sword", "WEAPON", "h5",
   "A masterwork sword of dark navy steel, angular and grim: a blade of flat faceted planes with a raised ridge down "
   "its middle and a sharp angular point, a crossguard of broad angular plates whose ends sweep toward the tip in "
   "short points and whose middle dips into a sharp V over the blade, a grip wrapped in navy leather, and a faceted "
   "ball pommel with one short spike. Every plate has a thin bevelled edge.\n"
   + SWORD_LOOK["h5"] + "\n" + SWORD_SHAPE + "\n" + SWORD_ALONE),
]))


# The other weapons (2026-09-24), written to the swords as they came back rather than to the helmets: every weapon
# of a tier stands in the same socket as its sword, so each tier's palette (`wp1`..`wp5`) is measured off
# Assets/Potential/Bases/<tier> Sword.png and named in chart words. Each kind keeps one Shape line for all five,
# with the sword's lit and shaded halves and its ball pommel, and each material adds one part, as the swords did.
# The iron is named in the charts' greys (slate, iron grey, dark grey), never "steel blue" or "navy": those words turned
# the Iron Mace a bright blue that read as the masterwork (2026-09-24). Steel keeps its leather to the grip and loses the
# warm cream highlight: the Steel Morningstar came back with a brown wooden haft and a yellow glint on its head.
PAL.update({
 "wp1": "warm brown wood #864b28 and #b2642e, light orange #df9138, apricot highlights #edbd8c, dark brown shadows #654237",
 "wp2": ("dull slate iron #616c79 and #566874, iron grey #41454b, blued steel highlights #777f85, dark grey shadows "
         "#2f3236, reddish brown leather #7f3b2e and #57261b only on the grip"),
 # The steel of both tiers, measured off the golden pieces the user matches the rest to (2026-09-24): the Golden
 # Sword's lit half #b5afd9 to near white and its shaded half #6a608f, the Golden Sceptre's #8986ab..#666286. Light all
 # over. Tried on the way: a neutral grey (too dark); "dusky plum" shadows and grip (the steel came back pink); iron grey
 # shadows with an aubergine grip and "deep shadows" (the Steel Zweihander's shaded half came back near-black navy
 # #0c0f29 with a purple edge). The golden tier is the steel tier colour for colour; only its gold parts differ.
 "wp3": ("lavender grey steel #b5afd9 and #8986ab, silver highlights #eee9f0, lilac grey on the shaded half #77739a "
         "and #6a608f, iron grey only in the deepest creases #4a495b, iron grey leather #4a495b only on the grip"),
 "wp4": ("lavender grey steel #b5afd9 and #8986ab, silver highlights #eee9f0, lilac grey on the shaded half #77739a "
         "and #6a608f, iron grey only in the deepest creases #4a495b, iron grey leather #4a495b only on the grip, tan "
         "orange #e74408 and bright gold #f59803 and #fdde36 only on the gold parts"),
 "wp5": ("steel blue steel #2b5476 and #113455, dusty blue #5e80ac on the lit faces, light grey edges #b8cbef and "
         "#dae7f9, navy only in the deepest shadows #1a2134"),
 "bone": ("bone white #f3f3dc and pale tan #e5cfb3 with sand shadows #cca67b on the blade, warm brown wood #864b28 "
          "and #b2642e, apricot highlights #edbd8c and dark brown shadows #654237 on the collar, grip and cap"),
 "broken": ("dull slate iron #616c79 and #566874, iron grey #41454b, blued steel highlights #777f85, dark grey shadows "
            "#2f3236, rust orange #a33814 only in small patches on the blade, reddish brown leather #7f3b2e and #57261b "
            "only on the grip"),
})
WEAPON_LOOK = {
 "wp1": ("Look: warm brown wood with apricot highlights along the upper-left edge and dark brown in the grain and the "
         "shadows; the grip wrapped in light orange leather, its wrap drawn as short dark dashes."),
 "wp2": ("Look: dull, plain slate grey iron, unpolished: blued steel along the upper-left edge, iron grey in the "
         "middle tones and dark grey in the shadows; reddish brown leather only on the grip."),
 "wp3": ("Look: pale, cool lavender grey steel, light all over: silver along the upper-left edge, lavender grey on "
         "the lit half, lilac grey on the shaded half, never dark; every part is steel except the grip, which is iron "
         "grey leather."),
 "wp4": ("Look: pale, cool lavender grey steel, light all over: silver along the upper-left edge, lavender grey on "
         "the lit half, lilac grey on the shaded half, never dark; the grip iron grey leather. Only the gold parts are "
         "gold: tan orange, shining bright gold at their highlights. Every edge of the steel is steel colours only."),
 "wp5": ("Look: cool steel blue steel, dusty blue on the faces the light reaches, navy only in the deepest shadows, a "
         "thin light grey highlight along every edge, and no other colour."),
 "bone": ("Look: pale bone white with sand in the shadows and a pale tan middle tone on the blade; the collar, grip and "
          "cap warm brown wood with apricot highlights, the grip's wrap drawn as short dark dashes."),
 "broken": ("Look: old, worn, dull slate grey iron: blued steel along the upper-left edge, iron grey in the middle "
            "tones and dark grey in the shadows, with a few small rust orange patches; the grip in worn reddish brown "
            "leather."),
}
# Daggers point the other way from swords (the user's call, 2026-09-24); ui_kit's BASE_TRANSPOSE mirrors any that don't.
POSE["DAGGER"] = "Lying diagonally, seen flat from the front: the grip at the top-right, the tip at the bottom-left."
POSE["MACE"] = ("Lying diagonally, seen flat from the front: the grip at the bottom-left, the head at the top-right, "
                "the mace running from corner to corner.")
# The old dagger row learned that a dagger has to read small before it reads as anything else: the pack's knife at
# 28 px corner to corner stood as tall as the sword. So the dagger carries its own size line, as a helmet does.
DAGGER_SIZE = ("The knife is small: about 22 of the 32 pixels from corner to corner, centred in the canvas, with clear "
               "space all round.")
# Written again (2026-09-24): the first dagger shape was the sword's word for word -- a crossguard, a ball pommel, the
# lit and shaded halves -- and read as a small sword (the user's call). A cross is what says sword, so the dagger has
# none: a triangular blade no longer than its handle, a thin collar, a thick grip and a flat cap.
DAGGER_SHAPE = ("Shape: one short knife: a blade shaped like a long narrow triangle, widest where it meets the handle "
                "and tapering all the way to the point, no longer than the handle; "
                "between them only a thin collar no wider than the blade; a thick grip as long as the "
                "blade; a flat round cap at the end of the grip.")
MACE_SHAPE = ("Shape: one one-handed mace: a straight haft about three pixels wide taking up about two thirds of the "
              "length, a short wrapped grip at its lower end with a small ball pommel, and one heavy head at its "
              "upper end, about three times as wide as the haft.")
# The swords already run corner to corner, so a two-hander cannot be longer: it is heavier -- a broader blade, a
# grip for two hands, a wider guard.
# Written again from the Masterwork Greatsword that came back (Assets/Potential/Bases/Masterwork Greatsword.png,
# 2026-09-24), the one the user said looked most like a two-hander "because the tip expands": a blade about 9 px wide
# at the guard widening to about 12 below a broad slanted tip, a short thick guard, a long grip into the corner.
GREAT_SHAPE = ("Shape: one huge, heavy two-handed sword filling the whole canvas from corner to corner: a massive "
               "blade that widens from the crossguard toward the tip, about nine pixels wide at the guard and about "
               "twelve pixels wide just below the tip, ending in a broad squared-off tip cut at a slant instead of a "
               "point; the blade takes up about two thirds of the length, split lengthwise into a lit upper-left half "
               "and a shaded lower-right half; a short, thick crossguard only a little wider than the blade; a long, "
               "thick grip for two hands running into the bottom-left corner; a small ball pommel at its end.")
ONE = {"DAGGER": "A single knife on its own and nothing else.", "MACE": "A single mace on its own and nothing else.",
       "WEAPON": "A single sword on its own and nothing else."}


def _weapon(name, pose, pal, subject, shape):
    extra = [DAGGER_SIZE] if pose == "DAGGER" else []
    return (name, pose, pal, "\n".join([subject, WEAPON_LOOK[pal], shape] + extra + [ONE[pose]]))


ITEMS.append(("Daggers", [
  _weapon("Bone Knife", "DAGGER", "bone",
          "A knife with a blade of carved bone: a pale bone blade with a rough chipped edge, a thin wooden collar, a "
          "thick wooden grip wrapped in light orange leather, and a flat wooden cap.", DAGGER_SHAPE),
  _weapon("Iron Dagger", "DAGGER", "wp2",
          "An iron dagger: a plain slate grey iron blade with a dark groove down its middle, a thin iron collar, a "
          "thick grip wrapped in reddish brown leather, and a flat iron cap.", DAGGER_SHAPE),
  _weapon("Steel Stiletto", "DAGGER", "wp3",
          "A steel stiletto: a very slim lavender grey steel blade, square in section, narrowing to a long needle "
          "point, a thin steel collar, a thick grip wrapped in iron grey leather, and a flat steel cap.",
          DAGGER_SHAPE),
  _weapon("Golden Kris", "DAGGER", "wp4",
          "A steel dagger with a wavy blade and gold fittings: a lavender grey steel blade that bends in three gentle "
          "waves from the handle to the point, a thin gold collar, a thick grip wrapped in iron grey "
          "leather, and a flat gold cap. Gold only on the collar and the cap.", DAGGER_SHAPE),
  _weapon("Masterwork Dagger", "DAGGER", "wp5",
          "A masterwork dagger of steel blue steel, sharp and angular: a clean blade with a raised ridge down its "
          "middle, tapering to a sharp point, a thin angular collar that dips into a sharp V over the blade, a thick "
          "grip wrapped in navy leather, and a flat cap with one short spike. A thin light grey highlight along each "
          "edge of the blade.", DAGGER_SHAPE),
]))
dict(ITEMS)["Swords"][2:2] = [_weapon("Steel Sword", "WEAPON", "wp3",
    "A steel sword: a lavender grey steel blade with a groove down its middle, a steel crossguard whose two ends curve "
    "toward the tip, a grip wrapped in iron grey leather, and a round steel pommel.", SWORD_SHAPE)]
dict(ITEMS)["Swords"].insert(3, _weapon("Golden Sword", "WEAPON", "wp4",
    "A steel sword with a gold hilt: a lavender grey steel blade with a groove down its middle, a gold "
    "crossguard whose two ends curve toward the tip, a grip wrapped in iron grey leather, and a round "
    "gold pommel. Gold only on the crossguard and the pommel.", SWORD_SHAPE))
ITEMS.append(("Maces", [
  _weapon("Wooden Club", "MACE", "wp1",
          "A club carved from one piece of wood: a plain wooden haft that swells into a thick rounded knobbly head, "
          "a grip wrapped in light orange leather, and a round wooden pommel.", MACE_SHAPE),
  _weapon("Iron Mace", "MACE", "wp2",
          "An iron mace: a slate grey iron haft, a round slate grey iron head ringed with four short flat flanges, a "
          "short grip wrapped in reddish brown leather, and a round iron pommel.", MACE_SHAPE),
  _weapon("Steel Morningstar", "MACE", "wp3",
          "A steel morningstar, all steel from the head to the grip: a lavender grey steel haft, a round steel ball head studded all round with short "
          "pointed spikes, a short grip wrapped in iron grey leather, and a round steel pommel.", MACE_SHAPE),
  _weapon("Golden Sceptre", "MACE", "wp4",
          "A steel sceptre with gold fittings: a lavender grey steel haft, a head of six tall lavender grey steel flanges "
          "standing round the top like a crown, a gold collar under the head, a grip wrapped in "
          "iron grey leather, and a round gold pommel. Gold only on the collar and the pommel.",
          MACE_SHAPE),
  _weapon("Masterwork Mace", "MACE", "wp5",
          "A masterwork mace of steel blue steel, sharp and angular: a plain steel haft, a head of broad angular "
          "flanges each ending in a short sharp point with one longer spike on top, a grip wrapped in navy leather, "
          "and a ball pommel with one short spike. A thin light grey highlight along the edge of each flange.",
          MACE_SHAPE),
]))
ITEMS.append(("Greatswords", [
  _weapon("Wooden Greatsword", "WEAPON", "wp1",
          "A massive practice sword carved from plain brown wood: a thick wooden blade that widens toward its broad "
          "slanted tip, a short thick wooden crossguard, a long grip wrapped in light orange leather, and a round wooden pommel.", GREAT_SHAPE),
  _weapon("Iron Claymore", "WEAPON", "wp2",
          "A massive iron two-handed sword: a slate grey iron blade that widens toward its broad slanted tip, with a dark "
          "groove down its middle, a short thick iron crossguard whose two ends slope toward the tip, a long grip wrapped in reddish brown leather, and a round "
          "iron pommel.", GREAT_SHAPE),
  _weapon("Steel Zweihander", "WEAPON", "wp3",
          "A massive steel two-handed sword: a lavender grey steel blade that widens toward its broad slanted tip, with a groove "
          "down its middle and two short hooks sticking out from its sides just above the crossguard, a short thick "
          "crossguard whose two ends curve "
          "gently toward the tip, a long grip wrapped in iron grey leather, and a round steel pommel.", GREAT_SHAPE),
  _weapon("Golden Greatsword", "WEAPON", "wp4",
          "A massive steel two-handed sword with a gold hilt: a lavender grey steel blade that widens toward its broad slanted tip, "
          "with a groove down its middle, a short thick gold crossguard whose two ends curve toward the tip, a long grip wrapped in iron grey "
          "leather, and a round gold pommel. Gold only on the crossguard and the pommel.", GREAT_SHAPE),
  _weapon("Masterwork Greatsword", "WEAPON", "wp5",
          "A massive masterwork two-handed sword of steel blue steel, sharp and angular: a very wide clean blade "
          "with a raised ridge down its middle and a sharp angular point, a wide crossguard of broad angular plates "
          "whose ends sweep toward the tip in short points and whose middle dips into a sharp V over the blade, a "
          "long grip wrapped in navy leather, and a faceted ball pommel with one short spike. Every plate has a thin "
          "bevelled edge.", GREAT_SHAPE),
]))
# The player's first find (LootTable.FIRST_DROP), which wears the Wooden Sword's picture until it has its own.
# Its own view and shape: the sword's say the blade runs to the far corner, which a snapped blade cannot.
POSE["BROKEN"] = ("Lying diagonally, seen flat from the front: the grip at the bottom-left, the jagged end of the "
                  "blade toward the top-right, with empty space beyond it.")
ONE["BROKEN"] = ONE["WEAPON"]
BROKEN_SHAPE = SWORD_SHAPE.replace("taking up about two thirds of the length", "snapped off short, only about as long as "
                                   "the crossguard, grip and pommel together")
ITEMS.append(("Broken sword", [
  _weapon("Broken Sword", "BROKEN", "broken",
          "An old, snapped iron sword: a slate grey iron blade broken off at about half its length in a jagged "
          "break, a few small rust orange patches on the blade, a plain bar crossguard of iron, a grip wrapped in "
          "worn reddish brown leather, and a round iron pommel.", BROKEN_SHAPE),
]))


# Shields (2026-09-24): a heater rather than a round one, so the steel tier's kite is the same outline. The Wooden
# Shield came back (Assets/Potential/Bases/Wooden Shield.png) straight on, 24x30, with no edge showing, a rim two
# pixels thick, five planks and a boss dead centre. The user took the boss off (a ball is too much), found the plain faces
# that followed too boring, and liked the first Iron Shield's double border (a broad riveted rim, an inner border,
# a sunken face).
# So the Shape line carries that border, and each material puts one flat device on the face in the boss's place:
# wood a leather band, iron a strapped cross, steel a chevron, golden a gold sun (and rim), masterwork an arrowhead
# crest and spikes. Each in its sword's palette (`wp1`..`wp5`), less the grip.
POSE["SHIELD"] = "Front view, seen straight on, standing upright: only the face of the shield shows."
ONE["SHIELD"] = "A single shield on its own and nothing else."
SHIELD_SHAPE = ("Shape: one shield standing upright, about 24 pixels wide and 30 tall: a flat top edge with small "
                "rounded corners, straight sides for about half its height, then curving in to a point at the bottom; "
                "a broad rim about three pixels wide studded with small round studs, and just inside it a second, "
                "narrower raised border following the same outline, so the face sits in a sunken panel; one flat "
                "device on the face, big enough to read at a glance.")
WEAPON_LOOK["wp1_shield"] = ("Look: warm brown wood with apricot highlights along the upper-left edge of each plank and "
                             "dark brown in the grain and in the lines between the planks; the rim bound in light orange "
                             "leather, its stitching drawn as short dark dashes.")
PAL["wp1_shield"] = PAL["wp1"]
# A shield has no grip in view, so its palettes are the swords' less the grip's leather.
for _t, _grip in (("wp2", ", reddish brown leather #7f3b2e and #57261b only on the grip"),
                  ("wp3", ", iron grey leather #4a495b only on the grip"), ("wp4", ", iron grey leather #4a495b only on the grip"),
                  ("wp5", "")):
    PAL[_t + "_shield"] = PAL[_t].replace(_grip, "")
WEAPON_LOOK["wp2_shield"] = ("Look: dull, plain slate grey iron, unpolished: blued steel along the upper-left edges, "
                             "iron grey in the middle tones and dark grey in the shadows; rivets as single light dots.")
WEAPON_LOOK["wp3_shield"] = ("Look: pale, cool lavender grey steel, light all over: silver along the upper-left edges, "
                             "lavender grey on the lit half of the face, lilac grey on the shaded half, never dark.")
WEAPON_LOOK["wp4_shield"] = WEAPON_LOOK["wp3_shield"] + (" Only the gold parts are gold: tan orange, shining bright gold "
                                                         "at their highlights. Every edge of the steel is steel colours only.")
WEAPON_LOOK["wp5_shield"] = WEAPON_LOOK["wp5"]
ITEMS.append(("Shields", [
  _weapon("Wooden Shield", "SHIELD", "wp1_shield",
          "A wooden shield: a face of upright planks of warm brown wood, crossed by one broad flat band of light "
          "orange leather running across the middle from side to side; the broad rim bound in light orange "
          "leather, the inner border of darker wood.", SHIELD_SHAPE),
  _weapon("Iron Shield", "SHIELD", "wp2_shield",
          "An iron shield: a face of slate grey iron crossed by two flat riveted iron straps, one running down the "
          "middle from the top to the point and one across the upper third, making a cross; the broad rim and the "
          "inner border of iron.", SHIELD_SHAPE),
  _weapon("Steel Kite Shield", "SHIELD", "wp3_shield",
          "A steel shield: a face of lavender grey steel with a raised chevron, a broad upside-down V of steel, "
          "spanning the face from side to side a little above the middle; the broad rim and the inner border of "
          "steel. Every part is steel.", SHIELD_SHAPE),
  _weapon("Golden Aegis", "SHIELD", "wp4_shield",
          "A steel shield with gold fittings: a face of lavender grey steel with a gold sun in the upper middle, a "
          "flat disc with eight short straight rays lying flat against the face; the broad rim gold, the inner "
          "border steel. Gold only on the rim and the sun.", SHIELD_SHAPE),
  _weapon("Masterwork Shield", "SHIELD", "wp5_shield",
          "A masterwork shield of steel blue steel, sharp and angular: a face of flat faceted plates meeting in a "
          "raised ridge down its middle, a raised angular crest in the middle shaped like a downward-pointing "
          "arrowhead, and the broad rim of angular plates with one short spike rising from each top corner. Every "
          "plate has a thin bevelled edge.", SHIELD_SHAPE),
]))


# Bucklers (2026-09-24): the dexterity offhand, so a small round shield rather than the heater -- the one shape
# that tells them apart in the same socket. The shields' recipe otherwise: straight on, a studded border in place
# of the double border (a buckler is too small for two), a flat face with no raised middle (the user took the
# shields' boss off as too much), and one flat device a material, none of them a shield's: a laced patch (hide),
# spokes (iron), rings and a star (steel), a gold crescent (golden), faceted plates and spikes (masterwork). Each
# in its shield's palette; the hide takes the Leather Helmet's leather (`h1`), since wood is the Wooden Shield's.
POSE["BUCKLER"] = POSE["SHIELD"]
ONE["BUCKLER"] = "A single small round shield on its own and nothing else."
BUCKLER_SHAPE = ("Shape: one small round shield, a perfect circle about 26 pixels across, seen straight on so it is a "
                 "circle and not an oval: a rim about two pixels wide running all the way round, a ring of small round "
                 "studs just inside the rim, and a flat face inside the ring of studs; one flat device on the face, "
                 "big enough to read at a glance.")
PAL["h1_buckler"] = PAL["h1"]
WEAPON_LOOK["h1_buckler"] = HELM_LOOK["h1"]
ITEMS.append(("Bucklers", [
  _weapon("Hide Buckler", "BUCKLER", "h1_buckler",
          "A small hide shield: a face of tan orange hide stretched tight over a round frame, a rim of bronze "
          "leather laced to the face with short stitches all the way round, and in the middle a flat round patch of "
          "darker bronze leather held down by four small studs.", BUCKLER_SHAPE),
  _weapon("Iron Buckler", "BUCKLER", "wp2_shield",
          "A small iron shield: a face of slate grey iron with eight flat iron spokes running straight out from a "
          "small flat round plate in the middle to the rim, like the spokes of a cartwheel; the rim and its studs "
          "of iron.", BUCKLER_SHAPE),
  _weapon("Steel Targe", "BUCKLER", "wp3_shield",
          "A small steel shield: a face of lavender grey steel with two thin raised rings round the middle, one "
          "inside the other, and a flat four-pointed star lying flat in the very middle; the rim and its studs of "
          "steel. Every part is steel.", BUCKLER_SHAPE),
  _weapon("Golden Buckler", "BUCKLER", "wp4_shield",
          "A small steel shield with gold fittings: a face of lavender grey steel with a flat gold crescent moon "
          "lying across the middle, its two horns pointing up; the rim gold, the studs steel. Gold only on the rim "
          "and the moon.", BUCKLER_SHAPE),
  _weapon("Masterwork Buckler", "BUCKLER", "wp5_shield",
          "A small masterwork shield of steel blue steel, sharp and angular: a face of six flat triangular plates "
          "meeting at a point in the middle like the facets of a cut gem, and six short spikes pointing straight "
          "out from the rim, evenly spaced round it. Every plate has a thin bevelled edge.", BUCKLER_SHAPE),
]))


# Torches (2026-09-24): three materials, not five (Sight has three values: LootTable's torch), plus the Thick Fog's
# Broken Torch, which wears the Wooden Torch's picture until it has its own. Laid like the weapons, handle at the
# bottom-left, but the fire rises straight up rather than along the haft, since fire does. The flame is what the
# kind is for (Sight), so it grows with the material -- small, roaring, tall -- and is the one bright thing on each,
# which is why the ordinary colour line's "never bright" is loosened for it. Wood, iron and masterwork take the
# swords' measured wood (`wp1`), iron (`wp2`) and steel blue (`wp5`); the fire is chart colours only.
POSE["TORCH"] = ("Lying diagonally, seen flat from the front: the handle at the bottom-left, the burning head toward "
                 "the top-right; the flame rises straight up from the head, not along the handle.")
ONE["TORCH"] = "A single torch on its own and nothing else."
TORCH_SHAPE = ("Shape: one hand torch: a straight haft about three pixels wide running from the bottom-left corner to "
               "a little past the middle of the canvas, a head at its upper end about twice as wide as the haft, and a "
               "flame rising straight up from the head into the top-right of the canvas.")
FIRE = ("fire of bright gold #e9bc3d at its heart, light orange #e68908 and burnt orange #c95429 at its edges, rust "
        "orange #a33814 at the flickering tips")
PAL.update({
 "torch1": ("warm brown wood #864b28 and #b2642e, apricot highlights #edbd8c, dark brown shadows #654237, burlap tan "
            "cloth #a77a3e, " + FIRE),
 "torch2": ("warm brown wood #864b28 and #b2642e and dark brown shadows #654237 on the haft, dull slate iron #616c79 "
            "and #566874, iron grey #41454b and blued steel highlights #777f85 on the bands and the cage, " + FIRE),
 "torch5": PAL["wp5"] + ", " + FIRE,
 "torch_broken": ("warm brown wood #864b28 and #b2642e, dark brown #4e2d1f where it is charred, grey-brown ash "
                  "#81746a, burlap tan cloth #a77a3e, light orange #e68908 and burnt orange #c95429 in the small flame"),
})
_GLOW = "the fire the brightest thing on it, gold at its heart and orange at its edges."
WEAPON_LOOK.update({
 "torch1": ("Look: warm brown wood with apricot highlights along the upper-left edge and dark brown in the grain and "
            "the shadows; the cloth wrap burlap tan, its turns drawn as short dark lines; " + _GLOW),
 "torch2": ("Look: warm brown wood set against dull, plain slate grey iron: blued steel along the upper-left edges of "
            "the iron, dark brown in the wood's grain and the shadows; " + _GLOW),
 "torch5": ("Look: cool steel blue steel, dusty blue on the faces the light reaches, navy only in the deepest shadows, "
            "a thin light grey highlight along every edge; the steel is steel blue and navy only, and " + _GLOW
            + " The fire is the only warm colour."),
 "torch_broken": ("Look: old, worn warm brown wood, dark brown where it is charred and grey-brown where the ash sits; "
                  "the small flame the only bright thing on it."),
})
ITEMS.append(("Torches", [
  _weapon("Wooden Torch", "TORCH", "torch1",
          "A plain wooden torch: a straight stick of warm brown wood, its upper end wrapped in a few turns of burlap "
          "tan cloth, and a small steady flame about a quarter of the canvas tall burning on the cloth.", TORCH_SHAPE),
  _weapon("Blazing Torch", "TORCH", "torch2",
          "A sturdy torch with an iron head: a straight haft of warm brown wood bound with two slate grey iron bands, "
          "topped by a small open iron cage of four bars holding the burning end, and a big roaring flame about half "
          "the canvas tall bursting out of the cage and rising well above it.", TORCH_SHAPE),
  _weapon("Masterwork Torch", "TORCH", "torch5",
          "A masterwork torch of steel blue steel, sharp and angular: a faceted steel haft with a raised ridge down "
          "it and a short spike at its lower end, topped by an angular steel cup of pointed plates opening like a "
          "crown, and a tall fierce flame about half the canvas tall rising from the cup. Every plate has a thin "
          "bevelled edge.", TORCH_SHAPE),
  _weapon("Broken Torch", "TORCH", "torch_broken",
          "An old, burnt-out torch: a stick of warm brown wood split by a long crack down its length, its head "
          "charred dark brown with grey-brown ash and a few torn scraps of burlap tan cloth, and a small guttering "
          "flame about five pixels tall clinging to one side of the head.", TORCH_SHAPE),
]))


# The top materials are the finest of their line and should look it: the same dusty set, but polished.
# Without this the golden and masterwork helms came out duller than the steel one (2026-09-23).
SHINE = {"wp3": "the steel's upper-left edges", "wp4": "the gold parts", "wp5": "the thin light grey edges",
         "h4": "the tan orange and bright gold parts", "h5": "the thin light grey edges",
         "gold": "the gold parts", "master": "the pale bevelled edges", "t4": "the gold parts", "t5": "the thin bone-white edges",
         "b4": "the copper and bright gold parts", "b5": "the thin light grey edges",
         "gold_ring": "the gold band and the stone", "iron_band": "the rivets and the band's rims",
         "jade_ring": "the jade's smooth face",
         "opal_ring": "the milky stone and its glints", "pearl_ring": "the round pearl", "ruby_amulet": "the red stone", "gold_amulet": "the gold rim and dome",
         "emerald_amulet": "the green stone and the silver frame"}
# The leather line's top two: finer leather rather than polished metal.
SHINE_LEATHER = {"t4_leather": "the copper buckles", "t5_leather": "the light grey stitched edges"}


NO_CREAM = {"wp2", "broken"}
LIGHT_STEEL = {"wp3", "wp4"}
# The shields wear their swords' treatment.
NO_CREAM.add("wp2_shield"); LIGHT_STEEL |= {"wp3_shield", "wp4_shield"}
SHINE.update({"wp3_shield": SHINE["wp3"], "wp4_shield": SHINE["wp4"], "wp5_shield": SHINE["wp5"]})
SHINE["torch5"] = "the thin light grey edges and the fire"


def prompt(pose, pal, subject):
    muted = ("Muted, dusty, faded colours like an old hand-painted item sheet; warm browns and greys dominate, "
             "every colour greyed down, never pure or bright.")
    if pal in NO_CREAM:
        # Cool metal: "warm browns dominate" helped turn the Steel Morningstar's haft to wood.
        muted = muted.replace("warm browns and greys dominate", "cool greys dominate")
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
    if pal.startswith("torch"):
        muted = muted.replace("never pure or bright.", "never pure; only the fire glows.")
    if pal in LIGHT_STEEL:
        muted = muted.replace("and deep shadows", "and soft, light shadows")
    # No outline line: pixellab's Outline setting draws its own, and `_outlined` repaints it in ink anyway.
    # A helmet and a dagger carry their own size lines (HELM_SIZE, DAGGER_SIZE), which this one would contradict.
    margin = [] if pose in ("HELM", "DAGGER", "BROKEN") else ["Object fills most of the canvas with a 2-3 pixel margin, centred."]
    return "\n".join([subject,
     "Single game inventory icon, 32x32 pixel art in the style of a classic fantasy RPG item pack.",
     POSE[pose]] + margin + [
     "A plain, common item: simple shapes and a clean readable silhouette, no engraving, no decoration, no gems or trim beyond what is named.",
     muted,
     f"Palette: {PAL[pal]}" + ("." if pal in NO_CREAM else ", pale cream highlights #faedb1."),
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
