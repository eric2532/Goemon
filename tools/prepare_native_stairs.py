"""Recover stone paint for the five source-confirmed six-tread stair graphics."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/maps/original_crossgate"
OUT = ROOT / "assets/maps/falan/native_stairs"
IDS = (17964, 17966, 17972, 17984, 17996)


def prepare():
    catalog = json.loads((ART / "east/catalog.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    records = {}
    for serial in IDS:
        graphic = catalog["graphics"][str(serial)]
        x, y, width, height = graphic["rect"]
        image = Image.open(ART / catalog["pages"][graphic["page"]]).convert("RGBA").crop((x, y, x+width, y+height))
        assert hashlib.sha256(image.tobytes()).hexdigest() == graphic["rgba_sha256"]
        # Reuse the Habaru stair preparer's measured native stone-face method.
        origin, across, down = (10, 20), (18, -13), (2, 2)
        face = Image.new("RGB", (32, 32))
        for v in range(32):
            for u in range(32):
                point = tuple(round(origin[i] + (across[i]*u + down[i]*v)/31) for i in (0, 1))
                pixel = image.getpixel(point)
                assert pixel[3] == 255, (serial, point)
                face.putpixel((u, v), pixel[:3])
        colors = list(face.getdata())
        records[str(serial)] = {"source_rgba_sha256": graphic["rgba_sha256"],
            "stone_color": [sum(p[i] for p in colors)/len(colors)/255 for i in range(3)],
            "source_face": {"origin": origin, "across": across, "down": down}}
    (OUT / "provenance.json").write_text(json.dumps({
        "method": "Measured native stone-face pigment with existing Habaru six-tread geometry and painterly stone material; original art unchanged",
        "inferred": "Unseen stone volume and darker riser shade (60% of native pigment); no new collision or map placement",
        "graphics": records}, indent=2) + "\n")
    print(f"Prepared {len(records)} native stair paints; RGBA and sampled alpha verified")


if __name__ == "__main__":
    prepare()
