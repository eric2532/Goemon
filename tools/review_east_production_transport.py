"""Independent read-only CGPROD framing/array-stride peer check; no replay writes."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
R = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
BASE = R / 'Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage'
OUT = R / 'Runtime Audit/Source100 Transport Peer Review'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inspect(data):
    """Use byte offsets directly, independent of the proposed readers/packer."""
    assert data[:8] in [b'CGPROD01', b'CGPROD02']
    version = data[7] - ord('0')
    assert struct.unpack_from('<I', data, 8)[0] in [0, 1]
    position, blocks = 12, []
    for name in ['new', 'old']:
        header = data[position:position + 48]
        assert len(header) == 48
        width = int.from_bytes(header[:4], 'little')
        position += 48
        count = 5 if version == 2 else 4
        counts = struct.unpack_from('<' + 'I' * count, data, position)
        position += 4 * count
        lengths = [counts[0] * 4, counts[1], counts[2] * 4, counts[3] * 12, counts[3] * 12]
        arrays = {}
        for key, length in zip(['heights', 'covered', 'pieces', 'obstacle_min', 'obstacle_max'], lengths):
            assert position + length <= len(data)
            arrays[key] = data[position:position + length]
            position += length
        length = counts[4] if version == 2 else 0
        assert position + length <= len(data)
        mask = data[position:position + length]; position += length
        if mask:
            assert width >= 2 and length == width * width and max(mask) <= 1
            assert not any(mask[(width - 1) * width:]) and not any(mask[width - 1::width])
        arrays['diagonal_flips'] = mask
        blocks.append({'name': name, 'header': header, 'arrays': arrays})
    cells = int.from_bytes(data[position:position + 4], 'little'); position += 4
    assert position + cells * 24 == len(data)
    return {'version': version, 'blocks': blocks, 'cell_bytes': data[position:], 'cell_count': cells}


def main():
    proof_path = BASE / 'CGPROD02/transport-proof.json'
    proof = json.loads(proof_path.read_text())
    assert proof['failures'] == 0 and not proof['source_changed']
    rows, checks, pins = [], 0, {str(proof_path.relative_to(ROOT)): sha(proof_path), str(Path(__file__).relative_to(ROOT)): sha(Path(__file__))}
    for area in ['east_gate', 'north_coast']:
        original = BASE / ('Production Replay02/production-' + area + '-current-scope.bin')
        data = original.read_bytes(); decoded = inspect(data); assert decoded['version'] == 1
        assert not any(b['arrays']['diagonal_flips'] for b in decoded['blocks']); checks += 2
        for label in ['legacy-' + area, 'legacy02-' + area]:
            file = BASE / ('CGPROD02/' + label + '.bin'); back = BASE / ('CGPROD02/' + label + '-roundtrip.bin')
            assert file.read_bytes() == back.read_bytes(); checks += 1
            now = inspect(file.read_bytes())
            assert now['cell_bytes'] == decoded['cell_bytes']; checks += 1
            for a, b in zip(now['blocks'], decoded['blocks']):
                assert a['header'] == b['header'] and a['arrays'] == b['arrays']; checks += 1
            pins[str(file.relative_to(ROOT))] = sha(file); pins[str(back.relative_to(ROOT))] = sha(back)
        pins[str(original.relative_to(ROOT))] = sha(original)
        rows.append({'area': area, 'frozen01_bytes': len(data), 'source_cells': decoded['cell_count'], 'version1_and2_common_scalar_array_cell_bytes_preserved': True})
    actual = BASE / 'CGPROD02/actual-mask02.bin'; decoded = inspect(actual.read_bytes()); assert decoded['version'] == 2
    assert decoded['blocks'][0]['arrays']['diagonal_flips'] == bytes([1, 0, 0, 0, 0, 0, 0, 0, 0])
    assert decoded['blocks'][1]['arrays']['diagonal_flips'] == b''; checks += 3
    contract_path = BASE / 'CGPROD02/export-contract.json'; export = json.loads(contract_path.read_text())
    assert export['failures'] == 0 and not export['source_changed']; checks += 1
    for block in decoded['blocks']:
        for key, row in export['records'][block['name']]['arrays'].items():
            path = ROOT / row['path'].removeprefix('res://'); raw = path.read_bytes()
            assert sha(path) == row['sha256'] and len(raw) == row['bytes'] and raw == block['arrays'][key]; checks += 1
            pins[str(path.relative_to(ROOT))] = sha(path)
    assert actual.read_bytes() == (BASE / 'CGPROD02/actual-mask02-roundtrip.bin').read_bytes(); checks += 1
    pins[str(actual.relative_to(ROOT))] = sha(actual); pins[str(contract_path.relative_to(ROOT))] = sha(contract_path)
    # Verify only the excluded transport sources during the shared-library window.
    for path in ['replay_production.py', 'exact_byte_probe.cpp', 'inspect_common_source_seams.py', 'CGPROD02/test_transport.py']:
        file = BASE / path; key = str(file.relative_to(ROOT)); assert sha(file) == proof['source_hashes'][key]; pins[key] = sha(file); checks += 1
    for path in ['tests/forest-shrine/east_host100_scaling_contract.gd', 'tests/forest-shrine/east_production_transport_test.gd']:
        assert sha(ROOT / path) == proof['source_hashes'][path]; pins[path] = sha(ROOT / path); checks += 1
    result = {'status': 'NO_BLOCKING_TRANSPORT_FINDINGS', 'independent_checks': checks, 'failures': 0, 'method': 'Independent little-endian offset/stride parser; no import or execution of candidate packer/reader, no shared files or library touched.', 'layouts': {'prefix': '8magic +4area', 'nav_scalar_header_bytes': 48, 'nav_count_words_v1': 4, 'nav_count_words_v2': 5, 'array_order': ['heightsF32', 'coveredU8', 'piecesF32', 'obstacle_minVec3F32', 'obstacle_maxVec3F32', 'optional_diagonal_flipsU8'], 'cell_record_bytes': 24}, 'legacy': rows, 'actual_raw_mask_hex': decoded['blocks'][0]['arrays']['diagonal_flips'].hex(), 'review_findings': ['CGPROD02 appends raw orientation bytes after the existing five array blocks; it does not transpose or rescale them.', 'CGPROD01 has no fifth count and implies an empty mask; the packer rejects a nonempty mask under01 rather than silently losing it.', 'Both readers reject unsupported magic/area, truncated/trailing input, invalid mask shape/value/border; candidate producer separately tests8malformed cases.', 'C++ explicitly checks Vec3 stride12 and cell stride24. Python stores height/piece floats and vector bytes unchanged, with little-endian scalar header recreation from exact finite exportedF32 values.', 'Actual Army export is already normalized to optional nonempty PackedByteArray; the exporter stores byte masks directly and does not multiply them by world scale.'], 'source_hashes': pins, 'source_changed': [p for p, h in pins.items() if sha(ROOT / p) != h], 'limits': ['The producer reports74transport and14canonical-export checks; those are not independently rerun here.', 'No shared seven-file/library read or rebuild during its reserved window; their producer-pinned hashes remain separate evidence.', 'No new Host field product, common-height solution, old failure-resolution claim, source route, player/pet or rendered acceptance follows from byte fidelity.']}
    assert not result['source_changed']
    OUT.mkdir(parents=True, exist_ok=True); (OUT / 'review.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Independent CGPROD01/02 peer checks:', checks, 'PASS; no shared/native/library mutation.')


if __name__ == '__main__':
    main()
