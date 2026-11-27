"""Native proof of the private composite, with immutable canonical comparisons."""
from array import array
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zlib

from prepare_east_host100_fields import BASE, OUT, ROOT, RESTORE, digest, source_point, within_mask


def decoded(row, key, kind):
    blob = row[key]
    raw = zlib.decompress(base64.b64decode(blob['deflate']))
    assert len(raw) == blob['raw_bytes']
    return array('f', raw) if kind == 'float' else raw


def main():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    manifest = json.loads((OUT / 'manifest.json').read_text())
    restore = json.loads((RESTORE / 'field100-restore.json').read_text())
    raw_path = ROOT / restore['raw_path'].removeprefix('res://')
    w, h, bg, pg, _ = lib.parse_map(raw_path.read_bytes())
    walk = navigation_grid(w, h, bg, pg, lib.serial_index())
    assert digest(raw_path) == manifest['raw_sha256'] == restore['raw_sha256']
    cpp = ROOT / 'tests/forest-shrine/east_host100_field_native_probe.cpp'
    source_paths = [Path(__file__), cpp, ROOT / 'tools/prepare_east_host100_fields.py',
                    ROOT / 'scripts/forest/forest_east_host_source_context.gd',
                    ROOT / 'scripts/forest/forest_east_host_source_field.gd',
                    raw_path, RESTORE / 'field100-restore.json', OUT / 'manifest.json', BASE / 'review.json']
    source_paths += [ROOT / 'native/terrain_math/crowd' / name for name in ['terrain.cpp', 'terrain.h', 'air.cpp', 'math_types.h']]
    for area in manifest['areas']:
        source_paths += [OUT / (area + '-field.json'), BASE / (area + '-field.json'), BASE / (area + '-mask.png')]
    snapshot = lambda: {str(path.relative_to(ROOT)): digest(path) for path in source_paths}
    before = snapshot()
    folder = OUT / 'Native Proof'; folder.mkdir(parents=True, exist_ok=True); (folder / '.gdignore').touch()
    inputs = []
    for area, spec in manifest['areas'].items():
        row = json.loads((OUT / (area + '-field.json')).read_text())
        assert spec['sha256'] == digest(OUT / (area + '-field.json'))
        ref = json.loads((BASE / (area + '-field.json')).read_text())
        old_covered = json.loads(ref['covered']) if isinstance(ref['covered'], str) else ref['covered']
        old_bridges = json.loads(ref['bridges']) if isinstance(ref['bridges'], str) else ref['bridges']
        scope = decoded(row, 'scope_bits', 'byte'); banks = set(row['bank_cells']); shore = set(row['shore_cells'])
        cells = []
        for z in range(h):
            for x in range(w):
                if not within_mask(area, x, z, ref): continue
                # Whole disks must stay within the existing scene envelope.
                px, pz = source_point(area, x, z); b = ref['mask_bounds']
                if not (b[0] + 1.5 <= px < b[0] + b[2] - 1.5 and b[1] + 1.5 <= pz < b[1] + b[3] - 1.5): continue
                i = z * w + x
                ix = round((px - ref['origin'][0]) / 3.); iz = round((pz - ref['origin'][1]) / 3.)
                if min(px-ref['origin'][0],pz-ref['origin'][1],ref['origin'][0]+(ref['width']-1)*3.-px,ref['origin'][1]+(ref['width']-1)*3.-pz)<.60/1.3+.001:continue
                bridge = int(old_bridges[iz * int(ref['width']) + ix])
                role = 1 if i in banks else 2 if i in shore else 3 if pg[i] == 252 else 0
                cells.append((x, z, int(walk[i]), int(bool(scope[i >> 3] & (1 << (i & 7)))), role, bridge))
        path = folder / (area + '-cases.bin')
        with path.open('wb') as output:
            output.write(b'CGHOST01')
            output.write(struct.pack('<7I4f', int(row['width']), int(ref['width']), len(cells), len(row['water_rectangles']), len(row['closed_rectangles']), 1 if area == 'north_coast' else 0, 0,
                                     *row['origin'], row['spacing'], 3.))
            output.write(decoded(row, 'heights', 'float').tobytes()); output.write(decoded(row, 'covered', 'byte'))
            output.write(array('f', ref['heights']).tobytes()); output.write(bytes(old_covered))
            for key in ['water_rectangles', 'closed_rectangles']:
                for rectangle in row[key]: output.write(struct.pack('<4i', *rectangle))
            for cell in cells: output.write(struct.pack('<6i', *cell))
        inputs.append(path)
        source_paths.append(path); before[str(path.relative_to(ROOT))] = digest(path)
    binary = folder / 'native-probe'
    command = ['clang++', '-std=c++17', '-O2', '-I', str(ROOT / 'native/terrain_math/crowd'), str(cpp),
               str(ROOT / 'native/terrain_math/crowd/terrain.cpp'), str(ROOT / 'native/terrain_math/crowd/air.cpp'), '-o', str(binary)]
    compiled = subprocess.run(command, capture_output=True, text=True)
    (folder / 'build.log').write_text(compiled.stdout + compiled.stderr)
    assert compiled.returncode == 0, compiled.stderr
    result = subprocess.run([str(binary), *(str(path) for path in inputs)], capture_output=True, text=True)
    (folder / 'native-proof.log').write_text(result.stdout + result.stderr)
    changed = [path for path, sha in before.items() if digest(ROOT / path) != sha]
    counters = {key: int(value) for key, value in re.findall(r'(checks|failures|shore_cells|shore_segments|open_centers|closed_centers|outside_samples|outside_disks|scoped_segments|shore_unique_cells|shore_unique_edges)=(\d+)', result.stdout.splitlines()[-1])}
    report = {'checks': counters.get('checks', 0), 'failures': counters.get('failures', 1), 'counters': counters,
              'process_exit': result.returncode, 'source_changed': changed, 'source_hashes': before, 'raw_sha256': restore['raw_sha256'],
              'scope': 'PRIVATE composite original100 Native Terrain only. Both actual East/North source frames and scale1.3; source-scoped centers, all represented shore incident edges, and unchanged outside support/height/disk comparison. Existing scenery obstacles/actual Army/player/pet/rendering/context arrival are not installed or accepted.',
              'concrete_owner_ready': False,
              'limits': ['This probe intentionally has only exact prepared source-closed obstacles. Existing model scenery/native friendly obstacles must still be checked in an actual process.',
                         'Legal whole-disk union coverage is technical sampling only. Same-source display-scene handoff at outer Native boundaries and the original East/North crossing remain actual player/pet acceptance requirements.',
                         'Other21 native wet components remain a separate quality/topology checklist; this proof does not accept inferred heights or source art merely because checks pass.']}
    (folder / 'native-proof.json').write_text(json.dumps(report, indent=2) + '\n')
    print(result.stdout.strip()); print(result.stderr[:7000]); print('Source changes:', changed)
    assert result.returncode == 0 and not changed and counters.get('failures') == 0


if __name__ == '__main__': main()
