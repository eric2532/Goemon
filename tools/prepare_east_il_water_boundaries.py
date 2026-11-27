"""Private exact original open/blocked-water edges for Il player/source parity."""
import base64
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate'


def main():
    meta = ROOT/'assets/maps/falan/east_region/il_source_completion/data.json'; raw_path = meta.with_name('hybrid-map.bin')
    source = json.loads(meta.read_text()); raw = raw_path.read_bytes(); width, height = source['size']; count = width*height
    values = struct.unpack_from(f'<{count*3}H', raw, 20); bits = base64.b64decode(source['native_walk']['after_bits'])
    def opened(cell):
        x, z = cell
        return 0 <= x < width and 0 <= z < height and bool(bits[(z*width+x) >> 3] & (1 << ((z*width+x) & 7)))
    runs, counts = [], {'unit_edges': 0, 'plain_water_unit_edges': 0, 'object_water_unit_edges': 0}
    for along_x in [True, False]:
        rows, columns = (height, width) if along_x else (width, height)
        for row in range(1, rows):
            flags = []
            for column in range(columns):
                a, b = ((column, row-1), (column, row)) if along_x else ((row-1, column), (row, column))
                if opened(a) == opened(b): flags.append(None); continue
                blocked = b if opened(a) else a; i = blocked[1]*width+blocked[0]
                if values[i] not in range(5000, 5009): flags.append(None); continue
                flags.append((opened(a), values[count+i] == 0))
                counts['unit_edges'] += 1; counts['plain_water_unit_edges' if values[count+i] == 0 else 'object_water_unit_edges'] += 1
            start = 0
            while start < columns:
                if flags[start] is None: start += 1; continue
                end = start+1
                while end < columns and flags[end] == flags[start]: end += 1
                blocked_positive, plain = flags[start]
                runs.append({'along_x': along_x, 'row': row, 'start': start, 'end': end, 'blocked_positive': blocked_positive,
                             'camera_plain_water_eligible': plain, 'source': 2000, 'rule': 'Exactly one original-open side; the other side is original-blocked BG5000..5008. No new source closure.'})
                start = end
    data = {'source': 2000, 'size': [width, height], 'origin': [-135, -180], 'wall_thickness': .12, 'inferred_wall_height': 12.0,
            'runs': runs, 'counts': {**counts, 'batched_runs': len(runs)}, 'source_hashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [meta, raw_path]},
            'scope': 'Private exact-source player boundary trial only. Existing Art.solid/OriginalWaterCamera.record owners are reused. No global player/World changes. Native2D blockage is recovered; invisible12m edge height is inferred3D enforcement.'}
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'water-boundaries.json').write_text(json.dumps(data, indent=2)+'\n')
    print('Private Il blocked-water source edges:', data['counts'])


if __name__ == '__main__': main()
