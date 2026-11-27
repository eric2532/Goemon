"""Read-only native stair placements, walk cells and nearby directed transfers."""
from array import array
import base64
import hashlib
import json
from pathlib import Path
import zlib
from prepare_east_nature import sources

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Classic Architecture/stair-source-contracts.json'

def run(only_ids=None,outfile=OUT):
    profile=ROOT/'assets/maps/falan/east_region/classic_architecture/profiles.json'
    definitions=json.loads(profile.read_text())
    initial=next(group['ids'] for group in definitions['groups'] if group['family']=='stairs_and_open_floor_hatches')
    assert len(initial)==32 and len(set(initial))==32
    ids=set(only_ids) if only_ids is not None else set(initial)|set(range(17111,17127));table,_,_=sources()
    catalog_path=ROOT/'assets/maps/original_crossgate/east/catalog.json';catalog=json.loads(catalog_path.read_text())
    routes_path=ROOT/'assets/maps/falan/east_region/routes.json';routes=json.loads(routes_path.read_text());links=[]
    for n,row in enumerate(routes['fixed']):
        links.append(dict(source=row[0],cell=row[1:3],target=row[3],landing=row[4:6],kind='active fixed warp',row=n))
    for key in ['inline_warps','event_links']:
        for row in routes[key]:
            if isinstance(row.get('cell'),list) and isinstance(row.get('landing'),list):links.append(row)
    outgoing={};incoming={}
    for row in links:
        outgoing.setdefault(int(row['source']),[]).append(row);incoming.setdefault(int(row['target']),[]).append(row)
    result=[];maps={};counts={n:0 for n in ids}
    for path,row in catalog['maps'].items():
        mapid=int(path.rsplit('/',1)[1].split('.')[0]);w,h=map(int,row['size']);cells=w*h
        token=row.get('reference_variant_raw') if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
        raw=zlib.decompress(base64.b64decode(token));planes=array('H');planes.frombytes(raw[20:20+cells*4]);bits=zlib.decompress(base64.b64decode(row['walk']))
        assert raw[:4]==b'MAP\x01' and len(raw)==20+cells*6 and len(bits)==(cells+7)//8,mapid
        aliases={int(k):int(v) for k,v in row.get('graphic_aliases',{}).items()}
        native_ids={n for n in ids if n<65536}|{n for n in aliases if aliases[n] in ids}
        def cell_info(cell):
            x,y=cell
            if not (0<=x<w and 0<=y<h):return dict(cell=cell,in_bounds=False,open=False)
            i=y*w+x
            return dict(cell=cell,in_bounds=True,open=bool(bits[i>>3]&(1<<(i&7))),floor=int(planes[i]),object=int(planes[cells+i]))
        for index,native in enumerate(planes):
            if native not in native_ids:continue
            serial=aliases.get(native,native)
            if serial not in ids:continue
            plane,offset=divmod(index,cells);cell=[offset%w,offset//w];g=table[serial][0]
            near=lambda point:max(abs(int(point[0])-cell[0]),abs(int(point[1])-cell[1]))<=2
            exits=[dict(link,trigger_cell_state=cell_info(link['cell'])) for link in outgoing.get(mapid,[]) if near(link['cell'])]
            returns=[dict(link,landing_cell_state=cell_info(link['landing'])) for link in incoming.get(mapid,[]) if near(link['landing'])]
            open_returns=[link for link in returns if link['landing_cell_state']['open']]
            bounds=[int(g['origin'][0]),int(g['origin'][1]),int(g['origin'][0])+int(g['rect'][2]),int(g['origin'][1])+int(g['rect'][3])]
            below=bounds[3]>24
            interpretation='Original-open return landing: preserve its existing ground support and exact arrival; source art alone does not establish a new climb.' if open_returns else 'Nearby original exit transfers before traversing represented descent; preserve the original trigger/ground.' if below and any(link['trigger_cell_state']['open'] for link in exits) else 'No nearby original-open transfer/return proved; source geometry still needs per-form measurement.'
            result.append(dict(map=mapid,graphic=serial,native_graphic=native,layer=plane,cell=cell,anchor=cell_info(cell),signed_native_bounds=bounds,footprint=g['footprint'],native_rgba_sha256=g['rgba_sha256'],source_below_cap_extent=below,original_open_exit_near_below_cap_art=below and any(link['trigger_cell_state']['open'] for link in exits),local_walk_rows=[''.join('1' if cell_info([cell[0]+x,cell[1]+y])['open'] else '0' for x in range(-2,3)) for y in range(-2,3)],nearby_outgoing=exits,nearby_incoming_returns=returns,original_open_return_landings=len(open_returns),interpretation=interpretation))
            counts[serial]+=1
        maps[mapid]=dict(size=[w,h],active_layout_variant=row.get('active_layout_variant','client/restored-compatible'),raw_sha256=hashlib.sha256(raw).hexdigest(),legacy_owner_retained=row.get('east_existing_owner',False))
    used_maps={row['map'] for row in result}
    output=dict(scope='Read-only active fixed source planes and directed compiled routes. Native open cells/transfer tuples are facts; hidden stair depth and raised walk-surface heights still require source measurements. The five walk rows are offsets[-2..2] in y, columns[-2..2] in x;1means original-open. Legacy owners are explicitly marked, so their native source placement is not an actual runtime-geometry claim. No new climb, collider or route is proposed.',initial_ids=initial,additional_stair_ids=list(range(17111,17127)),graphic_counts=counts,zero_fixed_placements=sorted(n for n,count in counts.items() if not count),placements=result,maps={n:v for n,v in maps.items() if n in used_maps},source_pins={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [profile,catalog_path,routes_path]})
    if only_ids is not None:
        output.update(scope='Read-only native ruin anchors/foot/walk contract with nearby directed transfers. Local5x5walk strings are y[-2..2],x[-2..2];1is original-open. Native signed bounds and sourcefootprint stay authoritative. Legacy-owner map exceptions explicitlymarked. No art/runtime/route/collider edits or raisedclimb interpretation.',initial_ids=sorted(ids),additional_stair_ids=[])
        for row in output['placements']:
            row.pop('interpretation',None)
            g=table[row['graphic']][0];row['native_family']=g.get('family');row['native_ground_flag']=g.get('ground');row['source_owner_exception']=maps[row['map']]['legacy_owner_retained']
    outfile.write_text(json.dumps(output,ensure_ascii=False,indent=2));print(len(result),'placements;',len(used_maps),'fixed maps;',len(ids),'requestedgraphics;',sum(bool(n) for n in counts.values()),'usedgraphics')

if __name__=='__main__':run()
