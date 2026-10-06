"""Renders the Roblox store icon and thumbnails from the real critter meshes (assets/critters/*.fbx).

Run (needs `pip install bpy`): python3 tools/blender/render_store_art.py
Writes assets/store/icon.png (512x512) and assets/store/thumb_*.png (1920x1080).

Art bible rules: real in-game models only, one lighting rig (golden hour), no text baked into images.
"""

import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(ROOT))
CRITTERS = os.path.join(REPO, "assets", "critters")
OUT = os.path.join(REPO, "assets", "store")


def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, hex_color, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*hex_lin(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def add(obj, material):
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def critter(species, loc, yaw_deg=0.0, scale=1.0):
    """Imports a critter FBX and places it. The meshes face -Y with their feet at z = 0."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(CRITTERS, f"{species}.fbx"))
    parts = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    pivot = bpy.data.objects.new(species, None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in parts:
        o.parent = pivot
    pivot.location = loc
    pivot.rotation_euler = (0, 0, math.radians(yaw_deg))
    pivot.scale = (scale, scale, scale)
    return pivot


def desert(seed_offset=0.0):
    """Sand floor, dunes, mesas and cacti in the art-bible palette."""
    sand, dune, rock, rock_dark, cactus = (
        mat("Sand", "#E8B97E"),
        mat("Dune", "#C98F55"),
        mat("Rock", "#B06A45"),
        mat("RockDark", "#8A4E33"),
        mat("Cactus", "#4E9A4B", 0.6),
    )
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    add(bpy.context.active_object, sand)
    for x, y, sx, sz in ((-30, 60, 40, 6), (25, 75, 50, 8), (70, 55, 30, 5), (-80, 70, 45, 7)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(x + seed_offset, y, 0))
        o = bpy.context.active_object
        o.scale = (sx, sx * 0.5, sz)
        add(o, dune)
    # Mesas: bevelled boxes with a darker cap band.
    for x, y, w, h in ((-55, 110, 30, 26), (45, 130, 42, 34), (110, 120, 26, 22)):
        bpy.ops.mesh.primitive_cube_add(location=(x, y, h / 2))
        o = bpy.context.active_object
        o.scale = (w / 2, w / 3, h / 2)
        bev = o.modifiers.new("b", "BEVEL")
        bev.width = 1.5
        bev.segments = 3
        add(o, rock)
        bpy.ops.mesh.primitive_cube_add(location=(x, y, h - 1.5))
        cap = bpy.context.active_object
        cap.scale = (w / 2 + 0.3, w / 3 + 0.3, 1.6)
        add(cap, rock_dark)
    # Saguaro cacti.
    for x, y, h in ((-9, 14, 5.0), (11, 18, 6.5), (-16, 26, 4.0), (19, 30, 5.5)):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=h, location=(x, y, h / 2))
        add(bpy.context.active_object, cactus)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(x, y, h))
        add(bpy.context.active_object, cactus)
        for side in (-1, 1):
            ax = x + side * 1.1
            az = h * (0.45 if side < 0 else 0.6)
            bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.1, location=(x + side * 0.6, y, az), rotation=(0, math.pi / 2, 0))
            add(bpy.context.active_object, cactus)
            bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.6, location=(ax, y, az + 0.8))
            add(bpy.context.active_object, cactus)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.38, location=(ax, y, az + 1.6))
            add(bpy.context.active_object, cactus)


def golden_hour(sun_heading_deg=-30.0):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    sky = nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(9)
    sky.sun_rotation = math.radians(sun_heading_deg + 180)
    sky.altitude = 200
    sky.dust_density = 3.0
    sky.air_density = 1.3
    world.node_tree.links.new(sky.outputs[0], nodes["Background"].inputs[0])
    nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(78), 0, math.radians(sun_heading_deg + 180)))
    sun = bpy.context.active_object.data
    sun.energy = 4.0
    sun.color = (1.0, 0.78, 0.55)
    sun.angle = math.radians(3)
    # Soft teal fill from the opposite side keeps faces readable.
    bpy.ops.object.light_add(type="AREA", location=(-6, -10, 8))
    fill = bpy.context.active_object
    fill.data.energy = 900
    fill.data.size = 12
    fill.data.color = (0.75, 0.9, 1.0)
    fill.rotation_euler = (Vector((0, 0, 1.5)) - fill.location).to_track_quat("-Z", "Y").to_euler()


def camera(loc, target, lens):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.active_object
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    bpy.context.scene.camera = cam


def render(path, width, height, samples=96):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print(f"[store] wrote {path}", flush=True)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def thumb_lineup():
    """Thumbnail 1: the gang, rarest in the middle, on the station sand at golden hour."""
    fresh()
    desert()
    golden_hour()
    cast = [
        ("CactusCarl", (-6.2, 1.5), 18),
        ("SheriffShrimpo", (-4.0, 0.6), 12),
        ("DustDevilDragon", (-1.6, -0.3), 6),
        ("CloudCowboy", (0.9, -0.6), -4),
        ("LaLocomotoraLoca", (3.6, 0.1), -12),
        ("GoldToothGoose", (6.0, 1.0), -18),
        ("RattlesnakeRex", (-8.6, 3.2), 24),
        ("BootsMcGoat", (8.4, 2.8), -24),
    ]
    for species, (x, y), yaw in cast:
        critter(species, (x, y, 0), yaw, 1.15)
    camera((0, -15.5, 3.2), (0, 0, 1.7), 40)
    render(os.path.join(OUT, "thumb_lineup.png"), 1920, 1080)


def thumb_hero():
    """Thumbnail 2: one legendary critter close up, small ones behind for scale."""
    fresh()
    desert(seed_offset=15)
    golden_hour(sun_heading_deg=-50)
    critter("DustDevilDragon", (0, 0, 0), -15, 2.4)
    critter("CactusCarl", (-4.5, 4, 0), 20, 1.0)
    critter("PicklePete", (4.2, 5, 0), -25, 1.0)
    camera((2.2, -10.5, 2.0), (0, 0, 2.6), 42)
    render(os.path.join(OUT, "thumb_hero.png"), 1920, 1080)


def icon():
    """Store icon: the mascot, Cactus Carl, filling the frame against the sunset."""
    fresh()
    desert()
    golden_hour(sun_heading_deg=-10)
    critter("CactusCarl", (0, 0, 0), -12, 1.0)
    camera((0.9, -5.2, 1.5), (0, 0, 1.35), 50)
    render(os.path.join(OUT, "icon.png"), 512, 512, samples=128)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    thumb_lineup()
    thumb_hero()
