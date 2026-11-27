"""Private volume payload census against unchanged native cliff placements."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    counts = json.loads((AUDIT / 'cliff-cost-census.json').read_text())
    folder = AUDIT / 'Volume Candidates'
    candidate = json.loads((folder / 'data.json').read_text())
    original = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
    assert sha(original) == counts['source_map100_sha256']
    records = {}
    for key, row in candidate['graphics'].items():
        assert sha(folder / f'{key}.bin') == row['cost']['geometry_sha256']
        source = counts['graphics'][key]
        records[key] = dict(row['cost'], source100_placements=source['all_source100_placements'],
                            owned_source_placements=source['owned_source_placements'])
    areas = {}
    for area, total in counts['owned_source_totals'].items():
        replacements = sum(row['owned_source_placements'][area] for row in records.values())
        areas[area] = {
            'all_twelve_source_placements': total,
            'six_volume_source_placements': replacements,
            'six_sparse_crest_source_placements': total - replacements,
            'six_volume_all_instances_triangle_sum': sum(row['triangles'] * row['owned_source_placements'][area] for row in records.values()),
            'multimesh_transform_payload_bytes': total * 48,
        }
    report = {
        'candidate_sha256': sha(folder / 'data.json'),
        'source_map100_sha256': sha(original),
        'scope': 'Private source-derived six-family candidate. Exact source array payloads are shared once per family, never multiplied by instance count. All-instance triangle sums are theoretical uncullled source placement costs, not visibility, driver memory, frame cost or smoothness evidence.',
        'graphics': records,
        'owned_windows': areas,
        'shared_six_mesh_cpu_attribute_index_bytes': sum(row['resident_cpu_attribute_index_bytes'] for row in records.values()),
        'shared_six_mesh_gpu_upload_attribute_index_bytes': sum(row['gpu_upload_attribute_index_bytes'] for row in records.values()),
        'shared_six_compressed_binary_bytes': sum(row['compressed_geometry_bytes'] for row in records.values()),
        'pending': 'Actual mounted/source anchor reconciliation, individual frustum candidates versus submitted chunks, GPU/CPU/wall frame samples and whole-process memory remain the live fixture responsibility.',
    }
    (folder / 'cost-census.json').write_text(json.dumps(report, indent=2) + '\n')
    print('EAST_PRIVATE_VOLUME_COSTS', report['shared_six_mesh_cpu_attribute_index_bytes'], areas)


if __name__ == '__main__':
    main()
