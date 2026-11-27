"""Tina terrain: preserve legacy gutters and bake native alpha joins continuously."""
import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path

from PIL import Image
from native_floor_bake import bake_floor

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/maps/original_crossgate"
OUT = ROOT / "assets/maps/falan/tina"


def prepare():
    catalog = json.loads((ART / "catalog.json").read_text())
    serials = set()
    for number in (4200, 4201):
        row = catalog["maps"][f"BlueCrossgate/map/0/{number}.dat"]
        raw = zlib.decompress(base64.b64decode(row["restored_raw"]))
        serials.update(s for s in struct.unpack("<10000H", raw[20:20020]) if s >= 1000)
    atlas = Image.new("RGBA", (16 * 72, ((len(serials) + 15) // 16) * 56))
    pages = {}
    records = {}
    for index, serial in enumerate(sorted(serials)):
        graphic = catalog["graphics"][str(serial)]
        page = graphic["page"]
        if page not in pages:
            pages[page] = Image.open(ART / catalog["pages"][page]).convert("RGBA")
        x, y, width, height = graphic["rect"]
        original = pages[page].crop((x, y, x + width, y + height))
        assert (width, height) == (64, 47), (serial, original.size)
        assert hashlib.sha256(original.tobytes()).hexdigest() == graphic["rgba_sha256"]
        tile = original.copy()
        # A floor quad samples only the diamond. Extend its edge colors into the
        # transparent gutter so filtering cannot expose cracks between neighbors.
        pixels = tile.load()
        for row in range(height):
            occupied = [col for col in range(width) if pixels[col, row][3] > 127]
            if not occupied:
                continue
            left, right = occupied[0], occupied[-1]
            for col in range(width):
                r, g, b, _ = pixels[min(right, max(left, col)), row]
                pixels[col, row] = (r, g, b, 255)
        for row in range(height):
            if pixels[32, row][3] == 0:
                closest = min((r for r in range(height) if pixels[32, r][3]), key=lambda r: abs(r-row))
                tile.paste(tile.crop((0, closest, width, closest+1)), (0, row))
        px, py = (index % 16) * 72 + 4, (index // 16) * 56 + 4
        atlas.paste(tile, (px, py))
        atlas.paste(tile.crop((0, 0, 1, height)).resize((4, height)), (px-4, py))
        atlas.paste(tile.crop((width-1, 0, width, height)).resize((4, height)), (px+width, py))
        atlas.paste(atlas.crop((px-4, py, px+width+4, py+1)).resize((72, 4)), (px-4, py-4))
        atlas.paste(atlas.crop((px-4, py+height-1, px+width+4, py+height)).resize((72, 5)), (px-4, py+height))
        assert tile.getchannel("A").getextrema() == (255, 255)
        records[str(serial)] = {"rect": [px, py, width, height], "source_rgba_sha256": graphic["rgba_sha256"]}
    atlas.save(OUT / "ground.png")
    # Composite original alpha diamonds before rectifying the complete floor.
    # Native pixel area is1536px/tile;40x40 retains that density. Runtime needs
    # one continuous sample rather than four dependent tile lookups.
    floors = {str(number): bake_floor(catalog, number, OUT / f"ground-continuous-{number}.png")
              for number in (4200, 4201)}
    (OUT / "ground-continuous.json").write_text(json.dumps({
        "method": "Original RGBA diamonds alpha-composited in native source-cell order, then affine-rectified once; no tile replacement or geometry change",
        "inferred_surfaces": "None; existing floor footprint, heights and native ground selection retained",
        "source_tiles": records, "maps": floors}, indent=2) + "\n")
    (OUT / "ground.json").write_text(json.dumps({"method": "Original opaque pixels preserved; alpha-edge colors extended into floor filtering gutters only", "graphics": records}, indent=2) + "\n")
    print(f"Prepared {len(records)} Tina terrain tiles; native RGBA hashes verified")


if __name__ == "__main__":
    prepare()
