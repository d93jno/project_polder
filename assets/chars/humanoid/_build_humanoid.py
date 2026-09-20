#!/usr/bin/env python3
"""P0 shared humanoid + animation library. Run headless:

    /snap/bin/blender --background --python assets/chars/humanoid/_build_humanoid.py

Blender is Z-up; glTF export uses +Y up for Godot 4.7.
Character faces +Y, origin between the feet, height 1.70 m.
Rest pose is A-pose. Root motion is in place.
"""

from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

# ---------------------------------------------------------------------------
# Paths / constants
# ---------------------------------------------------------------------------

SCRIPT_PATH = Path(__file__).resolve()
CHAR_DIR = SCRIPT_PATH.parent
ANIM_DIR = CHAR_DIR.parent / "anims"
PREVIEW_DIR = Path("/tmp/polder_humanoid")

HEIGHT = 1.70
FPS = 30

# A-pose: arms down from horizontal.
A_DEG = 28.0

# Palette: wet-slate teal coat, ochre/cream knit, rust, dirty cream.
# Linear-ish sRGB for Principled Base Color. (rgb, roughness, metallic, coat)
PALETTE = {
    "skin":      ((0.48, 0.34, 0.26), 0.58, 0.00, 0.00),
    "lip":       ((0.42, 0.24, 0.22), 0.48, 0.00, 0.00),
    "hair":      ((0.05, 0.045, 0.04), 0.38, 0.00, 0.00),
    "eye":       ((0.06, 0.06, 0.06), 0.22, 0.00, 0.00),
    "coat":      ((0.16, 0.24, 0.25), 0.46, 0.00, 0.18),
    "coat_dirt": ((0.18, 0.20, 0.14), 0.58, 0.00, 0.08),
    "knit":      ((0.58, 0.44, 0.26), 0.88, 0.00, 0.00),
    "knit_dk":   ((0.36, 0.24, 0.12), 0.86, 0.00, 0.00),
    "scarf":     ((0.32, 0.28, 0.20), 0.90, 0.00, 0.00),
    "trousers":  ((0.12, 0.16, 0.16), 0.78, 0.00, 0.00),
    "patch":     ((0.58, 0.38, 0.12), 0.80, 0.00, 0.00),
    "boots":     ((0.16, 0.09, 0.05), 0.62, 0.04, 0.00),
    "boot_mud":  ((0.11, 0.08, 0.05), 0.78, 0.00, 0.00),
    "flag_r":    ((0.55, 0.10, 0.08), 0.70, 0.00, 0.00),
    "flag_w":    ((0.80, 0.78, 0.72), 0.68, 0.00, 0.00),
    "flag_b":    ((0.12, 0.18, 0.42), 0.70, 0.00, 0.00),
    "rust":      ((0.42, 0.16, 0.08), 0.55, 0.28, 0.00),
    "iron":      ((0.16, 0.16, 0.16), 0.48, 0.70, 0.00),
    "iron_dk":   ((0.08, 0.08, 0.09), 0.50, 0.78, 0.00),
    "wood":      ((0.28, 0.16, 0.08), 0.82, 0.00, 0.00),
    "grip":      ((0.08, 0.08, 0.08), 0.72, 0.00, 0.00),
}


# ---------------------------------------------------------------------------
# Scene / materials
# ---------------------------------------------------------------------------

def _scene_coll():
    return bpy.context.scene.collection


def _reset_scene() -> None:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.cameras, bpy.data.lights,
                 bpy.data.curves, bpy.data.armatures, bpy.data.actions):
        for block in list(coll):
            try:
                coll.remove(block)
            except Exception:
                pass
    for block in list(bpy.data.materials):
        try:
            bpy.data.materials.remove(block)
        except Exception:
            pass
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    scene.frame_start = 1
    scene.frame_end = 60
    scene.cursor.location = (0.0, 0.0, 0.0)
    scene.frame_set(1)


def _bsdf(mat: bpy.types.Material):
    nt = mat.node_tree
    if nt is None:
        return None
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n
    return nt.nodes.get("Principled BSDF")


def make_mat(name: str, rgb, roughness: float, metallic: float,
             coat: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    bsdf = _bsdf(mat)
    if bsdf is None:
        return mat
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.45
    if coat > 0.0 and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.22
    return mat


def build_materials() -> dict[str, bpy.types.Material]:
    mats = {}
    for key, (rgb, rough, metal, coat) in PALETTE.items():
        mats[key] = make_mat("mat_" + key, rgb, rough, metal, coat=coat)
    return mats


def _link(obj: bpy.types.Object) -> bpy.types.Object:
    coll = _scene_coll()
    if obj.name not in coll.objects:
        coll.objects.link(obj)
    return obj


def _box_uv(mesh: bpy.types.Mesh, scale: float = 2.0) -> None:
    if mesh.uv_layers.active is None:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active
    for poly in mesh.polygons:
        n = poly.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index].co
            if az >= ax and az >= ay:
                uv.data[li].uv = (v.x * scale, v.y * scale)
            elif ax >= ay:
                uv.data[li].uv = (v.y * scale, v.z * scale)
            else:
                uv.data[li].uv = (v.x * scale, v.z * scale)


def _from_bm(name: str, bm: bmesh.types.BMesh, mat=None,
             smooth: bool = True) -> bpy.types.Object:
    bm.normal_update()
    try:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    except Exception:
        pass
    for f in bm.faces:
        f.smooth = smooth
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    _link(obj)
    if mat is not None:
        mesh.materials.append(mat)
    _box_uv(mesh)
    for p in mesh.polygons:
        p.use_smooth = smooth
    return obj


def _quat_z_to(direction: Vector) -> Matrix:
    d = Vector(direction)
    if d.length < 1e-8:
        return Matrix.Identity(4)
    d.normalize()
    z = Vector((0.0, 0.0, 1.0))
    if z.dot(d) < -0.999:
        return Matrix.Rotation(math.pi, 4, "X")
    return z.rotation_difference(d).to_matrix().to_4x4()


def cyl_obj(name: str, p0, p1, r0: float, r1: float, mat,
            segs: int = 8) -> bpy.types.Object:
    bm = bmesh.new()
    a, b = Vector(p0), Vector(p1)
    d = b - a
    length = max(d.length, 1e-4)
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs,
        radius1=r0, radius2=r1, depth=length,
    )
    mat4 = _quat_z_to(d)
    mat4.translation = (a + b) * 0.5
    bmesh.ops.transform(bm, verts=bm.verts, matrix=mat4)
    return _from_bm(name, bm, mat)


def sphere_obj(name: str, center, radius: float, mat,
               segments: int = 12, rings: int = 8,
               scale: Vector | None = None) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(
        bm, u_segments=segments, v_segments=rings, radius=radius,
    )
    m = Matrix.Identity(4)
    if scale is not None:
        m = Matrix.Diagonal((scale.x, scale.y, scale.z, 1.0))
    m.translation = Vector(center)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=m)
    return _from_bm(name, bm, mat)


def box_obj(name: str, center, size, mat, rot=None) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    m = Matrix.Diagonal((sx, sy, sz, 1.0))
    if rot is not None:
        m = Euler(rot, "XYZ").to_matrix().to_4x4() @ m
    m.translation = Vector(center)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=m)
    return _from_bm(name, bm, mat)


def collar_obj(name: str, center, radius: float, height: float, mat,
               segs: int = 10) -> bpy.types.Object:
    """Solid scarf collar (no torus op in this Blender)."""
    bm = bmesh.new()
    z0 = center[2] - height * 0.5
    z1 = center[2] + height * 0.5
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs,
        radius1=radius, radius2=radius * 1.05, depth=max(height, 1e-4),
    )
    mat4 = Matrix.Identity(4)
    mat4.translation = Vector((center[0], center[1], (z0 + z1) * 0.5))
    bmesh.ops.transform(bm, verts=bm.verts, matrix=mat4)
    return _from_bm(name, bm, mat)


def add_vg(obj: bpy.types.Object, weights: dict[str, float]) -> None:
    n = len(obj.data.vertices)
    idx = list(range(n))
    for name, w in weights.items():
        vg = obj.vertex_groups.get(name)
        if vg is None:
            vg = obj.vertex_groups.new(name=name)
        vg.add(idx, float(w), "REPLACE")


def join_objects(name: str, objects: list[bpy.types.Object]) -> bpy.types.Object:
    objects = [o for o in objects if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    if obj.data:
        obj.data.name = name + "_mesh"
        for p in obj.data.polygons:
            p.use_smooth = True
        _box_uv(obj.data)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


# ---------------------------------------------------------------------------
# Skeleton layout (shared by mesh + armature)
# ---------------------------------------------------------------------------

def skeleton_layout() -> dict:
    """Bone head/tail in metres. Character faces +Y, +Z up, +X = character's right."""
    hip_z = 0.940
    waist_z = 1.070
    chest_z = 1.250
    clav_z = 1.385
    neck_z = 1.455
    chin_z = 1.500
    crown_z = HEIGHT

    hip_x = 0.090
    sh_x = 0.155
    knee_z = 0.490
    ankle_z = 0.095
    toe_y = 0.195

    ang = math.radians(A_DEG)
    upper_len = 0.275
    lower_len = 0.245
    hand_len = 0.115

    def arm(sign: float):
        sh = Vector((sign * sh_x, 0.02, clav_z))
        d = Vector((sign * math.cos(ang), 0.05, -math.sin(ang))).normalized()
        elbow = sh + d * upper_len
        d2 = Vector((sign * math.cos(ang + 0.08), 0.12, -math.sin(ang + 0.12))).normalized()
        wrist = elbow + d2 * lower_len
        hand = wrist + d2 * hand_len
        return sh, elbow, wrist, hand

    lsh, lelb, lwri, lhand = arm(-1.0)
    rsh, relb, rwri, rhand = arm(1.0)

    lhip = Vector((-hip_x, 0.01, hip_z))
    rhip = Vector((hip_x, 0.01, hip_z))
    lknee = Vector((-hip_x, 0.035, knee_z))
    rknee = Vector((hip_x, 0.035, knee_z))
    lank = Vector((-hip_x, 0.00, ankle_z))
    rank = Vector((hip_x, 0.00, ankle_z))
    ltoe = Vector((-hip_x, toe_y, 0.028))
    rtoe = Vector((hip_x, toe_y, 0.028))
    ltoe_end = Vector((-hip_x, toe_y + 0.055, 0.024))
    rtoe_end = Vector((hip_x, toe_y + 0.055, 0.024))

    clav_l0 = Vector((-0.03, 0.01, clav_z))
    clav_r0 = Vector((0.03, 0.01, clav_z))

    bones = {
        "Hips":          (Vector((0.0, 0.00, hip_z)), Vector((0.0, 0.00, waist_z)), None, False),
        "Spine":         (Vector((0.0, 0.00, waist_z)), Vector((0.0, 0.02, chest_z)), "Hips", True),
        "Chest":         (Vector((0.0, 0.02, chest_z)), Vector((0.0, 0.01, clav_z)), "Spine", True),
        "Neck":          (Vector((0.0, 0.01, neck_z)), Vector((0.0, 0.00, chin_z)), "Chest", False),
        "Head":          (Vector((0.0, 0.00, chin_z)), Vector((0.0, 0.02, crown_z)), "Neck", True),
        "LeftShoulder":  (clav_l0, lsh, "Chest", False),
        "LeftUpperArm":  (lsh, lelb, "LeftShoulder", True),
        "LeftLowerArm":  (lelb, lwri, "LeftUpperArm", True),
        "LeftHand":      (lwri, lhand, "LeftLowerArm", True),
        "RightShoulder": (clav_r0, rsh, "Chest", False),
        "RightUpperArm": (rsh, relb, "RightShoulder", True),
        "RightLowerArm": (relb, rwri, "RightUpperArm", True),
        "RightHand":     (rwri, rhand, "RightLowerArm", True),
        "LeftUpperLeg":  (lhip, lknee, "Hips", False),
        "LeftLowerLeg":  (lknee, lank, "LeftUpperLeg", True),
        "LeftFoot":      (lank, ltoe, "LeftLowerLeg", True),
        "LeftToes":      (ltoe, ltoe_end, "LeftFoot", True),
        "RightUpperLeg": (rhip, rknee, "Hips", False),
        "RightLowerLeg": (rknee, rank, "RightUpperLeg", True),
        "RightFoot":     (rank, rtoe, "RightLowerLeg", True),
        "RightToes":     (rtoe, rtoe_end, "RightFoot", True),
    }
    return bones


BONE_ORDER = [
    "Hips", "Spine", "Chest", "Neck", "Head",
    "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
    "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]


# ---------------------------------------------------------------------------
# Body mesh
# ---------------------------------------------------------------------------

def build_body(mats, layout) -> bpy.types.Object:
    h = layout
    parts: list[bpy.types.Object] = []

    def add(obj, w):
        add_vg(obj, w)
        parts.append(obj)
        return obj

    # Head + hair
    head_c = Vector((0.0, 0.02, 1.575))
    add(sphere_obj("head", head_c, 0.108, mats["skin"], 12, 8,
                   scale=Vector((0.90, 1.00, 1.06))),
        {"Head": 1.0})
    add(sphere_obj("hair", Vector((0.0, -0.01, 1.615)), 0.114, mats["hair"], 10, 7,
                   scale=Vector((0.96, 1.10, 0.98))),
        {"Head": 1.0})
    add(box_obj("nose", Vector((0.0, 0.112, 1.555)), (0.024, 0.038, 0.030), mats["skin"]),
        {"Head": 1.0})
    add(sphere_obj("eye_l", Vector((-0.032, 0.090, 1.585)), 0.016, mats["eye"], 8, 6),
        {"Head": 1.0})
    add(sphere_obj("eye_r", Vector((0.032, 0.090, 1.585)), 0.016, mats["eye"], 8, 6),
        {"Head": 1.0})

    # Neck + scarf
    add(cyl_obj("neck", (0, 0.01, 1.44), (0, 0.01, 1.51), 0.048, 0.052, mats["skin"], 8),
        {"Neck": 0.85, "Head": 0.15})
    add(collar_obj("scarf", (0.0, 0.02, 1.430), 0.092, 0.10, mats["scarf"], 10),
        {"Neck": 0.70, "Chest": 0.30})
    add(collar_obj("scarf2", (0.0, 0.03, 1.390), 0.100, 0.07, mats["scarf"], 10),
        {"Neck": 0.40, "Chest": 0.60})

    # Knit torso (open-coat reveal on +Y)
    add(box_obj("knit", (0.0, 0.04, 1.18), (0.16, 0.11, 0.32), mats["knit"]),
        {"Chest": 0.55, "Spine": 0.35, "Hips": 0.10})
    add(box_obj("knit_core", (0.0, 0.05, 1.12), (0.10, 0.09, 0.14), mats["knit_dk"]),
        {"Chest": 0.40, "Spine": 0.50, "Hips": 0.10})
    add(box_obj("belt", (0.0, 0.03, 1.00), (0.20, 0.12, 0.045), mats["knit_dk"]),
        {"Spine": 0.40, "Hips": 0.60})

    # Coat: tapered hull, not a refrigerator slab.
    add(cyl_obj("coat", (0.0, 0.01, 1.40), (0.0, 0.02, 0.58), 0.175, 0.210, mats["coat"], 10),
        {"Chest": 0.35, "Spine": 0.35, "Hips": 0.30})
    add(box_obj("coat_yoke", (0.0, 0.00, 1.365), (0.30, 0.16, 0.08), mats["coat"]),
        {"Chest": 0.70, "LeftShoulder": 0.15, "RightShoulder": 0.15})
    add(cyl_obj("hem", (0.0, 0.02, 0.70), (0.0, 0.03, 0.54), 0.205, 0.215, mats["coat"], 10),
        {"Hips": 0.55, "LeftUpperLeg": 0.225, "RightUpperLeg": 0.225})
    add(box_obj("placket", (0.0, 0.12, 1.18), (0.09, 0.035, 0.30), mats["knit"]),
        {"Chest": 0.60, "Spine": 0.40})

    # Sleeves along A-pose arms
    lsh, lelb, lwri, lhand = h["LeftUpperArm"][0], h["LeftUpperArm"][1], h["LeftLowerArm"][1], h["LeftHand"][1]
    rsh, relb, rwri, rhand = h["RightUpperArm"][0], h["RightUpperArm"][1], h["RightLowerArm"][1], h["RightHand"][1]

    add(cyl_obj("sleeve_lu", lsh, lelb, 0.072, 0.058, mats["coat"], 8),
        {"LeftShoulder": 0.20, "LeftUpperArm": 0.80})
    add(cyl_obj("sleeve_ll", lelb, lwri, 0.056, 0.048, mats["coat"], 8),
        {"LeftUpperArm": 0.25, "LeftLowerArm": 0.75})
    add(cyl_obj("sleeve_ru", rsh, relb, 0.072, 0.058, mats["coat"], 8),
        {"RightShoulder": 0.20, "RightUpperArm": 0.80})
    add(cyl_obj("sleeve_rl", relb, rwri, 0.056, 0.048, mats["coat"], 8),
        {"RightUpperArm": 0.25, "RightLowerArm": 0.75})

    # Knit cuffs
    add(cyl_obj("cuff_l", lwri - (lwri - lelb).normalized() * 0.04, lwri, 0.046, 0.044, mats["knit"], 8),
        {"LeftLowerArm": 0.70, "LeftHand": 0.30})
    add(cyl_obj("cuff_r", rwri - (rwri - relb).normalized() * 0.04, rwri, 0.046, 0.044, mats["knit"], 8),
        {"RightLowerArm": 0.70, "RightHand": 0.30})

    # Elbow patches (outer)
    patch_l = lelb + Vector((-0.055, 0.0, 0.0))
    patch_r = relb + Vector((0.055, 0.0, 0.0))
    add(box_obj("patch_l", patch_l, (0.018, 0.055, 0.070), mats["patch"]),
        {"LeftUpperArm": 0.45, "LeftLowerArm": 0.55})
    add(box_obj("patch_r", patch_r, (0.018, 0.055, 0.070), mats["patch"]),
        {"RightUpperArm": 0.45, "RightLowerArm": 0.55})

    # Dutch tricolor on character's LEFT upper arm (outer / -X)
    mid_lu = (lsh + lelb) * 0.5 + Vector((-0.062, 0.0, 0.01))
    add(box_obj("flag_r", mid_lu + Vector((0, 0, 0.018)), (0.010, 0.046, 0.014), mats["flag_r"]),
        {"LeftUpperArm": 1.0})
    add(box_obj("flag_w", mid_lu, (0.010, 0.046, 0.014), mats["flag_w"]),
        {"LeftUpperArm": 1.0})
    add(box_obj("flag_b", mid_lu + Vector((0, 0, -0.018)), (0.010, 0.046, 0.014), mats["flag_b"]),
        {"LeftUpperArm": 1.0})

    # Hands
    add(box_obj("hand_l", (lwri + lhand) * 0.5, (0.055, 0.085, 0.040), mats["skin"],
                rot=(0.0, math.radians(-A_DEG), 0.0)),
        {"LeftHand": 1.0})
    add(box_obj("hand_r", (rwri + rhand) * 0.5, (0.055, 0.085, 0.040), mats["skin"],
                rot=(0.0, math.radians(A_DEG), 0.0)),
        {"RightHand": 1.0})

    # Trousers / legs
    lhip, lknee = h["LeftUpperLeg"][0], h["LeftUpperLeg"][1]
    rhip, rknee = h["RightUpperLeg"][0], h["RightUpperLeg"][1]
    lank = h["LeftLowerLeg"][1]
    rank = h["RightLowerLeg"][1]
    add(box_obj("hips", (0.0, 0.01, 0.90), (0.28, 0.16, 0.16), mats["trousers"]),
        {"Hips": 0.80, "LeftUpperLeg": 0.10, "RightUpperLeg": 0.10})
    add(cyl_obj("thigh_l", lhip, lknee, 0.072, 0.055, mats["trousers"], 8),
        {"Hips": 0.15, "LeftUpperLeg": 0.85})
    add(cyl_obj("thigh_r", rhip, rknee, 0.072, 0.055, mats["trousers"], 8),
        {"Hips": 0.15, "RightUpperLeg": 0.85})
    add(cyl_obj("shin_l", lknee, lank + Vector((0, 0, 0.12)), 0.052, 0.046, mats["trousers"], 8),
        {"LeftUpperLeg": 0.20, "LeftLowerLeg": 0.80})
    add(cyl_obj("shin_r", rknee, rank + Vector((0, 0, 0.12)), 0.052, 0.046, mats["trousers"], 8),
        {"RightUpperLeg": 0.20, "RightLowerLeg": 0.80})
    # Knee dirt patches
    add(box_obj("knee_l", lknee + Vector((-0.02, 0.04, 0.0)), (0.05, 0.04, 0.08), mats["patch"]),
        {"LeftUpperLeg": 0.40, "LeftLowerLeg": 0.60})
    add(box_obj("knee_r", rknee + Vector((0.02, 0.04, 0.0)), (0.05, 0.04, 0.08), mats["patch"]),
        {"RightUpperLeg": 0.40, "RightLowerLeg": 0.60})

    # Boots
    for side, ank, toe, foot_bn, toe_bn in (
        ("l", lank, h["LeftFoot"][1], "LeftFoot", "LeftToes"),
        ("r", rank, h["RightFoot"][1], "RightFoot", "RightToes"),
    ):
        add(cyl_obj(f"boot_shaft_{side}", ank + Vector((0, 0, 0.18)), ank + Vector((0, 0, 0.02)),
                    0.055, 0.058, mats["boots"], 8),
            {foot_bn: 0.70, "LeftLowerLeg" if side == "l" else "RightLowerLeg": 0.30})
        add(box_obj(f"boot_foot_{side}", (ank.x, 0.07, 0.055), (0.10, 0.22, 0.09), mats["boots"]),
            {foot_bn: 0.75, toe_bn: 0.25})
        add(box_obj(f"boot_toe_{side}", (ank.x, 0.16, 0.040), (0.09, 0.10, 0.06), mats["boot_mud"]),
            {foot_bn: 0.30, toe_bn: 0.70})
        add(box_obj(f"boot_sole_{side}", (ank.x, 0.08, 0.012), (0.10, 0.24, 0.022), mats["boot_mud"]),
            {foot_bn: 0.60, toe_bn: 0.40})

    body = join_objects("char_humanoid", parts)
    # Ensure every bone has a group so the exporter doesn't drop names.
    for bname in BONE_ORDER:
        if body.vertex_groups.get(bname) is None:
            body.vertex_groups.new(name=bname)
    return body


# ---------------------------------------------------------------------------
# Armature + bind + sockets
# ---------------------------------------------------------------------------

def _mode(obj, mode: str) -> None:
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode=mode)


def build_armature(layout) -> bpy.types.Object:
    data = bpy.data.armatures.new("Armature")
    data.display_type = "OCTAHEDRAL"
    arm = bpy.data.objects.new("Armature", data)
    arm.show_in_front = True
    _link(arm)
    _mode(arm, "EDIT")
    ebs = {}
    for name in BONE_ORDER:
        head, tail, parent, connected = layout[name]
        eb = data.edit_bones.new(name)
        eb.head = head
        eb.tail = tail
        eb.use_deform = True
        # Feet point forward: roll Z toward world +Z. Everything else: Z toward +Y.
        if name.endswith("Foot") or name.endswith("Toes"):
            eb.align_roll(Vector((0.0, 0.0, 1.0)))
        else:
            eb.align_roll(Vector((0.0, 1.0, 0.0)))
        ebs[name] = eb
    for name in BONE_ORDER:
        head, tail, parent, connected = layout[name]
        if parent:
            ebs[name].parent = ebs[parent]
            ebs[name].use_connect = connected
    _mode(arm, "POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    _mode(arm, "OBJECT")
    arm.location = (0.0, 0.0, 0.0)
    arm.rotation_euler = (0.0, 0.0, 0.0)
    arm.scale = (1.0, 1.0, 1.0)
    arm["polder_height"] = HEIGHT
    arm["polder_sockets"] = "hand_r,hand_l,back,head"
    arm["polder_root_motion"] = "in_place"
    return arm


def bind(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    mesh.parent = arm
    mesh.parent_type = "OBJECT"
    mesh.location = (0.0, 0.0, 0.0)
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False
    mod.use_deform_preserve_volume = False


def build_sockets(arm: bpy.types.Object) -> list[bpy.types.Object]:
    """Empties parented to bones. Bone-parent origin is the bone tail."""
    specs = [
        # name, bone, loc in bone-parent space (origin = tail)
        ("hand_r", "RightHand", (0.0, 0.0, 0.0)),
        ("hand_l", "LeftHand", (0.0, 0.0, 0.0)),
        ("back", "Chest", (0.0, -0.02, -0.12)),
        ("head", "Head", (0.0, 0.0, 0.0)),
    ]
    out = []
    for name, bone, loc in specs:
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.08
        _link(empty)
        empty.parent = arm
        empty.parent_type = "BONE"
        empty.parent_bone = bone
        empty.location = loc
        empty.rotation_euler = (0.0, 0.0, 0.0)
        empty["polder_socket"] = name
        empty["polder_bone"] = bone
        out.append(empty)
    return out


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

# Local-axis cheat sheet (align_roll +Y, A-pose):
#   Legs (bone Y down): +X swing forward, -X back / knee bend, +Z swing to -X.
#   Left arm:           +X swing forward, +Z raise, -Z lower.
#   Right arm:          +X swing forward, +Z lower, -Z raise.
#   Spine/Hips (Y up):  +X pitch forward, +Y twist (CCW from top), +Z roll right.


def _d2r(rot):
    return Euler((math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ")


def reset_pose(arm: bpy.types.Object) -> None:
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def apply_pose(arm: bpy.types.Object, pose: dict) -> None:
    reset_pose(arm)
    for name, data in pose.items():
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        rot = data.get("rot", (0.0, 0.0, 0.0))
        loc = data.get("loc", (0.0, 0.0, 0.0))
        pb.rotation_euler = _d2r(rot)
        pb.location = Vector(loc)


def mix_pose(a: dict, b: dict, t: float) -> dict:
    keys = set(a) | set(b)
    out = {}
    for k in keys:
        ra = a.get(k, {}).get("rot", (0.0, 0.0, 0.0))
        rb = b.get(k, {}).get("rot", (0.0, 0.0, 0.0))
        la = a.get(k, {}).get("loc", (0.0, 0.0, 0.0))
        lb = b.get(k, {}).get("loc", (0.0, 0.0, 0.0))
        out[k] = {
            "rot": tuple(ra[i] + (rb[i] - ra[i]) * t for i in range(3)),
            "loc": tuple(la[i] + (lb[i] - la[i]) * t for i in range(3)),
        }
    return out


def key_all(arm: bpy.types.Object, frame: int) -> None:
    # Do not scene.frame_set here: that re-evaluates the action and
    # overwrites the pose we just applied (Blender 5 layered actions).
    for pb in arm.pose.bones:
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        pb.keyframe_insert(data_path="location", frame=frame)
        pb.keyframe_insert(data_path="scale", frame=frame)


def set_interpolation(action, mode: str = "BEZIER") -> None:
    for layer in action.layers:
        for strip in layer.strips:
            bags = getattr(strip, "channelbags", None)
            if not bags:
                continue
            for cb in bags:
                for fc in cb.fcurves:
                    fc.extrapolation = "LINEAR"
                    for kp in fc.keyframe_points:
                        kp.interpolation = mode
                        kp.easing = "AUTO"
                        kp.handle_left_type = "AUTO_CLAMPED"
                        kp.handle_right_type = "AUTO_CLAMPED"


def assign_action(arm: bpy.types.Object, action: bpy.types.Action) -> None:
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    slots = getattr(action, "slots", None)
    if slots:
        try:
            arm.animation_data.action_slot = slots[0]
        except Exception:
            pass


def new_action(arm: bpy.types.Object, name: str, start: int, end: int,
               cyclic: bool) -> bpy.types.Action:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start = float(start)
    action.frame_end = float(end)
    action.use_cyclic = cyclic
    assign_action(arm, action)
    reset_pose(arm)
    return action


# ----- clip poses ----------------------------------------------------------

def pose_idle(phase: float = 0.0) -> dict:
    s = math.sin(phase * 2.0 * math.pi)
    c = math.cos(phase * 2.0 * math.pi)
    return {
        "Hips":          {"rot": (3.0, 4.0 * s, 0.0), "loc": (0.008 * s, 0.0, 0.010 * c)},
        "Spine":         {"rot": (5.0 + 1.2 * c, 2.0 * s, 0.0)},
        "Chest":         {"rot": (4.0 + 1.8 * c, 0.0, 0.0)},
        "Neck":          {"rot": (-3.0, 0.0, 0.0)},
        "Head":          {"rot": (8.0 + 1.5 * s, 10.0 + 3.0 * c, 0.0)},
        "LeftShoulder":  {"rot": (6.0, 0.0, 8.0)},
        "RightShoulder": {"rot": (4.0, 0.0, -6.0)},
        "LeftUpperArm":  {"rot": (12.0, 8.0, -42.0)},
        "LeftLowerArm":  {"rot": (18.0, 0.0, -14.0)},
        "LeftHand":      {"rot": (8.0, 0.0, -10.0)},
        "RightUpperArm": {"rot": (8.0, -6.0, 36.0)},
        "RightLowerArm": {"rot": (22.0, 0.0, 10.0)},
        "RightHand":     {"rot": (12.0, 20.0, 8.0)},
        "LeftUpperLeg":  {"rot": (3.0, 0.0, -3.0)},
        "LeftLowerLeg":  {"rot": (-6.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (4.0, 0.0, 4.0)},
        "RightUpperLeg": {"rot": (4.0, 0.0, 3.0)},
        "RightLowerLeg": {"rot": (-7.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (5.0, 0.0, -4.0)},
    }


def pose_walk(t: float) -> dict:
    """t in [0, 1) = two steps. t=0 left-forward contact, t=0.25 right passing."""
    w = 2.0 * math.pi * t
    lf = math.cos(w)
    rf = -math.cos(w)
    l_up = max(0.0, -math.sin(w))
    r_up = max(0.0, math.sin(w))
    bob = -0.014 * math.cos(2.0 * w)
    hip_yaw = -8.0 * lf
    hip_roll = 4.0 * lf
    return {
        "Hips":          {"rot": (6.0, hip_yaw, hip_roll), "loc": (0.0, 0.0, bob)},
        "Spine":         {"rot": (6.0, -0.5 * hip_yaw, 0.0)},
        "Chest":         {"rot": (4.0, -0.4 * hip_yaw, 0.0)},
        "Neck":          {"rot": (-2.0, 0.0, 0.0)},
        "Head":          {"rot": (6.0, 0.3 * hip_yaw, 0.0)},
        "LeftShoulder":  {"rot": (4.0, 0.0, 6.0)},
        "RightShoulder": {"rot": (4.0, 0.0, -6.0)},
        "LeftUpperArm":  {"rot": (-34.0 * lf, 0.0, -34.0)},
        "LeftLowerArm":  {"rot": (16.0 + 10.0 * max(0.0, -lf), 0.0, -8.0)},
        "LeftHand":      {"rot": (6.0, 0.0, 0.0)},
        "RightUpperArm": {"rot": (-34.0 * rf, 0.0, 32.0)},
        "RightLowerArm": {"rot": (16.0 + 10.0 * max(0.0, -rf), 0.0, 8.0)},
        "RightHand":     {"rot": (8.0, 16.0, 6.0)},
        "LeftUpperLeg":  {"rot": (40.0 * lf, 0.0, -2.0)},
        "LeftLowerLeg":  {"rot": (-12.0 - 48.0 * l_up, 0.0, 0.0)},
        "LeftFoot":      {"rot": (8.0 - 18.0 * l_up, 0.0, 2.0)},
        "LeftToes":      {"rot": (10.0 * l_up, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (40.0 * rf, 0.0, 2.0)},
        "RightLowerLeg": {"rot": (-12.0 - 48.0 * r_up, 0.0, 0.0)},
        "RightFoot":     {"rot": (8.0 - 18.0 * r_up, 0.0, -2.0)},
        "RightToes":     {"rot": (10.0 * r_up, 0.0, 0.0)},
    }


def pose_swim(t: float) -> dict:
    w = 2.0 * math.pi * t
    a = math.sin(w)
    b = math.sin(w + math.pi)
    kick = math.sin(2.0 * w)
    return {
        "Hips":          {"rot": (78.0 + 3.0 * math.sin(w), 0.0, 4.0 * a),
                          "loc": (0.0, 0.10, -0.20 + 0.03 * math.cos(w))},
        "Spine":         {"rot": (8.0, 6.0 * a, 0.0)},
        "Chest":         {"rot": (6.0, 8.0 * a, 0.0)},
        "Neck":          {"rot": (-18.0, 0.0, 0.0)},
        "Head":          {"rot": (-12.0, 0.0, 0.0)},
        "LeftShoulder":  {"rot": (8.0, 0.0, 16.0)},
        "RightShoulder": {"rot": (8.0, 0.0, -16.0)},
        "LeftUpperArm":  {"rot": (25.0 + 35.0 * a, 0.0, 58.0)},
        "LeftLowerArm":  {"rot": (18.0 + 28.0 * max(0.0, a), 0.0, 8.0)},
        "LeftHand":      {"rot": (0.0, 0.0, 12.0 * a)},
        "RightUpperArm": {"rot": (25.0 + 35.0 * b, 0.0, -58.0)},
        "RightLowerArm": {"rot": (18.0 + 28.0 * max(0.0, b), 0.0, -8.0)},
        "RightHand":     {"rot": (0.0, 0.0, -12.0 * b)},
        "LeftUpperLeg":  {"rot": (18.0 + 22.0 * kick, 0.0, -8.0)},
        "LeftLowerLeg":  {"rot": (-20.0 - 25.0 * max(0.0, kick), 0.0, 0.0)},
        "LeftFoot":      {"rot": (10.0, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (18.0 - 22.0 * kick, 0.0, 8.0)},
        "RightLowerLeg": {"rot": (-20.0 - 25.0 * max(0.0, -kick), 0.0, 0.0)},
        "RightFoot":     {"rot": (10.0, 0.0, 0.0)},
    }


def pose_climb(t: float) -> dict:
    w = 2.0 * math.pi * t
    a = math.sin(w)
    b = math.sin(w + math.pi)
    bob = 0.06 * math.sin(w)
    return {
        "Hips":          {"rot": (8.0, 5.0 * a, 0.0), "loc": (0.0, 0.04, bob)},
        "Spine":         {"rot": (10.0, -4.0 * a, 0.0)},
        "Chest":         {"rot": (8.0, -6.0 * a, 0.0)},
        "Neck":          {"rot": (-8.0, 0.0, 0.0)},
        "Head":          {"rot": (-16.0, 0.0, 0.0)},
        "LeftShoulder":  {"rot": (8.0, 0.0, 18.0)},
        "RightShoulder": {"rot": (8.0, 0.0, -18.0)},
        "LeftUpperArm":  {"rot": (20.0, 0.0, 72.0 + 16.0 * a)},
        "LeftLowerArm":  {"rot": (28.0 - 16.0 * a, 0.0, 8.0)},
        "LeftHand":      {"rot": (0.0, 0.0, 0.0)},
        "RightUpperArm": {"rot": (20.0, 0.0, -72.0 - 16.0 * b)},
        "RightLowerArm": {"rot": (28.0 - 16.0 * b, 0.0, -8.0)},
        "RightHand":     {"rot": (0.0, 0.0, 0.0)},
        "LeftUpperLeg":  {"rot": (35.0 * max(0.0, a) + 8.0, 0.0, -4.0)},
        "LeftLowerLeg":  {"rot": (-50.0 * max(0.0, a) - 8.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (6.0, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (35.0 * max(0.0, b) + 8.0, 0.0, 4.0)},
        "RightLowerLeg": {"rot": (-50.0 * max(0.0, b) - 8.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (6.0, 0.0, 0.0)},
    }


def pose_watch(phase: float = 0.0) -> dict:
    s = math.sin(phase * 2.0 * math.pi)
    return {
        "Hips":          {"rot": (8.0, -8.0, 4.0), "loc": (0.0, 0.02, -0.04 + 0.006 * s)},
        "Spine":         {"rot": (8.0, -4.0, 0.0)},
        "Chest":         {"rot": (10.0, -6.0, 0.0)},
        "Neck":          {"rot": (-4.0, 4.0, 0.0)},
        "Head":          {"rot": (4.0 + 1.0 * s, 6.0, 0.0)},
        "LeftShoulder":  {"rot": (16.0, 0.0, 12.0)},
        "RightShoulder": {"rot": (18.0, 0.0, -10.0)},
        "LeftUpperArm":  {"rot": (62.0, 12.0, 8.0)},
        "LeftLowerArm":  {"rot": (48.0, 0.0, 16.0)},
        "LeftHand":      {"rot": (10.0, 20.0, 8.0)},
        "RightUpperArm": {"rot": (70.0, -8.0, -6.0)},
        "RightLowerArm": {"rot": (22.0, 0.0, -8.0)},
        "RightHand":     {"rot": (8.0, -10.0, 0.0)},
        "LeftUpperLeg":  {"rot": (18.0, 0.0, -6.0)},
        "LeftLowerLeg":  {"rot": (-22.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (6.0, 0.0, 6.0)},
        "RightUpperLeg": {"rot": (8.0, 0.0, 8.0)},
        "RightLowerLeg": {"rot": (-10.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (4.0, 0.0, -4.0)},
    }


def pose_aim(phase: float = 0.0) -> dict:
    s = math.sin(phase * 2.0 * math.pi)
    return {
        "Hips":          {"rot": (6.0, -4.0, 2.0), "loc": (0.0, 0.03, -0.02 + 0.004 * s)},
        "Spine":         {"rot": (6.0, -2.0, 0.0)},
        "Chest":         {"rot": (8.0, -4.0, 0.0)},
        "Neck":          {"rot": (-2.0, 2.0, 0.0)},
        "Head":          {"rot": (2.0 + 0.8 * s, 4.0, 0.0)},
        "LeftShoulder":  {"rot": (14.0, 0.0, 10.0)},
        "RightShoulder": {"rot": (16.0, 0.0, -8.0)},
        "LeftUpperArm":  {"rot": (72.0, 8.0, 4.0)},
        "LeftLowerArm":  {"rot": (36.0, 0.0, 12.0)},
        "LeftHand":      {"rot": (8.0, 16.0, 6.0)},
        "RightUpperArm": {"rot": (78.0, -4.0, -4.0)},
        "RightLowerArm": {"rot": (10.0, 0.0, -4.0)},
        "RightHand":     {"rot": (4.0, -8.0, 0.0)},
        "LeftUpperLeg":  {"rot": (10.0, 0.0, -4.0)},
        "LeftLowerLeg":  {"rot": (-12.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (4.0, 0.0, 4.0)},
        "RightUpperLeg": {"rot": (14.0, 0.0, 6.0)},
        "RightLowerLeg": {"rot": (-16.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (6.0, 0.0, -4.0)},
    }


def pose_melee(t: float) -> dict:
    """t in [0, 1]. Windup → slash → recover."""
    idle = pose_idle(0.0)
    wind = {
        "Hips":          {"rot": (6.0, 28.0, 4.0), "loc": (0.0, -0.02, 0.0)},
        "Spine":         {"rot": (8.0, 18.0, 0.0)},
        "Chest":         {"rot": (6.0, 16.0, 0.0)},
        "Neck":          {"rot": (-4.0, -8.0, 0.0)},
        "Head":          {"rot": (6.0, -10.0, 0.0)},
        "LeftShoulder":  {"rot": (8.0, 0.0, 10.0)},
        "RightShoulder": {"rot": (12.0, 0.0, -16.0)},
        "LeftUpperArm":  {"rot": (16.0, 0.0, -30.0)},
        "LeftLowerArm":  {"rot": (20.0, 0.0, -8.0)},
        "RightUpperArm": {"rot": (-50.0, -24.0, -62.0)},
        "RightLowerArm": {"rot": (48.0, 0.0, -12.0)},
        "RightHand":     {"rot": (10.0, 30.0, 0.0)},
        "LeftUpperLeg":  {"rot": (8.0, 0.0, -6.0)},
        "LeftLowerLeg":  {"rot": (-10.0, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (16.0, 0.0, 8.0)},
        "RightLowerLeg": {"rot": (-14.0, 0.0, 0.0)},
    }
    strike = {
        "Hips":          {"rot": (10.0, -34.0, -6.0), "loc": (0.0, 0.04, -0.02)},
        "Spine":         {"rot": (12.0, -22.0, 0.0)},
        "Chest":         {"rot": (10.0, -24.0, 0.0)},
        "Neck":          {"rot": (4.0, 12.0, 0.0)},
        "Head":          {"rot": (8.0, 14.0, 0.0)},
        "LeftShoulder":  {"rot": (6.0, 0.0, 8.0)},
        "RightShoulder": {"rot": (18.0, 0.0, -8.0)},
        "LeftUpperArm":  {"rot": (20.0, 0.0, -24.0)},
        "LeftLowerArm":  {"rot": (28.0, 0.0, 6.0)},
        "RightUpperArm": {"rot": (85.0, 16.0, 28.0)},
        "RightLowerArm": {"rot": (6.0, 0.0, 18.0)},
        "RightHand":     {"rot": (0.0, -20.0, 0.0)},
        "LeftUpperLeg":  {"rot": (18.0, 0.0, -8.0)},
        "LeftLowerLeg":  {"rot": (-16.0, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (6.0, 0.0, 10.0)},
        "RightLowerLeg": {"rot": (-10.0, 0.0, 0.0)},
    }
    if t < 0.28:
        u = t / 0.28
        u = u * u
        return mix_pose(idle, wind, u)
    if t < 0.48:
        u = (t - 0.28) / 0.20
        u = u * u * (3.0 - 2.0 * u)
        return mix_pose(wind, strike, u)
    u = (t - 0.48) / 0.52
    u = u * u * (3.0 - 2.0 * u)
    return mix_pose(strike, idle, u)


def pose_flinch(t: float) -> dict:
    idle = pose_idle(0.0)
    duck = {
        "Hips":          {"rot": (22.0, 14.0, -10.0), "loc": (0.0, -0.05, -0.28)},
        "Spine":         {"rot": (22.0, 8.0, 0.0)},
        "Chest":         {"rot": (16.0, 6.0, 0.0)},
        "Neck":          {"rot": (8.0, -6.0, 0.0)},
        "Head":          {"rot": (22.0, 18.0, -10.0)},
        "LeftShoulder":  {"rot": (20.0, 0.0, 16.0)},
        "RightShoulder": {"rot": (8.0, 0.0, -8.0)},
        "LeftUpperArm":  {"rot": (30.0, 0.0, 28.0)},
        "LeftLowerArm":  {"rot": (50.0, 0.0, 10.0)},
        "LeftHand":      {"rot": (10.0, 0.0, 0.0)},
        "RightUpperArm": {"rot": (16.0, 0.0, 28.0)},
        "RightLowerArm": {"rot": (30.0, 0.0, 8.0)},
        "RightHand":     {"rot": (12.0, 16.0, 8.0)},
        "LeftUpperLeg":  {"rot": (62.0, 0.0, -8.0)},
        "LeftLowerLeg":  {"rot": (-78.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (16.0, 0.0, 6.0)},
        "RightUpperLeg": {"rot": (48.0, 0.0, 14.0)},
        "RightLowerLeg": {"rot": (-18.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (8.0, 0.0, -8.0)},
    }
    if t < 0.45:
        u = t / 0.45
        u = u * u * (3.0 - 2.0 * u)
        return mix_pose(idle, duck, u)
    return duck


def pose_downed(phase: float = 0.0) -> dict:
    s = math.sin(phase * 2.0 * math.pi)
    return {
        "Hips":          {"rot": (12.0, 8.0, 78.0 + 1.5 * s),
                          "loc": (0.12, 0.05, -0.78 + 0.008 * s)},
        "Spine":         {"rot": (16.0 + 2.0 * s, 6.0, 4.0)},
        "Chest":         {"rot": (10.0 + 2.5 * s, 4.0, 0.0)},
        "Neck":          {"rot": (8.0, -8.0, 0.0)},
        "Head":          {"rot": (18.0 + 2.0 * s, -16.0, -8.0)},
        "LeftShoulder":  {"rot": (10.0, 0.0, 20.0)},
        "RightShoulder": {"rot": (6.0, 0.0, -8.0)},
        "LeftUpperArm":  {"rot": (40.0, 0.0, 20.0)},
        "LeftLowerArm":  {"rot": (36.0, 0.0, 8.0)},
        "LeftHand":      {"rot": (8.0, 0.0, 0.0)},
        "RightUpperArm": {"rot": (50.0 + 4.0 * s, 10.0, 16.0)},
        "RightLowerArm": {"rot": (18.0, 0.0, 8.0)},
        "RightHand":     {"rot": (10.0, 12.0, 6.0)},
        "LeftUpperLeg":  {"rot": (72.0, 0.0, -10.0)},
        "LeftLowerLeg":  {"rot": (-78.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (12.0, 0.0, 0.0)},
        "RightUpperLeg": {"rot": (58.0, 0.0, 16.0)},
        "RightLowerLeg": {"rot": (-64.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (10.0, 0.0, 0.0)},
    }


def pose_boat_sit(phase: float = 0.0) -> dict:
    s = math.sin(phase * 2.0 * math.pi)
    return {
        "Hips":          {"rot": (8.0, 0.0, 0.0), "loc": (0.0, 0.06, -0.48 + 0.008 * s)},
        "Spine":         {"rot": (-6.0 + 1.5 * s, 0.0, 0.0)},
        "Chest":         {"rot": (-4.0 + 1.8 * s, 0.0, 0.0)},
        "Neck":          {"rot": (4.0, 0.0, 0.0)},
        "Head":          {"rot": (6.0 + 1.0 * s, 6.0, 0.0)},
        "LeftShoulder":  {"rot": (4.0, 0.0, 8.0)},
        "RightShoulder": {"rot": (4.0, 0.0, -8.0)},
        "LeftUpperArm":  {"rot": (18.0, 0.0, -18.0)},
        "LeftLowerArm":  {"rot": (42.0, 0.0, -6.0)},
        "LeftHand":      {"rot": (8.0, 0.0, 0.0)},
        "RightUpperArm": {"rot": (16.0, 0.0, 16.0)},
        "RightLowerArm": {"rot": (40.0, 0.0, 6.0)},
        "RightHand":     {"rot": (8.0, 12.0, 0.0)},
        "LeftUpperLeg":  {"rot": (78.0, 0.0, -8.0)},
        "LeftLowerLeg":  {"rot": (-78.0, 0.0, 0.0)},
        "LeftFoot":      {"rot": (4.0, 0.0, 4.0)},
        "RightUpperLeg": {"rot": (80.0, 0.0, 8.0)},
        "RightLowerLeg": {"rot": (-80.0, 0.0, 0.0)},
        "RightFoot":     {"rot": (4.0, 0.0, -4.0)},
    }


def _key_loop(arm, nframes: int, pose_fn, cyclic: bool = True) -> None:
    for i in range(nframes):
        t = i / float(nframes) if cyclic else i / float(max(nframes - 1, 1))
        apply_pose(arm, pose_fn(t))
        key_all(arm, i + 1)
    if cyclic:
        apply_pose(arm, pose_fn(0.0))
        key_all(arm, nframes + 1)


def make_actions(arm: bpy.types.Object) -> list[tuple[str, int, bool]]:
    clips: list[tuple[str, int, bool, object, str]] = [
        # name, frames, loop, builder, interpolation
        ("idle",       60, True,  lambda t: pose_idle(t), "BEZIER"),
        ("walk",       32, True,  pose_walk, "LINEAR"),
        ("swim",       40, True,  pose_swim, "LINEAR"),
        ("climb",      40, True,  pose_climb, "LINEAR"),
        ("watch",      60, True,  pose_watch, "BEZIER"),
        ("aim_pistol", 60, True,  pose_aim, "BEZIER"),
        ("melee",      24, False, pose_melee, "BEZIER"),
        ("flinch",     16, False, pose_flinch, "BEZIER"),
        ("downed",     90, True,  pose_downed, "BEZIER"),
        ("boat_sit",   60, True,  pose_boat_sit, "BEZIER"),
    ]
    report = []
    for name, nframes, loop, fn, ipo in clips:
        end = nframes + 1 if loop else nframes
        action = new_action(arm, name, 1, end, loop)
        _key_loop(arm, nframes, fn, cyclic=loop)
        set_interpolation(action, ipo)
        report.append((name, end, loop))
        print(f"  clip {name:12} frames=1..{end} loop={loop}")
    return report


# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

def build_machete(mats) -> bpy.types.Object:
    """Origin at grip. Blade along +Y (Godot -Z forward). Handle along -Z."""
    parts = []
    # Handle along -Z from +0.02 to -0.10
    parts.append(cyl_obj("handle", (0, 0.0, 0.02), (0, 0.0, -0.11), 0.016, 0.018, mats["wood"], 8))
    parts.append(sphere_obj("pommel", (0, 0.0, -0.115), 0.018, mats["wood"], 8, 6))
    parts.append(box_obj("guard", (0.0, 0.01, 0.025), (0.04, 0.012, 0.012), mats["iron"]))
    # Blade: y 0.02 → 0.50, thin X, height Z
    parts.append(box_obj("blade", (0.0, 0.26, 0.035), (0.006, 0.46, 0.055), mats["rust"]))
    parts.append(box_obj("edge", (0.0, 0.28, 0.006), (0.003, 0.42, 0.010), mats["iron"]))
    obj = join_objects("char_kit_machete", parts)
    obj["polder_origin"] = "grip"
    obj["polder_forward"] = "+Y"
    return obj


def build_pistol(mats) -> bpy.types.Object:
    """Origin at grip (web of the hand). Barrel along +Y. Grip along -Z."""
    parts = []
    parts.append(box_obj("slide", (0.0, 0.075, 0.028), (0.028, 0.155, 0.032), mats["iron"]))
    parts.append(box_obj("barrel", (0.0, 0.145, 0.026), (0.016, 0.040, 0.016), mats["iron_dk"]))
    parts.append(box_obj("frame", (0.0, 0.040, 0.010), (0.024, 0.080, 0.028), mats["iron_dk"]))
    parts.append(box_obj("grip", (0.0, 0.012, -0.045), (0.026, 0.032, 0.095), mats["grip"]))
    parts.append(box_obj("guard", (0.0, 0.038, -0.012), (0.012, 0.034, 0.028), mats["iron"]))
    parts.append(box_obj("trigger", (0.0, 0.036, -0.012), (0.006, 0.010, 0.018), mats["iron_dk"]))
    parts.append(box_obj("sight_f", (0.0, 0.145, 0.048), (0.006, 0.010, 0.010), mats["iron_dk"]))
    parts.append(box_obj("sight_r", (0.0, 0.012, 0.048), (0.010, 0.008, 0.010), mats["iron_dk"]))
    obj = join_objects("char_kit_pistol", parts)
    obj["polder_origin"] = "grip"
    obj["polder_forward"] = "+Y"
    return obj


# ---------------------------------------------------------------------------
# Export / inspect
# ---------------------------------------------------------------------------

def _select_hierarchy(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    def sel(o):
        o.select_set(True)
        for c in o.children:
            sel(c)

    for o in objects:
        sel(o)
    bpy.context.view_layer.objects.active = objects[0]


def export_glb(path: Path, objects: list[bpy.types.Object],
               with_anims: bool, with_skins: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    _select_hierarchy(objects)
    kwargs = dict(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_texcoords=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        export_morph=False,
        export_skins=with_skins,
        export_animations=with_anims,
        export_current_frame=False,
        export_def_bones=False,
        export_leaf_bone=False,
        export_rest_position_armature=True,
    )
    if with_anims:
        kwargs.update(
            export_animation_mode="ACTIONS",
            export_force_sampling=True,
            export_nla_strips=True,
            export_anim_single_armature=True,
            export_reset_pose_bones=True,
            export_optimize_animation_size=True,
            export_optimize_animation_keep_anim_armature=True,
            export_anim_slide_to_zero=True,
            export_frame_range=False,
        )
    if with_skins:
        kwargs.update(export_influence_nb=4, export_all_influences=False)
    bpy.ops.export_scene.gltf(**kwargs)
    print(f"  wrote {path}  ({path.stat().st_size} bytes)")


def inspect_glb(path: Path) -> dict:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise RuntimeError(f"{path} is not a glTF file")
    chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
    gltf = json.loads(data[20:20 + chunk_len])
    nodes = [n.get("name", "") for n in gltf.get("nodes", [])]
    anims = gltf.get("animations", [])
    skins = gltf.get("skins", [])
    extras_sockets = []
    for i, n in enumerate(gltf.get("nodes", [])):
        if n.get("name") in ("hand_r", "hand_l", "back", "head"):
            parent = None
            for j, p in enumerate(gltf.get("nodes", [])):
                if i in p.get("children", []):
                    parent = p.get("name")
                    break
            extras_sockets.append((n.get("name"), parent, n.get("extras")))
    if extras_sockets:
        print(f"    sockets: {extras_sockets}")
    joints = []
    if skins:
        jidx = skins[0].get("joints", [])
        joints = [gltf["nodes"][i].get("name", "") for i in jidx]
    mesh_count = len(gltf.get("meshes", []))
    print(f"  inspect {path.name}")
    print(f"    nodes: {nodes}")
    print(f"    joints: {joints}")
    print(f"    meshes: {mesh_count}  anims: {[a.get('name') for a in anims]}")
    for a in anims:
        chans = a.get("channels", [])
        samps = a.get("samplers", [])
        tmax = 0.0
        for s in samps:
            acc = gltf["accessors"][s["input"]]
            tmax = max(tmax, acc.get("max", [0])[0])
        print(f"      {a.get('name')}: channels={len(chans)} duration={tmax:.3f}s")
    return gltf


# ---------------------------------------------------------------------------
# Previews (QA only, /tmp)
# ---------------------------------------------------------------------------

def _setup_preview_world() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        scene.world = world
    nt = world.node_tree
    if nt is None:
        world.use_nodes = True
        nt = world.node_tree
    bg = None
    for n in nt.nodes:
        if n.type == "BACKGROUND":
            bg = n
            break
    if bg:
        bg.inputs[0].default_value = (0.22, 0.28, 0.26, 1.0)
        bg.inputs[1].default_value = 0.55
    if "preview_key" not in bpy.data.objects:
        light = bpy.data.lights.new("preview_key", "AREA")
        light.energy = 400.0
        light.size = 2.4
        lo = bpy.data.objects.new("preview_key", light)
        lo.location = (2.4, 3.2, 3.4)
        lo.rotation_euler = (math.radians(55), 0.0, math.radians(40))
        _link(lo)
    if "preview_fill" not in bpy.data.objects:
        light = bpy.data.lights.new("preview_fill", "AREA")
        light.energy = 120.0
        light.size = 4.0
        lo = bpy.data.objects.new("preview_fill", light)
        lo.location = (-2.8, 1.6, 2.2)
        _link(lo)
    if "preview_cam" not in bpy.data.objects:
        cam = bpy.data.cameras.new("preview_cam")
        cam.lens = 45
        cobj = bpy.data.objects.new("preview_cam", cam)
        _link(cobj)
        scene.camera = cobj
    else:
        scene.camera = bpy.data.objects["preview_cam"]


def _aim_cam(loc, target) -> None:
    cam = bpy.data.objects["preview_cam"]
    cam.location = Vector(loc)
    vec = Vector(target) - Vector(loc)
    cam.rotation_euler = vec.to_track_quat("-Z", "Y").to_euler()


def render_preview(arm, action_name: str, frame: int, tag: str,
                   loc=(-1.85, 3.15, 1.45), target=(0.0, 0.05, 0.88)) -> None:
    _setup_preview_world()
    action = bpy.data.actions.get(action_name)
    if action is None:
        print(f"  missing action {action_name}")
        return
    assign_action(arm, action)
    arm.data.pose_position = "POSE"
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = arm.pose.bones.get("RightUpperArm")
    if pb:
        e = tuple(round(math.degrees(x), 1) for x in pb.rotation_euler)
        print(f"  pose {tag}: RightUpperArm deg={e}")
    _aim_cam(loc, target)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    path = PREVIEW_DIR / f"{tag}.png"
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print(f"  preview {path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("== P0 humanoid ==")
    _reset_scene()
    mats = build_materials()
    layout = skeleton_layout()
    print("  layout bones", list(layout))
    mesh = build_body(mats, layout)
    print(f"  mesh verts={len(mesh.data.vertices)} faces={len(mesh.data.polygons)}")
    arm = build_armature(layout)
    bind(mesh, arm)
    sockets = build_sockets(arm)
    print("  sockets", [s.name for s in sockets])
    clips = make_actions(arm)

    if arm.animation_data:
        try:
            arm.animation_data.action = None
        except Exception:
            pass
    reset_pose(arm)
    # Must stay POSE: REST makes the glTF sampler see a constant bind pose.
    arm.data.pose_position = "POSE"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 91
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()

    char_path = CHAR_DIR / "char_humanoid.glb"
    anim_path = ANIM_DIR / "char_humanoid_anims.glb"
    export_glb(char_path, [arm], with_anims=True, with_skins=True)
    export_glb(anim_path, [arm], with_anims=True, with_skins=True)
    arm.data.pose_position = "POSE"

    machete = build_machete(mats)
    pistol = build_pistol(mats)
    export_glb(CHAR_DIR / "char_kit_machete.glb", [machete], with_anims=False, with_skins=False)
    export_glb(CHAR_DIR / "char_kit_pistol.glb", [pistol], with_anims=False, with_skins=False)

    inspect_glb(char_path)
    inspect_glb(anim_path)
    inspect_glb(CHAR_DIR / "char_kit_machete.glb")
    inspect_glb(CHAR_DIR / "char_kit_pistol.glb")

    # Hide weapons for pose previews
    machete.hide_render = True
    pistol.hide_render = True
    try:
        render_preview(arm, "idle", 1, "idle")
        render_preview(arm, "walk", 1, "walk_contact")
        render_preview(arm, "walk", 9, "walk_pass")
        render_preview(arm, "swim", 1, "swim",
                       loc=(-2.2, 2.0, 1.7), target=(0.0, 0.15, 0.75))
        render_preview(arm, "climb", 1, "climb")
        render_preview(arm, "watch", 1, "watch")
        render_preview(arm, "aim_pistol", 1, "aim_pistol")
        render_preview(arm, "melee", 12, "melee")
        render_preview(arm, "flinch", 16, "flinch")
        render_preview(arm, "downed", 1, "downed",
                       loc=(-1.6, 2.2, 1.1), target=(0.15, 0.1, 0.35))
        render_preview(arm, "boat_sit", 1, "boat_sit",
                       loc=(-1.8, 2.8, 1.15), target=(0.0, 0.08, 0.55))
    except Exception as e:
        print("  preview failed:", e)

    zmax = max(v.co.z for v in mesh.data.vertices)
    zmin = min(v.co.z for v in mesh.data.vertices)
    print(f"  height rest mesh z=[{zmin:.3f}, {zmax:.3f}] clips={len(clips)}")
    print("== done ==")


if __name__ == "__main__":
    main()
