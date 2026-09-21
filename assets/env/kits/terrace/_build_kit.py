#!/usr/bin/env python3
"""P0 terrace GridMap kit + ridge. Run headless:

    /snap/bin/blender --background --python assets/env/kits/terrace/_build_kit.py

Cell size is 2.0 m. Blender is Z-up; glTF export uses +Y up for Godot.
Origins sit at the tile / footprint centre. Ground walking plane is Z=0.
No baked shadows, no lightmaps, no per-water-step mesh duplicates.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

# ---------------------------------------------------------------------------
# Paths / constants
# ---------------------------------------------------------------------------

CELL = 2.0
HALF = CELL * 0.5
STOREY = 3.0
HUMAN = 1.7

# House shells occupy 2x2 cells so a 1.7 m body can stand in a room.
HOUSE = 4.0
HOUSE_HALF = HOUSE * 0.5
WALL_T = 0.22
EAVE_Z = 6.15
RIDGE_Z = 7.85

LEVEE_H = 2.0
CREST_HALF = 0.40
TOE_HALF = 1.00

SCRIPT_PATH = Path(__file__).resolve()
KIT_DIR = SCRIPT_PATH.parent
HERO_DIR = KIT_DIR.parents[1] / "hero"  # assets/env/hero

# ---------------------------------------------------------------------------
# Palette (style lock: wet-slate teal, ochre brick, rust, dirty cream)
# Linear-ish sRGB values for Principled Base Color.
# ---------------------------------------------------------------------------

PALETTE = {
    "asphalt":        ((0.11, 0.12, 0.13), 0.88, 0.00),
    "asphalt_b":      ((0.16, 0.15, 0.14), 0.84, 0.00),
    "asphalt_c":      ((0.13, 0.12, 0.11), 0.90, 0.00),
    "paver":          ((0.30, 0.28, 0.25), 0.78, 0.00),
    "concrete":       ((0.40, 0.39, 0.36), 0.82, 0.00),
    "concrete_wet":   ((0.28, 0.29, 0.28), 0.55, 0.00),
    "stone":          ((0.46, 0.45, 0.40), 0.80, 0.00),
    "coping":         ((0.55, 0.53, 0.46), 0.70, 0.00),
    "sand":           ((0.62, 0.54, 0.38), 0.95, 0.00),
    "ridge_sand":     ((0.68, 0.58, 0.40), 0.96, 0.00),
    "ridge_dark":     ((0.48, 0.42, 0.30), 0.94, 0.00),
    "brick_ochre":    ((0.62, 0.40, 0.16), 0.72, 0.00),
    "brick_red":      ((0.50, 0.26, 0.18), 0.74, 0.00),
    "brick_brown":    ((0.36, 0.24, 0.16), 0.76, 0.00),
    "brick_dark":     ((0.22, 0.15, 0.11), 0.78, 0.00),
    "plaster":        ((0.72, 0.64, 0.48), 0.70, 0.00),
    "plaster_dirty":  ((0.56, 0.50, 0.40), 0.74, 0.00),
    "terracotta":     ((0.52, 0.24, 0.14), 0.62, 0.00),
    "terracotta_dk":  ((0.38, 0.18, 0.12), 0.66, 0.00),
    "bitumen":        ((0.07, 0.07, 0.08), 0.85, 0.00),
    "rust":           ((0.42, 0.16, 0.08), 0.58, 0.35),
    "iron":           ((0.18, 0.17, 0.16), 0.42, 0.72),
    "iron_dark":      ((0.08, 0.08, 0.09), 0.48, 0.80),
    "iron_green":     ((0.22, 0.26, 0.22), 0.50, 0.45),
    "wood":           ((0.34, 0.22, 0.12), 0.82, 0.00),
    "wood_wet":       ((0.20, 0.14, 0.08), 0.70, 0.00),
    "wood_pale":      ((0.48, 0.36, 0.22), 0.78, 0.00),
    "tarp_blue":      ((0.12, 0.28, 0.48), 0.72, 0.00),
    "tarp_orange":    ((0.72, 0.32, 0.10), 0.70, 0.00),
    "window":         ((0.05, 0.07, 0.08), 0.12, 0.00),
    "door_cream":     ((0.74, 0.70, 0.62), 0.68, 0.00),
    "door_dark":      ((0.10, 0.09, 0.08), 0.62, 0.00),
    "soil":           ((0.20, 0.15, 0.10), 0.95, 0.00),
    "glass_glint":    ((0.55, 0.72, 0.74), 0.08, 0.05),
    "interior":       ((0.38, 0.34, 0.28), 0.85, 0.00),
    "mortar":         ((0.50, 0.46, 0.40), 0.86, 0.00),
}


def _scene_coll():
    return bpy.context.scene.collection


def _reset_scene() -> None:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.cameras, bpy.data.lights, bpy.data.curves):
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
    scene.cursor.location = (0.0, 0.0, 0.0)


def _bsdf(mat: bpy.types.Material):
    nt = mat.node_tree
    if nt is None:
        return None
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n
    return nt.nodes.get("Principled BSDF")


def make_mat(name: str, rgb, roughness: float, metallic: float,
             emit=None, coat: float = 0.0) -> bpy.types.Material:
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
        bsdf.inputs["Coat Roughness"].default_value = 0.18
    if emit is not None:
        col, strength = emit
        bsdf.inputs["Emission Color"].default_value = (col[0], col[1], col[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _load_image(path: Path) -> bpy.types.Image | None:
    if not path.is_file():
        return None
    img = bpy.data.images.load(str(path), check_existing=True)
    try:
        img.pack()
    except Exception:
        pass
    return img


def _bind_albedo(mat: bpy.types.Material, img: bpy.types.Image) -> None:
    nt = mat.node_tree
    bsdf = _bsdf(mat)
    if nt is None or bsdf is None:
        return
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    tex.extension = "REPEAT"
    tex.location = (-420.0, 280.0)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def build_materials() -> dict[str, bpy.types.Material]:
    mats = {}
    for key, (rgb, rough, metal) in PALETTE.items():
        coat = 0.18 if key.startswith("asphalt") or key == "concrete_wet" else 0.0
        emit = None
        if key == "glass_glint":
            emit = ((0.70, 0.86, 0.88), 1.8)
        mats[key] = make_mat("mat_" + key, rgb, rough, metal, emit=emit, coat=coat)

    tex = KIT_DIR / "textures"
    # Only tileable kit albedos. env_street_slab_c.png is a plaster/photo
    # ghost, not a road — leave it off the street meshes.
    binds = {
        "asphalt": "env_street_slab_a.png",
        "asphalt_b": "env_street_slab_a.png",
        "asphalt_c": "env_street_slab_a.png",
        "paver": "env_curb.png",
        "stone": "env_canal_wall.png",
        "sand": "env_levee_fill.png",
        "ridge_sand": "env_levee_fill.png",
    }
    cache: dict[str, bpy.types.Image | None] = {}
    for mat_key, filename in binds.items():
        if filename not in cache:
            cache[filename] = _load_image(tex / filename)
        img = cache[filename]
        if img is not None and mat_key in mats:
            _bind_albedo(mats[mat_key], img)
            print(f"  albedo {mat_key} <- {filename}")
    return mats


def _link(obj: bpy.types.Object) -> bpy.types.Object:
    coll = _scene_coll()
    if obj.name not in coll.objects:
        coll.objects.link(obj)
    return obj


def _assign_mat(obj: bpy.types.Object, mat: bpy.types.Material | None) -> None:
    if mat is None:
        return
    mesh = obj.data
    if mesh.materials:
        mesh.materials[0] = mat
    else:
        mesh.materials.append(mat)
    for p in mesh.polygons:
        p.material_index = 0
        p.use_smooth = False


def _box_uv(mesh: bpy.types.Mesh, scale: float = 0.5) -> None:
    """World-metre box UVs. scale 0.5 → one texture repeat per 2 m cell."""
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


def _from_bm(name: str, bm: bmesh.types.BMesh, mat=None, smooth: bool = False) -> bpy.types.Object:
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
    _assign_mat(obj, mat)
    _box_uv(mesh)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    return obj


def box(name: str, xmin, xmax, ymin, ymax, zmin, zmax, mat=None) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = (xmax - xmin), (ymax - ymin), (zmax - zmin)
    cx, cy, cz = (xmin + xmax) * 0.5, (ymin + ymax) * 0.5, (zmin + zmax) * 0.5
    for v in bm.verts:
        v.co.x = v.co.x * sx + cx
        v.co.y = v.co.y * sy + cy
        v.co.z = v.co.z * sz + cz
    return _from_bm(name, bm, mat)


def cyl(name: str, radius: float, zmin: float, zmax: float, mat=None,
        segments: int = 12, x: float = 0.0, y: float = 0.0) -> bpy.types.Object:
    bm = bmesh.new()
    h = zmax - zmin
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segments,
        radius1=radius, radius2=radius, depth=max(h, 0.001),
    )
    cz = (zmin + zmax) * 0.5
    for v in bm.verts:
        v.co.x += x
        v.co.y += y
        v.co.z += cz
    return _from_bm(name, bm, mat)


def cone(name: str, r0: float, r1: float, zmin: float, zmax: float, mat=None,
         segments: int = 12, x: float = 0.0, y: float = 0.0) -> bpy.types.Object:
    bm = bmesh.new()
    h = zmax - zmin
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segments,
        radius1=r0, radius2=r1, depth=max(h, 0.001),
    )
    cz = (zmin + zmax) * 0.5
    for v in bm.verts:
        v.co.x += x
        v.co.y += y
        v.co.z += cz
    return _from_bm(name, bm, mat)


def empty(name: str) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.4
    obj.location = (0.0, 0.0, 0.0)
    _link(obj)
    return obj


def combine(name: str, objects: list[bpy.types.Object]) -> bpy.types.Object:
    objects = [o for o in objects if o is not None]
    if not objects:
        raise ValueError(f"combine({name!r}) got no objects")
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
            p.use_smooth = False
        _box_uv(obj.data)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


def parent(child: bpy.types.Object, parent_obj: bpy.types.Object) -> None:
    child.parent = parent_obj
    child.matrix_parent_inverse = parent_obj.matrix_world.inverted()


def delete_objects(objects: list[bpy.types.Object]) -> None:
    for o in list(objects):
        if o is None:
            continue
        children = list(o.children)
        delete_objects(children)
        me = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


def export_glb(path: Path, objects: list[bpy.types.Object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")

    def _sel(o: bpy.types.Object) -> None:
        o.select_set(True)
        for c in o.children:
            _sel(c)

    for o in objects:
        _sel(o)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
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
        export_animations=False,
        export_skins=False,
        export_extras=False,
        export_morph=False,
        export_vertex_color="MATERIAL",
    )
    print(f"  wrote {path.relative_to(KIT_DIR.parents[2])}  ({path.stat().st_size} bytes)")


def finish(path: Path, objects: list[bpy.types.Object]) -> None:
    export_glb(path, objects)
    delete_objects(objects)


# ---------------------------------------------------------------------------
# Shared geometry helpers
# ---------------------------------------------------------------------------

def rects_subtract(xmin, xmax, zmin, zmax, holes):
    """Fill a wall rectangle minus axis-aligned holes. holes: (x0,x1,z0,z1)."""
    zs = {zmin, zmax}
    for h in holes:
        zs.add(h[2])
        zs.add(h[3])
    zs = sorted(zs)
    out = []
    for i in range(len(zs) - 1):
        a, b = zs[i], zs[i + 1]
        if b - a < 1e-5:
            continue
        active = [h for h in holes if h[2] <= a + 1e-5 and h[3] >= b - 1e-5]
        xs = {xmin, xmax}
        for h in active:
            xs.add(h[0])
            xs.add(h[1])
        xs = sorted(xs)
        for j in range(len(xs) - 1):
            c, d = xs[j], xs[j + 1]
            if d - c < 1e-5:
                continue
            covered = any(h[0] <= c + 1e-5 and h[1] >= d - 1e-5 for h in active)
            if not covered:
                out.append((c, d, a, b))
    return out


def wall_y(name, y0, y1, xmin, xmax, zmin, zmax, holes, mat, mats_win, win_inset=0.06):
    """Wall spanning Y=[y0,y1]. holes in (x0,x1,z0,z1)."""
    parts = []
    rects = rects_subtract(xmin, xmax, zmin, zmax, holes)
    for i, (x0, x1, z0, z1) in enumerate(rects):
        parts.append(box(f"{name}_w{i}", x0, x1, y0, y1, z0, z1, mat))
    inward = 1.0 if y1 > y0 else -1.0
    for i, (hx0, hx1, hz0, hz1) in enumerate(holes):
        # inset frame + dark glass, not a through-hole (LOS is data, not mesh)
        fy0 = y0 + inward * 0.02
        fy1 = y0 + inward * (abs(y1 - y0) * 0.45 + win_inset)
        parts.append(box(f"{name}_fr{i}", hx0, hx1, min(fy0, fy1), max(fy0, fy1),
                         hz0, hz1, mats_win["iron_dark"]))
        gpad = 0.04
        gy = y0 + inward * (abs(y1 - y0) * 0.55)
        parts.append(box(f"{name}_gl{i}", hx0 + gpad, hx1 - gpad, gy - 0.02, gy + 0.02,
                         hz0 + gpad, hz1 - gpad, mats_win["window"]))
    return parts


def wall_x(name, x0, x1, ymin, ymax, zmin, zmax, holes, mat, mats_win, win_inset=0.06):
    """Wall spanning X=[x0,x1]. holes in (y0,y1,z0,z1)."""
    parts = []
    rects = rects_subtract(ymin, ymax, zmin, zmax, holes)
    for i, (y0, y1, z0, z1) in enumerate(rects):
        parts.append(box(f"{name}_w{i}", x0, x1, y0, y1, z0, z1, mat))
    inward = 1.0 if x1 > x0 else -1.0
    for i, (hy0, hy1, hz0, hz1) in enumerate(holes):
        fx0 = x0 + inward * 0.02
        fx1 = x0 + inward * (abs(x1 - x0) * 0.45 + win_inset)
        parts.append(box(f"{name}_fr{i}", min(fx0, fx1), max(fx0, fx1), hy0, hy1,
                         hz0, hz1, mats_win["iron_dark"]))
        gpad = 0.04
        gx = x0 + inward * (abs(x1 - x0) * 0.55)
        parts.append(box(f"{name}_gl{i}", gx - 0.02, gx + 0.02, hy0 + gpad, hy1 - gpad,
                         hz0 + gpad, hz1 - gpad, mats_win["window"]))
    return parts


def gable_roof(name, xmin, xmax, ymin, ymax, z_eaves, z_ridge, mat, thickness=0.10):
    """Ridge along X (parallel to the street). Two sloped leaves + gable fills."""
    mx = (xmin + xmax) * 0.5
    verts = [
        (xmin, ymin, z_eaves), (xmax, ymin, z_eaves),
        (xmax, ymax, z_eaves), (xmin, ymax, z_eaves),
        (mx, ymin, z_ridge), (mx, ymax, z_ridge),
        (xmin, ymin, z_eaves - thickness), (xmax, ymin, z_eaves - thickness),
        (xmax, ymax, z_eaves - thickness), (xmin, ymax, z_eaves - thickness),
        (mx, ymin, z_ridge - thickness), (mx, ymax, z_ridge - thickness),
    ]
    faces = [
        (0, 4, 5, 3),  # -X slope
        (1, 2, 5, 4),  # +X slope
        (0, 1, 4),     # -Y gable
        (3, 5, 2),     # +Y gable
        (6, 9, 11, 10),
        (7, 10, 11, 8),
        (0, 3, 9, 6),
        (1, 7, 8, 2),
        (0, 6, 7, 1),
        (3, 2, 8, 9),
    ]
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in verts]
    bm.verts.ensure_lookup_table()
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _from_bm(name, bm, mat)


def height_from_dist(d: float, h: float = LEVEE_H) -> float:
    if d <= CREST_HALF:
        return h
    if d >= TOE_HALF:
        return 0.0
    t = (d - CREST_HALF) / (TOE_HALF - CREST_HALF)
    return h * (1.0 - t)


def _seg_dist(px, py, ax, ay, bx, by) -> float:
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    c1 = vx * wx + vy * wy
    if c1 <= 0.0:
        return math.hypot(px - ax, py - ay)
    c2 = vx * vx + vy * vy
    if c2 <= c1:
        return math.hypot(px - bx, py - by)
    t = c1 / c2
    return math.hypot(px - (ax + t * vx), py - (ay + t * vy))


def solid_heightfield(name, size, segs, hfn, mat, z_min=0.0, smooth: bool = False) -> bpy.types.Object:
    """Solid heightfield on XY, origin-centred, skirted to z_min."""
    bm = bmesh.new()
    n = segs
    half = size * 0.5
    step = size / n
    grid = []
    for j in range(n + 1):
        row = []
        y = -half + j * step
        for i in range(n + 1):
            x = -half + i * step
            h = max(0.0, hfn(x, y))
            row.append((x, y, h))
        grid.append(row)

    top_verts = [[bm.verts.new(Vector((x, y, z_min + h if h > 0.01 else z_min)))
                  for (x, y, h) in row] for row in grid]
    bm.verts.ensure_lookup_table()

    for j in range(n):
        for i in range(n):
            h00 = grid[j][i][2]
            h10 = grid[j][i + 1][2]
            h01 = grid[j + 1][i][2]
            h11 = grid[j + 1][i + 1][2]
            if max(h00, h10, h01, h11) < 0.02:
                continue
            v00, v10 = top_verts[j][i], top_verts[j][i + 1]
            v01, v11 = top_verts[j + 1][i], top_verts[j + 1][i + 1]
            try:
                bm.faces.new((v00, v10, v11, v01))
            except ValueError:
                pass

    # skirt along the four borders down to z_min
    def skirt(edge_pairs):
        for (a, b) in edge_pairs:
            lo_a = bm.verts.new(Vector((a.co.x, a.co.y, z_min)))
            lo_b = bm.verts.new(Vector((b.co.x, b.co.y, z_min)))
            try:
                bm.faces.new((a, b, lo_b, lo_a))
            except ValueError:
                pass

    # -Y and +Y rows, -X and +X cols
    pairs = []
    for i in range(n):
        pairs.append((top_verts[0][i], top_verts[0][i + 1]))          # -Y, winding out
        pairs.append((top_verts[n][i + 1], top_verts[n][i]))          # +Y
    for j in range(n):
        pairs.append((top_verts[j + 1][0], top_verts[j][0]))          # -X
        pairs.append((top_verts[j][n], top_verts[j + 1][n]))          # +X
    skirt(pairs)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
    return _from_bm(name, bm, mat, smooth=smooth)


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------

def build_street_slabs(mats, out: Path) -> None:
    # A — wet asphalt, drain grate, faint joint
    parts = [
        box("slab", -HALF, HALF, -HALF, HALF, -0.15, 0.0, mats["asphalt"]),
        box("grate", -0.22, 0.22, 0.62, 0.88, -0.02, 0.012, mats["iron"]),
        box("slot", -0.18, 0.18, 0.70, 0.80, 0.010, 0.018, mats["iron_dark"]),
        box("joint_x", -HALF, HALF, -0.012, 0.012, -0.002, 0.004, mats["asphalt_b"]),
        box("joint_y", -0.012, 0.012, -HALF, HALF, -0.002, 0.004, mats["asphalt_b"]),
    ]
    finish(out / "env_street_slab_a.glb", [combine("env_street_slab_a", parts)])

    # B — concrete pavers (4 large flags)
    parts = [box("base", -HALF, HALF, -HALF, HALF, -0.16, -0.02, mats["concrete"])]
    gap = 0.04
    tile = (CELL - 3 * gap) / 2.0
    k = 0
    for iy in range(2):
        for ix in range(2):
            x0 = -HALF + gap + ix * (tile + gap)
            y0 = -HALF + gap + iy * (tile + gap)
            parts.append(box(f"pv{k}", x0, x0 + tile, y0, y0 + tile, -0.02, 0.0, mats["paver"]))
            k += 1
    finish(out / "env_street_slab_b.glb", [combine("env_street_slab_b", parts)])

    # C — patched asphalt, ochre repair, manhole
    parts = [
        box("slab", -HALF, HALF, -HALF, HALF, -0.15, 0.0, mats["asphalt_c"]),
        box("patch", -0.85, -0.10, -0.70, 0.35, -0.005, 0.012, mats["asphalt_b"]),
        box("patch2", 0.20, 0.95, 0.15, 0.90, -0.005, 0.010, mats["mortar"]),
        cyl("manhole", 0.28, -0.02, 0.014, mats["iron"], segments=14, x=0.45, y=-0.50),
        cyl("lid", 0.22, 0.012, 0.020, mats["iron_dark"], segments=14, x=0.45, y=-0.50),
    ]
    finish(out / "env_street_slab_c.glb", [combine("env_street_slab_c", parts)])


def build_curb(mats, out: Path) -> None:
    # Sits on the +Y edge of a street cell. 0.16 m upstand, 0.30 m tread.
    parts = [
        box("upstand", -HALF, HALF, 0.70, 1.00, 0.0, 0.16, mats["paver"]),
        box("taper", -HALF, HALF, 0.62, 0.72, 0.0, 0.06, mats["paver"]),
    ]
    finish(out / "env_curb.glb", [combine("env_curb", parts)])


def _canal_wall(name, height, mats) -> bpy.types.Object:
    # Masonry quay, walkable coping. Runs along X, thickness in Y.
    t = 0.62
    y0, y1 = -t * 0.5, t * 0.5
    parts = [
        box("body", -HALF, HALF, y0, y1, 0.0, height - 0.10, mats["stone"]),
        box("coping", -HALF, HALF, y0 - 0.04, y1 + 0.04, height - 0.10, height, mats["stone"]),
        # water-side batter strip
        box("batter", -HALF, HALF, y1 - 0.02, y1 + 0.08, 0.0, height - 0.12, mats["stone"]),
        # land-side footing
        box("foot", -HALF, HALF, y0 - 0.10, y0 + 0.02, 0.0, 0.18, mats["concrete"]),
    ]
    # vertical joints so it tiles as blocks, not a slab
    for i, x in enumerate((-0.66, 0.0, 0.66)):
        parts.append(box(f"j{i}", x - 0.012, x + 0.012, y0 + 0.02, y1 - 0.02,
                         0.10, height - 0.14, mats["mortar"]))
    return combine(name, parts)


def build_canal_walls(mats, out: Path) -> None:
    finish(out / "env_canal_wall.glb", [_canal_wall("env_canal_wall", 1.20, mats)])
    finish(out / "env_canal_wall_tall.glb", [_canal_wall("env_canal_wall_tall", 2.40, mats)])


def build_levees(mats, out: Path) -> None:
    sand = mats["sand"]

    def h_straight(x, y):
        return height_from_dist(abs(y))

    def h_inner(x, y):
        # Concave L. Connect straights on -X and -Y. Bowl / inside toward +X+Y.
        d = min(_seg_dist(x, y, -HALF, 0.0, 0.0, 0.0),
                _seg_dist(x, y, 0.0, 0.0, 0.0, -HALF))
        return height_from_dist(d)

    def h_outer(x, y):
        # Convex L. Connect straights on +X and +Y.
        d = min(_seg_dist(x, y, HALF, 0.0, 0.0, 0.0),
                _seg_dist(x, y, 0.0, 0.0, 0.0, HALF))
        return height_from_dist(d)

    def h_slope(x, y):
        fade = max(0.0, min(1.0, 1.0 - (x + HALF) / CELL))
        return height_from_dist(abs(y)) * fade

    finish(out / "env_levee_straight.glb",
           [solid_heightfield("env_levee_straight", CELL, 10, h_straight, sand)])
    finish(out / "env_levee_inner_corner.glb",
           [solid_heightfield("env_levee_inner_corner", CELL, 12, h_inner, sand)])
    finish(out / "env_levee_outer_corner.glb",
           [solid_heightfield("env_levee_outer_corner", CELL, 12, h_outer, sand)])
    finish(out / "env_levee_slope.glb",
           [solid_heightfield("env_levee_slope", CELL, 10, h_slope, sand)])


def _door(name, x0, x1, y0, y1, z0, z1, mat_door, mat_iron, boarded=False):
    parts = [
        box(name + "_leaf", x0, x1, y0, y1, z0, z1, mat_door),
        box(name + "_knob", (x0 + x1) * 0.5 + 0.28, (x0 + x1) * 0.5 + 0.36,
            min(y0, y1) - 0.03, max(y0, y1) + 0.03, 0.95, 1.05, mat_iron),
    ]
    if boarded:
        for i, z in enumerate((0.45, 0.95, 1.50)):
            parts.append(box(f"{name}_brd{i}", x0 - 0.02, x1 + 0.02,
                             min(y0, y1) - 0.04, max(y0, y1) + 0.04,
                             z, z + 0.14, mat_iron if False else mat_door))
    return parts


def build_house(tag: str, cfg: dict, mats, out: Path) -> None:
    h = HOUSE_HALF
    wt = WALL_T
    brick = mats[cfg["brick"]]
    plinth = mats[cfg["plinth"]]
    roof_m = mats[cfg["roof"]]
    door_m = mats[cfg["door"]]
    z_plinth = 0.42
    z_eave = EAVE_Z
    z_ridge = RIDGE_Z

    parts = []
    # plinth — front is split so the door opening reaches the street
    door_w = 0.95
    door_x0 = cfg.get("door_x", -0.55)
    door_x1 = door_x0 + door_w
    parts.append(box("plinth_f_l", -h, door_x0, -h, -h + wt, 0.0, z_plinth, plinth))
    parts.append(box("plinth_f_r", door_x1, h, -h, -h + wt, 0.0, z_plinth, plinth))
    parts.append(box("plinth_b", -h, h, h - wt, h, 0.0, z_plinth, plinth))
    parts.append(box("plinth_l", -h, -h + wt, -h + wt, h - wt, 0.0, z_plinth, plinth))
    parts.append(box("plinth_r", h - wt, h, -h + wt, h - wt, 0.0, z_plinth, plinth))

    # front (-Y): door + windows
    win_w, win_h = 0.78, 1.15
    holes_f = [
        (door_x0, door_x1, 0.05, 2.15),  # door
    ]
    # ground window if not boarded-only
    gx0 = cfg.get("gwin_x", 0.55)
    holes_f.append((gx0, gx0 + win_w, 0.85, 0.85 + win_h))
    # two upper windows
    holes_f.append((-1.45, -1.45 + win_w, 3.55, 3.55 + win_h))
    holes_f.append((0.55, 0.55 + win_w, 3.55, 3.55 + win_h))
    if cfg.get("third_upper"):
        holes_f.append((-0.40, -0.40 + 0.70, 3.70, 3.70 + 0.90))

    parts += wall_y("front", -h, -h + wt, -h, h, z_plinth, z_eave, holes_f, brick, mats)
    parts += _door("door", door_x0 + 0.04, door_x1 - 0.04,
                   -h + 0.01, -h + 0.07, 0.05, 2.12, door_m, mats["iron"],
                   boarded=cfg.get("boarded", False))
    if cfg.get("boarded"):
        # boards over the ground window
        hx0, hx1 = gx0, gx0 + win_w
        parts.append(box("boards", hx0, hx1, -h - 0.03, -h + 0.08, 0.85, 0.85 + win_h, mats["wood"]))

    # back (+Y): two windows per floor
    holes_b = [
        (-1.30, -1.30 + win_w, 0.90, 0.90 + win_h),
        (0.45, 0.45 + win_w, 0.90, 0.90 + win_h),
        (-1.30, -1.30 + win_w, 3.55, 3.55 + win_h),
        (0.45, 0.45 + win_w, 3.55, 3.55 + win_h),
    ]
    parts += wall_y("back", h - wt, h, -h, h, z_plinth, z_eave, holes_b, brick, mats)

    # party walls (±X). End unit (d) gets a side window.
    holes_l = []
    holes_r = []
    if cfg.get("end_window"):
        holes_r = [( -0.40, 0.40, 3.50, 3.50 + 1.0)]
    parts += wall_x("left", -h, -h + wt, -h, h, z_plinth, z_eave, holes_l, brick, mats)
    parts += wall_x("right", h - wt, h, -h, h, z_plinth, z_eave, holes_r, brick, mats)

    # string course at storey line
    parts.append(box("string_f", -h - 0.02, h + 0.02, -h - 0.03, -h + wt + 0.02,
                     STOREY - 0.06, STOREY + 0.05, mats["coping"]))

    # roof
    over = 0.14
    parts.append(gable_roof("roof", -h - over, h + over, -h - over, h + over,
                            z_eave, z_ridge, roof_m))

    if cfg.get("chimney"):
        cx, cy = cfg.get("chimney_xy", (1.35, 0.85))
        parts.append(box("chimney", cx - 0.22, cx + 0.22, cy - 0.18, cy + 0.18,
                         z_eave - 0.2, z_ridge + 0.85, brick))
        parts.append(box("pot", cx - 0.10, cx + 0.10, cy - 0.08, cy + 0.08,
                         z_ridge + 0.85, z_ridge + 1.05, mats["brick_dark"]))

    if cfg.get("dormer"):
        # small street-facing dormer
        dx0, dx1 = -0.55, 0.55
        parts.append(box("dorm_box", dx0, dx1, -h - 0.08, -0.40,
                         z_eave + 0.15, z_eave + 1.35, brick))
        parts.append(box("dorm_gl", dx0 + 0.12, dx1 - 0.12, -h - 0.10, -h - 0.04,
                         z_eave + 0.35, z_eave + 1.15, mats["window"]))
        parts.append(box("dorm_cap", dx0 - 0.06, dx1 + 0.06, -h - 0.12, -0.32,
                         z_eave + 1.30, z_eave + 1.42, roof_m))

    # downpipe
    px = h - 0.08
    parts.append(cyl("downpipe", 0.04, 0.2, z_eave + 0.1, mats["rust"], segments=8,
                     x=px, y=-h + 0.06))

    # gutter along eaves, street side
    parts.append(box("gutter", -h, h, -h - 0.16, -h - 0.04, z_eave - 0.04, z_eave + 0.06,
                     mats["rust"]))

    finish(out / f"env_house_2storey_{tag}.glb",
           [combine(f"env_house_2storey_{tag}", parts)])


def build_houses(mats, out: Path) -> None:
    build_house("a", dict(
        brick="brick_ochre", plinth="brick_brown", roof="terracotta",
        door="door_cream", chimney=True, boarded=False, dormer=False,
        end_window=False, door_x=-0.70, gwin_x=0.55, chimney_xy=(1.30, 0.70),
    ), mats, out)
    build_house("b", dict(
        brick="brick_red", plinth="brick_dark", roof="terracotta",
        door="door_dark", chimney=True, boarded=False, dormer=True,
        end_window=False, door_x=0.10, gwin_x=-1.45, chimney_xy=(-1.25, 0.90),
    ), mats, out)
    build_house("c", dict(
        brick="plaster", plinth="brick_ochre", roof="terracotta_dk",
        door="door_cream", chimney=True, boarded=False, dormer=False,
        end_window=False, third_upper=True, door_x=-0.40, gwin_x=0.70,
        chimney_xy=(1.40, -0.55),
    ), mats, out)
    build_house("d", dict(
        brick="brick_brown", plinth="brick_dark", roof="terracotta",
        door="door_dark", chimney=True, boarded=True, dormer=False,
        end_window=True, door_x=-0.90, gwin_x=0.40, chimney_xy=(-1.35, -0.80),
    ), mats, out)


def build_interior_floors(mats, out: Path) -> None:
    inset = WALL_T + 0.02
    x0, x1 = -HOUSE_HALF + inset, HOUSE_HALF - inset
    y0, y1 = -HOUSE_HALF + inset, HOUSE_HALF - inset
    hole = (0.35, 1.35, 0.15, 1.50)  # x0,x1,y0,y1 stair well, inside the plate

    def floor_plate(name, z, with_hole: bool):
        t = 0.08
        parts = []
        if with_hole:
            hx0, hx1, hy0, hy1 = hole
            # four strips around the well
            parts += [
                box("n", x0, x1, hy1, y1, z, z + t, mats["interior"]),
                box("s", x0, x1, y0, hy0, z, z + t, mats["interior"]),
                box("w", x0, hx0, hy0, hy1, z, z + t, mats["interior"]),
                box("e", hx1, x1, hy0, hy1, z, z + t, mats["interior"]),
            ]
            # well lip
            parts.append(box("lip", hx0 - 0.04, hx1 + 0.04, hy0 - 0.04, hy1 + 0.04,
                             z + t, z + t + 0.04, mats["wood"]))
        else:
            parts.append(box("plate", x0, x1, y0, y1, z, z + t, mats["interior"]))
        return combine(name, parts)

    # Storey numbers baked in Z so they drop into a house at the same origin.
    finish(out / "env_floor_interior_1.glb",
           [floor_plate("env_floor_interior_1", 0.02, with_hole=True)])
    finish(out / "env_floor_interior_2.glb",
           [floor_plate("env_floor_interior_2", STOREY, with_hole=True)])


def build_roof_decks(mats, out: Path) -> None:
    h = HOUSE_HALF
    parapet = 0.42
    t = 0.14

    def deck(name, extra):
        parts = [
            box("slab", -h, h, -h, h, -t, 0.0, mats["bitumen"]),
            box("par_n", -h, h, h - 0.12, h, 0.0, parapet, mats["concrete"]),
            box("par_s", -h, h, -h, -h + 0.12, 0.0, parapet, mats["concrete"]),
            box("par_w", -h, -h + 0.12, -h + 0.12, h - 0.12, 0.0, parapet, mats["concrete"]),
            box("par_e", h - 0.12, h, -h + 0.12, h - 0.12, 0.0, parapet, mats["concrete"]),
        ]
        parts += extra
        return combine(name, parts)

    extra_a = [
        cyl("vent_a", 0.16, 0.0, 0.35, mats["iron"], segments=10, x=-1.1, y=1.0),
        cyl("vent_b", 0.12, 0.0, 0.28, mats["iron"], segments=10, x=1.2, y=-0.8),
        box("hatch_mark", -0.40, 0.40, -0.40, 0.40, 0.0, 0.03, mats["iron_dark"]),
    ]
    extra_b = [
        box("skylight", 0.40, 1.50, -0.30, 0.80, 0.0, 0.08, mats["window"]),
        box("sky_frame", 0.36, 1.54, -0.34, 0.84, 0.08, 0.12, mats["iron"]),
        cyl("pipe", 0.07, 0.0, 0.55, mats["rust"], segments=8, x=-1.4, y=-1.2),
        box("curb_strip", -1.8, 1.8, 1.55, 1.78, 0.0, 0.08, mats["concrete_wet"]),
    ]
    finish(out / "env_roof_deck_a.glb", [deck("env_roof_deck_a", extra_a)])
    finish(out / "env_roof_deck_b.glb", [deck("env_roof_deck_b", extra_b)])


def build_shanty(mats, out: Path) -> None:
    # Tarp: poles + sagging fly. Sits on a roof deck (Z=0).
    poles = []
    corners = [(-0.95, -0.70, 1.55), (0.95, -0.70, 1.45),
               (0.95, 0.75, 1.60), (-0.95, 0.75, 1.50)]
    for i, (x, y, z) in enumerate(corners):
        poles.append(cyl(f"pole{i}", 0.035, 0.0, z, mats["wood"], segments=8, x=x, y=y))
    # tarp as a 3x3 grid, centre sag
    bm = bmesh.new()
    grid_v = []
    for j in range(3):
        row = []
        v = j / 2.0
        for i in range(3):
            u = i / 2.0
            x = -0.98 + 1.96 * u
            y = -0.73 + 1.50 * v
            zc = (corners[0][2] * (1 - u) * (1 - v) + corners[1][2] * u * (1 - v)
                  + corners[2][2] * u * v + corners[3][2] * (1 - u) * v)
            sag = 0.22 * math.sin(u * math.pi) * math.sin(v * math.pi)
            row.append(bm.verts.new(Vector((x, y, zc - sag))))
        grid_v.append(row)
    for j in range(2):
        for i in range(2):
            bm.faces.new((grid_v[j][i], grid_v[j][i + 1],
                          grid_v[j + 1][i + 1], grid_v[j + 1][i]))
    tarp = _from_bm("tarp", bm, mats["tarp_blue"])
    strap = box("strap", -1.00, 1.00, -0.08, 0.08, 1.18, 1.26, mats["tarp_orange"])
    finish(out / "env_shanty_tarp.glb",
           [combine("env_shanty_tarp", poles + [tarp, strap])])

    # Pallet wall: stacked pallets, crate-class cover.
    parts = []
    for row in range(4):
        z0 = row * 0.38
        parts.append(box(f"plank_a{row}", -1.00, 1.00, -0.07, 0.07, z0, z0 + 0.06, mats["wood"]))
        parts.append(box(f"plank_b{row}", -1.00, 1.00, -0.07, 0.07, z0 + 0.28, z0 + 0.34, mats["wood_pale"]))
        for k, x in enumerate((-0.85, -0.28, 0.28, 0.85)):
            parts.append(box(f"st{row}{k}", x - 0.06, x + 0.06, -0.10, 0.10,
                             z0 + 0.06, z0 + 0.28, mats["wood_wet"]))
    finish(out / "env_shanty_pallet_wall.glb",
           [combine("env_shanty_pallet_wall", parts)])

    # Water tank on a stand. Metal, rifle-stop if tagged metal.
    parts = [
        cyl("tank", 0.42, 0.55, 1.70, mats["iron_green"], segments=14),
        cyl("rim", 0.44, 1.64, 1.72, mats["iron"], segments=14),
        cyl("lid", 0.38, 1.70, 1.78, mats["iron_dark"], segments=14),
        box("strap", -0.45, 0.45, -0.05, 0.05, 1.05, 1.14, mats["rust"]),
    ]
    for i, (x, y) in enumerate(((-0.28, -0.28), (0.28, -0.28), (0.28, 0.28), (-0.28, 0.28))):
        parts.append(box(f"leg{i}", x - 0.04, x + 0.04, y - 0.04, y + 0.04, 0.0, 0.58, mats["iron"]))
    parts.append(box("base", -0.38, 0.38, -0.38, 0.38, 0.0, 0.08, mats["wood"]))
    finish(out / "env_shanty_water_tank.glb",
           [combine("env_shanty_water_tank", parts)])

    # Plot box: open planter, crate-class.
    t = 0.08
    x0, x1, y0, y1 = -0.70, 0.70, -0.45, 0.45
    parts = [
        box("bottom", x0, x1, y0, y1, 0.0, 0.08, mats["wood"]),
        box("n", x0, x1, y1 - t, y1, 0.08, 0.42, mats["wood"]),
        box("s", x0, x1, y0, y0 + t, 0.08, 0.42, mats["wood"]),
        box("w", x0, x0 + t, y0 + t, y1 - t, 0.08, 0.42, mats["wood_wet"]),
        box("e", x1 - t, x1, y0 + t, y1 - t, 0.08, 0.42, mats["wood_wet"]),
        box("soil", x0 + t, x1 - t, y0 + t, y1 - t, 0.08, 0.28, mats["soil"]),
    ]
    finish(out / "env_shanty_plot_box.glb",
           [combine("env_shanty_plot_box", parts)])


def build_climb(mats, out: Path) -> None:
    # Stair: one storey, 2 m run along +Y, 1.4 m wide, origin at cell centre.
    steps_n = 12
    run, rise, width = 2.00, STOREY, 1.40
    sh, sd = rise / steps_n, run / steps_n
    y0 = -run * 0.5
    x0, x1 = -width * 0.5, width * 0.5
    parts = []
    for i in range(steps_n):
        z1 = (i + 1) * sh
        ys = y0 + i * sd
        parts.append(box(f"st{i}", x0, x1, ys, ys + sd + 0.01, 0.0, z1, mats["concrete"]))
        parts.append(box(f"nos{i}", x0, x1, ys, ys + 0.04, z1, z1 + 0.03, mats["coping"]))
    # thin handrails — not cover
    for x in (x0 - 0.04, x1 + 0.04):
        parts.append(box("rail_p", x - 0.025, x + 0.025, y0, y0 + run,
                         0.90, 0.96, mats["iron"]))
        for i in range(0, steps_n, 2):
            z = 0.15 + i * sh
            yy = y0 + i * sd
            parts.append(box(f"bal{i}", x - 0.02, x + 0.02, yy - 0.02, yy + 0.02,
                             z, z + 0.90, mats["iron"]))
    finish(out / "env_stair.glb", [combine("env_stair", parts)])

    # Ladder: one storey, origin at bottom centre. Thin — not cover.
    h = STOREY + 0.25
    parts = [
        cyl("st_l", 0.028, 0.0, h, mats["iron"], segments=8, x=-0.20, y=0.0),
        cyl("st_r", 0.028, 0.0, h, mats["iron"], segments=8, x=0.20, y=0.0),
    ]
    n_rungs = 11
    for i in range(n_rungs):
        z = 0.28 + i * (h - 0.40) / (n_rungs - 1)
        parts.append(box(f"rung{i}", -0.20, 0.20, -0.018, 0.018, z - 0.018, z + 0.018, mats["iron"]))
    # standoff brackets
    for z in (0.4, h - 0.3):
        parts.append(box(f"br{z}", -0.22, 0.22, 0.02, 0.12, z, z + 0.05, mats["iron_dark"]))
    finish(out / "env_ladder.glb", [combine("env_ladder", parts)])

    # Hatch: sits on a roof deck. Closed lid, handle. Walkable.
    parts = [
        box("frame", -0.50, 0.50, -0.50, 0.50, 0.0, 0.08, mats["iron"]),
        box("well", -0.38, 0.38, -0.38, 0.38, -0.04, 0.02, mats["iron_dark"]),
        box("lid", -0.42, 0.42, -0.42, 0.42, 0.08, 0.12, mats["iron_green"]),
        box("hinge", -0.42, 0.42, 0.36, 0.46, 0.10, 0.16, mats["iron_dark"]),
        box("handle", -0.12, 0.12, -0.28, -0.20, 0.12, 0.20, mats["rust"]),
    ]
    finish(out / "env_hatch.glb", [combine("env_hatch", parts)])


def build_pump_house(mats, out: Path) -> None:
    h = 2.0
    parts = [
        box("plinth", -h, h, -h, h, 0.0, 0.30, mats["concrete"]),
        box("body", -1.70, 1.70, -1.70, 1.70, 0.30, 3.60, mats["brick_brown"]),
        box("string", -1.74, 1.74, -1.74, 1.74, 3.50, 3.64, mats["coping"]),
        # low pitch roof
        box("roof", -1.90, 1.90, -1.90, 1.90, 3.60, 3.85, mats["bitumen"]),
        box("ridge_cap", -0.15, 0.15, -1.90, 1.90, 3.82, 4.05, mats["iron"]),
        # door
        box("door", -0.45, 0.45, -1.74, -1.62, 0.30, 2.40, mats["iron_dark"]),
        box("door_win", -0.20, 0.20, -1.76, -1.70, 1.70, 2.20, mats["window"]),
        # side windows
        box("w1", -1.74, -1.62, -0.40, 0.40, 1.40, 2.40, mats["window"]),
        box("w2", 1.62, 1.74, -0.40, 0.40, 1.40, 2.40, mats["window"]),
        # intake pipes
        cyl("pipe_a", 0.28, 0.40, 1.60, mats["rust"], segments=12, x=1.85, y=0.80),
        cyl("pipe_b", 0.22, 0.40, 1.35, mats["iron"], segments=12, x=1.85, y=1.35),
        box("flange", 1.55, 2.05, 0.55, 1.05, 1.50, 1.70, mats["iron_dark"]),
        # motor house bump
        box("motor", -0.70, 0.70, 1.20, 1.95, 0.30, 1.80, mats["iron"]),
        box("vent", -0.30, 0.30, 1.90, 2.05, 1.20, 1.60, mats["iron_dark"]),
        cyl("stack", 0.12, 3.85, 5.10, mats["rust"], segments=10, x=-1.10, y=1.10),
        box("plate", -0.55, 0.55, -1.80, -1.74, 2.55, 3.05, mats["iron"]),  # blank plate, no text
    ]
    shell = combine("pump_house", parts)

    # Damaged dressing — separate object, hide in Godot when the pump is kept.
    dress = [
        box("lean_panel", 1.55, 1.62, -1.10, 0.20, 0.50, 2.20, mats["rust"]),
        cyl("bent", 0.10, 1.40, 2.40, mats["rust"], segments=8, x=2.05, y=0.40),
        box("rubble", 1.40, 2.10, -0.30, 0.50, 0.30, 0.55, mats["brick_dark"]),
        box("tape", -0.50, 0.50, -1.82, -1.70, 1.10, 1.22, mats["tarp_orange"]),
    ]
    dressing = combine("dressing_damaged", dress)

    root = empty("env_pump_house")
    parent(shell, root)
    parent(dressing, root)
    finish(out / "env_pump_house.glb", [root])


def build_sluice(mats, out: Path) -> None:
    """Hero sluice. `sluice_gate` is a separate object — translate local +Z
    (Godot +Y after export) to open. Closed travel 0; full open ~2.2 m.
    """
    root = empty("env_sluice_gauge")

    frame_parts = [
        # channel floor
        box("floor", -1.0, 1.0, -2.0, 2.0, -0.20, 0.08, mats["concrete_wet"]),
        # abutments
        box("ab_l", -2.0, -0.85, -2.0, 2.0, 0.0, 2.60, mats["stone"]),
        box("ab_r", 0.85, 2.0, -2.0, 2.0, 0.0, 2.60, mats["stone"]),
        box("cap_l", -2.05, -0.80, -2.05, 2.05, 2.50, 2.72, mats["coping"]),
        box("cap_r", 0.80, 2.05, -2.05, 2.05, 2.50, 2.72, mats["coping"]),
        # gate slots
        box("slot_l", -0.95, -0.80, -0.12, 0.12, 0.08, 2.50, mats["iron"]),
        box("slot_r", 0.80, 0.95, -0.12, 0.12, 0.08, 2.50, mats["iron"]),
        box("lintel", -1.00, 1.00, -0.18, 0.18, 2.40, 2.70, mats["iron_dark"]),
        # walkway over
        box("walk", -2.0, 2.0, -0.45, 0.45, 2.70, 2.82, mats["concrete"]),
        box("rail_a", -2.0, 2.0, -0.48, -0.42, 2.82, 3.55, mats["iron"]),
        box("rail_b", -2.0, 2.0, 0.42, 0.48, 2.82, 3.55, mats["iron"]),
        # gauge cabinet — a box, not a meter
        box("cabinet", 1.35, 1.85, -0.70, -0.25, 1.10, 2.10, mats["iron_green"]),
        box("cab_door", 1.33, 1.38, -0.62, -0.33, 1.20, 2.00, mats["iron_dark"]),
        # winch drum
        cyl("drum", 0.16, 2.85, 3.15, mats["iron"], segments=10, x=0.0, y=0.0),
    ]
    # rotate drum? it's a vertical cyl; make it a horizontal box-ish cylinder along X
    delete_objects([frame_parts[-1]])
    frame_parts[-1] = cyl("post", 0.06, 2.82, 3.55, mats["iron"], segments=8, x=0.0, y=0.0)
    frame_parts.append(box("drum", -0.35, 0.35, -0.12, 0.12, 3.20, 3.48, mats["rust"]))

    frame = combine("sluice_frame", frame_parts)

    # Gate as its own object. Local origin at the closed-position centre so a
    # +Z (Blender) / +Y (Godot) translate lifts it in the slots.
    gate_parts = [
        box("leaf", -0.78, 0.78, -0.05, 0.05, 0.10, 2.35, mats["iron"]),
        box("rib_v1", -0.78, -0.68, -0.07, 0.07, 0.10, 2.35, mats["iron_dark"]),
        box("rib_v2", 0.68, 0.78, -0.07, 0.07, 0.10, 2.35, mats["iron_dark"]),
        box("rib_h1", -0.78, 0.78, -0.07, 0.07, 0.70, 0.82, mats["rust"]),
        box("rib_h2", -0.78, 0.78, -0.07, 0.07, 1.50, 1.62, mats["rust"]),
        box("rib_h3", -0.78, 0.78, -0.07, 0.07, 2.20, 2.32, mats["iron_dark"]),
    ]
    gate = combine("sluice_gate", gate_parts)
    # Re-origin the gate to its geometric centre without moving world verts:
    # keep world placement; Godot animates this node.
    parent(frame, root)
    parent(gate, root)
    finish(out / "env_sluice_gauge.glb", [root])


def cyl_along(name: str, radius: float, a0: float, a1: float, axis: str, mat=None,
              segments: int = 12, x: float = 0.0, y: float = 0.0, z: float = 0.0):
    """Cylinder lying along Blender X or Y from a0 to a1. (x, y, z) place it on the other axes."""
    obj = cyl(name, radius, -(a1 - a0) * 0.5, (a1 - a0) * 0.5, mat, segments=segments)
    if axis == "y":
        obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        obj.location = (x, (a0 + a1) * 0.5, z)
    else:
        obj.rotation_euler = (0.0, math.radians(90.0), 0.0)
        obj.location = ((a0 + a1) * 0.5, y, z)
    return obj


# Extract dock: a floating dock on guide piles, 2 x 6 m, origin at footprint centre, long axis Blender Y.
# Two nodes under one root (MANIFEST): `pier_deck` rides the water and `pier_piles` stay put. The
# code reads the deck height from PresentationCoords.DOCK_DECK_TOP_M; a test measures this mesh
# against it, so change them together.
DOCK_DECK_TOP = 0.60
PILE_X = 1.14
PILE_YS = (-2.4, 0.0, 2.4)


def build_pier(mats, out: Path) -> None:
    top = DOCK_DECK_TOP
    deck = []

    # Boards: nine planks along the length, butt joints staggered, alternating weathering.
    joints = (-1.5, 0.4, -0.6, 1.1, -1.1, 0.9, -0.2, 1.4, -0.9)
    pitch = 2.0 / 9.0
    plank_w = pitch - 0.022
    for i, jy in enumerate(joints):
        x0 = -1.0 + i * pitch
        mat = mats["wood"] if i % 2 == 0 else mats["wood_pale"]
        deck.append(box(f"plank{i}a", x0, x0 + plank_w, -3.0, jy - 0.011, top - 0.08, top, mat))
        deck.append(box(f"plank{i}b", x0, x0 + plank_w, jy + 0.011, 3.0, top - 0.08, top, mat))

    # Frame under the boards: two stringers and cross-bearers.
    for x in (-0.85, 0.85):
        deck.append(box("stringer", x - 0.07, x + 0.07, -3.0, 3.0, top - 0.24, top - 0.08, mats["wood_wet"]))
    for j in range(7):
        y = -2.9 + j * (5.8 / 6.0)
        deck.append(box(f"bearer{j}", -1.0, 1.0, y - 0.06, y + 0.06, top - 0.20, top - 0.08, mats["wood_wet"]))

    # Floats: oil drums lying under the stringers. Their tops meet the frame; their bottoms clear the
    # ground, so a dry dock rests on them instead of sinking into the slab.
    drum_r = 0.26
    drum_z = top - 0.32
    for si, x in enumerate((-0.62, 0.62)):
        for di, (y0, y1) in enumerate(((-2.9, -1.5), (-1.4, 0.0), (0.1, 1.5), (1.6, 2.9))):
            mat = (mats["iron_green"], mats["rust"], mats["iron"], mats["rust"])[(si + di) % 4]
            deck.append(cyl_along(f"drum{si}{di}", drum_r, y0, y1, "y", mat, segments=12, x=x, z=drum_z))
            for k in (0.25, 0.75):
                ry = y0 + (y1 - y0) * k
                deck.append(cyl_along(f"rib{si}{di}{k}", drum_r + 0.012, ry - 0.03, ry + 0.03, "y",
                                      mats["iron_dark"], segments=12, x=x, z=drum_z))

    # Fender kerb along both edges, and tyre fenders hung outside it.
    for sx in (-1, 1):
        deck.append(box("kerb", min(sx * 0.90, sx * 1.0), max(sx * 0.90, sx * 1.0), -3.0, 3.0, top, top + 0.09, mats["wood_pale"]))
        for ty in (-1.9, 0.0, 1.9):
            deck.append(cyl_along(f"tyre{sx}{ty}", 0.20, sx * 1.0, sx * 1.14, "x", mats["bitumen"],
                                  segments=12, y=ty, z=top - 0.10))

    # Pile guides: an iron ring around each pile, on an arm from the deck edge. The pile passes
    # through it, so the deck slides up and down its piles.
    for sx in (-1, 1):
        for py in PILE_YS:
            px = sx * PILE_X
            lo, hi = 0.16, 0.20  # inner half-width just clears the 0.12 m pile, outer half-width
            z0, z1 = top - 0.14, top + 0.22
            for name, ax0, ax1, ay0, ay1 in (
                ("gl", px - hi, px - lo, py - hi, py + hi),
                ("gr", px + lo, px + hi, py - hi, py + hi),
                ("gf", px - lo, px + lo, py - hi, py - lo),
                ("gb", px - lo, px + lo, py + lo, py + hi),
            ):
                deck.append(box(f"{name}{sx}{py}", ax0, ax1, ay0, ay1, z0, z1, mats["iron_dark"]))
            arm_x0, arm_x1 = (sx * 1.0, px - sx * hi)
            deck.append(box(f"arm{sx}{py}", min(arm_x0, arm_x1), max(arm_x0, arm_x1), py - 0.05, py + 0.05,
                            top - 0.10, top + 0.02, mats["iron_dark"]))

    # Mooring: bollards and cleats at the water end (+Y), where a boat comes alongside.
    for x in (-0.55, 0.55):
        deck.append(cyl(f"bollard{x}", 0.08, top, top + 0.34, mats["iron"], segments=8, x=x, y=2.55))
        deck.append(cyl(f"bollard_cap{x}", 0.115, top + 0.30, top + 0.36, mats["iron"], segments=8, x=x, y=2.55))
    for x in (-0.70, 0.70):
        for y in (-1.2, 1.2):
            deck.append(box(f"cleat{x}{y}", x - 0.09, x + 0.09, y - 0.03, y + 0.03, top, top + 0.06, mats["iron_dark"]))

    # Open rail on the water end: two thin posts and two thin bars. Not cover, and it must not read
    # as cover, so nothing solid stands between them.
    for x in (-0.94, 0.94):
        deck.append(cyl(f"rail_post{x}", 0.03, top, top + 0.67, mats["iron"], segments=6, x=x, y=2.94))
    for h in (0.34, 0.66):
        deck.append(cyl_along(f"rail_bar{h}", 0.022, -0.94, 0.94, "x", mats["iron"], segments=6, y=2.94, z=top + h))

    # Piles: driven into the bed, standing over even a Flooded deck. Thin, so they do not read as cover.
    piles = []
    for sx in (-1, 1):
        for py in PILE_YS:
            px = sx * PILE_X
            piles.append(cyl(f"pile{sx}{py}", 0.12, -1.40, 3.50, mats["wood_wet"], segments=10, x=px, y=py))
            piles.append(cone(f"pile_cap{sx}{py}", 0.12, 0.07, 3.50, 3.62, mats["wood"], segments=10, x=px, y=py))
            for bz in (-0.55, 1.05):
                piles.append(cyl(f"pile_band{sx}{py}{bz}", 0.135, bz, bz + 0.07, mats["iron"], segments=10, x=px, y=py))

    root = empty("env_pier")
    deck_obj = combine("pier_deck", deck)
    piles_obj = combine("pier_piles", piles)
    parent(deck_obj, root)
    parent(piles_obj, root)
    finish(out / "env_pier.glb", [root])


def build_furniture(mats, out: Path) -> None:
    # Lamp — thin pole, not cover.
    parts = [
        cyl("base", 0.16, 0.0, 0.12, mats["iron_dark"], segments=10),
        cyl("pole", 0.045, 0.12, 3.40, mats["iron"], segments=8),
        box("arm", -0.04, 0.55, -0.04, 0.04, 3.28, 3.38, mats["iron"]),
        cyl("head", 0.12, 3.10, 3.30, mats["iron_dark"], segments=10, x=0.50, y=0.0),
        cyl("lens", 0.09, 3.08, 3.12, mats["glass_glint"], segments=10, x=0.50, y=0.0),
    ]
    finish(out / "env_furn_lamp.glb", [combine("env_furn_lamp", parts)])

    # Bench — low wood, not cover (seat 0.42 m).
    parts = [
        box("seat", -0.75, 0.75, -0.22, 0.22, 0.40, 0.48, mats["wood"]),
        box("back", -0.75, 0.75, 0.16, 0.24, 0.48, 0.92, mats["wood_pale"]),
    ]
    for x in (-0.62, 0.62):
        parts.append(box("leg", x - 0.04, x + 0.04, -0.18, 0.18, 0.0, 0.40, mats["iron"]))
    finish(out / "env_furn_bench.glb", [combine("env_furn_bench", parts)])

    # Bollard — too thin/short for cover.
    parts = [
        cyl("body", 0.11, 0.0, 0.92, mats["iron"], segments=12),
        cyl("cap", 0.13, 0.88, 0.98, mats["iron_dark"], segments=12),
        cyl("ring", 0.125, 0.62, 0.70, mats["rust"], segments=12),
    ]
    finish(out / "env_furn_bollard.glb", [combine("env_furn_bollard", parts)])

    # Rail — 2 m run, 1.05 m high, Ø ~4 cm. MUST read as thin. Not cover.
    parts = []
    for x in (-0.90, 0.0, 0.90):
        parts.append(cyl(f"post{x}", 0.025, 0.0, 1.05, mats["iron"], segments=8, x=x, y=0.0))
    parts.append(box("top", -1.00, 1.00, -0.022, 0.022, 1.00, 1.05, mats["iron"]))
    parts.append(box("mid", -1.00, 1.00, -0.018, 0.018, 0.52, 0.56, mats["iron"]))
    finish(out / "env_furn_rail.glb", [combine("env_furn_rail", parts)])


def build_ridge(mats, hero: Path) -> None:
    """Low sandy moraine / dune. Horizon object. No nameplate, no compass.
    Tiny glass glint is a separate mesh (Citadel hint, not a marker).
    """
    root = empty("env_ridge_farfield")

    def hfn(x, y):
        # ~80 x 32 m, peak ~9 m. Multiple lobes, never alpine.
        h = 0.0
        h += 8.4 * math.exp(-((x / 34.0) ** 2) * 1.15 - ((y / 11.0) ** 2) * 2.4)
        h += 3.6 * math.exp(-((x - 18.0) / 12.0) ** 2 - ((y - 3.0) / 7.0) ** 2)
        h += 3.1 * math.exp(-((x + 22.0) / 14.0) ** 2 - ((y + 2.0) / 8.0) ** 2)
        h += 1.6 * math.exp(-((x - 4.0) / 8.0) ** 2 - ((y + 6.0) / 5.0) ** 2)
        h += 0.35 * math.sin(x * 0.18) * math.cos(y * 0.22)
        # flatten the skirt
        edge = max(abs(x) / 40.0, abs(y) / 16.0)
        if edge > 0.85:
            h *= max(0.0, 1.0 - (edge - 0.85) / 0.15)
        return max(0.0, h)

    terrain = solid_heightfield(
        "ridge_terrain", 80.0, 28, hfn, mats["ridge_sand"], z_min=0.0, smooth=True,
    )

    # tiny glass observatory on the back shoulder — a glint, not a landmark chrome
    glint_parts = [
        box("plinth", -1.4, 1.4, -1.0, 1.0, 0.0, 0.35, mats["concrete"]),
        box("glass", -1.1, 1.1, -0.75, 0.75, 0.35, 1.85, mats["glass_glint"]),
        box("frame_v1", -1.15, -1.05, -0.80, 0.80, 0.35, 1.85, mats["iron"]),
        box("frame_v2", 1.05, 1.15, -0.80, 0.80, 0.35, 1.85, mats["iron"]),
        box("roof", -1.3, 1.3, -0.95, 0.95, 1.85, 2.05, mats["iron_dark"]),
        cyl("mast", 0.04, 2.05, 3.4, mats["iron"], segments=8, x=0.4, y=0.0),
    ]
    glint = combine("ridge_glint", glint_parts)
    # sit it on the peak-ish back (not dead-centre of the bowl when placed)
    glint.location = (6.5, 1.8, 7.2)

    parent(terrain, root)
    parent(glint, root)
    finish(hero / "env_ridge_farfield.glb", [root])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("Polder P0 kit — cell", CELL, "m")
    print("  kit ", KIT_DIR)
    print("  hero", HERO_DIR)
    KIT_DIR.mkdir(parents=True, exist_ok=True)
    HERO_DIR.mkdir(parents=True, exist_ok=True)

    _reset_scene()
    mats = build_materials()

    build_street_slabs(mats, KIT_DIR)
    build_curb(mats, KIT_DIR)
    build_canal_walls(mats, KIT_DIR)
    build_levees(mats, KIT_DIR)
    build_houses(mats, KIT_DIR)
    build_interior_floors(mats, KIT_DIR)
    build_roof_decks(mats, KIT_DIR)
    build_shanty(mats, KIT_DIR)
    build_climb(mats, KIT_DIR)
    build_pump_house(mats, KIT_DIR)
    build_sluice(mats, KIT_DIR)
    build_pier(mats, KIT_DIR)
    build_furniture(mats, KIT_DIR)
    build_ridge(mats, HERO_DIR)
    print("done")


if __name__ == "__main__":
    main()
    # Blender --python keeps running unless we quit.
    if "--" in sys.argv or bpy.app.background:
        pass
