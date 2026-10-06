"""Builds critter meshes in headless Blender (bpy) from tools/blender/out/looks.json.

Each critter is a set of smooth subdivided parts (body, eyes, features), one object per color so the
Roblox importer gives one MeshPart per color region (colored in code, no textures needed).
Outputs, per species:  out/critters/<Species>.fbx   and a preview render out/previews/<Species>.png
plus a contact sheet out/previews/sheet.png.

Usage:  python3 tools/blender/build_critters.py [SpeciesId ...]   (default: all)
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "out")
LOOKS = json.load(open(os.path.join(OUT, "looks.json")))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material(name, rgb, rough=0.55, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    lin = srgb_to_linear(rgb)
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def smooth(obj, levels=2):
    mod = obj.modifiers.new("sub", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    for p in obj.data.polygons:
        p.use_smooth = True


def sphere(name, loc, scale, mat, rot=(0, 0, 0), segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    smooth(o, 1)
    return o


def cylinder(name, loc, radius, depth, mat, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cone(name, loc, r1, r2, depth, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


# Coordinates: Blender Z up, critter faces -Y (exported with -Y forward so Roblox sees it facing -Z).
def build(species_id, look):
    reset()
    body_rgb = hex_rgb(look["body"])
    accent_rgb = hex_rgb(look["accent"])
    sx, sy, sz = look["shape"]  # shape[1] is height in game terms
    r = 1.0
    M = {
        "body": material("Body", body_rgb),
        "belly": material("Belly", tuple(min(1, c + (1 - c) * 0.35) for c in body_rgb)),
        "accent": material("Accent", accent_rgb, 0.45),
        "white": material("EyeWhite", (1, 1, 1), 0.2),
        "ink": material("Ink", hex_rgb("#2B1D14"), 0.3),
        "cheek": material("Cheek", (1.0, 0.55, 0.55), 0.6),
        "dark": material("Dark", tuple(c * 0.55 for c in accent_rgb), 0.6),
        "hat": material("Hat", tuple(c * 0.6 + 0.08 for c in hex_rgb("#8A5A3B")), 0.6),
        "band": material("HatBand", hex_rgb("#E2463A"), 0.5),
        "gold": material("Gold", hex_rgb("#FFC83D"), 0.25),
        "wood": material("Wood", hex_rgb("#5B3A26"), 0.7),
        "glow": material("Glow", (1.0, 0.82, 0.45), 0.4, emission=2.0),
        "flame": material("Flame", (1.0, 0.42, 0.1), 0.4, emission=0.7),
        "flameCore": material("FlameCore", (1.0, 0.82, 0.25), 0.4, emission=0.9),
        "brass": material("Brass", hex_rgb("#E2A93B"), 0.3),
        "ruby": material("Ruby", hex_rgb("#E2463A"), 0.15, emission=0.6),
    }
    # Rarity reads on the hat: Outlaws (tiers 35-38) wear black, Mythic and up (30+) get a gold band.
    tier = look.get("tier", 1)
    if 35 <= tier <= 38:
        M["hat"] = material("Hat", hex_rgb("#1E1B2E"), 0.5)
    M["hatBand"] = M["gold"] if tier >= 30 else M["band"]
    H = r * sy  # half height
    W = r * sx
    D = r * sz
    sphere("Body", (0, 0, H), (W, D, H), M["body"], segments=24)
    # Eyes
    for side in (-1, 1):
        ex, ey, ez = side * W * 0.38, -D * 0.84, H * 1.28
        sphere("EyeWhite", (ex, ey, ez), (r * 0.24, r * 0.12, r * 0.28), M["white"])
        sphere("Pupil", (ex, ey - r * 0.08, ez - r * 0.03), (r * 0.14, r * 0.08, r * 0.17), M["ink"])
        sphere("Shine", (ex - side * r * 0.04, ey - r * 0.14, ez + r * 0.07), (r * 0.045, r * 0.03, r * 0.045), M["white"])
        sphere("Cheek", (side * W * 0.62, -D * 0.78, H * 1.02), (r * 0.12, r * 0.05, r * 0.07), M["cheek"])
    sphere("Nose", (0, -D * 0.99, H * 1.12), (r * 0.08, r * 0.05, r * 0.06), M["dark"])
    if "spikes" in look["features"] and species_id == "CactusCarl":
        for side in (-1, 1):
            sphere("Arm", (side * W * 1.12, 0, H * 0.9), (r * 0.3, r * 0.17, r * 0.15), M["body"])
            sphere("ArmUp", (side * W * 1.36, 0, H * 1.18), (r * 0.15, r * 0.15, r * 0.32), M["body"])
    # Feet
    rig = look["rig"]
    spots = {"quadruped": [(-0.5, -0.45), (0.5, -0.45), (-0.5, 0.45), (0.5, 0.45)], "biped": [(-0.38, 0), (0.38, 0)]}.get(rig, [])
    for fx, fy in spots:
        sphere("Foot", (fx * W, fy * D, r * 0.12), (r * 0.18, r * 0.22, r * 0.14), M["dark"])

    top = H * 2 - r * 0.18
    # Crowns, flames and lanterns sit on the hat when there is one.
    crest = top + (r * 0.55 if "hat" in look["features"] else 0.0)
    for feature in look["features"]:
        if feature == "hat":
            brim = sphere("HatBrim", (0, 0, top + r * 0.02), (r * 1.0, r * 0.82, r * 0.07), M["hat"], segments=20)
            for v in brim.data.vertices:  # curl the sides up like a cowboy hat
                v.co.z += (abs(v.co.x) ** 2) * 0.9
            crown = cylinder("HatCrown", (0, 0, top + r * 0.28), r * 0.44, r * 0.5, M["hat"], bevel=0.08)
            for v in crown.data.vertices:  # taper + pinch the top
                if v.co.z > 0:
                    v.co.x *= 0.86
                    v.co.y *= 0.8
                    v.co.z -= abs(v.co.y) * 0.15 if abs(v.co.x) < 0.15 else 0
            cylinder("HatBand", (0, 0, top + r * 0.1), r * 0.45, r * 0.1, M["hatBand"])
        elif feature == "mustache":
            for side in (-1, 1):
                sphere("Mustache", (side * r * 0.22, -D * 0.97, H * 0.98), (r * 0.24, r * 0.08, r * 0.08), M["ink"], rot=(0, side * 0.35, 0))
                sphere("MustacheCurl", (side * r * 0.44, -D * 0.92, H * 1.04), (r * 0.08, r * 0.06, r * 0.08), M["ink"])
        elif feature == "spikes":
            for i in range(14):
                theta = i * 2.399  # golden angle
                phi = 0.5 + (i % 5) * 0.45
                n = Vector((math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)))
                if n.y < -0.55 and n.z > -0.2:
                    continue  # keep the face clear
                loc = Vector((n.x * W, n.y * D, H + n.z * H)) * 1.0
                sphere("Spike", loc, (r * 0.05, r * 0.05, r * 0.05), M["belly"])
        elif feature == "ears":
            for side in (-1, 1):
                sphere("Ear", (side * W * 0.5, 0, top - r * 0.05), (r * 0.14, r * 0.1, r * 0.36), M["body"], rot=(0, side * 0.35, 0))
        elif feature == "tail":
            sphere("Tail", (0, D * 1.0, H * 1.05), (r * 0.16, r * 0.36, r * 0.16), M["accent"], rot=(0.5, 0, 0))
        elif feature == "bandana":
            # The band hugs the body: an ellipsoid's cross-section at 0.62 H is 0.93x its widest.
            band = cylinder("Bandana", (0, 0, H * 0.62), W * 0.97, r * 0.2, M["band"])
            band.scale.y = D / W
            cone("BandanaKnot", (0, -D * 0.96, H * 0.5), r * 0.24, 0, r * 0.34, M["band"], rot=(math.pi, 0, 0))
        elif feature == "boots":
            for side in (-1, 1):
                cylinder("Boot", (side * W * 0.38, 0, r * 0.18), r * 0.2, r * 0.36, M["wood"], bevel=0.03)
        elif feature == "badge":
            cylinder("Badge", (W * 0.3, -D * 0.92, H * 0.75), r * 0.16, r * 0.05, M["gold"], rot=(math.pi / 2, 0, 0))
        elif feature == "horns":
            for side in (-1, 1):
                cone("Horn", (side * W * 1.02, 0, H * 1.5), r * 0.13, r * 0.03, r * 0.65, M["belly"], rot=(0, side * 1.15, 0))
        elif feature == "shell":
            sphere("Shell", (0, D * 0.35, H * 1.2), (W * 0.75, D * 0.65, H * 0.7), M["accent"])
        elif feature == "beak":
            cone("Beak", (0, -D * 1.02, H * 1.0), r * 0.18, 0, r * 0.35, M["gold"], rot=(math.pi / 2, 0, 0))
        elif feature == "wings":
            # Three fanned feathers per side, raised and swept back.
            for side in (-1, 1):
                for i in range(3):
                    feather = sphere(
                        "Wing",
                        (side * W * (0.92 + i * 0.05), D * (0.25 + i * 0.12), H * (1.45 - i * 0.12)),
                        (r * 0.07, r * (0.32 - i * 0.05), r * (0.78 - i * 0.16)),
                        M["accent"],
                        rot=(-0.45 - i * 0.35, side * (0.75 + i * 0.1), 0),
                    )
                    feather.location.z += r * 0.35
        elif feature == "crown":
            # Tilted gold band with five points and a ruby.
            cz = crest + r * 0.12
            cylinder("Crown", (0, 0, cz), r * 0.4, r * 0.24, M["gold"], rot=(0, 0.14, 0), bevel=0.02)
            for i in range(5):
                a = i / 5 * math.tau
                cone("CrownPoint", (math.cos(a) * r * 0.36, math.sin(a) * r * 0.36, cz + r * 0.22 + math.cos(a) * r * 0.05), r * 0.09, 0.0, r * 0.26, M["gold"], rot=(0, 0.14, 0))
            sphere("CrownGem", (0, -r * 0.42, cz), (r * 0.09, r * 0.05, r * 0.09), M["ruby"])
        elif feature == "lantern":
            lz = crest + r * 0.32
            sphere("Lantern", (0, 0, lz), (r * 0.22, r * 0.22, r * 0.27), M["glow"])
            cylinder("LanternCap", (0, 0, lz + r * 0.27), r * 0.2, r * 0.1, M["brass"], bevel=0.02)
            cylinder("LanternBase", (0, 0, lz - r * 0.27), r * 0.2, r * 0.08, M["brass"], bevel=0.02)
            for a in (0.0, math.pi / 2):
                bar = cylinder("LanternBar", (0, 0, lz), r * 0.235, r * 0.5, M["brass"])
                bar.scale = (0.12 if a == 0 else 1.0, 1.0 if a == 0 else 0.12, 1.0)
        elif feature == "glow":
            pass  # a PointLight and aura in game; nothing on the mesh
        elif feature == "cloud":
            # A puffy cloud to ride on, ringing the bottom of the body.
            for i in range(7):
                a = i / 7 * math.tau
                puff = r * (0.42 + 0.08 * math.sin(i * 2.3))
                sphere("Cloud", (math.cos(a) * W * 0.95, math.sin(a) * D * 0.95, r * 0.22), (puff, puff, puff * 0.8), M["white"])
        elif feature == "longtail":
            # A curling tail of shrinking beads, ending in a rattle.
            # It sweeps out to the critter's right and curls up, so it shows from the front.
            steps = 12
            for i in range(steps + 1):
                t = i / steps  # 0 at the body, 1 at the tip
                a = t * 2.6
                rad = r * (0.34 - t * 0.22)
                pos = (W * 0.6 + math.sin(a) * r * 0.75, D * 0.55 + math.cos(a) * r * 0.2, r * 0.3 + t * t * r * 1.1)
                sphere("Tail", pos, (rad, rad, rad), M["body"])
            sphere("Rattle", (pos[0], pos[1], pos[2] + r * 0.2), (r * 0.11, r * 0.11, r * 0.18), M["accent"])
        elif feature == "stack":
            for i in range(3):
                cylinder("Pancake", (0, 0, H * 0.5 + i * r * 0.26), W * 0.95, r * 0.2, M["belly"], bevel=0.05)
        elif feature == "wheels":
            for side in (-1, 1):
                cylinder("Wheel", (side * W * 0.95, 0, H * 0.5), r * 0.5, r * 0.18, M["wood"], rot=(0, math.pi / 2, 0), bevel=0.03)
        elif feature == "flame":
            # A flame tuft on the head (the game adds Fire particles on top).
            for dx, height, lean in ((0.0, 0.95, 0.0), (-0.2, 0.6, -0.35), (0.2, 0.68, 0.35)):
                cone("Flame", (dx * r, D * 0.1, crest + r * height * 0.5), r * 0.24, 0.0, r * height, M["flame"], rot=(0, lean, 0))
            cone("Flame", (0, D * 0.02, crest + r * 0.3), r * 0.14, 0.0, r * 0.55, M["flameCore"])

    return M


def merge_by_material():
    """Join all parts sharing a material into one object (one MeshPart per color in Roblox)."""
    by_mat = {}
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        for m in o.modifiers:
            bpy.ops.object.modifier_apply(modifier=m.name)
        by_mat.setdefault(o.data.materials[0].name, []).append(o)
    for name, objs in by_mat.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        bpy.context.active_object.name = name


def decimate(target=6500):
    total = triangle_count()
    if total <= target:
        return
    ratio = target / total
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            bpy.context.view_layer.objects.active = o
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.ratio = max(ratio, 0.15)
            bpy.ops.object.modifier_apply(modifier=mod.name)


def triangle_count():
    total = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            total += len(o.data.loop_triangles)
    return total


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 360
    scene.render.resolution_y = 360
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*srgb_to_linear(hex_rgb("#E8B97E")), 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(-35)))
    bpy.context.active_object.data.energy = 3.5
    bpy.context.active_object.data.color = (1.0, 0.9, 0.78)
    bpy.ops.object.camera_add(location=(2.4, -5.4, 2.6))
    cam = bpy.context.active_object
    target = Vector((0, 0, 1.15))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_fbx(path):
    for o in bpy.context.scene.objects:
        o.select_set(o.type == "MESH")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
    )


def main():
    ids = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    ids = ids or sorted(LOOKS)
    os.makedirs(os.path.join(OUT, "critters"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)
    report = {}
    for sid in ids:
        build(sid, LOOKS[sid])
        merge_by_material()
        decimate()
        tris = triangle_count()
        export_fbx(os.path.join(OUT, "critters", f"{sid}.fbx"))
        render_preview(os.path.join(OUT, "previews", f"{sid}.png"))
        report[sid] = tris
        print(f"[critter] {sid}: {tris} triangles", flush=True)
    json.dump(report, open(os.path.join(OUT, "critters", "triangles.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
