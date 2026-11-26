"""Render a dungeon's generated data to PNG, the way the addon lays it out (north up).

    python3 tools/preview.py 229 out.png [--floors] [--level N] [--path path.csv]

Draws the client's minimap tiles where SakedMap/Data/M<id>.lua says they go. --floors overlays the
walkable grid (cyan dots); red crosses are the client's area triggers, which sit on real floors, so they
show whether tiles, floors and world coordinates line up. --path draws a CSV of x,y[,ex,ey] points.
"""
import io
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
    body = src.split("tiles = {", 1)[1].split("},\n  hints", 1)[0]
    d["tiles"] = [tuple(float(v) for v in m.group(1).split(",")) for m in re.finditer(r"\{ ([-\d., ]+) \}", body)]
    body = src.split("hints = {", 1)[1].split("},\n  rows", 1)[0]
    d["hints"] = [tuple(float(v) for v in m.group(1).split(",")) for m in re.finditer(r"\{ ([-\d., ]+) \}", body)]
    body = src.split("groups = {", 1)[1].split("},\n  names", 1)[0]
    d["groups"] = []
    for m in re.finditer(r'name = "((?:[^"\\]|\\.)*)", lvl = (\d+), fz = ([-\d.]+), bb = \{ ([-\d., ]+) \}', body):
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


def render(map_id, out, show_floors=False, level=None, path=None, crop=None):
    d = load(map_id)
    xs = [t[1] for t in d["tiles"]] + [t[3] for t in d["tiles"]]
    ys = [t[2] for t in d["tiles"]] + [t[4] for t in d["tiles"]]
    xmax, ymax = max(xs), max(ys)
    W = int((ymax - min(ys)) * PX) + 1
    H = int((xmax - min(xs)) * PX) + 1

    def scr(x, y):  # north up: screen right = -y, screen down = -x
        return (ymax - y) * PX, (xmax - x) * PX

    img = Image.new("RGBA", (W, H), (12, 12, 16, 255))
    tiles = sorted(d["tiles"], key=lambda t: d["groups"][int(t[5]) - 1]["fz"])
    for fdid, x0, y0, x1, y1, gi in tiles:
        g = d["groups"][int(gi) - 1]
        t = Image.open(io.BytesIO(w.casc(int(fdid)))).convert("RGBA")
        # the texture's own axes: right = -world x, down = +world y (see build.py); turn it north up
        # (u, v) -> screen (h-1-v, u): a quarter turn clockwise. Same as the addon's texcoords.
        t = t.transpose(Image.Transpose.ROTATE_270)
        sx, sy = scr(x1, y1)
        tw, th = int(round((y1 - y0) * PX)), int(round((x1 - x0) * PX))
        if t.size != (tw, th):
            t = t.resize((tw, th))
        if level is not None and g["lvl"] != level:
            a = t.getchannel("A").point(lambda v: v * 0.18)
            t.putalpha(a)
        img.alpha_composite(t, (int(round(sx)), int(round(sy))))
    dr = ImageDraw.Draw(img)
    if show_floors:
        for x, y, z in floors(d):
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
