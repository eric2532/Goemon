"""Read-only map-100 terrain/input-anchor union audit; never modifies game data."""
import argparse
from collections import Counter, defaultdict, deque
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit'
sys.path[:0]=[str(ROOT/'tools'),str(ROOT.parent/'Magic Power/tools')]
import cg_library as lib
from build_freyja_destinations import warp_rows
from prepare_field_assets import navigation_grid


def ridge_source_anchor(row,lookup):
    """East ridge inputs store footprint centres, not native map anchors."""
    x,y,serial=row[:3];g=lookup[int(serial)]
    return x-(max(1,g['east'])-1)/2,y+(max(1,g['south'])-1)/2


def matching_station(w,h,objects,x,y,serial):
    xx,yy=round(x),round(y)
    if abs(xx-x)>1e-5 or abs(yy-y)>1e-5 or not(0<=xx<w and 0<=yy<h):return None
    i=yy*w+xx
    return i if objects[i]==int(serial) else None


def spans(cells,w):
    rows=defaultdict(list)
    for i in cells:rows[i//w].append(i%w)
    result=[]
    for y,xs in sorted(rows.items()):
        xs=sorted(xs);start=last=xs[0]
        for x in xs[1:]+[xs[-1]+2]:
            if x>last+1:result.append([y,start,last]);start=x
            last=x
    return result


def bounds(cells,w):
    return [min(i%w for i in cells),min(i//w for i in cells),max(i%w for i in cells),max(i//w for i in cells)] if cells else None


def components(cells,w,h):
    pending=set(cells);result=[]
    while pending:
        seed=min(pending);pending.remove(seed);seen={seed};q=deque([seed])
        while q:
            i=q.popleft();x,y=i%w,i//w
            for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                k=yy*w+xx
                if 0<=xx<w and 0<=yy<h and k in pending:pending.remove(k);seen.add(k);q.append(k)
        result.append(dict(cells=len(seen),bounds=bounds(seen,w),spans=spans(seen,w)))
    return sorted(result,key=lambda r:-r['cells'])


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source-map',type=Path,help='Prepared client-plus-server map100 DAT; never activates it')
    parser.add_argument('--out',type=Path,help='Separate output folder; mask inputs remain the current client audit snapshots')
    args=parser.parse_args()
    if args.source_map and (args.out is None or args.out.resolve()==OUT.resolve()):
        parser.error('An alternate source needs a separate --out folder to preserve client-cache evidence')
    output=args.out or OUT;output.mkdir(parents=True,exist_ok=True)
    metadata=json.loads((OUT/'current-mask-data.json').read_text())
    lookup=lib.serial_index()
    client_path=ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/100.dat'
    source_path=args.source_map or client_path
    raw=source_path.read_bytes();w,h,ground,objects,flags=lib.parse_map(raw)
    if args.source_map:assert (w,h)==lib.parse_map(client_path.read_bytes())[:2],'Alternate source must retain original map100 dimensions'
    native=navigation_grid(w,h,ground,objects,lookup)
    all_cells=set(range(w*h));opened={i for i,v in enumerate(native)if v}
    dry_opened={i for i in opened if ground[i] not in (0,100) and not 5000<=ground[i]<=5008}
    source_art={i for i,v in enumerate(objects)if v>=1000}
    main_component={480*w+330};q=deque(main_component)
    while q:
        i=q.popleft();x,y=i%w,i//w
        for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            k=yy*w+xx
            if 0<=xx<w and 0<=yy<h and native[k] and k not in main_component:main_component.add(k);q.append(k)
    if not args.source_map:assert len(main_component)==94984,'Compare the fresh native component before accepting changed source bytes'
    frames={r['area']:r for r in metadata['areas']}
    def source(area,point):
        row=frames[area];x,y=point
        return ((row['frame_origin_meters'][0]+row['frame_x'][0]*x+row['frame_y'][0]*y)/3,
                (row['frame_origin_meters'][1]+row['frame_x'][1]*x+row['frame_y'][1]*y)/3)
    terrain={};area_envelopes={};union={k:set()for k in ['envelope','alpha_nonzero','alpha_opaque','dry_opaque']}
    for row in metadata['areas']:
        area=row['area'];image=Image.open(OUT/row['mask_snapshot']).convert('RGBA')
        sets={k:set()for k in union}
        for py in range(image.height):
            for px in range(image.width):
                point=[row['mask_origin_meters'][0]+px*3,row['mask_origin_meters'][1]+py*3]
                xx,yy=source(area,point);x,y=round(xx),round(yy)
                assert abs(xx-x)<1e-8 and abs(yy-y)<1e-8
                if not(0<=x<w and 0<=y<h):continue
                i=y*w+x;r,g,b,a=image.getpixel((px,py));sets['envelope'].add(i)
                if a:sets['alpha_nonzero'].add(i)
                if a>=128:sets['alpha_opaque'].add(i)
                if a>=128 and r<128:sets['dry_opaque'].add(i)
        terrain[area]={**row,'source_bounds_clipped':bounds(sets['envelope'],w),
                       'counts':{k:len(v)for k,v in sets.items()},
                       'native_open_in_envelope':len(opened&sets['envelope'])}
        area_envelopes[area]=sets['envelope']
        if area==row['canonical_area']:
            for key in union:union[key].update(sets[key])
    declarations=defaultdict(set);unmatched=Counter();suppressed=Counter()
    def add(owner,area,x,y,serial,replace_east=False):
        xx,yy=round(x),round(y)
        if abs(xx-x)>1e-5 or abs(yy-y)>1e-5:unmatched[owner+':fractional_source_station']+=1;return
        if not(0<=xx<w and 0<=yy<h):return
        if replace_east and xx>=440 and yy<360:suppressed[owner]+=1;return
        i=matching_station(w,h,objects,x,y,serial)
        if i is None:unmatched[owner+':native_graphic_differs']+=1;return
        if serial>=1000:declarations[owner].add(i)
    for area,data in metadata['gate_exteriors'].items():
        for row in data['trees']:
            x,y=source(area,row[1]);xx,yy=round(x),round(y)
            if 0<=xx<w and 0<=yy<h:
                serial=objects[yy*w+xx]
                if serial==10000 or 10058<=serial<=10094:add('gate_trees',area,x,y,serial,area=='east_gate')
        delta={'freyja':(-3,-3),'east_gate':(3,3),'south_gate':(3,-3)}[area]
        for point,serial,*_ in data['forts']:
            x,y=source(area,[point[0]-delta[0],point[1]-delta[1]])
            if area=='south_gate':serial={10640:10641,10641:10640}.get(serial,serial)
            add('gate_forts',area,x,y,serial)
        signs={'freyja':(-1,-1),'east_gate':(1,1),'south_gate':(1,-1)}[area]
        for row in data['rocks']:
            point,serial,size=row[:3]
            x,y=source(area,[point[0]-(signs[0]*(size[0]-3)//2),point[1]-(signs[1]*(size[1]-3)//2)])
            add('gate_ridges',area,x,y,serial,area=='east_gate')
        for point,serial,*_ in data.get('crops',[]):
            x,y=source(area,point);add('gate_crops',area,x,y,serial)
        for key in ['posts','lamps']:
            for point in data.get(key,[]):
                x,y=source(area,point);xx,yy=round(x),round(y)
                if 0<=xx<w and 0<=yy<h:add('gate_'+key,area,x,y,objects[yy*w+xx])
    for area,rows in metadata['outlying_trees'].items():
        if area not in frames:continue
        for point,serial in rows:
            x,y=source(area,point);add('outlying_trees',area,x,y,serial,area in ['east_coast','north_coast'])
    for area,rows in metadata['outlying_ridges'].items():
        if area not in frames:continue
        for row in rows:
            point,serial=row[:2];x,y=source(area,point);g=lookup[serial]
            add('outlying_ridges',area,x-(max(1,g['east'])-1)/2,y+(max(1,g['south'])-1)/2,serial,area in ['east_coast','north_coast'])
    for key in ['entrance_scenery','undersea_scenery']:
        for area,rows in metadata[key].items():
            if area not in frames:continue
            for row in rows:add(key,area,*row[0],row[1])
    west=json.loads((ROOT/'assets/maps/falan/west_route_scenery.json').read_text())
    for area in ['freyja','west_lakes']:
        for key in ['trees','cliffs','details','banks']:
            for x,y,serial,*_ in west['maps'][area][key]:add('west_'+key,area,x,y,serial)
    east=json.loads((ROOT/'assets/maps/falan/east_region/field-scenery.json').read_text())
    for area,data in east.items():
        for key,rows in data.items():
            for row in rows:
                x,y,serial=row[:3]
                if key=='ridges':x,y=ridge_source_anchor(row,lookup)
                add('east_field_'+key,area,x,y,serial)
    trees=json.loads((ROOT/'assets/maps/falan/black_prayer/region-trees.json').read_text())['areas']['south_lakes']
    for key in ['trees','fences']:
        for x,y,serial in trees[key]:add('ruby_south_'+key,'south_lakes',x,y,serial)
    cliffs=json.loads((ROOT/'assets/maps/falan/black_prayer/region-cave-walls.json').read_text())['maps']['100']
    for x,y,serial in cliffs:add('ruby_south_cliffs','south_lakes',x,y,serial)
    for row in metadata['venoa_southwest_scenery']['placements']:
        add('venoa_southwest_'+row['family'],'south_lakes',*row['cell'],row['serial'])
    for row in metadata['venoa_southwest_scenery'].get('offshore_placements',[]):
        add('venoa_water_flowers','south_lakes',*row['cell'],row['serial'])
    residual=ROOT/'assets/maps/falan/freyja_residual/provenance.json'
    if residual.exists():
        for x,y,serial in json.loads(residual.read_text())['shores']:
            add('freyja_residual_shores','freyja',x,y,serial)
    # These existing village fringes are actually overlaid in map-100 scenes.
    offset=metadata['venoa_road_offset']
    for row in metadata['venoa_frontage_buildings']:
        if row[1][0]<6:continue
        serial=row[4];g=lookup[serial]
        x,y=source('south_lakes',[row[1][0]+offset[0],row[1][1]+offset[1]])
        add('venoa_frontage_buildings','south_lakes',x-(max(1,g['east'])-1)/2,y+(max(1,g['south'])-1)/2,serial)
    for row in metadata['venoa_frontage_scenery']:
        point=[metadata['venoa_origin'][k]+row[0][k]*3 for k in [0,1]]
        if not 11252<=row[1]<=11265 or point[0]<40 or abs(point[1]+9)>24:continue
        x,y=source('south_lakes',[point[k]+offset[k]for k in [0,1]])
        add('venoa_frontage_walls','south_lakes',x,y,row[1])
    for row in metadata['laruka_approach_rows']:
        x,y,serial=row[:3];point=[(x-metadata['laruka_size'][0]/2)*3,(y-metadata['laruka_size'][1]/2)*3]
        if serial in [11077,11078,11254,11257,11260,11261,11263,11264,11374] and (point[0]-21)**2+(point[1]+18)**2<28**2:continue
        if serial in metadata['laruka_building_graphics']:continue
        if point[0]<-12 or abs(point[1]+18)>36:continue
        x,y=source('west_lakes',[point[k]+metadata['laruka_road_offset'][k]for k in [0,1]])
        add('laruka_frontage_details','west_lakes',x,y,serial)
    declared=set().union(*declarations.values());not_declared=source_art-declared
    # Matching an input declaration is an upper-bound restoration check, not a draw call or visual approval.
    main_gaps=main_component-union['envelope']
    union_report={}
    for key,cells in union.items():
        absent=all_cells-cells
        union_report[key]=dict(covered_source_cells=len(cells),native_open_outside=len(opened-cells),
                              decoder_dry_open_outside=len(dry_opened-cells),
                              venoa_component_outside=len(main_component-cells),
                              venoa_component_outside_bounds=bounds(main_component-cells,w),
                              nonzero_ground_outside=sum(bool(ground[i])for i in absent),
                              source_art_anchors_outside=len(source_art&absent))
    links=[]
    for a,x,y,b,tx,ty in warp_rows(ROOT.parent/'Magic Power'):
        if a!=100:continue
        i=y*w+x
        links.append(dict(cell=[x,y],target=b,arrival=[tx,ty],in_venoa_component=i in main_component,
                          in_terrain_envelope=i in union['envelope'],in_opaque_mask=i in union['alpha_opaque']))
    sites=[dict(area=r[0],target=int(r[2]),cell=[r[4][0]/3,r[4][1]/3])
           for r in metadata['sites']if r[0]in frames]
    for row in links:
        matches=[r for r in sites if r['target']==row['target']]
        row['nearest_same_target_site_manhattan']=min((abs(row['cell'][0]-r['cell'][0])+abs(row['cell'][1]-r['cell'][1])for r in matches),default=None)
        row['site_data_qualification']='dedicated city-gate owner'if row['target']==1000 else 'No same-target Sites declaration; separate owner reconciliation needed'if not matches else 'Matching target has site data; exact trigger semantics not executed'
    graph=json.loads((OUT.parent/'Source events/source-graph.json').read_text())
    actors={r['id']:r for r in graph['actors']}
    event_points=[];seen_events=set()
    for record in graph['event_warps']:
        if record['source_map']!=100 or record['npc']in seen_events:continue
        actor=actors[record['npc']];x,y=actor['cell'];i=y*w+x;seen_events.add(record['npc'])
        event_points.append(dict(npc=record['npc'],cell=[x,y],script=record['script'],target_release=record['target_release'],
                                 in_terrain_envelope=i in union['envelope'],source_recorded=bool(flags[i]&0xc000)))
    missing_records=[dict(cell=[i%w,i//w],serial=objects[i],source_recorded=bool(flags[i]&0xc000),
                          within_terrain_envelope=i in union['envelope'])for i in sorted(not_declared)]
    result=dict(schema=1,complete=False,source_map=100,
                source_variant='Prepared client-known plus pinned server-unrecorded map100; current runtime inputs remain separately owned' if args.source_map else 'BlueCrossgate client-cache map100; server LS2MAP-only stations are not yet reconciled',
                source_path=str(source_path),source_sha256=hashlib.sha256(raw).hexdigest(),
                mask_metadata_path=str(OUT/'current-mask-data.json'),
                mask_metadata_sha256=hashlib.sha256((OUT/'current-mask-data.json').read_bytes()).hexdigest(),
                dimensions=[w,h],native_open_cells=len(opened),decoder_dry_open_cells=len(dry_opened),
                venoa_component=dict(seed=[330,480],cells=len(main_component),bounds=bounds(main_component,w)),
                terrain_scenes=terrain,union=union_report,venoa_component_envelope_gap_components=components(main_gaps,w,h),
                decoder_open_outside_all_envelopes=[[i%w,i//w]for i in sorted(opened-union['envelope'])],
                source_art=dict(original_anchor_count=len(source_art),matching_input_declarations=len(declared),
                                no_matching_inspected_input_declaration=len(not_declared),
                                no_declaration_inside_union=len(not_declared&union['envelope']),
                                no_declaration_inside_southern_lakes=len(not_declared&area_envelopes['south_lakes']),
                                no_declaration_by_serial=dict(Counter(objects[i]for i in not_declared)),
                                owner_match_counts={k:len(v)for k,v in declarations.items()},
                                replaced_legacy_east_records=dict(suppressed),unmatched_input_records=dict(unmatched)),
                source_fixed_ports=links,
                source_event_warp_points=event_points,
                limits=['Terrain envelope and alpha/paint agreement are distinct from original walkability or rendered scenery.',
                        'Declared source-art stations are static input evidence, not proof that visibility/clearance filters draw every item.',
                        'No matching inspected input declaration is a source-ownership gap, not proof that no approximate generic object is visible.',
                        'Gate forts are reverse-mapped through the generator original-cell offset/south graphic swap.',
                        'East field completion uses a separate pinned LS2MAP reference outside recorded native cells; mismatches are kept separate.',
                        'East ridge footprint centres are inverted using exact original graphic footprints before comparing anchor coordinates and IDs.',
                        'Other regional owners retain their identities. The full-map complement is not automatically assigned to Venoa.'])
    result['limits'].append('Counts describe the recorded source variant and current mask/input snapshots; server-only stations may already belong to an existing owner. No source, terrain or route is activated by this audit.')
    (output/'union-coverage.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (output/'source-art-without-declaration.json').write_text(json.dumps(missing_records,ensure_ascii=False,indent=2)+'\n')
    im=Image.new('RGB',(w,h),'#18232a');pixels=im.load()
    for i in opened:pixels[i%w,i//w]=(99,123,119) if i in union['envelope'] else (136,79,98)
    for i in main_component:pixels[i%w,i//w]=(104,173,134) if i in union['envelope'] else (239,116,93)
    for i in not_declared:pixels[i%w,i//w]=(196,166,85)
    draw=ImageDraw.Draw(im)
    for area,row in terrain.items():
        if area!=row['canonical_area']:continue
        draw.rectangle(row['source_bounds_clipped'],outline='#80a5ce');draw.text(tuple(row['source_bounds_clipped'][:2]),area,fill='white')
    draw.ellipse((326,476,334,484),outline='white')
    im.save(output/'source-union-data-map.png')
    assert len(declared)+len(not_declared)==len(source_art)
    print(json.dumps(dict(complete=False,source_map=100,
        matching_input_declarations=len(declared),unmatched_input_declarations=len(not_declared),
        union=union_report,main_gap_components=len(result['venoa_component_envelope_gap_components']),
        fixed_ports_outside=[r for r in links if not r['in_terrain_envelope']]),ensure_ascii=False))


if __name__=='__main__':main()
