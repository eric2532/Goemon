"""Recover PUK2 island maps through their native CUT tables, preserving client bytes."""
import argparse
import base64
from collections import Counter, deque
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
import hashlib
import json
import re
from pathlib import Path
import struct
import sys
import urllib.request
import zlib

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Elsa Island'
SOURCE = REPORT / 'Source'
OUTPUT = ROOT / 'assets/maps/original_crossgate/elsa'
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_library as lib
import cg_assets as cg

COMMIT = 'dd8690ed3df11e4eb5a038a54079a8f40d8e93b3'
CORE = [59511, 59510, 59500, 59501, 59520, 59530, 59534, 59531, 59535, 59536, 59537]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def reference_map(ident):
    path = next(SOURCE.glob(str(ident) + '*'))
    raw = path.read_bytes()
    assert raw[:6] == b'LS2MAP'
    width, height = struct.unpack_from('>HH', raw, 40)
    cells = width * height
    extended = raw[6:8] == b'\xff\xff'
    offset = 60 if extended else 44
    planes = 3 if extended else 2
    assert len(raw) == offset + cells * planes * 2, path
    values = struct.unpack_from(f'>{cells * planes}H', raw, offset)
    return width, height, [values[i*cells:(i+1)*cells] for i in range(planes)]


@lru_cache(maxsize=None)
def cut_records(ident):
    path = cg.SOURCE / f'Puk2/cutdat/{ident}.cut'
    raw = path.read_bytes()
    magic, header, floors, objects, animated = struct.unpack_from('<4s4H', raw)
    assert magic == b'CUT ' and header == 12
    assert len(raw) == header + (floors + objects + animated) * 18, path
    return list(struct.iter_unpack('<IH4H2h', raw[header:]))


@lru_cache(maxsize=None)
def cut_header(ident):
    return struct.unpack_from('<4s4H', (cg.SOURCE / f'Puk2/cutdat/{ident}.cut').read_bytes())


@lru_cache(maxsize=None)
def graphic(serial):
    with lib.connection() as db:
        rows = db.execute('SELECT * FROM graphics WHERE serial=? ORDER BY pack_order,row', (serial,)).fetchall()
    assert rows, ('Missing graphic serial', serial)
    row = dict(rows[-1])
    return row, lib.image_from_record(row['pack'], row['row'])


@lru_cache(maxsize=None)
def scenery_frame(serial, frame_index=0):
    candidates = [a['key'] for a in cg.catalog()['entries'] if a['id'] == serial]
    preferred = [key for key in candidates if key.startswith('puk2:')]
    # Later CUT files remain under Puk2/cutdat but reference unique PUK3 scenery.
    choices = preferred or candidates
    assert len(choices) == 1, ('Ambiguous CUT scenery source', serial, choices)
    key = choices[0]
    pack, index = key.split(':')
    info = (cg.SOURCE / cg.PACKS[pack][2]).read_bytes()
    ident, address, count, _ = struct.unpack_from('<IIHH',info,int(index)*12)
    data = cg.anime_data(pack)
    direction, action, duration, frames = struct.unpack_from('<HHII',data,address)
    # PUK2 scenery additionally uses the marker's high byte for opacity (e.g. 8c/96).
    high = data[address+16:address+19] == b'\xff'*3
    palette, flags = struct.unpack_from('<HH',data,address+12) if high else (0,0)
    start = address + (20 if high else 12)
    sequence = list(struct.iter_unpack('<IhhH',data[start:start+frames*10]))
    graphic_id, dx, dy, event = sequence[frame_index]
    assert abs(dx)<4096 and abs(dy)<4096 and 0<graphic_id<1000000,(serial,sequence[0])
    pixels, embedded, (ox,oy,w,h) = cg.graphic_data(pack,graphic_id)
    colors = (cg.actor_palette(pack,ident) if high else None) or embedded or cg.external_palette(palette if flags&4 else 0)
    art=Image.frombytes('P',(w,h),pixels)
    art.putpalette([v for color in colors for v in color]+[0]*(768-len(colors)*3))
    art.info['transparency']=bytes([0]+[255]*(len(colors)-1)+[0]*(256-len(colors)))
    art=ImageOps.flip(art.convert('RGBA'));ox+=dx;oy+=dy
    if flags&1:art=ImageOps.mirror(art);ox=-ox-w
    if flags&2:art=ImageOps.flip(art);oy=-oy-h
    return art,ox,oy,dict(key=key,duration=duration,palette=palette,flags=flags,frames=sequence,
                        opacity=data[address+19] if high else 255)


@lru_cache(maxsize=24000)
def cut_image(ident, serial):
    row = cut_records(ident)[serial - 1000]
    source, mode, x, y, w, h, ax, ay = row
    record, art = graphic(source)
    header = cut_header(ident)
    if serial - 1000 >= header[2] + header[3]:
        art, ox, oy, _ = scenery_frame(source)
        return art, (ox + ax, oy + ay), row
    if w == h == 0:
        # Diagnostic master payload only: a static zero-area CUT has no drawable crop.
        # Keep these source pixels available for inspection; render/prepare mark it void.
        return art, (record['x'] + ax, record['y'] + ay), row
    assert mode in [0,1] and w > 0 and h > 0, (ident, serial, row)
    # CUT coordinates address a 640x480 canvas; GraphicInfo trims its transparent border.
    left = x - (320 + record['x'])
    top = y - (240 + record['y'])
    return art.crop((left, top, left + w, top + h)), (-ax, -ay), row


def client_map(ident):
    with lib.connection() as db:
        row = db.execute('SELECT * FROM files WHERE path=?', (f'BlueCrossgate/map/0/{ident}.dat',)).fetchone()
    if row is None:
        return None
    info, path = lib.source_file(row['id'])
    raw = path.read_bytes()
    assert sha(raw) == info['sha256'], path
    return raw, lib.parse_map(raw)


def npc_rows():
    path = ROOT / 'build/Other Files/Asset Toolkit/Cursed Maze/Source/npc-index.txt'
    rows = []
    for line, text in enumerate(path.read_bytes().decode('gb18030').splitlines(), 1):
        fields = text.split('\t')
        if len(fields) != 25 or not fields[8].isdigit():
            continue
        rows.append(dict(line=line, kind=fields[0], name=fields[1], id=fields[3],
                         map=int(fields[8]), cell=[int(fields[9]), int(fields[10])],
                         graphic=int(fields[20] or 0), direction=int(fields[19] or 0)%8,
                         script=fields[24], raw=fields))
    return rows


def fetch(paths):
    tree = json.loads((ROOT / 'build/Other Files/Asset Toolkit/Original Isometric Maps/reference-tree.json').read_text())
    entries = {r['path']: r for r in tree['tree']}
    proofs = json.loads((SOURCE / 'references.json').read_text()) if (SOURCE / 'references.json').exists() else []
    seen = {p['path'] for p in proofs}
    def download(path):
        row = entries.get(path)
        if row is None:
            print('MISSING_REFERENCE', path)
            return None
        url = f'https://raw.githubusercontent.com/linv2/Crossgate_Docker/{COMMIT}/{path}'
        raw = urllib.request.urlopen(url, timeout=30).read()
        assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == row['sha']
        return path, url, raw
    with ThreadPoolExecutor(max_workers=6) as pool:
      for result in pool.map(download, sorted(set(paths) - seen)):
        if result is None:
            continue
        path, url, raw = result
        (SOURCE / Path(path).name).write_bytes(raw)
        proofs.append(dict(path=path, file=Path(path).name, url=url, sha256=sha(raw)))
        (SOURCE / 'references.json').write_text(json.dumps(proofs, ensure_ascii=False, indent=2) + '\n')


def fixed_warps():
    rows = []
    path = ROOT / 'build/Other Files/Asset Toolkit/Original Isometric Maps/reference-warp.txt'
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 7 and all(x.isdecimal() for x in fields[:7]):
            rows.append(list(map(int, fields[1:7])))
    return rows


def event_warps(script):
    path = SOURCE / script
    if not path.is_file():
        return []
    text = path.read_bytes().decode('gb18030')
    result=[]
    for line in text.splitlines():
        if not re.match(r'^\s*(?:Warp|Encount)\b',line,re.I):continue
        result.extend(list(map(int,m)) for m in re.findall(r'0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',line))
    return result


@lru_cache(maxsize=None)
def components(ident):
    width, height, planes = reference_map(ident)
    labels = [-1] * (width * height)
    sizes = []
    for i, blocked in enumerate(planes[2]):
        if blocked or labels[i] >= 0:
            continue
        label = len(sizes); labels[i] = label; queue = deque([i]); size = 0
        while queue:
            cell = queue.popleft(); size += 1
            x, y = cell % width, cell // width
            for other in [cell-1 if x else -1, cell+1 if x+1<width else -1,
                          cell-width if y else -1, cell+width if y+1<height else -1]:
                if other >= 0 and not planes[2][other] and labels[other] < 0:
                    labels[other] = label; queue.append(other)
        sizes.append(size)
    return width, height, labels, sizes


def cell_component(ident, cell):
    width, height, labels, _ = components(ident)
    x, y = cell
    return labels[y*width+x] if 0<=x<width and 0<=y<height else -1


def temple_return(actor):
    cells={'me_warp_family_1.txt':[79,55],'me_warp_family_2.txt':[59,93],'me_warp_family_3.txt':[81,133]}
    return actor['map']==59530 and actor['kind']=='Event' and actor['graphic']==103010 and cells.get(actor['script'])==actor['cell']


def npc_appearance(choices):
    # AnimeInfo is indexed by serial with later table rows replacing earlier ones.
    pack='puk2' if any(a['pack']=='puk2' for a in choices) else choices[0]['pack']
    return max((a for a in choices if a['pack']==pack),key=lambda a:int(a['key'].rsplit(':',1)[1]))


def active_actor(actor):
    # These three explicitly corroborated return stones are the only later-ID exception.
    return not actor['kind'].startswith('#') and (int(actor['id']) < 1000000 or temple_return(actor)) and actor['raw'][6] == '1'


def activation_cells(actor):
    path=SOURCE/actor['script']
    if actor['kind']=='WatchEx' and path.is_file():
        text=path.read_bytes().decode('gb18030')
        cells=sorted({tuple(map(int,m)) for m in re.findall(r'XPos\s*==\s*(\d+)\s*&&\s*YPos\s*==\s*(\d+)',text,re.I)})
        if cells:return cells
    return [actor['cell']]


def actor_components(actor):
    return {cell_component(actor['map'], (x+dx,y+dy)) for x,y in activation_cells(actor)
            for dx in range(-1,2) for dy in range(-1,2)} - {-1}


def room_scope():
    """A shared map file is not an ownership boundary: follow its connected rooms."""
    actors = [a for a in npc_rows() if active_actor(a)]
    warps = fixed_warps(); owned = set(); queue = deque([(59520,112,102)]); links=[]
    def destination(source, cell, target, landing, kind, proof, command=''):
        component = cell_component(source,cell)
        link = dict(source=source,cell=cell,target=target,landing=landing,kind=kind,
                    proof=proof,command=command,source_component=component)
        if not 59530<=target<59800 and target!=59520:
            link['status']='off-island boundary'
        elif not list(SOURCE.glob(str(target)+'*')):
            link['status']='missing fixed layout'
        elif cell_component(target,landing)<0:
            link['status']='blocked archived landing'
        else:
            link['status']='island room';queue.append((target,*landing))
        links.append(link)
    while queue:
        ident,x,y=queue.popleft();component=cell_component(ident,(x,y))
        if component<0 or (ident,component) in owned:continue
        owned.add((ident,component))
        for n,w in enumerate(warps):
            if w[0]!=ident or cell_component(ident,w[1:3])!=component:continue
            destination(ident,w[1:3],w[3],w[4:6],'door',f'reference-warp.txt:record {n+1}')
        for actor in actors:
            if actor['map']!=ident or component not in actor_components(actor):continue
            script=actor['script'];path=SOURCE/script
            if script.endswith('.txt') and path.is_file():
                for line,text in enumerate(path.read_bytes().decode('gb18030').splitlines(),1):
                    match=re.match(r'^\s*(Warp|Encount)\b',text,re.I)
                    if not match:continue
                    for target,tx,ty in re.findall(r'0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',text):
                        for at in activation_cells(actor):
                            destination(ident,list(at),int(target),[int(tx),int(ty)],
                                        'victory' if match[1].lower()=='encount' else 'event',
                                        f'{script}:{line}',text.strip())
                            if temple_return(actor):
                                links[-1].update(temple_return=True,original_client_parity='unverified',
                                                 snapshot_condition='Level > 49; LeaveGroup',explore_condition='existing free area travel')
            elif actor['kind'] in ['StandEnemy','Warp']:
                for target,tx,ty in re.findall(r'0,(\d+),(\d+),(\d+)',script):
                    destination(ident,actor['cell'],int(target),[int(tx),int(ty)],
                                'victory' if actor['kind']=='StandEnemy' else 'event',
                                f'npc-index.txt:{actor["line"]}',script)
    ids=sorted({ident for ident,_ in owned});by_map={}
    for ident in ids:
        width,height,labels,sizes=components(ident);selected={c for i,c in owned if i==ident}
        by_map[str(ident)]=dict(components=sorted(selected),cells=sum(sizes[c] for c in selected),
                              entries=[l['landing'] for l in links if l['target']==ident and l['status']=='island room'])
    # This script lands in room 6, while its next story actor is in disconnected room 7.
    blocked=[dict(map=59716,component=7,actor='806499',next_map=59737,
                  reason='EV_tane_mein5_104.txt transfers to (166,173), component 6. Bishop (67,171) belongs to component 7; no crossing joins them. Do not substitute (66,173).')]
    ids=sorted(set(ids)|{59737})
    scope=dict(island=ids,route=CORE[:4],maps=sorted(set(ids)|set(CORE[:4])),rooms=by_map,blocked_rooms=blocked,
               external=sorted({l['target'] for l in links if l['status']=='off-island boundary'}))
    (REPORT/'scope.json').write_text(json.dumps(scope,ensure_ascii=False,indent=2)+'\n')
    unique={json.dumps(l,sort_keys=True):l for l in links}
    (REPORT/'links.json').write_text(json.dumps(list(unique.values()),ensure_ascii=False,indent=2)+'\n')
    print('ELSA_CONNECTED_SCOPE',len(ids),'map containers',len(owned),'connected rooms',scope['external'],flush=True)


def owned_actor(actor,scope):
    if actor['map'] in scope['route']:return True
    for blocked in scope.get('blocked_rooms',[]):
        if actor['map']==blocked['next_map']:return True
        if actor['map']==blocked['map'] and blocked['component'] in actor_components(actor):return True
    room=scope.get('rooms',{}).get(str(actor['map']))
    return room is not None and bool(actor_components(actor)&set(room['components']))


def prepare_ownership(scope):
    result={}
    for ident in scope['island']:
        width,height,labels,sizes=components(ident)
        selected=set(scope.get('rooms',{}).get(str(ident),{}).get('components',[]))
        for blocked in scope.get('blocked_rooms',[]):
            if ident==blocked['map']:selected.add(blocked['component'])
            if ident==blocked['next_map']:
                actor=next(a for a in npc_rows() if a['id']==blocked['actor'])
                selected.update(cell_component(ident,landing) for target,*landing in event_warps(actor['script']) if target==ident)
        bits=bytearray((width*height+7)//8);bounds=[]
        for label in selected:
            cells=[i for i,c in enumerate(labels) if c==label]
            if not cells:continue
            bounds.append([min(i%width for i in cells)-12,min(i//width for i in cells)-12,
                           max(i%width for i in cells)+13,max(i//width for i in cells)+13])
            for i in cells:bits[i>>3]|=1<<(i&7)
        result[str(ident)]=dict(size=[width,height],open=encoded(bits),bounds=bounds)
    path=ROOT/'assets/maps/falan/elsa/ownership.json'
    path.write_text(json.dumps(result,separators=(',',':'))+'\n')


def fetch_scope():
    island = {59520, 59530, 59531, 59534, 59535, 59536, 59537}
    warps = fixed_warps()
    actors = npc_rows()
    tree = json.loads((ROOT / 'build/Other Files/Asset Toolkit/Original Isometric Maps/reference-tree.json').read_text())
    map_paths = {int(Path(r['path']).name.split('_')[0]): r['path'] for r in tree['tree']
                 if r['path'].startswith('gmsv/data/map/') and Path(r['path']).name.split('_')[0].isdigit()}
    for _ in range(270):
        fetch([map_paths[n] for n in island | set(CORE) if n in map_paths] +
              ['gmsv/data/npc/' + r['script'] for r in actors if r['map'] in island and not r['kind'].startswith('#') and r['script'].endswith('.txt')])
        targets = {w[3] for w in warps if w[0] in island}
        targets.update(w[0] for r in actors if r['map'] in island and not r['kind'].startswith('#') for w in event_warps(r['script']))
        targets.update(int(m[0]) for r in actors if r['map'] in island and r['kind'] in ['StandEnemy','Warp']
                       for m in re.findall(r'0,(\d+),(\d+),(\d+)',r['script']))
        additions = {n for n in targets if 59530 <= n < 59800}
        if additions <= island:
            break
        island |= additions
        print('ELSA_SCOPE_EXPANDING',len(island),flush=True)
    else:
        raise AssertionError('Island link closure did not settle')
    result = dict(island=sorted(island), route=CORE[:4],
                  external=sorted(targets - island),
                  maps=sorted(island | set(CORE)))
    (REPORT / 'scope.json').write_text(json.dumps(result, indent=2) + '\n')
    print('ELSA_SCOPE', len(island), 'island maps', result['external'], flush=True)
    room_scope()


def inventory():
    rows = []
    scope = json.loads((REPORT / 'scope.json').read_text()) if (REPORT / 'scope.json').exists() else dict(maps=CORE)
    for ident in scope['maps']:
        w, h, planes = reference_map(ident)
        client = client_map(ident)
        known = [i for i, v in enumerate(client[1][4]) if v & 0xc000] if client else []
        differences = [i for i in known if (client[1][2][i], client[1][3][i]) != (planes[0][i], planes[1][i])]
        assert not differences, (ident, len(differences))
        raw = next(SOURCE.glob(str(ident) + '*')).read_bytes()
        title = raw[8:40].split(b'\0')[0].decode('gb18030').split('|')[0]
        rows.append(dict(map=ident, title=title, size=[w,h], recorded=len(known), cells=w*h,
                         client_sha256=sha(client[0]) if client else None,
                         recorded_differences=len(differences), cut_records=len(cut_records(ident)) if (cg.SOURCE / f'Puk2/cutdat/{ident}.cut').exists() else None))
    actors = [r for r in npc_rows() if r['map'] in scope['maps'] and not r['kind'].startswith('#')]
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / 'inventory.json').write_text(json.dumps(dict(maps=rows, npcs=actors), ensure_ascii=False, indent=2) + '\n')
    return rows, actors


def render(ident):
    w, h, planes = reference_map(ident)
    scale = .2
    canvas = Image.new('RGBA', (round((w+h)*32*scale + 600), round((w+h)*24*scale + 600)), '#202831')
    placed = []
    for layer, values in enumerate(planes[:2]):
        for i, serial in enumerate(values):
            if serial < 1000:
                continue
            if serial-1000<sum(cut_header(ident)[2:4]) and cut_records(ident)[serial-1000][4:6]==(0,0):continue
            art, anchor, cut = cut_image(ident, serial)
            x, y = i % w, i // w
            placed.append((layer, 11*y-9*x, (x+y)*32+anchor[0], (y-x)*24+anchor[1], art))
    for _, _, x, y, art in sorted(placed, key=lambda r: (r[0],r[1],r[2])):
        resized = art.resize((max(1,round(art.width*scale)), max(1,round(art.height*scale))))
        canvas.alpha_composite(resized, (round(x*scale+300), round((y+w*24)*scale+300)))
    path = REPORT / f'source-{ident}.png'
    canvas.save(path)
    print(path)


def encoded(raw):
    return base64.b64encode(zlib.compress(raw, 9)).decode('ascii')


def prepare(check=False):
    scope = json.loads((REPORT / 'scope.json').read_text())
    existing = [json.loads((ROOT / 'assets/maps/original_crossgate' / p).read_text())
                for p in ['catalog.json', 'university/catalog.json','../falan/sokia/fixed/catalog.json']]
    taken = {int(k) for c in existing for k in c['graphics']}
    available = iter(n for n in range(20000, 65536) if n not in taken)
    page_offset = sum(len(c['pages']) for c in existing)
    pages = []; graphics = {}; maps = {}; dedup = {}; proofs = []
    page = Image.new('RGBA', (2048,2048)); px = py = row_height = 0
    for ident in scope['maps']:
        width, height, planes = reference_map(ident); cells = width * height
        client = client_map(ident)
        original = client[0] if client else b'MAP\x01' + bytes(8) + struct.pack('<II',width,height) + struct.pack(f'<{cells*3}H',*planes[0],*planes[1],*[0xc000|v for v in planes[2]])
        flags = list(lib.parse_map(original)[4])
        completed = bytearray(original)
        for i in range(cells):
            if flags[i] & 0xc000:
                assert struct.unpack_from('<H',original,20+i*2)[0] == planes[0][i]
                assert struct.unpack_from('<H',original,20+(cells+i)*2)[0] == planes[1][i]
                assert bool(flags[i]&256) == bool(planes[2][i])
            else:
                struct.pack_into('<H',completed,20+i*2,planes[0][i])
                struct.pack_into('<H',completed,20+(cells+i)*2,planes[1][i])
        runtime = bytearray(completed); remap = {}
        native_records = cut_records(ident)
        floor_count = cut_header(ident)[2]
        animated_start = sum(cut_header(ident)[2:4])
        for native in sorted({v for p in planes[:2] for v in p if v >= 1000}):
            record = native_records[native-1000]
            floor = native-1000 < floor_count
            animated = native-1000 >= animated_start
            key = (record, floor, animated)
            if key not in dedup:
                serial = next(available)
                art, origin, _ = cut_image(ident,native)
                assert art.width+4<=2048 and art.height+4<=2048, (ident,native,art.size)
                if px+art.width+4>2048:
                    px=0;py+=row_height;row_height=0
                if py+art.height+4>2048:
                    pages.append(page);page=Image.new('RGBA',(2048,2048));px=py=row_height=0
                page.paste(art,(px+2,py+2))
                graphics[str(serial)] = dict(page=page_offset+len(pages),rect=[px+2,py+2,*art.size],
                    origin=list(origin),footprint=[1,1],ground=floor,
                    family='void' if not animated and record[4:6]==(0,0) else 'floor' if floor else 'prop' if art.getbbox() else 'void',
                    rgba_sha256=sha(art.tobytes()),cut=list(record),cut_map=ident,cut_serial=native,
                    animated=animated)
                dedup[key]=serial;px+=art.width+4;row_height=max(row_height,art.height+4)
            remap[native]=dedup[key]
        for layer, values in enumerate(planes[:2]):
            for i, value in enumerate(values):
                struct.pack_into('<H',runtime,20+(layer*cells+i)*2,remap.get(value,value))
        mask=bytearray((cells+7)//8)
        for i,value in enumerate(planes[2]):
            if not value:mask[i>>3]|=1<<(i&7)
        ref=next(SOURCE.glob(str(ident)+'*'));title=ref.read_bytes()[8:40].split(b'\0')[0].decode('gb18030').split('|')[0]
        path=f'BlueCrossgate/map/0/{ident}.dat'
        maps[path]=dict(group='elsa',title=title,id=ident,size=[width,height],raw=encoded(original),
            sha256=sha(original),bytes=len(original),recorded=sum(bool(f&0xc000) for f in flags),cells=cells,
            completed_raw=encoded(completed),completed_sha256=sha(completed),
            restored_raw=encoded(runtime),restored_sha256=sha(runtime),walk=encoded(mask),
            art_remap={str(k):v for k,v in remap.items()},reference_only=client is None,
            layout_reference_sha256=sha(ref.read_bytes()),
            cut_sha256=sha((cg.SOURCE/f'Puk2/cutdat/{ident}.cut').read_bytes()),
            warp_cells=[[i%width,i//width] for i,f in enumerate(flags) if f&2],music=struct.unpack_from('>H',ref.read_bytes(),56)[0])
        proofs.append(dict(map=ident,client=sha(original),completed=sha(completed),runtime=sha(runtime),graphics=len(remap)))
        print('PREPARED',ident,len(remap),'graphics',flush=True)
    pages.append(page)
    result=dict(schema=1,maps=maps,graphics=graphics,page_offset=page_offset,pages=[f'elsa/atlas-{i}.png' for i in range(len(pages))],
                solid_pages=[f'elsa/solid-{i}.png' for i in range(len(pages))],surface_pages=[],
                source_preservation=proofs)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    if check:
        # Other regions can append atlas pages; runtime rebases this relative supplement.
        stored=json.loads((OUTPUT/'catalog.json').read_text())
        shift=int(stored['page_offset'])-page_offset
        result['page_offset']+=shift
        for graphic in graphics.values():graphic['page']+=shift
    text=json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n'
    if check:
        assert (OUTPUT/'catalog.json').read_text()==text,'Elsa map supplement is stale'
    else:
        (OUTPUT/'catalog.json').write_text(text)
    for i,im in enumerate(pages):
        path=OUTPUT/f'atlas-{i}.png'
        if check:
            with Image.open(path) as actual:assert actual.convert('RGBA').tobytes()==im.tobytes(),path
        else:im.save(path)
    print('ELSA_PREPARED',len(maps),len(graphics),'graphics',len(pages),'atlas pages',flush=True)


def prepare_population(pack=False):
    scope=json.loads((REPORT/'scope.json').read_text())
    atlas_path=ROOT/'assets/maps/falan/elsa'
    atlas_path.mkdir(parents=True,exist_ok=True)
    prepare_ownership(scope)
    actors=cg.catalog()['entries'];lookup=lib.serial_index()
    art={};images={};npcs=[];omitted=[]
    for record in npc_rows():
        if record['map'] not in scope['maps'] or record['kind'].startswith('#') or not owned_actor(record,scope):continue
        if not active_actor(record):
            omitted.append(dict(**record,reason='Later/private-server or inactive record; not classic presence evidence.'));continue
        if record['kind'] in ['SEPlay','WatchEx','StandEnemy','Warp'] or not record['name'] or record['graphic'] in [0,1]:continue
        graphic_id=record['graphic'];direction=record['direction'];token=f'{graphic_id}:{direction}'
        if token not in art:
            if graphic_id<100000 and graphic_id in lookup:
                g=lookup[graphic_id];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic_id}'
            else:
                choices=[a for a in actors if a['id']==graphic_id]
                assert choices,(record['name'],graphic_id)
                chosen=npc_appearance(choices);key=chosen['key']
                _,_,clips=cg.actor(key)
                idle=[c for c in clips if c['action']==0]
                clip=next((c for c in idle if c['direction']==direction),idle[0] if len(idle)==1 else None)
                assert clip is not None,(record['name'],graphic_id,direction,'Missing native idle direction')
                im,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=im.getbbox()
            assert box,(record['name'],graphic_id)
            im=im.crop(box);images[token]=im
            art[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=sha(im.tobytes()))
        npcs.append(dict(id=record['id'],type=record['kind'],name=record['name'],floor=record['map'],
                         source=record['map'],cell=record['cell'],direction=direction,graphic=graphic_id,
                         token=token,scenery=False,messages=['你好。'],raw=record['raw']))
        if temple_return(record):npcs[-1].update(source_version='corroborating snapshot; original-client parity unverified',source_script=record['script'])
    px=py=row_height=0
    for token,im in images.items():
        if px+im.width+2>1024:px=0;py+=row_height;row_height=0
        art[token]['rect']=[px+1,py+1,*im.size];px+=im.width+2;row_height=max(row_height,im.height+2)
    atlas=Image.new('RGBA',(1024,py+row_height))
    assert atlas.height<=16384
    for token,im in images.items():atlas.paste(im,tuple(art[token]['rect'][:2]))
    atlas.save(atlas_path/'npc-atlas.png')
    tables=ROOT/'assets/references/crossgate_tina/events'
    def rows(name):return [l.split('\t') for l in (tables/name).read_bytes().decode('gb18030').splitlines() if l and not l.startswith('#')]
    enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')};groups={r[2]:r for r in rows('group.txt')}
    zones=[];group_data={};species={}
    for zone in rows('encount.txt'):
        if int(zone[3]) not in scope['maps']:continue
        choices=[]
        for i,gid in enumerate(zone[14:24]):
            weight=int(zone[24+i] or 0)
            if not gid or not weight:continue
            group=groups[gid];members=[]
            for j,eid in enumerate(group[5:15]):
                probability=int(group[15+j] or 0)
                if not eid or eid=='0' or not probability:continue
                enemy=enemies[eid];base=bases[enemy[3]];appearance=int(base[30])
                if appearance not in species:
                    matches=[a for a in actors if a['id']==appearance]
                    actor=npc_appearance(matches)
                    species[appearance]=dict(id=appearance,key=actor['key'],name=base[0],height=1.)
                members.append([appearance,int(enemy[4]),int(enemy[5]),probability])
            group_data[gid]=dict(members=members,order=group[1],count_weights=[int(v or 0) for v in group[25:35]],raw=group)
            choices.append([gid,weight])
        zones.append(dict(id=int(zone[0]),map=int(zone[3]),bounds=list(map(int,zone[4:8])),
                          probability=list(map(int,zone[8:10])),maximum=int(zone[10]),priority=int(zone[11]),groups=choices,raw=zone))
    event_links=json.loads((REPORT/'links.json').read_text())
    for actor in npc_rows():
        blocked=any(actor['id']==b['actor'] or actor['map']==b['next_map'] for b in scope.get('blocked_rooms',[]))
        if not (actor['map'] in scope['route'] or blocked) or not active_actor(actor):continue
        path=SOURCE/actor['script']
        if not path.is_file():continue
        for number,line in enumerate(path.read_bytes().decode('gb18030').splitlines(),1):
            command=re.match(r'^\s*(Encount|Warp)\b',line,re.I)
            if not command:continue
            destinations=re.findall(r'0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',line)
            if destinations and not blocked:continue
            if command[1].lower()=='warp' and not blocked:continue
            for target in (destinations or [(None,None,None)]):
                event_links.append(dict(source=actor['map'],cell=actor['cell'],
                    kind='victory' if command[1].lower()=='encount' else 'event',
                    target=int(target[0]) if target[0] is not None else None,
                    landing=[int(target[1]),int(target[2])] if target[0] is not None else [],
                    proof=f'{actor["script"]}:{number}',command=line.strip(),
                    status='blocked branch: original entrance unverified' if blocked else 'local battle'))
    pet_manifest=json.loads((ROOT/'assets/characters/crossgate/guard_pets/motions.json').read_text())
    pet_skins={v['key']:i for i,v in enumerate(pet_manifest['variants'])}
    encounter_by_id={z[0]:z for z in rows('encount.txt')}
    battles=[];battle_groups={};seen=set()
    for link in event_links:
        if link['kind']!='victory':continue
        command=re.sub(r'^Encount\s+','',link['command'],flags=re.I)
        token=(link['source'],tuple(link['cell']),command)
        if token in seen:continue
        seen.add(token);fields=command.split('|');ident=fields[9]
        choices=([[ident,1]] if fields[0]=='3' else
                 [[gid,int(encounter_by_id[ident][24+i] or 0)] for i,gid in enumerate(encounter_by_id[ident][14:24])
                  if gid not in ['', '0'] and int(encounter_by_id[ident][24+i] or 0)])
        for gid,weight in choices:
            if gid in battle_groups:continue
            group=groups[gid];details=[]
            for eid in group[5:15]:
                if eid in ['', '0']:continue
                enemy=enemies[eid];base=bases[enemy[3]];appearance=int(base[30])
                matches=[a for a in actors if a['id']==appearance]
                pet=next((a for a in matches if a['key'] in pet_skins),None)
                if appearance not in species and pet is None:
                    actor=npc_appearance(matches)
                    species[appearance]=dict(id=appearance,key=actor['key'],name=base[0],height=1.)
                details.append(dict(appearance=appearance,name=base[0],enemy=eid,
                    bank='local' if appearance in species else 'companion',
                    pet_skin=pet_skins[pet['key']] if pet else -1,
                    level=[int(enemy[4]),int(enemy[5])],count=[int(enemy[6]),int(enemy[7])],
                    hp_override=int(enemy[9] or 0),raw_enemy=enemy,raw_base=base))
            battle_groups[gid]=dict(name=group[0],raw=group,details=details)
        owner=next((a for a in npc_rows() if a['map']==link['source'] and list(a['cell'])==list(link['cell']) and active_actor(a)),{})
        battles.append(dict(key=str(len(battles)),map=link['source'],cell=link['cell'],
                            name=owner.get('name','試煉'),groups=choices,
                            win=[link['target'],*link['landing']] if link['target'] is not None else [],proof=link['proof'],command=command))
    ordered=[species[k] for k in sorted(species)];skins={s['id']:i for i,s in enumerate(ordered)}
    assert len(ordered)<=29,'Use the companion bank or a per-map native bank above 29 species'
    for group in battle_groups.values():
        for member in group['details']:
            member['skin']=skins[member['appearance']] if member['bank']=='local' else member['pet_skin']
    for g in group_data.values():
        for member in g['members']:member[0]=skins[member[0]]
    result=dict(schema=1,npcs=npcs,art=art,species=ordered,zones=zones,groups=group_data,omitted=omitted,
                battles=battles,battle_groups=battle_groups,
                source_hashes={n:sha((tables/n).read_bytes()) for n in ['npc.txt','encount.txt','group.txt','enemy.txt','enemybase.txt']},
                limits=['Source random battles require Goemon real-time placement adaptation.',
                        'No encounter zones exist in the source for the island plaza, temple service halls or time passage.',
                        'Group count-column semantics require corroboration before enabling their probabilities.'])
    assert not {59520,59511,59530,59531,59534,59535,59536,59537}&{z['map'] for z in zones}
    (atlas_path/'population.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (atlas_path/'links.json').write_text(json.dumps(event_links,ensure_ascii=False,indent=2)+'\n')
    if pack:
        from recover_habaru_encounter import recover
        recover(ROOT.parent/'Magic Power',shalena=True,species_override=ordered,
                output_override=ROOT/'assets/characters/crossgate/elsa_region')
    print('ELSA_POPULATION',len(npcs),'NPCs',len(ordered),'species',len(zones),'source encounter zones',flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch-events', action='store_true')
    parser.add_argument('--fetch-scope', action='store_true')
    parser.add_argument('--room-scope', action='store_true')
    parser.add_argument('--render', type=int)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--population', action='store_true')
    parser.add_argument('--pack-creatures', action='store_true')
    args = parser.parse_args()
    if args.fetch_scope:
        fetch_scope()
    if args.room_scope:
        room_scope()
    rows, actors = inventory()
    if args.fetch_events:
        fetch(['gmsv/data/npc/' + r['script'] for r in actors if r['script'].endswith('.txt')])
    if args.render:
        render(args.render)
    if args.prepare or args.check:
        prepare(args.check)
    if args.population or args.pack_creatures:
        prepare_population(args.pack_creatures)
    print('ELSA_SOURCE', len(rows), 'maps', len(actors), 'actor records; recorded cells match')


if __name__ == '__main__':
    main()
