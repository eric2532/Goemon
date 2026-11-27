"""Read-only proof of source-exact private player boundary products."""
import base64
import json
from pathlib import Path
import struct
from prepare_east_host100_fields import OUT, ROOT, digest, within_mask
from run_east_host100_field_proof import decoded


def main():
    path=OUT/'player-boundaries.json';report=json.loads(path.read_text());raw_path=ROOT/report['boundary_metadata_raw_path'].removeprefix('res://');raw=raw_path.read_bytes()
    assert digest(raw_path)==report['boundary_metadata_raw_sha256']
    bits=base64.b64decode(report['native_walk_bits']);w,h=840,610;n=w*h;checks=0;areas={};failed=[]
    paths=[Path(__file__),path,raw_path,OUT/'manifest.json',ROOT/'scripts/forest/forest_east_host_source_context.gd',ROOT/'scripts/forest/forest_original_water_camera.gd',ROOT/'scripts/forest/forest_freyja_art.gd']
    paths += [OUT/(area+'-field.json')for area in report['areas']]
    before={str(p.relative_to(ROOT)):digest(p)for p in paths}
    def check(yes,label):
        nonlocal checks
        checks+=1
        if not yes:failed.append(label)
    def opened(x,z):
        i=z*w+x;return 0<=x<w and 0<=z<h and bool(bits[i>>3]&(1<<(i&7)))
    for area,spec in report['areas'].items():
        data=json.loads((OUT/(area+'-field.json')).read_text());scope=decoded(data,'scope_bits','byte');protected=set(data['protected_bridge_cells']);edges=set();plain_water=0
        check(digest(OUT/(area+'-field.json'))==spec['field_sha256'],area+' boundary/field snapshot matches')
        def owned(x,z):
            i=z*w+x;return 0<=x<w and 0<=z<h and i not in protected and within_mask(area,x,z,data) and bool(scope[i>>3]&(1<<(i&7)))
        for along,row,start,end in spec['runs']:
            check(0<=start<end<=(w if along else h),area+' finite original source run')
            water=True
            for column in range(start,end):
                a=(column,row-1)if along else(row-1,column);b=(column,row)if along else(row,column);key=(along,row,column)
                check(key not in edges,area+' source edge appears once');edges.add(key)
                check(opened(*a)!=opened(*b),area+' every physical wall is an original open/closed boundary')
                check(owned(*a)or owned(*b),area+' physical edge has an enrolled adjacent cell')
                check(not any(0<=x<w and 0<=z<h and z*w+x in protected for x,z in [a,b]),area+' whole bridge remains a separate physical owner')
                blocked=b if opened(*a)else a;x,z=blocked
                if not(0<=x<w and 0<=z<h):water=False;continue
                i=z*w+x;bg=struct.unpack_from('<H',raw,20+i*2)[0];pg=struct.unpack_from('<H',raw,20+(n+i)*2)[0]
                water=water and 5000<=bg<=5008 and pg==0
            plain_water+=int(water)
        expected=set()
        for z in range(h):
            for x in range(w):
                if not owned(x,z):continue
                for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                    nx,nz=x+dx,z+dz
                    if opened(x,z)==opened(nx,nz)or 0<=nx<w and 0<=nz<h and nz*w+nx in protected:continue
                    expected.add((0,max(x,nx),z)if dx else(1,max(z,nz),x))
        check(edges==expected,area+' all and only scoped source boundary edges are present')
        for x in [495,497]:
            if area!='east_gate':continue
            check(opened(x,359)and opened(x,360),'Pinned original dry road stays open across the preparer y360guard')
            check((1,360,x)not in edges,'No invented wall at the y360preparation guard')
        areas[area]={'runs':len(spec['runs']),'source_edges':len(edges),'plain_water_camera_only_runs':plain_water,'protected_bridge_cells':len(protected)}
    changed=[p for p,sha in before.items()if digest(ROOT/p)!=sha];check(not changed,'Source stayed current')
    result={'checks':checks,'failures':len(failed),'failed':failed,'areas':areas,'source_hashes':before,'source_changed':changed,
            'scope':'PRIVATE exact source-edge/complete-metadata boundary product only. Whole bridge is excluded. No game scene/body installation, player/pet or camera/cost acceptance.',
            'limits':['Unknown outside neighbors borrow complete-source metadata only for edge classification and camera water tagging; this does not restore their actual terrain/support.',
                      'Collider height remains inferred local-10..30; actual body/camera behavior and setup cost remain unverified.']}
    (OUT/'boundary-contract.json').write_text(json.dumps(result,indent=2)+'\n');print('HOST100_BOUNDARIES',checks,'checks',len(failed),'failures',areas);assert not failed


if __name__=='__main__':main()
