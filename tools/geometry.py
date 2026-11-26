"""Walkable floor grid of a WMO: which (x, y) cells have ground, at what height, in which group (room).

Floors are the collision faces that point up (slope below MAX_SLOPE_DEG). Each grid cell keeps one
height per distinct floor level, so stacked rooms (bridges over halls, spiral ramps) stay separate.
"""
import math

import numpy as np

MAX_SLOPE_DEG = 55.0          # WoW lets you walk up roughly 50 degree slopes
MIN_NZ = math.cos(math.radians(MAX_SLOPE_DEG))
MERGE_DZ = 2.0                # heights closer than this in one cell are one floor


def floor_samples(groups, cell):
    """groups: list of (group_index, WMOGroup). Returns array rows (ix, iy, z, group_index) in world units.

    Cells are aligned to multiples of `cell`; ix = floor(x / cell)."""
    out = []
    for gi, g in groups:
        if not g.verts:
            continue
        V = np.asarray(g.verts, dtype=np.float64)
        T = np.asarray([(a, b, c) for a, b, c, col in g.tris if col], dtype=np.int64)
        if len(T) == 0:
            continue
        A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
        n = np.cross(B - A, C - A)
        ln = np.linalg.norm(n, axis=1)
        ok = ln > 1e-9
        nz = np.zeros(len(T))
        nz[ok] = n[ok, 2] / ln[ok]
        # which side is up: the shipped vertex normals say where the surface faces (a ceiling seen
        # from above looks flat too, but its normals point down)
        if len(g.normals) == len(g.verts):
            N = np.asarray(g.normals, dtype=np.float64)
            up = (N[T[:, 0], 2] + N[T[:, 1], 2] + N[T[:, 2], 2]) / 3.0
            walk = (np.abs(nz) >= MIN_NZ) & (up > 0.3)
        else:
            walk = nz >= MIN_NZ
        for a, b, c in zip(A[walk], B[walk], C[walk]):
            xs = (a[0], b[0], c[0])
            ys = (a[1], b[1], c[1])
            ix0, ix1 = math.floor(min(xs) / cell), math.floor(max(xs) / cell)
            iy0, iy1 = math.floor(min(ys) / cell), math.floor(max(ys) / cell)
            det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(det) < 1e-12:
                continue
            for ix in range(ix0, ix1 + 1):
                px = (ix + 0.5) * cell
                for iy in range(iy0, iy1 + 1):
                    py = (iy + 0.5) * cell
                    l1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / det
                    l2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / det
                    l3 = 1.0 - l1 - l2
                    # small tolerance so thin triangles still mark the cell they cross
                    e = -0.15
                    if l1 >= e and l2 >= e and l3 >= e:
                        z = l1 * a[2] + l2 * b[2] + l3 * c[2]
                        out.append((ix, iy, z, gi))
    return out


def build_cells(samples):
    """{(ix, iy): [(z, group), ...]} with heights merged per floor level (highest sample wins)."""
    cells = {}
    for ix, iy, z, gi in samples:
        cells.setdefault((ix, iy), []).append((z, gi))
    for k, lst in cells.items():
        lst.sort()
        merged = []
        for z, gi in lst:
            if merged and z - merged[-1][0] < MERGE_DZ:
                merged[-1] = (z, gi)  # keep the top of the cluster: you stand on the highest surface
            else:
                merged.append((z, gi))
        cells[k] = merged
    return cells


def drop_unreachable(cells, seeds_xyz, cell, step_up=1.6, step_down=6.0):
    """Keep only floors connected (walking) to one of the seed points. Without seeds, keep all.

    Roof tops and wall tops are walkable-looking but never reachable; dropping them keeps the
    estimator from snapping onto them."""
    if not seeds_xyz:
        return cells
    keep = set()
    stack = []
    for x, y, z in seeds_xyz:
        k = (math.floor(x / cell), math.floor(y / cell))
        best = None
        for i, (fz, gi) in enumerate(cells.get(k, [])):
            if best is None or abs(fz - z) < abs(cells[k][best][0] - z):
                best = i
        if best is not None:
            stack.append((k, best))
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
                for j, (nz, _g) in enumerate(cells.get(nk, [])):
                    if -step_down <= nz - z <= step_up * cell and (nk, j) not in keep:
                        stack.append((nk, j))
    out = {}
    for (k, i) in keep:
        out.setdefault(k, []).append(cells[k][i])
    for k in out:
        out[k].sort()
    return out
