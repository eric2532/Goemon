"""Original editable floating-island kit and soft cloud sculptures. Blender 5.x."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/sky_descent'; SRC=ROOT/'assets/blender/sky_descent'
OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mats={}
def mat(name,color,emission=0):
 if name in mats:return mats[name]
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.86
 if emission:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
 mats[name]=m;return m
rock=[mat('Basalt indigo',(.13,.21,.30)),mat('Blue slate',(.22,.35,.43)),mat('Sunlit sandstone',(.47,.50,.46)),mat('Warm cliff strata',(.62,.53,.40))]
grass=[mat('Jade moss',(.30,.61,.40)),mat('Sage meadow',(.48,.67,.43)),mat('Golden meadow',(.68,.68,.37))]
gold=mat('Weathered gold',(.89,.65,.27),.12);stone=mat('Old ivory stone',(.75,.77,.65));rootmat=mat('Hanging root',(.22,.31,.26))
cloud=mat('Pearl cloud',(.89,.94,1));cloudshadow=mat('Blue cloud underside',(.62,.76,.88));sun=mat('Apricot sun', (1,.75,.43),2)
def cv(p):return (p[0],-p[2],p[1])
def mesh(name,verts,faces,material):
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in verts],[],faces);me.materials.append(material);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return o
def ico(name,p,scale,material,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(scale[0],scale[2],scale[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);return o
def beam(name,a,b,width,material):
 a,b=Vector(cv(a)),Vector(cv(b));bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=width,radius2=width*.65,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(material);return o
def torus(name,p,radius,width,material):
 bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=width,major_segments=48,minor_segments=6,location=cv(p));o=bpy.context.object;o.name=name;o.data.materials.append(material);return o
stats={};masters=[]
def export(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 stats[name]={'objects':len(objects),'triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects if o.type=='MESH')}
 for o in objects:o.hide_set(True);o.hide_render=True
 masters.extend(objects)
for variant in range(3):
 rng=random.Random(512+variant);before=set(bpy.data.objects);n=24
 radii=[12+rng.uniform(-.45,.45) for _ in range(n)]
 rings=[(0,1),(-.65,1.015),(-2.5,.94),(-5,.65),(-8.5,.28),(-10,.04)]
 verts=[]
 for j,(y,factor) in enumerate(rings):
  for k,r in enumerate(radii):
   a=k*math.tau/n;verts.append((math.cos(a)*r*factor,y+(rng.uniform(-.5,.5) if j>1 else 0),math.sin(a)*r*factor))
 faces=[]
 for j in range(len(rings)-1):
  for k in range(n):
   a=j*n+k;b=j*n+(k+1)%n;c=(j+1)*n+(k+1)%n;d=(j+1)*n+k
   faces.extend([(a,b,d),(b,c,d)])
 cliff=mesh('Layered floating bedrock',verts,faces,rock[0])
 for m in rock[1:]:cliff.data.materials.append(m)
 for face in cliff.data.polygons:face.material_index=(face.index//(n*2)+variant)%4
 # Perfectly flat readable combat surface; collision uses its exact exported mesh.
 mesh('Walkable meadow',[(0,0,0)]+verts[:n],[(0,1+(k+1)%n,1+k) for k in range(n)],grass[variant])
 torus('Landing seal outer',(0,.045,0),2.45,.065,gold);torus('Landing seal inner',(0,.05,0),1.95,.035,stone)
 for k in range(8):
  a=k*math.tau/8
  beam('Inlaid compass',(math.cos(a)*2.7,.07,math.sin(a)*2.7),(math.cos(a)*3.3,.07,math.sin(a)*3.3),.045,stone)
 for k in range(12):
  a=k*math.tau/12+.3;r=rng.uniform(9.5,10.7);x,z=math.cos(a)*r,math.sin(a)*r
  ico('Edge boulder',(x,.22,z),(.65,.55,.55),rock[2])
  for j in range(3):
   px,pz=x+rng.uniform(-.7,.7),z+rng.uniform(-.7,.7)
   beam('Wind grass',(px,0,pz),(px+.18,.5+rng.random()*.5,pz-.1),.06,grass[(variant+1)%3])
 for k in range(6):
  a=k*math.tau/6;root=(math.cos(a)*9,-2,math.sin(a)*9)
  beam('Trailing root',root,(root[0]*.8,-8-rng.random()*3,root[2]*.8),.13,rootmat)
 # Two low broken pylons leave the central arena and launch lip clear.
 for a in [2.1,3.9]:
  x,z=math.cos(a)*8.5,math.sin(a)*8.5
  beam('Broken shrine column',(x,0,z),(x,1.3+variant*.35,z),.37,stone)
  torus('Pylon gold collar',(x,.8,z),.38,.04,gold)
 ornaments=[o for o in set(bpy.data.objects)-before if not o.name.startswith(('Walkable','Layered'))]
 bpy.ops.object.select_all(action='DESELECT')
 for o in ornaments:o.select_set(True)
 bpy.context.view_layer.objects.active=ornaments[0];bpy.ops.object.join();bpy.context.object.name='Island edge ornaments'
 export('island_'+str(variant),list(set(bpy.data.objects)-before))
for variant in range(2):
 rng=random.Random(97+variant);before=set(bpy.data.objects);parts=[]
 for i in range(11):
  x=(i-5)*1.5;z=rng.uniform(-1.3,1.3);y=math.sin((i+1)/12*math.pi)*2
  o=ico('Cloud billow', (x,y,z),(rng.uniform(2,3.4),rng.uniform(1.1,2.0),rng.uniform(1.7,2.7)),cloud,2);parts.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='Sculpted pearl cloud bank'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mod=o.modifiers.new('Joined soft volumes','REMESH');mod.mode='VOXEL';mod.voxel_size=.45;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Billow smoothing','SMOOTH');mod.factor=1;mod.iterations=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Realtime cloud budget','DECIMATE');mod.ratio=.32;bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=True
 export('cloud_'+str(variant),[o])
before=set(bpy.data.objects)
for r,w in [(12,.18),(14,.07)]:torus('Solar halo',(0,0,0),r,w,sun)
ico('Sun disc',(0,0,0),(10,.12,10),sun,3)
export('sun_halo',list(set(bpy.data.objects)-before))
# Native project includes export masters in named collections, arranged for editing.
for o in masters:o.hide_set(False);o.hide_render=False
for idx,name in enumerate(stats):
 collection=bpy.data.collections.new(name+' · export master');bpy.context.scene.collection.children.link(collection)
 # Export names are also written to the manifest, preserving easy regeneration.
scene=bpy.context.scene;scene.world.color=(.35,.48,.65)
# Keep assets at their original local origin; collection visibility makes selection easy.
for o in masters:o.hide_set(True);o.hide_render=True
# A linked layout study gives the .blend an immediately usable overview.
for idx,name in enumerate(stats):
 path=OUT/(name+'.glb');before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path))
 new=list(set(bpy.data.objects)-before)
 for o in new:
  if o.parent is None:o.location+=Vector(((idx%3)*32,(idx//3)*34,0))
 bpy.data.collections[name+' · export master'].objects.link(new[0])
bpy.ops.object.camera_add(location=(70,-75,75));camera=bpy.context.object;camera.rotation_euler=(Vector((30,16,-1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=112;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(20,-25,60));bpy.context.object.data.energy=65000;bpy.context.object.data.size=50
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'Sky_Descent_Islands_and_Clouds.blend'))
scene.render.filepath=str(ROOT/'tests/sky-descent/blender-kit.png');bpy.ops.render.render(write_still=True)
(ROOT/'tests/sky-descent/assets.json').write_text(json.dumps(stats,indent=2))
print('SKY_ASSETS_COMPLETE',stats)
