"""Stage only the exact northwest24cell source/atlas merge plan; write no map assets."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from build_falan_room_art import COLS,STRIDE,project_tile
from prepare_field_assets import navigation_grid
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Display Handoff Proposal'
def sha(data):return hashlib.sha256(data).hexdigest()
def run():
    branches=json.loads((OUT/'source-branch-final-ledger.json').read_text());branch=next(b for b in branches['branches']if b['id']=='branch-04')
    cells=branch['cells'];assert len(cells)==24
    base_path=ROOT/'assets/maps/falan/freyja_source/100.dat';reference_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    restore_path=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/field100-restore.json'
    restore=json.loads(restore_path.read_text());merged_path=ROOT/restore['raw_path'].removeprefix('res://')
    raw=base_path.read_bytes();reference=reference_path.read_bytes();merged=merged_path.read_bytes();assert sha(merged)==restore['raw_sha256']
    w,h,bg,pg,flags=lib.parse_map(raw);rw,rh,fg,fo,ff=lib.parse_map(reference);mw,mh,mg,mo,mf=lib.parse_map(merged)
    assert(w,h)==(rw,rh)==(mw,mh)and flags==ff==mf
    lookup=lib.serial_index();walk=navigation_grid(w,h,fg,fo,lookup)
    index_path=ROOT/'assets/maps/falan/freyja_ground_index.png';atlas_path=ROOT/'assets/maps/falan/freyja_ground_atlas.png'
    index=Image.open(index_path).convert('RGBA');atlas=Image.open(atlas_path).convert('RGB')
    private_index_path=restore_path.parent/'freyja_ground_index.png';private_atlas_path=restore_path.parent/'freyja_ground_atlas.png'
    private_index=Image.open(private_index_path).convert('RGBA');private_atlas=Image.open(private_atlas_path).convert('RGB')
    slots={}
    for i,serial in enumerate(bg):
        rgba=index.getpixel((i%w,i//w))
        if not rgba[3]or serial not in lookup or (lookup[serial]['w'],lookup[serial]['h'])!=(64,47):continue
        slot=rgba[0]+rgba[1]*COLS;assert serial not in slots or slots[serial]==slot;slots[serial]=slot
    graphics={}
    for serial in sorted({fg[y*w+x]for x,y in cells}):
        g=lookup[serial];image=lib.image_from_record(g['pack'],g['row']);tile=project_tile(image);slot=slots[serial]
        rect=(slot%COLS*STRIDE,slot//COLS*STRIDE,slot%COLS*STRIDE+STRIDE,slot//COLS*STRIDE+STRIDE)
        assert atlas.crop(rect).tobytes()==tile.tobytes()==private_atlas.crop(rect).tobytes()
        graphics[str(serial)]=dict(pack=g['pack'],row=g['row'],native_rgba_sha256=sha(image.tobytes()),projected_tile_rgb_sha256=sha(tile.tobytes()),
                                   preserved_slot=slot,preserved_array_layer=slot,rect=rect,requires_new_graphic_or_atlas_layer=False)
    rows=[]
    for x,y in sorted(cells):
        i=y*w+x;known=bool(flags[i]&0xc000);assert walk[i]
        assert not known or (bg[i],pg[i])==(fg[i],fo[i])==(mg[i],mo[i])
        slot=slots[fg[i]];water=5000<=fg[i]<=5008;desired=[slot%COLS,slot//COLS,255 if water else 0,255]
        rows.append(dict(cell=[x,y],flags=flags[i],recorded_client=known,canonical=[bg[i],pg[i]],current_merged=[mg[i],mo[i]],
                         pinned=[fg[i],fo[i]],source_decoder_open=True,source_surface_role='water-control'if fo[i]==252 else'water-background-native-shore'if water else'dry',raw_merge_needed=[mg[i],mo[i]]!=[fg[i],fo[i]],
                         canonical_index_rgba=list(index.getpixel((x,y))),current_merged_index_rgba=list(private_index.getpixel((x,y))),
                         desired_index_rgba=desired,native_atlas_layer=slot,index_merge_needed=list(private_index.getpixel((x,y)))!=desired))
    source_graphics=Counter(fo[y*w+x]for x,y in cells)
    outputs=dict(status='PRIVATE source/merge plan only; no raw, index, atlas, fields, Native, physics, scenery or shared source modified.',
                 branch='branch-04',cell_count=24,rows=rows,graphics=graphics,
                 counts=dict(recorded=sum(r['recorded_client']for r in rows),unrecorded=sum(not r['recorded_client']for r in rows),
                             merged_raw_tuple_additions=sum(r['raw_merge_needed']for r in rows),merged_index_additions=sum(r['index_merge_needed']for r in rows),
                             bg_graphics=len(graphics),pg1_graphics=dict(source_graphics),source_water_cells=sum(5000<=r['pinned'][0]<=5008 for r in rows),new_atlas_layers=0),
                 current_merged_sha256=sha(merged),current_canonical_sha256=sha(raw),pinned_reference_sha256=sha(reference),
                 current_private_atlas_rgb_sha256=sha(private_atlas.tobytes()),canonical_atlas_rgb_sha256=sha(atlas.tobytes()),
                 source_hashes={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in[base_path,reference_path,merged_path,restore_path,index_path,atlas_path,private_index_path,private_atlas_path]},
                 one_Host_merge_plan=['Hold current merged raw/field hashes during Native diagnosis. No preparer regeneration is requested by this plan.',
                                      'When released, add only listed unrecorded raw tuples to the existing source100 merger; known tuples, full header, marker plane and all outside tuples stay byte-identical.',
                                      'Reuse listed immutable atlas slots exactly. Change only listed index pixels; no tile repacking, atlas append or padding change.',
                                      'All24tuples are already recorded water/control or water/shore. Preserve the same merged raw SHA unless some separately authorized raw change is required; this plan does not request one.',
                                      'ONEHost owns visible source-water/native shore, physics/Native and any proven original support semantics. Decoder-open alone authorizes no generic dry ground or water bridge.',
                                      'Preserve neighboring original closed/water/void, opaqueCity and all existing Source100/Source2000/Source2400 contexts.',
                                      'Do not activate or claim walk support from24source-open bits; exact center/edge/radius/landing/normal/return proof remains required.'],
                 measured_endpoint_sources=[[437,39],[437,40],[437,41],[437,42]],inferred='Absolute vertical datum and hidden bank/mesh sides remain reconstructed, separately from pinned source tuples.')
    (OUT/'northwest24-source-merge-plan.json').write_text(json.dumps(outputs,indent=2)+'\n')
    assert all(sha((ROOT/p).read_bytes())==digest for p,digest in outputs['source_hashes'].items())
    print(json.dumps(outputs['counts'],indent=2));print('Current merged raw remains',sha(merged))
if __name__=='__main__':run()
