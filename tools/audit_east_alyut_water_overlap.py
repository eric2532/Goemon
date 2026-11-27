"""Read-only original100/2400 overlap ownership and portal-stopped walk graph."""
import collections
import hashlib
import json
import sys
from array import array
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
OUT=REPORT/'Village Props/Cliff Audit/Alyut Canonical Stage'


def labels(width,height,walk,stops):
    result=array('i',[-1])*len(walk);sizes=[]
    for i,opened in enumerate(walk):
        if not opened or result[i]>=0 or(i%width,i//width)in stops:continue
        component=len(sizes);result[i]=component;queue=collections.deque([i]);count=0
        while queue:
            at=queue.popleft();count+=1;x,y=at%width,at//width
            for nx,ny in[(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if not(0<=nx<width and 0<=ny<height)or(nx,ny)in stops:continue
                other=ny*width+nx
                if walk[other]and result[other]<0:result[other]=component;queue.append(other)
        sizes.append(count)
    return result,sizes


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    from build_freyja_destinations import load_map
    from prepare_field_assets import navigation_grid
    from prepare_east_region_maps import reference_map
    graph=json.loads((REPORT/'Version Expansion Source Audit/graph.json').read_text());links=graph['links']
    probe=json.loads((OUT/'water-join-probe.json').read_text());cells=[tuple(r['cell'])for r in probe['raw_terrain_native_clear']]
    static=[r for r in links if r.get('source')==100 and r['kind']=='fixed warp'];stops={tuple(r['cell'])for r in static}
    points={'source100_west_boundary_return':(550,19),'alyut_north_return_100':(587,50),'alyut_south_return_100':(595,83),'alyut_wet_bank_31_4_field_frame':(560,24),'alyut_wet_bank_33_5_field_frame':(562,25)}
    for r in links:
        if r.get('target')==100 and r.get('source')==1000 and r.get('landing'):points['falan_return_'+str(r.get('id',r.get('line')))]=tuple(r['landing'])
    rows=[];lookup=lib.serial_index();client=load_map(lib,100)
    manifest=json.loads((REPORT/'Version Expansion Source Audit/references.json').read_text());source=next(r for r in manifest if r['file']=='map__00100_field1');raw=(REPORT/'Version Expansion Source Audit'/source['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==source['sha256'];assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==source['git_blob']
    width,height,planes,_=reference_map(raw,100);count=width*height
    for name,values in [('recorded_client',client),('pinned_full_source',(width,height,list(planes[:count]),list(planes[count:]),[0xc000]*count))]:
        width,height,bg,pg,flags=values;walk=navigation_grid(width,height,bg,pg,lookup);components,sizes=labels(width,height,walk,stops)
        def state(p):
            x,y=p;i=y*width+x;label=components[i]
            return{'cell':[x,y],'bg':bg[i],'pg1':pg[i],'recorded':bool(flags[i]&0xc000),'native_open':bool(walk[i]),'static_warp_here':(x,y)in stops,'portal_stopped_component':label,'component_cells':sizes[label]if label>=0 else 0}
        controls={key:state(p)for key,p in points.items()};findings=[]
        for cell in cells:
            point=(cell[0]+529,cell[1]+20);row=state(point);row['village_cell']=list(cell);row['same_original100_component_as']=[key for key,value in controls.items()if value['portal_stopped_component']>=0 and value['portal_stopped_component']==row['portal_stopped_component']];findings.append(row)
        rows.append({'variant':name,'size':[width,height],'static_warp_stops':len(stops),'controls':controls,'six_overlaps':findings})
    result={'source2400_hybrid_sha256':probe['source_hybrid_sha256'],'source100_pinned':source,'variants':rows,'static100_to2400_gate_warps':[r for r in static if r['target']==2400],'nearby_scripted_source100_returns':[r for r in links if r.get('target')==100 and r.get('landing')and 545<=r['landing'][0]<=570 and 10<=r['landing'][1]<=35],'inference_limit':'Static-warp source cells stop the walking graph; scripts/conditions remain separately traced. This does not itself prove assembled Goemon reachability or authorize changing a shared source100 owner. No source, masks, terrain, collision or routes changed.'}
    (OUT/'water-overlap-source-ownership.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for variant in rows:print(variant['variant'],[(r['village_cell'],r['bg'],r['pg1'],r['native_open'],r['same_original100_component_as'])for r in variant['six_overlaps']])


if __name__=='__main__':main()
