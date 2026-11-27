"""Isolated current-Native proof of the private source100 host shore grade."""
from collections import defaultdict
import hashlib
import json
from math import ceil, floor, sqrt
from pathlib import Path
import re
import subprocess
import sys

from prepare_east_il_host_height_plan import FLAT_DRY_RING, GRADE, old_dry_height
from prepare_east_il_low_host import BOUNDS, OUT, ROOT
from prepare_east_il_low_source import rectangles


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    folder = OUT/'Sampler'; folder.mkdir(parents=True,exist_ok=True); (folder/'.gdignore').touch()
    host_path = OUT/'100.dat'; plan_path = OUT/'height-proposal.json'; interfaces_path = OUT/'shore-interface-plan.json'
    w,h,bg,pg,_ = lib.parse_map(host_path.read_bytes())
    walk = navigation_grid(w,h,bg,pg,lib.serial_index())
    plan = json.loads(plan_path.read_text()); interfaces = json.loads(interfaces_path.read_text())
    paths = [Path(__file__),ROOT/'tools/prepare_east_il_host_height_plan.py',ROOT/'tools/prepare_east_il_low_host.py',host_path,plan_path,interfaces_path,
             ROOT/'tests/forest-shrine/east_il_host_height_native_probe.cpp']
    paths += [ROOT/'native/terrain_math/crowd'/name for name in ['terrain.h','terrain.cpp','air.cpp','math_types.h']]
    paths += [ROOT/name for name in plan['source_hashes']]
    def snapshot():return {str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    before = snapshot()
    assert all(before[name] == expected for name,expected in plan['source_hashes'].items()), 'Height proposal source inputs changed; regenerate its measured ledger first'
    wet = [tuple(row['cell']) for row in interfaces['private_connected_shore_rows'] if not row['contextual_owner'].startswith('protected_')]
    buckets = defaultdict(list)
    for x,z in wet:buckets[x//8,z//8].append((x,z))
    def datum(sx,sz):
        old = old_dry_height(sx,sz)
        if 529 <= sx < 629 and 20 <= sz < 120:return old
        bx,bz = floor(sx/8),floor(sz/8); distance2 = float('inf')
        for dz in range(-2,3):
            for dx in range(-2,3):
                for x,z in buckets.get((bx+dx,bz+dz),[]):distance2=min(distance2,(sx-x)**2+(sz-z)**2)
        return min(old,2.10+max(0.,sqrt(distance2)*3.-FLAT_DRY_RING)*GRADE)
    # The small probe retains actual East Gate world coordinates/quarter turn.
    x0,z0,sx,sz = BOUNDS; low_x,low_z = x0-3,z0-3; high_x,high_z = x0+sx+3,z0+sz+3
    columns,rows = high_z-low_z,high_x-low_x
    field_width = max(columns,rows)*2+3
    origin_x,origin_z = 591.-(high_z-1)*3.-3.,low_x*3.-1251.-3.
    domain = lambda x,z: low_x <= x < high_x and low_z <= z < high_z and 0 <= x < w and 0 <= z < h
    field,coverage = [],[]
    for iz in range(field_width):
        for ix in range(field_width):
            local_x,local_z = origin_x+ix*1.5,origin_z+iz*1.5
            source_x,source_z = (local_z+1251.)/3.,(591.-local_x)/3.
            candidates = []
            for z in range(ceil(source_z-.500001),floor(source_z+.500001)+1):
                for x in range(ceil(source_x-.500001),floor(source_x+.500001)+1):
                    if not domain(x,z) or not walk[z*w+x]:continue
                    serial=pg[z*w+x]
                    # Original open-water controls keep flat2m explicit support;
                    # do not interpolate a grass cap into their visible water.
                    if serial==252:continue
                    candidates.append(2.10 if 12500 <= serial < 12536 else datum(source_x,source_z))
            coverage.append(int(bool(candidates)));field.append(max(candidates) if candidates else 0.)
    cell_rows = []
    for z in range(low_z,high_z):
        for x in range(low_x,high_x):
            i=z*w+x; high=2.10 if 12500 <= pg[i] < 12536 else 2. if pg[i]==252 else datum(x,z)
            cell_rows.append((x,z,pg[i],int(walk[i]),high))
    blocks = rectangles(high_x-low_x,high_z-low_z,lambda i:not walk[(i//(high_x-low_x)+low_z)*w+i%(high_x-low_x)+low_x])
    blocks = [[r[0]+low_x,r[1]+low_z,r[2],r[3]] for r in blocks]
    water = rectangles(high_x-low_x,high_z-low_z,lambda i:bool(walk[(i//(high_x-low_x)+low_z)*w+i%(high_x-low_x)+low_x]) and pg[(i//(high_x-low_x)+low_z)*w+i%(high_x-low_x)+low_x]==252)
    water = [[r[0]+low_x,r[1]+low_z,r[2],r[3]] for r in water]
    def number(value):return repr(round(float(value),8))+'f'
    def integers(row):return '{'+','.join(str(int(v)) for v in row)+'}'
    lines = ['#pragma once','#include <array>','#include <vector>',
             f'constexpr int field_w={field_width};',f'constexpr float field_x={number(origin_x)},field_z={number(origin_z)};',
             'const std::vector<float> source_heights={'+','.join(number(v) for v in field)+'};',
             'const std::vector<unsigned char> source_covered={'+','.join(str(v) for v in coverage)+'};',
             'struct Cell {int x,z,serial,opened;float high;};',
             'const std::vector<Cell> source_cells={'+','.join('{'+','.join(str(int(v)) for v in row[:4])+','+number(row[4])+'}' for row in cell_rows)+'};',
             'const std::vector<std::array<int,4>> source_closed={'+','.join(integers(row) for row in blocks)+'};',
             'const std::vector<std::array<int,4>> source_water={'+','.join(integers(row) for row in water)+'};',
             'const std::vector<std::array<int,4>> source_interfaces={'+','.join(integers(row['inside_cell']+row['outside_cell']) for row in plan['host_interface_edges'])+'};']
    cases = folder/'host-height-cases.h'; cases.write_text('\n'.join(lines)+'\n')
    sampler = {'width':field_width,'spacing':1.5,'route_spacing':3.,'origin':[origin_x,origin_z],'heights':field,'covered':coverage,
               'source_bounds':[low_x,low_z,high_x-low_x,high_z-low_z],'source_cells':cell_rows,'source_closed':blocks,'source_water':water,
               'interfaces':[row['inside_cell']+row['outside_cell'] for row in plan['host_interface_edges']],
               'physical_frame':'Source100 East Gate local(591−sourceZ*3,sourceX*3−1251); worldscale1.3.',
               'source_hashes':before}
    sampler_path = folder/'sampler-data.json'; sampler_path.write_text(json.dumps(sampler)+'\n')
    before[str(cases.relative_to(ROOT))]=hashlib.sha256(cases.read_bytes()).hexdigest(); paths.append(cases)
    before[str(sampler_path.relative_to(ROOT))]=hashlib.sha256(sampler_path.read_bytes()).hexdigest(); paths.append(sampler_path)
    command = ['clang++','-std=c++17','-O2','-I',str(ROOT/'native/terrain_math/crowd'),'-I',str(folder),
               str(ROOT/'tests/forest-shrine/east_il_host_height_native_probe.cpp'),str(ROOT/'native/terrain_math/crowd/terrain.cpp'),str(ROOT/'native/terrain_math/crowd/air.cpp'),'-o',str(folder/'native-probe')]
    build = subprocess.run(command,capture_output=True,text=True); (folder/'build.log').write_text(build.stdout+build.stderr)
    assert build.returncode==0,build.stderr
    result = subprocess.run([str(folder/'native-probe')],capture_output=True,text=True); (folder/'native-proof.log').write_text(result.stdout+result.stderr)
    after = snapshot(); changed = [path for path in before if before[path]!=after[path]]
    counters = {key:int(value) for key,value in re.findall(r'(checks|failures|source_open|source_closed|interface_segments|boundary_edges|open_segments|padding_touch_clear|padding_touch_count)=(\d+)',result.stdout)}
    report = {'checks':counters.get('checks',0),'failures':counters.get('failures',1),'counters':counters,'process_exit':result.returncode,
              'source_changed':changed,'source_hashes':before,'compile_command':command,'field_width':field_width,'height_samples':len(field),'source_cells':len(cell_rows),'source_closed_rectangles':len(blocks),'source_water_rectangles':len(water),
              'scope':'PRIVATE standalone current Native Terrain. Actual East Gate quarter-turn/translation/FALAN_SCALE1.3. Source100host window plus3nativecell probe collar; all77host interfaces both ways/fourradii and exactsource-open/closed clearance. No actualArmy/Kai/player/pet, whole2559coast, sourcevisual or shared migration acceptance.',
              'inferred':'Private1.5m derived height grid,3moriginalroute spacing,2mwater floors/2.10mbank lips, source-open dry1:5inland grade; no raw/sourceflag edit or extra land/route.',
              'limits':['The probe coverage derives solely from original-open source cells; exactclosed AABBs preserve blocked neighbors. It is not a proof of preserving the canonical3mfield outside the private candidate.',
                        'The actual terrain/physics mesh and mask/PG1/context owners are not installed. FullAlyut remains protected and other21coast components are unfinished.']}
    (folder/'native-proof.json').write_text(json.dumps(report,indent=2)+'\n')
    print(result.stdout.strip()); print('Source changes:',changed)
    assert result.returncode==0 and not changed and counters.get('failures')==0


if __name__ == '__main__':main()
