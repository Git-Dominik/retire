import math

import dtk
from dtk import Builder, v

# Roller-table section, tiled end to end along X (SEG studs each, two rollers at the
# 2.2 pitch of the old RollerLine). Origin: floor under the line centre. Rail ends stay flat
# and sharp so neighbouring sections butt without a groove. The side guides are on +Y.

SEG = 4.4
RAIL_Y0, RAIL_Y1 = 2.1, 2.7
RAIL_Z0, RAIL_Z1 = 1.7, 2.7
ROLL_Z, ROLL_R = 2.35, 0.5


def build_section():
    m = Builder()
    h = SEG / 2
    for s in (-1, 1):
        ya, yb = sorted((s * RAIL_Y0, s * RAIL_Y1))
        m.box("Frame", (-h, ya, RAIL_Z0), (h, yb, RAIL_Z1), c=0.06, axes="x", flat=("-x", "+x"))
        # leg (blocky furniture post, flat top under the rail), foot pad
        la, lb = sorted((s * 2.15, s * 2.65))
        m.box("Dark", (-0.25, la, 0.1), (0.25, lb, RAIL_Z0), c=0.04, axes="z")
        m.box("Dark", (-0.4, la - 0.15, 0), (0.4, lb + 0.15, 0.1), c=0.03, flat=("-z", "+z"))
        # axle nuts on the rail's outer face
        for x in (-1.1, 1.1):
            yo = s * RAIL_Y1
            m.cyl("Dark", (x, yo - s * 0.02, ROLL_Z), (x, yo + s * 0.12, ROLL_Z), 0.16)
    # cross brace T-joined into both legs
    m.box("Dark", (-0.12, -2.25, 0.6), (0.12, 2.25, 0.85))
    for x in (-1.1, 1.1):
        m.cyl("Roller", (x, -RAIL_Y0 - 0.1, ROLL_Z), (x, RAIL_Y0 + 0.1, ROLL_Z), ROLL_R, c=0.06)
    # side guide plate bolted to the +Y rail, leaning out
    gy = RAIL_Y1
    pts = []
    for x in (-1.0, 1.0):
        pts += [v(x, gy, 1.9), v(x, gy + 0.2, 1.9), v(x, gy + 0.32, 3.9), v(x, gy + 0.12, 3.9)]
    m.hull("Frame", pts)
    for x in (-0.6, 0.6):
        m.cyl("Dark", (x, gy + 0.18, 2.25), (x, gy + 0.3, 2.25), 0.11)
    return m


def build_drive():
    """Drive unit standing beside the line on -Y; its shaft points +Y into the end roller.
    Origin: floor under the unit, 4.7 studs from the line centre."""
    m = Builder()
    m.box("Dark", (-1.1, -1.9, 0), (1.1, 1.6, 0.4), c=0.04, flat=("-z",))
    # motor can on feet, fan cowl at the back, two cooling bands
    m.box("Dark", (-0.6, -1.3, 0.4), (0.6, 0.1, 0.65), flat=("-z",))
    m.cyl("Frame", (0, 0.35, 1.25), (0, -1.5, 1.25), 0.72, c=0.1)
    for y in (-0.45, -0.95):
        m.lathe("Frame", [(0.76, 0), (0.76, 0.1)], (0, y, 1.25), (0, -1, 0))
    m.lathe("Dark", [(0.62, 0), (0.62, 0.2), (0.42, 0.3)], (0, -1.48, 1.25), (0, -1, 0))
    # gearbox, output shaft, coupling, pillow block flush on the rail's outer face
    m.box("Frame", (-0.65, 0.35, 0.4), (0.65, 1.35, 2.6), c=0.06, flat=("-z",))
    m.lathe("Dark", [(0.3, 0), (0.3, 0.12)], (0, 1.33, ROLL_Z), (0, 1, 0))
    m.cyl("Roller", (0, 1.4, ROLL_Z), (0, 2.1, ROLL_Z), 0.13)
    m.cyl("Dark", (0, 1.5, ROLL_Z), (0, 1.75, ROLL_Z), 0.24)
    m.box("Dark", (-0.35, 1.75, ROLL_Z - 0.4), (0.35, 2.0, ROLL_Z + 0.4), c=0.04, flat=("+y",))
    # e-stop box on the gearbox (operating detail)
    m.box("Dark", (-0.3, 0.55, 2.6), (0.3, 1.15, 2.95), c=0.04, flat=("-z",))
    m.lathe("Accent", [(0.1, 0), (0.1, 0.08), (0.2, 0.1), (0.2, 0.2), (0.14, 0.24)], (0, 0.85, 2.93))
    return m


PALETTE = {
    "Frame": ("#C08A2E", "Metal"),
    "Roller": ("#4A4A4C", "Metal"),
    "Dark": ("#2E2A24", "DiamondPlate"),
    "Accent": ("#B83A2A", "SmoothPlastic"),
}
DRIVE_OFFSET_Y = -4.7
