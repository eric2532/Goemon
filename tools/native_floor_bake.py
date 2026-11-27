"""Composite preserved native floor diamonds before making a continuous texture."""
import base64
import hashlib
import struct
import zlib
from pathlib import Path

from PIL import Image

ART = Path(__file__).resolve().parents[1] / "assets/maps/original_crossgate"


def bake_floor(catalog, number, output):
    key = f"BlueCrossgate/map/0/{number}.dat"
    row = catalog["maps"][key]
    raw = zlib.decompress(base64.b64decode(row["restored_raw"]))
    width, height = row["size"]
    cells = width*height
    floor = struct.unpack(f"<{cells}H", raw[20:20+cells*2])
    pages, tiles, hashes = {}, {}, {}
    for serial in sorted(set(floor)):
        if serial < 1000:
            continue
        graphic = catalog["graphics"][str(serial)]
        page = graphic["page"]
        if page not in pages:
            pages[page] = Image.open(ART / catalog["pages"][page]).convert("RGBA")
        x, y, w, h = graphic["rect"]
        assert (w, h) == (64, 47), (number, serial, w, h)
        tile = pages[page].crop((x, y, x+w, y+h))
        digest = hashlib.sha256(tile.tobytes()).hexdigest()
        assert digest == graphic["rgba_sha256"], (number, serial)
        tiles[serial] = tile
        hashes[str(serial)] = digest
    composed = Image.new("RGBA", ((width+height)*32+64, (width+height)*24+48))
    for cell, serial in enumerate(floor):
        if serial not in tiles:
            continue
        x, y = cell % width, cell // width
        origin = catalog["graphics"][str(serial)]["origin"]
        composed.alpha_composite(tiles[serial], ((x+y)*32+32+origin[0], (y-x)*24+width*24+origin[1]))
    # Native pixel area is1536px/cell;40x40 retains that density.
    continuous = composed.transform((width*40, height*40), Image.Transform.AFFINE,
        (32/40, 32/40, 0, -24/40, 24/40, width*24), Image.Resampling.BILINEAR)
    continuous.convert("RGB").save(output)
    return {"source_map": key, "source_raw_sha256": hashlib.sha256(raw).hexdigest(),
        "size": [width, height], "pixels_per_cell": 40, "output": output.name,
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "source_tiles": hashes}
