"""Preserve original2400↔100 gate transfers inside the existing seamless join."""
import base64
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

from build_freyja_destinations import load_map
from recover_sokia import rectangles

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate'


def prepare(out=OUT):
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    from prepare_field_assets import navigation_grid
    data=json.loads((out/'map-data.json').read_text());width,height=data['size'];count=width*height
    ground=struct.unpack(f'<{count}H',zlib.decompress(base64.b64decode(data['ground_u16le_deflate'])))
    objects=struct.unpack(f'<{count}H',zlib.decompress(base64.b64decode(data['objects_u16le_deflate'])))
    bits=zlib.decompress(base64.b64decode(data['walk_bits']))
    def opened(x,y):return bool(bits[(y*width+x)>>3]&(1<<((y*width+x)&7)))
    fw,fh,fg,fp,flags=load_map(lib,100);field_walk=navigation_grid(fw,fh,fg,fp,lib.serial_index())
    with lib.connection()as db:record=dict(db.execute('SELECT * FROM files WHERE path=?',('BlueCrossgate/map/0/100.dat',)).fetchone())
    field_raw=(lib.SOURCE/record['path']).read_bytes();offset=(529,20);removed={};warps=[]
    for link in data['connections']:
        if link['source']!=2400 or link['target']!=100:continue
        x,y=link['cell'];tx,ty=link['landing'];dx,dy=tx-x-offset[0],ty-y-offset[1]
        assert (dx,dy)==(0,-1),'Inspect any changed source transfer direction before adapting its join'
        assert opened(x,y),'Original gate must remain natively open'
        cells=[]
        for distance in range(1,9):
            sx,sy=x+dx*distance,y+dy*distance
            if opened(sx,sy):break
            i=sy*width+sx;fx,fy=sx+offset[0],sy+offset[1];fi=fy*fw+fx
            assert objects[i]==17644 and ground[i]not in [0,100,*range(5000,5009)],'Only original invisible post-warp buffer cells belong to this handoff'
            assert flags[fi]&0xc000 and field_walk[fi],'Original field road must be recorded and open at every joined buffer cell'
            row={'village_cell':[sx,sy],'village_bg':ground[i],'village_pg1':objects[i],'village_native_open':False,
                 'field_cell':[fx,fy],'field_bg':fg[fi],'field_pg1':fp[fi],'field_native_open':True,'field_recorded':True,'source_warp_ids':[]}
            key=(sx,sy)
            if key not in removed:removed[key]=row
            removed[key]['source_warp_ids'].append(link['id']);cells.append([sx,sy])
        else:raise AssertionError('Original source gate requires a bounded field-road handoff')
        warps.append({'source_warp':link,'direction':[dx,dy],'handoff_cells':cells,'first_village_open_after_buffer':[sx,sy]})
    assert set(removed)=={(x,y)for xs,ys in [([58,59],range(28,31)),([66,67],range(61,64))]for x in xs for y in ys}
    original={(x,y)for a,b,w,h in data['blocked_land_rectangles']for x in range(a,a+w)for y in range(b,b+h)}
    assert set(removed)<=original
    merged=rectangles(original-set(removed))
    result={'schema':1,'source_hybrid_sha256':data['source']['sha256'],'map_data_sha256':hashlib.sha256((out/'map-data.json').read_bytes()).hexdigest(),
            'field_source':{'path':record['path'],'sha256':hashlib.sha256(field_raw).hexdigest()},'existing_join_source_offset':list(offset),
            'source_warps':warps,'handoff_cells':list(removed.values()),'original_blocked_land_cells':len(original),
            'joined_blocked_land_cells':len(original)-len(removed),'blocked_land_rectangles':merged,
            'preserved':'All native2400 raw layers, source walk bits, gate art/positions, building colliders/doors and all other blocked cells are unchanged.',
            'inferred':'The existing seamless village join realizes the original2400→100 transfers by handing these12 invisible post-warp buffer cells to the same-position recorded/open source100 road. No original blocked road is newly opened; no new route or room is invented.'}
    (out/'gate-handoffs.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('EAST_ALYUT_GATE_HANDOFFS',len(removed),'exact source100 road cells;',len(original),'→',result['joined_blocked_land_cells'],'joined blocked land')


def main():prepare()


if __name__=='__main__':main()
