"""Supplement regional NPCs without changing the existing snow-region residents or dialogue."""
import hashlib
import json
import sys
import base64
import zlib
from collections import deque
from pathlib import Path
from PIL import Image
import review_university_region as review

ROOT=review.ROOT
OUT=ROOT/'assets/maps/falan/university_region'
TABLES=ROOT/'assets/references/crossgate_tina/events'
# Existing native boss actors retain presentation ownership; post-fight residents are separate records.
NATIVE_ACTORS={'6402','6403','6404','6405','6406','6337','808122','1102307','1102309','1102310','1102311'}
QUEST_ACTIONS={'6392':'decree_strawberry','6399':'decree_cellar','6397':'decree_past',
               '6394':'decree_blade','6407':'decree_present','6450':'decree_return',
               '6735':'azure_wall','6251':'lake_jump',
               '6457':'region_boss_altar','6464':'region_boss_ruby','6465':'region_boss_fribo',
               '5251':'region_boss_doctor','5269':'region_boss_abyss','1102643':'region_boss_azure',
               '1102642':'azure_medicine','5245':'doctor_researcher','6330':'beast_key','6331':'beast_entry',
               '6334':'beast_grayson','6453':'east_priest','5202':'cabin_return','5268':'ice_entrance',
               '5272':'abyss_approach','5266':'white_messenger','5267':'black_messenger',
               '5247':'doctor_ghoul','5252':'doctor_bars','5248':'doctor_kick','6470':'ruby_reward',
               '808112':'region_boss_sylph','808113':'sylph_reward',
               '6458':'altar_priest','6466':'prison_flag','6467':'prison_complete',
               '5408':'lizard_hospital',
               '6342':'beast_witch_room','6345':'beast_monk_room','6343':'beast_witch_exit',
               '6736':'book_research','6562':'abanis_teleport','6339':'jenova_teleport',
               '6154':'curse_password','6159':'curse_master_entry','6152':'curse_recommendation',
               '6335':'beast_story','6378':'astia_entry',
               '1102305':'hall_ami',
               '1102658':'four_beast_memory','1102730':'tina_child_return',
               '6933':'decree_shanti','6934':'decree_shanti_return','6920':'decree_shanti_shop','807220':'decree_shanti_bonus_shop',
               '6740':'music_secret',
               **{str(6408+i):f'decree_reward_{i}' for i in range(5)}}


def prepare_sylph_ownership(catalog):
    """Only the two local Sylph chambers on the shared holding map belong to this region."""
    row=catalog['maps']['BlueCrossgate/map/0/59752.dat'];width,height=row['size']
    original=zlib.decompress(base64.b64decode(row['walk']));mask=bytearray(len(original));bounds=[];sizes=[]
    for anchor in [(100,112),(130,143)]:
        queue=deque([anchor]);seen={anchor}
        while queue:
            x,y=queue.popleft()
            for xx,yy in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                index=yy*width+xx
                if 0<=xx<width and 0<=yy<height and (xx,yy) not in seen and original[index>>3] & (1<<(index&7)):
                    seen.add((xx,yy));queue.append((xx,yy))
        assert 0<len(seen)<500,'Do not claim the other holding-map quests'
        for x,y in seen:
            index=y*width+x;mask[index>>3]|=1<<(index&7)
        bounds.append([min(x for x,y in seen)-2,min(y for x,y in seen)-2,max(x for x,y in seen)+3,max(y for x,y in seen)+3]);sizes.append(len(seen))
    result={'59752':dict(size=[width,height],open=base64.b64encode(zlib.compress(mask)).decode(),bounds=bounds,
                        chamber_walk_cells=sizes,layout_sha256=row['restored_sha256'],
                        limits='Adds only the source Sylph arena and post-fight room; existing Elsa ownership remains authoritative elsewhere.')}
    text=json.dumps(result,ensure_ascii=False,indent=2)+'\n';path=OUT/'sylph_ownership.json'
    if not path.exists() or path.read_text()!=text:path.write_text(text)


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_assets as cg
    import cg_library as lib
    lookup=lib.serial_index();actors=cg.catalog()['entries']
    scope=json.loads((review.OUT/'scope.json').read_text())
    maps={r['source']:r['runtime'] for r in scope['fixed']}
    catalog=json.loads(review.CATALOG.read_text())
    catalog['maps'].update(json.loads((ROOT/'assets/maps/original_crossgate/university/catalog.json').read_text())['maps'])
    shared_elsa=json.loads((ROOT/'assets/maps/original_crossgate/elsa/catalog.json').read_text())
    catalog['maps'].update(shared_elsa['maps'])
    prepare_sylph_ownership(shared_elsa)
    previous=json.loads((ROOT/'assets/maps/falan/snow_region/population.json').read_text())
    existing={r['id'] for r in previous['npcs']}
    lines={}
    for line in (TABLES/'msg.txt').read_bytes().decode('gb18030').splitlines():
        row=line.split('\t')
        if len(row)>1:lines[row[0]]=row[1].replace('\\n','\n').replace('@c','')
    images={};art={};npcs=[];blocked=[];inactive=[];aliases=[]
    anchors={(int(r['source']),*r['cell'],int(r['graphic'])):r['id'] for r in previous['npcs']}
    for line in (TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines():
        row=line.split('\t')
        if len(row)!=25 or not row[8].isdigit() or int(row[8]) not in maps:continue
        ident=row[3];source,x,y=map(int,[row[8],row[9],row[10]])
        if source==400 and not(110<=x<620 and 170<=y<480):continue
        if source==4100 and not(45<=x<78 and 115<=y<140):continue
        if row[0].startswith('#') or row[6]!='1':
            inactive.append(dict(id=ident,source=source,cell=[x,y],name=row[1],reason='Commented or inactive source record; never spawn it.'));continue
        # This shared event holding map contains unrelated journeys in disconnected rooms.
        if source==59752 and ident not in ['808112','808113']:continue
        if row[0] in ['Warp','HouseWarp2'] or ident in existing or ident in NATIVE_ACTORS:continue
        if row[0]=='StandEnemy':continue
        if not row[1] and row[0] not in ['Event','Billboard']:
            blocked.append(dict(id=ident,source=source,cell=[x,y],reason='Unnamed event marker requires its original trigger semantics.'));continue
        path=f'BlueCrossgate/map/0/{source}.dat'
        if path not in catalog['maps']:
            blocked.append(dict(id=ident,source=source,cell=[x,y],name=row[1],reason='Its runtime layout is unavailable.'));continue
        # Existing identities above remain authoritative. Newly recovered approach actors are additive.
        if source==4400:
            import base64,zlib
            m=catalog['maps'][path];walk=zlib.decompress(base64.b64decode(m['walk']))
            if not any(walk[(yy*150+xx)>>3] & (1<<((yy*150+xx)&7)) for yy in range(max(0,y-1),min(200,y+2)) for xx in range(max(0,x-1),min(150,x+2))):
                blocked.append(dict(id=ident,source=source,cell=[x,y],name=row[1],reason='Campus snapshot has no recorded walkable ground in original talk range.'));continue
        graphic=int(row[20]);direction=int(row[19])%8;token=f'{graphic}:{direction}'
        anchor=(source,x,y,graphic)
        if anchor in anchors:
            aliases.append(dict(id=ident,owner=anchors[anchor],source=source,cell=[x,y],name=row[1],reason='Same original graphic and anchor; keep one actor and preserve its working dialogue.'));continue
        if token not in images:
            if graphic in [0,1]:im=Image.new('RGBA',(1,1));ox=oy=0;key='invisible source event'
            elif graphic<100000 and graphic in lookup:
                g=lookup[graphic];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic}'
            else:
                choices=[a['key'] for a in actors if a['id']==graphic]
                if not choices:
                    blocked.append(dict(id=ident,source=source,cell=[x,y],name=row[1],reason='Original actor art unavailable.',graphic=graphic));continue
                choices.sort(key=lambda k:0 if k.startswith('original:') and 2800<=int(k.split(':')[1])<3000 else 1)
                clip=None
                for key in choices:
                    _,_,clips=cg.actor(key)
                    clip=next((c for c in clips if c['action']==0 and c['direction']==direction),None)
                    if clip is not None:break
                if clip is None:
                    blocked.append(dict(id=ident,source=source,cell=[x,y],name=row[1],reason='Recorded idle facing unavailable.',graphic=graphic,direction=direction));continue
                im,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=im.getbbox() or (0,0,1,1);im=im.crop(box);images[token]=im
            art[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
        messages=[lines[v] for v in row[24].split('|') if v in lines] if row[0]=='TownPeople' else ['你好。']
        record=dict(id=ident,type=row[0],name=row[1] or '原始事件',floor=maps[source],source=source,cell=[x,y],direction=direction,
                    graphic=graphic,token=token,scenery=graphic<14000,messages=messages or ['你好。'],raw=row)
        if not row[1] and row[0]=='Billboard':record['scenery_only']=True
        if ident in QUEST_ACTIONS:record['quest_action']=QUEST_ACTIONS[ident]
        if source in range(20501,20531) and row[24]=='EV_aoki_6582.txt' or row[24]=='EV_aoki_6565.txt' or source in range(20501,20531) and row[1]=='烛台':record['quest_action']='ice:'+ident
        npcs.append(record)
        anchors[anchor]=ident
    places={};xx=yy=rh=0
    for token,im in images.items():
        if xx+im.width+2>1024:xx=0;yy+=rh;rh=0
        places[token]=(xx+1,yy+1);art[token]['rect']=[xx+1,yy+1,*im.size];xx+=im.width+2;rh=max(rh,im.height+2)
    atlas=Image.new('RGBA',(1024,max(1,yy+rh)))
    for token,im in images.items():atlas.paste(im,places[token])
    assert atlas.height<=16384,'Split the existing NPC atlas format before exceeding the renderer limit'
    OUT.mkdir(parents=True,exist_ok=True);atlas.save(OUT/'npc-atlas.png')
    result=dict(schema=1,npcs=npcs,art=art,blockers=blocked,inactive_records=inactive,aliases=aliases,
                source_hashes={n:hashlib.sha256((TABLES/n).read_bytes()).hexdigest() for n in ['npc.txt','msg.txt']},
                limits=['Native single-view art preserves original pixels/offsets; missing directional or quest behavior is not invented.',
                        'The existing snow-region NPC file and working dialogue remain authoritative for their residents.'])
    (OUT/'population.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('UNIVERSITY_NPCS',len(npcs),'art',len(art),'atlas',atlas.size,'reference_gaps',len(blocked))


if __name__=='__main__':main()
