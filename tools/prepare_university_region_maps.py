"""Prepare a source-preserving regional supplement; never repack the existing map atlases."""
import argparse
import base64
import copy
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

from PIL import Image
import recover_original_crossgate_maps as recovery
import review_university_region as review

ROOT = review.ROOT
OUT = ROOT / 'assets/maps/original_crossgate/university'
MOUNTAIN_TEMPLATES=[2765,3013,3941,3955,3962,4043,4085,4398,4414,4447,4865,4895]


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    from build_falan_room_art import KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND
    from build_coastal_villages import KINDS, WALLS
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({s: 'room_wall' for s in WALLS if s >= 16000})
    lookup = lib.serial_index()
    base = json.loads(review.CATALOG.read_text())
    scope = json.loads((review.OUT / 'scope.json').read_text())
    proofs = {p['file']: p for p in json.loads((review.SOURCE / 'references.json').read_text())}
    maps = {}; used = {13996,13997}; evidence = []; blockers = [];mountain=[]
    shared_elsa=json.loads((ROOT/'assets/maps/original_crossgate/elsa/catalog.json').read_text())['maps']
    with lib.connection() as db:
        files = {r['path']: r['id'] for r in db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/0/%'")}
    for entry in scope['fixed']:
        ident = entry['source']; path = f'BlueCrossgate/map/0/{ident}.dat'
        cached = base['maps'].get(path); reference = entry['reference']
        if not reference:
            if ident==59752 and path in shared_elsa:
                evidence.append(dict(source=ident,shared_owner='elsa',runtime_sha256=shared_elsa[path]['restored_sha256']))
                continue
            if not cached: blockers.append(dict(source=ident, reason='No fixed source layout is available in the pinned regional reference.'))
            continue
        proof = proofs[reference['file']]
        original = (review.SOURCE / reference['file']).read_bytes()
        assert recovery.digest(original) == proof['sha256'], reference['file']
        assert original[:6] == b'LS2MAP' and struct.unpack_from('>H', original, 6)[0] == ident
        w, h = struct.unpack_from('>HH', original, 40); cells = w*h
        assert 0 < w <= 1024 and 0 < h <= 1024 and len(original) == 44+cells*4
        values = struct.unpack_from(f'>{cells*2}H', original, 44)
        provenance = {}
        if cached:
            raw = zlib.decompress(base64.b64decode(cached['raw']))
            final = bytearray(zlib.decompress(base64.b64decode(cached.get('restored_raw', cached['raw']))))
        elif path in files:
            payload = lib.source_file(files[path])[1]
            raw = payload.read_bytes() if isinstance(payload, Path) else payload
            final = bytearray(raw)
        else:
            raw = b'MAP\x01'+bytes(8)+struct.pack('<II', w, h)+struct.pack(f'<{cells*3}H', *values, *([0xc000]*cells))
            final = bytearray(raw)
            provenance = dict(reference_only=True, layout_reference=proof)
        assert struct.unpack_from('<II', raw, 12) == (w, h) and len(raw) == 20+cells*6
        planes = struct.unpack_from(f'<{cells*3}H', raw, 20)
        known = [i for i in range(cells) if planes[2*cells+i] & 0xc000]
        differences = [i for i in known if (planes[i], planes[cells+i]) != (values[i], values[cells+i])]
        completed = 0
        # The campus reference is a visibly different version. Do not relax the overlap check to fill it.
        compatible = not known or len(differences) / len(known) < .005
        if compatible:
            for i in range(cells):
                if planes[2*cells+i] & 0xc000: continue
                if (planes[i], planes[cells+i]) != (values[i], values[cells+i]):
                    struct.pack_into('<H', final, 20+i*2, values[i])
                    struct.pack_into('<H', final, 20+(cells+i)*2, values[cells+i])
                    completed += 1
        else:
            blockers.append(dict(source=ident, reason='Pinned layout version differs from the recorded client; unknown ground remains unfilled.', compared=len(known), differing=len(differences)))
        assert all(final[20+i*2:22+i*2] == raw[20+i*2:22+i*2] and final[20+(cells+i)*2:22+(cells+i)*2] == raw[20+(cells+i)*2:22+(cells+i)*2] for i in known), ident
        assert final[20+cells*4:] == raw[20+cells*4:], 'Keep original flags intact'
        _, _, floor, objects, flags = lib.parse_map(bytes(final))
        serials = {s for s in floor if s} | {s for s in objects if s >= 1000}
        unavailable = serials - lookup.keys()
        if unavailable:
            blockers.append(dict(source=ident, reason='Native source graphics unavailable; map not activated.', graphics=sorted(unavailable)))
            continue
        used.update(serials)
        walk = navigation_grid(w, h, floor, objects, lookup)
        mask = bytearray((cells+7)//8)
        for i, opened in enumerate(walk):
            if opened: mask[i>>3] |= 1 << (i & 7)
        row = copy.deepcopy(cached) if cached else {}
        row.update(group='university_region', title=entry['title'], id=ident, size=[w,h],
                   raw=recovery.encode(raw), sha256=recovery.digest(raw), bytes=len(raw),
                   walk=recovery.encode(mask), recorded=len(known), cells=cells,
                   warp_cells=[[i%w,i//w] for i,v in enumerate(flags) if v & 2], **provenance)
        if bytes(final) != raw:
            row.update(restored_raw=recovery.encode(final), restored_sha256=recovery.digest(final),
                       restored_cells=completed, completion_reference=proof,
                       reference_compared_cells=len(known), preserved_client_variations=len(differences))
        maps[path] = row
        evidence.append(dict(source=ident, recorded=len(known), cells=cells, completed=completed,
                             preserved_variations=len(differences), reference_only=bool(provenance),
                             original_sha256=row['sha256'], runtime_sha256=recovery.digest(final)))
    # These are complete native Snow Mountain snapshots, not cache visit numbers treated as floors.
    for ident in MOUNTAIN_TEMPLATES:
        info,payload=lib.source_file(ident);raw=payload.read_bytes() if isinstance(payload,Path) else payload
        w,h,floor,objects,flags=lib.parse_map(raw);cells=w*h
        assert w==40 and 40<=h<=80 and all(value&0xc000 for value in flags)
        assert objects.count(17956)==objects.count(17957)==1 and 8175 in floor and 8177 not in floor
        walk=navigation_grid(w,h,floor,objects,lookup);mask=bytearray((cells+7)//8)
        for i,opened in enumerate(walk):
            if opened:mask[i>>3]|=1<<(i&7)
        up=objects.index(17956);down=objects.index(17957)
        path=info['path'];digest=recovery.digest(raw)
        maps[path]=dict(group='university_mountain_template',title='積雪的山路',id=14400,size=[w,h],raw=recovery.encode(raw),
                        sha256=digest,bytes=len(raw),walk=recovery.encode(mask),recorded=cells,cells=cells,
                        warp_cells=[[i%w,i//w] for i,value in enumerate(flags) if value&2])
        mountain.append(dict(path=path,size=[w,h],up=[up%w,up//w],down=[down%w,down//w],source_file_id=ident,sha256=digest))
        used.update(v for v in floor if v);used.update(v for v in objects if v>=1000)
    generated_graphics={9555,17954,17955,17974,17975}
    assert not generated_graphics-lookup.keys(), 'Original generated-floor graphics are unavailable'
    used.update(generated_graphics)
    novel = used - set(map(int, base['graphics']))
    pages, graphics, _ = recovery.pack_graphics(novel, lookup, furniture, lib)
    catalog = dict(schema=1, maps=maps, graphics=graphics,mountain_templates=mountain,
                   base_sha256=recovery.digest(review.CATALOG.read_bytes()),
                   pages=[f'university/atlas-{i}.png' for i in range(len(pages))])
    surfaces = recovery.rock_surfaces(catalog, pages)
    solids = recovery.solid_pages(catalog, pages)
    catalog['surface_pages'] = [f'university/surfaces-{i}.png' for i in range(len(surfaces))]
    catalog['solid_pages'] = [f'university/solid-{i}.png' for i in range(len(solids))]
    # Indices address the append-only merged arrays in the existing map-art owner.
    for g in graphics.values():
        g['page'] += len(base['pages'])
        if 'surfaces' in g: g['surfaces'][0] += len(base['surface_pages'])
    return catalog, pages, surfaces, solids, dict(maps=evidence, blockers=blockers, new_graphics=len(novel))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    catalog, pages, surfaces, solids, evidence = prepare()
    text=json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n'
    if args.check:
        assert (OUT/'catalog.json').read_text()==text, 'Regional supplement is stale'
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        if not (OUT/'catalog.json').exists() or (OUT/'catalog.json').read_text()!=text:(OUT/'catalog.json').write_text(text)
    for prefix, images in [('atlas',pages),('surfaces',surfaces),('solid',solids)]:
        for i, expected in enumerate(images):
            path=OUT/f'{prefix}-{i}.png'
            if args.check:
                with Image.open(path) as actual: assert actual.size==expected.size and actual.tobytes()==expected.tobytes(),path
            elif not path.exists():expected.save(path)
            else:
                with Image.open(path) as actual:changed=actual.size!=expected.size or actual.tobytes()!=expected.tobytes()
                if changed:expected.save(path)
    (review.OUT/'map-preservation.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    print('UNIVERSITY_MAPS',len(catalog['maps']),'new_graphics',len(catalog['graphics']),'blockers',len(evidence['blockers']))


if __name__=='__main__':main()
