"""Exact newly recovered Alyut shore lips and source-proved dry approaches."""
import base64
import collections
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate'
BANKS=ROOT/'assets/maps/falan/east_region/bank_caps/data.json'
DIRECTIONS={'west':(-1,0),'east':(1,0),'north':(0,-1),'south':(0,1)}


def prepare(folder=FOLDER):
    source=json.loads((folder/'map-data.json').read_text());caps=json.loads(BANKS.read_text());width,height=source['size'];count=width*height
    ground=struct.unpack(f'<{count}H',zlib.decompress(base64.b64decode(source['ground_u16le_deflate'])));bits=zlib.decompress(base64.b64decode(source['walk_bits']))
    def dry(x,y):
        return 0<=x<width and 0<=y<height and bool(bits[(y*width+x)>>3]&(1<<((y*width+x)&7))) and ground[y*width+x]not in [0,100,*range(5000,5009)]
    rows=[]
    for placement in source['placements']:
        if not 12500<=placement['graphic']<=12535:continue
        serial=placement['graphic'];x,y=placement['cell'];spec=caps['graphics'][str(serial)];approaches=[];joins=[];neighbors=[]
        index=y*width+x
        assert ground[index]in range(5000,5009)and bits[index>>3]&(1<<(index&7)),'Only native-open shore cells may receive inferred anchor support'
        for name,(dx,dy)in DIRECTIONS.items():
            if not dry(x+dx,y+dy):continue
            neighbor={'direction':name,'cell':[x+dx,y+dy],'bg':ground[(y+dy)*width+x+dx],'native_open':True,'terrain_class':'dry_land','height':6.}
            neighbors.append(neighbor)
            if name not in spec['approaches']:continue
            approaches.append({**spec['approaches'][name],'direction':name,'source_neighbor':neighbor})
            joins.append(spec['approaches'][name]['join_rect'])
        rows.append({'serial':serial,'source_cell':[x,y],'anchor':[(x-width*.5)*3,(y-height*.5)*3],
                     'height':6.,'water_height':2.,'join_rects':joins,'source_dry_neighbors':neighbors,'verified_approach_candidates':approaches,
                     'cached_cell_known':placement['cached_cell_known'],'native_open':True,'source_bg':ground[index],
                     'support_only_rects':[[-1.5,-1.5,1.5,1.5]],
                     'source_anchor_inside_alpha_strips':any(a<=0<=c and b<=0<=d for a,b,c,d in spec['support_rects']),
                     'support_only_inference':'Invisible support under this exact native-open3m shore tile retains original source anchors and cap-chain routes. It does not draw grass, alter water, or open any original blocked tile.',
                     'deepest_stand':spec['deepest_stand'],'outline_clearance_local':spec['outline_clearance_local'],
                     'native_source_rgba_sha256':spec['source_rgba_sha256'],
                     'scope':'Exact source lip; source-native open-cell support is separate hidden reconstruction. The source walk bit already opens this cell; no new route is introduced.'})
    assert len(rows)==117 and sum(not r['cached_cell_known']for r in rows)==99
    result={'schema':1,'source_map':2400,'source_hybrid_sha256':source['source']['sha256'],'map_data_sha256':hashlib.sha256((folder/'map-data.json').read_bytes()).hexdigest(),
            'bank_data_sha256':hashlib.sha256(BANKS.read_bytes()).hexdigest(),'rows':rows,'counts':{'placements':len(rows),'newly_recovered':99,'previously_cached':18,'anchors_outside_drawn_alpha':sum(not r['source_anchor_inside_alpha_strips']for r in rows),'with_dry_approach':sum(bool(r['verified_approach_candidates'])for r in rows),
            'without_dry_approach':sum(not r['verified_approach_candidates']for r in rows),'joins':sum(len(r['join_rects'])for r in rows)},
            'height_frame':{'local_cap_top':6.,'local_water':2.,'joined_north_translation':[-165,-123],'source_cell_to_local':'(cell-[50,50])*3'},
            'inferred':'Closed unseen4m shore depth and small alpha-edge continuation reuse the shared source-bank helper. No source water/void mask or global terrain class changes.',
            'unfinished':'Candidate only. Actual native-player support, cap-to-cap continuity and original route/door/NPC review must precede publication. No inferred approaches across water.'}
    (folder/'banks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('EAST_ALYUT_BANK_ROWS',result['counts'])


def main():prepare()


if __name__=='__main__':main()
