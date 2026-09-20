#!/usr/bin/env python3
"""Drifter kit meshes on the shared P0 skeleton. Run headless:

    /snap/bin/blender --background --python assets/chars/humanoid/_build_drifter.py

Same armature, sockets, and clips as char_humanoid.glb. No Dutch flag.
A: torn tarp poncho, rope belt. B: olive oilskin, orange life-vest scrap.
"""

from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_PATH = Path(__file__).resolve()
CHAR_DIR = SCRIPT_PATH.parent

_spec = importlib.util.spec_from_file_location(
    "polder_humanoid", CHAR_DIR / "_build_humanoid.py"
)
h = importlib.util.module_from_spec(_spec)
sys.modules["polder_humanoid"] = h
_spec.loader.exec_module(h)


DRIFTER_PALETTE = {
    "tarp":      ((0.28, 0.24, 0.16), 0.78, 0.00, 0.00),
    "tarp_dk":   ((0.16, 0.14, 0.10), 0.82, 0.00, 0.00),
    "tarp_wet":  ((0.18, 0.22, 0.20), 0.52, 0.00, 0.12),
    "patch_brn": ((0.32, 0.18, 0.10), 0.86, 0.00, 0.00),
    "rope":      ((0.42, 0.34, 0.22), 0.90, 0.00, 0.00),
    "olive":     ((0.22, 0.26, 0.12), 0.55, 0.00, 0.10),
    "olive_dk":  ((0.14, 0.16, 0.08), 0.62, 0.00, 0.06),
    "vest":      ((0.62, 0.22, 0.08), 0.72, 0.00, 0.00),
    "vest_dk":   ((0.38, 0.12, 0.05), 0.78, 0.00, 0.00),
    "rags":      ((0.22, 0.20, 0.16), 0.88, 0.00, 0.00),
}


def _mats() -> dict:
    mats = h.build_materials()
    for key, (rgb, rough, metal, coat) in DRIFTER_PALETTE.items():
        mats[key] = h.make_mat("mat_" + key, rgb, rough, metal, coat=coat)
    return mats


def _shared_head_legs(add, mats, layout) -> None:
    """Head, neck, hands, trousers, boots — same as unclassed, no coat/flag."""
    hl = layout
    add(h.sphere_obj("head", Vector((0.0, 0.02, 1.575)), 0.108, mats["skin"], 12, 8,
                     scale=Vector((0.90, 1.00, 1.06))),
        {"Head": 1.0})
    add(h.sphere_obj("hair", Vector((0.0, -0.01, 1.615)), 0.114, mats["hair"], 10, 7,
                     scale=Vector((0.96, 1.10, 0.98))),
        {"Head": 1.0})
    add(h.box_obj("nose", Vector((0.0, 0.112, 1.555)), (0.024, 0.038, 0.030), mats["skin"]),
        {"Head": 1.0})
    add(h.sphere_obj("eye_l", Vector((-0.032, 0.090, 1.585)), 0.016, mats["eye"], 8, 6),
        {"Head": 1.0})
    add(h.sphere_obj("eye_r", Vector((0.032, 0.090, 1.585)), 0.016, mats["eye"], 8, 6),
        {"Head": 1.0})
    add(h.cyl_obj("neck", (0, 0.01, 1.44), (0, 0.01, 1.51), 0.048, 0.052, mats["skin"], 8),
        {"Neck": 0.85, "Head": 0.15})

    lsh, lelb, lwri, lhand = hl["LeftUpperArm"][0], hl["LeftUpperArm"][1], hl["LeftLowerArm"][1], hl["LeftHand"][1]
    rsh, relb, rwri, rhand = hl["RightUpperArm"][0], hl["RightUpperArm"][1], hl["RightLowerArm"][1], hl["RightHand"][1]
    add(h.box_obj("hand_l", (lwri + lhand) * 0.5, (0.055, 0.085, 0.040), mats["skin"],
                  rot=(0.0, math.radians(-h.A_DEG), 0.0)),
        {"LeftHand": 1.0})
    add(h.box_obj("hand_r", (rwri + rhand) * 0.5, (0.055, 0.085, 0.040), mats["skin"],
                  rot=(0.0, math.radians(h.A_DEG), 0.0)),
        {"RightHand": 1.0})

    lhip, lknee = hl["LeftUpperLeg"][0], hl["LeftUpperLeg"][1]
    rhip, rknee = hl["RightUpperLeg"][0], hl["RightUpperLeg"][1]
    lank = hl["LeftLowerLeg"][1]
    rank = hl["RightLowerLeg"][1]
    add(h.box_obj("hips", (0.0, 0.01, 0.90), (0.28, 0.16, 0.16), mats["trousers"]),
        {"Hips": 0.80, "LeftUpperLeg": 0.10, "RightUpperLeg": 0.10})
    add(h.cyl_obj("thigh_l", lhip, lknee, 0.072, 0.055, mats["trousers"], 8),
        {"Hips": 0.15, "LeftUpperLeg": 0.85})
    add(h.cyl_obj("thigh_r", rhip, rknee, 0.072, 0.055, mats["trousers"], 8),
        {"Hips": 0.15, "RightUpperLeg": 0.85})
    add(h.cyl_obj("shin_l", lknee, lank + Vector((0, 0, 0.12)), 0.052, 0.046, mats["trousers"], 8),
        {"LeftUpperLeg": 0.20, "LeftLowerLeg": 0.80})
    add(h.cyl_obj("shin_r", rknee, rank + Vector((0, 0, 0.12)), 0.052, 0.046, mats["trousers"], 8),
        {"RightUpperLeg": 0.20, "RightLowerLeg": 0.80})
    add(h.box_obj("knee_l", lknee + Vector((-0.02, 0.04, 0.0)), (0.05, 0.04, 0.08), mats["patch_brn"]),
        {"LeftUpperLeg": 0.40, "LeftLowerLeg": 0.60})
    add(h.box_obj("knee_r", rknee + Vector((0.02, 0.04, 0.0)), (0.05, 0.04, 0.08), mats["patch_brn"]),
        {"RightUpperLeg": 0.40, "RightLowerLeg": 0.60})

    for side, ank, foot_bn, toe_bn in (
        ("l", lank, "LeftFoot", "LeftToes"),
        ("r", rank, "RightFoot", "RightToes"),
    ):
        add(h.cyl_obj(f"boot_shaft_{side}", ank + Vector((0, 0, 0.18)), ank + Vector((0, 0, 0.02)),
                      0.055, 0.058, mats["boots"], 8),
            {foot_bn: 0.70, "LeftLowerLeg" if side == "l" else "RightLowerLeg": 0.30})
        add(h.box_obj(f"boot_foot_{side}", (ank.x, 0.07, 0.055), (0.10, 0.22, 0.09), mats["boots"]),
            {foot_bn: 0.75, toe_bn: 0.25})
        add(h.box_obj(f"boot_toe_{side}", (ank.x, 0.16, 0.040), (0.09, 0.10, 0.06), mats["boot_mud"]),
            {foot_bn: 0.30, toe_bn: 0.70})
        add(h.box_obj(f"boot_sole_{side}", (ank.x, 0.08, 0.012), (0.10, 0.24, 0.022), mats["boot_mud"]),
            {foot_bn: 0.60, toe_bn: 0.40})


def build_drifter_a(mats, layout) -> bpy.types.Object:
    """Torn tarp poncho, hood, rope belt. Wider than the unclassed coat. No flag."""
    parts: list = []

    def add(obj, w):
        h.add_vg(obj, w)
        parts.append(obj)
        return obj

    _shared_head_legs(add, mats, layout)
    hl = layout
    lsh, lelb, lwri = hl["LeftUpperArm"][0], hl["LeftUpperArm"][1], hl["LeftLowerArm"][1]
    rsh, relb, rwri = hl["RightUpperArm"][0], hl["RightUpperArm"][1], hl["RightLowerArm"][1]

    add(h.collar_obj("hood_neck", (0.0, 0.00, 1.430), 0.095, 0.09, mats["tarp_dk"], 10),
        {"Neck": 0.55, "Chest": 0.45})
    add(h.sphere_obj("hood", Vector((0.0, -0.04, 1.58)), 0.145, mats["tarp"], 10, 7,
                     scale=Vector((1.05, 1.15, 0.92))),
        {"Head": 0.55, "Neck": 0.45})
    add(h.box_obj("hood_peak", Vector((0.0, 0.06, 1.68)), (0.16, 0.10, 0.06), mats["tarp_dk"]),
        {"Head": 0.70, "Neck": 0.30})

    add(h.cyl_obj("poncho", (0.0, 0.00, 1.38), (0.0, 0.02, 0.88), 0.22, 0.34, mats["tarp"], 10),
        {"Chest": 0.30, "Spine": 0.35, "Hips": 0.25, "LeftShoulder": 0.05, "RightShoulder": 0.05})
    add(h.cyl_obj("poncho_hem", (0.0, 0.02, 0.92), (0.0, 0.03, 0.78), 0.33, 0.36, mats["tarp_dk"], 10),
        {"Hips": 0.55, "LeftUpperLeg": 0.225, "RightUpperLeg": 0.225})
    add(h.box_obj("poncho_yoke", (0.0, 0.00, 1.36), (0.42, 0.20, 0.07), mats["tarp"]),
        {"Chest": 0.50, "LeftShoulder": 0.25, "RightShoulder": 0.25})

    add(h.box_obj("patch_chest_l", Vector((-0.08, 0.18, 1.18)), (0.10, 0.03, 0.12), mats["patch_brn"]),
        {"Chest": 0.80, "Spine": 0.20})
    add(h.box_obj("patch_chest_r", Vector((0.10, 0.16, 1.08)), (0.12, 0.03, 0.10), mats["tarp_wet"]),
        {"Chest": 0.60, "Spine": 0.40})
    add(h.box_obj("fray_1", Vector((-0.16, 0.10, 0.80)), (0.06, 0.04, 0.10), mats["tarp_dk"]),
        {"Hips": 0.80, "LeftUpperLeg": 0.20})
    add(h.box_obj("fray_2", Vector((0.14, 0.08, 0.78)), (0.07, 0.04, 0.12), mats["rags"]),
        {"Hips": 0.80, "RightUpperLeg": 0.20})
    add(h.box_obj("fray_3", Vector((0.00, 0.16, 0.79)), (0.08, 0.03, 0.08), mats["tarp_dk"]),
        {"Hips": 1.0})

    add(h.collar_obj("rope", (0.0, 0.02, 1.02), 0.20, 0.04, mats["rope"], 10),
        {"Spine": 0.40, "Hips": 0.60})
    add(h.box_obj("knot", Vector((0.0, 0.22, 1.00)), (0.06, 0.05, 0.07), mats["rope"]),
        {"Spine": 0.50, "Hips": 0.50})
    add(h.cyl_obj("rope_tail", (0.04, 0.20, 1.00), (0.06, 0.18, 0.82), 0.012, 0.010, mats["rope"], 6),
        {"Hips": 0.70, "Spine": 0.30})

    add(h.cyl_obj("arm_l", lsh, lelb, 0.055, 0.048, mats["tarp_wet"], 8),
        {"LeftShoulder": 0.20, "LeftUpperArm": 0.80})
    add(h.cyl_obj("arm_ll", lelb, lwri, 0.046, 0.042, mats["tarp_dk"], 8),
        {"LeftUpperArm": 0.25, "LeftLowerArm": 0.75})
    add(h.cyl_obj("arm_r", rsh, relb, 0.055, 0.048, mats["tarp_wet"], 8),
        {"RightShoulder": 0.20, "RightUpperArm": 0.80})
    add(h.cyl_obj("arm_rl", relb, rwri, 0.046, 0.042, mats["tarp_dk"], 8),
        {"RightUpperArm": 0.25, "RightLowerArm": 0.75})
    add(h.cyl_obj("wrap_l", lwri - (lwri - lelb).normalized() * 0.08, lwri, 0.048, 0.044, mats["knit"], 8),
        {"LeftLowerArm": 0.70, "LeftHand": 0.30})
    add(h.cyl_obj("cuff_r", rwri - (rwri - relb).normalized() * 0.04, rwri, 0.044, 0.042, mats["rags"], 8),
        {"RightLowerArm": 0.70, "RightHand": 0.30})

    body = h.join_objects("char_humanoid_drifter_a", parts)
    for bname in h.BONE_ORDER:
        if body.vertex_groups.get(bname) is None:
            body.vertex_groups.new(name=bname)
    return body


def build_drifter_b(mats, layout) -> bpy.types.Object:
    """Olive oilskin coat, orange life-vest scrap, rope across the chest. No flag."""
    parts: list = []

    def add(obj, w):
        h.add_vg(obj, w)
        parts.append(obj)
        return obj

    _shared_head_legs(add, mats, layout)
    hl = layout
    lsh, lelb, lwri = hl["LeftUpperArm"][0], hl["LeftUpperArm"][1], hl["LeftLowerArm"][1]
    rsh, relb, rwri = hl["RightUpperArm"][0], hl["RightUpperArm"][1], hl["RightLowerArm"][1]

    add(h.collar_obj("scarf", (0.0, 0.02, 1.430), 0.092, 0.10, mats["rags"], 10),
        {"Neck": 0.70, "Chest": 0.30})
    add(h.collar_obj("scarf2", (0.0, 0.03, 1.390), 0.100, 0.07, mats["rags"], 10),
        {"Neck": 0.40, "Chest": 0.60})

    add(h.box_obj("knit", (0.0, 0.04, 1.18), (0.16, 0.11, 0.32), mats["rags"]),
        {"Chest": 0.55, "Spine": 0.35, "Hips": 0.10})
    add(h.cyl_obj("coat", (0.0, 0.01, 1.40), (0.0, 0.02, 0.58), 0.175, 0.210, mats["olive"], 10),
        {"Chest": 0.35, "Spine": 0.35, "Hips": 0.30})
    add(h.box_obj("coat_yoke", (0.0, 0.00, 1.365), (0.30, 0.16, 0.08), mats["olive_dk"]),
        {"Chest": 0.70, "LeftShoulder": 0.15, "RightShoulder": 0.15})
    add(h.cyl_obj("hem", (0.0, 0.02, 0.70), (0.0, 0.03, 0.54), 0.205, 0.215, mats["olive_dk"], 10),
        {"Hips": 0.55, "LeftUpperLeg": 0.225, "RightUpperLeg": 0.225})

    add(h.box_obj("vest_l", Vector((-0.05, 0.14, 1.22)), (0.09, 0.06, 0.22), mats["vest"]),
        {"Chest": 0.85, "Spine": 0.15})
    add(h.box_obj("vest_r", Vector((0.05, 0.14, 1.22)), (0.09, 0.06, 0.22), mats["vest"]),
        {"Chest": 0.85, "Spine": 0.15})
    add(h.box_obj("vest_join", Vector((0.0, 0.15, 1.12)), (0.08, 0.05, 0.08), mats["vest_dk"]),
        {"Chest": 0.70, "Spine": 0.30})
    add(h.collar_obj("chest_rope", (0.0, 0.08, 1.16), 0.14, 0.035, mats["rope"], 10),
        {"Chest": 0.80, "Spine": 0.20})
    add(h.box_obj("chest_knot", Vector((0.0, 0.18, 1.14)), (0.05, 0.04, 0.05), mats["rope"]),
        {"Chest": 1.0})

    add(h.cyl_obj("sleeve_lu", lsh, lelb, 0.072, 0.058, mats["olive"], 8),
        {"LeftShoulder": 0.20, "LeftUpperArm": 0.80})
    add(h.cyl_obj("sleeve_ll", lelb, lwri, 0.056, 0.048, mats["olive_dk"], 8),
        {"LeftUpperArm": 0.25, "LeftLowerArm": 0.75})
    add(h.cyl_obj("sleeve_ru", rsh, relb, 0.072, 0.058, mats["olive"], 8),
        {"RightShoulder": 0.20, "RightUpperArm": 0.80})
    add(h.cyl_obj("sleeve_rl", relb, rwri, 0.056, 0.048, mats["olive_dk"], 8),
        {"RightUpperArm": 0.25, "RightLowerArm": 0.75})
    add(h.cyl_obj("cuff_l", lwri - (lwri - lelb).normalized() * 0.04, lwri, 0.046, 0.044, mats["rags"], 8),
        {"LeftLowerArm": 0.70, "LeftHand": 0.30})
    add(h.cyl_obj("cuff_r", rwri - (rwri - relb).normalized() * 0.04, rwri, 0.046, 0.044, mats["rags"], 8),
        {"RightLowerArm": 0.70, "RightHand": 0.30})

    body = h.join_objects("char_humanoid_drifter_b", parts)
    for bname in h.BONE_ORDER:
        if body.vertex_groups.get(bname) is None:
            body.vertex_groups.new(name=bname)
    return body


def _export_kit(name: str, builder) -> Path:
    print(f"== {name} ==")
    h._reset_scene()
    mats = _mats()
    layout = h.skeleton_layout()
    mesh = builder(mats, layout)
    print(f"  mesh verts={len(mesh.data.vertices)} faces={len(mesh.data.polygons)}")
    arm = h.build_armature(layout)
    h.bind(mesh, arm)
    sockets = h.build_sockets(arm)
    print("  sockets", [s.name for s in sockets])
    clips = h.make_actions(arm)
    if arm.animation_data:
        try:
            arm.animation_data.action = None
        except Exception:
            pass
    h.reset_pose(arm)
    arm.data.pose_position = "POSE"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 91
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    path = CHAR_DIR / f"{name}.glb"
    h.export_glb(path, [arm], with_anims=True, with_skins=True)
    h.inspect_glb(path)
    zmax = max(v.co.z for v in mesh.data.vertices)
    zmin = min(v.co.z for v in mesh.data.vertices)
    print(f"  height z=[{zmin:.3f}, {zmax:.3f}] clips={len(clips)}")
    return path


def main() -> None:
    _export_kit("char_humanoid_drifter_a", build_drifter_a)
    _export_kit("char_humanoid_drifter_b", build_drifter_b)
    print("== drifter kits done ==")


if __name__ == "__main__":
    main()
