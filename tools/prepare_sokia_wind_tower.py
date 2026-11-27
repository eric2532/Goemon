"""Stage the connected Arcas/Wind Tower source branch, without activating travel."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys

import recover_original_crossgate_maps as recovery
from prepare_east_region_maps import complete_map, reference_map, solid_pages
from prepare_east_region_population import actor_art, append_native_bank, approved_height, battle_ids, compile_script, native_page_index
from prepare_sokia_server_maps import ROOT, SOURCE, CATALOGS
from prepare_snow_region_population import SOURCE as TABLES, rows

IDS = {301, 302, 20002, 20003, *range(20301, 20311)}
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower'
OUT = REPORT / 'Staged'
EVENTS = ROOT / 'assets/references/crossgate_sokia/events'
SCRIPT_ENCOUNTERS = {10007, 10010, 10011}
NATIVE_SOURCES = [('sokia_region', [7,9], ['original:2843','original:2846']),
                  ('university_region', [7,6], ['original:2844','original:2845']),
                  ('venoa_route', [5], ['original:2927'])]


def stage_native_bank(output):
    output=output.resolve()
    base=ROOT/'assets/characters/crossgate/east_region'
    previous=json.loads((base/'motions.json').read_text()); records=json.loads((base/'species.json').read_text())
    assert not {101211,101212,101213,101214,101630}&{int(v['id']) for v in previous['variants']}, 'These native appearances are already prepared'
    output.mkdir(parents=True,exist_ok=True)
    for name in ['motions.json','frames.bin','palette.png','species.json']: shutil.copyfile(base/name,output/name)
    dependencies={}
    for bank,skins,keys in NATIVE_SOURCES:
        source=ROOT/'assets/characters/crossgate'/bank; manifest=json.loads((source/'motions.json').read_text())
        additions=[dict(id=int(manifest['variants'][skin]['id']),key=key,
                        name='恶魔螃蟹' if bank=='venoa_route' else '守护者',height=approved_height(bank,skin,manifest),
                        prepared_from=dict(bank=bank,skin=skin)) for skin,key in zip(skins,keys)]
        append_native_bank(output,source,skins,additions)
        dependencies[bank]={n:recovery.digest((source/n).read_bytes()) for n in ['motions.json','frames.bin','palette.png']}
    native_page_index(output)
    result=json.loads((output/'motions.json').read_text())
    for key in ['variants','timelines','atlas_paths','skin_pages','variant_heights','variant_sources']:
        assert result[key][:len(previous[key])]==previous[key],key
    assert json.loads((output/'species.json').read_text())[:len(records)]==records
    result.setdefault('reused_source_hashes',{}).update(dependencies)
    (output/'motions.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    return dict(previous_variants=len(previous['variants']),variants=len(result['variants']),
                added=[v['id'] for v in result['variants'][len(previous['variants']):]],
                source_before_hashes={n:recovery.digest((base/n).read_bytes()) for n in ['motions.json','frames.bin','palette.png','species.json']},
                dependencies=dependencies,activation='Staged only; original pixels/contact/native/rendered review required.')


def source_actors(output):
    references = {r['file']: r for r in json.loads((EVENTS/'references.json').read_text())}
    actors = []; scripts = {}; proofs = {}; excluded = []
    for line, text in enumerate((TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines(), 1):
        raw = text.split('\t')
        if text.startswith('#') or len(raw) != 25 or not raw[8].isdigit(): continue
        if int(raw[8]) not in IDS and raw[3] != '6267': continue
        if raw[0] in ['Warp', 'HouseWarp2']: continue  # Fixed graph owns these exact directed ports.
        if raw[6] != '1' or int(raw[3]) >= 300000:
            excluded.append(dict(id=raw[3], raw=raw, reason='Inactive or later source actor; retained, not authenticated for original release.'))
            continue
        actor = dict(id=raw[3], type=raw[0], name=raw[1], source=int(raw[8]),
                     cell=list(map(int, raw[9:11])), direction=int(raw[19] or 0)%8,
                     graphic=int(raw[20] or 0), script=raw[24], raw=raw,
                     source_line=line, region='sokia_wind_tower', generated_by=None,dialogue_owner='sokia_wind')
        actors.append(actor)
        if actor['script'].endswith('.txt'):
            name=actor['script']; payload=(EVENTS/name).read_bytes(); proof=references[name]
            assert recovery.digest(payload)==proof['sha256'], name
            scripts[name]=compile_script(payload); proofs[name]=proof
    assert len(actors)==16 and {a['id'] for a in actors if a['source']==300}=={'6267'}
    used_messages=set()
    for script in scripts.values():
        for _, command in script['lines']:
            used_messages.update(re.findall(r'\b(?:Window|EndWindow)\s+(\d+)',command,re.I))
            used_messages.update(re.findall(r'\b(?:StrCmpChat|StrStrChat)\s*==\s*(\d+)',command,re.I))
    messages={r[0]:r[1].replace('\\n','\n') for r in rows('msg.txt') if len(r)>1 and r[0] in used_messages}
    assert used_messages<=messages.keys(), used_messages-messages.keys()
    art=actor_art(actors,scripts,{},output)
    art['art']={'wind:'+key:value for key,value in art['art'].items()}
    for actor in actors+art['npcs']:actor['token']='wind:'+actor['token']
    return dict(schema=1, actors=actors, scripts=scripts, source_provenance=proofs,
                scripted_battles=[b for b in battle_ids(actors,scripts) if b['source'] in IDS],
                automatic=[dict(actor=a['id'],source=a['source'],type=a['type'],bounds=list(map(int,a['raw'][13:17])),
                                cooldown_ms=max(750,int(a['raw'][18]or 0)),source_line=a['source_line'])
                           for a in actors if a['type']=='StandEnemy'],
                messages=messages, excluded=excluded,
                source_hashes={n:recovery.digest((TABLES/n).read_bytes()) for n in ['npc.txt','msg.txt']}, **art)


def encounters():
    east=json.loads((ROOT/'assets/maps/falan/east_region/population.json').read_text())
    species=list(east['species']); indices={int(s['id']):i for i,s in enumerate(species)}
    native=json.loads((ROOT/'assets/characters/crossgate/east_region/motions.json').read_text())
    native_skins={int(v['id']):i for i,v in enumerate(native['variants'])}
    # Preserve existing East indices. Missing appearances reuse their existing native banks.
    extras={101211:('sokia_region',7),101212:('university_region',7),
            101213:('university_region',6),101214:('sokia_region',9),101630:('venoa_route',5)}
    bases={r[1]:r for r in rows('enemybase.txt')}; enemies={r[2]:r for r in rows('enemy.txt')}
    source_groups={r[2]:r for r in rows('group.txt')}; groups={}; zones=[]; bosses={}
    for raw in rows('encount.txt'):
        ident=int(raw[0])
        if int(raw[3]) not in IDS and ident not in SCRIPT_ENCOUNTERS: continue
        choices=[]
        for slot,gid in enumerate(raw[14:24]):
            weight=int(raw[24+slot] or 0)
            if not gid or not weight: continue
            source=source_groups[gid]; members=[]; details=[]; identities=[]
            for j,eid in enumerate(source[5:15]):
                member_weight=int(source[15+j] or 0)
                if eid in ['', '0'] or not member_weight: continue
                enemy=enemies[eid]; base=bases[enemy[3]]; appearance=int(base[30])
                if appearance not in indices:
                    if appearance in native_skins:
                        bank='east_region';skin=native_skins[appearance];height=native['variant_heights'][skin]
                    else:
                        bank,skin=extras[appearance]
                        manifest=json.loads((ROOT/f'assets/characters/crossgate/{bank}/motions.json').read_text())
                        assert int(manifest['variants'][skin]['id'])==appearance
                        height=approved_height(bank,skin,manifest)
                    indices[appearance]=len(species)
                    species.append(dict(id=appearance,name=base[0],bank=bank,skin=skin,
                                        height=height))
                index=indices[appearance]
                members.append([index,int(enemy[4]),int(enemy[5]),member_weight])
                identities.append(dict(enemy_id=eid,name=base[0],count=list(map(int,enemy[6:8])),mandatory=source[25+j]=='1'))
                details.append(dict(species=index,enemy=eid,name=base[0],raw_enemy=enemy,raw_base=base))
            key='wind:'+gid
            group=dict(members=members,raw=source,source_group=gid,order=source[1],source_members=identities,details=details)
            if key in groups: assert groups[key]==group
            groups[key]=group; choices.append([key,weight])
        record=dict(id=ident,map=int(raw[3]),bounds=list(map(int,raw[4:8])),probability=list(map(int,raw[8:10])),
                    maximum=int(raw[10]),minimum=1,priority=int(raw[11]),groups=choices,raw=raw,
                    wind_tower_source=True,next_encounter=int(raw[12]or 0),next_probability=int(raw[13]or 0),
                    follow_on=dict(encounter=raw[12],weight=raw[13],execution_verified=False))
        if ident in SCRIPT_ENCOUNTERS: bosses[str(ident)]=record
        else: zones.append(record)
    assert len(zones)==14 and len(groups)==19 and set(map(int,bosses))==SCRIPT_ENCOUNTERS
    used=sorted({m[0] for g in groups.values() for m in g['members']}); contracts=[]
    for index in used:
        s=species[index]; bank='guard_pets' if s['bank']=='companion' else s['bank']
        path=ROOT/f'assets/characters/crossgate/{bank}/motions.json'; manifest=json.loads(path.read_text())
        assert int(manifest['variants'][s['skin']]['id'])==int(s['id'])
        contracts.append(dict(index=index,appearance=s['id'],bank=bank,skin=s['skin'],
                              motions_sha256=recovery.digest(path.read_bytes()),
                              frame_table_sha256=recovery.digest(path.with_name('frames.bin').read_bytes()),
                              qualification='Existing exact appearance ID. Source-frame/contact/native/rendered verification remains required.'))
    assert len(contracts)==14
    return dict(schema=1,species=species,reused_species=[dict(index=i,**species[i]) for i in used],
                zones=zones,bosses=bosses,groups=groups,art_contracts=contracts,
                source_hashes={n:recovery.digest((TABLES/n).read_bytes()) for n in ['encount.txt','group.txt','enemy.txt','enemybase.txt']},
                map_assessment={str(n):dict(ambient_rows=[z['id'] for z in zones if z['map']==n],
                    qualification='No ambient rows is not proof of a safe zone; retained script fights and original event conditions own those cases.') for n in sorted(IDS)},
                limits=['Staged source data only; no enemy pool or travel activation.',
                        'Retain per-zone weights, source identities, mandatory flags, member bounds and total caps under the existing native owner.',
                        'Original AI, formation, encounter probability denominator, follow-on selection and scripted flags remain separately unverified.'])


def prepare(output=OUT):
    table_refs={r['file']:r for r in json.loads((TABLES/'references.json').read_text())}
    table_refs={n:table_refs[n] for n in ['npc.txt','msg.txt','encount.txt','group.txt','enemy.txt','enemybase.txt']}
    for name,proof in table_refs.items():
        assert recovery.digest((TABLES/name).read_bytes())==proof['sha256'],name
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    from build_falan_room_art import KIND,PALACE_KIND,CELLAR_KIND,CIVIC_KIND,ARENA_KIND,FREYJA_KIND
    from build_coastal_villages import KINDS,WALLS
    furniture={**KIND,**PALACE_KIND,**CELLAR_KIND,**CIVIC_KIND,**ARENA_KIND,**FREYJA_KIND,**KINDS}
    furniture.update({n:'room_wall' for n in WALLS if n>=16000})
    lookup=lib.serial_index(); shared={}; owners={}; protected={}
    for name in CATALOGS:
        path=ROOT/name; catalog=json.loads(path.read_text()); protected[name]=recovery.digest(path.read_bytes())
        for key,graphic in catalog['graphics'].items():
            if key not in shared: shared[key]=graphic; owners[key]=name
    graph=json.loads((REPORT.parent/'Source events/source-graph.json').read_text())
    refs=json.loads((SOURCE/'wind-tower-references.json').read_text()); maps={}; evidence=[]; used=set()
    with lib.connection() as db:
        files={r['path']:r['id'] for r in db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    for proof in refs:
        number=int(proof['file'].split('_')[0]); assert number in IDS
        server=(SOURCE/proof['file']).read_bytes(); assert recovery.digest(server)==proof['sha256']
        path=f'BlueCrossgate/map/0/{number}.dat'; raw=lib.source_file(files[path])[1].read_bytes()
        restored,completion=complete_map(raw,server,number)
        assert completion['compatible'] and completion['layout_complete'] and not completion['preserved_client_variations']
        w,h,ground,objects,flags=lib.parse_map(restored); _,_,values,title=reference_map(server,number)
        assert tuple(ground)+tuple(objects)==values
        serials={s for s in ground if s}|{s for s in objects if s>=1000}; used.update(serials)
        walk=navigation_grid(w,h,ground,objects,lookup); bits=bytearray((w*h+7)//8)
        for i,opened in enumerate(walk):
            if opened: bits[i>>3]|=1<<(i&7)
        maps[path]=dict(group='sokia_wind_tower',id=number,title=title,size=[w,h],outdoor=number in [301,302],
            raw=recovery.encode(raw),sha256=recovery.digest(raw),restored_raw=recovery.encode(restored),
            restored_sha256=recovery.digest(restored),bytes=len(raw),walk=recovery.encode(bits),
            recorded=completion['recorded'],cells=w*h,restored_cells=completion['completed'],layout_complete=True,
            warp_cells=[[i%w,i//w] for i,value in enumerate(flags) if value&2],layout_reference=proof,
            source_floor_object_sha256=recovery.digest(server[44:]),source_flags_available=True,sokia_visual_only=True,
            fixed_port_candidates=[r for r in graph['fixed_warps'] if r['source_map']==number],
            gate_status='Staged only; original source entry/chat/item conditions, native travel, source fights and scenery still require verification.')
        evidence.append(dict(id=number,title=title,completion=completion,source=proof,
                             client_sha256=recovery.digest(raw),client_flags_preserved=True,decoder_open_cells=sum(walk)))
    assert {m['id'] for m in maps.values()}==IDS
    assert sum(m['restored_cells'] for m in maps.values())==76093
    novel=used-set(map(int,shared)); assert len(used)==600 and len(novel)==78
    pixel_proofs={}
    for serial in sorted(used):
        native=lookup[serial]; image=lib.image_from_record(native['pack'],native['row']); digest=recovery.digest(image.tobytes())
        if str(serial) in shared:
            graphic=shared[str(serial)]
            assert digest==graphic['rgba_sha256'],serial
            assert graphic['origin']==[native['x'],native['y']] and graphic['footprint']==[native['east'],native['south']],serial
        pixel_proofs[str(serial)]=dict(pack=native['pack'],row=native['row'],rgba_sha256=digest)
    pages,graphics,_=recovery.pack_graphics(novel,lookup,furniture,lib)
    surfaces=recovery.rock_surfaces(dict(graphics=graphics),pages); solids=solid_pages(graphics,pages)
    catalog=dict(schema=1,page_indices='local',surface_indices='local',maps=maps,graphics=graphics,
        pages=[f'sokia_wind_tower/atlas-{i}.png' for i in range(len(pages))],
        surface_pages=[f'sokia_wind_tower/surfaces-{i}.png' for i in range(len(surfaces))],
        solid_pages=[f'sokia_wind_tower/solid-{i}.png' for i in range(len(solids))],requires=['east'],
        reused_graphics={str(s):owners[str(s)] for s in sorted(used-novel)})
    npcs=source_actors(output/'events'); roster=encounters()
    proof=dict(source_scope=sorted(IDS),maps=evidence,source_tables=table_refs,protected_catalog_sha256=protected,
        source_graphics=pixel_proofs,reused_graphics=len(used-novel),new_graphics=len(novel),
        original_graphics_repacked=0,
        fixed_ports=[r for r in graph['fixed_warps'] if r['source_map'] in IDS],
        branch_boundary_ports=[r for r in graph['fixed_warps'] if (r['source_map'] in IDS)!=(r['target_map'] in IDS)],
        entry_events=[r for r in graph['event_warps'] if str(r['npc'])=='6267'],
        event_warps=[r for r in graph['event_warps'] if r['source_map'] in IDS],
        scripted_fights=[r for r in graph['fight_triggers'] if r['source_map'] in IDS],
        activation='Review-only source candidate; runtime registration, native fights and visual approval are separate evidence.',
        missing_maps=[],missing_enemy_assets=[],
        unverified_encounter_rules=[
            'Original encounter probability denominator, party-size distribution and follow-on fields (including301zone2003) are unverified. Exact group ticket weights alone do not prove original frequency.',
            'Original ordered AI/techniques, formation and real-time combat adaptation require source-specific review.',
            'StandEnemy original scheduling, defeat/escape/repeat/cooldown semantics remain unverified; native proximity triggers and Arcas victory transfer have separate runtime evidence.',
            'Full source-frame and rendered validation of all14appearances remains required; existing bank IDs/file hashes are not visual certification.'],
        unverified_event_rules=[
            'Natural item18575 acquisition through priest6326 on existing map3300 and its prerequisite quest flags remain unverified. Entry/return item and exact17034phrase predicates have separate ordinary F/chat evidence.',
            'Original input that produces the nine literal R transport guards is unverified. Both18566item branches and all18destinations have separate runtime evidence using explicit fixture chat input.',
            'Natural item18566 drops from source enemies10041/10050 are not integrated; raw drop rate100 has an unverified denominator. Do not substitute a free or guaranteed grant.',
            'Post-Arcas BImage, EndEvent19, LeaveGroup context and exact1530return have separate runtime checks; full original quest/service parity and guardian idle presentation remain unverified.'],
        native_bank_integration_pending=[dict(appearance=s['id'],bank=s['bank'],skin=s['skin'],
            reason='Existing source art requires the established shared East bank append workflow before East.available can dispatch it.')
            for s in roster['reused_species'] if s['bank'] not in ['east_region','companion']],
        remaining=['Natural quest prerequisites and original R input semantics; no invented reverse Sokia entry or free item.',
                   'Original encounter frequency, AI, StandEnemy scheduling/repeat/escape and remaining quest/service rules.',
                   'Independent original-frame and clean rendered motion review for all14enemy appearances.',
                   'Full fixed gameplay-camera scenery review; source pixels alone do not approve inferred3D surfaces.'])
    images={**{f'atlas-{i}.png':p for i,p in enumerate(pages)},
            **{f'surfaces-{i}.png':p for i,p in enumerate(surfaces)},
            **{f'solid-{i}.png':p for i,p in enumerate(solids)}}
    return catalog,roster,npcs,images,proof


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,default=OUT)
    parser.add_argument('--native-bank',action='store_true',help='Stage the five missing shared-bank appearances using existing immutable source pages.')
    args=parser.parse_args();args.output=args.output.resolve()
    if args.native_bank:
        report=stage_native_bank(args.output)
        (args.output/'preservation.json').write_text(json.dumps(report,indent=2)+'\n')
        print('WIND_NATIVE_STAGED',report['previous_variants'],'to',report['variants'],'variants; old indices and metadata preserved')
        return
    catalog,roster,npcs,images,proof=prepare(args.output)
    for name,data in [('catalog.json',catalog),('encounters.json',roster),('events/data.json',npcs),('source-preservation.json',proof)]:
        path=args.output/name; path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    for name,image in images.items(): image.save(args.output/name)
    print('SOKIA_WIND_TOWER_STAGED',len(catalog['maps']),'maps; 76093 completed cells; 522 reused and 78 recovered graphics; 14 zones, 19 groups, 16 actors. Gameplay/visual/rules remain pending.')


if __name__=='__main__': main()
