import dtk
from dtk import Builder

# Wall prop: wall plane y = 0, front toward -Y, origin on the floor at the wall.


def build():
    m = Builder()
    z0, z1 = 2.6, 5.6
    hw, d = 1.2, 0.9
    m.box("Body", (-hw, -d, z0), (hw, 0, z1), c=0.06, flat=("+y",))
    # rain hood over the top, flat underside on the body
    m.box("Body", (-hw - 0.08, -d - 0.1, z1), (hw + 0.08, 0, z1 + 0.12), c=0.04, flat=("-z", "+y"))
    # door: thin plate, sharp, set on the front face
    m.box("Body", (-hw + 0.12, -d - 0.08, z0 + 0.12), (hw - 0.12, -d, z1 - 0.12))
    # hinges on the door's left edge
    for z in (z0 + 0.45, z1 - 0.45):
        m.box("Body", (-hw + 0.04, -d - 0.13, z - 0.16), (-hw + 0.2, -d - 0.04, z + 0.16), c=0.03, flat=("+y",))
        m.cyl("Body", (-hw + 0.12, -d - 0.13, z - 0.2), (-hw + 0.12, -d - 0.13, z + 0.2), 0.05)
    # quarter-turn latch (operating detail): boss + hex handle
    lx, lz = hw - 0.35, (z0 + z1) / 2
    m.lathe("Rubber", [(0.15, 0), (0.15, 0.06), (0.11, 0.1)], (lx, -d - 0.08, lz), (0, -1, 0))
    m.tube("Rubber", [(lx, -d - 0.17, lz + 0.05), (lx, -d - 0.17, lz - 0.38)], 0.055)
    # rating plate
    m.box("Plate", (-0.45, -d - 0.1, z1 - 0.75), (0.35, -d - 0.08, z1 - 0.4))

    for x in (-0.55, 0.55):
        # bottom gland + rigid conduit: jogs back to the wall, clamped, into a floor collar
        m.lathe("Body", [(0.17, 0), (0.17, 0.15)], (x, -0.45, z0 - 0.15))
        cy = -0.2
        pts = Builder.turtle((x, -0.45, z0 - 0.1), (0, 0, -1), (1, 0, 0), [("f", 0.3), ("t", 45), ("f", 0.354), ("t", -45), ("f", z0 - 0.65)])
        m.tube("Conduit", pts, 0.12, sides=8)
        m.lathe("Body", [(0.18, 0), (0.18, 0.08), (0.14, 0.12)], (x, cy, 0))
        for z in (0.7, 1.6):
            # pipe clamp: 8-sided band hugging the conduit, a stand-off back to an
            # 8-sided wall rosette with two bolt heads
            m.lathe("Body", [(0.16, 0), (0.16, 0.06), (0.15, 0.08), (0.15, 0.14)], (x, cy, z - 0.07))
            m.cyl("Body", (x, cy + 0.12, z), (x, -0.04, z), 0.06)
            m.lathe("Body", [(0.2, 0), (0.2, 0.025), (0.16, 0.045)], (x, 0, z), (0, -1, 0))
            for bz in (z - 0.12, z + 0.12):
                m.cyl("Rubber", (x, -0.04, bz), (x, -0.08, bz), 0.035, sides=6)
        # top gland + sheathed cable: black boot, rises, bends back into the wall
        top = z1 + 0.12
        m.lathe("Body", [(0.16, 0), (0.16, 0.12)], (x, -0.45, top - 0.02))
        cable = Builder.turtle((x, -0.45, top + 0.05), (0, 0, 1), (1, 0, 0), [("f", 1.3), ("t", -45), ("f", 0.35), ("t", -45), ("f", 0.4)])
        m.tube("Conduit", cable, 0.1)
        m.tube("Rubber", [(x, -0.45, top + 0.08), (x, -0.45, top + 0.5)], 0.13)
    return m


PALETTE = {
    "Body": ("#8E9A92", "Metal"),
    "Conduit": ("#C9C3B4", "SmoothPlastic"),
    "Rubber": ("#2A2826", "Rubber"),
    "Plate": ("#E3D8BE", "SmoothPlastic"),
}
