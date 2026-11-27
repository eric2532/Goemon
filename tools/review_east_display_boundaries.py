#!/usr/bin/env python3
"""Trace saved drawer sightline hits to exact original walk-boundary runs."""
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
CATALOG = ROOT / 'assets/maps/original_crossgate/east/catalog.json'
REVIEW = ARTIFACTS / 'Display Furniture/Near Actual/review.json'


def runs(row):
    width, height = row['size']
    bits = zlib.decompress(base64.b64decode(row['walk']))
    raw = zlib.decompress(base64.b64decode(row.get('restored_raw', row['raw'])))

    def opened(cell):
        x, y = cell
        index = y * width + x
        return 0 <= x < width and 0 <= y < height and bool(bits[index >> 3] & (1 << (index & 7)))

    result = []
    for along_x in (True, False):
        rows, columns = (height, width) if along_x else (width, height)
        for line in range(rows + 1):
            start = None
            for column in range(columns + 1):
                a = (column, line - 1) if along_x else (line - 1, column)
                b = (column, line) if along_x else (line, column)
                edge = column < columns and opened(a) != opened(b)
                if edge and start is None:
                    start = column
                if edge or start is None:
                    continue
                blocked = []
                for segment in range(start, column):
                    a = (segment, line - 1) if along_x else (line - 1, segment)
                    b = (segment, line) if along_x else (line, segment)
                    x, y = b if opened(a) else a
                    cells = width * height
                    values = [struct.unpack_from('<H', raw, 20 + (plane * cells + y * width + x) * 2)[0] for plane in range(3)] if 0 <= x < width and 0 <= y < height else None
                    blocked.append({'cell': [x, y], 'native_bg_pg1_marker': values})
                origin = (-(width // 2) * 3, -(height // 2) * 3)
                center = [origin[0] + ((start + column - 1) * 1.5 if along_x else line * 3 - 1.5), 4.25, origin[1] + (line * 3 - 1.5 if along_x else (start + column - 1) * 1.5)]
                size = [(column - start) * 3, 8.5, .04] if along_x else [.04, 8.5, (column - start) * 3]
                result.append({'along_x': along_x, 'line': line, 'start': start, 'end': column, 'local_center': center, 'local_size': size, 'blocked_source_cells': blocked})
                start = None
    return result


def main():
    catalog = json.loads(CATALOG.read_text())
    review = json.loads(REVIEW.read_text())
    traced = []
    failures = []
    for observation in review['observations']:
        if observation.get('physics_sightline_clear', True):
            continue
        source = 43900 if observation['viewpoint'].startswith('reversed') else 31900
        hit = observation['ray_hit']
        index = int(hit['collider'].rsplit('_', 1)[1])
        run = runs(catalog['maps'][f'BlueCrossgate/map/0/{source}.dat'])[index]
        point = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?', hit['position'].removeprefix('Vector3'))]
        # Both saved reviews use the existing1.3world scale and no rotated map frame.
        inside = all(abs(point[axis] - run['local_center'][axis] * 1.3) <= run['local_size'][axis] * 1.3 * .5 + .002 for axis in range(3))
        if not inside:
            failures.append({'source': source, 'boundary': index, 'reason': 'Saved hit is not inside the independently reconstructed current boundary'})
        traced.append({'source': source, 'viewpoint': observation['viewpoint'], 'angle': observation['angle'], 'boundary': index, 'hit': point, 'hit_in_exact_boundary': inside, **run})
    assert len(traced) == 4, 'Expected exactly the four unresolved drawer sightlines'
    output = ARTIFACTS / 'Display Furniture/boundary-diagnostic.json'
    output.write_text(json.dumps({'traced_hits': traced, 'failures': failures, 'input_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [CATALOG, REVIEW, ROOT / 'scripts/forest/forest_original_maps.gd']}, 'finding': 'The saved rays hit exact generic8.5mwalk-closure proxies. Source BG/PG1/marker cells are recorded without reclassifying them as visible walls. This is diagnosis, not permission to ignore boundaries or change source walking.', 'scope': 'Read-only reconstruction from saved actual captures and current source bytes; no map mutation, camera exemption or new rendered acceptance.'}, ensure_ascii=False, indent=2) + '\n')
    print(f'Traced {len(traced)} exact saved hits; {len(failures)} mismatches. {output}')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
