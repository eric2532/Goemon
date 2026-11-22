"""Pack the preserved Blue Cross Gate battle feedback and Guard Break icon."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "assets/characters/crossgate/hit_feedback"


def recover(source: Path):
    sys.path.insert(0, str(source / "tools"))
    import cg_library

    spells = source / "godot/assets/humanoid-spells"
    clips = json.loads((spells / "manifest.json").read_text())["clips"]
    critical = clips["110008"]
    burst = (spells / "110008.png").read_bytes()
    assert hashlib.sha256(burst).hexdigest() == critical["sha256"]
    assert (critical["frames"], critical["width"], critical["height"], critical["duration"]) == (4, 260, 249, 300)

    digits = [cg_library.image_from_record("original", 19026 + digit).convert("RGBA") for digit in range(10)]
    assert [digit.size for digit in digits] == [(32, 64), (24, 64)] + [(32, 64)] * 8
    pack_font("damage", list(zip("0123456789", digits)), 64)

    # The HP recovery branch passes kind 5 to 0x41c950, whose table starts at 243750.
    raw_index, _ = cg_library.cg.graphic_index("v3")
    rows_by_serial = {record[-1]: row for row, record in enumerate(cg_library.cg.RECORD.iter_unpack(raw_index))}
    serials = [243850, *range(243750, 243760)]
    healing = [cg_library.image_from_record("v3", rows_by_serial[serial]) for serial in serials]
    assert [glyph.size for glyph in healing] == [(12, 10)] + [(12, 16)] * 10
    assert all({pixel[:3] for pixel in glyph.getdata() if pixel[3]} == {(0, 255, 0)} for glyph in healing)
    pack_font("healing", list(zip("+0123456789", healing)), 16)
    (OUT / "critical.png").write_bytes(burst)
    exclamation = cg_library.image_from_record("original", 19060)
    assert exclamation.size == (36, 36)
    assert hashlib.sha256(exclamation.tobytes()).hexdigest() == "0900498e62193d87d205dbf68fe905075ff38cacc4a33af54d1b07dbb01e2e62"
    exclamation.save(OUT / "exclamation.png")
    pack_guard_break_icon(spells / "110139.png", clips["110139"])


def pack_guard_break_icon(path, clip):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
    width, height = clip["width"], clip["height"]
    with Image.open(path) as sheet:
        assert sheet.size == (8 * width, height) and sheet.mode == "RGBA"
        icon = sheet.crop((3 * width, 0, 4 * width, height))
    icon = icon.crop(icon.getbbox())
    icon.thumbnail((60, 60), Image.Resampling.LANCZOS)
    square = Image.new("RGBA", (64, 64))
    square.paste(icon, ((64 - icon.width) // 2, (64 - icon.height) // 2))
    square.save(OUT / "guard-break-icon.png")


def pack_font(name, glyphs, height):
    atlas = Image.new("RGBA", (sum(glyph.width + 2 for _, glyph in glyphs), height))
    rows = [
        f'info face="Blue Cross Gate {name.title()}" size={height} bold=0 italic=0',
        f'common lineHeight={height} base={height} scaleW={atlas.width} scaleH={height} pages=1 packed=0',
        f'page id=0 file="{name}.png"',
        f'chars count={len(glyphs)}',
    ]
    x = 1
    for char, glyph in glyphs:
        atlas.paste(glyph, (x, 0))
        rows.append(f"char id={ord(char)} x={x} y=0 width={glyph.width} height={glyph.height} "
                    f"xoffset=0 yoffset={(height - glyph.height) // 2} xadvance={glyph.width} page=0 chnl=15")
        x += glyph.width + 2
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / f"{name}.png")
    (OUT / f"{name}.fnt").write_text("\n".join(rows) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    recover(parser.parse_args().source.resolve())
