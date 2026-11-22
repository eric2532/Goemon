"""Prepare the preserved client's HitCombo glyphs; never execute client bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "assets/characters/crossgate/hit_feedback"
SERIALS = [*range(23140, 23149), *range(23158, 23166)]
OFFSETS = [0, 34, 54, 66, 88, 108, 131, 152, 171, 0]
ORDER = [0, 8, 7, 6, 5, 4, 3, 2, 1, 9]


def recover(source: Path):
    sys.path.insert(0, str(source / "tools"))
    import cg_library
    memory = source / "research/newclient20261030/combat/bluecg-virtual-memory.bin"
    data = memory.read_bytes()
    assert struct.unpack_from("<10i", data, 0x543A90 - 0x400000) == tuple(OFFSETS)
    assert struct.unpack_from("<10i", data, 0x543AB8 - 0x400000) == tuple(ORDER)
    assert struct.unpack_from("<f", data, 0x53E5B4 - 0x400000)[0] == 32
    raw, _ = cg_library.cg.graphic_index("original")
    rows = list(cg_library.cg.RECORD.iter_unpack(raw))
    by_serial = {r[-1]: i for i, r in enumerate(rows)}
    atlas = Image.new("RGBA", (96 * len(SERIALS), 64))
    glyphs = []
    for index, serial in enumerate(SERIALS):
        row = by_serial[serial]
        record = rows[row]
        image = cg_library.image_from_record("original", row).convert("RGBA")
        x, y = 48 + record[3], 32 + record[4]
        assert 0 <= x <= 96 - image.width and 0 <= y <= 64 - image.height
        atlas.paste(image, (index * 96 + x, y))
        assert atlas.crop((index * 96 + x, y, index * 96 + x + image.width, y + image.height)).tobytes() == image.tobytes()
        glyphs.append(dict(serial=serial, row=row, origin=list(record[3:5]), size=list(image.size), sha256=hashlib.sha256(image.tobytes()).hexdigest()))
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / "joint-attack.png")
    ten = atlas.crop((799, 16, 835, 45))
    digits = Image.new("RGBA", (40, 31))
    for y in range(ten.height):
        # The two outlines meet on rows 12 and 23. Split between their strokes.
        split = 15 if y < 7 else 14
        digits.paste(ten.crop((0, y, split, y + 1)), (1, y + 1))
        digits.paste(ten.crop((split, y, 35, y + 1)), (18 + split - 14, y + 1))
    digits.save(OUT / "hitcombo-01.png")
    result = dict(glyphs=glyphs, cell=[96, 64], offsets=OFFSETS, order=ORDER,
                  client_sha256=hashlib.sha256(data).hexdigest(),
                  layout_function="0x41D800..0x41DAA8", motion_function="0x41DAB0..0x41DD99",
                  limits=["Original glyph pixels, origins, count selection, spacing and entry order are preserved.",
                          "World-space placement and the real-time joint-contact window are Goemon adaptations, not original turn-based battle recovery."])
    (OUT / "joint-attack.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    result = recover(parser.parse_args().source.resolve())
    print("Preserved", len(result["glyphs"]), "original HitCombo glyphs and native layout tables.")
