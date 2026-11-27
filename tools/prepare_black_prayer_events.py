"""Prepare source Ruby access scripts, exact post-palace cells and reused field NPC art."""
import argparse
import base64
import hashlib
import json
import re
import sys
import zlib
from pathlib import Path

from PIL import Image
from prepare_black_prayer_encounters import ROOT, SOURCE, TABLES, rows, sha
from prepare_east_region_population import compile_script
import prepare_sokia_fixed_maps as fixed
from prepare_east_region_maps import complete_map

OUT = ROOT / 'assets/maps/falan/black_prayer/events'
ACTORS = ['6300', '6301', '6302', '6303', '6304', '6305', '6306', '6307', '61000', '61001', '81000',
          '6308', '6309', '6927', '61002', '6310', '6311', '6917', '6928', '20580', '807217']


def encoded(raw):
    return base64.b64encode(zlib.compress(raw)).decode()


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    import cg_assets as cg
    from prepare_field_assets import navigation_grid
    from recover_habaru_encounter import body_rows
    lookup = lib.serial_index()
    npc_rows = {}
    for line, text in enumerate((TABLES/'npc.txt').read_bytes().decode('gb18030').splitlines(),1):
        raw=text.split('\t')
        if len(raw)>24 and not text.startswith('#'):npc_rows[raw[3]]=(line,raw)
    references = {r['file']: r for r in json.loads((SOURCE / 'references.json').read_text())}
    references.update({r['file']: r for r in json.loads((SOURCE / 'black-prayer-references.json').read_text())})
    messages = {r[0]: r[1].replace('\\n', '\n') for r in rows(TABLES / 'msg.txt') if len(r) > 1}
    scripts = {}; actors = {}; art = {}; images = {}; proofs = {}
    keys = {}
    for entry in cg.catalog()['entries']:
        if entry['key'].startswith('original:'):keys.setdefault(entry['id'], entry['key'])
    for ident in ACTORS:
        line, raw = npc_rows[ident]
        graphic = int(raw[20]); direction = int(raw[19]); token = f'{graphic}:{direction}'
        if token not in art:
            if graphic in lookup and graphic < 100000:
                g = lookup[graphic]; im = lib.image_from_record(g['pack'], g['row'])
                ox, oy = g['x'], g['y']; key = f'graphic:{graphic}'; top = foot = None
                if 14000<=graphic<15000:top,foot=body_rows(im)
            else:
                key = keys[graphic]; _, _, clips = cg.actor(key)
                idle = next(c for c in clips if c['action'] == 0 and c['direction'] == direction)
                im, ox, oy = cg.frame_parts(key, idle['index'], 0); top, foot = body_rows(im)
            box = im.getbbox(); assert box, token
            images[token] = im.crop(box)
            art[token] = dict(key=key, origin=[ox+box[0], oy+box[1]], rgba_sha256=hashlib.sha256(images[token].tobytes()).hexdigest())
            if foot is not None:art[token].update(body_top=top-box[1], body_foot=foot-box[1],
                                                  map_foot_contract='Existing body_rows excludes exact charcoal shadow; unchanged pixels/scale/body feet meet unchanged source ground cell.')
        script = raw[24]
        if script.endswith('.txt'):
            path = SOURCE / script; proof = references[script]
            assert sha(path) == proof['sha256']
            scripts[script] = compile_script(path.read_bytes()); proofs[script] = proof
        actor = dict(id=ident, name=raw[1], type=raw[0], source=int(raw[8]), cell=list(map(int, raw[9:11])),
                     direction=direction, graphic=graphic, token=token, script=script, source_line=line, raw=raw,
                     area='interior', floor=int(raw[8]), quest_action='black_prayer:'+ident,
                     scenery=graphic < 14000, rendered_elsewhere=False, dialogue_owner='black_prayer',
                     messages=[messages.get(script, '請繼續聽我說。')] if raw[0] == 'TownPeople' else ['請繼續聽我說。'],
                     unbounded_source_quest_items=True,
                     itemspace_contract='Zero/nonzero only: existing source quest dictionary has no rejected insert/capacity; original slot-limit parity unmodeled.')
        if ident == '6300':actor['source_have_item_equality'] = 18419
        if ident == '81000':actor['battle_owner'] = 'black_prayer'
        if raw[0]=='Skillmaster':
            actor['messages']=[messages[script.split('|')[1]]]
            actor['source_service_unmodeled']='Original skill training UI/payment/eligibility is not restored by this source route.'
        if actor['source'] == 777:
            actor.update(generated_by=301, template_cell=actor['cell'], template_source=777, source_refresh=100)
        actors[ident] = actor
    x = y = row_height = 0
    atlas = Image.new('RGBA', (1024, 2048))
    for token, im in images.items():
        if x+im.width+2 > 1024:x=0; y+=row_height; row_height=0
        atlas.paste(im, (x+1, y+1)); art[token]['rect'] = [x+1,y+1,*im.size]
        x+=im.width+2; row_height=max(row_height,im.height+2)
    atlas = atlas.crop((0,0,1024,y+row_height))
    def source_map(number):
        with lib.connection() as db:ident = db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        return lib.source_file(ident)[1].read_bytes()
    before = source_map(16508); client_post = source_map(16509)
    server_root=ROOT/'assets/references/crossgate_sokia/maps/server'
    server_refs=json.loads((server_root/'black-prayer-references.json').read_text())
    old = lib.parse_map(before)
    text = (ROOT/'assets/maps/falan/room_art_data.gd').read_text()
    old_tiles = zlib.decompress(base64.b64decode(re.search(r'\b16508\s*:\s*"([^"]+)"',text)[1]))
    old_walk=bytes.fromhex(re.search(r'16508:\[Vector2i\(50,50\),Vector2\(-75,-75\),"([^"]+)"',
                                   (ROOT/'assets/maps/falan/freyja_destinations_data.gd').read_text())[1])
    tile_lookup = {}
    for i,serial in enumerate(old[2]):
        tile = int.from_bytes(old_tiles[i*2:i*2+2],'little')
        assert serial not in tile_lookup or tile_lookup[serial] == tile
        tile_lookup[serial] = tile
    palace = json.loads((ROOT/'assets/maps/falan/black_prayer/palace-proportions.json').read_text())
    walls = {serial:i+1 for i,serial in enumerate(palace['wall_serials'])}
    prop_text = (ROOT/'assets/maps/falan/ruby_room_props.gd').read_text()
    prop_serials = set(map(int,re.findall(r'^\s(\d+):\[Rect2',prop_text,re.M)))
    def prepare_palace(number,client,recorded,completed):
        proof=next(row for row in server_refs if row['file']==f'{number}_rubi')
        server=(server_root/proof['file']).read_bytes()
        assert hashlib.sha256(server).hexdigest()==proof['sha256']
        raw,completion=complete_map(client,server,number)
        assert completion==dict(recorded=recorded,cells=2500,completed=completed,preserved_client_variations=0,compatible=True,layout_complete=True)
        w,h,ground,objects,flags=lib.parse_map(raw);original=lib.parse_map(client)
        assert set(ground)<=tile_lookup.keys()
        walk=navigation_grid(w,h,ground,objects,lookup);mask=bytearray((w*h+7)//8)
        for i,opened in enumerate(walk):
            if opened:mask[i>>3]|=1<<(i&7)
        row=dict(id=number,size=[w,h],origin=[-w//2*3,-h//2*3],raw=encoded(raw),raw_sha256=hashlib.sha256(raw).hexdigest(),
                 client_raw_sha256=hashlib.sha256(client).hexdigest(),server_provenance=proof,completion=completion,
                 client_flags_sha256=hashlib.sha256(client[20+w*h*4:]).hexdigest(),walk=mask.hex(),
                 floor_tiles=encoded(b''.join(tile_lookup[s].to_bytes(2,'little') for s in ground)),
                 wall_tiles=encoded(b''.join(walls.get(s,0).to_bytes(2,'little') for s in objects)),
                 props=[[i%w,i//w,s] for i,s in enumerate(objects) if s in prop_serials],
                 recorded=sum(bool(v&0xc000) for v in flags),source=f'BlueCrossgate/map/0/{number}.dat',
                 reuses=f'Existing Ruby floor/wall/prop atlases and builders. Pinned server planes fill only{completed}client-unrecorded cells; all recorded cells and every flag remain exact.')
        if number==16508:
            known=[i for i,v in enumerate(original[4]) if v&0xc000]
            assert all(bool(old_walk[i>>3]&(1<<(i&7)))==bool(walk[i]) for i in known)
            assert all(not(old_walk[i>>3]&(1<<(i&7))) or walk[i] for i in range(w*h))
            row['walk_preservation']=dict(recorded_cells=len(known),recorded_changes=0,old_open_lost=0,
                                          added_open=sum(walk[i] and not(old_walk[i>>3]&(1<<(i&7))) for i in range(w*h)),
                                          old_walk_sha256=hashlib.sha256(old_walk).hexdigest())
            assert row['walk_preservation']['added_open']==68
        return row,raw
    pre,pre_raw=prepare_palace(16508,before,2247,253)
    map_data,post=prepare_palace(16509,client_post,1929,571)
    w,h,ground,objects,flags=lib.parse_map(post)
    for actor in actors.values():
        if actor['source']==777 or actor['graphic']>=14000:continue
        parsed=lib.parse_map(post if actor['source']==16509 else pre_raw if actor['source']==16508 else source_map(actor['source']))
        actor['rendered_elsewhere']=parsed[3][actor['cell'][1]*parsed[0]+actor['cell'][0]]==actor['graphic']
    both = [i for i in range(w*h) if flags[i]&0xc000 and old[4][i]&0xc000]
    map_data['before_comparison'] = dict(map16508_sha256=hashlib.sha256(before).hexdigest(),both_recorded_cells=len(both),
                                         floor_differences_in_overlap=sum(ground[i]!=old[2][i] for i in both),
                                         object_differences_in_overlap=sum(objects[i]!=old[3][i] for i in both),
                                         qualification='Separate cached layouts; no cell is copied from16508 into16509.')
    message_ids = set()
    for script in scripts.values():
        for _,line in script['lines']:
            match = re.match(r'\s*(?:End)?Window\s+(\d+)',line,re.I)
            if match:message_ids.add(match[1])
    enemy_rows={r[2]:r for r in rows(TABLES/'enemy.txt')}
    group=next(r for r in rows(TABLES/'group.txt') if r[2]=='11009')
    native_slots=['11017',*map(str,range(11022,11027)),*map(str,range(11018,11022))]
    assert set(native_slots)==set(group[5:15]) and all(value=='1' for value in group[15:35])
    data = dict(schema=1,actors=actors,art=art,scripts=scripts,messages={k:messages[k] for k in sorted(message_ids,key=int)},
                pre=pre,post=map_data,source_provenance=proofs,source_hashes={n:sha(TABLES/n) for n in ['npc.txt','msg.txt']},
                boss=dict(encounter=11007,group=11009,raw_group=group,native_slots=native_slots,
                          enemies={ident:enemy_rows[ident] for ident in native_slots},
                          qualification='Current native party positions/spells/stat formulas retained; distinct original enemy/AI IDs remain explicit and original AI execution stays unverified.'),
                generated_npc_contract=dict(config=301,source_slots=[[101,6303,102,100],[103,6304,104,100]],
                                            runtime_adaptation='One of each actor, seeded without replacement across current room centers, once per logical branch; original placement/count/refresh unverified.'),
                limits=['Original StandEnemy scheduling, repeat/cooldown/escape and turn-based formation remain unverified; F is the existing field-interaction adaptation.',
                        'HaveItem==18419 is adapted only for source6300 from the exact held-item ledger; pure unknown conditions remain guarded.',
                        'Existing source-quest inventory is unbounded; original slot capacity and profession Job131–137 parity remain unmodeled.',
                        '16508/16509 use separate exact pinned server completions; recorded client cells and every flag remain unchanged.16508 adds68source-open cells without changing old recorded navigation.3354/5011 clients are fully recorded.',
                        'Native Ruby attacks/spells/balance and existing boss death ledger remain adapted and unchanged.'])
    data['limits'].append('3354 source book20580 is rendered at its original cell; its original skill-training service is unmodeled. Source Shanti/807217 reward item IDs are retained, but equipment/icon integration is not certified by this route.')
    fixture_roles={**{s:'book' for s in range(10504,10510)},16511:'bookcase',16512:'bookcase',16793:'pot',16808:'pedestal',16815:'wooden_clubs',16841:'counter',
                   17194:'books',17195:'candelabra',16526:'wall_shelf',16534:'wall_cabinet',16583:'drawers',16584:'drawers',16649:'pot',16651:'pot'}
    fixtures={}
    for serial,role in fixture_roles.items():
        g=lookup[serial];im=lib.image_from_record(g['pack'],g['row']);box=im.getbbox();assert box
        fixtures[str(serial)]=dict(role=role,bounds=list(box),origin=[g['x'],g['y']],size=list(im.size),
                                   footprint=[g['x_len'],g['y_len']] if 'x_len' in g else [],
                                   source_rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest(),
                                   elevated=serial in [16526,16534,17195],
                                   qualification='Source projection/anchor/art exact; compatible existing solid masters and hidden depth are a visual reconstruction.')
    data['room_fixtures']=dict(maps=[3354,5011],graphics=fixtures)
    fixed.MAPS = {3354:'馮奴的家 · 巫師卡莫西',5011:'香蒂的房間'}; fixed.VISUAL_ROOMS = {}
    catalog,map_images = fixed.prepare()
    return data,{'npc-atlas.png':atlas,**{'return-maps/'+k:v for k,v in map_images.items()}},catalog


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=OUT);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data,images,catalog=prepare()
    for name,value in [('data.json',data),('return-maps/catalog.json',catalog)]:
        path=args.output/name; text=json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check:assert path.read_text()==text,path
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    for name,image in images.items():
        path=args.output/name
        if args.check:
            actual=Image.open(path);assert actual.mode==image.mode and actual.size==image.size and actual.tobytes()==image.tobytes(),name
        else:path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
    print('BLACK_PRAYER_EVENTS',len(data['actors']),'source actors;',len(data['scripts']),'full scripts; exact16508/16509 plus2return maps;',len(images),'new derivative images; original Ruby art unchanged')


if __name__=='__main__':main()
