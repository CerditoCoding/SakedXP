"""Generate SakedMap/Data/M<mapID>.lua for WoW Forever dungeons that are one big WMO.

    python3 tools/build.py            # every supported dungeon
    python3 tools/build.py 229 230    # only these instance map IDs

What goes into each file (all in the instance's own world coordinates, the ones the server uses):
  * groups  : the WMO's rooms with their bounding boxes and area names (what GetSubZoneText shows)
  * tiles   : the client's own minimap textures for each room, by FileDataID, with the world
              rectangle each one covers (the addon draws them with SetTexture(fileID))
  * rows    : the walkable floor grid (cell = 2 yd), with every floor height per cell
  * levels  : rooms grouped by height, for the floor buttons
  * hints   : client area triggers inside the dungeon (always on a floor), used to sanity check

World vs WMO coordinates: for these WMO-only maps the instance world is the WMO rotated 180 degrees
around the vertical axis (world x = -wmo x, world y = -wmo y). Verified with the client's area
triggers, which land exactly on the floors only with this transform. Tile placement is checked by
tools/verify_tiles.py.
"""
import collections
import math
import os
import statistics
import sys

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

# instance map ID -> nothing else needed; the list is the dungeons whose WDT holds a single WMO
WMO_DUNGEONS = [389, 43, 48, 34, 90, 70, 349, 109, 230, 229, 429]

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
}

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "SakedMap", "Data")


class RotatedGroup:
    """A WMOGroup seen in world coordinates (180 degree turn)."""

    def __init__(self, g):
        self.verts = [(-x, -y, z) for x, y, z in g.verts]
        self.normals = [(-x, -y, z) for x, y, z in g.normals]
        self.tris = g.tris


def world_bbox(b):
    x0, y0, z0, x1, y1, z1 = b
    return (-x1, -y1, z0, -x0, -y0, z1)


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


def group_at(groups, x, y, z):
    """Runtime rule (mirrored in SakedMap/Grid.lua): smallest room box holding the point."""
    best, bestv = None, None
    for i, g in enumerate(groups):
        x0, y0, z0, x1, y1, z1 = g["wbb"]
        if x0 - 0.5 <= x <= x1 + 0.5 and y0 - 0.5 <= y <= y1 + 0.5 and z0 - 1 <= z + 1 <= z1 + 2:
            v = (x1 - x0) * (y1 - y0) * (z1 - z0)
            if bestv is None or v < bestv:
                best, bestv = i, v
    return best


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build(map_id, maps, area_names, local_names, tiles_by_wmo, triggers):
    m = maps[map_id]
    gw = w.wdt_global_wmo(int(m["WdtFileDataID"]))
    if not gw:
        print(map_id, "is not a WMO-only map, skipped")
        return None
    wmo_fdid, pos, rot = gw
    assert pos == (0.0, 0.0, 0.0) and rot == (0.0, 0.0, 0.0), (pos, rot)
    root = w.WMORoot(wmo_fdid)
    names = area_names.get(root.wmo_id, {})
    groups = []
    raw = []
    for g in root.groups:
        G = w.WMOGroup(g["fdid"]) if g["fdid"] else None
        name = names.get(G.wmo_group_id, "") if G else ""
        loc = {}
        if G and name:
            for lc, d in local_names.items():
                ln = d.get(root.wmo_id, {}).get(G.wmo_group_id)
                if ln and ln != name:
                    loc[lc] = ln
        groups.append({"index": g["index"], "name": name, "wbb": world_bbox(g["bbox"]), "loc": loc,
                       "lbb": g["bbox"], "wgid": G.wmo_group_id if G else 0})
        if G:
            raw.append((g["index"], RotatedGroup(G)))
    cells = geo.build_cells(geo.floor_samples(raw, CELL))
    label, sizes = components(cells)
    kept = {}
    for k, lst in cells.items():
        keep = [f for i, f in enumerate(lst) if sizes[label[(k, i)]] >= MIN_COMPONENT]
        if keep:
            kept[k] = keep
    cells = kept

    # rule check: how often does the bbox rule give the room the floor came from
    agree = total = 0
    for (gx, gy), lst in cells.items():
        for z, gi in lst:
            total += 1
            agree += group_at(groups, (gx + 0.5) * CELL, (gy + 0.5) * CELL, z) == gi

    # per-room floor height and size, then levels
    fz = collections.defaultdict(list)
    for k, lst in cells.items():
        for z, gi in lst:
            fz[gi].append(z)
    for g in groups:
        zs = fz.get(g["index"], [])
        g["fz"] = statistics.median(zs) if zs else (g["wbb"][2] + g["wbb"][5]) / 2
        g["area"] = len(zs) * CELL * CELL
    order = sorted((g for g in groups if g["area"] > 0), key=lambda g: g["fz"])
    levels = []
    for g in order:
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

    # minimap tiles: bottom-left of block (bx, by) is the room box's min corner + 128 yd steps (WMO space),
    # 2 pixels per yard, image right = +x, image down = -y (WMO space). Verified by tools/verify.py.
    tiles = []
    for t in tiles_by_wmo.get(root.wmo_id, []):
        gi = int(t["GroupNum"])
        if gi >= len(groups):
            continue
        fdid = int(t["FileDataID"])
        wpx, hpx = tile_size(fdid)
        lx0 = groups[gi]["lbb"][0] + int(t["BlockX"]) * TILE_YD
        ly0 = groups[gi]["lbb"][1] + int(t["BlockY"]) * TILE_YD
        lx1, ly1 = lx0 + wpx / 2.0, ly0 + hpx / 2.0
        tiles.append((fdid, -lx1, -ly1, -lx0, -ly0, gi))

    xs = [k[0] for k in cells]
    ys = [k[1] for k in cells]
    gx0, gx1, gy0, gy1 = min(xs), max(xs), min(ys), max(ys)
    zmin = math.floor(min(z for lst in cells.values() for z, _ in lst)) - 1
    rows = encode_rows(cells, gx0, gx1, gy0, gy1, zmin)

    hints = [(float(t["Pos_0"]), float(t["Pos_1"]), float(t["Pos_2"]))
             for t in triggers if int(t["ContinentID"]) == map_id]

    entrances = []
    for ex, ey, ez in ENTRANCES.get(map_id, []):
        lst = cells.get((math.floor(ex / CELL), math.floor(ey / CELL)), [])
        if any(abs(z - ez) <= 1.5 for z, _ in lst):
            entrances.append((ex, ey, ez))
        else:
            print("  entrance", (ex, ey, ez), "is not on a floor: dropped")

    nfloors = sum(len(v) for v in cells.values())
    path = os.path.join(OUT, "M%d.lua" % map_id)
    with open(path, "w", newline="\n") as f:
        f.write("-- GENERATED by tools/build.py from WoW Forever %s game data. Do not edit.\n" % w.BUILD)
        f.write("-- Coordinates are the instance's world coordinates (yards). Textures are the client's own, by FileDataID.\n")
        f.write("local _, ns = ...\nns.data = ns.data or {}\nns.data[%d] = {\n" % map_id)
        f.write("  id = %d, name = %s, build = %s, wmoID = %d,\n" % (map_id, lua_str(m["MapName_lang"]), lua_str(w.BUILD), root.wmo_id))
        f.write("  cell = %g, zq = %g, zmin = %d, gx0 = %d, gy0 = %d, gw = %d, gh = %d,\n" % (
            CELL, ZQ, zmin, gx0, gy0, gx1 - gx0 + 1, gy1 - gy0 + 1))
        # texcoords that draw a tile north-up (screen up = +x, screen right = -y): UL, LL, UR, LR
        f.write("  tc = { 0, 1, 1, 1, 0, 0, 1, 0 },\n")
        f.write("  levels = {\n")
        for lv in levels:
            f.write("    { name = %s, z0 = %.1f, z1 = %.1f },\n" % (lua_str(lv["name"]), lv["z0"], lv["z1"]))
        f.write("  },\n  groups = {\n")
        for g in groups:
            b = g["wbb"]
            f.write("    { name = %s, lvl = %d, fz = %.1f, bb = { %.1f, %.1f, %.1f, %.1f, %.1f, %.1f } },\n" % (
                lua_str(g["name"]), g["lvl"], g["fz"], *b))
        f.write("  },\n  names = {\n")
        # localized room names: names[locale][english name] = local name
        byloc = collections.defaultdict(dict)
        for g in groups:
            for lc, ln in g["loc"].items():
                byloc[lc][g["name"]] = ln
        for lc in sorted(byloc):
            f.write("    %s = { %s },\n" % (lc, ", ".join("[%s] = %s" % (lua_str(k), lua_str(v)) for k, v in sorted(byloc[lc].items()))))
        f.write("  },\n  tiles = {\n")
        for t in tiles:
            f.write("    { %d, %.1f, %.1f, %.1f, %.1f, %d },\n" % (t[0], t[1], t[2], t[3], t[4], t[5] + 1))
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
    print("%d %-22s wmo %5d groups %3d tiles %3d levels %2d floors %6d room-rule %.1f%% entrances %d file %4d KB" % (
        map_id, m["MapName_lang"], root.wmo_id, len(groups), len(tiles), len(levels), nfloors,
        100.0 * agree / max(total, 1), len(entrances), size // 1024), flush=True)
    return {"id": map_id, "name": m["MapName_lang"], "file": "Data/M%d.lua" % map_id}


_tile_sizes = {}


def tile_size(fdid):
    if fdid not in _tile_sizes:
        data = w.casc(fdid)
        assert data[:4] == b"BLP2", fdid
        # BLP2 header: magic, version, compression, alphaDepth, alphaType, hasMips, width, height
        import struct
        _tile_sizes[fdid] = struct.unpack_from("<II", data, 12)
    return _tile_sizes[fdid]


def main(argv):
    ids = [int(a) for a in argv] or WMO_DUNGEONS
    maps = {int(r["ID"]): r for r in w.db2("Map")}
    area_names = collections.defaultdict(dict)
    for r in w.db2("WMOAreaTable"):
        area_names[int(r["WMOID"])][int(r["WMOGroupID"])] = r["AreaName_lang"]
    # the same names in the client languages, for matching GetSubZoneText() on non-English clients
    local_names = {}
    for loc in LOCALES:
        if loc == "enUS":
            continue
        d = collections.defaultdict(dict)
        for r in w.db2("WMOAreaTable", loc):
            if r["AreaName_lang"]:
                d[int(r["WMOID"])][int(r["WMOGroupID"])] = r["AreaName_lang"]
        local_names[loc] = d
    tiles_by_wmo = collections.defaultdict(list)
    for r in w.db2("WMOMinimapTexture"):
        tiles_by_wmo[int(r["WMOID"])].append(r)
    triggers = w.db2("AreaTrigger")
    os.makedirs(OUT, exist_ok=True)
    for mid in ids:
        build(mid, maps, area_names, local_names, tiles_by_wmo, triggers)
    # index of every generated file, so the .toc stays in sync
    present = sorted(int(f[1:-4]) for f in os.listdir(OUT) if f.startswith("M") and f.endswith(".lua"))
    with open(os.path.join(OUT, "Data.xml"), "w", newline="\n") as f:
        f.write('<Ui xmlns="http://www.blizzard.com/wow/ui/">\n')
        for mid in present:
            f.write('  <Script file="M%d.lua"/>\n' % mid)
        f.write("</Ui>\n")


if __name__ == "__main__":
    main(sys.argv[1:])
