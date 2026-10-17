"""Reproducible rounded, painted-face Reed Archer concept model. No runtime integration."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import common as c
import bpy
from mathutils import Vector, Matrix
import bmesh
c.reset();m=c.material_set()
m['green']=c.mat('Cloak edge olive','485a34');m['trousers']=c.mat('Soft charcoal trousers','454a3c');m['scarf']=c.mat('Russet scarf','823e2b');m['scarf_light']=c.mat('Scarf folded edge','a65b3c');m['sandals']=c.mat('Sandals woven sole','9a7945');m['hair']=c.mat('Shadowed charcoal hair','252c24')
face=c.texture_mat('Painted eyes and brows on actual skull',c.TEX/'reed_archer_face.png');cam=c.texture_mat('Olive leaf camouflage woven cloth',c.TEX/'reed_archer_cloak.png');straw=c.texture_mat('Golden woven straw',c.TEX/'reed_archer_straw.png')
# Full ribcage and pelvis under the costume, with stout compact anatomy.
c.uv_sphere('Anatomy_Ribcage',(0,0,2.28),(.65,.43,.63),m['trousers'],40,24)
c.uv_sphere('Anatomy_Pelvis',(0,-.01,1.60),(.57,.38,.32),m['trousers'],40,24)
c.loft('Inner tunic',[(1.37,0,0,.59,.39),(1.50,0,0,.69,.43),(1.91,0,0,.62,.39),(2.29,0,0,.67,.43),(2.63,0,0,.69,.43),(2.81,0,0,.44,.30)],cam,56)
c.uv_sphere('Neck',(0,0,2.99),(.23,.23,.35),m['skin'])
# Actual closed volumetric head. UV artwork is on its own skin polygons.
rings=[]
for i in range(33):
 t=i/32; z=2.80+1.42*t
 # short chin/jaw, cheek, full rounded cranium
 rx=math.sin(math.pi*t)**.55*(.67+ .045*math.sin(math.pi*t));ry=math.sin(math.pi*t)**.55*.54
 if t<.30:rx*=.76+.24*t/.30
 cy=.035+ .055*math.exp(-((t-.4)/.24)**2)
 rings.append((z,0,cy,max(.014,rx),max(.014,ry)))
head=c.loft('Head_full_3D_skull_with_painted_face',rings,face,96);head['face_artwork']=True
for vert in head.data.vertices:
 x,y,z=vert.co;t=(z-2.80)/1.42
 if y>0:
  vert.co.y+=.075*math.exp(-((x/.105)**2)-((t-.49)/.09)**2)
head.data.update()
for s in [-1,1]:
 c.uv_sphere('Ear_'+str(s),(s*.66,0,3.48),(.115,.11,.19),m['skin'],24,16)
 # temple and back hair forms frame skin, preserving open frontal eye area
 c.uv_sphere('Temple hair_'+str(s),(s*.59,-.13,3.69),(.20,.38,.37),m['hair'],32,20)
c.uv_sphere('Hair nape',(0,-.38,3.55),(.59,.19,.43),m['hair'],40,24)
# Four overlapping russet folds fitted around mouth and neck. Upper face stays open.
c.loft('Scarf mouth and neck wrap',[(2.86,0,.035,.37,.34),(2.98,0,.035,.47,.39),(3.13,0,.045,.66,.56),(3.30,0,.04,.72,.60),(3.36,0,.035,.73,.605)],m['scarf'],64)
for z,rx,ry in [(3.03,.46,.40),(3.17,.68,.575),(3.31,.73,.612)]:
 c.ellipse('Scarf overlapping fabric ridge',(0,.045,z),rx,ry,.022,m['scarf_light'],64,twist=.055)
c.cloth('Scarf pointed front kerchief',[[(-.38,.585,3.16),(0,.665,3.20),(.38,.585,3.16)],[(-.25,.53,2.95),(0,.61,2.87),(.25,.53,2.95)],[(-.08,.46,2.79),(0,.51,2.72),(.08,.46,2.79)]],m['scarf'],.03)
c.cloth('Scarf rear knot tail',[[(-.31,-.40,3.18),(-.19,-.46,3.24),(-.08,-.46,3.19)],[(-.46,-.68,2.91),(-.33,-.70,2.93),(-.18,-.66,2.95)],[(-.59,-.75,2.70),(-.44,-.75,2.75),(-.27,-.68,2.74)]],m['scarf'],.035)
# Circular kasa with tapered crown and double thickness brim, subtle uneven reed ends.
hatrings=[]
for i in range(13):
 t=i/12;hatrings.append((3.82+.64*t,0,-.035,1.59*(1-t)+.07*t,1.37*(1-t)+.07*t))
hat=c.loft('Kasa conical woven straw crown',hatrings,straw,96)
# Interior brim volume and a soft rolled boundary.
c.loft('Kasa underside',[(3.79,0,-.035,1.58,1.36),(3.82,0,-.035,1.59,1.37)],m['wood'],96)
c.ellipse('Kasa bound straw rim',(0,-.035,3.805),1.587,1.369,.030,m['straw'],96)
for j in range(32):
 a=j*math.tau/32
 c.curve('Raised straw rib_%02d'%j,[(math.sin(a)*r,math.cos(a)*r*.863-.035,3.821+.64*(1-r/1.59)) for r in [.15,.40,.75,1.10,1.58]],.008,m['straw'],2)
c.loft('Kasa dark crown cap',[(4.32,0,-.035,.33,.29),(4.43,0,-.035,.10,.09)],m['green'],48)
c.ellipse('Kasa crown tie',(0,-.035,4.39),.16,.14,.028,m['rope'],40)
c.cloth('Hat tied cloth tail',[[(-.10,-.03,4.43),(.08,-.04,4.43)],[(-.20,-.30,4.40),(.01,-.33,4.38)],[(-.37,-.46,4.34),(-.10,-.43,4.33)]],m['hair'],.03)
# Open-front broad layered cloak, with rounded shoulder and irregular lower hem.
def cape(u,v):
 a=.43+u*(math.tau-.86); z=2.99-1.07*v
 rx=.47+.67*(1-math.exp(-v*10)); ry=.32+.30*(1-math.exp(-v*10))
 folds=.026*math.sin(a*11)*math.sin(v*math.pi*.75)
 z-=.105*(math.sin(a*9)**2)*(v**7)
 return (math.sin(a)*(rx+folds),math.cos(a)*(ry+folds),z)
o=c.surface('Layered patched shoulder cloak',cape,cam,84,15)
mod=o.modifiers.new('Woven thickness','SOLIDIFY');mod.thickness=.040;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
def skirt(u,v):
 a=u*math.tau;z=1.87-.59*v-.14*math.sin(a*7)**2*v**8
 rx=.65+.13*v;ry=.41+.055*v
 return (math.sin(a)*(rx+.02*math.sin(a*9)),math.cos(a)*ry,z)
o=c.surface('Layered lower cloak skirt',skirt,cam,72,12);mod=o.modifiers.new('Woven thickness','SOLIDIFY');mod.thickness=.035;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
# Front cape hems echo split short cloak panels.
for s in [-1,1]:
 c.cloth('Front mantle split panel_'+str(s),[[(s*.21,.43,2.72),(s*.61,.35,2.71),(s*.86,.24,2.54)],[(s*.26,.46,2.35),(s*.61,.43,2.27),(s*.98,.26,2.17)],[(s*.30,.45,1.95),(s*.51,.47,1.88),(s*.78,.40,2.00)]],cam,.035)
# Hand-stitched patches lie on garment, with curved cloth corners.
for idx,(s,z,y) in enumerate([(-1,2.42,.565),(1,2.29,.575),(-1,1.51,.405)]):
 x=s*.53
 c.cloth('Sewn olive patch_'+str(idx),[[(x-.12,y,z+.11),(x,y+.025,z+.13),(x+.13,y,z+.11)],[(x-.13,y+.015,z),(x,y+.04,z),(x+.14,y+.015,z)],[(x-.10,y,z-.14),(x,y+.025,z-.12),(x+.11,y,z-.12)]],m['green'],.018)
 for k in [-1,0,1]:c.curve('Visible patch stitch',[(x+k*.075,y+.028,z+.106),(x+k*.075+.014,y+.029,z+.139)],.005,m['rope'],1)
# Short sturdy arms, wrap bands and large articulated mitten hands.
for s in [-1,1]:
 a=(s*.62,0,2.62);b=(s*.91,.10,2.10);w=(s*1.0,.24,1.72)
 c.uv_sphere('Shoulder_'+str(s),a,(.27,.29,.30),m['trousers'],32,20)
 c.tube('Upper arm_'+str(s),a,b,.24,m['trousers'],.23,32)
 c.uv_sphere('Elbow_'+str(s),b,(.25,.25,.25),m['cream'],32,20)
 c.tube('Wrapped forearm_'+str(s),b,w,.225,m['cream'],.19,32)
 for t in [.12,.30,.48,.66,.83]:
  p=Vector(b).lerp(Vector(w),t)
  # contour of cuff in horizontal plane; compact posed forearm axis nearly vertical
  c.ellipse('Forearm wrap band',(p.x,p.y,p.z),.225-.035*t,.23-.04*t,.017,m['rope'],32,twist=s*.035)
 c.uv_sphere('Large hand palm_'+str(s),(s*1.0,.29,1.60),(.25,.22,.27),m['skin'],32,20)
 c.uv_sphere('Fingerless glove back_'+str(s),(s*1.0,.19,1.66),(.251,.14,.25),m['hair'],32,20)
 for k in range(3):
  c.uv_sphere('Curled finger_%s_%s'%(s,k),(s*(.86+.125*k),.438,1.56),(.075,.094,.13),m['skin'],20,12)
 c.uv_sphere('Thumb_'+str(s),(s*.80,.40,1.67),(.12,.13,.17),m['skin'],24,16)
# Belt and knotted russet ties at visible waist.
c.loft('Waist leather belt',[(1.85,0,.012,.66,.43),(2.00,0,.012,.67,.43)],m['wood'],56)
c.curve('Diagonal chest quiver strap',[(-.59,.445,2.72),(-.32,.48,2.52),(.05,.48,2.30),(.47,.442,2.02)],.075,m['wood'],3)
c.uv_sphere('Belt scarf knot',(0,.485,1.93),(.14,.10,.13),m['scarf'],28,16)
c.cloth('Belt hanging scarf',[[(-.03,.45,1.9),(.16,.45,1.9)],[(-.10,.50,1.58),(.09,.50,1.6)],[(-.15,.47,1.42),(.06,.48,1.45)]],m['scarf'],.028)
for s in [-1,1]:
 c.uv_sphere('Rounded trouser thigh_'+str(s),(s*.39,.0,1.21),(.33,.33,.43),m['trousers'],40,24)
 c.uv_sphere('Sturdy wrapped shin_'+str(s),(s*.42,.02,.63),(.23,.25,.43),m['cream'],40,24)
 for z in [.43,.55,.67,.79,.91]:c.ellipse('Leg linen wrap',(s*.42,.02,z),.235,.25,.018,m['rope'],36,twist=.027)
 c.uv_sphere('Foot_'+str(s),(s*.43,.19,.245),(.31,.40,.17),m['skin'],32,20)
 c.uv_sphere('Woven sandal sole_'+str(s),(s*.43,.18,.10),(.37,.47,.095),m['sandals'],40,20)
 for k in range(4):c.uv_sphere('Toe_%s_%s'%(s,k),(s*.43-.20+k*.12,.51,.23),(.07,.09,.095),m['skin'],20,12)
 c.curve('Sandal V thong_'+str(s),[(s*.43-.25,.08,.35),(s*.43,.48,.33),(s*.43+.25,.08,.35)],.045,m['hair'],3)
 for j in range(20):
  a=j*math.tau/20;x=s*.43+math.sin(a)*.335;y=.18+math.cos(a)*.425
  c.curve('Sole reed binding',[(x,y,.07),(x,y,.145)],.017,m['rope'],2)
# Rear quiver and arrows visibly extend above cloak, under kasa edge.
qa=Vector((-.43,-.55,1.55));qb=Vector((-.77,-.75,2.83));c.tube('Wooden back quiver',qa,qb,.225,m['wood'],.27,40)
axis=(qb-qa).normalized()
c.tube('Dark opening inside quiver',qb-axis*.007,qb+axis*.003,.222,m['hair'],count=40)
for frac in [.10,.55,.91]:
 p=qa.lerp(qb,frac)
 # rings are perpendicular to quiver axis
 u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
 c.curve('Quiver rope binding',[tuple(p+u*(.25*math.sin(j*math.tau/48))+v*(.25*math.cos(j*math.tau/48))) for j in range(49)],.035,m['rope'],3)
for idx in range(6):
 dx=(idx%3-1)*.13;dy=(idx//3-.5)*.16
 start=qb+Vector((dx,dy,-.1));end=start+axis*(.62+.05*(idx%2))
 c.tube('Arrow shaft_%02d'%idx,start,end,.017,m['wood'],count=12)
 for side in [-1,1]:
  p=end-axis*.22
  c.cloth('Arrow feather_%s_%s'%(idx,side),[[tuple(p),tuple(p+Vector((side*.12,0,.05)))],[tuple(end),tuple(end+Vector((side*.085,0,-.02)))]],m['cream'],.008)
# Equipment is built on +X for convenience, then reflected to anatomical LEFT (-X).
points=[]
for i in range(33):
 t=i/32; z=.49+2.60*t
 x=1.0+.40*(abs(t-.5)*2)**1.4;y=.42+.015*math.sin(math.pi*t)
 points.append((x,y,z))
c.curve('Wood bow LEFT hand',points,.055,m['wood'],4)
c.curve('Taut bow string LEFT',[(1.4,.42,.49),(1.08,.45,1.63),(1.4,.42,3.09)],.012,m['rope'],2)
for z in [1.49,1.56,1.63,1.70,1.77]:c.tube('Bow grip binding',(1.005,.435,z),(1.005,.435,z+.035),.065,m['rope'],count=16)
# Provide garment UVs for cloth strips, then trim excess tessellation while keeping silhouette.
for o in c.asset_meshes():
 if o.name.startswith('Front mantle split panel'):
  uv=o.data.uv_layers.active
  for loop in o.data.loops:
   co=o.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(co.x*.75,co.z*.85)
 for p in o.data.polygons:p.use_smooth=True
 tri=sum(len(p.vertices)-2 for p in o.data.polygons)
 if tri>180 and o.name!='Kasa conical woven straw crown':
  mod=o.modifiers.new('Concept tessellation optimization','DECIMATE')
  mod.ratio=.70 if o.get('face_artwork') else (.55 if 'cloak' in o.name.lower() or 'mantle' in o.name.lower() else .36)
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
# Front is +Y: a person facing +Y has anatomical LEFT toward -X.
gear_prefixes=('Wood bow','Taut bow','Bow grip','Wooden back quiver','Dark opening inside quiver','Quiver rope binding','Arrow shaft','Arrow feather','Diagonal chest quiver strap')
for o in c.asset_meshes():
 if o.name.startswith(gear_prefixes):
  points=[o.matrix_world@v.co for v in o.data.vertices]
  o.matrix_world=Matrix.Identity(4)
  for v,p in zip(o.data.vertices,points):v.co=(-p.x,p.y,p.z)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free();o.data.update()
bpy.context.view_layer.update()
c.rescale_to_height(c.HEIGHT*1.35)
c.export_asset('reed_archer','Forest ranged enemy concept',[
 'Concept turnaround interpretation only; no game integration.',
 'Compact roughly three-head anatomy, rounded skull/ribcage/pelvis, short sturdy legs and large sandals/hands.',
 'Angry eyes and brows are painted directly on the closed head UV surface; no separate eyes or flat face panel.',
 'Wide straw kasa, layered patched olive cloak, russet mouth scarf, rear quiver, bow in anatomical LEFT hand (-X, screen-right in front review).',
 'Packed PNG artwork. Goemon source/master untouched. Height includes kasa crown.'
])
