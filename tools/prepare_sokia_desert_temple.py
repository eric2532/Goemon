"""Recover all seven Desert Temple states and their source-specific encounters."""
import argparse
import json
import sys
from pathlib import Path

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map, solid_pages
from prepare_sokia_server_maps import ROOT, SOURCE, CATALOGS, KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND, KINDS, WALLS
from prepare_sokia_server_events import prepare as prepare_npcs
from prepare_snow_region_population import SOURCE as TABLES, rows

IDS = set(range(13016, 13023))
REPORT = ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Desert Temple'
OUT = REPORT/'Staged'


def encounters():
    wind = json.loads((ROOT/'assets/maps/original_crossgate/sokia_wind_tower/encounters.json').read_text())
    species = list(wind['species']); indices = {int(s['id']): i for i, s in enumerate(species)}
    manifest = json.loads((ROOT/'assets/characters/crossgate/guard_pets/motions.json').read_text())
    assert manifest['variants'][399]['id'] == 101931
    if 101931 not in indices:
        indices[101931] = len(species)
        species.append(dict(id=101931, name='狂战将军', bank='companion', skin=399, key=manifest['variants'][399]['key'],
                            height=manifest['variants'][399]['body'][4]))
    enemies = {r[2]: r for r in rows('enemy.txt')}; bases = {r[1]: r for r in rows('enemybase.txt')}
    original_groups = {r[2]: r for r in rows('group.txt')}; groups = {}; zones = []; approach = None
    for raw in rows('encount.txt'):
        if int(raw[3]) not in IDS and int(raw[0])!=15003: continue
        choices = []
        for slot, gid in enumerate(raw[14:24]):
            weight = int(raw[24+slot] or 0)
            if not gid or not weight: continue
            original = original_groups[gid]; members = []; identities = []; details = []
            for j, eid in enumerate(original[5:15]):
                member_weight = int(original[15+j] or 0)
                if eid in ['', '0'] or not member_weight: continue
                enemy = enemies[eid]; base = bases[enemy[3]]; index = indices[int(base[30])]
                assert species[index]['bank'] in ['companion', 'east_region']
                members.append([index, int(enemy[4]), int(enemy[5]), member_weight])
                identities.append(dict(enemy_id=eid, name=base[0], count=list(map(int, enemy[6:8])), mandatory=original[25+j]=='1'))
                details.append(dict(species=index, enemy=eid, name=base[0], raw_enemy=enemy, raw_base=base))
            key = 'desert:'+gid
            record = dict(members=members, raw=original, source_group=gid, order=original[1], source_members=identities, details=details)
            if key in groups: assert groups[key] == record
            groups[key] = record; choices.append([key, weight])
        record=dict(id=int(raw[0]), map=int(raw[3]), bounds=list(map(int, raw[4:8])),
                          probability=list(map(int, raw[8:10])), maximum=int(raw[10]), minimum=1,
                          priority=int(raw[11]), groups=choices, raw=raw, source_party_contract=True,
                          next_encounter=int(raw[12] or 0), next_probability=int(raw[13] or 0))
        if int(raw[0])==15003:record['levels']=[26,28];approach=record
        else:zones.append(record)
    assert len(zones)==9 and len(groups)==12 and approach is not None
    assert set(groups)=={'desert:'+str(n) for n in [*range(7016,7023),*range(15010,15015)]}
    assert groups['desert:7021']['raw'][3:5]==['18462','-1']
    used = sorted({m[0] for g in groups.values() for m in g['members']})
    assert {species[i]['id'] for i in used} == {101104,101303,101931}
    contracts = []
    for i in used:
        s = species[i]; bank = 'guard_pets' if s['bank']=='companion' else s['bank']
        path = ROOT/'assets/characters/crossgate'/bank/'motions.json'; data=json.loads(path.read_text())
        assert int(data['variants'][s['skin']]['id'])==int(s['id'])
        contracts.append(dict(index=i,appearance=s['id'],bank=bank,skin=s['skin'],
                              motions_sha256=recovery.digest(path.read_bytes()),frame_table_sha256=recovery.digest(path.with_name('frames.bin').read_bytes()),
                              qualification='Existing native appearance/cache contract; source-frame, contact and rendered validation remain separate.'))
    config=next(r for r in (ROOT/'assets/references/crossgate_sokia/events/dungeonconf.txt').read_bytes().decode('gb18030').splitlines() if len(r.split('\t'))>52 and r.split('\t')[3]=='303').split('\t')
    assert config[39:41]==['5','5'] and config[49:52]==['15003','26','28']
    return dict(schema=1,species=species,reused_species=[dict(index=i,**species[i]) for i in used],zones=zones,groups=groups,art_contracts=contracts,
                generated_approach=dict(name=config[0],config=303,raw=config,minimum=5,maximum=5,source_template=int(config[7]),
                    size=list(map(int,config[41:45])),entry_rect=list(map(int,config[10:14])),entry_map=int(config[9]),
                    end=list(map(int,config[15:18])),ground=int(config[22]),pool=approach,runtime_registered=False,
                    source_sha256=recovery.digest((ROOT/'assets/references/crossgate_sokia/events/dungeonconf.txt').read_bytes()),
                    qualification='Required five-floor approach and moving source entrance; original graph/placement distribution, per-floor level curve and field execution remain unverified. Pool26-28is the configured interval, not per-floor certification. Prepared roster does not establish playable generated floors.'),
                source_hashes={n:recovery.digest((TABLES/n).read_bytes()) for n in ['encount.txt','group.txt','enemy.txt','enemybase.txt']},
                limits=['Source memberships, item gates, mandatory general, levels, caps and ticket weights are retained.',
                        'Original probability denominator, party-size distribution, formation, AI and follow-on execution remain unverified.'])


def prepare():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    lookup=lib.serial_index();shared={};owners={};protected={}
    for name in CATALOGS:
        path=ROOT/name;catalog=json.loads(path.read_text());protected[name]=recovery.digest(path.read_bytes())
        for key,g in catalog['graphics'].items():
            if key not in shared:shared[key]=g;owners[key]=name
    refs=json.loads((SOURCE/'earth-shrine-references.json').read_text())
    graph=json.loads((REPORT.parent/'Source events/source-graph.json').read_text())
    maps={};evidence=[];used=set();variations=[]
    for ref in refs:
        number=int(ref['file'].split('_')[0]);assert number in IDS
        server=(SOURCE/ref['file']).read_bytes();assert recovery.digest(server)==ref['sha256']
        with lib.connection() as db:
            fid=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        raw=lib.source_file(fid)[1].read_bytes();restored,completion=complete_map(raw,server,number)
        assert completion['compatible'] and completion['layout_complete']
        w,h,ground,objects,flags=lib.parse_map(restored);_,_,original,title=reference_map(server,number);cells=w*h
        for i,(client,pinned) in enumerate(zip(ground+objects,original)):
            if client!=pinned:variations.append(dict(map=number,layer=i//cells,cell=[i%cells%w,i%cells//w],client=client,server=pinned))
        assert restored[20+cells*4:]==raw[20+cells*4:]
        serials={s for s in ground if s}|{s for s in objects if s>=1000};used.update(serials)
        bits=bytearray((cells+7)//8);walk=navigation_grid(w,h,ground,objects,lookup)
        for i,opened in enumerate(walk):
            if opened:bits[i>>3]|=1<<(i&7)
        path=f'BlueCrossgate/map/0/{number}.dat'
        maps[path]=dict(group='sokia_desert_temple',id=number,title=title,size=[w,h],outdoor=False,
                        raw=recovery.encode(raw),sha256=recovery.digest(raw),restored_raw=recovery.encode(restored),restored_sha256=recovery.digest(restored),bytes=len(raw),
                        walk=recovery.encode(bits),recorded=completion['recorded'],cells=cells,restored_cells=completion['completed'],layout_complete=True,
                        warp_cells=[[i%w,i//w] for i,v in enumerate(flags) if v&2],layout_reference=ref,source_floor_object_sha256=recovery.digest(server[44:]),
                        source_flags_available=True,sokia_visual_only=True,fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map']==number],
                        gate_status='Review-only; original item/keeper/chest predicates and scenery remain required. No free entrance or quest grant.')
        evidence.append(dict(id=number,title=title,completion=completion,source=ref,client_flags_preserved=True,client_sha256=recovery.digest(raw),decoder_open_cells=sum(walk)))
    assert len(maps)==7 and sum(m['restored_cells'] for m in maps.values())==4094
    assert variations==[dict(map=13022,layer=1,cell=[7,4],client=13998,server=0)]
    furniture={**KIND,**PALACE_KIND,**CELLAR_KIND,**CIVIC_KIND,**ARENA_KIND,**FREYJA_KIND,**KINDS}
    furniture.update({n:'room_wall' for n in WALLS if n>=16000})
    novel=used-set(map(int,shared));assert len(used)==181 and len(novel)==20
    pixel_proofs={}
    for s in sorted(used):
        native=lookup[s];image=lib.image_from_record(native['pack'],native['row']);digest=recovery.digest(image.tobytes())
        if str(s) in shared:
            assert shared[str(s)]['rgba_sha256']==digest and shared[str(s)]['origin']==[native['x'],native['y']] and shared[str(s)]['footprint']==[native['east'],native['south']],s
        pixel_proofs[str(s)]=dict(rgba_sha256=digest,pack=native['pack'],row=native['row'])
    pages,graphics,_=recovery.pack_graphics(novel,lookup,furniture,lib)
    surfaces=recovery.rock_surfaces(dict(graphics=graphics),pages);solids=solid_pages(graphics,pages)
    catalog=dict(schema=1,page_indices='local',surface_indices='local',maps=maps,graphics=graphics,requires=['east'],
                 pages=[f'sokia_desert_temple/atlas-{i}.png' for i in range(len(pages))],
                 surface_pages=[f'sokia_desert_temple/surfaces-{i}.png' for i in range(len(surfaces))],
                 solid_pages=[f'sokia_desert_temple/solid-{i}.png' for i in range(len(solids))])
    npcs,npc_atlas=prepare_npcs(catalog);assert len(npcs['actors'])==14 and len(npcs['excluded'])==2
    npcs['atlas_path']='res://assets/maps/original_crossgate/sokia_desert_temple/events/npc-atlas.png'
    proof=dict(maps=evidence,source_scope=sorted(IDS),recorded_client_variations=variations,source_graphics=pixel_proofs,
               protected_catalog_sha256=protected,reused_graphics={str(s):owners[str(s)] for s in sorted(used-novel)},original_graphics_repacked=0,
               fixed_ports=[r for r in graph['fixed_warps'] if r['source_map'] in IDS],
               boundary_ports=[r for r in graph['fixed_warps'] if (r['source_map'] in IDS)!=(r['target_map'] in IDS)],
               event_warps=[r for r in graph['event_warps'] if r['source_map'] in IDS or r.get('target_map') in IDS],
               actors=sorted(npcs['actors']),excluded_later_actors=npcs['excluded'],
               missing_fixed_maps=[],missing_prepared_enemy_assets=[],goal_complete=False,
               required_missing_runtime_maps=[dict(config=303,name='砂漠之祠',generated_floors=5,source_template=21600,
                    entry_map=300,entry_rect=[570,300,640,400],terminal_map=13022,terminal_cell=[7,4],
                    reason='Original generated approach/entrance is required and not registered. Do not replace it with a free fixed-map shortcut or certify an invented layout.')],
               remaining=['Native source party dispatch, source-item gate and rare-identity evidence is separate in the Desert Temple checkpoint; table preparation alone does not certify execution.',
                          'Complete fixed-camera scenery and rendered source-frame/motion review; byte-exact frame recovery is separate evidence.',
                          'All original keeper/chest/entrance conditions and natural prerequisite acquisition.',
                          'Original probability denominator, party-size distribution, formation/AI and follow-on execution.',
                          '13022client entrance marker13998differs from pinned server zero; recorded client tile is preserved, release parity remains unverified.'])
    images={**{f'atlas-{i}.png':im for i,im in enumerate(pages)},**{f'surfaces-{i}.png':im for i,im in enumerate(surfaces)},
            **{f'solid-{i}.png':im for i,im in enumerate(solids)},'events/npc-atlas.png':npc_atlas}
    return catalog,encounters(),npcs,images,proof


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=OUT);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    catalog,roster,npcs,images,proof=prepare()
    for name,data in [('catalog.json',catalog),('encounters.json',roster),('events/data.json',npcs),('source-preservation.json',proof)]:
        path=args.output/name;text=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check:assert path.read_text()==text,name
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    for name,image in images.items():
        path=args.output/name
        if args.check:
            from PIL import Image
            with Image.open(path) as actual:assert actual.mode==image.mode and actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else:path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
    print('DESERT_TEMPLE_SOURCE 7fixed maps,4094completed cells,181graphics,9zones,12groups including required5floor approach,14actors; normal access remains gated.')


if __name__=='__main__':main()
