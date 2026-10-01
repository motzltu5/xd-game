"""Convert the supplied 3DS map from its ZIP archive into a Godot-friendly OBJ."""
import json
import struct
import zipfile
from pathlib import Path

SOURCE = Path(r"C:\Users\motzl\Downloads\3d-model.3ds.zip")
DEST = Path(__file__).resolve().parents[1] / "assets" / "dust2"
SCALE = 0.06  # Source is centimetre-like; this gives Dust II a playable ~290-unit span.
Z_CENTER = (-152.47904296875 + 145.2850341796875) * 0.5
FLOOR_Y = 11.855462


def chunks(data, start=0, end=None):
    end = len(data) if end is None else end
    offset = start
    while offset + 6 <= end:
        chunk_id, length = struct.unpack_from("<HI", data, offset)
        if length < 6 or offset + length > end:
            break
        payload = offset + 6
        yield chunk_id, payload, offset + length
        offset += length


def read_string(data, offset, end):
    stop = data.find(b"\0", offset, end)
    if stop < 0:
        return "", end
    return data[offset:stop].decode("latin1", errors="replace"), stop + 1


def read_mesh(data, start, end):
    objects, materials = [], {}
    for outer_id, outer_start, outer_end in chunks(data, start, end):
        if outer_id == 0xAFFF:
            name = ""
            rgb = (0.76, 0.68, 0.55)
            for mid, ms, me in chunks(data, outer_start, outer_end):
                if mid == 0xA000:
                    name, _ = read_string(data, ms, me)
                elif mid == 0xA020:
                    for cid, cs, ce in chunks(data, ms, me):
                        if cid in (0x0011, 0x0012, 0x0013) and cs + 3 <= ce:
                            rgb = tuple(channel / 255.0 for channel in data[cs:cs + 3])
                        elif cid in (0x0010, 0x0015, 0x0016) and cs + 12 <= ce:
                            rgb = struct.unpack_from("<3f", data, cs)
            if name:
                materials[name] = rgb
        elif outer_id == 0x4000:
            name, mesh_start = read_string(data, outer_start, outer_end)
            vertices, faces, assignments = [], [], {}
            local_matrix = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0)
            for mid, ms, me in chunks(data, mesh_start, outer_end):
                if mid == 0x4100:
                    for sid, ss, se in chunks(data, ms, me):
                        if sid == 0x4160 and ss + 48 <= se:
                            local_matrix = struct.unpack_from("<12f", data, ss)
                        elif sid == 0x4110:
                            count = struct.unpack_from("<H", data, ss)[0]
                            vertices = [struct.unpack_from("<3f", data, ss + 2 + i * 12) for i in range(count)]
                        elif sid == 0x4120:
                            count = struct.unpack_from("<H", data, ss)[0]
                            faces = [struct.unpack_from("<4H", data, ss + 2 + i * 8)[:3] for i in range(count)]
                            for fid, fs, fe in chunks(data, ss + 2 + count * 8, se):
                                if fid == 0x4130:
                                    material_name, cursor = read_string(data, fs, fe)
                                    face_count = struct.unpack_from("<H", data, cursor)[0]
                                    cursor += 2
                                    for i in range(face_count):
                                        assignments[struct.unpack_from("<H", data, cursor + i * 2)[0]] = material_name
            if vertices and faces:
                # This source stores the mesh vertices in map space. Its 3x3
                # basis describes a rotation around the mesh pivot; apply it
                # around the stored pivot without reapplying its translation.
                origin = local_matrix[9:12]
                basis_x = local_matrix[0:3]
                basis_y = local_matrix[3:6]
                basis_z = local_matrix[6:9]
                transformed = []
                for x, y, z in vertices:
                    rx, ry, rz = x - origin[0], y - origin[1], z - origin[2]
                    transformed.append((
                        origin[0] + rx * basis_x[0] + ry * basis_y[0] + rz * basis_z[0],
                        origin[1] + rx * basis_x[1] + ry * basis_y[1] + rz * basis_z[1],
                        origin[2] + rx * basis_x[2] + ry * basis_y[2] + rz * basis_z[2],
                    ))
                objects.append((name, transformed, faces, assignments))
    return objects, materials


with zipfile.ZipFile(SOURCE) as archive:
    entry = next(name for name in archive.namelist() if name.lower().endswith(".3ds"))
    data = archive.read(entry)
root = next((payload, end) for cid, payload, end in chunks(data) if cid == 0x4D4D)
editor = next((payload, end) for cid, payload, end in chunks(data, *root) if cid == 0x3D3D)
objects, source_materials = read_mesh(data, *editor)

DEST.mkdir(parents=True, exist_ok=True)
obj_path = DEST / "dust2.obj"
mtl_path = DEST / "dust2.mtl"
metadata_path = DEST / "model_info.json"

# A single smooth neutral sandstone material keeps the asset coherent when the
# 3DS material library contains only the source's many white placeholder colors.
with mtl_path.open("w", encoding="utf-8", newline="\n") as mtl:
    mtl.write("newmtl DustStone\nKd 0.76 0.68 0.55\nKa 0.20 0.18 0.15\nKs 0.05 0.05 0.05\nNs 16\n")

vertices_out, faces_out = [], []
grounded_components = []
floating_components = []
converted_objects = []
for name, vertices, faces, _assignments in objects:
    points = [(x * SCALE, z * SCALE, -y * SCALE - Z_CENTER) for x, y, z in vertices]
    converted_objects.append({"name": name, "points": points, "faces": faces})

min_bounds = [float("inf")] * 3
max_bounds = [float("-inf")] * 3
total_faces = 0
base = 1
with obj_path.open("w", encoding="utf-8", newline="\n") as obj:
    obj.write("mtllib dust2.mtl\nusemtl DustStone\ns off\n")
    for component in converted_objects:
        obj.write(f"o Dust_II_{component['name']}\n")
        for point in component["points"]:
            vertices_out.append(point)
            for axis in range(3):
                min_bounds[axis] = min(min_bounds[axis], point[axis])
                max_bounds[axis] = max(max_bounds[axis], point[axis])
            obj.write(f"v {point[0]:.6f} {point[1]:.6f} {point[2]:.6f}\n")
        for a, b, c in component["faces"]:
            obj.write(f"f {base + a} {base + b} {base + c}\n")
            total_faces += 1
        base += len(component["points"])
        faces_out.extend(component["faces"])

metadata = {
    "source": str(SOURCE), "entry": entry, "mesh_objects": len(objects),
    "vertices": len(vertices_out), "faces": total_faces, "scale": SCALE,
    "mesh_local_matrices_applied": True,
    "bounds": {"min": min_bounds, "max": max_bounds},
    "source_materials": len(source_materials),
    "grounded_components": grounded_components,
    "floating_components_corrected": floating_components,
}
metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
print(json.dumps(metadata, indent=2))
