"""Render a compact, original top-down radar from the bundled Dust II OBJ."""
from pathlib import Path
import json
import math

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "dust2"
OBJ_PATH = ASSET_DIR / "dust2.obj"
META_PATH = ASSET_DIR / "model_info.json"
OUTPUT_PATH = ASSET_DIR / "dust2_radar.png"
IMAGE_SIZE = 768
PADDING = 18


def main() -> None:
    bounds = json.loads(META_PATH.read_text(encoding="utf-8"))["bounds"]
    minimum = bounds["min"]
    maximum = bounds["max"]
    scale = min(
        (IMAGE_SIZE - PADDING * 2) / (maximum[0] - minimum[0]),
        (IMAGE_SIZE - PADDING * 2) / (maximum[2] - minimum[2]),
    )
    x_padding = (IMAGE_SIZE - (maximum[0] - minimum[0]) * scale) * 0.5
    z_padding = (IMAGE_SIZE - (maximum[2] - minimum[2]) * scale) * 0.5

    def project(x: float, z: float) -> tuple[int, int]:
        return (
            round(x_padding + (x - minimum[0]) * scale),
            round(z_padding + (z - minimum[2]) * scale),
        )

    image = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), (19, 30, 29))
    draw = ImageDraw.Draw(image)
    vertices: list[tuple[float, float, float]] = []
    wall_edges: list[tuple[tuple[int, int], tuple[int, int]]] = []
    with OBJ_PATH.open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("v "):
                _, x, y, z = line.split()
                vertices.append((float(x), float(y), float(z)))
            elif line.startswith("f "):
                indices = [int(part.split("/")[0]) - 1 for part in line.split()[1:4]]
                a, b, c = (vertices[index] for index in indices)
                ab = tuple(b[i] - a[i] for i in range(3))
                ac = tuple(c[i] - a[i] for i in range(3))
                normal = (
                    ab[1] * ac[2] - ab[2] * ac[1],
                    ab[2] * ac[0] - ab[0] * ac[2],
                    ab[0] * ac[1] - ab[1] * ac[0],
                )
                normal_length = math.sqrt(sum(component * component for component in normal))
                # Only near-vertical faces describe useful plan-view walls.
                if normal_length < 1e-6 or abs(normal[1]) / normal_length > 0.48:
                    continue
                points = [project(point[0], point[2]) for point in (a, b, c)]
                for index in range(3):
                    start = points[index]
                    end = points[(index + 1) % 3]
                    if math.dist(start, end) > 1.1:
                        wall_edges.append((start, end))

    for start, end in wall_edges:
        draw.line((start, end), fill=(132, 145, 132), width=2)
    draw.rectangle(
        (PADDING, PADDING, IMAGE_SIZE - PADDING, IMAGE_SIZE - PADDING),
        outline=(82, 102, 90),
        width=2,
    )
    # Official Dust II overview bomb-site fractions mapped into this mesh's
    # world bounds; keep the painted sites on the same transform as gameplay.
    x_span = maximum[0] - minimum[0]
    z_span = maximum[2] - minimum[2]
    sites = (
        ("A", minimum[0] + x_span * 0.80, minimum[2] + z_span * 0.16),
        ("B", minimum[0] + x_span * 0.21, minimum[2] + z_span * 0.12),
    )
    for label, x, z in sites:
        px, py = project(x, z)
        radius = 7
        color = (234, 177, 82)
        draw.ellipse((px - radius, py - radius, px + radius, py + radius), outline=color, width=2)
        draw.text((px + 9, py - 8), label, fill=color)
    image.save(OUTPUT_PATH, optimize=True)


if __name__ == "__main__":
    main()
