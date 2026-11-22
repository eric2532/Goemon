"""Recover Tina NPC identities, source event instructions, messages and original sprite anchors."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/crossgate_tina/events'
OUT=ROOT/'assets/maps/falan/tina'
QUEST_MAPS=set(range(14017,14026))|set(range(14036,14040))
REMOTE_IDS={1102660,1102731,1102732,1102733,1102734}
COMMANDS={'block','endblock','window','endwindow','endwind','leavegroup','warp','killitem','giveitem',
          'giveleak1item','nowevent','endevent','addgold','setdur','encount','end'}

def rows(path):
    return [line.split('\t') for line in path.read_bytes().decode('gb18030').splitlines()
            if line and not line.lstrip().startswith('#')]

def instructions(path):
    result=[]
    for number,line in enumerate(path.read_bytes().decode('gb18030').splitlines(),1):
        line=line.split('#',1)[0].strip()
        if not line:continue
        if line.endswith(':'):result.append(['label',line[:-1].lower(),number]);continue
        op,*args=line.split(None,1);op=op.lower();arg=args[0].strip() if args else ''
        assert op in COMMANDS or op.startswith('window_'),(path,number,line)
        result.append([op,arg,number])
    return result

def recover(archive):
    for p in json.loads((SOURCE/'references.json').read_text()):
        assert hashlib.sha256((SOURCE/p['file']).read_bytes()).hexdigest()==p['sha256'],p['file']
    sys.path.insert(0,str(archive/'tools'))
    import cg_library as lib
    import cg_assets as cg
    lookup=lib.serial_index()
    actors={}
    for r in cg.catalog()['entries']:
        actors.setdefault(r['id'],[]).append(r['key'])
    messages={r[0]:r[1].replace('\\n','\n').replace('@c','') for r in rows(SOURCE/'msg.txt') if len(r)>1 and r[0].isdigit()}
    npcs=[];scripts={};images={};proofs={}
    for line,r in enumerate(rows(SOURCE/'npc.txt')):
        if len(r)<25 or not r[8].isdigit() or not r[3].isdigit():continue
        floor=int(r[8]);ident=int(r[3])
        if not (4200<=floor<4300 or floor in QUEST_MAPS or ident in REMOTE_IDS or
                floor==400 and r[9].isdigit() and r[10].isdigit() and 500<=int(r[9])<=625 and 230<=int(r[10])<=350):continue
        if r[0] in ['Warp','HouseWarp2']:continue
        graphic=int(r[20]);direction=int(r[19])%8
        # Housing signs are already recorded in the client object plane; retain their records without duplicate art.
        token=f'{graphic}:{direction}'
        if token not in images and graphic:
            if graphic<100000 and graphic in lookup:
                g=lookup[graphic];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic}'
            else:
                choices=actors.get(graphic,[])
                preferred=[k for k in choices if k.startswith('original:') and 2800<=int(k.split(':')[1])<3000]
                key=(preferred or choices)[0] if choices else ''
                assert key,(ident,graphic)
                _,_,clips=cg.actor(key)
                matches=[c for c in clips if c['action']==0 and c['direction']==direction]
                if not matches and len(clips)==1 and clips[0]['action']==0:matches=clips
                assert matches,(ident,graphic,direction,key,[(c['action'],c['direction']) for c in clips])
                clip=matches[0]
                im,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=im.getbbox();assert box,(ident,graphic)
            im=im.crop(box);images[token]=im
            proofs[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
        script=r[24] if '.txt' in r[24] else ''
        if script:
            assert (SOURCE/script).is_file(),(ident,script)
            scripts[script]=instructions(SOURCE/script)
        npcs.append(dict(id=ident,type=r[0],name=r[1],floor=floor,cell=[int(r[9]),int(r[10])],
                         graphic=graphic,direction=direction,token=token,args=r[24],script=script,
                         messages=[int(n) for n in r[24].split('|') if n.isdecimal()] if r[0]=='TownPeople' else [],
                         rendered=r[0]!='HouseMaster',source_row=r))
    used_messages={str(v) for n in npcs for v in n['messages']}
    for code in scripts.values():
        for op,arg,_ in code:
            if op in ['window','endwindow','endwind'] and arg:
                used_messages.add(arg.split(',')[0].strip())
    skills={r[1]:dict(name=r[0],fee=int(r[6]),raw=r) for r in rows(SOURCE/'skill.txt') if len(r)>7 and r[1] in ['50','51','52','53','54','59','60']}
    for npc in npcs:
        if npc['type']=='Skillmaster':used_messages.update(npc['args'].strip('|').split('|')[1:])
        if npc['type']=='Techshop':used_messages.update(npc['args'].split('|')[1:6])
        if npc['type']=='Itemshop2':used_messages.update(npc['args'].split('|')[3:9])
    used_messages.update(str(i) for i in range(14842,14857))
    missing=used_messages-messages.keys();assert not missing,missing
    # Source item ID is column 11; keep native names, appearances, slot and durability fields.
    items={r[11]:dict(name=r[1],graphic=int(r[12]),type=int(r[14] or 0),price=int(r[13] or 0),
                     max_durability=int(r[25] or 0),raw=r) for r in rows(SOURCE/'itemset.txt') if len(r)>26 and r[11].isdigit()}
    used_items={18465,18466,18467,18468,18469,41173,41174,41175,41176,41177,41178,41217,41146,41149,41151,41153,18440,18441,18448,18660,*range(9600,9606)}
    shops={};pet_shops={};techniques={r[3]:r for r in rows(SOURCE/'tech.txt') if len(r)>12}
    for npc in npcs:
        fields=npc['args'].split('|')
        if npc['type']=='Itemshop2':
            shops[str(npc['id'])]=dict(buy_rate=int(fields[0]),sell_rate=int(fields[1]),mode=int(fields[2]),
                messages=fields[3:9],accept_types=[i for i,v in enumerate(fields[9:57]) if v=='1'],stock=[int(v) for v in fields[57:] if v.isdecimal() and int(v)>0])
            shop=shops[str(npc['id'])];used_items.update(shop['stock'])
            used_items.update(int(k) for k,v in items.items() if v['type'] in shop['accept_types'] and v['price']>0)
        if npc['type']=='Techshop':
            entries=[]
            for ident in fields[6:]:
                if not ident:continue
                r=techniques[ident];assert r[12]=='0',(ident,'Only pet techniques belong here')
                entries.append(dict(id=int(ident),name=r[0],required_level=int(r[6]),fee=int(r[9])*int(fields[0])//100,mp=int(r[11]),handler=r[1],parameters={k:int(v) for k,v in re.findall(r'([A-Z][A-Z0-9]*):(-?\d+)',r[2])},raw=r))
            pet_shops[str(npc['id'])]=dict(messages=fields[1:6],techniques=entries)
        for op,arg,_ in scripts.get(npc['script'],[]):
            if op in ['giveitem','giveleak1item','killitem']:used_items.add(int(arg.split(',')[0]))
    unresolved_items=sorted({str(i) for i in used_items}-items.keys())
    assert not unresolved_items,unresolved_items
    width=1024;x=y=row_height=0;rects={}
    height=sum(im.height+2 for im in images.values())
    atlas=Image.new('RGBA',(width,height))
    for token,im in images.items():
        if x+im.width+2>width:x=0;y+=row_height;row_height=0
        atlas.paste(im,(x+1,y+1));rects[token]=[x+1,y+1,*im.size]
        x+=im.width+2;row_height=max(row_height,im.height+2)
    atlas=atlas.crop((0,0,width,y+row_height))
    for token,(x,y,w,h) in rects.items():assert hashlib.sha256(atlas.crop((x,y,x+w,y+h)).tobytes()).hexdigest()==proofs[token]['rgba_sha256']
    enemies={r[2]:r for r in rows(SOURCE/'enemy.txt')};bases={r[1]:r for r in rows(SOURCE/'enemybase.txt')}
    group=next(r for r in rows(SOURCE/'group.txt') if r[2]=='40349')
    formation=[]
    for ident in group[5:15]:
        if not ident or ident=='0':continue
        enemy=enemies[ident];appearance=int(bases[enemy[3]][30])
        formation.append(dict(name=enemy[0],appearance=appearance,level=int(enemy[4]),enemy=enemy))
    assert [v['appearance'] for v in formation]==[110391,110388,110389,110390]
    mine_group=next(r for r in rows(SOURCE/'group.txt') if r[2]=='40331')
    mine=[]
    for ident in mine_group[5:15]:
        if not ident or ident=='0':continue
        enemy=enemies[ident];mine.append(dict(name=enemy[0],appearance=int(bases[enemy[3]][30]),level=int(enemy[4]),drops=41173,enemy=enemy))
    houses={r[0]:dict(raw=r,floor=1850,entry=[5,4],exit=[5,6],fee=500,days=14) for r in rows(SOURCE/'houseroom.txt') if r[0] in ['4803','4805','4808']}
    return dict(schema=1,npcs=npcs,scripts=scripts,skills=skills,houses=houses,shops=shops,pet_shops=pet_shops,merchant_stock=shops['1050']['stock'],messages={k:messages[k] for k in sorted(used_messages,key=int)},battles={'40349':formation},mine=mine,
                items={str(k):items[str(k)] for k in sorted(used_items) if str(k) in items},unresolved_items=unresolved_items,
                art={k:dict(rect=v,**proofs[k]) for k,v in rects.items()},
                provenance='Original BlueCG art; pinned corroborating server records. No claim of recovered BlueCG server state.'),atlas

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--archive',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');p.add_argument('--flowers',action='store_true');a=p.parse_args()
    if a.flowers:
        from recover_crossgate_mantises import recover as pack
        actors=[(110388+i,f'puk2:{58+i}') for i in range(4)]+[(101631,'original:2928')]
        names=['走路花妖','舞蹈花妖','跑步花妖','侯爵花妖','水晶螃蟹']
        profiles={key:dict(label=names[i],category='quest',effect=False,xl=False,visual_scale=1.0,
                          body=[-1.0,0,-1.0,2.0,3.8,2.0]) for i,(_,key) in enumerate(actors)}
        pack(a.archive,actors,ROOT/'assets/characters/crossgate/tina_flowers',xl_ids=(),profiles=profiles,legacy_contacts=False)
        return
    data,atlas=recover(a.archive);text=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
    if a.check:
        assert (OUT/'npcs.json').read_text()==text
        assert Image.open(OUT/'npcs.png').tobytes()==atlas.tobytes()
    else:
        OUT.mkdir(parents=True,exist_ok=True);(OUT/'npcs.json').write_text(text);atlas.save(OUT/'npcs.png')
    print('TINA_NPCS',len(data['npcs']),'scripts',len(data['scripts']),'messages',len(data['messages']),'original appearances',len(data['art']))

if __name__=='__main__':main()
