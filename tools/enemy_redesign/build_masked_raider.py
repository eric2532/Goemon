"""Concept-only Masked Raider: rounded volumes, curved painted wooden mask."""
from pathlib import Path
import sys,math
sys.path.insert(0,str(Path(__file__).resolve().parent))
import common as C
import bpy
from mathutils import Vector,Matrix
import bmesh
C.reset();m=C.material_set()
cloth=C.texture_mat('Raider weathered indigo cotton',C.TEX/'masked_raider_indigo.png')
maskmat=C.texture_mat('Raider painted aged wood mask',C.TEX/'masked_raider_mask.png')
hair=C.mat('Warm charcoal hair','302b26');skin=C.mat('Warm sun-browned hands','b4855c')
wood=C.mat('Warm split wood','805b3e');edge=C.mat('Armor golden edging','b68850')
rope=C.mat('Woven hemp rope','c2a374');ink=C.mat('Fingerless charcoal gloves','343330')
# Rounded padded torso; deliberately substantial depth in profile.
C.loft('Jacket rounded ribcage',[(1.82,0,0,.69,.43),(2.08,0,0,.76,.51),(2.48,0,0,.89,.60),(2.90,0,-.01,.87,.54),(3.17,0,-.02,.66,.44),(3.27,0,0,.40,.33)],cloth,count=48)
C.uv_sphere('Substantive padded pelvis',(0,-.01,1.82),(.73,.48,.53),cloth)
C.uv_sphere('Compact neck',(0,0,3.23),(.32,.30,.35),skin)
# Padded trousers are short and broad, with almost spherical upper legs.
for side in [-1,1]:
 x=side*.44
 C.loft(f'{side} short billowing trouser',[(.62,x,0,.21,.28),(.85,x,0,.30,.35),(1.13,x,0,.40,.43),(1.46,x,0,.43,.45),(1.70,x,0,.32,.36)],cloth,count=32)
 C.uv_sphere(f'{side} visible shin',(x,.025,.56),(.21,.23,.26),skin,24,16)
 C.uv_sphere(f'{side} sandal thick sole',(x,.11,.12),(.40,.58,.12),wood,32,16)
 C.uv_sphere(f'{side} bare foot',(x,.13,.28),(.34,.49,.19),skin,28,16)
 for toe in range(4):
  C.uv_sphere(f'{side} toe {toe}',(x+(toe-1.5)*.145,.51,.265),(.095,.14,.11),skin,16,10)
 # Thick woven sandal straps wrap the full instep instead of hovering in front.
 C.curve(f'{side} sandal front thong',[(x-.31,.38,.29),(x-.16,.18,.43),(x,.12,.45),(x+.19,.23,.40),(x+.31,.40,.28)],.058,ink,2)
 C.curve(f'{side} ankle sandal tie',[(x-.22,-.24,.42),(x-.20,.0,.48),(x,.12,.51),(x+.21,.0,.48),(x+.22,-.24,.42)],.052,rope,2)
 for z in [.69,.75]:C.ellipse(f'{side} ankle rope {z}',(x,0,z),.24,.30,.036,rope,32,twist=.02)
# Jacket skirt is an actual circumferential shell with overlapping rounded front panels.
C.loft('Jacket full curved skirt',[(1.40,0,0,.91,.52),(1.65,0,0,.88,.53),(1.95,0,0,.77,.50),(2.15,0,0,.72,.48)],cloth,count=48)
# Cream distressed hem in an understated wavy edging.
C.ellipse('Cream worn jacket hem',(0,0,1.41),.906,.522,.024,m['cream'],64,twist=.027)
# Wrap lapels follow convex chest geometry, with a small dark undershirt visible at collar.
C.uv_sphere('Dark inner collar',(0,.38,3.02),(.35,.15,.31),ink,24,16)
C.cloth('Left diagonal wrapping lapel',[
 [(.49,.36,3.21),(.31,.47,3.17)],[(.23,.58,2.89),(.02,.617,2.87)],[(-.14,.611,2.49),(-.38,.559,2.48)],[(-.50,.509,2.15),(-.68,.43,2.16)]],cloth,.038)
C.cloth('Right folding lapel',[
 [(-.47,.36,3.20),(-.30,.47,3.19)],[(-.22,.58,2.94),(-.03,.61,2.88)],[(.13,.614,2.64),(.27,.586,2.53)],[(.39,.54,2.38),(.48,.52,2.34)]],cloth,.033)
C.curve('Visible diagonal lapel seam',[(.40,.41,3.2),(.12,.613,2.87),(-.27,.606,2.50),(-.59,.477,2.17)],.023,m['indigo'],2)
# Belt with plaited rope courses and a deep red tie.
C.loft('Broad red sash',[(1.95,0,0,.79,.53),(2.08,0,0,.81,.54),(2.17,0,0,.77,.52)],m['red'],count=48)
for strand in range(3):
 pts=[]
 for j in range(121):
  a=j*math.tau/120
  pts.append((.81*math.sin(a),.56*math.cos(a),2.20+.028*math.sin(a*16+strand*math.tau/3)))
 C.curve('Braided waist rope strand '+str(strand),pts,.041,rope,2)
for x in [-.51,.51]:
 C.uv_sphere('Sash tied knot '+str(x),(x,.50,2.04),(.11,.10,.11),m['red'],20,12)
 C.curve('Red sash loop '+str(x),[(x,.52,2.06),(x+.16,.54,2.10),(x+.19,.54,2.00),(x,.52,2.01)],.041,m['red'],2)
 C.cloth('Red sash hanging end '+str(x),[[(x-.07,.53,2.00),(x+.07,.53,2.00)],[(x-.08,.565,1.80),(x+.09,.565,1.80)],[(x-.12,.56,1.52),(x+.08,.56,1.54)]],m['red'],.038)
# Upper arm sleeves and big chunky hands.
for side in [-1,1]:
 C.uv_sphere(f'{side} full padded shoulder',(side*.91,0,2.90),(.40,.42,.43),cloth,28,18)
 sleeve=C.uv_sphere(f'{side} rounded short sleeve',(side*1.09,.015,2.66),(.40,.43,.46),cloth,32,20);sleeve.rotation_euler.y=side*.29
 C.uv_sphere(f'{side} thick forearm',(side*1.20,.025,2.26),(.26,.29,.36),skin,24,16)
 for z in [2.30,2.37,2.44]:C.ellipse(f'{side} wrist hemp {z}',(side*1.20,.025,z),.27,.295,.036,rope,32,twist=.025)
 C.uv_sphere(f'{side} fingerless glove',(side*1.24,.04,1.99),(.31,.32,.29),ink,28,16)
 C.uv_sphere(f'{side} exposed thumb',(side*1.05,.29,1.94),(.125,.16,.17),skin,20,12)
 for i in range(3):C.uv_sphere(f'{side} exposed curled finger {i}',(side*1.24+(i-1)*.14,.27,1.83),(.09,.115,.145),skin,20,12)
# Convex wooden shoulder armor; final coordinate correction places left at -X.
for j in range(3):
 z=3.12-j*.23
 def armor(u,v):
  ang=-math.pi*.59+u*math.pi*1.18
  return (1.025+.53*math.cos(ang),.54*math.sin(ang),z+(v-.5)*.245-.16*math.cos(ang))
 plate=C.surface('Left convex shoulder wooden plate '+str(j),armor,wood,cols=24,rows=4)
 mod=plate.modifiers.new('Thick timber plate','SOLIDIFY');mod.thickness=.06;bpy.context.view_layer.objects.active=plate;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=plate.modifiers.new('Timber rounded rim','BEVEL');mod.width=.024;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 for v in [0,1]:C.curve('Shoulder armor golden rim '+str(j)+' '+str(v),[armor(k/32,v) for k in range(33)],.026,edge,2)
 C.curve('Shoulder armor binding '+str(j),[armor(k/32,.50) for k in range(33)],.025,m['red'],2)
 for u in [.05,.95]:
  pos=Vector(armor(u,.80));pos.y+=.028 if pos.y>0 else -.028
  C.uv_sphere('Armor small peg',pos,(.026,.025,.026),edge,12,8)
C.uv_sphere('Left armor rope knot',(.91,.43,2.81),(.11,.085,.10),m['red'],20,12)
C.cloth('Left armor tassel',[[(.87,.46,2.78),(.95,.46,2.78)],[(.86,.47,2.55),(.97,.47,2.55)],[(.84,.45,2.40),(.98,.45,2.40)]],m['red'],.035)
# FULL round cranium behind a thin bowed wood mask.
C.uv_sphere('Full rounded skull',(0,-.045,3.76),(.80,.71,.83),hair,48,30)
# More intentional rounded cheek volume and tapered chin underneath the mask.
C.uv_sphere('Underlying cheek and jaw',(0,.16,3.47),(.66,.53,.52),skin,36,22)
for side in [-1,1]:
 C.uv_sphere(f'{side} visible ear',(side*.81,.12,3.68),(.16,.16,.25),skin,24,16)
 C.uv_sphere(f'{side} recessed ear inset',(side*.855,.229,3.69),(.07,.042,.13),wood,20,12)
 # Rear hair lobes make skull depth unambiguous in profile.
 for j in range(3):
  lock=C.uv_sphere(f'{side} solid rear hair lock {j}',(side*(.55-j*.11),-.51,3.54+j*.18),(.26,.28,.32),hair,24,16)
  lock.rotation_euler.y=side*(.42-j*.13)
def mask_fn(u,v):
 t=2*u-1;s=2*v-1
 # Jaw tapers gently; sides remain curved instead of an oval billboard.
 width=.76*(.73+.27*math.sin(math.pi*v))
 x=t*width;z=3.03+v*1.53+.20*(1-v)**7*t*t-.19*v**7*t*t
 y=.40+.41*math.sqrt(max(.02,1-.74*t*t-.32*s*s))
 # Tiny integrated nose swelling remains in the same UV-bearing surface.
 y+=.052*math.exp(-((t/.14)**2+((v-.43)/.20)**2))
 return (x,y,z)
face=C.surface('Thin curved wood mask painted face',mask_fn,maskmat,cols=48,rows=40);face['face_artwork']=True
mod=face.modifiers.new('Real wood mask thickness','SOLIDIFY');mod.thickness=.045;bpy.context.view_layer.objects.active=face;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=face.modifiers.new('Soft worn mask rim','BEVEL');mod.width=.012;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
# Headband physically circles the head; its rear tied ends read from every angle.
C.ellipse('Indigo headband',(0,-.035,4.18),.735,.615,.075,cloth,64,twist=.015)
C.uv_sphere('Rear headband tie',(0,-.752,4.15),(.14,.095,.12),cloth,24,16)
C.cloth('Rear upper ribbon',[[(-.08,-.75,4.15),(.07,-.75,4.15)],[(-.22,-.99,4.20),(.02,-1.01,4.16)],[(-.49,-1.28,4.25),(-.22,-1.27,4.18)]],cloth,.035)
C.cloth('Rear falling ribbon',[[(-.03,-.77,4.11),(.08,-.77,4.11)],[(.15,-.92,3.94),(.30,-.91,3.94)],[(.27,-1.06,3.69),(.45,-1.02,3.73)]],cloth,.035)
# Tied swept-up hair with rounded, not needle-thin, locks.
C.uv_sphere('Topknot hair base',(0,-.10,4.48),(.32,.28,.23),hair,28,18)
C.ellipse('Topknot hemp binding',(0,-.10,4.59),.215,.20,.042,rope,40)
for i,(cx,cy,h,rx) in enumerate([(-.22,-.12,.34,.15),(-.07,-.25,.46,.19),(.13,-.15,.45,.19),(.29,-.05,.31,.16)]):
 C.loft('Swept hair tuft '+str(i),[(4.55,cx*.5,cy*.4,.12,.12),(4.67,cx,cy,rx,.15),(4.67+h*.55,cx+.08,cy-.04,rx*.9,.125),(4.67+h,cx+.16,cy-.09,.03,.025)],hair,count=20)
# Wooden club; final coordinate correction places the right hand at +X.
a=Vector((-1.29,.16,1.90));b=Vector((-1.73,.41,.44));axis=(b-a).normalized()
C.tube('Right hand wooden club shaft',a,b,.085,wood,radius2=.205,count=12)
C.uv_sphere('Club rounded striking end',b,(.22,.22,.16),wood,20,12)
# Inlaid strips follow the handle's length; these are wood construction marks.
for i in range(6):
 ang=i*math.tau/6
 start=a+Vector((math.cos(ang)*.082,math.sin(ang)*.082,0))
 end=b+Vector((math.cos(ang)*.20,math.sin(ang)*.20,0))
 C.curve('Club longitudinal grain '+str(i),[start,((start+end)/2),end],.008,edge,1)
for i in range(3):
 center=a+(b-a)*(.065+i*.043)
 C.ellipse('Club grip binding '+str(i),center,.09,.09,.018,rope,24)
# Front camera (+Y) review: anatomical LEFT is -X, RIGHT is +X.
# Reflect mesh placement while keeping UVs and positive object scales intact.
reflect=Matrix.Diagonal((-1.0,1.0,1.0,1.0))
for o in C.asset_meshes():
 o.matrix_world=reflect @ o.matrix_world @ reflect
 for v in o.data.vertices:v.co.x=-v.co.x
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
# Preserve painted face UV lattice; simplify hidden and accessory smooth surfaces.
for o in C.asset_meshes():
 triangles=sum(len(p.vertices)-2 for p in o.data.polygons)
 if triangles>350 and not o.get('face_artwork'):
  mod=o.modifiers.new('Restrained smooth export topology','DECIMATE');mod.ratio=.44
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
scale=C.rescale_to_height(C.HEIGHT*1.40)
C.export_asset('masked_raider','Oversized masked forest infantry',[
 'Curved 45mm wooden face shell UV-mapped with painted angry eyes, brows, mouth and red markings; no floating facial features.',
 'Full rounded cranium, deep padded ribcage and pelvis, short stout limbs and large hands/sandals; designed specifically to hold volume in profile.',
 'Anatomical left wooden shoulder armor; anatomical right wooden club; indigo worn wrap jacket, hemp rope belt, red tied sash and swept topknot.',
 'Height is exactly 1.40 times measured read-only Goemon master; asset-only approval, no game or gameplay integration.',
 'Editable generator and packed PNG textures; separate named rigid meshes without skeletal rig.'
])
