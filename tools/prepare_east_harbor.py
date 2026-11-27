"""Prepare native harbor residents and the source-backed, twenty-second voyages."""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Harbor Source'
OUT = ROOT / 'assets/maps/falan/east_region'
SHIP_MAPS = {1: list(range(41000, 41009)), 2: [41022, 41023, 41024, 41025, 41026, 41028],
             10: [32234, 32235, 32236], 20: [32082, 32083], 50: [32275, 59100]}
MAPS = {33214, 33219, 33215, 33220, 40001, 40002, 40003, 40006, 43190, 40004, 40005,
        32084, 32085, 59001,
        *(floor for floors in SHIP_MAPS.values() for floor in floors)}
TRANSFERS = {
    '305024': [33219, 22, 20], '305141': [2000, 57, 71],
    '305043': [40001, 17, 57], '305044': [40002, 17, 57],
    '305045': [33214, 33, 26], '305046': [33214, 33, 26],
    '305074': [33220, 28, 31], '305131': [33200, 56, 177],
    '305076': [40003, 18, 55], '305077': [33215, 15, 11],
    '305105': [43190, 1, 7],
    '305106': [40006, 84, 55],
    '1102043': [33517, 14, 11], '1102045': [43500, 20, 115],
    '1102235': [32080, 32, 25], '1102236': [32081, 32, 25],
}
BOARDING = {'305052': [1, 1, 2], '305078': [1, 2, 1], '305101': [2, 3, 4], '305102': [2, 4, 3],
            '1102044': [10, 6, 7], '1102046': [10, 7, 6],
            '1102234': [20, 8, 9], '1102232': [20, 9, 8], '1102413': [50, 20, 10]}
ATTENDANTS = {'305051': 1, '305103': 2, '1102040': 10, '1102230': 20, '1102412': 50}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_assets as cg
    import cg_library as lib
    lookup = lib.serial_index()
    proofs = json.loads((SOURCE / 'references.json').read_text())
    for proof in proofs:
        assert digest((SOURCE / Path(proof['path']).name).read_bytes()) == proof['sha256'], proof['path']
    # The Goral return clerk was discovered by the continental script trace.
    goral = SOURCE.parent / 'Verification/Goral Source Audit'
    return_proof = next(p for p in json.loads((goral/'references.json').read_text())
                        if p['path'] == 'gmsv/data/npc/EV_mag_305106.txt')
    assert digest((goral/return_proof['file']).read_bytes()) == return_proof['sha256']
    proofs.append(return_proof)
    ship_rows = [r.split('\t') for r in (SOURCE / 'ship.txt').read_bytes().decode('gb18030').splitlines() if r and not r.startswith('#')]
    harbor_rows = [r.split('\t') for r in (SOURCE / 'harbor.txt').read_bytes().decode('gb18030').splitlines() if r and not r.startswith('#')]
    ports = {int(r[1]): dict(name=r[0], floor=int(r[3]), cell=list(map(int, r[4:6]))) for r in harbor_rows}
    ships = {}
    for number in SHIP_MAPS:
        r = next(r for r in ship_rows if int(r[1]) == number)
        ships[str(number)] = dict(name=r[0], floor=int(r[3]), cell=list(map(int, r[4:6])), maps=SHIP_MAPS[number])
    assert ports[1]['floor'] == 40001 and ports[2]['floor'] == 40003
    assert ports[3]['floor'] == 40002 and ports[4]['floor'] == 40006
    index = ROOT.parent / 'Magic Power/research/jobs-sharing-20261031/source/npc-utf8.txt'
    images = {}; art = {}; residents = []; actions = {}; blockers = []
    for line in index.read_text().splitlines():
        row = line.split('\t')
        if len(row) != 25 or not row[8].isdigit() or row[0].startswith('#') or row[6] != '1': continue
        floor = int(row[8]); ident = row[3]
        if floor not in MAPS and ident != '305024': continue
        if row[0] in ['Warp', 'HouseWarp2', 'StandEnemy']: continue
        graphic = int(row[20] or 0); direction = int(row[19] or 0) % 8
        if graphic in [0, 1]: continue
        token = f'{graphic}:{direction}'
        if graphic not in lookup:
            with lib.connection() as db:
                native = db.execute('SELECT pack,row,serial,x,y,w,h,east,south,ground FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1', (graphic,)).fetchone()
            if native is not None: lookup[graphic] = dict(native)
        if token not in images:
            if graphic in lookup:
                g = lookup[graphic]; im = lib.image_from_record(g['pack'], g['row']); ox, oy = g['x'], g['y']; key = f'graphic:{graphic}'
            else:
                choices = [a['key'] for a in cg.catalog()['entries'] if a['id'] == graphic]
                choices.sort(key=lambda key: (not key.startswith('original:'), key))
                for key in choices:
                    _, _, clips = cg.actor(key)
                    clip = next((c for c in clips if c['action'] == 0 and c['direction'] == direction), None)
                    if clip is not None: break
                else: raise ValueError(f'Missing native harbor actor {ident}: {graphic}/{direction}')
                im, ox, oy = cg.frame_parts(key, clip['index'], 0)
            box = im.getbbox() or (0, 0, 1, 1); im = im.crop(box); images[token] = im
            art[token] = dict(key=key, origin=[ox+box[0], oy+box[1]], rgba_sha256=digest(im.tobytes()))
        record = dict(id=ident, type=row[0], name=row[1], floor=floor, source=floor, cell=list(map(int, row[9:11])),
                      direction=direction, graphic=graphic, token=token, scenery=False, messages=['你好。'], raw=row)
        if ident in ATTENDANTS:
            actions[ident] = dict(kind='status', ship=ATTENDANTS[ident])
            record['messages'] = ['船會在航程結束後自動靠港。']
        elif ident in BOARDING:
            ship, departure, arrival = BOARDING[ident]
            actions[ident] = dict(kind='voyage', ship=ship, departure=departure, arrival=arrival)
            record['messages'] = ['準備出航。與船員交談後，航程為二十秒。']
        elif ident in TRANSFERS:
            actions[ident] = dict(kind='transfer', target=TRANSFERS[ident], fare=500 if ident in ['305043','305044','305076','305106'] else 0)
            record['messages'] = ['船票為 500G。'] if actions[ident]['fare'] else ['請往這邊走。']
        if ident in actions:
            record['quest_action'] = 'east_harbor:'+ident
            if int(ident) >= 1000000:
                expansion = SOURCE.parent / 'Version Expansion Source Audit'
                proof = next(p for p in json.loads((expansion/'references.json').read_text())
                             if p['path'] == 'gmsv/data/npc/'+row[24])
                assert digest((expansion/proof['file']).read_bytes()) == proof['sha256']
                proofs.append(proof)
        elif row[0] == 'Event':
            # Harbor art ownership must not erase ghost-ship or other original quest scripts.
            record['quest_action'] = 'east_event:'+ident
            record['script'] = row[24]
        residents.append(record)
    x = y = height = 0
    for token, im in images.items():
        if x+im.width+2 > 1024: x=0; y+=height; height=0
        art[token]['rect'] = [x+1, y+1, im.width, im.height]; x+=im.width+2; height=max(height, im.height+2)
    atlas = Image.new('RGBA', (1024, max(1,y+height)))
    for token, im in images.items(): atlas.paste(im, tuple(art[token]['rect'][:2]))
    assert atlas.height <= 8192
    result = dict(schema=1, voyage_seconds=20, ships=ships, ports=ports, actions=actions, npcs=residents, art=art, blockers=blockers,
                  source_hashes={p['path']:p['sha256'] for p in proofs}, npc_index_sha256=digest(index.read_bytes()),
                  adaptations=['User-directed talk-to-crew departure and twenty seconds of active-play voyage replace the server timetable.',
                               'Explore has no original TrialFlg rank system; ordinary harbor admission does not fabricate or modify trial completion.',
                               'Original clerk fares and the source ship/port/map coordinates are retained.'],
                  boundary_connections=[dict(ship=50, source=59001, target=59000, cell=[50,49],
                     return_actor='1102410', return_ship_port=20, status='West region owns source59000; departure is held until its existing owner supplies the landing.')],
                  limits=['NPC wording is a short local placeholder; original script control fields, names, appearances and source facings are retained.'])
    return result, atlas


def main():
    result, atlas = prepare(); OUT.mkdir(parents=True, exist_ok=True)
    (OUT/'harbor.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    atlas.save(OUT/'harbor-npcs.png')
    print('EAST_HARBOR', len(result['npcs']), 'native residents;', len(result['actions']), 'actions;', len(BOARDING), 'twenty-second voyage directions')


if __name__ == '__main__': main()
