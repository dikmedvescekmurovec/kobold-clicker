"""One palette per environment for the battle backdrops.

Each entry is the whole place: the sky ramp top-to-horizon, the cloud steps, the land bands from
the far field down to the floor, the cover ramp the ground texture is drawn with, and the materials
its people build with. Anything drawn in areas.py reads its colours from here and nowhere else, so
an environment is re-tinted by editing one block.

The grass entry is sampled from the hand-drawn reference, Assets/Area/Summer2.png; the other five
are built to match its contrast -- a pale ceiling, a blue that darkens upward, a hazy horizon, and
a cover ramp of six steps from the lit top of a clump down to the shadow under the front one.
"""
from arealib import GROUND_TOP, HORIZON

PAL = {
    "grass": {
        "sky": [(0, (66, 170, 202)), (100, (80, 180, 212)),
                (132, (93, 189, 214)), (159, (108, 194, 217)), (178, (118, 203, 223)),
                (189, (153, 217, 229)), (HORIZON, (216, 248, 243))],
        "cloud_core": (62, 151, 179), "cloud_edge": (108, 194, 217), "cloud_lit": (163, 222, 231),
        "cloud_hi": (216, 248, 243), "cloud_lo": (163, 222, 231),
        "horizon": (119, 162, 205),
        "ground": [(GROUND_TOP, (137, 192, 125)), (227, (109, 171, 72)), (242, (93, 162, 69)),
                   (254, (126, 176, 63)), (266, (98, 158, 70))],
        "clumps": [(118, 174, 63), (89, 148, 66), (74, 122, 84), (73, 120, 72), (52, 89, 72),
                   (41, 77, 51)],
        "specks": [(254, 240, 81), (255, 242, 165), (228, 215, 123)],
        "blossoms": [((255, 232, 230), (254, 240, 81)), ((245, 160, 151), (255, 232, 230)),
                     ((163, 222, 231), (255, 242, 165)), ((255, 242, 165), (228, 215, 123))],
        "hill": (119, 181, 98), "hill_lit": (137, 192, 125),
        "road": [(191, 168, 122), (168, 143, 99), (146, 121, 82)], "road_edge": (146, 121, 82),
        "wall": (216, 205, 178), "wall_dk": (176, 162, 136), "roof": (176, 96, 74),
        "roof_dk": (132, 68, 56), "ink": (52, 44, 48), "dark": (40, 36, 40),
        # Half-timbering, after the references: clay tile over pale plaster panels between dark
        # uprights, on a stone footing, with moss on anything old enough to be stone.
        "tile": (186, 118, 72), "tile_dk": (140, 84, 52), "tile_lit": (214, 154, 100),
        "beam": (92, 62, 44), "beam_dk": (64, 42, 30),
        "plaster": (238, 230, 208), "plaster_sh": (204, 192, 166),
        "moss": (116, 142, 84), "moss_dk": (82, 104, 62),
        "shingle": (92, 84, 66), "shingle_dk": (64, 58, 46), "shingle_lit": (120, 110, 88),
        # The crag the castle reference stands on: grey rock going green in the wet.
        "crag": (128, 130, 118), "crag_dk": (94, 96, 86), "crag_lit": (158, 160, 146),
        "stone": (176, 176, 176), "stone_dk": (128, 132, 140), "stone_lit": (206, 206, 202),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (74, 52, 34), "trunk_lit": (96, 70, 46),
        "glow": (255, 214, 120), "fence": (132, 102, 68), "trunk": (108, 78, 52),
        "crown": (92, 167, 84), "crown_dk": (52, 89, 72), "crown_lit": (119, 181, 98),
    },
    "dirt": {
        "sky": [(0, (96, 168, 190)), (100, (110, 180, 198)),
                (132, (124, 190, 206)), (159, (150, 205, 216)), (178, (172, 216, 222)),
                (189, (198, 230, 230)), (HORIZON, (226, 240, 236))],
        "cloud_core": (86, 146, 166), "cloud_edge": (124, 190, 206), "cloud_lit": (176, 214, 224),
        "cloud_hi": (232, 244, 242), "cloud_lo": (190, 226, 230),
        "horizon": (150, 158, 182),
        "ground": [(GROUND_TOP, (172, 152, 124)), (227, (152, 130, 102)), (242, (138, 116, 88)),
                   (254, (126, 104, 78)), (266, (114, 94, 70))],
        "clumps": [(148, 126, 96), (130, 108, 82), (114, 92, 68), (98, 78, 58), (82, 64, 46),
                   (66, 52, 38)],
        "specks": [(150, 130, 100), (120, 132, 80), (96, 110, 70)],
        "blossoms": [((150, 160, 96), (190, 196, 120)), ((132, 146, 88), (168, 180, 108))],
        "hill": (146, 138, 118), "hill_lit": (168, 158, 134),
        "road": [(158, 132, 96), (136, 112, 80), (112, 92, 66)], "road_edge": (96, 78, 58),
        "wall": (206, 192, 162), "wall_dk": (168, 152, 124), "roof": (150, 96, 66),
        "roof_dk": (112, 68, 48), "ink": (44, 36, 32), "dark": (32, 26, 24),
        "thatch": (178, 146, 92), "thatch_dk": (132, 106, 64), "thatch_lit": (208, 180, 126),
        "beam": (96, 72, 48), "beam_dk": (66, 48, 32),
        "plaster": (214, 202, 176), "plaster_sh": (172, 160, 138),
        "moss": (108, 128, 74), "moss_dk": (76, 94, 54),
        "shingle": (104, 84, 66), "shingle_dk": (74, 58, 46), "shingle_lit": (134, 112, 88),
        # The bluff the ruin sits above, dry and pale beside the field.
        "crag": (150, 138, 118), "crag_dk": (112, 102, 86), "crag_lit": (180, 168, 146),
        "tile": (150, 96, 66), "tile_dk": (112, 68, 48), "tile_lit": (182, 128, 92),
        "stone": (168, 160, 148), "stone_dk": (124, 116, 108), "stone_lit": (198, 192, 180),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (66, 48, 32), "trunk_lit": (88, 64, 42),
        # Daub: mud and straw pressed onto a wattle frame, which is what the village reference
        # is walled with. Warmer and duller than plaster -- it has never been painted.
        "daub": (186, 158, 118), "daub_dk": (142, 116, 84), "daub_lit": (212, 188, 150),
        # Undressed rubble, off the fortress reference: cold grey, laid without being cut. It is
        # deliberately colder than this environment's own warm `stone`, because what makes the
        # keep read as older and grimmer than the town is that it was never dressed.
        "rubble": (126, 126, 124), "rubble_dk": (88, 88, 88), "rubble_lit": (154, 154, 150),
        # The poles the thatch is bound over, and the fire in the middle of the village.
        "pole": (132, 106, 70), "fire": (236, 128, 52), "fire_lit": (255, 198, 96),
        "smoke": (176, 170, 158),
        "glow": (255, 214, 120), "fence": (120, 92, 60), "trunk": (96, 70, 48),
        "crown": (108, 132, 72), "crown_dk": (70, 90, 52), "crown_lit": (134, 156, 90),
    },
    "desert": {
        "sky": [(0, (96, 186, 212)), (100, (116, 198, 218)),
                (132, (140, 208, 222)), (159, (170, 218, 226)), (178, (198, 228, 226)),
                (189, (226, 236, 220)), (HORIZON, (250, 240, 206))],
        "cloud_core": (168, 206, 214), "cloud_edge": (200, 226, 228), "cloud_lit": (236, 244, 236),
        "cloud_hi": (252, 248, 236), "cloud_lo": (224, 232, 224),
        "horizon": (206, 186, 146),
        "ground": [(GROUND_TOP, (236, 214, 164)), (227, (222, 196, 140)), (242, (208, 180, 122)),
                   (254, (194, 164, 106)), (266, (180, 150, 94))],
        "clumps": [(214, 186, 130), (196, 166, 110), (178, 148, 96), (158, 128, 80),
                   (138, 110, 68), (118, 92, 56)],
        "specks": [(236, 220, 172), (190, 160, 100), (160, 132, 84)],
        "blossoms": [((186, 178, 110), (214, 204, 140)), ((166, 158, 98), (198, 190, 128))],
        "hill": (214, 186, 132), "hill_lit": (232, 206, 156),
        "road": [(212, 186, 136), (190, 162, 114), (168, 140, 96)], "road_edge": (150, 122, 82),
        "wall": (232, 214, 176), "wall_dk": (196, 174, 136), "roof": (196, 140, 92),
        "roof_dk": (150, 102, 64), "ink": (56, 44, 36), "dark": (40, 32, 26),
        "stone": (214, 198, 164), "stone_dk": (166, 148, 116), "stone_lit": (238, 226, 198),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (118, 72, 48), "trunk_lit": (160, 102, 66),
        "glow": (255, 214, 120), "fence": (150, 120, 78), "trunk": (126, 98, 62),
        "crown": (150, 170, 96), "crown_dk": (104, 124, 70), "crown_lit": (176, 192, 116),
        # Rammed earth and the rock it is piled on, sampled off the kasbah references: a red
        # ochre four steps deep for the walls, a paler and greyer stone for the crag under them,
        # so the town reads as built on the rock rather than cut out of it.
        "mud": (198, 134, 88), "mud_lit": (224, 166, 114), "mud_dk": (160, 102, 66),
        "mud_sh": (118, 72, 48),
        "crag": (190, 152, 112), "crag_lit": (218, 184, 142), "crag_dk": (146, 110, 78),
    },
    "ice": {
        "sky": [(0, (120, 186, 216)), (100, (140, 198, 224)),
                (132, (162, 210, 230)), (159, (184, 220, 236)), (178, (204, 230, 240)),
                (189, (224, 240, 246)), (HORIZON, (240, 250, 252))],
        "cloud_core": (146, 178, 202), "cloud_edge": (186, 212, 228), "cloud_lit": (216, 234, 242),
        "cloud_hi": (248, 252, 254), "cloud_lo": (222, 236, 244),
        "horizon": (150, 176, 206),
        "ground": [(GROUND_TOP, (238, 246, 250)), (227, (222, 234, 244)), (242, (206, 222, 238)),
                   (254, (192, 212, 234)), (266, (178, 200, 228))],
        "clumps": [(226, 238, 246), (206, 222, 238), (186, 206, 230), (164, 188, 220),
                   (142, 170, 208), (120, 150, 196)],
        "specks": [(255, 255, 255), (226, 240, 250), (196, 220, 240)],
        "blossoms": [((255, 255, 255), (214, 234, 248)), ((226, 242, 252), (255, 255, 255))],
        "hill": (200, 216, 234), "hill_lit": (230, 240, 250),
        "road": [(198, 208, 224), (176, 188, 208), (154, 166, 190)], "road_edge": (128, 146, 176),
        "wall": (226, 232, 240), "wall_dk": (186, 196, 212), "roof": (108, 132, 168),
        "roof_dk": (76, 96, 128), "ink": (44, 52, 68), "dark": (32, 38, 50),
        "thatch": (198, 212, 228), "thatch_dk": (158, 178, 204), "thatch_lit": (240, 248, 252),
        "beam": (74, 68, 66), "beam_dk": (48, 44, 44),
        "plaster": (226, 236, 246), "plaster_sh": (186, 202, 222),
        "moss": (96, 120, 104), "moss_dk": (68, 88, 76),
        "shingle": (72, 78, 92), "shingle_dk": (50, 54, 66), "shingle_lit": (98, 106, 122),
        "tile": (86, 96, 116), "tile_dk": (60, 68, 84), "tile_lit": (116, 128, 150),
        "cap": (238, 246, 252), "cap_sh": (198, 214, 234),
        "stone": (198, 208, 222), "stone_dk": (150, 162, 182), "stone_lit": (228, 236, 244),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (58, 48, 42), "trunk_lit": (78, 64, 56),
        # Pack ice, for the berg a palace is cut out of. Ice had no crag ramp at all, so any
        # plan of its that stood something on a rock raised KeyError rather than drawing it.
        "crag": (176, 202, 224), "crag_dk": (134, 164, 196), "crag_lit": (214, 232, 244),
        # Carved ice: what the palace is made of, as against the snow lying on everything else.
        # Paler and bluer than stone, and lit hard on one side, or a spire is a grey stick.
        "ice": (172, 206, 230), "ice_dk": (112, 152, 190), "ice_lit": (236, 248, 254),
        # The one warm thing in the place. The town reference is carried entirely by orange
        # windows and hanging lanterns against blue -- take those away and it is a grey hillside.
        "lantern": (255, 168, 76), "lantern_dk": (196, 110, 40),
        "glow": (255, 214, 120), "fence": (120, 110, 104), "trunk": (86, 72, 64),
        "crown": (74, 116, 102), "crown_dk": (48, 84, 78), "crown_lit": (104, 146, 124),
    },
    "forest": {
        "sky": [(0, (104, 182, 196)), (100, (120, 192, 204)),
                (132, (140, 202, 212)), (159, (164, 212, 218)), (178, (190, 224, 224)),
                (189, (214, 236, 230)), (HORIZON, (232, 244, 232))],
        "cloud_core": (96, 158, 168), "cloud_edge": (140, 202, 212), "cloud_lit": (186, 222, 222),
        "cloud_hi": (228, 244, 236), "cloud_lo": (200, 230, 224),
        "horizon": (128, 156, 152),
        "ground": [(GROUND_TOP, (120, 156, 104)), (227, (100, 140, 88)), (242, (84, 124, 76)),
                   (254, (70, 110, 66)), (266, (58, 96, 58))],
        "clumps": [(108, 152, 78), (86, 132, 70), (68, 112, 60), (54, 94, 52), (42, 76, 44),
                   (32, 60, 36)],
        "specks": [(150, 180, 96), (196, 206, 120), (120, 160, 80)],
        "blossoms": [((236, 238, 220), (216, 196, 120)), ((196, 96, 88), (236, 222, 200)),
                     ((214, 216, 190), (172, 152, 96))],
        "hill": (86, 124, 80), "hill_lit": (108, 146, 94),
        "road": [(150, 126, 92), (128, 106, 76), (106, 86, 62)], "road_edge": (86, 70, 50),
        "wall": (214, 198, 166), "wall_dk": (172, 158, 130), "roof": (126, 92, 64),
        "roof_dk": (92, 66, 46), "ink": (34, 38, 32), "dark": (24, 28, 24),
        "thatch": (162, 134, 86), "thatch_dk": (118, 96, 60), "thatch_lit": (196, 168, 116),
        "beam": (92, 68, 46), "beam_dk": (62, 46, 30),
        "plaster": (206, 194, 164), "plaster_sh": (164, 152, 128),
        "moss": (98, 128, 72), "moss_dk": (66, 92, 52),
        "shingle": (96, 82, 62), "shingle_dk": (68, 58, 44), "shingle_lit": (126, 108, 82),
        "tile": (126, 92, 64), "tile_dk": (92, 66, 46), "tile_lit": (156, 118, 84),
        # The hillside the temple reference is cut into -- wet grey rock going green wherever it
        # has stood still long enough, which in a jungle is everywhere.
        "crag": (132, 140, 116), "crag_dk": (100, 108, 88), "crag_lit": (162, 170, 142),
        "stone": (176, 180, 168), "stone_dk": (130, 136, 126), "stone_lit": (204, 208, 196),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (60, 44, 30), "trunk_lit": (82, 60, 42),
        "glow": (255, 214, 120), "fence": (110, 86, 58), "trunk": (92, 68, 48),
        "crown": (78, 128, 70), "crown_dk": (48, 90, 54), "crown_lit": (104, 152, 84),
        # Brown river water, off the town reference -- it is silt, not sky, so it is warm and
        # nearly opaque, and a reflection in it is a dimmed shape rather than a mirror.
        "water": (56, 82, 86), "water_lit": (118, 150, 142),
        # The gold a meru's finials and upper tiers carry. The only warm accent the place has, and
        # the thing that separates a temple from a very large barn.
        "gold": (214, 170, 78), "gold_dk": (150, 114, 48),
        # What grows in every ledge and joint. A jungle leaves nothing bare, and a fern on a stone
        # course is what says this temple has stood a long time.
        "fern": (128, 174, 88), "fern_dk": (74, 116, 58),
    },
    "mountains": {
        "sky": [(0, (56, 146, 190)), (100, (72, 160, 200)),
                (132, (92, 176, 210)), (159, (116, 190, 218)), (178, (146, 206, 226)),
                (189, (184, 222, 234)), (HORIZON, (216, 238, 240))],
        "cloud_core": (48, 124, 164), "cloud_edge": (96, 176, 206), "cloud_lit": (156, 210, 226),
        "cloud_hi": (222, 242, 244), "cloud_lo": (188, 224, 236),
        "horizon": (124, 144, 176),
        "ground": [(GROUND_TOP, (170, 158, 136)), (227, (152, 140, 120)), (242, (136, 124, 106)),
                   (254, (120, 110, 94)), (266, (106, 96, 82))],
        "clumps": [(156, 146, 126), (134, 124, 106), (114, 104, 88), (94, 86, 72), (76, 70, 58),
                   (60, 55, 46)],
        "specks": [(188, 174, 148), (120, 140, 100), (162, 150, 128)],
        "blossoms": [((150, 170, 120), (190, 200, 150)), ((168, 168, 170), (200, 200, 202))],
        "hill": (134, 126, 110), "hill_lit": (162, 152, 134),
        "road": [(180, 166, 142), (156, 142, 120), (132, 120, 100)], "road_edge": (108, 98, 82),
        "wall": (206, 200, 190), "wall_dk": (162, 158, 150), "roof": (120, 110, 120),
        "roof_dk": (86, 80, 92), "ink": (40, 40, 46), "dark": (28, 28, 34),
        # The village in the reference is built on a rock and steps up it, so mountains needs the
        # crag ramp the desert has. Its roofs are weathered dark shingle, not tile: steep, packed
        # tight and at a dozen heights, which is the whole silhouette.
        "crag": (142, 126, 104), "crag_dk": (104, 92, 74), "crag_lit": (172, 158, 134),
        "shingle": (88, 80, 74), "shingle_dk": (60, 54, 50), "shingle_lit": (118, 108, 98),
        "beam": (78, 64, 52), "beam_dk": (52, 42, 34),
        "plaster": (208, 204, 196), "plaster_sh": (166, 162, 156),
        "moss": (96, 118, 78), "moss_dk": (68, 86, 58),
        "tile": (120, 110, 120), "tile_dk": (86, 80, 92), "tile_lit": (150, 140, 148),
        # Darker than the other places build in. Mountains ground is already pale grey, so stone at
        # the old value put a white bar across a white field -- a curtain wall here has to sit down
        # against the scree rather than glare off it.
        "stone": (164, 164, 172), "stone_dk": (120, 120, 130), "stone_lit": (192, 192, 198),
        # The shaded side of a trunk and the litter under it. Shared, because a palm
        # grows in a desert oasis and over a jungle river both.
        "trunk_sh": (56, 44, 36), "trunk_lit": (78, 62, 50),
        # Warm ashlar, off the town reference: cut stone, laid flat-roofed and stacked up a rock.
        # Warmer than the grass's limestone on purpose -- the two places that both build in stone
        # have to differ in something a glance can catch, and the temperature of it is that thing.
        "ochre": (198, 180, 144), "ochre_dk": (152, 136, 106), "ochre_lit": (226, 212, 180),
        # The red cones on the fortress's drum towers, and the pennants over them. This is the only
        # saturated colour anywhere in the six environments, which is the whole point of spending
        # it here: one look at a red roof and you know which place you are fighting in.
        "redtile": (180, 76, 58), "redtile_dk": (134, 52, 42), "redtile_lit": (208, 112, 84),
        "banner": (198, 66, 54), "banner_pale": (238, 232, 218),
        "glow": (255, 214, 120), "fence": (110, 102, 92), "trunk": (84, 68, 56),
        "crown": (72, 110, 86), "crown_dk": (48, 80, 66), "crown_lit": (98, 136, 104),
    },
}

# Snow and rock for the peaks behind the cold and high places, and the haze a distant ridge sits in.
PEAKS = {
    "ice": {"rock": (146, 160, 186), "lit": (186, 200, 220), "snow": (240, 248, 252),
            "haze": (196, 218, 234)},
    "mountains": {"rock": (110, 118, 140), "lit": (146, 154, 174), "snow": (236, 244, 248),
                  "haze": (166, 194, 214)},
    "desert": {"rock": (196, 166, 124), "lit": (222, 196, 152), "snow": None,
               "haze": (232, 214, 176)},
    "dirt": {"rock": (140, 128, 106), "lit": (168, 154, 128), "snow": None,
             "haze": (196, 206, 202)},
    "grass": {"rock": (120, 150, 128), "lit": (150, 178, 150), "snow": None,
              "haze": (182, 212, 206)},
    "forest": {"rock": (96, 132, 112), "lit": (126, 160, 132), "snow": None,
               "haze": (188, 216, 206)},
}
