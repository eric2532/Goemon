"""Prepare bounded, reference-backed snow-region NPCs and encounter pools. Preserve source art."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/crossgate_tina/events'
OUT=ROOT/'assets/maps/falan/snow_region'
ARCHIVE=ROOT.parent/'Magic Power'
MAPS={4000:51004,400:51031,14000:14000,14001:14001,14002:14002,402:51032,4300:51011,4400:51012,15522:15522}

def rows(name):
    return [r.split('\t') for r in (SOURCE/name).read_bytes().decode('gb18030').splitlines() if r and not r.startswith('#')]

def build(pack=False):
    proofs=json.loads((SOURCE/'references.json').read_text())
    for proof in proofs:
        assert hashlib.sha256((SOURCE/proof['file']).read_bytes()).hexdigest()==proof['sha256'],proof['file']
    sys.path.insert(0,str(ARCHIVE/'tools'))
    import cg_assets as cg
    import cg_library as lib
    lookup=lib.serial_index()
    catalog=cg.catalog()['entries']
    keys={}
    for r in catalog:
        if r['key'].startswith('original:') and 2800<=int(r['key'].split(':')[1])<3000:keys[r['id']]=r['key']
    base=json.loads((ROOT/'assets/maps/falan/tina/encounters.json').read_text())['species']
    species=base+[dict(id=i,key=keys[i],name=n,height=h) for i,n,h in [(101004,'惡魔貓',1.4),(101253,'胖蝙蝠',.85),(101101,'喪屍',1.),(101413,'冰之人魔草',.8),(101501,'變種液態史萊姆',.7)]]
    skins={s['id']:i for i,s in enumerate(species)}
    enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')};groups={r[2]:r for r in rows('group.txt')}
    zones=[];group_data={};blockers=[]
    for row in rows('encount.txt'):
        if int(row[3]) not in [400,402,14000,14001,14002,15522]:continue
        chosen=[]
        for i,gid in enumerate(row[14:24]):
            weight=int(row[24+i] or 0)
            if not gid or not weight:continue
            g=groups[gid];members=[]
            for j,eid in enumerate(g[5:15]):
                member_weight=int(g[15+j] or 0)
                if eid in ['', '0'] or not member_weight:continue
                e=enemies[eid];appearance=int(bases[e[3]][30])
                members.append([skins[appearance],int(e[4]),int(e[5]),member_weight])
            # Conditional inventory/event fields need their original runtime semantics.
            if gid!='12089' and any(v not in ['', '0','-1'] for v in g[25:]):
                blockers.append(dict(kind='conditional_group',group=gid,raw=g));continue
            group_data[gid]=dict(members=members,order=g[1],raw=g)
            if gid=='12089':
                # Original quest reference documents one ice alraune with three mutant liquid slimes.
                assert [m[0] for m in members]==[19,20]
                group_data[gid]['fixed']=[[19,51],[20,49],[20,49],[20,49]]
                group_data[gid]['reference']='https://cg.skyey.tw/errand/macc01.htm'
            chosen.append([gid,weight])
        zones.append(dict(id=int(row[0]),map=int(row[3]),bounds=list(map(int,row[4:8])),probability=list(map(int,row[8:10])),maximum=int(row[10]),priority=int(row[11]),groups=chosen,raw=row))
    # Preserve the current two generated floors' documented zombie/hound identities and levels.
    # Their original random-dungeon config cannot be mapped to these two adapted floor numbers.
    for floor in [51009,51010]:
        zones.append(dict(id=floor,map=floor,bounds=[0,0,32,26],probability=[1,3],maximum=6,priority=1,groups=[['mountain-mixed',1],['mountain-zombie',1],['mountain-hound',1]],adapted=True))
    group_data.update({'mountain-mixed':dict(members=[[18,39,42,1],[1,39,42,1]],order=''), 'mountain-zombie':dict(members=[[18,39,42,1]],order=''), 'mountain-hound':dict(members=[[1,39,42,1]],order='')})
    boundary=json.loads((ROOT/'build/Other Files/Asset Toolkit/Snow Region/boundary.json').read_text())
    stages={r['source']:r for r in boundary['stages'] if r['source'] is not None}
    def in_scope(floor,x,y):
        stage=stages[floor];a,b,w,h=stage['bounds']
        if not(a<=x<a+w and b<=y<b+h):return False
        return any(z==y and lo<=x<=hi for z,lo,hi in stage['reachable_spans'])
    messages={r[0]:r[1].replace('\\n','\n').replace('@c','') for r in rows('msg.txt') if len(r)>1}
    npcs=[];skipped=[];images={};art={}
    import review_west_snow_route as review
    original_maps=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    campus=review.decode(4400,original_maps)
    for row in rows('npc.txt'):
        if len(row)<25 or not row[8].isdigit() or int(row[8]) not in MAPS or not row[9].isdigit() or not row[10].isdigit():continue
        floor,x,y=map(int,[row[8],row[9],row[10]])
        if row[0] in ['Warp','HouseWarp2']:continue
        if floor in [400,402] and not in_scope(floor,x,y):continue
        # Later private-server/event objects are not evidence of the classic population.
        if int(row[3])>=1000000 or row[6]!='1' or row[0] in ['WatchEx','Billboard'] and not row[1]:
            skipped.append(dict(id=row[3],map=floor,cell=[x,y],name=row[1],reason='Later event/private-server object or inactive/unnamed record; original presence uncorroborated.'));continue
        if floor==4400 and row[20]!='1' and not any(campus['walk'][yy*campus['width']+xx] for yy in range(max(0,y-1),min(campus['height'],y+2)) for xx in range(max(0,x-1),min(campus['width'],x+2))):
            skipped.append(dict(id=row[3],map=floor,cell=[x,y],name=row[1],reason='Documented farm coordinate has no original walkable ground within talk range in the preserved client snapshot; cannot move NPC or invent a path.'));continue
        graphic=int(row[20]);direction=int(row[19])%8;token=f'{graphic}:{direction}'
        scenery=graphic<14000 or row[0] in ['HouseMaster','Dengon','Billboard','Windowman'] and graphic<14000
        if graphic==1:
            skipped.append(dict(id=row[3],map=floor,cell=[x,y],name=row[1],reason='Invisible source event marker; physical appearance/interaction location needs corroboration.'));continue
        if token not in images:
            if graphic<100000 and graphic in lookup:
                g=lookup[graphic];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic}'
            else:
                choices=[r['key'] for r in catalog if r['id']==graphic];key=keys.get(graphic,(choices or [''])[0]);assert key,(graphic,row[1])
                _,_,clips=cg.actor(key);clip=next(c for c in clips if c['action']==0 and c['direction']==direction)
                im,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=im.getbbox();assert box;im=im.crop(box);images[token]=im
            art[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
        lines=[messages[v] for v in row[24].split('|') if v in messages] if row[0]=='TownPeople' else ['你好。這裡的詳細對話尚待恢復。']
        npcs.append(dict(id=row[3],type=row[0],name=row[1],floor=MAPS[floor],source=floor,cell=[x,y],direction=direction,graphic=graphic,token=token,scenery=scenery,messages=lines,raw=row))
    atlas=Image.new('RGBA',(1024,4096));xx=yy=rh=0
    for token,im in images.items():
        if xx+im.width+2>1024:xx=0;yy+=rh;rh=0
        atlas.paste(im,(xx+1,yy+1));art[token]['rect']=[xx+1,yy+1,*im.size];xx+=im.width+2;rh=max(rh,im.height+2)
    atlas=atlas.crop((0,0,1024,yy+rh));atlas.save(OUT/'npc-atlas.png')
    data=dict(schema=1,road_scope=stages[400]['reachable_spans'],species=species,zones=zones,groups=group_data,npcs=npcs,art=art,skipped=skipped,blockers=blockers,source_hashes={n:hashlib.sha256((SOURCE/n).read_bytes()).hexdigest() for n in ['npc.txt','msg.txt','encount.txt','group.txt','enemy.txt','enemybase.txt']},limits=['Pinned corroborating server records are not recovered BlueCG server state.','Generated mountain floor group weights, count distribution and encounter frequency lack exact original mapping; retain documented species/current levels with explicit adaptation.','Real-time encounters use local native combat after a movement check; turn-based formation ordering and original probability ramp are not available.'])
    (OUT/'population.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    if pack:
        from recover_habaru_encounter import recover
        recover(ARCHIVE,shalena=True,species_override=species,output_override=ROOT/'assets/characters/crossgate/snow_region')
    print('Prepared',len(npcs),'NPCs;',len(zones),'zones;',len(species),'species;',len(skipped),'uncertain/inactive objects;',len(blockers),'conditional group blockers')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pack',action='store_true');a=p.parse_args();build(a.pack)
