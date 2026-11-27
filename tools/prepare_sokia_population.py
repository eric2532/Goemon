"""Prepare the source regional actors and encounters for the existing population owner."""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image
from prepare_snow_region_population import rows,SOURCE,ARCHIVE,ROOT
from build_freyja_destinations import load_map
OUT=ROOT/'assets/maps/falan/sokia'

def prepare():
    for proof in json.loads((SOURCE/'references.json').read_text()):
        assert hashlib.sha256((SOURCE/proof['file']).read_bytes()).hexdigest()==proof['sha256'],proof['file']
    sys.path.insert(0,str(ARCHIVE/'tools'))
    import cg_assets as cg
    import cg_library as lib
    lookup=lib.serial_index();catalog=cg.catalog()['entries'];keys={}
    for r in catalog:
        if r['key'].startswith('original:'):keys.setdefault(r['id'],r['key'])
    for r in catalog:
        if r['key'].startswith('original:') and 2800<=int(r['key'].split(':')[1])<3000:keys[r['id']]=r['key']
    base=json.loads((ROOT/'assets/maps/falan/south_kili_route/population.json').read_text())
    from recover_habaru_encounter import body_rows
    def source_body_pixels(key):
        _,_,clips=cg.actor(key)
        idle=next(c for c in clips if c['action']==0 and c['direction']==4)
        top,foot=body_rows(cg.frame_parts(key,idle['index'],0)[0])
        return foot-top
    reference_pixels=source_body_pixels('ex:1727')
    extra=[dict(id=ident,name=name,key=keys[ident],height=height,skin=i,family='sokia_region') for i,(ident,name,height) in enumerate([(101020,'大地鼠',.55),(101022,'火焰鼠',.55),(101330,'土蜘蛛',.6),(101332,'火蜘蛛',.6),(101720,'地龍蜥',.8),(101722,'火龍蜥',.8),(101301,'紅蠍',.6)])]
    for ident,name in [(101211,'血魔'),(101613,'謎之箱'),(101214,'守護者'),(101921,'最終決戰型牛鬼')]:
        pixels=source_body_pixels(keys[ident])
        extra.append(dict(id=ident,name=name,key=keys[ident],height=pixels/reference_pixels,skin=len(extra),family='sokia_region',source_body_pixels=pixels,source_scale_reference=dict(key='ex:1727',body_pixels=reference_pixels)))
    # Reuse existing family fits; latest original ghost row has coherent eight-facing art.
    for ident,name,key,height,pixels,fit in [(101031,'巨狼','original:2819',83*1.4/78,83,'existing hounds HOUND_PIXEL_SIZE*HOUND_SCALE'),(101121,'鬼靈','original:2833',1.15,52,'existing black_prayer explore HEIGHTS[2]')]:
        assert source_body_pixels(key)==pixels,(ident,key)
        extra.append(dict(id=ident,name=name,key=key,height=height,skin=len(extra),family='sokia_region',source_body_pixels=pixels,fit_reference=fit))
    extra[-1]['native_action_sources']={'3':1}
    extra[-1]['native_action_adaptation']='Original2833 run3 is one transparent frame in each direction; native continuous locomotion reuses the same actor\'s original walk1. Raw run3 remains in the untouched archive.'
    from prepare_sokia_cape_bank import records as cape_records
    for record in cape_records():extra.append({**record,'skin':len(extra),'family':'sokia_region'})
    from prepare_sokia_scripted_actors import records as scripted_records
    for record in scripted_records():extra.append({**record,'skin':len(extra),'family':'sokia_region'})
    mountain_skins={r['id']:len(base['species'])+i for i,r in enumerate(extra)}
    scopes={area:row['bounds'] for area,row in json.loads((OUT/'provenance.json').read_text())['regions'].items()}
    x,y,cw,ch=scopes['sokia_coast']
    def within(xx,yy):return any(x<=xx<x+w and y<=yy<y+h for x,y,w,h in scopes.values())
    from prepare_sokia_fixed_maps import MAPS
    ghana_maps=[3000,3001,3002,3008,3010,3012,3013,3014,3020,3021,3099,3350,3352]
    maps={n:load_map(lib,n) for n in [300,*MAPS,*ghana_maps]}
    existing=json.loads((ROOT/'build/Other Files/Asset Toolkit/Sokia Region Reconstruction/runtime-before.json').read_text())
    reconciled=[]
    npcs=[];skipped=[];art={};images={}
    for raw in rows('npc.txt'):
        if len(raw)<25 or not raw[8].isdigit() or int(raw[8]) not in maps or not raw[9].isdigit() or not raw[10].isdigit():continue
        number=int(raw[8]);xx,yy=map(int,raw[9:11])
        if number==300 and not within(xx,yy) or raw[0] in ['Warp','HouseWarp2']:continue
        if raw[6]!='1' or not raw[20].isdigit() or int(raw[20])<=1 or int(raw[3])>=300000:
            skipped.append(dict(id=raw[3],name=raw[1],cell=[xx,yy],reason='Inactive, invisible or later event record; no visible actor invented.'));continue
        if any(r['source']==number and r['id']==raw[3] for r in base['npcs']):continue
        old=next((npc for area in existing if (area['area']=='ghana' and number==3000 or area['area']=='interior' and int(area['floor'])==number) for npc in area['npcs'] if npc['cell']==[xx,yy]),None)
        if old is not None:
            reconciled.append(dict(id=raw[3],name=raw[1],map=number,cell=[xx,yy],existing_name=old['name']));continue
        graphic=int(raw[20]);direction=int(raw[19])%8;token=f'sokia:{graphic}:{direction}'
        if token not in images:
            if graphic in lookup and (graphic<100000 or raw[0]=='Billboard'):
                g=lookup[graphic];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic}'
            else:
                key=keys[graphic];_,_,clips=cg.actor(key)
                idle=[c for c in clips if c['action']==0]
                clip=next((c for c in idle if c['direction']==direction),None)
                if clip is None:
                    assert {c['direction'] for c in idle}=={0},('Missing original drawn facing',raw[3],direction)
                    clip=idle[0]  # The animated transfer sign has no directional variants.
                im,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=im.getbbox();assert box,token
            images[token]=im.crop(box)
            art[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=hashlib.sha256(images[token].tobytes()).hexdigest())
        width,_,_,objects,_=maps[number]
        npcs.append(dict(id=raw[3],name=raw[1],type=raw[0],area='sokia_coast' if number==300 else 'ghana' if number==3000 else 'interior',floor=0 if number in [300,3000] else number,source=number,cell=[xx,yy],direction=direction,graphic=graphic,token=token,
            scenery=graphic<14000 or raw[0] in ['HouseMaster','Dengon','Billboard','Windowman'],rendered_elsewhere=objects[yy*width+xx]==graphic,
            atlas_path='res://assets/maps/falan/sokia/npc-atlas.png',night_only=raw[3] in ['6117','6131','6315','6316','6317'],messages=['這裡的詳細對話尚待恢復。'],raw=raw))
        if raw[3] in ['5243','5305']:npcs[-1]['quest_action']='sokia_cape:'+raw[3]
        if raw[3] in ['5243','5305']:
            _,_,native_clips=cg.actor(art[token]['key'])
            native_idle=next(c for c in native_clips if c['action']==0 and c['direction']==direction)
            native_frame,_,_=cg.frame_parts(art[token]['key'],native_idle['index'],0)
            native_box=native_frame.getbbox();top,foot=body_rows(native_frame)
            npcs[-1].update(map_body_foot_row=foot-native_box[1],map_body_top_row=top-native_box[1],map_raw_origin=art[token]['origin'],
                map_foot_contract='Existing body_rows excludes the original charcoal shadow; body feet align with the unchanged source-cell ground anchor. Native combat keeps its separate10px convention.')
    assert len({r['id'] for r in npcs})==len(npcs)
    atlas=Image.new('RGBA',(1024,4096));ax=ay=rh=0
    for token,im in images.items():
        if ax+im.width+2>1024:ax=0;ay+=rh;rh=0
        atlas.paste(im,(ax+1,ay+1));art[token]['rect']=[ax+1,ay+1,*im.size];ax+=im.width+2;rh=max(rh,im.height+2)
    atlas=atlas.crop((0,0,1024,ay+rh))
    enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')};source_groups={r[2]:r for r in rows('group.txt')}
    skins={r['id']:i for i,r in enumerate(base['species'])};groups={};zones=[]
    for raw in rows('encount.txt'):
        number=int(raw[3]);mountain=13002<=number<=13014 or 13500<=number<=13502 or number==15526
        if number not in {*MAPS,300,13001}:continue
        bounds=list(map(int,raw[4:8]))
        if number==300 and not any(not(bounds[2]<x or bounds[0]>=x+w or bounds[3]<y or bounds[1]>=y+h) for x,y,w,h in scopes.values()):continue
        selected=[]
        for i,gid in enumerate(raw[14:24]):
            weight=int(raw[24+i] or 0)
            if not gid or not weight:continue
            g=source_groups[gid];members=[]
            for j,eid in enumerate(g[5:15]):
                if not eid or eid=='0' or not int(g[15+j] or 0):continue
                enemy=enemies[eid];species=int(bases[enemy[3]][30])
                palette={**skins,**mountain_skins} if mountain else skins
                assert species in palette,('Missing native appearance',number,species)
                members.append([palette[species],int(enemy[4]),int(enemy[5]),int(g[15+j])])
            group_key=f'mountain:{gid}' if mountain else gid
            record=dict(members=members,raw=g,order=g[1],source_group=gid)
            if group_key in groups:assert groups[group_key]==record,group_key
            groups[group_key]=record;selected.append([group_key,weight])
        zones.append(dict(id=int(raw[0]),map=number,bounds=bounds,probability=list(map(int,raw[8:10])),maximum=int(raw[10]),priority=int(raw[11]),groups=selected,raw=raw))
    data=dict(schema=1,area='sokia_coast',bounds=[x,y,cw,ch],outdoor_bounds=scopes,npcs=npcs,art=art,skipped=skipped,reconciled=reconciled,zones=zones,groups=groups,extra_species=extra,base_species_count=len(base['species']),
        source_hashes={n:hashlib.sha256((SOURCE/n).read_bytes()).hexdigest() for n in ['npc.txt','encount.txt','group.txt','enemy.txt','enemybase.txt']},
        limits=['Pinned server records corroborate identities, coordinates and encounter distributions; original BlueCG server execution is unavailable.','Dialogue is one placeholder line. Conditional corpse/mountain quest warps are not replaced with unconditional shortcuts.','Existing native group spawning, shuffled outcome bags, combat and special fights remain authoritative.'],
        gorge_corridor=dict(map=15526,ambient_zones=[7044,7045],source_groups=['7033','7034','7035','7036'],pending=['Generated configs305/306 each have ten source-contract floors through the existing generator; original procedural topology remains unrecovered.','NPC5305 encounter12020 resolves through encount.txt to group12098: Lorens101532 with two100553 and two100678 soldiers; original barrier and post-victory landing remain authoritative.','Native ambient combat uses species/level adaptation; distinct source enemy/base IDs remain in raw groups and are not yet native stat bindings.']))
    return atlas,data

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');p.add_argument('--pack',action='store_true');a=p.parse_args();atlas,data=prepare()
    if a.check:
        assert Image.open(OUT/'npc-atlas.png').tobytes()==atlas.tobytes()
        assert json.loads((OUT/'population.json').read_text())==data
    else:
        atlas.save(OUT/'npc-atlas.png');(OUT/'population.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        if a.pack:
            from recover_habaru_encounter import recover
            recover(ARCHIVE,shalena=True,species_override=data['extra_species'][:13],output_override=ROOT/'assets/characters/crossgate/sokia_region')
            from prepare_sokia_cape_bank import prepare as append_cape_bank
            append_cape_bank()
            from prepare_sokia_scripted_actors import append_scripted_actors
            append_scripted_actors()
    print('SOKIA_POPULATION_SOURCE_CHECK actors=',len(data['npcs']),'zones=',len(data['zones']),'groups=',len(data['groups']))
if __name__=='__main__':main()
