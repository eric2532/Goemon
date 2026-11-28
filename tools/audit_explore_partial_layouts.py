"""Compare active partial client snapshots with hash-pinned layouts; publish no geometry."""
import base64
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import struct
import urllib.request
import zlib

from audit_explore_access import CATALOGS, source_layout_complete
from prepare_explore_missing_maps import reference_map

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access'
CACHE = ROOT / 'assets/references/crossgate_sokia/maps/server/completion-review'
COMMIT = 'dd8690ed3df11e4eb5a038a54079a8f40d8e93b3'


def main():
    maps = {}
    for path in CATALOGS:
        data = json.loads((ROOT / path).read_text())
        maps.update({int(row['id']): dict(row, catalog=path)
                     for row in list(data['maps'].values()) + list(data.get('layout_overrides', {}).values())})
    inventory = json.loads((REPORT / 'runtime-inventory.json').read_text())
    active = {int(row['source']) for row in inventory['maps'] if row['runtime_owner']}
    files = {}
    for row in json.loads((REPORT / 'pinned-source-tree.json').read_text())['tree']:
        if row['type'] != 'blob' or '/map/' not in row['path']:
            continue
        match = re.search(r'\d+', Path(row['path']).name)
        if match:
            files.setdefault(int(match[0]), []).append(row)
    wanted = [(ident, row) for ident, row in maps.items() if ident in active and not source_layout_complete(row)]
    CACHE.mkdir(parents=True, exist_ok=True)

    def compare(item):
        ident, row = item
        result = dict(source=ident, title=row.get('title'), catalog=row['catalog'])
        candidates = files.get(ident, [])
        if len(candidates) != 1:
            return dict(result, blocker='No unique pinned original map', candidates=candidates)
        source = candidates[0]; target = CACHE / Path(source['path']).name
        url = f'https://raw.githubusercontent.com/linv2/Crossgate_Docker/{COMMIT}/{source["path"]}'
        payload = target.read_bytes() if target.exists() else urllib.request.urlopen(url, timeout=60).read()
        blob = hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest()
        assert len(payload) == source['size'] and blob == source['sha'], source['path']
        if not target.exists():
            target.write_bytes(payload)
        result['reference'] = dict(file=target.name, source=source['path'], url=url, commit=COMMIT,
                                   git_blob_sha1=blob, sha256=hashlib.sha256(payload).hexdigest())
        raw = zlib.decompress(base64.b64decode(row['raw']))
        assert hashlib.sha256(raw).hexdigest() == row['sha256'], ident
        width, height = struct.unpack_from('<II', raw, 12); cells = width * height
        rw, rh, values, title = reference_map(payload, ident)
        result.update(client_size=[width, height], reference_size=[rw, rh], reference_title=title)
        if (width, height) != (rw, rh):
            return dict(result, blocker='Pinned reference dimensions differ from the preserved original client')
        floor, objects, flags = [struct.unpack_from(f'<{cells}H', raw, 20 + plane * cells * 2) for plane in range(3)]
        known = [i for i in range(cells) if flags[i] & 0xc000]
        differences = [i for i in known if (floor[i], objects[i]) != (values[i], values[cells+i])]
        result.update(recorded=len(known), unrecorded=cells-len(known), differences=len(differences),
                      samples=[dict(cell=[i % width, i // width], client=[floor[i], objects[i]], reference=[values[i], values[cells+i]]) for i in differences[:20]],
                      compatibility='EXACT_RECORDED_TUPLES' if not differences else 'REVIEW_SOURCE_VARIATIONS')
        return result

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(compare, wanted))
    (REPORT / 'partial-layout-compatibility.json').write_text(json.dumps(dict(
        qualification='Read-only comparison. Recorded client tuples and flags are unchanged; no geometry or gate is published by this audit.',
        maps=results), ensure_ascii=False, indent=2) + '\n')
    print('EXPLORE_PARTIAL_LAYOUTS', len(results), 'active snapshots;',
          sum(row.get('compatibility') == 'EXACT_RECORDED_TUPLES' for row in results), 'exact recorded matches;',
          sum('blocker' in row for row in results), 'source/dimension blockers')


if __name__ == '__main__':
    main()
