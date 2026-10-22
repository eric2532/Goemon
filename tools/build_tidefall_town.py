"""Author only the new Tidefall town buildings. Never rebuild existing assets.
blender --background --python tools/build_tidefall_town.py
Use saved .blend + tools/export_blender.py for subsequent hand edits.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'assets/blender/town';OUT=ROOT/'assets/models/town'
SRC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
if list(SRC.glob('*.blend')) and '--replace' not in sys.argv:raise RuntimeError('Existing town sources: edit/export, or explicitly --replace.')
M={}
def material(key):
 if key in M:return M[key]
 m=bpy.data.materials.new('Town_'+key);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.95
 t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/textures/edo'/f'{key}.png'),check_existing=True);t.image.pack();t.interpolation='Closest'
 m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color']);M[key]=m;return m

def cv(p):return Vector((p[0],-p[2],p[1]))
def box(name,p,size,key):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material(key));return o

def mesh(name,verts,faces,key):
 d=bpy.data.meshes.new(name);d.from_pydata([cv(v) for v in verts],[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.data.materials.append(material(key));return o

def roof(y,w=8.6,d=7.4,rise=2.0,turn=False):
 # Thick pitched roof: painted ceramic tiles, straight shared eaves and raised ridge ends.
 verts=[(-w/2,y,-d/2),(w/2,y,-d/2),(-w/2,y+rise,0),(w/2,y+rise,0),(-w/2,y,d/2),(w/2,y,d/2)]
 if turn:verts=[(z,y,x) for x,y,z in verts]
 o=mesh('Roof main',verts,[(0,2,3,1),(2,4,5,3)],'tile')
 bpy.context.view_layer.objects.active=o;o.select_set(True);mod=o.modifiers.new('Solid tiled eave','SOLIDIFY');mod.thickness=.14;bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
 # Gable infill is part of the closed body, never a false opening.
 gv=[(-4,y,-3),(4,y,-3),(-4,y+rise,0),(4,y+rise,0),(-4,y,3),(4,y,3)]
 if turn:gv=[(z,y,x) for x,y,z in gv]
 mesh('Roof gable infill',gv,[(0,4,2),(1,3,5)],'plaster')
 if not turn:
  for z in [-d/2,d/2]:box('Roof timber fascia',(0,y-.02,z),(w,.17,.18),'wood')
  box('Roof ridge',(0,y+rise+.08,0),(w+.2,.24,.28),'tile')
 else:
  for x in [-d/2,d/2]:box('Roof timber fascia',(x,y-.02,0),(.18,.17,w),'wood')
  box('Roof ridge',(0,y+rise+.08,0),(.28,.24,w+.2),'tile')

def window(cx,y,w,h,z=3.04):
 box('Shoji paper',(cx,y,z),(w,h,.06),'plaster')
 for i in range(int(w/.4)+1):box('Lattice upright',(cx-w/2+i*w/int(w/.4),y,z+.045),(.035,h,.05),'wood')
 for yy in [y-h/2,y,y+h/2]:box('Lattice crossrail',(cx,yy,z+.05),(w,.045,.05),'wood')

def curtain(key,y,width=5.6):
 for i in range(7):
  x=(i-3)*width/7;box('Split noren',(x,y,3.52),(width/7-.045,.8,.035),key)
  if i in [2,3,4]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.15,depth=.018,location=cv((x,y,3.55)),rotation=(math.pi/2,0,0));o=bpy.context.object;o.name='Original circle shop crest';o.data.materials.append(material('paper'))

def awning(y):
 o=mesh('Roof lean-to',[(-4.25,y,-.1), (4.25,y,-.1),(-4.25,y-.5,4.05),(4.25,y-.5,4.05)],[(0,2,3,1)],'tile')
 bpy.context.view_layer.objects.active=o;o.select_set(True);mod=o.modifiers.new('Awning thickness','SOLIDIFY');mod.thickness=.12;bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
 box('Awning edge',(0,y-.52,4.05),(8.5,.16,.16),'wood')

def build(name,kind):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
 tall=kind=='inn';store=kind=='storehouse';height=6.4 if tall else (5.3 if kind in ['house','corner'] else 4.1)
 box('Foundation',(0,-.9,0),(8,2.2,6),'stone')
 box('Closed building shell',(0,height/2+.2,0),(8,height,6),'plaster' if store else 'wood')
 # Cream infill gives the street a light middle band, with a darker timber base.
 if not store:
  box('Facade plaster',(0,height-.95,3.02),(7.75,1.65,.04),'plaster')
  for side in [-1,1]:
   box('Side plaster',(side*4.02,height-.95,0),(.04,1.65,5.8),'plaster')
   for z in [-2.9,0,2.9]:box('Side timber frame',(side*4.05,height-.95,z),(.08,1.8,.14),'wood')
 for x in [-3.88,0,3.88]:box('Structural post',(x,height/2+.2,3.08),(.16,height,.16),'wood')
 for y in [.35,3.15,height+.12]:box('Continuous lintel',(0,y,3.09),(8,.17,.18),'wood')
 # Closed sliding panels signal non-enterable houses instead of fake door holes.
 for x in [-2.5,0,2.5]:window(x,1.68,2.15,2.48)
 if kind in ['house','corner']:
  for x in [-2.45,0,2.45]:window(x,4.18,1.85,1.25)
 if tall:
  for x in [-2.45,0,2.45]:window(x,4.95,1.85,2.1)
  awning(3.9)
 elif kind=='shop':awning(3.75)
 roof(height+.3,turn=kind=='corner',w=7.4 if kind=='corner' else 8.6,d=8.6 if kind=='corner' else 7.4,rise=1.85)
 if kind in ['shop','inn']:curtain('blue' if kind=='shop' else 'red',2.78)
 if kind=='house':
  box('Timber shop sign',(-3.15,3.1,3.33),(.6,1.25,.15),'wood')
  for y in [2.86,3.10,3.34]:box('Sign painted emblem',(-3.15,y,3.42),(.25,.065,.025),'paper')
 if store:
  # Oversized plaster merchant storehouse, thick timber corner strips.
  for x in [-3.9,3.9]:box('Storehouse corner',(x,height/2+.2,3.1),(.18,height,.2),'wood')
  box('Storehouse mon',(0,3.62,3.13),(.8,.45,.04),'blue')
 # Collapse into two groups: exact roof collision can be added separately from a solid body hull.
 for group in ['Body','Roof']:
  obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Roof')==(group=='Roof')]
  bpy.ops.object.select_all(action='DESELECT')
  for o in obs:o.select_set(True)
  bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
  bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
  uv=o.data.uv_layers.active if o.data.uv_layers else o.data.uv_layers.new(name='TownUV')
  uv.active_render=True
  for poly in o.data.polygons:
   axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
   for li in poly.loop_indices:
    v=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]]*.45,v[axes[1]]*.45)
 bpy.context.scene['town_body_width']=8;bpy.context.scene['town_body_depth']=6;bpy.context.scene['town_body_top']=height+.3
 bpy.context.scene['authoring_note']='Original Tidefall main-area town kit. Closed shoji: no playable interior. Metres. Body uses matching solid hull; Roof uses mesh collision.'
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];mf=ROOT/'assets/models/manifest.json';entries=json.loads(mf.read_text());entries=[e for e in entries if e['asset']!='town/'+name]
 entries.append({'asset':'town/'+name,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),'meshes':len(obs),'surfaces':sum(len(o.data.materials) for o in obs),'bytes':(OUT/(name+'.glb')).stat().st_size});mf.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2))
 print('TOWN_BUILDING_EXPORTED',name)
for name,kind in [('timber_house','house'),('noren_shop','shop'),('corner_house','corner'),('plaster_storehouse','storehouse'),('two_story_inn','inn')]:build(name,kind)
