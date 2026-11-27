"""Fit private carved profiles to original alpha outlines; hidden depth stays inferred."""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region/carved_pier_study/inferred-profiles.json'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Profile Measurements'
ROWS = [[1.40, 0, 1.40], [1.40, .18, 1.40], [1.25, .30, 1.25],
        [1.18, .47, 1.18], [.94, .65, .94], [.94, .90, .94],
        [1.02, 1.4, 1.02], [1.12, 2.1, 1.12], [1.12, 2.8, 1.12],
        [1.12, 3.4, 1.12], [1.12, 4.1, 1.12], [1.12, 4.8, 1.12],
        [1.12, 5.7, 1.12], [1.13, 6.1, 1.13], [1.27, 6.3, 1.27],
        [1.40, 6.42, 1.40], [1.40, 6.70, 1.40]]


def ring(row):
    x, y, z = row
    return [(-x, y, -z + .2), (-x, y, z - .2), (-x + .2, y, z),
            (x - .2, y, z), (x, y, z - .2), (x, y, -z + .2),
            (x - .2, y, -z), (-x + .2, y, -z)]


def outline(rows, bounds, sample_rows):
    # Same source-camera calibration as the existing fitted profile. Fixed cap
    # and foot extrema set its width/height; no new runtime fitting is introduced.
    width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
    cap_extent = 2 * 1.4 - .2  # The existing octagonal ring's corner bevel.
    scale = width / (2 * cap_extent * (32 / 3))
    vertical = (height - 2 * cap_extent * 8 * scale) / 6.7
    shift_x = (bounds[0] + bounds[2]) * .5
    shift_y = bounds[1] + cap_extent * 8 * scale + 6.7 * vertical
    points = [[((x + z) * (32 / 3) * scale + shift_x,
                (z - x) * 8 * scale - y * vertical + shift_y)
               for x, y, z in ring(row)] for row in rows]
    edges = []
    for level, current in enumerate(points):
        for i in range(8):
            edges.append((current[i], current[(i + 1) % 8]))
            if level:
                edges.append((points[level - 1][i], current[i]))
                edges.append((points[level - 1][i], current[(i + 1) % 8]))
    result = []
    for y in sample_rows:
        hits = []
        for (x0, y0), (x1, y1) in edges:
            if (y0 <= y < y1) or (y1 <= y < y0):
                hits.append(x0 + (x1 - x0) * ((y - y0) / (y1 - y0)))
        result.append((min(hits), max(hits)) if hits else (0., 0.))
    return result


def fit(image, bounds):
    samples, targets = [], []
    for y in range(bounds[1] + 2, bounds[3] - 2, 3):
        xs = [x for x in range(image.width) if image.getpixel((x, y))[3] >= 128]
        if xs:
            samples.append(y + .5)
            targets.append((min(xs), max(xs) + 1))
    rows = [row.copy() for row in ROWS]

    def score(candidate, penalty=True):
        if any(x < .65 or z < .65 or x + z > 2.8 + 1e-8 for x, _, z in candidate):
            return math.inf
        actual = outline(candidate, bounds, samples)
        error = sum((a - c) ** 2 + (b - d) ** 2
                    for (a, b), (c, d) in zip(actual, targets)) / (2 * len(samples))
        if penalty:
            error += .06 * sum((candidate[i][j] - ROWS[i][j]) ** 2
                               for i in range(3, 14) for j in (0, 2))
        return error

    before = score(rows, False)
    for step in (.16, .08, .04, .02, .01):
        for _ in range(3):
            changed = False
            for i in range(3, 14):
                for component in (0, 2):
                    current = rows[i][component]
                    best, choice = score(rows), current
                    for shift in (-step, step):
                        rows[i][component] = current + shift
                        value = score(rows)
                        if value < best:
                            best, choice = value, current + shift
                    rows[i][component] = choice
                    changed |= choice != current
            if not changed:
                break
    return rows, dict(samples=len(samples), baseline_rms_pixels=math.sqrt(before),
                      candidate_rms_pixels=math.sqrt(score(rows, False)),
                      source_rows=list(zip(samples, targets)),
                      proposed_rows=list(zip(samples, outline(rows, bounds, samples))))


def main():
    catalog_path = ROOT / 'assets/maps/original_crossgate/east/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    measures = json.loads((ROOT / 'assets/maps/falan/east_region/mouse_room_piers/data.json').read_text())
    graphics, reports = {}, {}
    pages = {}
    for serial in (1230051, 1230052, 1230054, 1230055):
        key = str(serial)
        g, measured = catalog['graphics'][key], measures['graphics'][key]
        if g['page'] not in pages:
            pages[g['page']] = Image.open(ROOT / 'assets/maps/original_crossgate' / catalog['pages'][g['page']]).convert('RGBA')
        x, y, w, h = g['rect']
        image = pages[g['page']].crop((x, y, x + w, y + h))
        assert hashlib.sha256(image.tobytes()).hexdigest() == measured['source_rgba_sha256']
        rows, report = fit(image, measured['bounds'])
        graphics[key] = dict(rows=rows, source_rgba_sha256=measured['source_rgba_sha256'])
        reports[key] = report
        print(serial, 'outline RMS', round(report['baseline_rms_pixels'], 3),
              '->', round(report['candidate_rms_pixels'], 3), flush=True)
    graphics['1230056'] = dict(rows=ROWS, source_rgba_sha256=measures['graphics']['1230056']['source_rgba_sha256'])
    result = dict(scope='Private inferred3Dprofiles from unchanged native alpha outlines. '
                  'The51proposal is not used by its published master.56retains the straight infill form.',
                  source_catalog_sha256=hashlib.sha256(catalog_path.read_bytes()).hexdigest(), graphics=graphics)
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / 'outline-fit.json').write_text(json.dumps(reports, indent=2) + '\n')


if __name__ == '__main__':
    main()
