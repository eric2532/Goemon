"""Recover depth for original blue cliff paint without moving original walking ground."""
import argparse
from collections import deque
from functools import lru_cache
import json
import math
import struct
import recover_elsa_island as source

OUT=source.ROOT/'assets/maps/falan/elsa/scenery/terrain'
MASTERS=set(range(300374,300401))|{300402}
STEP=8


def write_prepared(result):
    geometry={key:value for key,value in result.items() if key not in ['map','grid_sha256','walking_sha256','source']}
    raw=json.dumps(geometry,sort_keys=True,separators=(',',':'))+'\n';token=source.sha(raw.encode())
    target=OUT/'templates'/f'{token}.json';target.parent.mkdir(parents=True,exist_ok=True)
    if not target.is_file() or target.read_text()!=raw:target.write_text(raw)
    record={key:result[key] for key in ['map','grid_sha256','walking_sha256','source']}
    record['template']='templates/'+target.name
    (OUT/f'{result["map"]}.json').write_text(json.dumps(record,indent=2)+'\n')


def prepare(ident):
    width,height,planes=source.reference_map(ident)
    records=source.cut_records(ident)
    if not any(serial>=1000 and records[serial-1000][0] in MASTERS for serial in planes[0]):return False
    _,_,labels,_=source.components(ident)
    owned=set(json.loads((source.REPORT/'scope.json').read_text())['rooms'][str(ident)]['components'])
    tiles={};candidates=[]
    for i,serial in enumerate(planes[0]):
        if serial<1000:continue
        art,offset,record=source.cut_image(ident,serial)
        u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
        assert art.size==(64,48) and u%64==v%48==0,(ident,serial,art.size,u,v)
        tiles[(u//64,v//48)]=(art.load(),u,v,record[0])
        if record[0] in MASTERS:candidates.append((i,u,v))
    if not candidates:return

    def pixel(u,v):
        tile=tiles.get((u//64,v//48))
        return tile[0][u-tile[1],v-tile[2]] if tile else (0,0,0,0)

    def walking(u,v):
        x=u/64-v/48;y=u/64+v/48;cx=math.floor(x+.5);cy=math.floor(y+.5)
        for yy in range(max(0,cy-1),min(height,cy+2)):
            for xx in range(max(0,cx-1),min(width,cx+2)):
                if labels[yy*width+xx] in owned and abs(x-xx)<.67 and abs(y-yy)<.67:return True
        return False

    by_column={}
    for (x,y),tile in tiles.items():
        if tile[3] in MASTERS:by_column.setdefault(x,[]).append(y)

    @lru_cache(maxsize=None)
    def column(u):
        # Sample consistently just inside shared tile edges, including the lower alpha rim.
        px=u-1;ys=by_column.get(px//64,[])
        if not ys:return {}
        runs=[];run=[]
        for v in range(min(ys)*48,(max(ys)+1)*48+1,STEP):
            tile=tiles.get((px//64,(v-1)//48));r,g,b,a=pixel(px,v-1)
            if tile and tile[3] in MASTERS and a:
                blue=b>r*1.08 and b>g*1.05;brown=r>25 and r>b*1.25 and r>g*1.1
                run.append((v,blue,brown))
            elif run:runs.append(run);run=[]
        if run:runs.append(run)
        values={}
        for run in runs:
            edge=None;active=False
            for i,(v,blue,brown) in enumerate(run):
                # A later platform can touch the previous cliff's alpha in the
                # original sheet. It starts a new ledge, not a continuation of
                # the first cliff hundreds of pixels above it.
                next_brown=i+1<len(run) and run[i+1][2]
                if brown and (not active or next_brown or walking(u,v)):
                    edge=v;active=False
                elif edge is not None and not active and i+2<len(run) and all(run[j][1] for j in range(i,i+3)):
                    active=True
                if active and v>edge:values[v]=-min(512,v-edge)
        return values

    def depth(u,v):
        r,g,b,a=pixel(u,v)
        if a and r>25 and r>b*1.25 and r>g*1.1 and walking(u,v):return 0
        direct=column(u).get(v)
        if direct is not None:return direct
        r,g,b,a=pixel(u-1,v-1)
        if a and not (b>r*1.08 and b>g*1.05):return 0
        # Alpha padding has no surface height. Connecting its default zero to
        # a deep cliff stretches the last opaque pixels into a diagonal sheet.
        # Continue the adjacent cliff plane through that invisible padding.
        nearby=[]
        for du,dv in [(-STEP,0),(STEP,0),(0,-STEP),(0,STEP)]:
            value=column(u+du).get(v+dv)
            if value is None:continue
            further=column(u+2*du).get(v+2*dv)
            nearby.append(2*value-further if further is not None else value+dv)
        return max(-512,min(0,round(sum(nearby)/len(nearby)))) if nearby else 0

    patches={};walls=set()
    columns=64//STEP+1;rows=48//STEP+1
    for i,u,v in candidates:
        heights=[depth(u+x*STEP,v+y*STEP) for y in range(rows) for x in range(columns)]
        for y in range(rows-1):
            for x in range(columns-1):
                corners=[heights[y*columns+x],heights[y*columns+x+1],heights[(y+1)*columns+x+1],heights[(y+1)*columns+x]]
                ground=False
                for du,dv in [(0,0),(STEP,0),(STEP,STEP),(0,STEP)]:
                    px=u+x*STEP+du;py=v+y*STEP+dv;r,g,b,a=pixel(px,py)
                    if a and r>25 and r>b*1.25 and r>g*1.1 and walking(px,py):ground=True;break
                r,g,b,a=pixel(u+x*STEP+STEP//2,v+y*STEP+STEP//2)
                blue=a and b>r*1.08 and b>g*1.05
                if not ground and (blue or sorted(corners)[1]<-STEP):
                    walls.add((u//STEP+x,v//STEP+y))
        patches[i]=(u,v)

    # Ground and cliff paint are separate surfaces. Interpolating a heightfield
    # between them stretches a few edge pixels across an entire cliff depth.
    # Each connected wall instead has a continuous ledge and vertical sections.
    remaining=set(walls);sections=[];labels={};feet={}
    while remaining:
        start=min(remaining);remaining.remove(start);queue=deque([start]);cells=[];top={}
        while queue:
            x,y=queue.popleft();cells.append((x,y));top[x]=min(top.get(x,y*STEP),y*STEP)
            for other in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if other in remaining:remaining.remove(other);queue.append(other)
        xs=sorted(top)
        for order in [xs,list(reversed(xs))]:
            previous=None
            for x in order:
                if previous is not None:top[x]=min(top[x],top[previous]+2*STEP*abs(x-previous))
                previous=x
        label=len(sections)
        for cell in cells:labels[cell]=label
        for x in xs:
            feet[label,x]=min(top[x],top.get(x-1,top[x]))
            feet[label,x+1]=min(top[x],top.get(x+1,top[x]))
        sections.append(dict(cells=len(cells),bounds=[min(x for x,y in cells)*STEP,min(y for x,y in cells)*STEP,
                                                    (max(x for x,y in cells)+1)*STEP,(max(y for x,y in cells)+1)*STEP]))

    profiles={};placements={}
    for i,(u,v) in patches.items():
        if not any((u//STEP+x,v//STEP+y) in walls for y in range(rows-1) for x in range(columns-1)):continue
        quads=[];roles=[]
        for y in range(rows-1):
            for x in range(columns-1):
                cell=(u//STEP+x,v//STEP+y);label=labels.get(cell)
                if label is None:corners=[0]*4;roles.append(0)
                else:
                    left=feet[label,cell[0]];right=feet[label,cell[0]+1];native_v=v+y*STEP
                    corners=[left-native_v,right-native_v,right-native_v-STEP,left-native_v-STEP];roles.append(1)
                quads.append([x*STEP,y*STEP,STEP,STEP,*corners])
        token=source.sha(json.dumps([quads,roles],separators=(',',':')).encode())
        profiles[token]=dict(quads=quads,roles=roles);placements[str(i)]=token
    OUT.mkdir(parents=True,exist_ok=True)
    result=dict(map=ident,step=STEP,placements=placements,profiles=profiles,sections=sections,
                grid_sha256=source.sha(struct.pack('<'+'H'*len(planes[0]),*planes[0])),
                walking_sha256=source.sha(struct.pack('<'+'H'*len(planes[2]),*planes[2])),
                source='Original top and cliff paint on separate surfaces. Connected cliff sections share continuous ledges and vertical native-pixel spacing. Existing navigation and brown walking ground stay at zero; hidden depth is inferred.')
    write_prepared(result)
    print('ELSA_TERRAIN',ident,len(placements),'cliff patches',len(profiles),'profiles',sum(len(profiles[t]['quads']) for t in placements.values()),'quads')
    return True


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--map',type=int,default=59602);parser.add_argument('--all',action='store_true');args=parser.parse_args()
    if args.all:
        maps=json.loads((source.REPORT/'scope.json').read_text())['maps']
        prepared=[ident for ident in maps if prepare(ident)]
        (OUT/'coverage.json').write_text(json.dumps(dict(maps=prepared,source='Only the scoped maps with the original blue-cliff floor family.'),indent=2)+'\n')
        used={json.loads((OUT/f'{ident}.json').read_text())['template'] for ident in prepared}
        for template in (OUT/'templates').glob('*.json'):
            if 'templates/'+template.name not in used:template.unlink()
        print('ELSA_TERRAIN_COVERAGE',len(prepared),'scoped maps')
    else:prepare(args.map)
