"""Record current/proposed source100 crossing stencils without changing products."""
from array import array
import base64
import hashlib
import json
from math import cos, sin
from pathlib import Path
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def f32(value):return struct.unpack('<f',struct.pack('<f',value))[0]
def wave(x,z):
    # Source100 cell centres:0,0 is the original map origin;1cell is3model metres.
    sx,sz=x*3.,z*3.
    return f32(6.+1.6*sin(sx*.014+sz*.008)+1.1*cos(sz*.018-sx*.008))
def source_half_height(hx,hz):
    x,z=hx//2,hz//2
    if not hx%2 and not hz%2:return wave(x,z)
    if not hz%2:return f32((wave(x,z)+wave(x+1,z))*.5)
    if not hx%2:return f32((wave(x,z)+wave(x,z+1))*.5)
    return f32((wave(x+1,z)+wave(x,z+1))*.5)
def inside_rect(x,z,r):return r[0]-.5<=x<=r[0]+r[2]-.5 and r[1]-.5<=z<=r[1]+r[3]-.5


def main():
    paths=[OUT/(a+'-field.json')for a in ['east_gate','north_coast']]+[OUT/'manifest.json',ROOT/'scripts/forest/forest_freyja_regions.gd',Path(__file__)]
    before={str(p.relative_to(ROOT)):sha(p)for p in paths}
    fields={}
    for area in ['east_gate','north_coast']:
        data=json.loads((OUT/(area+'-field.json')).read_text())
        values=array('f',zlib.decompress(base64.b64decode(data['heights']['deflate'])))
        fields[area]=(data,values)
    cases=[]
    for center in [(686,193),(686,196)]:
        rows=[]
        for dz in [-1,0,1]:
            for dx in [-1,0,1]:
                hx,hz=center[0]*2+dx,center[1]*2+dz;x,z=hx*.5,hz*.5
                proposed=source_half_height(hx,hz);views={}
                for area,(data,values)in fields.items():
                    fx,fz=(hx-948,hz+98)if area=='north_coast'else(844-hz,hx-698)
                    current=values[fz*data['width']+fx]
                    assert not any(inside_rect(x,z,r)for r in data['water_rectangles'])
                    assert not any(inside_rect(x,z,r['rect'])for r in data.get('source_dry_floor_rectangles',[]))
                    views[area]={'before_model_m':current,'proposed_model_m':proposed,'delta_model_m':proposed-current,'before_world_vertex_f32_m':f32(current*1.3),'proposed_world_vertex_f32_m':f32(proposed*1.3),'winning_support':'heightfield; no explicit water/dry floor piece intersects this sample'}
                rows.append({'source_half_grid':[hx,hz],'source_cell_float':[x,z],'views':views})
        assert all(r['views']['north_coast']['delta_model_m']==0 for r in rows)
        assert all(r['views']['east_gate']['delta_model_m']==0 for r in rows if r['source_half_grid'][0]%2==0 or r['source_half_grid'][1]%2==0)
        cases.append({'center':list(center),'stencil':rows})
    changed=[k for k,v in before.items()if sha(ROOT/k)!=v]
    assert not changed
    report={'status':'private offline proposal; field products unchanged','raw_sha256':fields['east_gate'][0]['raw_sha256'],'coordinate_contract':{'origin':'Original map100cell centre(0,0), not an East/North local origin','cell_model_metres':3.,'half_grid_model_metres':1.5,'falan_world_scale':1.3,'wave_evaluation':'Evaluate source integer cell vertices in model metres and round to float32 once; refine canonical source h10-h01 triangles. The half-grid is not a second analytic wave evaluation.'},'cases':cases,'north_stencil_nodes_exact':18,'east_changed_odd_odd_nodes':sum(r['views']['east_gate']['delta_model_m']!=0 for c in cases for r in c['stencil']),'maximum_east_delta_model_m':max(abs(r['views']['east_gate']['delta_model_m'])for c in cases for r in c['stencil']),'source_hashes':before,'source_changed':changed,'scope':'Source vertex/role proposal only, not a Native sampler, player/pet or route proof. Root accepted the explicitly listed East odd/odd refinement correction; centers/cardinals and all North nodes stay exact. Production float query agreement remains an independent required test.'}
    (OUT/'source-height-anchor-ledger.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k]for k in ['north_stencil_nodes_exact','east_changed_odd_odd_nodes','maximum_east_delta_model_m','source_changed']}))


if __name__=='__main__':main()
