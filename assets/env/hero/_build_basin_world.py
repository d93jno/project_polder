#!/usr/bin/env python3
"""Build the continuous basin terrain used by the table-scale world view.

Run from the repository root:

    /snap/bin/blender --background --python assets/env/hero/_build_basin_world.py

The terrain is 30.72 x 30.72 km: 15,360 x 15,360 tactical cells at the
project's 2 m cell scale. It samples the macro terrain every 64 m (32 cells),
because this is the same-basin table LOD rather than a 225-million-vertex
tactical floor. Water is intentionally absent; each authored bowl supplies its
own step-driven water plane.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


CELL_M = 2.0
WORLD_M = 30_720.0
HALF_WORLD_M = WORLD_M * 0.5
TACTICAL_CELLS = int(WORLD_M / CELL_M)
TERRAIN_SAMPLE_M = 64.0
GRID = int(WORLD_M / TERRAIN_SAMPLE_M)
LAYOUT_SCALE = 40.0

SCRIPT_PATH = Path(__file__).resolve()
OUT_PATH = SCRIPT_PATH.with_name("env_basin_world_map.glb")


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.curves,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)

    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def material(name: str, color: tuple[float, float, float], roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def gaussian(x: float, z: float, cx: float, cz: float, rx: float, rz: float) -> float:
    dx = (x - cx) / rx
    dz = (z - cz) / rz
    return math.exp(-(dx * dx + dz * dz) * 2.0)


def terrain_height(x: float, z: float) -> float:
    """Low Dutch polder: broad bowls, one honest height, no alpine terrain."""
    x /= LAYOUT_SCALE
    z /= LAYOUT_SCALE
    half_layout = HALF_WORLD_M / LAYOUT_SCALE
    edge = max(abs(x), abs(z)) / half_layout
    shoulder = 1.1 * max(0.0, (edge - 0.68) / 0.32) ** 2
    ridge = 11.5 * gaussian(x, z, -92.0, 54.0, 118.0, 82.0)
    terrace = 2.8 * gaussian(x, z, -162.0, 122.0, 212.0, 158.0)
    floor_bowl = -3.4 * gaussian(x, z, 76.0, -34.0, 245.0, 208.0)
    sump = -5.1 * gaussian(x, z, 168.0, -132.0, 116.0, 94.0)
    return (shoulder + ridge + terrace + floor_bowl + sump) * 8.0


def is_canal(x: float, z: float) -> bool:
    """A sparse, orthogonal drainage network; geometry stays continuous."""
    x /= LAYOUT_SCALE
    z /= LAYOUT_SCALE
    north_south = abs(x - 34.0) < 9.0 and -304.0 < z < 300.0
    east_west = abs(z + 118.0) < 8.0 and -304.0 < x < 306.0
    terrace_cut = abs(x + 178.0) < 6.0 and 34.0 < z < 286.0
    return north_south or east_west or terrace_cut


def build_terrain(
    soil: bpy.types.Material,
    wet_silt: bpy.types.Material,
    ridge_sand: bpy.types.Material,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    for z_index in range(GRID + 1):
        z = -HALF_WORLD_M + z_index * TERRAIN_SAMPLE_M
        for x_index in range(GRID + 1):
            x = -HALF_WORLD_M + x_index * TERRAIN_SAMPLE_M
            height = terrain_height(x, z)
            if is_canal(x, z):
                height -= 1.55
            vertices.append((x, height, z))

    faces: list[tuple[int, int, int]] = []
    face_materials: list[int] = []
    row = GRID + 1
    for z_index in range(GRID):
        for x_index in range(GRID):
            a = z_index * row + x_index
            b = a + 1
            c = a + row + 1
            d = a + row
            faces.extend([(a, b, c), (a, c, d)])
            x = -HALF_WORLD_M + (x_index + 0.5) * TERRAIN_SAMPLE_M
            z = -HALF_WORLD_M + (z_index + 0.5) * TERRAIN_SAMPLE_M
            material_index = 1 if is_canal(x, z) else 2 if terrain_height(x, z) > 6.0 else 0
            face_materials.extend([material_index, material_index])

    mesh = bpy.data.meshes.new("basin_terrain_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(soil)
    mesh.materials.append(wet_silt)
    mesh.materials.append(ridge_sand)
    for polygon, material_index in zip(mesh.polygons, face_materials):
        polygon.material_index = material_index
        polygon.use_smooth = True
    mesh.update()

    terrain = bpy.data.objects.new("basin_terrain", mesh)
    bpy.context.scene.collection.objects.link(terrain)
    return terrain


def strip_mesh(
    name: str,
    points: list[tuple[float, float]],
    height: float,
    top_width: float,
    base_width: float,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    """Create a faceted earthen dike that follows a polyline on the terrain."""
    vertices: list[tuple[float, float, float]] = []
    for index, (x, z) in enumerate(points):
        if index == 0:
            nx, nz = points[1][0] - x, points[1][1] - z
        elif index == len(points) - 1:
            nx, nz = x - points[index - 1][0], z - points[index - 1][1]
        else:
            nx = points[index + 1][0] - points[index - 1][0]
            nz = points[index + 1][1] - points[index - 1][1]
        length = math.hypot(nx, nz)
        nx, nz = -nz / length, nx / length
        base_y = terrain_height(x, z)
        for width, y in ((base_width, base_y), (top_width, base_y + height)):
            vertices.append((x + nx * width * 0.5, y, z + nz * width * 0.5))
            vertices.append((x - nx * width * 0.5, y, z - nz * width * 0.5))

    faces: list[tuple[int, int, int, int]] = []
    for index in range(len(points) - 1):
        current = index * 4
        following = (index + 1) * 4
        faces.extend(
            [
                (current, following, following + 2, current + 2),
                (current + 1, current + 3, following + 3, following + 1),
                (current + 2, following + 2, following + 3, current + 3),
            ]
        )

    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    mesh.update()

    dike = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(dike)
    return dike


def build_levees(mat: bpy.types.Material) -> bpy.types.Object:
    """Ring dikes and cross-dikes divide the terrain into legible water bowls."""
    root = bpy.data.objects.new("basin_levees", None)
    bpy.context.scene.collection.objects.link(root)

    routes = [
        [(-334.0, -330.0), (332.0, -330.0), (332.0, 330.0), (-334.0, 330.0), (-334.0, -330.0)],
        [(-286.0, -40.0), (-160.0, -40.0), (-96.0, 28.0), (-96.0, 242.0)],
        [(-280.0, 142.0), (-92.0, 142.0), (10.0, 188.0)],
        [(-218.0, -214.0), (26.0, -214.0), (118.0, -150.0), (286.0, -150.0)],
        [(34.0, -286.0), (34.0, -118.0), (34.0, 110.0), (34.0, 284.0)],
        [(142.0, -278.0), (142.0, -150.0), (222.0, -70.0), (286.0, -70.0)],
        [(-48.0, 74.0), (102.0, 74.0), (202.0, 18.0), (288.0, 18.0)],
    ]
    for index, route in enumerate(routes):
        scaled_route = [(x * LAYOUT_SCALE, z * LAYOUT_SCALE) for x, z in route]
        dike = strip_mesh(
            "levee_%02d" % index,
            scaled_route,
            height=10.0 if index == 0 else 7.0,
            top_width=8.0,
            base_width=40.0,
            mat=mat,
        )
        dike.parent = root
    return root


def add_ridge_marker(mat: bpy.types.Material) -> bpy.types.Object:
    """A small, abstract dome footprint anchors the central ridge at table scale."""
    x = -92.0 * LAYOUT_SCALE
    z = 54.0 * LAYOUT_SCALE
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=60.0,
        depth=20.0,
        location=(x, terrain_height(x, z) + 10.0, z),
    )
    dome = bpy.context.object
    dome.name = "citadel_ridge_footprint"
    dome.data.materials.append(mat)
    return dome


def export(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        for child in obj.children_recursive:
            child.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=False,
        export_extras=False,
        export_morph=False,
    )
    print("wrote %s (%d bytes)" % (OUT_PATH, OUT_PATH.stat().st_size))


def main() -> None:
    reset_scene()
    soil = material("mat_basin_soil", (0.17, 0.18, 0.15), 0.92)
    wet_silt = material("mat_basin_wet_silt", (0.09, 0.13, 0.14), 0.86)
    ridge_sand = material("mat_basin_ridge_sand", (0.46, 0.39, 0.25), 0.95)
    levee = material("mat_basin_levee", (0.31, 0.29, 0.21), 0.96)
    dome = material("mat_basin_citadel", (0.30, 0.34, 0.34), 0.50)

    terrain = build_terrain(soil, wet_silt, ridge_sand)
    dikes = build_levees(levee)
    citadel = add_ridge_marker(dome)
    export([terrain, dikes, citadel])


if __name__ == "__main__":
    main()
