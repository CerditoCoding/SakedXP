"""Read WoW Forever game data: DB2 tables (CSV) and raw files, from wago.tools.

Everything is cached under tools/.cache so a rebuild does not download again.
Only facts (FileDataIDs, coordinates, names) end up in the addon; the game's
textures are loaded by the client itself at run time.
"""
import csv
import io
import os
import struct
import sys
import time
import urllib.request

BUILD = os.environ.get("WOW_BUILD", "1.60.1.71139")
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache", BUILD)
UA = "Mozilla/5.0 (X11; Linux x86_64) SakedMap-datatool"


def _get(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        with open(dest, "rb") as f:
            return f.read()
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    last = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            if data[:1] == b"{" and b'"errors"' in data[:64]:
                raise RuntimeError("wago.tools error for %s: %s" % (url, data[:200]))
            with open(dest + ".tmp", "wb") as f:
                f.write(data)
            os.replace(dest + ".tmp", dest)
            return data
        except Exception as e:  # network hiccup: back off and retry
            last = e
            time.sleep(2 * (attempt + 1))
    raise RuntimeError("download failed: %s (%s)" % (url, last))


def db2(table, locale=None):
    """Rows of a DB2 table as a list of dicts (strings). `locale` picks the language of *_lang columns."""
    url = "https://wago.tools/db2/%s/csv?build=%s" % (table, BUILD)
    name = table
    if locale and locale != "enUS":
        url += "&locale=" + locale
        name += "." + locale
    data = _get(url, os.path.join(CACHE, "db2", name + ".csv"))
    return list(csv.DictReader(io.StringIO(data.decode("utf-8"))))


def casc(fdid):
    """Raw bytes of a game file by FileDataID."""
    url = "https://wago.tools/api/casc/%d?version=%s" % (fdid, BUILD)
    return _get(url, os.path.join(CACHE, "casc", str(fdid)))


def chunks(data, start=0, end=None):
    """Yield (tag, payload) for IFF-style chunks (tags stored reversed)."""
    end = len(data) if end is None else end
    i = start
    while i + 8 <= end:
        tag = data[i:i + 4][::-1].decode("latin1")
        size = struct.unpack_from("<I", data, i + 4)[0]
        yield tag, data[i + 8:i + 8 + size]
        i += 8 + size


# ---------------------------------------------------------------- WDT

def wdt_global_wmo(wdt_fdid):
    """(wmo_fdid, pos, rot) of a WMO-only map, or None if the map uses terrain."""
    data = casc(wdt_fdid)
    flags = None
    for tag, p in chunks(data):
        if tag == "MPHD":
            flags = struct.unpack_from("<I", p, 0)[0]
        if tag == "MODF" and len(p) >= 64:
            name_id, _uid = struct.unpack_from("<II", p, 0)
            pos = struct.unpack_from("<3f", p, 8)
            rot = struct.unpack_from("<3f", p, 20)
            return name_id, pos, rot
    return None


# ---------------------------------------------------------------- WMO root

class WMORoot:
    def __init__(self, fdid):
        self.fdid = fdid
        data = casc(fdid)
        c = {}
        for tag, p in chunks(data):
            c.setdefault(tag, p)
        mohd = c["MOHD"]
        (self.n_textures, self.n_groups, self.n_portals, self.n_lights, _ndn, _ndd,
         _nds, _col, self.wmo_id) = struct.unpack_from("<9I", mohd, 0)
        self.bbox = struct.unpack_from("<6f", mohd, 36)
        self.group_names = c.get("MOGN", b"")
        self.groups = []
        mogi = c["MOGI"]
        for i in range(self.n_groups):
            flags, x0, y0, z0, x1, y1, z1, name_ofs = struct.unpack_from("<I6fi", mogi, i * 32)
            self.groups.append({"index": i, "flags": flags, "bbox": (x0, y0, z0, x1, y1, z1),
                                "name": self._name(name_ofs)})
        gfid = c.get("GFID", b"")
        ids = struct.unpack("<%dI" % (len(gfid) // 4), gfid)
        for i, g in enumerate(self.groups):
            g["fdid"] = ids[i] if i < len(ids) else 0

    def _name(self, ofs):
        if ofs < 0 or ofs >= len(self.group_names):
            return ""
        end = self.group_names.find(b"\0", ofs)
        return self.group_names[ofs:end].decode("latin1")


# ---------------------------------------------------------------- WMO group

MOGP_HEADER = 0x44
F_DETAIL, F_COLLISION, F_RENDER = 0x04, 0x08, 0x20


class WMOGroup:
    def __init__(self, fdid):
        self.fdid = fdid
        data = casc(fdid)
        mogp = None
        for tag, p in chunks(data):
            if tag == "MOGP":
                mogp = p
        if mogp is None:
            raise ValueError("no MOGP in %d" % fdid)
        (self.name_ofs, self.desc_ofs, self.flags) = struct.unpack_from("<3I", mogp, 0)
        self.bbox = struct.unpack_from("<6f", mogp, 12)
        self.wmo_group_id = struct.unpack_from("<I", mogp, 0x38)[0]
        sub = {}
        for tag, p in chunks(mogp, MOGP_HEADER):
            sub.setdefault(tag, p)
        movt = sub.get("MOVT", b"")
        self.verts = [struct.unpack_from("<3f", movt, i * 12) for i in range(len(movt) // 12)]
        monr = sub.get("MONR", b"")
        self.normals = [struct.unpack_from("<3f", monr, i * 12) for i in range(len(monr) // 12)]
        if "MOVX" in sub:  # 32-bit indices in newer files
            movi = sub["MOVX"]
            idx = struct.unpack("<%dI" % (len(movi) // 4), movi)
        else:
            movi = sub.get("MOVI", b"")
            idx = struct.unpack("<%dH" % (len(movi) // 2), movi)
        ntri = len(idx) // 3
        # per-face flags: MOPY (u8 flags, u8 material) or MPY2 (u16 flags, u16 material)
        if "MPY2" in sub:
            p = sub["MPY2"]
            face = [struct.unpack_from("<HH", p, t * 4) for t in range(min(ntri, len(p) // 4))]
        else:
            p = sub.get("MOPY", b"")
            face = [(p[t * 2], p[t * 2 + 1]) for t in range(min(ntri, len(p) // 2))]
        # the faces the collision BSP references are what the player stands on and bumps into
        bsp = set()
        if "MOBR" in sub:
            p = sub["MOBR"]
            bsp = set(struct.unpack("<%dH" % (len(p) // 2), p))
        self.tris = []
        for t in range(ntri):
            fl, mat = face[t] if t < len(face) else (0, 0)
            if bsp:
                collide = t in bsp
            else:  # wowdev.wiki rule: collision-only faces, or rendered non-detail faces
                collide = bool(fl & F_COLLISION) or (bool(fl & F_RENDER) and not fl & F_DETAIL)
            self.tris.append((idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2], collide))

    @property
    def indoor(self):
        return bool(self.flags & 0x2000)


if __name__ == "__main__":
    root = WMORoot(int(sys.argv[1]))
    print("wmoID", root.wmo_id, "groups", root.n_groups, "bbox", root.bbox)
