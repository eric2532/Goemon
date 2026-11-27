"""Exact source100 land ownership beneath six source2400 water cells."""
import hashlib
import json
import sys
import base64
import struct
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
OUT=REPORT/'Village Props/Cliff Audit/Alyut Canonical Stage'
CELLS=[(32,3),(33,3),(34,3),(35,3),(33,4),(34,4)]


def prepare(out=OUT):
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    from build_freyja_destinations import load_map
    from prepare_field_assets import navigation_grid
    from prepare_east_region_maps import reference_map
    data=json.loads((out/'map-data.json').read_text());source_rows=json.loads((REPORT/'Version Expansion Source Audit/references.json').read_text());record=next(r for r in source_rows if r['file']=='map__00100_field1')
    town_count=data['size'][0]*data['size'][1];town_bg=struct.unpack(f'<{town_count}H',zlib.decompress(base64.b64decode(data['ground_u16le_deflate'])));town_pg=struct.unpack(f'<{town_count}H',zlib.decompress(base64.b64decode(data['objects_u16le_deflate'])));town_walk=zlib.decompress(base64.b64decode(data['walk_bits']))
    raw=(REPORT/'Version Expansion Source Audit'/record['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==record['sha256'];assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==record['git_blob']
    width,height,planes,_=reference_map(raw,100);count=width*height;bg,pg=planes[:count],planes[count:]
    client=load_map(lib,100);assert client[:2]==(width,height);lookup=lib.serial_index();walk=navigation_grid(width,height,bg,pg,lookup)
    with lib.connection()as db:client_record=dict(db.execute('SELECT * FROM files WHERE path=?',('BlueCrossgate/map/0/100.dat',)).fetchone())
    client_raw=(lib.SOURCE/client_record['path']).read_bytes();rows=[]
    for x,y in CELLS:
        town_index=y*data['size'][0]+x
        assert town_bg[town_index]in range(5000,5009)and town_pg[town_index]==0 and not(town_walk[town_index>>3]&(1<<(town_index&7)))
        fx,fy=x+529,y+20;i=fy*width+fx
        assert client[4][i]&0xc000 and(client[2][i],client[3][i])==(bg[i],pg[i]),'Both original100variants must agree before retaining its owner'
        expected_open=(x,y)!=(35,3);assert bool(walk[i])==expected_open
        assert pg[i]==(12172 if not expected_open else 0)
        rows.append({'village_cell':[x,y],'village_bg':town_bg[town_index],'village_pg1':0,'village_native_open':False,'field_cell':[fx,fy],'source_map':100,'field_bg':bg[i],'field_pg1':pg[i],'field_native_open':bool(walk[i]),'recorded_in_client':True,'both100variants_agree':True,'restore_graphic':not expected_open,'source_footprint':[1,1],'joined_land_height':6.0})
    assert lookup[12172]['east']==lookup[12172]['south']==1
    result={'schema':1,'source_hybrid_sha256':data['source']['sha256'],'map_data_sha256':hashlib.sha256((out/'map-data.json').read_bytes()).hexdigest(),'field_source':{'client_path':client_record['path'],'client_sha256':hashlib.sha256(client_raw).hexdigest(),'pinned':record},'existing_join_source_offset':[529,20],'source100_overlap_cells':rows,'source100_open_land_cells':5,'source100_blocked_flower_cells':1,'source2400_raw_layers_unchanged':True,'separate_from_gate_handoffs':True,'source_component_proof':'Alyut Canonical Stage/water-overlap-source-ownership.json: both100variants share the original portal-stopped component with100(550,19), Alyut north/south returns and neighboringfieldroad cells. Scripted returns from16504/16505remain separate-region connections; they are not rebuilt here.','inferred':'The existing seamless join retains these exact source100land/flower cells where the distinct2400map has closed water. Their logical source remains100, and they are excluded from2400water visibility cuts. Only the original12172flower/1×1nativeclosure is restored; rawmaps,12gatebuffers,otherland/routes/NPCs/quests are unchanged.'}
    (out/'source-overlaps.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('EAST_ALYUT_SOURCE_OVERLAPS',len(rows),'source100cells;5openland+1originalflowerclosure')


if __name__=='__main__':prepare()
