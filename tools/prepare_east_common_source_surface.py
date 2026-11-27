"""Prepare one PRIVATE source100 surface proposal; never mutate regional products."""
from array import array
import argparse
import base64
from collections import Counter,deque
import hashlib
import json
from math import cos,hypot,inf,sin,sqrt
from pathlib import Path
import struct
import sys
import zlib

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
HOST=REPORT/'Il Source Completion/Low Source Candidate/Host/Original100 Candidate'
DEFAULT_RESTORE=REPORT/'Village Props/Cliff Audit/Source Context Audit/Prototype/field100-restore.json'
WIDTH,HEIGHT=840,610


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def f32(value):return struct.unpack('<f',struct.pack('<f',value))[0]
def goal(x,z):return x>=440 and(z<360 or 636<=x<726 and 312<=z<423 or 529<=x<629 and 20<=z<120)
def smooth(a,b,value):
    t=max(0.,min(1.,(value-a)/(b-a)));return t*t*(3.-2.*t)
def rect_distance(x,z,r):return hypot(x-max(r[0],min(r[0]+r[2],x)),z-max(r[1],min(r[1]+r[3],z)))*3.
def blob(values,kind):
    raw=array(kind,values).tobytes()if kind!='B'else bytes(values)
    return{'raw_bytes':len(raw),'deflate':base64.b64encode(zlib.compress(raw,9)).decode()}
def unpack(row):return zlib.decompress(base64.b64decode(row['deflate']))
def cells_at(half):return(half//2,)if half%2==0 else(half//2,half//2+1)


class SourceSurface:
    """Offline proposal used by both frame emitters, not another runtime backend."""
    def __init__(self,bg,pg,walk,bridge_cells):
        self.bg,self.pg,self.walk=bg,pg,walk;self.bridge=set(bridge_cells)
        self.owned=bytearray(goal(i%WIDTH,i//WIDTH)or i in self.bridge for i in range(WIDTH*HEIGHT))
        self.water=lambda i:5000<=bg[i]<=5008
        self.bank=lambda i:12500<=pg[i]<12536
        self.control=lambda i:pg[i]in(250,251,252)
        self.dry=lambda i:bg[i]not in(0,100)and not self.water(i)
        self.wet={i for i in range(WIDTH*HEIGHT)if walk[i]and(self.bank(i)or(self.control(i)and self.water(i)))}
        self.distance={};pending=deque()
        for i in self.wet:
            if not self.owned[i]:continue
            for j in self.neighbors(i):
                if self.owned[j]and self.dry(j)and j not in self.distance:self.distance[j]=1;pending.append(j)
        while pending:
            i=pending.popleft()
            for j in self.neighbors(i):
                if self.owned[j]and self.dry(j)and j not in self.distance:self.distance[j]=self.distance[i]+1;pending.append(j)
        self.coarse={};self.cache={}
        # Whole existing source owners, not the smaller exclusive bridge flags.
        self.anchors=[(438.,193.,30.,6.),(553.5,231.5,6.,3.),(439.5,199.5,1.,1.)]
    def neighbors(self,i):
        x,z=i%WIDTH,i//WIDTH
        for xx,zz in[(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
            if 0<=xx<WIDTH and 0<=zz<HEIGHT:yield zz*WIDTH+xx
    def coarse_wave(self,x,z):
        key=(x,z)
        if key not in self.coarse:
            sx,sz=x*3.,z*3.;self.coarse[key]=f32(6.+1.6*sin(sx*.014+sz*.008)+1.1*cos(sz*.018-sx*.008))
        return self.coarse[key]
    def base(self,hx,hz):
        x,z=hx//2,hz//2
        if not hx%2 and not hz%2:value=self.coarse_wave(x,z)
        elif not hz%2:value=f32((self.coarse_wave(x,z)+self.coarse_wave(x+1,z))*.5)
        elif not hx%2:value=f32((self.coarse_wave(x,z)+self.coarse_wave(x,z+1))*.5)
        else:value=f32((self.coarse_wave(x+1,z)+self.coarse_wave(x,z+1))*.5)
        distance=min(rect_distance(hx*.5,hz*.5,r)for r in self.anchors)
        weight=1.-smooth(0.,18.,distance)
        return f32(value+(6.-value)*weight),max(0.,6.-distance*.2)
    def point(self,hx,hz):
        key=(hx,hz)
        if key in self.cache:return self.cache[key]
        touch=[z*WIDTH+x for z in cells_at(hz)for x in cells_at(hx)if 0<=x<WIDTH and 0<=z<HEIGHT]
        enrolled=[i for i in touch if self.owned[i]]
        if not enrolled:return None
        base,bridge_lower=self.base(hx,hz)
        distances=[]
        for i in enrolled:
            steps=0 if i in self.wet else self.distance.get(i)
            if steps is not None:distances.append(steps*3.+hypot(hx*.5-i%WIDTH,hz*.5-i//WIDTH)*3.)
        distance=min(distances,default=inf)
        target=max(min(base,2.1+max(0.,distance-sqrt(18.))*.2),bridge_lower)
        visual=any(self.dry(i)for i in enrolled)
        land=any(self.walk[i]and(self.dry(i)or self.bank(i))for i in enrolled)
        # A control's centre stays uncovered; its exact source-cell water piece
        # supplies2m without granting nearby closed water or raising it to a bank.
        high=6. if any(i in self.bridge for i in enrolled)else target if land else 0.
        bed=0. if any(i in self.bridge for i in enrolled)else target if visual else 0.
        result=(f32(high),f32(bed),int(land),f32(bridge_lower))
        self.cache[key]=result;return result
    def role(self,i):
        if i in self.bridge:return'bridge_open'if self.walk[i]else'bridge_closed_or_unrecorded'
        if self.bg[i]in(0,100):return'void_or_unrecorded'
        if self.bank(i):return('wet_bank'if self.water(i)else'bank_nonwater_context')+('_open'if self.walk[i]else'_closed')
        if self.water(i)and self.control(i)and self.walk[i]:return'water_control_'+str(self.pg[i])
        if self.water(i):return'closed_water'if not self.walk[i]else'other_open_water_role'
        return'dry_open'if self.walk[i]else'dry_closed_art'


def main(restore_path,output):
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    restore=json.loads(restore_path.read_text());raw_path=ROOT/restore['raw_path'].removeprefix('res://')
    paths=[restore_path,raw_path,HOST/'manifest.json',Path(__file__),ROOT/'scripts/forest/forest_freyja_regions.gd']
    paths += [HOST/(a+'-field.json')for a in['east_gate','north_coast']]
    before={str(p.relative_to(ROOT)):digest(p)for p in paths}
    assert digest(raw_path)==restore['raw_sha256'];w,h,bg,pg,_=lib.parse_map(raw_path.read_bytes());assert(w,h)==(WIDTH,HEIGHT)
    bits=base64.b64decode(restore['native_walk_bits']);walk=[bool(bits[i>>3]&(1<<(i&7)))for i in range(w*h)]
    bridge=set()
    for area in['east_gate','north_coast']:bridge.update(json.loads((HOST/(area+'-field.json')).read_text())['protected_bridge_cells'])
    assert len(bridge)==198
    surface=SourceSurface(bg,pg,walk,bridge);half_w,half_h=w*2+1,h*2+1
    heights=array('f',[0.])*(half_w*half_h);bed=heights[:];covered=bytearray(len(heights));owned_points=bytearray(len(heights))
    for hz in range(half_h):
        for hx in range(half_w):
            result=surface.point(hx,hz)
            if result is None:continue
            i=hz*half_w+hx;heights[i],bed[i],covered[i],_=result;owned_points[i]=1
    roles=Counter(surface.role(i)for i in range(w*h)if surface.owned[i])
    water=[i for i in range(w*h)if surface.owned[i]and surface.water(i)and surface.control(i)and walk[i]]
    banks=[i for i in range(w*h)if surface.owned[i]and surface.bank(i)]
    conflicts=[]
    for i in water+banks:
        expected=2. if i in water else 2.1;_,lower=surface.base((i%w)*2,(i//w)*2)
        if lower>expected+.00001:conflicts.append({'cell':[i%w,i//w],'role':surface.role(i),'desired_role_height':expected,'bridge_grade_lower_bound':lower})
    changed=[k for k,v in before.items()if digest(ROOT/k)!=v];assert not changed
    data={'schema':1,'status':'PRIVATE offline proposed source-space surface; regional products not replaced','raw_sha256':restore['raw_sha256'],'source_size':[w,h],'half_size':[half_w,half_h],'spacing_source_cells':.5,'spacing_model_m':1.5,'origin_source_cell':[0,0],'world_scale':1.3,'heights':blob(heights,'f'),'bed':blob(bed,'f'),'covered':blob(covered,'B'),'owned_points':blob(owned_points,'B'),'owned_source_cells':blob(surface.owned,'B'),'water_cells':water,'bank_cells':banks,'bridge_cells':sorted(bridge),'role_counts':dict(roles),'bridge_role_height_conflicts':conflicts,'source_hashes':before,'source_changed':changed,'limits':['No local-frame field has consumed this proposal. No Native, player, pet, camera, route or performance acceptance.','Boundary/other-owner constraints, source24bridge raw completion, closed ownership and effective max-piece precedence require projection/review before any activation.','Heights/bridge blend/1:5dry grade/canonical triangle choice are3Dinference. Raw source roles and walk bits are immutable.']}
    output.mkdir(parents=True,exist_ok=True);(output/'.gdignore').touch();p=output/'source-surface.json';p.write_text(json.dumps(data)+'\n')
    summary={k:data[k]for k in['status','raw_sha256','role_counts','bridge_role_height_conflicts','source_hashes','source_changed','limits']};summary['surface_sha256']=digest(p);summary['prepared_source_half_points']=sum(owned_points);summary['covered_half_points']=sum(covered)
    (output/'review.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:summary[k]for k in['surface_sha256','prepared_source_half_points','covered_half_points','role_counts','bridge_role_height_conflicts']}))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--restore',type=Path,default=DEFAULT_RESTORE);parser.add_argument('--out',type=Path,default=HOST/'Common Source Candidate');args=parser.parse_args();main(args.restore.resolve(),args.out.resolve())
