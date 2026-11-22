"""Prepare shallow carving depth from the original arena crest, letters and rings."""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CARVING_EDGE = 256


def carving_depth(atlas):
    assert atlas.size == (CARVING_EDGE * 5, CARVING_EDGE), "Expected five recovered 256px emblems"
    stone = Image.new("L", (CARVING_EDGE, CARVING_EDGE))
    for y in range(CARVING_EDGE):
        for x in range(CARVING_EDGE):
            # Shared pale strokes survive the green/red/blue dyes; colored grain does not.
            white = sum(min(atlas.getpixel((x + variant * CARVING_EDGE, y))[:3])
                        for variant in (0, 1, 3)) / 3
            stone.putpixel((x, y), round(white))
    depth = shallow_depth(stone)
    assert depth.getextrema()[1] > 220
    assert .05 < sum(v > 127 for v in depth.getdata()) / (CARVING_EDGE * CARVING_EDGE) < .5
    return depth


def shallow_depth(stone):
    """Retain pale carved strokes and seal their edges against the supporting stone."""
    width,height = stone.size
    surrounding = stone.filter(ImageFilter.GaussianBlur(4))
    depth = Image.new("L", stone.size)
    for y in range(height):
        for x in range(width):
            amount = max(0, min(1, (stone.getpixel((x, y))
                                  - surrounding.getpixel((x, y)) - 4) / 35))
            amount = amount * amount * (3 - 2 * amount)
            border = max(0, min(1, min(x, y, width - 1 - x, height - 1 - y) / 8))
            depth.putpixel((x, y), round(amount * border * 255))
    # Refine the contours between source pixels without reducing the deep cuts.
    depth = depth.filter(ImageFilter.GaussianBlur(.65))
    peak = depth.getextrema()[1]
    assert peak > 0
    depth = depth.point([round(value * 255 / peak) for value in range(256)])
    # Seal the slab edges so the recessed mesh meets the existing platform cleanly.
    for x in range(width):
        depth.putpixel((x,0),0);depth.putpixel((x,height-1),0)
    for y in range(height):
        depth.putpixel((0,y),0);depth.putpixel((width-1,y),0)
    return depth


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("magic_power", nargs="?", type=Path, help="Recover detail from the original Magic Power library first")
    args = parser.parse_args()
    if args.magic_power is not None:
        sys.path.insert(0, str(args.magic_power.resolve() / "tools"))
        import cg_library as library
        from build_falan_room_art import arena_inlay_detail
        arena_inlay_detail(library, library.serial_index(), ROOT / "assets/maps/falan")
    source = ROOT / "assets/maps/falan/arena_inlays_detail.png"
    output = source.with_name("arena_carving_depth.png")
    carving_depth(Image.open(source).convert("RGB")).save(output, optimize=True)
    print(f"Prepared {output.relative_to(ROOT)}; original artwork unchanged")
