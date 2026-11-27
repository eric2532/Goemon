"""Reproduce the private isolated low-source terrain proof with loaded input hashes."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

import prepare_east_il_low_source as prepare

ROOT, OUT = prepare.ROOT, prepare.OUT


def main():
    prepare.main()
    paths = [Path(__file__), Path(prepare.__file__), ROOT/'tests/forest-shrine/east_il_low_source_native_probe.cpp',
             OUT/'data.json', OUT/'il-low-source-cases.h']
    paths += [ROOT/'native/terrain_math/crowd'/name for name in ['terrain.h', 'terrain.cpp', 'air.cpp', 'math_types.h']]
    manifest = json.loads((OUT/'data.json').read_text())
    paths += [ROOT/name for name in manifest['source_hashes']]
    def snapshot(): return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before = snapshot()
    command = ['clang++', '-std=c++17', '-O2', '-I', str(ROOT/'native/terrain_math/crowd'), '-I', str(OUT),
               str(ROOT/'tests/forest-shrine/east_il_low_source_native_probe.cpp'),
               str(ROOT/'native/terrain_math/crowd/terrain.cpp'), str(ROOT/'native/terrain_math/crowd/air.cpp'), '-o', str(OUT/'native-probe')]
    build = subprocess.run(command, capture_output=True, text=True)
    (OUT/'native-build.log').write_text(build.stdout+build.stderr)
    assert build.returncode == 0, build.stderr
    result = subprocess.run([str(OUT/'native-probe')], capture_output=True, text=True)
    (OUT/'native-probe.log').write_text(result.stdout+result.stderr)
    after = snapshot(); changed = [p for p in before if before[p] != after[p]]
    counters = {key: int(value) for key, value in re.findall(r'(checks|failures|source_open|source_closed|direct_segments|original_closed_boundary_edges|outside_centers|top_open)=(\d+)', result.stdout)}
    report = {'checks': counters.get('checks',0), 'failures': counters.get('failures',1), 'counters': counters,
              'process_exit':result.returncode,'source_hashes':before,'source_changed':changed,'compile_command':command,
              'scope':'PRIVATE standalone current Native Terrain source. Exact original90x120source cells,143directbank/water segments both directions at four actual-world radii, sourceclosed/outside boundary cases. No actual ArmyRuntime/pet/player/context/visual acceptance and no shared migration.'}
    (OUT/'native-proof.json').write_text(json.dumps(report,indent=2)+'\n')
    print(result.stdout.strip());print('Source changes during proof:',changed)
    assert result.returncode == 0 and not changed and counters.get('failures') == 0


if __name__ == '__main__': main()
