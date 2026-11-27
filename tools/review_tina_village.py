"""Independent native-map comparisons for the fixed Explorer audit cameras."""
import argparse
import base64
import collections
import hashlib
import json
import struct
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

from recover_original_crossgate_maps import preview

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/maps/original_crossgate"
OUT = ROOT / "build/Other Files/Asset Toolkit/Tina Recovery/Full Village Audit"
NAMES = [
    "Northwest snow verge", "North gate and storage", "North inlet", "Open water (no reachable ground)",
    "West verge", "Hospital, house and store", "East yards", "Northeast point",
    "West house and lane", "Green house, gate and pub", "Graveyard and harbor", "East shore",
    "Southwest channels", "South trees and beach", "Harbor and camp", "Southeast tip",
]


def data(catalog, number):
    row = catalog["maps"][f"BlueCrossgate/map/0/{number}.dat"]
    raw = zlib.decompress(base64.b64decode(row["restored_raw"]))
    return row, raw, struct.unpack("<30000H", raw[20:])


def native_bounds(catalog, values):
    left = top = 100000
    for plane in (0, 1):
        for i, serial in enumerate(values[plane*10000:(plane+1)*10000]):
            if serial < 1000:
                continue
            g = catalog["graphics"][str(serial)]
            left = min(left, (i % 100 + i // 100)*32 + g["origin"][0])
            top = min(top, (i // 100 - i % 100)*24 + g["origin"][1])
    return left, top


def pair(left, right, caption, width=720):
    height = round(left.height * width / left.width)
    result = Image.new("RGB", (width*2, height+34), "#242a2d")
    result.paste(left.convert("RGB").resize((width, height), Image.Resampling.LANCZOS), (0, 34))
    result.paste(right.convert("RGB").resize((width, height), Image.Resampling.LANCZOS), (width, 34))
    d = ImageDraw.Draw(result)
    d.text((10, 10), caption+" | ORIGINAL MAP ART", fill="white")
    d.text((width+10, 10), "CURRENT EXPLORER / FIXED CAMERA", fill="white")
    return result


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    OUT = args.out
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((ART / "catalog.json").read_text())
    pages = [Image.open(ART / f).convert("RGBA") for f in catalog["pages"]]
    natives = {}
    bounds = {}
    proof = {}
    for number in (4200, 4201):
        row, raw, values = data(catalog, number)
        server = (ROOT / f"assets/references/crossgate_tina/{'04200_tina' if number==4200 else '04201_nighttina'}").read_bytes()
        reference = struct.unpack(">20000H", server[44:])
        differences = [[i%100, i//100, values[10000+i], reference[10000+i]] for i in range(10000)
                       if (values[i], values[10000+i]) != (reference[i], reference[10000+i])]
        assert differences == ([[54,40,11497,0], [65,44,11497,0], [24,57,11497,0]] if number==4200 else [])
        bits = zlib.decompress(base64.b64decode(row["walk"]))
        open_cells = {(i%100, i//100) for i in range(10000) if bits[i//8] & (1 << (i%8))}
        # Flood from the actual pub-square arrival, keeping disconnected open islands explicit.
        connected = {(42, 55)}
        assert connected <= open_cells, "Reachability seed must be actual open ground"
        queue = collections.deque(connected)
        while queue:
            x, y = queue.popleft()
            for at in ((x-1,y), (x+1,y), (x,y-1), (x,y+1)):
                if at in open_cells and at not in connected:
                    connected.add(at)
                    queue.append(at)
        counts = collections.Counter((x//25, y//25) for x, y in open_cells)
        reachable_counts = collections.Counter((x//25, y//25) for x, y in connected)
        proof[str(number)] = {
            "raw_sha256": hashlib.sha256(raw).hexdigest(), "walk_sha256": hashlib.sha256(bits).hexdigest(),
            "source_sha256": hashlib.sha256(server).hexdigest(), "client_variations": differences,
            "open_cells": len(open_cells), "reachable_cells_4_neighbor": len(connected),
            "disconnected_open_cells": len(open_cells-connected), "sections": [
                {"id": f"{z}{x}", "name": NAMES[z*4+x], "source_bounds_inclusive": [x*25,z*25,x*25+24,z*25+24],
                 "open_cells": counts[x,z], "reachable_cells_4_neighbor": reachable_counts[x,z], "map_reference": "complete", "original_gameplay_screenshot": ("north gate: ML52 + 1.5 footage 1:06" if (x,z)==(1,0) else "night pub quarter: 1.5 footage 1:43" if (x,z)==(1,2) else "BlueCG 2015 rental variant, not the static map" if (x,z) in [(0,2),(2,1)] else "none found")}
                for z in range(4) for x in range(4)]}
        assert sum(s["open_cells"] for s in proof[str(number)]["sections"]) == len(open_cells)
        row = row.copy(); row["raw"] = row["restored_raw"]
        copy = dict(catalog); copy["maps"] = dict(catalog["maps"]); copy["maps"][f"BlueCrossgate/map/0/{number}.dat"] = row
        natives[number] = preview(copy, pages, f"BlueCrossgate/map/0/{number}.dat")
        bounds[number] = native_bounds(catalog, values)
        natives[number].save(OUT / f"original-complete-{number}.png")
    (OUT / "coverage.json").write_text(json.dumps(proof, indent=2)+"\n")
    folder = OUT / "Matched"
    folder.mkdir(exist_ok=True)
    poses = json.loads((OUT / "After/cameras.json").read_text())
    primary = []
    sectors = []
    night_sectors = []
    for pose in poses:
        number = pose.get("source_map", 4200)
        name = pose["name"]
        current = Image.open(OUT / f"After/{name}.png")
        k = pose["native_pixel_scale"]
        ox, oy = pose["native_origin_screen"]
        left, top = bounds[number]
        original = natives[number].transform(current.size, Image.Transform.AFFINE,
            (1/k, 0, -ox/k-left, 0, 1/k, -oy/k-top), Image.Resampling.BICUBIC)
        original.save(folder / f"{name}-original.png")
        panel = pair(original, current, name)
        panel.save(folder / f"{name}-comparison.jpg", quality=92)
        if name == "00-whole-village":
            pair(original, current, "MATCHED ISOMETRIC OVERHEAD MAP", 1200).save(OUT / "overhead-map-comparison.jpg", quality=95)
        if name in ["03-hospital", "05-east-yards-graveyard", "06-pub-square", "08-green-house-south-gate", "09-harbor-south-shore"]:
            primary.append(panel)
        if name.startswith("sector-"):
            sectors.append(pair(original, current, name, 320))
        if name.startswith("night-sector-"):
            night_sectors.append(pair(original, current, name, 320))
    if primary:
        sheet = Image.new("RGB", (primary[0].width, sum(p.height for p in primary)))
        y = 0
        for panel in primary:
            sheet.paste(panel, (0,y)); y += panel.height
        sheet.save(OUT / "matched-landmarks.jpg", quality=94)
    for panels, filename in [(sectors, "all-sections.jpg"), (night_sectors, "all-sections-night.jpg")]:
        if panels:
            sheet = Image.new("RGB", (panels[0].width*2, panels[0].height*8), "#242a2d")
            for i, panel in enumerate(panels):sheet.paste(panel, ((i%2)*panel.width, (i//2)*panel.height))
            sheet.save(OUT / filename, quality=93)
    print("Independent full-map checks passed; matched views:", len(poses))


if __name__ == "__main__":
    main()
