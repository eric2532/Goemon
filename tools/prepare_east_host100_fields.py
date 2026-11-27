"""Private composite100 CPU fields; preserve canonical inputs and all raw map bytes."""
from array import array
import base64
from collections import defaultdict, deque
import hashlib
import io
import json
from math import cos, floor, hypot, inf, sin, sqrt
from pathlib import Path
import struct
import sys
import zlib

from PIL import Image
from prepare_east_il_low_source import rectangles

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
BASE=REPORT/'Il Source Completion/Low Source Candidate/Host/Reference'
RESTORE=REPORT/'Village Props/Cliff Audit/Source Context Audit/Prototype'
OUT=REPORT/'Il Source Completion/Low Source Candidate/Host/Original100 Candidate'
SW,SH=840,610


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3.-2.*t)
def rect_distance(x,z,left,top,width,height):return hypot(x-max(left,min(left+width,x)),z-max(top,min(top+height,z)))
def datum(area,x,z):
    sx,sz=x*3.,z*3.;world=6.+sin(sx*.014+sz*.008)*1.6+cos(sz*.018-sx*.008)*1.1
    if area=='north_coast':return 6.+(world-6.)*smooth(0.,18.,rect_distance((x-579)*3.,(z-70)*3.,-150.,-150.,300.,300.))
    lx,lz=591.-sz,sx-1251.;bank=6.
    if lz>244.:bank+=(3.*sin(lx*.023+lz*.016)+2.*cos(lz*.027-lx*.011))*smooth(244.,326.,lz)
    bank+=(6.-bank)*smooth(105.,140.,-lx);bank+=(world-bank)*smooth(370.,405.,lz)
    return 6.+(bank-6.)*smooth(0.,18.,rect_distance((x-681)*3.,(z-372)*3.,-135.,-180.,270.,360.))
def goal(x,z):return x>=440 and (z<360 or 636<=x<726 and 312<=z<423 or 529<=x<629 and 20<=z<120)
def source_point(area,x,z):return (x*3.-1902.,z*3.-333.) if area=='north_coast' else (591.-z*3.,x*3.-1251.)
def source_half(area,fx,fz):return (948+fx,-98+fz) if area=='north_coast' else (698+fz,844-fx)
def cells_at(half):return (half//2,) if half%2==0 else (half//2,half//2+1)
def blob(values,kind):
    raw=array('f',values).tobytes() if kind=='float' else bytes(values)
    return {'raw_bytes':len(raw),'deflate':base64.b64encode(zlib.compress(raw,9)).decode()}
def refine(values,width):
    fine=width*2-1;out=array('f',[0.])*(fine*fine)
    for z in range(width):
        for x in range(width):
            i=z*width+x;j=z*2*fine+x*2;out[j]=values[i]
            if x+1<width:out[j+1]=(values[i]+values[i+1])*.5
            if z+1<width:out[j+fine]=(values[i]+values[i+width])*.5
            if x+1<width and z+1<width:out[j+fine+1]=(values[i+1]+values[i+width])*.5
    return out
def refine_support(covered,width):
    fine=width*2-1;out=bytearray(fine*fine);valid=bytearray((width-1)*(width-1))
    for z in range(width-1):
        for x in range(width-1):
            i=z*width+x
            if not(covered[i] and covered[i+1] and covered[i+width] and covered[i+width+1]):continue
            valid[z*(width-1)+x]=1
            for dz in range(3):
                j=(z*2+dz)*fine+x*2;out[j:j+3]=b'\1\1\1'
    return out,valid


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    restore_path=RESTORE/'field100-restore.json';restore=json.loads(restore_path.read_text());raw_path=ROOT/restore['raw_path'].removeprefix('res://')
    source_paths=[raw_path,restore_path,BASE/'review.json',Path(__file__)]
    source_paths += [BASE/(area+suffix) for area in ['east_gate','north_coast'] for suffix in ['-field.json','-mask.png']]
    before={str(path.relative_to(ROOT)):digest(path) for path in source_paths}
    assert digest(raw_path)==restore['raw_sha256'];w,h,bg,pg,flags=lib.parse_map(raw_path.read_bytes());assert(w,h)==(SW,SH)
    walk=navigation_grid(w,h,bg,pg,lib.serial_index());bits=base64.b64decode(restore['native_walk_bits'])
    assert all(bool(bits[i>>3]&(1<<(i&7)))==bool(walk[i]) for i in range(w*h))
    old_path=ROOT/'assets/maps/falan/freyja_source/100.dat';_,_,og,op,_=lib.parse_map(old_path.read_bytes());old_walk=navigation_grid(w,h,og,op,lib.serial_index())
    wet={i for i in range(w*h) if walk[i] and (pg[i]==252 or 12500<=pg[i]<12536)}
    pending=[i for i in wet if 636<=i%w<726 and 312<=i//w<423];component=set(pending)
    for i in pending:
        x,z=i%w,i//w
        for nx,nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
            j=nz*w+nx
            if 0<=nx<w and 0<=nz<h and j in wet and j not in component:component.add(j);pending.append(j)
    assert len(component)==2989
    dry=lambda i:bg[i] not in(0,100) and not 5000<=bg[i]<=5008
    primary_dry=set();dry_steps={};pending_dry=deque()
    for i in component:
        x,z=i%w,i//w
        for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
            xx,zz=x+dx,z+dz;j=zz*w+xx
            if 0<=xx<w and 0<=zz<h and dry(j) and j not in primary_dry:primary_dry.add(j);dry_steps[j]=1;pending_dry.append(j)
    while pending_dry:
        i=pending_dry.popleft();x,z=i%w,i//w
        for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
            xx,zz=x+dx,z+dz;j=zz*w+xx
            if 0<=xx<w and 0<=zz<h and dry(j) and j not in primary_dry:primary_dry.add(j);dry_steps[j]=dry_steps[i]+1;pending_dry.append(j)
    repairs_path=OUT/'dry-seam-repairs.json';repairs=json.loads(repairs_path.read_text()) if repairs_path.exists() else {'dry_cells':[]}
    assert not repairs_path.exists() or repairs['raw_sha256']==restore['raw_sha256']
    if repairs_path.exists():before[str(repairs_path.relative_to(ROOT))]=digest(repairs_path)
    for x,z in repairs['dry_cells']:
        i=z*w+x;assert walk[i] and bg[i] not in(0,100) and not 5000<=bg[i]<=5008 and goal(x,z)
    half_w=w*2+1;distance=array('f',[inf])*((h*2+1)*half_w)
    kernel=[(dx,dz,(dx*dx+dz*dz)*2.25) for dz in range(-26,27) for dx in range(-26,27) if dx*dx+dz*dz<=26*26]
    for i in component:
        hx,hz=(i%w)*2,(i//w)*2
        for dx,dz,d2 in kernel:
            xx,zz=hx+dx,hz+dz
            if 0<=xx<half_w and 0<=zz<h*2+1:
                j=zz*half_w+xx
                if d2<distance[j]:distance[j]=d2
    scope=bytearray(w*h);changed=[]
    for i in range(w*h):
        x,z=i%w,i//w
        if (bg[i],pg[i])!=(og[i],op[i]):scope[i]=1;changed.append(i)
        if walk[i]!=old_walk[i] and goal(x,z):scope[i]=1
        if 636<=x<726 and 312<=z<423 or 529<=x<629 and 20<=z<120:scope[i]=1
        if i in component:scope[i]=1
        if bg[i] not in (0,100) and not 5000<=bg[i]<=5008 and distance[z*2*half_w+x*2]<38.*38.:scope[i]=1
    assert len(changed)==50745
    references={};summary={'raw_sha256':restore['raw_sha256'],'changed_raw_union':len(changed),'component_cells':len(component),'component_bank_cells':sum(12500<=pg[i]<12536 for i in component),'component_water_controls':sum(pg[i]==252 for i in component),'areas':{},'source_hashes':{}}
    for area in ['east_gate','north_coast']:
        path=BASE/(area+'-field.json');ref=json.loads(path.read_text())
        for key in ['covered','bridges']:
            if isinstance(ref[key],str):ref[key]=json.loads(ref[key])
        assert len(ref['heights'])==int(ref['width'])**2 and all(v in (0,1) for v in ref['covered'])
        references[area]=ref
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch();prepared_files={}
    # Only data derivatives are written. Canonical Resources/byte arrays stay immutable.
    for area,ref in references.items():
        width=int(ref['width']);fine=width*2-1;heights=refine(ref['heights'],width);bed=refine(ref['bed'],width);base_cov,base_valid=refine_support(ref['covered'],width)
        baseline_h=heights[:];baseline_b=bed[:]
        coverage=bytearray(base_cov);bridges=bytearray(fine*fine);mask=Image.open(BASE/(area+'-mask.png')).convert('RGBA');mask_before=mask.copy()
        visual_dry_fixes=[];height_vertices=0;modified=set();local_scope=bytearray(scope);protected=set()
        for x,z in repairs['dry_cells']:local_scope[z*w+x]=1
        for z in range(mask.height):
            for x in range(mask.width):
                if not ref['bridges'][z*width+x]:continue
                hx,hz=source_half(area,x*2,z*2);sx,sz=hx//2,hz//2
                if 0<=sx<w and 0<=sz<h:protected.add(sz*w+sx);local_scope[sz*w+sx]=0
        for z in range(mask.height):
            for x in range(mask.width):
                hx,hz=source_half(area,x*2,z*2);sx,sz=hx//2,hz//2
                if not(0<=sx<w and 0<=sz<h):continue
                i=sz*w+sx
                if i in protected or not goal(sx,sz) and i not in component:continue
                tile=bg[i]
                if tile not in(0,100) and not 5000<=tile<=5008 and ref['bed'][z*width+x]<datum(area,sx,sz)-.25:
                    local_scope[i]=1;visual_dry_fixes.append([sx,sz,tile,pg[i],ref['bed'][z*width+x],datum(area,sx,sz),int(walk[i])])
        closure_rows=[]
        def point_data(fx,fz):
            hx,hz=source_half(area,fx,fz);touch=[]
            for sz in cells_at(hz):
                for sx in cells_at(hx):
                    if 0<=sx<w and 0<=sz<h:touch.append(sz*w+sx)
            return hx,hz,touch
        def grade_distance2(hx,hz,touch):
            # This is a Native-safe3D height inference, not a claim about
            # original executable diagonal-corner walking. Do not lower dry
            # patches through a closed-water shortcut to the primary shore.
            values=[]
            for i in touch:
                steps=0 if i in component else dry_steps.get(i)
                if steps is not None:values.append(steps*3.+hypot(hx*.5-i%w,hz*.5-i//w)*3.)
            return min(values)**2 if values else inf
        max_fx,max_fz=(mask.width-1)*2,(mask.height-1)*2
        for fz in range(fine):
            for fx in range(fine):bridges[fz*fine+fx]=ref['bridges'][((fz+1)//2)*width+(fx+1)//2]
        def update_vertex(fx,fz):
            j=fz*fine+fx;hx,hz,touch=point_data(fx,fz);enrolled=[i for i in touch if local_scope[i]]
            if not enrolled:return
            yes=any(walk[i] and pg[i]!=252 for i in enrolled) or bool(base_cov[j] and any(not local_scope[i] for i in touch))
            coverage[j]=base_cov[j] if bridges[j] else int(yes)
            source_x,source_z=hx*.5,hz*.5;d2=grade_distance2(hx,hz,touch)
            target=min(datum(area,source_x,source_z),2.1+max(0.,sqrt(d2)-sqrt(18.))*.2);choices=[];visual=[]
            for i in enrolled:
                tile,obj=bg[i],pg[i]
                cell_target=target if not dry(i) or i in primary_dry else datum(area,source_x,source_z)
                if dry(i):visual.append(cell_target)
                if not walk[i] or obj==252:continue
                high=2.1 if i in component else 0. if tile in(0,100) else cell_target if not 5000<=tile<=5008 or 12500<=obj<12536 else 0.
                choices.append(high)
            if base_cov[j] and any(not local_scope[i] for i in touch):choices.append(baseline_h[j])
            high=max(choices) if choices else 0.;paint=max(visual) if visual else 0.
            source_dry=all(bg[i] not in(0,100) and not 5000<=bg[i]<=5008 for i in touch)
            detached_dry=all(dry(i) and i not in primary_dry for i in enrolled)
            if base_cov[j] and (source_dry and d2>=38.*38. or detached_dry):high=baseline_h[j]
            if bridges[j]:high=baseline_h[j];paint=baseline_b[j]
            heights[j]=high;bed[j]=paint
        pending_points=((fx,fz)for fz in range(max_fz+1)for fx in range(max_fx+1))
        pending_quads=((fx,fz)for fz in range(max_fz)for fx in range(max_fx))
        for iteration in range(w*h):
            for fx,fz in pending_points:update_vertex(fx,fz)
            added=[]
            for fx,fz in pending_quads:
                    j=fz*fine+fx;new=bool(coverage[j] and coverage[j+1] and coverage[j+fine] and coverage[j+fine+1]);old=bool(base_valid[(fz//2)*(width-1)+fx//2])
                    hx,hz=source_half(area,fx,fz);sx=(hx+1)//2;sz=(hz+1)//2 if area=='north_coast' else hz//2
                    if not(0<=sx<w and 0<=sz<h):continue
                    i=sz*w+sx
                    if i in protected:continue
                    changed_height=old and any(abs(heights[k]-baseline_h[k])>.00002 for k in [j,j+1,j+fine,j+fine+1])
                    if new==old and not changed_height:continue
                    if not local_scope[i]:
                        assert goal(sx,sz) or i in component,('Topology extension touches another goal',area,sx,sz)
                        local_scope[i]=1;added.append(i);closure_rows.append({'cell':[sx,sz],'old_support':old,'new_support':new,'height_boundary':bool(changed_height)})
            if iteration<4 or iteration%10==0 or not added:print('HOST100_TOPOLOGY',area,'iteration',iteration,'new_scope',len(added),flush=True)
            if not added:break
            pending_points=set()
            for i in added:
                sx,sz=i%w,i//w;cx,cz=(sx*2-948,sz*2+98)if area=='north_coast'else(844-sz*2,sx*2-698)
                for dz in [-1,0,1]:
                    for dx in [-1,0,1]:
                        if 0<=cx+dx<=max_fx and 0<=cz+dz<=max_fz:pending_points.add((cx+dx,cz+dz))
            pending_quads={(fx+dx,fz+dz)for fx,fz in pending_points for dx,dz in [(0,0),(-1,0),(0,-1),(-1,-1)]if 0<=fx+dx<max_fx and 0<=fz+dz<max_fz}
        else:raise AssertionError('Private topology boundary did not settle')
        height_vertices=sum(abs(a-b)>.000001 or abs(c-d)>.000001 for a,b,c,d in zip(heights,baseline_h,bed,baseline_b))
        visual_anchors={}
        for i in range(w*h):
            if not local_scope[i] or pg[i]<1000:continue
            x,z=i%w,i//w;d2=grade_distance2(x*2,z*2,[i])
            visual_anchors[str(i)]=datum(area,x,z) if dry(i) and i not in primary_dry else min(datum(area,x,z),2.1+max(0.,sqrt(d2)-sqrt(18.))*.2)
        for z in range(mask.height):
            for x in range(mask.width):
                hx,hz=source_half(area,x*2,z*2);sx,sz=hx//2,hz//2
                if not(0<=sx<w and 0<=sz<h):continue
                i=sz*w+sx
                if not local_scope[i]:continue
                tile=bg[i];rgba=(255,0,0,0) if tile in(0,100) else (255 if 5000<=tile<=5008 else 0,224 if 5198<=tile<=5233 or 6400<=tile<=6409 else 0,0,255)
                mask.putpixel((x,z),rgba)
        for z in range(mask.height-1):
            for x in range(mask.width-1):
                ids=[(z*2+dz)*fine+x*2+dx for dz in range(3) for dx in range(3)]
                if any(coverage[j]!=base_cov[j] or heights[j]!=baseline_h[j] or bed[j]!=baseline_b[j] for j in ids):modified.add(z*(mask.width-1)+x)
        mask_path=OUT/(area+'-mask.png');png=io.BytesIO();mask.save(png,format='PNG');prepared_files[mask_path]=png.getvalue()
        effective=[i for i in range(w*h) if local_scope[i] and within_mask(area,i%w,i//w,ref)]
        scene_scope=set(effective)
        water_rects=rectangles(w,h,lambda i:bool(i in scene_scope and walk[i] and pg[i]==252))
        closed=rectangles(w,h,lambda i:bool(i in scene_scope and not walk[i]))
        dry_floors=[]
        if area=='east_gate':
            i=200*w+440;assert bg[i]==1004 and pg[i]==0 and walk[i] and i in scene_scope
            dry_floors=[{'rect':[440,200,1,1],'height':6.,'source_bg':1004,'source_pg1':0,'original_open':True,'inference':'Exact drawn paving supports the existing6m bridge approach; nearest-grid bridge preservation had left this separate source cell unsupported. No water/bridge/other-cell support is added.'}]
            for dz in [-1,0]:
                for dx in [-1,0]:modified.add((91+dz)*(mask.width-1)+222+dx)
        row={'schema':1,'source':100,'area':area,'raw_sha256':restore['raw_sha256'],'width':fine,'spacing':1.5,'route_spacing':3.,'origin':ref['origin'],'mask_origin':ref['origin'],'mask_size':ref['mask_size'],'mask_bounds':ref['mask_bounds'],'mask_path':'res://'+str(mask_path.relative_to(ROOT)),
             'base_width':width,'base_columns':ref['mask_size'][0],'base_rows':ref['mask_size'][1],'base_bed':blob(ref['bed'],'float'),
             'heights':blob(heights,'float'),'bed':blob(bed,'float'),'covered':blob(coverage,'byte'),'bridges':blob(bridges,'byte'),'modified_quads':sorted(modified),
             'scope_bits':blob(pack_bits(local_scope),'byte'),'water_rectangles':water_rects,'source_dry_floor_rectangles':dry_floors,'closed_rectangles':closed,'visual_dry_fixes':visual_dry_fixes,'visual_anchor_heights':visual_anchors,'protected_bridge_cells':sorted(protected),'affected_neighbor_closure':closure_rows,
             'source_raw_path':restore['raw_path'],'source_size':[w,h], 'source_native_bits':restore['native_walk_bits'],
             'bank_cells':[i for i in component if 12500<=pg[i]<12536 and within_mask(area,i%w,i//w,ref)],'shore_cells':[i for i in component if within_mask(area,i%w,i//w,ref)],'bank_land_height':2.1,'water_height':2.,
             'grade_inference':'Primary shore2.1m; dry-substrate cardinal graph distance sets the1:5height cap. This does not assert original server diagonal rules, alter native walk bits, or erase potential diagonal routes. Detached dry patches keep compatible baseline datum.',
             'counts':{'source_scope_cells':len(effective),'visual_dry_zero_bed_corrections':len(visual_dry_fixes),'height_vertices_modified':height_vertices,'modified_coarse_quads':len(modified),'water_rectangles':len(water_rects),'closed_rectangles':len(closed)},
             'source_hashes':{str(path.relative_to(ROOT)):digest(path) for path in [raw_path,restore_path,BASE/'review.json',BASE/(area+'-field.json'),BASE/(area+'-mask.png'),Path(__file__)]}}
        path=OUT/(area+'-field.json');prepared_files[path]=(json.dumps(row)+'\n').encode();summary['areas'][area]={'path':'res://'+str(path.relative_to(ROOT)),'sha256':hashlib.sha256(prepared_files[path]).hexdigest(),'counts':row['counts']}
        print('HOST100_FIELD_PREPARED',area,row['counts'],flush=True)
    summary['source_hashes']={str(path.relative_to(ROOT)):digest(path) for path in [raw_path,restore_path,BASE/'review.json',Path(__file__)]}
    summary['source_changed']=[path for path,sha in before.items() if digest(ROOT/path)!=sha]
    assert not summary['source_changed'],'Composite inputs changed during preparation'
    summary['scope']='PRIVATE original1002989shore/context composition. No canonical source/height/mask/cache/actor/route mutation; actual/native/outside-preservation and rendering remain required.'
    for path,content in prepared_files.items():
        staging=path.with_suffix(path.suffix+'.staging');staging.write_bytes(content);staging.replace(path)
    staging=OUT/'manifest.json.staging';staging.write_text(json.dumps(summary,indent=2)+'\n');staging.replace(OUT/'manifest.json')

def refine_value(values,width,fx,fz):
    x,z=fx//2,fz//2;i=z*width+x
    if not fx%2 and not fz%2:return values[i]
    if not fz%2:return (values[i]+values[i+1])*.5
    if not fx%2:return (values[i]+values[i+width])*.5
    return (values[i+1]+values[i+width])*.5
def pack_bits(values):
    out=bytearray((len(values)+7)//8)
    for i,value in enumerate(values):
        if value:out[i>>3]|=1<<(i&7)
    return out
def within_mask(area,x,z,ref):
    px,pz=source_point(area,x,z);b=ref['mask_bounds']
    return b[0]<=px<b[0]+b[2] and b[1]<=pz<b[1]+b[3]

if __name__=='__main__':main()
