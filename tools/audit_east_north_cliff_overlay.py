"""Read-only source100 cliffs displaced by the existing joined Alyut presentation."""
import base64
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    data_path = ROOT / 'assets/maps/falan/east_field_cliffs/data.json'
    data = json.loads(data_path.read_text())
    field_path = ROOT / 'assets/maps/falan/east_region/field-scenery.json'
    prepared = json.loads(field_path.read_text())['north_coast']['ridges']
    live_path = AUDIT / 'private-volume-live-review.json'
    live = json.loads(live_path.read_text())['camera_performance'][-1]['source_owners']
    mounted = set(tuple(row) for row in live['north_coast']['anchors'])
    rows = []
    for row in prepared:
        if not 12536 <= row[2] < 12548:
            continue
        foot = [round(row[3] / 3), round(row[4] / 3)]
        anchor = [round(row[0] - (foot[0] - 1) * .5), round(row[1] + (foot[1] - 1) * .5)]
        key = (row[2], *anchor)
        overlay = 529 <= row[0] < 629 and 20 <= row[1] < 120
        assert (key not in mounted) == overlay, key
        rows.append({'graphic': row[2], 'cell': anchor, 'footprint': foot,
                     'source_center': row[:2], 'inside_existing_village_overlay': overlay,
                     'mounted_as_source100_cliff': key in mounted})
    displaced = [row for row in rows if row['inside_existing_village_overlay']]
    assert len(displaced) == 132 and len(mounted) == 71
    raw_path = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
    assert sha(raw_path) == data['field']['source_sha256']
    raw = raw_path.read_bytes(); width, height = struct.unpack_from('>HH', raw, 40)
    count = width * height
    ground = struct.unpack_from(f'>{count}H', raw, 44)
    objects = struct.unpack_from(f'>{count}H', raw, 44 + count * 2)
    for row in rows:
        x, y = row['cell']; assert objects[y * width + x] == row['graphic']
    walk = zlib.decompress(base64.b64decode(data['field']['walk']))
    walkable = sum(bool(walk[(y * width + x) >> 3] & (1 << ((y * width + x) & 7)))
                   for y in range(20, 120) for x in range(529, 629))
    report = {'scope': 'Existing joined Alyut layout inference, not equivalent source recovery and not a route/navigation change. All132 exact source100 placements below are excluded by Regions.village_contains; native2400 village placements are a separate map.',
              'source100_sha256': sha(raw_path), 'field_scenery_sha256': sha(field_path),
              'live_evidence_sha256': sha(live_path), 'field_counts': {'native': 220, 'entrance_handoffs': 17, 'prepared': 203, 'village_overlay_exclusions': 132, 'mounted': 71},
              'original_field_walkable_cells_inside_overlay': walkable,
              'village2400': {'native_cliff_placements': 125, 'distinct_native_cliff_footprint_cells': 579,
                              'source_sha256': data['alyut']['source_sha256']},
              'transform_proof': {'north_coast_frame_origin': [1902, 333], 'alyut_join_translation': [-165, -123],
                                  'village_local_bounds': [-150, -150, 300, 300],
                                  'source100_center_rectangle_half_open': [529, 20, 629, 120],
                                  'formula': 'village_local = source100_center*3 - [1902,333] - [-165,-123]; membership is [-150,150) on both axes'},
              'displaced_source100_placements': displaced,
              'non_displaced_source100_placements': [row for row in rows if not row['inside_existing_village_overlay']]}
    (AUDIT / 'north-overlay-proof.json').write_text(json.dumps(report, indent=2) + '\n')
    # Exact source-grid proof. This does not depict a proposed rebuild.
    left, top, extent, scale = 515, 5, 130, 6
    image = Image.new('RGB', (extent * scale, extent * scale + 48), '#252e34'); draw = ImageDraw.Draw(image)
    for y in range(top, top + extent):
        for x in range(left, left + extent):
            i = y * width + x
            if walk[i >> 3] & (1 << (i & 7)):
                draw.rectangle(((x-left)*scale, (y-top)*scale+48, (x-left+1)*scale-1, (y-top+1)*scale+47), fill='#51684a')
    for row in rows:
        color = '#ee625e' if row['inside_existing_village_overlay'] else '#e4d888'
        x, y = row['cell']; ew, ns = row['footprint']
        draw.rectangle(((x-left)*scale, (y-top-ns+1)*scale+48, (x-left+ew)*scale-1, (y-top+1)*scale+47), outline=color, width=2)
    draw.rectangle(((529-left)*scale, (20-top)*scale+48, (629-left)*scale, (120-top)*scale+48), outline='#70caff', width=3)
    draw.text((8, 7), 'Original source100 / blue: existing joined village overlay', fill='white')
    draw.text((8, 25), 'Red:132 source100 cliffs displaced / yellow: retained field rows / green: native walk', fill='white')
    image.save(AUDIT / 'north-overlay-source-grid.png')
    # Original native floor/object planes, separately from the runtime geometry.
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools')); import cg_library as lib
    lookup = lib.serial_index(); images = {}; placements = []
    for layer, plane in enumerate([ground, objects]):
        for y in range(top, top + extent):
            for x in range(left, left + extent):
                serial = plane[y * width + x]
                if serial == 0 or layer == 1 and serial < 1000: continue
                g = lookup[serial]
                if serial not in images: images[serial] = lib.image_from_record(g['pack'], g['row']).convert('RGBA')
                placements.append((0 if layer == 0 or g['ground'] else 1, 11*y-9*x-min(g['east'], g['south'])*10,
                                   (x+y)*32+g['x'], (y-x)*24+g['y'], serial))
    x0 = min(p[2] for p in placements); y0 = min(p[3] for p in placements)
    x1 = max(p[2]+images[p[4]].width for p in placements); y1 = max(p[3]+images[p[4]].height for p in placements)
    ratio = 1800 / max(x1-x0, y1-y0)
    canvas = Image.new('RGBA', (round((x1-x0)*ratio), round((y1-y0)*ratio)), '#252e34')
    scaled = {key: image.resize((max(1, round(image.width*ratio)), max(1, round(image.height*ratio))), Image.Resampling.LANCZOS) for key, image in images.items()}
    for _, _, x, y, serial in sorted(placements): canvas.alpha_composite(scaled[serial], (round((x-x0)*ratio), round((y-y0)*ratio)))
    draw = ImageDraw.Draw(canvas)
    corners = [(529, 20), (629, 20), (629, 120), (529, 120), (529, 20)]
    draw.line([(round(((x+y)*32-x0)*ratio), round(((y-x)*24-y0)*ratio)) for x, y in corners], fill='#70caff', width=4)
    draw.text((8, 8), 'Untouched native source100 layers; blue: existing runtime village overlay footprint', fill='white')
    canvas.convert('RGB').save(AUDIT / 'north-overlay-native-layers.png')
    print('EAST_NORTH_OVERLAY_PROOF', len(displaced), 'source100 cliffs displaced;', walkable, 'native field walk cells in overlay; no runtime changes')


if __name__ == '__main__':
    main()
