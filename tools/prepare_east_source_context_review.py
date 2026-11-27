"""Private merged100 recovery and source-sized2400 input; never publish runtime assets."""
import base64
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import struct
import sys

from PIL import Image
from prepare_east_il_low_source import rectangles
from prepare_east_region_maps import reference_map

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
OUT = REPORT / 'Village Props/Cliff Audit/Source Context Audit/Prototype'
FULL = ROOT / 'assets/maps/falan/east_region/alyut_source_completion'
HOST = REPORT / 'Il Source Completion/Low Source Candidate/Host'
CORE = REPORT / 'Runtime Audit/Source100 Candidate'


def sha(raw): return hashlib.sha256(raw).hexdigest()


def main():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    canonical_path = ROOT / 'assets/maps/falan/freyja_source/100.dat'
    host_path = HOST / '100.dat'; pin_path = REPORT / 'Version Expansion Source Audit/map__00100_field1'
    baseline, host, pinned = [p.read_bytes() for p in [canonical_path, host_path, pin_path]]
    host_contract = json.loads((HOST / 'source-contract.json').read_text())
    assert sha(host) == host_contract['prepared_sha256']
    assert sha(baseline) == host_contract['source_hashes'][str(canonical_path.relative_to(ROOT))]
    w, h, bg, pg, flags = lib.parse_map(host)
    rw, rh, native, _ = reference_map(pinned, 100); count = w * h
    assert (w, h) == (rw, rh) == (840, 610)
    after = bytearray(host); enrolled = set(); restored = []; known = []; before = lib.parse_map(baseline)
    for y in range(20, 120):
        for x in range(529, 629):
            i = y * w + x; enrolled.add(i)
            assert not (636 <= x < 726 and 312 <= y < 423)
            old, target = (bg[i], pg[i]), (native[i], native[count+i])
            assert old == (before[2][i], before[3][i]), 'The two private source windows must be disjoint'
            if flags[i] & 0xc000 or any(old):
                assert old == target, 'Inspect any source100 variant difference instead of overwriting it'
                known.append([x, y]); continue
            assert old == (0, 0) and target != old
            struct.pack_into('<H', after, 20+i*2, target[0]); struct.pack_into('<H', after, 20+(count+i)*2, target[1])
            restored.append({'cell': [x, y], 'before': old, 'after': target})
    assert len(restored) == 1489 and len(known) == 8511
    after = bytes(after); _, _, town_bg, town_pg, town_flags = lib.parse_map(after)
    assert after[:20] == host[:20] == baseline[:20] and after[20+count*4:] == host[20+count*4:] == baseline[20+count*4:]
    assert town_flags == flags
    assert all((town_bg[i], town_pg[i]) == (bg[i], pg[i]) for i in range(count) if i not in enrolled or flags[i]&0xc000 or bg[i] or pg[i])
    core_path = CORE / '100.dat'; core_contract_path = CORE / 'preservation.json'
    core = core_path.read_bytes(); core_contract = json.loads(core_contract_path.read_text())
    assert sha(core) == core_contract['candidate_sha256'] == '71003c698bda7808f433d29d38167c70ec22b1c4a3177189881d240cce502422'
    assert sha(baseline) == core_contract['source_active_sha256'] == '1005a9032918d1be6108d5b0a7e5925225c16a576519f2b772417df68ad18850'
    _, _, cbg, cpg, cflags = lib.parse_map(core); assert cflags == flags
    assert core[:20] == baseline[:20] and core[20+count*4:] == baseline[20+count*4:]
    changes = {name: {} for name in ['core', 'il', 'alyut']}; overlaps = []
    for name, layer in [('core', (cbg,cpg)), ('il', (bg,pg)), ('alyut',(town_bg,town_pg))]:
        for i in range(count):
            target = (layer[0][i],layer[1][i]); original = (before[2][i],before[3][i])
            if target == original: continue
            assert not flags[i]&0xc000 and original == (0,0)
            if name == 'alyut' and i not in enrolled: continue
            changes[name][i] = target
    assert [len(changes[name]) for name in ['core','il','alyut']] == [42662,6702,1489]
    merged = bytearray(baseline); chosen = {}
    for name, selected in changes.items():
        for i, target in selected.items():
            if i in chosen:
                assert chosen[i][1] == target, 'Conflicting source completion candidates'
                overlaps.append({'cell':[i%w,i//w], 'first':chosen[i][0], 'second':name, 'identical_tuple':target})
            else: chosen[i] = (name,target)
            struct.pack_into('<H',merged,20+i*2,target[0]);struct.pack_into('<H',merged,20+(count+i)*2,target[1])
    after = bytes(merged); _, _, new_bg, new_pg, new_flags = lib.parse_map(after)
    assert new_flags == flags
    assert after[:20] == baseline[:20] and after[20+count*4:] == baseline[20+count*4:]
    assert all((new_bg[i],new_pg[i]) == (before[2][i],before[3][i]) for i in range(count) if i not in chosen)
    lookup = lib.serial_index(); merged_walk = navigation_grid(w, h, new_bg, new_pg, lookup)
    OUT.mkdir(parents=True, exist_ok=True); (OUT / '.gdignore').touch(); (OUT / '100.dat').write_bytes(after)
    field = {'schema': 1, 'source': 100, 'size': [w, h], 'raw_path': 'res://' + str((OUT / '100.dat').relative_to(ROOT)),
             'raw_sha256': sha(after), 'base_host_sha256': sha(host), 'canonical_baseline_sha256': sha(baseline),
             'source100_pinned_sha256': sha(pinned), 'source_window': [529, 20, 100, 100], 'base_host_window': [636, 312, 90, 111],
             'combined_changed_counts': {name:len(rows) for name,rows in changes.items()}, 'combined_changed_union':len(chosen), 'identical_overlaps':overlaps,
             'restored': restored, 'known_cells_preserved': len(known), 'markers_sha256': sha(after[20+count*4:]),
             'native_walk_bits': base64.b64encode(bytes(sum((1 << (i & 7)) if merged_walk[i] else 0 for i in range(start, min(start+8, count))) for start in range(0, count, 8))).decode(),
             'source_hashes': {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in [canonical_path, host_path, HOST / 'source-contract.json', core_path, core_contract_path, pin_path]},
             'preservation': ['Merge core42662 + Il6702 + Alyut1489 zero/unrecorded tuple fills from one immutable1005a903baseline; any overlap must agree exactly and be listed.', 'All8511 known Alyut-field tuples, every tuple outside the combined changed union, entire header and marker plane remain exact.', 'Raw restoration is not physical support, route or visual acceptance.']}
    (OUT / 'field100-restore.json').write_text(json.dumps(field, indent=2) + '\n')
    provenance = json.loads((canonical_path.parent/'provenance.json').read_text()); provenance.update({'active':False,'active_sha256':sha(after),'stage':'PRIVATE-combined-East-source-context','completion_scope':field['preservation'][0],'whole_map100_active':False})
    (OUT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    from build_freyja_surface import build
    old_override = os.environ.get('CROSSGATE_FREYJA_SOURCE_DIR')
    os.environ['CROSSGATE_FREYJA_SOURCE_DIR'] = str(OUT)
    try: build(ROOT.parent/'Magic Power',OUT,100,lookup)
    finally:
        if old_override is None:os.environ.pop('CROSSGATE_FREYJA_SOURCE_DIR',None)
        else:os.environ['CROSSGATE_FREYJA_SOURCE_DIR']=old_override
    original_atlas=ROOT/'assets/maps/falan/freyja_ground_atlas.png'
    old_atlas=Image.open(original_atlas).convert('RGB');candidate_atlas=Image.open(OUT/'freyja_ground_atlas.png').convert('RGB')
    from build_falan_room_art import COLS, STRIDE, project_tile
    old_index=Image.open(ROOT/'assets/maps/falan/freyja_ground_index.png').convert('RGBA')
    index=Image.open(OUT/'freyja_ground_index.png').convert('RGBA');old_slots={}
    for i,serial in enumerate(new_bg):
        pixel=old_index.getpixel((i%w,i//w))
        if pixel[3] and serial not in [0,100]:
            slot=pixel[0]+pixel[1]*COLS
            assert serial not in old_slots or old_slots[serial]==slot
            old_slots[serial]=slot
    new_serials=sorted({s for s in new_bg if s not in [0,100] and s in lookup and (lookup[s]['w'],lookup[s]['h'])==(64,47)}-old_slots.keys())
    assert new_serials==[5250]
    first_new_slot=(old_atlas.height//STRIDE)*COLS
    appended=Image.new('RGB',(old_atlas.width,((first_new_slot+len(new_serials)+COLS-1)//COLS)*STRIDE));appended.paste(old_atlas,(0,0));added=[]
    for offset,serial in enumerate(new_serials):
        slot=first_new_slot+offset;graphic=lookup[serial];rgba=lib.image_from_record(graphic['pack'],graphic['row']).convert('RGBA');tile=project_tile(rgba)
        appended.paste(tile,(slot%COLS*STRIDE,slot//COLS*STRIDE))
        for i,value in enumerate(new_bg):
            if value==serial:index.putpixel((i%w,i//w),(slot%COLS,slot//COLS,0,255))
        added.append({'graphic':serial,'slot':slot,'source_rgba_sha256':sha(rgba.tobytes()),'projected_sha256':sha(tile.tobytes())})
    for serial,slot in old_slots.items():
        tile=candidate_atlas.crop((slot%COLS*STRIDE,slot//COLS*STRIDE,slot%COLS*STRIDE+STRIDE,slot//COLS*STRIDE+STRIDE))
        assert tile.tobytes()==old_atlas.crop((slot%COLS*STRIDE,slot//COLS*STRIDE,slot%COLS*STRIDE+STRIDE,slot//COLS*STRIDE+STRIDE)).tobytes()
    assert appended.crop((0,0,*old_atlas.size)).tobytes()==old_atlas.tobytes()
    for i in range(count):
        old_pixel=old_index.getpixel((i%w,i//w))
        if old_pixel[3]:assert index.getpixel((i%w,i//w))==old_pixel
    appended.save(OUT/'freyja_ground_atlas.png',optimize=True);index.save(OUT/'freyja_ground_index.png',optimize=True)
    field['ground']={'existing_graphics':len(old_slots),'existing_atlas_size':old_atlas.size,'private_atlas_size':appended.size,'original_atlas_rgb_sha256':sha(old_atlas.tobytes()),'original_atlas_prefix_rgb_sha256':sha(appended.crop((0,0,*old_atlas.size)).tobytes()),'added':added,'index_sha256':sha((OUT/'freyja_ground_index.png').read_bytes()),'atlas_sha256':sha((OUT/'freyja_ground_atlas.png').read_bytes()),'legacy_index_nonzero_pixels_preserved':True}
    (OUT/'field100-restore.json').write_text(json.dumps(field,indent=2)+'\n')
    full = json.loads((FULL / 'map-data.json').read_text()); raw = (FULL / 'hybrid-map.bin').read_bytes()
    tw, th, tbg, tpg, _ = lib.parse_map(raw); assert (tw, th) == (100, 100)
    walk = navigation_grid(tw, th, tbg, tpg, lookup); assert sum(walk) == 4597
    opened = lambda i: bool(walk[i]); water = lambda i: tpg[i] == 252; bank = lambda i: 12500 <= tpg[i] < 12536
    cells = []
    for i in range(10000):
        role = 'water_control' if water(i) else 'bank' if bank(i) else 'dry' if tbg[i] and tbg[i] not in range(5000,5009) else 'water_or_void'
        assert not opened(i) or role in ['water_control', 'bank', 'dry']
        cells.append([i%tw, i//tw, tbg[i], tpg[i], struct.unpack_from('<H', raw, 20+40000+i*2)[0], int(opened(i)), role])
    floors = []
    for kind, high, select in [('land_bank', 6., lambda i: opened(i) and not water(i)), ('water_control', 2., lambda i: opened(i) and water(i))]:
        for rect in rectangles(tw, th, select): floors.append({'source_rect': rect, 'height': high, 'kind': kind})
    mask = Image.open(FULL / 'mask.png').convert('RGBA')
    for i,tile in enumerate(tbg):
        x,y=i%tw,i//tw;old=mask.getpixel((x,y))
        mask.putpixel((x,y),(255,0,0,0) if tile in [0,100] else (255,old[1],old[2],255) if tile in range(5000,5009) else (0,old[1],old[2],255))
    mask.save(OUT/'alyut2400-mask.png',optimize=True)
    width = 102; heights = [0.] * (width*width); covered = [0] * len(heights)
    for y in range(th):
        for x in range(tw):
            rgba = mask.getpixel((x,y)); at = (y+1)*width+x+1
            if rgba[3] >= 128 and rgba[0] < 128: heights[at] = 6.; covered[at] = 1
    bits = bytearray(1250)
    for i in range(10000):
        if walk[i]: bits[i >> 3] |= 1 << (i & 7)
    banks = json.loads((FULL / 'banks.json').read_text())['rows']; assert len(banks) == 117 and all(opened(r['source_cell'][1]*tw+r['source_cell'][0]) for r in banks)
    native_banks = [{'serial': r['serial'], 'source_cell': r['source_cell'], 'anchor': r['anchor'], 'height': 6., 'water_height': 2., 'cached_cell_known': r['cached_cell_known']} for r in banks]
    data = {'schema': 1, 'source': 2400, 'size': [tw, th], 'source_origin': [-150,-150], 'source_bounds': [-151.5,-151.5,300,300],
            'source_mask_path':'res://'+str((OUT/'alyut2400-mask.png').relative_to(ROOT)), 'source_mask_rgba_sha256':sha(mask.tobytes()),
            'land_bank_height': 6., 'water_height': 2., 'world_scale': 1.3, 'native_width': width, 'native_origin': [-153,-153],
            'native_bounds_min': [-153,-153], 'native_bounds_max': [148.5,148.5], 'native_route_spacing': 3.,
            'native_heights': heights, 'native_covered': covered, 'cells': cells, 'walk_bits': base64.b64encode(bits).decode(),
            'floor_rectangles': floors, 'closed_rectangles': rectangles(tw,th,lambda i: not opened(i)), 'banks': native_banks,
            'connections': full['connections'], 'source_hybrid_sha256': sha(raw),
            'counts': {'source_cells': 10000, 'original_open': sum(walk), 'original_closed': 10000-sum(walk), 'open_banks': len(banks),
                       'source_open_dry': sum(c[5] and c[6]=='dry' for c in cells), 'water_controls': sum(c[5] and c[6]=='water_control' for c in cells), 'support_rectangles': len(floors)},
            'source_hashes': {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in [FULL/'map-data.json',FULL/'hybrid-map.bin',FULL/'mask.png',FULL/'banks.json',ROOT/'assets/maps/falan/east_region/bank_caps/data.json']},
            'inferred': ['Preserve the published6m land/bank and2m water datum; original native maps provide no3D heights.', 'Whole native-open source cells have invisible support; published source bank alpha/4m body owns visible land.', 'Original12 gate-buffer closures and all six native2400 water cells remain closed. No joined100flower is restored in this standalone map.']}
    assert all(not opened(y*tw+x) for xs,ys in [([58,59],range(28,31)),([66,67],range(61,64))] for x in xs for y in ys)
    (OUT / 'alyut2400-data.json').write_text(json.dumps(data, indent=2) + '\n')
    print('PRIVATE_SOURCE_CONTEXT field1489restored/8511known preserved, town', data['counts'])


if __name__ == '__main__': main()
