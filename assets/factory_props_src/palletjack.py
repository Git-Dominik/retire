import math

import dtk
from dtk import Builder, v

# Forks point toward -Y (front). Origin bottom centre of the whole jack.


def build():
    m = Builder()
    fz0, fz1 = 0.08, 0.38
    for x in (-0.7, 0.7):
        # fork: chamfered along its length, flat seam where it meets the yoke, tapered tip
        m.box("Paint", (x - 0.3, -2.7, fz0), (x + 0.3, 1.0, fz1), c=0.04, axes="y", flat=("+y", "-z"))
        m.hull("Paint", [v(x + sx * 0.3, y, z) for sx in (-1, 1) for y, z in ((-2.7, fz0), (-2.7, fz1), (-3.15, fz0), (-3.15, 0.18))])
        # load roller showing through the fork window, and under it
        m.box("Rubber", (x - 0.16, -2.55, fz1), (x + 0.16, -2.15, fz1 + 0.01))
        m.cyl("Rubber", (x - 0.2, -2.35, 0.11), (x + 0.2, -2.35, 0.11), 0.11)
        # entry roller under the fork root
        m.cyl("Rubber", (x - 0.2, 0.55, 0.1), (x + 0.2, 0.55, 0.1), 0.1)
    # yoke tying both forks
    m.box("Paint", (-1.0, 1.0, fz0), (1.0, 1.38, 0.62), c=0.05, flat=("-z",))
    # sloped body rising from the yoke to the pump
    m.hull(
        "Paint",
        [
            v(sx * 0.5, y, z)
            for sx in (-1, 1)
            for y, z in ((0.45, 0.62), (1.38, 0.62), (1.05, 1.25), (1.5, 1.25))
        ],
    )

    px, py = 0.0, 1.7
    # pump cylinder + cap, spring rings on the rod
    m.cyl("Steel", (px, py, 0.68), (px, py, 1.25), 0.27, c=0.03)
    m.lathe("Steel", [(0.32, 0), (0.32, 0.1), (0.26, 0.16)], (px, py, 1.25))
    for i in range(3):
        m.lathe("Steel", [(0.2, 0), (0.2, 0.07)], (px, py, 1.45 + i * 0.1))
    m.cyl("Steel", (px, py, 1.41), (px, py, 1.75), 0.08)
    # steer wheel bracket (two cheeks under a top plate), axle, wheels
    m.box("Steel", (-0.49, py - 0.22, 0.62), (0.49, py + 0.22, 0.72), c=0.03, flat=("-z",))
    for sx in (-1, 1):
        m.box("Steel", (sx * 0.44 - 0.05, py - 0.2, 0.15), (sx * 0.44 + 0.05, py + 0.2, 0.62), c=0.02, flat=("+z",))
        m.cyl("Rubber", (sx * 0.22 - 0.12, py, 0.3), (sx * 0.22 + 0.12, py, 0.3), 0.3)
        m.cyl("Steel", (sx * 0.22 - 0.14, py, 0.3), (sx * 0.22 + 0.14, py, 0.3), 0.12)
    m.cyl("Steel", (-0.5, py, 0.3), (0.5, py, 0.3), 0.06)

    # tiller from a pivot boss on the pump head, leaning back
    tilt = 0.26
    def at(z):
        return py + (z - 1.85) * tilt

    m.cyl("Steel", (-0.32, py, 1.85), (0.32, py, 1.85), 0.15)
    for sx in (-1, 1):
        m.box("Steel", (sx * 0.27 - 0.05, py - 0.15, 1.35), (sx * 0.27 + 0.05, py + 0.15, 1.95))
    m.tube("Steel", [(0, at(1.85), 1.85), (0, at(3.45), 3.45)], 0.11)
    # handle loop (faceted corners) in the tiller's plane
    loop = [(-0.3, 3.4), (0.3, 3.4), (0.6, 3.7), (0.6, 3.95), (0.4, 4.15), (-0.4, 4.15), (-0.6, 3.95), (-0.6, 3.7)]
    nrm = v(0, 1, -tilt).normalized()
    m.loop_tube("Steel", [(x, at(z), z) for x, z in loop], nrm, 0.07)
    # grips (top bar + both shoulders) and the release trigger (operating detail)
    m.tube("Rubber", [(-0.32, at(4.15), 4.15), (0.32, at(4.15), 4.15)], 0.1)
    m.tube("Rubber", [(0.15, at(4.1), 4.1), (0.15, at(3.85) + 0.12, 3.85)], 0.04)
    m.box("Steel", (-0.12, at(3.4) - 0.1, 3.3), (0.12, at(3.4) + 0.1, 3.52), c=0.03)
    return m


PALETTE = {
    "Paint": ("#9C3328", "Metal"),
    "Steel": ("#4A4643", "Metal"),
    "Rubber": ("#2A2220", "Rubber"),
}
