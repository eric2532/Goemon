"""Prepare pinned East Gate fixed maps without changing recorded client cells or shared atlases."""
import argparse
import ast
import base64
import json
import os
import struct
import sys
import zlib
from pathlib import Path
from types import SimpleNamespace

from PIL import Image
import recover_original_crossgate_maps as recovery

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/maps/original_crossgate'
OUT = ART / 'east'
MAP_INDEX = ROOT/'assets/maps/falan/east_region/map_index.gd'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
SOURCE = REPORT / 'Source Audit'
MANIFESTS = (SOURCE/'references.json', REPORT/'Harbor Source/references.json',
             REPORT/'Akelufa Source Audit/references.json', REPORT/'Verification/Goral Source Audit/references.json',
             REPORT/'Harbor Quest Source Audit/references.json', REPORT/'Version Expansion Source Audit/references.json')
EXISTING_OWNERS = {1155,2000,2400,11003,11004,11005,11028}
SHARED = {
    'base': ART / 'catalog.json',
    'sokia': ROOT / 'assets/maps/falan/sokia/fixed/catalog.json',
    'university': ART / 'university/catalog.json',
    'elsa': ART / 'elsa/catalog.json',
}
RENDER_IDS = (11031, 11034, 11038, 15506, 5008, 2800, 2801)
EXPANDED_ROWS = {}
INFERRED_BINDINGS={32265:{60057},32266:{60057},31954:{60074,60075,60077,60079,60081,60083,60086,60162,60163,60164,60165,60166,60167,60168,60169,60172,60173,60177,60312,60313,60317,60322,60324}}


def decode(row, key='raw'):
    return zlib.decompress(base64.b64decode(row.get(key, row['raw'])))


def active_raw(row):
    return decode(row,'reference_variant_raw' if row.get('active_layout_variant') == 'pinned-reference' else 'restored_raw')


def reference_map(raw, ident):
    if len(raw) < 44 or raw[:6] != b'LS2MAP' or struct.unpack_from('>H', raw, 6)[0] != ident:
        raise ValueError(f'Invalid pinned map identity: {ident}')
    w, h = struct.unpack_from('>HH', raw, 40)
    if not 0 < w <= 1024 or not 0 < h <= 1024 or len(raw) != 44+w*h*4:
        raise ValueError(f'Invalid pinned map dimensions or planes: {ident}')
    title = raw[8:40].split(b'\0', 1)[0].decode('gb18030').split('|')[0]
    return w, h, struct.unpack_from(f'>{w*h*2}H', raw, 44), title


def complete_map(raw, reference, ident):
    """Copy only unrecorded floor/object cells; a mismatched layout remains untouched."""
    w, h, values, _ = reference_map(reference, ident)
    cells = w*h
    if raw[:4] != b'MAP\x01' or len(raw) != 20+cells*6 or struct.unpack_from('<II', raw, 12) != (w, h):
        raise ValueError(f'Client/reference map dimensions differ: {ident}')
    planes = struct.unpack_from(f'<{cells*3}H', raw, 20)
    known = [i for i in range(cells) if planes[2*cells+i] & 0xc000]
    differences = [i for i in known if (planes[i], planes[cells+i]) != (values[i], values[cells+i])]
    water_frames = []
    if ident == 2000:
        # Il's56 recorded water animation frames are the same layout. Count
        # only actual layout differences, while preserving every known byte.
        water_frames = [i for i in differences if planes[cells+i] == values[cells+i]
                        and 5000 <= planes[i] <= 5008 and 5000 <= values[i] <= 5008]
    compatible = not known or (len(differences)-len(water_frames))/len(known) < .005
    final = bytearray(raw)
    completed = 0
    if compatible:
        for i in range(cells):
            if planes[2*cells+i] & 0xc000:
                continue
            if (planes[i], planes[cells+i]) != (values[i], values[cells+i]):
                struct.pack_into('<H', final, 20+i*2, values[i])
                struct.pack_into('<H', final, 20+(cells+i)*2, values[cells+i])
                completed += 1
    assert final[:20] == raw[:20] and final[20+cells*4:] == raw[20+cells*4:]
    assert all(final[20+i*2:22+i*2] == raw[20+i*2:22+i*2] and
               final[20+(cells+i)*2:22+(cells+i)*2] == raw[20+(cells+i)*2:22+(cells+i)*2]
               for i in known), ident
    evidence = dict(recorded=len(known), cells=cells, completed=completed,
                    preserved_client_variations=len(differences), compatible=compatible,
                    layout_complete=compatible or len(known) == cells)
    if ident == 2000:
        evidence.update(preserved_water_frame_variations=len(water_frames),
                        meaningful_layout_differences=len(differences)-len(water_frames),
                        compatibility_scope='Il2000 only:5000..5008 water frames with identical object layer; all known tuples and the original marker plane remain untouched.')
    return bytes(final), evidence


def shared_graphics():
    """Resolve shared owners without assigning their mutable runtime page positions."""
    graphics, owners, catalogs, evidence = {}, {}, {}, []
    for name, path in SHARED.items():
        catalog = json.loads(path.read_text())
        catalogs[name] = catalog
        evidence.append(dict(owner=name, path=str(path.relative_to(ROOT)), sha256=recovery.digest(path.read_bytes())))
        for serial, graphic in catalog['graphics'].items():
            if serial in graphics:
                continue
            graphics[serial] = graphic
            owners[serial] = name
    return graphics, owners, catalogs, evidence


def pinned_maps(manifests):
    references, excluded = {}, []
    for manifest in manifests:
        inventory = manifest.parent/'inventory.json'
        summary = json.loads(inventory.read_text()) if inventory.exists() else {}
        owned = {int(row['id'] if isinstance(row,dict) else row) for row in summary.get('maps',[])} if summary else None
        for entry in json.loads(manifest.read_text()):
            if '/map/' not in entry['path']:
                continue
            proof = dict(entry)
            filename = proof.get('file', Path(proof['path']).name)
            path = manifest.parent/filename
            raw = path.read_bytes()
            assert recovery.digest(raw) == proof['sha256'], path
            if raw[:6] != b'LS2MAP':
                raise ValueError(f'Invalid pinned map format: {path}')
            ident = struct.unpack_from('>H', raw, 6)[0]
            if 1000<=ident<2000 and ident!=1155 or owned is not None and ident not in owned:
                excluded.append(dict(source=ident, reason='Existing Falan interior boundary keeps its current owner.' if 1000<=ident<2000 else 'Reference-only boundary outside this source inventory ownership.', reference=proof))
                continue
            if ident in references:
                assert references[ident][0]['sha256'] == proof['sha256'], f'Conflicting pinned map {ident}'
                continue
            proof['local_path'] = str(path.relative_to(ROOT))
            references[ident] = (proof, raw)
    return references, excluded


def expanded_lookup(lib, serials, lookup):
    """EX DAT serials omit 200000; their unexpanded numbers can identify unrelated UI art."""
    result = lookup.copy()
    aliases = {}
    with lib.connection() as db:
        for serial in sorted(s for s in serials if s >= 20000):
            if serial not in EXPANDED_ROWS:
                row = db.execute('SELECT pack,row,serial,x,y,w,h,east,south,ground FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1',
                                 (serial+200000,)).fetchone()
                EXPANDED_ROWS[serial] = dict(row) if row is not None else None
            row = EXPANDED_ROWS[serial]
            if row is None:
                result.pop(serial, None)
                continue
            result[serial] = dict(row)
            aliases[serial] = 1_000_000+int(row['serial'])
    return result, aliases


def extend_solid_pixels(art):
    """Match the established nearest-edge fill, copying contiguous RGB gaps as bytes."""
    w,h = art.size
    rgba = art.tobytes(); rgb = art.convert('RGB').tobytes()
    rows, occupied = {}, []
    for y in range(h):
        source = rgb[y*w*3:(y+1)*w*3]
        alpha = rgba[y*w*4+3:(y+1)*w*4:4]
        marks = [x for x,a in enumerate(alpha) if a and max(source[x*3:x*3+3])>40]
        if not marks:
            continue
        row = bytearray(source)
        first,last = marks[0],marks[-1]
        row[:first*3] = source[first*3:first*3+3]*first
        row[(last+1)*3:] = source[last*3:last*3+3]*(w-last-1)
        for left,right in zip(marks,marks[1:]):
            gap = right-left-1
            if gap == 0:
                continue
            left_count = (right-left)//2
            row[(left+1)*3:right*3] = source[left*3:left*3+3]*left_count+source[right*3:right*3+3]*(gap-left_count)
        occupied.append(y); rows[y] = bytes(row)
    if not occupied:
        return Image.new('RGB',art.size)
    final = []; cursor = 0
    for y in range(h):
        while cursor+1<len(occupied) and abs(occupied[cursor+1]-y)<abs(occupied[cursor]-y):
            cursor += 1
        final.append(rows.get(y,rows[occupied[cursor]]))
    return Image.frombytes('RGB',art.size,b''.join(final))


def solid_pages(graphics,pages):
    result = [Image.new('RGB',page.size) for page in pages]
    for graphic in graphics.values():
        x,y,w,h = graphic['rect']
        native = pages[graphic['page']].crop((x,y,x+w,y+h))
        filled = extend_solid_pixels(native)
        if graphic.get('family') == 'room_wall':
            filled.paste(native.convert('RGB'), (0, 0), native.getchannel('A').point(lambda value: 255 if value else 0))
        result[graphic['page']].paste(filled,(x,y))
    return result


def previous_art():
    """Reuse this supplement's verified native pages when source discovery adds maps."""
    path = OUT/'catalog.json'
    if not path.exists():
        return {},[],[],[]
    catalog = json.loads(path.read_text())
    if catalog.get('page_indices') != 'local':
        return {},[],[],[]
    pages = [Image.open(ART/page).convert('RGBA') for page in catalog['pages']]
    surfaces = [Image.open(ART/page).convert('RGB') for page in catalog['surface_pages']]
    solids = [Image.open(ART/page).convert('RGB') for page in catalog['solid_pages']]
    return catalog['graphics'],pages,surfaces,solids


def same_source(graphic,entry):
    return (graphic.get('pack'),graphic.get('row'),graphic['origin'],graphic['footprint']) == (entry['pack'],entry['row'],[entry['x'],entry['y']],[entry['east'],entry['south']])


def navigation_function(lib):
    # Importing this module also builds an unrelated TalesWeaver catalog; reuse only its exact pure helper.
    path = ROOT.parent/'Magic Power/tools/prepare_field_assets.py'
    definition = next(node for node in ast.parse(path.read_text()).body if isinstance(node,ast.FunctionDef) and node.name=='navigation_grid')
    scope = {'cg':lib.cg}
    exec(compile(ast.Module(body=[definition],type_ignores=[]),str(path),'exec'),scope)
    return scope['navigation_grid']


def prepare(manifests=MANIFESTS):
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    navigation_grid = navigation_function(lib)
    from build_falan_room_art import KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND
    from build_coastal_villages import KINDS, WALLS
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({s: 'room_wall' for s in WALLS if s >= 16000})
    lookup = lib.serial_index()
    existing, owners, catalogs, shared = shared_graphics()
    prior_graphics,prior_pages,prior_surfaces,prior_solids = previous_art()
    references, excluded = pinned_maps(manifests)
    outdoors, inferred_roofless, generated_graphics, animated_stairs = {}, set(), set(), set()
    for manifest in manifests:
        inventory = manifest.parent/'inventory.json'
        if not inventory.exists():
            continue
        summary = json.loads(inventory.read_text())
        outdoor_evidence=summary.get('outdoor_evidence',{})
        if isinstance(outdoor_evidence,list):
            outdoor_evidence={str(row['id']):row for row in outdoor_evidence}
        for ident in summary.get('outdoor_ids',[]):
            outdoors[ident] = dict(inventory=str(inventory.relative_to(ROOT)),
                                  evidence=outdoor_evidence.get(str(ident),'Source audit classifies this original map as exterior.'))
        inferred_roofless.update(summary.get('inferred_roofless_ids',[]))
        for dungeon in summary.get('dungeons',[]):
            for column in (22,34,35,*range(57,min(97,len(dungeon['raw'])),4)):
                value=str(dungeon['raw'][column]).strip()
                serial = int(value) if value else 0
                if 0 < serial < 65536:
                    generated_graphics.add(serial)
                elif serial >= 65536:
                    animated_stairs.add(serial)
    previous_paths = set().union(*(catalog['maps'] for catalog in catalogs.values()))
    previous_ids = {row['id'] for row in json.loads((REPORT/'Runtime Audit/runtime-coverage.json').read_text())['maps']}
    with lib.connection() as db:
        files = {r['path']: r['id'] for r in db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    maps, used, evidence, blockers, variants = {}, set(), [], [], []
    packed_lookup = lookup.copy()
    graphic_sources = {}
    checked_art = {}
    source_images = {}
    def prepared_image(pack, row):
        key = (pack,row)
        if key not in source_images:
            source_images[key] = lib.image_from_record(pack,row)
        return source_images[key]
    for map_number, (ident, (proof, reference)) in enumerate(sorted(references.items())):
        if map_number%50 == 0:
            print('EAST_MAP_SOURCE_PROGRESS',map_number,'of',len(references),'source',ident,flush=True)
        w, h, values, title = reference_map(reference, ident)
        cells = w*h
        path = f'BlueCrossgate/map/0/{ident}.dat'
        provenance = {}
        # Read original client bytes, never a prepared derivative from another owner.
        if path in files:
            _, payload = lib.source_file(files[path])
            raw = payload.read_bytes() if isinstance(payload, Path) else payload
            provenance.update(source_file_id=files[path], source_path=path)
        else:
            raw = b'MAP\x01'+bytes(8)+struct.pack('<II', w, h)+struct.pack(f'<{cells*3}H', *values, *([0xc000]*cells))
            provenance.update(reference_only=True, layout_reference=proof)
        variant = b'MAP\x01'+bytes(8)+struct.pack('<II', w, h)+struct.pack(f'<{cells*3}H', *values, *([0xc000]*cells))
        dimension_conflict = ''
        try:
            final, preservation = complete_map(raw, reference, ident)
        except ValueError as error:
            native_w,native_h,_,_,native_flags = lib.parse_map(raw)
            final = raw; dimension_conflict = str(error)
            preservation = dict(recorded=sum(bool(f&0xc000) for f in native_flags), cells=native_w*native_h,
                                completed=0, preserved_client_variations=None, compatible=False, layout_complete=False)
        select_variant = not preservation['compatible'] and path not in previous_paths and ident not in previous_ids
        active = variant if select_variant else final
        if select_variant:
            variants.append(dict(source=ident, reason=dimension_conflict or 'Full pinned source variant selected instead of mixing incompatible client cells.',
                                 client_recorded=preservation['recorded'], client_cells=preservation['cells'],
                                 differing=preservation['preserved_client_variations'], reference=proof,
                                 original_sha256=recovery.digest(raw), selected_sha256=recovery.digest(variant)))
        elif not preservation['layout_complete']:
            blockers.append(dict(source=ident, reason='Pinned layout differs from recorded client cells; unknown cells remain unfilled.',
                                 compared=preservation['recorded'], differing=preservation['preserved_client_variations'],
                                 layout_complete=False, existing_owner=ident in EXISTING_OWNERS))
        w, h, floor, objects, flags = lib.parse_map(active)
        cells = w*h
        serials = {s for s in floor if s} | {s for s in objects if s >= 1000}
        expanded = Path(proof['path']).name.lower().startswith(('ex_', 'cg2_', 'tw_'))
        map_lookup, aliases = expanded_lookup(lib, serials, lookup) if expanded else (lookup, {})
        inferred_bindings = []
        for native in sorted((serials&INFERRED_BINDINGS.get(ident,set()))-map_lookup.keys()):
            binding, resolved = expanded_lookup(lib,{native},lookup)
            if native in resolved:
                map_lookup=map_lookup.copy();map_lookup[native]=binding[native];aliases={**aliases,native:resolved[native]}
                description='blue teleport crystal/pedestal' if native==60057 else 'bridge board, suspension post or gate component'
                inferred_bindings.append(dict(native_serial=native,source_serial=native+200000,
                    basis=f'Unique available counterpart is the {description}; unprefixed source map does not prove client namespace. Native pixels, origin and footprint preserved.'))
        unavailable = serials-map_lookup.keys()
        if unavailable:
            blockers.append(dict(source=ident, reason='Native source graphics unavailable; map omitted.', graphics=sorted(unavailable), activated=False))
            continue
        invalid_art = {}
        for serial in serials:
            graphic_id = str(aliases.get(serial,serial))
            if graphic_id in existing or graphic_id in prior_graphics and same_source(prior_graphics[graphic_id],map_lookup[serial]):
                continue
            entry = map_lookup[serial]
            key = (entry['pack'],entry['row'])
            if key not in checked_art:
                try:
                    image = prepared_image(*key)
                    checked_art[key] = '' if image.width+4 <= recovery.PAGE and image.height+4 <= recovery.PAGE else 'Source image exceeds the shared atlas page size.'
                except (ValueError,OSError) as error:
                    checked_art[key] = str(error)
            if checked_art[key]:
                invalid_art[serial] = checked_art[key]
        if invalid_art:
            blockers.append(dict(source=ident, reason='Native artwork cannot be safely packed; map omitted.', graphics=invalid_art, activated=False))
            continue
        conflicts = []
        for serial in serials:
            if serial in aliases or str(serial) not in existing:
                continue
            g, entry = existing[str(serial)], map_lookup[serial]
            if (g.get('pack'), g.get('row'), g['origin'], g['footprint']) != (entry['pack'], entry['row'], [entry['x'],entry['y']], [entry['east'],entry['south']]):
                native = lib.image_from_record(entry['pack'], entry['row'])
                if recovery.digest(native.tobytes()) != g['rgba_sha256']:
                    conflicts.append(serial)
        if conflicts:
            blockers.append(dict(source=ident, reason='Shared graphic identity differs from source; map omitted instead of replacing shared art.', graphics=sorted(conflicts), activated=False))
            continue
        for serial in serials:
            graphic_id = aliases.get(serial, serial)
            packed_lookup[graphic_id] = map_lookup[serial]
            if serial in aliases:
                graphic_sources[graphic_id] = dict(source_serial=int(map_lookup[serial]['serial']), source_native_serial=serial)
        used.update(aliases.get(s,s) for s in serials)
        walk = navigation_grid(w, h, floor, objects, map_lookup)
        walk_override = {}
        if ident==41029:
            opened=[[x,y] for y in range(4,7) for x in range(4,7)]
            for x,y in opened:walk[y*w+x]=True
            walk_override=dict(opened_cells=opened,kind='technical-cutscene-adaptation',
                reason='Original storm-sea cutscene has no native walkable terrain. A center3x3 interaction anchor permits the source landing(5,5) and exact surrounding EventNPC ring; source sea planes and artwork are unchanged.')
        mask = bytearray((cells+7)//8)
        for i, opened in enumerate(walk):
            if opened:
                mask[i>>3] |= 1 << (i & 7)
        row = dict(group='east_region', title=title, id=ident, size=[w,h], raw=recovery.encode(raw),
                   sha256=recovery.digest(raw), bytes=len(active), walk=recovery.encode(mask),
                   native_bytes=len(raw), native_size=list(struct.unpack_from('<II',raw,12)),
                   recorded=preservation['recorded'], cells=cells, layout_complete=select_variant or preservation['layout_complete'],
                   warp_cells=[[i%w,i//w] for i,value in enumerate(flags) if value & 2], **provenance)
        row['music_metadata']=dict(status='not-recorded-in-classic-header',audio_fidelity='unverified',header_bytes=44,
            source=proof['local_path'],source_sha256=proof['sha256'],
            note='Classic two-plane LS2MAP starts floor data at44; offset56 is a floor cell, not the extended-header music field. No track ID inferred.')
        if ident in EXISTING_OWNERS:
            row['east_existing_owner'] = True
        if not preservation['compatible']:
            row.update(reference_variant_raw=recovery.encode(variant), reference_variant_sha256=recovery.digest(variant),
                       reference_variant_bytes=len(variant), reference_variant_size=list(struct.unpack_from('<II',variant,12)),
                       reference_variant_source=proof, active_layout_variant='pinned-reference' if select_variant else 'preserved-client')
        if aliases:
            row['graphic_aliases'] = {str(native):alias for native,alias in sorted(aliases.items())}
        if inferred_bindings:
            row['inferred_graphic_bindings']=inferred_bindings
        if walk_override:
            row['walk_override']=walk_override
        if ident in outdoors:
            row['outdoor'] = True
            row['outdoor_reference'] = outdoors[ident]
        if ident in inferred_roofless:
            row['inferred_roofless'] = True
        if final != raw:
            row.update(restored_raw=recovery.encode(final), restored_sha256=recovery.digest(final),
                       restored_cells=preservation['completed'], completion_reference=proof,
                       reference_compared_cells=preservation['recorded'],
                       preserved_client_variations=preservation['preserved_client_variations'])
        if ident == 2000:
            row['completion_semantics'] = {key:preservation[key] for key in
                ('preserved_water_frame_variations','meaningful_layout_differences','compatibility_scope')}
        maps[path] = row
        evidence.append(dict(source=ident, title=title, **preservation, reference_only=bool(provenance.get('reference_only')),
                             active_layout_complete=row['layout_complete'], active_layout_variant=row.get('active_layout_variant','preserved-client'),
                             original_sha256=row['sha256'], runtime_sha256=recovery.digest(active), reference=proof))
        if walk_override:evidence[-1]['walk_override']=walk_override
    missing_generated = generated_graphics-lookup.keys()
    if missing_generated:
        blockers.append(dict(reason='Static source graphics required by generated dungeon floors are unavailable.', graphics=sorted(missing_generated)))
    used.update(generated_graphics- missing_generated)
    novel = used-set(map(int, existing))
    print('EAST_MAP_SOURCE_SCAN',len(maps),'fixed maps',len(novel),'novel graphics',len(blockers),'blockers',flush=True)
    retained = {}
    for ident in sorted(novel):
        key = str(ident)
        if key not in prior_graphics or not same_source(prior_graphics[key],packed_lookup[ident]):
            continue
        graphic = prior_graphics[key]
        x,y,w,h = graphic['rect']
        if recovery.digest(prior_pages[graphic['page']].crop((x,y,x+w,y+h)).tobytes()) == graphic['rgba_sha256']:
            retained[key] = graphic
    fresh = novel-set(map(int,retained))
    if fresh:
        pages, graphics, _ = recovery.pack_graphics(fresh, packed_lookup, furniture, SimpleNamespace(image_from_record=prepared_image))
        for graphic_id, provenance in graphic_sources.items():
            if str(graphic_id) not in graphics:
                continue
            graphic = graphics[str(graphic_id)]
            graphic.update(provenance)
            native = provenance['source_native_serial']
            if graphic['ground'] and graphic['rect'][3] > 60 and 38000 <= native < 39000:
                graphic['shore_bank'] = True
        temporary = dict(graphics=graphics)
        surfaces = recovery.rock_surfaces(temporary, pages)
        solids = solid_pages(graphics, pages)
    else:
        pages, graphics, surfaces, solids = [], {}, [], []
    if retained:
        for graphic in graphics.values():
            graphic['page'] += len(prior_pages)
            if 'surfaces' in graphic:
                graphic['surfaces'][0] += len(prior_surfaces)
        graphics = {**retained,**graphics}
        pages = prior_pages+pages; surfaces = prior_surfaces+surfaces; solids = prior_solids+solids
    graphics = dict(sorted(graphics.items(),key=lambda item:int(item[0])))
    reused = {str(serial): owners[str(serial)] for serial in sorted(used-novel)}
    catalog = dict(schema=1, maps=maps, graphics=graphics, page_indices='local', surface_indices='local',
                   pages=[f'east/atlas-{i}.png' for i in range(len(pages))],
                   surface_pages=[f'east/surfaces-{i}.png' for i in range(len(surfaces))],
                   solid_pages=[f'east/solid-{i}.png' for i in range(len(solids))],
                   reused_graphics=reused, requires=sorted(set(reused.values())-{'base'}), shared_catalogs=shared,
                   generated_graphics=sorted(generated_graphics-missing_generated), animated_stair_markers=sorted(animated_stairs),
                   source_manifests=[dict(path=str(path.relative_to(ROOT)),sha256=recovery.digest(path.read_bytes())) for path in manifests],
                   excluded_source_maps=excluded,
                   fixed_ids=sorted(row['id'] for row in maps.values()))
    report = dict(maps=evidence, blockers=blockers, excluded_source_maps=excluded, selected_reference_variants=variants, new_graphics=len(novel), reused_graphics=len(reused),
                  inference='Fixed source planes and native source artwork only; no new rooms, paths or 3D geometry are authored by this preparer.')
    return catalog, pages, surfaces, solids, report


def render_reference(raw, lib, lookup, maximum=1600):
    """Render the retained original planes as a read-only isometric reference."""
    w, _, floor, objects, _ = lib.parse_map(raw)
    placements = []
    images = {}
    for layer, plane in enumerate((floor, objects)):
        for i, serial in enumerate(plane):
            if serial == 0 or layer == 1 and serial < 1000:
                continue
            g = lookup[serial]
            if serial not in images:
                images[serial] = lib.image_from_record(g['pack'], g['row'])
            x, z = i%w, i//w
            placements.append((0 if layer == 0 or g['ground'] else 1,
                               11*z-9*x-min(g['east'],g['south'])*10,
                               (x+z)*32+g['x'], (z-x)*24+g['y'], serial, i))
    if not placements:
        return Image.new('RGBA', (1,1))
    left = min(p[2] for p in placements); top = min(p[3] for p in placements)
    right = max(p[2]+images[p[4]].width for p in placements)
    bottom = max(p[3]+images[p[4]].height for p in placements)
    scale = min(1.0, maximum/max(right-left,bottom-top))
    result = Image.new('RGBA', (max(1,round((right-left)*scale)),max(1,round((bottom-top)*scale))), '#252923')
    if scale < 1:
        images = {serial:image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.LANCZOS) for serial,image in images.items()}
    for _, _, x, y, serial, _ in sorted(placements):
        result.alpha_composite(images[serial], (round((x-left)*scale),round((y-top)*scale)))
    return result


def map_index(catalog):
    ids = catalog['fixed_ids']
    aliases = {ident:ident+1000000 for ident in ids if 51000<=ident<59500}
    return ('extends RefCounted\n## Generated by tools/prepare_east_region_maps.py; keeps the large catalog lazy.\n'
            +'const FIXED=['+','.join(map(str,ids))+']\n'
            +'const RUNTIME_ALIASES={'+','.join(f'{source}:{runtime}' for source,runtime in aliases.items())+'}\n'
            +'const REVERSE_ALIASES={'+','.join(f'{runtime}:{source}' for source,runtime in aliases.items())+'}\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--render', action='store_true', help='Write native isometric reference images of selected new fixed rooms.')
    parser.add_argument('--manifest', type=Path, action='append', help='Use these pinned reference manifests instead of the default eastern and harbor manifests.')
    args = parser.parse_args()
    catalog, pages, surfaces, solids, evidence = prepare(tuple(path.resolve() for path in args.manifest) if args.manifest else MANIFESTS)
    encoded = json.dumps(catalog, ensure_ascii=False, separators=(',',':'))+'\n'
    OUT.mkdir(parents=True, exist_ok=True)
    index = map_index(catalog)
    for prefix, images in [('atlas',pages),('surfaces',surfaces),('solid',solids)]:
        for i, expected in enumerate(images):
            path = OUT/f'{prefix}-{i}.png'
            if args.check:
                with Image.open(path) as actual:
                    assert actual.size == expected.size and actual.tobytes() == expected.tobytes(), path
            elif not path.exists():
                expected.save(path)
            else:
                with Image.open(path) as actual:
                    changed = actual.size != expected.size or actual.tobytes() != expected.tobytes()
                if changed:
                    expected.save(path)
    # Publish descriptors only after every referenced page exists; readers never see half-written JSON/GDScript.
    for path,value in [(OUT/'catalog.json',encoded),(MAP_INDEX,index)]:
        if args.check:
            assert path.read_text()==value,f'Stale East descriptor: {path}'
        elif not path.exists() or path.read_text()!=value:
            path.parent.mkdir(parents=True,exist_ok=True);temporary=path.with_suffix(path.suffix+'.pending')
            temporary.write_text(value);os.replace(temporary,path)
    (REPORT/'fixed-map-preservation.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2)+'\n')
    if args.render:
        import cg_library as lib
        lookup = lib.serial_index()
        destination = REPORT/'Native Fixed Map References'
        destination.mkdir(exist_ok=True)
        for ident in RENDER_IDS:
            path = f'BlueCrossgate/map/0/{ident}.dat'
            if path in catalog['maps']:
                render_reference(active_raw(catalog['maps'][path]),lib,lookup).save(destination/f'{ident}.png')
    print('EAST_FIXED_MAPS', len(catalog['maps']), 'new_graphics', len(catalog['graphics']), 'reused_graphics', len(catalog['reused_graphics']), 'blockers', len(evidence['blockers']))


if __name__ == '__main__':
    main()
