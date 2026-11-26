"""Generate SakedMap/Data/M<mapID>.lua for WoW Forever dungeons.

    python3 tools/build.py            # every supported dungeon
    python3 tools/build.py 229 329    # only these instance map IDs

Two kinds of maps:
  * WMO-only: the map's WDT places one big WMO (Blackrock Spire, Dire Maul...).
  * terrain:  ADT terrain tiles plus WMOs placed on them (Stratholme, Scholomance, the new outdoor
              dungeons). Terrain heights come from each chunk's MCVT, WMO placements from MODF.

What goes into each file (all in the instance's own world coordinates, the ones the server uses):
  * placements : every placed WMO (position, yaw, scale), so rooms can be tested in their own frame
  * groups     : the rooms (WMO groups) with local boxes, area names (what GetSubZoneText shows)
  * areas      : outdoors, the subzone name of each 33-yard terrain chunk
  * tiles      : the client's own minimap textures (terrain tiles and room tiles), by FileDataID, with
                 the world centre, size and screen rotation of each (the addon draws them with SetTexture)
  * rows       : the walkable floor grid with every floor height per cell
  * levels     : rooms grouped by height, for the level buttons
  * entrances  : known zone-in points, kept only when they land on a generated floor

Coordinates, checked against the client's own data:
  * a WMO placed by a WDT (WMO-only maps) is turned 180 degrees: world x = -wmo x, world y = -wmo y
    (the client's area triggers land exactly on the floors only with this turn)
  * a WMO placed by an ADT: world = (32 tiles - pos.z, 32 tiles - pos.x, pos.y), yaw = rot.y + 180
    degrees (the same turn; the transformed boxes match the placements' stored world bounds)
  * room minimap tiles: 2 pixels per yard, blocks of 128 yards from the room box's min corner, image
    right = +x and image down = -y of the WMO (tools/verify_tiles.py: 95-99% overlap with the floors)
"""
import collections
import math
import os
import statistics
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geometry as geo  # noqa: E402
import wowdata as w  # noqa: E402

CELL = 2.0
ZQ = 0.5
MIN_COMPONENT = 30            # floor patches smaller than this (cells) are props / wall tops
LEVEL_GAP = 9.0               # yards of height between two display levels
LEVEL_SPAN = 22.0             # a display level never spans more height than this
TILE_YD = 128.0
LOCALES = ["enUS", "esMX", "esES", "ptBR", "deDE", "frFR", "itIT", "ruRU", "koKR", "zhCN", "zhTW"]
ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

WMO_DUNGEONS = [389, 43, 48, 34, 90, 70, 349, 109, 230, 229, 429]
TERRAIN_DUNGEONS = [329, 289, 2974, 3001, 2994]
ALL = WMO_DUNGEONS + TERRAIN_DUNGEONS

# Where the player appears when zoning in (instance coordinates), as published in open server-emulator
# data. A point is only written out when it lies on a generated floor (within 1.5 yd of height), so a
# wrong or outdated point is dropped instead of misleading the estimator.
ENTRANCES = {
    229: [(78.35, -226.84, 49.77)],
    389: [(3.81, -14.82, -17.84)],
    43: [(-163.49, 132.90, -73.66)],
    48: [(-151.89, 106.96, -39.87)],
    34: [(54.23, 0.28, -18.34)],
    90: [(-332.22, -2.28, -150.86)],
    70: [(-226.80, 49.09, -46.03)],
    349: [(1019.69, -458.31, -43.43), (752.91, -616.53, -33.11)],
    109: [(-319.24, 99.90, -131.85)],
    230: [(458.32, 26.52, -70.67)],
    429: [(44.45, -154.82, -2.71), (-201.11, 193.84, -2.71), (31.56, 159.45, -3.47)],
    329: [(3395.09, -3380.25, 142.70), (3593.15, -3646.56, 138.50)],
    289: [(196.37, 127.05, 134.91)],
}

# terrain maps: how far (yards) floors may reach out from the dungeon's own buildings and known points
TERRAIN_STEP_UP = 3.0         # per 2-yard cell (55 degree slope)
TERRAIN_STEP_DOWN = 8.0

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "SakedMap", "Data")


# ---------------------------------------------------------------- placements

class Placement:
    def __init__(self, root, x, y, z, yaw, scale=1.0):
        self.root, self.x, self.y, self.z, self.yaw, self.s = root, x, y, z, yaw, scale
        self.c, self.sn = math.cos(yaw), math.sin(yaw)

    def to_world(self, lx, ly, lz):
        s = self.s
        return (self.x + s * (lx * self.c - ly * self.sn), self.y + s * (lx * self.sn + ly * self.c), self.z + s * lz)

    def world_box(self, b):
        pts = [self.to_world(x, y, z) for x in (b[0], b[3]) for y in (b[1], b[4]) for z in (b[2], b[5])]
        xs, ys, zs = zip(*pts)
        return (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs))


class PlacedGroup:
    """A WMOGroup's geometry moved into world coordinates (for geometry.floor_samples)."""

    def __init__(self, g, p):
        self.verts = [p.to_world(*v) for v in g.verts]
        self.normals = [(x * p.c - y * p.sn, x * p.sn + y * p.c, z) for x, y, z in g.normals]
        self.tris = g.tris


# ---------------------------------------------------------------- terrain

def terrain_samples(chunk_list, cell):
    """Floor samples (ix, iy, z, -1) for every grid cell centre on walkable terrain (not in a hole,
    slope under geometry.MAX_SLOPE_DEG). Per chunk: 8x8 quads, each split in 4 triangles around its
    centre vertex, as the client renders it."""
    out = []
    U = w.UNIT
    for k in chunk_list:
        if k.heights is None:
            continue
        h = k.heights
        px, py, pz = k.pos
        outer = np.empty((9, 9))
        inner = np.empty((8, 8))
        for r in range(17):
            base = (r // 2) * 17 + (0 if r % 2 == 0 else 9)
            if r % 2 == 0:
                outer[r // 2, :] = h[base:base + 9]
            else:
                inner[r // 2, :] = h[base:base + 8]
        ix0 = math.ceil((px - w.CHUNK) / cell - 0.5)
        ix1 = math.floor(px / cell - 0.5)
        iy0 = math.ceil((py - w.CHUNK) / cell - 0.5)
        iy1 = math.floor(py / cell - 0.5)
        for ix in range(ix0, ix1 + 1):
            X = (ix + 0.5) * cell
            fu = (px - X) / U  # 0..8 southward
            r = min(7, max(0, int(fu)))
            u = fu - r
            for iy in range(iy0, iy1 + 1):
                Y = (iy + 0.5) * cell
                fv = (py - Y) / U  # 0..8 eastward
                c = min(7, max(0, int(fv)))
                v = fv - c
                if w.chunk_hole(k, r, c):
                    continue
                # corners (u, v) and heights; centre (0.5, 0.5)
                zc = inner[r, c]
                if u <= v and u <= 1 - v:      # north edge triangle
                    a, b = (0, 0, outer[r, c]), (0, 1, outer[r, c + 1])
                elif v >= u and v >= 1 - u:    # east edge
                    a, b = (0, 1, outer[r, c + 1]), (1, 1, outer[r + 1, c + 1])
                elif u >= v and u >= 1 - v:    # south edge
                    a, b = (1, 1, outer[r + 1, c + 1]), (1, 0, outer[r + 1, c])
                else:                          # west edge
                    a, b = (1, 0, outer[r + 1, c]), (0, 0, outer[r, c])
                # plane through a, b, centre in (u, v, z) with u, v in vertex units
                ax, ay, az = a
                bx, by, bz = b
                cx, cy, cz = 0.5, 0.5, zc
                det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
                l1 = ((by - cy) * (u - cx) + (cx - bx) * (v - cy)) / det
                l2 = ((cy - ay) * (u - cx) + (ax - cx) * (v - cy)) / det
                z = pz + l1 * az + l2 * bz + (1 - l1 - l2) * cz
                # slope: normal of the triangle in yards
                e1 = np.array([(ax - cx) * U, (ay - cy) * U, az - cz])
                e2 = np.array([(bx - cx) * U, (by - cy) * U, bz - cz])
                n = np.cross(e1, e2)
                nz = abs(n[2]) / (np.linalg.norm(n) + 1e-12)
                if nz >= geo.MIN_NZ:
                    out.append((ix, iy, float(z), -1))
    return out


TERRAIN_MARGIN = 40.0         # yards of open ground kept around the dungeon's buildings
# maps whose terrain is only a lid over an underground dungeon (one tile of ground 20+ yards above every room)
NO_TERRAIN = {2994}


def terrain_filter(samples, chunk_list, placements, groups, map_id):
    """Which open ground belongs to the dungeon. The terrain of these maps goes on for kilometres, and
    walls that close it off in game (doors, invisible walls) are not in the geometry. Kept: ground
    around buildings that have rooms inside, around known entrances, and in named sub-areas (chunks whose
    area is neither empty nor the dungeon's own catch-all area)."""
    counts = collections.Counter(k.area for k in chunk_list)
    main = counts.most_common(1)[0][0]
    chunk_area = {}
    for k in chunk_list:
        chunk_area[(math.floor((k.pos[0] - 1) / w.CHUNK), math.floor((k.pos[1] - 1) / w.CHUNK))] = k.area
    boxes = []
    for pi, p in enumerate(placements):
        if any(g["indoor"] for g in groups if g["p"] == pi):
            b = p.world_box(p.root.bbox)
            boxes.append((b[0] - TERRAIN_MARGIN, b[1] - TERRAIN_MARGIN, b[3] + TERRAIN_MARGIN, b[4] + TERRAIN_MARGIN))
    for x, y, _z in ENTRANCES.get(map_id, []):
        boxes.append((x - 120, y - 120, x + 120, y + 120))
    out = []
    for s in samples:
        X, Y = (s[0] + 0.5) * CELL, (s[1] + 0.5) * CELL
        a = chunk_area.get((math.floor(X / w.CHUNK), math.floor(Y / w.CHUNK)), 0)
        if a not in (0, main) or any(b[0] <= X <= b[2] and b[1] <= Y <= b[3] for b in boxes):
            out.append(s)
    return out


def reachable(cells, seeds, cell):
    """Floors reachable on foot from the seed points (directed: climbing is limited, dropping less so).
    Returns the kept cells dict."""
    keep = set()
    stack = []
    for x, y, z in seeds:
        k = (math.floor(x / cell), math.floor(y / cell))
        lst = cells.get(k)
        if not lst:
            continue
        i = min(range(len(lst)), key=lambda j: abs(lst[j][0] - z))
        if abs(lst[i][0] - z) < 6:
            stack.append((k, i))
    while stack:
        k, i = stack.pop()
        if (k, i) in keep:
            continue
        keep.add((k, i))
        z = cells[k][i][0]
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nk = (k[0] + dx, k[1] + dy)
                for j, (nz, _g) in enumerate(cells.get(nk, ())):
                    d = nz - z
                    if -TERRAIN_STEP_DOWN <= d <= TERRAIN_STEP_UP and (nk, j) not in keep:
                        stack.append((nk, j))
    out = {}
    for k, i in keep:
        out.setdefault(k, []).append(cells[k][i])
    for k in out:
        out[k].sort()
    return out


# ---------------------------------------------------------------- shared helpers

def components(cells):
    """Label connected floor pieces (8-neighbour, height step <= 3 yd). Returns {(k, i): label}, sizes."""
    label = {}
    sizes = []
    for k, lst in cells.items():
        for i in range(len(lst)):
            if (k, i) in label:
                continue
            lab = len(sizes)
            n = 0
            stack = [(k, i)]
            label[(k, i)] = lab
            while stack:
                ck, ci = stack.pop()
                n += 1
                z = cells[ck][ci][0]
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nk = (ck[0] + dx, ck[1] + dy)
                        for j, (nz, _g) in enumerate(cells.get(nk, ())):
                            if (nk, j) not in label and abs(nz - z) <= 3.0:
                                label[(nk, j)] = lab
                                stack.append((nk, j))
            sizes.append(n)
    return label, sizes


def enc(v, n):
    s = ""
    for _ in range(n):
        s = ALPHA[v & 63] + s
        v >>= 6
    return s


def encode_rows(cells, gx0, gx1, gy0, gy1, zmin):
    rows = []
    for gx in range(gx0, gx1 + 1):
        out = []
        gy = gy0
        while gy <= gy1:
            lst = cells.get((gx, gy))
            if not lst:
                run = 0
                while run < 63 and gy + run + 1 <= gy1 and not cells.get((gx, gy + run + 1)):
                    run += 1
                out.append(ALPHA[0] + ALPHA[run])
                gy += run + 1
                continue
            lst = lst[:63]
            out.append(ALPHA[len(lst)])
            for z, _gi in lst:
                q = int(round((z - zmin) / ZQ))
                assert 0 <= q < 4096, q
                out.append(enc(q, 2))
            gy += 1
        rows.append("".join(out))
    return rows


def group_at(groups, placements, x, y, z):
    """Runtime rule (mirrored in SakedMap/Grid.lua): smallest room box (in the room's own WMO frame)
    holding the point. Returns the group index or None."""
    best, bestv = None, None
    for i, g in enumerate(groups):
        x0, y0, z0, x1, y1, z1 = g["wbb"]
        if not (x0 - 0.5 <= x <= x1 + 0.5 and y0 - 0.5 <= y <= y1 + 0.5):
            continue
        p = placements[g["p"]]
        dx, dy, dz = (x - p.x) / p.s, (y - p.y) / p.s, (z - p.z) / p.s
        lx, ly = dx * p.c + dy * p.sn, -dx * p.sn + dy * p.c
        b = g["lbb"]
        if b[0] - 0.5 <= lx <= b[3] + 0.5 and b[1] - 0.5 <= ly <= b[4] + 0.5 and b[2] - 1 <= dz + 1 <= b[5] + 2:
            v = (b[3] - b[0]) * (b[4] - b[1]) * (b[5] - b[2])
            if bestv is None or v < bestv:
                best, bestv = i, v
    return best


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


_tile_sizes = {}


def tile_size(fdid):
    if fdid not in _tile_sizes:
        data = w.casc(fdid)
        assert data[:4] == b"BLP2", fdid
        # BLP2 header: magic, version, compression, alphaDepth, alphaType, hasMips, width, height
        _tile_sizes[fdid] = struct.unpack_from("<II", data, 12)
    return _tile_sizes[fdid]


# ---------------------------------------------------------------- one dungeon

def build(map_id, ctx):
    m = ctx["maps"][map_id]
    wdt = int(m["WdtFileDataID"])
    placements = []
    chunk_list = []
    adt_tiles = []
    gw = w.wdt_global_wmo(wdt)
    if gw:
        wmo_fdid, pos, rot = gw
        assert pos == (0.0, 0.0, 0.0) and rot == (0.0, 0.0, 0.0), (pos, rot)
        placements.append(Placement(w.WMORoot(wmo_fdid), 0.0, 0.0, 0.0, math.pi))
        kind = "wmo"
    else:
        kind = "terrain"
        seen = set()
        for tx, ty, ids in w.wdt_tiles(wdt):
            adt_tiles.append((tx, ty, ids))
            chunk_list.extend(w.adt_chunks(ids[0]))
            for pl in w.adt_wmos(ids[1]):
                if pl["uid"] in seen:
                    continue
                seen.add(pl["uid"])
                placements.append(Placement(w.WMORoot(pl["fdid"]), pl["x"], pl["y"], pl["z"], pl["yaw"], pl["scale"]))

    # rooms of every placed WMO
    groups, raw = [], []
    for pi, p in enumerate(placements):
        root = p.root
        names = ctx["area_names"].get(root.wmo_id, {})
        for g in root.groups:
            G = w.WMOGroup(g["fdid"]) if g["fdid"] else None
            name = names.get(G.wmo_group_id, "") if G else ""
            loc = {}
            if G and name:
                for lc, d in ctx["local_names"].items():
                    ln = d.get(root.wmo_id, {}).get(G.wmo_group_id)
                    if ln and ln != name:
                        loc[lc] = ln
            gi = len(groups)
            groups.append({"index": gi, "local": g["index"], "p": pi, "name": name, "loc": loc,
                           "lbb": g["bbox"], "wbb": p.world_box(g["bbox"]),
                           "indoor": bool(g["flags"] & 0x2000)})
            if G:
                raw.append((gi, PlacedGroup(G, p)))

    samples = geo.floor_samples(raw, CELL)
    if kind == "terrain" and map_id not in NO_TERRAIN:
        samples.extend(terrain_filter(terrain_samples(chunk_list, CELL), chunk_list, placements, groups, map_id))
    cells = geo.build_cells(samples)

    hints = [(float(t["Pos_0"]), float(t["Pos_1"]), float(t["Pos_2"]))
             for t in ctx["triggers"] if int(t["ContinentID"]) == map_id]

    if kind == "terrain":
        # keep what can be walked to from the dungeon itself: its buildings' floors, known entrances
        # and the client's area triggers (the open terrain around a dungeon goes on for kilometres)
        seeds = list(ENTRANCES.get(map_id, [])) + hints
        for (ix, iy), lst in cells.items():
            for z, gi in lst:
                if gi >= 0 and groups[gi]["indoor"]:
                    seeds.append(((ix + 0.5) * CELL, (iy + 0.5) * CELL, z))
        cells = reachable(cells, seeds, CELL)

    label, sizes = components(cells)
    kept = {}
    for k, lst in cells.items():
        keep = [f for i, f in enumerate(lst) if sizes[label[(k, i)]] >= MIN_COMPONENT]
        if keep:
            kept[k] = keep
    cells = kept

    # rule check: how often does the runtime room rule give the room the floor came from
    agree = total = 0
    for (gx, gy), lst in cells.items():
        for z, gi in lst:
            total += 1
            got = group_at(groups, placements, (gx + 0.5) * CELL, (gy + 0.5) * CELL, z)
            agree += got == (gi if gi >= 0 else None) or (gi < 0 and got is not None and not groups[got]["indoor"])

    # per-room floor height and size, then levels (terrain counts as one more "room" for levels)
    fz = collections.defaultdict(list)
    for k, lst in cells.items():
        for z, gi in lst:
            fz[gi].append(z)
    for g in groups:
        zs = fz.get(g["index"], [])
        g["fz"] = statistics.median(zs) if zs else (g["wbb"][2] + g["wbb"][5]) / 2
        g["area"] = len(zs) * CELL * CELL
    level_items = [g for g in groups if g["area"] > 0]
    terrain = None
    if fz.get(-1):
        terrain = {"index": -1, "name": m["MapName_lang"], "fz": statistics.median(fz[-1]), "area": len(fz[-1]) * CELL * CELL}
        level_items.append(terrain)
    levels = []
    for g in sorted(level_items, key=lambda g: g["fz"]):
        if levels and g["fz"] - levels[-1]["zs"][-1] <= LEVEL_GAP and g["fz"] - levels[-1]["zs"][0] <= LEVEL_SPAN:
            levels[-1]["zs"].append(g["fz"])
            levels[-1]["groups"].append(g)
        else:
            levels.append({"zs": [g["fz"]], "groups": [g]})
    for li, lv in enumerate(levels):
        cnt = collections.Counter()
        for g in lv["groups"]:
            g["lvl"] = li + 1
            if g["name"]:
                cnt[g["name"]] += g["area"]
        lv["name"] = cnt.most_common(1)[0][0] if cnt else "Level %d" % (li + 1)
        lv["z0"] = min(lv["zs"])
        lv["z1"] = max(lv["zs"])
    for g in groups:
        if "lvl" not in g:  # no floor: attach to the level closest in height
            g["lvl"] = min(range(len(levels)), key=lambda i: abs(levels[i]["z0"] - g["fz"])) + 1 if levels else 1
    terrain_level = terrain["lvl"] if terrain else 0

    # tiles: { fdid, centre x, centre y, width, height (yards, as the image lies), room (0 = terrain),
    #          screen rotation (radians, counter-clockwise; 0 = image right is east), level }
    tiles = []
    for pi, p in enumerate(placements):
        first = next((g["index"] for g in groups if g["p"] == pi), 0)
        for t in ctx["tiles_by_wmo"].get(p.root.wmo_id, []):
            lg = int(t["GroupNum"])
            if lg >= len(p.root.groups):
                continue
            gi = first + lg
            fdid = int(t["FileDataID"])
            wpx, hpx = tile_size(fdid)
            lb = p.root.groups[lg]["bbox"]
            lx0 = lb[0] + int(t["BlockX"]) * TILE_YD
            ly0 = lb[1] + int(t["BlockY"]) * TILE_YD
            cx, cy, _ = p.to_world(lx0 + wpx / 4.0, ly0 + hpx / 4.0, 0)
            # image right = local +x; on screen (up = +x world, right = -y world) that is yaw + 90 degrees
            rho = (p.yaw + math.pi / 2) % (2 * math.pi)
            tiles.append((fdid, cx, cy, wpx / 2.0 * p.s, hpx / 2.0 * p.s, gi + 1, rho, groups[gi]["lvl"]))
    if kind == "terrain":
        used = set()
        for (ix, iy) in cells:
            X, Y = (ix + 0.5) * CELL, (iy + 0.5) * CELL
            used.add((int((w.HALF_MAP - Y) // w.TILE), int((w.HALF_MAP - X) // w.TILE)))
        for tx, ty, ids in adt_tiles:
            if (tx, ty) in used and ids[7] and map_id not in NO_TERRAIN:
                cx = w.HALF_MAP - (ty + 0.5) * w.TILE
                cy = w.HALF_MAP - (tx + 0.5) * w.TILE
                # the ADT minimap image is north up, west left: no rotation
                tiles.insert(0, (ids[7], cx, cy, w.TILE, w.TILE, 0, 0.0, terrain_level))

    # outdoor subzones: area of each 33-yard terrain chunk that holds kept floors
    area_ids = {}
    if kind == "terrain":
        chunk_area = {}
        for k in chunk_list:
            chunk_area[(math.floor((k.pos[0] - 1) / w.CHUNK), math.floor((k.pos[1] - 1) / w.CHUNK))] = k.area
        for (ix, iy) in cells:
            key = (math.floor((ix + 0.5) * CELL / w.CHUNK), math.floor((iy + 0.5) * CELL / w.CHUNK))
            a = chunk_area.get(key)
            if a:
                area_ids[key] = a
    area_list = sorted(set(area_ids.values()))
    area_index = {a: i + 1 for i, a in enumerate(area_list)}

    xs = [k[0] for k in cells]
    ys = [k[1] for k in cells]
    gx0, gx1, gy0, gy1 = min(xs), max(xs), min(ys), max(ys)
    zmin = math.floor(min(z for lst in cells.values() for z, _ in lst)) - 1
    rows = encode_rows(cells, gx0, gx1, gy0, gy1, zmin)

    entrances = []
    for ex, ey, ez in ENTRANCES.get(map_id, []):
        lst = cells.get((math.floor(ex / CELL), math.floor(ey / CELL)), [])
        if any(abs(z - ez) <= 1.5 for z, _ in lst):
            entrances.append((ex, ey, ez))
        else:
            print("  entrance", (ex, ey, ez), "is not on a floor: dropped")
    on_floor = 0
    for hx, hy, hz in hints:
        lst = cells.get((math.floor(hx / CELL), math.floor(hy / CELL)), [])
        on_floor += any(abs(z - hz) <= 3 for z, _ in lst)

    # localized names: rooms (WMOAreaTable) and outdoor areas (AreaTable)
    byloc = collections.defaultdict(dict)
    for g in groups:
        for lc, ln in g["loc"].items():
            byloc[lc][g["name"]] = ln
    for a in area_list:
        en = ctx["areas"]["enUS"].get(a, "")
        for lc in LOCALES[1:]:
            ln = ctx["areas"][lc].get(a)
            if en and ln and ln != en:
                byloc[lc][en] = ln
    map_loc = {lc: ctx["map_names"][lc].get(map_id) for lc in LOCALES[1:]}
    for lc, ln in map_loc.items():
        if ln and ln != m["MapName_lang"]:
            byloc[lc][m["MapName_lang"]] = ln

    nfloors = sum(len(v) for v in cells.values())
    path = os.path.join(OUT, "M%d.lua" % map_id)
    with open(path, "w", newline="\n") as f:
        f.write("-- GENERATED by tools/build.py from WoW Forever %s game data. Do not edit.\n" % w.BUILD)
        f.write("-- Coordinates are the instance's world coordinates (yards). Textures are the client's own, by FileDataID.\n")
        f.write("local _, ns = ...\nns.data = ns.data or {}\nns.data[%d] = {\n" % map_id)
        f.write("  id = %d, name = %s, build = %s, kind = %s,\n" % (map_id, lua_str(m["MapName_lang"]), lua_str(w.BUILD), lua_str(kind)))
        f.write("  cell = %g, zq = %g, zmin = %d, gx0 = %d, gy0 = %d, gw = %d, gh = %d, terrainLevel = %d,\n" % (
            CELL, ZQ, zmin, gx0, gy0, gx1 - gx0 + 1, gy1 - gy0 + 1, terrain_level))
        f.write("  levels = {\n")
        for lv in levels:
            f.write("    { name = %s, z0 = %.1f, z1 = %.1f },\n" % (lua_str(lv["name"]), lv["z0"], lv["z1"]))
        f.write("  },\n  placements = {\n")
        for p in placements:
            f.write("    { %.2f, %.2f, %.2f, %.5f, %.4f },\n" % (p.x, p.y, p.z, p.yaw, p.s))
        f.write("  },\n  groups = {\n")
        for g in groups:
            b, lb = g["wbb"], g["lbb"]
            f.write("    { name = %s, lvl = %d, fz = %.1f, p = %d, ind = %s, bb = { %.1f, %.1f, %.1f, %.1f, %.1f, %.1f }, lb = { %.1f, %.1f, %.1f, %.1f, %.1f, %.1f } },\n" % (
                lua_str(g["name"]), g["lvl"], g["fz"], g["p"] + 1, "true" if g["indoor"] else "false", *b, *lb))
        f.write("  },\n  areas = {\n")
        for a in area_list:
            f.write("    %s,\n" % lua_str(ctx["areas"]["enUS"].get(a, "")))
        f.write("  },\n  achunk = {\n")
        for (cx, cy), a in sorted(area_ids.items()):
            f.write("    [%d] = %d,\n" % ((cx + 1024) * 2048 + (cy + 1024), area_index[a]))
        f.write("  },\n  names = {\n")
        for lc in sorted(byloc):
            f.write("    %s = { %s },\n" % (lc, ", ".join("[%s] = %s" % (lua_str(k), lua_str(v)) for k, v in sorted(byloc[lc].items()))))
        f.write("  },\n  tiles = {\n")
        for t in tiles:
            f.write("    { %d, %.1f, %.1f, %.1f, %.1f, %d, %.4f, %d },\n" % t)
        f.write("  },\n  hints = {\n")
        for h in hints:
            f.write("    { %.1f, %.1f, %.1f },\n" % h)
        f.write("  },\n  entrances = {\n")
        for e in entrances:
            f.write("    { %.2f, %.2f, %.2f },\n" % e)
        f.write("  },\n  rows = {\n")
        for r in rows:
            f.write("    %s,\n" % lua_str(r))
        f.write("  },\n}\n")
    size = os.path.getsize(path)
    print("%d %-22s %-7s wmos %3d groups %4d tiles %4d levels %2d floors %6d room-rule %.1f%% entrances %d hints-on-floor %d/%d file %4d KB" % (
        map_id, m["MapName_lang"], kind, len(placements), len(groups), len(tiles), len(levels), nfloors,
        100.0 * agree / max(total, 1), len(entrances), on_floor, len(hints), size // 1024), flush=True)


def main(argv):
    ids = [int(a) for a in argv] or ALL
    ctx = {}
    ctx["maps"] = {int(r["ID"]): r for r in w.db2("Map")}
    ctx["area_names"] = collections.defaultdict(dict)
    for r in w.db2("WMOAreaTable"):
        ctx["area_names"][int(r["WMOID"])][int(r["WMOGroupID"])] = r["AreaName_lang"]
    # the same names in the client languages, for matching GetSubZoneText() on non-English clients
    ctx["local_names"] = {}
    ctx["areas"] = {"enUS": {int(r["ID"]): r["AreaName_lang"] for r in w.db2("AreaTable")}}
    ctx["map_names"] = {}
    for loc in LOCALES[1:]:
        d = collections.defaultdict(dict)
        for r in w.db2("WMOAreaTable", loc):
            if r["AreaName_lang"]:
                d[int(r["WMOID"])][int(r["WMOGroupID"])] = r["AreaName_lang"]
        ctx["local_names"][loc] = d
        ctx["areas"][loc] = {int(r["ID"]): r["AreaName_lang"] for r in w.db2("AreaTable", loc)}
        ctx["map_names"][loc] = {int(r["ID"]): r["MapName_lang"] for r in w.db2("Map", loc)}
    ctx["tiles_by_wmo"] = collections.defaultdict(list)
    for r in w.db2("WMOMinimapTexture"):
        ctx["tiles_by_wmo"][int(r["WMOID"])].append(r)
    ctx["triggers"] = w.db2("AreaTrigger")
    os.makedirs(OUT, exist_ok=True)
    for mid in ids:
        build(mid, ctx)
    # index of every generated file, so the .toc stays in sync
    present = sorted(int(f[1:-4]) for f in os.listdir(OUT) if f.startswith("M") and f.endswith(".lua"))
    with open(os.path.join(OUT, "Data.xml"), "w", newline="\n") as f:
        f.write('<Ui xmlns="http://www.blizzard.com/wow/ui/">\n')
        for mid in present:
            f.write('  <Script file="M%d.lua"/>\n' % mid)
        f.write("</Ui>\n")


if __name__ == "__main__":
    main(sys.argv[1:])
