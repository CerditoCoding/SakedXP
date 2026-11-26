"""PNG of a generated map with its walkable floors tinted and entrances circled (for eyeballing).

    python3 tools/floormap.py <mapID> out.png [maxsize]
"""
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import preview as pv  # noqa: E402


def main(map_id, out, maxsize=1000):
    tmp = out + ".base.png"
    pv.render(map_id, tmp)
    d = pv.load(map_id)
    fl = pv.floors(d)
    xmax = max(p[0] for p in fl) + 40
    ymax = max(p[1] for p in fl) + 40
    base = Image.open(tmp).convert("RGB")
    mask = Image.new("L", base.size, 0)
    dm = ImageDraw.Draw(mask)
    for x, y, _z in fl:
        u, v = (ymax - y) * 2, (xmax - x) * 2
        dm.rectangle((u - 2, v - 2, u + 2, v + 2), fill=100)
    over = Image.composite(Image.new("RGB", base.size, (0, 255, 255)), base, mask)
    dr = ImageDraw.Draw(over)
    src = open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "SakedMap", "Data", "M%d.lua" % map_id)).read()
    body = src.split("entrances = {")[1].split("rows")[0]
    for m in re.finditer(r"\{ (-?[\d.]+), (-?[\d.]+), (-?[\d.]+) \}", body):
        x, y = float(m.group(1)), float(m.group(2))
        u, v = (ymax - y) * 2, (xmax - x) * 2
        dr.ellipse((u - 16, v - 16, u + 16, v + 16), outline=(255, 0, 0), width=6)
    for x, y, _z in d["hints"]:
        u, v = (ymax - y) * 2, (xmax - x) * 2
        dr.rectangle((u - 8, v - 8, u + 8, v + 8), outline=(255, 255, 0), width=4)
    over.thumbnail((maxsize, maxsize))
    over.save(out)
    os.remove(tmp)
    print("wrote", out, over.size)


if __name__ == "__main__":
    main(int(sys.argv[1]), sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1000)
