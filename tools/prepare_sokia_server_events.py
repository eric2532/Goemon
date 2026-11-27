"""Prepare the missing-client maps' source NPCs without repacking existing art."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

from PIL import Image
from prepare_east_region_population import compile_script
from prepare_east_region_maps import active_raw
from prepare_sokia_server_maps import IDS, OUT, ROOT
from prepare_snow_region_population import rows, SOURCE as TABLES

SOURCE = ROOT / 'assets/references/crossgate_sokia/events'
EVENTS = OUT / 'events'
MESSAGE_ALIASES = {'51523': ('1051523', 'mayko_gm_1102312.txt'),
                   '11054713': ('1054713', 'mayko_gm_1051676.txt')}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare(map_catalog=None, wanted_ids=None, additional_ids=frozenset(), frontier=False):
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_assets as cg
    import cg_library as lib
    from recover_habaru_encounter import body_rows
    lookup = lib.serial_index()
    catalog = map_catalog if map_catalog is not None else json.loads((OUT / 'catalog.json').read_text())
    maps = {int(row['id']): row for row in catalog['maps'].values()}
    if map_catalog is None: assert len(maps) == 13 and set(maps) <= IDS
    references = {row['file']: row for row in json.loads((SOURCE / 'references.json').read_text())}
    if additional_ids:
        references.update({row['file']: row for row in json.loads((SOURCE / 'explore-extra-references.json').read_text())})
    if frontier:
        references.update({row['file']: row for row in json.loads((SOURCE / 'frontier-references.json').read_text())})
    messages = {row[0]: row[1].replace('\\n', '\n') for row in rows('msg.txt') if len(row) > 1}
    if frontier:
        for missing, (original, _) in MESSAGE_ALIASES.items():messages[missing] = messages[original]
    keys = {}
    for row in cg.catalog()['entries']:
        if row['key'].startswith('original:') or additional_ids and int(row['id']) == 110750 and row['key'] == 'puk2:332':
            keys.setdefault(int(row['id']), []).append(row['key'])
    if frontier:
        for row in cg.catalog()['entries']:
            if row['key'] not in keys.setdefault(int(row['id']), []):
                keys[int(row['id'])].append(row['key'])
    actors = {}; excluded = []; scripts = {}; proofs = {}; images = {}; art = {}; used_messages = set(); message_repairs = []
    source_lines = (TABLES / 'npc.txt').read_bytes().decode('gb18030').splitlines()
    for line, text in enumerate(source_lines, 1):
        raw = text.split('\t')
        if text.startswith('#') or len(raw) != 25 or not raw[8].isdigit() or int(raw[8]) not in maps:
            continue
        if wanted_ids is not None and raw[3] not in wanted_ids:
            continue
        if raw[0] in ['Warp', 'HouseWarp2'] or raw[6] != '1':
            continue
        ident = raw[3]; graphic = int(raw[20] or 0); direction = int(raw[19] or 0) % 8
        if int(ident) >= 300000 and ident not in additional_ids:
            excluded.append(dict(id=ident, raw=raw, reason='Later source ID; original-release presence requires corroboration.'))
            continue
        assert graphic > 1
        token = f'{graphic}:{direction}'
        if token not in art:
            if frontier and not keys.get(graphic) and graphic not in lookup:
                with lib.connection() as db:
                    row = db.execute('SELECT pack,row,serial,x,y,w,h,east,south,ground FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1', (graphic,)).fetchone()
                if row is not None:
                    lookup = lookup.copy(); lookup[graphic] = dict(row)
            if graphic in lookup and (graphic < 100000 or frontier and not keys.get(graphic)):
                g = lookup[graphic]; image = lib.image_from_record(g['pack'], g['row'])
                ox, oy = g['x'], g['y']; key = f'graphic:{graphic}'
            else:
                candidates = keys[graphic]
                coherent = [key for key in candidates if key.startswith('original:') and 2800 <= int(key.split(':')[1]) < 3000]
                key = coherent[-1] if coherent else candidates[0]
                _, _, clips = cg.actor(key)
                if frontier and not any(c['action'] == 0 and c['direction'] == direction for c in clips):
                    key = next(k for k in candidates if any(c['action'] == 0 and c['direction'] == direction for c in cg.actor(k)[2]))
                    _, _, clips = cg.actor(key)
                clip = next(c for c in clips if c['action'] == 0 and c['direction'] == direction)
                image, ox, oy = cg.frame_parts(key, clip['index'], 0)
            box = image.getbbox(); assert box or frontier, token
            images[token] = image.crop(box) if box else Image.new('RGBA', (1, 1))
            art[token] = dict(key=key, origin=[ox + (box[0] if box else 0), oy + (box[1] if box else 0)],
                              source_direction=direction, source_rgba_sha256=sha(image.tobytes()),
                              rgba_sha256=sha(images[token].tobytes()))
            if graphic >= 14000 and box:
                top, foot = body_rows(image)
                art[token].update(body_top=top-box[1], body_foot=foot-box[1],
                                  foot_contract='Existing body_rows removes source charcoal shadow; pixels, scale and source cell unchanged.')
        script = raw[24]
        if script.endswith('.txt'):
            proof = references[script]; payload = (SOURCE / script).read_bytes()
            assert sha(payload) == proof['sha256'], script
            scripts[script] = compile_script(payload); proofs[script] = proof
            if frontier:
                # Isolated source typos: the same NO handler repeatedly uses1051523;
                # the random conversation's sibling ending uses1054713.
                aliases = {missing: original for missing, (original, owner) in MESSAGE_ALIASES.items() if owner == script}
                for missing, original in aliases.items():
                    assert original in messages
                    messages[missing] = messages[original]
                    repair = dict(script=script, missing=missing, source_message=original, scope='Dialogue text alias only; original script bytes, conditions and side effects retained.')
                    if repair not in message_repairs:message_repairs.append(repair)
            for _, command in scripts[script]['lines']:
                match = re.match(r'\s*(?:End)?Window\s+(\d+)', command, re.I)
                if match: used_messages.add(str(int(match[1])))
        actor = dict(id=ident, name=raw[1], type=raw[0], source=int(raw[8]), floor=int(raw[8]), area='interior',
                     cell=list(map(int, raw[9:11])), direction=direction, graphic=graphic, token=token,
                     script=script, raw=raw, source_line=line, scenery=graphic < 14000,
                     rendered_elsewhere=False, dialogue_owner='sokia_server',
                     target_release='Pinned original-candidate reference; BlueCG release execution not authenticated.')
        if not images[token].getbbox():actor['invisible'] = True
        source_map = maps[actor['source']]; width, height = source_map['size']; x, y = actor['cell']
        assert 0 <= x < width and 0 <= y < height
        cells = width * height; decoded = active_raw(source_map)
        actor['rendered_elsewhere'] = struct.unpack_from('<H', decoded, 20 + (cells + y*width+x)*2)[0] == graphic
        walk = zlib.decompress(base64.b64decode(source_map['walk']))
        index = y*width+x; actor['source_cell_blocked'] = not bool(walk[index >> 3] & (1 << (index & 7)))
        if raw[0] == 'TownPeople':
            ids = [str(int(mid)) for mid in script.split('|') if mid]; assert all(mid in messages for mid in ids)
            actor['messages'] = [messages[mid] for mid in ids]
            if not ids:actor['source_dialogue_empty'] = True
        elif raw[0] == 'Windowman':
            # Source label-based signs use the existing ordinary conversation presentation.
            ids = [str(int(match[1])) for _, command in scripts[script]['lines']
                   if (match := re.match(r'\s*Window\s+(\d+)', command, re.I))]
            assert ids, (ident, script, 'Source sign has no window')
            actor['messages'] = [messages[mid] for mid in ids]
            actor['sign_adaptation'] = 'Original label-based sign windows; ordinary conversation cycles their source text without event side effects.'
        else:
            ids = [str(int(m[1])) for _, c in scripts.get(script, {}).get('lines', []) if (m := re.match(r'\s*Window\s+(\d+)', c, re.I))]
            actor['messages'] = [messages[ids[0]]] if ids else []
            if script in scripts or raw[0] == 'StandEnemy':
                actor['quest_action'] = 'sokia_server:' + ident
        actors[ident] = actor
    if map_catalog is None and wanted_ids is None:
        assert len(actors) == 19 and {row['id'] for row in excluded} == {'807215', '807216'}
    x = y = height = 0; atlas = Image.new('RGBA', (1024, 2048))
    for token, image in images.items():
        if x + image.width + 2 > atlas.width: x = 0; y += height; height = 0
        if y + image.height + 2 > atlas.height:
            assert frontier and atlas.height < 16384, 'Source NPC atlas exceeds supported texture size'
            enlarged = Image.new('RGBA', (atlas.width, atlas.height * 2))
            enlarged.paste(atlas, (0, 0)); atlas = enlarged
        atlas.paste(image, (x+1, y+1)); art[token]['rect'] = [x+1, y+1, *image.size]
        x += image.width + 2; height = max(height, image.height + 2)
    assert not used_messages - messages.keys(), ('Missing original source messages', sorted(used_messages - messages.keys()))
    data = dict(schema=1, actors=actors, excluded=excluded, art=art, scripts=scripts,
                messages={mid: messages[mid] for mid in sorted(used_messages, key=int)}, source_provenance=proofs,
                source_hashes={name: sha((TABLES / name).read_bytes()) for name in ['npc.txt', 'msg.txt']},
                source_map_sha256={str(ident): row['source_floor_object_sha256'] for ident, row in maps.items()},
                message_repairs=message_repairs,
                limitations=['Unknown original skill, inventory capacity, item-age or group predicates remain guarded by the existing event interpreter.',
                             'Presence of NPC scripts is not proof that a map is safe or that a target map has a usable runtime owner.',
                             'Server maps contain no client warp/record flags. Exact source fixed-port candidates remain separately assessed.'])
    return data, atlas.crop((0, 0, atlas.width, y + height))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=EVENTS)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(); data, image = prepare()
    path = args.output / 'data.json'; text = json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n'
    if args.check:
        assert path.read_text() == text
        with Image.open(args.output / 'npc-atlas.png') as actual:
            assert actual.mode == image.mode and actual.size == image.size and actual.tobytes() == image.tobytes()
    else:
        args.output.mkdir(parents=True, exist_ok=True); path.write_text(text); image.save(args.output / 'npc-atlas.png')
    print('SOKIA_SERVER_NPCS', len(data['actors']), 'original candidates;', len(data['excluded']), 'later IDs pending;', len(data['scripts']), 'source scripts')


if __name__ == '__main__':
    main()
