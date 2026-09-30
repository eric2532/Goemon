"""Original Tidefall prop kit. Blender --background --python tools/build_town_props.py.
Existing masters are protected; edit .blend and export_blender.py for revisions.
"""
import bpy, math, json, sys, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/blender/town_props'; OUT=ROOT/'assets/models/town_props'; DOC=ROOT/'docs/town-props'
for p in [SRC,OUT,DOC]:p.mkdir(parents=True,exist_ok=True)
if list(SRC.glob('*.blend')) and '--replace' not in sys.argv:raise RuntimeError('Town prop masters exist; edit/export them or explicitly --replace')
M={}
def cv(p):return Vector((p[0],-p[2],p[1]))
def mat(k):
 if k in M:return M[k]
 m=bpy.data.materials.new('Tidefall_'+k);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Roughness'].default_value=1
 t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/textures/edo'/f'{k}.png'),check_existing=True);t.image.pack();t.interpolation='Closest';m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color']);M[k]=m;return m

def box(n,p,s,k):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=n;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat(k));return o

def mesh(n,v,f,k):
 d=bpy.data.meshes.new(n);d.from_pydata([cv(p) for p in v],[],f);d.update();o=bpy.data.objects.new(n,d);bpy.context.collection.objects.link(o);o.data.materials.append(mat(k));return o

def round(n,p,s,k,verts=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=verts,ring_count=6,radius=1,location=cv(p));o=bpy.context.object;o.name=n;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat(k));return o

def cyl(n,p,r,h,k,verts=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=h,location=cv(p));o=bpy.context.object;o.name=n;o.data.materials.append(mat(k));return o

def roof(y,w,d,h):
 mesh('Curved tiled roof',[(-w/2,y,-d/2),(w/2,y,-d/2),(-w*.44,y-.12,-d*.30),(w*.44,y-.12,-d*.30),(-w*.43,y+h,0),(w*.43,y+h,0),(-w*.44,y-.12,d*.30),(w*.44,y-.12,d*.30),(-w/2,y,d/2),(w/2,y,d/2)],[(0,2,3,1),(2,4,5,3),(4,6,7,5),(6,8,9,7)],'tile')
 box('Roof ridge',(0,y+h+.05,0),(w*.9,.17,.24),'tile')
 for z in [-d/2,d/2]:box('Vermilion eaves',(0,y-.045,z),(w,.12,.14),'red')

def lantern(x=0,y=.8,z=0):
 round('Twelve sided paper lantern',(x,y,z),(.35,.52,.35),'paper')
 for yy in [-.42,-.27,0,.27,.42]:
  rr=math.sqrt(max(.05,1-(yy/.53)**2))*.355
  cyl('Dark lacquer ribs',(x,y+yy,z),rr,.025,'wood')
 for yy in [-.51,.51]:cyl('End cap',(x,y+yy,z),.18,.075,'wood')
 box('Hanging strap',(x,y+.68,z),(.035,.29,.035),'wood')
 # Abstract original sun-mark, not text or borrowed crest.
 box('Lantern indigo mark',(x,y,z+.352),(.16,.22,.025),'blue')

def noren():
 box('Curtain rail',(0,1.2,0),(2.5,.06,.07),'wood')
 for i in range(5):
  x=(i-2)*.46;box('Split indigo cloth',(x,.65,0),(.425,1.0,.028),'blue')
  box('Cream crest horizontal',(x,.73,.025),(.23,.055,.02),'paper')
  if i%2==0:box('Cream crest vertical',(x,.73,.026),(.055,.25,.02),'paper')

def sign():
 box('Sign bracket',(-.35,1.12,0),(1.05,.07,.07),'wood')
 for x in [-.28,.28]:box('Sign rope',(x,.94,0),(.025,.25,.025),'ochre')
 box('Carved shop sign',(0,.49,0),(.88,.72,.12),'wood')
 box('Cream sign inset',(0,.49,.072),(.72,.58,.025),'paper')
 for y,w in [(.32,.4),(.49,.27),(.66,.4)]:box('Abstract bowl emblem',(0,y,.093),(w,.055,.025),'red')

def gate():
 for x in [-7,7]:
  box('Stone post foot',(x,.25,0),(.95,.5,.9),'stone');box('Vermilion gate post',(x,2.7,0),(.48,5,.48),'red')
  box('Foot tie',(x,.38,0),(.6,.2,1.7),'wood')
 box('Great timber lintel',(0,4.85,0),(15,.45,.65),'wood');box('Painted lower beam',(0,4.2,0),(14.6,.22,.25),'red');roof(5.13,16,2.7,.85)
 box('Gate crest board',(0,4.25,.19),(1.8,.95,.13),'blue')
 for x in [-.5,0,.5]:box('Gate sun crest',(x,4.25,.28),(.18,.5,.025),'paper')
 for x in [-5.6,5.6]:lantern(x,3.58,0)

def stall(kind):
 box('Counter base',(0,.57,0),(2.7,1.14,1.15),'wood');box('Counter top',(0,1.17,.12),(2.95,.16,1.5),'ochre')
 for x in [-1.38,1.38]:
  box('Awning post',(x,1.35,-.5),(.085,2.7,.085),'wood')
 for i in range(7):
  a=-1.65+i*3.3/7;b=a+3.3/7
  mesh('Striped cloth awning',[(a,2.7,-.9),(b,2.7,-.9),(a,2.35,1),(b,2.35,1)],[(0,2,3,1)],'red' if (i%2==0 and kind=='noodle') else ('blue' if i%2==0 else 'paper'))
  box('Awning scallop',(a+3.3/14,2.25,1),(3.3/7-.025,.25,.03),'red' if kind=='noodle' else 'blue')
 for x in [-.7,0,.7]:
  cyl('Serving bowl',(x,1.31,.3),.23,.17,'paper')
  if kind=='noodle':round('Soup surface',(x,1.40,.3),(.18,.025,.18),'ochre')
  else:
   for z in [.19,.38]:
    for xx in [-.09,.09]:round('Rice dumpling',(x+xx,1.48,z),(.08,.08,.08),'paper',8)
 box('Hanging food sign',(1.16,1.91,.96),(.48,.54,.04),'paper')
 for yy in [1.78,1.93,2.06]:box('Food sign red bars',(1.16,yy,.99),(.22,.055,.025),'red')

def stone_lantern():
 box('Stone lantern plinth',(0,.08,0),(.78,.16,.78),'stone');cyl('Stone lantern pedestal',(0,.62,0),.17,.95,'stone',8)
 box('Lantern chamber floor',(0,1.12,0),(.62,.15,.62),'stone');box('Lantern paper light',(0,1.39,0),(.36,.39,.36),'paper')
 for x in [-.24,.24]:
  for z in [-.24,.24]:box('Stone chamber upright',(x,1.39,z),(.085,.48,.085),'stone')
 bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.64,radius2=.18,depth=.34,location=cv((0,1.77,0)),rotation=(0,0,math.pi/4));bpy.context.object.data.materials.append(mat('stone'));round('Stone finial',(0,2.02,0),(.12,.18,.12),'stone',8)

def offering():
 box('Offering chest',(0,.37,0),(1.3,.74,.74),'wood')
 for z in [-.33,.33]:box('Chest rim',(0,.8,z),(1.44,.12,.09),'ochre')
 for x in [-.63,.63]:box('Chest side rim',(x,.8,0),(.12,.12,.72),'ochre')
 for i in range(7):box('Offering slat',(-.5+i/6,.79,0),(.075,.075,.66),'wood')
 box('Original offering crest',(0,.43,.38),(.29,.3,.025),'paper')

def shrine():
 box('Shrine foundation',(0,.16,0),(2.7,.32,2.25),'stone');box('Raised platform',(0,.5,0),(2.25,.4,1.8),'wood')
 box('Cream shrine enclosure',(0,1.5,-.16),(1.8,1.65,1.35),'plaster')
 for x in [-1,1]:box('Shrine red posts',(x,1.5,.68),(.16,2,.16),'red')
 for x in [-.42,.42]:
  box('Closed shrine doors',(x,1.55,.55),(.76,1.44,.11),'wood')
  for xx in [-.2,0,.2]:box('Door lattice',(x+xx,1.66,.62),(.035,1.02,.025),'ochre')
 box('Shrine lower step',(0,.13,1.28),(2.2,.26,.45),'stone');box('Shrine upper step',(0,.32,1.04),(2,.2,.35),'stone')
 roof(2.44,3.05,2.45,.65)
 box('Sacred rope',(0,2.18,.86),(2.06,.075,.07),'ochre')
 for x in [-.62,0,.62]:
  o=box('Folded paper ornament',(x,1.99,.89),(.12,.29,.02),'paper');o.rotation_euler.y=.35

def save(name,fn):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);fn()
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in obs:
  uv=o.data.uv_layers.active or o.data.uv_layers.new(name='PropUV')
  for p in o.data.polygons:
   axes=[a for a in range(3) if a!=max(range(3),key=lambda i:abs(p.normal[i]))]
   for li in p.loop_indices:
    v=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]]*.8,v[axes[1]]*.8)
 # One mesh object per prop with shared opaque texture materials.
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 tris=sum(len(p.vertices)-2 for p in o.data.polygons);materials=len(o.data.materials)
 bpy.context.scene['asset_id']='town_props/'+name;bpy.context.scene['authorship']='Original geometry and existing original Edo pixel texture kit; main Tidefall area only'
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
 # Isometric neutral studio preview; source remains a clean editable asset.
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=768;scene.render.resolution_y=640;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.world.color=(.16,.19,.23)
 scene.view_settings.view_transform='Standard'
 bounds=[o.matrix_world@Vector(v) for v in o.bound_box];center=sum(bounds,Vector())/8;span=max(o.dimensions)
 bpy.ops.object.camera_add(location=center+Vector((1.3,-2.0,1.2))*span);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*1.65;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=center+Vector((1,-1,2))*span);bpy.context.object.data.energy=160*span**2;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=span*2
 scene.render.filepath=str(DOC/(name+'.png'));bpy.ops.render.render(write_still=True)
 return {'asset_id':'town_props/'+name,'source':str((SRC/(name+'.blend')).relative_to(ROOT)),'runtime':str((OUT/(name+'.glb')).relative_to(ROOT)),'thumbnail':str((DOC/(name+'.png')).relative_to(ROOT)),'triangles':tris,'meshes':1,'materials':materials,'bytes':(OUT/(name+'.glb')).stat().st_size,'sha256':hashlib.sha256((OUT/(name+'.glb')).read_bytes()).hexdigest()}
entries=[]
for name,fn in [('tidefall_gate',gate),('noodle_stall',lambda:stall('noodle')),('dumpling_stall',lambda:stall('dumpling')),('paper_lantern',lantern),('indigo_noren',noren),('bowl_shop_sign',sign),('wayside_shrine',shrine),('stone_lantern',stone_lantern),('offering_box',offering)]:entries.append(save(name,fn))
(DOC/'asset-catalog.json').write_text(json.dumps({'schema_version':1,'area':'Tidefall only','authorship':'Original Blender geometry; original Edo texture kit','assets':entries},indent=2))
