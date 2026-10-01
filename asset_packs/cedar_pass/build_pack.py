"""Original Cedar Pass kit. Blender 4.3+: blender -b --python build_pack.py [-- --checkpoint]."""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
random.seed(2532)
COL={'cedar':'633E35','cut':'A56A47','plaster':'F7DCA3','roof':'237D80','ridge':'184C60','red':'C84939','gold':'EFBA55','paper':'FFF1CA','leaf':'398666','lightleaf':'77AC68','pink':'EB91A3','stone':'687888','lightstone':'91A3A0','moss':'738E54','snow':'DAEBDE','dark':'303E4A'}
M={}
def mat(k):
 if k in M:return M[k]
 h=COL[k];m=bpy.data.materials.new('CP_'+k);m.use_nodes=True;c=[int(h[i:i+2],16)/255 for i in (0,2,4)];c=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c];m.diffuse_color=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;M[k]=m;return m
def finish(o,n,k):
 o.name=n;o.data.materials.append(mat(k));return o
def box(n,p,s,k):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,n,k)
def mesh(n,v,f,k):
 d=bpy.data.meshes.new(n);d.from_pydata(v,[],f);d.update();o=bpy.data.objects.new(n,d);bpy.context.collection.objects.link(o);return finish(o,n,k)
def beam(n,a,b,r,k,r2=None):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=r,radius2=r if r2 is None else r2,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,n,k)
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.context.scene.unit_settings.system='METRIC'
def roof(w,d,z,rise=2,cx=0,cy=0,k='roof'):
 # Five-section flared roof, thick closed strips and raised ridge ends.
 for side in [-1,1]:
  path=[(0,z+rise),(.42*d,z+.17),(.5*d,z+.38)]
  for (y0,z0),(y1,z1) in zip(path,path[1:]):
   v=[(cx+x,cy+side*y,h) for hshift in [0,-.16] for x,y,h in [(-w/2,y0,z0+hshift),(w/2,y0,z0+hshift),(w/2,y1,z1+hshift),(-w/2,y1,z1+hshift)]]
   mesh('Swept ceramic roof',v,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],k)
   for i in range(int(w/.6)+1):
    x=cx-w/2+i*w/int(w/.6);beam('Tile seam',(x,cy+side*y0,z0+.035),(x,cy+side*y1,z1+.035),.032,'ridge')
  beam('Eave fascia',(cx-w/2,cy+side*d/2,z+.29),(cx+w/2,cy+side*d/2,z+.29),.105,'ridge')
 beam('Ridge cap',(cx-w/2-.15,cy,z+rise+.10),(cx+w/2+.15,cy,z+rise+.10),.16,'ridge')
 for side in [-1,1]:beam('Ridge finial',(cx+side*w/2,cy,z+rise+.1),(cx+side*(w/2+.25),cy,z+rise+.48),.13,'gold',.06)
def lattice(x,y,z,w,h):
 box('Paper screen',(x,y,z),(w,.08,h),'paper')
 for i in range(5):box('Screen mullion',(x-w/2+i*w/4,y-.06,z),(.045,.06,h),'cedar')
 for j in range(4):box('Screen rail',(x,y-.065,z-h/2+j*h/3),(w,.06,.045),'cedar')
def building(kind):
 w,d,h={'machiya':(8,6,4),'inn':(10,7,7),'tea_house':(9,6,3.5),'warehouse':(8,7,5),'shrine':(7,6,4.2),'gatehouse':(12,5,6)}[kind]
 if kind=='gatehouse':
  for x in [-4.5,4.5]:
   box('Gate tower',(x,0,2),(3,4,4),'plaster')
   for xx in [x-1.35,x+1.35]:box('Gate pillar',(xx,-2,2),(.28,.3,4),'red')
   lattice(x,-2.08,2.8,1.5,1.4)
  box('Upper passage',(0,0,4.6),(12,4,1.2),'cedar')
  for x in [-4,-2,0,2,4]:lattice(x,-2.05,4.7,1.6,.85)
  roof(13,6,5.3,1.8);return
 open_=kind in ['machiya','tea_house'];wall='plaster';wood='red' if kind=='shrine' else 'cedar'
 box('Stone plinth',(0,0,.12),(w+.4,d+.4,.24),'stone');box('Timber floor',(0,0,.30),(w,d,.12),'cut')
 box('Rear wall',(0,d/2-.12,h/2+.3),(w,.24,h),wall)
 for x in [-w/2+.12,w/2-.12]:box('Side wall',(x,0,h/2+.3),(.24,d,h),wall)
 if open_:
  gap=2.4 if kind=='machiya' else 3.2
  for sign in [-1,1]:box('Front wing',(sign*(w+gap)/4,-d/2+.12,h/2+.3),((w-gap)/2,.24,h),wall)
  box('Door header',(0,-d/2+.12,(h+2.9)/2+.3),(gap,.24,h-2.9),wall)
  for x in [-gap/2-.25,gap/2+.25]:lattice(x,-d/2-.06,1.6,.45,2.5)
  for x in [-2,2]:
   box('Tatami mat',(x,.4,.39),(3,3,.06),'moss')
   box('Mat border',(x-1.45,.4,.43),(.08,3,.03),'cedar')
  box('Low table',(0,1,.9),(2,1.1,.14),'red')
  for x in [-.8,.8]:box('Table legs',(x,1,.65),(.15,.8,.45),'cedar')
 else:
  box('Front wall',(0,-d/2+.12,h/2+.3),(w,.24,h),wall)
  lattice(0,-d/2-.04,1.6,2,2.5)
 for x in [-w/2+.1,-w/4,w/4,w/2-.1]:
  box('Front post',(x,-d/2-.07,h/2+.3),(.18,.22,h),wood)
 for z in [.55,2.95,h+.22]:
  if open_ and z<1:
   for sign in [-1,1]:box('Facade rail',(sign*(w+gap)/4,-d/2-.12,z),((w-gap)/2,.18,.18),wood)
  else:box('Facade rail',(0,-d/2-.12,z),(w,.18,.18),wood)
 for x in [-w*.33,w*.33]:lattice(x,-d/2-.08,1.8,1.7,1.6)
 if kind=='inn':
  for x in [-3.4,-1.15,1.15,3.4]:lattice(x,-d/2-.09,5.2,1.8,2)
  roof(w+1.2,2.2,3.25,.5,cy=-d/2)
  box('Balcony deck',(0,-d/2-.7,4),(w,1.4,.18),'cut')
  for x in range(-4,5):box('Balcony baluster',(x,-d/2-1.3,4.5),(.09,.09,1),'cedar')
  box('Balcony handrail',(0,-d/2-1.3,5),(w,.15,.12),'red')
 if kind=='warehouse':
  for x in [-3.4,3.4]:
   for z in [.9,1.6,2.3]:box('Stone corner band',(x,-d/2-.15,z),(1.15,.1,.42),'stone')
  lattice(0,-d/2-.15,4.1,1.2,.8)
 if kind in ['machiya','tea_house']:
  roof(w+1,2.2,3.15,.55,cy=-d/2-.3)
  for x in [-w/2,w/2]:box('Veranda post',(x,-d/2-1,.3+1.5),(.14,.14,3),'cedar')
  for x in [-1,0,1]:box('Split indigo noren',(x,-d/2-.35,2.85),(.9,.07,.6),'red' if kind=='tea_house' else 'roof')
  box('Entry step',(0,-d/2-.55,.12),(3.2,1.1,.24),'stone')
 if kind=='shrine':
  for i in range(3):box('Shrine approach',(0,-d/2-.4-i*.45,.09+(2-i)*.07),(4-i*.3,.5,.18+(2-i)*.14),'stone')
  roof(5,3,3.45,1.1,cy=-d/2)
  beam('Sacred rope',(-2.5,-d/2-.4,2.8),(2.5,-d/2-.4,2.8),.07,'gold')
  for x in [-1.6,-.5,.5,1.6]:box('Paper offering',(x,-d/2-.42,2.5),(.14,.05,.4),'paper')
 roof(w+1.2,d+1.2,h+.35,1.8 if kind!='tea_house' else 1.3)
 # Solid gable triangles close attic at left and right.
 for x in [-w/2,w/2]:mesh('Gable infill',[(x,-d/2,h+.3),(x,d/2,h+.3),(x,0,h+(1.6 if kind=='tea_house' else 2.1))],[(0,1,2)],wall)
 if kind=='machiya':
  box('Hanging shop sign',(3,-d/2-.4,3.9),(.6,.2,1.5),'gold')
  for z in [3.5,3.9,4.3]:box('Original sign motif',(3,-d/2-.52,z),(.32,.025,.1),'red')
def crown(p,s,k,seed):
 rng=random.Random(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p);o=bpy.context.object
 for v in o.data.vertices:v.co*=rng.uniform(.84,1.16)
 o.scale=s;finish(o,'Faceted foliage',k)
def tree(kind):
 if kind=='bamboo':
  for i,(x,y,h) in enumerate([(-.7,0,5.5),(.3,.4,6.3),(.8,-.5,4.8)]):
   beam('Bamboo culm',(x,y,0),(x+.2,y,h),.12,'leaf',.08)
   for z in range(1,int(h)):
    beam('Bamboo node',(x+.2*z/h,y,z),(x+.2*z/h,y,z+.08),.145,'gold')
    for side in [-1,1]:
     a=(x,y,z+.2);b=(x+side*1.15,y+.25,z+.65);beam('Twig',a,b,.035,'leaf')
     for t in [.4,.7,1]:
      xx=x+side*1.15*t;mesh('Lance leaf',[(xx,y+.25*t,z+.2+.45*t),(xx+side*.5,y+.4,z+.75),(xx+side*.8,y+.3,z+.65),(xx+side*.25,y+.12,z+.3)],[(0,1,2,3)],'lightleaf')
  return
 h=7 if kind=='cedar' else 5.5
 beam('Tapered bent trunk',(0,0,0),(.35,.1,h),.36,'cedar',.10)
 if kind=='cedar':
  for j in range(4):
   z=2.2+j*1.15;r=2.3-j*.4
   # Angular tier with offset apex, irregular eight-point skirt.
   v=[(.3,0,z+2)]+[(math.cos(i*math.pi/4)*r,math.sin(i*math.pi/4)*r,z+(.18 if i%2 else 0)) for i in range(8)];mesh('Cedar tier',v,[(0,1+i,1+(i+1)%8) for i in range(8)]+[tuple(range(8,0,-1))],'leaf' if j%2 else 'lightleaf')
 else:
  for i in range(7):
   a=i*2.4;r=1.6 if i<5 else .6;p=(math.cos(a)*r,math.sin(a)*r,3.5+i*.3)
   beam('Forked limb',(.2,0,1.8+i*.23),p,.16,'cedar',.055);crown(p,(1.5,1.25,.85),'pink' if kind=='sakura' else ('leaf' if i%2 else 'lightleaf'),i)
  if kind=='pine':crown((.2,0,5.8),(1.4,1.2,.6),'leaf',88)
def rock(kind):
 dims={'river_rock':(2.6,1.8,1.3),'moss_boulder':(3,2.4,2.4),'split_crag':(3.2,2.2,4),'cliff_step':(6,3.5,4)}[kind]
 w,d,h=dims;rng=random.Random(kind);v=[]
 for j,(z,fac) in enumerate([(0,.86),(h*.35,1),(h*.85,.75),(h,.42)]):
  for i in range(7):
   a=i*2*math.pi/7;v.append((math.cos(a)*w/2*fac+rng.uniform(-.16,.16),math.sin(a)*d/2*fac+rng.uniform(-.12,.12),z))
 faces=[tuple(range(6,-1,-1))]
 for j in range(3):
  for i in range(7):
   a=j*7+i;b=j*7+(i+1)%7;c=b+7;e=a+7;faces.extend([(a,b,c),(a,c,e)])
 faces.append(tuple(range(21,28)));o=mesh('Stratified stone',v,faces,'stone');o.data.materials.append(mat('lightstone'));o.data.materials.append(mat('moss'))
 for p in o.data.polygons:p.material_index=2 if kind=='moss_boulder' and p.center.z>h*.75 else (1 if p.index%5==0 else 0)
 if kind=='split_crag':
  beam('Dark fracture',(-.35,-d*.43,.5),(.2,-d*.39,h*.85),.07,'dark')
def mountain(kind):
 peaks={'twin_summit':[(-5,0,12),(4,1,15)],'long_ridge':[(-11,0,7),(-4,1,11),(3,0,9),(10,0,6)],'sacred_peak':[(0,0,20)]}[kind]
 for j,(x,y,h) in enumerate(peaks):
  rng=random.Random(70+j);n=9;v=[]
  for z,r in [(0,h*.65),(h*.35,h*.44),(h*.72,h*.20),(h,0.4)]:
   for i in range(n):
    a=2*math.pi*i/n;v.append((x+math.cos(a)*r*rng.uniform(.8,1.2)+z*.1,y+math.sin(a)*r*.7,z))
  fs=[tuple(range(n-1,-1,-1))]
  for layer in range(3):
   for i in range(n):a=layer*n+i;b=layer*n+(i+1)%n;fs.extend([(a,b,b+n),(a,b+n,a+n)])
  fs.append(tuple(range(27,36)));o=mesh('Folded mountain',v,fs,'stone')
  for k in ['moss','lightstone','snow']:o.data.materials.append(mat(k))
  for p in o.data.polygons:
   z=sum(o.data.vertices[i].co.z for i in p.vertices)/len(p.vertices);p.material_index=3 if z>h*.76 else (1 if z<h*.22 else (2 if p.index%4==0 else 0))
def prop(kind):
 if kind=='lantern':
  box('Foot',(0,0,.12),(.7,.7,.24),'stone');beam('Post',(0,0,.2),(0,0,2.4),.1,'cedar');box('Paper light',(0,0,2),(.65,.65,.8),'paper')
  for x in [-.34,.34]:
   for y in [-.34,.34]:box('Lantern frame',(x,y,2),(.06,.06,.85),'red')
  roof(1,1,2.45,.25)
 elif kind=='well':
  for i in range(10):
   a=i*math.tau/10;o=box('Well stone',(math.cos(a),math.sin(a),.55),(.65,.4,1.1),'lightstone');o.rotation_euler.z=a+math.pi/2
  for x in [-1.3,1.3]:box('Well support',(x,0,1.5),(.17,.17,3),'cedar')
  roof(3.2,2.7,2.8,.7);beam('Cross axle',(-1.3,0,2),(1.3,0,2),.13,'cut');beam('Rope',(0,0,.5),(0,0,2),.025,'gold')
 elif kind=='cart':
  box('Cart bed',(0,0,.8),(1.6,2,.18),'cut')
  for x in [-.8,.8]:
   box('Cart side',(x,0,1.2),(.12,2,.7),'cedar');beam('Cart handle',(x,-.8,.75),(x,-2.7,.65),.06,'cut')
   bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=4,major_radius=.48,minor_radius=.075,location=(x*1.2,0,.52),rotation=(0,math.pi/2,0));finish(bpy.context.object,'Wood wheel','cedar')
   for a in range(4):beam('Wheel spoke',(x*1.2,-math.cos(a*math.pi/4)*.45,.52-math.sin(a*math.pi/4)*.45),(x*1.2,math.cos(a*math.pi/4)*.45,.52+math.sin(a*math.pi/4)*.45),.035,'cut')
 elif kind=='fence':
  for x in [-1.5,1.5]:box('Fence post',(x,0,.8),(.16,.18,1.6),'cedar')
  for z in [.45,1.3]:box('Fence rail',(0,0,z),(3.2,.12,.12),'cut')
  for i in range(9):box('Fence slat',(-1.4+i*.35,0,.85),(.1,.1,1.1),'cedar')
 elif kind=='torii':
  for x in [-2,2]:beam('Vermilion pillar',(x,0,0),(x*.95,0,4.2),.2,'red',.16);box('Pillar shoe',(x,0,.18),(.52,.5,.36),'stone')
  box('Tie beam',(0,0,3.2),(5,.25,.26),'red');roof(5.8,.65,4,.28,k='ridge');box('Sacred plaque',(0,-.2,3.65),(.6,.16,.65),'gold')

def export(name,category):
 bpy.context.view_layer.update()
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
 # Preserve part-level editing in .blend, export combined vertex-color mesh with one shared material.
 for o in obs:o.select_set(True)
 pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
 bpy.context.scene['asset_id']=name;bpy.context.scene['pivot']='ground center';bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources'/f'{name}.blend'))
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 attr=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 for p in o.data.polygons:
  c=o.data.materials[p.material_index].diffuse_color
  for li in p.loop_indices:attr.data[li].color=c
 m=bpy.data.materials.get('CP_Shared_Matte')
 if not m:
  m=bpy.data.materials.new('CP_Shared_Matte');m.use_nodes=True;n=m.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Color';m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color']);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
 o.data.materials.clear();o.data.materials.append(m)
 for p in o.data.polygons:p.material_index=0
 bpy.ops.export_scene.gltf(filepath=str(P/'exports'/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True)
 return {'id':name,'category':category,'dimensions_xyz_blender_m':[round(hi[i]-lo[i],3) for i in range(3)],'bounds_min':lo,'bounds_max':hi,'triangles':tris,'pivot':'ground center (0,0,0)','interior':name in ['machiya_open','tea_house_open'],'collision':'separate wall/floor boxes; keep doorway clear' if name in ['machiya_open','tea_house_open','gatehouse'] else ('static trimesh or simplified convex hull' if category!='tree' else 'trunk capsule only'),'surfaces':1}

def setup_render(loc,target,ortho,path,res=(1500,1100)):
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=False;s.render.resolution_x=res[0];s.render.resolution_y=res[1];s.render.resolution_percentage=100
 s.world.color=(.35,.35,.35);s.view_settings.view_transform='Standard'
 bpy.ops.object.light_add(type='AREA',location=(0,-10,24));bpy.context.object.data.energy=2700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=18
 bpy.ops.object.light_add(type='AREA',location=(2,-12,8));bpy.context.object.data.energy=1600;bpy.context.object.data.size=10;bpy.context.object.rotation_euler=(Vector((0,0,2))-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.light_add(type='SUN',location=(0,0,10));bpy.context.object.rotation_euler=(.5,-.4,-.4);bpy.context.object.data.energy=2
 bpy.ops.object.camera_add(location=loc);cam=bpy.context.object;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=ortho;s.camera=cam;s.render.filepath=str(path)
def import_asset(name,p=(0,0,0)):
 bpy.ops.import_scene.gltf(filepath=str(P/'exports'/f'{name}.glb'));obs=list(bpy.context.selected_objects)
 for o in obs:o.location+=Vector(p)
 return obs
def render_group(names,positions,path,ortho=20):
 reset()
 for n,p in zip(names,positions):import_asset(n,p)
 box('Display ground',(0,0,-.16),(80,65,.25),'paper');setup_render((18,-26,20),(0,0,2.5),ortho,P/'previews'/path);bpy.ops.render.render(write_still=True)

spec=[('machiya_open','building','machiya'),('inn','building','inn'),('tea_house_open','building','tea_house'),('warehouse','building','warehouse'),('shrine','building','shrine'),('gatehouse','building','gatehouse')]+[(n,'tree',k) for n,k in [('cedar','cedar'),('sakura','sakura'),('cloud_pine','pine'),('bamboo_cluster','bamboo')]]+[(n,'rock',n) for n in ['river_rock','moss_boulder','split_crag','cliff_step']]+[(n,'mountain',n) for n in ['twin_summit','long_ridge','sacred_peak']]+[(n,'prop',n) for n in ['lantern','well','cart','fence','torii']]
if '--checkpoint' in sys.argv:spec=[spec[0],spec[6],spec[11]]
manifest=[]
for name,cat,kind in spec:
 reset();{'building':building,'tree':tree,'rock':rock,'mountain':mountain,'prop':prop}[cat](kind);manifest.append(export(name,cat))
(P/('checkpoint.json' if '--checkpoint' in sys.argv else 'manifest.json')).write_text(json.dumps(manifest,indent=2))
if '--checkpoint' in sys.argv:render_group(['machiya_open','cedar','moss_boulder'],[(0,0,0),(6,1,0),(5,-3,0)],'checkpoint.png',22)
else:
 render_group(['machiya_open','cedar','moss_boulder','lantern','cart'],[(0,0,0),(6,1,0),(5,-3,0),(-5,-4,0),(-3,-5,0)],'street_close.png',23)
 render_group(['shrine','torii','sakura','river_rock'],[(0,2,0),(0,-5,0),(6,2,0),(-5,-3,0)],'shrine_close.png',24)
 render_group(['tea_house_open','cloud_pine','well'],[(0,0,0),(6,2,0),(-6,-1,0)],'tea_house_close.png',23)
 render_group(['long_ridge','twin_summit','sacred_peak'],[(-20,0,0),(1,0,0),(23,1,0)],'mountains_close.png',75)
 # Labeled atlas assembled in Blender with individually normalized exhibits.
 reset()
 for i,a in enumerate(manifest):
  x=(i%6)*10;y=-(i//6)*18;obs=import_asset(a['id']);s=6.5/max(a['dimensions_xyz_blender_m'])
  for o in obs:o.location=Vector((x,y,0));o.scale*=s;o.rotation_euler.z=math.radians(-12)
  box('Exhibit plinth',(x,y,-.15),(9,10,.3),'paper')
  bpy.ops.object.text_add(location=(x-4.1,y-4.8,.03));t=bpy.context.object;t.name='Label '+a['id'];t.data.body=a['id'];t.data.size=.50;t.data.extrude=.001;t.data.materials.append(mat('dark'))
 setup_render((25,-82,40),(25,-27,2),68,P/'previews/contact_sheet.png',(2400,1700));bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources/contact_sheet.blend'));bpy.ops.render.render(write_still=True)
 # Full-scale standalone arranged showcase source and GLB.
 reset()
 for i,a in enumerate(manifest):
  x=(i%6)*18;y=(i//6)*25;import_asset(a['id'],(x,y,0))
 box('Showcase ground',(45,32,-.2),(120,120,.4),'paper');bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources/showcase.blend'));bpy.ops.export_scene.gltf(filepath=str(P/'showcase.glb'),export_format='GLB')
