"""Building and prop primitives for detailed towns (56x64).

Convention: roofs are seen from above, buildings show a thin south-facing front wall.
Light from the top-left, 1 px ink outline, cast shadows toward the bottom-right.
All drawing is clipped to the hex (never wrapped).
"""
import math

from hexlib import C, DARKER, bayer
from stamps import dome, edge_ring, shade_dome, shadow_set


def P(t, x, y, c):
    t.put(x, y, c, wrapped=False)


def shade(t, cells, dx=3, dy=2):
    for x, y in shadow_set(cells, dx, dy):
        t.darken(x, y, wrapped=False)


def rect(x0, y0, w, h):
    return {(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w)}


def disc(cx, cy, r):
    return {(x, y) for y in range(int(cy - r) - 1, int(cy + r) + 2)
            for x in range(int(cx - r) - 1, int(cx + r) + 2) if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r}


def ramp3(names):
    return tuple(C[n] for n in names)


# --------------------------------------------------------------------------- walls & roofs
def masonry(x, y, base, dark, kind):
    """Surface texture for vertical faces: stone blocks, horizontal logs, or plaster."""
    if kind == "stone":
        return dark if (y % 2 == 0 and x % 4 == 0) or (y % 2 == 1 and x % 4 == 2) else base
    if kind == "log":
        return dark if y % 2 == 1 else base
    if kind == "plank":
        return dark if x % 3 == 0 else base
    return base


def hip_roof(t, x0, y0, w, d, roof):
    ridge, lit, dark = ramp3(roof)
    horizontal = w >= d
    for y in range(y0, y0 + d):
        for x in range(x0, x0 + w):
            if x in (x0, x0 + w - 1) or y in (y0, y0 + d - 1):
                P(t, x, y, C["ink"])
                continue
            top, bottom, left, right = y - y0, y0 + d - 1 - y, x - x0, x0 + w - 1 - x
            vert, horz = min(top, bottom), min(left, right)
            if horizontal and top == bottom and horz >= top:
                c = ridge
            elif not horizontal and left == right and vert >= left:
                c = ridge
            elif vert == horz:                                       # hip lines
                c = ridge if top <= bottom and left <= right else lit if top <= bottom else DARKER[dark]
            else:
                if vert < horz:
                    face = lit if top < bottom else dark
                    stagger = (y - y0) % 2 == 0 and (x + (y - y0) // 2) % 3 == 0
                else:
                    face = lit if left < right else dark
                    stagger = (x - x0) % 2 == 0 and (y + (x - x0) // 2) % 3 == 0
                c = DARKER[face] if stagger else face
            P(t, x, y, c)


def front_wall(t, x0, y, w, wall, kind, door=None, windows=(), h=5, window=C["amber"]):
    lit, base, dark = ramp3(wall)
    for yy in range(y, y + h):
        for x in range(x0, x0 + w):
            if x in (x0, x0 + w - 1) or yy == y + h - 1:
                c = C["ink"]
            elif yy == y:
                c = dark                                   # eave shadow
            else:
                c = masonry(x, yy - y, lit if x == x0 + 1 else base, dark, kind)
            P(t, x, yy, c)
    for wx in windows:
        P(t, wx, y + 1, window)
        P(t, wx, y + 2, DARKER[window])
    if door is not None:
        for dy in (1, 2, 3):
            P(t, door, y + dy, C["earth"])
            P(t, door + 1, y + dy, C["earth_dk"])
        P(t, door, y + 1, C["ink"])
        P(t, door + 1, y + 1, C["ink"])
        P(t, door + 1, y + 2, C["amber"])


def chimney(t, x, y, smoke=True):
    for dx, dy, c in ((0, 0, "ink"), (1, 0, "ink"), (0, 1, "stone_lt"), (1, 1, "stone"),
                      (0, 2, "slate"), (1, 2, "slate_dk")):
        P(t, x + dx, y + dy, C[c])
    if smoke:
        P(t, x + 1, y - 2, C["mist"])
        P(t, x + 2, y - 3, C["mist"])
        P(t, x + 2, y - 4, C["stone_lt"])


def building(t, x0, y0, w, d, st, door="auto", windows="auto", chimney_at="auto", wall_h=5):
    shade(t, rect(x0, y0, w, d + wall_h))
    hip_roof(t, x0, y0, w, d, st["roof"])
    if door == "auto":
        door = x0 + w // 2 - 1
    if windows == "auto":
        cand = [x0 + 2, x0 + w - 3] + ([x0 + 5, x0 + w - 6] if w >= 15 else [])
        windows = [x for x in cand if door is None or x not in (door - 1, door, door + 1, door + 2)]
    front_wall(t, x0, y0 + d, w, st["wall"], st["kind"], door, windows, wall_h)
    if chimney_at == "auto" and w >= 9:
        chimney(t, x0 + w - 4, y0 + 1)


def flat_building(t, x0, y0, w, d, st, dome_roof=False, door="auto", wall_h=5):
    shade(t, rect(x0, y0, w, d + wall_h))
    ridge, lit, dark = ramp3(st["roof"])
    for y in range(y0, y0 + d):
        for x in range(x0, x0 + w):
            if x in (x0, x0 + w - 1) or y in (y0, y0 + d - 1):
                c = C["ink"]
            elif x == x0 + 1 or y == y0 + 1:
                c = ridge                                  # lit parapet
            elif x == x0 + w - 2 or y == y0 + d - 2:
                c = dark                                   # shaded parapet
            else:
                c = lit
            P(t, x, y, c)
    if dome_roof:
        cx, cy = x0 + w / 2, y0 + d / 2
        shade_dome(t, dome(cx, cy, min(w, d) / 2 - 1.2, min(w, d) / 2 - 1.5),
                   [C["sand_dk"], C["sand"], C["sand_lt"], C["bone"]],
                   wrapped=False, outline=C["ink"], shadow_offset=None)
        P(t, int(cx), int(cy - min(w, d) / 2 + 1), C["amber"])
    elif w >= 8:
        for i in range(3):                                 # drying rug on the roof
            P(t, x0 + 3 + i, y0 + 3, C["brick"] if i % 2 else C["amber"])
            P(t, x0 + 3 + i, y0 + 4, C["brick_dk"] if i % 2 else C["rust"])
        P(t, x0 + w - 4, y0 + d - 4, C["soil_lt"])             # water jar
        P(t, x0 + w - 4, y0 + d - 3, C["earth"])
    lit_w, base, dark_w = ramp3(st["wall"])
    y = y0 + d
    for yy in range(y, y + wall_h):
        for x in range(x0, x0 + w):
            c = C["ink"] if x in (x0, x0 + w - 1) or yy == y + wall_h - 1 else dark_w if yy == y else base
            P(t, x, yy, c)
    door = x0 + w // 2 - 1 if door == "auto" else door
    P(t, door, y + 1, C["ink"])
    for dy in (2, 3):
        P(t, door - 1 if dy == 3 else door, y + dy, C["ink"])
        P(t, door, y + dy, C["ink"])
        P(t, door + 1, y + dy, C["ink"])
    for wx in (x0 + 2, x0 + w - 3):
        P(t, wx, y + 2, C["ink"])


def round_tower(t, cx, cy, r, st, cone=True, flag=None, wall_h=4):
    top = disc(cx, cy, r)
    face = set()
    for x in {p[0] for p in top}:
        bottom = max(y for px, y in top if px == x)
        face |= {(x, bottom + k) for k in range(1, wall_h + 1)}
    shade(t, top | face)
    lit, base, dark = ramp3(st["fort"])
    xs = sorted({p[0] for p in face})
    for x, y in face:
        edge = x in (xs[0], xs[-1]) or (x, y + 1) not in face
        P(t, x, y, C["ink"] if edge else masonry(x, y, base, dark, st["fort_kind"]))
    slit = int(cx)
    P(t, slit, max(y for x, y in face if x == slit) - 2, C["ink"])
    ring = edge_ring(top)
    for x, y in top:                                   # stone top with a ring of merlons
        dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
        if (x, y) in ring:
            c = C["ink"]
        elif math.hypot(dx, dy) > 1 - 1.9 / r:
            merlon = int((math.atan2(dy, dx) / math.tau) * 14) % 2 == 0
            c = (lit if dx + dy < 0.2 else base) if merlon else dark
        else:
            c = DARKER[dark]
        P(t, x, y, c)
    if cone:                                           # conical roof set inside the parapet
        ridge, rlit, rdark = ramp3(st["roof"])
        ccx, ccy, cr = cx, cy - 1.0, r - 1.4
        roof = disc(ccx, ccy, cr)
        rring = edge_ring(roof)
        for x, y in roof:
            dx, dy = (x + 0.5 - ccx) / cr, (y + 0.5 - ccy) / cr
            dist = math.hypot(dx, dy)
            seam = abs(((math.atan2(dy, dx) / math.tau * 6) % 1) - 0.5) > 0.4 and dist > 0.3
            c = ridge if dist < 0.3 else rlit if dx + dy < 0.1 else rdark
            if seam:
                c = DARKER[c]
            if (x, y) in rring and dx + dy > -0.3:
                c = C["ink"]
            P(t, x, y, c)
    if flag is not None:
        fx, fy = int(cx), int(cy)
        for k in range(4):
            P(t, fx, fy - k, C["ink"])
        for dx, dy in ((1, -3), (2, -3), (1, -2)):
            P(t, fx + dx, fy + dy, C[flag])
        P(t, fx + 2, fy - 2, DARKER[C[flag]])


def wall_h(t, x0, x1, y, st, face_h=3):
    lit, base, dark = ramp3(st["fort"])
    cells = rect(x0, y, x1 - x0 + 1, 4 + face_h)
    shade(t, cells, 2, 2)
    for x in range(x0, x1 + 1):
        end = x in (x0, x1)
        P(t, x, y, C["ink"] if end or x % 2 == 0 else lit)        # merlons
        P(t, x, y + 1, C["ink"] if end else lit)
        P(t, x, y + 2, C["ink"] if end else base)
        P(t, x, y + 3, C["ink"] if end else dark)
        for k in range(face_h):
            yy = y + 4 + k
            P(t, x, yy, C["ink"] if end or k == face_h - 1 else masonry(x, k, base, dark, st["fort_kind"]))


def wall_v(t, x, y0, y1, st, face_h=3):
    lit, base, dark = ramp3(st["fort"])
    cells = rect(x, y0, 4, y1 - y0 + 1 + face_h)
    shade(t, cells, 2, 2)
    for y in range(y0, y1 + 1):
        P(t, x, y, C["ink"] if y % 2 == 0 else lit)
        P(t, x + 1, y, lit)
        P(t, x + 2, y, base)
        P(t, x + 3, y, C["ink"])
    for k in range(face_h):
        for dx in range(4):
            P(t, x + dx, y1 + 1 + k, C["ink"] if dx in (0, 3) or k == face_h - 1 else masonry(x + dx, k, base, dark, st["fort_kind"]))


def gatehouse(t, cx, y, st, w=14, d=6, face_h=8):
    x0 = cx - w // 2
    lit, base, dark = ramp3(st["fort"])
    shade(t, rect(x0, y, w, d + face_h))
    for yy in range(y, y + d):
        for x in range(x0, x0 + w):
            edge = x in (x0, x0 + w - 1) or yy in (y, y + d - 1)
            c = C["ink"] if edge and (yy != y or x % 2 == 0) else lit if yy <= y + 1 or x == x0 + 1 else base
            P(t, x, yy, c)
    for k in range(face_h):
        for x in range(x0, x0 + w):
            edge = x in (x0, x0 + w - 1) or k == face_h - 1
            P(t, x, y + d + k, C["ink"] if edge else dark if k == 0 else masonry(x, k, base, dark, st["fort_kind"]))
    for k in range(1, face_h - 1):                                   # arched wooden door
        half = 1 if k == 1 else 2
        for x in range(cx - half, cx + half):
            c = C["ink"] if k == 1 else C["soil"] if x < cx else C["earth"]
            if k > 1 and (x + k) % 3 == 0:
                c = C["ink"]                                         # studs / planks
            P(t, x, y + d + k, c)


# --------------------------------------------------------------------------- props
def well(t, cx, cy):
    top = disc(cx, cy, 2.8)
    shade(t, top, 2, 2)
    ring = edge_ring(top)
    for x, y in top:                                   # lit/shaded stone rim, small dark water
        if (x, y) in ring:
            c = C["stone_lt"] if x + y < cx + cy else C["slate"]
        else:
            c = C["abyss"]
        P(t, x, y, c)
    P(t, int(cx) - 1, int(cy) - 1, C["ice_dk"])
    P(t, int(cx), int(cy) - 1, C["soil"])              # rope
    for k in (-3, 3):                                                # roof posts + beam
        P(t, int(cx) + k, int(cy) - 1, C["soil"])
        P(t, int(cx) + k, int(cy), C["earth"])
    for x in range(int(cx) - 3, int(cx) + 4):
        P(t, x, int(cy) - 2, C["soil_lt"])


def fountain(t, cx, cy):
    top = disc(cx, cy, 4.2)
    shade(t, top, 2, 2)
    ring = edge_ring(top)
    inner = disc(cx, cy, 3.0)
    for x, y in top:
        if (x, y) in ring:
            c = C["stone_lt"] if x + y < cx + cy else C["slate"]
        elif (x, y) in inner:
            c = C["ice_lt"] if x + y < cx + cy - 2 else C["ice"]
        else:
            c = C["stone"]
        P(t, x, y, c)
    P(t, int(cx), int(cy), C["snow"])
    P(t, int(cx) - 1, int(cy) - 1, C["snow"])


def stall(t, x, y, stripes=("brick", "bone")):
    shade(t, rect(x, y, 7, 6), 2, 2)
    for dx in range(7):
        col = C[stripes[dx % 2]]
        P(t, x + dx, y, C["ink"])
        P(t, x + dx, y + 1, col)
        P(t, x + dx, y + 2, col)
        P(t, x + dx, y + 3, DARKER[col])
    P(t, x, y + 4, C["soil"])
    P(t, x + 6, y + 4, C["soil"])
    for dx, c in ((1, "amber"), (2, "leaf"), (3, "rust"), (4, "leaf_lt"), (5, "amber")):
        P(t, x + dx, y + 4, C[c])
    for dx in range(7):
        P(t, x + dx, y + 5, C["ink"] if dx in (0, 6) else C["earth"])


def crate(t, x, y):
    shade(t, rect(x, y, 4, 4), 1, 1)
    for dx, dy in rect(0, 0, 4, 4):
        edge = dx in (0, 3) or dy in (0, 3)
        P(t, x + dx, y + dy, C["ink"] if edge else C["soil_lt"] if dx + dy == 2 else C["soil"])


def barrel(t, x, y):
    shade(t, rect(x, y, 3, 4), 1, 1)
    for dx, dy, c in ((1, 0, "soil_lt"), (0, 1, "soil"), (1, 1, "earth_dk"), (2, 1, "soil"),
                      (0, 2, "earth"), (1, 2, "soil"), (2, 2, "earth"), (0, 3, "ink"), (1, 3, "ink"), (2, 3, "ink"),
                      (0, 0, "ink"), (2, 0, "ink")):
        P(t, x + dx, y + dy, C[c])


def haystack(t, cx, cy):
    shade_dome(t, dome(cx, cy, 3.6, 3.0, lump=0.1), [C["sand_dk"], C["sand"], C["sand_lt"]],
               wrapped=False, outline=C["soil_lt"], shadow_offset=(2, 2))


def crop_field(t, x0, y0, w, h, crop="wheat"):
    rows = {"wheat": ("amber", "sand_dk"), "green": ("leaf_lt", "leaf_dk"), "cabbage": ("leaf", "olive")}[crop]
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if y in (y0, y0 + h - 1) or x in (x0, x0 + w - 1):
                c = C["soil_lt"] if (x - x0) % 3 == 0 or y in (y0, y0 + h - 1) and x in (x0, x0 + w - 1) else C["soil"]
            elif (y - y0) % 2 == 1:
                c = C[rows[0]] if (x + y) % 3 else C[rows[1]]
            else:
                c = C["earth"]
            P(t, x, y, c)


def small_tree(t, cx, cy, kind="leaf"):
    ramps = {"leaf": ([C["leaf_dk"], C["leaf"], C["leaf_lt"]], C["pine"]),
             "snow": ([C["pine"], C["ice_lt"], C["snow"]], C["pine_dk"]),
             "pine": ([C["pine_dk"], C["pine"], C["leaf_dk"]], C["ink"])}
    ramp, outline = ramps[kind]
    P(t, int(cx), int(cy) + 4, C["earth"])
    P(t, int(cx), int(cy) + 3, C["earth_dk"])
    shade_dome(t, dome(cx, cy, 3.8, 3.4, lump=0.25 if kind == "pine" else 0.15, lobes=7 if kind == "pine" else 3),
               ramp, wrapped=False, outline=outline, shadow_offset=(3, 2))


def palm(t, cx, cy):
    for k in range(5):
        P(t, cx + (1 if k > 2 else 0), cy + k, C["soil_lt"] if k % 2 else C["soil"])
    shade(t, {(cx + dx, cy - 1 + dy) for dx in range(-5, 6) for dy in range(-3, 3) if abs(dx) + abs(dy) * 2 < 6}, 3, 2)
    for ang in range(6):
        a = ang / 6 * math.tau + 0.3
        for k in range(1, 6):
            x = int(round(cx + math.cos(a) * k))
            y = int(round(cy - 1 + math.sin(a) * k * 0.7 + (k * k) * 0.06))
            P(t, x, y, C["leaf_lt"] if math.cos(a) + math.sin(a) < 0 else C["leaf_dk"] if k > 3 else C["leaf"])
    P(t, cx, cy - 1, C["amber"])


def igloo(t, cx, cy):
    blob = dome(cx, cy, 5.5, 4.5)
    shade_dome(t, blob, [C["ice"], C["ice_lt"], C["snow"]], wrapped=False, outline=C["ice_dk"], shadow_offset=(3, 2))
    for (x, y), (h, nx, ny) in blob.items():
        if y % 2 == 0 and (x + y // 2) % 4 == 0 and h < 0.9:
            P(t, x, y, C["ice"])
    for x in (int(cx) - 1, int(cx), int(cx) + 1):
        for y in (int(cy) + 3, int(cy) + 4):
            P(t, x, y, C["abyss"])
    P(t, int(cx), int(cy) + 2, C["ice_dk"])


def pool(t, cx, cy, rx, ry):
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            e = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if e <= 1.0:
                c = C["ice_dk"] if e > 0.7 and x + y > cx + cy else C["ice_lt"] if e < 0.35 and x + y < cx + cy else C["ice"]
                P(t, x, y, c)
            elif e <= 1.5:
                P(t, x, y, C["sand_lt"] if x + y < cx + cy else C["sand_dk"])
    for dx, dy in ((-rx + 1, -1), (-rx + 1, 0), (rx - 1, 1)):
        P(t, int(cx + dx), int(cy + dy), C["leaf_dk"])


def log_pile(t, x, y, n=4):
    shade(t, rect(x, y, n * 3 + 1, 6), 2, 2)
    for i in range(n):
        for j, yy in enumerate((y + 3, y)):
            if j == 1 and i == n - 1:
                continue
            lx = x + i * 3 + (1 if j else 0)
            for dx, dy, c in ((0, 0, "ink"), (1, 0, "soil_lt"), (2, 0, "ink"), (0, 1, "soil"), (1, 1, "sand_dk"),
                              (2, 1, "earth"), (0, 2, "ink"), (1, 2, "earth"), (2, 2, "ink")):
                P(t, lx + dx, yy + dy, C[c])


def mine_entrance(t, cx, cy):
    blob = dome(cx, cy, 9.0, 6.0, seed=7, lump=0.2)
    shade_dome(t, blob, [C["slate"], C["stone"], C["stone_lt"], C["mist"]], wrapped=False,
               outline=C["slate_dk"], shadow_offset=(3, 2))
    by = int(cy) + 2
    for dy in range(4):
        for dx in (-2, -1, 0, 1):
            P(t, int(cx) + dx, by + dy, C["ink"])
    for dy in range(-1, 4):
        P(t, int(cx) - 3, by + dy, C["soil_lt"])
        P(t, int(cx) + 2, by + dy, C["soil"])
    for dx in range(-3, 3):
        P(t, int(cx) + dx, by - 1, C["soil_lt"])
    for k in range(4, 12):                                           # rails + sleepers
        yy = by + k
        P(t, int(cx) - 2, yy, C["slate"])
        P(t, int(cx) + 1, yy, C["slate"])
        if k % 2 == 0:
            P(t, int(cx) - 1, yy, C["earth"])
            P(t, int(cx), yy, C["earth"])
    for dx, dy, c in ((-1, 7, "ink"), (0, 7, "ink"), (-2, 8, "slate"), (-1, 8, "amber"), (0, 8, "rust"),
                      (1, 8, "slate"), (-2, 9, "ink"), (1, 9, "ink")):
        P(t, int(cx) + dx, by + dy, C[c])                            # minecart with ore


def windmill(t, cx, cy, st):
    building(t, cx - 4, cy - 2, 9, 6, st, door=cx - 1, windows=[], chimney_at=None)
    hub = (cx, cy + 1)
    blades = [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for bx, by in blades:
        for k in range(2, 7):
            t.darken(hub[0] + bx * k + 2, hub[1] + by * k + 2, wrapped=False)
    for bx, by in blades:
        for k in range(1, 7):
            x, y = hub[0] + bx * k, hub[1] + by * k
            P(t, x, y, C["soil"])
            if k > 2:
                P(t, x + bx, y, C["bone"] if by < 0 else C["mist"])
    P(t, hub[0], hub[1], C["ink"])


def villager(t, x, y, body="brick"):
    t.darken(x + 1, y + 2, wrapped=False)
    P(t, x, y, C["sand_lt"])
    P(t, x, y + 1, C[body])
    P(t, x, y + 2, DARKER[C[body]])


def banner(t, x, y, color="brick"):
    for k in range(5):
        P(t, x, y + k, C["ink"])
    for dx, dy in ((1, 0), (2, 0), (1, 1), (2, 1), (1, 2)):
        P(t, x + dx, y + dy, C[color])
    P(t, x + 2, y + 2, DARKER[C[color]])


def lamp(t, x, y):
    P(t, x, y, C["amber"])
    P(t, x, y + 1, C["ink"])
    P(t, x, y + 2, C["ink"])
    t.darken(x + 1, y + 3, wrapped=False)


def ice_hole(t, cx, cy):
    for dx, dy in rect(-2, -1, 5, 3):
        e = (dx / 2.5) ** 2 + (dy / 1.5) ** 2
        if e <= 1.0:
            P(t, cx + dx, cy + dy, C["abyss"] if e < 0.6 else C["ice_dk"])
    P(t, cx - 2, cy - 2, C["snow"])
    P(t, cx + 3, cy + 1, C["ice_dk"])


def path(t, pts, color, width=1.6):
    """Dithered worn path through a list of points (ground layer)."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            px, py = x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    d = math.hypot(dx, dy)
                    if d <= width or (d <= width + 1 and bayer(int(px) + dx, int(py) + dy) < 0.45):
                        P(t, int(px) + dx, int(py) + dy, C[color])
