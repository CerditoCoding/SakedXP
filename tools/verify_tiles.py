"""Check which minimap-tile layout matches a WMO's floors (used by build.py, also runnable alone)."""
import io
import sys

import numpy as np
from PIL import Image

import geometry as geo
import wowdata as w

TILE_YD = 128.0


def paint_mask(fdid):
    a = np.array(Image.open(io.BytesIO(w.casc(fdid))).convert("RGBA"))
    return (a[..., 3] > 0) & (a[..., :3].astype(int).sum(-1) > 20)


def layouts():
    # each returns (u, v) pixel for a WMO-space point, given tile/group info
    def xy(x, y, g, bx, by, W, H, nby):
        ox, oy = g[0] + bx * TILE_YD, g[1] + by * TILE_YD
        return (x - ox) * 2, H - 1 - (y - oy) * 2

    def classic(x, y, g, bx, by, W, H, nby):
        # wow.tools style: tile top-left at the group's (max x, max y), image right = -y, down = -x
        ox, oy = g[4] - bx * TILE_YD, g[3] - (nby - 1 - by) * TILE_YD
        return (ox - y) * (W / TILE_YD), (oy - x) * (H / TILE_YD)

    return {"xy": xy, "classic": classic}


def score(root, tiles, max_groups=25):
    res = {k: [0, 0] for k in layouts()}
    by_group = {}
    for t in tiles:
        by_group.setdefault(int(t["GroupNum"]), []).append(t)
    done = 0
    for gi, ts in sorted(by_group.items(), key=lambda kv: -len(kv[1])):
        if gi >= len(root.groups) or done >= max_groups:
            continue
        g = root.groups[gi]
        G = w.WMOGroup(g["fdid"])
        s = geo.floor_samples([(gi, G)], 1.0)
        if len(s) < 20:
            continue
        done += 1
        nby = max(int(t["BlockY"]) for t in ts) + 1
        masks = [(t, paint_mask(int(t["FileDataID"]))) for t in ts]
        for name, f in layouts().items():
            for ix, iy, z, _ in s[::3]:
                x, y = ix + 0.5, iy + 0.5
                for t, m in masks:
                    H, W = m.shape
                    u, v = f(x, y, g["bbox"], int(t["BlockX"]), int(t["BlockY"]), W, H, nby)
                    u, v = int(u), int(v)
                    if 0 <= u < W and 0 <= v < H:
                        res[name][0] += 1
                        res[name][1] += int(m[v, u])
                        break
    return {k: (round(v[1] / max(v[0], 1), 3), v[0]) for k, v in res.items()}


if __name__ == "__main__":
    maps = {int(r["ID"]): r for r in w.db2("Map")}
    rows = w.db2("WMOMinimapTexture")
    for mid in map(int, sys.argv[1:]):
        wf = w.wdt_global_wmo(int(maps[mid]["WdtFileDataID"]))[0]
        root = w.WMORoot(wf)
        tiles = [r for r in rows if int(r["WMOID"]) == root.wmo_id]
        print(mid, maps[mid]["MapName_lang"], "wmo", root.wmo_id, "tiles", len(tiles), score(root, tiles))
