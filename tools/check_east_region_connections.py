"""Check fixed-map route approaches against prepared native navigation, retaining gated component edges."""
import base64
import json
import math
import zlib
from array import array
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'


def components(bits, width, height, cells):
    labels = array('i', [-1]) * (width*height)
    sizes = []; resolved = {}
    def opened(x, y):
        return 0 <= x < width and 0 <= y < height and bits[(y*width+x)>>3] & (1 << ((y*width+x)&7))
    for key, cell in cells.items():
        x, y = cell
        near = [(dx*dx+dy*dy, y+dy, x+dx) for dy in range(-2,3) for dx in range(-2,3)
                if dx*dx+dy*dy <= 2.1**2 and opened(x+dx,y+dy)]
        if not near:
            resolved[key] = dict(source_cell=cell, usable=False); continue
        distance, yy, xx = min(near); index=yy*width+xx
        if labels[index] < 0:
            ident=len(sizes); labels[index]=ident; pending=deque([index]); size=0
            while pending:
                at=pending.popleft(); size+=1; cx,cy=at%width,at//width
                for nx,ny in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]:
                    ni=ny*width+nx
                    if opened(nx,ny) and labels[ni] < 0:
                        labels[ni]=ident; pending.append(ni)
            sizes.append(size)
        resolved[key]=dict(source_cell=cell, approach=[xx,yy], distance_tiles=math.sqrt(distance), usable=True, component=labels[index])
    return resolved, sizes


def main():
    route=json.loads((ROOT/'assets/maps/falan/east_region/routes.json').read_text())
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())['maps']
    specs=json.loads((REPORT/'dungeon-specs.json').read_text())['specs']
    points=defaultdict(dict); edges=[]
    def add(source,cell,key):
        if source in [100,1000,1522,1530,1541,59702,59721] or cell is None:return None
        token=f'{key}:{cell[0]},{cell[1]}'; points[source][token]=list(cell); return [source,token]
    for i,row in enumerate(route['fixed']):
        source,x,y,target,tx,ty=row
        edges.append(dict(kind='fixed',source=add(source,[x,y],f'fixed{i}:from'),target=add(target,[tx,ty],f'fixed{i}:to'),raw=row))
    for i,row in enumerate(route['event_links']+route['inline_warps']):
        edges.append(dict(kind=row['kind'],actor=row.get('actor'),script=row.get('script'),line=row.get('line'),
            source=add(row['source'],row.get('cell'),f'event{i}:from'),target=add(row['target'],row.get('landing'),f'event{i}:to')))
    for key,spec in specs.items():
        end=spec['end']; source=spec['entry'][0]; rect=spec['entry_rect']
        for y in range(min(rect[1],rect[3]),max(rect[1],rect[3])+1):
            for x in range(min(rect[0],rect[2]),max(rect[0],rect[2])+1):
                add(source,[x,y],f'{key}:entry')
        if end:add(end[0],end[1:3],f'{key}:endpoint')
    maps=[]; index={}; blockers=[]
    for source in route['fixed_maps']:
        row=catalog['BlueCrossgate/map/0/'+str(source)+'.dat'];w,h=row['size'];bits=zlib.decompress(base64.b64decode(row['walk']))
        resolved,sizes=components(bits,w,h,points[source]);index[source]=resolved
        unusable=[dict(key=k,**v) for k,v in resolved.items() if not v['usable']]
        if unusable:blockers.append(dict(kind='source_approach',map=source,cells=unusable))
        maps.append(dict(source=source,title=row['title'],size=[w,h],runtime_owner='existing native owner' if row.get('east_existing_owner') else 'original map owner',
            native_route_component_sizes=sizes,route_points=resolved,all_approaches_share_component=len(sizes)<=1,
            status='source nav checked; existing owner needs runtime fixture' if row.get('east_existing_owner') else 'native route components checked'))
    connections=[]
    for edge in edges:
        endpoints=[]
        for side in ['source','target']:
            ref=edge[side];p=index.get(ref[0],{}).get(ref[1],{}) if ref else {}
            endpoints.append([ref[0],p['component']] if ref and p.get('usable') else None)
        connections.append(dict(edge,component_source=endpoints[0],component_target=endpoints[1],gated=edge['kind']!='fixed'))
    result=dict(maps=maps,component_connections=connections,blockers=blockers,
        limits=['Components use the prepared native navigation graph, not rendered3D collision. Legacy Il/Alyut/Habaru/Woodcutter owners have separate runtime fixtures.',
                'Source maps may intentionally contain disconnected rooms. Gated warp/battle edges retain the connections between components; no physical corridor is invented.',
                'Source-cell interaction and landing approaches allow the existing2.1tile safe-landing tolerance. Unusable source points remain explicit.'])
    (REPORT/'fixed-map-connections.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('EAST_FIXED_COMPONENTS',len(maps),'maps;',sum(len(m['route_points']) for m in maps),'route points;',sum(len(m['native_route_component_sizes'])>1 for m in maps),'maps with separated source components;',len(blockers),'source approach blockers')


if __name__=='__main__':
    assert components(bytes([0b00010111]),3,2,{'a':[0,0],'b':[1,1]})[0]['a']['component']==components(bytes([0b00010111]),3,2,{'a':[0,0],'b':[1,1]})[0]['b']['component']
    main()
