import math

import bpy
from mathutils import Vector


def rig():
    sc = bpy.context.scene
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.024, 0.016, 0.012, 1)  # ~#2A211C
    bg.inputs["Strength"].default_value = 1.0
    for name in ("ReviewKey", "ReviewFill"):
        o = bpy.data.objects.get(name)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    key = bpy.data.lights.new("ReviewKey", "POINT")
    key.color = (1.0, 0.835, 0.54)
    key.energy = 3000
    key.shadow_soft_size = 0.5
    ko = bpy.data.objects.new("ReviewKey", key)
    sc.collection.objects.link(ko)
    fill = bpy.data.lights.new("ReviewFill", "SUN")
    fill.energy = 0.6
    fill.color = (0.7, 0.75, 0.9)
    fo = bpy.data.objects.new("ReviewFill", fill)
    fo.rotation_euler = (math.radians(55), 0, math.radians(140))
    sc.collection.objects.link(fo)
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 960
    sc.render.resolution_y = 720
    sc.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.get("ReviewCam")
    if not cam:
        cam = bpy.data.objects.new("ReviewCam", bpy.data.cameras.new("ReviewCam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    return ko, cam


def shot(path, target, dist, yaw, pitch, lens=50, key_offset=(-0.4, -1.0, 0.9)):
    ko, cam = rig()
    t = Vector(target)
    d = Vector(
        (
            math.cos(math.radians(pitch)) * math.sin(math.radians(yaw)),
            -math.cos(math.radians(pitch)) * math.cos(math.radians(yaw)),
            math.sin(math.radians(pitch)),
        )
    )
    cam.location = t + d * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    side = d.cross(Vector((0, 0, 1)))
    ko.location = t + (d + Vector((0, 0, 0.7)) + side * 0.6).normalized() * dist * 0.8
    ko.data.energy = 120 * dist * dist
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
