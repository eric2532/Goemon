"""Read-only exact Il242/entry tuples against the active Source100 overlay."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate'


def main():
    sys.path[:0] = [str(ROOT/'tools'), str(ROOT.parent/'Magic Power/tools')]
    import cg_library as lib
    from build_freyja_destinations import load_map
    from prepare_east_region_maps import navigation_function
    from prepare_sokia_outdoor_source import FREYJA_ACTIVE
    source = FREYJA_ACTIVE/'100.dat'
    width, height, floor, objects, markers = load_map(lib, 100)
    walk = navigation_function(lib)(width, height, floor, objects, lib.serial_index())
    proposal = json.loads((OUT/'data.json').read_text())
    def record(cell):
        x, z = cell; sx, sz = 636+x, 312+z; index = sz*width+sx
        return {'il_cell': cell, 'source100_cell': [sx, sz], 'source100_BG': floor[index],
                'source100_object': objects[index], 'source100_marker': markers[index],
                'source100_attribute_open': bool(walk[index])}
    rows = [record(row['source_cell']) for row in proposal['water_rows']]
    bank = record([58, 34])
    assert (bank['source100_BG'], bank['source100_object'], bank['source100_attribute_open']) == (5000, 12515, True)
    result = {'source100_size': [width, height], 'translation': [636, 312],
              'translation_basis': 'Regions east_gate inverse * east_coast * IL_TO_ROAD; Il local origin[-135,-180]. Tuple comparison does not change runtime ownership.',
              'source_hashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in
                                [source, source.with_name('provenance.json'), ROOT/'assets/maps/falan/east_region/il_source_completion/hybrid-map.bin', ROOT/'scripts/forest/forest_freyja_regions.gd']},
              'controls': rows, 'counts': {'source100_open': sum(row['source100_attribute_open'] for row in rows),
                                         'source100_object_zero': sum(row['source100_object'] == 0 for row in rows)},
              'ramps': [[record(cell) for cell in ramp['source_run_cells']] for ramp in proposal['ramps']],
              'joined_bank_underlay': {'source100': bank, 'Il_tuple': [5000, 12515], 'Il_original_open': True,
                                      'inference': 'Both maps agree on the native wet bank. The inherited6m joined height is a3D owner choice, not a source-byte disagreement. Private candidate cuts only that hidden vertex to0 and supplies the inferred2.10m entry cap; covered/source bytes stay unchanged.'},
              'limits': ['No runtime/source mutation; no all143contact parity or player/native acceptance established by this tuple ledger.',
                         'The two source100 object11098 rows beneath the empty Il dry corridor are retained as a cross-map ownership distinction; actual model preemption/obstacle diagnosis is separate.']}
    (OUT/'source100-water-overlay-diagnosis.json').write_text(json.dumps(result, indent=2)+'\n')
    print('Il242 read-only overlay:', result['counts'], 'joined bank tuple agrees.')


if __name__ == '__main__': main()
