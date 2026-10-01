"""Upgrade only Cedar Pass building sources. Blender 4.3. Original pack is preserved in git.
Run -- --checkpoint for the shop only; default revises all six buildings.
"""
from pathlib import Path
import bpy,json,math,sys
from mathutils import Vector
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
SPECS={'machiya_open':(8,6,4,3.2),'inn':(10,7,7,3.6),'tea_house_open':(9,6,3.5,3.4),'warehouse':(8,7,5,4),'shrine':(7,6,4.2,3.2),'gatehouse':(12,4,6,6)}
C=[];G='Interior';F=.36
raw_box=box;raw_mesh=mesh;raw_beam=beam

def mark(o,g=None):o['cp_group']=g or G;return o
def box(n,p,s,k):return mark(raw_box(n,p,s,k))
def mesh(n,v,f,k):return mark(raw_mesh(n,v,f,k))
def beam(n,a,b,r,k,r2=None):return mark(raw_beam(n,a,b,r,k,r2))
def col(n,p,s,g='Interior',kind='box',extra=None):
 a={'name':n,'group':g,'type':kind,'position_blender':p,'size_blender':s}
 if extra:a.update(extra)
 C.append(a)
def solid(n,p,s,k,g=None):
 o=box(n,p,s,k)
 if g:o['cp_group']=g
 col(n,p,s,o['cp_group']);return o

def ramp(n,cx,front,width,length=2):
 # Zero-threshold wedge rising from street to the 0.36m finished floor.
 y0=front-length;y1=front
 v=[(cx-width/2,y0,0),(cx+width/2,y0,0),(cx+width/2,y1,0),(cx-width/2,y1,0),(cx-width/2,y1,F),(cx+width/2,y1,F)]
 o=mesh(n,v,[(0,1,5,4),(0,4,3),(1,2,5),(3,4,5,2),(0,3,2,1)],'stone');o['cp_group']='Floor'
 col(n,(0,0,0),(0,0,0),'Floor','convex',{'vertices_blender':v})
def shelf(n,x,y,w,d,h,rotation=False):
 # Individual planks, uprights and original wares; a matching simple solid volume blocks traversal.
 for z in [F+.10,F+h*.45,F+h*.80]:box(n+' shelf',(x,y,z),(w,d,.09),'cut')
 if rotation:
  for sign in [-1,1]:box(n+' upright',(x,y+sign*(d/2-.06),F+h/2),(w,.12,h),'cedar')
  box(n+' back',(x+(1 if x>0 else -1)*(w/2-.04),y,F+h/2),(.08,d,h),'cedar')
 else:
  for sign in [-1,1]:box(n+' upright',(x+sign*(w/2-.06),y,F+h/2),(.12,d,h),'cedar')
  box(n+' back',(x,y+d/2-.04,F+h/2),(w,.08,h),'cedar')
 length=d if rotation else w
 count=max(2,int(length/.6))
 for j in range(3):
  for i in range(count):
   offset=-length*.35+i*length*.7/(count-1);xx=x if rotation else x+offset;yy=y+offset if rotation else y-.04;zz=F+.26+j*h*.34
   box(n+' goods',(xx,yy,zz),(.26,.28,.26),'paper' if (i+j)%2 else 'red')
 col(n,(x,y,F+h/2),(w,d,h))
def bench(n,x,y,w=1.6,d=.55):
 box(n+' seat',(x,y,F+.47),(w,d,.12),'cut')
 for dx in [-w*.36,w*.36]:box(n+' leg',(x+dx,y,F+.23),(.12,d*.7,.46),'cedar')
 col(n,(x,y,F+.27),(w,d,.54))
def table(n,x,y,w,d,height=.82):
 box(n+' top',(x,y,F+height),(w,d,.12),'red')
 for dx in [-w*.38,w*.38]:
  for dy in [-d*.35,d*.35]:box(n+' leg',(x+dx,y+dy,F+height/2),(.10,.10,height),'cedar')
 col(n,(x,y,F+(height+.06)/2),(w,d,height+.06))
 # Small ceramic tray and cups remain within the table collider silhouette.
 box(n+' serving tray',(x,y,F+height+.085),(.65,.42,.035),'gold')
 for dx in [-.18,.18]:beam(n+' tea cup',(x+dx,y,F+height+.11),(x+dx,y,F+height+.25),.075,'paper',.09)
def crate(n,x,y,w=1,d=1,h=.8,z=F):
 box(n+' body',(x,y,z+h/2),(w,d,h),'cut')
 for dz in [.12,h-.12]:box(n+' band',(x,y-d/2-.02,z+dz),(w,.05,.07),'cedar')
 col(n,(x,y,z+h/2),(w+.03,d+.04,h))
def bed(n,x,y,z=F):
 box(n+' tatami',(x,y,z+.015),(1.65,2.35,.03),'moss')
 box(n+' futon',(x,y,z+.09),(1.4,2.1,.14),'paper');box(n+' quilt',(x,y-.18,z+.18),(1.43,1.55,.1),'roof');box(n+' pillow',(x,y+.75,z+.22),(.7,.35,.18),'plaster')
 col(n,(x,y,z+.14),(1.65,2.35,.28),G)
def lamp(n,x,y,z):
 box(n+' paper',(x,y,z),(.35,.35,.55),'paper')
 for dz in [-.31,.31]:box(n+' cap',(x,y,z+dz),(.46,.46,.07),'cedar')
 for dx in [-.19,.19]:
  for dy in [-.19,.19]:box(n+' frame',(x+dx,y+dy,z),(.035,.035,.6),'red')
 beam(n+' hanger',(x,y,z+.34),(x,y,z+.75),.025,'cedar')
def delete(o):bpy.data.objects.remove(o,do_unlink=True)
def classify(o,w,d):
 n=o.name
 if any(t in n for t in ['roof','Roof','Tile seam','Ridge','Eave','Gable','Upper passage']):return 'Roof'
 if n.startswith(('Side wall','Side plaster')):return 'Wall_Left' if o.location.x<0 else 'Wall_Right'
 if n.startswith('Rear wall'):return 'Wall_Back'
 if any(t in n for t in ['Front','Facade','Screen','Paper screen','Veranda','Hanging','Sign motif','offering','Sacred rope','Split indigo','Balcony']):return 'Wall_Front'
 if n.startswith(('Stone plinth','Timber floor','Entry step','Shrine approach')):return 'Floor'
 return 'Wall_Front' if o.location.y<0 else 'Interior'

def revise(name):
 global C,G,M
 C=[];G='Interior';M={}
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{name}.blend'))
 # Idempotent revision: source has a packed original snapshot in git; upgrading twice is disallowed.
 if bpy.context.scene.get('cedar_interior_revision',0):raise RuntimeError('Already revised '+name+'; edit/export instead or restore source from previous commit.')
 w,d,h,gap=SPECS[name]
 old=list(bpy.context.scene.objects)
 for o in old:
  if o.type!='MESH':continue
  n=o.name
  if name=='gatehouse':
   if n.startswith(('Gate tower','Gate pillar')):delete(o);continue
  elif n.startswith(('Front wall','Front wing','Door header','Low table','Table legs','Tatami mat','Mat border','Entry step','Shrine approach','Split indigo','Sacred rope','Paper offering')):
   delete(o);continue
  elif n.startswith(('Facade rail','Screen','Paper screen')):
   if n.startswith('Facade rail') and o.location.z<3.35:delete(o);continue
   if n.startswith(('Screen','Paper screen')) and abs(o.location.x)<gap/2+.08 and o.location.z<3.4:delete(o);continue
  o['cp_group']=classify(o,w,d)
 # Foundation, floor and existing wall visuals remain. Author exact wall/floor collision.
 if name!='gatehouse':
  col('Finished floor',(0,0,F/2),(w+.4,d+.4,F),'Floor')
  for sign in [-1,1]:
   col('Side wall',(sign*(w/2-.12),0,h/2+.3),(.24,d,h),'Wall_Left' if sign<0 else 'Wall_Right')
   G='Wall_Front';solid('Accessible front wing',(sign*(w+gap)/4,-d/2+.12,h/2+.3),((w-gap)/2,.24,h),'plaster')
   # Preserve visual framing without a collider rail across the entrance.
   for z in [.55,2.95]:box('Split facade rail',(sign*(w+gap)/4,-d/2-.12,z),((w-gap)/2,.18,.18),'red' if name=='shrine' else 'cedar')
   box('Door jamb',(sign*(gap/2+.05),-d/2-.11,1.88),(.12,.23,3.05),'red' if name=='shrine' else 'cedar')
  col('Rear wall',(0,d/2-.12,h/2+.3),(w,.24,h),'Wall_Back')
  solid('High doorway lintel',(0,-d/2+.12,(h+.3+3.4)/2),(gap,.24,h+.3-3.4),'plaster','Wall_Front')
  # Remove surviving centre lattice in the doorway; above-door details remain.
  for o in list(bpy.context.scene.objects):
   if o.type=='MESH' and o.name.startswith(('Screen','Paper screen')) and abs(o.location.x)<gap/2 and o.location.z<3.4:delete(o)
  G='Wall_Front'
  if name in ['machiya_open','tea_house_open']:
   for x in [-1,0,1]:box('Raised noren',(x,-d/2-.34,3.1),(.88,.045,.38),'roof' if name=='machiya_open' else 'red')
  G='Floor';ramp('Continuous entry ramp',0,-d/2-.20,gap+.15,2.2)
 else:
  G='Floor';solid('Gate paving',(0,0,F/2),(12,4,F),'stone','Floor');ramp('Gate approach',0,-2,6,2.2)
  # Back ramp allows continuous travel through the gate.
  before=set(bpy.context.scene.objects);ramp('Gate exit',0,-2,6,2.2)
  o=next(o for o in bpy.context.scene.objects if o not in before);o.rotation_euler.z=math.pi
  C[-1]['vertices_blender']=[(-x,-y,z) for x,y,z in C[-1]['vertices_blender']]
  for sign in [-1,1]:
   G='Wall_Left' if sign<0 else 'Wall_Right';solid('Guard bay outer wall',(sign*5.88,0,2.2),(.24,4,4),'plaster')
   G='Wall_Back';solid('Guard bay rear',(sign*4.5,1.88,2.2),(3,.24,4),'plaster')
   G='Wall_Front';solid('Guard bay facade',(sign*4.5,-1.88,2.2),(3,.24,4),'plaster')
   for x in [sign*3.1,sign*5.9]:box('Gate structural post',(x,-2,2.2),(.22,.26,4.4),'red')
 G='Interior'
 routes=[[0,-d/2-2.7],[0,-d/2+1.2],[0,0],[0,d/2-1.2]]
 blockers=[]
 if name=='machiya_open':
  solid('Merchant counter',(-2.7,.2,F+.55),(1.15,3.35,1.1),'cut')
  shelf('Back stock',-1.9,2.55,3.2,.55,2.3);shelf('Right display',3.15,.8,.65,2.5,2.15,True)
  crate('Rice crate',2.9,2.25,.85,.85,.7)
  box('Merchant counter cloth',(-2.7,.2,F+1.115),(1.14,1.7,.035),'roof')
  for y in [-.7,.2,1.0]:box('Shop parcel',(-2.7,y,F+1.32),(.5,.45,.4),'paper')
  blockers=[{'start':[0,0],'toward':[-3,0],'stop_axis':'x','limit':-1.70}]
  routes=[[0,-5.8],[0,-1.7],[0,.8],[1.65,.8],[1.65,-1.7],[0,-1.7],[0,-5.8]]
 elif name=='tea_house_open':
  for sign in [-1,1]:
   box('Dining tatami',(sign*2.9,.35,F+.012),(2.25,3,.024),'moss')
   table('Tea table',sign*2.85,.45,1.35,1.5,.60)
   bench('Guest bench',sign*2.85,-.95,1.35,.42)
  solid('Tea service counter',(0,2.45,F+.5),(4.6,.65,1),'cut');shelf('Tea tins',0,2.7,3.7,.4,2.1)
  blockers=[{'start':[0,0],'toward':[3,0],'stop_axis':'x','limit':1.79}]
  routes=[[0,-5.8],[0,-1.8],[0,.8],[1.45,.8],[1.45,-1.8],[-1.45,-1.8],[-1.45,.8],[0,.8],[0,-5.8]]
 elif name=='warehouse':
  shelf('Left goods rack',-2.85,0,1.1,4.4,2.8,True);shelf('Right goods rack',2.85,0,1.1,4.4,2.8,True)
  for x in [-1.25,1.25]:crate('Rear cargo',x,2.65,1.15,1.1,1.1);crate('Cargo top',x,2.65,.8,.85,.7,F+1.1)
  blockers=[{'start':[0,0],'toward':[3,0],'stop_axis':'x','limit':1.92}]
  routes=[[0,-6.3],[0,-1.8],[0,1.5],[-1.25,1.5],[-1.25,-1.8],[1.25,-1.8],[1.25,1.5],[0,1.5],[0,-6.3]]
 elif name=='inn':
  solid('Reception counter',(-3.35,-1,F+.55),(1.4,2.4,1.1),'cut');shelf('Guest key cabinet',-3.2,3.05,2.5,.5,2.3)
  bed('Ground guest futon',-2.7,1.15);bench('Waiting bench',.7,2.75,2.2,.5)
  # 22 visible 0.15m risers; one continuous inclined collision hull underneath.
  run=4.0;rise=3.3;xx=3.65;start=-2.0;end=start+run;sw=1.6
  for i in range(22):
   step=(i+1)*rise/22;box('Stair tread',(xx,start+(i+.5)*run/22,F+step/2),(sw,run/22,step),'cut')
  verts=[(xx-sw/2,start,F),(xx+sw/2,start,F),(xx-sw/2,end,F),(xx+sw/2,end,F),(xx-sw/2,end,F+rise),(xx+sw/2,end,F+rise)]
  col('Stair smooth collision',(0,0,0),(0,0,0),'Interior','convex',{'vertices_blender':verts})
  # Rear mezzanine and landing, with full height clearance above the reception area.
  upper=F+rise;solid('Mezzanine floor',(-.85,1.35,upper-.09),(7.65,4.0,.18),'cut','UpperFloor');solid('Stair top landing',(3.65,2.6,upper-.09),(1.6,1.2,.18),'cut','UpperFloor')
  G='UpperFurniture'
  for x in [-3.2,-.6]:bed('Upstairs guest futon',x,1.8,upper)
  solid('Mezzanine front guard',(-.85,-.67,upper+.48),(7.65,.12,.96),'cedar','UpperFloor')
  # Transparent-in-silhouette rail with solid simple collision to prevent falls.
  for o in list(bpy.context.scene.objects):
   if o.name.startswith('Mezzanine front guard'):delete(o)
  G='UpperFloor'
  for x in [-4.5,-3.5,-2.5,-1.5,-.5,.5,1.5,2.7]:box('Mezzanine baluster',(x,-.67,upper+.45),(.07,.07,.9),'cedar')
  box('Mezzanine handrail',(-.85,-.67,upper+.94),(7.65,.12,.10),'red')
  # Railing along inner stair edge stops sideways falls without blocking top landing.
  a=(xx-sw/2-.03,start,F+.85);b=(xx-sw/2-.03,end,upper+.85);beam('Stair handrail',a,b,.055,'red')
  for i in range(6):
   yy=start+i*run/5;zz=F+i*rise/5;box('Stair baluster',(xx-sw/2-.03,yy,zz+.42),(.07,.07,.84),'cedar')
  col('Stair inner rail',(xx-sw/2-.06,(start+end)/2,F+rise/2+.55),(.12,run,rise+1.1),'UpperFloor')
  G='Interior';blockers=[{'start':[0,-1],'toward':[-4,-1],'stop_axis':'x','limit':-2.24}]
  routes=[[0,-6.3],[0,-1.8],[0,1.1],[1.6,1.1],[1.6,-1.8],[0,-1.8],[0,-6.3]]
 elif name=='shrine':
  solid('Offering altar',(0,1.85,F+.52),(3.6,.95,1.04),'red')
  box('Altar gold edge',(0,1.85,F+1.07),(3.8,1.05,.09),'gold')
  for x in [-1.1,1.1]:box('Prayer mat',(x,0,F+.012),(.85,1.2,.024),'moss');bench('Worship bench',x*2.35,0,.6,1.5)
  for x in [-.9,.9]:beam('Offering vase',(x,1.85,F+1.15),(x,1.85,F+1.55),.15,'paper',.1)
  box('Sacred tablet',(0,2.65,2.2),(1,.12,1.1),'gold')
  blockers=[{'start':[0,0],'toward':[0,2.5],'stop_axis':'y','limit':.99}]
  routes=[[0,-5.8],[0,-1.2],[0,.6],[1.25,.6],[1.25,-1.2],[-1.25,-1.2],[-1.25,.6],[0,.6],[0,-5.8]]
 else:
  for sign in [-1,1]:
   bench('Guard bench',sign*4.9,.85,1.7,.5);shelf('Guard cubby',sign*5.35,-.5,.6,1.25,1.6,True)
  blockers=[{'start':[4,0],'toward':[4,1.5],'stop_axis':'y','limit':.22}]
  routes=[[0,-5],[0,0],[4,0],[0,0],[-4,0],[0,0],[0,5],[0,0],[0,-5]]
 G='Floor'
 if name!='gatehouse':
  for i in range(int(w/.5)):
   xx=-w/2+(i+1)*.5;box('Floorboard seam',(xx,0,F+.002),(.012,d,.004),'cedar')
 G='Interior'
 lights=[]
 for x in [-w*.30,w*.30]:lamp('Warm room lantern',x,1.6,2.7);lights.append([x,1.6,2.7])
 scene=bpy.context.scene;scene['cedar_interior_revision']=2;scene['asset_id']=name
 # Explicit editable collision proxies are hidden from rendering/export.
 coll=bpy.data.collections.new('CP_COLLISION_PROXIES');scene.collection.children.link(coll)
 for i,a in enumerate(C):
  if a['type']=='box':o=raw_box('COL_'+a['name'],a['position_blender'],a['size_blender'],'dark')
  else:o=raw_mesh('COL_'+a['name'],a['vertices_blender'],[],'dark')
  for c in list(o.users_collection):c.objects.unlink(o)
  coll.objects.link(o);o.hide_render=True;o.hide_set(True);o['collision_type']=a['type'];o['cp_group']='Collision'
 scene['interior_notes']='Revision 2. Ground floor 0.36m; ramps to grade; separated cutaway groups; exact collider metadata in interiors.json.'
 bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources'/f'{name}.blend'))
 stats=export_parts(name)
 return dict(stats,body_width=w,body_depth=d,door_width=gap,door_clear_height=2.5 if name in ['machiya_open','tea_house_open'] else 3.04,floor_height=F,colliders=C,lights_blender=lights,route_blender=routes,furniture_tests=blockers,accessible_levels=[F,F+3.3] if name=='inn' else [F])

def export_parts(name):
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('cp_group')!='Collision'];bpy.context.view_layer.update()
 pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs);groups=sorted(set(o.get('cp_group','Interior') for o in obs));bygroup={g:[o for o in obs if o.get('cp_group','Interior')==g] for g in groups};exported=[]
 for group in groups:
  parts=bygroup[group];bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.hide_set(False);o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='CP_'+group;bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
  attr=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
  for p in o.data.polygons:
   color=o.data.materials[p.material_index].diffuse_color
   for li in p.loop_indices:attr.data[li].color=color
  m=bpy.data.materials.get('CP_Shared_Matte')
  if not m:
   m=bpy.data.materials.new('CP_Shared_Matte');m.use_nodes=True;n=m.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Color';m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color']);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
  o.data.materials.clear();o.data.materials.append(m)
  for p in o.data.polygons:p.material_index=0
  exported.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in exported:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(P/'exports'/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True)
 return {'id':name,'category':'building','dimensions_xyz_blender_m':[round(hi[i]-lo[i],3) for i in range(3)],'bounds_min':lo,'bounds_max':hi,'triangles':tris,'pivot':'ground placement origin (0,0,0)','interior':True,'collision':'authored wall/furniture boxes and ramp convex shapes in interiors.json','surfaces':len(exported),'groups':groups}

if __name__=='__main__':
 entries=json.loads((P/'manifest.json').read_text());interiors=json.loads((P/'interiors.json').read_text()) if (P/'interiors.json').exists() else {}
 names=['machiya_open'] if '--checkpoint' in sys.argv else list(SPECS)
 for name in names:
  if name in interiors:continue
  a=revise(name);interiors[name]=a
  for i,e in enumerate(entries):
   if e['id']==name:entries[i]={k:v for k,v in a.items() if k not in ['colliders','lights_blender','route_blender','furniture_tests']}
  (P/'manifest.json').write_text(json.dumps(entries,indent=2));(P/'interiors.json').write_text(json.dumps(interiors,indent=2))
 print('INTERIOR_REVISION_COMPLETE',list(interiors))
