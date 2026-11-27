"""Snapshot actual OriginalMaps dispatch and instrument only its final box branch."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'


def main():
    inputs = {}

    def read(name):
        data = (ROOT / name).read_bytes()
        inputs[name] = hashlib.sha256(data).hexdigest()
        return data.decode()

    forms = read('scripts/forest/forest_original_map_solids.gd')
    branch = ' else:\n  skin.box(AABB(Vector3(-1.5,0,1.5-d),Vector3(w,height,d)))\n'
    assert forms.count(branch) == 1, 'Review production final-box branch before instrumenting'
    probe = forms.replace(branch, branch + '  var audit_box=skin.finish();audit_box.set_meta("east_unmeasured_final_box",true);return audit_box\n')
    (OUT / 'forms_probe.gd').write_text(probe)
    source = read('scripts/forest/forest_original_maps.gd').splitlines()
    for name in ['scripts/forest/forest_original_map_art.gd', 'scripts/forest/forest_east_region_art.gd',
                 'assets/maps/original_crossgate/east/catalog.json',
                 'assets/maps/falan/east_region/landmarks/profiles.json']:
        read(name)
    helpers = {6:'ruin_sections', 7:'room_columns', 8:'lektal_annexes', 9:'room_furniture', 10:'ground_motifs'}
    groups = []
    for number in range(6, 24):
        hits = [i for i, line in enumerate(source) if f'var key=Vector2i(serial,{number})' in line]
        assert len(hits) == 1, number
        start = hits[0]
        while not source[start].startswith('  if '):
            start -= 1
        condition = source[start].strip()
        ids = set()
        for values in re.findall(r'\bserial in (\[[^\]]+\])', condition):
            ids.update(json.loads(values))
        for values in re.findall(r'\bserial in range\(([^)]+)\)', condition):
            ids.update(range(*map(int, values.split(','))))
        ids.update(map(int, re.findall(r'\bserial==(\d+)', condition)))
        if number in helpers:
            helper = read(f'scripts/forest/forest_east_{helpers[number]}.gd')
            ids.update(json.loads(re.search(r'^const IDS=(\[[^\n]+\])$', helper, re.M)[1]))
        if number == 22:
            helper = read('scripts/forest/forest_east_nature.gd')
            assert 'serial!=11699 and data().graphics.has(str(serial))' in helper
            ids.update(map(int, json.loads(read('assets/maps/falan/east_region/nature/data.json'))['graphics']))
            ids.discard(11699)
        assert ids, (number, condition)
        maps = re.search(r'source_id\(id\) in (\[[^\]]+\])', condition)
        groups.append(dict(group=number, order=hits[0], ids=sorted(ids), condition=condition,
            fixed_only='source_id(id) in EastIndex.FIXED' in condition, maps=json.loads(maps[1]) if maps else [],
            conservative_unresolved_context=number == 14))
    groups.sort(key=lambda group: group['order'])
    profile_line = next(i for i, line in enumerate(source) if 'var key=Vector2i(serial,5)' in line)
    snapshot = dict(schema=1, groups=groups, profile_dispatch_line=profile_line, source_hashes=inputs,
        probe_sha256=hashlib.sha256(probe.encode()).hexdigest(),
        scope='Actual committed groups6–23only. Contextual tree exclusions conservatively unresolved. A live mesh owner is not visual acceptance; private helpers absent from OriginalMaps are excluded.')
    (OUT / 'committed-dispatch.json').write_text(json.dumps(snapshot, indent=2) + '\n')
    print('Prepared current final-box probe and18committed dispatch groups; gameplay source unchanged.')


if __name__ == '__main__':
    main()
