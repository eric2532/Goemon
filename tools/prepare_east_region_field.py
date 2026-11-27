"""Restore source-confirmed shore caps and prepare reachable East field dungeon entries."""
import hashlib
import json
import sys
import struct
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
FRAMES = {'east_gate': ('east_road_surface.png', (-675, -204)),
          'north_coast': ('north_coast_surface.png', (-480, -480))}


def source_pixel(area, x, y):
    return (422-y, x-349) if area == 'east_gate' else (x-474, y+49)


def source_area(x, y):
    return 'north_coast' if y < 100 and x > 510 or x > 670 and y < 210 else 'east_gate'


def prepare():
    sys.path[:0] = [str(ROOT.parent / 'Magic Power/tools')]
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    with lib.connection() as db:
        fid = db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/100.dat'").fetchone()[0]
    _, path = lib.source_file(fid)
    cached = path.read_bytes(); w, h, cached_ground, cached_objects, cached_flags = lib.parse_map(cached)
    reference = REPORT / 'Version Expansion Source Audit/map__00100_field1'
    raw = reference.read_bytes(); sw, sh = struct.unpack_from('>HH', raw, 40)
    assert (w, h) == (sw, sh)
    cells = w*h
    ground = struct.unpack_from('>'+str(cells)+'H', raw, 44)
    objects = struct.unpack_from('>'+str(cells)+'H', raw, 44+cells*2)
    assert all((ground[y*w+x], objects[y*w+x]) == (cached_ground[y*w+x], cached_objects[y*w+x])
               for y in range(360) for x in range(440,w) if cached_flags[y*w+x] & 0xc000)
    flags = [0xc000]*cells
    lookup = lib.serial_index()
    native = navigation_grid(w, h, ground, objects, lookup)
    masks = {}; corrections = []
    for area, (filename, _) in FRAMES.items():
        source = ROOT / 'assets/maps/falan' / filename
        image = Image.open(source).convert('RGBA')
        if area == 'east_gate':
            wider = Image.new('RGBA', (image.width+1, image.height)); wider.paste(image, (0,0)); image = wider
        for y in range(h):
            for x in range(w):
                i = y*w+x
                if x < 440 or y >= 360:
                    continue
                px, py = source_pixel(area, x, y)
                if not 0 <= px < image.width or not 0 <= py < image.height:
                    continue
                wet = 5000 <= ground[i] <= 5008 or ground[i] in [0,100]
                cap = native[i] and 12500 <= objects[i] <= 12535
                road = 5198 <= ground[i] <= 5233 or 6400 <= ground[i] <= 6409
                pixel = (0 if cap or not wet else 255, 255 if road else 0, 0, 255)
                if cap and image.getpixel((px, py))[0] >= 128:
                    corrections.append(dict(area=area, cell=[x, y], source_graphic=objects[i]))
                image.putpixel((px, py), pixel)
        masks[area] = image
        image.save(OUT / f'{area}-surface.png')
    def opened(area, x, y):
        if not 0 <= x < w or not 0 <= y < h:
            return False
        i = y*w+x
        if not native[i] or not flags[i] & 0xc000:
            return False
        image = masks[area]; px, py = source_pixel(area, x, y)
        if not 0 <= px < image.width or not 0 <= py < image.height:
            return False
        r, _, _, a = image.getpixel((px, py))
        return a >= 128 and r < 128
    components = {}
    for area, start in [('east_gate', (475, 196)), ('north_coast', (691, 188))]:
        assert opened(area, *start), (area, start)
        seen = {start}; pending = deque([start])
        while pending:
            x, y = pending.popleft()
            for p in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
                if p not in seen and opened(area, *p):
                    seen.add(p); pending.append(p)
        components[area] = seen
    graph = json.loads((REPORT / 'Version Expansion Source Audit/graph.json').read_text())
    scenery = {a:dict(trees=[], details=[], ridges=[]) for a in FRAMES}
    mouths = [l['cell'] for l in graph['links'] if l['source']==100 and l.get('cell')
              and (l['kind']=='fixed warp' and l['target'] not in [1000,2000,2400]
                   or l['kind']=='inline Warp')]
    handoffs = []
    for y in range(360):
        for x in range(440,w):
            serial=objects[y*w+x]; area=source_area(x,y)
            px,py=source_pixel(area,x,y)
            if not 0<=px<masks[area].width or not 0<=py<masks[area].height:
                continue
            if serial==10000 or 10058<=serial<=10094:
                kind='cedar' if serial<=10065 else 'pine' if serial<=10073 else 'tree'
                scenery[area]['trees'].append([x,y,serial,kind,1.15 if serial>=10085 else .9])
            asset=None
            if 11661<=serial<=11679:asset='grass_tall'
            elif serial in [11656,11659,11696,11697,11698,12169,12170,12171]:asset='flowers_ivory'
            elif 12175<=serial<=12180:asset='flowers_coral'
            elif 12107<=serial<=12130 or 12225<=serial<=12244:asset='mossy_boulder'
            if asset:
                entry=lookup[serial]
                scale=min(.75,entry['w']/110) if asset=='mossy_boulder' else min(2.2,entry['w']/24)
                scenery[area]['details'].append([x,y,serial,asset,scale])
            if 12500<=serial<=12565:
                if any(abs(x-a)<=6 and abs(y-b)<=6 for a,b in mouths):
                    handoffs.append(dict(cell=[x,y],graphic=serial,owner='Existing native entrance/cave-mouth geometry; avoid sealing its approach.'))
                    continue
                entry=lookup[serial]; ew,ns=max(1,entry['east']),max(1,entry['south']); tall=serial>=12536
                rise=max(9,(entry['h']-46)*.050) if tall else min(1.4,entry['h']*.012)
                if tall and ew==ns==1:rise*=.63
                scenery[area]['ridges'].append([x+(ew-1)*.5,y-(ns-1)*.5,serial,ew*3,ns*3,rise,tall])
    (OUT/'field-scenery.json').write_text(json.dumps(scenery,separators=(',',':'))+'\n')
    candidates = {}; entrances = []
    for dungeon in graph['dungeons']:
        if dungeon['source'] != 100:
            continue
        rect = dungeon['rectangle']; entries = []
        for y in range(rect[1], rect[3]+1):
            for x in range(rect[0], rect[2]+1):
                area = source_area(x, y)
                if (x, y) in components[area] and (x, y+1) in components[area]:
                    entries.append([x, y])
        assert entries, f'No recorded reachable entrance in source rectangle {dungeon["id"]}'
        candidates[str(dungeon['id'])] = entries
        entrances.append(dict(config=dungeon['id'], rectangle=rect, reachable_candidates=len(entries)))
    approaches = []; blockers = []; arrivals = {}
    points = {(tuple(l['cell']), 'warp:'+str(l['target'])) for l in graph['links']
              if l['source'] == 100 and l.get('cell') and l['kind'] != 'generated dungeon'}
    points |= {(tuple(l['landing']), 'return:'+str(l['source'])) for l in graph['links']
               if l['target'] == 100 and l.get('landing')}
    points |= {(tuple(a['cell']), 'actor:'+str(a['id'])) for a in graph['actors'] if a['map'] == 100}
    for (x, y), name in sorted(points):
        area = source_area(x, y)
        closest = min(((abs(x-cx)+abs(y-cy), cx, cy) for cx, cy in components[area]), default=(9999, 0, 0))
        row = dict(cell=[x, y], kind=name, area=area, reachable=closest[0] <= 1,
                   approach=[closest[1], closest[2]], source_distance=closest[0])
        approaches.append(row)
        if name.startswith('return:') and closest[0] <= 2:
            arrivals[f'{x},{y}'] = [closest[1], closest[2]]
            if not row['reachable']:
                row['runtime_landing'] = arrivals[f'{x},{y}']
                row['inferred'] = 'The source return cell conflicts with native field navigation; the established nearby safe-landing tolerance is applied.'
        elif not row['reachable']:
            blockers.append(dict(row, blocker_kind='field_approach'))
    evidence = dict(source=str(reference.relative_to(ROOT)), source_sha256=hashlib.sha256(raw).hexdigest(),
        cache_source='BlueCrossgate/map/0/100.dat', cache_sha256=hashlib.sha256(cached).hexdigest(),
        selected_variant='Whole pinned LS2MAP variant within East-owned field windows; zero disagreements with all82179recorded East cells.',
        scenery_counts={a:{kind:len(rows) for kind,rows in record.items()} for a,record in scenery.items()},
        entrance_scenery_handoffs=handoffs,
        corrections=corrections, component_sizes={a:len(c) for a,c in components.items()},
        approaches=approaches, generated_entries=entrances, blockers=blockers,
        limits=['The full compatible pinned map supplies terrain/path/shoreline placement inside East windows; other region owners and original masks remain intact.',
                'Entry cells are drawn from source rectangles using a seeded shuffled candidate bag; exact original server placement is unavailable.',
                'Four-neighbour source-grid checks do not establish rendered collision clearance or gameplay appearance.'])
    (OUT / 'field-entries.json').write_text(json.dumps(candidates, separators=(',', ':'))+'\n')
    (OUT / 'field-arrivals.json').write_text(json.dumps(arrivals, separators=(',', ':'))+'\n')
    (REPORT / 'field-approaches.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2)+'\n')
    print('EAST_FIELD', len(corrections), 'native caps;', len(approaches), 'approaches;', len(blockers), 'specific blockers')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    prepare()
