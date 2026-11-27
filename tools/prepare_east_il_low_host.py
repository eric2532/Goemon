"""Private unknown-only source100 restoration inside the existing joined Il exclusion."""
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
import sys

from PIL import Image
from build_freyja_outlying import is_road, is_water
from prepare_east_region_maps import reference_map

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host'
BOUNDS = (636, 312, 90, 111)


def sha(payload):
    return hashlib.sha256(payload).hexdigest()


def prepare():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    active_path = ROOT/'assets/maps/falan/freyja_source/100.dat'
    active_provenance = active_path.with_name('provenance.json')
    original_path = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
    raw = active_path.read_bytes(); original = original_path.read_bytes()
    state = json.loads(active_provenance.read_text())
    assert sha(raw) == state['active_sha256'] and sha(original) == state['source']['sha256']
    width, height, before_bg, before_pg, flags = lib.parse_map(raw)
    rw, rh, native, _ = reference_map(original, 100)
    assert (width, height) == (rw, rh) == (840, 610)
    cells = width*height; after = bytearray(raw); preserved_differences = []; restored = []
    x0, z0, sx, sz = BOUNDS; enrolled = set()
    for z in range(z0, z0+sz):
        for x in range(x0, x0+sx):
            i = z*width+x; enrolled.add(i)
            current = (before_bg[i], before_pg[i]); target = (native[i], native[cells+i])
            # Preserve an entire nonzero tuple, including its recorded zeros.
            if flags[i] & 0xc000 or any(current):
                if current != target:
                    preserved_differences.append({'cell':[x,z], 'active':current, 'pinned':target, 'marker':flags[i]})
                continue
            if target == current:
                continue
            for plane in (0, 1):
                struct.pack_into('<H', after, 20+(plane*cells+i)*2, target[plane])
            restored.append([x,z])
    after = bytes(after); aw, ah, bg, pg, after_flags = lib.parse_map(after)
    assert (aw, ah) == (width, height) and after_flags == flags
    assert all((bg[i],pg[i]) == (before_bg[i],before_pg[i]) for i in range(cells) if i not in enrolled or flags[i]&0xc000 or before_bg[i] or before_pg[i])
    lookup = lib.serial_index(); old_walk = navigation_grid(width,height,before_bg,before_pg,lookup); walk = navigation_grid(width,height,bg,pg,lookup)
    native_walk = navigation_grid(width,height,native[:cells],native[cells:],lookup)
    baseline_path = ROOT/'assets/maps/falan/freyja_residual/full/east_gate-surface.png'
    baseline = Image.open(baseline_path).convert('RGBA'); mask = baseline.copy()
    assert mask.size == (387,459)
    rows = []; changed_mask = []; graphics = Counter(); new_open = []; lost_open = []
    for z in range(z0, z0+sz):
        for x in range(x0, x0+sx):
            i = z*width+x; px, pz = 422-z, x-349
            assert 0 <= px < mask.width and 0 <= pz < mask.height
            tile = bg[i]
            rgba = (255,0,0,0) if tile in (0,100) else (255 if is_water(tile) else 0,224 if is_road(tile) else 0,220 if 1000<=tile<=1099 or 5954<=tile<=5988 else 0,255)
            if baseline.getpixel((px,pz)) != rgba:
                changed_mask.append({'cell':[x,z], 'pixel':[px,pz], 'before':list(baseline.getpixel((px,pz))), 'after':rgba})
                mask.putpixel((px,pz),rgba)
            if walk[i] and not old_walk[i]:new_open.append([x,z])
            if old_walk[i] and not walk[i]:lost_open.append([x,z])
            if pg[i] >= 1000:graphics[pg[i]] += 1
            rows.append({'cell':[x,z], 'mask_pixel':[px,pz], 'before':[before_bg[i],before_pg[i]], 'after':[bg[i],pg[i]], 'marker':flags[i],
                         'native_open_before':bool(old_walk[i]), 'native_open_after':bool(walk[i]), 'pinned_native_open':bool(native_walk[i]),
                         'source_was_recorded':bool(flags[i]&0xc000), 'source_had_nonzero_tuple':bool(before_bg[i] or before_pg[i])})
    pixels = {(422-z,x-349) for z in range(z0,z0+sz) for x in range(x0,x0+sx)}
    assert len(pixels) == sx*sz == 9990
    assert all(mask.getpixel((x,z)) == baseline.getpixel((x,z)) for z in range(mask.height) for x in range(mask.width) if (x,z) not in pixels)
    assert not lost_open, 'Unknown-only recovery must not delete an existing native-open cell'
    topology = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/100-il-trigger-topology.json'
    contracts = {'schema':1, 'source':100, 'scope':'PRIVATE unknown-only fill inside the existing9990cell joined Il exclusion. No shared input, owner, mask or source publication.',
                 'source_bounds':BOUNDS, 'host_mask_bounds':[0,287,111,90], 'source_size':[width,height], 'host_mask_origin':[-675,-204],
                 'active_source_stage':{key:state.get(key) for key in ['stage','preview_bounds','active_sha256']},
                 'counts':{'enrolled_cells':len(rows), 'restored_tuples':len(restored), 'before_open':sum(r['native_open_before'] for r in rows),
                           'after_open':sum(r['native_open_after'] for r in rows), 'additional_native_open':len(new_open), 'lost_native_open':len(lost_open),
                           'preserved_variant_tuples':len(preserved_differences), 'mask_changes':len(changed_mask), 'pg1_anchors':sum(graphics.values())},
                 'preserved_variants':preserved_differences, 'restored_cells':restored, 'additional_native_open':new_open, 'mask_changes':changed_mask,
                 'source_rows':rows, 'graphics':dict(sorted(graphics.items())),
                 'source_hashes':{str(path.relative_to(ROOT)):sha(path.read_bytes()) for path in [active_path,active_provenance,original_path,baseline_path,Path(__file__),topology]},
                 'prepared_sha256':sha(after), 'prepared_mask_rgba_sha256':sha(mask.tobytes()),
                 'preservation':['All markers/header bytes unchanged. Every recorded OR nonzero tuple is preserved in full.',
                                 'All512400source tuples outside the enrolled window and allRGBAoutside its exactmask pixels remain unchanged.',
                                 'Pinned original topology proves that most enrolled land is outside-connected without the Il instant trigger; it is not decorative.'],
                 'pending':['Source100 native height/support and all source-open adjacency remain unverified; mask paint alone is not physical support.',
                            'Restore original100 PG1 through compatible existing owners without the joined2000 overlay; preserve gate source cells and original transfer radius.',
                            'Actual entry681,343 to2000(44,31), return2000(45,31) to100(682,343), player/nativepet/source-current camera checks.']}
    return after, mask, contracts


def main():
    raw, mask, contracts = prepare(); OUT.mkdir(parents=True,exist_ok=True); (OUT/'.gdignore').touch()
    (OUT/'100.dat').write_bytes(raw); mask.save(OUT/'east-gate-mask.png')
    (OUT/'source-contract.json').write_text(json.dumps(contracts,indent=2)+'\n')
    print('Private source100 Il host recovery:',contracts['counts'])


if __name__ == '__main__': main()
