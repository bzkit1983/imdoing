#!/usr/bin/env python3
"""Preview-only Blender renders of player_alt3 as voxel cubes.

Does not write into godot/game art. Run via:
  blender -b -P tools/preview_blender_player_alt3.py -- --out /opt/cursor/artifacts

Or from repo root (invokes blender):
  python3 tools/preview_blender_player_alt3.py
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VOX_PATH = ROOT / "godot" / "game" / "art" / "src" / "player_alt3.vox"
DEFAULT_OUT = Path("/opt/cursor/artifacts")
BLENDER_BIN = Path("/usr/local/bin/blender")


def _chunk(data: bytes, pos: int):
    tag = data[pos : pos + 4]
    content_size, children = struct.unpack_from("<ii", data, pos + 4)
    content = data[pos + 12 : pos + 12 + content_size]
    return tag, content, children


def read_vox(path: Path):
    data = path.read_bytes()
    pos = 20
    end = pos + _chunk(data, 8)[2]
    size = (1, 1, 1)
    cells: dict[tuple[int, int, int], int] = {}
    palette = [(0, 0, 0)] * 256
    while pos < end:
        tag, content, child = _chunk(data, pos)
        if tag == b"SIZE":
            size = struct.unpack_from("<iii", content)
        elif tag == b"XYZI":
            count = struct.unpack_from("<i", content)[0]
            for i in range(count):
                x, y, z, index = struct.unpack_from("<BBBB", content, 4 + i * 4)
                cells[(x, y, z)] = index
        elif tag == b"RGBA":
            palette = [struct.unpack_from("<BBB", content, i * 4) for i in range(256)]
        pos += 12 + len(content) + child
    return size, cells, palette


def run_via_blender(out: Path) -> int:
    blender = BLENDER_BIN if BLENDER_BIN.is_file() else Path("blender")
    cmd = [
        str(blender),
        "-b",
        "-P",
        str(Path(__file__).resolve()),
        "--",
        "--out",
        str(out),
        "--vox",
        str(VOX_PATH),
    ]
    print("exec", " ".join(cmd))
    return subprocess.call(cmd)


def build_and_render(vox: Path, out: Path) -> None:
    import bpy
    import mathutils

    size, cells, palette = read_vox(vox)
    sx, sy, sz = size
    print(f"vox size={size} voxels={len(cells)}")

    # Fresh scene.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    # World soft grey for Workbench solid.
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.82, 0.84, 0.88, 1.0)
    bg.inputs[1].default_value = 1.0

    # MagicaVoxel: X right, Y depth (face +Y), Z up. Blender: Z up, -Y toward camera for front.
    # Place voxel centers so feet sit on z=0 and model is centered on X/Y.
    cx = (sx - 1) * 0.5
    cy = (sy - 1) * 0.5

    # Build one mesh with per-voxel cubes (only exposed faces would be nicer; full cubes OK for QA).
    # Use material slots keyed by palette index for Object/Material color.
    mat_cache: dict[int, bpy.types.Material] = {}

    def mat_for(index: int):
        if index in mat_cache:
            return mat_cache[index]
        r, g, b = palette[index - 1]
        mat = bpy.data.materials.new(name=f"pal_{index}")
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        col = (r / 255.0, g / 255.0, b / 255.0, 1.0)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = col
            bsdf.inputs["Roughness"].default_value = 0.85
        mat.diffuse_color = col
        mat_cache[index] = mat
        return mat

    # Faster: create cubes via mesh from_pydata for all quads of exposed faces only.
    verts: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    face_cols: list[tuple[float, float, float, float]] = []

    def add_quad(corners, color):
        base = len(verts)
        verts.extend(corners)
        faces.append((base, base + 1, base + 2, base + 3))
        face_cols.append(color)

    cell_set = set(cells.keys())
    for (x, y, z), index in cells.items():
        r, g, b = palette[index - 1]
        col = (r / 255.0, g / 255.0, b / 255.0, 1.0)
        # Blender coords: X=x, Y=y, Z=z (same Magica axes).
        x0, y0, z0 = x - cx, y - cy, float(z)
        x1, y1, z1 = x0 + 1.0, y0 + 1.0, z0 + 1.0
        # +Z top
        if (x, y, z + 1) not in cell_set:
            add_quad([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], col)
        # -Z bottom
        if (x, y, z - 1) not in cell_set:
            add_quad([(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)], col)
        # +Y front (face)
        if (x, y + 1, z) not in cell_set:
            add_quad([(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)], col)
        # -Y back
        if (x, y - 1, z) not in cell_set:
            add_quad([(x1, y0, z0), (x1, y0, z1), (x0, y0, z1), (x0, y0, z0)], col)
        # +X right
        if (x + 1, y, z) not in cell_set:
            add_quad([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], col)
        # -X left
        if (x - 1, y, z) not in cell_set:
            add_quad([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], col)

    mesh = bpy.data.meshes.new("player_alt3")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    # Vertex colors for Workbench MATERIAL/VERTEX path — use object color via materials is hard
    # for merged mesh; paint attribute "Col".
    if not mesh.color_attributes:
        mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    attr = mesh.color_attributes["Col"]
    # 4 loops per face
    for fi, col in enumerate(face_cols):
        for li in range(4):
            attr.data[fi * 4 + li].color = col

    obj = bpy.data.objects.new("player_alt3", mesh)
    scene.collection.objects.link(obj)

    # Workbench: vertex color.
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.display.shading.shadow_intensity = 0.35

    # Camera + light.
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam_data.lens = 50

    light_data = bpy.data.lights.new("Key", type="SUN")
    light_data.energy = 2.0
    light = bpy.data.objects.new("Key", light_data)
    scene.collection.objects.link(light)
    light.rotation_euler = (0.9, 0.2, 0.4)

    # Framing: look at chest height.
    target = mathutils.Vector((0.0, 0.0, sz * 0.45))
    dist = max(sx, sy, sz) * 1.35

    views = {
        "front": (0.0, dist, sz * 0.55, 0.0),  # cam at +Y looking -Y
        "three_quarter": (dist * 0.75, dist * 0.75, sz * 0.6, 0.0),
        "side": (dist, 0.0, sz * 0.55, 0.0),
    }

    out.mkdir(parents=True, exist_ok=True)
    for name, (px, py, pz, _) in views.items():
        cam.location = (px, py, pz)
        direction = target - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        path = out / f"preview_blender_alt3_{name}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        print(f"wrote {path}")


def parse_args(argv: list[str]):
    # Blender passes args after `--`.
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--vox", type=Path, default=VOX_PATH)
    return ap.parse_args(argv)


def main() -> int:
    # Inside Blender: bpy is importable.
    try:
        import bpy  # noqa: F401

        in_blender = True
    except ImportError:
        in_blender = False

    if not in_blender:
        args = parse_args(sys.argv)
        return run_via_blender(args.out)

    args = parse_args(sys.argv)
    build_and_render(args.vox, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
