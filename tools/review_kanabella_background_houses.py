"""Read-only exact native Kanabella tiled-house/door/translation ledger."""
from collections import defaultdict
import hashlib,json
from review_east_backgrounds import decode,ROOT,OUT,CATALOG

def run():
    catalog=json.loads(CATALOG.read_text());graph=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/graph.json';links=json.loads(graph.read_text())['links'];maps={}
    for mid in [33500,33000,33298]:
        row=catalog['maps'][f'BlueCrossgate/map/0/{mid}.dat'];w,h,raw,values,bits,aliases=decode(row);n=w*h
        cells={ (i%w,i//w):int(serial) for i,serial in enumerate(values[:n]) if 20276<=serial<=20584 }
        pending=set(cells);groups=[]
        while pending:
            start=pending.pop();todo=[start];members=[start]
            while todo:
                x,y=todo.pop()
                for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if p in pending:pending.remove(p);members.append(p);todo.append(p)
            left=min(x for x,y in members);top=min(y for x,y in members);right=max(x for x,y in members);bottom=max(y for x,y in members)
            tuples=sorted([x-left,y-top,cells[x,y]] for x,y in members);shape=hashlib.sha256(json.dumps(tuples,separators=(',',':')).encode()).hexdigest()
            near=[]
            for link in links:
                if link.get('source')==mid:
                    p=link.get('cell',[-999,-999]);kind='entrance'
                elif link.get('target')==mid:
                    p=link.get('landing',[-999,-999]);kind='return landing'
                else:continue
                if left-2<=p[0]<=right+2 and top-2<=p[1]<=bottom+2:near.append(dict(direction=kind,route=link))
            pg1=[]
            for yy in range(max(0,top-1),min(h,bottom+2)):
                for xx in range(max(0,left-1),min(w,right+2)):
                    serial=int(values[n+yy*w+xx])
                    if serial>=1000:pg1.append(dict(cell=[xx,yy],native_graphic=serial,graphic=aliases.get(serial,serial)))
            groups.append(dict(bounds=[left,top,right-left+1,bottom-top+1],tile_count=len(members),canonical_native_tuple_sha256=shape,
                tiles=[dict(cell=[x,y],native_graphic=cells[x,y],graphic=aliases.get(cells[x,y],cells[x,y]),original_open=bool(bits[(y*w+x)>>3]&(1<<((y*w+x)&7)))) for x,y in sorted(members,key=lambda p:(p[1],p[0]))],nearby_directed_entrances_and_returns=near,nearby_pg1=pg1,
                status='Native picture confirms the family contains complete house roofs/walls/doors/stairs. Components preserve associated grass/background portions too; do not extrude every tile or remove those pixels wholesale.'))
        maps[str(mid)]=dict(title=row['title'],size=[w,h],source_raw_sha256=hashlib.sha256(raw).hexdigest(),family_tiles=len(cells),groups=sorted(groups,key=lambda r:(r['bounds'][1],r['bounds'][0])),cells=cells)
    base=maps['33500']['cells'];proofs=[]
    for mid in [33000,33298]:
        target=maps[str(mid)]['cells'];offset=(614,257);matching=sum(target.get((x+offset[0],y+offset[1]))==serial for (x,y),serial in base.items());extra=[dict(cell=list(p),native_graphic=s) for p,s in target.items() if (p[0]-offset[0],p[1]-offset[1]) not in base]
        mismatches=[dict(source_cell=[x,y],target_cell=[x+offset[0],y+offset[1]],source_native_graphic=serial,target_native_graphic=target.get((x+offset[0],y+offset[1]))) for (x,y),serial in base.items() if target.get((x+offset[0],y+offset[1]))!=serial]
        proofs.append(dict(source=33500,target=mid,cell_translation=list(offset),matching_native_house_tiles=matching,source_house_tiles=len(base),exact_translation=matching==len(base),native_tuple_mismatches=mismatches,target_extra_family_tiles=extra))
    for row in maps.values():del row['cells']
    data=dict(scope='Read-only exact BG house-family ledger; source pixels/planes/navigation/events unchanged. Native range identifies this inspected art family, not arbitrary blocked cells.',catalog_sha256=hashlib.sha256(CATALOG.read_bytes()).hexdigest(),graph_sha256=hashlib.sha256(graph.read_bytes()).hexdigest(),source_native_family=[20276,20584],maps=maps,translation_proofs=proofs,native_references=['33500-native-house-33501-layers.jpg','33500-native-house-33510-layers.jpg','native-bg-39.png','native-bg-40.png','native-bg-41.png'],whole_master_comparison=dict(reference='existing-prepared-house-masters.jpg',count=38,result='No complete source-shape match among these prepared house masters; curved roof/wall/stair parts remain reusable. Unused library assets were not exhaustively excluded.'))
    (OUT/'kanabella-house-compounds.json').write_text(json.dumps(data,indent=2));print('Kanabella',[(m,r['family_tiles'],len(r['groups'])) for m,r in maps.items()],'translation',[(r['target'],r['exact_translation']) for r in proofs])
if __name__=='__main__':run()
