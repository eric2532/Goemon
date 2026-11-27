"""Read-only source bank bounds and existing floor-mask placement diagnosis."""
import base64
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion'


def main():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    data = json.loads((ROOT/'assets/maps/falan/east_region/il_source_completion/data.json').read_text())
    lookup = lib.serial_index(); mask = Image.open(ROOT/'assets/maps/falan/freyja_il_village.png').convert('RGBA')
    with lib.connection() as db:
        record = dict(db.execute('SELECT * FROM files WHERE path=?', ('BlueCrossgate/map/0/2000.dat',)).fetchone())
    raw = (lib.SOURCE/record['path']).read_bytes(); values = struct.unpack_from('<32400H', raw, 20)
    bits = base64.b64decode(data['native_walk']['before_bits'])
    wet = [values[10800+i] for i in range(10800) if bits[i >> 3] & (1 << (i & 7)) and mask.getpixel((i % 90, i // 90))[0] > 127]
    rows, images = [], {}
    for x, z, serial, _ in data['additional_scenery_rows']:
        graphic = lookup[serial]; image = lib.image_from_record(graphic['pack'], graphic['row']).convert('RGBA'); images[serial] = image
        depth = max(.2, (graphic['h']+graphic['y']-24)*.045); points = []
        for py in range(image.height):
            for px in range(image.width):
                r, green, b, alpha = image.getpixel((px, py)); u = (px+graphic['x'])/(32/3); v = (py+graphic['y'])/8
                xx, zz = (u-v)/2, (u+v)/2
                if alpha > 128 and green > r*.92 and green > b*1.16 and -1.5 <= xx <= 1.5 and -1.5 <= zz <= 1.5:
                    points.append([xx, zz])
        dry = []
        for radius in range(1, 5):
            for yy in range(max(0, z-radius), min(120, z+radius+1)):
                for xx in range(max(0, x-radius), min(90, x+radius+1)):
                    if mask.getpixel((xx, yy))[0] < 128: dry.append([xx, yy, math.hypot(xx-x, yy-z)])
            if dry: break
        nearest = min(dry, key=lambda p: p[2])
        bounds = [min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points)] if points else None
        rows.append({'source_cell': [x, z], 'graphic': serial, 'origin': [graphic['x'], graphic['y']], 'size': list(image.size),
                     'native_rgba_sha256': hashlib.sha256(image.tobytes()).hexdigest(),
                     'existing_mesh_aabb': {'position': [-1.5, -depth, -1.5], 'size': [3, depth+.018, 3]},
                     'existing_plan_y_from_floor_only_mask': 0, 'existing_plan_top': .018, 'water_local_height': 2,
                     'nearest_original_dry_cell': nearest[:2], 'nearest_dry_distance_cells': nearest[2], 'nearest_dry_local_height': 6,
                     'native_alpha_diagnostic': {'green_pixels_projected_on_y0_inside_original_1x1': len(points), 'projected_xz_bounds': bounds,
                                                 'limit': 'Source alpha/RGB are exact; this projection is a diagnostic, not recovered cap geometry or a collision polygon.'}})
    report = {'source': 2000, 'rows': rows, 'known_attribute_open_wet_mask_baseline': {'count': len(wet), 'object_counts': dict(Counter(wet))},
              'baseline_limit': 'The existing mask/attribute mismatch includes625known cells (242low marker252,383known125xxbanks). This is not authorization to change those cells or proof they were originally physical floor.',
              'derived_from': ['forest_original_map_solids.gd bank branch:3x3cap0.018, native downward depth',
                               'forest_il_laruka_art.gd build_exterior:model.surface_height at the source anchor',
                               'forest_freyja_terrain.gd bed=bank*(1-paint.r), WATER_HEIGHT2, BANK_HEIGHT6'],
              'actual_gate': 'The focused actual fixture must measure final modelY/AABB/native clearance. Static analysis alone does not establish physical completion.',
              'smallest_candidate_if_underwater': 'Only these six new source-bank placements may receive measured cap/support aligned to the adjacent6m original bank, within original1x1footprints and native alpha-facing paint. Reuse existing bank/Palace support primitives; continue inferred hidden depth down to2mwater. Do not change the625known cases, the global mask rule, source markers or routes.'}
    (OUT/'bank-static-measurement.json').write_text(json.dumps(report, indent=2)+'\n')
    ids = sorted(images); sheet = Image.new('RGB', (len(ids)*230, 335), (30, 36, 37)); draw = ImageDraw.Draw(sheet)
    for slot, serial in enumerate(ids):
        g = lookup[serial]; image = images[serial].resize((images[serial].width*3, images[serial].height*3), Image.Resampling.NEAREST)
        sheet.paste(image, (slot*230+8, 45), image); draw.text((slot*230+8, 12), f'{serial} original pixels 3x', fill='white')
        draw.text((slot*230+8, 310), f"origin{g['x'],g['y']} foot{g['east'],g['south']}", fill='white')
    sheet.save(OUT/'six-shore-native-forms.png')
    print('Measured six source bank candidates: staticcap0.018 below2mwater; nearest existing dry bank6m. Actual gate remains open.')


if __name__ == '__main__': main()
