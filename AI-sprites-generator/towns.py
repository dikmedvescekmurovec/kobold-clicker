"""Phase 3: the map's settlements, three tiers in each of the six environments.

A settlement is an icon, not a street plan: one tight cluster, a few big shapes in two tones each, so
it reads at a glance on the map. Each environment keeps only its people's signature (README,
*Battle backdrops*): red gables in grass, thatch cones in dirt, rammed-earth cubes with teeth in the
desert, snow roofs over a warm light in ice, tiered roofs under a gold finial in the forest, cream
blocks under a red spire in the mountains. The village is two buildings, the town three or four
round a landmark, the fortress one castle silhouette.

A settlement is two pictures. The **tile** (56x64, in the hex atlas as `town_<env>_<tier>`) is only
ground: the clearing, the plate the town stands on, and the buildings' shadows and halo. The
**sprite** (SPRITE_W x SPRITE_H, `Assets/Towns/`, written by `build_towns.py`) is the buildings,
which Godot draws on a layer of their own over the fog and past the hex, so a town is bigger than
its tile and reads from across the map.

Buildings are height fields drawn in 3/4 view by `render`: a footprint and a height per ground
pixel, drawn near-to-far per column so what stands in front hides what is behind. The top pixel of a
span is roof and the rows under it are the front wall, so eaves, gable ends, crenels and cones come
out of the geometry, and the cast shadow is the same height field's.

The tile starts from the environment's "base" (its shared border band, identical on every variant)
and clears the middle, so it tiles against any neighbour; the outer ring is copied back at the end.
"""
import math

from hexlib import BORDER, C, DARKER, HEX_PIXELS, PALETTE, bayer
from terrain import ENV_ORDER, ENVS, R, forest_shared_trees, forest_tree, palm

TIERS = ["small", "medium", "fortress"]
CLEARING = {"small": 19.0, "medium": 22.0, "fortress": 24.0}
KEEP = 6.5          # the plate, shadows and halo stay this far inside the tile's border
RING_KEEP = 2.0     # outer ring restored from the base tile so towns always tile against open terrain
# Layouts are written in tile units round the cell's centre (28, 32) and scaled by K into the sprite,
# whose pixel ANCHOR sits on that centre. A tile pixel and a sprite pixel are the same size on screen,
# so tile (x, y) is sprite (x + SHIFT[0], y + SHIFT[1]). Godot's `HexMap.TOWN_ANCHOR` is ANCHOR.
K = 1.35
SPRITE_W, SPRITE_H = 84, 96
ANCHOR = (42, 56)
SHIFT = (ANCHOR[0] - 28, ANCHOR[1] - 32)


def mp(u, v):
    """A layout point (tile units) in sprite pixels."""
    return ANCHOR[0] + (u - 28) * K, ANCHOR[1] + (v - 32) * K


def mpi(u, v):
    x, y = mp(u, v)
    return int(round(x)), int(round(y))


# --------------------------------------------------------------------------- the renderer
class Prim:
    """One building part, in sprite pixels. `h(x, y)` is its height over ground pixel (x, y) (only
    read on its footprint); `roof(x, y)` colours a top pixel, `face(x, z)` a front-wall pixel at
    height z. `front` is its nearest ground row, which decides who is edged where two parts meet."""

    def __init__(self, cells, h, roof, face, ink):
        self.cells, self.h, self.roof, self.face, self.ink = cells, h, roof, face, ink
        self.front = max(y for _, y in cells)


class Scene:
    def __init__(self):
        self.prims = []

    def add(self, prim):
        self.prims.append(prim)
        return prim


class Canvas:
    """The sprite: palette indices, 0 transparent. `put` and `darken` take the keyword the terrain's
    props pass, so a palm can be drawn straight onto it."""

    def __init__(self):
        self.px = [[0] * SPRITE_W for _ in range(SPRITE_H)]

    def put(self, x, y, c, wrapped=True):
        if 0 <= x < SPRITE_W and 0 <= y < SPRITE_H:
            self.px[y][x] = c

    def darken(self, x, y, wrapped=True, steps=1):
        if 0 <= x < SPRITE_W and 0 <= y < SPRITE_H and self.px[y][x]:
            for _ in range(steps):
                self.px[y][x] = DARKER[self.px[y][x]]


def render(cv, scene, ground):
    """Draws the scene onto the sprite. `ground` is the colour it will mostly stand on, which only
    decides where a lit side needs an edge. Returns the height field, in sprite pixels."""
    owner, Hf = {}, {}
    for prim in scene.prims:
        for p in prim.cells:
            if 0 <= p[0] < SPRITE_W and 0 <= p[1] < SPRITE_H:
                h = prim.h(*p)
                if h > Hf.get(p, 0.0):
                    Hf[p], owner[p] = h, prim
    drawn = {}
    for x in range(SPRITE_W):
        ybuf, prev = SPRITE_H, None
        for y in reversed(range(SPRITE_H)):
            prim = owner.get((x, y))
            if prim is None:
                ybuf, prev = min(ybuf, y), None
                continue
            sy = y - int(round(Hf[(x, y)]))
            if sy < ybuf:
                for yy in range(max(sy, 0), ybuf):
                    cv.px[yy][x] = prim.roof(x, y) if prev is prim or yy == sy else prim.face(x, y - yy)
                    drawn[(x, yy)] = prim
                ybuf = sy
            prev = prim
    # No ink: an edge is the surface's own colour a step darker, the way the terrain draws its rocks
    # and trees -- on the shaded sides of a silhouette (right and below), and where a nearer part
    # stands in front of a farther one. A lit side gets one only where the building would otherwise
    # melt into the ground (a snow roof on snow).
    edge = []
    for (x, y), prim in drawn.items():
        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            other = drawn.get((x + dx, y + dy))
            if other is None:
                if (dx, dy) in ((1, 0), (0, 1)) or abs(_lum(cv.px[y][x]) - _lum(ground)) < 45:
                    edge.append((x, y))
                    break
            elif other is not prim and prim.front > other.front:
                edge.append((x, y))
                break
    for x, y in edge:
        cv.px[y][x] = DARKER[cv.px[y][x]]
    return Hf


def ground_marks(t, Hf):
    """What the buildings do to the tile under them: cast shadows, and a soft halo round every
    footprint, so the cluster sits down on its plate."""
    def at(x, y):
        return Hf.get((x + SHIFT[0], y + SHIFT[1]), 0.0)

    for x, y in HEX_PIXELS:
        if BORDER[y][x] < KEEP - 1 or at(x, y) > 0:
            continue
        shadow = any(at(round(x - k * 0.78), round(y - k * 0.62)) > k * 0.8 for k in range(1, 24))
        halo = any(at(x + dx, y + dy) > 0 for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if shadow or halo:
            t.px[y][x] = DARKER[t.px[y][x]]


def _lum(c):
    r, g, b = (int(PALETTE[c][1][i:i + 2], 16) for i in (1, 3, 5))
    return 0.3 * r + 0.59 * g + 0.11 * b


def _box_cells(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def _circle_cells(cx, cy, r):
    return {(x, y) for y in range(int(cy - r) - 1, int(cy + r) + 2) for x in range(int(cx - r) - 1, int(cx + r) + 2)
            if math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.2) <= r}


# --------------------------------------------------------------------------- building parts
# Every part takes layout units and draws in sprite pixels. A look is (wall lit, wall shade, roof lit,
# roof shade, ridge, dark); every surface is two tones, and `dark` -- the eave line and the door -- is
# the deepest step of the building's own hue, never ink.
def box(sc, x0, y0, x1, y1, wall, roof_h, look, roof="gable_x", door=False, light=False):
    """A rectangular building. roof: gable_x (ridge east-west), gable_y (ridge north-south), hip,
    flat (a rim round the deck), crenel (merlons round it) or teeth (pointed merlons)."""
    wl, ws, rl, rs, ridge, ink = look
    (x0, y0), (x1, y1) = mpi(x0, y0), mpi(x1 + 1, y1 + 1)
    x1, y1, wall, roof_h = x1 - 1, y1 - 1, wall * K, roof_h * K
    cx, cy = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2
    hw, hd = (x1 - x0 + 1) / 2, (y1 - y0 + 1) / 2
    flat = roof in ("flat", "crenel", "teeth")
    eave = round(wall)

    def rim(x, y):
        return x in (x0, x1) or y in (y0, y1)

    def h(x, y):
        ex, ey = 1 - abs(x + 0.5 - cx) / hw, 1 - abs(y + 0.5 - cy) / hd
        if roof == "gable_x":
            return wall + roof_h * min(ey * 1.3, 1.0)
        if roof == "gable_y":
            return wall + roof_h * min(ex * 1.3, 1.0)
        if roof == "hip":
            return wall + roof_h * min(ex * hw / max(hd, 1) * 1.2, ey * 1.3, 1.0)
        if roof == "crenel":
            return wall + ((2 if (x + y) % 2 == 0 else 1) if rim(x, y) else 0)
        if roof == "teeth":
            return wall + ((2 if (x + y) % 3 == 0 else 1) if rim(x, y) else 0)
        return wall + (1 if rim(x, y) else 0)

    top = wall + roof_h

    def roof_c(x, y):
        if flat:
            return wl if rim(x, y) else rs
        if h(x, y) >= top - 0.01:
            return ridge
        if roof == "gable_x":
            return rs if x >= x1 - max(1, int(hw * 0.35)) else rl       # the far end falls into shade
        return rl if x + 0.5 < cx else rs

    def face(x, z):
        if z > eave:                                                       # a gable end above the wall
            return wl if x + 0.5 < cx else ws
        if z == eave and not flat:
            return ink                                                     # the eave's shadow line
        if door and abs(x + 0.5 - cx) < 1.0 and z < 4:
            return ink
        if light and z == max(eave - 3, 1) and x + 0.5 - cx in (-2.5, -3.5, 2.5, 3.5):
            return C["amber"]
        return ws if x >= x1 - max(0, int(hw * 0.3)) else wl

    return sc.add(Prim(_box_cells(x0, y0, x1, y1), h, roof_c, face, ink))


def round_part(sc, cx, cy, r, wall, roof_h, look, roof="cone", door=False):
    """A round tower or hut. roof: cone, dome, crenel."""
    wl, ws, rl, rs, ridge, ink = look
    (cx, cy), r, wall, roof_h = mp(cx, cy), r * K, wall * K, roof_h * K
    cells = _circle_cells(cx, cy, r)
    eave = round(wall)

    def d(x, y):
        return math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.2) / r

    def h(x, y):
        k = min(d(x, y), 1.0)
        if roof == "cone":
            return wall + roof_h * (1 - k) + 0.6
        if roof == "dome":
            return wall + roof_h * math.sqrt(max(0.0, 1 - k * k))
        return wall + ((2 if (x + y) % 2 == 0 else 1) if k > 0.7 else 0)

    def roof_c(x, y):
        if roof == "crenel":
            return wl if d(x, y) > 0.7 else rs
        if d(x, y) < 0.18:
            return ridge
        return rl if x + 0.5 < cx - r * 0.1 else rs

    def face(x, z):
        if z == eave and roof == "cone" and wall > 1:
            return ink
        if door and abs(x + 0.5 - cx) < 1.0 and z < 4:
            return ink
        return wl if x + 0.5 < cx + r * 0.35 else ws

    return sc.add(Prim(cells, h, roof_c, face, ink))


def curtain(sc, a, b, wall, look, thick=3, crown="crenel"):
    """A stretch of wall between two ground points, `thick` deep, merlons on top."""
    wl, ws, _, rs, _, ink = look
    (ax, ay), (bx, by) = mpi(*a), mpi(*b)
    thick, wall = max(2, round(thick * K)), wall * K
    n = max(abs(bx - ax), abs(by - ay)) + 1
    cells = set()
    for i in range(n):
        f = i / max(n - 1, 1)
        px, py = round(ax + (bx - ax) * f), round(ay + (by - ay) * f)
        cells |= {(px + dx, py + dy) for dx in range(thick) for dy in range(thick)}
    step = 2 if crown == "crenel" else 3
    return sc.add(Prim(cells, lambda x, y: wall + (1 if (x + y) % step == 0 else 0),
                       lambda x, y: wl, lambda x, z: ws if z < 1 else wl, ink))


def mound(sc, cx, cy, rx, ry, height):
    """The rock a mountain fortress stands on."""
    (cx, cy), rx, ry, height = mp(cx, cy), rx * K, ry * K, height * K
    cells = {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2) for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
             if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}

    def h(x, y):
        e = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
        return height * min(1.0, (1 - min(e, 1.0)) * 2.5)

    return sc.add(Prim(cells, h, lambda x, y: C["ro3"] if x + 0.5 < cx else C["ro2"],
                       lambda x, z: C["ro2"] if x + 0.5 < cx else C["ro1"], C["ro0"]))


def tiered(sc, x, y, w, tiers, look):
    """Receding stacked tiers, a roof skirt on each. Returns where its finial goes, in layout units."""
    h0 = 0
    for k in range(tiers):
        box(sc, x + k, y + k, x + w - 1 - k, y + w - 1 - k, h0 + 3, 3, look, roof="hip", door=(k == 0), light=(k == 0))
        h0 += 5
    return x + w // 2, y + w // 2 - h0 - 1


# --------------------------------------------------------------------------- the plate and the marks
def patch(t, cx, cy, rx, ry, ramp):
    """The ground a settlement stands on, drawn on the tile at the sprite's scale: one flat tone with
    a broken rim, a clear step lighter or darker than the land round it, so the cluster sits on a
    plate and reads from across the map."""
    cx, cy = mp(cx, cy)
    cx, cy, rx, ry = cx - SHIFT[0], cy - SHIFT[1], rx * K, ry * K
    for x, y in HEX_PIXELS:
        e = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
        if BORDER[y][x] >= KEEP - 1 and e < 1.0:
            t.px[y][x] = ramp[1] if e < 0.7 or bayer(x, y) < 0.5 else ramp[0]


# The marks draw onto the sprite at a layout point.
def pennant(cv, x, y, colour):
    x, y = mpi(x, y)
    for k in range(5):
        cv.put(x, y - k, C["di0"])
    for dx, dy in ((1, -4), (2, -4), (3, -4), (4, -4), (1, -3), (2, -3), (3, -3)):
        cv.put(x + dx, y + dy, colour)


def finial(cv, x, y):
    x, y = mpi(x, y)
    cv.put(x, y, C["de3"])
    cv.put(x, y - 1, C["de4"])
    cv.put(x, y - 2, C["de5"])


def poles(cv, x, y):
    """Two poles crossed over a thatch apex."""
    x, y = mpi(x, y)
    for k in range(3):
        cv.put(x - 1 - k, y - 1 - k, C["di1"])
        cv.put(x + 1 + k, y - 1 - k, C["di1"])


# --------------------------------------------------------------------------- the six peoples
def L(*names):
    return tuple(C[n] for n in names)


LOOKS = {
    "grass": dict(cottage=L("pl3", "pl2", "rf2", "rf1", "rf3", "rf0"),
                  slate=L("pl3", "pl2", "ro3", "ro2", "ro4", "ro1"),
                  stone=L("ro4", "ro3", "ro3", "ro2", "ro4", "ro1"),
                  tower=L("ro4", "ro3", "ro2", "ro1", "ro3", "ro0"),
                  patch=R("di4", "di5")),
    "dirt": dict(hut=L("di3", "di2", "pl2", "st2", "pl3", "di0"),
                 rubble=L("sc3", "sc2", "sc3", "sc1", "ro4", "sc1"),
                 grim=L("ro2", "ro1", "ro2", "ro0", "ro3", "ro0"),
                 patch=R("di2", "di1")),
    "desert": dict(earth=L("rf3", "rf2", "de3", "de2", "de4", "rf0"),
                   patch=R("de4", "de5")),
    "ice": dict(lodge=L("di2", "di1", "sn4", "sn3", "sn5", "di0"),
                ice=L("sn5", "sn3", "ice_lt", "ice", "sn5", "sn1"),
                patch=R("sn3", "sn2")),
    "forest": dict(hut=L("di2", "di1", "di4", "di3", "di5", "di0"),
                   stone=L("pl2", "pl1", "pl2", "pl1", "pl3", "pl0"),
                   patch=R("di2", "di1")),
    "mountains": dict(block=L("pl3", "pl2", "pl1", "pl1", "pl3", "pl0"),
                      red=L("pl3", "pl2", "rf2", "rf1", "rf3", "rf0"),
                      patch=R("sc2", "sc3")),
}


# Each layout paints its plate on the tile `t`, adds its buildings to `sc` and returns the marks
# (Callables) that go on the sprite `cv` once the buildings are drawn.
def grass_town(t, cv, sc, lk, tier):
    marks = []
    if tier == "small":
        patch(t, 27, 37, 14, 8, lk["patch"])
        box(sc, 13, 27, 25, 33, 5, 6, lk["cottage"], light=True)
        box(sc, 29, 31, 38, 39, 5, 5, lk["cottage"], roof="gable_y", door=True)
    elif tier == "medium":
        patch(t, 28, 38, 17, 9, lk["patch"])
        box(sc, 18, 21, 33, 28, 5, 6, lk["slate"], light=True)
        box(sc, 9, 33, 20, 39, 5, 5, lk["cottage"])
        box(sc, 24, 36, 33, 44, 5, 5, lk["cottage"], roof="gable_y", door=True)
        round_part(sc, 40, 36, 3.2, 10, 7, lk["tower"])
        marks.append(lambda: pennant(cv, 39.6, 18.4, C["brick"]))
    else:
        patch(t, 28, 38, 18, 9, lk["patch"])
        stone, tower = lk["stone"], lk["tower"]
        round_part(sc, 16, 30, 3.2, 9, 6, tower)
        round_part(sc, 40, 30, 3.2, 9, 6, tower)
        box(sc, 23, 21, 33, 29, 11, 5, tower, roof="hip", light=True)
        curtain(sc, (13, 41), (42, 41), 6, stone)
        box(sc, 24, 39, 32, 45, 8, 0, stone, roof="crenel", door=True)
        round_part(sc, 13, 42, 4.0, 9, 7, tower)
        round_part(sc, 43, 42, 4.0, 9, 7, tower)
        marks.append(lambda: pennant(cv, 28, 9, C["brick"]))
    return marks


def dirt_town(t, cv, sc, lk, tier):
    hut, marks = lk["hut"], []

    def cone(x, y, r):
        round_part(sc, x, y, r, 4, round(r * 1.1), hut, door=True)
        marks.append(lambda: poles(cv, x - 0.4, y - 4 - round(r * 1.1) - 0.6))

    if tier == "small":
        patch(t, 28, 37, 14, 8, lk["patch"])
        cone(21, 32, 6.0)
        cone(35, 38, 5.0)
    elif tier == "medium":
        patch(t, 28, 38, 17, 9, lk["patch"])
        box(sc, 15, 23, 30, 30, 6, 0, lk["rubble"], roof="crenel", light=True)
        cone(40, 32, 4.6)
        cone(16, 40, 5.0)
        cone(30, 42, 5.4)
    else:
        patch(t, 28, 39, 18, 8, lk["patch"])
        box(sc, 11, 33, 19, 39, 4, 0, lk["rubble"], roof="crenel")
        box(sc, 37, 33, 45, 39, 4, 0, lk["rubble"], roof="crenel")
        box(sc, 23, 26, 33, 34, 16, 0, lk["grim"], roof="crenel", door=True, light=True)   # the keep, open-topped
        curtain(sc, (10, 42), (44, 42), 4, lk["rubble"])
    return marks


def desert_town(t, cv, sc, lk, tier):
    earth, marks = lk["earth"], []
    if tier == "small":
        patch(t, 28, 38, 14, 8, lk["patch"])
        box(sc, 33, 24, 37, 28, 11, 0, earth, roof="teeth")
        box(sc, 15, 27, 26, 34, 7, 0, earth, roof="flat", light=True)
        box(sc, 27, 32, 38, 40, 5, 0, earth, roof="flat", door=True)
        marks.append(lambda: palm(cv, *mpi(43, 43), 3, h=13))
    elif tier == "medium":
        patch(t, 28, 40, 17, 8, lk["patch"])
        box(sc, 25, 19, 30, 24, 12, 0, earth, roof="teeth")
        box(sc, 17, 26, 28, 34, 8, 0, earth, roof="flat")
        box(sc, 28, 25, 39, 33, 9, 0, earth, roof="flat", light=True)
        box(sc, 12, 34, 22, 41, 5, 0, earth, roof="flat")
        box(sc, 33, 34, 44, 41, 5, 0, earth, roof="flat", door=True)
        marks.append(lambda: palm(cv, *mpi(26, 46), 3, h=12))
    else:
        patch(t, 28, 38, 18, 9, lk["patch"])
        curtain(sc, (11, 24), (44, 24), 7, earth, crown="teeth")
        curtain(sc, (11, 24), (11, 42), 7, earth, crown="teeth")
        curtain(sc, (43, 24), (43, 42), 7, earth, crown="teeth")
        box(sc, 23, 27, 33, 35, 13, 0, earth, roof="flat", light=True)
        curtain(sc, (11, 42), (44, 42), 7, earth, crown="teeth")
        box(sc, 9, 40, 15, 46, 10, 0, earth, roof="teeth")
        box(sc, 41, 40, 47, 46, 10, 0, earth, roof="teeth")
        box(sc, 24, 40, 32, 46, 9, 0, earth, roof="teeth", door=True)
    return marks


def ice_town(t, cv, sc, lk, tier):
    lodge, ice_c = lk["lodge"], lk["ice"]
    if tier == "small":
        patch(t, 27, 37, 14, 8, lk["patch"])
        box(sc, 13, 27, 25, 33, 4, 6, lodge, light=True)
        box(sc, 29, 31, 39, 40, 4, 5, lodge, roof="gable_y", door=True, light=True)
    elif tier == "medium":
        patch(t, 28, 38, 17, 9, lk["patch"])
        box(sc, 17, 21, 34, 28, 5, 7, lodge, light=True)
        box(sc, 9, 34, 19, 40, 4, 5, lodge, light=True)
        box(sc, 32, 35, 42, 43, 4, 5, lodge, roof="gable_y", door=True, light=True)
    else:
        patch(t, 28, 39, 18, 8, lk["patch"])
        round_part(sc, 22, 28, 2.2, 2, 14, ice_c)
        round_part(sc, 34, 28, 2.2, 2, 14, ice_c)
        round_part(sc, 28, 34, 9.5, 3, 9, ice_c, roof="dome", door=True)
        round_part(sc, 14, 37, 2.4, 2, 13, ice_c)
        round_part(sc, 42, 37, 2.4, 2, 13, ice_c)
        curtain(sc, (12, 43), (43, 43), 4, ice_c)
    return []


def forest_town(t, cv, sc, lk, tier):
    hut, marks = lk["hut"], []

    def cone(x, y, r):
        round_part(sc, x, y, r, 3, round(r * 1.7), hut, door=True)
        marks.append(lambda: finial(cv, x - 0.4, y - 3 - round(r * 1.7) - 1.0))

    if tier == "small":
        patch(t, 28, 37, 14, 8, lk["patch"])
        cone(21, 33, 5.6)
        cone(35, 38, 4.6)
    elif tier == "medium":
        patch(t, 28, 38, 17, 9, lk["patch"])
        fx, fy = tiered(sc, 21, 21, 14, 3, hut)
        marks.append(lambda: finial(cv, fx, fy))
        cone(13, 39, 4.4)
        cone(43, 39, 4.4)
    else:
        patch(t, 28, 39, 18, 8, lk["patch"])
        fx, fy = tiered(sc, 20, 22, 16, 4, hut)
        curtain(sc, (12, 42), (43, 42), 5, lk["stone"])
        a = tiered(sc, 8, 38, 7, 2, hut)
        b = tiered(sc, 41, 38, 7, 2, hut)
        marks += [lambda: finial(cv, fx, fy), lambda: finial(cv, *a), lambda: finial(cv, *b)]
    return marks


def mountains_town(t, cv, sc, lk, tier):
    block, red, marks = lk["block"], lk["red"], []

    def spire(x, y, r, wall, cone, flag=False):
        round_part(sc, x, y, r, wall, cone, red)
        if flag:
            marks.append(lambda: pennant(cv, x - 0.4, y - wall - cone - 0.6, C["brick"]))

    if tier == "small":
        patch(t, 28, 38, 14, 8, lk["patch"])
        spire(34, 28, 2.8, 9, 6)
        box(sc, 13, 28, 25, 35, 6, 0, block, roof="flat", light=True)
        box(sc, 27, 33, 37, 40, 5, 0, block, roof="flat", door=True)
    elif tier == "medium":
        patch(t, 28, 40, 17, 8, lk["patch"])
        box(sc, 28, 24, 40, 32, 9, 0, block, roof="flat", light=True)
        box(sc, 15, 26, 27, 34, 7, 0, block, roof="flat")
        box(sc, 10, 35, 21, 41, 4, 0, block, roof="flat")
        box(sc, 33, 35, 45, 41, 4, 0, block, roof="flat")
        spire(27, 39, 3.2, 12, 7, flag=True)
    else:
        patch(t, 28, 41, 18, 7, lk["patch"])
        mound(sc, 28, 34, 17, 11, 5.0)
        box(sc, 15, 27, 26, 34, 10, 0, block, roof="flat")
        box(sc, 30, 26, 41, 34, 11, 0, block, roof="flat", light=True)
        spire(28, 33, 3.8, 15, 9, flag=True)
        curtain(sc, (12, 42), (43, 42), 7, block)
        box(sc, 23, 40, 33, 45, 8, 0, block, roof="crenel", door=True)
    return marks


def calm(t, radius):
    """Quiet the ground in the clearing: each pixel takes its neighbourhood's commonest colour, twice,
    so the land's grain gives way to broad patches and the settlement is the busiest thing there."""
    zone = [(x, y) for x, y in HEX_PIXELS if BORDER[y][x] >= KEEP
            and math.hypot(x + 0.5 - 28, (y + 0.5 - 33) * 1.1) < radius - 1]
    for _ in range(2):
        before = {p: t.px[p[1]][p[0]] for p in HEX_PIXELS}
        for x, y in zone:
            near = [before[q] for q in ((x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)) if q in before]
            t.px[y][x] = max(set(near), key=near.count)


BUILDERS = {"grass": grass_town, "dirt": dirt_town, "desert": desert_town, "ice": ice_town, "forest": forest_town,
            "mountains": mountains_town}


# --------------------------------------------------------------------------- the tile and the sprite
def build(env, tier):
    """The settlement's ground tile (for the hex atlas) and its building sprite (a Canvas)."""
    base = ENVS[env]("base")
    bare = ENVS[env]("base", objects=False)
    inner = ENVS["grass"]("base", objects=False) if env == "forest" else bare
    t = bare.copy(f"town_{env}_{tier}", "towns")
    radius = CLEARING[tier]
    for x, y in HEX_PIXELS:
        d = math.hypot(x + 0.5 - 28, (y + 0.5 - 33) * 1.1)
        k = min(max((radius - d) / 3.0, 0.0), 1.0) * min(max((BORDER[y][x] - 6.0) / 2.0, 0.0), 1.0)
        if k > bayer(x, y):
            t.px[y][x] = inner.px[y][x]
    calm(t, radius)
    if env == "forest":                                             # the border trees, minus those in the clearing
        for x, y in sorted(forest_shared_trees(), key=lambda p: (p[1], p[0])):
            if math.hypot(x + 0.5 - 28, (y + 0.5 - 33) * 1.1) > radius - 3:
                forest_tree(t, x, y)
    sc, cv, lk = Scene(), Canvas(), LOOKS[env]
    marks = BUILDERS[env](t, cv, sc, lk, tier)
    Hf = render(cv, sc, lk["patch"][1])
    for fn in marks:
        fn()
    ground_marks(t, Hf)
    for x, y in HEX_PIXELS:
        if BORDER[y][x] < RING_KEEP:
            t.px[y][x] = base.px[y][x]
    return t, cv


def town(env, tier):
    return build(env, tier)[0]


def all_towns():
    return [town(env, tier) for env in ENV_ORDER for tier in TIERS]


def sprites():
    """Every building sprite as an RGBA image, by the tile's name."""
    from PIL import Image
    from preview import RGBA
    out = {}
    for env in ENV_ORDER:
        for tier in TIERS:
            cv = build(env, tier)[1]
            img = Image.new("RGBA", (SPRITE_W, SPRITE_H))
            img.putdata([RGBA[c] if c else (0, 0, 0, 0) for row in cv.px for c in row])
            out[f"town_{env}_{tier}"] = img
    return out
