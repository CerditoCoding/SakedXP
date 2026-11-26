"""Render a dungeon's generated data to PNG, the way the addon lays it out (north up).

    python3 tools/preview.py 229 out.png [--floors] [--level N] [--path path.csv]

Draws the client's minimap tiles where SakedMap/Data/M<id>.lua says they go. --floors overlays the
walkable grid (cyan dots); red crosses are the client's area triggers, which sit on real floors, so they
show whether tiles, floors and world coordinates line up. --path draws a CSV of x,y[,ex,ey] points.
"""
import io
import math
import math
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wowdata as w  # noqa: E402

PX = 2.0  # pixels per yard (the tiles' own resolution)
ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
DEC = {c: i for i, c in enumerate(ALPHA)}


def load(map_id):
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "SakedMap", "Data", "M%d.lua" % map_id)
    src = open(path, encoding="utf-8").read()
    d = {}
    for k in ("cell", "zq", "zmin", "gx0", "gy0", "gw", "gh"):
        d[k] = float(re.search(r"\b%s = (-?[\d.]+)" % k, src).group(1))
    body = src.split("  tiles = {", 1)[1].split("},\n  hints", 1)[0]
    d["tiles"] = [tuple(float(v) for v in m.group(1).split(",")) for m in re.finditer(r"\{ ([-\d., ]+) \}", body)]
    body = src.split("hints = {", 1)[1].split("},\n  rows", 1)[0]
    d["hints"] = [tuple(float(v) for v in m.group(1).split(",")) for m in re.finditer(r"\{ ([-\d., ]+) \}", body)]
    body = src.split("  groups = {", 1)[1].split("},\n  areas", 1)[0]
    d["groups"] = []
    for m in re.finditer(r'name = "((?:[^"\\]|\\.)*)", lvl = (\d+), fz = ([-\d.]+), p = \d+, ind = \w+, bb = \{ ([-\d., ]+) \}', body):
        d["groups"].append({"name": m.group(1), "lvl": int(m.group(2)), "fz": float(m.group(3)),
                            "bb": [float(v) for v in m.group(4).split(",")]})
    d["rows"] = re.findall(r'^    "([^"]*)",$', src.split("rows = {", 1)[1], re.M)
    return d


def floors(d):
    out = []
    for r, s in enumerate(d["rows"]):
        gx = int(d["gx0"]) + r
        i, gy = 0, 0
        while i < len(s):
            n = DEC[s[i]]
            if n == 0:
                gy += DEC[s[i + 1]] + 1
                i += 2
                continue
            i += 1
            for _ in range(n):
                q = DEC[s[i]] * 64 + DEC[s[i + 1]]
                out.append(((gx + 0.5) * d["cell"], (gy + int(d["gy0"]) + 0.5) * d["cell"], d["zmin"] + q * d["zq"]))
                i += 2
            gy += 1
    return out


def paste_clipped(img, t, pos):
    x, y = pos
    l, tp = max(0, -x), max(0, -y)
    t = t.crop((l, tp, t.size[0], t.size[1]))
    img.alpha_composite(t, (max(0, x), max(0, y)))


def render(map_id, out, show_floors=False, level=None, path=None, crop=None):
    d = load(map_id)
    fl = floors(d)
    xs = [p[0] for p in fl]
    ys = [p[1] for p in fl]
    xmax, ymax = max(xs) + 40, max(ys) + 40
    W = int((ymax - min(ys) + 40) * PX) + 1
    H = int((xmax - min(xs) + 40) * PX) + 1

    def scr(x, y):  # north up: screen right = -y, screen down = -x
        return (ymax - y) * PX, (xmax - x) * PX

    img = Image.new("RGBA", (W, H), (12, 12, 16, 255))
    tiles = sorted(d["tiles"], key=lambda t: (t[7], 0 if t[5] == 0 else 1))
    for fdid, cx, cy, tw_, th_, gi, rho, lvl in tiles:
        t = Image.open(io.BytesIO(w.casc(int(fdid)))).convert("RGBA")
        # the image as it lies (w x h yards), turned counter-clockwise by rho, centred on (cx, cy)
        t = t.resize((max(1, int(round(tw_ * PX))), max(1, int(round(th_ * PX)))))
        t = t.rotate(math.degrees(rho), expand=True, resample=Image.Resampling.BILINEAR)
        if level is not None and lvl != level:
            t.putalpha(t.getchannel("A").point(lambda v: v * 0.18))
        sx, sy = scr(cx, cy)
        pos = (int(round(sx - t.size[0] / 2)), int(round(sy - t.size[1] / 2)))
        if pos[0] >= W or pos[1] >= H or pos[0] + t.size[0] <= 0 or pos[1] + t.size[1] <= 0:
            continue
        # crop to the canvas
        l, tp = max(0, -pos[0]), max(0, -pos[1])
        r, b = min(t.size[0], W - pos[0]), min(t.size[1], H - pos[1])
        img.alpha_composite(t.crop((l, tp, r, b)), (max(0, pos[0]), max(0, pos[1])))
    dr = ImageDraw.Draw(img)
    if show_floors:
        for x, y, z in fl:
            if level is None or abs(z - next((g["fz"] for g in d["groups"] if g["lvl"] == level), z)) < 25:
                u, v = scr(x, y)
                dr.point((u, v), fill=(0, 255, 255, 255))
    for x, y, z in d["hints"]:
        u, v = scr(x, y)
        dr.line((u - 6, v - 6, u + 6, v + 6), fill=(255, 40, 40, 255), width=2)
        dr.line((u - 6, v + 6, u + 6, v - 6), fill=(255, 40, 40, 255), width=2)
    if path:
        pts = [tuple(float(v) for v in line.split(",")) for line in open(path) if line.strip() and not line.startswith("#")]
        dr.line([scr(p[0], p[1]) for p in pts], fill=(80, 255, 80, 255), width=2)
        if len(pts[0]) >= 4:
            dr.line([scr(p[2], p[3]) for p in pts], fill=(255, 200, 0, 255), width=2)
    if crop:
        img = img.crop(crop)
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    a = sys.argv[1:]
    lvl = int(a[a.index("--level") + 1]) if "--level" in a else None
    pth = a[a.index("--path") + 1] if "--path" in a else None
    render(int(a[0]), a[1], "--floors" in a, lvl, pth)
