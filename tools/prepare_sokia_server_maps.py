"""Stage missing-client Sokia maps from pinned server layers, without repacking old banks."""
import argparse
import json
from pathlib import Path
import struct
import sys

from PIL import Image
import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import reference_map,active_raw
from build_falan_room_art import KIND,PALACE_KIND,CELLAR_KIND,CIVIC_KIND,ARENA_KIND,FREYJA_KIND
from build_coastal_villages import KINDS,WALLS

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/crossgate_sokia/maps/server'
OUT=ROOT/'assets/maps/original_crossgate/sokia_server'
REPORT=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps'
IDS={5005,5006,5009,5010,11031,11039,11040,13504,13509,13512,15549,15556,15560,15562,15577,15800}
ACTIVE_WATER={13504,13509,13512}
CATALOGS=['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json',
          'assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/elsa/catalog.json',
          'assets/maps/original_crossgate/east/catalog.json']


def encounter_data(graph):
    from prepare_snow_region_population import rows,SOURCE as tables
    base=json.loads((ROOT/'assets/maps/falan/south_kili_route/population.json').read_text())
    coast=json.loads((ROOT/'assets/maps/falan/sokia/population.json').read_text())
    offset=len(base['species'])+len(coast['extra_species'])
    east=json.loads((ROOT/'assets/characters/crossgate/east_region/species.json').read_text())
    species=[dict(east[skin],family='east_region',skin=skin)for skin in [11,106]]
    palette={r['id']:offset+i for i,r in enumerate(species)}
    enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')}
    source_groups={r[2]:r for r in rows('group.txt')};zones=[];groups={}
    for raw in rows('encount.txt'):
        number=int(raw[3])
        if number not in IDS:continue
        assert number in [13509,13512] and int(raw[0])in [7037,7039]
        choices=[]
        for i,gid in enumerate(raw[14:24]):
            weight=int(raw[24+i]or 0)
            if not gid or not weight:continue
            g=source_groups[gid];assert g[3:5]==['-1','-1']and not any(int(v or 0)for v in g[25:35])
            members=[];details=[]
            for j,eid in enumerate(g[5:15]):
                member_weight=int(g[15+j]or 0)
                if not eid or eid=='0'or not member_weight:continue
                enemy=enemies[eid];original=bases[enemy[3]];appearance=int(original[30]);assert appearance in palette
                members.append([palette[appearance],int(enemy[4]),int(enemy[5]),member_weight])
                details.append(dict(enemy_id=int(eid),base_id=int(enemy[3]),appearance=appearance,raw_enemy=enemy,raw_base=original))
            key='server:'+gid;record=dict(members=members,raw=g,order=g[1],source_group=gid,details=details)
            if key in groups:assert groups[key]==record
            groups[key]=record;choices.append([key,weight])
        zones.append(dict(id=int(raw[0]),map=number,bounds=list(map(int,raw[4:8])),probability=list(map(int,raw[8:10])),
                          maximum=int(raw[10]),priority=int(raw[11]),groups=choices,raw=raw))
    assert {r['id']for r in zones}=={7037,7039}
    assessment={str(n):dict(ambient_rows=[r['id']for r in zones if r['map']==n],
        scripted_candidates=[r for r in graph['fight_triggers']if r['source_map']==n],
        status='ordinary source zones prepared'if n in [13509,13512]else'No encount.txt map rows; scripted/event semantics require separate review, not a blanket safe claim')for n in sorted(IDS)}
    return dict(schema=1,species_offset=offset,species=species,zones=zones,groups=groups,map_assessment=assessment,
        source_hashes={n:recovery.digest((tables/n).read_bytes())for n in ['encount.txt','group.txt','enemy.txt','enemybase.txt']},
        adaptations=['Existing South shuffle bags preserve documented weights, map bounds, levels and maximums.',
                     'Existing native species/level combat is retained; exact original server stat/formation execution remains unverified.'])


def runtime_map(source,ident):
    w,h,values,title=reference_map(source,ident);cells=w*h
    # The existing renderer consumes MAP01. These visibility bits are synthetic;
    # LS2MAP supplies no recorded/warp flag plane. No warp bits are invented.
    raw=b'MAP\x01'+bytes(8)+struct.pack('<II',w,h)+struct.pack(f'<{cells*3}H',*values,*([0xc000]*cells))
    return raw,w,h,values,title


def decoder_regression():
    source=(SOURCE/'15526_usi').read_bytes();_,w,h,values,_=runtime_map(source,15526)
    row=json.loads((ROOT/CATALOGS[1]).read_text())['maps']['BlueCrossgate/map/0/15526.dat']
    client=active_raw(row);cells=w*h;planes=struct.unpack_from(f'<{cells*3}H',client,20)
    assert struct.unpack_from('<II',client,12)==(w,h)
    assert tuple(planes[:cells])==values[:cells]
    differences=[dict(cell=[i%w,i//w],client=planes[cells+i],server=values[cells+i])
                 for i in range(cells)if planes[cells+i]!=values[cells+i]]
    assert differences==[dict(cell=[8,7],client=17954,server=0),dict(cell=[91,7],client=17954,server=0)]
    return dict(source=15526,size=[w,h],all_ground_cells_equal=True,object_differences=differences,
                contract='Existing client exit markers remain untouched; server has no client flag plane.')


def prepare():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    lookup=lib.serial_index();shared={};owners={};catalogs={};protected={}
    with lib.connection()as db:
        client_paths={r['path']for r in db.execute("SELECT path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    assert not{f'BlueCrossgate/map/0/{n}.dat'for n in IDS}&client_paths,'A newly available client map must be reconciled, not replaced with synthetic flags'
    for path in CATALOGS:
        catalog=json.loads((ROOT/path).read_text());catalogs[path]=catalog
        protected[path]=recovery.digest((ROOT/path).read_bytes())
        for serial,g in catalog['graphics'].items():
            if serial not in shared:shared[serial]=g;owners[serial]=path
    graph=json.loads((REPORT.parent/'Source events/source-graph.json').read_text())
    refs=json.loads((SOURCE/'references.json').read_text());maps={};used=set();evidence=[]
    for proof in refs:
        source=(SOURCE/proof['file']).read_bytes();ident=struct.unpack_from('>H',source,6)[0]
        if ident not in IDS:continue
        assert recovery.digest(source)==proof['sha256'],proof['file']
        raw,w,h,values,title=runtime_map(source,ident);cells=w*h;path=f'BlueCrossgate/map/0/{ident}.dat'
        existing=[(p,c['maps'][path])for p,c in catalogs.items()if path in c['maps']]
        if existing:
            for p,row in existing:
                decoded=active_raw(row);assert struct.unpack_from('<II',decoded,12)==(w,h)
                assert struct.unpack_from(f'<{cells*2}H',decoded,20)==values,(ident,p)
            evidence.append(dict(source=ident,reused_owners=[p for p,_ in existing],exact_floor_object_match=True,reference=proof))
            continue
        ground,objects=values[:cells],values[cells:]
        serials={s for s in ground if s}|{s for s in objects if s>=1000}
        assert not serials-lookup.keys(),('Missing original graphics',ident,sorted(serials-lookup.keys()))
        used.update(serials);walk=navigation_grid(w,h,ground,objects,lookup);bits=bytearray((cells+7)//8)
        for i,opened in enumerate(walk):
            if opened:bits[i>>3]|=1<<(i&7)
        fixed=[r for r in graph['fixed_warps']if r['source_map']==ident]
        events=[r for r in graph['event_warps']if r['source_map']==ident or r.get('target_map')==ident]
        maps[path]=dict(group='sokia_server_fixed',title=title,id=ident,size=[w,h],outdoor=False,
            raw=recovery.encode(raw),sha256=recovery.digest(raw),bytes=len(raw),walk=recovery.encode(bits),
            recorded=0,cells=cells,warp_cells=[],reference_only=True,layout_complete=True,source_flags_available=False,
            synthesized_flags=dict(value=49152,purpose='Existing MAP01 visibility contract only; not original recorded/warp evidence'),
            layout_reference=proof,source_path=str((SOURCE/proof['file']).relative_to(ROOT)),
            source_floor_object_sha256=recovery.digest(source[44:]),source_background_serials=[100],
            fixed_port_candidates=fixed,event_port_candidates=events,sokia_visual_only=ident not in ACTIVE_WATER,
            gate_status='Verified Water layout/NPC/native dispatch; unresolved source predicates remain guarded, no invented inbound route.' if ident in ACTIVE_WATER else 'Review-only during source/render QA. Activate proven fixed doors separately; retain scripted conditions.')
        evidence.append(dict(source=ident,size=[w,h],reference=proof,derived_open_cells=sum(walk),
                             fixed_port_candidates=len(fixed),event_port_candidates=len(events),client_flags_available=False))
    assert len(maps)==13 and len(evidence)==16
    furniture={**KIND,**PALACE_KIND,**CELLAR_KIND,**CIVIC_KIND,**ARENA_KIND,**FREYJA_KIND,**KINDS}
    furniture.update({s:'room_wall'for s in WALLS if s>=16000})
    for serial in used:
        if str(serial)not in shared:continue
        g=lookup[serial];image=lib.image_from_record(g['pack'],g['row'])
        assert recovery.digest(image.tobytes())==shared[str(serial)]['rgba_sha256'],('Shared native graphic differs',serial)
    novel=used-set(map(int,shared));pages,graphics,_=recovery.pack_graphics(novel,lookup,furniture,lib)
    catalog=dict(schema=1,page_indices='local',maps=maps,graphics=graphics,requires=['east'],
                 pages=[f'sokia_server/atlas-{i}.png'for i in range(len(pages))])
    surfaces=recovery.rock_surfaces(catalog,pages);solids=recovery.solid_pages(catalog,pages)
    catalog['surface_pages']=[f'sokia_server/surfaces-{i}.png'for i in range(len(surfaces))]
    catalog['solid_pages']=[f'sokia_server/solid-{i}.png'for i in range(len(solids))]
    proof=dict(source_scope=sorted(IDS),maps=evidence,prepared_maps=13,reused_maps=3,new_graphics=len(novel),
               reused_graphic_owners={str(s):owners[str(s)]for s in sorted(used)if str(s)in shared},
               protected_catalog_sha256=protected,decoder_regression=decoder_regression(),
               limitations=['Server LS2MAP has no client flags. Walk derives from existing original graphic attributes.',
                            'Synthetic0xc000 bits preserve the existing renderer format, not client record/warp evidence.',
                            'Pinned fixed/event port candidates retain direction/conditions; no quest links activated by preparation.',
                            'Existing East maps11031/11039/11040 and all prior atlases/maps stay under their original owners.'])
    images={**{f'atlas-{i}.png':im for i,im in enumerate(pages)},**{f'solid-{i}.png':im for i,im in enumerate(solids)},
            **{f'surfaces-{i}.png':im for i,im in enumerate(surfaces)}}
    return catalog,images,proof,encounter_data(graph)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',type=Path);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    catalog,images,proof,encounters=prepare();dest=args.stage or OUT;dest.mkdir(parents=True,exist_ok=True)
    text=json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n'
    if args.check:assert(dest/'catalog.json').read_text()==text
    else:(dest/'catalog.json').write_text(text)
    if args.check:assert json.loads((dest/'encounters.json').read_text())==encounters
    else:(dest/'encounters.json').write_text(json.dumps(encounters,ensure_ascii=False,indent=2)+'\n')
    if args.check and not args.stage:
        for page,record in json.loads((OUT/'cpu-pages/provenance.json').read_text()).items():
            assert recovery.digest((ROOT/'assets/maps/original_crossgate'/page).read_bytes())==record['source_sha256'],page
            assert recovery.digest((ROOT/'assets/maps/original_crossgate'/record['resource']).read_bytes())==record['resource_sha256'],page
    for name,image in images.items():
        if args.check:
            with Image.open(dest/name)as actual:assert actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else:image.save(dest/name)
    REPORT.mkdir(parents=True,exist_ok=True);(REPORT/'source-preservation.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
    print(f'SOKIA_SERVER_MAPS prepared={len(catalog["maps"])} reused=3 new_graphics={len(catalog["graphics"])} original_flags_available=false')


if __name__=='__main__':main()
