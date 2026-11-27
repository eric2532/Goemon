"""Private source-sized low Il manifest and exact native proof inputs; no live hooks."""
import base64
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate'
IL = ROOT/'assets/maps/falan/east_region/il_source_completion'
LAND_HEIGHT, WATER_HEIGHT = 2.10, 2.0


def rectangles(width, height, selected):
    result, active = [], {}
    for z in range(height):
        runs, first = [], None
        for x in range(width+1):
            yes = x < width and selected(z*width+x)
            if yes and first is None: first = x
            if not yes and first is not None: runs.append((first, x)); first = None
        next_active = {}
        for a, b in runs:
            if (a, b) in active: row = active[a, b]; row[3] += 1
            else: row = [a, z, b-a, 1]; result.append(row)
            next_active[a, b] = row
        active = next_active
    return result


def main():
    source = json.loads((IL/'data.json').read_text()); raw = (IL/'hybrid-map.bin').read_bytes()
    width, height = struct.unpack_from('<II', raw, 12); count = width*height
    values = struct.unpack_from(f'<{count*3}H', raw, 20); bits = base64.b64decode(source['native_walk']['after_bits'])
    mask = Image.open(IL/'mask.png').convert('RGBA'); assert mask.size == (width, height) == (90, 120)
    opened = lambda i: bool(bits[i >> 3] & (1 << (i & 7)))
    water = lambda i: values[count+i] == 252
    bank = lambda i: values[count+i] in range(12500, 12536)
    assert sum(opened(i) for i in range(count)) == 2718
    cells = []
    for i in range(count):
        role = 'water_control' if water(i) else 'bank' if bank(i) else 'dry' if values[i] and values[i] not in range(5000, 5009) else 'water_or_void'
        if opened(i): assert role in ('water_control', 'bank', 'dry'), (i, values[i], values[count+i])
        cells.append([i % width, i // width, values[i], values[count+i], values[count*2+i], int(opened(i)), role])
    floors = []
    for kind, high, selected in [('land_bank', LAND_HEIGHT, lambda i: opened(i) and not water(i)), ('water_control', WATER_HEIGHT, lambda i: opened(i) and water(i))]:
        for rect in rectangles(width, height, selected): floors.append({'source_rect': rect, 'height': high, 'kind': kind})
    closed = rectangles(width, height, lambda i: not opened(i))
    contacts = []
    for i in range(count):
        if not water(i) or not opened(i): continue
        x, z = i % width, i // width
        for nx, nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
            if 0 <= nx < width and 0 <= nz < height:
                j = nz*width+nx
                if bank(j) and opened(j): contacts.append({'water_cell': [x,z], 'bank_cell': [nx,nz], 'bank_graphic': values[count+j]})
    assert len(contacts) == 143
    native_width = max(width, height)+2; native_heights = [0.0]*(native_width*native_width); covered = [0]*len(native_heights)
    for z in range(height):
        for x in range(width):
            rgba = mask.getpixel((x,z)); at = (z+1)*native_width+x+1
            if rgba[3] >= 128 and rgba[0] < 128: native_heights[at] = LAND_HEIGHT; covered[at] = 1
    edges = []
    for cell in cells:
        x,z,_,_,_,yes,_ = cell
        if not yes: continue
        for dx,dz in [(-1,0),(1,0),(0,-1),(0,1)]:
            if not (0 <= x+dx < width and 0 <= z+dz < height): edges.append({'source_cell':[x,z], 'outward':[dx,dz]})
    boundary = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/100-2000-original-boundary.json'
    source_paths = [IL/'data.json', IL/'hybrid-map.bin', IL/'mask.png', IL/'ground-index.png', ROOT/'assets/maps/falan/east_region/bank_caps/data.json', boundary]
    data = {'schema':1,'source':2000,'size':[width,height],'source_origin':[-135,-180], 'source_bounds':[-136.5,-181.5,270,360],
            'land_bank_height':LAND_HEIGHT,'water_height':WATER_HEIGHT,'world_scale':1.3,
            'native_width':native_width,'native_origin':[-138,-183], 'native_bounds_min':[-138,-183], 'native_bounds_max':[133.5,178.5],
            'native_route_spacing':3.0,'native_heights':native_heights,'native_covered':covered,'cells':cells,'walk_bits':source['native_walk']['after_bits'],
            'floor_rectangles':floors,'closed_rectangles':closed,'bank_water_contacts':contacts,'outer_open_edges':edges,
            'fixed_boundary_links':json.loads(boundary.read_text())['directed_links'],
            'counts':{'source_cells':count,'original_open':2718,'original_closed':count-2718,'source_open_dry':sum(c[5] and c[6]=='dry' for c in cells),'open_banks':389,'blocked_bank_controls':4,'water_controls':242,'direct_bank_water_edges':143,'support_rectangles':len(floors),'closed_rectangles':len(closed),'open_top_edge_cells':len(edges)},
            'source_hashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths},
            'inferred':['Uniform2.10m land/bank placement and2m water are a private3D translation, not native client heights.','Only original-open source cells receive invisible support floors; no visible bridge/stair or outside land is added.','One void row/column before the original source frame keeps the3m native route grid aligned. The extra query area remains void; visible/physical source bounds are unchanged.'],
            'acceptance_pending':['Exact native all143segments both ways/fourworld radii and all source cells/boundaries.','Native source-axis bank/front likeness at the lowwaterline, actual player/pet/source context, original two transfers/sixhouse/harbor/NPC events.','No shared source/context migration before private proof and Root review.']}
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch();(OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n')
    def ints(row): return '{'+','.join(str(int(v)) for v in row)+'}'
    lines=['#pragma once','#include <array>','#include <vector>',f'constexpr int source_w={width},source_h={height},field_w={native_width};',
           'const std::vector<float> source_heights={'+','.join(str(v)+'f' for v in native_heights)+'};',
           'const std::vector<unsigned char> source_covered={'+','.join(str(v) for v in covered)+'};',
           'const std::vector<std::array<int,6>> source_cells={'+','.join(ints(c[:6]) for c in cells)+'};',
           'struct Floor {std::array<int,4> rect;float height;};',
           'const std::vector<Floor> source_floors={'+','.join('{'+ints(r['source_rect'])+','+str(r['height'])+'f}' for r in floors)+'};',
           'const std::vector<std::array<int,4>> source_closed={'+','.join(ints(r) for r in closed)+'};',
           'const std::vector<std::array<int,4>> source_contacts={'+','.join(ints(r['water_cell']+r['bank_cell']) for r in contacts)+'};']
    (OUT/'il-low-source-cases.h').write_text('\n'.join(lines)+'\n')
    print('Private low Il source manifest:',data['counts'])


if __name__ == '__main__': main()
